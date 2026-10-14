; Wheeled carrier derived from Sonic CD's ObjMovingSpring (scddisasm main).
; The mount table names any ordinary object routine and its subtype/flip.
; Payload code remains unchanged; the carrier owns position and lifetime.
wheel_child = objoff_30           ; long, child SST
wheel_type = objoff_34            ; long, expected child routine
wheel_old_x = objoff_38           ; word
wheel_old_y = objoff_3A           ; word
wheel_offset = objoff_3C          ; signed word, mount Y relative to axle
wheel_spawned = objoff_3E         ; byte; retries allocation until a child exists

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
        beq.s .ready
        neg.w obVelX(a0)
.ready:
        move.w obX(a0),wheel_old_x(a0)
        move.w obY(a0),wheel_old_y(a0)
        cmpi.b #2,obRoutine(a0)
        bne.s .roll
        jsr (ObjectMoveAndFall).l
        jsr (ObjHitFloor).l
        tst.w d1
        bpl.s .mount
        add.w d1,obY(a0)
        clr.w obVelY(a0)
        move.b #4,obRoutine(a0)
        bra.s .mount
.roll:
        jsr (ObjectMove).l
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
        lsl.w #3,d0
        lea (WheelPayloads).l,a2
        adda.w d0,a2
        move.l (a2)+,d0
        move.l d0,code(a1)
        move.l d0,wheel_type(a0)
        move.l a1,wheel_child(a0)
        move.w (a2)+,wheel_offset(a0)
        move.b (a2)+,obSubtype(a1)
        move.b (a2),obStatus(a1)
        move.b (a2),obRender(a1)
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

; Eight bytes per editable mount: routine, Y offset, subtype, facing flags.
WheelPayloads:
        dc.l Obj41
        dc.w -16
        dc.b $00,0             ; red up spring
        dc.l Obj41
        dc.w -16
        dc.b $02,0             ; yellow up spring
        dc.l Obj41
        dc.w -16
        dc.b $10,0             ; red side spring
        dc.l Obj41
        dc.w -16
        dc.b $12,1             ; yellow side spring facing left
        dc.l Obj41
        dc.w -16
        dc.b $30,0             ; red diagonal spring
        dc.l Obj26
        dc.w -21
        dc.b 4,0               ; ring monitor
        dc.l Obj26
        dc.w -21
        dc.b 6,0               ; shield monitor
        dc.l Obj36
        dc.w -15
        dc.b 0,0               ; upward spikes
WheelPayload_Count = (*-WheelPayloads)/8
