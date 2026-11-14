// SMPS Driver Detection for SMPS Extract
// ---------------------
// Written by Valley Bell

#define _CRT_SECURE_NO_WARNINGS
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <memory.h>
#include <malloc.h>
#include "stdtype.h"

#include "ReadFuncs.h"
#include "DetectSearch.h"
#include "DriverInfo.h"

#include "DACExtract.h"
#include "SongExtract.h"
#include "EnvExtract.h"


//void PrintDriverInf(UINT8 DumpAll, UINT32 PtrListOfs);
static void PrintSmpsDrvType(void);
static void DetectDrvType_Z80(void);
static void DetectDrvType_Z80_Special(void);
static void DetectDrvType_68k(void);
static void DetectDrvType_68k_Special(void);
static void DetectDrvType_68k_Special_Sonic(void);
static UINT16 ParseVersionString(const char* verStr);
static void DetectDrvType_68k_Special_Clownacy(void);
static void PrintZ80Ptr(char* Str, UINT16 Ptr, UINT32 Z80Bank);
void PrintOffsets_Z80(UINT32 ForceGenPtrList);
void PrintOffsets_68k(UINT32 ForceGenPtrList);
static void ReadPtrList(UINT8 Mode, UINT8 MaxPtrCount, UINT8* RetPtrCount, UINT32* PtrList,
						UINT32 PtrListOfs, UINT32 Z80Bank);
static void PrintPtrList(UINT8 Mode, UINT8 PtrNameCnt, const char** PtrNames,
						UINT32 Z80Bank, UINT8 PtrCount, const UINT32* PtrList);
static UINT32 GetNextAddr(UINT16 PtrCnt, const UINT32* PtrList, UINT32 MinAddr);


#define MODE_68K		0x00
#define MODE_Z80		0x01

#define DRVTYPE_UNKNOWN		0x00
#define DRVTYPE_68K			0x10
#define DRVTYPE_68K_T1A		0x11
#define DRVTYPE_68K_T1B		0x12
#define DRVTYPE_68K_T2		0x13
#define DRVTYPE_68K_PICO	0x14
#define DRVTYPE_Z80			0x20
#define DRVTYPE_Z80_T1		0x21
#define DRVTYPE_Z80_T2		0x22

extern UINT32 ROMLength;
extern UINT8* ROMData;
extern UINT16 RAMSize;
extern UINT8* RAMData;
extern UINT8 PtrMode;

extern UINT8 SONG_BASE;
extern UINT8 SONG_COUNT;

extern char DAC_NAMEBASE[0x40];

static UINT8 SmpsDrvType;
static UINT8 SmpsDrv_SubType;
static char SmpsDrvType_Spc[0x40];	// Special driver string
static UINT32 SmpsDrv_Ofs_Count;
static UINT32 SmpsDrv_Offsets[0x10];
static UINT32 GeneralPtrList;
static UINT32 Z80Bank;

const char* SMPS68K_TYPES[0x10] =
{	"unknown", "1a", "1b", "2", "Pico", "", "", "",
	"", "", "", "", "", "", ""};
const char* SMPSZ80_TYPES[0x10] =
{	"unknown", "1", "2", "", "", "", "", "",
	"", "", "", "", "", "", ""};
const char* SMPS68K_SUBTYPES[0x0F] =
{	"", "", "", "", "", "", "", "",
	"", "", "", "", "", "", ""};

#define DPTYPE_MUSIC	0x01
#define DPTYPE_SFX		0x02
#define DPTYPE_DAC		0x03
#define DPTYPE_MODENV	0x04
#define DPTYPE_VOLENV	0x05

const char* PTR_NAMES_GEN[0x07] =
{	"SndPriorities", "SpcSFXPtrs", "MusicPtrs", "SFXPtrs",
	"ModEnvPtrs", "VolEnvPtrs", "Song Limit"};
const UINT8 DPARTS_GEN[0x07] =
{	0x00, DPTYPE_SFX, DPTYPE_MUSIC, DPTYPE_SFX, DPTYPE_MODENV, DPTYPE_VOLENV, 0x00};
const char* PTR_NAMES_Z80_T1[0x02] =
{	"DACDrumPtrs", "DACVoicePtrs"};
const char* PTR_NAMES_68K[0x01] =
{	"UpdateSound"};
const char* PTR_NAMES_68K_PICO[0x04] =
{	"SoundRAM", "DoPCMStream", "StreamPCMData", "PSGDrumData"};

typedef struct
{
	UINT8 Type;
	UINT8 IDBase;
	UINT32 Size;
	UINT32 Offset;
} DUMP_PARTS;

UINT8 DumpPartCnt;
DUMP_PARTS DumpParts[0x20];

void PrintDriverInf(UINT8 DumpAll, UINT32 PtrListOfs)
{
	// --- Step 1: Detect the Driver Type ---
	SmpsDrvType = DRVTYPE_UNKNOWN;
	SmpsDrv_SubType = 0x00;
	strcpy(SmpsDrvType_Spc, "");
	SmpsDrv_Ofs_Count = 0;
	
	DetectDrvType_Z80();
	if (SmpsDrvType == DRVTYPE_UNKNOWN)
		DetectDrvType_68k();
	
	memset(DumpParts, 0x00, 0x20 * sizeof(DUMP_PARTS));
	switch(SmpsDrvType & 0xF0)
	{
	case DRVTYPE_UNKNOWN:
		printf("SMPS Driver Type: ");
		printf("Unknown\n");
		return;
	case DRVTYPE_68K:
		DetectDrvType_68k_Special();
		PrintSmpsDrvType();
		PrintOffsets_68k(PtrListOfs);
		break;
	case DRVTYPE_Z80:
		DetectDrvType_Z80_Special();
		PrintSmpsDrvType();
		PrintOffsets_Z80(PtrListOfs);
		break;
	default:
		printf("SMPS Driver Type: ");
		printf("???\n");
		return;
	}
	
	if (DumpAll)
	{
		UINT8 ModeFlags;
		UINT8 CurPtr;
		UINT8 CurDigits;
		DUMP_PARTS* TempDP;
		UINT32 TempOfs;
		
		for (CurPtr = 0x00; CurPtr < DumpPartCnt; CurPtr ++)
		{
			TempDP = &DumpParts[CurPtr];
			SONG_BASE = 0xFF;
			SONG_COUNT = 0x00;
			switch(TempDP->Type)
			{
			case DPTYPE_MODENV:
			case DPTYPE_VOLENV:
				TempOfs = TempDP->Offset;
				if ((SmpsDrvType & 0xF0) == DRVTYPE_68K)
				{
					ModeFlags = ENVPTR_68K;
					CurDigits = 6;
				}
				else if ((SmpsDrvType & 0xF0) == DRVTYPE_Z80)
				{
					ModeFlags = ENVPTR_Z80;
					CurDigits = 4;
					if (TempDP->Offset < 0x8000)
						ModeFlags |= ENVPTR_RAM;
					else
						TempOfs = (Z80Bank & 0xFF8000) | (TempOfs & 0x7FFF);
				}
				
				if (TempDP->Type == DPTYPE_VOLENV)
					ModeFlags |= ENVMODE_VOL;
				else if (TempDP->Type == DPTYPE_MODENV)
					ModeFlags |= ENVMODE_MOD;
				printf("Envelope Extraction: Mode %02X, Offset %0*X ...\n", ModeFlags, CurDigits, TempOfs);
				if (TempDP->Offset == DumpParts[CurPtr + 0x01].Offset)
				{
					printf("    skipped. (Pointer invalid)\n");
					break;
				}
				
				ExtractEnvelopes(ModeFlags, TempOfs);
				break;
			case DPTYPE_MUSIC:
				TempOfs = TempDP->Offset;
				if ((SmpsDrvType & 0xF0) == DRVTYPE_68K)
				{
					if (TempDP->Size <= 0x400)
						SONG_COUNT = TempDP->Size / 0x04;
					ModeFlags = PTR_68K;
				}
				else if ((SmpsDrvType & 0xF0) == DRVTYPE_Z80)
				{
					if (SmpsDrvType == DRVTYPE_Z80_T2)
					{
						printf("Song Extraction: skipped. Requires separate bank setting.\n");
						break;	// requires additional bank setting
					}
					if (TempDP->Offset & 0x8000)
					{
						ModeFlags = PTR_Z80;
						TempOfs = (Z80Bank & 0xFF8000) | (TempOfs & 0x7FFF);
					}
					else
					{
						//ModeFlags = PTR_Z80RAM;
						ModeFlags = PTR_Z80;
					}
					if (TempDP->Size <= 0x100)
						SONG_COUNT = TempDP->Size / 0x02;
				}
				if (TempDP->IDBase)
					SONG_BASE = TempDP->IDBase;
				
				printf("Song Extraction: Mode %02X, Offset %04X ...\n", ModeFlags, TempOfs);
				PtrMode = ModeFlags;
				ExtractSongs(0x00, TempOfs, 0x00, 0x00);
				break;
			case DPTYPE_DAC:
				if (SmpsDrvType == DRVTYPE_Z80_T1)
				{
					if (TempDP->Size == 1)
						strcpy(DAC_NAMEBASE, "DAC_Voice");
					else
						strcpy(DAC_NAMEBASE, "DAC");
					TempOfs = Z80Bank | (TempDP->Offset & 0x7FFF);
					printf("DAC Extraction: Mode %02X (%s), Offset %04X ...\n", 0x0E, DAC_NAMEBASE, TempOfs);
					ExtractDACSounds(0x0E, TempOfs);
				}
				break;
			}
		}
		if (SmpsDrvType == DRVTYPE_68K)
		{
			strcpy(DAC_NAMEBASE, "DAC");
			ExtractDACSounds(0x06, 0x00);
			strcpy(DAC_NAMEBASE, "DAC_Voice");
			ExtractDACSounds(0x08, 0x00);
		}
	}
	
	return;
}

static void PrintSmpsDrvType(void)
{
	const char* drvStr_pre;
	const char* drvStr_CPU;
	const char* drvStr_Type;
	
	drvStr_pre = "";
	switch(SmpsDrvType & 0xF0)
	{
	case DRVTYPE_68K:
		drvStr_CPU = "68k";
		drvStr_Type = SMPS68K_TYPES[SmpsDrvType & 0x0F];
		break;
	case DRVTYPE_Z80:
		drvStr_CPU = "Z80";
		drvStr_Type = SMPSZ80_TYPES[SmpsDrvType & 0x0F];
		break;
	}
	
	printf("SMPS Driver Type: ");
	if (SmpsDrvType_Spc[0] == '\0')
		printf("%sSMPS %s, Type %s\n", drvStr_pre, drvStr_CPU, drvStr_Type);
	else
		printf("%sSMPS %s, Type %s - %s\n", drvStr_pre, drvStr_CPU, drvStr_Type, SmpsDrvType_Spc);
	
	return;
}

static void DetectDrvType_Z80(void)
{
	const UINT8 MAGIC_Z80_CHECK[0x04] = {0x79, 0x32, 0x03, 0x40};
	const UINT8 MAGIC_Z80_T1[0x04] = {0x3A, 0x00, 0x40, 0xCB};
	const UINT8 MAGIC_Z80_T2[0x05] = {0x4F, 0x06, 0x00, 0x09, 0x09};
	UINT16 CurPos;
	
	if (! RAMSize)
		return;	// can't work without Z80 RAM
	
	// Check for Z80 sound driver in general:
	// 0113	79			LD		A, C
	// 0114	32 03 40	LD		(4003h), A
	CurPos = ScanForData(RAMSize, RAMData, 0x04, MAGIC_Z80_CHECK, 0x00);
	if (! CurPos)
		return;	// This should catch most DAC drivers, at least.
	
	// Common for SMPS Z80 Type 1:
	//		WaitForYM:
	// 0008	3A 00 40	LD		A, (4000h)
	// 000B	CB 7F		BIT		7, A
	// 000D	20 F9		JR		NZ, -07h	; [0008h]
	// 000F	C9			RET
	if (! memcmp(&RAMData[0x08], MAGIC_Z80_T1, 0x03))	// check the LD A, (4000h) instruction
	{
		SmpsDrvType = DRVTYPE_Z80_T1;
		return;
	}
	// If that didn't work, try searching for "LD A, (4000h)" with a bit test right after it.
	// None of the SMPS Z80 Type 2 drivers does this.
	CurPos = ScanForData(RAMSize, RAMData, 0x04, MAGIC_Z80_T1, 0x00);
	if (CurPos)
	{
		SmpsDrvType = DRVTYPE_Z80;
		return;
	}
	
	// All SMPS Z80 Type 2 drivers have this at offset 0008 or 0018. (Z80 Type 1 has it usually at 0028.)
	//		ReadPtrTable:
	// 0008	4F			LD		C, A
	// 0009	06 00		LD		B, 00h
	// 000B	09			ADD		HL, BC
	// 000C	09			ADD		HL, BC
	CurPos = ScanForData(RAMSize, RAMData, 0x05, MAGIC_Z80_T2, 0x00);
	if (CurPos == 0x0008 || CurPos == 0x0018)
	{
		SmpsDrvType = DRVTYPE_Z80_T2;
		return;
	}
	
	return;
}

static void DetectDrvType_Z80_Special(void)
{
	const UINT8 MAGIC_S3K_SEGA[0x07] =
	{	0x3E, 0x2A, 0x32, 0x00, 0x40, 0x00, 0x7E};
	UINT32 CurPos;
	
	if (SmpsDrvType == DRVTYPE_Z80_T2)
	{
		// Sonic 3 & Knuckles - check part of SEGA PCM code
		// 1144	21 00 80	LD		HL, 8000h
		// 1147	11 2F 5E	LD		DE, 5E2Fh
		// 114A	3E 2A		LD		A, 2Ah
		// 114C	32 00 40	LD		(4000h), A
		// 114F	00			NOP
		// 1150	7E			LD		A, (HL)
		CurPos = ScanForData(RAMSize, RAMData, 0x07, MAGIC_S3K_SEGA, 0x06);	// must start at 0x06 or later
		while(CurPos)
		{
			if (RAMData[CurPos - 0x06] == 0x21 && RAMData[CurPos - 0x03] == 0x11)
			{
				SmpsDrv_SubType = 0x01;
				strcpy(SmpsDrvType_Spc, "Sonic 3 & Knuckles");
				return;
			}
			else if (RAMData[CurPos - 0x06] == 0x8A && RAMData[CurPos - 0x03] == 0x5B)
			{
				SmpsDrv_SubType = 0x02;
				strcpy(SmpsDrvType_Spc, "Sonic 3K/Varion mod");
				return;
			}
			CurPos = ScanForData(RAMSize, RAMData, 0x07, MAGIC_S3K_SEGA, CurPos + 0x01);
		}
	}
	
	return;
}

static void DetectDrvType_68k(void)
{
	const UINT8 MAGIC_68K_CHECK[0x0C] =
	{	0x41, 0xF9, 0x00, 0xA0, 0x40, 0x00,
		0x08, 0x10, 0x00, 0x07, 0x66, 0xFA};
	const UINT8 MAGIC_68K_CHECK_EARLY[0x0C] =
	{	0x14, 0x39, 0x00, 0xA0, 0x40, 0x00,
		0x08, 0x02, 0x00, 0x07, 0x66, 0xF4};
	const UINT8 MAGIC_68K_CHECK_AS[0x0E] =
	{	0x41, 0xF9, 0x00, 0xA0, 0x40, 0x00,
		0x33, 0xFC, 0x01, 0x00, 0x00, 0xA1, 0x11, 0x00};
	const UINT8 MAGIC_68K_CHECK_DH[0x14] =
	{	0x41, 0xF9, 0x00, 0xA0, 0x40, 0x00,
		0x40, 0xE7, 0x00, 0x7C, 0x07, 0x00,
		0x33, 0xFC, 0x01, 0x00, 0x00, 0xA1, 0x11, 0x00};
	const UINT8 MAGIC_68K_CHECK_S2R[0x08] =
	{	0x4A, 0x39, 0x00, 0xA0, 0x40, 0x00, 0x6B, 0xF8};
	const UINT8 MAGIC_68K_CHECK_S2C2_V225[0x10] =
	{	0x41, 0xF9, 0x00, 0xA0, 0x40, 0x00, 0x4E, 0x71, 0x4E, 0x71, 0x4E, 0x71, 0x4A, 0x10, 0x6B, 0xFC};
	const UINT8 MAGIC_68K_CHECK_PICO[0x0C] =
	{	0x13, 0xC0, 0x00, 0xC0, 0x00, 0x11, 0x13, 0xC6, 0x00, 0xC0, 0x00, 0x11};
	const UINT8 MAGIC_68K_PLAYMUSIC_EARLY[0x05] =
	{	0x04, 0x00, 0x00, 0x81, 0x65};
	const UINT8 MAGIC_68K_MODULATION[0x0A] =
	{	0x4A, 0x2D, 0x00, 0x18, 0x67, 0x06, 0x53, 0x2D, 0x00, 0x018};
	const UINT8 MAGIC_68K_MODULATION_W[0x0C] =
	{	0x4A, 0x2D, 0x00, 0x18, 0x67, 0x00, 0x00, 0x08, 0x53, 0x2D, 0x00, 0x018};
	UINT32 BasePos;
	UINT32 CurPos;
	UINT16 CurInst;
	UINT8 DrvMode;
	
	DrvMode = 0x00;
	// Check for 68k sound driver in general:
	// Check, if the offset A04000 can be found. If not, it's not using a 68k sound driver at all.
	// (And if it's found, it speeds up the other scans.)
	BasePos = ScanForData2(ROMLength, ROMData, 0x04, &MAGIC_68K_CHECK[0x02], 0x100);
	if (BasePos)
	{
		BasePos -= 0x10;	// It may be part of the instruction we're searching for, so go back a bit.
		DrvMode = 0x01;		// SMPS 68k/MegaDrive
	}
	if (! BasePos)
	{
		// The Sega Pico console lacks an FM chip, so I need to check for PSG.
		//	0B0E70	13C0 00C0 0011		MOVE.B	D0, ($C00011).l
		//	0B0E76	13C6 00C0 0011		MOVE.B	D6, ($C00011).l
		BasePos = ScanForData2(ROMLength, ROMData, 0x0C, MAGIC_68K_CHECK_PICO, 0x100);
		if (BasePos)
		{
			BasePos -= 0x10;	// It may be part of the instruction we're searching for, so go back a bit.
			DrvMode = 0x02;		// SMPS 68k/Sega Pico
		}
	}
	if (! DrvMode)
		return;
	
	CurPos = 0x00;
	switch(DrvMode)
	{
	case 0x01:
		// normal SMPS 68k: (from Golden Axe II)
		//WriteFMI:
		// 076D18	41F9 00A0 4000	LEA		$A04000.l, A0
		// 076D1E	0810 0007		BTST	#7, (A0)
		// 076D22	66FA			BNE		$076D1E
		printf("1..");
		CurPos = ScanForData2(ROMLength, ROMData, 0x0C, MAGIC_68K_CHECK, BasePos);
		if (! CurPos)
		{
			// early SMPS 68k: (from MJ's Moonwalker, i.e. Type 1a)
			// Note: also Sonic 1 (Type 1b)
			//WriteFMI:
			// 060F9C	1439 00A0 4000	MOVE.B	$A04000.l, D2
			// 060FA2	0802 0007		BTST	#7, D2
			// 060FA6	66F4			BNE		$060F9C
			printf("2..");
			CurPos = ScanForData2(ROMLength, ROMData, 0x0C, MAGIC_68K_CHECK_EARLY, BasePos);
		}
		if (! CurPos)
		{
			// Alien Soldier is a bit special:
			//WriteFMI:
			//	0835CC	41F9 00A0 4000		LEA		$A04000.l, A0
			//	0835D2	33FC 0100 00A1 1100	MOVE.W	#$100, $A11100.l
			//	... (the actual YM2612 ready-test comes later)
			printf("3..");
			CurPos = ScanForData2(ROMLength, ROMData, 0x0E, MAGIC_68K_CHECK_AS, BasePos);
		}
		if (! CurPos)
		{
			// ... and Dynamite Headdy (JE) is even more special:
			// (Note: the (J) version is more like normal SMPS 68k)
			//WriteFMI:
			//	05C7C6	41F9 00A0 4000		LEA		$A04000.l, A0
			//	05C7CC	40E7				MOVE	SR, -(SP)
			//	05C7CE	007C 0700			ORI		#$0700, SP
			//	05C7D2	33FC 0100 00A1 1100	MOVE.W	#$100, $A11100.l
			//	... (the actual YM2612 ready-test comes later)
			printf("4..");
			CurPos = ScanForData2(ROMLength, ROMData, 0x14, MAGIC_68K_CHECK_DH, BasePos);
		}
		if (! CurPos)
		{
			// And this is to detect my own Sonic 1 SMPS driver mod. :P (Sonic 2 Clone Driver, Valley Bell Edition)
			// (Oh, and Clownacy seems to do this in his S2 Clone Driver 2.0, too.)
			//	10DC60	4A39 00A0 4000		TST.B	$A04000.l
			//	10DC64	6BF8				BMI.S	loc_10DC60
			printf("5..");
			CurPos = ScanForData2(ROMLength, ROMData, 0x08, MAGIC_68K_CHECK_S2R, BasePos);
		}
		if (! CurPos)
		{
			// Yet another variation - this time to detect Clownacy's S2 Clone Driver v2.2.5+
			//	172A18	41F9 00A0 4000		LEA		$A04000.l, A0
			//	172A1E	4E71				NOP
			//	172A20	4E71				NOP
			//	172A22	4E71				NOP
			//	172A24	4A10				TST.B	(A0)
			//	172A26	6BFC				BMI.S	loc_172A24
			printf("6..");
			CurPos = ScanForData2(ROMLength, ROMData, 0x10, MAGIC_68K_CHECK_S2C2_V225, BasePos);
			SmpsDrv_SubType = 0x10;
		}
		printf("\r");
		break;
	case 0x02:
		SmpsDrvType = DRVTYPE_68K_PICO;
		return;
	default:
		return;
	}
	if (! CurPos)
		return;
	
	// At first, check for SMPS 68k Type 1a
	// 0609F4	0400 0081		SUBI.B	#$81, D0
	// 0609F8	6500 FDF0		BLO.W	$0607EA			; ClearSoundID
	// 0609FC	2F00			MOVE.L	D0, -(SP)
	// 0609FE	6100 0146		BSR		$060B46			; ClearMusicTrks
	// 060A02	207C 0006 0000	MOVEA.L	#$060000, A0	; GeneralPtrList
	CurPos = ScanForData2(ROMLength, ROMData, 0x05, MAGIC_68K_PLAYMUSIC_EARLY, 0x00);
	if (CurPos)
	{
		CurInst = ReadBE16(&ROMData[CurPos + 0x0E]);
		if ((CurInst & 0xF1FF) == 0x207C)	// check for MOVEA.L
		{
			SmpsDrvType = DRVTYPE_68K_T1A;
			GeneralPtrList = ReadBE32(&ROMData[CurPos + 0x10]);
			//printf("General Pointer List: %06X\n", GeneralPtrList);
			return;
		}
	}
	
	// The main difference between SMPS 68k Type 1 and 2 is support for
	// Modulation Envelopes in Type 2. For that, the DoModulation routine has a tiny difference.
	
	// SMPS 68k Type 1b:							SMPS 68k Type 2
	//			DoModulation:	; Golden Axe II				DoModulation:	; Fatal Fury
	// 0763F2	584F			ADDQ.W	#4, SP		------
	// 0763F4	0815 0003		BTST	#3, (A5)	160276	082D 0007 000A	BTST	#7, $0A(A5)
	// 0763F8	6748			BEQ.S	$076442		16027C	6746			BEQ.S	$1602C4		; locret
	// 0763FA	4A2D 0018		TST.B	$18(A5)		16027E	4A2D 0018		TST.B	$18(A5)
	// 0763FE	6706			BEQ.S	$076406		160282	6706			BEQ.S	$16028A
	// 076400	532D 0018		SUBQ.B	#1, $18(A5)	160284	532D 0018		SUBQ.B	#1, $18(A5)
	// 076404	4E75			RTS					160288	4E75			RTS
	CurPos = ScanForData2(ROMLength, ROMData, 0x0A, MAGIC_68K_MODULATION, 0x00);
	if (! CurPos)
	{
		// Well, that didn't work. Try again with BEQ.W for all.
		CurPos = ScanForData2(ROMLength, ROMData, 0x0C, MAGIC_68K_MODULATION_W, 0x00);
	}
	if (CurPos)
	{
		CurInst = ReadBE16(&ROMData[CurPos - 0x08]);
		if (CurInst == 0x584F)
			SmpsDrvType = DRVTYPE_68K_T1B;
		else if (CurInst == 0x082D)
			SmpsDrvType = DRVTYPE_68K_T2;
		
		if (SmpsDrvType == DRVTYPE_UNKNOWN)
		{
			CurInst = ReadBE16(&ROMData[CurPos - 0x0A]);	// check here again (Ristar uses a BEQ.W after the BTST)
			if (CurInst == 0x584F)
				SmpsDrvType = DRVTYPE_68K_T1B;
			else if (CurInst == 0x082D)
				SmpsDrvType = DRVTYPE_68K_T2;
		}
		if (SmpsDrvType == DRVTYPE_UNKNOWN)
		{
			if (ROMData[CurPos - 0x06] == 0x08 && ROMData[CurPos - 0x03] == 0x03)
				SmpsDrvType = DRVTYPE_68K_T1B;
		}
	}
	
	return;
}

static void SortPointerLists(UINT8 PtrCount, UINT32* ListToSort, UINT32* OrderList)
{
	UINT8 CurPtr;
	UINT8 CurIt;
	UINT8 AllOK;
	UINT32 TempPtr;
	
	// simple bubble sort
	for (CurIt = 0; CurIt < PtrCount - 1; CurIt ++)
	{
		AllOK = 0x01;
		for (CurPtr = 0; CurPtr < PtrCount - 1; CurPtr ++)
		{
			if (OrderList[CurPtr + 0] > OrderList[CurPtr + 1])
			{
				AllOK = 0x00;
				// swap pointers in both lists
				TempPtr = OrderList[CurPtr + 0];
				OrderList[CurPtr + 0] = OrderList[CurPtr + 1];
				OrderList[CurPtr + 1] = TempPtr;
				TempPtr = ListToSort[CurPtr + 0];
				ListToSort[CurPtr + 0] = ListToSort[CurPtr + 1];
				ListToSort[CurPtr + 1] = TempPtr;
			}
		}
		if (AllOK)
			break;
	}
	
	return;
}

static void DetectDrvType_68k_Special(void)
{
	if (SmpsDrv_SubType == 0x10)
	{
		DetectDrvType_68k_Special_Clownacy();
		return;
	}
	DetectDrvType_68k_Special_Sonic();
	if (SmpsDrv_SubType)
		return;
	// TODO: Ristar
	return;
}

static void DetectDrvType_68k_Special_Sonic(void)
{
//	const UINT8 MAGIC_SONIC_1_SPDUP_TEMPO[0x0C] =
//	{	0x04, 0x07, 0x00, 0x81, 0x1D, 0x74, 0x70, 0x00, 0x00, 0x29, 0x28, 0x79};
	const UINT8 MAGIC_SONIC_1_SPDUP_TEMPO[0x10] =
	{	0x28, 0x79, 0x00, 0xFF, 0xFF, 0xFF, 0x04, 0x07, 0x00, 0xFF, 0x1D, 0x74, 0x70, 0x00, 0x00, 0x29};
	const UINT8 MAGIC_S2_CLONE_PLAYSPCCMD[0x08] =
	{	0xE5, 0x4F, 0x4E, 0xFB, 0x70, 0x02, 0x60, 0x00};
	const UINT8 MAGIC_S2_CLONE_PLAYSPCCMD2[0x0A] =
	{	0xDE, 0x47, 0xDE, 0x47, 0x4E, 0xFB, 0x70, 0x02, 0x60, 0x00};
	const UINT8 MAGIC_S1_INDEX_00[0x08] =
	{	0x0C, 0x38, 0x00, 0x01, 0xFF, 0xFC, 0x66, 0x06};
	const UINT8 MAGIC_S1_INDEX_E5[0x09] =
	{	0x11, 0xFC, 0x00, 0x01, 0xFF, 0xFD, 0x04, 0x07, 0x00};
	const UINT8 MAGIC_S1_LIST_LOAD[0x0A] =
	{	0x0C, 0x38, 0x00, 0x01, 0xFF, 0xFF, 0x66, 0xFF, 0x28, 0x79};
	UINT32 CurPos;
	UINT32 BasePos;
	UINT16 CurInst;
	UINT8 TempByt;
	UINT32 TempOfsList[8];
	
	// Sonic 1 sound driver
	// 072030	2879 0007 19A0		MOVEA.L	($0719A0).l, A4		; Pointer to SpeedUp Tempo List
	// 072036	0407 0081			SUBI.B	#$81, D7
	// 07203A	1D74 7000 0029		MOVE.B	(A4,D7.w), $29(A6)
	// 072040	2879 0007 1998		MOVEA.L	($071998).l, A4		; Pointer to Music Pointer List
	CurPos = ScanForData_WC(ROMLength, ROMData, 0x10-1, MAGIC_SONIC_1_SPDUP_TEMPO, 0x100);
	if (! CurPos)
		return;
	
	CurInst = ReadBE16(&ROMData[CurPos + 0x10]);
	if (! (CurInst == 0x2879 || CurInst == 0x49F9))
		return;
	
	BasePos = CurPos;
	strcpy(SmpsDrvType_Spc, "Sonic 1");
	SmpsDrv_SubType = 0x01;
	while(ROMData[CurPos + 0x09] >= 0xE0)
	{
		CurPos = ScanForData_WC(ROMLength, ROMData, 0x10, MAGIC_SONIC_1_SPDUP_TEMPO, CurPos + 0x0A);
		if (! CurPos)
		{
			CurPos = BasePos;
			break;
		}
	}
	printf("First song index: %02X\n", ROMData[CurPos + 0x09]);
	
	
	// Sonic 2 Clone Driver
	//	0407 00F9		SUBI.B	#$F9, D7
	//	E54F			LSL.W	#2, D7
	//	4EFB 7002		JMP		Sound_ExIndex(PC,D7.w)
	//	6000 xxxx		BRA.W	xxxx
	// Alternatively replace LSL.W #2 with two ADD.W (DE47)
	CurPos = ScanForData2(ROMLength, ROMData, 0x08, MAGIC_S2_CLONE_PLAYSPCCMD, 0x100);
	if (! CurPos)
		CurPos = ScanForData2(ROMLength, ROMData, 0x0A, MAGIC_S2_CLONE_PLAYSPCCMD2, 0x100);
	if (CurPos && ReadBE16(&ROMData[CurPos - 0x04]) == 0x0407 && ROMData[CurPos - 0x01] >= 0xF0)
	{
		strcpy(SmpsDrvType_Spc, "S2 Clone Driver");
		printf("Command Base: %02X\n", ROMData[CurPos - 0x01]);
		SmpsDrv_SubType = 0x02;
	}
	
	// Sonic 1 index extention [old]: "Extend Music Slots in Sonic 1"
	//	Go_MusicIndex:		dc.l MusicIndex
	//	Go_MusicIndex_E5toFF:	dc.l MusicIndex_E5plus
	// Sonic 1 index extention [new]: "Expand the music index to start at $00 instead of $80"
	//	Go_MusicIndex:		dc.l MusicIndex
	//	Go_MusicIndex00:	dc.l MusicIndex00
	//	Go_MusicIndexFF:	dc.l MusicIndexFF
	// Sonic 2 Clone Driver index extention:
	//	Go_MusicIndex:			dc.l MusicIndex
	//	Go_MusicIndex_01to1F:	dc.l MusicIndex_01plus
	if (SmpsDrv_SubType == 0x01)
	{
		if (ROMData[BasePos + 0x09] >= 0xE0)	// Sonic 1 index extention #1 (81-9F and E5-FF)
		{
			SmpsDrv_SubType += 0x02;
			strcat(SmpsDrvType_Spc, " [old index extention]");
			SmpsDrv_Offsets[SmpsDrv_Ofs_Count] = ROMData[BasePos + 0x09];
			SmpsDrv_Ofs_Count ++;
		}
	}
	
	// Index Extention 00-7F [S1 + S2 Clone]
	//	0C38 0001 FFFC	CMPI.B	#1, $FFFC.w
	//	6606			BNE.S	...
	CurPos = ScanForData2(ROMLength, ROMData, 0x08, MAGIC_S1_INDEX_00, 0x100);
	if (CurPos)
	{
		if (SmpsDrv_SubType <= 0x02)
		{
			SmpsDrv_SubType += 0x02;
			strcat(SmpsDrvType_Spc, " [new index extention]");
		}
		SmpsDrv_Offsets[SmpsDrv_Ofs_Count] = 0x01;
		SmpsDrv_Ofs_Count ++;
	}
	
	if (SmpsDrv_SubType == 0x01 || SmpsDrv_SubType == 0x03)
	{
		// Index Extention E5-FF [Sonic 1 only]
		//	11FC 0001 FFFD	MOVE.B	#1, $FFFD.w
		//	0407 0064		SUBI.B	#$64, D7	; E5-FF -> 81-9B
		CurPos = ScanForData2(ROMLength, ROMData, 0x09, MAGIC_S1_INDEX_E5, 0x100);
		if (CurPos)
		{
			if (SmpsDrv_SubType <= 0x02)
			{
				SmpsDrv_SubType += 0x02;
				strcat(SmpsDrvType_Spc, " [new index extention E5-FF]");
			}
			SmpsDrv_Offsets[SmpsDrv_Ofs_Count] = ROMData[CurPos + 0x09] + 0x81;
			SmpsDrv_Ofs_Count ++;
			
			// Now determine the order of the music lists.
			TempByt = 0x03;
			CurPos = ScanForData_WC(ROMLength, ROMData, 0x0A, MAGIC_S1_LIST_LOAD, CurPos + 0x0A);
			while(CurPos)
			{
				CurInst = ReadBE16(&ROMData[CurPos + 0x04]);
				if (CurInst == 0xFFFC || CurInst == 0xFFFD)
				{
					CurInst &= 0x01;
					TempOfsList[CurInst] = ReadBE32(&ROMData[CurPos + 0x0A]);
					TempByt &= ~(1 << CurInst);	// remove one of the bits
					if (! TempByt)
						break;
				}
				CurPos = ScanForData_WC(ROMLength, ROMData, 0x0A, MAGIC_S1_LIST_LOAD, CurPos + 0x0A);
			}
			if (! TempByt)
			{
				if (TempOfsList[0] > TempOfsList[1])
				{
					CurPos = SmpsDrv_Offsets[0];
					SmpsDrv_Offsets[0] = SmpsDrv_Offsets[1];
					SmpsDrv_Offsets[1] = CurPos;
				}
			}
		}
	}
	
	if (SmpsDrv_SubType <= 0x02)
	{
		CurPos = BasePos;
		while(CurPos)
		{
			if (ROMData[CurPos + 0x09] != 0x81)
			{
				if (SmpsDrv_SubType <= 0x02)
				{
					SmpsDrv_SubType += 0x02;
					strcat(SmpsDrvType_Spc, " [alt. index extention]");
				}
				SmpsDrv_Offsets[SmpsDrv_Ofs_Count] = ROMData[CurPos + 0x09];
				TempOfsList[SmpsDrv_Ofs_Count] = ReadBE32(&ROMData[CurPos + 0x12]);
				SmpsDrv_Ofs_Count ++;
			}
			CurPos = ScanForData_WC(ROMLength, ROMData, 0x10, MAGIC_SONIC_1_SPDUP_TEMPO, CurPos + 0x10);
		}
		SortPointerLists(SmpsDrv_Ofs_Count, SmpsDrv_Offsets, TempOfsList);
	}
	
	return;
}

static UINT16 ParseVersionString(const char* verStr)
{
	UINT8 verDigits[3];
	
	// skip until number of reached
	while(! (*verStr >= '0' && *verStr <= '9'))
	{
		if (*verStr == ')')
			return 0x000;
		verStr ++;
	}
	memset(verDigits, 0, 3);
	
	verDigits[0] = *verStr - '0';
	verStr ++;
	if (*verStr == '.')
	{
		verStr ++;
		verDigits[1] = *verStr - '0';
		if (*verStr == '.')
			verStr ++;
		if (*verStr >= '0' && *verStr <= '9')
			verDigits[2] = *verStr - '0';
	}
	
	return (verDigits[0] << 8) | (verDigits[1] << 4) | (verDigits[2] << 0);
}

static void DetectDrvType_68k_Special_Clownacy(void)
{
	const char* CloneDrv_Text = "Clownacy's Sonic 2 Clone Driver v2";
	UINT16 cdVer;
	UINT32 BasePos;
	UINT32 CurPos;
	
	cdVer = 0x225;	// minimum is 2.25
	
	BasePos = 0x100;
	CurPos = ScanForData(ROMLength, ROMData, strlen(CloneDrv_Text), (UINT8*)CloneDrv_Text, BasePos);
	if (CurPos)
	{
		CurPos += strlen(CloneDrv_Text);
		if (ROMData[CurPos + 0x00] == ' ' && ROMData[CurPos + 0x01] == '(')
			cdVer = ParseVersionString((char*)&ROMData[CurPos + 0x02]);
		BasePos = CurPos;
	}
	
	// --- finding sound priorities ---
	// S2 Clone Driver v2.2.5+
	//							LEA		SoundPriorities(PC), A0
	//							LEA		v_playsnd1(A6), A1
	//							MOVE.B	v_sndprio(A6), D3
	//							MOVEQ	#3, D4
	//							MOVEQ	#0, D0
	
	// --- finding music pointers + speedup tempo values ---
	// S2 Clone Driver v2.1.0 - 2.2.41
	//			41F9 00xx xxxx	LEA		(SpeedUpIndex).l, A4
	//			0407 0001		SUBI.B	#MusID__First, D7
	//			1D74 7000 00xx	MOVE.B	(A4,D7.w), v_speeduptempo(A6)
	//			41F9 00xx xxxx	LEA		(MusicIndex).l, A4
	//			DE47			ADD.W	D7, D7
	//			DE47			ADD.W	D7, D7
	//			2234 7000		MOVEA.L	(A4,D7.w), D1
	// S2 Clone Driver v2.2.5+
	//			49FA xxxx		LEA		SpeedUpIndex(PC), A4
	//			0407 0001		SUBI.B	#MusID__First, D7
	//			1D74 7000 00xx	MOVE.B	(A4,D7.w), v_speeduptempo(A6)
	//			49FA xxxx		LEA		MusicIndex(PC), A4
	//			DE47			ADD.W	D7, D7
	//			DE47			ADD.W	D7, D7
	//			2234 7000		MOVEA.L	(A4,D7.w), D1
	
	// --- finding SFX pointers ---
	//			41FA xxxx		LEA		SoundIndex(PC), A0
	//			0407 00xx		SUBI.B	#SndID__First, D7
	//			DE47			ADD.W	D7, D7
	//			DE47			ADD.W	D7, D7
	//			2670 7000		MOVEA.L	(A0,D7.w), A3
	//			224B			MOVEA.L	A3, A1
	
	// --- finding volume envelope pointers ---
	//			1C2D 00xx		MOVE.B	zTrackVolume(A5), D6
	//			7000			MOVEQ	#0, D0
	//			102D 00xx		MOVE.B	zTrackVoiceIndex(A5), D0
	//			67xx			BEQ.S	SetPSGVolume
	//			41FA xxxx		LEA		PSG_Index(PC), A0
	//			5340			SUBQ.W	#1, D0
	//			D040			ADD.W	D0, D0
	//			D040			ADD.W	D0, D0
	//			2070 0000		MOVEA.L	(A0,D0.w), A0
	
	sprintf(SmpsDrvType_Spc, "S2 Clone Driver v%X.%02X", (cdVer & 0xF00) >> 8, (cdVer & 0x0FF) >> 0);
	return;
}

static void PrintZ80Ptr(char* Str, UINT16 Ptr, UINT32 Z80Bank)
{
	if (! Z80Bank || Ptr < 0x8000)
		sprintf(Str, "%04X", Ptr);
	else
		sprintf(Str, "%04X -> %06X", Ptr, (Z80Bank & 0xFF8000) | (Ptr & 0x7FFF));
	
	return;
}

void PrintOffsets_Z80(UINT32 ForceGenPtrList)
{
	const UINT8 MAGIC_READ_PTR_TBL[0x05] = {0x4F, 0x06, 0x00, 0x09, 0x09};
	const UINT8 MAGIC_LD_HL__B_0[0x05] = {0x2A, 0xFF, 0xFF, 0x06, 0x00};
	const UINT8 MAGIC_LD_HL_1C02[0x03] = {0x2A, 0x02, 0x1C};
	const UINT8 MAGIC_PLAYSND_C[0x0B] = {0xFE, 0xFF, 0xDA, 0xFF, 0xFF, 0xFE, 0xFF, 0xDA, 0xFF, 0xFF, 0xFE};
	const UINT8 MAGIC_PLAYSND_NC[0x0B] = {0xFE, 0xFF, 0xD2, 0xFF, 0xFF, 0xFE, 0xFF, 0xD2, 0xFF, 0xFF, 0xFE};
	UINT8 PTR_NAME_CNT;
	const char* PTR_NAMES[0x20];
	UINT32 CurPos;
	UINT32 MaxPos;
	UINT16 GenPtrListPtr;
	UINT8 SmpsCfgData[0x08];
	char Z80PtrStr[0x20];
	UINT8 PtrCount;
	UINT32 PtrList[0x20];
	UINT8 CurPtr;
	
	PTR_NAME_CNT = 0x00;
	for (CurPtr = 0x00; CurPtr < 0x07; CurPtr ++)
	{
		PTR_NAMES[PTR_NAME_CNT + CurPtr] = PTR_NAMES_GEN[CurPtr];
		DumpParts[PTR_NAME_CNT + CurPtr].Type = DPARTS_GEN[CurPtr];
	}
	PTR_NAME_CNT += CurPtr;
	
	if (SmpsDrvType == DRVTYPE_Z80_T1)
	{
		for (CurPtr = 0x00; CurPtr < 0x02; CurPtr ++)
		{
			PTR_NAMES[PTR_NAME_CNT + CurPtr] = PTR_NAMES_Z80_T1[CurPtr];
			DumpParts[PTR_NAME_CNT + CurPtr].Type = DPTYPE_DAC;
			DumpParts[PTR_NAME_CNT + CurPtr].Size = CurPtr;
		}
		PTR_NAME_CNT += CurPtr;
	}
	else if (SmpsDrvType == DRVTYPE_Z80_T2)
	{
		if (SmpsDrv_SubType == 0x01 || SmpsDrv_SubType == 0x02)
		{
			PTR_NAMES[0x01] = "GblInsLib";	// actually still SpcSFXPtrs, but it also points to the Ins. Lib.
		}
		if (SmpsDrv_SubType == 0x02)
		{
			PTR_NAME_CNT --;	// no Song Limit for S3K/Varion
			PTR_NAMES[PTR_NAME_CNT + 0x00] = "PCMPtrs";
			PTR_NAMES[PTR_NAME_CNT + 0x01] = "PCMSizes";
			PTR_NAMES[PTR_NAME_CNT + 0x02] = "DPCMBanks";
			PTR_NAMES[PTR_NAME_CNT + 0x03] = "MusicBanks";
			PTR_NAMES[PTR_NAME_CNT + 0x04] = "SFXBanks";
			PTR_NAMES[PTR_NAME_CNT + 0x05] = "PCMBanks";
			PTR_NAMES[PTR_NAME_CNT + 0x06] = "PCMFreqs";
			for (CurPtr = 0x00; CurPtr < 0x07; CurPtr ++)
				DumpParts[PTR_NAME_CNT + CurPtr].Type = 0x00;
			PTR_NAME_CNT += 0x07;
		}
	}
	
	// The ReadPtrTable routine used for SMPS Z80 Type 2 detection is always placed
	// after the routine that loads the GeneralPtrList offset into HL.
	
	if (! ForceGenPtrList)
	{
	
	// SMPS Z80 Type 1:							SMPS Z80 Type 2:
	//		GetListOfs:
	// 0020	2A 02 1C	LD		HL, (1C02h)		0008	2A 02 1C	LD		HL, (1C02h)
	// 0023	06 00		LD		B, 00h			000B	06 00		LD		B, 00h
	// 0025	C3 49 05	JP		GetPtrListOfs	000D	09			ADD		HL, BC
	//											....
	//		ReadPtrTable:
	// 0028	4F			LD		C, A			0028	4F			LD		C, A
	// 0029	06 00		LD		B, 00h			0029	06 00		LD		B, 00h
	// 002B	09			ADD		HL, BC			002B	09			ADD		HL, BC
	// 002C	09			ADD		HL, BC			002C	09			ADD		HL, BC
	GenPtrListPtr = 0x0000;
	MaxPos = ScanForData(RAMSize, RAMData, 0x05, MAGIC_READ_PTR_TBL, 0x00);
	if (MaxPos && MaxPos < 0x10)
	{
		// This game uses hardcoded offsets.
		GenPtrListPtr = 0x0000;
	}
	else if (MaxPos >= 0x18)
	{
		// Search in the area [MaxPos-20h .. MaxPos]
		if (MaxPos < 0x20)
			CurPos = 0x00;
		else
			CurPos = MaxPos - 0x20;
		CurPos = ScanForData_WC(RAMSize, RAMData, 0x05, MAGIC_LD_HL__B_0, CurPos);
		if (CurPos && CurPos < MaxPos)
			GenPtrListPtr = ReadLE16(&RAMData[CurPos + 0x01]);
	}
	if (! GenPtrListPtr)
	{
		// Okay, let's try to dumb way. In most cases, the Pointer List Offset is stored at 1C02,
		// so search for "LD HL, (1C02h)".
		CurPos = ScanForData_WC(RAMSize, RAMData, 0x03, MAGIC_LD_HL_1C02, CurPos);
		if (CurPos && CurPos < MaxPos)
			GenPtrListPtr = ReadLE16(&RAMData[CurPos + 0x01]);
	}
	
	// "full" RAM dumps might be incorrect??
	if ((RAMSize >= 0x1C08 && RAMSize <= 0x1C40) || RAMSize == 0x2000)
	{
		memcpy(SmpsCfgData, &RAMData[0x1C00], 0x08);
	}
	else
	{
		memset(SmpsCfgData, 0x00, 0x08);
		CurPos = FindBytesWrittenToOfs(&SmpsCfgData[0x00], 0xA01C00, 0x08);
		if (! CurPos)
			CurPos = FindBytesWrittenToOfs(&SmpsCfgData[0x02], 0xA01C02, 0x06);
	}
	Z80Bank = ReadBE16(&SmpsCfgData[0x00]) << 8;
	if (! Z80Bank && SmpsDrvType == DRVTYPE_Z80_T2)
		Z80Bank = ReadBE16(&SmpsCfgData[0x06]) << 8;	// SMPS Z80 Type 2 often stores the Data Bank at 1C06/07.
	
	// Note: Right now GenPtrListPtr has a *pointer* to the actual list, so let's resolve that.
	GeneralPtrList = 0x0000;
	if ((GenPtrListPtr >= 0x1C00 && GenPtrListPtr < 0x1C08) &&
		(RAMSize < 0x1C00 || RAMSize > 0x1C40))
	{
		GeneralPtrList = ReadLE16(&SmpsCfgData[GenPtrListPtr & 0x07]);
	}
	else if (GenPtrListPtr && GenPtrListPtr < RAMSize)
	{
		GeneralPtrList = ReadLE16(&RAMData[GenPtrListPtr]);
	}
	if (GeneralPtrList >= 0xFFFC)
		GeneralPtrList = 0x0000;	// catch offsets that are obviously wrong
	
	}
	else //if (ForceGenPtrList)
	{
		if (ForceGenPtrList < RAMSize)
		{
			GeneralPtrList = ForceGenPtrList & 0x7FFF;
			Z80Bank = 0x0000;
		}
		else
		{
			GeneralPtrList = 0x8000 | (ForceGenPtrList & 0x7FFF);
			Z80Bank = ForceGenPtrList & ~0x7FFF;
		}
	}
	
	printf("General Pointer List Offset: ");
	if (! GeneralPtrList)
	{
		printf("not found.");
		if (GenPtrListPtr)
			printf(" (reading from offset %04X)", GenPtrListPtr);
		printf("\n");
		PtrCount = 0x00;
	}
	else
	{
		PrintZ80Ptr(Z80PtrStr, GeneralPtrList, Z80Bank);
		printf("%s\n", Z80PtrStr);
		
		ReadPtrList(MODE_Z80, 0x20, &PtrCount, PtrList, GeneralPtrList, Z80Bank);
	}
	
	PrintPtrList(MODE_Z80, PTR_NAME_CNT, PTR_NAMES, Z80Bank, PtrCount, PtrList);
	
	
	
	// --- Additional Information ---
	// Now let's get some additional information.
	
	// Search the PlaySoundID routine.
	CurPos = ScanForData_WC(RAMSize, RAMData, 0x0B, MAGIC_PLAYSND_C, 0x00);
	if (! CurPos)
		CurPos = ScanForData_WC(RAMSize, RAMData, 0x0B, MAGIC_PLAYSND_NC, 0x00);
	if (CurPos)
	{
		while(1)
		{
			CurPos -= 0x03;
			if (RAMData[CurPos] == 0x3A)	// 3A xx xx - LD A, (nnnn)
				break;
			if (RAMData[CurPos] != 0xCB && (RAMData[CurPos] & ~0x38) != 0xC2)
				break;
			CurPos -= 0x02;
		}
		MaxPos = ReadLE16(&RAMData[CurPos + 0x01]);
		printf("PlaySound routine: %04X, reading from %04X\n", CurPos, MaxPos);
		// TODO: ParsePlaySound_Z80(CurPos)
		// Notes:
		//	PlayMusic: does "SUB 81h; RET M" or "DEC A; RET M"
		//	PlaySFX: does "SUB A0h; EX AF, AF'; XOR A/LD A, 80h" (bank changes are commonly injected somewhere)
		//	PlaySnd_Command: does "SUB E0h; LD HL, CmdPtrTable"
	}
	
	return;
}

static void InsertPtrListItem(UINT8* PTR_NAME_CNT, const char** PTR_NAMES, DUMP_PARTS* DumpParts,
								UINT8 PosToInsert)
{
	UINT8 CurPtr;
	
	for (CurPtr = *PTR_NAME_CNT; CurPtr > PosToInsert; CurPtr --)
	{
		PTR_NAMES[CurPtr] = PTR_NAMES[CurPtr - 1];
		DumpParts[CurPtr] = DumpParts[CurPtr - 1];
	}
	(*PTR_NAME_CNT) ++;
	
	return;
}

void PrintOffsets_68k(UINT32 ForceGenPtrList)
{
	const UINT8 MAGIC_68K_PLAYMUSIC[0x08] =
	{	0x04, 0x07, 0x00, 0x81, 0xE5, 0x4F, 0x28, 0x74};
	const UINT8 MAGIC_68K_VOLENV[0x0B] =
	{	0x1C, 0x2D, 0x00, 0x09, 0x70, 0x00, 0x10, 0x2D, 0x00, 0x0B, 0x67};
	UINT8 MUSPTR_ID;
	UINT8 VOLENV_ID;
	UINT8 PTR_NAME_CNT;
	const char* PTR_NAMES[0x20];
	UINT32 CurPos;
	UINT32 TempPos;
	UINT16 CurInst;
	UINT8 DataBuf[6];
	UINT8 PtrCount;
	UINT32 PtrList[0x20];
	UINT8 CurPtr;
	
	PTR_NAME_CNT = 0x00;
	for (CurPtr = 0x00; CurPtr < 0x07; CurPtr ++)
	{
		PTR_NAMES[PTR_NAME_CNT + CurPtr] = PTR_NAMES_GEN[CurPtr];
		DumpParts[PTR_NAME_CNT + CurPtr].Type = DPARTS_GEN[CurPtr];
	}
	PTR_NAME_CNT += CurPtr;
	for (CurPtr = 0x00; CurPtr < 0x01; CurPtr ++)
	{
		PTR_NAMES[PTR_NAME_CNT + CurPtr] = PTR_NAMES_68K[CurPtr];
		DumpParts[PTR_NAME_CNT + CurPtr].Type = 0x00;
	}
	PTR_NAME_CNT += CurPtr;
	
	MUSPTR_ID = 0x02;
	VOLENV_ID = 0x05;
	DumpParts[MUSPTR_ID].IDBase = 0x81 ^ 0x80;
	if (SmpsDrvType == DRVTYPE_68K_T1B && SmpsDrv_SubType)
	{
		if (SmpsDrv_SubType >= 0x01 && SmpsDrv_SubType <= 0x04)
		{
			PTR_NAMES[0x04] = "SpeedUpTempo";	// replaces ModEnvPtr
			DumpParts[0x04].Type = 0x00;
			PTR_NAME_CNT = 0x06;	// VolEnvPtr is the last pointer
		}
		if (SmpsDrv_SubType == 0x02 || SmpsDrv_SubType == 0x04)
		{
			// additional SFX pointer for E0-F8
			// move all strings from 0x04 on one slot forward
			CurPtr = 0x04;
			InsertPtrListItem(&PTR_NAME_CNT, PTR_NAMES, DumpParts, CurPtr);
			PTR_NAMES[CurPtr] = "ExtraSFXPtrs";
			DumpParts[CurPtr].Type = DPTYPE_SFX;
			DumpParts[CurPtr].IDBase = 0xE0 ^ 0x80;
			VOLENV_ID ++;
		}
		if (SmpsDrv_SubType == 0x03 || SmpsDrv_SubType == 0x04)
		{
			for (PtrCount = 0x00; PtrCount < SmpsDrv_Ofs_Count; PtrCount ++)
			{
				CurPtr = MUSPTR_ID + 0x01 + PtrCount;
				InsertPtrListItem(&PTR_NAME_CNT, PTR_NAMES, DumpParts, CurPtr);
				PTR_NAMES[CurPtr] = "ExtraMusPtrs";
				DumpParts[CurPtr].Type = DPTYPE_MUSIC;
				DumpParts[CurPtr].IDBase = SmpsDrv_Offsets[PtrCount] ^ 0x80;
				VOLENV_ID ++;
			}
		}
		/*if (SmpsDrv_SubType == 0x03)
		{
			// move all strings from (MUSPTR_ID+1) on one slot forward
			CurPtr = MUSPTR_ID + 0x01;
			InsertPtrListItem(PTR_NAME_CNT, PTR_NAMES, DumpParts, CurPtr);
			PTR_NAMES[CurPtr] = "ExtraMusPtrs";
			DumpParts[CurPtr].Type = DPTYPE_MUSIC;
			DumpParts[CurPtr].IDBase = 0xE5 ^ 0x80;
			VOLENV_ID ++;
		}
		if (SmpsDrv_SubType == 0x03 || SmpsDrv_SubType == 0x04)
		{
			// move all strings from (MUSPTR_ID+1) on one slot forward
			CurPtr = MUSPTR_ID + 0x01;
			InsertPtrListItem(PTR_NAME_CNT, PTR_NAMES, DumpParts, CurPtr);
			PTR_NAMES[CurPtr] = "ExtraMusPtrs";
			DumpParts[CurPtr].Type = DPTYPE_MUSIC;
			DumpParts[CurPtr].IDBase = 0x00 ^ 0x80;
			VOLENV_ID ++;
		}*/
	}
	else if (SmpsDrvType == DRVTYPE_68K_T2 && SmpsDrv_SubType)
	{
		if (SmpsDrv_SubType == 0x01)	// Ristar
		{
			PTR_NAMES[PTR_NAME_CNT + 0x00] = "LoadZ80Driver";
			PTR_NAMES[PTR_NAME_CNT + 0x01] = "SoundRAM";
			PTR_NAMES[PTR_NAME_CNT + 0x02] = "DACDrum_MasterList";
			PTR_NAMES[PTR_NAME_CNT + 0x03] = "DACSFX_MasterList";
			for (CurPtr = 0x00; CurPtr < 0x04; CurPtr ++)
				DumpParts[PTR_NAME_CNT + CurPtr].Type = 0x00;
			PTR_NAME_CNT += 0x04;
		}
	}
	else if (SmpsDrvType == DRVTYPE_68K_PICO)
	{
		for (CurPtr = 0x00; CurPtr < 0x04; CurPtr ++)
		{
			PTR_NAMES[PTR_NAME_CNT + CurPtr] = PTR_NAMES_68K_PICO[CurPtr];
			DumpParts[PTR_NAME_CNT + CurPtr].Type = 0x00;
		}
		PTR_NAME_CNT += CurPtr;
	}
	
	if (ForceGenPtrList)
	{
		// user specified Pointer List offset
		GeneralPtrList = ForceGenPtrList;
	}
	else if (SmpsDrvType == DRVTYPE_68K_T1A)
	{
		// already found when detecting the driver version
	}
	else //if (SmpsDrvType == DRVTYPE_68K_T1B || SmpsDrvType == DRVTYPE_68K_T2)
	{
		// 0766FA	2879 0007 6008	MOVEA.L	$076008.l, A4	; MusListPtr
		// 076700	0407 0081		SUBI.B	#$81, D7
		// 076704	E54F			LSL.W	#2, D7
		// 076706	2874 7000		MOVEA.L	(A4,D7.w), A4
		CurPos = ScanForData2(ROMLength, ROMData, 0x08, MAGIC_68K_PLAYMUSIC, 0x00);
		if (CurPos)
		{
			FixMarsPointer(&CurPos);
			TempPos = 0x00;
			if (ReadBE16(&ROMData[CurPos - 0x06]) == 0x2879)
			{
				// MOVEA.L (ListPtr), A4
				TempPos = ReadBE32(&ROMData[CurPos - 0x04]);
			}
			else if (ReadBE16(&ROMData[CurPos - 0x04]) == 0x49FA)
			{
				// LEA	List(PC), A4
				TempPos = ReadLEA(ROMData, CurPos - 0x04);
				CurPos = ReadBE32(&ROMData[TempPos]);
				if (CurPos & 0xC00000)
					TempPos = (CurPos & 0xF80000) | (TempPos & 0x7FFFF);	// turn into a proper 32x pointer
				WriteBE32(&DataBuf[0x00], TempPos);
				DataBuf[0x04] = DataBuf[0x00];
				TempPos = ScanForData2(ROMLength, ROMData, 0x05, DataBuf, 0x00);
			}
			if (TempPos)
				GeneralPtrList = TempPos - MUSPTR_ID * 0x04;	// MusListPtr is the 3td entry in the list.
		}
		if (! GeneralPtrList)
		{
			// That didn't work, so try to get the Volume Envelope pointers.
			// 076E5E	1C2D 0009			MOVE.B	$09(A5), D6
			// 076E62	7000				MOVEQ	#0, D0
			// 076E64	102D 000B			MOVE.B	$0B(A5), D0
			// 076E68	673C				BEQ		$076EA6
			// 076E6A	2079 0007 6014		MOVEA.L	$076014, A0
			// alternatively:
			//			41FA xxxx			LEA		xxxx(PC), A0
			CurPos = ScanForData2(ROMLength, ROMData, 0x0B, MAGIC_68K_VOLENV, 0x00);
			if (CurPos)
			{
				CurPos += 0x0C;
				if (ROMData[CurPos - 0x01] == 0x00)	// was this a BEQ.W?
					CurPos += 0x02;	// yes - skip another 2 bytes
				CurInst = ReadBE16(&ROMData[CurPos]);
				TempPos = 0x00;
				if (CurInst == 0x2079)
				{
					// MOVEA.L (ListPtr), A0
					TempPos = ReadBE32(&ROMData[CurPos + 0x02]);
				}
				else if ((CurInst & 0xF1F8) == 0x41F8)
				{
					// LEA	List(PC), A0
					TempPos = ReadLEA(ROMData, CurPos);
					CurPos = ReadBE32(&ROMData[TempPos]);
					if (CurPos & 0xC00000)
						TempPos = (CurPos & 0xF80000) | (TempPos & 0x7FFFF);	// turn into a proper 32x pointer
					WriteBE32(&DataBuf[0x00], TempPos);
					DataBuf[0x04] = DataBuf[0x00];
					TempPos = ScanForData2(ROMLength, ROMData, 0x05, DataBuf, 0x00);
				}
				if (TempPos)
					GeneralPtrList = TempPos - VOLENV_ID * 0x04;	// VolEnvPtr is the 6th entry in the list.
			}
		}
	}
	
	printf("General Pointer List: ");
	if (! GeneralPtrList)
	{
		printf("not found.\n");
		PtrCount = 0x00;
	}
	else
	{
		if (! ForceGenPtrList && SmpsDrvType != DRVTYPE_68K_T1A &&	// 68k Type 1a has ALWAYS the correct offset.
			GeneralPtrList < ROMLength)
		{
			CurPos = ReadBE32(&ROMData[GeneralPtrList]);
			if (! CurPos || (CurPos & 0xFF000000))
				GeneralPtrList = TempPos;
			/*while(GeneralPtrList < ROMLength)
			{
				CurPos = ReadBE32(&ROMData[GeneralPtrList]);
				if (! (CurPos & 0xFF000000))
					break;
				GeneralPtrList += 0x04;	// offset correction, in case it found an early entry
			}*/
			while(GeneralPtrList && GeneralPtrList < ROMLength)
			{
				CurPos = ReadBE32(&ROMData[GeneralPtrList - 0x04]);
				if (! CurPos || (CurPos & 0xFF000000))
					break;
				GeneralPtrList -= 0x04;	// offset correction, in case it found a LATE entry
			}
		}
		printf("%06X\n", GeneralPtrList);
		
		ReadPtrList(MODE_68K, 0x20, &PtrCount, PtrList, GeneralPtrList, 0x00);
	}
	
	PrintPtrList(MODE_68K, PTR_NAME_CNT, PTR_NAMES, 0x00, PtrCount, PtrList);
	
	return;
}

static void ReadPtrList(UINT8 Mode, UINT8 MaxPtrCount, UINT8* RetPtrCount, UINT32* PtrList,
						UINT32 PtrListOfs, UINT32 Z80Bank)
{
	UINT32 MaxPos;
	UINT32 CurPos;
	UINT32 RealPos;
	UINT32 CurPtr;
	UINT32 PtrSize;
	UINT8 RAMMode;
	
	RAMMode = 0x00;
	CurPos = PtrListOfs;
	if (Mode == MODE_68K)
	{
		PtrSize = 0x04;
		MaxPos = ROMLength;
		RealPos = CurPos;
	}
	else //if (Mode == MODE_Z80)
	{
		PtrSize = 0x02;
		if (PtrListOfs < 0x2000)
		{
			RAMMode = 0x01;	// in Z80 RAM
			MaxPos = 0x2000;	// end of Z80 RAM
			RealPos = CurPos;
		}
		else
		{
			MaxPos = 0x10000;	// end of Z80 ROM bank window
			RealPos = (Z80Bank & 0xFF8000) | (CurPos & 0x7FFF);
			if (Z80Bank >= ROMLength)
				MaxPos = 0x00;	// prevent it from reading anything
		}
	}
	
	for (CurPtr = 0x00; CurPtr < MaxPtrCount; CurPtr ++, CurPos += PtrSize, RealPos += PtrSize)
	{
		if (CurPos >= MaxPos)
			break;
		
		if (Mode == MODE_68K)
		{
			PtrList[CurPtr] = ReadBE32(&ROMData[RealPos]);
		}
		else //if (Mode == MODE_Z80)
		{
			if (RAMMode)
				PtrList[CurPtr] = ReadLE16(&RAMData[RealPos]);
			else if (Z80Bank < ROMLength)
				PtrList[CurPtr] = ReadLE16(&ROMData[RealPos]);
		}
		FixMarsPointer(&PtrList[CurPtr]);
		
		if (PtrList[CurPtr] > GeneralPtrList && PtrList[CurPtr] < MaxPos)
			MaxPos = PtrList[CurPtr];
	}
	*RetPtrCount = CurPtr;
	
	return;
}

static void PrintPtrList(UINT8 Mode, UINT8 PtrNameCnt, const char** PtrNames,
						UINT32 Z80Bank, UINT8 PtrCount, const UINT32* PtrList)
{
	char PtrStr[0x20];
	UINT32 CurPtr;
	UINT32 NextOfs;
	UINT32 ListSize;
	
	for (CurPtr = 0x00; CurPtr < PtrCount; CurPtr ++)
	{
		ListSize = 0x00;
		DumpParts[CurPtr].Offset = PtrList[CurPtr];
		NextOfs = GetNextAddr(PtrCount, PtrList, PtrList[CurPtr]);
		if (Mode == MODE_68K)
		{
			if (NextOfs)
				ListSize = NextOfs - PtrList[CurPtr];
			
			if (CurPtr == 0x06 && PtrList[CurPtr] < 0xF000)
				sprintf(PtrStr, "%6X", PtrList[CurPtr]);	// Song Limit stuff
			else
				sprintf(PtrStr, "%06X", PtrList[CurPtr]);
		}
		else //if (Mode == MODE_Z80)
		{
			if (NextOfs && ! ((PtrList[CurPtr] ^ NextOfs) & 0x8000))	// PtrList and NextOfs must be in the same bank
				ListSize = NextOfs - PtrList[CurPtr];
			
			if (CurPtr == 0x06 && PtrList[CurPtr] < 0x00F0)
				sprintf(PtrStr, "%4X", PtrList[CurPtr]);	// Song Limit stuff
			else
				PrintZ80Ptr(PtrStr, (UINT16)PtrList[CurPtr], Z80Bank);
		}
		if (DumpParts[CurPtr].Type != DPTYPE_DAC)
			DumpParts[CurPtr].Size = ListSize;
		
		if (CurPtr < PtrNameCnt)
			printf("\t%s:\t%s", PtrNames[CurPtr], PtrStr);
		else
			printf("\tPointer %02X:\t%s", CurPtr, PtrStr);
		if (DumpParts[CurPtr].Type == DPTYPE_MUSIC)
			printf(" (index %02X)", DumpParts[CurPtr].IDBase ^ 0x80);
		printf("\n");
	}
	DumpPartCnt = PtrCount;
	
	return;
}

static UINT32 GetNextAddr(UINT16 PtrCnt, const UINT32* PtrList, UINT32 MinAddr)
{
	UINT32 RetAddr;
	UINT32 CurPtr;
	
	RetAddr = 0xFFFFFFFF;
	for (CurPtr = 0x00; CurPtr < PtrCnt; CurPtr ++)
	{
		if (PtrList[CurPtr] > MinAddr && PtrList[CurPtr] < RetAddr)
			RetAddr = PtrList[CurPtr];
	}
	
	return RetAddr;
}
