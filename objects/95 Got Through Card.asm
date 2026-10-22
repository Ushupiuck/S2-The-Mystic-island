; ---------------------------------------------------------------------------
; Object 95 - End of level results screen
; ---------------------------------------------------------------------------

GotThrough:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Got_Index(pc,d0.w),d1
		jmp	Got_Index(pc,d1.w)
; ===========================================================================
Got_Index:	dc.w Got_ChkPLC-Got_Index
		dc.w Got_Move-Got_Index
		dc.w Got_Wait-Got_Index
		dc.w Got_TimeBonus-Got_Index
		dc.w Got_Wait-Got_Index
		dc.w Got_NextLevel-Got_Index
		dc.w Got_Wait-Got_Index
		dc.w Got_Move2-Got_Index
		dc.w loc_BD3A-Got_Index

got_mainX = objoff_34		; position for card to display on
got_finalX = objoff_36		; position for card to finish on
; ===========================================================================

Got_ChkPLC:	; Routine 0
		tst.l	(v_plc_buffer).w ; are the pattern load cues empty?
		bne.s	.return
		jsr	(Get_NormalCardScene).l
		move.w	#ArtTile_Title_Card*tile_size,d4
		jsr	(Load_CardDPLC).l
		bcc.s	Got_Main
.return:
		rts
; ---------------------------------------------------------------------------

Got_Main:
		jsr	(Get_NormalCardScene).l
		movea.l	a0,a1
		lea	(Got_Config).l,a2
		moveq	#6,d1

Got_Loop:
		move.l	#GotThrough,code(a1)
		move.w	(a2),obX(a1)	; load start x-position
		move.w	(a2)+,got_finalX(a1) ; load finish x-position (same as start)
		move.w	(a2)+,got_mainX(a1) ; load main x-position
		move.w	(a2)+,obScreenY(a1) ; load y-position
		move.b	(a2)+,obRoutine(a1)
		move.b	(a2)+,d0
		cmpi.b	#6,d0
		bne.s	loc_BB94
		add.b	(Current_Act).w,d0	; add act number to frame number

loc_BB94:
		move.b	d0,obFrame(a1)
		move.l	a3,obMap(a1)
		move.b	#Map_Obj3A_height,height_pixels(a1)
		move.w	#make_art_tile(ArtTile_Title_Card,0,1),obGfx(a1)
		sf	obRender(a1)
		lea	object_size(a1),a1
		dbf	d1,Got_Loop	; repeat 6 times

Got_Move:	; Routine 2
		moveq	#$10,d1		; set horizontal speed
		move.w	got_mainX(a0),d0
		cmp.w	obX(a0),d0	; has item reached its target position?
		beq.s	loc_BBEA	; if yes, branch
		bge.s	Got_ChgPos
		neg.w	d1

Got_ChgPos:
		add.w	d1,obX(a0)	; change item's position

loc_BBCC:
		move.w	obX(a0),d0
		bmi.s	Got_ChkPLC.return
		cmpi.w	#$200,d0	; has item moved beyond	$200 on	x-axis?
		bcc.s	Got_ChkPLC.return	; if yes, branch
		bra.w	DisplaySprite
; ===========================================================================

loc_BBE0:
		move.b	#$E,obRoutine(a0)
		bra.w	Got_Move2
; ===========================================================================

loc_BBEA:
		cmpi.b	#$E,(v_endcardring+obRoutine).w
		beq.s	loc_BBE0
		cmpi.b	#4,obFrame(a0)
		bne.s	loc_BBCC
		addq.b	#2,obRoutine(a0)
		move.b	#180,obTimeFrame(a0) ; set time delay to 3 seconds

Got_Wait:	; Routine 4, 8, $C
		subq.b	#1,obTimeFrame(a0) ; subtract 1 from time delay
		bne.s	Got_Display
		addq.b	#2,obRoutine(a0)

Got_Display:
		bra.w	DisplaySprite
; ===========================================================================

Got_TimeBonus:	; Routine 6
		bsr.w	DisplaySprite
		move.b	#1,(f_endactbonus).w ; set time/ring bonus update flag
		moveq	#0,d0
		tst.w	(v_timebonus).w	; is time bonus	= zero?
		beq.s	Got_RingBonus	; if yes, branch
		addi.w	#10,d0		; add 10 to score
		subi.w	#10,(v_timebonus).w ; subtract 10 from time bonus

Got_RingBonus:
		tst.w	(v_ringbonus).w	; is ring bonus	= zero?
		beq.s	Got_ChkBonus	; if yes, branch
		addi.w	#10,d0		; add 10 to score
		subi.w	#10,(v_ringbonus).w ; subtract 10 from ring bonus

Got_ChkBonus:
		tst.w	d0		; is there any bonus?
		bne.s	Got_AddBonus	; if yes, branch
		move.w	#sfx_Cash,d0
		jsr	(PlaySound_Special).l	; play "ker-ching" sound
		addq.b	#2,obRoutine(a0)
		cmpi.w	#(id_SBZ<<8)+1,(Current_ZoneAndAct).w
		bne.s	Got_SetDelay
		addq.b	#4,obRoutine(a0)

Got_SetDelay:
		move.b	#180,obTimeFrame(a0) ; set time delay to 3 seconds
-		rts
; ===========================================================================

Got_AddBonus:
		jsr	(AddPoints).l
		move.b	(Vint_runcount+3).w,d0
		andi.b	#3,d0
		bne.s	-
		move.w	#sfx_Switch,d0
		jmp	(PlaySound_Special).l	; play "blip" sound
; ===========================================================================

Got_NextLevel:	; Routine $A
		move.b	(Current_Zone).w,d0
		andi.w	#$F,d0
		lsl.w	#3,d0
		move.b	(Current_Act).w,d1
		andi.w	#3,d1
		add.w	d1,d1
		add.w	d1,d0
		move.w	LevelOrder(pc,d0.w),d0 ; load level from level order array
		move.w	d0,(Current_ZoneAndAct).w	; set level number
		tst.w	d0
		bne.s	Got_ChkSS
		move.w	#SegaScreen,(v_gamemode).w
		bra.w	DisplaySprite
; ===========================================================================

Got_ChkSS:
		clr.b	(v_lastlamp).w	; clear	lamppost counter
		tst.b	(f_bigring).w	; has Sonic jumped into	a giant	ring?
		beq.s	VBla_08A	; if not, branch
		move.w	#BonusStage,(v_gamemode).w ; set game mode to Special Stage (10)
		bra.w	DisplaySprite
; ===========================================================================

VBla_08A:
		move.w	#1,(Level_Inactive_flag).w
		bra.w	DisplaySprite
; ===========================================================================
; ---------------------------------------------------------------------------
; Level	order array
; ---------------------------------------------------------------------------
LevelOrder: ; Don't be fooled: the 2nd byte is the act you're transitioning TO
; Four entries per current zone, indexed by the current act (0-3).

		; Twilight Hill Zone
		dc.b id_GHZ, 1	; Act 1 -> Act 2
		dc.b id_GHZ, 2	; Act 2 -> Act 3
		dc.b id_SMZ, 0	; Act 3 -> SMZ Act 1
		dc.b id_LZ, 0	; Act 4 -> Rustic Ruins Zone Act 1

		; Rustic Ruins Zone
		dc.b id_LZ, 1	; Act 1 -> Act 2
		dc.b id_LZ, 2	; Act 2 -> Act 3
		dc.b id_LZ, 3	; Act 3 -> Act 4
		dc.b id_CPZ, 0	; Act 4 -> Ancient Workbench Zone Act 1

		; Ancient Workbench Zone
		dc.b id_CPZ, 1	; Act 1 -> Act 2
		dc.b id_CPZ, 2	; Act 2 -> Act 3
		dc.b id_CPZ, 3	; Act 3 -> Act 4
		dc.b id_EHZ, 0	; Act 4 -> Emerald Hill Zone Act 1

		; Emerald Hill Zone
		dc.b id_EHZ, 1	; Act 1 -> Act 2
		dc.b id_EHZ, 2	; Act 2 -> Act 3
		dc.b id_EHZ, 3	; Act 3 -> Act 4
		dc.b id_HPZ, 0	; Act 4 -> Crystal Valley Zone Act 1

		; Crystal Valley Zone
		dc.b id_HPZ, 1	; Act 1 -> Act 2
		dc.b id_HPZ, 2	; Act 2 -> Act 3
		dc.b id_HPZ, 3	; Act 3 -> Act 4
		dc.b id_HTZ, 0	; Act 4 -> Egg Mountain Zone Act 1

		; Egg Mountain Zone
		dc.b id_HTZ, 1	; Act 1 -> Act 2
		dc.b id_HTZ, 2	; Act 2 -> Act 3
		dc.b id_HTZ, 3	; Act 3 -> Act 4
		dc.b id_MTZ, 0	; Act 4 -> Metropolis Zone Act 1

		; Metropolis Zone
		dc.b id_MTZ, 1	; Act 1 -> Act 2
		dc.b id_MTZ, 2	; Act 2 -> Act 3
		dc.b id_MTZ, 3	; Act 3 -> Act 4
		dc.b $07, 0	; Act 4 -> Shocking Blizzard Zone Act 1

		; Shocking Blizzard Zone
		dc.b $07, 1	; Act 1 -> Act 2
		dc.b $07, 2	; Act 2 -> Act 3
		dc.b $07, 3	; Act 3 -> Act 4
		dc.b id_SMZ, 0	; Act 4 -> Scrap Madness Zone Act 1

		; Scrap Madness Zone
		dc.b id_SMZ, 1	; Act 1 -> Act 2
		dc.b id_EHZ, 0	; Act 2 -> EHZ Act 1	; Sorry, no act 3 yet!
	;	dc.b id_SMZ, 2	; Act 2 -> Act 3
		dc.b id_EHZ, 0	; Act 3 -> EHZ Act 1
		dc.b id_DEZ, 0	; Act 4 -> Death Egg Zone Act 1

		; Death Egg Zone
		dc.b id_DEZ, 1	; Act 1 -> Act 2
		dc.b id_DEZ, 2	; Act 2 -> Act 3
		dc.b id_DEZ, 3	; Act 3 -> Act 4
		dc.b $0A, 0	; Act 4 -> Level 0A Act 1

		; Level 0A
		dc.b $0A, 1	; Act 1 -> Act 2
		dc.b $0A, 2	; Act 2 -> Act 3
		dc.b $0A, 3	; Act 3 -> Act 4
		dc.b $0B, 0	; Act 4 -> Level 0B Act 1

		; Level 0B
		dc.b $0B, 1	; Act 1 -> Act 2
		dc.b $0B, 2	; Act 2 -> Act 3
		dc.b $0B, 3	; Act 3 -> Act 4
		dc.b $0C, 0	; Act 4 -> Level 0C Act 1

		; Level 0C
		dc.b $0C, 1	; Act 1 -> Act 2
		dc.b $0C, 2	; Act 2 -> Act 3
		dc.b $0C, 3	; Act 3 -> Act 4
		dc.b $0D, 0	; Act 4 -> Level 0D Act 1

		; Level 0D
		dc.b $0D, 1	; Act 1 -> Act 2
		dc.b $0D, 2	; Act 2 -> Act 3
		dc.b $0D, 3	; Act 3 -> Act 4
		dc.b $0E, 0	; Act 4 -> Level 0E Act 1

		; Level 0E
		dc.b $0E, 1	; Act 1 -> Act 2
		dc.b $0E, 2	; Act 2 -> Act 3
		dc.b $0E, 3	; Act 3 -> Act 4
		dc.b $0F, 0	; Act 4 -> Level 0F Act 1

		; Level 0F
		dc.b $0F, 1	; Act 1 -> Act 2
		dc.b $0F, 2	; Act 2 -> Act 3
		dc.b $0F, 3	; Act 3 -> Act 4
		dc.b id_GHZ, 0	; Act 4 -> Twilight Hill Zone Act 1
		even

; ---------------------------------------------------------------------------

Got_Move2:	; Routine $E
		moveq	#$20,d1		; set horizontal speed
		move.w	got_finalX(a0),d0
		cmp.w	obX(a0),d0	; has item reached its finish position?
		beq.s	Got_SBZ2	; if yes, branch
		bge.s	Got_ChgPos2
		neg.w	d1

Got_ChgPos2:
		add.w	d1,obX(a0)	; change item's position
		move.w	obX(a0),d0
		bmi.s	loc_BD3A.return
		cmpi.w	#$200,d0	; has item moved beyond	$200 on	x-axis?
		bcc.s	loc_BD3A.return	; if yes, branch
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

Got_SBZ2:
		cmpi.b	#4,obFrame(a0)
		bne.w	DeleteObject
		addq.b	#2,obRoutine(a0)
		clr.b	(f_lockctrl).w	; unlock controls
		move.w	#bgm_FZ,d0
		jmp	(PlaySound).l	; play FZ music
; ---------------------------------------------------------------------------

 loc_BD3A:	; Routine $10
		addq.w	#2,(Camera_Max_X_pos).w
		cmpi.w	#$2100,(Camera_Max_X_pos).w
		beq.w	DeleteObject
.return:
		rts
; ---------------------------------------------------------------------------
		;    x-start,	x-main,	y-main,
		;				routine, frame number

Got_Config:	dc.w 4,		$124,	$BC			; "SONIC HAS"
		dc.b 				2,	0

		dc.w -$120,	$120,	$D0			; "PASSED"
		dc.b 				2,	1

		dc.w $40C,	$14C,	$D6			; "ACT" 1/2/3
		dc.b 				2,	6

		dc.w $520,	$120,	$EC			; score
		dc.b 				2,	2

		dc.w $540,	$120,	$FC			; time bonus
		dc.b 				2,	3

		dc.w $560,	$120,	$10C			; ring bonus
		dc.b 				2,	4

		dc.w $20C,	$14C,	$CC			; oval
		dc.b 				2,	5
