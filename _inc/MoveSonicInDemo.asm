; ---------------------------------------------------------------------------
; Subroutine to	move Sonic in demo mode
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


MoveSonicInDemo:
		tst.w	(f_demo).w	; is demo mode on?
		beq.s	.return		; if not, branch
		tst.b	(v_jpadhold1).w	; is start button pressed?
		bpl.s	.dontquit	; if not, branch
		tst.w	(f_demo).w	; is this an ending sequence demo?
		bmi.s	.dontquit	; if yes, branch
		move.w	#TitleScreen,(v_gamemode).w ; go to title screen

.dontquit:
		lea	Demo_Index(pc),a1
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
		lsl.w	#2,d0
		movea.l	(a1,d0.w),a1	; fetch address for demo data
		tst.w	(f_demo).w	; is this an ending sequence demo?
		bpl.s	.notcredits	; if not, branch
		lea	DemoEndDataPtr(pc),a1
		move.w	(v_creditsnum).w,d0
		subq.w	#1,d0
		lsl.w	#2,d0
		movea.l	(a1,d0.w),a1	; fetch address for credits demo

.notcredits:
		move.w	(Demo_button_index).w,d0
		adda.w	d0,a1
		move.b	(a1),d0
		lea	(v_jpadhold1).w,a0
		move.b	d0,d1
		move.b	v_jpadholdlogical-v_jpadhold1(a0),d2
		eor.b	d2,d0
		move.b	d1,(a0)+
		and.b	d1,d0
		move.b	d0,(a0)+
		subq.b	#1,(Demo_press_counter).w
		bcc.s	.MimicSonic
		move.b	3(a1),(Demo_press_counter).w
		addq.w	#2,(Demo_button_index).w
.MimicSonic:	clr.w	(v_jpadhold2).w
.return:	rts
; End of function MoveSonicInDemo

; ---------------------------------------------------------------------------
Demo_Index:	; Demo Index ID
		dc.l Demo_GHZ		; unused, as Level_Demo overrides the first
		dc.l Demo_GHZ		; unused, as Level_Demo overrides the first
		dc.l Demo_CPZ
		dc.l Demo_EHZ
		dc.l Demo_HPZ
		dc.l Demo_HTZ
		dc.l Demo_GHZ		; filler
		dc.l Demo_GHZ		; filler
DemoEndDataPtr:	dc.l Demo_EndGHZ1	; leftover credit sequence demos
		dc.l Demo_EndMZ
		dc.l Demo_EndSYZ
		dc.l Demo_EndLZ
		dc.l Demo_EndSLZ
		dc.l Demo_EndSBZ1
		dc.l Demo_EndSBZ2
		dc.l Demo_EndGHZ2
		even