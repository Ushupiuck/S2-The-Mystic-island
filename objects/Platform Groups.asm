; MD CPU. Shared constructor, update and ownership for platform groups.
; A single platform is a group with zero child slots. A child never owns a
; placement and validates the root's reciprocal link before running its state.
platgroup_x:		equ objoff_2E
platgroup_y:		equ objoff_30
platgroup_timer:	equ objoff_32
platgroup_state:	equ objoff_34	; long, direct behavior entry
platgroup_script:	equ objoff_38	; long, timed-frame cursor; rectangle uses its target XY
platgroup_owner:	equ objoff_3C	; word, zero for root
platgroup_link:		equ objoff_3E	; word, offset of reciprocal root field
platgroup_count:	equ ob2ndRout	; number of child links in the root
platgroup_members:	equ objoff_40	; up to seven word child links
platgroup_sequence:	equ objoff_44	; timed fixtures: return script (up to two links)
platgroup_phase:	equ objoff_48	; curved platforms (up to four links)
platgroup_spin:		equ objoff_4A	; curved platform's 8.8 animation accumulator
platgroup_dwell:	equ obTimeFrame	; timed animation updates remaining

; d6 = child count. Z and a3 = start of allocation scan on success.
; Root and children stay untouched until the allocator can build the whole group.
PlatformGroup_Preflight:
		move.w	d6,d1
		beq.s	.ready
		lea	(v_lvlobjspace).w,a1
		move.w	#(v_lvlobjend-v_lvlobjspace)/object_size-1,d0
.count:
		tst.l	code(a1)
		bne.s	.next
		subq.w	#1,d1
		beq.s	.ready
.next:
		lea	object_size(a1),a1
		dbf	d0,.count
		moveq	#1,d0
		rts
.ready:
		lea	(v_lvlobjspace).w,a3
		move.b	d6,platgroup_count(a0)
		move.w	obX(a0),platgroup_x(a0)
		move.w	obY(a0),platgroup_y(a0)
		moveq	#platgroup_members,d4
		moveq	#0,d0
		rts

; Preflight guarantees space. Scan forward from a3, preserving slot order.
; d4 gives the next link's SST offset and advances after each allocation.
PlatformGroup_Allocate:
		movea.l	a3,a1
		lea	object_size(a3),a3
		tst.l	code(a1)
		bne.s	PlatformGroup_Allocate
		move.w	a1,(a0,d4.w)
		move.w	a0,platgroup_owner(a1)
		move.w	d4,platgroup_link(a1)
		addq.w	#2,d4
		rts

; a4 = first state; a5 = visual/collision profile, including sprite and support radii.
; Profile: mappings long, art and priority words, display H/W, solidity H/W.
PlatformGroup_InitMember:
		move.l	#PlatformGroup_Run,code(a1)
		move.l	a4,platgroup_state(a1)
		move.l	(a5),obMap(a1)
		move.w	4(a5),obGfx(a1)
		move.w	6(a5),obPriority(a1)
		move.w	8(a5),height_pixels(a1)
		move.w	10(a5),obHeight(a1)
		move.b	obStatus(a1),obRender(a1)
		ori.b	#4,obRender(a1)
		rts

; a2 = records (timer,dx,dy,phase), d6 = helpers, a4/a5 as above.
; Used by timed groups and curves. The eight-member rectangle has its own
; spawn-phase records and uses the same allocator and member initializer.
PlatformGroup_Create:
		bsr.w	PlatformGroup_Preflight
		bne.s	.return
		movea.l	a0,a1
.make:
		move.b	obStatus(a0),obStatus(a1)
		bsr.s	PlatformGroup_InitMember
		move.w	(a2)+,platgroup_timer(a1)
		move.w	platgroup_x(a0),d0
		move.w	d0,platgroup_x(a1)
		add.w	(a2)+,d0
		move.w	d0,obX(a1)
		move.w	platgroup_y(a0),d0
		move.w	d0,platgroup_y(a1)
		add.w	(a2)+,d0
		move.w	d0,obY(a1)
		move.w	(a2)+,platgroup_phase(a1)
		dbf	d6,.allocate
		moveq	#0,d0
.return:
		rts
.allocate:
		bsr.w	PlatformGroup_Allocate
		bra.s	.make

PlatformGroup_Run:
		move.w	platgroup_owner(a0),d0
		beq.s	.behavior
		movea.w	d0,a1
		cmpi.l	#PlatformGroup_Run,code(a1)
		bne.s	PlatformGroup_Delete
		move.w	platgroup_link(a0),d0
		move.w	a0,d1
		cmp.w	(a1,d0.w),d1
		bne.s	PlatformGroup_Delete
.behavior:
		movea.l	platgroup_state(a0),a1
		jsr	(a1)
PlatformGroup_Draw:
		tst.w	platgroup_owner(a0)
		bne.s	.draw
		out_of_range.s	PlatformGroup_Unload,platgroup_x(a0)
.draw:
		jmp	(DisplaySprite).l

PlatformGroup_Delete:
		jsr	(SMZ_ReleaseRiders).l
		jmp	(DeleteObject).l

PlatformGroup_Unload:
		moveq	#0,d5
		move.b	platgroup_count(a0),d5
		beq.s	.root
		subq.w	#1,d5
		movea.l	a0,a4
		lea	platgroup_members(a0),a3
.member:
		move.w	(a3)+,d0
		beq.s	.next
		movea.w	d0,a0
		cmpi.l	#PlatformGroup_Run,code(a0)
		bne.s	.next
		move.w	a4,d0
		cmp.w	platgroup_owner(a0),d0
		bne.s	.next
		move.w	a3,d1
		sub.w	a4,d1
		subq.w	#2,d1
		cmp.w	platgroup_link(a0),d1
		bne.s	.next
		bsr.s	PlatformGroup_Delete
.next:
		dbf	d5,.member
		movea.l	a4,a0
.root:
		jsr	(SMZ_ReleaseRiders).l
		jmp	(UnloadObject).l

; Timed frames use (duration-1,frame); a negative duration holds that frame.
; Frame zero ends a timed transition. A null cursor holds the current pose.
PlatformGroup_Animate:
		subq.b	#1,platgroup_dwell(a0)
		bpl.s	.frame
		move.l	platgroup_script(a0),d0
		beq.s	.frame
		movea.l	d0,a1
		move.w	(a1)+,d0
		move.b	d0,obFrame(a0)
		lsr.w	#8,d0
		move.b	d0,platgroup_dwell(a0)
		bmi.s	.hold
		move.l	a1,platgroup_script(a0)
.frame:
		move.b	obFrame(a0),d0
		rts
.hold:
		clr.l	platgroup_script(a0)
		bra.s	.frame

; Stationary supports supply their current X; a moving path supplies old X.
PlatformGroup_TopSupport:
		moveq	#0,d1
		moveq	#0,d3
		move.b	obWidth(a0),d1
		move.b	obHeight(a0),d3
		jmp	(PlatformObject).l

; Timed vanishing blocks and fixed rotating platforms share this cycle.
PlatformGroup_TimedSolid:
		move.w	obX(a0),d4
		bsr.s	PlatformGroup_TopSupport
		subq.w	#1,platgroup_timer(a0)
		bne.s	.return
		move.l	#PlatformGroup_TimedTransition,platgroup_state(a0)
		move.l	platgroup_sequence(a0),platgroup_script(a0)
		clr.b	platgroup_dwell(a0)
		jmp	(SMZ_ReleaseRiders).l
.return:
		rts

PlatformGroup_TimedTransition:
		bsr.s	PlatformGroup_Animate
		bne.s	.return
		move.w	#120,platgroup_timer(a0)
		move.l	#PlatformGroup_TimedSolid,platgroup_state(a0)
.return:
		rts
