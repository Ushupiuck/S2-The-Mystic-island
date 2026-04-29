; ---------------------------------------------------------------------------
; Morphing Platform
; ---------------------------------------------------------------------------
mplat_origin_x	= objoff_30
mplat_origin_y	= objoff_32
mplat_timer	= objoff_34
mplat_state	= objoff_35
; ---------------------------------------------------------------------------
MorphingPlatform:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	MorphingPlatform_Index(pc,d0.w),d0
		jsr	MorphingPlatform_Index(pc,d0.w)
		out_of_range.w	DeleteObject,mplat_origin_x(a0)
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------
MorphingPlatform_Index:
		dc.w MorphingPlatform_Init-MorphingPlatform_Index
		dc.w MorphingPlatform_Main-MorphingPlatform_Index
; ---------------------------------------------------------------------------

MorphingPlatform_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Mplat,obMap(a0)
		move.w	#make_art_tile(ArtTile_MorphingOrbs,0,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.w	#$180,obPriority(a0)
		move.w	obX(a0),mplat_origin_x(a0)
		move.w	obY(a0),mplat_origin_y(a0)
		; fall through
; ---------------------------------------------------------------------------

MorphingPlatform_Main:
		tst.b	mplat_timer(a0)
		beq.s	.load_state
		subq.b	#1,mplat_timer(a0)
		bne.s	.solid
		addq.b	#1,mplat_state(a0)
		cmpi.b	#$C,mplat_state(a0)
		bcs.s	.load_state
		clr.b	mplat_state(a0)
; ---------------------------------------------------------------------------

.load_state:
		moveq	#0,d0
		move.b	mplat_state(a0),d0
		add.b	d0,d0
		add.b	d0,d0
		lea	HVPlat_StateTable(pc,d0.w),a2
		move.b	(a2)+,obFrame(a0)
		move.b	(a2)+,mplat_timer(a0)
		move.b	(a2)+,obWidth(a0)
		move.b	(a2)+,obHeight(a0)
		move.b	obWidth(a0),obActWid(a0)	; top-standing width check
.solid:		moveq	#0,d1
		move.b	obWidth(a0),d1		; half-width / X radius
		move.b	obStatus(a0),d0		; load obStatus from the table
		andi.b	#18,d0			; and by Sonic/Tails standing bits
		bne.s	.no_extra_width		; if not being stood on, skip
		addi.w	#$10,d1			; otherwise, correct side collision

.no_extra_width:
		moveq	#0,d2
		move.b	obHeight(a0),d2		; half-height / Y radius
		move.w	d2,d3			; top-standing offset
		move.w	obX(a0),d4
		jmp	(SolidObject_MorphPlatform).l
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Morphing Platform script
; 0-2:  vertical platform, shrinking toward center orb
; 3-5:  center orb pause, then expanding horizontally
; 6-8:  horizontal platform, shrinking toward center orb
; 9-$B: center orb pause, then expanding vertically
; ---------------------------------------------------------------------------
;        frame, duration, collision width, collision height
HVPlat_StateTable:
		dc.b 0, $78,   8, $38	; full vertical platform, hold
		dc.b 1,   4,   8, $28	; vertical shrinking
		dc.b 2,   4,   8, $18	; vertical shrinking, near orb

		dc.b 3, $20,   8,   8	; center orb only, hold
		dc.b 4,   4, $18,   8	; horizontal expanding
		dc.b 5,   4, $28,   8	; horizontal expanding

		dc.b 6, $78, $38,   8	; full horizontal platform, hold
		dc.b 5,   4, $28,   8	; horizontal shrinking
		dc.b 4,   4, $18,   8	; horizontal shrinking, near orb

		dc.b 3, $20,   8,   8	; center orb only, hold
 if FixBugs=1
		dc.b 2,   4,   8, $18	; vertical expanding, near orb
		dc.b 1,   4,   8, $28	; vertical expanding
 else		; Bug: The last 2 entries are inverted
		dc.b 2,   4, $18,   8	; vertical expanding, near orb
		dc.b 1,   4, $28,   8	; vertical expanding
 endif
		even