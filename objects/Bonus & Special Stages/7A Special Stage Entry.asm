; ---------------------------------------------------------------------------
; Object 7A - Special Stage entry effect
; ---------------------------------------------------------------------------
; OST:
obj7A_vanishtime:	equ objoff_34		; time for Sonic to vanish for
; ---------------------------------------------------------------------------

SpecialStageEntry:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj7A_Index(pc,d0.w),d1
		jmp	Obj7A_Index(pc,d1.w)
; ===========================================================================
Obj7A_Index:	dc.w Obj7A_Init-Obj7A_Index
		dc.w Obj7A_RmvSonic-Obj7A_Index
		dc.w Obj7A_LoadSonic-Obj7A_Index
; ===========================================================================

Obj7A_Init:
		tst.l	(v_plc_buffer).w	; are the pattern load cues empty?
		beq.s	.continue		; if so, branch
.return:
		rts
; ---------------------------------------------------------------------------

.continue:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_SpecialWarp,obMap(a0)
		move.b	#Map_SpecialWarp_height,height_pixels(a0)
		move.b	#4,obRender(a0)
		move.w	#$80,obPriority(a0)
		move.b	#sprite_bound($38,Map_SpecialWarp_width),obActWid(a0)
		move.w	#make_art_tile(ArtTile_Warp,0,0),obGfx(a0)
		move.w	#60*2,obj7A_vanishtime(a0)	; set vanishing time to 2 seconds

Obj7A_RmvSonic:
		move.w	(v_player+obX).w,obX(a0)
		move.w	(v_player+obY).w,obY(a0)
		move.b	(v_player+obStatus).w,obStatus(a0)
		lea	Ani_obj7A(pc),a1
		jsr	(AnimateSprite).l
		cmpi.b	#2,obFrame(a0)
		bne.s	loc_1253E
		tst.l	(v_player+code).w		; is this Sonic?
		beq.s	loc_1253E			; if not, branch
		clr.l	(v_player+code).w		; set Sonic's object ID to 0
		move.w	#sfx_SSGoal,d0
		jsr	(PlaySound_Special).l		; play Special Stage entry sound effect

loc_1253E:
		jmp	(DisplaySprite).l
; ===========================================================================

Obj7A_LoadSonic:
		subq.w	#1,obj7A_vanishtime(a0)		; subtract 1 from vanishing time
		bne.s	Obj7A_Init.return		; if there's any time left, branch
		move.l	#Obj01,d0
		cmpi.w	#PlayerMode_Tails,(Player_mode).w
		bne.s	.restore
		move.l	#Obj02,d0
.restore:
		move.l	d0,(v_player+code).w	; restore the selected primary character
		jmp	(DeleteObject).l
; ---------------------------------------------------------------------------
Ani_obj7A:	dc.w byte_1278C-Ani_obj7A
byte_1278C:	dc.b   5,  0,  1,  0,  1,  0,  7,  1,  7,  2,  7,  3,  7,  4,  7,  5
		dc.b   7,  6,  7,$FC
		even
