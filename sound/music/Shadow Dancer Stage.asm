; Shadow Dancer (Mega Drive), Stage 1-1 and 3-1.
; Converted from 01 Stage 1-1, 3-1.mmw. See build_tools/sound/README.md.
; The original loads patch TLs directly. Its volume writes either match the
; loaded carrier TL or are replaced by another patch before the next note.
; Keep FM track attenuation at zero to preserve the original levels.

ShadowDancerStage_Header:
	smpsHeaderStartSong	2, 1
	smpsHeaderVoice	ShadowDancerStage_Voices
	smpsHeaderChan	$06, $02
	smpsHeaderTempo	$02, $CD

	smpsHeaderDAC	ShadowDancerStage_DAC
	smpsHeaderFM	ShadowDancerStage_FM1,	$00, $00
	smpsHeaderFM	ShadowDancerStage_FM2,	$F4, $00
	smpsHeaderFM	ShadowDancerStage_FM3,	$00, $00
	smpsHeaderFM	ShadowDancerStage_FM4,	$00, $00
	smpsHeaderFM	ShadowDancerStage_FM5,	$00, $00
	smpsHeaderPSG	ShadowDancerStage_PSG1,	$D0, $03, $00, fTone_ShadowDancer
	smpsHeaderPSG	ShadowDancerStage_PSG2,	$D0, $03, $00, fTone_ShadowDancer

; FM5 Data
ShadowDancerStage_FM5:
	dc.b	nRst, $09, nRst, $0C

ShadowDancerStage_Jump01:
	smpsModSet	$0E, $01, $04, $04
	smpsSetvoice	$04
	dc.b	nG6, $03, nD6, $2A, nE6, $03, nB5, $2D, nG5, $03, nA5, $06
	dc.b	nE5, $27, nD5, $03, nE5, $2D, nG6, $03, nD6, $2D, nE6, $03
	dc.b	nB5, $2D, nG5, $03, nA5, $06, nE5, $27, nD5, $03, nE5, $27
	smpsAlterPitch	$F4
	smpsModSet	$00, $01, $09, $04

ShadowDancerStage_Loop0C:
	smpsSetvoice	$06
	smpsCall	ShadowDancerStage_Call09
	smpsLoop	$00, $02, ShadowDancerStage_Loop0C
	smpsAlterPitch	$0C
	smpsCall	ShadowDancerStage_Call0A
	dc.b	nRst, $09
	smpsJump	ShadowDancerStage_Jump01

ShadowDancerStage_Call09:
	dc.b	nBb5, $30, nD6, $12, nC6, nD6, $0C, nG5, $2A, nFs5, $06
	dc.b	nF5, $2A, nC6, $06, nCs6, $30, nEb6, $12, nAb5, nBb5, $0C
	dc.b	nB5, $2A, nB6, $06, nBb6, $24, nAb6, $06, nFs6, $06
	smpsReturn

ShadowDancerStage_Call0A:
	dc.b	nA4, $03, nA5, nA4, nBb4, nBb5, nBb4, nB4, nB5, nB4, nC5, nC6
	dc.b	nCs5, nCs6, nD5, nD6, nD5
	smpsReturn

; FM1 Data
ShadowDancerStage_FM1:
	dc.b	nRst, $0C

ShadowDancerStage_Jump00:
	smpsCall	ShadowDancerStage_Call08
	smpsAlterPitch	$F4

ShadowDancerStage_Loop0B:
	smpsSetvoice	$00
	smpsCall	ShadowDancerStage_Call09
	smpsLoop	$00, $02, ShadowDancerStage_Loop0B
	smpsAlterPitch	$0C
	smpsCall	ShadowDancerStage_Call0A
	smpsJump	ShadowDancerStage_Jump00

ShadowDancerStage_Call08:
	smpsSetvoice	$04
	dc.b	nG6, $03, nD6, $2A, nE6, $03, nB5, $2D, nG5, $03, nA5, $06
	dc.b	nE5, $27, nD5, $03, nE5, $2D, nG6, $03, nD6, $2D, nE6, $03
	dc.b	nB5, $2D, nG5, $03, nA5, $06, nE5, $27, nD5, $03, nE5, $2A
	dc.b	nRst, $06
	smpsReturn

; FM2 Data
ShadowDancerStage_FM2:
	smpsSetvoice	$02
	dc.b	nRst, $03, nA3, nG3, nA3

ShadowDancerStage_Loop08:
	dc.b	nEb4, $03, nD4, nC4, nA3, nRst, nA3, nRst, nA3, nRst, nA3, nA3
	dc.b	nA4, nA3, nRst, nA3, nRst, nA3, nG4, nA3, nRst, nA3, nA3, nA4
	dc.b	nEb4, $06, nAb3, $03, nA3, nD4, $06, nA3, $03, nG3, nA3
	smpsLoop	$00, $04, ShadowDancerStage_Loop08
	smpsSetvoice	$05

ShadowDancerStage_Loop09:
	dc.b	nC4, $03, nC5, nC4, nC4, nEb4, $06, nC4, $03, nC4, nF4, $06
	dc.b	nC4, $03, nEb4, $06, nC4, $03, nCs4, nC4, nC4, nC5, nC4, nC4
	dc.b	nD4, $06, nC4, $03, nF4, $06, nC4, $03, nD4, nC4, nFs4, nC4
	dc.b	nG4, nC4
	smpsLoop	$00, $02, ShadowDancerStage_Loop09

ShadowDancerStage_Loop0A:
	dc.b	nCs4, $03, nCs5, nCs4, nCs4, nE4, $06, nCs4, $03, nCs4, nFs4, $06
	dc.b	nCs4, $03, nE4, $06, nCs4, $03, nEb4, nCs4, nCs4, nCs5, nCs4, nCs4
	dc.b	nEb4, $06, nCs4, $03, nE4, $06, nCs4, $03, nEb4, nCs4, nG4, nCs4
	dc.b	nAb4, nCs4
	smpsLoop	$00, $02, ShadowDancerStage_Loop0A
	smpsLoop	$01, $02, ShadowDancerStage_Loop09
	dc.b	nA3, $03, nA4, nA3, nBb3, nBb4, nBb3, nB3, nB4, nB3, nC4, nC5
	dc.b	nCs4, nCs5, nD4, nD5, nD4
	smpsSetvoice	$02
	smpsJump	ShadowDancerStage_Loop08

; FM3 Data
ShadowDancerStage_FM3:
	smpsPan	panRight, $00
	dc.b	nRst, $0C

ShadowDancerStage_Loop05:
	smpsSetvoice	$01
	smpsCall	ShadowDancerStage_Call04
	smpsLoop	$00, $04, ShadowDancerStage_Loop05
	smpsSetvoice	$03
	smpsModSet	$00, $01, $07, $04

ShadowDancerStage_Loop06:
	smpsCall	ShadowDancerStage_Call05
	smpsLoop	$00, $04, ShadowDancerStage_Loop06

ShadowDancerStage_Loop07:
	smpsCall	ShadowDancerStage_Call06
	smpsLoop	$00, $04, ShadowDancerStage_Loop07
	smpsLoop	$01, $02, ShadowDancerStage_Loop06
	smpsCall	ShadowDancerStage_Call07
	smpsModOff
	smpsJump	ShadowDancerStage_Loop05

ShadowDancerStage_Call04:
	dc.b	nAb5, $03, nA5, nD6, nG6, nFs6, nRst, nA5, nRst, $06, nF6, $03
	dc.b	nE6, nRst, nA5, nAb5, nE6, nD6, nA5, nRst, nC6, nD6, nRst, $06
	dc.b	nD6, $03, nAb5, nA5, nB5, nA5, nRst, nC6, nAb5, nB5, nC6
	smpsReturn

ShadowDancerStage_Call05:
	dc.b	nF4, $09, nC5, $06, nC5, nF5, nBb4, nC5, nG5, nBb4, $03
	smpsReturn

ShadowDancerStage_Call06:
	dc.b	nFs4, $09, nCs5, $06, nCs5, nFs5, nB4, nCs5, nAb5, nB4, $03
	smpsReturn

ShadowDancerStage_Call07:
	dc.b	nRst, $03, nE5, $06, nA5, nF5, nB5, nG5, nC6, nB5, nG6, $03
	smpsReturn

; FM4 Data
ShadowDancerStage_FM4:
	smpsPan	panLeft, $00
	dc.b	nRst, $0C

ShadowDancerStage_Loop02:
	smpsSetvoice	$01
	smpsCall	ShadowDancerStage_Call00
	smpsLoop	$00, $04, ShadowDancerStage_Loop02
	smpsSetvoice	$03
	smpsModSet	$00, $01, $07, $04

ShadowDancerStage_Loop03:
	smpsCall	ShadowDancerStage_Call01
	smpsLoop	$00, $02, ShadowDancerStage_Loop03

ShadowDancerStage_Loop04:
	smpsCall	ShadowDancerStage_Call02
	smpsLoop	$00, $02, ShadowDancerStage_Loop04
	smpsLoop	$01, $02, ShadowDancerStage_Loop03
	smpsCall	ShadowDancerStage_Call03
	smpsModOff
	smpsJump	ShadowDancerStage_Loop02

ShadowDancerStage_Call00:
	dc.b	nEb5, $03, nE5, nA5, nD6, nCs6, nA3, nE5, nA3, nA3, nC6, nB5
	dc.b	nA3, nE5, nEb5, nB5, nA5, nE5, nA3, nG5, nA5, nA3, nA3, nA5
	dc.b	nEb5, nE5, nFs5, nE5, nA3, nG5, nEb5, nFs5, nG5
	smpsReturn

ShadowDancerStage_Call01:
	dc.b	nRst, $06, nBb4, nEb5, nBb4, nC5, nEb5, nBb4, nC5, $0C, nBb4
	dc.b	$06, nEb5, nBb4, nC5, nEb5, nBb4, nC5
	smpsReturn

ShadowDancerStage_Call02:
	dc.b	nRst, $06, nB4, nE5, nB4, nCs5, nE5, nB4, nCs5, $0C, nB4
	dc.b	$06, nE5, nB4, nCs5, nE5, nB4, nCs5
	smpsReturn

ShadowDancerStage_Call03:
	dc.b	nB4, $06, nF5, nBb4, nG5, nC5, nA5, nCs5, nC6
	smpsReturn

; PSG1 Data
ShadowDancerStage_PSG1:
	dc.b	nRst, $0C

ShadowDancerStage_Loop10:
	smpsCall	ShadowDancerStage_Call04
	smpsLoop	$00, $04, ShadowDancerStage_Loop10
	smpsAlterPitch	$0C

ShadowDancerStage_Loop11:
	smpsCall	ShadowDancerStage_Call05
	smpsLoop	$00, $04, ShadowDancerStage_Loop11

ShadowDancerStage_Loop12:
	smpsCall	ShadowDancerStage_Call06
	smpsLoop	$00, $04, ShadowDancerStage_Loop12
	smpsLoop	$01, $02, ShadowDancerStage_Loop11
	smpsAlterPitch	$F4
	smpsCall	ShadowDancerStage_Call07
	smpsJump	ShadowDancerStage_Loop10

; PSG2 Data
ShadowDancerStage_PSG2:
	dc.b	nRst, $0C

ShadowDancerStage_Loop0D:
	smpsCall	ShadowDancerStage_Call00
	smpsLoop	$00, $04, ShadowDancerStage_Loop0D
	smpsAlterPitch	$0C

ShadowDancerStage_Loop0E:
	smpsCall	ShadowDancerStage_Call01
	smpsLoop	$00, $02, ShadowDancerStage_Loop0E

ShadowDancerStage_Loop0F:
	smpsCall	ShadowDancerStage_Call02
	smpsLoop	$00, $02, ShadowDancerStage_Loop0F
	smpsLoop	$01, $02, ShadowDancerStage_Loop0E
	smpsAlterPitch	$F4
	smpsCall	ShadowDancerStage_Call03
	smpsJump	ShadowDancerStage_Loop0D

; DAC Data
ShadowDancerStage_DAC:
	dc.b	dShadowDancerKick, $03, dShadowDancerSnare, dShadowDancerKick, dShadowDancerKick

ShadowDancerStage_Loop00:
	dc.b	dShadowDancerKick, $03, dShadowDancerKick, dShadowDancerKick, $06, dShadowDancerSnare, $03
	dc.b	dShadowDancerKick, $06, dShadowDancerKick, dShadowDancerKick, dShadowDancerSnare
	dc.b	dShadowDancerKick, $03, dShadowDancerKick, $06, dShadowDancerKick, $03, dShadowDancerSnare
	dc.b	dShadowDancerKick, dShadowDancerKick, $06, dShadowDancerKick, $03
	dc.b	dShadowDancerSnare, dShadowDancerKick, $06, dShadowDancerKick, dShadowDancerKick, $03
	dc.b	dShadowDancerKick, dShadowDancerSnare, dShadowDancerKick, dShadowDancerKick
	smpsLoop	$00, $04, ShadowDancerStage_Loop00

ShadowDancerStage_Loop01:
	dc.b	dShadowDancerKick, $03, dShadowDancerKick, $06, dShadowDancerKick, $03, dShadowDancerSnare, $09
	dc.b	dShadowDancerKick, $03, dShadowDancerKick, $06
	dc.b	dShadowDancerKick, $03, dShadowDancerKick, dShadowDancerSnare, dShadowDancerKick, $06
	dc.b	dShadowDancerKick, $03, dShadowDancerKick, dShadowDancerKick, $06, dShadowDancerKick
	dc.b	$03, dShadowDancerSnare, $06, dShadowDancerKick, $03, dShadowDancerKick, $09, dShadowDancerKick, $03
	dc.b	dShadowDancerKick, dShadowDancerSnare, dShadowDancerKick
	dc.b	$06, dShadowDancerKick, $03
	smpsLoop	$00, $08, ShadowDancerStage_Loop01
	dc.b	dShadowDancerSnare, $03, dShadowDancerKick, $06, dShadowDancerSnare, $03, dShadowDancerKick, $06
	dc.b	dShadowDancerSnare, $03, dShadowDancerKick, $06
	dc.b	dShadowDancerKick, $03, dShadowDancerKick, dShadowDancerKick, dShadowDancerSnare, dShadowDancerSnare
	dc.b	dShadowDancerKick, dShadowDancerKick
	smpsJump	ShadowDancerStage_Loop00

ShadowDancerStage_Voices:
;	Voice $00
	smpsVcAlgorithm	$03
	smpsVcFeedback	$03
	smpsVcUnusedBits	$00
	smpsVcDetune	$05, $01, $00, $00
	smpsVcCoarseFreq	$00, $00, $00, $00
	smpsVcRateScale	$02, $01, $01, $03
	smpsVcAttackRate	$15, $15, $05, $14
	smpsVcAmpMod	$00, $00, $00, $00
	smpsVcDecayRate1	$05, $02, $07, $0A
	smpsVcDecayRate2	$08, $03, $06, $06
	smpsVcDecayLevel	$06, $08, $07, $01
	smpsVcReleaseRate	$02, $02, $02, $02
	smpsVcTotalLevel	$80, $17, $04, $15

;	Voice $01
	smpsVcAlgorithm	$03
	smpsVcFeedback	$07
	smpsVcUnusedBits	$03
	smpsVcDetune	$06, $00, $00, $00
	smpsVcCoarseFreq	$00, $00, $00, $00
	smpsVcRateScale	$00, $00, $00, $01
	smpsVcAttackRate	$1F, $1F, $1F, $1F
	smpsVcAmpMod	$00, $00, $00, $00
	smpsVcDecayRate1	$0D, $0D, $09, $09
	smpsVcDecayRate2	$00, $00, $00, $00
	smpsVcDecayLevel	$0F, $00, $00, $0F
	smpsVcReleaseRate	$07, $07, $07, $07
	smpsVcTotalLevel	$83, $20, $09, $14

;	Voice $02
	smpsVcAlgorithm	$02
	smpsVcFeedback	$02
	smpsVcUnusedBits	$00
	smpsVcDetune	$00, $00, $00, $00
	smpsVcCoarseFreq	$01, $00, $0D, $00
	smpsVcRateScale	$00, $00, $00, $00
	smpsVcAttackRate	$1F, $1F, $1F, $1F
	smpsVcAmpMod	$00, $00, $00, $00
	smpsVcDecayRate1	$0B, $0E, $0C, $1F
	smpsVcDecayRate2	$09, $0A, $0C, $00
	smpsVcDecayLevel	$01, $03, $08, $00
	smpsVcReleaseRate	$0C, $08, $0B, $0A
	smpsVcTotalLevel	$82, $15, $2B, $10

;	Voice $03
	smpsVcAlgorithm	$00
	smpsVcFeedback	$07
	smpsVcUnusedBits	$03
	smpsVcDetune	$00, $06, $03, $06
	smpsVcCoarseFreq	$01, $00, $00, $01
	smpsVcRateScale	$01, $00, $00, $00
	smpsVcAttackRate	$1D, $1F, $1F, $1F
	smpsVcAmpMod	$00, $00, $00, $00
	smpsVcDecayRate1	$10, $09, $0C, $0E
	smpsVcDecayRate2	$04, $00, $00, $00
	smpsVcDecayLevel	$00, $04, $05, $05
	smpsVcReleaseRate	$06, $00, $05, $04
	smpsVcTotalLevel	$92, $13, $18, $28

;	Voice $04
	smpsVcAlgorithm	$04
	smpsVcFeedback	$07
	smpsVcUnusedBits	$03
	smpsVcDetune	$06, $03, $03, $06
	smpsVcCoarseFreq	$00, $00, $01, $01
	smpsVcRateScale	$00, $00, $00, $00
	smpsVcAttackRate	$10, $10, $10, $10
	smpsVcAmpMod	$00, $00, $00, $00
	smpsVcDecayRate1	$01, $01, $01, $01
	smpsVcDecayRate2	$06, $00, $06, $00
	smpsVcDecayLevel	$02, $04, $02, $02
	smpsVcReleaseRate	$07, $07, $07, $07
	smpsVcTotalLevel	$81, $95, $81, $1E

;	Voice $05
	smpsVcAlgorithm	$02
	smpsVcFeedback	$02
	smpsVcUnusedBits	$00
	smpsVcDetune	$00, $00, $00, $00
	smpsVcCoarseFreq	$01, $00, $07, $00
	smpsVcRateScale	$00, $00, $00, $00
	smpsVcAttackRate	$1F, $1F, $1F, $1F
	smpsVcAmpMod	$00, $00, $00, $00
	smpsVcDecayRate1	$0B, $0E, $0C, $1F
	smpsVcDecayRate2	$09, $0A, $0C, $00
	smpsVcDecayLevel	$01, $03, $08, $00
	smpsVcReleaseRate	$0C, $08, $0B, $0A
	smpsVcTotalLevel	$80, $14, $2A, $10

;	Voice $06
	smpsVcAlgorithm	$03
	smpsVcFeedback	$03
	smpsVcUnusedBits	$00
	smpsVcDetune	$05, $01, $00, $00
	smpsVcCoarseFreq	$00, $00, $00, $00
	smpsVcRateScale	$02, $01, $01, $03
	smpsVcAttackRate	$17, $17, $07, $17
	smpsVcAmpMod	$00, $00, $00, $00
	smpsVcDecayRate1	$05, $02, $07, $0A
	smpsVcDecayRate2	$08, $03, $06, $06
	smpsVcDecayLevel	$06, $08, $07, $01
	smpsVcReleaseRate	$02, $02, $02, $02
	smpsVcTotalLevel	$80, $17, $04, $15
