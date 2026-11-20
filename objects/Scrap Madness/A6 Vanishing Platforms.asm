; $A6 vanishing platform. Each placement owns one surface. Its settings
; select the phase clock, mappings, and support window.
vanish_visible_time:	equ objoff_40	; classic single: duration minus one
vanish_sync_offset:	equ objoff_42
vanish_sync_mask:	equ objoff_44
vanish_contact:		equ objoff_4A	; frame limit, then drop on the last update

Vanish_UseVisibleTime = -2
Vanish_UntilLastFrame = -1
Vanish_ClassicContact = $0200		; frames 0 and 1 support riders
Vanish_DelayedContact = $0101		; frame 0 supports, then releases at timer 0

SMZ_VanishPlatform:
		move.w	obSubtype(a0),d0
		btst	#8,d0
		bne.w	Vanish_DelayedInit
		cmpi.b	#id_MMZ,(v_zone).w	; editor byte presets
		beq.w	Vanish_DelayedInit
		lea	Vanish_ClassicSync(pc),a4
		lea	Vanish_ClassicProfile(pc),a5
		bsr.w	Vanish_Init
		move.l	#Vanish_ClassicFade,platgroup_script(a0)
		move.w	#Vanish_PhaseClassicAppear-Vanish_Phases,platgroup_phase(a0)
		move.w	#Vanish_ClassicContact,vanish_contact(a0)

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

Vanish_Init:
		move.w	obX(a0),platgroup_x(a0)
		move.w	obY(a0),platgroup_y(a0)
		movea.l	a0,a1
		jmp	(PlatformGroup_InitMember).l

Vanish_ClassicSync:
		move.w	(v_framecount).w,d0
		sub.w	vanish_sync_offset(a0),d0
		and.w	vanish_sync_mask(a0),d0
		jne	(PlatformGroup_Animate).l
		move.l	#Vanish_Cycle,platgroup_state(a0)

; Each member runs the same cycle after its first clock/delay. Fixed holds
; count down in words; a transition can instead run until its script ends.
Vanish_Cycle:
		tst.w	platgroup_timer(a0)
		bmi.s	.wait_for_frame
		subq.w	#1,platgroup_timer(a0)
		bpl.s	.animate
		bra.s	.next_phase
.wait_for_frame:
		tst.l	platgroup_script(a0)
		bne.s	.animate
.next_phase:
		lea	Vanish_Phases(pc),a1
		adda.w	platgroup_phase(a0),a1
		move.w	(a1)+,d0
		cmpi.w	#Vanish_UseVisibleTime,d0
		bne.s	.set_phase
		move.w	vanish_visible_time(a0),d0
.set_phase:
		move.w	d0,platgroup_timer(a0)
		move.w	(a1)+,vanish_contact(a0)
		move.l	(a1)+,platgroup_script(a0)
		move.w	(a1),platgroup_phase(a0)
		clr.b	platgroup_dwell(a0)
.animate:
		move.b	obFrame(a0),d0
		tst.l	platgroup_script(a0)
		beq.s	.support
		jsr	(PlatformGroup_Animate).l
.support:
		cmp.b	vanish_contact(a0),d0
		bhs.s	.release
		move.w	obX(a0),d4
		jsr	(PlatformGroup_TopSupport).l
		tst.b	vanish_contact+1(a0)
		beq.s	.return
		tst.w	platgroup_timer(a0)
		bne.s	.return
.release:
		move.b	obStatus(a0),d0
		andi.b	#$18,d0
		beq.s	.return
		jmp	(ReleaseObjectRiders).l
.return:
		rts

; Phase timer (duration minus one), contact word, frame list, next phase.
Vanish_Phases:
Vanish_PhaseClassicAppear:
		dc.w $80-1,Vanish_ClassicContact
		dc.l Vanish_ClassicAppear
		dc.w Vanish_PhaseClassicFade-Vanish_Phases
Vanish_PhaseClassicFade:
		dc.w Vanish_UseVisibleTime,Vanish_ClassicContact
		dc.l Vanish_ClassicFade
		dc.w Vanish_PhaseClassicAppear-Vanish_Phases
Vanish_PhaseDelayedAppear:
		dc.w Vanish_UntilLastFrame,0
		dc.l Vanish_DelayedAppear
		dc.w Vanish_PhaseDelayedHold-Vanish_Phases
Vanish_PhaseDelayedHold:
		dc.w 120-1,Vanish_DelayedContact
		dc.l 0
		dc.w Vanish_PhaseDelayedDisappear-Vanish_Phases
Vanish_PhaseDelayedDisappear:
		dc.w Vanish_UntilLastFrame,0
		dc.l Vanish_DelayedDisappear
		dc.w Vanish_PhaseDelayedHold-Vanish_Phases

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

Vanish_DelayedInit:
		lea	Vanish_Cycle(pc),a4
		lea	Vanish_DelayedProfile(pc),a5
		bsr.w	Vanish_Init
		moveq	#0,d0
		move.b	obSubtype+1(a0),d0
		mulu.w	#30,d0			; first delay in half-second NTSC steps
		move.w	d0,platgroup_timer(a0)
		move.w	#Vanish_PhaseDelayedAppear-Vanish_Phases,platgroup_phase(a0)
		move.b	#6,obFrame(a0)
		jmp	(PlatformGroup_Draw).l

Vanish_DelayedProfile:
		dc.l Map_MMZ_Vanish
		dc.w ArtTile_MMZ_Atlas,$180
		dc.b Map_MMZ_Vanish_height,16,16,16

Vanish_DelayedAppear:
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
		dc.b $FF,0
Vanish_DelayedDisappear:
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
		dc.b $FF,0
		even
Map_MMZ_Vanish:	binclude "mappings/sprite/MMZ Vanish.bin"
		even
