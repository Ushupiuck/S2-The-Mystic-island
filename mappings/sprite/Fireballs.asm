; S1 Fireballs, s1disasm 2c51d46. Word count and six-byte mapping pieces.
; Both flight poses and the impact frame for each direction share one bank.
Map_Fireballs:
	dc.w .vertical1-Map_Fireballs,.vertical2-Map_Fireballs,.verticalImpact-Map_Fireballs
	dc.w .horizontal1-Map_Fireballs,.horizontal2-Map_Fireballs,.horizontalImpact-Map_Fireballs
.vertical1:
	dc.w 1
	dc.b -24,$07
	dc.w $0000,-8
.vertical2:
	dc.w 1
	dc.b -24,$07
	dc.w $0008,-8
.verticalImpact:
	dc.w 1
	dc.b -16,$06
	dc.w $0010,-8
.horizontal1:
	dc.w 1
	dc.b -8,$0D
	dc.w $0016,-24
.horizontal2:
	dc.w 1
	dc.b -8,$0D
	dc.w $001E,-24
.horizontalImpact:
	dc.w 1
	dc.b -8,$09
	dc.w $0026,-16
	even
