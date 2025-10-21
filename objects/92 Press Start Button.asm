; ---------------------------------------------------------------------------
; Object 92 - "PRESS START BUTTON" from title screen
; ---------------------------------------------------------------------------

PressStartButton:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	PSB_Index(pc,d0.w),d1
		jsr	PSB_Index(pc,d1.w)
		bra.w	DisplaySprite
; ===========================================================================
PSB_Index:	dc.w PSB_Main-PSB_Index
; ===========================================================================

PSB_Main:	; Routine 0
	;	addq.b	#2,obRoutine(a0)
		move.w	#$D8,obX(a0)
		move.w	#$130,obScreenY(a0)
		move.l	#Map_PSB,obMap(a0)
		move.w	#make_art_tile(ArtTile_Title_Press_Start,3,0),obGfx(a0)
		lea	Ani_PSB(pc),a1
		bra.w	AnimateSprite	; "PRESS START" is animated
; ===========================================================================
Ani_PSB:	dc.w .flash-Ani_PSB
.flash:		dc.b $1F,  0,  1,$FF
		even