; ===========================================================================
; ----------------------------------------------------------------------------
; Object 78 - CPZ staircase blocks
; ----------------------------------------------------------------------------
;
; Layout:
; - Parent object controls the staircase state and per-step Y offsets
; - 4 child blocks read their assigned Y-offset entry from the parent
; - Child blocks report collision/touch info back to the parent
; ----------------------------------------------------------------------------

stair_wait_time		= objoff_2C	; frames remaining before changing staircase state
stair_touch_flags	= objoff_2E	; accumulated touch/collision flags from child blocks
stair_yoff_slot		= objoff_2F	; offset of this child's Y-offset entry in parent ($34/$36/$38/$3A)

stair_origX		= objoff_30	; original X position
stair_origY		= objoff_32	; original Y position

stair_yoff_table	= objoff_34	; 4-word Y-offset table for the staircase steps
stair_yoff_0		= objoff_34	; Y offset for step 0
stair_yoff_1		= objoff_36	; Y offset for step 1
stair_yoff_2		= objoff_38	; Y offset for step 2
stair_yoff_3		= objoff_3A	; Y offset for step 3

stair_parent		= objoff_3C	; pointer to parent staircase object

Obj78:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj78_StateIndex(pc,d0.w),d1
		jsr	Obj78_StateIndex(pc,d1.w)
		move.w	stair_origX(a0),d0
		jmp	(MarkObjGone3).l

; ===========================================================================
Obj78_StateIndex:	offsetTable
		offsetTableEntry.w Obj78_Init		; 0
		offsetTableEntry.w Obj78_Main		; 2
		offsetTableEntry.w Obj78_Solid		; 4
; ===========================================================================
Obj78_Init:
		addq.b	#2,obRoutine(a0)
		ori.b	#4,obRender(a0)
		move.b	obSubtype(a0),d0
		andi.w	#7,d0
		cmpi.w	#4,d0
		blo.s	+
		bchg	#0,obRender(a0)
+
		btst	#1,obRender(a0)
		beq.s	+
		bchg	#0,obRender(a0)
+
		moveq	#stair_yoff_0,d3			; first Y-offset slot in parent table
		moveq	#2,d4					; advance by 2 bytes per entry (word table)
		btst	#0,obStatus(a0)				; is object flipped?
		beq.s	.notflipped
		moveq	#stair_yoff_3,d3			; start from final Y-offset slot
		moveq	#-2,d4					; iterate backwards through word table

.notflipped:
		move.w	obX(a0),d2
		movea.l	a0,a1					; current object becomes first stair block
		moveq	#3,d1					; spawn 3 additional blocks
		bra.s	Obj78_LoadBlock
; ===========================================================================
Obj78_SpawnLoop:
		jsr	FindNextFreeObj
		bne.w	Obj78_Main
		move.b	#4,obRoutine(a1)			; child blocks start at Obj78_Solid

Obj78_LoadBlock:
		_move.b	obID(a0),obID(a1)			; load Obj78
		move.l	#Obj6B_MapUnc_2800E,mappings(a1)
		move.w	#make_art_tile(ArtTile_ArtNem_CPZStairBlock,3,0),obGfx(a1)
		move.b	obRender(a0),obRender(a1)
		move.w	#$180,obPriority(a1)
		move.b	#$10,obActWid(a1)
		move.b	obSubtype(a0),obSubtype(a1)
		move.w	d2,obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	obX(a0),stair_origX(a1)
		move.w	obY(a1),stair_origY(a1)
		addi.w	#$20,d2					; next block is 32px to the right
		move.b	d3,stair_yoff_slot(a1)			; child's assigned slot in parent Y-offset table
		move.l	a0,stair_parent(a1)
		add.b	d4,d3					; next slot in table
		dbf	d1,Obj78_SpawnLoop
; ===========================================================================
Obj78_Main:
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		andi.w	#7,d0					; read subtype bits 0-2 only
		add.w	d0,d0
		move.w	Obj78_ModeIndex(pc,d0.w),d1
		jsr	Obj78_ModeIndex(pc,d1.w)

Obj78_Solid:
		movea.l	stair_parent(a0),a2			; parent staircase object
		moveq	#0,d0
		move.b	stair_yoff_slot(a0),d0			; slot in parent's Y-offset table
		move.w	(a2,d0.w),d0				; read this block's Y offset
		add.w	stair_origY(a0),d0
		move.w	d0,obY(a0)
		moveq	#$1B,d1	; obActWid+10
		moveq	#$10,d2
		moveq	#$11,d3
		move.w	obX(a0),d4
		jsr	(SolidObject).l
		swap	d6
		or.b	d6,stair_touch_flags(a2)			; merge touch info into parent
		rts
; ===========================================================================
Obj78_ModeIndex:	offsetTable
		offsetTableEntry.w Obj78_WaitTopTrigger		; 0
		offsetTableEntry.w Obj78_AdvancePositive	; 1
		offsetTableEntry.w Obj78_WaitBottomTrigger	; 2
		offsetTableEntry.w Obj78_AdvancePositive	; 3
		offsetTableEntry.w Obj78_WaitTopTrigger		; 4
		offsetTableEntry.w Obj78_AdvanceNegative	; 5
		offsetTableEntry.w Obj78_WaitBottomTrigger	; 6
		offsetTableEntry.w Obj78_AdvanceNegative	; 7
; ===========================================================================
; Wait for top contact, then delay before advancing to next subtype
Obj78_WaitTopTrigger:
		tst.w	stair_wait_time(a0)
		bne.s	.countdown
		move.b	stair_touch_flags(a0),d0
		andi.b	#touch_top_mask,d0
		beq.s	.return
		move.w	#$1E,stair_wait_time(a0)
		rts

.countdown:
		subq.w	#1,stair_wait_time(a0)
		bne.s	.return
		addq.b	#1,obSubtype(a0)
.return:	rts
; ===========================================================================
; Wait for bottom contact, then delay before advancing to next subtype.
; While counting down, alternate step offsets between 0 and 1.
Obj78_WaitBottomTrigger:
		tst.w	stair_wait_time(a0)
		bne.s	.countdown
		move.b	stair_touch_flags(a0),d0
		andi.b	#touch_bottom_mask,d0
		beq.s	.return
		move.w	#60,stair_wait_time(a0)
		rts

.countdown:
		subq.w	#1,stair_wait_time(a0)
		bne.s	.jiggle
		addq.b	#1,obSubtype(a0)
		rts

.jiggle:
		lea	stair_yoff_table(a0),a1
		move.w	stair_wait_time(a0),d0
		lsr.b	#2,d0
		andi.b	#1,d0					; toggle every 8 frames
		move.w	d0,(a1)+
		eori.b	#1,d0
		move.w	d0,(a1)+
		move.w	d0,(a1)+
		eori.b	#1,d0
		move.w	d0,(a1)+
		rts
; ===========================================================================
; Move staircase in positive direction until first step reaches +$80
Obj78_AdvancePositive:
		lea	stair_yoff_table(a0),a1
		cmpi.w	#$80,(a1)
		beq.s	.return

		addq.w	#1,(a1)					; step 0 moves fastest
		moveq	#0,d1
		move.w	(a1)+,d1
		swap	d1
		lsr.l	#1,d1
		move.l	d1,d2
		lsr.l	#1,d1
		move.l	d1,d3
		add.l	d2,d3
		swap	d1
		swap	d2
		swap	d3
		move.w	d3,(a1)+				; propagate smaller motion to other steps
		move.w	d2,(a1)+
		move.w	d1,(a1)+
.return:	rts
; ===========================================================================
; Move staircase in negative direction until first step reaches -$80
Obj78_AdvanceNegative:
		lea	stair_yoff_table(a0),a1
		cmpi.w	#-$80,(a1)
		beq.s	.return

		subq.w	#1,(a1)					; step 0 moves fastest
		moveq	#0,d1
		move.w	(a1)+,d1
		swap	d1
		asr.l	#1,d1
		move.l	d1,d2
		asr.l	#1,d1
		move.l	d1,d3
		add.l	d2,d3
		swap	d1
		swap	d2
		swap	d3
		move.w	d3,(a1)+				; propagate smaller motion to other steps
		move.w	d2,(a1)+
		move.w	d1,(a1)+

.return:
		rts
; ===========================================================================