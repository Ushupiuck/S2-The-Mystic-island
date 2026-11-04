; ---------------------------------------------------------------------------
; Object 3C - smashable wall (GHZ, SLZ, EHZ)
; ---------------------------------------------------------------------------

Obj3C:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Smash_Index(pc,d0.w),d1
		jsr	Smash_Index(pc,d1.w)
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------
Smash_Index:	dc.w Smash_Main-Smash_Index
		dc.w Smash_Solid-Smash_Index
		dc.w Smash_FragMove-Smash_Index

smash_speed	= objoff_34		; primary player's pre-collision horizontal speed
smash_speed2	= objoff_36		; companion's pre-collision horizontal speed
; ---------------------------------------------------------------------------
Obj3C_FragSpdRight:
		dc.w  $400,-$500
		dc.w  $600,-$100
		dc.w  $600, $100
		dc.w  $400, $500
		dc.w  $600,-$600
		dc.w  $800,-$200
		dc.w  $800, $200
		dc.w  $600, $600
Obj3C_FragSpdLeft:
		dc.w -$600,-$600
		dc.w -$800,-$200
		dc.w -$800, $200
		dc.w -$600, $600
		dc.w -$400,-$500
		dc.w -$600,-$100
		dc.w -$600, $100
		dc.w -$400, $500
; ---------------------------------------------------------------------------

Smash_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj3C,obMap(a0)
		move.b	#Map_Obj3C_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_GHZ_SLZ_Smashable_Wall,2,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.b	#sprite_bound($10,Map_Obj3C_width),obActWid(a0)
		move.w	#$200,obPriority(a0)
		move.w	obSubtype(a0),d0
		move.b	d0,obFrame(a0)
		cmpi.b	#id_EHZ,(Current_Zone).w
		bne.s	.art_ready
		move.w	#make_art_tile(ArtTile_Level,2,0),obGfx(a0)
		addq.b	#3,obFrame(a0)	; EHZ variants in the same mapping family
.art_ready:

Smash_Solid:	; Routine 2
		move.w	(v_player+obVelX).w,smash_speed(a0)
		move.w	(v_player2+obVelX).w,smash_speed2(a0)
		moveq	#$1B,d1
		moveq	#$20,d2
		moveq	#$20,d3
		move.w	obX(a0),d4
		bsr.w	SolidObject
		lea	(v_player).w,a1
		btst	#p1_pushing_bit,obStatus(a0)
		beq.s	.companion
		move.w	smash_speed(a0),d0
		bsr.s	.chkroll
.companion:
		lea	(v_player2).w,a1
		btst	#p2_pushing_bit,obStatus(a0)
		beq.s	.donothing
		move.w	smash_speed2(a0),d0
		bsr.s	.chkroll
.donothing:
		rts
; ---------------------------------------------------------------------------

.chkroll:
		cmpi.b	#AniIDSonAni_Roll,obAnim(a1)
		bne.s	.donothing
		move.w	d0,d2		; preserve this actor's signed impact speed
		bpl.s	.chkspeed
		neg.w	d0

.chkspeed:
		cmpi.w	#$480,d0	; is this actor's speed $480 or higher?
		bcs.s	.donothing	; if not, branch
		move.w	d2,obVelX(a1)
		addq.w	#4,obX(a1)
		lea	Obj3C_FragSpdRight(pc),a4 ; use fragments that move right
		move.w	obX(a0),d0
		cmp.w	obX(a1),d0	; is this actor to the right of the block?
		bcs.s	.smash		; if yes, branch
		subq.w	#8,obX(a1)
		lea	Obj3C_FragSpdLeft(pc),a4 ; use fragments that move left

.smash:
		move.w	obVelX(a1),obInertia(a1)
		andi.b	#~pushing_mask,obStatus(a0)
		bclr	#status.player.pushing,obStatus(a1)
		jsr	(SMZ_ReleaseRiders).l	; the other player may be standing on this wall
		moveq	#7,d1		; load 8 fragments
		move.w	#$70,d2
		bsr.s	SmashObject

Smash_FragMove:	; Routine 4
		addq.l	#4,sp
		bsr.w	ObjectMove
		addi.w	#$70,obVelY(a0) ; make fragment fall faster
		tst.b	obRender(a0)
		bpl.w	UnloadObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
