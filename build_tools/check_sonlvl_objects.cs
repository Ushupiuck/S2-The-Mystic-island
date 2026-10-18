// Compile alongside a current SonLVLAPI.dll; see SonLVL INI Files/README.md.
// Loads the actual editor definitions, including XML and CodeDOM compilation.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Linq;
using SonicRetro.SonLVL.API;

class CheckSonLVLObjects
{
	static int failures, placements, definitions, subtypes, properties;
	static string current;
	static readonly List<string> logs = new List<string>();
	static readonly HashSet<string> previewed = new HashSet<string>();

	static void Fail(string message)
	{
		Console.Error.WriteLine(current + ": " + message);
		failures++;
	}

	static bool IsUnknown(Sprite sprite)
	{
		return sprite.Size == LevelData.UnknownSprite.Size
			&& sprite.GetBitmap().Bits.SequenceEqual(LevelData.UnknownSprite.GetBitmap().Bits);
	}

	static void CheckImage(Sprite sprite, string context)
	{
		if (sprite == null || sprite.Width == 0 || sprite.Height == 0 || IsUnknown(sprite))
			Fail("Missing preview: " + context);
	}

	static void RoundTripProperties(ObjectDefinition definition, byte id)
	{
		IEnumerable<byte> values = definition.GetType().FullName == "MysticIsland.ObjectDefinitions.RuntimeObject"
			? Enumerable.Range(0, 256).Select(i => (byte)i) : definition.Subtypes;
		foreach (byte subtype in values)
			foreach (PropertySpec property in definition.CustomProperties)
			{
				ObjectEntry entry = new SonicRetro.SonLVL.API.S3K.S3KObjectEntry { ID = id, SubType = subtype, XFlip = true, YFlip = true, LoadAtAnyYPos = true };
				byte[] before = entry.GetBytes();
				object value = property.GetValue(entry);
				property.SetValue(entry, value);
				if (!entry.GetBytes().SequenceEqual(before))
					Fail("Property round trip changed $" + id.ToString("X2") + "/$" + subtype.ToString("X2") + " " + property.Name);
				properties++;
			}
	}

	static void Preview(string directory)
	{
		string list = string.Join("-", LevelData.Level.ObjectList ?? new string[0]);
		if (!previewed.Add(list)) return;
		List<KeyValuePair<byte, ObjectDefinition>> items = LevelData.ObjTypes.OrderBy(p => p.Key).ToList();
		const int columns = 4, width = 260, height = 160;
		using (Bitmap sheet = new Bitmap(columns * width, ((items.Count + columns - 1) / columns) * height))
		using (Graphics graphics = Graphics.FromImage(sheet))
		using (Font font = new Font(FontFamily.GenericSansSerif, 10))
		{
			graphics.Clear(Color.FromArgb(35, 39, 45));
			graphics.InterpolationMode = InterpolationMode.NearestNeighbor;
			graphics.PixelOffsetMode = PixelOffsetMode.Half;
			for (int i = 0; i < items.Count; i++)
			{
				var item = items[i];
				int x = (i % columns) * width, y = (i / columns) * height;
				graphics.DrawString("$" + item.Key.ToString("X2") + " " + item.Value.Name, font, Brushes.White, x + 8, y + 8);
				Sprite sprite = item.Value.Image;
				if (sprite.Width == 0 || sprite.Height == 0) continue;
				BitmapBits pixels = sprite.GetBitmap();
				// Explicit ARGB also works on libgdiplus, whose indexed bitmap
				// conversion can turn transparent palette entries opaque white.
				using (Bitmap image = new Bitmap(pixels.Width, pixels.Height))
				{
					for (int py = 0; py < pixels.Height; py++)
						for (int px = 0; px < pixels.Width; px++)
							image.SetPixel(px, py, pixels[px, py] == 0 ? Color.Transparent : Color.FromArgb(255, LevelData.BmpPal.Entries[pixels[px, py]]));
					float scale = Math.Min(2, Math.Min((width - 16f) / image.Width, (height - 36f) / image.Height));
					graphics.DrawImage(image, x + (width - image.Width * scale) / 2, y + 30 + (height - 36 - image.Height * scale) / 2, image.Width * scale, image.Height * scale);
				}
			}
			Directory.CreateDirectory(directory);
			sheet.Save(Path.Combine(directory, Path.GetFileNameWithoutExtension(list) + ".png"));
		}
	}

	static void CheckSwitcher()
	{
		var entry = new SonicRetro.SonLVL.API.S3K.S3KObjectEntry { ID = 3, SubType = 0xE9, XFlip = true };
		ObjectDefinition definition = LevelData.ObjTypes[3];
		definition.CustomProperties.Single(p => p.Name == "Direction").SetValue(entry, 1);
		if (entry.SubType != 0xED || !entry.XFlip) Fail("Switcher direction overwrote unrelated flags.");
		definition.CustomProperties.Single(p => p.Name == "Ground only").SetValue(entry, 0);
		if (entry.SubType != 0x6D) Fail("Switcher ground flag overwrote path/priority bits.");
		for (int size = 0; size < 4; size++)
		{
			entry.SubType = (byte)size;
			if (definition.GetSprite(entry).Height != 64 << size) Fail("Incorrect vertical switcher size.");
			entry.SubType |= 4;
			if (definition.GetSprite(entry).Width != 64 << size) Fail("Incorrect horizontal switcher size.");
		}
	}

	static void CheckBallhog()
	{
		ObjectDefinition definition = LevelData.ObjTypes[0x21];
		PropertySpec mode = definition.CustomProperties.Single(p => p.Name == "Behavior");
		PropertySpec lifetime = definition.CustomProperties.Single(p => p.Name == "Bomb lifetime (seconds)");
		// Boundary cases include the CMP.B/BPL extended range and $1F wrap.
		int[] values = { 0x0F, 0x10, 0x1E, 0x1F, 0x20, 0x30, 0x9E, 0x9F, 0xFF };
		int[] modes = { 0, 1, 2, 3, 3, 3, 3, 2, 2 };
		double[] seconds = { 15, 255 / 60.0, 14, 255, 0, 16, 126, 143, 239 };
		for (int i = 0; i < values.Length; i++)
		{
			ObjectEntry entry = new SonicRetro.SonLVL.API.S3K.S3KObjectEntry { ID = 0x21, SubType = (byte)values[i] };
			if ((int)mode.GetValue(entry) != modes[i] || (double)lifetime.GetValue(entry) != seconds[i]) Fail("Incorrect Ballhog settings for $" + values[i].ToString("X2"));
		}
		ObjectEntry moving = new SonicRetro.SonLVL.API.S3K.S3KObjectEntry { ID = 0x21, SubType = 0x11 };
		lifetime.SetValue(moving, 143.0);
		if (moving.SubType != 0x9F) Fail("Extended moving Ballhog lifetime did not encode correctly.");
	}

	static void CheckLevel(string name, string previewDirectory)
	{
		current = name;
		logs.Clear();
		LevelData.LoadLevel(name, true);
		foreach (string line in logs)
			if (line.Contains("Error") || line.Contains("failed") || line.Contains("not found")) Fail(line);
		foreach (var item in LevelData.ObjTypes)
		{
			ObjectDefinition definition = item.Value;
			string context = "$" + item.Key.ToString("X2") + " " + definition.Name;
			CheckImage(definition.Image, context);
			foreach (byte subtype in definition.Subtypes)
			{
				definition.SubtypeName(subtype);
				// Hidden bonus 0 intentionally has no graphic or award.
				if (!(item.Key == 0x7D && subtype == 0)) CheckImage(definition.SubtypeImage(subtype), context + "/$" + subtype.ToString("X2"));
				subtypes++;
			}
			RoundTripProperties(definition, item.Key);
			definitions++;
		}
		foreach (ObjectEntry entry in LevelData.Objects)
		{
			ObjectDefinition definition;
			if (!LevelData.ObjTypes.TryGetValue(entry.ID, out definition)) { Fail("Undefined placement $" + entry.ID.ToString("X2")); continue; }
			for (int flip = 0; flip < 4; flip++)
			{
				ObjectEntry copy = new SonicRetro.SonLVL.API.S3K.S3KObjectEntry(entry.GetBytes(), 0);
				copy.XFlip = (flip & 1) != 0;
				copy.YFlip = (flip & 2) != 0;
				CheckImage(definition.GetSprite(copy), "$" + entry.ID.ToString("X2") + "/$" + entry.SubType.ToString("X2"));
				definition.GetDebugOverlay(copy);
			}
			placements++;
		}
		bool terminator;
		byte[] original = File.ReadAllBytes(LevelData.Level.Objects);
		var entries = LevelData.ObjectFormat.ReadLayout(original, out terminator);
		if (!LevelData.ObjectFormat.WriteLayout(entries, terminator).SequenceEqual(original)) Fail("Object placement bytes did not round trip.");
		CheckSwitcher();
		CheckBallhog();
		if (previewDirectory != null) Preview(previewDirectory);
		Console.WriteLine("PASS " + name + " (" + LevelData.Objects.Count + " placements)");
	}

	static int Main(string[] args)
	{
		if (args.Length == 0) { Console.Error.WriteLine("Usage: check_sonlvl_objects.exe SonLVL.ini [preview-directory]"); return 2; }
		string ini = Path.GetFullPath(args[0]);
		string previewDirectory = args.Length > 1 ? Path.GetFullPath(args[1]) : null;
		LevelData.LogEvent += lines => logs.AddRange(lines);
		LevelData.LoadGame(ini);
		foreach (string name in LevelData.Game.Levels.Keys)
		{
			try { CheckLevel(name, previewDirectory); }
			catch (Exception exception) { Fail(exception.ToString()); }
		}
		Console.WriteLine("Checked " + LevelData.Game.Levels.Count + " acts, " + placements + " placements, " + definitions + " definitions, " + subtypes + " subtype previews and " + properties + " property round trips; " + failures + " failures.");
		return failures == 0 ? 0 : 1;
	}
}
