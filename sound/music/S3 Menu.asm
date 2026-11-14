s3p45_Header:
	smpsHeaderStartSong 3, 1
	smpsHeaderVoice     s3p45_Voices
	smpsHeaderChan      $06, $03
	smpsHeaderTempo     $01, $25

	smpsHeaderDAC       s3p45_DAC
	smpsHeaderFM        s3p45_FM1,	$18, $12
	smpsHeaderFM        s3p45_FM2,	$0C, $19
	smpsHeaderFM        s3p45_FM3,	$0C, $19
	smpsHeaderFM        s3p45_FM4,	$0C, $19
	smpsHeaderFM        s3p45_FM5,	$0C, $19
	smpsHeaderPSG       s3p45_PSG1,	$F4, $04, $00, sTone_0C
	smpsHeaderPSG       s3p45_PSG2,	$F4, $04, $00, sTone_0C
	smpsHeaderPSG       s3p45_PSG3,	$00, $04, $00, sTone_0C

; DAC Data
s3p45_DAC:
	dc.b	nRst, $30, dSnareS3, $02, dSnareS3, dSnareS3, dSnareS3, $06, dSnareS3, dSnareS3, dSnareS3, dSnareS3
	dc.b	dSnareS3, dSnareS3

s3p45_Jump00:
	smpsCall	s3p45_Phrase0F
	dc.b	dKickS3, $12
	smpsCall	s3p45_Phrase0F
	dc.b	dKickS3, dSnareS3, dSnareS3
	smpsCall	s3p45_Phrase07
	dc.b	dSnareS3, $24, dKickS3, $0C, dSnareS3, $06, dKickS3, dSnareS3, $0C
	smpsCall	s3p45_Phrase07
	dc.b	dSnareS3, $1E, dSnareS3, $06, dKickS3, dSnareS3, dSnareS3, dKickS3, dSnareS3, dSnareS3
	smpsCall	s3p45_Phrase07
	dc.b	dSnareS3, $24, dKickS3, $06, dSnareS3, dSnareS3, dSnareS3, dSnareS3, dSnareS3, dKickS3, dKickS3, dKickS3
	dc.b	dKickS3, dSnareS3, $24, dKickS3, $06, dKickS3, dSnareS3, dKickS3, $12
	smpsCall	s3p45_Phrase08
	smpsCall	s3p45_Phrase08
	smpsCall	s3p45_Phrase08
	dc.b	dSnareS3, $06, dSnareS3, dSnareS3, dSnareS3, $26, dSnareS3, $02, dSnareS3, dSnareS3, $06, dSnareS3
	dc.b	dSnareS3, dSnareS3, dSnareS3, dSnareS3
	smpsJump            s3p45_Jump00

; FM1 Data
s3p45_FM1:
	smpsSetvoice        $03
	smpsDetune          $00
	smpsModSet          $0F, $01, $06, $06
	dc.b	nRst, $60

s3p45_Jump04:
	smpsCall	s3p45_Phrase09
	smpsCall	s3p45_Phrase09
	smpsCall	s3p45_Phrase04
	smpsCall	s3p45_Phrase04
	dc.b	nF1, $06, nRst, $12, nF2, nC2, $06, nEb2, $04, nRst, $08
	dc.b	nF2, $04, nRst, $08, nEb2, $06, nC2, $12, nBb1, $06, nB1, nC2
	dc.b	nBb1, nAb1, nF1, $0C, nAb1, $06, nRst, $0C, nBb1, $04, nRst, $08
	dc.b	nAb1, $06, nF1, $0E, nRst, $04
	smpsCall	s3p45_Phrase04
s3p45_Run03_Repeat00:
	smpsCall	s3p45_Phrase01
	smpsLoop	$00, $05, s3p45_Run03_Repeat00
	dc.b	nCs1, $06, nRst, $12, nCs2, $0E, nRst, $04, nCs2, $06, nB1, $04
	dc.b	nRst, $08, nAb1, $04, nRst, $08, nFs1, $06, nAb1, $10, nRst, $02
	dc.b	nG1, $06, nRst, $12, nG2, $10, nRst, $02, nG2, $04, nRst, $02
	dc.b	nF2, $04, nRst, $08, nD2, $04, nRst, $08, nC2, $04, nRst, $02
	dc.b	nD2, $0E, nRst, $04
	smpsJump            s3p45_Jump04

; FM5 Data
s3p45_FM5:
	dc.b	nRst, $03
	smpsJump            s3p45_FM2

; FM2 Data
s3p45_FM2:
	smpsSetvoice        $01
	smpsDetune          $03
	smpsModSet          $0F, $01, $06, $06
	dc.b	nRst, $60

s3p45_Jump03:
	dc.b	nRst, $1E, nBb4, $0A, nRst, $02, nA4, $04, nRst, $50, nA4, $0A
	dc.b	nRst, $02, nBb4, $04, nRst, $50, nBb4, $0A, nRst, $02, nA4, $04
	dc.b	nRst, $50, nA4, $0A, nRst, $02, nBb4, $04, nRst, $32
	smpsSetvoice        $04
	smpsDetune          $03
	smpsModSet          $0F, $01, $06, $06
	dc.b	nEb4, $04, nRst, $08, nD4, $04, nRst, $08, nC4, $0C, nBb3, $06
	dc.b	nC4, $1C, nRst, $08, nF3, $02, nFs3, nRst, nG3, $06, nBb3
	dc.b	nEb4, $04, nRst, $08, nD4, $04, nRst, $08, nC4, $06, nBb3, $12
	dc.b	nC4, $0C, nBb3, $06, nFs3, $02, nG3, $06
	smpsCall	s3p45_Phrase0B
	dc.b	nC4, $0C, nBb3, $04, nRst, $02, nC4, $20
	smpsCall	s3p45_Phrase0B
	dc.b	nC4, $06, nBb3, $12, nC4, $0C, nBb3, $06, nG3, $08, nRst, $16
	dc.b	nF2, $06, nF3, nEb3, $04, nRst, $02, nC3, $06, nEb3, nF3, $04
	dc.b	nRst, $08, nFs3, $12, nF3, $06, nC3, nEb3, nF3, nRst, nBb3, $12
	dc.b	nG3, $06, nF3, $04, nRst, $02, nG3, $06, nF3, nEb3, nC3
	dc.b	nEb3, $04, nRst, $08, nF3, $06, nEb3, $08
	smpsCall	s3p45_Phrase0B
	dc.b	nC4, $0C, nBb3, $06, nC4, $0C, nD4, $06, nC4, $20, nRst, $04
	dc.b	nF4, $0E, nRst, $04, nF4, $12, nEb4, $2E, nRst, $0E, nD4
	dc.b	nRst, $04, nD4, $12, nC4, $3C, nBb3, $0C, nRst, $06, nBb3, $12
	dc.b	nG3, $38, nRst, $04, nF3, $0E, nRst, $04, nF3, $12, nEb3, $18
	dc.b	nF3, $0C, nG3, $08, nRst, $04, nBb3, $0A, nRst, $02, nEb3, $12
	dc.b	nD3, $04, nRst, $0E, nEb3, $18
	smpsSetvoice        $02
	smpsDetune          $00
	smpsModSet          $0F, $01, $06, $06
	dc.b	nC3, $06, nEb3, nF3, nFs3, nG3, nBb3, nC4, $0C, nBb3, $04, nRst
	dc.b	$02, nC4, $06, nEb4, nF4, nRst, nF4, $02, nF4, nFs4, nF4, $0C
	dc.b	nEb4, $06, nC4, nEb4, nF4, $10, nRst, $02, nFs4, nG4, $0A, nBb4
	dc.b	$06, nG4, nBb4, nC5, nRst, nD5, $02, nEb5, $0A, nD5, $04, nRst
	dc.b	$02, nC5, $06, nBb4, nC5, $0C, nBb4, $02, nG4, nF4, nEb4, nC4
	dc.b	nBb3
	smpsSetvoice        $02
	smpsDetune          $00
	smpsModSet          $0F, $01, $06, $06
	dc.b	nEb5, $06, nF5, $0A, nRst, $02, nEb5, $06, nFs5, $0C, nEb5, $06
	dc.b	nA5, $02, nBb5, $0A, nF5, $06, nEb5, nC5, nEb5, nC5, nBb4, nC5
	dc.b	nBb4, nG4, nBb4, nG4, nF4, nG4, nF4, nEb4, nF4, nEb4, nC4, nEb4
	dc.b	$12, nC4, $02, nBb3, nG3, nF3, nEb3, nC3
	smpsSetvoice        $02
	smpsDetune          $00
	smpsModSet          $0F, $01, $06, $06
	dc.b	nEb4, $12, nFs4, nF4, $28, nRst, $14, nFs4, $02, nG4, $10, nBb4
	dc.b	$12, nG4, $06, nBb4, nA4, $12, nFs4, $02, nG4, $14, nRst, $08
	smpsSetvoice        $02
	smpsDetune          $00
	smpsModSet          $0F, $01, $06, $06
	dc.b	nBb4, $12, nEb5, $1E, nB4, $12, nE5, $1E, nF5, $08, nRst, $10
	dc.b	nF5, $30, nRst, $06, nF3, nG3, nBb3
	smpsJump            s3p45_Jump03

; FM3 Data
s3p45_FM3:
	smpsSetvoice        $05
	dc.b	nRst, $60

s3p45_Jump02:
	smpsCall	s3p45_Phrase0A
	smpsCall	s3p45_Phrase0A
	smpsCall	s3p45_Phrase0C
	smpsCall	s3p45_Phrase0C
	dc.b	nEb3, $04, nRst, $14, nFs3, $02, nG3, $0E, nRst, $02, nEb3, $04
	dc.b	nRst, $3E, nEb4, $04, nRst, $0E, nEb4, $04, nRst, $0E, nF4, $02
	dc.b	nFs4, $0E, nRst, $02, nEb4, $04, nRst, $1A, nG3, $04, nRst, $14
	dc.b	nA3, $10, nRst, $02, nG3, $04, nRst, $32, nD4, $10, nRst, $02
	dc.b	nD4, $04, nRst, $0E, nBb3, $10, nRst, $2C, nBb3, $10, nRst, $02
	dc.b	nBb3, $04, nRst, $0E, nG3, $10, nRst, $02, nEb4, $04, nRst, $02
	dc.b	nG4, $04, nRst, $08, nF4, $04, nRst, $02, nEb4, $0E, nRst, $04
	dc.b	nG3, $10, nRst, $02, nG3, $04, nRst, $0E, nEb3, $10, nRst, $02
	dc.b	nC4, $04, nRst, $02, nEb4, $04, nRst, $08, nD4, $06, nC4, $12
	dc.b	nD3, $10, nRst, $02, nD3, $04, nRst, $0E, nC3, $10, nRst, $02
	dc.b	nF4, $04, nRst, $02, nBb4, $04, nRst, $08, nAb4, $04, nRst, $02
	dc.b	nG4, $10, nRst, $02, nBb2, $10, nRst, $02, nBb2, $04, nRst, $0E
	dc.b	nBb2, $10, nRst, $02, nBb3, $04, nRst, $02, nF4, $04, nRst, $08
	dc.b	nEb4, $04, nRst, $02, nC4, $0C, nRst, $06, nAb3, $04, nRst, $02
	dc.b	nAb3, $04, nRst, $02, nEb3, $04, nRst, $02, nAb3, $04, nRst, $1A
	dc.b	nBb4, $02, nC5, $0A
	smpsCall	s3p45_Phrase06
	dc.b	nF5, $02, nFs5, $0A
	smpsCall	s3p45_Phrase06
	dc.b	nBb4, $02, nC5, $0A
	smpsCall	s3p45_Section04
	dc.b	nF5, $0C
	smpsCall	s3p45_Section03
	dc.b	nEb5, $02, nF5, $0A, nAb3, $04, nRst, $02, nAb3, $04, nRst, $02
	dc.b	nEb3, $04, nRst, $02, nAb3, $0A, nRst, $08, nD4, $04, nRst, $02
	dc.b	nD4, $04, nRst, $02, nD4, $04, nRst, $02, nD4, $04, nRst, $26
	dc.b	nD4, $04, nRst, $02, nD4, $04, nRst, $02, nD4, $04, nRst, $02
	dc.b	nD4, $04, nRst, $0E
	smpsJump            s3p45_Jump02

; FM4 Data
s3p45_FM4:
	smpsSetvoice        $06
	dc.b	nRst, $60

s3p45_Jump01:
	dc.b	nD3, $04, nRst, $08, nC3, $06, nD3, $04, nRst, $08
	smpsSetvoice        $01
	smpsDetune          $FD
	smpsModSet          $0F, $01, $06, $06
	dc.b	nEb4, $0A, nRst, $02, nEb4, $04, nRst, $0E
	smpsSetvoice        $06
	dc.b	nEb3, $02, nRst, $0A, nD3, $04, nRst, $02, nEb3, $12, nD3, $04
	dc.b	nRst, $08, nC3, $06, nD3, $04, nRst, $08
	smpsSetvoice        $01
	smpsDetune          $FD
	smpsModSet          $0F, $01, $06, $06
	dc.b	nEb4, $0A, nRst, $02, nEb4, $04, nRst, $0E
	smpsSetvoice        $06
	dc.b	nG3, $02, nRst, $10, nG3, $0A, nRst, $08, nD3, $04, nRst, $08
	dc.b	nC3, $06, nD3, $04, nRst, $08
	smpsSetvoice        $01
	smpsDetune          $FD
	smpsModSet          $0F, $01, $06, $06
	dc.b	nEb4, $0A, nRst, $02, nEb4, $04, nRst, $0E
	smpsSetvoice        $06
	dc.b	nEb3, $02, nRst, $0A, nD3, $04, nRst, $02, nEb3, $12, nD3, $04
	dc.b	nRst, $08, nC3, $06, nD3, $04, nRst, $08
	smpsSetvoice        $01
	smpsDetune          $FD
	smpsModSet          $0F, $01, $06, $06
	dc.b	nEb4, $0A, nRst, $02, nEb4, $04, nRst, $0E
	smpsSetvoice        $06
	dc.b	nG3, $02, nRst, $10, nG3, $0A, nRst, $08
	smpsCall	s3p45_Phrase0D
	smpsCall	s3p45_Phrase0D
	dc.b	nC3, $04, nRst, $14, nEb3, $10, nRst, $02, nC3, $04, nRst, $3E
	dc.b	nC4, $04, nRst, $0E, nC4, $04, nRst, $0E, nEb4, $10, nRst, $02
	dc.b	nC4, $04, nRst, $1A, nEb3, $04, nRst, $14, nF3, $10, nRst, $02
	dc.b	nEb3, $04, nRst, $32, nBb3, $10, nRst, $02, nBb3, $04, nRst, $0E
	dc.b	nG3, $10, nRst, $02, nG4, $06, nBb4, nD5, nBb4, nG4, nEb4, nBb3
	dc.b	nF3, $10, nRst, $02, nF3, $04, nRst, $0E, nEb3, $10, nRst, $02
	dc.b	nBb3, $04, nRst, $02, nEb4, $04, nRst, $08, nD4, $04, nRst, $02
	dc.b	nC4, $0E, nRst, $04, nEb3, $10, nRst, $02, nEb3, $04, nRst, $0E
	dc.b	nBb2, $10, nRst, $02, nG3, $04, nRst, $02, nC4, $04, nRst, $08
	dc.b	nBb3, $06, nEb3, $12, nBb2, $10, nRst, $02, nBb2, $04, nRst, $0E
	dc.b	nG2, $10, nRst, $02, nBb3, $04, nRst, $02, nD4, $04, nRst, $08
	dc.b	nC4, $04, nRst, $02, nEb4, $10, nRst, $02, nG2, $10, nRst, $02
	dc.b	nF2, $04, nRst, $0E, nG2, $10, nRst, $02, nG3, $04, nRst, $02
	dc.b	nD4, $04, nRst, $08, nC4, $04, nRst, $02, nEb3, $0C, nRst, $06
	dc.b	nEb3, $04, nRst, $02, nEb3, $04, nRst, $02, nBb2, $04, nRst, $02
	dc.b	nEb3, $04, nRst, $1A, nFs4, $0C
	smpsCall	s3p45_Phrase05
	dc.b	nC5, $0C
	smpsCall	s3p45_Phrase05
	dc.b	nFs4, $0C
	smpsCall	s3p45_Section02
	dc.b	nC5, $0C, nG3, $04, nRst, $02, nG3, $04, nRst, $02, nF3, $04
	dc.b	nRst, $02, nG3, $0A, nBb3, $02, nG3, nF3, nEb3, nCs3, $04
	dc.b	nRst, $02, nCs3, $04, nRst, $02, nBb2, $04, nRst, $02, nCs3, $04
	dc.b	nRst, $1A, nB4, $0C, nCs3, $04, nRst, $02, nCs3, $04, nRst, $02
	dc.b	nBb2, $04, nRst, $02, nCs3, $0A, nFs3, $02, nF3, nEb3, nC3
	dc.b	nG3, $04, nRst, $02, nG3, $04, nRst, $02, nG3, $04, nRst, $02
	dc.b	nG3, $04, nRst, $02, nB3, $24, nG3, $04, nRst, $02, nG3, $04
	dc.b	nRst, $02, nG3, $04, nRst, $02, nG3, $04, nRst, $0E
	smpsJump            s3p45_Jump01

; PSG1 Data
s3p45_PSG1:
	dc.b	nRst, $60

s3p45_Jump06:
	smpsCall	s3p45_Phrase0E
	smpsCall	s3p45_Phrase0E
	dc.b	nC5, $04, nRst, $08, nD5, $04, nRst, $08, nEb5, $04, nRst, $08
	smpsCall	s3p45_Section01
	smpsCall	s3p45_Phrase03
	smpsCall	s3p45_Phrase03
	smpsCall	s3p45_Phrase03
	dc.b	nRst, $3E, nG4, $06, nBb4, nD5, nBb4, nG4, nEb4, nBb3, nBb4, $10
	dc.b	nRst, $02, nBb4, $04, nRst, $0E, nG4, $10, nRst, $02, nEb5, $04
	dc.b	nRst, $02, nG5, $04, nRst, $08, nF5, $04, nRst, $02, nEb5, $0E
	dc.b	nRst, $04, nG4, $10, nRst, $02, nG4, $04, nRst, $0E, nEb4, $10
	dc.b	nRst, $02, nC5, $04, nRst, $02, nEb5, $04, nRst, $08, nD5, $06
	dc.b	nC5, $12, nD4, $10, nRst, $02, nD4, $04, nRst, $0E, nC4, $10
	dc.b	nRst, $02, nF5, $04, nRst, $02, nBb5, $04, nRst, $08, nAb5, $04
	dc.b	nRst, $02, nG5, $10, nRst, $02, nBb3, $10, nRst, $02, nBb3, $04
	dc.b	nRst, $0E, nBb3, $10, nRst, $02, nBb4, $04, nRst, $02, nF5, $04
	dc.b	nRst, $08, nEb5, $04, nRst, $02, nC5, $0C, nRst, $06
	smpsCall	s3p45_Phrase02
	smpsCall	s3p45_Phrase02
	smpsCall	s3p45_Phrase02
	dc.b	nF4, $04, nRst, $08, nF4, $04, nRst, $08, nF4, $04, nRst, $02
	dc.b	nF5, $04, nRst, $08, nF4, $04, nRst, $02, nF5, $04, nRst, $08
	dc.b	nF4, $04, nRst, $02, nF5, $04, nRst, $08, nF4, $04, nRst, $02
	dc.b	nF4, $04, nRst, $02, nF5, $04
	smpsCall	s3p45_Section00
	smpsJump            s3p45_Jump06

; PSG2 Data
s3p45_PSG2:
	dc.b	nRst, $7F, nRst, nRst, nRst, nRst, nRst, nRst, nRst, nRst, nRst, nRst
	dc.b	nRst, nRst, nRst, nRst, nRst, nRst, nRst, nRst, $72
	smpsJump            s3p45_Jump06

; PSG3 Data
s3p45_PSG3:
	smpsPSGvoice        sTone_02
	smpsPSGform         $E7
	dc.b	nRst, $60

s3p45_Jump05:
	dc.b	nMaxPSG1, $06
	smpsCall	s3p45_Phrase00
	smpsCall	s3p45_Phrase00
	dc.b	nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1
	dc.b	nMaxPSG1
	smpsCall	s3p45_Section05
	smpsCall	s3p45_Phrase00
	smpsCall	s3p45_Section05
s3p45_Run1C_Repeat00:
	smpsCall	s3p45_Phrase00
	smpsLoop	$00, $04, s3p45_Run1C_Repeat00
	dc.b	nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1
	dc.b	nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nMaxPSG1, nRst, $60
	smpsJump            s3p45_Jump05

; Shared note phrases; channel settings stay in the calling tracks.

s3p45_Phrase00:
	dc.b	nMaxPSG1
	smpsLoop	$01, $1D, s3p45_Phrase00
	smpsReturn

s3p45_Phrase01:
	dc.b	nAb0, $06, nRst, $12, nAb1, $0E, nRst, $04, nAb1, $06, nG1, $04
	dc.b	nRst, $08, nF1, $04, nRst, $08, nEb1, $06, nF1, $10, nRst, $02
	dc.b	nC1, $06, nRst, $12, nC2, $10, nRst, $02, nC2, $04, nRst, $02
	dc.b	nBb1, $04, nRst, $08, nG1, $04, nRst, $08, nF1, $04, nRst, $02
	dc.b	nG1, $0E, nRst, $04
	smpsReturn

s3p45_Phrase02:
	dc.b	nEb4, $04, nRst, $08, nEb4, $04, nRst, $08, nEb4, $04, nRst, $02
	dc.b	nEb5, $04, nRst, $08, nEb4, $04, nRst, $02, nEb5, $04, nRst, $08
	dc.b	nEb4, $04, nRst, $02, nEb5, $04, nRst, $08, nEb4, $04, nRst, $02
	dc.b	nEb4, $04, nRst, $02, nEb5, $04
	smpsCall	s3p45_Section00
	smpsReturn

s3p45_Phrase03:
	dc.b	nRst, $08, nC5, $04, nRst, $08, nEb5, $04, nRst, $0E, nEb5, $04
	dc.b	nRst, $02
	smpsCall	s3p45_Section01
	dc.b	nRst, $08, nC5, $04, nRst, $08, nD5, $04, nRst, $08, nEb5, $04
	dc.b	nRst, $08
	smpsCall	s3p45_Section01
	smpsReturn

s3p45_Phrase04:
	dc.b	nC1, $06, nRst, $12, nC2, nG1, $06, nBb1, $04, nRst, $08
	dc.b	nC2, $04, nRst, $08, nBb1, $06, nG1, $12, nF1, $06, nFs1, nG1
	dc.b	nF1, nEb1, nC1, $0C, nEb1, $06, nRst, $0C, nF1, $04, nRst, $08
	dc.b	nEb1, $06, nBb0, $0E, nRst, $04
	smpsReturn

s3p45_Phrase05:
	smpsCall	s3p45_Section02
	dc.b	nBb4, $0C, nG3, $04, nRst, $02, nG3, $04, nRst, $02, nF3, $04
	dc.b	nRst, $02, nG3, $0A, nBb3, $02, nG3, nF3, nEb3, nEb3, $04
	dc.b	nRst, $02, nEb3, $04, nRst, $02, nBb2, $04, nRst, $02, nEb3, $04
	dc.b	nRst, $1A
	smpsReturn

s3p45_Phrase06:
	smpsCall	s3p45_Section04
	dc.b	nEb5, $0C
	smpsCall	s3p45_Section03
	smpsReturn

s3p45_Phrase07:
	dc.b	dKickS3, $18, dSnareS3, $24, dKickS3, $0C, dSnareS3, $06, dKickS3, $12, dKickS3, $18
	dc.b	dSnareS3, $24, dKickS3, $0C, dSnareS3, $06, dKickS3, $12, dKickS3, $18, dSnareS3, $24
	dc.b	dKickS3, $0C, dSnareS3, $06, dKickS3, $12, dKickS3, $18
	smpsReturn

s3p45_Phrase08:
	dc.b	dKickS3, $06, dKickS3, dKickS3, dKickS3, dSnareS3, $24, dKickS3, $06, dKickS3, dSnareS3, dKickS3
	dc.b	dSnareS3, $0C, dKickS3, $06, dKickS3, dKickS3, dKickS3, dSnareS3, $24, dKickS3, $06, dKickS3
	dc.b	dSnareS3, dKickS3, $12
	smpsReturn

s3p45_Phrase09:
	dc.b	nC1, $06, nRst, $12, nC2, nG1, $06, nRst, nBb1, $04, nRst, $02
	dc.b	nC2, $04, nRst, $08, nBb1, $06, nG1, $12, nF1, $06, nFs1, nG1
	dc.b	nF1, nEb1, nC1, $0C, nEb1, $04, nRst, $08, nFs1, $04, nRst, $02
	dc.b	nF1, $0C, nEb1, $06, nBb0, $0E, nRst, $04
	smpsReturn

s3p45_Phrase0A:
	dc.b	nF3, $04, nRst, $08, nEb3, $06, nF3, $04, nRst, $26, nG3, $04
	dc.b	nRst, $08, nF3, $04, nRst, $02, nG3, $12, nF3, $04, nRst, $08
	dc.b	nEb3, $06, nF3, $04, nRst, $26, nBb3, $04, nRst, $0E, nBb3, $0A
	dc.b	nRst, $08
	smpsReturn

s3p45_Phrase0B:
	dc.b	nRst, $04, nF3, nRst, $02, nG3, $06, nBb3, nEb4, $04, nRst, $08
	dc.b	nD4, $04, nRst, $08
	smpsReturn

s3p45_Phrase0C:
	dc.b	nG3, $04, nRst, $14, nA3, $10, nRst, $02, nG3, $04, nRst, $3E
	dc.b	nBb4, $04, nRst, $0E, nBb4, $04, nRst, $0E, nA4, $02, nBb4, $10
	dc.b	nA4, $04, nRst, $1A
	smpsReturn

s3p45_Phrase0D:
	dc.b	nEb3, $04, nRst, $14, nF3, $10, nRst, $02, nEb3, $04, nRst, $3E
	dc.b	nG4, $04, nRst, $0E, nG4, $04, nRst, $0E, nG4, $10, nRst, $02
	dc.b	nF4, $04, nRst, $1A
	smpsReturn

s3p45_Phrase0E:
	dc.b	nC4, $06, nRst, nC5, nC4, nRst, $1E, nC4, $06, nRst, nC5
	dc.b	nC4, $0C, nC5, nC4, $06, nRst, nC5, nC4, nRst, $1E, nC4, $06
	dc.b	nRst, nC5, nC4, $0C, nC5
	smpsReturn

s3p45_Phrase0F:
	dc.b	dKickS3, $18, dSnareS3, $06, dSnareS3, $0C, dSnareS3, $12, dKickS3, $0C, dSnareS3, $06
	dc.b	dKickS3, $12, dKickS3, $18, dSnareS3, $06, dSnareS3, $0C, dSnareS3, $12, dKickS3, $0C
	dc.b	dSnareS3, $06
	smpsReturn

; Shared sections built from the note phrases above.

s3p45_Section00:
	dc.b	nRst, $02, nG4, $04, nRst, $08, nG4, $04, nRst, $08, nG4, $04
	dc.b	nRst, $02, nG5, $04, nRst, $08, nG4, $04, nRst, $02, nG5, $04
	dc.b	nRst, $08, nG4, $04, nRst, $02, nG5, $04, nRst, $08, nG4, $04
	dc.b	nRst, $02, nG4, $04, nRst, $02, nG5, $04, nRst, $02
	smpsReturn

s3p45_Section01:
	dc.b	nD5, $04, nRst, $02, nEb5, $04, nRst, $08, nC5, $04, nRst, $02
	dc.b	nD5, $04, nRst, $08, nEb5, $04, nRst, $08, nD5, $04
	smpsReturn

s3p45_Section02:
	dc.b	nEb3, $04, nRst, $02, nEb3, $04, nRst, $02, nBb2, $04, nRst, $02
	dc.b	nEb3, $0A, nFs3, $02, nF3, nEb3, nC3, nG3, $04, nRst, $02
	dc.b	nG3, $04, nRst, $02, nF3, $04, nRst, $02, nG3, $04, nRst, $1A
	smpsReturn

s3p45_Section03:
	dc.b	nC4, $04, nRst, $02, nC4, $04, nRst, $02, nBb3, $04, nRst, $02
	dc.b	nC4, $0A, nRst, $08, nAb3, $04, nRst, $02, nAb3, $04, nRst, $02
	dc.b	nEb3, $04, nRst, $02, nAb3, $04, nRst, $1A
	smpsReturn

s3p45_Section04:
	dc.b	nAb3, $04, nRst, $02, nAb3, $04, nRst, $02, nEb3, $04, nRst, $02
	dc.b	nAb3, $0A, nRst, $08, nC4, $04, nRst, $02, nC4, $04, nRst, $02
	dc.b	nBb3, $04, nRst, $02, nC4, $04, nRst, $1A
	smpsReturn

s3p45_Section05:
	dc.b	nMaxPSG1, $04, nMaxPSG1, nMaxPSG1, nMaxPSG1, $06
	smpsCall	s3p45_Phrase00
	dc.b	nMaxPSG1, $04, nMaxPSG1, nMaxPSG1, nMaxPSG1, $06
	smpsCall	s3p45_Phrase00
	dc.b	nMaxPSG1, $04, nMaxPSG1, nMaxPSG1, nMaxPSG1, $06
	smpsReturn

s3p45_Voices:
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

;	Voice $01 (source $0D)
;	$3A
;	$01, $07, $01, $01, 	$8E, $8E, $8D, $53, 	$0E, $0E, $0E, $03
;	$00, $00, $00, $07, 	$1F, $FF, $1F, $0F, 	$18, $28, $27, $80
	smpsVcAlgorithm     $02
	smpsVcFeedback      $07
	smpsVcUnusedBits    $00
	smpsVcDetune        $00, $00, $00, $00
	smpsVcCoarseFreq    $01, $01, $07, $01
	smpsVcRateScale     $01, $02, $02, $02
	smpsVcAttackRate    $13, $0D, $0E, $0E
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $03, $0E, $0E, $0E
	smpsVcDecayRate2    $07, $00, $00, $00
	smpsVcDecayLevel    $00, $01, $0F, $01
	smpsVcReleaseRate   $0F, $0F, $0F, $0F
	smpsVcTotalLevel    $80, $27, $28, $18

;	Voice $02 (source $0E)
;	$3A
;	$31, $25, $73, $41, 	$5F, $1F, $1F, $9C, 	$08, $05, $04, $1E
;	$03, $04, $02, $06, 	$2F, $2F, $1F, $0F, 	$29, $27, $1F, $80
	smpsVcAlgorithm     $02
	smpsVcFeedback      $07
	smpsVcUnusedBits    $00
	smpsVcDetune        $04, $07, $02, $03
	smpsVcCoarseFreq    $01, $03, $05, $01
	smpsVcRateScale     $02, $00, $00, $01
	smpsVcAttackRate    $1C, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $1E, $04, $05, $08
	smpsVcDecayRate2    $06, $02, $04, $03
	smpsVcDecayLevel    $00, $01, $02, $02
	smpsVcReleaseRate   $0F, $0F, $0F, $0F
	smpsVcTotalLevel    $80, $1F, $27, $29

;	Voice $03 (source $15)
;	$28
;	$71, $00, $30, $01, 	$1F, $1F, $1D, $1F, 	$06, $06, $06, $05
;	$05, $05, $02, $05, 	$4F, $4F, $2F, $3F, 	$1E, $28, $1E, $80
	smpsVcAlgorithm     $00
	smpsVcFeedback      $05
	smpsVcUnusedBits    $00
	smpsVcDetune        $00, $03, $00, $07
	smpsVcCoarseFreq    $01, $00, $00, $01
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1D, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $05, $06, $06, $06
	smpsVcDecayRate2    $05, $02, $05, $05
	smpsVcDecayLevel    $03, $02, $04, $04
	smpsVcReleaseRate   $0F, $0F, $0F, $0F
	smpsVcTotalLevel    $80, $1E, $28, $1E

;	Voice $04 (source $17)
;	$39
;	$32, $31, $72, $71, 	$1F, $1F, $1F, $1F, 	$00, $00, $00, $00
;	$00, $00, $00, $00, 	$0F, $0F, $0F, $0F, 	$1B, $32, $28, $80
	smpsVcAlgorithm     $01
	smpsVcFeedback      $07
	smpsVcUnusedBits    $00
	smpsVcDetune        $07, $07, $03, $03
	smpsVcCoarseFreq    $01, $02, $01, $02
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $00, $00, $00, $00
	smpsVcDecayRate2    $00, $00, $00, $00
	smpsVcDecayLevel    $00, $00, $00, $00
	smpsVcReleaseRate   $0F, $0F, $0F, $0F
	smpsVcTotalLevel    $80, $28, $32, $1B

;	Voice $05 (source $18)
;	$07
;	$34, $74, $32, $71, 	$1F, $1F, $1F, $1F, 	$0A, $0A, $05, $03
;	$00, $00, $00, $00, 	$3F, $3F, $2F, $2F, 	$8A, $8A, $80, $80
	smpsVcAlgorithm     $07
	smpsVcFeedback      $00
	smpsVcUnusedBits    $00
	smpsVcDetune        $07, $03, $07, $03
	smpsVcCoarseFreq    $01, $02, $04, $04
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $03, $05, $0A, $0A
	smpsVcDecayRate2    $00, $00, $00, $00
	smpsVcDecayLevel    $02, $02, $03, $03
	smpsVcReleaseRate   $0F, $0F, $0F, $0F
	smpsVcTotalLevel    $80, $80, $8A, $8A

;	Voice $06 (source $19)
;	$3A
;	$31, $37, $31, $31, 	$8D, $8D, $8E, $53, 	$0E, $0E, $0E, $03
;	$00, $00, $00, $00, 	$1F, $FF, $1F, $0F, 	$17, $28, $26, $80
	smpsVcAlgorithm     $02
	smpsVcFeedback      $07
	smpsVcUnusedBits    $00
	smpsVcDetune        $03, $03, $03, $03
	smpsVcCoarseFreq    $01, $01, $07, $01
	smpsVcRateScale     $01, $02, $02, $02
	smpsVcAttackRate    $13, $0E, $0D, $0D
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $03, $0E, $0E, $0E
	smpsVcDecayRate2    $00, $00, $00, $00
	smpsVcDecayLevel    $00, $01, $0F, $01
	smpsVcReleaseRate   $0F, $0F, $0F, $0F
	smpsVcTotalLevel    $80, $26, $28, $17
