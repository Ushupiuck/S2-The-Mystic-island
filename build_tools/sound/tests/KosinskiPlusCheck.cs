using System;
using System.IO;
using System.Linq;
using KEHmusic;

class KosinskiPlusCheck
{
	static int checks;
	static void Check(byte[] packed, byte[] expected)
	{
		if (!expected.SequenceEqual(KosinskiPlus.Decode(packed, 0xA40)))
			throw new Exception("Kosinski+ output mismatch.");
		++checks;
	}

	static void Reject(byte[] packed, int limit = 0xA40)
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
		Console.WriteLine("Kosinski+: {0} cases; short/long/extended counts, overlap, terminators and invalid streams.", checks);
	}
}
