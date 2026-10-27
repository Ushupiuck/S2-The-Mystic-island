; ---------------------------------------------------------------------------
; Object 26 - monitor
; ---------------------------------------------------------------------------

Obj26:
		tst.w	Mount_parent(a0)
		beq.s	Obj26_Behavior
		jmp	(PlatformMount_Child).l
Obj26_Behavior:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj26_Index(pc,d0.w),d1
		jmp	Obj26_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj26_Index:	dc.w loc_AE70-Obj26_Index	; 0
		dc.w loc_AED6-Obj26_Index	; 2
		dc.w loc_AFDC-Obj26_Index	; 4
		dc.w Mon_Animate-Obj26_Index	; 6
		dc.w loc_AFC4-Obj26_Index	; 8
; ---------------------------------------------------------------------------

loc_AE70:
		addq.b	#2,obRoutine(a0)
		move.b	#$E,obHeight(a0)
		move.b	#$E,obWidth(a0)
		move.l	#Map_Obj26,obMap(a0)
		move.b	#Map_Obj26_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_Monitor,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#v_player,obParent(a0)		; default collector for scripted/debug breakage
		move.w	#$180,obPriority(a0)
		move.b	#sprite_bound($F,Map_Obj26_width),obActWid(a0)
		move.w	respawn_addr(a0),d0
		beq.s	loc_AECA			; Debug/scripted monitors have no placement state
		jsr	(Object_RespawnRead).l
		btst	#0,d0
		beq.s	loc_AECA
		move.b	#8,obRoutine(a0)
		move.b	#$B,obFrame(a0)
		rts
; ---------------------------------------------------------------------------

loc_AECA:
		tst.w	Mount_parent(a0)
		beq.s	.live
		movea.w	Mount_parent(a0),a2
		btst	#1,PlatformMount_flags(a2)
		beq.s	.live
		move.b	#8,obRoutine(a0)
		move.b	#$B,obFrame(a0)
		rts
.live:
		move.b	#$46,obColType(a0)
		move.w	obSubtype(a0),d0
		move.b	d0,obAnim(a0)

loc_AED6:
		tst.b	ob2ndRout(a0)
		beq.s	Monitor_Solid
		bsr.w	ObjectMoveAndFall
		jsr	(ObjHitFloor).l
		bpl.s	Monitor_Solid
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		clr.b	ob2ndRout(a0)

; Sonic 2 final's per-character monitor solidity, with ball attacks enabled
; for both players. Standing and pushing use separate bits on the monitor.
Monitor_Solid:
		move.w	#$1A,d1
		move.w	#$F,d2
		move.w	#$10,d3
		move.w	obX(a0),d4
		lea	(v_player).w,a1
		moveq	#status.player.on_object,d6
		movem.l	d1-d4,-(sp)
		bsr.s	Monitor_SolidCharacter
		movem.l	(sp)+,d1-d4
		lea	(v_player2).w,a1
		moveq	#status.sidekick.on_object,d6
		bsr.s	Monitor_SolidCharacter
		bra.s	Mon_Animate

Monitor_SolidCharacter:
		tst.l	code(a1)
		beq.s	.return
		btst	d6,obStatus(a0)
		beq.s	.contact
		; A retained monitor must not snap a former rider back onto its top.
		; Both sides of the standing relationship must still name each other.
		btst	#status.player.on_object,obStatus(a1)
		beq.s	.stale
		moveq	#0,d0
		move.b	standonobject(a1),d0
		mulu.w	#object_size,d0
		addi.w	#v_objspace,d0
		move.w	a0,d5
		cmp.w	d5,d0
		beq.s	.standing
.stale:
		bclr	d6,obStatus(a0)
.contact:
		cmpi.b	#AniIDSonAni_Roll,obAnim(a1)
		beq.s	.return
		; A held charge is solid: it can land on a monitor without breaking it.
		; Releasing the charge switches to Roll, handled by TouchResponse.
		bra.w	SolidObject_cont
.standing:
		; Use the common standing/edge path, preserving this player's bit.
		bra.w	SolidObject_Always_SingleCharacter
.return:
		rts

Mon_Animate:
		lea	(Ani_obj26).l,a1
		bsr.w	AnimateSprite

loc_AFC4:
		out_of_range2	PlatformMount_CullChild
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

loc_AFDC:
		move.b	obStatus(a0),d0
		andi.b	#$28,d0
		beq.s	.partner
		andi.b	#$D7,(v_player+obStatus).w
		bset	#status.player.in_air,(v_player+obStatus).w
.partner:
		move.b	obStatus(a0),d0
		andi.b	#$50,d0
		beq.s	.spawn
		andi.b	#$D7,(v_player2+obStatus).w
		bset	#status.player.in_air,(v_player2+obStatus).w
.spawn:
		clr.b	obStatus(a0)
		addq.b	#2,obRoutine(a0)
		clr.b	obColType(a0)
		bsr.w	FindFreeObj
		bne.s	loc_B004
		move.l	#Obj29,code(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obAnim(a0),obAnim(a1)
		move.b	obRender(a0),obRender(a1)
		move.w	obParent(a0),obParent(a1)		; power-up must reach the player who broke this monitor

loc_B004:
		bsr.w	FindFreeObj
		bne.s	loc_B020
		move.l	#Explosion,code(a1)
		addq.b	#2,obRoutine(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)

loc_B020:
		move.w	respawn_addr(a0),d0
		beq.s	.no_state
		jsr	(Object_RespawnConsume).l
.no_state:
		move.b	#$A,obAnim(a0)
		bra.w	DisplaySprite
