Sfx_SlowSmash_Header:
	smpsHeaderStartSong 2
	smpsHeaderVoice     Sfx_BossHit_39_4B_Voices
	smpsHeaderTempoSFX  $01
	smpsHeaderChanSFX   $02

	smpsHeaderSFXChannel cFM5, Sfx_SlowSmash_FM5,	$00, $00
	smpsHeaderSFXChannel cPSG3, Sfx_SlowSmash_PSG3,	$00, $00

; FM5 Data
Sfx_SlowSmash_FM5:
	smpsSetvoice        $00
	smpsModSet          $03, $01, $20, $04

Sfx_SlowSmash_Loop00:
	dc.b	nC0, $18
	smpsAlterVol        $0A
	smpsLoop            $00, $06, Sfx_SlowSmash_Loop00
	smpsStop

; PSG3 Data
Sfx_SlowSmash_PSG3:
	smpsModSet          $01, $01, $0F, $05
	smpsPSGform         $E7

Sfx_SlowSmash_Loop01:
	dc.b	nB3, $18, smpsNoAttack
	smpsPSGAlterVol     $03
	smpsLoop            $00, $05, Sfx_SlowSmash_Loop01
	smpsStop
