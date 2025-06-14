; ---------------------------------------------------------------------------

Obj_S1Shield:
		move.l	#Map_S1Shield,mappings(a0)
		move.l	#DPLC_ClassicShield,shield_plc(a0)			; Used by PLCLoad_Shields
		move.l	#ArtUnc_ClassicShield,shield_art(a0)			; Used by PLCLoad_Shields
		move.b	#4,render_flags(a0)
		move.w	#$80,priority(a0)
		move.b	#$18,width_pixels(a0)
		move.b	#$18,height_pixels(a0)
		move.w	#ArtTile_Shield,art_tile(a0)
		move.w	#tiles_to_bytes(ArtTile_Shield),vram_art(a0)	; Used by PLCLoad_Shields
		btst	#7,(Player_1+art_tile).w
		beq.s	.nothighpriority
		bset	#7,art_tile(a0)

	.nothighpriority:
		move.w	#1,anim(a0)			; Clear anim and set prev_anim to 1
		move.b	#-1,shield_prev_frame(a0)	; Reset shield_prev_frame (used by PLCLoad_Shields)
		move.l	#Obj_S1Shield_Main,(a0)

Obj_S1Shield_Main:
		movea.w	parent(a0),a2
		btst	#Status_Invincible,status_secondary(a2)	; Is player invincible?
		bne.s	locret_187D6				; If so, do not display and do not update variables
		cmpi.b	#$1C,anim(a2)				; Is player in their 'blank' animation?
		beq.s	locret_187D6				; If so, do not display and do not update variables
		btst	#Status_Shield,status_secondary(a2)	; Should the player still have a shield?
		beq.s	Obj_S1Shield_Destroy			; If not, change to Insta-Shield
		move.w	x_pos(a2),x_pos(a0)
		move.w	y_pos(a2),y_pos(a0)
		move.b	status(a2),status(a0)
		andi.b	#1,status(a0)				; Limit inheritance to 'orientation' bit
		tst.b	(Reverse_gravity_flag).w
		beq.s	.normalgravity
		ori.b	#2,status(a0)				; If in reverse gravity, reverse the vertical mirror render_flag bit (On if Off beforehand and vice versa)

	.normalgravity:
		andi.w	#drawing_mask,art_tile(a0)
		tst.w	art_tile(a2)
		bpl.s	Obj_S1Shield_Display
		ori.w	#high_priority,art_tile(a0)

;	.nothighpriority:
Obj_S1Shield_Display:
		lea	(Ani_S1Shield).l,a1
		jsr	(Animate_Sprite).l
		bsr.w	PLCLoad_Shields
		jmp	(Draw_Sprite).l
; ---------------------------------------------------------------------------

locret_187D6:
		rts
; ---------------------------------------------------------------------------

Obj_S1Shield_Destroy:
		andi.b	#$8E,status_secondary(a2)	; Sets Status_Shield, Status_FireShield, Status_LtngShield, and Status_BublShield to 0
		move.l	#Obj_InstaShield,(a0)		; Replace the Classic Shield with the Insta-Shield
		rts
; ---------------------------------------------------------------------------
off_187DE:	dc.l byte_189ED
		dc.w $B
		dc.l byte_18A02
		dc.w $160D
		dc.l byte_18A1B
		dc.w $2C0D
; ---------------------------------------------------------------------------

; =============== S U B R O U T I N E =======================================


PLCLoad_Shields:
		moveq	#0,d0
		move.b	mapping_frame(a0),d0
		cmp.b	shield_prev_frame(a0),d0
		beq.s	locret_199E8
		move.b	d0,shield_prev_frame(a0)
		movea.l	shield_plc(a0),a2
		add.w	d0,d0
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,d5
		subq.w	#1,d5
		bmi.s	locret_199E8
		move.w	vram_art(a0),d4

PLCLoad_Shields_ReadEntry:
		moveq	#0,d1
		move.w	(a2)+,d1
		move.w	d1,d3
		lsr.w	#8,d3
		andi.w	#$F0,d3
		addi.w	#$10,d3
		andi.w	#$FFF,d1
		lsl.l	#5,d1
		add.l	shield_art(a0),d1
		move.w	d4,d2
		add.w	d3,d4
		add.w	d3,d4
		jsr	(Add_To_DMA_Queue).l
		dbf	d5,PLCLoad_Shields_ReadEntry

locret_199E8:
		rts
; End of function PLCLoad_Shields
