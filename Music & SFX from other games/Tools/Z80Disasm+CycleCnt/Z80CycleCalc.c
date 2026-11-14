// Z80 Disassembler and Cycle Counter
// ----------------------------------
// Written by Valley Bell within 2 days
//
// 26 January: All instructions, except for ED xx
// 27 January: ED xx instructions, a few IX/IY fixes, added all the options
//
// This tool was written with the help of "The Undocumented Z80 Documented" v0.91 by Sean Young.


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <malloc.h>
#include <memory.h>
#include "stdtype.h"


#define REG_B		0x00
#define REG_C		0x01
#define REG_D		0x02
#define REG_E		0x03
#define REG_H		0x04
#define REG_L		0x05
#define REG_SPECIAL	0x06
#define REG_A		0x07

#define REG_IXH		0x20
#define REG_IXL		0x21
#define REG_IYH		0x22
#define REG_IYL		0x23
#define REG_I		0x24
#define REG_R		0x25

#define REG_BC		0x10
#define REG_DE		0x11
#define REG_HL		0x12	// can be swapped with IX/IY
#define REG_SP		0x13
#define REG_AF		0x14
#define REG_HL2		0x15
#define REG_IX		0x16
#define REG_IY		0x17
#define REG_FROM_MASK	0x08
#define REG_FROM_HL	(REG_HL | REG_FROM_MASK)	// 0x1A

#define REG_NUM8	0x40
#define REG_NUM16	0x41
#define REG_NUM4	0x42	// for BIT, SET, RES
#define REG_ABS_OFS	0x44
#define REG_REL_OFS	0x45

#define REG_NONE	0xFF

#define COND_NONE	0xFF

static const char* REGISTER_LIST[] =
{	"B", "C", "D", "E", "H", "L", NULL, "A",
	"BC", "DE", "HL", "SP", "AF", "HL", "IX", "IY",
	"IXh", "IXl", "IYh", "IYl", "I", "R", NULL, NULL};
static const char* CONDCODE_LIST[] =
{	"NZ", "Z", "NC", "C", "PO", "PE", "P", "M"};

enum
{
	MN_NOP = 0x00,
	MN_HALT,
	
	MN_DI,
	MN_EI,
	MN_IM,
	
	MN_EX = 0x08,
	MN_EXX,
	
	MN_IX_PREF = 0x0C,
	MN_IY_PREF,
	
	MN_DJNZ = 0x10,
	MN_JR,
	MN_JP,
	MN_RST,
	MN_CALL,
	MN_RET,
	MN_RETI,
	MN_RETN,
	
	MN_LD = 0x20,
	MN_OUT,
	MN_IN,
	
	MN_POP = 0x24,
	MN_PUSH,
	
	MN_LDI = 0x30,
	MN_CPI,
	MN_INI,
	MN_OUTI,
	MN_LDD,		// 0x34
	MN_CPD,
	MN_IND,
	MN_OUTD,
	MN_LDIR,	// 0x38
	MN_CPIR,
	MN_INIR,
	MN_OTIR,
	MN_LDDR,	// 0x3C
	MN_CPDR,
	MN_INDR,
	MN_OTDR,
	
	MN_INC = 0x40,
	MN_DEC,
	
	MN_ADD,
	MN_ADC,
	MN_SUB,
	MN_SBC,
	MN_AND,
	MN_XOR,
	MN_OR,
	MN_CP,
	
	MN_RLCA = 0x50,
	MN_RRCA,
	MN_RLA,
	MN_RRA,
	MN_DAA,
	MN_CPL,
	MN_SCF,
	MN_CCF,
	MN_NEG,
	
	MN_RLC = 0x60,
	MN_RRC,
	MN_RL,
	MN_RR,
	MN_SLA,
	MN_SRA,
	MN_SLL,
	MN_SRL,
	MN_RRD,
	MN_RLD,
	
	MN_BIT = 0x70,
	MN_RES,
	MN_SET,
	
	MN_ERROR = 0x7F
};

typedef struct _instruction_data
{
	UINT8 Instruction;
	UINT8 Size;
	UINT8 Cycles;
	UINT8 CyclesB;
	UINT8 Condition;
	UINT8 SrcReg;
	UINT8 DstReg;
	UINT8 SideFXReg;
	UINT16 SrcVal;
	UINT16 DstVal;
} INST_DATA;

#define OPTION_USE_IREG		0x01	// use IX/IY displacement
#define OPTION_IREG_IX		0x00	// Bit 1 == 0
#define OPTION_IREG_IY		0x02	// Bit 1 == 1
#define OPTION_NO_PREF_EXEC	0x10	// don't process Prefix+Instruction at once

static const UINT8 CALC_MN[8] =
{	MN_ADD, MN_ADC, MN_SUB, MN_SBC,
	MN_AND, MN_XOR, MN_OR, MN_CP};
static const UINT8 ROT_ARITHM_MN[8] =
{	MN_RLCA, MN_RRCA, MN_RLA, MN_RRA,
	MN_DAA, MN_CPL, MN_SCF, MN_CCF};
static const UINT8 ROT_SHIFT_REG_MN[8] =
{	MN_RLC, MN_RRC, MN_RL, MN_RR,
	MN_SLA, MN_SRA, MN_SLL, MN_SRL};

static const char* MNEMONICS[0x80];


static void InitMnemonics(void);
static void HandlePrefix(const UINT8* Code, INST_DATA* Result, UINT8 Options, UINT8 DispCycles);
static UINT8 CheckAndDoPrefix_Single(UINT8* Register, UINT8 Options);
static UINT8 CheckAndDoPrefix(INST_DATA* Result, UINT8 Options);
static void DisassembleInstruction(const UINT8* Code, UINT8 Options, INST_DATA* Result);
static void DisassembleEDInstruction(const UINT8* Code, UINT8 Options, INST_DATA* Result);
int main(int argc, char* argv[]);
static UINT8 PrintRegister(char* Buffer, UINT8 Reg, UINT16 Data, UINT16 BaseOfs);
static void ShowDisassembledLine(char* Buffer, UINT16 Pos, const UINT8* CodeData, INST_DATA* InsData);
static UINT8 CalculateZ80Cycles(UINT16 StartOfs, UINT16 EndOfs);
static UINT16 ReadLE16(const UINT8* Data);
static void print_hex_data(UINT16 DataSize, const UINT8* DataPtr);


static UINT32 BinLen;
static UINT8* BinData;
static UINT8* BinMask;

static UINT8 SPACE_OPS;		// put spaces between operators
static UINT8 STOP_START_JP;	// stop at jump to start offset
static UINT8 IGNORE_JPRET;	// ignore jump and return instructions
static UINT8 PRINT_A;		// 00 - never, 01 - ADD/ADC/SBC only, 02 - always
static UINT8 SPLIT_PREFIX;	// split prefix instruction
static UINT8 SHOW_OFFSET;	// show current offset
static UINT8 SHOW_DATA;		// show instruction data bytes
static UINT8 SHOW_CYCLES;	// show cycles per instruction
static UINT8 CYCLE_SMRY;	// show cycle summary

static void InitMnemonics(void)
{
	unsigned int CurIdx;
	
	for (CurIdx = 0x00; CurIdx < 0x80; CurIdx ++)
		MNEMONICS[CurIdx] = NULL;
	
	MNEMONICS[MN_NOP] = "NOP";
	MNEMONICS[MN_HALT] = "HALT";
	
	MNEMONICS[MN_DI] = "DI";
	MNEMONICS[MN_EI] = "EI";
	MNEMONICS[MN_IM] = "IM";
	
	MNEMONICS[MN_EX] = "EX";
	MNEMONICS[MN_EXX] = "EXX";
	
	MNEMONICS[MN_IX_PREF] = "prefIX";
	MNEMONICS[MN_IY_PREF] = "prefIY";
	
	MNEMONICS[MN_DJNZ] = "DJNZ";
	MNEMONICS[MN_JR] = "JR";
	MNEMONICS[MN_JP] = "JP";
	MNEMONICS[MN_RST] = "RST";
	MNEMONICS[MN_CALL] = "CALL";
	MNEMONICS[MN_RET] = "RET";
	MNEMONICS[MN_RETI] = "RETI";
	MNEMONICS[MN_RETN] = "RETN";
	
	MNEMONICS[MN_LD] = "LD";
	MNEMONICS[MN_OUT] = "OUT";
	MNEMONICS[MN_IN] = "IN";
	
	MNEMONICS[MN_POP] = "POP";
	MNEMONICS[MN_PUSH] = "PUSH";
	
	MNEMONICS[MN_LDI] = "LDI";
	MNEMONICS[MN_CPI] = "CPI";
	MNEMONICS[MN_INI] = "INI";
	MNEMONICS[MN_OUTI] = "OUTI";
	MNEMONICS[MN_LDD] = "LDD";
	MNEMONICS[MN_CPD] = "CPD";
	MNEMONICS[MN_IND] = "IND";
	MNEMONICS[MN_OUTD] = "OUTD";
	MNEMONICS[MN_LDIR] = "LDIR";
	MNEMONICS[MN_CPIR] = "CPIR";
	MNEMONICS[MN_INIR] = "INIR";
	MNEMONICS[MN_OTIR] = "OTIR";
	MNEMONICS[MN_LDDR] = "LDDR";
	MNEMONICS[MN_CPDR] = "CPDR";
	MNEMONICS[MN_INDR] = "INDR";
	MNEMONICS[MN_OTDR] = "OTDR";
	
	MNEMONICS[MN_INC] = "INC";
	MNEMONICS[MN_DEC] = "DEC";
	
	MNEMONICS[MN_ADD] = "ADD";
	MNEMONICS[MN_ADC] = "ADC";
	MNEMONICS[MN_SUB] = "SUB";
	MNEMONICS[MN_SBC] = "SBC";
	MNEMONICS[MN_AND] = "AND";
	MNEMONICS[MN_XOR] = "XOR";
	MNEMONICS[MN_OR] = "OR";
	MNEMONICS[MN_CP] = "CP";
	
	MNEMONICS[MN_RLCA] = "RLCA";
	MNEMONICS[MN_RRCA] = "RRCA";
	MNEMONICS[MN_RLA] = "RLA";
	MNEMONICS[MN_RRA] = "RRA";
	MNEMONICS[MN_DAA] = "DAA";
	MNEMONICS[MN_CPL] = "CPL";
	MNEMONICS[MN_SCF] = "SCF";
	MNEMONICS[MN_CCF] = "CCF";
	MNEMONICS[MN_NEG] = "NEG";
	
	MNEMONICS[MN_RLC] = "RLC";
	MNEMONICS[MN_RRC] = "RRC";
	MNEMONICS[MN_RL] = "RL";
	MNEMONICS[MN_RR] = "RR";
	MNEMONICS[MN_SLA] = "SLA";
	MNEMONICS[MN_SRA] = "SRA";
	MNEMONICS[MN_SLL] = "SLL";
	MNEMONICS[MN_SRL] = "SRL";
	MNEMONICS[MN_RRD] = "RRD";
	MNEMONICS[MN_RLD] = "RLD";
	
	MNEMONICS[MN_BIT] = "BIT";
	MNEMONICS[MN_RES] = "RES";
	MNEMONICS[MN_SET] = "SET";
	
	return;
}


static void HandlePrefix(const UINT8* Code, INST_DATA* Result, UINT8 Options, UINT8 DispCycles)
{
	if (! (Options & OPTION_USE_IREG))
		return;
	
	if (Result->SrcReg == REG_FROM_HL)
	{
		Result->Cycles += DispCycles;	// add cycles needed to read the displacement value
		Result->SrcVal = Code[Result->Size];
		Result->Size ++;
	}
	if (Result->DstReg == REG_FROM_HL)
	{
		Result->Cycles += DispCycles;
		Result->DstVal = Code[Result->Size];
		Result->Size ++;
	}
	
	return;
}

static UINT8 CheckAndDoPrefix_Single(UINT8* Register, UINT8 Options)
{
	if (*Register == REG_H || *Register == REG_L)
	{
		if (! (Options & OPTION_IREG_IY))
			*Register += (REG_IXH - REG_H);
		else
			*Register += (REG_IYH - REG_H);
		return 0x01;
	}
	else if ((*Register & ~REG_FROM_MASK) == REG_HL)
	{
		if (! (Options & OPTION_IREG_IY))
			*Register = (*Register & REG_FROM_MASK) | REG_IX;
		else
			*Register = (*Register & REG_FROM_MASK) | REG_IY;
		return 0x01;
	}
	
	return 0x00;
}

static UINT8 CheckAndDoPrefix(INST_DATA* Result, UINT8 Options)
{
	UINT8 RetMask;
	
	RetMask = 0x00;
	if (Result->SrcReg == REG_FROM_HL)
		RetMask |= CheckAndDoPrefix_Single(&Result->SrcReg, Options) << 0;
	if (Result->DstReg == REG_FROM_HL)
		RetMask |= CheckAndDoPrefix_Single(&Result->DstReg, Options) << 1;
	
	if (! RetMask)
	{
		//	LD	IXh, IXh
		RetMask |= CheckAndDoPrefix_Single(&Result->SrcReg, Options) << 0;
		RetMask |= CheckAndDoPrefix_Single(&Result->DstReg, Options) << 1;
	}
	else
	{
		//	LD	H, (IX+d)
		if (Result->SrcReg >= 0x10)
			RetMask |= CheckAndDoPrefix_Single(&Result->SrcReg, Options) << 0;
		if (Result->DstReg >= 0x10)
			RetMask |= CheckAndDoPrefix_Single(&Result->DstReg, Options) << 1;
	}
	
	return RetMask;
}

static void DisassembleInstruction(const UINT8* Code, UINT8 Options, INST_DATA* Result)
{
	UINT8 CodeM;	// Master
	UINT8 CodeH;	// High
	UINT8 CodeL;	// Low
	
	Result->Instruction = MN_ERROR;
	Result->Size = 0x00;
	Result->Cycles = 0;
	Result->CyclesB = 0;
	Result->Condition = COND_NONE;
	Result->SrcReg = REG_NONE;
	Result->SrcVal = 0x0000;
	Result->DstReg = REG_NONE;
	Result->DstVal = 0x0000;
	Result->SideFXReg = REG_NONE;
	if (Code == NULL)
		return;
	
	CodeM = *Code & 0xC0;
	CodeH = (*Code & 0x38) >> 3;
	CodeL = (*Code & 0x07) >> 0;
	switch(CodeM)
	{
	case 0x00:	// load with immediate values, calculations with non-A registers, special jumps
		switch(CodeL)
		{
		case 0x00:
			if (CodeH == 0x00)			// 00	NOP
			{
				Result->Instruction = MN_NOP;
				Result->Size = 0x01;
				Result->Cycles = 4;
			}
			else if (CodeH == 0x01)	// 08	EX	AF, AF'
			{
				Result->Instruction = MN_EX;
				Result->SrcReg = REG_AF | REG_FROM_MASK;
				Result->DstReg = REG_AF;
				Result->Size = 0x01;
				Result->Cycles = 4;
			}
			else if (CodeH == 0x02)	// 10	DJNZ	disp
			{
				Result->Instruction = MN_DJNZ;
				Result->SrcReg = REG_REL_OFS;
				Result->SrcVal = Code[0x01];
				Result->Size = 0x02;
				Result->Cycles = 8;		// last iteration
				Result->CyclesB = 13;	// looping iteration
			}
			else						//18-38	JR	[cond,] disp
			{
				Result->Instruction = MN_JR;
				Result->SrcReg = REG_REL_OFS;
				Result->SrcVal = Code[0x01];
				Result->Size = 0x02;
				if (CodeH < 0x04)	// 18 unconditional JR
				{
					Result->Cycles = 12;
				}
				else				// 20-38 conditional JR
				{
					Result->Condition = CodeH & 0x03;
					Result->Cycles = 7;		// not taken
					Result->CyclesB = 12;	// taken
				}
			}
			break;
		case 0x01:
			if (! (CodeH & 0x01))
			{
				// LD	pair, data
				Result->Instruction = MN_LD;
				Result->SrcReg = REG_NUM16;
				Result->SrcVal = ReadLE16(&Code[0x01]);
				Result->DstReg = 0x10 | (CodeH >> 1);
				Result->Size = 0x03;
				Result->Cycles = 10;
			}
			else
			{
				// ADD	HL, pair
				Result->Instruction = MN_ADD;
				Result->SrcReg = 0x10 | (CodeH >> 1);
				Result->DstReg = REG_HL;
				Result->Size = 0x01;
				Result->Cycles = 11;
			}
			break;
		case 0x02:
			//	02	LD	(BC), A		[BC]	1/7
			//	12	LD	(DE), A		[DE]	1/7
			//	22	LD	(nn), HL	[HL]	3/16
			//	32	LD	(nn), A		[SP]	3/13
			Result->Instruction = MN_LD;
			if (! (CodeH & 0x01))
			{
				// x2	LD	(pair), A
				Result->SrcReg = (CodeH == 0x04) ? REG_HL : REG_A;
				Result->DstReg = 0x10 | REG_FROM_MASK | (CodeH >> 1);
			}
			else
			{
				// xA	LD	A, (pair)
				Result->SrcReg = 0x10 | REG_FROM_MASK | (CodeH >> 1);
				Result->DstReg = (CodeH == 0x05) ? REG_HL : REG_A;
			}
			Result->Size = 0x01;
			Result->Cycles = 7;
			
			if (CodeH & 0x04)	// is HL or SP
			{
				if (! (CodeH & 0x01))
				{
					Result->DstReg = REG_NUM16 | REG_FROM_MASK;
					Result->DstVal = ReadLE16(&Code[0x01]);
				}
				else
				{
					Result->SrcReg = REG_NUM16 | REG_FROM_MASK;
					Result->SrcVal = ReadLE16(&Code[0x01]);
				}
				Result->Size += 0x02;
				Result->Cycles += 6;
				
				if (! (CodeH & 0x02))	// (nn) <-> HL
					Result->Cycles += 3;
			}
			break;
		case 0x03:
			// INC/DEC	pair
			Result->Instruction = (CodeH & 0x01) ? MN_DEC : MN_INC;
			Result->DstReg = 0x10 | (CodeH >> 1);
			Result->Size = 0x01;
			Result->Cycles = 6;
			break;
		case 0x04:	// INC	reg
		case 0x05:	// DEC	reg
			Result->Instruction = (CodeL & 0x01) ? MN_DEC : MN_INC;
			Result->DstReg = CodeH;
			Result->Size = 0x01;
			Result->Cycles = 4;
			
			if (Result->DstReg == REG_SPECIAL)
			{
				Result->DstReg = REG_FROM_HL;
				Result->Cycles += 7;
				HandlePrefix(Code, Result, Options, 8);	// INC (IX+d), data: 11 -> 19 cycles
			}
			break;
		case 0x06:	// LD	reg, data
			Result->Instruction = MN_LD;
			Result->SrcReg = REG_NUM8;
			Result->DstReg = CodeH;		// H/L can be swapped to IXh/IXl, IYh/IYl
			Result->Size = 0x01;
			Result->Cycles = 7;
			
			if (Result->DstReg == REG_SPECIAL)
			{
				Result->DstReg = REG_FROM_HL;
				Result->Cycles += 3;	// LD (HL), data: 7 -> 10 cyles
				HandlePrefix(Code, Result, Options, 5);	// LD (IX+d), data: 10 -> 15 cycles
			}
			
			Result->SrcVal = Code[Result->Size];
			Result->Size ++;
			break;
		case 0x07:	// rotate/carry
			Result->Instruction = ROT_ARITHM_MN[CodeH];
			Result->SrcReg = REG_A | 0x08;
			Result->Size = 0x01;
			Result->Cycles = 4;
			break;
		}
		break;
	case 0x40:	// load instructions
		if (*Code == 0x76)	// would be LD (HL), (HL)
		{
			Result->Instruction = MN_HALT;
			Result->Size = 0x01;
			Result->Cycles = 4;
			return;
		}
		
		Result->Instruction = MN_LD;
		Result->SrcReg = CodeL;
		Result->DstReg = CodeH;
		Result->Size = 0x01;
		Result->Cycles = 4;
		
		if (Result->SrcReg == REG_SPECIAL || Result->DstReg == REG_SPECIAL)
		{
			if (Result->SrcReg == REG_SPECIAL)
				Result->SrcReg = REG_FROM_HL;
			if (Result->DstReg == REG_SPECIAL)
				Result->DstReg = REG_FROM_HL;
			
			Result->Cycles += 3;	// LD reg, (HL): 4 -> 7 cycles
			HandlePrefix(Code, Result, Options, 8);	// LD reg, (IX+d): 7 -> 15 cycles
		}
		break;
	case 0x80:	// calculations with Register and A
		Result->Instruction = CALC_MN[CodeH];
		Result->SrcReg = CodeL;
		Result->DstReg = REG_A;
		if (! (Result->Instruction == MN_ADD ||
			   Result->Instruction == MN_ADC ||
			   Result->Instruction == MN_SBC))
			Result->DstReg |= 0x08;	// hide register
		Result->Size = 0x01;
		Result->Cycles = 4;
		
		if (Result->SrcReg == REG_SPECIAL)
		{
			Result->SrcReg = REG_FROM_HL;
			Result->Cycles += 3;	// ADD A, (HL): 4 -> 7 cyles
			HandlePrefix(Code, Result, Options, 8);	// ADD A, (IX+d): 7 -> 15 cycles
		}
		break;
	case 0xC0:
		switch(CodeL)
		{
		case 0x00:	//	RET	cond
			Result->Instruction = MN_RET;
			Result->Condition = CodeH;
			Result->Size = 0x01;
			Result->Cycles = 5;
			Result->CyclesB = 11;
			break;
		case 0x01:
			if (! (CodeH & 0x01))
			{
				//	x1	POP	pair
				Result->Instruction = MN_POP;
				Result->SrcReg = 0x10 | (CodeH >> 1);
				if (Result->SrcReg == REG_SP)
					Result->SrcReg = REG_AF;
				Result->Size = 0x01;
				Result->Cycles = 10;
			}
			else
			{
				switch(CodeH >> 1)
				{
				case 0x00:	//	C9	RET
					Result->Instruction = MN_RET;
					Result->Size = 0x01;
					Result->Cycles = 10;
					break;
				case 0x01:	//	D9	EXX
					Result->Instruction = MN_EXX;
					Result->Size = 0x01;
					Result->Cycles = 4;
					break;
				case 0x02:	//	E9	JP	(HL)
					Result->Instruction = MN_JP;
					Result->SrcReg = REG_HL;
					Result->Size = 0x01;
					Result->Cycles = 4;
					break;
				case 0x03:	//	F9	LD	SP, HL
					Result->Instruction = MN_LD;
					Result->SrcReg = REG_HL;	// Note: Swapping with IX/IY doesn't affect the required cycles.
					Result->DstReg = REG_SP;
					Result->Size = 0x01;
					Result->Cycles = 6;
					break;
				}
			}
			break;
		case 0x02:	//	JP	cond, addr
			Result->Instruction = MN_JP;
			Result->Condition = CodeH;
			Result->SrcReg = REG_ABS_OFS;
			Result->SrcVal = ReadLE16(&Code[0x01]);
			Result->Size = 0x03;
			Result->Cycles = 10;
			Result->CyclesB = 10;
			break;
		case 0x03:
			switch(CodeH)
			{
			case 0x00:	//	C3		JP	addr
				Result->Instruction = MN_JP;
				Result->SrcReg = REG_ABS_OFS;
				Result->SrcVal = ReadLE16(&Code[0x01]);
				Result->Size = 0x03;
				Result->Cycles = 10;
				break;
			case 0x01:	//	CB subcmd	Bit Arithmetic
				Result->Size = 0x01;
				Result->Cycles = 8;
				Result->SrcReg = REG_FROM_HL;	// DD CB has ALWAYS a displacement.
				HandlePrefix(Code, Result, Options, 4);	// IX-syntax is DD CB disp subcmd
				
				CodeM = Code[Result->Size] & 0xC0;
				CodeH = (Code[Result->Size] & 0x38) >> 3;
				CodeL = (Code[Result->Size] & 0x07) >> 0;
				Result->Size ++;
				
				if (! (Options & OPTION_USE_IREG))
				{
					Result->SrcReg = CodeL;
					if (Result->SrcReg == REG_SPECIAL)
						Result->SrcReg = REG_FROM_HL;
				}
				else
				{
					Result->SideFXReg = CodeL;
					if (Result->SideFXReg == REG_SPECIAL)
						Result->SideFXReg = REG_NONE;
				}
				
				switch(CodeM)
				{
				case 0x00:	// rotate/shift
					Result->Instruction = ROT_SHIFT_REG_MN[CodeH];
					if (Result->SrcReg == REG_FROM_HL)
						Result->Cycles += 7;	// RLC (HL): 8 -> 15 cyles
					break;
				case 0x40:	// Bit Test
					Result->Instruction = MN_BIT;
					Result->DstReg = REG_NUM4;
					Result->DstVal = CodeH;
					if (Result->SrcReg == REG_FROM_HL)
						Result->Cycles += 4;	// BIT b, (HL): 8 -> 12 cyles
					break;
				case 0x80:	// Bit Reset
					Result->Instruction = MN_RES;
					Result->DstReg = REG_NUM4;
					Result->DstVal = CodeH;
					if (Result->SrcReg == REG_FROM_HL)
						Result->Cycles += 7;	// SET b, (HL): 8 -> 15 cyles
					break;
				case 0xC0:	// Bit Set
					Result->Instruction = MN_SET;
					Result->DstReg = REG_NUM4;
					Result->DstVal = CodeH;
					if (Result->SrcReg == REG_FROM_HL)
						Result->Cycles += 7;	// SET b, (HL): 8 -> 15 cyles
					break;
				}
				break;
			case 0x02:	//	D3		OUT (io_addr), A
				Result->Instruction = MN_OUT;
				Result->SrcReg = REG_A;
				Result->DstReg = REG_NUM8 | REG_FROM_MASK;
				Result->DstVal = Code[0x01];
				Result->Size = 0x02;
				Result->Cycles = 11;
				break;
			case 0x03:	//	DB		IN	A, (io_addr)
				Result->Instruction = MN_IN;
				Result->SrcReg = REG_NUM8 | REG_FROM_MASK;
				Result->SrcVal = Code[0x01];
				Result->DstReg = REG_A;
				Result->Size = 0x02;
				Result->Cycles = 11;
				break;
			case 0x04:	//	E3		EX	(SP), HL
				Result->Instruction = MN_EX;
				Result->SrcReg = REG_HL;
				Result->DstReg = REG_SP | REG_FROM_MASK;
				Result->Size = 0x01;
				Result->Cycles = 19;
				break;
			case 0x05:	//	EB		EX	DE, HL
				Result->Instruction = MN_EX;
				Result->SrcReg = REG_HL2;
				Result->DstReg = REG_DE;
				Result->Size = 0x01;
				Result->Cycles = 4;
				break;
			case 0x06:	//	F3		DI
				Result->Instruction = MN_DI;
				Result->Size = 0x01;
				Result->Cycles = 4;
				break;
			case 0x07:	//	FB		EI
				Result->Instruction = MN_EI;
				Result->Size = 0x01;
				Result->Cycles = 4;
				break;
			}
			break;
		case 0x04:	//	CALL cond, addr
			Result->Instruction = MN_CALL;
			Result->Condition = CodeH;
			Result->SrcReg = REG_ABS_OFS;
			Result->SrcVal = ReadLE16(&Code[0x01]);
			Result->Size = 0x03;
			Result->Cycles = 10;
			Result->CyclesB = 17;
			break;
		case 0x05:
			if (! (CodeH & 0x01))
			{
				//	x5	PUSH	pair
				Result->Instruction = MN_PUSH;
				Result->SrcReg = 0x10 | (CodeH >> 1);
				if (Result->SrcReg == REG_SP)
					Result->SrcReg = REG_AF;
				Result->Size = 0x01;
				Result->Cycles = 11;
			}
			else
			{
				switch(CodeH >> 1)
				{
				case 0x00:	//	CD	CALL	addr
					Result->Instruction = MN_CALL;
					Result->SrcReg = REG_ABS_OFS;
					Result->SrcVal = ReadLE16(&Code[0x01]);
					Result->Size = 0x03;
					Result->Cycles = 17;
					break;
				case 0x01:	//	DD	IX-prefix
					if (! (Options & OPTION_NO_PREF_EXEC))
					{
						DisassembleInstruction(&Code[0x01], Options | OPTION_USE_IREG, Result);
						CodeL = CheckAndDoPrefix(Result, OPTION_IREG_IX);
						if (CodeL)
						{
							Result->Size ++;	// add bytes and cycles for IX-prefix
							Result->Cycles += 4;
							break;
						}
						DisassembleInstruction(NULL, 0x00, Result);	// reset structure
					}
					Result->Instruction = MN_IX_PREF;
					Result->Size = 0x01;
					Result->Cycles = 4;
					break;
				case 0x02:	//	ED	Special Command
					DisassembleEDInstruction(&Code[0x01], Options, Result);
					if (Result->Instruction != MN_ERROR)
					{
						Result->Size ++;
						Result->Cycles += 4;
						if (Result->CyclesB)
							Result->CyclesB += 4;
					}
					break;
				case 0x03:	//	FD	IY-prefix
					if (! (Options & OPTION_NO_PREF_EXEC))
					{
						DisassembleInstruction(&Code[0x01], Options | OPTION_USE_IREG, Result);
						CodeL = CheckAndDoPrefix(Result, OPTION_IREG_IY);
						if (CodeL)
						{
							Result->Size ++;	// add bytes and cycles for IX-prefix
							Result->Cycles += 4;
							break;
						}
						DisassembleInstruction(NULL, 0x00, Result);	// reset structure
					}
					Result->Instruction = MN_IY_PREF;
					Result->Size = 0x01;
					Result->Cycles = 4;
					break;
				}
			}
			break;
		case 0x06:	// calculations with Immediate Value and A
			//	C6	ADD	A, data
			Result->Instruction = CALC_MN[CodeH];
			Result->SrcReg = REG_NUM8;
			Result->SrcVal = Code[0x01];
			Result->DstReg = REG_A;
			if (! (Result->Instruction == MN_ADD ||
				   Result->Instruction == MN_ADC ||
				   Result->Instruction == MN_SBC))
				Result->DstReg |= 0x08;	// hide register
			Result->Size = 0x02;
			Result->Cycles = 7;
			break;
		case 0x07:	//	RST	00h-38h
			Result->Instruction = MN_RST;
			Result->SrcReg = REG_ABS_OFS;
			Result->SrcVal = CodeH << 3;
			Result->Size = 0x01;
			Result->Cycles = 11;
			break;
		}
		break;
	}
	
	return;
}

static void DisassembleEDInstruction(const UINT8* Code, UINT8 Options, INST_DATA* Result)
{
	UINT8 CodeM;	// Master
	UINT8 CodeH;	// High
	UINT8 CodeL;	// Low
	
	Result->Instruction = MN_ERROR;
	Result->Size = 0x00;
	Result->Cycles = 0;
	Result->CyclesB = 0;
	Result->Condition = COND_NONE;
	Result->SrcReg = REG_NONE;
	Result->SrcVal = 0x0000;
	Result->DstReg = REG_NONE;
	Result->DstVal = 0x0000;
	if (Code == NULL)
		return;
	
	CodeM = *Code & 0xC0;
	CodeH = (*Code & 0x38) >> 3;
	CodeL = (*Code & 0x07) >> 0;
	switch(CodeM)
	{
	case 0x40:	// load instructions
		switch(CodeL)
		{
		case 0x00:	// IN	reg, (C)
			Result->Instruction = MN_IN;
			Result->Size = 0x01;
			Result->Cycles = 8;
			Result->SrcReg = REG_C | REG_FROM_MASK;
			Result->DstReg = CodeH;
			if (Result->DstReg == REG_SPECIAL)
				Result->DstReg = REG_NONE;
			break;
		case 0x01:	// OUT	(C), reg
			Result->Instruction = MN_OUT;
			Result->Size = 0x01;
			Result->Cycles = 8;
			Result->SrcReg = CodeH;
			if (Result->SrcReg == REG_SPECIAL)
			{
				Result->SrcReg = REG_NUM4;
				Result->SrcVal = 0;
			}
			Result->DstReg = REG_C | REG_FROM_MASK;
			break;
		case 0x02:	// SBC/ADC	HL, pair
			if (! (CodeH & 0x01))
				Result->Instruction = MN_SBC;
			else
				Result->Instruction = MN_ADC;
			Result->Size = 0x01;
			Result->Cycles = 11;
			Result->SrcReg = 0x10 | (CodeH >> 1);
			Result->DstReg = REG_HL;
			break;
		case 0x03:	// LD	(nn), pair
			Result->Instruction = MN_LD;
			Result->Size = 0x03;
			Result->Cycles = 16;
			Result->SrcReg = 0x10 | (CodeH >> 1);
			Result->DstReg = REG_NUM16 | REG_FROM_MASK;
			Result->DstVal = ReadLE16(&Code[0x01]);
			break;
		case 0x04:	// NEG
			Result->Instruction = MN_NEG;
			Result->Size = 0x01;
			Result->Cycles = 4;
			Result->SrcReg = REG_A | 0x08;
			break;
		case 0x05:	// RETN
			// ED 4D = RETI, all others are RETN
			Result->Instruction = (CodeH == 0x01) ? MN_RETI : MN_RETN;
			Result->Size = 0x01;
			Result->Cycles = 10;
			break;
		case 0x06:	// IM	0
			Result->Instruction = MN_IM;
			Result->Size = 0x01;
			Result->Cycles = 4;
			Result->SrcReg = REG_NUM4;
			Result->SrcVal = CodeH & 0x03;
			if (Result->SrcVal)
				Result->SrcVal --;	// It is IM 0, 0, 1, 2
			break;
		case 0x07:
			if (! (CodeH & 0x04))
			{
				// ED 47	LD	I, A		ED 57	LD	A, I
				// ED 4F	LD	R, A		ED 5F	LD	A, R
				Result->Instruction = MN_LD;
				Result->Size = 0x01;
				Result->Cycles = 5;
				if (! (CodeH & 0x02))
				{
					Result->SrcReg = REG_A;
					Result->DstReg = (CodeH & 0x01) ? REG_R : REG_I;
				}
				else
				{
					Result->SrcReg = (CodeH & 0x01) ? REG_R : REG_I;
					Result->DstReg = REG_A;
				}
			}
			else
			{
				if (! (CodeH & 0x02))
				{
					// ED 67	RRD			ED 6F	RLD
					Result->Instruction = (CodeH & 0x01) ? MN_RLD : MN_RRD;
					Result->Size = 0x01;
					Result->Cycles = 14;
					Result->SrcReg = REG_A | 0x08;
				}
				else
				{
					Result->Instruction = MN_NOP;
					Result->Size = 0x01;
					Result->Cycles = 4;
				}
			}
			break;
		}
		break;
	case 0x80:
		// if ((ED A0/A8/B0/B8) && (ED x0..x3))
		if ((CodeH & 0x04) && ! (CodeL & 0x04))
		{
			// LD/CP/IN/OUT with I/D/IR/DR
			Result->Instruction = (MN_LDI + CodeL) + ((CodeH & 0x03) * 0x04);
			Result->Size = 0x01;
			
			Result->Cycles = 12;
			if (CodeH & 0x02)
				Result->CyclesB = 17;
			break;
		}
		// else fall through
		break;
	case 0x00:
	case 0xC0:
		Result->Instruction = MN_NOP;
		Result->Size = 0x01;
		Result->Cycles = 4;
		break;
	}
	
	return;
}

int main(int argc, char* argv[])
{
	int argbase;
	FILE* hFile;
	UINT16 StartOfs;
	UINT16 EndOfs;
	
	if (argc < 3)
	{
		printf("Z80 Disassembler and Cycle Counter\n");
		printf("----------------------------------\n");
		printf("Written by Valley Bell\n");
		printf("\n");
		printf("Usage: z80cycle [-options] Z80Code.bin StartOfset [EndOffset]\n");
		printf("\n");
		printf("Options:\n");
		printf("  -nospaces     don't separate operands with spaces\n");
		printf("  -jpstop       stop on a (conditional) jump to the start offset\n");
		printf("  -ignorejmp    ignore all jump and return instructions\n");
		printf("                By default the program follows JP/JR and quits after RET.\n");
		printf("  -showA n      set Register A display mode (affects ADD/ADC/NEG/...)\n");
		printf("                n = 0 - don't show A (ADD  B)\n");
		printf("                n = 1 - show in ADD/ADC/SBC only (default, offical syntax)\n");
		printf("                n = 2 - always show A (ADD  A, B)\n");
		printf("  -splitIreg    print IX/IY prefix bytes as separate instructions\n");
		printf("  -hideofs      don't show the current file offset in the first column\n");
		printf("  -showdata     show the instruction's byte code\n");
		printf("  -showcycles   show the number of cycles for every instruction\n");
		printf("                The format for conditional jumps is (not taken/taken).\n");
		printf("  -summarize    shows how many cycles the processed code section takes\n");
		printf("\n");
		printf("Note: The program will always stop when it is reaching code that was already\n");
		printf("      analyzed.\n");
		return 0;
	}
	
	SPACE_OPS = 0x01;
	STOP_START_JP = 0x00;
	IGNORE_JPRET = 0x00;
	PRINT_A = 0x01;
	SPLIT_PREFIX = 0x00;
	SHOW_OFFSET = 0x01;
	SHOW_DATA = 0x00;
	SHOW_CYCLES = 0x00;
	CYCLE_SMRY = 0x00;
	
	argbase = 1;
	while(argbase < argc && argv[argbase][0] == '-')
	{
		if (! _stricmp(argv[argbase] + 1, "nospaces"))
			SPACE_OPS = 0x00;
		else if (! _stricmp(argv[argbase] + 1, "jpstop"))
			STOP_START_JP = 0x01;
		else if (! _stricmp(argv[argbase] + 1, "ignorejmp"))
			IGNORE_JPRET = 0x01;
		else if (! _stricmp(argv[argbase] + 1, "showA"))
		{
			argbase ++;
			if (argbase < argc)
				PRINT_A = (UINT8)strtoul(argv[argbase], NULL, 0);
		}
		else if (! _stricmp(argv[argbase] + 1, "splitIreg"))
			SPLIT_PREFIX = 0x01;
		else if (! _stricmp(argv[argbase] + 1, "hideofs"))
			SHOW_OFFSET = 0x00;
		else if (! _stricmp(argv[argbase] + 1, "showdata"))
			SHOW_DATA = 0x01;
		else if (! _stricmp(argv[argbase] + 1, "showcycles"))
			SHOW_CYCLES = 0x01;
		else if (! _stricmp(argv[argbase] + 1, "summarize"))
			CYCLE_SMRY = 0x01;
		else
			break;
		argbase ++;
	}
	
	if (argc < argbase + 2)
	{
		printf("Not enough arguments!\n");
		return 9;
	}
	
	InitMnemonics();
	
	hFile = fopen(argv[argbase + 0], "rb");
	if (hFile == NULL)
	{
		printf("Error opening file!\n");
		return 1;
	}
	
	fseek(hFile, 0, SEEK_END);
	BinLen = ftell(hFile);
	
	fseek(hFile, 0, SEEK_SET);
	BinData = (UINT8*)malloc(BinLen);
	BinMask = (UINT8*)malloc((BinLen + 0x07) / 0x08);
	fread(BinData, 0x01, BinLen, hFile);
	memset(BinMask, 0x00, (BinLen + 0x07) / 0x08);
	
	fclose(hFile);
	
	StartOfs = (UINT16)strtoul(argv[argbase + 1], NULL, 0);
	if (argc < argbase + 3)
		EndOfs = 0xFFFF;
	else
		EndOfs = (UINT16)strtoul(argv[argbase + 2], NULL, 0);
	
	CalculateZ80Cycles(StartOfs, EndOfs);
	
	free(BinData);	BinData = NULL;
	free(BinMask);	BinMask = NULL;
	
	//_getch();
	return 0;
}

static UINT8 PrintRegister(char* Buffer, UINT8 Reg, UINT16 Data, UINT16 BaseOfs)
{
	if (Reg < REG_NUM8)
	{
		const char* RegStr;
		UINT8 RegIdx;
		
		if (Reg == (REG_A | 0x08))
			Reg &= ~0x08;
		
		RegIdx = ((Reg & 0xF0) >> 1) | (Reg & 0x07);
		RegStr = REGISTER_LIST[RegIdx];
		if (RegStr == NULL)
			RegStr = "???";
		
		if (! (Reg & REG_FROM_MASK))
		{
			strcpy(Buffer, RegStr);
		}
		else
		{
			Reg &= ~REG_FROM_MASK;
			if (Reg == REG_IX || Reg == REG_IY)
				sprintf(Buffer, "(%s+%02Xh)", RegStr, Data);
			else if (Reg == REG_AF)
				sprintf(Buffer, "%s'", RegStr);
			else
				sprintf(Buffer, "(%s)", RegStr);
		}
	}
	else 
	{
		switch(Reg)
		{
		case REG_NUM4:
			sprintf(Buffer, "%01u", Data);
			break;
		case REG_NUM8:
			sprintf(Buffer, "%02Xh", Data);
			break;
		case REG_NUM16:
			sprintf(Buffer, "%04Xh", Data);
			break;
		case REG_NUM8 | REG_FROM_MASK:
			sprintf(Buffer, "(%02Xh)", Data);
			break;
		case REG_NUM16 | REG_FROM_MASK:
			sprintf(Buffer, "(%04Xh)", Data);
			break;
		case REG_ABS_OFS:
			sprintf(Buffer, "%04Xh", Data);
			break;
		case REG_REL_OFS:
			{
				INT16 Diff = (INT8)Data;
				UINT16 FinalOfs = BaseOfs + Diff;
				
				if (Diff < 0)
					sprintf(Buffer, "-%02Xh  ; [%04Xh]", -Diff, FinalOfs);
				else
					sprintf(Buffer, "+%02Xh  ; [%04Xh]", +Diff, FinalOfs);
			}
			break;
		default:
			strcpy(Buffer, "???");
			break;
		}
	}
	
	return strlen(Buffer);
}

static void ShowDisassembledLine(char* Buffer, UINT16 Pos, const UINT8* CodeData, INST_DATA* InsData)
{
	char* DisasmStr;
	const char* InstrStr;
	UINT16 TempPos;
	UINT8 ColumnNum;
	
	DisasmStr = Buffer;
	if (SHOW_OFFSET)
		DisasmStr += sprintf(DisasmStr, "%04X", Pos);	// print current offset
	
	if (SHOW_DATA)
	{
		// print instruction bytes
		*(DisasmStr ++) = '\t';
		for (TempPos = 0x00; TempPos < 0x04; TempPos ++)
		{
			if (TempPos < InsData->Size)
			{
				DisasmStr += sprintf(DisasmStr, "%02X ", CodeData[TempPos]);
			}
			else
			{
				strcpy(DisasmStr, "   ");
				DisasmStr += 3;
			}
		}
		DisasmStr --;	// remove last space
	}
	*(DisasmStr ++) = '\t';
	
	if (SHOW_CYCLES)
	{
		if (! InsData->CyclesB)
			DisasmStr += sprintf(DisasmStr, "%u", InsData->Cycles);
		else
			DisasmStr += sprintf(DisasmStr, "%u/%u", InsData->Cycles, InsData->CyclesB);
	}
	*(DisasmStr ++) = '\t';
	
	if (InsData->Instruction & 0x80)
		InstrStr = "error";
	else
		InstrStr = MNEMONICS[InsData->Instruction];
	if (InstrStr == NULL)
		InstrStr = "???";
	DisasmStr += sprintf(DisasmStr, "%s\t", InstrStr);
	
	ColumnNum = 0;
	if (InsData->Condition != COND_NONE)
	{
		strcat(DisasmStr, CONDCODE_LIST[InsData->Condition]);
		DisasmStr += strlen(DisasmStr);
		ColumnNum ++;
	}
	
	// show or hide register A in instructions like "CP A, 20h" and "NEG A"
	if (PRINT_A == 0x00)
	{
		if (InsData->Instruction >= MN_ADD && InsData->Instruction <= MN_CP)
		{
			if (InsData->DstReg == REG_A)
				InsData->DstReg = REG_NONE;
		}
		else if (InsData->Instruction >= MN_RLCA && InsData->Instruction <= MN_NEG)
		{
			if (InsData->SrcReg == REG_A)
				InsData->SrcReg = REG_NONE;
		}
	}
	if (PRINT_A <= 0x01)
	{
		if (InsData->DstReg == (REG_A | 0x08))
			InsData->DstReg = REG_NONE;
		if (InsData->SrcReg == (REG_A | 0x08))
			InsData->SrcReg = REG_NONE;
	}
	
	TempPos = Pos + InsData->Size;
	if (InsData->DstReg != REG_NONE)
	{
		if (ColumnNum)
		{
			*(DisasmStr ++) = ',';
			if (SPACE_OPS)
				*(DisasmStr ++) = ' ';
		}
		DisasmStr += PrintRegister(DisasmStr, InsData->DstReg, InsData->DstVal, TempPos);
		ColumnNum ++;
	}
	if (InsData->SrcReg != REG_NONE)
	{
		if (ColumnNum)
		{
			*(DisasmStr ++) = ',';
			if (SPACE_OPS)
				*(DisasmStr ++) = ' ';
		}
		DisasmStr += PrintRegister(DisasmStr, InsData->SrcReg, InsData->SrcVal, TempPos);
		ColumnNum ++;
	}
	if (InsData->SideFXReg != REG_NONE)
	{
		if (ColumnNum)
		{
			*(DisasmStr ++) = ',';
			if (SPACE_OPS)
				*(DisasmStr ++) = ' ';
		}
		DisasmStr += PrintRegister(DisasmStr, InsData->SideFXReg, 0x00, TempPos);
		ColumnNum ++;
	}
	
	DisasmStr --;
	if (*DisasmStr == '\t')
		*DisasmStr = '\0';	// remove trailing TAB
	
	return;
}

#define BMASK_BYTE(pos)			(pos >> 3)
#define BMASK_BIT(pos)			(1 << (pos & 0x07))
static UINT8 CalculateZ80Cycles(UINT16 StartOfs, UINT16 EndOfs)
{
	UINT16 CurPos;
	UINT16 TempPos;
	UINT16 JumpDstPos;
	
	UINT32 CycleCnt;
	UINT32 CyclePerDJNZ;
	UINT32 DJNZCnt;
	
	INST_DATA InsData;
	UINT8 BaseDasmOpts;
	UINT8 CurDisasmOpts;
	
	char DisasmStrBuf[0x80];
	
	BaseDasmOpts = 0x00;
	if (SPLIT_PREFIX)
		BaseDasmOpts |= OPTION_NO_PREF_EXEC;
	
	CycleCnt = 0x00;
	CyclePerDJNZ = 0x00;
	DJNZCnt = 0x00;
	
	CurDisasmOpts = 0x00;
	CurPos = StartOfs;
	while(CurPos < BinLen && CurPos < EndOfs)
	{
		if (BinMask[BMASK_BYTE(CurPos)] & BMASK_BIT(CurPos))
			break;
		
		DisassembleInstruction(&BinData[CurPos], BaseDasmOpts | CurDisasmOpts, &InsData);
		if (CurDisasmOpts & OPTION_USE_IREG)
			CheckAndDoPrefix(&InsData, CurDisasmOpts);
		
		ShowDisassembledLine(DisasmStrBuf, CurPos, &BinData[CurPos], &InsData);
		printf("%s\n", DisasmStrBuf);
		
		TempPos = CurPos;
		CurPos += InsData.Size;
		while(TempPos < CurPos)
		{
			BinMask[BMASK_BYTE(TempPos)] |= BMASK_BIT(TempPos);
			TempPos ++;
		}
		if (InsData.Instruction == MN_DJNZ)
		{
			CyclePerDJNZ = InsData.CyclesB;
			DJNZCnt ++;
		}
		CycleCnt += InsData.Cycles;
		
		if (InsData.Instruction == MN_ERROR)
			break;
		
		CurDisasmOpts = 0x00;
		switch(InsData.Instruction)
		{
		case MN_IX_PREF:
			CurDisasmOpts |= OPTION_USE_IREG | OPTION_IREG_IX;
			break;
		case MN_IY_PREF:
			CurDisasmOpts |= OPTION_USE_IREG | OPTION_IREG_IY;
			break;
		case MN_JR:
			JumpDstPos = CurPos + (INT8)InsData.SrcVal;
			if (STOP_START_JP)
			{
				if (JumpDstPos == StartOfs)
					CurPos = EndOfs;
			}
			if (InsData.Condition == COND_NONE && ! IGNORE_JPRET)
			{
				CurPos = JumpDstPos;
				printf("\n");
			}
			break;
		case MN_JP:
			JumpDstPos = InsData.SrcVal;
			if (STOP_START_JP)
			{
				if (JumpDstPos == StartOfs)
					CurPos = EndOfs;
			}
			if (InsData.Condition == COND_NONE && ! IGNORE_JPRET)
			{
				CurPos = JumpDstPos;
				printf("\n");
			}
			break;
		case MN_CALL:
			//_getch();
			break;
		case MN_RET:
			if (InsData.Condition == COND_NONE && ! IGNORE_JPRET)
			{
				CurPos = EndOfs;
				printf("\n");
			}
			break;
		}
	}
	printf("\n");
	
	if (CYCLE_SMRY)
	{
		printf("Total cycles: %u", CycleCnt);
		if (DJNZCnt)
		{
			printf(" + %u*x cycles\n", CyclePerDJNZ * DJNZCnt);
			printf("%u DJNZ instructions (%u cycles/iteration)\n", DJNZCnt, CyclePerDJNZ);
		}
		printf("\n");
	}
	
	return 0x00;
}

static UINT16 ReadLE16(const UINT8* Data)
{
	return	(Data[0x01] << 8) |
			(Data[0x00] << 0);
}

static void print_hex_data(UINT16 DataSize, const UINT8* DataPtr)
{
	while(DataSize > 1)
	{
		printf("%02X ", *DataPtr);
		DataPtr ++;		DataSize --;
	}
	if (DataSize)
		printf("%02X\n", *DataPtr);
	
	return;
}
