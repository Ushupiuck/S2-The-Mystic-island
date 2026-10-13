; S3&K mappings. Frame IDs retain the original award/bumper meanings.
; Each DPLC supplies two tiles. Tile 1 is reused for additional zeros,
; preserving the original pixels and positions even for 10000/50000.
		dc.w .hundred-Map_Points
		dc.w .twohundred-Map_Points
		dc.w .fivehundred-Map_Points
		dc.w .thousand-Map_Points
		dc.w .ten-Map_Points
		dc.w .tenthousand-Map_Points
		dc.w .fiftythousand-Map_Points
		dc.w .hidden-Map_Points		; retiring popup, including an already queued sprite
.hundred:
		dc.w 1
		dc.w $FC04,0,-6
.twohundred:
		dc.w 1
		dc.w $FC04,0,-8
.fivehundred:
		dc.w 1
		dc.w $FC04,0,-8
.thousand:
		dc.w 2
		dc.w $FC04,0,-8
		dc.w $FC00,1,5
.ten:
		dc.w 1
		dc.w $FC00,0,-4
.tenthousand:
		dc.w 3
		dc.w $FC04,0,-8
		dc.w $FC00,1,5
		dc.w $FC00,1,10
.fiftythousand:
		dc.w 5
		dc.w $FC00,0,-8
		dc.w $FC00,1,-3
		dc.w $FC00,1,2
		dc.w $FC00,1,7
		dc.w $FC00,1,12
.hidden:
		dc.w 0
		even
