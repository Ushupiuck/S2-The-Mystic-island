; ---------------------------------------------------------------------------
; Sprite mappings - rings
; Sonic 3 & Knuckles custom ring format
; - no offset table
; - 1 sprite piece per frame (implicit)
; - signed Y position
; - signed size value
; - signed X position
; ---------------------------------------------------------------------------

CMap_Ring
.ring
		dc.w	-8
		dc.w	$0005
		dc.w	$0000+make_art_tile(ArtTile_Ring,1,0)
		dc.w	-8

.sparkle1
		dc.w	-8
		dc.w	$0005
		dc.w	$0008+make_art_tile(ArtTile_Ring,1,0)
		dc.w	-8

.sparkle2
		dc.w	-8
		dc.w	$0005
		dc.w	$1808+make_art_tile(ArtTile_Ring,1,0)
		dc.w	-8

.sparkle3
		dc.w	-8
		dc.w	$0005
		dc.w	$0808+make_art_tile(ArtTile_Ring,1,0)
		dc.w	-8

.sparkle4
		dc.w	-8
		dc.w	$0005
		dc.w	$1008+make_art_tile(ArtTile_Ring,1,0)
		dc.w	-8

.blank
		dc.w	0

		even