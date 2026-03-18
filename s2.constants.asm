; ===========================================================================
; size variables - you'll get an informational error if you need to change these...
; they are all in units of bytes
Size_of_DAC_samples		= $2F00
Size_of_SEGA_sound		= $6978
Size_of_Snd_driver_guess	= $F64 ; approximate post-compressed size of the Z80 sound driver
; ---------------------------------------------------------------------------
; Object variables
; ---------------------------------------------------------------------------
; Object Status Table offsets (for everything between Object_RAM and Primary_Collision)
; ---------------------------------------------------------------------------
; universally followed object conventions:
obID:			equ 0		; object ID number
obRender:		equ 1		; bitfield for x/y flip, display mode
obGfx:			equ 2		; palette line & VRAM setting (2 bytes)
obMap:			equ 4		; mappings address (4 bytes)
obX:			equ 8		; x-axis position (2-4 bytes)
obXSub:			equ $A		; for when exra presition is required (2 bytes)
obY:			equ $C		; y-axis position (2-4 bytes)
obYSub:			equ $E		; for when exra presition is required (2 bytes)
obActWid:		equ $14		; action width
obPriority:		equ $18		; and $19 - sprite stack priority -- 0 is front
obFrame:		equ $1A		; current frame displayed
; ---------------------------------------------------------------------------
; conventions followed by most objects:
obVelX:			equ $10		; x-axis velocity (2 bytes)
obVelY:			equ $12		; y-axis velocity (2 bytes)
obTimeFrame:		equ $15		; time to next frame
obHeight:		equ $16		; height/2; y_radius
obWidth:		equ $17		; width/2 ; x_radius
obAniFrame:		equ $1B		; current frame in animation script
obAnim:			equ $1C		; current animation
obPrevAni:		equ $1D		; previous animation
obStatus:		equ $22		; note: exact meaning depends on the object... for sonic/tails: bit 0: leftfacing. bit 1: inair. bit 2: spinning. bit 3: onobject. bit 4: rolljumping. bit 5: pushing. bit 6: underwater.
obRoutine:		equ $24		; routine number
ob2ndRout:		equ $25		; secondary routine number
obAngle:		equ $26		; angle about the z axis (360 degrees = 256)
; ---------------------------------------------------------------------------
; conventions followed by many objects but NOT Sonic/Tails:
obColType:		equ $20		; collision response type
obColProp:		equ $21		; collision extra property
obRespawnNo:		equ $1E		; (and soon $1F) respawn list index number
obSubtype:		equ $28		; object subtype
; ---------------------------------------------------------------------------
; conventions specific to Sonic/Tails (Obj01, Obj02, and ObjDB):
; note: $23, and $14 are unused and available
obInertia:		equ $20		; also known as ground_vel; and $21 directionless representation of speed... not updated in the air
;obSolid: 		equ $25		; (DEPRECATED, Sonic 1 leftover for reference only) solid status flag
; air_left:		equ $28
; flip_turned:		equ $29		; 0 for normal, 1 to invert flipping (it's a 180 degree rotation about the axis of Sonic's spine, so he stays in the same position but looks turned around)
obControl:		equ $2A		; 0 for normal, 1 for hanging or for resting on a flipper, $81 for going through CNZ/OOZ/MTZ tubes or stopped in CNZ cages or stoppers or flying if Tails
obStatusSecondary:	equ $2B
flips_remaining:	equ $2C		; number of flip revolutions remaining
flip_speed:		equ $2D		; number of flip revolutions per frame / 256
move_lock:		equ $2E		; and $2F ; horizontal control lock, counts down to 0
flashtime:		equ $30		; time between flashes after getting hit
invtime:		equ $32		; time left for invincibility
shoetime:		equ $34		; time left for speed shoes
;next_tilt:		equ $36		; angle on ground in front of sprite
;tilt: 			equ $37		; angle on ground
stick_to_convex:	equ $38
spindash_flag:		equ $39		; 0 for normal, 1 for charging a spindash or forced rolling
;pinball_mode =		spindash_flag
;jumping:		equ $3C
standonobject:		equ $3D		; interact; ; RAM address of the last object Sonic stood on, minus v_objspace and divided by object_size
obTopSolidBit:		equ $3E		; bit to check for top solidity (either $C or $E)
obLRBSolidBit:		equ $3F		; bit to check for left/right/bottom solidity (either $D or $F)
; ---------------------------------------------------------------------------
; Miscellaneous object scratch-RAM
objoff_25:		equ $25
objoff_26:		equ $26
objoff_27:		equ $27
objoff_28:		equ $28
objoff_29:		equ $29
objoff_2A:		equ $2A
objoff_2B:		equ $2B
objoff_2C:		equ $2C
objoff_2D:		equ $2D
objoff_2E:		equ $2E
objoff_2F:		equ $2F
objoff_30:		equ $30
objoff_31:		equ $31
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
obParent =		objoff_3E ; and $3F ; address of object that owns or spawned this one, if applicable

object_size_bits:	equ 6
object_size:		equ 1<<object_size_bits
next_object =		object_size
; ---------------------------------------------------------------------------
; conventions followed by some/most bosses:
boss_subtype		= obXSub
boss_invulnerable_time	= obInertia
boss_sine_count		= obFrame
boss_routine		= obAngle
boss_defeated		= objoff_2C
boss_hitcount2		= objoff_32
boss_hurt_sonic		= objoff_38	; flag set by collision response routine when Sonic has just been hurt (by boss?)
; ---------------------------------------------------------------------------
; when childsprites are activated (i.e. bit #6 of render_flags set)
next_subspr		= 6
mainspr_mapframe	= $B
mainspr_width		= $E
mainspr_childsprites	= $F	; amount of child sprites
mainspr_height		= $14
subspr_data		= $10
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
; status_secondary bitfield variables
;
; status_secondary variable bit numbers
obStatusSecondary_hasShield:		EQU	0
obStatusSecondary_isInvincible:		EQU	1
obStatusSecondary_hasSpeedShoes:	EQU	2
obStatusSecondary_isSliding:		EQU	7
; status_secondary variable masks (1 << x == pow(2, x))
obStatusSecondary_hasShield_mask:	EQU	1<<obStatusSecondary_hasShield		; $01
obStatusSecondary_isInvincible_mask:	EQU	1<<obStatusSecondary_isInvincible	; $02
obStatusSecondary_hasSpeedShoes_mask:	EQU	1<<obStatusSecondary_hasSpeedShoes	; $04
obStatusSecondary_isSliding_mask:	EQU	1<<obStatusSecondary_isSliding		; $80
; ---------------------------------------------------------------------------
; render_flags bitfield

obRender.x_flip			= 0 ; Sprite mirrored horizontally.
obRender.y_flip			= 1 ; Sprite mirrored vertically.
obRender.level_fg		= 2 ; Move with level foreground.
obRender.level_bg		= 3 ; Move with level background; leftover from Sonic 1.
obRender.explicit_height	= 4 ; Draw culling uses `y_radius` instead of guessing a height.
obRender.static_mappings	= 5 ; Mappings pointer points directly to a lone sprite piece instead of a list of sprites.
obRender.multi_sprite		= 6 ; Object SST holds metadata for multiple sprites.
obRender.on_screen		= 7 ; Object is on-screen and was rendered on the previous frame.

; ---------------------------------------------------------------------------
; Animation flags
afEnd:		equ $FF	; return to beginning of animation
afBack:		equ $FE	; go back (specified number) bytes
afChange:	equ $FD	; run specified animation
afRoutine:	equ $FC	; increment routine counter
afReset:	equ $FB	; reset animation and 2nd object routine counter
af2ndRoutine:	equ $FA	; increment 2nd routine counter
; Levels
id_GHZ:		equ 0
id_LZ:		equ 1
id_MZ:		equ 2
id_CPZ:		equ 2
id_SLZ:		equ 3
id_EHZ:		equ 3
id_SYZ:		equ 4
id_HPZ:		equ 4
id_SBZ:		equ 5
id_HTZ:		equ 5
id_EndZ:	equ 6
id_SS:		equ 7

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
; Casino night bumpers (Imported from Sonic 2. MIGHT get used, might not.)
bumper_id           = 0
bumper_x            = 2
bumper_y            = 4
next_bumper         = 6
prev_bumper_x       = bumper_x-next_bumper
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


; Other sizes
palette_line_size		= $10*2	; 16 word entries
palette_size:			equ $80

PLCKosPlusM_Count:	= 32

; ===========================================================================
; The following come from Sonic 2 -- For compatibility only.
; ---------------------------------------------------------------------------
; VRAM and tile art base addresses.
; VRAM Reserved regions.
VRAM_Plane_A_Name_Table                  = $C000	; Extends until $CFFF
VRAM_Plane_B_Name_Table                  = $E000	; Extends until $EFFF
VRAM_Plane_Table_Size                    = $1000	; 64 cells x 32 cells x 2 bytes per cell
VRAM_Sprite_Attribute_Table              = $F800	; Extends until $FA7F
VRAM_Sprite_Attribute_Table_Size         = $0280	; 640 bytes
VRAM_Horiz_Scroll_Table                  = $FC00	; Extends until $FF7F
VRAM_Horiz_Scroll_Table_Size             = 224*2*2	; 224 lines * 2 bytes per entry * 2 PNTs

; VRAM Reserved regions, Sega screen.
VRAM_SegaScr_Plane_A_Name_Table          = $C000	; Extends until $DFFF
VRAM_SegaScr_Plane_B_Name_Table          = $A000	; Extends until $BFFF
VRAM_SegaScr_Plane_Table_Size            = $2000	; 128 cells x 32 cells x 2 bytes per cell

; VRAM Reserved regions, Special Stage.
VRAM_SS_Plane_A_Name_Table1              = $C000	; Extends until $DFFF
VRAM_SS_Plane_A_Name_Table2              = $8000	; Extends until $9FFF
VRAM_SS_Plane_B_Name_Table               = $A000	; Extends until $BFFF
VRAM_SS_Plane_Table_Size                 = $2000	; 128 cells x 32 cells x 2 bytes per cell

; VRAM Reserved regions, Title screen.
VRAM_TtlScr_Plane_A_Name_Table           = $C000	; Extends until $CFFF
VRAM_TtlScr_Plane_B_Name_Table           = $E000	; Extends until $EFFF
VRAM_TtlScr_Plane_Table_Size             = $1000	; 64 cells x 32 cells x 2 bytes per cell

; VRAM Reserved regions, Ending sequence and credits.
VRAM_EndSeq_Plane_A_Name_Table           = $C000	; Extends until $DFFF
VRAM_EndSeq_Plane_B_Name_Table1          = $E000	; Extends until $EFFF (plane size is 64x32)
VRAM_EndSeq_Plane_B_Name_Table2          = $4000	; Extends until $5FFF
VRAM_EndSeq_Plane_Table_Size             = $2000	; 64 cells x 64 cells x 2 bytes per cell

; VRAM Reserved regions, menu screen.
VRAM_Menu_Plane_A_Name_Table             = $C000	; Extends until $CFFF
VRAM_Menu_Plane_B_Name_Table             = $E000	; Extends until $EFFF
VRAM_Menu_Plane_Table_Size               = $1000	; 64 cells x 32 cells x 2 bytes per cell
; ===========================================================================

	include "musicids.gen.asm"

	include "sfxids.gen.asm"


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
RAM_debug_start:		ds.b	$10000
RAM_debug_end:

v_start:
RAM_Start:

Chunk_Table:			ds.w	$40*$100	; 128x128 tile mappings ($8000 bytes)
Chunk_Table_End:
v_128x128:=	Chunk_Table
v_128x128_end:=	Chunk_Table_End

Level_Layout:			ds.b	$1000		; level layout buffer ($1000 bytes)
Level_Layout_End:

v_lvllayout:=			Level_Layout
v_lvllayout_end:=		Level_Layout_End
v_lvllayoutbg:=			Level_Layout+$80
v_16x16:			ds.b	$1800		; $1800 bytes

TempArray_LayerDef:		ds.b	$200		; background scroll buffer
v_bgscroll_buffer:=		TempArray_LayerDef
v_hscrolltablebuffer:		ds.b	$380		; scrolling table data
v_hscrolltablebuffer_end:
				ds.b	$80		; would be unused, but data from v_hscrolltablebuffer can spill into here
v_hscrolltablebuffer_end_padded:
Sprite_Table:			ds.b	$280		; Sprite attribute table buffer
Sprite_Table_end:
				ds.b	$140		; stack
v_systemstack:
v_ngfx_buffer:			ds.b	$200		; Nemesis graphics decompression buffer
v_ngfx_buffer_end:

v_objstate:			ds.b	$300		; object state list
v_objstate_end:
Object_Display_Lists:		ds.b	$400		; sprite display queue, in order of priority
Object_Display_Lists_End:
v_spritequeue:=		Object_Display_Lists
v_spritequeue_end:=	Object_Display_Lists_End

Sonic_Stat_Record_Buf:		ds.b	$100
Sonic_Pos_Record_Buf:		ds.b	$100
Tails_Pos_Record_Buf:		ds.b	$100
Ring_Positions:			ds.b	$600
Ring_Positions_End:

Kos_decomp_buffer:		ds.b	$1000		; Moduled Kosinski+ decompression buffer

VDP_Command_Buffer:		ds.w	7*$12		; stores 18 ($12) VDP commands to issue the next time ProcessDMAQueue is called
VDP_Command_Buffer_Slot:	ds.w	1		; stores the address of the next open slot for a queued VDP command

; ---------------------------------------------------------------------------
v_objspace:			ds.b	object_size*$80	; object variable space ($40 bytes per object)
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
v_player2tails	= v_objspace+object_size*6		; object variable space for Tails' Tails ($40 bytes)
v_shieldobj	= v_objspace+object_size*7		; object variable space for Sonic's shield ($40 bytes)
v_shieldobj2	= v_objspace+object_size*8		; object variable space for Tails's shield ($40 bytes)
v_starsobj1	= v_objspace+object_size*9		; object variable space for Sonic's invincibility stars #1 ($40 bytes)
v_starsobj2	= v_objspace+object_size*10		; object variable space for Sonic's invincibility stars #2 ($40 bytes)
v_starsobj3	= v_objspace+object_size*11		; object variable space for Sonic's invincibility stars #3 ($40 bytes)
v_starsobj4	= v_objspace+object_size*12		; object variable space for Sonic's invincibility stars #4 ($40 bytes)
v_tstarsobj1	= v_objspace+object_size*13		; object variable space for Tails's invincibility stars #1 ($40 bytes)
v_tstarsobj2	= v_objspace+object_size*14		; object variable space for Tails's invincibility stars #2 ($40 bytes)
v_tstarsobj3	= v_objspace+object_size*15		; object variable space for Tails's invincibility stars #3 ($40 bytes)
v_tstarsobj4	= v_objspace+object_size*16		; object variable space for Tails's invincibility stars #4 ($40 bytes)

v_splash	= v_objspace+object_size*17		; object variable space for Sonic's water splash ($40 bytes)
v_tsplash	= v_objspace+object_size*18		; object variable space for Tails's water splash ($40 bytes)
v_sonicbubbles	= v_objspace+object_size*19		; object variable space for the bubbles that come out of Sonic's mouth/drown countdown ($40 bytes)
v_tailsbubbles	= v_objspace+object_size*20		; object variable space for the bubbles that come out of Tails's mouth/drown countdown ($40 bytes)
v_watersurface1	= v_objspace+object_size*21		; object variable space for the water surface #1 ($40 bytes)
v_watersurface2	= v_objspace+object_size*22		; object variable space for the water surface #2 ($40 bytes)

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

; Bonus Stage objects
v_bsrescard	= v_objspace+object_size*23		; object variable space for the Bonus Stage results card ($140 bytes)
v_bsrestext	= v_bsrescard+object_size*0		; object variable space for the Bonus Stage results card text ($40 bytes)
v_bsresscore	= v_bsrescard+object_size*1		; object variable space for the Bonus Stage results card score tally ($40 bytes)
v_bsresring	= v_bsrescard+object_size*2		; object variable space for the Bonus Stage results card ring bonus tally ($40 bytes)
v_bsresoval	= v_bsrescard+object_size*3		; object variable space for the Bonus Stage results card oval ($40 bytes)
v_ssrescontinue	= v_bsrescard+object_size*4		; object variable space for the Bonus Stage results card continue icon ($40 bytes)
v_ssresemeralds	= v_objspace+object_size*32		; object variable space for the emeralds in the Bonus Stage results ($180 bytes)

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
; ---------------------------------------------------------------------------
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

Block_Crossed_Flags:
Horiz_block_crossed_flag:	ds.b	1	; toggles between 0 and $10 when you cross a block boundary horizontally
Verti_block_crossed_flag:	ds.b	1	; toggles between 0 and $10 when you cross a block boundary vertically
Horiz_block_crossed_flag_BG:	ds.b	1	; toggles between 0 and $10 when background camera crosses a block boundary horizontally
Verti_block_crossed_flag_BG:	ds.b	1	; toggles between 0 and $10 when background camera crosses a block boundary vertically
Horiz_block_crossed_flag_BG2:	ds.b	1	; used in CPZ
Horiz_block_crossed_flag_BG3:	ds.b	1
Block_Crossed_Flags_End:

Scroll_Flags_All:
Scroll_flags:			ds.w	1	; bitfield ; bit 0 = redraw top row, bit 1 = redraw bottom row, bit 2 = redraw left-most column, bit 3 = redraw right-most column
Scroll_flags_BG:		ds.w	1	; bitfield ; bits 0-3 as above, bit 4 = redraw top row (except leftmost block), bit 5 = redraw bottom row (except leftmost block), bits 6-7 = as bits 0-1
Scroll_flags_BG2:		ds.w	1	; bitfield ; essentially unused; bit 0 = redraw left-most column, bit 1 = redraw right-most column
Scroll_flags_BG3:		ds.w	1	; bitfield ; for CPZ; bits 0-3 as Scroll_flags_BG but using Y-dependent BG camera; bits 4-5 = bits 2-3; bits 6-7 = bits 2-3
Scroll_Flags_All_End:

Camera_Positions_Copy:
Camera_RAM_copy:		ds.l	2	; copied over every V-int
Camera_BG_copy:			ds.l	2	; copied over every V-int
Camera_BG2_copy:		ds.l	2	; copied over every V-int
Camera_BG3_copy:		ds.l	2	; copied over every V-int
Camera_Positions_Copy_End:

Scroll_Flags_Copy_All:
Scroll_flags_copy:		ds.w	1	; copied over every V-int
Scroll_flags_BG_copy:		ds.w	1	; copied over every V-int
Scroll_flags_BG2_copy:		ds.w	1	; copied over every V-int
Scroll_flags_BG3_copy:		ds.w	1	; copied over every V-int
Scroll_Flags_Copy_All_End:

Camera_Difference:
Camera_X_pos_diff:		ds.w	1	; (new X pos - old X pos) * 256
Camera_Y_pos_diff:		ds.w	1	; (new Y pos - old Y pos) * 256
Camera_Difference_End:

Camera_BG_X_pos_diff:		ds.w	1	; Effective camera change used in WFZ ending and HTZ screen shake
Camera_BG_Y_pos_diff:		ds.w	1	; Effective camera change used in WFZ ending and HTZ screen shake

Camera_Difference_P2:		; These WILL be used for Tails respawning.
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
Camera_Min_X_pos:		ds.w	1
Camera_Max_X_pos:		ds.w	1
Camera_Min_Y_pos:		ds.w	1
Camera_Max_Y_pos:		ds.w	1
Camera_Boundaries_End:

Camera_Delay:
Horiz_scroll_delay_val:		ds.w	1	; if its value is a, where a != 0, X scrolling will be based on the player's X position a-1 frames ago
Sonic_Pos_Record_Index:		ds.w	1	; into Sonic_Pos_Record_Buf and Sonic_Stat_Record_Buf
Camera_Delay_End:
Tails_Pos_Record_Index:		ds.w	1	; into Tails_Pos_Record_Buf

Camera_Y_pos_bias:		ds.w	1	; added to y position for lookup/lookdown, $60 is center
Camera_Y_pos_bias_End:

Deform_lock:			ds.b	1	; set to 1 to stop all deformation
HTZ_Terrain_Direction:		ds.b	1	; During HTZ screen shake, 0 if terrain/lava is rising, 1 if lowering
Camera_Max_Y_Pos_Changing:	ds.b	1
Dynamic_Resize_Routine:		ds.b	1
Camera_BG_X_offset:		ds.w	1	; Used to control background scrolling in X in WFZ ending and HTZ screen shake
Camera_BG_Y_offset:		ds.w	1	; Used to control background scrolling in Y in WFZ ending and HTZ screen shake
HTZ_Terrain_Delay:		ds.w	1	; During HTZ screen shake, this is a delay between rising and sinking terrain during which there is no shaking
Camera_X_pos_copy:		ds.l	1
Camera_Y_pos_copy:		ds.l	1

Camera_Boundaries_P2:
Tails_Min_X_pos:		ds.w	1
Tails_Max_X_pos:		ds.w	1
Tails_Min_Y_pos:		ds.w	1	; seems not actually implemented (only written to)
Tails_Max_Y_pos:		ds.w	1
Camera_Boundaries_P2_End:
Camera_RAM_End:
; ---------------------------------------------------------------------------

Block_cache:		ds.w	512/16*2		; Width of plane in blocks, with each block getting two words.

v_gamemode:		ds.w	1			; game mode - Pointer to the current Gamemode IN-ROM
Ctrl_1_Logical:
v_jpadholdlogical:	ds.b	1			; joypad input - held, duplicate
v_jpadpresslogical:	ds.b	1			; joypad input - pressed, duplicate
Ctrl_1:
v_jpadhold1:		ds.b	1			; joypad input - held
v_jpadpress1:		ds.b	1			; joypad input - pressed
Ctrl_2:
v_jpadhold2:		ds.b	1			; joypad input - held
v_jpadpress2:		ds.b	1			; joypad input - pressed

v_vdp_buffer1:		ds.w	1			; VDP instruction buffer
v_generictimer:		ds.w	1			; the length of a demo in frames
v_scrposy_vdp:		ds.w	1			; screen position y (VDP)
Vscroll_Factor		= v_scrposy_vdp
v_bgscrposy_vdp:	ds.w	1			; background screen position y (VDP)
v_scrposx_vdp:		ds.w	1			; screen position x (VDP)
v_bgscrposx_vdp:	ds.w	1			; background screen position x (VDP)
v_bg3scrposy_vdp:	ds.w	1
v_bg3scrposx_vdp:	ds.w	1
v_hbla_hreg:		ds.w	1			; VDP H.interrupt register buffer (8Axx)
v_hbla_line 		= v_hbla_hreg+1			; screen line where water starts and palette is changed by HBlank
v_pfade_start:		ds.b	1			; palette fading - start position in bytes
v_pfade_size:		ds.b	1			; palette fading - number of colours

v_misc_variables:
Lag_frame_count:	ds.w	1			; more specifically, the number of times V-int routine 0 has run. Reset at the end of a normal frame
v_vbla_counter:		ds.b	1			; VBlank - routine counter
v_spritecount:		ds.b	1			; number of sprites on-screen
v_vbla_routine:		ds.w	1
f_doupdatesinhblank:	ds.b	1			; defers performing various tasks to the Horizontal Interrupt (H-Blank)
f_hbla_pal:		ds.b	1			; flag set to change palette during HBlank (00 = no; 01 = change)
v_dma_thunk:		ds.w	1			; Used as a RAM holder for the final DMA command word. Data will NOT be preserved across V-INTs, so consider this space reserved.
v_pcyc_num:		ds.w	1			; palette cycling - current reference number
v_pcyc_num2:		ds.w	1			; palette cycling - current reference number
v_pcyc_num3:		ds.w	1			; palette cycling - current reference number
v_pcyc_time:		ds.w	1			; palette cycling - time until the next change
v_pcyc_time2:		ds.w	1			; palette cycling - time until the next change
v_pcyc_time3:		ds.w	1			; palette cycling - time until the next change
v_pal_buffer:		ds.b	$30			; palette data buffer (used for palette cycling)
v_random:		ds.l	1			; pseudo random number buffer
f_pause:		ds.w	1			; flag set to pause the game
v_waterpos1:		ds.w	1			; water height, actual
v_waterpos2:		ds.w	1			; water height, ignoring sway
v_waterpos3:		ds.w	1			; water height, next target
v_wtr_routine:		ds.b	1			; water event - routine counter
f_wtr_state:		ds.b	1			; water palette state when water is above/below the screen (00 = partly/all dry; 01 = all underwater)
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
Kos_module_queue:		ds.w	3*7		; 6 bytes per entry, first longword is source location and next word is VRAM destination
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
Boss_defeated_flag:	ds.b	1			;

Sonic_top_speed:	ds.w	1
Sonic_acceleration:	ds.w	1
Sonic_deceleration:	ds.w	1
Tails_top_speed:	ds.w	1
Tails_acceleration:	ds.w	1
Tails_deceleration:	ds.w	1
Sonic_LastLoadedDPLC:	ds.b	1
Tails_LastLoadedDPLC:		ds.b	1
TailsTails_LastLoadedDPLC:	ds.b	1
Primary_Angle:		ds.b	1
Secondary_Angle:	ds.b	1
Obj_placement_routine:	ds.b	1

Camera_X_pos_last:	ds.w	1			; Camera_X_pos_coarse from the previous frame
Camera_X_pos_last_End:
Camera_X_pos_last_P2:	ds.w	1
Camera_X_pos_last_P2_End:
Camera_X_pos_coarse:	ds.w	1			; (Camera_X_pos - 128) / 256
Camera_X_pos_coarse_End:
Camera_X_pos_coarse_P2:	ds.w	1
Camera_X_pos_coarse_P2_End:

Object_Manager_Addresses:
Obj_load_addr_right:	ds.l	1			; contains the address of the next object to load when moving right
Obj_load_addr_left:	ds.l	1			; contains the address of the last object loaded when moving left
Object_Manager_Addresses_End:

Object_Manager_Addresses_P2:
Obj_load_addr_right_P2:	ds.l	1
Obj_load_addr_left_P2:	ds.l	1
Object_Manager_Addresses_P2_End:

Demo_button_index:	ds.w	1			; index into button press demo data, for player 1
Demo_press_counter:	ds.b	1			; frames remaining until next button press, for player 1
Current_Timezone:	ds.b	1			; byte; Whether we're in the present, past, or Good/Bad future
PalChangeSpeed:		ds.w	1
Collision_addr:		ds.l	1
v_colladdr1:		ds.l	1
v_colladdr2:		ds.l	1
v_palbs_num:		ds.w	1			; palette cycling in Bonus Stage - reference number
v_palbs_time:		ds.w	1			; palette cycling in Bonus Stage - time until next change
v_bsbganim:		ds.w	1			; bonus Stage background animation

v_gfxbigring:		ds.w	1			; settings for giant ring graphics loading
f_lockscreen:		ds.b	1
f_wtunnelmode:		ds.b	1			; LZ water tunnel mode

f_playerctrl:		ds.b	1			; Player control override flags (object ineraction, control enable)
f_wtunnelallow:		ds.b	1			; LZ water tunnels (00 = enabled; 01 = disabled)
f_wtunnelallow_p2:	ds.b	1			; For tails too
f_slidemode:		ds.b	1			; LZ water slide mode

v_lz_deform:		ds.w	1			; LZ deformation offset, in units of $80
f_lockctrl:		ds.b	1
f_bigring:		ds.b	1			; flag set when Sonic collects the giant ring

v_itembonus:		ds.w	1			; item bonus from broken enemies, blocks etc.
v_timebonus:		ds.w	1			; time bonus at the end of an act
v_ringbonus:		ds.w	1			; ring bonus at the end of an act
f_endactbonus:		ds.b	1			; time/ring bonus update flag at the end of an act
Water_flag:		ds.b	1			; flag set for water

f_switch:		ds.b	$10			; flags set when Sonic stands on a switch
Anim_Counters:		ds.b	$10

v_levelvariables_end:

v_palette_water_fading: ds.b	palette_size		; duplicate underwater palette, used for transitions ($80 bytes)
v_palette_water_fading_end:
v_palette_water:	ds.b	palette_size		; main underwater palette
v_palette_water_end:
v_palette:		ds.b	palette_size		; main palette
v_palette_end:
v_palette_fading:	ds.b	palette_size		; duplicate palette, used for transitions
v_palette_fading_end:

v_crossresetram:					; RAM beyond this point is only cleared on a cold-boot
Level_Inactive_flag:	ds.w	1			; (2 bytes)
Timer_frames:		ds.w	1			; the number of frames which have elapsed since the level started
Debug_object:		ds.b	1			; the current position in the debug mode object list
			ds.b	1			; unused
Debug_placement_mode:	ds.b	1
			ds.b	1			; the whole word is tested, but the debug mode code uses only the low byte
Debug_Accel_Timer:	ds.b	1			; (1 byte)
Debug_Speed:		ds.b	1			; (1 byte)
v_vbla_byte =		*				; see next line
Vint_runcount:		ds.l	1			; v_vbla_byte in Sonic 1; the number of times V-int has run

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
v_lastbonus:		ds.b	1			; last bonus stage number
v_continues:		ds.b	1			; number of continues
f_timeover:		ds.b	1			; time over flag
v_lifecount:		ds.b	1			; lives counter value (for actual number, see "v_lives")
f_lifecount:		ds.b	1			; lives counter update flag
f_ringcount:		ds.b	1			; ring counter update flag
f_timecount:		ds.b	1			; time counter update flag
f_scorecount:		ds.b	1			; score counter update flag
v_rings:		ds.w	1			; rings
v_ringbyte		= v_rings+1			; low byte for rings
v_time:			ds.l	1			; time
v_timemin		= v_time+1			; time - minutes
v_timesec		= v_time+2			; time - seconds
v_timecent		= v_time+3			; time - centiseconds
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

			ds.b	$200			; will become used by the object table
			ds.b	$378			; free
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


; Bonus stage
v_ssbuffer1		= v_start
v_ssblockbuffer		= v_ssbuffer1+$1020		; $1020 bytes -- layout padded from the top and sides
v_ssblockbuffer_end	= v_ssblockbuffer+$80*$40	; ($2000 bytes)
v_ssbuffer2		= v_ssblockbuffer_end
v_ssblocktypes		= v_ssbuffer2
v_ssitembuffer		= v_ssbuffer2+$400		; ($1000 bytes)
v_ssitembuffer_end	= v_ssitembuffer+$100
v_ssbuffer3		= v_ssitembuffer+$500
v_ssscroll_buffer	= v_ssbuffer3+$400
v_ssangle		= v_ssscroll_buffer+$300
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

; ---------------------------------------------------------------------------
; RAM variables - Special stage
	phase	RAM_Start	; Move back to start of RAM
PNT_Buffer:			ds.b	$700
PNT_Buffer_End:
SSRAM_ArtNem_SpecialSonicAndTails:
				ds.b	tiles_to_bytes($353)	; $353 art blocks
SSRAM_MiscKoz_SpecialPerspective:
				ds.b	$1AFC
SSRAM_MiscNem_SpecialLevelLayout:
				ds.b	$180
				ds.b	$9C	; padding
SSRAM_MiscKoz_SpecialObjectLocations:
				ds.b	$1AE0
	;dephase			; Ends Deep in the block table; roughly $600 bytes before "TempArray_LayerDef"
; ---------------------------------------------------------------------------
	;phase (v_16x16+$1300)
		; The special stage mode also uses the rest of the RAM for
		; different purposes.
SSTrack_mappings_bitflags:		ds.l	1
SSTrack_mappings_uncompressed:		ds.l	1
SSTrack_anim:				ds.b	1
SSTrack_last_anim_frame:		ds.b	1
SpecialStage_CurrentSegment:		ds.b	1
SSTrack_anim_frame:			ds.b	1
SS_Alternate_PNT:			ds.b	1
SSTrack_drawing_index:			ds.b	1
SSTrack_Orientation:			ds.b	1
SS_Alternate_HorizScroll_Buf:		ds.b	1
SSTrack_mapping_frame:			ds.b	1
SS_Last_Alternate_HorizScroll_Buf:	ds.b	1
SS_New_Speed_Factor:			ds.l	1
SS_Cur_Speed_Factor:			ds.l	1
SSTrack_duration_timer:			ds.b	1
SS_player_anim_frame_timer:		ds.b	1
SpecialStage_LastSegment:		ds.b	1
SpecialStage_Started:			ds.b	1
SSTrack_last_mappings_copy:		ds.l	1
SSTrack_last_mappings:			ds.l	1
SSTrack_LastVScroll:			ds.w	1
SpecialStage_LastSegment2:		ds.b	1
SSTrack_last_mapping_frame:		ds.b	1
SSTrack_mappings_RLE:			ds.l	1
SSDrawRegBuffer:			ds.w	6
SSDrawRegBuffer_End
SS_Ctrl_Record_Buf:			ds.w	$10
SS_Ctrl_Record_Buf_End
SS_CurrentPerspective:			ds.l	1
SS_Check_Rings_flag:			ds.b	1
SS_Pause_Only_flag:			ds.b	1
SS_CurrentLevelObjectLocations:		ds.l	1
SS_Ring_Requirement:			ds.w	1
SS_CurrentLevelLayout:			ds.l	1
SS_2P_BCD_Score:			ds.b	1
SS_NoCheckpoint_flag:			ds.b	1
SS_Checkpoint_Rainbow_flag:		ds.b	1
SS_Rainbow_palette:			ds.b	1
SS_Perfect_rings_left:			ds.w	1
SS_Star_color_1:			ds.b	1
SS_Star_color_2:			ds.b	1
SS_NoCheckpointMsg_flag:		ds.b	1
SS_HideRingsToGo:			ds.b	1
SS_NoRingsTogoLifetime:			ds.w	1
SS_RingsToGoBCD:			ds.w	1
SS_TriggerRingsToGo:			ds.b	1
SS_Swap_Positions_Flag:			ds.b	1
SS_Offset_X:				ds.w	1
SS_Offset_Y:				ds.w	1
	dephase
; ---------------------------------------------------------------------------
	phase	ramaddr(v_hscrolltablebuffer)	; Still in SS RAM
SS_Horiz_Scroll_Buf_1		= v_hscrolltablebuffer
	dephase

	phase (Ring_Positions)
SS_Horiz_Scroll_Buf_2		= v_hscrolltablebuffer
	dephase
; ---------------------------------------------------------------------------
; RAM variables - Special stage Object RAM
	phase	v_objspace	; Move back to the object RAM
				ds.b	object_size
				ds.b	object_size
SpecialStageHUD:		; HUD in the special stage
				ds.b	object_size
SpecialStageStartBanner:
				ds.b	object_size
SpecialStageNumberOfRings:
				ds.b	object_size
SpecialStageShadow_Sonic:
				ds.b	object_size
SpecialStageShadow_Tails:
				ds.b	object_size
SpecialStageTails_Tails:
				ds.b	object_size
SS_Dynamic_Object_RAM:
				ds.b	$18*object_size
SpecialStageResults:
				ds.b	object_size
				ds.b	$C*object_size
SpecialStageResults2:
				ds.b	object_size
				ds.b	$51*object_size
SS_Dynamic_Object_RAM_End:
    if * > v_objspace_end
	fatal "Special stage objects go past end of object RAM buffer."
    endif
	dephase
; ---------------------------------------------------------------------------
	phase (v_palette_water_fading)
Underwater_target_palette:		ds.b palette_line_size	; This is used by the screen-fading subroutines.
Underwater_target_palette_line2:	ds.b palette_line_size	; While Underwater_palette contains the blacked-out palette caused by the fading,
Underwater_target_palette_line3:	ds.b palette_line_size	; Underwater_target_palette will contain the palette the screen will ultimately fade in to.
Underwater_target_palette_line4:	ds.b palette_line_size

Underwater_palette:			ds.b	palette_line_size	; main palette for underwater parts of the screen
Underwater_palette_line2:		ds.b	palette_line_size
Underwater_palette_line3:		ds.b	palette_line_size
Underwater_palette_line4:		ds.b	palette_line_size

Normal_palette:				ds.b	palette_line_size	; main palette for non-underwater parts of the screen
Normal_palette_line2:			ds.b	palette_line_size
Normal_palette_line3:			ds.b	palette_line_size
Normal_palette_line4:			ds.b	palette_line_size
Normal_palette_End:

Target_palette:				ds.b	palette_line_size	; This is used by the screen-fading subroutines.
Target_palette_line2:			ds.b	palette_line_size	; While Normal_palette contains the blacked-out palette caused by the fading,
Target_palette_line3:			ds.b	palette_line_size	; Target_palette will contain the palette the screen will ultimately fade in to.
Target_palette_line4:			ds.b	palette_line_size
Target_palette_End:
	dephase
; ---------------------------------------------------------------------------

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
bgm_GHZ =		MusID_ALZ
bgm_LZ =		MusID_MCZ
bgm_MZ =		MusID_CPZ
bgm_SLZ =		MusID_GRGZ1
bgm_SYZ =		MusID_DDZ1
bgm_SBZ =		MusID_LBZ1_S3
bgm_Invincible =	MusID_Invincible
bgm_ExtraLife =		MusID_ExtraLife
bgm_DoubleLife =	MusID_DoubleLife
bgm_SS =		MusID_BonusStage
bgm_Title =		MusID_Title
bgm_Ending =		MusID_Ending_S1
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
ArtTile_Ball_HogV:		equ $33E
ArtTile_Ball_HogH:		equ ArtTile_Ball_HogV+$18
ArtTile_Bomb:			equ $400
ArtTile_Ground_Explosion:	equ $385 ; Unused
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
ArtTile_Basaran:		equ $385
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