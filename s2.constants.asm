; ===========================================================================
; size variables - you'll get an informational error if you need to change these...
; they are all in units of bytes
Size_of_DAC_samples		= $2F00
Size_of_SEGA_sound		= $6978
Size_of_Snd_driver_guess	= $F64 ; approximate post-compressed size of the Z80 sound driver
; ---------------------------------------------------------------------------
; Object variables
; ---------------------------------------------------------------------------
; S3&K object placement: X word, Y/flags word, ID byte, subtype byte.
; Y flags: bit 13 = X flip, bit 14 = Y flip, bit 15 = load at any Y.
; ---------------------------------------------------------------------------
omX:		equ	0
omY:		equ	2
omID:		equ	4
omSubtype:	equ	5
omSize:		equ	6
omYMask:		equ	$FFF
omLoadAtAnyY:	equ	$8000
; Debug entries carry direct routine/mapping pointers; placement files do not.
DebugEntry_code:         equ $00
DebugEntry_mappings:     equ $04
DebugEntry_subtype:      equ $08
DebugEntry_frame:        equ $09
DebugEntry_art_tile:     equ $0A
DebugEntry_size:         equ $0C
Object_Load_BandSize:	equ $80
Object_Load_CoarseMask:	equ -Object_Load_BandSize
Object_Load_XBehind:	equ Object_Load_BandSize
Object_Load_XAhead:	equ $280	; screen plus two preload bands
Object_Load_YAbove:	equ Object_Load_BandSize
Object_Load_YBelow:	equ $200	; screen plus vertical preload margin
Level_YWrapMask:		equ $7FF	; the existing camera wraps at $800 pixels
; ---------------------------------------------------------------------------
; Object Status Table offsets (for everything between Object_RAM and Primary_Collision)
; ---------------------------------------------------------------------------
; Shared display/dispatch header, $00-$17. All normal object fields use
; these offsets; an object may overlay a field it does not use.
code:                   equ $00     ; long; routine address; zero = empty slot
obID =                  code        ; legacy spelling; longword, not a layout ID
obRender:               equ $04     ; byte; rendering flags
obFrame:                equ $05     ; byte; displayed mapping frame
height_pixels:          equ $06     ; byte; display half-height
obActWid:               equ $07     ; byte; display half-width
width_pixels =          obActWid
obPriority:             equ $08     ; word; sprite queue offset, in units of $80
obGfx:                  equ $0A     ; word; base tile and VDP attributes
obMap:                  equ $0C     ; long; mappings address
obX:                    equ $10     ; word, or long including fractional position
obXSub:                 equ $12     ; word; X fractional position
obY:                    equ $14     ; word, or long including fractional position
obYSub:                 equ $16     ; word; Y fractional position
; S3&K spellings for imported objects.
render_flags =          obRender
mapping_frame =         obFrame
priority =              obPriority
art_tile =              obGfx
mappings =              obMap
x_pos =                 obX
y_pos =                 obY
x_sub =                 obXSub
y_sub =                 obYSub
; ---------------------------------------------------------------------------
; Conventions followed by most objects, $18-$2D.
obVelX:                 equ $18     ; word; X velocity
obVelY:                 equ $1A     ; word; Y velocity
obHeight:               equ $1C     ; byte; collision Y radius
obWidth:                equ $1D     ; byte; collision X radius
obTimeFrame:            equ $1E     ; byte; animation frame timer
obAniFrame:             equ $1F     ; byte; position in animation script
obAnim:                 equ $20     ; byte; current animation
obPrevAni:              equ $21     ; byte; previous animation
respawn_addr:           equ $22     ; word; placement respawn-byte pointer; zero for dynamic/Debug objects
obRoutine:              equ $24     ; byte; main routine
ob2ndRout:              equ $25     ; byte; secondary routine
obAngle:                equ $26     ; byte; angle about the Z axis
obColType:              equ $28     ; byte; NPC collision response type
obColProp:              equ $29     ; byte; NPC collision property
obStatus:               equ $2A     ; byte; meaning depends on object type
obSubtype:              equ $2C     ; byte; primary subtype
ob2ndSubtype:           equ $2D     ; byte; optional secondary subtype, currently unused
; Animation delay counters remain local to the objects that need them.
; ---------------------------------------------------------------------------
; Player meanings. These bytes are private scratch in other object types.
obInertia:              equ $28     ; word; ground speed; overlays NPC collision type/property
scroll_delay_counter:   equ $2B     ; byte; camera look delay
flip_angle:             equ $27     ; byte; twist/tumble angle
air_left:               equ $2C     ; byte; companion Tails' independent air supply
flip_turned:            equ $2D     ; byte; tumble orientation
obControl:              equ $2E     ; byte; control override flags
obStatusSecondary:      equ $2F     ; byte; shield, invincibility, shoes and sliding
flips_remaining:        equ $30     ; byte
flip_speed:             equ $31     ; byte
move_lock:              equ $32     ; word; horizontal control lock timer
flashtime:              equ $34     ; word; post-hit invulnerability/blinking timer
invtime:                equ $36     ; word; invincibility duration
shoetime:               equ $38     ; word; speed shoes duration
next_tilt:              equ $3A     ; byte; forward ground sensor angle
tilt:                   equ $3B     ; byte; ground sensor angle
stick_to_convex:        equ $3C     ; byte
spindash_flag:          equ $3D     ; byte; charging/forced rolling state
pinball_mode =          spindash_flag
spindash_counter:       equ $3E     ; word; 8.8 spindash charge
restart_countdown =     spindash_counter
jumping:                equ $40     ; byte
standonobject:          equ $41     ; byte; object-slot index
obTopSolidBit:          equ $42     ; byte; top solidity bit
obLRBSolidBit:          equ $43     ; byte; side/bottom solidity bit
tails_hidden:           equ $44     ; byte; body's damage-blink decision
; $45 is available to the CPU respawn code.
player_dust_ptr:        equ $46     ; word; validated dust-controller pointer
default_y_radius:       equ $48     ; byte; standing collision Y radius
default_x_radius:       equ $49     ; byte; standing collision X radius
character_id:           equ $4A     ; byte; Sonic = 0, Tails = 1
CharacterID_Tails:      equ 1
tails_flight_flag:      equ $4B     ; byte; falling/flapping state
tails_flight_energy:    equ $4C     ; byte; half-frame flight budget
; $4D-$4F remain private scratch; display height is in the shared header.
tails_width:		equ 9
tails_roll_height:	equ 14
tails_roll_width:	equ 7
Tails_FlightBudget:	equ (8*60)/2
Tails_FlightGravity:	equ 8
Tails_FlapAcceleration:	equ $20
Tails_FlapRiseLimit:	equ $100
Tails_FlapStateLimit:	equ $20
Tails_ExtraFirstFrame:	equ $D1
Tails_CPU_ManualTime:	equ 10*60
Tails_CPU_RespawnTime:	equ 5*60
Tails_FlightAttackMinAngle: equ $20	; S3&K's upward contact sector
Tails_FlightAttackArc:	equ $40
Tails_CarriedYOffset:	equ 28
Sonic_CarriedFrameDelay:	equ 11
SonicFrame_CarriedBase:	equ $D5		; five existing prototype carry/sway poses
SonicFrame_CarriedFirst:	equ SonicFrame_CarriedBase+2
; Reuse the existing CPU words and unused tail-object scratch bytes. The
; controller's owner remains in obParent; no SST or global RAM expansion.
v_jpadholdlogical2:	equ word_F700
v_jpadpresslogical2:	equ v_jpadholdlogical2+1
Tails_CPU_idle_timer:	equ Tails_control_counter
Tails_CPU_flight_timer:	equ Tails_respawn_counter
Tails_CPU_interact:	equ v_player2tails+objoff_2E	; long; remembered standing-object code
Tails_CPU_target_X:	equ v_player2tails+objoff_44
Tails_CPU_target_Y:	equ v_player2tails+objoff_46
Tails_CPU_auto_jump_flag:	equ v_player2tails+objoff_39
Flying_carrying_Sonic_flag: equ v_player2tails+objoff_3C
Tails_Carry_RegrabDelay:	equ v_player2tails+objoff_3D
Tails_Carry_SavedXSpeed:	equ v_player2tails+objoff_3E
Tails_Carry_SavedYSpeed:	equ v_player2tails+objoff_40
; ---------------------------------------------------------------------------
; Raw scratch aliases name their actual offsets. Their availability depends
; on the services used by an object; they do not reserve extra RAM.
objoff_25:             equ $25
objoff_26:             equ $26
objoff_27:             equ $27
objoff_28:             equ $28
objoff_29:             equ $29
objoff_2A:             equ $2A
objoff_2B:             equ $2B
objoff_2C:             equ $2C
objoff_2D:             equ $2D
objoff_2E:             equ $2E
objoff_2F:             equ $2F
objoff_30:             equ $30
objoff_31:             equ $31
objoff_32:             equ $32
objoff_33:             equ $33
objoff_34:             equ $34
objoff_35:             equ $35
objoff_36:             equ $36
objoff_37:             equ $37
objoff_38:             equ $38
objoff_39:             equ $39
objoff_3A:             equ $3A
objoff_3B:             equ $3B
objoff_3C:             equ $3C
objoff_3D:             equ $3D
objoff_3E:             equ $3E
objoff_3F:             equ $3F
objoff_40:             equ $40
objoff_41:             equ $41
objoff_42:             equ $42
objoff_43:             equ $43
objoff_44:             equ $44
objoff_45:             equ $45
objoff_46:             equ $46
objoff_47:             equ $47
objoff_48:             equ $48
objoff_49:             equ $49
objoff_4A:             equ $4A
objoff_4B:             equ $4B
objoff_4C:             equ $4C
objoff_4D:             equ $4D
objoff_4E:             equ $4E
objoff_4F:             equ $4F
objoff_50:             equ $50     ; one past the end of the SST
; ---------------------------------------------------------------------------
; Screen-space and parent/child overlays.
obScreenX =             obX
obScreenY =             obXSub     ; retained S2 screen Y convention
obParent =              objoff_42  ; word
obParent2 =             objoff_44  ; word
obParent3 =             objoff_46  ; word
child_dx =              objoff_46  ; byte; alternative to obParent3
child_dy =              objoff_47  ; byte
object_size_bits:       equ 6      ; allocator lookup buckets, not SST stride
object_size:            equ $50    ; 80 bytes; eight star children plus orbit state; longword clearing
reserved_object_slots: equ 23
dynamic_object_slots:  equ 90
object_slot_count:      equ reserved_object_slots+dynamic_object_slots
object_ram_size:        equ object_size*object_slot_count ; $2350; keep all 113 slots
next_object =           object_size
    if (object_size<(1<<object_size_bits))||((object_size&1)<>0)
        fatal "SSTs must be even-sized and at least as large as an allocator lookup bucket."
    endif
    if (dynamic_object_slots<1)||(object_slot_count>$80)
        fatal "The object pool must fit its byte references and MOVEQ counter."
    endif
    if (dynamic_object_slots*object_size)/(1<<object_size_bits)>$FF
        fatal "The allocator lookup index must fit its loop-counter register."
    endif
; ---------------------------------------------------------------------------
; Optional boss aliases.
boss_subtype =              obXSub
boss_invulnerable_time =    obInertia
boss_sine_count =           obFrame
boss_routine =              obAngle
boss_defeated =             objoff_30
boss_hitcount2 =            objoff_36
boss_hurt_sonic =           objoff_3C
; ---------------------------------------------------------------------------
; Composite overlay. Y's fractional byte holds the child count;
; $18-$47 holds eight six-byte records.
next_subspr =           6
mainspr_mapframe =      obFrame
mainspr_width =         width_pixels
mainspr_childsprites =  obYSub
mainspr_height =        height_pixels
subspr_data =           $18
sub2_x_pos =          $18
sub2_y_pos =          $1A
sub2_mapframe =       $1D
sub3_x_pos =          $1E
sub3_y_pos =          $20
sub3_mapframe =       $23
sub4_x_pos =          $24
sub4_y_pos =          $26
sub4_mapframe =       $29
sub5_x_pos =          $2A
sub5_y_pos =          $2C
sub5_mapframe =       $2F
sub6_x_pos =          $30
sub6_y_pos =          $32
sub6_mapframe =       $35
sub7_x_pos =          $36
sub7_y_pos =          $38
sub7_mapframe =       $3B
sub8_x_pos =          $3C
sub8_y_pos =          $3E
sub8_mapframe =       $41
sub9_x_pos =          $42
sub9_y_pos =          $44
sub9_mapframe =       $47
; ---------------------------------------------------------------------------
; Animation flags
afEnd:		equ $FF	; return to beginning of animation
afBack:		equ $FE	; go back (specified number) bytes
afChange:	equ $FD	; run specified animation
afRoutine:	equ $FC	; increment routine counter
afReset:	equ $FB	; reset animation and 2nd object routine counter
af2ndRoutine:	equ $FA	; increment 2nd routine counter
; ---------------------------------------------------------------------------
; Player collision sizes
tails_height:		equ 30/2	; Tails's standing radius
sonic_width:		equ 18/2	; Sonic's width
sonic_height:		equ 38/2	; Sonic's height
sonic_roll_width:	equ 14/2	; Sonic's width (rolling)
sonic_roll_height:	equ 28/2	; Sonic's height (rolling)
sonic_solid_width:	equ 22/2	; Sonic's width (solid object collision)
sonic_react_width:	equ 16/2	; Sonic's width (object collision)
sonic_duck_height:	equ 20/2	; Sonic's height (object collision, ducking)
sonic_quick_size:	equ 20/2	; Sonic's size (quick terrain find)
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
; obRender bitfield
obRender.x_flip			= 0 ; Sprite mirrored horizontally.
obRender.y_flip			= 1 ; Sprite mirrored vertically.
obRender.level_fg		= 2 ; Move with level foreground.
obRender.level_bg		= 3 ; Move with level background; leftover from Sonic 1.
obRender.explicit_height	= 4 ; Legacy composite flag; display height is always height_pixels.
obRender.static_mappings	= 5 ; Mappings pointer points directly to a lone sprite piece instead of a list of sprites.
obRender.multi_sprite		= 6 ; Object SST holds metadata for multiple sprites.
obRender.on_screen		= 7 ; Object is on-screen and was rendered on the previous frame.
; ---------------------------------------------------------------------------
; (Sonic 2 github compatibility)
render_flags.x_flip		= obRender.x_flip
render_flags.y_flip		= obRender.y_flip
render_flags.level_fg		= obRender.level_fg
render_flags.level_bg		= obRender.level_bg
render_flags.explicit_height	= obRender.explicit_height
render_flags.static_mappings	= obRender.static_mappings
render_flags.multi_sprite	= obRender.multi_sprite
render_flags.on_screen		= obRender.on_screen
; ---------------------------------------------------------------------------
; status bitfield

status.player.x_flip			= render_flags.x_flip ; Facing left.
status.player.in_air			= 1 ; Airborne.
status.player.rolling			= 2 ; Spinning, i.e. jumping or rolling.
status.player.on_object			= 3 ; Stood on an object rather than the level.
status.sidekick.on_object		= 4 ; Stood on an object rather than the level.
status.player.rolljumping		= 4 ; Legacy bit, cleared on carry/flight; air steering stays enabled.
status.player.pushing			= 5 ; Pressing against an object.
status.player.underwater		= 6 ; Submersed.
status.player.prevent_tails_respawn	= 7 ; Prevents AI Tails from respawning.

status.player.ss.x_flip		= render_flags.x_flip ; Sprite mirrored horizontally.
status.player.ss.y_flip		= render_flags.y_flip ; Sprite mirrored vertically.
status.player.ss.jumping	= 2 ; Jumping.
status.player.ss.slowing	= 6 ; Coming to a stop after moving or landing.

status.npc.x_flip		= render_flags.x_flip ; Facing right.
status.npc.y_flip		= render_flags.y_flip ; Facing up.
status.npc.misc			= 2 ; Used for various purposes by bosses.
status.npc.p1_standing		= 3 ; Stood on by player 1.
status.npc.p2_standing		= 4 ; Stood on by player 2.
status.npc.p1_pushing		= 5 ; Pushed by player 1.
status.npc.p2_pushing		= 6 ; Pushed by player 2.
status.npc.no_balancing		= 7 ; Prevents player from performing their balancing animation whilst stood upon this object. Also set when the object is destroyed by the player.

; ---------------------------------------------------------------------------
; status_secondary bitfield

status_secondary.shield		= 0
status_secondary.invincible	= 1
status_secondary.speed_shoes	= 2
status_secondary.sliding	= 7

; Ugly old constants, kept for backwards-compatibility.

; status_secondary variable bit numbers
status_sec_hasShield:		EQU	status_secondary.shield
status_sec_isInvincible:	EQU	status_secondary.invincible
status_sec_hasSpeedShoes:	EQU	status_secondary.speed_shoes
status_sec_isSliding:		EQU	status_secondary.sliding
; status_secondary variable masks (1 << x == pow(2, x))
status_sec_hasShield_mask:	EQU	1<<status_sec_hasShield		; $01
status_sec_isInvincible_mask:	EQU	1<<status_sec_isInvincible	; $02
status_sec_hasSpeedShoes_mask:	EQU	1<<status_sec_hasSpeedShoes	; $04
status_sec_isSliding_mask:	EQU	1<<status_sec_isSliding		; $80

; ---------------------------------------------------------------------------
; Controller Buttons
;
; Buttons bit numbers
button_up:			EQU	0
button_down:			EQU	1
button_left:			EQU	2
button_right:			EQU	3
button_B:			EQU	4
button_C:			EQU	5
button_A:			EQU	6
button_start:			EQU	7
; Buttons masks (1 << x == pow(2, x))
button_up_mask:			EQU	1<<button_up	; $01
button_down_mask:		EQU	1<<button_down	; $02
button_left_mask:		EQU	1<<button_left	; $04
button_right_mask:		EQU	1<<button_right	; $08
button_B_mask:			EQU	1<<button_B	; $10
button_C_mask:			EQU	1<<button_C	; $20
button_A_mask:			EQU	1<<button_A	; $40
button_start_mask:		EQU	1<<button_start	; $80

; ---------------------------------------------------------------------------
; Bits 3-6 of an object's status after a SolidObject call is a
; bitfield with the following meaning:
p1_standing_bit   = status.npc.p1_standing
p2_standing_bit   = p1_standing_bit + 1

p1_standing       = 1<<p1_standing_bit
p2_standing       = 1<<p2_standing_bit

pushing_bit_delta = status.npc.p1_pushing-status.npc.p1_standing
p1_pushing_bit    = p1_standing_bit + pushing_bit_delta
p2_pushing_bit    = p1_pushing_bit + 1

p1_pushing        = 1<<p1_pushing_bit
p2_pushing        = 1<<p2_pushing_bit


standing_mask     = p1_standing|p2_standing
pushing_mask      = p1_pushing|p2_pushing

; ---------------------------------------------------------------------------
; The high word of d6 after a SolidObject call is a bitfield
; with the following meaning:
p1_touch_side_bit   = 0
p2_touch_side_bit   = p1_touch_side_bit + 1

p1_touch_side       = 1<<p1_touch_side_bit
p2_touch_side       = 1<<p2_touch_side_bit

touch_side_mask     = p1_touch_side|p2_touch_side

p1_touch_bottom_bit = p1_touch_side_bit + pushing_bit_delta
p2_touch_bottom_bit = p1_touch_bottom_bit + 1

p1_touch_bottom     = 1<<p1_touch_bottom_bit
p2_touch_bottom     = 1<<p2_touch_bottom_bit

touch_bottom_mask   = p1_touch_bottom|p2_touch_bottom

p1_touch_top_bit   = p1_touch_bottom_bit + pushing_bit_delta
p2_touch_top_bit   = p1_touch_top_bit + 1

p1_touch_top       = 1<<p1_touch_top_bit
p2_touch_top       = 1<<p2_touch_top_bit

touch_top_mask     = p1_touch_top|p2_touch_top

; ---------------------------------------------------------------------------
; Player modes (character selection remains a future feature)
PlayerMode_SonicAndTails:	equ 0
PlayerMode_Sonic:		equ 1
PlayerMode_Tails:		equ 2
PlayerMode_Knuckles:		equ 3	; reserved
PlayerControl_SkipWallCollision:	equ 6	; bit in f_playerctrl and obControl

; Shared Sonic/Tails movement settings. Speeds use 8.8 pixels/frame;
; acceleration and deceleration use 8.8 pixels/frame squared.
Player_DefaultTopSpeed:		equ $600
Player_DefaultAcceleration:	equ $C
Player_DefaultDeceleration:	equ $80
Player_ShoesTopSpeed:		equ $C00
Player_ShoesAcceleration:	equ $18

; Normal Sonic movement from S3&K. Velocities use 8.8 pixels/frame.
Sonic_RollStartSpeed:		equ $100
Sonic_RollStopSpeed:		equ $80
Sonic_RollBraking:		equ $20
Sonic_ForcedRollSpeed:		equ $400
Sonic_RollMaxXSpeed:		equ $1000
Sonic_JumpSpeed:			equ $680
Sonic_WaterJumpSpeed:		equ $380
Sonic_JumpReleaseSpeed:		equ $400
Sonic_WaterJumpReleaseSpeed:	equ $200
Sonic_UpwardSpeedLimit:		equ $FC0
Sonic_WaterExitSpeedLimit:	equ $1000
Sonic_CeilingPenetrationLimit:	equ 20	; pixels; deeper overlaps check the opposite wall
Sonic_DeathScreenMargin:		equ $100	; pixels below the frozen camera
Player_HurtFlashTime:		equ 2*60	; frames
Sonic_SlopeStandingThreshold:	equ $D
Sonic_SlopeDetachSpeed:		equ $280
Sonic_SlopeLockTime:		equ 30	; frames
Sonic_SlopeSlipStep:		equ $80
Sonic_SpindashChargeStep:		equ $200
Sonic_SpindashMaxCharge:		equ $800
Sonic_SpindashDecayShift:		equ 5	; lose 1/32 of the accumulated charge per frame
Sonic_SpindashMinSpeed:		equ $800
Sonic_SpindashSpeedStep:		equ $80
Sonic_SpindashCameraDelayMax:	equ 32	; frames; reduced as launch speed increases

; Debug mode IDs occupy the low byte of the routine/type word.
DebugType_Placement:	equ 1
DebugType_FrameCycle:	equ 2

; Look camera: delays are frames; biases and steps are pixels.
Camera_LookDelay:		equ 120
Camera_LookCenter:		equ 96	; 16 pixels above the 224-pixel screen's centre
Camera_LookUpLimit:		equ 200
Camera_LookDownLimit:		equ 8
Camera_LookPanSpeed:		equ 2
Camera_LookReturnSpeed:		equ 2

; Scores are stored in 10-point units; the HUD appends a fixed trailing zero.
Score_Max:		equ 999999	; displayed cap: 9,999,990

; ---------------------------------------------------------------------------
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
offset :=	SonicAniData
ptrsize :=	2
idstart :=	0

AniIDSonAni_Walk		= id(SonAni_Walk_ptr)		;  0 ;   0
AniIDSonAni_Run			= id(SonAni_Run_ptr)		;  1 ;   1
AniIDSonAni_Roll		= id(SonAni_Roll_ptr)		;  2 ;   2
AniIDSonAni_Roll2		= id(SonAni_Roll2_ptr)		;  3 ;   3
AniIDSonAni_Push		= id(SonAni_Push_ptr)		;  4 ;   4
AniIDSonAni_Wait		= id(SonAni_Wait_ptr)		;  5 ;   5
AniIDSonAni_Balance		= id(SonAni_Balance_ptr)	;  6 ;   6
AniIDSonAni_LookUp		= id(SonAni_LookUp_ptr)		;  7 ;   7
AniIDSonAni_Duck		= id(SonAni_Duck_ptr)		;  8 ;   8
AniIDSonAni_Spindash		= id(SonAni_Spindash_ptr)	;  9 ;   9
AniIDSonAni_Blink		= id(SonAni_Blink_ptr)		; 10 ;  $A ; Exclusive to Sonic
AniIDSonAni_GetUp		= id(SonAni_GetUp_ptr)		; 11 ;  $B ; Exclusive to Sonic
AniIDSonAni_Balance2		= id(SonAni_Balance2_ptr)	; 12 ;  $C ; Exclusive to Sonic
AniIDSonAni_Stop		= id(SonAni_Stop_ptr)		; 13 ;  $D
AniIDSonAni_Float		= id(SonAni_Float_ptr)		; 14 ;  $E
AniIDSonAni_Float2		= id(SonAni_Float2_ptr)		; 15 ;  $F
AniIDSonAni_Spring		= id(SonAni_Spring_ptr)		; 16 ; $10
AniIDSonAni_Hang		= id(SonAni_Hang_ptr)		; 17 ; $11
AniIDSonAni_Dash2		= id(SonAni_Dash2_ptr)		; 18 ; $12 ; Unused.
AniIDSonAni_Dash3		= id(SonAni_Dash3_ptr)		; 19 ; $13 ; Unused.
AniIDSonAni_Hang2		= id(SonAni_Hang2_ptr)		; 20 ; $14
AniIDSonAni_Bubble		= id(SonAni_Bubble_ptr)		; 21 ; $15
AniIDSonAni_DeathBW		= id(SonAni_DeathBW_ptr)	; 22 ; $16
AniIDSonAni_Drown		= id(SonAni_Drown_ptr)		; 23 ; $17
AniIDSonAni_Death		= id(SonAni_Death_ptr)		; 24 ; $18
AniIDSonAni_Hurt		= id(SonAni_Hurt_ptr)		; 25 ; $19
AniIDSonAni_Hurt2		= id(SonAni_Hurt2_ptr)		; 26 ; $1A
AniIDSonAni_Slide		= id(SonAni_Slide_ptr)		; 27 ; $1B
AniIDSonAni_Blank		= id(SonAni_Blank_ptr)		; 28 ; $1C
AniIDSonAni_Balance3		= id(SonAni_Balance3_ptr)	; 29 ; $1D ; Exclusive to Sonic
AniIDSonAni_Balance4		= id(SonAni_Balance4_ptr)	; 30 ; $1E ; Exclusive to Sonic
AniIDSupSonAni_Transform	= id(SupSonAni_Transform_ptr)	; 31 ; $1F ; Exclusive to Sonic
AniIDSonAni_Lying		= id(SonAni_Lying_ptr)		; 32 ; $20 ; Exclusive to Sonic
AniIDSonAni_LieDown		= id(SonAni_LieDown_ptr)	; 33 ; $21 ; Exclusive to Sonic
AniIDSonAni_Carried		= id(SonAni_Carried_ptr)	; 35 ; $23 ; Sonic carried by Tails


	; TODO -- will get to this as soon as I'm done with Sonic.
; offset :=	TailsAniData
; ptrsize :=	2
; idstart :=	0
; 
; AniIDTailsAni_Walk		= id(TailsAni_Walk_ptr)		;  0 ;   0
; AniIDTailsAni_Run		= id(TailsAni_Run_ptr)		;  1 ;   1
; AniIDTailsAni_Roll		= id(TailsAni_Roll_ptr)		;  2 ;   2
; AniIDTailsAni_Roll2		= id(TailsAni_Roll2_ptr)	;  3 ;   3
; AniIDTailsAni_Push		= id(TailsAni_Push_ptr)		;  4 ;   4
; AniIDTailsAni_Wait		= id(TailsAni_Wait_ptr)		;  5 ;   5
; AniIDTailsAni_Balance		= id(TailsAni_Balance_ptr)	;  6 ;   6
; AniIDTailsAni_LookUp		= id(TailsAni_LookUp_ptr)	;  7 ;   7
; AniIDTailsAni_Duck		= id(TailsAni_Duck_ptr)		;  8 ;   8
; AniIDTailsAni_Spindash		= id(TailsAni_Spindash_ptr)	;  9 ;   9
; AniIDTailsAni_Dummy1		= id(TailsAni_Dummy1_ptr)	; 10 ;  $A
; AniIDTailsAni_Dummy2		= id(TailsAni_Dummy2_ptr)	; 11 ;  $B
; AniIDTailsAni_Dummy3		= id(TailsAni_Dummy3_ptr)	; 12 ;  $C
; AniIDTailsAni_Stop		= id(TailsAni_Stop_ptr)		; 13 ;  $D
; AniIDTailsAni_Float		= id(TailsAni_Float_ptr)	; 14 ;  $E
; AniIDTailsAni_Float2		= id(TailsAni_Float2_ptr)	; 15 ;  $F
; AniIDTailsAni_Spring		= id(TailsAni_Spring_ptr)	; 16 ; $10
; AniIDTailsAni_Hang		= id(TailsAni_Hang_ptr)		; 17 ; $11
; AniIDTailsAni_Blink		= id(TailsAni_Blink_ptr)	; 18 ; $12
; AniIDTailsAni_Blink2		= id(TailsAni_Blink2_ptr)	; 19 ; $13
; AniIDTailsAni_Hang2		= id(TailsAni_Hang2_ptr)	; 20 ; $14
; AniIDTailsAni_Bubble		= id(TailsAni_Bubble_ptr)	; 21 ; $15
; AniIDTailsAni_DeathBW		= id(TailsAni_DeathBW_ptr)	; 22 ; $16
; AniIDTailsAni_Drown		= id(TailsAni_Drown_ptr)	; 23 ; $17
; AniIDTailsAni_Death		= id(TailsAni_Death_ptr)	; 24 ; $18
; AniIDTailsAni_Hurt		= id(TailsAni_Hurt_ptr)		; 25 ; $19
; AniIDTailsAni_Hurt2		= id(TailsAni_Hurt2_ptr)	; 26 ; $1A
; AniIDTailsAni_Slide		= id(TailsAni_Slide_ptr)	; 27 ; $1B
; AniIDTailsAni_Blank		= id(TailsAni_Blank_ptr)	; 28 ; $1C
; AniIDTailsAni_Dummy4		= id(TailsAni_Dummy4_ptr)	; 29 ; $1D
; AniIDTailsAni_Dummy5		= id(TailsAni_Dummy5_ptr)	; 30 ; $1E
; AniIDTailsAni_HaulAss		= id(TailsAni_HaulAss_ptr)	; 31 ; $1F
; AniIDTailsAni_Fly		= id(TailsAni_Fly_ptr)		; 32 ; $20

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
vram_hscroll:		equ $F000			; horizontal scroll table
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
VRAM_Horiz_Scroll_Table                  = $F000	; Extends until $F37F
VRAM_Horiz_Scroll_Table_Size             = 224*2*2	; 224 lines * 2 bytes per entry * 2 PNTs
; Level-mode tile $79C ($F380), up to the $F800 sprite table, is reserved
; for shared shield/invincibility art. A second shield bank at tile $56E
; ($ADC0) permits independent shield phases and mixed shield/star states.
; The S1 stage has its own ring/sparkle bank at $2940.

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
; Sound and Music tables
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

; Background music
bgm_GHZ =		MusID_ALZ
bgm_LZ =		MusID_LZ
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

; Sound effects -- Note: Some files are offset by +-$1E. That's a mess for future me to sort out
sfx_Jump =		SndID_Jump
sfx_Lamppost =		SndID_Checkpoint
sfx_SpikeSwitch =	SndID_SpikeSwitch
sfx_Death =		SndID_Hurt
sfx_Skid =		SndID_Skidding
sfx_Push =		SndID_BlockPush
sfx_HitSpikes =		SndID_HurtBySpikes
sfx_A5 =		SndID_MegaMackDrop
sfx_SSGoal =		SndID_Goal
sfx_SSItem =		SndID_Bwoop
sfx_Splash =		SndID_Splash
sfx_Grab =		SndID_TailsGrab
sfx_Flying =		SndID_TailsFlying
sfx_FlyTired =		SndID_TailsFlyingTired
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
sfx_B8 =		SndID_DoorSlam		; 56
sfx_Collapse =		SndID_Smash
sfx_SSGlass =		SndID_Glass
sfx_Door =		SndID_Trapdoor		; 59
sfx_Teleport =		SndID_SpindashRelease
sfx_ChainStomp =	SndID_ChainRise
sfx_Roll =		SndID_Roll
sfx_Spindash =		SndID_SpindashRev
sfx_Dash =		SndID_SpindashRelease
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
sfx_Switch =		SndID_Blip	; file Sound4D.asm; internally 6B
sfx_RingLeft =		SndID_RingLeft
sfx_Signpost =		SndID_Signpost

; Special sound effects
sfx_Waterfall =	$D0

bgm_Fade =		MusID_FadeOut
sfx_Sega =		SndID_SegaSound
bgm_Speedup =		MusID_SpeedUp
bgm_Slowdown =		MusID_SlowDown
bgm_Stop =		MusID_Stop

; ===========================================================================
; ---------------------------------------------------------------------------
; Main RAM
; ---------------------------------------------------------------------------
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
Kos_decomp_buffer:		ds.b	$1000		; Moduled Kosinski+ decompression buffer
; ---------------------------------------------------------------------------
    if object_size*object_slot_count > object_ram_size
	fatal "Object slots exceed the reserved object RAM growth area."
    endif
v_objspace:			ds.b	object_size*object_slot_count
v_objspace_end:
; ---------------------------------------------------------------------------
; Title screen objects
v_sonicteam	= v_objspace+object_size*1		; object variable space for the "SONIC TEAM PRESENTS" text (1 SST)
v_titlesonic	= v_objspace+object_size*2		; object variable space for Sonic in the title screen (1 SST)
v_titletails	= v_objspace+object_size*3		; object variable space for Tails in the title screen (1 SST)
v_ttlsonichide	= v_objspace+object_size*4		; object variable space for hiding part of Sonic (1 SST)
v_pressstart	= v_objspace+object_size*5		; object variable space for the "PRESS START BUTTON" text (1 SST)
; ---------------------------------------------------------------------------
; Reserved object slots
v_player	= v_objspace+object_size*0		; object variable space for Sonic (1 SST)
v_player2	= v_objspace+object_size*1		; object variable space for Tails (1 SST)
v_player2tails	= v_objspace+object_size*6		; object variable space for Tails' Tails (1 SST)
v_shieldobj	= v_objspace+object_size*7		; object variable space for Sonic's shield (1 SST)
v_shieldobj2	= v_objspace+object_size*8		; object variable space for Tails's shield (1 SST)
v_starsobj	= v_objspace+object_size*9		; primary eight-star effect; partner uses one dynamic SST

v_splash	= v_objspace+object_size*10		; object variable space for Sonic's water splash (1 SST)
v_tsplash	= v_objspace+object_size*11		; object variable space for Tails's water splash (1 SST)
v_sonicbubbles	= v_objspace+object_size*12		; object variable space for the bubbles that come out of Sonic's mouth/drown countdown (1 SST)
v_tailsbubbles	= v_objspace+object_size*13		; object variable space for the bubbles that come out of Tails's mouth/drown countdown (1 SST)
v_watersurface1	= v_objspace+object_size*14		; object variable space for the water surface #1 (1 SST)
v_watersurface2	= v_objspace+object_size*15		; object variable space for the water surface #2 (1 SST)

v_gameovertext1	= v_objspace+object_size*2		; object variable space for the "GAME"/"TIME" in "GAME OVER"/"TIME OVER" text (1 SST)
v_gameovertext2	= v_objspace+object_size*3		; object variable space for the "OVER" in "GAME OVER"/"TIME OVER" text (1 SST)
; ---------------------------------------------------------------------------
; Start/End of level objects (Part of the above; used exclusively at the beginning/end of a level)
v_titlecard	= v_objspace+object_size*2		; object variable space for the title card (4 SSTs)
v_ttlcardname	= v_titlecard+object_size*0		; object variable space for the title card zone name text (1 SST)
v_ttlcardzone	= v_titlecard+object_size*1		; object variable space for the title card "ZONE" text (1 SST)
v_ttlcardact	= v_titlecard+object_size*2		; object variable space for the title card act text (1 SST)
v_ttlcardoval	= v_titlecard+object_size*3		; object variable space for the title card oval (1 SST)

v_endcard	= v_objspace+object_size*16		; object variable space for the level results card (7 SSTs)
v_endcardsonic	= v_endcard+object_size*0		; object variable space for the level results card "SONIC HAS" text (1 SST)
v_endcardpassed	= v_endcard+object_size*1		; object variable space for the level results card "PASSED" text (1 SST)
v_endcardact	= v_endcard+object_size*2		; object variable space for the level results card act text (1 SST)
v_endcardscore	= v_endcard+object_size*3		; object variable space for the level results card score tally (1 SST)
v_endcardtime	= v_endcard+object_size*4		; object variable space for the level results card time bonus tally (1 SST)
v_endcardring	= v_endcard+object_size*5		; object variable space for the level results card ring bonus tally (1 SST)
v_endcardoval	= v_endcard+object_size*6		; object variable space for the level results card oval (1 SST)
	if v_endcardoval+object_size>v_objspace+reserved_object_slots*object_size
		fatal "The level results card overlaps the dynamic object pool."
	endif
; ---------------------------------------------------------------------------
; Dynamic slots -- for all other objects
v_lvlobjspace	= v_objspace+object_size*reserved_object_slots	; 90 dynamic slots
v_lvlobjend	= v_objspace_end
v_objend	= v_lvlobjend

; Bonus Stage objects
v_bsrescard	= v_objspace+object_size*16		; object variable space for the Bonus Stage results card (5 SSTs)
v_bsrestext	= v_bsrescard+object_size*0		; object variable space for the Bonus Stage results card text (1 SST)
v_bsresscore	= v_bsrescard+object_size*1		; object variable space for the Bonus Stage results card score tally (1 SST)
v_bsresring	= v_bsrescard+object_size*2		; object variable space for the Bonus Stage results card ring bonus tally (1 SST)
v_bsresoval	= v_bsrescard+object_size*3		; object variable space for the Bonus Stage results card oval (1 SST)
v_ssrescontinue	= v_bsrescard+object_size*4		; object variable space for the Bonus Stage results card continue icon (1 SST)
v_ssresemeralds	= v_objspace+object_size*32		; object variable space for the emeralds in the Bonus Stage results (6 SSTs)

; Continue screen objects
v_continuetext	= v_objspace+object_size*1		; object variable space for the continue screen text (1 SST)
v_continuelight	= v_objspace+object_size*2		; object variable space for the continue screen light spot (1 SST)
v_continueicon	= v_objspace+object_size*3		; object variable space for the continue screen icon (1 SST)

; Ending objects
v_endemeralds	= v_objspace+object_size*16		; object variable space for the emeralds in the ending (6 SSTs)
v_endemeralds_end	= v_objspace+object_size*32
v_endlogo	= v_objspace+object_size*16		; object variable space for the logo in the ending (1 SST)

; Credits objects
v_credits	= v_objspace+object_size*2		; object variable space for the credits text (1 SST)
v_endeggman	= v_objspace+object_size*2		; object variable space for Eggman after the credits (1 SST)
v_tryagain	= v_objspace+object_size*3		; object variable space for the "TRY AGAIN" text (1 SST)
v_eggmanchaos	= v_objspace+object_size*32		; object variable space for the emeralds juggled by Eggman (6 SSTs)
; ---------------------------------------------------------------------------
				ds.b	object_ram_size-(v_objspace_end-v_objspace)	; unused object RAM budget, if any
v_16x16:			ds.b	$1800		; $1800 bytes

TempArray_LayerDef:		ds.b	$200		; background scroll buffer
v_bgscroll_buffer:=		TempArray_LayerDef
v_hscrolltablebuffer:		ds.b	$380		; scrolling table data
v_hscrolltablebuffer_end:
				ds.b	$80		; would be unused, but data from v_hscrolltablebuffer can spill into here
v_hscrolltablebuffer_end_padded:
Sprite_Table_Max:		equ 80
Sprite_Table:			ds.b	Sprite_Table_Max*8		; Sprite attribute table buffer
Sprite_Table_end:
				ds.b	$140		; stack
v_systemstack:
v_ngfx_buffer:			ds.b	$200		; Nemesis graphics decompression buffer
v_ngfx_buffer_end:

Error_Handler_Buffer:		ds.b	$45		; register/SP/error-type overlay below
				ds.b	1		; align the Debug snapshot after the error buffer
Debug_saved_mappings:		ds.l	1
Debug_saved_art_tile:		ds.w	1
Debug_saved_width:		ds.b	1
Debug_saved_height:		ds.b	1
	if object_ram_size-$2200>$2B2
		fatal "Object RAM growth exceeds the retired state-buffer budget"
	endif
Free_LegacyObjectState:		ds.b	$2B2-(object_ram_size-$2200)	; retain later RAM addresses after SST growth
Free_LegacyObjectState_end:
Object_Display_Lists:		ds.b	$400		; sprite display queue, in order of priority
Object_Display_Lists_End:
v_spritequeue:=		Object_Display_Lists
v_spritequeue_end:=	Object_Display_Lists_End

Sonic_Stat_Record_Buf:		ds.b	$100
Sonic_Stat_Record_Buf_End:
Sonic_Pos_Record_Buf:		ds.b	$100
Sonic_Pos_Record_Buf_End:
Tails_Pos_Record_Buf:		ds.b	$100
Tails_Pos_Record_Buf_End:
Ring_Positions:			ds.b	$600
Ring_Positions_End:

VDP_Command_Buffer:		ds.w	7*$12		; stores 18 ($12) VDP commands to issue the next time ProcessDMAQueue is called
VDP_Command_Buffer_Slot:	ds.w	1		; stores the address of the next open slot for a queued VDP command

Object_Respawn_Table:		ds.b	$300	; S3&K: one byte per placement (loaded bit + local state)
Object_Respawn_Table_end:
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

Camera_Y_pos_bias:		ds.w	1	; look-up/down bias; Camera_LookCenter is the default
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
Vscroll_Factor:
v_scrposy_vdp:		ds.w	1			; screen position y (VDP)
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
word_F700:		ds.w	1			; Tails' logical controller (held/pressed)
Tails_control_counter:	ds.w	1
Tails_respawn_counter:	ds.w	1
word_F706:		ds.w	1		; free; CPU object code lives in the tail SST
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
; Both speed banks have the same three-word layout, based at top_speed.
PlayerSpeed_AccelerationOffset:	equ Sonic_acceleration-Sonic_top_speed
PlayerSpeed_DecelerationOffset:	equ Sonic_deceleration-Sonic_top_speed
Sonic_LastLoadedDPLC:	ds.b	1
Tails_LastLoadedDPLC:		ds.b	1
TailsTails_LastLoadedDPLC:	ds.b	1
Primary_Angle:		ds.b	1
Secondary_Angle:	ds.b	1
Obj_placement_routine:	ds.b	1

Camera_X_pos_coarse:	ds.w	1			; last processed camera X, rounded down to $80
Camera_X_pos_coarse_End:
Camera_X_pos_last_P2:	ds.w	1
Camera_X_pos_last_P2_End:
Camera_X_pos_coarse_back:	ds.w	1			; (Camera_X_pos - $80) & $FF80, for object deletion
Camera_X_pos_coarse_back_End:
Camera_X_pos_coarse_P2:	ds.w	1
Camera_X_pos_coarse_P2_End:

Object_Manager_Addresses:
Object_load_addr_front:	ds.l	1			; first placement beyond the right loading edge
Object_load_addr_back:	ds.l	1			; first placement inside the left loading edge
Object_Manager_Addresses_End:

Object_Manager_Addresses_P2:
Obj_load_addr_right_P2:	ds.l	1
Obj_load_addr_left_P2:	ds.l	1
Object_Manager_Addresses_P2_End:

Demo_button_index:	ds.w	1			; index into button press demo data, for player 1
Demo_press_counter:	ds.b	1			; frames remaining until next button press, for player 1
Current_Timezone:	ds.b	1			; byte; Present (0), Past (1), Good Future (2), Bad Future (3); SCD swaps Past/Present
v_palchgspeed:
PalChangeSpeed:		ds.w	1
Collision_addr:		ds.l	1
v_colladdr1:		ds.l	1
v_colladdr2:		ds.l	1
v_palbs_num:		ds.w	1			; palette cycling in Bonus Stage - reference number
v_palbs_time:		ds.w	1			; palette cycling in Bonus Stage - time until next change
v_bsbganim:		ds.w	1			; bonus Stage background animation

v_gfxbigring:		ds.b	1			; settings for giant ring graphics loading
v_ssangleprev:		ds.b	1
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
v_palette_water_fading_line_2 =	palette_size+$20
v_palette_water_fading_line_3 =	palette_size+$40
v_palette_water_fading_line_4 =	palette_size+$60
v_palette_water_fading_end:

v_palette_water:	ds.b	palette_size		; main underwater palette
v_palette_water_line_2 =	palette_size+$20
v_palette_water_line_3 =	palette_size+$40
v_palette_water_line_4 =	palette_size+$60
v_palette_water_end:

v_palette:		ds.b	palette_size		; main palette
v_palette_line_2 =	palette_size+$20
v_palette_line_3 =	palette_size+$40
v_palette_line_4 =	palette_size+$60
v_palette_end:

v_palette_fading:	ds.b	palette_size		; duplicate palette, used for transitions
v_palette_fading_line_2 =	palette_size+$20
v_palette_fading_line_3 =	palette_size+$40
v_palette_fading_line_4 =	palette_size+$60
v_palette_fading_end:

v_crossresetram:					; RAM beyond this point is only cleared on a cold-boot
Level_Inactive_flag:	ds.w	1			; (2 bytes)
Level_frame_counter:	; For compatibility
v_framecount:		; For compatibility
Timer_frames:		ds.w	1			; the number of frames which have elapsed since the level started
Debug_object:		ds.b	1			; the current position in the debug mode object list
f_conveyrev:		ds.b	1			; unused
Debug_placement_mode =	*			; routine/type word; nonzero while either mode is active
Debug_placement_routine:	ds.b	1			; placement init/main (0/2)
Debug_placement_type:	ds.b	1			; DebugType_*
Debug_Accel_Timer:	ds.b	1			; (1 byte)
Debug_Speed:		ds.b	1			; (1 byte)
v_vbla_byte =		*				; see next line
Vint_runcount:		ds.l	1			; v_vbla_byte in Sonic 1; the number of times V-int has run

Player_mode		ds.w	1			; PlayerMode_*; Knuckles remains reserved
Player_option		ds.w	1			; option selected on level select, data select screen or Sonic & Knuckles title screen
Current_ZoneAndAct =	*
v_zone:			; For compatibility
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
			ds.b	3			; unused former global power-up flags
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
f_debugcheat:		ds.b	1			; debug mode cheat flag
			ds.b	1
Debug_mode_flag:	ds.b	1
v_megadrive:		ds.b	1			; Megadrive machine type
v_title_dcount:		ds.w	1			; number of times the d-pad is pressed on title screen
v_title_ccount:		ds.w	1			; number of times C is pressed on title screen

f_demo:			ds.w	1			; demo mode flag (0 = no; 1 = yes; $8001 = ending)
v_demonum:		ds.w	1			; demo level number (not the same as the level number)
v_creditsnum:		ds.w	1			; credits index number
Super_Sonic_frame_count:	ds.w	1
v_obj1F:		ds.b	6			; conveyor belt (Object 1F) variables
v_ani1_prev:		ds.b	1			; synchronised sprite animation 1 - previous frame
v_ani2_prev:		ds.b	1			; synchronised sprite animation 2 - previous frame
v_ani3_prev:		ds.b	1			; synchronised sprite animation 3 - previous frame

; S3&K object-manager additions fit in the existing tail padding.
Respawn_table_keep:	ds.b	1	; preserve placement state when reinitializing the same live layout
Camera_Y_pos_coarse:	ds.w	1	; last processed camera Y, rounded down to $80
Camera_Y_pos_coarse_back:	ds.w	1	; (Camera_Y_pos - $80) & $FF80
Object_respawn_index_front:	ds.w	1	; RAM address paired with Object_load_addr_front
Object_respawn_index_back:	ds.w	1	; RAM address paired with Object_load_addr_back
Object_load_retry:	ds.b	1	; an eligible placement could not get an SST this frame

			ds.b	$63			; free (99 bytes)
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


; S1 bonus stage: background chunks, rotating playfield and plane buffers
; all share the normal chunk table. The normal block table stays at v_16x16.
SSBG_Chunk_RAM_Size	= $A00
v_ssbuffer1		= Chunk_Table+SSBG_Chunk_RAM_Size
v_ssblockbuffer		= v_ssbuffer1+$1020		; $1020 bytes -- layout padded from the top and sides
v_ssblockbuffer_end	= v_ssblockbuffer+$80*$40	; ($2000 bytes)
v_ssbuffer2		= v_ssblockbuffer_end
v_ssblocktypes		= v_ssbuffer2
v_ssitembuffer		= v_ssbuffer2+$400		; animation list ($100 bytes)
v_ssitembuffer_end	= v_ssitembuffer+$100
v_ssbuffer3		= v_ssitembuffer+$500
v_ssscroll_buffer	= v_ssbuffer3+$400
v_ssangle		= v_ssscroll_buffer+$300
v_ssrotate		= v_ssangle+2
v_ssbg_fg_frame		= v_ssrotate+2		; frame prepared in RAM
v_ssbg_fg_uploaded	= v_ssbg_fg_frame+2	; frame displayed in VRAM
v_ssbg_bg_uploaded	= v_ssbg_fg_uploaded+2	; 0 = clouds, 1 = bubbles
v_ssbg_bg_wanted		= v_ssbg_bg_uploaded+2
v_ssbg_fg_build_row	= v_ssbg_bg_wanted+2	; next 16-pixel row to prepare
v_ssbg_bg_build_row	= v_ssbg_fg_build_row+2
v_ssbg_art_uploaded	= v_ssbg_bg_build_row+2	; animation 2,4,...12 in the shared tile bank
v_ssbg_anim_counter	= v_ssbg_art_uploaded+2	; private counter for Dynamic_Normal
v_ssbg_fg_buffer		= v_ssbg_anim_counter+2
v_ssbg_bg_buffer		= v_ssbg_fg_buffer+plane_size_64x32
v_ssbg_end		= v_ssbg_bg_buffer+plane_size_64x32

	if v_ssbg_end>Chunk_Table_End
		fatal "S1 special-stage RAM exceeds the chunk table."
	endif

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
				ds.b	v_objspace_end-object_size-*	; fill remaining slots; keep the final slot spare as before
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
	phase Error_Handler_Buffer
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
; ---------------------------------------------------------------------------
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
; ---------------------------------------------------------------------------
; Tile VRAM Locations

; Universal level sprites; zone/boss PLCs may replace inactive banks.
ArtTile_Spring_Diagonal:	equ $4D5	; 32 tiles
ArtTile_Spring_Vertical:	equ ArtTile_Spring_Diagonal+$20 ; 20 tiles
ArtTile_Spring_Horizontal:	equ ArtTile_Spring_Vertical+$14 ; 14 tiles (S2 uses 12)
ArtTile_Spikes:		equ ArtTile_Spring_Horizontal+$E ; side eight, then floor eight
ArtTile_Monitor:		equ ArtTile_Spikes+$10 ; 60 tiles
ArtTile_Lamppost:	equ ArtTile_Monitor+$3C ; 10 tiles; ends at $AD9F

; GHZ's packed objects/badniks, starting immediately after its 811 level tiles.
ArtTile_GHZ_Bridge:	equ $32B	; $6560
ArtTile_GHZ_MZ_Swing:	equ ArtTile_GHZ_Bridge+$A
ArtTile_GHZ_Giant_Ball:	equ ArtTile_GHZ_MZ_Swing+$E
ArtTile_GHZ_Purple_Rock:	equ ArtTile_GHZ_Giant_Ball+$26
ArtTile_Ground_Explosion:	equ ArtTile_GHZ_Purple_Rock+$18
ArtTile_Buzz_Bomber:	equ ArtTile_Ground_Explosion+$24
ArtTile_Crabmeat:	equ ArtTile_Buzz_Bomber+$37
ArtTile_Moto_Bug:	equ ArtTile_Crabmeat+$44
ArtTile_Ball_HogV:	equ ArtTile_Moto_Bug+$1D
ArtTile_Ball_HogH:	equ ArtTile_Ball_HogV+$18
ArtTile_Newtron:		equ ArtTile_Ball_HogH+$2F ; 81 tiles; four shared tail tiles below
ArtTile_Chopper:		equ ArtTile_Spring_Diagonal ; GHZ has no diagonal spring art
ArtTile_S1_Spring_Vertical:	equ ArtTile_Spring_Vertical ; 16 tiles; Newtron uses +$10-$13
ArtTile_S1_Spring_Horizontal:	equ ArtTile_Spring_Horizontal
ArtTile_Newtron_Tail:	equ ArtTile_S1_Spring_Vertical+$10
ArtTile_GHZ_Edge_Wall:	equ $6F7	; eight tiles in the HUD/points gap; cap uses level art


; Shared
ArtTile_MZ_SYZ_Caterkiller:	equ $3D0
ArtTile_GHZ_SLZ_Smashable_Wall:	equ $50F
ArtTile_Bumper:			equ $380

; Green Hill Zone
ArtTile_GHZ_Flower_4:		equ ArtTile_Level+$340
ArtTile_GHZ_Flower_Stalk:	equ ArtTile_Level+$358
ArtTile_GHZ_Big_Flower_1:	equ ArtTile_Level+$35C
ArtTile_GHZ_Small_Flower:	equ ArtTile_Level+$36C
ArtTile_GHZ_Waterfall:		equ ArtTile_Level+$378
ArtTile_GHZ_Flower_3:		equ ArtTile_Level+$380
ArtTile_GHZ_Big_Flower_2:	equ ArtTile_Level+$390
ArtTile_GHZ_Spike_Pole:		equ $398

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
ArtTile_LZ_Gargoyle:		equ $2E9
ArtTile_LZ_Water_Surface:	equ $300
ArtTile_LZ_Spikeball_Chain:	equ $310
ArtTile_LZ_Flapping_Door:	equ $328
ArtTile_Bubbles:		equ $45C	; S3&K resident bubbles, 56 tiles at $8B80
ArtTile_LZ_Moving_Block:	equ $3BC
ArtTile_LZ_Door:		equ $3C4
ArtTile_LZ_Harpoon:		equ $3CC
ArtTile_LZ_Pole:		equ $3DE
ArtTile_LZ_Push_Block:		equ $3DE
ArtTile_LZ_Blocks:		equ $3E6
ArtTile_LZ_Conveyor_Belt:	equ $3F6
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

; GHZ badniks and ground explosion continue the packed bank after its scenery.
; Universal springs, spikes, monitors and checkpoint follow in fixed slots.
; General Level Art
ArtTile_Level:			equ $000
ArtTile_Bomb:			equ $400


ArtTile_Yadrin:			equ $47B
ArtTile_Jaws:			equ $486
ArtTile_Burrobot:		equ $4A6
ArtTile_Basaran:		equ $385
ArtTile_Button:			equ $50F	; TO BE CHANGED
ArtTile_Shield:			equ $79C	; $F380; shared with primary invincibility
ArtTile_Shield_2:			equ $56E	; $ADC0; 18 tiles, clear of ground explosions and BBat
ArtTile_Shield_2_End:		equ ArtTile_Shield_2+$12 ; $B000; exclusive end of this bank
ArtTile_Invincibility:		equ ArtTile_Shield
ArtTile_Game_Over:		equ ArtTile_Shield ; replaces the dead primary player's effects, as in S3&K
ArtTile_Title_Card:		equ $580
; Shared explosion/fiery art first, then both animals, ending at Plane A.
ArtTile_Explosion:		equ $582	; $B040; 94 tiles, shared by both explosion mappings
ArtTile_Animal_1:		equ ArtTile_Explosion+$5E ; $5E0 / $BC00; 18 tiles
ArtTile_Animal_2:		equ ArtTile_Animal_1+$12 ; $5F2 / $BE40; 14 tiles, ending at $BFFF

ArtTile_Sonic:			equ $680
ArtTile_Tails:			equ $6A0
ArtTile_TailsTails:		equ $6B0	; stock S3&K shares this area with larger body frames
ArtTile_Ring:			equ $6B9	; $D720; Tails body/tail uploads stop at $6B7/$6B8
ArtTile_RingLoss:		equ ArtTile_Ring+4
ArtTile_Sparkles:		equ ArtTile_Ring+8
ArtTile_HUD:			equ ArtTile_Sparkles+4 ; $6C5 / $D8A0; contiguous with rings/sparkles
ArtTile_HUD_E:			equ ArtTile_HUD+$E	; SCORE shares TIME's static E
ArtTile_HUD_Debug_Numbers:	equ ArtTile_HUD+$10	; First two tiles are used only by debug coordinates
ArtTile_HUD_Numbers:		equ ArtTile_HUD_Debug_Numbers+2 ; 28 tiles for score, time and ring digits
ArtTile_Points:			equ $6F3	; $DE60; two tiles for the primary player's popup
ArtTile_Points_2:		equ ArtTile_Points+2 ; $6F5 / $DEA0; two tiles for the companion


ArtTile_Lives_Counter:		equ $7D4
ArtTile_Sonic_Dust:		equ $7E0
ArtTile_Tails_Dust:		equ $7F0
ArtTile_Water_Surface:		equ $400

; Eggman
ArtTile_Eggman:			equ $400
ArtTile_Eggman_Weapons:		equ $46C
ArtTile_Eggman_Button:		equ $4A4
ArtTile_Eggman_Spikeball:	equ $518
ArtTile_Eggman_Trap_Floor:	equ $518
ArtTile_Eggman_Exhaust:		equ ArtTile_Eggman_Weapons+$2A ; 17 tiles, after 42 weapon tiles

; End of Level
ArtTile_Giant_Ring:		equ $400
ArtTile_Giant_Ring_Flash:	equ $462
ArtTile_Prison_Capsule:		equ $508	; boss/capsule PLCs replace general level-object art
ArtTile_Hidden_Points:		equ $4B6
ArtTile_Warp:			equ $541
ArtTile_Mini_Tails:		equ $535
ArtTile_Mini_Sonic:		equ $551
ArtTile_Bonuses:		equ $570
ArtTile_Signpost:		equ ArtTile_Monitor	; replaces monitor art near the level exit

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
ArtTile_SS_Background_Transition:	equ $051
ArtTile_SS_Background_Animated:	equ ArtTile_SS_Background_Transition+9	; one 64-tile animation bank
ArtTile_SS_Wall:		equ ArtTile_SS_Background_Animated+64
ArtTile_SS_Bumper:		equ ArtTile_SS_Wall+16
ArtTile_SS_Goal:		equ ArtTile_SS_Bumper+36
ArtTile_SS_Up_Down:		equ ArtTile_SS_Goal+18
; Fixed stage art is contiguous now that it no longer lives between BG maps.
ArtTile_SS_R_Block:		equ ArtTile_SS_Up_Down+27
ArtTile_SS_Extra_Life:		equ ArtTile_SS_R_Block+9
ArtTile_SS_Emerald_Sparkle:	equ ArtTile_SS_Extra_Life+9
ArtTile_SS_Red_White_Block:	equ ArtTile_SS_Emerald_Sparkle+9
ArtTile_SS_Ghost_Block:		equ ArtTile_SS_Red_White_Block+9
ArtTile_SS_W_Block:		equ ArtTile_SS_Ghost_Block+9
ArtTile_SS_Glass:		equ ArtTile_SS_W_Block+9
ArtTile_SS_Emerald:		equ ArtTile_SS_Glass+9	; away from the live BG plane
ArtTile_SS_Rings:		equ $14A	; $2940; stage ring and palette-0 results copy
ArtTile_SS_Sparkles:		equ ArtTile_SS_Rings+4

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

; CPZ
ArtTile_MorphingOrbs:		equ $3C0

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
ArtTile_ArtNem_Eggpod_1:	equ $3A0
ArtTile_ArtNem_EHZBoss:		equ $400
ArtTile_ArtNem_EggChoppers:	equ $480
ArtTile_BossExplosion:	equ $580	; 100 tiles; replaced by animals/normal explosions after escape

; CPZ
ArtTile_CPZ_Platform:		equ $400

; HPZ
ArtTile_Splats:			equ ArtTile_Water_Surface+$18 ; 29 tiles, after 24 water tiles
ArtTile_BBat:			equ ArtTile_Bubbles+$38 ; 58 tiles after bubbles, below common level sprites

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
ArtTile_Rhinobot:		equ $3C4
ArtTile_Octus:			equ $38A
ArtTile_Redz:			equ $500
ArtTile_BFish:			equ $530
ArtTile_Aquis:			equ $570
ArtTile_Aquis_Child:		equ $4E0

; S1 Ending (leftover) (Original offsets temporarily overriden)
ArtTile_ArtNem_S1EndFlicky:	equ $580;$05A5
ArtTile_ArtNem_S1EndRabbit:	equ $592;$0553
ArtTile_ArtNem_S1EndPenguin:	equ $580;$0573
ArtTile_ArtNem_S1EndSeal:	equ $592;$0585
ArtTile_ArtNem_S1EndPig:	equ $580;$0593
ArtTile_ArtNem_S1EndChicken:	equ $592;$0565
ArtTile_ArtNem_S1EndSquirrel:	equ $580;$05B3
