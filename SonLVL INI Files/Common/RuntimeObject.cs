using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Drawing;
using System.IO;
using System.Linq;
using SonicRetro.SonLVL.API;

namespace MysticIsland.ObjectDefinitions
{
	// IDs and assets are supplied by the per-zone lists. Subtype controls below
	// follow this project's handlers, including its imported and custom objects.
	public class RuntimeObject : ObjectDefinition
	{
		private ObjectData data;
		private string behavior;
		private Sprite[] frames, alternate, scenery;
		private byte[] groups, routes;
		private readonly List<PropertySpec> properties = new List<PropertySpec>();

		public override void Init(ObjectData definition)
		{
			data = definition;
			behavior = Setting("behavior", "Static");
			LevelData.Log("Loading Mystic Island object: " + data.Name);
			if (data.Art != null)
			{
				MultiFileIndexer<byte> art = new MultiFileIndexer<byte>();
				foreach (SonicRetro.SonLVL.API.FileInfo file in data.Art)
					art.AddFile(new List<byte>(ObjectHelper.OpenArtFile(file.Filename, data.ArtCompression)), file.Offset);
				byte[] map = data.MapFile != null ? LevelData.ReadFile(data.MapFile, data.MapCompression)
					: data.MapAsmLabel == null ? LevelData.ASMToBin(data.MapFileAsm, data.MapVersion)
					: LevelData.ASMToBin(data.MapFileAsm, data.MapAsmLabel, data.MapVersion);
				byte[] dplc = data.DPLCFileAsm == null ? null : LevelData.ASMToBin(data.DPLCFileAsm, data.DPLCVersion);
				byte[] pixels = art.ToArray();
				if (behavior == "Junction")
				{
					// Gap angle 0 starts immediately after the padded static atlas.
					int gapOffset = pixels.Length;
					Array.Resize(ref pixels, gapOffset + 4 * 32);
					Array.Copy(File.ReadAllBytes("../art/uncompressed/SMZ Junction Gap.unc"), 0, pixels, gapOffset, 4 * 32);
				}
				frames = Render(pixels, map, data.Palette, dplc, data.DPLCVersion, int.Parse(Setting("mapframes", "0")));
			}
			else frames = new[] { Outline(16, 16) };

			switch (behavior)
			{
				case "PathSwapper":
					LoadPathSwapperMarkers();
					Bits("Length", 0, 3, "Full length; the runtime tests half this distance on either side of the origin.", "64 pixels", "128 pixels", "256 pixels", "512 pixels");
					Bits("Direction", 2, 1, "Placement flip flags are not used by the runtime.", "Vertical (cross left/right)", "Horizontal (cross up/down)");
					Bits("Right / down path", 3, 1, "Collision path after crossing right or down.", "Primary ($C / $D)", "Secondary ($E / $F)");
					Bits("Left / up path", 4, 1, "Collision path after crossing left or up.", "Primary ($C / $D)", "Secondary ($E / $F)");
					Bits("Right / down priority", 5, 1, "Sprite priority after crossing right or down.", "Low", "High");
					Bits("Left / up priority", 6, 1, "Sprite priority after crossing left or up.", "Low", "High");
					Bits("Ground only", 7, 1, "Ignore airborne characters.", "No", "Yes");
					break;
				case "Bridge": Bits("Length", 0, 255, "Number of 16-pixel bridge logs. Existing layouts use 8 to 16."); break;
				case "Platform":
					Bits("Movement", 0, 15, "Movement table in objects/18 Platforms.asm. Distances are full travel. Type 3 waits 30 frames before falling; type 7 waits 60 frames after switch 0.", "Stationary", "Horizontal (128 px)", "Vertical (128 px)", "Fall when stood on (30-frame delay)", "Falling (internal)", "Horizontal (128 px), reversed", "Vertical (128 px), reversed", "Switch 0: rise 512 px", "Rising 512 px (internal)", "Stationary (type 9)", "Vertical (64 px)", "Vertical (64 px), reversed", "Vertical (96 px)", "Vertical (96 px), reversed");
					Bits("Shape", 4, 7, "Mapping / collision configuration. Choose only frames present in this zone's mapping set.", Enumerable.Range(0, Math.Min(5, frames.Length)).Select(i => "Frame " + i).ToArray());
					Bits("Alternate solidity", 7, 1, "Selects the tall platform routine. Note: the current initialization also includes this bit in its shape index.", "Off", "On");
					break;
				case "MovingBlock":
				case "CPZPlatform":
					Bits("Movement", 0, 15, "Low-nibble movement routine. X flip reverses oscillation phase and fast-slide direction.", "Stationary", "Horizontal (96 px)", "Move right when stood on", "Move right, stop at wall (internal)", "Move right when stood on, then fall at wall", "Move right, fall at wall (internal)", "Falling (internal)", "Switch 2 raft (LZ1)", "Vertical (128 px)", "Fast slide when stood on", "Fast sliding (internal)");
					Bits("Shape", 4, 15, "Mapping / collision configuration. Only frames 0 to 4 have configuration entries.", Enumerable.Range(0, Math.Min(5, frames.Length)).Select(i => "Frame " + i).ToArray());
					break;
				case "BallHog":
					alternate = Load("../art/moduled kosinski/Enemy Ballhog (Vertical).kospm", CompressionType.KosinskiPlusM, "Vertical Ballhog.bin", 1);
					properties.Add(new PropertySpec("Behavior", typeof(int), "Ballhog", "$00-$0F horizontal; $10 timed vertical; $11-$1E and $9F-$FF moving vertical; $1F-$9E stationary vertical. $1F is a runtime underflow edge case.", null,
						Choices("Horizontal", "Vertical, timed", "Vertical, moving", "Vertical, stationary"), obj => HogMode(obj.SubType),
						(obj, value) => { int mode = (int)value; if (mode != HogMode(obj.SubType)) obj.SubType = HogSubtype(mode, Convert.ToInt32(BombSeconds(obj.SubType))); }));
					properties.Add(new PropertySpec("Bomb lifetime (seconds)", typeof(double), "Ballhog", "Delay * 60 frames. Timed mode $10 uses a fixed 255-frame value; $1F underflows to 255 seconds.", null,
						obj => BombSeconds(obj.SubType),
						(obj, value) => { int mode = HogMode(obj.SubType); if (mode != 1 && Convert.ToDouble(value) != BombSeconds(obj.SubType)) obj.SubType = HogSubtype(mode, Convert.ToInt32(value)); }));
					break;
				case "Swing":
					Bits("Chain length", 0, 15, "Number of 16-pixel links; suspended object rests 8 pixels beyond the chain.");
					Bits("Family", 4, 15, "Custom movement families in objects/17 Swinging Platforms.asm.", "Normal", "Bounce left", "Static", "Bounce right", "Trap", "Ball with solid top", "Detachable", "Full spikeball");
					if (Setting("atlas", "false") != "true") alternate = Load("../art/nemesis/S1/GHZ Giant Ball.nem", CompressionType.Nemesis, "Giant Ball.bin", 2);
					break;
				case "Scenery":
					scenery = new[] {
						Load("../art/nemesis/HPZ bridge.nem", CompressionType.Nemesis, "obj1D_HPZ.bin", 3)[3],
						Load("../art/nemesis/HPZ Pulsing Ball.nem", CompressionType.Nemesis, "HPZ Pulsing Orb.bin", 3)[0],
						Load("../art/nemesis/EHZ bridge.nem", CompressionType.Nemesis, "obj1D_EHZ.bin", 2)[1],
						Load("../art/nemesis/S1/GHZ Bridge.nem", CompressionType.Nemesis, "obj1D_GHZ.bin", 2)[1],
						Load("../art/nemesis/HTZ zip-line platform.nem", CompressionType.Nemesis, "HTZ Descending lift.bin", 2)[3],
						Load("../art/nemesis/HTZ zip-line platform.nem", CompressionType.Nemesis, "HTZ Descending lift.bin", 2)[4],
						Load("../art/nemesis/HTZ zip-line platform.nem", CompressionType.Nemesis, "HTZ Descending lift.bin", 2)[1] };
					Bits("Appearance", 0, 15, "Index into Obj1C_SubtypeConfig.", "HPZ bridge decoration", "HPZ pulsing orb", "EHZ bridge stake", "GHZ bridge stake", "Lift stake, frame 3", "Lift stake, frame 4", "Lift stake, frame 1");
					Bits("Animation", 4, 15, "Upper nibble selects the scenery animation.", "Stationary", "Animation 0", "Animation 1");
					break;
				case "Newtron":
					alternate = Load("../art/moduled kosinski/Enemy Newtron.kospm", CompressionType.KosinskiPlusM, "Newtron.asm", 1);
					Bits("Behavior", 0, 255, "Custom third variant uses Newtron_Type03.", "Blue: ground runner", "Green: missile, then vanish", "Green: hybrid"); break;
				case "Caterkiller":
					alternate = Load("../art/nemesis/Enemy Kemusi.nem", CompressionType.Nemesis, "Kemusi.bin", 1);
					Bits("Variant", 0, 255, "The level must load the matching art bank. Scrap Madness Act 1 loads Caterkiller; Act 2 loads both families. Damaged Kemusi has a vulnerable body and moves at half speed.", "Caterkiller", "Kemusi", "Damaged Kemusi");
					break;
				case "Chopper": Bits("Jump velocity", 0, 255, "Index into the eight-entry jump-speed table.", "-$400", "-$480", "-$500", "-$580", "-$600", "-$680", "-$700", "-$780"); break;
				case "Jaws": Bits("Turn interval", 0, 255, "Subtype * 64 - 1 frames; zero wraps to $FFFF."); break;
				case "Piranha": Bits("Patrol interval", 0, 15, "Low nibble * 64 - 1 frames."); Bits("Jump interval", 4, 15, "High nibble * 64 frames."); break;
				case "Aquis": Bits("Patrol interval", 0, 15, "Low nibble * 16 - 1 frames."); Bits("Firing interval", 4, 15, "High nibble * 256 frames."); break;
				case "Skyhorse": Bits("Patrol interval", 0, 15, "Low nibble * 32 - 1 frames; vertical range is 96 pixels."); break;
				case "EdgeWall": Bits("Appearance", 0, 15, "Low nibble selects the mapping frame.", "Wall with top", "Wall", "Terrain cap"); Bits("Non-solid", 4, 1, "Bit 4 disables collision.", "Solid", "Non-solid"); break;
				case "BreakableWall":
				case "Collapse": Bits("Appearance", 0, 255, "The runtime copies the subtype directly into the mapping frame."); break;
				case "Capsule": Bits("Part", 0, 255, "Body and button are separate placements.", "Body", "Button"); break;
				case "Checkpoint": Bits("Checkpoint number", 0, 255, "Identifier stored when activated."); break;
				case "Bonus": Bits("Points", 0, 255, "End-of-level hidden bonus.", "No points", "10000 points", "1000 points", "100 points"); break;
				case "Lift": Bits("Travel duration", 0, 255, "Subtype * 8 frames: moves 16 * subtype pixels horizontally and 8 * subtype pixels down before falling. X flip reverses horizontal travel."); break;
				case "HPZWaterfall": Bits("Height", 0, 255, "Waterfall top = origin Y - 120 + subtype * 16 pixels, clamped to water. Values $10 and above add a second stream."); break;
				case "EHZWaterfall": Bits("Configuration", 0, 255, "Waterfall configuration from object 49."); break;
				case "FlapDoor": Bits("Interval (seconds)", 0, 255, "The entire subtype is multiplied by 60 frames between opening and closing."); break;
				case "Tilt": Bits("Duration", 4, 15, "Tilt duration = (value + 1) * 16 frames."); Bits("Phase", 0, 15, "Initial phase = (value + 1) * 16 frames."); break;
				case "Bubbles": Bits("Generator", 7, 1, "Set for a bubble generator; clear for an individual bubble.", "Individual bubble", "Generator"); Bits("Frequency / size", 0, 127, "Generator frequency, or animation ID for an individual bubble."); break;
				case "Junction": Bits("Switch number", 0, 15, "Button that reverses junction rotation."); break;
				case "RunningDisc": Bits("Radius", 0, 15, "Zero: 24-pixel spot orbit / 72-pixel trigger. Nonzero: 16-pixel orbit / 56-pixel trigger."); SignedNibble("Rotation speed", "High nibble scaled by $80 angular units."); break;
				case "Conveyor":
					Bits("Width", 0, 15, "Full width = (value + 1) * 16 pixels.", Enumerable.Range(1, 16).Select(i => i * 16 + " pixels").ToArray());
					Bits("Speed (pixels/frame)", 4, 7, "Speed magnitude; X flip selects leftward travel.");
					Bits("Height", 7, 1, "The area extends upward from its placement Y.", "48 pixels", "112 pixels");
					properties.Add(new PropertySpec("Direction", typeof(int), "Object settings", "Placement X flip reverses the belt.", null,
						Choices("Right", "Left"), obj => obj.XFlip ? 1 : 0, (obj, value) => obj.XFlip = (int)value != 0));
					break;
				case "SpinTrap":
					alternate = Load("../art/nemesis/SMZ Sprite Atlas.nem", CompressionType.Nemesis, "SMZ Trap.bin", 0);
					Bits("Type", 7, 1, "Selects two different objects and mapping sets.", "Trapdoor", "Spinning platform");
					Bits("Delay / phase", 0, 15, "Trapdoor: interval * 60 frames. Spin platform: initial phase * 6 frames.");
					Bits("Spin period", 4, 7, "Sync mask = (value + 1) * 64 - 1. Original patterns use 0, 1, 3 or 7."); break;
				case "Saw": Bits("Movement", 0, 7, "Saw movement routine.", "Stationary cutter", "Horizontal cutter (96 px)", "Vertical cutter (48 px)", "Speeding saw from left", "Speeding saw from right"); break;
				case "Stomper":
					Bits("Shape", 4, 7, "Size / frame configuration.", "Sliding block (128 x 24)", "Stomper (56 x 64)", "Stomper, 64 px travel", "Stomper, 96 px travel", "Large lift (256 x 128)");
					Bits("Switch controlled", 7, 1, "When set, low nibble = switch; otherwise low nibble = movement.", "No", "Yes");
					Bits("Movement / switch", 0, 15, "Button number when switch controlled; movement type 0 to 5 otherwise."); break;
				case "Vanish": Bits("Duration", 0, 15, "Visible duration = (value + 1) * 128 frames; invisible transition = 128 frames."); Bits("Phase", 4, 15, "Sync offset = phase * (duration + 2) * 8 frames."); break;
				case "Flame": Bits("Off duration", 0, 15, "Low nibble * 32 frames."); Bits("On duration", 4, 15, "High nibble * 32 frames. Y flip selects the sideways flame mapping."); break;
				case "Electro": Bits("Period mask", 0, 255, "Sync mask = subtype * 16 - 1; use a power of two for a regular interval."); break;
				case "SpinGroup":
					groups = ReadWordTable("../objects/Scrap Madness/A9 Spin Conveyor.asm", "SMZ_SpinC_Placements");
					Bits("Group", 0, 127, "Absolute-position group 0 to 5. Moving the spawner does not move the runtime's hardcoded group.");
					Bits("Group spawner", 7, 1, "Set for level placements; clear is an individual moving child.", "Individual child", "Eight-platform group"); break;
				case "Teleporter":
					routes = ReadWordTable("../objects/Scrap Madness/AB Teleporter.asm", "SMZ_PipeData");
					Bits("Route", 0, 7, "SMZ_PipeData uses absolute destinations; route 7 requires 50 rings.", "Route 0", "Route 1", "Route 2", "Route 3", "Route 4", "Route 5", "Route 6", "Route 7 (50 rings)"); break;
				case "InvisibleSolid": Bits("Width", 4, 15, "Full width = (value + 1) * 16 pixels."); Bits("Height", 0, 15, "Full height = (value + 1) * 16 pixels."); break;
				case "Button": Bits("Switch number", 0, 15, "Sets the corresponding f_switch entry."); break;
			}
		}

		private string Setting(string key, string fallback)
		{
			string value;
			return data.CustomProperties != null && data.CustomProperties.TryGetValue(key, out value) ? value : fallback;
		}
		private static Dictionary<string, int> Choices(params string[] names)
		{
			Dictionary<string, int> result = new Dictionary<string, int>();
			for (int i = 0; i < names.Length; i++) result.Add(names[i], i);
			return result;
		}
		private void Bits(string name, int shift, int mask, string description, params string[] names)
		{
			Func<ObjectEntry, object> get = obj => (obj.SubType >> shift) & mask;
			Action<ObjectEntry, object> set = (obj, value) => obj.SubType = (byte)((obj.SubType & ~(mask << shift)) | (((int)value & mask) << shift));
			// The enum overload always installs StringEnumConverter, even for a
			// null dictionary. Numeric fields need the ordinary int converter.
			properties.Add(names.Length == 0
				? new PropertySpec(name, typeof(int), "Object settings", description, null, get, set)
				: new PropertySpec(name, typeof(int), "Object settings", description, null, Choices(names), get, set));
		}
		private void SignedNibble(string name, string description)
		{
			properties.Add(new PropertySpec(name, typeof(int), "Object settings", description, null,
				obj => ((obj.SubType >> 4) & 7) - ((obj.SubType >> 4) & 8),
				(obj, value) => obj.SubType = (byte)((obj.SubType & 15) | (((int)value & 15) << 4))));
		}
		private static int HogMode(int subtype)
		{
			// The handler branches on N after a byte CMP, rather than unsigned
			// carry: its moving mode also includes the upper $9F-$FF range.
			return subtype < 0x10 ? 0 : subtype == 0x10 ? 1 : ((subtype - 0x1F) & 0x80) == 0 ? 3 : 2;
		}
		private static double BombSeconds(int subtype)
		{
			int mode = HogMode(subtype);
			return mode == 0 ? subtype : mode == 1 ? 255 / 60.0 : mode == 2 ? subtype - 0x10 : (subtype - 0x20) & 255;
		}
		private static byte HogSubtype(int mode, int seconds)
		{
			if (mode == 0) return (byte)Math.Max(0, Math.Min(15, seconds));
			if (mode == 1) return 0x10;
			if (mode == 2) return (byte)(0x10 + (seconds >= 143 ? Math.Min(239, seconds) : Math.Max(1, Math.Min(14, seconds))));
			return seconds == 255 ? (byte)0x1F : (byte)(0x20 + Math.Max(0, Math.Min(126, seconds)));
		}
		private static Sprite[] Render(byte[] art, byte[] mappings, int palette, byte[] dplc, EngineVersion dplcVersion = EngineVersion.S2, int frameCount = 0)
		{
			MappingsFrame[] maps = frameCount == 0 ? MappingsFrame.Load(mappings, EngineVersion.S3K).ToArray()
				: Enumerable.Range(0, frameCount).Select(i => new MappingsFrame(mappings, ByteConverter.ToUInt16(mappings, i * 2), EngineVersion.S3K, "frame" + i)).ToArray();
			DPLCFrame[] cues = dplc == null ? null : DPLCFrame.Load(dplc, dplcVersion).ToArray();
			Sprite[] result = new Sprite[maps.Length];
			for (int i = 0; i < result.Length; i++) result[i] = cues == null ? LevelData.MapFrameToBmp(art, maps[i], palette) : LevelData.MapFrameToBmp(art, maps[i], cues[i], palette);
			return result;
		}
		private static Sprite[] Load(string art, CompressionType compression, string map, int palette)
		{
			string filename = "../mappings/sprite/" + map;
			return Render(ObjectHelper.OpenArtFile(art, compression), Path.GetExtension(map) == ".asm" ? LevelData.ASMToBin(filename, EngineVersion.S3K) : File.ReadAllBytes(filename), palette, null);
		}
		private static Sprite At(Sprite[] sprites, int frame) { return sprites[Math.Max(0, Math.Min(sprites.Length - 1, frame))]; }

		// SonLVL's mapping parser treats numeric subtraction as a label offset and
		// cannot evaluate multiplication. These runtime tables use both (8-1, 7*4).
		// Read their word directives directly so editor previews follow ASM edits.
		private static byte[] ReadWordTable(string filename, string startLabel)
		{
			Dictionary<string, int> labels = new Dictionary<string, int>();
			List<string> words = new List<string>();
			bool started = false;
			foreach (string source in File.ReadAllLines(filename))
			{
				string line = source.Split(';')[0].Trim();
				if (!started) { if (!line.StartsWith(startLabel + ":")) continue; started = true; }
				int colon = line.IndexOf(':');
				if (colon >= 0) { labels.Add(line.Substring(0, colon), words.Count * 2); line = line.Substring(colon + 1).Trim(); }
				if (line.Length == 0 || line == "even") continue;
				if (!line.StartsWith("dc.w")) throw new InvalidDataException("Unexpected word-table directive in " + filename + ": " + line);
				words.AddRange(line.Substring(4).Split(',').Select(value => value.Trim()));
			}
			if (!started) throw new InvalidDataException("Missing table " + startLabel + " in " + filename);
			return words.SelectMany(word => ByteConverter.GetBytes(unchecked((ushort)WordValue(word, labels)))).ToArray();
		}
		private static int WordValue(string value, Dictionary<string, int> labels)
		{
			int split = value.IndexOf('-', 1);
			if (split > 0) return WordValue(value.Substring(0, split), labels) - WordValue(value.Substring(split + 1), labels);
			if ((split = value.IndexOf('+')) > 0) return WordValue(value.Substring(0, split), labels) + WordValue(value.Substring(split + 1), labels);
			if ((split = value.IndexOf('*')) > 0) return WordValue(value.Substring(0, split), labels) * WordValue(value.Substring(split + 1), labels);
			int result;
			return labels.TryGetValue(value, out result) ? result : value.StartsWith("$") ? Convert.ToInt32(value.Substring(1), 16) : int.Parse(value);
		}
		private static Sprite Outline(int width, int height)
		{
			BitmapBits bitmap = new BitmapBits(width, height);
			bitmap.DrawRectangle(LevelData.ColorYellow, 0, 0, width - 1, height - 1);
			bitmap.DrawLine(LevelData.ColorWhite, width / 2 - 3, height / 2, width / 2 + 3, height / 2);
			bitmap.DrawLine(LevelData.ColorWhite, width / 2, height / 2 - 3, width / 2, height / 2 + 3);
			return new Sprite(bitmap, -width / 2, -height / 2);
		}
		private void LoadPathSwapperMarkers()
		{
			// SonLVL's S3&K marker art numbers each side's collision path.
			// Repeat the 64-pixel unit to show the full runtime trigger length.
			byte[] art = ObjectHelper.OpenArtFile("Common/pathswapper-art.nem", CompressionType.Nemesis);
			frames = new Sprite[32];
			for (int subtype = 0; subtype < frames.Length; subtype++)
			{
				byte[] tile = art.Skip((subtype & 0x1C) << 5).Take(128).ToArray();
				BitmapBits unit = ObjectHelper.MapASMToBmp(tile, "../mappings/sprite/obj03.asm", subtype & 4, 0).GetBitmap();
				bool horizontal = (subtype & 4) != 0;
				int repeat = 1 << (subtype & 3);
				BitmapBits marker = new BitmapBits(unit.Width * (horizontal ? repeat : 1), unit.Height * (horizontal ? 1 : repeat));
				for (int i = 0; i < repeat; i++) marker.DrawBitmap(unit, horizontal ? i * unit.Width : 0, horizontal ? 0 : i * unit.Height);
				frames[subtype] = new Sprite(marker, true, -marker.Width / 2, -marker.Height / 2);
			}
		}

		private Sprite Preview(byte subtype, int x, int y, bool yflip)
		{
			List<Sprite> pieces;
			switch (behavior)
			{
				case "PathSwapper": return frames[subtype & 0x1F];
				case "Bridge":
					pieces = new List<Sprite>();
					int count = Math.Max(1, (int)subtype);
					for (int i = 0; i < count; i++) pieces.Add(new Sprite(frames[0], i * 16 - count * 8, 0));
					return new Sprite(pieces);
				case "Swing":
					pieces = new List<Sprite> { new Sprite(At(frames, 2)) };
					int links = subtype & 15;
					for (int i = 1; i < links; i++) pieces.Add(new Sprite(At(frames, 1), 0, i * 16));
					pieces.Add(new Sprite(alternate != null && ((subtype & 0xE0) == 0x40 || (subtype & 0xF0) == 0x70) ? At(alternate, 1) : frames[0], 0, links * 16 + 8));
					return new Sprite(pieces);
				case "Platform":
				case "CPZPlatform":
				case "MovingBlock": return At(frames, subtype >> 4);
				case "HPZWaterfall":
					int top = -120 + subtype * 16;
					// The picker uses the unclamped height; placed waterfalls respect water.
					if (y != 0) top = Math.Min(top, LevelData.Level.WaterHeight - y);
					int length = Math.Max(0, (top + 128) >> 4);
					pieces = new List<Sprite> { new Sprite(At(frames, 18), 0, top), new Sprite(At(frames, Math.Min(15, length))) };
					if (subtype >= 16) pieces.Add(new Sprite(At(frames, 19 + Math.Max(0, length - 15)), 0, 152));
					return new Sprite(pieces);
				case "Scenery": return At(scenery, subtype & 15);
				case "BallHog": return subtype < 0x10 ? frames[0] : alternate[0];
				case "Bubbles": return At(frames, (subtype & 0x80) != 0 ? 19 : subtype == 0 ? 2 : subtype == 1 ? 4 : 6);
				case "Newtron": return subtype == 0 ? At(frames, 3) : At(alternate, 1);
				case "Capsule": return At(frames, subtype == 0 ? 1 : 3);
				case "Collapse":
				case "BreakableWall": return At(frames, subtype);
				case "Bonus": return At(frames, subtype);
				case "EdgeWall":
					pieces = new List<Sprite>();
					bool cap = (subtype & 15) == 2;
					byte[] art = cap ? ObjectHelper.LevelArt : ObjectHelper.OpenArtFile("../art/nemesis/S1/GHZ Edge Wall.nem", CompressionType.Nemesis);
					for (int i = 0; i < 4; i++) pieces.Add(LevelData.MapTileToBmp(art, new MappingsTile(-8, (short)(i * 16 - 32), 2, 2, (ushort)(cap ? 0xD1 : i == 0 && (subtype & 15) == 0 ? 0 : 4), cap, false, 0, false), 2));
					return new Sprite(pieces);
				case "Caterkiller":
					bool kemusi = subtype != 0, damaged = subtype >= 2;
					pieces = new List<Sprite> { new Sprite(kemusi ? alternate[1] : frames[0]) };
					for (int i = 1; i < 4; i++) pieces.Add(new Sprite(kemusi ? alternate[damaged ? 3 : 2] : At(frames, 8), i * 12, kemusi ? (damaged ? 5 : 1) : 0));
					return new Sprite(pieces);
				case "Junction": return new Sprite(frames[0], At(frames, 16));
				case "Eggman": return new Sprite(frames[0], At(frames, 1));
				case "Saw": return At(frames, (subtype & 7) >= 3 ? 2 : 0);
				case "SpinTrap": return (subtype & 0x80) != 0 ? frames[0] : alternate[0];
				case "Stomper": return At(frames, (subtype >> 4) & 7);
				case "Flame": return At(frames, yflip ? 0xB : 0);
				case "Conveyor":
					int height = (subtype & 0x80) == 0 ? 48 : 112;
					Sprite belt = Outline(((subtype & 15) + 1) * 16, height); belt.Offset(0, -height / 2); return belt;
				case "InvisibleSolid": return Outline(((subtype >> 4) + 1) * 16, ((subtype & 15) + 1) * 16);
				case "Teleporter":
					Sprite trigger = Outline(16, 64); trigger.Offset(8, 0); return trigger;
				case "Unused": return Outline(32, 32);
				case "SpinGroup":
					if ((subtype & 0x80) == 0 || (subtype & 0x7F) >= 6) return frames[0];
					int offset = ByteConverter.ToUInt16(groups, (subtype & 0x7F) * 2), members = ByteConverter.ToUInt16(groups, offset) + 1;
					pieces = new List<Sprite>();
					for (int i = 0; i < members; i++) { int entry = offset + 2 + i * 6; pieces.Add(new Sprite(frames[0], ByteConverter.ToUInt16(groups, entry) - x, ByteConverter.ToUInt16(groups, entry + 2) - y)); }
					return new Sprite(pieces);
				default: return At(frames, data.Frame);
			}
		}
		public override string Name { get { return data.Name; } }
		public override bool RememberState { get { return data.RememberState; } }
		public override byte DefaultSubtype { get { return data.DefaultSubtype; } }
		public override bool Debug { get { return data.Debug; } }
		public override int GetDepth(ObjectEntry obj) { return behavior == "PathSwapper" ? 5 : data.Depth; }
		public override PropertySpec[] CustomProperties { get { return properties.ToArray(); } }
		public override ReadOnlyCollection<byte> Subtypes { get { return new ReadOnlyCollection<byte>(data.Subtypes ?? new byte[] { data.DefaultSubtype }); } }
		public override string SubtypeName(byte subtype)
		{
			ObjectEntry entry = new SonicRetro.SonLVL.API.S3K.S3KObjectEntry { SubType = subtype };
			List<string> settings = new List<string>();
			foreach (PropertySpec property in properties.Take(2))
			{
				object value = property.GetValue(entry);
				string text = Convert.ToString(value, System.Globalization.CultureInfo.InvariantCulture);
				if (property.Enumeration != null)
					foreach (var choice in property.Enumeration)
						if (choice.Value.Equals(value)) { text = choice.Key; break; }
				settings.Add(property.Name + ": " + text);
			}
			return (settings.Count == 0 ? Name : string.Join(", ", settings)) + " ($" + subtype.ToString("X2") + ")";
		}
		public override Sprite Image { get { return SubtypeImage(DefaultSubtype); } }
		public override Sprite SubtypeImage(byte subtype) { return behavior == "SpinGroup" ? frames[0] : Preview(subtype, 0, 0, false); }
		public override Sprite GetSprite(ObjectEntry obj)
		{
			Sprite sprite = new Sprite(Preview(obj.SubType, obj.X, obj.Y, obj.YFlip));
			if (behavior == "Teleporter") sprite.Flip(obj.XFlip, false);
			else if (behavior != "SpinGroup" && behavior != "InvisibleSolid" && behavior != "Conveyor" && behavior != "PathSwapper") sprite.Flip(obj.XFlip, obj.YFlip);
			return sprite;
		}
		public override Sprite GetDebugOverlay(ObjectEntry obj)
		{
			int movement = obj.SubType & 15;
			if (behavior == "Platform")
			{
				if (movement == 1 || movement == 5) return Travel(-64, 0, 64, 0);
				if (movement == 2 || movement == 6) return Travel(0, -64, 0, 64);
				if (movement == 10 || movement == 11) return Travel(0, -32, 0, 32);
				if (movement == 12 || movement == 13) return Travel(0, -48, 0, 48);
				if (movement == 7 || movement == 8) return Travel(0, -512, 0, 0);
			}
			if (behavior == "CPZPlatform" || behavior == "MovingBlock")
			{
				if (movement == 1) return Travel(-96, 0, 0, 0);
				if (movement == 8) return Travel(0, -128, 0, 0);
				if (movement == 9 || movement == 10) return Travel(0, 0, (obj.XFlip ? -1 : 1) * (frames[(obj.SubType >> 4) % frames.Length].Width), 0);
			}
			if (behavior == "Lift") return Travel(0, 0, (obj.XFlip ? -1 : 1) * obj.SubType * 16, obj.SubType * 8);
			if (behavior == "Saw" && movement == 1) return Travel(-96, 0, 0, 0);
			if (behavior == "Saw" && movement == 2) return Travel(0, obj.XFlip ? -128 : -48, 0, obj.XFlip ? -80 : 0);
			if (behavior == "RunningDisc") return Outline((movement == 0 ? 72 : 56) * 2, (movement == 0 ? 72 : 56) * 2);
			if (behavior != "Teleporter") return null;
			int offset = ByteConverter.ToUInt16(routes, (obj.SubType & 7) * 2), count = ByteConverter.ToUInt16(routes, offset) / 4;
			List<Point> points = new List<Point> { Point.Empty };
			for (int i = 0; i < count; i++) points.Add(new Point(ByteConverter.ToUInt16(routes, offset + 2 + i * 4) - obj.X, ByteConverter.ToInt16(routes, offset + 4 + i * 4) - obj.Y));
			int left = points.Min(p => p.X), top = points.Min(p => p.Y);
			BitmapBits bitmap = new BitmapBits(points.Max(p => p.X) - left + 1, points.Max(p => p.Y) - top + 1);
			for (int i = 1; i < points.Count; i++) bitmap.DrawLine(LevelData.ColorWhite, points[i - 1].X - left, points[i - 1].Y - top, points[i].X - left, points[i].Y - top);
			return new Sprite(bitmap, left, top);
		}
		private static Sprite Travel(int x1, int y1, int x2, int y2)
		{
			int left = Math.Min(x1, x2) - 3, top = Math.Min(y1, y2) - 3;
			BitmapBits bitmap = new BitmapBits(Math.Abs(x2 - x1) + 7, Math.Abs(y2 - y1) + 7);
			bitmap.DrawLine(LevelData.ColorWhite, x1 - left, y1 - top, x2 - left, y2 - top);
			bitmap.DrawRectangle(LevelData.ColorYellow, x1 - left - 2, y1 - top - 2, 4, 4);
			bitmap.DrawRectangle(LevelData.ColorYellow, x2 - left - 2, y2 - top - 2, 4, 4);
			return new Sprite(bitmap, left, top);
		}
	}

	// Release SonLVL compiles definitions in parallel and names cached DLLs
	// after CodeType. Every object ID needs a distinct type/cache filename,
	// even though its implementation is shared here. Zone overrides keep the
	// same type because they replace that ID before definitions are loaded.
	public sealed class PathSwapper : RuntimeObject { }
	public sealed class BubbleGenerator : RuntimeObject { }
	public sealed class TiltingPlatform : RuntimeObject { }
	public sealed class FlappingDoor : RuntimeObject { }
	public sealed class DiagonalLift : RuntimeObject { }
	public sealed class SwingingPlatform : RuntimeObject { }
	public sealed class Platform : RuntimeObject { }
	public sealed class ChemicalPlantPlatform : RuntimeObject { }
	public sealed class CollapsingLedge : RuntimeObject { }
	public sealed class CollapsingFloor : RuntimeObject { }
	public sealed class Scenery : RuntimeObject { }
	public sealed class Bridge : RuntimeObject { }
	public sealed class HiddenPalaceWaterfall : RuntimeObject { }
	public sealed class Ballhog : RuntimeObject { }
	public sealed class Chopper : RuntimeObject { }
	public sealed class Jaws : RuntimeObject { }
	public sealed class VerticalDoor : RuntimeObject { }
	public sealed class BreakableWall : RuntimeObject { }
	public sealed class Eggman : RuntimeObject { }
	public sealed class Capsule : RuntimeObject { }
	public sealed class Newtron : RuntimeObject { }
	public sealed class EdgeWall : RuntimeObject { }
	public sealed class EmeraldHillWaterfall : RuntimeObject { }
	public sealed class BBat : RuntimeObject { }
	public sealed class Gator : RuntimeObject { }
	public sealed class Aquis : RuntimeObject { }
	public sealed class Skyhorse : RuntimeObject { }
	public sealed class Piranha : RuntimeObject { }
	public sealed class Caterkiller : RuntimeObject { }
	public sealed class Unused71 : RuntimeObject { }
	public sealed class Checkpoint : RuntimeObject { }
	public sealed class HiddenBonus : RuntimeObject { }
	public sealed class Signpost : RuntimeObject { }
	public sealed class Junction : RuntimeObject { }
	public sealed class RunningDisc : RuntimeObject { }
	public sealed class Conveyor : RuntimeObject { }
	public sealed class SpinTrap : RuntimeObject { }
	public sealed class Saw : RuntimeObject { }
	public sealed class Stomper : RuntimeObject { }
	public sealed class VanishingPlatform : RuntimeObject { }
	public sealed class Flamethrower : RuntimeObject { }
	public sealed class Electrocuter : RuntimeObject { }
	public sealed class ConveyorPlatformGroup : RuntimeObject { }
	public sealed class MovingGirder : RuntimeObject { }
	public sealed class TransportPipe : RuntimeObject { }
	public sealed class InvisibleSolid : RuntimeObject { }
	public sealed class MovingBlock : RuntimeObject { }
	public sealed class Bomb : RuntimeObject { }
	public sealed class Button : RuntimeObject { }

}
