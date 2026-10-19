using IniFile;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;

namespace KEHmusic
{
	static class Program
	{
		const int BankSize = 0x8000;
		// s2.sounddriver.asm reserves this much for zMusicData, plus a $20-byte gap.
		const int MusicRamSize = 0xA40;
		static string toolsDirectory;
		static string assembler;
		static string converter;

		static byte[] GetTextFileBytes(string path)
		{
			// reads a text file and outputs a string that line endings normalized to \n
			string[] lines = File.ReadAllLines(path, Encoding.Default);
			using(MemoryStream ms = new MemoryStream())
			{
				for (int i = 0; i < lines.Length; i ++)
				{
					byte[] line = Encoding.Default.GetBytes(lines[i] + '\n');
					ms.Write(line, 0, line.Length);
				}
				return ms.ToArray();
			}
		}

		static string GetFileHash(System.Security.Cryptography.HashAlgorithm hashAlgo, string path, bool isText)
		{
			byte[] fileData = isText ? GetTextFileBytes(path) : File.ReadAllBytes(path);
			byte[] hashbytes = hashAlgo.ComputeHash(fileData);
			string hashstr = string.Empty;
			foreach (byte b in hashbytes)
				hashstr += b.ToString("x2");
			return hashstr;
		}

		static string QueryUname(string argument)
		{
			using (Process process = Process.Start(new ProcessStartInfo("uname", argument)
			{
				UseShellExecute = false,
				RedirectStandardOutput = true
			}))
			{
				string result = process.StandardOutput.ReadToEnd().Trim();
				process.WaitForExit();
				if (process.ExitCode != 0)
					throw new IOException("Could not identify this platform; specify --tools-dir.");
				return result;
			}
		}

		static string FindToolsDirectory()
		{
			if (Path.DirectorySeparatorChar == '\\')
				return "build_tools/Windows-x86";
			string system = QueryUname("-s");
			string machine = QueryUname("-m");
			string architecture = machine == "aarch64" || machine == "arm64" ? "aarch64" :
				machine == "x86_64" || machine == "amd64" ? "x86_64" :
				Regex.IsMatch(machine, "^i[3-6]86$") ? "x86" : machine;
			return "build_tools/" + (system.EndsWith("BSD") ? "BSD" : system) + "-" + architecture;
		}

		static void AddDependencies(HashSet<string> files, string filename, bool assembly)
		{
			filename = Path.GetFullPath(filename);
			if (!files.Add(filename))
				return;
			if (!File.Exists(filename))
				throw new FileNotFoundException("Missing music dependency: " + filename);
			if (!assembly)
				return;
			foreach (Match include in Regex.Matches(File.ReadAllText(filename),
				"^\\s*!?(include|binclude|incbin)\\s+\"([^\"]+)\"", RegexOptions.Multiline | RegexOptions.IgnoreCase))
			{
				string path = include.Groups[2].Value.Replace('\\', '/');
				string relative = Path.Combine(Path.GetDirectoryName(filename), path);
				AddDependencies(files, File.Exists(relative) ? relative : path,
					include.Groups[1].Value.Equals("include", StringComparison.OrdinalIgnoreCase));
			}
		}

		static string BuildHash(string filename, MusicBinaryFormat format)
		{
			var files = new HashSet<string>(StringComparer.Ordinal);
			foreach (string input in new[] { filename, "s2.macros.asm", "sound/_smps2asm_inc.asm",
				assembler, converter, Assembly.GetExecutingAssembly().Location,
				"SonicRetro.KensSharp.Saxman.dll", "SonicRetro.KensSharp.Common.dll" })
				AddDependencies(files, input, Path.GetExtension(input).Equals(".asm", StringComparison.OrdinalIgnoreCase) ||
					Path.GetExtension(input).Equals(".68k", StringComparison.OrdinalIgnoreCase));
			using (var hash = System.Security.Cryptography.SHA256.Create())
			{
				var inputs = new StringBuilder(format.ToString());
				foreach (string input in files.OrderBy(p => p, StringComparer.Ordinal))
				{
					string extension = Path.GetExtension(input).ToLowerInvariant();
					inputs.Append('\n').Append(input).Append(':').Append(GetFileHash(hash, input,
						extension == ".asm" || extension == ".68k"));
				}
				return BitConverter.ToString(hash.ComputeHash(Encoding.UTF8.GetBytes(inputs.ToString()))).Replace("-", "").ToLowerInvariant();
			}
		}

		static void RunTool(string filename, string arguments, string output)
		{
			var info = new ProcessStartInfo(Path.GetFullPath(filename), arguments)
			{
				UseShellExecute = false,
				CreateNoWindow = true
			};
			info.EnvironmentVariables["AS_MSGPATH"] = Path.GetFullPath(toolsDirectory);
			info.EnvironmentVariables["USEANSI"] = "n";
			using (Process process = Process.Start(info))
			{
				process.WaitForExit();
				if (File.Exists(".sound-build/music.log"))
					Console.Write(File.ReadAllText(".sound-build/music.log"));
				if (process.ExitCode != 0 || !File.Exists(output))
					throw new IOException(Path.GetFileName(filename) + " failed; see .sound-build/music.asm and music.log.");
			}
		}

		static byte[] AssembleSong(string filename)
		{
			foreach (string extension in new[] { "asm", "p", "bin", "log" })
				File.Delete(".sound-build/music." + extension);
			using (var writer = new StreamWriter(".sound-build/music.asm", false, Encoding.ASCII))
			{
				writer.WriteLine("\tCPU 68000");
				writer.WriteLine("\tpadding off");
				writer.WriteLine("kehmusic = 1");
				writer.WriteLine("allOptimizations = 1");
				writer.WriteLine("\tinclude \"s2.macros.asm\"");
				writer.WriteLine("\tinclude \"sound/_smps2asm_inc.asm\"");
				writer.WriteLine("\tinclude \"{0}\"", filename.Replace('\\', '/'));
			}
			RunTool(assembler, "-xx -n -q -A -U -E -i . -o .sound-build/music.p .sound-build/music.asm", ".sound-build/music.p");
			RunTool(converter, ".sound-build/music.p .sound-build/music.bin", ".sound-build/music.bin");
			return File.ReadAllBytes(".sound-build/music.bin");
		}

		static bool BuildSong(string name, MusicInfo song, bool clean)
		{
			string filename = Path.Combine("sound/music", song.File);
			string extension = Path.GetExtension(filename).ToLowerInvariant();
			bool assembly = extension == ".asm" || extension == ".68k";
			if (!assembly && extension != ".bin")
				throw new InvalidDataException("Unsupported music file: " + filename);
			if (assembly && song.BinaryFormat == MusicBinaryFormat.Saxman)
				throw new InvalidDataException("BinaryFormat=Saxman requires a precompressed .bin file: " + filename);
			string hash = BuildHash(filename, song.BinaryFormat);
			if (!clean && song.BuildHash == hash && song.Size > 0 && song.Size <= BankSize &&
				(song.OutputFile == null || File.Exists(Path.Combine("sound/music", song.OutputFile))))
				return false;
			Console.WriteLine("Building song \"{0}\"...", song.Title);
			byte[] data = assembly ? AssembleSong(filename) : File.ReadAllBytes(filename);
			song.OutputFile = null;
			song.IsCompressed = song.BinaryFormat == MusicBinaryFormat.Saxman;
			if (data.Length == 0 || data.Length > BankSize)
				throw new InvalidDataException(name + " must occupy between 1 and $8000 bytes.");
			if (song.IsCompressed && (data.Length < 2 || (data[0] | data[1] << 8) != data.Length - 2))
				throw new InvalidDataException(name + " has an invalid Saxman size header.");
			int rawSize = song.IsCompressed ? SonicRetro.KensSharp.Saxman.Decompress(data).Length : data.Length;
			if (song.IsCompressed && (rawSize == 0 || rawSize > MusicRamSize))
				throw new InvalidDataException(name + " decompresses beyond the Z80 music buffer ($A40 bytes).");
			if (!song.IsCompressed && data.Length <= MusicRamSize)
			{
				byte[] compressed = SonicRetro.KensSharp.Saxman.Compress(data, true);
				if (compressed.Length < data.Length)
				{
					if (!data.SequenceEqual(SonicRetro.KensSharp.Saxman.Decompress(compressed)))
						throw new InvalidDataException(name + " failed its Saxman round-trip check.");
					song.OutputFile = "../generated/" + name + "_cmp.bin";
					File.WriteAllBytes(Path.Combine("sound/music", song.OutputFile), compressed);
					data = compressed;
					song.IsCompressed = true;
				}
			}
			song.Size = data.Length;
			song.UncompressedSize = rawSize;
			song.BuildHash = hash;
			using (var md5 = System.Security.Cryptography.MD5.Create())
				song.MD5 = GetFileHash(md5, filename, assembly);
			return true;
		}

		static int Main(string[] args)
		{
			try
			{
				Build(args);
				return 0;
			}
			catch (Exception error)
			{
				Console.Error.WriteLine("KEHmusic: {0}", error.Message);
				return 1;
			}
		}

		static void Build(string[] args)
		{
			bool clean = false;
			string overrideDirectory = Environment.GetEnvironmentVariable("KEH_TOOLS_DIR");
			for (int i = 0; i < args.Length; i++)
			{
				if (args[i].Equals("/clean", StringComparison.OrdinalIgnoreCase) || args[i] == "--clean")
					clean = true;
				else if (args[i] == "--tools-dir" && i + 1 < args.Length)
					overrideDirectory = args[++i];
				else if (args[i] == "--help")
				{
					Console.WriteLine("KEHmusic [/clean | --clean] [--tools-dir PATH]");
					return;
				}
				else
					throw new ArgumentException("Unknown or incomplete argument: " + args[i]);
			}
			if (!File.Exists("main.asm"))
				throw new FileNotFoundException("Run KEHmusic from the project directory containing main.asm.");
			toolsDirectory = overrideDirectory ?? FindToolsDirectory();
			bool windows = Path.DirectorySeparatorChar == '\\';
			assembler = Path.Combine(toolsDirectory, windows ? "asw.exe" : "asl");
			converter = Path.Combine(toolsDirectory, windows ? "p2bin.exe" : "p2bin");
			foreach (string tool in new[] { assembler, converter })
				if (!File.Exists(tool))
					throw new FileNotFoundException("Missing build tool: " + tool);
			Directory.CreateDirectory(".sound-build");
			Directory.CreateDirectory("sound/generated");
			if (clean)
				Console.WriteLine("Performing clean build of music data.");
			var dacs = IniSerializer.Deserialize<Dictionary<string, DACInfo>>("sound/DAC/DAC.ini");
			var samples = new List<KeyValuePair<string, int>>();
			foreach (var item in dacs.Select(a => a.Value.File).Distinct())
			{
				long size = new FileInfo(Path.Combine("sound/DAC", item)).Length;
				if (size == 0 || size > BankSize)
					throw new InvalidDataException("DAC sample must occupy between 1 and $8000 bytes: " + item);
				samples.Add(new KeyValuePair<string, int>(item, (int)size));
			}
			List<int> dacbanksizes = new List<int>() { 0 };
			List<List<string>> dacbanks = new List<List<string>> { new List<string>() };
			foreach (var item in samples.OrderByDescending(a => a.Value))
			{
				bool found = false;
				for (int bank = 0; bank < dacbanksizes.Count; bank++)
					if (dacbanksizes[bank] + item.Value <= 0x8000)
					{
						dacbanks[bank].Add(item.Key);
						dacbanksizes[bank] += item.Value;
						found = true;
						break;
					}
				if (!found)
				{
					dacbanks.Add(new List<string>() { item.Key });
					dacbanksizes.Add(item.Value);
				}
			}
			var samplenums = new Dictionary<string, string>();
			using (var layout = new StreamWriter("dacbanks.gen.asm", false, Encoding.ASCII))
			{
				for (int b = 0; b < dacbanks.Count; b++)
				{
					string bankFile = string.Format("sound/generated/dac-bank-{0}.gen.asm", b + 1);
					layout.WriteLine("\tinclude \"{0}\"", bankFile);
					using (var sw = new StreamWriter(bankFile, false, Encoding.ASCII))
					{
						sw.WriteLine("SndDAC{0}_Start:\tstartBank", b + 1);
						foreach (string item in dacbanks[b])
						{
							string label = Path.GetFileNameWithoutExtension(item).Replace(' ', '_').Replace('-', '_');
							samplenums.Add(item, label);
							sw.WriteLine("SndDAC_{0}:\tBINCLUDE \"sound/DAC/{1}\"", label, item);
							sw.WriteLine("SndDAC_{0}_End:", label);
						}
						sw.WriteLine("SndDAC{0}_DataEnd:", b + 1);
						sw.WriteLine("\tSoundBankAssets DAC,{0}", b + 1);
						sw.WriteLine("\tfinishBank");
					}
				}
			}
			List<string> dacids = new List<string>(dacs.Count);
			using (StreamWriter sw = new StreamWriter("dacinfo.gen.asm", false, Encoding.ASCII))
			{
				sw.WriteLine("zDACMasterPlaylist:");
				sw.WriteLine();
				foreach (var item in dacs)
				{
					byte flags = 0;
					if (item.Value.Format == DACFormat.PCM)
						flags |= 1;
					if (item.Value.Priority)
						flags |= 2;

					sw.WriteLine("\tDACSample\tSndDAC_{0},{1},{2} ; {3}", samplenums[item.Value.File], item.Value.Rate, flags, item.Key);
					dacids.Add(item.Key);
				}
			}
			using (StreamWriter sw = new StreamWriter("dacids.gen.asm", false, Encoding.ASCII))
			{
				string last = "$81";
				for (int i = 0; i < dacids.Count; i++)
				{
					if (i % 7 == 0)
						sw.Write("\tenum {0}={1}", dacids[i], last);
					else
						sw.Write(",{0}", dacids[i]);
					if (i % 7 == 6)
					{
						sw.WriteLine();
						last = dacids[i] + "+1";
					}
				}
			}
			var songs = IniSerializer.Deserialize<Dictionary<string, MusicInfo>>("sound/music/music.ini");
			const string cacheFile = ".sound-build/music-cache.ini";
			var cache = File.Exists(cacheFile) ? IniSerializer.Deserialize<Dictionary<string, MusicBuildInfo>>(cacheFile) :
				new Dictionary<string, MusicBuildInfo>();
			bool writeini = false;
			foreach (var item in songs)
			{
				if (!Regex.IsMatch(item.Key, "^[A-Za-z0-9_]+$"))
					throw new InvalidDataException("Invalid music ID: " + item.Key);
				MusicBuildInfo previous;
				if (cache.TryGetValue(item.Key, out previous))
					item.Value.BuildHash = previous.Hash;
				try
				{
					writeini |= BuildSong(item.Key, item.Value, clean);
				}
				catch (Exception error)
				{
					throw new InvalidDataException(item.Key + " (" + item.Value.File + "): " + error.Message, error);
				}
				cache[item.Key] = new MusicBuildInfo { Hash = item.Value.BuildHash };
			}
			IniSerializer.Serialize(cache, cacheFile);
			if (writeini)
				IniSerializer.Serialize(songs, "sound/music/music.ini");
			List<int> banksizes = new List<int>() { 0 };
			List<List<KeyValuePair<string, MusicInfo>>> banks = new List<List<KeyValuePair<string, MusicInfo>>>() { new List<KeyValuePair<string, MusicInfo>>() };
			foreach (var item in songs.OrderByDescending(a => a.Value.Size))
			{
				bool found = false;
				for (int i = 0; i < banks.Count; i++)
					if (banksizes[i] + item.Value.Size <= 0x8000)
					{
						banks[i].Add(item);
						banksizes[i] += item.Value.Size;
						found = true;
						break;
					}
				if (!found)
				{
					banks.Add(new List<KeyValuePair<string, MusicInfo>>() { item });
					banksizes.Add(item.Value.Size);
				}
			}
			using (var layout = new StreamWriter("musicbanks.gen.asm", false, Encoding.ASCII))
			{
				for (int i = 0; i < banks.Count; i++)
				{
					string bankFile = string.Format("sound/generated/music-bank-{0}.gen.asm", i + 1);
					layout.WriteLine("\tinclude \"{0}\"", bankFile);
					using (var sw = new StreamWriter(bankFile, false, Encoding.ASCII))
					{
						sw.WriteLine("SndMus{0}_Start:\tstartBank", i + 1);
						foreach (var item in banks[i])
						{
							string file = item.Value.OutputFile ?? item.Value.File;
							string directive = Path.GetExtension(file).Equals(".bin", StringComparison.OrdinalIgnoreCase) ? "BINCLUDE" : "include";
							sw.WriteLine("Mus_{0}:\t{1} \"sound/music/{2}\" ; ${3:X} bytes", item.Key, directive, file, item.Value.Size);
						}
						sw.WriteLine("SndMus{0}_DataEnd:", i + 1);
						sw.WriteLine("\tSoundBankAssets Music,{0}", i + 1);
						sw.WriteLine("\tfinishBank");
					}
				}
			}
			using (StreamWriter sw = new StreamWriter("musicinfo.gen.asm", false, Encoding.ASCII))
			{
				sw.WriteLine("zMasterPlaylist:");
				foreach (var item in songs)
				{
					sw.Write("\tzmakePlaylistEntry\tMus_{0},", item.Key);
					sw.Write(item.Value.IsCompressed ? "0" : "musprop_uncompressed");
					if (item.Value.PALMode)
						sw.Write("|musprop_palmode");
					if (item.Value.ExtraLifeJingle)
						sw.Write("|musprop_1up");
					if (item.Value.NoSpeedUp)
						sw.Write("|musprop_nospeedup");
					sw.WriteLine();
				}
			}
			using (StreamWriter sw = new StreamWriter("musicids.gen.asm", false, Encoding.ASCII))
			{
				List<string> musids = new List<string>(songs.Keys) { "_End" };
				sw.WriteLine("MusID__First = 1");
				string last = "_First";
				for (int i = 0; i < musids.Count; i++)
				{
					if (i % 7 == 0)
						sw.Write("\tenum MusID_{0}=MusID_{1}", musids[i], last);
					else
						sw.Write(",MusID_{0}", musids[i]);
					if (i % 7 == 6)
					{
						sw.WriteLine();
						last = musids[i] + "+1";
					}
				}
			}
			using (StreamWriter sw = new StreamWriter("musicnames.gen.asm", false, Encoding.ASCII))
			{
				sw.WriteLine("SongNames:\toffsetTable");
				sw.WriteLine("\toffsetTableEntry.w\tMusNam_Null");
				foreach (var item in songs)
					sw.WriteLine("\toffsetTableEntry.w\tMusNam_{0}", item.Key);
				sw.WriteLine();
				sw.WriteLine("MusNam_Null:\tdc.b 0,' '");
				foreach (var item in songs)
					sw.WriteLine("MusNam_{0}:\tsongtext\t\"{1}\"", item.Key, item.Value.Title.ToUpperInvariant());
				sw.WriteLine("\teven");
			}
		}
	}

	class MusicInfo
	{
		public string Title { get; set; }
		public string Author { get; set; }
		public string File { get; set; }
		public bool PALMode { get; set; }
		public bool ExtraLifeJingle { get; set; }
		public bool NoSpeedUp { get; set; }
		public int Size { get; set; }
		public int UncompressedSize { get; set; }
		public string MD5 { get; set; }
		[IniIgnore]
		public string BuildHash { get; set; }
		public string OutputFile { get; set; }
		public bool IsCompressed { get; set; }
		public MusicBinaryFormat BinaryFormat { get; set; }
	}

	enum MusicBinaryFormat { Raw, Saxman }

	class MusicBuildInfo
	{
		public string Hash { get; set; }
	}

	class DACInfo
	{
		public string File { get; set; }
		public int Rate { get; set; }
		public DACFormat Format { get; set; }
		public bool Priority { get; set; }
	}

	enum DACFormat { DPCM, PCM }
}
