Obj1A:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Ledge_Index(pc,d0.w),d1
		jmp	Ledge_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Ledge_Index:	dc.w Ledge_Main-Ledge_Index	; 0
		dc.w Ledge_Touch-Ledge_Index	; 2
;		dc.w Ledge_Collapse-Ledge_Index	; 4
		dc.w Ledge_Display-Ledge_Index	; 6
;		dc.w Ledge_WalkOff-Ledge_Index	; 8

collapsing_platform_delay_pointer = objoff_34
ledge_timedelay = objoff_38		; time between touching the ledge and it collapsing
ledge_collapse_flag = objoff_3A		; collapse flag
collapsing_platform_slope_pointer = objoff_3C

; ---------------------------------------------------------------------------

Ledge_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj1A,obMap(a0)
		move.w	#make_art_tile(ArtTile_Level,2,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#7,ledge_timedelay(a0) ; set time delay for collapse
		move.b	obSubtype(a0),obFrame(a0)
		cmpi.b	#id_HPZ,(Current_Zone).w
		bne.s	+
		move.l	#Map_Obj1A_HPZ,obMap(a0)
		move.w	#$434A,obGfx(a0)
		move.b	#$30,obActWid(a0)
		move.l	#Obj1A_Conf_HPZ,collapsing_platform_slope_pointer(a0)
		bra.s	Ledge_Touch
; ===========================================================================
;+
;		cmpi.b	#oil_ocean_zone,(Current_Zone).w
;		bne.s	+
;		move.l	#Obj1F_MapUnc_110C6,mappings(a0)
;		move.w	#make_art_tile(ArtTile_ArtNem_OOZPlatform,3,0),art_tile(a0)
;		move.b	#$40,width_pixels(a0)
;		move.l	#Obj1A_OOZ_SlopeData,collapsing_platform_slope_pointer(a0)
;		bra.s	Ledge_Touch	; Obj1A_Main in S2 Final
; ===========================================================================
+
		move.l	#Obj1A_Conf,collapsing_platform_slope_pointer(a0)
		move.b	#$34,obActWid(a0)
		move.b	#$38,obHeight(a0)
		bset	#4,obRender(a0)

Ledge_Touch:	; Routine 2
		tst.b	ledge_collapse_flag(a0)	; is ledge collapsing?
		beq.s	loc_8CDC	; if not, branch
		tst.b	ledge_timedelay(a0)	; has time reached zero?
		beq.w	Ledge_Fragment	; if yes, branch
		subq.b	#1,ledge_timedelay(a0) ; subtract 1 from time

loc_8CDC:	; Ledge_Collapse?
		move.b	obStatus(a0),d0
		andi.b	#$18,d0
		beq.s	Ledge_WalkOff
		move.b	#1,ledge_collapse_flag(a0)	; set collapse flag

; =============== S U B	R O U T	I N E =======================================

Ledge_Destroy:
Ledge_WalkOff:	; Routine $A ; Misnomer now! See below.
		moveq	#0,d1
		move.b	obActWid(a0),d1
		movea.l	collapsing_platform_slope_pointer(a0),a2	; This is now stored in it's own custom constant
		move.w	obX(a0),d4
		bsr.w	SlopedPlatform
		bra.w	MarkObjGone
; End of function Ledge_WalkOff

; ---------------------------------------------------------------------------

Ledge_Display:	; Routine 6
		tst.b	ledge_timedelay(a0)	; has time delay reached zero?
		beq.s	Ledge_TimeZero		; if yes, branch
		tst.b	ledge_collapse_flag(a0)	; is ledge collapsing?
		bne.s	loc_8D16		; if yes, branch
		subq.b	#1,ledge_timedelay(a0) ; subtract 1 from time
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

loc_8D16:	; Actually "Ledge_WalkOff"! Due to how the subroutine evolved
		; You'd support two players, the code split into two. This,
		bsr.w	Ledge_WalkOff	; and "Ledge_Destroy"
		subq.b	#1,ledge_timedelay(a0)
		bne.s	locret_8D44
		lea	(v_player).w,a1
		bsr.s	sub_8D2A
		lea	(v_player2).w,a1

; =============== S U B	R O U T	I N E =======================================


sub_8D2A:
		btst	#3,obStatus(a1)
		beq.s	locret_8D44
		bclr	#3,obStatus(a1)
		bclr	#5,obStatus(a1)
		move.b	#1,obPrevAni(a1)

locret_8D44:
		rts
; End of function sub_8D2A

; ---------------------------------------------------------------------------

Ledge_TimeZero:
		bsr.w	ObjectMoveAndFall
		tst.b	obRender(a0)
		bpl.w	DeleteObject
		bra.w	DisplaySprite