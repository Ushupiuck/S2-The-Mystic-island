; S3&K word-count/run DPLCs. Bank cache zero is reserved for empty VRAM;
; actual award frame IDs select indices 1-7 through Points_FrameBias.
		dc.w .empty-DPLC_Points
		dc.w .hundred-DPLC_Points
		dc.w .twohundred-DPLC_Points
		dc.w .fivehundred-DPLC_Points
		dc.w .hundred-DPLC_Points	; 1000 repeats the zero tile
		dc.w .hundred-DPLC_Points	; 10 uses only the first tile
		dc.w .hundred-DPLC_Points	; 10000 repeats the zero tile
		dc.w .fiftythousand-DPLC_Points
		dc.w .empty-DPLC_Points		; hidden mapping (no active award uses this frame)
.empty:
		dc.w 0
.hundred:
		dc.w 1,$1000
.twohundred:
		dc.w 1,$1002
.fivehundred:
		dc.w 1,$1004
.fiftythousand:
		dc.w 2,$0004,$0001		; leading 5 and the complete repeatable zero
		even
