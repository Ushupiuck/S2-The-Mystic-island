; DAC streaming and FM/PSG sound effects, derived from the project's KeH Z80 driver.
; Music sequencing and decompression belong to the MD 68000 / Mega-CD service.
; Original disassembly: Xenowhirl, RAS, Flamewing; KeH adaptations: MainMemory.
zTrack STRUCT DOTS
	; 	"playback control"; bits:
	; 	1 (02h): seems to be "track is at rest"
	; 	2 (04h): SFX is overriding this track
	; 	3 (08h): modulation on
	; 	4 (10h): do not attack next note
	; 	7 (80h): track is playing
	PlaybackControl:	ds.b 1
	; 	"voice control"; bits:
	; 	2 (04h): If set, bound for part II, otherwise 0 (see zWriteFMIorII)
	; 		-- bit 2 has to do with sending key on/off, which uses this differentiation bit directly
	; 	7 (80h): PSG Track
	VoiceControl:		ds.b 1
	TempoDivider:		ds.b 1	; timing divisor; 1 = Normal, 2 = Half, 3 = Third...
	DataPointerLow:		ds.b 1	; Track's position low byte
	DataPointerHigh:	ds.b 1	; Track's position high byte
	Transpose:		ds.b 1	; Transpose (from coord flag E9)
	Volume:			ds.b 1	; channel volume (only ap plied at voice changes)
	AMSFMSPan:		ds.b 1	; Panning / AMS / FMS settings
	VoiceIndex:		ds.b 1	; Current voice in use OR current PSG tone
	VolFlutter:		ds.b 1	; PSG flutter (dynamically effects PSG volume for decay effects)
	StackPointer:		ds.b 1	; Return-stack offset, initialized to zTrack.GoSubStack; calls subtract two
	DurationTimeout:	ds.b 1	; current duration timeout; counting down to zero
	SavedDuration:		ds.b 1	; last set duration (if a note follows a note, this is reapplied to 0Bh)
	;
	; 	; 0Dh / 0Eh change a little depending on track -- essentially they hold data relevant to the next note to play
	SavedDAC:			; DAC: Next drum to play
	FreqLow:		ds.b 1	; FM/PSG: frequency low byte
	FreqHigh:		ds.b 1	; FM/PSG: frequency high byte
	NoteFillTimeout:	ds.b 1	; Currently set note fill; counts down to zero and then cuts off note
	NoteFillMaster:		ds.b 1	; Reset value for current note fill
	ModulationPtrLow:	ds.b 1	; low byte of address of current modulation setting
	ModulationPtrHigh:	ds.b 1	; high byte of address of current modulation setting
	ModulationWait:		ds.b 1	; Wait for ww period of time before modulation starts
	ModulationSpeed:	ds.b 1	; Modulation Speed
	ModulationDelta:	ds.b 1	; Modulation change per Mod. Step
	ModulationSteps:	ds.b 1	; Number of steps in modulation (divided by 2)
	ModulationValLow:	ds.b 1	; Current modulation value low byte
	ModulationValHigh:	ds.b 1	; Current modulation value high byte
	Detune:			ds.b 1	; Set by detune coord flag E1; used to add directly to FM/PSG frequency
	VolTLMask:		ds.b 1	; zVolTLMaskTbl value set during voice setting (value based on algorithm indexing zGain table)
	PSGNoise:		ds.b 1	; PSG noise setting
	VoicePtrLow:		ds.b 1	; low byte of custom voice table (for SFX)
	VoicePtrHigh:		ds.b 1	; high byte of custom voice table (for SFX)
	LoopCounters:		ds.b $A	; Loop counter index 0
	GoSubStack:			; End of the shared ten-byte counter/return area.
	; Counters grow upward; two-byte return addresses grow downward. Never
	; use a counter occupied by an active return address.
zTrack ENDSTRUCT

zVar STRUCT DOTS
	SFXPriorityVal: ds.b 1
	StopMusic: ds.b 1
	Communication: ds.b 1
	DACUpdating: ds.b 1
	SoundQueueStart:
	QueueToPlay: ds.b 1
	SFXToPlay: ds.b 1
	SFXStereoToPlay: ds.b 1
	SFXUnknown: ds.b 1
	SoundQueueEnd:
	1upPlaying: ds.b 1
	FadeInFlag: ds.b 1
	MusicDACRequest: ds.b 1
	MusicDACPan: ds.b 1
	StopDAC: ds.b 1
	MDLock: ds.b 1
	FMBusy: ds.b 1
zVar ENDSTRUCT
zYM2612_A0 = $4000
zYM2612_D0 = $4001
zYM2612_A1 = $4002
zYM2612_D1 = $4003
zBankRegister = $6000
zPSG = $7F11
zROMWindow = $8000
zStack = $1D00
	phase zStack+$20
zAbsVar: zVar
zTracksSFXStart:
zSFX_FMStart:
zSFX_FM3: zTrack
zSFX_FM4: zTrack
zSFX_FM5: zTrack
zSFX_FMEnd:
zSFX_PSGStart:
zSFX_PSG1: zTrack
zSFX_PSG2: zTrack
zSFX_PSG3: zTrack
zSFX_PSGEnd:
zTracksSFXEnd:
	if zTracksSFXEnd>$2000
		fatal "Z80 SFX state exceeds RAM"
	endif
	dephase
SFX_TRACK_COUNT = (zTracksSFXEnd-zTracksSFXStart)/zTrack.len
SFX_FM_TRACK_COUNT = (zSFX_FMEnd-zSFX_FMStart)/zTrack.len
SFX_PSG_TRACK_COUNT = (zSFX_PSGEnd-zSFX_PSGStart)/zTrack.len
	!org	0 ; Z80 code at address 0 is compressed by p2bin's -z=0 pass

	CPU	Z80UNDOC
	listing	purecode

zmake68kBank function addr,(((addr&3F8000h)/zROMWindow))

; macro to make a certain error message clearer should you happen to get it...
rsttarget macro {INTLABEL}
	if ($&7)||($>38h)
		fatal "Function __LABEL__ is at 0\{$}h, but must be at a multiple of 8 bytes <= 38h to be used with the rst instruction."
	endif
	if "__LABEL__"<>""
__LABEL__ label $
	endif
	endm

; function to decide whether an offset's full range won't fit in one byte
offsetover1byte function from,maxsize, ((from&0FFh)>(100h-maxsize))

; macro to make sure that ($ & 0FF00h) == (($+maxsize) & 0FF00h)
ensure1byteoffset macro maxsize
	if offsetover1byte($,maxsize)
startpad := $
		align 100h
		if	MOMPASS=1
endpad := $
		if endpad-startpad>=1h
			; warn because otherwise you'd have no clue why you're running out of space so fast
			warning "had to insert \{endpad-startpad}h   bytes of padding before improperly located data at 0\{startpad}h in Z80 code"
		endif
		endif
	endif
	endm

; function to turn a 68k address into a word the Z80 can use to access it,
; assuming the correct bank has been switched to first
zmake68kPtr function addr,zROMWindow+(addr&7FFFh)


; >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Z80 'ROM' start:
;zEntryPoint:
	di	; disable interrupts
	ld	sp,zStack
	jp	zInitialiseDriver
; ---------------------------------------------------------------------------
; zbyte_7:
zPalModeByte:
	db	0

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||
	align	8
;zsub_10
zWriteFMIorII:    rsttarget
	bit	2,(ix+zTrack.VoiceControl)
	jp	nz, zWriteFMII
	nop
; End of function zWriteFMIorII

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||
	align	8
;zsub_18
zWriteFMI:    rsttarget
	; Write reg/data pair to part I; 'a' is register, 'c' is data
	ld	(iy+0),a
	ld	(iy+1),c
	ret
; End of function zWriteFMI


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||
	align	8
;zsub_28
zWriteFMII:    rsttarget
	; Write reg/data pair to part II; 'a' is register, 'c' is data
	ld	(iy+2),a
	ld	(iy+3),c
	ret
; End of function zWriteFMII

zSpindashPlayingCounter:	db 0 ; zbyte_1304

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||
	align	8
zDACEnabled:	db 0
zHighPriorityDACPlaying:	db 0
zDACSFXPlaying:	db 0

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||
	align	8
zBankSwitchToSFX:    rsttarget
	ld	a,zmake68kBank(SoundIndex)
	jr	zBankSwitch
; End of function zBankSwitchToSFX

zCurDAC:	db 0 ; zbyte_12FF ; seems to indicate DAC sample playing status
zCurPCMBnk:	     ; shared wtih zDoSFXFlag
zDoSFXFlag:	db 0 ; zbyte_1301 ; Flag to indicate we're updating SFX (and thus use custom voice table); set to FFh while doing SFX, 0 when not.
zSpindashExtraFrequencyIndex:	db 0 ; zbyte_1305

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||
	align	8
; zsub_C63:
zBankSwitch:    rsttarget
	ld	hl, zBankRegister
	ld	(hl), a
	jp	zBankSwitchPart2
; End of function zBankSwitch

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||
	org	38h
zVInt: rsttarget
	push af
	push bc
	push de
	push hl
	call zEnterFMSection
	rst zBankSwitchToSFX
	ld ix,zAbsVar
	ld a,(zAbsVar.StopMusic)
	or a
	jr z,zUpdateEverything
	call zPauseMusic
	jp zUpdateDAC
zUpdateEverything:
	call zCycleQueue
	ld a,(zAbsVar.QueueToPlay)
	or a
	call nz,zPlaySoundByIndex
	ld a,(zSpindashPlayingCounter)
	or a
	jr z,+
	dec a
	ld (zSpindashPlayingCounter),a
+
	ld a,(zAbsVar.MusicDACRequest)
	or a
	jr z,+
	ld b,a
	xor a
	ld (zAbsVar.MusicDACRequest),a
	ld a,(zAbsVar.MusicDACPan)
	ld c,a
	ld d,0
	call zPlayDAC
+
	rst zBankSwitchToSFX
	ld a,80h
	ld (zDoSFXFlag),a
	ld ix,zTracksSFXStart-zTrack.len
	ld b,SFX_TRACK_COUNT
-	push bc
	ld de,zTrack.len
	add ix,de
	bit 7,(ix+zTrack.PlaybackControl)
	call nz,zUpdateTrack
	pop bc
	djnz -
zUpdateDAC:
	call zLeaveFMSection
	ld a,(zAbsVar.StopDAC)
	or a
	jp nz,zAbortDAC
	ld	(iy+0),2Ah		; Set DAC port register

zDACBankSwitch:
	ld	a,zmake68kBank(SndDAC1_Start)	; Bankswitch to the DAC data (self-modifying code!)
	rst	zBankSwitch

	; Shadow regs for the DPCM loop
	ld	c,0Fh				; DPCM nibble mask
	ld	de,zYM2612_D0
	ld	h,(zDACDecodeTbl & 0FF00h) >> 8	; DPCM lookup table address high byte
	exx

	ld	hl,zCurDAC			; Get address of 'current DAC sound' value
	bit	7,(hl)				; Get currently playing DAC sound
	jr	nz,+						; If one is queued (80h+), go to it!
	pop	hl
	pop	de
	pop	bc
	pop	af
	ld	b,1						; b=1 (initial feed to the DAC "djnz" loops, i.e. UPDATE RIGHT AWAY)
	ei		; enable interrupts
	ret
+
	; If you get here, it's time to start a new DAC sound...
	ld	a,80h
	ex	af,af'	;'
	res	7,(hl)					; Subtract 80h (first DAC index is 80h)

	; Clear the stack of (now-useless) backed-up variables
	pop	hl
	pop	de
	pop	bc
	pop	af

	pop	hl	; Pop return address from the stack; we don't want to return

zloc_104:
	ld	hl,0000h	; "self-modified code" -- sets start address of DAC sample for zWriteDPCMtoDAC

zloc_107:
	ld	de,0000h	; "self-modified code" -- sets length of DAC sample for zWriteDPCMtoDAC

zloc_10B:
	ld	bc,100h ; "self-modified code" -- From zloc_22A; sets b=1 (the 100h part of it) UPDATE RIGHT AWAY and c="data rate delay" for this DAC sample, the future 'b' setting
	ei		; enable interrupts

zDACPlaybackAddrInstruction:
	jp	zWriteDPCMtoDAC
; End of function zVInt

	align 100h
;zbyte_1B3
zDACDecodeTbl:
	db	   0,	 1,   2,   4,   8,  10h,  20h,  40h
	db	 80h,	-1,  -2,  -4,  -8, -10h, -20h, -40h

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; Updates all tracks; queues notes and durations!

;zsub_110
zInitialiseDriver:
	im	1	; set interrupt mode 1
	ld	iy,zYM2612_A0
	call	zClearTrackPlaybackMem
	ei		; enable interrupts
	jr	$
	; This controls the update rate for the DAC...
	; My speculation for the rate at which the DAC updates:
	;	Z80 clock = 3.57954MHz = 3579540Hz (not sure?)
	;	zWaitLoop (immediately below) is waiting for someone to set
	;		'de' (length of DAC sample) to non-zero

	; The DAC code is sync'ed with VBLANK somehow, but I haven't quite got that
	; one figure out yet ... tests on emulator seem to confirm it though.
	; Next, there are "djnz" loops which do busy-waits.  (Two of them, which is
	; where the '2' comes from in my guess equation.)  The DACMasterPlaylist
	; appears to use '1' as the lowest input value to these functions.  (Which,
	; given the djnz, would be the fastest possible value.)
	; The rate seems to be calculated by 3579540Hz / (60Hz + (speed * 4)) / 2

	; 'hl' is the pointer to the sample, 'de' is the length of the sample,
	; and 'iy' points to the translation table; let's go...

	; The "djnz $" loops control the playback rate of the DAC
	; (the higher the 'b' value, the slower it will play)


	; As for the actual encoding of the data, it is described by jman2050:

	; "As for how the data is compressed, lemme explain that real quick:
	; First, it is a lossy compression. So if you recompress a PCM sample this way,
	; you will lose precision in data. Anyway, what happens is that each compressed data
	; is separated into nybbles (1 4-bit section of a byte). This first nybble of data is
	; read, and used as an index to a table containing the following data:
	; 0,1,2,4,8,$10,$20,$40,$80,$FF,$FE,$FC,$F8,$F0,$E0,$C0."   [zDACDecodeTbl / zbyte_1B3]
	; "So if the nybble were equal to F, it'd extract $C0 from the tale. If it were 8,
	; it would extract $80 from the table. ... Anyway, there is also another byte of data
	; that we'll call 'd'. At the start of decompression, d is $80. What happens is that d
	; is then added to the data extracted from the table using the nybble. So if the nybble
	; were 4, the 8 would be extracted from the table, then added to d, which is $80,
	; resulting in $88. This result is then put back into d, then fed into the YM2612 for
	; processing. Then the next nybble is read, the data is extracted from the table, then
	; is added to d (remember, d is now changed because of the previous operation), then is
	; put back into d, then is fed into the YM2612. This process is repeated until the number
	; of bytes as defined in the table above are read and decompressed."

	; In our case, the so-called 'd' value is shadow register 'a'

; zWriteToDAC:
zWriteDPCMtoDAC:
	djnz	$				; Busy wait for specific amount of time in 'b'

	di		; disable interrupts (while updating DAC)
	ld	a,(hl)				; Get next DAC byte
	rlca
	rlca
	rlca
	rlca
	exx
	and	c					; UPPER 4-bit offset into zDACDecodeTbl
	ld	l,a
	ex	af,af'				; shadow register 'a' is the 'd' value for 'jman2050' encoding
	add	a,(hl)			; Get byte from zDACDecodeTbl (self-modified to proper index)
	ld	(de),a		; Write this byte to the DAC
	exx
	ex	af,af'				; back to regular registers
	ld	b,c					; reload 'b' with wait value
	ei						; enable interrupts (done updating DAC, busy waiting for next update)

	djnz	$				; Busy wait for specific amount of time in 'b'

	di		; disable interrupts (while updating DAC)
	ld	b,c					; reload 'b' with wait value
	ld	a,(hl)				; Get next DAC byte
	inc	hl					; Next byte in DAC stream...
	dec	de					; One less byte
	exx
	and	c					; LOWER 4-bit offset into zDACDecodeTbl
	ld	l,a
	ex	af,af'				; shadow register 'a' is the 'd' value for 'jman2050' encoding
	add	a,(hl)			; Get byte from zDACDecodeTbl (self-modified to proper index)
	ld	(de),a		; Write this byte to the DAC
	exx
	ex	af,af'				; back to regular registers
	ei						; enable interrupts (done updating DAC, busy waiting for next update)

; zloc_174: zWaitLoop:
zDPCMWaitLoop:
	ld	a,d
	or	e
zDPCMWaitLoopJumpInstruction:
	jp	nz,zWriteDPCMtoDAC

	xor	a
	ld	(zHighPriorityDACPlaying),a
	ld	(zDACSFXPlaying),a
	jr	zDPCMWaitLoop		; As long as 'de' (length of sample) = 0, wait...

zWritePCMtoDAC:
	djnz	$				; Busy wait for specific amount of time in 'b'

	di		; disable interrupts (while updating DAC)
	ld	a,(hl)				; Get next DAC byte
	inc	hl					; Next byte in DAC stream...
	dec	de					; One less byte
	ld	(zYM2612_D0),a		; Write this byte to the DAC
	ld	b,c					; reload 'b' with wait value
	ei						; enable interrupts (done updating DAC, busy waiting for next update)

zPCMWaitLoop:
	ld	a,d
	or	e
zPCMWaitLoopJumpInstruction:
	jp	nz,zWritePCMtoDAC

	xor	a
	ld	(zHighPriorityDACPlaying),a
	ld	(zDACSFXPlaying),a
	jr	zPCMWaitLoop			; Back to the wait loop; if there's more DAC to write, we come back down again!

; ---------------------------------------------------------------------------
	; FM3/FM4/FM5 and PSG1/PSG2/PSG3 effect slots. Music lives on MD.
	; FM3 is followed by a gap in the YM channel numbering.

	ensure1byteoffset 10h
;zbyte_1C3
zSFXTrackOffs:
	; These are offsets to different sound effect tracks starting with FM3
	dw	zSFX_FM3,      0000h,  zSFX_FM4,  zSFX_FM5	; FM3, 0, FM4, FM5
	dw	zSFX_PSG1, zSFX_PSG2, zSFX_PSG3, zSFX_PSG3	; PSG1, PSG2, PSG3, PSG3 (noise alternate)
; ---------------------------------------------------------------------------

zPlayDAC:
	ld	a,(zHighPriorityDACPlaying)
	or	a
	ret	nz

	ld	a,b
	ld	(zCurDAC),a					; Store current DAC sound to play

	ld	a,d
	ld	(zDACSFXPlaying),a

	ld	a,0B6h		; Set FM6 panning
	rst	zWriteFMII

	; Enable DAC if it isn't enabled already
	ld	a,(zDACEnabled)
	or	a
	jr	nz,+
	ld	a,80h
	ld	(zDACEnabled),a
	ld	c,a
	ld	a,2Bh
	rst	zWriteFMI
+
	rst	zBankSwitchToSFX		; zDACMasterPlaylist is in this bank

	ld	a,(zCurDAC)
	sub	81h				; Otherwise, transform note into an index... (we're selecting which drum to play!)
;	add	a,a				; A = DAC number * 2
	ld	c,a
	ld	b,0
	ld	hl,zmake68kPtr(zDACMasterPlaylist)
	add	hl,bc
	add	hl,bc
	add	hl,bc
	add	hl,bc
	add	hl,bc
	add	hl,bc
	add	hl,bc	; Each entry of zDACMasterPlaylist is 7 bytes long

	ld	a, (hl)
	ld	(zDACBankSwitch+1),a	; write DAC bank
	inc	hl

	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	hl
	ld	(zloc_104+1),bc			; write DAC sample start offset

	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	hl
	ld	(zloc_107+1),bc			; write DAC sample size

	ld	a,(hl)						; Data rate delay -> 'b'
	ld	(zloc_10B+1),a	; store into the instruction after zloc_10B (self-modifying code)
	inc	hl

	ld	a,(hl)
	ld	bc,zWriteDPCMtoDAC
	rra
	jr	nc,+
	ld	bc,zWritePCMtoDAC
+
	ld	(zDACPlaybackAddrInstruction+1),bc

	rra
	sbc	a,a
	ld	(zHighPriorityDACPlaying),a

	rst	zBankSwitchToSFX	; Restore SFX tables

	ret

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

zUpdateTrack:
	bit	7,(ix+zTrack.VoiceControl)		; Is this a PSG track?
	jp	nz, zPSGUpdateTrack			; If so, jump to zPSGUpdateTrack
	;jp	zFMUpdateTrack				; Else, jump to zFMUpdateTrack
	; fall through instead

;zsub_237
zFMUpdateTrack:
	dec	(ix+zTrack.DurationTimeout)					; Decrement duration
	jr	nz,+						; If not time-out yet, go do updates only
	res	4,(ix+zTrack.PlaybackControl)					; When duration over, clear "do not attack" bit 4 (0x10) of track's play control
	call	zFMDoNext				; Handle coordination flags, get next note and duration
	call	zFMPrepareNote			; Prepares to play next note
	call	zFMNoteOn				; Actually key it (if allowed)
	call	zDoModulation			; Update modulation (if modulation doesn't change, we do not return here)
	jp		zFMUpdateFreq			; Applies frequency update from modulation
+
	call	zNoteFillUpdate			; Applies "note fill" (time until cut-off); NOTE: Will not return here if "note fill" expires
	call	zDoModulation			; Update modulation (if modulation doesn't change, we do not return here)
	jp		zFMUpdateFreq			; Applies frequency update from modulation
; End of function zFMUpdateTrack


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


;zsub_258
zFMDoNext:
	ld	l,(ix+zTrack.DataPointerLow)		; Load track position low byte
	ld	h,(ix+zTrack.DataPointerHigh)		; Load track position high byte
	res	1,(ix+zTrack.PlaybackControl)		; Clear bit 1 (02h) "track is rest" from track

-	ld	a,(hl)
	inc	hl				; Increment track to next byte
	cp	0E0h			; Is it a control byte / "coordination flag"?
	jr	c,+				; If not, jump over
	call	zCoordFlag	; Handle coordination flag
	jr	-				; Go around, get next byte
+
	push	af
	call	zFMNoteOff	; Send key off
	pop	af
	or	a				; Test 'a' for 80h not set, which is a note duration
	jp	p,+				; If duration, jump to '+'
	call	zFMSetFreq	; Otherwise, this is a note; call zFMSetFreq
	ld	a,(hl)			; Get next byte
	or	a				; Test 'a' for 80h set, which is a note
	jp	m,zFinishTrackUpdate		; If this is a note, jump to zFinishTrackUpdate
	inc	hl				; Otherwise, go to next byte; a duration
+
	call	zSetDuration
	jr	zFinishTrackUpdate		; Either way, jumping to zFinishTrackUpdate...
; End of function zFMDoNext

; ---------------------------------------------------------------------------
; zloc_285:
;zGetFrequency
zFMSetFreq:
	; 'a' holds a note to get frequency for
	sub	80h
	jr	z,zFMDoRest		; If this is a rest, jump to zFMDoRest
	add	a,(ix+zTrack.Transpose)		; Add current channel transpose (coord flag E9)
	if	0
	add	a,a				; Offset into Frequency table...
	add	a,zFrequencies&0FFh
	ld	(zloc_292+2),a	; store into the instruction after zloc_292 (self-modifying code)
	;ld	d,a
	;adc	a,(zFrequencies&0FF00h)>>8
	;sub	d
	;ld	(zloc_292+3),a	; this is how you could store the high byte of the pointer too (unnecessary if it's in the right range)
zloc_292:
	ld	de,(zFrequencies)	; Stores frequency into "de"
	ld	(ix+zTrack.FreqLow),e		; Frequency low byte   -> trackPtr + 0Dh
	ld	(ix+zTrack.FreqHigh),d		; Frequency high byte  -> trackPtr + 0Eh
	else
	ld	d,12			; 12 notes per octave
	ld	c,0			; clear c (will hold octave bits)

-	sub	d			; Subtract 1 octave from the note
	jr	c,+			; If this is less than zero, we are done
	inc	c			; One octave up
	jr	-
+
	add	a,d			; Add 1 octave back (so note index is positive)
	sla	c
	sla	c
	sla	c			; multiply octave value by 8, to get final octave bits
	ld	de,zFrequencies
zSFX_SetFMPSGFreq:
	add	a,a
	add	a,e	; DE += 0A
	ld	e,a
	adc	a,d
	sub	a,e
	ld	d,a
	ld	a,(de)
	ld	(ix+zTrack.FreqLow),a		; Frequency low byte   -> trackPtr + 0Dh
	inc	de
	ld	a,(de)
	or	c			; a = high bits of frequency (including octave bits, which were in c)
	ld	(ix+zTrack.FreqHigh),a		; Frequency high byte  -> trackPtr + 0Eh
	endif
	ret
; ---------------------------------------------------------------------------

;zloc_29D
zFMDoRest:
	set	1,(ix+zTrack.PlaybackControl)		; Set bit 1 (track is at rest)
	xor	a				; Clear 'a'
	ld	(ix+zTrack.FreqLow),a		; Zero out FM Frequency
	ld	(ix+zTrack.FreqHigh),a		; Zero out FM Frequency
	ret

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


;zsub_2A9
zSetDuration:
	call	zComputeNoteDuration
	ld	(ix+zTrack.SavedDuration),a		; Store new duration into ticker goal of this track (this is reused if a note follows a note without a new duration)
	ld	(ix+zTrack.DurationTimeout),a		; Sets it on ticker (counts to zero)
	ret
; End of function zSetDuration

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


zComputeNoteDuration:
	ld	c,a				; 'a' = current duration
	xor	a
	ld	b,(ix+zTrack.TempoDivider)		; Divisor; causes multiplication of duration for every number higher than 1
-	add	a,c				; Will multiply duration based on 'b'
	djnz	-
	ret
; End of function zComputeNoteDuration

; ---------------------------------------------------------------------------

;zloc_2BA
zFinishTrackUpdate:
	; Common finish-up routine used by FM or PSG
	ld	(ix+zTrack.DataPointerLow),l		; Stores "hl" to the track pointer memory
	ld	(ix+zTrack.DataPointerHigh),h
	ld	a,(ix+zTrack.SavedDuration)		; Last set duration
	ld	(ix+zTrack.DurationTimeout),a		; ... put into ticker
	bit	4,(ix+zTrack.PlaybackControl)		; Is bit 4 (10h) "do not attack next note" set on playback?
	ret	nz				; If so, quit
	ld	a,(ix+zTrack.NoteFillMaster)		; Master "note fill" value -> a
	ld	(ix+zTrack.NoteFillTimeout),a		; Reset 0Fh "note fill" value to master
	ld	(ix+zTrack.VolFlutter),0		; Reset PSG flutter byte
	bit	3,(ix+zTrack.PlaybackControl)		; is modulation turned on?
	ret	z				; if not, quit
	ld	l,(ix+zTrack.ModulationPtrLow)		; Otherwise, get address of modulation setting
	ld	h,(ix+zTrack.ModulationPtrHigh)
	jp	zSetModulation	; ... and go do it!

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


;zsub_2E3
zNoteFillUpdate:
	ld	a,(ix+zTrack.NoteFillTimeout)		; Get current note fill value
	or	a
	ret	z				; If zero, return!
	dec	(ix+zTrack.NoteFillTimeout)		; Decrement note fill
	ret	nz				; If not zero, return
	set	1,(ix+zTrack.PlaybackControl)		; Set bit 1 (track is at rest)
	pop	de				; return address -> 'de' (will not return to z*UpdateTrack function!!)
	bit	7,(ix+zTrack.VoiceControl)		; Is this a PSG track?
	jp	nz,zPSGNoteOff	; If so, jump to zPSGNoteOff
	jp	zFMNoteOff		; Else, jump to zFMNoteOff
; End of function zNoteFillUpdate


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


;zsub_2FB
zDoModulation:
	pop	de				; keep return address -> de (MAY not return to caller)

	bit	1,(ix+zTrack.PlaybackControl)		; Is "track in rest"?
	ret	nz				; If so, quit
	bit	3,(ix+zTrack.PlaybackControl)		; Is modulation on?
	ret	z				; If not, quit
	ld	a,(ix+zTrack.ModulationWait)		; 'ww' period of time before modulation starts
	or	a
	jr	z,+				; if zero, go to it!
	dec	(ix+zTrack.ModulationWait)		; Otherwise, decrement timer
	ret					; return if decremented (does NOT return to z*UpdateTrack!!)
+
	dec	(ix+zTrack.ModulationSpeed)		; Decrement modulation speed counter
	ret	nz				; Return if not yet zero
	ld	l,(ix+zTrack.ModulationPtrLow)
	ld	h,(ix+zTrack.ModulationPtrHigh)		; 'hl' points to modulation setting
	inc	hl				; skip passed 'ww' period of time
	ld	a,(hl)			; Get modulation speed
	ld	(ix+zTrack.ModulationSpeed),a		; Restore speed counter
	ld	a,(ix+zTrack.ModulationSteps)		; Get number of steps in modulation
	or	a
	jr	nz,+			; If not zero, skip to '+'

	; If steps have reached zero...
	inc	hl				; passed mod speed
	inc	hl				; passed mod change per mod step
	ld	a,(hl)			; get number of steps in modulation
	ld	(ix+zTrack.ModulationSteps),a		; restore modulation steps
	ld	a,(ix+zTrack.ModulationDelta)		; get modulation change per mod step
	neg					; flip it negative
	ld	(ix+zTrack.ModulationDelta),a		; store negated value
	ret
+
	dec	(ix+zTrack.ModulationSteps)		; Decrement the step
	ld	l,(ix+zTrack.ModulationValLow)
	ld	h,(ix+zTrack.ModulationValHigh)		; Get 16-bit modulation value

	; This is a 16-bit sign extension for 'bc'
	if	0
	ld	b,0
	ld	c,(ix+zTrack.ModulationDelta)		; Get current modulation change per step -> 'c'
	bit	7,c
	jp	z,+
	ld	b,0FFh			; Sign extend if negative
	else
	ld	c,(ix+zTrack.ModulationDelta)		; Get current modulation change per step -> 'c'
	ld	a, c
	add	a, a			; sign bit into carry
	sbc	a, a
	ld	b, a			; b = sign extention
	endif
+
	add	hl,bc			; Add to current modulation value
	ld	(ix+zTrack.ModulationValLow),l
	ld	(ix+zTrack.ModulationValHigh),h		; Store new 16-bit modulation value
	ld	c,(ix+zTrack.FreqLow)		; frequency low byte -> c
	ld	b,(ix+zTrack.FreqHigh)		; frequency high byte -> b
	add	hl,bc			; Add modulation value
	ex	de,hl
	jp	(hl)			; WILL return to z*UpdateTrack
; End of function zDoModulation

; ---------------------------------------------------------------------------

;zloc_3E5
zFMPrepareNote:
	bit	1,(ix+zTrack.PlaybackControl)		; Is track in rest?
	ret	nz				; If so, quit
	ld	e,(ix+zTrack.FreqLow)		; Get frequency low
	ld	d,(ix+zTrack.FreqHigh)		; Get frequency high
	ld	a,d
	or	e
	jp	z,zloc_4C5		; If de == 0, go to zloc_4C5

;zloc_3F5
zFMUpdateFreq:
	bit	2,(ix+zTrack.PlaybackControl)		; Is SFX overriding this track?
	ret	nz				; If so, quit!
	if	0
	ld	h,0				; h = 0
	ld	l,(ix+zTrack.Detune)		; Get detune value
	; This is a 16-bit sign extension of (ix+19h)
	bit	7,l				; Did prior value have 80h set?
	jr	z,+				; If not, skip next step
	ld	h,0FFh			; h = FFh
	else
	ld	l,(ix+zTrack.Detune)		; Get detune value
	ld	a, l
	add	a, a			; sign bit into carry
	sbc	a, a
	ld	h, a			; h = sign extention
	endif
+
	add	hl,de			; Alter frequency just a tad
	ld	c,h				; Upper part of frequency as data to FM ('c')
	ld	a,(ix+zTrack.VoiceControl)		; "voice control" byte -> 'a'
	and	3				; Strip to only channel assignment
	add	a,0A4h			; Change to proper register
	rst	zWriteFMIorII	; Write it!
	ld	c,l				; lower part of frequency
	sub	4				; A0h+ register
	rst	zWriteFMIorII	; Write it!
	ret

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


;zsub_414
zPSGUpdateTrack:
	dec	(ix+zTrack.DurationTimeout)					; decrement current duration timeout..
	jr	nz,+						; If not time-out yet, go do updates only
	res	4,(ix+zTrack.PlaybackControl)				; Reset "do not attack next note" bit
	call	zPSGDoNext				; Handle coordination flags, get next note and duration
	call	zPSGDoNoteOn			; Actually key it (if allowed)
	call	zPSGDoVolFX				; This applies PSG volume as well as its special volume-based effects that I call "flutter"
	call	zDoModulation			; Update modulation (if modulation doesn't change, we do not return here)
	jr	zPSGUpdateFreq
+
	call	zNoteFillUpdate			; Applies "note fill" (time until cut-off); NOTE: Will not return here if "note fill" expires
	call	zPSGUpdateVolFX			; Update volume effects
	call	zDoModulation			; Update modulation (if modulation doesn't change, we do not return here)
	jr	zPSGUpdateFreq
; End of function zPSGUpdateTrack


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


;zsub_438
zPSGDoNext:
	ld	l,(ix+zTrack.DataPointerLow)		; Load track position low byte
	ld	h,(ix+zTrack.DataPointerHigh)		; Load track position high byte
	res	1,(ix+zTrack.PlaybackControl)		; Clear bit 1 (02h) "track is rest" from track

-	ld	a,(hl)
	inc	hl				; Increment track to next byte
	cp	0E0h			; Is it a control byte / "coordination flag"?
	jr	c,+				; If not, jump over
	call	zCoordFlag	; Handle coordination flag
	jr	-				; Go around, get next byte
+
	or	a				; Test 'a' for 80h not set, which is a note duration
	jp	p,+				; If note duration, jump to '+'
	call	zPSGSetFreq	; Get frequency for this note
	ld	a,(hl)			; Get next byte
	or	a				; Test 'a' for 80h set, which is a note
	jp	m,zFinishTrackUpdate		; If this is a note, jump to zFinishTrackUpdate
	inc	hl				; Otherwise, go to next byte; a duration
+
	call	zSetDuration
	jp	zFinishTrackUpdate		; Either way, jumping to zFinishTrackUpdate...
; End of function zPSGDoNext

; ---------------------------------------------------------------------------

;zloc_460
zPSGSetFreq:
	sub	81h				; a = a-$81 (zero-based index from lowest note)
	jr	c,+				; If carry (only time that happens if 80h because of earlier logic) this is a rest!
	add	a,(ix+zTrack.Transpose)		; Add current channel transpose (coord flag E9)
	add	a,12
	if	0
	add	a,a
	add	a,zPSGFrequencies&0FFh	; Point to proper place in table
	ld	(zloc_46D+2),a	; store into the instruction after zloc_46D (self-modifying code)
	;ld	d,a
	;adc	a,(zPSGFrequencies&0FF00h)>>8
	;sub	d
	;ld	(zloc_46D+3),a	; this is how you could store the high byte of the pointer too (unnecessary if it's in the right range)
zloc_46D:
	ld	de,(zPSGFrequencies)	; Gets appropriate frequency setting -> 'de'
	ld	(ix+zTrack.FreqLow),e		; Frequency low byte   -> trackPtr + 0Dh
	ld	(ix+zTrack.FreqHigh),d		; Frequency high byte  -> trackPtr + 0Eh
	ret
	else
	ld	de, zPSGFrequencies
	ld	c,0	; zSFX_SetFMPSGFreq uses c to hold octave bits for FM
	jp	zSFX_SetFMPSGFreq
	endif
+
	; If you get here, we're doing a PSG rest
	set	1,(ix+zTrack.PlaybackControl)		; Set "track in rest" bit
	ld	a,0FFh
	ld	(ix+zTrack.FreqLow),a		; Frequency low byte = FFh
	ld	(ix+zTrack.FreqHigh),a		; Frequency hight byte = FFh
	jp	zPSGNoteOff		; Send PSG Note Off

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


;zsub_487
zPSGDoNoteOn:
	bit	7,(ix+zTrack.FreqHigh)		; If track is at rest (frequency was set to FFh)...
	jr	nz,zloc_4C5		; jump to zloc_4C5
	ld	e,(ix+zTrack.FreqLow)		; Frequency low byte -> e
	ld	d,(ix+zTrack.FreqHigh)		; Frequency high byte -> d

;zloc_493
zPSGUpdateFreq:
	ld	a,(ix+zTrack.PlaybackControl)		; Get playback control byte
	and	6
	ret	nz				; If either bit 1 ("track in rest") and 2 ("SFX overriding this track"), quit!
	; This is a 16-bit sign extension of (ix+19h) -> 'hl'
	if	0
	ld	h,0
	ld	l,(ix+zTrack.Detune)		; hl = detune value (coord flag E9)
	bit	7,l				; Did prior value have 80h set?
	jr	z,+				; If not, skip next step
	ld	h,0FFh			; sign extend negative value
	else
	ld	l,(ix+zTrack.Detune)		; Get detune value
	ld	a, l
	add	a, a			; sign bit into carry
	sbc	a, a
	ld	h, a			; h = sign extention
	endif
+
	add	hl,de			; Alter frequency just a tad
	; This picks out the reg to write to the PSG
	ld	a,(ix+zTrack.VoiceControl)		; Get "voice control" byte...
	cp	0E0h			; Is it E0h?
	jr	nz,+			; If not, skip next step
	ld	a,0C0h			; a = C0h instead of E0h
+
	ld	b,a				; 'a' -> 'b'
	ld	a,l				; Frequency low byte -> 'a'
	and	0Fh				; Keep only lower four bits (first PSG reg write only applies d0-d3 of freq)
	or	b				; Apply register bits
	ld	(zPSG),a		; Write it to PSG!
	ld	a,l				; Get frequency low byte -> 'a'
	srl	h				; (h >> 1); lowest bit into carry
	rra					; (a >> 1); carry from 'h' applied at end
	srl	h				; ... and so on ...
	rra
	rra
	rra					; in C, basically (hl >> 4) (except possible garbage from the rotation in upper bits)
	and	3Fh				; keep only lower 6 bits (PSG d4-d9)
	ld	(zPSG),a		; Write other frequency byte to PSG!
	ret
; ---------------------------------------------------------------------------

zloc_4C5:
	set	1,(ix+zTrack.PlaybackControl)		; Set "track at rest" bit
	ret
; End of function zPSGDoNoteOn


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


;zsub_4CA
zPSGUpdateVolFX:
	ld	a,(ix+zTrack.VoiceIndex)		; Get current PSG tone
	or	a				; Test if it's zero
	ret	z				; If it is, return!
	; Otherwise, fall into zPSGDoVolFX...


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


;zsub_4CF
zPSGDoVolFX:
	ld	b,(ix+zTrack.Volume)		; Channel volume -> 'b'
	ld	a,(ix+zTrack.VoiceIndex)		; Current PSG tone -> 'a'
	or	a				; Test it
	jr	z,zPSGUpdateVol		; If tone is zero, jump to zPSGUpdateVol
	ld	hl,zPSG_FlutterTbl	; hl points to zPSG_FlutterTbl table
	dec	a				; a--
	add	a,a				; a *= 2
	ld	e,a
	ld	d,0				; de = a
	add	hl,de			; Offset into pointer table...
	ld	a,(hl)			; Get low byte -> 'a'
	inc	hl				; Next byte
	ld	h,(hl)			; Get high byte into 'h'
	add	a,(ix+zTrack.VolFlutter)		; Apply PSG flutter (provides dynamic volume for special effects)
	ld	l,a
	adc	a,h
	sub	l
	ld	h,a				; Basically, hl = (hl+(ix+zTrack.VolFlutter))
	ld	a,(hl)			; Get byte from this location
	inc	(ix+zTrack.VolFlutter)			; Increment PSG flutter value
	or	a				; test byte from before
	jp	p,+				; Is it a positive value?
	cp	80h				; Check if it's 80h (terminator to the "flutter" list)
	jr	z,zVolEnvHold		; If it is, then jump to zVolEnvHold (which just keeps at this flutter value, i.e. no more changes in volume)
+
	add	a,b				; Apply this "flutter" to channel volume -> 'a'
	ld	b,a				; a -> 'b'

;zloc_4F9
zPSGUpdateVol:
	ld	a,(ix+zTrack.PlaybackControl)		; get playback control byte
	and	6
	ret	nz				; If either bit 1 ("track in rest") and 2 ("SFX overriding this track"), quit!
	bit	4,(ix+zTrack.PlaybackControl)		; is "do not attack next note" set?
	jr	nz,zloc_515		; If so, jump to zloc_515

zloc_505:
	ld	a,b				; 'b' -> 'a'
	cp	10h				; Did the level get pushed below silence level? (i.e. a > 0Fh)
	jr	c,+
	ld	a,0Fh			; If so, fix it!
+
	or	(ix+zTrack.VoiceControl)			; Apply channel info (which PSG to set!)
	or	10h				; This bit marks it as an attenuation level assignment (along with channel info just above)
	ld	(zPSG),a		; Write to PSG!!
	ret
; ---------------------------------------------------------------------------

zloc_515:				; If you get here, then "do not attack next note" was set...
	ld	a,(ix+zTrack.NoteFillMaster)		; Get master "note fill" value
	or	a				; test it
	jr	z,zloc_505		; If it's zero, then just process normally
	ld	a,(ix+zTrack.NoteFillTimeout)		; Otherwise, get current "note fill" value
	or	a				; Test it
	jr	nz,zloc_505		; If it's not zero, then just process normally
	ret
; ---------------------------------------------------------------------------
; zloc_522:
zVolEnvHold:
	; This just decrements the flutter to keep it in place; no more volume changes in this list
	; Clownacy: This new code loops over the terminator flag AND the final volume
	; value, to fix PSG during fade in/out.
	dec	(ix+zTrack.VolFlutter)
	dec	(ix+zTrack.VolFlutter)				; Put index back (before final volume value)
	jr	zPSGDoVolFX				; Loop back and update volume
;	; DANGER! This effectively halts all future volume updates, breaking fades.
;	dec	(ix+zTrack.VolFlutter)	; Put index back (before flag 80h)
;	ret							; Return and don't update volume on this frame (!!!)
; End of function zPSGDoVolFX


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


;zsub_526
zPSGNoteOff:
	bit	2,(ix+zTrack.PlaybackControl)		; Is "SFX override" bit set?
	ret	nz				; If so, quit!
	ld	a,(ix+zTrack.VoiceControl)		; Get "voice control" byte (loads upper bits which specify attenuation setting)

	;                 |a| |1Fh|
	; VOL1    0x90	= 100 1xxxx	vol 4b xxxx = attenuation value
	; VOL2    0xb0	= 101 1xxxx	vol 4b
	; VOL3    0xd0	= 110 1xxxx	vol 4b

	or	1Fh				; Attenuation Off
	ld	(zPSG),a
	; Clownacy: Without zInitMusicPlayback forcefully muting all channels, there's the
	; risk of music accidentally playing noise because it can't detect if
	; the PSG4/noise channel needs muting, on track initialisation.
	; This bug can be heard be playing the End of Level music in CNZ, whose
	; music uses the noise channel. S&K's driver contains a fix just like this.
	cp	0DFh		; Are we stopping PSG3?
	ret	nz
	ld	a,0FFh		; If so, stop noise channel while we're at it
	ld	(zPSG),a	; Stop noise channel
	ret
; End of function zPSGNoteOff


;zloc_5F4
zPSGSilenceAll:
	ld	hl,zPSG		; PSG reg
	ld	(hl),9Fh	; Stop channel 0
	ld	(hl),0BFh	; Stop channel 1
	ld	(hl),0DFh	; Stop channel 2
	ld	(hl),0FFh	; Stop noise channel
	ret

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||
;zsub_600
zPauseMusic:
	jp m,.resume
	ld a,0DAh
	ld (zDPCMWaitLoopJumpInstruction),a
	ld (zPCMWaitLoopJumpInstruction),a
	ret
.resume:
	xor a
	ld (zAbsVar.StopMusic),a
	ld a,0C2h
	ld (zDPCMWaitLoopJumpInstruction),a
	ld (zPCMWaitLoopJumpInstruction),a
	ld ix,zTracksSFXStart
	ld b,SFX_TRACK_COUNT
-	push bc
	bit 7,(ix+zTrack.PlaybackControl)
	jr z,+
	bit 7,(ix+zTrack.VoiceControl)
	call z,zSetSFXVoice
+	pop bc
	ld de,zTrack.len
	add ix,de
	djnz -
	ret
zCycleQueue:
	ld	a,(zAbsVar.QueueToPlay)	; Check if a sound request was made zComRange+08h
	or	a					; Is queue slot equal to 80h?
	ret	nz					; If not, return
	ld	hl,zAbsVar.SFXToPlay		; Get address of next sound
	ld	a,(zAbsVar.SFXPriorityVal)		; Get current SFX priority
	ld	d,a					; a -> c
	ld	b,zVar.SoundQueueEnd-zVar.SFXToPlay					; b = 3

-	ld	a,(hl)				; Get sound to play -> 'a'
	ld	e,a					; 'a' -> 'e'
	ld	(hl),0				; Clear it back to zero (we got it)
	inc	hl					; hl = pointer to next queue item
	cp	MusID__First		; Is it before first music?
	jr	c,zlocQueueNext		; if so, branch
	cp	DACSFXID__First		; Is it a special command?
	jr	nc,zlocQueueItem	; If so, branch
	sub	SndID__First		; Subtract first SFX index
	jr	c,zlocQueueItem		; If it was music, branch
	push	af
	rst	zBankSwitchToSFX			; Switch to SFX banks
	pop	af
	ld	hl,zmake68kPtr(SoundIndex+2)
	ld	c,a
	ld	b,0
	add	hl,bc
	add	hl,bc
	add	hl,bc
	ld	a,(hl)				; Get SFX priority
	cp	d					; Is the new SFX of a higher priority?
	jr	c,+					; Branch if not
	ld	d,a					; Save new priotity
	call	zlocQueueItem	; Queue the new SFX
+
	rst	zBankSwitchToSFX			; Switch to SFX tables
	ld	a,d					; Get back SFX priority
	or	a					; Is it negative (jumping sound)?
	ret	m					; Return if so
	ld	(zAbsVar.SFXPriorityVal),a		; Store the new priority
	ret
; ---------------------------------------------------------------------------
zlocQueueNext:
	djnz	-
	ret
; ---------------------------------------------------------------------------
zlocQueueItem:
	ld	a,e				; restore a to be the last queue item read
	ld	(zAbsVar.QueueToPlay),a	; Put it as the next item to play
	ret
; End of function zCycleQueue


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||
; zsub_6B2:
zPlaySoundByIndex:
	ld c,a
	xor a
	ld (zAbsVar.QueueToPlay),a
	ld a,c
	cp SndID__First
	ret c
	cp SndID__End
	jp c,zPlaySound_Main
	cp DACSFXID__First
	ret c
	cp DACSFXID__End
	jp c,zPlayDACSFX
	cp SndID_SegaSound
	jp z,zPlaySegaSound
	cp MusID_StopSFX
	jp z,zStopSoundEffects
	cp MusID_Stop
	ret nz
	call zStopSoundEffects
	ld a,1
	ld (zAbsVar.StopDAC),a
	xor a
	ld (zAbsVar.MusicDACRequest),a
	ret
zPlaySegaSound:
	; reset panning (don't want Sega sound playing on only one speaker)
	ld	a,0B6h			; Set Panning / AMS / FMS
	ld	c,0C0h			; default Panning / AMS / FMS settings (only stereo L/R enabled)
	rst	zWriteFMII		; Set it!

	ld	a,80h			; Command to enable DAC
	ld	(zDACEnabled),a
	ld	c,a
	ld	a,2Bh			; DAC enable/disable register
	rst	zWriteFMI

	call	zFMSilenceAll
	call	zPSGSilenceAll
	ld	a, zmake68kBank(SegaSndTbl)
	rst	zBankSwitch
	; Table Format:
	; pp bb s1 s0 l1 l0
	; bb = Bank, s1s0 = start offset, l1l0 = data length, pp = pitch
zPCMSound = $+1
	ld	a, 0
	add	a, a
	ld	b, 00h
	ld	c, a
	ld	hl, zmake68kPtr(SegaSndTbl)
	add	hl, bc
	add	hl, bc
	add	hl, bc
	ld	c, (hl)	; pitch
	inc	hl
	ld	a, (hl)	; bank
	inc	hl
	ld	d, (hl)	; start offset MSB
	inc	hl
	ld	e, (hl)	; start offset LSB
	inc	hl
	ld	b, (hl)	; data size MSB
	inc	hl
	ld	l, (hl)	; data size LSB
	ld	h, b

	push	hl
	ld	(zCurPCMBnk), a
	rst	zBankSwitch
	pop	hl
	ex	de, hl

	ld	(iy+0),2Ah	; Select it
	call zLeaveFMSection
zPCMLoop:
	ld	a, (hl)			; Get next PCM byte
	ld	(iy+1), a	; Send to DAC
	inc	hl
	dec	de				; 1 byte less to play
	ld	b, c
	djnz	$			; Delay loop

	ld	a, d			; a = d
	or	e				; Is de zero?
	jr	z, zPCMLoopExit	; If so, exit

	ld	a, (zAbsVar.QueueToPlay)	; Get next item to play
	or	a
	jr	nz, zPCMLoopExit

	or	h
	jp	m, zPCMLoop
zPCMBankAdvance:
	ld	hl, zCurPCMBnk
	inc	(hl)	; next Z80 bank
	ld	a, (hl)
	rst	zBankSwitch
	ld	h, 80h	; L is already 0
	jr	zPCMLoop

zPCMLoopExit:
	call zEnterFMSection
	xor	a
	ld	(zDoSFXFlag), a
	rst	zBankSwitchToSFX
	pop	bc			; skip effect sequencing during Sega PCM playback
	jp	zUpdateDAC		; (alternatively call zBankSwitchToSFX)
; ---------------------------------------------------------------------------
; zloc_73D:
zPlaySound_Checks:
	xor	a
	ld	(zSpindashActiveFlag),a			; Clear spindash sound flag
	ld	a,c								; Sound index -> 'a'

	cp	SndID_Ring						; is this the ring sound?
	jr	z,zPlaySound_CheckRing			; if not, branch
	cp	SndID_Gloop						; is this the bloop/gloop noise?
	jr	z,zPlaySound_CheckGloop			; if not, branch
	cp	SndID_BlockPush					; is this the pushing block noise?
	jr	z,zPlaySound_CheckPush			; if not, branch
	cp	SndID_SpindashRev				; is this the spindash rev sound playing?
	jr	z,zPlaySound_CheckSpindash		; if not, branch
	ret

zPlaySound_CheckRing:
	; This is the ring sound...
zRingSpeaker = $+1
	ld	a,0							; 0 plays left, FFh plays right
	xor	0FFh							; If it was 0, it's now FFh, or vice versa
	ld	(zRingSpeaker),a							; Store new ring speaker value (other side)
	ret	z								; If it's zero, we play RingRight
	ld	c,SndID_RingLeft				; play RingLeft
	ret									; now play the play the ring sound
; ---------------------------------------------------------------------------
; zloc_942:
zPlaySound_CheckGloop:
zGloopFlag = $+1
	ld	a,0
	cpl
	ld	(zGloopFlag),a
	or	a
	ret	nz ; now play the play the gloop sound
zPlaySound_ret:
	pop	bc ; sometimes don't play it
	ret
; ---------------------------------------------------------------------------
; zloc_942:
zPlaySound_CheckPush:
zPushFlag = $+1
	ld	a,0
	or	a
	jr	nz, zPlaySound_ret
	cpl
	ld	(zPushFlag),a
	ret
; ---------------------------------------------------------------------------
; zloc_953:
zPlaySound_CheckSpindash:
	ld	hl, zSpindashExtraFrequencyIndex
	ld	a,(zSpindashPlayingCounter)
	or	a
	ld	a,(hl)
	jr	nz,+ ; if the spindash sound is already playing, branch
	ld	a,-1 ; reset the extra frequency (becomes 0 on the next line)
+
	inc	a ; increase the frequency
	cp	12
	jr	nc,+
	ld	(hl),a
+
	ld	a,60
	ld	(zSpindashPlayingCounter),a
	ld	a,-1
	ld	(zSpindashActiveFlag),a
	ret

; zloc_920:
zPlaySound_Main:
	ld	c,a								; Store sound index -> 'c'
	ld	a,(ix+zVar.1upPlaying)						; Get "is 1-up playing" flag...
	or	(ix+zVar.FadeInFlag)						; Or it with fading in flag
	jp	nz,zloc_KillSFXPrio				; If either is set, SFX cannot be played!!
	call	zPlaySound_Checks

; zloc_975:
zPlaySound:
	rst	zBankSwitchToSFX			; Switch to SFX banks

	ld	hl,zmake68kPtr(SoundIndex)		; 'hl' points to beginning of SFX bank in ROM window
	ld	a,c								; 'c' -> 'a'
	sub	SndID__First					; Bring 'a' down to index value
	ld	e,a
	ld	d,0								; de = a
	add	hl,de
	add	hl,de
	add	hl,de							; now hl points to a pointer in the SoundIndex list (such as rom_ptr_z80 Sound20)
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a								; now hl points to a sound's data (such as Sound20: ...)
	ld	e,l
	ld	d,h
	ld	c,(hl)
	inc	hl
	ld	b,(hl)							; 'de' points to custom voice table (if any; otherwise is 0000h)
	inc	hl
	ex	hl,de
	add	hl,bc
	ex	hl,de
	ld	(zloc_A26+1),de	; store into the instruction after zloc_A26 (self-modifying code)
	ld	c,(hl)							; Timing divisor -> 'c'
	inc	hl
	ld	b,(hl)							; Total channels used -> 'b'
	inc	hl

zloc_99F:
	push	bc							; backup divisor/channel usage
	xor	a								; a = 0 (will end up being NO CUSTOM VOICE TABLE!)
	ld	(zloc_A1D+1),a ; store into the instruction after zloc_A1D (self-modifying code) (Kind of pointless, always sets it to zero... maybe PSG would've had custom "flutter" tables?)
	push	hl							; save current position within sound (offset 04h)

	ld	a,(hl)							; Track sound def -> 'a' (if 80h set, it's PSG, otherwise it's FM) -- note this also tells what channel it's on (80, A0, C0 for PSG, FM channel assignments otherwise)
	or	a								; test it
	jp	m,+								; if bit 7 (80h) set (meaning PSG track), skip next part...
	sub	2								; Subtract 2 from this value
	add	a,a								; Multiply it by 2
	jp	zloc_9CA						; This is an FM sound track...
+
	; This is a PSG track!
	; Always ends up writing zero to voice table pointer?
	ld	(zloc_A1D+1),a	; store into the instruction after zloc_A1D (self-modifying code)
	cp	0C0h							; Is this PSG3?
	jr	nz,+							; If not, skip this part
	push	af
	or	1Fh								; Set silence on PSG!
	ld	(zPSG),a
	xor	20h
	ld	(zPSG),a
	pop	af
+
	rra
	rra
	rra
	rra
	and	0Fh					; for PSG, just shift it down by 4 and we have its index!

zloc_9CA:
	add a,zSFXTrackOffs&0FFh
	ld (zloc_9D9+2),a
zloc_9D9:
	ld	ix,(zSFXTrackOffs)				; 'ix' is now start of corresponding SFX track

	; The channel code selects one of the six effect slots through IX.

	; Now we're going to clear this SFX track...
	ld	e,ixl
	ld	d,ixu							; de = ix
	ld	l,e								; hl = de (start of SFX track)
	ld	h,d
	ld	(hl),0							; store 00h on first byte of track
	inc	de								; next byte...
	push	de							; save 'de'
	ld	bc,zTrack.len-1					; For all bytes in the track, minus 1 (since we're copying 00h from first byte)
	ldir								; Clear track memory!
	pop	de								; Restore 'de' (start of SFX track yet again)
	pop	hl								; Get 'hl' back from way before (offset of sound in ROM + 04h)
;	ld	a,e
;	add	a,zTrack.PlaybackControl
;	ld	e,a
;	adc	a,d
;	sub	e
;	ld	d,a
	ldi									; *de++ = *hl++ (write voice control byte) (sets whether is PSG or what)
	pop	bc								; restore 'bc'...
	push	bc							; ... Um, back it up again!
	set	7,(ix+zTrack.PlaybackControl)						; write playback control byte ('track is playng' bit)
	ld	(ix+zTrack.TempoDivider),c						; Set timing divisor of SFX track
	ld	(ix+zTrack.DurationTimeout),1						; current duration timeout to 1 (will expire immediately and thus update)
	ld	(ix+zTrack.StackPointer),zTrack.GoSubStack				; Reset track "gosub" stack
	inc	de							; de += 1 (skip timing divisor; already set)
	ld	bc,3
	ldir						; while (bc-- > 0) *de++ = *hl++; (copy track address, default key offset)

	; If spindash active, the following block updates its frequency specially:
zSpindashActiveFlag = $+1
	ld	a,0
	or	a
	jr	z,+									; If spindash not last sound played, skip this
	ld	a,(zSpindashExtraFrequencyIndex)	; Get current frequency index
	dec	de									; Go back to key offset
	ex	de,hl								; hl <=> de
	add	a,(hl)								; Add spindash key offset!
	ex	de,hl								; de <=> hl (just done because we wanted add a,(hl))
	ld	(de),a								; Store it!
	inc	de									; Go passed key offset again
+
	ldi									; *de++ = *hl++ (channel volume)
zloc_A1D:	; Modified way back within zloc_99F
	ld	a,0								; "self-modified code"; if 00h, no custom voice table defined for this track
	or	a								; Test it
	jr	nz,+							; If not zero, skip next part...
	ld	(ix+zTrack.AMSFMSPan),0C0h						; Default panning / AMS / FMS settings (just L/R Stereo enabled)
zloc_A26:
	ld	de,0 ; "self-modified code"		; This will be modified to custom voice table address (possibly still 0000h)
	ld	(ix+zTrack.VoicePtrLow),e						; low byte of custom voice table (for SFX)
	ld	(ix+zTrack.VoicePtrHigh),d						; high byte of custom voice table (for SFX)
+
	pop	bc								; restore divisor (c) and channel counts (b0)
	dec	b								; One less FM channel
	jp	nz,zloc_99F						; If more to go, loop!

	rst	zBankSwitchToSFX
	ret
; ---------------------------------------------------------------------------

zloc_KillSFXPrio:
	xor	a
	ld	(zAbsVar.SFXPriorityVal),a					; Reset SFX priority
	ret
; End of function zPlaySoundByIndex

zPlayDACSFX:
	sub	DACSFXID__First
	ld	c,a
	ld	b,0
	ld	hl,zDACSFXList
	add	hl,bc
	ld	b,(hl)
	ld	c,0C0h		; default Panning / AMS / FMS settings (only stereo L/R enabled)
	ld	d,80h		; This is a DAC SFX
	jp	zPlayDAC

	include "sound/dacsfxlist.gen.asm"

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; zsub_A3C:
zStopSoundEffects:
	ld ix,zTracksSFXStart
	ld b,SFX_TRACK_COUNT
-	push bc
	bit 7,(ix+zTrack.PlaybackControl)
	jr z,+
	res 7,(ix+zTrack.PlaybackControl)
	bit 7,(ix+zTrack.VoiceControl)
	jr nz,.psg
	call zFMNoteOff
	jr +
.psg:
	call zPSGNoteOff
+	pop bc
	ld de,zTrack.len
	add ix,de
	djnz -
	xor a
	ld (zAbsVar.SFXPriorityVal),a
	ret
zFMSilenceAll:
	ld	a,28h			; Start at FM KEY ON/OFF register
	ld	b,3				; Three key on/off per part

-	ld	c,b				; Current key off -> 'c'
	dec	c				; c--
	rst	zWriteFMI		; Write key off for part I
	set	2,c				; Set part II select
	rst	zWriteFMI		; Write key off for part II
	djnz	-

	ld	a,30h			; Starting at FM register 30h...
	ld	c,0FFh			; Write dummy kill-all values
	ld	b,60h			; ... up to register 90h

-	rst	zWriteFMI		; ... on part I
	rst	zWriteFMII		; ... and part II
	inc	a				; Next register!
	djnz	-

	ret
; End of function zFMSilenceAll

; ---------------------------------------------------------------------------
; zloc_B4E:

zClearTrackPlaybackMem:
	ld hl,zAbsVar
	ld de,zAbsVar+1
	ld (hl),0
	ld bc,zTracksSFXEnd-zAbsVar-1
	ldir
	ret
zFMNoteOn:
	ld	a,(ix+zTrack.PlaybackControl)		; Get playback control byte
	and	6
	ret	nz				; If either bit 1 ("track in rest") and 2 ("SFX overriding this track"), quit!
	ld	a,(ix+zTrack.VoiceControl)		; Get "voice control" byte
	or	0F0h			; Turn on ALL operators
	ld	c,a				; Set as data to write to FM
	ld	a,28h			; Write to KEY ON/OFF port (key ON in this case)
	rst	zWriteFMI		; do it!
	ret
; End of function zFMNoteOn


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


;zsub_C56
zFMNoteOff:
	ld	a,(ix+zTrack.PlaybackControl)		; Load this track's playback control byte
	and	14h				; Are bits 4 (no attack) or 2 (SFX overriding) set?
	ret	nz				; If they are, return
	ld	a,28h			; Otherwise, send a KEY ON/OFF
	ld	c,(ix+zTrack.VoiceControl)		; Track's data for this key operation

	; Format of key on/off:
	; 4321 .ccc
	; Where 4321 are the bits for which operator,
	; and ccc is which channel (0-2 for channels 1-3, 4-6 for channels 4-6 WATCH BIT GAP)

	rst	zWriteFMI		; Write to part I (Note this particular register is ALWAYS sent to part I)
	ret
; End of function zFMNoteOff


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

zBankSwitchPart2:
	rept 7
		rra
		ld	(hl), a
	endm
	ld	(hl), l	; write a 0
	ret
; End of function zBankSwitchPart2

; ---------------------------------------------------------------------------

;zloc_C89
zCoordFlag:
	sub	0E0h
	add	a,a
	if	0
	add	a,zSFX_coordflagLookup&0FFh
	ld	(.writeme+2),a
.writeme:
	ld	bc,(zSFX_coordflagLookup)
	else
	ex	de, hl
	ld	hl, zSFX_coordflagLookup
	add	a, l
	ld	l, a
	adc	a, h
	sub	a, l
	ld	h, a
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
	ex	de, hl
	endif
	ld	(.writeme2+1),bc ; store into the instruction after zSFX_coordflagLookup (self-modifying code)
	ld	a,(hl)
	inc	hl
.writeme2:
	jp	$
; This is the lookup for Coordination flag routines

	;ensure1byteoffset 34h
;zloc_C92
zSFX_coordflagLookup:
; ---------------------------------------------------------------------------
	dw	zSFX_cfPanningAMSFMS ; E0
; ---------------------------------------------------------------------------
	dw	zSFX_cfDetune ; E1
; ---------------------------------------------------------------------------
	dw	zSFX_cfSetCommunication ; E2
; ---------------------------------------------------------------------------
	dw	zSFX_cfJumpReturn ; E3
; ---------------------------------------------------------------------------
	dw	zSFX_cfStopTrack ; E4
; ---------------------------------------------------------------------------
	dw	zSFX_cfSetTempoDivider ; E5
; ---------------------------------------------------------------------------
	dw	zSFX_cfChangeFMVolume ; E6
; ---------------------------------------------------------------------------
	dw	zSFX_cfPreventAttack ; E7
; ---------------------------------------------------------------------------
	dw	zSFX_cfNoteFill ; E8
; ---------------------------------------------------------------------------
	dw	zSFX_cfChangeTransposition ; E9
; ---------------------------------------------------------------------------
	dw	zSFX_cfStopTrack ; EA
; ---------------------------------------------------------------------------
	dw	zSFX_cfStopTrack ; EB
; ---------------------------------------------------------------------------
	dw	zSFX_cfChangePSGVolume ; EC
; ---------------------------------------------------------------------------
	dw	zSFX_cfClearPush ; ED
; ---------------------------------------------------------------------------
	dw	zSFX_cfStopSpecialFM4 ; EE
; ---------------------------------------------------------------------------
	dw	zSFX_cfSetVoice ; EF
; ---------------------------------------------------------------------------
	dw	zSFX_cfModulation ; F0
; ---------------------------------------------------------------------------
	dw	zSFX_cfEnableModulation ; F1
; ---------------------------------------------------------------------------
	dw	zSFX_cfStopTrack ; F2
; ---------------------------------------------------------------------------
	dw	zSFX_cfSetPSGNoise ; F3
; ---------------------------------------------------------------------------
	dw	zSFX_cfDisableModulation ; F4
; ---------------------------------------------------------------------------
	dw	zSFX_cfSetPSGTone ; F5
; ---------------------------------------------------------------------------
	dw	zSFX_cfJumpTo ; F6
; ---------------------------------------------------------------------------
	dw	zSFX_cfRepeatAtPos ; F7
; ---------------------------------------------------------------------------
	dw	zSFX_cfJumpToGosub ; F8
; ---------------------------------------------------------------------------
	dw	zSFX_cfOpF9 ; F9
; ---------------------------------------------------------------------------
	dw	zSFX_cfNoteFillS3K ; FA, new
; ---------------------------------------------------------------------------

; (via Saxman's doc): panning, AMS, FMS
;zloc_CFC
zSFX_cfPanningAMSFMS:
	;Panning, AMS, FMS
    ;* xx - Value (reg a)
    ;      o Bit 7 - Left channel status
    ;      o Bit 6 - Right channel Status
    ;      o Bit 5-3 - AMS
    ;      o Bit 2 - 0
    ;      o Bit 1-0 - FMS

	; Subject to verification, but even though you COULD set
	; AMS/FMS values, it does not appear that's what they intended
	; here; instead it appears they only meant for panning control.
	; I say this because it retains prior AMS/FMS settings ("and 37h")

	bit	7,(ix+zTrack.VoiceControl)		; a PSG track
	ret	m				; If so, quit!
	; This check is in the wrong place.
	; If this flag is triggered by a music track while it's being overridden
	; by an SFX, it will use the old panning when the SFX ends.
	; This is because zTrack.AMSFMSPan doesn't get updated.
	;bit	2,(ix+zTrack.PlaybackControl)		; If "SFX overriding" bit set...
	;ret	nz				; return
	ld	c,a				; input val 'a' -> c
	ld	a,(ix+zTrack.AMSFMSPan)		; old PAF value
	and	37h				; retains bits 0-2, 3-4?
	or	c				; OR'd with new settings
	ld	(ix+zTrack.AMSFMSPan),a		; new PAF value

	; The check should only stop hardware access, like this.
	bit	2,(ix+zTrack.PlaybackControl)		; If "SFX overriding" bit set...
	ret	nz				; return

	ld	c,a				; a -> c (YM2612 data write)

	; Don't change hardware if being overwritten by DAC SFX
	ld	a,(ix+zTrack.VoiceControl)
	cp	6
	jr	nz,+
	ld	a,(zDACSFXPlaying)
	or	a
	ret	nz
+
	ld	a,(ix+zTrack.VoiceControl)		; Get voice control byte
	and	3				; Channels only!
	add	a,0B4h			; Add register B4, stereo output control and LFO sensitivity
	rst	zWriteFMIorII	; depends on bit 2 of (ix+zTrack.VoiceControl)
	ret

; ---------------------------------------------------------------------------

; (via Saxman's doc): Alter note values by xx
; More or less a pitch bend; this is applied to the frequency as a signed value
;zloc_D1A cfAlterNotesUNK cfAlterNotes:
zSFX_cfDetune:
	ld	(ix+zTrack.Detune),a		; set new detune value
	ret
; ---------------------------------------------------------------------------

; Set otherwise unused communication byte to parameter
; Used for triggering a boss' attacks in Ristar
;zloc_D1E cfUnknown1
zSFX_cfSetCommunication:
	ld	(zAbsVar.Communication),a
	ret
; ---------------------------------------------------------------------------

; Return (Sonic 1 & 2)
;zloc_D22
zSFX_cfJumpReturn:
	ld	c,(ix+zTrack.StackPointer)		; Get current stack offset -> 'c'
	ld	b,0				; b = 0
	push	ix
	pop	hl				; hl = ix
	add	hl,bc			; hl += bc (latest item on "gosub" stack)
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a				; hl = address from "gosub" stack
	inc	c
	inc	c
	ld	(ix+zTrack.StackPointer),c		; add 2 to "gosub" stack offset (pop)
	ret
; ---------------------------------------------------------------------------

; Per-effect timing divider
zSFX_cfSetTempoDivider:
	ld	(ix+zTrack.TempoDivider),a		; Set tempo divider on this track only
	ret
; ---------------------------------------------------------------------------

; (via Saxman's doc): Change channel volume BY xx; xx is signed
;zloc_DBB cfSetVolume
zSFX_cfChangeFMVolume:
	add	a,(ix+zTrack.Volume)		; Add to current volume
	ld	(ix+zTrack.Volume),a		; Update volume
	jp	zSetChanVol		; Immediately set this new volume
; ---------------------------------------------------------------------------

; (via Saxman's doc): prevent next note from attacking
;zloc_DC4
zSFX_cfPreventAttack:
	set	4,(ix+zTrack.PlaybackControl)		; Set bit 4 (10h) on playback control; do not attack next note
	dec	hl				; Takes no argument, so just put it back
	ret
; ---------------------------------------------------------------------------
; Sets the note fill.
;
; Has one parameter byte, the new note fill. This value is multiplied by the
; tempo divider, and so may overflow.

zSFX_cfNoteFillS3K:
	call	zComputeNoteDuration	; fall through to zSFX_cfNoteFill
; ---------------------------------------------------------------------------

; (via Saxman's doc): set note fill amount to xx
;zloc_DCA
zSFX_cfNoteFill:
	ld	(ix+zTrack.NoteFillTimeout),a		; Note fill value (modifiable)
	ld	(ix+zTrack.NoteFillMaster),a		; Note fill value (master copy, rewrites +0Fh when necessary)
	ret
; ---------------------------------------------------------------------------

; (via Saxman's doc): add xx to channel key
;zloc_DD1 cfAddKey:
zSFX_cfChangeTransposition:
	add	a,(ix+zTrack.Transpose)	; Add to current transpose value
	ld	(ix+zTrack.Transpose),a	; Store updated transpose value
	ret
; ---------------------------------------------------------------------------

; Algorithm carrier masks used for FM effect attenuation.
zVolTLMaskTbl:
	db	  8,  8,  8,  8
	db	0Ch,0Eh,0Eh,0Fh
; ---------------------------------------------------------------------------

; (via Saxman's doc): Change channel volume TO xx; xx is signed (Incorrect, see below)
; However, I've noticed this is incorrect; first of all, you'll notice
; it's still doing an addition, not a forced set.  Furthermore, it's
; not actually altering the FM yet; basically, until the next voice
; switch, this volume change will not come into effect.  Maybe a better
; description of it is "change volume by xx when voice changes", which
; makes sense given some voices are quieter/louder than others, and a
; volume change at voice may be necessary... or my guess anyway.

; Alternatively, just think of it as a volume setting optimized for PSG :P
;zloc_DF9 cfChangeVolume
zSFX_cfChangePSGVolume:
	add	a,(ix+zTrack.Volume)	; Add to channel volume
	ld	(ix+zTrack.Volume),a	; Store updated volume
	ret
; ---------------------------------------------------------------------------

; Ported from S1 EDh
;zlocret_E00 cfUnused cfUnused1
zSFX_cfClearPush:
	dec	hl		; Put back byte
	xor	a		; Clear a
	ld	(zPushFlag),a	; Clear pushing sound flag
	ret
; ---------------------------------------------------------------------------

; Unused command EEh
; This used to be Sonic 1's zSFX_cfStopSpecialFM4. But the Special SFX function hasn't been ported...
;zloc_E01 cfVoiceUNK cfUnused2
zSFX_cfStopSpecialFM4:
	dec	hl		; Put back byte; does nothing
	ret
; ---------------------------------------------------------------------------

; (via Saxman's doc): set voice selection to xx
;zloc_E03
zSFX_cfSetVoice:
	ld	(ix+zTrack.VoiceIndex),a			; Set current voice
	bit	2,(ix+zTrack.PlaybackControl)			; If "SFX is overriding this track" bit set...
	ret	nz					; .. return!
	push	hl				; Save 'hl'
	call	zSetSFXVoice	; Set the new voice!
	pop	hl					; Restore 'hl'
	ret

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


zGetCurrentVoice:
	ld	l,(ix+zTrack.VoicePtrLow)
	ld	h,(ix+zTrack.VoicePtrHigh)
	ld	a,(ix+zTrack.VoiceIndex)
	or	a
	ret	z
	ld	b,a

	ld	de,25

-	add	hl,de
	djnz	-
	ret

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


;zsub_E21
zSetSFXVoice:
	call	zGetCurrentVoice

	; Sets up a value for future Total Level setting...
	ld	a,(hl)				; Get feedback/algorithm -> a
	inc	hl					; next byte of voice...
	ld	(zloc_E65+1),a		; self-modifying code; basically enables 'a' restored to its current value later

	ld	c,a					; a -> c (will be data to YM2612)

	; Don't change pan if being overwritten by DAC SFX
	ld	a,(ix+zTrack.VoiceControl)
	cp	6
	jr	nz,+
	ld	a,(zDACSFXPlaying)
	or	a
	jr	nz,++
+
	ld	a,(ix+zTrack.VoiceControl)			; Get "voice control" byte
	and	3					; only keep bits 0-2 (bit 2 specifies which chip to write to)
	add	a,0B0h				; add to get appropriate feedback/algorithm register
	rst	zWriteFMIorII		; Write new value to appropriate part
+
	; detune/coarse freq, all channels
	sub	80h					; Subtract 80h from 'a' (Detune/coarse frequency of operator 1 register)
	ld	b,4					; Do next 4 bytes (operator 1, 2, 3, and 4)

-	ld	c,(hl)				; Get next detune/coarse freq
	inc	hl					; next voice byte
	rst	zWriteFMIorII		; Write this detune/coarse freq
	add	a,4					; Next detune/coarse freq register
	djnz	-

	push	af				; saving 'a' for much later... will be restored when time to "Total Level"

	; other regs up to just before "Total Level", all channels
	add	a,10h				; we're at 40h+, now at 50h+ (RS/AR of operator 1 register)
	ld	b,10h				; Perform 16 writes (basically goes through RS/AR, AM/D1R, D2R, D1L)

-	ld	c,(hl)				; Get next reg data value
	inc	hl					; next voice byte
	rst	zWriteFMIorII		; Write to FM
	add	a,4					; Next register
	djnz	-

	; Now going to set "stereo output control and LFO sensitivity"
	add	a,24h				; Sets to reg B4h+ (stereo output control and LFO sensitivity)
	ld	c,(ix+zTrack.AMSFMSPan)			; Panning / AMS / FMS settings from track
	rst	zWriteFMIorII		; Write it!

zloc_E65:
	ld	a,0 ; "self-modified code" -- 'a' will actually be set to the feedback/algorithm byte
	and	7					; Only keeping the "algorithm" part of it
	add	a,zVolTLMaskTbl&0FFh		; Adds offset to zVolTLMaskTbl table (low byte only)
	ld	e,a					; Puts this low byte into 'e'
	adc	a,(zVolTLMaskTbl&0FF00h)>>8
	sub	e
	ld	d,a	; Get high byte -> 'd'
	ld	a,(de)				; Get this zVolTLMaskTbl value by algorithm
	ld	(ix+zTrack.VolTLMask),a			; Store this zVolTLMaskTbl value into (ix+1Ah)
	ld	e,a					; Store zVolTLMaskTbl value -> 'e'
	ld	d,(ix+zTrack.Volume)			; Store channel volume -> 'd'
	pop	af					; Restore 'a'; it's now back at appropriate 40h+ register for Total Level setting!

	; Set "Total Levels" (general volume control)
zSetFMTLs:
	ld	b,4					; Loop 4 times (for each Total Level register on this channel)

-	ld	c,(hl)				; Get next TL byte -> c
	inc	hl					; Next voice byte...
	rr	e					; zVolTLMaskTbl value is rotated right; if the bit 0 of this value prior to the rotate was reset (0)...
	jr	nc,+				; ... then we make the jump here (just write the TL value directly, don't modify it)

	; Otherwise, apply channel volume to TL here
	; It's not appropriate to alter ALL TL values, only
	; the ones which are "slots" (output operators)
	push	af				; Save 'a'
	ld	a,d					; Channel volume -> d
	add	a,c					; Add it to the TL value
	ld	c,a					; Modified value -> c
	pop	af					; Restore 'a'
+
	rst	zWriteFMIorII		; Write TL value
	add	a,4					; Next TL reg...
	djnz	-

	ret
; End of function zSetSFXVoice


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


;zsub_E8A
zSetChanVol:
	bit	7,(ix+zTrack.VoiceControl)		; a PSG track
	ret	nz				; If so, quit!
	bit	2,(ix+zTrack.PlaybackControl)		; If playback control byte "SFX is overriding this track" bit set...
	ret	nz				; ... then quit!

	push	hl			; Save 'hl'

	; Get TL address
	call	zGetCurrentVoice
	ld	de,21		; Get TL data
	add	hl,de

	ld	e,(ix+zTrack.VolTLMask)		; zVolTLMaskTbl value from last voice setting (marks which specific TL operators need updating)
	ld	a,(ix+zTrack.VoiceControl)		; Load current voice control byte
	and	3				; Keep only bits 0-2
	add	a,40h			; Add 40h -- appropriate TL register
	ld	d,(ix+zTrack.Volume)		; Get channel volume
	bit	7,d
	call	z,zSetFMTLs	; Set the appropriate Total Levels
	pop	hl				; Restore 'hl'
	ret
; End of function zSetChanVol

; ---------------------------------------------------------------------------

; (via Saxman's doc): F0wwxxyyzz - modulation
;							o	ww - Wait for ww period of time before modulation starts
;							o	xx - Modulation Speed
;							o	yy - Modulation change per Mod. Step
;							o	zz - Number of steps in modulation
;zloc_EB0
zSFX_cfModulation:
	set	3,(ix+zTrack.PlaybackControl)		; Set bit 3 (08h) of "playback control" byte (modulation on)
	dec	hl				; Move 'hl' back one...
	ld	(ix+zTrack.ModulationPtrLow),l		; Back up modulation setting address into (ix+11h), (ix+12h)
	ld	(ix+zTrack.ModulationPtrHigh),h

;zloc_EBB
zSetModulation:
	; Sets up modulation for this track; expects 'hl' to point to modulation
	; configuration info...

	; Heh, using some undoc instructions here...
	ld	a,ixl			; Get lower byte of current track address (ew :P)
	add	a,zTrack.ModulationWait			; ... and add 19 bytes to it
	ld	e,a				; put that into 'e'
	adc	a,ixu			; If carry occurred, add that to upper part of address
	sub	e				; subtract 'e'
	ld	d,a				; Basically, 'd' is now the appropriate upper byte of the address, completing de = (ix + 19)
						; Copying next three bytes
	ld	bc,3
	ldir						; while (bc-- > 0) *de++ = *hl++; (wait, modulation speed, modulation change)
	ld	a,(hl)			; Get Number of steps in modulation
	inc	hl				; Next byte...
	srl	a				; divide number of steps by 2
	ld	(ix+zTrack.ModulationSteps),a		; Store this step count into trackPtr+16h
	bit	4,(ix+zTrack.PlaybackControl)		; Is bit 4 "do not attack next note" (10h) set?
	ret	nz				; If so, quit!
	xor	a				; Clear 'a'
	ld	(ix+zTrack.ModulationValLow),a		; Clear modulation value low byte
	ld	(ix+zTrack.ModulationValHigh),a		; Clear modulation value high byte
	ret
; ---------------------------------------------------------------------------

; (via Saxman's doc): Turn on modulation
;zloc_EDE
zSFX_cfEnableModulation:
	dec	hl
	set	3,(ix+zTrack.PlaybackControl)		; Playback byte bit 3 (08h) -- modulation on
	ret
; ---------------------------------------------------------------------------

; (via Saxman's doc): stop the track
;zloc_EE4
zSFX_cfStopTrack:
	res 7,(ix+zTrack.PlaybackControl)
	res 4,(ix+zTrack.PlaybackControl)
	bit 7,(ix+zTrack.VoiceControl)
	jr nz,.psg
	call zFMNoteOff
	jr .priority
.psg:
	call zPSGNoteOff
.priority:
	push ix
	ld ix,zTracksSFXStart
	ld de,zTrack.len
	ld b,SFX_TRACK_COUNT
-	bit 7,(ix+zTrack.PlaybackControl)
	jr nz,+
	add ix,de
	djnz -
	xor a
	ld (zAbsVar.SFXPriorityVal),a
+	pop ix
	pop bc
	pop bc
	ret
zSFX_cfSetPSGNoise:
	ld	(ix+zTrack.VoiceControl),0E0h		; This is a PSG noise track now!
	ld	(ix+zTrack.PSGNoise),a		; Save PSG noise setting for restoration if SFX overrides it
	bit	2,(ix+zTrack.PlaybackControl)		; If SFX is currently overriding it, don't actually set it!
	ret	nz
	ld	(zPSG),a		; Otherwise, please do
	ret
; ---------------------------------------------------------------------------

; (via Saxman's doc): Turn off modulation
;zloc_F88
zSFX_cfDisableModulation:
	dec	hl				; No parameters used, must back up a byte
	res	3,(ix+zTrack.PlaybackControl)		; Clear "modulation on" bit setting
	ret
; ---------------------------------------------------------------------------

; (via Saxman's doc): Change current PSG tone to xx
;zloc_F8E
zSFX_cfSetPSGTone:
	ld	(ix+zTrack.VoiceIndex),a		; Set current PSG tone
	ret
; ---------------------------------------------------------------------------

; (via Saxman's doc): jump to position yyyy
;zloc_F92
zSFX_cfJumpTo:
	ld	d,(hl)			; Get hight byte of jump destination (since pointer advanced to it)
	ld	e,a				; Put low byte (already retrieved)
	add	hl,de
	ret
; ---------------------------------------------------------------------------

; (via Saxman's doc): $F7xxyyzzzz - repeat section of music
;    * xx - loop index, for loops within loops without confusing the engine.
;          o EXAMPLE: Some notes, then a section that is looped twice, then some more notes, and finally the whole thing is looped three times.
;            The "inner" loop (the section that is looped twice) would have an xx of 01, looking something along the lines of F70102zzzz, whereas the "outside" loop (the whole thing loop) would have an xx of 00, looking something like F70003zzzz.
;    * yy - number of times to repeat
;          o NOTE: This includes the initial encounter of the F7 flag, not number of times to repeat AFTER hitting the flag.
;    * zzzz - position to loop back to
;zloc_F95
zSFX_cfRepeatAtPos:
					; Loop index is in 'a'
	ld	c,(hl)		; Get next byte (number of repeats) -> 'c'
	inc	hl			; Next byte...
	push	hl		; Save 'hl'
	add	a,zTrack.LoopCounters		; Add to make loop index offset (starts at 20h in track memory)
	ld	l,a			; Set hl = offset index
	ld	h,0
	ld	e,ixl		; Set 'de' to beginning of track
	ld	d,ixu
	add	hl,de		; hl is now pointing to track memory offset for this loop
	ld	a,(hl)		; Get loop count at this address
	or	a			; Test it
	jr	nz,+		; If not zero, then skip next step (i.e. we're currently looping)
	ld	(hl),c		; Otherwise, set it to the new number of repeats
+
	dec	(hl)		; One less loop
	pop	hl			; Restore 'hl' (now at the position)
	jr	z,+			; If counted to zero, skip the rest of this (hence start loop count of 1 terminates the loop without ever looping)
	ld	a,(hl)		; Get low byte of jump address
	inc	hl			; Next byte
	ld	d,(hl)		; Get high byte of jump address -> 'd'
	ld	e,a			; Put low byte of jump address -> 'e'
	add	hl,de

	; Note then that this loop command only works AFTER the section you mean to loop

	ret
+
	; If you get here, the loop terminated; just bypass the loop jump address
	inc	hl
	inc	hl
	ret
; ---------------------------------------------------------------------------

; (via Saxman's doc): jump to position yyyy (keep previous position in memory for returning)
;zloc_FB3
zSFX_cfJumpToGosub:
	ld	c,a			; a -> c
	ld	a,(ix+zTrack.StackPointer)	; Get current "stack" offset (starts at 2Ah, i.e. beginning of next track)
	sub	2			; Move back by two (we need to store a new return address)
	ld	(ix+zTrack.StackPointer),a	; Set current stack offset
	ld	b,(hl)		; Get high byte of jump position -> 'b'
	inc	hl			; Next byte...
	ex	de,hl		; hl <=> de
	add	a,ixl		; Add low byte of current track pointer to stack offset (low byte of stack location)
	ld	l,a			; Keep this in 'l'
	adc	a,ixu		; Update high byte, if necessary
	sub	l			; Fixup
	ld	h,a			; a -> 'h' (Simply, we just did hl = ix + stack_offset)
	ld	(hl),e		; Store current address low byte (just after jump) into stack
	inc	hl			; Next byte
	ld	(hl),d		; Store current address high byte (just after jump) into stack
	ld	h,b
	ld	l,c			; hl = bc (current location is where you wanted to jump to)
	add	hl,de
	ret
; ---------------------------------------------------------------------------

; Leftover from Sonic 1: was used in SYZ's music.
;zloc_FCC
zSFX_cfOpF9:
	ld	a,88h		; D1L/RR of Operator 3
	ld	c,0Fh		; Loaded with fixed value (max RR, 1TL?)
	rst	zWriteFMI	; Written to part I
	ld	a,8Ch		; D1L/RR of Operator 4
	ld	c,0Fh		; Loaded with fixed value (max RR, 1TL?)
	rst	zWriteFMI	; Written to part I
	dec	hl			; Doesn't take an arg, so put back one byte
	ret

; ---------------------------------------------------------------------------
; This the note -> frequency setting lookup
; the same array is found at $729CE in Sonic 1, and at $C9C44 in Ristar
; zword_359:
zPSGFrequencies:
		; This table starts with 12 notes not in S1 or S2:
	dw	3FFh, 3FFh, 3FFh, 3FFh, 3FFh, 3FFh, 3FFh, 3FFh, 3FFh, 3F7h, 3BEh, 388h
	dw	356h, 326h, 2F9h, 2CEh, 2A5h, 280h, 25Ch, 23Ah, 21Ah, 1FBh, 1DFh, 1C4h
	dw	1ABh, 193h, 17Dh, 167h, 153h, 140h, 12Eh, 11Dh, 10Dh, 0FEh, 0EFh, 0E2h
	dw	0D6h, 0C9h, 0BEh, 0B4h, 0A9h, 0A0h,  97h,  8Fh,  87h,  7Fh,  78h,  71h
	dw	 6Bh,  65h,  5Fh,  5Ah,  55h,  50h,  4Bh,  47h,  43h,  40h,  3Ch,  39h
	dw	 36h,  33h,  30h,  2Dh,  2Bh,  28h,  26h,  24h,  22h,  20h,  1Fh,  1Dh
	dw	 1Bh,  1Ah,  18h,  17h,  16h,  15h,  13h,  12h,  11h,    0,    0,    0
; lookup table of FM note frequencies for instruments and sound effects
; zbyte_534:
zFrequencies:
	dw 025Eh,0284h,02ABh,02D3h,02FEh,032Dh,035Ch,038Fh,03C5h,03FFh,043Ch,047Ch
; ---------------------------------------------------------------------------
;zbyte_FD8h
;zSFXPriority:
; zSFXPriority is now a part of SoundIndex

; zoff_1029:
;zPSG_Index
zPSG_FlutterTbl:
	; Basically, for any tone 0-11, dynamic volume adjustments are applied to produce a pseudo-decay,
	; or sometimes a ramp up for "soft" sounds, or really any other volume effect you might want!

	; Remember on PSG that the higher the value, the quieter it gets (it's attenuation, not volume);
	; 0 is thus loudest, and increasing values decay, until level $F (silent)

	dw	zSFX_byte_1043, zSFX_byte_105A, zSFX_byte_1061, zSFX_byte_1072
	dw	zSFX_byte_108C, zSFX_byte_107D, zSFX_byte_10B6, zSFX_byte_10D2
	dw	zSFX_byte_10FA, zSFX_byte_110B, zSFX_byte_1149, zSFX_byte_1165
	dw	zSFX_byte_11E5
zSFX_byte_1043:
	db	0,0,0,1,1,1,2,2,2,3,3,3,4,4,4,5
	db	5,5,6,6,6,7,80h
zSFX_byte_105A:
	db	0,2,4,6,8,10h,80h
zSFX_byte_1061:
	db	0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,80h
zSFX_byte_1072:
	db	0,0,2,3,4,4,5,5,5,6,80h
zSFX_byte_107D:
	db	3,3,3,2,2,2,2,1,1,1,0,80h
zSFX_byte_108C:
	db	0,0,0,0,0,0,0,0,0,0,1,1
	db	1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2
	db	2,2,2,2,3,3,3,3,3,3,3,3,4,80h
zSFX_byte_10B6:
	db	0,0,0,0,0,0,1,1,1,1,1,2,2,2,2,2
	db	3,3,3,4,4,4,5,5,5,6,7,80h
zSFX_byte_10D2:
	db	0,0,0,0,0,1,1,1,1,1,2,2,2,2,2,2
	db	3,3,3,3,3,4,4,4,4,4,5,5,5,5,5,6
	db	6,6,6,6,7,80h
zSFX_byte_10FA:
	db	0,1,2,3,4,5,6,7,8,9,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh,80h
zSFX_byte_110B:
	db	0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1
	db	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
	db	1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2
	db	2,2,3,3,3,3,3,3,3,3,3,3,4,80h
zSFX_byte_1149:
	db	4,4,4,3,3,3,2,2,2,1,1,1,1,1,1,1
	db	2,2,2,2,2,3,3,3,3,3,4,80h
zSFX_byte_1165:
	db	4,4,3,3,2,2,1,1,1,1,1,1,1,1,1,1
	db	1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2
	db	2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,3
	db	3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
	db	3,3,4,4,4,4,4,4,4,4,4,4,4,4,4,4
	db	4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5
	db	5,5,5,5,5,5,5,5,5,5,6,6,6,6,6,6
	db	6,6,6,6,6,6,6,6,6,6,6,6,6,6,7,80h
zSFX_byte_11E5:
	db	0Eh,0Dh,0Ch,0Bh,0Ah,9,8,7,6,5,4,3,2,1,0,80h

;	END of zPSG_FlutterTbl ---------------------------

	;align	100h	; TODO: without this, ensure1byteoffset below throws a warning (?) that prevents the ROM from building??

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

; Cooperate with the MD sequencer at a complete FM/SFX update boundary.
zEnterFMSection:
	ld a,1
	ld (zAbsVar.FMBusy),a
	ld a,(zAbsVar.MDLock)
	or a
	ret z
	xor a
	ld (zAbsVar.FMBusy),a
.wait:
	ld a,(zAbsVar.MDLock)
	or a
	jr nz,.wait
	jr zEnterFMSection
zLeaveFMSection:
	ld a,2Ah
	ld (zYM2612_A0),a
	xor a
	ld (zAbsVar.FMBusy),a
	ret

zAbortDAC:
	xor a
	ld (zAbsVar.StopDAC),a
	ld (zHighPriorityDACPlaying),a
	ld (zDACSFXPlaying),a
	ld a,80h
	ld (zYM2612_D0),a
	pop hl
	pop de
	pop bc
	pop af
	ld de,0
	ld b,1
	ei
	ret
zDAC_SFX_DriverEnd:
	if (MOMPASS>1)&&($>zStack-20h)
		fatal "Z80 DAC/SFX code overlaps its stack"
	endif
	if MOMPASS=1
		message "Z80 DAC/SFX driver: $\{$} bytes."
	endif
