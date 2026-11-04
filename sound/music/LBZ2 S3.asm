s3p14_Header:
	smpsHeaderStartSong 3
	smpsHeaderVoice     s3p14_Voices
	smpsHeaderChan      $06, $03
	smpsHeaderTempo     $01, $25

	smpsHeaderDAC       s3p14_DAC
	smpsHeaderFM        s3p14_FM1,	$0C, $1F
	smpsHeaderFM        s3p14_FM2,	$0C, $1F
	smpsHeaderFM        s3p14_FM3,	$18, $16
	smpsHeaderFM        s3p14_FM4,	$18, $0E
	smpsHeaderFM        s3p14_FM5,	$0C, $1A
	smpsHeaderPSG       s3p14_PSG1,	$F4, $04, $00, sTone_0C
	smpsHeaderPSG       s3p14_PSG2,	$F4, $04, $00, sTone_0C
	smpsHeaderPSG       s3p14_PSG3,	$00, $04, $00, sTone_0C

; DAC Data
s3p14_DAC:
	dc.b	dKickS3, $18, dSnareS3, $12, dSnareS3, $06, dKickS3, dSnareS3, $12
	smpsCall	s3p14_Section06
	smpsCall	s3p14_Section02
	smpsCall	s3p14_Section02
	smpsCall	s3p14_Section02
	smpsCall	s3p14_Section02
	dc.b	dSnareS3, $18, dKickS3, dSnareS3, dKickS3
	smpsCall	s3p14_Phrase08
	dc.b	dSnareS3, $18, dKickS3, dSnareS3, dKickS3
	smpsCall	s3p14_Phrase08
	smpsCall	s3p14_Section06
	dc.b	dSnareS3, $18, dKickS3, dSnareS3, dKickS3, dSnareS3, $0C, dSnareS3, $06, dSnareS3, dSnareS3, $0C
	dc.b	dSnareS3, dSnareS3, dKickS3, dSnareS3, dSnareS3, dSnareS3, $18, dKickS3, dSnareS3, $12, dSnareS3, $06
	dc.b	dKickS3, dSnareS3, $12
	smpsCall	s3p14_Phrase08
	dc.b	dSnareS3, $18, dKickS3, dSnareS3, dKickS3, $0C, dSnareS3, $06, dSnareS3, dSnareS3, dSnareS3, dSnareS3
	dc.b	dSnareS3, $08
	smpsJump            s3p14_DAC

; FM1 Data
s3p14_FM1:
	smpsSetvoice        $02
	smpsDetune          $01
	smpsModSet          $0A, $01, $00, $06
	smpsPan             panRight, $00

s3p14_Jump03:
	smpsCall	s3p14_Phrase02
	dc.b	nA4, $10, nRst, $02, nF4, $04, nRst, $08, nD4, $04, nRst, $08
	smpsCall	s3p14_Phrase02
	dc.b	nA4, $10, nRst, $02, nF4, $04, nRst, $08, nD4, $04, nRst, $08
	smpsCall	s3p14_Phrase02
	dc.b	nA4, $10, nRst, $02, nF4, $04, nRst, $08, nD4, $04
	smpsCall	s3p14_Phrase0E
	dc.b	nB4, $10, nRst, $02, nG4, $04, nRst, $14
	smpsCall	s3p14_Phrase03
	dc.b	nG4, $10, nRst, $02, nEb4, $04, nRst, $08, nC4, $04, nRst, $08
	smpsCall	s3p14_Phrase03
	dc.b	nG4, $10, nRst, $02, nEb4, $04, nRst, $08, nC4, $04, nRst, $08
	smpsCall	s3p14_Phrase03
	dc.b	nG4, $10, nRst, $02, nEb4, $04, nRst, $08, nC4, $04
	smpsCall	s3p14_Phrase0F
	dc.b	nA4, $10, nRst, $02, nF4, $04, nRst, $14
	smpsCall	s3p14_Phrase16
	dc.b	nF3, $16, nRst, $02, nBb3, $04, nRst, $02, nBb3, $04, nRst, $02
	dc.b	nG3, $04, nRst, $02, nBb3, $04, nRst, $14, nG4, $0A, nRst, $02
	dc.b	nEb4, $10, nRst, $02, nBb3, $16, nRst, $02, nA3, $04, nRst, $02
	dc.b	nA3, $04, nRst, $02, nF3, $04, nRst, $02, nA3, $04, nRst, $14
	dc.b	nF4, $0A, nRst, $02, nD4, $10, nRst, $02, nF3, $0A, nRst, $02
	dc.b	nG3, $10, nRst, $02, nG3, $04, nRst, $02, nE3, $04, nRst, $02
	dc.b	nG3, $04, nRst, $08, nG2, $04, nRst, $02, nC3, $04, nRst, $02
	dc.b	nE3, $04, nRst, $02, nG3, $04, nRst, $02, nE3, $04, nRst, $02
	dc.b	nG3, $04, nRst, $02, nC4, $04, nRst, $02, nE4, $04, nRst, $02
	dc.b	nC4, $04, nRst, $02, nE4, $04, nRst, $02, nG4, $04, nRst, $02
	smpsCall	s3p14_Phrase16
	dc.b	nF3, $16, nRst, $02
	smpsCall	s3p14_Phrase16
	dc.b	nF3, $0A, nRst, $02, nBb3, $0A, nRst, $02, nF3, $04, nRst, $02
	dc.b	nF3, $04, nRst, $02, nC3, $04, nRst, $02, nF3, $04, nRst, $14
	dc.b	nC4, $0A, nRst, $02, nG3, $10, nRst, $02, nE3, $0A, nRst, $02
	dc.b	nC4, $0A, nRst, $02, nB3, $04, nRst, $02, nB3, $04, nRst, $02
	dc.b	nG3, $04, nRst, $02, nB3, $04, nRst, $08, nB3, $04, nRst, $02
	dc.b	nD4, $04, nRst, $02, nD4, $04, nRst, $08, nD3, $04, nRst, $02
	dc.b	nE3, $04, nRst, $02, nF3, $04, nRst, $02, nG3, $04, nRst, $02
	dc.b	nA3, $04, nRst, $02, nB3, $04, nRst, $02, nD4, $04, nRst, $02
	smpsCall	s3p14_Phrase0B
	smpsCall	s3p14_Phrase0B
	smpsCall	s3p14_Phrase0B
	dc.b	nBb3, $04, nRst, $02, nBb3, $04, nRst, $02, nF3, $04, nRst, $08
	dc.b	nBb3, $04, nRst, $02, nBb3, $04, nRst, $02, nF3, $04, nRst, $0E
	dc.b	nBb4, $10, nRst, $02, nBb4, $04, nRst, $08, nBb4, $04, nRst, $08
	smpsCall	s3p14_Section0D
	dc.b	nF4, $10, nRst, $02, nAb4, $04, nRst, $08, nAb4, $04, nRst, $08
	smpsCall	s3p14_Phrase17
	dc.b	nFs4, $10, nRst, $02, nB4, $04, nRst, $08, nB4, $04, nRst, $08
	dc.b	nEb4, $06, nEb4, nD4, nRst, nBb3, nBb3, nF4, nF4, nE4, nRst, nC4
	dc.b	nC4, nG4, nG4, nFs4, nRst, nD4, nD4, nAb4, nAb4, nG4, nRst, nEb4
	dc.b	nEb4, nFs4, $12, nRst, $06, nF4, $12, nRst, $06
	smpsCall	s3p14_Phrase0B
	smpsCall	s3p14_Phrase19
	dc.b	nRst, $08
	smpsCall	s3p14_Phrase0B
	smpsCall	s3p14_Phrase19
	dc.b	nRst, $0A
	smpsJump            s3p14_Jump03

; FM2 Data
s3p14_FM2:
	smpsSetvoice        $02
	smpsDetune          $FF
	smpsModSet          $0A, $01, $00, $06
	smpsPan             panLeft, $00

s3p14_Jump02:
	smpsCall	s3p14_Phrase02
	dc.b	nF4, $10, nRst, $02, nD4, $04, nRst, $08, nBb3, $04, nRst, $08
	smpsCall	s3p14_Phrase02
	dc.b	nF4, $10, nRst, $02, nD4, $04, nRst, $08, nBb3, $04, nRst, $08
	smpsCall	s3p14_Phrase02
	dc.b	nF4, $10, nRst, $02, nD4, $04, nRst, $08, nBb3, $04
	smpsCall	s3p14_Phrase0E
	dc.b	nG4, $10, nRst, $02, nD4, $04, nRst, $14
	smpsCall	s3p14_Phrase03
	dc.b	nEb4, $10, nRst, $02, nC4, $04, nRst, $08, nAb3, $04, nRst, $08
	smpsCall	s3p14_Phrase03
	dc.b	nEb4, $10, nRst, $02, nC4, $04, nRst, $08, nAb3, $04, nRst, $08
	smpsCall	s3p14_Phrase03
	dc.b	nEb4, $10, nRst, $02, nC4, $04, nRst, $08, nAb3, $04
	smpsCall	s3p14_Phrase0F
	dc.b	nF4, $10, nRst, $02, nC4, $04, nRst, $14
	smpsCall	s3p14_Phrase13
	dc.b	nD3, $16, nRst, $02, nG3, $04, nRst, $02, nG3, $04, nRst, $02
	dc.b	nEb3, $04, nRst, $02, nG3, $04, nRst, $14, nEb4, $0A, nRst, $02
	dc.b	nBb3, $10, nRst, $02, nG3, $16, nRst, $02
	smpsCall	s3p14_Phrase13
	dc.b	nD3, $0A, nRst, $02, nE3, $10, nRst, $02, nE3, $04, nRst, $02
	dc.b	nC3, $04, nRst, $02, nE3, $04, nRst, $08, nE2, $04, nRst, $02
	dc.b	nG2, $04, nRst, $02, nC3, $04, nRst, $02, nE3, $04, nRst, $02
	dc.b	nC3, $04, nRst, $02, nE3, $04, nRst, $02, nG3, $04, nRst, $02
	dc.b	nC4, $04, nRst, $02, nG3, $04, nRst, $02, nC4, $04, nRst, $02
	dc.b	nE4, $04, nRst, $02
	smpsCall	s3p14_Phrase13
	dc.b	nD3, $16, nRst, $02
	smpsCall	s3p14_Phrase13
	dc.b	nD3, $0A, nRst, $02, nG3, $0A, nRst, $02, nC3, $04, nRst, $02
	dc.b	nC3, $04, nRst, $02, nA2, $04, nRst, $02, nC3, $04, nRst, $14
	dc.b	nE3, $0A, nRst, $02, nC3, $10, nRst, $02, nG2, $0A, nRst, $02
	dc.b	nE3, $0A, nRst, $02, nG3, $04, nRst, $02, nG3, $04, nRst, $02
	dc.b	nD3, $04, nRst, $02, nG3, $04, nRst, $08, nG3, $04, nRst, $02
	dc.b	nB3, $04, nRst, $02, nB3, $04, nRst, $08, nB2, $04, nRst, $02
	dc.b	nC3, $04, nRst, $02, nD3, $04, nRst, $02, nE3, $04, nRst, $02
	dc.b	nF3, $04, nRst, $02, nG3, $04, nRst, $02, nA3, $04, nRst, $02
	smpsCall	s3p14_Phrase0A
	smpsCall	s3p14_Phrase0A
	smpsCall	s3p14_Phrase0A
	dc.b	nF3, $04, nRst, $02, nF3, $04, nRst, $02, nD3, $04, nRst, $08
	dc.b	nF3, $04, nRst, $02, nF3, $04, nRst, $02, nD3, $04, nRst, $0E
	dc.b	nF4, $10, nRst, $02, nF4, $04, nRst, $08, nF4, $04, nRst, $08
	smpsCall	s3p14_Section0C
	dc.b	nCs4, $10, nRst, $02, nF4, $04, nRst, $08, nF4, $04, nRst, $08
	dc.b	nEb3, $04, nRst, $02, nEb3, $04, nRst, $02, nC3, $04, nRst, $08
	dc.b	nEb3, $04, nRst, $02, nEb3, $04, nRst, $02, nC3, $04, nRst, $0E
	dc.b	nEb4, $10, nRst, $02, nFs4, $04, nRst, $08, nFs4, $04, nRst, $08
	dc.b	nBb3, $06, nBb3, nA3, nRst, nF3, nF3, nC4, nC4, nB3, nRst, nG3
	dc.b	nG3, nD4, nD4, nCs4, nRst, nA3, nA3, nEb4, nEb4, nD4, nRst, nBb3
	dc.b	nBb3, nEb4, $12, nRst, $06, nD4, $12, nRst, $06
	smpsCall	s3p14_Phrase0A
	smpsCall	s3p14_Phrase17
	dc.b	nAb4, $10, nRst, $02, nAb4, $04, nRst, $08, nAb4, $04, nRst, $08
	smpsCall	s3p14_Phrase0A
	smpsCall	s3p14_Phrase17
	dc.b	nAb4, $10, nRst, $02, nAb4, $04, nRst, $08, nAb4, $04, nRst, $0A
	smpsJump            s3p14_Jump02

; FM3 Data
s3p14_FM3:
	smpsSetvoice        $01
	smpsDetune          $FE
	smpsModSet          $0F, $01, $06, $06
	smpsCall	s3p14_Phrase05
	smpsSetvoice        $01
	smpsDetune          $FE
	smpsModSet          $0F, $01, $06, $06
	smpsCall	s3p14_Phrase09
	smpsSetvoice        $01
	smpsDetune          $FE
	smpsModSet          $0F, $01, $06, $06
	smpsCall	s3p14_Phrase04
	smpsJump            s3p14_FM3

; FM4 Data
s3p14_FM4:
	smpsSetvoice        $03

s3p14_Jump01:
	smpsCall	s3p14_Phrase1A
	smpsCall	s3p14_Phrase10
	smpsCall	s3p14_Phrase1A
	smpsCall	s3p14_Phrase10
	smpsCall	s3p14_Phrase1A
	smpsCall	s3p14_Phrase10
	smpsCall	s3p14_Section05
	smpsCall	s3p14_Section05
	smpsCall	s3p14_Phrase12
	smpsCall	s3p14_Phrase12
	smpsCall	s3p14_Phrase12
	dc.b	nF0, $0A, nRst, $0E, nF0, $0A, nRst, $14, nF0, $04, nRst, $02
	dc.b	nF0, $0A, nRst, $02, nF0, $04, nRst, $14, nF0, $0A, nRst, $0E
	dc.b	nF0, $0A, nRst, $14, nF0, $04, nRst, $02, nF0, $0A, nRst, $02
	dc.b	nF0, $04, nRst, $14, nD0, $0A, nRst, $0E, nD0, $0A, nRst, $14
	dc.b	nD0, $04, nRst, $02, nD0, $0A, nRst, $02, nD0, $04, nRst, $14
	smpsCall	s3p14_Phrase11
	dc.b	nEb0, $04
	smpsCall	s3p14_Phrase10
	smpsCall	s3p14_Phrase18
	dc.b	nD0, $0A, nRst, $0E, nD0, $0A, nRst, $14, nD0, $04, nRst, $02
	dc.b	nD0, $0A, nRst, $02, nD0, $04
	smpsCall	s3p14_Phrase10
	smpsCall	s3p14_Phrase18
	smpsCall	s3p14_Phrase18
	smpsCall	s3p14_Phrase11
	dc.b	nEb0, $04, nRst, $14, nAb0, $0A, nRst, $0E, nAb0, $0A, nRst, $14
	dc.b	nAb0, $04, nRst, $02, nAb0, $0A, nRst, $02, nAb0, $04, nRst, $14
	smpsCall	s3p14_Phrase11
	dc.b	nEb0, $04
	smpsCall	s3p14_Phrase10
	dc.b	nEb1, $0A, nRst, $0E, nEb1, $0A, nRst, $14, nCs1, $04, nRst, $02
	dc.b	nCs1, $0A, nRst, $02, nCs1, $04, nRst, $14, nC1, $0A, nRst, $0E
	dc.b	nC1, $0A, nRst, $14, nB0, $04, nRst, $02, nB0, $0A, nRst, $02
	dc.b	nB0, $04, nRst, $14, nBb0, $08, nRst, $04, nA0, $14, nRst, $04
	dc.b	nC1, $08, nRst, $04, nB0, $14, nRst, $04, nEb1, $08, nRst, $04
	dc.b	nD1, $14, nRst, $04, nF1, $08, nRst, $04, nE1, $14, nRst, $04
	dc.b	nFs1, $14, nRst, $04, nF1, $14, nRst, $04
	smpsCall	s3p14_Phrase11
	dc.b	nEb0, $04, nRst, $14
	smpsCall	s3p14_Phrase11
	dc.b	nEb0, $04, nRst, $14
	smpsCall	s3p14_Phrase11
	dc.b	nEb0, $04, nRst, $14
	smpsCall	s3p14_Phrase11
	dc.b	nEb0, $0A, nRst, $02, nBb0, $0A, nRst, $04
	smpsJump            s3p14_Jump01

; FM5 Data
s3p14_FM5:
	dc.b	nRst, $02
	smpsFMAlterVol      $08

s3p14_Jump00:
	smpsSetvoice        $01
	smpsDetune          $02
	smpsModSet          $0F, $01, $06, $06
	smpsCall	s3p14_Phrase05
	smpsSetvoice        $01
	smpsDetune          $02
	smpsModSet          $0F, $01, $06, $06
	smpsCall	s3p14_Phrase09
	smpsSetvoice        $01
	smpsDetune          $02
	smpsModSet          $0F, $01, $06, $06
	smpsCall	s3p14_Phrase04
	smpsJump            s3p14_Jump00

; PSG1 Data
s3p14_PSG1:
	dc.b	nRst, $0C
	smpsCall	s3p14_Phrase15
	smpsCall	s3p14_Phrase07
	smpsCall	s3p14_Phrase15
	smpsCall	s3p14_Phrase07
	smpsCall	s3p14_Phrase15
s3p14_Run0B_Repeat00:
	smpsCall	s3p14_Phrase07
	smpsLoop	$00, $04, s3p14_Run0B_Repeat00
	smpsCall	s3p14_Phrase0D
	dc.b	nRst, $16
	smpsCall	s3p14_Phrase07
	smpsCall	s3p14_Phrase0D
	dc.b	nRst, $16
	smpsCall	s3p14_Phrase07
	smpsCall	s3p14_Phrase0D
	dc.b	nRst, $16
	smpsCall	s3p14_Phrase0D
	dc.b	nRst, $16
	smpsCall	s3p14_Phrase0D
	smpsCall	s3p14_Phrase00
	smpsJump            s3p14_PSG1

; PSG2 Data
s3p14_PSG2:
	dc.b	nRst, $0C
	smpsCall	s3p14_Phrase0C
	smpsCall	s3p14_Phrase06
	dc.b	nRst, $16
	smpsCall	s3p14_Phrase0C
	smpsCall	s3p14_Phrase06
	dc.b	nRst, $16
	smpsCall	s3p14_Phrase0C
	smpsCall	s3p14_Phrase06
	dc.b	nRst, $16
	smpsCall	s3p14_Phrase0C
	dc.b	nRst, $16
	smpsCall	s3p14_Phrase0C
	smpsCall	s3p14_Phrase06
	smpsCall	s3p14_Phrase14
	smpsCall	s3p14_Phrase06
	smpsCall	s3p14_Phrase14
	smpsCall	s3p14_Phrase06
	smpsCall	s3p14_Phrase14
	smpsCall	s3p14_Phrase06
	smpsCall	s3p14_Phrase06
	smpsCall	s3p14_Phrase00
	smpsJump            s3p14_PSG2

; PSG3 Data
s3p14_PSG3:
	smpsPSGvoice        sTone_02
	smpsPSGform         $E7

s3p14_Jump04:
	dc.b	nMaxPSG1, $0C
	smpsCall	s3p14_Phrase01
	smpsCall	s3p14_Phrase01
	smpsCall	s3p14_Section0B
	smpsCall	s3p14_Section0B
	smpsCall	s3p14_Section0A
	dc.b	nMaxPSG1, nMaxPSG1, $0C, nMaxPSG1, $06, nMaxPSG1, nMaxPSG1, $0C, nMaxPSG1, nMaxPSG1
	smpsCall	s3p14_Phrase01
	dc.b	nMaxPSG1, nMaxPSG1
	smpsCall	s3p14_Phrase01
	dc.b	nMaxPSG1, nMaxPSG1
	smpsCall	s3p14_Phrase01
	dc.b	nMaxPSG1, nMaxPSG1
	smpsCall	s3p14_Phrase01
	dc.b	nMaxPSG1, nMaxPSG1
	smpsCall	s3p14_Phrase01
	dc.b	nMaxPSG1, nMaxPSG1
	smpsCall	s3p14_Phrase01
	dc.b	nMaxPSG1, nMaxPSG1
	smpsCall	s3p14_Phrase01
	dc.b	nMaxPSG1, nMaxPSG1
	smpsCall	s3p14_Section0A
	dc.b	nMaxPSG1, $02, nRst, $06
	smpsJump            s3p14_Jump04

; Shared note phrases; channel settings stay in the calling tracks.

s3p14_Phrase00:
	dc.b	nRst, $0A
	smpsCall	s3p14_Section00
	dc.b	nEb4, $04, nRst, $02, nEb4, $04, nRst, $02, nEb5, $04, nRst, $02
	dc.b	nEb4, $04, nRst, $02, nEb5, $04, nRst, $02, nEb4, $04, nRst, $02
	dc.b	nEb4, $04, nRst, $02, nEb5, $04, nRst, $08, nEb4, $04, nRst, $02
	dc.b	nEb5, $04, nRst, $02, nEb4, $04, nRst, $02, nEb4, $04, nRst, $02
	dc.b	nEb4, $04, nRst, $02, nEb5, $04, nRst, $02, nEb4, $04, nRst, $02
	smpsCall	s3p14_Section00
	dc.b	nE4, $04, nRst, $02, nE4, $04, nRst, $02, nE5, $04, nRst, $02
	dc.b	nE4, $04, nRst, $02, nE5, $04, nRst, $02, nE4, $04, nRst, $02
	dc.b	nE4, $04, nRst, $02, nE5, $04, nRst, $08, nE4, $04, nRst, $02
	dc.b	nE5, $04, nRst, $02, nE4, $04, nRst, $02, nE4, $04, nRst, $02
	dc.b	nE4, $04, nRst, $02, nE5, $04, nRst, $02, nE4, $04, nRst, $02
	smpsCall	s3p14_Section00
	dc.b	nF4, $04, nRst, $02, nF4, $04, nRst, $02, nF5, $04, nRst, $02
	dc.b	nF4, $04, nRst, $02, nF5, $04, nRst, $02, nF4, $04, nRst, $02
	dc.b	nF4, $04, nRst, $02, nF5, $04, nRst, $08, nF4, $04, nRst, $02
	dc.b	nF5, $04, nRst, $02, nF4, $04, nRst, $02, nF4, $04, nRst, $02
	dc.b	nF4, $04, nRst, $02, nF5, $04, nRst, $02, nF4, $04, nRst, $02
	dc.b	nC4, $04, nRst, $02, nC4, $04, nRst, $02, nC5, $04, nRst, $02
	dc.b	nC4, $04, nRst, $02, nC5, $04, nRst, $02, nC4, $04, nRst, $02
	dc.b	nC4, $04, nRst, $02, nC5, $04, nRst, $08, nC4, $04, nRst, $02
	dc.b	nC5, $04, nRst, $02, nC4, $04, nRst, $02, nC4, $04, nRst, $02
	dc.b	nC4, $04, nRst, $02, nC5, $04, nRst, $02, nC4, $04, nRst, $02
	dc.b	nG3, $04, nRst, $02, nG3, $04, nRst, $02, nG4, $04, nRst, $02
	dc.b	nG3, $04, nRst, $02, nG4, $04, nRst, $02, nG3, $04, nRst, $02
	dc.b	nG3, $04, nRst, $02, nG4, $04, nRst, $08, nG3, $04, nRst, $02
	dc.b	nG4, $04, nRst, $02, nG3, $04, nRst, $02, nG3, $04, nRst, $02
	dc.b	nG3, $04, nRst, $02, nG4, $04, nRst, $02, nG3, $04, nRst, $02
	dc.b	nEb2, $06, nF2, nBb2, nEb3, nF3, nBb3, nEb4, nF4, nBb4, nF4, nEb4
	dc.b	nBb3, nF3, nEb3, nBb2, nF2, nEb2, nG2, nBb2, nEb3, nG3, nBb3, nEb4
	dc.b	nG4, nBb4, nG4, nEb4, nBb3, nG3, nEb3, nBb2, nG2, nEb2, nF2, nBb2
	dc.b	nEb3, nF3, nBb3, nEb4, nF4, nBb4, nF4, nEb4, nBb3, nF3, nEb3, nBb2
	dc.b	nF2, nD2, nF2, nBb2, nD3, nF3, nBb3, nD4, nF4, nBb4, nF4, nD4
	dc.b	nBb3, nF3, nD3, nBb2, nF2, nEb2, nF2, nBb2, nEb3, nF3, nBb3, nEb4
	dc.b	nF4, nRst, nCs2, nEb2, nF2, nAb2, nCs3, nEb3, nF3, nC2, nEb2, nAb2
	dc.b	nBb2, nC3, nEb3, nAb3, nC4, nRst, nB1, nEb2, nFs2, nB2, nEb3, nFs3
	dc.b	nB3, nEb4, nRst, nD4, nRst, nBb3, nRst, nC4, nRst, nB3, nRst, nG3
	dc.b	nRst, nG4, nRst, nFs4, nRst, nD4, nRst, nEb4, nRst, nD4, nRst, nBb3
	dc.b	nRst, nAb4, $14, nRst, $04, nG4, $14, nRst, $04, nEb2, $06
	smpsCall	s3p14_Section09
	dc.b	nEb2
	smpsCall	s3p14_Section09
	dc.b	nRst, $02
	smpsReturn

s3p14_Phrase01:
	smpsCall	s3p14_Section0A
	dc.b	nMaxPSG1, nMaxPSG1, $0C, nMaxPSG1, $06, nMaxPSG1, nMaxPSG1, $0C, nMaxPSG1, $06, nMaxPSG1
	dc.b	nMaxPSG1, $0C, nMaxPSG1, $06, nMaxPSG1, nMaxPSG1, $0C
	smpsReturn

s3p14_Phrase02:
	smpsCall	s3p14_Section07
	smpsCall	s3p14_Section07
	dc.b	nD3, $04, nRst, $02, nF3, $04, nRst, $02, nBb3, $04, nRst, $02
	dc.b	nD4, $04, nRst, $02, nF4, $04, nRst, $02, nD4, $04, nRst, $02
	dc.b	nBb3, $04, nRst, $02, nF3, $04, nRst, $08
	smpsReturn

s3p14_Phrase03:
	smpsCall	s3p14_Section08
	smpsCall	s3p14_Section08
	dc.b	nC3, $04, nRst, $02, nEb3, $04, nRst, $02, nAb3, $04, nRst, $02
	dc.b	nC4, $04, nRst, $02, nEb4, $04, nRst, $02, nC4, $04, nRst, $02
	dc.b	nAb3, $04, nRst, $02, nEb3, $04, nRst, $08
	smpsReturn

s3p14_Phrase04:
	dc.b	nD3, $06, nE3, nF3, nG3, nA3, nB3, nD4
	smpsCall	s3p14_Section01
	dc.b	nEb4, $0A, nRst, $02, nEb4, $08, nRst, $04, nF4, $08, nRst, $04
	dc.b	nG4, $08, nRst, $04, nEb4, $20, nRst, $04, nC4, $14, nRst, $04
	smpsCall	s3p14_Section01
	dc.b	nF4, $0A, nRst, $02, nG4, $08, nRst, $04, nF4, $08, nRst, $04
	dc.b	nD4, $08, nRst, $04, nBb3, $38, nRst, $04
	smpsCall	s3p14_Section01
	dc.b	nEb4, $0A, nRst, $02, nEb4, $08, nRst, $04, nF4, $08, nRst, $04
	dc.b	nG4, $08, nRst, $04, nEb4, $20, nRst, $1C, nEb4, $06, nEb4
	dc.b	nD4, $08, nRst, $10, nF4, $06, nF4, nE4, $08, nRst, $10
	dc.b	nG4, $06, nG4, nFs4, $08, nRst, $10, nAb4, $06, nAb4, nG4, $08
	dc.b	nRst, $10, nB4, $14, nRst, $04, nBb4, $14, nRst, $04, nEb4, $7F
	dc.b	smpsNoAttack, $19, nRst, $04, nEb4, nRst, $02, nF4, $04, nRst, $02
	dc.b	nG4, $04, nRst, $02, nF4, $04, nRst, $02, nEb4, $04, nRst, $02
	dc.b	nD4, $04, nRst, $02, nEb4, $20, nRst, $04, nBb3, $08, nRst, $04
	dc.b	nBb3, $2C, nRst, $04, nC4, $08, nRst, $04, nC4, $08, nRst, $04
	dc.b	nD4, $08, nRst, $04, nEb4, $08, nRst, $10, nF4, $18, nRst, $0E
	smpsReturn

s3p14_Phrase05:
	smpsCall	s3p14_Section03
	dc.b	nG3, $04, nRst, $14, nG3, $10, nRst, $02, nC3, $04, nRst, $7A
	dc.b	nBb2, $0A, nRst, $02, nD3, $0A, nRst, $02
	smpsCall	s3p14_Section03
	dc.b	nG3, $52, nRst, $02, nG3, $06, nC3, nD3, $48, nRst, $0C
	dc.b	nG2, $06, nA2
	smpsCall	s3p14_Section04
	dc.b	nF3, $04, nRst, $14, nF3, $10, nRst, $02, nBb2, $04, nRst, $7A
	dc.b	nG2, $0A, nRst, $02, nAb2, $0A, nRst, $02
	smpsCall	s3p14_Section04
	dc.b	nF3, $52, nRst, $02, nF3, $06, nBb2, nC3, $52, nRst, $0E
	smpsReturn

s3p14_Phrase06:
	dc.b	nRst, $16, nF3, $02, nRst, $04, nF3, $02, nRst, $10, nF3, $02
	dc.b	nRst, $04, nF3, $02, nRst, $0A, nF3, $02, nRst, $0A, nF3, $02
	dc.b	nRst, $04, nF3, $02, nRst, $0A, nF3, $02
	smpsReturn

s3p14_Phrase07:
	dc.b	nD4, $02, nRst, $04, nD4, $02, nRst, $10, nD4, $02, nRst, $04
	dc.b	nD4, $02, nRst, $0A, nD4, $02, nRst, $0A, nD4, $02, nRst, $04
	dc.b	nD4, $02, nRst, $0A, nD4, $02, nRst, $16
	smpsReturn

s3p14_Phrase08:
	dc.b	dSnareS3, $06, dSnareS3, dSnareS3, dSnareS3, dKickS3, $18, dSnareS3, $12, dSnareS3, $06, dKickS3
	dc.b	dSnareS3, $12
	smpsCall	s3p14_Section06
	smpsReturn

s3p14_Phrase09:
	dc.b	nF4, $16, nRst, $02, nBb4, $10, nRst, $02, nF4, $04, nRst, $08
	dc.b	nD4, $04, nRst, $02, nF4, $0A, nRst, $02, nA4, $0A, nRst, $02
	dc.b	nF4, $0A, nRst, $02, nBb4, $16, nRst, $02, nA4, $10, nRst, $02
	dc.b	nG4, $04, nRst, $08, nF4, $10, nRst, $02, nF4, $0A, nRst, $02
	dc.b	nG4, $0A, nRst, $02, nA4, $04, nRst, $08, nF4, $04, nRst, $08
	dc.b	nD4, $04, nRst, $08, nF4, $14, nRst, $04, nD4, nRst, $08
	dc.b	nF4, $04, nRst, $08, nG4, $64, nRst, $08, nF4, $16, nRst, $02
	dc.b	nBb4, $10, nRst, $02, nF4, $04, nRst, $08, nF4, $04, nRst, $02
	dc.b	nG4, $0A, nRst, $02, nA4, $0A, nRst, $02, nF4, $0A, nRst, $02
	dc.b	nD5, $16, nRst, $02, nC5, $10, nRst, $02, nBb4, $04, nRst, $08
	dc.b	nF4, $04, nRst, $02, nG4, $04, nRst, $02, nA4, $04, nRst, $02
	dc.b	nBb4, $0A, nRst, $02, nC5, $0A, nRst, $02, nA4, $22, nRst, $02
	dc.b	nG4, $08, nRst, $04, nG4, $64, nRst, $02
	smpsReturn

s3p14_Phrase0A:
	smpsCall	s3p14_Section0C
	dc.b	nG4, $10, nRst, $02, nG4, $04, nRst, $08, nG4, $04, nRst, $08
	smpsReturn

s3p14_Phrase0B:
	smpsCall	s3p14_Section0D
	dc.b	nBb4, $10, nRst, $02, nBb4, $04, nRst, $08, nBb4, $04, nRst, $08
	smpsReturn

s3p14_Phrase0C:
	dc.b	nG3, $02, nRst, $04, nG3, $02, nRst, $10, nG3, $02, nRst, $04
	dc.b	nG3, $02, nRst, $0A, nG3, $02, nRst, $0A, nG3, $02, nRst, $04
	dc.b	nG3, $02, nRst, $0A, nG3, $02
	smpsReturn

s3p14_Phrase0D:
	dc.b	nC4, $02, nRst, $04, nC4, $02, nRst, $10, nC4, $02, nRst, $04
	dc.b	nC4, $02, nRst, $0A, nC4, $02, nRst, $0A, nC4, $02, nRst, $04
	dc.b	nC4, $02, nRst, $0A, nC4, $02
	smpsReturn

s3p14_Phrase0E:
	dc.b	nRst, $08, nC3, $04, nRst, $02, nD3, $04, nRst, $02, nG3, $04
	dc.b	nRst, $02, nD3, $04, nRst, $02, nD3, $04, nRst, $02, nG3, $04
	dc.b	nRst, $02, nC4, $04, nRst, $02, nG3, $04, nRst, $02, nG3, $04
	dc.b	nRst, $02, nC4, $04, nRst, $02, nD4, $04, nRst, $02, nC4, $04
	dc.b	nRst, $02, nC4, $04, nRst, $02, nD4, $04, nRst, $02, nG4, $04
	dc.b	nRst, $02, nD4, $04, nRst, $02, nD3, $04, nRst, $02, nG3, $04
	dc.b	nRst, $02, nB3, $04, nRst, $02, nG3, $04, nRst, $02, nB3, $04
	dc.b	nRst, $02, nD4, $04, nRst, $02, nG4, $04, nRst, $02, nD4, $04
	dc.b	nRst, $08
	smpsReturn

s3p14_Phrase0F:
	dc.b	nRst, $08, nBb2, $04, nRst, $02, nC3, $04, nRst, $02, nF3, $04
	dc.b	nRst, $02, nC3, $04, nRst, $02, nC3, $04, nRst, $02, nF3, $04
	dc.b	nRst, $02, nBb3, $04, nRst, $02, nF3, $04, nRst, $02, nF3, $04
	dc.b	nRst, $02, nBb3, $04, nRst, $02, nC4, $04, nRst, $02, nBb3, $04
	dc.b	nRst, $02, nBb3, $04, nRst, $02, nC4, $04, nRst, $02, nF4, $04
	dc.b	nRst, $02, nC4, $04, nRst, $02, nC3, $04, nRst, $02, nF3, $04
	dc.b	nRst, $02, nA3, $04, nRst, $02, nF3, $04, nRst, $02, nA3, $04
	dc.b	nRst, $02, nC4, $04, nRst, $02, nF4, $04, nRst, $02, nC4, $04
	dc.b	nRst, $08
	smpsReturn

s3p14_Phrase10:
	dc.b	nRst, $14, nBb0, $0A, nRst, $0E, nBb0, $0A, nRst, $14, nBb0, $04
	dc.b	nRst, $02, nBb0, $0A, nRst, $02, nBb0, $04, nRst, $14
	smpsReturn

s3p14_Phrase11:
	dc.b	nEb0, $0A, nRst, $0E, nEb0, $0A, nRst, $14, nEb0, $04, nRst, $02
	dc.b	nEb0, $0A, nRst, $02
	smpsReturn

s3p14_Phrase12:
	smpsCall	s3p14_Section05
	dc.b	nAb0, $0A, nRst, $0E, nAb0, $0A, nRst, $14, nAb0, $04, nRst, $02
	dc.b	nAb0, $0A, nRst, $02, nAb0, $04, nRst, $14
	smpsReturn

s3p14_Phrase13:
	dc.b	nF3, $04, nRst, $02, nF3, $04, nRst, $02, nD3, $04, nRst, $02
	dc.b	nF3, $04, nRst, $14, nD4, $0A, nRst, $02, nF3, $10, nRst, $02
	smpsReturn

s3p14_Phrase14:
	dc.b	nRst, $16, nEb3, $02, nRst, $04, nEb3, $02, nRst, $10, nEb3, $02
	dc.b	nRst, $04, nEb3, $02, nRst, $0A, nEb3, $02, nRst, $0A, nEb3, $02
	dc.b	nRst, $04, nEb3, $02, nRst, $0A, nEb3, $02
	smpsReturn

s3p14_Phrase15:
	dc.b	nE4, $02, nRst, $04, nE4, $02, nRst, $10, nE4, $02, nRst, $04
	dc.b	nE4, $02, nRst, $0A, nE4, $02, nRst, $0A, nE4, $02, nRst, $04
	dc.b	nE4, $02, nRst, $0A, nE4, $02, nRst, $16
	smpsReturn

s3p14_Phrase16:
	dc.b	nBb3, $04, nRst, $02, nBb3, $04, nRst, $02, nF3, $04, nRst, $02
	dc.b	nBb3, $04, nRst, $14, nF4, $0A, nRst, $02, nD4, $10, nRst, $02
	smpsReturn

s3p14_Phrase17:
	dc.b	nAb3, $04, nRst, $02, nAb3, $04, nRst, $02, nEb3, $04, nRst, $08
	dc.b	nAb3, $04, nRst, $02, nAb3, $04, nRst, $02, nEb3, $04, nRst, $0E
	smpsReturn

s3p14_Phrase18:
	dc.b	nC1, $0A, nRst, $0E, nC1, $0A, nRst, $14, nC1, $04, nRst, $02
	dc.b	nC1, $0A, nRst, $02, nC1, $04, nRst, $14
	smpsReturn

s3p14_Phrase19:
	dc.b	nC4, $04, nRst, $02, nC4, $04, nRst, $02, nAb3, $04, nRst, $08
	dc.b	nC4, $04, nRst, $02, nC4, $04, nRst, $02, nAb3, $04, nRst, $0E
	dc.b	nC5, $10, nRst, $02, nC5, $04, nRst, $08, nC5, $04
	smpsReturn

s3p14_Phrase1A:
	dc.b	nA0, $0A, nRst, $0E, nA0, $0A, nRst, $14, nA0, $04, nRst, $02
	dc.b	nA0, $0A, nRst, $02, nA0, $04
	smpsReturn

; Shared sections built from the note phrases above.

s3p14_Section00:
	dc.b	nD4, $04, nRst, $02, nD4, $04, nRst, $02, nD5, $04, nRst, $02
	dc.b	nD4, $04, nRst, $02, nD5, $04, nRst, $02, nD4, $04, nRst, $02
	dc.b	nD4, $04, nRst, $02, nD5, $04, nRst, $08, nD4, $04, nRst, $02
	dc.b	nD5, $04, nRst, $02, nD4, $04, nRst, $02, nD4, $04, nRst, $02
	dc.b	nD4, $04, nRst, $02, nD5, $04, nRst, $02, nD4, $04, nRst, $02
	smpsReturn

s3p14_Section01:
	dc.b	nEb4, $0A, nRst, $0E, nEb4, $10, nRst, $02, nEb4, $04, nRst, $08
	dc.b	nEb4, $04, nRst, $02, nEb4, $0A, nRst, $02, nEb4, $0A, nRst, $02
	smpsReturn

s3p14_Section02:
	dc.b	dSnareS3, $0C, dMidTomS3, $06, dMidTomS3, dKickS3, $18, dSnareS3, $0C, dLowTomS3, $06, dLowTomS3
	dc.b	dKickS3, $18
	smpsCall	s3p14_Phrase08
	smpsReturn

s3p14_Section03:
	dc.b	nC3, $16, nRst, $02, nG3, $10, nRst, $02, nC4, $04, nRst, $08
	dc.b	nG3, $10, nRst, $02, nC4, $04, nRst, $08, nG3, $04, nRst, $08
	dc.b	nBb3, $16, nRst, $02, nA3, $10, nRst, $02, nF3, $04, nRst, $26
	dc.b	nA3, $0A, nRst, $02
	smpsReturn

s3p14_Section04:
	dc.b	nBb2, $16, nRst, $02, nF3, $10, nRst, $02, nBb3, $04, nRst, $08
	dc.b	nF3, $10, nRst, $02, nBb3, $04, nRst, $08, nF3, $04, nRst, $08
	dc.b	nAb3, $16, nRst, $02, nG3, $10, nRst, $02, nEb3, $04, nRst, $26
	dc.b	nG3, $0A, nRst, $02
	smpsReturn

s3p14_Section05:
	dc.b	nG0, $0A, nRst, $0E, nG0, $0A, nRst, $14, nG0, $04, nRst, $02
	dc.b	nG0, $0A, nRst, $02, nG0, $04, nRst, $14
	smpsReturn

s3p14_Section06:
	dc.b	dSnareS3, $18, dKickS3, dSnareS3, dKickS3, dSnareS3, $0C, dSnareS3, $06, dSnareS3, dKickS3, $18
	dc.b	dSnareS3, $12, dSnareS3, $06, dKickS3, dSnareS3, $12
	smpsReturn

s3p14_Section07:
	dc.b	nE3, $04, nRst, $02, nG3, $04, nRst, $02, nA3, $04, nRst, $02
	dc.b	nC4, $04, nRst, $02, nE4, $04, nRst, $02, nC4, $04, nRst, $02
	dc.b	nA3, $04, nRst, $02, nG3, $04, nRst, $02
	smpsReturn

s3p14_Section08:
	dc.b	nD3, $04, nRst, $02, nF3, $04, nRst, $02, nG3, $04, nRst, $02
	dc.b	nBb3, $04, nRst, $02, nD4, $04, nRst, $02, nBb3, $04, nRst, $02
	dc.b	nG3, $04, nRst, $02, nF3, $04, nRst, $02
	smpsReturn

s3p14_Section09:
	dc.b	nF2, nBb2, nEb3, nF3, nBb3, nEb4, nF4, nBb4, nF4, nEb4, nBb3, nF3
	dc.b	nEb3, nBb2, nF2, nEb2, nAb2, nBb2, nEb3, nAb3, nBb3, nEb4, nG4, nBb4
	dc.b	nG4, nEb4, nBb3, nG3, nEb3, nBb2, nG2
	smpsReturn

s3p14_Section0A:
	dc.b	nMaxPSG1, $06, nMaxPSG1, nMaxPSG1, $0C, nMaxPSG1, $06, nMaxPSG1, nMaxPSG1, $0C, nMaxPSG1, $06
	dc.b	nMaxPSG1, nMaxPSG1, $0C, nMaxPSG1, $06
	smpsReturn

s3p14_Section0B:
	dc.b	nMaxPSG1, $06, nMaxPSG1, nMaxPSG1, $0C, nMaxPSG1, nMaxPSG1
	smpsCall	s3p14_Phrase01
	smpsCall	s3p14_Phrase01
	dc.b	nMaxPSG1, $06, nMaxPSG1, nMaxPSG1, $0C, nMaxPSG1, nMaxPSG1
	smpsCall	s3p14_Phrase01
	smpsCall	s3p14_Phrase01
	smpsReturn

s3p14_Section0C:
	dc.b	nG3, $04, nRst, $02, nG3, $04, nRst, $02, nEb3, $04, nRst, $08
	dc.b	nG3, $04, nRst, $02, nG3, $04, nRst, $02, nEb3, $04, nRst, $0E
	smpsReturn

s3p14_Section0D:
	dc.b	nBb3, $04, nRst, $02, nBb3, $04, nRst, $02, nG3, $04, nRst, $08
	dc.b	nBb3, $04, nRst, $02, nBb3, $04, nRst, $02, nG3, $04, nRst, $0E
	smpsReturn

s3p14_Voices:
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

;	Voice $01 (source $03)
;	$34
;	$70, $72, $31, $31, 	$1F, $1F, $1F, $1F, 	$10, $06, $06, $06
;	$01, $06, $06, $06, 	$35, $1A, $15, $1A, 	$10, $80, $18, $80
	smpsVcAlgorithm     $04
	smpsVcFeedback      $06
	smpsVcUnusedBits    $00
	smpsVcDetune        $03, $03, $07, $07
	smpsVcCoarseFreq    $01, $01, $02, $00
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $06, $06, $06, $10
	smpsVcDecayRate2    $06, $06, $06, $01
	smpsVcDecayLevel    $01, $01, $01, $03
	smpsVcReleaseRate   $0A, $05, $0A, $05
	smpsVcTotalLevel    $80, $18, $80, $10

;	Voice $02 (source $04)
;	$3E
;	$77, $71, $32, $31, 	$1F, $1F, $1F, $1F, 	$0D, $06, $00, $00
;	$08, $06, $00, $00, 	$15, $0A, $0A, $0A, 	$1B, $80, $80, $80
	smpsVcAlgorithm     $06
	smpsVcFeedback      $07
	smpsVcUnusedBits    $00
	smpsVcDetune        $03, $03, $07, $07
	smpsVcCoarseFreq    $01, $02, $01, $07
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $00, $00, $06, $0D
	smpsVcDecayRate2    $00, $00, $06, $08
	smpsVcDecayLevel    $00, $00, $00, $01
	smpsVcReleaseRate   $0A, $0A, $0A, $05
	smpsVcTotalLevel    $80, $80, $80, $1B

;	Voice $03 (source $15)
;	$28
;	$71, $00, $30, $01, 	$1F, $1F, $1D, $1F, 	$13, $13, $06, $05
;	$03, $03, $02, $05, 	$4F, $4F, $2F, $3F, 	$0E, $14, $1E, $80
	smpsVcAlgorithm     $00
	smpsVcFeedback      $05
	smpsVcUnusedBits    $00
	smpsVcDetune        $00, $03, $00, $07
	smpsVcCoarseFreq    $01, $00, $00, $01
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1D, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $05, $06, $13, $13
	smpsVcDecayRate2    $05, $02, $03, $03
	smpsVcDecayLevel    $03, $02, $04, $04
	smpsVcReleaseRate   $0F, $0F, $0F, $0F
	smpsVcTotalLevel    $80, $1E, $14, $0E
