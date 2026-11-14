Sfx_TailsFlyingTired_Header:
	smpsHeaderStartSong 3
	smpsHeaderVoice     Sfx_TailsFlying_BB_Voices
	smpsHeaderTempoSFX  $01
	smpsHeaderChanSFX   $01

	smpsHeaderSFXChannel cFM4, Sfx_TailsFlyingTired_FM4,	$FA, $0B

; FM4 Data
Sfx_TailsFlyingTired_FM4:
	smpsSetvoice        $00
	dc.b	nE2, $08, $08
	smpsStop
