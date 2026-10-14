; Dust, water splash and countdown numbers share S3&K's two 16-tile banks.
; The reserved splash SST caches each physical bank even when no splash lives.
; A source change invalidates the frame cache before the generic loader runs;
; a full DMA queue leaves frame $FF, so the next attempt still retries.
water_loaded_kind = objoff_4E
water_loaded_frame = objoff_4F
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
