; ---------------------------------------------------------------------------
; Death Egg act 3 - advancing wall of mixed explosions (source reference)
; Kept for a future level at the owner's request. NOT currently assembled.
; Source: sonicretro/skdisasm 73de97c6b55055bcb8089c1d55d006b02136f163,
; sonic3k.asm, loc_8030E / loc_80382.
;
; This is the original S3&K code, with its original SST/service names. Port
; those interfaces before using it here. The shared live explosion subsystem
; is in objects/FC, FD & FE Explosions.asm; no level currently starts this wall.
;
; Four following emitters: two large, two ordinary; each emits every 3 frames.
; Anchor: camera X-$80, camera Y+$80. Advance X by 2 pixels/frame to camera
; X+$80. Both axes scatter within [-$80,$7F] of that moving anchor.
;
; Original controller parameters (count, X/Y half-ranges, routine-set offset):
; CreateBossExp16: dc.b $80,$80,$80,8    ; follow parent, boss explosions
; CreateBossExp18: dc.b $80,$80,$80,$28 ; follow parent, ordinary explosions
; $80 means continuous in the large-explosion controller. The ordinary one
; decrements it normally (127 bursts). Obj_WaitForParent can end either early
; when its owner ends.
;
; The final transition below belongs to DEZ's ending cutscene. In particular,
; its full-pool fallback forcibly clears slot 61: retain it as reference only,
; and replace that transition/allocation policy when making a reusable wall.
; ---------------------------------------------------------------------------

loc_8030E:
		move.l	#loc_80382,(a0)
		clr.b	$38(a0)
		move.w	(Camera_X_pos).w,d0
		subi.w	#$80,d0
		move.w	d0,x_pos(a0)
		move.w	(Camera_Y_pos).w,d0
		addi.w	#$80,d0
		move.w	d0,y_pos(a0)
		lea	(Child6_CreateBossExplosion).l,a2
		jsr	(CreateChild6_Simple).l
		bne.s	loc_80344
		move.b	#$16,subtype(a1)

loc_80344:
		lea	(Child6_CreateBossExplosion).l,a2
		jsr	(CreateChild6_Simple).l
		bne.s	loc_80358
		move.b	#$16,subtype(a1)

loc_80358:
		lea	(Child6_CreateBossExplosion).l,a2
		jsr	(CreateChild6_Simple).l
		bne.s	loc_8036C
		move.b	#$18,subtype(a1)

loc_8036C:
		lea	(Child6_CreateBossExplosion).l,a2
		jsr	(CreateChild6_Simple).l
		bne.s	locret_80380
		move.b	#$18,subtype(a1)

locret_80380:
		rts
; ---------------------------------------------------------------------------

loc_80382:
		addq.w	#2,x_pos(a0)
		move.w	(Camera_X_pos).w,d0
		addi.w	#$80,d0
		cmp.w	x_pos(a0),d0
		bhs.s	locret_803D4
		move.l	#loc_803D6,(a0)
		jsr	(AllocateObject).l
		bne.s	loc_803B4
		move.l	#loc_85E64,(a1)
		move.w	a1,$44(a0)
		move.w	#3,$3A(a1)
		rts
; ---------------------------------------------------------------------------

loc_803B4:
		lea	(Dynamic_object_RAM+(object_size*61)).w,a1
		movea.l	a1,a2
		moveq	#0,d0
		moveq	#bytesToWcnt(object_size),d1

loc_803BE:
		move.w	d0,(a1)+
		dbf	d1,loc_803BE
		move.l	#loc_85E64,(a2)
		move.w	a2,$44(a0)
		move.w	#3,$3A(a2)

locret_803D4:
		rts
; ---------------------------------------------------------------------------
