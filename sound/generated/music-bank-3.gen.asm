SndMus3_Start:	startBank
Mus_DoubleLife:	BINCLUDE "sound/music/../generated/DoubleLife_cmp.bin" ; $114 bytes
Mus_Countdown:	BINCLUDE "sound/music/../generated/Countdown_cmp.bin" ; $105 bytes
Mus_EndLevel:	BINCLUDE "sound/music/../generated/EndLevel_cmp.bin" ; $100 bytes
Mus_ExtraLife:	BINCLUDE "sound/music/../generated/ExtraLife_cmp.bin" ; $AF bytes
SndMus3_DataEnd:
	SoundBankAssets Music,3
	finishBank
