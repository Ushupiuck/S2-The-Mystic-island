; ---------------------------------------------------------------------------
; Object 91 - Sonic and Tails from the title screen
; ---------------------------------------------------------------------------

TitleSonicTails:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	TSon_Index(pc,d0.w),d1
		jmp	TSon_Index(pc,d1.w)
; ===========================================================================
TSon_Index:	dc.w TSon_Main-TSon_Index
		dc.w TSon_Delay-TSon_Index
		dc.w TSon_Move-TSon_Index
		dc.w TSon_Animate-TSon_Index
; ===========================================================================

TSon_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.w	#$148,obScreenX(a0)	; this part of code loads Sonic on the Title Screen.
		move.w	#$C4,obScreenY(a0)	; position is fixed to screen
		move.l	#Map_TitleST,obMap(a0)
		move.w	#make_art_tile(ArtTile_Title_Sonic_And_Tails,2,0),obGfx(a0)
		move.w	#$80,obPriority(a0)
	;	move.b	#29,obDelayAni(a0)	; set time delay to 0.5 seconds
		tst.b	obFrame(a0)		; are we on frame 0?
		beq.s	TSon_Delay		; if so, skip.
		move.w	#$FC,obScreenX(a0)	; this part of code loads Tails on the Title Screen.
		move.w	#$CC,obScreenY(a0)
		move.w	#make_art_tile(ArtTile_Title_Sonic_And_Tails,1,0),obGfx(a0)

TSon_Delay:	; Routine 2
		bra.w	DisplaySprite
	; Dead code from Sonic 1, remove or comment out the branch above to use the original code.
	;	subq.b	#1,obDelayAni(a0)	; subtract 1 from time delay
	;	bpl.s	.wait			; if time remains, branch
	;	addq.b	#2,obRoutine(a0)	; go to next routine
	;	bra.w	DisplaySprite

.wait:
	;	rts
; ===========================================================================
; This is also dead code because the routine is never actually reached.
; Even if it did, the animation is long gone.

TSon_Move:	; Routine 4
	;	subq.w	#8,obScreenY(a0)	; move Sonic up
	;	cmpi.w	#$96,obScreenY(a0)	; has Sonic reached final position?
	;	bne.s	.display		; if not, branch
	;	addq.b	#2,obRoutine(a0)

.display:
	;	bra.w	DisplaySprite
; ===========================================================================
; In Sonic 1, this would've been where the Title Character animations take place.
; It appears they just removed the code for animating the object.
TSon_Animate:	; Routine 6
	;	lea	(Ani_TSon).l,a1
	;	bsr.w	AnimateSprite
	;	bra.w	DisplaySprite