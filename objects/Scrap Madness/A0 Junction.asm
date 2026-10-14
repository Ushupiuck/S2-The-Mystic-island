; SBZ rotating junction: original frame/path timing, independent actor capture.
; Source geometry: sonicretro/s1disasm 2c51d46. Controls are per player;
; no global input lock can freeze the other character.
smz_jun_grab = objoff_32       ; two bytes, one captured frame per player
smz_jun_direction = objoff_34
smz_jun_pressed = objoff_36
smz_jun_switch = objoff_38

SMZ_Junction:
        tst.b obRoutine(a0)
        bne.w .ready
        move.b #2,obRoutine(a0)
        move.l #Map_SMZ_Jun,obMap(a0)
        move.b #Map_SMZ_Jun_height,height_pixels(a0)
        move.b #Map_SMZ_Jun_width,width_pixels(a0)
        move.w #ArtTile_SMZ_Atlas,obGfx(a0)
        move.b #4,obRender(a0)
        move.w #$200,obPriority(a0)
        move.b #1,smz_jun_direction(a0)
        move.b obSubtype(a0),smz_jun_switch(a0)
        jsr (FindFreeObj).l
        bne.w .ready
        move.l #SMZ_Junction,code(a1)
        move.b #4,obRoutine(a1)
        move.l obX(a0),obX(a1)
        move.l obY(a0),obY(a1)
        move.l obMap(a0),obMap(a1)
        move.b height_pixels(a0),height_pixels(a1)
        move.b width_pixels(a0),width_pixels(a1)
        move.w obGfx(a0),obGfx(a1)
        move.b #4,obRender(a1)
        move.w #$180,obPriority(a1)
        move.b #16,obFrame(a1)
.ready:
        cmpi.b #4,obRoutine(a0)
        beq.w .display
        moveq #0,d0
        move.b smz_jun_switch(a0),d0
        andi.w #15,d0
        lea (f_switch).w,a2
        btst #0,(a2,d0.w)
        beq.s .unpressed
        tst.b smz_jun_pressed(a0)
        bne.s .rotate
        neg.b smz_jun_direction(a0)
        move.b #1,smz_jun_pressed(a0)
        bra.s .rotate
.unpressed:
        clr.b smz_jun_pressed(a0)
.rotate:
        subq.b #1,obTimeFrame(a0)
        bpl.s .solid
        move.b #7,obTimeFrame(a0)
        move.b smz_jun_direction(a0),d0
        add.b obFrame(a0),d0
        andi.b #15,d0
        move.b d0,obFrame(a0)
.solid:
        moveq #48,d1
        moveq #48,d2
        moveq #49,d3
        move.w obX(a0),d4
        jsr (SolidObject).l
        lea (v_player).w,a1
        lea smz_jun_grab(a0),a3
        bsr.s .actor
        lea (v_player2).w,a1
        lea smz_jun_grab+1(a0),a3
        bsr.s .actor
.display:
        out_of_range2 .unload
        jmp (DisplaySprite).l
.actor:
        tst.b (a3)
        bne.s .captured
        cmpi.b #6,obRoutine(a1)
        bhs.w .return
        tst.b obControl(a1)
        bne.w .return
        btst #status.player.pushing,obStatus(a1)
        beq.w .return
        moveq #14,d0
        move.w obX(a1),d1
        cmp.w obX(a0),d1
        blo.s .entry
        moveq #7,d0
.entry:
        cmp.b obFrame(a0),d0
        bne.w .return
        move.b d0,(a3)
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
.captured:
        cmpi.b #6,obRoutine(a1)
        bhs.s .release
        move.b obFrame(a0),d0
        cmpi.b #4,d0
        beq.s .exit_frame
        cmpi.b #7,d0
        bne.s .position
.exit_frame:
        cmp.b (a3),d0
        beq.s .position
        clr.w obVelX(a1)
        move.w #$800,obVelY(a1)
        cmpi.b #7,d0
        bne.s .release
        move.w #$800,obVelX(a1)
.release:
        clr.b (a3)
        clr.b obControl(a1)
        rts
.position:
        moveq #0,d0
        move.b obFrame(a0),d0
        add.w d0,d0
        lea .offsets(pc,d0.w),a2
        move.b (a2)+,d0
        ext.w d0
        add.w obX(a0),d0
        move.w d0,obX(a1)
        move.b (a2),d0
        ext.w d0
        add.w obY(a0),d0
        move.w d0,obY(a1)
.return:
        rts
.unload:
        lea (v_player).w,a1
        lea smz_jun_grab(a0),a3
        tst.b (a3)
        beq.s .second
        bsr.s .release
.second:
        lea (v_player2).w,a1
        addq.w #1,a3
        tst.b (a3)
        beq.s .delete
        bsr.s .release
.delete:
        jmp (UnloadObject).l
.offsets:
        dc.b -$20,0,-$1E,$E,-$18,$18,-$E,$1E,0,$20,$E,$1E,$18,$18,$1E,$E
        dc.b $20,0,$1E,-$E,$18,-$18,$E,-$1E,0,-$20,-$E,-$1E,-$18,-$18,-$1E,-$E
        even
Map_SMZ_Jun: binclude "mappings/sprite/SMZ Jun.bin"
