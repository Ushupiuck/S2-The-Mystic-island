; Original SBZ momentary switches, using both engine rider bits.
SMZ_Button:
        tst.b obRoutine(a0)
        bne.s .active
        move.b #2,obRoutine(a0)
        move.l #Map_SMZ_But,obMap(a0)
        move.b #Map_SMZ_But_height,height_pixels(a0)
        move.b #Map_SMZ_But_width,width_pixels(a0)
        move.w #ArtTile_SMZ_Atlas,obGfx(a0)
        move.b #4,obRender(a0)
        move.w #$200,obPriority(a0)
        addq.w #3,obY(a0)
.active:
        moveq #27,d1
        moveq #5,d2
        moveq #5,d3
        move.w obX(a0),d4
        jsr (SolidObject).l
        moveq #0,d0
        move.w obSubtype(a0),d0
        andi.w #15,d0
        lea (f_switch).w,a3
        adda.w d0,a3
        clr.b obFrame(a0)
        move.b obStatus(a0),d0
        andi.b #$18,d0
        beq.s .off
        tst.b (a3)
        bne.s .on
        move.w #sfx_Switch,d0
        jsr (PlaySound_Special).l
.on:
        bset #0,(a3)
        move.b #1,obFrame(a0)
        jmp (RememberState).l
.off:
        bclr #0,(a3)
        jmp (RememberState).l
Map_SMZ_But: binclude "mappings/sprite/SMZ But.bin"
