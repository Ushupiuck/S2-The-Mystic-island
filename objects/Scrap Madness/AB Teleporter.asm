; Shared automatic pipes with independent actor packets.
; S1 entrances bounce before travel. The direct entrances use instant
; capture and retain exit velocity. $180 is a four-way steering junction.
smz_pipe_state = 0
smz_pipe_bump = 1
smz_pipe_index = 8
smz_pipe_packet = 10
smz_pipe_data = objoff_44
smz_pipe_length = objoff_48

SMZ_Teleport:
		move.b	#2,obRoutine(a0)
		moveq	#0,d0
		move.w	obSubtype(a0),d0
		btst	#8,d0
		bne.s	.direct
		andi.w	#7,d0
		lea	SMZ_PipeData(pc),a2
		bra.s	.lookup
.direct:
		andi.w	#$3F,d0
		beq.s	.junction
		lea	MMZ_PipeData(pc),a2
		cmp.w	(a2)+,d0
		bhs.s	.junction
.lookup:
		add.w	d0,d0
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,d0
		bra.s	.store
.junction:
		moveq	#0,d0
		suba.l	a2,a2
.store:
		move.b	d0,smz_pipe_length(a0)
		move.l	a2,smz_pipe_data(a0)
		move.l	#SMZ_Teleport_Main,code(a0)

SMZ_Teleport_Main:
		lea	(v_player).w,a1
		lea	objoff_30(a0),a3
		bsr.w	.actor
		lea	(v_player2).w,a1
		lea	objoff_30+smz_pipe_packet(a0),a3
		bsr.w	.actor
		tst.b	objoff_30(a0)
		bne.w	.return
		tst.b	objoff_30+smz_pipe_packet(a0)
		bne.w	.return
		out_of_range2	UnloadObject
.return:
		rts
.actor:
		tst.l	code(a1)
		beq.w	.cancel
		cmpi.b	#6,obRoutine(a1)
		bhs.w	.cancel
		tst.b	smz_pipe_state(a3)
		beq.s	.wait
		cmpi.b	#1,smz_pipe_state(a3)
		beq.w	.bump
		cmpi.b	#3,smz_pipe_state(a3)
		beq.w	.steer
		bra.w	.travel
.wait:
		tst.b	obControl(a1)
		bne.w	.return
		tst.w	(Debug_placement_mode).w
		bne.w	.return
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		btst	#0,obSubtype(a0)		; direct MMZ entrance
		bne.s	.direct_entry
		btst	#0,obStatus(a0)
		beq.s	.x
		addi.w	#15,d0
.x:
		cmpi.w	#16,d0
		bhs.s	.return
		move.w	obY(a1),d0
		sub.w	obY(a0),d0
		addi.w	#32,d0
		cmpi.w	#64,d0
		bhs.s	.return
		cmpi.w	#7,obSubtype(a0)
		bne.s	.start
		cmpi.w	#50,(v_rings).w
		blo.s	.return
		bra.s	.start
.direct_entry:
		addi.w	#16,d0
		cmpi.w	#32,d0
		bhs.w	.return
		move.w	obY(a1),d0
		sub.w	obY(a0),d0
		addi.w	#16,d0
		cmpi.w	#32,d0
		bhs.w	.return
.start:
		; Recoil runs outside the object-control lock. End it before the pipe moves the actor.
		cmpi.b	#4,obRoutine(a1)
		bne.s	.capture
		subq.b	#2,obRoutine(a1)
		move.w	#Player_HurtFlashTime,flashtime(a1)
.capture:
		move.b	#1,smz_pipe_state(a3)
		clr.b	smz_pipe_bump(a3)
		clr.b	smz_pipe_index(a3)
		move.b	#$81,obControl(a1)
		move.b	#AniIDSonAni_Roll,obAnim(a1)
		move.w	#$800,obInertia(a1)
		clr.w	obVelX(a1)
		clr.w	obVelY(a1)
		bclr	#status.player.pushing,obStatus(a1)
		bclr	#status.player.on_object,obStatus(a1)
		bset	#status.player.in_air,obStatus(a1)
		clr.b	jumping(a1)
		clr.b	spindash_flag(a1)
		clr.b	tails_flight_flag(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		tst.b	smz_pipe_length(a0)
		beq.s	.wait_direction
		movea.l	smz_pipe_data(a0),a2
		move.w	(a2)+,autopath_target_x(a3)
		move.w	(a2),autopath_target_y(a3)
		btst	#0,obSubtype(a0)
		bne.s	.begin_direct
.sound:
		move.w	#SndID_Roll,d0
		jmp	(PlaySound_Special).l
.wait_direction:
		move.b	#3,smz_pipe_state(a3)
		bra.s	.hide
.begin_direct:
		move.b	#2,smz_pipe_state(a3)
		move.w	#$1000,d2
		jsr	(AutoTunnel_CalcSpeed).l
.hide:
		bclr	#7,obGfx(a1)
		bra.s	.sound

.steer:
		move.b	(v_jpadholdlogical).w,d0
		cmpa.w	#v_player,a1
		beq.s	.input
		move.b	(v_jpadholdlogical2).w,d0
.input:
		andi.w	#$F,d0
		beq.w	.return
		move.w	obX(a0),d1
		move.w	obY(a0),d2
		btst	#button_up,d0
		beq.s	.down
		subi.w	#16,d2
		bra.s	.target
.down:
		btst	#button_down,d0
		beq.s	.horizontal
		addi.w	#16,d2
		bra.s	.target
.horizontal:
		btst	#button_left,d0
		beq.s	.right
		subi.w	#16,d1
		bra.s	.target
.right:
		addi.w	#16,d1
.target:
		move.w	d1,autopath_target_x(a3)
		move.w	d2,autopath_target_y(a3)
		bra.s	.begin_direct
.bump:
		moveq	#0,d0
		move.b	smz_pipe_bump(a3),d0
		addq.b	#2,smz_pipe_bump(a3)
		jsr	(CalcSine).l
		asr.w	#5,d0
		move.w	obY(a0),d2
		sub.w	d0,d2
		move.w	d2,obY(a1)
		cmpi.b	#$80,smz_pipe_bump(a3)
		bne.w	.return
		move.w	#$1000,d2
		bsr.w	AutoTunnel_CalcSpeed
		move.b	#2,smz_pipe_state(a3)
		move.w	#SndID_SpindashRelease,d0
		jmp	(PlaySound_Special).l
.travel:
		subq.b	#1,autopath_time(a3)
		bpl.s	.move
		move.w	autopath_target_x(a3),obX(a1)
		move.w	autopath_target_y(a3),obY(a1)
		moveq	#0,d1
		move.b	smz_pipe_index(a3),d1
		addq.b	#4,d1
		cmp.b	smz_pipe_length(a0),d1
		bhs.s	.exit
		move.b	d1,smz_pipe_index(a3)
		movea.l	smz_pipe_data(a0),a2
		adda.w	d1,a2
		move.w	#$1000,d2
		jmp	(AutoTunnel_GetPath).l
.move:
		move.w	obVelX(a1),d0
		ext.l	d0
		asl.l	#8,d0
		add.l	d0,obX(a1)
		move.w	obVelY(a1),d0
		ext.l	d0
		asl.l	#8,d0
		add.l	d0,obY(a1)
		rts
.exit:
		andi.w	#Level_YWrapMask,obY(a1)
		btst	#0,obSubtype(a0)
		beq.s	.legacy_exit
		cmpi.b	#$C,obTopSolidBit(a1)
		bne.s	.cancel
		bset	#7,obGfx(a1)
		bra.s	.cancel
.legacy_exit:
		clr.w	obVelX(a1)
		move.w	#$200,obVelY(a1)
.cancel:
		tst.b	smz_pipe_state(a3)
		beq.s	.done
		clr.b	smz_pipe_state(a3)
		clr.b	obControl(a1)
.done:
		rts




; ===========================================================================
; Teleporter target data for each tube in a tube network, per subtype.
; Format:
; 	dc.w number of entries (times 4)
; 	dc.w target X-position, target Y-position
;	dc.w ...


MMZ_PipeData:
		binclude	"level/objects/MMZ2 Tunnel Paths.bin"
		even

SMZ_PipeData:	dc.w .type00-SMZ_PipeData
		dc.w .type01-SMZ_PipeData
		dc.w .type02-SMZ_PipeData
		dc.w .type03-SMZ_PipeData
		dc.w .type04-SMZ_PipeData
		dc.w .type05-SMZ_PipeData
		dc.w .type06-SMZ_PipeData
		dc.w .type07-SMZ_PipeData

.type00:	dc.w 1*4
		dc.w $794, $98C

.type01:	dc.w 1*4
		dc.w $94, $38C

.type02:	dc.w 7*4
		dc.w $794, $2E8
		dc.w $7A4, $2C0
		dc.w $7D0, $2AC
		dc.w $858, $2AC
		dc.w $884, $298
		dc.w $894, $270
		dc.w $894, $190

.type03:	dc.w 1*4
		dc.w $894, $690

.type04:	dc.w 7*4
		dc.w $1194, $470
		dc.w $1184, $498
		dc.w $1158, $4AC
		dc.w $FD0, $4AC
		dc.w $FA4, $4C0
		dc.w $F94, $4E8
		dc.w $F94, $590

.type05:	dc.w 1*4
		dc.w $1294, $490

.type06:	dc.w 7*4
		dc.w $1594, $FFE8
		dc.w $1584, $FFC0
		dc.w $1560, $FFAC
		dc.w $14D0, $FFAC
		dc.w $14A4, $FF98
		dc.w $1494, $FF70
		dc.w $1494, $FD90

.type07:	dc.w 1*4
		dc.w $894, $90
