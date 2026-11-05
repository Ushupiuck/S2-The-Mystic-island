using System;
using System.IO;
using System.Linq;
using KEHmusic;

class KosinskiPlusCheck
{
	static int checks;
	static void Check(byte[] packed, byte[] expected)
	{
		if (!expected.SequenceEqual(KosinskiPlus.Decode(packed, 0x4000)))
			throw new Exception("Kosinski+ output mismatch.");
		++checks;
	}

	static void Reject(byte[] packed, int limit = 0x4000)
	{
		try { KosinskiPlus.Decode(packed, limit); }
		catch (InvalidDataException) { ++checks; return; }
		throw new Exception("Invalid Kosinski+ stream was accepted.");
	}

	static void Main()
	{
		Check(new byte[] { 0x40, 0, 0, 0 }, new byte[0]);
		Check(new byte[] { 0xA0, 0x55, 0, 0, 0 }, new byte[] { 0x55 });
		for (int count = 2; count <= 5; ++count)
		{
			byte flags = (byte)(0x82 | (count - 2) << 3);
			Check(new byte[] { flags, 0x55, 0xFF, 0, 0, 0 }, Enumerable.Repeat((byte)0x55, count + 1).ToArray());
		}
		for (int count = 3; count <= 264; ++count)
		{
			byte high = (byte)(0xF8 | (count <= 9 ? 10 - count : 0));
			byte[] packed = count <= 9 ? new byte[] { 0xA8, 0x55, high, 0xFF, 0, 0, 0 } :
				new byte[] { 0xA8, 0x55, high, 0xFF, (byte)(count - 9), 0, 0, 0 };
			Check(packed, Enumerable.Repeat((byte)0x55, count + 1).ToArray());
		}
		Reject(new byte[0]);
		Reject(new byte[] { 0x40, 0, 0 });
		Reject(new byte[] { 0x40, 0, 0, 0, 1 });
		Reject(new byte[] { 0, 0xFF }); // copy before any output
		Reject(new byte[] { 0x80 }); // truncated literal
		Reject(new byte[] { 0xA0, 0x55, 0, 0, 0 }, 0);
		Reject(new byte[] { 0xA8, 0x55, 0xF8, 0xFF, 0xFF, 0, 0, 0 }, 264);
		var random = new Random(0x4B4F53);
		foreach (int size in new[] { 0, 1, 2, 3, 5, 9, 10, 17, 255, 256, 264, 265, 8191, 8192, 8193, 16384 })
		{
			var raw = new byte[size];
			random.NextBytes(raw);
			Check(KosinskiPlus.Encode(raw), raw);
			Array.Clear(raw, 0, size);
			Check(KosinskiPlus.Encode(raw), raw);
			for (int i = 0; i < size; ++i) raw[i] = (byte)((i * 7) % 29);
			Check(KosinskiPlus.Encode(raw), raw);
		}
		// A full-distance match begins exactly on the 8-KiB window boundary.
		var window = new byte[16384];
		random.NextBytes(window);
		Array.Copy(window, 0, window, 8192, 8192);
		Check(KosinskiPlus.Encode(window), window);
		Reject(KosinskiPlus.Encode(window), window.Length - 1);
		Console.WriteLine("Kosinski+: {0} cases; short/long/extended counts, overlap, window edges, 16-KiB encoder round trips and invalid streams.", checks);
	}
}
