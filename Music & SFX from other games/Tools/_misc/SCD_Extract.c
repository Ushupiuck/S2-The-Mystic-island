// SonicCD Sound Extractor
// Programmed by Valley Bell, 12 Februrary 2012

#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <memory.h>

#include "stdtype.h"


typedef struct _sample_info
{
	UINT32 StartAddr;
	UINT32 Size;
	UINT32 LoopOfs;
	UINT32 unused;
} SMPL_INFO;

// PCMWAVEFORMAT strcture from mmsystem.h
typedef struct pcmwaveformat_tag
{
	UINT16	wFormatTag;			// format type
	UINT16	nChannels;			// number of channels (i.e. mono, stereo...)
	UINT32	nSamplesPerSec;		// sample rate
	UINT32	nAvgBytesPerSec;	// for buffer estimation
	UINT16	nBlockAlign;		// block size of data
	UINT16	wBitsPerSample;		// number of bits per sample of mono data
} PCMWAVEFORMAT;
#define WAVE_FORMAT_PCM		0x0001

typedef struct sample_loop
{
	UINT32 dwIdentifier;
	UINT32 dwType;
	UINT32 dwStart;
	UINT32 dwEnd;
	UINT32 dwFraction;
	UINT32 dwPlayCount;
} SMPL_LOOP;
typedef struct sampler_chunk
{
	UINT32 chunkID;
	UINT32 chunkSize;
	
	UINT32 dwManufacturer;
	UINT32 dwProduct;
	UINT32 dwSamplePeriod;
	UINT32 dwMIDIUnityNote;
	UINT32 dwMIDIPitchFraction;
	UINT32 dwSMPTEFormat;
	UINT32 dwSMPTEOffset;
	UINT32 cSampleLoops;
	UINT32 cbSamplerData;
	SMPL_LOOP Loops[0x01];
} SMPL_CHUNK;

typedef struct wave_file_tag
{
	UINT32 fccRIFF;
	UINT32 dwRIFFSize;
	UINT32 fccWAVE;
	UINT32 fccfmt_;
	UINT32 dwFmtSize;
	PCMWAVEFORMAT Fmt;
	UINT32 fccdata;
	UINT32 dwDataSize;
} WAVE_FILE;


UINT16 ReadBE16(const UINT8* Buffer);
UINT32 ReadBE32(const UINT8* Buffer);
UINT32 ReadAddr(const UINT8* Buffer);
UINT8 ExtractSamples(UINT32 FileSize, const UINT8* FileData);
UINT32 GetNextAddress(const UINT32** PtrList, UINT32 Addr);
void WriteData(const char* FileName, UINT32 DataSize, const UINT8* Data);
UINT32 SearchSMPSTrkEnd(const UINT8* Data, UINT32 StartAddr);
void WriteSampleData(const char* FileName, const UINT8* Data, const SMPL_INFO* SmplInf, UINT8 Raw);


int main(int argc, char* argv[])
{
	FILE* hFile;
	UINT32 FileSize;
	UINT8* FileData;
	UINT8 RetVal;
	int ErrVal;
	
	printf("SonicCD Sound Extractor\n-----------------------\n");
	if (argc < 2)
	{
		printf("Usage: SCD_Extract.exe SNCBNK##.BIN\n");
		return 0;
	}
	
	hFile = fopen(argv[1], "rb");
	if (hFile == NULL)
	{
		printf("Error opening file!\n");
		return 1;
	}
	
	fseek(hFile, 0, SEEK_END);
	FileSize = ftell(hFile);
	if (FileSize > 0x40000)
		FileSize = 0x40000;	// the files can have 256 KB at max
	
	fseek(hFile, 0, SEEK_SET);
	FileData = (UINT8*)malloc(FileSize);
	fread(FileData, 0x01, FileSize, hFile);
	
	fclose(hFile);
	
	RetVal = ExtractSamples(FileSize, FileData);
	switch(RetVal)
	{
	case 0x00:	// Success!
		ErrVal = 0;
		break;
	case 0x10:
		printf("Error: Invalid File!\n");
		ErrVal = 2;
		break;
	case 0x01:	// OK, but sample data not found
		ErrVal = 0;
		break;
	default:
		printf("Unknown Error!");
		ErrVal = -1;
		break;
	}
	
#ifdef _DEBUG
	getchar();
#endif
	return ErrVal;
}

// Read BigEndian values
UINT16 ReadBE16(const UINT8* Buffer)
{
	return (Buffer[0x00] << 8) | (Buffer[0x01] << 0);
}

UINT32 ReadBE32(const UINT8* Buffer)
{
	return	(Buffer[0x00] << 24) | (Buffer[0x01] << 16) |
			(Buffer[0x02] <<  8) | (Buffer[0x03] <<  0);
}

UINT32 ReadAddr(const UINT8* Buffer)
{
	return ReadBE32(Buffer) & 0x3FFFF;
}

UINT8 ExtractSamples(UINT32 FileSize, const UINT8* FileData)
{
	const UINT8 SNDTYPE_PTRS[0x03] = {0x00, 0x08, 0x09};
	UINT32 CurPos;
	UINT32 CurPtr;
	UINT32 PtrList[0x0C];
	UINT32 MusList[0x10];	// actually there's only 1 used - always
	UINT32 SFXList[0x20];	// 0x10 should be ebnough, actually
	UINT32 SampleAddr;
	UINT32 SmplCount;
	UINT32* SmplList;
	SMPL_INFO* SmplInf;
	UINT32* PPtrList[0x04];	// for GetNextAddress
	UINT32 BaseAddr;
	UINT32 DataSize;
	char TempStr[0x10];
	
	CurPos = 0x00;
	for (CurPtr = 0x00; CurPtr < 0x04; CurPtr ++)
		PPtrList[CurPtr] = NULL;
	
	// Check Header
	if (memcmp(&FileData[CurPos], "SNCBNK", 6))
		return 0x10;
	CurPos += 0x10;
	
	// I assume that 4E FA is a command.
	// Anyway, there are 2 commands, each with one 16-bit adress.
	// Both are relative adresses are relative to the offset of the address. (e.g. command + 2)
	
	// The first address at 0x12 points to the first actual sound driver code. (I guess)
	// The second one points to another section of code.
	CurPos += 0x06;
	// We use the second one, because the driver differs a little between the B1/B2 and 1B/3B/... files
	// (the B1/B2 files have 4 additional bytes quite at the beginning) and doing a relative jump from
	// the seconds offset works always.
	CurPos += ReadBE16(&FileData[CurPos]);
	// Now we do a relative jump to reach all the adresses for music, PCM SFX and samples.
	CurPos += 0x0310;
	
	// Okay, here we reached the addresses related to music. (in the SCD Past songs, this is at 0x12B6)
	// 00	0x12B6:	Sound Type Array #1 (for musics)
	// 01	0x12BA:	a pointer that points to itself
	// 02	0x12BE:	pointer to Music List (has always 1 entry, not more)
	// 03	0x12C2:	pointer to SFX List
	// 04	0x12C6:	a pointer that points to itself
	// 05	0x12CA:	a pointer that points to itself (there are quite a lot of these)
	// 06	0x12CE:	some value (0xB0)
	// 07	0x12D2:	pointer to the bytes after the header
	// 08	0x12D6:	Sound Type Array #2 (for ??)
	// 09	0x12DE:	Sound Type Array #3 (for SFX)
	for (CurPtr = 0x00; CurPtr < 0x0A; CurPtr ++)
	{
		PtrList[CurPtr] = ReadAddr(&FileData[CurPos]);
		CurPos += 0x04;
	}
	PtrList[CurPtr] = 0x00;	// terminate list (for GetNextAddress)
	PPtrList[0x00] = PtrList;
	
	printf("Writing Sound Type Arrays ...\n");
	// Write Sound Type Arrays 1/2/3
	for (CurPtr = 0x00; CurPtr < 0x03; CurPtr ++)
	{
		BaseAddr = PtrList[SNDTYPE_PTRS[CurPtr]];
		CurPos = BaseAddr;
		// I simply count until I reach a 00 byte
		while(FileData[CurPos])
			CurPos ++;
		DataSize = CurPos - BaseAddr;
		sprintf(TempStr, "SndType%u.bin", CurPtr + 1);
		WriteData(TempStr, DataSize, &FileData[BaseAddr]);
	}
	
	// both, music and SFX lists are read until a know offset is reached
	printf("Reading Music and SFX Lists ...\n");
	// Read Music List
	CurPos = PtrList[0x02];
	BaseAddr = GetNextAddress(PPtrList, CurPos);
	CurPtr = 0x00;
	while(CurPos < BaseAddr)
	{
		MusList[CurPtr] = ReadAddr(&FileData[CurPos]);
		if (MusList[CurPtr] < BaseAddr)
			BaseAddr = MusList[CurPtr];
		if (MusList[CurPtr] < PtrList[0x02])
			break;
		
		CurPos += 0x04;
		CurPtr ++;
	}
	MusList[CurPtr] = 0x00;
	PPtrList[0x01] = MusList;
	
	// Read SFX List
	CurPos = PtrList[0x03];
	BaseAddr = GetNextAddress(PPtrList, CurPos);
	CurPtr = 0x00;
	while(CurPos < BaseAddr)
	{
		SFXList[CurPtr] = ReadAddr(&FileData[CurPos]);
		if (SFXList[CurPtr] < BaseAddr)
			BaseAddr = SFXList[CurPtr];
		if (SFXList[CurPtr] < PtrList[0x02])
			break;
		
		CurPos += 0x04;
		CurPtr ++;
	}
	SFXList[CurPtr] = 0x00;
	PPtrList[0x02] = SFXList;
	
	// The size of music and SFX is determinated by GetNextAddress
	printf("Extracting Music ...\n");
	CurPtr = 0x00;
	while(MusList[CurPtr])
	{
		BaseAddr = MusList[CurPtr];
		CurPos = GetNextAddress(PPtrList, BaseAddr);
		DataSize = CurPos - BaseAddr;
		sprintf(TempStr, "Music_%02X.bin", CurPtr);
		WriteData(TempStr, DataSize, &FileData[BaseAddr]);
		CurPtr ++;
	}
	
	printf("Extracting SFX ...\n");
	CurPtr = 0x00;
	SampleAddr = 0x00;
	while(SFXList[CurPtr])
	{
		BaseAddr = SFXList[CurPtr];
		CurPos = GetNextAddress(PPtrList, BaseAddr);
		if (CurPos >= 0x40000)
		{
			CurPos = SearchSMPSTrkEnd(FileData, BaseAddr);
			SampleAddr = CurPos;
		}
		DataSize = CurPos - BaseAddr;
		sprintf(TempStr, "SFX_%02X.bin", CurPtr);
		WriteData(TempStr, DataSize, &FileData[BaseAddr]);
		CurPtr ++;
	}
	
	// Extract the samples
	SmplCount = ReadBE32(&FileData[SampleAddr]);
	if (! SmplCount)
	{
		printf("Warning: No sample data found!\n");
		return 0x01;
	}
	else if (SmplCount >= 0x40)
	{
		printf("Warning: Failed to find sample data!\n");
		return 0x01;
	}
	// The samples list is easy:
	// At first it starts with a 4-byte value that contains the number of samples.
	// Then there is a pointer list with one pointer per sample, that points to the actual
	// structure that defined the samples.
	// Such a structure consists of four 4-byte-values, making 0x10 bytes:
	// - the start address of the sample
	// - the sample size
	// - the loop offset (relative to the sample's start address)
	// - an unused value that's always 0
	CurPos = SampleAddr + 0x04;
	
	printf("Extracting Samples ...\n");
	SmplList = (UINT32*)malloc(sizeof(UINT32) * SmplCount);
	SmplInf = (SMPL_INFO*)malloc(sizeof(SMPL_INFO) * SmplCount);
	
	for (CurPtr = 0x00; CurPtr < SmplCount; CurPtr ++)
	{
		SmplList[CurPtr] = ReadAddr(&FileData[CurPos]);
		CurPos += 0x04;
	}
	for (CurPtr = 0x00; CurPtr < SmplCount; CurPtr ++)
	{
		CurPos = SmplList[CurPtr];
		SmplInf[CurPtr].StartAddr =	ReadAddr(&FileData[CurPos + 0x00]);
		SmplInf[CurPtr].Size =		ReadBE32(&FileData[CurPos + 0x04]);
		SmplInf[CurPtr].LoopOfs =	ReadBE32(&FileData[CurPos + 0x08]);
		SmplInf[CurPtr].unused =	ReadBE32(&FileData[CurPos + 0x0C]);
		CurPos += 0x04;
	}
	
	for (CurPtr = 0x00; CurPtr < SmplCount; CurPtr ++)
	{
		sprintf(TempStr, "Smpl_%02X.wav", CurPtr);
		WriteSampleData(TempStr, FileData, &SmplInf[CurPtr], 0x00);
		//sprintf(TempStr, "Smpl_%02X.pcm", CurPtr);
		//WriteSampleData(TempStr, FileData, &SmplInf[CurPtr], 0x01);
	}
	
	printf("Done.\n");
	free(SmplList);
	free(SmplInf);
	
	return 0x00;
}

UINT32 GetNextAddress(const UINT32** PPtrList, UINT32 Addr)
{
	// This works with 2 lists:
	// a list collection ("master") and some smaller lists ("slaves")
	// The function goes through all slave-lists that are referenced in the master-list and
	// returns the smallest address that's greater than Addr.
	const UINT32** CurPtr;
	const UINT32* CurAddr;
	UINT32 MinAddr;
	
	MinAddr = 0x40000;
	CurPtr = PPtrList;
	while(*CurPtr)
	{
		CurAddr = *CurPtr;
		while(*CurAddr)
		{
			if (*CurAddr > Addr && *CurAddr < MinAddr)
				MinAddr = *CurAddr;
			CurAddr ++;
		}
		CurPtr ++;
	}
	
	return MinAddr;
}

void WriteData(const char* FileName, UINT32 DataSize, const UINT8* Data)
{
	FILE* hFile;
	
	hFile = fopen(FileName, "wb");
	if (hFile == NULL)
	{
		printf("Error opening %s!\n", FileName);
		return;
	}
	
	fwrite(Data, 0x01, DataSize, hFile);
	
	fclose(hFile);
	
	return;
}

UINT32 SearchSMPSTrkEnd(const UINT8* Data, UINT32 StartAddr)
{
	UINT32 CurPos;
	
	CurPos = StartAddr + 0x0A;	// jump to first track
	while(Data[CurPos] != 0xF2)
		CurPos ++;
	CurPos ++;	// count the F2

	CurPos = (CurPos + 1) & ~0x01;	// round up to 2-byte-words
	return CurPos;
}

void WriteSampleData(const char* FileName, const UINT8* Data, const SMPL_INFO* SmplInf, UINT8 Raw)
{
	FILE* hFile;
	WAVE_FILE WF;
	SMPL_CHUNK SmpChk;
	UINT32 CurPos;
	const UINT8* TempPtr;
	UINT8 SmplVal;
	UINT8 SaveSmplChk;
	
	hFile = fopen(FileName, "wb");
	if (hFile == NULL)
	{
		printf("Error opening %s!\n", FileName);
		return;
	}
	
	switch(Raw)
	{
	case 0x00:	// WAVE format
		WF.fccRIFF = 0x46464952;
		WF.fccWAVE = 0x45564157;
		WF.fccfmt_ = 0x20746D66;
		WF.dwFmtSize = sizeof(PCMWAVEFORMAT);
		WF.fccdata = 0x61746164;
		
		WF.Fmt.wFormatTag = WAVE_FORMAT_PCM;
		WF.Fmt.nChannels = 1;
		WF.Fmt.nSamplesPerSec = 16000;
		WF.Fmt.wBitsPerSample = 8;
		WF.Fmt.nBlockAlign = (WF.Fmt.wBitsPerSample + 7) / 8 * WF.Fmt.nChannels;
		WF.Fmt.nAvgBytesPerSec = WF.Fmt.nSamplesPerSec * WF.Fmt.nBlockAlign;
		
		WF.dwDataSize = SmplInf->Size;
		WF.dwRIFFSize = 0x0C + WF.dwFmtSize + 0x08 + WF.dwDataSize;
		
#if 0
		SaveSmplChk = (SmplInf->LoopOfs > 0);
#else
		SaveSmplChk = 0x00;
#endif
		
		if (SaveSmplChk)
		{
			SmpChk.chunkID = 0x6C706D73;
			SmpChk.chunkSize = sizeof(SMPL_CHUNK) - 0x08;
			SmpChk.dwManufacturer = 0x00;
			SmpChk.dwProduct = 0x00;
			SmpChk.dwSamplePeriod = (UINT32)(1.0E+9 / WF.Fmt.nSamplesPerSec + 0.5);
			SmpChk.dwMIDIUnityNote = 60;
			SmpChk.dwMIDIPitchFraction = 0;
			SmpChk.dwSMPTEFormat = 0;
			SmpChk.dwSMPTEOffset = 0;
			SmpChk.cSampleLoops = 1;
			SmpChk.cbSamplerData = 0x00;
			SmpChk.Loops[0x00].dwIdentifier = 0x00;
			SmpChk.Loops[0x00].dwType = 0x00;	// 00 - loop forward (normal)
			SmpChk.Loops[0x00].dwStart = SmplInf->LoopOfs;
			SmpChk.Loops[0x00].dwEnd = SmplInf->Size - 1;
			SmpChk.Loops[0x00].dwFraction = 0x00;
			SmpChk.Loops[0x00].dwPlayCount = 0;
			WF.dwRIFFSize += sizeof(SMPL_CHUNK);
		}
		
		fwrite(&WF, sizeof(WAVE_FILE), 0x01, hFile);
		
		TempPtr = &Data[SmplInf->StartAddr];
		for (CurPos = 0x00; CurPos < SmplInf->Size; CurPos ++, TempPtr ++)
		{
			// The RF5Cxx chips have a sign-magnitude format.
			// i.e. 0b1000 0001 = 0x81 = -1 and 0b0111 1111 = 7F = 127
			if (*TempPtr & 0x80)
				SmplVal = 0x80 - (*TempPtr & 0x7F);
			else
				SmplVal = 0x80 + *TempPtr;
			fwrite(&SmplVal, 0x01, 0x01, hFile);
		}
		if (SaveSmplChk)
			fwrite(&SmpChk, sizeof(SMPL_CHUNK), 0x01, hFile);
		break;
	case 0x01:	// RAW data
		TempPtr = &Data[SmplInf->StartAddr];
		for (CurPos = 0x00; CurPos < SmplInf->Size; CurPos ++, TempPtr ++)
		{
			if (*TempPtr & 0x80)
				SmplVal = 0x00 - (*TempPtr & 0x7F);
			else
				SmplVal = 0x00 + *TempPtr;
			fwrite(&SmplVal, 0x01, 0x01, hFile);
		}
		break;
	}
	
	fclose(hFile);
	
	return;
}
