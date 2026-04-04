;--------------------------------------------------------------------------------
; Object 16 - the HTZ platform that goes down diagonally
; and stops after a while (in the final, it falls)
;--------------------------------------------------------------------------------

Obj16:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj16_Index(pc,d0.w),d1
		jmp	Obj16_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj16_Index:	dc.w Obj16_Init-Obj16_Index
		dc.w Obj16_Main-Obj16_Index
; ---------------------------------------------------------------------------

Obj16_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj16,obMap(a0)
		move.w	#make_art_tile(ArtTile_HtzZipline,2,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$20,obActWid(a0)
		clr.b	obFrame(a0)
		move.w	#$80,obPriority(a0)
	;	move.w	obX(a0),objoff_30(a0)
	;	move.w	obY(a0),objoff_32(a0)
		move.b	#$40,obHeight(a0)
		bset	#4,obRender(a0)
		moveq	#0,d0
		move.b	obSubtype(a0),d0	; subtype determines how far we descend
		lsl.w	#3,d0
		move.w	d0,objoff_34(a0)

Obj16_Main:
		move.w	obX(a0),-(sp)
		bsr.w	HTZLift_RunSecondaryRoutine
		moveq	#0,d1
		move.b	obActWid(a0),d1
		move.w	#-$28,d3
		move.w	(sp)+,d4
		bsr.w	PlatformObject
		bra.w	MarkObjGone

; =============== S U B R O U T I N E =======================================


HTZLift_RunSecondaryRoutine:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Obj16_SubIndex(pc,d0.w),d1
		jmp	Obj16_SubIndex(pc,d1.w)
; End of function HTZLift_RunSecondaryRoutine

; ---------------------------------------------------------------------------
Obj16_SubIndex:	dc.w Obj16_Wait-Obj16_SubIndex
		dc.w Obj16_Slide-Obj16_SubIndex
		dc.w Obj16_Fall-Obj16_SubIndex
		dc.w Obj16_NoMove-Obj16_SubIndex	; Stops rather than collapse; TODO
; ---------------------------------------------------------------------------

Obj16_Wait:
		move.b	obStatus(a0),d0	; get the status flags
		andi.b	#$18,d0		; is one of the players standing on it? (standing mask, to be added to s2.constants.asm)
		beq.s	.return		; if not, branch
		addq.b	#2,ob2ndRout(a0)
		move.w	#$200,obVelX(a0)
		btst	#0,obStatus(a0)	; is the object flipped horizontally?
		beq.s	.facingright	; if not, branch
		neg.w	obVelX(a0)	; negate; we're going the other way
.facingright:
		move.w	#$100,obVelY(a0)
.return:	rts
; ---------------------------------------------------------------------------

Obj16_Slide:	; this comes from S2 final; since the sound is yet to be added,
	;	move.w	(Level_frame_counter).w,d0	; so is this subroutine snippet
	;	andi.w	#$F,d0	; play the sound only every 16 frames
	;	bne.s	+
	;	move.w	#SndID_HTZLiftClick,d0
	;	jsr	(PlaySound).l
;+
		bsr.w	ObjectMove
		subq.w	#1,objoff_34(a0)
		bne.s	.return
		addq.b	#2,ob2ndRout(a0)
	;	move.b	#2,obFrame(a0)	; doesn't exists yet, so we'll keep using frame 0 for now
		clr.l	obVelX(a0)	; clearing X and Y velocity will become relevant for the falling variant of this object
		; this object will eventually gain a 4th secondary routine, where it descends but doesn't fall (alike in S2NA); TODO
		bsr.w	FindNextFreeObj
		bne.s	.return
		_move.b	#id_Obj1C,obID(a1) ; load obj1C
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obRender(a0),obRender(a1)
		move.b	#6,obSubtype(a1)	; doesn't exists either but it's not causing any issues
.return:	rts
; ---------------------------------------------------------------------------

Obj16_Fall:
		bsr.w	ObjectMove
		addi.w	#$38,obVelY(a0)
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#$E0,d0		; screen_height
		cmp.w	obY(a0),d0
		bhs.s	.return
		move.b	obStatus(a0),d0
		andi.b	#$18,d0		; standing_mask
		beq.s	++
		bclr	#3,obStatus(a0)	; p1_standing_bit
		beq.s	+
		bclr	#3,(v_player+obStatus).w	; status.player.on_object
		bset	#1,(v_player+obStatus).w	; status.player.in_air
+
		bclr	#4,obStatus(a0)	; p2_standing_bit
		beq.s	+
		bclr	#3,(v_player2+obStatus).w	; status.player.on_object
		bset	#1,(v_player2+obStatus).w	; status.player.in_air
+
		move.w	#$4000,obX(a0)
.return:	rts
; ---------------------------------------------------------------------------

Obj16_NoMove:	; TODO
		rts
; ---------------------------------------------------------------------------