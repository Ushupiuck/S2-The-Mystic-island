// Compile alongside a released SonLVLAPI.dll; see SonLVL INI Files/README.md.
// Loads the actual editor definitions, including XML and CodeDOM compilation.
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Globalization;
using System.IO;
using System.Linq;
using SonicRetro.SonLVL.API;

class CheckSonLVLObjects
{
	static int failures, placements, definitions, subtypes, properties;
	static string current;
	static readonly List<string> logs = new List<string>();
	static readonly HashSet<string> previewed = new HashSet<string>();

	class GridContext : ITypeDescriptorContext
	{
		public IContainer Container { get { return null; } }
		public object Instance { get; private set; }
		public PropertyDescriptor PropertyDescriptor { get; private set; }
		public GridContext(ObjectEntry entry, PropertyDescriptor property) { Instance = entry; PropertyDescriptor = property; }
		public object GetService(Type serviceType) { return null; }
		public bool OnComponentChanging() { return true; }
		public void OnComponentChanged() { }
	}

	static SonicRetro.SonLVL.API.S3K.S3KObjectEntry NewEntry(byte id, ushort subtype, bool xflip = false, bool yflip = false, bool anyY = false)
	{
		ObjectEntry entry = LevelData.ObjectFormat.CreateObject();
		entry.ID = id;
		entry.GetType().GetProperty("FullSubType").SetValue(entry, subtype, null);
		entry.XFlip = xflip;
		entry.YFlip = yflip;
		((SonicRetro.SonLVL.API.S3K.S3KObjectEntry)entry).LoadAtAnyYPos = anyY;
		return (SonicRetro.SonLVL.API.S3K.S3KObjectEntry)entry;
	}

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
		// Exercise the same descriptor/converter path as the property grid.
		// Direct getter/setter checks alone miss invalid enum converters.
		ObjectEntry gridEntry = NewEntry(id, definition.DefaultSubtype);
		PropertyDescriptorCollection descriptors = TypeDescriptor.GetProperties(gridEntry);
		foreach (PropertySpec property in definition.CustomProperties)
		{
			PropertyDescriptor descriptor = descriptors[property.Name];
			var context = new GridContext(gridEntry, descriptor);
			TypeConverter converter = descriptor.Converter;
			if (converter.GetStandardValuesSupported(context)) converter.GetStandardValues(context);
			object value = descriptor.GetValue(gridEntry);
			string text = converter.ConvertToString(context, CultureInfo.InvariantCulture, value);
			if (string.IsNullOrEmpty(text)) Fail("Blank property-grid value: $" + id.ToString("X2") + " " + property.Name);
			byte[] before = gridEntry.GetBytes();
			descriptor.SetValue(gridEntry, converter.ConvertFromString(context, CultureInfo.InvariantCulture, text));
			if (!gridEntry.GetBytes().SequenceEqual(before)) Fail("Property-grid conversion changed " + property.Name);
		}
		IEnumerable<byte> values = definition.GetType().Namespace == "MysticIsland.ObjectDefinitions"
			? Enumerable.Range(0, 256).Select(i => (byte)i) : definition.Subtypes;
		foreach (int upper in new[] { 0, 0xA500 })
		foreach (byte subtype in values)
			foreach (PropertySpec property in definition.CustomProperties)
			{
				ObjectEntry entry = NewEntry(id, (ushort)(upper | subtype), true, true, true);
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
		var entry = NewEntry(3, 0xE9, true);
		ObjectDefinition definition = LevelData.ObjTypes[3];
		if (definition.CustomProperties.Length != 7) Fail("Switcher settings did not load.");
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
		for (int subtype = 0; subtype < 256; subtype++)
		{
			entry.SubType = (byte)subtype;
			Sprite marker = definition.GetSprite(entry);
			if (marker.X != -marker.Width / 2 || marker.Y != -marker.Height / 2) Fail("Switcher marker is not centered.");
			if (marker.Strips.Any(strip => !strip.Priority)) Fail("Switcher marker can be hidden behind foreground art.");
			byte[] pixels = marker.GetBitmap().Bits;
			entry.XFlip = !entry.XFlip;
			entry.YFlip = !entry.YFlip;
			if (!pixels.SequenceEqual(definition.GetSprite(entry).GetBitmap().Bits)) Fail("Unused placement flips changed a switcher marker.");
			foreach (byte pathBit in new byte[] { 8, 16 })
			{
				entry.SubType = (byte)(subtype ^ pathBit);
				if (pixels.SequenceEqual(definition.GetSprite(entry).GetBitmap().Bits)) Fail("Switcher path numbers did not change with their bit.");
			}
		}
	}

	static void CheckDefinitionTypes()
	{
		var cacheNames = new HashSet<string>();
		foreach (var item in LevelData.INIObjDefs)
		{
			byte id;
			if (!byte.TryParse(item.Key, System.Globalization.NumberStyles.HexNumber, System.Globalization.CultureInfo.InvariantCulture, out id)
				|| item.Value.CodeFile == null) continue;
			string expected = item.Value.CodeType;
			if (!cacheNames.Add(expected)) Fail("Multiple objects compile into the same DLL cache: " + expected);
			ObjectDefinition definition;
			if (!LevelData.ObjTypes.TryGetValue(id, out definition) || definition.GetType().FullName != expected)
				Fail("Custom definition fell back or failed to load: $" + id.ToString("X2") + " expected " + expected);
		}
	}

	static void CheckConveyor()
	{
		ObjectDefinition definition = LevelData.ObjTypes[0xA2];
		for (int subtype = 0; subtype < 256; subtype++)
		{
			Sprite area = definition.SubtypeImage((byte)subtype);
			int width = ((subtype & 15) + 1) * 16, height = (subtype & 128) == 0 ? 48 : 112;
			if (area.Bounds != new Rectangle(-width / 2, -height, width, height)) Fail("Incorrect terrain-conveyor area.");
		}
		var entry = NewEntry(0xA2, 0xAF, false, true, true);
		definition.CustomProperties.Single(p => p.Name == "Width").SetValue(entry, 6);
		if (entry.SubType != 0xA6) Fail("Conveyor width changed its height or speed.");
		definition.CustomProperties.Single(p => p.Name == "Direction").SetValue(entry, 1);
		if (!entry.XFlip || !entry.YFlip || !entry.LoadAtAnyYPos || entry.SubType != 0xA6) Fail("Conveyor direction changed unrelated flags.");
	}

	static void CheckBallhog()
	{
		ObjectDefinition definition = LevelData.ObjTypes[0x21];
		PropertySpec mode = definition.CustomProperties.Single(p => p.Name == "Behavior");
		PropertySpec lifetime = definition.CustomProperties.Single(p => p.Name == "Bomb lifetime (seconds)");
		// Boundary cases include the word CMP/BPL range and word timer wrap.
		int[] values = { 0x0F, 0x10, 0x1E, 0x1F, 0x20, 0x30, 0x9E, 0x9F, 0xFF };
		int[] modes = { 0, 1, 2, 3, 3, 3, 3, 3, 3 };
		double[] seconds = { 15, 255 / 60.0, 14, 65476 / 60.0, 0, 16, 126, 127, 223 };
		for (int i = 0; i < values.Length; i++)
		{
			ObjectEntry entry = NewEntry(0x21, (ushort)values[i]);
			if ((int)mode.GetValue(entry) != modes[i] || (double)lifetime.GetValue(entry) != seconds[i]) Fail("Incorrect Ballhog settings for $" + values[i].ToString("X2"));
		}
		ObjectEntry moving = NewEntry(0x21, 0x11);
		lifetime.SetValue(moving, 143.0);
		if (moving.SubType != 0x1E) Fail("Moving Ballhog lifetime did not respect its packed mode range.");
	}

	static void CheckLevel(string name, string previewDirectory)
	{
		current = name;
		logs.Clear();
		LevelData.LoadLevel(name, true);
		foreach (string line in logs)
			if (line.Contains("Error") || line.Contains("failed") || line.Contains("not found")) Fail(line);
		CheckDefinitionTypes();
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
				ObjectEntry copy = LevelData.ObjectFormat.CreateObject();
				copy.FromBytes(entry.GetBytes());
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
		CheckConveyor();
		CheckPlatform();
		CheckWordLayout();
		if (previewDirectory != null) Preview(previewDirectory);
		Console.WriteLine("PASS " + name + " (" + LevelData.Objects.Count + " placements)");
	}

	static void CheckPlatform()
	{
		ObjectDefinition definition;
		if (!LevelData.ObjTypes.TryGetValue(0x18, out definition) || !definition.CustomProperties.Any(p => p.Name == "Switch channel")) return;
		var entry = NewEntry(0x18, 0x419E, true, true, true);
		byte[] original = entry.GetBytes();
		byte[] image = definition.GetSprite(entry).GetBitmap().Bits;
		string[] names = { "Switch channel", "Rider sag", "Phase / corner", "Interaction", "Movement", "Falling" };
		int[] values = { 15, 0, 3, 0, 5, 1 };
		ushort[] words = { 0xE19E, 0xE11E, 0xE11E, 0xE01E, 0xE015, 0xF015 };
		for (int i = 0; i < names.Length; i++)
		{
			definition.CustomProperties.Single(p => p.Name == names[i]).SetValue(entry, values[i]);
			byte[] actual = entry.GetBytes();
			if (SonicRetro.SonLVL.API.ByteConverter.ToUInt16(actual, 6) != words[i] || !actual.Take(6).SequenceEqual(original.Take(6))) Fail("Platform settings overlap: " + names[i]);
			if (!definition.GetSprite(entry).GetBitmap().Bits.SequenceEqual(image)) Fail("Platform settings changed its shape: " + names[i]);
		}
		for (int shape = 2; shape < 8; shape++)
		{
			var invalid = NewEntry(0x18, (ushort)(0xF180 | (shape << 4)));
			var fallback = NewEntry(0x18, 0xF180);
			if (!definition.GetSprite(invalid).GetBitmap().Bits.SequenceEqual(definition.GetSprite(fallback).GetBitmap().Bits)) Fail("Invalid platform shape differs from runtime fallback.");
		}
	}

	static void CheckWordLayout()
	{
		foreach (ushort subtype in new ushort[] { 0, 0xFF, 0x100, 0x1234, 0x8000, 0xFFFF })
		foreach (int era in Enumerable.Range(0, 8))
		{
			ObjectEntry entry = NewEntry(0xFC, subtype, true, true, true);
			var type = entry.GetType();
			type.GetProperty("ShowPresent").SetValue(entry, (era & 2) != 0, null);
			type.GetProperty("ShowPast").SetValue(entry, (era & 1) != 0, null);
			type.GetProperty("ShowFuture").SetValue(entry, (era & 4) != 0, null);
			byte[] bytes = entry.GetBytes();
			if (bytes.Length != 8 || bytes[4] != 0xFC || bytes[5] != era << 5 || bytes[6] != subtype >> 8 || bytes[7] != (subtype & 255))
				Fail("Incorrect eight-byte word subtype / timezone encoding.");
			bool terminator;
			var rows = LevelData.ObjectFormat.ReadLayout(LevelData.ObjectFormat.WriteLayout(new List<ObjectEntry> { entry }), out terminator);
			if (!terminator || rows.Count != 1 || !rows[0].GetBytes().SequenceEqual(bytes)) Fail("Word subtype did not round trip through layout I/O.");
			PropertyDescriptor field = TypeDescriptor.GetProperties(entry)["FullSubType"];
			var context = new GridContext(entry, field);
			string text = field.Converter.ConvertToString(context, CultureInfo.InvariantCulture, field.GetValue(entry));
			field.SetValue(entry, field.Converter.ConvertFromString(context, CultureInfo.InvariantCulture, text));
			if (!entry.GetBytes().SequenceEqual(bytes)) Fail("The 16-bit subtype property grid lost data.");
		}
	}

	static int Main(string[] args)
	{
		if (args.Length == 0) { Console.Error.WriteLine("Usage: check_sonlvl_objects.exe SonLVL.ini [preview-directory]"); return 2; }
		string ini = Path.GetFullPath(args[0]);
		string previewDirectory = args.Length > 1 ? Path.GetFullPath(args[1]) : null;
		LevelData.LogEvent += lines => { lock (logs) logs.AddRange(lines); };
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
