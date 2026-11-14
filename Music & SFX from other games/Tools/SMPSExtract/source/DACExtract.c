// SMPS DAC Sound Extractor
// ------------------------
// Written by Valley Bell

#define _CRT_SECURE_NO_WARNINGS
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
//#include <malloc.h>
#include <memory.h>
#include <string.h>
#include <direct.h>	// for mkdir()

#include "stdtype.h"

#include "ReadFuncs.h"
#include "DetectSearch.h"
#include "DACExtract.h"

typedef struct dac_list
{
	UINT32 Pos;
	UINT32 Len;
	UINT32 PwmPitch;
	UINT8 BankID;
	UINT8 SndID;
	UINT8 Pitch;
	UINT8 Pan;
	UINT8 Unknown;
	UINT8 Flags;
	// Flags:
	//	bit 0 - Compressed
	//	bit 4 - RAM (on) / ROM (off)
	//	bit 7 - skip entry
	UINT16 Z80WarnAddr;
	const char* CommentStr;
	const char* CommentStrB;	// comment string, written before section start
} DAC_LIST;
typedef struct dac_library
{
	const char* RateStr;
	
	// cycle based values
	UINT16 BaseCycles;	// cycles taken in every loop that processes a sample
	UINT16 LoopCycles;	// cycles for per delay loop
	UINT16 LoopSamples;	// samples processed per loop
	
	// Base/Divider based values
	UINT32 BaseRate;
	UINT16 RateDiv;		// 1.00 fixed point
	
	UINT8 Flags;
	// Flags:
	//	bit 0 - Compressed
	//	bit 1 - 68k Pointers (enables 32x checks)
	//	bit 4 - use NumBank for file names
	//	bit 6 - NEC ADPCM values
	//	bit 7 - use 4-digit Rate
	UINT8 SndCnt;
	DAC_LIST Snds[0xFF];
} DAC_LIB;


static const UINT8 MAGIC_BYTES_S1[0x04] = {0x00, 0x00, 0xFD, 0x21};
static const UINT8 MAGIC_BYTES_PS2[0x06] = {0x3A, 0xFF, 0x1F, 0xCB, 0x7F, 0xCA};
static const UINT8 MAGIC_BYTES_PS2_DPCM[0x04] = {0x08, 0x3E, 0x80, 0x08};
//static const UINT8 MAGIC_BYTES_Z80_1C00[0x04] = {0x00, 0xA0, 0x1C, 0x00};	// 68k space: Z80 RAM 0x1C00 (0xA01C00)
static const UINT8 MAGIC_BYTES_JMAN_150[0x04] = {0x00, 0xA0, 0x01, 0x50};	// 68k space: Z80 RAM 0x0150 (0xA00150)
static const UINT8 MAGIC_BYTES_JMAN_200[0x04] = {0x00, 0xA0, 0x02, 0x00};	// 68k space: Z80 RAM 0x0200 (0xA00200)
static const UINT8 MAGIC_BYTES_HFRONT_1[0x04] = {0xCB, 0xFE, 0xD9, 0x26};
static const UINT8 MAGIC_BYTES_HFRONT_2[0x02] = {0xF1, 0x21};	// POP	AF;	LD	HL, addr
static const UINT8 MAGIC_BYTES_VTRACE[0x04] = {0x10, 0xFC, 0xC9, 0x21};
static const UINT8 MAGIC_BYTES_VTRACE_DX[0x04] = {0x06, 0x00, 0x09, 0x09};
static const UINT8 MAGIC_BYTES_SM_GP[0x04] = {0xB7, 0x1F, 0x47, 0x21};
static const UINT8 MAGIC_BYTES_RAHERO[0x06] = {0x17, 0x40, 0x00, 0x13, 0x41, 0xF9};
static const UINT8 MAGIC_BYTES_RAHERO_2[0x04] = {0x5F, 0x16, 0x00, 0x21};
static const UINT8 MAGIC_BYTES_MEGAPCM[0x02] = {0xDD, 0x21};	// LD	IX, DAC_Table
static const UINT8 MAGIC_BYTES_DHEAD_MUS[0x06] = {0x48, 0x80, 0xE7, 0x40, 0x47, 0xFB};	// EXT.W D0;	ASL.W	#3, D0;	LEA
static const UINT8 MAGIC_BYTES_DHEAD_SFX[0x06] = {0x48, 0x87, 0xE7, 0x47, 0x41, 0xF9};	// EXT.W D7;	ASL.W	#3, D7;	LEA
//static const UINT8 MAGIC_BYTES_DHEAD_SFX_J[0x06] = {0x48, 0x87, 0xE7, 0x47, 0x47, 0xFB};	// EXT.W D7;	ASL.W	#3, D7;	LEA(PC)
static const UINT8 MAGIC_BYTES_YYHMT_SFX[0x06] = {0x00, 0xFF, 0xE7, 0x4F, 0x41, 0xF9};	// AND.W #$FF, D7;	LSL.W	#3, D7;	LEA
static const UINT8 MAGIC_BYTES_32X_PWM[0x08] = {0x30, 0x1C, 0x40, 0x21, 0x00, 0x0B, 0x35, 0x0C};	// works with Chaotix, not with Tempo
static const UINT8 MAGIC_BYTES_S2[0x05] = {0x01, 0x00, 0x01, 0xFB, 0xC9};
static const UINT8 MAGIC_BYTES_VFIGHT2[0x06] = {0x3D, 0x4F, 0x06, 0x00, 0x09, 0x09};
static const UINT8 MAGIC_BYTES_SEGAPICO_A[0x08] = {0xD1, 0xC0, 0x39, 0x58, 0x00, 0x02, 0x20, 0x18};
static const UINT8 MAGIC_BYTES_SEGAPICO_B[0x0A] = {0xD1, 0xC0, 0x19, 0x58, 0x00, 0x02, 0x52, 0x88, 0x20, 0x18};
static const UINT32 MB_SPICO_LEN[2] = {sizeof(MAGIC_BYTES_SEGAPICO_A), sizeof(MAGIC_BYTES_SEGAPICO_B)};
static const UINT8* MB_SPICO_PTR[2] = {MAGIC_BYTES_SEGAPICO_A, MAGIC_BYTES_SEGAPICO_B};
static const UINT8 MAGIC_BYTES_WCTENNIS_1[0x06] = {0x4F, 0x06, 0x00, 0x09, 0x09, 0x09};	// LD C, A; LD B, 0; 3xADD HL, BC
static const UINT8 MAGIC_BYTES_WCTENNIS_2[0x08] = {0x87, 0x4F, 0x87, 0x81, 0x4F, 0x06, 0x00, 0x09};
static const UINT8 MAGIC_BYTES_GAMTEC_1[0x07] = {0x07, 0x32, 0x00, 0x60, 0x06, 0x08, 0x3E};
static const UINT8 MAGIC_BYTES_GAMTEC_2[0x09] = {0x4F, 0x06, 0x00, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09};
static const UINT8 CODE_RTS[0x02] = {0x4E, 0x75};
static const UINT8 CODE_LEA_A0[0x02] = {0x41, 0xF9};
static const UINT8 CODE_LEA_A1[0x02] = {0x43, 0xF9};
static const UINT8 CODE_MOVEL_D0[0x02] = {0x20, 0x3C};
static const UINT8 CODE_MOVEB_A0p[0x02] = {0x10, 0xFC};
static const UINT8 CODE_MOVEB_addr[0x02] = {0x13, 0xFC};
static const UINT8 CODE_BSR_W[0x02] = {0x60, 0x00};
static const UINT8 CODE_SET_LD_HL[0x03] = {0xCB, 0xFE, 0x21};	// SET	7, (HL);	LD	HL, addr
static const UINT8 CODE_LD_1FFD_LD_DE[0x04] = {0x32, 0xFD, 0x1F, 0x11};	// LD	(1FFDh); A;	LD	DE, addr
static const UINT8 CODE_LD_HL_6000[0x03] = {0x21, 0x00, 0x60};	// LD	HL, 6000h (Z80 Bank Switch offset)
static const UINT8 CODE_LD_CA_B0_HL[0x04] = {0x4F, 0x06, 0x00, 0x21};	// LD	C, A;	LD	B, 0;	LD HL, addr
static const UINT8 CODE_LD_IY[0x03] = {0x3D, 0xFD, 0x21};
static const UINT8 CODE_LD_1C3C_LD_HL[0x04] = {0x32, 0x3C, 0x1C, 0x21};	// LD	(1C3Ch), A;	LD	HL, addr



extern UINT32 ROMLength;
extern UINT8* ROMData;
extern UINT8 RAMMode;
extern UINT16 RAMSize;
extern UINT8* RAMData;

extern UINT8 MarsMode;
extern UINT32 MarsBase;

extern UINT8 SONG_BASE;
extern UINT8 SONG_COUNT;
extern UINT8 ReadOnlyMode;

extern char DAC_NAMEBASE[0x40];

static UINT32 DacTblBase;
static UINT32 BnkTblBase;
static UINT32 BnkBase;

UINT8 SearchDACTable(UINT8 Mode, UINT32 PtrList)
{
	UINT8 CurSnd;
	UINT32 ROMPos;
	UINT32 RAMPos;
	const UINT8* TempPnt;
	
	// In many DAC drivers the address of the DAC table is loaded into the IY reg with this code:
	//	LD	DE, 0000h	(11 00 00)
	//	LD	IY, xxxxh	(FD 21 xx xx)
	UINT8 CODE_BUF[0x08];
	
#define RAM_CHECK()	if (! RAMSize || RAMData == NULL)	return 0xF0;
	CurSnd = 0x00;
	switch(Mode)
	{
	case 0x00:	// Sonic 1 | DAC table stored in RAM
	case 0x06:	// Generic SMPS 68k [Drums] | DAC table stored in RAM
	case 0x10:	// Streets of Rage / A Ressha de Gyoukou MD | DAC table stored in RAM
	case 0x22:	// Generic SMPS 68k/Pulstar [Drums] | DAC table stored in RAM
		// Output: DacTblBase, (BnkBase)
		RAM_CHECK();
		
		RAMPos = ScanForData(RAMSize - 0x02, RAMData, 0x04, MAGIC_BYTES_S1, 0x00);
		if (! RAMPos)
			break;	// we didn't found anything
		DacTblBase = ReadLE16(&RAMData[RAMPos + 0x04]);
		CurSnd = 0x02;
		
		if (Mode == 0x10)
		{
			// Streets of Rage's bank base offset is written to the
			// same offset as for most other SMPS 68k DAC drivers.
			ROMPos = FindBytesWrittenToOfs(CODE_BUF, 0xA01FF8, 0x04);
			if (ROMPos >= 0x04)
			{
				BnkTblBase  = (ReadBE16(&CODE_BUF[0x02]) & 0xFF80) << 8;	// Bank Bits
				BnkTblBase |= (ReadLE16(&CODE_BUF[0x00]) & 0x7FFF) << 0;	// Pointer List
				CurSnd = 0x03;
			}
		}
		else if (Mode == 0x22)
		{
			// Magical Taruruuto-Kun and Pulseman use a seperate bank array
			//	Magical Taruruuto-Kun:
			//		array at 002A-006E
			//		80 - RAM
			//		00..02 - ROM Bank 050000..060000
			//	Pulseman:
			//		array at 002B-009F
			//		80 - RAM
			//		00..13 - ROM Bank 160000..1F8000
			
			//	LD		C, A		4F
			//	LD		B, 00h		06 00
			//	LD		HL, xxxxh	21 xx xx
			//	ADD		HL, BC		09
			BnkTblBase = 0x00;
			for (RAMPos = 0x00; RAMPos < RAMSize - 0x08; RAMPos ++)
			{
				if (! memcmp(&RAMData[RAMPos], CODE_LD_CA_B0_HL, 0x04))
				{
					BnkTblBase = ReadLE16(&RAMData[RAMPos + 0x04]);
					printf("Bank List Offset: %04X\n", BnkTblBase);
					break;
				}
			}
			
			// Magical Taruruuto-Kun's bank base (currently hardcoded)
			BnkBase = 0x050000;
			
			// Pulseman's bank base (currently hardcoded)
			BnkBase = 0x160000;
		}
		if (PtrList)
			BnkBase = PtrList;
		
		/*if (CurSnd && Mode == 0x06)
		{
			// Try to load Table Offset. (bank relative)
			GenerateCode(CODE_BUF, CODE_LEA_A0, 0xA01FF8, NULL);
			
			BnkBase = 0x50000;	// Magical Taruruuto-Kun's bank base
			// It will read table offset 8000 anyway.
			for (ROMPos = 0x100; ROMPos < ROMLength - 0x20; ROMPos += 0x02)
			{
				if (! memcmp(&ROMData[ROMPos], CODE_BUF + 0x02, 0x04))
				{
					printf("Table Loader found at offset: %06X\n", ROMPos - 0x02);
					ROMPos += 0x04;
					
					// Magical Taruruuto-Kun [load Bank Offset]
					//	LEA		$A01FF8, A6
					//	MOVE.B	#xx, (A6)+
					//	MOVE.B	#xx, (A6)+
					SndAddr  = (ROMData[ROMPos + 0x07] & 0x7F) <<  8;	// Pointer List MSB
					SndAddr |=  ROMData[ROMPos + 0x03]         <<  0;	// Pointer List LSB
					BnkBase &= 0xFF8000;
					BnkBase |= SndAddr;
					break;
				}
			}
			
			// Magical Taruruuto-Kun uses a seperate bank array at 002A-006E:
			// 80 - RAM
			// 00..02 - ROM Bank 050000..060000
			
			//	LD		C, A		4F
			//	LD		B, 00h		06 00
			//	LD		HL, xxxxh	21 xx xx
			//	ADD		HL, BC		09
			BnkTblBase = 0x00;
			for (RAMPos = 0x00; RAMPos < RAMSize - 0x08; RAMPos ++)
			{
				if (! memcmp(&RAMData[RAMPos], CODE_LD_CA_B0_HL, 0x04))
				{
					BnkTblBase = ReadLE16(&RAMData[RAMPos + 0x04]);
					printf("Bank List Offset: %04X\n", BnkTblBase);
					break;
				}
			}
			
			if (PtrList)
				BnkBase = PtrList;
		}*/
		break;
	case 0x03:	// Dynamite Headdy | 68k processes DAC table
		// Output: DacTblBase
		
		// Search for [drums]:
		//	EXT.W	D0			[48 80]
		//	ASL.W	#3, D0		[E7 40]
		//	LEA	($7A,PC,D0), A3	[47 FB 00 7A]
		//	MOVE	SR, -(A7)	[40 E7]
		
		// Search for [SFX]: (not Yuu Yuu Hakusho - Makyou Toitsusen)
		//	EXT.W	D7			[4887]
		//	ASL.W	#3, D7		[E747]
		//	LEA		$addr.l, A0	[41F9 xxxx xxxx]
		//	LEA		(A0,D7), A0	[41F0 7000]
		
		// Search for Yuu Yuu Hakusho - Makyou Toitsusen SFX:
		// Because of the huge number of DAC sound effects (0x86!),
		// the code is slightly different.
		//	ANDI.W	#$FF, D0	[0247 00FF]
		//	LSL.W	#3, D7		[E74F]
		//	LEA		$addr.l, A0	[41F9 xxxx xxxx]
		//	LEA		(A0,D7), A0	[41F0 7000]
		
		/*if (1)
			ROMPos = 0x5BF08;	// Dynamite Headdy drums (J)
		else
			ROMPos = 0x5C736;	// Dynamite Headdy voices (J)
		if (1)
			ROMPos = 0x037724;	// Yuu Yuu Hakusho drums
		else
			ROMPos = 0x0380A8;	// Yuu Yuu Hakusho voices (0x86 sounds!)
		if (1)
			ROMPos = 0x0824A2;	// Alien Soldier drums
		else
			ROMPos = 0x082DEC;	// Alien Soldier voices*/
		
		if (PtrList >= 0x100)
		{
			DacTblBase = PtrList & 0xFFFFFF;
			CurSnd = 0x03;
		}
		else
		{
			// Note: need 4 bytes for Dynamite Headdy (J)
			if (PtrList & 0x01)
			{
				ROMPos = ScanForData2(ROMLength - 0x04, ROMData, 0x04, MAGIC_BYTES_DHEAD_SFX, 0x100);
				if (! ROMPos)	// If in SFX mode, try again with code for "Yuu Yuu Hakusho - Makyou Toitsusen".
					ROMPos = ScanForData2(ROMLength - 0x04, ROMData, 0x04, MAGIC_BYTES_YYHMT_SFX, 0x100);
			}
			else
			{
				ROMPos = ScanForData2(ROMLength - 0x04, ROMData, 0x04, MAGIC_BYTES_DHEAD_MUS, 0x100);
			}
			if (ROMPos)
			{
				ROMPos += 0x04;
				
				printf("Loader found at offset: %06X\n", ROMPos);
				DacTblBase = ReadLEA(ROMData, ROMPos);
				CurSnd = 0x03;
			}
		}
		break;
	case 0x05:	// Chou Yakyuu Miracle Nine | DAC table stored in ROM Bank [Bank offset hardcoded]
		// Output: BnkTblBase, BnkBase
		BnkBase = 0x198000;	// Chou Yakyuu Miracle Nine
		//BnkBase = 0x068000;	// J. League Pro Striker 2
		BnkTblBase = BnkBase | 0x1000;
		CurSnd = 0x01;
		break;
	case 0x08:	// Generic SMPS 68k [SFX] | DAC table stored in ROM Bank
		// Output: DacTblBase
		//BnkBase = 0x168000 + 0x1486;	// Fatal Fury 1
		//BnkBase = 0x2B8000 + 0x0000;	// Fatal Fury 2
		//BnkBase = 0x050000 + 0x0000;	// Magical Taruruuto-Kun
		//BnkBase = 0x040000 + 0x0000;	// Mighty Morphin Power Rangers - The Movie
		//BnkBase = 0x068000 + 0x0800;	// MJ's Moonwalker
		
		if (PtrList >= 0x100)
		{
			DacTblBase = PtrList & 0xFFFFFF;
			CurSnd = 0x03;
		}
		else
		{
			ROMPos = FindBytesWrittenToOfs(CODE_BUF, 0xA01FF8, 0x04);
			if (ROMPos >= 0x04)
			{
				DacTblBase  = (ReadBE16(&CODE_BUF[0x02]) & 0xFF80) << 8;	// Bank Bits
				DacTblBase |= (ReadLE16(&CODE_BUF[0x00]) & 0x7FFF) << 0;	// Pointer List
				CurSnd = 0x03;
			}
		}
		break;
	case 0x0D:	// Mighty Morphin Power Rangers | DAC table stored in ROM Bank
		// Output: DacTblBase, BnkTblBase
		
		// Bank Offsets are hardcoded into the driver.
		// -> Needs evaluation of bank switching code.
		//	Code location:
		//		Music:	003D (MMPR, Viewpoint)
		//		DAC:	0090 (MMPR), 0052/008F/0FDD (Viewpoint, 3 copies of the same code)
		
		//DacTblBase = 0x068000 + 0x0000;	// Mighty Morphin Power Rangers
		//DacTblBase = 0x018000 + 0x0000;	// Viewpoint
		if (PtrList >= 0x2000)
		{
			// use manual Bank offset (will read exactly 1 bank)
			BnkTblBase = 0x0000;
			DacTblBase = PtrList;
			CurSnd = 0x03;
			break;
		}
		
		RAM_CHECK();
		
		BnkTblBase = 0x0000;
		if (PtrList)
		{
			// use manual Bank Code offset
			BnkTblBase = PtrList;
		}
		
		// Mighty Morphin Power Rangers:
		//	Music Bank:	060000	000001100	77 77 73 73 77x5
		//	DAC Bank:	068000	000001101	73 77 73 73 77x5
		
		// How the autodetection works:
		// 1. Find where 1C3D is read (3A 3D 1C)
		//    (Note: The current DAC bank is stored at 1C3D in MMPR and at 1FFE in Viewpoint.)
		// 2. read the consecutive CP xx (FE xx) and JP Z,loc (CA xx xx) commands
		// 3. parse the code until ret (C9) or JR (18 xx) command to get bank value
		//    (will be done by extraction routine)
		
		// Note: In order to exit the loop correctly, we need:
		//       - BnkTblBase (beginning of bank selection code) and
		//       - DacTblBase (Z80 table offset)
		DacTblBase = 0x00;
		for (RAMPos = 0x00; RAMPos < RAMSize - 0x04; RAMPos ++)
		{
			// Search for
			//	LD	A, (addr)	3A xx xx
			//	CP	A, val		FE xx
			if (RAMData[RAMPos + 0x00] == 0x3A && RAMData[RAMPos + 0x03] == 0xFE)
			{
				if (! BnkTblBase)
				{
					// We found the start of the DAC bank switching code.
					BnkTblBase = RAMPos + 0x03;
					if (DacTblBase)
					{
						CurSnd = 0x04;
						break;
					}
				}
			}
			else if (! memcmp(&RAMData[RAMPos], CODE_SET_LD_HL, 0x03))
			{
				if (! DacTblBase)
				{
					// We found the place where the table offset is loaded.
					DacTblBase = ReadLE16(&RAMData[RAMPos + 0x03]);
					if (BnkTblBase)
					{
						CurSnd = 0x04;
						break;
					}
				}
			}
		}
		/*RAMPos = ReadCmpJumpTable(RAMData, BnkTblBase, 0x00);
		printf("Bank Code: %04X\n", RAMPos);
		printf("Bank Code: %04X\n", ReadCmpJumpTable(RAMData, BnkTblBase, 0xFF));
		printf("Bank Count: %hu\n", ReadCmpJumpTable_BnkCount(RAMData, BnkTblBase));
		
		printf("Bank Ofs: %06X\n", ReadBankSwitchCode(RAMData, RAMPos) * 0x8000);*/
		break;
	case 0x0E:	// Mazin Saga
		// Output: DacTblBase
		if (PtrList >= 0x100)
		{
			// PtrList has a valid pointer
			if (PtrList & 0x80000000)
			{
				// Read from Master List
				PtrList &= 0xFFFFFF;
				TempPnt = &ROMData[PtrList];
				
				DacTblBase = PtrList & 0xFF8000;
				DacTblBase |= ReadLE16(TempPnt) & 0x7FFF;
			}
			else
			{
				DacTblBase = PtrList & 0xFFFFFF;
			}
			
			CurSnd = 0x03;
		}
		else
		{
			ROMPos = FindBytesWrittenToOfs(CODE_BUF, 0xA01C00, 0x04);
			if (ROMPos >= 0x04)
			{
				BnkTblBase  = (ReadBE16(&CODE_BUF[0x00]) & 0xFF80) << 8;	// Bank Bits
				BnkTblBase |= (ReadLE16(&CODE_BUF[0x02]) & 0x7FFF) << 0;	// Pointer List
				printf("SMPS Pointer List: %06X\n", BnkTblBase);
				
				RAMPos = 0x0E + (PtrList & 0x01) * 0x02;
				TempPnt = &ROMData[BnkTblBase + RAMPos];
				
				DacTblBase  = BnkTblBase & 0xFF8000;
				DacTblBase |= ReadLE16(TempPnt) & 0x7FFF;
				CurSnd = 0x03;
			}
		}
		break;
	case 0x12:	// Golden Axe III
		// Output: DacTblBase
		
		// Note: The 68k writes the current bank to Z80's 1FF0/1FF1 (MSB/LSB) and the table base to 1FEE/1FEF
		//ROMPos = 0x0F8000 + 0x2E5E;
		
		// Search for
		//	LEA A01FEE, A0	[41F9 00A0 1FEE]
		//	MOVE.L	#...,D0	[203C xxxx xxxx] (that's the full offset of the bank table)
		GenerateCode(CODE_BUF, CODE_LEA_A0, 0xA01FEE, CODE_MOVEL_D0);
		ROMPos = ScanForData2(ROMLength - 0x04, ROMData, 0x08, CODE_BUF, 0x100);
		if (ROMPos)
		{
			printf("Loader found at offset: %06X\n", ROMPos);
			ROMPos += 0x08;
			
			DacTblBase = ReadBE32(&ROMData[ROMPos]) & 0x00FFFFFF;
			CurSnd = 0x03;
		}
		break;
	case 0x19:	// Sonic 3D Blast/Sonic & Knuckles
		// Output: DacTblBase, BnkTblBase
		
		/*BnkTblBase = 0x00D6;	// Sonic 3D
		DacTblBase = 0x8000;
		BnkTblBase = 0x0E20;	// Tempo 32x
		DacTblBase = 0x0E3A;
		BnkTblBase = 0x0E39;	// J. League Pro Striker Final Stage
		DacTblBase = 0x0E55;*/
		
		// J. League Pro Striker Final Stage (also verified: Tempo 32X)
		// ---------------------------------
		// DacTblBase: (DAC Pointer List) [DAC table load routine]
		//	LD	HL, 1C3Ch	[21 3C 1C]
		//	LD	A, (HL)		[7E]
		//	DEC	A			[3D]
		//	SET	7, (HL)		[CB FE]
		//	LD	HL, 0E55h	[21 55 0E]	-> DacTblBase = 0x0E55
		
		// BnkTblBase: (DAC Bank List) [do DAC note routine]
		//	LD	(1C3Ch), A	[32 3C 1C]
		//	LD	HL, 0E39h	[21 39 0E]	-> BnkTblBase = 0x0E39
		//	LD	D, 00h		[16 00]
		//	LD	E, A		[5F]
		//	ADD	HL, DE		[19]
		//	LD	A, (HL)		[7E]
		//	LD	(1C3F), A	[32 3F 1C]
		
		// Sonic 3 (also verified: Sonic 3D Blast)
		// -------
		// DacTblBase: (DAC Pointer List) [DAC table load routine]
		//	LD	HL, 1C30h	[21 3C 10]
		//	LD	A, (HL)		[7E]
		//	DEC	A			[3D]
		//	SET	7, (HL)		[CB FE]
		//	LD	HL, 8000h	[21 00 80]	-> DacTblBase = 0x8000
		
		// BnkTblBase: (DAC Bank List) [last part of VInt routine]
		//	LD	A, (1C30h)	[3A 30 1C]
		//	AND	7Fh			[E6 7F]
		//	LD	C, A		[4F]
		//	LD	B, 00h		[06 00]
		//	LD	HL, 00DCh	[21 DC 00]	-> BnkTblBase = 0x00DC (00D6 in Sonic 3D)
		//	ADD	HL, BC		[09]
		//	LD	A, (HL)		[7E]
		//	LD	HL, 6000h	[21 00 60]
		
		// Works the same for all games.
		RAMPos = ScanForData(RAMSize - 0x02, RAMData, 0x03, CODE_SET_LD_HL, 0x00);
		if (! RAMPos)
		{
			printf("DAC Table not found!\n");
			break;
		}
		DacTblBase = ReadLE16(&RAMData[RAMPos + 0x03]);
		
		// search for the common SMPS Z80 way
		RAMPos = ScanForData(RAMSize - 0x02, RAMData, 0x04, CODE_LD_1C3C_LD_HL, 0x00);
		if (! RAMPos)
		{
			// search for Sonic 3/K/3D
			RAMPos = ScanForData(RAMSize - 0x02, RAMData, 0x04, CODE_LD_CA_B0_HL, 0x00);
		}
		if (! RAMPos)
		{
			printf("DAC Bank Table not found!\n");
			break;
		}
		BnkTblBase = ReadLE16(&RAMData[RAMPos + 0x04]);
		
		// BnkTblBase points to bank for sound 80,
		BnkTblBase ++;	// but we start at 81
		
		CurSnd = 0x05;
		break;
	case 0x01:	// Phantasy Star IV
		// Output: BnkTblBase, BnkBase
		RAM_CHECK();
		
		// Note: ROM Bank is hardcoded into the Z80 driver
		//	Bits are 0000111xx = 0E0000 | (xx << 15)
		//BnkBase = 0xE0000;
		//BnkTblBase = 0x0500;
		//ROMPos = 0x0438;
		
		RAMPos = ScanForData(RAMSize - 0x02, RAMData, 0x04, CODE_LD_1FFD_LD_DE, 0x00);
		if (! RAMPos)
			break;
		// We found the address of the Bank/Sound table.
		BnkTblBase = ReadLE16(&RAMData[RAMPos + 0x04]);
		
		RAMPos = ScanForData(RAMSize, RAMData, 0x03, CODE_LD_HL_6000, 0x00);
		if (! RAMPos)
			break;
		// We found the start of the DAC bank switching code.
		BnkBase = ReadBankSwitchCode(RAMData, RAMPos + 0x03) << 15;
		CurSnd = BnkBase ? 0x01 : 0x00;
		
		printf("Bank Base: %06X\n", BnkBase);
		printf("Bank/Sound Table: %04X\n", BnkTblBase);
		break;
	case 0x11:	// SM1bM 4 | Offsets hardcoded for now (search possible, but it's not worth the effort)
		// Output: DacTblBase, BnkTblBase
		BnkTblBase = 0x01171E;
		DacTblBase = 0x01166E;
		if (BnkTblBase >= ROMLength)
			break;
		
		printf("PCM Sound List: %06X\n", BnkTblBase);
		printf("PCM Sound Offsets: %06X\n", DacTblBase);
		CurSnd = 0x01;
		break;
	case 0x02:	// Phantasy Star 2
		// Output: DacTblBase
		RAM_CHECK();
		
		RAMPos = ScanForData(RAMSize, RAMData, 0x06, MAGIC_BYTES_PS2, 0x00);
		if (RAMPos)
		{
			DacTblBase = ReadLE16(&RAMData[RAMPos + 0x06]);	// read "JP Z, nosound" instruction
			DacTblBase += 0x03;	// actual DAC tables begin at the next instruction
			CurSnd = 0x02;
		}
		break;
	case 0x07:	// Ristar
		// Output: DacTblBase, BnkTblBase
		RAM_CHECK();
		
		// DacTblBase - DAC offsets for Z80 RAM sounds
		// BnkTblBase - DAC offsets for ROM sounds
		
		RAMPos = ScanForData(RAMSize, RAMData, 0x02, &MAGIC_BYTES_S1[0x02], 0x00);
		if (! RAMPos)
			break;
		// The RAM Offset is used for a few drum sounds that are stored in Z80 RAM.
		DacTblBase = ReadLE16(&RAMData[RAMPos + 0x02]);
		
		// TODO: Search for BnkTblBase
		BnkTblBase = 0x0CC100;	// DAC ROM offsets
		//BnkTblBase = 0x1C3F28;	// Ristar Beta
		
		printf("DAC Z80 Table starts at %04X\n", DacTblBase);
		printf("DAC ROM Table starts at %06X\n", BnkTblBase);
		CurSnd = 0x01;
		
		// BnkTblBase:
		//	LEA		$0CC100.l, A0
		//	SUBQ.B	#1, D0
		//	ADD.W	D0, D0	[x4]
		//	ADDA.W	D0, A0
		// Search for:
		//	SUBQ.B	#1, D0	[5300]
		//	ADD.W	D0, D0	[D040]	x4
		//	ADDA.W	D0, A0	[D0C0]
		
		// DAC Drum/SFX Index Table:
		//	LEA		(-$516, PC), A0
		//	ANDI.B	#$7F, D0
		//	SUBQ.B	#1, D0
		//	ADD.W	D0, D0	[x2]
		//	ADDA.W	D0, A0
		// Search for:
		//	ANDI.B	#$7F, D0	[0200 007F]
		//	SUBQ.B	#1, D0		[5300]
		//	ADD.W	D0, D0		[D040]	x2
		//	ADDA.W	D0, A0		[D0C0]
		break;
	case 0x0A:	// Sonic 2 Clone Driver + jman2050 DAC [MarkeyJester Mod]
	case 0x13:	// PsychoSk8r DAC Driver
		// Output: DacTblBase
		// Auto-Search for jman2050 DAC with MarkeyJester DAC Table
		
		// Old algorithm:
		//	1. Search for 00 A0 01 50
		//	2. From there search for 4E75 (RTS)
		//	3. Directly after that is the DAC Table
		/*BnkBase = ScanForData2(ROMLength, ROMData, 0x04, MAGIC_BYTES_JMAN_150, 0x100);
		if (! BnkBase)
			break;
		ROMPos = ScanForData(ROMLength, ROMData, 0x02, CODE_RTS, BnkBase);
		if (! ROMPos || (ROMPos - BnkBase) > 0x40)	// the difference should be exactly 0018
			break;
		DacTblBase = ROMPos + 0x02;
		CurSnd = 0x03;*/
		
		// New algorithm:
		//	1. Search for 00 A0 01 50
		//	2. go back 6 bytes, there is the pointer to the DAC Table.
		for (ROMPos = 0x100; ROMPos < ROMLength - 0x20; ROMPos += 0x02)
		{
			if (! memcmp(&ROMData[ROMPos], MAGIC_BYTES_JMAN_150, 0x04) ||
				! memcmp(&ROMData[ROMPos], MAGIC_BYTES_JMAN_200, 0x04))
			{
				if (! memcmp(&ROMData[ROMPos - 0x08], CODE_LEA_A0, 0x02))
				{
					DacTblBase = ReadBE32(&ROMData[ROMPos - 0x06]);
					CurSnd = 0x03;
					break;
				}
			}
		}
		break;
	case 0x0B:	// Virtua Racing Deluxe 32X, Sonic Crackers
	case 0x20:	// Metal Head 32X, Shadow Squadron 32X
		// Output: DacTblBase, BnkBase
		RAM_CHECK();
		
		//DacTblBase = 0x0105;
		//BnkBase = 0x800000;
		
		// Search for (3D 21 xx xx 4F) 06 00 09 09
		for (RAMPos = 0x04; RAMPos < RAMSize - 0x08; RAMPos ++)
		{
			if (! memcmp(&RAMData[RAMPos], MAGIC_BYTES_VTRACE_DX, 0x04) &&
				RAMData[RAMPos - 0x04] == 0x21)
			{
				DacTblBase = ReadLE16(&RAMData[RAMPos - 0x03]);
				CurSnd = 0x02;
				break;
			}
		}
		
		if (! CurSnd)
		{
			//DacTblBase = 0x11DE;
			//BnkBase = 0x000000;
			RAMPos = ScanForData(RAMSize - 0x02, RAMData, 0x03, CODE_SET_LD_HL, 0x00);
			if (! RAMPos)
				break;
			DacTblBase = ReadLE16(&RAMData[RAMPos + 0x03]);
		}
		CurSnd = 0x02;
		
		// How to get Bank Base:
		//  Search for LD	HL, 6000h	[21 00 60]
		//  and read the code.
		BnkBase = 0x000000;
		RAMPos = ScanForData(RAMSize, RAMData, 0x03, CODE_LD_HL_6000, 0x00);
		if (RAMPos)
		{
			RAMPos += 0x03;
			BnkBase = ReadBankSwitchCode(RAMData, RAMPos) << 15;
		}
		break;
	case 0x0C:	// OutRunners, Virtua Fighter 2
		// Output: DacTblBase, BnkBase
		// TODO: auto search (for Virtua Fighter 2)
		RAM_CHECK();
		
		// It's impossible to do a proper search for that,
		// because there are JPs in front of the LD HL, xxx commands.
		//DacTblBase = 0x0C5E;
		//BnkBase = 0x180000;
		//CurSnd = 0x01;
		
		BnkBase = 0x000000;
		// OutRunners: search for (21 xx xx) 32 19 1C.
		// Virtua Figher 2: search for (21 xx xx) 3D 4F 06 00 09 09
		for (RAMPos = 0x03; RAMPos < RAMSize - 0x08; RAMPos ++)
		{
			if (! memcmp(&RAMData[RAMPos], MAGIC_BYTES_VFIGHT2, 0x06) &&
				RAMData[RAMPos - 0x03] == 0x21)
			{
				DacTblBase = ReadLE16(&RAMData[RAMPos - 0x02]);
				CurSnd = 0x02;
				break;
			}
		}
		break;
	case 0x04:	// Sonic 2 Clone Driver + jman2050 DAC
	case 0x09:	// Sonic 2 Clone Driver + jman2050 DAC [GenesisFan64 Mod]
	case 0x1A:	// Sonic 2 Clone Driver + jman2050 DAC [Aquaslash Mod]
		// Output: DacTblBase
		
		// Auto-Search for jman2050 DAC with Puto DAC Table (most common version)
		// 1. Search for 00 A0 02 00
		// 2. That is the first entry of the DAC Table
		// 3. [Optional] Check, if the last command before the table is a RTS
		ROMPos = ScanForData2(ROMLength, ROMData, 0x04, MAGIC_BYTES_JMAN_200, 0x100);
		while(ROMPos)
		{
			if (! memcmp(&ROMData[ROMPos - 0x02], CODE_RTS, 0x02) ||	// default
				! memcmp(&ROMData[ROMPos - 0x04], CODE_BSR_W, 0x02))	// Aquaslash Mod
			{
				DacTblBase = ROMPos;
				CurSnd = 0x03;
				break;
			}
			ROMPos = ScanForData2(ROMLength, ROMData, 0x04, MAGIC_BYTES_JMAN_200, ROMPos + 0x04);
		}
		break;
	case 0x14:	// The Hybrid Front
		// Output: DacTblBase, BnkTblBase, BnkBase
		RAM_CHECK();
		
		// BnkTblBase: (DAC Bank List) [last part of VInt routine]
		//	DEC	A			[3D]
		//	PUSH AF			[F5]
		//	SET	7, (HL)		[CB FE]
		//	EXX				[D9]
		//	LD	H, 0Ah		[26 0A]
		//	ADD	A, 3Dh		[C6 3D]	-> BnkTblBase = 0x0A3D
		//	LD	L, A		[6F]
		//	ADC	A, H		[8C]
		//	SUB	L			[95]
		//	LD	H, A		[67]
		//	LD	A, (HL)		[7E]
		//	LD	(1C3D), A	[32 3D 1C]
		
		// RAMPos: (DAC Pointer List) [last part of VInt routine, after bank switching code]
		//	POP	AF			[F1]
		//	LD	HL, 0A53h	[21 53 0A]	-> RAMPos = 0x0A53
		//	LD	C, A		[4F]
		//	ADD	A, A		[87]
		//	ADD	A, A		[87]
		//	ADD	A, C		[81]
		//	LD	C, A		[4F]
		//	LD	B, 00h		[06 00]
		//	ADD	HL, BC		[09]
		//	LD	A, (HL)		[7E]
		
		BnkBase = 0x70000;
		BnkTblBase = 0x0000;
		RAMPos = ScanForData(RAMSize, RAMData, 0x04, MAGIC_BYTES_HFRONT_1, 0x00);
		if (! RAMPos)
			break;
		RAMPos += 0x03;
		BnkTblBase = (RAMData[RAMPos + 0x01] << 8) | (RAMData[RAMPos + 0x03] << 0);
		
		RAMPos = ScanForData(RAMSize, RAMData, 0x02, MAGIC_BYTES_HFRONT_2, RAMPos);
		if (! RAMPos)
			break;
		DacTblBase = ReadLE16(&RAMData[RAMPos + 0x02]);
		CurSnd = 0x05;
		break;
	case 0x15:	// Virtua Racing
		// Output: DacTblBase, BnkTblBase, BnkBase
		RAM_CHECK();
		
		RAMPos = ScanForData(RAMSize, RAMData, 0x04, MAGIC_BYTES_VTRACE, 0x00);
		if (! RAMPos)
			RAMPos = ScanForData(RAMSize, RAMData, 0x04, MAGIC_BYTES_SM_GP, 0x00);
		if (! RAMPos)
			break;
		DacTblBase = ReadLE16(&RAMData[RAMPos + 0x04]);
		CurSnd = 0x02;
		
		// VR Sound Effects:
		//	LD	(1F82h), A		[32 82 1F]
		//	LD	HL, xxxxh		[21 xx xx]
		BnkTblBase = 0x0E77E0;
		
		// Note: Bank is written to 1C00/1C01. (1C00 = 07, 1C01 = 80)
		ROMPos = FindBytesWrittenToOfs(CODE_BUF, 0xA01C00, 0x04);
		if (ROMPos >= 0x02)
		{
			BnkBase = (ReadBE16(&CODE_BUF[0x00]) & 0xFF80) << 8;	// Bank Bits
			//BnkBase = 0x078000;	// works with Super Monaco Grand Prix
		}
		break;
	case 0x16:	// Rent A Hero
		// Output: DacTblBase, BnkTblBase
		RAM_CHECK();
		
		ROMPos = ScanForData2(ROMLength, ROMData, 0x06, MAGIC_BYTES_RAHERO, 0x100);
		if (! ROMPos)
			break;
		// Pointer for DAC Sets
		BnkTblBase = ReadBE32(&ROMData[ROMPos + 0x06]);
		CurSnd = 0x01;
		
		DacTblBase = 0x0000;
		RAMPos = ScanForData(RAMSize, RAMData, 0x04, MAGIC_BYTES_RAHERO_2, 0x00);
		if (RAMPos)
		{
			// DAC Table Offset in Z80 RAM
			DacTblBase = ReadLE16(&RAMData[RAMPos + 0x04]) - 0x0002;
		}
		else
		{
			DacTblBase = 0x0200;
			printf("Warning: Beginning of DAC RAM not found, assuming 0x%04X!\n", DacTblBase);
		}
		printf("DAC Set Table starts at %06X, DAC Tables start at %04X (Z80 RAM).\n",
				BnkTblBase, DacTblBase);
		break;
	case 0x17:	// vladikcomper's MegaPCM
		// Output: DacTblBase
		RAM_CHECK();
		
		RAMPos = ScanForData(RAMSize, RAMData, 0x02, MAGIC_BYTES_MEGAPCM, 0x00);
		if (! RAMPos)
			break;
		DacTblBase = ReadLE16(&RAMData[RAMPos + 0x02]);
		CurSnd = 0x02;
		break;
	case 0x1B:	// Bishoujo Senshi Sailor Moon
		// Output: DacTblBase
		RAM_CHECK();
		
		// search for 00 3D 87 21
		DacTblBase = 0x00EF;
		CurSnd = 0x02;
		break;
	case 0x1C:	// Samurai Shodown
		// Output: DacTblBase
		RAM_CHECK();
		
		RAMPos = ScanForData(RAMSize, RAMData, 0x03, CODE_LD_IY, 0x00);
		if (! RAMPos)
			break;
		DacTblBase = ReadLE16(&RAMData[RAMPos + 0x03]);
		CurSnd = 0x02;
		break;
	case 0x1D:	// Knuckles Chaotix
		// Output: DacTblBase
		ROMPos = ScanForData2(ROMLength, ROMData, 0x08, MAGIC_BYTES_32X_PWM, 0x100);
		while(ROMPos)
		{
			ROMPos += 0x0C;
			if (ROMData[ROMPos] == 0x02 || ROMData[ROMPos] == 0x22)
			{
				DacTblBase = ReadBE32(&ROMData[ROMPos]) & 0x00FFFFFF;
				CurSnd = 0x03;
				break;
			}
			ROMPos = ScanForData2(ROMLength, ROMData, 0x08, MAGIC_BYTES_32X_PWM, ROMPos);
		}
		break;
	case 0x1E:	// Visual Scene SEGA-CD Image
		// Output: DacTblBase
		DacTblBase = 0x040000;
		CurSnd = 0x01;
		break;
	case 0x1F:	// Sonic 2
		// Output: DacTblBase, BnkBase
		RAM_CHECK();
		
		RAMPos = ScanForData(RAMSize, RAMData, 0x05, MAGIC_BYTES_S2, 0x00);
		if (! RAMPos)
			break;
		DacTblBase = ReadLE16(&RAMData[RAMPos - 0x06]);
		CurSnd = 0x02;
		BnkBase = 0x0E8000;
		
		RAMPos -= 0x10;
		for (; RAMPos > 0x0000; RAMPos --)
		{
			if (! memcmp(&RAMData[RAMPos], CODE_LD_HL_6000, 0x03))
			{
				BnkTblBase = RAMPos - 0x03;
				BnkBase = ReadBankSwitchCode(RAMData, BnkTblBase) << 15;
				CurSnd = 0x04;
				break;
			}
		}
		break;
	case 0x21:	// Mercs
		// TODO: read bank switch code
		if (! PtrList)
			DacTblBase = 0x0F8000;
		else
			DacTblBase = PtrList;
		CurSnd = 0x03;
		break;
	case 0x23:	// Ayrton Senna's Super Monaco GP II
		// TODO: read bank switch code
		if (! PtrList)
		{
			printf("You need to manually supply the DAC Bank!\n");
			return 0xF1;
		}
		//DacTblBase = 0x0E8000;
		DacTblBase = PtrList;
		
		ROMPos = ReadBE32(&ROMData[DacTblBase + 0x0C]) & 0x00FFFFFF;	// read 0D/0E/0F
		if (! ROMPos)
			BnkTblBase = 0x10;
		else
			BnkTblBase = 0x0D;
		printf("DAC Entry Size: %02Xh bytes\n", BnkTblBase);
		CurSnd = 0x03;
		break;
	case 0x24:	// Sega Pico ADPCM
		// late Pico SMPS: [Mickey no Boku wa Meitantei]
		//	0B1568	0280 0000 FFFF	ANDI.L	#$FFFF, D0
		//	0B156E	E988			LSL.L	#4, D0
		//	0B1570	41FA 0CA8		LEA		PCMSampleTbl, A0
		//	0B1574	D1C0			ADDA.L	D0, A0
		//	0B1576	1958 0002		MOVE.B	(A0)+, $02(A4)
		//	0B157A	5288			ADDQ.L	#1, A0
		//	0B157C	2018			MOVE.L	(A0)+, D0
		// early Pico SMPS: [Sonic Gameworld (J)]
		//	069178	0280 0000 00FF	ANDI.L	#$FF, D0
		//	06917E	E988			LSL.L	#4, D0
		//	069180	41FA 0A98		LEA		PCMSampleTbl(pc), A0
		//	069184	D1C0			ADDA.L	D0, A0
		//	069186	3958 0002		MOVE.W	(A0)+, $02(A4)
		//	06918A	2018			MOVE.L	(A0)+, D0
		for (RAMPos = 0; RAMPos < 2; RAMPos ++)
		{
			ROMPos = ScanForData_WC(ROMLength, ROMData, MB_SPICO_LEN[RAMPos], MB_SPICO_PTR[RAMPos], 0x100);
			while(ROMPos)
			{
				if (ROMData[ROMPos - 0x04] == 0x41)
				{
					DacTblBase = ReadLEA(ROMData, ROMPos - 0x04);
					CurSnd = 0x03;
					break;
				}
				else if (ROMData[ROMPos - 0x06] == 0x41)
				{
					DacTblBase = ReadLEA(ROMData, ROMPos - 0x06);
					CurSnd = 0x03;
					break;
				}
				ROMPos += MB_SPICO_LEN[RAMPos];
				ROMPos = ScanForData_WC(ROMLength, ROMData, MB_SPICO_LEN[RAMPos], MB_SPICO_PTR[RAMPos], ROMPos);
			}
			if (CurSnd)
				break;
		}
		break;
	case 0x25:	// J. League Pro Striker DAC driver
		DacTblBase = 0x0B0000;
		CurSnd = 0x03;
		break;
	case 0x26:	// Wimbledon Championship Tennis (DAC Voices)
		// Output: DacTblBase, BnkTblBase
		RAM_CHECK();
		
		RAMPos = ScanForData(RAMSize, RAMData, 0x06, MAGIC_BYTES_WCTENNIS_1, 0x00);
		if (! RAMPos)
			break;
		BnkTblBase = ReadLE16(&RAMData[RAMPos - 0x02]);
		
		RAMPos = ScanForData(RAMSize, RAMData, 0x08, MAGIC_BYTES_WCTENNIS_2, 0x00);
		if (! RAMPos)
			break;
		DacTblBase = ReadLE16(&RAMData[RAMPos - 0x02]);
		CurSnd = 0x05;
		break;
	case 0x27:	// SMPS Z80/Gamtec
		// Output: DacTblBase, BnkTblBase
		RAM_CHECK();
		
		RAMPos = ScanForData(RAMSize, RAMData, 0x07, MAGIC_BYTES_GAMTEC_1, 0x00);
		if (! RAMPos)
			break;
		DacTblBase = (RAMData[RAMPos + 0x07] << 16) | (RAMData[RAMPos - 0x01] << 8);
		
		RAMPos = ScanForData(RAMSize, RAMData, 0x09, MAGIC_BYTES_GAMTEC_2, 0x00);
		if (RAMPos)
			ROMPos = ReadLE16(&RAMData[RAMPos - 0x02]);
		else
			ROMPos = 0x0000;
		DacTblBase &= 0xFF8000;
		DacTblBase |= (ROMPos & 0x7FFF);
		
		CurSnd = 0x03;
		break;
	default:
		//printf("Unknown DAC format number!\n");
		return 0x80;
	}	// end switch(Mode)
	
	return CurSnd;
}

UINT8 ExtractDACSounds(UINT8 Mode, UINT32 PtrList)
{
	// Originally based on code from my Data East Data Extractor
	FILE* hFile;
	FILE* hFileINI;
	
	UINT32 ROMPos;
	UINT16 RAMPos;
	const UINT8* TempPnt;
	UINT8 BnkCnt;
	UINT8 CurSnd;
	UINT8 CurBnk;
	UINT8 BnkSnd;
	UINT8 DigitsBnk;
	UINT8 DigitsSnd;
	UINT32 AddrLst[0x100];
	UINT8 AddrID[0x100];
	UINT8 CurLst;
	UINT32 SndAddr;
	UINT32 SndLen;
	UINT32 LstVal;
	UINT16 MinPos;
	char TempName[0x10];
	char OutName[0x50];
	
	DAC_LIB DACLib;
	DAC_LIST* TempSnd;
	DAC_LIST* TempSnd2;
	
	// Supported Formats:
	//	0x00*	Sonic 1
	//	0x01*	Phantasy Star IV
	//	0x02*	Phantasy Star 2
	//	0x03	Dynamite Headdy / Yuu Yuu Hakusho - Makyou Toitsusen
	//	0x04	Sonic 2 Clone Driver + jman2050 DAC
	//	0x05 h	Chou Yakyuu Miracle Nine
	//	0x06*	DAC Drums:	Mighty Morphin Power Rangers - The Movie /
	//						Fatal Fury 1/2, MJ's Moonwalker
	//	0x07*h	Ristar
	//	0x08	DAC Voices:	Magical Taruruuto-Kun / Mighty Morphin Power Rangers - The Movie /
	//						Fatal Fury 1/2, MJ's Moonwalker
	//	0x09	Sonic 2 Clone Driver + jman2050 DAC [GenesisFan64 Mod]
	//	0x0A	Sonic 2 Clone Driver + jman2050 DAC [MarkeyJester Mod]
	//	0x0B*	Virtua Racing Deluxe 32X / Sonic Crackers
	//	0x0C*h	OutRunners, Virtua Fighter 2
	//	0x0D	Mighty Morphin Power Rangers / Viewpoint
	//	0x0E	Mazin Saga
	//	0x0F h	[removed]
	//	0x10*	Streets of Rage / A Ressha de Gyoukou MD
	//	0x11 h	SM1bM 4
	//	0x12 	Golden Axe III
	//	0x13	PsychoSk8r DAC driver
	//	0x14*	The Hybrid Front
	//	0x15*	Virtua Racing / Super Monaco Grand Prix
	//	0x16*	Rent A Hero / Metal Fangs / Street Fighter II Turbo Beta
	//	0x17*	vladikcomper's MegaPCM
	//	0x19	Sonic 3D Blast/Sonic & Knuckles
	//	0x1A	Sonic 2 Clone Driver + jman2050 DAC [Aquaslash Mod]
	//	0x1B*h	Bishoujo Senshi Sailor Moon
	//	0x1C*	Samurai Shodown
	//	0x1D	Knuckles Chaotix
	//	0x1E	Visual Scene SEGA-CD Image
	//	0x1F	Sonic 2
	//	0x20*	Metal Head 32X, Shadow Squadron 32X
	//	0x21	Mercs
	//	0x22*	DAC Drums:	Magical Taruruuto-Kun / Pulseman (uses Bank Table)
	//	0x23	Ayrton Senna's Super Monaco GP II
	//	0x24	Sega Pico SMPS
	// * uses RAMData
	// h uses hardcoded offsets
	
	// --- Step 1: Get the addresses that are needed by the extraction routines ---
	DacTblBase = 0x00;
	BnkTblBase = 0x00;
	BnkBase = 0x00;
	CurSnd = SearchDACTable(Mode, PtrList);
	if (CurSnd == 0xF0)
	{
		printf("Can't work without Z80 Driver data!\n");
		return 0x01;
	}
	else if (CurSnd == 0x00)
	{
		printf("Magic bytes for DAC sound list not found!\n");
		return 0x02;
	}
	else if (CurSnd == 0x80)
	{
		printf("Unknown DAC format number!\n");
		return 0x03;
	}
	else if (CurSnd & 0x80)
	{
		return 0x04;
	}
	// CurSnd Codes:
	//  00	Table not found - return
	//  01	no additional messages (used when custom messages were displayed already)
	//  02	Message: Table at RAM
	//  03	Message: Table at ROM
	//  04	Message: Bank Code at RAM, Table at ROM-Bank
	//  05	Message: Bank List at RAM, Table at ROM-Bank
	if (CurSnd == 0x02)
		printf("DAC Table starts at %04X (Z80 RAM).\n", DacTblBase);
	else if (CurSnd == 0x03)
		printf("DAC Table starts at %06X (ROM).\n", DacTblBase);
	else if (CurSnd == 0x04)
		printf("DAC Bank Switch Code starts at %04X, DAC Table at %04X (Z80 Bank).\n",
				BnkTblBase, DacTblBase);
	else if (CurSnd == 0x05)
		printf("DAC Bank Table starts at %04X (Z80 RAM), DAC Table at %04X (Z80 Bank).\n",
				BnkTblBase, DacTblBase);
	
	// Initialize DAC Lib structure
	memset(&DACLib, 0x00, sizeof(DAC_LIB));
	
	TempSnd = DACLib.Snds;
	for (CurSnd = 0x00; CurSnd < 0xFF; CurSnd ++, TempSnd ++)
		TempSnd->Z80WarnAddr = 0xFFFF;
	
	// --- Step 2: Iterate over all sound entries and write them into DACLib ---
	CurSnd = 0x00;
	switch(Mode)
	{
	case 0x00:	// Sonic 1
		// Note: HPZMan made a slightly modified Sonic 1 DAC driver
		//       which adds support for banked and uninterruptable sounds. (bytes 6 and 7)
		// Sonic 1 itself only uses bytes 0-4.
		DACLib.RateStr = "Sonic 1";
		//DACLib.BaseRate = 275300;
		//DACLib.RateDiv = 1068;
		DACLib.BaseCycles = 301;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x01;
		
		RAMPos = (UINT16)DacTblBase;
		
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, RAMPos += 0x08)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if (RAMPos + 0x07 >= RAMSize)
				break;
			
			TempPnt = &RAMData[RAMPos];
			if (TempPnt[0x05] || (TempPnt[0x07] & 0xFE) || (TempPnt[0x06] & 0xC0))
				break;
			
			SndAddr = ReadLE16(&TempPnt[0x00]);
			SndLen = ReadLE16(&TempPnt[0x02]);
			
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Flags |= 0x10;
				if (SndAddr >= RAMSize)
				{
					TempSnd->Z80WarnAddr = SndAddr;
					TempSnd->Flags |= 0x80;
					continue;
				}
				//TempSnd->CommentStr = "Sound from Z80 RAM";
			}
			else
			{
				// Note: Keeping the 0x8000 bit is correct.
				SndAddr |= TempPnt[0x06] << 16;
			}
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x04];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = TempPnt[0x07];	// uninterruptable flag
		}
		break;
	case 0x01:	// Phantasy Star IV
		DACLib.RateStr = "Phantasy Star IV";
		DACLib.BaseRate = 275300;	// Note: incorrect
		DACLib.RateDiv = 1068;
		DACLib.Flags = 0x10;
		
		RAMPos = BnkTblBase;
		
		BnkCnt = 0x00;
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, RAMPos += 0x02)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if (RAMData[RAMPos] > 0x03)
				break;
			
			CurBnk = RAMData[RAMPos + 0x00];
			BnkSnd = RAMData[RAMPos + 0x01];
			BnkBase &= 0xFE0000;
			BnkBase |= CurBnk << 15;
			
			MinPos = ReadLE16(&ROMData[BnkBase]) & 0x7FFF;
			ROMPos = BnkSnd << 3;
			if (ROMPos >= MinPos)
				break;
			
			if (BnkCnt <= CurBnk)
				BnkCnt = CurBnk + 1;
			TempPnt = &ROMData[BnkBase | ROMPos];
			SndAddr = ReadLE16(&TempPnt[0x00]);
			SndLen = ReadLE16(&TempPnt[0x02]);
			
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x90;
				continue;
			}
			SndAddr &= 0x7FFF;
			SndAddr |= BnkBase;
			
			TempSnd->BankID = CurBnk;
			TempSnd->SndID = BnkSnd;
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = 0x16;
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x02:	// Phantasy Star 2
		DACLib.RateStr = "Phantasy Star II";
		DACLib.BaseCycles = 245;
		DACLib.LoopCycles = 13;
		DACLib.LoopSamples = 1;
		DACLib.Flags = 0x00;
		
		// PS2 has everything hardcoded and uses a large
		// switch-block to load the DAC offsets.
		RAMPos = (UINT16)DacTblBase;
		
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x10; CurSnd ++, TempSnd ++, RAMPos += 0x0B)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if (RAMPos + 0x07 >= RAMSize)
				break;
			
			TempPnt = &RAMData[RAMPos];
			if (TempPnt[0x00] == 0x11 && TempPnt[0x03] == 0x21)
			{
				// Phantasy Star 2
				// 11 xx xx  LD DE, StartOfs
				// 21 xx xx  LD HL, DataLen
				// 3E xx     LD A, Pitch
				// C3 xx xx  JP LoadDAC
				SndAddr = ReadLE16(&TempPnt[0x01]);
				SndLen = ReadLE16(&TempPnt[0x04]);
			}
			else if (TempPnt[0x00] == 0x21 && TempPnt[0x03] == 0x11)
			{
				// World Championship Soccer
				// 21 xx xx  LD HL, StartOfs
				// 11 xx xx  LD DE, DataLen
				// 3E xx     LD A, Pitch
				// C3 xx xx  JP LoadDAC
				SndAddr = ReadLE16(&TempPnt[0x01]);
				SndLen = ReadLE16(&TempPnt[0x04]);
			}
			else
			{
				break;
			}
			
			TempSnd->Flags |= 0x10;
			if (SndAddr >= RAMSize)
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x80;
				continue;
			}
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x07];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
			
			// try to detect whether it is PCM or DPCM playback
			SndLen = ReadLE16(&TempPnt[0x09]);
			SndAddr = ScanForData(SndLen + 0x10, RAMData, 0x04, MAGIC_BYTES_PS2_DPCM, SndLen);
			if (SndAddr)
			{
				if (ReadBE16(&RAMData[SndAddr + 0x04]) == 0xD911)	// check for EX AF,AF'; LD DE, xxxx
					TempSnd->Flags |= 0x01;	// set DPCM flag
			}
		}
		break;
	case 0x03:	// Dynamite Headdy / Yuu Yuu Hakusho - Makyou Toitsusen
		DACLib.RateStr = "SMPS Treasure";
		//DACLib.BaseRate = 274700;
		//DACLib.RateDiv = 1340;	// 13.40 was a pretty good approximation for 375 cycles.
		DACLib.BaseCycles = 387;	// Dynamite Headdy only: BaseCyles = 375
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x01;
		
		ROMPos = DacTblBase;
		
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0xFF; CurSnd ++, TempSnd ++, ROMPos += 0x08)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if (ROMData[ROMPos + 0x01] & 0x7F)
				break;
			
			TempPnt = &ROMData[ROMPos];
			SndAddr = ReadLE16(&TempPnt[0x02]);
			BnkBase = ReadBE16(&TempPnt[0x00]) << 8;
			BnkBase = (BnkBase & 0xFF8000) | (SndAddr & 0x7FFF);
			
			TempPnt = &ROMData[BnkBase];
			SndAddr = ReadLE16(&TempPnt[0x00]);
			
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x90;
				continue;
			}
			SndAddr = (BnkBase & 0xFF8000) | (SndAddr & 0x7FFF);
			SndLen = ReadLE16(&TempPnt[0x02]);
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = ROMData[ROMPos + 0x04];
			TempSnd->Pan = ROMData[ROMPos + 0x06];
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x04:	// Sonic 2 Clone Driver + jman2050 DAC
		// Note: Very common in Sonic hacks
		DACLib.RateStr = "jman2050";
		//DACLib.BaseRate = 275320;
		//DACLib.RateDiv = 796;
		DACLib.BaseCycles = 233;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x02;
		
		ROMPos = DacTblBase;
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, ROMPos += 0x0C)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &ROMData[ROMPos];
			if (TempPnt[0x00] || TempPnt[0x04])
				break;
			
			BnkBase = ReadBE32(&TempPnt[0x00]);
			SndAddr = ReadBE32(&TempPnt[0x04]);
			SndLen = ReadBE16(&TempPnt[0x08]) << 1;
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x0A];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = TempPnt[0x0B];
		}
		break;
	case 0x05:	// Chou Yakyuu Miracle Nine
		DACLib.RateStr = "Chou Yakyuu Miracle Nine";
		DACLib.BaseCycles = 294;
		DACLib.LoopCycles = 0;
		DACLib.LoopSamples = 1;
		DACLib.Flags = 0x00;
		
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x27; CurSnd ++, TempSnd ++)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &ROMData[BnkTblBase + (CurSnd * 0x02)];
			if (! (TempPnt[0x01] & 0x80))
				break;
			
			RAMPos = ReadLE16(&TempPnt[0x00]);
			TempPnt = &ROMData[BnkBase + (RAMPos & 0x7FFF)];
			
			BnkBase = TempPnt[0x01] << 15;
			SndAddr = ReadLE16(&TempPnt[0x04]);
			SndLen = ReadLE16(&TempPnt[0x02]);
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x90;
				continue;
			}
			SndAddr = (BnkBase & 0xFF8000) | (SndAddr & 0x7FFF);
			
			if (TempPnt[0x00] & 0x01)
				TempSnd->CommentStr = "looping sound";
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = 0x0C;
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x06:	// DAC Drums:	Mighty Morphin Power Rangers - The Movie / Fatal Fury 1/2
	case 0x22:	// DAC Drums:	Magical Taruruuto-Kun / Pulseman
		DACLib.RateStr = "SMPS 68k";
		DACLib.BaseCycles = 425;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x01;
		
		//BnkBase = 0x168000;
		RAMPos = (UINT16)DacTblBase;
		
		MinPos = 0x1FFF;
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, RAMPos += 0x0C)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if (RAMPos + 0x0C >= RAMSize)
				break;
			if (RAMPos >= MinPos)
				break;
			
			TempPnt = &RAMData[RAMPos];
			if (TempPnt[0x04] || TempPnt[0x05])
				break;
			
			SndAddr = ReadLE16(&TempPnt[0x00]);
			SndLen = ReadLE16(&TempPnt[0x02]);
			if (SndAddr > RAMPos && SndAddr < MinPos)
				MinPos = (UINT16)SndAddr;
			// TempPnt[0x04] seems to activate something
			// (it gets copied to 1FFE and is read from there),
			// but it's always zero, so I'll ignore it for now.
			
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Flags |= 0x10;
				if (SndAddr >= RAMSize)
				{
					TempSnd->Z80WarnAddr = SndAddr;
					TempSnd->Flags |= 0x80;
					continue;
				}
				//TempSnd->CommentStr = "Sound from Z80 RAM";
			}
			else
			{
				SndAddr &= 0x7FFF;
				if (Mode == 0x06)
					SndAddr += BnkBase;
				else //if (Mode == 0x22)
					SndAddr |= BnkBase + (RAMData[BnkTblBase + CurSnd] << 15);
			}
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x0B];
			TempSnd->Pan = TempPnt[0x0A];
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x07:	// Ristar
		DACLib.RateStr = "Ristar";
		DACLib.BaseCycles = 429;
		DACLib.LoopCycles = 0;
		DACLib.LoopSamples = 1;
		DACLib.Flags = 0x02;
		
		RAMPos = DacTblBase;
		TempSnd = &DACLib.Snds[0x80];
		TempSnd->CommentStr = "Sound from Z80 RAM";
		for (CurSnd = 0x80; CurSnd < 0xFF; CurSnd ++, TempSnd ++, RAMPos += 0x08)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			// use Z80 RAM
			TempSnd->Flags |= 0x10;
			TempPnt = &RAMData[RAMPos];
			if (TempPnt[0x04] || TempPnt[0x05])
				break;
			
			SndAddr = ReadLE16(&TempPnt[0x00]);
			SndLen = ReadLE16(&TempPnt[0x02]);
			if (SndAddr >= RAMSize)
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x80;
				continue;
			}
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = 0x10;
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		
		ROMPos = BnkTblBase;
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x7F; CurSnd ++, TempSnd ++, ROMPos += 0x10)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			// use Bank
			TempPnt = &ROMData[ROMPos];
			if (TempPnt[0x08] || TempPnt[0x0C])
				break;
			
			SndAddr = ReadBE32(&TempPnt[0x00]);
			SndLen = ReadBE32(&TempPnt[0x04]);
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = 0x10;
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		
		break;
	case 0x08:	// DAC Voices:	Magical Taruruuto-Kun / Mighty Morphin Power Rangers - The Movie
				//				Fatal Fury 1/2 / MJ's Moonwalker
		DACLib.RateStr = "SMPS 68k";
		DACLib.BaseCycles = 425;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x11;
		
		BnkBase = DacTblBase;
		
		TempSnd = DACLib.Snds;
		CurSnd = 0x00;
		CurBnk = 0x00;
		BnkSnd = 0x00;
		RAMPos = 0x0000;
		while(BnkBase < ROMLength)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &ROMData[BnkBase];
			if (TempPnt[0x04] || TempPnt[0x07])
				break;
			if (! TempPnt[0x0B] && ! TempPnt[0x03])
				break;
			
			BnkSnd = 0x00;		// disable this for MMPR-TM
			RAMPos = 0x0000;	// disable this for MMPR-TM
			MinPos = 0x7FFF;
			for (; CurSnd < 0x7F; CurSnd ++, TempSnd ++, BnkSnd ++, RAMPos += 0x0C)
			{
				if (SONG_COUNT && CurSnd >= SONG_COUNT)
					break;
				if (RAMPos >= MinPos)
					break;
				
				TempPnt = &ROMData[BnkBase + RAMPos];
				if (TempPnt[0x04] >= 0x01 && TempPnt[0x04] <= 0x80)
					break;
				if (! TempPnt[0x04] && (TempPnt[0x05] & 0x7F))
					break;
				
				SndAddr = ReadLE16(&TempPnt[0x00]);
				SndLen = ReadLE16(&TempPnt[0x02]);
				if (SndAddr & 0x8000)
				{
					// use sound from Z80 RAM - seen in Magical Taruruuto-Kun
					TempSnd->CommentStr = "Sound from Z80 RAM";
					TempSnd->Flags |= 0x10;
					
					SndAddr &= 0x7FFF;
					if (SndAddr >= RAMSize)
					{
						TempSnd->Z80WarnAddr = SndAddr;
						TempSnd->Flags |= 0x80;
						continue;
					}
				}
				else
				{
					if (SndAddr < MinPos)
						MinPos = (UINT16)SndAddr;
					SndAddr += BnkBase;
				}
				
				TempSnd->BankID = CurBnk;
				TempSnd->SndID = BnkSnd;
				
				TempSnd->Pos = SndAddr;
				TempSnd->Len = SndLen;
				TempSnd->Pitch = TempPnt[0x0B];
				TempSnd->Pan = TempPnt[0x0A];
				TempSnd->Unknown = TempPnt[0x05];
			}
			
			CurBnk ++;
			BnkBase += 0x8000;
		}
		BnkCnt = CurBnk;
		break;
	case 0x09:	// Sonic 2 Clone Driver + jman2050 DAC [GenesisFan64 Mod]
		DACLib.RateStr = "jman2050";
		DACLib.BaseCycles = 233;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x02;
		
		ROMPos = DacTblBase;
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, ROMPos += 0x10)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &ROMData[ROMPos];
			if (TempPnt[0x00] || TempPnt[0x04])
				break;
			if (! TempPnt[0x01] && ! TempPnt[0x02])
				continue;	// there are lots of unused entries, somehow
			
			BnkBase = ReadBE32(&TempPnt[0x00]);
			SndAddr = ReadBE32(&TempPnt[0x04]);
			SndLen = ReadBE16(&TempPnt[0x08]) << 1;
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x0C];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x0A:	// Sonic 2 Clone Driver + jman2050 DAC [MarkeyJester Mod]
		DACLib.RateStr = "jman2050";
		DACLib.BaseCycles = 233;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x02;
		
		if (ROMData[DacTblBase + 0x07])
			CurBnk = 0x00;
		else
			CurBnk = 0x01;
		
		ROMPos = DacTblBase;
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, ROMPos += 0x08)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &ROMData[ROMPos];
			if (CurBnk)
			{
				// new version
				if ((TempPnt[0x05] & 0x7F) || TempPnt[0x07] || ! TempPnt[0x01])
					break;
				
				SndAddr = ReadLE16(&TempPnt[0x00]);
				SndLen = ReadLE16(&TempPnt[0x02]);
				SndLen = (SndLen + 1) << 1;
				
				if (! (SndAddr & 0x8000))
				{
					if (SndAddr >= RAMSize)
					{
						TempSnd->Z80WarnAddr = SndAddr;
						TempSnd->Flags |= 0x80;
						continue;
					}
					//TempSnd->CommentStr = "Sound from Z80 RAM";
				}
				else
				{
					SndAddr &= 0x7FFF;
					SndAddr |= (TempPnt[0x05] & 0x80) << 8;
					SndAddr |= TempPnt[0x06] << 16;
				}
				
				TempSnd->Pos = SndAddr;
				TempSnd->Len = SndLen;
				TempSnd->Pitch = TempPnt[0x04];
				TempSnd->Pan = 0x00;
			}
			else
			{
				// old version
				if (TempPnt[0x04] || (TempPnt[0x06] & 0x7F) || ! TempPnt[0x07])
					break;
				
				SndAddr = ReadBE16(&TempPnt[0x00]);
				SndLen = ReadBE16(&TempPnt[0x02]) << 1;
				if (! (SndAddr & 0x8000))
				{
					if (SndAddr >= RAMSize)
					{
						TempSnd->Z80WarnAddr = SndAddr;
						TempSnd->Flags |= 0x80;
						continue;
					}
					//TempSnd->CommentStr = "Sound from Z80 RAM";
				}
				else
				{
					SndAddr &= 0x7FFF;
					SndAddr |= (TempPnt[0x06] & 0x80) << 8;
					SndAddr |= (TempPnt[0x07] << 16);
				}
				
				TempSnd->Pos = SndAddr;
				TempSnd->Len = SndLen;
				TempSnd->Pitch = TempPnt[0x05];
				TempSnd->Pan = 0x00;
			}
		}
		break;
	case 0x0B:	// Virtua Racing Deluxe 32X
		DACLib.RateStr = "SMPS 32x/68k";
		DACLib.BaseCycles = 437;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x03;
		
		RAMPos = DacTblBase;
		
		MinPos = 0x2000;
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, RAMPos += 0x02)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if (RAMPos >= MinPos)
				break;
			
			TempPnt = &RAMData[RAMPos];
			ROMPos = ReadLE16(&TempPnt[0x00]);
			if (ROMPos >= 0x2000 && ROMPos <= 0x7FFF)
				break;
			if (MinPos > ROMPos)
				MinPos = ROMPos;
			
			TempPnt = &RAMData[ROMPos];
			
			BnkBase &= 0x800000;	// keep bit 23
			BnkBase |= TempPnt[0x01] << 15;
			SndAddr = ReadLE16(&TempPnt[0x04]);
			SndLen = ReadLE16(&TempPnt[0x02]);
			
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x90;
				continue;
			}
			SndAddr &= 0x7FFF;
			SndAddr |= BnkBase;
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x00];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x0C:	// OutRunners, Virtua Fighter 2
		DACLib.RateStr = "OutRunners";
		DACLib.BaseCycles = 665;
		DACLib.LoopCycles = 0;
		DACLib.LoopSamples = 1;
		DACLib.Flags = 0x00;
		
		RAMPos = DacTblBase;
		
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, RAMPos += 0x05)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &RAMData[RAMPos];
			
			//if (TempPnt[0x04] < 0x04 || TempPnt[0x04] >= 0x10)
			//	break;
			if (! TempPnt[0x04] || (TempPnt[0x04] & 0x80))
				break;
			
			SndAddr = ReadLE16(&TempPnt[0x00]);
			SndLen = ReadLE16(&TempPnt[0x02]);
			CurBnk = TempPnt[0x04];
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x80;
				continue;
			}
			SndAddr &= 0x7FFF;
			SndAddr |= BnkBase | (CurBnk << 15);
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = 0x20;
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x0D:	// Mighty Morphin Power Rangers / Viewpoint
		// SMPS Z80 Type 2 games with FM drums
		DACLib.RateStr = "SMPS Z80 FM Type 2";
		DACLib.BaseCycles = 293;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x11;
		
		BnkBase = DacTblBase;
		if (BnkTblBase)
			BnkCnt = ReadCmpJumpTable_BnkCount(RAMData, BnkTblBase);
		else
			BnkCnt = (ROMLength - BnkBase) >> 15;
		printf("DAC Banks: %02X\n", BnkCnt);
		
		TempSnd = DACLib.Snds;
		CurSnd = 0x00;
		for (CurBnk = 0x00; CurBnk < BnkCnt; CurBnk ++)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			if (BnkTblBase)
			{
				// set new ROM Bank
				RAMPos = ReadCmpJumpTable(RAMData, BnkTblBase, CurBnk);
				BnkBase &= 0x7FFF;
				BnkBase |= ReadBankSwitchCode(RAMData, RAMPos) << 15;
			}
			printf("Bank: %02X, Offset: %06X\n", CurBnk, BnkBase);
			ROMPos = ReadLE16(&ROMData[BnkBase]);
			if (! (ROMPos & 0x8000) || ROMPos == 0xFFFF)
			{
				BnkCnt = CurBnk;
				break;
			}
			
			BnkSnd = 0x00;
			RAMPos = 0x0000;
			MinPos = 0x7FFF;
			for (; CurSnd < 0xFF; CurSnd ++, TempSnd ++, BnkSnd ++, RAMPos += 0x02)
			{
				if (SONG_COUNT && CurSnd >= SONG_COUNT)
					break;
				if (RAMPos >= MinPos)
					break;
				
				TempPnt = &ROMData[BnkBase + RAMPos];
				if (! (TempPnt[0x01] & 0x80))
					break;
				
				ROMPos = ReadLE16(&TempPnt[0x00]) & 0x7FFF;
				if (ROMPos < MinPos)
					MinPos = (UINT16)ROMPos;
				ROMPos |= BnkBase & ~0x7FFF;	// has to be '|' for ATP Tour Championship Tennis
				TempPnt = &ROMData[ROMPos];
				if (! (TempPnt[0x04] & 0x80))
					break;
				
				SndAddr = ReadLE16(&TempPnt[0x03]);
				SndLen = ReadLE16(&TempPnt[0x01]);
				if (! (SndAddr & 0x8000))
				{
					TempSnd->Z80WarnAddr = SndAddr;
					TempSnd->Flags |= 0x80;
					continue;
				}
				SndAddr &= 0x7FFF;
				//SndAddr += BnkBase;	// must be +, not | TODO: for which game?
				SndAddr |= BnkBase & ~0x7FFF;	// has to be '|' for ATP Tour Championship Tennis
				
				TempSnd->BankID = CurBnk;
				TempSnd->SndID = BnkSnd;
				
				TempSnd->Pos = SndAddr;
				TempSnd->Len = SndLen;
				if (! SndLen)
				{
					//TempSnd->CommentStr = "Invalid sound";
					//TempSnd->Flags |= 0x80;
				}
				TempSnd->Pitch = TempPnt[0x00];
				TempSnd->Pan = 0x00;
				TempSnd->Unknown = 0x00;
				if (TempSnd->Pitch & 0x80)
				{
					TempSnd->Pitch &= 0x7F;
					TempSnd->Unknown = 1;
				}
			}
			BnkBase += 0x8000;
		}
		break;
	case 0x0E:	// Mazin Saga, Battletoads, other SMPS Z80 Type 1
		// Note: Mazin Saga itself has a custom DAC loop.
		DACLib.RateStr = "SMPS Z80";
		DACLib.BaseCycles = 341;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x00;
		
		ROMPos = DacTblBase;
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, ROMPos += 0x06)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &ROMData[ROMPos];
			if (! (TempPnt[0x01] & 0x80) || (TempPnt[0x05] & 0x3E))
				break;
			
			SndAddr = ReadLE16(&TempPnt[0x00]);
			SndLen = ReadLE16(&TempPnt[0x02]);
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x80;
				continue;
			}
			SndAddr &= 0x7FFF;
			SndAddr |= (ROMPos & 0xFF8000);
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x04];
			TempSnd->Pan = TempPnt[0x05] & 0xFE;
			if (! (TempPnt[0x05] & 0x01))
				TempSnd->Flags |= 0x01;	// compressed sound
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x10:	// Streets of Rage / A Ressha de Gyoukou MD
		DACLib.RateStr = "Streets of Rage";	// TODO: Find actual rate
		DACLib.BaseRate = 274262;
		DACLib.RateDiv = 1535;
		DACLib.Flags = 0x01;	// Note: actually uses a custom compression
		
		RAMPos = (UINT16)DacTblBase;
		
		MinPos = 0x1FFF;
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, RAMPos += 0x05)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if (RAMPos >= MinPos)
				break;
			
			TempPnt = &RAMData[RAMPos];
			if ((TempPnt[0x01] & 0x80) || (TempPnt[0x04] & 0x80))
				break;
			
			SndAddr = ReadLE16(&TempPnt[0x00]);
			SndLen = ReadLE16(&TempPnt[0x02]);
			if (SndAddr < MinPos)
				MinPos = (UINT16)SndAddr;
			
			TempSnd->Flags |= 0x10;
			if (SndAddr >= RAMSize)
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x80;
				continue;
			}
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x04];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		if (! BnkTblBase)
			break;
		ROMPos = BnkTblBase;
		
		TempSnd->CommentStrB = "Sounds in ROM Bank:";
		MinPos = 0x7FFF;
		for (; CurSnd < 0x5F; CurSnd ++, TempSnd ++, ROMPos += 0x05)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if ((ROMPos & 0x7FFF) >= MinPos)
				break;
			
			TempPnt = &ROMData[ROMPos];
			if ((TempPnt[0x01] & 0x80) || (TempPnt[0x04] & 0x80))
				break;
			
			SndAddr = ReadLE16(&TempPnt[0x00]);
			SndLen = ReadLE16(&TempPnt[0x02]);
			
			SndAddr &= 0x7FFF;
			if (SndAddr < MinPos)
				MinPos = (UINT16)SndAddr;
			SndAddr |= (ROMPos & 0xFF8000);
			//if (ROMPos < MinPos)
			//	MinPos = (UINT16)ROMPos;
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x04];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x11:	// SM1bM 4
		DACLib.RateStr = "jman2050";
		DACLib.BaseCycles = 233;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x02;
		
		ROMPos = DacTblBase;
		
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, ROMPos += 0x04)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &ROMData[ROMPos];
			if (! TempPnt[0x00])
				break;
			
			CurBnk = TempPnt[0x01] - 1;
			TempPnt = &ROMData[BnkTblBase + CurBnk * 0x10];
			SndAddr = ReadBE32(&TempPnt[0x00]);
			SndLen = ReadBE32(&TempPnt[0x04]);
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = ROMData[ROMPos + 0x02];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		
		// Convert RF5C164's PCM data to usual unsigned 8-bit PCM
		// Note: This is not the "correct" conversion, but it reverts the
		//       sound data back to the data in SM1M3.
		for (ROMPos = 0x00; ROMPos < ROMLength; ROMPos ++)
		{
			if (! (ROMData[ROMPos] & 0x80))
				ROMData[ROMPos] = 0x7F - (ROMData[ROMPos] & 0x7F);
		}
		break;
	case 0x12:	// Golden Axe III
		DACLib.RateStr = "Golden Axe III";	// Note: uses 
		DACLib.BaseRate = 274262;
		DACLib.RateDiv = 1535;
		DACLib.Flags = 0x00;
		
		ROMPos = DacTblBase;
		
		MinPos = 0x7FFF;
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, ROMPos += 0x05)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if ((ROMPos & 0x7FFF) >= MinPos)
				break;
			
			TempPnt = &ROMData[ROMPos];
			if ((TempPnt[0x01] & 0x80) || (TempPnt[0x04] & 0x80))
				break;
			
			SndAddr = ReadLE16(&TempPnt[0x03]);
			SndLen = ReadLE16(&TempPnt[0x00]);
			SndAddr += ROMPos;
			if ((SndAddr & 0x7FFF) < MinPos)
				MinPos = (UINT16)SndAddr & 0x7FFF;
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x02];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x13:	// PsychoSk8r DAC driver
		DACLib.RateStr = "PsychoSk8r";
		DACLib.BaseCycles = 300;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x02;
		
		ROMPos = DacTblBase;
		
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, ROMPos += 0x0C)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &ROMData[ROMPos];
			if (TempPnt[0x00] || TempPnt[0x04])
				break;
			
			SndAddr = ReadBE32(&TempPnt[0x00]);
			SndLen = ReadBE32(&TempPnt[0x04]);
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x08];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = TempPnt[0x0A];
			TempSnd->Flags |= (TempPnt[0x09] & 0x01) << 0;
		}
		break;
	case 0x14:	// The Hybrid Front
		// basically Mighty Morphin Power Rangers / Viewpoint with seperate bank table
		DACLib.RateStr = "The Hybrid Front";
		DACLib.BaseCycles = 270;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x01;
		
		ROMPos = BnkTblBase;
		RAMPos = DacTblBase;
		BnkCnt = 0x00;
		
		MinPos = RAMPos;
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x7F; CurSnd ++, TempSnd ++, RAMPos += 0x05, ROMPos ++)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if (ROMPos >= MinPos)
				break;
			
			CurBnk = RAMData[ROMPos];
			if (CurBnk & ~0x01)
				break;
			if (CurBnk)
				TempSnd->CommentStr = "uses Bank 1";
			if (BnkCnt <= CurBnk)
				BnkCnt = CurBnk + 1;
			
			TempPnt = &RAMData[RAMPos];
			if (! (TempPnt[0x04] & 0x80))
				break;
			
			SndAddr = ReadLE16(&TempPnt[0x03]);
			SndLen = ReadLE16(&TempPnt[0x01]);
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x80;
				continue;
			}
			SndAddr &= 0x7FFF;
			SndAddr |= BnkBase | (CurBnk << 15);
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			if (! SndLen)
			{
				//TempSnd->CommentStr = "Invalid sound";
				//TempSnd->Flags |= 0x80;
			}
			TempSnd->Pitch = TempPnt[0x00];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x15:	// Virtua Racing
		DACLib.RateStr = "Virtua Racing";
		DACLib.BaseCycles = 528;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x01;
		
		RAMPos = DacTblBase;
		
		MinPos = 0x1FFF;
		TempSnd = DACLib.Snds;
		BnkSnd = 0x00;
		for (CurSnd = 0x00; CurSnd < 0x7F; CurSnd ++, TempSnd ++, RAMPos += 0x08)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if (RAMPos >= MinPos)
				break;
			
			TempPnt = &RAMData[RAMPos];
			if (TempPnt[0x00] != 0x80 || TempPnt[0x06] != 0x80)
				break;
			
			SndAddr = ReadLE16(&TempPnt[0x02]);
			SndLen = ReadLE16(&TempPnt[0x04]);
			if (SndAddr < MinPos)
				MinPos = (UINT16)SndAddr;
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Flags |= 0x10;
				if (SndAddr >= RAMSize)
				{
					TempSnd->Z80WarnAddr = SndAddr;
					TempSnd->Flags |= 0x80;
					continue;
				}
				if (SndAddr == 0x1E80)
				{
					//break;	// SFX sounds that are streamed by the 68k begin here
					if (! BnkSnd)
						BnkSnd = CurSnd;
					SndAddr = ReadBE32(&ROMData[BnkTblBase + (CurSnd - BnkSnd) * 0x08]);
					TempSnd->Flags &= ~0x10;
				}
			}
			else
			{
				SndAddr &= 0x7FFF;
				SndAddr |= BnkBase;
			}
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			if (! SndLen)
			{
				//TempSnd->CommentStr = "Invalid sound";
			}
			TempSnd->Pitch = TempPnt[0x07];
			TempSnd->Pan = 0xC0;	// the driver sends a 1B6 C0 when playing a DAC sound
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x16:	// Rent A Hero / Street Fighter 2 Turbo Beta (common preSMPS 68k)
		DACLib.RateStr = "preSMPS 68k";
		DACLib.BaseCycles = 596;
		DACLib.LoopCycles = 13;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x10;
		
		ROMPos = BnkTblBase;
		
		TempSnd = DACLib.Snds;
		CurSnd = 0x00;
		CurBnk = 0x00;
		while(ROMPos < ROMLength)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &ROMData[ROMPos];
			if (TempPnt[0x04])
				break;
			
			BnkBase = ReadBE32(&TempPnt[0x00]);
			SndAddr = ReadBE32(&TempPnt[0x04]);
			ROMPos += 0x04;
			if (! BnkBase || BnkBase == SndAddr)
			{
				CurBnk ++;
				continue;
			}
			
			BnkBase -= 0x0200;	// data gets copies to Z80 RAM offset 0200
			RAMPos = (UINT16)DacTblBase;
			MinPos = ReadLE16(&ROMData[BnkBase + RAMPos]);
			RAMPos += 0x02;
			BnkSnd = 0x00;
			for (; CurSnd < 0x7F; CurSnd ++, TempSnd ++, BnkSnd ++, RAMPos += 0x02)
			{
				if (SONG_COUNT && CurSnd >= SONG_COUNT)
					break;
				if (RAMPos >= MinPos)
					break;
				
				TempPnt = &ROMData[BnkBase + MinPos + BnkSnd * 0x04];
				
				SndAddr = ReadLE16(&TempPnt[0x02]);
				SndLen = ReadLE16(&TempPnt[0x00]);
				if (! SndAddr)
				{
					CurSnd --;
					TempSnd --;
					continue;
				}
				if (SndAddr & 0x8000)
				{
					TempSnd->Z80WarnAddr = SndAddr;
					TempSnd->Flags |= 0x80;
					continue;
				}
				SndAddr += BnkBase;
				//TempSnd->Flags |= 0x10;	// actually Z80 RAM, but I store ROM offsets
				
				TempSnd->BankID = CurBnk;
				TempSnd->SndID = BnkSnd;
				
				TempSnd->Pos = SndAddr;
				TempSnd->Len = SndLen;
				SndLen = ReadLE16(&ROMData[BnkBase + RAMPos]);	// get address of pitch value
				TempSnd->Pitch = ROMData[BnkBase + SndLen];
				TempSnd->Pan = 0x00;
				TempSnd->Unknown = 0x00;
				// Street Fighter 2 Turbo Beta supports uncompressed sounds
				if (DacTblBase <= 0x0200 || ROMData[BnkBase + 0x0200] != 0xFF)
					TempSnd->Flags |= 0x01;	// compressed sound
			}
			
			CurBnk ++;
		}
		BnkCnt = CurBnk;
		break;
	case 0x17:	// vladikcomper's MegaPCM
		DACLib.RateStr = "MegaPCM";
		DACLib.BaseCycles = 235;	// PCM: 123+13x, DPCM: 223+26x
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x00;
		
		RAMPos = DacTblBase;
		
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x7F; CurSnd ++, TempSnd ++, RAMPos += 0x08)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &RAMData[RAMPos];
			if (TempPnt[0x00] & 0x38)	// check for invalid bits
				break;
			//if (! (TempPnt[0x05] & 0x80) || ! (TempPnt[0x07] & 0x80))
			//	break;
			
			SndAddr = ReadLE16(&TempPnt[0x04]);	// Z80 Start Offset
			SndLen = ReadLE16(&TempPnt[0x06]);	// Z80 End Offset
			if (! (SndAddr & 0x8000))
			{
				if (SndAddr || SndLen)	// don't set Error flag for NULL sounds
				{
					TempSnd->Z80WarnAddr = SndAddr;
					TempSnd->Flags |= 0x80;
				}
				else
				{
					TempSnd->Pos = 0x0000;
					TempSnd->Len = 0x0000;
					TempSnd->Pitch = TempPnt[0x01];
					TempSnd->Pan = 0x00;
				}
				continue;
			}
			SndAddr &= 0x7FFF;
			SndLen &= 0x7FFF;
			
			SndAddr |= (TempPnt[0x02] << 15);
			BnkBase = (TempPnt[0x03] << 15) | SndLen;
			BnkBase ++;	// it points to the last sample to play
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = BnkBase - SndAddr;
			TempSnd->Pitch = TempPnt[0x01];
			TempSnd->Pan = TempPnt[0x00] & 0xC0;
			if (TempPnt[0x00] & 0x04)
				TempSnd->Flags |= 0x01;	// compressed sound
			TempSnd->Unknown = TempPnt[0x00] & ~0xC4;
		}
		break;
	case 0x19:	// Sonic 3D Blast/Sonic & Knuckles
		DACLib.RateStr = "Sonic 3/K/3D";
		DACLib.BaseCycles = 297;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x01;
		
		ROMPos = DacTblBase;
		RAMPos = BnkTblBase;
		
		TempSnd = DACLib.Snds;
		MinPos = 0xFFFF;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, RAMPos ++, ROMPos += 0x02)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if (ROMPos >= MinPos)
				break;
			BnkBase = RAMData[RAMPos] << 15;
			
			if (ROMPos & 0x8000)
			{
				if (BnkBase >= ROMLength && BnkBase < 0x00400000)
				{
					TempSnd->Pos = 0x00;
					TempSnd->Len = 0x0000;
					TempSnd->Pitch = 0x00;
					TempSnd->Pan = 0x00;
					TempSnd->Unknown = 0x00;
					continue;	// handle vanilla Sonic & Knuckles
				}
				
				TempPnt = &ROMData[BnkBase | (ROMPos & 0x7FFF)];
				if (! (TempPnt[0x01] & 0x80))
					break;
			}
			else
			{
				TempPnt = &RAMData[ROMPos];
				if (TempPnt[0x01] & 0x80)
					break;
			}
			
			SndAddr = ReadLE16(&TempPnt[0x00]);
			if (SndAddr < MinPos)
				MinPos = (UINT16)SndAddr;
			if (SndAddr & 0x8000)
				TempPnt = &ROMData[BnkBase | (SndAddr & 0x7FFF)];
			else
				TempPnt = &RAMData[SndAddr];
			
			SndAddr = ReadLE16(&TempPnt[0x03]);
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x90;
				continue;
			}
			SndAddr &= 0x7FFF;
			SndAddr |= (BnkBase & 0xFF8000);
			SndLen = ReadLE16(&TempPnt[0x01]);
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x00];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x1A:	// Sonic 2 Clone Driver + jman2050 DAC [Aquaslash Mod]
		DACLib.RateStr = "jman2050";
		DACLib.BaseCycles = 233;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x02;
		
		ROMPos = DacTblBase;
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, ROMPos += 0x10)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &ROMData[ROMPos];
			if (TempPnt[0x00] || TempPnt[0x04])
				break;
			if (! TempPnt[0x01] && ! TempPnt[0x02])
				continue;	// there are lots of unused entries, somehow
			
			BnkBase = ReadBE32(&TempPnt[0x00]);
			SndAddr = ReadBE32(&TempPnt[0x04]);
			SndLen = ReadBE16(&TempPnt[0x08]) << 1;
			if (ROMData[SndAddr + SndLen - 1] == 0x00)
				SndLen --;
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x0A];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x1B:	// Bishoujo Senshi Sailor Moon
		DACLib.RateStr = "Bishoujo Senshi Sailor Moon";
		DACLib.BaseCycles = 394;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x01;
		
		RAMPos = DacTblBase;
		TempSnd = DACLib.Snds;
		MinPos = 0xFFFF;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, RAMPos += 0x02)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if (RAMPos >= MinPos)
				break;
			
			TempPnt = &RAMData[RAMPos];
			if (TempPnt[0x01] >= 0x20 && TempPnt[0x01] < 0x80)
				break;
			
			ROMPos = ReadLE16(&TempPnt[0x00]);
			if (ROMPos < MinPos)
				MinPos = (UINT16)ROMPos;
			TempPnt = &RAMData[ROMPos];
			
			SndAddr = ReadLE16(&TempPnt[0x00]);
			SndLen = ReadLE16(&TempPnt[0x02]);
			BnkBase = (TempPnt[0x05] & 0x7F) << 15;
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Flags |= 0x10;
				if (SndAddr >= RAMSize)
				{
					TempSnd->Z80WarnAddr = SndAddr;
					TempSnd->Flags |= 0x80;
					continue;
				}
				//TempSnd->CommentStr = "Sound from Z80 RAM";
			}
			else
			{
				SndAddr = (BnkBase & 0xFF8000) | (SndAddr & 0x7FFF);
			}
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x04];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x1C:	// Samurai Shodown
		DACLib.RateStr = "Samurai Shodown";
		DACLib.BaseCycles = 387;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x01;
		
		RAMPos = DacTblBase;
		
		TempSnd = DACLib.Snds;
		MinPos = 0xFFFF;
		for (CurSnd = 0x00; CurSnd < 0x7F; CurSnd ++, TempSnd ++, RAMPos += 0x08)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &RAMData[RAMPos];
			if (TempPnt[0x01] & 0x80)
				break;
			
			SndAddr = ReadLE16(&TempPnt[0x00]);
			SndLen = ReadLE16(&TempPnt[0x02]);
			BnkBase = ReadLE16(&TempPnt[0x04]) << 8;
			if (SndAddr & 0x8000)
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x80;
				continue;
			}
			SndAddr |= (BnkBase & 0xFF8000);
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x07];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x1D:	// Knuckles' Chaotix
		DACLib.RateStr = "Stanard 32x PWM";
		DACLib.BaseRate = 22050;
		DACLib.RateDiv = 0;
		// 0x80 - use PWM frequency
		// no 0x02 - We're using SH-2 pointers, so the pointers don't need to be fixed.
		DACLib.Flags = 0x80;
		
		ROMPos = DacTblBase;
		
		TempSnd = DACLib.Snds;
		MinPos = 0xFFFF;
		for (CurSnd = 0x00; CurSnd < 0xFF; CurSnd ++, TempSnd ++, ROMPos += 0x10)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &ROMData[ROMPos];
			if (TempPnt[0x00] != 0x22 || TempPnt[0x04])
				break;
			
			SndAddr = ReadBE32(&TempPnt[0x00]) & 0x00FFFFFF;
			SndLen = ReadBE32(&TempPnt[0x04]);
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->PwmPitch = ReadBE32(&TempPnt[0x0C]);
			TempSnd->Pitch = TempSnd->PwmPitch >> 4;
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x1E:	// Visual Scene SEGA-CD Image
		// Note: These sounds are actually the drums for Wolfteam's sound driver.
		//       But they were part of that "Visual Scene" ROM (ripped from Earnest Evans)
		//       that contained SMPS data, so it ended up here.
		DACLib.RateStr = "Wolfteam";
		DACLib.BaseCycles = 293;	// TODO: find actual rate
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x10;
		
		BnkBase = DacTblBase;
		BnkCnt = 2;
		
		TempSnd = DACLib.Snds;
		CurSnd = 0x00;
		for (CurBnk = 0x00; CurBnk < BnkCnt; CurBnk ++)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &ROMData[BnkBase];
			if (TempPnt[0x02] || TempPnt[0x03])
			{
				BnkCnt = CurBnk;
				break;
			}
			
			BnkSnd = 0x00;
			ROMPos = 0x0000;
			MinPos = 0x7FFF;
			for (; CurSnd < 0x7F; CurSnd ++, TempSnd ++, BnkSnd ++, ROMPos += 0x08)
			{
				if (SONG_COUNT && CurSnd >= SONG_COUNT)
					break;
				if (ROMPos >= MinPos)
					break;
				
				TempPnt = &ROMData[BnkBase + ROMPos];
				if (TempPnt[0x02])
					break;
				
				SndAddr = ReadBE16(&TempPnt[0x06]);
				SndLen = ReadBE16(&TempPnt[0x04]);
				if (SndAddr & 0x8000)
				{
					TempSnd->Z80WarnAddr = SndAddr;
					TempSnd->Flags |= 0x80;
					continue;
				}
				if (SndAddr < MinPos)
					MinPos = (UINT16)SndAddr;
				SndAddr += BnkBase;	// must be +, not |
				
				TempSnd->BankID = CurBnk;
				TempSnd->SndID = BnkSnd;
				
				TempSnd->Pos = SndAddr;
				TempSnd->Len = SndLen;
				if (! SndLen)
				{
					//TempSnd->CommentStr = "Invalid sound";
					//TempSnd->Flags |= 0x80;
				}
				TempSnd->Pitch = TempPnt[0x00];
				TempSnd->Pan = TempPnt[0x01];
				TempSnd->Unknown = 0x00;
			}
			
			BnkBase += 0x8000;
		}
		break;
	case 0x1F:	// Sonic 2 (Beta + Final)
		DACLib.RateStr = "Sonic 2 Final";
		DACLib.BaseCycles = 288;	// 288 - Final, 296 - Simon Wai Beta
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x01;
		
		RAMPos = DacTblBase;
		
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, RAMPos += 0x04)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &RAMData[RAMPos];
			if (! (TempPnt[0x01] & 0x80))
				break;
			
			SndAddr = ReadLE16(&TempPnt[0x00]);
			SndLen = ReadLE16(&TempPnt[0x02]);
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x80;
				continue;
			}
			SndAddr &= 0x7FFF;
			SndAddr |= (BnkBase & 0xFF8000);
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = 0x10;
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x20:	// Metal Head 32X, Shadow Squadron 32X
		DACLib.RateStr = "SMPS 32x/68k 2-channel";
		DACLib.BaseCycles = 1345;	// 1345 - Metal Head, 1105 - Shadow Squadron
		DACLib.LoopCycles = 0;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x03;
		
		RAMPos = DacTblBase;
		
		MinPos = 0x2000;
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, RAMPos += 0x02)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if (RAMPos >= MinPos)
				break;
			
			TempPnt = &RAMData[RAMPos];
			ROMPos = ReadLE16(&TempPnt[0x00]);
			if (ROMPos >= 0x2000 && ROMPos <= 0x7FFF)
				break;
			if (MinPos > ROMPos)
				MinPos = ROMPos;
			
			TempPnt = &RAMData[ROMPos];
			
			BnkBase &= 0x800000;	// keep bit 23
			BnkBase |= TempPnt[0x00] << 15;
			SndAddr = ReadLE16(&TempPnt[0x01]);
			SndLen = ReadLE16(&TempPnt[0x03]);
			
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x90;
				continue;
			}
			SndAddr &= 0x7FFF;
			SndAddr |= BnkBase;
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = 0x40;
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x21:	// Mercs
		DACLib.RateStr = "Mercs";
		DACLib.BaseCycles = 1102;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x01;
		
		ROMPos = DacTblBase;
		BnkBase = ROMPos & 0xFF8000;
		
		MinPos = 0x7FFF;
		TempSnd = DACLib.Snds;
		for (; CurSnd < 0x5F; CurSnd ++, TempSnd ++, ROMPos += 0x02)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if ((ROMPos & 0x7FFF) >= MinPos)
				break;
			
			TempPnt = &ROMData[ROMPos];
			if (! (TempPnt[0x01] & 0x80))
				break;
			SndAddr = ReadLE16(&TempPnt[0x00]);
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x90;
				continue;
			}
			
			SndAddr &= 0x7FFF;
			if (SndAddr < MinPos)
				MinPos = (UINT16)SndAddr;
			TempPnt = &ROMData[BnkBase | SndAddr];
			SndAddr = ReadLE16(&TempPnt[0x00]);
			SndLen = ReadLE16(&TempPnt[0x02]);
			
			SndAddr &= 0x7FFF;
			SndAddr |= BnkBase;
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x04];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x23:	// Ayrton Senna's Super Monaco GP II
		DACLib.RateStr = "Super Monaco GP II";
		DACLib.BaseCycles = 700;
		DACLib.LoopCycles = 13;
		DACLib.LoopSamples = 1;
		DACLib.Flags = 0x10;
		
		BnkBase = DacTblBase;
		
		TempSnd = DACLib.Snds;
		RAMPos = 0x0000;
		MinPos = 0x7FFF;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, RAMPos += BnkTblBase)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			if (RAMPos >= MinPos)
				break;
			
			TempPnt = &ROMData[BnkBase + RAMPos];
			if (TempPnt[0x02] || TempPnt[0x07])
			//if (TempPnt[0x0F])
				break;
			
			SndAddr = ReadLE16(&TempPnt[0x08]);
			SndLen = ReadLE16(&TempPnt[0x00]);
			//SndLen = ReadLE16(&TempPnt[0x04]) + 1;
			if (! (SndAddr & 0x8000))
			{
				TempSnd->CommentStr = "Sound from Z80 RAM";
				TempSnd->Flags |= 0x10;
				
				SndAddr &= 0x7FFF;
				if (SndAddr >= RAMSize)
				{
					TempSnd->Z80WarnAddr = SndAddr;
					TempSnd->Flags |= 0x80;
					continue;
				}
			}
			else
			{
				SndAddr &= 0x7FFF;
				if (SndAddr < MinPos)
					MinPos = (UINT16)SndAddr;
				SndAddr |= BnkBase;
			}
			
			TempSnd->BankID = 0x00;
			TempSnd->SndID = CurSnd;
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x06];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = TempPnt[0x0B];
		}
		break;
	case 0x24:	// Sega Pico ADPCM
		DACLib.RateStr = "Sega Pico PCM";
		DACLib.BaseRate = 0;	// The ADPCM chip does the sample rate itself and
		DACLib.RateDiv = 0;		// the driver only checks/fills the FIFO.
		DACLib.Flags = 0x40;
		
		ROMPos = DacTblBase;
		
		TempSnd = DACLib.Snds;
		MinPos = 0xFFFF;
		for (CurSnd = 0x00; CurSnd < 0xFF; CurSnd ++, TempSnd ++, ROMPos += 0x10)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &ROMData[ROMPos];
			if (TempPnt[0x0A] || TempPnt[0x0C])
				break;
			
			SndAddr = ReadBE32(&TempPnt[0x02]) & 0x00FFFFFF;
			SndLen = ReadBE32(&TempPnt[0x06]);
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x00];
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = TempPnt[0x01];
			if (TempSnd->Unknown)
				DACLib.Flags |= 0x01;
		}
		break;
	case 0x25:	// J. League Pro Striker DAC driver
		DACLib.RateStr = "J. League Pro Striker";
		DACLib.BaseCycles = 445;
		DACLib.LoopCycles = 17;
		DACLib.LoopSamples = 1;
		DACLib.Flags = 0x10;
		
		BnkBase = DacTblBase;
		ROMPos = BnkBase | (ReadLE16(&ROMData[BnkBase]) & 0x7FFF);
		MinPos = ReadLE16(&ROMData[ROMPos + 0x00]);
		MinPos += ReadLE16(&ROMData[ROMPos + 0x02]);
		RAMPos = ReadLE16(&ROMData[ROMPos + 0x04]);
		if (RAMPos == (MinPos + 0x01))
			CurLst = 3;	// Rev 03/Perfect Edition
		else
			CurLst = 0;	// Rev 00
		
		TempSnd = DACLib.Snds;
		CurSnd = 0x00;
		CurBnk = 0x00;
		BnkSnd = 0x00;
		RAMPos = 0x0000;
		while(BnkBase < ROMLength)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &ROMData[BnkBase];
			if (! (TempPnt[0x01] & 0x80))
				break;
			
			BnkSnd = 0x00;
			RAMPos = 0x0000;
			MinPos = 0x7FFF;
			if (TempPnt[0x00] + 0x05 == TempPnt[0x02])	// bank with music DAC drums (different format)
				MinPos = 0x0000;	// enforce bank skip
			for (; CurSnd < 0x7F; CurSnd ++, TempSnd ++, BnkSnd ++, RAMPos += 0x02)
			{
				if (SONG_COUNT && CurSnd >= SONG_COUNT)
					break;
				if (RAMPos >= MinPos)
					break;
				
				TempPnt = &ROMData[BnkBase + RAMPos];
				if (! (TempPnt[0x01] & 0x80))
					break;
				
				ROMPos = ReadLE16(&TempPnt[0x00]) & 0x7FFF;
				if (ROMPos < MinPos)
					MinPos = (UINT16)ROMPos;
				TempPnt = &ROMData[BnkBase + ROMPos];
				if (TempPnt[0x03] & 0x80)
					break;
				
				SndAddr = ReadLE16(&TempPnt[0x00]);
				SndLen = ReadLE16(&TempPnt[0x02]);
				if (! (SndAddr & 0x8000))
				{
					TempSnd->Z80WarnAddr = SndAddr;
					TempSnd->Flags |= 0x80;
					continue;
				}
				SndAddr &= 0x7FFF;
				SndAddr |= BnkBase;
				if (CurLst && SndLen)
					SndLen ++;
				
				TempSnd->BankID = CurBnk;
				TempSnd->SndID = BnkSnd;
				
				TempSnd->Pos = SndAddr;
				TempSnd->Len = SndLen;
				TempSnd->Pitch = CurLst ? 0x01 : 0x02;
				TempSnd->Pan = 0x00;
				TempSnd->Unknown = 0x00;
			}
			
			CurBnk ++;
			BnkBase += 0x8000;
		}
		BnkCnt = CurBnk;
		break;
	case 0x26:	// Wimbledon Championship Tennis (DAC Voices)
		DACLib.RateStr = "Wimbledon Championship Tennis";
		DACLib.BaseCycles = 339;
		DACLib.LoopCycles = 26;
		DACLib.LoopSamples = 2;
		DACLib.Flags = 0x11;
		
		BnkCnt = 0x00;
		RAMPos = BnkTblBase;
		ROMPos = DacTblBase;
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x7F; CurSnd ++, TempSnd ++, RAMPos += 0x03, ROMPos += 0x06)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			CurBnk = RAMData[RAMPos + 0x00];
			BnkBase = (ReadBE16(&RAMData[RAMPos + 0x01]) & 0xFF80) << 8;
			ROMPos &= 0x7FFF;
			ROMPos |= BnkBase;
			if (BnkBase >= ROMLength || ROMData[BnkBase + 0x0000] != CurBnk)
				break;
			TempPnt = &ROMData[ROMPos];
			if (! (TempPnt[0x01] & 0x80) || (TempPnt[0x05] & 0x3E))
				break;
			
			SndAddr = ReadLE16(&TempPnt[0x00]);
			SndLen = ReadLE16(&TempPnt[0x02]);
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x80;
				continue;
			}
			SndAddr &= 0x7FFF;
			SndAddr |= BnkBase;
			
			TempSnd->BankID = CurBnk;
			TempSnd->SndID = CurSnd;
			if (BnkCnt <= CurBnk)
				BnkCnt = CurBnk + 1;
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = TempPnt[0x04];
			TempSnd->Pan = TempPnt[0x05];
			TempSnd->Unknown = 0x00;
		}
		break;
	case 0x27:	// SMPS Z80/Gamtec
		DACLib.RateStr = "SMPS Z80/Gamtec";
		DACLib.BaseCycles = 210;
		DACLib.LoopCycles = 13;
		DACLib.LoopSamples = 1;
		DACLib.Flags = 0x00;
		
		ROMPos = DacTblBase;
		TempSnd = DACLib.Snds;
		for (CurSnd = 0x00; CurSnd < 0x5F; CurSnd ++, TempSnd ++, ROMPos += 0x06)
		{
			if (SONG_COUNT && CurSnd >= SONG_COUNT)
				break;
			
			TempPnt = &ROMData[ROMPos];
			if (! (TempPnt[0x04] & 0x80) || TempPnt[0x02])
				break;
			
			SndAddr = ReadBE16(&TempPnt[0x04]);
			SndLen = ReadBE16(&TempPnt[0x00]);	// actual length
			SndLen += ReadBE16(&TempPnt[0x02]);	// padding bytes?
			if (! (SndAddr & 0x8000))
			{
				TempSnd->Z80WarnAddr = SndAddr;
				TempSnd->Flags |= 0x80;
				continue;
			}
			SndAddr &= 0x7FFF;
			SndAddr |= (ROMPos & 0xFF8000);
			
			TempSnd->Pos = SndAddr;
			TempSnd->Len = SndLen;
			TempSnd->Pitch = 0x32;	// hardcoded into the driver
			TempSnd->Pan = 0x00;
			TempSnd->Unknown = 0x00;
		}
		break;
	}
	DACLib.SndCnt = CurSnd;
	if (! DACLib.SndCnt)
	{
		printf("Nothing to extract.\n");
		return 0x00;
	}
	
	if (DACLib.BaseCycles)
	{
		//printf("DAC loop cycles: (%hu + %hu*x) / %hu\n", 
		//		DACLib.BaseCycles, DACLib.LoopCycles, DACLib.LoopSamples);
		
		if (DACLib.LoopCycles)
		{
			DACLib.BaseRate = (3579545 * DACLib.LoopSamples + DACLib.LoopCycles / 2) / DACLib.LoopCycles;
			DACLib.RateDiv = (DACLib.BaseCycles * 100 + DACLib.LoopCycles / 2) / DACLib.LoopCycles - 100;
		}
		else
		{
			// handle games with constant sample rate
			MinPos = DACLib.Snds[0].Pitch * 100;
			DACLib.BaseRate = (3579545 * DACLib.LoopSamples + 6) / 13;
			DACLib.RateDiv = (DACLib.BaseCycles * 100 + 6) / 13 - MinPos;
		}
		//printf("BaseRate: %u, RateDiv: %hu\n", DACLib.BaseRate, DACLib.RateDiv);
	}
	
	if (SONG_BASE == 0xFF)
	{
		if (DACLib.SndCnt >= 0x60)
			SONG_BASE = 0x01;
		else
			SONG_BASE = 0x81;
	}
	
	if (ReadOnlyMode)
	{
		hFileINI = NULL;
	}
	else
	{
		_mkdir(DAC_NAMEBASE);
		sprintf(OutName, "%s.ini", DAC_NAMEBASE);
		hFileINI = fopen(OutName, "wt");
		if (hFileINI == NULL)
		{
			printf("Error opening %s!\n", OutName);
			return 0x04;
		}
		
		fprintf(hFileINI, "; Generated by SMPS Extractor\n\n");
		
		fprintf(hFileINI, "; %s DAC driver rates\n", DACLib.RateStr);
		fprintf(hFileINI, "BaseRate = %u\n", DACLib.BaseRate);
		fprintf(hFileINI, "RateDiv = %u.%02u\n", DACLib.RateDiv / 100, DACLib.RateDiv % 100);
		fprintf(hFileINI, "\n");
		if (DACLib.BaseCycles)
		{
			fprintf(hFileINI, "BaseCycles = %u\n", DACLib.BaseCycles);
			fprintf(hFileINI, "LoopCycles = %u\n", DACLib.LoopCycles);
			fprintf(hFileINI, "LoopSamples = %u\n", DACLib.LoopSamples);
			fprintf(hFileINI, "\n");
		}
	}
	
	if (DACLib.Flags & 0x10)
	{
		// BnkSnd - highest Sound ID in any bank
		// CurBnk - highest Bank ID
		BnkSnd = 0x00;
		CurBnk = 0x00;
		for (CurSnd = 0x00; CurSnd < DACLib.SndCnt; CurSnd ++, TempSnd ++)
		{
			if (BnkSnd < DACLib.Snds[CurSnd].SndID)
				BnkSnd = DACLib.Snds[CurSnd].SndID;
			if (CurBnk < DACLib.Snds[CurSnd].BankID)
				CurBnk = DACLib.Snds[CurSnd].BankID;
		}
		
		DigitsBnk = 1;
		while(CurBnk >= 0x10)
		{
			CurBnk >>= 4;
			DigitsBnk ++;
		}
		
		DigitsSnd = 1;
		while(BnkSnd >= 0x10)
		{
			BnkSnd >>= 4;
			DigitsSnd ++;
		}
	}
	memset(AddrLst, 0x00, 0x100 * sizeof(UINT32));
	
	// --- Step 3: Extract all sounds from information in DACLib. ---
	TempSnd = DACLib.Snds;
	printf("ID  Pos     Len\n");
	for (CurSnd = 0x00; CurSnd < DACLib.SndCnt; CurSnd ++, TempSnd ++)
	{
		if (! ReadOnlyMode)
		{
			if (TempSnd->CommentStrB != NULL)
				fprintf(hFileINI, "; %s\n", TempSnd->CommentStrB);
			
			fprintf(hFileINI, "[%02X]\n", (SONG_BASE + CurSnd) & 0xFF);
			
			if (TempSnd->Z80WarnAddr != 0xFFFF)
				fprintf(hFileINI, "; Warning: Sound is reading from invalid "
						"Z80 Offset %04X\n", TempSnd->Z80WarnAddr);
			if (TempSnd->CommentStr != NULL)
				fprintf(hFileINI, "; %s\n", TempSnd->CommentStr);
		}
		
		printf("%02X  ", (SONG_BASE + CurSnd) & 0xFF);
		if (TempSnd->Flags & 0x10)
			printf("  %04X", TempSnd->Pos);
		else
			printf("%06X", TempSnd->Pos);
		if (TempSnd->Len)
			printf("  %04X\n", TempSnd->Len);
		else
			printf("  ----\n", TempSnd->Len);
		
		if (TempSnd->Flags & 0x80)
			printf("Warning: Sound %02X is invalid!\n", (SONG_BASE + CurSnd) & 0xFF);
		if (ReadOnlyMode)
			continue;	// If we're just information, we're done with this sounds.
		
		if ((TempSnd->Flags & 0x80) || ! TempSnd->Pos)
		{
			// catch invalid and empty sounds
			fprintf(hFileINI, "\n");
			continue;
		}
		
		if (MarsMode && (DACLib.Flags & 0x02))
			FixMarsPointer(&TempSnd->Pos);
		
		if (TempSnd->Len)
			LstVal = (TempSnd->Pos << 12) | (TempSnd->Len << 0);
		else
			LstVal = -1;
		for (CurLst = 0x00; CurLst < 0xFF; CurLst ++)
		{
			if (! AddrLst[CurLst])
			{
				AddrLst[CurLst] = LstVal;
				AddrID[CurLst] = CurSnd;
				TempSnd2 = TempSnd;
				break;
			}
			else if (AddrLst[CurLst] == LstVal)
			{
				TempSnd2 = &DACLib.Snds[AddrID[CurLst]];
				break;
			}
		}
		
		if (TempSnd->Len)
		{
			if (! (DACLib.Flags & 0x10))
				sprintf(TempName, "DAC_%02X.bin", (SONG_BASE + AddrID[CurLst]) & 0xFF);
			else
				sprintf(TempName, "DAC_%0*X-%0*X.bin", DigitsBnk, TempSnd2->BankID,
						DigitsSnd, TempSnd2->SndID);
		}
		else
		{
			strcpy(TempName, "DAC_null.bin");
		}
		
		if (TempSnd2 == TempSnd)
		{
			sprintf(OutName, "%s/%s", DAC_NAMEBASE, TempName);
			hFile = fopen(OutName, "wb");
			if (hFile == NULL)
			{
				printf("Can't write %s!\n", TempName);
			}
			else
			{
				if (TempSnd->Flags & 0x10)
					fwrite(RAMData + TempSnd->Pos, 0x01, TempSnd->Len, hFile);
				else if (TempSnd->Pos < ROMLength)
					fwrite(ROMData + TempSnd->Pos, 0x01, TempSnd->Len, hFile);
				
				fclose(hFile);
			}
		}
		
		if (DACLib.Flags & 0x40)
		{
			fprintf(hFileINI, "Compr = %s\n", "PCM");
			fprintf(hFileINI, "File = %s\\%s\n", DAC_NAMEBASE, TempName);
			fprintf(hFileINI, "Param1 = 0x%02X\n", TempSnd->Pitch);
			if (DACLib.Flags & 0x01)
				fprintf(hFileINI, "Param2 = 0x%02X\n", TempSnd->Unknown);
		}
		else
		{
			//fprintf(hFileINI, "Compr = %s\n", ((DACLib.Flags | TempSnd->Flags) & 0x01) ? "True" : "False");
			fprintf(hFileINI, "Compr = %s\n", ((DACLib.Flags | TempSnd->Flags) & 0x01) ? "DPCM" : "PCM");
			fprintf(hFileINI, "File = %s\\%s\n", DAC_NAMEBASE, TempName);
			if (1 && (DACLib.Flags & 0x80))
				fprintf(hFileINI, "Rate = 0x%04X\n", TempSnd->PwmPitch);
			else
				fprintf(hFileINI, "Rate = 0x%02X\n", TempSnd->Pitch);
			if (TempSnd->Pan)
				fprintf(hFileINI, "Pan = 0x%02X\n", TempSnd->Pan);
			if (TempSnd->Unknown)
				fprintf(hFileINI, ";Unknown = 0x%02X\n", TempSnd->Unknown);
		}
		fprintf(hFileINI, "\n");
	}
	if (hFileINI != NULL)
		fclose(hFileINI);
	
	printf("%02X Sound%s extracted.\n", DACLib.SndCnt, (DACLib.SndCnt == 1) ? "" : "s");
	
	return 0x00;
}
