"""Mystic Island's eight-byte, big-endian object placement format.

Importers reading an original game's six-byte data must still decode that
source format, then write their converted rows through encode().
"""
import argparse
from pathlib import Path
import struct

RECORD = struct.Struct('>HHBBH')
SIZE = RECORD.size
ALL_TIMEZONES = 0xE0  # Sonic CD: Past=$20, Present=$40, Future=$80
TERMINATOR = bytes.fromhex('FFFF000000000000')


def decode(data):
    if len(data) < SIZE or len(data) % SIZE or data[-SIZE:] != TERMINATOR:
        raise ValueError('Object layout needs complete eight-byte records and a final terminator')
    rows = list(RECORD.iter_unpack(data[:-SIZE]))
    previous = 0
    for x, y, object_id, timezones, subtype in rows:
        if not previous <= x < 0xFFFF or (y & 0x1000 and object_id not in (0x17, 0x18, 0xDB, 0xDC, 0xDD, 0xDE)) or not object_id:
            raise ValueError('Invalid coordinate, ordering, Y flags or object ID')
        previous = x
    return rows


def encode(rows):
    data = b''.join(RECORD.pack(*row) for row in rows) + TERMINATOR
    decode(data)
    return data


def with_timezones(row):
    """Accept legacy four-field importer/fixture rows, or full five-field rows."""
    if len(row) == 4:
        x, y, object_id, subtype = row
        return x, y, object_id, ALL_TIMEZONES, subtype
    if len(row) != 5:
        raise ValueError('Expected X/Y/ID/time-mask/subtype')
    return tuple(row)


def legacy_saw_subtype(subtype, metal=False):
	"""Translate a pre-sweep $A4 subtype while preserving its old motion."""
	reserved = subtype & 0xF000
	if metal or subtype & 0x100:
		return reserved | 0x0216 | (subtype & 0x80)
	return reserved | (0, 0x0301, 0x0401, 0x0501, 0x0601, 0, 0, 0)[subtype & 7]


def convert_legacy_saws(data, metal=False):
	rows = decode(data)
	legacy_mask = 0xF180 if metal else 0xF007
	for x, _, object_id, _, subtype in rows:
		if object_id == 0xA4 and subtype & ~legacy_mask:
			raise ValueError(f'Saw at X=${x:04X} has a non-legacy subtype ${subtype:04X}')
	return encode((*row[:4], legacy_saw_subtype(row[4], metal)) if row[2] == 0xA4 else row
		for row in rows)


def convert_s3k(data):
    if len(data) < 6 or len(data) % 6 or data[-6:] != bytes.fromhex('FFFF00000000'):
        raise ValueError('Input is not a terminated six-byte S3&K layout')
    return encode(with_timezones(row) for row in struct.iter_unpack('>HHBB', data[:-6]))


def mount_settings(row):
    """Six platform payload bits; presence and coordinates retain their masks."""
    _, y, oid, eras, _ = row
    return ((eras & 31) | ((y & 0x1000) >> 7)) if oid in (0x17, 0x18, 0xDB, 0xDC, 0xDD, 0xDE) else 0


def with_mount(row, settings):
    x, y, oid, eras, subtype = row
    if oid not in (0x17, 0x18, 0xDB, 0xDC, 0xDD, 0xDE) or not 0 <= settings < 64:
        raise ValueError('Mount settings require a platform and a six-bit value')
    return x, (y & ~0x1000) | ((settings & 32) << 7), oid, (eras & 0xE0) | (settings & 31), subtype


if __name__ == '__main__':
	parser = argparse.ArgumentParser(description='Convert supported object layouts in place.')
	mode = parser.add_mutually_exclusive_group(required=True)
	mode.add_argument('--from-s3k', action='store_true')
	mode.add_argument('--legacy-saws', choices=('scrap', 'metal'), help='Translate legacy $A4 records')
	parser.add_argument('files', nargs='+', type=Path)
	args = parser.parse_args()
	# Validate every input before replacing any of them.
	if args.from_s3k:
		converted = [(path, convert_s3k(path.read_bytes())) for path in args.files]
		message = f'Converted {len(converted)} layouts; existing objects appear in every era.'
	else:
		converted = [(path, convert_legacy_saws(path.read_bytes(), args.legacy_saws == 'metal'))
			for path in args.files]
		message = f'Updated saw subtypes in {len(converted)} layouts.'
	for path, data in converted:
		path.write_bytes(data)
	print(message)
