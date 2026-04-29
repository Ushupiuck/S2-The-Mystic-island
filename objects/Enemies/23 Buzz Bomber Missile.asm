; ===========================================================================
; ---------------------------------------------------------------------------
; Object 23 - Buzz Bomber/Newtron missile
; ---------------------------------------------------------------------------
obj23_parent	= objoff_3C
; ---------------------------------------------------------------------------

Obj23:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj23_Index(pc,d0.w),d1
		jmp	Obj23_Index(pc,d1.w)
; ===========================================================================
Obj23_Index:	dc.w Obj23_Init-Obj23_Index	; 0
		dc.w Obj23_Animate-Obj23_Index	; 2
		dc.w Obj23_Move-Obj23_Index	; 4
		dc.w DeleteObject-Obj23_Index	; 6 ; small tweak to remove an optional jmpto
		dc.w Obj23_Newtron-Obj23_Index	; 8
; ===========================================================================
; loc_A576:
Obj23_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_obj23,obMap(a0)
		move.w	#make_art_tile(ArtTile_Buzz_Bomber,1,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$180,obPriority(a0)
		move.b	#8,obActWid(a0)
		andi.b	#3,obStatus(a0)
		tst.b	obSubtype(a0)			; was the object created by a Newtron?
		beq.s	Obj23_Animate			; if not, branch
		move.b	#8,obRoutine(a0)
		move.b	#$87,obColType(a0)
		move.b	#1,obAnim(a0)
		lea	Ani_obj23(pc),a1
		bsr.w	AnimateSprite
		bra.w	DisplaySprite
; ===========================================================================
; loc_A5C4:
Obj23_Animate:
		movea.l	obj23_parent(a0),a1
		_cmpi.b	#id_ObjFC,obID(a1)			; is Buzz Bomber destroyed?
		beq.w	DeleteObject			; if yes, branch
		lea	Ani_obj23(pc),a1
		bsr.w	AnimateSprite
		bra.w	DisplaySprite
; ===========================================================================
; loc_A5EC:
Obj23_Move:
		move.b	#$87,obColType(a0)
		move.b	#1,obAnim(a0)
		bsr.w	ObjectMove
		lea	Ani_obj23(pc),a1
		bsr.w	AnimateSprite
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		bcs.w	DeleteObject
		bra.w	DisplaySprite
; ===========================================================================
; loc_A630:
;Obj23_Delete:
	;	bra.w	DeleteObject
; ===========================================================================
; loc_A634:
Obj23_Newtron:
		tst.b	obRender(a0)
		bpl.w	DeleteObject
		bsr.w	ObjectMove
		lea	Ani_obj23(pc),a1
		bsr.w	AnimateSprite
		bra.w	DisplaySprite
; ===========================================================================
; animation script
Ani_obj23:	dc.w byte_A662-Ani_obj23
		dc.w byte_A666-Ani_obj23
byte_A662:	dc.b   7,  0,  1,afRoutine
byte_A666:	dc.b   1,  2,  3,afEnd
		even