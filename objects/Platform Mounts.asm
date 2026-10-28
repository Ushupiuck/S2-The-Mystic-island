; ---------------------------------------------------------------------------
; Optional Obj17/18 payloads (MD CPU). Placement metadata, never subtype bits.
; 0 none; 1-16 switch channels; 17-20 spring pairs RR/RY/YR/YY;
; 21 three S1 spikes; 22-33 monitor types 0-B. 34-63 reserved.
; The body owns movement/lifetime. Children retain ordinary code pointers for
; touch-response identity; their manager entry only checks ownership. The body
; invokes their behavior once after positioning, independent of SST order.
; ---------------------------------------------------------------------------
PlatformMount_settings = obWidth       ; byte: unused collision radius on Obj17/18
PlatformMount_head = obAngle           ; word: unused angle on Obj18 only
PlatformMount_count = obAniFrame       ; byte: number of mounted children
PlatformMount_standing = obAnim        ; byte: riders supported by payloads
PlatformMount_flags = obPrevAni        ; byte: bit 0 state loaded, bit 1 monitor used
Mount_parent = objoff_44               ; word: owning Obj18
Mount_next = objoff_46                 ; word: next child, at most two total
Mount_x = objoff_48                    ; word: local X
Mount_y = objoff_4A                    ; word: local Y, from physical platform top
Mount_kind = objoff_4C                 ; word: 0 spring, 1 spikes, 2 monitor, 3 button
PlatformMount_Count = 34

; MD placement loader: a0 placement, a1 SST. Preserve its free-slot counter d0.
PlatformMount_LoadSettings:
		cmpi.l	#SwingingPtfm,code(a1)
		beq.s	.platform
		cmpi.l	#Obj18,code(a1)
		beq.s	.platform
		move.l	code(a1),d2
		cmpi.l	#SwingingPtfm_ArtTerrain0,d2
		blo.s	.return
		cmpi.l	#SwingingPtfm_ArtEnd,d2
		bhs.s	.return
.platform:
		move.w	omY(a0),d2
		andi.w	#ObjectLayout_MountHighMask,d2
		lsr.w	#7,d2
		move.b	omTimeZones(a0),d1
		andi.w	#ObjectLayout_MountLowMask,d1
		or.b	d1,d2
		move.b	d2,PlatformMount_settings(a1)
.return:
		rts
; Mode 1 reply carries six mount bits above the two ordinary flip bits.
PlatformMount_ApplyReply:
		cmpi.l	#SwingingPtfm,code(a1)
		beq.s	.platform
		cmpi.l	#Obj18,code(a1)
		beq.s	.platform
		move.l	code(a1),d2
		cmpi.l	#SwingingPtfm_ArtTerrain0,d2
		blo.s	.return
		cmpi.l	#SwingingPtfm_ArtEnd,d2
		bhs.s	.return
.platform:
		lsr.b	#2,d1
		move.b	d1,PlatformMount_settings(a1)
.return:
		rts

PlatformMount_Codes:
		dc.l Obj41,Obj36,Obj26,SMZ_Button
PlatformMount_Behaviors:
		dc.l Obj41_Behavior,Obj36_Behavior,Obj26_Behavior,SMZ_Button_Behavior

; a0 body, a1 child -> Z iff this still is one of our ordinary payload objects.
PlatformMount_CheckChild:
		move.w	a0,d0
		cmp.w	Mount_parent(a1),d0
		bne.s	.return
		move.w	Mount_kind(a1),d0
		cmpi.w	#3,d0
		bhi.s	.invalid
		lsl.w	#2,d0
		lea	PlatformMount_Codes(pc),a2
		move.l	(a2,d0.w),d0
		cmp.l	code(a1),d0
.return:
		rts
.invalid:
		moveq	#1,d0
		rts

; Child's ordinary manager entry. Real behavior is parent-driven exactly once.
PlatformMount_Child:
		movea.w	Mount_parent(a0),a1
		cmpi.l	#Plat_Top,code(a1)
		beq.s	.member
		cmpi.l	#Plat_FallingIntangible,code(a1)
		beq.s	.member
		cmpi.l	#Platform_SuspendedBody,code(a1)
		bne.s	.orphan
.member:
		move.w	a0,d0
		cmp.w	PlatformMount_head(a1),d0
		beq.s	.return
		movea.w	PlatformMount_head(a1),a2
		move.w	a2,d1
		beq.s	.orphan
		move.w	a1,d1
		cmp.w	Mount_parent(a2),d1
		bne.s	.orphan
		cmp.w	Mount_next(a2),d0
		beq.s	.return
.orphan:
		bra.w	PlatformMount_DeleteChild
.return:
		rts

; Supported objects branch here only when their ordinary cull would unload.
PlatformMount_CullChild:
		tst.w	Mount_parent(a0)
		beq.s	.unload
		jmp	(DisplaySprite).l
.unload:
		jmp	(UnloadObject).l

; a0 body -> real placement handle in d0 (the suspension owns placed swings).
PlatformMount_Handle:
		move.w	respawn_addr(a0),d0
		bne.s	.return
		tst.w	Plat_parent(a0)
		beq.s	.return
		movea.w	Plat_parent(a0),a1
		cmpi.l	#SwingingPtfm,code(a1)
		bne.s	.return
		move.w	respawn_addr(a1),d0
.return:
		tst.w	d0
		rts

PlatformMount_Update:
		moveq	#0,d0
		move.b	PlatformMount_settings(a0),d0
		beq.s	.inactive
		cmpi.w	#PlatformMount_Count,d0
		blo.s	.active
.inactive:
		rts
.active:
		move.l	d7,-(sp)
		btst	#1,Plat_flags(a0)
		beq.s	.live
		bsr.w	PlatformMount_Delete
		clr.b	PlatformMount_settings(a0)
		bra.w	.return
.live:
		btst	#0,PlatformMount_flags(a0)
		bne.s	.spawn
		bset	#0,PlatformMount_flags(a0)
		bsr.s	PlatformMount_Handle
		beq.s	.spawn
		jsr	(Object_RespawnRead).l
		andi.b	#2,d0
		or.b	d0,PlatformMount_flags(a0)
.spawn:
		moveq	#1,d6
		move.b	PlatformMount_settings(a0),d0
		subi.b	#17,d0
		cmpi.b	#3,d0
		bhi.s	.count
		moveq	#2,d6
.count:
		cmp.b	PlatformMount_count(a0),d6
		bls.s	.update
		bsr.w	PlatformMount_Spawn
		bcc.s	.count
.update:
		clr.b	PlatformMount_standing(a0)
		movea.w	PlatformMount_head(a0),a1
		moveq	#1,d7
.loop:
		move.w	a1,d0
		beq.w	.return
		bsr.w	PlatformMount_CheckChild
		bne.w	.lost
		move.w	Mount_next(a1),-(sp)
		movem.l	d7/a0,-(sp)
		movea.l	a0,a2
		movea.l	a1,a0
		move.w	obX(a0),d4
		move.w	obY(a0),d5
		move.l	obX(a2),obX(a0)
		move.w	Mount_x(a0),d0
		add.w	d0,obX(a0)
		move.l	obY(a2),obY(a0)
		moveq	#0,d0
		move.b	obHeight(a2),d0
		sub.w	d0,obY(a0)
		move.w	Mount_y(a0),d0
		add.w	d0,obY(a0)
		sub.w	obX(a0),d4
		neg.w	d4
		sub.w	obY(a0),d5
		neg.w	d5
		lea	(v_player).w,a1
		moveq	#3,d6
		bsr.w	PlatformMount_Rider
		lea	(v_player2).w,a1
		moveq	#4,d6
		bsr.w	PlatformMount_Rider
		clr.w	obVelX(a0)
		clr.w	obVelY(a0)
		move.w	Mount_kind(a0),d0
		cmpi.w	#1,d0
		bne.s	.button
		move.w	obX(a0),spikes_base_x_pos(a0)
		move.w	obY(a0),spikes_base_y_pos(a0)
.button:
		cmpi.w	#3,d0
		bne.s	.run
		tst.b	obRoutine(a0)
		bne.s	.run
		subq.w	#3,obY(a0)		; button constructor's original placement adjustment
.run:
		lsl.w	#2,d0
		lea	PlatformMount_Behaviors(pc),a1
		movea.l	(a1,d0.w),a1
		jsr	(a1)
		movea.l	a0,a2
		movem.l	(sp)+,d7/a0
		movea.l	a2,a1
		jsr	(Touch_RegisterEarlierObject).l
		move.b	obStatus(a2),d0
		andi.b	#$18,d0
		or.b	d0,PlatformMount_standing(a0)
		cmpi.w	#2,Mount_kind(a2)
		bne.s	.next
		btst	#1,PlatformMount_flags(a0)
		bne.s	.next
		cmpi.b	#6,obRoutine(a2)
		blo.s	.next
		bset	#1,PlatformMount_flags(a0)
		bsr.w	PlatformMount_Handle
		beq.s	.next
		jsr	(Object_RespawnMountConsume).l
.next:
		movea.w	(sp)+,a1
		dbf	d7,.loop
.return:
		move.l	(sp)+,d7
		rts
.lost:
		; Do not follow a reused SST's next pointer. Its surviving sibling retires
		; through the reciprocal-membership check; allocation retries next update.
		clr.w	PlatformMount_head(a0)
		clr.b	PlatformMount_count(a0)
		move.l	(sp)+,d7
		rts

; Transport players standing on the payload, not just those on the base body.
PlatformMount_Rider:
		btst	d6,obStatus(a0)
		beq.s	.return
		btst	#3,obStatus(a1)
		beq.s	.return
		moveq	#0,d0
		move.b	standonobject(a1),d0
		mulu.w	#object_size,d0
		addi.w	#v_objspace,d0
		move.w	a0,d1
		cmp.w	d1,d0
		bne.s	.return
		add.w	d4,obX(a1)
		add.w	d5,obY(a1)
.return:
		rts

PlatformMount_Spawn:
		jsr	(FindFreeObj).l
		bne.w	.full
		moveq	#0,d0
		move.b	PlatformMount_settings(a0),d0
		moveq	#3,d2			; button
		moveq	#0,d3			; local X
		moveq	#-5,d4			; local Y above the platform collision top
		subq.w	#1,d0
		cmpi.w	#16,d0
		blo.s	.recipe
		subi.w	#16,d0
		cmpi.w	#4,d0
		bhs.s	.spikes
		moveq	#0,d2
		moveq	#-16,d3
		moveq	#-8,d4
		tst.b	PlatformMount_count(a0)
		bne.s	.right
		lsr.w	#1,d0
		bra.s	.colour
.right:
		neg.w	d3
.colour:
		andi.w	#1,d0
		add.w	d0,d0
		bra.s	.recipe
.spikes:
		subq.w	#4,d0
		bne.s	.monitor
		moveq	#1,d2
		move.w	#$80,d0
		moveq	#-16,d4
		bra.s	.recipe
.monitor:
		subq.w	#1,d0
		moveq	#2,d2
		moveq	#-15,d4
.recipe:
		move.w	d0,obSubtype(a1)
		move.w	d2,Mount_kind(a1)
		lsl.w	#2,d2
		lea	PlatformMount_Codes(pc),a2
		move.l	(a2,d2.w),code(a1)
		move.w	d3,Mount_x(a1)
		move.w	d4,Mount_y(a1)
		move.w	a0,Mount_parent(a1)
		move.w	PlatformMount_head(a0),Mount_next(a1)
		move.w	a1,PlatformMount_head(a0)
		addq.b	#1,PlatformMount_count(a0)
.return:
		andi.b	#$FE,ccr
		rts
.full:
		ori.b	#1,ccr
		rts

PlatformMount_Delete:
		move.l	d7,-(sp)
		movea.w	PlatformMount_head(a0),a1
		clr.w	PlatformMount_head(a0)
		clr.b	PlatformMount_count(a0)
		clr.b	PlatformMount_standing(a0)
		moveq	#1,d7
.loop:
		move.w	a1,d0
		beq.s	.return
		bsr.w	PlatformMount_CheckChild
		bne.s	.return
		move.w	Mount_next(a1),-(sp)
		movem.l	d7/a0,-(sp)
		movea.l	a1,a0
		bsr.s	PlatformMount_DeleteChild
		movem.l	(sp)+,d7/a0
		movea.w	(sp)+,a1
		dbf	d7,.loop
.return:
		move.l	(sp)+,d7
		rts

; a0 child. Retiring a held momentary button must also release its channel.
PlatformMount_DeleteChild:
		cmpi.w	#3,Mount_kind(a0)
		bne.s	.release
		cmpi.l	#SMZ_Button,code(a0)
		bne.s	.release
		move.w	obSubtype(a0),d0
		andi.w	#15,d0
		lea	(f_switch).w,a1
		bclr	#0,(a1,d0.w)
.release:
		jsr	(SMZ_ReleaseRiders).l
		jmp	(DeleteObject).l
