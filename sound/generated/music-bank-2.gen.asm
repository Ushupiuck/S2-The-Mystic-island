SndMus2_Start:	startBank
Mus_GRGZ1:	include "sound/music/GreenGZ1.asm" ; $114A bytes
Mus_BonusStage3:	include "sound/music/Gumball Machine.asm" ; $D15 bytes
Mus_LBZ1_S3:	include "sound/music/LBZ1 S3.asm" ; $CDB bytes
Mus_DDZ2:	include "sound/music/DDZ2.asm" ; $B78 bytes
Mus_ALZ:	include "sound/music/Azure Lake.asm" ; $AFE bytes
Mus_DDZ1:	include "sound/music/DDZ1.asm" ; $AF2 bytes
Mus_BonusStage2:	include "sound/music/Slots.asm" ; $AE8 bytes
Mus_Test7:	include "sound/music/46.asm" ; $AB4 bytes
Mus_GGZ1:	include "sound/music/GGZ1.asm" ; $A70 bytes
Mus_Credits_2:	include "sound/music/S3 Beta - Ending.asm" ; $A6E bytes
Mus_PPZ1:	BINCLUDE "sound/music/../generated/PPZ1_cmp.bin" ; $62D bytes
Mus_BonusStage:	BINCLUDE "sound/music/../generated/BonusStage_cmp.bin" ; $273 bytes
SndMus2_DataEnd:
	SoundBankAssets Music,2
	finishBank
