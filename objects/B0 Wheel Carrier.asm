; Wheeled carrier derived from Sonic CD's ObjMovingSpring (scddisasm main).
; The mount table names any ordinary object routine and its subtype/flip.
; Payload code remains unchanged; the carrier owns position and lifetime.
wheel_child = objoff_30           ; long, child SST
wheel_type = objoff_34            ; long, expected child routine
wheel_old_x = objoff_38           ; word
wheel_old_y = objoff_3A           ; word
wheel_offset = objoff_3C          ; signed word, mount Y relative to axle
wheel_spawned = objoff_3E         ; byte; retries allocation until a child exists
wheel_payload_x = objoff_2E		; signed bytes: left/right bounds, right exclusive
wheel_payload_y = obAngle		; signed bytes: top/bottom bounds, bottom exclusive

WheelCarrier:
        tst.b obRoutine(a0)
        bne.s .ready
        move.b #2,obRoutine(a0)
        move.l #Map_MovSpring,obMap(a0)
        move.b #Map_MovSpring_height,height_pixels(a0)
        move.b #Map_MovSpring_width,width_pixels(a0)
        move.w #ArtTile_Wheel,obGfx(a0)
        move.b #4,obRender(a0)
        move.w #$200,obPriority(a0)
        move.b #8,obWidth(a0)
        move.b #7,obHeight(a0)
        move.w #$180,obVelX(a0)
        btst #0,obStatus(a0)
		beq.w	.mount
        neg.w obVelX(a0)
		bra.w	.mount		; mount the payload before the first movement/wall check
.ready:
        move.w obX(a0),wheel_old_x(a0)
        move.w obY(a0),wheel_old_y(a0)
        cmpi.b #2,obRoutine(a0)
        bne.s .roll
        jsr (ObjectMoveAndFall).l
		bsr.w	.wall
		bmi.s	.reverse
        jsr (ObjHitFloor).l
        bpl.s .mount
        add.w d1,obY(a0)
        clr.w obVelY(a0)
        move.b #4,obRoutine(a0)
        bra.s .mount
.roll:
        jsr (ObjectMove).l
		bsr.w	.wall
		bmi.s	.reverse
        jsr (ObjHitFloor).l
        cmpi.w #12,d1
        bgt.s .reverse
        cmpi.w #-12,d1
        blt.s .reverse
        add.w d1,obY(a0)
        bra.s .mount
.reverse:
        move.w wheel_old_x(a0),obX(a0)
        move.w wheel_old_y(a0),obY(a0)
        neg.w obVelX(a0)
        bchg #0,obStatus(a0)
.mount:
        tst.b wheel_spawned(a0)
        bne.s .carry
        jsr (FindFreeObj).l
        bne.w .draw
        moveq #0,d0
        move.b obSubtype(a0),d0
        andi.w #15,d0
        cmpi.w #WheelPayload_Count,d0
        blo.s .config
        moveq #0,d0
.config:
		mulu.w	#WheelPayload_size,d0
        lea (WheelPayloads).l,a2
        adda.w d0,a2
        move.l (a2)+,d0
        move.l d0,code(a1)
        move.l d0,wheel_type(a0)
        move.l a1,wheel_child(a0)
        move.w (a2)+,wheel_offset(a0)
        move.b (a2)+,obSubtype(a1)
        move.b (a2),obStatus(a1)
        move.b (a2)+,obRender(a1)
		move.w	(a2)+,wheel_payload_x(a0)
		move.w	(a2),wheel_payload_y(a0)
        move.w respawn_addr(a0),respawn_addr(a1)
        move.b #1,wheel_spawned(a0)
        bra.s .position
.carry:
        movea.l wheel_child(a0),a1
        move.l a1,d0
        beq.s .draw
        move.l code(a1),d0
        cmp.l wheel_type(a0),d0
        bne.s .consumed
        move.w respawn_addr(a1),d0
        cmp.w respawn_addr(a0),d0
        bne.s .consumed
        movea.l a1,a2
        lea (v_player).w,a1
        bsr.s .rider
        lea (v_player2).w,a1
        bsr.s .rider
        movea.l a2,a1
.position:
        move.l obX(a0),obX(a1)
        moveq #0,d0
        move.w wheel_offset(a0),d0
        swap d0
        add.l obY(a0),d0
        move.l d0,obY(a1)
        clr.w obVelX(a1)
        clr.w obVelY(a1)
        bra.s .draw
.consumed:
        clr.l wheel_child(a0)
        ; A destroyed monitor must not become a new monitor on backtracking.
        clr.w respawn_addr(a0)
.draw:
        lea (Ani_MovSpring).l,a1
        jsr (AnimateSprite).l
        out_of_range2 .unload
        jmp (DisplaySprite).l
.rider:
        tst.b obControl(a1)
        bmi.s .return
        btst #status.player.on_object,obStatus(a1)
        beq.s .return
        moveq #0,d0
        move.b standonobject(a1),d0
        mulu.w #object_size,d0
        addi.l #v_objspace,d0
        cmp.l a2,d0
        bne.s .return
        move.w obX(a0),d0
        sub.w wheel_old_x(a0),d0
        add.w d0,obX(a1)
        move.w obY(a0),d0
        sub.w wheel_old_y(a0),d0
        add.w d0,obY(a1)
.return:
        rts
.unload:
        movea.l wheel_child(a0),a1
        move.l a1,d0
        beq.s .delete
        move.l code(a1),d0
        cmp.l wheel_type(a0),d0
        bne.s .delete
        move.w respawn_addr(a1),d0
        cmp.w respawn_addr(a0),d0
        bne.s .delete
        move.l a0,-(sp)
        movea.l a1,a0
        jsr (SMZ_ReleaseRiders).l
        movea.l a0,a1
        movea.l (sp)+,a0
        jsr (DeleteObject2).l
.delete:
        jmp (UnloadObject).l

; Use the existing directional wall probes, as Splats does. Probe the upper
; rim so traversable steps/slopes are still handled by the floor check.
.wall:
		subq.w	#8,obY(a0)
		moveq	#8,d3
		tst.w	obVelX(a0)
		bmi.s	.leftwall
		jsr	(ObjHitWallRight).l
		bra.s	.walltested
.leftwall:
		not.w	d3
		jsr	(ObjHitWallLeft).l
.walltested:
		addq.w	#8,obY(a0)
		tst.w	d1
		bmi.w	.wallreturn
		movea.l	wheel_child(a0),a1
		move.l	a1,d0
		beq.w	.wallreturn
		move.l	code(a1),d0
		cmp.l	wheel_type(a0),d0
		bne.w	.wallreturn
		cmpi.l	#Obj26,d0
		bne.s	.payloadlive
		cmpi.b	#4,obRoutine(a1)	; the carried shell has no intact monitor collision
		bhs.w	.wallreturn
.payloadlive:
		move.w	respawn_addr(a1),d0
		cmp.w	respawn_addr(a0),d0
		bne.w	.wallreturn
		; Check the payload at its own height. Eight-pixel spacing also
		; catches low overhangs that do not meet the wheels themselves.
		movem.l	d7/a5-a6,-(sp)
		move.w	obY(a0),-(sp)
		move.b	wheel_payload_y(a0),d7
		ext.w	d7
		add.w	wheel_offset(a0),d7
		add.w	obY(a0),d7
		move.b	wheel_payload_y+1(a0),d0
		ext.w	d0
		add.w	wheel_offset(a0),d0
		add.w	obY(a0),d0
		subq.w	#1,d0
		movea.w	d0,a5
		move.b	wheel_payload_x+1(a0),d0
		tst.w	obVelX(a0)
		bpl.s	.payloadside
		move.b	wheel_payload_x(a0),d0
		subq.b	#1,d0
.payloadside:
		ext.w	d0
		movea.w	d0,a6
.payloadwall:
		move.w	d7,obY(a0)
		move.w	a6,d3
		tst.w	obVelX(a0)
		bmi.s	.payloadleft
		jsr	(ObjHitWallRight).l
		bra.s	.payloadtested
.payloadleft:
		jsr	(ObjHitWallLeft).l
.payloadtested:
		tst.w	d1
		bmi.s	.payloadreturn
		cmp.w	a5,d7
		beq.s	.payloadreturn
		addq.w	#8,d7
		cmp.w	a5,d7
		ble.s	.payloadwall
		move.w	a5,d7
		bra.s	.payloadwall
.payloadreturn:
		move.w	(sp)+,obY(a0)
		movem.l	(sp)+,d7/a5-a6
.wallreturn:
		tst.w	d1
		rts

; Routine, Y offset, subtype, facing flags, then the payload's collision box
; relative to its center (left/right/top/bottom). Right/bottom are exclusive.
; Bounds include the table's facing flags; the carrier's flip only steers it.
WheelPayload_size = 12
WheelPayloads:
        dc.l Obj41
        dc.w -16
        dc.b $00,0             ; red up spring
		dc.b	-16,16,-8,8
        dc.l Obj41
        dc.w -16
        dc.b $02,0             ; yellow up spring
		dc.b	-16,16,-8,8
        dc.l Obj41
        dc.w -16
        dc.b $10,0             ; red side spring
		dc.b	-8,8,-16,16
        dc.l Obj41
        dc.w -16
        dc.b $12,1             ; yellow side spring facing left
		dc.b	-8,8,-16,16
        dc.l Obj41
        dc.w -16
        dc.b $30,0             ; red diagonal spring
		dc.b	-21,11,-15,17
        dc.l Obj26
        dc.w -21
        dc.b 4,0               ; ring monitor
		dc.b	-16,16,-17,15
        dc.l Obj26
        dc.w -21
        dc.b 6,0               ; shield monitor
		dc.b	-16,16,-17,15
        dc.l Obj36
        dc.w -15
		dc.b	$A0,0		; single S1 upward spike
		dc.b	-4,4,-16,16
WheelPayload_Count = (*-WheelPayloads)/WheelPayload_size
