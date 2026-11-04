; ---------------------------------------------------------------------------
; Object 96 - bonus stage results screen
; ---------------------------------------------------------------------------

BonusGotThrough:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	SSR_Index(pc,d0.w),d1
		jmp	SSR_Index(pc,d1.w)
; ===========================================================================
SSR_Index:	dc.w SSR_ChkPLC-SSR_Index
		dc.w SSR_Move-SSR_Index
		dc.w SSR_Wait-SSR_Index
		dc.w SSR_RingBonus-SSR_Index
		dc.w SSR_Wait-SSR_Index
		dc.w SSR_Exit-SSR_Index
		dc.w SSR_Wait-SSR_Index
		dc.w SSR_Continue-SSR_Index
		dc.w SSR_Wait-SSR_Index
		dc.w SSR_Exit-SSR_Index
		dc.w loc_BEF2-SSR_Index
		dc.w SSR_Display-SSR_Index	; $16: assembled old heading waits for the tally controller
		dc.w SSR_AnnouncementOut-SSR_Index
		dc.w SSR_AnnouncementIn-SSR_Index
		dc.w SSR_Display-SSR_Index
		dc.w SSR_WaitAnnouncement-SSR_Index
		dc.w SSR_Wait-SSR_Index
		dc.w SSR_ExitLevel-SSR_Index

ssr_mainX = objoff_34	; position for card to display on
ssr_splitoffset = objoff_36	; all-seven left/right distance from the common anchor
SSR_HeadingRightFrame = 8
SSR_AnnouncementRightFrame = 9
SSR_HeadingEntryOffset = $120	; both incoming groups start wholly offscreen
SSR_HeadingExitOffset = $A0	; both old groups clear the edges after five exit steps
SSR_AnnouncementFrame = 7
SSR_PostTallyDelay = 2*60		; S3&K: pause after the completed tally
SSR_ContinueDelay = 270		; S3&K: let the Continue celebration finish
SSR_AnnouncementHold = 4*60	; S3&K: display time from the new message spawning
; ===========================================================================

SSR_ChkPLC:	; Routine 0
		tst.l	(v_plc_buffer).w ; are the pattern load cues empty?
		bne.s	.wait
		jsr	(Get_SpecialCardScene).l
		move.w	#ArtTile_Results_Card*tile_size,d4
		jsr	(Load_CardDPLC).l
		bcc.s	SSR_Main
.wait:
		rts
; ===========================================================================

SSR_Main:
		jsr	(Get_SpecialCardScene).l
		movea.l	a0,a1
		lea	(SSR_Config).l,a2
		move.b	#Map_SSR_2_0_height,d3	; covers both heading groups and the oval
		move.l	#BonusGotThrough,d6
		moveq	#(SSR_Config_Continue-SSR_Config)/8-1,d1
		cmpi.w	#50,(v_rings).w	; do you have 50 or more rings?
		bcs.s	SSR_Loop	; if not, branch
		addq.w	#1,d1		; if yes, add 1	to d1 (number of sprites)

SSR_Loop:
		bsr.w	Card_InitResultSprite
		lea	object_size(a1),a1
		dbf	d1,SSR_Loop	; score, ring bonus, oval and optional Continue
		cmpi.b	#7,(v_emeralds).w
		bne.s	SSR_Move
		tst.b	(v_ss_emerald_collected).w
		beq.s	SSR_Move
		; Slot 21 is shared with the inactive normal-results card, inside the
		; existing reserved pool. Its glyphs use the same loaded scene bank.
		lea	(v_bsresright).w,a1
		lea	SSR_Config_Right(pc),a2
		bsr.w	Card_InitResultSprite
		bset	#obRender.explicit_height,obRender(a1) ; clip offscreen pieces before VDP X wrapping
		bset	#obRender.explicit_height,obRender(a0)
		move.w	(v_bsresoval+ssr_mainX).w,(v_bsresoval+obX).w
		move.w	#$80,(v_bsresoval+obPriority).w ; both heading groups draw in front
		move.w	#SSR_HeadingEntryOffset,ssr_splitoffset(a0)
		move.b	#$1A,obRoutine(a0)
		bra.w	SSR_AnnouncementIn

SSR_Move:	; Routine 2
		moveq	#$10,d1		; set horizontal speed
		move.w	ssr_mainX(a0),d0
		cmp.w	obX(a0),d0	; has item reached its target position?
		beq.s	loc_BE44	; if it has, branch
		bge.s	SSR_ChgPos
		neg.w	d1

SSR_ChgPos:
		add.w	d1,obX(a0)	; change item's position

loc_BE32:
		move.w	obX(a0),d0
		bmi.s	locret_BE42
		cmpi.w	#$200,d0	; has item moved beyond	$200 on	x-axis?
		bcc.s	locret_BE42	; if yes, branch
		bra.w	DisplaySprite
; ===========================================================================

locret_BE42:
		rts
; ===========================================================================

loc_BE44:
		cmpi.b	#2,obFrame(a0)
		bne.s	loc_BE32
		addq.b	#2,obRoutine(a0)
		move.w	#180,objoff_38(a0) ; set time delay to 3 seconds
		move.l	#ChaosEmeralds,(v_ssresemeralds).w ; load chaos emerald object

SSR_Wait:	; Routine 4, 8, $C, $10, $20
		subq.w	#1,objoff_38(a0) ; subtract 1 from time delay
		bne.s	SSR_Display
		addq.b	#2,obRoutine(a0)

SSR_Display:
		bra.w	DisplaySprite
; ===========================================================================

; A single offset keeps the two heading objects synchronized around the oval.
; The right object only displays; the left owner advances both positions/frames.
SSR_AnnouncementOut:	; Routine $18
		addi.w	#$20,ssr_splitoffset(a0) ; title-card exit speed, towards opposite edges
		cmpi.w	#SSR_HeadingExitOffset,ssr_splitoffset(a0)
		bcs.s	SSR_HeadingPosition
		; Both old groups are now wholly offscreen. Begin the new pair together.
		move.b	#SSR_AnnouncementFrame,obFrame(a0)
		move.b	#SSR_AnnouncementRightFrame,(v_bsresright+obFrame).w
		move.w	#SSR_HeadingEntryOffset,ssr_splitoffset(a0)
		move.b	#$1A,obRoutine(a0)
		bra.s	SSR_HeadingPosition

SSR_AnnouncementIn:	; Routine $1A; initial GOT/THEM ALL and subsequent Super pair
		subi.w	#$10,ssr_splitoffset(a0) ; title-card entry speed
		bne.s	SSR_HeadingPosition
		move.b	#$1C,obRoutine(a0)
		tst.b	obFrame(a0)
		bne.s	SSR_HeadingPosition
		move.b	#$16,obRoutine(a0)	; the ring-bonus controller starts the transition

SSR_HeadingPosition:
		move.w	ssr_mainX(a0),d0
		move.w	d0,d1
		sub.w	ssr_splitoffset(a0),d0
		add.w	ssr_splitoffset(a0),d1
		move.w	d0,obX(a0)
		move.w	d1,(v_bsresright+obX).w
		bra.w	DisplaySprite
; ===========================================================================

SSR_RingBonus:	; Routine 6
		bsr.w	DisplaySprite
		move.b	#1,(f_endactbonus).w ; set ring bonus update flag
		tst.w	(v_ringbonus).w	; is ring bonus	= zero?
		beq.s	loc_BE9C	; if yes, branch
		subi.w	#10,(v_ringbonus).w ; subtract 10 from ring bonus
		moveq	#10,d0		; add 10 to score
		jsr	(AddPoints).l
		move.b	(Vint_runcount+3).w,d0
		andi.b	#3,d0
		bne.s	locret_BEC2
		move.w	#sfx_Switch,d0
		jmp	(PlaySound_Special).l	; play "blip" sound
; ===========================================================================

loc_BE9C:
		move.w	#sfx_Cash,d0
		jsr	(PlaySound_Special).l	; play "ker-ching" sound
		addq.b	#2,obRoutine(a0)
		move.w	#180,objoff_38(a0) ; set time delay to 3 seconds
		cmpi.w	#50,(v_rings).w	; do you have at least 50 rings?
		bcs.s	.post_tally
		move.w	#60,objoff_38(a0) ; ordinary results pause before Continue
		addq.b	#4,obRoutine(a0) ; goto "SSR_Continue" routine
.post_tally:
		tst.l	(v_bsresright).w	; the split heading exists only on a fresh seventh emerald
		beq.s	locret_BEC2
		move.w	#SSR_PostTallyDelay,objoff_38(a0)

locret_BEC2:
		rts
; ===========================================================================

SSR_Exit:	; Routine $A, $12: ordinary exit, or start the all-seven announcement
		tst.l	(v_bsresright).w
		beq.s	SSR_ExitLevel
		move.b	#$18,(v_bsrestext+obRoutine).w
		move.b	#$1E,obRoutine(a0)
		bra.w	DisplaySprite

SSR_WaitAnnouncement:	; Routine $1E; old groups must leave before the new hold starts
		cmpi.b	#SSR_AnnouncementFrame,(v_bsrestext+obFrame).w
		bne.w	SSR_Display
		move.w	#SSR_AnnouncementHold,objoff_38(a0)
		move.b	#$20,obRoutine(a0)
		bra.w	DisplaySprite

SSR_ExitLevel:	; Routine $22, or an ordinary result without the split heading
		move.w	#1,(Level_Inactive_flag).w ; restart level
		bra.w	DisplaySprite
; ===========================================================================

SSR_Continue:	; Routine $E
		move.b	#4,(v_ssrescontinue+obFrame).w
		move.b	#$14,(v_ssrescontinue+obRoutine).w
		move.w	#sfx_Continue,d0
		jsr	(PlaySound_Special).l	; play continues jingle
		addq.b	#2,obRoutine(a0)
		move.w	#360,objoff_38(a0) ; ordinary results Continue hold
		tst.l	(v_bsresright).w
		beq.w	SSR_Display
		move.w	#SSR_ContinueDelay,objoff_38(a0)
		bra.w	DisplaySprite
; ===========================================================================

loc_BEF2:	; Routine $14
		move.b	(Vint_runcount+3).w,d0
		andi.b	#$F,d0
		bne.s	SSR_Display2
		bchg	#0,obFrame(a0)

SSR_Display2:
		bra.w	DisplaySprite
; ===========================================================================
SSR_Config:	dc.w $20, $120,	$C4	; start	x-pos, main x-pos, y-pos
		dc.b 2,	0		; rountine number, frame number
		dc.w $320, $120, $118
		dc.b 2,	1
		dc.w $360, $120, $128
		dc.b 2,	2
		dc.w $1EC, $11C, $BC	; oval clears the top emerald row
		dc.b 2,	3
SSR_Config_Continue:
		dc.w $3A0, $120, $138
		dc.b 2,	6
SSR_Config_Right:
		dc.w $240, $120, $C4	; separate right group, sharing the heading's center
		dc.b $1C, SSR_HeadingRightFrame
