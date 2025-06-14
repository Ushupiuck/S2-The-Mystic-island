; ---------------------------------------------------------------------------
; Object 26 - monitors
; ---------------------------------------------------------------------------

Obj26:		;Monitor
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Mon_Index(pc,d0.w),d1
		jmp	Mon_Index(pc,d1.w)
; ===========================================================================
Mon_Index:	dc.w Mon_Init-Mon_Index
		dc.w Mon_Main-Mon_Index
		dc.w Mon_Break-Mon_Index
		dc.w Mon_Animate-Mon_Index
		dc.w Mon_Display-Mon_Index
; ===========================================================================

Mon_Init:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.b	#$E,obHeight(a0)
		move.b	#$E,obWidth(a0)
		move.l	#Map_Monitor,obMap(a0)
		move.w	#$680,obGfx(a0)
		move.b	#4,obRender(a0)
		move.b	#3,obPriority(a0)
		move.b	#$F,obActWid(a0)
		lea	(v_objstate).w,a2
		moveq	#0,d0
		move.b	obRespawnNo(a0),d0
		bclr	#7,2(a2,d0.w)
		btst	#0,2(a2,d0.w)	; has monitor been broken?
		beq.s	.notbroken	; if not, branch
		move.b	#8,obRoutine(a0) ; run "Mon_Display" routine
		move.b	#$B,obFrame(a0)	; use broken monitor frame
		rts
; ===========================================================================

.notbroken:
		move.b	#$46,obColType(a0)
		move.b	obSubtype(a0),obAnim(a0)

Mon_Main:	; Routine 2
		move.b	ob2ndRout(a0),d0 ; is monitor set to fall?
		beq.s	SolidObject_Monitor		; if not, branch
		bsr.w	ObjectMoveAndFall
		jsr	(ObjCheckFloorDist).l
		tst.w	d1
		bpl.w	SolidObject_Monitor
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		clr.b	ob2ndRout(a0)

SolidObject_Monitor:	; 2nd Routine 0
		move.w	#$1A,d1
		move.w	#$F,d2
		move.w	d2,d3
		addq.w	#1,d3
		move.w	x_pos(a0),d4
		lea	(v_player).w,a1 ; a1=character
		moveq	#3,d6
		movem.l	d1-d4,-(sp)
		bsr.w	SolidObject_Monitor_Sonic
		movem.l	(sp)+,d1-d4
		lea	(v_player+$40).w,a1 ; a1=character
		moveq	#4,d6
		bsr.w	SolidObject_Monitor_Tails
Mon_Animate:	; Routine 6
		lea	(Ani_Monitor).l,a1
		bsr.w	AnimateSprite

Mon_Display:	; Routine 8
		bra.w	MarkObjGone
; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||
; sub_12756:
SolidObject_Monitor_Sonic:
		btst	d6,status(a0)			; is Sonic standing on the monitor?
		bne.s	Mon_ChkOverEdge			; if yes, branch
		cmpi.b	#2,anim(a1)			; is Sonic spinning?
		bne.w	SolidObject_cont		; if not, branch
		rts
; End of function SolidObject_Monitor_Sonic


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||
SolidObject_Monitor_Tails:
		btst	d6,status(a0)			; is Tails standing on the monitor?
		bne.s	Mon_ChkOverEdge			; if yes, branch
		cmpi.b	#2,anim(a1)			; is Tails spinning?
		bne.w	SolidObject_cont		; if not, branch
		rts
; End of function SolidObject_Monitor_Tails

; ---------------------------------------------------------------------------
; Checks if the player has walked over the edge of the monitor.
; ---------------------------------------------------------------------------
Mon_ChkOverEdge:
		move.w	d1,d2
		add.w	d2,d2
		btst	#1,status(a1)	; is the character in the air?
		bne.s	+		; if yes, branch
		; check, if character is standing on
		move.w	x_pos(a1),d0
		sub.w	x_pos(a0),d0
		add.w	d1,d0
		bmi.s	+	; branch, if character is behind the left edge of the monitor
		cmp.w	d2,d0
		blo.s	Mon_CharStandOn	; branch, if character is not beyond the right edge of the monitor
+
		; if the character isn't standing on the monitor
		bclr	#3,status(a1)	; clear 'on object' bit
		bset	#1,status(a1)	; set 'in air' bit
		bclr	d6,status(a0)	; clear 'standing on' bit for the current character
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------
Mon_CharStandOn:
		move.w	d4,d2
		bsr.w	MvSonicOnPtfm
		moveq	#0,d4
		rts
; ===========================================================================
Mon_Break:
		move.b	status(a0),d0
		andi.b	#$78,d0	; is someone touching the monitor?
		beq.s	Mon_SpawnIcon	; if not, branch
		move.b	d0,d1
		andi.b	#$28,d1	; is it the main character?
		beq.s	+		; if not, branch
		andi.b	#$D7,(v_player+status).w
		ori.b	#2,(v_player+status).w	; prevent Sonic from walking in the air
+
		andi.b	#$50,d0	; is it the sidekick?
		beq.s	Mon_SpawnIcon	; if not, branch
		andi.b	#$D7,(v_player+$40+status).w
		ori.b	#2,(v_player+$40+status).w	; prevent Tails from walking in the air

Mon_SpawnIcon:
		clr.b	status(a0)
		addq.b	#2,obRoutine(a0)
		move.b	#0,obColType(a0)
		bsr.w	SingleObjectLoad
		bne.s	Mon_SpawnSmoke
		_move.b	#$2E,0(a1) ; load monitor contents object
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obAnim(a0),obAnim(a1)

Mon_SpawnSmoke:
		bsr.w	SingleObjectLoad
		bne.s	+
		_move.b	#$27,0(a1) ; load explosion object
		addq.b	#2,obRoutine(a1) ; don't create an animal
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
+
		lea	(v_objstate).w,a2
		moveq	#0,d0
		move.b	obRespawnNo(a0),d0
		bset	#0,2(a2,d0.w)
		move.b	#$A,obAnim(a0)	; set monitor type to broken
		bra.w	DisplaySprite