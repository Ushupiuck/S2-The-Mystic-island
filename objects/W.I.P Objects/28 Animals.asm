; ---------------------------------------------------------------------------
animal_ground_routine_base = objoff_30
animal_ground_x_vel = objoff_32
animal_ground_y_vel = objoff_34
ObjAnimal:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	ObjAnimal_Index(pc,d0.w),d1
		jmp	ObjAnimal_Index(pc,d1.w)
; ---------------------------------------------------------------------------
ObjAnimal_Index:
		dc.w ObjAnimal_Init-ObjAnimal_Index		;   0
		dc.w ObjAnimal_Main-ObjAnimal_Index		;   2
		dc.w ObjAnimal_Walk-ObjAnimal_Index		;   4
		dc.w ObjAnimal_Fly-ObjAnimal_Index		;   6
		dc.w ObjAnimal_Walk-ObjAnimal_Index		;   8
		dc.w ObjAnimal_Walk-ObjAnimal_Index		;  $A
		dc.w ObjAnimal_Walk-ObjAnimal_Index		;  $C
		dc.w ObjAnimal_Fly-ObjAnimal_Index		;  $E
		dc.w ObjAnimal_Walk-ObjAnimal_Index		; $10
		dc.w ObjAnimal_Fly-ObjAnimal_Index		; $12
		dc.w ObjAnimal_Walk-ObjAnimal_Index		; $14
		dc.w ObjAnimal_Walk-ObjAnimal_Index		; $16
		dc.w ObjAnimal_Walk-ObjAnimal_Index		; $18
		dc.w ObjAnimal_Walk-ObjAnimal_Index		; $1A
		dc.w ObjAnimal_Prison-ObjAnimal_Index		; $1C
		; These are the S1 ending actions:
		dc.w ObjAnimal_FlickyWait-ObjAnimal_Index	; $1E
		dc.w ObjAnimal_FlickyWait-ObjAnimal_Index	; $20
		dc.w ObjAnimal_FlickyJump-ObjAnimal_Index	; $22
		dc.w ObjAnimal_RabbitWait-ObjAnimal_Index	; $24
		dc.w ObjAnimal_LandJump-ObjAnimal_Index		; $26
		dc.w ObjAnimal_SingleBounce-ObjAnimal_Index	; $28
		dc.w ObjAnimal_LandJump-ObjAnimal_Index		; $2A
		dc.w ObjAnimal_SingleBounce-ObjAnimal_Index	; $2C
		dc.w ObjAnimal_LandJump-ObjAnimal_Index		; $2E
		dc.w ObjAnimal_FlyBounce-ObjAnimal_Index	; $30
		dc.w ObjAnimal_DoubleBounce-ObjAnimal_Index	; $32

ObjAnimal_ZoneAnimals:
	; This table declares what animals will appear in the zone.
	; When an enemy is destroyed, a random animal is chosen from the 2 selected animals.
	; Note: you must also load the corresponding art in the PLCs.
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
		dc.b Bear,	Eagle	; AIZ 0
		dc.b Rabbit,	Seal	; HCZ 1
		dc.b Bird,	Chicken	; MGZ 2
		dc.b Rabbit,	Bird	; CNZ 3
		dc.b Squirrel,	Bird	; FBZ 4
		dc.b Penguin,	Seal	; ICZ 5
		dc.b Bird,	Chicken	; LBZ 6
		dc.b Squirrel,	Chicken	; MHZ 7
		dc.b Rabbit,	Chicken	; SOZ 8
		dc.b Bird,	Chicken	; LRZ 9
		dc.b Rabbit,	Bird	; SSZ $A ; Why does this load "Rabbit and Chicken"?
		dc.b Squirrel,	Chicken	; DEZ $B
		dc.b Squirrel,	Bird	; DDZ $C ; Doomsday skips loading animals, but this is what would load if it did
		dc.b Bird,	Chicken	; ??Z $D ; Intro and Ending
		dc.b Bird,	Chicken	; ALZ $E
		dc.b Bird,	Chicken	; BPZ $F
		dc.b Bird,	Chicken	; CGZ $10
		dc.b Bird,	Chicken	; DPZ $11
		dc.b Bird,	Chicken	; EMZ $12
		dc.b Bird,	Chicken	; GBZ $13 ; Gumball
		dc.b Bird,	Chicken	; SCZ $14 ; Glowing Spheres
		dc.b Bird,	Chicken	; SCZ $15 ; Slot Machine
		dc.b Bird,	Chicken	; HPZ $16 ; Act 1
		dc.b Bird,	Chicken	; HPZ $16 ; Act 2

;		dc.b 5, 1
;		dc.b 0, 3
;		dc.b 5, 1
;		dc.b 0, 5
;		dc.b 6, 5
;		dc.b 2, 3
;		dc.b 5, 1
;		dc.b 6, 1
;		dc.b 0, 1
;		dc.b 5, 1
;		dc.b 0, 5
;		dc.b 6, 1
;		dc.b 6, 5
;		dc.b 5, 1
;		dc.b 5, 1
;		dc.b 5, 1
;		dc.b 5, 1
;		dc.b 5, 1
;		dc.b 5, 1
;		dc.b 5, 1
;		dc.b 5, 1
;		dc.b 5, 1
;		dc.b 5, 1
;		dc.b 5, 1
ObjAnimal_Properties:	; This table declares the speed and mappings of each animal.
		dc.w -$200, -$400 ; Rabbit
		dc.l Map_Animals5
		dc.w -$200, -$300 ; Chicken
		dc.l Map_Animals1
		dc.w -$180, -$300 ; Penguin
		dc.l Map_Animals5
		dc.w -$140, -$180 ; Seal
		dc.l Map_Animals4
		dc.w -$1C0, -$300 ; Pig
		dc.l Map_Animals3
		dc.w -$300, -$400 ; Bird
		dc.l Map_Animals1
		dc.w -$280, -$380 ; Squirrel
		dc.l Map_Animals2
		dc.w -$280, -$300 ; Eagle
		dc.l Map_Animals1
		dc.w -$200, -$380 ; Mouse
		dc.l Map_Animals2
		dc.w -$2C0, -$300 ; Beaver
		dc.l Map_Animals2
		dc.w -$140, -$200 ; Turtle
		dc.l Map_Animals2
		dc.w -$200, -$300 ; Bear
		dc.l Map_Animals2

ObjAnimal_Speeds:
		dc.w -$440, -$400	; 0
		dc.w -$440, -$400	; 2
		dc.w -$440, -$400	; 4
		dc.w -$300, -$400	; 6
		dc.w -$300, -$400	; 8
		dc.w -$180, -$300	; 10
		dc.w -$180, -$300	; 12
		dc.w -$140, -$180	; 14
		dc.w -$1C0, -$300	; 16
		dc.w -$200, -$300	; 18
		dc.w -$280, -$380	; 20

ObjAnimal_Mappings:
		dc.l Map_Animals1
		dc.l Map_Animals1
		dc.l Map_Animals1
		dc.l Map_Animals5
		dc.l Map_Animals5
		dc.l Map_Animals5
		dc.l Map_Animals5
		dc.l Map_Animals4
		dc.l Map_Animals3
		dc.l Map_Animals1
		dc.l Map_Animals2

ObjAnimal_ArtLocations:
		dc.w  ArtTile_ArtNem_S1EndFlicky	;  0	Flicky
		dc.w  ArtTile_ArtNem_S1EndFlicky	;  1	Flicky
		dc.w  ArtTile_ArtNem_S1EndFlicky	;  2	Flicky
		dc.w  ArtTile_ArtNem_S1EndRabbit	;  3	Rabbit
		dc.w  ArtTile_ArtNem_S1EndRabbit	;  4	Rabbit
		dc.w  ArtTile_ArtNem_S1EndPenguin	;  5	Penguin
		dc.w  ArtTile_ArtNem_S1EndPenguin	;  6	Penguin
		dc.w  ArtTile_ArtNem_S1EndSeal		;  7	Seal
		dc.w  ArtTile_ArtNem_S1EndPig		;  8	Pig
		dc.w  ArtTile_ArtNem_S1EndChicken	;  9	Chicken
		dc.w  ArtTile_ArtNem_S1EndSquirrel	; 10	Squirrel
; ---------------------------------------------------------------------------

ObjAnimal_Init:
		tst.b	obSubtype(a0)
		beq.w	ObjAnimalRandom
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		add.w	d0,d0
		move.b	d0,obRoutine(a0)
		subi.w	#$14,d0
		move.w	ObjAnimal_ArtLocations(pc,d0.w),obGfx(a0)
		add.w	d0,d0
		move.l	ObjAnimal_Mappings(pc,d0.w),obMap(a0)
		lea	ObjAnimal_Speeds(pc),a1
		move.w	(a1,d0.w),animal_ground_x_vel(a0)
		move.w	(a1,d0.w),obVelX(a0)
		move.w	2(a1,d0.w),animal_ground_y_vel(a0)
		move.w	2(a1,d0.w),obVelY(a0)
		move.b	#$C,obHeight(a0)
		move.b	#4,obRender(a0)
		bset	#0,obRender(a0)
		move.w	#$300,obPriority(a0)
		move.b	#8,obActWid(a0)
		move.b	#7,obTimeFrame(a0)
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

ObjAnimalRandom:
		addq.b	#2,obRoutine(a0)
		bsr.w	Random_Number
		move.w	#make_art_tile($580,0,0),obGfx(a0)
		andi.w	#1,d0
		beq.s	+
		move.w	#make_art_tile($592,0,0),obGfx(a0)
+
		moveq	#0,d1
		move.b	(Current_Zone).w,d1
		add.w	d1,d1
		add.w	d0,d1
		lea	ObjAnimal_ZoneAnimals(pc),a1
		move.b	(a1,d1.w),d0
		move.b	d0,animal_ground_routine_base(a0)
		lsl.w	#3,d0
		lea	ObjAnimal_Properties(pc),a1
		adda.w	d0,a1
		move.w	(a1)+,animal_ground_x_vel(a0)
		move.w	(a1)+,animal_ground_y_vel(a0)
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
		_move.b	#id_Obj2A,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	objoff_3E(a0),d0
		lsr.w	#1,d0
		move.b	d0,obFrame(a1)
+		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
+
		move.b	#$1C,obRoutine(a0)
		clr.w	obVelX(a0)
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

;ObjAnimal_Delete:
	;	jmp	(DeleteObject).l
; ---------------------------------------------------------------------------

ObjAnimal_Main:
		tst.b	obRender(a0)
		bpl.w	DeleteObject
		bsr.w	ObjectMoveAndFall
		tst.w	obVelY(a0)
		bmi.s	+
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	+
		add.w	d1,obY(a0)
		move.w	animal_ground_x_vel(a0),obVelX(a0)
		move.w	animal_ground_y_vel(a0),obVelY(a0)
		move.b	#1,obFrame(a0)
		move.b	animal_ground_routine_base(a0),d0
		add.b	d0,d0
		addq.b	#4,d0
		move.b	d0,obRoutine(a0)
		tst.b	objoff_38(a0)
		beq.s	+
		btst	#4,(Vint_runcount+3).w
		beq.s	+
		neg.w	obVelX(a0)
		bchg	#0,obRender(a0)
+		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

ObjAnimal_Walk:
		bsr.w	ObjectMoveAndFall
		move.b	#1,obFrame(a0)
		tst.w	obVelY(a0)
		bmi.s	+
		clr.b	obFrame(a0)
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	+
		add.w	d1,obY(a0)
		move.w	animal_ground_y_vel(a0),obVelY(a0)
+
		tst.b	obSubtype(a0)
		bne.s	ObjAnimal_ChkDel
		tst.b	obRender(a0)
		bpl.w	DeleteObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

ObjAnimal_Fly:
		bsr.w	ObjectMove
		addi.w	#$18,obVelY(a0)
		tst.w	obVelY(a0)
		bmi.s	+
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	+
		add.w	d1,obY(a0)
		move.w	animal_ground_y_vel(a0),obVelY(a0)
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
		bne.s	ObjAnimal_ChkDel
		tst.b	obRender(a0)
		bpl.w	DeleteObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

ObjAnimal_ChkDel:
		move.w	obX(a0),d0
		sub.w	(v_player+obX).w,d0
		bcs.s	+
		subi.w	#384,d0
		bpl.s	+
		tst.b	obRender(a0)
		bpl.w	DeleteObject
+		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

ObjAnimal_Prison:
		tst.b	obRender(a0)
		bpl.w	DeleteObject
		subq.w	#1,objoff_36(a0)
		bne.w	+
		move.b	#2,obRoutine(a0)
		move.w	#$80,obPriority(a0)
+		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

ObjAnimal_FlickyWait:
		bsr.w	ChkAnimalInRange
		bcc.s	ObjAnimal_ChkDel
		move.w	animal_ground_x_vel(a0),obVelX(a0)
		move.w	animal_ground_y_vel(a0),obVelY(a0)
		move.b	#$E,obRoutine(a0)
		bra.w	ObjAnimal_Fly
; ---------------------------------------------------------------------------

ObjAnimal_FlickyJump:
		bsr.w	ChkAnimalInRange
		bpl.s	ObjAnimal_ChkDel
		clr.w	obVelX(a0)
		clr.w	animal_ground_x_vel(a0)
		bsr.w	ObjectMove
		addi.w	#$18,obVelY(a0)
		bsr.w	AnimalJump
		bsr.w	AnimalFaceSonic
		subq.b	#1,obTimeFrame(a0)
		bpl.w	ObjAnimal_ChkDel
		move.b	#1,obTimeFrame(a0)
		addq.b	#1,obFrame(a0)
		andi.b	#1,obFrame(a0)
		bra.w	ObjAnimal_ChkDel
; ---------------------------------------------------------------------------

ObjAnimal_RabbitWait:
		bsr.w	ChkAnimalInRange
		bpl.w	ObjAnimal_ChkDel
		move.w	animal_ground_x_vel(a0),obVelX(a0)
		move.w	animal_ground_y_vel(a0),obVelY(a0)
		move.b	#4,obRoutine(a0)
		bra.w	ObjAnimal_Walk
; ---------------------------------------------------------------------------

ObjAnimal_DoubleBounce:
		bsr.w	ObjectMoveAndFall
		move.b	#1,obFrame(a0)
		tst.w	obVelY(a0)
		bmi.w	ObjAnimal_ChkDel
		clr.b	obFrame(a0)
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.w	ObjAnimal_ChkDel
		not.b	objoff_2D(a0) ; used to be objoff_29 in Sonic 1/2; in sonic 3, 29 is a "convention followed by many objects", so it was changed
		bne.s	+
		neg.w	obVelX(a0)
		bchg	#0,obRender(a0)
+
		add.w	d1,obY(a0)
		move.w	animal_ground_y_vel(a0),obVelY(a0)
		bra.w	ObjAnimal_ChkDel
; ---------------------------------------------------------------------------

ObjAnimal_LandJump:
		bsr.w	ChkAnimalInRange
		bpl.w	ObjAnimal_ChkDel
		clr.w	obVelX(a0)
		clr.w	animal_ground_x_vel(a0)
		bsr.w	ObjectMoveAndFall
		bsr.w	AnimalJump
		bsr.w	AnimalFaceSonic
		bra.w	ObjAnimal_ChkDel
; ---------------------------------------------------------------------------

ObjAnimal_SingleBounce:
		bsr.w	ChkAnimalInRange
		bpl.w	ObjAnimal_ChkDel
		bsr.w	ObjectMoveAndFall
		move.b	#1,obFrame(a0)
		tst.w	obVelY(a0)
		bmi.s	ObjAnimal_ChkDel
		clr.b	obFrame(a0)
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.w	ObjAnimal_ChkDel
		neg.w	obVelX(a0)
		bchg	#0,obRender(a0)
		add.w	d1,obY(a0)
		move.w	animal_ground_y_vel(a0),obVelY(a0)
		bra.w	ObjAnimal_ChkDel
; ---------------------------------------------------------------------------

ObjAnimal_FlyBounce:
		bsr.w	ChkAnimalInRange
		bpl.w	ObjAnimal_ChkDel
		bsr.w	ObjectMove
		addi.w	#$18,obVelY(a0)
		tst.w	obVelY(a0)
		bmi.s	++
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	++
		not.b	objoff_2D(a0) ; used to be objoff_29 in Sonic 1/2; in sonic 3, 29 is a "convention followed by many objects", so it was changed
		bne.s	+
		neg.w	obVelX(a0)
		bchg	#0,obRender(a0)
+
		add.w	d1,obY(a0)
		move.w	animal_ground_y_vel(a0),obVelY(a0)
+
		subq.b	#1,obTimeFrame(a0)
		bpl.w	ObjAnimal_ChkDel
		move.b	#1,obTimeFrame(a0)
		addq.b	#1,obFrame(a0)
		andi.b	#1,obFrame(a0)
		bra.w	ObjAnimal_ChkDel

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
		move.w	animal_ground_y_vel(a0),obVelY(a0)
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