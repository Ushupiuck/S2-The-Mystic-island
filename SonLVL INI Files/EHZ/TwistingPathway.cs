using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Drawing;
using SonicRetro.SonLVL.API;
using System;

namespace S2ObjectDefinitions.EHZ
{
	class TwistingPathway : ObjectDefinition
	{
		private Sprite img;
		private Sprite sprite;
		private PropertySpec[] properties;

		public override void Init(ObjectData data)
		{
			BitmapBits marker = new BitmapBits(17, 17);
			marker.DrawRectangle(LevelData.ColorYellow, 0, 0, 16, 16);
			marker.DrawLine(LevelData.ColorWhite, 0, 8, 16, 8);
			marker.DrawLine(LevelData.ColorWhite, 8, 0, 8, 16);
			img = new Sprite(marker, -8, -8);
			properties = new[] {
				new PropertySpec("Path type", typeof(int), "Object settings", "EHZ spiral or the FBZ/MTZ horizontal wire cage.", 0,
					new Dictionary<string, int> { { "EHZ spiral", 0 }, { "FBZ/MTZ wire cage", 1 } },
					obj => (Subtype(obj) >> 7) & 1,
					(obj, value) => SetSubtype(obj, (Subtype(obj) & ~0x80) | (((int)value & 1) << 7))),
				new PropertySpec("Cage half-width", typeof(int), "Object settings", "Units of eight pixels, 0-127; zero uses MTZ's 192 pixels. Used only in cage mode.", 0,
					obj => Subtype(obj) & 0x7F,
					(obj, value) => SetSubtype(obj, (Subtype(obj) & ~0x7F) | ((int)value & 0x7F)))
			};
			List<Sprite> sprs = new List<Sprite>();
			int left = -208;
			int right = 208;
			int top = 0;
			int bottom = 0;
			for (int i = 0; i < TwistingPathway_CosineTable.Length; i++)
			{
				top = Math.Min(TwistingPathway_CosineTable[i], top);
				bottom = Math.Max(TwistingPathway_CosineTable[i], bottom);
			}
			Point offset = new Point(left, top);
			BitmapBits bmp = new BitmapBits(right - left, bottom - top);
			for (int x = 0; x < 0x1A0; x++)
			{
				int y = TwistingPathway_CosineTable[x] - top;
				if (x < bmp.Width & y >= 0 & y < bmp.Height)
					bmp[x, y] = LevelData.ColorYellow;
			}
			sprs.Add(new Sprite(bmp, offset));
			offset = new Point(-192, 0);
			bmp = new BitmapBits(0x180, 53);
			bmp.DrawLine(LevelData.ColorYellow, 192, 0, 192, 52);
			bmp.DrawLine(LevelData.ColorYellow, 0, 52, 0x180, 52);
			sprs.Add(new Sprite(bmp, offset));
			sprs.Add(img);
			sprite = new Sprite(sprs.ToArray());
		}

		public override ReadOnlyCollection<byte> Subtypes
		{
			get { return new ReadOnlyCollection<byte>(new byte[] { 0, 0x98 }); }
		}

		public override string Name
		{
			get { return "Twisting pathway / wire cage"; }
		}

		public override string SubtypeName(byte subtype)
		{
			return (subtype & 0x80) == 0 ? "EHZ spiral" : "FBZ/MTZ wire cage";
		}

		public override Sprite Image
		{
			get { return img; }
		}

		public override Sprite SubtypeImage(byte subtype)
		{
			return img;
		}

		private int[] TwistingPathway_CosineTable = {
	      32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, // 16
	      32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 31, 31, // 32
	      31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 30, 30, 30, // 48
	      30, 30, 30, 30, 30, 30, 29, 29, 29, 29, 29, 28, 28, 28, 28, 27, // 64
	      27, 27, 27, 26, 26, 26, 25, 25, 25, 24, 24, 24, 23, 23, 22, 22, // 80
	      21, 21, 20, 20, 19, 18, 18, 17, 16, 16, 15, 14, 14, 13, 12, 12, // 96
	      11, 10, 10,  9,  8,  8,  7,  6,  6,  5,  4,  4,  3,  2,  2,  1, //112
	       0, -1, -2, -2, -3, -4, -4, -5, -6, -7, -7, -8, -9, -9,-10,-10, //128
	     -11,-11,-12,-12,-13,-14,-14,-15,-15,-16,-16,-17,-17,-18,-18,-19, //144
	     -19,-19,-20,-21,-21,-22,-22,-23,-23,-24,-24,-25,-25,-26,-26,-27, //160
	     -27,-28,-28,-28,-29,-29,-30,-30,-30,-31,-31,-31,-32,-32,-32,-33, //176
	     -33,-33,-33,-34,-34,-34,-35,-35,-35,-35,-35,-35,-35,-35,-36,-36, //192
	     -36,-36,-36,-36,-36,-36,-36,-37,-37,-37,-37,-37,-37,-37,-37,-37, //208
	     -37,-37,-37,-37,-37,-37,-37,-37,-37,-37,-37,-37,-37,-37,-37,-37, //224
	     -37,-37,-37,-37,-36,-36,-36,-36,-36,-36,-36,-35,-35,-35,-35,-35, //240
	     -35,-35,-35,-34,-34,-34,-33,-33,-33,-33,-32,-32,-32,-31,-31,-31, //256
	     -30,-30,-30,-29,-29,-28,-28,-28,-27,-27,-26,-26,-25,-25,-24,-24, //272
	     -23,-23,-22,-22,-21,-21,-20,-19,-19,-18,-18,-17,-16,-16,-15,-14, //288
	     -14,-13,-12,-11,-11,-10, -9, -8, -7, -7, -6, -5, -4, -3, -2, -1, //304
	       0,  1,  2,  3,  4,  5,  6,  7,  8,  8,  9, 10, 10, 11, 12, 13, //320
	      13, 14, 14, 15, 15, 16, 16, 17, 17, 18, 18, 19, 19, 20, 20, 21, //336
	      21, 22, 22, 23, 23, 24, 24, 24, 25, 25, 25, 25, 26, 26, 26, 26, //352
	      27, 27, 27, 27, 28, 28, 28, 28, 28, 28, 29, 29, 29, 29, 29, 29, //368
	      29, 30, 30, 30, 30, 30, 30, 30, 31, 31, 31, 31, 31, 31, 31, 31, //384
	      31, 31, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, //400
	      32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, //416
										  };

		public override Sprite GetSprite(ObjectEntry obj)
		{
			if ((Subtype(obj) & 0x80) == 0) return sprite;
			int halfWidth = (Subtype(obj) & 0x7F) * 8;
			if (halfWidth == 0) halfWidth = 192;
			BitmapBits area = new BitmapBits(halfWidth * 2 + 1, 121);
			area.DrawRectangle(LevelData.ColorYellow, 0, 0, halfWidth * 2, 120);
			area.DrawLine(LevelData.ColorWhite, 0, 40, halfWidth * 2, 40);
			return new Sprite(new Sprite(area, -halfWidth, -80), img);
		}

		public override PropertySpec[] CustomProperties { get { return properties; } }
		private static int Subtype(ObjectEntry obj) { return ByteConverter.ToUInt16(obj.GetBytes(), 6); }
		private static void SetSubtype(ObjectEntry obj, int subtype)
		{
			byte[] data = obj.GetBytes();
			ByteConverter.GetBytes((ushort)subtype).CopyTo(data, 6);
			obj.FromBytes(data);
		}

		public override Rectangle GetBounds(ObjectEntry obj)
		{
			return new Rectangle(obj.X + img.X, obj.Y + img.Y, img.Width, img.Height);
		}

		public override bool Debug { get { return true; } }
	}
}