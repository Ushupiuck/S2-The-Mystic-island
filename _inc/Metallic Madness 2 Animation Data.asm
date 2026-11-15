; Imported MMZ2 palette/terrain animation data; see import_metallic_madness.py.
; Pixel art is editable in art/uncompressed/MMZ2 Animated.unc.

AnimCue_MMZ2_Present:	zoneanimstart
		zoneanimdecl -1,Art_MMZ2Animated+0*32,ArtTile_MMZ2_Present_Anim1,4,8
		dc.b 8,6
		dc.b 16,6
		dc.b 8,6
		dc.b 0,6
		even
		zoneanimdecl -1,Art_MMZ2Animated+24*32,ArtTile_MMZ2_Present_Anim2,4,8
		dc.b 8,3
		dc.b 16,3
		dc.b 24,3
		dc.b 0,3
		even
		zoneanimdecl -1,Art_MMZ2Animated+56*32,ArtTile_MMZ2_Present_Anim3,4,16
		dc.b 16,4
		dc.b 32,4
		dc.b 48,4
		dc.b 0,4
		even
		zoneanimdecl -1,Art_MMZ2Animated+120*32,ArtTile_MMZ2_Present_Anim4,7,4
		dc.b 4,7
		dc.b 8,7
		dc.b 12,7
		dc.b 16,7
		dc.b 20,7
		dc.b 24,7
		dc.b 0,7
		even
		zoneanimdecl -1,Art_MMZ2Animated+148*32,ArtTile_MMZ2_Present_Anim5,6,4
		dc.b 4,4
		dc.b 8,4
		dc.b 12,4
		dc.b 16,4
		dc.b 20,4
		dc.b 0,4
		even
		zoneanimend

AnimCue_MMZ2_GoodFuture:	zoneanimstart
		zoneanimdecl -1,Art_MMZ2Animated+172*32,ArtTile_MMZ2_GoodFuture_Anim1,4,8
		dc.b 8,6
		dc.b 16,6
		dc.b 8,6
		dc.b 0,6
		even
		zoneanimdecl -1,Art_MMZ2Animated+196*32,ArtTile_MMZ2_GoodFuture_Anim2,4,8
		dc.b 8,3
		dc.b 16,3
		dc.b 24,3
		dc.b 0,3
		even
		zoneanimdecl -1,Art_MMZ2Animated+228*32,ArtTile_MMZ2_GoodFuture_Anim3,4,16
		dc.b 16,4
		dc.b 32,4
		dc.b 48,4
		dc.b 0,4
		even
		zoneanimdecl -1,Art_MMZ2Animated+148*32,ArtTile_MMZ2_GoodFuture_Anim4,6,4
		dc.b 4,4
		dc.b 8,4
		dc.b 12,4
		dc.b 16,4
		dc.b 20,4
		dc.b 0,4
		even
		zoneanimend

AnimCue_MMZ2_BadFuture:	zoneanimstart
		zoneanimdecl -1,Art_MMZ2Animated+0*32,ArtTile_MMZ2_BadFuture_Anim1,4,8
		dc.b 8,6
		dc.b 16,6
		dc.b 8,6
		dc.b 0,6
		even
		zoneanimdecl -1,Art_MMZ2Animated+24*32,ArtTile_MMZ2_BadFuture_Anim2,4,8
		dc.b 8,3
		dc.b 16,3
		dc.b 24,3
		dc.b 0,3
		even
		zoneanimdecl -1,Art_MMZ2Animated+56*32,ArtTile_MMZ2_BadFuture_Anim3,4,16
		dc.b 16,4
		dc.b 32,4
		dc.b 48,4
		dc.b 0,4
		even
		zoneanimdecl -1,Art_MMZ2Animated+120*32,ArtTile_MMZ2_BadFuture_Anim4,7,4
		dc.b 4,7
		dc.b 8,7
		dc.b 12,7
		dc.b 16,7
		dc.b 20,7
		dc.b 24,7
		dc.b 0,7
		even
		zoneanimdecl -1,Art_MMZ2Animated+148*32,ArtTile_MMZ2_BadFuture_Anim5,6,4
		dc.b 4,4
		dc.b 8,4
		dc.b 12,4
		dc.b 16,4
		dc.b 20,4
		dc.b 0,4
		even
		zoneanimend

AnimCue_MMZ2_Past:	dc.w -1

MMZ2_PalPresent:
		dc.w 5
		dc.w v_palette+$26*2,2
		dc.l .cycle0
		dc.w v_palette+$27*2,2
		dc.l .cycle1
		dc.w v_palette+$28*2,2
		dc.l .cycle2
		dc.w v_palette+$31*2,11
		dc.l .cycle3
		dc.w v_palette+$32*2,11
		dc.l .cycle4
		dc.w v_palette+$33*2,11
		dc.l .cycle5
.cycle0:
		dc.b 4,0
		dc.w $404
		dc.b 4,0
		dc.w $808
		dc.b 4,0
		dc.w $E0E
.cycle1:
		dc.b 4,0
		dc.w $E0E
		dc.b 4,0
		dc.w $404
		dc.b 4,0
		dc.w $808
.cycle2:
		dc.b 4,0
		dc.w $808
		dc.b 4,0
		dc.w $E0E
		dc.b 4,0
		dc.w $404
.cycle3:
		dc.b 3,0
		dc.w $E60
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $E60
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 60,0
		dc.w $000
.cycle4:
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $E60
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $E60
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 60,0
		dc.w $000
.cycle5:
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $E60
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $E60
		dc.b 60,0
		dc.w $000

MMZ2_PalPast:
		dc.w 4
		dc.w v_palette+$26*2,2
		dc.l .cycle0
		dc.w v_palette+$27*2,2
		dc.l .cycle1
		dc.w v_palette+$28*2,2
		dc.l .cycle2
		dc.w v_palette+$3E*2,7
		dc.l .cycle3
		dc.w v_palette+$3F*2,1
		dc.l .cycle4
.cycle0:
		dc.b 4,0
		dc.w $22A
		dc.b 4,0
		dc.w $46C
		dc.b 4,0
		dc.w $6AE
.cycle1:
		dc.b 4,0
		dc.w $6AE
		dc.b 4,0
		dc.w $22A
		dc.b 4,0
		dc.w $46C
.cycle2:
		dc.b 4,0
		dc.w $46C
		dc.b 4,0
		dc.w $6AE
		dc.b 4,0
		dc.w $22A
.cycle3:
		dc.b 99,0
		dc.w $CC0
		dc.b 2,0
		dc.w $EEE
		dc.b 2,0
		dc.w $CC0
		dc.b 2,0
		dc.w $EEE
		dc.b 2,0
		dc.w $000
		dc.b 2,0
		dc.w $EEE
		dc.b 2,0
		dc.w $000
		dc.b 2,0
		dc.w $EEE
.cycle4:
		dc.b 15,0
		dc.w $0E0
		dc.b 15,0
		dc.w $0EE

MMZ2_PalGoodFuture:
		dc.w 3
		dc.w v_palette+$26*2,2
		dc.l .cycle0
		dc.w v_palette+$27*2,2
		dc.l .cycle1
		dc.w v_palette+$28*2,2
		dc.l .cycle2
		dc.w v_palette+$31*2,5
		dc.l .cycle3
.cycle0:
		dc.b 4,0
		dc.w $A60
		dc.b 4,0
		dc.w $CA0
		dc.b 4,0
		dc.w $EE6
.cycle1:
		dc.b 4,0
		dc.w $EE6
		dc.b 4,0
		dc.w $A60
		dc.b 4,0
		dc.w $CA0
.cycle2:
		dc.b 4,0
		dc.w $CA0
		dc.b 4,0
		dc.w $EE6
		dc.b 4,0
		dc.w $A60
.cycle3:
		dc.b 2,0
		dc.w $0EE
		dc.b 2,0
		dc.w $EE0
		dc.b 22,0
		dc.w $0EE
		dc.b 2,0
		dc.w $EE0
		dc.b 66,0
		dc.w $000
		dc.b 2,0
		dc.w $0EE

MMZ2_PalBadFuture:
		dc.w 5
		dc.w v_palette+$26*2,2
		dc.l .cycle0
		dc.w v_palette+$27*2,2
		dc.l .cycle1
		dc.w v_palette+$28*2,2
		dc.l .cycle2
		dc.w v_palette+$31*2,3
		dc.l .cycle3
		dc.w v_palette+$32*2,4
		dc.l .cycle4
		dc.w v_palette+$33*2,4
		dc.l .cycle5
.cycle0:
		dc.b 4,0
		dc.w $02A
		dc.b 4,0
		dc.w $04C
		dc.b 4,0
		dc.w $0AE
.cycle1:
		dc.b 4,0
		dc.w $0AE
		dc.b 4,0
		dc.w $02A
		dc.b 4,0
		dc.w $04C
.cycle2:
		dc.b 4,0
		dc.w $04C
		dc.b 4,0
		dc.w $0AE
		dc.b 4,0
		dc.w $02A
.cycle3:
		dc.b 3,0
		dc.w $0EE
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $0EE
		dc.b 84,0
		dc.w $000
.cycle4:
		dc.b 12,0
		dc.w $000
		dc.b 3,0
		dc.w $0EE
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $0EE
		dc.b 72,0
		dc.w $000
.cycle5:
		dc.b 24,0
		dc.w $000
		dc.b 3,0
		dc.w $0EE
		dc.b 3,0
		dc.w $000
		dc.b 3,0
		dc.w $0EE
		dc.b 60,0
		dc.w $000
