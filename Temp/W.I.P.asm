
LevelFGSetup_Null:
		jsr	Reset_TileOffsetPositionActual(pc)
		jmp	Refresh_PlaneFull(pc)
; ===========================================================================

LevelBGSetup_Null:
		jsr	Default_Deform(pc)
		jsr	Reset_TileOffsetPositionEff(pc)
		jsr	Refresh_PlaneFull(pc)
		jmp	Plain_Deformation(pc)
; ===========================================================================

LevelFGRun_Null:
		jmp	Load_Tiles_As_You_Move(pc)
; ===========================================================================

LevelBGRun_Null:
		jsr	Default_Deform(pc)
		jsr	Load_Tiles_As_You_Move_2(pc)
		jmp	Plain_Deformation(pc)
; ===========================================================================

Default_Deform:
		move.w	(Screen_Pos_Buffer_X).w,d0
		asr.w	#3,d0
		move.w	d0,(Screen_Pos_Buffer_X_2).w
		move.w	(Screen_Pos_Buffer_Y).w,d0
		asr.w	#3,d0
		move.w	d0,(Screen_Pos_Buffer_Y_2).w
		rts
;-------------------------------------------------------------------------------
; DrawTilesAsYouMove
Load_Tiles_As_You_Move:
		lea	(Screen_Pos_Buffer_X).w,a6
		lea	(Screen_Pos_Rounded_X).w,a5
		move.w	(Screen_Pos_Buffer_Y).w,d1
		moveq	#$0F,d6
		jsr	Draw_TileColumn(pc)
		lea	(Screen_Pos_Buffer_Y).w,a6
		lea	(Screen_Pos_Rounded_Y).w,a5
		move.w	(Screen_Pos_Buffer_X).w,d1
		moveq	#$15,d6
		jmp	Draw_TileRow(pc)
;-------------------------------------------------------------------------------
; DrawBGAsYouMove
Load_Tiles_As_You_Move_2:
		lea	(Screen_Pos_Buffer_X_2).w,a6
		lea	(Screen_Pos_Rounded_X_2).w,a5
		move.w	(Screen_Pos_Buffer_Y_2).w,d1
		moveq	#$0F,d6
		jsr	Draw_TileColumn(pc)
		lea	(Screen_Pos_Buffer_Y_2).w,a6
		lea	(Screen_Pos_Rounded_Y_2).w,a5
		move.w	(Screen_Pos_Buffer_X_2).w,d1
		moveq	#$15,d6
		jmp	Draw_TileRow(pc)
;-------------------------------------------------------------------------------
; Used by Mushroom hill act 2; Specifically, the boss arena
		movem.l d5/a4/a5,-(sp)
		lea	(Screen_Pos_Buffer_Y).w,a6
		jsr	Get_Deform_Draw_Position_Vertical(PC)
		lea	(Screen_Pos_Rounded_Y).w,a5
		jsr	Draw_Tile_Row_2(pc)
		movem.l (sp)+,d5/a4/a6
		move.w	(Screen_Pos_Rounded_Y).w,d6
		bra.s	Draw_Background_D6

; =============== S U B R O U T I N E =======================================


Draw_BG:
		movem.l	d5/a4-a5,-(sp)
		lea	(Camera_Y_pos_BG_copy).w,a6
		jsr	Get_DeformDrawPosVert(pc)
		lea	(Camera_Y_pos_BG_rounded).w,a5
		jsr	Draw_TileRow2(pc)
		movem.l	(sp)+,d5/a4/a6
		move.w	(Camera_Y_pos_BG_rounded).w,d6
		tst.w	(Camera_Y_pos_BG_copy).w
		bpl.s	Draw_BGNoVert
		move.w	(Camera_Y_pos_BG_copy).w,d6
		andi.w	#$FFF0,d6

Draw_BGNoVert:
		move.w	d6,d1

loc_4EE22:
		sub.w	(a4)+,d6
		bmi.s	loc_4EE32
		move.w	(a6)+,d0
		andi.w	#$FFF0,d0
		move.w	d0,(a6)+
		subq.w	#1,d5
		bra.s	loc_4EE22
; ---------------------------------------------------------------------------

loc_4EE32:
		neg.w	d6
		lsr.w	#4,d6
		moveq	#$F,d4
		sub.w	d6,d4
		bcc.s	loc_4EE40
		moveq	#0,d4
		moveq	#$F,d6

loc_4EE40:
		movem.w	d1/d4-d6,-(sp)
		movem.l	a4/a6,-(sp)
		lea	2(a6),a5
		jsr	Draw_TileColumn(pc)
		movem.l	(sp)+,a4/a6
		movem.w	(sp)+,d1/d4-d6
		addq.w	#4,a6
		tst.w	d4
		beq.s	loc_4EE74
		lsl.w	#4,d6
		add.w	d6,d1
		subq.w	#1,d5
		move.w	(a4)+,d6
		lsr.w	#4,d6
		move.w	d4,d0
		sub.w	d6,d4
		bpl.s	loc_4EE40
		move.w	d0,d6
		moveq	#0,d4
		bra.s	loc_4EE40
; ---------------------------------------------------------------------------

loc_4EE74:
		subq.w	#1,d5
		beq.s	locret_4EE82
		move.w	(a6)+,d0
		andi.w	#$FFF0,d0
		move.w	d0,(a6)+
		bra.s	loc_4EE74
; ---------------------------------------------------------------------------

locret_4EE82:
		rts
; End of function Draw_BG


; =============== S U B R O U T I N E =======================================


Get_DeformDrawPosVert:
		move.w	(a4)+,d2
		move.w	(a6),d0
		bsr.s	sub_4EE8E
		addi.w	#$E0,d0
; End of function Get_DeformDrawPosVert


; =============== S U B R O U T I N E =======================================


sub_4EE8E:
		cmp.w	d2,d0
		bmi.s	loc_4EE98
		add.w	(a4)+,d2
		addq.w	#4,a5
		bra.s	sub_4EE8E
; ---------------------------------------------------------------------------

loc_4EE98:
		move.w	(a5),d1
		swap	d1
		rts
; End of function sub_4EE8E

; ---------------------------------------------------------------------------

DrawTilesVDeform:
		movem.l	d5/a4-a5,-(sp)
		lea	(Camera_X_pos_copy).w,a6
		jsr	Get_XDeformRange(pc)
		lea	(Camera_X_pos_rounded).w,a5
		jsr	Draw_TileColumn2(pc)
		movem.l	(sp)+,d5/a4/a6
		move.w	(Camera_X_pos_rounded).w,d6
		bra.s	loc_4EED8

; ---------------------------------------------------------------------------

DrawTilesVDeform2:
		movem.l	d5/a4-a5,-(sp)
		lea	(Camera_X_pos_BG_copy).w,a6
		jsr	Get_XDeformRange(pc)
		lea	(Camera_X_pos_BG_rounded).w,a5
		jsr	Draw_TileColumn2(pc)
		movem.l	(sp)+,d5/a4/a6
		move.w	(Camera_X_pos_BG_rounded).w,d6

loc_4EED8:
		move.w	d6,d1

loc_4EEDA:
		sub.w	(a4)+,d6
		bcs.s	loc_4EEEA
		move.w	(a6)+,d0
		and.w	(Camera_Y_pos_mask).w,d0
		move.w	d0,(a6)+
		subq.w	#1,d5
		bra.s	loc_4EEDA
; ---------------------------------------------------------------------------

loc_4EEEA:
		neg.w	d6
		lsr.w	#4,d6
		moveq	#$15,d4
		sub.w	d6,d4
		bcc.s	loc_4EEF8
		moveq	#0,d4
		moveq	#$15,d6

loc_4EEF8:
		movem.w	d1/d4-d6,-(sp)
		movem.l	a4/a6,-(sp)
		lea	2(a6),a5
		jsr	Draw_TileRow(pc)
		movem.l	(sp)+,a4/a6
		movem.w	(sp)+,d1/d4-d6
		addq.w	#4,a6
		tst.w	d4
		beq.s	loc_4EF2C
		lsl.w	#4,d6
		add.w	d6,d1
		subq.w	#1,d5
		move.w	(a4)+,d6
		lsr.w	#4,d6
		move.w	d4,d0
		sub.w	d6,d4
		bcc.s	loc_4EEF8
		move.w	d0,d6
		moveq	#0,d4
		bra.s	loc_4EEF8
; ---------------------------------------------------------------------------

loc_4EF2C:
		subq.w	#1,d5
		beq.s	locret_4EF3A
		move.w	(a6)+,d0
		and.w	(Camera_Y_pos_mask).w,d0
		move.w	d0,(a6)+
		bra.s	loc_4EF2C
; ---------------------------------------------------------------------------

locret_4EF3A:
		rts


; =============== S U B R O U T I N E =======================================


Get_XDeformRange:
		move.w	(a4)+,d2
		move.w	(a6),d0
		bsr.s	sub_4EF46
		addi.w	#$140,d0
; End of function Get_XDeformRange


; =============== S U B R O U T I N E =======================================


sub_4EF46:
		cmp.w	d2,d0
		blo.s	loc_4EF50
		add.w	(a4)+,d2
		addq.w	#4,a5
		bra.s	sub_4EF46
; ---------------------------------------------------------------------------

loc_4EF50:
		move.w	(a5),d1
		swap	d1
		rts
; End of function sub_4EF46


; =============== S U B R O U T I N E =======================================


Draw_PlaneVertBottomUp:
		movem.w	d1-d2,-(sp)
		bsr.s	Draw_PlaneVertSingleBottomUp
		movem.w	(sp)+,d1-d2
		bpl.s	Draw_PlaneVertSingleBottomUp
		rts
; End of function Draw_PlaneVertBottomUp


; =============== S U B R O U T I N E =======================================


Draw_PlaneVertSingleBottomUp:
		and.w	(Camera_Y_pos_mask).w,d2
		move.w	d2,d3
		addi.w	#$F0,d3
		and.w	(Camera_Y_pos_mask).w,d3
		move.w	(Draw_delayed_position).w,d0
		cmp.w	d2,d0
		blo.s	loc_4EF84
		cmp.w	d3,d0
		bhi.s	loc_4EF84
		moveq	#$20,d6
		jsr	Setup_TileRowDraw(pc)

loc_4EF84:
		subi.w	#$10,(Draw_delayed_position).w
		subq.w	#1,(Draw_delayed_rowcount).w
		rts
; End of function Draw_PlaneVertSingleBottomUp


; =============== S U B R O U T I N E =======================================


Draw_PlaneVertTopDown:
		and.w	(Camera_Y_pos_mask).w,d2
		move.w	d2,d3
		addi.w	#$F0,d3
		and.w	(Camera_Y_pos_mask).w,d3
		move.w	(Draw_delayed_position).w,d0
		cmp.w	d2,d0
		blo.s	loc_4EFB0
		cmp.w	d3,d0
		bhi.s	loc_4EFB0
		moveq	#$20,d6
		jsr	Setup_TileRowDraw(pc)

loc_4EFB0:
		addi.w	#$10,(Draw_delayed_position).w
		subq.w	#1,(Draw_delayed_rowcount).w
		rts
; End of function Draw_PlaneVertTopDown


; =============== S U B R O U T I N E =======================================


Draw_PlaneHorzRightToLeft:
		movem.w	d1-d2,-(sp)
		bsr.s	sub_4EFCA
		movem.w	(sp)+,d1-d2
		bpl.s	sub_4EFCA
		rts
; End of function Draw_PlaneHorzRightToLeft


; =============== S U B R O U T I N E =======================================


sub_4EFCA:
		andi.w	#$FFF0,d2
		move.w	d2,d3
		addi.w	#$1F0,d3
		andi.w	#$FFF0,d3
		move.w	(Draw_delayed_position).w,d0
		cmp.w	d2,d0
		blo.s	loc_4EFEA
		cmp.w	d3,d0
		bhi.s	loc_4EFEA
		moveq	#$10,d6
		jsr	Setup_TileColumnDraw(pc)

loc_4EFEA:
		subi.w	#$10,(Draw_delayed_position).w
		subq.w	#1,(Draw_delayed_rowcount).w
		rts
; End of function sub_4EFCA


; =============== S U B R O U T I N E =======================================


Draw_PlaneHorzLeftToRight:
		movem.w	d1-d2,-(sp)
		bsr.s	sub_4F004
		movem.w	(sp)+,d1-d2
		bpl.s	sub_4F004
		rts
; End of function Draw_PlaneHorzLeftToRight


; =============== S U B R O U T I N E =======================================


sub_4F004:
		andi.w	#$FFF0,d2
		move.w	d2,d3
		addi.w	#$1F0,d3
		andi.w	#$FFF0,d3
		move.w	(Draw_delayed_position).w,d0
		cmp.w	d2,d0
		blo.s	loc_4F024
		cmp.w	d3,d0
		bhi.s	loc_4F024
		moveq	#$10,d6
		jsr	Setup_TileColumnDraw(pc)

loc_4F024:
		addi.w	#$10,(Draw_delayed_position).w
		subq.w	#1,(Draw_delayed_rowcount).w
		rts
; End of function sub_4F004


; =============== S U B R O U T I N E =======================================


Draw_PlaneVertBottomUpComplex:
		movem.l	d1/a4-a5,-(sp)
		bsr.s	sub_4F03E
		movem.l	(sp)+,d1/a4-a5
		bpl.s	sub_4F03E
		rts
; End of function Draw_PlaneVertBottomUpComplex


; =============== S U B R O U T I N E =======================================


sub_4F03E:
		and.w	(Camera_Y_pos_mask).w,d1
		move.w	d1,d2
		addi.w	#$F0,d2
		and.w	(Camera_Y_pos_mask).w,d2
		move.w	(Draw_delayed_position).w,d0
		cmp.w	d1,d0
		blo.s	loc_4F066
		cmp.w	d2,d0
		bhi.s	loc_4F066

loc_4F058:
		addq.w	#4,a5
		cmp.w	(a4)+,d0
		bpl.s	loc_4F058
		move.w	(a5),d1
		moveq	#$20,d6
		jsr	Setup_TileRowDraw(pc)

loc_4F066:
		subi.w	#$10,(Draw_delayed_position).w
		subq.w	#1,(Draw_delayed_rowcount).w
		rts
; End of function sub_4F03E


; =============== S U B R O U T I N E =======================================


PlainDeformation:
		lea	(H_scroll_buffer).w,a1
		move.w	(Camera_X_pos_copy).w,d0
		neg.w	d0
		swap	d0
		move.w	(Camera_X_pos_BG_copy).w,d0
		neg.w	d0
		moveq	#$38-1,d1

loc_4F086:
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		dbf	d1,loc_4F086
		rts
; End of function PlainDeformation


; =============== S U B R O U T I N E =======================================


PlainDeformation_Flipped:
		lea	(H_scroll_buffer).w,a1
		move.w	(Camera_X_pos_BG_copy).w,d0
		neg.w	d0
		swap	d0
		move.w	(Camera_X_pos_copy).w,d0
		neg.w	d0
		moveq	#$38-1,d1

loc_4F0A8:
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		dbf	d1,loc_4F0A8
		rts
; End of function PlainDeformation_Flipped


; =============== S U B R O U T I N E =======================================


MakeFGDeformArray:
		move.w	d1,d0
		lsr.w	#1,d0
		bcc.s	loc_4F0C2

loc_4F0BC:
		move.w	(a6)+,d5
		add.w	d6,d5
		move.w	d5,(a1)+

loc_4F0C2:
		move.w	(a6)+,d5
		add.w	d6,d5
		move.w	d5,(a1)+
		dbf	d0,loc_4F0BC
		rts
; End of function MakeFGDeformArray


; =============== S U B R O U T I N E =======================================


ApplyDeformation:
		move.w	#$E0-1,d1

ApplyDeformation3:
		lea	(H_scroll_buffer).w,a1
		move.w	(Camera_Y_pos_BG_copy).w,d0
		move.w	(Camera_X_pos_copy).w,d3

ApplyDeformation2:
		move.w	(a4)+,d2
		smi	d4
		bpl.s	loc_4F0E8
		andi.w	#$7FFF,d2

loc_4F0E8:
		sub.w	d2,d0
		bmi.s	loc_4F0FA
		addq.w	#2,a5
		tst.b	d4
		beq.s	ApplyDeformation2
		subq.w	#2,a5
		add.w	d2,d2
		adda.w	d2,a5
		bra.s	ApplyDeformation2
; ---------------------------------------------------------------------------

loc_4F0FA:
		tst.b	d4
		beq.s	loc_4F104
		add.w	d0,d2
		add.w	d2,d2
		adda.w	d2,a5

loc_4F104:
		neg.w	d0
		move.w	d1,d2
		sub.w	d0,d2
		bcc.s	loc_4F110
		move.w	d1,d0
		addq.w	#1,d0

loc_4F110:
		neg.w	d3
		swap	d3

loc_4F114:
		subq.w	#1,d0

loc_4F116:
		tst.b	d4
		beq.s	loc_4F130
		lsr.w	#1,d0
		bcc.s	loc_4F124

loc_4F11E:
		move.w	(a5)+,d3
		neg.w	d3
		move.l	d3,(a1)+

loc_4F124:
		move.w	(a5)+,d3
		neg.w	d3
		move.l	d3,(a1)+
		dbf	d0,loc_4F11E
		bra.s	loc_4F140
; ---------------------------------------------------------------------------

loc_4F130:
		move.w	(a5)+,d3
		neg.w	d3
		lsr.w	#1,d0
		bcc.s	loc_4F13A

loc_4F138:
		move.l	d3,(a1)+

loc_4F13A:
		move.l	d3,(a1)+
		dbf	d0,loc_4F138

loc_4F140:
		tst.w	d2
		bmi.s	locret_4F158
		move.w	(a4)+,d0
		smi	d4
		bpl.s	loc_4F14E
		andi.w	#$7FFF,d0

loc_4F14E:
		move.w	d2,d3
		sub.w	d0,d2
		bpl.s	loc_4F114
		move.w	d3,d0
		bra.s	loc_4F116
; ---------------------------------------------------------------------------

locret_4F158:
		rts
; End of function ApplyDeformation


; =============== S U B R O U T I N E =======================================


ApplyFGDeformation:
		move.w	#$DF,d1
		lea	(H_scroll_buffer).w,a1
		move.w	(Camera_Y_pos_copy).w,d0
		move.w	(Camera_X_pos_BG_copy).w,d3

ApplyFGDeformation2:
		move.w	(a4)+,d2
		smi	d4
		bpl.s	loc_4F174
		andi.w	#$7FFF,d2

loc_4F174:
		sub.w	d2,d0
		bmi.s	loc_4F186
		addq.w	#2,a5
		tst.b	d4
		beq.s	ApplyFGDeformation2
		subq.w	#2,a5
		add.w	d2,d2
		adda.w	d2,a5
		bra.s	ApplyFGDeformation2
; ---------------------------------------------------------------------------

loc_4F186:
		tst.b	d4
		beq.s	loc_4F190
		add.w	d0,d2
		add.w	d2,d2
		adda.w	d2,a5

loc_4F190:
		neg.w	d0
		move.w	d1,d2
		sub.w	d0,d2
		bcc.s	loc_4F19C
		move.w	d1,d0
		addq.w	#1,d0

loc_4F19C:
		neg.w	d3

loc_4F19E:
		subq.w	#1,d0

loc_4F1A0:
		tst.b	d4
		beq.s	loc_4F1C2
		lsr.w	#1,d0
		bcc.s	loc_4F1B2

loc_4F1A8:
		swap	d3
		move.w	(a5)+,d3
		neg.w	d3
		swap	d3
		move.l	d3,(a1)+

loc_4F1B2:
		swap	d3
		move.w	(a5)+,d3
		neg.w	d3
		swap	d3
		move.l	d3,(a1)+
		dbf	d0,loc_4F1A8
		bra.s	loc_4F1D6
; ---------------------------------------------------------------------------

loc_4F1C2:
		swap	d3
		move.w	(a5)+,d3
		neg.w	d3
		swap	d3
		lsr.w	#1,d0
		bcc.s	loc_4F1D0

loc_4F1CE:
		move.l	d3,(a1)+

loc_4F1D0:
		move.l	d3,(a1)+
		dbf	d0,loc_4F1CE

loc_4F1D6:
		tst.w	d2
		bmi.s	locret_4F1EE
		move.w	(a4)+,d0
		smi	d4
		bpl.s	loc_4F1E4
		andi.w	#$7FFF,d0

loc_4F1E4:
		move.w	d2,d1
		sub.w	d0,d2
		bpl.s	loc_4F19E
		move.w	d1,d0
		bra.s	loc_4F1A0
; ---------------------------------------------------------------------------

locret_4F1EE:
		rts
; End of function ApplyFGDeformation

; ---------------------------------------------------------------------------

ApplyFGandBGDeformation:
		swap	d7
		swap	d3

loc_4F1F4:
		move.w	(a4)+,d3
		smi	d7
		bpl.s	loc_4F1FE
		andi.w	#$7FFF,d3

loc_4F1FE:
		sub.w	d3,d0
		bmi.s	loc_4F210
		addq.w	#2,a5
		tst.b	d7
		beq.s	loc_4F1F4
		subq.w	#2,a5
		add.w	d3,d3
		adda.w	d3,a5
		bra.s	loc_4F1F4
; ---------------------------------------------------------------------------

loc_4F210:
		tst.b	d7
		beq.s	loc_4F21A
		add.w	d0,d3
		add.w	d3,d3
		adda.w	d3,a5

loc_4F21A:
		swap	d3
		neg.w	d0
		move.w	d1,d4
		sub.w	d0,d4
		bcc.s	loc_4F228
		move.w	d1,d0
		addq.w	#1,d0

loc_4F228:
		subq.w	#1,d0

loc_4F22A:
		tst.b	d7
		beq.s	loc_4F250
		lsr.w	#1,d0
		bcc.s	loc_4F23E

loc_4F232:
		move.w	(a2)+,d6
		swap	d6
		move.w	(a5)+,d6
		neg.w	d6
		add.w	(a6)+,d6
		move.l	d6,(a1)+

loc_4F23E:
		move.w	(a2)+,d6
		swap	d6
		move.w	(a5)+,d6
		neg.w	d6
		add.w	(a6)+,d6
		move.l	d6,(a1)+
		dbf	d0,loc_4F232
		bra.s	loc_4F270
; ---------------------------------------------------------------------------

loc_4F250:
		move.w	(a5)+,d5
		neg.w	d5
		lsr.w	#1,d0
		bcc.s	loc_4F262

loc_4F258:
		move.w	(a2)+,d6
		swap	d6
		move.w	(a6)+,d6
		add.w	d5,d6
		move.l	d6,(a1)+

loc_4F262:
		move.w	(a2)+,d6
		swap	d6
		move.w	(a6)+,d6
		add.w	d5,d6
		move.l	d6,(a1)+
		dbf	d0,loc_4F258

loc_4F270:
		tst.w	d4
		bmi.s	loc_4F288
		move.w	(a4)+,d0
		smi	d7
		bpl.s	loc_4F27E
		andi.w	#$7FFF,d0

loc_4F27E:
		move.w	d4,d5
		sub.w	d0,d4
		bpl.s	loc_4F228
		move.w	d5,d0
		bra.s	loc_4F22A
; ---------------------------------------------------------------------------

loc_4F288:
		swap	d7
		rts

; =============== S U B R O U T I N E =======================================


Apply_FGVScroll:
		lea	(Vscroll_buffer).w,a1
		move.w	(Camera_Y_pos_BG_copy).w,d1
		move.w	(Camera_X_pos_copy).w,d0
		move.w	d0,d2
		andi.w	#$F,d2
		beq.s	loc_4F2A4
		addi.w	#$10,d0

loc_4F2A4:
		lsr.w	#4,d0

loc_4F2A6:
		addq.w	#2,a5
		move.w	(a4)+,d2
		lsr.w	#4,d2
		sub.w	d2,d0
		bpl.s	loc_4F2A6
		neg.w	d0
		moveq	#$13,d2
		sub.w	d0,d2
		bcc.s	loc_4F2BA
		moveq	#$14,d0

loc_4F2BA:
		subq.w	#1,d0

loc_4F2BC:
		move.w	(a5)+,d3

loc_4F2BE:
		move.w	d3,(a1)+
		move.w	d1,(a1)+
		dbf	d0,loc_4F2BE
		tst.w	d2
		bmi.s	locret_4F2D8
		move.w	(a4)+,d0
		lsr.w	#4,d0
		move.w	d2,d3
		sub.w	d0,d2
		bpl.s	loc_4F2BA
		move.w	d3,d0
		bra.s	loc_4F2BC
; ---------------------------------------------------------------------------

locret_4F2D8:
		rts
; End of function Apply_FGVScroll


; =============== S U B R O U T I N E =======================================


Reset_TileOffsetPositionActual:
		move.w	(Camera_X_pos_copy).w,d0
		move.w	d0,d1
		andi.w	#$FFF0,d0
		move.w	d0,(Camera_X_pos_rounded).w
		move.w	(Camera_Y_pos_copy).w,d0
		and.w	(Camera_Y_pos_mask).w,d0
		move.w	d0,(Camera_Y_pos_rounded).w
		rts
; End of function Reset_TileOffsetPositionActual


; =============== S U B R O U T I N E =======================================


Reset_TileOffsetPositionEff:
		move.w	(Camera_X_pos_BG_copy).w,d0
		move.w	d0,d1
		andi.w	#$FFF0,d0
		move.w	d0,d2
		move.w	d0,(Camera_X_pos_BG_rounded).w
		move.w	(Camera_Y_pos_BG_copy).w,d0
		and.w	(Camera_Y_pos_mask).w,d0
		move.w	d0,(Camera_Y_pos_BG_rounded).w
		rts
; End of function Reset_TileOffsetPositionEff


;-------------------------------------------------------------------------------


Refresh_PlaneFull:
		moveq	#$10-1,d2

.loop:
		movem.l	d0-d2/a0,-(sp)
		moveq	#$20,d6
		jsr	Setup_TileRowDraw(pc)
		jsr	VInt_DrawLevel(pc)
		movem.l	(sp)+,d0-d2/a0
		addi.w	#$10,d0
		dbf	d2,.loop
		rts
; End of function Refresh_PlaneFull

; =============== S U B R O U T I N E =======================================


SpecialVInt_Function:
		lea	(VDP_data_port).l,a6
		move.w	(Special_V_int_routine).w,d0
		jmp	SpecialVInt_Array(pc,d0.w)
; End of function SpecialVInt_Function

; ---------------------------------------------------------------------------

SpecialVInt_Array:
		rts					; $00
		nop
; ---------------------------------------------------------------------------
		bra.w	SpecialVInt_VScrollOn		; $04
; ---------------------------------------------------------------------------
		bra.w	SpecialVInt_VScrollCopy		; $08
; ---------------------------------------------------------------------------
		bra.w	SpecialVInt_VScrollOff		; $0C
; ---------------------------------------------------------------------------
		bra.w	SpecialVInt_LBZ2WindowCopy	; $10
; ---------------------------------------------------------------------------
		bra.w	SpecialVInt_LBZ2ScrollAClear	; $14
; ---------------------------------------------------------------------------
		bra.w	SpecialVInt_LBZ2ScrollAClear2	; $18
; ---------------------------------------------------------------------------
		bra.w	SpecialVInt_LBZ2WindowClear	; $1C
; ---------------------------------------------------------------------------

SpecialVInt_VScrollOn:
		move.w	#$8B07,VDP_control_port-VDP_data_port(a6)		; Command $8B07 - VScroll cell-based, HScroll line-based
		addq.w	#4,(Special_V_int_routine).w

SpecialVInt_VScrollCopy:
		lea	(Vscroll_buffer).w,a0
		move.l	#vdpComm($0000,VSRAM,WRITE),VDP_control_port-VDP_data_port(a6)
		moveq	#$14-1,d0

.loop:
		move.l	(a0)+,(a6)
		dbf	d0,.loop
		rts
; ---------------------------------------------------------------------------

SpecialVInt_VScrollOff:
		move.w	#$8B03,VDP_control_port-VDP_data_port(a6)		; Command $8B03 - VScroll full, HScroll line-based
		clr.w	(Special_V_int_routine).w
		rts
; ---------------------------------------------------------------------------

SpecialVInt_LBZ2WindowCopy:
		lea	(VRAM_buffer).w,a0		; Used specifically by the Death Egg platform at the end of LBZ2
		move.w	(Draw_delayed_rowcount).w,d0
		addi.w	#$D,d0
		andi.w	#$1F,d0
		lsl.w	#7,d0
		addi.w	#VRAM_Plane_A_Name_Table,d0
		move.w	d0,d2
		addi.w	#$64,d0
		moveq	#7-1,d1
		jsr	SpecialVInt_VRAMRead(pc)	; Grabs the nametable area of the Death Egg platform
		move.w	d2,d0
		moveq	#$19-1,d1
		jsr	SpecialVInt_VRAMRead(pc)
		lea	(VRAM_buffer).w,a0
		move.w	(Draw_delayed_rowcount).w,d0
		lsl.w	#7,d0
		addi.w	#$8000,d0
		moveq	#$20-1,d1
		jsr	VInt_VRAMWrite(pc)			; Copies the pertinent data from scroll A to the window nametable
		subq.w	#1,(Draw_delayed_rowcount).w		; Do this (EECA) number of times
		bpl.s	.return
		addq.w	#4,(Special_V_int_routine).w

.return:
		rts
; ---------------------------------------------------------------------------

SpecialVInt_LBZ2ScrollAClear:
		move.l	#vdpComm(VRAM_Plane_A_Name_Table+$900,VRAM,WRITE),(VDP_control_port).l	; VRAM base $C900
		moveq	#0,d0
		moveq	#$60-1,d1

.loop:
		move.l	d0,(a6)				; Clear 6 cell lines from VRAM A for when it scrolls upward
		move.l	d0,(a6)
		dbf	d1,.loop
		move.w	#$8320,VDP_control_port-VDP_data_port(a6)		; VRAM command $8320 - Window at base address $8000
		move.w	#$9285,VDP_control_port-VDP_data_port(a6)		; VRAM command $9285 - Window starts 5 cells down from top
		clr.w	(Special_V_int_routine).w
		rts
; ---------------------------------------------------------------------------

SpecialVInt_LBZ2ScrollAClear2:
		move.l	#vdpComm(VRAM_Plane_A_Name_Table+$600,VRAM,WRITE),(VDP_control_port).l	; VRAM base $C600
		moveq	#0,d0
		moveq	#$60-1,d1

.loop:
		move.l	d0,(a6)					; Erase remainder of upper area of VRAM A
		move.l	d0,(a6)
		dbf	d1,.loop
		addq.w	#4,(Special_V_int_routine).w
		rts
; ---------------------------------------------------------------------------

SpecialVInt_LBZ2WindowClear:
		lea	(VRAM_buffer).w,a0
		move.w	#$829C,d0
		moveq	#$19-1,d1
		jsr	SpecialVInt_VRAMRead(pc)
		move.w	#$8280,d0
		moveq	#7-1,d1
		jsr	SpecialVInt_VRAMRead(pc)	; Copy from window data. Luckily, all 6 cell lines are identical so it only needs to be done once
		move.l	#vdpComm(VRAM_Plane_A_Name_Table+$900,VRAM,WRITE),(VDP_control_port).l	; VRAM position $C900
		moveq	#6-1,d0

loc_4E90C:
		lea	(VRAM_buffer).w,a0
		moveq	#$10-1,d1

loc_4E912:
		move.l	(a0)+,(a6)
		move.l	(a0)+,(a6)				; Write cell lines back to Scroll A
		dbf	d1,loc_4E912
		dbf	d0,loc_4E90C
		move.w	#$9200,VDP_control_port-VDP_data_port(a6)			; VRAM command $9200 - Zero out window position
		clr.w	(Special_V_int_routine).w
		rts

; =============== S U B R O U T I N E =======================================


Draw_TileColumn:
		move.w	(a6),d0
		andi.w	#$FFF0,d0
		move.w	(a5),d2
		move.w	d0,(a5)
		move.w	d2,d3
		sub.w	d0,d2
		beq.w	locret_4EAB6
		tst.b	d2
		bpl.s	loc_4E948
		neg.w	d2
		move.w	d3,d0
		addi.w	#$150,d0

loc_4E948:
		andi.w	#$30,d2
		cmpi.w	#$10,d2
		sne	(Plane_double_update_flag).w
		movem.w	d1/d6,-(sp)
		bsr.s	Setup_TileColumnDraw
		movem.w	(sp)+,d1/d6
		tst.b	(Plane_double_update_flag).w
		beq.w	locret_4EAB6
		addi.w	#$10,d0
		bra.s	Setup_TileColumnDraw
; End of function Draw_TileColumn


; =============== S U B R O U T I N E =======================================


Draw_TileColumn2:
		move.w	(a6),d0
		andi.w	#$FFF0,d0
		move.w	(a5),d2
		move.w	d0,(a5)
		move.w	d2,d3
		sub.w	d0,d2
		beq.w	locret_4EAB6
		tst.b	d2
		bpl.s	loc_4E98C
		neg.w	d2
		move.w	d3,d0
		addi.w	#$150,d0
		swap	d1

loc_4E98C:
		andi.w	#$30,d2
		cmpi.w	#$10,d2
		sne	(Plane_double_update_flag).w
		movem.w	d1/d6,-(sp)
		bsr.s	Setup_TileColumnDraw
		movem.w	(sp)+,d1/d6
		tst.b	(Plane_double_update_flag).w
		beq.w	locret_4EAB6
		addi.w	#$10,d0
; End of function Draw_TileColumn2


; =============== S U B R O U T I N E =======================================


Setup_TileColumnDraw:
		move.w	d1,d2
		andi.w	#$70,d2
		move.w	d1,d3
		lsl.w	#4,d3
		andi.w	#$F00,d3
		asr.w	#4,d1
		move.w	d1,d4
		asr.w	#1,d1
		and.w	(Layout_row_index_mask).w,d1
		andi.w	#$F,d4
		moveq	#$10,d5
		sub.w	d4,d5
		move.w	d5,d4
		sub.w	d6,d5
		bmi.s	loc_4E9FC
		move.w	d0,d5
		asr.w	#2,d5
		andi.w	#$7C,d5
		add.w	d7,d5
		add.w	d3,d5
		move.w	d5,(a0)+
		move.w	d6,d5
		subq.w	#1,d6
		move.w	d6,(a0)+
		bset	#7,-2(a0)
		lea	(a0),a1
		add.w	d5,d5
		add.w	d5,d5
		adda.w	d5,a0
		jsr	Get_LevelChunkColumn(pc)
		bra.s	sub_4EA4A
; ---------------------------------------------------------------------------

loc_4E9FC:
		neg.w	d5
		move.w	d5,-(sp)
		move.w	d0,d5
		asr.w	#2,d5
		andi.w	#$7C,d5
		add.w	d7,d5
		add.w	d3,d5
		move.w	d5,(a0)+
		move.w	d4,d6
		subq.w	#1,d6
		move.w	d6,(a0)+
		bset	#7,-2(a0)
		lea	(a0),a1
		add.w	d4,d4
		add.w	d4,d4
		adda.w	d4,a0
		jsr	Get_LevelChunkColumn(pc)
		bsr.s	sub_4EA4A
		move.w	(sp)+,d6
		move.w	d0,d5
		asr.w	#2,d5
		andi.w	#$7C,d5
		add.w	d7,d5
		move.w	d5,(a0)+
		move.w	d6,d5
		subq.w	#1,d6
		move.w	d6,(a0)+
		bset	#7,-2(a0)
		lea	(a0),a1
		add.w	d5,d5
		add.w	d5,d5
		adda.w	d5,a0

sub_4EA4A:
		swap	d7

loc_4EA4C:
		move.w	(a5,d2.w),d3
		move.w	d3,d4
		andi.w	#$3FF,d3
		lsl.w	#3,d3
		move.w	(a2,d3.w),d5
		swap	d5
		move.w	4(a2,d3.w),d5
		move.w	6(a2,d3.w),d7
		move.w	2(a2,d3.w),d3
		swap	d3
		move.w	d7,d3
		btst	#$B,d4
		beq.s	loc_4EA84
		eori.l	#$10001000,d5
		eori.l	#$10001000,d3
		swap	d5
		swap	d3

loc_4EA84:
		btst	#$A,d4
		beq.s	loc_4EA98
		eori.l	#$8000800,d5
		eori.l	#$8000800,d3
		exg	d3,d5

loc_4EA98:
		move.l	d5,(a1)+
		move.l	d3,(a0)+
		addi.w	#$10,d2
		andi.w	#$70,d2
		bne.s	loc_4EAAE
		addq.w	#4,d1
		and.w	(Layout_row_index_mask).w,d1
		bsr.s	Get_LevelChunkColumn

loc_4EAAE:
		dbf	d6,loc_4EA4C
		swap	d7
		clr.w	(a0)

locret_4EAB6:
		rts
; End of function Setup_TileColumnDraw


; =============== S U B R O U T I N E =======================================


Get_LevelChunkColumn:
		movea.w	(a3,d1.w),a4
		move.w	d0,d3
		asr.w	#7,d3
		adda.w	d3,a4
		moveq	#-1,d3
		clr.w	d3
		move.b	(a4),d3
		lsl.w	#7,d3
		move.w	d0,d4
		asr.w	#3,d4
		andi.w	#$E,d4
		add.w	d4,d3
		movea.l	d3,a5
		rts
; End of function Get_LevelChunkColumn


; =============== S U B R O U T I N E =======================================


Draw_TileRow:
		move.w	(a6),d0
		and.w	(Camera_Y_pos_mask).w,d0
		move.w	(a5),d2
		move.w	d0,(a5)
		move.w	d2,d3
		sub.w	d0,d2
		beq.w	locret_4EC46
		tst.b	d2
		bpl.s	loc_4EAFA
		neg.w	d2
		move.w	d3,d0
		addi.w	#$F0,d0
		and.w	(Camera_Y_pos_mask).w,d0

loc_4EAFA:
		andi.w	#$30,d2
		cmpi.w	#$10,d2
		sne.b	(Plane_double_update_flag).w
		movem.w	d1/d6,-(sp)
		bsr.s	Setup_TileRowDraw
		movem.w	(sp)+,d1/d6
		tst.b	(Plane_double_update_flag).w
		beq.w	locret_4EC46
		addi.w	#$10,d0
		and.w	(Camera_Y_pos_mask).w,d0
		bra.s	Setup_TileRowDraw
; End of function Draw_TileRow


; =============== S U B R O U T I N E =======================================


Draw_TileRow2:
		move.w	(a6),d0
		and.w	(Camera_Y_pos_mask).w,d0
		move.w	(a5),d2
		move.w	d0,(a5)
		move.w	d2,d3
		sub.w	d0,d2
		beq.w	locret_4EC46
		tst.b	d2
		bpl.s	loc_4EB46
		neg.w	d2
		move.w	d3,d0
		addi.w	#$F0,d0
		and.w	(Camera_Y_pos_mask).w,d0
		swap	d1

loc_4EB46:
		andi.w	#$30,d2
		cmpi.w	#$10,d2
		sne	(Plane_double_update_flag).w
		movem.w	d1/d6,-(sp)
		bsr.s	Setup_TileRowDraw
		movem.w	(sp)+,d1/d6
		tst.b	(Plane_double_update_flag).w
		beq.w	locret_4EC46
		addi.w	#$10,d0
		and.w	(Camera_Y_pos_mask).w,d0
; End of function Draw_TileRow2


; =============== S U B R O U T I N E =======================================


Setup_TileRowDraw:
		asr.w	#4,d1
		move.w	d1,d2
		move.w	d1,d4
		asr.w	#3,d1
		add.w	d2,d2
		move.w	d2,d3
		andi.w	#$E,d2
		add.w	d3,d3
		andi.w	#$7C,d3
		andi.w	#$1F,d4
		moveq	#$20,d5
		sub.w	d4,d5
		move.w	d5,d4
		sub.w	d6,d5
		bmi.s	loc_4EBB2
		move.w	d0,d5
		andi.w	#$F0,d5		; If the length of the write can fit without wrapping the nametable
		lsl.w	#4,d5
		add.w	d7,d5
		add.w	d3,d5
		move.w	d5,(a0)+
		move.w	d6,d5
		subq.w	#1,d6
		move.w	d6,(a0)+
		lea	(a0),a1
		add.w	d5,d5
		add.w	d5,d5
		adda.w	d5,a0
		jsr	Get_LevelAddrChunkRow(pc)
		bra.s	loc_4EBF2
; ---------------------------------------------------------------------------

loc_4EBB2:
		neg.w	d5			; If the length of the write wraps over the length of the nametable
		move.w	d5,-(sp)
		move.w	d0,d5
		andi.w	#$F0,d5
		lsl.w	#4,d5
		add.w	d7,d5
		add.w	d3,d5
		move.w	d5,(a0)+
		move.w	d4,d6
		subq.w	#1,d6
		move.w	d6,(a0)+
		lea	(a0),a1
		add.w	d4,d4
		add.w	d4,d4
		adda.w	d4,a0
		bsr.s	Get_LevelAddrChunkRow
		bsr.s	loc_4EBF2
		move.w	(sp)+,d6	; Must place one more write command to account for rollover
		move.w	d0,d5
		andi.w	#$F0,d5
		lsl.w	#4,d5
		add.w	d7,d5
		move.w	d5,(a0)+
		move.w	d6,d5
		subq.w	#1,d6
		move.w	d6,(a0)+
		lea	(a0),a1
		add.w	d5,d5
		add.w	d5,d5
		adda.w	d5,a0

loc_4EBF2:
		move.w	(a5,d2.w),d3
		move.w	d3,d4
		andi.w	#$3FF,d3
		lsl.w	#3,d3
		move.l	(a2,d3.w),d5
		move.l	4(a2,d3.w),d3
		btst	#$B,d4
		beq.s	loc_4EC1A
		eori.l	#$10001000,d5
		eori.l	#$10001000,d3
		exg	d3,d5

loc_4EC1A:
		btst	#$A,d4
		beq.s	loc_4EC30
		eori.l	#$8000800,d5
		eori.l	#$8000800,d3
		swap	d5
		swap	d3

loc_4EC30:
		move.l	d5,(a1)+
		move.l	d3,(a0)+
		addq.w	#2,d2
		andi.w	#$E,d2
		bne.s	loc_4EC40
		addq.w	#1,d1
		bsr.s	Get_ChunkRow

loc_4EC40:
		dbf	d6,loc_4EBF2
		clr.w	(a0)

locret_4EC46:
		rts
; End of function Setup_TileRowDraw

; =============== S U B R O U T I N E =======================================


Get_LevelAddrChunkRow:
		move.w	d0,d3
		asr.w	#5,d3
		and.w	(Layout_row_index_mask).w,d3
		movea.w	(a3,d3.w),a4

Get_ChunkRow:
		moveq	#-1,d3
		clr.w	d3
		move.b	(a4,d1.w),d3
		lsl.w	#7,d3
		move.w	d0,d4
		andi.w	#$70,d4
		add.w	d4,d3
		movea.l	d3,a5
		rts
; End of function Get_LevelAddrChunkRow

; =============== S U B R O U T I N E =======================================


VInt_DrawLevel:
		lea	(VDP_data_port).l,a6
		lea	(Plane_buffer).w,a0
		bsr.s	VInt_DrawLevel_2
		move.l	(Plane_buffer_2_addr).w,d0
		beq.s	VInt_DrawLevel_Return
		movea.l	d0,a0
; End of function VInt_DrawLevel


; =============== S U B R O U T I N E =======================================


VInt_DrawLevel_2:
		move.w	(a0),d0
		beq.s	VInt_DrawLevel_Done
		clr.w	(a0)+
		move.w	(a0)+,d1
		bmi.s	VInt_DrawLevel_Col
		move.w	#$8F02,d2		; VRAM increment at 2 bytes (horizontal level write)
		move.w	#$80,d3
		bra.s	VInt_DrawLevel_Draw
; ---------------------------------------------------------------------------

VInt_DrawLevel_Col:
		move.w	#$8F80,d2		; VRAM increment at $80 bytes (vertical level write)
		moveq	#2,d3
		andi.w	#$7FFF,d1

VInt_DrawLevel_Draw:
		move.w	d2,VDP_control_port-VDP_data_port(a6)
		move.w	d0,d2
		move.w	d1,d4
		bsr.s	VInt_VRAMWrite
		move.w	d2,d0
		add.w	d3,d0
		move.w	d4,d1
		bsr.s	VInt_VRAMWrite
		bra.s	VInt_DrawLevel_2
; ---------------------------------------------------------------------------

VInt_DrawLevel_Done:
		move.w	#$8F02,VDP_control_port-VDP_data_port(a6)

VInt_DrawLevel_Return:
		rts
; End of function VInt_DrawLevel_2


; =============== S U B R O U T I N E =======================================


VInt_VRAMWrite:
		swap	d0
		clr.w	d0
		swap	d0
		lsl.l	#2,d0
		lsr.w	#2,d0
		ori.w	#$4000,d0
		swap	d0
		move.l	d0,VDP_control_port-VDP_data_port(a6)

.loop:
		move.l	(a0)+,(a6)
		dbf	d1,.loop
		rts
; End of function VInt_VRAMWrite


; =============== S U B R O U T I N E =======================================


SpecialVInt_VRAMRead:
		swap	d0
		clr.w	d0
		swap	d0
		lsl.l	#2,d0
		lsr.w	#2,d0
		swap	d0
		move.l	d0,VDP_control_port-VDP_data_port(a6)

.loop:
		move.l	(a6),(a0)+
		dbf	d1,.loop
		rts
; End of function SpecialVInt_VRAMRead

