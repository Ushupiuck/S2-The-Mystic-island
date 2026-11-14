// SMPS Song Extractor
// -------------------
// Written by Valley Bell

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <memory.h>
#include <string.h>
#include <direct.h>
#include "stdtype.h"

#include "ReadFuncs.h"
#include "SongExtract.h"

typedef struct song_list
{
	UINT32 Pos;
	UINT32 Len;
} SONG_LIST;

static UINT32 GetMDZ80Ptr(UINT16 Z80Addr, UINT32 BankBaseOfs);
static UINT32 GetMSZ80Ptr(UINT16 Z80Addr);
static UINT32 GuessSongCount(UINT8 Mode, UINT32 MusPtrList, UINT32 BankList,
							UINT8* RetBankMode, UINT32 BankBase);
//void ExtractSongs(UINT32 MusPtrList, UINT8 Mode, UINT16 BankList);
static UINT32 GetNextAddr(UINT16 SongCnt, const SONG_LIST* SongLst, UINT32 Address);
static UINT32 GuessSMPSEnd(SONG_LIST* SongLst);
void SetSMSBankMap(const char* BMapStr);
static void PatchSongData(UINT32* SongAddr, UINT8* songBuffer, UINT32 baseAddr);

#define BNKM_FULL	0x00	// all 8 bits are used, absolute
#define BNKM_LOWB	0x01	// only bit 0 is used, or relative
#define BNKM_HIGHB	0x02	// only bit 7 is used

extern UINT32 ROMLength;
extern UINT8* ROMData;
extern UINT8 RAMMode;
extern UINT16 RAMSize;
extern UINT8* RAMData;
extern char* FileTitle;
extern UINT8 PtrMode;
extern UINT8 MarsMode;
extern UINT32 MarsBase;

extern UINT8 SONG_BASE;
extern UINT8 SONG_COUNT;
extern UINT8 ReadOnlyMode;

extern char DAC_NAMEBASE[0x40];

static UINT32 SMSBankMap[3];

// Formats:
//	PTR_68K
//		list of 32-bit addresses
//		-> Addresses point directly to music data.
//	PTR_Z80
//		list of 16-bit addresses, all within the current Z80 ROM bank (8000-FFFF)
//		-> Addresses point directly to music data.
//	PTR_ORNS (OutRunners)
//		list format:
//			1 byte  - bank description (0 - 1F0000, 1 - 1F8000)
//			2 bytes - song address (Z80 ROM bank, 8000-FFFF)
//		-> Final address = (1F0000 | (bank << 15) | (address & 7FFF)
//	PTR_MMWW (Mega Man - The Wily Wars)
//		list of 32-bit addresses
//		-> Every address points to a structure of the format:
//			2 bytes - song length (big endian)
//			2 bytes - song address (little endian, for sound driver)
//			x bytes - song data ([song length - 2] bytes)
//	PTR_SM1bM4
//		list format:
//			4 bytes - song address
//			2 bytes - song size (DBRA iterations with 0x20 bytes each)
//	PTR_Z80RAM
//		list of 16-bit addresses, all in Z80 RAM (0000-1FFF)
//		-> Addresses point directly to music data.
//	PTR_Z80BPTR
//		2 lists:
//			list of 8-bit bank values, possible formats:
//				- value bits 0-7 -> bank bits 15-22 (used in Sonic 3 and later)
//				- value bit 7 -> bank bit 15 (Super Monaco Grand Prix)
//				- value bit 0 -> bank bit 15 (used in The Hybrid Front)
//			list of 16-bit addresses
//			-> Addresses point directly to music data.
//			-> Addresses are mostly Z80 ROM bank offsets (8000-FFFF),
//			   but some games also Z80 RAM offsets (0000-1FFF)
//	PTR_S2CDV2
//		same as PTR_68K, except that the SMPS header is different
//		(instrument pointer is an absolute 4 byte ROM offset)
//	PTR_DARWIN
//		list format:
//			4 bytes - song address
//			4 bytes - song size (DBRA iterations)

static UINT32 GetMDZ80Ptr(UINT16 Z80Addr, UINT32 BankBaseOfs)
{
	if (! Z80Addr)	// NULL address
		return 0x00;
	else if (Z80Addr < 0x2000)		// Z80 RAM
		return 0x80000000 | Z80Addr;
	else if (Z80Addr & 0x8000)	// banked ROM
		return (BankBaseOfs & 0xFF8000) | (Z80Addr & 0x7FFF);
	else
		return 0x00;
}

static UINT32 GetMSZ80Ptr(UINT16 Z80Addr)
{
	if (Z80Addr < 0xC000)	// banked ROM
		return (SMSBankMap[Z80Addr >> 14] & 0xFFC000) | (Z80Addr & 0x3FFF);
	else					// Z80 RAM
		return 0x80000000 | (Z80Addr & 0x3FFF);
}

static UINT32 GuessSongCount(UINT8 Mode, UINT32 MusPtrList, UINT32 BankList,
							UINT8* RetBankMode, UINT32 BnkBase)
{
	const UINT8* RMData;	// Music List Pointer
	const UINT8* RBData;	// Bank List Pointer
	UINT32 MaxPos;
	UINT32 MaxBPos;
	UINT32 CurPos;
	UINT32 BnkPos;
	UINT16 SongCnt;
	UINT32 ROMBank;
	UINT32 Z80Addr;
	UINT32 SongAddr;
	UINT8 BankMode;
	
	switch(PtrMode & 0xF0)
	{
	case PTR_68K:
		RMData = ROMData;
		MaxPos = ROMLength;
		break;
	case PTR_Z80:
		if (MusPtrList < RAMSize)
		{
			RMData = RAMData;
			MaxPos = RAMSize;
		}
		else
		{
			RMData = ROMData;
			MaxPos = (MusPtrList | 0x7FFF) + 0x01;
		}
		break;
	}
	
	BankMode = *RetBankMode;
	SongCnt = 0x00;
	CurPos = MusPtrList;
	switch(PtrMode)
	{
	case PTR_68K:
	case PTR_MMWW:
	case PTR_S2CDV2:
		while(CurPos + 0x03 < MaxPos)
		{
			SongAddr = ReadBE32(&RMData[CurPos]);
			FixMarsPointer(&SongAddr);
			if (! SongAddr || SongAddr >= ROMLength)
				break;
			CurPos += 0x04;
			
			if (SongAddr < MaxPos && SongAddr > MusPtrList)
				MaxPos = SongAddr;
			SongCnt ++;
		}
		break;
	case PTR_SM1bM4:
		while(CurPos + 0x05 < MaxPos)
		{
			SongAddr = ReadBE32(&RMData[CurPos]);
			FixMarsPointer(&SongAddr);
			if (! SongAddr || SongAddr >= ROMLength)
				break;
			CurPos += 0x04 + 0x02;
			
			if (SongAddr < MaxPos && SongAddr > MusPtrList)
				MaxPos = SongAddr;
			SongCnt ++;
		}
		break;
	case PTR_DARWIN:
		while(CurPos + 0x08 < MaxPos)
		{
			SongAddr = ReadBE32(&RMData[CurPos + 0x00]);
			FixMarsPointer(&SongAddr);
			if (! SongAddr || SongAddr >= ROMLength)
				break;
			if (ReadBE32(&RMData[CurPos + 0x04]) >= 0x10000)
				break;
			CurPos += 0x04 + 0x04;
			
			if (SongAddr < MaxPos && SongAddr > MusPtrList)
				MaxPos = SongAddr;
			SongCnt ++;
		}
		break;
	case PTR_Z80:
	//case PTR_Z80RAM:
		while(CurPos + 0x01 < MaxPos)
		{
			Z80Addr = ReadLE16(&RMData[CurPos]);
			if (Z80Addr && Z80Addr >= 0x2000 && Z80Addr < 0x8000)
				break;	// pointer to invalid Z80 memory space (2000-7FFF)
			/*if (PtrMode == PTR_Z80RAM)
			{
				// pointer to Z80 ROM bank (8000-FFFF)
				if (Z80Addr & 0x8000)
					break;
			}
			else if (PtrMode == PTR_Z80)
			{
				// pointer to Z80 RAM (0000-1FFFF)
				if (Z80Addr && ! (Z80Addr & 0x8000))
					break;
			}*/
			SongAddr = GetMDZ80Ptr(Z80Addr, BnkBase) & 0x7FFFFFF;	// strip the RAM bit off, if set
			CurPos += 0x02;
			
			if (SongAddr > MusPtrList && SongAddr < MaxPos)
				MaxPos = SongAddr;
			SongCnt ++;
		}
		break;
	case PTR_Z80BPTR:
		if (BankList < RAMSize)
		{
			RBData = RAMData;
			MaxBPos = RAMSize;
			if (MusPtrList < RAMSize)
			{
				if (MusPtrList < MaxBPos && BankList < MusPtrList)
					MaxBPos = MusPtrList;
				else if (BankList < MaxPos && MusPtrList < BankList)
					MaxPos = BankList;
			}
		}
		else
		{
			RBData = ROMData;
			MaxBPos = (BankList | 0x7FFF) + 0x01;
			// Mus+Bank lists are ROM, MusList ROM Bank == BnkList ROM Bank
			if (MusPtrList >= RAMSize && (MusPtrList & ~0x7FFF) == (BankList & ~0x7FFF))
			{
				if (MusPtrList < MaxBPos && BankList < MusPtrList)
					MaxBPos = MusPtrList;
				else if (BankList < MaxPos && MusPtrList < BankList)
					MaxPos = BankList;
			}
		}
		BnkPos = BankList;
		while(CurPos + 0x01 < MaxPos && BnkPos < MaxBPos)
		{
			if (BankMode >= 0xFE && RBData[BnkPos])
			{
				if (BankMode == 0xFE)
				{
					if (RBData[BnkPos] == 0x80)
						BankMode = BNKM_HIGHB;
					else
						BankMode = BNKM_LOWB;
				}
				else if (BankMode == 0xFF)
				{
					if (RBData[BnkPos] == 0x80)
						BankMode = BNKM_HIGHB;
					else if (RBData[BnkPos] < 0x08)
						BankMode = BNKM_LOWB;
					else
						BankMode = BNKM_FULL;
				}
			}
			if (BankMode == BNKM_FULL)
				ROMBank = RBData[BnkPos] << 15;
			else if (BankMode == BNKM_LOWB)
				ROMBank = BnkBase + (RBData[BnkPos] << 15);
			else if (BankMode == BNKM_HIGHB)
				ROMBank = BnkBase + (RBData[BnkPos] <<  8);
			else
				ROMBank = BnkBase;
			ROMBank &= 0xFF8000;
			if (MarsMode && ROMBank < 0x200000)
				ROMBank |= 0x800000;	// force 32x ROM area
			FixMarsPointer(&ROMBank);
			if (ROMBank >= ROMLength)
				break;
			/*if (BankMode == BNKM_FULL)
			{
				if (ROMBank >= ROMLength)
					break;
			}
			else if (BankMode == BNKM_LOWB)
			{
				if (RBData[BnkPos] >= 0x10)
					break;
			}*/
			//Z80Addr = ReadLE16(&RMData[CurPos]);
			if (CurPos < 0x8000)
				Z80Addr = ReadLE16(&RMData[CurPos]);
			else
				Z80Addr = ReadLE16(&ROMData[ROMBank | (CurPos & 0x7FFF)]);
			if (Z80Addr && Z80Addr >= 0x2000 && Z80Addr < 0x8000)
				break;	// pointer to invalid Z80 memory space (2000-7FFF)
			SongAddr = GetMDZ80Ptr(Z80Addr, ROMBank) & 0x7FFFFFF;	// strip the RAM bit off, if set
			BnkPos ++;
			CurPos += 0x02;
			
			if (SongAddr > MusPtrList && SongAddr < MaxPos)
				MaxPos = SongAddr;
			SongCnt ++;
		}
		break;
	case PTR_ORNS:
		while(CurPos + 0x02 < MaxPos)
		{
			// OutRunners includes a bank value
			BnkBase = 0x1F0000 | ((RMData[CurPos + 0x00] & 0x01) << 15);
			Z80Addr = ReadLE16(&RMData[CurPos + 0x01]);
			
			// same pointer as before || pointer to invalid Z80 memory space (2000-7FFF)
			if (Z80Addr >= 0x2000 && Z80Addr < 0x8000)
				break;	// pointer to invalid Z80 memory space (2000-7FFF)
			SongAddr = GetMDZ80Ptr(Z80Addr, BnkBase) & 0x7FFFFFF;	// strip the RAM bit off, if set
			CurPos += 0x03;
			
			if (SongAddr > MusPtrList && SongAddr < MaxPos)
				MaxPos = SongAddr;
			SongCnt ++;
		}
		break;
	}
	
	if (RetBankMode != NULL)
		*RetBankMode = BankMode;
	return SongCnt;
}

void ExtractSongs(UINT8 Mode, UINT32 MusPtrList, UINT32 BankList, UINT32 BnkBase)
{
	const char* FTitlePtr;
	const char* FExtPtr;
	const UINT8* RMData;	// Music List Pointer
	const UINT8* RBData;	// Bank List Pointer
	UINT32 CurPos;
	UINT32 BnkPos;
	UINT32 ROMBank;
	UINT16 CurSng;
	UINT16 CurSng2;
	UINT16 SongCnt;
	SONG_LIST* SongLst;
	SONG_LIST* TempLst;
	UINT16 Z80Addr;
	UINT32 SongAddr;
	char FileName[0x200];
	FILE* hFile;
	UINT8 BankMode;
	UINT32 songBufSize;
	UINT8* songBuffer;
	
	if (! MusPtrList || MusPtrList >= ROMLength)
		return;
	if (! RAMSize || RAMData == NULL)
	{
		//if (PtrMode == PTR_Z80RAM || PtrMode == PTR_Z80BPTR)
		if ((PtrMode & 0xF0) == PTR_Z80 &&
			((MusPtrList && MusPtrList < 0x2000) ||
			(BankList && BankList < 0x2000)))
		{
			printf("Can't work without Z80 Driver data!\n");
			return;
		}
	}
	
	if (! BnkBase)
	{
		BankMode = 0xFF;	// allow all Bank types
		BnkBase = MusPtrList & 0x00FF8000;
	}
	else
	{
		BankMode = 0xFE;	// allow BNKM_LOWB and BNKM_HIGHB only
	}
	
	SongCnt = GuessSongCount(Mode, MusPtrList, BankList, &BankMode, BnkBase);
	if (SONG_COUNT)
		SongCnt = SONG_COUNT;
	
	switch(PtrMode & 0xF0)
	{
	case PTR_68K:
		RMData = ROMData;
		break;
	case PTR_Z80:
		RMData = (MusPtrList < RAMSize) ? RAMData : ROMData;
		RBData = (BankList < RAMSize) ? RAMData : ROMData;
		break;
	}
	
	SongLst = (SONG_LIST*)malloc(SongCnt * sizeof(SONG_LIST));
	CurPos = MusPtrList;
	BnkPos = BankList;
	for (CurSng = 0x00; CurSng < SongCnt; CurSng ++)
	{
		SongLst[CurSng].Len = (UINT32)-1;
		switch(PtrMode)
		{
		case PTR_68K:
			SongLst[CurSng].Pos = ReadBE32(&RMData[CurPos]);
			CurPos += 0x04;
			break;
		case PTR_Z80:
		//case PTR_Z80RAM:
			Z80Addr = ReadLE16(&RMData[CurPos]);
			SongLst[CurSng].Pos = GetMDZ80Ptr(Z80Addr, BnkBase);
			CurPos += 0x02;
			break;
		case PTR_ORNS:	// OutRunners Pointer List Format
			BnkBase = 0x1F0000 | ((RMData[CurPos + 0x00] & 0x01) << 15);
			Z80Addr = ReadLE16(&RMData[CurPos + 0x01]);
			SongLst[CurSng].Pos = GetMDZ80Ptr(Z80Addr, BnkBase);
			CurPos += 0x01 + 0x02;
			break;
		case PTR_MMWW:	// Mega Man Wily Wars
			SongAddr = ReadBE32(&RMData[CurPos]);
			FixMarsPointer(&SongAddr);
			SongLst[CurSng].Pos = SongAddr + 0x04;
			SongLst[CurSng].Len = ReadBE16(&RMData[SongAddr]) - 0x02;
			CurPos += 0x04;
			break;
		case PTR_SM1bM4:
			SongLst[CurSng].Pos = ReadBE32(&RMData[CurPos + 0x00]);
			SongAddr = ReadBE16(&RMData[CurPos + 0x04]);
			SongLst[CurSng].Len = (SongAddr + 0x01) << 5;
			CurPos += 0x06;
			break;
		case PTR_DARWIN:
			SongLst[CurSng].Pos = ReadBE32(&RMData[CurPos + 0x00]);
			SongLst[CurSng].Len = ReadBE32(&RMData[CurPos + 0x04]) + 1;	// DBRA count + 1 = actual size
			CurPos += 0x08;
			break;
		case PTR_Z80BPTR:
			// Note: The Z80 Bank affects from where the pointer is read.
			if (BankMode == BNKM_FULL)
				ROMBank = RBData[BnkPos] << 15;
			else if (BankMode == BNKM_LOWB)
				ROMBank = BnkBase + (RBData[BnkPos] << 15);
			else if (BankMode == BNKM_HIGHB)
				ROMBank = BnkBase + (RBData[BnkPos] <<  8);
			else
				ROMBank = 0x00;
			ROMBank &= 0xFF8000;
			if (MarsMode && ROMBank < 0x200000)
				ROMBank |= 0x800000;	// force 32x ROM area
			FixMarsPointer(&ROMBank);
			
			if (CurPos < 0x8000)
				Z80Addr = ReadLE16(&RMData[CurPos]);
			else if (ROMBank < ROMLength)
				Z80Addr = ReadLE16(&ROMData[ROMBank | (CurPos & 0x7FFF)]);
			else
			{
				// prevent crashing due to invalid offsets
				Z80Addr = ReadLE16(&ROMData[BnkBase | (CurPos & 0x7FFF)]);
				ROMBank = 0xFF8000;	// make invalid address
			}
			SongLst[CurSng].Pos = GetMDZ80Ptr(Z80Addr, ROMBank);
			
			CurPos += 0x02;	BnkPos ++;
			break;
		case PTR_S2CDV2:
			SongLst[CurSng].Pos = ReadBE32(&RMData[CurPos]) & ~0x01;
			CurPos += 0x04;
			break;
		}
		FixMarsPointer(&SongLst[CurSng].Pos);
	}
	
	if (PtrMode == PTR_SM1bM4)
	{
		// The length has a resolution of 0x20-byte-blocks,
		// but the data is not aligned to these.
		// So we try to fix that by looking for overlapping data.
		for (CurSng = 0x00; CurSng < SongCnt; CurSng ++)
		{
			TempLst = &SongLst[CurSng];
			
			CurPos = GetNextAddr(SongCnt, SongLst, TempLst->Pos);
			if (CurPos >= ROMLength)
				CurPos = MusPtrList;
			
			if (CurPos >= TempLst->Pos + TempLst->Len - 0x20 &&
				CurPos <  TempLst->Pos + TempLst->Len)
				TempLst->Len = CurPos - TempLst->Pos;
		}
	}
	
	for (CurSng = 0x00; CurSng < SongCnt; CurSng ++)
	{
		TempLst = &SongLst[CurSng];
		if (TempLst->Len != (UINT32)-1)
			continue;
		if (! TempLst->Pos)
		{
			TempLst->Len = 0x0000;
			continue;
		}
		
		CurPos = GetNextAddr(SongCnt, SongLst, TempLst->Pos);
		if (TempLst->Pos & 0x80000000)
		{
			// Z80 RAM
			if ((CurPos & 0x7FFFFFFF) >= RAMSize)
				CurPos = GuessSMPSEnd(TempLst);
		}
		else
		{
			// ROM
			if (CurPos >= ROMLength)
				CurPos = GuessSMPSEnd(TempLst);
			// Note: GuessSMPSEnd can return the song's offset, if there are no FM instruments.
			if (CurPos <= TempLst->Pos)
			{
				if ((PtrMode & 0xF0) == PTR_68K)
					CurPos = TempLst->Pos + 0x10000;
				else
					CurPos = (TempLst->Pos | 0x7FFF) + 0x01;
			}
			else if ((PtrMode & 0xF0) == PTR_Z80)
			{
				// prevent Z80 dumps from crossing Z80 ROM banks
				if ((CurPos & ~0x7FFF) > (TempLst->Pos & ~0x7FFF))
					CurPos = (TempLst->Pos | 0x7FFF) + 0x01;
			}
		}
		if (TempLst->Pos & 0x80000000)
		{
			if ((CurPos & 0x7FFFFFFF) <= RAMSize)
				TempLst->Len = CurPos - TempLst->Pos;
			else
				TempLst->Len = 0x00;
		}
		else
		{
			if (CurPos <= ROMLength)
				TempLst->Len = CurPos - TempLst->Pos;
			else
				TempLst->Len = 0x00;
		}
		//if (TempLst->Len < 0x08)
		//	SongCnt = CurSng;
	}
	
	songBufSize = 0x00;
	for (CurSng = 0x00; CurSng < SongCnt; CurSng ++)
	{
		for (CurSng2 = CurSng + 1; CurSng2 < SongCnt; CurSng2 ++)
		{
			TempLst = &SongLst[CurSng2];
			if (TempLst->Pos == SongLst[CurSng].Pos)
				TempLst->Len = 0x0000;
		}
		if (SongLst[CurSng].Len > songBufSize)
			songBufSize = SongLst[CurSng].Len;
	}
	if (PtrMode == PTR_S2CDV2)
		songBuffer = (UINT8*)malloc(songBufSize);
	else
		songBuffer = NULL;
	
	if (Mode == 0x01)
	{
		FTitlePtr = "SFX";
		FExtPtr = "sfx";
	}
	else
	{
		FTitlePtr = FileTitle;
		FExtPtr = "bin";
	}
	if (SONG_BASE == 0xFF)
		SONG_BASE = 0x01;	// 0x81
	printf("ID  Pos     Len\n");
	for (CurSng = 0x00; CurSng < SongCnt; CurSng ++)
	{
		TempLst = &SongLst[CurSng];
		//if (! TempLst->Len)
		//	continue;
		
		printf("%02X  ", SONG_BASE + CurSng);
		if (TempLst->Pos & 0x80000000)
			printf("  %04X", TempLst->Pos & 0xFFFF);
		else
			printf("%06X", TempLst->Pos);
		if (TempLst->Len)
			printf("  %04X\n", TempLst->Len);
		else
			printf("  ----\n");
		if (ReadOnlyMode)
			continue;
		if (! TempLst->Pos || ! TempLst->Len)
			continue;
		
		//sprintf(FileName, "%s%s_%02X.%s", FileBase, FTitlePtr, CurSng + 0x15, FExtPtr);
		sprintf(FileName, "%s%02X.%s", DAC_NAMEBASE, SONG_BASE + CurSng, FExtPtr);
		hFile = fopen(FileName, "wb");
		if (hFile == NULL)
		{
			printf("Error opening file!\n");
			continue;
		}
		
		if (songBuffer == NULL)
		{
			if (TempLst->Pos & 0x80000000)
				fwrite(RAMData + (TempLst->Pos & 0x1FFF), 0x01, TempLst->Len, hFile);
			else
				fwrite(ROMData + TempLst->Pos, 0x01, TempLst->Len, hFile);
		}
		else
		{
			if (TempLst->Pos & 0x80000000)
				memcpy(songBuffer, RAMData + (TempLst->Pos & 0x1FFF), TempLst->Len);
			else
				memcpy(songBuffer, ROMData + TempLst->Pos, TempLst->Len);
			SongAddr = TempLst->Len;
			PatchSongData(&SongAddr, songBuffer, TempLst->Pos & 0x7FFFFFFF);
			fwrite(songBuffer, 0x01, SongAddr, hFile);
		}
		
		fclose(hFile);
	}
	
	return;
}

static UINT32 GetNextAddr(UINT16 SongCnt, const SONG_LIST* SongLst, UINT32 Address)
{
	UINT32 RetAddr;
	UINT32 CurSng;
	
	RetAddr = 0xFFFFFFFF;
	if (Address & 0x80000000)
	{
		// RAM Offsets
		for (CurSng = 0x00; CurSng < SongCnt; CurSng ++)
		{
			if (! (SongLst[CurSng].Pos & 0x80000000))
				continue;
			
			if (SongLst[CurSng].Pos > Address && SongLst[CurSng].Pos < RetAddr)
				RetAddr = SongLst[CurSng].Pos;
		}
	}
	else
	{
		// ROM Offsets
		for (CurSng = 0x00; CurSng < SongCnt; CurSng ++)
		{
			if (SongLst[CurSng].Pos & 0x80000000)
				continue;
			
			if (SongLst[CurSng].Pos > Address && SongLst[CurSng].Pos < RetAddr)
				RetAddr = SongLst[CurSng].Pos;
		}
	}
	
	return RetAddr;
}

static UINT32 GuessSMPSEnd(SONG_LIST* SongLst)
{
	UINT32 CurPos;
	UINT16 Z80Addr;
	
	if (SongLst->Pos & 0x80000000)
	{
		// Guess size of last SMPS file
		Z80Addr = ReadLE16(&RAMData[SongLst->Pos & 0x1FFF]);
		CurPos = GetMDZ80Ptr(Z80Addr, 0x0000) & 0x1FFF;
		if (CurPos < SongLst->Pos)
			return 0x80000000 | RAMSize;
		while(CurPos < RAMSize && RAMData[CurPos] && RAMData[CurPos] < 0xFF)
			CurPos += 0x19;
		return 0x80000000 | CurPos;
	}
	else if (SongLst->Pos < ROMLength)
	{
		// Guess size of last SMPS file
		if (PtrMode == PTR_S2CDV2)
		{
			CurPos = ReadBE32(&ROMData[SongLst->Pos]);
		}
		else if (PtrMode == PTR_68K)
		{
			CurPos = SongLst->Pos;
			CurPos += ReadBE16(&ROMData[CurPos]);
		}
		else
		{
			Z80Addr = ReadLE16(&ROMData[SongLst->Pos]);
			CurPos = GetMDZ80Ptr(Z80Addr, SongLst->Pos);
			if (CurPos & 0x80000000)
				return 0x00;
		}
		while(ROMData[CurPos] && ROMData[CurPos] < 0xFF &&
			CurPos < SongLst->Pos + 0x8000)
			CurPos += 0x19;
		return CurPos;
	}
	return SongLst->Pos;
}

void SetSMSBankMap(const char* BMapStr)
{
	UINT32 MapStrLen;
	UINT8 StartBnk;
	UINT8 CurBnk;
	const char* CurStr;
	char BnkNumStr[3];
	
	// default mapping
	SMSBankMap[0] = 0x00 << 14;
	SMSBankMap[1] = 0x01 << 14;
	SMSBankMap[2] = 0x02 << 14;
	
	MapStrLen = strlen(BMapStr);
	if ((MapStrLen & 1) || MapStrLen < 2 || MapStrLen > 6)
		return;	// valid are 2, 4 and 6 only
	
	StartBnk = 3 - (MapStrLen / 2);
	CurStr = BMapStr;
	BnkNumStr[2] = '\0';
	for (CurBnk = StartBnk; CurBnk < 3; CurBnk ++, CurStr += 2)
	{
		BnkNumStr[0] = CurStr[0];
		BnkNumStr[1] = CurStr[1];
		SMSBankMap[CurBnk] = strtoul(BnkNumStr, NULL, 0x10) << 14;
	}
	
	return;
}

static void PatchSongData(UINT32* songSize, UINT8* songBuffer, UINT32 baseAddr)
{
	UINT32 insPtr;
	UINT32 curPos;
	UINT16 trkPtr;
	UINT8 curTrk;
	
	switch(PtrMode)
	{
	case PTR_S2CDV2:
		insPtr = ReadBE32(&songBuffer[0x00]);
		(*songSize) -= 0x02;
		insPtr -= 0x02;
		memmove(&songBuffer[0x00], &songBuffer[0x02], *songSize);
		insPtr -= baseAddr;
		WriteBE16(&songBuffer[0x00], (UINT16)insPtr);
		
		curPos = 0x06;
		// patch drum/FM track pointers
		for (curTrk = 0; curTrk < songBuffer[0x02]; curTrk ++, curPos += 0x04)
		{
			trkPtr = ReadBE16(&songBuffer[curPos]);
			trkPtr -= 0x02;
			WriteBE16(&songBuffer[curPos], trkPtr);
		}
		// patch PSG track pointers
		for (curTrk = 0; curTrk < songBuffer[0x03]; curTrk ++, curPos += 0x06)
		{
			trkPtr = ReadBE16(&songBuffer[curPos]);
			trkPtr -= 0x02;
			WriteBE16(&songBuffer[curPos], trkPtr);
		}
		break;
	}
	
	return;
}
