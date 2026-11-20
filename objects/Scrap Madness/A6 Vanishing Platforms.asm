; $A6 vanishing platforms. A frame clock controls the phases while the
; shared platform service manages animation, top support and group ownership.
vanish_visible_time:	equ objoff_40	; classic single: duration minus one
vanish_sync_offset:	equ objoff_42
vanish_sync_mask:	equ objoff_44

SMZ_VanishPlatform:
		move.w	obSubtype(a0),d0
		btst	#8,d0
		bne.w	MMZ_VanP_Init
		cmpi.b	#id_MMZ,(v_zone).w	; editor byte presets
		beq.w	MMZ_VanP_Init
		moveq	#0,d6
		jsr	(PlatformGroup_Preflight).l
		movea.l	a0,a1
		lea	Vanish_ClassicSync(pc),a4
		lea	Vanish_ClassicProfile(pc),a5
		jsr	(PlatformGroup_InitMember).l
		move.l	#Vanish_ClassicFade,platgroup_script(a0)

		move.w	obSubtype(a0),d0
		andi.w	#$F,d0
		addq.w	#1,d0
		lsl.w	#7,d0
		move.w	d0,d1
		subq.w	#1,d0
		move.w	d0,platgroup_timer(a0)
		move.w	d0,vanish_visible_time(a0)

		move.w	obSubtype(a0),d0
		andi.w	#$F0,d0
		addi.w	#$80,d1
		mulu.w	d1,d0
		lsr.l	#8,d0
		move.w	d0,vanish_sync_offset(a0)
		subq.w	#1,d1
		move.w	d1,vanish_sync_mask(a0)
		jmp	(PlatformGroup_Run).l

Vanish_ClassicSync:
		move.w	(v_framecount).w,d0
		sub.w	vanish_sync_offset(a0),d0
		and.w	vanish_sync_mask(a0),d0
		jne	(PlatformGroup_Animate).l
		move.l	#Vanish_ClassicCycle,platgroup_state(a0)
Vanish_ClassicCycle:
		subq.w	#1,platgroup_timer(a0)
		bpl.s	.animate
		move.w	#$80-1,platgroup_timer(a0)
		lea	Vanish_ClassicAppear(pc),a1
		bchg	#0,obAnim(a0)
		beq.s	.sequence
		move.w	vanish_visible_time(a0),platgroup_timer(a0)
		lea	Vanish_ClassicFade(pc),a1
.sequence:
		move.l	a1,platgroup_script(a0)
		clr.b	platgroup_dwell(a0)
.animate:
		jsr	(PlatformGroup_Animate).l
		cmpi.b	#2,d0
		jhs	(ReleaseObjectRiders).l
		move.w	obX(a0),d4
		jmp	(PlatformGroup_TopSupport).l

Vanish_ClassicProfile:
		dc.l Map_SMZ_VanP
		dc.w ArtTile_SMZ_Atlas,$200
		dc.b Map_SMZ_VanP_height,16,9,16
Vanish_ClassicFade:
		dc.b 7,0,7,1,7,2,$FF,3
Vanish_ClassicAppear:
		dc.b 7,3,7,2,7,1,$FF,0

Map_SMZ_VanP:	binclude "mappings/sprite/SMZ VanP.bin"
		even

; Grouped placements start with staggered timers, then share the ordinary
; timed solid/animation states with fixed spinning platforms.
MMZ_VanP_Init:
		move.w	obSubtype(a0),d6
		andi.w	#3,d6
		cmpi.w	#2,d6
		bls.s	.variant
		moveq	#0,d6
.variant:
		move.w	d6,d0
		add.w	d0,d0
		lea	MMZ_VanP_Groups(pc),a2
		adda.w	(a2,d0.w),a2
		lea	MMZ_VanP_Delay(pc),a4
		lea	Vanish_TimedProfile(pc),a5
		jsr	(PlatformGroup_Create).l
		bne.s	.return
		; Birth is invisible for each member. Configure its repeating sequence
		; once; the common timed states run the animation and support.
		lea	platgroup_members(a0),a2
		moveq	#0,d5
		move.b	platgroup_count(a0),d5
		movea.l	a0,a1
.blank:
		move.b	#6,obFrame(a1)
		move.l	#MMZ_VanP_Disappear,platgroup_sequence(a1)
		dbf	d5,.next
		jmp	(PlatformGroup_Draw).l
.next:
		movea.w	(a2)+,a1
		bra.s	.blank
.return:
		rts

MMZ_VanP_Delay:
		subq.w	#1,platgroup_timer(a0)
		bne.s	.return
		move.l	#PlatformGroup_TimedTransition,platgroup_state(a0)
		move.l	#MMZ_VanP_Appear,platgroup_script(a0)
.return:
		rts

Vanish_TimedProfile:
		dc.l Map_MMZ_Vanish
		dc.w ArtTile_MMZ_Atlas,$180
		dc.b Map_MMZ_Vanish_height,16,16,16

; timer, relative X/Y, phase. Only the root owns the authored placement.
MMZ_VanP_Groups:
		dc.w .one-MMZ_VanP_Groups,.two-MMZ_VanP_Groups,.three-MMZ_VanP_Groups
.one:	dc.w 60,0,0,0
.two:	dc.w 60,0,0,0,60,32,0,0
.three:	dc.w 90,0,0,0,180,32,16,0,270,64,32,0

MMZ_VanP_Appear:
		dc.b 4,5
		dc.b 2,4
		dc.b 4,5
		dc.b 2,4
		dc.b 4,3
		dc.b 2,2
		dc.b 4,3
		dc.b 2,2
		dc.b 4,1
		dc.b 2,7
		dc.b 4,1
		dc.b 0,0
MMZ_VanP_Disappear:
		dc.b 4,1
		dc.b 2,7
		dc.b 4,1
		dc.b 2,2
		dc.b 4,3
		dc.b 2,2
		dc.b 4,3
		dc.b 2,4
		dc.b 4,5
		dc.b 2,4
		dc.b 4,5
		dc.b 59,6
		dc.b 4,5
		dc.b 2,4
		dc.b 4,5
		dc.b 2,4
		dc.b 4,3
		dc.b 2,2
		dc.b 4,3
		dc.b 2,2
		dc.b 4,1
		dc.b 2,7
		dc.b 4,1
		dc.b 0,0
		even
Map_MMZ_Vanish:	binclude "mappings/sprite/MMZ Vanish.bin"
		even
