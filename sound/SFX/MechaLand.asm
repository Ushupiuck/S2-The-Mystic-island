; From pinned skdisasm; legacy SMPS voice format 0.
Sfx_MechaLand_Header:
	smpsHeaderStartSong 3
	smpsHeaderVoice     Sfx_MechaLand_Voices
	smpsHeaderTempoSFX  $01
	smpsHeaderChanSFX   $01

	smpsHeaderSFXChannel cFM5, Sfx_MechaLand_FM5,	$00, $00

; FM5 Data
Sfx_MechaLand_FM5:
	smpsSetvoice        $00
	smpsModSet          $01, $01, $0C, $01

Sfx_MechaLand_Loop00:
	dc.b	nC0, $0A
	smpsFMAlterVol      $10
	smpsLoop            $00, $04, Sfx_MechaLand_Loop00
	smpsStop

Sfx_MechaLand_Voices:
;	Voice $00
;	$F9
;	$20, $30, $10, $30, 	$1F, $1F, $1F, $1F, 	$02, $04, $11, $02
;	$0B, $1F, $10, $05, 	$1F, $2F, $4F, $2F, 	$0E, $07, $04, $80
	smpsVcAlgorithm     $01
	smpsVcFeedback      $07
	smpsVcUnusedBits    $03
	smpsVcDetune        $03, $01, $03, $02
	smpsVcCoarseFreq    $00, $00, $00, $00
	smpsVcRateScale     $00, $00, $00, $00
	smpsVcAttackRate    $1F, $1F, $1F, $1F
	smpsVcAmpMod        $00, $00, $00, $00
	smpsVcDecayRate1    $02, $11, $04, $02
	smpsVcDecayRate2    $05, $10, $1F, $0B
	smpsVcDecayLevel    $02, $04, $02, $01
	smpsVcReleaseRate   $0F, $0F, $0F, $0F
	smpsVcTotalLevel    $00, $04, $07, $0E
