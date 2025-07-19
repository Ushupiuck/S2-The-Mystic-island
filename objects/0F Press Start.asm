; ---------------------------------------------------------------------------
; Object 0F - "PRESS START BUTTON" from title screen
; ---------------------------------------------------------------------------

Obj0F:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	PSB_Index(pc,d0.w),d1
		jsr	PSB_Index(pc,d1.w)
		bra.w	DisplaySprite
; ===========================================================================
PSB_Index:	dc.w PSB_Main-PSB_Index
; ===========================================================================

PSB_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.w	#$D8,obX(a0)
		move.w	#$130,obScreenY(a0)
		move.l	#Map_PSB,obMap(a0)
		move.w	#$200,obGfx(a0)
		lea	(Ani_PSB).l,a1
		bra.w	AnimateSprite	; "PRESS START" is animated
; ===========================================================================
Ani_PSB:	dc.w byte_B52A-Ani_PSB
byte_B52A:	dc.b $1F,  0,  1,$FF
		even