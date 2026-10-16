; S3&K mapping records. The complete 85-tile art keeps Sonic 1's tile order.
Map_Newtron_internal:
		dc.w .frame0-Map_Newtron_internal
		dc.w .frame1-Map_Newtron_internal
		dc.w .frame2-Map_Newtron_internal
		dc.w .frame3-Map_Newtron_internal
		dc.w .frame4-Map_Newtron_internal
		dc.w .frame5-Map_Newtron_internal
		dc.w .frame6-Map_Newtron_internal
		dc.w .frame7-Map_Newtron_internal
		dc.w .frame8-Map_Newtron_internal
.frame0:	dc.w 3
		dc.w $EC0D, $0000, $FFEC
		dc.w $F400, $0008, $000C
		dc.w $FC0E, $0009, $FFF4
.frame1:	dc.w 3
		dc.w $EC06, $0015, $FFEC
		dc.w $EC09, $001B, $FFFC
		dc.w $FC0A, $0021, $FFFC
.frame2:	dc.w 3
		dc.w $EC06, $002A, $FFEC
		dc.w $EC09, $001B, $FFFC
		dc.w $FC0A, $0021, $FFFC
.frame3:	dc.w 4
		dc.w $EC06, $0030, $FFEC
		dc.w $EC09, $001B, $FFFC
		dc.w $FC09, $0036, $FFFC
		dc.w $0C00, $003C, $000C
.frame4:	dc.w 3
		dc.w $F40D, $003D, $FFEC
		dc.w $FC00, $0020, $000C
		dc.w $0408, $0045, $FFFC
.frame5:	dc.w 2
		dc.w $F80D, $0048, $FFEC
		dc.w $F801, $0050, $000C
.frame6:	dc.w 3
		dc.w $F80D, $0048, $FFEC
		dc.w $F801, $0050, $000C
		dc.w $FE00, $0052, $0014
.frame7:	dc.w 3
		dc.w $F80D, $0048, $FFEC
		dc.w $F801, $0050, $000C
		dc.w $FE04, $0053, $0014
.frame8:	dc.w 0
Map_Newtron_internal_End:
		even
