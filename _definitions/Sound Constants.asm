; CloneDriver v2.8.0.1, upstream f9723d683bcc304afb7a1fb5d1278592451fd274.
; FM/PSG music executes on the MD main 68000. DAC and SFX execute on Z80.
SMPS_GloopSFXBehaviour = 0
SMPS_PushSFXBehaviour = 0
SMPS_EnableSpecSFX = 0
SMPS_EnableSpinDashSFX = 0
SMPS_EnableContSFX = 0
SMPS_First_ContSFX = $BC
SMPS_IdlingSegaSound = 0
SMPS_EnableUniversalVoiceBank = 0
SMPS_EnablePlaySoundLocal = 0
SMPS_EnableModulationEnvelopes = 0
SMPS_IsOn32X = 0
SMPS_EnablePWM = 0
SMPS_SoundTest = 0
SMPS_S1PSGEnvelopes = 0
SMPS_S2PSGEnvelopes = 1
SMPS_S3PSGEnvelopes = 0
SMPS_SKPSGEnvelopes = 0
SMPS_S3DPSGEnvelopes = 0
SMPS_KCPSGEnvelopes = 0
SMPS_S28BitPSGEnvelopes = 0
	include "sound/CloneDriver/engine/Macros.asm"
	include "sound/CloneDriver/engine/RAM.asm"
	include "sound/CloneDriver/engine/Constants.asm"

Sound_MusicBufferCapacity = $4000
Sound_MusicEntry STRUCT DOTS
	Source: ds.l 1
	StoredSize: ds.w 1
	DecodedSize: ds.w 1
	Flags: ds.b 1
	Reserved: ds.b 1
Sound_MusicEntry ENDSTRUCT
Sound_MusicCompressed = 0
Sound_MusicNoSpeedUp = 5
Sound_MusicPAL = 6
Sound_MusicJingle = 7
