; ---------------------------------------------------------------------------
; Object 7C - Flash from the Giant Ring object
; All flashes share one art bank/frame. Only the first drives its clock;
; later flashes join it without restarting it. ob2ndRout holds these flags.
; ---------------------------------------------------------------------------

GRFlash_ClockOwner_bit = 0
GRFlash_ParentHandled_bit = 1

GiantRingFlash:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	GiantRingFlash_Index(pc,d0.w),d1
		jmp	GiantRingFlash_Index(pc,d1.w)
; ---------------------------------------------------------------------------
GiantRingFlash_Index:
		dc.w Flash_Main-GiantRingFlash_Index
		dc.w Flash_Animate-GiantRingFlash_Index
		dc.w Flash_Delete-GiantRingFlash_Index
; ---------------------------------------------------------------------------

Flash_Main:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_GiantRing,obMap(a0)
		move.w	#make_art_tile(ArtTile_Giant_Ring,1,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$20,obActWid(a0)
		clr.b	ob2ndRout(a0)		; Initialize this flash's ownership/cleanup flags
		cmpi.b	#2,(v_gfxbigring).w
		beq.s	Flash_Animate		; Join the existing flash animation
		tst.b	(f_bigring).w
		bne.s	Flash_Animate		; Never restart a completed entry
		bset	#GRFlash_ClockOwner_bit,ob2ndRout(a0)
		clr.b	obTimeFrame(a0)
		move.b	#2,(v_gfxbigring).w	; Start flash animation
		move.b	#-1,(v_ani2_frame).w
		move.b	#-1,(v_ani2_prev).w	; Frame 0 now uses flash art, not ring art

Flash_Animate:
		btst	#GRFlash_ClockOwner_bit,ob2ndRout(a0)
		beq.s	.checkframe
		subq.b	#1,obTimeFrame(a0)
		bpl.s	.checkframe
		move.b	#1,obTimeFrame(a0)
		addq.b	#1,(v_ani2_frame).w
.checkframe:
		cmpi.b	#8,(v_ani2_frame).w	; Has the shared animation finished?
		bhs.s	.finished
		cmpi.b	#3,(v_ani2_frame).w
		blo.s	.display
		bset	#GRFlash_ParentHandled_bit,ob2ndRout(a0)
		bne.s	.display			; Each parent is handled only once
		movea.l	objoff_3C(a0),a1
		cmpi.b	#id_Obj7B,obID(a1)	; The parent may have left the screen/reused its slot
		bne.s	.entry
		cmpi.b	#2,obRoutine(a1)
		bne.s	.entry
		tst.b	obColType(a1)		; Only the collected parent is eligible for deletion
		bne.s	.entry
		move.b	#6,obRoutine(a1)
.entry:
		btst	#GRFlash_ClockOwner_bit,ob2ndRout(a0)
		beq.s	.display			; Only the owner performs the level-exit effects
		move.b	#AniIDSonAni_Blank,(v_player+obAnim).w
		move.b	#1,(f_bigring).w
		; The owner queues entry once: clear both players' effects and tempo.
		move.l	a0,-(sp)
		lea	(v_player).w,a0
		jsr	(Player_ClearPowerUps).l
		lea	(v_player2).w,a0
		jsr	(Player_ClearPowerUps).l
		movea.l	(sp)+,a0
.display:
		; Finish the entry even if Sonic's speed takes this flash offscreen.
		bra.w	DisplaySprite
.finished:
		btst	#GRFlash_ClockOwner_bit,ob2ndRout(a0)
		beq.w	DeleteObject
; ---------------------------------------------------------------------------

Flash_End:
		addq.b	#2,obRoutine(a0)
		clr.b	(v_gfxbigring).w	; Stop loading giant ring graphics
		clr.w	(v_player).w
		addq.l	#4,sp
		rts
; End of function GiantRingFlash

; ---------------------------------------------------------------------------

Flash_Delete:
		bra.w	DeleteObject
