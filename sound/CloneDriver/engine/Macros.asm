; Native YM helpers. Sound_Update owns the negotiated Z80 bus; these
; upstream safe-pair names now mask IRQs only. Game callers use the public
; sound interface, not the upstream stand-alone update/pause macros.
SMPS_stopZ80_safe macro
	move.w sr,-(sp)
	move.w #$2700,sr
	endm
SMPS_startZ80_safe macro
	move.w (sp)+,sr
	endm

; ---------------------------------------------------------------------------
; Macros to wait for when the YM2612 isn't busy.
;
; Might as well document this a little:
; When you write to the YM2612's data ports, it takes 2 YM cycles
; for the BUSY flag to set itself. A YM-cycle takes 6 cycles on the
; 68k, so we wait 12 cycles before checking the flag.
;
; The BUSY flag is seemingly hardcoded to last 32 YM cycles, or 192
; 68k cycles, so theoretically I could just burn a bunch of cycles
; here with ineffective instructions, but I think checking the flag
; would let me be a bit more precise (I don't know exactly *when* in
; the 12-cycle instruction the YM2612 is actually written to).
; ---------------------------------------------------------------------------
SMPS_delayYM macro target
	nop		; 4(1/0)
	nop		; 4(1/0)
	nop		; 4(1/0)
	endm

SMPS_waitYM macro target
.loop:	tst.b	(a0)	; 8(2/0)
	bmi.s	.loop	; 10(2/0) | 8(1/0)
	endm

SMPS_RAM_even macro
	if (*)&1	; pretty much an 'even'
	ds.b 1
	endif
	endm
