; ---------------------------------------------------------------------------
; Object 14 - Blank
; ---------------------------------------------------------------------------

Obj14:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj14_Index(pc,d0.w),d1
		jmp	Obj14_Index(pc,d1.w)
; ===========================================================================
Obj14_Index:	dc.w Obj14_Init-Obj14_Index
		dc.w Obj14_Delete-Obj14_Index
; ===========================================================================

Obj14_Init:
		addq.b	#2,obRoutine(a0)
		rts

Obj14_Delete:
		bra.w	DeleteObject

; =============== S U B R O U T I N E =======================================

ObjHVPlatform:
; 		moveq	#0,d0
; 		move.b	obRoutine(a0),d0
; 		move.w	AxisPlat_Index(pc,d0.w),d0
; 		jsr	AxisPlat_Index(pc,d0.w)
; 		lea	(v_player).w,a1
; 		jsr	(SolidObject).l
; 		jsr	(DrawObject).l
; 		move.w	axis_origin_x(a0),d0
; 		jmp	(CheckObjDespawn2).l
; ; End of function ObjHVPlatform
; 
; ; ---------------------------------------------------------------------------
; AxisPlat_Index:
; 		dc.w AxisPlat_Init-AxisPlat_Index
; 		dc.w AxisPlat_Main-AxisPlat_Index
; ; ---------------------------------------------------------------------------
; axis_origin_y	= obj.oVar32
; axis_origin_x	= obj.oVar36
; axis_timer	= obj.oVar3A
; axis_state	= obj.oVar3C
; 
; ; =============== S U B R O U T I N E =======================================
; 
; 
; AxisPlat_Init:
; 		addq.b	#2,obRoutine(a0)
; 		move.l	#Spr_20C376,obj.oSprites(a0)
; 		move.w	#$41B,obj.oTile(a0)
; 		ori.b	#4,obj.oSprFlags(a0)
; 		move.b	#3,obj.oPriority(a0)
; 		move.w	obj.oX(a0),axis_origin_x(a0)
; 		move.w	obj.oY(a0),axis_origin_y(a0)
; 		; fall through
; ; ---------------------------------------------------------------------------
; 
; AxisPlat_Main:
; 		tst.b	axis_timer(a0)
; 		bne.s	Axis_UpdateTimer
; 		moveq	#0,d0
; 		move.b	axis_state(a0),d0
; 		add.b	d0,d0
; 		add.b	d0,d0
; 		lea	HVPlat_StateTable(pc,d0.w),a2
; 		move.b	(a2)+,obj.oSprFrame(a0)
; 		move.b	(a2)+,axis_timer(a0)
; 		move.b	(a2)+,obj.oWidth(a0)
; 		move.b	(a2)+,obj.oYRadius(a0)
; 		clr.w	obj.oYVel(a0)
; 		tst.b	obj.oSprFrame(a0)
; 		bne.s	.return
; 		move.w	#$100,obj.oYVel(a0)
; .return:	rts
; ; ---------------------------------------------------------------------------
; 
; Axis_UpdateTimer:
; 		subq.b	#1,axis_timer(a0)
; 		bne.s	.update_motion
; 		addq.b	#1,axis_state(a0)
; 		cmpi.b	#$C,axis_state(a0)
; 		bcs.s	.update_motion
; 		clr.b	axis_state(a0)
; 
; .update_motion:
; 		clr.w	obj.oYVel(a0)
; 		tst.b	obj.oSprFrame(a0)
; 		bne.s	.return
; 		move.w	#$100,obj.oYVel(a0)
; .return:	rts
; ---------------------------------------------------------------------------
; HV Platform state script
; 0-6: contract / rotate into horizontal form
; 7-11: expand back
; ---------------------------------------------------------------------------

HVPlat_StateTable:
	dc.b   0, $78,   8, $38
	dc.b   1, 4,     8, $28
	dc.b   2, 4,     8, $18
	dc.b   3, $20,   8, 8
	dc.b   4, 4,   $18, 8
	dc.b   5, 4,   $28, 8
	dc.b   6, $78, $38, 8
	dc.b   5, 4,   $28, 8
	dc.b   4, 4,   $18, 8
	dc.b   3, $20, 8,   8
	dc.b   2, 4,   $18, 8
	dc.b   1, 4,   $28, 8
Spr_20C376:
	dc.w .Spr_20C376_0-Spr_20C376
	dc.w .Spr_20C376_1-Spr_20C376
	dc.w .Spr_20C376_2-Spr_20C376
	dc.w .Spr_20C376_3-Spr_20C376
	dc.w .Spr_20C376_4-Spr_20C376
	dc.w .Spr_20C376_5-Spr_20C376
	dc.w .Spr_20C376_6-Spr_20C376
.Spr_20C376_0:
	dc.b 7
	dc.b $C8, 5, 0, 4, $F8
	dc.b $D8, 5, 0, 4, $F8
	dc.b $E8, 5, 0, 4, $F8
	dc.b $F8, 5, 0, 0, $F8
	dc.b 8, 5, 0, 4, $F8
	dc.b $18, 5, 0, 4, $F8
	dc.b $28, 5, 0, 4, $F8
.Spr_20C376_1:
	dc.b 5
	dc.b $D8, 5, 0, 4, $F8
	dc.b $E8, 5, 0, 4, $F8
	dc.b $F8, 5, 0, 0, $F8
	dc.b 8, 5, 0, 4, $F8
	dc.b $18, 5, 0, 4, $F8
.Spr_20C376_2:
	dc.b 3
	dc.b $E8, 5, 0, 4, $F8
	dc.b $F8, 5, 0, 0, $F8
	dc.b 8, 5, 0, 4, $F8
.Spr_20C376_3:
	dc.b 1
	dc.b $F8, 5, 0, 0, $F8
.Spr_20C376_4:
	dc.b 3
	dc.b $F8, 5, 0, 4, $E8
	dc.b $F8, 5, 0, 0, $F8
	dc.b $F8, 5, 0, 4, 8
.Spr_20C376_5:
	dc.b 5
	dc.b $F8, 5, 0, 4, $D8
	dc.b $F8, 5, 0, 4, $E8
	dc.b $F8, 5, 0, 0, $F8
	dc.b $F8, 5, 0, 4, 8
	dc.b $F8, 5, 0, 4, $18
.Spr_20C376_6:
	dc.b 7
	dc.b $F8, 5, 0, 4, $C8
	dc.b $F8, 5, 0, 4, $D8
	dc.b $F8, 5, 0, 4, $E8
	dc.b $F8, 5, 0, 0, $F8
	dc.b $F8, 5, 0, 4, 8
	dc.b $F8, 5, 0, 4, $18
	dc.b $F8, 5, 0, 4, $28