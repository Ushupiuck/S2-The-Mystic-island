; ---------------------------------------------------------------------------
; Object 07 - points that appear when you destroy something
; ---------------------------------------------------------------------------

Points:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Points_Index(pc,d0.w),d1
		jmp	Points_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Points_Index:	dc.w Points_main-Points_Index
		dc.w Points_Deccelerate-Points_Index
; ---------------------------------------------------------------------------

Points_main:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj29,obMap(a0)
		move.w	#make_art_tile($4AC,0,0),obGfx(a0)	; TODO Change
		move.b	#4,obRender(a0)
		move.w	#$80,obPriority(a0)
		move.b	#8,obActWid(a0)
		move.w	#-$300,obVelY(a0)			; move object upwards

Points_Deccelerate:
		tst.w	obVelY(a0)				; is object moving?
		bpl.w	DeleteObject				; if not, delete
		bsr.w	ObjectMove				; update position
		addi.w	#$18,obVelY(a0)				; reduce object speed
		bra.w	DisplaySprite