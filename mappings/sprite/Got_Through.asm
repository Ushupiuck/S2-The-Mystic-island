Map_SSResults_RingTile = ArtTile_SS_Rings-ArtTile_Title_Card
; ---------------------------------------------------------------------------
; Sprite mappings - "SONIC HAS PASSED" title card
; ---------------------------------------------------------------------------
; Both results cards share these HUD tiles and use ArtTile_Title_Card as
; their mapping base. Each ring icon reuses its stage's ring allocation.
Map_Results_ScoreLetters = ArtTile_HUD-ArtTile_Title_Card
Map_Results_TimeLetters = ArtTile_HUD+8-ArtTile_Title_Card
Map_Results_ScoreE = ArtTile_HUD_E-ArtTile_Title_Card
Map_Results_ScoreDigits = ArtTile_HUD_Numbers-ArtTile_Title_Card
Map_Results_Zero = ArtTile_HUD_Numbers+$C-ArtTile_Title_Card
Map_Results_RingTile = make_art_tile(ArtTile_Ring-ArtTile_Title_Card,1,0)

Map_Obj3A:
		dc.w M_Got_SonicHas-Map_Obj3A
		dc.w M_Got_Passed-Map_Obj3A
		dc.w M_Got_Score-Map_Obj3A
		dc.w M_Got_TBonus-Map_Obj3A
		dc.w M_Got_RBonus-Map_Obj3A
		dc.w M_Result_Oval-Map_Obj3A
		dc.w M_Result_Act1-Map_Obj3A
		dc.w M_Result_Act2-Map_Obj3A
		dc.w M_Result_Act3-Map_Obj3A
		dc.w M_Result_Act4-Map_Obj3A
M_Got_SonicHas:	dc.w 8			; SONIC HAS
		dc.w $F805, $3E, $FFB8
		dc.w $F805, $32, $FFC8
		dc.w $F805, $2E, $FFD8
		dc.w $F801, $20, $FFE8
		dc.w $F805, 8, $FFF0
		dc.w $F805, $1C, $10
		dc.w $F805, 0, $20
		dc.w $F805, $3E, $30
M_Got_Passed:	dc.w 6			; PASSED
		dc.w $F805, $36, $FFD0
		dc.w $F805, 0, $FFE0
		dc.w $F805, $3E, $FFF0
		dc.w $F805, $3E, 0
		dc.w $F805, $10, $10
		dc.w $F805, $C, $20
M_Got_Score:	dc.w 6			; SCORE
		dc.w $F80D, Map_Results_ScoreLetters, $FFB0
		dc.w $F801, Map_Results_ScoreE, $FFD0
		dc.w $F809, Map_Results_ScoreDigits, $18
		dc.w $F80D, Map_Results_ScoreDigits+6, $30
		dc.w $F704, $6D, $FFCD
		dc.w $FF04, $186D, $FFCD
M_Got_TBonus:	dc.w 7			; TIME BONUS
		dc.w $F80D, Map_Results_TimeLetters, $FFB0
		dc.w $F80D, $65, $FFD9
		dc.w $F801, Map_Results_ScoreLetters, $FFF9
		dc.w $F704, $6D, $FFF6
		dc.w $FF04, $186D, $FFF6
		dc.w $F80D, $FFF0, $28
		dc.w $F801, Map_Results_Zero, $48
M_Got_RBonus:	dc.w 7			; Animated ring + BONUS
		dc.w $F805, Map_Results_RingTile, $FFC0
		dc.w $F80D, $65, $FFD9
		dc.w $F801, Map_Results_ScoreLetters, $FFF9
		dc.w $F704, $6D, $FFF6
		dc.w $FF04, $186D, $FFF6
		dc.w $F80D, $FFF8, $28
		dc.w $F801, Map_Results_Zero, $48
		even
