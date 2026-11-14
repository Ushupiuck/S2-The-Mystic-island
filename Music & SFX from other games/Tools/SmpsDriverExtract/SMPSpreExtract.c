#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include <stdtype.h>


#define INLINE
#ifdef _MSC_VER
#define stricmp	_stricmp
#else
#define stricmp	strcasecmp
#endif


typedef UINT8 STAT_DATA;
#include "stats.h"


typedef struct song_list
{
	UINT32 HdrPos;
	UINT32 HdrLen;
	UINT32 SongOfs;	// relative to HdrPos
	UINT32 SongLen;
	UINT8 Tempo;
	UINT16 HdrBankPos;
	UINT16 FinBankPos;
	UINT8* SongData;
	UINT8* DataBuffer;
} SONG_LIST;



int main(int argc, char* argv[]);
void PrintHelpScreen(void);
void OpenROMFile(const char* FileName);
UINT8 DoActions(UINT8 Mode, int argc, const char** argv);
INLINE UINT16 ReadBE16(const UINT8* Data);
INLINE UINT16 ReadLE16(const UINT8* Data);
static UINT16 GetRawPointer(UINT8* Data);
static UINT32 GetROMPointer(UINT8* Data);
static UINT32 GetJumpPointer(UINT8* Data, UINT32 BasePos);
static UINT32 GuessSongCount(UINT32 MusPtrList);
void ExtractSongs(UINT8 Mode, UINT32 MusPtrList, UINT32 TempoList);
static void FillUseMask(UINT32 StartOfs, UINT32 ByteCount, UINT8 Value);
static UINT8 GetUseMask(UINT32 Offset);
void ParsePreSMPS(SONG_LIST* SongInfo, UINT8 UsageID);
static void ParseSMPSSection(UINT32 StartPos);
static void AreaStats_PrintStats(AREA_STATS* stats);



#define PTR_LE_RAW	0x00
#define PTR_Z80BNK	0x01
#define PTR_68KT1	0x08
#define PTR_BE_RAW	0x10
#define PTR_68KT2	0x10

UINT32 ROMLength;
UINT8* ROMData;
char FileBase[0x200];
char* FileTitle;
UINT8 PtrMode;

UINT8 SONG_BASE = 0xFF;
UINT8 SONG_COUNT = 0x00;
UINT8 ReadOnlyMode;
UINT8 PrintUsage;
UINT8 ForcedTrkCnt;

char OUT_NAMEBASE[0x41];

UINT32 BankBase;
UINT32 BankSize;

static UINT8 PSMP_NumParams[0x20] =
{	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,		// E0-E7
	0x00, 0x01, 0x01, 0x01, 0x00, 0x00, 0x01, 0x01,		// E8-EF
	0x01, 0x00, 0x80, 0x01, 0x01, 0x01, 0x02, 0x04,		// F0-F7
	0x02, 0x80, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00};	// F8-FF
static UINT8* UseMask;
static AREA_STATS ROMUsage;

int main(int argc, char* argv[])
{
	int argbase;
	UINT8 Mode;
	UINT8 RetVal;
	
	printf("pre-SMPS Song Extractor\n");
	printf("-----------------------\n");
	if (argc < 2)
	{
		PrintHelpScreen();
		
		// Example calls:
		//	-mus -Z80Bank "Space Harrier II (W).bin" 0x010000 0x0107FC 0x0107E3
		//	-mus -68k -ShowUse "Street Fighter II Turbo (U).bin" 0x0C1360 0x0C5282 0x0C5036
		//	-mus -68k -ShowUse -ReadOnly "Rent A Hero (J) [!].bin" 0x0EF330 0x0EF290 0x0EEFF6
		return 0;
	}
	
	Mode = 0xFF;
	PtrMode = 0x00;
	ReadOnlyMode = 0x00;
	PrintUsage = 0x00;
	ForcedTrkCnt = 0x00;
	strcpy(OUT_NAMEBASE, "");
	
	argbase = 1;
	if (argv[argbase][0] == '-')
	{
		if (! stricmp(argv[argbase] + 1, "mus"))
			Mode = 0x00;
		else if (! stricmp(argv[argbase] + 1, "sfx"))
			Mode = 0x01;
		else
		{
			if (! stricmp(argv[argbase] + 1, "help"))
				PrintHelpScreen();
			else
				printf("Unknown Mode!\n");
#ifdef _DEBUG
			getchar();
#endif
			return 0;
		}
		argbase ++;
	}
	while(argbase < argc && argv[argbase][0] == '-')
	{
		if (! stricmp(argv[argbase] + 1, "rawLE"))
			PtrMode = PTR_LE_RAW;
		else if (! stricmp(argv[argbase] + 1, "rawBE"))
			PtrMode = PTR_BE_RAW;
		else if (! stricmp(argv[argbase] + 1, "Z80Bank"))
			PtrMode = PTR_Z80BNK;
		else if (! stricmp(argv[argbase] + 1, "68k"))
			PtrMode = PTR_68KT2;
		else if (! stricmp(argv[argbase] + 1, "68kRel"))
			PtrMode = PTR_68KT1;
		else if (! stricmp(argv[argbase] + 1, "base"))
		{
			argbase ++;
			if (argbase < argc)
				SONG_BASE = (UINT8)strtoul(argv[argbase], NULL, 0);
		}
		else if (! stricmp(argv[argbase] + 1, "num"))
		{
			argbase ++;
			if (argbase < argc)
				SONG_COUNT = (UINT8)strtoul(argv[argbase], NULL, 0);
		}
		else if (! stricmp(argv[argbase] + 1, "TrkCnt"))
		{
			argbase ++;
			if (argbase < argc)
				ForcedTrkCnt = (UINT8)strtoul(argv[argbase], NULL, 0);
		}
		else if (! _stricmp(argv[argbase] + 1, "folder"))
		{
			argbase ++;
			if (argbase < argc)
			{
				strncpy(OUT_NAMEBASE, argv[argbase], 0x3F);
				OUT_NAMEBASE[0x3F] = '\0';
				strcat(OUT_NAMEBASE, "/");
			}
		}
		else if (! stricmp(argv[argbase] + 1, "ReadOnly"))
			ReadOnlyMode = 0x01;
		else if (! stricmp(argv[argbase] + 1, "ShowUse"))
			PrintUsage = 0x01;
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
	
	RetVal = DoActions(Mode, argc - argbase, argv + argbase);
	
	free(ROMData);	ROMData = NULL;
	ROMLength = 0x00;
	
#ifdef _DEBUG
	if (argv[0][1] == ':')
		getchar();
#endif
	
	return RetVal;
}

void PrintHelpScreen(void)
{
	printf("Usage:\n");
	printf("SMPSpreExtract Mode [Options] ROM.bin SongBankOfs SongPtrList SongTempoList\n");
	printf("\n");
	printf("Modes:\n");
//	printf("    -info - show SMPS driver information (type, pointers, etc.) (default)\n");
//	printf("            Note: info/dumpall accept an additional parameter that\n");
//	printf("                  specifies the Pointer List Offset.\n");
	printf("    -mus - Music\n");
	printf("    -sfx - Sounds (same as music, dumps as .sfx)\n");
	printf("    -help  - show usage\n");
	printf("If you want to extract envelopes and/or DAC sounds, please use SMPSExtract.\n");
	printf("Options:\n");
	printf("-base N         sets the index of the first song/sound to N\n");
	printf("-num N          forces N songs/sounds to be ripped \n");
	printf("-folder Name    set destination folder (default is current folder)\n");
	printf("-rawLE          raw Little Endian pointers\n");
	printf("-rawBE          raw Big Endian pointers\n");
	printf("-Z80Bank        assumes Little Endian pointers (checks for Z80 ROM area)\n");
	printf("-68k            Big Endian pointers, for pre-SMPS 68k Type 2 (same as -rawBE)\n");
	printf("-68kRel         Little Endian pointers, relative jumps, for pre-SMPS 68k Type 1\n");
	printf("-ReadOnly       print everything, but don't write any files\n");
	printf("-ShowUse        show a detailed list about the used ROM regions\n");
	printf("-TrkCnt N       enforce ripping all songs with N tracks (for unused headers)\n");
	printf("\n");
	
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

UINT8 DoActions(UINT8 Mode, int argc, const char** argv)
{
	UINT32 MusPtr;
	UINT32 TempoPtr;
	
	if (argc < 3)
	{
		printf("Not enough parameters.\n");
		return 2;
	}
	
	BankBase = strtoul(argv[0], NULL, 0);
	MusPtr = strtoul(argv[1], NULL, 0);
	TempoPtr = strtoul(argv[2], NULL, 0);
	
	ExtractSongs(Mode, MusPtr, TempoPtr);
	
	printf("Done.\n");
	
	return 0;
}

INLINE UINT16 ReadBE16(const UINT8* Data)
{
	return (Data[0x00] << 8) | (Data[0x01] << 0);
}

INLINE UINT16 ReadLE16(const UINT8* Data)
{
	return (Data[0x01] << 8) | (Data[0x00] << 0);
}

static UINT16 GetRawPointer(UINT8* Data)
{
	switch(PtrMode & 0xF0)
	{
	case PTR_LE_RAW:
		return ReadLE16(Data);
	case PTR_BE_RAW:
		return ReadBE16(Data);
	default:
		return (UINT16)-1;
	}
}

static UINT32 GetROMPointer(UINT8* Data)
{
	switch(PtrMode)
	{
	case PTR_LE_RAW:
	case PTR_68KT1:
		return BankBase + ReadLE16(Data);
	case PTR_BE_RAW:
	//case PTR_68KT2:
		return BankBase + ReadBE16(Data);
	case PTR_Z80BNK:
		return BankBase + (ReadLE16(Data) & 0x7FFF);
	default:
		return (UINT32)-1;
	}
}

static UINT32 GetJumpPointer(UINT8* Data, UINT32 BasePos)
{
	if (! (PtrMode & 0x08))
		return GetROMPointer(Data);
	
	// do relative pointer
	BasePos ++;
	switch(PtrMode & 0xF0)
	{
	case PTR_LE_RAW:
		return BasePos + (INT16)ReadLE16(Data);
	case PTR_BE_RAW:
		return BasePos + (INT16)ReadBE16(Data);
	default:
		return (UINT32)-1;
	}
}

static UINT32 GuessSongCount(UINT32 MusPtrList)
{
	UINT32 MaxPos;
	UINT32 CurPos;
	UINT16 SongCnt;
	UINT32 SongAddr;
	
	MaxPos = BankBase + BankSize;
	SongCnt = 0x00;
	CurPos = MusPtrList;
	while(CurPos + 0x01 < MaxPos)
	{
		if (ROMData[CurPos + 0x00] == 0xFF && ROMData[CurPos + 0x01] == 0xFF)
			break;
		
		SongAddr = GetROMPointer(&ROMData[CurPos]);
		if (SongAddr >= ROMLength)
			break;
		if (ROMData[SongAddr] > 0x0A)
			break;	// > 10 channels is not realistic
		if (ROMData[SongAddr] > 0x00)
		{
			// valid channel values are: 00..06, 16, 40, 80, A0, C0, E0
			// so a simplified check exits for value >= 20 that are not multiples of 20
			if (ROMData[SongAddr + 0x02] >= 0x20 && (ROMData[SongAddr + 0x02] & 0x1F))
				break;
		}
		CurPos += 0x02;
		
		if (SongAddr < MaxPos && SongAddr > MusPtrList)
			MaxPos = SongAddr;
		SongCnt ++;
	}
	
	return SongCnt;
}

void ExtractSongs(UINT8 Mode, UINT32 MusPtrList, UINT32 TempoList)
{
	const char* FTitlePtr;
	const char* FExtPtr;
	UINT32 CurPos;
	UINT32 MaxPos;
	UINT8 OutPtrMode;
	UINT16 CurSng;
	UINT16 PrevSng;
	UINT16 SongCnt;
	SONG_LIST* SongLst;
	SONG_LIST* TempLst;
	char FileName[0x100];
	FILE* hFile;
	
	if (! MusPtrList || MusPtrList >= ROMLength)
		return;
	if (! TempoList || TempoList >= ROMLength)
		return;
	
	BankSize = 0x10000;
	switch(PtrMode)
	{
	case PTR_Z80BNK:
		BankSize = 0x8000;
		break;
	case PTR_68KT1:
	case PTR_68KT2:
		PSMP_NumParams[0x0C] = 0x01;	// fix EC command length for preSMPS 68k
		break;
	}
	if (SONG_COUNT)
		SongCnt = SONG_COUNT;
	else
		SongCnt = GuessSongCount(MusPtrList);
	printf("Song count: 0x%02X\n", SongCnt);
	
	MaxPos = BankBase + BankSize;
	switch(PtrMode & 0xF0)
	{
	case PTR_LE_RAW:
		OutPtrMode = 0x00;
		break;
	case PTR_BE_RAW:
		OutPtrMode = 0x10;
		break;
	}
	if (SONG_BASE == 0xFF)
		SONG_BASE = 0x01;	// 0x81
	
	AreaStats_Init(&ROMUsage);
	SongLst = (SONG_LIST*)malloc(SongCnt * sizeof(SONG_LIST));
	CurPos = MusPtrList;
	for (CurSng = 0x00; CurSng < SongCnt; CurSng ++, CurPos += 0x02)
	{
		TempLst = &SongLst[CurSng];
		TempLst->Tempo = ROMData[TempoList + CurSng];
		TempLst->HdrBankPos = GetRawPointer(&ROMData[CurPos]);
		TempLst->FinBankPos = 0x0000;
		TempLst->HdrPos = GetROMPointer(&ROMData[CurPos]);
		
		for (PrevSng = 0x00; PrevSng < CurSng; PrevSng ++)
		{
			if (SongLst[PrevSng].HdrPos == TempLst->HdrPos &&
				SongLst[PrevSng].Tempo == TempLst->Tempo)
				break;
		}
		if (PrevSng < CurSng)
		{
			// same song, same tempo - doesn't need to be dumped
			TempLst->HdrLen = 0x00;
			TempLst->SongOfs = 0x00;
			TempLst->SongLen = 0x00;
			TempLst->SongData = NULL;
			TempLst->DataBuffer = NULL;
			continue;
		}
		for (PrevSng = 0x00; PrevSng < CurSng; PrevSng ++)
		{
			if (SongLst[PrevSng].HdrPos == TempLst->HdrPos)
				break;
		}
		if (PrevSng < CurSng)
		{
			// same song, different tempo - copy values over
			TempLst->HdrLen = SongLst[PrevSng].HdrLen;
			TempLst->SongOfs = SongLst[PrevSng].SongOfs;
			TempLst->SongLen = SongLst[PrevSng].SongLen;
			TempLst->HdrBankPos = SongLst[PrevSng].HdrBankPos;
			TempLst->FinBankPos = SongLst[PrevSng].FinBankPos;
			TempLst->SongData = SongLst[PrevSng].SongData;
			TempLst->DataBuffer = NULL;
			continue;
		}
		
		printf("Parsing Song %02X ...\r", SONG_BASE + CurSng);
		//TempLst->SongData = &ROMData[TempLst->HdrPos + TempLst->SongOfs];
		ParsePreSMPS(TempLst, SONG_BASE + CurSng);
		TempLst->FinBankPos = TempLst->HdrBankPos + TempLst->SongOfs - TempLst->HdrLen;	// fix header offset
	}
	
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
	//printf("ID  Pos     Len\n");
	printf("ID  Ptr   HdrPos  HLen  SongPos SLen\n");
	for (CurSng = 0x00; CurSng < SongCnt; CurSng ++)
	{
		TempLst = &SongLst[CurSng];
		//if (! TempLst->Len)
		//	continue;
		
		printf("%02X  %04X  %06X", SONG_BASE + CurSng, TempLst->HdrBankPos, TempLst->HdrPos);
		if (TempLst->HdrLen)
			printf("  %04X  %06X  %04X\n", TempLst->HdrLen,
					TempLst->HdrPos + TempLst->SongOfs, TempLst->SongLen);
		else
			printf("  ----  ------  ----\n");
		if (ReadOnlyMode)
			continue;
		if (! TempLst->HdrPos || ! TempLst->HdrLen)
			continue;
		
		sprintf(FileName, "%s%02X.%s", OUT_NAMEBASE, SONG_BASE + CurSng, FExtPtr);
		hFile = fopen(FileName, "wb");
		if (hFile == NULL)
		{
			printf("Error opening file!\n");
			continue;
		}
		
		fwrite("PSMP", 0x01, 0x04, hFile);
		fputc(OutPtrMode, hFile);
		fputc(TempLst->Tempo, hFile);
		if (PtrMode & 0x10)
		{
			fputc((TempLst->FinBankPos >> 8) & 0xFF, hFile);
			fputc((TempLst->FinBankPos >> 0) & 0xFF, hFile);
		}
		else
		{
			fputc((TempLst->FinBankPos >> 0) & 0xFF, hFile);
			fputc((TempLst->FinBankPos >> 8) & 0xFF, hFile);
		}
		fwrite(ROMData + TempLst->HdrPos, 0x01, TempLst->HdrLen, hFile);
		fwrite(TempLst->SongData, 0x01, TempLst->SongLen, hFile);
		
		fclose(hFile);
	}
	
	if (PrintUsage)
	{
		printf("\n");
		AreaStats_PrintStats(&ROMUsage);
	}
	
	AreaStats_Deinit(&ROMUsage);
	for (CurSng = 0x00; CurSng < SongCnt; CurSng ++)
	{
		TempLst = &SongLst[CurSng];
		if (TempLst->DataBuffer != NULL)
			free(TempLst->DataBuffer);
	}
	
	return;
}

static void FillUseMask(UINT32 StartOfs, UINT32 ByteCount, UINT8 Value)
{
	assert(StartOfs >= BankBase);
	StartOfs -= BankBase;
	assert(StartOfs < BankSize);
	
	while(ByteCount > 0)
	{
		UseMask[StartOfs] |= Value;
		StartOfs ++;	ByteCount --;
	}
	
	return;
}

static UINT8 GetUseMask(UINT32 Offset)
{
	assert(Offset >= BankBase);
	Offset -= BankBase;
	assert(Offset < BankSize);
	if (Offset >= BankSize)
	{
		printf("Warning: Trying to access invalid offset %06X!\n", BankBase + Offset);
		return 0xFF;	// this should stop the parser from processing invalid data
	}
	
	return UseMask[Offset];
}

void ParsePreSMPS(SONG_LIST* SongInfo, UINT8 UsageID)
{
	UINT32 CurPos;
	UINT32 TrkDataPos;
	UINT8 TrkCount;
	UINT8 CurTrk;
	UINT32 FirstPos;
	UINT32 LastPos;
	UINT32 DataLen;
	UINT8 SongPadding;
	
	UseMask = (UINT8*)malloc(BankSize);
	memset(UseMask, 0x00, BankSize);
	
	SongPadding = 0x00;
	// Note: The header is NOT part of the actual mask.
	CurPos = SongInfo->HdrPos;
	TrkCount = ROMData[CurPos];
	CurPos ++;
	if (ForcedTrkCnt)
		TrkCount = ForcedTrkCnt;
	
	for (CurTrk = 0; CurTrk < TrkCount; CurTrk ++, CurPos += 0x09)
	{
		if (ROMData[CurPos + 0x00] & 0x80)	// track must be active
		{
			TrkDataPos = GetROMPointer(&ROMData[CurPos + 0x03]);
			ParseSMPSSection(TrkDataPos);
		}
	}
	if (PtrMode == PTR_68KT2 && ROMData[CurPos] == 0x00)
		CurPos ++;	// keep the padding byte present in preSMPS 68k Type 2 (not 68k T1)
	SongInfo->HdrLen = CurPos - SongInfo->HdrPos;
	AreaStats_AddRange(&ROMUsage, SongInfo->HdrPos, CurPos, UsageID, 0);
	
	FirstPos = BankSize;
	for (CurPos = 0x00; CurPos < BankSize; CurPos ++)
	{
		if (UseMask[CurPos])
		{
			FirstPos = CurPos;
			break;
		}
	}
	LastPos = FirstPos;
	for (CurPos = BankSize - 1; CurPos > FirstPos; CurPos --)
	{
		if (UseMask[CurPos])
		{
			LastPos = CurPos;
			break;
		}
	}
	LastPos ++;
	while(LastPos < BankSize && ROMData[BankBase + LastPos] == 0xF2)
	{
		// keep additional track terminators
		UseMask[LastPos] = 0x01;
		LastPos ++;
	}
	if ((PtrMode == PTR_68KT1 || PtrMode == PTR_68KT2) &&
		LastPos < BankSize && ROMData[BankBase + LastPos] == 0x00)
	{
		// keep the padding byte to prevent cluttered ROM usage statistics
		SongPadding = 0x01;
		UseMask[LastPos] = 0x01;
		LastPos ++;
	}
	
	if (FirstPos < BankSize)
	{
		SongInfo->SongOfs = FirstPos - (SongInfo->HdrPos - BankBase);
		SongInfo->SongLen = LastPos - FirstPos;
		SongInfo->DataBuffer = (UINT8*)malloc(SongInfo->SongLen);
		
		memcpy(SongInfo->DataBuffer, &ROMData[BankBase + FirstPos], SongInfo->SongLen);
		// dummy out all unused bytes
		LastPos = (UINT32)-1;
		for (CurPos = 0x00; CurPos < SongInfo->SongLen; CurPos ++)
		{
			if (LastPos != (UINT32)-1 &&				// all previous bytes were 'used'
				! UseMask[FirstPos + CurPos + 0x00] &&	// current byte 'unused'
				UseMask[FirstPos + CurPos + 0x01])		// next byte 'used' again
				UseMask[FirstPos + CurPos] = 0x01;	// mark padding byte as "used"
			
			if (! UseMask[FirstPos + CurPos])
			{
				SongInfo->DataBuffer[CurPos] = 0xAA;
				
				if (LastPos != (UINT32)-1)
				{
					TrkDataPos = BankBase + FirstPos + LastPos;
					DataLen = CurPos - LastPos;
					AreaStats_AddRange(&ROMUsage, TrkDataPos, TrkDataPos + DataLen, UsageID, 1);
					LastPos = (UINT32)-1;
				}
			}
			else
			{
				if (LastPos == (UINT32)-1)
					LastPos = CurPos;
			}
		}
		if (LastPos != (UINT32)-1)
		{
			TrkDataPos = BankBase + FirstPos + LastPos;
			DataLen = CurPos - LastPos;
			AreaStats_AddRange(&ROMUsage, TrkDataPos, TrkDataPos + DataLen, UsageID, 1);
		}
		
		if (SongPadding)
			SongInfo->SongLen --;	// remove padding byte from extracted data
		SongInfo->SongData = SongInfo->DataBuffer;
	}
	else
	{
		SongInfo->SongOfs = SongInfo->HdrLen;
		SongInfo->SongLen = 0x00;
		SongInfo->DataBuffer = NULL;
		SongInfo->SongData = NULL;
	}
	
	free(UseMask);
	return;
}

static void ParseSMPSSection(UINT32 StartPos)
{
	UINT32 CurPos;
	UINT32 DstPos;
	UINT8 IsActive;
	UINT8 CurCmd;
	INT8 CmdLen;
	
	if (GetUseMask(StartPos))
		return;
	
	CurPos = StartPos;
	IsActive = 0x80;
	while(IsActive)
	{
		CurCmd = ROMData[CurPos];
		FillUseMask(CurPos, 0x01, 0x02);
		CurPos ++;
		if (CurCmd >= 0xE0)
		{
			CmdLen = PSMP_NumParams[CurCmd & 0x1F];
			if (CmdLen & 0x80)
			{
				IsActive = 0x00;
				CmdLen &= ~0x80;
			}
			FillUseMask(CurPos, CmdLen, 0x01);
			
			switch(CurCmd)
			{
			case 0xF6:	// GoTo
				DstPos = GetJumpPointer(&ROMData[CurPos], CurPos);
				CmdLen = 0x00;
				if (GetUseMask(DstPos))
					IsActive = 0x00;
				else
					CurPos = DstPos;
				break;
			case 0xF7:	// Loop
				DstPos = GetJumpPointer(&ROMData[CurPos + 0x02], CurPos + 0x02);
				if (! GetUseMask(DstPos))
				{
					printf("Warning: Loop at %06X jumps into unread section %06X!\n",
							CurPos - 0x01, DstPos);
					assert(0);
				}
				break;
			case 0xF8:	// GoSub
				DstPos = GetJumpPointer(&ROMData[CurPos], CurPos);
				ParseSMPSSection(DstPos);
				break;
			}
			
			CurPos += CmdLen;
		}
	}
	
	return;
}

static void AreaStats_PrintStats(AREA_STATS* stats)
{
	unsigned int curItm;
	STAT_BLOCK* curBlk;
	STAT_BLOCK* lastBlk;
	
	printf("ROM Usage\n---------\n");
	printf("Start   End     Size  Used by\n");
	lastBlk = NULL;
	for (curBlk = stats->BlkHead; curBlk != NULL; curBlk = curBlk->next)
	{
		if (lastBlk != NULL && lastBlk->end != curBlk->start)
			printf("%06X  %06X  %04X  unused\n", lastBlk->end, curBlk->start - 1, curBlk->start - lastBlk->end);
		lastBlk = curBlk;
		
		printf("%06X  %06X  %04X  ", curBlk->start, curBlk->end - 1, curBlk->end - curBlk->start);
		if (curBlk->items.count > 0)
		{
			printf("%02X", curBlk->items.data[0]);
			for (curItm = 1; curItm < curBlk->items.count; curItm ++)
				printf(", %02X", curBlk->items.data[curItm]);
		}
		else
		{
			printf("error");
		}
		printf("\n");
	}
	
	return;
}
