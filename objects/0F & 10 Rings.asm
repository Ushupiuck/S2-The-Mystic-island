; ===========================================================================
; Rings: ordinary placements, scattered rings and their shared pickup sparkle.
; code holds the current state; item touch installs the collection entry once.
; ===========================================================================
Ring:
		move.l	#Ring_Animate,code(a0)
		move.l	#Map_Ring,obMap(a0)
		move.b	#Map_Ring_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_Ring,1,0),obGfx(a0)
		cmpi.w	#BonusStage,(v_gamemode).w
		bne.s	.level
		move.w	#make_art_tile(ArtTile_SS_Rings,1,0),obGfx(a0)
.level:
		move.b	#4,obRender(a0)
		move.w	#$100,obPriority(a0)
		move.b	#$47,obColType(a0)
		move.b	#sprite_bound(8,Map_Ring_width),obActWid(a0)
Ring_Animate:
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------
LostRing_Collect:
		; The moving body uses the single-mapping fast path; its pickup
		; restores the ordinary four sparkle frames before changing state.
		move.l	#Map_Ring,obMap(a0)
		bclr	#obRender.static_mappings,obRender(a0)
		move.w	#make_art_tile(ArtTile_Ring,1,0),obGfx(a0)
Ring_Collect:
		move.l	#Ring_Sparkle,code(a0)
		clr.b	obColType(a0)
		move.w	#$80,obPriority(a0)
		move.b	#1,obFrame(a0)
		move.b	#5,obTimeFrame(a0)
		bsr.s	CollectRing
		bra.w	DisplaySprite
; Four frames, six updates each, followed by the original terminal display.
; A dedicated timer avoids interpreting an animation script for every pickup.
Ring_Sparkle:
		subq.b	#1,obTimeFrame(a0)
		bpl.w	DisplaySprite
		move.b	#5,obTimeFrame(a0)
		cmpi.b	#4,obFrame(a0)
		beq.s	.finish
		addq.b	#1,obFrame(a0)
		bra.w	DisplaySprite
.finish:
		move.l	#DeleteObject,code(a0)
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
CollectRing:
		move.w	#SndID_Ring,d0
		cmpi.w	#999,(v_rings).w
		bhs.s	.playsound
		addq.w	#1,(v_rings).w
		ori.b	#1,(f_ringcount).w
		cmpi.w	#100,(v_rings).w
		bcs.s	.playsound
		bset	#1,(v_lifecount).w
		beq.s	+
		cmpi.w	#200,(v_rings).w
		bcs.s	.playsound
		bset	#2,(v_lifecount).w
		bne.s	.playsound
+
		addq.b	#1,(v_lives).w
		addq.b	#1,(f_lifecount).w
		move.w	#MusID_ExtraLife,d0

.playsound:
		jmp	(PlaySound_Special).l
; End of function CollectRing

; ---------------------------------------------------------------------------
; Lost rings have independent lifetimes; neither timer aliases subpixel motion.
obDelayAni	= objoff_2E
lost_ring_floor_distance = objoff_30
lost_ring_floor_frame = objoff_32

LostRings:
		move.w	(v_rings).w,d5
		beq.w	DeleteObject		; no phantom spill when the count is zero
		cmpi.w	#32,d5
		blo.s	.count
		moveq	#32,d5
.count:
		subq.w	#1,d5
		movea.l	a0,a1
		lea	(v_lvlobjspace).w,a3
		lea	LostRing_Velocities(pc),a2
		bra.s	.initialize
.next:
		; Keep the original lowest-free-slot order, scanning each slot once.
		; LEA preserves the flags from TST, including for the last free slot.
		cmpa.w	#v_lvlobjend,a3
		bhs.s	.done
		tst.l	code(a3)
		lea	object_size(a3),a3
		bne.s	.next
		lea	-object_size(a3),a1
.initialize:
		bsr.s	LostRing_Init
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.l	(a2)+,obVelX(a1)
		jsr	(Touch_RegisterEarlierObject).l
		dbf	d5,.next
.done:
		clr.w	(v_rings).w
		move.b	#$80,(f_ringcount).w
		clr.b	(v_lifecount).w
		move.b	#-1,(v_ani3_time).w
		move.w	#SndID_RingSpill,d0
		jsr	(PlaySound_Special).l
		bra.s	LostRing_Move

; a1 = cleared child SST. Reused by the goddess emitter; no reward/timer reset
; affects any other ring. Packed stores cover only contiguous NPC fields.
LostRing_Init:
		move.l	#LostRing_Move,code(a1)
		move.l	#($24<<24)|(Map_Ring_height<<8)|sprite_bound(8,Map_Ring_width),obRender(a1)
		move.l	#($180<<16)|make_art_tile(ArtTile_RingLoss,1,0),obPriority(a1)
		; Resolve the existing first piece once, rather than for every draw.
		lea	(Map_Ring).l,a4
		adda.w	(a4),a4
		addq.w	#2,a4
		move.l	a4,obMap(a1)
		move.w	#$0808,obHeight(a1)
		move.b	#$47,obColType(a1)
		move.b	#255,obDelayAni(a1)
		move.w	(Timer_frames).w,d0
		subq.w	#1,d0
		move.w	d0,lost_ring_floor_frame(a1)
		rts

LostRing_Move:
		movem.w	obVelX(a0),d0/d2
		lsl.l	#8,d0
		lsl.l	#8,d2
		add.l	d0,obX(a0)
		add.l	d2,obY(a0)
		tst.w	(Camera_Min_Y_pos).w
		bpl.s	.no_wrap
		andi.w	#Level_YWrapMask,obY(a0)
.no_wrap:
		addi.w	#$18,obVelY(a0)
		bmi.s	.lifetime
		move.b	(Vint_runcount+3).w,d0
		add.b	d7,d0
		andi.b	#3,d0
		bne.s	.lifetime
		tst.b	obRender(a0)
		bpl.s	.lifetime
		bsr.w	LostRing_Floor
		bpl.s	.lifetime
		add.w	d1,obY(a0)
		tst.w	(Camera_Min_Y_pos).w
		bpl.s	.bounce
		andi.w	#Level_YWrapMask,obY(a0)
.bounce:
		move.w	obVelY(a0),d0
		asr.w	#2,d0
		sub.w	d0,obVelY(a0)
		neg.w	obVelY(a0)
.lifetime:
		subq.b	#1,obDelayAni(a0)
		beq.w	DeleteObject
		tst.w	(v_limittop2).w
		bmi.s	.blink
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		bcs.w	DeleteObject
.blink:
		btst	#0,obDelayAni(a0)
		beq.w	DisplaySprite
		cmpi.b	#80,obDelayAni(a0)
		bhi.w	DisplaySprite
		rts

; The next same-phase slots are four records apart. Prefetch up to two
; falling, visible rings whose inputs cannot change before their object turn.
; Cache only this update's answer; isolated rings retain the ordinary query.
LostRing_Floor:
		move.w	(Timer_frames).w,d0
		cmp.w	lost_ring_floor_frame(a0),d0
		beq.w	.cached
		movea.l	a0,a1
		bsr.w	.next
		bcs.w	.single
		move.w	sr,-(sp)
		disable_ints
		move.w	obX(a0),(MCD_MainArgument).l
		move.w	obY(a0),(MCD_MainArgument+2).l
		lea	(MCD_MainArgument+4).l,a4
		bsr.w	.predict
		move.b	#1,(MCD_MainFlags).l
		move.l	a1,-(sp)
		bsr.s	.next
		bcs.s	.two_points
		movea.l	a1,a2
		bsr.w	.predict
		move.b	#2,(MCD_MainFlags).l
.two_points:
		movea.l	(sp)+,a1
		moveq	#0,d0
		move.b	obHeight(a0),d0
		lsl.w	#8,d0
		ori.b	#MCD_TerrainFloorBatch,d0
		jsr	(MCD_TerrainRequest).l
		move.w	(MCD_SubResult+6).l,lost_ring_floor_distance(a1)
		move.w	(Timer_frames).w,lost_ring_floor_frame(a1)
		cmpi.b	#2,(MCD_MainFlags).l
		bne.s	.result
		move.w	(MCD_SubResult+8).l,lost_ring_floor_distance(a2)
		move.w	(Timer_frames).w,lost_ring_floor_frame(a2)
.result:
		move.w	(MCD_SubResult+4).l,d1
		move.w	(sp)+,sr
		tst.w	d1
		rts
.cached:
		move.w	lost_ring_floor_distance(a0),d1
		rts
.single:
		jmp	(ObjHitFloor).l

; Skip rising/offscreen candidates without ending the run. Intervening slots
; must all be moving rings: their floor queries do not change the terrain path
; or layout, even if an interrupt changes which phase gets its turn.
.next:
		lea	4*object_size(a1),a1
		cmpa.w	#v_lvlobjend,a1
		bhs.s	.unavailable
		cmpi.l	#LostRing_Move,code-3*object_size(a1)
		bne.s	.unavailable
		cmpi.l	#LostRing_Move,code-2*object_size(a1)
		bne.s	.unavailable
		cmpi.l	#LostRing_Move,code-object_size(a1)
		bne.s	.unavailable
		cmpi.l	#LostRing_Move,code(a1)
		bne.s	.unavailable
		tst.b	obRender(a1)
		bpl.s	.next
		move.w	obVelY(a1),d0
		addi.w	#$18,d0
		bmi.s	.next
		move.b	obHeight(a0),d0
		cmp.b	obHeight(a1),d0
		bne.s	.next
		andi	#$FE,ccr
		rts
.unavailable:
		ori	#1,ccr
		rts

; Predict the same signed 16.16 movement and optional seam normalization as
; LostRing_Move. This leaves its SST and fractional coordinates untouched.
.predict:
		move.l	obX(a1),d3
		move.w	obVelX(a1),d0
		ext.l	d0
		lsl.l	#8,d0
		add.l	d0,d3
		swap	d3
		move.w	d3,(a4)+
		move.l	obY(a1),d3
		move.w	obVelY(a1),d0
		ext.l	d0
		lsl.l	#8,d0
		add.l	d0,d3
		swap	d3
		tst.w	(Camera_Min_Y_pos).w
		bpl.s	.y_ready
		andi.w	#Level_YWrapMask,d3
.y_ready:
		move.w	d3,(a4)+
		rts

; Exact original CalcSine($88+$10*n) pairs: 16 at 4x, then 16 at 2x.
; Interleaved signed X/Y words preserve slot order, rounding and both rings
; of each mirrored pair without recalculating trigonometry during a hit.
LostRing_Velocities:
		dc.w	$FF3C,$FC14
		dc.w	$00C4,$FC14
		dc.w	$FDC8,$FCB0
		dc.w	$0238,$FCB0
		dc.w	$FCB0,$FDC8
		dc.w	$0350,$FDC8
		dc.w	$FC14,$FF3C
		dc.w	$03EC,$FF3C
		dc.w	$FC14,$00C4
		dc.w	$03EC,$00C4
		dc.w	$FCB0,$0238
		dc.w	$0350,$0238
		dc.w	$FDC8,$0350
		dc.w	$0238,$0350
		dc.w	$FF3C,$03EC
		dc.w	$00C4,$03EC
		dc.w	$FF9E,$FE0A
		dc.w	$0062,$FE0A
		dc.w	$FEE4,$FE58
		dc.w	$011C,$FE58
		dc.w	$FE58,$FEE4
		dc.w	$01A8,$FEE4
		dc.w	$FE0A,$FF9E
		dc.w	$01F6,$FF9E
		dc.w	$FE0A,$0062
		dc.w	$01F6,$0062
		dc.w	$FE58,$011C
		dc.w	$01A8,$011C
		dc.w	$FEE4,$01A8
		dc.w	$011C,$01A8
		dc.w	$FF9E,$01F6
		dc.w	$0062,$01F6
