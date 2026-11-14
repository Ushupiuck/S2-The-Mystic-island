Sfx_Beep_Header:
	smpsHeaderStartSong 2
	smpsHeaderVoiceNull
	smpsHeaderTempoSFX  $01
	smpsHeaderChanSFX   $01

	smpsHeaderSFXChannel cPSG1, Sfx_Beep_PSG1,	$E8, $03

; PSG1 Data
Sfx_Beep_PSG1:
	smpsPSGvoice        fTone_04
	dc.b	nD6, $04
	smpsStop
