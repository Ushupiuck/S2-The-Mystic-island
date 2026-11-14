#ifndef __DETECTSEARCH_H__
#define __DETECTSEARCH_H__

#include "stdtype.h"


typedef struct _z80driver_section
{
	UINT32 SrcOfs;	// ROM offset
	UINT16 Length;
	UINT16 DstOfs;	// Z80 RAM offset
} Z80DRV_PART;
typedef struct _z80driver_compilation
{
	UINT16 Alloc;
	UINT16 Count;
	Z80DRV_PART* Data;
} Z80DRV_COMP;
typedef struct _z80driver_collection
{
	UINT16 Alloc;
	UINT16 Count;
	Z80DRV_COMP* Data;
} Z80DRV_COLL;


UINT32 ScanForData(UINT32 ScanLen, const UINT8* ScanData,
					UINT32 MatchLen, const UINT8* MatchData, UINT32 StartPos);
UINT32 ScanForData2(UINT32 ScanLen, const UINT8* ScanData,
					UINT32 MatchLen, const UINT8* MatchData, UINT32 StartPos);
UINT32 ScanForData_WC(UINT32 ScanLen, const UINT8* ScanData,
					UINT32 MatchLen, const UINT8* MatchData, UINT32 StartPos);

UINT16 ReadCmpJumpTable(const UINT8* Code, UINT16 StartPos, UINT8 BankID);
UINT8 ReadCmpJumpTable_BnkCount(const UINT8* Code, UINT16 StartPos);
UINT16 ReadBankSwitchCode(const UINT8* Code, UINT16 StartPos);
UINT32 ReadLEA(const UINT8* Code, UINT32 InstPos);
void GenerateCode(UINT8* Buffer, const UINT8* Instr1, UINT32 Address, const UINT8* Instr2);
UINT32 FindBytesWrittenToOfs(UINT8* Buffer, UINT32 Offset, UINT32 BytCount);

UINT32 ScanForSonic1Ptrs(void);
UINT32 ScanForZ80Drv_CompKos(void);
UINT32 ScanForZ80Drv_Uncomp(void);

void GetZ80DriverParts(Z80DRV_COLL* Z80Coll);
void GetZ80DriverParts_SegaNet(Z80DRV_COLL* Z80Coll);
UINT16 MakeZ80DriverDump(UINT8** RetData, Z80DRV_COMP* Z80Drv);
void FreeZ80DriverComp(Z80DRV_COMP* Z80Drv);

#endif	// __DETECTSEARCH_H__
