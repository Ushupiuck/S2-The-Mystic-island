; Mega Drive main-68000 automatic-path movement, shared by transport objects.
; Adapted from the reserved S3&K AutoTunnel helpers; paths belong to each level.
; No stock LBZ/LRZ coordinates or character-specific route substitutions remain.
;
; a1 = actor, a3 = owning object's rider packet, d2 = positive 8.8 major speed.
; AutoTunnel_GetPath also takes a2 = next signed absolute X/Y word pair.
; Output: actor velocities and packet's 8.8 timer. D0-D5 and a2 may change.
; The object owns entry/exit, timer ticking, waypoint advance and player locks.
; A leg must fit the existing signed integer-byte timer (less than 128 ticks).

AutoTunnel_GetPath:
		move.w	(a2)+,autopath_target_x(a3)
		move.w	(a2)+,autopath_target_y(a3)

AutoTunnel_CalcSpeed:
		move.w	autopath_target_x(a3),d0
		sub.w	obX(a1),d0
		move.w	autopath_target_y(a3),d1
		sub.w	obY(a1),d1
		move.w	d0,d4
		or.w	d1,d4
		beq.w	.zero		; duplicate waypoints never divide by zero
		moveq	#0,d4
		move.w	d0,d4
		bpl.s	.absY
		neg.w	d4
.absY:
		moveq	#0,d3
		move.w	d1,d3
		bpl.s	.major
		neg.w	d3
.major:
		cmp.w	d4,d3
		blo.s	.xMajor
		; Y-major: time = abs(Y distance)*65536 / speed. At the usual
		; sixteen pixels/tick this is exactly distance<<4, without DIVS.
		cmpi.w	#$1000,d2
		bne.s	.divideY
		lsl.w	#4,d3
		bra.s	.yTime
.divideY:
		swap	d3
		clr.w	d3
		divu.w	d2,d3
.yTime:
		move.w	d3,autopath_time(a3)
		tst.w	d0
		beq.s	.ySpeeds
		swap	d0
		clr.w	d0
		divs.w	d3,d0
.ySpeeds:
		move.w	d0,obVelX(a1)
		tst.w	d1
		bpl.s	.yPositive
		neg.w	d2
.yPositive:
		move.w	d2,obVelY(a1)
		rts
.xMajor:
		cmpi.w	#$1000,d2
		bne.s	.divideX
		lsl.w	#4,d4
		bra.s	.xTime
.divideX:
		swap	d4
		clr.w	d4
		divu.w	d2,d4
.xTime:
		move.w	d4,autopath_time(a3)
		tst.w	d1
		beq.s	.xSpeeds
		swap	d1
		clr.w	d1
		divs.w	d4,d1
.xSpeeds:
		move.w	d1,obVelY(a1)
		tst.w	d0
		bpl.s	.xPositive
		neg.w	d2
.xPositive:
		move.w	d2,obVelX(a1)
		rts
.zero:
		clr.w	autopath_time(a3)
		clr.w	obVelX(a1)
		clr.w	obVelY(a1)
		rts
