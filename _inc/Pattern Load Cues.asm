; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
;
; Pattern load request lists are simple structures used to load
; Nemesis-compressed art for sprites.
;
; The decompressor predictably moves down the list, so request 0 is processed first, etc.
; This only matters if your addresses are bad and you overwrite art loaded in a previous request.
;

; NOTICE: The load queue buffer can only hold $10 (16) load requests. None of the routines
; that load PLRs into the queue do any bounds checking, so it's possible to create a buffer
; overflow and completely screw up the variables stored directly after the queue buffer.
; (in my experience this is a guaranteed crash or hang)
;
; Many levels queue more than 16 items overall, but they don't exceed the limit because
; their PLRs are split into multiple parts (like PLC_GHZ and PLC_GHZ2) and they fully
; process the first part before requesting the rest.
; ---------------------------------------------------------------------------

;----------------------------------------------------------------------------
; Table of pattern load request lists. Remember to use word-length data
; When adding lists. Otherwise you'll break the array.
;----------------------------------------------------------------------------
ArtLoadCues:

ptr_PLC_Main:		dc.w PLC_Main-ArtLoadCues
ptr_PLC_Main2:		dc.w PLC_Main2-ArtLoadCues
ptr_PLC_Explode:	dc.w PLC_Explode-ArtLoadCues
ptr_PLC_GameOver:	dc.w PLC_GameOver-ArtLoadCues
PLC_Levels:
ptr_PLC_GHZ:		dc.w PLC_GHZ-ArtLoadCues
ptr_PLC_GHZ2:		dc.w PLC_GHZ2-ArtLoadCues
ptr_PLC_LZ:		dc.w PLC_LZ-ArtLoadCues
ptr_PLC_LZ2:		dc.w PLC_LZ2-ArtLoadCues
ptr_PLC_CPZ:		dc.w PLC_CPZ-ArtLoadCues
ptr_PLC_CPZ2:		dc.w PLC_CPZ2-ArtLoadCues
ptr_PLC_EHZ:		dc.w PLC_EHZ-ArtLoadCues
ptr_PLC_EHZ2:		dc.w PLC_EHZ2-ArtLoadCues
ptr_PLC_HPZ:		dc.w PLC_HPZ-ArtLoadCues
ptr_PLC_HPZ2:		dc.w PLC_HPZ2-ArtLoadCues
ptr_PLC_HTZ:		dc.w PLC_HTZ-ArtLoadCues
ptr_PLC_HTZ2:		dc.w PLC_HTZ2-ArtLoadCues

ptr_PLC_TitleCard:	dc.w PLC_S1TitleCard-ArtLoadCues
ptr_PLC_Boss:		dc.w PLC_Boss-ArtLoadCues
ptr_PLC_Signpost:	dc.w PLC_Signpost-ArtLoadCues
ptr_PLC_Warp:		dc.w PLC_S1SpecialStage-ArtLoadCues
ptr_PLC_SpecialStage:	dc.w PLC_S1SpecialStage-ArtLoadCues
PLC_Animals:
ptr_PLC_GHZAnimals:	dc.w PLC_GHZAnimals-ArtLoadCues
ptr_PLC_LZAnimals:	dc.w PLC_LZAnimals-ArtLoadCues
ptr_PLC_CPZAnimals:	dc.w PLC_CPZAnimals-ArtLoadCues
ptr_PLC_EHZAnimals:	dc.w PLC_EHZAnimals-ArtLoadCues
ptr_PLC_HPZAnimals:	dc.w PLC_HPZAnimals-ArtLoadCues
ptr_PLC_HTZAnimals:	dc.w PLC_HTZAnimals-ArtLoadCues

ptr_PLC_SSResult:	dc.w PLC_SSResult-ArtLoadCues
ptr_PLC_Ending:		dc.w PLC_S1SpecialStage-ArtLoadCues
ptr_PLC_TryAgain:	dc.w PLC_S1SpecialStage-ArtLoadCues
ptr_PLC_EggmanSBZ2:	dc.w PLC_Boss-ArtLoadCues		; Placeholder
ptr_PLC_FZBoss:		dc.w PLC_Boss-ArtLoadCues		; Placeholder

plcm:	macro gfx,vram
	dc.l gfx
	dc.w (vram<<5)
	endm
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Standard 1 - loaded for every level
; ---------------------------------------------------------------------------
PLC_Main:	dc.w ((PLC_Main_End-PLC_Main)/6)-1
		plcm	Nem_HUD, ArtTile_HUD
		plcm	Nem_Lives, ArtTile_Lives_Counter
		plcm	Nem_Ring, ArtTile_Ring
PLC_Main_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Standard 2 - loaded for every level
; ---------------------------------------------------------------------------
PLC_Main2:	dc.w ((PLC_Main2_End-PLC_Main2)/6)-1
		plcm	Nem_Points, ArtTile_Points
		plcm	Nem_Lamppost, ArtTile_Lamppost
		plcm	Nem_Monitors, ArtTile_Monitor
		plcm	Nem_Shield, ArtTile_Shield
		plcm	Nem_Stars, ArtTile_Invincibility
PLC_Main2_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Explosion - loaded for every level AFTER the title card
; ---------------------------------------------------------------------------
PLC_Explode:	dc.w ((PLC_Explode_End-PLC_Explode)/6)-1
		plcm	Nem_Explosion, ArtTile_Explosion
PLC_Explode_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Game/Time over
; ---------------------------------------------------------------------------
PLC_GameOver:	dc.w ((PLC_GameOver_End-PLC_GameOver)/6)-1
		plcm	Nem_GameOver, ArtTile_Game_Over
PLC_GameOver_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Green Hill Zone primary
; ---------------------------------------------------------------------------
PLC_GHZ:	dc.w ((PLC_GHZ_End-PLC_GHZ)/6)-1
		plcm	Nem_GHZ_Bridge, ArtTile_GHZ_Bridge
		plcm	Nem_Swing, $4D0
		plcm	Nem_GHZ_Rock, ArtTile_GHZ_Purple_Rock
PLC_GHZ_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Green Hill Zone secondary
; ---------------------------------------------------------------------------
PLC_GHZ2:	dc.w ((PLC_GHZ2_End-PLC_GHZ2)/6)-1
		plcm	Nem_VSpikes, ArtTile_Spikes_GHZ
		plcm	Nem_HSpring, ArtTile_S1_Spring_Horizontal
		plcm	Nem_VSpring, ArtTile_S1_Spring_Vertical
PLC_GHZ2_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Labyrinth Zone primary
; ---------------------------------------------------------------------------
PLC_LZ:		dc.w ((PLC_CPZ_End-PLC_CPZ)/6)-1
		plcm	Nem_CPZ_FloatingPlatform, ArtTile_CPZ_Platform
PLC_LZ_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Labyrinth Zone secondary
; ---------------------------------------------------------------------------
PLC_LZ2:	dc.w ((PLC_CPZ2_End-PLC_CPZ2)/6)-1
		plcm	Nem_VSpikes, ArtTile_Spikes
		plcm	Nem_DSpring, ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2, ArtTile_Spring_Vertical
		plcm	Nem_HSpring2, ArtTile_Spring_Horizontal
PLC_LZ2_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Chemical Plant Zone primary
; ---------------------------------------------------------------------------
PLC_CPZ:	dc.w ((PLC_CPZ_End-PLC_CPZ)/6)-1
		plcm	Nem_CPZ_FloatingPlatform, ArtTile_CPZ_Platform
PLC_CPZ_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Chemical Plant Zone secondary
; ---------------------------------------------------------------------------
PLC_CPZ2:	dc.w ((PLC_CPZ2_End-PLC_CPZ2)/6)-1
		plcm	Nem_VSpikes, ArtTile_Spikes
		plcm	Nem_DSpring, ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2, ArtTile_Spring_Vertical
		plcm	Nem_HSpring2, ArtTile_Spring_Horizontal
PLC_CPZ2_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Emerald Hill Zone primary
; ---------------------------------------------------------------------------
PLC_EHZ:	dc.w ((PLC_EHZ_End-PLC_EHZ)/6)-1
		plcm	Nem_EHZ_Fireball, ArtTile_Fireball
		plcm	Nem_EHZ_Waterfall, ArtTile_Waterfall
		plcm	Nem_EHZ_Bridge, ArtTile_EHZ_Bridge
		plcm	Nem_HTZ_Seesaw, ArtTile_HTZ_Seesaw
		plcm	Nem_VSpikes, ArtTile_Spikes
		plcm	Nem_DSpring, ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2, ArtTile_Spring_Vertical
		plcm	Nem_HSpring2, ArtTile_Spring_Horizontal
PLC_EHZ_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Emerald Hill Zone secondary
; ---------------------------------------------------------------------------
PLC_EHZ2:	dc.w ((PLC_EHZ2_End-PLC_EHZ2)/6)-1
		plcm	Nem_Shield, ArtTile_EHZ_Shield
		plcm	Nem_Points, $4AC
		plcm	Nem_Buzzer, ArtTile_Buzzer
		plcm	Nem_Snail, ArtTile_Snail
		plcm	Nem_Masher, ArtTile_Masher
PLC_EHZ2_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Hidden Palace Zone primary
; ---------------------------------------------------------------------------
PLC_HPZ:	dc.w ((PLC_HPZ_End-PLC_HPZ)/6)-1
		plcm	Nem_HPZ_Bridge, ArtTile_HPZ_Bridge
		plcm	Nem_HPZ_Waterfall, ArtTile_HPZ_Waterfall
		plcm	Nem_HPZ_Platform, ArtTile_HPZ_Platform
		plcm	Nem_HPZ_PulsingBall, ArtTile_HPZ_Orb
		plcm	Nem_Water, ArtTile_Water_Surface
PLC_HPZ_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Hidden Palace Zone secondary
; ---------------------------------------------------------------------------
PLC_HPZ2:	dc.w ((PLC_HPZ2_End-PLC_HPZ2)/6)-1
		plcm	Nem_HPZ_Various, $37C
		plcm	Nem_HPZ_Emerald, ArtTile_HPZ_Emerald
PLC_HPZ2_End:
		; unused PLR entries
;		plcm	Nem_Gator, ArtTile_Gator
;		plcm	Nem_Stegway, ArtTile_Stegway
;		plcm	Nem_Redz, ArtTile_Redz
;		plcm	Nem_BFish, ArtTile_BFish
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Hill Top Zone primary
; ---------------------------------------------------------------------------
PLC_HTZ:	dc.w ((PLC_HTZ_End-PLC_HTZ)/6)-1
		plcm	Nem_HTZ_AniPlaceholders, ArtTile_HTZMountains
		plcm	Nem_EHZ_Fireball, ArtTile_Fireball
		plcm	Nem_HTZ_Fireball, ArtTile_HTZ_Fireball
		plcm	Nem_HTZ_AutomaticDoor, ArtTile_HTZ_AutomaticDoor
		plcm	Nem_EHZ_Bridge, ArtTile_EHZ_Bridge
		plcm	Nem_HTZ_Seesaw, ArtTile_HTZ_Seesaw
		plcm	Nem_VSpikes, ArtTile_Spikes
		plcm	Nem_DSpring, ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2, ArtTile_Spring_Vertical
		plcm	Nem_HSpring2, ArtTile_Spring_Horizontal
PLC_HTZ_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Hill Top Zone secondary
; ---------------------------------------------------------------------------
PLC_HTZ2:	dc.w ((PLC_HTZ2_End-PLC_HTZ2)/6)-1
		plcm	Nem_HTZ_Lift, ArtTile_HtzZipline
PLC_HTZ2_End:
		; unused PLR entries
;		plcm	Nem_Buzzer, ArtTile_Buzzer
;		plcm	Nem_Snail, ArtTile_Snail
;		plcm	Nem_Masher, ArtTile_Masher
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Sonic 1 title card
; ---------------------------------------------------------------------------
PLC_S1TitleCard:dc.w ((PLC_S1TitleCard_End-PLC_S1TitleCard)/6)-1
		plcm	Nem_TitleCard, ArtTile_Title_Card
PLC_S1TitleCard_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; End of zone bosses
; ---------------------------------------------------------------------------
PLC_Boss:	dc.w ((PLC_Boss_End-PLC_Boss)/6)-1
		plcm	Nem_EggPod, ArtTile_ArtNem_Eggpod_1
		plcm	Nem_EHZ_Boss, ArtTile_ArtNem_EHZBoss
		plcm	Nem_EggChopper, ArtTile_ArtNem_EggChoppers
PLC_Boss_End:
		; unused PLR entries
;		plcm	Nem_CPZ_Boss, $460
;		plcm	Nem_EggPodJets, $4D0
;		plcm	Nem_Smoke, $4D8
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; End of level signpost
; ---------------------------------------------------------------------------
PLC_Signpost:	dc.w ((PLC_Signpost_End-PLC_Signpost)/6)-1
		plcm	Nem_Signpost, ArtTile_Signpost
		plcm	Nem_Bonus, ArtTile_Hidden_Points
		plcm	Nem_BigFlash, ArtTile_Giant_Ring_Flash
PLC_Signpost_End:
; ---------------------------------------------------------------------------
; Pattern load cues - special stage
; ---------------------------------------------------------------------------
PLC_S1SpecialStage:
		dc.w ((PLC_S1SpecialStage_End-PLC_S1SpecialStage)/6)-1
		plcm	Nem_SSBgCloud,  ArtTile_SS_Background_Clouds	; bubble and cloud background
		plcm	Nem_SSBgFish,   ArtTile_SS_Background_Fish	; bird and fish background
		plcm	Nem_SSWalls,    ArtTile_SS_Wall			; walls
		plcm	Nem_Bumper,     ArtTile_SS_Bumper		; bumper
		plcm	Nem_SSGOAL,     ArtTile_SS_Goal			; GOAL block
		plcm	Nem_SSUpDown,   ArtTile_SS_Up_Down		; UP and DOWN blocks
		plcm	Nem_SSRBlock,   ArtTile_SS_R_Block		; R block
		plcm	Nem_SS1UpBlock, ArtTile_SS_Extra_Life		; 1UP block
		plcm	Nem_SSRings,    ArtTile_SS_Rings		; Rings
		plcm	Nem_SSEmStars,  ArtTile_SS_Emerald_Sparkle	; emerald collection stars
		plcm	Nem_SSRedWhite, ArtTile_SS_Red_White_Block	; red and white block
		plcm	Nem_SSGhost,    ArtTile_SS_Ghost_Block		; ghost block
		plcm	Nem_SSWBlock,   ArtTile_SS_W_Block		; W block
		plcm	Nem_SSGlass,    ArtTile_SS_Glass		; glass block
		plcm	Nem_SSEmerald,  ArtTile_SS_Emerald		; emeralds
PLC_S1SpecialStage_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Green Hill Zone animals
; ---------------------------------------------------------------------------
PLC_GHZAnimals:	dc.w ((PLC_GHZAnimals_End-PLC_GHZAnimals)/6)-1
		plcm	Nem_Bunny, ArtTile_Animal_1
		plcm	Nem_Flicky, ArtTile_Animal_2
PLC_GHZAnimals_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Labyrinth Zone animals
; ---------------------------------------------------------------------------
PLC_LZAnimals:	dc.w ((PLC_LZAnimals_End-PLC_LZAnimals)/6)-1
		plcm	Nem_Penguin, ArtTile_Animal_1
		plcm	Nem_Seal, ArtTile_Animal_2
PLC_LZAnimals_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Chemical Plant Zone animals
; ---------------------------------------------------------------------------
PLC_CPZAnimals:	dc.w ((PLC_CPZAnimals_End-PLC_CPZAnimals)/6)-1
		plcm	Nem_Squirrel, ArtTile_Animal_1
		plcm	Nem_Seal, ArtTile_Animal_2
PLC_CPZAnimals_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Emerald Hill Zone animals
; ---------------------------------------------------------------------------
PLC_EHZAnimals:	dc.w ((PLC_EHZAnimals_End-PLC_EHZAnimals)/6)-1
		plcm	Nem_Pig, ArtTile_Animal_1
		plcm	Nem_Flicky, ArtTile_Animal_2
PLC_EHZAnimals_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Hidden Palace Zone animals
; ---------------------------------------------------------------------------
PLC_HPZAnimals:	dc.w ((PLC_HPZAnimals_End-PLC_HPZAnimals)/6)-1
		plcm	Nem_Pig, ArtTile_Animal_1
		plcm	Nem_Chicken, ArtTile_Animal_2
PLC_HPZAnimals_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Hill Top Zone animals
; ---------------------------------------------------------------------------
PLC_HTZAnimals:	dc.w ((PLC_HTZAnimals_End-PLC_HTZAnimals)/6)-1
		plcm	Nem_Bunny, ArtTile_Animal_1
		plcm	Nem_Chicken, ArtTile_Animal_2
PLC_HTZAnimals_End:
; ---------------------------------------------------------------------------
; Pattern load cues - special stage results screen
; ---------------------------------------------------------------------------
PLC_SSResult:dc.w ((PLC_SpeStResultend-PLC_SSResult-2)/6)-1
		plcm	Nem_ResultEm, ArtTile_SS_Results_Emeralds	; emeralds
		plcm	Nem_MiniSonic, ArtTile_Mini_Sonic		; mini Sonic
PLC_SpeStResultend:

; ---------------------------------------------------------------------------
; Pattern load cue IDs
; ---------------------------------------------------------------------------
plcid_Main:		equ (ptr_PLC_Main-ArtLoadCues)/2	; 0
plcid_Main2:		equ (ptr_PLC_Main2-ArtLoadCues)/2	; 1
plcid_Explode:		equ (ptr_PLC_Explode-ArtLoadCues)/2	; 2
plcid_GameOver:		equ (ptr_PLC_GameOver-ArtLoadCues)/2	; 3
plcid_GHZ:		equ (ptr_PLC_GHZ-ArtLoadCues)/2		; 4
plcid_GHZ2:		equ (ptr_PLC_GHZ2-ArtLoadCues)/2	; 5
plcid_LZ:		equ (ptr_PLC_LZ-ArtLoadCues)/2		; 6
plcid_LZ2:		equ (ptr_PLC_LZ2-ArtLoadCues)/2		; 7
plcid_CPZ:		equ (ptr_PLC_CPZ-ArtLoadCues)/2		; 8
plcid_CPZ2:		equ (ptr_PLC_CPZ2-ArtLoadCues)/2	; 9
plcid_EHZ:		equ (ptr_PLC_EHZ-ArtLoadCues)/2		; $A
plcid_EHZ2:		equ (ptr_PLC_EHZ2-ArtLoadCues)/2	; $B
plcid_HPZ:		equ (ptr_PLC_HPZ-ArtLoadCues)/2		; $C
plcid_HPZ2:		equ (ptr_PLC_HPZ2-ArtLoadCues)/2	; $D
plcid_HTZ:		equ (ptr_PLC_HTZ-ArtLoadCues)/2		; $E
plcid_HTZ2:		equ (ptr_PLC_HTZ2-ArtLoadCues)/2	; $F
plcid_TitleCard:	equ (ptr_PLC_TitleCard-ArtLoadCues)/2	; $10
plcid_Boss:		equ (ptr_PLC_Boss-ArtLoadCues)/2	; $11
plcid_Signpost:		equ (ptr_PLC_Signpost-ArtLoadCues)/2	; $12
plcid_Warp:		equ (ptr_PLC_Warp-ArtLoadCues)/2	; $13
plcid_SpecialStage:	equ (ptr_PLC_SpecialStage-ArtLoadCues)/2; $14
plcid_GHZAnimals:	equ (ptr_PLC_GHZAnimals-ArtLoadCues)/2	; $15
plcid_LZAnimals:	equ (ptr_PLC_LZAnimals-ArtLoadCues)/2	; $16
plcid_CPZAnimals:	equ (ptr_PLC_CPZAnimals-ArtLoadCues)/2	; $17
plcid_EHZAnimals:	equ (ptr_PLC_EHZAnimals-ArtLoadCues)/2	; $18
plcid_HPZAnimals:	equ (ptr_PLC_HPZAnimals-ArtLoadCues)/2	; $19
plcid_HTZAnimals:	equ (ptr_PLC_HTZAnimals-ArtLoadCues)/2	; $1A
plcid_SSResult:		equ (ptr_PLC_SSResult-ArtLoadCues)/2	; $1B
plcid_Ending:		equ (ptr_PLC_Ending-ArtLoadCues)/2	; $1C
plcid_TryAgain:		equ (ptr_PLC_TryAgain-ArtLoadCues)/2	; $1D
plcid_EggmanSBZ2:	equ (ptr_PLC_EggmanSBZ2-ArtLoadCues)/2	; $1E
plcid_FZBoss:		equ (ptr_PLC_FZBoss-ArtLoadCues)/2	; $1F
; ---------------------------------------------------------------------------
KosMLoadCues:
; Green Hill Zone
ptr_KPLC_GHZ1:	dc.w PLCKosM_GHZ1-KosMLoadCues  ; $00 Act 1
ptr_KPLC_GHZ2:	dc.w PLCKosM_GHZ2-KosMLoadCues  ; $00 Act 2
ptr_KPLC_GHZ3:	dc.w PLCKosM_GHZ3-KosMLoadCues  ; $00 Act 3
ptr_KPLC_GHZ4:	dc.w PLCKosM_GHZ4-KosMLoadCues  ; $00 Act 4
; ---------------------------------------------------------------------------
; Rustic Ruins Zone  [WILL BE REPLACED] [LZ]
ptr_KPLC_RRZ1:	dc.w PLCKosM_Null-KosMLoadCues ; $01 Act 1
ptr_KPLC_RRZ2:	dc.w PLCKosM_Null-KosMLoadCues ; $01 Act 2
ptr_KPLC_RRZ3:	dc.w PLCKosM_Null-KosMLoadCues ; $01 Act 3
ptr_KPLC_RRZ4:	dc.w PLCKosM_Null-KosMLoadCues ; $01 Act 4
; ---------------------------------------------------------------------------
; Ancient Factory Zone [TO BE REMIXED] [CPZ]
ptr_KPLC_AFZ1:	dc.w PLCKosM_Null-KosMLoadCues ; $02 Act 1
ptr_KPLC_AFZ2:	dc.w PLCKosM_Null-KosMLoadCues ; $02 Act 2
ptr_KPLC_AFZ3:	dc.w PLCKosM_Null-KosMLoadCues ; $02 Act 3
ptr_KPLC_AFZ4:	dc.w PLCKosM_Null-KosMLoadCues ; $02 Act 4
; ---------------------------------------------------------------------------
; Emerald Hill Zone
ptr_KPLC_EHZ1:	dc.w PLCKosM_Null-KosMLoadCues ; $03 Act 1
ptr_KPLC_EHZ2:	dc.w PLCKosM_Null-KosMLoadCues ; $03 Act 2
ptr_KPLC_EHZ3:	dc.w PLCKosM_Null-KosMLoadCues ; $03 Act 3
ptr_KPLC_EHZ4:	dc.w PLCKosM_Null-KosMLoadCues ; $03 Act 4
; ---------------------------------------------------------------------------
; Crystal Valley Zone [WILL BE REPLACED] [HPZ]
ptr_KPLC_CVZ1:	dc.w PLCKosM_HPZ1-KosMLoadCues  ; $04 Act 1
ptr_KPLC_CVZ2:	dc.w PLCKosM_HPZ2-KosMLoadCues  ; $04 Act 2
ptr_KPLC_CVZ3:	dc.w PLCKosM_HPZ3-KosMLoadCues  ; $04 Act 3
ptr_KPLC_CVZ4:	dc.w PLCKosM_HPZ4-KosMLoadCues  ; $04 Act 4
; ---------------------------------------------------------------------------
; Egg Mountain Zone [TO BE REMIXED] [HTZ]
ptr_KPLC_EMZ1:	dc.w PLCKosM_Null-KosMLoadCues ; $05 Act 1
ptr_KPLC_EMZ2:	dc.w PLCKosM_Null-KosMLoadCues ; $05 Act 2
ptr_KPLC_EMZ3:	dc.w PLCKosM_Null-KosMLoadCues ; $05 Act 3
ptr_KPLC_EMZ4:	dc.w PLCKosM_Null-KosMLoadCues ; $05 Act 4
; ---------------------------------------------------------------------------
; Metropolis Zone [TO BE ADDED]
ptr_KPLC_MZ1:	dc.w PLCKosM_Null-KosMLoadCues ; $06 Act 1
ptr_KPLC_MZ2:	dc.w PLCKosM_Null-KosMLoadCues ; $06 Act 2
ptr_KPLC_MZ3:	dc.w PLCKosM_Null-KosMLoadCues ; $06 Act 3
ptr_KPLC_MZ4:	dc.w PLCKosM_Null-KosMLoadCues ; $06 Act 4
; ---------------------------------------------------------------------------
; Scrap Madness Zone [TO BE ADDED]
ptr_KPLC_SMZ1:	dc.w PLCKosM_Null-KosMLoadCues ; $07 Act 1
ptr_KPLC_SMZ2:	dc.w PLCKosM_Null-KosMLoadCues ; $07 Act 2
ptr_KPLC_SMZ3:	dc.w PLCKosM_Null-KosMLoadCues ; $07 Act 3
ptr_KPLC_SMZ4:	dc.w PLCKosM_Null-KosMLoadCues ; $07 Act 4
; ---------------------------------------------------------------------------
; Death Egg Zone [TO BE ADDED]
ptr_KPLC_DEZ1:	dc.w PLCKosM_Null-KosMLoadCues ; $08 Act 1
ptr_KPLC_DEZ2:	dc.w PLCKosM_Null-KosMLoadCues ; $08 Act 2
ptr_KPLC_DEZ3:	dc.w PLCKosM_Null-KosMLoadCues ; $08 Act 3
ptr_KPLC_DEZ4:	dc.w PLCKosM_Null-KosMLoadCues ; $08 Act 4
; ---------------------------------------------------------------------------
; Shocking Blizzard Zone [TO BE ADDED]
ptr_KPLC_SBZ1:	dc.w PLCKosM_Null-KosMLoadCues ; $09 Act 1
ptr_KPLC_SBZ2:	dc.w PLCKosM_Null-KosMLoadCues ; $09 Act 2
ptr_KPLC_SBZ3:	dc.w PLCKosM_Null-KosMLoadCues ; $09 Act 3
ptr_KPLC_SBZ4:	dc.w PLCKosM_Null-KosMLoadCues ; $09 Act 4
; ---------------------------------------------------------------------------
; Level Slot $A
ptr_KPLC_L0AZ1:	dc.w PLCKosM_Null-KosMLoadCues ; $0A Act 1
ptr_KPLC_L0AZ2:	dc.w PLCKosM_Null-KosMLoadCues ; $0A Act 2
ptr_KPLC_L0AZ3:	dc.w PLCKosM_Null-KosMLoadCues ; $0A Act 3
ptr_KPLC_L0AZ4:	dc.w PLCKosM_Null-KosMLoadCues ; $0A Act 4
; ---------------------------------------------------------------------------
; Level Slot $B
ptr_KPLC_L0BZ1:	dc.w PLCKosM_Null-KosMLoadCues ; $0B Act 1
ptr_KPLC_L0BZ2:	dc.w PLCKosM_Null-KosMLoadCues ; $0B Act 2
ptr_KPLC_L0BZ3:	dc.w PLCKosM_Null-KosMLoadCues ; $0B Act 3
ptr_KPLC_L0BZ4:	dc.w PLCKosM_Null-KosMLoadCues ; $0B Act 4
; ---------------------------------------------------------------------------
; Level Slot $C
ptr_KPLC_L0CZ1:	dc.w PLCKosM_Null-KosMLoadCues ; $0C Act 1
ptr_KPLC_L0CZ2:	dc.w PLCKosM_Null-KosMLoadCues ; $0C Act 2
ptr_KPLC_L0CZ3:	dc.w PLCKosM_Null-KosMLoadCues ; $0C Act 3
ptr_KPLC_L0CZ4:	dc.w PLCKosM_Null-KosMLoadCues ; $0C Act 4
; ---------------------------------------------------------------------------
; Level Slot $D
ptr_KPLC_L0DZ1:	dc.w PLCKosM_Null-KosMLoadCues ; $0D Act 1
ptr_KPLC_L0DZ2:	dc.w PLCKosM_Null-KosMLoadCues ; $0D Act 2
ptr_KPLC_L0DZ3:	dc.w PLCKosM_Null-KosMLoadCues ; $0D Act 3
ptr_KPLC_L0DZ4:	dc.w PLCKosM_Null-KosMLoadCues ; $0D Act 4
; ---------------------------------------------------------------------------
; Level Slot $E
ptr_KPLC_L0EZ1:	dc.w PLCKosM_Null-KosMLoadCues ; $0E Act 1
ptr_KPLC_L0EZ2:	dc.w PLCKosM_Null-KosMLoadCues ; $0E Act 2
ptr_KPLC_L0EZ3:	dc.w PLCKosM_Null-KosMLoadCues ; $0E Act 3
ptr_KPLC_L0EZ4:	dc.w PLCKosM_Null-KosMLoadCues ; $0E Act 4
; ---------------------------------------------------------------------------
; Level Slot $F
ptr_KPLC_L0FZ1:	dc.w PLCKosM_Null-KosMLoadCues ; $0F Act 1
ptr_KPLC_L0FZ2:	dc.w PLCKosM_Null-KosMLoadCues ; $0F Act 2
ptr_KPLC_L0FZ3:	dc.w PLCKosM_Null-KosMLoadCues ; $0F Act 3
ptr_KPLC_L0FZ4:	dc.w PLCKosM_Null-KosMLoadCues ; $0F Act 4
; ---------------------------------------------------------------------------
; Level Slot $10
ptr_KPLC_L10Z1:	dc.w PLCKosM_Null-KosMLoadCues ; $10 Act 1
ptr_KPLC_L10Z2:	dc.w PLCKosM_Null-KosMLoadCues ; $10 Act 2
ptr_KPLC_L10Z3:	dc.w PLCKosM_Null-KosMLoadCues ; $10 Act 3
ptr_KPLC_L10Z4:	dc.w PLCKosM_Null-KosMLoadCues ; $10 Act 4
; ---------------------------------------------------------------------------
; Misc. PLC's [May change. Names here are potential entries]
; Note: the ptr names here are temporary.
ptr_KPLC_1:	dc.w PLCKosM_Null-KosMLoadCues ; Cutscene assets
ptr_KPLC_2:	dc.w PLCKosM_Null-KosMLoadCues ; Giant Ring
ptr_KPLC_3:	dc.w PLCKosM_Null-KosMLoadCues ; Boss 1
ptr_KPLC_4:	dc.w PLCKosM_Null-KosMLoadCues ; Boss 2
ptr_KPLC_5:	dc.w PLCKosM_Null-KosMLoadCues ; Boss 3
ptr_KPLC_6:	dc.w PLCKosM_Null-KosMLoadCues ; Boss 4
ptr_KPLC_7:	dc.w PLCKosM_Null-KosMLoadCues ; Level transition patchers
ptr_KPLC_8:	dc.w PLCKosM_Null-KosMLoadCues ; Level transition patchers
ptr_KPLC_9:	dc.w PLCKosM_Null-KosMLoadCues ; Level transition patchers
ptr_KPLC_10:	dc.w PLCKosM_Null-KosMLoadCues ; Level transition patchers
ptr_KPLC_11:	dc.w PLCKosM_Null-KosMLoadCues ; Level transition patchers
ptr_KPLC_12:	dc.w PLCKosM_Null-KosMLoadCues ; Level transition patchers
; ---------------------------------------------------------------------------
; macro for a pattern load request list header
; must be on the same line as a label that has a corresponding _End label later
plrKosMlistheader macro {INTLABEL}
__LABEL__ label *
	dc.w (((__LABEL___End - __LABEL__Plc) / 6) - 1)
__LABEL__Plc:
    endm

; macro for a pattern load request
plreqKosM macro toVRAMaddr,fromROMaddr
	dc.l	fromROMaddr
	dc.w	tiles_to_bytes(toVRAMaddr)
    endm


PLCKosM_Null:	plrKosMlistheader
	dc.w	$FFFF
PLCKosM_Null_End

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; Green Hill Zone
; ---------------------------------------------------------------------------
; Act 1
PLCKosM_GHZ1:	plrKosMlistheader
		plreqKosM	ArtTile_Buzz_Bomber, Kospm_Buzz
		plreqKosM	ArtTile_Crabmeat, Kospm_Crabmeat
		plreqKosM	ArtTile_Chopper, Kospm_Chopper
		plreqKosM	ArtTile_Moto_Bug, Kospm_Motobug
		plreqKosM	ArtTile_Newtron, Kospm_Newtron
PLCKosM_GHZ1_End
; ---------------------------------------------------------------------------
; Act 2
PLCKosM_GHZ2:	plrKosMlistheader
		plreqKosM	ArtTile_Buzz_Bomber, Kospm_Buzz
		plreqKosM	ArtTile_Crabmeat, Kospm_Crabmeat
		plreqKosM	ArtTile_Chopper, Kospm_Chopper
		plreqKosM	ArtTile_Moto_Bug, Kospm_Motobug
		plreqKosM	ArtTile_Newtron, Kospm_Newtron
PLCKosM_GHZ2_End
; ---------------------------------------------------------------------------
; Act 3
PLCKosM_GHZ3:	plrKosMlistheader
		plreqKosM	ArtTile_Buzz_Bomber, Kospm_Buzz
		plreqKosM	ArtTile_Crabmeat, Kospm_Crabmeat
		plreqKosM	ArtTile_Chopper, Kospm_Chopper
		plreqKosM	ArtTile_Moto_Bug, Kospm_Motobug
		plreqKosM	ArtTile_Newtron, Kospm_Newtron
PLCKosM_GHZ3_End
; ---------------------------------------------------------------------------
; Act 4
PLCKosM_GHZ4:	plrKosMlistheader
		plreqKosM	ArtTile_Buzz_Bomber, Kospm_Buzz
		plreqKosM	ArtTile_Crabmeat, Kospm_Crabmeat
		plreqKosM	ArtTile_Chopper, Kospm_Chopper
		plreqKosM	ArtTile_Moto_Bug, Kospm_Motobug
		plreqKosM	ArtTile_Newtron, Kospm_Newtron
PLCKosM_GHZ4_End
; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV01 Zone
; ---------------------------------------------------------------------------
; Act 1

; ---------------------------------------------------------------------------
; Act 2

; ---------------------------------------------------------------------------
; Act 3

; ---------------------------------------------------------------------------
; Act 4

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; Chemical Plant Zone
; ---------------------------------------------------------------------------
; Act 1

; ---------------------------------------------------------------------------
; Act 2

; ---------------------------------------------------------------------------
; Act 3

; ---------------------------------------------------------------------------
; Act 4

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; Emerald Hill Zone
; ---------------------------------------------------------------------------
; Act 1

; ---------------------------------------------------------------------------
; Act 2

; ---------------------------------------------------------------------------
; Act 3

; ---------------------------------------------------------------------------
; Act 4

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; Hidden Palace Zone
; ---------------------------------------------------------------------------
; Act 1
PLCKosM_HPZ1:	plrKosMlistheader
		plreqKosM	ArtTile_Redz, Kospm_Redz
		plreqKosM	ArtTile_BBat, Kospm_BBat
PLCKosM_HPZ1_End
; ---------------------------------------------------------------------------
; Act 2
PLCKosM_HPZ2:	plrKosMlistheader
		plreqKosM	ArtTile_Redz, Kospm_Redz
		plreqKosM	ArtTile_BBat, Kospm_BBat
PLCKosM_HPZ2_End
; ---------------------------------------------------------------------------
; Act 3
PLCKosM_HPZ3:	plrKosMlistheader
		plreqKosM	ArtTile_Redz, Kospm_Redz
		plreqKosM	ArtTile_BBat, Kospm_BBat
PLCKosM_HPZ3_End
; ---------------------------------------------------------------------------
; Act 4
PLCKosM_HPZ4:	plrKosMlistheader
		plreqKosM	ArtTile_Redz, Kospm_Redz
		plreqKosM	ArtTile_BBat, Kospm_BBat
PLCKosM_HPZ4_End

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; Hill top Zone
; ---------------------------------------------------------------------------
; Act 1

; ---------------------------------------------------------------------------
; Act 2

; ---------------------------------------------------------------------------
; Act 3

; ---------------------------------------------------------------------------
; Act 4

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV06 Zone
; ---------------------------------------------------------------------------
; Act 1

; ---------------------------------------------------------------------------
; Act 2

; ---------------------------------------------------------------------------
; Act 3

; ---------------------------------------------------------------------------
; Act 4

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV07 Zone
; ---------------------------------------------------------------------------
; Act 1

; ---------------------------------------------------------------------------
; Act 2

; ---------------------------------------------------------------------------
; Act 3

; ---------------------------------------------------------------------------
; Act 4

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV08 Zone
; ---------------------------------------------------------------------------
; Act 1

; ---------------------------------------------------------------------------
; Act 2

; ---------------------------------------------------------------------------
; Act 3

; ---------------------------------------------------------------------------
; Act 4

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV09 Zone
; ---------------------------------------------------------------------------
; Act 1

; ---------------------------------------------------------------------------
; Act 2

; ---------------------------------------------------------------------------
; Act 3

; ---------------------------------------------------------------------------
; Act 4

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV0A Zone
; ---------------------------------------------------------------------------
; Act 1

; ---------------------------------------------------------------------------
; Act 2

; ---------------------------------------------------------------------------
; Act 3

; ---------------------------------------------------------------------------
; Act 4

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV0B Zone
; ---------------------------------------------------------------------------
; Act 1

; ---------------------------------------------------------------------------
; Act 2

; ---------------------------------------------------------------------------
; Act 3

; ---------------------------------------------------------------------------
; Act 4

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV0C Zone
; ---------------------------------------------------------------------------
; Act 1

; ---------------------------------------------------------------------------
; Act 2

; ---------------------------------------------------------------------------
; Act 3

; ---------------------------------------------------------------------------
; Act 4

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV0D Zone
; ---------------------------------------------------------------------------
; Act 1

; ---------------------------------------------------------------------------
; Act 2

; ---------------------------------------------------------------------------
; Act 3

; ---------------------------------------------------------------------------
; Act 4

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV0E Zone
; ---------------------------------------------------------------------------
; Act 1

; ---------------------------------------------------------------------------
; Act 2

; ---------------------------------------------------------------------------
; Act 3

; ---------------------------------------------------------------------------
; Act 4

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV0F Zone
; ---------------------------------------------------------------------------
; Act 1

; ---------------------------------------------------------------------------
; Act 2

; ---------------------------------------------------------------------------
; Act 3

; ---------------------------------------------------------------------------
; Act 4

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV10 Zone
; ---------------------------------------------------------------------------
; Act 1

; ---------------------------------------------------------------------------
; Act 2

; ---------------------------------------------------------------------------
; Act 3

; ---------------------------------------------------------------------------
; Act 4

; ---------------------------------------------------------------------------
; MISC PATTERN LOAD REQUEST LIST
;
; ---------------------------------------------------------------------------
; 1

; ---------------------------------------------------------------------------
; 2

; ---------------------------------------------------------------------------
; 3

; ---------------------------------------------------------------------------
; 4

; ---------------------------------------------------------------------------
; 5

; ---------------------------------------------------------------------------
; 6

; ---------------------------------------------------------------------------
; 7

; ---------------------------------------------------------------------------
; 8

; ---------------------------------------------------------------------------
; 9

; ---------------------------------------------------------------------------
; 10

; ---------------------------------------------------------------------------
; 11

; ---------------------------------------------------------------------------
; 12

; ---------------------------------------------------------------------------
; Moduled Kosinski Pattern IDs
; ---------------------------------------------------------------------------
mkplcid_GHZ1:		equ (ptr_KPLC_GHZ1-KosMLoadCues)/2		; 0
mkplcid_GHZ2:		equ (ptr_KPLC_GHZ2-KosMLoadCues)/2		; 1
mkplcid_GHZ3:		equ (ptr_KPLC_GHZ3-KosMLoadCues)/2		; 2
mkplcid_GHZ4:		equ (ptr_KPLC_GHZ4-KosMLoadCues)/2		; 3

mkplcid_RRZ1:		equ (ptr_KPLC_RRZ1-KosMLoadCues)/2		; 4
mkplcid_RRZ2:		equ (ptr_KPLC_RRZ2-KosMLoadCues)/2		; 5
mkplcid_RRZ3:		equ (ptr_KPLC_RRZ3-KosMLoadCues)/2		; 6
mkplcid_RRZ4:		equ (ptr_KPLC_RRZ4-KosMLoadCues)/2		; 7

mkplcid_AFZ1:		equ (ptr_KPLC_AFZ1-KosMLoadCues)/2		; 8
mkplcid_AFZ2:		equ (ptr_KPLC_AFZ2-KosMLoadCues)/2		; 9
mkplcid_AFZ3:		equ (ptr_KPLC_AFZ3-KosMLoadCues)/2		; $A
mkplcid_AFZ4:		equ (ptr_KPLC_AFZ4-KosMLoadCues)/2		; $B

mkplcid_EHZ1:		equ (ptr_KPLC_EHZ1-KosMLoadCues)/2		; $C
mkplcid_EHZ2:		equ (ptr_KPLC_EHZ2-KosMLoadCues)/2		; $D
mkplcid_EHZ3:		equ (ptr_KPLC_EHZ3-KosMLoadCues)/2		; $E
mkplcid_EHZ4:		equ (ptr_KPLC_EHZ4-KosMLoadCues)/2		; $F

mkplcid_CVZ1:		equ (ptr_KPLC_CVZ1-KosMLoadCues)/2		; $10
mkplcid_CVZ2:		equ (ptr_KPLC_CVZ2-KosMLoadCues)/2		; $11
mkplcid_CVZ3:		equ (ptr_KPLC_CVZ3-KosMLoadCues)/2		; $12
mkplcid_CVZ4:		equ (ptr_KPLC_CVZ4-KosMLoadCues)/2		; $13

mkplcid_EMZ1:		equ (ptr_KPLC_EMZ1-KosMLoadCues)/2		; $14
mkplcid_EMZ2:		equ (ptr_KPLC_EMZ2-KosMLoadCues)/2		; $15
mkplcid_EMZ3:		equ (ptr_KPLC_EMZ3-KosMLoadCues)/2		; $16
mkplcid_EMZ4:		equ (ptr_KPLC_EMZ4-KosMLoadCues)/2		; $17

mkplcid_MZ1:		equ (ptr_KPLC_MZ1-KosMLoadCues)/2		; $18
mkplcid_MZ2:		equ (ptr_KPLC_MZ2-KosMLoadCues)/2		; $19
mkplcid_MZ3:		equ (ptr_KPLC_MZ3-KosMLoadCues)/2		; $1A
mkplcid_MZ4:		equ (ptr_KPLC_MZ4-KosMLoadCues)/2		; $1B

mkplcid_SMZ1:		equ (ptr_KPLC_SMZ1-KosMLoadCues)/2		; $1C
mkplcid_SMZ2:		equ (ptr_KPLC_SMZ2-KosMLoadCues)/2		; $1D
mkplcid_SMZ3:		equ (ptr_KPLC_SMZ3-KosMLoadCues)/2		; $1E
mkplcid_SMZ4:		equ (ptr_KPLC_SMZ4-KosMLoadCues)/2		; $1F

mkplcid_DEZ1:		equ (ptr_KPLC_DEZ1-KosMLoadCues)/2		; $20
mkplcid_DEZ2:		equ (ptr_KPLC_DEZ2-KosMLoadCues)/2		; $21
mkplcid_DEZ3:		equ (ptr_KPLC_DEZ3-KosMLoadCues)/2		; $22
mkplcid_DEZ4:		equ (ptr_KPLC_DEZ4-KosMLoadCues)/2		; $23
; From here on out, unused level slots
mkplcid_L0AZ1:		equ (ptr_KPLC_L0AZ1-KosMLoadCues)/2		; $24
mkplcid_L0AZ2:		equ (ptr_KPLC_L0AZ2-KosMLoadCues)/2		; $25
mkplcid_L0AZ3:		equ (ptr_KPLC_L0AZ3-KosMLoadCues)/2		; $26
mkplcid_L0AZ4:		equ (ptr_KPLC_L0AZ4-KosMLoadCues)/2		; $27

mkplcid_L0BZ1:		equ (ptr_KPLC_L0BZ1-KosMLoadCues)/2		; $28
mkplcid_L0BZ2:		equ (ptr_KPLC_L0BZ2-KosMLoadCues)/2		; $29
mkplcid_L0BZ3:		equ (ptr_KPLC_L0BZ3-KosMLoadCues)/2		; $2A
mkplcid_L0BZ4:		equ (ptr_KPLC_L0BZ4-KosMLoadCues)/2		; $2B

mkplcid_L0CZ1:		equ (ptr_KPLC_L0CZ1-KosMLoadCues)/2		; $2C
mkplcid_L0CZ2:		equ (ptr_KPLC_L0CZ2-KosMLoadCues)/2		; $2D
mkplcid_L0CZ3:		equ (ptr_KPLC_L0CZ3-KosMLoadCues)/2		; $2E
mkplcid_L0CZ4:		equ (ptr_KPLC_L0CZ4-KosMLoadCues)/2		; $2F

mkplcid_L0DZ1:		equ (ptr_KPLC_L0DZ1-KosMLoadCues)/2		; $30
mkplcid_L0DZ2:		equ (ptr_KPLC_L0DZ2-KosMLoadCues)/2		; $31
mkplcid_L0DZ3:		equ (ptr_KPLC_L0DZ3-KosMLoadCues)/2		; $32
mkplcid_L0DZ4:		equ (ptr_KPLC_L0DZ4-KosMLoadCues)/2		; $33

mkplcid_L0EZ1:		equ (ptr_KPLC_L0EZ1-KosMLoadCues)/2		; $34
mkplcid_L0EZ2:		equ (ptr_KPLC_L0EZ2-KosMLoadCues)/2		; $35
mkplcid_L0EZ3:		equ (ptr_KPLC_L0EZ3-KosMLoadCues)/2		; $36
mkplcid_L0EZ4:		equ (ptr_KPLC_L0EZ4-KosMLoadCues)/2		; $37

mkplcid_L0FZ1:		equ (ptr_KPLC_L0FZ1-KosMLoadCues)/2		; $38
mkplcid_L0FZ2:		equ (ptr_KPLC_L0FZ2-KosMLoadCues)/2		; $39
mkplcid_L0FZ3:		equ (ptr_KPLC_L0FZ3-KosMLoadCues)/2		; $3A
mkplcid_L0FZ4:		equ (ptr_KPLC_L0FZ4-KosMLoadCues)/2		; $3B

mkplcid_L10Z1:		equ (ptr_KPLC_L10Z1-KosMLoadCues)/2		; $3C
mkplcid_L10Z2:		equ (ptr_KPLC_L10Z2-KosMLoadCues)/2		; $3D
mkplcid_L10Z3:		equ (ptr_KPLC_L10Z3-KosMLoadCues)/2		; $3E
mkplcid_L10Z4:		equ (ptr_KPLC_L10Z4-KosMLoadCues)/2		; $3F
; end of unused level slots
mkplcid_Misc1:		equ (ptr_KPLC_1-KosMLoadCues)/2			; $40
mkplcid_Misc2:		equ (ptr_KPLC_2-KosMLoadCues)/2			; $41
mkplcid_Misc3:		equ (ptr_KPLC_3-KosMLoadCues)/2			; $42
mkplcid_Misc4:		equ (ptr_KPLC_4-KosMLoadCues)/2			; $43
mkplcid_Misc5:		equ (ptr_KPLC_5-KosMLoadCues)/2			; $44
mkplcid_Misc6:		equ (ptr_KPLC_6-KosMLoadCues)/2			; $45
mkplcid_Misc7:		equ (ptr_KPLC_7-KosMLoadCues)/2			; $46
mkplcid_Misc8:		equ (ptr_KPLC_8-KosMLoadCues)/2			; $47
mkplcid_Misc9:		equ (ptr_KPLC_9-KosMLoadCues)/2			; $48
mkplcid_Misc10:		equ (ptr_KPLC_10-KosMLoadCues)/2		; $49
mkplcid_Misc11:		equ (ptr_KPLC_11-KosMLoadCues)/2		; $4A
mkplcid_Misc12:		equ (ptr_KPLC_12-KosMLoadCues)/2		; $4B