; ---------------------------------------------------------------------------
; Object 07 - water surface
; ---------------------------------------------------------------------------

WaterSurface:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Surf_Index(pc,d0.w),d1
		jmp	Surf_Index(pc,d1.w)
; ===========================================================================
Surf_Index:	dc.w WaterSurface_Init-Surf_Index
		dc.w WaterSurface_Main-Surf_Index

surf_origX = objoff_30		; original x-axis position
surf_freeze = objoff_32		; flag to freeze animation
; ===========================================================================

WaterSurface_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj07,obMap(a0)
		move.w	#make_art_tile(ArtTile_Water_Surface,0,1),obGfx(a0)
		move.b	#4,obRender(a0)
		move.b	#$80,obActWid(a0)
		move.w	obX(a0),surf_origX(a0)

WaterSurface_Main:
		move.w	(v_waterpos1).w,d1
		move.w	d1,obY(a0)
		tst.b	surf_freeze(a0)
		bne.s	WaterSurface_Animate
		move.b	(v_jpadpress1).w,d0 ; is Start button pressed?
		or.b	(v_jpadpresslogical).w,d0 ; (either player)
		andi.b	#btnStart,d0
		beq.s	loc_15540		; if not, branch
		addq.b	#3,obFrame(a0)
		move.b	#1,surf_freeze(a0)
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

WaterSurface_Animate:
		tst.w	(f_pause).w
		bne.s	WaterSurface_Display
		move.b	#0,surf_freeze(a0)
		subq.b	#3,obFrame(a0)

loc_15540:
		lea	(Obj07_FrameData).l,a1
		moveq	#0,d1
		move.b	obAniFrame(a0),d1
		move.b	(a1,d1.w),obFrame(a0)
		addq.b	#1,obAniFrame(a0)
		andi.b	#$3F,obAniFrame(a0)
WaterSurface_Display:
		jmp	(DisplaySprite).l
; ===========================================================================
; water sprite animation 'script' (custom format for this object)
Obj07_FrameData:
		dc.b 0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
		dc.b 1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2
		dc.b 2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1
		dc.b 1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0
		even
; ===========================================================================