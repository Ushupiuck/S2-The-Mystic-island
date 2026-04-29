; ---------------------------------------------------------------------------
; Object 0D - animals
; ---------------------------------------------------------------------------
animal_direction	= objoff_2C	; 1 byte
animal_type		= objoff_2D	; 1 byte
animal_x_vel		= objoff_2E	; 2 bytes
animal_y_vel		= objoff_30	; 2 bytes
animal_prison_num	= objoff_32	; 2 bytes
enemy_combo		= objoff_3E	; 2 bytes. See Touch_KillEnemy
; ---------------------------------------------------------------------------
Flicky:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Flicky_Index(pc,d0.w),d1
		jmp	Flicky_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Flicky_Index:
		dc.w Flicky_Init-Flicky_Index		;   0
		dc.w Flicky_ChkFloor-Flicky_Index	;   2
		dc.w Flicky_Walk-Flicky_Index		;   4
		dc.w Flicky_Fly-Flicky_Index		;   6
		dc.w Flicky_Walk-Flicky_Index		;   8
		dc.w Flicky_Walk-Flicky_Index		;  $A
		dc.w Flicky_Walk-Flicky_Index		;  $C
		dc.w Flicky_Fly-Flicky_Index		;  $E
		dc.w Flicky_Walk-Flicky_Index		; $10
		dc.w Flicky_Fly-Flicky_Index		; $12
		dc.w Flicky_Walk-Flicky_Index		; $14
		dc.w Flicky_Walk-Flicky_Index		; $16
		dc.w Flicky_Walk-Flicky_Index		; $18
		dc.w Flicky_Walk-Flicky_Index		; $1A
		dc.w Flicky_Prison-Flicky_Index		; $1C
		; These are the S1 ending actions:
		dc.w Flicky_FlickyWait-Flicky_Index	; $1E
		dc.w Flicky_FlickyWait-Flicky_Index	; $20
		dc.w Flicky_FlickyJump-Flicky_Index	; $22
		dc.w Flicky_RabbitWait-Flicky_Index	; $24
		dc.w Flicky_LandJump-Flicky_Index	; $26
		dc.w Flicky_SingleBounce-Flicky_Index	; $28
		dc.w Flicky_LandJump-Flicky_Index	; $2A
		dc.w Flicky_SingleBounce-Flicky_Index	; $2C
		dc.w Flicky_LandJump-Flicky_Index	; $2E
		dc.w Flicky_FlyBounce-Flicky_Index	; $30
		dc.w Flicky_DoubleBounce-Flicky_Index	; $32
; ---------------------------------------------------------------------------
; Numerical defintions as for Which Flicky is which
; Otherwise this would become a nightmare to modify
; ---------------------------------------------------------------------------
Rabbit = 0
Chicken = 1
Penguin = 2
Seal = 3
Pig = 4
Bird = 5
Squirrel = 6
Eagle = 7
Mouse = 8
Monkey = 9
Turtle = $A
Bear = $B
; ---------------------------------------------------------------------------
 ; This table declares what animals will appear in the zone.
 ; When an enemy is destroyed, a random animal is chosen from the 2 selected animals.
 ; Note: you must also load the corresponding art in the PLCs.
; ---------------------------------------------------------------------------
Flicky_ZoneAnimals:
		dc.b Rabbit,	Bird	; AIZ  0
		dc.b Rabbit,	Seal	; HCZ  1
		dc.b Bird,	Chicken	; MGZ  2
		dc.b Rabbit,	Bird	; CNZ  3
		dc.b Squirrel,	Bird	; FBZ  4
		dc.b Penguin,	Seal	; ICZ  5
		dc.b Bird,	Chicken	; LBZ  6
		dc.b Squirrel,	Chicken	; MHZ  7  ; (S3&K)
		dc.b Rabbit,	Chicken	; SOZ  8  ; (S3&K)
		dc.b Bird,	Chicken	; LRZ  9  ; (S3&K)
		dc.b Rabbit,	Bird	; SSZ $A  ; (S3&K)
		dc.b Squirrel,	Chicken	; DEZ $B  ; (S3&K)
		dc.b Squirrel,	Bird	; DDZ $C  ; (S3&K) Doomsday skips loading animals, but this is what would load if it did
		dc.b Bird,	Chicken	; ??Z $D  ; (S3&K)Intro and Ending
		dc.b Bird,	Chicken	; ALZ $E  ; (S3&K)
		dc.b Bird,	Chicken	; BPZ $F  ; (S3&K)
		dc.b Bird,	Chicken	; CGZ $10 ; (S3&K)
		dc.b Bird,	Chicken	; DPZ $11 ; (S3&K)
		dc.b Bird,	Chicken	; EMZ $12 ; (S3&K)
		dc.b Bird,	Chicken	; GBZ $13 ; (S3&K) Gumball
		dc.b Bird,	Chicken	; SCZ $14 ; (S3&K) Glowing Spheres
		dc.b Bird,	Chicken	; SCZ $15 ; (S3&K) Slot Machine
		dc.b Bird,	Chicken	; HPZ $16 ; (S3&K) Act 1
		dc.b Bird,	Chicken	; HPZ $16 ; (S3&K) Act 2

Flicky_Properties:	; This table declares the speed and mappings of each animal.
		dc.w -$200, -$400 ; Rabbit
		dc.l Map_Animals5
		dc.w -$200, -$300 ; Chicken
		dc.l Map_Animals1
		dc.w -$180, -$300 ; Penguin
		dc.l Map_Animals5
		dc.w -$140, -$180 ; Seal
		dc.l Map_Animals4
		dc.w -$1C0, -$300 ; Pig
		dc.l Map_Animals2
		dc.w -$300, -$400 ; Blue Flicky
		dc.l Map_Animals1
		dc.w -$280, -$380 ; Squirrel
		dc.l Map_Animals2
		dc.w -$280, -$300 ; Eagle
		dc.l Map_Animals1
		dc.w -$200, -$380 ; Mouse
		dc.l Map_Animals2
		dc.w -$2C0, -$300 ; Monkey
		dc.l Map_Animals2
		dc.w -$140, -$200 ; Turtle
		dc.l Map_Animals3
		dc.w -$200, -$300 ; Bear
		dc.l Map_Animals2

; ---------------------------------------------------------------------------
; The following tables are used exclusively by Sonic 1's ending
; ---------------------------------------------------------------------------
Flicky_EndingProperties:
		; Art, Horizontal speed, Vertical speed, Mappings
		dc.w  ArtTile_ArtNem_S1EndFlicky	;  0	Flicky
		dc.w -$440, -$400			;  0
		dc.l Map_Animals1			;  0
		dc.w  ArtTile_ArtNem_S1EndFlicky	;  1	Flicky (unused)
		dc.w -$440, -$400			;  1
		dc.l Map_Animals1			;  1
		dc.w  ArtTile_ArtNem_S1EndFlicky	;  2	Flicky
		dc.w -$440, -$400			;  2
		dc.l Map_Animals1			;  2
		dc.w  ArtTile_ArtNem_S1EndRabbit	;  3	Rabbit
		dc.w -$300, -$400			;  3
		dc.l Map_Animals5			;  3
		dc.w  ArtTile_ArtNem_S1EndRabbit	;  4	Rabbit
		dc.w -$300, -$400			;  4
		dc.l Map_Animals5			;  4
		dc.w  ArtTile_ArtNem_S1EndPenguin	;  5	Penguin (unused)
		dc.w -$180, -$300			;  5
		dc.l Map_Animals5			;  5
		dc.w  ArtTile_ArtNem_S1EndPenguin	;  6	Penguin (unused)
		dc.w -$180, -$300			;  6
		dc.l Map_Animals5			;  6
		dc.w  ArtTile_ArtNem_S1EndSeal		;  7	Seal (unused)
		dc.w -$140, -$180			;  7
		dc.l Map_Animals4			;  7
		dc.w  ArtTile_ArtNem_S1EndPig		;  8	Pig (unused)
		dc.w -$1C0, -$300			;  8
		dc.l Map_Animals2			;  8
		dc.w  ArtTile_ArtNem_S1EndChicken	;  9	Chicken
		dc.w -$200, -$300			;  9
		dc.l Map_Animals1			;  9
		dc.w  ArtTile_ArtNem_S1EndSquirrel	;  $A	Squirrel
		dc.w -$280, -$380			;  $A
		dc.l Map_Animals2			;  $A
; ---------------------------------------------------------------------------

Flicky_Init:
		tst.b	obSubtype(a0)
		beq.s	FlickyRandom
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		add.w	d0,d0
		move.b	d0,obRoutine(a0)
		subi.w	#$14,d0		; d0 = (subtype-$A)*2
		move.w	d0,d1
		add.w	d0,d0
		add.w	d0,d0
		add.w	d1,d0
		lea	Flicky_EndingProperties(pc),a1
		adda.w	d0,a1
		move.w	(a1)+,obGfx(a0)
		move.w	(a1)+,animal_x_vel(a0)
		move.w	animal_x_vel(a0),obVelX(a0)
		move.w	(a1)+,animal_y_vel(a0)
		move.w	animal_y_vel(a0),obVelY(a0)
		move.l	(a1)+,obMap(a0)
		move.b	#$C,obHeight(a0)
		move.b	#4,obRender(a0)
		bset	#0,obRender(a0)
		move.w	#$300,obPriority(a0)
		move.b	#8,obActWid(a0)
		move.b	#7,obTimeFrame(a0)
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

FlickyRandom:
		addq.b	#2,obRoutine(a0)
		bsr.w	RandomNumber
		move.w	#make_art_tile($580,0,0),obGfx(a0)
		andi.w	#1,d0
		beq.s	+
		move.w	#make_art_tile($592,0,0),obGfx(a0)
+
		moveq	#0,d1
		move.b	(Current_Zone).w,d1
		add.w	d1,d1
		add.w	d0,d1
		lea	Flicky_ZoneAnimals(pc),a1
		move.b	(a1,d1.w),d0
		move.b	d0,animal_type(a0)
		lsl.w	#3,d0
		lea	Flicky_Properties(pc),a1
		adda.w	d0,a1
		move.w	(a1)+,animal_x_vel(a0)
		move.w	(a1)+,animal_y_vel(a0)
		move.l	(a1)+,obMap(a0)
		move.b	#$C,obHeight(a0)
		move.b	#4,obRender(a0)
		bset	#0,obRender(a0)
		move.w	#$300,obPriority(a0)
		move.b	#8,obActWid(a0)
		move.b	#7,obTimeFrame(a0)
		move.b	#2,obFrame(a0)
		move.w	#-$400,obVelY(a0)
	;	tst.b	objoff_38(a0)	; From Sonic 3 & knuckles
		tst.b	(Boss_defeated_flag).w
		bne.s	++
		jsr	(FindFreeObj).l
		bne.s	+
		_move.b	#id_ObjFF,obID(a1)	; load the points object
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	enemy_combo(a0),d0	; Shared with Touch_KillEnemy & Explosion for the chain hit bonus
		lsr.w	#1,d0
		move.b	d0,obFrame(a1)
+		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
+
		move.b	#$1C,obRoutine(a0)
		clr.w	obVelX(a0)
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

;Flicky_Delete:
	;	jmp	(DeleteObject).l
; ---------------------------------------------------------------------------

Flicky_ChkFloor:
		tst.b	obRender(a0)
		bpl.w	DeleteObject
		bsr.w	ObjectMoveAndFall
		tst.w	obVelY(a0)
		bmi.w	DisplaySprite
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.w	DisplaySprite
		add.w	d1,obY(a0)
		move.w	animal_x_vel(a0),obVelX(a0)
		move.w	animal_y_vel(a0),obVelY(a0)
		move.b	#1,obFrame(a0)
		move.b	animal_type(a0),d0
		add.b	d0,d0
		addq.b	#4,d0
		move.b	d0,obRoutine(a0)
	;	tst.b	objoff_38(a0)	; From Sonic 3 & knuckles
	;	tst.b	(Boss_defeated_flag).w
	;	beq.w	DisplaySprite
		btst	#4,(Vint_runcount+3).w
		beq.w	DisplaySprite
		neg.w	obVelX(a0)
		bchg	#0,obRender(a0)
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

Flicky_Walk:
		bsr.w	ObjectMoveAndFall
		move.b	#1,obFrame(a0)
		tst.w	obVelY(a0)
		bmi.s	+
		clr.b	obFrame(a0)
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	+
		add.w	d1,obY(a0)
		move.w	animal_y_vel(a0),obVelY(a0)
+
		tst.b	obSubtype(a0)
		bne.s	Flicky_ChkDel
		tst.b	obRender(a0)
		bpl.w	DeleteObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

Flicky_Fly:
		bsr.w	ObjectMove
		addi.w	#$18,obVelY(a0)
		tst.w	obVelY(a0)
		bmi.s	+
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	+
		add.w	d1,obY(a0)
		move.w	animal_y_vel(a0),obVelY(a0)
		tst.b	obSubtype(a0)
		beq.s	+
		cmpi.b	#$A,obSubtype(a0)
		beq.s	+
		neg.w	obVelX(a0)
		bchg	#0,obRender(a0)
+
		subq.b	#1,obTimeFrame(a0)
		bpl.s	+
		move.b	#1,obTimeFrame(a0)
		addq.b	#1,obFrame(a0)
		andi.b	#1,obFrame(a0)
+
		tst.b	obSubtype(a0)
		bne.s	Flicky_ChkDel
		tst.b	obRender(a0)
		bpl.w	DeleteObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

Flicky_ChkDel:
		move.w	obX(a0),d0
		sub.w	(v_player+obX).w,d0
		bcs.w	DisplaySprite
		subi.w	#384,d0
		bpl.w	DisplaySprite
		tst.b	obRender(a0)
		bpl.w	DeleteObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

Flicky_Prison:
		tst.b	obRender(a0)
		bpl.w	DeleteObject
		subq.w	#1,animal_prison_num(a0)
		bne.w	DisplaySprite
		move.b	#2,obRoutine(a0)
		move.w	#$80,obPriority(a0)
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

Flicky_FlickyWait:
		bsr.w	ChkAnimalInRange
		bcc.s	Flicky_ChkDel
		move.w	animal_x_vel(a0),obVelX(a0)
		move.w	animal_y_vel(a0),obVelY(a0)
		move.b	#$E,obRoutine(a0)
		bra.w	Flicky_Fly
; ---------------------------------------------------------------------------

Flicky_FlickyJump:
		bsr.w	ChkAnimalInRange
		bpl.s	Flicky_ChkDel
		clr.w	obVelX(a0)
		clr.w	animal_x_vel(a0)
		bsr.w	ObjectMove
		addi.w	#$18,obVelY(a0)
		bsr.w	AnimalJump
		bsr.w	AnimalFaceSonic
		subq.b	#1,obTimeFrame(a0)
		bpl.w	Flicky_ChkDel
		move.b	#1,obTimeFrame(a0)
		addq.b	#1,obFrame(a0)
		andi.b	#1,obFrame(a0)
		bra.w	Flicky_ChkDel
; ---------------------------------------------------------------------------

Flicky_RabbitWait:
		bsr.w	ChkAnimalInRange
		bpl.w	Flicky_ChkDel
		move.w	animal_x_vel(a0),obVelX(a0)
		move.w	animal_y_vel(a0),obVelY(a0)
		move.b	#4,obRoutine(a0)
		bra.w	Flicky_Walk
; ---------------------------------------------------------------------------

Flicky_DoubleBounce:
		bsr.w	ObjectMoveAndFall
		move.b	#1,obFrame(a0)
		tst.w	obVelY(a0)
		bmi.w	Flicky_ChkDel
		clr.b	obFrame(a0)
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.w	Flicky_ChkDel
		not.b	animal_direction(a0) ; used to be objoff_29 in Sonic 1/2; in sonic 3, 29 is a "convention followed by many objects", so it was changed
		bne.s	+
		neg.w	obVelX(a0)
		bchg	#0,obRender(a0)
+
		add.w	d1,obY(a0)
		move.w	animal_y_vel(a0),obVelY(a0)
		bra.w	Flicky_ChkDel
; ---------------------------------------------------------------------------

Flicky_LandJump:
		bsr.w	ChkAnimalInRange
		bpl.w	Flicky_ChkDel
		clr.w	obVelX(a0)
		clr.w	animal_x_vel(a0)
		bsr.w	ObjectMoveAndFall
		bsr.w	AnimalJump
		bsr.w	AnimalFaceSonic
		bra.w	Flicky_ChkDel
; ---------------------------------------------------------------------------

Flicky_SingleBounce:
		bsr.w	ChkAnimalInRange
		bpl.w	Flicky_ChkDel
		bsr.w	ObjectMoveAndFall
		move.b	#1,obFrame(a0)
		tst.w	obVelY(a0)
		bmi.w	Flicky_ChkDel
		clr.b	obFrame(a0)
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.w	Flicky_ChkDel
		neg.w	obVelX(a0)
		bchg	#0,obRender(a0)
		add.w	d1,obY(a0)
		move.w	animal_y_vel(a0),obVelY(a0)
		bra.w	Flicky_ChkDel
; ---------------------------------------------------------------------------

Flicky_FlyBounce:
		bsr.w	ChkAnimalInRange
		bpl.w	Flicky_ChkDel
		bsr.w	ObjectMove
		addi.w	#$18,obVelY(a0)
		tst.w	obVelY(a0)
		bmi.s	++
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	++
		not.b	animal_direction(a0) ; used to be objoff_29 in Sonic 1/2; in sonic 3, 29 is a "convention followed by many objects", so it was changed
		bne.s	+
		neg.w	obVelX(a0)
		bchg	#0,obRender(a0)
+
		add.w	d1,obY(a0)
		move.w	animal_y_vel(a0),obVelY(a0)
+
		subq.b	#1,obTimeFrame(a0)
		bpl.w	Flicky_ChkDel
		move.b	#1,obTimeFrame(a0)
		addq.b	#1,obFrame(a0)
		andi.b	#1,obFrame(a0)
		bra.w	Flicky_ChkDel

; =============== S U B R O U T I N E =======================================


AnimalJump:
		move.b	#1,obFrame(a0)
		tst.w	obVelY(a0)
		bmi.s	+
		clr.b	obFrame(a0)
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	+
		add.w	d1,obY(a0)
		move.w	animal_y_vel(a0),obVelY(a0)
+		rts
; End of function AnimalJump


; =============== S U B R O U T I N E =======================================


AnimalFaceSonic:
		bset	#0,obRender(a0)
		move.w	obX(a0),d0
		sub.w	(v_player+obX).w,d0
		bcc.s	+
		bclr	#0,obRender(a0)
+		rts
; End of function AnimalFaceSonic


; =============== S U B R O U T I N E =======================================


ChkAnimalInRange:
		move.w	(v_player+obX).w,d0
		sub.w	obX(a0),d0
		subi.w	#184,d0
		rts
; End of function ChkAnimalInRange