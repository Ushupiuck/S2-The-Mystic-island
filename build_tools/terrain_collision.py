"""Convert imported terrain to the project's single byte-index collision bank.

The bank and per-act index files remain ordinary editable binary inputs. This
helper is for importers: it finds existing profiles, compensates their flips in
block art/chunks, and rejects missing shapes rather than changing the bank.
"""
from collections import defaultdict
import struct

BANK_FILES = ('Collision array 1.bin', 'Collision array 2.bin',
              'Curve and resistance mapping.bin')
S1_BANK_FILES = ('Collision Array (Normal).bin', 'Collision Array (Rotated).bin',
                 'Angle Map.bin')


def read_bank(directory, names=BANK_FILES):
    heights, widths, angles = [(directory/name).read_bytes() for name in names]
    if len(heights) != len(widths) or len(heights) != len(angles)*16:
        raise ValueError('Collision bank has inconsistent dimensions')
    signed = lambda row: tuple(v if v < 128 else v-256 for v in row)
    return [(signed(heights[i*16:i*16+16]), signed(widths[i*16:i*16+16]), angle)
            for i, angle in enumerate(angles)]


def reflect(profile, flip):
    heights, widths, angle = profile
    if flip & 1:
        heights, widths, angle = heights[::-1], tuple(-v for v in widths), -angle & 255
    if flip & 2:
        heights, widths, angle = tuple(-v for v in heights), widths[::-1], 128-angle & 255
    # Both signs of a full 16px column/row cover the same pixels and produce
    # the same distances in our floor/wall probes. This is engine-specific;
    # CD's negative-height special cases are not being imported here.
    normalize = lambda row: tuple(16 if abs(v) == 16 else v for v in row)
    return normalize(heights), normalize(widths), angle


def profile_candidates(source_bank, target_bank, max_angle_change=0):
    lookup = defaultdict(list)
    for index, profile in enumerate(target_bank):
        if not index or not any(profile[0]+profile[1]):
            continue
        for flip in range(4):
            h, w, angle = reflect(profile, flip)
            lookup[h, w, bool(angle & 1)].append((index, flip, angle))
    candidates = {}
    for index, profile in enumerate(source_bank):
        if not index:
            candidates[index] = [(0, flip, 0) for flip in range(4)]
            continue
        h, w, angle = reflect(profile, 0)
        matches = []
        for target, flip, target_angle in lookup[h, w, bool(angle & 1)]:
            delta = 0 if angle & 1 else abs((angle-target_angle+128) % 256-128)
            if delta <= max_angle_change:
                matches.append((target, flip, delta))
        candidates[index] = sorted(matches, key=lambda m: (m[2], m[1] != 0, m[0]))
    return candidates


def remap_geometry(blocks, chunks, indices, source_bank, target_bank,
                   max_angle_change=0):
    """Return remapped blocks, chunks, index variants and per-block flips.

    A block has one art orientation, so both paths in every supplied act/time
    variant must agree on its compensating flip. Chunks may be concatenated
    when several chunk sets share the same block sheet.
    """
    if len(blocks) % 8 or len(chunks) % 128 or not indices:
        raise ValueError('Invalid block/chunk/index dimensions')
    count = len(indices[0])//2
    if any(len(c) != count*2 for c in indices) or count < len(blocks)//8:
        raise ValueError('Each block needs two collision indices in every variant')
    choices = profile_candidates(source_bank, target_bank, max_angle_change)
    blocks, chunks = bytearray(blocks), bytearray(chunks)
    indices = [bytearray(c) for c in indices]
    flips = {}
    for block in range(count):
        plans = []
        for flip in range(4):
            selected, cost = [], 0
            if block >= len(blocks)//8 and flip:
                continue
            for data in indices:
                pair = []
                for index in data[block*2:block*2+2]:
                    matches = [m for m in choices[index] if m[1] == flip]
                    if not matches:
                        break
                    target, _, delta = matches[0]
                    pair.append(target)
                    cost += delta
                if len(pair) != 2:
                    break
                selected.append(bytes(pair))
            if len(selected) == len(indices):
                plans.append((cost, flip != 0, flip, selected))
        if not plans:
            raise ValueError(f'Block ${block:X} has no compatible shared-bank orientation')
        _, _, flip, selected = min(plans)
        flips[block] = flip
        for data, pair in zip(indices, selected):
            data[block*2:block*2+2] = pair
        if block >= len(blocks)//8:
            continue
        words = list(struct.unpack_from('>4H', blocks, block*8))
        if flip & 1:
            words = [words[i] ^ 0x800 for i in (1, 0, 3, 2)]
        if flip & 2:
            words = [words[i] ^ 0x1000 for i in (2, 3, 0, 1)]
        struct.pack_into('>4H', blocks, block*8, *words)
    for offset in range(0, len(chunks), 2):
        word = struct.unpack_from('>H', chunks, offset)[0]
        # Preserve pre-existing opaque cells beyond the editable block sheet.
        word ^= flips.get(word & 0x3FF, 0) << 10
        struct.pack_into('>H', chunks, offset, word)
    return bytes(blocks), bytes(chunks), [bytes(c) for c in indices], flips
