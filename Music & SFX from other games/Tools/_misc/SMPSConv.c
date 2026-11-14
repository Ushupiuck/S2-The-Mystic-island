// SMPS Converter (formerly SMPS S3K to S1 Converter)
// --------------
// Programmed by Valley Bell, 2011-2012, 2015

// TODO: Remove IsInLoop and make a 'loop-dependent pointer mask'
//	prevent crashing from reading after EOF
// Note: S3K->S1 note conversion failed in Chaotix: Speed of Sound due to a subroutine in FM 2
//	(803C F8069D E7 08 -> 803C F801BE E7 BA08, BA should be B8)
//	I fixed this by resetting LastNoteCmd, but that's not proper fix.
// OK? fix Instrument Table detection in Pre-Parser (for proper S2->S1 conversions)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef unsigned char	bool;
typedef unsigned char	UINT8;
typedef signed char		INT8;
typedef unsigned short	UINT16;
typedef signed short	INT16;
typedef unsigned int	UINT32;

#define false	0x00
#define true	0x01

#define INLINE	__inline
#ifdef _MSC_VER
#define stricmp	_stricmp
#else
#define stricmp	strcasecmp
#endif

typedef struct mapping_table MAP_TBL;


int main(int argc, char* argv[]);
static bool SetConvModes(const char* ArgStr);
static bool SetConvMode(UINT8 IsDst, const char* ModeStr);

void LoadMappingFile(const char* MapFileName, MAP_TBL* MapData);

UINT8 LoadInstrumentBank(const char* FileName);
UINT8 LoadSMPSFile(const char* FileName);

static INLINE UINT16 Get16Ptr(UINT8* Data, UINT16 PtrPos);
static INLINE void Put16Ptr(UINT8* Data, UINT16 Ptr);

static void AddPtrToList(UINT16 SrcPos, UINT16 SrcPtr, UINT8 CoordFlag);
static void AddNewPtrOfsToList(UINT16 SrcPtr, UINT16 DstOfs, UINT8 CoordFlag);
static void AddNewPosToList(UINT16 SrcPos, UINT16 DstPos);
static void AddNewPtrOfsToList_FromOfs(UINT16 SrcOfs, UINT16 DstOfs, UINT8 CoordFlag);

void ReadSMPSHeader(void);

static void MakeSortedChannelList(void);
static bool GetProcMask(UINT16 Pos);
static void SetProcMask(UINT16 Pos, UINT16 Len);
UINT16 GetProcMaskNonusage(void);
void PrintProcMaskNonusage(void);

void PreparseSMPS(void);

static UINT8 TempoConv(UINT8 TempoMod);
static UINT8 PSGInsPatch(UINT8 PSGIns);
static void IgnoreMsg(UINT8 CurChn, UINT16 CurPos);
static void WarningMsg(UINT8 CurChn, UINT16 CurPos);
static void WarningMsgFlame(UINT8 CurChn, UINT16 CurPos, UINT16 NewPos);
static void WarningMsgInvalid(UINT8 CurChn, UINT16 CurPos);

void ConvertSMPS(void);
static UINT16 CopyInstrument(UINT8* Buffer, const UINT8* InsData);
static void CopyInstrumentTable(UINT16* DstOfs, UINT16* SrcOfs, UINT8 InsCnt);
void WritePointers(void);
void FreePointers(void);


typedef struct offset_list OFS_LIST;
struct offset_list
{
	UINT16 Ofs;
	UINT8 CoordFlg;
	OFS_LIST* next;
};

typedef struct pointer_list PTR_LIST;
struct pointer_list
{
	OFS_LIST* SrcPosLst;
	OFS_LIST* DstPosLst;
	UINT16 SrcPtr;
	UINT16 DstPtr;
	UINT8 CoordFlg;
	PTR_LIST* next;
};

typedef struct data_ptr_list DATAPTR_LIST;
struct data_ptr_list
{
	UINT16 Ofs;
	PTR_LIST* Item;
	DATAPTR_LIST* next;
};

typedef struct channel_header
{
	UINT16 Ptr;
	UINT8 KeyDisplc;
	UINT8 Volume;
} CHN_HEAD;

typedef struct mapping_value
{
	UINT8 MapFrom;
	UINT8 MapTo;
} MAP_VAL;
struct mapping_table
{
	UINT8 DoWarn;
	UINT8 Add;
	UINT8 MapCount;
	MAP_VAL* Map;
};


static const UINT8 ALGO_OPS[0x08] = {0x08, 0x08, 0x08, 0x08, 0x0A, 0x0E, 0x0E, 0x0F};


#define CPTR_68K	0x00
#define CPTR_Z80	0x01
#define CPTR_RST	0x02

#define CFMODE_S1	0x00
#define CFMODE_S2	0x00
#define CFMODE_S3K	0x01
#define CFMODE_TRS	0x02
#define CFMODE_ORNS	0x03

#define CTEMPO_S1	0x00
#define CTEMPO_S2	0x01
#define CTEMPO_S3K	0x02

#define CINS_DEF	0x00
#define CINS_HW		0x01

#define GET_CNV_SRC(x)	(((x) & 0x0F) >> 0)
#define GET_CNV_DST(x)	(((x) & 0xF0) >> 4)
#define MAKE_CNV_SRC(x)	(((x) & 0x0F) << 0)
#define MAKE_CNV_DST(x)	(((x) & 0x0F) << 4)

#define MAKE_CNV_SD(Src, Dst)	(MAKE_CNV_SRC(Src) | MAKE_CNV_DST(Dst))

enum
{
	CFTYPE_NO_CHANGE,
	CFTYPE_UNUSED,	// also used for proprietary flags the can't be converted
	CFTYPE_INVALID,	// print a warning when encountering these
	CFTYPE_STOP_TRACK,
	CFTYPE_LOOP,
	CFTYPE_GOTO,
	CFTYPE_GOSUB,
	CFTYPE_RETURN,
	CFTYPE_LP_JMP,
	CFTYPE_MODULATION,
	CFTYPE_VOLUME,
	CFTYPE_TEMPO,
	CFTYPE_NOTE_FILL,
	CFTYPE_FM_INS,
	CFTYPE_PSG_INS,
	CFTYPE_KEY_DISPLC,
	CFTYPE_SPECIAL
};
typedef struct coordination_flag
{
	UINT8 Type;
	UINT8 Len;
	UINT8 JmpOfs;
	UINT8 reserved;
} COORD_FLAG;

typedef struct instrument_bank_entry
{
	UINT8 Data[0x19];
} INS_BNK_ENTRY;
typedef struct instrument_list
{
	UINT8 IsUsed;
	UINT8 NewID;
} INS_LIST;
typedef struct instrument_bank
{
	UINT16 InsCount;
	INS_BNK_ENTRY* InsData;
	INS_LIST* InsAssign;
} INS_BANK;


UINT8 PtrMode;
UINT8 CoordMode;
UINT8 TempoMode;
UINT8 InsMode;
UINT8 SkipChecks;

UINT32 SMPSLen;
UINT8* SMPSData;
UINT32 SMPSNewLen;
UINT8* SMPSNewData;
UINT32 ProcMskSize;
UINT8* ProcMask;	// Mask of processed Data

PTR_LIST* PtrList;
PTR_LIST* PtrLEnd;
DATAPTR_LIST* SrcPosPtrList;
DATAPTR_LIST* SrcPosPtrLEnd;
UINT16 SMPSOffset;
UINT16 SMPSNewOffset;

bool UseInsBank;
UINT8 ChnCnt;
UINT8 FMChnCnt;
UINT8 PSGChnCnt;
CHN_HEAD* ChnList;
UINT8* ChnListSort;

UINT8 DuratDivide;

MAP_TBL DACMap;
MAP_TBL PSGMap;
INS_BANK InsBank;
COORD_FLAG CFMain[0x1F];
COORD_FLAG CFExt[0x11];

int main(int argc, char* argv[])
{
	const char* InsBankName;
	bool InsBankSet;
	int argbase;
	int ResVal;
	FILE* hFile;
	UINT8 RetVal;
	PTR_LIST* CurLst;
	OFS_LIST* CurOfs;
	int InKey;
	UINT16 SMPSOfsBak;
	
	printf("SMPS Converter\n--------------\n");
	if (argc < 4)
	{
		printf("Usage: SMPSConv.exe [-options] FmtFrom-FmtTo smps_in.bin smps_out.bin\n");
		printf("Options:\n");
		printf("    -nocheck - skips some validation checks (for use with custom formats)\n");
		printf("    -insbank file.bin - load instrument bank from the specified file\n");
		printf("                        default is InsBank.bin\n");
		printf("    -durdiv N - divides all durations by N. The Tick Multiplier is changed\n");
		printf("                accordinly to keep the song's speed.\n");
		printf("Format Strings (case insensitive):\n");
		printf("    S1  - Sonic 1 (68k)\n");
		printf("    S2  - Sonic 2 (Z80)\n");
		printf("    S3K - Sonic 3 & Knuckles (Z80)\n");
		printf("    Trs - SMPS Treasure (68k) and other games with late SMPS 68k\n");
		printf("    Tra - SMPS 68k with S3K-like Tempo\n");
		printf("    Rst - Ristar (68k)\n");
		printf("    ORs - Outrunners (Z80)\n");
		printf("Note: Upon startup, PSGMap.ini, DACMap.ini and InsBank.bin are loaded.\n");
		printf("      A message is displayed, if the .ini files fail to load.\n");
		printf("      An error about InsBank.bin is only shown when -insbank is used.\n");
		return 0;
	}
	
	ResVal = -1;
	argbase = 1;
	SkipChecks = 0x00;
	InsBankName = "InsBank.bin";
	InsBankSet = false;
	DuratDivide = 0;
	while(argbase < argc)
	{
		if (! stricmp(argv[argbase], "-nocheck"))
		{
			SkipChecks ++;
		}
		else if (! stricmp(argv[argbase], "-insbank"))
		{
			argbase ++;
			if (argbase < argc)
			{
				InsBankName = argv[argbase];
				InsBankSet = true;
			}
		}
		else if (! stricmp(argv[argbase], "-durdiv"))
		{
			argbase ++;
			if (argbase < argc)
				DuratDivide = (UINT8)strtoul(argv[argbase], NULL, 0);
		}
		else
		{
			break;
		}
		argbase ++;
	}
	if (DuratDivide == 0)
		DuratDivide = 1;	// prevent divide by 0
	
	/*ConvMode = CMODE_S3KtoS1;
	switch(ConvMode)
	{
	case CMODE_S3KtoS1:
		PtrMode = MAKE_CNV_SD(CPTR_Z80, CPTR_68K);
		CoordMode = MAKE_CNV_SD(CFMODE_S3K, CFMODE_S1);
		TempoMode = MAKE_CNV_SD(CTEMPO_S3K, CTEMPO_S1);
		break;
	case CMODE_TRStoS1:
		PtrMode = MAKE_CNV_SD(CPTR_68K, CPTR_68K);
		CoordMode = MAKE_CNV_SD(CFMODE_TRS, CFMODE_S1);
		TempoMode = MAKE_CNV_SD(CTEMPO_S1, CTEMPO_S1);
		break;
	case CMODE_S3KtoS3K:
		PtrMode = MAKE_CNV_SD(CPTR_Z80, CPTR_Z80);
		CoordMode = MAKE_CNV_SD(CFMODE_S3K, CFMODE_S3K);
		TempoMode = MAKE_CNV_SD(CTEMPO_S3K, CTEMPO_S3K);
		break;
	default:
		printf("Unknown Mode!\n");
		return 2;
	}*/
	if (! SetConvModes(argv[argbase + 0]))
	{
		printf("Invalid Format String!\n");
		return 2;
	}
	
	LoadMappingFile("PSGMap.ini", &PSGMap);
	LoadMappingFile("DACMap.ini", &DACMap);
	RetVal = LoadInstrumentBank(InsBankName);
	if (! RetVal)
		printf("Instrument Bank loaded. (0x%02X instruments)\n", InsBank.InsCount);
	else if (InsBankSet)
		printf("Error loading instrument bank!\n");
	SMPSData = NULL;
	SMPSNewData = NULL;
	
	RetVal = LoadSMPSFile(argv[argbase + 1]);
	if (RetVal)
	{
		printf("Error opening file!\n");
		ResVal = 1;
		goto CleanUp;
	}
	
	ReadSMPSHeader();
	if (! ChnCnt)
	{
		printf("Sorry, this file seems to be no valid SMPS file.\n");
		ResVal = 2;
		goto CleanUp;
	}
	
	// SMPSOffset gets set by ReadSMPSHeader
	if (GET_CNV_SRC(PtrMode) == CPTR_Z80)
	{
		printf("The guessed SMPS Offset in Z80 ROM Bank is: 0x%04X. Is this right? (Y/N/Q)\n", SMPSOffset);
		SMPSOfsBak = SMPSOffset;
		do
		{
			do
			{
				InKey = toupper(getchar());
				if (InKey == 'Q')
				{
					printf("Quit.\n");
					ResVal = 0;
					goto CleanUp;
				}
			} while(InKey != 'Y' && InKey != 'N');
			if (InKey == 'N')
			{
				printf("Please enter the correct offset: 0x");
				scanf("%hX", &SMPSOffset);
				if (! SMPSOffset)
				{
					printf("I think you should better use the default offset.\n");
					SMPSOffset = SMPSOfsBak;
				}
				//SMPSOffset |= 0x8000;
				printf("New Offset is: 0x%04X. Is this right? (Y/N)\n", SMPSOffset);
			}
		} while(InKey != 'Y');
		while(InKey != '\n')
			InKey = getchar();
	}
	SMPSNewOffset = 0x0000;
	if (GET_CNV_DST(PtrMode) == CPTR_Z80)
	{
		printf("Please enter the SMPS Offset in Z80 ROM Bank for the new SMPS file:\n0x", SMPSOffset);
		scanf("%hX", &SMPSNewOffset);
		if (! SMPSNewOffset)
		{
			printf("Offset invalid. Assume minimum bank offset.\n");
			SMPSNewOffset = 0x8000;
		}
		SMPSOfsBak = SMPSNewOffset;
		do
		{
			printf("Destination Offset is: 0x%04X. Is this right? (Y/N/Q)\n", SMPSNewOffset);
			do
			{
				InKey = toupper(getchar());
				if (InKey == 'Q')
				{
					printf("Quit.\n");
					ResVal = 0;
					goto CleanUp;
				}
			} while(InKey != 'Y' && InKey != 'N');
			if (InKey == 'N')
			{
				printf("Please enter the correct offset: 0x");
				scanf("%hX", &SMPSNewOffset);
				if (! SMPSNewOffset)
				{
					printf("Come on, this can't work.\n");
					SMPSNewOffset = SMPSOfsBak;
				}
			}
		} while(InKey != 'Y');
		while(InKey != '\n')
			InKey = getchar();
	}
	printf("\n");
	
	printf("FM/DAC Tracks: %u, PSG Tracks: %u\n", FMChnCnt, PSGChnCnt);
	PreparseSMPS();
	printf("\n");
	
	printf("Pointer List:\nCoord\tPntFile\tPntReal\tPos\n");
	CurLst = PtrList;
	while(CurLst != NULL)
	{
		printf("%02X\t%04X\t%04X\t", CurLst->CoordFlg, (SMPSOffset + CurLst->SrcPtr) & 0xFFFF, CurLst->SrcPtr);
		CurOfs = CurLst->SrcPosLst;
		while(CurOfs != NULL)
		{
			printf("%04X", CurOfs->Ofs);
			if (CurOfs->next != NULL)
				printf("/");
			CurOfs = CurOfs->next;
		}
		CurLst = CurLst->next;
		printf("\n");
	}
	printf("\n");
	
	ConvertSMPS();
	
	WritePointers();
	
	FreePointers();
	
	hFile = fopen(argv[argbase + 2], "wb");
	if (hFile == NULL)
	{
		printf("Error opening file!\n");
		return 1;
	}
	fwrite(SMPSNewData, SMPSNewLen, 0x01, hFile);
	
	fclose(hFile);
	
	printf("Conversion complete.\n");
	ResVal = 0;
	
CleanUp:
	if (SMPSData != NULL)
		free(SMPSData);
	if (SMPSNewData != NULL)
		free(SMPSNewData);
	
	if (InsBank.InsData != NULL)
		free(InsBank.InsData);
	if (InsBank.InsAssign != NULL)
		free(InsBank.InsAssign);
	
#ifdef _DEBUG
	getchar();
#endif
	
	return ResVal;
}

static bool SetConvModes(const char* ArgStr)
{
	char TempStr[0x10];
	char* RStr;
	
	strncpy(TempStr, ArgStr, 0x0F);
	TempStr[0x0F] = '\0';
	
	// split FmtFrom and FmtTo
	RStr = strchr(TempStr, '-');
	if (RStr == NULL)
		return false;
	*RStr = '\0';
	RStr ++;
	
	if (! SetConvMode(false, TempStr))
		return false;
	if (! SetConvMode(true, RStr))
		return false;
	
	return true;
}

static bool SetConvMode(UINT8 IsDst, const char* ModeStr)
{
	UINT8 Ptr;
	UINT8 Coord;
	UINT8 Tempo;
	UINT8 Ins;
	
	if (! stricmp(ModeStr, "S1"))
	{
		Ptr = CPTR_68K;
		Coord = CFMODE_S1;
		Tempo = CTEMPO_S1;
		Ins = CINS_DEF;
	}
	else if (! stricmp(ModeStr, "S2"))
	{
		Ptr = CPTR_Z80;
		Coord = CFMODE_S2;
		Tempo = CTEMPO_S2;
		Ins = CINS_HW;
	}
	else if (! stricmp(ModeStr, "S3K"))
	{
		Ptr = CPTR_Z80;
		Coord = CFMODE_S3K;
		Tempo = CTEMPO_S3K;
		Ins = CINS_DEF;
	}
	else if (! stricmp(ModeStr, "Trs"))
	{
		Ptr = CPTR_68K;
		Coord = CFMODE_TRS;
		Tempo = CTEMPO_S1;
		Ins = CINS_DEF;
	}
	else if (! stricmp(ModeStr, "Tra"))
	{
		Ptr = CPTR_68K;
		Coord = CFMODE_TRS;
		Tempo = CTEMPO_S3K;
		Ins = CINS_DEF;
	}
	else if (! stricmp(ModeStr, "Rst"))
	{
		Ptr = CPTR_RST;
		Coord = CFMODE_TRS;
		Tempo = CTEMPO_S3K;
		Ins = CINS_DEF;
	}
	else if (! stricmp(ModeStr, "ORs"))
	{
		Ptr = CPTR_Z80;
		Coord = CFMODE_ORNS;
		Tempo = CTEMPO_S3K;
		Ins = CINS_HW;
	}
	else
	{
		return false;
	}
	
	if (! IsDst)
	{
		PtrMode = MAKE_CNV_SD(Ptr, GET_CNV_DST(PtrMode));
		CoordMode = MAKE_CNV_SD(Coord, GET_CNV_DST(CoordMode));
		TempoMode = MAKE_CNV_SD(Tempo, GET_CNV_DST(TempoMode));
		InsMode = MAKE_CNV_SD(Ins, GET_CNV_DST(InsMode));
	}
	else
	{
		PtrMode = MAKE_CNV_SD(GET_CNV_SRC(PtrMode), Ptr);
		CoordMode = MAKE_CNV_SD(GET_CNV_SRC(CoordMode), Coord);
		TempoMode = MAKE_CNV_SD(GET_CNV_SRC(TempoMode), Tempo);
		InsMode = MAKE_CNV_SD(GET_CNV_SRC(InsMode), Ins);
	}
	
	return true;
}


void LoadMappingFile(const char* MapFileName, MAP_TBL* MapData)
{
	FILE* hFile;
	char TempStr[0x40];
	UINT8 CurMap;
	int TempInt;
	char* TempPnt;
	MAP_VAL* TempMap;
	
	MapData->DoWarn = 0x00;
	MapData->Add = 0x00;
	MapData->MapCount = 0x00;
	MapData->Map = NULL;
	
	hFile = fopen(MapFileName, "rt");
	if (hFile == NULL)
	{
		printf("Error opening %s\n", MapFileName);
		return;
	}
	
	MapData->MapCount = 0x7F;
	MapData->Map = (MAP_VAL*)malloc(MapData->MapCount * sizeof(MAP_VAL));
	memset(MapData->Map, 0x00, MapData->MapCount * sizeof(MAP_VAL));
	for (CurMap = 0x00; CurMap < MapData->MapCount; CurMap ++)
		MapData->Map[CurMap].MapFrom = 0xFF;
	
	while(! feof(hFile))
	{
		TempPnt = fgets(TempStr, 0x40, hFile);
		if (TempPnt == NULL)
			break;
		if (TempStr[0x00] == '\n' || TempStr[0x00] == '\0')
			continue;
		if (TempStr[0x00] == ';')
		{
			// skip comment lines
			// fgets has set a null-terminator at char 0x3F
			while(! feof(hFile) && TempStr[strlen(TempStr) - 1] != '\n')
			{
				fgets(TempStr, 0x40, hFile);
				if (TempStr[0x00] == '\0')
					break;
			}
			continue;
		}
		
		TempPnt = strchr(TempStr, '=');
		if (TempPnt == NULL || TempPnt == TempStr)
			continue;	// invalid line
		
		*TempPnt = '\0';
		TempPnt ++;
		
		TempInt = strlen(TempStr) - 1;
		while(TempInt > 0 && TempStr[TempInt] == ' ')
		{
			TempStr[TempInt] = '\0';
			TempInt --;
		}
		
		if (! stricmp(TempStr, "WarnUnmapped"))
		{
			MapData->DoWarn = (UINT8)strtoul(TempPnt, NULL, 0x10);
		}
		else if (! stricmp(TempStr, "Add"))
		{
			MapData->Add = (UINT8)strtoul(TempPnt, NULL, 0x10);
		}
		else
		{
			TempInt = (unsigned int)strtoul(TempStr, NULL, 0x10);
			CurMap = TempInt & 0x7F;
			if (! CurMap)
				continue;
			CurMap --;
			
			TempMap = &MapData->Map[CurMap];
			TempMap->MapFrom = (UINT8)strtoul(TempStr, NULL, 0x10);
			TempMap->MapTo = (UINT8)strtoul(TempPnt, NULL, 0x10);
		}
	}
	
	fclose(hFile);
	
	return;
}


UINT8 LoadInstrumentBank(const char* FileName)
{
	FILE* hFile;
	UINT32 FileLen;
	
	InsBank.InsCount = 0x00;
	InsBank.InsData = NULL;
	InsBank.InsAssign = NULL;
	
	hFile = fopen(FileName, "rb");
	if (hFile == NULL)
		return 0x80;
	
	fseek(hFile, 0x00, SEEK_END);
	FileLen = ftell(hFile);
	FileLen /= 0x19;	// -> number of instruments
	if (FileLen > 0x100)
		InsBank.InsCount = 0x100;
	else
		InsBank.InsCount = FileLen;
	
	fseek(hFile, 0x00, SEEK_SET);
	InsBank.InsData = (INS_BNK_ENTRY*)malloc(InsBank.InsCount * sizeof(INS_BNK_ENTRY));
	InsBank.InsAssign = (INS_LIST*)malloc(InsBank.InsCount * sizeof(INS_BNK_ENTRY));
	fread(InsBank.InsData, sizeof(INS_BNK_ENTRY), InsBank.InsCount, hFile);
	
	fclose(hFile);
	
	ProcMskSize = (SMPSLen + 0x07) >> 3;
	ProcMask = (UINT8*)malloc(ProcMskSize);
	
	return 0x00;
}

UINT8 LoadSMPSFile(const char* FileName)
{
	FILE* hFile;
	
	hFile = fopen(FileName, "rb");
	if (hFile == NULL)
		return 0x80;
	
	fseek(hFile, 0x00, SEEK_END);
	SMPSLen = ftell(hFile);
	if (SMPSLen > 0x10000)	// 64 KB
		SMPSLen = 0x10000;
	
	fseek(hFile, 0x00, SEEK_SET);
	SMPSData = (UINT8*)malloc(SMPSLen);
	fread(SMPSData, 0x01, SMPSLen, hFile);
	
	fclose(hFile);
	
	ProcMskSize = (SMPSLen + 0x07) >> 3;
	ProcMask = (UINT8*)malloc(ProcMskSize);
	
	return 0x00;
}

static INLINE UINT16 Get16Ptr(UINT8* Data, UINT16 PtrPos)
{
	UINT16 NewOfs;
	
	switch(GET_CNV_SRC(PtrMode))
	{
	case CPTR_68K:
		NewOfs = (Data[0x00] << 8) | (Data[0x01] << 0);
		if (PtrPos)
			NewOfs += PtrPos + 0x01;
		break;
	case CPTR_RST:
		NewOfs = (Data[0x00] << 8) | (Data[0x01] << 0);
		if (PtrPos)
			NewOfs += PtrPos + 0x02;
		break;
	case CPTR_Z80:
		NewOfs = (Data[0x01] << 8) | (Data[0x00] << 0);
		break;
	}
	
	return NewOfs - SMPSOffset;
}

static INLINE void Put16Ptr(UINT8* Data, UINT16 Ptr)
{
	switch(GET_CNV_DST(PtrMode))
	{
	case CPTR_68K:
	case CPTR_RST:
		Data[0x00] = (Ptr & 0xFF00) >> 8;
		Data[0x01] = (Ptr & 0x00FF) >> 0;
		break;
	case CPTR_Z80:
		Data[0x00] = (Ptr & 0x00FF) >> 0;
		Data[0x01] = (Ptr & 0xFF00) >> 8;
		break;
	}
	
	return;
}

static bool PtrIsInList(UINT16 SrcPos, UINT16 SrcPtr)
{
	PTR_LIST* CurLst;
	
	CurLst = PtrList;
	while(CurLst != NULL)
	{
		if (/*CurLst->SrcPos == SrcPos &&*/ CurLst->SrcPtr == SrcPtr)
			return true;
		
		CurLst = CurLst->next;
	}
	
	return false;
}

static void AddPtrToList(UINT16 SrcPos, UINT16 SrcPtr, UINT8 CoordFlag)
{
	PTR_LIST* CurLst;
	PTR_LIST* TempLst;
	OFS_LIST* CurOfs;
	OFS_LIST* TempOfs;
	DATAPTR_LIST* TempDPtr;
	
	CurLst = PtrList;
	while(CurLst != NULL)
	{
		if (CurLst->SrcPtr == SrcPtr)
		{
			// Pointer-Destination found - Add source offset to the list
			CurOfs = CurLst->SrcPosLst;
			while(CurOfs != NULL)
			{
				if (CurOfs->Ofs == SrcPos)
					return;
				
				TempOfs = CurOfs;
				CurOfs = CurOfs->next;
			}
			CurOfs = TempOfs;
			
			TempOfs = (OFS_LIST*)malloc(sizeof(OFS_LIST));
			TempOfs->Ofs = SrcPos;
			TempOfs->CoordFlg = CoordFlag;
			TempOfs->next = NULL;
			TempDPtr = (DATAPTR_LIST*)malloc(sizeof(DATAPTR_LIST));
			TempDPtr->Ofs = SrcPos;
			TempDPtr->Item = CurLst;
			TempDPtr->next = NULL;
			
			// every SrcPosLst has at least 1 entry, so I don't need to
			// check for CurOfs == NULL
			CurOfs->next = TempOfs;
			SrcPosPtrLEnd->next = TempDPtr;
			SrcPosPtrLEnd = TempDPtr;
			return;
		}
		
		CurLst = CurLst->next;
	}
	
	// Pointer-Dest. not found - add pointer + offset;
	TempLst = (PTR_LIST*)malloc(sizeof(PTR_LIST));
	TempOfs = (OFS_LIST*)malloc(sizeof(OFS_LIST));
	
	TempLst->SrcPosLst = TempOfs;
	TempOfs->Ofs = SrcPos;
	TempOfs->CoordFlg = CoordFlag;
	TempOfs->next = NULL;
	TempLst->DstPosLst = NULL;
	TempLst->SrcPtr = SrcPtr;
	TempLst->CoordFlg = CoordFlag;
	TempLst->DstPtr = 0xFFFF;
	TempLst->next = NULL;
	if (PtrLEnd == NULL)
		PtrList = TempLst;
	else
		PtrLEnd->next = TempLst;
	PtrLEnd = TempLst;
	
	TempDPtr = (DATAPTR_LIST*)malloc(sizeof(DATAPTR_LIST));
	TempDPtr->Ofs = SrcPos;
	TempDPtr->Item = TempLst;
	TempDPtr->next = NULL;
	if (SrcPosPtrList == NULL)
		SrcPosPtrList = TempDPtr;
	else
		SrcPosPtrLEnd->next = TempDPtr;
	SrcPosPtrLEnd = TempDPtr;
	
	return;
}

static void AddNewPtrOfsToList(UINT16 SrcPtr, UINT16 DstOfs, UINT8 CoordFlag)
{
	PTR_LIST* CurLst;
	OFS_LIST* CurOfs;
	OFS_LIST* TempOfs;
	
	CurLst = PtrList;
	while(CurLst != NULL)
	{
		if (CurLst->SrcPtr == SrcPtr)
			break;
		
		CurLst = CurLst->next;
	}
	if (CurLst == NULL)
		return;
	
	// Pointer found - write Location of New Pointer
	CurOfs = TempOfs = CurLst->DstPosLst;
	while(CurOfs != NULL)
	{
		if (CurOfs->Ofs == DstOfs)
			return;	// no duplicated (just in case)
				
		TempOfs = CurOfs;
		CurOfs = CurOfs->next;
	}
	CurOfs = TempOfs;	// go back to last list entry
	
	TempOfs = (OFS_LIST*)malloc(sizeof(OFS_LIST));
	TempOfs->Ofs = DstOfs;
	TempOfs->CoordFlg = CoordFlag;
	TempOfs->next = NULL;
	if (CurLst->DstPosLst == NULL)
		CurLst->DstPosLst = TempOfs;
	else
		CurOfs->next = TempOfs;
	
	return;
}

static void AddNewPosToList(UINT16 SrcPos, UINT16 DstPos)
{
	PTR_LIST* CurLst;
	
	CurLst = PtrList;
	while(CurLst != NULL)
	{
		if (CurLst->SrcPtr == SrcPos)
		{
			// SrcPos is the Destination-Offset of a Pointer
			// -> set new Offset
			CurLst->DstPtr = DstPos;
			return;
		}
		
		CurLst = CurLst->next;
	}
	
	return;
}

static void AddNewPtrOfsToList_FromOfs(UINT16 SrcOfs, UINT16 DstOfs, UINT8 CoordFlag)
{
	DATAPTR_LIST* CurDPtr;
	PTR_LIST* CurLst;
	OFS_LIST* CurOfs;
	OFS_LIST* TempOfs;
	
	// that's faster
	CurDPtr = SrcPosPtrList;
	while(CurDPtr != NULL)
	{
		if (CurDPtr->Ofs == SrcOfs)
			break;
		
		CurDPtr = CurDPtr->next;
	}
	if (CurDPtr == NULL)
		return;
	CurLst = CurDPtr->Item;
	
	// Pointer found - write Location of New Pointer
	CurOfs = TempOfs = CurLst->DstPosLst;
	while(CurOfs != NULL)
	{
		if (CurOfs->Ofs == DstOfs)
			return;	// no duplicated (just in case)
				
		TempOfs = CurOfs;
		CurOfs = CurOfs->next;
	}
	CurOfs = TempOfs;	// go back to last list entry
	
	TempOfs = (OFS_LIST*)malloc(sizeof(OFS_LIST));
	TempOfs->Ofs = DstOfs;
	TempOfs->CoordFlg = CoordFlag;
	TempOfs->next = NULL;
	if (CurLst->DstPosLst == NULL)
		CurLst->DstPosLst = TempOfs;
	else
		CurOfs->next = TempOfs;
	
	return;
}

void ReadSMPSHeader(void)
{
	// search for all pointers
	UINT8 CurChn;
	UINT16 CurPos;
	UINT16 CurPtr;
	
	PtrList = PtrLEnd = NULL;
	SrcPosPtrList = SrcPosPtrLEnd = NULL;
	SMPSOffset = 0x0000;
	
	CurPos = 0x00;
	CurPtr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
	FMChnCnt = SMPSData[CurPos + 0x02];
	PSGChnCnt = SMPSData[CurPos + 0x03];
	if ((FMChnCnt > 0x07 || PSGChnCnt > 0x04) && ! SkipChecks)
	{
		ChnCnt = 0x00;
		return;
	}
	ChnCnt = FMChnCnt + PSGChnCnt;
	CurPos += 0x06;
	
	ChnList = (CHN_HEAD*)malloc(ChnCnt * sizeof(CHN_HEAD));
	ChnListSort = (UINT8*)malloc(ChnCnt * sizeof(UINT8));
	for (CurChn = 0x00; CurChn < FMChnCnt; CurChn ++)
	{
		ChnList[CurChn].Ptr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
		CurPos += 0x04;
	}
	for (CurChn = 0x00; CurChn < PSGChnCnt; CurChn ++)
	{
		ChnList[FMChnCnt + CurChn].Ptr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
		CurPos += 0x06;
	}
	MakeSortedChannelList();
	
	UseInsBank = false;
	if (GET_CNV_SRC(PtrMode) == CPTR_Z80)
	{
		// Try to guess the Z80 offset (should work with most files)
		// Note: CurPtr is already set to a valid value - the instrument table
		//if (! (CurPtr & 0x8000))
		if ((ChnList[ChnListSort[0x00]].Ptr ^ CurPtr) & 0x8000)
		{
			printf("This song seems to use the global Sonic 3 Instrument Bank.\n");
			CurPtr = 0xFFFF;	// set to the maximum pointer value
			UseInsBank = true;
		}
		
		CurPtr = 0xFFFF;	// afterthought: it's quite unlikely to have the instrument
							// table between header and actual smps data
							// but it's possible
		if (ChnList[ChnListSort[0x00]].Ptr < CurPtr)
			CurPtr = ChnList[ChnListSort[0x00]].Ptr;
		SMPSOffset = CurPtr - CurPos;
	}
	
	for (CurChn = 0x00; CurChn < InsBank.InsCount; CurChn ++)
	{
		InsBank.InsAssign[CurChn].IsUsed = 0x00;
		InsBank.InsAssign[CurChn].NewID = 0x00;
	}
	
	return;
}

static void MakeSortedChannelList(void)
{
	UINT8 CurChn;
	UINT8 CurChn2;
	UINT16* TempArr;
	UINT16 MinPtr;
	UINT8 MinChn;
	
	TempArr = (UINT16*)malloc(ChnCnt * sizeof(UINT16));
	for (CurChn = 0x00; CurChn < ChnCnt; CurChn ++)
		TempArr[CurChn] = ChnList[CurChn].Ptr;
	
	for (CurChn = 0x00; CurChn < ChnCnt; CurChn ++)
	{
		MinPtr = TempArr[0x00];
		MinChn = 0x00;
		for (CurChn2 = 0x01; CurChn2 < ChnCnt; CurChn2 ++)
		{
			if (TempArr[CurChn2] < MinPtr)
			{
				MinPtr = TempArr[CurChn2];
				MinChn = CurChn2;
			}
		}
		ChnListSort[CurChn] = MinChn;
		TempArr[MinChn] = 0xFFFF;
	}
	
	free(TempArr);
	
	return;
}

static bool GetProcMask(UINT16 Pos)
{
	// returns ProcMask[Pos >> 3], Bit (Pos & 0x07)
	return (ProcMask[Pos >> 3] >> (Pos & 0x07)) & 0x01;
}

static void SetProcMask(UINT16 Pos, UINT16 Len)
{
	UINT16 CurPos;
	UINT16 MskPos;
	
	for (CurPos = 0x00, MskPos = Pos; CurPos < Len; CurPos ++, MskPos ++)
	{
		//BitPos = MskPos & 0x07;
		//BytPos = MskPos >> 3;
		//ProcMask[BytPos] |= 1 << BitPos;
		ProcMask[MskPos >> 3] |= 1 << (MskPos & 0x07);
	}

	return;
}

UINT16 GetProcMaskNonusage(void)
{
	UINT32 CurPos;
	UINT32 UnusedBytes;
	
	UnusedBytes = 0x00;
	for (CurPos = 0x00; CurPos < SMPSLen; CurPos ++)
	{
		if (! GetProcMask(CurPos))
			UnusedBytes ++;
	}
	
	return (UINT16)UnusedBytes;
}

void PrintProcMaskNonusage(void)
{
	UINT32 CurPos;
	UINT32 UnusedSt;
	
	UnusedSt = 0xFFFFFFFF;
	for (CurPos = 0x00; CurPos < SMPSLen; CurPos ++)
	{
		if (! GetProcMask(CurPos))
		{
			if (UnusedSt == 0xFFFFFFFF)
				UnusedSt = CurPos;
		}
		else
		{
			if (UnusedSt != 0xFFFFFFFF)
			{
				if (UnusedSt == CurPos - 0x01)
					printf("0x%04X (0x%02X)\n", UnusedSt, SMPSData[UnusedSt]);
				else
					printf("0x%04X - 0x%04X (0x%X bytes)\n", UnusedSt, CurPos - 0x01, CurPos - UnusedSt);
				UnusedSt = 0xFFFFFFFF;
			}
		}
	}
	if (UnusedSt != 0xFFFFFFFF)
	{
		if (UnusedSt == CurPos - 0x01)
			printf("0x%04X (0x%02X)\n", UnusedSt, SMPSData[UnusedSt]);
		else
			printf("0x%04X - 0x%04X (0x%X bytes)\n", UnusedSt, CurPos - 0x01, CurPos - UnusedSt);
	}
	
	return;
}

static void FillCFStructs(COORD_FLAG* CFMain, COORD_FLAG* CFExt, UINT8 CFMode)
{
	UINT8 CurFlag;
	COORD_FLAG* TempFlag;
	
	TempFlag = CFMain;
	for (CurFlag = 0xE0; CurFlag < 0xFF; CurFlag ++, TempFlag ++)
	{
		TempFlag->Len = 0x01;
		TempFlag->Type = CFTYPE_UNUSED;
		TempFlag->JmpOfs = 0x00;	// default is no offset
		TempFlag->reserved = 0x00;
		if (CurFlag >= 0xFA && CFMode == CFMODE_S1)
		{
			TempFlag->Type = CFTYPE_INVALID;
			continue;
		}
		
		if (CFMode == CFMODE_ORNS)
		{
			// OutRunners has a very reduces SMPS command set.
			// It looks more clean to handle it this way.
			switch(CurFlag)
			{
			case 0xE0:	// Pan
			case 0xE1:	// Frequency Displacement
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_NO_CHANGE;
				break;
			case 0xE2:	// Change Volume (FM)
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_VOLUME;
				break;
			case 0xE3:	// No-Attack
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_SPECIAL;
				break;
			case 0xE4:	// Set Note Fill
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_NOTE_FILL;
				break;
			case 0xE5:	// Change Volume (PSG) [same as E6]
			case 0xE6:	// Change Volume (PSG)
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_VOLUME;
				break;
			case 0xE7:	// Set Instrument
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_FM_INS;
				break;
			case 0xE8:	// Set Modulation
				TempFlag->Len = 0x05;
				TempFlag->Type = CFTYPE_MODULATION;
				break;
			case 0xE9:	// Stop Track
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_STOP_TRACK;
				break;
			case 0xEA:	// Set PSG Noise
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_SPECIAL;
				break;
			case 0xEB:	// unknown
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case 0xEC:	// Set PSG instrument
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_PSG_INS;
				break;
			case 0xED:	// Jump
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_GOTO;
				TempFlag->JmpOfs = 0x01;
				break;
			case 0xEE:	// Loop
				TempFlag->Len = 0x05;
				TempFlag->Type = CFTYPE_LOOP;
				TempFlag->JmpOfs = 0x03;
				break;
			case 0xEF:	// Call Subroutine
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_GOSUB;
				TempFlag->JmpOfs = 0x01;
				break;
			case 0xF0:	// Return
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_RETURN;
				break;
			case 0xF1:	// Change Key Displacement
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_KEY_DISPLC;
				break;
			case 0xF2:	// unknown
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case 0xF3:	// unknown
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			default:
				TempFlag->Type = CFTYPE_INVALID;
				break;
			}
			continue;
		}
		
		switch(CurFlag)
		{
		case 0xE0:	// Pan
		case 0xE1:	// Frequency Displacement
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_NO_CHANGE;
			break;
		case 0xE2:
			switch(CFMode)
			{
			case CFMODE_S1:		// set unused RAM variable
			case CFMODE_TRS:
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_NO_CHANGE;
				break;
			case CFMODE_S3K:	// Fade In
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_SPECIAL;
				break;
			}
			break;
		case 0xE3:
			switch(CFMode)
			{
			case CFMODE_S1:		// Return
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_RETURN;
				break;
			case CFMODE_S3K:	// Stop Track - same as F2
			case CFMODE_TRS:
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_STOP_TRACK;
				break;
			}
			break;
		case 0xE4:
			switch(CFMode)
			{
			case CFMODE_S1:		// Stop Track and prepare Fade In
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_SPECIAL;
				break;
			case CFMODE_S3K:	// Set Volume
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_VOLUME;
				break;
			case CFMODE_TRS:	// Set Pan Animation
				TempFlag->Len = 0x82;	// 0x02 [+ 0x04]
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			}
			break;
		case 0xE5:
			switch(CFMode)
			{
			case CFMODE_S1:		// set Tempo Divider
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_TEMPO;
				break;
			case CFMODE_S3K:	// Change Volume (FM)
			case CFMODE_TRS:
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_VOLUME;
				break;
			}
			break;
		case 0xE6:	// Change Volume (FM)
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_VOLUME;
			break;
		case 0xE7:	// No-Attack
			TempFlag->Len = 0x01;
			TempFlag->Type = CFTYPE_NO_CHANGE;
			break;
		case 0xE8:	// Set Note Fill
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_NOTE_FILL;
			break;
		case 0xE9:
			switch(CFMode)
			{
			case CFMODE_S1:		// Change Key Displacement
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_KEY_DISPLC;
				break;
			//case CFMODE_S3K:	// Spindash Rev.
			//	TempFlag->Len = 0x01;
			//	TempFlag->Type = CFTYPE_UNUSED;
			//	break;
			case CFMODE_TRS:	// Set LFO parameters
			case CFMODE_S3K:	// LFO for SMPS Z80 in general
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			}
			break;
		case 0xEA:
			switch(CFMode)
			{
			case CFMODE_S1:		// Set Tempo Modifier
			case CFMODE_TRS:	// Set Tempo Modifier
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_TEMPO;
				break;
			case CFMODE_S3K:	// Play DAC Sample
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			}
			break;
		case 0xEB:
			switch(CFMode)
			{
			case CFMODE_S1:		// Set Tempo Divider for ALL Tracks
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_TEMPO;
				break;
			case CFMODE_S3K:	// Conditional Jump
				TempFlag->Len = 0x04;
				TempFlag->Type = CFTYPE_LP_JMP;
				TempFlag->JmpOfs = 0x02;
				break;
			case CFMODE_TRS:	// Play Sound ID
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			}
			break;
		case 0xEC:	// Change Volume (PSG)
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_VOLUME;
			break;
		case 0xED:
			switch(CFMode)
			{
			case CFMODE_S1:		// Clear 'pushing block' flag
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_NO_CHANGE;
				break;
			case CFMODE_S3K:	// Set Key Displacement (to Param. - 0x40)
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_KEY_DISPLC;
				break;
			case CFMODE_TRS:	// Send Command to FM channel
				if (1)	// PS4: DAC Pan Setting
				{
					TempFlag->Len = 0x02;
					TempFlag->Type = CFTYPE_UNUSED;
				}
				else
				{
					TempFlag->Len = 0x03;
					TempFlag->Type = CFTYPE_UNUSED;
				}
				break;
			}
			break;
		case 0xEE:
			switch(CFMode)
			{
			case CFMODE_S1:	// SFX-related
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_STOP_TRACK;
				break;
			case CFMODE_S3K:	// Send YM2612 command to FM port 0
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case CFMODE_TRS:	// Send YM2612 command to FM port 0
				if (1)	// PS4: set DAC sound
				{
					TempFlag->Len = 0x02;
					TempFlag->Type = CFTYPE_UNUSED;
				}
				else
				{
					TempFlag->Len = 0x03;
					TempFlag->Type = CFTYPE_UNUSED;
				}
				break;
			}
			break;
		case 0xEF:	// Set Instrument
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_FM_INS;
			if (CFMode == CFMODE_S3K)
				TempFlag->Len |= 0x80;	// variable arguments
			break;
		case 0xF0:	// Set Modulation
			TempFlag->Len = 0x05;
			TempFlag->Type = CFTYPE_MODULATION;
			break;
		case 0xF1:
			switch(CFMode)
			{
			case CFMODE_S1:		// Enable Modulation
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_MODULATION;
				break;
			case CFMODE_S3K:	// Set Modulation Type
			case CFMODE_TRS:	// Set Modulation Type
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_MODULATION;
				break;
			}
			break;
		case 0xF2:	// Stop Track
			TempFlag->Len = 0x01;
			TempFlag->Type = CFTYPE_STOP_TRACK;
			break;
		case 0xF3:	// Set PSG Noise
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_NO_CHANGE;
			break;
		case 0xF4:
			switch(CFMode)
			{
			case CFMODE_S1:		// Disable Modulation
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_MODULATION;
				break;
			case CFMODE_S3K:	// Set Modulation Type
			case CFMODE_TRS:	// Set Modulation Type
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_MODULATION;
				break;
			}
			break;
		case 0xF5:	// Set PSG instrument
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_PSG_INS;
			break;
		case 0xF6:	// Jump
			TempFlag->Len = 0x03;
			TempFlag->Type = CFTYPE_GOTO;
			TempFlag->JmpOfs = 0x01;
			break;
		case 0xF7:	// Loop
			TempFlag->Len = 0x05;
			TempFlag->Type = CFTYPE_LOOP;
			TempFlag->JmpOfs = 0x03;
			break;
		case 0xF8:	// Call Subroutine
			TempFlag->Len = 0x03;
			TempFlag->Type = CFTYPE_GOSUB;
			TempFlag->JmpOfs = 0x01;
			break;
		case 0xF9:
			switch(CFMode)
			{
			case CFMODE_S1:		// Silence FM1
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_SPECIAL;
				break;
			case CFMODE_S3K:	// Return
			case CFMODE_TRS:	// Return
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_RETURN;
				break;
			}
			break;
		case 0xFA:
			switch(CFMode)
			{
			case CFMODE_S3K:	// Disable Modulation
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_MODULATION;
				break;
			case CFMODE_TRS	:	// set Tempo Divider
				if (0)	// PS4: DAC Reverse Mode
				{
					TempFlag->Len = 0x02;
					TempFlag->Type = CFTYPE_UNUSED;
				}
				else
				{
					TempFlag->Len = 0x02;
					TempFlag->Type = CFTYPE_TEMPO;
				}
				break;
			}
			break;
		case 0xFB:	// Change Key Displacement
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_KEY_DISPLC;
			break;
		case 0xFC:
			switch(CFMode)
			{
			case CFMODE_S3K:	// for Continuous SFX
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case CFMODE_TRS:	// Enable Modulation
				if (0)	// PS4: set DAC volume
				{
					TempFlag->Len = 0x02;
					TempFlag->Type = CFTYPE_UNUSED;
				}
				else
				{
					TempFlag->Len = 0x01;
					TempFlag->Type = CFTYPE_MODULATION;
				}
				break;
			}
			break;
		case 0xFD:
			switch(CFMode)
			{
			case CFMODE_S3K:	// Enable alternate SMPS mode
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_SPECIAL;
				break;
			case CFMODE_TRS:	// Disable Modulation
				if (0)	// PS4: set DAC Track Mode
				{
					TempFlag->Len = 0x02;
					TempFlag->Type = CFTYPE_UNUSED;
				}
				else
				{
					TempFlag->Len = 0x01;
					TempFlag->Type = CFTYPE_MODULATION;
				}
				break;
			}
			break;
		case 0xFE:
			switch(CFMode)
			{
			case CFMODE_S3K:	// Enbale FM3 Special Mode
			case CFMODE_TRS:	// Enbale FM3 Special Mode
				TempFlag->Len = 0x05;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			}
			break;
		}
	}
	
	TempFlag = CFExt;
	for (CurFlag = 0x00; CurFlag < 0x10; CurFlag ++, TempFlag ++)
	{
		TempFlag->Len = 0x02;
		TempFlag->Type = CFTYPE_UNUSED;
		TempFlag->JmpOfs = 0x00;	// default is no offset
		TempFlag->reserved = 0x00;
		if (CFMode == CFMODE_S1 || CFMode == CFMODE_ORNS)
		{
			TempFlag->Len = 0x01;
			TempFlag->Type = CFTYPE_INVALID;
			continue;
		}
		
		switch(CurFlag)
		{
		case 0x00:
			switch(CFMode)
			{
			case CFMODE_S3K:	// Set Tempo Modifier
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_TEMPO;
				break;
			}
			break;
		case 0x01:
			switch(CFMode)
			{
			case CFMODE_S3K:	// Play Sound
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			}
			break;
		case 0x02:
			switch(CFMode)
			{
			case CFMODE_S3K:	// Halt (or resume) music
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case CFMODE_TRS:	// Set Tempo Divider for ALL Tracks
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_TEMPO;
				break;
			}
			break;
		case 0x03:
			switch(CFMode)
			{
			case CFMODE_S3K:	// Copy Data
				TempFlag->Len = 0x05;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			}
			break;
		case 0x04:
			switch(CFMode)
			{
			case CFMODE_S3K:	// Set Tempo Divider for ALL Tracks
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_TEMPO;
				break;
			}
			break;
		case 0x05:
			switch(CFMode)
			{
			case CFMODE_S3K:	// Set SSG-EG data
				TempFlag->Len = 0x06;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			}
			break;
		case 0x06:
			switch(CFMode)
			{
			case CFMODE_S3K:	// Start FM Flutter
				TempFlag->Len = 0x04;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case CFMODE_TRS:	// Ristar: unknown
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			}
			break;
		case 0x07:
			switch(CFMode)
			{
			case CFMODE_S3K:	// Reset spindash rev.
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case CFMODE_TRS:	// Ristar: unknown
				TempFlag->Len = 0x04;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			}
			break;
		case 0x08:
			switch(CFMode)
			{
			case CFMODE_S3K:	// Set Tempo Divider (Flamewing's S&K driver mod only)
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_TEMPO;
				break;
			case CFMODE_TRS:	// Ristar: unknown
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			}
			break;
		case 0x09:
			switch(CFMode)
			{
			case CFMODE_S3K:	// Send Channel YM2612 Command (Flamewing's S&K driver mod only)
				TempFlag->Len = 0x04;
				TempFlag->Type = CFTYPE_NOTE_FILL;
				break;
			}
			break;
		case 0x0A:
			switch(CFMode)
			{
			case CFMODE_S3K:	// Set Note Fill (Flamewing's S&K driver mod only)
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_NOTE_FILL;
				break;
			}
			break;
		}
	}
	TempFlag = &CFExt[0x10];
	TempFlag->Len = 0x02;
	TempFlag->Type = CFTYPE_INVALID;
	TempFlag->JmpOfs = 0x00;
	TempFlag->reserved = 0x00;
	
	return;
}

void PreparseSMPS(void)
{
	// preparse complete SMPS file to get all pointers
	UINT8 CurChn;
	UINT16 CurPos;
	UINT16 CurPtr;
	bool TrackEnd;
	UINT8 GosubID;
	UINT16 GosubPtr[0x100];
	UINT16 InsPtr;
	UINT8 CoordFlg;
	COORD_FLAG* CurFlg;
	UINT16 TempPtr;
	
	memset(ProcMask, 0x00, ProcMskSize);
	FillCFStructs(CFMain, CFExt, GET_CNV_SRC(CoordMode));
	
	CurPos = 0x00;
	InsPtr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
	AddPtrToList(CurPos + 0x00, InsPtr, 0x7F);	// Instrument List Pointer
	SetProcMask(CurPos, 0x06);
	CurPos += 0x06;
	
	// recalc pointers with new SMPS Offset
	for (CurChn = 0x00; CurChn < FMChnCnt; CurChn ++)
	{
		CurPtr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
		AddPtrToList(CurPos + 0x00, CurPtr, 0x00 | CurChn);
		ChnList[CurChn].Ptr = CurPtr;
		SetProcMask(CurPos, 0x04);
		CurPos += 0x04;
	}
	for (CurChn = 0x00; CurChn < PSGChnCnt; CurChn ++)
	{
		CurPtr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
		AddPtrToList(CurPos + 0x00, CurPtr, 0x10 | CurChn);
		ChnList[FMChnCnt + CurChn].Ptr = CurPtr;
		SetProcMask(CurPos, 0x06);
		CurPos += 0x06;
	}
	
	for (CurChn = 0x00; CurChn < ChnCnt; CurChn ++)
	{
		// Parse Channel Data
		CurPos = ChnList[ChnListSort[CurChn]].Ptr;
		TrackEnd = false;
		GosubID = 0x00;
		
		while(! TrackEnd && CurPos < SMPSLen)
		{
			if (SMPSData[CurPos] < 0xE0)
			{
				SetProcMask(CurPos, 0x01);
				CurPos ++;
			}
			else
			{
				CoordFlg = SMPSData[CurPos + 0x00];
				if (CoordFlg < 0xFF)
				{
					CurFlg = &CFMain[CoordFlg & 0x1F];
				}
				else if (CoordFlg == 0xFF)
				{
					if (SMPSData[CurPos + 0x01] < 0x10)
						CurFlg = &CFExt[SMPSData[CurPos + 0x01]];
					else
						CurFlg = &CFExt[0x10];
				}
				
				switch(CurFlg->Type)
				{
				case CFTYPE_STOP_TRACK:
					TrackEnd = true;
					SetProcMask(CurPos, CurFlg->Len);
					CurPos += CurFlg->Len;
					break;
				// enumerate instruments
				case CFTYPE_FM_INS:
					if (CurChn < FMChnCnt)
					{
						if (SMPSData[CurPos + 0x01] < InsBank.InsCount)
						{
							InsBank.InsAssign[SMPSData[CurPos + 0x01]].IsUsed = 0x01;
						}
					}
					
					CurPtr = CurFlg->Len;
					if (CurPtr & 0x80)
					{
						CurPtr &= 0x7F;
						if (GET_CNV_SRC(CoordMode) == CFMODE_S3K && CoordFlg == 0xEF)
						{
							if (SMPSData[CurPos + 0x01] & 0x80)
								CurPtr += 0x01;
						}
					}
					SetProcMask(CurPos, CurPtr);
					CurPos += CurPtr;
					break;
				// Jumps with Pointer
				case CFTYPE_LOOP:
				case CFTYPE_LP_JMP:
				case CFTYPE_GOTO:
					TempPtr = CurPos + CurFlg->JmpOfs;
					CurPtr = Get16Ptr(&SMPSData[TempPtr], TempPtr);
					AddPtrToList(TempPtr, CurPtr, CoordFlg);
					SetProcMask(CurPos, CurFlg->Len);
					CurPos += CurFlg->Len;
					
					if (CurFlg->Type == CFTYPE_GOTO)
					{
						// if we jump to an offset that's already processed,
						// then it's definately a loop
						if (GetProcMask(CurPtr))
							if (! GosubID)	// TODO: can cause freezes
								TrackEnd = true;
						
						CurPos = CurPtr;
					}
					break;
				case CFTYPE_GOSUB:
					TempPtr = CurPos + CurFlg->JmpOfs;
					CurPtr = Get16Ptr(&SMPSData[TempPtr], TempPtr);
					AddPtrToList(TempPtr, CurPtr, CoordFlg);
					SetProcMask(CurPos, CurFlg->Len);
					CurPos += CurFlg->Len;
					
					if (! GetProcMask(CurPtr))
					{
						if (GosubID < 0x100)
						{
							GosubPtr[GosubID] = CurPos;
							GosubID ++;
							CurPos = CurPtr;
						}
						else
						{
							printf("Error on Track %u, Pos 0x%04X: Subroutine skipped (buffer too small)!\n",
									CurChn, CurPos);
						}
					}
					break;
				case CFTYPE_RETURN:
					SetProcMask(CurPos, CurFlg->Len);
					CurPos += CurFlg->Len;
					if (GosubID)
					{
						GosubID --;
						CurPos = GosubPtr[GosubID];
					}
					else
					{
						printf("Error on Track %u, Pos 0x%04X: Invalid Subroutine-Return found!\n",
								CurChn, CurPos);
						TrackEnd = true;
					}
					break;
				default:
					CurPtr = CurFlg->Len;
					if (CurPtr & 0x80)
					{
						CurPtr &= 0x7F;
						if (GET_CNV_SRC(CoordMode) == CFMODE_TRS && CoordFlg == 0xE4)
						{
							if (SMPSData[CurPos + 0x01])
								CurPtr += 0x04;
						}
						/*else if (GET_CNV_SRC(CoordMode) == CFMODE_S3K && CoordFlg == 0xEF)
						{
							if (SMPSData[CurPos + 0x01] & 0x80)
								CurPtr += 0x01;
						}*/
					}
					SetProcMask(CurPos, CurPtr);
					CurPos += CurPtr;
					break;
				}
			}
		}
	}
	
	return;
}

static UINT8 TempoConv(UINT8 TempoMod)
{
	UINT16 RealTmpMod;	// 0x01 to 0x100 for Sonic 1
	
	if (GET_CNV_SRC(TempoMode) == GET_CNV_DST(TempoMode))
		return TempoMod;
	
	if (GET_CNV_SRC(TempoMode) == CTEMPO_S1)
		RealTmpMod = (UINT16)((TempoMod - 1) & 0xFF) + 1;	// 0x00 = 0x100
	else
		RealTmpMod = TempoMod;
	
	// MAKE_CNV_SD(TempoFrom, TempoTo)
	switch(TempoMode)
	{
	case MAKE_CNV_SD(CTEMPO_S3K, CTEMPO_S1):
		if (TempoMod >= 0x01)
			RealTmpMod = (0x100 + (TempoMod >> 1)) / TempoMod;
		else
			RealTmpMod = 0x00;
		return (RealTmpMod == 0x01) ? 0x02 : (RealTmpMod & 0xFF);
	case MAKE_CNV_SD(CTEMPO_S3K, CTEMPO_S2):
	case MAKE_CNV_SD(CTEMPO_S2, CTEMPO_S3K):
		return ~TempoMod;
	case MAKE_CNV_SD(CTEMPO_S1, CTEMPO_S2):
		if (RealTmpMod == 0x01)	// broken tempo
			return 0x00;
		return ((RealTmpMod - 1) * 0x100 + (RealTmpMod >> 1)) / RealTmpMod;
	case MAKE_CNV_SD(CTEMPO_S2, CTEMPO_S1):
		if (TempoMod == 0x00)	// broken tempo
			return 0x01;
		RealTmpMod = ((0x300 - TempoMod) >> 1) / (0x100 - TempoMod);
		return (RealTmpMod == 0x01) ? 0x02 : (RealTmpMod & 0xFF);
	case MAKE_CNV_SD(CTEMPO_S1, CTEMPO_S3K):
		// S3K has no broken tempo
		return ~(((RealTmpMod - 1) * 0x100 + (RealTmpMod >> 1)) / RealTmpMod);
	}
	
	return TempoMod;
}

static UINT8 DACSndPatch(UINT8 DACSnd)
{
	UINT8 MapID;
	
	if (DACSnd <= 0x80)
		return DACSnd;
	
	// DAC Sounds go from 81 to DF
	MapID = DACSnd - 0x81;
	if (MapID < DACMap.MapCount)
	{
		if (DACMap.Map[MapID].MapFrom == 0xFF)
		{
			DACMap.Map[MapID].MapFrom = 0x00;
			if (DACMap.DoWarn)
				printf("Warning: Unmapped DAC sound $%02X found!\n", DACSnd);
		}
		else if (DACMap.Map[MapID].MapFrom == DACSnd)
		{
			DACSnd = DACMap.Map[MapID].MapTo;
		}
	}
	DACSnd += DACMap.Add;
	DACSnd |= 0x80;
	if (DACSnd >= 0xE0)
		DACSnd = 0x80;
	
	return DACSnd;
}

static UINT8 PSGInsPatch(UINT8 PSGIns)
{
	UINT8 MapID;
	
	if (PSGIns == 0x00)
		return 0x00;
	
	// PSG instrument 00 is locked
	MapID = PSGIns - 0x01;
	if (MapID < PSGMap.MapCount)
	{
		if (PSGMap.Map[MapID].MapFrom == 0xFF)
		{
			PSGMap.Map[MapID].MapFrom = 0x00;
			if (PSGMap.DoWarn)
				printf("Warning: Unmapped PSG instrument $%02X found!\n", PSGIns);
		}
		else if (PSGMap.Map[MapID].MapFrom == PSGIns)
		{
			PSGIns = PSGMap.Map[MapID].MapTo;
		}
	}
	PSGIns += PSGMap.Add;
	PSGIns &= 0x7F;
	
	return PSGIns;
}

static void IgnoreMsg(UINT8 CurChn, UINT16 CurPos)
{
	if (SMPSData[CurPos] < 0xFF)
	{
		printf("Track %u, Pos 0x%04X: Ignored Command %02X!\n",
				CurChn, CurPos, SMPSData[CurPos + 0x00]);
	}
	else
	{
		printf("Track %u, Pos 0x%04X: Ignored Command %02X %02X!\n",
				CurChn, CurPos, SMPSData[CurPos + 0x00], SMPSData[CurPos + 0x01]);
	}
	
	return;
}

static void WarningMsg(UINT8 CurChn, UINT16 CurPos)
{
	if (SMPSData[CurPos] < 0xFF)
	{
		printf("Track %u, Pos 0x%04X: Command %02X!\n",
				CurChn, CurPos, SMPSData[CurPos + 0x00]);
	}
	else
	{
		printf("Track %u, Pos 0x%04X: Command %02X %02X!\n",
				CurChn, CurPos, SMPSData[CurPos + 0x00], SMPSData[CurPos + 0x01]);
	}
	
	return;
}

static void WarningMsgFlame(UINT8 CurChn, UINT16 CurPos, UINT16 NewPos)
{
	printf("Track %u, Pos 0x%04X: Writing S3K-Flamewing Command %02X %02X!\n",
			CurChn, CurPos, SMPSData[NewPos + 0x00], SMPSData[NewPos + 0x01]);
	
	return;
}

static void WarningMsgInvalid(UINT8 CurChn, UINT16 CurPos)
{
	if (SMPSData[CurPos] < 0xFF)
	{
		printf("Track %u, Pos 0x%04X: Invalid Command %02X found!\n",
				CurChn, CurPos, SMPSData[CurPos + 0x00]);
	}
	else
	{
		printf("Track %u, Pos 0x%04X: Invalid Command %02X %02X found!\n",
				CurChn, CurPos, SMPSData[CurPos + 0x00], SMPSData[CurPos + 0x01]);
	}
	
	return;
}

void ConvertSMPS(void)
{
	UINT8 CurChn;
	UINT8 ChnID;
	UINT16 CurPos;
	UINT16 DstPos;
	UINT8 TempoDiv;
	UINT16 CurPtr;
	bool TrackEnd;
	UINT8 CurGosub;
	UINT8 GosubID;
	UINT16 GosubPtr[0x100];
	UINT16 InsPtr;
	UINT8 MaxIns;
	bool TrackBreak;
	UINT8 LastNote;
	UINT8 LastNoteCmd;
	UINT8 NoteDlyMask;
	UINT8 TempByt;
	UINT16 TempSht;
	UINT8 LoopExtra[0x10];
	UINT16 IsInLoop;
	UINT8 CurChnVol;
	UINT8 CurChnKeyDplc;
	COORD_FLAG* TempCF;
	PTR_LIST* CurPtrLst;
	UINT8 CmdLen;
	bool NoCoordConv;
	
	if (UseInsBank)
	{
		MaxIns = 0x00;
		for (TempByt = 0x00; TempByt < InsBank.InsCount; TempByt ++)
		{
			if (InsBank.InsAssign[TempByt].IsUsed)
			{
				InsBank.InsAssign[TempByt].NewID = MaxIns;
				MaxIns ++;
			}
		}
	}
	
	memset(ProcMask, 0x00, ProcMskSize);
	SMPSNewLen = SMPSLen * 2;
	SMPSNewData = (UINT8*)malloc(SMPSNewLen);
	memset(SMPSNewData, 0x00, SMPSNewLen);
	NoCoordConv = (GET_CNV_SRC(CoordMode) == GET_CNV_DST(CoordMode));
	
	CurPos = 0x00;
	DstPos = 0x00;
	InsPtr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
	if (! UseInsBank)
		MaxIns = 0x00;
	
	// 0x00 and 0x01 are set later
	AddNewPtrOfsToList_FromOfs(CurPos, DstPos, 0x7F);
	SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];	// FM Chn Count
	SMPSNewData[DstPos + 0x03] = SMPSData[CurPos + 0x03];	// PSG Chn Count
	SMPSNewData[DstPos + 0x04] = SMPSData[CurPos + 0x04] * DuratDivide;	// Tick Multiplier
	SMPSNewData[DstPos + 0x05] = TempoConv(SMPSData[CurPos + 0x05]);	// Tempo
	TempoDiv = SMPSData[CurPos + 0x04];
	
	SetProcMask(CurPos, 0x06);
	CurPos += 0x06;
	DstPos += 0x06;
	
	// recalc pointers with new SMPS Offset
	for (CurChn = 0x00; CurChn < FMChnCnt; CurChn ++)
	{
		CurPtr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
		
		ChnList[CurChn].Ptr = CurPtr;
		ChnList[CurChn].KeyDisplc = SMPSData[CurPos + 0x02];
		ChnList[CurChn].Volume = SMPSData[CurPos + 0x03];
		
		// 0x00 and 0x01 are set later
		AddNewPtrOfsToList_FromOfs(CurPos, DstPos, 0x00 | CurChn);
		SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];
		SMPSNewData[DstPos + 0x03] = SMPSData[CurPos + 0x03];
		
		SetProcMask(CurPos, 0x04);
		CurPos += 0x04;
		DstPos += 0x04;
	}
	for (CurChn = 0x00; CurChn < PSGChnCnt; CurChn ++)
	{
		CurPtr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
		
		ChnList[FMChnCnt + CurChn].Ptr = CurPtr;
		ChnList[FMChnCnt + CurChn].KeyDisplc = SMPSData[CurPos + 0x02];
		ChnList[FMChnCnt + CurChn].Volume = SMPSData[CurPos + 0x03];
		
		// 0x00 and 0x01 are set later
		AddNewPtrOfsToList_FromOfs(CurPos, DstPos, 0x10 | CurChn);
		SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];
		// Note: I don't apply the PSG Frequency patch to ChnList[FMChnCnt + CurChn].KeyDisplc,
		//       because this way I don't need to care about it when processing Flag ED
		if (GET_CNV_SRC(CoordMode) == CFMODE_S3K && GET_CNV_DST(CoordMode) != CFMODE_S3K)
		{
			// convert from S3K to S1
			SMPSNewData[DstPos + 0x02] -= 12;
		}
		else if (GET_CNV_SRC(CoordMode) != CFMODE_S3K && GET_CNV_DST(CoordMode) == CFMODE_S3K)
		{
			// convert from S1 to S3K
			SMPSNewData[DstPos + 0x02] += 12;
		}
		SMPSNewData[DstPos + 0x03] = SMPSData[CurPos + 0x03];
		SMPSNewData[DstPos + 0x04] = SMPSData[CurPos + 0x04];
		SMPSNewData[DstPos + 0x05] = PSGInsPatch(SMPSData[CurPos + 0x05]);
		
		SetProcMask(CurPos, 0x06);
		CurPos += 0x06;
		DstPos += 0x06;
	}
	
#if 1
	//CurPtr = ChnList[ChnListSort[0x00]].Ptr;
	//if (InsPtr < CurPtr)
	//	CurPtr = InsPtr;
	CurPtr = InsPtr;	// The first pointers are actually InsPtr, then ChnList[...].Ptr
	CurPtrLst = PtrList;
	while(CurPtrLst != NULL)
	{
		if (CurPtrLst->SrcPtr < CurPtr)
			CurPtr = CurPtrLst->SrcPtr;
		CurPtrLst = CurPtrLst->next;
	}
	if (CurPos < CurPtr)
	{
		SetProcMask(CurPos, CurPtr - CurPos);
		while(CurPos < CurPtr)
		{
			SMPSNewData[DstPos] = SMPSData[CurPos];
			CurPos ++;	DstPos ++;
		}
	}
#endif
	
	for (ChnID = 0x00; ChnID < ChnCnt; ChnID ++)
	{
		// Parse Channel Data
		CurChn = ChnListSort[ChnID];
		CurPos = ChnList[CurChn].Ptr;
		if (CurPos >= SMPSLen)
		{
			printf("Warning: The pointer of track %hu points beyond the End of File!\n", CurChn);
			continue;
		}
		TrackEnd = false;
		TrackBreak = false;
		CurGosub = 0x00;
		GosubPtr[0x00] = CurPos;
		GosubID = 0x01;
		LastNote = 0x80;
		LastNoteCmd = 0x80;
		NoteDlyMask = 0x00;
		memset(LoopExtra, 0x00, 0x10);
		IsInLoop = 0x0000;
		CurChnVol = ChnList[CurChn].Volume;
		CurChnKeyDplc = ChnList[CurChn].KeyDisplc;
		if (GetProcMask(CurPos))
			TrackEnd = true;
		
		while(! TrackEnd && ! TrackBreak && CurPos < SMPSLen)
		{
		
		if (! IsInLoop)
			AddNewPosToList(CurPos, DstPos);
		if (SMPSData[CurPos] < 0xE0)
		{
			if (SMPSData[CurPos] >= 0x80)
			{
				NoteDlyMask = 0x01;
				if (CurChn == 0x00)	// DAC Channel)
					LastNoteCmd = DACSndPatch(SMPSData[CurPos]);
				else
					LastNoteCmd = SMPSData[CurPos];
				if (LastNoteCmd >= 0x81)
				{
					LastNote = LastNoteCmd;
					if (CurChn >= FMChnCnt)
					{
						TempByt = (LastNoteCmd - 0x81) + CurChnKeyDplc;
						// fix differences between PSG frequency tables
						if (GET_CNV_SRC(CoordMode) == CFMODE_S3K && GET_CNV_DST(CoordMode) != CFMODE_S3K)
						{
							// S3K -> S1
							TempByt -= 12;
							if (! (TempByt & 0x80))
							{
								if (TempByt >= 71 && LastNoteCmd > 0x81)
								{
									TempByt --;
									LastNoteCmd --;
								}
								if (TempByt >= 69 && LastNoteCmd > 0x81)
								{
									TempByt --;
									LastNoteCmd --;
								}
							}
							else
							{
								printf("Track %u, Pos 0x%04X: Out of Range PSG Note!\n", CurChn, CurPos);
								if (LastNoteCmd < 0xD3)	// 0xD3 = 0xDF - 12
									LastNoteCmd += 12;
							}
						}
						else if (GET_CNV_SRC(CoordMode) != CFMODE_S3K && GET_CNV_DST(CoordMode) == CFMODE_S3K)
						{
							if (! (TempByt & 0x80))
							{
								// S1 -> S3K
								if (TempByt >= 69 && LastNoteCmd < 0xDF)
								{
									TempByt ++;
									LastNoteCmd ++;
								}
							}
						}
					}
				}
				SMPSNewData[DstPos] = LastNoteCmd;
			}
			else
			{
				if (GET_CNV_SRC(CoordMode) == CFMODE_S3K && GET_CNV_DST(CoordMode) != CFMODE_S3K)
				{
					// convert from S3K to S1
					if (! NoteDlyMask && LastNoteCmd == 0x80)
					{
						// 81 02 80 02 02 becomes 81 02 80 02 81 02
						SMPSNewData[DstPos] = LastNote;
						LastNoteCmd = LastNote;
						DstPos ++;
					}
				}
				else if (GET_CNV_SRC(CoordMode) != CFMODE_S3K && GET_CNV_DST(CoordMode) == CFMODE_S3K)
				{
					// convert from S1 to S3K
					if (! NoteDlyMask && LastNoteCmd == 0x80)
					{
						// 81 02 80 02 02 becomes 81 02 80 02 80 02
						SMPSNewData[DstPos] = LastNoteCmd;
						DstPos ++;
					}
				}
				NoteDlyMask >>= 1;
				if (DuratDivide <= 1)
				{
					SMPSNewData[DstPos] = SMPSData[CurPos];
				}
				else
				{
					TempByt = SMPSData[CurPos] % DuratDivide;
					if (TempByt)
						printf("Warning: Dividing duration %u by %u, rest u! (offset %04X)\n",
								SMPSData[CurPos], DuratDivide, TempByt, CurPos);
					TempSht = SMPSData[CurPos] + DuratDivide / 2;	// for proper rounding
					SMPSNewData[DstPos] = (UINT8)(TempSht / DuratDivide);
				}
			}
			
			SetProcMask(CurPos, 0x01);
			CurPos ++;
			DstPos ++;
		}
		else
		{
			NoteDlyMask >>= 1;
			if (SMPSData[CurPos] < 0xFF)
			{
				TempCF = &CFMain[SMPSData[CurPos] & 0x1F];
			}
			else if (SMPSData[CurPos] == 0xFF)
			{
				if (SMPSData[CurPos + 0x01] < 0x10)
					TempCF = &CFExt[SMPSData[CurPos + 0x01]];
				else
					TempCF = &CFExt[0x10];
			}
			
			CmdLen = TempCF->Len & 0x7F;
			if (TempCF->Len & 0x80)
			{
				if (GET_CNV_SRC(CoordMode) == CFMODE_TRS && SMPSData[CurPos] == 0xE4)
				{
					if (SMPSData[CurPos + 0x01])
						CmdLen += 0x04;
				}
				else if (GET_CNV_SRC(CoordMode) == CFMODE_S3K && SMPSData[CurPos] == 0xEF)
				{
					if (SMPSData[CurPos + 0x01] & 0x80)
						CmdLen += 0x01;
				}
			}
			
			if (NoCoordConv && TempCF->Type != CFTYPE_STOP_TRACK && ! TempCF->JmpOfs &&
				TempCF->Type != CFTYPE_RETURN && TempCF->Type != CFTYPE_FM_INS && TempCF->Type != CFTYPE_PSG_INS)
				TempByt = CFTYPE_NO_CHANGE;
			else
				TempByt = TempCF->Type;
			switch(TempByt)
			{
			case CFTYPE_NO_CHANGE:
				for (TempByt = 0x00; TempByt < CmdLen; TempByt ++)
				{
					SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
					if (! IsInLoop)
						AddNewPosToList(CurPos + TempByt, DstPos + TempByt);
				}
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				break;
			case CFTYPE_INVALID:
				WarningMsgInvalid(CurChn, CurPos);
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				break;
			case CFTYPE_UNUSED:
				IgnoreMsg(CurChn, CurPos);
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				break;
			case CFTYPE_STOP_TRACK:	// Flag F2 (all) / E3 (S3K only)
				//actualy E3 silences the FM track before stopping
				SMPSNewData[DstPos] = 0xF2;
				
				TrackEnd = true;
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += 0x01;
				break;
			case CFTYPE_LOOP:	// Flag F7
				SMPSNewData[DstPos + 0x00] = 0xF7;
				SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x01];	// Loop Index
				SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];	// Loop Count
				TempByt = SMPSData[CurPos + 0x01];
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + 0x03], CurPos + 0x03);
				AddNewPtrOfsToList(CurPtr, DstPos + 0x03, 0xF7);
				
				SetProcMask(CurPos, CmdLen);
				if (! LoopExtra[TempByt])
				{
					CurPos += 0x05;
				}
				else if (SMPSNewData[DstPos + 0x02])
				{
					SMPSNewData[DstPos + 0x02] --;
					LoopExtra[TempByt] |= 0x02;
					IsInLoop |= (1 << TempByt);
					CurPos = CurPtr;
				}
				DstPos += CmdLen;
				break;
			case CFTYPE_GOTO:	// Flag F6
				SMPSNewData[DstPos + 0x00] = 0xF6;
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + 0x01], CurPos + 0x01);
				AddNewPtrOfsToList(CurPtr, DstPos + 0x01, 0xF6);
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				
				// if we jump to an offset that's already processed,
				// then it's definately a loop
				if (! GetProcMask(CurPtr))
				{
					if (GosubID < 0x100)
					{
						// Queue jump
						GosubPtr[GosubID] = CurPtr;
						GosubID ++;
					}
					else
					{
						printf("Error: Goto/Gosub Address Buffer too small!\n");
					}
				}
				TrackEnd = true;
				break;
			case CFTYPE_GOSUB:	// Flag F8
				SMPSNewData[DstPos + 0x00] = 0xF8;
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + 0x01], CurPos + 0x01);
				AddNewPtrOfsToList(CurPtr, DstPos + 0x01, 0xF8);
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				LastNoteCmd = 0x00;	// prevent note conversion bugs
				
				/*if (GosubID < 0x100)
				{
					GosubPtr[GosubID] = CurPos;
					GosubID ++;
				}
				else
				{
					printf("Error on Track %u, Pos 0x%04X: Subroutine skipped (buffer too small)!\n",
							CurChn, CurPos);
				}*/
				if (! GetProcMask(CurPtr))
				{
					for (TempByt = 0x00; TempByt < GosubID; TempByt ++)
					{
						if (GosubPtr[TempByt] == CurPtr)
							break;
					}
					if (TempByt >= GosubID)
					{
						if (GosubID < 0x100)
						{
							// Queue jump
							GosubPtr[GosubID] = CurPtr;
							GosubID ++;
						}
						else
						{
							printf("Error: Goto/Gosub Address Buffer too small!\n");
						}
					}
				}
				break;
			case CFTYPE_RETURN:	// Flag E3 (S1/2), Flag F9 (S3K/Trs)
				if (GET_CNV_DST(CoordMode) == CFMODE_S1)
					SMPSNewData[DstPos + 0x00] = 0xE3;
				else
					SMPSNewData[DstPos + 0x00] = 0xF9;
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				/*if (GosubID)
				{
					GosubID --;
					CurPos = GosubPtr[GosubID];
				}
				else
				{
					printf("Error on Track %u, Pos 0x%04X: Invalid Subroutine-Return found!\n",
							CurChn, CurPos);
					TrackBreak = true;
				}*/
				TrackEnd = true;
				break;
			case CFTYPE_LP_JMP:	// Flag EB (S3K only)
				// The conditional jump was now confirmed to work correctly.
				//printf("Track %u, Pos 0x%04X: Conditional Jump EB found!\n", CurChn, CurPos);
				TempByt = SMPSData[CurPos + 0x01];
				CurPtr = Get16Ptr(&SMPSData[CurPos + 0x02], CurPos + 0x02);
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				
				if (! LoopExtra[TempByt])
				{
					LoopExtra[TempByt] = 0x01;
				}
				else
				{
					// jump
					LoopExtra[TempByt] = 0x00;
					IsInLoop &= ~(1 << TempByt);
					CurPos = CurPtr;
				}
				break;
			case CFTYPE_MODULATION:
				switch(SMPSData[CurPos])
				{
				case 0xF0:	// Modulation Setup and Enable
				case 0xE8:	// Modulation Setup (OutRunners)
					// because of some restructured code, there are some differences:
					// 1. Wait time is 1 higher in S1/2 than in S3K
					// 2. in S1/2 steps are processed only when the Speed counter expires
					//    in S3K they are always processed
					//    So Step Count must be adjusted accordingly.
					// 3. S1/2 counts Step Count from 0 <= x
					//    S3K counts Step Count from 0 < x
					SMPSNewData[DstPos + 0x00] = 0xF0;
					if (GET_CNV_SRC(CoordMode) == CFMODE_S3K)	// from S3K to S1/2/Trs
					{
						SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x01] - 1;	// Wait
						SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];		// Speed
						SMPSNewData[DstPos + 0x03] = SMPSData[CurPos + 0x03];		// Step Change
						// Steps S1 = (Steps S3K / Speed)
						// (Steps is the number of steps until Step Count is reseted.
						//  i.e. (Steps S3K) or (Steps S1 + 1)
						if (SMPSData[CurPos + 0x02])
						{
							TempSht = ((SMPSData[CurPos + 0x04] - 1) & 0xFF) + 1;	// 0x00 = 0x100
							TempSht += SMPSData[CurPos + 0x02] / 2;	// for correct rounding
							TempByt = TempSht / SMPSData[CurPos + 0x02];
						}
						else
						{
							TempByt = SMPSData[CurPos + 0x04];
						}
						SMPSNewData[DstPos + 0x04] = TempByt - 1;					// Step Count
					}
					else if (GET_CNV_DST(CoordMode) == CFMODE_S3K)	// from S1/2/Trs to S3K
					{
						SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x01] + 1;	// Wait
						SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];		// Speed
						SMPSNewData[DstPos + 0x03] = SMPSData[CurPos + 0x03];		// Step Change
						// Steps S3K = (Steps S1 * Speed)
						if (SMPSData[CurPos + 0x02])
						{
							TempSht = (UINT16)SMPSData[CurPos + 0x04] + 1;
							TempByt = TempSht / SMPSData[CurPos + 0x02];
							TempByt = TempSht * SMPSData[CurPos + 0x02];
						}
						else
						{
							TempByt = SMPSData[CurPos + 0x04] + 1;
						}
						SMPSNewData[DstPos + 0x04] = TempByt;						// Step Cunt
					}
					else
					{
						for (TempByt = 0x01; TempByt < CmdLen; TempByt ++)
							SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
					}
					
					SetProcMask(CurPos, CmdLen);
					CurPos += CmdLen;
					DstPos += CmdLen;
					break;
				case 0xF1:
					if (GET_CNV_SRC(CoordMode) != CFMODE_S1 && GET_CNV_DST(CoordMode) == CFMODE_S1)
					{
						// S3K: Set Modulation Type (with seperate parameters for FM and PSG tracks)
						
						// ignore for now
						IgnoreMsg(CurChn, CurPos);
						/*SMPSNewData[DstPos + 0x00] = SMPSData[CurPos + 0x00];
						SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x01];
						SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];*/
					}
					else if (GET_CNV_SRC(CoordMode) == CFMODE_S1)
					{
						// S1: Turn Modulaton On
						if (GET_CNV_DST(CoordMode) == CFMODE_S1)
						{
							SMPSNewData[DstPos + 0x00] = 0xF1;
							DstPos += 0x01;
						}
						else
						{
							SMPSNewData[DstPos + 0x00] = 0xF4;
							SMPSNewData[DstPos + 0x01] = 0x80;
							DstPos += 0x02;
						}
					}
					else
					{
						IgnoreMsg(CurChn, CurPos);
					}
					
					SetProcMask(CurPos, CmdLen);
					CurPos += CmdLen;
					break;
				case 0xF4:
					if (GET_CNV_SRC(CoordMode) != CFMODE_S1 && GET_CNV_DST(CoordMode) == CFMODE_S1)
					{
						// S3K: Set Modulation Type
						if (SMPSData[CurPos + 0x01] == 0x80)
						{
							// Turn Modulation On
							SMPSNewData[DstPos + 0x00] = 0xF1;
							DstPos += 0x01;
						}
						else if (SMPSData[CurPos + 0x01] == 0x00)
						{
							// Turn Modulation Off
							SMPSNewData[DstPos + 0x00] = 0xF4;
							DstPos += 0x01;
						}
						else
						{
							IgnoreMsg(CurChn, CurPos);
						}
					}
					else if (GET_CNV_SRC(CoordMode) == CFMODE_S1)
					{
						// S1: Disable Modulation
						if (GET_CNV_DST(CoordMode) == CFMODE_S3K)
							SMPSNewData[DstPos + 0x00] = 0xFA;
						else if (GET_CNV_DST(CoordMode) == CFMODE_S1)
							SMPSNewData[DstPos + 0x00] = 0xF4;
						else
							SMPSNewData[DstPos + 0x00] = 0xFD;
						DstPos += 0x01;
					}
					else
					{
						IgnoreMsg(CurChn, CurPos);
					}
					
					SetProcMask(CurPos, CmdLen);
					CurPos += CmdLen;
					break;
				case 0xFA:	// S3K: Clear Modulation Type Bit 7
					SetProcMask(CurPos, CmdLen);
					CurPos += CmdLen;
					break;
				case 0xFC:	// Trs: Enable Modulation
					if (GET_CNV_DST(CoordMode) == CFMODE_S3K)
					{
						SMPSNewData[DstPos + 0x00] = 0xF4;
						SMPSNewData[DstPos + 0x01] = 0x80;
						DstPos ++;
					}
					else if (GET_CNV_DST(CoordMode) == CFMODE_S1)
						SMPSNewData[DstPos + 0x00] = 0xF1;
					else
						SMPSNewData[DstPos + 0x00] = 0xFC;
					
					SetProcMask(CurPos, CmdLen);
					CurPos += CmdLen;
					DstPos += CmdLen;
					break;
				case 0xFD:	// Trs: Disable Modulation
					if (GET_CNV_DST(CoordMode) == CFMODE_S3K)
						SMPSNewData[DstPos + 0x00] = 0xFA;
					else if (GET_CNV_DST(CoordMode) == CFMODE_S1)
						SMPSNewData[DstPos + 0x00] = 0xF4;
					else
						SMPSNewData[DstPos + 0x00] = 0xFD;
					
					SetProcMask(CurPos, CmdLen);
					CurPos += CmdLen;
					DstPos += CmdLen;
					break;
				}
				break;
			case CFTYPE_VOLUME:
				TempByt = SMPSData[CurPos];
				if (GET_CNV_SRC(CoordMode) == CFMODE_ORNS)
				{
					if (TempByt == 0xE2)
						TempByt = 0xE6;
					else if (TempByt == 0xE5 || TempByt == 0xE6)
						TempByt = 0xEC;
				}
				
				switch(TempByt)
				{
				case 0xE4:	// Set Volume
					if (CurChn < FMChnCnt)
						TempByt = ~SMPSData[CurPos + 0x01] & 0x7F;
					else
						TempByt = (~SMPSData[CurPos + 0x01] & 0x78) >> 3;
					TempByt = TempByt - CurChnVol;
					
					if (GET_CNV_SRC(CoordMode) == CFMODE_S3K && GET_CNV_DST(CoordMode) != CFMODE_S3K)
					{
						if (CurGosub)
							printf("Track %u, Sub %u, Pos 0x%04X: Set Volume command used!\n",
									CurChn, CurGosub,  CurPos, SMPSData[CurPos + 0x01] & 0x7F, 0x81 + SMPSData[CurPos + 0x02]);
						SMPSNewData[DstPos + 0x00] = (CurChn < FMChnCnt) ? 0xE6 : 0xEC;
						SMPSNewData[DstPos + 0x01] = TempByt;
					}
					else
					{
						SMPSNewData[DstPos + 0x00] = SMPSData[CurPos + 0x00];
						SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x01];
					}
					CurChnVol += TempByt;
					
					DstPos += CmdLen;
					break;
				case 0xE5:	// like E6, but first parameter is skipped
					// ignored on PSG channels
					if (CurChn >= FMChnCnt && GET_CNV_SRC(CoordMode) == CFMODE_S3K)
						break;
					
					SMPSNewData[DstPos + 0x00] = (CurChn >= FMChnCnt) ? 0xEC : 0xE6;
					SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x02];
					CurChnVol += SMPSData[CurPos + 0x02];
					if (CurChnVol > 0x7F)
						CurChnVol = 0x7F;
					DstPos += 0x02;
					break;
				case 0xE6:	// Change Volume (FM)
					// ignored on PSG channels
					if (CurChn >= FMChnCnt && GET_CNV_SRC(CoordMode) == CFMODE_S3K)
						break;
					
					SMPSNewData[DstPos + 0x00] = (CurChn >= FMChnCnt) ? 0xEC : 0xE6;
					SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x01];
					CurChnVol += SMPSData[CurPos + 0x01];
					if (CurChnVol > 0x7F)
						CurChnVol = 0x7F;
					if (SMPSData[CurPos + 0x01])	// skip, if no change
						DstPos += CmdLen;
					break;
				case 0xEC:	// Change Volume (PSG)
					SMPSNewData[DstPos + 0x00] = 0xEC;
					SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x01];
					CurChnVol += SMPSData[CurPos + 0x01];
					if (CurChnVol > 0x0F)
						CurChnVol = 0x0F;
					if (SMPSData[CurPos + 0x01] /*|| GET_CNV_SRC(CoordMode) != CFMODE_S3K*/)	// skip, if no change
						DstPos += CmdLen;
					break;
				}
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				break;
			case CFTYPE_TEMPO:
				if (SMPSData[CurPos] < 0xFF)
				{
					TempSht = SMPSData[CurPos + 0x00];
					TempByt = SMPSData[CurPos + 0x01];
				}
				else
				{
					TempSht = (SMPSData[CurPos + 0x00] << 8) | (SMPSData[CurPos + 0x01] << 0);
					TempByt = SMPSData[CurPos + 0x02];
				}
				switch(TempSht)
				{
				case   0xEA:	// S1/Trs: Set Tempo Modifier
				case 0xFF00:	// S3K: Set Tempo Modifier
					if (GET_CNV_DST(CoordMode) != CFMODE_S3K)
					{
						SMPSNewData[DstPos + 0x00] = 0xEA;
						SMPSNewData[DstPos + 0x01] = TempoConv(TempByt);
						DstPos += 0x02;
					}
					else
					{
						SMPSNewData[DstPos + 0x00] = 0xFF;
						SMPSNewData[DstPos + 0x01] = 0x00;
						SMPSNewData[DstPos + 0x02] = TempoConv(TempByt);
						DstPos += 0x03;
					}
					break;
				case   0xEB:	// S1: Set Tempo Divider for ALL Channels
				case 0xFF02:	// Trs: Set Tempo Divider
				case 0xFF04:	// S3K: Set Tempo Divider
					TempByt *= DuratDivide;
					if (GET_CNV_DST(CoordMode) != CFMODE_S3K)
					{
						SMPSNewData[DstPos + 0x00] = 0xEB;
						SMPSNewData[DstPos + 0x01] = TempByt;
						DstPos += 0x02;
					}
					else
					{
						SMPSNewData[DstPos + 0x00] = 0xFF;
						SMPSNewData[DstPos + 0x01] = 0x04;
						SMPSNewData[DstPos + 0x02] = TempByt;
						DstPos += 0x03;
					}
					break;
				case   0xE5:	// S1: Set Tempo Divider
				case   0xFA:	// Trs: Set Tempo Divider
				case 0xFF08:	// S3K Flamewing: Set Channel Tempo Divider
					TempByt *= DuratDivide;
					if (GET_CNV_DST(CoordMode) != CFMODE_S3K)
					{
						SMPSNewData[DstPos + 0x00] = 0xE5;
						SMPSNewData[DstPos + 0x01] = TempByt;
						DstPos += 0x02;
					}
					else
					{
						SMPSNewData[DstPos + 0x00] = 0xFF;
						SMPSNewData[DstPos + 0x01] = 0x08;
						SMPSNewData[DstPos + 0x02] = TempByt;
						WarningMsgFlame(CurChn, CurPos, DstPos);
						DstPos += 0x03;
					}
					break;
				}
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				break;
			case CFTYPE_NOTE_FILL:
				switch(SMPSData[CurPos])
				{
				case 0xE8:	// Set Note Fill (affected by Tempo Divider)
				case 0xE4:	// Set Note Fill (OutRunners)
					SMPSNewData[DstPos + 0x00] = 0xE8;
					
					TempByt = SMPSData[CurPos + 0x01];
					if (GET_CNV_SRC(CoordMode) == CFMODE_S3K && GET_CNV_DST(CoordMode) != CFMODE_S3K)
						TempByt *= TempoDiv;
					else if (GET_CNV_SRC(CoordMode) != CFMODE_S3K && GET_CNV_DST(CoordMode) == CFMODE_S3K)
						TempByt /= TempoDiv;
					SMPSNewData[DstPos + 0x01] = TempByt;
					
					SetProcMask(CurPos, CmdLen);
					CurPos += CmdLen;
					DstPos += CmdLen;
					break;
				case 0xFF:
					switch(SMPSData[CurPos + 0x01])
					{
					case 0x0A:	// S3K Flamewing: Set Note Fill
						if (GET_CNV_DST(CoordMode) != CFMODE_S3K)
						{
							SMPSNewData[DstPos + 0x00] = 0xE8;
							SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x02];
							DstPos += 0x02;
						}
						else
						{
							SMPSNewData[DstPos + 0x00] = 0xFF;
							SMPSNewData[DstPos + 0x01] = 0x08;
							SMPSNewData[DstPos + 0x02] = TempoConv(SMPSData[CurPos + 0x02]);
							WarningMsgFlame(CurChn, CurPos, DstPos);
							DstPos += 0x03;
						}
						
						SetProcMask(CurPos, 0x03);
						CurPos += 0x03;
						break;
					}
				}
				break;
			case CFTYPE_FM_INS:		// Flag EF
				if (CurChn < FMChnCnt)
				{
					SMPSNewData[DstPos + 0x00] = 0xEF;
					if (UseInsBank && SMPSData[CurPos + 0x01] < InsBank.InsCount)
						SMPSNewData[DstPos + 0x01] = InsBank.InsAssign[SMPSData[CurPos + 0x01]].NewID;
					else
						SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x01];
					
					if (GET_CNV_SRC(CoordMode) == CFMODE_S3K && (SMPSData[CurPos + 0x01] & 0x80))
					{
						// special: S3K Instrument Command
						SMPSNewData[DstPos + 0x01] &= 0x7F;
						printf("Track %u, Pos 0x%04X: Foreign FM Instrument %02X of Song %02X used!\n",
								CurChn, CurPos, SMPSData[CurPos + 0x01] & 0x7F, 0x81 + SMPSData[CurPos + 0x02]);
					}
					else
					{
						// count the possibly patched instrument IDs
						if (CurChn < FMChnCnt && ! UseInsBank && MaxIns <= SMPSData[CurPos + 0x01])
							MaxIns = SMPSData[CurPos + 0x01] + 1;
					}
				}
				else
				{
					SMPSNewData[DstPos + 0x00] = 0xF5;
					SMPSNewData[DstPos + 0x01] = PSGInsPatch(SMPSData[CurPos + 0x01]);
				}
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += TempCF->Len & 0x7F;
				break;
			case CFTYPE_PSG_INS:	// Flag F5
				SMPSNewData[DstPos + 0x00] = 0xF5;
				SMPSNewData[DstPos + 0x01] = PSGInsPatch(SMPSData[CurPos + 0x01]);
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				break;
			case CFTYPE_KEY_DISPLC:
				switch(SMPSData[CurPos])
				{
				case 0xED:	// S3K: Set key displacement to (xx - 0x40)
					if (CurGosub)
						WarningMsg(CurChn, CurPos);
					TempByt = SMPSData[CurPos + 0x01] - 0x40;
					if (CurChn >= FMChnCnt)
						TempByt -= 12;
					TempByt = TempByt - CurChnKeyDplc;
					break;
				case 0xE9:	// S1: Add xx to key displacement
				case 0xF1:	// OutRunners: Add xx to key displacement
				case 0xFB:	// S3K: Add xx to key displacement
					TempByt = SMPSData[CurPos + 0x01];
					break;
				}
				if (GET_CNV_DST(CoordMode) == CFMODE_S1)
					SMPSNewData[DstPos + 0x00] = 0xE9;
				else
					SMPSNewData[DstPos + 0x00] = 0xFB;
				SMPSNewData[DstPos + 0x01] = TempByt;
				CurChnKeyDplc += TempByt;
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				break;
			case CFTYPE_SPECIAL:
				switch(SMPSData[CurPos])
				{
				case 0xE2:	// S3K: Fade In
					if (GET_CNV_DST(CoordMode) == CFMODE_S1)
					{
						if (SMPSNewData[DstPos + 0x01] == 0xFF)
						{
							SMPSNewData[DstPos + 0x00] = 0xE4;
							DstPos += 0x01;
						}
						else
						{
							// nothing special happens else
						}
					}
					else // if (GET_CNV_DST(CoordMode) == CFMODE_TRS)
					{
						for (TempByt = 0x00; TempByt < CmdLen; TempByt ++)
							SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
						DstPos += CmdLen;
					}
					break;
				case 0xE3:	// OutRunners: No Attack
					SMPSNewData[DstPos + 0x00] = 0xE7;
					DstPos += 0x01;
					break;
				case 0xE4:	// S1: Fade In
					if (GET_CNV_DST(CoordMode) == CFMODE_S3K)
					{
						SMPSNewData[DstPos + 0x00] = 0xE2;
						SMPSNewData[DstPos + 0x01] = 0xFF;
						DstPos += 0x02;
					}
					else
					{
						IgnoreMsg(CurChn, CurPos);
					}
					break;
				case 0xEA:	// OutRunners: Set PSG Noise
					SMPSNewData[DstPos + 0x00] = 0xF3;
					SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x01];
					DstPos += 0x02;
					break;
				case 0xFD:	// En-/Disable Alternate SMPS Mode
					// ignore and quit
					IgnoreMsg(CurChn, CurPos);
					TrackBreak = true;
					break;
				}
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				break;
			}
		}
		
		if (TrackEnd)
		{
			CurGosub ++;
			if (CurGosub < GosubID)
			{
				CurPos = GosubPtr[CurGosub];
				CurChnKeyDplc = 0x00;
				CurChnVol = 0x00;
				TrackEnd = false;
			}
		}
		
		}	// end while(! TrackEnd)
	}	// end for (ChnID < ChnCount)
	
	// Now write an F2 and make all invalid track pointers point to it.
	// (I still want valid files - even if the source files are invalid.)
	TrackEnd = false;
	for (ChnID = 0x00; ChnID < ChnCnt; ChnID ++)
	{
		// Parse Channel Data
		CurChn = ChnListSort[ChnID];
		CurPos = ChnList[CurChn].Ptr;
		if (CurPos >= SMPSLen)
		{
			AddNewPosToList(CurPos, DstPos);
			TrackEnd = true;
		}
	}
	if (TrackEnd)
	{
		SMPSNewData[DstPos] = 0xF2;
		DstPos ++;
	}
	printf("\n");
	
	// In the worst case (read: S3: LBZ1), the Instrument Pointer points to the EOF.
	AddNewPosToList(InsPtr, DstPos);
	if (GET_CNV_SRC(PtrMode) == CPTR_Z80)
		CurPtr = SMPSOffset ^ (SMPSOffset + InsPtr);
	else
		CurPtr = 0x0000;
	if (UseInsBank)
	{
		for (TempByt = 0x00; TempByt < InsBank.InsCount; TempByt ++)
		{
			if (InsBank.InsAssign[TempByt].IsUsed)
			{
				TempSht = CopyInstrument(&SMPSNewData[DstPos], InsBank.InsData[TempByt].Data);
				DstPos += TempSht;
			}
		}
		printf("The song uses 0x%02X instruments.\n", MaxIns);
	}
	else if (InsPtr >= SMPSLen)
	{
		printf("Warning: Instrument Table Offset after End of File! Ignored.\n");
		printf("The song uses 0x%02X instruments.\n", MaxIns);
	}
	else if (! (CurPtr & 0x8000))	// catch invalid Z80 InsPtrs (like Sonic 3 Global Instrument Bank)
	{
		CurPtr = InsPtr + 0x19 * MaxIns;
		if (CurPtr > SMPSLen)
		{
			printf("Warning: Instrument Table may be incomplete!\n"
					"(size is 0x%X bytes, but should have 0x%X * 0x%X = 0x%X bytes)\n",
					SMPSLen - InsPtr, MaxIns, 0x19, 0x19 * MaxIns);
			MaxIns = (SMPSLen - InsPtr) / 0x19;
		}
		CurPos = InsPtr;
		SetProcMask(InsPtr, 0x19 * MaxIns);
		
		CopyInstrumentTable(&DstPos, &CurPos, MaxIns);
	}
	else //if (CurPtr & 0x8000)
	{
		printf("The song uses 0x%02X instruments.\n", MaxIns);
	}
	SMPSNewLen = DstPos;
	
	CurPtr = GetProcMaskNonusage();
	printf("Conversion missed 0x%X (likely unused) byte%s:\n", CurPtr, (CurPtr == 1) ? "" : "s");
	PrintProcMaskNonusage();
	
	return;
}

static UINT16 CopyInstrument(UINT8* Buffer, const UINT8* InsData)
{
	UINT16 CurPos;
	bool SwapOp;
	UINT8 AlgoOps;
	UINT8 CurGrp;	// Operator Group
	UINT8 CurOp;
	
	SwapOp = (GET_CNV_SRC(InsMode) != GET_CNV_DST(InsMode));
	CurPos = 0x00;
	
	AlgoOps = ALGO_OPS[InsData[CurPos] & 0x07];
	if (GET_CNV_DST(InsMode) == CINS_HW)
		AlgoOps = (AlgoOps & 0x09) | ((AlgoOps & 0x04) >> 1) | ((AlgoOps & 0x02) << 1);
		
	Buffer[CurPos] = InsData[CurPos];
	CurPos ++;
		
	for (CurGrp = 0x00; CurGrp < 0x06; CurGrp ++)
	{
		Buffer[CurPos + 0x00] = InsData[CurPos + 0x00];
		if (! SwapOp)
		{
			Buffer[CurPos + 0x01] = InsData[CurPos + 0x01];
			Buffer[CurPos + 0x02] = InsData[CurPos + 0x02];
		}
		else
		{
			Buffer[CurPos + 0x01] = InsData[CurPos + 0x02];
			Buffer[CurPos + 0x02] = InsData[CurPos + 0x01];
		}
		Buffer[CurPos + 0x03] = InsData[CurPos + 0x03];
		
		if (CurGrp == 0x05)
		{
			// fix Total Level operators
			for (CurOp = 0x00; CurOp < 0x04; CurOp ++)
			{
				if (GET_CNV_SRC(CoordMode) != CFMODE_S3K && GET_CNV_DST(CoordMode) == CFMODE_S3K)
				{
					// In S3K, all TL operators that are affected by volume changes,
					// must have bit 7 set. All others must have bit 7 clear.
					// This also seems to apply to some late SMPS 68k games. (but not all?)
					if (AlgoOps & (1 << CurOp))
						Buffer[CurPos + CurOp] |= 0x80;
					else
						Buffer[CurPos + CurOp] &= 0x7F;
				}
				else if (GET_CNV_SRC(CoordMode) == CFMODE_S3K && GET_CNV_DST(CoordMode) != CFMODE_S3K)
				{
					Buffer[CurPos + CurOp] &= 0x7F;
				}
			}
		}
		
		CurPos += 0x04;
	}
	
	return CurPos;
}

static void CopyInstrumentTable(UINT16* DstOfs, UINT16* SrcOfs, UINT8 InsCnt)
{
	UINT16 ProcBytes;
	UINT8 CurIns;
	
	for (CurIns = 0x00; CurIns < InsCnt; CurIns ++)
	{
		ProcBytes = CopyInstrument(&SMPSNewData[*DstOfs], &SMPSData[*SrcOfs]);
		(*SrcOfs) += ProcBytes;
		(*DstOfs) += ProcBytes;
	}
	
	return;
}

void WritePointers(void)
{
	PTR_LIST* CurLst;
	OFS_LIST* CurOfs;
	UINT16 PtrVal;
	
	CurLst = PtrList;
	while(CurLst != NULL)
	{
		CurOfs = CurLst->DstPosLst;
		while(CurOfs != NULL)
		{
			// only the coordination flags of SMPS 68k have relative pointers
			switch(GET_CNV_DST(PtrMode))
			{
			case CPTR_Z80:
				PtrVal = SMPSNewOffset + CurLst->DstPtr;
				break;
			case CPTR_68K:
				if (CurOfs->CoordFlg < 0xE0)
					PtrVal = CurLst->DstPtr;
				else
					PtrVal = CurLst->DstPtr - (CurOfs->Ofs + 0x01);
				break;
			case CPTR_RST:
				if (CurOfs->CoordFlg < 0xE0)
					PtrVal = CurLst->DstPtr;
				else
					PtrVal = CurLst->DstPtr - (CurOfs->Ofs + 0x02);
				break;
			}
			if (CurLst->DstPtr == 0xFFFF)
			{
				printf("Error: Failed to relocate pointer at %04X! (original dest. ofs: %04X)\n",
						CurOfs->Ofs, CurLst->SrcPtr);
#ifdef _DEBUG
				getchar();
#endif
			}
			Put16Ptr(&SMPSNewData[CurOfs->Ofs], PtrVal);
			
			CurOfs = CurOfs->next;
		}
		
		CurLst = CurLst->next;
	}
	
	return;
}

void FreePointers(void)
{
	PTR_LIST* CurLst;
	OFS_LIST* CurOfs;
	DATAPTR_LIST* CurDPtr;
	PTR_LIST* OldLst;
	OFS_LIST* OldOfs;
	DATAPTR_LIST* OldDPtr;
	
	CurLst = PtrList;
	PtrList = NULL;
	while(CurLst != NULL)
	{
		CurOfs = CurLst->SrcPosLst;
		while(CurOfs != NULL)
		{
			OldOfs = CurOfs;
			CurOfs = CurOfs->next;
			free(OldOfs);
		}
		
		CurOfs = CurLst->DstPosLst;
		while(CurOfs != NULL)
		{
			OldOfs = CurOfs;
			CurOfs = CurOfs->next;
			free(OldOfs);
		}
		
		OldLst = CurLst;
		CurLst = CurLst->next;
		free(OldLst);
	}
	PtrLEnd = NULL;
	
	CurDPtr = SrcPosPtrList;
	SrcPosPtrList = NULL;
	while(CurDPtr != NULL)
	{
		OldDPtr = CurDPtr;
		CurDPtr = CurDPtr->next;
		free(OldDPtr);
	}
	SrcPosPtrLEnd = NULL;
	
	free(ChnList);		ChnList = NULL;
	free(ChnListSort);	ChnListSort = NULL;
	
	return;
}
