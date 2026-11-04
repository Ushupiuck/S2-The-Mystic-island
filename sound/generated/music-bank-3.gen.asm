SndMus3_Start:	startBank
Mus_EndBoss:	BINCLUDE "sound/music/../generated/EndBoss_cmp.bin" ; $2CA bytes
Mus_SuperSonic:	BINCLUDE "sound/music/../generated/SuperSonic_cmp.bin" ; $2B9 bytes
Mus_BonusStage:	BINCLUDE "sound/music/../generated/BonusStage_cmp.bin" ; $273 bytes
Mus_Ending_S1:	BINCLUDE "sound/music/../generated/Ending_S1_cmp.bin" ; $24C bytes
Mus_HPZ:	BINCLUDE "sound/music/../generated/HPZ_cmp.bin" ; $207 bytes
Mus_Title:	BINCLUDE "sound/music/../generated/Title_cmp.bin" ; $1CA bytes
Mus_Invincible:	BINCLUDE "sound/music/../generated/Invincible_cmp.bin" ; $191 bytes
Mus_Continue:	BINCLUDE "sound/music/../generated/Continue_cmp.bin" ; $15A bytes
Mus_GameOver:	include "sound/music/Game over.asm" ; $14F bytes
Mus_DoubleLife:	include "sound/music/Double Life.asm" ; $128 bytes
Mus_Countdown:	BINCLUDE "sound/music/../generated/Countdown_cmp.bin" ; $11F bytes
Mus_EndLevel:	BINCLUDE "sound/music/../generated/EndLevel_cmp.bin" ; $115 bytes
Mus_Emerald:	BINCLUDE "sound/music/../generated/Emerald_cmp.bin" ; $CB bytes
Mus_ExtraLife:	BINCLUDE "sound/music/../generated/ExtraLife_cmp.bin" ; $B7 bytes
SndMus3_DataEnd:
	SoundBankAssets Music,3
	finishBank
