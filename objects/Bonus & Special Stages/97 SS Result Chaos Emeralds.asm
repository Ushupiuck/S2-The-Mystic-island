; ---------------------------------------------------------------------------
; Object 97 - chaos emeralds from the special stage results screen
; ---------------------------------------------------------------------------

ChaosEmeralds:
		; S3&K-style constructor/direct handlers. Only held emeralds get SSTs;
		; their shared blink skips the draw queue entirely on hidden frames.
		movea.l	a0,a1
		lea	SSRC_PosData(pc),a2
		moveq	#0,d2
		moveq	#0,d1
		move.b	(v_emeralds).w,d1 ; d1 is number of emeralds
		subq.b	#1,d1		; subtract 1 from d1
		bcs.w	DeleteObject	; if you have 0	emeralds, branch

SSRC_Loop:
		move.l	#SSRC_Flash,code(a1)
		lea	(v_emldlist).w,a3 ; check which emeralds you have
		move.b	(a3,d2.w),d3
		move.b	d3,obFrame(a1)
		moveq	#0,d4
		move.b	d3,d4
		lsl.w	#2,d4
		move.l	(a2,d4.w),obX(a1)	; screen X/Y pair for this color
		addq.b	#1,d2
		move.l	#Map_SSRE,obMap(a1)
		move.b	#Map_SSRE_height,height_pixels(a1)
		move.w	#make_art_tile(ArtTile_SS_Results_Emeralds,0,1),obGfx(a1)
		sf	obRender(a1)
		lea	object_size(a1),a1	; next object
		dbf	d1,SSRC_Loop	; loop for d1 number of	emeralds

SSRC_Flash:
		btst	#0,(Vint_runcount+3).w
		beq.s	.return
		bra.w	DisplaySprite
.return:
		rts
; ---------------------------------------------------------------------------
; Screen X/Y pairs indexed by emerald ID. S3 order: red/blue/yellow/green,
; then purple/gray/cyan, centered below the heading and above the score.
; ---------------------------------------------------------------------------
SSRC_PosData:
		dc.w $110,$E4	; blue
		dc.w $130,$E4	; yellow
		dc.w $100,$FC	; purple
		dc.w $150,$E4	; green
		dc.w $F0,$E4	; red
		dc.w $120,$FC	; gray
		dc.w $140,$FC	; cyan
