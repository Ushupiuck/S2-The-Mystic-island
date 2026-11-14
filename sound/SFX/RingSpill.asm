Sfx_RingSpill_Header:
	smpsHeaderStartSong 2
	smpsHeaderVoice     Sfx_TallyEnd_Ring_Voices
	smpsHeaderTempoSFX  $01
	smpsHeaderChanSFX   $02

	smpsHeaderSFXChannel cFM4, Sfx_RingSpill_FM4,	$00, $05
	smpsHeaderSFXChannel cFM5, Sfx_RingSpill_FM5,	$00, $08

; FM4 Data
Sfx_RingSpill_FM4:
	smpsSetvoice        $00
	dc.b	nA5, $02, $05, $05, $05, $05, $05, $05, $3A
	smpsStop

; FM5 Data
Sfx_RingSpill_FM5:
	smpsSetvoice        $00
	dc.b	nRst, $02, nG5, $02, $05, $15, $02, $05, $32
	smpsStop
