; ---------------------------------------------------------------------------
; Object 1F - reusable conveyor platforms (MD main CPU)
; S1 $63 paths/wheel/switch, S2 $6C relative origins, S3&K LRZ movement/solidity.
; $80-$87: complete group; $C0-$C7: group with harmful undersides.
; $00-$7E: individual route/phase, also used by group members.
; $7F: decorative wheel. X flip reverses travel, without mirroring the route.
; ---------------------------------------------------------------------------
LCon_originX:		equ objoff_30
LCon_originY:		equ objoff_32
LCon_nextX:		equ objoff_34
LCon_nextY:		equ objoff_36
LCon_posindex:		equ objoff_38
LCon_count:		equ objoff_39
LCon_increment:		equ objoff_3A
LCon_reversed:		equ objoff_3B
LCon_targetdata:		equ objoff_3C
LCon_rightX:		equ objoff_40
LCon_loadwidth:		equ objoff_42
LCon_member:		equ objoff_44
LCon_settings:		equ objoff_45	; bit 0: harmful underside; passed by the parent
LCon_PathCount:		equ (LCon_Data_End-LCon_Data)/2
LCon_GroupCount:		equ (LCon_Placements_End-LCon_Placements)/2

LabyrinthConvey:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	LCon_Index(pc,d0.w),d1
		jmp	LCon_Index(pc,d1.w)
; ---------------------------------------------------------------------------
LCon_Index:	dc.w LCon_Init-LCon_Index
		dc.w LCon_Platform-LCon_Index
		dc.w LCon_Wheel-LCon_Index
; ---------------------------------------------------------------------------
LCon_Init:
		move.w	obSubtype(a0),d0
		btst	#7,d0
		bne.w	LCon_Spawn
		move.l	#Map_LConv,obMap(a0)
		move.b	#Map_LConv_height,height_pixels(a0)
		move.b	#sprite_bound($10,Map_LConv_width),obActWid(a0)
		move.w	#make_art_tile(ArtTile_LZ_Conveyor_Belt,2,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		cmpi.b	#$7F,d0
		bne.s	.platform
		move.b	#4,obRoutine(a0)
		clr.b	obFrame(a0)
		move.w	#make_art_tile(ArtTile_LZ_Conveyor_Belt,0,0),obGfx(a0)
		move.w	#$80,obPriority(a0)
		bra.w	LCon_Wheel
.platform:
		move.b	#2,obRoutine(a0)
		move.b	#4,obFrame(a0)
		btst	#0,LCon_settings(a0)
		beq.s	.normal
		move.b	#5,obFrame(a0)
.normal:
		move.w	d0,d1
		lsr.w	#3,d0
		andi.w	#$E,d0
		lea	LCon_Data(pc),a2
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,LCon_posindex(a0) ; zero index and byte count
		tst.b	LCon_member(a0)
		bne.s	.origin_ready
		move.w	obX(a0),LCon_originX(a0)
		move.w	obY(a0),LCon_originY(a0)
.origin_ready:
		; Retain the whole horizontal path, including the wide LZ3 loops.
		move.w	(a2)+,d0
		add.w	LCon_originX(a0),d0
		andi.w	#$FF80,d0
		move.w	(a2)+,d2
		add.w	LCon_originX(a0),d2
		andi.w	#$FF80,d2
		move.w	d2,LCon_rightX(a0)
		sub.w	d0,d2
		addi.w	#$280,d2
		move.w	d2,LCon_loadwidth(a0)
		move.l	a2,LCon_targetdata(a0)
		andi.w	#$F,d1
		lsl.w	#2,d1
		cmp.b	LCon_count(a0),d1
		blo.s	.phase_ready
		moveq	#0,d1			; invalid individual phase starts at corner 0
.phase_ready:
		move.b	d1,LCon_posindex(a0)
		tst.b	LCon_member(a0)
		bne.s	.position_ready
		move.w	(a2,d1.w),d0
		add.w	LCon_originX(a0),d0
		move.w	d0,obX(a0)
		move.w	2(a2,d1.w),d0
		add.w	LCon_originY(a0),d0
		move.w	d0,obY(a0)
.position_ready:
		move.b	#4,LCon_increment(a0)
		btst	#0,obStatus(a0)
		beq.s	.check_switch
		neg.b	LCon_increment(a0)
.check_switch:
		tst.b	(f_conveyrev).w
		beq.s	.direction_ready
		move.b	#1,LCon_reversed(a0)
		neg.b	LCon_increment(a0)
.direction_ready:
		tst.b	LCon_increment(a0)
		bpl.s	.forward
		bsr.w	LCon_AdvanceTarget
		bra.s	LCon_Platform
.forward:
		bsr.w	LCon_SetTarget
; ---------------------------------------------------------------------------
LCon_Platform:
		move.w	LCon_rightX(a0),d0
		sub.w	(Camera_X_pos_coarse_back).w,d0
		cmp.w	LCon_loadwidth(a0),d0
		bhi.s	LCon_Unload
		move.w	obX(a0),-(sp)
		bsr.w	LCon_Move
		move.w	#$10+sonic_solid_width,d1
		moveq	#8,d2			; physical platform is 32 by 16 pixels
		moveq	#9,d3
		move.w	(sp)+,d4
		jsr	(SolidObject).l		; both actors, with side/underside response
		btst	#0,LCon_settings(a0)
		beq.s	.display
		swap	d6			; underside contact bits: primary / companion
		andi.w	#$C,d6
		beq.s	.display
		btst	#2,d6
		beq.s	.partner
		lea	(v_player).w,a1
		jsr	(Spike_HurtCharacter).l	; shared S3&K damage/invulnerability handling
.partner:
		btst	#3,d6
		beq.s	.display
		lea	(v_player2).w,a1
		jsr	(Spike_HurtCharacter).l
.display:
		jmp	(DisplaySprite).l
LCon_Unload:
		jmp	(UnloadObject).l
; ---------------------------------------------------------------------------
; Count free SSTs before changing the parent or allocating any member.
; A single layout placement owns the loop; children have no respawn handle.
LCon_Spawn:
		out_of_range2	UnloadObject,obX(a0)
		; out_of_range2 changes d0, so reload the actual group number.
		moveq	#0,d0
		move.w	obSubtype(a0),d0
		andi.w	#$3F,d0			; group selector excludes the damage modifier
		cmpi.w	#LCon_GroupCount,d0
		bhs.s	LCon_Unload
		add.w	d0,d0
		lea	LCon_Placements(pc),a2
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,d1
		move.w	d1,d6
		beq.s	.spawn
		lea	(v_lvlobjspace).w,a1
		move.w	#(v_lvlobjend-v_lvlobjspace)/object_size-1,d0
.count_free:
		tst.l	code(a1)
		bne.s	.next
		subq.w	#1,d1
		beq.s	.spawn
.next:
		lea	object_size(a1),a1
		dbf	d0,.count_free
		rts
.spawn:
		moveq	#0,d4
		move.w	obSubtype(a0),d4
		andi.w	#$40,d4
		lsr.w	#6,d4			; pass the group's damage flag to every child
		move.w	obX(a0),d2
		move.w	obY(a0),d3
		movea.l	a0,a1
.make_platform:
		move.l	#LabyrinthConvey,code(a1)
		move.w	(a2)+,d0
		add.w	d2,d0
		move.w	d0,obX(a1)
		move.w	(a2)+,d0
		add.w	d3,d0
		move.w	d0,obY(a1)
		move.w	d2,LCon_originX(a1)
		move.w	d3,LCon_originY(a1)
		move.w	(a2)+,d0
		move.w	d0,obSubtype(a1)
		lsr.w	#8,d0			; recipe upper byte supplies extra settings
		or.b	d4,d0
		move.b	d0,LCon_settings(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	#1,LCon_member(a1)
		dbf	d6,.allocate
		rts
.allocate:
		jsr	(FindFreeObj).l
		clr.w	respawn_addr(a1)
		bra.s	.make_platform
; ---------------------------------------------------------------------------
LCon_Wheel:
		bsr.s	LCon_UpdateWheels
		jmp	(RememberState).l
; ---------------------------------------------------------------------------
; One shared clock/cache for every wheel. Queue at most once per game frame,
; and let the common atomic DPLC loader retry a failed upload next frame.
LCon_ResetWheels:
		clr.l	(v_lcon_wheel_frame).w
		clr.w	(v_lcon_wheel_updated).w
		st	(v_lcon_wheel_artframe).w
		rts
LCon_UpdateWheels:
		move.w	(v_framecount).w,d0
		tst.b	(v_lcon_wheel_updated).w
		beq.s	.update
		cmp.w	(v_lcon_wheel_updateframe).w,d0
		beq.s	.return
.update:
		move.w	d0,(v_lcon_wheel_updateframe).w
		st	(v_lcon_wheel_updated).w
		andi.w	#3,d0
		bne.s	.load
		moveq	#1,d0
		tst.b	(f_conveyrev).w
		beq.s	.advance
		neg.b	d0
.advance:
		add.b	d0,(v_lcon_wheel_frame).w
		andi.b	#3,(v_lcon_wheel_frame).w
.load:
		moveq	#0,d0
		move.b	(v_lcon_wheel_frame).w,d0
		lea	DPLC_LConWheels(pc),a2
		lea	(v_lcon_wheel_artframe).w,a3
		move.w	#ArtTile_LZ_Conveyor_Belt*tile_size,d4
		move.l	#Art_LConWheels,d6
		jmp	(Load_DynamicPLC).l
.return:
		rts
; S3&K DPLC format: one 16-tile run for each source wheel frame.
DPLC_LConWheels:
		dc.w .frame0-DPLC_LConWheels, .frame1-DPLC_LConWheels
		dc.w .frame2-DPLC_LConWheels, .frame3-DPLC_LConWheels
.frame0:	dc.w 1, $F000
.frame1:	dc.w 1, $F010
.frame2:	dc.w 1, $F020
.frame3:	dc.w 1, $F030
; ---------------------------------------------------------------------------
LCon_Move:
		tst.b	(f_switch+$E).w
		beq.s	.check_corner
		tst.b	LCon_reversed(a0)
		bne.s	.check_corner
		move.b	#1,LCon_reversed(a0)
		move.b	#1,(f_conveyrev).w	; S1's reversal stays latched after release
		neg.b	LCon_increment(a0)
		bsr.s	LCon_AdvanceTarget
		jmp	(SpeedToPos).l
.check_corner:
		move.w	obX(a0),d0
		cmp.w	LCon_nextX(a0),d0
		bne.s	.move
		move.w	obY(a0),d0
		cmp.w	LCon_nextY(a0),d0
		bne.s	.move
		bsr.s	LCon_AdvanceTarget
.move:
		jmp	(SpeedToPos).l
; ---------------------------------------------------------------------------
LCon_AdvanceTarget:
		moveq	#0,d1
		move.b	LCon_posindex(a0),d1
		add.b	LCon_increment(a0),d1
		cmp.b	LCon_count(a0),d1
		blo.s	.store
		move.b	d1,d0
		moveq	#0,d1
		tst.b	d0
		bpl.s	.store
		move.b	LCon_count(a0),d1
		subq.b	#4,d1
.store:
		move.b	d1,LCon_posindex(a0)
LCon_SetTarget:
		movea.l	LCon_targetdata(a0),a1
		move.w	(a1,d1.w),d0
		add.w	LCon_originX(a0),d0
		move.w	d0,LCon_nextX(a0)
		move.w	2(a1,d1.w),d0
		add.w	LCon_originY(a0),d0
		move.w	d0,LCon_nextY(a0)
; Fall through to the S2/S3&K dominant-axis velocity calculation.
LCon_ChangeDir:
		moveq	#0,d0
		move.w	#-$100,d2
		move.w	obX(a0),d0
		sub.w	LCon_nextX(a0),d0
		bcc.s	LCon_VelocityY
		neg.w	d0
		neg.w	d2

LCon_VelocityY:
		moveq	#0,d1
		move.w	#-$100,d3
		move.w	obY(a0),d1
		sub.w	LCon_nextY(a0),d1
		bcc.s	LCon_VelocityAxis
		neg.w	d1
		neg.w	d3

LCon_VelocityAxis:
		cmp.w	d0,d1
		blo.s	LCon_VelocityX
		move.w	obX(a0),d0
		sub.w	LCon_nextX(a0),d0
		beq.s	LCon_SetYMajor
		ext.l	d0
		asl.l	#8,d0
		divs.w	d1,d0
		neg.w	d0

LCon_SetYMajor:
		move.w	d0,obVelX(a0)
		move.w	d3,obVelY(a0)
		swap	d0
		move.w	d0,obXSub(a0)
		clr.w	obYSub(a0)
		rts
; ===========================================================================

LCon_VelocityX:
		move.w	obY(a0),d1
		sub.w	LCon_nextY(a0),d1
		beq.s	LCon_SetXMajor
		ext.l	d1
		asl.l	#8,d1
		divs.w	d0,d1
		neg.w	d1

LCon_SetXMajor:
		move.w	d1,obVelY(a0)
		move.w	d2,obVelX(a0)
		swap	d1
		move.w	d1,obYSub(a0)
		clr.w	obXSub(a0)
		rts

; ---------------------------------------------------------------------------
; Route header: byte count of points, leftmost X, rightmost X.
; Points: signed X/Y offsets from the placement origin.
LCon_Data:
		dc.w LCon_Path0-LCon_Data
		dc.w LCon_Path1-LCon_Data
		dc.w LCon_Path2-LCon_Data
		dc.w LCon_Path3-LCon_Data
		dc.w LCon_Path4-LCon_Data
		dc.w LCon_Path5-LCon_Data
		dc.w LCon_Path6-LCon_Data
		dc.w LCon_Path7-LCon_Data
LCon_Data_End:
LCon_Path0:
		dc.w 6*4, -$4E, $4E
		dc.w $8, -$D6
		dc.w $4E, -$90
		dc.w $4E, $A3
		dc.w $1C, $D5
		dc.w -$4E, $A0
		dc.w -$4E, -$AC
LCon_Path1:
		dc.w 5*4, -$4E, $4E
		dc.w -$2, -$F7
		dc.w $4E, -$A7
		dc.w $4E, $F7
		dc.w -$4E, $A9
		dc.w -$4E, -$AB
LCon_Path2:
		dc.w 4*4, -$46, $46
		dc.w -$46, -$AE
		dc.w -$46, $AE
		dc.w $46, $AE
		dc.w $46, -$AE
LCon_Path3:
		dc.w 4*4, -$3E, $4E
		dc.w -$3E, -$9E
		dc.w $4E, -$9E
		dc.w $4E, $9E
		dc.w -$3E, $9E
LCon_Path4:
		dc.w 5*4, -$AE, $DE
		dc.w -$54, -$CE
		dc.w $DE, -$CE
		dc.w $DE, $CE
		dc.w -$AE, $CE
		dc.w -$AE, -$74
LCon_Path5:
		dc.w 4*4, -$AE, $DE
		dc.w -$AE, -$5A
		dc.w $DE, -$5A
		dc.w $DE, $5A
		dc.w -$AE, $5A
LCon_Path6:
		dc.w 10*4, -$20, $20
		dc.w $0, $0
		dc.w -$16, $A
		dc.w -$20, $20
		dc.w -$20, $C0
		dc.w -$16, $D6
		dc.w $0, $E0
		dc.w $16, $D6
		dc.w $20, $C0
		dc.w $20, $20
		dc.w $16, $A
LCon_Path7:
		dc.w 10*4, -$20, $20
		dc.w $0, $0
		dc.w -$16, $A
		dc.w -$20, $20
		dc.w -$20, $1C0
		dc.w -$16, $1D6
		dc.w $0, $1E0
		dc.w $16, $1D6
		dc.w $20, $1C0
		dc.w $20, $20
		dc.w $16, $A
; ---------------------------------------------------------------------------
; Group header: members minus one. Members: relative X, relative Y, settings/subtype.
; The subtype word's low byte selects route/phase; upper-byte bit 0 adds spikes.
; Groups 0-5 preserve S1 REV01 platform spacing; 6-7 are S3&K LRZ loops.
LCon_Placements:
		dc.w LCon_Group0-LCon_Placements
		dc.w LCon_Group1-LCon_Placements
		dc.w LCon_Group2-LCon_Placements
		dc.w LCon_Group3-LCon_Placements
		dc.w LCon_Group4-LCon_Placements
		dc.w LCon_Group5-LCon_Placements
		dc.w LCon_Group6-LCon_Placements
		dc.w LCon_Group7-LCon_Placements
LCon_Placements_End:
LCon_Group0:
		dc.w 8-1
		dc.w $8, -$D6, $0
		dc.w $4E, -$5F, $2
		dc.w $4E, $17, $2
		dc.w $4E, $8E, $2
		dc.w -$14, $A0, $4
		dc.w -$4E, $62, $5
		dc.w -$4E, -$15, $5
		dc.w -$4E, -$8B, $5
LCon_Group1:
		dc.w 8-1
		dc.w -$2, -$F7, $10
		dc.w $4E, -$72, $12
		dc.w $4E, $13, $12
		dc.w $4E, $98, $12
		dc.w $27, $F7, $13
		dc.w -$4E, $98, $14
		dc.w -$4E, $13, $14
		dc.w -$4E, -$72, $14
LCon_Group2:
		dc.w 8-1
		dc.w -$46, -$AD, $21
		dc.w $34, -$AE, $20
		dc.w $46, -$46, $23
		dc.w $46, $34, $23
		dc.w $46, $AD, $23
		dc.w -$34, $AE, $22
		dc.w -$46, $46, $21
		dc.w -$46, -$34, $21
LCon_Group3:
		dc.w 8-1
		dc.w -$3E, -$9E, $30
		dc.w $34, -$9E, $31
		dc.w $4E, -$46, $32
		dc.w $4E, $2C, $32
		dc.w $4E, $9D, $32
		dc.w -$24, $9E, $33
		dc.w -$3E, $46, $30
		dc.w -$3E, -$2C, $30
LCon_Group4:
		dc.w 12-1
		dc.w -$53, -$CE, $41
		dc.w $2D, -$CE, $41
		dc.w $AC, -$CE, $41
		dc.w $DE, -$81, $42
		dc.w $DE, -$2, $42
		dc.w $DE, $7D, $42
		dc.w $B0, $CE, $43
		dc.w $31, $CE, $43
		dc.w -$4E, $CE, $43
		dc.w -$AE, $AF, $44
		dc.w -$AE, $30, $44
		dc.w -$AE, -$4F, $44
LCon_Group5:
		dc.w 9-1
		dc.w -$AE, -$5A, $50
		dc.w -$2E, -$5A, $51
		dc.w $52, -$5A, $51
		dc.w $D2, -$5A, $51
		dc.w $DE, $1A, $52
		dc.w $9E, $5A, $53
		dc.w $1E, $5A, $53
		dc.w -$62, $5A, $53
		dc.w -$AE, $26, $50
LCon_Group6:
		dc.w 4-1
		dc.w $0, $0, $61
		dc.w -$20, $70, $63
		dc.w $0, $E0, $66
		dc.w $20, $70, $68
LCon_Group7:
		dc.w 8-1
		dc.w $0, $0, $71
		dc.w -$20, $72, $73
		dc.w -$20, $F0, $73
		dc.w -$20, $16E, $73
		dc.w $0, $1E0, $76
		dc.w $20, $16E, $78
		dc.w $20, $F0, $78
		dc.w $20, $72, $78
