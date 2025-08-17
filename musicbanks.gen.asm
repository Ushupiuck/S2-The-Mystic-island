; ------------------------------------------------------------------------------
; Music bank 1
; ------------------------------------------------------------------------------
SndMus1_Start:	startBank

Mus_Credits:	include "sound/music/Credits.asm" ; $16E0 bytes
Mus_ARZ:	BINCLUDE "sound/music/ARZ_cmp.bin" ; $609 bytes
Mus_GHZ:	BINCLUDE "sound/music/Mus81 - GHZ_cmp.bin" ; $5AA bytes
Mus_EHZ:	BINCLUDE "sound/music/EHZ_cmp.bin" ; $518 bytes
Mus_Ending:	BINCLUDE "sound/music/Ending_cmp.bin" ; $4E8 bytes
Mus_CNZ:	BINCLUDE "sound/music/CNZ_cmp.bin" ; $4E1 bytes
Mus_CPZ:	BINCLUDE "sound/music/CPZ_cmp.bin" ; $434 bytes
Mus_MCZ:	BINCLUDE "sound/music/MCZ_cmp.bin" ; $428 bytes
Mus_SpecStage:	BINCLUDE "sound/music/SpecStg_cmp.bin" ; $3D9 bytes
Mus_OOZ:	BINCLUDE "sound/music/OOZ_cmp.bin" ; $3D5 bytes
Mus_CNZ_2P:	BINCLUDE "sound/music/CNZ_2p_cmp.bin" ; $3CE bytes
Mus_2PResult:	BINCLUDE "sound/music/Results screen 2p_cmp.bin" ; $3B4 bytes
Mus_EHZ_2P:	BINCLUDE "sound/music/EHZ_2p_cmp.bin" ; $3AA bytes
Mus_MTZ:	BINCLUDE "sound/music/MTZ_cmp.bin" ; $37D bytes
Mus_DEZ:	BINCLUDE "sound/music/DEZ_cmp.bin" ; $37B bytes
Mus_HTZ:	BINCLUDE "sound/music/HTZ_cmp.bin" ; $35E bytes
Mus_MCZ_2P:	BINCLUDE "sound/music/MCZ_2p_cmp.bin" ; $348 bytes
Mus_WFZ:	BINCLUDE "sound/music/WFZ_cmp.bin" ; $348 bytes
Mus_SCZ:	BINCLUDE "sound/music/SCZ_cmp.bin" ; $326 bytes
Mus_EndBoss:	BINCLUDE "sound/music/End_Boss_cmp.bin" ; $2CA bytes
Mus_SuperSonic:	BINCLUDE "sound/music/Supersonic_cmp.bin" ; $2B9 bytes
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

