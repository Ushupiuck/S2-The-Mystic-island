; ===========================================================================
; ---------------------------------------------------------------------------
; Kosinski decompression routine
;
; Created by vladikcomper
; Special thanks to flamewing and MarkeyJester
; Modified for AS by MainMemory
; ---------------------------------------------------------------------------

_Kos_RunBitStream macro
	dbf	d2,+
	moveq	#7,d2
	move.b	d1,d0
	swap	d3
	bpl.s	+
	move.b	(a0)+,d0			; get desc. bitfield
	move.b	(a0)+,d1			;
	move.b	(a4,d0.w),d0			; reload converted desc. bitfield from a LUT
	move.b	(a4,d1.w),d1			;
+
	endm
; ---------------------------------------------------------------------------

KosDec:
	moveq	#7,d7
	moveq	#0,d0
	moveq	#0,d1
	lea	KosDec_ByteMap(pc),a4
	move.b	(a0)+,d0			; get desc field low-byte
	move.b	(a0)+,d1			; get desc field hi-byte
	move.b	(a4,d0.w),d0			; reload converted desc. bitfield from a LUT
	move.b	(a4,d1.w),d1			;
	moveq	#7,d2				; set repeat count to 8
	moveq	#-1,d3				; d3 will be desc field switcher
	clr.w	d3				;
	bra.s	KosDec_FetchNewCode

KosDec_FetchCodeLoop:
	; code 1 (Uncompressed byte)
	_Kos_RunBitStream
	move.b	(a0)+,(a1)+

KosDec_FetchNewCode:
	add.b	d0,d0				; get a bit from the bitstream
	bcs.s	KosDec_FetchCodeLoop		; if code = 0, branch

	; codes 00 and 01
	_Kos_RunBitStream
	moveq	#0,d4				; d4 will contain copy count
	add.b	d0,d0				; get a bit from the bitstream
	bcs.s	KosDec_Code_01

	; code 00 (Dictionary ref. short)
	_Kos_RunBitStream
	add.b	d0,d0				; get a bit from the bitstream
	addx.w	d4,d4
	_Kos_RunBitStream
	add.b	d0,d0				; get a bit from the bitstream
	addx.w	d4,d4
	_Kos_RunBitStream
	moveq	#-1,d5
	move.b	(a0)+,d5			; d5 = displacement

KosDec_StreamCopy:
	lea	(a1,d5),a3
	move.b	(a3)+,(a1)+			; do 1 extra copy (to compensate for +1 to copy counter)

KosDec_copy:
	move.b	(a3)+,(a1)+
	dbf	d4,KosDec_copy
	bra.w	KosDec_FetchNewCode
; ---------------------------------------------------------------------------
KosDec_Code_01:
	; code 01 (Dictionary ref. long / special)
	_Kos_RunBitStream
	move.b	(a0)+,d6			; d6 = %LLLLLLLL
	move.b	(a0)+,d4			; d4 = %HHHHHCCC
	moveq	#-1,d5
	move.b	d4,d5				; d5 = %11111111 HHHHHCCC
	lsl.w	#5,d5				; d5 = %111HHHHH CCC00000
	move.b	d6,d5				; d5 = %111HHHHH LLLLLLLL
	and.w	d7,d4				; d4 = %00000CCC
	bne.s	KosDec_StreamCopy		; if CCC=0, branch

	; special mode (extended counter)
	move.b	(a0)+,d4			; read cnt
	beq.s	KosDec_Quit			; if cnt=0, quit decompression
	subq.b	#1,d4
	beq.w	KosDec_FetchNewCode		; if cnt=1, fetch a new code

	lea	(a1,d5),a3
	move.b	(a3)+,(a1)+			; do 1 extra copy (to compensate for +1 to copy counter)
	move.w	d4,d6
	not.w	d6
	and.w	d7,d6
	add.w	d6,d6
	lsr.w	#3,d4
	jmp	KosDec_largecopy(pc,d6.w)

KosDec_largecopy:
	rept 8
	move.b	(a3)+,(a1)+
	endm
	dbf	d4,KosDec_largecopy
	bra.w	KosDec_FetchNewCode

KosDec_Quit:
	rts

; ---------------------------------------------------------------------------
; A look-up table to invert bits order in desc. field bytes
; ---------------------------------------------------------------------------

KosDec_ByteMap:
	dc.b	$00,$80,$40,$C0,$20,$A0,$60,$E0,$10,$90,$50,$D0,$30,$B0,$70,$F0
	dc.b	$08,$88,$48,$C8,$28,$A8,$68,$E8,$18,$98,$58,$D8,$38,$B8,$78,$F8
	dc.b	$04,$84,$44,$C4,$24,$A4,$64,$E4,$14,$94,$54,$D4,$34,$B4,$74,$F4
	dc.b	$0C,$8C,$4C,$CC,$2C,$AC,$6C,$EC,$1C,$9C,$5C,$DC,$3C,$BC,$7C,$FC
	dc.b	$02,$82,$42,$C2,$22,$A2,$62,$E2,$12,$92,$52,$D2,$32,$B2,$72,$F2
	dc.b	$0A,$8A,$4A,$CA,$2A,$AA,$6A,$EA,$1A,$9A,$5A,$DA,$3A,$BA,$7A,$FA
	dc.b	$06,$86,$46,$C6,$26,$A6,$66,$E6,$16,$96,$56,$D6,$36,$B6,$76,$F6
	dc.b	$0E,$8E,$4E,$CE,$2E,$AE,$6E,$EE,$1E,$9E,$5E,$DE,$3E,$BE,$7E,$FE
	dc.b	$01,$81,$41,$C1,$21,$A1,$61,$E1,$11,$91,$51,$D1,$31,$B1,$71,$F1
	dc.b	$09,$89,$49,$C9,$29,$A9,$69,$E9,$19,$99,$59,$D9,$39,$B9,$79,$F9
	dc.b	$05,$85,$45,$C5,$25,$A5,$65,$E5,$15,$95,$55,$D5,$35,$B5,$75,$F5
	dc.b	$0D,$8D,$4D,$CD,$2D,$AD,$6D,$ED,$1D,$9D,$5D,$DD,$3D,$BD,$7D,$FD
	dc.b	$03,$83,$43,$C3,$23,$A3,$63,$E3,$13,$93,$53,$D3,$33,$B3,$73,$F3
	dc.b	$0B,$8B,$4B,$CB,$2B,$AB,$6B,$EB,$1B,$9B,$5B,$DB,$3B,$BB,$7B,$FB
	dc.b	$07,$87,$47,$C7,$27,$A7,$67,$E7,$17,$97,$57,$D7,$37,$B7,$77,$F7
	dc.b	$0F,$8F,$4F,$CF,$2F,$AF,$6F,$EF,$1F,$9F,$5F,$DF,$3F,$BF,$7F,$FF

; ===========================================================================
; ---------------------------------------------------------------------------
; New format based on Kosinski. It changes several design decisions to allow
; a faster decompressor without loss of compression ratio.
; Created originally by Flamewing and vladikcomper (by discussions on IRC),
; further improvements by Clownacy.
; ---------------------------------------------------------------------------
; Permission to use, copy, modify, and/or distribute this software for any
; purpose with or without fee is hereby granted.
;
; THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
; WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
; MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
; ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
; WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
; ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
; OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
; ---------------------------------------------------------------------------
; FUNCTION:
; 	KosPlusDec
;
; DESCRIPTION
; 	Kosinski+ Decompressor
;
; INPUT:
; 	a0	Source address
; 	a1	Destination address
; ---------------------------------------------------------------------------
_KosPlus_LoopUnroll = 3

_KosPlus_ReadBit macro
	dbra	d2,.skip
	moveq	#7,d2						; We have 8 new bits, but will use one up below.
	move.b	(a0)+,d0					; Get desc field low-byte.
.skip:
	add.b	d0,d0						; Get a bit from the bitstream.
	endm
; ===========================================================================

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||
; ---------------------------------------------------------------------------
KosPlusDec:
	if _KosPlus_LoopUnroll>0
		moveq	#(1<<_KosPlus_LoopUnroll)-1,d7
	endif
	moveq	#0,d2						; Flag as having no bits left.
	bra.s	.FetchNewCode
; ---------------------------------------------------------------------------
.FetchCodeLoop:
	; Code 1 (Uncompressed byte).
	move.b	(a0)+,(a1)+

.FetchNewCode:
	_KosPlus_ReadBit
	bcs.s	.FetchCodeLoop				; If code = 1, branch.

	; Codes 00 and 01.
	moveq	#-1,d5
	lea	(a1),a5
	_KosPlus_ReadBit
	bcs.s	.Code_01

	; Code 00 (Dictionary ref. short).
	move.b	(a0)+,d5					; d5 = displacement.
	adda.w	d5,a5
	; Always copy at least two bytes.
	move.b	(a5)+,(a1)+
	move.b	(a5)+,(a1)+
	_KosPlus_ReadBit
	bcc.s	.Copy_01
	move.b	(a5)+,(a1)+
	move.b	(a5)+,(a1)+

.Copy_01:
	_KosPlus_ReadBit
	bcc.s	.FetchNewCode
	move.b	(a5)+,(a1)+
	bra.s	.FetchNewCode
; ---------------------------------------------------------------------------
.Code_01:
	moveq	#0,d4						; d4 will contain copy count.
	; Code 01 (Dictionary ref. long / special).
	move.b	(a0)+,d4					; d4 = %HHHHHCCC.
	move.b	d4,d5						; d5 = %11111111 HHHHHCCC.
	lsl.w	#5,d5						; d5 = %111HHHHH CCC00000.
	move.b	(a0)+,d5					; d5 = %111HHHHH LLLLLLLL.
	if _KosPlus_LoopUnroll==3
		and.w	d7,d4					; d4 = %00000CCC.
	else
		andi.w	#7,d4
	endif
	if _KosPlus_LoopUnroll>0
		bne.s	.StreamCopy				; if CCC=0, branch.

		; special mode (extended counter)
		move.b	(a0)+,d4				; Read cnt
		beq.s	.Quit					; If cnt=0, quit decompression.

		adda.w	d5,a5
		move.w	d4,d6
		not.w	d6
		and.w	d7,d6
		add.w	d6,d6
		lsr.w	#_KosPlus_LoopUnroll,d4
		jmp	.largecopy(pc,d6.w)
	else
		beq.s	.dolargecopy
	endif
; ---------------------------------------------------------------------------
.StreamCopy:
	adda.w	d5,a5
	move.b	(a5)+,(a1)+					; Do 1 extra copy (to compensate +1 to copy counter).
	add.w	d4,d4
	jmp	.mediumcopy-2(pc,d4.w)
; ---------------------------------------------------------------------------
	if _KosPlus_LoopUnroll==0
.dolargecopy:
		; special mode (extended counter)
		move.b	(a0)+,d4				; Read cnt
		beq.s	.Quit					; If cnt=0, quit decompression.
		adda.w	d5,a5
	endif

.largecopy:
	rept (1<<_KosPlus_LoopUnroll)
		move.b	(a5)+,(a1)+
	endm
	dbra	d4,.largecopy

.mediumcopy:
	rept 8
		move.b	(a5)+,(a1)+
	endm
	bra.w	.FetchNewCode
; ---------------------------------------------------------------------------
.Quit:
	rts
; ===========================================================================