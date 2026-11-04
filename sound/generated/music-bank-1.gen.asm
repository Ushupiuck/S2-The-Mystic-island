SndMus1_Start:	startBank
Mus_Credits:	include "sound/music/Credits.asm" ; $1294 bytes
Mus_GRGZ2:	include "sound/music/GreenGZ2.asm" ; $10C1 bytes
Mus_GRGZ1:	include "sound/music/GreenGZ1.asm" ; $F76 bytes
Mus_LBZ2_S3:	include "sound/music/LBZ2 S3.asm" ; $EE2 bytes
Mus_BonusStage3:	include "sound/music/Gumball Machine.asm" ; $B16 bytes
Mus_DDZ2:	BINCLUDE "sound/music/../generated/DDZ2_cmp.bin" ; $751 bytes
Mus_DDZ1:	BINCLUDE "sound/music/../generated/DDZ1_cmp.bin" ; $668 bytes
Mus_Test6:	BINCLUDE "sound/music/../generated/Test6_cmp.bin" ; $61F bytes
Mus_RRZ1:	BINCLUDE "sound/music/../generated/RRZ1_cmp.bin" ; $615 bytes
Mus_RRZ2:	BINCLUDE "sound/music/../generated/RRZ2_cmp.bin" ; $611 bytes
Mus_Credits_2:	BINCLUDE "sound/music/../generated/Credits_2_cmp.bin" ; $5E3 bytes
Mus_GGZ1:	BINCLUDE "sound/music/../generated/GGZ1_cmp.bin" ; $5AA bytes
Mus_PPZ1:	BINCLUDE "sound/music/../generated/PPZ1_cmp.bin" ; $57D bytes
Mus_BonusStage:	BINCLUDE "sound/music/../generated/BonusStage_cmp.bin" ; $231 bytes
SndMus1_DataEnd:
	SoundBankAssets Music,1
	finishBank
