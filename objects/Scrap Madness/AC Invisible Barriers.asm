; Ported from sonicretro/s1disasm 2c51d46 (REV01).
; Six-byte mappings, full code pointers, S3&K placement ownership.
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 71 - invisible solid barriers
; ---------------------------------------------------------------------------

SMZ_Invisibarrier:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	SMZ_Invis_Index(pc,d0.w),d1
		jmp	SMZ_Invis_Index(pc,d1.w)
; ===========================================================================
SMZ_Invis_Index:	dc.w SMZ_Invis_Main-SMZ_Invis_Index
		dc.w SMZ_Invis_Solid-SMZ_Invis_Index
; ===========================================================================

SMZ_Invis_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)		; advance to SMZ_Invis_Solid
		move.l	#Map_SMZ_Invis,obMap(a0)
		move.b #Map_SMZ_Invis_height,height_pixels(a0)		; set mappings (debug mode only)
		move.w	#ArtTile_Monitor|$8000,obGfx(a0) ; set art tile and priority bit (debug mode only)
		ori.b	#4,obRender(a0)	; set to playfield-positioned mode

		move.b	obSubtype(a0),d0		; get width/height settings for block
		move.b	d0,d1				; copy for height
		andi.w	#$F0,d0				; read only the 1st byte
		addi.w	#$10,d0				; settings are 0-based, actual sizes are 1-based
		lsr.w	#1,d0				; divide by 2 ($10px per digit, obActWid is halved)
		move.b	d0,obActWid(a0)			; set object width
		andi.w	#$F,d1				; read only the 2nd byte
		addq.w	#1,d1				; settings are 0-based, actual sizes are 1-based
		lsl.w	#3,d1				; multiply by 8 ($10px per setting, obHeight is halved)
		move.b	d1,obHeight(a0)			; set object height
; ---------------------------------------------------------------------------

SMZ_Invis_Solid:
        moveq #0,d1
        move.b obActWid(a0),d1
        addi.w #sonic_solid_width,d1
        moveq #0,d2
        move.b obHeight(a0),d2
        move.w d2,d3
        addq.w #1,d3
        move.w obX(a0),d4
        jsr (SolidObject_Always).l
        out_of_range2 UnloadObject
        tst.w (Debug_placement_mode).w
        jne DisplaySprite
        rts
Map_SMZ_Invis: binclude "mappings/sprite/SMZ Invis.bin"
