; Raw cartridge-resident program uploaded into PRG-RAM bank 0. No BIOS work
; space is reserved. Game data remains in MD RAM; disc/BRAM drivers come later.
MCD_SubProgram:
		phase	0
		dc.l	$80000,MCD_SubEntry
		rept	24
		dc.l	MCD_SubError
		endm
		dc.l	MCD_SubIRQ2
		rept	37
		dc.l	MCD_SubError
		endm
MCD_SubEntry:
		move.w	#$2700,sr
		clr.b	($FF8033).l		; mask Gate Array IRQ sources
		clr.w	($FF8030).l		; stop timer
		move.b	#$FF,($FF0011).l		; silence PCM channels
		bset	#0,(MCD_SubMemoryMode).l	; give main CPU 2M Word RAM
		move.w	#MCD_Ready,(MCD_SubOwnStatus).l
		move.w	(MCD_SubMainToken).l,d7
		not.w	d7			; process the staged boot request too
.wait:
		move.w	(MCD_SubMainToken).l,d6
		cmp.w	d6,d7
		beq.s	.wait
		move.w	(MCD_SubMainCommand).l,d0
		beq.s	.done
		cmpi.w	#MCD_CommandPing,d0
		beq.s	.ping
		cmpi.w	#MCD_CommandReturnRAM,d0
		beq.s	.returnRAM
		moveq	#-1,d0
		bra.s	.done
.ping:
		move.w	(MCD_SubMainArgument).l,d0
		bra.s	.done
.returnRAM:
		bset	#0,(MCD_SubMemoryMode).l
		moveq	#0,d0
.done:
		move.w	d0,(MCD_SubOwnResult).l
		move.w	d6,d7
		move.w	d7,(MCD_SubOwnAck).l
		bra.s	.wait
MCD_SubIRQ2:
		rte
MCD_SubError:
		move.w	#$FFFF,(MCD_SubOwnStatus).l
		bra.s	*
		even
		dephase
MCD_SubProgramEnd:
		if (MCD_SubProgramEnd-MCD_SubProgram)>$20000
			fatal "Mode 1 bootstrap exceeds its bank-0 upload window"
		endif
