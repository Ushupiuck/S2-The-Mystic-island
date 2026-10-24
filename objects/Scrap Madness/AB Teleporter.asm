; S1 SBZ pipe paths, with two independent control packets.
; Each actor keeps its own state, travel timer and path index in the parent.
smz_pipe_state = 0
smz_pipe_bump = 1
smz_pipe_time = 2
smz_pipe_x = 4
smz_pipe_y = 6
smz_pipe_index = 8
smz_pipe_packet = 10
smz_pipe_data = objoff_44
smz_pipe_length = objoff_48

SMZ_Teleport:
        tst.b obRoutine(a0)
        bne.s .ready
        move.b #2,obRoutine(a0)
        moveq #0,d0
        move.w obSubtype(a0),d0
        andi.w #7,d0
        add.w d0,d0
        lea SMZ_PipeData(pc),a2
        adda.w (a2,d0.w),a2
        move.w (a2)+,d0
        move.b d0,smz_pipe_length(a0)
        move.l a2,smz_pipe_data(a0)
.ready:
        lea (v_player).w,a1
        lea objoff_30(a0),a3
        bsr.w .actor
        lea (v_player2).w,a1
        lea objoff_30+smz_pipe_packet(a0),a3
        bsr.w .actor
        tst.b objoff_30(a0)
        bne.w .return
        tst.b objoff_30+smz_pipe_packet(a0)
        bne.w .return
        out_of_range2 UnloadObject
.return:
        rts
.actor:
        cmpi.b #6,obRoutine(a1)
        bhs.w .cancel
        tst.b smz_pipe_state(a3)
        beq.s .wait
        cmpi.b #1,smz_pipe_state(a3)
        beq.w .bump
        bra.w .travel
.wait:
        tst.b obControl(a1)
        bne.w .return
        tst.w (Debug_placement_mode).w
        bne.w .return
        move.w obX(a1),d0
        sub.w obX(a0),d0
        btst #0,obStatus(a0)
        beq.s .x
        addi.w #15,d0
.x:
        cmpi.w #16,d0
        bhs.s .return
        move.w obY(a1),d0
        sub.w obY(a0),d0
        addi.w #32,d0
        cmpi.w #64,d0
        bhs.s .return
        cmpi.w #7,obSubtype(a0)
        bne.s .start
        cmpi.w #50,(v_rings).w
        blo.s .return
.start:
        move.b #1,smz_pipe_state(a3)
        clr.b smz_pipe_bump(a3)
        clr.b smz_pipe_index(a3)
        movea.l smz_pipe_data(a0),a2
        move.w (a2)+,smz_pipe_x(a3)
        move.w (a2),smz_pipe_y(a3)
        move.b #$81,obControl(a1)
        move.b #2,obAnim(a1)
        move.w #$800,obInertia(a1)
        clr.w obVelX(a1)
        clr.w obVelY(a1)
        bclr #status.player.pushing,obStatus(a1)
        bclr #status.player.on_object,obStatus(a1)
        bset #status.player.in_air,obStatus(a1)
        clr.b jumping(a1)
        clr.b spindash_flag(a1)
        clr.b tails_flight_flag(a1)
        move.w obX(a0),obX(a1)
        move.w obY(a0),obY(a1)
        move.w #sfx_Roll,d0
        jmp (PlaySound_Special).l
.bump:
        moveq #0,d0
        move.b smz_pipe_bump(a3),d0
        addq.b #2,smz_pipe_bump(a3)
        jsr (CalcSine).l
        asr.w #5,d0
        move.w obY(a0),d2
        sub.w d0,d2
        move.w d2,obY(a1)
        cmpi.b #$80,smz_pipe_bump(a3)
        bne.w .return
        bsr.w SMZ_PipeDirection
        move.b #2,smz_pipe_state(a3)
        move.w #sfx_Teleport,d0
        jmp (PlaySound_Special).l
.travel:
        subq.b #1,smz_pipe_time(a3)
        bpl.s .move
        move.w smz_pipe_x(a3),obX(a1)
        move.w smz_pipe_y(a3),obY(a1)
        moveq #0,d1
        move.b smz_pipe_index(a3),d1
        addq.b #4,d1
        cmp.b smz_pipe_length(a0),d1
        bhs.s .exit
        move.b d1,smz_pipe_index(a3)
        movea.l smz_pipe_data(a0),a2
        move.w (a2,d1.w),smz_pipe_x(a3)
        move.w 2(a2,d1.w),smz_pipe_y(a3)
        jmp (SMZ_PipeDirection).l
.move:
        move.w obVelX(a1),d0
        ext.l d0
        asl.l #8,d0
        add.l d0,obX(a1)
        move.w obVelY(a1),d0
        ext.l d0
        asl.l #8,d0
        add.l d0,obY(a1)
        rts
.exit:
        andi.w #$7FF,obY(a1)
        clr.w obVelX(a1)
        move.w #$200,obVelY(a1)
.cancel:
        tst.b smz_pipe_state(a3)
        beq.s .done
        clr.b smz_pipe_state(a3)
        clr.b obControl(a1)
.done:
        rts

SMZ_PipeDirection:
        move.w smz_pipe_x(a3),d0
        sub.w obX(a1),d0
        move.w smz_pipe_y(a3),d1
        sub.w obY(a1),d1
        or.w d1,d0
        bne.s .nonzero
        clr.w smz_pipe_time(a3)
        clr.w obVelX(a1)
        clr.w obVelY(a1)
        rts
.nonzero:
		moveq	#0,d0					; clear d0 for X-difference
		move.w	#$1000,d2				; move Sonic horizontally at speed $1000 to the right
		move.w	smz_pipe_x(a3),d0			; get next teleport X-target
		sub.w	obX(a1),d0				; calculate difference to Sonic's current X-position
		bge.s	.getYDirection				; is Sonic's next target to the right or directly above? if yes, branch
		neg.w	d0					; negate X-difference
		neg.w	d2					; negate X-speed to move to the left instead

	.getYDirection:
		moveq	#0,d1					; clear d1 for Y-difference
		move.w	#$1000,d3				; move Sonic vertically at speed $1000 downwards
		move.w	smz_pipe_y(a3),d1			; get next teleport Y-target
		sub.w	obY(a1),d1				; calculate difference to Sonic's current Y-position
		bge.s	.checkHorizOrVert			; is Sonic's next target below or leveled? if yes, branch
		neg.w	d1					; negate Y-difference
		neg.w	d3					; negate Y-speed to move upwards instead

	.checkHorizOrVert:
		cmp.w	d0,d1					; is X-distance greater than Y-distance?
		bcs.s	SMZ_PipeDirection_X				; if yes, branch

; SMZ_PipeDirection_Y:
		moveq	#0,d1					; clear d1 again
		move.w	smz_pipe_y(a3),d1			; get next teleport Y-target
		sub.w	obY(a1),d1				; calculate difference to Sonic's current Y-position
		swap	d1					; move into upper word
		divs.w	d3,d1					; divide by $1000 or -$1000

		moveq	#0,d0					; clear d0 again
		move.w	smz_pipe_x(a3),d0			; get next teleport X-target
		sub.w	obX(a1),d0				; calculate difference to Sonic's current X-position
		beq.s	.setSpeeds				; if next X-target is the same as Sonic's current X-position, branch
		swap	d0					; move into upper word
		divs.w	d1,d0					; divide by earlier division result

	.setSpeeds:
		move.w	d0,obVelX(a1)				; set new X-speed
		move.w	d3,obVelY(a1)				; set new Y-speed

		tst.w	d1					; is next tele_time already positive?
		bpl.s	.setTravelTime				; if yes, branch
		neg.w	d1					; make it positive otherwise
	.setTravelTime:
		move.w	d1,smz_pipe_time(a3)			; set travel time until next target
		rts						; return
; ===========================================================================

SMZ_PipeDirection_X:
		moveq	#0,d0					; clear d1 again
		move.w	smz_pipe_x(a3),d0			; get next teleport X-target
		sub.w	obX(a1),d0				; calculate difference to Sonic's current X-position
		swap	d0					; move into upper word
		divs.w	d2,d0					; divide by $1000 or -$1000

		moveq	#0,d1					; clear d1 again
		move.w	smz_pipe_y(a3),d1			; get next teleport Y-target
		sub.w	obY(a1),d1				; calculate difference to Sonic's current Y-position
		beq.s	.y_match				; if next Y-target is the same as Sonic's current Y-position, branch
		swap	d1					; move into upper word
		divs.w	d0,d1					; divide by earlier division result

	.y_match:
		move.w	d1,obVelY(a1)				; set new Y-speed
		move.w	d2,obVelX(a1)				; set new X-speed

		tst.w	d0					; is next tele_time already positive?
		bpl.s	.setTravelTime				; if yes, branch
		neg.w	d0					; make it positive otherwise
	.setTravelTime:
		move.w	d0,smz_pipe_time(a3)			; set travel time until next target
		rts						; return
; End of function SMZ_PipeDirection


; ===========================================================================
; Teleporter target data for each tube in a tube network, per subtype.
; Format:
; 	dc.w number of entries (times 4)
; 	dc.w target X-position, target Y-position
;	dc.w ...


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
