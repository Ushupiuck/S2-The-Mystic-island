; ---------------------------------------------------------------------------
; Initialize a dynamically selected debug mapping. Normal objects use constant
; bounds at setup; this scan never runs from Render_Sprites or DisplaySprite.
; Preserve the debug selector's registers and its object/list pointers.
; ---------------------------------------------------------------------------
Set_SpriteBounds:
		movem.l	d0-d4/a1,-(sp)
		movea.l	obMap(a0),a1
		moveq	#0,d0
		move.b	obFrame(a0),d0
		add.w	d0,d0
		adda.w	(a1,d0.w),a1
		move.w	(a1)+,d4
		moveq	#0,d2
		moveq	#0,d3
		subq.w	#1,d4
		bmi.s	.done
.piece:
		move.b	(a1)+,d0
		ext.w	d0
		moveq	#0,d1
		move.b	(a1)+,d1
		andi.w	#3,d1
		addq.w	#1,d1
		lsl.w	#3,d1
		add.w	d0,d1		; bottom edge
		tst.w	d0
		bpl.s	.bottom
		neg.w	d0			; the top is above the origin
		cmp.w	d1,d0
		bge.s	.height
.bottom:
		move.w	d1,d0
.height:
		cmp.w	d2,d0
		bls.s	.width
		move.w	d0,d2
.width:
		moveq	#0,d1
		move.b	-1(a1),d1
		lsr.w	#2,d1
		addq.w	#1,d1
		lsl.w	#3,d1
		addq.w	#2,a1
		move.w	(a1)+,d0
		add.w	d0,d1		; right edge
		tst.w	d0
		bpl.s	.right
		neg.w	d0
		cmp.w	d1,d0
		bge.s	.extent
.right:
		move.w	d1,d0
.extent:
		cmp.w	d3,d0
		bls.s	.next
		move.w	d0,d3
.next:
		dbf	d4,.piece
.done:
		cmpi.w	#$FF,d2
		bls.s	.height_ready
		move.w	#$FF,d2
.height_ready:
		cmpi.w	#$FF,d3
		bls.s	.width_ready
		move.w	#$FF,d3
.width_ready:
		move.b	d2,height_pixels(a0)
		move.b	d3,width_pixels(a0)
		movem.l	(sp)+,d0-d4/a1
		rts
