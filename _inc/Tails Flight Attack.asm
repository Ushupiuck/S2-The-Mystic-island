; ---------------------------------------------------------------------------
; S3&K's angle quantization for the flight attack sector. The general CalcAngle
; rounds the 45-degree boundary down; keep the stock table for this contact test.
; Input: d1.w = player X - enemy X, d2.w = player Y - enemy Y; d0.w = angle.
; From skdisasm 73de97c6b55055bcb8089c1d55d006b02136f163, GetArcTan.
; ---------------------------------------------------------------------------
Tails_CalcFlightAttackAngle:
		movem.l d3-d4,-(sp)
		moveq   #0,d3
		moveq   #0,d4
		move.w  d1,d3
		move.w  d2,d4
		or.w    d3,d4
		beq.s   .zero
		move.w  d2,d4
		tst.w   d3
		bpl.s   .x_positive
		neg.w   d3
.x_positive:
		tst.w   d4
		bpl.s   .y_positive
		neg.w   d4
.y_positive:
		cmp.w   d3,d4
		bhs.s   .y_larger
		lsl.l   #8,d4
		divu.w  d3,d4
		moveq   #0,d0
		move.b  Tails_FlightArcTanTable(pc,d4.w),d0
		bra.s   .quadrant
.y_larger:
		lsl.l   #8,d3
		divu.w  d4,d3
		moveq   #$40,d0
		sub.b   Tails_FlightArcTanTable(pc,d3.w),d0
.quadrant:
		tst.w   d1
		bpl.s   .x_quadrant
		neg.w   d0
		addi.w  #$80,d0
.x_quadrant:
		tst.w   d2
		bpl.s   .return
		neg.w   d0
		addi.w  #$100,d0
.return:
		movem.l (sp)+,d3-d4
		rts
.zero:
		move.w  #$40,d0
		bra.s   .return
Tails_FlightArcTanTable:
		dc.b $00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02
		dc.b $03,$03,$03,$03,$03,$03,$03,$04,$04,$04,$04,$04,$04,$05,$05,$05
		dc.b $05,$05,$05,$06,$06,$06,$06,$06,$06,$06,$07,$07,$07,$07,$07,$07
		dc.b $08,$08,$08,$08,$08,$08,$08,$09,$09,$09,$09,$09,$09,$0A,$0A,$0A
		dc.b $0A,$0A,$0A,$0A,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0C,$0C,$0C,$0C,$0C
		dc.b $0C,$0C,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0E,$0E,$0E,$0E,$0E,$0E,$0E
		dc.b $0F,$0F,$0F,$0F,$0F,$0F,$0F,$10,$10,$10,$10,$10,$10,$10,$11,$11
		dc.b $11,$11,$11,$11,$11,$11,$12,$12,$12,$12,$12,$12,$12,$13,$13,$13
		dc.b $13,$13,$13,$13,$13,$14,$14,$14,$14,$14,$14,$14,$14,$15,$15,$15
		dc.b $15,$15,$15,$15,$15,$15,$16,$16,$16,$16,$16,$16,$16,$16,$17,$17
		dc.b $17,$17,$17,$17,$17,$17,$17,$18,$18,$18,$18,$18,$18,$18,$18,$18
		dc.b $19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$1A,$1A,$1A,$1A,$1A,$1A
		dc.b $1A,$1A,$1A,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1C,$1C,$1C
		dc.b $1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D
		dc.b $1D,$1D,$1D,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1F,$1F
		dc.b $1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$20,$20,$20,$20,$20,$20
		dc.b $20,$00
		even
