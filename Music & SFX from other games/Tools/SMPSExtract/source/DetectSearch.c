// Detection and Search routines for SMPS Extract
// -----------------------------
// Written by Valley Bell

#define _CRT_SECURE_NO_WARNINGS
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <memory.h>
#include <malloc.h>
#include "stdtype.h"
#include "ReadFuncs.h"
#include "DetectSearch.h"


//UINT32 ScanForData(UINT32 ScanLen, const UINT8* ScanData,
//					UINT32 MatchLen, const UINT8* MatchData, UINT32 StartPos);
//UINT32 ScanForData_WC(UINT32 ScanLen, const UINT8* ScanData,
//					UINT32 MatchLen, const UINT8* MatchData, UINT32 StartPos);
static INT8 memcmp_wc(const UINT8* buf1, const UINT8* buf2, UINT32 count);

//UINT16 ReadCmpJumpTable(const UINT8* Code, UINT16 StartPos, UINT8 BankID);
//UINT8 ReadCmpJumpTable_BnkCount(const UINT8* Code, UINT16 StartPos);
//UINT16 ReadBankSwitchCode(const UINT8* Code, UINT16 StartPos);
INLINE UINT16 ReadDisplc(const UINT8* Code, UINT32 InstPos, UINT32* RetOfs);
//UINT32 ReadLEA(const UINT8* Code, UINT32 InstPos);
//void GenerateCode(UINT8* Buffer, const UINT8* Instr1, UINT32 Address, const UINT8* Instr2);
//UINT32 FindBytesWrittenToOfs(UINT8* Buffer, UINT32 Offset, UINT32 BytCount);

//UINT32 ScanForSonic1Ptrs(void);
//UINT32 ScanForZ80Drv_CompKos(void);
//UINT32 ScanForZ80Drv_Uncomp(void);

static void AddZ80Part(Z80DRV_COMP* Z80Coll, UINT32 SrcOfs, UINT16 Len, UINT32 DstOfs);
//void GetZ80DriverParts(Z80DRV_COLL* Z80Coll);
//void GetZ80DriverParts_SegaNet(Z80DRV_COLL* Z80Coll);
//UINT16 MakeZ80DriverDump(UINT8** RetData, Z80DRV_COMP* Z80Drv);
//void FreeZ80DriverComp(Z80DRV_COMP* Z80Drv);
static UINT16 GetAddressCommand(UINT32 ROMPos, UINT32* RetOfs);
static UINT16 GetMoveCommand(UINT32 ROMPos, UINT32* RetVal);
static UINT16 GetCopyData(UINT32 BasePos, UINT32* DataOfs, UINT16* DataLen, UINT32* DataDstOfs);
static UINT32 GetCopyBlockStart(UINT32 ROMPos);
static UINT16 GetCopyData_SegaNet(UINT32 BasePos, UINT32* StructAddr,
									UINT32* DataOfs, UINT16* DataLen, UINT32* DataDstOfs);
static UINT16 GetCopyData_SegaNet_Struct(UINT32 BasePos, UINT32* StructAddr,
										UINT32* DataOfs, UINT16* DataLen, UINT32* DataDstOfs);
static UINT32 GetCopyBlockStart_SegaNet(UINT32 ROMPos);


extern UINT32 ROMLength;
extern UINT8* ROMData;

static UINT8 Z80DrvAlloc;
static UINT8 Z80DrvCount;
static Z80DRV_COMP* Z80DrvData;

// --- Generic Search Routines ---
UINT32 ScanForData(UINT32 ScanLen, const UINT8* ScanData,
					UINT32 MatchLen, const UINT8* MatchData, UINT32 StartPos)
{
	UINT32 CurPos;
	
	if (ScanLen < MatchLen)
		return 0x00;
	for (CurPos = StartPos; CurPos < ScanLen - MatchLen; CurPos ++)
	{
		if (! memcmp(ScanData + CurPos, MatchData, MatchLen))
			return CurPos;
	}
	
	return 0x00;
}

UINT32 ScanForData2(UINT32 ScanLen, const UINT8* ScanData,
					UINT32 MatchLen, const UINT8* MatchData, UINT32 StartPos)
{
	UINT32 CurPos;
	
	if (ScanLen < MatchLen)
		return 0x00;
	for (CurPos = StartPos; CurPos < ScanLen - MatchLen; CurPos += 0x02)
	{
		if (! memcmp(ScanData + CurPos, MatchData, MatchLen))
			return CurPos;
	}
	
	return 0x00;
}

UINT32 ScanForData_WC(UINT32 ScanLen, const UINT8* ScanData,
					UINT32 MatchLen, const UINT8* MatchData, UINT32 StartPos)
{
	// wildcard version (the wildcard is FF)
	UINT32 CurPos;
	
	if (ScanLen < MatchLen)
		return 0x00;
	for (CurPos = StartPos; CurPos < ScanLen - MatchLen; CurPos ++)
	{
		if (! memcmp_wc(ScanData + CurPos, MatchData, MatchLen))
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


// --- Game-specific Search and Read Routines ---
UINT16 ReadCmpJumpTable(const UINT8* Code, UINT16 StartPos, UINT8 BankID)
{
	// read a Z80 jump table of the format:
	// Mighty Morphin Power Rangers:
	//	CP	A, val1		FE val1
	//	JP	Z, loc1		CA xx xx
	//	CP	A, val2		FE val2
	//	JP	Z, loc2		CA xx xx
	// etc.
	//	Viewpoint:
	//	CP	A, val1		FE val1
	//	JR	NZ, loc1	20 xx
	//	..code..
	
	UINT16 CurPos;
	UINT8 MaxBnkID;
	UINT8 CurBnkID;
	UINT8 CurInstr;
	UINT16 CurAddr;
	
	MaxBnkID = 0x00;
	CurPos = StartPos;
	while(Code[CurPos] == 0xFE)	// CMP command
	{
		CurPos ++;
		CurBnkID = Code[CurPos];
		CurPos ++;
		if (CurBnkID > MaxBnkID)
			MaxBnkID = CurBnkID;
		
		CurInstr = Code[CurPos];
		CurPos ++;
		
		if ((CurInstr & 0xF7) == 0xC2)
		{
			// absolute 16-bit jump
			//	JP	Z, loc		CA xx xx
			//	JP	NZ, loc		C2 xx xx
			CurAddr = ReadLE16(&Code[CurPos]);
			CurPos += 0x02;
		}
		else if ((CurInstr & 0xF7) == 0x20)
		{
			// relative 8-bit jump
			//	JR	Z, loc		28 xx
			//	JR	NZ, loc		20 xx
			CurAddr = Code[CurPos];
			CurPos ++;
			CurAddr += CurPos;
		}
		else
		{
			return 0x0000;
		}
		
		if (CurInstr & 0x08)	// JP/JR	Z
		{
			if (CurBnkID == BankID)
				return CurAddr;
		}
		else					// JP/JR	NZ
		{
			if (CurBnkID != BankID)
				return CurAddr;
		}
	}
	
	CurAddr = CurPos;
	CurInstr = Code[CurPos];
	CurPos ++;
	
	if (CurInstr == 0xC3)	// JP	loc
	{
		CurAddr = ReadLE16(&Code[CurPos]);
		CurPos += 0x02;
	}
	else if (CurInstr == 0x18)	// JR	loc
	{
		CurAddr = Code[CurPos];
		CurPos ++;
		CurAddr += CurPos;
	}
	
	return CurAddr;
}

UINT8 ReadCmpJumpTable_BnkCount(const UINT8* Code, UINT16 StartPos)
{
	UINT16 CurPos;
	UINT16 FinBnkAddr;
	UINT8 MaxBnkID;
	UINT8 CurBnkID;
	UINT8 CurInstr;
	UINT16 CurAddr;
	
	FinBnkAddr = ReadCmpJumpTable(Code, StartPos, 0xFF);
	
	MaxBnkID = 0x00;
	CurPos = StartPos;
	while(Code[CurPos] == 0xFE)	// CMP command
	{
		CurPos ++;
		CurBnkID = Code[CurPos];
		CurPos ++;
		
		CurInstr = Code[CurPos];
		CurPos ++;
		
		if ((CurInstr & 0xF7) == 0xC2)
		{
			// absolute 16-bit jump
			CurAddr = ReadLE16(&Code[CurPos]);
			CurPos += 0x02;
		}
		else if ((CurInstr & 0xF7) == 0x20)
		{
			// relative 8-bit jump
			CurAddr = Code[CurPos];
			CurPos ++;
			CurAddr += CurPos;
		}
		else
		{
			return 0x00;
		}
		if (! (CurInstr & 0x08))	// JP	NZ
			CurBnkID ++;
		
		if (CurBnkID > MaxBnkID)
			MaxBnkID = CurBnkID;
		if (FinBnkAddr == CurAddr)
			FinBnkAddr = 0x0000;
	}
	
	//if (FinBnkAddr)
	//	MaxBnkID ++;
	
	return MaxBnkID + 1;
}

UINT16 ReadBankSwitchCode(const UINT8* Code, UINT16 StartPos)
{
	// This function reads bank switching code of the format:
	//	LD	HL, 6000h	21 00 60
	//	XOR	A			AF
	//	LD	E, 01h		1E 01
	//	LD	(HL), E		73
	//	LD	(HL), A		77
	//	LD	(HL), E		73
	//	...
	// Notes:
	//	- Phantasy Star IV uses register B instead of E.
	//	- The Hybrid Front uses only register A.
	//	- Sonic 2 sets register A and E first and then HL.
	UINT16 CurPos;
	UINT16 BnkVal;
	UINT8 RegA;
	UINT8 RegE;
	
	CurPos = StartPos;
	//if (Code[CurPos] == 0x21)	// LD	HL, addr
	//	CurPos += 0x02;
	//CurPos ++;
	
	// Note: ROM Bank has 9 bits. LSB is written first, MSB is written last.
	RegA = 0x00;
	RegE = 0x00;
	BnkVal = 0x0000;
	while(CurPos != 0xFFFF)
	{
		switch(Code[CurPos])
		{
		case 0x3A:	// LD	A, (addr)
			CurPos += 0x03;
			break;
		case 0x21:	// LD	HL, addr
			CurPos += 0x03;
			break;
		case 0xAF:	// XOR	A
			RegA = 0x00;
			CurPos ++;
			break;
		case 0x0F:	// RRCA
		case 0x1F:	// RRA
			RegA >>= 1;	// a simple Bit-Shift is enough to emulate this
			CurPos ++;
			break;
		case 0x06:	// LD	B, val
		case 0x1E:	// LD	E, val
		case 0x3E:	// LD	A, val
			CurPos ++;
			RegE = Code[CurPos];
			CurPos ++;
			break;
		case 0x70:	// LD	(HL), B
		case 0x73:	// LD	(HL), E
			CurPos ++;
			BnkVal >>= 1;
			BnkVal |= (RegE & 0x01) << 15;	// if set, add 8000
			break;
		case 0x77:	// LD	(HL), A
			CurPos ++;
			BnkVal >>= 1;
			BnkVal |= (RegA & 0x01) << 15;	// if set, add 8000
			break;
		case 0xCB:	// RLC/RRC/RL/RR/...
			CurPos ++;
			CurPos ++;
			break;
		case 0x36:	// LD	(HL), val
			CurPos ++;
			BnkVal >>= 1;
			BnkVal |= (Code[CurPos] & 0x01) << 15;	// if set, add 8000
			CurPos ++;
			break;
		default:
			CurPos = 0xFFFF;
			break;
		}
	}
	
	return (BnkVal & 0xFF80) >> 7;
}

INLINE UINT16 ReadDisplc(const UINT8* Code, UINT32 InstPos, UINT32* RetOfs)
{
	UINT8 DisplcMode;
	UINT16 ParamSize;
	UINT32 DstOfs;
	
	DisplcMode = Code[InstPos + 0x01];
	if ((DisplcMode & 0x3C) != 0x38)
		return 0x00;
	InstPos += 0x02;
	
	DisplcMode &= 0x03;
	if (DisplcMode == 0x00)			// JMP	addr.w, Ax
	{
		DstOfs = (INT16)ReadBE16(&Code[InstPos]) & 0xFFFFFF;
		ParamSize = 0x02;
	}
	else if (DisplcMode == 0x01)	// JMP	addr.l, Ax
	{
		DstOfs = ReadBE32(&Code[InstPos]) & 0xFFFFFF;
		ParamSize = 0x04;
	}
	else if (DisplcMode == 0x02)	// JMP	addr(PC), Ax
	{
		DstOfs = InstPos + (INT16)ReadBE16(&Code[InstPos]);
		ParamSize = 0x02;
	}
	else if (DisplcMode == 0x03)	// JMP	addr(PC, Dx.w), Ax
	{
		DstOfs = InstPos + (INT8)Code[InstPos + 0x01];
		ParamSize = 0x02;
	}
	
	if (RetOfs != NULL)
		*RetOfs = DstOfs;
	return 0x02 + ParamSize;
}

UINT32 ReadLEA(const UINT8* Code, UINT32 InstPos)
{
	UINT8 LeaMode;
	
	LeaMode = Code[InstPos + 0x01];
	InstPos += 0x02;
	
	if (LeaMode == 0xF8)		// LEA	addr.w, Ax
		return (INT16)ReadBE16(&Code[InstPos]) & 0xFFFFFF;
	else if (LeaMode == 0xF9)	// LEA	addr.l, Ax
		return ReadBE32(&Code[InstPos]) & 0xFFFFFF;
	else if (LeaMode == 0xFA)	// LEA	addr(PC), Ax
		return InstPos + (INT16)ReadBE16(&Code[InstPos]);
	else if (LeaMode == 0xFB)	// LEA	addr(PC, Dx.w), Ax
		return InstPos + (INT8)Code[InstPos + 0x01];
	
	return 0x00;
}

void GenerateCode(UINT8* Buffer, const UINT8* Instr1, UINT32 Address, const UINT8* Instr2)
{
	Buffer[0x00] = Instr1[0x00];
	Buffer[0x01] = Instr1[0x01];
	WriteBE32(&Buffer[0x02], Address);
	if (Instr2 != NULL)
	{
		Buffer[0x06] = Instr2[0x00];
		Buffer[0x07] = Instr2[0x01];
	}
	
	return;
}

static UINT32 GetMoveB_APtoAP_Count(UINT32 StartOffset)
{
	// get number of consecutive MOVE.B (Ax)+, (Ax)+ writes
	UINT32 ROMPos;
	UINT32 MoveCnt;
	UINT16 CurInstr;
	
	ROMPos = StartOffset;
	CurInstr = ReadBE16(&ROMData[ROMPos]) & ~0x0E00;
	// Note: Sometimes they don't use DBRA for the loops.
	//       In this case, the result will be one byte too high.
	//       (but that's better than one missing byte)
	if ((CurInstr & 0xFF00) == 0x7000)	// 7Exx			MOVEQ	#xx, D7
	{
		MoveCnt = ROMData[ROMPos + 0x01] + 0x01;
		printf("Found MOVEQ for 0x%02X iterations.\n", MoveCnt);
		return MoveCnt;
	}
	else if (CurInstr == 0x103C)		// 103C 00xx	MOVE.B	#xx, D0
	{
		MoveCnt = ROMData[ROMPos + 0x03] + 0x01;
		printf("Found MOVE.B for 0x%02X iterations.\n", MoveCnt);
		return MoveCnt;
	}
	else if (CurInstr == 0x303C)		// 323C xxxx	MOVE.W	#xxxx, D1
	{
		MoveCnt = ReadBE16(&ROMData[ROMPos + 0x02]) + 0x01;
		printf("Found MOVE.W for 0x%02X iterations.\n", MoveCnt);
		return MoveCnt;
	}
	
	MoveCnt = 0x00;
	while(ROMPos < ROMLength)
	{
		CurInstr = ReadBE16(&ROMData[ROMPos]);
		if ((CurInstr & 0xFFF8) != 0x1098)	// 1099	MOVE.B	(A1)+, (A0)
		{
			if ((CurInstr & 0xFFF8) == 0x1090)	// 1091	MOVE.B	(A1), (A0)
				MoveCnt ++;
			break;
		}
		ROMPos += 0x02;
		MoveCnt ++;
	}
	printf("Found 0x%02X MOVE.B instructions.\n", MoveCnt);
	
	return MoveCnt;
}

UINT32 FindBytesWrittenToOfs(UINT8* Buffer, UINT32 Offset, UINT32 BytCount)
{
	UINT8 OfsBuf[0x04];
	UINT32 ROMPos;
	UINT32 DataAddr;
	UINT32 CurByt;
	UINT16 CurInst;
	
	// Try to find the offset manually.
	// Note: The 68k writes the current bank to Z80's 1C00/1C01 (MSB/LSB)
	//       and the pointer list offset to Z80's 1C02/1C03. (LSB/MSB)
	//       This doesn't work for SMPS Z80 only, but also for a few of
	//       the SMPS 68k DAC drivers.
	
	// Autodetection 1:
	// 1. Search for LEA $A01C00, A0 (41F9 00A0 1C00)
	// 2a. Then read the next two MOVE.B #??, (A0)+ instructions (10FC 00??)
	// 2b. Read the address of the next LEA A1, addr instruction (43F9 ...) and
	//     read the first 2 bytes from that offset.
	//
	// Autodetection 2:
	// 1. Search for MOVE.B #??, $A01C00.l (13FC 00?? 00A0 1C00)
	// 2. Read the consecutive writes.
	//
	// Autodetection 3:
	// 1. Search for LEA $A01C00, A1 (43F9 00A0 1C00)
	// 2. The instruction 4 bytes ago should be LEA addr(PC), A0 (41FA xxxx)
	
	WriteBE32(OfsBuf, Offset);
	for (ROMPos = 0x100; ROMPos < ROMLength - 0x20; ROMPos += 0x02)
	{
		if (! memcmp(&ROMData[ROMPos], OfsBuf, 0x04))
		{
			ROMPos += 0x04;
			CurInst = ReadBE16(&ROMData[ROMPos]);
			//if (CurInst == 0x10FC)	// 10FC 00aa	MOVE.B	#$aa, (A0)+
			if ((CurInst & ~0x0E00) == 0x10FC)
			{
				printf("Loader found at offset: %06X\n", ROMPos - 0x06);
				
				// [1a] Mazin Saga / King of the Monsters 1
				//	LEA		$A01C00, A0		41F9 00A0 1C00
				//	MOVE.B	#xx, (A0)+		10FC 00xx
				//	MOVE.B	#xx, (A0)+		10FC 00xx
				//	...
				for (CurByt = 0x00; CurByt < BytCount; CurByt ++, ROMPos += 0x04)
				{
					CurInst = ReadBE16(&ROMData[ROMPos]) & ~0x0E00;	// mask Ax bits out
					if (CurInst != 0x10FC)
					{
						if (ReadBE16(&ROMData[ROMPos]) == 0x10BC)
						{
							Buffer[CurByt] = ROMData[ROMPos + 0x03];
							CurByt ++;
						}
						break;
					}
					Buffer[CurByt] = ROMData[ROMPos + 0x03];
				}
				if (CurByt)
					return CurByt;
			}
			//else if (CurInst == 0x43F9)	// 43F9 addr	LEA	addr.l, A1
			else if ((CurInst & ~0x0E00) == 0x41F9 || CurInst == 0x45FA)	// 4xF9 addr	LEA	addr.l, Ax
			{
				printf("Loader found at offset: %06X\n", ROMPos - 0x06);
				
				// [1b] Battletoads
				//	LEA		$A01C00, A0		41F9 00A0 1C00
				//	LEA		addr, A1		43F9 0002 7582
				//	MOVE.W	#$0A, D1		323C 000A
				// loop:
				//	MOVE.B	(A1)+, (A0)+	10D9
				//	SUBQ.W	#1, D1			5341
				//	BNE.S	loop			66FA
				//	...
				DataAddr = ReadLEA(ROMData, ROMPos);
				if (! DataAddr)
				{
					printf("Failed to read LEA\n");
					continue;
				}
				if (ROMData[ROMPos + 0x01] == 0xF9)
					ROMPos += 0x06;
				else
					ROMPos += 0x04;
				
				CurByt = GetMoveB_APtoAP_Count(ROMPos);
				if (CurByt)
				{
					if (CurByt > BytCount)
						CurByt = BytCount;
					memcpy(Buffer, &ROMData[DataAddr], CurByt);
					return CurByt;
				}
			}
			else if (CurInst == 0x13FC)	// 13FC 00aa addr	MOVE.B	#$aa, addr.l
			{
				ROMPos -= 0x08;
				printf("Loader found at offset: %06X\n", ROMPos);
				
				// [2] King of the Monsters 2 / OutRun / OutRun 2019
				//	MOVE.B	#xx, $A01C00.l
				//	MOVE.B	#xx, $A01C01.l
				//	...
				CurByt = 0x00;
				/*for (CurByt = 0x00; CurByt < BytCount; CurByt ++, ROMPos += 0x08)
				{
					if (ReadBE16(&ROMData[ROMPos]) != 0x13FC)
						break;
					Buffer[CurByt] = ROMData[ROMPos + 0x03];
				}*/
				while(ReadBE16(&ROMData[ROMPos]) == 0x13FC)
				{
					DataAddr = ReadBE32(&ROMData[ROMPos + 0x04]);
					DataAddr -= Offset;
					if (DataAddr < BytCount)
					{
						Buffer[DataAddr] = ROMData[ROMPos + 0x03];
						if (CurByt <= DataAddr)
							CurByt = DataAddr + 0x01;
					}
					ROMPos += 0x08;
				}
				if (CurByt)
					return CurByt;
				else
					ROMPos += 0x06;
			}
			else if ((ReadBE16(&ROMData[ROMPos - 0x06]) & ~0x0E00) == 0x41F9 &&	// 43F9 addr	LEA	addr.l, A1
					(ReadBE16(&ROMData[ROMPos]) & ~0x0E00) == 0x117C)		// 117C data ofs	MOVE.B #data, ofs(A0)
			{
				printf("Loader found at offset: %06X\n", ROMPos - 0x06);
				
				// Puzzle & Action: Ichidant-R
				//	LEA		$A01C00, A0		41F9 00A0 1C00
				//	MOVE.B	#$00, $02(A0)	117C 0000 0002
				//	MOVE.B	#$80, $03(A0)	117C 0080 0003
				//	MOVE.W	#$1A80, $04(A0)	117C 1A80 0004	// Note: This actually doesn't work.
				//	MOVE.W	#$0100, $06(A0)	117C 0100 0006
				
				CurByt = 0x00;
				while((ReadBE16(&ROMData[ROMPos]) & ~0x2E00) == 0x117C)
				{
					DataAddr = ReadBE16(&ROMData[ROMPos + 0x04]);
					if (! (ROMData[ROMPos] & 0x20))
					{
						if (DataAddr < BytCount)
						{
							Buffer[DataAddr] = ROMData[ROMPos + 0x03];
							if (CurByt <= DataAddr)
								CurByt = DataAddr + 0x01;
						}
					}
					else
					{
						if (DataAddr + 0x01 < BytCount)
						{
							memcpy(&Buffer[DataAddr], &ROMData[ROMPos + 0x02], 0x02);
							if (CurByt + 0x01 <= DataAddr)
								CurByt = DataAddr + 0x02;
						}
					}
					ROMPos += 0x06;
				}
				if (CurByt)
					return CurByt;
			}
			else if ((ReadBE16(&ROMData[ROMPos - 0x06]) & ~0x0E00) == 0x41F9)	// 43F9 addr	LEA	addr.l, A1
			{
				ROMPos -= 0x06;
				printf("Loader found at offset: %06X\n", ROMPos);
				
				// [3] Yuu Yuu Hakusho Gaiden
				//	LEA		addr(PC), A0	41FA FF54
				//	LEA		$A01C00, A1		43F9 00A0 1C00
				//	MOVEQ	#7, D0			7007
				//	BSR.W	Transfer		6100 FEAA
				//	...
				// Transfer:
				//	MOVE.B	(A0)+, (A1)+	12D8
				//	DBRA	D0, Transfer	51C8 FFFC
				//	RTS						4E75
				
				if ((ROMData[ROMPos - 0x04] & ~0x0E) == 0x41)
					DataAddr = ReadLEA(ROMData, ROMPos - 0x04);
				else if ((ROMData[ROMPos - 0x06] & ~0x0E) == 0x41)
					DataAddr = ReadLEA(ROMData, ROMPos - 0x06);
				else
				{
					// TODO: Handle Columns III
					printf("failed to read previous LEA command!\n");
					ROMPos += 0x02;	// prevent infinite loop
					continue;
				}
				if (ROMData[ROMPos + 0x01] == 0xF9)
					ROMPos += 0x06;
				else
					ROMPos += 0x04;
				
				CurByt = GetMoveB_APtoAP_Count(ROMPos);
				if (CurByt)
				{
					if (CurByt > BytCount)
						CurByt = BytCount;
					memcpy(Buffer, &ROMData[DataAddr], CurByt);
					return CurByt;
				}
			}	// end if (Check Instruction)
		}	//end if (ROMData[ROMPos] == Offset)
	}	// end for (ROMPos)
	
	return 0x00;
}






// --- Song Extraction ---
UINT32 ScanForSonic1Ptrs(void)
{
	const UINT8 MAGIC_BYTES[0x08] = {0x07, 0x72, 0x73, 0x26, 0x15, 0x08, 0xFF, 0x05};
	UINT32 CurPos;
	
	printf("Trying to search for Music Pointer List ...");
	for (CurPos = 0x00; CurPos < ROMLength - 0x08; CurPos ++)
	{
		if (! memcmp(ROMData + CurPos, MAGIC_BYTES, 0x08))
		{
			CurPos += 0x08;
			printf("  found at %06X\n", CurPos);
			return CurPos;
		}
	}
	printf("  not found.\n");
	
	return 0x00;
}


// --- DAC Extraction ---
UINT32 ScanForZ80Drv_CompKos(void)
{
	// These bytes are the first bytes of the compressed Z80 DAC Driver.
	const UINT8 MAGIC_BYTES[0x08] = {0xE1, 0xFF, 0xF3, 0xFF, 0x31, 0xFC, 0x1F, 0xDD};
	UINT32 CurPos;
	
	printf("Trying to search for compressed Z80 DAC Driver ...");
	for (CurPos = 0x100; CurPos < ROMLength - 0x08; CurPos ++)
	{
		if (! memcmp(ROMData + CurPos, MAGIC_BYTES, 0x08))
		{
			printf("  found at %06X\n", CurPos);
			return CurPos;
		}
	}
	printf("  not found.\n");
	
	return 0x00;
}

UINT32 ScanForZ80Drv_Uncomp(void)
{
	// These bytes are the first bytes of the uncompressed Z80 DAC Driver.
	const UINT8 MAGIC_BYTES_1[0x08] =	// jman2050
		{0xF3, 0xF3, 0x31, 0xF0, 0x1F, 0x3E, 0x80, 0x0E};
	//const UINT8 MAGIC_BYTES_2[0x08] =	// Magical Taruruuto-Kun
	//	{0xF3, 0xF3, 0xF3, 0x31, 0xF3, 0x1F, 0xAF, 0x32};
	//const UINT8 MAGIC_BYTES_2[0x08] =	// Mighty Morphin Power Rangers - The Movie
	//	{0xF3, 0xF3, 0xF3, 0x31, 0x00, 0x1F, 0xAF, 0x32};
	//const UINT8 MAGIC_BYTES_2[0x08] =	// Fatal Fury
	//	{0xF3, 0xF3, 0xF3, 0x31, 0xF4, 0x1F, 0xAF, 0x32};
	//const UINT8 MAGIC_BYTES_3[0x08] =	// Ristar
	//	{0xF3, 0xF3, 0xF3, 0x31, 0xEA, 0x1F, 0x21, 0xEA};
	//const UINT8 MAGIC_BYTES_4[0x08] =	// MJ's Moonwalker
	//	{0xF3, 0xF3, 0xF3, 0x31, 0xF4, 0x1F, 0x3A, 0xFB};
	const UINT8 MAGIC_BYTES_GEN_68K[0x04] =	// DAC driver for most SMPS 68k games
		{0xF3, 0xF3, 0xF3, 0x31};
	const UINT8 MAGIC_BYTES_GEN_68K_2[0x04] =	// DAC driver for Battle Golfer Yui
		{0xF3, 0xF3, 0x31, 0xF4};
	const UINT8 MAGIC_BYTES_GEN_Z80[0x04] =	// Z80 sound driver for SMPS Z80 games
		{0xF3, 0xF3, 0xED, 0x56};
	const UINT8 MAGIC_BYTES_GEN_PRE[0x04] =	// Z80 sound driver for preSMPS SMPS 68k games
		{0xF3, 0xF3, 0x31, 0xF0};
	const UINT8 MAGIC_BYTES_VRD[0x04] =		// Virtua Racing Deluxe 32X
		{0xF3, 0xF3, 0x0E, 0x00};
	const UINT8 MAGIC_BYTES_PS4[0x04] =		// DAC driver for Phantasy Star IV
		{0xF3, 0xF3, 0x31, 0x00};
	UINT32 CurPos;
	
	printf("Trying to search for uncompressed Z80 Driver ...");
	for (CurPos = 0x100; CurPos < ROMLength - 0x08; CurPos ++)
	{
		if (! memcmp(ROMData + CurPos, MAGIC_BYTES_1, 0x08)/* ||
			! memcmp(ROMData + CurPos, MAGIC_BYTES_2, 0x08) ||
			! memcmp(ROMData + CurPos, MAGIC_BYTES_3, 0x08)*/)
		{
			printf("  found at %06X\n", CurPos);
			return CurPos;
		}
	}
	for (CurPos = 0x100; CurPos < ROMLength - 0x08; CurPos ++)
	{
		if (! memcmp(ROMData + CurPos, MAGIC_BYTES_GEN_68K, 0x04) ||
			! memcmp(ROMData + CurPos, MAGIC_BYTES_GEN_68K_2, 0x04) ||
			! memcmp(ROMData + CurPos, MAGIC_BYTES_GEN_Z80, 0x04) ||
			! memcmp(ROMData + CurPos, MAGIC_BYTES_GEN_PRE, 0x04) ||
			! memcmp(ROMData + CurPos, MAGIC_BYTES_VRD, 0x04) ||
			! memcmp(ROMData + CurPos, MAGIC_BYTES_PS4, 0x04))
		{
			if (ROMData[CurPos + 0x04] == 0x20 || ROMData[CurPos + 0x04] == 0xE2)
				continue;	// catch false detection of Z80 setup drivers
			
			if (ROMData[CurPos - 0x01] == 0xF3)
				CurPos --;
			printf("  found at %06X\n", CurPos);
			return CurPos;
		}
	}
	printf("  not found.\n");
	
	return 0x00;
}



static void AddZ80Part(Z80DRV_COMP* Z80Coll, UINT32 SrcOfs, UINT16 Len, UINT32 DstOfs)
{
	Z80DRV_PART* TempPart;
	
	if ((DstOfs & 0xFFE000) != 0xA00000)
		return;	// not Z80 RAM (must be A0 0000 .. A0 1FFF)
	if (! SrcOfs || SrcOfs >= 0xA00000)
		return;	// invalid or not 68k ROM
	
	if (Z80Coll->Count >= Z80Coll->Alloc)
	{
		Z80Coll->Alloc += 0x10;
		Z80Coll->Data = (Z80DRV_PART*)realloc(Z80Coll->Data, Z80Coll->Alloc * sizeof(Z80DRV_PART));
	}
	TempPart = &Z80Coll->Data[Z80Coll->Count];
	TempPart->SrcOfs = SrcOfs;
	TempPart->Length = Len;
	TempPart->DstOfs = DstOfs & 0x1FFF;
	Z80Coll->Count ++;
	
	return;
}

void GetZ80DriverParts(Z80DRV_COLL* Z80Coll)
{
	Z80DRV_COMP CurZ80Drv;
	char DatStStr[9];
	const char* AddText;
	UINT8 OfsBuf[0x04];
	UINT32 SearchPos;
	UINT32 CurPos;
	UINT32 CodePos;
	UINT16 CodeLen;
	UINT32 DataOfs;
	UINT16 DataLen;
	UINT32 Z80Ofs;
	
	CurZ80Drv.Alloc = 0;
	CurZ80Drv.Count = 0;
	CurZ80Drv.Data = NULL;
	
	WriteBE32(OfsBuf, 0xA00000);	// 68k space: A0 0000 - Z80 RAM
	SearchPos = 0x00;
	do
	{
		SearchPos = ScanForData(ROMLength, ROMData, 0x04, OfsBuf, SearchPos);
		if (SearchPos)
		{
			CodePos = GetCopyBlockStart(SearchPos);
			SearchPos ++;	// ensure that we don't start searching from the offset where we found the data
			if (CodePos)
			{
				printf("Z80 Loader found at %06X.\n", CodePos);
				DataOfs = 0x00;
				CurPos = CodePos;
				CodeLen = GetCopyData(CurPos, &DataOfs, &DataLen, &Z80Ofs);
				while(CodeLen)
				{
					if (DataOfs)
						sprintf(DatStStr, "%06X", DataOfs);
					else
						strcpy(DatStStr, "------");
					if (CodeLen & 0x8000)
						AddText = " (reused offsets)";
					else
						AddText = "";
					CodeLen &= 0x7FFF;
					printf("Data Start: %s, Length %04X, Destination: %06X%s\n", DatStStr, DataLen, Z80Ofs, AddText);
					AddZ80Part(&CurZ80Drv, DataOfs, DataLen, Z80Ofs);
					
					if (DataOfs)
						DataOfs += DataLen;	// for games like Columns that don't reload the data address
					Z80Ofs += DataLen;
					CurPos += CodeLen;
					CodeLen = GetCopyData(CurPos, &DataOfs, &DataLen, &Z80Ofs);
				}
				
				if (CurPos > SearchPos)
					SearchPos = CurPos;
				if (CurZ80Drv.Count && Z80Coll != NULL)
				{
					if (Z80Coll->Count >= Z80Coll->Alloc)
					{
						Z80Coll->Alloc += 0x10;
						Z80Coll->Data = (Z80DRV_COMP*)realloc(Z80Coll->Data, Z80Coll->Alloc * sizeof(Z80DRV_COMP));
					}
					Z80Coll->Data[Z80Coll->Count] = CurZ80Drv;
					Z80Coll->Count ++;
					CurZ80Drv.Alloc = 0;
					CurZ80Drv.Data = NULL;
				}
				CurZ80Drv.Count = 0;
			}
		}
	} while(SearchPos);
	
	free(CurZ80Drv.Data);
	printf("\n");
	
	return;
}

void GetZ80DriverParts_SegaNet(Z80DRV_COLL* Z80Coll)
{
	const UINT8 JSR_COPYZ80[] = {0x4E, 0xB8, 0xFC, 0x50};	// JSR	$FFFFFC50.w
	Z80DRV_COMP CurZ80Drv;
	UINT32 SearchPos;
	UINT32 CurPos;
	UINT32 CodePos;
	UINT16 CodeLen;
	UINT32 DataOfs;
	UINT16 DataLen;
	UINT32 Z80Ofs;
	UINT16 CurPart;
	Z80DRV_PART* Z80BaseDrv;	// containing sound code
	UINT32 AddrReg;
	
	CurZ80Drv.Alloc = 0;
	CurZ80Drv.Count = 0;
	CurZ80Drv.Data = NULL;
	Z80BaseDrv = NULL;
	
	SearchPos = 0x00;
	do
	{
		SearchPos = ScanForData(ROMLength, ROMData, sizeof(JSR_COPYZ80), JSR_COPYZ80, SearchPos);
		if (SearchPos)
		{
			CodePos = GetCopyBlockStart_SegaNet(SearchPos);
			SearchPos ++;	// ensure that we don't start searching from the offset where we found the data
			if (CodePos)
			{
				printf("SegaNet Z80 Loader found at %06X.\n", CodePos);
				DataOfs = 0x00;
				CurPos = CodePos;
				AddrReg = 0x000000;
				CodeLen = GetCopyData_SegaNet(CurPos, &AddrReg, &DataOfs, &DataLen, &Z80Ofs);
				while(CodeLen)
				{
					printf("Data Start: %06X, Length %04X, Destination: %06X\n", DataOfs, DataLen, Z80Ofs);
					AddZ80Part(&CurZ80Drv, DataOfs, DataLen, Z80Ofs);
					
					CurPos += CodeLen;
					CodeLen = GetCopyData_SegaNet(CurPos, &AddrReg, &DataOfs, &DataLen, &Z80Ofs);
				}
				
				if (CurPos > SearchPos)
					SearchPos = CurPos;
				if (CurZ80Drv.Count && Z80Coll != NULL)
				{
					DataOfs = 0xFFFF;
					for (CurPart = 0; CurPart < CurZ80Drv.Count; CurPart ++)
					{
						if (CurZ80Drv.Data[CurPart].DstOfs < DataOfs)
							DataOfs = CurZ80Drv.Data[CurPart].DstOfs;
						if (! CurZ80Drv.Data[CurPart].DstOfs)
						{
							Z80BaseDrv = &CurZ80Drv.Data[CurPart];	// save pointer to "driver base data"
							break;
						}
					}
					if (DataOfs && Z80BaseDrv != NULL)	// no "base data" found
					{
						// SegaNet games often keep the original sound driver,
						// so we'll add it to the new driver structure
						DataLen = CurZ80Drv.Count;
						AddZ80Part(&CurZ80Drv, Z80BaseDrv->SrcOfs, Z80BaseDrv->Length, 0xA00000);
						memmove(&CurZ80Drv.Data[1], &CurZ80Drv.Data[0], DataLen * sizeof(Z80DRV_PART));
						CurZ80Drv.Data[0] = *Z80BaseDrv;
					}
					
					if (Z80Coll->Count >= Z80Coll->Alloc)
					{
						Z80Coll->Alloc += 0x10;
						Z80Coll->Data = (Z80DRV_COMP*)realloc(Z80Coll->Data, Z80Coll->Alloc * sizeof(Z80DRV_COMP));
					}
					Z80Coll->Data[Z80Coll->Count] = CurZ80Drv;
					Z80Coll->Count ++;
					CurZ80Drv.Alloc = 0;
					CurZ80Drv.Data = NULL;
				}
				CurZ80Drv.Count = 0;
			}
		}
	} while(SearchPos);
	
	free(CurZ80Drv.Data);
	printf("\n");
	
	return;
}

UINT16 MakeZ80DriverDump(UINT8** RetData, Z80DRV_COMP* Z80Drv)
{
	UINT16 DrvLen;
	UINT8* DrvData;
	UINT16 MaxPos;
	UINT16 CurPart;
	UINT32 ROMPos;
	UINT16 Z80Pos;
	UINT16 CopyLen;
	
	*RetData = NULL;
	if (Z80Drv == NULL || ! Z80Drv->Count)
		return 0x0000;
	
	DrvLen = 0x2000;
	DrvData = (UINT8*)malloc(DrvLen);
	memset(DrvData, 0xAA, DrvLen);
	
	MaxPos = 0x0000;
	for (CurPart = 0; CurPart < Z80Drv->Count; CurPart ++)
	{
		ROMPos = Z80Drv->Data[CurPart].SrcOfs;
		// TODO: do 32x address patch
		CopyLen = Z80Drv->Data[CurPart].Length;
		Z80Pos = Z80Drv->Data[CurPart].DstOfs;
		
		if (Z80Pos + CopyLen > 0x2000)
			CopyLen = 0x2000 - Z80Pos;
		if (ROMPos + CopyLen > ROMLength)
			continue;
		memcpy(&DrvData[Z80Pos], &ROMData[ROMPos], CopyLen);
		Z80Pos += CopyLen;
		if (MaxPos < Z80Pos)
			MaxPos = Z80Pos;
	}
	
	*RetData = DrvData;
	return MaxPos;
}

void FreeZ80DriverComp(Z80DRV_COMP* Z80Drv)
{
	free(Z80Drv->Data);
	free(Z80Drv);
	
	return;
}

static UINT16 GetAddressCommand(UINT32 ROMPos, UINT32* RetOfs)
{
	// checks for a valid command that loads an address and returns the command length
	UINT16 CurInst;	// Instruction Code
	
	CurInst = ReadBE16(&ROMData[ROMPos]);
	if ((CurInst & ~0x0E03) == 0x41F8)
	{
		// 4xF8 addr	LEA	addr.w, Ax
		// 4xF9 addr	LEA	addr.l, Ax
		// 4xFA addr	LEA	(ofs, PC), Ax
		if (RetOfs != NULL)
			*RetOfs = ReadLEA(ROMData, ROMPos);
		return (CurInst & 0x0001) ? 0x06 : 0x04;
	}
	else if ((CurInst & ~0x1E00) == 0x207C)
	{
		// 2x7C addr	MOVEA.L	#addr, Ax
		// 3x7C addr	MOVEA.W	#addr, Ax
		if (CurInst & 0x1000)
		{
			if (RetOfs != NULL)
				*RetOfs = ReadBE16(&ROMData[ROMPos + 0x02]);
			return 0x04;
		}
		else
		{
			if (RetOfs != NULL)
				*RetOfs = ReadBE32(&ROMData[ROMPos + 0x02]);
			return 0x06;
		}
	}
	else if ((CurInst & ~0x0E00) == 0x2079)
	{
		// 2x79 addr	MOVEA.L	addr, Ax
		// 2x39 addr	MOVE.L	addr, Dx
		UINT32 SrcOfs;
		
		SrcOfs = ReadBE32(&ROMData[ROMPos + 0x02]);
		FixMarsPointer(&SrcOfs);
		if (RetOfs != NULL)
			*RetOfs = ReadBE32(&ROMData[SrcOfs]);
		return 0x06;
	}
	return 0x00;
}

static UINT16 GetMoveCommand(UINT32 ROMPos, UINT32* RetVal)
{
	// checks for a valid command that loads a value into Dx and returns the command length
	UINT16 CurInst;	// Instruction Code
	
	CurInst = ReadBE16(&ROMData[ROMPos]);
	if ((CurInst & 0xF100) == 0x7000)	// 7Exx			MOVEQ	#xx, D7
	{
		if (RetVal != NULL)
			*RetVal = (INT8)ROMData[ROMPos + 0x01];
		return 0x02;
	}
	
	CurInst &= 0xF1FF;	// mask Dx register number out
	if (CurInst == 0x103C)	// 103C 00xx	MOVE.B	#xx, D0
	{
		if (RetVal != NULL)
			*RetVal = ROMData[ROMPos + 0x03];
		return 0x04;
	}
	else if (CurInst == 0x203C)	// 203C xxxx xxxx	MOVE.L	#xxxxxxxx, D0
	{
		if (RetVal != NULL)
			*RetVal = ReadBE32(&ROMData[ROMPos + 0x02]);
		return 0x08;
	}
	else if (CurInst == 0x303C)	// 303C xxxx	MOVE.W	#xxxx, D0
	{
		if (RetVal != NULL)
			*RetVal = ReadBE16(&ROMData[ROMPos + 0x02]);
		return 0x04;
	}
	else if (CurInst == 0x2039)
	{
		// 2x39 addr	MOVE.L	addr, Dx
		UINT32 SrcOfs;
		
		SrcOfs = ReadBE32(&ROMData[ROMPos + 0x02]);
		FixMarsPointer(&SrcOfs);
		if (RetVal != NULL)
			*RetVal = ReadBE32(&ROMData[SrcOfs]);
		return 0x06;
	}
	
	return 0x00;
}

static UINT16 GetJumpCommand(UINT32 ROMPos, UINT32* RetOfs)
{
	// checks for a valid command that jumps to a location and returns the destination address
	UINT16 CurInst;	// Instruction Code
	
	CurInst = ReadBE16(&ROMData[ROMPos]);
	if ((CurInst & 0xF000) == 0x6000)	// BRA/BSR and variants
	{
		ROMPos += 0x02;
		if (CurInst & 0x00FF)	// BRA.S
		{
			if (RetOfs != NULL)
				*RetOfs = ROMPos + (INT8)(CurInst & 0x00FF);
			return 0x02;
		}
		else	// BRA.W
		{
			if (RetOfs != NULL)
				*RetOfs = ROMPos + (INT16)ReadBE16(&ROMData[ROMPos]);
			return 0x04;
		}
	}
	else if ((CurInst & ~0x0043) == 0x4EB8)
	{
		// 4EF8 addr	JMP	addr.w, Ax
		// 4EF9 addr	JMP	addr.l, Ax
		// 4EFA addr	JMP	(ofs, PC), Ax
		return ReadDisplc(ROMData, ROMPos, RetOfs);
	}
	return 0x00;
}

static UINT16 GetCopyData(UINT32 BasePos, UINT32* DataOfs, UINT16* DataLen, UINT32* DataDstOfs)
{
	UINT8 FoundInst;
	UINT8 ReadReg;
	UINT8 WriteReg;
	UINT8 DataAddrReg[2];
	UINT32 DataAddrVal[2];
	UINT32 SrcDataAddr;
	UINT32 SrcDataLen;
	UINT32 DstDataAddr;
	
	UINT32 CurPos;
	UINT32 CpyCodePos;
	UINT16 CurInst;	// Instruction
	UINT16 CmdLen;
	
	DataAddrVal[0] = 0x00;
	DataAddrVal[1] = 0x00;
	FoundInst = 0x00;
	
	CurPos = BasePos;
	CmdLen = GetMoveCommand(CurPos, &SrcDataLen);	// check for MOVE.W command (Mickey Mouse: Castle of Illusion)
	if (CmdLen)
	{
		CurPos += CmdLen;
		FoundInst |= 0x04;	// data length found
	}
	
	CmdLen = GetAddressCommand(CurPos, &DataAddrVal[0]);
	if (! CmdLen)
		return 0;
	DataAddrReg[0] = (ROMData[CurPos] >> 1) & 0x07;
	
	CurPos += CmdLen;
	FoundInst |= 0x01;	// destination address found
	
	// --- Step 1: Check for an address command right after the offset write ---
	CurInst = ReadBE16(&ROMData[CurPos]);
	while(CurInst == 0x4E71)
	{
		CurPos += 0x02;	// skip NOPs
		CurInst = ReadBE16(&ROMData[CurPos]);
	}
	
	CmdLen = GetMoveCommand(CurPos, &SrcDataLen);	// check for MOVE.W command (Mickey Mouse: Castle of Illusion)
	if (CmdLen)
	{
		CurPos += CmdLen;
		FoundInst |= 0x04;	// data length found
	}
	
	if (ReadBE16(&ROMData[CurPos]) == 0x5380)	// SUBQ.L	#1, D0
	{
		SrcDataLen --;
		CurPos += 0x02;
	}
	
	CmdLen = GetAddressCommand(CurPos, &DataAddrVal[1]);
	if (CmdLen)
	{
		DataAddrReg[1] = (ROMData[CurPos] >> 1) & 0x07;
		CurPos += CmdLen;
		FoundInst |= 0x02;	// source address found
	}
	CpyCodePos = CurPos;
	
	// --- Step 2: get length of data to be written ---
	if (! (FoundInst & 0x04))
	{
		CmdLen = GetMoveCommand(CpyCodePos, &SrcDataLen);
		if (CmdLen)
		{
			CpyCodePos += CmdLen;
			FoundInst |= 0x04;	// data length found
		}
	}
	if (! (FoundInst & 0x04))
	{
		CmdLen = GetMoveCommand(BasePos - 0x04, &SrcDataLen);
		if (CmdLen)
			FoundInst |= 0x04;	// data length found
	}
	//if (~FoundInst & 0x07)
	if (~FoundInst & 0x05)	// don't be as strict with the data value for now
		return 0;	// didn't find all 3 values - exit
	
	ReadReg = 0xFF;
	WriteReg = 0xFF;
	// --- Step 3: evaluate loop to estimate code size ---
	// Also detects if a DBRA loop is used and thus SrcDataLen is 1 smaller.
	CurPos = CpyCodePos;
	do
	{
		CurInst = ReadBE16(&ROMData[CurPos]);
		CmdLen = 0x00;
		if (CurInst == 0x4E71)
		{
			// 4E71 NOP
			CmdLen = 0x02;
		}
		else if ((CurInst & 0xF000) == 0x1000)
		{
			// one of the MOVE.B instructions
			CmdLen = 0x02;
			if ((CurInst & 0xF1F0) == 0x1010)		// MOVE.B	(Ax), Dx [1010] / (Ax)+, Dx [1018]
				ReadReg = (CurInst & 0x0007) >> 0;
			else if ((CurInst & 0xF1B8) == 0x1080)	// MOVE.B	Dx, (Ax) [1080] / Dx, (Ax)+ [10C0]
				WriteReg = (CurInst & 0x0E00) >> 17;
			else if ((CurInst & 0xF1B0) == 0x1090)	// MOVE.B	(Ax), (Ax) [1090] / (Ax)+, (Ax)+ [10D8]
			{
				ReadReg = (CurInst & 0x0007) >> 0;
				WriteReg = (CurInst & 0x0E00) >> 17;
			}
		}
		else if ((CurInst & 0xF0F8) == 0x50C8)
		{
			// 51Cx DBRA.x (the various conditions use 5xC8-5xCF)
			CmdLen = 0x04;
			SrcDataLen ++;	// DBRA breaks on underflow, not when reaching 0, so compensate for that
			break;
		}
		else if ((CurInst & 0xF100) == 0x5100 || (CurInst & 0xF000) == 0x9000)
		{
			// 51xx SUBQ.x instruction
			// 90xx SUB.x instruction
			// I won't catch the various addressing modes here and just assume 1-word commands
			CmdLen = 0x02;
		}
		else if ((CurInst & 0xF100) == 0x0400)
		{
			// 04xx SUBI.x instruction
			// I won't catch the various addressing modes here and just assume 1-word commands
			if ((CurInst & 0x00C0) == 0x0000)
				CmdLen = 0x04;	// SUBI.B
			else if ((CurInst & 0x00C0) == 0x0000)
				CmdLen = 0x04;	// SUBI.W
			else if ((CurInst & 0x00C0) == 0x0000)
				CmdLen = 0x06;	// SUBI.L
		}
		else if ((CurInst & 0xF000) == 0x6000)
		{
			// BRA/BSR and conditional branches
			if ((CurInst & 0x00FF) == 0x0000)
				CmdLen = 0x04;	// BRA.W
			else
				CmdLen = 0x02;	// BRA.S
			/*if ((CurInst & 0xFF00) == 0x6100)
				break;	// break on BSR*/
			if ((CurInst & 0xFF00) == 0x6600)
				break;	// BNE usually marks the end of the loop
		}
		else if ((CurInst & 0xFFF0) == 0x4210)	// CLR.B
		{
			if (WriteReg == (CurInst & 0x0007))
			{
				if (WriteReg == DataAddrReg[0])
					DataAddrVal[0] = 0x00;
				else
					DataAddrVal[1] = 0x00;
				FoundInst |= 0x02;
			}
		}
		CurPos += CmdLen;
	} while(CmdLen);
	CurPos += CmdLen;
	
	if (ReadReg == 0xFF && WriteReg == 0xFF)
	{
		if ((DataAddrVal[0] & 0xFF0000) == 0xA00000)
		{
			ReadReg = DataAddrReg[1];
			WriteReg = DataAddrReg[0];
		}
		else
		{
			ReadReg = DataAddrReg[0];
			WriteReg = DataAddrReg[1];
		}
	}
	else if (ReadReg == 0xFF)
	{
		if (WriteReg == DataAddrReg[0])
			ReadReg = DataAddrReg[1];
		else
			ReadReg = DataAddrReg[0];
	}
	else if (WriteReg == 0xFF)
	{
		if (ReadReg == DataAddrReg[0])
			WriteReg = DataAddrReg[1];
		else
			WriteReg = DataAddrReg[0];
	}
	
	// assign the read Addresses to Source and Destination, depending on which register was read and wrote
	if (ReadReg == DataAddrReg[0])
	{
		SrcDataAddr = DataAddrVal[0];
		DstDataAddr = DataAddrVal[1];
	}
	else
	{
		SrcDataAddr = DataAddrVal[1];
		DstDataAddr = DataAddrVal[0];
	}
	FixMarsPointer(&SrcDataAddr);
	FixMarsPointer(&DstDataAddr);
	
	// The offsets are kept if not found.
	if (DataOfs != NULL && SrcDataAddr)
		*DataOfs = SrcDataAddr;
	if (DataLen != NULL)
		*DataLen = SrcDataLen;
	if (DataDstOfs != NULL && DstDataAddr)
		*DataDstOfs = DstDataAddr;
	
	if (FoundInst & 0x02)
		return CurPos - BasePos;
	else
		return 0x8000 | (CurPos - BasePos);
}

static UINT32 GetCopyBlockStart(UINT32 ROMPos)
{
	UINT32 CurPos;
	UINT32 BasePos;
	UINT16 CurInst;	// Instruction
	UINT16 CmdLen;
	
	if (ROMPos & 0x01)
		return 0;	// uneven address - this can't work
	BasePos = ROMPos - 0x02;
	CmdLen = GetAddressCommand(BasePos, NULL);
	if (! CmdLen)
		return 0;
	
	CurPos = BasePos;
	do
	{
		CurPos -= 0x02;
		CurInst = ReadBE16(&ROMData[CurPos]);
	} while(CurInst == 0x4E71);	// skip NOPs
	
	if (CurInst == 0x5380)	// SUBQ.L	#1, D0
	{
		CurPos -= 0x06;
		CmdLen = GetMoveCommand(CurPos, NULL);
		if (CmdLen)
		{
			CurPos -= 0x06;
			CmdLen = GetAddressCommand(CurPos, NULL);
			if (CmdLen)
				return CurPos;
		}
	}
	else
	{
		CurPos += 0x02;
		CmdLen = GetAddressCommand(CurPos - 0x04, NULL);
		if (CmdLen)
			return CurPos - 0x04;
	
		CmdLen = GetAddressCommand(CurPos - 0x06, NULL);
		if (CmdLen)
			return CurPos - 0x06;
	}
	
	return BasePos;
}

static UINT16 GetCopyData_SegaNet(UINT32 BasePos, UINT32* StructAddr,
									UINT32* DataOfs, UINT16* DataLen, UINT32* DataDstOfs)
{
	UINT32 CurPos;
	UINT32 SrcDataAddr;
	UINT32 SrcDataLen;
	UINT32 DstDataAddr;
	UINT32 RegD[3];	// D0 - Byte Count-1, D1 - Z80 Destination Address, D2 - Z80 Reset/Resume
	UINT8 CurMove;
	UINT8 RegID;
	UINT16 CmdLen;
	UINT16 CurInst;	// Instruction
	
	CurPos = BasePos;
	CurInst = ReadBE16(&ROMData[CurPos]);
	if (CurInst == 0x0C78 || CurInst == 0x4A79)
	{
		CmdLen = GetJumpCommand(CurPos + 0x06, &DstDataAddr);
		if (CmdLen)
		{
			static char TempStr[0x20];
			
			if (CurInst == 0x0C78)		// CMPI.B	#val, ofs.w
				sprintf(TempStr, "CMPI.B  #$%02X, $%04X.w", ROMData[CurPos + 0x03],
						ReadBE16(&ROMData[CurPos + 0x04]));
			else if (CurInst == 0x4A79)	// TST.W	ofs.l
				sprintf(TempStr, "TST.W   $%08X.l", ReadBE32(&ROMData[CurPos + 0x02]));
			printf("Warning: Taking branch, skipping struct! (%s)\n", TempStr);
			CurPos = DstDataAddr;
		}
	}
	
	if (GetJumpCommand(CurPos, NULL) || ReadLEA(ROMData, CurPos))
	{
		CmdLen = GetCopyData_SegaNet_Struct(CurPos, StructAddr, DataOfs, DataLen, DataDstOfs);
		if (! CmdLen)
			return 0;
		else
			return (CurPos - BasePos) + CmdLen;
	}

	for (CurMove = 0; CurMove < 3; CurMove ++)
	{
		RegID = (ROMData[CurPos] & 0x0E) >> 1;
		if (RegID >= 3)
			return 0;
		CmdLen = GetMoveCommand(CurPos, &RegD[RegID]);
		if (! CmdLen)
			return 0;
		CurPos += CmdLen;
	}
	CmdLen = GetAddressCommand(CurPos, &SrcDataAddr);
	if (! CmdLen)
		return 0;
	CurPos += CmdLen;
	
	if (ReadBE16(&ROMData[CurPos]) == 0x4EB8)
		CurPos += 0x04;
	else
		printf("SegaNet Block at %06X not finished with JSR call!\n", BasePos);
	
	SrcDataLen = RegD[0] + 1;
	DstDataAddr = 0xA00000 | RegD[1];
	
	// The offsets are kept if not found.
	if (DataOfs != NULL && SrcDataAddr)
		*DataOfs = SrcDataAddr;
	if (DataLen != NULL)
		*DataLen = SrcDataLen;
	if (DataDstOfs != NULL && DstDataAddr)
		*DataDstOfs = DstDataAddr;
	
	return CurPos - BasePos;
}

static UINT16 GetCopyData_SegaNet_Struct(UINT32 BasePos, UINT32* StructAddr,
										UINT32* DataOfs, UINT16* DataLen, UINT32* DataDstOfs)
{
	UINT32 LastPos;
	UINT32 CurPos;
	UINT32 SrcDataAddr;
	UINT32 SrcDataLen;
	UINT32 DstDataAddr;
	UINT16 CmdLen;
	
	LastPos = 0x00;
	CurPos = BasePos;
	do
	{
		CmdLen = GetAddressCommand(CurPos, StructAddr);
		CurPos += CmdLen;
		
		CmdLen = GetMoveCommand(CurPos, NULL);
		CurPos += CmdLen;	// skip MOVEQ #2, D2
	
		CmdLen = GetJumpCommand(CurPos, &DstDataAddr);
		if (CmdLen)
		{
			if (! LastPos)
				LastPos = CurPos + CmdLen;
			CurPos = DstDataAddr;
		}
	} while(CmdLen);
	if (! *StructAddr)
		return 0;
	
	if (! LastPos)
		LastPos = CurPos;
	
	if (ReadBE32(&ROMData[CurPos]) == 0x4C990103)	// MOVEM.W	(A1)+, D0-D1/A0
	{
		printf("SegaNet Z80 Copy Struct: %06X\n", *StructAddr);
		CurPos = *StructAddr;
		SrcDataLen = ReadBE16(&ROMData[CurPos + 0x00]) + 1;
		DstDataAddr = 0xA00000 | ReadBE16(&ROMData[CurPos + 0x02]);
		SrcDataAddr = (CurPos & 0xFF0000) | ReadBE16(&ROMData[CurPos + 0x04]);
		(*StructAddr) += 0x06;
	}
	else if (ReadBE32(&ROMData[CurPos + 0x00]) == 0x4C990003 &&	// MOVEM.W	(A1)+, D0-D1
			ReadBE16(&ROMData[CurPos + 0x04]) == 0x2059)		// MOVEA.L	(A1)+, A0
	{
		printf("SegaNet Z80 Copy Struct: %06X (longword address)\n", *StructAddr);
		CurPos = *StructAddr;
		SrcDataLen = ReadBE16(&ROMData[CurPos + 0x00]) + 1;
		DstDataAddr = 0xA00000 | ReadBE16(&ROMData[CurPos + 0x02]);
		SrcDataAddr = ReadBE32(&ROMData[CurPos + 0x04]);
		(*StructAddr) += 0x08;
	}
	else
	{
		return 0;
	}
	
	// The offsets are kept if not found.
	if (DataOfs != NULL && SrcDataAddr)
		*DataOfs = SrcDataAddr;
	if (DataLen != NULL)
		*DataLen = SrcDataLen;
	if (DataDstOfs != NULL && DstDataAddr)
		*DataDstOfs = DstDataAddr;
	
	return LastPos - BasePos;
}

static UINT32 GetCopyBlockStart_SegaNet(UINT32 ROMPos)
{
	//	0035B6	303C 0FE5		MOVE.W	#$0FE5, D0	; Byte Count
	//	0035BA	7200			MOVEQ	#$0000, D1	; Z80 Dest. Address
	//	0035BC	7402			MOVEQ	#2, D2
	//	0035BE	41F9 0000 956E	LEA		$00956E.l, A0
	//	0035C4	4EB8 FC50		JSR		$FFFFFC50.w
	UINT32 CurPos;
	UINT32 BasePos;
	UINT16 CmdLen;
	UINT8 CurMove;
	
	if (ROMPos & 0x01)
		return 0;	// uneven address - this can't work
	BasePos = ROMPos - 0x04;
	CmdLen = GetAddressCommand(BasePos, NULL);
	if (! CmdLen)
	{
		BasePos -= 0x02;
		CmdLen = GetAddressCommand(BasePos, NULL);
		if (! CmdLen)
			return 0;
	}
	
	for (CurMove = 0; CurMove < 3; CurMove ++)
	{
		BasePos -= 0x02;
		if ((ROMData[BasePos] & 0xF1) != 0x70)	// check for MOVEQ
		{
			BasePos -= 0x02;
			if ((ReadBE16(&ROMData[BasePos]) & 0xF1FF) != 0x303C)	// check for MOVE.W
				return 0;
		}
	}
	
	CurPos = BasePos;
	while(1)
	{
		if (ReadBE16(&ROMData[CurPos - 0x04]) == 0x6100)
			CurPos -= 0x04;
		else if ((ROMData[CurPos - 0x02] & 0xF0) == 0x60)
			CurPos -= 0x02;
		else if (GetAddressCommand(CurPos - 0x04, NULL))
		{
			CurPos -= 0x04;
			BasePos = CurPos;
		}
		else if (GetAddressCommand(CurPos - 0x06, NULL))
		{
			CurPos -= 0x06;
			BasePos = CurPos;
		}
		else if (ReadBE16(&ROMData[CurPos - 0x06]) == 0x0C78)	// CMPI.W #val, ofs.w
		{
			CurPos -= 0x06;
		}
		else if (ReadBE16(&ROMData[CurPos - 0x06]) == 0x4A79)	// TST.W ofs.l
		{
			CurPos -= 0x06;
		}
		else
			break;
	};
	
	if (ReadBE16(&ROMData[BasePos - 0x04]) != 0x4EB8)
		printf("Backtracing to JSR failed! SegaNet Loader might be incomplete!\n");
	
	return BasePos;
}
