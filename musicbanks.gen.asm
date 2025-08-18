; ------------------------------------------------------------------------------
; Music bank 1
; ------------------------------------------------------------------------------
SndMus1_Start:	startBank

Mus_Credits:	include "sound/music/Credits.asm" ; $16DE bytes
Mus_Test_Electoria:	BINCLUDE "sound/music/New - Electoria_cmp.bin" ; $614 bytes
Mus_ARZ:	BINCLUDE "sound/music/ARZ_cmp.bin" ; $609 bytes
Mus_GHZ:	BINCLUDE "sound/music/GHZ_cmp.bin" ; $5AA bytes
Mus_EHZ:	BINCLUDE "sound/music/EHZ_cmp.bin" ; $518 bytes
Mus_Ending:	BINCLUDE "sound/music/Ending_cmp.bin" ; $4E8 bytes
Mus_CNZ:	BINCLUDE "sound/music/CNZ_cmp.bin" ; $4E1 bytes
Mus_SBZ:	BINCLUDE "sound/music/SBZ_cmp.bin" ; $4D7 bytes
Mus_Test_Hyper_Hyper:	BINCLUDE "sound/music/New - Hyper-Hyper_cmp.bin" ; $449 bytes
Mus_CPZ:	BINCLUDE "sound/music/CPZ_cmp.bin" ; $434 bytes
Mus_MCZ:	BINCLUDE "sound/music/MCZ_cmp.bin" ; $428 bytes
Mus_SpecStage:	BINCLUDE "sound/music/Special Stage_cmp.bin" ; $3D9 bytes
Mus_OOZ:	BINCLUDE "sound/music/OOZ_cmp.bin" ; $3D5 bytes
Mus_CNZ_2P:	BINCLUDE "sound/music/CNZ 2P_cmp.bin" ; $3CE bytes
Mus_Test_Evening_Star:	BINCLUDE "sound/music/New - Evening star_cmp.bin" ; $3CD bytes
Mus_2PResult:	BINCLUDE "sound/music/Results screen 2P_cmp.bin" ; $3B4 bytes
Mus_EHZ_2P:	BINCLUDE "sound/music/EHZ 2P_cmp.bin" ; $3AA bytes
Mus_MTZ:	BINCLUDE "sound/music/MTZ_cmp.bin" ; $37D bytes
Mus_DEZ:	BINCLUDE "sound/music/DEZ_cmp.bin" ; $37B bytes
Mus_HTZ:	BINCLUDE "sound/music/HTZ_cmp.bin" ; $35E bytes
Mus_WFZ:	BINCLUDE "sound/music/WFZ_cmp.bin" ; $348 bytes
Mus_MCZ_2P:	BINCLUDE "sound/music/MCZ 2P_cmp.bin" ; $348 bytes
Mus_SCZ:	BINCLUDE "sound/music/SCZ_cmp.bin" ; $326 bytes
Mus_SW_HPZ:	BINCLUDE "sound/music/SW_HPZ_cmp.bin" ; $317 bytes
Mus_Test_Moonrise:	BINCLUDE "sound/music/New - Moonrise_cmp.bin" ; $307 bytes
Mus_Test_Walkin:	BINCLUDE "sound/music/New - Walkin_cmp.bin" ; $2CB bytes
Mus_EndBoss:	BINCLUDE "sound/music/Final Boss_cmp.bin" ; $2CA bytes

	finishBank

; ------------------------------------------------------------------------------
; Music bank 2
; ------------------------------------------------------------------------------
SndMus2_Start:	startBank

Mus_SuperSonic:	BINCLUDE "sound/music/Super Sonic_cmp.bin" ; $2B9 bytes
Mus_Boss:	BINCLUDE "sound/music/Boss_cmp.bin" ; $250 bytes
Mus_HPZ:	BINCLUDE "sound/music/HPZ_cmp.bin" ; $207 bytes
Mus_Title:	BINCLUDE "sound/music/Title screen_cmp.bin" ; $1CA bytes
Mus_Invincible:	BINCLUDE "sound/music/Invincible_cmp.bin" ; $191 bytes
Mus_Options:	include "sound/music/Options.asm" ; $17B bytes
Mus_Continue:	BINCLUDE "sound/music/Continue_cmp.bin" ; $15A bytes
Mus_GameOver:	include "sound/music/Game over.asm" ; $14F bytes
Mus_Countdown:	BINCLUDE "sound/music/Drowning_cmp.bin" ; $11F bytes
Mus_EndLevel:	BINCLUDE "sound/music/End of level_cmp.bin" ; $115 bytes
Mus_Emerald:	BINCLUDE "sound/music/Got emerald_cmp.bin" ; $CB bytes
Mus_ExtraLife:	BINCLUDE "sound/music/Extra life_cmp.bin" ; $B7 bytes

	finishBank

