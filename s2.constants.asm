; ===========================================================================
; size variables - you'll get an informational error if you need to change these...
; they are all in units of bytes
Size_of_DAC_samples =		$2F00
Size_of_SEGA_sound =		$6978
Size_of_Snd_driver_guess =	$F64 ; approximate post-compressed size of the Z80 sound driver
; ---------------------------------------------------------------------------
; Object Status Table offsets
; ---------------------------------------------------------------------------

; Object variables
obID:			equ 0		; object ID number
obRender:		equ 1		; bitfield for x/y flip, display mode
obGfx:			equ 2		; palette line & VRAM setting (2 bytes)
obMap:			equ 4		; mappings address (4 bytes)
obX:			equ 8		; x-axis position (2-4 bytes)
obXSub:			equ $A		; for when exra presition is required (2 bytes)
obY:			equ $C		; y-axis position (2-4 bytes)
obYSub:			equ $E		; for when exra presition is required (2 bytes)
obVelX:			equ $10		; x-axis velocity (2 bytes)
obVelY:			equ $12		; y-axis velocity (2 bytes)
obInertia:		equ $20		; potential speed (2 bytes)
obHeight:		equ $16		; height/2; y_radius
obWidth:		equ $14		; width/2 ; x_radius
obPriority:		equ $18		; sprite stack priority -- 0 is front
obActWid:		equ $19		; action width
obFrame:		equ $1A		; current frame displayed
obAniFrame:		equ $1B		; current frame in animation script
obAnim:			equ $1C		; current animation
obPrevAni:		equ $1D		; previous animation
obTimeFrame:		equ $1E		; time to next frame
obDelayAni:		equ $1F		; time to delay animation
obColType:		equ $20		; collision response type
obColProp:		equ $21		; collision extra property
obStatus:		equ $22		; orientation or mode
obRespawnNo:		equ $23		; respawn list index number
obRoutine:		equ $24		; routine number
ob2ndRout:		equ $25		; secondary routine number
obAngle:		equ $26		; angle
obSubtype:		equ $28		; object subtype
obControl:		equ $2A		; 0 for normal, 1 for hanging or for resting on a flipper, $81 for going through CNZ/OOZ/MTZ tubes or stopped in CNZ cages or stoppers or flying if Tails
obSolid:	equ ob2ndRout		; solid status flag

obTopSolidBit:		equ $3E		; bit to check for top solidity (either $C or $E)
obLRBSolidBit:		equ $3F		; bit to check for left/right/bottom solidity (either $D or $F)

; Object variables used by Sonic/Tails
; v_air:		equ $28
flashtime:		equ $30		; time between flashes after getting hit
invtime:		equ $32		; time left for invincibility
shoetime:		equ $34		; time left for speed shoes
stick_to_convex:	equ $38
spindash_flag:		equ $39		; 0 for normal, 1 for charging a spindash or forced rolling
standonobject:		equ $3D		; object Sonic stands on

; ---------------------------------------------------------------------------
; Miscellaneous object scratch-RAM
objoff_25:		equ $25
objoff_26:		equ $26
objoff_27:		equ $27
objoff_29:		equ $29
objoff_2A:		equ $2A
objoff_2B:		equ $2B
objoff_2C:		equ $2C
objoff_2D:		equ $2D
objoff_2E:		equ $2E
objoff_2F:		equ $2F
objoff_30:		equ $30
objoff_32:		equ $32
objoff_33:		equ $33
objoff_34:		equ $34
objoff_35:		equ $35
objoff_36:		equ $36
objoff_37:		equ $37
objoff_38:		equ $38
objoff_39:		equ $39
objoff_3A:		equ $3A
objoff_3B:		equ $3B
objoff_3C:		equ $3C
objoff_3D:		equ $3D
objoff_3E:		equ $3E
objoff_3F:		equ $3F
; ---------------------------------------------------------------------------
; conventions followed by several objects but NOT Sonic/Tails:
obScreenX =		obX ; and 1+x_pos ; x coordinate for objects using screen-space coordinate system (S2 x_pixel)
obScreenY =		obXSub ; and 3+x_pos ; y coordinate for objects using screen-space coordinate system (S2 y_pixel)
parent =		objoff_3E ; and $3F ; address of object that owns or spawned this one, if applicable

object_size_bits:	equ 6
object_size:		equ 1<<object_size_bits
next_object =		object_size

; ---------------------------------------------------------------------------
; when childsprites are activated (i.e. bit #6 of render_flags set)
next_subspr		= 6
mainspr_mapframe	= $B
mainspr_width		= $E
mainspr_childsprites	= $F	; amount of child sprites
mainspr_height	= $14
subspr_data	= $10
sub2_x_pos	= subspr_data+next_subspr*0+0	;x_vel
sub2_y_pos	= subspr_data+next_subspr*0+2	;y_vel
sub2_mapframe	= subspr_data+next_subspr*0+5
sub3_x_pos	= subspr_data+next_subspr*1+0	;y_radius
sub3_y_pos	= subspr_data+next_subspr*1+2	;priority
sub3_mapframe	= subspr_data+next_subspr*1+5	;anim_frame
sub4_x_pos	= subspr_data+next_subspr*2+0	;anim
sub4_y_pos	= subspr_data+next_subspr*2+2	;anim_frame_duration
sub4_mapframe	= subspr_data+next_subspr*2+5	;collision_property
sub5_x_pos	= subspr_data+next_subspr*3+0	;status
sub5_y_pos	= subspr_data+next_subspr*3+2	;routine
sub5_mapframe	= subspr_data+next_subspr*3+5
sub6_x_pos	= subspr_data+next_subspr*4+0	;subtype
sub6_y_pos	= subspr_data+next_subspr*4+2
sub6_mapframe	= subspr_data+next_subspr*4+5
sub7_x_pos	= subspr_data+next_subspr*5+0
sub7_y_pos	= subspr_data+next_subspr*5+2
sub7_mapframe	= subspr_data+next_subspr*5+5
sub8_x_pos	= subspr_data+next_subspr*6+0
sub8_y_pos	= subspr_data+next_subspr*6+2
sub8_mapframe	= subspr_data+next_subspr*6+5
sub9_x_pos	= subspr_data+next_subspr*7+0
sub9_y_pos	= subspr_data+next_subspr*7+2
sub9_mapframe	= subspr_data+next_subspr*7+5

; ---------------------------------------------------------------------------
; Object Status Table offsets S2 Nomemclature
; ---------------------------------------------------------------------------
; universally followed object conventions:
id =			  0 ; object ID (if you change this, change insn1op and insn2op in s2.macrosetup.asm, if you still use them)
render_flags =		  1 ; bitfield ; bit 7 = onscreen flag, bit 0 = x mirror, bit 1 = y mirror, bit 2 = coordinate system, bit 6 = render subobjects
art_tile =		  2 ; and 3 ; start of sprite's art
mappings =		  4 ; and 5 and 6 and 7
x_pos =			  8 ; and 9 ... some objects use $A and $B as well when extra precision is required (see ObjectMove) ... for screen-space objects this is called x_pixel instead
x_sub =			 $A ; and $B
y_pos =			 $C ; and $D ... some objects use $E and $F as well when extra precision is required ... screen-space objects use y_pixel instead
y_sub =			 $E ; and $F
priority =		$18 ; 0 = front
width_pixels =		$19
mapping_frame =		$1A
; ---------------------------------------------------------------------------
; conventions followed by most objects:
x_vel =			$10 ; and $11 ; horizontal velocity
y_vel =			$12 ; and $13 ; vertical velocity
y_radius =		$16 ; collision height / 2
x_radius =		$17 ; collision width / 2
anim_frame =		$1B
anim =			$1C
prev_anim =		$1D
anim_frame_duration =	$1E
status =		$22 ; note: exact meaning depends on the object... for sonic/tails: bit 0: leftfacing. bit 1: inair. bit 2: spinning. bit 3: onobject. bit 4: rolljumping. bit 5: pushing. bit 6: underwater.
routine =		$24
routine_secondary =	$25
angle =			$26 ; angle about the z axis (360 degrees = 256)
; ---------------------------------------------------------------------------
; conventions followed by many objects but NOT sonic/tails:
collision_flags =	$20
collision_property =	$21
respawn_index =		$23
subtype =		$28
; ---------------------------------------------------------------------------
; Levels
id_GHZ:	equ 0
id_LZ:	equ 1
id_CPZ:	equ 2
id_MZ:	equ 2
id_EHZ:	equ 3
id_SLZ:	equ 3
id_HPZ:	equ 4
id_SYZ:	equ 4
id_HTZ:	equ 5
id_SBZ:	equ 5
id_EndZ:	equ 6
id_SS:	equ 7

; Colours
cBlack:		equ $000				; colour black
cWhite:		equ $EEE				; colour white
cBlue:		equ $E00				; colour blue
cGreen:		equ $0E0				; colour green
cRed:		equ $00E				; colour red
cYellow:	equ cGreen+cRed				; colour yellow
cAqua:		equ cGreen+cBlue			; colour aqua
cMagenta:	equ cBlue+cRed				; colour magenta
cCyan:		equ $880				; colour cyan
; ---------------------------------------------------------------------------
; Controller Buttons

; Buttons bit numbers
bitUp:	EQU	0
bitDn:	EQU	1
bitL:	EQU	2
bitR:	EQU	3
bitB:	EQU	4
bitC:	EQU	5
bitA:	EQU	6
bitStart:	EQU	7
; Buttons masks (1 << x == pow(2, x))
btnUp:	EQU	1<<bitUp		; $01
btnDn:	EQU	1<<bitDn		; $02
btnL:	EQU	1<<bitL			; $04
btnR:	EQU	1<<bitR			; $08
btnB:	EQU	1<<bitB			; $10
btnC:	EQU	1<<bitC			; $20
btnA:	EQU	1<<bitA			; $40
btnABC:	EQU	btnA|btnB|btnC		; $70
btnStart:	EQU	1<<bitStart	; $80
; ---------------------------------------------------------------------------
; Art tile stuff
flip_x              =      (1<<11)
flip_y              =      (1<<12)
palette_bit_0       =      5
palette_bit_1       =      6
palette_line_0      =      (0<<13)
palette_line_1      =      (1<<13)
palette_line_2      =      (2<<13)
palette_line_3      =      (3<<13)
high_priority_bit   =      7
high_priority       =      (1<<15)
palette_mask        =      $6000
tile_mask           =      $7FF
nontile_mask        =      $F800
drawing_mask        =      $7FFF

; Animation IDs
	phase 0
AniIDSonAni_Walk:		ds.b 1
AniIDSonAni_Run:		ds.b 1
AniIDSonAni_Roll:		ds.b 1
AniIDSonAni_Roll2:		ds.b 1
AniIDSonAni_Push:		ds.b 1
AniIDSonAni_Wait:		ds.b 1
AniIDSonAni_Balance:		ds.b 1
AniIDSonAni_LookUp:		ds.b 1
AniIDSonAni_Duck:		ds.b 1
AniIDSonAni_Spindash:		ds.b 1
AniIDSonAni_WallRecoil1:	ds.b 1
AniIDSonAni_WallRecoil2:	ds.b 1
AniIDSonAni_0C:			ds.b 1
AniIDSonAni_Stop:		ds.b 1
AniIDSonAni_Float:		ds.b 1
AniIDSonAni_Float2:		ds.b 1
AniIDSonAni_Spring:		ds.b 1
AniIDSonAni_Hang:		ds.b 1
AniIDSonAni_Unused12:		ds.b 1
AniIDSonAni_Unused13:		ds.b 1
AniIDSonAni_Unused14:		ds.b 1
AniIDSonAni_Bubble:		ds.b 1
AniIDSonAni_DeathBW:		ds.b 1
AniIDSonAni_Drown:		ds.b 1
AniIDSonAni_Death:		ds.b 1
AniIDSonAni_Unused19:		ds.b 1
AniIDSonAni_Hurt:		ds.b 1
AniIDSonAni_Slide:		ds.b 1
AniIDSonAni_Blank:		ds.b 1
AniIDSonAni_Float3:		ds.b 1
AniIDSonAni_1E:			ds.b 1
	dephase
	!org 0

Size_of_SegaPCM:		equ $6978
Size_of_DAC_driver_guess:	equ $1760

; Clocks
Master_Clock:    equ 53693175
M68000_Clock:    equ Master_Clock/7
Z80_Clock:       equ Master_Clock/15
FM_Sample_Rate:  equ M68000_Clock/(6*6*4)
PSG_Sample_Rate: equ Z80_Clock/16

; Z80 addresses
Z80_RAM:		equ $A00000			; start of Z80 RAM
Z80_RAM_end:		equ $A02000			; end of non-reserved Z80 RAM
Z80_version:		equ $A10001
Z80_port_1_data:	equ $A10002
Z80_port_1_control:	equ $A10008
Z80_port_2_control:	equ $A1000A
Z80_expansion_control:	equ $A1000C
Z80_Bus_Request:	equ $A11100
Z80_Reset:		equ $A11200
ym2612_a0:		equ $A04000
ym2612_d0:		equ $A04001
ym2612_a1:		equ $A04002
ym2612_d1:		equ $A04003

security_addr:		equ $A14000

; VDP addressses
vdp_data_port:		equ $C00000
vdp_control_port:	equ $C00004
VDP_control_port = vdp_control_port
vdp_counter:		equ $C00008

psg_input:		equ $C00011

; VRAM data
vram_window:		equ $A000			; window namespace
vram_fg:		equ $C000			; foreground namespace
vram_bg:		equ $E000			; background namespace
vram_sprites:		equ $F800			; sprite table
vram_hscroll:		equ $FC00			; horizontal scroll table
tile_size:		equ 8*8/2
plane_size_64x32:	equ 64*32*2

palette_size:		equ $80
PLCKosPlusM_Count:	= 32

; ===========================================================================
; ---------------------------------------------------------------------------
; V-Int routines
offset :=	Vint_SwitchTbl
ptrsize :=	1
idstart :=	0

VintID_Lag =		id(Vint_Lag_ptr)	; 0
VintID_SEGA =		id(Vint_SEGA_ptr)	; 2
VintID_Title =		id(Vint_Title_ptr)	; 4
VintID_Level =		id(Vint_Level_ptr)	; 6
VintID_S1SS =		id(Vint_S1SS_ptr)	; 8
VintID_TitleCard =	id(Vint_TitleCard_ptr)	; $A
VintID_Pause =		id(Vint_Pause_ptr)	; $C
VintID_Fade =		id(Vint_Fade_ptr)	; $E
VintID_PCM =		id(Vint_PCM_ptr)	; $10
VintID_SSResults =	id(Vint_SSResults_ptr)	; $12
VintID_TitleCard2 =	id(Vint_TitleCard2_ptr)	; $14

; Game modes
offset :=	GameModeArray
ptrsize :=	1
idstart :=	0

GameModeID_SegaScreen =		id(GameMode_SegaScreen)	; 0
GameModeID_TitleScreen =	id(GameMode_TitleScreen) ; 4
GameModeID_Demo =		id(GameMode_Demo)	; 8
GameModeID_Level =		id(GameMode_Level)	; $C
GameModeID_SpecialStage =	id(GameMode_SpecialStage) ; $10
GameModeID_ContinueScreen =	id(GameMode_Continue)	; $14 ; (TODO)
GameModeID_Ending =		id(GameMode_Ending)	; $18 ; (TODO)
GameModeID_Credits =		id(GameMode_Credits)	; $1C ; (TODO)
GameModeID_Options =		id(GameMode_Options)	; $20 ; (TODO)
GameModeID_LevelSelect =	id(GameMode_SecretMenu)	; $24 ; (TODO)
GameModeFlag_TitleCard:		equ 7			; flag bit
GameModeID_TitleCard:		equ 1<<GameModeFlag_TitleCard ; $80 ; flag mask

	include "musicids.gen.asm"

	include "sfxids.gen.asm"

SndID_ArrowFiring = SndID_LavaBall
SndID_RingRight = SndID_Ring
SndID_WingFortress = SndID_Helicopter
SndID_Scatter = SndID_LaserFloor

; Sound command IDs
offset :=	zCommandIndex
ptrsize :=	2
idstart :=	$FA

CmdID__First = idstart
MusID_StopSFX =		id(CmdPtr_StopSFX)	; F8
MusID_FadeOut =		id(CmdPtr_FadeOut)	; F9
SndID_SegaSound =	id(CmdPtr_SegaSound)	; FA
MusID_SpeedUp =		id(CmdPtr_SpeedUp)	; FB
MusID_SlowDown =	id(CmdPtr_SlowDown)	; FC
MusID_Stop =		id(CmdPtr_Stop)		; FD
CmdID__End =		id(CmdPtr__End)		; FE

; Main RAM
	phase	ramaddr($FFFE0000)
RAM_debug_start:	ds.b	$10000
RAM_debug_end:

v_start:
RAM_Start:

Chunk_Table:		ds.w	$40*$100			; 128x128 tile mappings ($8000 bytes)
Chunk_Table_End:
v_128x128:=	Chunk_Table
v_128x128_end:=	Chunk_Table_End

Level_Layout:		ds.b	$1000			; level layout buffer ($1000 bytes)
Level_Layout_End:

v_lvllayout:=	Level_Layout
v_lvllayout_end:=	Level_Layout_End
v_lvllayoutbg:=	Level_Layout+$80
v_16x16:		ds.b	$1800			; $1800 bytes; unused

TempArray_LayerDef:	ds.b	$200			; background scroll buffer
Decomp_Buffer:		ds.b	$200			; Nemesis graphics decompression buffer
Decomp_Buffer_End:

v_bgscroll_buffer:=	TempArray_LayerDef
v_ngfx_buffer:=	Decomp_Buffer
v_ngfx_buffer_end:=	Decomp_Buffer_End

Object_Display_Lists:	ds.b	$400			; sprite display queue, in order of priority
Object_Display_Lists_End:

v_spritequeue:=	Object_Display_Lists
v_spritequeue_end:=	Object_Display_Lists_End

v_hscrolltablebuffer:	ds.b	$380			; scrolling table data
v_hscrolltablebuffer_end:
			ds.b	$80			; would be unused, but data from v_hscrolltablebuffer can spill into here
v_hscrolltablebuffer_end_padded:

Sonic_Stat_Record_Buf:	ds.b	$100
Sonic_Pos_Record_Buf:	ds.b	$100
Tails_Pos_Record_Buf:	ds.b	$100

Ring_Positions:		ds.b	$600
Ring_Positions_End:


v_objspace:		ds.b	object_size*$80		; object variable space ($40 bytes per object)
v_objspace_end:

; ---------------------------------------------------------------------------
; Title screen objects
v_sonicteam	= v_objspace+object_size*1		; object variable space for the "SONIC TEAM PRESENTS" text ($40 bytes)
v_titlesonic	= v_objspace+object_size*2		; object variable space for Sonic in the title screen ($40 bytes)
v_titletails	= v_objspace+object_size*3		; object variable space for Tails in the title screen ($40 bytes)
v_ttlsonichide	= v_objspace+object_size*4		; object variable space for hiding part of Sonic ($40 bytes)
v_pressstart	= v_objspace+object_size*5		; object variable space for the "PRESS START BUTTON" text ($40 bytes)
; ---------------------------------------------------------------------------
; Reserved object slots
v_player	= v_objspace+object_size*0		; object variable space for Sonic ($40 bytes)
v_player2	= v_objspace+object_size*1		; object variable space for Tails ($40 bytes)
v_shieldobj	= v_objspace+object_size*6		; object variable space for the shield ($40 bytes)
v_player2tails	= v_objspace+object_size*7		; object variable space for Tails' Tails ($40 bytes)
v_starsobj1	= v_objspace+object_size*8		; object variable space for the invincibility stars #1 ($40 bytes)
v_starsobj2	= v_objspace+object_size*9		; object variable space for the invincibility stars #2 ($40 bytes)
v_starsobj3	= v_objspace+object_size*10		; object variable space for the invincibility stars #3 ($40 bytes)
v_starsobj4	= v_objspace+object_size*11		; object variable space for the invincibility stars #4 ($40 bytes)

v_splash	= v_objspace+object_size*12		; object variable space for the water splash ($40 bytes)
v_sonicbubbles	= v_objspace+object_size*13		; object variable space for the bubbles that come out of Sonic's mouth/drown countdown ($40 bytes)
v_watersurface1	= v_objspace+object_size*30		; object variable space for the water surface #1 ($40 bytes)
v_watersurface2	= v_objspace+object_size*31		; object variable space for the water surface #2 ($40 bytes)
;		= v_objspace+object_size*14		; empty

v_gameovertext1	= v_objspace+object_size*2		; object variable space for the "GAME"/"TIME" in "GAME OVER"/"TIME OVER" text ($40 bytes)
v_gameovertext2	= v_objspace+object_size*3		; object variable space for the "OVER" in "GAME OVER"/"TIME OVER" text ($40 bytes)

; ---------------------------------------------------------------------------
; Start/End of level objects (Part of the above; used exclusively at the beginning/end of a level)
v_titlecard	= v_objspace+object_size*2		; object variable space for the title card ($100 bytes)
v_ttlcardname	= v_titlecard+object_size*0		; object variable space for the title card zone name text ($40 bytes)
v_ttlcardzone	= v_titlecard+object_size*1		; object variable space for the title card "ZONE" text ($40 bytes)
v_ttlcardact	= v_titlecard+object_size*2		; object variable space for the title card act text ($40 bytes)
v_ttlcardoval	= v_titlecard+object_size*3		; object variable space for the title card oval ($40 bytes)

v_endcard	= v_objspace+object_size*23		; object variable space for the level results card ($1C0 bytes)
v_endcardsonic	= v_endcard+object_size*0		; object variable space for the level results card "SONIC HAS" text ($40 bytes)
v_endcardpassed	= v_endcard+object_size*1		; object variable space for the level results card "PASSED" text ($40 bytes)
v_endcardact	= v_endcard+object_size*2		; object variable space for the level results card act text ($40 bytes)
v_endcardscore	= v_endcard+object_size*3		; object variable space for the level results card score tally ($40 bytes)
v_endcardtime	= v_endcard+object_size*4		; object variable space for the level results card time bonus tally ($40 bytes)
v_endcardring	= v_endcard+object_size*5		; object variable space for the level results card ring bonus tally ($40 bytes)
v_endcardoval	= v_endcard+object_size*6		; object variable space for the level results card oval ($40 bytes)
; ---------------------------------------------------------------------------
; Dynamic slots -- for all other objects
v_lvlobjspace	= v_objspace+object_size*32		; level object variable space ($1800 bytes)
v_lvlobjend	= v_lvlobjspace+object_size*96
v_objend	= v_lvlobjend

; Special Stage objects
v_ssrescard	= v_objspace+object_size*23		; object variable space for the Special Stage results card ($140 bytes)
v_ssrestext	= v_ssrescard+object_size*0		; object variable space for the Special Stage results card text ($40 bytes)
v_ssresscore	= v_ssrescard+object_size*1		; object variable space for the Special Stage results card score tally ($40 bytes)
v_ssresring	= v_ssrescard+object_size*2		; object variable space for the Special Stage results card ring bonus tally ($40 bytes)
v_ssresoval	= v_ssrescard+object_size*3		; object variable space for the Special Stage results card oval ($40 bytes)
v_ssrescontinue	= v_ssrescard+object_size*4		; object variable space for the Special Stage results card continue icon ($40 bytes)
v_ssresemeralds	= v_objspace+object_size*32		; object variable space for the emeralds in the Special Stage results ($180 bytes)

; Continue screen objects
v_continuetext	= v_objspace+object_size*1		; object variable space for the continue screen text ($40 bytes)
v_continuelight	= v_objspace+object_size*2		; object variable space for the continue screen light spot ($40 bytes)
v_continueicon	= v_objspace+object_size*3		; object variable space for the continue screen icon ($40 bytes)

; Ending objects
v_endemeralds	= v_objspace+object_size*16		; object variable space for the emeralds in the ending ($180 bytes)
v_endemeralds_end	= v_objspace+object_size*32
v_endlogo	= v_objspace+object_size*16		; object variable space for the logo in the ending ($40 bytes)

; Credits objects
v_credits	= v_objspace+object_size*2		; object variable space for the credits text ($40 bytes)
v_endeggman	= v_objspace+object_size*2		; object variable space for Eggman after the credits ($40 bytes)
v_tryagain	= v_objspace+object_size*3		; object variable space for the "TRY AGAIN" text ($40 bytes)
v_eggmanchaos	= v_objspace+object_size*32		; object variable space for the emeralds juggled by Eggman ($180 bytes)

Kos_decomp_buffer:		ds.b	$1000		; Moduled Kosinski+ decompression buffer

VDP_Command_Buffer:		ds.w	7*$12		; stores 18 ($12) VDP commands to issue the next time ProcessDMAQueue is called
VDP_Command_Buffer_Slot:	ds.w	1		; stores the address of the next open slot for a queued VDP command

Camera_RAM:
Camera_Positions:
Camera_X_pos:			ds.l	1
Camera_Y_pos:			ds.l	1
Camera_BG_X_pos:		ds.l	1	; only used sometimes as the layer deformation makes it sort of redundant
Camera_BG_Y_pos:		ds.l	1
Camera_BG2_X_pos:		ds.l	1	; used in CPZ
Camera_BG2_Y_pos:		ds.l	1	; used in CPZ
Camera_BG3_X_pos:		ds.l	1	; unused (only initialised at beginning of level)?
Camera_BG3_Y_pos:		ds.l	1	; unused (only initialised at beginning of level)?
Camera_Positions_End:

Camera_Positions_P2:
Camera_X_pos_P2:		ds.l	1
Camera_Y_pos_P2:		ds.l	1
Camera_BG_X_pos_P2:		ds.l	1	; only used sometimes as the layer deformation makes it sort of redundant
Camera_BG_Y_pos_P2:		ds.l	1
Camera_BG2_X_pos_P2:		ds.l	1	; unused (only initialised at beginning of level)?
Camera_BG2_Y_pos_P2:		ds.l	1
Camera_BG3_X_pos_P2:		ds.l	1	; unused (only initialised at beginning of level)?
Camera_BG3_Y_pos_P2:		ds.l	1
Camera_Positions_P2_End:

Block_Crossed_Flags:
Horiz_block_crossed_flag:	ds.b	1	; toggles between 0 and $10 when you cross a block boundary horizontally
Verti_block_crossed_flag:	ds.b	1	; toggles between 0 and $10 when you cross a block boundary vertically
Horiz_block_crossed_flag_BG:	ds.b	1	; toggles between 0 and $10 when background camera crosses a block boundary horizontally
Verti_block_crossed_flag_BG:	ds.b	1	; toggles between 0 and $10 when background camera crosses a block boundary vertically
Horiz_block_crossed_flag_BG2:	ds.b	1	; used in CPZ
				ds.b	1	; $FFFFEE45 ; seems unused
Horiz_block_crossed_flag_BG3:	ds.b	1
				ds.b	1	; $FFFFEE47 ; seems unused
Block_Crossed_Flags_End:

Block_Crossed_Flags_P2:
Horiz_block_crossed_flag_P2:	ds.b	1	; toggles between 0 and $10 when you cross a block boundary horizontally
Verti_block_crossed_flag_P2:	ds.b	1	; toggles between 0 and $10 when you cross a block boundary vertically
				ds.b	6	; $FFFFEE4A-$FFFFEE4F ; seems unused
Block_Crossed_Flags_P2_End:

Scroll_Flags_All:
Scroll_flags:			ds.w	1	; bitfield ; bit 0 = redraw top row, bit 1 = redraw bottom row, bit 2 = redraw left-most column, bit 3 = redraw right-most column
Scroll_flags_BG:		ds.w	1	; bitfield ; bits 0-3 as above, bit 4 = redraw top row (except leftmost block), bit 5 = redraw bottom row (except leftmost block), bits 6-7 = as bits 0-1
Scroll_flags_BG2:		ds.w	1	; bitfield ; essentially unused; bit 0 = redraw left-most column, bit 1 = redraw right-most column
Scroll_flags_BG3:		ds.w	1	; bitfield ; for CPZ; bits 0-3 as Scroll_flags_BG but using Y-dependent BG camera; bits 4-5 = bits 2-3; bits 6-7 = bits 2-3
Scroll_Flags_All_End:

Scroll_Flags_All_P2:
Scroll_flags_P2:		ds.w	1	; bitfield ; bit 0 = redraw top row, bit 1 = redraw bottom row, bit 2 = redraw left-most column, bit 3 = redraw right-most column
Scroll_flags_BG_P2:		ds.w	1	; bitfield ; bits 0-3 as above, bit 4 = redraw top row (except leftmost block), bit 5 = redraw bottom row (except leftmost block), bits 6-7 = as bits 0-1
Scroll_flags_BG2_P2:		ds.w	1	; bitfield ; essentially unused; bit 0 = redraw left-most column, bit 1 = redraw right-most column
Scroll_flags_BG3_P2:		ds.w	1	; bitfield ; for CPZ; bits 0-3 as Scroll_flags_BG but using Y-dependent BG camera; bits 4-5 = bits 2-3; bits 6-7 = bits 2-3
Scroll_Flags_All_P2_End:

Camera_Positions_Copy:
Camera_RAM_copy:		ds.l	2	; copied over every V-int
Camera_BG_copy:			ds.l	2	; copied over every V-int
Camera_BG2_copy:		ds.l	2	; copied over every V-int
Camera_BG3_copy:		ds.l	2	; copied over every V-int
Camera_Positions_Copy_End:

Camera_Positions_Copy_P2:
Camera_P2_copy:			ds.l	8	; copied over every V-int
Camera_Positions_Copy_P2_End:

Scroll_Flags_Copy_All:
Scroll_flags_copy:		ds.w	1	; copied over every V-int
Scroll_flags_BG_copy:		ds.w	1	; copied over every V-int
Scroll_flags_BG2_copy:		ds.w	1	; copied over every V-int
Scroll_flags_BG3_copy:		ds.w	1	; copied over every V-int
Scroll_Flags_Copy_All_End:

Scroll_Flags_Copy_All_P2:
Scroll_flags_copy_P2:		ds.w	1	; copied over every V-int
Scroll_flags_BG_copy_P2:	ds.w	1	; copied over every V-int
Scroll_flags_BG2_copy_P2:	ds.w	1	; copied over every V-int
Scroll_flags_BG3_copy_P2:	ds.w	1	; copied over every V-int
Scroll_Flags_Copy_All_P2_End:

Camera_Difference:
Camera_X_pos_diff:		ds.w	1	; (new X pos - old X pos) * 256
Camera_Y_pos_diff:		ds.w	1	; (new Y pos - old Y pos) * 256
Camera_Difference_End:

Camera_BG_X_pos_diff:		ds.w	1	; Effective camera change used in WFZ ending and HTZ screen shake
Camera_BG_Y_pos_diff:		ds.w	1	; Effective camera change used in WFZ ending and HTZ screen shake

Camera_Difference_P2:
Camera_X_pos_diff_P2:		ds.w	1	; (new X pos - old X pos) * 256
Camera_Y_pos_diff_P2:		ds.w	1	; (new Y pos - old Y pos) * 256
Camera_Difference_P2_End:

Screen_Shaking_Flag_HTZ:	ds.b	1	; activates screen shaking code in HTZ's layer deformation routine
Screen_Shaking_Flag:		ds.b	1	; activates screen shaking code (if existent) in layer deformation routine
Scroll_lock:			ds.b	1	; set to 1 to stop all scrolling for P1 -- for now, unused
				ds.b	1	; unused. if this was multiplayer, it'd be a copy of the above for player 2
Camera_Min_X_pos_target:	ds.w	1	; unused, except on write in LevelSizeLoad...
Camera_Max_X_pos_target:	ds.w	1	; unused
Camera_Min_Y_pos_target:	ds.w	1	; same as above. The write being a long also overwrites the address below
Camera_Max_Y_pos_target:	ds.w	1

Camera_Boundaries:
Camera_Min_X_pos:	ds.w	1
Camera_Max_X_pos:	ds.w	1
Camera_Min_Y_pos:	ds.w	1
Camera_Max_Y_pos:	ds.w	1
Camera_Boundaries_End:

Camera_Delay:
Horiz_scroll_delay_val:	ds.w	1			; if its value is a, where a != 0, X scrolling will be based on the player's X position a-1 frames ago
Sonic_Pos_Record_Index:	ds.w	1			; into Sonic_Pos_Record_Buf and Sonic_Stat_Record_Buf
Camera_Delay_End:

Camera_Delay_P2:
Horiz_scroll_delay_val_P2:	ds.w	1
Tails_Pos_Record_Index:	ds.w	1			; into Tails_Pos_Record_Buf
Camera_Delay_P2_End:

Camera_Y_pos_bias:	ds.w	1			; added to y position for lookup/lookdown, $60 is center
Camera_Y_pos_bias_End:

Camera_Y_pos_bias_P2:	ds.w	1			; for Tails
Camera_Y_pos_bias_P2_End:

Deform_lock:		ds.b	1			; set to 1 to stop all deformation
			ds.b	1			; $FFFFEEDD ; seems unused
Camera_Max_Y_Pos_Changing:	ds.b	1
Dynamic_Resize_Routine:	ds.b	1
			ds.w	1			; $FFFFEEE0-$FFFFEEE1
Camera_BG_X_offset:	ds.w	1			; Used to control background scrolling in X in WFZ ending and HTZ screen shake
Camera_BG_Y_offset:	ds.w	1			; Used to control background scrolling in Y in WFZ ending and HTZ screen shake
HTZ_Terrain_Delay:	ds.w	1			; During HTZ screen shake, this is a delay between rising and sinking terrain during which there is no shaking
HTZ_Terrain_Direction:	ds.b	1			; During HTZ screen shake, 0 if terrain/lava is rising, 1 if lowering
			ds.b	3			; $FFFFEEE9-$FFFFEEEB ; seems unused
Vscroll_Factor_P2_HInt:	ds.l	1
Camera_X_pos_copy:	ds.l	1
Camera_Y_pos_copy:	ds.l	1

Camera_Boundaries_P2:
Tails_Min_X_pos:	ds.w	1
Tails_Max_X_pos:	ds.w	1
Tails_Min_Y_pos:	ds.w	1			; seems not actually implemented (only written to)
Tails_Max_Y_pos:	ds.w	1
Camera_Boundaries_P2_End:

Camera_RAM_End:

Block_cache:		ds.w	512/16*2		; Width of plane in blocks, with each block getting two words.

v_gamemode:		ds.b	1			; game mode (00=Sega; 04=Title; 08=Demo; 0C=Level; 10=SS; 14=Cont; 18=End; 1C=Credit; +8C=PreLevel)
			ds.b	1			; unused
v_jpadhold2:		ds.b	1			; joypad input - held, duplicate
v_jpadpress2:		ds.b	1			; joypad input - pressed, duplicate
v_jpadhold1:		ds.b	1			; joypad input - held
v_jpadpress1:		ds.b	1			; joypad input - pressed
v_2Pjpadhold1:		ds.b	1			; joypad input - held
v_2Pjpadpress1:		ds.b	1			; joypad input - pressed
v_vdp_buffer1:		ds.w	1			; VDP instruction buffer
			ds.b	4			; used for the special stages; see below
v_demolength:		ds.w	1			; the length of a demo in frames
v_scrposy_vdp:		ds.w	1			; screen position y (VDP)
v_bgscrposy_vdp:	ds.w	1			; background screen position y (VDP)
v_scrposx_vdp:		ds.w	1			; screen position x (VDP)
v_bgscrposx_vdp:	ds.w	1			; background screen position x (VDP)
v_bg3scrposy_vdp:	ds.w	1
v_bg3scrposx_vdp:	ds.w	1
			ds.b	2			; unused
v_hbla_hreg:		ds.w	1			; VDP H.interrupt register buffer (8Axx)
v_hbla_line 		= v_hbla_hreg+1			; screen line where water starts and palette is changed by HBlank
v_pfade_start:		ds.b	1			; palette fading - start position in bytes
v_pfade_size:		ds.b	1			; palette fading - number of colours

v_misc_variables:
Lag_frame_count:	ds.w	1			; more specifically, the number of times V-int routine 0 has run. Reset at the end of a normal frame
v_vbla_routine:		ds.b	1			; VBlank - routine counter
v_spritecount:		ds.b	1			; number of sprites on-screen
			ds.b	1			; unused
f_hbla_pal:		ds.b	1			; flag set to change palette during HBlank (00 = no; 01 = change)
v_pcyc_num:		ds.w	1			; palette cycling - current reference number
v_pcyc_num2:		ds.w	1			; palette cycling - current reference number
v_pcyc_num3:		ds.w	1			; palette cycling - current reference number
v_pcyc_time:		ds.w	1			; palette cycling - time until the next change
v_pcyc_time2:		ds.w	1			; palette cycling - time until the next change
v_pcyc_time3:		ds.w	1			; palette cycling - time until the next change
v_random:		ds.l	1			; pseudo random number buffer
f_pause:		ds.w	1			; flag set to pause the game
v_vdp_buffer2:		ds.w	1			; VDP instruction buffer
v_waterpos1:		ds.w	1			; water height, actual
v_waterpos2:		ds.w	1			; water height, ignoring sway
v_waterpos3:		ds.w	1			; water height, next target
f_water:		ds.b	1			; flag set for water
v_wtr_routine:		ds.b	1			; water event - routine counter
f_wtr_state:		ds.b	1			; water palette state when water is above/below the screen (00 = partly/all dry; 01 = all underwater)
f_doupdatesinhblank:	ds.b	1			; defers performing various tasks to the Horizontal Interrupt (H-Blank)
v_pal_buffer:		ds.b	$30			; palette data buffer (used for palette cycling)
v_misc_variables_end:

v_plc_buffer:			ds.b	6*16		; pattern load cues buffer (maximum $10 PLCs)
v_plc_buffer_only_end:
v_plc_ptrnemcode:		ds.l	1		; pointer for nemesis decompression code ($1502 or $150C)
v_plc_repeatcount:		ds.l	1
v_plc_paletteindex:		ds.l	1
v_plc_previousrow:		ds.l	1
v_plc_dataword:			ds.l	1
v_plc_shiftvalue:		ds.l	1
v_plc_patternsleft:		ds.w	1
v_plc_framepatternsleft:	ds.w	1
v_plc_buffer_end:

Kos_decomp_queue_count:		ds.w	1		; the number of pieces of data on the queue. Sign bit set indicates a decompression is in progress
Kos_decomp_stored_Wregisters:	ds.w	6
Kos_decomp_stored_Lregisters:	ds.w	6
Kos_decomp_stored_SR:		ds.w	1
Kos_decomp_bookmark:		ds.l	1		; the address within the Kosinski queue processor at which processing is to be resumed
Kos_description_field:		ds.w	1		; used by the Kosinski queue processor the same way the stack is used by the normal Kosinski decompression routine
Kos_decomp_queue:		ds.l	2*4		; 2 longwords per entry, first is source location and second is decompression location
Kos_decomp_source =		Kos_decomp_queue	; long ; the compressed data location for the first entry in the queue
Kos_decomp_destination =	Kos_decomp_queue+4	; long ; the decompression location for the first entry in the queue
Kos_decomp_queue_End:
Kos_modules_left		ds.w	1		; the number of modules left to decompresses. Sign bit set indicates a module is being decompressed/has been decompressed
Kos_last_module_size		ds.w	1		; the uncompressed size of the last module in words. All other modules are $800 words
Kos_module_queue:		ds.w	3*6		; 6 bytes per entry, first longword is source location and next word is VRAM destination
Kos_module_source =		Kos_module_queue	; long ; the compressed data location for the first module in the queue
Kos_module_destination =	Kos_module_queue+4	; word ; the VRAM destination for the first module in the queue
Kos_module_queue_End:

v_levelvariables:					; variables that are reset between levels
word_F700:		ds.w	1			; set to 0 in Tails_Control, otherwise unused
Tails_control_counter:	ds.w	1
Tails_respawn_counter:	ds.w	1
word_F706:		ds.w	1
Tails_CPU_routine:	ds.w	1

Rings_manager_routine:	ds.b	1
Level_started_flag:	ds.b	1
Ring_start_addr:	ds.w	1
Ring_end_addr:		ds.w	1
Ring_start_addr_P2:	ds.w	1
Ring_end_addr_P2:	ds.w	1

Screen_redraw_flag:	ds.b	1			; if whole screen needs to redraw, such as when you destroy the hatch before the boss in WFZ
Scroll_Timer:		ds.b	1			; unused

Water_flag:		ds.b	1
			ds.b	1			; unused

Sonic_top_speed:	ds.w	1
Sonic_acceleration:	ds.w	1
Sonic_deceleration:	ds.w	1
Sonic_LastLoadedDPLC:	ds.b	1
Primary_Angle:		ds.b	1
Secondary_Angle:	ds.b	1
Obj_placement_routine:	ds.b	1

Camera_X_pos_last:	ds.w	1			; Camera_X_pos_coarse from the previous frame
Camera_X_pos_last_End:

Object_Manager_Addresses:
Obj_load_addr_right:	ds.l	1			; contains the address of the next object to load when moving right
Obj_load_addr_left:	ds.l	1			; contains the address of the last object loaded when moving left
Object_Manager_Addresses_End:

Object_Manager_Addresses_P2:
Obj_load_addr_right_P2:	ds.l	1
Obj_load_addr_left_P2:	ds.l	1
Object_Manager_Addresses_P2_End:

Object_manager_2P_RAM:					; The next 16 bytes belong to this.
Object_RAM_block_indices:	ds.b	6		; seems to be an array of horizontal chunk positions, used for object position range checks
Player_1_loaded_object_blocks:	ds.b	3
Player_2_loaded_object_blocks:	ds.b	3

Camera_X_pos_last_P2:	ds.w	1
Camera_X_pos_last_P2_End:

Obj_respawn_index_P2:	ds.b	2			; respawn table indices of the next objects when moving left or right for the second player
Obj_respawn_index_P2_End:
Object_manager_2P_RAM_End:

Demo_button_index:	ds.w	1			; index into button press demo data, for player 1
Demo_press_counter:	ds.b	1			; frames remaining until next button press, for player 1
Current_Timezone:	ds.b	1			; byte; Whether we're in the present, past, or Good/Bad future
PalChangeSpeed:		ds.w	1
Collision_addr:		ds.l	1
v_colladdr1:		ds.l	1
v_colladdr2:		ds.l	1
v_palss_num:		ds.w	1			; palette cycling in Special Stage - reference number
v_palss_time:		ds.w	1			; palette cycling in Special Stage - time until next change
v_palss_index:		ds.w	1			; palette cycling in Special Stage - index into palette cycle 2 (unused?)
v_ssbganim:		ds.w	1			; Special Stage background animation
			ds.b	1			; seems unused
Boss_defeated_flag:
v_bossstatus:		ds.b	1

v_gfxbigring:		ds.w	1			; settings for giant ring graphics loading
f_lockscreen:		ds.b	1

f_wtunnelmode:		ds.b	1			; LZ water tunnel mode
f_playerctrl:		ds.b	1			; Player control override flags (object ineraction, control enable)
f_wtunnelallow:		ds.b	1			; LZ water tunnels (00 = enabled; 01 = disabled)
f_slidemode:		ds.b	1			; LZ water slide mode
			ds.b	1			; unused

f_lockctrl:		ds.b	1
f_bigring:		ds.b	1			; flag set when Sonic collects the giant ring
			ds.b	1			; v_syz3door; flag to move the blockade at SYZ act 3, unused
			ds.b	1			; unused

v_itembonus:		ds.w	1			; item bonus from broken enemies, blocks etc.
v_timebonus:		ds.w	1			; time bonus at the end of an act
v_ringbonus:		ds.w	1			; ring bonus at the end of an act
f_endactbonus:		ds.b	1			; time/ring bonus update flag at the end of an act
			ds.b	1			; unused
v_lz_deform:		ds.w	1			; LZ deformation offset, in units of $80

Camera_X_pos_coarse:	ds.w	1			; (Camera_X_pos - 128) / 256
Camera_X_pos_coarse_End:

Camera_X_pos_coarse_P2:	ds.w	1
Camera_X_pos_coarse_P2_End:

Tails_LastLoadedDPLC:	ds.b	1
TailsTails_LastLoadedDPLC:	ds.b	1

f_switch:		ds.b	$10			; flags set when Sonic stands on a switch

Anim_Counters:		ds.b	$10

v_levelvariables_end:

Sprite_Table:		ds.b	$280			; Sprite attribute table buffer
Sprite_Table_end:
v_palette_water_fading = Sprite_Table_end-palette_size	; duplicate underwater palette, used for transitions ($80 bytes)
v_palette_water:	ds.b	palette_size		; main underwater palette
v_palette_water_end:
v_palette:		ds.b	palette_size		; main palette
v_palette_end:
v_palette_fading:	ds.b	palette_size		; duplicate palette, used for transitions
v_palette_fading_end:
			ds.b	$140			; stack
v_systemstack:

v_crossresetram:					; RAM beyond this point is only cleared on a cold-boot
Level_Inactive_flag:	ds.w	1			; (2 bytes)
Timer_frames:		ds.w	1			; the number of frames which have elapsed since the level started
Debug_object:		ds.b	1			; the current position in the debug mode object list
			ds.b	1			; unused
Debug_placement_mode:	ds.b	1
			ds.b	1			; the whole word is tested, but the debug mode code uses only the low byte
Debug_Accel_Timer:	ds.b	1			; (1 byte)
Debug_Speed:		ds.b	1			; (1 byte)

Vint_runcount:		ds.l	1			; the number of times V-int has run

Player_mode		ds.w	1			; 0 = Sonic and Tails, 1 = Sonic alone, 2 = Tails alone, 3 = Knuckles alone
Player_option		ds.w	1			; option selected on level select, data select screen or Sonic & Knuckles title screen
Current_ZoneAndAct =	*
Current_Zone:		ds.b	1			; (1 byte)
Current_Act =		*
v_act:			ds.b	1			; (1 byte)
v_lives:		ds.b	1			; (1 byte)
			ds.b	1			; unused
v_air:			ds.w	1			; air remaining while underwater
v_airbyte =		v_air+1				; low byte for air
v_lastspecial:		ds.b	1			; last special stage number
v_continues:		ds.b	1			; number of continues
f_timeover:		ds.b	1			; time over flag
v_lifecount:		ds.b	1			; lives counter value (for actual number, see "v_lives")
f_lifecount:		ds.b	1			; lives counter update flag
f_ringcount:		ds.b	1			; ring counter update flag
f_timecount:		ds.b	1			; time counter update flag
f_scorecount:		ds.b	1			; score counter update flag
v_rings:		ds.w	1			; rings
v_ringbyte = v_rings+1					; low byte for rings
v_time:			ds.l	1			; time
v_timemin = v_time+1					; time - minutes
v_timesec = v_time+2					; time - seconds
v_timecent = v_time+3					; time - centiseconds
v_score:		ds.l	1			; score
v_shield:		ds.b	1			; shield status (00 = no; 01 = yes)
v_invinc:		ds.b	1			; invinciblity status (00 = no; 01 = yes)
v_shoes:		ds.b	1			; speed shoes status (00 = no; 01 = yes)
Super_Sonic_flag:	ds.b	1

v_lastlamp:		ds.b	2			; number of the last lamppost you hit
v_lamp_xpos:		ds.w	1			; x-axis for Sonic to respawn at lamppost
v_lamp_ypos:		ds.w	1			; y-axis for Sonic to respawn at lamppost
v_lamp_rings:		ds.w	1			; rings stored at lamppost
v_lamp_time:		ds.l	1			; time stored at lamppost
v_lamp_mainchar:	ds.w	1
v_lamp_sidekick:	ds.w	1
v_lamp_solid:		ds.w	1
v_lamp_solid_sidekick:	ds.w	1
v_lamp_limitbtm:	ds.w	1			; level bottom boundary at lamppost
v_lamp_scrx:		ds.w	1			; x-axis screen at lamppost
v_lamp_scry:		ds.w	1			; y-axis screen at lamppost
v_lamp_bgscrx:		ds.w	1			; x-axis BG screen at lamppost
v_lamp_bgscry:		ds.w	1			; y-axis BG screen at lamppost
v_lamp_bg2scrx:		ds.w	1			; x-axis BG2 screen at lamppost
v_lamp_bg2scry:		ds.w	1			; y-axis BG2 screen at lamppost
v_lamp_bg3scrx:		ds.w	1			; x-axis BG3 screen at lamppost
v_lamp_bg3scry:		ds.w	1			; y-axis BG3 screen at lamppost
v_lamp_wtrpos:		ds.w	1			; water position at lamppost
v_lamp_wtrrout:		ds.b	1			; water routine at lamppost
v_lamp_wtrstat:		ds.b	1			; water state at lamppost
v_lamp_lives:		ds.b	1			; lives counter at lamppost
v_emeralds:		ds.b	1			; number of chaos emeralds
v_emldlist:		ds.b	6			; which individual emeralds you have (00 = no; 01 = yes)
v_oscillate:		ds.w	1			; oscillation bitfield


v_timingandscreenvariables:
v_timingvariables:
			ds.b	$40			; values which oscillate - for swinging platforms, et al
v_ani0_time:		ds.b	1			; synchronised sprite animation 0 - time until next frame (used for synchronised animations)
v_ani0_frame:		ds.b	1			; synchronised sprite animation 0 - current frame
v_ani1_time:		ds.b	1			; synchronised sprite animation 1 - time until next frame
v_ani1_frame:		ds.b	1			; synchronised sprite animation 1 - current frame
v_ani2_time:		ds.b	1			; synchronised sprite animation 2 - time until next frame
v_ani2_frame:		ds.b	1			; synchronised sprite animation 2 - current frame
v_ani3_time:		ds.b	1			; synchronised sprite animation 3 - time until next frame
v_ani3_frame:		ds.b	1			; synchronised sprite animation 3 - current frame
v_ani3_buf:		ds.w	1			; synchronised sprite animation 3 - info buffer
v_limittopdb:		ds.w	1			; level upper boundary, buffered for debug mode
v_limitbtmdb:		ds.w	1			; level bottom boundary, buffered for debug mode
v_timingvariables_end:

v_levseldelay:		ds.w	1			; level select - time until change when up/down is held
v_levselitem:		ds.w	1			; level select - item selected
v_levselsound:		ds.w	1			; level select - sound selected
v_scorelife:		ds.l	1			; points required for an extra life (JP1 only)

f_levselcheat:		ds.b	1			; level select cheat flag
f_slomocheat:		ds.b	1			; slow motion & frame advance cheat flag
Debug_mode_flag:	ds.b	1
f_debugcheat:		ds.b	1			; debug mode cheat flag
v_megadrive:		ds.b	1			; Megadrive machine type
			ds.b	1
v_title_dcount:		ds.w	1			; number of times the d-pad is pressed on title screen
v_title_ccount:		ds.w	1			; number of times C is pressed on title screen

f_demo:			ds.w	1			; demo mode flag (0 = no; 1 = yes; $8001 = ending)
v_demonum:		ds.w	1			; demo level number (not the same as the level number)
v_creditsnum:		ds.w	1			; credits index number
 
v_objstate:		ds.b	$C0			; object state list
v_objstate_end:
			ds.b	$7C0
v_end:
	if * > 0	; don't declare more space than the RAM can contain!
		fatal "The RAM variable declarations are too large by $\{*} bytes."
	endif

	if MOMPASS=1
		message "The current RAM available $\{0-*} bytes."
	endif
	dephase

; Sonic 1 camera variables

v_screenposx:=		Camera_X_pos
v_screenposy:=		Camera_Y_pos
v_bgscreenposx:=	Camera_BG_X_pos
v_bgscreenposy:=	Camera_BG_Y_pos
v_bg2screenposx:=	Camera_BG2_X_pos
v_bg2screenposy:=	Camera_BG2_Y_pos
v_bg3screenposx:=	Camera_BG3_X_pos
v_bg3screenposy:=	Camera_BG3_Y_pos
v_limitleft2:=		Camera_Min_X_pos
v_limitright2:=		Camera_Max_X_pos
v_limittop2:=		Camera_Min_Y_pos
v_limitbtm2:=		Camera_Max_Y_pos


; Special stage

v_ssbuffer1		= v_128x128
v_ssblockbuffer		= v_ssbuffer1+$1020		; ($2000 bytes)
v_ssblockbuffer_end	= v_ssblockbuffer+$80*$40	; from here, $FE0 bytes free
v_ssbuffer2		= v_128x128+$4000
v_ssblocktypes		= v_ssbuffer2
v_ssitembuffer		= v_ssbuffer2+$400		; ($1000 bytes)
v_ssitembuffer_end	= v_ssitembuffer+$100		; actually extends all the way to $FFFF5000; from here, $3000 bytes free
v_ssbuffer3		= v_128x128+$8000
v_ssscroll_buffer	= v_ngfx_buffer+$100
v_ssangle		= v_vdp_buffer1+2
v_ssrotate		= v_ssangle+2

;v_ss_layout:			equ $FF0000 ; special stage layout with space added to top and sides
;v_ss_layout_start:		equ v_ss_layout+sizeof_ss_padding_top+ss_width_padding_left ; $FF1020
;v_ss_enidec_buffer:		equ $FF0000 ; special stage background mappings are stored here before being moved to VRAM
;v_ss_layout_buffer:		equ $FF4000 ; unprocessed special stage layout - overwritten later ($1000 bytes)
;v_ss_sprite_info:		equ $FF4000 ; sprite info for each item type - mappings pointer (4 bytes); frame id (2 bytes); tile id (2 bytes) (total $278 bytes)
;v_ss_sprite_update_list:	equ $FF4400 ; list of items currently being updated - 8 bytes each ($100 bytes)
;v_ss_sprite_grid_plot:		equ $FF4500 ; x/y positions of cells in a 16x16 grid centered around Sonic, updates as it rotates ($400 bytes)
;v_ss_bubble_x_pos:		equ $FF4900 ; x position of background bubbles
;v_ss_cloud_x_pos:		equ $FF4A00 ; x position of background clouds - 4 bytes per block, 7 blocks ($1C bytes)

; Error handler
	phase v_objstate
v_regbuffer:		ds.b	$40			; stores registers d0-a7 during an error event
v_spbuffer:		ds.l	1			; stores most recent sp address
v_errortype:		ds.b	1			; error type
	dephase
	!org 0
; ---------------------------------------------------------------------------
; I/O Area
HW_Version:			equ $A10001
HW_Port_1_Data:			equ $A10003
HW_Port_2_Data:			equ $A10005
HW_Expansion_Data:		equ $A10007
HW_Port_1_Control:		equ $A10009
HW_Port_2_Control:		equ $A1000B
HW_Expansion_Control:		equ $A1000D
HW_Port_1_TxData:		equ $A1000F
HW_Port_1_RxData:		equ $A10011
HW_Port_1_SCtrl:		equ $A10013
HW_Port_2_TxData:		equ $A10015
HW_Port_2_RxData:		equ $A10017
HW_Port_2_SCtrl:		equ $A10019
HW_Expansion_TxData:		equ $A1001B
HW_Expansion_RxData:		equ $A1001D
HW_Expansion_SCtrl:		equ $A1001F

; Background music
bgm_GHZ =		MusID_GHZ
bgm_LZ =		MusID_CPZ
bgm_MZ =		MusID_CPZ
bgm_SLZ =		MusID_GRGZ1
bgm_SYZ =		MusID_HPZ
bgm_SBZ =		MusID_HTZ
bgm_Invincible =	MusID_Invincible
bgm_ExtraLife =		MusID_ExtraLife
bgm_SS =		MusID_SpecStage
bgm_Title =		MusID_Title
bgm_Ending =		MusID_Ending
bgm_Boss =		MusID_Boss
bgm_FZ =		MusID_HTZ
bgm_GotThrough =	MusID_EndLevel
bgm_GameOver =		MusID_GameOver
bgm_Continue =		MusID_Continue
bgm_Credits =		MusID_Credits
bgm_Drowning =		MusID_Countdown
bgm_Emerald =		MusID_Emerald

sfx_Jump =		SndID_Jump
sfx_Lamppost =		SndID_Checkpoint
sfx_SpikeSwitch =	SndID_SpikeSwitch
sfx_Death =		SndID_Hurt
sfx_Skid =		SndID_Skidding
sfx_A5 =		SndID_Bwoop
sfx_HitSpikes =		SndID_HurtBySpikes
sfx_Push =		SndID_BlockPush
sfx_SSGoal =		SndID_Goal
sfx_SSItem =		SndID_Bwoop
sfx_Splash =		SndID_Splash
sfx_AB =		SndID_Swish
sfx_HitBoss =		SndID_BossHit
sfx_Bubble =		SndID_InhalingBubble
sfx_Fireball =		SndID_FireBurn
sfx_Shield =		SndID_Shield
sfx_Saw =		SndID_LaserBeam
sfx_Electric =		SndID_Zap
sfx_Drown =		SndID_Drown
sfx_Flamethrower =	SndID_FireBurn
sfx_Bumper =		SndID_Bumper
sfx_Ring =		SndID_Ring
sfx_SpikesMove =	SndID_SpikesMove
sfx_Rumbling =		SndID_Rumbling
sfx_B8 =		SndID_unknown
sfx_Collapse =		SndID_Smash
sfx_SSGlass =		SndID_Glass
sfx_Door =		SndID_DoorSlam
sfx_Teleport =		SndID_SpindashRelease
sfx_ChainStomp =	SndID_ChainRise
sfx_Roll =		SndID_Roll
sfx_Continue =		SndID_ContinueJingle
sfx_Basaran =		SndID_SpindashRelease
sfx_BreakItem =		SndID_Explosion
sfx_Warning =		SndID_WaterWarning
sfx_GiantRing =		SndID_EnterGiantRing
sfx_Bomb =		SndID_BossExplosion
sfx_Cash =		SndID_TallyEnd
sfx_RingLoss =		SndID_RingSpill
sfx_ChainRise =		SndID_ChainRise
sfx_Burning =		SndID_FireBurn
sfx_Bonus =		SndID_Bonus
sfx_EnterSS =		SndID_SpecStageEntry
sfx_WallSmash =		SndID_SlowSmash
sfx_Spring =		SndID_Spring
sfx_Switch =		SndID_Blip
sfx_RingLeft =		SndID_RingLeft
sfx_Signpost =		SndID_Signpost

; Special sound effects
sfx_Waterfall =	$D0

bgm_Fade =		MusID_FadeOut
sfx_Sega =		SndID_SegaSound
bgm_Speedup =		MusID_SpeedUp
bgm_Slowdown =		MusID_SlowDown
bgm_Stop =		MusID_Stop

; Boss locations
; The main values are based on where the camera boundaries mainly lie
; The end values are where the camera scrolls towards after defeat
boss_ghz_x:	equ $2960		; Green Hill Zone
boss_ghz_y:	equ $300
boss_ghz_end:	equ boss_ghz_x+$160

boss_lz_x:	equ $1DE0		; Labyrinth Zone
boss_lz_y:	equ $C0
boss_lz_end:	equ boss_lz_x+$250

boss_mz_x:	equ $1800		; Marble Zone
boss_mz_y:	equ $210
boss_mz_end:	equ boss_mz_x+$160

boss_slz_x:	equ $2000		; Star Light Zone
boss_slz_y:	equ $210
boss_slz_end:	equ boss_slz_x+$160

boss_syz_x:	equ $2C00		; Spring Yard Zone
boss_syz_y:	equ $4CC
boss_syz_end:	equ boss_syz_x+$140

boss_sbz2_x:	equ $2050		; Scrap Brain Zone Act 2 Cutscene
boss_sbz2_y:	equ $510

boss_fz_x:	equ $2450		; Final Zone
boss_fz_y:	equ $510
boss_fz_end:	equ boss_fz_x+$2B0

; Tile VRAM Locations

; Shared
ArtTile_GHZ_MZ_Swing:		equ $380
ArtTile_MZ_SYZ_Caterkiller:	equ $4FF
ArtTile_GHZ_SLZ_Smashable_Wall:	equ $50F
ArtTile_Bumper:			equ $380

; Green Hill Zone
ArtTile_GHZ_Flower_4:		equ ArtTile_Level+$340
ArtTile_GHZ_Edge_Wall:		equ $34C
ArtTile_GHZ_Flower_Stalk:	equ ArtTile_Level+$358
ArtTile_GHZ_Big_Flower_1:	equ ArtTile_Level+$35C
ArtTile_GHZ_Small_Flower:	equ ArtTile_Level+$36C
ArtTile_GHZ_Waterfall:		equ ArtTile_Level+$378
ArtTile_GHZ_Flower_3:		equ ArtTile_Level+$380
ArtTile_GHZ_Bridge:		equ $4C6 ; $38E in S1
ArtTile_GHZ_Big_Flower_2:	equ ArtTile_Level+$390
ArtTile_GHZ_Spike_Pole:		equ $398
ArtTile_GHZ_Giant_Ball:		equ $3AA
ArtTile_GHZ_Purple_Rock:	equ $3D0 ; $3D0 in S1

; Marble Zone
ArtTile_ArtUnc_CPZAnimBack	equ $319 ; $370 in S2

ArtTile_MZ_Block:		equ $2B8
ArtTile_MZ_Animated_Magma:	equ ArtTile_Level+$2D2
ArtTile_MZ_Animated_Lava:	equ ArtTile_Level+$2E2
ArtTile_MZ_Torch:		equ ArtTile_Level+$2F2
ArtTile_MZ_Spike_Stomper:	equ $300
ArtTile_MZ_Fireball:		equ $345
ArtTile_MZ_Glass_Pillar:	equ $38E
ArtTile_MZ_Lava:		equ $3A8

; Spring Yard Zone
ArtTile_SYZ_Big_Spikeball:	equ $396
ArtTile_SYZ_Spikeball_Chain:	equ $3BA

; Labyrinth Zone
ArtTile_LZ_Block_1:		equ $1E0
ArtTile_LZ_Block_2:		equ $1F0
ArtTile_LZ_Splash:		equ $259
ArtTile_LZ_Gargoyle:		equ $2E9
ArtTile_LZ_Water_Surface:	equ $300
ArtTile_LZ_Spikeball_Chain:	equ $310
ArtTile_LZ_Flapping_Door:	equ $328
ArtTile_LZ_Bubbles:		equ $348
ArtTile_LZ_Moving_Block:	equ $3BC
ArtTile_LZ_Door:		equ $3C4
ArtTile_LZ_Harpoon:		equ $3CC
ArtTile_LZ_Pole:		equ $3DE
ArtTile_LZ_Push_Block:		equ $3DE
ArtTile_LZ_Blocks:		equ $3E6
ArtTile_LZ_Conveyor_Belt:	equ $3F6
ArtTile_LZ_Sonic_Drowning:	equ $440
ArtTile_LZ_Rising_Platform:	equ ArtTile_LZ_Blocks+$69
ArtTile_LZ_Orbinaut:		equ $467
ArtTile_LZ_Cork:		equ ArtTile_LZ_Blocks+$11A

; Star Light Zone
ArtTile_SLZ_Seesaw:		equ $374
ArtTile_SLZ_Fan:		equ $3A0
ArtTile_SLZ_Pylon:		equ $3CC
ArtTile_SLZ_Swing:		equ $3DC
ArtTile_SLZ_Orbinaut:		equ $429
ArtTile_SLZ_Fireball:		equ $480
ArtTile_SLZ_Fireball_Launcher:	equ $4D8
ArtTile_SLZ_Collapsing_Floor:	equ $4E0
ArtTile_SLZ_Spikeball:		equ $4F0

; Scrap Brain Zone
ArtTile_SBZ_Caterkiller:	equ $2B0
ArtTile_SBZ_Moving_Block_Short:	equ $2C0
ArtTile_SBZ_Door:		equ $2E8
ArtTile_SBZ_Girder:		equ $2F0
ArtTile_SBZ_Disc:		equ $344
ArtTile_SBZ_Junction:		equ $348
ArtTile_SBZ_Swing:		equ $391
ArtTile_SBZ_Saw:		equ $3B5
ArtTile_SBZ_Flamethrower:	equ $3D9
ArtTile_SBZ_Collapsing_Floor:	equ $3F5
ArtTile_SBZ_Orbinaut:		equ $429
ArtTile_SBZ_Smoke_Puff_1:	equ ArtTile_Level+$448
ArtTile_SBZ_Smoke_Puff_2:	equ ArtTile_Level+$454
ArtTile_SBZ_Moving_Block_Long:	equ $460
ArtTile_SBZ_Horizontal_Door:	equ $46F
ArtTile_SBZ_Electric_Orb:	equ $47E
ArtTile_SBZ_Trap_Door:		equ $492
ArtTile_SBZ_Vanishing_Block:	equ $4C3
ArtTile_SBZ_Spinning_Platform:	equ $4DF

; Final Zone
ArtTile_FZ_Boss:		equ $300
ArtTile_FZ_Eggman_Fleeing:	equ $3A0
ArtTile_FZ_Eggman_No_Vehicle:	equ $470

; General Level Art
ArtTile_Level:			equ $000
ArtTile_Ball_Hog:		equ $302
ArtTile_Bomb:			equ $400
ArtTile_Missile_Disolve:	equ $41C ; Unused
ArtTile_Spikes:			equ $434
ArtTile_Spikes_GHZ:		equ ArtTile_Spikes+$6C

ArtTile_Buzz_Bomber:		equ $444
ArtTile_Crabmeat:		equ $400
ArtTile_Chopper:		equ $470
ArtTile_Moto_Bug:		equ $4E0
ArtTile_Newtron:		equ $49B

ArtTile_Yadrin:			equ $47B
ArtTile_Lamppost:		equ $47C
ArtTile_Jaws:			equ $486
ArtTile_Burrobot:		equ $4A6
ArtTile_Basaran:		equ $4B8
ArtTile_Button:			equ $50F
ArtTile_S1_Spring_Horizontal:	equ $4A8
ArtTile_S1_Spring_Vertical:	equ $4B8
ArtTile_Shield:			equ $4BE
ArtTile_Invincibility:		equ $4DE
ArtTile_Game_Over:		equ $55E
ArtTile_Title_Card:		equ $580
ArtTile_Animal_1:		equ $580
ArtTile_Animal_2:		equ $592
ArtTile_Explosion:		equ $5A0
ArtTile_Monitor:		equ $680
ArtTile_HUD:			equ $6CA
ArtTile_Sonic:			equ $780
ArtTile_Points:			equ $4AC
ArtTile_Tails:			equ $7A0
ArtTile_TailsTails:		equ $7B0
ArtTile_Ring:			equ $6BC
ArtTile_Lives_Counter:		equ $7D4
ArtTile_Water_Surface:		equ $400
ArtTile_Spring_Horizontal:	equ $470
ArtTile_Spring_Vertical:	equ $45C
ArtTile_Spring_Diagonal:	equ $43C

; Eggman
ArtTile_Eggman:			equ $400
ArtTile_Eggman_Weapons:		equ $46C
ArtTile_Eggman_Button:		equ $4A4
ArtTile_Eggman_Spikeball:	equ $518
ArtTile_Eggman_Trap_Floor:	equ $518
ArtTile_Eggman_Exhaust:		equ ArtTile_Eggman+$12A

; End of Level
ArtTile_Giant_Ring:		equ $400
ArtTile_Giant_Ring_Flash:	equ $462
ArtTile_Prison_Capsule:		equ $49D
ArtTile_Hidden_Points:		equ $4B6
ArtTile_Warp:			equ $541
ArtTile_Mini_Tails:		equ $535
ArtTile_Mini_Sonic:		equ $551
ArtTile_Bonuses:		equ $570
ArtTile_Signpost:		equ $680

; Sega Screen
ArtTile_Sega_Tiles:		equ $000

; Title Screen
ArtTile_Title_Foreground:	equ $000
ArtTile_Title_Press_Start:	equ $18C
ArtTile_SonicTeamPresents:	equ $19A
ArtTile_Title_Sonic_And_Tails:	equ $200
ArtTile_Title_Sonic:		equ $300
ArtTile_Level_Select_Font:	equ $680

; Continue Screen
ArtTile_Continue_Sonic:		equ $500
ArtTile_Continue_Number:	equ $6FC

; Ending
ArtTile_Ending_Flowers:		equ $3A0
ArtTile_Ending_Emeralds:	equ $3C5
ArtTile_Ending_Sonic:		equ $3E1
ArtTile_Ending_Eggman:		equ $524
ArtTile_Ending_Rabbit:		equ $553
ArtTile_Ending_Chicken:		equ $565
ArtTile_Ending_Penguin:		equ $573
ArtTile_Ending_Seal:		equ $585
ArtTile_Ending_Pig:		equ $593
ArtTile_Ending_Flicky:		equ $5A5
ArtTile_Ending_Squirrel:	equ $5B3
ArtTile_Ending_STH:		equ $5C5

; Try Again Screen
ArtTile_Try_Again_Emeralds:	equ $3C5
ArtTile_Try_Again_Eggman:	equ $3E1

; Special Stage
ArtTile_SS_Background_Clouds:	equ $000
ArtTile_SS_Background_Fish:	equ $051
ArtTile_SS_Wall:		equ $142
ArtTile_SS_Plane_1:		equ $200
ArtTile_SS_Bumper:		equ $23B
ArtTile_SS_Goal:		equ $251
ArtTile_SS_Up_Down:		equ $263
ArtTile_SS_R_Block:		equ $2F0
ArtTile_SS_Plane_2:		equ $300
ArtTile_SS_Extra_Life:		equ $370
ArtTile_SS_Emerald_Sparkle:	equ $3F0
ArtTile_SS_Plane_3:		equ $400
ArtTile_SS_Red_White_Block:	equ $470
ArtTile_SS_Ghost_Block:		equ $4F0
ArtTile_SS_Plane_4:		equ $500
ArtTile_SS_W_Block:		equ $570
ArtTile_SS_Glass:		equ $5F0
ArtTile_SS_Plane_5:		equ $600
ArtTile_SS_Plane_6:		equ $700
ArtTile_SS_Emerald:		equ $770
ArtTile_SS_Rings:		equ $7B2
ArtTile_SS_Zone_1:		equ $797
ArtTile_SS_Zone_2:		equ $7A0
ArtTile_SS_Zone_3:		equ $7A9
ArtTile_SS_Zone_4:		equ $797
ArtTile_SS_Zone_5:		equ $7A0
ArtTile_SS_Zone_6:		equ $7A9

; Special Stage Results
ArtTile_SS_Results_Emeralds:	equ $541

; Font
ArtTile_Credits_Font:		equ $5A0

; Error Handler
ArtTile_Error_Handler_Font:	equ $7C0

; EHZ, HTZ
ArtTile_Checkers:		equ ArtTile_Level+$7D
ArtTile_Art_Flowers1:		equ $394
ArtTile_Art_Flowers2:		equ $396
ArtTile_Art_Flowers3:		equ $398
ArtTile_Art_Flowers4:		equ $39A
ArtTile_EHZ_Shield:		equ $560

; CPZ
ArtTile_CPZ_Buildings:		equ $3D0

; HPZ
ArtTile_Art_HPZPulseOrb_1:	equ $2E8
ArtTile_Art_HPZPulseOrb_2:	equ $2F0
ArtTile_Art_HPZPulseOrb_3:	equ $2F8
ArtTile_HPZ_Bridge:		equ $300
ArtTile_HPZ_Waterfall:		equ $315
ArtTile_HPZ_Platform:		equ $34A
ArtTile_HPZ_Orb:		equ $35A
ArtTile_HPZ_Emerald:		equ $392

; ---------------------------------------------------------------------------
; Level-specific objects and badniks.

; EHZ
ArtTile_Art_EHZPulseBall:	equ $39C
ArtTile_Fireball:		equ $39E
ArtTile_Waterfall:		equ $3AE
ArtTile_EHZ_Bridge:		equ $3C6
ArtTile_Buzzer:			equ $3E6
ArtTile_Buzzer_Fireball:	equ $3BE	; Actually unused
ArtTile_Snail:			equ $402
ArtTile_Masher:			equ $41C
ArtTile_Art_EHZMountains:	equ $500

; EHZ boss
ArtTile_ArtNem_Eggpod_1:	equ $460
ArtTile_ArtNem_EHZBoss:	equ $4C0
ArtTile_ArtNem_EggChoppers:	equ $540

; CPZ
ArtTile_CPZ_Platform:		equ $400

; HPZ
ArtTile_Redz:			equ $500
ArtTile_BBat:			equ $530

; HTZ
ArtTile_Rexon:			equ $37E
ArtTile_HTZ_Fireball:		equ $3AE
ArtTile_HTZ_AutomaticDoor:	equ $3BE
ArtTile_HTZ_Seesaw:		equ $3CE
ArtTile_Sol:			equ $3DE
ArtTile_HtzZipline:		equ $3E6
ArtTile_HtzValveBarrier:	equ $426
ArtTile_HTZMountains:		equ $500
ArtTile_Spiker:			equ $520

; Unused
ArtTile_Gator:			equ $300
ArtTile_Stegway:		equ $3C4
ArtTile_BFish:			equ $530
ArtTile_Aquis:			equ $570
ArtTile_Aquis_Child:		equ $4E0
ArtTile_Octus:			equ $38A
ArtTile_Octus_Child:		equ $4C6