; Imported from skdisasm 73de97c6b55055bcb8089c1d55d006b02136f163.
Map_HangingSonic:
		dc.w .pose0-Map_HangingSonic
		dc.w .pose1-Map_HangingSonic
		dc.w .pose2-Map_HangingSonic
		dc.w .pose3-Map_HangingSonic
		dc.w .pose4-Map_HangingSonic
		dc.w .pose5-Map_HangingSonic
		dc.w .pose6-Map_HangingSonic
.pose0:	dc.w 4	; S3&K frame $80
		dc.b $E8,$0E,$00,$00,$FF,$EF
		dc.b $E8,$00,$00,$0C,$00,$0F
		dc.b $00,$04,$00,$0D,$FF,$F7
		dc.b $08,$09,$00,$0F,$FF,$EF
.pose1:	dc.w 4	; S3&K frame $81
		dc.b $E8,$0C,$00,$00,$FF,$EE
		dc.b $F0,$0D,$00,$04,$FF,$EE
		dc.b $00,$05,$00,$0C,$FF,$F6
		dc.b $10,$08,$00,$10,$FF,$EE
.pose2:	dc.w 3	; S3&K frame $82
		dc.b $E8,$08,$00,$00,$FF,$F4
		dc.b $F0,$0C,$00,$03,$FF,$EC
		dc.b $F8,$0B,$00,$07,$FF,$F4
.pose3:	dc.w 4	; S3&K frame $83
		dc.b $E8,$00,$00,$00,$FF,$EA
		dc.b $E8,$0D,$00,$01,$FF,$F2
		dc.b $F8,$08,$00,$09,$FF,$F2
		dc.b $00,$06,$00,$0C,$FF,$FA
.pose4:	dc.w 3	; S3&K frame $84
		dc.b $E8,$0E,$00,$00,$FF,$ED
		dc.b $00,$09,$00,$0C,$FF,$F5
		dc.b $10,$04,$00,$12,$FF,$F5
.pose5:	dc.w 2	; S3&K frame $85
		dc.b $E8,$0E,$00,$00,$FF,$EF
		dc.b $00,$06,$00,$0C,$FF,$F7
.pose6:	dc.w 4	; S3&K frame $91
		dc.b $E6,$09,$00,$00,$FF,$F0
		dc.b $F6,$0C,$00,$06,$FF,$F0
		dc.b $FE,$08,$00,$0A,$FF,$F0
		dc.b $06,$0D,$00,$0D,$FF,$F8
