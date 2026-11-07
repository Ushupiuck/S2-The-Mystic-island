using System;
using System.Collections.Generic;
using System.IO;

namespace KEHmusic
{
	// Headerless Kosinski+; descriptors are MSB-first and the long zero count
	// terminates the stream. Encoding is supplied by the bundled p2bin tool.
	static class KosinskiPlus
	{
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
						throw new InvalidDataException("Kosinski+ output exceeds the Z80 music buffer ($A40 bytes).");
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
					throw new InvalidDataException("Kosinski+ output exceeds the Z80 music buffer ($A40 bytes).");
				while (count-- != 0) output.Add(output[output.Count + offset]);
			}
		}
	}
}
