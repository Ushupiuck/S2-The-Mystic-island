; ----------------------------------------------------------------------------
; Object 71 - Invisible solid block
; ----------------------------------------------------------------------------

Obj71:
	moveq	#0,d0
	move.b	routine(a0),d0
	move.w	Obj71_Index(pc,d0.w),d1
	jmp	Obj71_Index(pc,d1.w)
; ===========================================================================

Obj71_Index:
	dc.w Obj71_Init - Obj71_Index	; 0
	dc.w Obj71_Main - Obj71_Index	; 2
; ===========================================================================

Obj71_Init:
	addq.b	#2,routine(a0) ; => Obj71_Main
	move.l	#Obj71_MapUnc_20F66,mappings(a0)
	move.w	#$8680,art_tile(a0)
	ori.b	#4,render_flags(a0)
	move.b	subtype(a0),d0
	move.b	d0,d1
	andi.w	#$F0,d0
	addi.w	#$10,d0
	lsr.w	#1,d0
	move.b	d0,width_pixels(a0)
	andi.w	#$F,d1
	addq.w	#1,d1
	lsl.w	#3,d1
	move.b	d1,y_radius(a0)

Obj71_Main:
	moveq	#0,d1
	move.b	width_pixels(a0),d1
	addi.w	#$B,d1
	moveq	#0,d2
	move.b	y_radius(a0),d2
	move.w	d2,d3
	addq.w	#1,d3
	move.w	x_pos(a0),d4
	bsr.w	SolidObject_Always
	out_of_range.w	DeleteObject
+
	tst.w	(v_debuguse).w
	beq.s	+	; rts
	jmp	(DisplaySprite).l
+
	rts
; ===========================================================================
; -------------------------------------------------------------------------------
; sprite mappings
; -------------------------------------------------------------------------------
Obj71_MapUnc_20F66:	BINCLUDE "mappings/Invisible barrier.bin"