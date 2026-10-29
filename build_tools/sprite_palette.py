"""Offline palette-slot contracts for shared level sprites and importers.

These are source-format conversions, never runtime pixel conversion tables.
The first line is the owner's Sonic and Tails.bin arrangement. The second
keeps black/grays and the yellow ramp aligned; its other colors belong to
each act's enemies. Existing editable art already uses the destination slots.
"""

PLAYER_FROM_LEGACY = (0, 1, 12, 11, 15, 10, 6, 7, 8, 9, 5, 2, 13, 14, 4, 3)
ENEMY_FROM_LEGACY = (0, 1, 12, 11, 4, 10, 6, 7, 8, 9, 5, 2, 13, 14, 15, 3)
MECHA_FROM_SK = (0, 6, 2, 3, 4, 13, 14, 5, 10, 11, 12, 8, 9, 7, 1, 15)
PLAYER_FROM_SK = (0, 6, 10, 11, 12, 15, 13, 14, 4, 3, 5, 2, 7, 8, 9, 1)


def remap_pixels(raw, lookup):
    return bytes(lookup[b >> 4] << 4 | lookup[b & 15] for b in raw)


def remap_line(words, lookup):
    assert len(words) == 16 and sorted(lookup) == list(range(16))
    result = [0] * 16
    for old, new in enumerate(lookup):
        result[new] = words[old]
    return result


def remap_tile_bank(art, blocks, lookups):
    """Translate an imported terrain bank without changing its block IDs.

    Shared tile encodings are retained when equal, split only when a second
    palette use requires different pixels. Collision/chunk tables stay valid.
    """
    import struct
    identity = tuple(range(16))
    tiles = [art[i:i+32] for i in range(0, len(art), 32)]
    words = list(struct.unpack('>'+str(len(blocks)//2)+'H', blocks))
    owners = {}
    for word in words:
        tile, line = word & 2047, word >> 13 & 3
        if tile < len(tiles):
            owners.setdefault(tile, set()).add(line)
    ids = {}
    for tile, lines in owners.items():
        variants = {}
        for line in sorted(lines, key=lambda n: n in lookups):
            pixels = remap_pixels(art[tile*32:(tile+1)*32], lookups.get(line, identity))
            if pixels not in variants:
                slot = tile if not variants else len(tiles)
                if slot == len(tiles):
                    tiles.append(pixels)
                else:
                    tiles[slot] = pixels
                variants[pixels] = slot
            ids[tile, line] = variants[pixels]
    assert len(tiles) <= 2048
    result = [(w & 0xF800) | ids.get((w & 2047, w >> 13 & 3), w & 2047) for w in words]
    return b''.join(tiles), struct.pack('>'+str(len(result))+'H', *result)
