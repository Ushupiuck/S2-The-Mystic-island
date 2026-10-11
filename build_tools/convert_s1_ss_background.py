"""Convert the original S1 background sources to normal blocks and chunks.

Run from any directory with Python 3. The two Enigma files remain the editable
conversion sources; the game loads only the generated Kosinski+ files/layout.
Blocks use four tile words (TL, TR, BL, BR), chunks use 8x8 block words, and
each 512x256 layout is four by two chunk IDs. Tile palette/flip flags survive.
Bird/fish frames become animated art for one 64-tile bank; only the opaque,
bird and fish arrangements need foreground layouts.
"""
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parent.parent


def enigma(data, base):
    tile_bits, flags, increment, static = struct.unpack_from('>BBHH', data)
    increment = (increment + base) & 0xFFFF
    static = (static + base) & 0xFFFF
    position = 48

    def bits(count):
        nonlocal position
        value = 0
        for _ in range(count):
            value = (value << 1) | ((data[position // 8] >> (7 - position % 8)) & 1)
            position += 1
        return value

    def tile():
        properties = base
        for flag, value in zip((16, 8, 4, 2, 1), (0x8000, 0x4000, 0x2000, 0x1000, 0x800)):
            if flags & flag and bits(1):
                if flag in (16, 2, 1):
                    properties |= value
                else:
                    properties += value
        return (bits(tile_bits) + properties) & 0xFFFF

    output = []
    while True:
        if not bits(1):
            static_run = bits(1)
            count = bits(4) + 1
            if static_run:
                output.extend([static] * count)
            else:
                output.extend((increment + i) & 0xFFFF for i in range(count))
                increment = (increment + count) & 0xFFFF
        else:
            mode, count = bits(2), bits(4) + 1
            if mode == 3:
                if count == 16:
                    return output
                output.extend(tile() for _ in range(count))
            else:
                first = tile()
                step = (0, 1, -1)[mode]
                output.extend((first + step * i) & 0xFFFF for i in range(count))


def kosinski_plus(data):
    """Small greedy encoder; descriptors and bytes follow the game's decoder."""
    output = bytearray()
    descriptor = 0
    used = 8

    def bit(value):
        nonlocal descriptor, used
        if used == 8:
            descriptor = len(output)
            output.append(0)
            used = 0
        output[descriptor] |= value << (7 - used)
        used += 1

    position = 0
    while position < len(data):
        best_count, best_offset = 0, 0
        # Two-byte matches also include overlapping runs of a single byte.
        match = data.rfind(data[position:position + 2], max(0, position - 8192), position + 1)
        candidates = 0
        while match >= max(0, position - 8192) and match < position and candidates < 64:
            count = 0
            while count < min(256, len(data) - position) and data[match + count] == data[position + count]:
                count += 1
            if count > best_count:
                best_count, best_offset = count, position - match
            candidates += 1
            match = data.rfind(data[position:position + 2], max(0, position - 8192), match + 1)
        if best_count >= 2 and best_offset <= 256 and best_count <= 5:
            bit(0)
            bit(0)
            output.append((-best_offset) & 0xFF)
            bit((best_count - 2) >> 1)
            bit((best_count - 2) & 1)
        elif best_count >= 3:
            bit(0)
            bit(1)
            offset = (-best_offset) & 0x1FFF
            output.extend(((offset >> 8) << 3 | (10 - best_count if best_count <= 9 else 0), offset & 0xFF))
            if best_count > 9:
                output.append(best_count - 9)
        else:
            best_count = 1
            bit(1)
            output.append(data[position])
        position += best_count
    bit(0)
    bit(1)
    output.extend((0, 0, 0))
    return output


def kosinski_plus_decode(data, position=0):
    descriptor = remaining = 0
    output = bytearray()

    def byte():
        nonlocal position
        value = data[position]
        position += 1
        return value

    def bit():
        nonlocal descriptor, remaining
        if remaining == 0:
            descriptor, remaining = byte(), 8
        value = descriptor >> 7
        descriptor = descriptor << 1 & 255
        remaining -= 1
        return value

    while True:
        if bit():
            output.append(byte())
            continue
        if bit():
            high, low = byte(), byte()
            offset = ((high & 0xF8) << 5 | low) - 8192
            count = 10 - (high & 7)
            if high & 7 == 0:
                count = byte()
                if not count:
                    return bytes(output), position
                count += 9
        else:
            offset = byte() - 256
            count = 2 + bit() * 2 + bit()
        for _ in range(count):
            output.append(output[offset])


def moduled_art(path):
    data = path.read_bytes()
    size = struct.unpack_from('>H', data)[0]
    art, position = bytearray(), 2
    while len(art) < size:
        module, position = kosinski_plus_decode(data, position)
        art.extend(module)
    assert len(art) == size
    return bytes(art)


def baked_tile(art, word):
    tile = art[(word & 0x7FF) * 32:((word & 0x7FF) + 1) * 32]
    rows = [[nibble for byte in tile[y * 4:y * 4 + 4] for nibble in (byte >> 4, byte & 15)] for y in range(8)]
    if word & 0x800:
        rows = [row[::-1] for row in rows]
    if word & 0x1000:
        rows.reverse()
    return bytes(row[x] << 4 | row[x + 1] for row in rows for x in range(0, 8, 2))


def convert():
    frames = enigma((ROOT / 'tilemaps/BS Background 1.eni').read_bytes(), 0x4051)
    background = enigma((ROOT / 'tilemaps/BS Background 2.eni').read_bytes(), 0x4000)
    assert len(frames) == 8 * 64 and len(background) == 4096
    planes = []
    for frame in range(7):
        plane = [0] * 2048
        for y in range(32):
            for x in range(64):
                alternate = ((x // 8 + y // 8) & 1) ^ (frame < 4)
                if alternate or frame == 0:
                    source = frame + 1 if alternate else 0
                    plane[y * 64 + x] = frames[source * 64 + (y & 7) * 8 + (x & 7)]
        planes.append(plane)
    art = moduled_art(ROOT / 'art/Bonus & Special Stage/Bonus Clouds.kospm') + moduled_art(ROOT / 'art/Bonus & Special Stage/Bonus Birds & Fish.kospm')
    animated = bytearray()
    for frame in range(1, 7):
        for y in range(8):
            for x in range(8):
                word = planes[frame][y * 64 + x + (8 if frame >= 4 else 0)]
                assert word & 0xE000 == 0x6000
                animated.extend(baked_tile(art, word))
    # The transition tiles must cover the plane completely while maps/art load.
    transition = art[0x51 * 32:0x5A * 32]
    assert all(byte >> 4 and byte & 15 for byte in transition)
    template = []
    for fish in (False, True):
        template.append([0 if (((x // 8 + y // 8) & 1) ^ fish) else
                         0x605A + (y & 7) * 8 + (x & 7)
                         for y in range(32) for x in range(64)])
    planes = [planes[0], *template, background[:2048], background[2048:]]
    blocks = [(0, 0, 0, 0)]
    chunks = [(0,) * 64]
    layouts = bytearray()
    for plane in planes:
        for cy in range(2):
            for cx in range(4):
                chunk = []
                for by in range(8):
                    for bx in range(8):
                        index = (cy * 16 + by * 2) * 64 + cx * 16 + bx * 2
                        block = tuple(plane[index:index + 2] + plane[index + 64:index + 66])
                        if block not in blocks:
                            blocks.append(block)
                        chunk.append(blocks.index(block))
                chunk = tuple(chunk)
                if chunk not in chunks:
                    chunks.append(chunk)
                layouts.append(chunks.index(chunk))
    assert len(blocks) <= 0x300 and len(chunks) * 128 <= 0xA00
    block_data = b''.join(struct.pack('>4H', *block) for block in blocks)
    chunk_data = b''.join(struct.pack('>64H', *chunk) for chunk in chunks)
    (ROOT / 'mappings/16x16/S1 Special Stage BG.kosp').write_bytes(kosinski_plus(block_data))
    (ROOT / 'mappings/128x128/S1 Special Stage BG.kosp').write_bytes(kosinski_plus(chunk_data))
    (ROOT / 'level/layout/S1 Special Stage BG.bin').write_bytes(layouts)
    (ROOT / 'art/Bonus & Special Stage/Bonus BG Transition.kospm').write_bytes(struct.pack('>H', len(transition)) + kosinski_plus(transition))
    (ROOT / 'art/uncompressed/S1 Special Stage BG Animation.bin').write_bytes(animated)
    print(f'{len(blocks)} blocks ({len(block_data):#x} bytes), {len(chunks)} chunks ({len(chunk_data):#x} bytes), {len(layouts)} layout bytes')


if __name__ == '__main__':
    convert()
