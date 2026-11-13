; ---------------------------------------------------------------------------
; Object 79 - shared checkpoint / PAST / FUTURE pole, MD CPU.
; Word subtype: low byte checkpoint number/camera lock; bits 8-9 head mode;
; bit 10 yellow checkpoint; bits 11/12 required layer/filter enabled.
; One constructor selects a direct state. Signs never save checkpoint data.
; All heads borrow the Sonic 1 six-tile stem. See build_checkpoint_art.py.
Pole_child:		equ objoff_30 ; root: orbiting ball; ball: reciprocal parent
Pole_phase:		equ objoff_32 ; orbit step / time-post animation index
Pole_timer:		equ objoff_33 ; updates left in the animation
Pole_baseframe:		equ objoff_34 ; PAST 6 / FUTURE 8

Obj79:
		move.l	#Map_Obj79,obMap(a0)
		move.b	#Map_Obj79_height,height_pixels(a0)
		move.b	#Map_Obj79_width,width_pixels(a0)
		clr.w	obGfx(a0)	; maps use absolute VRAM words across three banks
		ori.b	#4,obRender(a0)
		move.w	#$280,obPriority(a0)
		move.b	#2,obRoutine(a0)
		move.w	obSubtype(a0),d0
		andi.w	#PoleType_Mask,d0
		cmpi.w	#PoleType_Past,d0
		beq.w	TimePole_Init
		cmpi.w	#PoleType_Future,d0
		beq.w	TimePole_Init
		move.l	#Checkpoint_Main,code(a0)
		bsr.w	Pole_ReadState
		btst	#0,d0
		bne.w	Checkpoint_SetActive
		bra.s	Checkpoint_Main

; Zero handles belong to Debug or scripted objects, never placement entry zero.
Pole_ReadState:
		move.w	respawn_addr(a0),d0
		beq.s	.return
		jmp	(Object_RespawnRead).l
.return:	rts

Pole_Consume:
		move.w	respawn_addr(a0),d0
		beq.s	.return
		jmp	(Object_RespawnConsume).l
.return:	rts

Checkpoint_Main:
		moveq	#0,d1
		move.b	(v_lastlamp).w,d1
		andi.b	#$7F,d1
		move.w	obSubtype(a0),d2
		andi.w	#$7F,d2
		cmp.b	d2,d1
		bhs.s	.already
		moveq	#8,d4
		bsr.w	Pole_Contact
		bcc.w	Pole_Draw
		bsr.w	Lamppost_StoreInfo
		bsr.s	Pole_Consume
		move.w	#sfx_Lamppost,d0
		jsr	(PlaySound_Special).l
		move.b	#4,obRoutine(a0)
		bsr.w	Checkpoint_SpawnBall
		bra.w	Pole_Draw
.already:
		bsr.s	Pole_Consume
Checkpoint_SetActive:
		bsr.s	Checkpoint_MakeActive
		bra.w	Pole_Draw
Checkpoint_MakeActive:
		clr.w	Pole_child(a0)
		move.b	#1,obFrame(a0)
		move.w	obSubtype(a0),d0
		btst	#10,d0
		beq.s	.ready
		move.b	#2,obFrame(a0)
.ready:
		move.b	#4,obRoutine(a0)
		move.l	#Pole_Active,code(a0)
		rts
Pole_Active:
Pole_Draw:
		jmp	(MarkObjGone).l

; One temporary child follows a 32-step radius-eight orbit twice. No live
; trigonometry/multiply or per-frame mapping rebuild; pool failure settles red.
Checkpoint_SpawnBall:
		jsr	(FindFreeObj).l
		bne.s	Checkpoint_MakeActive
		move.l	#Checkpoint_Ball,code(a1)
		move.w	a1,Pole_child(a0)
		move.w	a0,Pole_child(a1)
		move.l	obMap(a0),obMap(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.b	#4,obRender(a1)
		move.w	obPriority(a0),obPriority(a1)
		move.b	#8,width_pixels(a1)
		move.b	#8,height_pixels(a1)
		move.b	#4,obFrame(a1)
		move.w	obSubtype(a0),d0
		btst	#10,d0
		beq.s	.red
		addq.b	#1,obFrame(a1)
.red:
		move.b	#64,Pole_timer(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		subi.w	#32,obY(a1)
		move.b	#3,obFrame(a0)
		move.l	#Checkpoint_WaitBall,code(a0)
		rts

Checkpoint_WaitBall:
		movea.w	Pole_child(a0),a1
		cmpi.l	#Checkpoint_Ball,code(a1)
		bne.w	Checkpoint_SetActive
		move.w	a0,d0
		cmp.w	Pole_child(a1),d0
		bne.w	Checkpoint_SetActive
		bra.w	Pole_Draw

Checkpoint_Ball:
		movea.w	Pole_child(a0),a1
		cmpi.l	#Checkpoint_WaitBall,code(a1)
		bne.s	.delete
		move.w	a0,d0
		cmp.w	Pole_child(a1),d0
		bne.s	.delete
		subq.b	#1,Pole_timer(a0)
		beq.s	.finish
		addq.b	#1,Pole_phase(a0)
		andi.b	#31,Pole_phase(a0)
		moveq	#0,d0
		move.b	Pole_phase(a0),d0
		add.w	d0,d0
		lea	Checkpoint_Orbit(pc,d0.w),a2
		move.b	(a2)+,d0
		ext.w	d0
		add.w	obX(a1),d0
		move.w	d0,obX(a0)
		move.b	(a2),d0
		ext.w	d0
		add.w	obY(a1),d0
		move.w	d0,obY(a0)
		jmp	(DisplaySprite).l
.finish:
		exg	a0,a1
		bsr.w	Checkpoint_MakeActive
		exg	a0,a1
		jmp	(DeleteObject).l

.delete:
		jmp	(DeleteObject).l

Checkpoint_Orbit:
		dc.b 0,-32,2,-32,3,-33,4,-33,6,-34,7,-36,7,-37,8,-38
		dc.b 8,-40,8,-42,7,-43,7,-44,6,-46,4,-47,3,-47,2,-48
		dc.b 0,-48,-2,-48,-3,-47,-4,-47,-6,-46,-7,-44,-7,-43,-8,-42
		dc.b -8,-40,-8,-38,-7,-37,-7,-36,-6,-34,-4,-33,-3,-33,-2,-32
		even

TimePole_Init:
		move.b	#6,Pole_baseframe(a0)
		cmpi.w	#PoleType_Past,d0
		beq.s	.frame
		addq.b	#2,Pole_baseframe(a0)
.frame:
		move.b	Pole_baseframe(a0),obFrame(a0)
		move.l	#TimePole_Main,code(a0)
		bsr.w	Pole_ReadState
		btst	#0,d0
		beq.s	TimePole_Main
		bra.s	TimePole_Done

TimePole_Main:
		moveq	#22,d4
		bsr.w	Pole_Contact
		bcc.w	Pole_Draw
		bsr.w	Pole_Consume
		move.b	#-1,(TimeWarp_Direction).w
		cmpi.b	#6,Pole_baseframe(a0)
		beq.s	.past
		move.b	#1,(TimeWarp_Direction).w
.past:
		move.b	#60,Pole_timer(a0)
		clr.b	Pole_phase(a0)
		move.b	#1,obTimeFrame(a0)
		move.l	#TimePole_Spin,code(a0)
		move.w	#sfx_Lamppost,d0
		jsr	(PlaySound_Special).l
		bra.w	Pole_Draw

TimePole_Spin:
		subq.b	#1,Pole_timer(a0)
		beq.s	TimePole_Done
		subq.b	#1,obTimeFrame(a0)
		bpl.w	Pole_Draw
		move.b	#1,obTimeFrame(a0)
		addq.b	#1,Pole_phase(a0)
		andi.b	#7,Pole_phase(a0)
		moveq	#0,d0
		move.b	Pole_phase(a0),d0
		cmpi.b	#6,Pole_baseframe(a0)
		beq.s	.past
		addq.w	#8,d0
.past:
		move.b	TimePole_Frames(pc,d0.w),obFrame(a0)
		bra.w	Pole_Draw
TimePole_Done:
		move.b	Pole_baseframe(a0),obFrame(a0)
		addq.b	#1,obFrame(a0)
		move.b	#4,obRoutine(a0)
		move.l	#Pole_Active,code(a0)
		bra.w	Pole_Draw
TimePole_Frames:
		dc.b 6,10,11,10,7,10,11,10
		dc.b 8,10,11,10,9,10,11,10

; d4 = trigger half-width; carry set and a1 = the actual live contacting actor.
; Preserve d7, the object executor's DBF counter. Filter by each actor's own
; collision path when requested; one actor cannot lend the other its layer.
Pole_Contact:
		tst.w	(Debug_placement_mode).w
		bne.s	.miss
		tst.b	(f_playerctrl).w
		bmi.s	.miss
		lea	(v_player).w,a1
		bsr.s	.actor
		bcs.s	.return
		lea	(v_player2).w,a1
.actor:
		tst.l	code(a1)
		beq.s	.miss
		cmpi.b	#6,obRoutine(a1)
		bhs.s	.miss
		tst.b	obControl(a1)
		bmi.s	.miss
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d4,d0
		move.w	d4,d1
		add.w	d1,d1
		cmp.w	d1,d0
		bhs.s	.miss
		move.w	obY(a1),d0
		sub.w	obY(a0),d0
		addi.w	#64,d0
		cmpi.w	#104,d0
		bhs.s	.miss
		move.w	obSubtype(a0),d0
		btst	#12,d0
		beq.s	.hit
		moveq	#$C,d1
		btst	#11,d0
		beq.s	.layer
		moveq	#$E,d1
.layer:
		cmp.b	obTopSolidBit(a1),d1
		bne.s	.miss
.hit:
		ori.b	#1,ccr
.return:	rts
.miss:
		andi.b	#$FE,ccr
		rts

; Existing checkpoint snapshot/respawn contract; time poles never enter it.
Lamppost_StoreInfo:
		move.w	obSubtype(a0),d0
		move.b	d0,(v_lastlamp).w
		move.b	(v_lastlamp).w,(v_lastlamp+1).w
		move.w	obX(a0),(v_lamp_xpos).w
		move.w	obY(a0),(v_lamp_ypos).w
		move.w	(v_player+obGfx).w,(v_lamp_mainchar).w
		move.w	(v_player+obTopSolidBit).w,(v_lamp_solid).w
		move.w	(v_rings).w,(v_lamp_rings).w
		move.b	(v_lifecount).w,(v_lamp_lives).w
		move.l	(v_time).w,(v_lamp_time).w
	;	move.b	(Dynamic_Resize_Routine).w,(v_lamp_dle).w
		move.w	(Camera_Max_Y_pos).w,(v_lamp_limitbtm).w
		move.w	(Camera_RAM).w,(v_lamp_scrx).w
		move.w	(Camera_Y_pos).w,(v_lamp_scry).w
		move.w	(Camera_BG_X_pos).w,(v_lamp_bgscrx).w
		move.w	(Camera_BG_Y_pos).w,(v_lamp_bgscry).w
		move.w	(Camera_BG2_X_pos).w,(v_lamp_bg2scrx).w
		move.w	(Camera_BG2_Y_pos).w,(v_lamp_bg2scry).w
		move.w	(Camera_BG3_X_pos).w,(v_lamp_bg3scrx).w
		move.w	(Camera_BG3_Y_pos).w,(v_lamp_bg3scry).w
		move.w	(v_waterpos2).w,(v_lamp_wtrpos).w
		move.b	(v_wtr_routine).w,(v_lamp_wtrrout).w
		move.b	(f_wtr_state).w,(v_lamp_wtrstat).w
		rts
; End of function Lamppost_StoreInfo


; =============== S U B	R O U T	I N E =======================================


Lamppost_LoadInfo:
		move.b	(v_lastlamp+1).w,(v_lastlamp).w
		move.w	(v_lamp_xpos).w,(v_player+obX).w
		move.w	(v_lamp_ypos).w,(v_player+obY).w
		move.w	(v_lamp_rings).w,(v_rings).w
		move.b	(v_lamp_lives).w,(v_lifecount).w
		clr.w	(v_rings).w
		clr.b	(v_lifecount).w
		move.l	(v_lamp_time).w,(v_time).w
		move.b	#60-1,(v_timecent).w
		subq.b	#1,(v_timesec).w
		move.w	(v_lamp_mainchar).w,(v_player+obGfx).w
		move.w	(v_lamp_solid).w,(v_player+obTopSolidBit).w
	;	move.b	(v_lamp_dle).w,(Dynamic_Resize_Routine).w
		move.b	(v_lamp_wtrrout).w,(v_wtr_routine).w
		move.w	(v_lamp_limitbtm).w,(Camera_Max_Y_pos).w
		move.w	(v_lamp_limitbtm).w,(Camera_Max_Y_pos_target).w
		move.w	(v_lamp_scrx).w,(Camera_RAM).w
		move.w	(v_lamp_scry).w,(Camera_Y_pos).w
		move.w	(v_lamp_bgscrx).w,(Camera_BG_X_pos).w
		move.w	(v_lamp_bgscry).w,(Camera_BG_Y_pos).w
		move.w	(v_lamp_bg2scrx).w,(Camera_BG2_X_pos).w
		move.w	(v_lamp_bg2scry).w,(Camera_BG2_Y_pos).w
		move.w	(v_lamp_bg3scrx).w,(Camera_BG3_X_pos).w
		move.w	(v_lamp_bg3scry).w,(Camera_BG3_Y_pos).w
		tst.b	(Water_flag).w	; does the level have water?
		beq.s	+		; if not, branch to skip loading water stuff
		move.w	(v_lamp_wtrpos).w,(v_waterpos2).w
		move.b	(v_lamp_wtrrout).w,(v_wtr_routine).w
		move.b	(v_lamp_wtrstat).w,(f_wtr_state).w
+
		tst.b	(v_lastlamp).w
		bpl.s	.return
		move.w	(v_lamp_xpos).w,d0
		subi.w	#$A0,d0
		move.w	d0,(Camera_Min_X_pos).w
.return:	rts
; End of function Lamppost_LoadInfo
