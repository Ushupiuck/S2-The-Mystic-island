; ---------------------------------------------------------------------------

LevelLayout_Convert:	; leftover level layout converting function (from raw to the way it's stored in the game)
		lea	(RAM_debug_start&$FFFFFF).l,a1		; Set up input buffer pointer
		lea	(RAM_debug_start&$FFFFFF+$80).l,a2	; Set up offset for intermediate processing
		lea	(v_start).l,a3				; Set up pointer to the output buffer address
		move.w	#$40-1,d1				; Initialize loop counter

loc_747A:	; Main Loop
		bsr.w	sub_750C				; Copy data from a3 to a1 and a2
		bsr.w	sub_750C				; ...Twice
		dbf	d1,loc_747A				; Repeat loop until d1 becomes zero
		lea	(RAM_debug_start&$FFFFFF).l,a1		; Reset input buffer pointer
		lea	(v_start&$FFFFFF).l,a2			; Reset output buffer pointer
		move.w	#bytesToWcnt($80),d1			; Reset loop counter

loc_7496:	; Clearing Output Buffer
		move.w	#0,(a2)+				; Clear the output buffer
		dbf	d1,loc_7496				; Repeat until d1 becomes zero
		move.w	#bytesToWcnt($7F80),d1			; Initialize loop counter for copying remaining data

loc_74A2:	; Copying Remaining Data
		move.w	(a1)+,(a2)+				; Copy data from input buffer to output buffer
		dbf	d1,loc_74A2				; Repeat until d1 becomes zero
		rts
; ---------------------------------------------------------------------------
		lea	(RAM_debug_start&$FFFFFF).l,a1
		lea	(v_start).l,a3
		moveq	#bytesToLcnt($80),d0

loc_74B8:
		move.l	(a1)+,(a3)+
		dbf	d0,loc_74B8
		moveq	#0,d7
		lea	(RAM_debug_start&$FFFFFF).l,a1
		move.w	#bytesToWcnt($200),d5

loc_74CA:
		lea	(v_start).l,a3
		move.w	d7,d6

loc_74D2:
		movem.l	a1-a3,-(sp)
		move.w	#bytesToWcnt($80),d0

loc_74DA:
		cmpm.w	(a1)+,(a3)+
		bne.s	loc_74F0
		dbf	d0,loc_74DA
		movem.l	(sp)+,a1-a3
		adda.w	#$80,a1
		dbf	d5,loc_74CA
		bra.s	loc_750A
; ---------------------------------------------------------------------------

loc_74F0:
		movem.l	(sp)+,a1-a3
		adda.w	#$80,a3
		dbf	d6,loc_74D2
		moveq	#bytesToLcnt($80),d0

loc_74FE:
		move.l	(a1)+,(a3)+
		dbf	d0,loc_74FE
		addq.l	#1,d7
		dbf	d5,loc_74CA

loc_750A:
		bra.s	loc_750A

; =============== S U B	R O U T	I N E =======================================


sub_750C:
		moveq	#bytesToXcnt($100,32),d0		; Initialize loop counter

loc_750E:	; Copying Data Block
		move.l	(a3)+,(a1)+				; Copy block of data from a3 to a1
		move.l	(a3)+,(a1)+
		move.l	(a3)+,(a1)+
		move.l	(a3)+,(a1)+
		move.l	(a3)+,(a2)+				; Copy block of data from a3 to a2
		move.l	(a3)+,(a2)+
		move.l	(a3)+,(a2)+
		move.l	(a3)+,(a2)+
		dbf	d0,loc_750E				; Repeat until d0 becomes zero
		adda.w	#$80,a1					; Increment input buffer pointer
		adda.w	#$80,a2					; Increment output buffer pointer
		rts
; End of function sub_750C