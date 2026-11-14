// SMPS Converter (based on SMPS Converter)
// --------------
// Programmed by Valley Bell, 2012

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <malloc.h>
#include <memory.h>
#include <math.h>

typedef unsigned char	bool;
typedef unsigned char	UINT8;
typedef signed char		INT8;
typedef unsigned short	UINT16;
typedef signed short	INT16;
typedef unsigned int	UINT32;

#define false	0x00
#define true	0x01

#define PAN_DB	-3.0102999566398

#define INLINE	__inline
#ifndef WIN32
#define _stricmp	strcasecmp
#endif

typedef struct mapping_table MAP_TBL;


int main(int argc, char* argv[]);

void LoadMappingFile(const char* MapFileName, MAP_TBL* MapData);

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

static void IgnoreMsg(UINT8 CurChn, UINT16 CurPos);
static void WarningMsg(UINT8 CurChn, UINT16 CurPos);
static void WarningMsgFlame(UINT8 CurChn, UINT16 CurPos, UINT16 NewPos);
static void WarningMsgInvalid(UINT8 CurChn, UINT16 CurPos);

void ConvertSMPS(void);
static void ParseSubroutine(UINT16 StartPos, UINT8* CurVol, UINT8* CurPanOn);
static void ParseLoop(UINT16 StartPos, UINT8* CurVol, UINT8* CurPanOn);
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
	UINT8 Add;
	UINT8 MapCount;
	MAP_VAL* Map;
};


#define NIBBLE_LOW(x)	(((x) & 0x0F) >> 0)
#define NIBBLE_HIGH(x)	(((x) & 0xF0) >> 4)

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
	CFTYPE_SIMPLE_CHANGE,
	CFTYPE_SPECIAL
};
typedef struct coordination_flag
{
	UINT8 Type;
	UINT8 Len;
	UINT8 JmpOfs;
	UINT8 reserved;
} COORD_FLAG;


UINT8 CoordMode;
UINT8 TempoMode;

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

UINT8 ChnCnt;
UINT8 FMChnCnt;
UINT8 PSGChnCnt;
CHN_HEAD* ChnList;
UINT8* ChnListSort;

MAP_TBL DACMap;
COORD_FLAG CFMain[0x20];

int main(int argc, char* argv[])
{
	FILE* hFile;
	UINT8 RetVal;
	PTR_LIST* CurLst;
	OFS_LIST* CurOfs;
	
	printf("SMPS Converter\n--------------\n");
	if (argc < 3)
	{
		printf("Usage: SMPSConv.exe smps_in.bin smps_out.bin\n");
		return 0;
	}
	
	LoadMappingFile("PCMMap.ini", &DACMap);
	
	RetVal = LoadSMPSFile(argv[1]);
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
	printf("\n");
	
	printf("FM/DAC Tracks: %u, PSG Tracks: %u\n", FMChnCnt, PSGChnCnt);
	PreparseSMPS();
	printf("\n");
	
	printf("Pointer List:\nCoord\tPntFile\tPntReal\tPos\n");
	CurLst = PtrList;
	while(CurLst != NULL)
	{
		printf("%02X\t%04X\t%04X\t", CurLst->CoordFlg, CurLst->SrcPtr, CurLst->SrcPtr);
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
	
	hFile = fopen(argv[2], "wb");
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


void LoadMappingFile(const char* MapFileName, MAP_TBL* MapData)
{
	FILE* hFile;
	char TempStr[0x40];
	UINT8 CurMap;
	int TempInt;
	char* TempPnt;
	MAP_VAL* TempMap;
	
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
			while(TempStr[strlen(TempStr) - 1] != '\n')
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
		
		if (! _stricmp(TempStr, "Add"))
		{
			MapData->Add = (UINT8)strtoul(TempPnt, NULL, 0x10);
		}
		else
		{
			TempInt = (unsigned int)strtoul(TempStr, NULL, 0x10);
			CurMap = TempInt & 0x7F;
			if (! CurMap)
				continue;
			
			TempMap = &MapData->Map[CurMap];
			TempMap->MapFrom = (UINT8)strtoul(TempStr, NULL, 0x10);
			TempMap->MapTo = (UINT8)strtoul(TempPnt, NULL, 0x10);
		}
	}
	
	fclose(hFile);
	
	return;
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
	
	NewOfs = (Data[0x00] << 8) | (Data[0x01] << 0);
	if (PtrPos)
		NewOfs += PtrPos + 0x01;
	
	return NewOfs;
}

static INLINE void Put16Ptr(UINT8* Data, UINT16 Ptr)
{
	Data[0x00] = (Ptr & 0xFF00) >> 8;
	Data[0x01] = (Ptr & 0x00FF) >> 0;
	
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
	
	CurPos = 0x00;
	CurPtr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
	FMChnCnt = SMPSData[CurPos + 0x02];
	PSGChnCnt = SMPSData[CurPos + 0x03];
	//ChnCnt = SMPSData[CurPos + 0x02];
	//if (ChnCnt > 0x09)
	if (FMChnCnt > 0x07 || PSGChnCnt > 0x04)
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

static void FillCFStructs(COORD_FLAG* CFMain)
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
		if (CurFlag >= 0xFC)
		{
			TempFlag->Type = CFTYPE_INVALID;
			continue;
		}
		
		switch(CurFlag)
		{
		case 0xE0:	// Pan
		case 0xE1:	// Frequency Displacement
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_SIMPLE_CHANGE;
			break;
		case 0xE2:	// unknown
		case 0xE3:	// unknown
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_UNUSED;
			break;
		case 0xE4:	// unused
		case 0xE5:	// unused
			TempFlag->Len = 0x01;
			TempFlag->Type = CFTYPE_INVALID;
			break;
		case 0xE6:	// Change Volume
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_VOLUME;
			break;
		case 0xE7:	// No-Attack
			TempFlag->Len = 0x01;
			TempFlag->Type = CFTYPE_NO_CHANGE;
			break;
		case 0xE8:	// Set Note Fill
			TempFlag->Len = 0x02;
			//TempFlag->Type = CFTYPE_NOTE_FILL;
			TempFlag->Type = CFTYPE_NO_CHANGE;
			break;
		case 0xE9:	// unused
			TempFlag->Len = 0x01;
			TempFlag->Type = CFTYPE_INVALID;
			break;
		case 0xEA:	// Set Tempo Modifier
		case 0xEB:	// Set Tempo Divider for ALL Tracks
			TempFlag->Len = 0x02;
			//TempFlag->Type = CFTYPE_TEMPO;
			TempFlag->Type = CFTYPE_NO_CHANGE;
			break;
		case 0xEC:	// unused
		case 0xED:	// unused
		case 0xEE:	// unused
			TempFlag->Len = 0x01;
			TempFlag->Type = CFTYPE_INVALID;
			break;
		case 0xEF:	// Set Instrument
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_FM_INS;
			break;
		case 0xF0:	// unknown
		case 0xF1:	// unknown
			TempFlag->Len = 0x01;
			TempFlag->Type = CFTYPE_UNUSED;
			break;
		case 0xF2:	// Stop Track
			TempFlag->Len = 0x01;
			TempFlag->Type = CFTYPE_STOP_TRACK;
			break;
		case 0xF3:	// unused
		case 0xF5:	// unused
			//TempFlag->Len = 0x01;
			//TempFlag->Type = CFTYPE_INVALID;
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_NO_CHANGE;
			break;
		case 0xF4:	// Jump (same as F6)
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
		case 0xF9:	// Return
			TempFlag->Len = 0x01;
			TempFlag->Type = CFTYPE_RETURN;
			break;
		case 0xFA:	// unknown
			TempFlag->Len = 0x01;
			TempFlag->Type = CFTYPE_UNUSED;
			break;
		case 0xFB:	// Change Key Displacement
			TempFlag->Len = 0x02;
			TempFlag->Type = CFTYPE_KEY_DISPLC;
			break;
		}
	}
	TempFlag = &CFMain[0x1F];
	TempFlag->Len = 0x01;
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
	UINT16 GosubPtr[0x10];
	UINT16 InsPtr;
	UINT8 CoordFlg;
	COORD_FLAG* CurFlg;
	UINT16 TempPtr;
	
	memset(ProcMask, 0x00, ProcMskSize);
	FillCFStructs(CFMain);
	
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
				CurFlg = &CFMain[CoordFlg & 0x1F];
				
				switch(CurFlg->Type)
				{
				case CFTYPE_STOP_TRACK:
					TrackEnd = true;
					SetProcMask(CurPos, CurFlg->Len);
					CurPos += CurFlg->Len;
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
						if (GosubID < 0x10)
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
					SetProcMask(CurPos, CurPtr);
					CurPos += CurPtr;
					break;
				}
			}
		}
	}
	
	return;
}

static UINT8 DACSndPatch(UINT8 ChnIns, UINT8 DACSnd)
{
	UINT8 RetSnd;
	
	if (ChnIns >= DACMap.MapCount)
		return DACSnd;
	
	if (DACMap.Map[ChnIns].MapFrom == ChnIns)
		RetSnd = DACMap.Map[ChnIns].MapTo;
	else
		return DACSnd;
	if (ChnIns == 0x0D)
	{
		if (DACSnd == 0xA2)
			RetSnd = 0x90;
		else if (DACSnd == 0x9B)
			RetSnd = 0x91;
		else if (DACSnd == 0x96)
			RetSnd = 0x92;
		else
			RetSnd = 0x93;
	}
	RetSnd += DACMap.Add;
	RetSnd |= 0x80;
	if (RetSnd >= 0xE0)
		RetSnd = 0x80;
	
	return RetSnd;
}

static UINT8 ConvertVolume(UINT8 VolPCM, UINT8 PanVal, UINT8 ConvMode)
{
	//UINT16 LRVol;
	UINT8 RetVol;
	double DBVol;
	
	//            0x0F         *  0xFF  +        0x0F         *  0xFF = 0x1DE2
/*	LRVol = NIBBLE_LOW(PanVal) * VolPCM + NIBBLE_HIGH(PanVal) * VolPCM;
	DBVol = log(LRVol / 7650.0) / log(2.0) * 6.0;*/
	DBVol = log(VolPCM / 255.0) / log(2.0) * 6.0;
	switch(ConvMode & 0x0F)
	{
	case 0x00:	// FM Mode
	//	if (ConvMode & 0x80)
	//		DBVol -= PAN_DB;
		// DBVol = -TL * 3 / 4
		RetVol = (UINT8)(8 + -DBVol / 3 * 4 + 0.5);
		if (RetVol > 0x7F)
			RetVol = 0x7F;
		break;
	case 0x01:	// PSG Mode
		// DBVol = -TL * 2
		RetVol = (UINT8)(-DBVol / 2 + 0.5);
		if (RetVol >= 0x0F)
			RetVol = 0x0E;
		break;
	}
	
	return RetVol;
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
		printf("Track %u, Pos 0x%04X: Command %02X!",
				CurChn, CurPos, SMPSData[CurPos + 0x00]);
	}
	else
	{
		printf("Track %u, Pos 0x%04X: Command %02X %02X!",
				CurChn, CurPos, SMPSData[CurPos + 0x00], SMPSData[CurPos + 0x01]);
	}
	
	return;
}

static void WarningMsgFlame(UINT8 CurChn, UINT16 CurPos, UINT16 NewPos)
{
	printf("Track %u, Pos 0x%04X: Writing S3K-Flamewing Command %02X %02X!",
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
	UINT16 GosubPtr[0x10];
	UINT8 GosubVol[0x10];
	UINT8 GosubPan[0x10];
	UINT16 InsPtr;
	UINT8 MaxIns;
	bool TrackBreak;
	UINT8 TempByt;
	//UINT16 TempSht;
	UINT8 CurChnVolPCM;
	UINT8 CurChnVolMD;
	UINT8 CurChnPan;
	UINT8 PanOn;
	UINT8 CurIns;
	UINT8 CurChnKeyDplc;
	COORD_FLAG* TempCF;
	UINT8 CmdLen;
	
	memset(ProcMask, 0x00, ProcMskSize);
	SMPSNewLen = SMPSLen * 2;
	SMPSNewData = (UINT8*)malloc(SMPSNewLen);
	memset(SMPSNewData, 0x00, SMPSNewLen);
	
	CurPos = 0x00;
	DstPos = 0x00;
	InsPtr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
	MaxIns = 0x00;
	
	// 0x00 and 0x01 are set later
	AddNewPtrOfsToList_FromOfs(CurPos, DstPos, 0x7F);
	SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];
	SMPSNewData[DstPos + 0x03] = SMPSData[CurPos + 0x03];
	SMPSNewData[DstPos + 0x04] = SMPSData[CurPos + 0x04];
	SMPSNewData[DstPos + 0x05] = SMPSData[CurPos + 0x05] + 1;
	TempoDiv = SMPSData[CurPos + 0x04];
	
	SetProcMask(CurPos, 0x06);
	CurPos += 0x06;
	DstPos += 0x06;
	
	/*FMChnCnt = ChnCnt;
	if (FMChnCnt > 0x06)
	{
		PSGChnCnt = FMChnCnt - 0x06;
		FMChnCnt = 0x06;
	}
	else
	{
		PSGChnCnt = 0x00;
	}*/
	
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
		SMPSNewData[DstPos + 0x03] = ConvertVolume(SMPSData[CurPos + 0x03], 0xFF, 0x00);
		
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
		SMPSNewData[DstPos + 0x03] = ConvertVolume(SMPSData[CurPos + 0x03], 0xFF, 0x01);
		SMPSNewData[DstPos + 0x04] = 0x00;
		SMPSNewData[DstPos + 0x05] = 0x00;
		
		SetProcMask(CurPos, 0x06);
		CurPos += 0x06;
		DstPos += 0x06;
	}
	
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
		CurChnVolPCM = ChnList[CurChn].Volume;
		CurChnPan = 0xFF;
		PanOn = 0x00;
		CurChnVolMD = ConvertVolume(CurChnVolPCM, CurChnPan,
									((CurChn < FMChnCnt) ? 0x00 : 0x01) | (PanOn << 7));
		CurChnKeyDplc = ChnList[CurChn].KeyDisplc;
		if (GetProcMask(CurPos))
			TrackEnd = true;
		
		while(! TrackEnd && ! TrackBreak && CurPos < SMPSLen)
		{
		
		AddNewPosToList(CurPos, DstPos);
		if (SMPSData[CurPos] < 0xE0)
		{
			if (CurChn == 0x00 && SMPSData[CurPos] > 0x80)
				SMPSNewData[DstPos] = DACSndPatch(CurIns, SMPSData[CurPos]);
			else
				SMPSNewData[DstPos] = SMPSData[CurPos];
			
			SetProcMask(CurPos, 0x01);
			CurPos ++;
			DstPos ++;
		}
		else
		{
			TempCF = &CFMain[SMPSData[CurPos] & 0x1F];
			CmdLen = TempCF->Len & 0x7F;
			switch(TempCF->Type)
			{
			case CFTYPE_NO_CHANGE:
				for (TempByt = 0x00; TempByt < CmdLen; TempByt ++)
					SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
				
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
			case CFTYPE_STOP_TRACK:	// Flag F2
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
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + 0x03], CurPos + 0x03);
				AddNewPtrOfsToList(CurPtr, DstPos + 0x03, 0xF7);
				
				ParseLoop(CurPos, &CurChnVolPCM, &PanOn);
				if (CurChn < FMChnCnt)
					CurChnVolMD = ConvertVolume(CurChnVolPCM, CurChnPan, 0x00 | (PanOn << 7));
				else
					CurChnVolMD = ConvertVolume(CurChnVolPCM, CurChnPan, 0x01);
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
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
					if (GosubID < 0x10)
					{
						// Queue jump
						GosubPtr[GosubID] = CurPtr;
						GosubID ++;
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
				
				if (! GetProcMask(CurPtr))
				{
					for (TempByt = 0x00; TempByt < GosubID; TempByt ++)
					{
						if (GosubPtr[TempByt] == CurPtr)
							break;
					}
					if (TempByt >= GosubID && GosubID < 0x10)
					{
						// Queue jump
						GosubPtr[GosubID] = CurPtr;
						GosubVol[GosubID] = CurChnVolPCM;
						GosubPan[GosubID] = PanOn;
						GosubID ++;
					}
				}
				ParseSubroutine(CurPtr, &CurChnVolPCM, &PanOn);
				if (CurChn < FMChnCnt)
					CurChnVolMD = ConvertVolume(CurChnVolPCM, CurChnPan, 0x00 | (PanOn << 7));
				else
					CurChnVolMD = ConvertVolume(CurChnVolPCM, CurChnPan, 0x01);
				break;
			case CFTYPE_RETURN:	// Flag F9
				SMPSNewData[DstPos + 0x00] = 0xE3;
				
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
			case CFTYPE_SIMPLE_CHANGE:
				SMPSNewData[DstPos + 0x00] = SMPSData[CurPos + 0x00];
				switch(SMPSData[CurPos])
				{
				case 0xE0:	// Pan
					CurChnPan = SMPSData[CurPos + 0x01];
					//printf("Track %u, Pos 0x%04X: Pan change %02X!\n", CurChn, CurPos, CurChnPan);
					if (NIBBLE_LOW(CurChnPan) > NIBBLE_HIGH(CurChnPan))	// VolL > VolR
						TempByt = 0x80;	// Pan Left
					else if (NIBBLE_LOW(CurChnPan) < NIBBLE_HIGH(CurChnPan))	// VolL < VolR
						TempByt = 0x40;	// Pan Right
					else	// VolL == VolR
						TempByt = 0xC0;	// Pan Center
					PanOn = (TempByt != 0xC0);
					SMPSNewData[DstPos + 0x01] = TempByt;
					/*DstPos += CmdLen;
					
					if (CurChn < FMChnCnt)
					{
						SMPSNewData[DstPos + 0x00] = 0xE6;
						TempByt = ConvertVolume(CurChnVolPCM, CurChnPan, 0x00 | (PanOn << 7));
					}
					else
					{
						SMPSNewData[DstPos + 0x00] = 0xEC;
						TempByt = ConvertVolume(CurChnVolPCM, CurChnPan, 0x01);
					}
					TempByt -= CurChnVolMD;
					SMPSNewData[DstPos + 0x01] = TempByt;
					if (TempByt)
						CurChnVolMD += TempByt;
					else
						DstPos -= CmdLen;*/
					break;
				case 0xE1:	// Frequency Displacement
					SMPSNewData[DstPos + 0x01] = (INT8)SMPSData[CurPos + 0x01] / 4;
					break;
				}
				for (TempByt = 0x02; TempByt < CmdLen; TempByt ++)
					SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				break;
			case CFTYPE_VOLUME:
				CurChnVolPCM += SMPSData[CurPos + 0x01];
				if (CurChn < FMChnCnt)
				{
					SMPSNewData[DstPos + 0x00] = 0xE6;
					TempByt = ConvertVolume(CurChnVolPCM, CurChnPan, 0x00 | (PanOn << 7));
				}
				else
				{
					SMPSNewData[DstPos + 0x00] = 0xEC;
					TempByt = ConvertVolume(CurChnVolPCM, CurChnPan, 0x01);
				}
				TempByt -= CurChnVolMD;
				SMPSNewData[DstPos + 0x01] = TempByt;
				//SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x01];
				CurChnVolMD += TempByt;
				
				//if (SMPSData[CurPos + 0x01])	// skip, if no change
				if (CurChn > 0x00)
					DstPos += CmdLen;
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				break;
			case CFTYPE_FM_INS:		// Flag EF
				if (CurChn < FMChnCnt)
					SMPSNewData[DstPos + 0x00] = 0xEF;
				else
					SMPSNewData[DstPos + 0x00] = 0xF5;
				CurIns = SMPSData[CurPos + 0x01];
				TempByt = CurIns;
				if (CurChn >= FMChnCnt)
				{
					if (CurIns == 0x06)	// Closed Hi-Hat
						TempByt = 0x02;
					else if (CurIns == 0x09)	// Open Hi-Hat
						TempByt = 0x01;
				}
				SMPSNewData[DstPos + 0x01] = TempByt;
				
				if (CurChn < FMChnCnt && MaxIns <= CurIns)
					MaxIns = CurIns + 1;
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				if (CurChn > 0x00)
					DstPos += CmdLen;
				break;
			case CFTYPE_KEY_DISPLC:
				TempByt = SMPSData[CurPos + 0x01];
				SMPSNewData[DstPos + 0x00] = 0xE9;
				SMPSNewData[DstPos + 0x01] = TempByt;
				CurChnKeyDplc += TempByt;
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				if (CurChn > 0x00)
					DstPos += CmdLen;
				break;
			}
		}
		
		if (TrackEnd)
		{
			if (TempCF->Type != CFTYPE_STOP_TRACK)
			{
				if (SMPSData[CurPos] == 0xF2)
				{
					SMPSNewData[DstPos] = 0xF2;
					SetProcMask(CurPos, 0x01);
					CurPos ++,	DstPos ++;
				}
			}
			
			CurGosub ++;
			if (CurGosub < GosubID)
			{
				CurPos = GosubPtr[CurGosub];
				CurChnVolPCM = GosubVol[CurGosub];
				PanOn = GosubPan[CurGosub];
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
	SMPSNewLen = DstPos;
	
	CurPtr = GetProcMaskNonusage();
	printf("Conversion missed 0x%X (likely unused) byte%s:\n", CurPtr, (CurPtr == 1) ? "" : "s");
	PrintProcMaskNonusage();
	
	return;
}

static void ParseSubroutine(UINT16 StartPos, UINT8* CurVol, UINT8* CurPanOn)
{
	UINT8 GosubID;
	UINT16 GosubPtr[0x10];
	UINT8 LoopStk[0x10];
	UINT16 CurPos;
	UINT16 CurPtr;
	UINT8 CurChnVolPCM;
	UINT8 PanOn;
	COORD_FLAG* TempCF;
	UINT8 CmdLen;
	bool TrackEnd;
	UINT8 TempByt;
	
	CurPos = StartPos;
	CurChnVolPCM = *CurVol;
	PanOn = *CurPanOn;
	TrackEnd = false;
	memset(LoopStk, 0x00, 0x10);
	GosubID = 0x00;
	while(! TrackEnd && CurPos < SMPSLen)
	{
		if (SMPSData[CurPos] < 0xE0)
		{
			CurPos ++;
		}
		else
		{
			TempCF = &CFMain[SMPSData[CurPos] & 0x1F];
			CmdLen = TempCF->Len & 0x7F;
			switch(TempCF->Type)
			{
			case CFTYPE_LOOP:	// Flag F7
				CurPtr = CurPos + TempCF->JmpOfs;
				CurPtr = Get16Ptr(&SMPSData[CurPtr], CurPtr);
				
				TempByt = SMPSData[CurPos + 0x01];
				LoopStk[TempByt] ++;
				if (LoopStk[TempByt] < SMPSData[CurPos + 0x02])
				{
					CurPos = CurPtr;
				}
				else
				{
					LoopStk[TempByt] = 0x00;
					CurPos += CmdLen;
				}
				break;
			case CFTYPE_STOP_TRACK:	// Flag F2
				TrackEnd = true;
				break;
			case CFTYPE_GOTO:	// Flag F6
				CurPtr = CurPos + TempCF->JmpOfs;
				CurPos = Get16Ptr(&SMPSData[CurPtr], CurPtr);
				break;
			case CFTYPE_GOSUB:	// Flag F8
				CurPtr = CurPos + TempCF->JmpOfs;
				CurPtr = Get16Ptr(&SMPSData[CurPtr], CurPtr);
				if (GosubID < 0x10)
				{
					// Jump
					GosubPtr[GosubID] = CurPos + CmdLen;
					GosubID ++;
					CurPos = CurPtr;
				}
				else
				{
					CurPos += CmdLen;
				}
				break;
			case CFTYPE_RETURN:	// Flag F9
				if (GosubID)
				{
					GosubID --;
					CurPos = GosubPtr[GosubID];
				}
				else
				{
					TrackEnd = true;
				}
				break;
			case CFTYPE_VOLUME:
				CurChnVolPCM += SMPSData[CurPos + 0x01];
				CurPos += CmdLen;
				break;
			case CFTYPE_SIMPLE_CHANGE:
				switch(SMPSData[CurPos])
				{
				case 0xE0:	// Pan
					TempByt = SMPSData[CurPos + 0x01];
					if (NIBBLE_HIGH(TempByt) != NIBBLE_LOW(TempByt))	// VolL != VolR
						PanOn = 0x01;
					else
						PanOn = 0x00;
					break;
				}
				CurPos += CmdLen;
				break;
			default:
				CurPos += CmdLen;
				break;
			}
		}
	}
	*CurVol = CurChnVolPCM;
	*CurPanOn = PanOn;
	
	return;
}

static void ParseLoop(UINT16 StartPos, UINT8* CurVol, UINT8* CurPanOn)
{
	UINT8 GosubID;
	UINT16 GosubPtr[0x10];
	UINT8 LoopStk[0x10];
	UINT16 CurPos;
	UINT16 CurPtr;
	UINT8 CurChnVolPCM;
	UINT8 PanOn;
	COORD_FLAG* TempCF;
	UINT8 CmdLen;
	bool TrackEnd;
	UINT8 TempByt;
	UINT8 MasterLoopIdx;
	
	CurPos = StartPos;
	CurChnVolPCM = *CurVol;
	PanOn = *CurPanOn;
	TrackEnd = false;
	memset(LoopStk, 0x00, 0x10);
	GosubID = 0x00;
	MasterLoopIdx = SMPSData[CurPos + 0x01];
	
	while(! TrackEnd && CurPos < SMPSLen)
	{
		if (SMPSData[CurPos] < 0xE0)
		{
			CurPos ++;
		}
		else
		{
			TempCF = &CFMain[SMPSData[CurPos] & 0x1F];
			CmdLen = TempCF->Len & 0x7F;
			switch(TempCF->Type)
			{
			case CFTYPE_LOOP:	// Flag F7
				CurPtr = CurPos + TempCF->JmpOfs;
				CurPtr = Get16Ptr(&SMPSData[CurPtr], CurPtr);
				
				TempByt = SMPSData[CurPos + 0x01];
				LoopStk[TempByt] ++;
				if (LoopStk[TempByt] < SMPSData[CurPos + 0x02])
				{
					CurPos = CurPtr;
				}
				else
				{
					LoopStk[TempByt] = 0x00;
					CurPos += CmdLen;
					if (TempByt == MasterLoopIdx)
						TrackEnd = true;
				}
				break;
			case CFTYPE_STOP_TRACK:	// Flag F2
				TrackEnd = true;
				break;
			case CFTYPE_GOTO:	// Flag F6
				CurPtr = CurPos + TempCF->JmpOfs;
				CurPos = Get16Ptr(&SMPSData[CurPtr], CurPtr);
				break;
			case CFTYPE_GOSUB:	// Flag F8
				CurPtr = CurPos + TempCF->JmpOfs;
				CurPtr = Get16Ptr(&SMPSData[CurPtr], CurPtr);
				if (GosubID < 0x10)
				{
					// Jump
					GosubPtr[GosubID] = CurPos + CmdLen;
					GosubID ++;
					CurPos = CurPtr;
				}
				else
				{
					CurPos += CmdLen;
				}
				break;
			case CFTYPE_RETURN:	// Flag F9
				if (GosubID)
				{
					GosubID --;
					CurPos = GosubPtr[GosubID];
				}
				else
				{
					TrackEnd = true;
				}
				break;
			case CFTYPE_VOLUME:
				CurChnVolPCM += SMPSData[CurPos + 0x01];
				CurPos += CmdLen;
				break;
			case CFTYPE_SIMPLE_CHANGE:
				switch(SMPSData[CurPos])
				{
				case 0xE0:	// Pan
					TempByt = SMPSData[CurPos + 0x01];
					if (NIBBLE_HIGH(TempByt) != NIBBLE_LOW(TempByt))	// VolL != VolR
						PanOn = 0x01;
					else
						PanOn = 0x00;
					break;
				}
				CurPos += CmdLen;
				break;
			default:
				CurPos += CmdLen;
				break;
			}
		}
	}
	*CurVol = CurChnVolPCM;
	*CurPanOn = PanOn;
	
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
			if (CurOfs->CoordFlg < 0xE0)
				PtrVal = CurLst->DstPtr;
			else
				PtrVal = CurLst->DstPtr - (CurOfs->Ofs + 0x01);
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
