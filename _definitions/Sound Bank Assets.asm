; Called after each bank's audio data, before finishBank checks the boundary.
; This hook is hand-edited; the sound tools never regenerate it.
; kind is DAC or SFX; bank is 1-based.
SoundBankAssets macro kind,bank,{GLOBALSYMBOLS}
	endm
