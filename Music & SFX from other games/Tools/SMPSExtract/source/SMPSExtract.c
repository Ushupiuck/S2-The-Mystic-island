// SMPS Song and DAC Sound Extractor
// ---------------------------------
// Written by Valley Bell

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <memory.h>
#include <string.h>
#include <direct.h>
#include "stdtype.h"

#include "DetectSearch.h"
#include "DriverInfo.h"
#include "SongExtract.h"
#include "DACExtract.h"
#include "EnvExtract.h"

#ifndef _MSC_VER
#define _stricmp	strcasecomp
#endif


UINT8 KDecomp(UINT32 SrcSize, const UINT8* SrcData, UINT32* RetDstSize, UINT8** RetDstData, UINT8 Moduled);

int main(int argc, char* argv[]);
void PrintHelpScreen(UINT8 ScreenType);
void OpenROMFile(const char* FileName);
UINT16 OpenZ80MemoryDump(const char* FileName, UINT8** RetData);
void LoadZ80Driver(const char* DumpFileName);
UINT8 DoActions(UINT8 Mode, int argc, const char** argv_3);


#define RAMMODE_NONE	0x00	// don't have Z80 RAM
#define RAMMODE_PTR		0x01	// Z80 RAM data is pointer to ROM data
#define RAMMODE_ALLOC	0x02	// Z80 RAM data was allocated and has to be free'd

UINT32 ROMLength;
UINT8* ROMData;
UINT8 RAMMode;
UINT16 RAMSize;
UINT8* RAMData;
char FileBase[0x200];
char* FileTitle;
UINT8 PtrMode;
UINT8 MarsMode;
UINT32 MarsBase;

UINT8 SONG_BASE = 0xFF;
UINT8 SONG_COUNT = 0x00;
UINT8 ReadOnlyMode;

char DAC_NAMEBASE[0x40];
const char* Z80DumpFile;

int main(int argc, char* argv[])
{
	int argbase;
	UINT8 Mode;
	UINT8 RetVal;
	
	printf("SMPS Song Extractor\n");
	printf("-------------------\n");
	if (argc < 2)
	{
		PrintHelpScreen(0x00);
		
		// Example calls:
		//	-mus -Z80BPtr -Z80Dump "Z80Dump.bin" "Sonic 3D Blast (W) [!].bin" 0x165C 0x0B65
		//	-mus -Z80 "Sonic and Crackers (Beta).bin" 0x00633F
		//	-dac "Sonic 3D Blast (W) [!].bin" 0x1A
		return 0;
	}
	
	Mode = 0x03;
	PtrMode = 0x00;
	MarsMode = 0x00;
	MarsBase = 0x00;
	Z80DumpFile = NULL;
	ReadOnlyMode = 0x00;
	
	argbase = 1;
	if (argv[argbase][0] == '-')
	{
		if (! _stricmp(argv[argbase] + 1, "mus"))
			Mode = 0x00;
		else if (! _stricmp(argv[argbase] + 1, "sfx"))
			Mode = 0x01;
		else if (! _stricmp(argv[argbase] + 1, "dac"))
			Mode = 0x02;
		else if (! _stricmp(argv[argbase] + 1, "info"))
			Mode = 0x03;
		else if (! _stricmp(argv[argbase] + 1, "env"))
			Mode = 0x04;
		else if (! _stricmp(argv[argbase] + 1, "dumpdrv"))
			Mode = 0x05;
		else if (! _stricmp(argv[argbase] + 1, "dumpall"))
			Mode = 0x06;
		else
		{
			if (! _stricmp(argv[argbase] + 1, "help"))
				PrintHelpScreen(0x00);
			else if (! _stricmp(argv[argbase] + 1, "mlist"))
				PrintHelpScreen(0x01);
			else if (! _stricmp(argv[argbase] + 1, "dlist"))
				PrintHelpScreen(0x02);
			else if (! _stricmp(argv[argbase] + 1, "elist"))
				PrintHelpScreen(0x03);
			else
				printf("Unknown Mode!\n");
#ifdef _DEBUG
			getchar();
#endif
			return 0;
		}
		argbase ++;
	}
	if (Mode == 0x02)
		strcpy(DAC_NAMEBASE, "DAC");
	else
		strcpy(DAC_NAMEBASE, "");
	while(argbase < argc && argv[argbase][0] == '-')
	{
		if (! _stricmp(argv[argbase] + 1, "68k"))
			PtrMode = PTR_68K;
		else if (! _stricmp(argv[argbase] + 1, "Z80"))
			PtrMode = PTR_Z80;
		//else if (! _stricmp(argv[argbase] + 1, "Z80RAM"))
		//	PtrMode = PTR_Z80RAM;
		else if (! _stricmp(argv[argbase] + 1, "32x"))
			MarsMode = 0x01;	// done automatically by reading the ROM header, but can be enforced
		else if (! _stricmp(argv[argbase] + 1, "ORuns"))
			PtrMode = PTR_ORNS;
		else if (! _stricmp(argv[argbase] + 1, "MMWW"))
			PtrMode = PTR_MMWW;
		else if (! _stricmp(argv[argbase] + 1, "SM1M"))
			PtrMode = PTR_SM1bM4;
		else if (! _stricmp(argv[argbase] + 1, "Z80BPtr"))
			PtrMode = PTR_Z80BPTR;
		else if (! _stricmp(argv[argbase] + 1, "S2CDv2"))
			PtrMode = PTR_S2CDV2;
		else if (! _stricmp(argv[argbase] + 1, "Darwin"))
			PtrMode = PTR_DARWIN;
		else if (! _stricmp(argv[argbase] + 1, "base"))
		{
			argbase ++;
			if (argbase < argc)
				SONG_BASE = (UINT8)strtoul(argv[argbase], NULL, 0);
		}
		else if (! _stricmp(argv[argbase] + 1, "num"))
		{
			argbase ++;
			if (argbase < argc)
				SONG_COUNT = (UINT8)strtoul(argv[argbase], NULL, 0);
		}
		else if (! _stricmp(argv[argbase] + 1, "folder"))
		{
			argbase ++;
			if (argbase < argc)
			{
				strncpy(DAC_NAMEBASE, argv[argbase], 0x3F);
				DAC_NAMEBASE[0x3F] = '\0';
			}
		}
		else if (! _stricmp(argv[argbase] + 1, "Z80Dump"))
		{
			argbase ++;
			if (argbase < argc)
				Z80DumpFile = argv[argbase];
		}
		else if (! _stricmp(argv[argbase] + 1, "32xBase"))
		{
			argbase ++;
			if (argbase < argc)
				MarsBase = strtoul(argv[argbase], NULL, 0);
		}
		else if (! _stricmp(argv[argbase] + 1, "ReadOnly"))
		{
			ReadOnlyMode = 0x01;
		}
		else
			break;
		argbase ++;
	}
	
	if (argc <= argbase + 0x00)
	{
		printf("Not enough arguments!\n");
		return 9;
	}
	
	OpenROMFile(argv[argbase]);
	if (! ROMLength)
		return 1;
	argbase ++;
	
	if (ROMLength >= 0x200 && ! memcmp(&ROMData[0x105], "32X", 3))
		MarsMode = 0x01;
	
	RetVal = DoActions(Mode, argc - argbase, argv + argbase);
	
	free(ROMData);	ROMData = NULL;
	ROMLength = 0x00;
	
#ifdef _DEBUG
	if (argv[0][1] == ':')
		getchar();
#endif
	
	return RetVal;
}

void PrintHelpScreen(UINT8 ScreenType)
{
	switch(ScreenType)
	{
	case 0x00:
		printf("Usage:\n");
		printf("SMPSExtract Mode [Options] ROM.bin MusicParams/DACFormat/EnvFormat\n");
		//printf("SMPSExtract Mode [Options] ROM.bin [DACType] [PtrListAddr] [BankListAddr]\n");
		printf("\n");
		printf("Modes:\n");
		printf("    -info - show SMPS driver information (type, pointers, etc.) (default)\n");
		printf("            Note: info/dumpall accept an additional parameter that\n");
		printf("                  specifies the Pointer List Offset.\n");
		printf("    -mus - Music\n");
		printf("    -sfx - Sounds (same as music, dumps as .sfx)\n");
		printf("    -dac - DAC Sounds\n");
		printf("    -env - Envelopes (Modulation/Volume)\n");
		printf("    -dumpdrv - dump Z80 driver(s)\n");
		printf("    -dumpall - dump music, envelopes and DAC sounds\n");
		printf("    -help  - show usage\n");
		printf("    -mlist - list supported Music Pointer Formats\n");
		printf("    -dlist - list supported DAC Formats\n");
		printf("    -elist - list Envelope Formats\n");
		printf("\n");
		printf("Options:\n");
		printf("-base N         sets the index of the first song/sound to N\n");
		printf("-num N          forces N songs/sounds to be ripped \n");
		printf("-folder Name    extracts DAC to folder Name\\ (default is \"DAC\")\n");
		printf("-Z80Dump File   Specifies a file with a dump of the Z80 RAM.\n");
		printf("                Required if autodetection fails.\n");
		printf("-32xBase        Specify ROM Offset mapped to 68k's 900000 area,\n");
		printf("-PtrMode        sets the Pointer Format to PtrMode (music/sfx only)\n");
		printf("-ReadOnly       print everything, but don't write any files\n");
		printf("\n");
		break;
	case 0x01:
		printf("Music Parameter: MusPtrListAddr [BankListAddr] [BankBase]\n");
		printf("    MusPtrListAddr  Address of the List of Music Pointers\n");
		printf("    BankListAddr    Z80 Address of the Bank List\n");
		printf("    BankBase        Base Offset for relative Z80 Banks\n");
		printf("Pointer Formats:\n");
		printf("   -68k     68k SMPS (default)\n");
		printf("   -Z80     Z80 SMPS, banked\n");
		//printf("   -Z80RAM  Z80 SMPS, stored in RAM (1)\n");
		printf("   -32x     enforce fixes for 32x pointers (if autodetection fails)\n");
		printf("   -ORuns   OutRunners*\n");
		printf("   -MMWW    Mega Man: The Wily Wars*\n");
		printf("   -Z80BPtr Z80 SMPS, with seperate bank and pointer lists\n");
		printf("            uses BankListAddr (required) and BankBase (optional)\n");
		printf("            Note: Bank lists can have 3 modes:\n");
		printf("                  - full offset (68k offset bits 15-23)\n");
		printf("                  - relative (BankBase + full offset)\n");
		printf("                  - low byte (68k offset bits 8-15)\n");
		printf("            Using the BankBase parameter enforces 'relative' or\n");
		printf("            'low byte' modes.\n");
		printf("   -Darwin  Darwin 4081* (list of 4-byte pointer + 4-byte size)\n");
		printf("* custom pointer list format\n");
	//	printf("(1) MusPtrListAddr must be Z80 RAM address\n");
		printf("\n");
		break;
	case 0x02:
		printf("DAC Formats:\n");
		printf("0x00*   Sonic 1\n");
		printf("0x01*   Phantasy Star IV\n");
		printf("0x02*   Phantasy Star 2/Super Daisenryaku\n");
		printf("0x03    SMPS 68k/Treasure: Dynamite Headdy, Alien Soldier\n");
		printf("          PtrList < 0x100 -> automatic search for:\n");
		printf("            0x00 - Drums, 0x01 - DAC SFX\n");
		printf("          PtrList >= 0x100 -> use offset directly\n");
		printf("0x04    Sonic 2 Clone Driver + jman2050 DAC\r");
		printf("0x05    Chou Yakyuu Miracle Nine\n");
		printf("0x06*   SMPS 68k [Drums]: Fatal Fury 1/2, MJ's Moonwalker, ...\n");
	//	printf("0x06*   [Drums]	Magical Taruruuto-Kun, Fatal Fury 1/2, MJ's Moonwalker,\n");
	//	printf("                Mighty Morphin Power Rangers - The Movie, many more\n");
		printf("0x07*   Ristar\n");
		printf("0x08    SMPS 68k [Voices]: Fatal Fury 1/2, MJ's Moonwalker, ...\n");
	//	printf("0x08    [Voices] Fatal Fury 1/2, MJ's Moonwalker,\n");
	//	printf("                 Mighty Morphin Power Rangers - The Movie, many more\n");
		printf("0x0B*   Virtua Racing Deluxe 32X, Cosmic Carnage 32X,\n");
		printf("        Sonic Crackers\n");
		printf("0x0C*   OutRunners, Virtua Fighter 2\n");
		printf("0x0D    SMPS Z80 Type 2: Mighty Morphin Power Rangers, Viewpoint, ...\n");
		//		also:	Dyna Brothers 2
		printf("0x0E    SMPS Z80 Type 1: Mazin Saga, King of the Monsters 1/2, Battletoads,\n");
		printf("                         OutRun, OutRun 2019, Yuu Yuu Hakusho Gaiden, ...\n");
		printf("          PtrList < 0x100 -> automatic search for:\n");
		printf("            0x00 - Drums, 0x01 - DAC SFX\n");
		printf("          PtrList >= 0x100 -> use offset directly\n");
		printf("          PtrList == 0x80aaaaaa -> read Z80 pointer from 0xaaaaaa\n");
		printf("0x10*   Streets of Rage, A Ressha de Gyoukou MD (Note: custom compression)\n");
		printf("0x12    Golden Axe III\n");
		printf("0x14*   The Hybrid Front\n");
		printf("0x15*   Virtua Racing, Super Monaco Grand Prix\n");
		printf("0x16*   preSMPS 68k Type 2: Rent A Hero, Metal Fangs, Street Fighter II Turbo\n");
		printf("0x19    Sonic 3 & Knuckles, Sonic 3D Blast\n");
		printf("0x1B*   Bishoujo Senshi Sailor Moon\n");
		printf("0x1C*   Samurai Shodown\n");
		printf("0x1D    Knuckles Chaotix\n");
		printf("0x1E    Visual Scene SEGA-CD Image\n");
		printf("0x1F*   Sonic 2\n");
		printf("0x20*   Metal Head 32X, Shadow Squadron 32X\n");
		printf("0x21    Mercs\n");
		printf("0x22*   SMPS 68k [Drums with Bank Table]: Magical Taruruuto-Kun, Pulseman\n");
		printf("0x23    Ayrton Senna's Super Monaco GP II\n");
		printf("0x24    Sega Pico SMPS\n");
		printf("0x25    J. League Pro Striker DAC driver\n");
		printf("0x26    Wimbledon Championship Tennis (DAC Voices)\n");
		printf("0x27    SMPS Z80/Gamtec\n");
		printf("* requires Z80 DAC driver data (either via autodetection or Z80 dump)\n");
		printf("\n");
		break;
	case 0x03:
		printf("Envelope Type:\n");
		printf("    0x0#    Modulation Envelope\n");
		printf("    0x1#    PSG Volume Envelope\n");
		printf("Envelope Pointer Formats:\n");
		printf("    0x#0    68k Pointer\n");
		printf("    0x#1    Z80 Pointer\n");
		printf("    0x#9    Z80 RAM Pointer (reads from Z80 RAM dump only)\n");
		printf("\n");
		break;
	}
	
	return;
}

void OpenROMFile(const char* FileName)
{
	FILE* hFile;
	char* TempPnt;
	
	ROMLength = 0x00;
	
	hFile = fopen(FileName, "rb");
	if (hFile == NULL)
	{
		printf("Error opening file!\n");
		return;
	}
	
	fseek(hFile, 0, SEEK_END);
	ROMLength = ftell(hFile);
	
	fseek(hFile, 0, SEEK_SET);
	ROMData = (UINT8*)malloc(ROMLength);
	fread(ROMData, 0x01, ROMLength, hFile);
	
	fclose(hFile);
	
	strcpy(FileBase, FileName);
	TempPnt = strrchr(FileBase, '.');
	if (TempPnt != NULL)
		*TempPnt = 0x00;
	
	TempPnt = strrchr(FileBase, '\\');
	if (TempPnt == NULL)
		TempPnt = FileBase - 1;
	FileTitle = strrchr(FileBase, '/');
	if (FileTitle > TempPnt)
		TempPnt = FileTitle;
	
	TempPnt ++;
	FileTitle = TempPnt + 1;
	memmove(FileTitle, TempPnt, strlen(TempPnt) + 0x01);
	*TempPnt = '\0';
	
	return;
}

UINT16 OpenZ80MemoryDump(const char* FileName, UINT8** RetData)
{
	FILE* hFile;
	size_t FileSize;
	UINT8* FileData;
	
	hFile = fopen(FileName, "rb");
	if (hFile == NULL)
	{
		printf("Error opening %s!\n", FileName);
		return 0x00;
	}
	
	fseek(hFile, 0, SEEK_END);
	FileSize = ftell(hFile);
	if (! FileSize)
	{
		fclose(hFile);
		printf("Memory dump file is empty!\n");
		return 0x00;
	}
	else if (FileSize > 0x2000)	// The Z80 has only 8 KB of RAM
	{
		fclose(hFile);
		printf("Memory dump too large - the Z80 has only 8 KB of RAM!\n");
		return 0x00;
	}
	
	fseek(hFile, 0, SEEK_SET);
	FileData = (UINT8*)malloc(FileSize);
	fread(FileData, 0x01, FileSize, hFile);
	
	fclose(hFile);
	
	*RetData = FileData;
	return (UINT16)FileSize;
}

void LoadZ80Driver(const char* DumpFileName)
{
	UINT8 RetVal;
	UINT16 Z80DrvID;
	UINT32 DrvAddr;
	UINT32 RetSize;
	Z80DRV_COLL Z80DrvColl;
	Z80DRV_COMP* TempZ80Drv;
	
	RAMMode = RAMMODE_NONE;
	RAMSize = 0x00;
	RAMData = NULL;
	
	// Specifying a file takes priority over an automatic search.
	if (DumpFileName != NULL)
	{
		RAMSize = OpenZ80MemoryDump(DumpFileName, &RAMData);
		if (RAMSize)
		{
			// Loading successful.
			RAMMode = RAMMODE_ALLOC;
			return;
		}
	}
	
	memset(&Z80DrvColl, 0x00, sizeof(Z80DRV_COLL));
	GetZ80DriverParts(&Z80DrvColl);
	GetZ80DriverParts_SegaNet(&Z80DrvColl);
	if (Z80DrvColl.Count)
	{
		Z80DrvID = 0x00;
		if (Z80DrvColl.Count > 1)
		{
			UINT8 CurZ80;
			UINT16 MaxParts;
			
			MaxParts = 0;
			for (CurZ80 = 0x00; CurZ80 < Z80DrvColl.Count; CurZ80 ++)
			{
				TempZ80Drv = &Z80DrvColl.Data[CurZ80];
				//if (TempZ80Drv->Data[0].DstOfs != 0x0000)
				//	continue;	// Sound code begins at offset 0000, which is what I need
				if (TempZ80Drv->Count > MaxParts)
				{
					// multi-part drivers are preferred
					MaxParts = TempZ80Drv->Count;
					Z80DrvID = CurZ80;
				}
				else if (TempZ80Drv->Count == MaxParts &&
					TempZ80Drv->Data[0].Length > Z80DrvColl.Data[Z80DrvID].Data[0].Length)
				{
					// else I'll just use the larger driver
					Z80DrvID = CurZ80;
				}
			}
			printf("Choosing driver #%hu.\n", Z80DrvID);
		}
		RAMSize = MakeZ80DriverDump(&RAMData, &Z80DrvColl.Data[Z80DrvID]);
		if (RAMSize)
		{
			RAMMode = RAMMODE_ALLOC;
			return;
		}
	}
	
	DrvAddr = ScanForZ80Drv_Uncomp();
	if (DrvAddr)
	{
		RAMMode = RAMMODE_PTR;
		RAMSize = 0x2001;	// +1 to tell a few routines that there might be garbabe data at the end
		RAMData = &ROMData[DrvAddr];
		return;
	}
	
	DrvAddr = ScanForZ80Drv_CompKos();
	if (DrvAddr)
	{
		RetVal = KDecomp(ROMLength - DrvAddr, &ROMData[DrvAddr], &RetSize, &RAMData, 0);
		if (! RetVal)
		{
			RAMMode = RAMMODE_ALLOC;
			RAMSize = (UINT16)DrvAddr;
		}
	}
	
	return;
}

UINT8 DoActions(UINT8 Mode, int argc, const char** argv)
{
	UINT8 DACMode;
	UINT8 RetVal;
	UINT32 MusPtr;
	UINT32 BnkPtr;
	UINT32 BnkBase;
	Z80DRV_COLL Z80DrvColl;
	
	RetVal = 0;
	RAMMode = RAMMODE_NONE;
	switch(Mode)
	{
	case 0x00:	// Song Extraction
	case 0x01:	// SFX Extraction
		if (argc >= 1)
			MusPtr = strtoul(argv[0], NULL, 0);
		else
			MusPtr = 0x00;
		
		if (! MusPtr && PtrMode == PTR_68K)
			MusPtr = ScanForSonic1Ptrs();
		
		if (! MusPtr)
		{
			printf("Please specify a %s pointer.\n", (Mode ? "sound" : "music"));
			return 2;
		}
		
		BnkPtr = 0x00;
		BnkBase = 0x00;
		if (PtrMode & 0x10)
		{
			LoadZ80Driver(Z80DumpFile);
			if (argc > 1)
				BnkPtr = (UINT32)strtoul(argv[1], NULL, 0);
			if (argc > 2)
				BnkBase = (UINT32)strtoul(argv[2], NULL, 0);
		}
		ExtractSongs(Mode, MusPtr, BnkPtr, BnkBase);
		break;
	case 0x02:	// DAC Extraction
		if (argc < 1)
		{
			printf("No DAC Mode specified!\n");
			return 1;
		}
		
		DACMode = (UINT8)strtoul(argv[0], NULL, 0);
		LoadZ80Driver(Z80DumpFile);
		
		MusPtr = 0x00;
		if (argc > 1)
		{
			MusPtr = (UINT32)strtoul(argv[1], NULL, 0);
			if (MusPtr == (UINT32)-1)
				MusPtr = 0x00;
		}
		
		RetVal = ExtractDACSounds(DACMode, MusPtr);
		break;
	case 0x03:
	case 0x06:
		MusPtr = 0x00;
		if (argc > 0)
			MusPtr = (UINT32)strtoul(argv[0], NULL, 0);
		
		LoadZ80Driver(Z80DumpFile);
		if (Mode == 0x03)
			PrintDriverInf(0x00, MusPtr);	// show info only
		else
			PrintDriverInf(0x01, MusPtr);	// show info and dump all data
		RetVal = 0;
		break;
	case 0x04:
		if (argc < 1)
		{
			printf("No Envelope Mode specified!\n");
			return 1;
		}
		if (argc < 2)
		{
			printf("No Envelope Pointer List specified!\n");
			return 1;
		}
		DACMode = (UINT8)strtoul(argv[0], NULL, 0);
		MusPtr = strtoul(argv[1], NULL, 0);
		if (DACMode & 0x08)
			LoadZ80Driver(Z80DumpFile);
		
		ExtractEnvelopes(DACMode, MusPtr);
		RetVal = 0x00;
		break;
	case 0x05:
		memset(&Z80DrvColl, 0x00, sizeof(Z80DRV_COLL));
		GetZ80DriverParts(&Z80DrvColl);
		GetZ80DriverParts_SegaNet(&Z80DrvColl);
		if (Z80DrvColl.Count)
		{
			UINT8 CurZ80;
			UINT16 MaxParts;
			char DumpFileName[0x10];
			FILE* hFile;
			
			MaxParts = 0;
			for (CurZ80 = 0x00; CurZ80 < Z80DrvColl.Count; CurZ80 ++)
			{
				RAMSize = MakeZ80DriverDump(&RAMData, &Z80DrvColl.Data[CurZ80]);
				if (! RAMSize)
					break;
				
				if (Z80DrvColl.Count == 1)
					strcpy(DumpFileName, "Z80Drv.bin");
				else
					sprintf(DumpFileName, "Z80Drv_%u.bin", CurZ80);
				hFile = fopen(DumpFileName, "wb");
				if (hFile != NULL)
				{
					fwrite(RAMData, 0x01, RAMSize, hFile);
					fclose(hFile);
				}
				free(RAMData);	RAMData = NULL;
			}
		}
		break;
	}
	if (RAMMode == RAMMODE_ALLOC)
		free(RAMData);
	
	printf("Done.\n");
	
	if (RetVal)
		return 2 + RetVal;
	else
		return 0;
}

void FixMarsPointer(UINT32* ROMPos)
{
	if (! MarsMode)
		return;
	
	switch(*ROMPos & 0xFFF80000)	// not 0xF80000 to catch Z80 RAM offsets
	{
	case 0x480000:
	case 0x880000:
		*ROMPos &= 0x07FFFF;
		break;
	case 0x900000:
	case 0x980000:
		*ROMPos = MarsBase + (*ROMPos & 0x0FFFFF);
		break;
	}
	return;
}
