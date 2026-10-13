; The two shield SSTs cache the two physical banks, independently of their
; owners. Zero means empty, shield frames use DPLC indices 1-6, and $80 means
; resident stars in the primary bank. $FE reserves a bank for results/game
; over; $FF invalidates it. Both players share the resident star pixels.
effect_loaded_frame = objoff_30
PlayerEffects_ShieldFrameBias = 1
PlayerEffects_StarsLoaded = $80
PlayerEffects_GameOverLoaded = $FE
PlayerEffects_ResultsLoaded = PlayerEffects_GameOverLoaded

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
