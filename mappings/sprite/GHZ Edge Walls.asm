; S3&K mapping records. Cross-bank tile offsets follow the VRAM constants.
; The cap reuses an exact, X-flipped 16x16 pattern in GHZ level art.
Map_GHZ_EdgeCap = ArtTile_Level+$C1+$800-ArtTile_GHZ_Edge_Wall
Map_GHZ_Edges_internal:
		dc.w .frame0-Map_GHZ_Edges_internal
		dc.w .frame1-Map_GHZ_Edges_internal
		dc.w .frame2-Map_GHZ_Edges_internal
.frame0:	dc.w 4
		dc.w $E005, 0, $FFF8
		dc.w $F005, 4, $FFF8
		dc.w $0005, 4, $FFF8
		dc.w $1005, 4, $FFF8
.frame1:	dc.w 4
		dc.w $E005, 4, $FFF8
		dc.w $F005, 4, $FFF8
		dc.w $0005, 4, $FFF8
		dc.w $1005, 4, $FFF8
.frame2:	dc.w 4
		dc.w $E005, Map_GHZ_EdgeCap, $FFF8
		dc.w $F005, Map_GHZ_EdgeCap, $FFF8
		dc.w $0005, Map_GHZ_EdgeCap, $FFF8
		dc.w $1005, Map_GHZ_EdgeCap, $FFF8
Map_GHZ_Edges_internal_End:
		even
