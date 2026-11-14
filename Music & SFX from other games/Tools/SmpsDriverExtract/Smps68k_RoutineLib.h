#ifndef __SMPS68K_ROUTINELIB_H__
#define __SMPS68K_ROUTINELIB_H__

#include "stdtype.h"

// Note: The wildcard character is 0xAA.

static const UINT8 CF_NULL[] = {
	0x4E, 0x75};				//	RTS
static const UINT8 CFE0_PAN[] = {
	0x12, 0x1C,					//	MOVE.B	(A4)+, D1
	0x4A, 0x2D, 0x00, 0x01,		//	TST.B	$01(A5)
	0x6B, 0xAA,					//	BMI.S	locret_1610C2	[6B 16]
	0x10, 0x2D, 0x00, 0xAA,		//	MOVE.B	$27(A5), D0		[10 2D 00 27]
	0x02, 0x00, 0x00, 0x37,		//	ANDI.B	#$37, D0
	0x82, 0x00};				//	OR.B	D0, D1
//	0x1B, 0x41, 0x00, 0x27,		//	MOVE.B	D1, $27(A5)
//	0x10, 0x3C, 0x00, 0xB4,		//	MOVE.B	#$B4, D0
//	0x60, 0x00, 0xFB, 0xC4,		//	BRA.W	WriteFMMain_Z	[60 00 FB C4]
//	//locret_1610C2:
//	0x4E, 0x75};				//	RTS
static const UINT8 CFE1_DETUNE[] = {
	0x1B, 0x5C, 0x00, 0x1E,		//	MOVE.B	(A4)+, $1E(A5)
	0x4E, 0x75};				//	RTS
static const UINT8 CFE2_SETCOMM[] = {
	0x1D, 0x5C, 0x00, 0xAA,		//	MOVE.B	(A4)+, $03(A6)	[1D 5C 00 03]
	0x4E, 0x75};				//	RTS
static const UINT8 CFE3_SILENCETRK[] = {
	0x4E, 0xBA, 0xAA, 0xAA,		//	JSR 	SilenceFMChn(pc)	[4E BA FA 40]
	0x60, 0x00, 0xAA, 0xAA};	//	BRA.W	cfF2_StopTrk		[60 00 02 22]
static const UINT8 CFE4_PANANIM[] = {
	0x1B, 0x5C, 0x00, 0x1F,		//	MOVE.B	(A4)+, $1F(A5)
	0x67, 0x16,					//	BEQ.S	loc_1610F4		[67 16]
	0x1B, 0x5C, 0x00, 0x20,		//	MOVE.B	(A4)+, $20(A5)
	0x1B, 0x5C, 0x00, 0x21,		//	MOVE.B	(A4)+, $21(A5)
	0x1B, 0x5C, 0x00, 0x22,		//	MOVE.B	(A4)+, $22(A5)
	0x1B, 0x54, 0x00, 0x23,		//	MOVE.B	(A4), $23(A5)
	0x1B, 0x5C, 0x00, 0x24,		//	MOVE.B	(A4)+, $24(A5)
	0x4E, 0x75};					//	RTS
//	//loc_1610F4:
//	0x10, 0x3C, 0x00, 0xB4,		//	MOVE.B	#$B4, D0
//	0x12, 0x2D, 0x00, 0x27,		//	MOVE.B	$27(A5), D1
//	0x60, 0x00, 0xFB, 0x86};	//	BRA.W	WriteFMMain_Z	[60 00 FB 86]
static const UINT8 CFE5_CHGPFMVOL[] = {
	0x10, 0x1C,					//	MOVE.B	(A4)+, D0
	0x4A, 0x2D, 0x00, 0x01,		//	TST.B	$01(A5)
	0x6A, 0x08,					//	BPL.S	cfE6_ChgFMVol
	0xD1, 0x2D, 0x00, 0x09,		//	ADD.B	D0, $09(A5)
	0x52, 0x4C,					//	ADDQ.W	#1, A4
	0x4E, 0x75};				//	RTS
static const UINT8 CFE6_CHGFMVOL[] = {
	0x10, 0x1C,					//	MOVE.B	(A4)+, D0
	0xD1, 0x2D, 0x00, 0x09,		//	ADD.B	D0, $09(A5)
	0x60, 0x00, 0xAA, 0xAA};	//	BRA.W	RefreshFMVol	[60 00 01 22]
static const UINT8 CFE7_HOLD[] = {
	0x08, 0xD5, 0x00, 0x04,		//	BSET	#4, $00(A5)
	0x4E, 0x75};				//	RTS
static const UINT8 CFE8_NOTESTOP[] = {
	0x1B, 0x54, 0x00, 0xAA,		//	MOVE.B	(A4), $12(A5)	[1B 54 00 12]
	0x1B, 0x5C, 0x00, 0xAA,		//	MOVE.B	(A4)+, $13(A5)	[1B 5C 00 13] (-> $14(A5) in 68k/Pico)
	0x4E, 0x75};				//	RTS
static const UINT8 CFE9_SETLFO_T1[] = {
	0x22, 0x6E, 0x00, 0xAA,		//	MOVEA.L	$18(A6), A1
	0x67, 0x04,					//	BEQ.S	loc_0770D0
	0x22, 0x6E, 0x00, 0xAA,		//	MOVEA.L	$1C(A5), A1
	//loc_0770D0:
	0x16, 0x14,					//	MOVE.B	(A4), D3
	0xD0, 0xFC, 0x00, 0x09};	//	ADDA.W	#9, A0
static const UINT8 CFE9_SETLFO[] = {
	0x22, 0x6E, 0x00, 0xAA,		//	MOVEA.L	$20(A6), A1
	0x67, 0x04,					//	BEQ.S	loc_161134
	0x22, 0x6D, 0x00, 0xAA,		//	MOVEA.L	$20(A5), A1
	//loc_161134:
	0x16, 0x14,					//	MOVE.B	(A4), D3
	0xD0, 0xFC, 0x00, 0x09};	//	ADDA.W	#9, A0
//	0x45, 0xFA, 0x00, 0x3C,		//	LEA 	AMEnable_Ops(PC), A2	[45 FA 00 3C]
//	0x7C, 0x03,					//	MOVEQ	#3, D6
//	//loc_161140:
//	0x12, 0x19,					//	MOVE.B	(A1)+, D1
//	0x10, 0x1A,					//	MOVE.B	(A2)+, D0
//	0x08, 0x03, 0x00, 0x07,		//	BTST	#7, D3
//	0x67, 0x08,					//	BEQ.S	loc_161152
//	0x08, 0xC1, 0x00, 0x07,		//	BSET	#7, D1
//	0x4E, 0xBA, 0xFB, 0x34,		//	JSR 	WriteFMMain_Z		[4E BA FB 34]
//	//loc_161152:
//	0xE3, 0x4B,					//	LSL.W	#1, D3
//	0x51, 0xCE, 0xFF, 0xEA,		//	DBRA	D6, loc_161140
//	0x12, 0x1C,					//	MOVE.B	(A4)+, D1
//	0x70, 0x22,					//	MOVEQ	#$22, D0
//	0x4E, 0xBA, 0xFB, 0x3E,		//	JSR 	WriteFMI_Z
//	0x12, 0x1C,					//	MOVE.B	(A4)+, D1
//	0x10, 0x2D, 0x00, 0x27,		//	MOVE.B	$27(A5), D0
//	0x02, 0x00, 0x00, 0xC0,		//	ANDI.B	#$C0, D0
//	0x82, 0x00,					//	OR.B	D0, D1
//	0x1B, 0x41, 0x00, 0x27,		//	MOVE.B	D1, $27(A5)
//	0x10, 0x3C, 0x00, 0xB4,		//	MOVE.B	#$B4, D0
//	0x60, 0x00, 0xFB, 0x0E,		//	BRA.W	WriteFMMain_Z		[60 00 FB 0E]
//	//AMEnable_Ops:
//	0x60, 0x68, 0x64, 0x6C};	//	dc.b	$60, $68, $64, $6C
static const UINT8 CFEA_SETTEMPO[] = {
	0x1D, 0x54, 0x00, 0xAA,		//	MOVE.B	(A4), $02(A6)		[1D 54 00 02]
	0x1D, 0x5C, 0x00, 0xAA,		//	MOVE.B	(A4)+, $01(A6)		[1D 5C 00 01]
	0x4E, 0x75};				//	RTS
static const UINT8 CFEB_PLAYSOUND[] = {
	0x1D, 0x5C, 0x00, 0x0A,		//	MOVE.B	(A4)+, $0A(A6)
	0x4E, 0x75};				//	RTS
static const UINT8 CFEC_CHGPSGVOL[] = {
	0x10, 0x1C,					//	MOVE.B	(A4)+, D0
	0xD1, 0x2D, 0x00, 0x09,		//	ADD.B	D0, $09(A5)
	0x4E, 0x75};				//	RTS
static const UINT8 CFEDEE_FMWRITE[] = {
	0x10, 0x1C,					//	MOVE.B	(A4)+, D0
	0x12, 0x1C,					//	MOVE.B	(A4)+, D1
	0x60, 0x00, 0xAA, 0xAA};	//	BRA.W	WriteFMMain_Z	[60 00 FA EA, cfED_FMChnWrite]
//	0x60, 0x00, 0xAA, 0xAA};	//	BRA.W	WriteFMI_Z		[60 00 FA FA, cfEE_FM1Write]
static const UINT8 CFEF_SETFMINS[] = {
	0x70, 0x00,					//	MOVEQ	#0, D0
	0x10, 0x1C,					//	MOVE.B	(A4)+, D0
	0x1B, 0x40, 0x00, 0x0B,		//	MOVE.B	D0, $0B(A5)
	0x08, 0x15, 0x00, 0x02};	//	BTST	#2, (A5)
//	0x66, 0x00, 0x00, 0x7E};	//	BNE.W	locret_161230	[60 00 00 7E]
static const UINT8 CFF0_MODSETUP[] = {
	0x08, 0xED, 0x00, 0x07, 0x00, 0x0A,	//	BSET	#7, $0A(A5)
	0x2B, 0x4C, 0x00, 0x14,				//	MOVE.L	A4, $14(A5)
	0x1B, 0x5C, 0x00, 0x18,				//	MOVE.B	(A4)+, $18(A5)
	0x1B, 0x5C, 0x00, 0x19,				//	MOVE.B	(A4)+, $19(A5)
	0x1B, 0x5C, 0x00, 0x1A,				//	MOVE.B	(A4)+, $1A(A5)
	0x10, 0x1C,							//	MOVE.B	(A4)+, D0
	0xE2, 0x08,							//	LSR.B	#1, D0
	0x1B, 0x40, 0x00, 0x1B,				//	MOVE.B	D0, $1B(A5)
	0x42, 0x6D, 0x00, 0x1C,				//	CLR.W	$1C(A5)
	0x4E, 0x75};						//	RTS
static const UINT8 CFF0_MODSETUP_T1[] = {
	0x08, 0xD5, 0x00, 0x03,				//	BSET	#3, (A5)
	0x2B, 0x4C, 0x00, 0x14,				//	MOVE.L	A4, $14(A5)
	0x1B, 0x5C, 0x00, 0x18,				//	MOVE.B	(A4)+, $18(A5)
	0x1B, 0x5C, 0x00, 0x19,				//	MOVE.B	(A4)+, $19(A5)
	0x1B, 0x5C, 0x00, 0x1A,				//	MOVE.B	(A4)+, $1A(A5)
	0x10, 0x1C,							//	MOVE.B	(A4)+, D0
	0xE2, 0x08,							//	LSR.B	#1, D0
	0x1B, 0x40, 0x00, 0x1B,				//	MOVE.B	D0, $1B(A5)
	0x42, 0x6D, 0x00, 0x1C,				//	CLR.W	$1C(A5)
	0x4E, 0x75};						//	RTS
static const UINT8 CFF1_MODTYPEPFM[] = {
	0x10, 0x1C,					//	MOVE.B	(A4)+, D0
	0x4A, 0x2D, 0x00, 0x01,		//	TST.B	$01(A5)
	0x6A, 0x00, 0x00, 0xAA,		//	BPL.W	cfF4_ModType	[6A 00 00 E8]
	0x1B, 0x40, 0x00, 0x0A,		//	MOVE.B	D0, $0A(A5)
	0x10, 0x1C,					//	MOVE.B	(A4)+, D0
	0x4E, 0x75};				//	RTS
static const UINT8 CFF2_STOPTRK[] = {
	0x08, 0x95, 0x00, 0x07,		//	BCLR	#7 ,(A5)
	0x08, 0x95, 0x00, 0x04,		//	BCLR	#4, (A5)
	// Turn Note Off code
};
static const UINT8 CFF3_PSGNOISE[] = {
	0x1B, 0x7C, 0x00, 0xE0, 0x00, 0x01,		//	MOVE.B	#$E0, $01(A5)
	0x1B, 0x5C, 0x00};	// This is enough to check for this routine.
//	0x1B, 0x5C, 0x00, 0x25,					//	MOVE.B	(A4)+, $25(A5)
//	0x08, 0x15, 0x00, 0x02,					//	BTST	#2, (A5)
//	0x66, 0x08,								//	BNE.S	locret_1613D4
//	0x13, 0xEC, 0xFF, 0xFF, 0x00, 0xC0, 0x00, 0x11,	//	MOVE.B	-1(A4), $C00011
//	0x4E, 0x75};							//	RTS
static const UINT8 CFF4_MODTYPE[] = {
	0x1B, 0x5C, 0x00, 0x0A,		//	MOVE.B	(A4)+, $0A(A5)
	0x4E, 0x75};				//	RTS
static const UINT8 CFF5_SETPSGINS[] = {
	0x1B, 0x5C, 0x00, 0x0B,		//	MOVE.B	(A4)+, $0B(A5)
	0x4E, 0x75};				//	RTS
static const UINT8 CFF6_GOTO[] = {
	0x10, 0x1C,					//	MOVE.B	(A4)+, D0
	0xE1, 0x48,					//	LSL.W	#8, D0
	0x10, 0x1C,					//	MOVE.B	(A4)+, D0
	0xD8, 0xC0,					//	ADDA.W	D0, A4
	0x53, 0x4C,					//	SUBQ.W	#1, A4
	0x4E, 0x75};				//	RTS
static const UINT8 CFF6_GOTO_RISTAR[] = {
	0x10, 0x1C,					//	MOVE.B	(A4)+, D0
	0xE1, 0x48,					//	LSL.W	#8, D0
	0x10, 0x1C,					//	MOVE.B	(A4)+, D0
	0xD8, 0xC0,					//	ADDA.W	D0, A4
	0x4E, 0x75};				//	RTS
static const UINT8 CFF7_LOOP[] = {
	0x70, 0x00,					//	MOVEQ	#0, D0
	0x10, 0x1C,					//	MOVE.B	(A4)+, D0
	0x12, 0x1C,					//	MOVE.B	(A4)+, D1
	0x4A, 0x35, 0x00, 0xAA,		//	TST.B	$28(A5, D0.W)	[xx 35 00 28, also below]
	0x66, 0x04,					//	BNE.S	loc_1613FE		[66 04]
	0x1B, 0x81, 0x00, 0xAA,		//	MOVE.B	D1, $28(A5, D0.W)
	//loc_1613FE:
	0x53, 0x35, 0x00, 0xAA,		//	SUBQ.B	#1, $28(A5, D0.W)
	0x66, 0xAA,					//	BNE.S	cfF6_GoTo		[66 DE]
	0x54, 0x4C,					//	ADDQ.W	#2, A4
	0x4E, 0x75};				//	RTS
static const UINT8 CFF8_GOSUB[] = {
	0x70, 0x00,					//	MOVEQ	#0, D0
	0x10, 0x2D, 0x00, 0x0D,		//	MOVE.B	$0D(A5), D0
	0x59, 0x00,					//	SUBQ.B	#4, D0
	0x2B, 0x8C, 0x00, 0x00,		//	MOVE.L	A4, (A5,D0.W)
	0x1B, 0x40, 0x00, 0x0D,		//	MOVE.B	D0, $0D(A5)
	0x60, 0xAA};				//	BRA.S	cfF6_GoTo		[60 C8]
static const UINT8 CFF9_RETURN[] = {
	0x70, 0x00,					//	MOVEQ	#0, D0
	0x10, 0x2D, 0x00, 0x0D,		//	MOVE.B	$0D(A5), D0
	0x28, 0x75, 0x00, 0x00,		//	MOVEA.L	(A5,D0.W), A4
	0x54, 0x4C,					//	ADDQ.W	#2, A4
	0x58, 0x00,					//	ADDQ.B	#4, D0
	0x1B, 0x40, 0x00, 0x0D,		//	MOVE.B	D0, $0D(A5)
	0x4E, 0x75};				//	RTS
static const UINT8 CFF9_RETURN_S1[] = {
	0x70, 0x00,					//	MOVEQ	#0, D0
	0x10, 0x2D, 0x00, 0x0D,		//	MOVE.B	$0D(A5), D0
	0x28, 0x75, 0x00, 0x00,		//	MOVEA.L	(A5,D0.W), A4
	0x2B, 0xBC, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,	//	MOVE.L	#0, (A5,D0.W)
	0x54, 0x4C,					//	ADDQ.W	#2, A4
	0x58, 0x00,					//	ADDQ.B	#4, D0
	0x1B, 0x40, 0x00, 0x0D,		//	MOVE.B	D0, $0D(A5)
	0x4E, 0x75};				//	RTS
static const UINT8 CFFA_TICKMULT[] = {
	0x1B, 0x5C, 0x00, 0x02,		//	MOVE.B	(A4)+, $02(A5)
	0x4E, 0x75};				//	RTS
static const UINT8 CFFB_CHGTRANSP[] = {
	0x10, 0x1C,					//	MOVE.B	(A4)+, D0
	0xD1, 0x2D, 0x00, 0x08,		//	ADD.B	D0, $08(A5)
	0x4E, 0x75};				//	RTS
static const UINT8 CFFC_MODULATON[] = {
	0x08, 0xED, 0x00, 0x07, 0x00, 0x0A,	//	BSET	#7, $0A(A5)
	0x4E, 0x75};						//	RTS
static const UINT8 CFFD_MODULATOFF[] = {
	0x08, 0xAD, 0x00, 0x07, 0x00, 0x0A,	//	BCLR	#7, $0A(A5)
	0x4E, 0x75};						//	RTS
static const UINT8 CFF1_MODULATON_T1[] = {
	0x08, 0xD5, 0x00, 0x03,				//	BSET	#3, (A5)
	0x4E, 0x75};						//	RTS
static const UINT8 CFF4_MODULATOFF_T1[] = {
	0x08, 0x95, 0x00, 0x03,				//	BCLR	#3, (A5)
	0x4E, 0x75};						//	RTS
static const UINT8 CFFD_LOADMOD_T1[] = {
	0x20, 0x79, 0xAA, 0xAA, 0xAA, 0xAA,	//	MOVEA.L	ModDataPtr, A0	[20 79 00 07 60 10]
	0x70, 0x00,							//	MOVEQ	#0, D0
	0x10, 0x1C,							//	MOVE.B	(A4)+, D0
	0x53, 0x00,							//	SUBQ.B	#1, D0
	0xE5, 0x48,							//	LSL.W	#2, D0
	0xD0, 0xC0,							//	ADDA.W	D0, A0
	0x08, 0xD5, 0x00, 0x03,				//	BSET	#3, (A5)
	0x2B, 0x48, 0x00, 0x14,				//	MOVE.L	A0, $14(A5)
	0x1B, 0x58, 0x00, 0x18,				//	MOVE.B	(A0)+, $18(A5)
	0x1B, 0x58, 0x00, 0x19,				//	MOVE.B	(A0)+, $19(A5)
	0x1B, 0x58, 0x00, 0x1A,				//	MOVE.B	(A0)+, $1A(A5)
	0x10, 0x18,							//	MOVE.B	(A0)+, D0
	0xE2, 0x08,							//	LSR.B	#1, D0
	0x1B, 0x40, 0x00, 0x1B,				//	MOVE.B	D0, $1B(A5)
	0x42, 0x6D, 0x00, 0x1C,				//	CLR.W	$1C(A5)
	0x4E, 0x75};						//	RTS
static const UINT8 CFFE_SPCFM3MODE_T1[] = {
	0x41, 0xEE, 0x00, 0xAA,				//	LEA 	$10(A6), A0	[41 EE 00 10]
	0x70, 0x07,							//	MOVEQ	#7, D0
	//loc_7741A:
	0x10, 0xDC,							//	MOVE.B	(A4)+, (A0)+
	0x51, 0xC8, 0xFF, 0xFC,				//	DBRA	D0, loc_7741A
	0x1D, 0x7C, 0x00, 0x80, 0x00, 0x0F,	//	MOVE.B	#$80, $0F(A6)
	0x10, 0x3C, 0x00, 0x27,				//	MOVE.B	#$27,D0
	0x72, 0x40,							//	MOVEQ	#$40,D1
	0x60, 0x00, 0xF8, 0xA6};			//	BRA.W	WriteFMI_Z	[60 00 F8 A6]
static const UINT8 CFFE_SPCFM3MODE[] = {
	0x41, 0xEE, 0x00, 0xAA,				//	LEA 	$18(A6), A0	[41 EE 00 18]
	0x4A, 0x2E, 0x00, 0xAA,				//	TST.B	$0E(A6)		[4A 2E 00 0E]
	0x66, 0x0A,							//	BNE.S	loc_161460	[66 0A]
	0x41, 0xEE, 0x00, 0xAA,				//	LEA 	$10(A6), A0	[41 EE 00 10]
	0x1D, 0x7C, 0x00, 0x80, 0x00, 0x0F,	//	MOVE.B	#$80, $0F(A6)
	//loc_161460:
	0x70, 0x03,							//	MOVEQ	#3, D0
	//loc_161462:
	0x72, 0x00,							//	MOVEQ	#0, D1
	0x12, 0x1C,							//	MOVE.B	(A4)+, D1
	0xE3, 0x49};						//	LSL.W	#1, D1
//	0x30, 0xFB, 0x10, 0x10,				//	MOVE.W	FM3_FreqVals(PC,D1.W), (A0)+	[30 FB 10 10]
//	0x51, 0xC8, 0xFF, 0xF4,				//	DBRA	D0, loc_161462
//	0x10, 0x3C, 0x00, 0x27,				//	MOVE.B	#$27, D0
//	0x72, 0x40,							//	MOVEQ	#$40, D1
//	0x60, 0x00, 0xF8, 0x24,				//	BRA.W	WriteFMI_Z	[60 00 F8 24]
//	//FM3_FreqVals:
//	0x00, 0x00, 0x01, 0x80, 0x01, 0xF4, 0x02, 0x60};	//	DC.W	$000, $180, $1F4, $260
static const UINT8 CF00_SSGEG[] = {
	0x43, 0xFA, 0x00, 0xAA,		//	LEA 	SSGEG_Ops(PC), A1	[43 FA 00 1A]
	0x76, 0x03,					//	MOVEQ	#3, D3
	//loc_161488:
	0x10, 0x19,					//	MOVE.B	(A1)+, D0
	0x12, 0x1C,					//	MOVE.B	(A4)+, D1
	0xAA, 0xAA, 0xAA, 0xAA,		//	JSR 	WriteFMMain_Z(PC)	[4E BA F7 F6, is BSR.W in Ristar]
	0x10, 0x19,					//	MOVE.B	(A1)+, D0
	0x72, 0x1F,					//	MOVEQ	#$1F, D1
	0xAA, 0xAA, 0xAA, 0xAA,		//	JSR 	WriteFMMain_Z(PC)	[4E BA F7 EE]
	0x51, 0xCB, 0xFF, 0xEE,		//	DBRA	D3, loc_161488
	0x4E, 0x75};				//	RTS
//	//SSGEG_Ops:
//	0x90, 0x50,					//	DC.B  $90, $50
//	0x98, 0x58,					//	DC.B  $98, $58
//	0x94, 0x54,					//	DC.B  $94, $54
//	0x9C, 0x5C};				//	DC.B  $9C, $5C
static const UINT8 CF00_SSGEG_T1[] = {
	0x43, 0xFA, 0x00, 0xAA,		//	LEA 	SSGEG_Ops(PC), A1	[43 FA 00 1E]
	0x76, 0x03,					//	MOVEQ	#3, D3
	//loc_774E2:
	0x10, 0x19,					//	MOVE.B	(A1)+, D0
	0x12, 0x1C,					//	MOVE.B	(A4)+, D1
	0x08, 0xC1, 0x00, 0x03,		//	BSET	#3, D1
	0xAA, 0xAA, 0xAA, 0xAA,		//	JSR 	WriteFMMain_Z(PC)	[4E BA F7 F6]
	0x10, 0x19,					//	MOVE.B	(A1)+, D0
	0x72, 0x1F,					//	MOVEQ	#$1F, D1
	0xAA, 0xAA, 0xAA, 0xAA,		//	JSR 	WriteFMMain_Z(PC)	[4E BA F7 EE]
	0x51, 0xCB, 0xFF, 0xEA,		//	DBRA	D3, loc_774E2
	0x4E, 0x75};				//	RTS
static const UINT8 CF01_MUSPAUSE[] = {
	0x76, 0xAA,					//	MOVEQ	#$30, D3	[76 30]
	0x10, 0x1C,					//	MOVE.B	(A4)+, D0
	0x67, 0xAA,					//	BEQ.S	loc_161502	[67 56]
	0x26, 0x4D,					//	MOVEA.L	A5, A3
	// ... [The long rest is unimportant for detection.]
};
static const UINT8 CF02_TICKMULALL[] = {
	0x41, 0xEE, 0x00, 0xAA,		//	LEA 	$40(A6), A0	[41 EE 00 40]
	0x10, 0x1C,					//	MOVE.B	(A4)+, D0
	0x72, 0xAA,					//	MOVEQ	#$30, D1	[72 30]
	0x74, 0xAA,					//	MOVEQ	#9, D2		[74 09]
	//loc_161568:
	0x11, 0x40, 0x00, 0x02,		//	MOVE.B	D0, $02(A0)
	0xD0, 0xC1,					//	ADDA.W	D1, A0
	0x51, 0xCA, 0xFF, 0xF8,		//	DBRA	D2, loc_161568
	0x4E, 0x75};				//	RTS
static const UINT8 CF03_FADESPC[] = {
	0x0C, 0x2E, 0x00, 0x02, 0x00, 0xAA,	//	CMPI.B	#2, $28(A6)		[0C 2E 00 02 00 28]
	0x67, 0x00, 0x00, 0xAA,				//	BEQ.W	locret_16158C	[67 00 00 10]
	0x1D, 0x7C, 0x00, 0x01, 0x00, 0xAA,	//	MOVE.B	#1, $28(A6)		[1D 7C 00 01 00 28]
	0x1D, 0x5C, 0x00, 0xAA};			//	MOVE.B	(A4)+, $29(A6)	[1D 5C 00 29]
//	0x1D, 0x5C, 0x00, 0x2A,				//	MOVE.B	(A4)+, $2A(A6)
//	0x4E, 0x75};						//	RTS
static const UINT8 CF04_FADESPSTOP[] = {
	0x1D, 0x7C, 0x00, 0x80, 0x00, 0xAA,	//	MOVE.B	#$80, $28(A6)	[1D 7C 00 80 00 28]
	0x4E, 0x75};						//	RTS

typedef struct _coord_flag_library
{
	UINT32 Size;
	const UINT8* Data;
	const char* Name;
} CFLAG_LIB;

CFLAG_LIB CmdFlagLib[] = {
	{sizeof(CF_NULL),			CF_NULL,			"cf_null"},
	{sizeof(CFE0_PAN),			CFE0_PAN,			"cfE0_Pan"},
	{sizeof(CFE1_DETUNE),		CFE1_DETUNE,		"cfE1_Detune"},
//	{sizeof(CFE2_SETCOMM),		CFE2_SETCOMM,		"cfE2_SetComm"},	// too generic to be here
	{sizeof(CFE3_SILENCETRK),	CFE3_SILENCETRK,	"cfE3_SilenceTrk"},
	{sizeof(CFE4_PANANIM),		CFE4_PANANIM,		"cfE4_PanAnim"},
	{sizeof(CFE5_CHGPFMVOL),	CFE5_CHGPFMVOL,		"cfE5_ChgPFMVol"},
	{sizeof(CFE6_CHGFMVOL),		CFE6_CHGFMVOL,		"cfE6_ChgFMVol"},
	{sizeof(CFE7_HOLD),			CFE7_HOLD,			"cfE7_Hold"},
	{sizeof(CFE8_NOTESTOP),		CFE8_NOTESTOP,		"cfE8_NoteStop"},
	{sizeof(CFE9_SETLFO),		CFE9_SETLFO,		"cfE9_SetLFO"},
	{sizeof(CFE9_SETLFO_T1),	CFE9_SETLFO_T1,		"cfE9_SetLFO [Type 1b]"},
	{sizeof(CFEA_SETTEMPO),		CFEA_SETTEMPO,		"cfEA_SetTempo"},
	{sizeof(CFEB_PLAYSOUND),	CFEB_PLAYSOUND,		"cfEB_PlaySound"},
	{sizeof(CFEC_CHGPSGVOL),	CFEC_CHGPSGVOL,		"cfEC_ChgPSGVol"},
//	{sizeof(CFED_FMCHNWRITE),	CFED_FMCHNWRITE,	"cfED_FMChnWrite"},
//	{sizeof(CFEE_FM1WRITE),		CFEE_FM1WRITE,		"cfEE_FM1Write"},
	{sizeof(CFEDEE_FMWRITE),	CFEDEE_FMWRITE,		"cfEx_FMxWrite"},
	{sizeof(CFEF_SETFMINS),		CFEF_SETFMINS,		"cfEF_SetFMIns"},
	{sizeof(CFF0_MODSETUP),		CFF0_MODSETUP,		"cfF0_ModSetup"},
	{sizeof(CFF0_MODSETUP_T1),	CFF0_MODSETUP_T1,	"cfF0_ModSetup [Type 1b]"},
	{sizeof(CFF1_MODTYPEPFM),	CFF1_MODTYPEPFM,	"cfF1_ModTypePFM"},
	{sizeof(CFF2_STOPTRK),		CFF2_STOPTRK,		"cfF2_StopTrk"},
	{sizeof(CFF3_PSGNOISE),		CFF3_PSGNOISE,		"cfF3_PSGNoise"},
	{sizeof(CFF4_MODTYPE),		CFF4_MODTYPE,		"cfF4_ModType"},
	{sizeof(CFF5_SETPSGINS),	CFF5_SETPSGINS,		"cfF5_SetPSGIns"},
	{sizeof(CFF6_GOTO),			CFF6_GOTO,			"cfF6_GoTo"},
	{sizeof(CFF6_GOTO_RISTAR),	CFF6_GOTO_RISTAR,	"cfF6_GoTo [Ristar]"},
	{sizeof(CFF7_LOOP),			CFF7_LOOP,			"cfF7_Loop"},
	{sizeof(CFF8_GOSUB),		CFF8_GOSUB,			"cfF8_GoSub"},
	{sizeof(CFF9_RETURN),		CFF9_RETURN,		"cfF9_Return"},
	{sizeof(CFF9_RETURN_S1),	CFF9_RETURN_S1,		"cfF9_Return [Sonic 1]"},
	{sizeof(CFFA_TICKMULT),		CFFA_TICKMULT,		"cfFA_TickMult"},
	{sizeof(CFFB_CHGTRANSP),	CFFB_CHGTRANSP,		"cfFB_ChgTransp"},
	{sizeof(CFFC_MODULATON),	CFFC_MODULATON,		"cfFC_ModulatOn"},
	{sizeof(CFFD_MODULATOFF),	CFFD_MODULATOFF,	"cfFD_ModulatOff"},
	{sizeof(CFF1_MODULATON_T1),	CFF1_MODULATON_T1,	"cfF1_ModulatOn [Type 1b]"},
	{sizeof(CFF4_MODULATOFF_T1),CFF4_MODULATOFF_T1,	"cfF4_ModulatOff [Type 1b]"},
	{sizeof(CFFD_LOADMOD_T1),	CFFD_LOADMOD_T1,	"cfFD_LoadMod [Type 1b]"},
	{sizeof(CFFE_SPCFM3MODE),	CFFE_SPCFM3MODE,	"cfFE_SpcFM3Mode"},
	{sizeof(CFFE_SPCFM3MODE_T1),CFFE_SPCFM3MODE_T1,	"cfFE_SpcFM3Mode [Type 1b]"},
	
	{sizeof(CF00_SSGEG),		CF00_SSGEG,			"cf00_SSGEG"},
	{sizeof(CF00_SSGEG_T1),		CF00_SSGEG_T1,		"cf01_SSGEG [Type 1b]"},
	{sizeof(CF01_MUSPAUSE),		CF01_MUSPAUSE,		"cf01_MusPause"},
	{sizeof(CF02_TICKMULALL),	CF02_TICKMULALL,	"cf02_TickMulAll"},
	{sizeof(CF03_FADESPC),		CF03_FADESPC,		"cf03_FadeSpc"},
	{sizeof(CF04_FADESPSTOP),	CF04_FADESPSTOP,	"cf04_FadeSpStop"},

	{sizeof(CFE2_SETCOMM),		CFE2_SETCOMM,		"cf_SetGlobalVal"},
};
static const UINT8 CFLibSize = sizeof(CmdFlagLib) / sizeof(CFLAG_LIB);

#endif	// __SMPS68K_ROUTINELIB_H__
