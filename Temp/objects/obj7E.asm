; --------------------------------------------------------------------------------
; Sprite mappings - output from ClownMapEd - Sonic 2 format
; --------------------------------------------------------------------------------

.offsets:
	dc.w	.frame0-.offsets
	dc.w	.frame1-.offsets
	dc.w	.frame2-.offsets
	dc.w	.frame3-.offsets
	dc.w	.frame4-.offsets
	dc.w	.frame5-.offsets
	dc.w	.frame6-.offsets

.frame0:
	dc.w	1

	dc.b	-8
	dc.b	$05
	dc.w	$2004
	dc.w	$2002
	dc.w	-8

.frame1:
	dc.w	1

	dc.b	-8
	dc.b	$05
	dc.w	$0000
	dc.w	$0000
	dc.w	-8

.frame2:
	dc.w	1

	dc.b	-8
	dc.b	$05
	dc.w	$4004
	dc.w	$4002
	dc.w	-8

.frame3:
	dc.w	1

	dc.b	-8
	dc.b	$05
	dc.w	$6004
	dc.w	$6002
	dc.w	-8

.frame4:
	dc.w	1

	dc.b	-8
	dc.b	$05
	dc.w	$2008
	dc.w	$2004
	dc.w	-8

.frame5:
	dc.w	1

	dc.b	-8
	dc.b	$05
	dc.w	$200C
	dc.w	$2006
	dc.w	-8

.frame6:
	dc.w	0

	even
