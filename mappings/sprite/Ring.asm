; ---------------------------------------------------------------------------
; S3&K custom ring mappings: one fixed eight-byte record per frame.
; Signed Y, size word, complete tile/palette word, signed X; no offset table.
; Spinning rings animate their art in place, so the idle record stays fixed.
; Consumed rings are skipped before looking up these records.
; ---------------------------------------------------------------------------
Map_Ring_internal:
		dc.w	-8, 5, make_art_tile(ArtTile_Ring,1,0), -8
		dc.w	-8, 5, make_art_tile(ArtTile_Sparkles,1,0), -8
		dc.w	-8, 5, $1800+make_art_tile(ArtTile_Sparkles,1,0), -8
		dc.w	-8, 5, $0800+make_art_tile(ArtTile_Sparkles,1,0), -8
		dc.w	-8, 5, $1000+make_art_tile(ArtTile_Sparkles,1,0), -8
		even
