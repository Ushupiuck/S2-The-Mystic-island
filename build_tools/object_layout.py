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
    parser = argparse.ArgumentParser(description='Convert S3&K layouts to the Mystic Island format in place.')
    parser.add_argument('--from-s3k', action='store_true', required=True)
    parser.add_argument('files', nargs='+', type=Path)
    args = parser.parse_args()
    # Validate every input before replacing any of them.
    converted = [(path, convert_s3k(path.read_bytes())) for path in args.files]
    for path, data in converted:
        path.write_bytes(data)
    print(f'Converted {len(converted)} layouts; existing objects appear in every era.')
