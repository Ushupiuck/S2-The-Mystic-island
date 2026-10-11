; ---------------------------------------------------------------------------
; Sprite mappings - "SONIC HAS PASSED" title card
; ---------------------------------------------------------------------------
; Both results cards share these HUD tiles and use ArtTile_Title_Card as
; their mapping base. RING lettering is loaded separately for results only.
Map_Results_ScoreLetters = ArtTile_HUD-ArtTile_Title_Card
Map_Results_TimeLetters = ArtTile_HUD+8-ArtTile_Title_Card
Map_Results_ScoreE = ArtTile_HUD_Numbers-ArtTile_Title_Card
Map_Results_ScoreDigits = ArtTile_HUD_Numbers+2-ArtTile_Title_Card
Map_Results_Zero = ArtTile_HUD_Numbers+$E-ArtTile_Title_Card
Map_Results_RingLetters = ArtTile_Results_Ring_Label-ArtTile_Title_Card

Map_Obj3A:
		dc.w M_Got_SonicHas-Map_Obj3A
		dc.w M_Got_Passed-Map_Obj3A
		dc.w M_Got_Score-Map_Obj3A
		dc.w M_Got_TBonus-Map_Obj3A
		dc.w M_Got_RBonus-Map_Obj3A
		dc.w M_Card_Oval-Map_Obj3A
		dc.w M_Card_Act1-Map_Obj3A
		dc.w M_Card_Act2-Map_Obj3A
		dc.w M_Card_Act3-Map_Obj3A
M_Got_SonicHas:	dc.w 8			; SONIC HAS
		dc.w $F805,  $3E,  $1F,$FFB8
		dc.w $F805,  $32,  $19,$FFC8
		dc.w $F805,  $2E,  $17,$FFD8
		dc.w $F801,  $20,  $10,$FFE8
		dc.w $F805,    8,    4,$FFF0
		dc.w $F805,  $1C,   $E,	 $10
		dc.w $F805,    0,    0,	 $20
		dc.w $F805,  $3E,  $1F,	 $30
M_Got_Passed:	dc.w 6			; PASSED
		dc.w $F805,  $36,  $1B,$FFD0
		dc.w $F805,    0,    0,$FFE0
		dc.w $F805,  $3E,  $1F,$FFF0
		dc.w $F805,  $3E,  $1F,	   0
		dc.w $F805,  $10,    8,	 $10
		dc.w $F805,   $C,    6,	 $20
M_Got_Score:	dc.w 6			; SCORE
		dc.w $F80D, Map_Results_ScoreLetters, Map_Results_ScoreLetters/2,$FFB0
		dc.w $F801, Map_Results_ScoreE, Map_Results_ScoreE/2,$FFD0
		dc.w $F809, Map_Results_ScoreDigits, Map_Results_ScoreDigits/2,	 $18
		dc.w $F80D, Map_Results_ScoreDigits+6, (Map_Results_ScoreDigits+6)/2,	 $30
		dc.w $F704,  $6E,  $37,$FFCD
		dc.w $FF04,$186E,$1837,$FFCD
M_Got_TBonus:	dc.w 7			; TIME BONUS
		dc.w $F80D, Map_Results_TimeLetters, Map_Results_TimeLetters/2,$FFB0
		dc.w $F80D,  $66,  $33,$FFD9
		dc.w $F801, Map_Results_ScoreLetters, Map_Results_ScoreLetters/2,$FFF9
		dc.w $F704,  $6E,  $37,$FFF6
		dc.w $FF04,$186E,$1837,$FFF6
		dc.w $F80D,$FFF0,$FBF8,	 $28
		dc.w $F801, Map_Results_Zero, Map_Results_Zero/2,	 $48
M_Got_RBonus:	dc.w 7			; RING BONUS
		dc.w $F80D, Map_Results_RingLetters, Map_Results_RingLetters/2,$FFB0
		dc.w $F80D,  $66,  $33,$FFD9
		dc.w $F801, Map_Results_ScoreLetters, Map_Results_ScoreLetters/2,$FFF9
		dc.w $F704,  $6E,  $37,$FFF6
		dc.w $FF04,$186E,$1837,$FFF6
		dc.w $F80D,$FFF8,$FBFC,	 $28
		dc.w $F801, Map_Results_Zero, Map_Results_Zero/2,	 $48
		even
