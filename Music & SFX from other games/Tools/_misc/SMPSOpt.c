// SMPS Optimizer (largely based on SMPS Converter)
// --------------
// Programmed by Valley Bell, 2012-2013

// TODO: ProcessSubRoutine for OptimizeSMPS_Loops to properly set LastNote/LastDelay

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


int main(int argc, char* argv[]);
static bool SetConvMode(const char* ModeStr);

UINT8 LoadSMPSFile(const char* FileName);

static INLINE UINT16 Get16Ptr(UINT8* Data, UINT16 PtrPos);
static INLINE void Put16Ptr(UINT8* Data, UINT16 Ptr);

static void AddPtrToList(UINT16 SrcPos, UINT16 SrcPtr, UINT8 CoordFlag);
static void AddNewPtrOfsToList(UINT16 SrcPtr, UINT16 DstOfs, UINT8 CoordFlag);
static bool AddNewPosToList(UINT16 SrcPos, UINT16 DstPos);
static void AddNewPtrOfsToList_FromOfs(UINT16 SrcOfs, UINT16 DstOfs, UINT8 CoordFlag);

void ReadSMPSHeader(void);

static void MakeSortedChannelList(void);
static bool GetProcMask(UINT16 Pos);
static void SetProcMask(UINT16 Pos, UINT16 Len);
UINT16 GetProcMaskNonusage(void);
void PrintProcMaskNonusage(void);

void PreparseSMPS(void);

static UINT16 GetMinDataPtr(UINT16 MinOfs);
static void WarningMsgInvalid(UINT8 CurChn, UINT16 CurPos);

void OptimizeSMPS_Cmds(void);
void OptimizeSMPS_Notes(void);
void OptimizeSMPS_Loops(void);
UINT8 CheckLoopValidity(UINT8 LoopID, UINT16 LoopStart, UINT16 LoopEnd);
UINT16 CompareBlocks(UINT16 SrcPos, UINT16 CpyPos, UINT8 LastNoteC, UINT8 LastDelayC);
bool CheckBlock(UINT16 SrcPos, UINT16 CpyPos, UINT8 LastNoteC, UINT8 LastDelayC);
UINT16 GetLoopLength(UINT16 SrcPos, UINT16 CpyPos, UINT8 LastNoteC, UINT8 LastDelayC, UINT16* RetLoopEnd);
void WritePointers(void);
void FreePointers(void);
void PrepareNextPass(void);


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


#define CPTR_68K	0x00
#define CPTR_Z80	0x01
#define CPTR_RST	0x02

#define CFMODE_S1	0x00
#define CFMODE_S2	0x00
#define CFMODE_S3K	0x01
#define CFMODE_TRS	0x02

#define CTEMPO_S1	0x00
#define CTEMPO_S2	0x01
#define CTEMPO_S3K	0x02

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

#define GOSUB_LIMIT		0x20


UINT8 PtrMode;
UINT8 CoordMode;
UINT8 CoordMode2;
UINT8 SkipChecks;

UINT32 SMPSLen;
UINT8* SMPSData;
UINT32 SMPSNewLen;
UINT8* SMPSNewData;
UINT32 ProcMskSize;
UINT8* ProcMask;	// Mask of processed Data
UINT8* CmdMask;
UINT8* NewCmdMask;
UINT16* PtrCnvTable;

PTR_LIST* PtrList;
PTR_LIST* PtrLEnd;
DATAPTR_LIST* SrcPosPtrList;
DATAPTR_LIST* SrcPosPtrLEnd;
UINT16 SMPSOffset;
UINT16 SMPSNewOffset;

UINT8 ChnCnt;
UINT8 FMChnCnt;
UINT8 PSGChnCnt;
CHN_HEAD* ChnList;
UINT8* ChnListSort;

COORD_FLAG CFMain[0x1F];
COORD_FLAG CFExt[0x11];

int main(int argc, char* argv[])
{
	int argbase;
	FILE* hFile;
	UINT8 RetVal;
	PTR_LIST* CurLst;
	OFS_LIST* CurOfs;
	int InKey;
	UINT16 SMPSOfsBak;
	UINT16 OldSMPSLen;
	UINT8 PassMask;
	UINT8 PassID;
	UINT8 CurPass;
	
	printf("SMPS Optimizer\n--------------\n");
	if (argc < 4)
	{
		printf("Usage: SMPSOpt.exe [-p#] [-nocheck] Fmt smps_in.bin smps_out.bin\n");
		printf("    -p# - do only pass number # (useful if there are bugs, examples: -p1, -p23)\n");
		printf("    -nocheck - skips some validation checks (for use with custom formats)\n");
		printf("Format Strings (case insensitive):\n");
		printf("    S1  - Sonic 1 (68k)\n");
		printf("    S3K - Sonic 3 & Knuckles (Z80)\n");
		printf("    Trs - SMPS Treasure and SMPS other 68k games\n");
		printf("    Rst - Ristar (68k)\n");
		return 0;
	}
	
	argbase = 1;
	PassMask = 0xFF;
	SkipChecks = 0x00;
	while(argbase < argc)
	{
		if (! strncmp(argv[argbase], "-p", 2))
		{
			CurPass = 0x02;
			PassMask = 0x00;
			while(argv[argbase][CurPass] != '\0')
			{
				PassMask |= 1 << (argv[argbase][CurPass] - '1');
				CurPass ++;
			}
			argbase ++;
		}
		else if (! _stricmp(argv[argbase], "-nocheck"))
		{
			SkipChecks ++;
			argbase ++;
		}
		else
		{
			break;
		}
	}
	
	if (argc < argbase + 3)
	{
		printf("Not enough arguments!\n");
		return 0;
	}
	
	if (! SetConvMode(argv[argbase + 0]))
	{
		printf("Invalid Format String!\n");
		return 3;
	}
	
	RetVal = LoadSMPSFile(argv[argbase + 1]);
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
	OldSMPSLen = SMPSLen;
	
	// SMPSOffset gets set by ReadSMPSHeader
	if (PtrMode == CPTR_Z80)
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
		while(InKey != '\n')
			InKey = getchar();
	}
	SMPSNewOffset = SMPSOffset;
	printf("\n");
	
	printf("FM/DAC Tracks: %u, PSG Tracks: %u\n", FMChnCnt, PSGChnCnt);
	PreparseSMPS();
	printf("\n");
	if (PSGChnCnt == 0xFF)
		goto ErrExit;
	
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
	
	CurPass = 0x00;
	for (PassID = 0x00; PassID < 0x03; PassID ++)
	{
		if (! (PassMask & (1 << PassID)))
			continue;
		
		if (CurPass)
			PrepareNextPass();
		
		if (PassID == 0x00)
			OptimizeSMPS_Cmds();
		else if (PassID == 0x01)
			OptimizeSMPS_Notes();
		else if (PassID == 0x02)
			OptimizeSMPS_Loops();
		WritePointers();
		printf("Pass #%u: %u bytes -> %u bytes (Ratio: %.2f %%)\n", 1 + PassID, SMPSLen, SMPSNewLen,
				100.0 * SMPSNewLen / SMPSLen);
		CurPass ++;
	}
	
	printf("Total: %u bytes -> %u bytes (Ratio: %.2f %%, %u pass%s)\n", OldSMPSLen, SMPSNewLen,
			100.0 * SMPSNewLen / OldSMPSLen, CurPass, (CurPass == 1) ? "" : "es");
	
	if (SMPSNewLen < OldSMPSLen)
	{
		hFile = fopen(argv[argbase + 2], "wb");
		if (hFile == NULL)
		{
			printf("Error opening file!\n");
			return 1;
		}
		fwrite(SMPSNewData, SMPSNewLen, 0x01, hFile);
		
		fclose(hFile);
	}
	
ErrExit:
	FreePointers();
	free(CmdMask);
	free(NewCmdMask);
	free(ProcMask);
	free(SMPSData);
	free(SMPSNewData);
	
#ifdef _DEBUG
	getchar();
#endif
	
	return 0;
}

static bool SetConvMode(const char* ModeStr)
{
	CoordMode2 = 0x00;
	if (! _stricmp(ModeStr, "S1"))
	{
		PtrMode = CPTR_68K;
		CoordMode = CFMODE_S1;
	}
	else if (! _stricmp(ModeStr, "S2R"))
	{
		PtrMode = CPTR_68K;
		CoordMode = CFMODE_S1;
		CoordMode2 = 0x01;
	}
	else if (! _stricmp(ModeStr, "S3K"))
	{
		PtrMode = CPTR_Z80;
		CoordMode = CFMODE_S3K;
	}
	else if (! _stricmp(ModeStr, "Trs"))
	{
		PtrMode = CPTR_68K;
		CoordMode = CFMODE_TRS;
	}
	else if (! _stricmp(ModeStr, "Rst"))
	{
		PtrMode = CPTR_RST;
		CoordMode = CFMODE_TRS;
	}
	else
	{
		return false;
	}
	
	return true;
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
	CmdMask =  (UINT8*)malloc(SMPSLen);
	NewCmdMask = NULL;
	
	return 0x00;
}

static INLINE UINT16 Get16Ptr(UINT8* Data, UINT16 PtrPos)
{
	UINT16 NewOfs;
	
	switch(PtrMode)
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
	switch(PtrMode)
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

static bool AddNewPosToList(UINT16 SrcPos, UINT16 DstPos)
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
			return true;
		}
		
		CurLst = CurLst->next;
	}
	
	return false;
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
	
	if (PtrMode == CPTR_Z80)
	{
		// Try to guess the Z80 offset (should work with most files)
		// Note: CurPtr is already set to a valid value - the instrument table
		if (! (CurPtr & 0x8000))
		{
			printf("This song seems to use the global Sonic 3 Instrument Bank.\n");
			CurPtr = 0xFFFF;	// set to the maximum pointer value
		}
		
		CurPtr = 0xFFFF;	// afterthought: it's quite unlikely to have the instrument
							// table between header and actual smps data
							// but it's possible
		if (ChnList[ChnListSort[0x00]].Ptr < CurPtr)
			CurPtr = ChnList[ChnListSort[0x00]].Ptr;
		SMPSOffset = CurPtr - CurPos;
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
		if (CurFlag >= 0xFA && CFMode == CFMODE_S1 && ! CoordMode2)
		{
			TempFlag->Type = CFTYPE_INVALID;
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
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_UNUSED;
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
			case CFMODE_TRS:	// unknown
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
			case CFMODE_S3K:	// Spindash Rev.
				//TempFlag->Len = 0x01;
				TempFlag->Len = 0x03;	// most games have Set LFO here
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case CFMODE_TRS:	// Set LFO parameters
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			}
			break;
		case 0xEA:
			switch(CFMode)
			{
			case CFMODE_S1:		// Set Tempo Modifier
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
			case CFMODE_TRS:	// unknown
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
				if (! CoordMode2)
				{
					TempFlag->Len = 0x01;
					TempFlag->Type = CFTYPE_NO_CHANGE;
				}
				else
				{
					// S2R - Conditional Jump
					TempFlag->Len = 0x04;
					TempFlag->Type = CFTYPE_LP_JMP;
					TempFlag->JmpOfs = 0x02;
				}
				break;
			case CFMODE_S3K:	// Set Key Displacement (to Param. - 0x40)
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_KEY_DISPLC;
				break;
			case CFMODE_TRS:
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			}
			break;
		case 0xEE:
			switch(CFMode)
			{
			case CFMODE_S1:	// SFX-related
				if (! CoordMode2)
				{
					TempFlag->Len = 0x01;
					TempFlag->Type = CFTYPE_STOP_TRACK;
				}
				else
				{
					// S2R - Send YM2612 command
					TempFlag->Len = 0x03;
					TempFlag->Type = CFTYPE_UNUSED;
				}
				break;
			case CFMODE_S3K:	// Send YM2612 command
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case CFMODE_TRS:	// unknown, DAC related
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_UNUSED;
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
			case CFMODE_S1:		// S2R - Set DAC Play Mode
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_NO_CHANGE;
				break;
			case CFMODE_S3K:	// Disable Modulation
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_MODULATION;
				break;
			case CFMODE_TRS:	// unknown, DAC related
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			}
			break;
		case 0xFB:	// Change Key Displacement
			switch(CFMode)
			{
			case CFMODE_S1:		// S2R - Set LFO Data
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_NO_CHANGE;
				break;
			default:
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_KEY_DISPLC;
				break;
			}
			break;
		case 0xFC:
			switch(CFMode)
			{
			case CFMODE_S1:		// S2R - Set Note Fill Mode
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_NO_CHANGE;
				break;
			case CFMODE_S3K:	// for Continuous SFX
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case CFMODE_TRS:	// set DAC volume
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			}
			break;
		case 0xFD:
			switch(CFMode)
			{
			case CFMODE_S1:		// S2R - Set SSG-EG
				TempFlag->Len = 0x05;
				TempFlag->Type = CFTYPE_NO_CHANGE;
				break;
			case CFMODE_S3K:	// Enable alternate SMPS mode
				TempFlag->Len = 0x02;
				TempFlag->Type = CFTYPE_SPECIAL;
				break;
			case CFMODE_TRS:	// Disable Modulation
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_MODULATION;
				break;
			}
			break;
		case 0xFE:
			switch(CFMode)
			{
			case CFMODE_S1:		// S2R - invalid
				TempFlag->Len = 0x01;
				TempFlag->Type = CFTYPE_INVALID;
				break;
			case CFMODE_S3K:	// Enbale FM3 Special Mode
				TempFlag->Len = 0x05;
				TempFlag->Type = CFTYPE_UNUSED;
				break;
			case CFMODE_TRS:	//
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
		if (CFMode == CFMODE_S1)
		{
			TempFlag->Len = 0x01;
			TempFlag->Type = CFTYPE_INVALID;
			continue;
		}
		
		switch(CurFlag)
		{
		case 0x00:	// Pan
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
			case CFMODE_TRS:	// unknown
				TempFlag->Len = 0x03;
				TempFlag->Type = CFTYPE_UNUSED;
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
	UINT16 GosubPtr[GOSUB_LIMIT];
	UINT16 InsPtr;
	UINT8 CoordFlg;
	COORD_FLAG* CurFlg;
	UINT16 TempPtr;
	
	memset(ProcMask, 0x00, ProcMskSize);
	memset(CmdMask, 0x00, SMPSLen);
	FillCFStructs(CFMain, CFExt, CoordMode);
	
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
	memset(CmdMask, 0xFF, CurPos);
	
	for (CurChn = 0x00; CurChn < ChnCnt; CurChn ++)
	{
		// Parse Channel Data
		CurPos = ChnList[ChnListSort[CurChn]].Ptr;
		TrackEnd = false;
		GosubID = 0x00;
		
		while(! TrackEnd && CurPos < SMPSLen)
		{
			CmdMask[CurPos] |= 0x01;
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
					CmdMask[CurPos] = 0xFF;
					TrackEnd = true;
					SetProcMask(CurPos, CurFlg->Len);
					CurPos += CurFlg->Len;
					break;
				// Jumps with Pointer
				case CFTYPE_LOOP:
				case CFTYPE_LP_JMP:
					CmdMask[CurPos] |= 0x02;
					if (SMPSData[CurPos + 0x01] >= 0x10)
					{
						printf("Error in Track %u: Invalid Loop ID %u at 0x%04X\n", CurChn,
								SMPSData[CurPos + 0x01], CurPos);
						PSGChnCnt = 0xFF;
						return;
					}
					// fall through
				case CFTYPE_GOTO:
					if (CurFlg->Type != CFTYPE_LOOP)
						CmdMask[CurPos] |= 0x08;
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
					CmdMask[CurPos] |= 0x08;
					TempPtr = CurPos + CurFlg->JmpOfs;
					CurPtr = Get16Ptr(&SMPSData[TempPtr], TempPtr);
					AddPtrToList(TempPtr, CurPtr, CoordFlg);
					SetProcMask(CurPos, CurFlg->Len);
					CurPos += CurFlg->Len;
					
					if (! GetProcMask(CurPtr))
					{
						if (GosubID < GOSUB_LIMIT)
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
					CmdMask[CurPos] |= 0x08;
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
						if (CoordMode == CFMODE_TRS && CoordFlg == 0xE4)
						{
							if (SMPSData[CurPos + 0x01])
								CurPtr += 0x04;
						}
						else if (CoordMode == CFMODE_S3K && CoordFlg == 0xEF)
						{
							if (SMPSData[CurPos + 0x01] & 0x80)
								CurPtr += 0x01;
						}
					}
					SetProcMask(CurPos, CurPtr);
					CurPos += CurPtr;
					break;
				}
			}
		}
		if (! TrackEnd)
		{
			printf("Error in Track %u: Trying to read beyond EOF!\n", CurChn);
			PSGChnCnt = 0xFF;
			return;
		}
	}
	
	return;
}

static UINT16 GetMinDataPtr(UINT16 MinOfs)
{
	UINT16 ResPtr;
	PTR_LIST* CurLst;
	
	if (ChnList[ChnListSort[0x00]].Ptr >= MinOfs)
		ResPtr = ChnList[ChnListSort[0x00]].Ptr;
	else
		ResPtr = 0xFFFF;
	CurLst = PtrList;
	while(CurLst != NULL)
	{
		if (CurLst->SrcPtr >= MinOfs && CurLst->SrcPtr < ResPtr)
			ResPtr = CurLst->SrcPtr;
		
		CurLst = CurLst->next;
	}
	
	return ResPtr;
}

static void WarningMsgInvalid(UINT8 CurChn, UINT16 CurPos)
{
	if (SMPSData[CurPos] < 0xFF)
	{
		printf("Track %u, Pos 0x%04X: Invalid Command %02X found!",
				CurChn, CurPos, SMPSData[CurPos + 0x00]);
	}
	else
	{
		printf("Track %u, Pos 0x%04X: Invalid Command %02X %02X found!",
				CurChn, CurPos, SMPSData[CurPos + 0x00], SMPSData[CurPos + 0x01]);
	}
	
	return;
}

void OptimizeSMPS_Cmds(void)
{
	UINT8 CurChn;
	UINT8 ChnID;
	UINT16 CurPos;
	UINT16 DstPos;
	//UINT8 TempoDiv;
	UINT16 CurPtr;
	bool TrackEnd;
	UINT8 CurGosub;
	UINT8 GosubID;
	UINT16 GosubPtr[GOSUB_LIMIT];
	UINT16 InsPtr;
	UINT8 MaxIns;
	bool TrackBreak;
	UINT8 LastNote;
	UINT8 LastNoteCmd;
	UINT8 LastDelay;
	UINT8 NoteDlyMask;
	UINT8 NoteDlyMaskDst;
	UINT8 TempByt;
	//UINT16 TempSht;
	bool TempFlag;
	UINT16 LoopExtra[0x10];
	UINT16 LastVolPos;
	//UINT8 CurChnVol;
	//UINT8 CurChnKeyDplc;
	COORD_FLAG* TempCF;
	UINT8 CmdLen;
	
	memset(ProcMask, 0x00, ProcMskSize);
	SMPSNewLen = SMPSLen * 2;
	SMPSNewData = (UINT8*)malloc(SMPSNewLen);
	memset(SMPSNewData, 0x00, SMPSNewLen);
	NewCmdMask = (UINT8*)malloc(SMPSNewLen);
	memset(NewCmdMask, 0x00, SMPSNewLen);
	
	CurPos = 0x00;
	DstPos = 0x00;
	InsPtr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
	MaxIns = 0x00;
	
	// 0x00 and 0x01 are set later
	AddNewPtrOfsToList_FromOfs(CurPos, DstPos, 0x7F);
	SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];
	SMPSNewData[DstPos + 0x03] = SMPSData[CurPos + 0x03];
	SMPSNewData[DstPos + 0x04] = SMPSData[CurPos + 0x04];
	SMPSNewData[DstPos + 0x05] = SMPSData[CurPos + 0x05];
	//TempoDiv = SMPSData[CurPos + 0x04];
	
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
		SMPSNewData[DstPos + 0x03] = SMPSData[CurPos + 0x03];
		SMPSNewData[DstPos + 0x04] = SMPSData[CurPos + 0x04];
		SMPSNewData[DstPos + 0x05] = SMPSData[CurPos + 0x05];
		
		SetProcMask(CurPos, 0x06);
		CurPos += 0x06;
		DstPos += 0x06;
	}
	
	// copy additional header data
	CurPtr = GetMinDataPtr(0x0000);
	if (CurPos < CurPtr)
	{
		SetProcMask(CurPos, CurPtr - CurPos);
		while(CurPos < CurPtr)
		{
			SMPSNewData[DstPos] = SMPSData[CurPos];
			CurPos ++;	DstPos ++;
		}
	}
	memset(NewCmdMask, 0xFF, DstPos);
	
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
		LastNote = 0x00;
		LastNoteCmd = 0x00;
		LastDelay = 0x00;
		NoteDlyMask = 0x00;
		NoteDlyMaskDst = 0x00;
		memset(LoopExtra, 0x00, 0x10 * 0x02);
		LastVolPos = 0x0000;
		//CurChnVol = ChnList[CurChn].Volume;
		//CurChnKeyDplc = ChnList[CurChn].KeyDisplc;
		if (GetProcMask(CurPos))
			TrackEnd = true;
		
		while(! TrackEnd && ! TrackBreak && CurPos < SMPSLen)
		{
		
		TempFlag = AddNewPosToList(CurPos, DstPos);
		if (TempFlag)
		{
			LastNote = LastDelay = 0x00;
			LastVolPos = 0x0000;
		}
		NewCmdMask[DstPos] |= (TempFlag << 4);
		if (SMPSData[CurPos] < 0xE0)
		{
			// S1:  81 04 80 02 03 <-> 81 04 80 02 80 02
			// S3K: 81 04 80 02 03 <-> 81 04 80 02 81 02
			CmdLen = 0x01;
			if (SMPSData[CurPos] >= 0x80)
			{
				LastNoteCmd = SMPSData[CurPos];
				SMPSNewData[DstPos] = LastNoteCmd;
				NewCmdMask[DstPos] |= 0x01;
				
				TempByt = SMPSData[CurPos + 0x01];
				if (TempByt < 0x80 && ! NoteDlyMask && ! TempFlag)
				{
					NoteDlyMask = 0x01;
					if (LastNoteCmd == LastNote && ! NoteDlyMaskDst)
					{
						// Skip Note, Write Delay
						LastDelay = TempByt;
						SMPSNewData[DstPos] = TempByt;
						NoteDlyMask >>= 1;
						CmdLen ++;
					}
						// Prevent it from optimizing 04 82 04 02 into 04 82 02
					else if (TempByt == LastDelay && (SMPSData[CurPos + 0x02] & 0x80))
					{
						// Write Note, skip delay
						NoteDlyMaskDst = 0x01;
						NoteDlyMask >>= 1;
						CmdLen ++;
					}
				}
				else
				{
					NoteDlyMask = 0x01;
					NoteDlyMaskDst = 0x01;
				}
				
				if (! (LastNoteCmd == 0x80 && CoordMode == CFMODE_S3K))
					LastNote = LastNoteCmd;
				
				DstPos ++;
			}
			else
			{
				LastDelay = SMPSData[CurPos];
				
				NoteDlyMask >>= 1;
				NoteDlyMaskDst >>= 1;
				SMPSNewData[DstPos] = LastDelay;
				NewCmdMask[DstPos] |= 0x01;
				DstPos ++;
			}
			
			SetProcMask(CurPos, CmdLen);
			CurPos += CmdLen;
			LastVolPos = 0x0000;
		}
		else
		{
			NewCmdMask[DstPos] |= 0x01;
			
			NoteDlyMask >>= 1;
			NoteDlyMaskDst >>= 1;
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
				if (CoordMode == CFMODE_TRS && SMPSData[CurPos] == 0xE4)
				{
					if (SMPSData[CurPos + 0x01])
						CmdLen += 0x04;
				}
				else if (CoordMode == CFMODE_S3K && SMPSData[CurPos] == 0xEF)
				{
					if (SMPSData[CurPos + 0x01] & 0x80)
						CmdLen += 0x01;
				}
			}
			
			if (TempCF->Type != CFTYPE_STOP_TRACK && ! TempCF->JmpOfs &&
				TempCF->Type != CFTYPE_RETURN && TempCF->Type != CFTYPE_FM_INS && TempCF->Type != CFTYPE_PSG_INS &&
				TempCF->Type != CFTYPE_VOLUME &&
				TempCF->Type != CFTYPE_KEY_DISPLC)
				TempByt = CFTYPE_NO_CHANGE;
			else
				TempByt = TempCF->Type;
			switch(TempByt)
			{
			case CFTYPE_STOP_TRACK:	// Flag F2 (all) / E3 (S3K only)
				SMPSNewData[DstPos] = SMPSData[CurPos];
				NewCmdMask[DstPos] = 0xFF;
				
				TrackEnd = true;
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += 0x01;
				break;
			case CFTYPE_LOOP:	// Flag F7
				NewCmdMask[DstPos] |= 0x02;
				SMPSNewData[DstPos + 0x00] = 0xF7;
				SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x01];	// Loop Index
				SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];	// Loop Count
				TempByt = SMPSData[CurPos + 0x01];
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + TempCF->JmpOfs], CurPos + TempCF->JmpOfs);
				AddNewPtrOfsToList(CurPtr, DstPos + TempCF->JmpOfs, 0xF7);
				
				SetProcMask(CurPos, CmdLen);
				if (! LoopExtra[TempByt])
					CurPos += 0x05;
				else
					CurPos = LoopExtra[TempByt];
				LoopExtra[TempByt] = 0x0000;
				LastVolPos = 0x0000;
				DstPos += CmdLen;
				break;
			case CFTYPE_GOTO:	// Flag F6
				NewCmdMask[DstPos] |= 0x08;
				SMPSNewData[DstPos + 0x00] = 0xF6;
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + TempCF->JmpOfs], CurPos + TempCF->JmpOfs);
				AddNewPtrOfsToList(CurPtr, DstPos + TempCF->JmpOfs, 0xF6);
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				
				// if we jump to an offset that's already processed,
				// then it's definately a loop
				if (! GetProcMask(CurPtr))
				{
					if (GosubID < GOSUB_LIMIT)
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
				NewCmdMask[DstPos] |= 0x08;
				SMPSNewData[DstPos + 0x00] = 0xF8;
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + TempCF->JmpOfs], CurPos + TempCF->JmpOfs);
				AddNewPtrOfsToList(CurPtr, DstPos + TempCF->JmpOfs, 0xF8);
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
					if (TempByt >= GosubID)
					{
						if (GosubID < GOSUB_LIMIT)
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
				LastNote = LastDelay = 0x00;
				NoteDlyMask = 0x00;
				LastVolPos = 0x0000;
				break;
			case CFTYPE_RETURN:	// Flag E3 (S1/2), Flag F9 (S3K/Trs)
				NewCmdMask[DstPos] |= 0x08;
				SMPSNewData[DstPos] = SMPSData[CurPos];
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				TrackEnd = true;
				break;
			case CFTYPE_LP_JMP:	// Flag EB (S3K only)
				// TODO: Confirm that this works correctly
				NewCmdMask[DstPos] |= 0x08;
				SMPSNewData[DstPos] = SMPSData[CurPos];
				
				TempByt = SMPSData[CurPos + 0x01];
				SMPSNewData[DstPos + 0x01] = TempByt;
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + TempCF->JmpOfs], CurPos + TempCF->JmpOfs);
				AddNewPtrOfsToList(CurPtr, DstPos + TempCF->JmpOfs, 0xEB);
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				
				if (CoordMode2 && TempByt >= 0x0C)
				{
					// S2R Mode
					if (! GetProcMask(CurPtr))
					{
						for (TempByt = 0x00; TempByt < GosubID; TempByt ++)
						{
							if (GosubPtr[TempByt] == CurPtr)
								break;
						}
						if (TempByt >= GosubID)
						{
							if (GosubID < GOSUB_LIMIT)
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
				}
				
				if (! LoopExtra[TempByt])
					LoopExtra[TempByt] = CurPtr;
				break;
			case CFTYPE_VOLUME:
				TempFlag = false;
				TempByt = SMPSData[CurPos + 0x00];
				if (TempByt == 0xE6 || TempByt == 0xEC)
				{
					if (SMPSData[CurPos + 0x01] == 0x00)
					{
						TempFlag = true;
					}
					else if (LastVolPos)
					{
						TempFlag = true;
						SMPSNewData[LastVolPos + 0x01] += SMPSData[CurPos + 0x01];
					}
					else
					{
						LastVolPos = DstPos;
					}
				}
				else
				{
					LastVolPos = 0x0000;
				}
				
				if (! TempFlag)
				{
					for (TempByt = 0x00; TempByt < CmdLen; TempByt ++)
						SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
					DstPos += CmdLen;
				}
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				break;
			case CFTYPE_KEY_DISPLC:
				if (LastNote > 0x80)
				{
					if (SMPSData[CurPos] != 0xED)
					{
						LastNote += SMPSData[CurPos + 0x01];
						if (LastNote < 0x81)
							NoteDlyMaskDst >>= 1;
					}
					else
					{
						// Set Key Displacement to (Val - 0x40)
						NoteDlyMaskDst >>= 1;
					}
				}
				
				for (TempByt = 0x00; TempByt < CmdLen; TempByt ++)
					SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				break;
			case CFTYPE_FM_INS:
			case CFTYPE_PSG_INS:
				for (TempByt = 0x00; TempByt < CmdLen; TempByt ++)
					SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				
				if (CurChn == 0)
				{
					break;
				}
				else if (CurChn < FMChnCnt)
				{
					if (TempCF->Type == CFTYPE_PSG_INS)
						break;
				}
				else
				{
					// command EF is valid in S3K
					//if (TempCF->Type == CFTYPE_FM_INS)
					//	break;
				}
				DstPos += CmdLen;
				break;
			default:
				for (TempByt = 0x00; TempByt < CmdLen; TempByt ++)
					SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				break;
			}
		}
		
		if (TrackEnd)
		{
			CurGosub ++;
			if (CurGosub < GosubID)
			{
				CurPos = GosubPtr[CurGosub];
				LastNote = LastDelay = 0x00;
				NoteDlyMask = 0x00;
				LastVolPos = 0x0000;
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
	if (PtrMode == CPTR_Z80)
		CurPtr = SMPSOffset ^ (SMPSOffset + InsPtr);
	else
		CurPtr = 0x0000;
	if (InsPtr >= SMPSLen)
	{
		printf("Warning: Instrument Table Offset after End of File! Ignored.\n");
		//printf("The song uses 0x%02X instruments.\n", MaxIns);
	}
	else if (! (CurPtr & 0x8000))	// catch invalid Z80 InsPtrs (like Sonic 3 Global Instrument Bank)
	{
		/*CurPtr = InsPtr + 0x19 * MaxIns;
		if (CurPtr > SMPSLen)
		{
			printf("Warning: Instrument Table may be incomplete!\n"
					"(size is 0x%X bytes, but should have 0x%X * 0x%X = 0x%X bytes)\n",
					SMPSLen - InsPtr, MaxIns, 0x19, 0x19 * MaxIns);
			MaxIns = (SMPSLen - InsPtr) / 0x19;
		}*/
		CurPtr = GetMinDataPtr(InsPtr + 1);
		if (CurPtr == 0xFFFF)
			CurPtr = SMPSLen;
		MaxIns = (CurPtr - InsPtr) / 0x19;
		SetProcMask(InsPtr, 0x19 * MaxIns);
		
		memcpy(&SMPSNewData[DstPos], &SMPSData[InsPtr], 0x19 * MaxIns);
		DstPos += 0x19 * MaxIns;
	}
	/*else
	{
		printf("The song uses 0x%02X instruments.\n", MaxIns);
	}*/
	SMPSNewLen = DstPos;
	
	CurPtr = GetProcMaskNonusage();
	printf("Optimization missed 0x%X (likely unused) byte%s:\n", CurPtr, (CurPtr == 1) ? "" : "s");
	PrintProcMaskNonusage();
	if (! CurPtr)
		printf("-\n");
	printf("\n");
	
	return;
}

void OptimizeSMPS_Notes(void)
{
	UINT8 CurChn;
	UINT8 ChnID;
	UINT16 CurPos;
	UINT16 DstPos;
	//UINT8 TempoDiv;
	UINT16 CurPtr;
	bool TrackEnd;
	UINT8 CurGosub;
	UINT8 GosubID;
	UINT16 GosubPtr[GOSUB_LIMIT];
	UINT16 InsPtr;
	UINT8 MaxIns;
	bool TrackBreak;
	UINT8 LastNote;
	UINT8 TempByt;
	//UINT16 TempSht;
	bool TempFlag;
	UINT16 LoopExtra[0x10];
	COORD_FLAG* TempCF;
	UINT8 CmdLen;
	UINT16 LastDlyPos;
	UINT8 LastDlyVal;
	UINT8 LastDlyValP;
	UINT8 LastDlyValPP;
	UINT8 CurDlyVal;
	UINT8 MaxDlyVal;
	bool GotNoAtk;
	
	memset(ProcMask, 0x00, ProcMskSize);
	SMPSNewLen = SMPSLen * 2;
	SMPSNewData = (UINT8*)malloc(SMPSNewLen);
	memset(SMPSNewData, 0x00, SMPSNewLen);
	NewCmdMask = (UINT8*)malloc(SMPSNewLen);
	memset(NewCmdMask, 0x00, SMPSNewLen);
	
	CurPos = 0x00;
	DstPos = 0x00;
	InsPtr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
	//MaxIns = 0x00;
	
	// 0x00 and 0x01 are set later
	AddNewPtrOfsToList_FromOfs(CurPos, DstPos, 0x7F);
	SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];
	SMPSNewData[DstPos + 0x03] = SMPSData[CurPos + 0x03];
	SMPSNewData[DstPos + 0x04] = SMPSData[CurPos + 0x04];
	SMPSNewData[DstPos + 0x05] = SMPSData[CurPos + 0x05];
	TempByt = SMPSData[CurPos + 0x04];	// Tempo Divider
	MaxDlyVal = 0xFF / TempByt;
	if (MaxDlyVal > 0x7F)
		MaxDlyVal = 0x7F;
	
	SetProcMask(CurPos, 0x06);
	CurPos += 0x06;
	DstPos += 0x06;
	
	// recalc pointers with new SMPS Offset
	for (CurChn = 0x00; CurChn < FMChnCnt; CurChn ++)
	{
		CurPtr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
		
		ChnList[CurChn].Ptr = CurPtr;
		
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
		
		// 0x00 and 0x01 are set later
		AddNewPtrOfsToList_FromOfs(CurPos, DstPos, 0x10 | CurChn);
		SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];
		SMPSNewData[DstPos + 0x03] = SMPSData[CurPos + 0x03];
		SMPSNewData[DstPos + 0x04] = SMPSData[CurPos + 0x04];
		SMPSNewData[DstPos + 0x05] = SMPSData[CurPos + 0x05];
		
		SetProcMask(CurPos, 0x06);
		CurPos += 0x06;
		DstPos += 0x06;
	}
	
	// copy additional header data
	CurPtr = GetMinDataPtr(0x0000);
	if (CurPos < CurPtr)
	{
		SetProcMask(CurPos, CurPtr - CurPos);
		while(CurPos < CurPtr)
		{
			SMPSNewData[DstPos] = SMPSData[CurPos];
			CurPos ++;	DstPos ++;
		}
	}
	memset(NewCmdMask, 0xFF, DstPos);
	
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
		LastNote = 0x00;
		LastDlyVal = 0x00;
		LastDlyValP = 0x00;
		LastDlyValPP = 0x00;
		CurDlyVal = 0x00;
		LastDlyPos = 0x00;
		memset(LoopExtra, 0x00, 0x10 * 0x02);
		if (GetProcMask(CurPos))
			TrackEnd = true;
		
		while(! TrackEnd && ! TrackBreak && CurPos < SMPSLen)
		{
		
		// This time we convert 80 02 02 02 02 -> 80 08
		//					and 81 04 E7 02 02 -> 81 06 02
		TempFlag = AddNewPosToList(CurPos, DstPos);
		if (TempFlag)
			LastDlyPos = 0x0000;
		NewCmdMask[DstPos] |= (TempFlag << 4);
		if (SMPSData[CurPos] < 0xE0)
		{
			CmdLen = 0x01;
			if (SMPSData[CurPos] >= 0x80)
			{
				TempByt = SMPSData[CurPos];
				SMPSNewData[DstPos] = TempByt;
				NewCmdMask[DstPos] |= 0x01;
				
				if (SMPSData[CurPos + 0x01] & 0x80)
				{
					if (CurDlyVal != LastDlyVal)
					{
						// Write additional delay byte (to restore ommitted delay)
						DstPos ++;
						CurDlyVal = LastDlyVal;
						SMPSNewData[DstPos] = CurDlyVal;
						NewCmdMask[DstPos] |= 0x01;
					}
				}
				
				if (CoordMode == CFMODE_S3K && TempByt == 0x80)
				{
					if (SMPSData[CurPos + 0x01] < 0x80)
					{
						// (81 80 01 02 results in 81 80 01 81 02)
						// skip this delay
						DstPos ++;
						SMPSNewData[DstPos] = SMPSData[CurPos + 0x01];
						NewCmdMask[DstPos] |= 0x01;
						CmdLen ++;
					}
				}
				else
				{
					LastNote = TempByt;
				}
				
				LastDlyPos = 0x0000;
				DstPos ++;
			}
			else
			{
				if (LastNote == 0x80)
					GotNoAtk = true;
				TempFlag = true;
				LastDlyValPP = LastDlyValP;
				LastDlyValP = LastDlyVal;
				LastDlyVal = SMPSData[CurPos];
				
				//if (LastDlyPos && GotNoAtk && LastDlyVal < 0x20)
				if (LastDlyPos && GotNoAtk && (LastNote != 0x80 || LastDlyValP != LastDlyValPP))
				{
					// can this delay be combined with the last one?
					TempByt = SMPSNewData[LastDlyPos] + LastDlyVal;
					if (TempByt <= MaxDlyVal)
					{
						TempFlag = false;
						DstPos = LastDlyPos;
						// combine last delay with new one and reset DstPos
						CurDlyVal = SMPSNewData[DstPos] + LastDlyVal;
						SMPSNewData[DstPos] = CurDlyVal;
						DstPos ++;
					}
				}
				
				if (TempFlag)
				{
					NewCmdMask[DstPos] |= 0x01;
					CurDlyVal = LastDlyVal;
					SMPSNewData[DstPos] = CurDlyVal;
					LastDlyPos = DstPos;
					DstPos ++;
				}
				GotNoAtk = false;
			}
			
			SetProcMask(CurPos, CmdLen);
			CurPos += CmdLen;
		}
		else
		{
			NewCmdMask[DstPos] |= 0x01;
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
				if (CoordMode == CFMODE_TRS && SMPSData[CurPos] == 0xE4)
				{
					if (SMPSData[CurPos + 0x01])
						CmdLen += 0x04;
				}
				else if (CoordMode == CFMODE_S3K && SMPSData[CurPos] == 0xEF)
				{
					if (SMPSData[CurPos + 0x01] & 0x80)
						CmdLen += 0x01;
				}
			}
			
			// HERE is the important code
			if (SMPSData[CurPos] == 0xE7)
				GotNoAtk = true;
			else
				LastDlyPos = 0x0000;
			
			if (TempCF->Type != CFTYPE_STOP_TRACK && ! TempCF->JmpOfs &&
				TempCF->Type != CFTYPE_RETURN)
				TempByt = CFTYPE_NO_CHANGE;
			else
				TempByt = TempCF->Type;
			switch(TempByt)
			{
			case CFTYPE_STOP_TRACK:	// Flag F2 (all) / E3 (S3K only)
				NewCmdMask[DstPos] = 0xFF;
				SMPSNewData[DstPos] = SMPSData[CurPos];
				
				TrackEnd = true;
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += 0x01;
				break;
			case CFTYPE_LOOP:	// Flag F7
				NewCmdMask[DstPos] |= 0x02;
				SMPSNewData[DstPos + 0x00] = 0xF7;
				SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x01];	// Loop Index
				SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];	// Loop Count
				TempByt = SMPSData[CurPos + 0x01];
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + TempCF->JmpOfs], CurPos + TempCF->JmpOfs);
				AddNewPtrOfsToList(CurPtr, DstPos + TempCF->JmpOfs, 0xF7);
				
				SetProcMask(CurPos, CmdLen);
				if (! LoopExtra[TempByt])
					CurPos += 0x05;
				else
					CurPos = LoopExtra[TempByt];
				LoopExtra[TempByt] = 0x0000;
				DstPos += CmdLen;
				break;
			case CFTYPE_GOTO:	// Flag F6
				NewCmdMask[DstPos] |= 0x08;
				SMPSNewData[DstPos + 0x00] = 0xF6;
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + TempCF->JmpOfs], CurPos + TempCF->JmpOfs);
				AddNewPtrOfsToList(CurPtr, DstPos + TempCF->JmpOfs, 0xF6);
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				
				// if we jump to an offset that's already processed,
				// then it's definately a loop
				if (! GetProcMask(CurPtr))
				{
					if (GosubID < GOSUB_LIMIT)
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
				NewCmdMask[DstPos] |= 0x08;
				SMPSNewData[DstPos + 0x00] = 0xF8;
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + TempCF->JmpOfs], CurPos + TempCF->JmpOfs);
				AddNewPtrOfsToList(CurPtr, DstPos + TempCF->JmpOfs, 0xF8);
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				
				LastNote = 0x00;
				LastDlyVal = 0x00;
				LastDlyValP = 0x00;
				LastDlyValPP = 0x00;
				CurDlyVal = 0x00;
				if (! GetProcMask(CurPtr))
				{
					for (TempByt = 0x00; TempByt < GosubID; TempByt ++)
					{
						if (GosubPtr[TempByt] == CurPtr)
							break;
					}
					if (TempByt >= GosubID)
					{
						if (GosubID < GOSUB_LIMIT)
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
				NewCmdMask[DstPos] |= 0x08;
				SMPSNewData[DstPos] = SMPSData[CurPos];
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				TrackEnd = true;
				break;
			case CFTYPE_LP_JMP:	// Flag EB (S3K only)
				// TODO: Confirm that this works correctly
				NewCmdMask[DstPos] |= 0x08;
				SMPSNewData[DstPos] = SMPSData[CurPos];
				
				TempByt = SMPSData[CurPos + 0x01];
				SMPSNewData[DstPos + 0x01] = TempByt;
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + TempCF->JmpOfs], CurPos + TempCF->JmpOfs);
				AddNewPtrOfsToList(CurPtr, DstPos + TempCF->JmpOfs, 0xEB);
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				
				if (CoordMode2 && TempByt >= 0x0C)
				{
					// S2R Mode
					if (! GetProcMask(CurPtr))
					{
						for (TempByt = 0x00; TempByt < GosubID; TempByt ++)
						{
							if (GosubPtr[TempByt] == CurPtr)
								break;
						}
						if (TempByt >= GosubID)
						{
							if (GosubID < GOSUB_LIMIT)
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
				}
				
				if (! LoopExtra[TempByt])
					LoopExtra[TempByt] = CurPtr;
				break;
			default:
				for (TempByt = 0x00; TempByt < CmdLen; TempByt ++)
					SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				break;
			}
		}
		
		if (TrackEnd)
		{
			CurGosub ++;
			if (CurGosub < GosubID)
			{
				CurPos = GosubPtr[CurGosub];
				TrackEnd = false;
				LastNote = 0x00;
				LastDlyVal = 0x00;
				LastDlyValP = 0x00;
				LastDlyValPP = 0x00;
				CurDlyVal = 0x00;
				LastDlyPos = 0x00;
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
	
	// In the worst case (read: S3: LBZ1), the Instrument Pointer points to the EOF.
	AddNewPosToList(InsPtr, DstPos);
	if (PtrMode == CPTR_Z80)
		CurPtr = SMPSOffset ^ (SMPSOffset + InsPtr);
	else
		CurPtr = 0x0000;
	if (InsPtr >= SMPSLen)
	{
		//printf("Warning: Instrument Table Offset after End of File! Ignored.\n");
	}
	else if (! (CurPtr & 0x8000))	// catch invalid Z80 InsPtrs (like Sonic 3 Global Instrument Bank)
	{
		CurPtr = GetMinDataPtr(InsPtr + 1);
		if (CurPtr == 0xFFFF)
			CurPtr = SMPSLen;
		MaxIns = (CurPtr - InsPtr) / 0x19;
		SetProcMask(InsPtr, 0x19 * MaxIns);
		
		memcpy(&SMPSNewData[DstPos], &SMPSData[InsPtr], 0x19 * MaxIns);
		DstPos += 0x19 * MaxIns;
	}
	SMPSNewLen = DstPos;
	
	return;
}

void OptimizeSMPS_Loops(void)
{
	UINT8 CurChn;
	UINT8 ChnID;
	UINT16 CurPos;
	UINT16 DstPos;
	//UINT8 TempoDiv;
	UINT16 CurPtr;
	bool TrackEnd;
	UINT8 CurGosub;
	UINT8 GosubID;
	UINT16 GosubPtr[GOSUB_LIMIT];
	UINT16 GosubParent[GOSUB_LIMIT][0x40];
	UINT16 InsPtr;
	UINT8 MaxIns;
	bool TrackBreak;
	UINT8 TempByt;
	UINT16 TempSht;
	bool TempFlag;
	UINT16 LoopExtra[0x10];
	COORD_FLAG* TempCF;
	UINT8 CmdLen;
	UINT16 MinSPos;	// Minimum Loop Search offset
	UINT8 LastNote;
	UINT8 LastDelay;
	PTR_LIST* CurLst;
	UINT16 LoopStS;
	UINT16 LoopTimes;
	UINT16 LoopStD;
	UINT8 LoopMskBase;
	
	memset(ProcMask, 0x00, ProcMskSize);
	SMPSNewLen = SMPSLen * 2;
	SMPSNewData = (UINT8*)malloc(SMPSNewLen);
	memset(SMPSNewData, 0x00, SMPSNewLen);
	NewCmdMask = (UINT8*)malloc(SMPSNewLen);
	memset(NewCmdMask, 0x00, SMPSNewLen);
//	memset(CmdMask, 0x00, SMPSLen);
	PtrCnvTable = (UINT16*)malloc(SMPSLen * 0x02);
	memset(PtrCnvTable, 0x00, SMPSLen * 0x02);
	
	CurPos = 0x00;
	DstPos = 0x00;
	InsPtr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
	//MaxIns = 0x00;
	
	// 0x00 and 0x01 are set later
	AddNewPtrOfsToList_FromOfs(CurPos, DstPos, 0x7F);
	SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];
	SMPSNewData[DstPos + 0x03] = SMPSData[CurPos + 0x03];
	SMPSNewData[DstPos + 0x04] = SMPSData[CurPos + 0x04];
	SMPSNewData[DstPos + 0x05] = SMPSData[CurPos + 0x05];
	TempByt = SMPSData[CurPos + 0x04];	// Tempo Divider
	
	SetProcMask(CurPos, 0x06);
	CurPos += 0x06;
	DstPos += 0x06;
	
	// recalc pointers with new SMPS Offset
	for (CurChn = 0x00; CurChn < FMChnCnt; CurChn ++)
	{
		CurPtr = Get16Ptr(&SMPSData[CurPos + 0x00], 0x0000);
		
		ChnList[CurChn].Ptr = CurPtr;
		
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
		
		// 0x00 and 0x01 are set later
		AddNewPtrOfsToList_FromOfs(CurPos, DstPos, 0x10 | CurChn);
		SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];
		SMPSNewData[DstPos + 0x03] = SMPSData[CurPos + 0x03];
		SMPSNewData[DstPos + 0x04] = SMPSData[CurPos + 0x04];
		SMPSNewData[DstPos + 0x05] = SMPSData[CurPos + 0x05];
		
		SetProcMask(CurPos, 0x06);
		CurPos += 0x06;
		DstPos += 0x06;
	}
	
	// copy additional header data
	CurPtr = GetMinDataPtr(0x0000);
	if (CurPos < CurPtr)
	{
		SetProcMask(CurPos, CurPtr - CurPos);
		while(CurPos < CurPtr)
		{
			SMPSNewData[DstPos] = SMPSData[CurPos];
			CurPos ++;	DstPos ++;
		}
	}
	memset(NewCmdMask, 0xFF, DstPos);
	
	CurLst = PtrList;
	while(CurLst != NULL)
	{
		if (CurLst->CoordFlg != 0xF7)
			CmdMask[CurLst->SrcPtr] |= 0x40;
		else
			CmdMask[CurLst->SrcPtr] |= 0x20;
		CurLst = CurLst->next;
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
		GosubParent[0x00][0x00] = 0x00;
		GosubID = 0x01;
		LoopMskBase = 0x00;
		LastNote = 0x00;
		LastDelay = 0x00;
		memset(LoopExtra, 0x00, 0x10 * 0x02);
		if (GetProcMask(CurPos))
			TrackEnd = true;
		
		MinSPos = CurPos;
		while(! TrackEnd && ! TrackBreak && CurPos < SMPSLen)
		{
		
		PtrCnvTable[CurPos] = DstPos;
		NewCmdMask[DstPos] |= LoopMskBase;
		TempFlag = AddNewPosToList(CurPos, DstPos);
		//if (! TempFlag )
		{
			LoopStS = CompareBlocks(MinSPos, CurPos, LastNote, LastDelay);
			if (LoopStS)
			{
				{
					UINT16 TempSht2;
					UINT16 LoopTimes2;
					
					LoopTimes = GetLoopLength(LoopStS, CurPos, LastNote, LastDelay, &TempSht);
					LoopTimes2 = GetLoopLength(LoopStS + 0x01, CurPos, LastNote, LastDelay, &TempSht2);
					if (TempSht == TempSht2)
					{
						LoopStS ++;
						LoopTimes = LoopTimes2;
					}
				}
				if (TempSht - CurPos > 0x05)
				{
					TempByt = CheckLoopValidity(0x00, PtrCnvTable[LoopStS], DstPos + 0x01);
					//printf("Loop #%hu found in Trk %hu: %04hX-%04hX x%u (til %04hX)\n",
					//		TempByt, CurChn, LoopStS, CurPos, LoopTimes, TempSht);
					printf("Trk %hu", CurChn);
					if (CurGosub)
						printf(" (Subrt. %hu)", CurGosub);
					printf(" - Loop #%hu found: %04hX-%04hX x%u (til %04hX)\n",
							TempByt, LoopStS, CurPos, LoopTimes, TempSht);
					if (LoopTimes > 0xFF)
					{
						// TODO: Fix!!!! (currently all additional loops are simply ignored)
						printf("Warning: high loop count detected!\n");
						LoopTimes = 0xFF;
						//_getch();
					}
					LoopStD = PtrCnvTable[LoopStS];
					if (! LoopStD)	// CompareBlocks should catch that case now
						printf("Error - No entry for Offset 0x%04X in conversion table!\n", LoopStS);
					
					SMPSNewData[DstPos + 0x00] = 0xF7;
					SMPSNewData[DstPos + 0x01] = TempByt;	// Loop Index
					SMPSNewData[DstPos + 0x02] = (UINT8)LoopTimes;
					
					AddPtrToList(CurPos, LoopStS, 0xF7);
					AddNewPtrOfsToList(LoopStS, DstPos + 0x03, 0xF7);
					AddNewPosToList(LoopStS, LoopStD);
					DstPos += 0x05;
					
					SetProcMask(CurPos, TempSht - CurPos);
					while(CurPos < TempSht)
					{
						CmdMask[CurPos] |= 0x80;
						CurPos ++;
					}
					//MinSPos = CurPos;
					continue;
				}
			}
		}
		
		if (SMPSData[CurPos] < 0xE0)
		{
			CmdLen = 0x01;
			if (SMPSData[CurPos] >= 0x80)
			{
				TempByt = SMPSData[CurPos];
				SMPSNewData[DstPos] = TempByt;
				if (! (TempByt == 0x80 && CoordMode == CFMODE_S3K))
					LastNote = TempByt;
				DstPos ++;
				if (! (SMPSData[CurPos + 0x01] & 0x80))
				{
					PtrCnvTable[CurPos + 0x01] = DstPos;
					NewCmdMask[DstPos] |= LoopMskBase;
					TempFlag = AddNewPosToList(CurPos + 0x01, DstPos);
					
					LastDelay = SMPSData[CurPos + 0x01];
					SMPSNewData[DstPos] = LastDelay;
					DstPos ++;
					CmdLen ++;
				}
			}
			else
			{
				LastDelay = SMPSData[CurPos];
				SMPSNewData[DstPos] = LastDelay;
				DstPos ++;
			}
			
			SetProcMask(CurPos, CmdLen);
			CurPos += CmdLen;
		}
		else
		{
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
				if (CoordMode == CFMODE_TRS && SMPSData[CurPos] == 0xE4)
				{
					if (SMPSData[CurPos + 0x01])
						CmdLen += 0x04;
				}
				else if (CoordMode == CFMODE_S3K && SMPSData[CurPos] == 0xEF)
				{
					if (SMPSData[CurPos + 0x01] & 0x80)
						CmdLen += 0x01;
				}
			}
			
			if (TempCF->Type != CFTYPE_STOP_TRACK && ! TempCF->JmpOfs &&
				TempCF->Type != CFTYPE_RETURN)
				TempByt = CFTYPE_NO_CHANGE;
			else
				TempByt = TempCF->Type;
			switch(TempByt)
			{
			case CFTYPE_STOP_TRACK:	// Flag F2 (all) / E3 (S3K only)
				NewCmdMask[DstPos] = 0xFF;
				SMPSNewData[DstPos] = SMPSData[CurPos];
				
				TrackEnd = true;
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += 0x01;
				break;
			case CFTYPE_LOOP:	// Flag F7
				SMPSNewData[DstPos + 0x00] = 0xF7;
				//SMPSNewData[DstPos + 0x01] = SMPSData[CurPos + 0x01];	// Loop Index
				SMPSNewData[DstPos + 0x02] = SMPSData[CurPos + 0x02];	// Loop Count
				TempByt = SMPSData[CurPos + 0x01];
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + TempCF->JmpOfs], CurPos + TempCF->JmpOfs);
				AddNewPtrOfsToList(CurPtr, DstPos + TempCF->JmpOfs, 0xF7);
				SMPSNewData[DstPos + 0x01] = CheckLoopValidity(TempByt, PtrCnvTable[CurPtr], DstPos + 0x01);
				
				SetProcMask(CurPos, CmdLen);
				if (! LoopExtra[TempByt])
					CurPos += 0x05;
				else
					CurPos = LoopExtra[TempByt];
				LoopExtra[TempByt] = 0x0000;
				DstPos += CmdLen;
				break;
			case CFTYPE_GOTO:	// Flag F6
				SMPSNewData[DstPos + 0x00] = 0xF6;
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + TempCF->JmpOfs], CurPos + TempCF->JmpOfs);
				AddNewPtrOfsToList(CurPtr, DstPos + TempCF->JmpOfs, 0xF6);
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				
				// if we jump to an offset that's already processed,
				// then it's definately a loop
				if (! GetProcMask(CurPtr))
				{
					if (GosubID < GOSUB_LIMIT)
					{
						// Queue jump
						GosubPtr[GosubID] = CurPtr;
						GosubParent[GosubID][0x00] = 0x0000;
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
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + TempCF->JmpOfs], CurPos + TempCF->JmpOfs);
				AddNewPtrOfsToList(CurPtr, DstPos + TempCF->JmpOfs, 0xF8);
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				
				LastNote = 0x00;
				LastDelay = 0x00;
				if (! GetProcMask(CurPtr))
				{
					for (TempByt = 0x00; TempByt < GosubID; TempByt ++)
					{
						if (GosubPtr[TempByt] == CurPtr)
							break;
					}
					if (TempByt >= GosubID)
					{
						if (GosubID < GOSUB_LIMIT)
						{
							// Queue jump
							GosubPtr[GosubID] = CurPtr;
							GosubParent[GosubID][0x00] = 0x01;
							GosubParent[GosubID][0x01] = DstPos - CmdLen;
							GosubID ++;
						}
						else
						{
							printf("Error: Goto/Gosub Address Buffer too small!\n");
						}
					}
					else
					{
						// Add address to GosubParent
						if (GosubParent[TempByt][0x00] < 0x3F)
						{
							GosubParent[TempByt][0x00] ++;
							GosubParent[TempByt][ GosubParent[TempByt][0x00] ] = DstPos - CmdLen;
						}
						else
						{
							printf("Error: Gosub Parent Address Buffer too small!\n");
						}
					}
				}
				break;
			case CFTYPE_RETURN:	// Flag E3 (S1/2), Flag F9 (S3K/Trs)
				SMPSNewData[DstPos] = SMPSData[CurPos];
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				TrackEnd = true;
				break;
			case CFTYPE_LP_JMP:	// Flag EB (S3K only)
				// TODO: Confirm that this works correctly
				//NewCmdMask[DstPos] |= 0x08;
				SMPSNewData[DstPos] = SMPSData[CurPos];
				
				TempByt = SMPSData[CurPos + 0x01];
				SMPSNewData[DstPos + 0x01] = TempByt;
				
				CurPtr = Get16Ptr(&SMPSData[CurPos + TempCF->JmpOfs], CurPos + TempCF->JmpOfs);
				AddNewPtrOfsToList(CurPtr, DstPos + TempCF->JmpOfs, 0xEB);
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				
				if (CoordMode2 && TempByt >= 0x0C)
				{
					// S2R Mode
					if (! GetProcMask(CurPtr))
					{
						for (TempByt = 0x00; TempByt < GosubID; TempByt ++)
						{
							if (GosubPtr[TempByt] == CurPtr)
								break;
						}
						if (TempByt >= GosubID)
						{
							if (GosubID < GOSUB_LIMIT)
							{
								// Queue jump
								GosubPtr[GosubID] = CurPtr;
								GosubParent[GosubID][0x00] = 0x0000;
								GosubID ++;
							}
							else
							{
								printf("Error: Goto/Gosub Address Buffer too small!\n");
							}
						}
					}
					break;
				}
				
				if (! LoopExtra[TempByt])
					LoopExtra[TempByt] = CurPtr;
				break;
			default:
				for (TempByt = 0x00; TempByt < CmdLen; TempByt ++)
				{
					SMPSNewData[DstPos + TempByt] = SMPSData[CurPos + TempByt];
					//PtrCnvTable[CurPos + TempByt] = DstPos + TempByt;	// uncomment to enable Mid-Command loop-back
				}
				
				SetProcMask(CurPos, CmdLen);
				CurPos += CmdLen;
				DstPos += CmdLen;
				break;
			}
		}
		
		if (TrackEnd)
		{
			CurGosub ++;
			if (CurGosub < GosubID)
			{
				CurPos = GosubPtr[CurGosub];
				LoopMskBase = 0x00;
				if (GosubParent[CurGosub][0x00])
				{
					// Now OR the Loop Mask of all F8 commands to the Subroutine Mask
					for (LoopTimes = 0x01; LoopTimes <= GosubParent[CurGosub][0x00]; LoopTimes ++)
						LoopMskBase |= NewCmdMask[GosubParent[CurGosub][LoopTimes]];
				}
				MinSPos = CurPos;
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
	
	// In the worst case (read: S3: LBZ1), the Instrument Pointer points to the EOF.
	AddNewPosToList(InsPtr, DstPos);
	if (PtrMode == CPTR_Z80)
		CurPtr = SMPSOffset ^ (SMPSOffset + InsPtr);
	else
		CurPtr = 0x0000;
	if (InsPtr >= SMPSLen)
	{
		//printf("Warning: Instrument Table Offset after End of File! Ignored.\n");
	}
	else if (! (CurPtr & 0x8000))	// catch invalid Z80 InsPtrs (like Sonic 3 Global Instrument Bank)
	{
		CurPtr = GetMinDataPtr(InsPtr + 1);
		if (CurPtr == 0xFFFF)
			CurPtr = SMPSLen;
		MaxIns = (CurPtr - InsPtr) / 0x19;
		SetProcMask(InsPtr, 0x19 * MaxIns);
		
		memcpy(&SMPSNewData[DstPos], &SMPSData[InsPtr], 0x19 * MaxIns);
		DstPos += 0x19 * MaxIns;
	}
	SMPSNewLen = DstPos;
	
	return;
}

// Checks the data within a loop and returns an unused loop ID
UINT8 CheckLoopValidity(UINT8 LoopID, UINT16 LoopStart, UINT16 LoopEnd)
{
	// Note: LoopEnd should point to the F7 byte of the Loop End command.
	//       It mustn't mark the last bytes of the loop, else it's impossible to detect where loops end.
	UINT8 LoopMsk;
	UINT16 CurPos;
	UINT8 FnlLoopID;
	
	if (NewCmdMask[LoopStart])
	{
		// In the case of nested loops, find the *real* beginning of the
		// loop we're jumping into. (because we might just the 2nd half of it)
		LoopMsk = NewCmdMask[LoopStart];
		for (CurPos = LoopStart - 0x01; CurPos > 0x00; CurPos --)
		{
			if (NewCmdMask[CurPos] & 0x80)
				break;	// return when reaching the header
			if (! (LoopMsk & NewCmdMask[CurPos]))
				break;
			LoopMsk |= NewCmdMask[CurPos];
		}
		LoopStart = CurPos + 0x01;
		// The code above catches indirect overlaps.
		//	Example: 1start ... 2start .. 1end .. 3start .. 2end .. 3end
		//	results in 3end -> into 2 -> 2end -> into 1 (indirectly overlapping 3) -> 1end -> 2end -> 3end
	}
	// Create a mask of all loops
	LoopMsk = 0x00;
	for (CurPos = LoopStart; CurPos < LoopEnd; CurPos ++)
		LoopMsk |= NewCmdMask[CurPos];
	
	FnlLoopID = LoopID;
	if (LoopMsk & (1 << FnlLoopID))
	{
		// Find a free loop slot
		for (FnlLoopID = 0; FnlLoopID < 8; FnlLoopID ++)
		{
			if (~LoopMsk & (1 << FnlLoopID))
				break;
		}
	}
	
	LoopMsk = 1 << FnlLoopID;
	// Now apply the loop mask to the whole loop
	for (CurPos = LoopStart; CurPos < LoopEnd; CurPos ++)
		NewCmdMask[CurPos] |= LoopMsk;
	
	return FnlLoopID;
}

UINT16 CompareBlocks(UINT16 SrcPos, UINT16 CpyPos, UINT8 LastNoteC, UINT8 LastDelayC)
{
	for (; SrcPos < CpyPos; SrcPos ++)
	{
		if (CmdMask[SrcPos] & 0x80)
			continue;
		if (CheckBlock(SrcPos, CpyPos, LastNoteC, LastDelayC) && PtrCnvTable[SrcPos])
			return SrcPos;
	}
	
	return 0x0000;
}

bool CheckBlock(UINT16 SrcPos, UINT16 CpyPos, UINT8 LastNoteC, UINT8 LastDelayC)
{
	UINT16 CurSPos;
	UINT16 CurCPos;
	COORD_FLAG* TempCF;
	UINT8 CmdLen;
	UINT8 CurByt;
	UINT8 LastNoteS;
	UINT8 LastDelayS;
	UINT16 PtrS;
	UINT16 PtrC;
	
	if ((CmdMask[SrcPos] & 0x80))	// data already removed when making another loop
		return false;
	
	for (CurSPos = SrcPos, CurCPos = CpyPos; CurSPos < CpyPos; )
	{
		if ((CmdMask[CurCPos] & 0x40))		// another loop starts here - STOP
			return false;
		
		if (SMPSData[CurCPos] < 0xE0)
		{
			LastNoteS = LastNoteC;
			LastDelayS = LastDelayC;
			
			// This processes:
			//	- Note Note (80 80, stop after first Note)
			//	- Note Delay (80 00, both)
			//	- Delay Delay (00 00, stop after first Delay)
			if (SMPSData[CurCPos] & 0x80)	// Note (80-DF)
			{
				LastNoteC = SMPSData[CurCPos];
				CurCPos ++;
			}
			if (! (SMPSData[CurCPos] & 0x80))	// Delay (00-7F)
			{
				LastDelayC = SMPSData[CurCPos];
				CurCPos ++;
			}
			
			if (SMPSData[CurSPos] & 0x80)	// Note (80-DF)
			{
				LastNoteS = SMPSData[CurSPos];
				CurSPos ++;
			}
			if (! (SMPSData[CurSPos] & 0x80))	// Delay (00-7F)
			{
				LastDelayS = SMPSData[CurSPos];
				CurSPos ++;
			}
			
			if (LastNoteC != LastNoteS || LastDelayC != LastDelayS)
				return false;
		}
		else
		{
			if (SMPSData[CurCPos] < 0xFF)
			{
				TempCF = &CFMain[SMPSData[CurCPos] & 0x1F];
			}
			else if (SMPSData[CurCPos] == 0xFF)
			{
				if (SMPSData[CurCPos + 0x01] < 0x10)
					TempCF = &CFExt[SMPSData[CurCPos + 0x01]];
				else
					TempCF = &CFExt[0x10];
			}
			CmdLen = TempCF->Len & 0x7F;
			
			if (TempCF->Type == CFTYPE_STOP_TRACK || TempCF->Type == CFTYPE_GOTO ||
				TempCF->Type == CFTYPE_RETURN)
			{
				return false;
			}
			else if (TempCF->JmpOfs)
			{
				// CFTYPE_LOOP, CFTYPE_GOSUB, etc.
				for (CurByt = 0x00; CurByt < CmdLen; CurByt ++)
				{
					if (CurByt == TempCF->JmpOfs)
					{
						PtrS = Get16Ptr(&SMPSData[CurSPos + CurByt], CurSPos + CurByt);
						PtrC = Get16Ptr(&SMPSData[CurCPos + CurByt], CurCPos + CurByt);
						if (TempCF->Type == CFTYPE_LOOP || TempCF->Type == CFTYPE_LP_JMP)
						{
							PtrS -= CurSPos;
							PtrC -= CurCPos;
						}
						if (PtrS != PtrC)
							return false;
						CurByt ++;	// Pointers have 2 bytes
					}
					else if (SMPSData[CurSPos + CurByt] != SMPSData[CurCPos + CurByt] ||
						(CmdMask[CurSPos + CurByt] & 0x80))
					{
						return false;
					}
				}
			}
			else
			{
				for (CurByt = 0x00; CurByt < CmdLen; CurByt ++)
				{
					if (SMPSData[CurSPos + CurByt] != SMPSData[CurCPos + CurByt] ||
						(CmdMask[CurSPos + CurByt] & 0x80))
						return false;
				}
			}
			CurSPos += CmdLen;	CurCPos += CmdLen;
		}
	}
	
	return true;
}

UINT16 GetLoopLength(UINT16 SrcPos, UINT16 CpyPos, UINT8 LastNoteC, UINT8 LastDelayC, UINT16* RetLoopEnd)
{
	UINT16 CurSPos;
	UINT16 RealSPos;
	UINT16 CurCPos;
	COORD_FLAG* TempCF;
	UINT8 CmdLen;
	UINT8 CurByt;
	UINT8 LastNoteS;
	UINT8 LastDelayS;
	UINT16 LoopTimes;
	UINT16 PtrS;
	UINT16 PtrC;
	UINT16 InLoops;
	UINT16 LpTmCache;
	UINT16 RLpEndCache;
	
	*RetLoopEnd = 0x0000;
	LoopTimes = 0x01;
	if (CmdMask[SrcPos] & 0x80)	// data already removed when making another loop
		return LoopTimes;
	InLoops = 0x00;
	for (RealSPos = CurSPos = SrcPos, CurCPos = CpyPos; CurCPos < SMPSLen; )
	{
		if (RealSPos == CpyPos)
		{
			if (! InLoops)
			{
				LoopTimes ++;
				*RetLoopEnd = CurCPos;
			}
			RealSPos = SrcPos;
		}
		if (CmdMask[CurCPos] & 0x40)		// another loop starts here - STOP
			return LoopTimes;
		if (CmdMask[CurCPos] & 0x20)		// another loop starts here - STOP
		{
			InLoops ++;
			LpTmCache = LoopTimes;
			RLpEndCache = *RetLoopEnd;
		}
		
		if (SMPSData[CurCPos] < 0xE0)
		{
			LastNoteS = LastNoteC;
			LastDelayS = LastDelayC;
			CmdLen = LastNoteS;	// cache for S3K mode
			CurByt = LastNoteC;
			
			// This processes:
			//	- Note Note (80 80, stop after first Note)
			//	- Note Delay (80 00, both)
			//	- Delay Delay (00 00, stop after first Delay)
			if (SMPSData[CurCPos] & 0x80)	// Note (80-DF)
			{
				LastNoteC = SMPSData[CurCPos];
				CurCPos ++;
			}
			if (! (SMPSData[CurCPos] & 0x80))	// Delay (00-7F)
			{
				LastDelayC = SMPSData[CurCPos];
				CurCPos ++;
			}
			
			if (SMPSData[RealSPos] & 0x80)	// Note (80-DF)
			{
				LastNoteS = SMPSData[RealSPos];
				RealSPos ++;
			}
			if (! (SMPSData[RealSPos] & 0x80))	// Delay (00-7F)
			{
				LastDelayS = SMPSData[RealSPos];
				RealSPos ++;
			}
			if (SMPSData[CurSPos] & 0x80)
				CurSPos ++;
			if (! (SMPSData[CurSPos] & 0x80))
				CurSPos ++;
			
			if (LastNoteC != LastNoteS || LastDelayC != LastDelayS)
				return LoopTimes;
			
			if (LastNoteS == 0x80 && CoordMode == CFMODE_S3K)
				LastNoteS = CmdLen;
			if (LastNoteC == 0x80 && CoordMode == CFMODE_S3K)
				LastNoteC = CmdLen;
		}
		else
		{
			if (SMPSData[CurCPos] < 0xFF)
			{
				TempCF = &CFMain[SMPSData[CurCPos] & 0x1F];
			}
			else if (SMPSData[CurCPos] == 0xFF)
			{
				if (SMPSData[CurCPos + 0x01] < 0x10)
					TempCF = &CFExt[SMPSData[CurCPos + 0x01]];
				else
					TempCF = &CFExt[0x10];
			}
			CmdLen = TempCF->Len & 0x7F;
			
			if (TempCF->Type == CFTYPE_STOP_TRACK || TempCF->Type == CFTYPE_GOTO ||
				TempCF->Type == CFTYPE_RETURN)
			{
				return LoopTimes;
			}
			else if (TempCF->JmpOfs)
			{
				// CFTYPE_LOOP, CFTYPE_GOSUB, etc.
				for (CurByt = 0x00; CurByt < CmdLen; CurByt ++)
				{
					if (CurByt == TempCF->JmpOfs)
					{
						PtrS = Get16Ptr(&SMPSData[CurSPos + CurByt], CurSPos + CurByt);
						PtrC = Get16Ptr(&SMPSData[CurCPos + CurByt], CurCPos + CurByt);
						if (TempCF->Type == CFTYPE_LOOP || TempCF->Type == CFTYPE_LP_JMP)
						{
							PtrS -= CurSPos;
							PtrC -= CurCPos;
						}
						if (PtrS != PtrC)
							return LoopTimes;
						CurByt ++;	// Pointers have 2 bytes
					}
					else if (SMPSData[CurSPos + CurByt] != SMPSData[CurCPos + CurByt] ||
						(CmdMask[CurSPos + CurByt] & 0x80))
					{
						return LoopTimes;
					}
				}
				CurSPos += CmdLen;	RealSPos += CmdLen;	CurCPos += CmdLen;
				if (TempCF->Type == CFTYPE_LOOP)
				{
					InLoops --;
					if (! InLoops)
					{
						LoopTimes = LpTmCache;
						*RetLoopEnd = RLpEndCache;
					}
				}
			}
			else
			{
				// also handles CFTYPE_LOOP (because size+loop must match)
				while(CmdLen)
				{
					if (SMPSData[CurSPos] != SMPSData[CurCPos] ||
						(CmdMask[CurSPos] & 0x80))
						return LoopTimes;
					CurSPos ++;	RealSPos ++;	CurCPos ++;
					CmdLen --;
				}
			}
		}
	}
	
	return 0x0000;
}


void WritePointers(void)
{
	PTR_LIST* CurLst;
	OFS_LIST* CurOfs;
	UINT16 PtrVal;
	UINT16 HdrSize;
	
	HdrSize = 0x06 + FMChnCnt * 0x04 + PSGChnCnt * 0x06;
	CurLst = PtrList;
	while(CurLst != NULL)
	{
		CurOfs = CurLst->DstPosLst;
		if (CurLst->DstPtr == 0xFFFF && CurLst->SrcPtr < HdrSize)
			// Hack/Fix for SMPS files that use byte 0x09 to turn the DAC of.
			// (because some people are stupid enough to programs write files
			//  that violate all standards)
			CurLst->DstPtr = CurLst->SrcPtr;
		
		while(CurOfs != NULL)
		{
			// only the coordination flags of SMPS 68k have relative pointers
			switch(PtrMode)
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
				PtrVal = 0xAAAA;
				printf("Error at 0x%04X: Dst Ptr for Src Ofs 0x%04X not found! (Src Ptr Ref 0x%04X)",
						CurLst->DstPosLst->Ofs, CurLst->SrcPtr, CurLst->SrcPosLst->Ofs);
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

void PrepareNextPass(void)
{
	PTR_LIST* CurLst;
	OFS_LIST* CurOfs;
	DATAPTR_LIST* CurDPtr;
	PTR_LIST* OldLst;
	OFS_LIST* OldOfs;
	DATAPTR_LIST* OldDPtr;
	
	if (SMPSNewLen <= SMPSLen)
	{
		free(SMPSData);
		free(CmdMask);
		SMPSLen = SMPSNewLen;
		SMPSData = SMPSNewData;
		SMPSNewLen = 0x0000;
		SMPSNewData = NULL;
		ProcMskSize = (SMPSLen + 0x07) >> 3;
		ProcMask = (UINT8*)realloc(ProcMask, ProcMskSize);
		CmdMask = NewCmdMask;
		NewCmdMask = NULL;
		
		CurDPtr = SrcPosPtrList;
		SrcPosPtrList = NULL;
		while(CurDPtr != NULL)
		{
			OldDPtr = CurDPtr;
			CurDPtr = CurDPtr->next;
			free(OldDPtr);
		}
		SrcPosPtrLEnd = NULL;
		
		CurLst = PtrList;
		PtrList = PtrLEnd = NULL;
		while(CurLst != NULL)
		{
			CurOfs = CurLst->DstPosLst;
			while(CurOfs != NULL)
			{
				if (CurOfs->CoordFlg < 0x20)
				{
					if (CurOfs->CoordFlg & 0x10)
						ChnList[FMChnCnt + (CurOfs->CoordFlg & 0x0F)].Ptr = CurLst->DstPtr;
					else
						ChnList[CurOfs->CoordFlg].Ptr = CurLst->DstPtr;
				}
				AddPtrToList(CurOfs->Ofs, CurLst->DstPtr, CurOfs->CoordFlg);
				
				OldOfs = CurOfs;
				CurOfs = CurOfs->next;
				free(OldOfs);
			}
			
			OldLst = CurLst;
			CurLst = CurLst->next;
			free(OldLst);
		}
	}
	else	// SMPSNewLen >= SMPSLen
	{
		free(SMPSNewData);
		SMPSNewData = NULL;
		
		CurLst = PtrList;
		while(CurLst != NULL)
		{
			CurLst->DstPosLst = NULL;
			CurLst->DstPtr = 0xFFFF;
			
			CurOfs = CurLst->DstPosLst;
			while(CurOfs != NULL)
			{
				OldOfs = CurOfs;
				CurOfs = CurOfs->next;
				free(OldOfs);
			}
			
			CurLst = CurLst->next;
		}
	}
	
	return;
}
