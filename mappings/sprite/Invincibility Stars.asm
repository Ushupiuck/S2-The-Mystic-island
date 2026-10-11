; S2 invincibility-star mappings for the existing 34-tile Stars.nem art.
; Frame 0 is blank; each visible star uses one VDP sprite.
		dc.w .blank-Map_InvincibilityStars
		dc.w .star1-Map_InvincibilityStars
		dc.w .star2-Map_InvincibilityStars
		dc.w .star3-Map_InvincibilityStars
		dc.w .star4-Map_InvincibilityStars
		dc.w .star5-Map_InvincibilityStars
		dc.w .star6-Map_InvincibilityStars
		dc.w .star7-Map_InvincibilityStars
		dc.w .star8-Map_InvincibilityStars
.blank:
		dc.w 0
.star1:
		dc.w 1,$F801,0,0,-4
.star2:
		dc.w 1,$F801,2,1,-4
.star3:
		dc.w 1,$F801,4,2,-4
.star4:
		dc.w 1,$F801,6,3,-4
.star5:
		dc.w 1,$F801,8,4,-4
.star6:
		dc.w 1,$F805,$A,5,-8
.star7:
		dc.w 1,$F805,$E,7,-8
.star8:
		dc.w 1,$F00F,$12,9,-$10
		even
