Sfx_Ring_Header:
	smpsHeaderStartSong 2
	smpsHeaderVoice     Sfx_TallyEnd_Ring_Voices
	smpsHeaderTempoSFX  $01
	smpsHeaderChanSFX   $01

	smpsHeaderSFXChannel cFM5, Sfx_Ring_FM5,	$00, $05

; FM5 Data
Sfx_Ring_FM5:
	smpsSetvoice        $00
	smpsPan             panRight, $00
	dc.b	nE5, $05, nG5, $05, nC6, $1B
	smpsStop

