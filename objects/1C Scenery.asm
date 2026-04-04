; ---------------------------------------------------------------------------
; Object 1C - scenery (GHZ/HTZ bridge stump, SLZ lava thrower, HPZ Bridge)
; ---------------------------------------------------------------------------

Obj1C:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Scen_Index(pc,d0.w),d1
		jmp	Scen_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Scen_Index:	dc.w Scen_Init-Scen_Index		; 0
		dc.w Scen_Display-Scen_Index		; 2
		dc.w Scen_Animate-Scen_Index		; 4
; ---------------------------------------------------------------------------
Scen_Conf:	; Organized in the following format:
	;	dc.l Mappings
	;	dc.w Art
	;	dc.b obFrame, obActWid, obPriority (the last two bytes are a word)
; ---------------------------------------------------------------------------
		; 0
		dc.l Map_HPZ_Bridge		; HPZ Pulsing Bridge
		dc.w make_art_tile(ArtTile_HPZ_Bridge,3,0)
		dc.b	3,	4,	0,	$80
		; 1
		dc.l Map_HPZ_Orb		; HPZ Pulsing Orb
		dc.w make_art_tile($35A,3,1)
		dc.b	0,	$10,	0,	$80
		; 2
		dc.l Map_EHZ_Bridge			; EHZ Wooden Stake & Bridge
		dc.w make_art_tile($3C6,2,0)
		dc.b	1,	4,	0,	$80
		; 3
		dc.l Map_GHZ_Bridge		; GHZ Wooden Bridge & Stake (Yes, really. They're inverted)
		dc.w make_art_tile($4C6,2,0)
		dc.b	1,	$10,	0,	$80
		; 4
		dc.l Map_Obj16			; HTZ Zipline
		dc.w make_art_tile(ArtTile_HtzZipline,2,0)
		dc.b	1,	8,	2,	0
		; 5
		dc.l Map_Obj16			; HTZ Zipline (filler)
		dc.w make_art_tile(ArtTile_HtzZipline,2,0)
		dc.b	2,	8,	2,	0
		; 6
		dc.l Map_Obj16			; HTZ Zipline (filler)
		dc.w make_art_tile(ArtTile_HtzZipline,2,0)
		dc.b	2,	8,	2,	0
; ---------------------------------------------------------------------------

Scen_Init:	; FromSubtype
		addq.b	#2,obRoutine(a0)
		move.b	obSubtype(a0),d0	; Use the low nibble to determine which configuration to load
		andi.w	#$F,d0
		move.w	d0,d1
		lsl.w	#3,d0
		add.w	d1,d0
		add.w	d1,d0
		lea	Scen_Conf(pc,d0.w),a1	; Done? Load the proper object
		move.l	(a1)+,obMap(a0)
		move.w	(a1)+,obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	(a1)+,obFrame(a0)
		move.b	(a1)+,obActWid(a0)
		move.w	(a1)+,obPriority(a0)
		move.b	obSubtype(a0),d0	; we gotta process subtype one more time!
		andi.w	#$F0,d0			; high nibble this time
		beq.s	Scen_Display		; if 0, don't bother. Otherwise keep going, we gotta animate
		addq.b	#2,obRoutine(a0)
		lsr.b	#4,d0
		subq.b	#1,d0
		move.b	d0,obAnim(a0)
		; fall through to the next subroutine
; ---------------------------------------------------------------------------
Scen_Animate:	lea	Ani_Scen(pc),a1
		bsr.w	AnimateSprite
Scen_Display:	out_of_range.w	DeleteObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
Ani_Scen:	dc.w byte_9494-Ani_Scen
		dc.w byte_949C-Ani_Scen
byte_9494:	dc.b   8,  3,  3,  4,  5,  5,  4,$FF
byte_949C:	dc.b   5,  0,  0,  0,  1,  2,  3,  3
		dc.b   2,  1,  2,  3,  3,  1,$FF
		even