EUZ_Header:
	smpsHeaderStartSong 1, 1
	smpsHeaderVoice     EUZ_Voices
	smpsHeaderChan      $07, $03
	smpsHeaderTempo     $02, $03

	smpsHeaderDAC       EUZ_DAC
	smpsHeaderFM        EUZ_FM1,	$0C, $0C
	smpsHeaderFM        EUZ_FM2,	$00, $10
	smpsHeaderFM        EUZ_FM3,	$00, $10
	smpsHeaderFM        EUZ_FM4,	$00, $10
	smpsHeaderFM        EUZ_FM5,	$00, $10
	smpsHeaderFM        EUZ_FM6,	$00, $10
	smpsHeaderPSG       EUZ_PSG1,	$DC, $00, $00, $00
	smpsHeaderPSG       EUZ_PSG2,	$DC, $00, $00, $00
	smpsHeaderPSG       EUZ_PSG3,	$23, $00, $00, $00

; FM1 Data
EUZ_FM1:
	smpsSetvoice        $00

EUZ_Loop08:
	dc.b	nG1, $02, $02, nBb1, nG1, nBb1, $04, nG1, $02, $02, nC2, $04
	dc.b	nG1, $02, $02, nCs2, $02, $02, nD2, nG2
	smpsLoop            $00, $14, EUZ_Loop08

EUZ_Loop09:
	dc.b	nBb1, nBb1, nBb1, nBb1, nD2, $04, nBb1, $02, $02, nF2, $04, nBb1
	dc.b	$02, $02, nD2, $02, $02, nF2, $02, $02
	smpsLoop            $00, $02, EUZ_Loop09

EUZ_Loop0A:
	dc.b	nC2, $02, $02, $02, $02, nE2, $04, nC2, $02, $02, nG2, $04
	dc.b	nC2, $02, $02, nE2, $02, $02, nG2, $02, $02
	smpsLoop            $00, $02, EUZ_Loop0A
	smpsLoop            $01, $02, EUZ_Loop09

EUZ_Loop0B:
	dc.b	nG1, $02, $02, nBb1, nG1, nBb1, $04, nG1, $02, $02, nC2, $04
	dc.b	nG1, $02, $02, nCs2, $02, $02, nD2, nG2
	smpsLoop            $00, $08, EUZ_Loop0B
	dc.b	nG1

EUZ_Loop0C:
	dc.b	nG1, nA1, nA1, nBb1, nC2, nG1, $04, $02
	smpsLoop            $00, $1F, EUZ_Loop0C
	dc.b	$02, nA1, $02, $02, nBb1, nC2, nG1, $04
	smpsJump            EUZ_FM1

; FM2 Data
EUZ_FM2:
	dc.b	nRst, $7F, $01
	smpsSetvoice        $02
	dc.b	nG3, $02, nD4, nG4, nD5, nG5, nG5, nD5, nG4, nG3, nD4, nG4
	dc.b	nD5, nG5, nD5, nG4, nD4

EUZ_Loop03:
	dc.b	nG3, nD4, nG4, nD5
	smpsLoop            $00, $04, EUZ_Loop03
	dc.b	nRst, $40, nG3, $02, nD4, nG4, nD5, nG5, nG5, nD5, nG4, nG3
	dc.b	nD4, nG4, nD5, nG5, nD5, nG4, nD4

EUZ_Loop04:
	dc.b	nG3, nD4, nG4, nD5
	smpsLoop            $00, $04, EUZ_Loop04
	dc.b	nRst, $7F, $41, nG3, $02, nD4, nG4, nD5, nG5, nG5, nD5, nG4
	dc.b	nG3, nD4, nG4, nD5, nG5, nD5, nG4, nD4

EUZ_Loop05:
	dc.b	nG3, nD4, nG4, nD5
	smpsLoop            $00, $04, EUZ_Loop05
	dc.b	nRst, $40
	smpsSetvoice        $04

EUZ_Loop06:
	dc.b	nBb4, $20, nA4, $10, nBb4, nC5, $20, nD5, $10, nE5
	smpsLoop            $00, $02, EUZ_Loop06
	dc.b	nRst, $7F, $7F, $02
	smpsSetvoice        $05

EUZ_Loop07:
	dc.b	nD4, $20, nCs4, nC4, $40, nB3, $06, nC4, nD4, $34, nRst, $40
	smpsLoop            $00, $02, EUZ_Loop07
	smpsJump            EUZ_FM2

; FM3 Data
EUZ_FM3:
	smpsPan             panLeft, $00
	smpsSetvoice        $03
	dc.b	nG3, $02, nD4, nG4, nG5, nG5, nG4, nD4, nG3
	smpsPan             panRight, $00
	dc.b	nG3, nD4, nG4, nG5, nG5, nG4, nD4, nG3, nG3, nRst, $1E
	smpsPan             panLeft, $00
	dc.b	nG3, $02, nD4, nG4, nG5, nG5, nG4, nD4, nG3
	smpsPan             panRight, $00
	dc.b	nG3, nD4, nG4, nG5, nG5, nG4, nD4, nG3, nG3, nRst, $1E
	smpsPan             panCenter, $00
	smpsSetvoice        $01

EUZ_Loop01:
	dc.b	nBb3, $40, nC4
	smpsLoop            $00, $04, EUZ_Loop01
	dc.b	nRst, $7F, $7F, $02, nBb3, $40, nC4, nBb3, nC4
	smpsPan             panLeft, $00
	smpsSetvoice        $03
	dc.b	nG3, $02, nD4, nG4, nG5, nG5, nG4, nD4, nG3
	smpsPan             panRight, $00
	dc.b	nG3, nD4, nG4, nG5, nG5, nG4, nD4, nG3, nG3, nRst, $1E
	smpsPan             panLeft, $00
	dc.b	nG3, $02, nD4, nG4, nG5, nG5, nG4, nD4, nG3
	smpsPan             panRight, $00
	dc.b	nG3, nD4, nG4, nG5, nG5, nG4, nD4, nG3, nG3, nRst, $7F, $1F

EUZ_Loop02:
	smpsPan             panLeft, $00
	dc.b	nG3, $02, nD4, nG4, nG5, nG5, nG4, nD4, nG3
	smpsPan             panRight, $00
	dc.b	nG3, nD4, nG4, nG5, nG5, nG4, nD4, nG3, nG3, nRst, $5E
	smpsLoop            $00, $02, EUZ_Loop02
	smpsJump            EUZ_FM3

; FM4 Data
EUZ_FM4:
	dc.b	nRst, $7F, $01
	smpsPan             panLeft, $00
	smpsSetvoice        $01
	dc.b	nG4, $40, $40, $40, nE5, nG4, nG4, nG4, nE5, nRst, $7F, $7F
	dc.b	$12
	smpsPan             panCenter, $00
	dc.b	nG5, $10, nA5, nBb5, $20, nC6, $10, nD6, nE6, nRst, nG5, nA5
	dc.b	nBb5, $20, nC6, $10, nD6, nE6, nRst, $50, nG4, $10, nD5, nG5
	dc.b	nD6, $28, nA5, $0C, nB5, nC6, $08, nF6, $04, nC6, $14, nB5
	dc.b	$02, nC6, nA5, $0C, nG5, $02, nA5, nF5, $0C, nRst, $50, nBb4
	dc.b	$10, nD5, nG5, $30, nD6, $10, nBb5, nAb5, $01, nA5, $0F, nF5
	dc.b	$10, nD5, $20
	smpsJump            EUZ_FM4

; FM5 Data
EUZ_FM5:
	dc.b	nRst, $7F, $01
	smpsPan             panRight, $00
	smpsSetvoice        $01
	dc.b	nD5, $40, nE5, nD5, nG4, nD5, nE5, nD5, nG4, nRst, $7F, $7F
	dc.b	$02
	smpsPan             panCenter, $00
	dc.b	nD4, $40, nE4, nD4, nE4, nD6, $20, nRst, $30, nG3, $10, nD4
	dc.b	nG4, nD5, $28, nA4, $0C, nB4, nC5, $08, nF5, $04, nC5, nC5
	dc.b	$10, nB4, $02, nC5, nA4, $0C, nG4, $02, nA4, nF4, $0C, nRst
	dc.b	$40, nBb3, $10, nD4, $20, nG4, $10, nRst, $20, nD5, $10, nBb4
	dc.b	nAb4, $01, nA4, $0F, nF4, $10, nD4, $20
	smpsJump            EUZ_FM5

; FM6 Data
EUZ_FM6:
	dc.b	nRst, $7F, $7F, $7F, $03
	smpsSetvoice        $05
	dc.b	nD4, $30, nG3, $06, nBb3, $05, nF4, nE4, $38, nC4, $08, nD4
	dc.b	$30, $06, nG4, $05, nF4, nE4, $40, nD5, $24, $06, nBb4, nF4
	dc.b	$10, nE4, $14, nF4, $06, nG4, nC5, $20, nCs5, $01, nD5, $23
	dc.b	$06, nBb4, nF4, $10, nE4, $14, nF4, $06, nG4, nC5, $20, nD4
	dc.b	$30, nG3, $06, nBb3, $05, nF4, nE4, $38, nC4, $08, nD4, $30
	dc.b	$06, nG4, $05, nF4, nE4, $40

EUZ_Loop00:
	dc.b	nG4, $20, nFs4, nF4, $40, nE4, $06, nF4, nG4, $34, nRst, $40
	smpsLoop            $00, $02, EUZ_Loop00
	smpsJump            EUZ_FM6

; PSG1 Data
EUZ_PSG1:
	dc.b	nRst, $7F, $01
	smpsPSGvoice        fTone_04

EUZ_Loop17:
	dc.b	nD5, $02, $02, $02, nRst
	smpsLoop            $00, $03, EUZ_Loop17
	dc.b	nD5, nD5, nD5, nRst, $22

EUZ_Loop18:
	dc.b	nC5, $02, $02, $02, nRst
	smpsLoop            $00, $03, EUZ_Loop18
	dc.b	nC5, nC5, nC5, nRst, $22
	smpsLoop            $01, $03, EUZ_Loop17

EUZ_Loop19:
	dc.b	nD5, $02, $02, $02, nRst
	smpsLoop            $00, $03, EUZ_Loop19
	dc.b	nD5, nD5, nD5, nRst, $22

EUZ_Loop1A:
	dc.b	nC5, $02, $02, $02, nRst
	smpsLoop            $00, $03, EUZ_Loop1A
	dc.b	nC5, nC5, nC5, nRst, $2A
	smpsPSGvoice        $00

EUZ_Loop1D:
	dc.b	nF4, $02, nD4, nF4, nD4, nBb4, nF4, nBb4, nF4, nD5, nBb4, nD5
	dc.b	nBb4, nF5, nD5, nF5, nD5, nBb5, nF5, nBb5, nF5, nD6, nBb5, nD6
	dc.b	nBb5

EUZ_Loop1B:
	dc.b	nF6, nD6
	smpsLoop            $00, $04, EUZ_Loop1B
	dc.b	nG4, nE4, nG4, nE4, nC5, nG4, nC5, nG4, nE5, nC5, nE5, nC5
	dc.b	nG5, nE5, nG5, nE5, nC6, nG5, nC6, nG5, nE6, nC6, nE6, nC6

EUZ_Loop1C:
	dc.b	nG6, nE6
	smpsLoop            $00, $04, EUZ_Loop1C
	smpsLoop            $01, $02, EUZ_Loop1D
	dc.b	nRst, $7F, $7F, $7F, $7F, $7F, $7D
	smpsJump            EUZ_PSG1

; PSG2 Data
EUZ_PSG2:
	smpsPSGvoice        $00

EUZ_Loop0F:
	dc.b	$A0

EUZ_Loop0E:
	dc.b	$02, nD3, nG3, nG4, nG4, nG3, nD3, $A0
	smpsLoop            $00, $02, EUZ_Loop0E
	dc.b	nRst, $20
	smpsLoop            $01, $02, EUZ_Loop0F
	smpsPSGvoice        fTone_04

EUZ_Loop10:
	dc.b	nG4, $02, $02, $02, nRst
	smpsLoop            $00, $03, EUZ_Loop10
	dc.b	nG4, nG4, nG4, nRst, $22

EUZ_Loop11:
	dc.b	nE5, $02, $02, $02, nRst
	smpsLoop            $00, $03, EUZ_Loop11
	dc.b	nE5, nE5, nE5, nRst, $22
	smpsLoop            $01, $03, EUZ_Loop10

EUZ_Loop12:
	dc.b	nG4, $02, $02, $02, nRst
	smpsLoop            $00, $03, EUZ_Loop12
	dc.b	nG4, nG4, nG4, nRst, $22

EUZ_Loop13:
	dc.b	nE5, $02, $02, $02, nRst
	smpsLoop            $00, $03, EUZ_Loop13
	dc.b	nE5, nE5, nE5, nRst, $2A
	smpsPSGvoice        $00

EUZ_Loop16:
	dc.b	nBb3, $02, nF3, nBb3, nF3, nD4, nBb3, nD4, nBb3, nF4, nD4, nF4
	dc.b	nD4, nBb4, nF4, nBb4, nF4, nD5, nBb4, nD5, nBb4, nF5, nD5, nF5
	dc.b	nD5

EUZ_Loop14:
	dc.b	nBb5, nF5
	smpsLoop            $00, $04, EUZ_Loop14
	dc.b	nC4, nG3, nC4, nG3, nE4, nC4, nE4, nC4, nG4, nE4, nG4, nE4
	dc.b	nC5, nG4, nC5, nG4, nE5, nC5, nE5, nC5, nG5, nE5, nG5, nE5

EUZ_Loop15:
	dc.b	nC6, nG5
	smpsLoop            $00, $04, EUZ_Loop15
	smpsLoop            $01, $02, EUZ_Loop16
	dc.b	nRst, $7F, $7F, $7F, $7F, $7F, $7D
	smpsJump            EUZ_PSG2

; PSG3 Data
EUZ_PSG3:
	smpsPSGform         $E7

EUZ_Jump00:
	smpsPSGvoice        fTone_02

EUZ_Loop0D:
	dc.b	$D1, $01, nRst
	smpsLoop            $00, $08, EUZ_Loop0D
	smpsJump            EUZ_Jump00

; DAC Data
EUZ_DAC:
	smpsStop

EUZ_Voices:
;	Voice $00
;	$3B
;	$4E, $41, $40, $40, 	$9F, $1F, $1F, $1F, 	$0F, $0E, $09, $09
;	$00, $00, $00, $00, 	$EF, $EF, $EF, $EF, 	$27, $18, $18, $7F
	smpsVcAlgorithm     $03
	smpsVcFeedback      $07
	smpsVcUnusedBits    $00
	smpsVcDetune        $04, $04, $04, $04
	smpsVcCoarseFreq    $00, $00, $01, $0E
	smpsVcRateScale     $00, $00, $00, $02
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $09, $09, $0E, $0F
	smpsVcDecayRate2    $00, $00, $00, $00
	smpsVcDecayLevel    $0E, $0E, $0E, $0E
	smpsVcReleaseRate   $0F, $0F, $0F, $0F
	smpsVcTotalLevel    $7F, $18, $18, $27

;	Voice $01
;	$3B
;	$51, $71, $61, $41, 	$51, $16, $18, $1A, 	$05, $01, $01, $00
;	$09, $01, $01, $01, 	$17, $97, $27, $87, 	$1C, $22, $15, $7F
	smpsVcAlgorithm     $03
	smpsVcFeedback      $07
	smpsVcUnusedBits    $00
	smpsVcDetune        $04, $06, $07, $05
	smpsVcCoarseFreq    $01, $01, $01, $01
	smpsVcRateScale     $00, $00, $00, $01
	smpsVcAttackRate    $1A, $18, $16, $11
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $00, $01, $01, $05
	smpsVcDecayRate2    $01, $01, $01, $09
	smpsVcDecayLevel    $08, $02, $09, $01
	smpsVcReleaseRate   $07, $07, $07, $07
	smpsVcTotalLevel    $7F, $15, $22, $1C

;	Voice $02
;	$36
;	$0F, $01, $01, $01, 	$1F, $1F, $1F, $1F, 	$12, $11, $0E, $00
;	$00, $0A, $07, $09, 	$FF, $0F, $1F, $0F, 	$18, $80, $80, $80
	smpsVcAlgorithm     $06
	smpsVcFeedback      $06
	smpsVcUnusedBits    $00
	smpsVcDetune        $00, $00, $00, $00
	smpsVcCoarseFreq    $01, $01, $01, $0F
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $00, $0E, $11, $12
	smpsVcDecayRate2    $09, $07, $0A, $00
	smpsVcDecayLevel    $00, $01, $00, $0F
	smpsVcReleaseRate   $0F, $0F, $0F, $0F
	smpsVcTotalLevel    $80, $80, $80, $18

;	Voice $03
;	$3B
;	$3E, $42, $41, $33, 	$DE, $14, $1E, $14, 	$14, $0F, $0F, $00
;	$01, $00, $00, $00, 	$36, $25, $26, $29, 	$14, $13, $0A, $7D
	smpsVcAlgorithm     $03
	smpsVcFeedback      $07
	smpsVcUnusedBits    $00
	smpsVcDetune        $03, $04, $04, $03
	smpsVcCoarseFreq    $03, $01, $02, $0E
	smpsVcRateScale     $00, $00, $00, $03
	smpsVcAttackRate    $14, $1E, $14, $1E
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $00, $0F, $0F, $14
	smpsVcDecayRate2    $00, $00, $00, $01
	smpsVcDecayLevel    $02, $02, $02, $03
	smpsVcReleaseRate   $09, $06, $05, $06
	smpsVcTotalLevel    $7D, $0A, $13, $14

;	Voice $04
;	$35
;	$61, $61, $41, $71, 	$10, $11, $50, $D1, 	$06, $01, $01, $01
;	$08, $00, $09, $00, 	$89, $F8, $F9, $F8, 	$18, $7F, $7F, $7F
	smpsVcAlgorithm     $05
	smpsVcFeedback      $06
	smpsVcUnusedBits    $00
	smpsVcDetune        $07, $04, $06, $06
	smpsVcCoarseFreq    $01, $01, $01, $01
	smpsVcRateScale     $03, $01, $00, $00
	smpsVcAttackRate    $11, $10, $11, $10
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $01, $01, $01, $06
	smpsVcDecayRate2    $00, $09, $00, $08
	smpsVcDecayLevel    $0F, $0F, $0F, $08
	smpsVcReleaseRate   $08, $09, $08, $09
	smpsVcTotalLevel    $7F, $7F, $7F, $18

;	Voice $05
;	$3D
;	$01, $02, $02, $02, 	$10, $50, $50, $50, 	$07, $08, $08, $08
;	$01, $00, $00, $00, 	$20, $17, $17, $17, 	$1C, $80, $80, $80
	smpsVcAlgorithm     $05
	smpsVcFeedback      $07
	smpsVcUnusedBits    $00
	smpsVcDetune        $00, $00, $00, $00
	smpsVcCoarseFreq    $02, $02, $02, $01
	smpsVcRateScale     $01, $01, $01, $00
	smpsVcAttackRate    $10, $10, $10, $10
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $08, $08, $08, $07
	smpsVcDecayRate2    $00, $00, $00, $01
	smpsVcDecayLevel    $01, $01, $01, $02
	smpsVcReleaseRate   $07, $07, $07, $00
	smpsVcTotalLevel    $80, $80, $80, $1C

