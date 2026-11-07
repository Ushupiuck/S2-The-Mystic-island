; Called after each bank's audio data, before finishBank checks the boundary.
; This file is hand-edited; KEHmusic never regenerates it. Keep each payload
; within that bank's remaining space. kind is Music, DAC or SFX; bank is 1-based.
SoundBankAssets macro kind,bank,{GLOBALSYMBOLS}
	if ("kind"="Music")&&(bank=3)
		even
Nem_SegaLogo:	binclude "art/nemesis/Sega Logo (JP1).nem"
		even
Nem_HUD:	binclude "art/nemesis/HUD.nem"
		even
	endif
	endm
