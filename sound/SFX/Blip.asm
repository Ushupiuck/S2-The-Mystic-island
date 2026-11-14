Sfx_Blip_Header:
	smpsHeaderStartSong 2
	smpsHeaderVoiceNull
	smpsHeaderTempoSFX  $01
	smpsHeaderChanSFX   $01

	smpsHeaderSFXChannel cPSG3, Sfx_Blip_PSG3,	$00, $00

; PSG3 Data
Sfx_Blip_PSG3:
	dc.b	nBb4, $02
	smpsStop
