; ===========================================================================
; Subtype table
; $0X = Normal
; $2X = Single use (Stays sunken)
; $4X = Single use (Explodes)
; $0X, $2X, $4X + $10 = Persistance flag
; $0X, $2X, $4X + $80 = Block Activated
; $0X, $2X, $4X + $10 + $80 = Persistant; Block/Object Activated
; Subtypes $CX only trigger when destroyed by another Block/Object
; Subtypes $DX are the same as $CX, except it also triggers the Persistance flag
; ---------------------------------------------------------------------------
; Object 32 - buttons/switches
; ---------------------------------------------------------------------------

capsule_triggered	= objoff_34
external_settings	= objoff_35	; byte, subtype override from parent object

Button:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	But_Index(pc,d0.w),d1
		jmp	But_Index(pc,d1.w)
; ===========================================================================
But_Index:	dc.w But_Main-But_Index
		dc.w But_Pressed-But_Index
; ===========================================================================

But_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.l	#Map_But,obMap(a0)
		move.w	#ArtTile_Button,obGfx(a0)
		move.b	#4,obRender(a0)
		move.b	#32/2,obActWid(a0)
		move.w	#$200,obPriority(a0)
		addq.w	#3,obY(a0)
; ---------------------------------------------------------------------------

But_Pressed:	; Routine 2
		tst.b	obRender(a0)				; is button on screen?
		bpl.w	.display				; if not, branch
		moveq	#32/2+sonic_solid_width,d1
		moveq	#10/2,d2
		moveq	#10/2,d3
		move.w	obX(a0),d4
		bsr.w	SolidObject
		clr.b	obFrame(a0)				; use "unpressed" frame
		move.b	obSubtype(a0),d1			; get subtype of button
		tst.b	capsule_triggered(a0)			; are external settings empty?
		beq.s	.skip					; if so, skip
		move.b	external_settings(a0),d1		; override subtype
.skip:
		move.b	d1,d0
		andi.b	#$F0,d1					; filter out high nybble in d1
		move.b	d1,ob2ndRout(a0)			; store behaviour
		andi.w	#$F,d0					; now, filter out lower nybble in d0
		lea	(f_switch).w,a3				; load button status array
		lea	(a3,d0.w),a3				; go to byte for this button
		moveq	#0,d3					; use bit 0 for the pressed state flag
		; Fall through

; Button_Types:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		andi.b	#$60,d0			; keep only base family
		lsr.b	#4,d0			; $00->$00, $20->$02, $40->$04, $60->$06
		move.w	.buttons_Index(pc,d0.w),d1
		jmp	.buttons_Index(pc,d1.w)
; ===========================================================================
.buttons_Index:	dc.w .type00-.buttons_Index
		dc.w .type20-.buttons_Index
		dc.w .type40-.buttons_Index
		dc.w .delete-.buttons_Index
		dc.w .type00-.buttons_Index	; duplicate entries to catch $80 subtypes
		dc.w .type20-.buttons_Index
		dc.w .type40-.buttons_Index
		dc.w .delete-.buttons_Index
; ===========================================================================
; ---------------------------------------------------------------------------
; Regular button
; ---------------------------------------------------------------------------
.type00:
		btst	#7,ob2ndRout(a0)			; is this a special, object-triggered button? (bit 7 set)
		beq.s	.type00_CheckPlayer			; if not, branch
		bsr.w	But_SBlock				; check if pushable block has landed on button
		bne.s	.pressed				; if it has, branch

.type00_CheckPlayer:
		move.b	status(a0),d0
		andi.b	#standing_mask,d0			; are Sonic or Tails standing on top of button?
		bne.w	.pressed				; if yes, branch
		btst	#4,ob2ndRout(a0)			; persistent?
		bne.s	+					; if yes, don't clear
		bclr	d3,(a3)					; clear stored button pressed state
+		out_of_range.w	.delete
		bra.w	DisplaySprite
; ===========================================================================
; ---------------------------------------------------------------------------
; Stays down when pressed
; ---------------------------------------------------------------------------
.type20:
		tst.b	objoff_36(a0)				; already used?
		bne.s	.type20_used				; then skip all of this
		btst	#7,ob2ndRout(a0)			; is this a special, object-triggered button? (bit 7 set)
		beq.s	.type20_CheckPlayer			; if not, branch
		bsr.w	But_SBlock				; check if pushable block has landed on button
		bne.s	.type20_use				; if it has, branch

.type20_CheckPlayer:
		move.b	status(a0),d0
		andi.b	#standing_mask,d0			; are Sonic or Tails standing on top of button?
		bne.s	.pressed				; if yes, branch
		btst	#4,ob2ndRout(a0)			; persistent?
		bne.s	+					; if yes, don't clear
		bclr	d3,(a3)					; clear stored button pressed state
+		out_of_range.w	.delete
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
.type20_use:
		move.b	#1,objoff_36(a0)
		bra.s	.pressed
; ---------------------------------------------------------------------------
.type20_used:
		move.b	#1,obFrame(a0)		; stay down
		out_of_range.s	.delete
		bra.w	DisplaySprite
; ===========================================================================
; ---------------------------------------------------------------------------
; Explodes when pressed
; ---------------------------------------------------------------------------
.type40:
		btst	#7,ob2ndRout(a0)			; is this a special, object-triggered button? (bit 7 set)
		beq.s	.type40_CheckPlayer			; if not, branch
		bsr.w	But_SBlock				; check if pushable block has landed on button
		bne.s	.pressed				; if it has, branch
.type40_CheckPlayer:
		move.b	status(a0),d0
		andi.b	#standing_mask,d0			; are Sonic or Tails standing on top of button?
		bne.s	.pressed				; if yes, branch
		btst	#4,ob2ndRout(a0)			; persistent?
	;	bne.s	.explode				; dummied out until it's been properly implemented
		bne.s	+					; if yes, don't clear
		bclr	d3,(a3)					; clear stored button pressed state
+		out_of_range.s	.delete
		bra.w	DisplaySprite
; ===========================================================================

.pressed:
		tst.b	(a3)					; has Sonic already been standing on it the previous frame?
		bne.s	.setPressedState			; if yes, don't play sound again
		move.w	#sfx_Switch,d0
		jsr	(PlaySound).l				; play switch sound

.setPressedState:
		bset	d3,(a3)					; set stored button pressed state
		move.b	#1,obFrame(a0)				; use "pressed" frame
.display:	out_of_range.s	.delete
		bra.w	DisplaySprite
.delete:	bra.w	DeleteObject

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to handle buttons that are activated by pushable blocks
; (Or similar objects)
; output:
;	d0 = 1 if block is on top of button, 0 if not
; ---------------------------------------------------------------------------

But_SBlock:
		move.w	d3,-(sp)
		move.w	obX(a0),d2
		move.w	obY(a0),d3
		subi.w	#$10,d2					; d2 = x pos. of button left edge
		subq.w	#8,d3					; d3 = y pos. of button top edge
		move.w	#$20,d4					; d4 = x detection range;
		move.w	#$10,d5					; d5 = y detection range

		lea	(v_lvlobjspace).w,a1			; begin checking object RAM
		move.w	#(v_lvlobjend-v_lvlobjspace)/object_size-1,d6
.findBlock:
		tst.b	obRender(a1)				; is object on screen?
		bpl.s	.nextObject				; if not, branch
		; Temporarily commented out until such object is added
	;	cmpi.b	#id_PushBlock,obID(a1)			; is object a pushable block?
	;	beq.s	.blockFound				; if yes, branch

.nextObject:
		lea	object_size(a1),a1			; check next object
		dbf	d6,.findBlock				; repeat $5F times

		move.w	(sp)+,d3
		moveq	#0,d0					; set pushable block NOT on top
.return:	rts
; ===========================================================================
.sBlock_sizes:	dc.b $10, $10	; x/y radius
; ===========================================================================

.blockFound:
		moveq	#1,d0
		andi.w	#$3F,d0
		add.w	d0,d0
		lea	.sBlock_sizes-2(pc,d0.w),a2

.checkX:
		move.b	(a2)+,d1				; load X-radius
		ext.w	d1
		move.w	obX(a1),d0
		sub.w	d1,d0
		sub.w	d2,d0
		bhs.s	.checkX_fromRight			; branch if block is to the right of button
		add.w	d1,d1
		add.w	d1,d0
		blo.s	.checkY
		bra.s	.nextObject

.checkX_fromRight:
		cmp.w	d4,d0
		bhi.s	.nextObject
; ---------------------------------------------------------------------------

.checkY:
		move.b	(a2)+,d1				; load y-radius
		ext.w	d1
		move.w	obY(a1),d0
		sub.w	d1,d0
		sub.w	d3,d0
		bhs.s	.checkY_fromAbove			; branch if block is above button
		add.w	d1,d1
		add.w	d1,d0
		blo.s	.blockOnTop
		bra.s	.nextObject

.checkY_fromAbove:
		cmp.w	d5,d0
		bhi.s	.nextObject
; ---------------------------------------------------------------------------

; loc_BE9E:
.blockOnTop:
		move.w	(sp)+,d3
		moveq	#1,d0					; set pushable block on top
		rts
; End of function But_SBlock
; ===========================================================================
Map_But:	include	"_maps/Button.asm"