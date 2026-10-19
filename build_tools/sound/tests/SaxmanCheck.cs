using System;
using System.IO;
using System.Linq;
using SonicRetro.KensSharp;

class SaxmanCheck
{
	static void Check(byte[] raw)
	{
		byte[] packed = Saxman.Compress(raw, true);
		if ((packed[0] | packed[1] << 8) != packed.Length - 2 || !raw.SequenceEqual(Saxman.Decompress(packed)))
			throw new Exception("Saxman round trip failed for " + raw.Length + " bytes.");
		using (var input = new MemoryStream(raw))
		using (var output = new MemoryStream())
		{
			output.Write(new byte[7], 0, 7);
			Saxman.Compress(input, output, true);
			if (output.Position != output.Length || !packed.SequenceEqual(output.ToArray().Skip(7)))
				throw new Exception("Saxman failed with a nonzero output position.");
		}
	}

	static void Main()
	{
		var random = new Random(0x534D5053);
		foreach (int length in Enumerable.Range(0, 36).Concat(new[] { 0xA40, 0xFEE, 0x1000, 0x1001, 0x1200 }))
		{
			Check(new byte[length]);
			byte[] raw = new byte[length];
			random.NextBytes(raw);
			Check(raw);
			for (int i = Math.Max(0, length - 17); i < length; i++) raw[i] = 0;
			Check(raw);
		}
		Console.WriteLine("Saxman: 123 cases, including trailing zeros, dictionary wrap, and nonzero output positions.");
	}
}
