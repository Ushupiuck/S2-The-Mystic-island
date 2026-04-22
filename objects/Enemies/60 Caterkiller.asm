; ---------------------------------------------------------------------------
; Object 60 - Caterkiller enemy (MZ, SBZ)
; ---------------------------------------------------------------------------

Caterkiller:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Cat_Index(pc,d0.w),d1
		jmp	Cat_Index(pc,d1.w)
; ===========================================================================
Cat_Index:	dc.w Cat_Main-Cat_Index
		dc.w Cat_Head-Cat_Index
		dc.w Cat_BodySeg1-Cat_Index
		dc.w Cat_BodySeg2-Cat_Index
		dc.w Cat_BodySeg1-Cat_Index
		dc.w Cat_Delete-Cat_Index
		dc.w Cat_Scatter-Cat_Index

cat_wait_time	= obAniFrame		; 1 byte; delay between moves
cat_mode	= obAnim		; 1 byte; bit 4 = segment up/down, bit 7 = animate
cat_inertia	= objoff_2A		; 2 bytes; Needed to avoid overwriting it's own obColType & obColProp
cat_floormap	= objoff_2C		; $C bytes; 16 packed 6-bit floor entries
cat_parent	= objoff_38		; 4 bytes; parent object (high byte = segment index)
cat_segment_pos	= cat_parent		; high byte; current position in floor buffer

cat_floor_bias	= 8			; -8..+11 -> 0..19
cat_floor_flat	= cat_floor_bias	; encoded 0-height delta
cat_floor_turn	= 20			; turn marker
; packed flat entries for 4 slots: $20,$82,$08
; ===========================================================================

Cat_Main:	; Routine 0
		move.b	#7,obHeight(a0)
		move.b	#8,obWidth(a0)
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Cat,obMap(a0)
		move.w	#make_art_tile(ArtTile_SBZ_Caterkiller,1,0),obGfx(a0)
		cmpi.b	#id_SBZ,(v_zone).w	; if level is SBZ, branch
		beq.s	.isscrapbrain
		move.w	#make_art_tile(ArtTile_MZ_SYZ_Caterkiller,1,0),obGfx(a0)

.isscrapbrain:
		andi.b	#3,obRender(a0)
		ori.b	#4,obRender(a0)
		move.b	obRender(a0),obStatus(a0)
		move.w	#$200,obPriority(a0)
		move.b	#8,obActWid(a0)
		move.b	#$B,obColType(a0)

		; airborne / dormant start
		clr.b	cat_mode(a0)
		clr.w	obVelX(a0)
		clr.w	obVelY(a0)
		clr.w	cat_inertia(a0)

		move.w	obX(a0),d2
		moveq	#$C,d5
		btst	#0,obStatus(a0)
		beq.s	.noflip
		neg.w	d5

.noflip:
		moveq	#4,d6			; starting routine (Cat_BodySeg1)
		moveq	#0,d3
		moveq	#4,d4
		movea.l	a0,a2			; a2 = current parent (starts as head)
		moveq	#2,d1			; spawn 3 segments

Cat_Loop:
		jsr	(FindNextFreeObj).l
		bne.w	Cat_ChkGone
		_move.b	#id_Obj60,obID(a1)
		move.b	d6,obRoutine(a1)	; goto Cat_BodySeg1 or Cat_BodySeg2
		addq.b	#2,d6			; alternate between the two
		move.l	#Map_Cat,obMap(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.w	#$280,obPriority(a1)
		move.b	#8,obActWid(a1)
		move.b	#$CB,obColType(a1)

		clr.w	obVelX(a1)
		clr.w	obVelY(a1)
		clr.w	cat_inertia(a1)

		add.w	d5,d2
		move.w	d2,obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obStatus(a0),obRender(a1)
		move.b	#8,obFrame(a1)
		move.l	a2,cat_parent(a1)
		move.b	d4,cat_segment_pos(a1)
		; load values for the segments
		lea	cat_floormap(a1),a3
		moveq	#3,d0			; 4 groups of 3 bytes = 16 entries
.childfill:
		move.b	#$20,(a3)+
		move.b	#$82,(a3)+
		move.b	#$08,(a3)+
		dbf	d0,.childfill

		addq.b	#4,d4
		movea.l	a1,a2
		dbf	d1,Cat_Loop

		move.b	#7,cat_wait_time(a0)
		clr.b	cat_segment_pos(a0)
		; and now for the head
		lea	cat_floormap(a0),a3
		moveq	#3,d0			; 4 groups of 3 bytes = 16 entries
.headfill:
		move.b	#$20,(a3)+
		move.b	#$82,(a3)+
		move.b	#$08,(a3)+
		dbf	d0,.headfill

		; start Cat_Head in airborne state
		clr.b	ob2ndRout(a0)

Cat_Head:	; Routine 2
		tst.b	obStatus(a0)
		bmi.w	loc_16C96
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Cat_Index2(pc,d0.w),d1
		jsr	Cat_Index2(pc,d1.w)
		move.b	cat_mode(a0),d1
		bpl.s	.display
		lea	Ani_Cat(pc),a1
		move.b	obAngle(a0),d0
		andi.w	#$7F,d0
		addq.b	#4,obAngle(a0)
		move.b	(a1,d0.w),d0
		bpl.s	.animate
		bclr	#7,cat_mode(a0)
		bra.s	.display

.animate:
		andi.b	#$10,d1
		add.b	d1,d0
		move.b	d0,obFrame(a0)

.display:
		out_of_range.w	Cat_ChkGone
		bra.w	DisplaySprite

Cat_ChkGone:
		lea	(v_objstate).w,a2
		moveq	#0,d0
		move.b	obRespawnNo(a0),d0
		beq.s	.delete
		bclr	#7,2(a2,d0.w)

.delete:	move.b	#$A,obRoutine(a0)	; goto Cat_Delete next
		rts
; ===========================================================================

Cat_Delete:	; Routine $A
		bra.w	DeleteObject
; ===========================================================================
Cat_Index2:
		dc.w .airborne-Cat_Index2
		dc.w .wait-Cat_Index2
		dc.w loc_16B02-Cat_Index2
; ===========================================================================
.airborne:
		cmpi.w	#$800,obVelY(a0)	; cap at 8px/frame — safely within ObjHitFloor's $10 range
	;	blt.s	.chkfloor
		bls.s	.chkfloor
		move.w	#$800,obVelY(a0)
.chkfloor:
		bsr.w	ObjectFall
		bsr.w	ObjHitFloor
		tst.w	d1
		bpl.s	.stillair
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		move.b	#2,ob2ndRout(a0)
		move.b	#7,cat_wait_time(a0)
.stillair:	rts
; ===========================================================================
.wait:
		subq.b	#1,cat_wait_time(a0)
		bmi.s	.move
		rts
; ===========================================================================

.move:
		addq.b	#2,ob2ndRout(a0)
		move.b	#$10,cat_wait_time(a0)
		move.w	#-$C0,obVelX(a0)
		move.w	#$40,cat_inertia(a0)
		bchg	#4,cat_mode(a0)
		bne.s	loc_16AFC
		clr.w	obVelX(a0)
		neg.w	cat_inertia(a0)

loc_16AFC:
		bset	#7,cat_mode(a0)

loc_16B02:
		subq.b	#1,cat_wait_time(a0)
		bmi.s	.loc_16B5E
		move.w	obVelX(a0),d0
		beq.s	.notmoving
		move.l	obX(a0),d2
		move.l	d2,d3
		btst	#0,obStatus(a0)
		beq.s	.noflip
		neg.w	d0

.noflip:
		ext.l	d0
		asl.l	#8,d0
		add.l	d0,d2
		move.l	d2,obX(a0)
		swap	d3
		cmp.w	obX(a0),d3
		beq.s	.notmoving
		bsr.w	ObjHitFloor
		cmpi.w	#-8,d1
		blt.s	.turn
		cmpi.w	#$C,d1
		bge.s	.turn
		add.w	d1,obY(a0)
		addi.w	#cat_floor_bias,d1
		moveq	#0,d0
		move.b	cat_segment_pos(a0),d0
		bsr.w	Cat_WriteFloor
		addq.w	#1,d0
		andi.w	#$F,d0
		move.b	d0,cat_segment_pos(a0)
.notmoving:	rts
; ===========================================================================

.loc_16B5E:
		subq.b	#2,ob2ndRout(a0)
		move.b	#7,cat_wait_time(a0)
		clr.w	obVelX(a0)
		clr.w	cat_inertia(a0)
		rts
; ===========================================================================

.turn:
		moveq	#0,d0
		move.b	cat_segment_pos(a0),d0
		move.w	#cat_floor_turn,d1
		bsr.w	Cat_WriteFloor
		neg.w	obX+2(a0)
		beq.s	.flip
		btst	#0,obStatus(a0)
		beq.s	.flip
		subq.w	#1,obX(a0)
		addq.w	#1,d0
		andi.w	#$F,d0
		move.w	#cat_floor_flat,d1
		bsr.w	Cat_WriteFloor
.flip:
		bchg	#0,obStatus(a0)
		move.b	obStatus(a0),obRender(a0)
		addq.w	#1,d0
		andi.w	#$F,d0
		move.b	d0,cat_segment_pos(a0)
		rts
; ===========================================================================

Cat_BodySeg2:	; Routine 6
		movea.l	cat_parent(a0),a1
		move.b	cat_mode(a1),cat_mode(a0)
		bpl.s	Cat_BodySeg1
		lea	Ani_Cat(pc),a1
		move.b	obAngle(a0),d0
		andi.w	#$7F,d0
		addq.b	#4,obAngle(a0)
		tst.b	4(a1,d0.w)
		bpl.s	Cat_AniBody
		addq.b	#4,obAngle(a0)

Cat_AniBody:
		move.b	(a1,d0.w),d0
		addq.b	#8,d0
		move.b	d0,obFrame(a0)

Cat_BodySeg1:	; Routine 4, 8
		movea.l	cat_parent(a0),a1
		tst.b	obStatus(a0)
		bmi.w	loc_16C90
		moveq	#0,d6
		move.b	ob2ndRout(a0),d6	; save previous child state

		move.b	cat_mode(a1),cat_mode(a0)
		move.b	ob2ndRout(a1),ob2ndRout(a0)
		beq.w	Cat_BodyAirborne	; parent still airborne

		cmpi.b	#2,ob2ndRout(a1)
		bne.s	.notwait

		; parent is waiting after landing
		; only snap once if this child was airborne last frame
		tst.b	d6
		bne.w	loc_16C64

		move.l	obY(a1),obY(a0)
		clr.w	obVelX(a0)
		clr.w	obVelY(a0)
		clr.w	cat_inertia(a0)
		move.b	#8,obFrame(a0)
		bra.w	loc_16C64

.notwait:
		move.w	cat_inertia(a1),d1
		move.w	d1,cat_inertia(a0)
		move.w	obVelX(a1),d0
		add.w	d1,d0
		move.w	d0,obVelX(a0)
		move.l	obX(a0),d2
		move.l	d2,d3
		btst	#0,obStatus(a0)
		beq.s	.noflip
		neg.w	d0

.noflip:
		ext.l	d0
		asl.l	#8,d0
		add.l	d0,d2
		move.l	d2,obX(a0)
		swap	d3
		cmp.w	obX(a0),d3
		beq.w	loc_16C64
		moveq	#0,d0
		move.b	cat_segment_pos(a0),d0
		bsr.w	Cat_ReadFloor
		bsr.w	Cat_WriteFloor
		cmpi.w	#cat_floor_turn,d1
		beq.s	Cat_BodyAirborne.turn
		subi.w	#cat_floor_bias,d1
		add.w	d1,obY(a0)
		addq.w	#1,d0
		andi.w	#$F,d0
		move.b	d0,cat_segment_pos(a0)
		bra.s	loc_16C64

Cat_BodyAirborne:
		move.l	obY(a1),obY(a0)
		clr.w	obVelX(a0)
		clr.w	obVelY(a0)
		clr.w	cat_inertia(a0)
		move.b	#8,obFrame(a0)
		bra.s	loc_16C64

.turn:
		neg.w	obX+2(a0)
		beq.s	.flip
		btst	#0,obStatus(a0)
		beq.s	.flip
		cmpi.w	#-$C0,obVelX(a0)
		bne.s	.flip
		subq.w	#1,obX(a0)
		addq.w	#1,d0
		andi.w	#$F,d0
		move.w	#cat_floor_flat,d1
		bsr.w	Cat_WriteFloor
.flip:
		bchg	#0,obStatus(a0)
		move.b	obStatus(a0),obRender(a0)
		addq.w	#1,d0
		andi.w	#$F,d0
		move.b	d0,cat_segment_pos(a0)
		; fall through to loc_16C64
; ===========================================================================

loc_16C64:
		cmpi.b	#$C,obRoutine(a1)
		beq.s	loc_16C90

		; Each sub-object deletes itself when it detects that its
		; parent is going to delete itself. This mostly works, but
		; does cause the sub-object to linger for one frame longer
		; than it should, which is why rolling into a Caterkiller
		; at high speed causes Sonic to be hurt.

		; Has the head been destroyed?
		_cmpi.b	#id_Obj0F,obID(a1)
		beq.s	.delete
		; Is the parent going to delete itself?
		cmpi.b	#$A,obRoutine(a1)
		bne.s	.display
		; Delete the parent.
		bsr.w	DeleteObject2	; Don't mind this misnomer.

.delete:	; Mark self for deletion.
		clr.b	obColType(a1)	; immediately remove all touch response values when destroying the head to avoid taking damage
		move.b	#$A,obRoutine(a0)
		; Do not queue self for display, since it will be deleted by
		; its child later.
		rts

.display:	bra.w	DisplaySprite
; ===========================================================================
Cat_FragSpeed:
		dc.w -$200				; head x speed
		dc.w -$180				; body x speed
		dc.w $180				; body x speed
		dc.w $200				; body x speed
; ===========================================================================

loc_16C90:
		bset	#7,obStatus(a1)

loc_16C96:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Cat_FragSpeed-2(pc,d0.w),d0
		btst	#0,obStatus(a0)
		beq.s	loc_16CAA
		neg.w	d0

loc_16CAA:
		move.w	d0,obVelX(a0)
		move.w	#-$400,obVelY(a0)
		move.b	#$C,obRoutine(a0)
		andi.b	#$F8,obFrame(a0)

Cat_Scatter:	; Routine $C
		bsr.w	ObjectFall
		tst.w	obVelY(a0)
		bmi.s	loc_16CE0
		bsr.w	ObjHitFloor
		tst.w	d1
		bpl.s	loc_16CE0
		add.w	d1,obY(a0)
		move.w	#-$400,obVelY(a0)

loc_16CE0:
		tst.b	obRender(a0)
		bpl.w	Cat_ChkGone
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
; Animation script - Caterkiller enemy (uses non-standard format)
; ---------------------------------------------------------------------------
Ani_Cat:	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 1
		dc.b 1,	1, 1, 1, 1, 1, 2, 2, 2,	2, 2, 3, 3, 3, 3, 3
		dc.b 4,	4, 4, 4, 4, 4, 5, 5, 5,	5, 5, 6, 6, 6, 6, 6
		dc.b 6,	6, 7, 7, 7, 7, 7, 7, 7,	7, 7, 7, $FF, 7, 7, $FF
		dc.b 7,	7, 7, 7, 7, 7, 7, 7, 7,	7, 7, 7, 7, 7, 7, 6
		dc.b 6,	6, 6, 6, 6, 6, 5, 5, 5,	5, 5, 4, 4, 4, 4, 4
		dc.b 4,	3, 3, 3, 3, 3, 2, 2, 2,	2, 2, 1, 1, 1, 1, 1
		dc.b 1,	1, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, $FF, 0, 0, $FF
		even
; ===========================================================================
; Read packed 6-bit floormap entry from parent object.
; in:  a1 = object base, d0.w = entry index (0..15)
; out: d1.w = encoded entry
; preserves: d0,a0,a1
; clobbers: d2-d3/a2-a3
Cat_ReadFloor:
		lea	cat_floormap(a1),a2
		lea	Cat_FloorMeta(pc),a3
		moveq	#0,d3
		move.w	d0,d3
		add.w	d3,d3
		move.w	(a3,d3.w),d2	; high byte = case, low byte = offset
		moveq	#0,d3
		move.b	d2,d3		; low byte = offset
		adda.w	d3,a2
		lsr.w	#8,d2		; high byte = case
		add.w	d2,d2
		move.w	.read_index(pc,d2.w),d2
		jmp	.read_index(pc,d2.w)
; ===========================================================================
.read_index:
		dc.w	.read0-.read_index
		dc.w	.read1-.read_index
		dc.w	.read2-.read_index
		dc.w	.read3-.read_index
; ===========================================================================
; case 0: a2 -> byte 0 of group
.read0:
		moveq	#0,d1
		move.b	(a2),d1
		lsr.b	#2,d1
		rts
; ===========================================================================
; case 1: a2 -> byte 0 of group
.read1:
		moveq	#0,d1
		move.b	(a2),d1
		andi.w	#3,d1
		lsl.w	#4,d1
		moveq	#0,d3
		move.b	1(a2),d3
		lsr.b	#4,d3
		or.w	d3,d1
		rts
; ===========================================================================
; case 2: a2 -> byte 1 of group
.read2:
		moveq	#0,d1
		move.b	(a2),d1
		andi.w	#$F,d1
		add.w	d1,d1
		add.w	d1,d1
		moveq	#0,d3
		move.b	1(a2),d3
		lsr.b	#6,d3
		or.w	d3,d1
		rts

; ===========================================================================
; case 3: a2 -> byte 2 of group
.read3:
		moveq	#0,d1
		move.b	(a2),d1
		andi.w	#$3F,d1
		rts
; ===========================================================================
; low byte = byte offset, high byte = case
Cat_FloorMeta:
		dc.w $0000,$0100,$0201,$0302
		dc.w $0003,$0103,$0204,$0305
		dc.w $0006,$0106,$0207,$0308
		dc.w $0009,$0109,$020A,$030B
	;	even
; ===========================================================================
; Write packed 6-bit floormap entry to current object.
; in:  a0 = object base, d0.w = entry index (0..15), d1.w = encoded entry
; out: none
; preserves: d0,d1,a1
; clobbers: d2-d4/a2-a3
Cat_WriteFloor:
		move.w	d1,d4
		andi.w	#$3F,d4
		lea	cat_floormap(a0),a2
		lea	Cat_FloorMeta(pc),a3
		moveq	#0,d3
		move.w	d0,d3
		add.w	d3,d3
		move.w	(a3,d3.w),d2	; high byte = case, low byte = offset
		moveq	#0,d3
		move.b	d2,d3		; low byte = offset
		adda.w	d3,a2
		lsr.w	#8,d2		; high byte = case
		add.w	d2,d2
		move.w	.write_index(pc,d2.w),d2
		jmp	.write_index(pc,d2.w)
; ===========================================================================
.write_index:
		dc.w	.write0-.write_index
		dc.w	.write1-.write_index
		dc.w	.write2-.write_index
		dc.w	.write3-.write_index
; ===========================================================================
; case 0: a2 -> byte 0 of group
.write0:
		moveq	#0,d3
		move.b	(a2),d3
		andi.w	#3,d3
		add.w	d4,d4
		add.w	d4,d4
		or.w	d4,d3
		move.b	d3,(a2)
		rts
; ===========================================================================
; case 1: a2 -> byte 0 of group
.write1:
		move.b	(a2),d3
		andi.b	#$FC,d3
		move.w	d4,d2
		lsr.w	#4,d2
		or.b	d2,d3
		move.b	d3,(a2)
		move.b	1(a2),d3
		andi.b	#$F,d3
		lsl.b	#4,d4
		or.b	d4,d3
		move.b	d3,1(a2)
		rts
; ===========================================================================
; case 2: a2 -> byte 1 of group
.write2:
		moveq	#0,d3
		move.b	(a2),d3
		andi.w	#$F0,d3
		move.w	d4,d2
		lsr.w	#2,d2
		andi.w	#$0F,d2
		or.w	d2,d3
		move.b	d3,(a2)
		moveq	#0,d3
		move.b	1(a2),d3
		andi.w	#$3F,d3
		move.w	d4,d2
		lsl.w	#6,d2
		andi.w	#$C0,d2
		or.w	d2,d3
		move.b	d3,1(a2)
		rts
; ===========================================================================
; case 3: a2 -> byte 2 of group
.write3:
		moveq	#0,d3
		move.b	(a2),d3
		andi.w	#$C0,d3
		or.w	d4,d3
		move.b	d3,(a2)
		rts