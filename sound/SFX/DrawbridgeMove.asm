Sfx_DrawbridgeMove_Header:
	smpsHeaderStartSong 2
	smpsHeaderVoice     Sfx_DrawbridgeMove_Voices
	smpsHeaderTempoSFX  $01
	smpsHeaderChanSFX   $01

	smpsHeaderSFXChannel cPSG3, Sfx_DrawbridgeMove_PSG3,	$00, $00

; PSG3 Data
Sfx_DrawbridgeMove_PSG3:
	smpsPSGvoice        fTone_06
	smpsPSGform         $E7
	dc.b	nEb1, $0A, nG1, $0A, nB1, $0A, nEb2, $0A, nG2, $0A, nB2, $08
	dc.b	nEb3, $08, nG3, $08, nB3, $08
	smpsStop

; Song seems to not use any FM voices
Sfx_DrawbridgeMove_Voices:
