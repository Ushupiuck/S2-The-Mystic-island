using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using SonicRetro.SonLVL.API;

namespace MysticIsland.LevelLayouts
{
	// Editable planes plus generated relative lookups. No absolute RAM addresses.
	public class Layout : LayoutFormatCombined
	{
		const int Header = 12, Plane = 576, Data = Header + Plane * 2;
		static ushort Word(byte[] data, int offset) { return (ushort)((data[offset] << 8) | data[offset + 1]); }
		static void Word(List<byte> data, int offset, int value) { data[offset] = (byte)(value >> 8); data[offset + 1] = (byte)value; }
		static void Append(List<byte> data, int value) { data.Add((byte)(value >> 8)); data.Add((byte)value); }

		public override void ReadLayout(byte[] raw, LayoutData layout)
		{
			if (raw.Length < Data || Word(raw, 0) != 0x504C || Word(raw, 2) != 2)
				throw new FormatException("Expected a version-2 Mystic Island plane layout.");
			var planes = new ushort[2][,];
			for (int n = 0; n < 2; n++)
			{
				int width = Word(raw, 4 + n * 4), height = Word(raw, 6 + n * 4), table = Header + n * Plane;
				if (width < 1 || width > 256 || height < 1 || height > 32) throw new FormatException("Invalid plane dimensions.");
				var cells = new ushort[width, height];
				for (int y = 0; y < height; y++)
				{
					int row = table + Word(raw, table + y * 2);
					if (row < Data || row + width * 2 > raw.Length) throw new FormatException("Plane row points outside its cell data.");
					for (int x = 0; x < width; x++) cells[x, y] = Word(raw, row + x * 2);
				}
				planes[n] = cells;
			}
			layout.FGLayout = planes[0]; layout.BGLayout = planes[1];
			byte[] expected; WriteLayout(layout, out expected);
			if (!raw.SequenceEqual(expected)) throw new FormatException("Damaged or noncanonical plane lookup tables.");
		}

		public override void WriteLayout(LayoutData layout, out byte[] raw)
		{
			var result = new List<byte>(new byte[Data]);
			Word(result, 0, 0x504C); Word(result, 2, 2);
			var planes = new[] { layout.FGLayout, layout.BGLayout };
			for (int n = 0; n < 2; n++)
			{
				var cells = planes[n]; int width = cells.GetLength(0), height = cells.GetLength(1), table = Header + n * Plane;
				if (width < 1 || width > 256 || height < 1 || height > 32) throw new FormatException("Planes must be 1..256 by 1..32 chunks.");
				Word(result, 4 + n * 4, width); Word(result, 6 + n * 4, height);
				int start = result.Count;
				for (int y = 0; y < height; y++)
				{
					for (int x = 0; x < width; x++)
					{
						if (cells[x, y] >= 0x400) throw new FormatException("Chunk ID exceeds the 1024-chunk CD bank.");
						Append(result, cells[x, y]);
					}
					if (n == 0) Append(result, 0);
				}
				int blank = result.Count;
				if (n == 0) result.AddRange(new byte[(width + 1) * 2]);
				for (int y = 0; y < 32; y++)
				{
					int row = n == 1 ? start + (y % height) * width * 2 : y < height ? start + y * (width + 1) * 2 : blank;
					Word(result, table + y * 2, row - table);
				}
				for (int x = 0; x < 256; x++) Word(result, table + 64 + x * 2, (n == 1 ? x % width : Math.Min(x, width)) * 2);
			}
			if (result.Count > MaxBytes) throw new FormatException("Layout exceeds its 32-KiB CD allocation.");
			raw = result.ToArray();
		}
		public override CompressionType DefaultCompression { get { return CompressionType.KosinskiPlus; } }
		public override bool IsResizable { get { return true; } }
		public override Size MaxSize { get { return new Size(256, 32); } }
		public override Size DefaultSize { get { return new Size(128, 16); } }
		public override int MaxBytes { get { return 0x8000; } }
	}
}
