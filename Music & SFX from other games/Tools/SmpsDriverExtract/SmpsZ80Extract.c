// SMPS Z80 Data Extractor
// -----------------------
// Written by Valley Bell, April 2014

#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <memory.h>
#include <string.h>
#include "stdtype.h"


#ifndef INLINE
#if defined(_MSC_VER)
#define INLINE	static __inline
#elif defined(__GNUC__)
#define INLINE	static __inline__
#else
#define INLINE	static inline
#endif
#endif

#ifndef _MSC_VER
#define _stricmp	strcasecomp
#endif


typedef struct _smps_drum_header
{
	char Signature[0x04];
	UINT8 Type;
	UINT8 DrmCount;
	UINT16 DrmListOfs;
	UINT16 DrmListBase;
	UINT8 reserved;
	UINT8 InsCount;
	UINT16 InsListOfs;
	UINT16 InsListBase;
} SDRUM_HEADER;

typedef struct _pan_ani_header
{
	char Signature[0x04];
	UINT8 Type;
	UINT8 AniCount;
	UINT16 AniListOfs;
	UINT16 AniListBase;
	UINT8 Padding[0x06];
} PANI_HEADER;

typedef struct _coord_flag_info
{
	UINT16 Ptr;
	UINT16 Size;
	const char* Name;
	const char* Desc;
} CF_INFO;

UINT8 KDecomp(UINT32 SrcSize, const UINT8* SrcData, UINT32* RetDstSize, UINT8** RetDstData, UINT8 Moduled);

int main(int argc, char* argv[]);
void OpenROMFile(const char* FileName);

static void DumpDrumData(void);
static void DumpDrumFile(UINT8 Type, UINT32 StartOfs, UINT32 InsOfs, UINT32 EndOfs);

static void DumpPanAnimation(void);
static void DumpPanAniFile(UINT8 Type, UINT32 StartOfs, UINT16 AniCnt, UINT32 EndOfs);

static void ShowModulationBug(void);

static void ShowFrequencies(void);
static UINT16 ParseFreqTable(UINT16* Offset, UINT8 Mode);
static void LimitArrayCount(UINT16* Count, UINT8 ItmSize, UINT16 ArrPos, UINT16 OtherPos);
static void PrintFreqTable(const UINT8* Data, UINT16 FreqCnt, UINT8 Mode);

static void CoordFlagAnalysis(void);
static UINT16 GetNextPtr(UINT16 PtrCount, UINT16* PtrArr, UINT16 MinPtr);
static void PrintCFInfo(const CF_INFO* CFInf, UINT8 CFID);

static void PrintFadeInfo(void);

void ExtractSmpsData(void);

void DumpFile(const char* Title, const char* Ext, UINT32 DataLen, const UINT8* Data);
UINT32 ScanForData(UINT32 DataLen, const UINT8* Data, UINT32 StartPos);
UINT32 ScanForData_WC(UINT32 DataLen, const UINT8* Data, UINT32 StartPos);
static INT8 memcmp_wc(const UINT8* buf1, const UINT8* buf2, UINT32 count);
INLINE UINT16 ReadBE16(const UINT8* Data);
INLINE UINT32 ReadBE32(const UINT8* Data);
INLINE UINT32 ReadBE24(const UINT8* Data);
INLINE UINT16 ReadLE16(const UINT8* Data);


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

static const UINT16 DEF_FM3FREQ_Z80_T2_VAL[DEF_FM3FREQ_Z80_T2_CNT] =
{	0x000, 0x132, 0x18E, 0x1E4, 0x234, 0x27E, 0x2C2, 0x2F0};
static const UINT16 DEF_FM3FREQ_Z80_T1_VAL_B[DEF_FM3FREQ_Z80_T1_CNT] =
{	0x000, 0x132, 0x18A, 0x1E4};


UINT32 ROMLength;
UINT8* ROMData;
char FileBase[0x200];
char* FileTitle;
UINT8 ReadMode;
UINT8 UseBaseName;
UINT8 AnalyseCF;

int main(int argc, char* argv[])
{
	int argbase;
	UINT8 RetVal;
	
	printf("SMPS Z80 Data Extractor\n");
	printf("-----------------------\n");
	if (argc < 2)
	{
		printf("Usage: SmpsZ80Extract.c [-Dump] [-UseBaseName] [-CFAnalysis] Driver.bin\n\n");
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
	//getchar();
#endif
	printf("\n");
	
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


static void DumpDrumData(void)
{
	static const UINT8 DRUM_FM_ADDR[] = {0x21, 0x60, 0x1D, 0xCB, 0x56, 0x20};
	static const UINT8 DRUM_FM_CHNDATA[] = {0x08, 0x11};
	static const UINT8 DRUM_SEQLIST[] = {0x3D, 0x21};
	static const UINT8 DRUM_FM_INSLIST[] = {0x77, 0x3A, 0x68, 0x1D, 0x21};
	
	static const UINT8 DRUM_PSG_ADDR[] = {0x21, 0xF0, 0x1D, 0xCB, 0x56, 0x20};
	//static const UINT8 DRUM_PSG_CHNDATA[] = {0x21 0x##, 0x11};
	static const UINT8 DRUM_CFHANDLE[] = {0xE5, 0xD6, 0xE0};
	
	UINT16 DrumFM[2];	// 0 - FM sequences, 1 - FM instruments
	UINT16 DrumPSG;
	UINT16 CFHandler;
	
	UINT32 BasePos;
	UINT32 CurPos;
	UINT32 TempPos;
	
	DrumFM[0] = DrumFM[1] = DrumPSG = CFHandler = 0x00;
	
	// --- FM Drums ---
	//	095E	21 60 1D	LD		HL, 1D60h
	//	0961	CB 56		BIT		2, (HL)
	//	0963	20 44		JR		NZ, +44h
	BasePos = ScanForData(sizeof(DRUM_FM_ADDR), DRUM_FM_ADDR, 0x00);
	printf("FM Drum Loader: %04X\n", BasePos);
	if (BasePos)
	{
		//	096D	08			EX		AF, AF'
		//	096E	11 xx xx	LD		DE, FMDrumInit
		CurPos = ScanForData(sizeof(DRUM_FM_CHNDATA), DRUM_FM_CHNDATA, BasePos);
		if (CurPos)
		{
			CurPos += sizeof(DRUM_FM_CHNDATA);
			TempPos = ReadLE16(&ROMData[CurPos]);
			printf("%s Drum settings (%04X): %02X %02X %02X\n", "FM",
					TempPos, ROMData[TempPos + 0x00], ROMData[TempPos + 0x01],
					ROMData[TempPos + 0x02]);
		}
		
		//	0978	3D			DEC		A
		//	0979	21 xx xx	LD		HL, FMDrumList
		CurPos = ScanForData(sizeof(DRUM_SEQLIST), DRUM_SEQLIST, BasePos);
		if (CurPos)
		{
			CurPos += sizeof(DRUM_SEQLIST);
			DrumFM[0] = ReadLE16(&ROMData[CurPos]);
			printf("%s Drum List: %04X\n", "FM", DrumFM[0]);
			
			BasePos = CurPos + 0x02;
		}
		
		//	098C	77			LD		(HL), A
		//	098D	3A 68 1D	LD		A, (1D68h)
		//	0990	21 xx xx	LD		HL, FMDrumInsList
		CurPos = ScanForData(sizeof(DRUM_FM_INSLIST), DRUM_FM_INSLIST, BasePos);
		if (CurPos)
		{
			CurPos += sizeof(DRUM_FM_INSLIST);
			DrumFM[1] = ReadLE16(&ROMData[CurPos]);
			printf("%s Instrument List: %04X\n", "FM", DrumFM[1]);
		}
	}
	printf("\n");
	
	
	// --- PSG Drums ---
	//	09A9	21 F0 1D	LD      HL, 1DF0h
	//	09AC	CB 56		BIT     2, (HL)
	//	09AE	20 26		JR      NZ, +26h
	BasePos = ScanForData(sizeof(DRUM_PSG_ADDR), DRUM_PSG_ADDR, 0x00);
	printf("PSG Drum Loader: %04X\n", BasePos);
	if (BasePos)
	{
		//	09B5    28 1F		JR		Z, +1Fh
		//	09B7    11 xx xx	LD		DE, PSGDrumInit
		CurPos = 0x00;
		for (TempPos = BasePos; TempPos < BasePos + 0x20; TempPos ++)
		{
			if (ROMData[TempPos + 0x00] == 0x28 &&
				ROMData[TempPos + 0x02] == 0x11)
			{
				CurPos = TempPos;
				break;
			}
		}
		if (CurPos)
		{
			CurPos += 0x03;
			TempPos = ReadLE16(&ROMData[CurPos]);
			printf("%s Drum settings (%04X): %02X %02X %02X\n", "PSG",
					TempPos, ROMData[TempPos + 0x00], ROMData[TempPos + 0x01],
					ROMData[TempPos + 0x02]);
		}
		
		//	09C9	3D			DEC		A
		//	09CA	21 xx xx	LD		HL, PSGDrumList
		CurPos = ScanForData(sizeof(DRUM_SEQLIST), DRUM_SEQLIST, BasePos);
		if (CurPos)
		{
			CurPos += sizeof(DRUM_SEQLIST);
			DrumPSG = ReadLE16(&ROMData[CurPos]);
			printf("%s Drum List: %04X\n", "PSG", DrumPSG);
			
			BasePos = CurPos + 0x02;
		}
	}
	printf("\n");
	
	
	// The Coordination Flag Handler marks the end of the drum section.
	// (for detection details, see CoordFlagAnalysis)
	BasePos = ScanForData(sizeof(DRUM_CFHANDLE), DRUM_CFHANDLE, 0x00);
	if (BasePos)
		CFHandler = BasePos - 0x03;
	printf("Coordination Flag Handler: %04X\n", CFHandler);
	
	
	// Dump everything...
	//	FM Drums:
	if (DrumFM[0])
	{
		BasePos = DrumFM[0];
		CurPos = ROMLength;
		if (DrumPSG > BasePos && DrumPSG < CurPos)
			CurPos = DrumPSG;
		if (CFHandler > BasePos && CFHandler < CurPos)
			CurPos = CFHandler;
		DumpDrumFile(0x01, DrumFM[0], DrumFM[1], CurPos);
	}
	
	//	PSG Drums:
	if (DrumPSG)
	{
		BasePos = DrumPSG;
		CurPos = ROMLength;
		if (DrumFM[0] > BasePos && DrumFM[0] < CurPos)
			CurPos = DrumFM[0];
		if (DrumFM[1] > BasePos && DrumFM[1] < CurPos)
			CurPos = DrumFM[1];
		if (CFHandler > BasePos && CFHandler < CurPos)
			CurPos = CFHandler;
		DumpDrumFile(0x00, DrumPSG, 0x00, CurPos);
	}
	
	printf("\n");
	
	
	return;
}

static void DumpDrumFile(UINT8 Type, UINT32 StartOfs, UINT32 InsOfs, UINT32 EndOfs)
{
	UINT32 HdrSize;
	SDRUM_HEADER DrumHdr;
	UINT32 FileSize;
	UINT8* FileData;
	UINT32 LowOfs;
	UINT32 PtrBase;
	UINT16 DrmCount;
	UINT16 InsCount;
	
	HdrSize = sizeof(SDRUM_HEADER);
	memset(&DrumHdr, 0x00, HdrSize);
	
	LowOfs = StartOfs;
	if (InsOfs && InsOfs < LowOfs)
		LowOfs = InsOfs;
	PtrBase = LowOfs - HdrSize;
	
	if (StartOfs < InsOfs)
	{
		DrmCount = (InsOfs - StartOfs) / 0x02;
		InsCount = (ReadLE16(&ROMData[StartOfs]) - InsOfs) / 0x02;
	}
	else
	{
		InsCount = (StartOfs - InsOfs) / 0x02;
		DrmCount = (ReadLE16(&ROMData[StartOfs]) - StartOfs) / 0x02;
	}
	
	memcpy(DrumHdr.Signature, "SDRM", 0x04);
	DrumHdr.Type = Type;
	DrumHdr.DrmCount = (UINT8)DrmCount;
	DrumHdr.DrmListOfs = (UINT16)(StartOfs - PtrBase);
	DrumHdr.DrmListBase = (UINT16)StartOfs;
	if (InsOfs)
	{
		DrumHdr.InsCount = (UINT8)InsCount;
		DrumHdr.InsListOfs = (UINT16)(InsOfs - PtrBase);
		DrumHdr.InsListBase = (UINT16)InsOfs;
	}
	
	FileSize = HdrSize + (EndOfs - LowOfs);
	FileData = (UINT8*)malloc(FileSize);
	
	memcpy(&FileData[0x00], &DrumHdr, HdrSize);
	memcpy(&FileData[HdrSize], &ROMData[LowOfs], EndOfs - LowOfs);
	
	if (Type & 0x01)
		DumpFile("Drums_FM", "bin", FileSize, FileData);
	else
		DumpFile("Drums_PSG", "bin", FileSize, FileData);
	
	free(FileData);
	
	return;
}


static void DumpPanAnimation(void)
{
	//static const UINT8 PANANI_LIST[] = {0xDD, 0x77, 0x16, 0xDD, 0x7E, 0x12, 0x21};
	static const UINT8 PANANI_LIST[] = {0xDD, 0x77, 0xFF, 0xDD, 0x7E, 0xFF, 0x21};
	
	UINT16 PanAni;
	UINT16 PanAniCnt;
	UINT16 PanAniEnd;
	
	UINT32 BasePos;
	UINT32 CurPos;
	UINT32 TempPos;
	
	PanAni = 0x00;
	
	// --- Pan Animation List ---
	//	0276	DD 77 16	LD		(IX+16h), A
	//	0279	DD 7E 12	LD		A, (IX+12h)
	//	027C	21 xx xx	LD		HL, PanAniPtrList
	BasePos = ScanForData_WC(sizeof(PANANI_LIST), PANANI_LIST, 0x00);
	if (BasePos)
	{
		BasePos += sizeof(PANANI_LIST);
		PanAni = ReadLE16(&ROMData[BasePos]);
		
		BasePos = ReadLE16(&ROMData[PanAni]);
		PanAniEnd = BasePos;
		PanAniCnt = 0x00;
		for (CurPos = PanAni; CurPos < BasePos; CurPos += 0x02, PanAniCnt ++)
		{
			TempPos = ReadLE16(&ROMData[CurPos]);
			if (TempPos < BasePos)
				BasePos = TempPos;
			if (PanAniEnd < TempPos)
				PanAniEnd = TempPos;
		}
		
		while(! (ROMData[PanAniEnd] & 0x3F) && PanAniEnd < ROMLength)
			PanAniEnd ++;
	}
	printf("Pan Animation List: %04X\n", PanAni);
	if (PanAni)
	{
		printf("    %02X items (end %04X)\n", PanAniCnt, PanAniEnd);
		DumpPanAniFile(0x00, PanAni, PanAniCnt, PanAniEnd);
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
	PAniHdr.AniListBase = (UINT16)StartOfs;
	
	FileSize = HdrSize + (EndOfs - StartOfs);
	FileData = (UINT8*)malloc(FileSize);
	
	memcpy(&FileData[0x00], &PAniHdr, HdrSize);
	memcpy(&FileData[HdrSize], &ROMData[StartOfs], EndOfs - StartOfs);
	
	DumpFile("PanAni", "bin", FileSize, FileData);
	
	free(FileData);
	
	return;
}


static void ShowModulationBug(void)
{
	static const UINT8 MOD_CODE[] = {0xDD, 0x5E, 0x20, 0xDD, 0x56, 0x21, 0xD5, 0xFD, 0xE1};
	static const UINT8 MOD_CHECK[] = {0xDD, 0x35, 0x25, 0x20};
	
	UINT32 CurPos;
	UINT32 CurPosE;
	const char* DetectMsg;
	
	CurPos = ScanForData(sizeof(MOD_CODE), MOD_CODE, 0x00);
	CurPosE = CurPos + sizeof(MOD_CODE);
	if (! CurPos)
	{
		DetectMsg = "code not found!";
	}
	else if (! memcmp(&ROMData[CurPos - 0x05], MOD_CHECK, sizeof(MOD_CHECK)))
	{
		// Flicky: (SMPS Z80 Type 1, buggy modulation)
		//	037C	DD 35 25	DEC		(IX+25h)
		//	037F	20 20		JR		NZ, +20h
		//	0381	DD 5E 20	LD		E, (IX+20h)
		//	0384	DD 56 21	LD		D, (IX+21h)
		//	0387	D5			PUSH	DE
		//	0388	FD E1		POP		IY
		//	038A	FD 7E 01	LD		A, (IY+01h)
		DetectMsg = "present";
	}
	else if (! memcmp(&ROMData[CurPosE], MOD_CHECK, sizeof(MOD_CHECK)))
	{
		// Sonic and Crackers (SMPS Z80 Type 2 DAC, fixed modulation)
		//	03D7	DD 5E 20	LD		E, (IX+20h)
		//	03DA	DD 56 21	LD		D, (IX+21h)
		//	03DD	D5			PUSH	DE
		//	03DE	FD E1		POP		IY
		//	03E0	DD 35 25	DEC		(IX+25h)
		//	03E3	20 17		JR		NZ, +17h  ; [03FCh]
		//	03E5	FD 7E 01	LD		A, (IY+01h)
		DetectMsg = "fixed";
	}
	else
	{
		DetectMsg = "Detection failed!";
	}
	
	printf("DoModulation Bug: %s\n", DetectMsg);
	printf("\n");
	return;
}


static void ShowFrequencies(void)
{
	static const UINT8 PSG_FREQS[] = {0xDD, 0x86, 0x05, 0x21};
	static const UINT8 PSG_FREQS_TEMPO[] = {0xF5, 0xDF, 0xF1};
	//static const UINT8 FM_FREQS1[] = {0x08, 0x93, 0x38};
	static const UINT8 FM_FREQS2[] = {0x83, 0x21};
	static const UINT8 FM3_FREQS_1[] = {0x1A, 0x13, 0xD9, 0x21};
	static const UINT8 FM3_FREQS_2[] = {0x7E, 0x23, 0xE5, 0x21};
	
	UINT16 Freqs[3];	// 0 - PSG, 1 - FM, 2 - FM3
	UINT16 FreqCnt[3];
	
	UINT32 BasePos;
	UINT32 CurPos;
	
	Freqs[0] = Freqs[1] = Freqs[2] = 0x00;
	
	// --- Frequencies ---
	BasePos = ScanForData(sizeof(PSG_FREQS), PSG_FREQS, 0x00);
	if (BasePos)
	{
		BasePos += sizeof(PSG_FREQS);
	}
	else
	{
		// check for Tempo 32x
		//	0210	DD 86 05	ADD		A, (IX+05h)
		//	0213	DD 77 02	LD		(IX+02h), A
		//	0216	21 61 08	LD		HL, PSGFreqs
		//	0219	F5			PUSH	AF
		//	021A	DF			RST		0018h
		//	021B	F1			POP		AF
		BasePos = ScanForData(sizeof(PSG_FREQS_TEMPO), PSG_FREQS_TEMPO, 0x00);
		if (BasePos)
			BasePos -= 0x02;
	}
	if (BasePos)
	{
		if (ROMData[BasePos + 0x02] != 0xDD)
		{
			// SMPS Z80:
			//	01C2	DD 86 05	ADD		A, (IX+05h)
			//	01C5	21 xx xx	LD		HL, PSGFreqs
			//	01C8	F5			PUSH    AF
			Freqs[0] = ReadLE16(&ROMData[BasePos]);
			
			//	01D8	08			EX		AF, AF'
			//	01D9	93			SUB		E
			//	01DA	38 05		JR		C, +05h
			//	01E1	83			ADD		A, E
			//	01E2	21 xx xx	LD		HL, FMFreqs
			BasePos = ScanForData(sizeof(FM_FREQS2), FM_FREQS2, BasePos);
			if (BasePos)
			{
				BasePos += sizeof(FM_FREQS2);
				Freqs[1] = ReadLE16(&ROMData[BasePos]);
			}
		}
		else
		{
			// preSMPS Z80:
			//	0199	DD 86 05	ADD		A, (IX+05h)
			//	019C	21 xx xx	LD		HL, FMFreqs
			//	019F	DD CB 01 7E	BIT		7, (IX+01h)
			//	01A3	28 03		JR		Z, +03h
			//	01A5	21 xx xx	LD		HL, PSGFreqs
			CurPos = BasePos;
			BasePos += 0x02 + 0x04;
			if (ROMData[BasePos] == 0x28)	// JR	Z (Mystic Defender)
			{
				BasePos += 0x02 + 0x01;
				Freqs[0] = ReadLE16(&ROMData[BasePos]);
				Freqs[1] = ReadLE16(&ROMData[CurPos]);
			}
			else	// JR	NZ, +03h (preSMPS Z80)
			{
				BasePos += 0x02 + 0x01;
				Freqs[0] = ReadLE16(&ROMData[CurPos]);
				Freqs[1] = ReadLE16(&ROMData[BasePos]);
			}
		}
	}
	
	// SMPS Z80 Type 1:
	//	0CBA	1A			LD		A, (DE)
	//	0CBB	13			INC		DE
	//	0CBC	D9			EXX
	//	0CBD	21 xx xx	LD		HL, FM3Freqs
	// SMPS Z80 Type 2:
	//	0D5D	7E			LD		A, (HL)
	//	0D5E	23			INC		HL
	//	0D5F	E5			PUSH	HL
	//	0D60	21 xx xx	LD		HL, FM3Freqs
	BasePos = ScanForData(sizeof(FM3_FREQS_1), FM3_FREQS_1, 0x00);
	if (! BasePos)
		BasePos = ScanForData(sizeof(FM3_FREQS_2), FM3_FREQS_2, 0x00);
	if (BasePos)
	{
		BasePos += sizeof(FM3_FREQS_1);
		Freqs[2] = ReadLE16(&ROMData[BasePos]);
	}
	
	printf("PSG Frequencies: %04X\n", Freqs[0]);
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
	printf("FM Frequencies: %04X\n", Freqs[1]);
	if (Freqs[1])
	{
		FreqCnt[1] = ParseFreqTable(&Freqs[1], 0x01);
		LimitArrayCount(&FreqCnt[0], 0x02, Freqs[1], Freqs[0]);
		printf("    %02X frequencies:\n", FreqCnt[1]);
		PrintFreqTable(&ROMData[Freqs[1]], FreqCnt[1], 1);
	}
	printf("FM3 Frequencies: %04X\n", Freqs[2]);
	if (Freqs[2])
	{
		FreqCnt[2] = ParseFreqTable(&Freqs[2], 0x02);
		printf("    %02X frequencies:\n", FreqCnt[2]);
		PrintFreqTable(&ROMData[Freqs[2]], FreqCnt[2], 2);
	}
	printf("\n");
	
	return;
}

static UINT16 ParseFreqTable(UINT16* Offset, UINT8 Mode)
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
	LastFreq = ReadLE16(&ROMData[CurPos]);	CurPos += 0x02;
	if (! Mode)
	{
		// Mode 00 - falling frequencies (PSG)
		for (; CurPos < ROMLength; CurPos += 0x02)
		{
			NewFreq = ReadLE16(&ROMData[CurPos]);
			if (NewFreq > LastFreq)
				break;	// frequencies must be falling, stop when they rise
			if (NewFreq >= 0x4000)
				break;	// break on out-of-range frequency
			LastFreq = NewFreq;
		}
	}
	else
	{
		// Mode 01 - rising frequencies (FM)
		for (; CurPos < ROMLength; CurPos += 0x02)
		{
			NewFreq = ReadLE16(&ROMData[CurPos]);
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

static void LimitArrayCount(UINT16* Count, UINT8 ItmSize, UINT16 ArrPos, UINT16 OtherPos)
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
			FreqArr[CurIdx] = ReadLE16(&Data[CurIdx * 0x02]);
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
			printf("%0*Xh", DigitCnt, FreqArr[CurIdx]);
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
	static const UINT8 FM_CHMASK[] = {0x11, 0x06, 0x00, 0x19, 0x22, 0xFF, 0xFF, 0x21};
	static const UINT8 PSG_CHMASK[] = {0xFD, 0x7E, 0x03, 0xB7, 0xCA, 0xFF, 0xFF, 0x47, 0x21};
	
	UINT16 ChnMask[2];	// 0 - FM, 1 - PSG
	UINT16 ChnCount[2];
	
	UINT32 BasePos;
	UINT32 CurPos;
	
	// FM Channel Mask:
	//	0532	11 06 00	LD		DE, 0006h
	//	0535	19			ADD		HL, DE
	//	0536	22 33 1C	LD		(1C33h), HL
	//	0539	21 A1 05	LD		HL, FMInitBytes
	BasePos = ScanForData_WC(sizeof(FM_CHMASK), FM_CHMASK, 0x00);
	if (BasePos)
	{
		BasePos += sizeof(FM_CHMASK);
		ChnMask[0] = ReadLE16(&ROMData[BasePos]);
		
		printf("FM Channels (%04X):", ChnMask[0]);
		ChnCount[0] = 0;
		for (CurPos = ChnMask[0]; CurPos < ROMLength; CurPos += 0x02, ChnCount[0] ++)
		{
			if (ROMData[CurPos + 0x00] != 0x80 || (ROMData[CurPos + 0x01] & ~0x07))
				break;
			
			printf(" %X", ROMData[CurPos + 0x01]);
		}
		
		printf(" (count: %u)\n", ChnCount[0]);
	}
	
	// PSG Channel Mask:
	//	0569	FD 7E 03	LD		A, (IY+03h)
	//	056C	B7			OR		A
	//	056D	CA 9B 05	JP		Z, 059Bh
	//	0570	47			LD		B, A
	//	0571	21 AF 05	LD		HL, 05AFh
	BasePos = ScanForData_WC(sizeof(PSG_CHMASK), PSG_CHMASK, 0x00);
	if (BasePos)
	{
		BasePos += sizeof(PSG_CHMASK);
		ChnMask[1] = ReadLE16(&ROMData[BasePos]);
		
		printf("PSG Channels (%04X):", ChnMask[1]);
		ChnCount[1] = 0;
		for (CurPos = ChnMask[1]; CurPos < ROMLength; CurPos += 0x02, ChnCount[1] ++)
		{
			if (ROMData[CurPos + 0x00] != 0x80 || (ROMData[CurPos + 0x01] & ~0xE0))
				break;
			
			printf(" %X", ROMData[CurPos + 0x01]);
		}
		
		printf(" (count: %u)\n", ChnCount[1]);
	}
	printf("\n");
	
	return;
}


static void CoordFlagAnalysis(void)
{
	static const UINT8 CFHANDLE[] = {0xE5, 0xD6, 0xE0};
	static const UINT8 PSG_TRKUPD[] = {0xC9, 0xDD, 0xCB, 0x01, 0x7E, 0xC2};
	
#define MAX_CF	0x40
	UINT16 CFHandler;
	UINT16 CFHandlerEnd;
	UINT16 CFPtrList[2];
	UINT16 CFPtrCnt[2];
	UINT16 CFPtrs[MAX_CF + 3];
	CF_INFO CFInfo[MAX_CF];
	
	UINT32 CurPos;
	UINT32 MaxPos;
	UINT16 NextPtr;
	UINT8 CurCF;
	
	CFHandler = CFHandlerEnd = 0x00;
	
	// --- cfHandler ---
	//	0B2F	21 xx xx	LD		HL, cfReturn
	//	0B32	E5			PUSH	HL
	//	0B33	D6 E0		SUB		E0h
	//	0B35	21 xx xx	LD		HL, cfPtrTable
	CurPos = ScanForData(sizeof(CFHANDLE), CFHANDLE, 0x00);
	if (CurPos)
		CFHandler = CurPos - 0x03;
	printf("Coordination Flag Handler: %04X\n", CFHandler);
	
	// --- jump to UpdatePSGTrack ---
	//	00F2	C9			RET		; last instruction from TrkUpdateLoop
	//	00F3	DD CB 01 7E	BIT		7, (IX+01h)
	//	00F7	C2 xx xx	JP		NZ, UpdatePSGTrk
	CurPos = ScanForData(sizeof(PSG_TRKUPD), PSG_TRKUPD, 0x00);
	if (CurPos)
		CFHandlerEnd = ReadLE16(&ROMData[CurPos + 0x06]);
	printf("UpdatePSG routine (cfHandler End): %04X\n", CFHandlerEnd);
	if (! CFHandlerEnd)
		CFHandlerEnd = ROMLength;
	printf("Coord. Flag section size: %04X\n", CFHandlerEnd - CFHandler);
	
	if (! AnalyseCF)
		return;
	
	CFPtrList[0] = ReadLE16(&ROMData[CFHandler + 0x07]);
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
	MaxPos = CFHandlerEnd;
	for (CurCF = 0x00; CurCF < 0x20; CurCF ++, CurPos += 0x02)
	{
		if (CurPos >= MaxPos)
			break;
		
		CFPtrs[CurCF] = ReadLE16(&ROMData[CurPos]);
		if (CFPtrs[CurCF] < MaxPos && CFPtrs[CurCF] >= CFPtrList[0])
			MaxPos = CFPtrs[CurCF];	// remember smallest pointer to be able to terminate the CF list early
		CFInfo[CurCF].Ptr = CFPtrs[CurCF];
		
		//	cfMetaCoordFlag: (MegaCD BIOS)
		//	0B3F	21 xx xx	LD		HL, cfMetaPtrTable
		//	0B42	EF			RST		ReadPtrTable (0028h)
		//	cfMetaCoordFlag: (Columns III)
		//	0D92	21 xx xx	LD		HL, cfMetaPtrTable
		//	0D95	DF			RST		ReadPtrTable (0018h)
		if (ROMData[CFPtrs[CurCF] + 0x00] == 0x21 &&
			(ROMData[CFPtrs[CurCF] + 0x03] & 0xC7) == 0xC7)
		{
			CFPtrList[1] = ReadLE16(&ROMData[CFPtrs[CurCF] + 0x01]);
			CFInfo[CurCF].Name = "MetaCF";
		}
	}
	CFPtrCnt[0] = CurCF;
	for (; CurCF < 0x20; CurCF ++)
		CFPtrs[CurCF] = 0x0000;
	printf("\n");
	
	if (CFPtrList[1])
	{
		CurPos = CFPtrList[1];
		// continue using the old MaxPos, if possible
		if (MaxPos < CurPos)
			MaxPos = CFHandlerEnd;
		for (CurCF = 0x20; CurCF < MAX_CF; CurCF ++, CurPos += 0x02)
		{
			if (CurPos >= MaxPos)
				break;
			
			CFPtrs[CurCF] = ReadLE16(&ROMData[CurPos]);
			if (CFPtrs[CurCF] < MaxPos && CFPtrs[CurCF] >= CFPtrList[1])
				MaxPos = CFPtrs[CurCF];	// remember smallest pointer to be able to terminate the CF list early
			CFInfo[CurCF].Ptr = CFPtrs[CurCF];
		}
		CFPtrCnt[1] = CurCF;
		printf("\n");
	}
	for (; CurCF < MAX_CF; CurCF ++)
		CFPtrs[CurCF] = 0x0000;
	
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
	return;
}

static UINT16 GetNextPtr(UINT16 PtrCount, UINT16* PtrArr, UINT16 MinPtr)
{
	UINT16 ResPtr;
	UINT16 CurPtr;
	
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

static void PrintCFInfo(const CF_INFO* CFInf, UINT8 CFID)
{
	printf("\t%02X: %04X (size %04X)", CFID, CFInf->Ptr, CFInf->Size);
	if (CFInf->Name != NULL)
		printf(" %s", CFInf->Name);
	if (CFInf->Desc != NULL)
		printf(" (%s)", CFInf->Desc);
	printf("\n");
	
	return;
}

static void PrintFadeInfo(void)
{
	static const UINT8 FADE_MASK[0x0F] =
	{	0x3E, 0xFF, 0x32, 0xFF, 0xFF,
		0x3E, 0xFF, 0x32, 0xFF, 0xFF, 0x32, 0xFF, 0xFF,
		0xAF, 0x32};
	
	UINT32 CurPos;
	
	// 0736	3E 28		LD		A, 28h
	// 0738	32 0D 1C	LD		(1C0Dh), A
	// 073B	3E 06		LD		A, 06h
	// 073D	32 0F 1C	LD		(1C0Fh), A
	// 0740	32 0E 1C	LD		(1C0Eh), A
	// 0743	AF			XOR		A
	// 0744	32 40 1C	LD		(1C40h), A
	CurPos = ScanForData_WC(sizeof(FADE_MASK), FADE_MASK, 0x00);
	if (! CurPos)
	{
		printf("No fade settings found!\n");
		return;
	}
	
	printf("FadeOut routine found at %04X:\n", CurPos);
	printf("\tFadeOutSteps = %02Xh\n", ROMData[CurPos + 0x01]);
	printf("\tFadeOutDelay = %u\n", ROMData[CurPos + 0x06]);
	
	return;
}


void ExtractSmpsData(void)
{
	printf("\n");
	
	ShowChannelMask();
	DumpDrumData();
	DumpPanAnimation();
	ShowModulationBug();
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


UINT32 ScanForData(UINT32 DataLen, const UINT8* Data, UINT32 StartPos)
{
	UINT32 CurPos;
	
	//printf("Trying to search for Music Pointer List ...");
	for (CurPos = StartPos; CurPos < ROMLength - DataLen; CurPos ++)
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

UINT32 ScanForData_WC(UINT32 DataLen, const UINT8* Data, UINT32 StartPos)
{
	// wildcard version
	UINT32 CurPos;
	
	for (CurPos = StartPos; CurPos < ROMLength - DataLen; CurPos ++)
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


INLINE UINT16 ReadBE16(const UINT8* Data)
{
	return (Data[0x00] << 8) | (Data[0x01] << 0);
}

INLINE UINT32 ReadBE32(const UINT8* Data)
{
	return	(Data[0x00] << 24) | (Data[0x01] << 16) |
			(Data[0x02] <<  8) | (Data[0x03] <<  0);
}

INLINE UINT32 ReadBE24(const UINT8* Data)
{
	return	(Data[0x01] << 16) |
			(Data[0x02] <<  8) | (Data[0x03] <<  0);
}

INLINE UINT16 ReadLE16(const UINT8* Data)
{
	return (Data[0x01] << 8) | (Data[0x00] << 0);
}
