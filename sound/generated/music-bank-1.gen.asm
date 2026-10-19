SndMus1_Start:	startBank
Mus_LBZ2_S3:	include "sound/music/LBZ2 S3.asm" ; $23F3 bytes
Mus_GRGZ2:	include "sound/music/GreenGZ2.asm" ; $16D5 bytes
Mus_Credits:	include "sound/music/Credits.asm" ; $1294 bytes
Mus_Test6:	include "sound/music/45.asm" ; $119C bytes
Mus_RRZ1:	include "sound/music/RRZ1.asm" ; $1158 bytes
Mus_RRZ2:	include "sound/music/RRZ2.asm" ; $D84 bytes
Mus_Boss:	BINCLUDE "sound/music/../generated/Boss_cmp.bin" ; $217 bytes
SndMus1_DataEnd:
	SoundBankAssets Music,1
	finishBank
