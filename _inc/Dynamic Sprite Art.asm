; ---------------------------------------------------------------------------
; Mode 1 keeps compressed ROM art and streams from the former MD chunk RAM.
; Decompress outside VBlank, after scene clears/PLCs and before the first DMA.
; Level entry reloads all three sources; S1 stage entry needs only the ring.
; Other special-stage overlays may reclaim this RAM until the next level load.
; ---------------------------------------------------------------------------
LoadPlayerEffectArt:
		lea	(Nem_Shield_Dynamic).l,a0
		lea	(Art_Shield).l,a4
		jsr	(NemDecToRAM).l
		lea	(Nem_Invincibility).l,a0
		lea	(Art_Invincibility).l,a4
		jsr	(NemDecToRAM).l
LoadRingArt:
		lea	(Nem_Ring).l,a0
		lea	(Art_Ring).l,a4
		jmp	(NemDecToRAM).l
LoadSpecialStageRingArt:
		lea	(Nem_SpecialStageRings).l,a0
		lea	(Art_Ring).l,a4
		jmp	(NemDecToRAM).l

; ---------------------------------------------------------------------------
; S3&K dynamic pattern loading: word count, then one packed word per run.
; d0 = frame, a2 = DPLC table, a3 = cached-frame byte, d4 = VRAM destination,
; d6 = uncompressed art. Preserve a0 and d7 (the object-loop counter).
; Carry is set if the queue cannot accept the complete frame; retry next time.
; ---------------------------------------------------------------------------
Load_DynamicPLC:
		cmp.b	(a3),d0
		beq.s	.return
		move.w	d0,-(sp)
		add.w	d0,d0
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,d5
		beq.s	.ready
		; Each run can split at a 128 KB source boundary. Reserve both slots
		; before queuing anything, so a partial upload never becomes cached.
		move.w	d5,d1
		mulu.w	#DMAEntry.len*2,d1
		move.w	(VDP_Command_Buffer_Slot).w,d0
		add.w	d1,d0
		cmpi.w	#VDP_Command_Buffer_Slot,d0
		bhi.s	.full
		subq.w	#1,d5
.run:
		moveq	#0,d1
		move.w	(a2)+,d1
		move.w	d1,d3
		lsr.w	#8,d3
		andi.w	#$F0,d3
		addi.w	#$10,d3			; (count nibble + 1) * 16 words
		andi.w	#$FFF,d1
		lsl.l	#5,d1
		add.l	d6,d1
		move.w	d4,d2
		add.w	d3,d4
		add.w	d3,d4
		jsr	(QueueDMATransfer).l
		dbf	d5,.run
.ready:
		move.w	(sp)+,d0
		move.b	d0,(a3)
		andi.b	#$FE,ccr
.return:
		rts
.full:
		addq.w	#2,sp
.full_return:
		ori.b	#1,ccr
		rts

; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; Shared monitor icon DPLCs, MD CPU. Four physical 16x16 slots, shared by kind.
; Intact/broken bodies and the selected HUD portrait remain resident. Keep slots used
; in this or the previous game pass pinned, including blinking boxes, Debug
; previews and rising reward icons. Queue failure keeps the old tag and retries.
; A fifth simultaneous cached kind shows the baked-in static until a slot is
; available; it cannot overwrite another visible icon. Authored layouts are
; checked against the four-kind limit. No object-pool scan or per-box art buffer.
MonitorArt_Reset:
		move.l	#-1,(MonitorArt_Tags).w
		clr.l	(MonitorArt_Uses).w
		clr.l	(MonitorArt_Uses+4).w
		rts

; d0 = content kind -> a1 = corresponding slot mapping; carry = defer.
; Preserve a0/d7. Only cache misses enter the ordinary atomic DPLC loader.
MonitorArt_Select:
		cmp.b	(HUD_LifeType).w,d0
		beq.w	.life
		lea	(MonitorArt_Tags).w,a3
		moveq	#0,d2
.find:
		cmp.b	(a3,d2.w),d0
		beq.s	.pin
		addq.w	#1,d2
		cmpi.w	#MonitorArt_SlotCount,d2
		blo.s	.find
		moveq	#0,d2
.free:
		tst.b	(a3,d2.w)
		bmi.s	.load
		move.w	d2,d3
		add.w	d3,d3
		lea	(MonitorArt_Uses).w,a2
		move.w	(Timer_frames).w,d1
		sub.w	(a2,d3.w),d1
		cmpi.w	#1,d1
		bhi.s	.load
		addq.w	#1,d2
		cmpi.w	#MonitorArt_SlotCount,d2
		blo.s	.free
		ori.b	#1,ccr
		rts
.load:
		move.w	d2,-(sp)
		adda.w	d2,a3
		lsl.w	#7,d2	; four tiles, 128 VRAM bytes per slot
		move.w	#ArtTile_Monitor_Icons*tile_size,d4
		add.w	d2,d4
		lea	(DPLC_MonitorIcons).l,a2
		move.l	#Art_MonitorIcons,d6
		bsr.w	Load_DynamicPLC
		movem.w	(sp)+,d2	; preserve the loader's carry flag
		bcs.s	.return
.pin:
		move.w	d2,d3
		add.w	d3,d3
		lea	(MonitorArt_Uses).w,a2
		move.w	(Timer_frames).w,(a2,d3.w)
		lsl.w	#2,d2
		lea	(MonitorArt_Maps).l,a1
		movea.l	(a1,d2.w),a1
		andi.b	#$FE,ccr
.return:
		rts
.life:
		lea	(Map_MonitorHUD).l,a1
		andi.b	#$FE,ccr
		rts

; Carry means that a conservative sprite rectangle overlaps the viewport.
; Offscreen loaded boxes must not occupy the four visible-content slots.
MonitorArt_InView:
		move.w	obX(a0),d0
		sub.w	(Camera_X_pos).w,d0
		addi.w	#16,d0
		cmpi.w	#320+32,d0
		bhs.s	.return
		move.w	obY(a0),d0
		sub.w	(Camera_Y_pos).w,d0
		addi.w	#32,d0
		cmpi.w	#224+64,d0
.return:
		rts

MonitorArt_Draw:
		bsr.s	MonitorArt_InView
		bcc.w	DisplaySprite
		moveq	#0,d0
		move.b	obFrame(a0),d0
		cmpi.b	#2,obRoutine(a0)
		bne.s	.animation
		move.b	obAnim(a0),d0	; pin during the box's blank blink too
		bra.s	.select
.animation:
		tst.b	d0
		beq.w	DisplaySprite
		cmpi.b	#11,d0	; broken base has no content
		beq.w	DisplaySprite
		subq.w	#1,d0
.select:
		bsr.w	MonitorArt_Select
		bcs.s	.static
		move.l	a1,obMap(a0)
		bra.w	DisplaySprite
.static:
		clr.b	obFrame(a0)
		bra.w	DisplaySprite

MonitorArt_DrawContents:
		bsr.w	MonitorArt_InView
		bcc.w	DisplaySprite
		moveq	#0,d0
		move.b	obAnim(a0),d0
		bsr.w	MonitorArt_Select
		bcs.s	.return
		moveq	#0,d0
		move.b	obFrame(a0),d0
		add.w	d0,d0
		adda.w	(a1,d0.w),a1
		addq.w	#2,a1	; first mapping piece is the floating icon
		move.l	a1,obMap(a0)
		bra.w	DisplaySprite
.return:
		rts

; Card DPLCs use the same packed tile runs as Load_DynamicPLC. A complete card
; can exceed the DMA queue's run count, so its owner resumes on the next frame.
; The owner creates its visible children only after the final DMA has executed.
; d0 = scene (0-63 intro, 64-71 act results, 72-77 special-stage results)
; d4 = destination in VRAM bytes. Preserves a0/d7; clobbers d0-d6/a1-a3.
; Carry set: wait for another VBlank. Carry clear: all art is available.
; ---------------------------------------------------------------------------
card_dplc_ptr = objoff_28
card_dplc_left = objoff_2C
card_dplc_dest = objoff_2E

Load_CardDPLC:
		tst.l	card_dplc_ptr(a0)
		bne.s	.resume
		lea	(DPLC_Cards).l,a2
		add.w	d0,d0
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,card_dplc_left(a0)
		move.l	a2,card_dplc_ptr(a0)
		move.w	d4,card_dplc_dest(a0)
.resume:
		tst.w	card_dplc_left(a0)
		beq.s	.ready
.run:
		; Reserve both entries in case this run crosses a ROM 128KB boundary.
		move.w	(VDP_Command_Buffer_Slot).w,d0
		cmpi.w	#VDP_Command_Buffer_Slot-2*DMAEntry.len,d0
		bhi.s	.wait
		movea.l	card_dplc_ptr(a0),a2
		moveq	#0,d1
		move.w	(a2)+,d1
		move.l	a2,card_dplc_ptr(a0)
		move.w	d1,d3
		lsr.w	#8,d3
		andi.w	#$F0,d3
		addi.w	#$10,d3		; tile count -> word count
		andi.w	#$FFF,d1
		lsl.l	#5,d1
		addi.l	#Art_CardFont,d1
		move.w	card_dplc_dest(a0),d2
		add.w	d3,card_dplc_dest(a0)
		add.w	d3,card_dplc_dest(a0)
		jsr	(QueueDMATransfer).l
		subq.w	#1,card_dplc_left(a0)
		bne.s	.run
.wait:
		ori.b	#1,ccr
		rts
.ready:
		andi.b	#$FE,ccr
		rts

Get_NormalCardScene:
		lea	(Map_Obj3A).l,a3
		moveq	#0,d0
		move.b	(Current_Act).w,d0
		add.w	d0,d0
		addi.w	#64,d0
		cmpi.w	#PlayerMode_Tails,(Player_mode).w
		bne.s	.return
		addq.w	#1,d0
		lea	(Map_Got_Tails).l,a3
.return:
		rts

Get_SpecialCardScene:
		moveq	#0,d0
		tst.b	(v_ss_emerald_collected).w
		beq.s	.character
		tst.b	(v_emeralds).w
		beq.s	.character
		moveq	#2,d0
		cmpi.b	#ChaosEmerald_Count,(v_emeralds).w
		bne.s	.character
		moveq	#4,d0
.character:
		cmpi.w	#PlayerMode_Tails,(Player_mode).w
		bne.s	.map
		addq.w	#1,d0
.map:
		move.w	d0,d1
		lsl.w	#2,d1
		lea	(Card_SS_MapPointers).l,a3
		movea.l	(a3,d1.w),a3
		addi.w	#72,d0
		rts

; Load the selected portrait/name into the common life-HUD bank. Record its
; monitor type here, so cached monitors follow the loaded art, not the collector
; or a later Player_mode change. HUD_LifeType survives the level-entry clears.
Load_LifeArtPLC:
		move.b	#MonitorType_DoubleLife,(HUD_LifeType).w
		moveq	#plcid_LivesSonic,d0
		cmpi.w	#PlayerMode_Tails,(Player_mode).w
		bne.s	.load
		move.b	#MonitorType_ExtraLife,(HUD_LifeType).w
		moveq	#plcid_LivesTails,d0
.load:
		jmp	(LoadPLC).l

; ---------------------------------------------------------------------------
; The two shield SSTs cache the two physical banks, independently of their
; owners. Zero means empty, shield frames use DPLC indices 1-4, and $80 means
; resident stars in the primary bank. $FE reserves the dead primary
; player's bank for Game Over; $FF invalidates it. Both players share star pixels.
effect_loaded_frame = objoff_34
; DPLC_Shield entry 0 is cache-only; entry 1 is the invisible mapping frame 0.
PlayerEffects_ShieldFrameBias = 1
PlayerEffects_StarsLoaded = $80
PlayerEffects_GameOverLoaded = $FE

; a3 = bank cache byte, d4 = VRAM destination. Called only when switching
; to stars. Reserve both possible DMA entries before caching the upload;
; QueueDMATransfer can split a source crossing a 128 KB boundary.
PlayerEffects_LoadStars:
		move.w	(VDP_Command_Buffer_Slot).w,d0
		addi.w	#DMAEntry.len*2,d0
		cmpi.w	#VDP_Command_Buffer_Slot,d0
		bhi.s	.full
		move.l	#Art_Invincibility,d1
		move.w	d4,d2
		move.w	#(Art_Invincibility_End-Art_Invincibility)/2,d3
		jsr	(QueueDMATransfer).l
		move.b	#PlayerEffects_StarsLoaded,(a3)
		andi.b	#$FE,ccr
		rts
.full:
		ori.b	#1,ccr
		rts

; ---------------------------------------------------------------------------
; Dust, water splash and countdown numbers share S3&K's two 16-tile banks.
; The reserved splash SST caches each physical bank even when no splash lives.
; A source change invalidates the frame cache before the generic loader runs;
; a full DMA queue leaves frame $FF, so the next attempt still retries.
water_loaded_kind = objoff_34	; unused splash scratch, retained between bank users
water_loaded_frame = objoff_35
WaterArt_Dust = 1
WaterArt_Splash = 2
WaterArt_Countdown = 3

; Same inputs as Load_DynamicPLC; d5 identifies the source art kind.
; Select the shared cache here, avoiding a separate cache for every effect.
PlayerWaterArt_LoadDPLC:
		lea	(v_splash).w,a4
		cmpi.w	#ArtTile_Tails_Dust*tile_size,d4
		bne.s	.cache
		lea	(v_tsplash).w,a4
.cache:
		cmp.b	water_loaded_kind(a4),d5
		beq.s	.load
		move.b	d5,water_loaded_kind(a4)
		move.b	#-1,water_loaded_frame(a4)
.load:
		lea	water_loaded_frame(a4),a3
		bra.w	Load_DynamicPLC
