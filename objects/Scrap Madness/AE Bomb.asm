; Ported from sonicretro/s1disasm 2c51d46 (REV01).
; Six-byte mappings, full code pointers, S3&K placement ownership.
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 5F - Walking SMZ_Bomb enemy (SLZ, SBZ)
; ---------------------------------------------------------------------------

SMZ_Bomb:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	SMZ_Bom_Index(pc,d0.w),d1
		jmp	SMZ_Bom_Index(pc,d1.w)
; ===========================================================================
SMZ_Bom_Index:	dc.w SMZ_Bom_Main-SMZ_Bom_Index		; 0
		dc.w SMZ_Bom_Action-SMZ_Bom_Index	; 2
		dc.w SMZ_Bom_Fuse-SMZ_Bom_Index		; 4
		dc.w SMZ_Bom_Shrapnel-SMZ_Bom_Index	; 6

SMZ_bom_time:	equ objoff_30		; multi-purpose timer (walking, waiting, fuse)
SMZ_bom_origY:	equ objoff_34		; fuse's original y-axis position independent it moving
SMZ_bom_parent:	equ objoff_3C		; address of parent SMZ_Bomb object (set but not used)
; ===========================================================================

SMZ_Bom_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)			; advance to SMZ_Bom_Action
		move.l	#Map_SMZ_Bomb,obMap(a0)
		move.b #Map_SMZ_Bomb_height,height_pixels(a0)			; set mappings
		move.w #ArtTile_SMZ_Atlas,obGfx(a0)			; set art tile
		ori.b	#4,obRender(a0)		; set to playfield-positioned mode
		move.w #$180,obPriority(a0)			; set sprite priority
		move.b	#24/2,obActWid(a0)			; set sprite display width

		move.w	obSubtype(a0),d0			; get subtype (0 = normal badnik, 4 = fuse, 6 = shrapnel)
		beq.s	.normalBadnik				; if normal badnik, branch
		move.b	d0,obRoutine(a0)			; directly set alternate routine from subtype
		rts						; go there on next run
; ---------------------------------------------------------------------------

	.normalBadnik:
		move.b	#$1A|$80,obColType(a0)	; set ReactToItem type (invincible and damaging)
		bchg	#0,obStatus(a0)		; face right by default (immediately gets changed to left on spawn)
; ---------------------------------------------------------------------------

SMZ_Bom_Action:	; Routine 2
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	SMZ_Bom_ActIndex(pc,d0.w),d1
		jsr	SMZ_Bom_ActIndex(pc,d1.w)

		lea	(SMZ_Ani_Bomb).l,a1
		jsr (AnimateSprite).l
		jmp (RememberState).l
; ===========================================================================
SMZ_Bom_ActIndex:	dc.w SMZ_Bom_Action_Waiting-SMZ_Bom_ActIndex		; 0
		dc.w SMZ_Bom_Action_Walking-SMZ_Bom_ActIndex		; 2
		dc.w SMZ_Bom_Action_WaitAndExplode-SMZ_Bom_ActIndex	; 4
; ===========================================================================

SMZ_Bom_Action_Waiting:
		bsr.w	SMZ_Bom_CheckStartFuse			; check if Sonic is in range of SMZ_Bomb and start fuse if so

		subq.w	#1,SMZ_bom_time(a0)				; decrement time delay before turning around
		bpl.s	.return					; if time remains, branch
		addq.b	#2,ob2ndRout(a0)			; advance to SMZ_Bom_Action_Walking
		move.w	#(25*60)+36-1,SMZ_bom_time(a0)		; set time delay before SMZ_Bomb stops walking to just over 25.5 seconds
		move.w	#$10,obVelX(a0)				; slowly walk to the right
		move.b	#1,obAnim(a0)				; use walking animation
		bchg	#0,obStatus(a0)		; invert X-flip flag
		beq.s	.return					; if SMZ_Bomb is facing to the right now, branch
		neg.w	obVelX(a0)				; slowly walk to the left instead

	.return:
		rts						; return
; ===========================================================================

SMZ_Bom_Action_Walking:
		bsr.w	SMZ_Bom_CheckStartFuse			; check if Sonic is in range of SMZ_Bomb and start fuse if so

		subq.w	#1,SMZ_bom_time(a0)				; decrement time delay before stopping to walk
		bmi.s	.stopWalking				; if time expired, branch
		jmp	(SpeedToPos).l				; update SMZ_Bomb's position
; ---------------------------------------------------------------------------

	.stopWalking:
		subq.b	#2,ob2ndRout(a0)			; go back to SMZ_Bom_Action_Waiting
		move.w	#(3*60)-1,SMZ_bom_time(a0)			; set time delay before turning around to 3 seconds
		clr.w	obVelX(a0)				; stop walking
		move.b	#0,obAnim(a0)				; use waiting animation
		rts						; return
; ===========================================================================

SMZ_Bom_Action_WaitAndExplode:
		subq.w	#1,SMZ_bom_time(a0)				; decrement time delay before exploding
		bpl.s	.return					; if time remains, branch
		move.l #FieryExplosion,code(a0)			; change SMZ_Bomb into an explosion
		move.b	#0,obRoutine(a0)			; set explosion object to init routine

	.return:
		rts						; return


; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to start the fuse if Sonic is in range of the Walking SMZ_Bomb.
; ---------------------------------------------------------------------------

SMZ_Bom_CheckStartFuse:
		move.w	(v_player+obX).w,d0			; get Sonic's X-position
		sub.w	obX(a0),d0				; calculate X-difference
		bhs.s	.chkX					; if positive, branch
		neg.w	d0					; make positive for range check
	.chkX:	cmpi.w	#96,d0					; is Sonic horizontally within 96px of SMZ_Bomb?
		bhs.s	.return					; if not, branch

		move.w	(v_player+obY).w,d0			; get Sonic's Y-position
		sub.w	obY(a0),d0				; calculate Y-difference
		bhs.s	.chkY					; if positive, branch
		neg.w	d0					; make positive for range check
	.chkY:	cmpi.w	#96,d0					; is Sonic vertically within 96px of SMZ_Bomb?
		bhs.s	.return					; if not, branch

		tst.w	(Debug_placement_mode).w				; is debug mode in use?
		bne.s	.return					; if yes, branch

		move.b	#4,ob2ndRout(a0)			; set to SMZ_Bom_Action_WaitAndExplode
		move.w	#(2*60)+24-1,SMZ_bom_time(a0)		; set fuse time to just over 2 seconds
		clr.w	obVelX(a0)				; stop SMZ_Bomb moving
		move.b	#2,obAnim(a0)				; use activated animation

		jsr (FindNextFreeObj).l				; find a free object slot
		bne.s	.return					; if object RAM is full, branch
		move.l #SMZ_Bomb,code(a1)			; load fuse object
		move.w	obX(a0),obX(a1)				; copy X-position
		move.w	obY(a0),obY(a1)				; copy Y-position
		move.w	obY(a0),SMZ_bom_origY(a1)			; remember original Y-position when making shrapnel
		move.b	obStatus(a0),obStatus(a1)		; copy X/Y-flip flags
		move.w	#4,obSubtype(a1)			; set fuse to use SMZ_Bom_Fuse routine
		move.b	#3,obAnim(a1)				; set to fuse animation

		move.w	#$10,obVelY(a1)				; make fuse slowly move down
		btst	#1,obStatus(a0)		; is bomb upside-down?
		beq.s	.finishFuse				; if not, branch
		neg.w	obVelY(a1)				; make fuse move up instead

	.finishFuse:
		move.w	#(2*60)+24-1,SMZ_bom_time(a1)		; set fuse time to just over 2 seconds
		move.l	a0,SMZ_bom_parent(a1)			; make fuse remember parent bomb object (unused)

	.return:
		rts						; return
; End of function SMZ_Bom_CheckStartFuse

; ===========================================================================

SMZ_Bom_Fuse:	; Routine 4
		bsr.s	SMZ_Bom_BurnFuseAndExplode			; advance fuse and spawn shrapnel once expired

		lea	(SMZ_Ani_Bomb).l,a1				; load animation script
		jsr (AnimateSprite).l				; animate fuse
		jmp (RememberState).l				; display or delete fuse

; ---------------------------------------------------------------------------
; Subroutine to advance burning the fuse, and spawn shrapnel on expiration.
; ---------------------------------------------------------------------------

SMZ_Bom_BurnFuseAndExplode:
		subq.w	#1,SMZ_bom_time(a0)				; decrement fuse timer
		bmi.s	.fuseExpired				; if timer expired, branch
		jmp	(SpeedToPos).l				; update fuse's position
; ---------------------------------------------------------------------------

.fuseExpired:
		; Avoid returning to SMZ_Bom_Fuse to prevent display-and-delete
		; and double-delete bugs.
		addq.l	#4,sp					; skip returning to SMZ_Bom_Fuse
		clr.w	SMZ_bom_time(a0)				; clear fuse timer
		clr.b	obRoutine(a0)				; clear routine counter (redundant here)
		move.w	SMZ_bom_origY(a0),obY(a0)			; restore initial Y-position of bomb

		moveq	#4-1,d1					; load four shrapnel objects
		movea.l	a0,a1					; replace fuse with first shrapnel object
		lea	(SMZ_Bom_ShrSpeed).l,a2			; load shrapnel speed data
		bra.s	.firstShrapnel				; first shrapnel doesn't need a free object slot
; ---------------------------------------------------------------------------

.loopShrapnel:
		jsr (FindNextFreeObj).l				; find a free object slot
		bne.s	.nextShrapnel				; if object RAM is full, branch (should probably branch after the dbf...)

	.firstShrapnel:
		move.l #SMZ_Bomb,code(a1)			; load shrapnel object
		move.w	obX(a0),obX(a1)				; copy X-position
		move.w	obY(a0),obY(a1)				; copy Y-position
		move.w	#6,obSubtype(a1)			; set shrapnel to use SMZ_Bom_Shrapnel routine
		move.b	#4,obAnim(a1)				; use shrapnel animation
		move.w	(a2)+,obVelX(a1)			; get next X-velocity from speed data
		move.w	(a2)+,obVelY(a1)			; get next Y-velocity from speed data
		move.b	#$18|$80,obColType(a1)		; set ReactToItem type (damaging)
		bset	#7,obRender(a1)	; make sure shrapnel doesn't get immediately deleted from "obRender bpl" check below

	.nextShrapnel:
		dbf	d1,.loopShrapnel			; repeat 3 more times

		move.b	#6,obRoutine(a0)			; set root object (previously the fuse) to SMZ_Bom_Shrapnel routine
		; Continue straight to SMZ_Bom_Shrapnel for first shrapnel...

; End of function SMZ_Bom_BurnFuseAndExplode
; ---------------------------------------------------------------------------

SMZ_Bom_Shrapnel:	; Routine 6
		jsr (SpeedToPos).l				; update shrapnel's position
		addi.w	#$18,obVelY(a0)				; make shrapnel fall faster

		lea	(SMZ_Ani_Bomb).l,a1				; load animation script
		jsr (AnimateSprite).l				; animate shrapnel

		tst.b	obRender(a0)				; has shrapnel gone offscreen?
		jpl UnloadObject				; if yes, delete it
		jmp (DisplaySprite).l				; otherwise, display shrapnel
; ===========================================================================

SMZ_Bom_ShrSpeed:	;    X-vel  Y-vel
		dc.w -$200, -$300	; 1st shrapnel
		dc.w -$100, -$200	; 2nd shrapnel
		dc.w  $200, -$300	; 3rd shrapnel
		dc.w  $100, -$200	; 4th shrapnel
; ===========================================================================
; ---------------------------------------------------------------------------
; Animation script - SMZ_Bomb enemy (SLZ/SBZ)
; ---------------------------------------------------------------------------

SMZ_Ani_Bomb:	dc.w SMZ_Ani_Bomb_stand-SMZ_Ani_Bomb
		dc.w SMZ_Ani_Bomb_walk-SMZ_Ani_Bomb
		dc.w SMZ_Ani_Bomb_activated-SMZ_Ani_Bomb
		dc.w SMZ_Ani_Bomb_fuse-SMZ_Ani_Bomb
		dc.w SMZ_Ani_Bomb_shrapnel-SMZ_Ani_Bomb

SMZ_Ani_Bomb_stand:		dc.b 19
		dc.b 1, 0
		dc.b afEnd
		even

SMZ_Ani_Bomb_walk:		dc.b 19
		dc.b 5, 4, 3, 2
		dc.b afEnd
		even

SMZ_Ani_Bomb_activated:	dc.b 19
		dc.b 7, 6
		dc.b afEnd
		even

SMZ_Ani_Bomb_fuse:		dc.b 3
		dc.b 8, 9
		dc.b afEnd
		even

SMZ_Ani_Bomb_shrapnel:	dc.b 3
		dc.b $A, $B
		dc.b afEnd
		even

Map_SMZ_Bomb: binclude "mappings/sprite/SMZ Bomb.bin"
