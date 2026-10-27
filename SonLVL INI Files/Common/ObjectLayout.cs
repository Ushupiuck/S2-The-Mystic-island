using System;
using System.Collections.Generic;
using System.ComponentModel;
using SonicRetro.SonLVL.API;
using ByteConverter = SonicRetro.SonLVL.API.ByteConverter;

namespace MysticIsland.ObjectLayouts
{
	// X word, Y/flags word, full ID byte, CD time-mask byte, subtype word.
	public class Layout : ObjectLayoutFormat
	{
		public override Type ObjectType { get { return typeof(Entry); } }

		public override List<ObjectEntry> ReadLayout(byte[] data, out bool terminator)
		{
			if (data.Length % Entry.RecordSize != 0)
				throw new FormatException("Incomplete eight-byte Mystic Island object record.");
			var result = new List<ObjectEntry>();
			terminator = false;
			for (int offset = 0; offset < data.Length; offset += Entry.RecordSize)
			{
				if (ByteConverter.ToUInt16(data, offset) == 0xFFFF)
				{
					if (offset + Entry.RecordSize != data.Length)
						throw new FormatException("Data follows the object layout terminator.");
					terminator = true;
					break;
				}
				result.Add(new Entry(data, offset));
			}
			return result;
		}

		public override byte[] WriteLayout(List<ObjectEntry> objects, bool terminator)
		{
			var result = new List<byte>((objects.Count + (terminator ? 1 : 0)) * Entry.RecordSize);
			foreach (ObjectEntry obj in objects)
			{
				if (!(obj is Entry)) throw new ArgumentException("Expected a Mystic Island object entry.");
				result.AddRange(obj.GetBytes());
			}
			if (terminator) result.AddRange(new byte[] { 0xFF, 0xFF, 0, 0, 0, 0, 0, 0 });
			return result.ToArray();
		}
	}

	[Serializable]
	[DefaultProperty("ID")]
	public class Entry : SonicRetro.SonLVL.API.S3K.S3KObjectEntry, IComparable<ObjectEntry>
	{
		public const int RecordSize = 8;
		private ushort fullSubType;
		private byte timeZones = 0xE0;
		private bool mountHigh;

		// The stock picker uses the base API's byte property.
		// They must preserve the extended settings when changing a named property.
		[Browsable(false)]
		public override byte SubType
		{
			get { return (byte)fullSubType; }
			set { fullSubType = (ushort)((fullSubType & 0xFF00) | value); }
		}

		[DisplayName("Subtype")]
		[Description("Complete 16-bit subtype; named settings select their own bit fields.")]
		[TypeConverter(typeof(UInt16HexConverter))]
		public ushort FullSubType
		{
			get { return fullSubType; }
			set { fullSubType = value; }
		}

		[DisplayName("Show in Present")]
		public bool ShowPresent { get { return (timeZones & 0x40) != 0; } set { SetTime(0x40, value); } }
		[DisplayName("Show in Past")]
		public bool ShowPast { get { return (timeZones & 0x20) != 0; } set { SetTime(0x20, value); } }
		[DisplayName("Show in Future")]
		[Description("Both Good and Bad Future, as in Sonic CD's placement mask.")]
		public bool ShowFuture { get { return (timeZones & 0x80) != 0; } set { SetTime(0x80, value); } }

		private void SetTime(byte mask, bool value)
		{
			timeZones = value ? (byte)(timeZones | mask) : (byte)(timeZones & ~mask);
		}

		public Entry() { }
		public Entry(byte[] data, int offset)
		{
			var record = new byte[RecordSize];
			Array.Copy(data, offset, record, 0, RecordSize);
			FromBytes(record);
		}

		public override byte[] GetBytes()
		{
			ushort y = (ushort)(Y & 0xFFF);
			if (mountHigh) y |= 0x1000;
			if (XFlip) y |= 0x2000;
			if (YFlip) y |= 0x4000;
			if (LoadAtAnyYPos) y |= 0x8000;
			var data = new List<byte>(RecordSize);
			data.AddRange(ByteConverter.GetBytes(X));
			data.AddRange(ByteConverter.GetBytes(y));
			data.Add(ID);
			data.Add(timeZones);
			data.AddRange(ByteConverter.GetBytes(fullSubType));
			return data.ToArray();
		}

		public override void FromBytes(byte[] data)
		{
			if (data.Length != RecordSize) throw new FormatException("Expected eight bytes.");
			X = ByteConverter.ToUInt16(data, 0);
			ushort y = ByteConverter.ToUInt16(data, 2);
			Y = (ushort)(y & 0xFFF);
			mountHigh = (y & 0x1000) != 0;
			XFlip = (y & 0x2000) != 0;
			YFlip = (y & 0x4000) != 0;
			LoadAtAnyYPos = (y & 0x8000) != 0;
			ID = data[4];
			timeZones = data[5];
			fullSubType = ByteConverter.ToUInt16(data, 6);
		}

		int IComparable<ObjectEntry>.CompareTo(ObjectEntry other)
		{
			int result = X.CompareTo(other.X);
			if (result == 0) result = Y.CompareTo(other.Y);
			if (result == 0) result = ID.CompareTo(other.ID);
			if (result == 0) result = fullSubType.CompareTo(other is Entry ? ((Entry)other).FullSubType : other.SubType);
			if (result == 0 && other is Entry) result = timeZones.CompareTo(((Entry)other).timeZones);
			if (result == 0 && other is Entry) result = mountHigh.CompareTo(((Entry)other).mountHigh);
			return result;
		}
	}
}
