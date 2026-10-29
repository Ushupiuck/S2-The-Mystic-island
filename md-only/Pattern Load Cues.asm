; Cartridge-only Nemesis PLC preparation and VBlank output.

ClearPLC:
		lea	(v_plc_buffer).w,a2
		moveq	#bytesToLcnt(v_plc_buffer_end-v_plc_buffer),d0

.clear:
		clr.l	(a2)+
		dbf	d0,.clear
		rts
; End of function ClearPLC


; ---------------------------------------------------------------------------
; Subroutine to use graphics listed in a pattern load cue
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; RunPLC:
RunPLC_RAM:
		tst.l	(v_plc_buffer).w
		beq.s	.return
		bmi.w	RunPLC_KosModule
		tst.w	(v_plc_patternsleft).w
		bne.s	.return
		movea.l	(v_plc_buffer).w,a0
		lea	NemPCD_WriteRowToVDP(pc),a3
		lea	(v_ngfx_buffer).w,a1
		move.w	(a0)+,d2
		bpl.s	+
		adda.w	#NemPCD_WriteRowToVDP_XOR-NemPCD_WriteRowToVDP,a3
+
		andi.w	#$7FFF,d2
		bsr.w	NemDec_BuildCodeTable
		move.b	(a0)+,d5
		asl.w	#8,d5
		move.b	(a0)+,d5
		moveq	#$10,d6
		moveq	#0,d0
		move.l	a0,(v_plc_buffer).w
		move.l	a3,(v_plc_ptrnemcode).w
		move.l	d0,(v_plc_repeatcount).w
		move.l	d0,(v_plc_paletteindex).w
		move.l	d0,(v_plc_previousrow).w
		move.l	d5,(v_plc_dataword).w
		move.l	d6,(v_plc_shiftvalue).w
		move.w	d2,(v_plc_patternsleft).w

.return:
		rts
; End of function RunPLC_RAM


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||
; Process one PLC from the queue

; sub_1732:
ProcessDPLC:
		tst.w	(v_plc_patternsleft).w		; Is there anything to decompress?
		beq.w	ProcessDPLC_Done		; If not, branch

ProcessDPLC_Large:
		move.w	#9,(v_plc_framepatternsleft).w	; 9 patterns are decompressed every frame
		moveq	#0,d0				; Get VRAM address
		move.w	(v_plc_buffer+4).w,d0
		addi.w	#9*$20,(v_plc_buffer+4).w	; increment by 9 patterns's worth of data
		bra.s	ProcessDPLC_Main

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||
; Process one PLC from the queue

; loc_174E:
ProcessDPLC2:
		tst.w	(v_plc_patternsleft).w		; Is there anything to decompress?
		beq.w	ProcessDPLC_Done		; If not, branch
	;	tst.b	(f_lockscreen).w		; Is the screen locked?
	;	bne.s	ProcessDPLC_Large		; If so, go with the large batch instead
		move.w	#3,(v_plc_framepatternsleft).w	; 3 patterns are decompressed every frame
		moveq	#0,d0				; Get VRAM address
		move.w	(v_plc_buffer+4).w,d0
		addi.w	#3*$20,(v_plc_buffer+4).w	; increment by 3 patterns's worth of data
; loc_1766:
ProcessDPLC_Main:
		lea	(vdp_control_port).l,a4		; Set VDP write command
		lsl.l	#2,d0
		lsr.w	#2,d0
		ori.w	#$4000,d0
		swap	d0
		move.l	d0,(a4)
		subq.w	#4,a4				; Prepare data port
		movea.l	(v_plc_buffer).w,a0		; Get decompression registers
		movea.l	(v_plc_ptrnemcode).w,a3
		move.l	(v_plc_repeatcount).w,d0
		move.l	(v_plc_paletteindex).w,d1
		move.l	(v_plc_previousrow).w,d2
		move.l	(v_plc_dataword).w,d5
		move.l	(v_plc_shiftvalue).w,d6
		lea	(v_ngfx_buffer).w,a1

.Decomp:
		movea.w	#8,a5				; Store decompressed tile in VRAM
		bsr.w	NemPCD_NewRow
		subq.w	#1,(v_plc_patternsleft).w	; Decrement total tile count
		beq.s	ProcessDPLC_Pop			; If this art is finished being decompressed, branch
		subq.w	#1,(v_plc_framepatternsleft).w	; Decrement number of tiles left to decompress in this batch
		bne.s	.Decomp				; If we are not done, branch
		move.l	a0,(v_plc_buffer).w
		move.l	a3,(v_plc_ptrnemcode).w
		move.l	d0,(v_plc_repeatcount).w
		move.l	d1,(v_plc_paletteindex).w
		move.l	d2,(v_plc_previousrow).w
		move.l	d5,(v_plc_dataword).w
		move.l	d6,(v_plc_shiftvalue).w
		rts

ProcessDPLC_Pop:
		lea	(v_plc_buffer).w,a0
		moveq	#bytesToLcnt(v_plc_buffer_only_end-v_plc_buffer-6),d0

loc_17D2:
		move.l	6(a0),(a0)+
		dbf	d0,loc_17D2
	if (v_plc_buffer_only_end-v_plc_buffer-6)&2
		move.w	6(a0),(a0)
	endif
		clr.l	(v_plc_buffer_only_end-6).w

ProcessDPLC_Done:
		rts
