s3p13_Header:
	smpsHeaderStartSong 3
	smpsHeaderVoice     s3p13_Voices
	smpsHeaderChan      $06, $03
	smpsHeaderTempo     $01, $10

	smpsHeaderDAC       s3p13_DAC
	smpsHeaderFM        s3p13_FM1,	$18, $12
	smpsHeaderFM        s3p13_FM2,	$00, $16
	smpsHeaderFM        s3p13_FM3,	$00, $17
	smpsHeaderFM        s3p13_FM4,	$00, $19
	smpsHeaderFM        s3p13_FM5,	$00, $19
	smpsHeaderPSG       s3p13_PSG1,	$00, $05, $00, sTone_0C
	smpsHeaderPSG       s3p13_PSG2,	$00, $05, $00, sTone_0C
	smpsHeaderPSG       s3p13_PSG3,	$00, $03, $00, sTone_0C

; DAC Data
s3p13_DAC:
	dc.b	dSnareS3, $18, dSnareS3, $30, dSnareS3, $08, dSnareS3, dSnareS3, dSnareS3, $10, dSnareS3, $08
	dc.b	dSnareS3, $30, dSnareS3, $08, dSnareS3, dSnareS3, dSnareS3, $10, dSnareS3, $08, dSnareS3, $30
	dc.b	dSnareS3, $08, dSnareS3, dSnareS3, dSnareS3, $10, dSnareS3, $08, dSnareS3, $48

s3p13_Jump00:
	dc.b	dKickS3, $18
	smpsCall	s3p13_Phrase0A
	dc.b	dKickS3, dSnareS3, dKickS3
	smpsCall	s3p13_Phrase0A
	smpsCall	s3p13_Phrase09
	smpsCall	s3p13_Phrase09
	dc.b	dKickS3, $0C, dSnareS3, dSnareS3, dSnareS3, dKickS3, $18, dSnareS3
	smpsCall	s3p13_Phrase09
	smpsCall	s3p13_Phrase09
	dc.b	dKickS3, dSnareS3, dKickS3, dSnareS3, dKickS3, dSnareS3, dKickS3, dSnareS3, dKickS3, dSnareS3, dKickS3, dSnareS3
	dc.b	dKickS3, dSnareS3, $0C, dSnareS3
	smpsJump            s3p13_Jump00

; FM1 Data
s3p13_FM1:
	smpsSetvoice        $02
	smpsDetune          $FC
	smpsModSet          $0F, $01, $06, $06
	smpsCall            s3p13_Call04

s3p13_Jump05:
	smpsSetvoice        $00
	smpsCall            s3p13_Call05
	smpsJump            s3p13_Jump05

s3p13_Call04:
	dc.b	nBb0, $05, nRst, $13
	smpsCall	s3p13_Phrase0B
	dc.b	nBb0, $05, nRst, $0B, nBb0, $05, nRst, $03
	smpsCall	s3p13_Phrase0B
	dc.b	nBb0, $05, nRst, $0B, nBb0, $05, nRst, $03
	smpsCall	s3p13_Phrase0B
	dc.b	nF1, $05, nRst, $0B, nF1, $05, nRst, $03, nF1, $45, nRst, $03
	smpsReturn

s3p13_Call05:
	smpsCall	s3p13_Phrase00
	smpsCall	s3p13_Phrase00
	smpsCall	s3p13_Phrase00
s3p13_Run03_Repeat00:
	smpsCall	s3p13_Phrase03
	smpsLoop	$00, $04, s3p13_Run03_Repeat00
	smpsCall	s3p13_Phrase00
	smpsCall	s3p13_Phrase00
	smpsCall	s3p13_Phrase00
s3p13_Run03_Repeat01:
	smpsCall	s3p13_Phrase03
	smpsLoop	$00, $04, s3p13_Run03_Repeat01
	smpsCall	s3p13_Phrase08
	smpsCall	s3p13_Phrase08
	smpsCall	s3p13_Phrase01
	smpsCall	s3p13_Phrase05
	smpsCall	s3p13_Phrase05
	smpsCall	s3p13_Phrase04
	smpsCall	s3p13_Phrase04
	smpsCall	s3p13_Phrase08
	smpsCall	s3p13_Phrase08
	smpsCall	s3p13_Phrase05
	smpsCall	s3p13_Phrase05
s3p13_Run03_Repeat02:
	smpsCall	s3p13_Phrase04
	smpsLoop	$00, $04, s3p13_Run03_Repeat02
	smpsCall	s3p13_Phrase01
	dc.b	nCs1, $03, nRst, $09, nCs1, $03, nRst, $09, nCs1, $03, nRst, $09
	dc.b	nCs1, $03, nRst, $09, nCs1, $03, nRst, $09, nCs1, $03, nRst, $09
	dc.b	nCs1, $03, nRst, $09, nCs1, $03, nRst, $09
	smpsCall	s3p13_Phrase01
	smpsCall	s3p13_Phrase05
	smpsCall	s3p13_Phrase05
	dc.b	nAb1, $03, nRst, $09, nAb1, $03, nRst, $09, nAb1, $03, nRst, $09
	dc.b	nAb1, $03, nRst, $09, nFs1, $03, nRst, $09, nFs1, $03, nRst, $09
	dc.b	nFs1, $03, nRst, $09, nFs1, $03, nRst, $09
	smpsCall	s3p13_Phrase04
	dc.b	nE1, $03, nRst, $09, nE1, $03, nRst, $09, nE1, $03, nRst, $09
	dc.b	nE1, $03, nRst, $09, nEb1, $08, nRst, $04, nD1, $14, nRst, $04
	dc.b	nF1, $08, nRst, $04, nE1, $14, nRst, $04, nAb1, $08, nRst, $04
	dc.b	nG1, $14, nRst, $04, nBb1, $08, nRst, $04, nA1, $14, nRst, $04
	dc.b	nB1, $14, nRst, $04, nBb1, $14, nRst, $04
s3p13_Run03_Repeat03:
	smpsCall	s3p13_Phrase01
	smpsLoop	$00, $04, s3p13_Run03_Repeat03
	smpsReturn

; FM2 Data
s3p13_FM2:
	smpsSetvoice        $02
	smpsDetune          $04
	smpsModSet          $0F, $01, $06, $06
	smpsCall            s3p13_Call02
	smpsSetvoice        $02
	smpsDetune          $04
	smpsModSet          $0F, $01, $06, $06

s3p13_Jump04:
	smpsSetvoice        $02
	smpsDetune          $04
	smpsModSet          $0F, $01, $06, $06
	smpsCall            s3p13_Call03
	smpsJump            s3p13_Jump04

s3p13_Call02:
	dc.b	nD4, $04, nRst, $14, nD4, $2F, nRst, $01, nEb4, $08, nD4, $07
	dc.b	nRst, $01, nC4, $08, nBb3, $03, nRst, $0D, nD4, $03, nRst, $05
	dc.b	nD4, $30, nEb4, $07, nRst, $01, nD4, $08, nC4, $05, nRst, $03
	dc.b	nBb3, $05, nRst, $0B, nD4, $03, nRst, $05, nD4, $30, nC4, $06
	dc.b	nRst, $02, nD4, $06, nRst, $02, nEb4, $07, nRst, $01, nD4, $02
	dc.b	nRst, $0E, nA3, $03, nRst, $05, nA3, $3A, nRst, $0E
	smpsReturn

s3p13_Call03:
	smpsCall	s3p13_Phrase02
	dc.b	nBb3, $20, nRst, $04, nEb3, $60, $38, nRst, $04
	smpsCall	s3p13_Phrase02
	dc.b	nBb3, $60, $5C, nRst, $04
	smpsCall	s3p13_Phrase02
	dc.b	nBb3, $20, nRst, $04, nEb3, $60, $38, nRst, $04
	smpsCall	s3p13_Phrase02
	dc.b	nBb3, $60, $5C, nRst, $04, nBb3, $2C, nRst, $04, nG3, $08
	dc.b	nRst, $04, nBb3, $08, nRst, $04, nD4, $08, nRst, $04, nBb3, $08
	dc.b	nRst, $04, nEb4, $08, nRst, $04, nD4, $08, nRst, $04, nC4, $08
	dc.b	nRst, $04, nBb3, $20, nRst, $04, nBb3, $08, nRst, $04, nC4, $08
	dc.b	nRst, $04, nD4, $08, nRst, $04, nBb3, $08, nRst, $04, nG3, $08
	dc.b	nRst, $04, nBb3, $14, nRst, $04, nG3, $08, nRst, $04, nBb3, $08
	dc.b	nRst, $04, nC4, $60, $08, nRst, $04, nBb3, $2C, nRst, $04
	dc.b	nBb3, $08, nRst, $04, nC4, $08, nRst, $04, nD4, $08, nRst, $04
	dc.b	nBb3, $08, nRst, $04, nG4, $08, nRst, $04, nF4, $08, nRst, $04
	dc.b	nEb4, $08, nRst, $04, nBb3, $08, nRst, $04, nC4, $08, nRst, $04
	dc.b	nD4, $08, nRst, $04, nEb4, $08, nRst, $04, nF4, $08, nRst, $04
	dc.b	nD4, $20, nRst, $04, nC4, $08, nRst, $04, nC4, $60, $2C
	smpsCall	s3p13_Phrase07
	dc.b	nRst, $04, nF4, $14, nRst, $04, nAb4, $08, nRst, $04, nBb4, $08
	dc.b	nRst, $04, nC5, $08, nRst, $04, nAb4, $14, nRst, $04, nAb4, $08
	dc.b	nRst, $04, nBb4, $08, nRst, $04, nC5, $08, nRst, $04, nC5, $08
	dc.b	nRst, $04, nBb4, $08, nRst, $04, nG4, $08, nRst, $04, nEb4, $38
	smpsCall	s3p13_Phrase07
	dc.b	nRst, $1C, nAb4, $08, nRst, $04, nG4, $08, nRst, $10, nBb4, $08
	dc.b	nRst, $04, nA4, $08, nRst, $10, nC5, $08, nRst, $04, nB4, $08
	dc.b	nRst, $10, nCs5, $08, nRst, $04, nC5, $08, nRst, $10, nE5, $14
	dc.b	nRst, $04, nEb5, $14, nRst, $04, nAb4, $60, $38, nRst, $04
	dc.b	nAb4, $03, nRst, nBb4, nRst, nC5, nRst, nBb4, nRst, nAb4, nRst, nG4
	dc.b	nRst, nAb4, $20, nRst, $04, nEb4, $08, nRst, $04, nEb4, $2C
	dc.b	nRst, $04, nF4, $08, nRst, $04, nF4, $08, nRst, $04, nG4, $08
	dc.b	nRst, $04, nAb4, $08, nRst, $10, nBb4, $20, nRst, $04
	smpsReturn

; FM3 Data
s3p13_FM3:
	dc.b	nRst, $0C
	smpsFMAlterVol      $06
	smpsSetvoice        $02
	smpsDetune          $FC
	smpsModSet          $0F, $01, $06, $06
	smpsCall            s3p13_Call02
	smpsFMAlterVol      $02
	smpsSetvoice        $02
	smpsDetune          $FC
	smpsModSet          $0F, $01, $06, $06

s3p13_Jump03:
	smpsCall            s3p13_Call03
	smpsJump            s3p13_Jump03

; FM4 Data
s3p13_FM4:
	smpsSetvoice        $01
	smpsDetune          $03
	smpsModSet          $03, $01, $FD, $05
	smpsPan             panLeft, $00
	smpsCall            s3p13_Call00

s3p13_Jump02:
	smpsCall            s3p13_Call01
	smpsJump            s3p13_Jump02

; FM5 Data
s3p13_FM5:
	smpsSetvoice        $01
	smpsDetune          $FD
	smpsModSet          $03, $01, $03, $05
	smpsPan             panRight, $00
	smpsCall            s3p13_Call00

s3p13_Jump01:
	smpsCall            s3p13_Call01
	smpsJump            s3p13_Jump01

s3p13_Call00:
	dc.b	nF4, $05, nRst, $13, nF4, $2F, nRst, $01, nG4, $08, nF4, $07
	dc.b	nRst, $01, nEb4, $08, nD4, $04, nRst, $0C, nF4, $03, nRst, $05
	dc.b	nF4, $30, nG4, $08, nF4, $07, nRst, $01, nEb4, $08, nD4, $07
	dc.b	nRst, $09, nF4, $04, nRst, nF4, $30, nEb4, $08, nF4, nG4, nF4
	dc.b	$05, nRst, $0B, nC4, $04, nRst, nC4, $46, nRst, $02
	smpsReturn

s3p13_Call01:
	dc.b	nRst, $60, nRst, nRst, $3C, nBb3, $0C, nEb4, nBb3, $0B, nRst, $01
	dc.b	nCs4, $18, nC4, $17, nRst, $01, nAb3, $13, nRst, $05, nAb3, $0A
	dc.b	nRst, $02, nC4, $0C, nBb3, $24, nEb3, $60, $3A, nRst, $32, nBb3
	dc.b	$0C, nC4, $0B, nRst, $01, nD4, $0B, nRst, $01, nEb4, $0B, nRst
	dc.b	$01, nF4, $0C, nBb4, $54, nRst, $60, nRst, nRst, $3C, nBb3, $0B
	dc.b	nRst, $01, nEb4, $0B, nRst, $01, nBb3, $0A, nRst, $02, nCs4, $17
	dc.b	nRst, $01, nC4, $17, nRst, $01, nAb3, $15, nRst, $03, nAb3, $0B
	dc.b	nRst, $01, nC4, $0C, nBb3, $22, nRst, $02, nEb3, $60, $3B, nRst
	dc.b	$31, nBb3, $0B, nRst, $01, nC4, $0C, nD4, $0B, nRst, $01, nEb4
	dc.b	$0C, nF4, $0B, nRst, $01, nBb4, $48, nA4, $0B, nRst, $01, nG4
	dc.b	$5F, nRst, $01, nEb4, $5F, nRst, $01, nD4, $24, nF4, $16, nRst
	dc.b	$02, nF3, $0B, nRst, $01, nBb3, $0B, nRst, $01, nA3, $54, nRst
	dc.b	$18, nG4, $60, nEb4, nD4, $24, nF4, $3A, nRst, $02, nE4, $24
	dc.b	nG4, $39, nRst, $03, nAb4, nRst, $09, nEb4, $02, nRst, $0A, nC4
	dc.b	$03, nRst, $09, nAb4, $04, nRst, $08, nEb4, $03, nRst, $09, nC4
	dc.b	$03, nRst, $09, nAb4, $03, nRst, $09, nEb4, $04, nRst, $08, nF4
	dc.b	$03, nRst, $09, nCs4, $03, nRst, $09, nAb3, $03, nRst, $09, nF4
	dc.b	$04, nRst, $08, nCs4, $03, nRst, $09, nAb3, $04, nRst, $08, nF4
	dc.b	$04, nRst, $08, nCs4, $04, nRst, $08, nAb4, $03, nRst, $09, nEb4
	dc.b	$03, nRst, $09, nC4, $03, nRst, $09, nAb4, $04, nRst, $08, nEb4
	dc.b	$05, nRst, $07, nC4, $05, nRst, $07, nAb4, $04, nRst, $08, nEb4
	dc.b	$03, nRst, $09, nBb4, $04, nRst, $08, nG4, $03, nRst, $09, nEb4
	dc.b	$03, nRst, $09, nBb4, $05, nRst, $07, nG4, $03, nRst, $09, nEb4
	dc.b	$04, nRst, $08, nBb4, $04, nRst, $08, nG4, $02, nRst, $22, nAb4
	dc.b	$18, nRst, nFs4, $17, nRst, $19, nF4, $17, nRst, $19, nE4, $17
	dc.b	nRst, $01, nAb4, $03, nRst, $09, nG4, $04, nRst, $08, nFs4, $04
	dc.b	nRst, $08, nF4, $05, nRst, $07, nE4, $04, nRst, $08, nEb4, $05
	dc.b	nRst, $07, nD4, $04, nRst, $08, nCs4, $05, nRst, $07, nC4, $05
	dc.b	nRst, $07, nB3, $04, nRst, $08, nBb3, $06, nRst, nA3, $05, nRst
	dc.b	$07, nAb3, $14, nRst, $04, nG3, $0E, nRst, $0A, nAb4, $04, nRst
	dc.b	$08, nEb4, $03, nRst, $09, nC4, $04, nRst, $08, nAb4, $05, nRst
	dc.b	$07, nEb4, $04, nRst, $08, nC4, $05, nRst, $07, nAb4, $05, nRst
	dc.b	$07, nEb4, $06, nRst, nF4, $04, nRst, $08, nCs4, $04, nRst, $08
	dc.b	nAb3, $04, nRst, $08, nF4, $05, nRst, $07, nCs4, $04, nRst, $08
	dc.b	nAb3, $05, nRst, $07, nF4, $06, nRst, nCs4, $05, nRst, $07, nAb4
	dc.b	$04, nRst, $08, nEb4, $04, nRst, $08, nC4, $05, nRst, $07, nAb4
	dc.b	$05, nRst, $07, nEb4, $04, nRst, $08, nC4, $06, nRst, nAb4, $04
	dc.b	nRst, $08, nEb4, $05, nRst, $07, nCs4, $16, nRst, $02, nEb4, $0C
	dc.b	nF4, $07, nRst, $11, nG4, $24
	smpsJump            s3p13_Call01

; PSG3 Data
s3p13_PSG3:
	smpsPSGvoice        sTone_02
	smpsPSGform         $E7
	dc.b	nMaxPSG1, $18, nMaxPSG1, $30, nMaxPSG1, $08, nMaxPSG1, nMaxPSG1, nMaxPSG1, $10, nMaxPSG1, $08
	dc.b	nMaxPSG1, $30, nMaxPSG1, $08, nMaxPSG1, nMaxPSG1, nMaxPSG1, $10, nMaxPSG1, $08, nMaxPSG1, $30
	dc.b	nMaxPSG1, $08, nMaxPSG1, nMaxPSG1, nMaxPSG1, $10, nMaxPSG1, $08, nMaxPSG1, $48

s3p13_Jump07:
	dc.b	nMaxPSG1, $0C, nMaxPSG1, $06, nMaxPSG1, nMaxPSG1, $0C, nMaxPSG1, $06, nMaxPSG1, nMaxPSG1, $0C
	dc.b	nMaxPSG1, $06, nMaxPSG1, nMaxPSG1, $0C, nMaxPSG1, $06, nMaxPSG1
	smpsJump            s3p13_Jump07

; PSG1 Data
s3p13_PSG1:
	smpsPSGvoice        sTone_0A
	smpsDetune          $FF
	smpsChangeTransposition $F4
	smpsCall            s3p13_Call06
	smpsChangeTransposition $0C
	smpsJump            s3p13_Jump06

; PSG2 Data
s3p13_PSG2:
	smpsPSGvoice        sTone_0A
	smpsDetune          $00
	smpsChangeTransposition $F4
	smpsCall            s3p13_Call06
	smpsChangeTransposition $0C
	smpsJump            s3p13_Jump06

s3p13_Call06:
	dc.b	nF5, $05, nRst, $13, nF5, $2F, nRst, $01, nG5, $08, nF5, $07
	dc.b	nRst, $01, nEb5, $08, nD5, $04, nRst, $0C, nF5, $03, nRst, $05
	dc.b	nF5, $30, nG5, $08, nF5, $07, nRst, $01, nEb5, $08, nD5, $07
	dc.b	nRst, $09, nF5, $04, nRst, nF5, $30, nEb5, $08, nF5, nG5, nF5
	dc.b	$05, nRst, $0B, nC5, $04, nRst, nC5, $46, nRst, $02
	smpsReturn

s3p13_Jump06:
	dc.b	nRst, $60, nRst, nRst, $54
	smpsCall	s3p13_Phrase06
	dc.b	nRst, $23
	smpsCall	s3p13_Phrase06
	dc.b	nRst, $23
	smpsCall	s3p13_Phrase06
	dc.b	nRst, $47, nAb1, $01, nRst, $05, nAb1, $01, nRst, $05, nAb1, $01
	dc.b	nRst, $05, nAb1, $01, nRst, $05, nAb1, $01, nRst, $0B, nEb1, $02
	dc.b	nRst, $0A, nEb1, $02, nRst, $60, nRst, nRst, nRst, nRst, nRst, nRst
	dc.b	nRst, nRst, nRst, nRst, nRst, nRst, nRst, nRst, nRst, nRst, nRst, nRst
	dc.b	nRst, nRst, $16
	smpsJump            s3p13_Jump06

; Shared note phrases; channel settings stay in the calling tracks.

s3p13_Phrase00:
	dc.b	nEb1, $03, nRst, $09, nEb1, $03, nRst, $09, nEb1, $03, nRst, $09
	dc.b	nEb1, $03, nRst, $09, nEb1, $03, nRst, $09, nEb1, $03, nRst, $09
	dc.b	nEb1, $03, nRst, $09, nEb1, $03, nRst, $09, nCs1, $03, nRst, $09
	dc.b	nCs1, $03, nRst, $09, nCs1, $03, nRst, $09, nCs1, $03, nRst, $09
	dc.b	nCs1, $03, nRst, $09, nCs1, $03, nRst, $09, nCs1, $03, nRst, $09
	dc.b	nCs1, $03, nRst, $09
	smpsReturn

s3p13_Phrase01:
	dc.b	nAb0, $03, nRst, $09, nAb0, $03, nRst, $09, nAb0, $03, nRst, $09
	dc.b	nAb0, $03, nRst, $09, nAb0, $03, nRst, $09, nAb0, $03, nRst, $09
	dc.b	nAb0, $03, nRst, $09, nAb0, $03, nRst, $09
	smpsReturn

s3p13_Phrase02:
	dc.b	nEb3, $38, nRst, $04, nBb3, $08, nRst, $04, nEb4, $08, nRst, $04
	dc.b	nBb3, $08, nRst, $04, nCs4, $14, nRst, $04, nC4, $14, nRst, $04
	dc.b	nAb3, $14, nRst, $04, nAb3, $08, nRst, $04, nC4, $08, nRst, $04
	smpsReturn

s3p13_Phrase03:
	dc.b	nBb0, $03, nRst, $09, nBb0, $03, nRst, $09, nBb0, $03, nRst, $09
	dc.b	nBb0, $03, nRst, $09
	smpsReturn

s3p13_Phrase04:
	dc.b	nF1, $03, nRst, $09, nF1, $03, nRst, $09, nF1, $03, nRst, $09
	dc.b	nF1, $03, nRst, $09
	smpsReturn

s3p13_Phrase05:
	dc.b	nEb1, $03, nRst, $09, nEb1, $03, nRst, $09, nEb1, $03, nRst, $09
	dc.b	nEb1, $03, nRst, $09
	smpsReturn

s3p13_Phrase06:
	dc.b	nBb1, $01, nRst, $05, nBb1, $02, nRst, $04, nBb1, $02, nRst, $22
	dc.b	nAb1, $01, nRst, $05, nAb1, $01, nRst, $05, nAb1, $01, nRst, $60
	dc.b	nRst, nRst
	smpsReturn

s3p13_Phrase07:
	dc.b	nRst, $04, nAb4, $08, nRst, $04, nAb4, $08, nRst, $04, nAb4, $08
	dc.b	nRst, $04, nAb4, $08, nRst, $04, nAb4, $08, nRst, $04, nAb4, $08
	dc.b	nRst, $04, nAb4, $08, nRst, $04, nAb4, $08, nRst, $04, nAb4, $08
	dc.b	nRst, $04, nBb4, $08, nRst, $04, nC5, $08, nRst, $04, nAb4, $20
	smpsReturn

s3p13_Phrase08:
	dc.b	nG0, $03, nRst, $09, nG0, $03, nRst, $09, nG0, $03, nRst, $09
	dc.b	nG0, $03, nRst, $09
	smpsReturn

s3p13_Phrase09:
	dc.b	dKickS3, dSnareS3, dKickS3, dSnareS3, dKickS3, dSnareS3, dKickS3, dSnareS3, dKickS3, dSnareS3, dKickS3, dSnareS3
	dc.b	dKickS3, dSnareS3, dKickS3, dSnareS3
	smpsReturn

s3p13_Phrase0A:
	dc.b	dKickS3, dKickS3, dKickS3, dKickS3, dKickS3, dKickS3, dKickS3, dKickS3, dKickS3, dKickS3, dKickS3, dKickS3
	dc.b	dKickS3, dKickS3, dSnareS3, dKickS3, dKickS3, dKickS3, dKickS3, dKickS3, dKickS3, dKickS3, dKickS3, dKickS3
	dc.b	dKickS3, dKickS3, dKickS3, dKickS3, dKickS3
	smpsReturn

s3p13_Phrase0B:
	dc.b	nBb0, $2D, nRst, $03, nBb0, $05, nRst, $03, nBb0, $05, nRst, $03
	dc.b	nBb0, $05, nRst, $03
	smpsReturn

s3p13_Voices:
; Local instruments; source indices identify the original S3 voice bank.

;	Voice $00 (source $00)
;	$3C
;	$01, $00, $00, $00, 	$1F, $1F, $15, $1F, 	$11, $0D, $12, $05
;	$07, $04, $09, $02, 	$55, $3A, $25, $1A, 	$1A, $80, $07, $80
	smpsVcAlgorithm     $04
	smpsVcFeedback      $07
	smpsVcUnusedBits    $00
	smpsVcDetune        $00, $00, $00, $00
	smpsVcCoarseFreq    $00, $00, $00, $01
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $15, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $05, $12, $0D, $11
	smpsVcDecayRate2    $02, $09, $04, $07
	smpsVcDecayLevel    $01, $02, $03, $05
	smpsVcReleaseRate   $0A, $05, $0A, $05
	smpsVcTotalLevel    $80, $07, $80, $1A

;	Voice $01 (source $08)
;	$3C
;	$71, $72, $3F, $34, 	$8D, $52, $9F, $1F, 	$09, $00, $00, $0D
;	$00, $00, $00, $00, 	$23, $08, $02, $F7, 	$15, $80, $1D, $87
	smpsVcAlgorithm     $04
	smpsVcFeedback      $07
	smpsVcUnusedBits    $00
	smpsVcDetune        $03, $03, $07, $07
	smpsVcCoarseFreq    $04, $0F, $02, $01
	smpsVcRateScale     $00, $02, $01, $02
	smpsVcAttackRate    $1F, $1F, $12, $0D
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $0D, $00, $00, $09
	smpsVcDecayRate2    $00, $00, $00, $00
	smpsVcDecayLevel    $0F, $00, $00, $02
	smpsVcReleaseRate   $07, $02, $08, $03
	smpsVcTotalLevel    $87, $1D, $80, $15

;	Voice $02 (source $0A)
;	$3A
;	$31, $53, $31, $41, 	$8D, $4F, $15, $52, 	$06, $08, $07, $04
;	$02, $00, $00, $00, 	$1F, $1F, $2F, $2F, 	$19, $20, $2A, $80
	smpsVcAlgorithm     $02
	smpsVcFeedback      $07
	smpsVcUnusedBits    $00
	smpsVcDetune        $04, $03, $05, $03
	smpsVcCoarseFreq    $01, $01, $03, $01
	smpsVcRateScale     $01, $00, $01, $02
	smpsVcAttackRate    $12, $15, $0F, $0D
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $04, $07, $08, $06
	smpsVcDecayRate2    $00, $00, $00, $02
	smpsVcDecayLevel    $02, $02, $01, $01
	smpsVcReleaseRate   $0F, $0F, $0F, $0F
	smpsVcTotalLevel    $80, $2A, $20, $19
