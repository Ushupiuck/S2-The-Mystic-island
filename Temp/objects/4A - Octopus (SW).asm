;===============================================================================
; Object 0x4A - Oil Ocean - Octus
; [ Begin ]
;===============================================================================
octus_start_position = objoff_2A
Obj_0x4A_Octus:
		moveq	#0,d0
		move.b	routine(a0),d0
		move.w	Obj4A_Index(pc,d0.w),d1
		jmp	Obj4A_Index(pc,d1.w)
; ===========================================================================
Obj4A_Index:	dc.w	Obj4A_Init-Obj4A_Index
		dc.w	Obj4A_Main-Obj4A_Index
		dc.w	Obj4A_Angry-Obj4A_Index
		dc.w	Obj4A_Bullet-Obj4A_Index
; ===========================================================================
Obj4A_Bullet:
		subi.w	#1,objoff_2C(a0)
		bmi.s	+
		rts
; ---------------------------------------------------------------------------
+
		jsr	(ObjectFall).l
		lea	(Ani_obj4A).l,a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l

; ===========================================================================
Obj4A_Angry:
		subq.w	#1,objoff_2C(a0)
		beq.s	J_DeleteObject_25
		jmp	(DisplaySprite).l

J_DeleteObject_25:
		jmp	(DeleteObject).l
; ===========================================================================
Obj4A_Init:
		move.l	#Octus_Mappings,mappings(a0)
		move.w	#$238A,art_tile(a0)
		ori.b	#4,render_flags(a0)
		move.b	#$A,collision_flags(a0)
		move.b	#4,priority(a0)
		move.b	#$10,width_pixels(a0)
		move.b	#$10,y_radius(a0)
		move.b	#8,x_radius(a0)
		jsr	(ObjectFall).l
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	+
		add.w	d1,y_pos(a0)
		move.w	#0,y_vel(a0)
		addq.b	#2,routine(a0)
		move.w	x_pos(a0),d0
		sub.w	(Object_RAM+x_pos).w,d0
		bpl.s	+
		bchg	#0,status(a0)
+
		move.w	y_pos(a0),octus_start_position(a0)
		rts
; ===========================================================================
Obj4A_Main:
		moveq	#0,d0
		move.b	routine_secondary(a0),d0
		move.w	Obj4A_Main_Index(pc,d0.w),d1
		jsr	Obj4A_Main_Index(pc,d1.w)
		lea	(Ani_obj4A).l,a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ===========================================================================
Obj4A_Main_Index:
		dc.w	Obj4A_WaitForCharacter-Obj4A_Main_Index
		dc.w	loc_1ECA0-Obj4A_Main_Index
		dc.w	loc_1ECC2-Obj4A_Main_Index
		dc.w	loc_1ED94-Obj4A_Main_Index
; ===========================================================================
Obj4A_WaitForCharacter:
		move.w	x_pos(a0),d0
		sub.w	(Object_RAM+x_pos).w,d0
		cmpi.w	#$80,d0
		bgt.s	+
		cmpi.w	#-$80,d0
		blt.s	+
		addq.b	#2,routine_secondary(a0)
		move.b	#1,anim(a0)
+
		rts
; ===========================================================================
loc_1ECA0:
		subi.l	#$00018000,y_pos(a0)
		move.w	octus_start_position(a0),d0
		sub.w	y_pos(a0),d0
		cmpi.w	#$20,d0
		ble.s	+
		addq.b	#2,routine_secondary(a0)
		move.w	#0,objoff_2C(a0)
+
		rts
; ===========================================================================
loc_1ECC2:
		subi.w	#1,objoff_2C(a0)
		beq.w	loc_1ED8E
		bpl.w	+
		move.w	#$1E,objoff_2C(a0)
		jsr	(SingleObjLoad).l
		bne.s	loc_1ED28
		_move.b	#$4A,id(a1)
		move.b	#4,routine(a1)
		move.l	#Octus_Mappings,mappings(a1)
		move.b	#4,mapping_frame(a1)
		move.w	#$24C6,art_tile(a1)
		move.b	#3,priority(a1)
		move.b	#$10,width_pixels(a1)
		move.w	x_pos(a0),x_pos(a1)
		move.w	y_pos(a0),y_pos(a1)
		move.w	#$1E,objoff_2C(a1)
		move.b	render_flags(a0),render_flags(a1)
		move.b	status(a0),status(a1)
loc_1ED28:
		jsr	(SingleObjLoad).l
		bne.s	+
		_move.b	#$4A,id(a1)
		move.b	#6,routine(a1)
		move.l	#Octus_Mappings,mappings(a1)
		move.w	#$24C6,art_tile(a1)
		move.b	#4,priority(a1)
		move.b	#$10,width_pixels(a1)
		move.w	x_pos(a0),x_pos(a1)
		move.w	y_pos(a0),y_pos(a1)
		move.w	#$F,objoff_2C(a1)
		move.b	render_flags(a0),render_flags(a1)
		move.b	status(a0),status(a1)
		move.b	#2,anim(a1)
		move.w	#-$580,x_vel(a1)	;-$580 = $FA80; -$200 = $FE00 in the final
		btst	#0,render_flags(a1)
		beq.s	+
		neg.w	x_vel(a1)
+
		rts
loc_1ED8E:
		addq.b	#2,routine_secondary(a0)
		rts
; ===========================================================================
loc_1ED94:
		move.w	#-$6,d0
		btst	#0,render_flags(a0)
		beq.s	+
		neg.w	d0
+
		add.w	d0,x_pos(a0)
		jmp	(MarkObjGone).l
; ===========================================================================
Ani_obj4A:
		dc.w	byte_1EDB0-Ani_obj4A
		dc.w	byte_1EDB3-Ani_obj4A
		dc.w	byte_1EDB8-Ani_obj4A

byte_1EDB0:	dc.b	$F, 0, $FF
byte_1EDB3:	dc.b	3, 1, 2, 3, $FF
byte_1EDB8:	dc.b	2, 5, 6, $FF
; ===========================================================================
Octus_Mappings:
loc_1EDBC:
		dc.w	loc_1EDCA-loc_1EDBC
		dc.w	loc_1EDDC-loc_1EDBC
		dc.w	loc_1EDF6-loc_1EDBC
		dc.w	loc_1EE10-loc_1EDBC
		dc.w	loc_1EE2A-loc_1EDBC
		dc.w	loc_1EE34-loc_1EDBC
		dc.w	loc_1EE3E-loc_1EDBC
loc_1EDCA:
		dc.w 2
		dc.w $F00D, 0, 0, $FFF0
		dc.w $D, 8, 4, $FFF0
loc_1EDDC:
		dc.w 3
		dc.w $F00D, 0, 0, $FFF0
		dc.w 9, $10, 8, $FFE8
		dc.w 9, $16, $B, 0
loc_1EDF6:
		dc.w 3
		dc.w $F00D, 0, 0, $FFF0
		dc.w 9, $1C, $E, $FFE8
		dc.w 9, $22, $11, 0
loc_1EE10:
		dc.w 3
		dc.w $F00D, 0, 0, $FFF0
		dc.w 9, $28, $14, $FFE8
		dc.w 9, $2E, $17, 0
loc_1EE2A:
		dc.w 1
		dc.w $F001, $34, $1A, $FFF7
loc_1EE34:
		dc.w 1
		dc.w $F201, $36, $1B, $FFF0
loc_1EE3E:
		dc.w 1
		dc.w $F201, $38, $1C, $FFF0
	even
;===============================================================================
; Object 0x4A - Oil Ocean - Octus
; [ End ]
;===============================================================================