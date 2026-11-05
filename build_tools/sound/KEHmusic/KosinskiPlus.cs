using System;
using System.Collections.Generic;
using System.IO;

namespace KEHmusic
{
	// Headerless Kosinski+; descriptors are MSB-first and the long zero count
	// terminates the stream. The host encoder has no Z80 segment-size limit.
	static class KosinskiPlus
	{
		// Minimum bit-cost parse: literal 9, short match 12, long match 18/26.
		// A two-byte hash chain finds all useful matches within the 8-KiB window.
		// Unlike p2bin's Z80-segment wrapper, input is not limited to Z80 RAM.
		public static byte[] Encode(byte[] data)
		{
			int size = data.Length;
			var previous = new int[size];
			var heads = new int[65536];
			for (int i = 0; i < heads.Length; ++i) heads[i] = -1;
			for (int i = 0; i < size; ++i)
			{
				previous[i] = -1;
				if (i + 1 == size) continue;
				int key = data[i] << 8 | data[i + 1];
				previous[i] = heads[key];
				heads[key] = i;
			}
			var costs = new int[size + 1];
			var counts = new int[size];
			var distances = new int[size];
			var shortDistances = new int[6];
			var longDistances = new int[265];
			for (int i = size - 1; i >= 0; --i)
			{
				costs[i] = costs[i + 1] + 9;
				counts[i] = 1;
				Array.Clear(shortDistances, 0, shortDistances.Length);
				Array.Clear(longDistances, 0, longDistances.Length);
				int limit = Math.Min(264, size - i), longest = 1, shortest = 1;
				for (int match = previous[i]; match >= 0 && i - match <= 8192; match = previous[match])
				{
					int count = 2, distance = i - match;
					while (count < limit && data[match + count] == data[i + count]) ++count;
					if (distance <= 256)
						while (shortest < Math.Min(5, count)) shortDistances[++shortest] = distance;
					while (longest < count) longDistances[++longest] = distance;
					if (longest == limit && (shortest == Math.Min(5, limit) || distance > 256)) break;
				}
				for (int count = 2; count <= longest; ++count)
				{
					int bits, distance;
					if (count <= 5 && shortDistances[count] != 0)
					{
						bits = 12; distance = shortDistances[count];
					}
					else if (count >= 3)
					{
						bits = count <= 9 ? 18 : 26; distance = longDistances[count];
					}
					else continue;
					if (bits + costs[i + count] <= costs[i])
					{
						costs[i] = bits + costs[i + count];
						counts[i] = count; distances[i] = distance;
					}
				}
			}
			var output = new List<byte>();
			int descriptor = 0, used = 8;
			Action<int> bit = value =>
			{
				if (used == 8) { descriptor = output.Count; output.Add(0); used = 0; }
				output[descriptor] |= (byte)(value << (7 - used++));
			};
			for (int i = 0; i < size; i += counts[i])
			{
				int count = counts[i], distance = distances[i];
				if (count == 1)
				{
					bit(1); output.Add(data[i]);
				}
				else if (count <= 5 && distance <= 256)
				{
					bit(0); bit(0); output.Add((byte)(-distance & 255));
					bit((count - 2) >> 1); bit((count - 2) & 1);
				}
				else
				{
					bit(0); bit(1);
					int offset = -distance & 8191;
					output.Add((byte)((offset >> 8) << 3 | (count <= 9 ? 10 - count : 0)));
					output.Add((byte)(offset & 255));
					if (count > 9) output.Add((byte)(count - 9));
				}
			}
			bit(0); bit(1); output.Add(0); output.Add(0); output.Add(0);
			return output.ToArray();
		}

		public static byte[] Decode(byte[] data, int outputLimit)
		{
			int position = 0, descriptor = 0, remaining = 0;
			var output = new List<byte>();
			Func<int> readByte = () =>
			{
				if (position == data.Length)
					throw new InvalidDataException("Truncated Kosinski+ stream.");
				return data[position++];
			};
			Func<int> readBit = () =>
			{
				if (remaining == 0) { descriptor = readByte(); remaining = 8; }
				int result = (descriptor >> 7) & 1;
				descriptor <<= 1;
				--remaining;
				return result;
			};
			while (true)
			{
				if (readBit() != 0)
				{
					if (output.Count == outputLimit)
						throw new InvalidDataException("Kosinski+ output exceeds the MD music buffer ($4000 bytes).");
					output.Add((byte)readByte());
					continue;
				}
				int offset, count;
				if (readBit() == 0)
				{
					offset = readByte() - 0x100;
					count = (readBit() << 1 | readBit()) + 2;
				}
				else
				{
					int high = readByte(), low = readByte();
					offset = ((high & 0xF8) << 5 | low) - 0x2000;
					count = high & 7;
					if (count == 0)
					{
						count = readByte();
						if (count == 0)
						{
							if (position != data.Length)
								throw new InvalidDataException("Trailing data after Kosinski+ end marker.");
							return output.ToArray();
						}
						count += 9;
					}
					else count = 10 - count;
				}
				if (offset < -output.Count)
					throw new InvalidDataException("Kosinski+ match precedes the start of the song.");
				if (count > outputLimit - output.Count)
					throw new InvalidDataException("Kosinski+ output exceeds the MD music buffer ($4000 bytes).");
				while (count-- != 0) output.Add(output[output.Count + offset]);
			}
		}
	}
}
