; ===========================================================================
; ---------------------------------------------------------------------------
; Objects Manager
; Subroutine that keeps track of any objects that need to remember
; their state, such as monitors or enemies.
;
; input variables:
;  -none-
;
; writes:
;  d0, d1
;  d2 = respawn index of object to load
;  d6 = camera position
;
;  a0 = address in object placement list
;  a2 = respawn table
; ---------------------------------------------------------------------------

; ObjPosLoad:
ObjectsManager:
		moveq	#0,d0
		move.b	(Obj_placement_routine).w,d0
		move.w	ObjectsManager_States(pc,d0.w),d0
		jmp	ObjectsManager_States(pc,d0.w)
; ===========================================================================
; OPL_Index:
ObjectsManager_States:
		dc.w ObjectsManager_Init-ObjectsManager_States
		dc.w ObjectsManager_Main-ObjectsManager_States
; ===========================================================================
; loc_DC68:
ObjectsManager_Init:
		addq.b	#2,(Obj_placement_routine).w
		move.w	(Current_ZoneAndAct).w,d0
		move.w	d0,d1
		lsr.w	#5,d0
		andi.w	#$FF,d1
		add.w	d1,d1
		add.w	d1,d0
;		lsl.b	#6,d0
;		lsr.w	#4,d0
		lea	(ObjPos_Index).l,a0
		movea.l	a0,a1
		adda.w	(a0,d0.w),a0
		move.l	a0,(Obj_load_addr_right).w
		move.l	a0,(Obj_load_addr_left).w
		move.l	a0,(Obj_load_addr_right_P2).w
		move.l	a0,(Obj_load_addr_left_P2).w
		lea	(v_objstate).w,a2
		move.w	#$101,(a2)+

		move.w	#bytesToLcnt(v_objstate_end-v_objstate-2),d0
-		clr.l	(a2)+
		dbf	d0,-

		; Clear the last word, since the above loop only does longwords.
	if (v_objstate_end-v_objstate-2)&2
		clr.w	(a2)+
	endif
		lea	(v_objstate).w,a2
		moveq	#0,d2
		move.w	(Camera_RAM).w,d6
		subi.w	#$80,d6
		bhs.s	loc_DCB4
		moveq	#0,d6

loc_DCB4:
		andi.w	#-$80,d6
		movea.l	(Obj_load_addr_right).w,a0

loc_DCBC:
		cmp.w	(a0),d6
		bls.s	loc_DCCE
		tst.b	omID(a0)
		bpl.s	loc_DCCA
		move.b	(a2),d2
		addq.b	#1,(a2)

loc_DCCA:
		addq.w	#omSize,a0	; 8 in Sonic CD
		bra.s	loc_DCBC
; ===========================================================================

loc_DCCE:
		move.l	a0,(Obj_load_addr_right).w
		move.l	a0,(Obj_load_addr_right_P2).w
		movea.l	(Obj_load_addr_left).w,a0
		subi.w	#$80,d6
		blo.s	loc_DCF2

loc_DCE0:
		cmp.w	(a0),d6
		bls.s	loc_DCF2
		tst.b	omID(a0)
		bpl.s	loc_DCEE
		addq.b	#1,1(a2)

loc_DCEE:
		addq.w	#omSize,a0	; 8 in Sonic CD
		bra.s	loc_DCE0
; ===========================================================================

loc_DCF2:
		move.l	a0,(Obj_load_addr_left).w
		move.l	a0,(Obj_load_addr_left_P2).w
		move.w	#-1,(Camera_X_pos_last).w
		move.w	#-1,(Camera_X_pos_last_P2).w
; ===========================================================================
; loc_DD14:
ObjectsManager_Main:
		move.w	(Camera_RAM).w,d1
		subi.w	#$80,d1
		andi.w	#-$80,d1
		move.w	d1,(Camera_X_pos_coarse).w
		lea	(v_objstate).w,a2		; Sonic CD skips the first 4 lines
		moveq	#0,d2
		move.w	(Camera_RAM).w,d6
		andi.w	#-$80,d6
		cmp.w	(Camera_X_pos_last).w,d6
		beq.s	loc_DD94.return
		bge.s	loc_DD9A
		move.w	d6,(Camera_X_pos_last).w	; And there's a mysterious 4 "NOP" block of padding between the branches and this instruction

; -------------------------------------------------------------------------

; SpawnObjects_Backward:
		movea.l	(Obj_load_addr_left).w,a0
		subi.w	#$80,d6
		blo.s	loc_DD76

loc_DD4A:
		cmp.w	omX-omSize(a0),d6	; oeX-oeSize
		bge.s	loc_DD76
		subq.w	#omSize,a0		; oeSize
		tst.b	omID(a0)		; oeID
		bpl.s	loc_DD60
		subq.b	#1,1(a2)
		move.b	1(a2),d2

loc_DD60:
		bsr.w	sub_E0D2
		bne.s	loc_DD6A
		subq.w	#omSize,a0		; oeSize
		bra.s	loc_DD4A
; ===========================================================================

loc_DD6A:
		tst.b	omID(a0)		; oeID
		bpl.s	loc_DD74
		addq.b	#1,1(a2)
		bclr	#7,2(a2,d3.w)	; SCD Only:	; Mark object as unloaded

loc_DD74:
		addq.w	#omSize,a0		; oeSize

loc_DD76:
		move.l	a0,(Obj_load_addr_left).w
		movea.l	(Obj_load_addr_right).w,a0
		addi.w	#$280+$80,d6		; ((camera X & $FF80) + $280)

loc_DD82:
		cmp.w	omX-omSize(a0),d6	; oeX-oeSize
		bgt.s	loc_DD94
		tst.b	omID-omSize(a0)		; oeID-oeSize
		bpl.s	loc_DD90
		subq.b	#1,(a2)

loc_DD90:
		subq.w	#omSize,a0		; oeSize
		bra.s	loc_DD82
; ===========================================================================

loc_DD94:
		move.l	a0,(Obj_load_addr_right).w
.return:	rts
; ===========================================================================

loc_DD9A:	; Sonic CD pads the start with 4 NOP's
		move.w	d6,(Camera_X_pos_last).w
		movea.l	(Obj_load_addr_right).w,a0
		addi.w	#$280,d6

loc_DDA6:
		cmp.w	(a0),d6
		bls.s	.SpawnDone
		tst.b	omID(a0)		; oeID
		bpl.s	.SpawnObj
		move.b	(a2),d2
		addq.b	#1,(a2)

.SpawnObj:
		bsr.w	sub_E0D2
		beq.s	loc_DDA6
		tst.b	omID(a0)	; SCD		; Does this object have a saved flags entry?
		bpl.s	.SpawnDone	; SCD		; If not, branch
		subq.b	#1,(a2)		; SCD		; Rewind saved flags entry ID
		bclr	#7,2(a2,d3.w)	; SCD		; Mark object as unloaded

.SpawnDone:
		move.l	a0,(Obj_load_addr_right).w
		movea.l	(Obj_load_addr_left).w,a0
		subi.w	#$80+$280,d6			; ((camera X & $FF80) - $80)
		blo.s	loc_DDDA

loc_DDC8:
		cmp.w	(a0),d6
		bls.s	loc_DDDA
		tst.b	omID(a0)	; oeID
		bpl.s	loc_DDD6
		addq.b	#1,1(a2)

loc_DDD6:
		addq.w	#omSize,a0
		bra.s	loc_DDC8
; ===========================================================================

loc_DDDA:
		move.l	a0,(Obj_load_addr_left).w
		rts
; End of function ObjectsManager

; -------------------------------------------------------------------------
; Check object time zone and get objects flag entry offset
; -------------------------------------------------------------------------
; PARAMETERS:
;	a0.l  - Pointer to object entry
;	d2.w  - Saved object flags entry ID
; RETURNS:
;	eq/ne - Wrong time zone/Corrent time zone
;	d3.w  - Saved object flags entry offset
; -------------------------------------------------------------------------

CheckObjTimeZone:
		moveq	#0,d0				; Get current time zone
		move.b	(Current_Timezone).w,d0		; (timeZone).w in SCD
		bclr	#7,d0
		move.w	d2,d3				; Get saved objects flag entry offset
		add.w	d3,d3
		add.w	d2,d3
		add.w	d0,d3
		move.b	omTimeZones(a0),d1		; Check time zone
		rol.b	#3,d1
		andi.b	#7,d1
		btst	d0,d1
		rts

; =============== S U B R O U T I N E =======================================


sub_E0D2:
		bsr.s	CheckObjTimeZone		; Check object's time zone settings
		beq.s	.NoSpawn			; If we are in the wrong time zone, branch
		tst.b	omID(a0)		; oeID
		bpl.s	loc_E0E6
		btst	#7,2(a2,d2.w)
		beq.s	loc_E0E6
.NoSpawn:
		addq.w	#omSize,a0		; oeSize
		moveq	#0,d0
		rts
; ---------------------------------------------------------------------------

loc_E0E6:
		bsr.w	FindFreeObj
		bne.s	.return
		move.w	(a0)+,obX(a1)
		move.w	(a0)+,d0
		move.w	d0,d1
		andi.w	#$FFF,d0
		move.w	d0,obY(a1)
		rol.w	#2,d1
		andi.b	#3,d1
		move.b	d1,obRender(a1)
		move.b	d1,obStatus(a1)
		move.b	(a0)+,d0
		bpl.s	+
		bset	#7,2(a2,d2.w)
		andi.b	#$7F,d0
		move.b	d2,obRespawnNo(a1)
+
		_move.b	d0,obID(a1)
		move.b	(a0)+,obSubtype(a1)
		move.b	(a0)+,d0			; Skip time zone settings
		move.b	(a0)+,ob2ndSubtype(a1)		; Set secondary subtype
		moveq	#0,d0
.return:	rts
; End of function sub_E0D2