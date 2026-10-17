; Release only riders still owned by this surface. Adjacent/overlapping solids
; can retain an old stood-on bit after the actor moves onto another SST.
SMZ_ReleaseRiders:
		lea	(v_player).w,a1
		moveq	#3,d6
		bsr.s	.one
		lea	(v_player2).w,a1
		moveq	#4,d6
.one:
		btst	d6,obStatus(a0)
		beq.s	.return
		bclr	d6,obStatus(a0)
		moveq	#0,d0
		move.b	standonobject(a1),d0
		mulu.w	#object_size,d0
		addi.l	#v_objspace,d0
		cmp.l	a0,d0
		bne.s	.return
		bclr	#status.player.on_object,obStatus(a1)
		bset	#status.player.in_air,obStatus(a1)
.return:
		rts
