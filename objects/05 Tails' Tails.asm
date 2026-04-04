; ---------------------------------------------------------------------------
; Object 05 - Tails' tails
; ---------------------------------------------------------------------------

Obj05:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj05_Index(pc,d0.w),d1
		jmp	Obj05_Index(pc,d1.w)
; ===========================================================================
Obj05_Index:	dc.w Obj05_Init-Obj05_Index
		dc.w Obj05_Main-Obj05_Index

Tails_prev_anim = objoff_30
; ===========================================================================

Obj05_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Tails,obMap(a0)
		move.w	#make_art_tile(ArtTile_TailsTails,0,0),obGfx(a0)
		move.w	#$100,obPriority(a0)
		move.b	#$18,obActWid(a0)
		move.b	#4,obRender(a0)

Obj05_Main:
		move.b	(v_player2+obAngle).w,obAngle(a0)
		move.b	(v_player2+obStatus).w,obStatus(a0)
		move.w	(v_player2+obX).w,obX(a0)
		move.w	(v_player2+obY).w,obY(a0)
		moveq	#0,d0
		move.b	(v_player2+obAnim).w,d0
		cmp.b	Tails_prev_anim(a0),d0
		beq.s	+
		move.b	d0,Tails_prev_anim(a0)
		move.b	Obj05_Animations(pc,d0.w),obAnim(a0)
+
		lea	Obj05_AniData(pc),a1
		bsr.w	Tails_Animate2
		bsr.w	LoadTailsTailsDynPLC
	;	jmp	(DisplaySprite).l
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
Obj05_Animations:
		dc.b   0,  0
		dc.b   3,  3
		dc.b   0,  1
		dc.b   0,  2
		dc.b   1,  7
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		even

Obj05_AniData:	dc.w byte_11E2A-Obj05_AniData
		dc.w byte_11E2D-Obj05_AniData
		dc.w byte_11E34-Obj05_AniData
		dc.w byte_11E3C-Obj05_AniData
		dc.w byte_11E42-Obj05_AniData
		dc.w byte_11E48-Obj05_AniData
		dc.w byte_11E4E-Obj05_AniData
		dc.w byte_11E54-Obj05_AniData
byte_11E2A:	dc.b $20,  0,afEnd
byte_11E2D:	dc.b   7,  9, $A, $B, $C, $D,afEnd
byte_11E34:	dc.b   3,  9, $A, $B, $C, $D,afChange,  1
byte_11E3C:	dc.b $FC,$49,$4A,$4B,$4C,afEnd
byte_11E42:	dc.b   3,$4D,$4E,$4F,$50,afEnd
byte_11E48:	dc.b   3,$51,$52,$53,$54,afEnd
byte_11E4E:	dc.b   3,$55,$56,$57,$58,afEnd
byte_11E54:	dc.b   2,$81,$82,$83,$84,afEnd
		even