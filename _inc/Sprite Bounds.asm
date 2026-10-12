; ---------------------------------------------------------------------------
; Enlarge legacy display bounds to cover the current S3&K mapping frame.
; Existing object bounds remain valid for chains and objects with child sprites.
; obHeight remains a collision radius; height_pixels is the display half-height.
; Preserve sprite-queue registers and the render flags in d4.
; ---------------------------------------------------------------------------
UpdateSpriteBounds:
		movem.l	d0-d4/a1,-(sp)
		movea.l	obMap(a0),a1
		moveq	#1,d4
		btst	#5,obRender(a0)
		bne.s	.pieces		; a fragment points directly at one piece
		moveq	#0,d0
		move.b	obFrame(a0),d0
		add.w	d0,d0
		adda.w	(a1,d0.w),a1
		move.w	(a1)+,d4
		beq.s	.done
.pieces:
		subq.w	#1,d4
		moveq	#0,d2
		move.b	height_pixels(a0),d2
		moveq	#0,d3
		move.b	width_pixels(a0),d3
.loop:
		move.b	(a1)+,d0
		ext.w	d0
		moveq	#0,d1
		move.b	(a1)+,d1
		andi.w	#3,d1
		addq.w	#1,d1
		lsl.w	#3,d1		; (height cells + 1) * 8 pixels
		add.w	d0,d1		; bottom edge
		bsr.s	.height
		move.w	d0,d1		; top edge
		bsr.s	.height
		moveq	#0,d1
		move.b	-1(a1),d1
		lsr.w	#2,d1
		addq.w	#1,d1
		lsl.w	#3,d1		; (width cells + 1) * 8 pixels
		addq.w	#2,a1		; tile word
		move.w	(a1)+,d0
		add.w	d0,d1		; right edge
		bsr.s	.width
		move.w	d0,d1		; left edge
		bsr.s	.width
		dbf	d4,.loop
		move.b	d2,height_pixels(a0)
		move.b	d3,width_pixels(a0)
.done:
		movem.l	(sp)+,d0-d4/a1
		rts
.height:
		tst.w	d1
		bpl.s	+
		neg.w	d1
+		cmpi.w	#$FF,d1
		bls.s	+
		move.w	#$FF,d1
+		cmp.w	d2,d1
		bls.s	+
		move.w	d1,d2
+		rts
.width:
		tst.w	d1
		bpl.s	+
		neg.w	d1
+		cmpi.w	#$FF,d1
		bls.s	+
		move.w	#$FF,d1
+		cmp.w	d3,d1
		bls.s	+
		move.w	d1,d3
+		rts
