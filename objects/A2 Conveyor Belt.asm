; ---------------------------------------------------------------------------
; Object A2 - terrain conveyor areas
; Adapted from the project's Temp/objects/68 Conveyor Belt.asm.
; The level supplies the terrain and graphics; this invisible area moves both
; grounded players. Several adjacent areas can cover a sloped/uneven surface.
;
; Subtype: bits 0-3 = full width / 16 - 1 (16-256 pixels)
;          bits 4-6 = speed magnitude (0-7 pixels/frame)
;          bit 7    = height (clear: 48 pixels; set: 112 pixels)
; X flip reverses the speed. The area extends upward from its placement Y.
; ---------------------------------------------------------------------------

conv_speed:	equ objoff_36
conv_width:	equ objoff_38	; half-width
conv_height:	equ objoff_3C

Conveyor:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Conv_Index(pc,d0.w),d1
		jmp	Conv_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Conv_Index:	dc.w Conv_Main-Conv_Index
		dc.w Conv_Action-Conv_Index
; ---------------------------------------------------------------------------

Conv_Main:
		addq.b	#2,obRoutine(a0)
		moveq	#48,d1
		move.b	obSubtype(a0),d0
		bpl.s	.height
		moveq	#112,d1
.height:
		move.w	d1,conv_height(a0)
		andi.w	#$F,d0
		addq.w	#1,d0
		lsl.w	#3,d0
		move.w	d0,conv_width(a0)
		moveq	#0,d1
		move.b	obSubtype(a0),d1
		andi.w	#$70,d1
		lsr.w	#4,d1
		btst	#0,obStatus(a0)
		beq.s	.speed
		neg.w	d1
.speed:
		move.w	d1,conv_speed(a0)

Conv_Action:
		lea	(v_player).w,a1
		bsr.s	Conv_MovePlayer
		lea	(v_player2).w,a1
		bsr.s	Conv_MovePlayer
		jmp	(MarkObjGone2).l
; ---------------------------------------------------------------------------

Conv_MovePlayer:
		tst.l	code(a1)
		beq.s	.return
		cmpi.b	#4,obRoutine(a1)
		bhs.s	.return
		btst	#status.player.in_air,obStatus(a1)
		bne.s	.return
		tst.b	conveyor_applied(a1)
		bne.s	.return
		move.w	conv_width(a0),d2
		move.w	d2,d3
		add.w	d3,d3
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d2,d0
		cmp.w	d3,d0
		bhs.s	.return
		move.w	obY(a1),d1
		sub.w	obY(a0),d1
		move.w	conv_height(a0),d0
		add.w	d0,d1
		cmp.w	d0,d1
		bhs.s	.return
		move.w	conv_speed(a0),d0
		beq.s	.return
		st	conveyor_applied(a1)	; adjacent/overlapping areas must not multiply the speed
		bsr.s	Conv_WallDistance
		move.w	conv_speed(a0),d0
		tst.w	d1
		bpl.s	.move
		tst.w	d0
		bmi.s	.left
		add.w	d1,d0
		bra.s	.move
.left:
		sub.w	d1,d0
.move:
		add.w	d0,obX(a1)
.return:
		rts
; ---------------------------------------------------------------------------
; Check the leading side at the proposed X position. The player has already
; run this frame, so its normal wall check cannot account for the belt's push.
; FindWall uses the player's collision path and leaves its own velocity alone.

Conv_WallDistance:
		move.l	a1,-(sp)
		move.l	(v_colladdr1).w,(Collision_addr).w
		cmpi.b	#$C,obTopSolidBit(a1)
		beq.s	.path
		move.l	(v_colladdr2).w,(Collision_addr).w
.path:
		move.b	obLRBSolidBit(a1),d5
		move.w	obY(a1),d2
		move.w	obX(a1),d3
		add.w	d0,d3
		moveq	#0,d1
		move.b	obWidth(a1),d1
		addq.w	#1,d1
		movea.w	#$10,a3
		clr.w	d6
		tst.w	d0
		bmi.s	.left
		add.w	d1,d3
		bra.s	.probe
.left:
		sub.w	d1,d3
		eori.w	#$F,d3
		movea.w	#-$10,a3
		move.w	#$400,d6
.probe:
		lea	(Primary_Angle).w,a4
		jsr	(FindWall).l
		movea.l	(sp)+,a1
		rts
