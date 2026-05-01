; ------------------------------------------------------------------------------
; Music bank 1
; ------------------------------------------------------------------------------
SndMus1_Start:	startBank

Mus_LBZ2_S3:	include "sound/music/LBZ2 S3.asm" ; $23F3 bytes
Mus_GRGZ2:	include "sound/music/GreenGZ2.asm" ; $1719 bytes
Mus_Credits:	include "sound/music/Credits.asm" ; $1294 bytes
Mus_Test6:	include "sound/music/45.asm" ; $119C bytes
Mus_RRZ1:	include "sound/music/RRZ1.asm" ; $1158 bytes
Mus_RRZ2:	include "sound/music/RRZ2.asm" ; $D84 bytes
Mus_Title:	BINCLUDE "sound/music/Title screen_cmp.bin" ; $1CA bytes

	finishBank

; ------------------------------------------------------------------------------
; Music bank 2
; ------------------------------------------------------------------------------
SndMus2_Start:	startBank

Mus_GRGZ1:	include "sound/music/GreenGZ1.asm" ; $114A bytes
Mus_BonusStage3:	include "sound/music/Gumball Machine.asm" ; $D15 bytes
Mus_LBZ1_S3:	include "sound/music/LBZ1 S3.asm" ; $CDB bytes
Mus_DDZ2:	include "sound/music/DDZ2.asm" ; $B7A bytes
Mus_DDZ1:	include "sound/music/DDZ1.asm" ; $B0C bytes
Mus_ALZ:	include "sound/music/Azure Lake.asm" ; $AFE bytes
Mus_BonusStage2:	include "sound/music/Slots.asm" ; $AE8 bytes
Mus_Test7:	include "sound/music/46.asm" ; $AB4 bytes
Mus_GGZ1:	include "sound/music/GGZ1.asm" ; $A70 bytes
Mus_Credits_2:	include "sound/music/S3 Beta - Ending.asm" ; $A6E bytes
Mus_PPZ1:	BINCLUDE "sound/music/PPZ1_cmp.bin" ; $62F bytes
Mus_BonusStage:	BINCLUDE "sound/music/Bonus Stage_cmp.bin" ; $273 bytes

	finishBank

; ------------------------------------------------------------------------------
; Music bank 3
; ------------------------------------------------------------------------------
SndMus3_Start:	startBank

Mus_ARZ:	BINCLUDE "sound/music/ARZ_cmp.bin" ; $609 bytes
Mus_GHZ:	BINCLUDE "sound/music/GHZ_cmp.bin" ; $5AA bytes
Mus_GGZ2:	BINCLUDE "sound/music/GGZ2_cmp.bin" ; $552 bytes
Mus_EHZ:	BINCLUDE "sound/music/EHZ_cmp.bin" ; $518 bytes
Mus_Ending_S2:	BINCLUDE "sound/music/Ending - S2 DEZ Outro_cmp.bin" ; $4E8 bytes
Mus_SBZ:	BINCLUDE "sound/music/SBZ_cmp.bin" ; $4D7 bytes
Mus_Boss2:	BINCLUDE "sound/music/Boss 2_cmp.bin" ; $478 bytes
Mus_PPZ2:	BINCLUDE "sound/music/PPZ2_cmp.bin" ; $46E bytes
Mus_Options:	BINCLUDE "sound/music/Menu_cmp.bin" ; $44E bytes
Mus_CPZ:	BINCLUDE "sound/music/CPZ_cmp.bin" ; $434 bytes
Mus_LZ:	BINCLUDE "sound/music/LZ_cmp.bin" ; $3D9 bytes
Mus_SpecialStage:	BINCLUDE "sound/music/Special Stage_cmp.bin" ; $3D9 bytes
Mus_OOZ:	BINCLUDE "sound/music/OOZ_cmp.bin" ; $3D5 bytes
Mus_CNZ_2P:	BINCLUDE "sound/music/CNZ 2P_cmp.bin" ; $3CE bytes
Mus_2PResult:	BINCLUDE "sound/music/Results screen 2P_cmp.bin" ; $3B4 bytes
Mus_EHZ_2P:	BINCLUDE "sound/music/EHZ 2P_cmp.bin" ; $3AA bytes
Mus_TestSong1:	BINCLUDE "sound/music/Egg_Utopia_cmp.bin" ; $390 bytes
Mus_MTZ:	BINCLUDE "sound/music/MTZ_cmp.bin" ; $37D bytes
Mus_DEZ:	BINCLUDE "sound/music/DEZ_cmp.bin" ; $37B bytes
Mus_HTZ:	BINCLUDE "sound/music/HTZ_cmp.bin" ; $35E bytes
Mus_ICZ2:	BINCLUDE "sound/music/ICZ2_cmp.bin" ; $344 bytes
Mus_Boss3:	BINCLUDE "sound/music/Boss 3_cmp.bin" ; $33A bytes
Mus_SCZ:	BINCLUDE "sound/music/SCZ_cmp.bin" ; $326 bytes
Mus_ICZ1:	BINCLUDE "sound/music/ICZ1_cmp.bin" ; $31F bytes
Mus_SW_HPZ:	BINCLUDE "sound/music/SW_HPZ_cmp.bin" ; $317 bytes
Mus_EndBoss:	BINCLUDE "sound/music/Final Boss_cmp.bin" ; $2CA bytes
Mus_SuperSonic:	BINCLUDE "sound/music/Super Sonic_cmp.bin" ; $2B9 bytes
Mus_Ending_S1:	BINCLUDE "sound/music/Ending - S1 GHZ Outro_cmp.bin" ; $24C bytes
Mus_Boss:	BINCLUDE "sound/music/Boss_cmp.bin" ; $217 bytes
Mus_HPZ:	BINCLUDE "sound/music/HPZ_cmp.bin" ; $207 bytes
Mus_Invincible:	BINCLUDE "sound/music/Invincible_cmp.bin" ; $191 bytes
Mus_Continue:	BINCLUDE "sound/music/Continue_cmp.bin" ; $15A bytes
Mus_GameOver:	include "sound/music/Game over.asm" ; $14F bytes
Mus_DoubleLife:	include "sound/music/Double life.asm" ; $12A bytes
Mus_Countdown:	BINCLUDE "sound/music/Drowning_cmp.bin" ; $11F bytes
Mus_EndLevel:	BINCLUDE "sound/music/End of level_cmp.bin" ; $115 bytes
Mus_Emerald:	BINCLUDE "sound/music/Got emerald_cmp.bin" ; $CB bytes
Mus_ExtraLife:	BINCLUDE "sound/music/Extra life_cmp.bin" ; $B7 bytes

	finishBank

