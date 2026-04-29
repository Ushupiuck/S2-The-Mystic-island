Round32_Header:
	smpsHeaderStartSong 2, 1
	smpsHeaderVoice     Round32_Voices
	smpsHeaderChan      $06, $03
	smpsHeaderTempo     $02, $C0

	smpsHeaderDAC       Round32_DAC
	smpsHeaderFM        Round32_FM1,	$00, $0C
	smpsHeaderFM        Round32_FM2,	$00, $10
	smpsHeaderFM        Round32_FM3,	$00, $1C
	smpsHeaderFM        Round32_FM4,	$00, $18
	smpsHeaderFM        Round32_FM5,	$00, $12
	smpsHeaderPSG       Round32_PSG1,	$E8, $03, $00, $00
	smpsHeaderPSG       Round32_PSG2,	$E8, $05, $00, $00
	smpsHeaderPSG       Round32_PSG3,	$00, $01, $00, fTone_02

; FM1 Data
Round32_FM1:
	dc.b	nRst, $06
	smpsDetune          $0C
	smpsModSet          $01, $02, $0F, $02
	smpsSetvoice        $00
	dc.b	nAb1, $28, nAb1, $04, nAb1, nB1, $28, nB1, $04, nB1, nCs2, $28
	dc.b	nCs2, $04, nCs2, nEb2, $1C, nCs2, $04, nEb2, nEb2, nBb1, nEb2, nAb1
	dc.b	$28, nAb1, $04, nAb1, nB1, $28, nB1, $04, nB1, nCs2, $28, nAb1
	dc.b	$04, nCs2, nEb2, $20, nEb1, $08, nEb2

Round32_Loop11:
	dc.b	nAb1, $04, nAb1, nAb1, nAb1, nAb1, nAb1, nRst, nAb1, nAb1, nAb1, nAb1
	dc.b	nAb1
	smpsLoop            $00, $0C, Round32_Loop11
	dc.b	nE1, nE1, nE1, nE1, nE1, nE1, nRst, nE1, nE1, nE1, nE1, nE1
	dc.b	nF1, nF1, nF1, nF1, nF1, nF1, nRst, nF1, nF1, nF1, nF1, nF1
	dc.b	nE1, nE1, nE1, nE1, nE1, nE1, nRst, nE1, nE1, nE1, nE1, nE1
	dc.b	nCs2, nCs2, nCs2, nCs2, nCs2, nCs2, nRst, nCs2, nCs2, nCs2, nCs2, nCs2
	dc.b	nE1, nE1, nE1, nE1, nE1, nE1, nRst, nE1, nE1, nE1, nE1, nE1
	dc.b	nF1, nF1, nF1, nF1, nF1, nF1, nRst, nF1, nF1, nF1, nF1, nF1
	dc.b	nCs2, nCs2, nCs2, nCs2, nCs2, nCs2, nRst, nCs2, nCs2, nCs2, nCs2, nCs2
	dc.b	nEb2, nEb2, nEb2, nEb2, nEb2, nEb2, nRst, nEb2, nEb2, nEb2, nEb1, nEb2
	dc.b	nRst, $10, nFs1, $04, nFs1, nFs1, $08, nFs1, $04, nRst, $0C, nRst
	dc.b	$10, nFs1, $04, nFs1, nFs1, $08, nFs1, nFs1, nRst, $10, nAb1, $04
	dc.b	nAb1, nAb1, $08, nAb1, $04, nRst, $0C, nRst, $10, nAb1, $04, nAb1
	dc.b	nAb1, $08, nAb1, nAb1, nRst, $10, nFs1, $04, nFs1, nFs1, $08, nFs1
	dc.b	$04, nRst, $0C, nRst, $10, nFs1, $04, nFs1, nFs1, $08, nFs1, nFs1
	dc.b	nE1, $08, nE1, $04, nE1, nE1, nE1, nRst, nE1, nE1, nE1, nE1
	dc.b	nE1, nEb2, $08, nEb2, $04, nEb2, nEb2, nEb2, nEb1, nCs2, nEb1, nEb2
	dc.b	nEb1, nEb2
	smpsAlterVol        $FC
	dc.b	nFs1, $10, nFs1, $02, nFs1, nFs1, $04, nFs1, nFs1, nFs1, nFs1, nFs1
	dc.b	nFs1, nFs1, $08, nCs2, nC2, nFs1, nEb1, nFs1, nAb1, $10, nAb1, $02
	dc.b	nAb1, nAb1, $04, nAb1, nAb1, nAb1, nAb1, nAb1, nAb1, nAb1, $08, nFs2
	dc.b	nF2, nEb2, nC2, nAb1, nFs1, $10, nFs1, $02, nFs1, nFs1, $04, nFs1
	dc.b	nFs1, nFs1, nFs1, nFs1, nFs1, nFs1, $08, nCs2, nC2, nFs1, nEb1, nFs1
	smpsAlterVol        $04
	smpsAlterVol        $07
	smpsDetune          $0D
	dc.b	nB2, $06, nB1, $02, nB1, $04, nB2, nB1, nB2, nB1, $08, nB2
	dc.b	nB1
	smpsAlterVol        $F9
	smpsModSet          $01, $01, $01, $01
	smpsAlterVol        $FC
	dc.b	nCs1, $06, nCs1, $02, nCs1, $04, nCs2, $04, nCs1, nCs1
	smpsDetune          $15
	dc.b	nEb2, $06, nEb1, $02, nEb1, $04, nEb2, $04, nEb1, nEb2
	smpsAlterVol        $04
	dc.b	nRst, $18
	smpsDetune          $0C
	smpsModSet          $01, $02, $0F, $02
	smpsJump            Round32_Loop11

; FM2 Data
Round32_FM2:
	dc.b	nRst, $06
	smpsDetune          $05

Round32_Jump02:
	smpsModSet          $01, $0F, $0A, $03
	smpsSetvoice        $13
	smpsAlterVol        $FA
	dc.b	nEb4, $06, nEb4, $02, nEb4, $04, nAb4, nEb4, nBb4, nEb4, nCs5, nEb4
	dc.b	nC5, nEb4, nEb5, nEb4, $06, nEb4, $02, nEb4, $04, nAb4, nEb4, nBb4
	dc.b	nEb4, nCs5, nEb4, nC5, nEb4, nEb5, nEb4, $06, nEb4, $02, nEb4, $04
	dc.b	nAb4, nEb4, nBb4, nEb4, nCs5, nEb4, nC5, nAb4, nEb4, $08, nC4, $02
	dc.b	nCs4, nEb4, $04, nAb4, $10, nFs4, $04, nAb4, nBb4, nFs4, nFs5
	smpsChangeTransposition $0C
	smpsAlterVol        $03
	smpsSetvoice        $14
	dc.b	nEb4, $06, nEb4, $02, nEb4, $04, nAb4, nEb4, nBb4, nEb4, nCs5, nEb4
	dc.b	nC5, nEb4, nEb5, nEb4, $06, nEb4, $02, nEb4, $04, nAb4, nEb4, nBb4
	dc.b	nEb4, nCs5, nEb4, nC5, nEb4, nEb5, nEb4, $06, nEb4, $02, nEb4, $04
	dc.b	nAb4, nEb4, nBb4, nEb4, nCs5, nEb4, nC5, nAb4, nEb4, $08, nC4, $02
	dc.b	nCs4, nEb4, $04, nAb4, $10, nFs4, $04, nAb4, nBb4, nFs4, nAb4
	smpsAlterVol        $FD
	smpsChangeTransposition $F4
	smpsAlterVol        $06

Round32_Jump03:
	smpsModOff
	smpsSetvoice        $0F
	dc.b	nAb5, $0C
	smpsSetvoice        $17
	dc.b	nFs3, $02, nF3, nE3, nF3, nE3, nEb3, nE3, nEb3, nD3, nRst, $06
	smpsModSet          $24, $04, $F8, $CD
	smpsSetvoice        $0F
	dc.b	nFs5, $24
	smpsModOff
	dc.b	nF5, $04, nFs5, nF5, $10, nAb5, $0C
	smpsSetvoice        $17
	dc.b	nFs3, $02, nF3, nE3, nF3, nE3, nEb3, nE3, nEb3, nD3, nRst, $06
	smpsModSet          $24, $04, $F8, $CD
	smpsSetvoice        $0F
	dc.b	nFs5, $24
	smpsModOff
	dc.b	nF5, $04, nFs5, nAb5, nBb5, nB5, nFs6
	smpsModSet          $43, $01, $1C, $03
	smpsAlterVol        $FF
	smpsChangeTransposition $0C
	dc.b	nEb3, $06, nBb2, $02, nEb3, $04, nAb3, $1C, nG3, $04, nAb3, nG3
	dc.b	$20, nEb3, $08, nBb2, nCs3, $08, nC3, $02, nCs3, $04
	smpsModSet          $43, $02, $10, $02
	dc.b	nAb3, $48, nRst, $0A
	smpsModSet          $43, $01, $1C, $03
	dc.b	nE3, $06, nB2, $02, nE3, $04, nB3, $1C, nBb3, $04, nAb3, nFs3
	dc.b	$18, nE3, $08, nFs3, nBb3, nAb3, $06, nG3, $02, nAb3, $04
	smpsModSet          $43, $02, $10, $02
	dc.b	nEb3, $48
	smpsChangeTransposition $F4
	smpsAlterVol        $01
	smpsModSet          $43, $01, $1C, $03
	smpsSetvoice        $14
	smpsAlterVol        $FD
	smpsChangeTransposition $0C
	dc.b	nEb3, $04, nAb3, nEb4, nEb4, $10, nCs4, $04, nEb4, nAb3, $10, nEb3
	dc.b	$04, nCs4, nCs4, $10, nC4, $04, nBb3, nAb3, $08, nEb3, $04, nRst
	dc.b	nEb3, nAb3, $0A, nAb2, $02, nAb3, $04, nFs3, $20, nFs3, $04, nFs3
	dc.b	nF3, nCs3, nAb2, $18
	smpsChangeTransposition $F4
	smpsAlterVol        $03
	smpsAlterVol        $FF
	smpsSetvoice        $0F
	dc.b	nEb4, $04, nAb4, nEb5, nEb5, $10, nCs5, $04, nEb5, nAb4, $10, nAb4
	dc.b	$04, nEb5, nFs5, $10, nF5, $04, nFs5, nF5, $08, nCs5, nAb4, $0E
	dc.b	nAb3, $02, nAb4, $04, nG4, $1C, nAb3, $04, nG4, nAb4, $10, nCs4
	dc.b	$04, nAb4, nBb4, $18
	smpsAlterVol        $01
	smpsAlterVol        $FD
	smpsSetvoice        $19
	dc.b	nCs4, $04, nCs4, nCs4, nC4, $18, nCs4, $04, nC4, nC4, nEb4, $10
	dc.b	nCs4, $04, nC4, nC4, $08, nAb3, nEb3, nCs4, $04, nCs4, nCs4, nC4
	dc.b	$18, nAb3, $04, nCs4, nEb4, nAb4, $10, nG4, $04, nAb4, nBb4, $08
	dc.b	nG4, nEb4, nCs4, $04, nCs4, nCs4, nC4, $18, nCs4, $04, nC4, nC4
	dc.b	nEb4, $10, nCs4, $04, nC4, nC4, $08, nAb3, nEb3, nEb3, $06, nEb3
	dc.b	$02, nEb3, $04, nAb3, nEb3, nBb3, nEb4, $06, nEb4, $02, nEb4, $04
	dc.b	nAb4, nEb4, nEb5, nEb5, $06, nEb5, $02, nEb5, $04, nEb5, nEb5, nEb5
	dc.b	nEb5, $08, nEb5, nEb5
	smpsModSet          $3F, $02, $10, $03
	smpsAlterVol        $FF
	smpsSetvoice        $0F
	dc.b	nEb3, $04, nAb3, nBb3, nCs4, $1C, nC4, $04, nCs4, nC4, $08, nAb3
	dc.b	nEb3, $20, nEb3, $04, nAb3, nBb3, nFs4, $1C, nF4, $04, nFs4, nF4
	dc.b	$08, nCs4, nC4, nC4, nBb3, nEb4, $0C, nCs4, $04, nC4, nBb3, $18
	dc.b	nEb3, $04, nAb3, nBb3, nC4, nCs4, nBb3, nC4, nAb3, nEb4, $0C, nAb3
	dc.b	$08, nAb4, $18, nFs4, $04, nF4, nEb4, $10, nAb3, $04, nEb4, nFs4
	dc.b	$18, nAb4
	smpsAlterVol        $01
	smpsAlterVol        $03
	smpsSetvoice        $01
	smpsAlterVol        $48

Round32_Loop10:
	smpsAlterVol        $FA
	dc.b	nEb5, $02
	smpsLoop            $00, $0C, Round32_Loop10
	smpsJump            Round32_Jump03

; FM3 Data
Round32_FM3:
	dc.b	nRst, $06
	smpsDetune          $07
	dc.b	nRst, $07
	smpsAlterVol        $FD
	smpsJump            Round32_Jump02

; FM4 Data
Round32_FM4:
	dc.b	nRst, $06
	smpsDetune          $07
	smpsModSet          $01, $02, $03, $04
	smpsSetvoice        $07
	dc.b	nEb4, $06, nEb4, $02, nEb4, $04, nAb4, nEb4, nBb4, nEb4, nCs5, nEb4
	dc.b	nC5, nEb4, nEb5, nEb4, $06, nEb4, $02, nEb4, $04, nAb4, nEb4, nBb4
	dc.b	nEb4, nCs5, nEb4, nC5, nEb4, nEb5, nEb4, $06, nEb4, $02, nEb4, $04
	dc.b	nAb4, nEb4, nBb4, nEb4, nCs5, nEb4, nC5, nAb4, nEb4, $08, nC4, $02
	dc.b	nCs4, nEb4, $04, nAb4, $10, nFs4, $04, nAb4, nBb4, nFs4, nFs5
	smpsChangeTransposition $F4
	smpsAlterVol        $F8
	smpsSetvoice        $0F
	dc.b	nEb4, $06, nEb4, $02, nEb4, $04, nAb4, nEb4, nBb4, nEb4, nCs5, nEb4
	dc.b	nC5, nEb4, nEb5, nEb4, $06, nEb4, $02, nEb4, $04, nAb4, nEb4, nBb4
	dc.b	nEb4, nCs5, nEb4, nC5, nEb4, nEb5, nEb4, $06, nEb4, $02, nEb4, $04
	dc.b	nAb4, nEb4, nBb4, nEb4, nCs5, nEb4, nC5, nAb4, nEb4, $08, nC4, $02
	dc.b	nCs4, nEb4, $04, nAb4, $10, nFs4, $04, nAb4, nBb4, nFs4, nAb4
	smpsChangeTransposition $0C
	smpsAlterVol        $08

Round32_Jump01:
	smpsModOff
	smpsSetvoice        $0F
	dc.b	nEb5, $0C
	smpsSetvoice        $0C
	dc.b	nFs3, $02, nF3, nE3, nF3, nE3, nEb3, nE3, nEb3, nD3, nRst, $06
	smpsModSet          $27, $04, $F8, $CD
	smpsSetvoice        $0F
	dc.b	nB4, $24
	smpsModOff
	dc.b	nD5, $04, nEb5, nD5, $10, nEb5, $0C
	smpsSetvoice        $0C
	dc.b	nFs3, $02, nF3, nE3, nF3, nE3, nEb3, nE3, nEb3, nD3, nRst, $06
	smpsModSet          $27, $04, $F8, $CD
	smpsSetvoice        $0F
	dc.b	nB4, $24
	smpsModOff
	dc.b	nD5, $04, nEb5, nF5, nFs5, nAb5, nC6
	smpsModSet          $01, $02, $07, $02
	smpsSetvoice        $0C
	smpsAlterVol        $02
	smpsChangeTransposition $0C

Round32_Loop0C:
	dc.b	nEb3, $04, nRst, $02, nEb3, nEb3, $04, nEb3, nEb3, nEb3, nRst, nEb3
	dc.b	nEb3, nEb3, nEb3, nEb3
	smpsLoop            $00, $04, Round32_Loop0C

Round32_Loop0D:
	dc.b	nE3, $04, nRst, $02, nE3, nE3, $04, nE3, nE3, nE3, nRst, nE3
	dc.b	nE3, nE3, nE3, nE3
	smpsLoop            $00, $02, Round32_Loop0D

Round32_Loop0E:
	dc.b	nEb3, $04, nRst, $02, nEb3, nEb3, $04, nEb3, nEb3, nEb3, nRst, nEb3
	dc.b	nEb3, nEb3, nEb3, nEb3
	smpsLoop            $00, $02, Round32_Loop0E
	smpsChangeTransposition $F4
	smpsAlterVol        $FE
	smpsAlterVol        $FF
	smpsSetvoice        $0F
	dc.b	nAb3, $10, nEb3, $04, nAb3, nEb4, $18, nRst, $0C, nRst, $04, nCs4
	dc.b	nEb4, nAb4, $08, nFs4, nEb4, $18, nCs4, $04, nEb4, nAb3, $1C, nCs4
	dc.b	$04, nFs4, nAb3, $18, nRst, $0C
	smpsAlterVol        $01
	smpsSetvoice        $0C
	dc.b	nAb3, $10, nEb3, $04, nAb3, nEb4, $08, nCs4, nB3, nBb3, $10, nA3
	dc.b	$04, nBb3, nC4, $08, nF3, nF4, nCs4, $04, nAb3, nCs4, nEb4, $18
	dc.b	nCs4, $04, nAb3, nCs4, nF4, nAb3, nF4, nG4, $10, nAb3, $04, nG4
	dc.b	nAb4, nCs4, nBb4
	smpsSetvoice        $0F
	smpsAlterVol        $FA
	dc.b	nBb3, $04, nBb3, nBb3, nAb3, $18, nBb3, $04, nAb3, nAb3, nC4, $10
	dc.b	nBb3, $04, nAb3, nAb3, $08, nEb3, nC3, nBb3, $04, nBb3, nBb3, nAb3
	dc.b	$18, nEb3, $04, nAb3, nC4, nEb4, $10, nCs4, $04, nEb4, nG4, $08
	dc.b	nEb4, nBb3, nBb3, $04, nBb3, nBb3, nAb3, $18, nBb3, $04, nAb3, nAb3
	dc.b	nC4, $10, nBb3, $04, nAb3, nAb3, $08, nEb3, nC3, nEb3, $06, nEb3
	dc.b	$02, nEb3, $04, nAb3, nEb3, nBb3
	smpsAlterVol        $06
	smpsAlterVol        $FC
	dc.b	nEb4, $06, nEb4, $02, nEb4, $04, nAb4, nEb4, nEb5
	smpsAlterVol        $04
	smpsAlterVol        $FD
	dc.b	nAb4, $06, nAb4, $02, nAb4, $04, nAb4, nAb4, nAb4, nG4, $08, nG4
	dc.b	nG4
	smpsAlterVol        $03
	smpsModSet          $37, $02, $10, $03
	smpsSetvoice        $15
	smpsAlterVol        $F6
	dc.b	nFs2, $58, nFs2, $04, nFs2, nAb2, $38, nFs3, $08, nF3, nEb3, nC3
	dc.b	nAb2, nFs2, $28, nFs2, $04, nFs2, nFs2, $30, nB2, nCs3, $10, nAb3
	dc.b	$04, nCs3, nEb3, $18
	smpsAlterVol        $0A
	smpsSetvoice        $01
	smpsAlterVol        $48

Round32_Loop0F:
	smpsAlterVol        $FA
	dc.b	nEb5, $02
	smpsLoop            $00, $0C, Round32_Loop0F
	smpsJump            Round32_Jump01

; FM5 Data
Round32_FM5:
	dc.b	nRst, $06
	smpsDetune          $0C
	smpsModSet          $01, $02, $03, $04
	smpsAlterVol        $FD
	smpsSetvoice        $09

Round32_Loop04:
	dc.b	nAb2, $28, nAb2, $04, nAb2, nB2, $28, nB2, $04, nB2, nCs3, $28
	dc.b	nCs3, $04, nCs3, nEb3, $30
	smpsLoop            $00, $02, Round32_Loop04
	smpsAlterVol        $03

Round32_Jump00:
	smpsChangeTransposition $F4
	smpsAlterVol        $FE
	smpsSetvoice        $0F
	dc.b	nC5, $0C
	smpsSetvoice        $12
	smpsAlterVol        $48

Round32_Loop05:
	smpsAlterVol        $FA
	dc.b	nFs5, $02
	smpsLoop            $00, $0C, Round32_Loop05
	smpsSetvoice        $0F
	dc.b	nEb5, $24, nF4, $04, nFs4, nF4, $10, nC5, $0C
	smpsSetvoice        $12
	smpsAlterVol        $48

Round32_Loop06:
	smpsAlterVol        $FA
	dc.b	nFs5, $02
	smpsLoop            $00, $0C, Round32_Loop06
	smpsSetvoice        $0F
	dc.b	nEb5, $24, nF4, $04, nFs4, nAb4, nBb4, nB4, nFs5
	smpsAlterVol        $02
	smpsChangeTransposition $0C
	smpsSetvoice        $19
	smpsAlterVol        $02
	dc.b	nEb3, $04, nRst, $02, nEb3, nEb3, $04, nEb3, $1C, nCs3, $04, nEb3
	dc.b	nEb3, $04, nRst, $02, nBb2, nEb3, $04, nEb3, $14, nBb2, $08, nEb3
	dc.b	nCs3, $0C, nF3, $30, nRst, $04, nCs3, nF3, nAb3, $08, nG3, nF3
	dc.b	nE3, $06, nRst, $03, nB2, $1F, nCs3, $04, nEb3, nE3, $18, nB2
	dc.b	$08, nE3, nAb3, nC3, $04, nRst, $02, nB2, nC3, $04, nC3, $1C
	dc.b	nC3, $04, nCs3, nEb3, $08, nAb3, nG3, nG3, nEb3, nBb2
	smpsAlterVol        $FE
	smpsSetvoice        $0A
	smpsAlterVol        $09
	dc.b	nEb4, $10, nCs4, $04, nEb4, nAb3, $10, nEb3, $04, nCs4, nCs4, $10
	dc.b	nC4, $04, nBb3, nAb3, $08, nEb3, $04, nRst, nEb3, nAb3, $0A, nAb2
	dc.b	$02, nAb3, $04, nFs3, $20, nFs3, $04, nFs3, nF3, nCs3, nAb2, $0C
	smpsAlterVol        $F7
	smpsSetvoice        $08
	dc.b	nRst, $04, nCs4, nFs4, nAb4, nCs5, nCs6
	smpsSetvoice        $17
	smpsAlterVol        $07
	smpsChangeTransposition $F4
	dc.b	nEb5, $10, nCs5, $04, nEb5, nAb4, $10, nAb4, $04, nEb5, nFs5, $10
	dc.b	nF5, $04, nFs5, nF5, $08, nCs5, nAb4, $0E, nAb3, $02, nAb4, $04
	dc.b	nG4, $1C, nAb3, $04, nG4
	smpsChangeTransposition $0C
	smpsAlterVol        $F9
	smpsSetvoice        $0F
	dc.b	nCs6, $14, nCs6, $04, nEb6, $18
	smpsSetvoice        $08
	smpsAlterVol        $02

Round32_Loop08:
	dc.b	nRst, $0C

Round32_Loop07:
	dc.b	nC7, $02, nCs7
	smpsLoop            $00, $09, Round32_Loop07
	dc.b	nRst, $30
	smpsLoop            $01, $03, Round32_Loop08
	smpsAlterVol        $FE
	dc.b	nRst, $30
	smpsSetvoice        $0F
	dc.b	nCs7, $06, nCs7, $02, nCs7, $04, nCs7, nCs7, nCs7, nBb6, $08, nBb6
	dc.b	nBb6, nRst, $30
	smpsSetvoice        $01
	dc.b	nRst, $18
	smpsAlterVol        $48

Round32_Loop09:
	smpsAlterVol        $FA
	dc.b	nEb5, $02
	smpsLoop            $00, $0C, Round32_Loop09
	dc.b	nRst, $30, nRst, nRst, $30, nRst, $18
	smpsAlterVol        $48

Round32_Loop0A:
	smpsAlterVol        $FA
	dc.b	nEb5, $02
	smpsLoop            $00, $0C, Round32_Loop0A
	dc.b	nRst, $30, nRst
	smpsSetvoice        $01
	smpsAlterVol        $48

Round32_Loop0B:
	smpsAlterVol        $FA
	dc.b	nEb5, $02
	smpsLoop            $00, $0C, Round32_Loop0B
	smpsJump            Round32_Jump00

; PSG1 Data
Round32_PSG1:
	dc.b	nRst, $06
	smpsDetune          $00

Round32_Jump05:
	smpsModSet          $0F, $01, $EB, $03

Round32_Loop12:
	dc.b	nAb2, $28, nAb2, $04, nAb2, nB2, $28, nB2, $04, nB2, nCs3, $28
	dc.b	nCs3, $04, nCs3, nEb3, $30
	smpsLoop            $00, $02, Round32_Loop12

Round32_Jump06:
	smpsModSet          $0F, $01, $0B, $FF
	dc.b	nRst, $24, nEb3, $3C, nRst, $24, nEb3, $3C
	smpsModSet          $01, $02, $03, $02
	smpsPSGAlterVol     $01
	dc.b	nEb3, $04, nRst, $02, nEb3, nEb3, $04, nEb3, $1C, nCs3, $04, nEb3
	dc.b	nEb3, $04, nRst, $02, nBb2, nEb3, $04, nEb3, $14, nBb2, $08, nEb3
	dc.b	nCs3, $0C, nF3, $30, nRst, $04, nCs3, nF3, nAb3, $08, nG3, nF3
	dc.b	nE3, $06, nRst, $03, nB2, $1F, nCs3, $04, nEb3, nE3, $18, nB2
	dc.b	$08, nE3, nAb3, nC3, $04, nRst, $02, nB2, nC3, $04, nC3, $1C
	dc.b	nC3, $04, nCs3, nEb3, $08, nAb3, nG3, nG3, nEb3, nBb2, nAb3, $10
	dc.b	nEb3, $04, nAb3, nEb4, $18, nRst, $0C, nRst, $04, nCs4, nEb4, nAb4
	dc.b	$08, nFs4, nEb4, $18, nCs4, $04, nEb4, nAb3, $1C, nCs4, $04, nFs4
	dc.b	nAb3, $18, nRst, $0C, nAb3, $10, nEb3, $04, nAb3, nEb4, $08, nCs4
	dc.b	nB3, nBb3, $10, nA3, $04, nBb3, nC4, $08, nF3, nF4, nCs4, $04
	dc.b	nAb3, nCs4, nEb4, $18, nCs4, $04, nAb3, nCs4, nCs4, $18, nEb4, nFs3
	dc.b	$04, nFs3, nFs3

Round32_Loop13:
	dc.b	nC5, $02, nCs5
	smpsLoop            $00, $09, Round32_Loop13
	dc.b	nAb3, $10, nFs3, $04, nEb3, nEb3, $08, nC3, nAb2, nFs3, $04, nFs3
	dc.b	nFs3

Round32_Loop14:
	dc.b	nC5, $02, nCs5
	smpsLoop            $00, $09, Round32_Loop14
	dc.b	nC4, $10, nBb3, $04, nC4, nEb4, $08, nBb3, nG3, nFs3, $04, nFs3
	dc.b	nFs3

Round32_Loop15:
	dc.b	nC5, $02, nCs5
	smpsLoop            $00, $09, Round32_Loop15
	dc.b	nAb3, $10, nFs3, $04, nEb3, nEb3, $08, nC3, nAb2
	smpsModSet          $01, $01, $01, $01
	dc.b	nRst, $30, nCs5, $06, nCs5, $02, nCs5, $04, nCs5, nCs5, nCs5, nG4
	dc.b	$08, nG4, nG4
	smpsPSGAlterVol     $FF
	smpsModSet          $0F, $01, $0B, $FF
	dc.b	nRst, $30, nEb3, nRst, $30, nRst, nRst, $30, nEb3
	smpsModSet          $01, $02, $03, $02
	dc.b	nB2, $30, nCs3, $18
	smpsModSet          $0F, $01, $0B, $FF
	dc.b	nEb3, $24, nRst, $0C
	smpsJump            Round32_Jump06

; PSG2 Data
Round32_PSG2:
	dc.b	nRst, $06
	smpsDetune          $01
	dc.b	nRst, $05
	smpsJump            Round32_Jump05

; PSG3 Data
Round32_PSG3:
	smpsPSGform         $E7
	dc.b	nRst, $06

Round32_Jump04:
	smpsNoteFill        $02
	dc.b	nMaxPSG, $04, nMaxPSG, nMaxPSG, nMaxPSG, nMaxPSG, nMaxPSG, nMaxPSG, nMaxPSG, nMaxPSG, nMaxPSG, nMaxPSG
	smpsNoteFill        $00
	dc.b	nMaxPSG
	smpsJump            Round32_Jump04

; DAC Data
Round32_DAC:
	dc.b	nRst, $06, dMidClap, $06, dSnare, $02, dSnare, $04, dSnare, dSnare, dSnare, dKick
	dc.b	dVLowTimpani, dSnare, dLowTimpani, dMidClap, dMidClap, dMidClap, $06, dSnare, $02, dSnare, $04, dSnare
	dc.b	dSnare, dSnare, dSnare, dMidTimpani, dLowTimpani, dVLowTimpani, dLowTimpani, dVLowTimpani, dMidClap, $06, dSnare, $02
	dc.b	dSnare, $04, dSnare, dSnare, dScratch, dMidTimpani, dKick, dVLowTimpani, dSnare, dMidClap, dMidClap, dMidClap
	dc.b	dSnare, dSnare, dSnare, dKick, dVLowTimpani, dVLowTimpani, dSnare, dLowTimpani, dVLowTimpani, dSnare, dKick

Round32_Loop00:
	dc.b	dMidClap, $06, dSnare, $02, dSnare, $04, dMidClap, dMidClap, dMidClap, nRst, dMidClap, dMidClap
	dc.b	dSnare, dMidClap, dMidClap
	smpsLoop            $00, $04, Round32_Loop00

Round32_Loop01:
	dc.b	dMidClap, $06, dSnare, $02, dSnare, $04, dSnare, dSnare, dSnare, nRst, dSnare, dSnare
	dc.b	dSnare, dMidClap, dMidClap, dMidClap, dSnare, $02, dSnare, dSnare, $04, dSnare, dSnare, dSnare
	dc.b	nRst, dSnare, dSnare, dSnare, dMidClap, $02, dSnare, dMidClap, dSnare
	smpsLoop            $00, $02, Round32_Loop01

Round32_Loop02:
	dc.b	dSnare, $06, dSnare, $02, dSnare, $04, dSnare, dSnare, dSnare, nRst, dSnare, dSnare
	dc.b	dSnare, dSnare, dSnare, dSnare, dSnare, $02, dSnare, dSnare, $04, dSnare, dSnare, dSnare
	dc.b	nRst, dSnare, dSnare, dSnare, dSnare, $02, dSnare, dSnare, $04
	smpsLoop            $00, $04, Round32_Loop02

Round32_Loop03:
	dc.b	dSnare, $06, dSnare, $02, dSnare, $04, dSnare, dSnare, dSnare, dKick, dSnare, dSnare
	dc.b	dSnare, dVLowTimpani, dSnare, dSnare, $06, dSnare, $02, dSnare, $04, dSnare, dSnare, dSnare
	dc.b	dKick, dSnare, dSnare, dSnare, dLowTimpani, dScratch, dSnare, $06, dSnare, $02, dSnare, $04
	dc.b	dSnare, dSnare, dSnare, dKick, dSnare, dSnare, dSnare, dKick, dVLowTimpani, dSnare, $06, dSnare
	dc.b	$02, dSnare, $04, dSnare, dSnare, dSnare, dKick, dSnare, dSnare, dSnare, dScratch, dVLowTimpani
	smpsLoop            $00, $02, Round32_Loop03
	dc.b	dHiClap, $04, nRst, dKick, $02, dKick, dSnare, $04, dSnare, dSnare, dKick, dSnare
	dc.b	dSnare, dVLowTimpani, dKick, dSnare, dHiClap, $0C, dSnare, $04, dSnare, dSnare, dSnare, dKick
	dc.b	dKick, dSnare, dHiClap, dHiClap, dMidClap, nRst, dKick, $02, dKick, dSnare, $04, dSnare
	dc.b	dSnare, dSnare, dSnare, dKick, dLowTimpani, dVLowTimpani, dSnare, dMidClap, $0C, dSnare, $04, dSnare
	dc.b	dSnare, dMidTimpani, dLowTimpani, dVLowTimpani, dKick, dMidClap, dMidClap, dHiClap, nRst, dKick, $02, dKick
	dc.b	dSnare, $04, dSnare, dSnare, dSnare, dKick, dSnare, dScratch, dHiClap, dHiClap, dHiClap, $0C
	dc.b	dSnare, $04, dSnare, dVLowTimpani, dLowTimpani, dKick, dVLowTimpani, dSnare, dHiClap, dHiClap, dSnare, dSnare
	dc.b	dSnare, dSnare, dSnare, dSnare, dSnare, $06, dSnare, $02, dSnare, dSnare, dSnare, $04
	dc.b	dSnare, dVLowTimpani, dScratch, dSnare, dSnare, dMidTimpani, dLowTimpani, dSnare, dLowTimpani, dScratch, dKick, dLowTimpani
	dc.b	dSnare, dVLowTimpani, dHiClap, $04, dSnare, $02, dSnare, dSnare, dSnare, dHiClap, $04
	smpsPan             panRight, $00
	dc.b	dLowTom, dLowTom
	smpsPan             panCenter, $00
	dc.b	dHiClap
	smpsPan             panRight, $00
	dc.b	dLowTom, dLowTom
	smpsPan             panCenter, $00
	dc.b	dHiClap
	smpsPan             panRight, $00
	dc.b	dLowTom
	smpsPan             panCenter, $00
	dc.b	dHiClap, dVLowTimpani, $0C, dHiClap, $04
	smpsPan             panRight, $00
	dc.b	dLowTom, dLowTom
	smpsPan             panCenter, $00
	dc.b	dHiClap
	smpsPan             panRight, $00
	dc.b	dLowTom, dLowTom
	smpsPan             panCenter, $00
	dc.b	dHiClap
	smpsPan             panRight, $00
	dc.b	dLowTom
	smpsPan             panCenter, $00
	dc.b	dHiClap, dSnare, $02, dSnare, dSnare, dSnare, dSnare, dSnare
	smpsPan             panCenter, $00
	dc.b	dMidClap, $04
	smpsPan             panRight, $00
	dc.b	dLowTom
	smpsPan             panCenter, $00
	dc.b	dMidClap, dMidClap
	smpsPan             panRight, $00
	dc.b	dLowTom
	smpsPan             panRight, $00
	dc.b	dLowTom
	smpsPan             panCenter, $00
	dc.b	dMidClap
	smpsPan             panRight, $00
	dc.b	dLowTom
	smpsPan             panCenter, $00
	dc.b	dMidClap, dVLowTimpani, dKick, dSnare
	smpsPan             panCenter, $00
	dc.b	dMidClap
	smpsPan             panRight, $00
	dc.b	dLowTom, dLowTom
	smpsPan             panCenter, $00
	dc.b	dMidClap
	smpsPan             panRight, $00
	dc.b	dLowTom, dLowTom
	smpsPan             panCenter, $00
	dc.b	dMidClap
	smpsPan             panRight, $00
	dc.b	dLowTom
	smpsPan             panCenter, $00
	dc.b	dMidClap, dSnare, $02, dSnare, dSnare, dKick, dKick, dSnare, dHiClap, $04
	smpsPan             panRight, $00
	dc.b	dLowTom, $02, dLowTom
	smpsPan             panCenter, $00
	dc.b	dHiClap, $04, dHiClap
	smpsPan             panRight, $00
	dc.b	dLowTom, dLowTom
	smpsPan             panCenter, $00
	dc.b	dHiClap
	smpsPan             panRight, $00
	dc.b	dLowTom
	smpsPan             panCenter, $00
	dc.b	dHiClap, dVLowTimpani, $02, dSnare, dKick, dKick, dKick, $04
	smpsPan             panCenter, $00
	dc.b	dHiClap
	smpsPan             panRight, $00
	dc.b	dLowTom, dLowTom
	smpsPan             panCenter, $00
	dc.b	dHiClap
	smpsPan             panRight, $00
	dc.b	dLowTom, dLowTom
	smpsPan             panCenter, $00
	dc.b	dHiClap
	smpsPan             panRight, $00
	dc.b	dLowTom
	smpsPan             panCenter, $00
	dc.b	dHiClap, dSnare, $06, dSnare, $02, dSnare, $04, dSnare, dSnare, dSnare
	smpsPan             panCenter, $00
	dc.b	dMidClap
	smpsPan             panRight, $00
	dc.b	dLowTom, dLowTom
	smpsPan             panCenter, $00
	dc.b	dMidClap
	smpsPan             panRight, $00
	dc.b	dLowTom
	smpsPan             panCenter, $00
	dc.b	dMidClap, dSnare, dSnare, $02, dSnare, dSnare, dVLowTimpani, dMidTimpani, dMidTimpani, dVLowTimpani, dVLowTimpani, dKick
	dc.b	dSnare, dFloorTom, $04
	smpsPan             panRight, $00
	dc.b	dLowTom
	smpsPan             panRight, $00
	dc.b	dLowTom
	smpsPan             panCenter, $00
	dc.b	dFloorTom
	smpsPan             panRight, $00
	dc.b	dLowTom
	smpsPan             panCenter, $00
	dc.b	dLowClap, dKick, $06, dScratch, $02, dClap, dClap, dClap
	smpsPan             panLeft, $00
	dc.b	dClap
	smpsPan             panRight, $00
	dc.b	dClap
	smpsPan             panLeft, $00
	dc.b	dLowTom, $03, dLowTom
	smpsPan             panCenter, $00
	smpsJump            Round32_Loop01

Round32_Voices:
;	Voice $00
;	$7D
;	$73, $52, $74, $33, 	$1F, $1F, $5F, $5F, 	$1A, $0A, $0A, $0A
;	$13, $0A, $0A, $0A, 	$5F, $57, $57, $57, 	$11, $00, $00, $00
	smpsVcAlgorithm     $05
	smpsVcFeedback      $07
	smpsVcUnusedBits    $01
	smpsVcDetune        $03, $07, $05, $07
	smpsVcCoarseFreq    $03, $04, $02, $03
	smpsVcRateScale     $01, $01, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $0A, $0A, $0A, $1A
	smpsVcDecayRate2    $0A, $0A, $0A, $13
	smpsVcDecayLevel    $05, $05, $05, $05
	smpsVcReleaseRate   $07, $07, $07, $0F
	smpsVcTotalLevel    $00, $00, $00, $11

;	Voice $01
;	$7C
;	$74, $31, $31, $71, 	$1F, $1F, $1F, $1F, 	$1F, $05, $05, $05
;	$07, $05, $05, $05, 	$1F, $1F, $1F, $1F, 	$00, $00, $00, $00
	smpsVcAlgorithm     $04
	smpsVcFeedback      $07
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $01, $01, $01, $04
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $05, $05, $05, $1F
	smpsVcDecayRate2    $05, $05, $05, $07
	smpsVcDecayLevel    $01, $01, $01, $01
	smpsVcReleaseRate   $0F, $0F, $0F, $0F
	smpsVcTotalLevel    $00, $00, $00, $00

;	Voice $02
;	$FC
;	$7F, $31, $3F, $71, 	$FF, $1F, $FF, $1F, 	$0F, $00, $08, $00
;	$0F, $00, $08, $00, 	$A0, $14, $A0, $14, 	$00, $07, $08, $07
	smpsVcAlgorithm     $04
	smpsVcFeedback      $07
	smpsVcUnusedBits    $03
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $01, $0F, $01, $0F
	smpsVcRateScale     $00, $03, $00, $03
	smpsVcAttackRate    $1F, $3F, $1F, $3F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $00, $08, $00, $0F
	smpsVcDecayRate2    $00, $08, $00, $0F
	smpsVcDecayLevel    $01, $0A, $01, $0A
	smpsVcReleaseRate   $04, $00, $04, $00
	smpsVcTotalLevel    $07, $08, $07, $00

;	Voice $03
;	$FB
;	$73, $33, $30, $76, 	$FF, $1F, $1F, $1F, 	$0A, $00, $00, $00
;	$0A, $00, $00, $00, 	$18, $18, $18, $18, 	$0F, $03, $03, $03
	smpsVcAlgorithm     $03
	smpsVcFeedback      $07
	smpsVcUnusedBits    $03
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $06, $00, $03, $03
	smpsVcRateScale     $00, $00, $00, $03
	smpsVcAttackRate    $1F, $1F, $1F, $3F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $00, $00, $00, $0A
	smpsVcDecayRate2    $00, $00, $00, $0A
	smpsVcDecayLevel    $01, $01, $01, $01
	smpsVcReleaseRate   $08, $08, $08, $08
	smpsVcTotalLevel    $03, $03, $03, $0F

;	Voice $04
;	$7D
;	$71, $31, $3F, $72, 	$5F, $5F, $5F, $5F, 	$1F, $0F, $0F, $0F
;	$0A, $00, $00, $00, 	$68, $58, $58, $58, 	$00, $07, $07, $07
	smpsVcAlgorithm     $05
	smpsVcFeedback      $07
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $02, $0F, $01, $01
	smpsVcRateScale     $01, $01, $01, $01
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $0F, $0F, $0F, $1F
	smpsVcDecayRate2    $00, $00, $00, $0A
	smpsVcDecayLevel    $05, $05, $05, $06
	smpsVcReleaseRate   $08, $08, $08, $08
	smpsVcTotalLevel    $07, $07, $07, $00

;	Voice $05
;	$7C
;	$73, $30, $33, $75, 	$1F, $1F, $1F, $1F, 	$0F, $0F, $1F, $0F
;	$00, $00, $00, $00, 	$17, $17, $87, $17, 	$0D, $02, $00, $00
	smpsVcAlgorithm     $04
	smpsVcFeedback      $07
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $05, $03, $00, $03
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $0F, $1F, $0F, $0F
	smpsVcDecayRate2    $00, $00, $00, $00
	smpsVcDecayLevel    $01, $08, $01, $01
	smpsVcReleaseRate   $07, $07, $07, $07
	smpsVcTotalLevel    $00, $00, $02, $0D

;	Voice $06
;	$F0
;	$72, $30, $3B, $78, 	$1F, $1F, $1F, $1F, 	$1F, $1C, $1C, $0C
;	$1F, $0C, $0C, $0C, 	$5F, $5F, $5F, $5F, 	$00, $00, $07, $00
	smpsVcAlgorithm     $00
	smpsVcFeedback      $06
	smpsVcUnusedBits    $03
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $08, $0B, $00, $02
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $0C, $1C, $1C, $1F
	smpsVcDecayRate2    $0C, $0C, $0C, $1F
	smpsVcDecayLevel    $05, $05, $05, $05
	smpsVcReleaseRate   $0F, $0F, $0F, $0F
	smpsVcTotalLevel    $00, $07, $00, $00

;	Voice $07
;	$6C
;	$70, $33, $33, $7F, 	$1F, $1F, $1F, $1F, 	$19, $0F, $01, $09
;	$09, $01, $01, $01, 	$FF, $09, $FF, $5F, 	$0C, $00, $09, $09
	smpsVcAlgorithm     $04
	smpsVcFeedback      $05
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $0F, $03, $03, $00
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $09, $01, $0F, $19
	smpsVcDecayRate2    $01, $01, $01, $09
	smpsVcDecayLevel    $05, $0F, $00, $0F
	smpsVcReleaseRate   $0F, $0F, $09, $0F
	smpsVcTotalLevel    $09, $09, $00, $0C

;	Voice $08
;	$F7
;	$3F, $74, $78, $38, 	$1F, $1F, $1F, $1F, 	$0A, $0A, $0A, $0A
;	$00, $00, $00, $00, 	$17, $17, $17, $17, 	$08, $11, $11, $11
	smpsVcAlgorithm     $07
	smpsVcFeedback      $06
	smpsVcUnusedBits    $03
	smpsVcDetune        $03, $07, $07, $03
	smpsVcCoarseFreq    $08, $08, $04, $0F
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $0A, $0A, $0A, $0A
	smpsVcDecayRate2    $00, $00, $00, $00
	smpsVcDecayLevel    $01, $01, $01, $01
	smpsVcReleaseRate   $07, $07, $07, $07
	smpsVcTotalLevel    $11, $11, $11, $08

;	Voice $09
;	$7D
;	$71, $31, $31, $70, 	$4C, $1F, $50, $12, 	$0F, $02, $01, $02
;	$01, $00, $00, $00, 	$27, $29, $29, $29, 	$0F, $00, $00, $00
	smpsVcAlgorithm     $05
	smpsVcFeedback      $07
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $00, $01, $01, $01
	smpsVcRateScale     $00, $01, $00, $01
	smpsVcAttackRate    $12, $10, $1F, $0C
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $02, $01, $02, $0F
	smpsVcDecayRate2    $00, $00, $00, $01
	smpsVcDecayLevel    $02, $02, $02, $02
	smpsVcReleaseRate   $09, $09, $09, $07
	smpsVcTotalLevel    $00, $00, $00, $0F

;	Voice $0A
;	$75
;	$74, $34, $34, $78, 	$1F, $1F, $1F, $1F, 	$1F, $1F, $1F, $1F
;	$0A, $00, $00, $00, 	$0F, $17, $17, $17, 	$0F, $00, $00, $00
	smpsVcAlgorithm     $05
	smpsVcFeedback      $06
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $08, $04, $04, $04
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $1F, $1F, $1F, $1F
	smpsVcDecayRate2    $00, $00, $00, $0A
	smpsVcDecayLevel    $01, $01, $01, $00
	smpsVcReleaseRate   $07, $07, $07, $0F
	smpsVcTotalLevel    $00, $00, $00, $0F

;	Voice $0B
;	$40
;	$77, $31, $3F, $72, 	$1F, $F8, $1F, $F8, 	$11, $11, $11, $15
;	$00, $00, $00, $00, 	$24, $24, $24, $24, 	$0E, $0C, $1A, $00
	smpsVcAlgorithm     $00
	smpsVcFeedback      $00
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $02, $0F, $01, $07
	smpsVcRateScale     $03, $00, $03, $00
	smpsVcAttackRate    $38, $1F, $38, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $15, $11, $11, $11
	smpsVcDecayRate2    $00, $00, $00, $00
	smpsVcDecayLevel    $02, $02, $02, $02
	smpsVcReleaseRate   $04, $04, $04, $04
	smpsVcTotalLevel    $00, $1A, $0C, $0E

;	Voice $0C
;	$F6
;	$7F, $38, $31, $76, 	$1F, $1F, $1F, $1F, 	$1F, $00, $00, $00
;	$11, $0F, $05, $00, 	$10, $18, $18, $18, 	$07, $06, $0A, $08
	smpsVcAlgorithm     $06
	smpsVcFeedback      $06
	smpsVcUnusedBits    $03
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $06, $01, $08, $0F
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $00, $00, $00, $1F
	smpsVcDecayRate2    $00, $05, $0F, $11
	smpsVcDecayLevel    $01, $01, $01, $01
	smpsVcReleaseRate   $08, $08, $08, $00
	smpsVcTotalLevel    $08, $0A, $06, $07

;	Voice $0D
;	$7D
;	$71, $33, $34, $70, 	$1F, $1F, $1F, $1F, 	$0F, $0B, $0B, $0B
;	$0C, $07, $07, $07, 	$1F, $17, $17, $17, 	$13, $08, $08, $08
	smpsVcAlgorithm     $05
	smpsVcFeedback      $07
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $00, $04, $03, $01
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $0B, $0B, $0B, $0F
	smpsVcDecayRate2    $07, $07, $07, $0C
	smpsVcDecayLevel    $01, $01, $01, $01
	smpsVcReleaseRate   $07, $07, $07, $0F
	smpsVcTotalLevel    $08, $08, $08, $13

;	Voice $0E
;	$72
;	$74, $32, $34, $78, 	$5F, $5F, $5F, $5F, 	$10, $0C, $0C, $00
;	$03, $03, $02, $00, 	$1F, $1F, $1F, $1F, 	$0F, $0F, $0F, $06
	smpsVcAlgorithm     $02
	smpsVcFeedback      $06
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $08, $04, $02, $04
	smpsVcRateScale     $01, $01, $01, $01
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $00, $0C, $0C, $10
	smpsVcDecayRate2    $00, $02, $03, $03
	smpsVcDecayLevel    $01, $01, $01, $01
	smpsVcReleaseRate   $0F, $0F, $0F, $0F
	smpsVcTotalLevel    $06, $0F, $0F, $0F

;	Voice $0F
;	$75
;	$71, $32, $72, $32, 	$5F, $5F, $5F, $5F, 	$0F, $0C, $0C, $00
;	$07, $07, $07, $00, 	$1F, $1F, $1F, $1F, 	$0C, $05, $00, $00
	smpsVcAlgorithm     $05
	smpsVcFeedback      $06
	smpsVcUnusedBits    $01
	smpsVcDetune        $03, $07, $03, $07
	smpsVcCoarseFreq    $02, $02, $02, $01
	smpsVcRateScale     $01, $01, $01, $01
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $00, $0C, $0C, $0F
	smpsVcDecayRate2    $00, $07, $07, $07
	smpsVcDecayLevel    $01, $01, $01, $01
	smpsVcReleaseRate   $0F, $0F, $0F, $0F
	smpsVcTotalLevel    $00, $00, $05, $0C

;	Voice $10
;	$72
;	$73, $31, $32, $72, 	$1F, $1F, $1F, $1F, 	$0F, $1F, $0F, $00
;	$08, $0F, $00, $00, 	$1A, $18, $1E, $19, 	$0F, $0F, $1F, $01
	smpsVcAlgorithm     $02
	smpsVcFeedback      $06
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $02, $02, $01, $03
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $00, $0F, $1F, $0F
	smpsVcDecayRate2    $00, $00, $0F, $08
	smpsVcDecayLevel    $01, $01, $01, $01
	smpsVcReleaseRate   $09, $0E, $08, $0A
	smpsVcTotalLevel    $01, $1F, $0F, $0F

;	Voice $11
;	$40
;	$76, $32, $33, $78, 	$1F, $1F, $1F, $1F, 	$1A, $1E, $17, $07
;	$0A, $0E, $07, $07, 	$2C, $2C, $2C, $2C, 	$15, $15, $07, $00
	smpsVcAlgorithm     $00
	smpsVcFeedback      $00
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $08, $03, $02, $06
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $07, $17, $1E, $1A
	smpsVcDecayRate2    $07, $07, $0E, $0A
	smpsVcDecayLevel    $02, $02, $02, $02
	smpsVcReleaseRate   $0C, $0C, $0C, $0C
	smpsVcTotalLevel    $00, $07, $15, $15

;	Voice $12
;	$48
;	$76, $34, $31, $74, 	$1F, $1F, $1F, $1F, 	$1F, $0F, $1F, $07
;	$05, $07, $08, $07, 	$24, $24, $24, $24, 	$10, $15, $0C, $00
	smpsVcAlgorithm     $00
	smpsVcFeedback      $01
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $04, $01, $04, $06
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $07, $1F, $0F, $1F
	smpsVcDecayRate2    $07, $08, $07, $05
	smpsVcDecayLevel    $02, $02, $02, $02
	smpsVcReleaseRate   $04, $04, $04, $04
	smpsVcTotalLevel    $00, $0C, $15, $10

;	Voice $13
;	$7D
;	$73, $34, $36, $75, 	$1F, $1F, $1F, $1F, 	$0F, $0B, $0B, $0B
;	$0B, $07, $07, $07, 	$1F, $17, $17, $17, 	$13, $08, $08, $08
	smpsVcAlgorithm     $05
	smpsVcFeedback      $07
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $05, $06, $04, $03
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $0B, $0B, $0B, $0F
	smpsVcDecayRate2    $07, $07, $07, $0B
	smpsVcDecayLevel    $01, $01, $01, $01
	smpsVcReleaseRate   $07, $07, $07, $0F
	smpsVcTotalLevel    $08, $08, $08, $13

;	Voice $14
;	$76
;	$71, $33, $34, $70, 	$1F, $1F, $1F, $1F, 	$1F, $0B, $0B, $0B
;	$0D, $07, $07, $07, 	$1F, $17, $17, $17, 	$0A, $02, $09, $0B
	smpsVcAlgorithm     $06
	smpsVcFeedback      $06
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $00, $04, $03, $01
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $0B, $0B, $0B, $1F
	smpsVcDecayRate2    $07, $07, $07, $0D
	smpsVcDecayLevel    $01, $01, $01, $01
	smpsVcReleaseRate   $07, $07, $07, $0F
	smpsVcTotalLevel    $0B, $09, $02, $0A

;	Voice $15
;	$18
;	$72, $35, $36, $74, 	$1F, $1F, $1F, $1F, 	$15, $15, $15, $15
;	$00, $00, $00, $00, 	$04, $07, $04, $07, 	$0E, $17, $1A, $04
	smpsVcAlgorithm     $00
	smpsVcFeedback      $03
	smpsVcUnusedBits    $00
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $04, $06, $05, $02
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $15, $15, $15, $15
	smpsVcDecayRate2    $00, $00, $00, $00
	smpsVcDecayLevel    $00, $00, $00, $00
	smpsVcReleaseRate   $07, $04, $07, $04
	smpsVcTotalLevel    $04, $1A, $17, $0E

;	Voice $16
;	$7D
;	$72, $32, $32, $72, 	$1F, $1F, $1F, $1F, 	$13, $00, $00, $00
;	$0F, $00, $00, $00, 	$18, $18, $18, $18, 	$0E, $05, $05, $05
	smpsVcAlgorithm     $05
	smpsVcFeedback      $07
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $02, $02, $02, $02
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $00, $00, $00, $13
	smpsVcDecayRate2    $00, $00, $00, $0F
	smpsVcDecayLevel    $01, $01, $01, $01
	smpsVcReleaseRate   $08, $08, $08, $08
	smpsVcTotalLevel    $05, $05, $05, $0E

;	Voice $17
;	$7C
;	$78, $34, $33, $7F, 	$1F, $1F, $1F, $1F, 	$10, $00, $10, $00
;	$0F, $00, $08, $00, 	$3F, $08, $3F, $08, 	$0F, $04, $0C, $04
	smpsVcAlgorithm     $04
	smpsVcFeedback      $07
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $0F, $03, $04, $08
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $00, $10, $00, $10
	smpsVcDecayRate2    $00, $08, $00, $0F
	smpsVcDecayLevel    $00, $03, $00, $03
	smpsVcReleaseRate   $08, $0F, $08, $0F
	smpsVcTotalLevel    $04, $0C, $04, $0F

;	Voice $18
;	$7D
;	$72, $32, $31, $72, 	$5F, $5F, $5F, $5F, 	$1F, $0F, $0F, $0F
;	$0A, $00, $00, $00, 	$68, $58, $58, $58, 	$00, $01, $01, $01
	smpsVcAlgorithm     $05
	smpsVcFeedback      $07
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $03, $03, $07
	smpsVcCoarseFreq    $02, $01, $02, $02
	smpsVcRateScale     $01, $01, $01, $01
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $0F, $0F, $0F, $1F
	smpsVcDecayRate2    $00, $00, $00, $0A
	smpsVcDecayLevel    $05, $05, $05, $06
	smpsVcReleaseRate   $08, $08, $08, $08
	smpsVcTotalLevel    $01, $01, $01, $00

;	Voice $19
;	$75
;	$72, $4E, $54, $72, 	$1F, $1F, $1F, $1F, 	$0F, $1F, $0F, $00
;	$08, $0F, $00, $00, 	$1A, $18, $1E, $19, 	$0A, $05, $06, $01
	smpsVcAlgorithm     $05
	smpsVcFeedback      $06
	smpsVcUnusedBits    $01
	smpsVcDetune        $07, $05, $04, $07
	smpsVcCoarseFreq    $02, $04, $0E, $02
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $00, $0F, $1F, $0F
	smpsVcDecayRate2    $00, $00, $0F, $08
	smpsVcDecayLevel    $01, $01, $01, $01
	smpsVcReleaseRate   $09, $0E, $08, $0A
	smpsVcTotalLevel    $01, $06, $05, $0A

