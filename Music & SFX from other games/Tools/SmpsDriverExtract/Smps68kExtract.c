// SMPS 68k Data Extractor
// -----------------------
// Written by Valley Bell, November 2014

// TODO:
//	- Rest-Rest behaviour??
//	- Drum Pitch array
//	- Tempo Algorithm

#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <memory.h>
#include <string.h>
#include "stdtype.h"

#include "Smps68k_RoutineLib.h"


#ifndef _MSC_VER
#define _stricmp	strcasecomp
#endif


typedef struct _pan_ani_header
{
	char Signature[0x04];
	UINT8 Type;
	UINT8 AniCount;
	UINT16 AniListOfs;
	UINT8 AniListBaseMSB;
	UINT8 AniListBaseLSB;
	UINT8 Padding[0x06];
} PANI_HEADER;

typedef struct _coord_flag_info
{
	UINT32 Ptr;
	UINT16 Size;
	const char* Name;
	const char* Desc;
} CF_INFO;

typedef struct _channelmask_data
{
	const UINT8* Data;
	UINT16 Size;
	UINT8 Mode;
	UINT8 Param2;
} CHMASK_DATA;

int main(int argc, char* argv[]);
void OpenROMFile(const char* FileName);

static void DumpPanAnimation(void);
static void DumpPanAniFile(UINT8 Type, UINT32 StartOfs, UINT16 AniCnt, UINT32 EndOfs);

static void ShowFrequencies(void);
static UINT16 ParseFreqTable(UINT32* Offset, UINT8 Mode);
static void LimitArrayCount(UINT16* Count, UINT8 ItmSize, UINT32 ArrPos, UINT32 OtherPos);
static void PrintFreqTable(const UINT8* Data, UINT16 FreqCnt, UINT8 Mode);

static void CoordFlagAnalysis(void);
static UINT32 FindRoutineEnd(UINT32 RoutinePos);
static UINT32 GetNextPtr(UINT16 PtrCount, UINT32* PtrArr, UINT32 MinPtr);
static void ScanForCFRoutine(CF_INFO* CFInf);
static void PrintCFInfo(const CF_INFO* CFInf, UINT8 CFID);

static void PrintFadeInfo(void);

void ExtractSmpsData(void);

void DumpFile(const char* Title, const char* Ext, UINT32 DataLen, const UINT8* Data);
UINT32 ScanForData2(UINT32 DataLen, const UINT8* Data, UINT32 StartPos);
UINT32 ScanForData2_WC(UINT32 DataLen, const UINT8* Data, UINT32 StartPos);
static INT8 memcmp_wc(const UINT8* buf1, const UINT8* buf2, UINT32 count);
static INT8 memcmp_wcAA(const UINT8* data, const UINT8* compare, UINT32 count);
static UINT16 ReadBE16(const UINT8* Data);
static UINT32 ReadBE32(const UINT8* Data);
static UINT32 ReadBE24(const UINT8* Data);
static UINT16 ReadLE16(const UINT8* Data);
static UINT32 ReadLEA(const UINT8* Code, UINT32 InstPos);
static void FixMarsPointer(UINT32* ROMPos);


// FM/PSG frequency lists, taken from SMPSPlay
static const UINT16 DEF_FMFREQ_VAL[13] =
	{0x25E, 0x284, 0x2AB, 0x2D3, 0x2FE, 0x32D, 0x35C, 0x38F, 0x3C5, 0x3FF, 0x43C, 0x47C, 0x4C0};
#define DEF_FMFREQ_68K_VAL	&DEF_FMFREQ_VAL[0]
#define DEF_FMFREQ_Z80_VAL	&DEF_FMFREQ_VAL[1]

#define DEF_PSGFREQ_PRE_CNT		84
static const UINT16 DEF_PSGFREQ_PRE_VAL[DEF_PSGFREQ_PRE_CNT] =
{	0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x3F8, 0x3BF, 0x389,
	0x356, 0x326, 0x2F9, 0x2CE, 0x2A5, 0x280, 0x25C, 0x23A, 0x21A, 0x1FB, 0x1DF, 0x1C4,
	0x1AB, 0x193, 0x17D, 0x167, 0x153, 0x140, 0x12E, 0x11D, 0x10D, 0x0FE, 0x0EF, 0x0E2,
	0x0D6, 0x0C9, 0x0BE, 0x0B4, 0x0A9, 0x0A0, 0x097, 0x08F, 0x087, 0x07F, 0x078, 0x071,
	0x06B, 0x065, 0x05F, 0x05A, 0x055, 0x050, 0x04B, 0x047, 0x043, 0x040, 0x03C, 0x039,
	0x036, 0x033, 0x030, 0x02D, 0x02B, 0x028, 0x026, 0x024, 0x022, 0x020, 0x01F, 0x01D,
	0x01B, 0x01A, 0x018, 0x017, 0x016, 0x015, 0x013, 0x012, 0x011, 0x000};

#define DEF_PSGFREQ_68K_CNT		70
#define DEF_PSGFREQ_68K_VAL		&DEF_PSGFREQ_PRE_VAL[12]

#define DEF_PSGFREQ_Z80_T1_CNT	69
#define DEF_PSGFREQ_Z80_T1_VAL	DEF_PSGFREQ_68K_VAL

#define DEF_PSGFREQ_Z80_T2_CNT	84
static const UINT16 DEF_PSGFREQ_Z80_T2_VAL[DEF_PSGFREQ_Z80_T2_CNT] =
{	0x3FF, 0x3FF, 0x3FF, 0x3FF, 0x3FF, 0x3FF, 0x3FF, 0x3FF, 0x3FF, 0x3F7, 0x3BE, 0x388,
	0x356, 0x326, 0x2F9, 0x2CE, 0x2A5, 0x280, 0x25C, 0x23A, 0x21A, 0x1FB, 0x1DF, 0x1C4,
	0x1AB, 0x193, 0x17D, 0x167, 0x153, 0x140, 0x12E, 0x11D, 0x10D, 0x0FE, 0x0EF, 0x0E2,
	0x0D6, 0x0C9, 0x0BE, 0x0B4, 0x0A9, 0x0A0, 0x097, 0x08F, 0x087, 0x07F, 0x078, 0x071,
	0x06B, 0x065, 0x05F, 0x05A, 0x055, 0x050, 0x04B, 0x047, 0x043, 0x040, 0x03C, 0x039,
	0x036, 0x033, 0x030, 0x02D, 0x02B, 0x028, 0x026, 0x024, 0x022, 0x020, 0x01F, 0x01D,
	0x01B, 0x01A, 0x018, 0x017, 0x016, 0x015, 0x013, 0x012, 0x011, 0x010, 0x000, 0x000};

#define DEF_FM3FREQ_Z80_T1_CNT	4
#define DEF_FM3FREQ_Z80_T1_VAL	DEF_FM3FREQ_Z80_T2_VAL
#define DEF_FM3FREQ_Z80_T2_CNT	8
#define DEF_FM3FREQ_68K_CNT	4

static const UINT16 DEF_FM3FREQ_Z80_T2_VAL[DEF_FM3FREQ_Z80_T2_CNT] =
{	0x000, 0x132, 0x18E, 0x1E4, 0x234, 0x27E, 0x2C2, 0x2F0};
static const UINT16 DEF_FM3FREQ_Z80_T1_VAL_B[DEF_FM3FREQ_Z80_T1_CNT] =
{	0x000, 0x132, 0x18A, 0x1E4};
static const UINT16 DEF_FM3FREQ_68K_VAL[DEF_FM3FREQ_68K_CNT] =
{	0x000, 0x180, 0x1F4, 0x260};


UINT32 ROMLength;
UINT8* ROMData;
char FileBase[0x200];
char* FileTitle;
UINT8 ReadMode;
UINT8 UseBaseName;
UINT8 AnalyseCF;

UINT8 MarsMode = 1;
UINT32 MarsBase = 0;

int main(int argc, char* argv[])
{
	int argbase;
	UINT8 RetVal;
	
	printf("SMPS 68k Data Extractor\n");
	printf("-----------------------\n");
	if (argc < 2)
	{
		printf("Usage: Smps68kExtract.c [-Dump] [-UseBaseName] [-CFAnalysis] ROM.bin\n\n");
		return 0;
	}
	
	ReadMode = 0x01;
	UseBaseName = 0x00;
	AnalyseCF = 0x00;
	argbase = 1;
	while(argbase < argc && argv[argbase][0] == '-')
	{
		if (! _stricmp(argv[argbase] + 1, "Dump"))
			ReadMode = 0x00;
		else if (! _stricmp(argv[argbase] + 1, "UseBaseName"))
			UseBaseName = 0x01;
		else if (! _stricmp(argv[argbase] + 1, "CFAnalysis"))
			AnalyseCF = 0x01;
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
	
	RetVal = 0;
	ExtractSmpsData();
	
#ifdef _DEBUG
	_getch();
#endif
	
	return RetVal;
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
	printf("File name: %s\n", FileTitle);
	
	return;
}


static void DumpPanAnimation(void)
{
	const UINT8 PANANI_LIST[] = {0x10, 0xFF, 0x00, 0x20, 0x53, 0xFF, 0xE5, 0x48};
	
	UINT32 PanAni;
	UINT16 PanAniCnt;
	UINT32 PanAniEnd;
	
	UINT32 BasePos;
	UINT32 CurPos;
	UINT32 TempPos;
	UINT16 CurInst;
	
	// Pan Animation List: [Fatal Fury]
	//	160470	7000			MOVEQ	#0, D0
	//	160472	102D 0020		MOVE.B	$20(A5), D0
	//	160476	5340			SUBQ.W	#1, D0
	//	160478	E548			LSL.W	#2, D0
	//	16047A	207B 0026		MOVEA.L	PanAnimPtrs(pc,D0.w), A0
	
	// Pan Animation List: [MJ's Moonwalker]
	//	060594	41F9 0006 05D0	LEA		(PanAnimPtrs).l, A0
	//	06059A	102B 0020		MOVE.B	$20(A3), D0
	//	06059E	5300			SUBQ.B	#1, D0
	//	0605A0	E548			LSL.W	#2, D0
	//	0605A2	0240 00FF		ANDI.W	#$FF, D0
	//	0605A6	2070 0000		MOVEA.L	(A0,D0.w), A0
	BasePos = 0x00;
	PanAni = 0x00;
	do
	{
		CurPos = ScanForData2_WC(sizeof(PANANI_LIST), PANANI_LIST, BasePos);
		if (! CurPos)
			break;
		BasePos = CurPos + sizeof(PANANI_LIST);
		
		CurInst = ReadBE16(&ROMData[BasePos]);
		if ((CurInst & 0xFFF8) == 0x2078)
		{
			PanAni = ReadLEA(ROMData, BasePos);
		}
		else
		{
			CurPos -= 0x04;	// 2-byte LEA
			if (ROMData[CurPos] != 0x41)
			{
				CurPos -= 0x02;
				if (ROMData[CurPos] != 0x41)
					continue;
			}
			PanAni = ReadLEA(ROMData, CurPos);
		}
	} while(! PanAni);
	if (PanAni)
	{
		BasePos = ReadBE32(&ROMData[PanAni]);
		FixMarsPointer(&BasePos);
		PanAniEnd = BasePos;
		PanAniCnt = 0x00;
		for (CurPos = PanAni; CurPos < BasePos; CurPos += 0x04, PanAniCnt ++)
		{
			TempPos = ReadBE32(&ROMData[CurPos]);
			FixMarsPointer(&TempPos);
			if (TempPos < BasePos)
				BasePos = TempPos;
			if (PanAniEnd < TempPos)
				PanAniEnd = TempPos;
		}
		
		while(! (ROMData[PanAniEnd] & 0x3F) && PanAniEnd < ROMLength)
			PanAniEnd ++;
		if (ROMData[PanAniEnd - 1] == 0x00)
			PanAniEnd --;	// remove padding
	}
	printf("Pan Animation List: %06X\n", PanAni);
	if (PanAni)
	{
		printf("    %02X items (end %06X)\n", PanAniCnt, PanAniEnd);
		DumpPanAniFile(0x30, PanAni, PanAniCnt, PanAniEnd);
	}
	printf("\n");
	
	return;
}

static void DumpPanAniFile(UINT8 Type, UINT32 StartOfs, UINT16 AniCnt, UINT32 EndOfs)
{
	UINT32 HdrSize;
	PANI_HEADER PAniHdr;
	UINT32 FileSize;
	UINT8* FileData;
	
	HdrSize = sizeof(PANI_HEADER);
	memset(&PAniHdr, 0x00, HdrSize);
	
	memcpy(PAniHdr.Signature, "SPAN", 0x04);
	PAniHdr.Type = Type;
	PAniHdr.AniCount = (UINT8)AniCnt;
	PAniHdr.AniListOfs = (UINT16)HdrSize;
	PAniHdr.AniListBaseMSB = (UINT8)(StartOfs >> 8);
	PAniHdr.AniListBaseLSB = (UINT8)(StartOfs >> 0);
	
	FileSize = HdrSize + (EndOfs - StartOfs);
	FileData = (UINT8*)malloc(FileSize);
	
	memcpy(&FileData[0x00], &PAniHdr, HdrSize);
	memcpy(&FileData[HdrSize], &ROMData[StartOfs], EndOfs - StartOfs);
	
	DumpFile("PanAni", "bin", FileSize, FileData);
	
	free(FileData);
	
	return;
}


static void ShowFrequencies(void)
{
	const UINT8 PSG_FREQS[] = {0xDA, 0xFF, 0x00, 0x08, 0x02, 0x45, 0x00, 0x7F, 0xE3, 0xFF, 0x41};
	const UINT8 FM_FREQS[] = {0xDA, 0xFF, 0x00, 0x08, 0x02, 0x85, 0x00, 0x00, 0x00, 0xFF, 0x8A, 0xFC, 0x00, 0x0C};
	const UINT8 FM_FREQS_SSQUAD[] = {
		0xDA, 0x2D, 0x00, 0x08, 0x06, 0x05, 0x00, 0x20,
		0x02, 0x85, 0x00, 0x00, 0x00, 0x7F, 0x04, 0x05, 0x00, 0x20};
	const UINT8 FM3_FREQS_LATE[] = {0x70, 0x03, 0x72, 0x00, 0x12, 0x1C, 0xE3, 0x49, 0x30};
	
	UINT32 Freqs[3];	// 0 - PSG, 1 - FM, 2 - FM3
	UINT16 FreqCnt[3];
	
	UINT32 BasePos;
	UINT32 CurPos;
	
	Freqs[0] = Freqs[1] = Freqs[2] = 0x00;
	
	// PSG Frequencies: [Fatal Fury]
	//	160E2C	DA2D 0008		ADD.B	$08(A5), D5
	//	160E30	0245 007F		ANDI.W	#$7F ,D5
	//	160E34	E34D			LSL.W	#1, D5
	//	160E36	41FA 013C		LEA		PSGFreqs(pc), A0
	//	160E3A	3B70 5000 0010	MOVE.W	$00(A0, D5.w), $10(A5)
	// PSG Frequencies: [MJ's Moonwalker]
	//	0610BE	DA2B 0008		ADD.B	$08(A3), D5
	//	0610C2	0245 007F		ANDI.W	#$7F, D5
	//	0610C6	E30D			LSL.B	#1, D5
	//	0610C8	41F9 0006 11F6	LEA		(PSGFreqs).l, A0
	//	0610CE	3830 5000		MOVE.W	$00(A0,D5.w), D4
	//	0610D2	3744 0010		MOVE.W	D4, $10(A3)
	// FM Frequencies: [Sonic 1]
	//	071D28	DA2D 0008		ADD.B	$08(A5), D5
	//	071D2C	0245 007F		ANDI.W	#$7F, D5
	//	071D30	E34D			LSL.W	#1, D5
	//	071D32	41FA 0A5C		LEA		FMFreqs(pc), A0
	//	071D36	3C30 5000		MOVE.W	$00(A0,D5.w), D6
	
	BasePos = 0x00;
	while(1)
	{
		CurPos = ScanForData2_WC(sizeof(PSG_FREQS), PSG_FREQS, BasePos);
		if (! CurPos)
			break;
		
		BasePos = (CurPos + sizeof(PSG_FREQS)) & ~0x01;	// ensure even byte offset
		CurPos = ReadLEA(ROMData, BasePos);
		if ((ROMData[BasePos + 0x01] & 0x03) == 0x01)	// skip LEA command
			BasePos += 0x06;
		else
			BasePos += 0x04;
		if (ROMData[BasePos] == 0x3C)
			Freqs[1] = CurPos;	// handle Sonic 1 FM freqs
		else
			Freqs[0] = CurPos;	// handle PSG freqs
	}
	
	// FM Frequencies: [Fatal Fury]
	//	1601BA	DA2D 0008		ADD.B	$08(A5), D5
	//  Ristar--4EB9-000C-8B32--JSR-----(DoExtraTranspose).l
	//	1601BE	0285 0000 007F	ANDI.L	#$7F, D5
	//	1601C4	8AFC 000C		DIVU.W	#12, D5
	//	1601C8	4845			SWAP	D5
	//	1601CA	E34D			LSL.W	#1, D5
	//	1601CC	41FA 0BE6		LEA		FMFreqs(pc), A0
	//	1601D0	3C30 5000		MOVE.W	$00(A0,D5.w), D6
	// FM Frequencies: [Shadow Squadron 32X]
	//	0C03BC	DA2D 0008		ADD.B	$08(A5), D5
	//	0C03C0	0605 0020		ADDI.B	#$20, D5
	//	0C03C4	0285 0000 007F	ANDI.L	#$7F, D5
	//	0C03CA	0405 0020		SUBI.B	#$20, D5
	//	0C03CE	E34D			LSL.W	#1, D5
	//	0C03D0	41FA 093A		LEA		FMFreqs(pc), A0
	//	0C03D4	3C30 5000		MOVE.W	$00(A0,D5.w), D6
	// FM Frequencies: [MJ's Moonwalker]
	//	06038A	DA2B 0008		ADD.B	$08(A3), D5
	//	06038E	0285 0000 00FF	ANDI.L	#$FF, D5
	//	060394	8AFC 000C		DIVU.W	#12, D5
	//	060398	2005			MOVE.L	D5, D0
	//	06039A	E088			LSR.L	#8, D0
	//	06039C	E088			LSR.L	#8, D0
	//	06039E	E388			LSL.L	#1, D0
	//	0603A0	41F9 0006 1024	LEA		(FMFreqs).l, A0
	//	0603A6	3230 0000		MOVE.W	$00(A0,D0.w), D1
	BasePos = 0x00;
	CurPos = ScanForData2_WC(sizeof(FM_FREQS), FM_FREQS, 0x00);
	if (CurPos)
		BasePos = CurPos + sizeof(FM_FREQS);
	if (! BasePos)
	{
		// Try it again without the first instruction (-> Ristar)
		CurPos = ScanForData2_WC(sizeof(FM_FREQS) - 0x04, &FM_FREQS[0x04], 0x00);
		if (CurPos)
			BasePos = CurPos + sizeof(FM_FREQS) - 0x04;
	}
	if (! BasePos)
	{
		CurPos = ScanForData2(sizeof(FM_FREQS_SSQUAD), FM_FREQS_SSQUAD, 0x00);
		if (CurPos)
			BasePos = CurPos + sizeof(FM_FREQS_SSQUAD);
	}
	if (BasePos)
	{
		for (CurPos = 0x00; CurPos < 0x20; CurPos += 0x02)
		{
			if (ROMData[BasePos + CurPos] == 0x41)
				break;
		}
		BasePos += CurPos;
		if (ROMData[BasePos] == 0x41)
			Freqs[1] = ReadLEA(ROMData, BasePos);
	}
	
	// FM3 Frequencies: [Fatal Fury]
	//	161460	7003		MOVEQ	#3, D0
	//	161462	7200		MOVEQ	#0, D1
	//	161464	121C		MOVE.B	(A4)+, D1
	//	161466	E349		LSL.W	#1, D1
	//	161468	30FB 1010	MOVE.W	FM3_FreqVals(pc,D1.w), (A0)+
	//	16146C	51C8 FFF4	DBRA	D0, loc_161462
	CurPos = ScanForData2(sizeof(FM3_FREQS_LATE), FM3_FREQS_LATE, 0x00);
	if (CurPos)
	{
		BasePos = (CurPos + sizeof(FM3_FREQS_LATE)) & ~0x01;	// ensure even byte offset
		Freqs[2] = ReadLEA(ROMData, BasePos);
	}
	
	printf("PSG Frequencies: %06X\n", Freqs[0]);
	if (Freqs[0])
	{
		FreqCnt[0] = ParseFreqTable(&Freqs[0], 0x00);
		if (Freqs[0] == Freqs[1])
			FreqCnt[0] = 0x00;	// PSG frequencies were probably omitted
		else
			LimitArrayCount(&FreqCnt[0], 0x02, Freqs[0], Freqs[1]);	// ensure that FM and PSG freqs don't overlap
		printf("    %02X frequencies:\n", FreqCnt[0]);
		PrintFreqTable(&ROMData[Freqs[0]], FreqCnt[0], 0);
	}
	printf("FM Frequencies: %06X\n", Freqs[1]);
	if (Freqs[1])
	{
		FreqCnt[1] = ParseFreqTable(&Freqs[1], 0x01);
		LimitArrayCount(&FreqCnt[0], 0x02, Freqs[1], Freqs[0]);
		printf("    %02X frequencies:\n", FreqCnt[1]);
		PrintFreqTable(&ROMData[Freqs[1]], FreqCnt[1], 1);
	}
	printf("FM3 Frequencies: %06X\n", Freqs[2]);
	if (Freqs[2])
	{
		FreqCnt[2] = ParseFreqTable(&Freqs[2], 0x02);
		printf("    %02X frequencies:\n", FreqCnt[2]);
		PrintFreqTable(&ROMData[Freqs[2]], FreqCnt[2], 2);
	}
	printf("\n");
	
	return;
}

static UINT16 ParseFreqTable(UINT32* Offset, UINT8 Mode)
{
	UINT16 LastFreq;
	UINT16 NewFreq;
	UINT32 CurPos;
	
	NewFreq = ReadLE16(&ROMData[*Offset]);
	if (! NewFreq && Mode <= 0x01)
	{
		// preSMPS with 0-frequency at the beginning - skip that one
		*Offset += 0x02;
	}
	
	CurPos = *Offset;
	LastFreq = ReadBE16(&ROMData[CurPos]);	CurPos += 0x02;
	if (! Mode)
	{
		// Mode 00 - falling frequencies (PSG)
		for (; CurPos < ROMLength; CurPos += 0x02)
		{
			NewFreq = ReadBE16(&ROMData[CurPos]);
			// SMPS 68k/Pico uses redundant frequencies *sigh*
			//if (NewFreq > LastFreq)
			//	break;	// frequencies must be falling, stop when they rise
			if (NewFreq >= 0x0400)
				break;	// break on out-of-range frequency
			LastFreq = NewFreq;
		}
	}
	else
	{
		// Mode 01 - rising frequencies (FM)
		for (; CurPos < ROMLength; CurPos += 0x02)
		{
			NewFreq = ReadBE16(&ROMData[CurPos]);
			if (NewFreq < LastFreq)
				break;	// frequencies must be rising
			if (NewFreq >= 0x4000)
				break;	// break on out-of-range frequency
			if (ROMData[CurPos] == 0xCD && ROMData[CurPos + 0x03] == 0xCC)
				break;	// fix detection for "Flicky"
			if (LastFreq && /*! ((LastFreq ^ NewFreq) & 0x3800) &&*/ LastFreq + 0x0900 < NewFreq)
				break;	// break when gap between frequencies or more than (1 octave + 0x100)
			if (LastFreq != NewFreq && LastFreq > NewFreq - 0x20)
				break;
			if (LastFreq && LastFreq == NewFreq)
			{
				CurPos -= 0x02;	// 2 times the same frequency should be wrong (catch Music Bank table in Sonic 3)
				break;
			}
			LastFreq = NewFreq;
		}
	}
	
	return (CurPos - *Offset) / 0x02;
}

static void LimitArrayCount(UINT16* Count, UINT8 ItmSize, UINT32 ArrPos, UINT32 OtherPos)
{
	UINT16 NewCnt;
	
	if (ArrPos < OtherPos)
	{
		NewCnt = (OtherPos - ArrPos) / ItmSize;
		if (NewCnt < *Count)
			*Count = NewCnt;
	}
	
	return;
}

static void PrintFreqTable(const UINT8* Data, UINT16 FreqCnt, UINT8 Mode)
{
	// Mode: 0 - PSG, 1 - FM, 2 - FM3
	UINT16* FreqArr;
	UINT16 CurIdx;
	UINT16 DigitCnt;
	const char* FreqName;
	
	if (FreqCnt)
	{
		FreqArr = (UINT16*)malloc(FreqCnt * sizeof(UINT16));
		DigitCnt = 3;
		for (CurIdx = 0x00; CurIdx < FreqCnt; CurIdx ++)
		{
			FreqArr[CurIdx] = ReadBE16(&Data[CurIdx * 0x02]);
			if (FreqArr[CurIdx] >= 0x1000)
				DigitCnt = 4;
		}
		
		for (CurIdx = 0x00; CurIdx < FreqCnt; CurIdx ++)
		{
			if (! (CurIdx % 12))
			{
				if (CurIdx)
					printf("\n");
				printf("\t");
			}
			else
			{
				//printf(", ");
				printf(" ");
			}
			printf("$%0*X", DigitCnt, FreqArr[CurIdx]);
		}
		printf("\n");
	}
	else
	{
		printf("\t-\n");
	}
	
	FreqName = NULL;
	switch(Mode)
	{
	case 0x00:	// PSG
		if (FreqCnt == DEF_PSGFREQ_PRE_CNT &&
			! memcmp(FreqArr, DEF_PSGFREQ_PRE_VAL, DEF_PSGFREQ_PRE_CNT * sizeof(UINT16)))
			FreqName = "DEF_PRE";
		else if (FreqCnt == DEF_PSGFREQ_68K_CNT &&
			! memcmp(FreqArr, DEF_PSGFREQ_68K_VAL, DEF_PSGFREQ_68K_CNT * sizeof(UINT16)))
			FreqName = "DEF_68K";
		else if (FreqCnt == DEF_PSGFREQ_Z80_T1_CNT &&
			! memcmp(FreqArr, DEF_PSGFREQ_Z80_T1_VAL, DEF_PSGFREQ_Z80_T1_CNT * sizeof(UINT16)))
			FreqName = "DEF_Z80_T1";
		else if (FreqCnt == DEF_PSGFREQ_Z80_T2_CNT &&
			! memcmp(FreqArr, DEF_PSGFREQ_Z80_T2_VAL, DEF_PSGFREQ_Z80_T2_CNT * sizeof(UINT16)))
			FreqName = "DEF_Z80_T2";
		
		if (FreqName != NULL)
			printf("\t-> %s: %s\n", "PSG", FreqName);
		break;
	case 0x01:	// FM
		if (FreqCnt == 12)
		{
			// test for FM frequencies
			if (! memcmp(FreqArr, DEF_FMFREQ_68K_VAL, 12 * sizeof(UINT16)))
				FreqName = "DEF_68K";
			else if (! memcmp(FreqArr, DEF_FMFREQ_Z80_VAL, 12 * sizeof(UINT16)))
				FreqName = "DEF_Z80";
		}
		
		if (FreqName != NULL)
			printf("\t-> %s: %s\n", "FM", FreqName);
		break;
	case 0x02:	// FM3
		if (FreqCnt == DEF_FM3FREQ_68K_CNT &&
			! memcmp(FreqArr, DEF_FM3FREQ_68K_VAL, DEF_FM3FREQ_68K_CNT * sizeof(UINT16)))
			FreqName = "usual 68k";
		if (FreqCnt == DEF_FM3FREQ_Z80_T1_CNT &&
			! memcmp(FreqArr, DEF_FM3FREQ_Z80_T1_VAL, DEF_FM3FREQ_Z80_T1_CNT * sizeof(UINT16)))
			FreqName = "usual Z80 T1";
		else if (FreqCnt == DEF_FM3FREQ_Z80_T1_CNT &&
			! memcmp(FreqArr, DEF_FM3FREQ_Z80_T1_VAL_B, DEF_FM3FREQ_Z80_T1_CNT * sizeof(UINT16)))
			FreqName = "Z80 T1, SegaNet variant";
		else if (FreqCnt == DEF_FM3FREQ_Z80_T2_CNT &&
			! memcmp(FreqArr, DEF_FM3FREQ_Z80_T2_VAL, DEF_FM3FREQ_Z80_T2_CNT * sizeof(UINT16)))
			FreqName = "usual Z80 T2";
		
		if (FreqName != NULL)
			printf("\t-> %s: %s\n", "FM3", FreqName);
		break;
	}
	
	return;
}



static void ShowChannelMask(void)
{
	// FM/PSG Channel Mask: [Fatal Fury]
	//	16067E	45FA 0114		LEA		InitBytes(pc), A2
	//	160682	1283			MOVE.B	D3, (A1)
	//	160684	135A 0001		MOVE.B	(A2)+, $01(A1)
	//	160688	1344 0002		MOVE.B	D4, $02(A1)
	const UINT8 CHMASK_LATE[] = {0x12, 0x83, 0x13, 0x5A, 0x00, 0x01, 0x13, 0x44, 0x00, 0x02};
	// FM/PSG Channel Mask: [Sonic 1]
	//	072098	45FA 0124		LEA		InitBytes(pc), A2
	//	07209C	08D1 0007		BSET	#7, (A1)
	//	0720A0	135A 0001		MOVE.B	(A2)+, $01(A1)
	//	0720A4	1344 0002		MOVE.B	D4, $02(A1)
	const UINT8 CHMASK_LATE2[] = {0x08, 0xD1, 0x00, 0x07, 0x13, 0x5A, 0x00, 0x01, 0x13, 0x44, 0x00, 0x02};
	// FM/PSG Channel Mask: [MJ's Moonwalker]
	//	060A50	45F9 0006 0B36	LEA		(InitBytes).l, A2
	//	060A56	137C 0001 000E	MOVE.B	#1, $0E(A1)
	//	060A5A	137C 00C0 000A	MOVE.B	#$C0, $0A(A1)
	//	060A5E	137C 0030 000D	MOVE.B	#$30, $0D(A1)
	const UINT8 CHMASK_EARLY[] = {
		0x13, 0x7C, 0x00, 0x01, 0x00, 0x0E,
		0x13, 0x7C, 0x00, 0xC0, 0x00, 0x0A,
		0x13, 0x7C, 0x00, 0x30, 0x00, 0x0D};
	// FM/PSG Channel Mask: [Mickey no Boku wa Meitantei (Sega Pico)]
	//	0B09FA	45FA 0082	LEA		FMInitBytes(pc), A2
	//	0B09FE	0811 0002	BTST	#2, (A1)
	//	0B0A02	6706		BEQ.S	loc_B0A0A
	//	0B0A04	12BC 0084	MOVE.B	#$84, (A1)
	//	0B0A08	6002		BRA.S	loc_B0A0C
	const UINT8 CHMASK_PICO[] = {
		0x08, 0x11, 0x00, 0x02, 0x67, 0x06, 0x12, 0xBC, 0x00, 0x84, 0x60, 0x02};	
	const CHMASK_DATA CHMASK_DRVS[4] = {
		{CHMASK_LATE, sizeof(CHMASK_LATE), 0x01, 0},
		{CHMASK_LATE2, sizeof(CHMASK_LATE2), 0x01, 0},
		{CHMASK_EARLY, sizeof(CHMASK_EARLY), 0x02, 0},
		{CHMASK_PICO, sizeof(CHMASK_PICO), 0x01, 0}};
	
#define CHNMASK_CNT	4
	const char* CHNFMT_STR[3] = {"not found", "default", "early"};
	const char* CHN_STR[CHNMASK_CNT] = {"FM", "PSG", "PWM", "Unknown"};
	UINT32 ChnMask[CHNMASK_CNT];	// 0 - FM, 1 - PSG
	UINT16 ChnCount[CHNMASK_CNT];
	UINT8 Mode;
	
	UINT8 CurDrv;
	UINT8 CurChn;
	UINT8 ChnVal;
	UINT16 CurInst;
	UINT32 BasePos;
	UINT32 CurPos;
	const CHMASK_DATA* TempDrv;
	
	for (CurChn = 0; CurChn < CHNMASK_CNT; CurChn ++)
		ChnMask[CurChn] = 0x00;
	
	Mode = 0x00;
	for (CurDrv = 0; CurDrv < 4; CurDrv ++)
	{
		TempDrv = &CHMASK_DRVS[CurDrv];
		BasePos = 0x00;
		for (CurChn = 0; CurChn < CHNMASK_CNT; CurChn ++)
		{
			CurPos = ScanForData2(TempDrv->Size, TempDrv->Data, BasePos);
			if (! CurPos)
				break;
			BasePos = CurPos + TempDrv->Size;
			CurPos -= 0x04;
			if (ROMData[CurPos] != 0x45)
			{
				CurPos -= 0x02;
				if (ROMData[CurPos] != 0x45)
					break;
			}
			ChnMask[CurChn] = ReadLEA(ROMData, CurPos);
			Mode = TempDrv->Mode;
		}
		if (Mode)
			break;
	}
	printf("Channel Mask Format: %s\n", CHNFMT_STR[Mode]);
	if (! Mode)
		return;
	
	for (CurChn = 0; CurChn < CHNMASK_CNT; CurChn ++)
	{
		if (! ChnMask[CurChn])
			break;
		
		FixMarsPointer(&ChnMask[CurChn]);
		BasePos = ChnMask[CurChn];
		CurPos = GetNextPtr(CHNMASK_CNT, ChnMask, BasePos);
		if (! CurPos || CurPos - BasePos > 0x10)
		{
			for (CurPos = BasePos; CurPos < ROMLength; CurPos += 0x02)
			{
				CurInst = ReadBE16(&ROMData[CurPos]);
				if ((CurInst & 0xFFFC) == 0x41F8)	// LEA SFXPtrs, A0 [usual SMPS 68k]
					break;
				if (CurInst == 0xE548)	// LSL.W	#2, D0 [early SMPS 68k Type 1]
					break;
				if (CurInst == 0x0C07)	// ??? [Alien Soldier]
					break;
				if (CurInst == 0x2079)	// ??? [Crayon Shin-Chan]
					break;
				if (CurInst == 0x4A2E)	// TST.B	$27(A6) [Sonic 1]
					break;
				if (CurInst == 0x1D7C)	// ??? [Metal Head 32X]
					break;
			}
			/*for (CurPos = BasePos; CurPos < ROMLength; CurPos ++)
			{
				if (ROMData[CurPos] & 0x80)
				{
					if (ROMData[CurPos] & 0x1F)
						break;
				}
				else
				{
					if (ROMData[CurPos] & 0x68)
						break;
				}
			}*/
		}
		if (ROMData[CurPos - 1] == 0x00)
			CurPos --;	// remove alignment
		ChnCount[CurChn] = CurPos - BasePos;
		if (ChnCount[CurChn] > 0x10)
			ChnCount[CurChn] = 0x10;
	}
	
	for (CurChn = 0; CurChn < CHNMASK_CNT; CurChn ++)
	{
		if (! ChnMask[CurChn])
			break;
		
		BasePos = ChnMask[CurChn];
		printf("%s Channels (%06X):", CHN_STR[CurChn], BasePos);
		if (Mode == 0x01)
		{
			for (CurPos = 0x00; CurPos < ChnCount[CurChn]; CurPos ++)
				printf(" %X", ROMData[BasePos + CurPos]);
		}
		else
		{
			ChnVal = 0x00;
			for (CurPos = 0x00; CurPos < ChnCount[CurChn]; CurPos ++)
			{
				ChnVal += ROMData[BasePos + CurPos];
				printf(" %X", ChnVal);
			}
		}
		
		printf(" (count: %u)\n", ChnCount[CurChn]);
	}
	printf("\n");
	
	return;
}


static void CoordFlagAnalysis(void)
{
	const UINT8 CFHANDLE_LATE[] = {
		0x04, 0x45, 0x00, 0xE0,
		0xE5, 0x4D, 0x4E, 0xFB, 0x50, 0x02};
	const UINT8 CFMETA_LATE[] = {
		0x70, 0x00, 0x10, 0x1C, 0xE5, 0x48, 0x4E, 0xFB, 0x00, 0x02};
	const UINT8 CFHANDLE_EARLY[] = {
		0x04, 0x05, 0x00, 0xE0,
		0x02, 0x45, 0x00, 0xFF,
		0xE5, 0x4D, 0x4E, 0xFB, 0x50, 0x02};
	const UINT8 CFHANDLE_BGYUI[] = {
		0x04, 0x05, 0x00, 0xE0,
		0x02, 0x45, 0x00, 0xFF,
		0xCA, 0xFC, 0x00, 0x06,
		0x4E, 0xFB, 0x50, 0x02};
	const UINT8 CFMETA_BGYUI[] = {
		0x1A, 0x1C,
		0x02, 0x45, 0x00, 0xFF,
		0xCA, 0xFC, 0x00, 0x06,
		0x4E, 0xFB, 0x50, 0x02};
	
#define MAX_CF	0x40
	UINT32 CFHandler;
	UINT32 CFHandlerEnd;
	UINT32 JmpSize;
	UINT32 CFPtrList[2];
	UINT16 CFPtrCnt[2];
	UINT32 CFPtrs[MAX_CF + 3];
	CF_INFO CFInfo[MAX_CF];
	
	UINT32 CurPos;
	UINT32 MaxPos;
	UINT32 NextPtr;
	UINT8 CurCF;
	UINT16 CurInst;
	
	CFHandler = CFHandlerEnd = 0x00;
	
	// cfHandler: [Fatal Fury]
	//	161000	0445 00E0	SUBI.W	#$E0, D5
	//	161004	E54D		LSL.W	#2, D5
	//	161006	4EFB 5002	JMP		cfJumpTable(PC,D5.w)
	//	16100A	6000 0098	BRA.W	cfE0_Pan
	// cfHandler: [MJ's Moonwalker]
	//	061282	0405 00E0	SUBI.B	#$E0, D5
	//	061286	0245 00FF	ANDI.W	#$FF, D5
	//	06128A	E54D		LSL.W	#2, D5
	//	06128C	4EFB 5002	JMP		cfJumpTable(PC,D5.w)
	//	060190	6000 007A	BRA.W	cfE0_Pan
	
	// Special Case:
	// cfHandler: [Battle Golfer Yui]
	//	076C42	0405 00E0		SUBI.B	#$E0, D5
	//	076C46	0245 00FF		ANDI.W	#$FF, D5
	//	076C4A	CAFC 0006		MULU.W	#6, D5
	//	076C4E	4EFB 5002		JMP		cfJumpTable(PC,D5.w)
	//	076C52	4EF9 0007 6D44	BRA.W	cfE0_Pan
	CurPos = ScanForData2(sizeof(CFHANDLE_LATE), CFHANDLE_LATE, 0x00);
	if (CurPos)
	{
		CFHandler = CurPos;
		CFPtrList[0] = CurPos + sizeof(CFHANDLE_LATE);
		JmpSize = 0x04;
	}
	if (! CurPos)
	{
		CurPos = ScanForData2(sizeof(CFHANDLE_EARLY), CFHANDLE_EARLY, 0x00);
		if (CurPos)
		{
			CFHandler = CurPos;
			CFPtrList[0] = CurPos + sizeof(CFHANDLE_EARLY);
			JmpSize = 0x04;
		}
	}
	if (! CurPos)
	{
		CurPos = ScanForData2(sizeof(CFHANDLE_BGYUI), CFHANDLE_BGYUI, 0x00);
		if (CurPos)
		{
			CFHandler = CurPos;
			CFPtrList[0] = CurPos + sizeof(CFHANDLE_BGYUI);
			JmpSize = 0x06;
		}
	}
	printf("Coordination Flag Handler: %06X\n", CFHandler);
	if (! CFHandler)
		return;
	
	// I need to do the detection itself to be able to guess the command flag handler size.
	//if (! AnalyseCF)
	//	return;
	
	//CFPtrList[0] is already set;
	CFPtrList[1] = 0x0000;
	CFPtrCnt[0] = CFPtrCnt[1] = 0x00;
	
	for (CurCF = 0x00; CurCF < MAX_CF; CurCF ++)
	{
		CFInfo[CurCF].Ptr = 0x0000;
		CFInfo[CurCF].Size = 0x0000;
		CFInfo[CurCF].Name = NULL;
		CFInfo[CurCF].Desc = NULL;
	}
	
	CurPos = CFPtrList[0];
	MaxPos = ROMLength;
	NextPtr = MaxPos;
	for (CurCF = 0x00; CurCF < 0x20; CurCF ++, CurPos += JmpSize)
	{
		if (CurPos >= MaxPos)
			break;
		
		CurInst = ReadBE16(&ROMData[CurPos + 0x00]);
		if (CurInst == 0x6000)	// check for BRA.W
			CFPtrs[CurCF] = CurPos + 0x02 + ReadBE16(&ROMData[CurPos + 0x02]);
		else if ((CurInst & 0xFFF8) == 0x4EF8)
			CFPtrs[CurCF] = ReadLEA(ROMData, CurPos);
		else
			CFPtrs[CurCF] = CurPos;
		if (CFPtrs[CurCF] < MaxPos && CFPtrs[CurCF] >= CFPtrList[0])
		{
			NextPtr = MaxPos;		// make a backup of the old MaxPos
			MaxPos = CFPtrs[CurCF];	// remember smallest pointer to be able to terminate the CF list early
		}
		CFInfo[CurCF].Ptr = CFPtrs[CurCF];
		
		//	cfMetaCoordFlag: [Fatal Fury]
		//	161086	7000		MOVEQ	#0, D0
		//	161088	101C		MOVE.B	(A4)+, D0
		//	16108A	E548		LSL.W	#2, D0
		//	16108C	4EFB 0002	JMP	cfMetaJumpTable(PC,D0.w)
		if (! memcmp(&ROMData[CFPtrs[CurCF]], CFMETA_LATE, sizeof(CFMETA_LATE)))
		{
			CFPtrList[1] = CFPtrs[CurCF] + sizeof(CFMETA_LATE);
			CFInfo[CurCF].Name = "cfMetaCoordFlag";	// "MetaCF"
		}
		else if (! memcmp(&ROMData[CFPtrs[CurCF]], CFMETA_BGYUI, sizeof(CFMETA_BGYUI))) 
		{
			CFPtrList[1] = CFPtrs[CurCF] + sizeof(CFMETA_BGYUI);
			CFInfo[CurCF].Name = "cfMetaCoordFlag";	// "MetaCF"
		}
	}
	CFPtrCnt[0] = CurCF;
	for (; CurCF < 0x20; CurCF ++)
		CFPtrs[CurCF] = 0x0000;
	
	if (CFPtrList[1])
	{
		CurPos = CFPtrList[1];
		// continue using the old MaxPos, if possible
		if (MaxPos < CurPos)
			MaxPos = NextPtr;
		if (MaxPos < CurPos)
			MaxPos = ROMLength;	// I'd use CFHandlerEnd, but that isn't set yet.
		for (CurCF = 0x20; CurCF < MAX_CF; CurCF ++, CurPos += JmpSize)
		{
			if (CurPos >= MaxPos)
				break;
			
			CurInst = ReadBE16(&ROMData[CurPos + 0x00]);
			if (CurInst == 0x6000)	// check for BRA.W
				CFPtrs[CurCF] = CurPos + 0x02 + ReadBE16(&ROMData[CurPos + 0x02]);
			else if ((CurInst & 0xFFF8) == 0x4EF8)
				CFPtrs[CurCF] = ReadLEA(ROMData, CurPos);
			else
				CFPtrs[CurCF] = CurPos;
			if (CFPtrs[CurCF] < MaxPos && CFPtrs[CurCF] >= CFPtrList[1])
				MaxPos = CFPtrs[CurCF];	// remember smallest pointer to be able to terminate the CF list early
			CFInfo[CurCF].Ptr = CFPtrs[CurCF];
		}
		CFPtrCnt[1] = CurCF;
	}
	for (; CurCF < MAX_CF; CurCF ++)
		CFPtrs[CurCF] = 0x0000;
	
	MaxPos = 0x00;
	for (CurCF = 0; CurCF < MAX_CF; CurCF ++)
	{
		if (MaxPos < CFPtrs[CurCF])
			MaxPos = CFPtrs[CurCF];
	}
	CFHandlerEnd = FindRoutineEnd(MaxPos);
	printf("cfHandler End: %06X\n", CFHandlerEnd);
	if (! CFHandlerEnd)
		CFHandlerEnd = ROMLength;
	printf("Coord. Flag section size: %04X\n", CFHandlerEnd - CFHandler);
	printf("\n");
	if (! AnalyseCF)
		return;
	
	CFPtrs[MAX_CF + 0] = CFHandlerEnd;
	CFPtrs[MAX_CF + 1] = CFPtrList[0];
	CFPtrs[MAX_CF + 2] = CFPtrList[1];
	for (CurCF = 0x00; CurCF < MAX_CF; CurCF ++)
	{
		if (! CFPtrs[CurCF])
			NextPtr = 0x0000;
		else
			NextPtr = GetNextPtr(MAX_CF + 3, CFPtrs, CFPtrs[CurCF]);
		
		if (! NextPtr)
			CFInfo[CurCF].Size = 0x0000;
		else
			CFInfo[CurCF].Size = NextPtr - CFPtrs[CurCF];
		ScanForCFRoutine(&CFInfo[CurCF]);
	}
	
	
	printf("cfPtrTable:\n");
	for (CurCF = 0x00; CurCF < CFPtrCnt[0]; CurCF ++)
	{
		if (CFInfo[CurCF].Ptr)
			PrintCFInfo(&CFInfo[CurCF], 0xE0 + CurCF);
	}
	printf("cfMetaPtrTable:\n");
	for (CurCF = 0x20; CurCF < CFPtrCnt[1]; CurCF ++)
	{
		if (CFInfo[CurCF].Ptr)
			PrintCFInfo(&CFInfo[CurCF], CurCF - 0x20);
	}
	printf("\n");
	
	return;
}

static UINT32 FindRoutineEnd(UINT32 RoutinePos)
{
	UINT32 CurPos;
	UINT16 CurInstr;
	UINT32 DstPos;
	
	CurPos = RoutinePos;
	while(CurPos < ROMLength)
	{
		CurInstr = ReadBE16(&ROMData[CurPos]);
		CurPos += 0x02;
		if (CurInstr == 0x4E75)	// RTS
		{
			break;
		}
		else if ((CurInstr & 0xFFC0) == 0x4EC0)	// JMP
		{
			if (CurInstr < 0x4EF0)	// jump using Ax
				break;
			DstPos = ReadLEA(ROMData, CurPos);
			CurPos += ((CurInstr & 0x003F) == 0x0039) ? 0x04 : 0x02;
			if (DstPos < CurPos)
				break;	// jump backwards - exit
			else
				CurPos = DstPos;	// jump forwards - follow
		}
		else if ((CurInstr & 0xF100) == 0x6000)	// BRA
		{
			if (CurInstr & 0x00FF)
			{
				DstPos = CurPos + (INT8)(CurInstr & 0x00FF);
			}
			else
			{
				DstPos = CurPos + (INT16)ReadBE16(&ROMData[CurPos]);
				CurPos += 0x02;
			}
			if (DstPos < CurPos)
			{
				// jump backwards - exit if BRA
				if ((CurInstr & 0xFE00) == 0x6000)
					break;
			}
			else
			{
				CurPos = DstPos;	// jump forwards - follow
			}
		}
	}
	
	return CurPos;
}

static UINT32 GetNextPtr(UINT16 PtrCount, UINT32* PtrArr, UINT32 MinPtr)
{
	UINT32 ResPtr;
	UINT32 CurPtr;
	
	ResPtr = 0x0000;
	for (CurPtr = 0x00; CurPtr < PtrCount; CurPtr ++)
	{
		if (PtrArr[CurPtr] > MinPtr)	// > is intended (not >=)
		{
			if (ResPtr > PtrArr[CurPtr] || ! ResPtr)
				ResPtr = PtrArr[CurPtr];
		}
	}
	
	return ResPtr;
}

static void ScanForCFRoutine(CF_INFO* CFInf)
{
	UINT8 CurCF;
	CFLAG_LIB* TempCF;
	
	if (CFInf->Name != NULL)
		return;	// MetaCF has already been detected
	
	for (CurCF = 0x00; CurCF < CFLibSize; CurCF ++)
	{
		TempCF = &CmdFlagLib[CurCF];
		if (CFInf->Size && CFInf->Size < TempCF->Size)
			continue;
		
		if (! memcmp_wcAA(&ROMData[CFInf->Ptr], TempCF->Data, TempCF->Size))
		{
			CFInf->Name = TempCF->Name;
			break;
		}
	}
	
	return;
}

static void PrintCFInfo(const CF_INFO* CFInf, UINT8 CFID)
{
	printf("\t%02X: %06X (size %04X)", CFID, CFInf->Ptr, CFInf->Size);
	if (CFInf->Name != NULL)
		printf(" %s", CFInf->Name);
	if (CFInf->Desc != NULL)
		printf(" (%s)", CFInf->Desc);
	printf("\n");
	
	return;
}

static void PrintFadeInfo(void)
{
	// FadeOutMusic routine: [Fatal Fury]
	//	160A68	1D7C 0003 0006		MOVE.B	#$03, $06(A6)
	//	160A6E	1D7C 0028 0004		MOVE.B	#$28, $04(A6)
	//	160A74	422E 0040			CLR.B	$40(A6)		; <--- missing in SMPS 68k/32x
	//	160A78	4E75				RTS
	// FadeOutMusic routine: [MJ's Moonwalker]
	//	060D14	13FC 0003 00FF D306	MOVE.B	#$03, ($FFD306).l
	//	060D1C	13FC 0028 00FF D304	MOVE.B	#$28, ($FFD304).l
	//	060D24	4239 00FF D340		CLR.B	($FFD340).l
	//	060D14	4E75				RTS
	// FadeOutMusic routine: [Dynamite Headdy]
	//	05CC3C	11FC 0003 F806		MOVE.B	#$03, ($FFFFF806).w
	//	05CC42	11FC 0028 F804		MOVE.B	#$28,($FFFFF804).w
	//	05CC48	4238 F840			CLR.B	($FFFFF840).w
	//	05CC4C	4E75				RTS
	// FadeOutMusic_Quick routine: [Ristar]
	//	0C9454	1D7C 0001 002E		MOVE.B	#$01, $2E(A6)
	//	0C945A	1D7C 0001 002D		MOVE.B	#$01, $2D(A6)
	//	0C9460	1D7C 000C 002C		MOVE.B	#$0C, $2C(A6)
	//	0C9466	422E 004A			CLR.B	$4A(A6)
	//	0C946A	422E 007E			CLR.B	$7E(A6)
	//	0C946E	6100 0292			BSR.W	MuteDAC
	//	0C9454	4E75				RTS
	// FadeOutMusic routine: [Shadow Squadron 32X]
	//	160A68	1D7C 0001 002D		MOVE.B	#$01, $2D(A6)
	//	160A6E	1D7C 0018 002B		MOVE.B	#$18, $2B(A6)
	//	160A74	422E 0040			CLR.B	$40(A6)
	//	160A78	4E75				RTS
	// FadeOutMusic routine: [Mickey no Boku wa Meitantei (Sega Pico)]
	//	0B0BBA	1D7C 0010 0005		MOVE.B	#$10, $05(A6)
	//	0B0BC0	1D6E 002A 0007		MOVE.B	$2A(A6), $07(A6)
	//	0B0BC6	6600 0008			BNE.W	$0B0BD0
	//	0B0BCA	1D7C 0003 0007		MOVE.B	#3, 7(A6)
	//	0B0BD0	422E 0040			CLR.B	$40(A6)
	
	// Games known to not work:
	//	- Golden Axe III (custom fading algorithm)
	//	- Ristar (fading values moved, additional checks)
	//	- Shadow Squadron 32X (fading values moved)
	
	// masked out are: the values written, the 2nd low byte of the addresses
	const UINT8 FADE_LATE[] =
	{	0x1D, 0x7C, 0x00, 0xFF, 0x00, 0x06,
		0x1D, 0x7C, 0x00, 0xFF, 0x00, 0x04,
		0x42, 0x2E, 0x00, 0x40};
	const UINT8 FADE_LATE2[] =	// SMPS 68k/Treasure
	{	0x11, 0xFC, 0x00, 0xFF, 0xFF, 0x06,
		0x11, 0xFC, 0x00, 0xFF, 0xFF, 0x04,
		0x42, 0x38, 0xFF, 0x40};
	const UINT8 FADE_LATE3[] =	// SMPS 68k/32x
	{	0x1D, 0x7C, 0x00, 0xFF, 0x00, 0x06,
		0x1D, 0x7C, 0x00, 0xFF, 0x00, 0x04,
		0x4E, 0x75};
	const UINT8 FADE_EARLY[] =
	{	0x13, 0xFC, 0x00, 0xFF, 0x00, 0xFF, 0xFF, 0x06,
		0x13, 0xFC, 0x00, 0xFF, 0x00, 0xFF, 0xFF, 0x04,
		0x42, 0x39, 0x00, 0xFF, 0xFF, 0x40};
	const UINT8 FADE_PICO[] =
	{	0x1D, 0x7C, 0x00, 0xFF, 0x00, 0x05,
		0x1D, 0x6E, 0x00, 0xFF, 0x00, 0x07, 0x66, 0x00, 0x00, 0x08,
		0x1D, 0x7C, 0x00, 0xFF, 0x00, 0x07,
		0x42, 0x2E, 0x00, 0x40};
	const CHMASK_DATA CHMASK_DRVS[5] = {
		{FADE_LATE, sizeof(FADE_LATE), 0x06, 0x05},
		{FADE_LATE2, sizeof(FADE_LATE2), 0x06, 0x05},
		{FADE_LATE3, sizeof(FADE_LATE3), 0x06, 0x05},
		{FADE_EARLY, sizeof(FADE_EARLY), 0x08, 0x07},
		{FADE_PICO, sizeof(FADE_PICO), 0x06+0x06+0x04, 0x05}};
	
	UINT32 BasePos;
	UINT32 CurPos;
	UINT8 CurDrv;
	const CHMASK_DATA* TempDrv;
	UINT8 FadeFound;
	UINT8 CurFade;
	UINT8 FadeArr[2][2];
	UINT8 FadeStp;
	UINT8 FadeDly;
	
	FadeFound = 0x00;
	for (CurDrv = 0; CurDrv < 5; CurDrv ++)
	{
		TempDrv = &CHMASK_DRVS[CurDrv];
		BasePos = 0x00;
		while(1)
		{
			CurPos = ScanForData2_WC(TempDrv->Size, TempDrv->Data, BasePos);
			if (! CurPos)
				break;
			BasePos = CurPos + TempDrv->Size;
			
			for (CurFade = 0; CurFade < 2; CurFade ++)
			{
				FadeArr[CurFade][0] = ROMData[CurPos + 0x03];
				FadeArr[CurFade][1] = ROMData[CurPos + TempDrv->Param2];
				CurPos += TempDrv->Mode;
			}
			if (FadeArr[1][1] < FadeArr[0][1])
				CurFade = 1;
			else
				CurFade = 0;
			
			FadeStp = FadeArr[CurFade ^ 0][0];
			FadeDly = FadeArr[CurFade ^ 1][0];
			
			printf("FadeOut routine found at %06X\n", CurPos);
			printf("\tFadeOutSteps = $%02X\n", FadeStp);
			if (FadeDly < 10)
				printf("\tFadeOutDelay = %u\n", FadeDly);
			else
				printf("\tFadeOutDelay = $%02X\n", FadeDly);
			FadeFound ++;
		}
	}
	if (! FadeFound)
		printf("No fade settings found!\n");
	printf("\n");
	
	return;
}


void ExtractSmpsData(void)
{
	printf("\n");
	
	ShowChannelMask();
	DumpPanAnimation();
	ShowFrequencies();
	PrintFadeInfo();
	CoordFlagAnalysis();
	
	return;
}


void DumpFile(const char* Title, const char* Ext, UINT32 DataLen, const UINT8* Data)
{
	FILE* hFile;
	char FileName[0x200];
	
	if (ReadMode)
		return;
	
	if (Ext == NULL)
		Ext = "bin";
	if (UseBaseName)
		sprintf(FileName, "%s%s_%s.%s", FileBase, FileTitle, Title, Ext);
	else
		sprintf(FileName, "%s%s.%s", FileBase, Title, Ext);
	hFile = fopen(FileName, "wb");
	if (hFile == NULL)
	{
		printf("Error opening file %s!\n", FileName + strlen(FileBase));
		return;
	}
	
	fwrite(Data, 0x01, DataLen, hFile);
	
	fclose(hFile);
	
	return;
}


UINT32 ScanForData2(UINT32 DataLen, const UINT8* Data, UINT32 StartPos)
{
	UINT32 CurPos;
	
	//printf("Trying to search for Music Pointer List ...");
	for (CurPos = StartPos; CurPos < ROMLength - DataLen; CurPos += 0x02)
	{
		if (! memcmp(ROMData + CurPos, Data, DataLen))
		{
			//printf("  found at %06X\n", CurPos);
			return CurPos;
		}
	}
	//printf("  not found.\n");
	
	return 0x00;
}

UINT32 ScanForData2_WC(UINT32 DataLen, const UINT8* Data, UINT32 StartPos)
{
	// wildcard version
	UINT32 CurPos;
	
	for (CurPos = StartPos; CurPos < ROMLength - DataLen; CurPos += 0x02)
	{
		if (! memcmp_wc(ROMData + CurPos, Data, DataLen))
			return CurPos;
	}
	
	return 0x00;
}

static INT8 memcmp_wc(const UINT8* data, const UINT8* compare, UINT32 count)
{
	while(count)
	{
		if (*compare != 0xFF)
		{
			if (*data < *compare)
				return -1;
			else if (*data > *compare)
				return +1;
		}
		
		data ++;	compare ++;
		count --;
	}
	
	return 0;
}

static INT8 memcmp_wcAA(const UINT8* data, const UINT8* compare, UINT32 count)
{
	while(count)
	{
		if (*compare != 0xAA)
		{
			if (*data < *compare)
				return -1;
			else if (*data > *compare)
				return +1;
		}
		
		data ++;	compare ++;
		count --;
	}
	
	return 0;
}


static UINT16 ReadBE16(const UINT8* Data)
{
	return (Data[0x00] << 8) | (Data[0x01] << 0);
}

static UINT32 ReadBE32(const UINT8* Data)
{
	return	(Data[0x00] << 24) | (Data[0x01] << 16) |
			(Data[0x02] <<  8) | (Data[0x03] <<  0);
}

static UINT32 ReadBE24(const UINT8* Data)
{
	return	(Data[0x01] << 16) |
			(Data[0x02] <<  8) | (Data[0x03] <<  0);
}

static UINT16 ReadLE16(const UINT8* Data)
{
	return (Data[0x01] << 8) | (Data[0x00] << 0);
}

static UINT32 ReadLEA(const UINT8* Code, UINT32 InstPos)
{
	UINT8 LeaMode;
	UINT32 TempPtr;
	
	LeaMode = Code[InstPos + 0x01];
	InstPos += 0x02;
	
	// allowed are MOVE.x (78..7B) and LEA (F8..FB)
	if ((LeaMode & 0x7C) == 0x78)
	{
		switch(LeaMode & 0x03)
		{
		case 0x00:	// LEA	addr.w, Ax
			return (INT16)ReadBE16(&Code[InstPos]) & 0xFFFFFF;
		case 0x01:	// LEA	addr.l, Ax
			TempPtr = ReadBE32(&Code[InstPos]) & 0xFFFFFF;
			FixMarsPointer(&TempPtr);
			return TempPtr;
		case 0x02:	// LEA	addr(PC), Ax
			return InstPos + (INT16)ReadBE16(&Code[InstPos]);
		case 0x03:	// LEA	addr(PC, Dx.w), Ax
			return InstPos + (INT8)Code[InstPos + 0x01];
		}
	}
	
	return 0x00;
}

static void FixMarsPointer(UINT32* ROMPos)
{
	if (! MarsMode)
		return;
	
	switch(*ROMPos & 0xF80000)
	{
	//case 0x480000:
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
