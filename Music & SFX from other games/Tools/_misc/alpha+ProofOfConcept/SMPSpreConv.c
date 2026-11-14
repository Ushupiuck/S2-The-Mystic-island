// preSMPS Converter (based on SMPSConv)
// -----------------
// Programmed by Valley Bell, 2013
// Most work was done on 16 August 2013.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <malloc.h>
#include <memory.h>

typedef unsigned char	bool;
typedef unsigned char	UINT8;
typedef signed char		INT8;
typedef unsigned short	UINT16;
typedef signed short	INT16;
typedef unsigned int	UINT32;

#define false	0x00
#define true	0x01

#define INLINE	__inline
#ifndef WIN32
#define _stricmp	strcasecmp
#endif

typedef struct mapping_table MAP_TBL;


int main(int argc, char* argv[]);
static bool SetConvModes(const char* ArgStr);
static bool SetConvMode(UINT8 IsDst, const char* ModeStr);

void LoadMappingFile(const char* MapFileName, MAP_TBL* MapData);
UINT8 LoadInstrumentBank(const char* FileName);
UINT8 LoadSMPSFile(const char* FileName);

static INLINE UINT16 Get16Val(UINT8* Data, UINT8 LittleEndian);
static INLINE UINT16 Get16Ptr(UINT8* Data, UINT16 PtrPos);
static INLINE void Put16Ptr(UINT8* Data, UINT16 Ptr);

static void AddPtrToList(UINT16 SrcPos, UINT16 SrcPtr, UINT8 CoordFlag, UINT8 ChnMask);
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

static void IgnoreMsg(UINT8 CurChn, UINT16 CurPos);
static void WarningMsg(UINT8 CurChn, UINT16 CurPos);
static void WarningMsgFlame(UINT8 CurChn, UINT16 CurPos, UINT16 NewPos);
static void WarningMsgInvalid(UINT8 CurChn, UINT16 CurPos);

void ConvertSMPS(void);
static void CopyInstrumentTable(UINT16* DstOfs, UINT8 InsCnt);
void WritePointers(void);
void FreePointers(void);


typedef struct offset_list OFS_LIST;
struct offset_list
{
	UINT16 Ofs;
	UINT8 CoordFlg;
	UINT8 ChnMask;
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
	UINT8 ChnMask;
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
	UINT8 ModType;	// PSG only
	UINT8 PSGIns;	// PSG only
} CHN_HEAD;

typedef struct channel_header_presmps
{
	UINT8 PlaybackCtrl;
	UINT8 ChnMask;
	UINT8 TempoDiv;
	UINT16 Ptr;
	UINT8 Transpose;
	UINT8 ModType;
	UINT8 Instrument;
	UINT8 Volume;
} CHN_HEAD_PRE;

typedef struct mapping_value
{
	UINT8 Base;
	UINT8 Count;
} MAP_VAL;
struct mapping_table
{
	UINT8 BnkAlloc;
	UINT8 BnkCount;
	UINT8 BnkDefault;
	MAP_VAL* Bank;
};


#define CPTR_68K	0x00
#define CPTR_Z80	0x01

#define CFMODE_DEF	0x00
#define CFMODE_PRE	0x01

#define GET_CNV_SRC(x)	(((x) & 0x0F) >> 0)
#define GET_CNV_DST(x)	(((x) & 0xF0) >> 4)
#define MAKE_CNV_SRC(x)	(((x) & 0x0F) << 0)
#define MAKE_CNV_DST(x)	(((x) & 0x0F) << 4)

#define MAKE_CNV_SD(Src, Dst)	(MAKE_CNV_SRC(Src) | MAKE_CNV_DST(Dst))

#define GET_BIT(BytArr, Bit)	((BytArr[Bit >> 3] >> (Bit & 0x07)) & 0x01)
#define SET_BIT(BytArr, Bit)	BytArr[Bit >> 3] |= 0x01 << (Bit & 0x07)

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
	CFTYPE_VOLUME_SET,
	CFTYPE_TEMPO,
	CFTYPE_NO_ATK,
	CFTYPE_SET_INS,
	CFTYPE_PAN,
	CFTYPE_SPECIAL
};
typedef struct coordination_flag
{
	UINT8 Type;
	UINT8 Len;
	UINT8 JmpOfs;
	UINT8 reserved;
} COORD_FLAG;

static const UINT8 SMPS_INS_REGS[0x1A] =
{	0xB0,
	0x30, 0x38, 0x34, 0x3C,
	0x50, 0x58, 0x54, 0x5C,
	0x60, 0x68, 0x64, 0x6C,
	0x70, 0x78, 0x74, 0x7C,
	0x80, 0x88, 0x84, 0x8C,
	0x40, 0x48, 0x44, 0x4C,
	0xB4};

typedef struct instrument_bank_entry
{
	UINT8 Data[0x1A];	// 0x19 is register B4
} INS_BNK_ENTRY;
typedef struct instrument_bank
{
	//UINT16 InsCount;
	INS_BNK_ENTRY InsData[0x100];
	UINT8 InsAssign[0x100];
	UINT8 InsSrc[0x100];
	UINT8 InsUsage[0x100/8];
	UINT8 InsUsed;
} INS_BANK;


UINT8 PtrMode;
UINT8 CoordMode;

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

UINT8 ChnCnt;
UINT8 FnlChnCnt;
UINT8 FMChnCnt;
UINT8 PSGChnCnt;
CHN_HEAD ChnList[0x10];	// technically, 0x0A should be max (07+03)
UINT8 ChnListSort[0x10];
UINT8 ChnListSrc[0x10];
CHN_HEAD_PRE PreHeader[0x10];

MAP_TBL DACMap;
INS_BANK InsBank;
COORD_FLAG CFMain[0x20];

int main(int argc, char* argv[])
{
	FILE* hFile;
	UINT8 RetVal;
	PTR_LIST* CurLst;
	OFS_LIST* CurOfs;
	int InKey;
	UINT16 SMPSOfsBak;
	
	printf("SMPS Converter\n--------------\n");
	if (argc < 4)
	{
		printf("Usage: SMPSConv.exe FmtFrom-FmtTo smps_in.bin smps_out.bin\n");
		printf("Format Strings (case insensitive):\n");
		printf("    S1  - Sonic 1 (68k)\n");
		printf("    S3K - Sonic 3 & Knuckles (Z80)\n");
		printf("    Trs - SMPS Treasure (68k) and other games with late SMPS 68k\n");
		printf("    Rst - Ristar (68k)\n");
		printf("    ORs - Outrunners (Z80)\n");
		return 0;
	}
	
	if (! SetConvModes(argv[1]))
	{
		printf("Invalid Format String!\n");
		return 2;
	}
	
	LoadMappingFile("DACMap.ini", &DACMap);
	
	RetVal = LoadInstrumentBank("InsBank.bin");
	if (RetVal)
	{
		printf("Error opening instrument bank!\n");
		return 1;
	}
	
	RetVal = LoadSMPSFile(argv[2]);
	if (RetVal)
	{
		printf("Error opening file!\n");
		return 1;
	}
	
	ReadSMPSHeader();
	if (! ChnCnt)
	{
		printf("Sorry, this file seems to be no valid SMPS file.\n");
		return 2;
	}
	
	// SMPSOffset gets set by ReadSMPSHeader
	//if (GET_CNV_SRC(PtrMode) == CPTR_Z80)
	{
		printf("The guessed SMPS Offset relative to driver base is: 0x%04X. Is this right? (Y/N/Q)\n", SMPSOffset);
		SMPSOfsBak = SMPSOffset;
		do
		{
			do
			{
				//InKey = toupper(getchar());
				InKey = 'Y';
				if (InKey == 'Q')
				{
					free(SMPSData);
					printf("Quit.\n");
					return 0;
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
		//while(InKey != '\n')
		//	InKey = getchar();
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
					free(SMPSData);
					printf("Quit.\n");
					return 0;
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
	
	printf("Tracks: %u\n", ChnCnt);
	printf("-> FM/DAC Tracks: %u, PSG Tracks: %u\n", FMChnCnt, PSGChnCnt);
	PreparseSMPS();
	printf("\n");
	
	printf("Pointer List:\nCoord\tPntFile\tPntReal\tPos\n");
	CurLst = PtrList;
	while(CurLst != NULL)
	{
		printf("%02X/%02X\t%04X\t%04X\t", CurLst->CoordFlg, CurLst->ChnMask, (SMPSOffset + CurLst->SrcPtr) & 0xFFFF, CurLst->SrcPtr);
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
	
	hFile = fopen(argv[3], "wb");
	if (hFile == NULL)
	{
		printf("Error opening file!\n");
		return 1;
	}
	fwrite(SMPSNewData, SMPSNewLen, 0x01, hFile);
	
	fclose(hFile);
	
	free(SMPSData);
	free(SMPSNewData);
	
	printf("Conversion complete.\n");
	
#ifdef _DEBUG
	getchar();
#endif
	
	return 0;
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
	
	//PtrMode = MAKE_CNV_SD(CPTR_68K, CPTR_68K);
	if (! SetConvMode(false, TempStr))
		return false;
	/*if (! SetConvMode(true, RStr))
		return false;*/
	if (! SetConvMode(true, "68k"))
		return false;
	CoordMode = MAKE_CNV_SD(CFMODE_PRE, GET_CNV_DST(CoordMode));
	CoordMode = MAKE_CNV_SD(GET_CNV_SRC(CoordMode), CFMODE_DEF);
	
	return true;
}

static bool SetConvMode(UINT8 IsDst, const char* ModeStr)
{
	UINT8 Ptr;
	
	if (! _stricmp(ModeStr, "68k"))
	{
		Ptr = CPTR_68K;
	}
	else if (! _stricmp(ModeStr, "Z80"))
	{
		Ptr = CPTR_Z80;
	}
	else
	{
		return false;
	}
	
	if (! IsDst)
	{
		PtrMode = MAKE_CNV_SD(Ptr, GET_CNV_DST(PtrMode));
	}
	else
	{
		PtrMode = MAKE_CNV_SD(GET_CNV_SRC(PtrMode), Ptr);
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
	
	MapData->BnkAlloc = 0x00;
	MapData->BnkCount = 0x00;
	MapData->BnkDefault = 0x00;
	MapData->Bank = NULL;
	
	hFile = fopen(MapFileName, "rt");
	if (hFile == NULL)
	{
		printf("Error opening %s\n", MapFileName);
		return;
	}
	
	MapData->BnkAlloc = 0x40;
	MapData->Bank = (MAP_VAL*)malloc(MapData->BnkAlloc * sizeof(MAP_VAL));
	memset(MapData->Bank, 0x00, MapData->BnkAlloc * sizeof(MAP_VAL));
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
		
		if (! _stricmp(TempStr, "Count"))
		{
			MapData->BnkCount = (UINT8)strtoul(TempPnt, NULL, 0x10);
			if (MapData->BnkCount > MapData->BnkAlloc)
				MapData->BnkCount = MapData->BnkAlloc;
		}
		else if (! _stricmp(TempStr, "Default"))
		{
			MapData->BnkDefault = (UINT8)strtoul(TempPnt, NULL, 0x10);
		}
		else
		{
			CurMap = (UINT8)strtoul(TempStr, NULL, 0x10);
			if (! CurMap || CurMap >= MapData->BnkCount)
				continue;
			CurMap --;
			
			TempMap = &MapData->Bank[CurMap];
			TempMap->Count = (UINT8)strtoul(TempPnt, NULL, 0x10);
		}
	}
	
	fclose(hFile);
	
	TempInt = 0x00;
	for (CurMap = 0x00; CurMap < MapData->BnkCount; CurMap ++)
	{
		TempMap = &MapData->Bank[CurMap];
		TempMap->Base = (UINT8)TempInt;
		TempInt += TempMap->Count;
	}
	
	return;
}

UINT8 LoadInstrumentBank(const char* FileName)
{
	FILE* hFile;
	UINT32 FileSize;
	UINT8* FileData;
	UINT8 PtrMode;
	UINT16 RegBase;
	UINT16 PtrBase;
	UINT16 InsBase;
	UINT16 CurIns;
	UINT16 MinPos;
	UINT16 CurRPos;
	UINT16 CurPPos;
	UINT16 CurIPos;
	UINT8 CurReg;
	UINT8 RegVal;
	
	hFile = fopen(FileName, "rb");
	if (hFile == NULL)
		return 0x80;
	
	fseek(hFile, 0x00, SEEK_END);
	FileSize = ftell(hFile);
	if (FileSize > 0x8000)	// 32 KB
		FileSize = 0x8000;
	
	fseek(hFile, 0x00, SEEK_SET);
	FileData = (UINT8*)malloc(FileSize);
	fread(FileData, 0x01, FileSize, hFile);
	
	fclose(hFile);
	
	PtrMode = FileData[0x03] & 0x01;
	RegBase = Get16Val(&FileData[0x04], PtrMode);
	PtrBase = Get16Val(&FileData[0x06], PtrMode);
	InsBase = Get16Val(&FileData[0x08], PtrMode);
	
	CurPPos = PtrBase;
	CurRPos = FileSize;
	if (RegBase > CurPPos && RegBase < CurRPos)
		CurRPos = RegBase;
	if (InsBase > CurPPos && InsBase < CurRPos)
		CurRPos = InsBase;
	// CurRPos is now the next pointer after PtrBase
	MinPos = 0xFFFF;
	for (CurIns = 0x00; CurIns < 0x100; CurIns ++, CurPPos += 0x02)
	{
		if (CurPPos >= CurRPos)
			break;
		CurIPos = Get16Val(&FileData[CurPPos], PtrMode);
		if (! CurIPos)
			break;
		if (MinPos > CurIPos)
			MinPos = CurIPos;
	}
	InsBase = MinPos - InsBase;
	
	memset(&InsBank, 0x00, sizeof(INS_BANK));
	if (RegBase)
	{
		CurPPos = PtrBase;
		for (CurIns = 0x00; CurIns < 0x100; CurIns ++, CurPPos += 0x02)
		{
			CurIPos = Get16Val(&FileData[CurPPos], PtrMode);
			CurIPos -= InsBase;
			CurRPos = RegBase;
			while(CurRPos < FileSize && FileData[CurRPos])
			{
				for (CurReg = 0x00; CurReg < 0x1A; CurReg ++)
				{
					if (SMPS_INS_REGS[CurReg] == FileData[CurRPos])
					{
						InsBank.InsData[CurIns].Data[CurReg] = FileData[CurIPos];
						break;
					}
				}
				CurRPos ++;
				CurIPos ++;
			}
		}
	}
	else
	{
		CurPPos = PtrBase;
		for (CurIns = 0x00; CurIns < 0x100; CurIns ++, CurPPos += 0x02)
		{
			CurIPos = Get16Val(&FileData[CurPPos], PtrMode);
			CurIPos -= InsBase;
			while(CurRPos < FileSize && FileData[CurIPos] && FileData[CurIPos] != 0x83)
			{
				RegVal = FileData[CurIPos];
				CurIPos ++;
				for (CurReg = 0x00; CurReg < 0x1A; CurReg ++)
				{
					if (SMPS_INS_REGS[CurReg] == RegVal)
					{
						InsBank.InsData[CurIns].Data[CurReg] = FileData[CurIPos];
						break;
					}
				}
				CurIPos ++;
			}
		}
	}
	
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

static INLINE UINT16 Get16Val(UINT8* Data, UINT8 LittleEndian)
{
	UINT16 Value;
	
	if (! LittleEndian)
		Value = (Data[0x00] << 8) | (Data[0x01] << 0);
	else
		Value = (Data[0x01] << 8) | (Data[0x00] << 0);
	
	return Value;
}

static INLINE UINT16 Get16Ptr(UINT8* Data, UINT16 PtrPos)
{
	UINT16 NewOfs;
	
	switch(GET_CNV_SRC(PtrMode))
	{
	case CPTR_68K:
		NewOfs = (Data[0x00] << 8) | (Data[0x01] << 0);
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

static void AddPtrToList(UINT16 SrcPos, UINT16 SrcPtr, UINT8 CoordFlag, UINT8 ChnMask)
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
			TempOfs->ChnMask = ChnMask;
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
	TempOfs->ChnMask = ChnMask;
	TempOfs->next = NULL;
	TempLst->DstPosLst = NULL;
	TempLst->SrcPtr = SrcPtr;
	TempLst->CoordFlg = CoordFlag;
	TempLst->ChnMask = ChnMask;
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
	TempOfs->ChnMask = CurDPtr->Item->ChnMask;
	TempOfs->next = NULL;
	if (CurLst->DstPosLst == NULL)
		CurLst->DstPosLst = TempOfs;
	else
		CurOfs->next = TempOfs;
	
	return;
}

static UINT8 ChnMaskToChnID(UINT8 ChnMask)
{
	if (! (ChnMask & 0x80))
	{
		if (ChnMask == 0x16)
			return 0x00;
		else if (ChnMask < 0x04)
			return 0x01 + ChnMask;
		else
			return ChnMask;
	}
	else
	{
		return FMChnCnt + ((ChnMask & 0x60) >> 5);
	}
}

void ReadSMPSHeader(void)
{
	// search for all pointers
	UINT8 CurChn;
	UINT16 CurPos;
	UINT16 CurPtr;
	UINT8 ChnID;
	CHN_HEAD_PRE* TempChn;
	
	PtrList = PtrLEnd = NULL;
	SrcPosPtrList = SrcPosPtrLEnd = NULL;
	SMPSOffset = 0x0000;
	
	PtrMode = 0x00;
	
	CurPos = 0x0003;
	ChnCnt =  SMPSData[CurPos];
	CurPos ++;
	
	FMChnCnt = PSGChnCnt = 0x00;
	for (CurChn = 0x00; CurChn < ChnCnt; CurChn ++)
	{
		TempChn = &PreHeader[CurChn];
		TempChn->PlaybackCtrl =	 SMPSData[CurPos + 0x00];
		TempChn->ChnMask =		 SMPSData[CurPos + 0x01];
		TempChn->TempoDiv =		 SMPSData[CurPos + 0x02];
		TempChn->Ptr = Get16Ptr(&SMPSData[CurPos + 0x03], 0x0000);
		TempChn->Transpose =	 SMPSData[CurPos + 0x05];
		TempChn->ModType =		 SMPSData[CurPos + 0x06];
		TempChn->Instrument =	 SMPSData[CurPos + 0x07];
		TempChn->Volume =		 SMPSData[CurPos + 0x08];
		CurPos += 0x09;
		
		if (TempChn->PlaybackCtrl & 0x80)
		{
			ChnID = ChnMaskToChnID(TempChn->ChnMask);
			if (TempChn->ChnMask & 0x80)
			{
				ChnID -= FMChnCnt;
				if (PSGChnCnt <= ChnID)
					PSGChnCnt = ChnID + 1;
			}
			else
			{
				if (FMChnCnt <= ChnID)
					FMChnCnt = ChnID + 1;
			}
		}
	}
	FnlChnCnt = FMChnCnt + PSGChnCnt;
	
	memset(ChnList, 0x00, sizeof(CHN_HEAD) * FnlChnCnt);
	for (ChnID = 0x00; ChnID < FnlChnCnt; ChnID ++)
	{
		ChnListSrc[ChnID] = 0xFF;
		ChnList[ChnID].Ptr = 0x0000;
	}
	
	for (CurChn = 0x00; CurChn < ChnCnt; CurChn ++)
	{
		TempChn = &PreHeader[CurChn];
		if (! (TempChn->PlaybackCtrl & 0x80))
			continue;
		
		ChnID = ChnMaskToChnID(TempChn->ChnMask);
		ChnListSrc[ChnID] = CurChn;
		ChnList[ChnID].Ptr = TempChn->Ptr;
		ChnList[ChnID].KeyDisplc = TempChn->Transpose;
		ChnList[ChnID].Volume = TempChn->Volume;
		ChnList[ChnID].ModType = TempChn->ModType;
		ChnList[ChnID].PSGIns = TempChn->Instrument;
	}
	MakeSortedChannelList();
	
	/*CurPos |= 0x01;	// make an odd offset
	CurPtr = ChnList[ChnListSort[0x00]].Ptr;
	SMPSOffset = CurPtr - CurPos;*/
	SMPSOffset = Get16Val(&SMPSData[0x0000], GET_CNV_SRC(PtrMode) == CPTR_Z80) - 0x0003;
	
	return;
}

static void MakeSortedChannelList(void)
{
	UINT8 CurChn;
	UINT8 CurChn2;
	UINT16* TempArr;
	UINT16 MinPtr;
	UINT8 MinChn;
	
	TempArr = (UINT16*)malloc(FnlChnCnt * sizeof(UINT16));
	for (CurChn = 0x00; CurChn < FnlChnCnt; CurChn ++)
		TempArr[CurChn] = ChnList[CurChn].Ptr;
	
	for (CurChn = 0x00; CurChn < FnlChnCnt; CurChn ++)
	{
		MinPtr = TempArr[0x00];
		MinChn = 0x00;
		for (CurChn2 = 0x01; CurChn2 < FnlChnCnt; CurChn2 ++)
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

static void FillCFStructs(COORD_FLAG* CFMain, UINT8 CFMode)
{
	UINT16 CurFlag;
	COORD_FLAG* TempFlag;
	
	TempFlag = CFMain;
	for (CurFlag = 0xE0; CurFlag <= 0xFF; CurFlag ++, TempFlag ++)
	{
		TempFlag->Len = 0x01;
		TempFlag->Type = CFTYPE_UNUSED;
		TempFlag->JmpOfs = 0x00;	// default is no offset
		TempFlag->reserved = 0x00;
		
		// do some general flags
		switch(CurFlag)
		{
		case 0xEC:	// Change Volume
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_VOLUME;
			break;
		case 0xEF:	// Set Instrument
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_SET_INS;
			break;
		case 0xF2:	// Stop Track
			TempFlag->Len = 0x01;
			TempFlag->Type = CFTYPE_STOP_TRACK;
			break;
		case 0xF3:	// Set PSG Noise
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_NO_CHANGE;
			break;
		case 0xF4:	// Set Modulation Type
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_NO_CHANGE;
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
		case 0xF9:	// Return from Subroutine
			TempFlag->Len = 0x01;
			TempFlag->Type = CFTYPE_RETURN;
			break;
		case 0xFA:	// Set Tempo Divider
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_TEMPO;
			break;
		case 0xFB:	// Change Key Displacement
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_NO_CHANGE;
			break;
		}
		if (TempFlag->Type != CFTYPE_UNUSED)
			continue;
		
		if (CFMode == CFMODE_PRE)
		{
			switch(CurFlag)
			{
			case 0xE0:	// unused
			case 0xE1:	// unused
			case 0xE2:	// unused
			case 0xE3:	// unused
			case 0xE7:	// unused
			case 0xEE:	// unused
			case 0xF1:	// unused
			case 0xF5:	// unused
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case 0xE4:	// change Tempo
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_TEMPO;
				break;
			case 0xE5:	// Enable DAC
			case 0xE6:	// Disable DAC
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case 0xE8:	// Lock PSG frequency
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case 0xE9:	// Change DAC drum set
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_SPECIAL;
				break;
			case 0xEA:	// effectively same at "no attack"
			case 0xEB:	// effectively same at "no attack"
			case 0xED:	// effectively same at "no attack"
				TempFlag->Len = 0x01;	// actually Len = 0x02, but it should work this way, too
				TempFlag->Type = CFTYPE_NO_ATK;
				break;
		//	case 0xEC:	// Change Volume
		//	case 0xEF:	// Set Instrument
			case 0xF0:	// Set Volume
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_VOLUME_SET;
				break;
		//	case 0xF2:	// Stop Track
		//	case 0xF3:	// Set PSG Noise
		//	case 0xF4:	// Set Modulation Type
		//	case 0xF6:	// Jump
		//	case 0xF7:	// Loop
		//	case 0xF8:	// Call Subroutine
		//	case 0xF9:	// Return from Subroutine
		//	case 0xFA:	// Set Tempo Divider
		//	case 0xFB:	// Change Key Displacement
			case 0xFD:	// Pan C
			case 0xFE:	// Pan R
			case 0xFF:	// Pan L
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_PAN;
				break;
			}
		}
		else
		{
			switch(CurFlag)
			{
			case 0xE0:	// Pan L
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_PAN;
				break;
			case 0xE1:	// Frequency Displacement
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_NO_CHANGE;
				break;
			case 0xE2:	// set communication value
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_NO_CHANGE;
				break;
			case 0xE3:	// silence + stop track
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_STOP_TRACK;
				break;
			case 0xE4:	// Set Pan Animation
				TempFlag->Len = 0x82;	// 0x02 [+ 0x04]
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case 0xE5:	// Change Volume PSG+FM
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_VOLUME;
				break;
			case 0xE6:	// Change Volume (FM)
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_VOLUME;
				break;
			case 0xE7:	// No-Attack
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_NO_ATK;
				break;
			case 0xE8:	// Set Note Fill
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_NO_CHANGE;
				break;
			case 0xE9:	// Set LFO parameters
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case 0xEA:	// Set Tempo Modifier
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_TEMPO;
				break;
			case 0xEB:	// Play Sound ID
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
		//	case 0xEC:	// Change Volume
			case 0xED:	// Send YM2612 Command (Port depends on current channel)
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case 0xEE:	// Send YM2612 Command (Port 0)
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
		//	case 0xEF:	// Set Instrument
			case 0xF0:	// Set Modulation
				TempFlag->Len = 0x05;
				TempFlag->Type = CFTYPE_MODULATION;
				break;
			case 0xF1:	// Set Modulation Type PSG+FM
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_MODULATION;
				break;
		//	case 0xF2:	// Stop Track
		//	case 0xF3:	// Set PSG Noise
		//	case 0xF4:	// Set Modulation Type
			case 0xF5:	// Set PSG instrument
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_SET_INS;
				break;
		//	case 0xF6:	// Jump
		//	case 0xF7:	// Loop
		//	case 0xF8:	// Call Subroutine
		//	case 0xF9:	// Return from Subroutine
		//	case 0xFA:	// Set Tempo Divider
		//	case 0xFB:	// Change Key Displacement
			case 0xFC:	// Enable Modulaition
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_MODULATION;
				break;
			case 0xFD:	// Disable Modulation
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_MODULATION;
				break;
			case 0xFE:
				TempFlag->Len = 0x05;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case 0xFF:
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_SPECIAL;
				break;
			}
		}
	}
	
	return;
}

void PreparseSMPS(void)
{
	// preparse complete SMPS file to get all pointers
	UINT8 CurChn;
	UINT8 CurChnMask;
	UINT16 CurPos;
	UINT16 CurPtr;
	bool TrackEnd;
	UINT8 GosubID;
	UINT16 GosubPtr[0x100];
	UINT8 CoordFlg;
	COORD_FLAG* CurFlg;
	UINT16 TempPtr;
	UINT16 CurIns;
	
	memset(ProcMask, 0x00, ProcMskSize);
	FillCFStructs(CFMain, GET_CNV_SRC(CoordMode));
	
	AddPtrToList(0xFFFF, 0xFFFF, 0x7F, 0xFF);
	
	CurPos = 0x0003;
	SetProcMask(0x00, CurPos);
	
	SetProcMask(CurPos, 0x01);	// channel count
	CurPos ++;
	SetProcMask(CurPos, 0x09 * ChnCnt);
	
	// recalc pointers with new SMPS Offset
	for (CurChn = 0x00; CurChn < FnlChnCnt; CurChn ++)
	{
		CoordFlg = ChnListSrc[CurChn];
		if (CoordFlg < 0xFF)
		{
			CurChnMask = PreHeader[ChnListSrc[CurChn]].ChnMask;
			AddPtrToList(CurPos + 0x09 * CoordFlg, ChnList[CurChn].Ptr - SMPSOffset, CurChn, CurChnMask);
		}
		else
		{
			AddPtrToList(0x0000, ChnList[CurChn].Ptr, CurChn, 0xFF);
		}
	}
	
	for (CurChn = 0x00; CurChn < FnlChnCnt; CurChn ++)
	{
		// Parse Channel Data
		CoordFlg = ChnListSort[CurChn];
		if (! ChnList[CoordFlg].Ptr || ChnListSrc[CoordFlg] == 0xFF)
			continue;
		CurPos = ChnList[CoordFlg].Ptr - SMPSOffset;
		CurChnMask = PreHeader[ChnListSrc[CoordFlg]].ChnMask;
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
				CurFlg = &CFMain[CoordFlg & 0x1F];
				
				switch(CurFlg->Type)
				{
				case CFTYPE_STOP_TRACK:
					TrackEnd = true;
					SetProcMask(CurPos, CurFlg->Len);
					CurPos += CurFlg->Len;
					break;
				// enumerate instruments
				case CFTYPE_SET_INS:
					CurIns = SMPSData[CurPos + 0x01];
					if (CurChnMask < 0x10)
					{
						// set FM Instrument
						SET_BIT(InsBank.InsUsage, CurIns);	// mark as "used"
					}
					else
					{
						// set DAC/PSG instrument
						// nothing to do
					}
					SetProcMask(CurPos, CurFlg->Len);
					CurPos += CurFlg->Len;
					break;
				// Jumps with Pointer
				case CFTYPE_LOOP:
				case CFTYPE_LP_JMP:
				case CFTYPE_GOTO:
				case CFTYPE_GOSUB:
					TempPtr = CurPos + CurFlg->JmpOfs;
					CurPtr = Get16Ptr(&SMPSData[TempPtr], TempPtr);
					AddPtrToList(TempPtr, CurPtr, CoordFlg, CurChnMask);
					SetProcMask(CurPos, CurFlg->Len);
					CurPos += CurFlg->Len;
					
					if (CurFlg->Type == CFTYPE_GOTO)
					{
						// if we jump to an offset that's already processed,
						// then it's definately a loop
						if (GetProcMask(CurPtr))
							TrackEnd = true;
						
						CurPos = CurPtr;
					}
					else if (CurFlg->Type == CFTYPE_GOSUB)
					{
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
						// nothing more to do for preSMPS
					}
					SetProcMask(CurPos, CurPtr);
					CurPos += CurPtr;
					break;
				}
			}
		}
	}
	
	for (CurIns = 0x00; CurIns < 0x100; CurIns ++)
	{
		if (GET_BIT(InsBank.InsUsage, CurIns))
		{
			InsBank.InsAssign[CurIns] = InsBank.InsUsed;
			InsBank.InsSrc[InsBank.InsUsed] = (UINT8)CurIns;
			InsBank.InsUsed ++;
		}
	}
	
	return;
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
	UINT8 CurChnMask;
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
	bool TrackBreak;
	UINT8 TempByt;
	UINT8 CurChnVol;
	COORD_FLAG* TempCF;
	UINT8 CmdLen;
	UINT8 CurDACBank;
	UINT16 EmptyTrkPos;
	
	memset(ProcMask, 0x00, ProcMskSize);
	SMPSNewLen = FnlChnCnt * 0x06 + SMPSLen * 2;
	SMPSNewData = (UINT8*)malloc(SMPSNewLen);
	memset(SMPSNewData, 0x00, SMPSNewLen);
	
	CurPos = 0x00;
	CmdLen = 0x04 + 0x09 * ChnCnt;
	SetProcMask(CurPos, CmdLen);
	CurPos += CmdLen;
	
	TempoDiv = PreHeader[0x00].TempoDiv;
	
	DstPos = 0x00;
	// 0x00 and 0x01 are set later
	InsPtr = 0xFFFF;
	AddNewPtrOfsToList_FromOfs(InsPtr, DstPos, 0x7F);
	SMPSNewData[DstPos + 0x02] = FMChnCnt;
	SMPSNewData[DstPos + 0x03] = PSGChnCnt;
	SMPSNewData[DstPos + 0x04] = TempoDiv;
	SMPSNewData[DstPos + 0x05] = SMPSData[0x02];
	DstPos += 0x06;
	
	// recalc pointers with new SMPS Offset
	for (CurChn = 0x00; CurChn < FMChnCnt; CurChn ++)
	{
		// 0x00 and 0x01 are set later
		ChnID = ChnListSrc[CurChn];
		if (ChnID == 0xFF)
			AddNewPtrOfsToList_FromOfs(0x0000, DstPos, 0x00 | CurChn);
		else
			AddNewPtrOfsToList_FromOfs(0x04 + ChnID * 0x09, DstPos, 0x00 | CurChn);
		SMPSNewData[DstPos + 0x02] = ChnList[CurChn].KeyDisplc;
		if (CurChn)
			SMPSNewData[DstPos + 0x02] += 12;
		SMPSNewData[DstPos + 0x03] = ChnList[CurChn].Volume;
		DstPos += 0x04;
	}
	for (CurChn = 0x00; CurChn < PSGChnCnt; CurChn ++)
	{
		// 0x00 and 0x01 are set later
		ChnID = ChnListSrc[FMChnCnt + CurChn];
		AddNewPtrOfsToList_FromOfs(0x04 + ChnID * 0x09, DstPos, 0x10 | CurChn);
		SMPSNewData[DstPos + 0x02] = ChnList[FMChnCnt + CurChn].KeyDisplc - 12;
		SMPSNewData[DstPos + 0x03] = ChnList[FMChnCnt + CurChn].Volume;
		SMPSNewData[DstPos + 0x04] = ChnList[FMChnCnt + CurChn].ModType;
		SMPSNewData[DstPos + 0x05] = ChnList[FMChnCnt + CurChn].PSGIns;
		DstPos += 0x06;
	}
	
	EmptyTrkPos = 0x0000;
	for (ChnID = 0x00; ChnID < FnlChnCnt; ChnID ++)
	{
		// Parse Channel Data
		CurChn = ChnListSort[ChnID];
		if (ChnListSrc[CurChn] == 0xFF)
		{
			if (! EmptyTrkPos)
			{
				EmptyTrkPos = DstPos;
				AddNewPosToList(ChnList[CurChn].Ptr, DstPos);
				SMPSNewData[DstPos] = 0xF2;
				DstPos ++;
			}
			continue;
		}
		CurPos = ChnList[CurChn].Ptr - SMPSOffset;
		CurChnMask = PreHeader[ChnListSrc[CurChn]].ChnMask;
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
		CurChnVol = ChnList[CurChn].Volume;
		CurDACBank = DACMap.BnkDefault;
		if (GetProcMask(CurPos))
			TrackEnd = true;
		
		if (CurChnMask < 0x80 && ChnList[CurChn].ModType)
		{
			SMPSNewData[DstPos + 0x00] = 0xF4;
			SMPSNewData[DstPos + 0x01] = ChnList[CurChn].ModType;
			DstPos += 0x02;
		}
		
		while(! TrackEnd && ! TrackBreak && CurPos < SMPSLen)
		{
		
		AddNewPosToList(CurPos, DstPos);
		if (SMPSData[CurPos] < 0xE0)
		{
			TempByt = SMPSData[CurPos];
			if (TempByt >= 0x81 && CurChnMask == 0x16)
			{
				if (CurDACBank && CurDACBank <= DACMap.BnkCount)
					TempByt += DACMap.Bank[CurDACBank - 1].Base;
			}
			SMPSNewData[DstPos] = TempByt;
			
			SetProcMask(CurPos, 0x01);
			CurPos ++;
			DstPos ++;
		}
		else
		{
			TempCF = &CFMain[SMPSData[CurPos] & 0x1F];
			
			CmdLen = TempCF->Len & 0x7F;
			if (TempCF->Len & 0x80)
			{
				// nothing to do here right now
			}
			
			TempByt = TempCF->Type;
			switch(TempByt)
			{
			case CFTYPE_NO_CHANGE:
				for (TempByt = 0x00; TempByt < CmdLen; TempByt ++)
				{
					SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
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
			case CFTYPE_STOP_TRACK:	// Flag F2 / E3
			case CFTYPE_RETURN:		// Flag F9
				for (TempByt = 0x00; TempByt < CmdLen; TempByt ++)
				{
					SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
					AddNewPosToList(CurPos + TempByt, DstPos + TempByt);
				}
				
				TrackEnd = true;
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				break;
			case CFTYPE_GOTO:	// Flag F6
			case CFTYPE_LOOP:	// Flag F7
			case CFTYPE_GOSUB:	// Flag F8
			case CFTYPE_LP_JMP:	// Flag EB
				for (TempByt = 0x00; TempByt < CmdLen; TempByt ++)
				{
					SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
					AddNewPosToList(CurPos + TempByt, DstPos + TempByt);
				}
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + TempCF->JmpOfs], CurPos + TempCF->JmpOfs);
				AddNewPtrOfsToList(CurPtr, DstPos + TempCF->JmpOfs, SMPSData[CurPos]);
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				
				if (TempCF->Type == CFTYPE_GOTO)
				{
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
				}
				else if (TempCF->Type == CFTYPE_GOSUB)
				{
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
				}
				break;
			case CFTYPE_VOLUME:
				TempByt = SMPSData[CurPos + 0x00];
				switch(SMPSData[CurPos])
				{
				case 0xEC:
					TempByt = SMPSData[CurPos + 0x01];
					CurChnVol += TempByt;
					break;
				case 0xF0:
					printf("Warning: absolute volume\n");
					TempByt = SMPSData[CurPos + 0x01] - CurChnVol;
					CurChnVol += TempByt;
					break;
				}
				SMPSNewData[DstPos + 0x00] = (CurChnMask < 0x80) ? 0xE6 : 0xEC;
				SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x01];
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				break;
			case CFTYPE_TEMPO:
				if (SMPSData[CurPos] == 0xE4)
				{
					printf("Warning: Tempo Change %+d !\n", (INT8)SMPSData[CurPos + 0x01]);
				}
				else
				{
					for (TempByt = 0x00; TempByt < CmdLen; TempByt ++)
					{
						SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
						AddNewPosToList(CurPos + TempByt, DstPos + TempByt);
					}
					DstPos += CmdLen;
				}
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				break;
			case CFTYPE_SET_INS:		// Flag EF
				TempByt = SMPSData[CurPos + 0x01];
				if (! (CurChnMask & 0x80))
				{
					SMPSNewData[DstPos + 0x00] = 0xEF;
					if (CurChnMask < 0x10)
						SMPSNewData[DstPos + 0x01] = InsBank.InsAssign[TempByt];
					else
						SMPSNewData[DstPos + 0x01] = TempByt;
					DstPos += 0x02;
					
					if (InsBank.InsData[TempByt].Data[0x19])
					{
						SMPSNewData[DstPos + 0x00] = 0xE0;
						SMPSNewData[DstPos + 0x01] = InsBank.InsData[TempByt].Data[0x19];
						DstPos += 0x02;
					}
				}
				else
				{
					SMPSNewData[DstPos + 0x00] = 0xF5;
					SMPSNewData[DstPos + 0x01] = TempByt;
					DstPos += 0x02;
				}
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				break;
			case CFTYPE_PAN:
				if (TempCF->Len > 0x01)
				{
					for (TempByt = 0x00; TempByt < CmdLen; TempByt ++)
					{
						SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
						AddNewPosToList(CurPos + TempByt, DstPos + TempByt);
					}
					DstPos += CmdLen;
				}
				else
				{
					switch(SMPSData[CurPos])
					{
					case 0xFD:
						TempByt = 0xC0;
						break;
					case 0xFE:
						TempByt = 0x40;
						break;
					case 0xFF:
						TempByt = 0x80;
						break;
					}
					SMPSNewData[DstPos + 0x00] = 0xE0;
					SMPSNewData[DstPos + 0x01] = TempByt;
					DstPos += 0x02;
				}
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				break;
			case CFTYPE_NO_ATK:
				SMPSNewData[DstPos + 0x00] = 0xE7;
				DstPos += 0x01;
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				break;
			case CFTYPE_SPECIAL:
				switch(SMPSData[CurPos])
				{
				case 0xE9:	// set DAC Bank
					CurDACBank = SMPSData[CurPos + 0x01];
					if (CurDACBank > DACMap.BnkCount)
					{
						printf("Track %u, Pos 0x%04X: Warning: DAC Bank %02X selected! (only %02X loaded)\n",
								CurChn, CurPos, CurDACBank, DACMap.BnkCount);
					}
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
	printf("The song uses 0x%02X instruments.\n", InsBank.InsUsed);
	CopyInstrumentTable(&DstPos, InsBank.InsUsed);
	
	SMPSNewLen = DstPos;
	
	CurPtr = GetProcMaskNonusage();
	if (CurPtr)
	{
		printf("Conversion missed 0x%X (likely unused) byte%s:\n", CurPtr, (CurPtr == 1) ? "" : "s");
		PrintProcMaskNonusage();
	}
	else
	{
		printf("All bytes were used - cool.\n");
	}
	
	return;
}

static void CopyInstrumentTable(UINT16* DstOfs, UINT8 InsCnt)
{
	const UINT8 ALGO_OPS[0x08] = {0x08, 0x08, 0x08, 0x08, 0x0A, 0x0E, 0x0E, 0x0F};
	INS_BNK_ENTRY* TempIns;
	UINT16 SrcPos;
	UINT16 DstPos;
	UINT8 CurIns;
	UINT8 CurGrp;	// Operator Group
	UINT8 CurOp;
	UINT8 AlgoOps;
	
	DstPos = *DstOfs;
	for (CurIns = 0x00; CurIns < InsCnt; CurIns ++)
	{
		TempIns = &InsBank.InsData[InsBank.InsSrc[CurIns]];
		
		SrcPos = 0x00;
		AlgoOps = ALGO_OPS[TempIns->Data[SrcPos] & 0x07];
		
		SMPSNewData[DstPos] = TempIns->Data[SrcPos];
		SrcPos ++;	DstPos ++;
		
		for (CurGrp = 0x00; CurGrp < 0x06; CurGrp ++)
		{
			SMPSNewData[DstPos + 0x00] = TempIns->Data[SrcPos + 0x00];
			SMPSNewData[DstPos + 0x01] = TempIns->Data[SrcPos + 0x01];
			SMPSNewData[DstPos + 0x02] = TempIns->Data[SrcPos + 0x02];
			SMPSNewData[DstPos + 0x03] = TempIns->Data[SrcPos + 0x03];
			
			if (CurGrp == 0x05)
			{
				// fix Total Level operators
				for (CurOp = 0x00; CurOp < 0x04; CurOp ++)
				{
					// All TL operators that are affected by volume changes
					// should have bit 7 set. All others should have bit 7 cleared.
					// For SMPS Z80 games, the *must* have bit 7 set or cleared respectively.
					if (AlgoOps & (1 << CurOp))
						SMPSNewData[DstPos + CurOp] |= 0x80;
				}
			}
			
			SrcPos += 0x04;	DstPos += 0x04;
		}
	}
	*DstOfs = DstPos;
	
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
			}
#ifdef _DEBUG
			if (CurLst->DstPtr == 0xFFFF)
			{
				printf("Critical Error! No new pointer found for 0x%04X!\n", CurLst->SrcPtr);
				getchar();
			}
#endif
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
	
	return;
}
