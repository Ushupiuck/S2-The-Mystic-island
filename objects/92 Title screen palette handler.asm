; ----------------------------------------------------------------------------
; Object 92 - "Palette changing handler" from title screen (W.I.P)
; ----------------------------------------------------------------------------
ttlscrpalchanger_fadein_time_left = objoff_30
ttlscrpalchanger_fadein_time = objoff_31
ttlscrpalchanger_fadein_amount = objoff_32
ttlscrpalchanger_start_offset = objoff_34
ttlscrpalchanger_length = objoff_36
ttlscrpalchanger_codeptr = objoff_3A

TitlePaletteHandler:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj92_Index(pc,d0.w),d1
		jmp	Obj92_Index(pc,d1.w)
; ===========================================================================
Obj92_Index:
		dc.w Obj92_Init-Obj92_Index	; 0
	;	dc.w Obj92_Main-Obj92_Index	; 2
; ===========================================================================

Obj92_Init:
		addq.b	#2,obRoutine(a0)
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		nop
		nop
	;	lea	(PaletteChangerDataIndex).l,a1
		adda.w	(a1,d0.w),a1
		move.l	(a1)+,ttlscrpalchanger_codeptr(a0)
		movea.l	(a1)+,a2
		move.b	(a1)+,d0
		move.w	d0,ttlscrpalchanger_start_offset(a0)
		lea	(v_palette_fading).w,a3
		adda.w	d0,a3
		move.b	(a1)+,d0
		move.w	d0,ttlscrpalchanger_length(a0)

-		move.w	(a2)+,(a3)+
		dbf	d0,-

		move.b	(a1)+,d0
		move.b	d0,ttlscrpalchanger_fadein_time_left(a0)
		move.b	d0,ttlscrpalchanger_fadein_time(a0)
		move.b	(a1)+,ttlscrpalchanger_fadein_amount(a0)
		rts