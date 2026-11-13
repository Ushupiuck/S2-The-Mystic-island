; Shared lifetime/allocation for MMZ's vanishing and rotating platform cohorts.
; MD CPU. Source: scddisasm test 791253ba; all helpers use full code pointers.
; Each member has an independent phase and independent Sonic/Tails support bits.
; Only the root owns a placement; reciprocal slot links reject recycled parents.
MMZ_group_x:		equ objoff_2E
MMZ_group_y:		equ objoff_30
MMZ_group_timer:	equ objoff_32
MMZ_group_state:	equ objoff_34 ; long, direct behavior entry
MMZ_group_script:	equ objoff_38 ; long, timed-frame cursor
MMZ_group_owner:	equ objoff_3C ; word, zero on the placement/root
MMZ_group_link:		equ objoff_3E ; word, offset of reciprocal root field
MMZ_group_members:	equ objoff_40 ; four word child pointers
MMZ_group_phase:	equ objoff_48 ; word, curve phase / spinning accumulator
MMZ_group_dwell:	equ objoff_4A ; byte, remaining timed-frame updates

; a2: (timer,dx,dy,phase) word records, including the root; d6: helper count.
; a4: first state, a5: mappings, d5: display half-height. Z means success.
; Preflight before touching the root; allocation then scans the pool only once.
MMZ_Platform_CreateGroup:
		move.w	d6,d1
		beq.s	.prepare
		lea	(v_lvlobjspace).w,a1
		move.w	#(v_lvlobjend-v_lvlobjspace)/object_size-1,d0
.count:
		tst.l	code(a1)
		bne.s	.next
		subq.w	#1,d1
		beq.s	.prepare
.next:
		lea	object_size(a1),a1
		dbf	d0,.count
		moveq	#1,d0
		rts
.prepare:
		move.w	obX(a0),MMZ_group_x(a0)
		move.w	obY(a0),MMZ_group_y(a0)
		lea	(v_lvlobjspace).w,a3
		moveq	#MMZ_group_members,d4
		movea.l	a0,a1
.make:
		move.l	#MMZ_Platform_Run,code(a1)
		move.l	a4,MMZ_group_state(a1)
		move.l	a5,obMap(a1)
		move.w	#ArtTile_MMZ_Atlas,obGfx(a1)
		move.w	#$180,obPriority(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obStatus(a0),obRender(a1)
		ori.b	#4,obRender(a1)
		move.b	#16,width_pixels(a1)
		move.b	d5,height_pixels(a1)
		move.b	#16,obWidth(a1)
		move.w	(a2)+,MMZ_group_timer(a1)
		move.w	MMZ_group_x(a0),d0
		move.w	d0,MMZ_group_x(a1)
		add.w	(a2)+,d0
		move.w	d0,obX(a1)
		move.w	MMZ_group_y(a0),d0
		move.w	d0,MMZ_group_y(a1)
		add.w	(a2)+,d0
		move.w	d0,obY(a1)
		move.w	(a2)+,MMZ_group_phase(a1)
		dbf	d6,.allocate
		moveq	#0,d0
		rts
.allocate:
		movea.l	a3,a1
		lea	object_size(a3),a3
		tst.l	code(a1)
		bne.s	.allocate
		move.w	a1,(a0,d4.w)
		move.w	a0,MMZ_group_owner(a1)
		move.w	d4,MMZ_group_link(a1)
		addq.w	#2,d4
		bra.w	.make

MMZ_Platform_Run:
		move.w	MMZ_group_owner(a0),d0
		beq.s	.behavior
		movea.w	d0,a1
		cmpi.l	#MMZ_Platform_Run,code(a1)
		bne.s	MMZ_Platform_Delete
		move.w	MMZ_group_link(a0),d0
		move.w	a0,d1
		cmp.w	(a1,d0.w),d1
		bne.s	MMZ_Platform_Delete
.behavior:
		movea.l	MMZ_group_state(a0),a1
		jsr	(a1)
MMZ_Platform_Draw:
		tst.w	MMZ_group_owner(a0)
		bne.s	.draw
		out_of_range2.w MMZ_Platform_Unload,MMZ_group_x(a0)
.draw:
		jmp	(DisplaySprite).l

MMZ_Platform_Delete:
		jsr	(SMZ_ReleaseRiders).l
		jmp	(DeleteObject).l

MMZ_Platform_Unload:
		movea.l	a0,a4
		lea	MMZ_group_members(a0),a3
		moveq	#3,d5
.member:
		move.w	(a3)+,d0
		beq.s	.next
		movea.w	d0,a0
		cmpi.l	#MMZ_Platform_Run,code(a0)
		bne.s	.next
		move.w	a4,d0
		cmp.w	MMZ_group_owner(a0),d0
		bne.s	.next
		bsr.s	MMZ_Platform_Delete
.next:
		dbf	d5,.member
		movea.l	a4,a0
		jsr	(SMZ_ReleaseRiders).l
		jmp	(UnloadObject).l

; Timed frames are (duration-1,frame), not an animation command interpreter.
; Return the current frame in d0; frame 0 is the authored terminal pose.
MMZ_Platform_Animate:
		subq.b	#1,MMZ_group_dwell(a0)
		bpl.s	.frame
		movea.l	MMZ_group_script(a0),a1
		move.b	(a1)+,MMZ_group_dwell(a0)
		move.b	(a1)+,obFrame(a0)
		move.l	a1,MMZ_group_script(a0)
.frame:
		move.b	obFrame(a0),d0
		rts
