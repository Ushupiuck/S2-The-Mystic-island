Sfx_OilSlide_Header:
	smpsHeaderStartSong 2
	smpsHeaderVoiceNull
	smpsHeaderTempoSFX  $01
	smpsHeaderChanSFX   $01

	smpsHeaderSFXChannel cPSG3, Sfx_OilSlide_PSG3,	$00, $00

; PSG3 Data
Sfx_OilSlide_PSG3:
	smpsPSGform         $E7
	dc.b	nMaxPSG, $18

Sfx_OilSlide_Loop00:
	dc.b	smpsNoAttack, $03
	;smpsAlterVol        $01
	smpsPSGAlterVol     $01
	smpsLoop            $00, $08, Sfx_OilSlide_Loop00
	smpsStop
