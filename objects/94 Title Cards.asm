; ---------------------------------------------------------------------------
; Object 94 - zone title cards
; ---------------------------------------------------------------------------

TitleCards:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj94_Index(pc,d0.w),d1
		jmp	Obj94_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj94_Index:	dc.w Card_CheckSBZ3-Obj94_Index
		dc.w Card_ChkPos-Obj94_Index
		dc.w Card_Wait-Obj94_Index
		dc.w Card_Wait-Obj94_Index

card_mainX = objoff_34		; position for card to display on
card_finalX = objoff_36		; position for card to finish on
; ---------------------------------------------------------------------------

Card_CheckSBZ3:	; Routine 0
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
		lsl.w	#2,d0
		add.b	(Current_Act).w,d0
		move.w	#ArtTile_Zone_Title*tile_size,d4
		jsr	(Load_CardDPLC).l
		bcs.w	Obj94_NoDisplay
		movea.l	a0,a1
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
	;	cmpi.w	#(id_LZ<<8)+3,(Current_ZoneAndAct).w ; check if level is SBZ 3
	;	bne.s	Card_CheckFZ
	;	moveq	#5,d0		; load title card number 5 (SBZ)

; Card_CheckFZ:
		move.w	d0,d2
	;	cmpi.w	#(id_SBZ<<8)+2,(Current_ZoneAndAct).w ; check if level is FZ
	;	bne.s	Card_LoadConfig
	;	moveq	#6,d0		; load title card number 6 (FZ)
	;	moveq	#$B,d2		; use "FINAL" mappings

Card_LoadConfig:
		lea	(Card_ConData).l,a3
		lsl.w	#4,d0
		adda.w	d0,a3
		lea	(Card_ItemData).l,a2
		moveq	#3,d1

Card_Loop:
		move.l	#TitleCards,code(a1)
		move.w	(a3),obX(a1)	; load start x-position
		move.w	(a3)+,card_finalX(a1) ; load finish x-position (same as start)
		move.w	(a3)+,card_mainX(a1) ; load main x-position
		move.w	(a2)+,obScreenY(a1)
		move.b	(a2)+,obRoutine(a1)
		move.b	(a2)+,d0
		bne.s	Card_ActNumber
		move.b	d2,d0

Card_ActNumber:
		cmpi.b	#17,d0
		bne.s	Card_MakeSprite
		add.b	(Current_Act).w,d0
	;	cmpi.b	#3,(Current_Act).w
	;	bne.s	Card_MakeSprite
	;	subq.b	#1,d0

Card_MakeSprite:
		move.b	d0,obFrame(a1)
		move.l	#Map_Card,obMap(a1)
		move.b	#Map_Card_height,height_pixels(a1)
		move.w	#make_art_tile(ArtTile_Zone_Title,0,1),obGfx(a1)
		move.b	#sprite_bound($78,Map_Card_width),obActWid(a1)
		sf	obRender(a1)
		move.b	#60,obTimeFrame(a1)
		lea	object_size(a1),a1
		dbf	d1,Card_Loop

Card_ChkPos:	; Routine 2
		moveq	#$10,d1		; set horizontal speed
		move.w	card_mainX(a0),d0
		cmp.w	obX(a0),d0	; has item reached the target position?
		beq.s	Card_NoMove	; if yes, branch
		bge.s	Card_Move
		neg.w	d1

Card_Move:
		add.w	d1,obX(a0)

Card_NoMove:
		move.w	obX(a0),d0
		bmi.s	Obj94_NoDisplay
		cmpi.w	#$200,d0	; has item moved beyond	$200 on	x-axis?
		bcc.s	Obj94_NoDisplay	; if yes, branch
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

Obj94_NoDisplay:
		rts
; ---------------------------------------------------------------------------

Card_Wait:	; Routine 4/6
		tst.b	obTimeFrame(a0)	; is time remaining zero?
		beq.s	Card_ChkPos2	; if yes, branch
		subq.b	#1,obTimeFrame(a0) ; subtract 1 from time
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

Card_ChkPos2:
		tst.b	obRender(a0)
		bpl.s	Card_ChangeArt
		moveq	#$20,d1
		move.w	card_finalX(a0),d0
		cmp.w	obX(a0),d0	; has item reached the finish position?
		beq.s	Card_ChangeArt	; if yes, branch
		bge.s	Card_Move2
		neg.w	d1

Card_Move2:
		add.w	d1,obX(a0)	; change item's position
		move.w	obX(a0),d0
		bmi.s	Obj94_NoDisplay
		cmpi.w	#$200,d0	; has item moved beyond	$200 on	x-axis?
		bcc.s	Obj94_NoDisplay	; if yes, branch
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

Card_ChangeArt:
		cmpi.b	#4,obRoutine(a0)
		bne.s	Card_Delete
		moveq	#plcid_Explode,d0
		jsr	(LoadPLC).l	; load explosion patterns
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
		add.w d0,d0
		lea (Card_AnimalPLC).l,a1
		move.w (a1,d0.w),d0
		jsr	(LoadPLC).l	; load animal patterns
		jsr	(LoadKosPLC).l

Card_Delete:
		bra.w	DeleteObject
; ---------------------------------------------------------------------------
Card_ItemData:	dc.w $D0	; y-axis position
		dc.b 2,0	; routine number, frame	number (changes)
		dc.w $E4
		dc.b 2,16
		dc.w $EA
		dc.b 2,17
		dc.w $E0
		dc.b 2,21
; ---------------------------------------------------------------------------
; Title	card configuration data
; Format:
; 4 bytes per item (YYYY XXXX)
; 4 items per level (GREEN HILL, ZONE, ACT X, oval)
; ---------------------------------------------------------------------------
Card_ConData:
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154
		dc.w 0,$120,$FEFC,$13C,$414,$154,$214,$154

Card_AnimalPLC:
		dc.w plcid_GHZAnimals,plcid_LZAnimals,plcid_CPZAnimals,plcid_EHZAnimals,plcid_HPZAnimals,plcid_HTZAnimals
		dc.w plcid_GHZAnimals,plcid_GHZAnimals,plcid_GHZAnimals,plcid_GHZAnimals,plcid_GHZAnimals,plcid_GHZAnimals,plcid_GHZAnimals,plcid_GHZAnimals,plcid_GHZAnimals,plcid_GHZAnimals
