"""Offline sprite-rectangle packing shared by the SMZ and MMZ importers.

Rectangles remain contiguous in VDP column-major order. A tile may be bytes
or a tuple of era-specific bytes; the latter shares one mapping layout while
retaining independent art overlays. These helpers do not read/write files.
"""
def find_tiles(sequence, pattern):
	"""Find an entire column-major sprite rectangle at a tile boundary."""
	return next((i for i in range(len(sequence)-len(pattern)+1)
				 if sequence[i:i+len(pattern)] == pattern), None)


def pack_rectangles(patterns):
	"""Share complete rectangles and overlapping ends; never split a piece."""
	strings = []
	for pattern in sorted(set(patterns), key=lambda p: (-len(p), p)):
		if not any(find_tiles(s, pattern) is not None for s in strings):
			strings.append(pattern)
	while True:
		best = (0, 0, 0)
		for i, a in enumerate(strings):
			for j, b in enumerate(strings):
				if i == j:
					continue
				for count in range(min(len(a), len(b)), 0, -1):
					if a[-count:] == b[:count]:
						if count > best[0]:
							best = count, i, j
						break
		count, i, j = best
		if not count:
			return tuple(tile for s in strings for tile in s)
		joined = strings[i] + strings[j][count:]
		strings = [s for k, s in enumerate(strings)
				   if k not in (i, j) and find_tiles(joined, s) is None]
		strings.append(joined)
