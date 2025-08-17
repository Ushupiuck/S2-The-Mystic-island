; ---------------------------------------------------------------------------
; Subroutine to pause the game
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


PauseGame:
		nop
		tst.b	(v_lives).w
		beq.s	Unpause
		tst.w	(f_pause).w
		bne.s	Pause_AlreadyPaused
		btst	#bitStart,(v_jpadpress1).w
		beq.s	Pause_DoNothing

Pause_AlreadyPaused:
		move.w	#1,(f_pause).w
		jsr	PauseSoundDriver

Pause_Loop:
		move.b	#VintID_Pause,(v_vbla_routine).w
		bsr.w	WaitForVint
		tst.b	(f_slomocheat).w
		beq.s	Pause_ChkStart
		btst	#bitA,(v_jpadpress1).w
		beq.s	Pause_ChkBC
		move.b	#GameModeID_TitleScreen,(v_gamemode).w
		nop
		bra.s	Pause_Resume
; ===========================================================================

Pause_ChkBC:
		btst	#bitB,(v_jpadhold1).w
		bne.s	Pause_SlowMo
		btst	#bitC,(v_jpadpress1).w
		bne.s	Pause_SlowMo

Pause_ChkStart:
		btst	#bitStart,(v_jpadpress1).w
		beq.s	Pause_Loop
; loc_1464:
Pause_Resume:
		jsr	UnpauseSoundDriver

Unpause:
		move.w	#0,(f_pause).w

Pause_DoNothing:
		rts
; ===========================================================================
; loc_1472:
Pause_SlowMo:
		move.w	#1,(f_pause).w
		jmp	UnpauseSoundDriver
; End of function PauseGame