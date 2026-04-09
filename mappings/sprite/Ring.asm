; ---------------------------------------------------------------------------
; Sprite mappings - rings (Sonic 2 custom ring format, no MapMacros)
; One sprite piece is assumed for every frame.
; ---------------------------------------------------------------------------

Map_Ring_internal:
		dc.w	.ring-Map_Ring_internal
		dc.w	.sparkle1-Map_Ring_internal
		dc.w	.sparkle2-Map_Ring_internal
		dc.w	.sparkle3-Map_Ring_internal
		dc.w	.sparkle4-Map_Ring_internal
		dc.w	.blank-Map_Ring_internal

.ring:
		dc.b	-8, 5
		dc.w	$0000, $0000, -8

.sparkle1:
		dc.b	-8, 5
		dc.w	$0008, $0004, -8

.sparkle2:
		dc.b	-8, 5
		dc.w	$1808, $1804, -8

.sparkle3:
		dc.b	-8, 5
		dc.w	$0808, $0804, -8

.sparkle4:
		dc.b	-8, 5
		dc.w	$1008, $1004, -8

.blank:
		dc.b	0
		; WARNING:
		; In the regular S2 format this was a true 0-piece frame.
		; In the custom ring format, a frame is always assumed to contain 1 piece.
		; So this label is structurally valid as an offset target, but it is NOT
		; a safe drawable blank frame by itself.

		even