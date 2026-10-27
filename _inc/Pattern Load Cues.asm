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
; their PLRs are split into multiple parts (like PLC_GHZ1_Main and PLC_GHZ1_Extra) and they fully
; process the first part before requesting the rest.
; ---------------------------------------------------------------------------
plcm:	macro gfx,vram
	dc.l gfx
	dc.w (vram<<5)
	endm
; Check a completed list against the 16-request queue. Main act lists share
; it with the common art and the larger character-life list.
plccheck:	macro list,reserved
	if (*-list-2)/6+reserved>$10
		fatal "PLC and shared art exceed the 16-entry request queue"
	endif
	endm
; ---------------------------------------------------------------------------
; Table of pattern load request lists. Remember to use word-length data
; When adding lists. Otherwise you'll break the array.
; ---------------------------------------------------------------------------

ArtLoadCues:
ptr_PLC_Main:		dc.w PLC_Main-ArtLoadCues
ptr_PLC_Main2:		dc.w PLC_Main2-ArtLoadCues
ptr_PLC_Explode:	dc.w PLC_Explode-ArtLoadCues
ptr_PLC_GameOver:	dc.w PLC_GameOver-ArtLoadCues
ptr_PLC_TitleCard:	dc.w PLC_S1TitleCard-ArtLoadCues
ptr_PLC_Boss:		dc.w PLC_Boss-ArtLoadCues
ptr_PLC_Signpost:	dc.w PLC_Signpost-ArtLoadCues
ptr_PLC_Warp:		dc.w PLC_S1SpecialStage-ArtLoadCues
ptr_PLC_SpecialStage:	dc.w PLC_S1SpecialStage-ArtLoadCues
ptr_PLC_GHZAnimals:	dc.w PLC_GHZAnimals-ArtLoadCues
ptr_PLC_LZAnimals:	dc.w PLC_LZAnimals-ArtLoadCues
ptr_PLC_CPZAnimals:	dc.w PLC_CPZAnimals-ArtLoadCues
ptr_PLC_EHZAnimals:	dc.w PLC_EHZAnimals-ArtLoadCues
ptr_PLC_HPZAnimals:	dc.w PLC_HPZAnimals-ArtLoadCues
ptr_PLC_HTZAnimals:	dc.w PLC_HTZAnimals-ArtLoadCues
ptr_PLC_SSResult:	dc.w PLC_SSResult-ArtLoadCues
ptr_PLC_Ending:		dc.w PLC_S1SpecialStage-ArtLoadCues
ptr_PLC_TryAgain:	dc.w PLC_S1SpecialStage-ArtLoadCues
ptr_PLC_EggmanSBZ2:	dc.w PLC_Boss-ArtLoadCues
ptr_PLC_FZBoss:		dc.w PLC_Boss-ArtLoadCues
ptr_PLC_Capsule:	dc.w PLC_Capsule-ArtLoadCues
ptr_PLC_GHZBoss:	dc.w PLC_GHZBoss-ArtLoadCues
ptr_PLC_LivesSonic:	dc.w PLC_LivesSonic-ArtLoadCues
ptr_PLC_LivesTails:	dc.w PLC_LivesTails-ArtLoadCues
ptr_PLC_ExplosionWall:	dc.w PLC_ExplosionWall-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $00: Twilight Hill
ActLoadCues:
ptr_PLC_GHZ1_Main:	dc.w PLC_GHZ1_Main-ArtLoadCues
ptr_PLC_GHZ1_Extra:	dc.w PLC_GHZ1_Extra-ArtLoadCues
ptr_PLC_GHZ2_Main:	dc.w PLC_GHZ2_Main-ArtLoadCues
ptr_PLC_GHZ2_Extra:	dc.w PLC_GHZ2_Extra-ArtLoadCues
ptr_PLC_GHZ3_Main:	dc.w PLC_GHZ3_Main-ArtLoadCues
ptr_PLC_GHZ3_Extra:	dc.w PLC_GHZ3_Extra-ArtLoadCues
ptr_PLC_GHZ4_Main:	dc.w PLC_GHZ4_Main-ArtLoadCues
ptr_PLC_GHZ4_Extra:	dc.w PLC_GHZ4_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $01: Rustic Ruins
ptr_PLC_LZ1_Main:	dc.w PLC_LZ1_Main-ArtLoadCues
ptr_PLC_LZ1_Extra:	dc.w PLC_LZ1_Extra-ArtLoadCues
ptr_PLC_LZ2_Main:	dc.w PLC_LZ2_Main-ArtLoadCues
ptr_PLC_LZ2_Extra:	dc.w PLC_LZ2_Extra-ArtLoadCues
ptr_PLC_LZ3_Main:	dc.w PLC_LZ3_Main-ArtLoadCues
ptr_PLC_LZ3_Extra:	dc.w PLC_LZ3_Extra-ArtLoadCues
ptr_PLC_LZ4_Main:	dc.w PLC_LZ4_Main-ArtLoadCues
ptr_PLC_LZ4_Extra:	dc.w PLC_LZ4_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $02: Ancient Workbench
ptr_PLC_CPZ1_Main:	dc.w PLC_CPZ1_Main-ArtLoadCues
ptr_PLC_CPZ1_Extra:	dc.w PLC_CPZ1_Extra-ArtLoadCues
ptr_PLC_CPZ2_Main:	dc.w PLC_CPZ2_Main-ArtLoadCues
ptr_PLC_CPZ2_Extra:	dc.w PLC_CPZ2_Extra-ArtLoadCues
ptr_PLC_CPZ3_Main:	dc.w PLC_CPZ3_Main-ArtLoadCues
ptr_PLC_CPZ3_Extra:	dc.w PLC_CPZ3_Extra-ArtLoadCues
ptr_PLC_CPZ4_Main:	dc.w PLC_CPZ4_Main-ArtLoadCues
ptr_PLC_CPZ4_Extra:	dc.w PLC_CPZ4_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $03: Emerald Hill
ptr_PLC_EHZ1_Main:	dc.w PLC_EHZ1_Main-ArtLoadCues
ptr_PLC_EHZ1_Extra:	dc.w PLC_EHZ1_Extra-ArtLoadCues
ptr_PLC_EHZ2_Main:	dc.w PLC_EHZ2_Main-ArtLoadCues
ptr_PLC_EHZ2_Extra:	dc.w PLC_EHZ2_Extra-ArtLoadCues
ptr_PLC_EHZ3_Main:	dc.w PLC_EHZ3_Main-ArtLoadCues
ptr_PLC_EHZ3_Extra:	dc.w PLC_EHZ3_Extra-ArtLoadCues
ptr_PLC_EHZ4_Main:	dc.w PLC_EHZ4_Main-ArtLoadCues
ptr_PLC_EHZ4_Extra:	dc.w PLC_EHZ4_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $04: Crystal Valley
ptr_PLC_HPZ1_Main:	dc.w PLC_HPZ1_Main-ArtLoadCues
ptr_PLC_HPZ1_Extra:	dc.w PLC_HPZ1_Extra-ArtLoadCues
ptr_PLC_HPZ2_Main:	dc.w PLC_HPZ2_Main-ArtLoadCues
ptr_PLC_HPZ2_Extra:	dc.w PLC_HPZ2_Extra-ArtLoadCues
ptr_PLC_HPZ3_Main:	dc.w PLC_HPZ3_Main-ArtLoadCues
ptr_PLC_HPZ3_Extra:	dc.w PLC_HPZ3_Extra-ArtLoadCues
ptr_PLC_HPZ4_Main:	dc.w PLC_HPZ4_Main-ArtLoadCues
ptr_PLC_HPZ4_Extra:	dc.w PLC_HPZ4_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $05: Egg Mountain
ptr_PLC_HTZ1_Main:	dc.w PLC_HTZ1_Main-ArtLoadCues
ptr_PLC_HTZ1_Extra:	dc.w PLC_HTZ1_Extra-ArtLoadCues
ptr_PLC_HTZ2_Main:	dc.w PLC_HTZ2_Main-ArtLoadCues
ptr_PLC_HTZ2_Extra:	dc.w PLC_HTZ2_Extra-ArtLoadCues
ptr_PLC_HTZ3_Main:	dc.w PLC_HTZ3_Main-ArtLoadCues
ptr_PLC_HTZ3_Extra:	dc.w PLC_HTZ3_Extra-ArtLoadCues
ptr_PLC_HTZ4_Main:	dc.w PLC_HTZ4_Main-ArtLoadCues
ptr_PLC_HTZ4_Extra:	dc.w PLC_HTZ4_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $06: Metropolis
ptr_PLC_LV61_Main:	dc.w PLC_LV61_Main-ArtLoadCues
ptr_PLC_LV61_Extra:	dc.w PLC_LV61_Extra-ArtLoadCues
ptr_PLC_LV62_Main:	dc.w PLC_LV62_Main-ArtLoadCues
ptr_PLC_LV62_Extra:	dc.w PLC_LV62_Extra-ArtLoadCues
ptr_PLC_LV63_Main:	dc.w PLC_LV63_Main-ArtLoadCues
ptr_PLC_LV63_Extra:	dc.w PLC_LV63_Extra-ArtLoadCues
ptr_PLC_LV64_Main:	dc.w PLC_LV64_Main-ArtLoadCues
ptr_PLC_LV64_Extra:	dc.w PLC_LV64_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $07: Shocking Blizzard
ptr_PLC_LV71_Main:	dc.w PLC_LV71_Main-ArtLoadCues
ptr_PLC_LV71_Extra:	dc.w PLC_LV71_Extra-ArtLoadCues
ptr_PLC_LV72_Main:	dc.w PLC_LV72_Main-ArtLoadCues
ptr_PLC_LV72_Extra:	dc.w PLC_LV72_Extra-ArtLoadCues
ptr_PLC_LV73_Main:	dc.w PLC_LV73_Main-ArtLoadCues
ptr_PLC_LV73_Extra:	dc.w PLC_LV73_Extra-ArtLoadCues
ptr_PLC_LV74_Main:	dc.w PLC_LV74_Main-ArtLoadCues
ptr_PLC_LV74_Extra:	dc.w PLC_LV74_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $08: Scrap Madness
ptr_PLC_SMZ1_Main:	dc.w PLC_SMZ1_Main-ArtLoadCues
ptr_PLC_SMZ1_Extra:	dc.w PLC_SMZ1_Extra-ArtLoadCues
ptr_PLC_SMZ2_Main:	dc.w PLC_SMZ2_Main-ArtLoadCues
ptr_PLC_SMZ2_Extra:	dc.w PLC_SMZ2_Extra-ArtLoadCues
ptr_PLC_SMZ3_Main:	dc.w PLC_SMZ3_Main-ArtLoadCues
ptr_PLC_SMZ3_Extra:	dc.w PLC_SMZ3_Extra-ArtLoadCues
ptr_PLC_SMZ4_Main:	dc.w PLC_SMZ4_Main-ArtLoadCues
ptr_PLC_SMZ4_Extra:	dc.w PLC_SMZ4_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $09: Death Egg
ptr_PLC_LV91_Main:	dc.w PLC_LV91_Main-ArtLoadCues
ptr_PLC_LV91_Extra:	dc.w PLC_LV91_Extra-ArtLoadCues
ptr_PLC_LV92_Main:	dc.w PLC_LV92_Main-ArtLoadCues
ptr_PLC_LV92_Extra:	dc.w PLC_LV92_Extra-ArtLoadCues
ptr_PLC_LV93_Main:	dc.w PLC_LV93_Main-ArtLoadCues
ptr_PLC_LV93_Extra:	dc.w PLC_LV93_Extra-ArtLoadCues
ptr_PLC_LV94_Main:	dc.w PLC_LV94_Main-ArtLoadCues
ptr_PLC_LV94_Extra:	dc.w PLC_LV94_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $0A: Level 0A
ptr_PLC_PP1_Main:	dc.w PLC_PP1_Main-ArtLoadCues
ptr_PLC_PP1_Extra:	dc.w PLC_PP1_Extra-ArtLoadCues
ptr_PLC_PP2_Main:	dc.w PLC_PP2_Main-ArtLoadCues
ptr_PLC_PP2_Extra:	dc.w PLC_PP2_Extra-ArtLoadCues
ptr_PLC_PP3_Main:	dc.w PLC_PP3_Main-ArtLoadCues
ptr_PLC_PP3_Extra:	dc.w PLC_PP3_Extra-ArtLoadCues
ptr_PLC_PP4_Main:	dc.w PLC_PP4_Main-ArtLoadCues
ptr_PLC_PP4_Extra:	dc.w PLC_PP4_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $0B: Level 0B
ptr_PLC_LVB1_Main:	dc.w PLC_LVB1_Main-ArtLoadCues
ptr_PLC_LVB1_Extra:	dc.w PLC_LVB1_Extra-ArtLoadCues
ptr_PLC_LVB2_Main:	dc.w PLC_LVB2_Main-ArtLoadCues
ptr_PLC_LVB2_Extra:	dc.w PLC_LVB2_Extra-ArtLoadCues
ptr_PLC_LVB3_Main:	dc.w PLC_LVB3_Main-ArtLoadCues
ptr_PLC_LVB3_Extra:	dc.w PLC_LVB3_Extra-ArtLoadCues
ptr_PLC_LVB4_Main:	dc.w PLC_LVB4_Main-ArtLoadCues
ptr_PLC_LVB4_Extra:	dc.w PLC_LVB4_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $0C: Level 0C
ptr_PLC_LVC1_Main:	dc.w PLC_LVC1_Main-ArtLoadCues
ptr_PLC_LVC1_Extra:	dc.w PLC_LVC1_Extra-ArtLoadCues
ptr_PLC_LVC2_Main:	dc.w PLC_LVC2_Main-ArtLoadCues
ptr_PLC_LVC2_Extra:	dc.w PLC_LVC2_Extra-ArtLoadCues
ptr_PLC_LVC3_Main:	dc.w PLC_LVC3_Main-ArtLoadCues
ptr_PLC_LVC3_Extra:	dc.w PLC_LVC3_Extra-ArtLoadCues
ptr_PLC_LVC4_Main:	dc.w PLC_LVC4_Main-ArtLoadCues
ptr_PLC_LVC4_Extra:	dc.w PLC_LVC4_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $0D: Level 0D
ptr_PLC_LVD1_Main:	dc.w PLC_LVD1_Main-ArtLoadCues
ptr_PLC_LVD1_Extra:	dc.w PLC_LVD1_Extra-ArtLoadCues
ptr_PLC_LVD2_Main:	dc.w PLC_LVD2_Main-ArtLoadCues
ptr_PLC_LVD2_Extra:	dc.w PLC_LVD2_Extra-ArtLoadCues
ptr_PLC_LVD3_Main:	dc.w PLC_LVD3_Main-ArtLoadCues
ptr_PLC_LVD3_Extra:	dc.w PLC_LVD3_Extra-ArtLoadCues
ptr_PLC_LVD4_Main:	dc.w PLC_LVD4_Main-ArtLoadCues
ptr_PLC_LVD4_Extra:	dc.w PLC_LVD4_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $0E: Level 0E
ptr_PLC_LVE1_Main:	dc.w PLC_LVE1_Main-ArtLoadCues
ptr_PLC_LVE1_Extra:	dc.w PLC_LVE1_Extra-ArtLoadCues
ptr_PLC_LVE2_Main:	dc.w PLC_LVE2_Main-ArtLoadCues
ptr_PLC_LVE2_Extra:	dc.w PLC_LVE2_Extra-ArtLoadCues
ptr_PLC_LVE3_Main:	dc.w PLC_LVE3_Main-ArtLoadCues
ptr_PLC_LVE3_Extra:	dc.w PLC_LVE3_Extra-ArtLoadCues
ptr_PLC_LVE4_Main:	dc.w PLC_LVE4_Main-ArtLoadCues
ptr_PLC_LVE4_Extra:	dc.w PLC_LVE4_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
; Level slot $0F: Level 0F
ptr_PLC_LVF1_Main:	dc.w PLC_LVF1_Main-ArtLoadCues
ptr_PLC_LVF1_Extra:	dc.w PLC_LVF1_Extra-ArtLoadCues
ptr_PLC_LVF2_Main:	dc.w PLC_LVF2_Main-ArtLoadCues
ptr_PLC_LVF2_Extra:	dc.w PLC_LVF2_Extra-ArtLoadCues
ptr_PLC_LVF3_Main:	dc.w PLC_LVF3_Main-ArtLoadCues
ptr_PLC_LVF3_Extra:	dc.w PLC_LVF3_Extra-ArtLoadCues
ptr_PLC_LVF4_Main:	dc.w PLC_LVF4_Main-ArtLoadCues
ptr_PLC_LVF4_Extra:	dc.w PLC_LVF4_Extra-ArtLoadCues
; ---------------------------------------------------------------------------
ArtLoadCues_End:
		if ArtLoadCues_End-ActLoadCues<>LevelActCount*4
			fatal "Act PLC index must contain Main and Extra for every act"
		endif
		if (ArtLoadCues_End-ArtLoadCues)/2>$100
			fatal "PLC IDs no longer fit level-header bytes"
		endif
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Standard 1 - loaded for every level
; ---------------------------------------------------------------------------
PLC_Main:	dc.w ((PLC_Main_End-PLC_Main)/6)-1
		plcm	Nem_HUD,	ArtTile_HUD
		plcm	Nem_Sparkles,	ArtTile_Sparkles
PLC_Main_End:
; Character selection happens on level select, after the shared HUD PLC.
PLC_LivesSonic:	dc.w 0
		plcm	Nem_Lives,	ArtTile_Lives_Counter
PLC_LivesSonic_End:
PLC_LivesTails:	dc.w 1
		plcm	Nem_Lives,	ArtTile_Lives_Counter
		plcm	Nem_TailsLifeText,(ArtTile_Lives_Counter+4)
PLC_LivesTails_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Standard 2 - loaded for every level
; ---------------------------------------------------------------------------
PLC_Main2:	dc.w ((PLC_Main2_End-PLC_Main2)/6)-1
		plcm	Nem_Lamppost,	ArtTile_Lamppost
		plcm	Nem_Monitors,	ArtTile_Monitor
		plcm	Nem_VSpikes,	ArtTile_Spikes
PLC_Main2_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Explosion - loaded for every level AFTER the title card
; ---------------------------------------------------------------------------
PLC_Explode:	dc.w ((PLC_Explode_End-PLC_Explode)/6)-1
		plcm	Nem_Explosion,	ArtTile_Explosion
PLC_Explode_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Game/Time over
; ---------------------------------------------------------------------------
PLC_GameOver:	dc.w ((PLC_GameOver_End-PLC_GameOver)/6)-1
		plcm	Nem_GameOver,	ArtTile_Game_Over
PLC_GameOver_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Sonic 1 title card
; ---------------------------------------------------------------------------
; NewPLC still clears pending level PLCs; the results object queues its DPLC.
PLC_S1TitleCard:dc.w -1
PLC_S1TitleCard_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; End of zone bosses
; ---------------------------------------------------------------------------
PLC_Boss:	dc.w ((PLC_Boss_End-PLC_Boss)/6)-1
		plcm	Nem_EggPod,	ArtTile_ArtNem_Eggpod_1
		plcm	Nem_EHZ_Boss,	ArtTile_ArtNem_EHZBoss
		plcm	Nem_EggChopper,	ArtTile_ArtNem_EggChoppers
		plcm	Nem_BossExplosion,	ArtTile_BossExplosion
PLC_Boss_End:
; GHZ retains its S1 boss mappings; its ball and chain are already resident.
PLC_GHZBoss:	dc.w ((PLC_GHZBoss_End-PLC_GHZBoss)/6)-1
		plcm	Nem_OldEggPod,	ArtTile_Eggman
		plcm	Nem_Weapons,	ArtTile_Eggman_Weapons
		plcm	Nem_Exhaust,	ArtTile_Eggman_Exhaust
		plcm	Nem_Prison,	ArtTile_Prison_Capsule
		plcm	Nem_BossExplosion,	ArtTile_BossExplosion
PLC_GHZBoss_End:
; Capsule art can coexist with the boss during its defeat/escape sequence.
PLC_Capsule:	dc.w ((PLC_Capsule_End-PLC_Capsule)/6)-1
		plcm	Nem_Prison,	ArtTile_Prison_Capsule
PLC_Capsule_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Advancing explosion wall - both sizes must coexist; replaces inactive ship art
; ---------------------------------------------------------------------------
PLC_ExplosionWall:	dc.w (PLC_ExplosionWall_End-PLC_ExplosionWall-2)/6-1
		plcm	Nem_BossExplosion,	ArtTile_BossExplosion
		plcm	Nem_Explosion,	ArtTile_ExplosionWall_Small
PLC_ExplosionWall_End:	plccheck PLC_ExplosionWall,0
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; End of level signpost
; ---------------------------------------------------------------------------
PLC_Signpost:	dc.w ((PLC_Signpost_End-PLC_Signpost)/6)-1
		plcm	Nem_Bonus,	ArtTile_Hidden_Points
PLC_Signpost_End:
; ---------------------------------------------------------------------------
; Pattern load cues - special stage
; ---------------------------------------------------------------------------
PLC_S1SpecialStage:
		dc.w ((PLC_S1SpecialStage_End-PLC_S1SpecialStage)/6)-1
		plcm	Nem_Bumper,	ArtTile_SS_Bumper		; bumper
		plcm	Nem_SSGOAL,	ArtTile_SS_Goal			; GOAL block
		plcm	Nem_SSRBlock,	ArtTile_SS_R_Block		; R block
		plcm	Nem_Sparkles,	ArtTile_SS_Sparkles		; Ring sparkle
		plcm	Nem_SSEmStars,	ArtTile_SS_Emerald_Sparkle	; emerald collection stars
		plcm	Nem_SSRedWhite,	ArtTile_SS_Red_White_Block	; red and white block
		plcm	Nem_SSWBlock,	ArtTile_SS_W_Block		; W block
		plcm	Nem_SSGlass,	ArtTile_SS_Glass		; glass block
		plcm	Nem_SSEmerald,	ArtTile_SS_Emerald		; emeralds
PLC_S1SpecialStage_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Green Hill Zone animals
; ---------------------------------------------------------------------------
PLC_GHZAnimals:	dc.w ((PLC_GHZAnimals_End-PLC_GHZAnimals)/6)-1
		plcm	Nem_Bunny,	ArtTile_Animal_1
		plcm	Nem_Flicky,	ArtTile_Animal_2
PLC_GHZAnimals_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Labyrinth Zone animals
; ---------------------------------------------------------------------------
PLC_LZAnimals:	dc.w ((PLC_LZAnimals_End-PLC_LZAnimals)/6)-1
		plcm	Nem_Penguin,	ArtTile_Animal_1
		plcm	Nem_Seal,	ArtTile_Animal_2
PLC_LZAnimals_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Chemical Plant Zone animals
; ---------------------------------------------------------------------------
PLC_CPZAnimals:	dc.w ((PLC_CPZAnimals_End-PLC_CPZAnimals)/6)-1
		plcm	Nem_Squirrel,	ArtTile_Animal_1
		plcm	Nem_Seal,	ArtTile_Animal_2
PLC_CPZAnimals_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Emerald Hill Zone animals
; ---------------------------------------------------------------------------
PLC_EHZAnimals:	dc.w ((PLC_EHZAnimals_End-PLC_EHZAnimals)/6)-1
		plcm	Nem_Pig,	ArtTile_Animal_1
		plcm	Nem_Flicky,	ArtTile_Animal_2
PLC_EHZAnimals_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Hidden Palace Zone animals
; ---------------------------------------------------------------------------
PLC_HPZAnimals:	dc.w ((PLC_HPZAnimals_End-PLC_HPZAnimals)/6)-1
		plcm	Nem_Pig,	ArtTile_Animal_1
		plcm	Nem_Chicken,	ArtTile_Animal_2
PLC_HPZAnimals_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Hill Top Zone animals
; ---------------------------------------------------------------------------
PLC_HTZAnimals:	dc.w ((PLC_HTZAnimals_End-PLC_HTZAnimals)/6)-1
		plcm	Nem_Bunny,	ArtTile_Animal_1
		plcm	Nem_Chicken,	ArtTile_Animal_2
PLC_HTZAnimals_End:
; ---------------------------------------------------------------------------
; Pattern load cues - special stage results screen
; ---------------------------------------------------------------------------
PLC_SSResult:dc.w ((PLC_SpeStResult_End-PLC_SSResult-2)/6)-1
		plcm	Nem_ResultEm,	ArtTile_SS_Results_Emeralds	; emeralds
PLC_SpeStResult_End:
; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LIST
; Swinging ball boss
; ---------------------------------------------------------------------------
;PLC_Filler:	dc.w ((PLC_Filler_End-PLC_Filler-2)/6)-1
;		plcm	Nem_VSpikes,	ArtTile_Spikes
;PLC_Filler_End:

; ---------------------------------------------------------------------------
; Act lists: Main loads during the title card, Extra after terrain.
; Every act has its own entries; edit its plcm lines directly.
; ---------------------------------------------------------------------------
ActPLC_Main_Reserve equ (PLC_Main2_End-PLC_Main2-2)/6+(PLC_LivesTails_End-PLC_LivesTails-2)/6

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Twilight Hill - Act 1
; ---------------------------------------------------------------------------
PLC_GHZ1_Main:		dc.w (PLC_GHZ1_Main_End-PLC_GHZ1_Main-2)/6-1
		plcm	Nem_GHZ_Bridge,	ArtTile_GHZ_Bridge
		plcm	Nem_Swing,	ArtTile_GHZ_MZ_Swing
		plcm	Nem_GHZ_Ball,	ArtTile_GHZ_Giant_Ball ; giant ball
		plcm	Nem_GHZ_Rock,	ArtTile_GHZ_Purple_Rock
;		plcm	Nem_GroundExplosion,	ArtTile_Ground_Explosion ; Ballhog test effect
PLC_GHZ1_Main_End:	plccheck PLC_GHZ1_Main,ActPLC_Main_Reserve

PLC_GHZ1_Extra:		dc.w (PLC_GHZ1_Extra_End-PLC_GHZ1_Extra-2)/6-1
		plcm	Nem_HSpring2,	ArtTile_S1_Spring_Horizontal
		plcm	Nem_VSpring2,	ArtTile_S1_Spring_Vertical
		plcm	Nem_GHZ_BWall,	ArtTile_GHZ_SLZ_Smashable_Wall
		plcm	Nem_GHZ_SWall,	ArtTile_GHZ_Edge_Wall
PLC_GHZ1_Extra_End:	plccheck PLC_GHZ1_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Twilight Hill - Act 2
; ---------------------------------------------------------------------------
PLC_GHZ2_Main:		dc.w (PLC_GHZ2_Main_End-PLC_GHZ2_Main-2)/6-1
		plcm	Nem_GHZ_Bridge,	ArtTile_GHZ_Bridge
		plcm	Nem_Swing,	ArtTile_GHZ_MZ_Swing
		plcm	Nem_GHZ_Ball,	ArtTile_GHZ_Giant_Ball ; giant ball
		plcm	Nem_GHZ_Rock,	ArtTile_GHZ_Purple_Rock
		plcm	Nem_GroundExplosion,	ArtTile_Ground_Explosion
PLC_GHZ2_Main_End:	plccheck PLC_GHZ2_Main,ActPLC_Main_Reserve

PLC_GHZ2_Extra:		dc.w (PLC_GHZ2_Extra_End-PLC_GHZ2_Extra-2)/6-1
		plcm	Nem_HSpring2,	ArtTile_S1_Spring_Horizontal
		plcm	Nem_VSpring2,	ArtTile_S1_Spring_Vertical
		plcm	Nem_GHZ_BWall,	ArtTile_GHZ_SLZ_Smashable_Wall
		plcm	Nem_GHZ_SWall,	ArtTile_GHZ_Edge_Wall
PLC_GHZ2_Extra_End:	plccheck PLC_GHZ2_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Twilight Hill - Act 3
; ---------------------------------------------------------------------------
PLC_GHZ3_Main:		dc.w (PLC_GHZ3_Main_End-PLC_GHZ3_Main-2)/6-1
		plcm	Nem_GHZ_Bridge,	ArtTile_GHZ_Bridge
		plcm	Nem_Swing,	ArtTile_GHZ_MZ_Swing
		plcm	Nem_GHZ_Ball,	ArtTile_GHZ_Giant_Ball ; giant ball
		plcm	Nem_GHZ_Rock,	ArtTile_GHZ_Purple_Rock
		plcm	Nem_GroundExplosion,	ArtTile_Ground_Explosion
PLC_GHZ3_Main_End:	plccheck PLC_GHZ3_Main,ActPLC_Main_Reserve

PLC_GHZ3_Extra:		dc.w (PLC_GHZ3_Extra_End-PLC_GHZ3_Extra-2)/6-1
		plcm	Nem_HSpring2,	ArtTile_S1_Spring_Horizontal
		plcm	Nem_VSpring2,	ArtTile_S1_Spring_Vertical
		plcm	Nem_GHZ_BWall,	ArtTile_GHZ_SLZ_Smashable_Wall
		plcm	Nem_GHZ_SWall,	ArtTile_GHZ_Edge_Wall
PLC_GHZ3_Extra_End:	plccheck PLC_GHZ3_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Twilight Hill - Act 4
; ---------------------------------------------------------------------------
PLC_GHZ4_Main:		dc.w (PLC_GHZ4_Main_End-PLC_GHZ4_Main-2)/6-1
		plcm	Nem_Swing,	ArtTile_GHZ_MZ_Swing
		plcm	Nem_GHZ_Ball,	ArtTile_GHZ_Giant_Ball ; giant ball
		plcm	Nem_PlatformButton,	ArtTile_PlatformButton
PLC_GHZ4_Main_End:	plccheck PLC_GHZ4_Main,ActPLC_Main_Reserve

PLC_GHZ4_Extra:		dc.w (PLC_GHZ4_Extra_End-PLC_GHZ4_Extra-2)/6-1
		plcm	Nem_HSpring2,	ArtTile_S1_Spring_Horizontal
		plcm	Nem_VSpring2,	ArtTile_S1_Spring_Vertical
		plcm	Nem_HangingSurface,	ArtTile_HangingSurface
PLC_GHZ4_Extra_End:	plccheck PLC_GHZ4_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Rustic Ruins - Act 1
; ---------------------------------------------------------------------------
PLC_LZ1_Main:		dc.w (PLC_LZ1_Main_End-PLC_LZ1_Main-2)/6-1
		plcm	Nem_MorphingPlatform,	ArtTile_MorphingOrbs ; without a filler entry, this crashes
		plcm	Nem_WaterBubbles,	ArtTile_Bubbles
PLC_LZ1_Main_End:	plccheck PLC_LZ1_Main,ActPLC_Main_Reserve

PLC_LZ1_Extra:		dc.w (PLC_LZ1_Extra_End-PLC_LZ1_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
		plcm	Nem_HangingSurface,	ArtTile_HangingSurface
PLC_LZ1_Extra_End:	plccheck PLC_LZ1_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Rustic Ruins - Act 2
; ---------------------------------------------------------------------------
PLC_LZ2_Main:		dc.w (PLC_LZ2_Main_End-PLC_LZ2_Main-2)/6-1
		plcm	Nem_MorphingPlatform,	ArtTile_MorphingOrbs ; without a filler entry, this crashes
		plcm	Nem_WaterBubbles,	ArtTile_Bubbles
PLC_LZ2_Main_End:	plccheck PLC_LZ2_Main,ActPLC_Main_Reserve

PLC_LZ2_Extra:		dc.w (PLC_LZ2_Extra_End-PLC_LZ2_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
		plcm	Nem_HangingSurface,	ArtTile_HangingSurface
PLC_LZ2_Extra_End:	plccheck PLC_LZ2_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Rustic Ruins - Act 3
; ---------------------------------------------------------------------------
PLC_LZ3_Main:		dc.w (PLC_LZ3_Main_End-PLC_LZ3_Main-2)/6-1
		plcm	Nem_MorphingPlatform,	ArtTile_MorphingOrbs ; without a filler entry, this crashes
		plcm	Nem_WaterBubbles,	ArtTile_Bubbles
PLC_LZ3_Main_End:	plccheck PLC_LZ3_Main,ActPLC_Main_Reserve

PLC_LZ3_Extra:		dc.w (PLC_LZ3_Extra_End-PLC_LZ3_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
		plcm	Nem_HangingSurface,	ArtTile_HangingSurface
PLC_LZ3_Extra_End:	plccheck PLC_LZ3_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Rustic Ruins - Act 4
; ---------------------------------------------------------------------------
PLC_LZ4_Main:		dc.w (PLC_LZ4_Main_End-PLC_LZ4_Main-2)/6-1
		plcm	Nem_MorphingPlatform,	ArtTile_MorphingOrbs ; without a filler entry, this crashes
		plcm	Nem_WaterBubbles,	ArtTile_Bubbles
PLC_LZ4_Main_End:	plccheck PLC_LZ4_Main,ActPLC_Main_Reserve

PLC_LZ4_Extra:		dc.w (PLC_LZ4_Extra_End-PLC_LZ4_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
		plcm	Nem_HangingSurface,	ArtTile_HangingSurface
PLC_LZ4_Extra_End:	plccheck PLC_LZ4_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Ancient Workbench - Act 1
; ---------------------------------------------------------------------------
PLC_CPZ1_Main:		dc.w (PLC_CPZ1_Main_End-PLC_CPZ1_Main-2)/6-1
		plcm	Nem_CPZ_Platform1,	ArtTile_CPZ_Platform
PLC_CPZ1_Main_End:	plccheck PLC_CPZ1_Main,ActPLC_Main_Reserve

PLC_CPZ1_Extra:		dc.w (PLC_CPZ1_Extra_End-PLC_CPZ1_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_CPZ1_Extra_End:	plccheck PLC_CPZ1_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Ancient Workbench - Act 2
; ---------------------------------------------------------------------------
PLC_CPZ2_Main:		dc.w (PLC_CPZ2_Main_End-PLC_CPZ2_Main-2)/6-1
		plcm	Nem_CPZ_Platform1,	ArtTile_CPZ_Platform
PLC_CPZ2_Main_End:	plccheck PLC_CPZ2_Main,ActPLC_Main_Reserve

PLC_CPZ2_Extra:		dc.w (PLC_CPZ2_Extra_End-PLC_CPZ2_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_CPZ2_Extra_End:	plccheck PLC_CPZ2_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Ancient Workbench - Act 3
; ---------------------------------------------------------------------------
PLC_CPZ3_Main:		dc.w (PLC_CPZ3_Main_End-PLC_CPZ3_Main-2)/6-1
		plcm	Nem_CPZ_Platform1,	ArtTile_CPZ_Platform
PLC_CPZ3_Main_End:	plccheck PLC_CPZ3_Main,ActPLC_Main_Reserve

PLC_CPZ3_Extra:		dc.w (PLC_CPZ3_Extra_End-PLC_CPZ3_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_CPZ3_Extra_End:	plccheck PLC_CPZ3_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Ancient Workbench - Act 4
; ---------------------------------------------------------------------------
PLC_CPZ4_Main:		dc.w (PLC_CPZ4_Main_End-PLC_CPZ4_Main-2)/6-1
		plcm	Nem_CPZ_Platform1,	ArtTile_CPZ_Platform
PLC_CPZ4_Main_End:	plccheck PLC_CPZ4_Main,ActPLC_Main_Reserve

PLC_CPZ4_Extra:		dc.w (PLC_CPZ4_Extra_End-PLC_CPZ4_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_CPZ4_Extra_End:	plccheck PLC_CPZ4_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Emerald Hill - Act 1
; ---------------------------------------------------------------------------
PLC_EHZ1_Main:		dc.w (PLC_EHZ1_Main_End-PLC_EHZ1_Main-2)/6-1
		plcm	Nem_EHZ_Fireball,	ArtTile_Fireball
		plcm	Nem_EHZ_Waterfall,	ArtTile_Waterfall
		plcm	Nem_EHZ_Bridge,	ArtTile_EHZ_Bridge
		plcm	Nem_HTZ_Seesaw,	ArtTile_HTZ_Seesaw
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_EHZ1_Main_End:	plccheck PLC_EHZ1_Main,ActPLC_Main_Reserve

PLC_EHZ1_Extra:		dc.w (PLC_EHZ1_Extra_End-PLC_EHZ1_Extra-2)/6-1
		plcm	Nem_Buzzer,	ArtTile_Buzzer
		plcm	Nem_Snail,	ArtTile_Snail
		plcm	Nem_Masher,	ArtTile_Masher
PLC_EHZ1_Extra_End:	plccheck PLC_EHZ1_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Emerald Hill - Act 2
; ---------------------------------------------------------------------------
PLC_EHZ2_Main:		dc.w (PLC_EHZ2_Main_End-PLC_EHZ2_Main-2)/6-1
		plcm	Nem_EHZ_Fireball,	ArtTile_Fireball
		plcm	Nem_EHZ_Waterfall,	ArtTile_Waterfall
		plcm	Nem_EHZ_Bridge,	ArtTile_EHZ_Bridge
		plcm	Nem_HTZ_Seesaw,	ArtTile_HTZ_Seesaw
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_EHZ2_Main_End:	plccheck PLC_EHZ2_Main,ActPLC_Main_Reserve

PLC_EHZ2_Extra:		dc.w (PLC_EHZ2_Extra_End-PLC_EHZ2_Extra-2)/6-1
		plcm	Nem_Buzzer,	ArtTile_Buzzer
		plcm	Nem_Snail,	ArtTile_Snail
		plcm	Nem_Masher,	ArtTile_Masher
PLC_EHZ2_Extra_End:	plccheck PLC_EHZ2_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Emerald Hill - Act 3
; ---------------------------------------------------------------------------
PLC_EHZ3_Main:		dc.w (PLC_EHZ3_Main_End-PLC_EHZ3_Main-2)/6-1
		plcm	Nem_EHZ_Fireball,	ArtTile_Fireball
		plcm	Nem_EHZ_Waterfall,	ArtTile_Waterfall
		plcm	Nem_EHZ_Bridge,	ArtTile_EHZ_Bridge
		plcm	Nem_HTZ_Seesaw,	ArtTile_HTZ_Seesaw
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_EHZ3_Main_End:	plccheck PLC_EHZ3_Main,ActPLC_Main_Reserve

PLC_EHZ3_Extra:		dc.w (PLC_EHZ3_Extra_End-PLC_EHZ3_Extra-2)/6-1
		plcm	Nem_Buzzer,	ArtTile_Buzzer
		plcm	Nem_Snail,	ArtTile_Snail
		plcm	Nem_Masher,	ArtTile_Masher
PLC_EHZ3_Extra_End:	plccheck PLC_EHZ3_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Emerald Hill - Act 4
; ---------------------------------------------------------------------------
PLC_EHZ4_Main:		dc.w (PLC_EHZ4_Main_End-PLC_EHZ4_Main-2)/6-1
		plcm	Nem_EHZ_Fireball,	ArtTile_Fireball
		plcm	Nem_EHZ_Waterfall,	ArtTile_Waterfall
		plcm	Nem_EHZ_Bridge,	ArtTile_EHZ_Bridge
		plcm	Nem_HTZ_Seesaw,	ArtTile_HTZ_Seesaw
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_EHZ4_Main_End:	plccheck PLC_EHZ4_Main,ActPLC_Main_Reserve

PLC_EHZ4_Extra:		dc.w (PLC_EHZ4_Extra_End-PLC_EHZ4_Extra-2)/6-1
		plcm	Nem_Buzzer,	ArtTile_Buzzer
		plcm	Nem_Snail,	ArtTile_Snail
		plcm	Nem_Masher,	ArtTile_Masher
PLC_EHZ4_Extra_End:	plccheck PLC_EHZ4_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Crystal Valley - Act 1
; ---------------------------------------------------------------------------
PLC_HPZ1_Main:		dc.w (PLC_HPZ1_Main_End-PLC_HPZ1_Main-2)/6-1
		plcm	Nem_HPZ_Bridge,	ArtTile_HPZ_Bridge
		plcm	Nem_HPZ_Waterfall,	ArtTile_HPZ_Waterfall
		plcm	Nem_HPZ_Platform,	ArtTile_HPZ_Platform
		plcm	Nem_HPZ_PulsingBall,	ArtTile_HPZ_Orb
		plcm	Nem_WaterBubbles,	ArtTile_Bubbles
PLC_HPZ1_Main_End:	plccheck PLC_HPZ1_Main,ActPLC_Main_Reserve

PLC_HPZ1_Extra:		dc.w (PLC_HPZ1_Extra_End-PLC_HPZ1_Extra-2)/6-1
		plcm	Nem_HPZ_Various,	$37C
		plcm	Nem_HPZ_Emerald,	ArtTile_HPZ_Emerald
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_HPZ1_Extra_End:	plccheck PLC_HPZ1_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Crystal Valley - Act 2
; ---------------------------------------------------------------------------
PLC_HPZ2_Main:		dc.w (PLC_HPZ2_Main_End-PLC_HPZ2_Main-2)/6-1
		plcm	Nem_HPZ_Bridge,	ArtTile_HPZ_Bridge
		plcm	Nem_HPZ_Waterfall,	ArtTile_HPZ_Waterfall
		plcm	Nem_HPZ_Platform,	ArtTile_HPZ_Platform
		plcm	Nem_HPZ_PulsingBall,	ArtTile_HPZ_Orb
		plcm	Nem_WaterBubbles,	ArtTile_Bubbles
PLC_HPZ2_Main_End:	plccheck PLC_HPZ2_Main,ActPLC_Main_Reserve

PLC_HPZ2_Extra:		dc.w (PLC_HPZ2_Extra_End-PLC_HPZ2_Extra-2)/6-1
		plcm	Nem_HPZ_Various,	$37C
		plcm	Nem_HPZ_Emerald,	ArtTile_HPZ_Emerald
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_HPZ2_Extra_End:	plccheck PLC_HPZ2_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Crystal Valley - Act 3
; ---------------------------------------------------------------------------
PLC_HPZ3_Main:		dc.w (PLC_HPZ3_Main_End-PLC_HPZ3_Main-2)/6-1
		plcm	Nem_HPZ_Bridge,	ArtTile_HPZ_Bridge
		plcm	Nem_HPZ_Waterfall,	ArtTile_HPZ_Waterfall
		plcm	Nem_HPZ_Platform,	ArtTile_HPZ_Platform
		plcm	Nem_HPZ_PulsingBall,	ArtTile_HPZ_Orb
		plcm	Nem_WaterBubbles,	ArtTile_Bubbles
PLC_HPZ3_Main_End:	plccheck PLC_HPZ3_Main,ActPLC_Main_Reserve

PLC_HPZ3_Extra:		dc.w (PLC_HPZ3_Extra_End-PLC_HPZ3_Extra-2)/6-1
		plcm	Nem_HPZ_Various,	$37C
		plcm	Nem_HPZ_Emerald,	ArtTile_HPZ_Emerald
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_HPZ3_Extra_End:	plccheck PLC_HPZ3_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Crystal Valley - Act 4
; ---------------------------------------------------------------------------
PLC_HPZ4_Main:		dc.w (PLC_HPZ4_Main_End-PLC_HPZ4_Main-2)/6-1
		plcm	Nem_HPZ_Bridge,	ArtTile_HPZ_Bridge
		plcm	Nem_HPZ_Waterfall,	ArtTile_HPZ_Waterfall
		plcm	Nem_HPZ_Platform,	ArtTile_HPZ_Platform
		plcm	Nem_HPZ_PulsingBall,	ArtTile_HPZ_Orb
		plcm	Nem_WaterBubbles,	ArtTile_Bubbles
PLC_HPZ4_Main_End:	plccheck PLC_HPZ4_Main,ActPLC_Main_Reserve

PLC_HPZ4_Extra:		dc.w (PLC_HPZ4_Extra_End-PLC_HPZ4_Extra-2)/6-1
		plcm	Nem_HPZ_Various,	$37C
		plcm	Nem_HPZ_Emerald,	ArtTile_HPZ_Emerald
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_HPZ4_Extra_End:	plccheck PLC_HPZ4_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Egg Mountain - Act 1
; ---------------------------------------------------------------------------
PLC_HTZ1_Main:		dc.w (PLC_HTZ1_Main_End-PLC_HTZ1_Main-2)/6-1
		plcm	Nem_EHZ_Fireball,	ArtTile_Fireball
		plcm	Nem_HTZ_Fireball,	ArtTile_HTZ_Fireball
		plcm	Nem_HTZ_AutomaticDoor,	ArtTile_HTZ_AutomaticDoor
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_HTZ1_Main_End:	plccheck PLC_HTZ1_Main,ActPLC_Main_Reserve

PLC_HTZ1_Extra:		dc.w (PLC_HTZ1_Extra_End-PLC_HTZ1_Extra-2)/6-1
		plcm	Nem_HTZ_Lift,	ArtTile_HtzZipline
		plcm	Nem_EHZ_Bridge,	ArtTile_EHZ_Bridge
		plcm	Nem_HTZ_Seesaw,	ArtTile_HTZ_Seesaw
PLC_HTZ1_Extra_End:	plccheck PLC_HTZ1_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Egg Mountain - Act 2
; ---------------------------------------------------------------------------
PLC_HTZ2_Main:		dc.w (PLC_HTZ2_Main_End-PLC_HTZ2_Main-2)/6-1
		plcm	Nem_EHZ_Fireball,	ArtTile_Fireball
		plcm	Nem_HTZ_Fireball,	ArtTile_HTZ_Fireball
		plcm	Nem_HTZ_AutomaticDoor,	ArtTile_HTZ_AutomaticDoor
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_HTZ2_Main_End:	plccheck PLC_HTZ2_Main,ActPLC_Main_Reserve

PLC_HTZ2_Extra:		dc.w (PLC_HTZ2_Extra_End-PLC_HTZ2_Extra-2)/6-1
		plcm	Nem_HTZ_Lift,	ArtTile_HtzZipline
		plcm	Nem_EHZ_Bridge,	ArtTile_EHZ_Bridge
		plcm	Nem_HTZ_Seesaw,	ArtTile_HTZ_Seesaw
PLC_HTZ2_Extra_End:	plccheck PLC_HTZ2_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Egg Mountain - Act 3
; ---------------------------------------------------------------------------
PLC_HTZ3_Main:		dc.w (PLC_HTZ3_Main_End-PLC_HTZ3_Main-2)/6-1
		plcm	Nem_EHZ_Fireball,	ArtTile_Fireball
		plcm	Nem_HTZ_Fireball,	ArtTile_HTZ_Fireball
		plcm	Nem_HTZ_AutomaticDoor,	ArtTile_HTZ_AutomaticDoor
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_HTZ3_Main_End:	plccheck PLC_HTZ3_Main,ActPLC_Main_Reserve

PLC_HTZ3_Extra:		dc.w (PLC_HTZ3_Extra_End-PLC_HTZ3_Extra-2)/6-1
		plcm	Nem_HTZ_Lift,	ArtTile_HtzZipline
		plcm	Nem_EHZ_Bridge,	ArtTile_EHZ_Bridge
		plcm	Nem_HTZ_Seesaw,	ArtTile_HTZ_Seesaw
PLC_HTZ3_Extra_End:	plccheck PLC_HTZ3_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Egg Mountain - Act 4
; ---------------------------------------------------------------------------
PLC_HTZ4_Main:		dc.w (PLC_HTZ4_Main_End-PLC_HTZ4_Main-2)/6-1
		plcm	Nem_EHZ_Fireball,	ArtTile_Fireball
		plcm	Nem_HTZ_Fireball,	ArtTile_HTZ_Fireball
		plcm	Nem_HTZ_AutomaticDoor,	ArtTile_HTZ_AutomaticDoor
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_HTZ4_Main_End:	plccheck PLC_HTZ4_Main,ActPLC_Main_Reserve

PLC_HTZ4_Extra:		dc.w (PLC_HTZ4_Extra_End-PLC_HTZ4_Extra-2)/6-1
		plcm	Nem_HTZ_Lift,	ArtTile_HtzZipline
		plcm	Nem_EHZ_Bridge,	ArtTile_EHZ_Bridge
		plcm	Nem_HTZ_Seesaw,	ArtTile_HTZ_Seesaw
PLC_HTZ4_Extra_End:	plccheck PLC_HTZ4_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Metropolis - Act 1
; ---------------------------------------------------------------------------
PLC_LV61_Main:		dc.w -1
PLC_LV61_Main_End:	plccheck PLC_LV61_Main,ActPLC_Main_Reserve

PLC_LV61_Extra:		dc.w (PLC_LV61_Extra_End-PLC_LV61_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LV61_Extra_End:	plccheck PLC_LV61_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Metropolis - Act 2
; ---------------------------------------------------------------------------
PLC_LV62_Main:		dc.w -1
PLC_LV62_Main_End:	plccheck PLC_LV62_Main,ActPLC_Main_Reserve

PLC_LV62_Extra:		dc.w (PLC_LV62_Extra_End-PLC_LV62_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LV62_Extra_End:	plccheck PLC_LV62_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Metropolis - Act 3
; ---------------------------------------------------------------------------
PLC_LV63_Main:		dc.w -1
PLC_LV63_Main_End:	plccheck PLC_LV63_Main,ActPLC_Main_Reserve

PLC_LV63_Extra:		dc.w (PLC_LV63_Extra_End-PLC_LV63_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LV63_Extra_End:	plccheck PLC_LV63_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Metropolis - Act 4
; ---------------------------------------------------------------------------
PLC_LV64_Main:		dc.w -1
PLC_LV64_Main_End:	plccheck PLC_LV64_Main,ActPLC_Main_Reserve

PLC_LV64_Extra:		dc.w (PLC_LV64_Extra_End-PLC_LV64_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LV64_Extra_End:	plccheck PLC_LV64_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Shocking Blizzard - Act 1
; ---------------------------------------------------------------------------
PLC_LV71_Main:		dc.w -1
PLC_LV71_Main_End:	plccheck PLC_LV71_Main,ActPLC_Main_Reserve

PLC_LV71_Extra:		dc.w (PLC_LV71_Extra_End-PLC_LV71_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LV71_Extra_End:	plccheck PLC_LV71_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Shocking Blizzard - Act 2
; ---------------------------------------------------------------------------
PLC_LV72_Main:		dc.w -1
PLC_LV72_Main_End:	plccheck PLC_LV72_Main,ActPLC_Main_Reserve

PLC_LV72_Extra:		dc.w (PLC_LV72_Extra_End-PLC_LV72_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LV72_Extra_End:	plccheck PLC_LV72_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Shocking Blizzard - Act 3
; ---------------------------------------------------------------------------
PLC_LV73_Main:		dc.w -1
PLC_LV73_Main_End:	plccheck PLC_LV73_Main,ActPLC_Main_Reserve

PLC_LV73_Extra:		dc.w (PLC_LV73_Extra_End-PLC_LV73_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LV73_Extra_End:	plccheck PLC_LV73_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Shocking Blizzard - Act 4
; ---------------------------------------------------------------------------
PLC_LV74_Main:		dc.w -1
PLC_LV74_Main_End:	plccheck PLC_LV74_Main,ActPLC_Main_Reserve

PLC_LV74_Extra:		dc.w (PLC_LV74_Extra_End-PLC_LV74_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LV74_Extra_End:	plccheck PLC_LV74_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Scrap Madness - Act 1
; ---------------------------------------------------------------------------
PLC_SMZ1_Main:		dc.w (PLC_SMZ1_Main_End-PLC_SMZ1_Main-2)/6-1
		plcm	Nem_SMZAtlas,	ArtTile_SMZ_Atlas
PLC_SMZ1_Main_End:	plccheck PLC_SMZ1_Main,ActPLC_Main_Reserve

PLC_SMZ1_Extra:		dc.w (PLC_SMZ1_Extra_End-PLC_SMZ1_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_SMZ1_Extra_End:	plccheck PLC_SMZ1_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Scrap Madness - Act 2
; ---------------------------------------------------------------------------
PLC_SMZ2_Main:		dc.w (PLC_SMZ2_Main_End-PLC_SMZ2_Main-2)/6-1
		plcm	Nem_SMZAtlas,	ArtTile_SMZ_Atlas
		plcm	Nem_Kemusi,	ArtTile_SMZ_Kemusi
PLC_SMZ2_Main_End:	plccheck PLC_SMZ2_Main,ActPLC_Main_Reserve

PLC_SMZ2_Extra:		dc.w (PLC_SMZ2_Extra_End-PLC_SMZ2_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_SMZ2_Extra_End:	plccheck PLC_SMZ2_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Scrap Madness - Act 3
; ---------------------------------------------------------------------------
PLC_SMZ3_Main:		dc.w (PLC_SMZ3_Main_End-PLC_SMZ3_Main-2)/6-1
		plcm	Nem_SMZAtlas,	ArtTile_SMZ_Atlas
PLC_SMZ3_Main_End:	plccheck PLC_SMZ3_Main,ActPLC_Main_Reserve

PLC_SMZ3_Extra:		dc.w (PLC_SMZ3_Extra_End-PLC_SMZ3_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_SMZ3_Extra_End:	plccheck PLC_SMZ3_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Scrap Madness - Act 4
; ---------------------------------------------------------------------------
PLC_SMZ4_Main:		dc.w (PLC_SMZ4_Main_End-PLC_SMZ4_Main-2)/6-1
		plcm	Nem_SMZAtlas,	ArtTile_SMZ_Atlas
PLC_SMZ4_Main_End:	plccheck PLC_SMZ4_Main,ActPLC_Main_Reserve

PLC_SMZ4_Extra:		dc.w (PLC_SMZ4_Extra_End-PLC_SMZ4_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_SMZ4_Extra_End:	plccheck PLC_SMZ4_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Death Egg - Act 1
; ---------------------------------------------------------------------------
PLC_LV91_Main:		dc.w -1
PLC_LV91_Main_End:	plccheck PLC_LV91_Main,ActPLC_Main_Reserve

PLC_LV91_Extra:		dc.w (PLC_LV91_Extra_End-PLC_LV91_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LV91_Extra_End:	plccheck PLC_LV91_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Death Egg - Act 2
; ---------------------------------------------------------------------------
PLC_LV92_Main:		dc.w -1
PLC_LV92_Main_End:	plccheck PLC_LV92_Main,ActPLC_Main_Reserve

PLC_LV92_Extra:		dc.w (PLC_LV92_Extra_End-PLC_LV92_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LV92_Extra_End:	plccheck PLC_LV92_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Death Egg - Act 3
; ---------------------------------------------------------------------------
PLC_LV93_Main:		dc.w -1
PLC_LV93_Main_End:	plccheck PLC_LV93_Main,ActPLC_Main_Reserve

PLC_LV93_Extra:		dc.w (PLC_LV93_Extra_End-PLC_LV93_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LV93_Extra_End:	plccheck PLC_LV93_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Death Egg - Act 4
; ---------------------------------------------------------------------------
PLC_LV94_Main:		dc.w -1
PLC_LV94_Main_End:	plccheck PLC_LV94_Main,ActPLC_Main_Reserve

PLC_LV94_Extra:		dc.w (PLC_LV94_Extra_End-PLC_LV94_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LV94_Extra_End:	plccheck PLC_LV94_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0A - Act 1
; ---------------------------------------------------------------------------
PLC_PP1_Main:		dc.w (PLC_PP1_Main_End-PLC_PP1_Main-2)/6-1
		plcm	Nem_PP_Anton,	ArtTile_PP_Anton
		plcm	Nem_PP_Mosqui,	ArtTile_PP_Mosqui
		plcm	Nem_PP_PataBata,	ArtTile_PP_PataBata
		plcm	Nem_PP_TagaTaga,	ArtTile_PP_TagaTaga
		plcm	Nem_PP_Tamabboh,	ArtTile_PP_Tamabboh
		plcm	Nem_MM_Propeller,	ArtTile_Propeller
		plcm	Nem_Wheel,	ArtTile_Wheel
PLC_PP1_Main_End:	plccheck PLC_PP1_Main,ActPLC_Main_Reserve

PLC_PP1_Extra:		dc.w (PLC_PP1_Extra_End-PLC_PP1_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_PP1_Extra_End:	plccheck PLC_PP1_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0A - Act 2
; ---------------------------------------------------------------------------
PLC_PP2_Main:		dc.w (PLC_PP2_Main_End-PLC_PP2_Main-2)/6-1
		plcm	Nem_PP_Anton,	ArtTile_PP_Anton
		plcm	Nem_PP_Mosqui,	ArtTile_PP_Mosqui
		plcm	Nem_PP_PataBata,	ArtTile_PP_PataBata
		plcm	Nem_PP_TagaTaga,	ArtTile_PP_TagaTaga
		plcm	Nem_PP_Tamabboh,	ArtTile_PP_Tamabboh
		plcm	Nem_MM_Propeller,	ArtTile_Propeller
		plcm	Nem_Wheel,	ArtTile_Wheel
PLC_PP2_Main_End:	plccheck PLC_PP2_Main,ActPLC_Main_Reserve

PLC_PP2_Extra:		dc.w (PLC_PP2_Extra_End-PLC_PP2_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_PP2_Extra_End:	plccheck PLC_PP2_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0A - Act 3
; ---------------------------------------------------------------------------
PLC_PP3_Main:		dc.w (PLC_PP3_Main_End-PLC_PP3_Main-2)/6-1
		plcm	Nem_PP_Anton,	ArtTile_PP_Anton
		plcm	Nem_PP_Mosqui,	ArtTile_PP_Mosqui
		plcm	Nem_PP_PataBata,	ArtTile_PP_PataBata
		plcm	Nem_PP_TagaTaga,	ArtTile_PP_TagaTaga
		plcm	Nem_PP_Tamabboh,	ArtTile_PP_Tamabboh
		plcm	Nem_MM_Propeller,	ArtTile_Propeller
		plcm	Nem_Wheel,	ArtTile_Wheel
PLC_PP3_Main_End:	plccheck PLC_PP3_Main,ActPLC_Main_Reserve

PLC_PP3_Extra:		dc.w (PLC_PP3_Extra_End-PLC_PP3_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_PP3_Extra_End:	plccheck PLC_PP3_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0A - Act 4
; ---------------------------------------------------------------------------
PLC_PP4_Main:		dc.w (PLC_PP4_Main_End-PLC_PP4_Main-2)/6-1
		plcm	Nem_PP_Anton,	ArtTile_PP_Anton
		plcm	Nem_PP_Mosqui,	ArtTile_PP_Mosqui
		plcm	Nem_PP_PataBata,	ArtTile_PP_PataBata
		plcm	Nem_PP_TagaTaga,	ArtTile_PP_TagaTaga
		plcm	Nem_PP_Tamabboh,	ArtTile_PP_Tamabboh
		plcm	Nem_MM_Propeller,	ArtTile_Propeller
		plcm	Nem_Wheel,	ArtTile_Wheel
PLC_PP4_Main_End:	plccheck PLC_PP4_Main,ActPLC_Main_Reserve

PLC_PP4_Extra:		dc.w (PLC_PP4_Extra_End-PLC_PP4_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_PP4_Extra_End:	plccheck PLC_PP4_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0B - Act 1
; ---------------------------------------------------------------------------
PLC_LVB1_Main:		dc.w -1
PLC_LVB1_Main_End:	plccheck PLC_LVB1_Main,ActPLC_Main_Reserve

PLC_LVB1_Extra:		dc.w (PLC_LVB1_Extra_End-PLC_LVB1_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVB1_Extra_End:	plccheck PLC_LVB1_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0B - Act 2
; ---------------------------------------------------------------------------
PLC_LVB2_Main:		dc.w -1
PLC_LVB2_Main_End:	plccheck PLC_LVB2_Main,ActPLC_Main_Reserve

PLC_LVB2_Extra:		dc.w (PLC_LVB2_Extra_End-PLC_LVB2_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVB2_Extra_End:	plccheck PLC_LVB2_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0B - Act 3
; ---------------------------------------------------------------------------
PLC_LVB3_Main:		dc.w -1
PLC_LVB3_Main_End:	plccheck PLC_LVB3_Main,ActPLC_Main_Reserve

PLC_LVB3_Extra:		dc.w (PLC_LVB3_Extra_End-PLC_LVB3_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVB3_Extra_End:	plccheck PLC_LVB3_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0B - Act 4
; ---------------------------------------------------------------------------
PLC_LVB4_Main:		dc.w -1
PLC_LVB4_Main_End:	plccheck PLC_LVB4_Main,ActPLC_Main_Reserve

PLC_LVB4_Extra:		dc.w (PLC_LVB4_Extra_End-PLC_LVB4_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVB4_Extra_End:	plccheck PLC_LVB4_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0C - Act 1
; ---------------------------------------------------------------------------
PLC_LVC1_Main:		dc.w -1
PLC_LVC1_Main_End:	plccheck PLC_LVC1_Main,ActPLC_Main_Reserve

PLC_LVC1_Extra:		dc.w (PLC_LVC1_Extra_End-PLC_LVC1_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVC1_Extra_End:	plccheck PLC_LVC1_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0C - Act 2
; ---------------------------------------------------------------------------
PLC_LVC2_Main:		dc.w -1
PLC_LVC2_Main_End:	plccheck PLC_LVC2_Main,ActPLC_Main_Reserve

PLC_LVC2_Extra:		dc.w (PLC_LVC2_Extra_End-PLC_LVC2_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVC2_Extra_End:	plccheck PLC_LVC2_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0C - Act 3
; ---------------------------------------------------------------------------
PLC_LVC3_Main:		dc.w -1
PLC_LVC3_Main_End:	plccheck PLC_LVC3_Main,ActPLC_Main_Reserve

PLC_LVC3_Extra:		dc.w (PLC_LVC3_Extra_End-PLC_LVC3_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVC3_Extra_End:	plccheck PLC_LVC3_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0C - Act 4
; ---------------------------------------------------------------------------
PLC_LVC4_Main:		dc.w -1
PLC_LVC4_Main_End:	plccheck PLC_LVC4_Main,ActPLC_Main_Reserve

PLC_LVC4_Extra:		dc.w (PLC_LVC4_Extra_End-PLC_LVC4_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVC4_Extra_End:	plccheck PLC_LVC4_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0D - Act 1
; ---------------------------------------------------------------------------
PLC_LVD1_Main:		dc.w -1
PLC_LVD1_Main_End:	plccheck PLC_LVD1_Main,ActPLC_Main_Reserve

PLC_LVD1_Extra:		dc.w (PLC_LVD1_Extra_End-PLC_LVD1_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVD1_Extra_End:	plccheck PLC_LVD1_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0D - Act 2
; ---------------------------------------------------------------------------
PLC_LVD2_Main:		dc.w -1
PLC_LVD2_Main_End:	plccheck PLC_LVD2_Main,ActPLC_Main_Reserve

PLC_LVD2_Extra:		dc.w (PLC_LVD2_Extra_End-PLC_LVD2_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVD2_Extra_End:	plccheck PLC_LVD2_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0D - Act 3
; ---------------------------------------------------------------------------
PLC_LVD3_Main:		dc.w -1
PLC_LVD3_Main_End:	plccheck PLC_LVD3_Main,ActPLC_Main_Reserve

PLC_LVD3_Extra:		dc.w (PLC_LVD3_Extra_End-PLC_LVD3_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVD3_Extra_End:	plccheck PLC_LVD3_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0D - Act 4
; ---------------------------------------------------------------------------
PLC_LVD4_Main:		dc.w -1
PLC_LVD4_Main_End:	plccheck PLC_LVD4_Main,ActPLC_Main_Reserve

PLC_LVD4_Extra:		dc.w (PLC_LVD4_Extra_End-PLC_LVD4_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVD4_Extra_End:	plccheck PLC_LVD4_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0E - Act 1
; ---------------------------------------------------------------------------
PLC_LVE1_Main:		dc.w -1
PLC_LVE1_Main_End:	plccheck PLC_LVE1_Main,ActPLC_Main_Reserve

PLC_LVE1_Extra:		dc.w (PLC_LVE1_Extra_End-PLC_LVE1_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVE1_Extra_End:	plccheck PLC_LVE1_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0E - Act 2
; ---------------------------------------------------------------------------
PLC_LVE2_Main:		dc.w -1
PLC_LVE2_Main_End:	plccheck PLC_LVE2_Main,ActPLC_Main_Reserve

PLC_LVE2_Extra:		dc.w (PLC_LVE2_Extra_End-PLC_LVE2_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVE2_Extra_End:	plccheck PLC_LVE2_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0E - Act 3
; ---------------------------------------------------------------------------
PLC_LVE3_Main:		dc.w -1
PLC_LVE3_Main_End:	plccheck PLC_LVE3_Main,ActPLC_Main_Reserve

PLC_LVE3_Extra:		dc.w (PLC_LVE3_Extra_End-PLC_LVE3_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVE3_Extra_End:	plccheck PLC_LVE3_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0E - Act 4
; ---------------------------------------------------------------------------
PLC_LVE4_Main:		dc.w -1
PLC_LVE4_Main_End:	plccheck PLC_LVE4_Main,ActPLC_Main_Reserve

PLC_LVE4_Extra:		dc.w (PLC_LVE4_Extra_End-PLC_LVE4_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVE4_Extra_End:	plccheck PLC_LVE4_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0F - Act 1
; ---------------------------------------------------------------------------
PLC_LVF1_Main:		dc.w -1
PLC_LVF1_Main_End:	plccheck PLC_LVF1_Main,ActPLC_Main_Reserve

PLC_LVF1_Extra:		dc.w (PLC_LVF1_Extra_End-PLC_LVF1_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVF1_Extra_End:	plccheck PLC_LVF1_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0F - Act 2
; ---------------------------------------------------------------------------
PLC_LVF2_Main:		dc.w -1
PLC_LVF2_Main_End:	plccheck PLC_LVF2_Main,ActPLC_Main_Reserve

PLC_LVF2_Extra:		dc.w (PLC_LVF2_Extra_End-PLC_LVF2_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVF2_Extra_End:	plccheck PLC_LVF2_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0F - Act 3
; ---------------------------------------------------------------------------
PLC_LVF3_Main:		dc.w -1
PLC_LVF3_Main_End:	plccheck PLC_LVF3_Main,ActPLC_Main_Reserve

PLC_LVF3_Extra:		dc.w (PLC_LVF3_Extra_End-PLC_LVF3_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVF3_Extra_End:	plccheck PLC_LVF3_Extra,0

; ---------------------------------------------------------------------------
; PATTERN LOAD REQUEST LISTS
; Level 0F - Act 4
; ---------------------------------------------------------------------------
PLC_LVF4_Main:		dc.w -1
PLC_LVF4_Main_End:	plccheck PLC_LVF4_Main,ActPLC_Main_Reserve

PLC_LVF4_Extra:		dc.w (PLC_LVF4_Extra_End-PLC_LVF4_Extra-2)/6-1
		plcm	Nem_DSpring,	ArtTile_Spring_Diagonal
		plcm	Nem_VSpring2,	ArtTile_Spring_Vertical
		plcm	Nem_HSpring2,	ArtTile_Spring_Horizontal
PLC_LVF4_Extra_End:	plccheck PLC_LVF4_Extra,0

; ---------------------------------------------------------------------------
; Pattern load cue IDs
; ---------------------------------------------------------------------------
plcid_Main:		equ (ptr_PLC_Main-ArtLoadCues)/2
plcid_Main2:		equ (ptr_PLC_Main2-ArtLoadCues)/2
plcid_Explode:		equ (ptr_PLC_Explode-ArtLoadCues)/2
plcid_GameOver:		equ (ptr_PLC_GameOver-ArtLoadCues)/2
plcid_TitleCard:	equ (ptr_PLC_TitleCard-ArtLoadCues)/2
plcid_Boss:		equ (ptr_PLC_Boss-ArtLoadCues)/2
plcid_Signpost:		equ (ptr_PLC_Signpost-ArtLoadCues)/2
plcid_Warp:		equ (ptr_PLC_Warp-ArtLoadCues)/2
plcid_SpecialStage:	equ (ptr_PLC_SpecialStage-ArtLoadCues)/2
plcid_GHZAnimals:	equ (ptr_PLC_GHZAnimals-ArtLoadCues)/2
plcid_LZAnimals:	equ (ptr_PLC_LZAnimals-ArtLoadCues)/2
plcid_CPZAnimals:	equ (ptr_PLC_CPZAnimals-ArtLoadCues)/2
plcid_EHZAnimals:	equ (ptr_PLC_EHZAnimals-ArtLoadCues)/2
plcid_HPZAnimals:	equ (ptr_PLC_HPZAnimals-ArtLoadCues)/2
plcid_HTZAnimals:	equ (ptr_PLC_HTZAnimals-ArtLoadCues)/2
plcid_SSResult:		equ (ptr_PLC_SSResult-ArtLoadCues)/2
plcid_Ending:		equ (ptr_PLC_Ending-ArtLoadCues)/2
plcid_TryAgain:		equ (ptr_PLC_TryAgain-ArtLoadCues)/2
plcid_EggmanSBZ2:	equ (ptr_PLC_EggmanSBZ2-ArtLoadCues)/2
plcid_FZBoss:		equ (ptr_PLC_FZBoss-ArtLoadCues)/2
plcid_Capsule:		equ (ptr_PLC_Capsule-ArtLoadCues)/2
plcid_GHZBoss:		equ (ptr_PLC_GHZBoss-ArtLoadCues)/2
plcid_LivesSonic:	equ (ptr_PLC_LivesSonic-ArtLoadCues)/2
plcid_LivesTails:	equ (ptr_PLC_LivesTails-ArtLoadCues)/2
plcid_ExplosionWall:	equ (ptr_PLC_ExplosionWall-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $00: Twilight Hill
plcid_GHZ1_Main:	equ (ptr_PLC_GHZ1_Main-ArtLoadCues)/2
plcid_GHZ1_Extra:	equ (ptr_PLC_GHZ1_Extra-ArtLoadCues)/2
plcid_GHZ2_Main:	equ (ptr_PLC_GHZ2_Main-ArtLoadCues)/2
plcid_GHZ2_Extra:	equ (ptr_PLC_GHZ2_Extra-ArtLoadCues)/2
plcid_GHZ3_Main:	equ (ptr_PLC_GHZ3_Main-ArtLoadCues)/2
plcid_GHZ3_Extra:	equ (ptr_PLC_GHZ3_Extra-ArtLoadCues)/2
plcid_GHZ4_Main:	equ (ptr_PLC_GHZ4_Main-ArtLoadCues)/2
plcid_GHZ4_Extra:	equ (ptr_PLC_GHZ4_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $01: Rustic Ruins
plcid_LZ1_Main:		equ (ptr_PLC_LZ1_Main-ArtLoadCues)/2
plcid_LZ1_Extra:	equ (ptr_PLC_LZ1_Extra-ArtLoadCues)/2
plcid_LZ2_Main:		equ (ptr_PLC_LZ2_Main-ArtLoadCues)/2
plcid_LZ2_Extra:	equ (ptr_PLC_LZ2_Extra-ArtLoadCues)/2
plcid_LZ3_Main:		equ (ptr_PLC_LZ3_Main-ArtLoadCues)/2
plcid_LZ3_Extra:	equ (ptr_PLC_LZ3_Extra-ArtLoadCues)/2
plcid_LZ4_Main:		equ (ptr_PLC_LZ4_Main-ArtLoadCues)/2
plcid_LZ4_Extra:	equ (ptr_PLC_LZ4_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $02: Ancient Workbench
plcid_CPZ1_Main:	equ (ptr_PLC_CPZ1_Main-ArtLoadCues)/2
plcid_CPZ1_Extra:	equ (ptr_PLC_CPZ1_Extra-ArtLoadCues)/2
plcid_CPZ2_Main:	equ (ptr_PLC_CPZ2_Main-ArtLoadCues)/2
plcid_CPZ2_Extra:	equ (ptr_PLC_CPZ2_Extra-ArtLoadCues)/2
plcid_CPZ3_Main:	equ (ptr_PLC_CPZ3_Main-ArtLoadCues)/2
plcid_CPZ3_Extra:	equ (ptr_PLC_CPZ3_Extra-ArtLoadCues)/2
plcid_CPZ4_Main:	equ (ptr_PLC_CPZ4_Main-ArtLoadCues)/2
plcid_CPZ4_Extra:	equ (ptr_PLC_CPZ4_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $03: Emerald Hill
plcid_EHZ1_Main:	equ (ptr_PLC_EHZ1_Main-ArtLoadCues)/2
plcid_EHZ1_Extra:	equ (ptr_PLC_EHZ1_Extra-ArtLoadCues)/2
plcid_EHZ2_Main:	equ (ptr_PLC_EHZ2_Main-ArtLoadCues)/2
plcid_EHZ2_Extra:	equ (ptr_PLC_EHZ2_Extra-ArtLoadCues)/2
plcid_EHZ3_Main:	equ (ptr_PLC_EHZ3_Main-ArtLoadCues)/2
plcid_EHZ3_Extra:	equ (ptr_PLC_EHZ3_Extra-ArtLoadCues)/2
plcid_EHZ4_Main:	equ (ptr_PLC_EHZ4_Main-ArtLoadCues)/2
plcid_EHZ4_Extra:	equ (ptr_PLC_EHZ4_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $04: Crystal Valley
plcid_HPZ1_Main:	equ (ptr_PLC_HPZ1_Main-ArtLoadCues)/2
plcid_HPZ1_Extra:	equ (ptr_PLC_HPZ1_Extra-ArtLoadCues)/2
plcid_HPZ2_Main:	equ (ptr_PLC_HPZ2_Main-ArtLoadCues)/2
plcid_HPZ2_Extra:	equ (ptr_PLC_HPZ2_Extra-ArtLoadCues)/2
plcid_HPZ3_Main:	equ (ptr_PLC_HPZ3_Main-ArtLoadCues)/2
plcid_HPZ3_Extra:	equ (ptr_PLC_HPZ3_Extra-ArtLoadCues)/2
plcid_HPZ4_Main:	equ (ptr_PLC_HPZ4_Main-ArtLoadCues)/2
plcid_HPZ4_Extra:	equ (ptr_PLC_HPZ4_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $05: Egg Mountain
plcid_HTZ1_Main:	equ (ptr_PLC_HTZ1_Main-ArtLoadCues)/2
plcid_HTZ1_Extra:	equ (ptr_PLC_HTZ1_Extra-ArtLoadCues)/2
plcid_HTZ2_Main:	equ (ptr_PLC_HTZ2_Main-ArtLoadCues)/2
plcid_HTZ2_Extra:	equ (ptr_PLC_HTZ2_Extra-ArtLoadCues)/2
plcid_HTZ3_Main:	equ (ptr_PLC_HTZ3_Main-ArtLoadCues)/2
plcid_HTZ3_Extra:	equ (ptr_PLC_HTZ3_Extra-ArtLoadCues)/2
plcid_HTZ4_Main:	equ (ptr_PLC_HTZ4_Main-ArtLoadCues)/2
plcid_HTZ4_Extra:	equ (ptr_PLC_HTZ4_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $06: Metropolis
plcid_LV61_Main:	equ (ptr_PLC_LV61_Main-ArtLoadCues)/2
plcid_LV61_Extra:	equ (ptr_PLC_LV61_Extra-ArtLoadCues)/2
plcid_LV62_Main:	equ (ptr_PLC_LV62_Main-ArtLoadCues)/2
plcid_LV62_Extra:	equ (ptr_PLC_LV62_Extra-ArtLoadCues)/2
plcid_LV63_Main:	equ (ptr_PLC_LV63_Main-ArtLoadCues)/2
plcid_LV63_Extra:	equ (ptr_PLC_LV63_Extra-ArtLoadCues)/2
plcid_LV64_Main:	equ (ptr_PLC_LV64_Main-ArtLoadCues)/2
plcid_LV64_Extra:	equ (ptr_PLC_LV64_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $07: Shocking Blizzard
plcid_LV71_Main:	equ (ptr_PLC_LV71_Main-ArtLoadCues)/2
plcid_LV71_Extra:	equ (ptr_PLC_LV71_Extra-ArtLoadCues)/2
plcid_LV72_Main:	equ (ptr_PLC_LV72_Main-ArtLoadCues)/2
plcid_LV72_Extra:	equ (ptr_PLC_LV72_Extra-ArtLoadCues)/2
plcid_LV73_Main:	equ (ptr_PLC_LV73_Main-ArtLoadCues)/2
plcid_LV73_Extra:	equ (ptr_PLC_LV73_Extra-ArtLoadCues)/2
plcid_LV74_Main:	equ (ptr_PLC_LV74_Main-ArtLoadCues)/2
plcid_LV74_Extra:	equ (ptr_PLC_LV74_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $08: Scrap Madness
plcid_SMZ1_Main:	equ (ptr_PLC_SMZ1_Main-ArtLoadCues)/2
plcid_SMZ1_Extra:	equ (ptr_PLC_SMZ1_Extra-ArtLoadCues)/2
plcid_SMZ2_Main:	equ (ptr_PLC_SMZ2_Main-ArtLoadCues)/2
plcid_SMZ2_Extra:	equ (ptr_PLC_SMZ2_Extra-ArtLoadCues)/2
plcid_SMZ3_Main:	equ (ptr_PLC_SMZ3_Main-ArtLoadCues)/2
plcid_SMZ3_Extra:	equ (ptr_PLC_SMZ3_Extra-ArtLoadCues)/2
plcid_SMZ4_Main:	equ (ptr_PLC_SMZ4_Main-ArtLoadCues)/2
plcid_SMZ4_Extra:	equ (ptr_PLC_SMZ4_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $09: Death Egg
plcid_LV91_Main:	equ (ptr_PLC_LV91_Main-ArtLoadCues)/2
plcid_LV91_Extra:	equ (ptr_PLC_LV91_Extra-ArtLoadCues)/2
plcid_LV92_Main:	equ (ptr_PLC_LV92_Main-ArtLoadCues)/2
plcid_LV92_Extra:	equ (ptr_PLC_LV92_Extra-ArtLoadCues)/2
plcid_LV93_Main:	equ (ptr_PLC_LV93_Main-ArtLoadCues)/2
plcid_LV93_Extra:	equ (ptr_PLC_LV93_Extra-ArtLoadCues)/2
plcid_LV94_Main:	equ (ptr_PLC_LV94_Main-ArtLoadCues)/2
plcid_LV94_Extra:	equ (ptr_PLC_LV94_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $0A: Level 0A
plcid_PP1_Main:		equ (ptr_PLC_PP1_Main-ArtLoadCues)/2
plcid_PP1_Extra:	equ (ptr_PLC_PP1_Extra-ArtLoadCues)/2
plcid_PP2_Main:		equ (ptr_PLC_PP2_Main-ArtLoadCues)/2
plcid_PP2_Extra:	equ (ptr_PLC_PP2_Extra-ArtLoadCues)/2
plcid_PP3_Main:		equ (ptr_PLC_PP3_Main-ArtLoadCues)/2
plcid_PP3_Extra:	equ (ptr_PLC_PP3_Extra-ArtLoadCues)/2
plcid_PP4_Main:		equ (ptr_PLC_PP4_Main-ArtLoadCues)/2
plcid_PP4_Extra:	equ (ptr_PLC_PP4_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $0B: Level 0B
plcid_LVB1_Main:	equ (ptr_PLC_LVB1_Main-ArtLoadCues)/2
plcid_LVB1_Extra:	equ (ptr_PLC_LVB1_Extra-ArtLoadCues)/2
plcid_LVB2_Main:	equ (ptr_PLC_LVB2_Main-ArtLoadCues)/2
plcid_LVB2_Extra:	equ (ptr_PLC_LVB2_Extra-ArtLoadCues)/2
plcid_LVB3_Main:	equ (ptr_PLC_LVB3_Main-ArtLoadCues)/2
plcid_LVB3_Extra:	equ (ptr_PLC_LVB3_Extra-ArtLoadCues)/2
plcid_LVB4_Main:	equ (ptr_PLC_LVB4_Main-ArtLoadCues)/2
plcid_LVB4_Extra:	equ (ptr_PLC_LVB4_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $0C: Level 0C
plcid_LVC1_Main:	equ (ptr_PLC_LVC1_Main-ArtLoadCues)/2
plcid_LVC1_Extra:	equ (ptr_PLC_LVC1_Extra-ArtLoadCues)/2
plcid_LVC2_Main:	equ (ptr_PLC_LVC2_Main-ArtLoadCues)/2
plcid_LVC2_Extra:	equ (ptr_PLC_LVC2_Extra-ArtLoadCues)/2
plcid_LVC3_Main:	equ (ptr_PLC_LVC3_Main-ArtLoadCues)/2
plcid_LVC3_Extra:	equ (ptr_PLC_LVC3_Extra-ArtLoadCues)/2
plcid_LVC4_Main:	equ (ptr_PLC_LVC4_Main-ArtLoadCues)/2
plcid_LVC4_Extra:	equ (ptr_PLC_LVC4_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $0D: Level 0D
plcid_LVD1_Main:	equ (ptr_PLC_LVD1_Main-ArtLoadCues)/2
plcid_LVD1_Extra:	equ (ptr_PLC_LVD1_Extra-ArtLoadCues)/2
plcid_LVD2_Main:	equ (ptr_PLC_LVD2_Main-ArtLoadCues)/2
plcid_LVD2_Extra:	equ (ptr_PLC_LVD2_Extra-ArtLoadCues)/2
plcid_LVD3_Main:	equ (ptr_PLC_LVD3_Main-ArtLoadCues)/2
plcid_LVD3_Extra:	equ (ptr_PLC_LVD3_Extra-ArtLoadCues)/2
plcid_LVD4_Main:	equ (ptr_PLC_LVD4_Main-ArtLoadCues)/2
plcid_LVD4_Extra:	equ (ptr_PLC_LVD4_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $0E: Level 0E
plcid_LVE1_Main:	equ (ptr_PLC_LVE1_Main-ArtLoadCues)/2
plcid_LVE1_Extra:	equ (ptr_PLC_LVE1_Extra-ArtLoadCues)/2
plcid_LVE2_Main:	equ (ptr_PLC_LVE2_Main-ArtLoadCues)/2
plcid_LVE2_Extra:	equ (ptr_PLC_LVE2_Extra-ArtLoadCues)/2
plcid_LVE3_Main:	equ (ptr_PLC_LVE3_Main-ArtLoadCues)/2
plcid_LVE3_Extra:	equ (ptr_PLC_LVE3_Extra-ArtLoadCues)/2
plcid_LVE4_Main:	equ (ptr_PLC_LVE4_Main-ArtLoadCues)/2
plcid_LVE4_Extra:	equ (ptr_PLC_LVE4_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Level slot $0F: Level 0F
plcid_LVF1_Main:	equ (ptr_PLC_LVF1_Main-ArtLoadCues)/2
plcid_LVF1_Extra:	equ (ptr_PLC_LVF1_Extra-ArtLoadCues)/2
plcid_LVF2_Main:	equ (ptr_PLC_LVF2_Main-ArtLoadCues)/2
plcid_LVF2_Extra:	equ (ptr_PLC_LVF2_Extra-ArtLoadCues)/2
plcid_LVF3_Main:	equ (ptr_PLC_LVF3_Main-ArtLoadCues)/2
plcid_LVF3_Extra:	equ (ptr_PLC_LVF3_Extra-ArtLoadCues)/2
plcid_LVF4_Main:	equ (ptr_PLC_LVF4_Main-ArtLoadCues)/2
plcid_LVF4_Extra:	equ (ptr_PLC_LVF4_Extra-ArtLoadCues)/2
; ---------------------------------------------------------------------------
; Moduled Kosinski pattern load request lists
; ---------------------------------------------------------------------------
KosMLoadCues:
; Level Slot $00: Twilight Hill Zone  [WILL BE REPLACED] [GHZ]
ptr_KPLC_THZ1:	dc.w PLCKosM_THZ1-KosMLoadCues  ; $00 Act 1
ptr_KPLC_THZ2:	dc.w PLCKosM_THZ2-KosMLoadCues  ; $00 Act 2
ptr_KPLC_THZ3:	dc.w PLCKosM_THZ3-KosMLoadCues  ; $00 Act 3
ptr_KPLC_THZ4:	dc.w PLCKosM_THZ4-KosMLoadCues  ; $00 Act 4
; ---------------------------------------------------------------------------
; Level Slot $01: Rustic Ruins Zone  [WILL BE REPLACED] [LZ]
ptr_KPLC_RRZ1:	dc.w PLCKosM_RRZ1-KosMLoadCues ; $01 Act 1
ptr_KPLC_RRZ2:	dc.w PLCKosM_RRZ2-KosMLoadCues ; $01 Act 2
ptr_KPLC_RRZ3:	dc.w PLCKosM_RRZ3-KosMLoadCues ; $01 Act 3
ptr_KPLC_RRZ4:	dc.w PLCKosM_RRZ4-KosMLoadCues ; $01 Act 4
; ---------------------------------------------------------------------------
; Level Slot $02: Ancient Workbench Zone [TO BE REMIXED] [CPZ]
ptr_KPLC_AWZ1:	dc.w PLCKosM_AWZ1-KosMLoadCues ; $02 Act 1
ptr_KPLC_AWZ2:	dc.w PLCKosM_AWZ2-KosMLoadCues ; $02 Act 2
ptr_KPLC_AWZ3:	dc.w PLCKosM_AWZ3-KosMLoadCues ; $02 Act 3
ptr_KPLC_AWZ4:	dc.w PLCKosM_AWZ4-KosMLoadCues ; $02 Act 4
; ---------------------------------------------------------------------------
; Level Slot $03: Emerald Hill Zone
ptr_KPLC_EHZ1:	dc.w PLCKosM_EHZ1-KosMLoadCues ; $03 Act 1
ptr_KPLC_EHZ2:	dc.w PLCKosM_EHZ2-KosMLoadCues ; $03 Act 2
ptr_KPLC_EHZ3:	dc.w PLCKosM_EHZ3-KosMLoadCues ; $03 Act 3
ptr_KPLC_EHZ4:	dc.w PLCKosM_EHZ4-KosMLoadCues ; $03 Act 4
; ---------------------------------------------------------------------------
; Level Slot $04: Crystal Valley Zone [WILL BE REPLACED] [HPZ]
ptr_KPLC_CVZ1:	dc.w PLCKosM_CVZ1-KosMLoadCues  ; $04 Act 1
ptr_KPLC_CVZ2:	dc.w PLCKosM_CVZ2-KosMLoadCues  ; $04 Act 2
ptr_KPLC_CVZ3:	dc.w PLCKosM_CVZ3-KosMLoadCues  ; $04 Act 3
ptr_KPLC_CVZ4:	dc.w PLCKosM_CVZ4-KosMLoadCues  ; $04 Act 4
; ---------------------------------------------------------------------------
; Level Slot $05: Egg Mountain Zone [TO BE REMIXED] [HTZ]
ptr_KPLC_EMZ1:	dc.w PLCKosM_HTZ1-KosMLoadCues ; $05 Act 1
ptr_KPLC_EMZ2:	dc.w PLCKosM_HTZ2-KosMLoadCues ; $05 Act 2
ptr_KPLC_EMZ3:	dc.w PLCKosM_HTZ3-KosMLoadCues ; $05 Act 3
ptr_KPLC_EMZ4:	dc.w PLCKosM_HTZ4-KosMLoadCues ; $05 Act 4
; ---------------------------------------------------------------------------
; Level Slot $06: Metropolis Zone [TO BE ADDED]
ptr_KPLC_MZ1:	dc.w PLCKosM_LV61-KosMLoadCues ; $06 Act 1
ptr_KPLC_MZ2:	dc.w PLCKosM_LV62-KosMLoadCues ; $06 Act 2
ptr_KPLC_MZ3:	dc.w PLCKosM_LV63-KosMLoadCues ; $06 Act 3
ptr_KPLC_MZ4:	dc.w PLCKosM_LV64-KosMLoadCues ; $06 Act 4
; ---------------------------------------------------------------------------
; Level Slot $07: Shocking Blizzard Zone [TO BE ADDED]
ptr_KPLC_SBZ1:	dc.w PLCKosM_LV71-KosMLoadCues ; $08 Act 1
ptr_KPLC_SBZ2:	dc.w PLCKosM_LV72-KosMLoadCues ; $08 Act 2
ptr_KPLC_SBZ3:	dc.w PLCKosM_LV73-KosMLoadCues ; $08 Act 3
ptr_KPLC_SBZ4:	dc.w PLCKosM_LV74-KosMLoadCues ; $08 Act 4
; ---------------------------------------------------------------------------
; Level Slot $08: Scrap Madness Zone [TO BE ADDED]
ptr_KPLC_SMZ1:	dc.w PLCKosM_SMZ1-KosMLoadCues ; $07 Act 1
ptr_KPLC_SMZ2:	dc.w PLCKosM_SMZ2-KosMLoadCues ; $07 Act 2
ptr_KPLC_SMZ3:	dc.w PLCKosM_SMZ3-KosMLoadCues ; $07 Act 3
ptr_KPLC_SMZ4:	dc.w PLCKosM_SMZ4-KosMLoadCues ; $07 Act 4
; ---------------------------------------------------------------------------
; Level Slot $09: Death Egg Zone [TO BE ADDED]
ptr_KPLC_DEZ1:	dc.w PLCKosM_LV91-KosMLoadCues ; $09 Act 1
ptr_KPLC_DEZ2:	dc.w PLCKosM_LV92-KosMLoadCues ; $09 Act 2
ptr_KPLC_DEZ3:	dc.w PLCKosM_LV93-KosMLoadCues ; $09 Act 3
ptr_KPLC_DEZ4:	dc.w PLCKosM_LV94-KosMLoadCues ; $09 Act 4
; ---------------------------------------------------------------------------
; Level Slot $0A: Empty
ptr_KPLC_L0AZ1:	dc.w PLCKosM_PP1-KosMLoadCues ; $0A Act 1
ptr_KPLC_L0AZ2:	dc.w PLCKosM_PP2-KosMLoadCues ; $0A Act 2
ptr_KPLC_L0AZ3:	dc.w PLCKosM_PP3-KosMLoadCues ; $0A Act 3
ptr_KPLC_L0AZ4:	dc.w PLCKosM_PP4-KosMLoadCues ; $0A Act 4
; ---------------------------------------------------------------------------
; Level Slot $0B: Empty
ptr_KPLC_L0BZ1:	dc.w PLCKosM_LVB1-KosMLoadCues ; $0B Act 1
ptr_KPLC_L0BZ2:	dc.w PLCKosM_LVB2-KosMLoadCues ; $0B Act 2
ptr_KPLC_L0BZ3:	dc.w PLCKosM_LVB3-KosMLoadCues ; $0B Act 3
ptr_KPLC_L0BZ4:	dc.w PLCKosM_LVB4-KosMLoadCues ; $0B Act 4
; ---------------------------------------------------------------------------
; Level Slot $0C: Empty
ptr_KPLC_L0CZ1:	dc.w PLCKosM_LVC1-KosMLoadCues ; $0C Act 1
ptr_KPLC_L0CZ2:	dc.w PLCKosM_LVC2-KosMLoadCues ; $0C Act 2
ptr_KPLC_L0CZ3:	dc.w PLCKosM_LVC3-KosMLoadCues ; $0C Act 3
ptr_KPLC_L0CZ4:	dc.w PLCKosM_LVC4-KosMLoadCues ; $0C Act 4
; ---------------------------------------------------------------------------
; Level Slot $0D: Empty
ptr_KPLC_L0DZ1:	dc.w PLCKosM_LVD1-KosMLoadCues ; $0D Act 1
ptr_KPLC_L0DZ2:	dc.w PLCKosM_LVD2-KosMLoadCues ; $0D Act 2
ptr_KPLC_L0DZ3:	dc.w PLCKosM_LVD3-KosMLoadCues ; $0D Act 3
ptr_KPLC_L0DZ4:	dc.w PLCKosM_LVD4-KosMLoadCues ; $0D Act 4
; ---------------------------------------------------------------------------
; Level Slot $0E: Empty
ptr_KPLC_L0EZ1:	dc.w PLCKosM_LVE1-KosMLoadCues ; $0E Act 1
ptr_KPLC_L0EZ2:	dc.w PLCKosM_LVE2-KosMLoadCues ; $0E Act 2
ptr_KPLC_L0EZ3:	dc.w PLCKosM_LVE3-KosMLoadCues ; $0E Act 3
ptr_KPLC_L0EZ4:	dc.w PLCKosM_LVE4-KosMLoadCues ; $0E Act 4
; ---------------------------------------------------------------------------
; Level Slot $0F: Empty
ptr_KPLC_L0FZ1:	dc.w PLCKosM_LVF1-KosMLoadCues ; $0F Act 1
ptr_KPLC_L0FZ2:	dc.w PLCKosM_LVF2-KosMLoadCues ; $0F Act 2
ptr_KPLC_L0FZ3:	dc.w PLCKosM_LVF3-KosMLoadCues ; $0F Act 3
ptr_KPLC_L0FZ4:	dc.w PLCKosM_LVF4-KosMLoadCues ; $0F Act 4
; ---------------------------------------------------------------------------
KosMLevelCues_End:
		if KosMLevelCues_End-KosMLoadCues<>LevelActCount*2
			fatal "Kosinski module index must cover every act"
		endif
; Misc. PLC's [May change. Names here are potential entries]
; Note: the ptr names here are temporary.
ptr_KPLC_1:	dc.w PLCKosM_Null-KosMLoadCues ; Cutscene assets
ptr_KPLC_2:	dc.w PLCKosM_Null-KosMLoadCues ; Giant Ring
ptr_KPLC_3:	dc.w PLCKosM_Null-KosMLoadCues ; Boss 1
ptr_KPLC_4:	dc.w PLCKosM_Null-KosMLoadCues ; Boss 2
ptr_KPLC_5:	dc.w PLCKosM_Null-KosMLoadCues ; Boss 3
ptr_KPLC_6:	dc.w PLCKosM_Null-KosMLoadCues ; Boss 4
ptr_KPLC_7:	dc.w PLCKosM_Null-KosMLoadCues ; Special stage results
ptr_KPLC_8:	dc.w PLCKosM_SSBackground-KosMLoadCues ; Level transition patchers
ptr_KPLC_9:	dc.w PLCKosM_SSResult-KosMLoadCues ; Level transition patchers
ptr_KPLC_10:	dc.w PLCKosM_Null-KosMLoadCues ; Level transition patchers
ptr_KPLC_11:	dc.w PLCKosM_Null-KosMLoadCues ; Level transition patchers
ptr_KPLC_12:	dc.w PLCKosM_Null-KosMLoadCues ; Level transition patchers
ptr_KPLC_13:	dc.w PLCKosM_Null-KosMLoadCues ; Level transition patchers
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

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV00 - Twilight Hill Zone
; ---------------------------------------------------------------------------
; Act 1
PLCKosM_THZ1:	plrKosMlistheader
	plreqKosM	ArtTile_Buzz_Bomber, Kospm_Buzz
	plreqKosM	ArtTile_Crabmeat, Kospm_Crabmeat
	plreqKosM	ArtTile_Chopper, Kospm_Chopper
	plreqKosM	ArtTile_Moto_Bug, Kospm_Motobug
;	plreqKosM	ArtTile_Ball_HogV, Kospm_BallhogV ; retired test load
;	plreqKosM	ArtTile_Ball_HogH, Kospm_BallhogH ; retired test load
	plreqKosM	ArtTile_Newtron, Kospm_Newtron
PLCKosM_THZ1_End
; ---------------------------------------------------------------------------
; Act 2
PLCKosM_THZ2:	plrKosMlistheader
	plreqKosM	ArtTile_Buzz_Bomber, Kospm_Buzz
	plreqKosM	ArtTile_Crabmeat, Kospm_Crabmeat
	plreqKosM	ArtTile_Chopper, Kospm_Chopper
	plreqKosM	ArtTile_Moto_Bug, Kospm_Motobug
	plreqKosM	ArtTile_Ball_HogV, Kospm_BallhogV
	plreqKosM	ArtTile_Ball_HogH, Kospm_BallhogH
	plreqKosM	ArtTile_Newtron, Kospm_Newtron
PLCKosM_THZ2_End
; ---------------------------------------------------------------------------
; Act 3
PLCKosM_THZ3:	plrKosMlistheader
	plreqKosM	ArtTile_Buzz_Bomber, Kospm_Buzz
	plreqKosM	ArtTile_Crabmeat, Kospm_Crabmeat
	plreqKosM	ArtTile_Chopper, Kospm_Chopper
	plreqKosM	ArtTile_Moto_Bug, Kospm_Motobug
	plreqKosM	ArtTile_Ball_HogV, Kospm_BallhogV
	plreqKosM	ArtTile_Ball_HogH, Kospm_BallhogH
	plreqKosM	ArtTile_Newtron, Kospm_Newtron
PLCKosM_THZ3_End
; ---------------------------------------------------------------------------
; Act 4
PLCKosM_THZ4:	dc.w -1	; GHZ4 is the sparse object test act; no copied badnik bank
PLCKosM_THZ4_End
; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV01 - Rustic Ruins Zone
; ---------------------------------------------------------------------------
; Act 1
PLCKosM_RRZ1:	plrKosMlistheader
	plreqKosM	ArtTile_LZ_Flapping_Door, Kospm_FlapDoor
	plreqKosM	ArtTile_LZ_Conveyor_Belt, Kospm_LzWheel
;	plreqKosM	ArtTile_Ball_HogV, Kospm_BallhogV ; retired test load
;	plreqKosM	ArtTile_Ball_HogH, Kospm_BallhogH ; retired test load
	plreqKosM	ArtTile_Basaran, Kospm_Basaran
PLCKosM_RRZ1_End
; ---------------------------------------------------------------------------
; Act 2
PLCKosM_RRZ2:	plrKosMlistheader
	plreqKosM	ArtTile_LZ_Flapping_Door, Kospm_FlapDoor
	plreqKosM	ArtTile_LZ_Conveyor_Belt, Kospm_LzWheel
;	plreqKosM	ArtTile_Ball_HogV, Kospm_BallhogV ; retired test load
;	plreqKosM	ArtTile_Ball_HogH, Kospm_BallhogH ; retired test load
	plreqKosM	ArtTile_Basaran, Kospm_Basaran
PLCKosM_RRZ2_End
; ---------------------------------------------------------------------------
; Act 3
PLCKosM_RRZ3:	plrKosMlistheader
	plreqKosM	ArtTile_LZ_Flapping_Door, Kospm_FlapDoor
	plreqKosM	ArtTile_LZ_Conveyor_Belt, Kospm_LzWheel
;	plreqKosM	ArtTile_Ball_HogV, Kospm_BallhogV ; retired test load
;	plreqKosM	ArtTile_Ball_HogH, Kospm_BallhogH ; retired test load
	plreqKosM	ArtTile_Basaran, Kospm_Basaran
PLCKosM_RRZ3_End
; ---------------------------------------------------------------------------
; Act 4
PLCKosM_RRZ4:	plrKosMlistheader
	plreqKosM	ArtTile_LZ_Flapping_Door, Kospm_FlapDoor
	plreqKosM	ArtTile_LZ_Conveyor_Belt, Kospm_LzWheel
;	plreqKosM	ArtTile_Ball_HogV, Kospm_BallhogV ; retired test load
;	plreqKosM	ArtTile_Ball_HogH, Kospm_BallhogH ; retired test load
	plreqKosM	ArtTile_Basaran, Kospm_Basaran
PLCKosM_RRZ4_End
; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV02 - Ancient Workbench Zone
; ---------------------------------------------------------------------------
; Act 1
PLCKosM_AWZ1:	plrKosMlistheader
	plreqKosM	ArtTile_LZ_Flapping_Door, Kospm_FlapDoor
	plreqKosM	ArtTile_MZ_SYZ_Caterkiller, Kospm_Cater
PLCKosM_AWZ1_End
; ---------------------------------------------------------------------------
; Act 2
PLCKosM_AWZ2:	plrKosMlistheader
	plreqKosM	ArtTile_LZ_Flapping_Door, Kospm_FlapDoor
	plreqKosM	ArtTile_MZ_SYZ_Caterkiller, Kospm_Cater
PLCKosM_AWZ2_End
; ---------------------------------------------------------------------------
; Act 3
PLCKosM_AWZ3:	plrKosMlistheader
	plreqKosM	ArtTile_LZ_Flapping_Door, Kospm_FlapDoor
	plreqKosM	ArtTile_MZ_SYZ_Caterkiller, Kospm_Cater
PLCKosM_AWZ3_End
; ---------------------------------------------------------------------------
; Act 4
PLCKosM_AWZ4:	plrKosMlistheader
	plreqKosM	ArtTile_LZ_Flapping_Door, Kospm_FlapDoor
	plreqKosM	ArtTile_MZ_SYZ_Caterkiller, Kospm_Cater
PLCKosM_AWZ4_End
; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV03 - Emerald Hill Zone
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
; LV04 - Crystal Valley Zone
; ---------------------------------------------------------------------------
; Act 1
PLCKosM_CVZ1:	plrKosMlistheader
	plreqKosM	ArtTile_Splats, Kospm_Splats
	plreqKosM	ArtTile_BBat, Kospm_BBat
	plreqKosM	ArtTile_MZ_SYZ_Caterkiller, Kospm_Cater
PLCKosM_CVZ1_End
; ---------------------------------------------------------------------------
; Act 2
PLCKosM_CVZ2:	plrKosMlistheader
	plreqKosM	ArtTile_Splats, Kospm_Splats
	plreqKosM	ArtTile_BBat, Kospm_BBat
	plreqKosM	ArtTile_MZ_SYZ_Caterkiller, Kospm_Cater
PLCKosM_CVZ2_End
; ---------------------------------------------------------------------------
; Act 3
PLCKosM_CVZ3:	plrKosMlistheader
	plreqKosM	ArtTile_Splats, Kospm_Splats
	plreqKosM	ArtTile_BBat, Kospm_BBat
	plreqKosM	ArtTile_MZ_SYZ_Caterkiller, Kospm_Cater
PLCKosM_CVZ3_End
; ---------------------------------------------------------------------------
; Act 4
PLCKosM_CVZ4:	plrKosMlistheader
	plreqKosM	ArtTile_Splats, Kospm_Splats
	plreqKosM	ArtTile_BBat, Kospm_BBat
	plreqKosM	ArtTile_MZ_SYZ_Caterkiller, Kospm_Cater
PLCKosM_CVZ4_End

; ---------------------------------------------------------------------------
; KOSM PATTERN LOAD REQUEST LIST
; LV05 - Egg Mountain Zone
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
; LV06 - Metropolis Zone
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
; LV07 - Shocking Blizzard Zone
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
; LV08 - Scrap Madness Zone
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
; LV09 - Death Egg Zone
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
PLCKosM_SSBackground:	plrKosMlistheader
	plreqKosM	ArtTile_SS_Background_Clouds, Kospm_SSBgCloud		; Clouds
	plreqKosM	ArtTile_SS_Background_Transition, Kospm_SSBgTransition	; opaque transition tiles
	plreqKosM	ArtTile_SS_Up_Down, Kospm_SSUpDown			; UP and DOWN blocks
	plreqKosM	ArtTile_SS_Extra_Life, Kospm_SS1UpBlock			; 1UP block
	plreqKosM	ArtTile_SS_Ghost_Block, Kospm_SSGhost			; ghost block
PLCKosM_SSBackground_End
; ---------------------------------------------------------------------------
; 7
PLCKosM_SSResult:	plrKosMlistheader
	plreqKosM	ArtTile_Mini_Tails, Kospm_MiniTails		; mini Tails
	plreqKosM	ArtTile_Mini_Sonic, Kospm_MiniSonic		; mini Sonic
PLCKosM_SSResult_End
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
; 13

; ---------------------------------------------------------------------------
; Filler/Null entry
PLCKosM_Null:	plrKosMlistheader
	dc.w	$FFFF
PLCKosM_Null_End
; ---------------------------------------------------------------------------
; Moduled Kosinski Pattern IDs
; ---------------------------------------------------------------------------
mkplcid_THZ1:		equ (ptr_KPLC_THZ1-KosMLoadCues)/2		; 0
mkplcid_THZ2:		equ (ptr_KPLC_THZ2-KosMLoadCues)/2		; 1
mkplcid_THZ3:		equ (ptr_KPLC_THZ3-KosMLoadCues)/2		; 2
mkplcid_THZ4:		equ (ptr_KPLC_THZ4-KosMLoadCues)/2		; 3

mkplcid_RRZ1:		equ (ptr_KPLC_RRZ1-KosMLoadCues)/2		; 4
mkplcid_RRZ2:		equ (ptr_KPLC_RRZ2-KosMLoadCues)/2		; 5
mkplcid_RRZ3:		equ (ptr_KPLC_RRZ3-KosMLoadCues)/2		; 6
mkplcid_RRZ4:		equ (ptr_KPLC_RRZ4-KosMLoadCues)/2		; 7

mkplcid_AWZ1:		equ (ptr_KPLC_AWZ1-KosMLoadCues)/2		; 8
mkplcid_AWZ2:		equ (ptr_KPLC_AWZ2-KosMLoadCues)/2		; 9
mkplcid_AWZ3:		equ (ptr_KPLC_AWZ3-KosMLoadCues)/2		; $A
mkplcid_AWZ4:		equ (ptr_KPLC_AWZ4-KosMLoadCues)/2		; $B

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

mkplcid_SBZ1:		equ (ptr_KPLC_SBZ1-KosMLoadCues)/2		; $1C
mkplcid_SBZ2:		equ (ptr_KPLC_SBZ2-KosMLoadCues)/2		; $1D
mkplcid_SBZ3:		equ (ptr_KPLC_SBZ3-KosMLoadCues)/2		; $1E
mkplcid_SBZ4:		equ (ptr_KPLC_SBZ4-KosMLoadCues)/2		; $1F

mkplcid_SMZ1:		equ (ptr_KPLC_SMZ1-KosMLoadCues)/2		; $20
mkplcid_SMZ2:		equ (ptr_KPLC_SMZ2-KosMLoadCues)/2		; $21
mkplcid_SMZ3:		equ (ptr_KPLC_SMZ3-KosMLoadCues)/2		; $22
mkplcid_SMZ4:		equ (ptr_KPLC_SMZ4-KosMLoadCues)/2		; $23

mkplcid_DEZ1:		equ (ptr_KPLC_DEZ1-KosMLoadCues)/2		; $24
mkplcid_DEZ2:		equ (ptr_KPLC_DEZ2-KosMLoadCues)/2		; $25
mkplcid_DEZ3:		equ (ptr_KPLC_DEZ3-KosMLoadCues)/2		; $26
mkplcid_DEZ4:		equ (ptr_KPLC_DEZ4-KosMLoadCues)/2		; $27

; From here on out, unused level slots
mkplcid_L0AZ1:		equ (ptr_KPLC_L0AZ1-KosMLoadCues)/2		; $28
mkplcid_L0AZ2:		equ (ptr_KPLC_L0AZ2-KosMLoadCues)/2		; $29
mkplcid_L0AZ3:		equ (ptr_KPLC_L0AZ3-KosMLoadCues)/2		; $2A
mkplcid_L0AZ4:		equ (ptr_KPLC_L0AZ4-KosMLoadCues)/2		; $2B

mkplcid_L0BZ1:		equ (ptr_KPLC_L0BZ1-KosMLoadCues)/2		; $2C
mkplcid_L0BZ2:		equ (ptr_KPLC_L0BZ2-KosMLoadCues)/2		; $2D
mkplcid_L0BZ3:		equ (ptr_KPLC_L0BZ3-KosMLoadCues)/2		; $2E
mkplcid_L0BZ4:		equ (ptr_KPLC_L0BZ4-KosMLoadCues)/2		; $2F

mkplcid_L0CZ1:		equ (ptr_KPLC_L0CZ1-KosMLoadCues)/2		; $30
mkplcid_L0CZ2:		equ (ptr_KPLC_L0CZ2-KosMLoadCues)/2		; $31
mkplcid_L0CZ3:		equ (ptr_KPLC_L0CZ3-KosMLoadCues)/2		; $32
mkplcid_L0CZ4:		equ (ptr_KPLC_L0CZ4-KosMLoadCues)/2		; $33

mkplcid_L0DZ1:		equ (ptr_KPLC_L0DZ1-KosMLoadCues)/2		; $34
mkplcid_L0DZ2:		equ (ptr_KPLC_L0DZ2-KosMLoadCues)/2		; $35
mkplcid_L0DZ3:		equ (ptr_KPLC_L0DZ3-KosMLoadCues)/2		; $36
mkplcid_L0DZ4:		equ (ptr_KPLC_L0DZ4-KosMLoadCues)/2		; $37

mkplcid_L0EZ1:		equ (ptr_KPLC_L0EZ1-KosMLoadCues)/2		; $38
mkplcid_L0EZ2:		equ (ptr_KPLC_L0EZ2-KosMLoadCues)/2		; $39
mkplcid_L0EZ3:		equ (ptr_KPLC_L0EZ3-KosMLoadCues)/2		; $3A
mkplcid_L0EZ4:		equ (ptr_KPLC_L0EZ4-KosMLoadCues)/2		; $3B

mkplcid_L0FZ1:		equ (ptr_KPLC_L0FZ1-KosMLoadCues)/2		; $3C
mkplcid_L0FZ2:		equ (ptr_KPLC_L0FZ2-KosMLoadCues)/2		; $3D
mkplcid_L0FZ3:		equ (ptr_KPLC_L0FZ3-KosMLoadCues)/2		; $3E
mkplcid_L0FZ4:		equ (ptr_KPLC_L0FZ4-KosMLoadCues)/2		; $3F

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
mkplcid_Misc13:		equ (ptr_KPLC_13-KosMLoadCues)/2		; $4C

; Independent empty Kosinski module lists; ready for act-specific imports.
PLCKosM_EHZ1: dc.w -1
PLCKosM_EHZ2: dc.w -1
PLCKosM_EHZ3: dc.w -1
PLCKosM_EHZ4: dc.w -1
PLCKosM_HTZ1: dc.w -1
PLCKosM_HTZ2: dc.w -1
PLCKosM_HTZ3: dc.w -1
PLCKosM_HTZ4: dc.w -1
PLCKosM_LV61: dc.w -1
PLCKosM_LV62: dc.w -1
PLCKosM_LV63: dc.w -1
PLCKosM_LV64: dc.w -1
PLCKosM_LV71: dc.w -1
PLCKosM_LV72: dc.w -1
PLCKosM_LV73: dc.w -1
PLCKosM_LV74: dc.w -1
PLCKosM_SMZ1: dc.w -1
PLCKosM_SMZ2: dc.w -1
PLCKosM_SMZ3: dc.w -1
PLCKosM_SMZ4: dc.w -1
PLCKosM_LV91: dc.w -1
PLCKosM_LV92: dc.w -1
PLCKosM_LV93: dc.w -1
PLCKosM_LV94: dc.w -1
PLCKosM_PP1: dc.w -1
PLCKosM_PP2: dc.w -1
PLCKosM_PP3: dc.w -1
PLCKosM_PP4: dc.w -1
PLCKosM_LVB1: dc.w -1
PLCKosM_LVB2: dc.w -1
PLCKosM_LVB3: dc.w -1
PLCKosM_LVB4: dc.w -1
PLCKosM_LVC1: dc.w -1
PLCKosM_LVC2: dc.w -1
PLCKosM_LVC3: dc.w -1
PLCKosM_LVC4: dc.w -1
PLCKosM_LVD1: dc.w -1
PLCKosM_LVD2: dc.w -1
PLCKosM_LVD3: dc.w -1
PLCKosM_LVD4: dc.w -1
PLCKosM_LVE1: dc.w -1
PLCKosM_LVE2: dc.w -1
PLCKosM_LVE3: dc.w -1
PLCKosM_LVE4: dc.w -1
PLCKosM_LVF1: dc.w -1
PLCKosM_LVF2: dc.w -1
PLCKosM_LVF3: dc.w -1
PLCKosM_LVF4: dc.w -1
