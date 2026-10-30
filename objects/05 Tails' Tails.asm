; S3&K tail animation and separate nine-tile art bank.
Obj05:
		tst.b	obRoutine(a0)
		bne.s	Obj_Tails_Tail_Main
Obj_Tails_Tail:
		; Init
		move.l	#Map_Tails_Tail,obMap(a0)
		move.b	#Map_Tails_Tail_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_TailsTails,0,0),obGfx(a0)
		move.w	#$100,obPriority(a0)
		move.b	#sprite_bound($18,Map_Tails_Tail_width),width_pixels(a0)
		move.b	#4,obRender(a0)
		move.b	#2,obRoutine(a0)

Obj_Tails_Tail_Main:
		movea.w	obParent(a0),a2
		cmpi.l	#Obj02,code(a2)
		beq.s	.inherit
		cmpi.l	#BonusPlayer,code(a2)
		bne.w	DeleteObject
		cmpi.b	#CharacterID_Tails,character_id(a2)
		bne.w	DeleteObject
		tst.w	(Debug_placement_mode).w
		bne.w	TailS3_loc_1615A.hide	; stage Debug displays a cursor or body-frame preview
.inherit:

		; Here, several SSTs are inherited from the parent, normally Tails
		move.b	obAngle(a2),obAngle(a0)
		move.b	obStatus(a2),obStatus(a0)
		move.w	obX(a2),obX(a0)
		move.w	obY(a2),obY(a0)
		move.w	obPriority(a2),obPriority(a0)
		andi.w	#drawing_mask,obGfx(a0)
		tst.w	obGfx(a2)
		bpl.s	TailS3_loc_16106
		ori.w	#high_priority,obGfx(a0)

TailS3_loc_16106:
		moveq	#0,d0
		move.b	obAnim(a2),d0
		btst	#status.player.pushing,obStatus(a2)
		beq.s	TailS3_loc_1612C
		tst.b	(f_wtunnelmode).w
		bne.s	TailS3_loc_1612C
		; This is checking if parent (Tails) is in its pushing animation
		cmpi.b	#$A9,obFrame(a2)
		blo.s	TailS3_loc_1612C
		cmpi.b	#$AC,obFrame(a2)
		bhi.s	TailS3_loc_1612C
		moveq	#4,d0

TailS3_loc_1612C:
		cmp.b	objoff_38(a0),d0	; Has the input parent obAnim changed since last check?
		beq.s	TailS3_loc_1613C		; If not, branch and skip setting a matching Tails' Tails obAnim
		move.b	d0,objoff_38(a0)	; Store d0 for the above comparison
		move.b	Obj_Tails_Tail_AniSelection(pc,d0.w),obAnim(a0)	; Load obAnim relative to parent's

TailS3_loc_1613C:
		lea	(AniTails_Tail).l,a1
		bsr.w	Animate_Tails_Part2
TailS3_loc_1615A:
		movea.w	obParent(a0),a2	; directional CalcAngle uses a2 as its lookup pointer
		cmpi.l	#BonusPlayer,code(a2)
		beq.s	.stage_art
		bsr.w	LoadTailsTailsDynPLC
		bra.s	.art_ready
.stage_art:
		jsr	(LoadSpecialStageTailsTailPLC).l
.art_ready:
		movea.w	obParent(a0),a2
		tst.b	tails_hidden(a2)		; use the exact decision made by Tails_Display
		beq.s	.show
.hide:
		andi.b	#$7F,obRender(a0)
		rts
.show:
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------
; animation master script table for the tails
; chooses which animation script to run depending on what Tails is doing

Obj_Tails_Tail_AniSelection:
		dc.b 0,0	; TailsAni_Walk,Run	->
		dc.b 3		; TailsAni_Roll		-> Directional
		dc.b 3		; TailsAni_Roll2	-> Directional
		dc.b 9		; TailsAni_Push		-> Pushing
		dc.b 1		; TailsAni_Wait		-> Swish
		dc.b 0		; TailsAni_Balance	-> Blank
		dc.b 2		; TailsAni_LookUp	-> Flick
		dc.b 1		; TailsAni_Duck		-> Swish
		dc.b 7		; TailsAni_Spindash	-> Spindash
		dc.b 0,0,0	; TailsAni_Dummy1,2,3	->
		dc.b 8		; TailsAni_Stop		-> Skidding
		dc.b 0,0	; TailsAni_Float,2	->
		dc.b 0		; TailsAni_Spring	->
		dc.b 0		; TailsAni_Hang		->
		dc.b 0		;
		dc.b 0		; TailsAni_Victory	->
		dc.b $A		; TailsAni_Hang2	-> Hanging
		dc.b 0		; TailsAni_Bubble	->
		dc.b 0,0,0	; TailsAni_Death,2,3	->
		dc.b 0		; TailsAni_Slide2?	->
		dc.b 0,0	; TailsAni_Hurt,Slide	->
		dc.b 0		; TailsAni_Blank	->
		dc.b 0,0	; TailsAni_Dummy4,5	->
		dc.b 0		; TailsAni_HaulAss	->
		dc.b $B,$C	; TailsAni_Fly,2	-> Fly1,2
		dc.b $B		; TailsAni_Carry	-> Fly1
		dc.b $C		; TailsAni_Ascend	-> Fly2
		dc.b $B		; TailsAni_Tired	-> Fly1
		dc.b 0,0	; TailsAni_Swim,2	->
		dc.b 0		; TailsAni_Tired2	->
		dc.b 0		; TailsAni_Tired3	->
		dc.b 0
		dc.b 0
		dc.b 0
		dc.b 0
		dc.b 0
		dc.b 0
		dc.b 0
		dc.b 0
		dc.b 0
		even
AniTails_Tail:
		include "animations/Tails tails.asm"
; ---------------------------------------------------------------------------
