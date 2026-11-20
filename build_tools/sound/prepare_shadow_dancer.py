#!/usr/bin/env python3
"""Normalize supported Shadow Dancer .mmw commands for SMPSConv's S1 input."""

import argparse
from pathlib import Path


# Reachable commands supported by this import profile, from DefCFlag.txt.
# The two rewrites preserve instruction lengths and all relative pointers.
COMMAND_LENGTH = {
	0xE0: 2,  # Pan
	0xE6: 2,  # FM volume delta
	0xEF: 2,  # FM patch
	0xF0: 5,  # Modulation setup
	0xF2: 1,  # Stop
	0xF4: 1,  # Modulation off
	0xF6: 3,  # Jump
	0xF7: 5,  # Loop
	0xF8: 3,  # Call
	0xF9: 1,  # Return
	0xFB: 2,  # Transpose
}
TO_S1 = {0xF9: 0xE3, 0xFB: 0xE9}


def prepare(data):
	if len(data) < 6 or not 1 <= data[2] <= 6 or data[3] > 3:
		raise ValueError("invalid 68k music header")

	fm_end = 6 + data[2] * 4
	header_end = fm_end + data[3] * 6
	voice_start = int.from_bytes(data[:2], "big")
	if not header_end < voice_start < len(data) or (len(data) - voice_start) % 25:
		raise ValueError("expected a song with an appended 25-byte FM patch table")

	track_offsets = [*range(6, fm_end, 4), *range(fm_end, header_end, 6)]
	pending = [int.from_bytes(data[offset:offset + 2], "big") for offset in track_offsets]
	visited = set()
	operands = set()
	result = bytearray(data)
	while pending:
		position = pending.pop()
		if position in visited:
			continue
		if not header_end <= position < voice_start or position in operands:
			raise ValueError(f"invalid score address ${position:04X}")
		visited.add(position)
		command = data[position]
		if command < 0xE0:
			pending.append(position + 1)
			continue

		length = COMMAND_LENGTH.get(command)
		if length is None:
			raise ValueError(f"unsupported command ${command:02X} at ${position:04X}")
		end = position + length
		arguments = range(position + 1, end)
		if end > voice_start or not visited.isdisjoint(arguments):
			raise ValueError(f"overlapping or truncated command at ${position:04X}")
		operands.update(arguments)
		result[position] = TO_S1.get(command, command)
		if command in (0xF6, 0xF7, 0xF8):
			displacement = int.from_bytes(data[end - 2:end], "big", signed=True)
			pending.append(end - 1 + displacement)
		if command not in (0xF2, 0xF6, 0xF9):
			pending.append(end)
	return result


def main():
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("rip", type=Path)
	parser.add_argument("output", type=Path)
	args = parser.parse_args()
	if args.rip.resolve() == args.output.resolve():
		parser.error("use a separate output file")
	try:
		args.output.write_bytes(prepare(args.rip.read_bytes()))
	except (OSError, ValueError) as error:
		parser.error(str(error))


if __name__ == "__main__":
	main()
