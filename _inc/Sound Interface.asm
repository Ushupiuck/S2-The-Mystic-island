; Mega Drive main-68000 audio boundary.
; CloneDriver sequences music; the retained Z80 owns DAC streaming and SFX.
; Compressed songs use the existing Mega-CD decoder before a prepared-buffer
; pointer is published to the interrupt-driven FM/PSG sequencer.
SMPS_QueueSound1 = PlayMusic
SMPS_QueueSound2 = PlaySound
SMPS_QueueSound3 = PlaySound_Special

SoundMusicEntry macro source,stored,decoded,flags
	dc.l source
	dc.w stored,decoded
	dc.b flags,0
	endm

Sound_Setup:
	movem.l d0-a6,-(sp)
	bsr.w Sound_AcquireZ80
	lea (Clone_Driver_RAM).l,a6
	jsr (Clone_StopAllSound).l
	btst #6,(HW_Version).l
	beq.s .ntsc
	bset #f_pal,SMPS_RAM.bitfield1(a6)
.ntsc:
	move.b #1,(Sound_Initialized).l
	bsr.w Sound_ReleaseZ80
	movem.l (sp)+,d0-a6
	rts

; Queue writes are byte-sized and never perform CD work or touch YM ports.
PlaySoundLocal:
	tst.b obRender(a0)
	bpl.s Sound_QueueReturn
PlaySound:
	cmpi.b #MusID__End,d0
	blo.s PlayMusic
	cmpi.b #CmdID__First,d0
	bhs.s Sound_QueueControl
	move.b d0,(Sound_SFXNormal).l
Sound_QueueReturn:
	rts
PlaySoundStereo:
	move.b d0,(Sound_SFXStereo).l
	rts
PlaySound_Special:
	cmpi.b #MusID__End,d0
	blo.s PlayMusic
	cmpi.b #CmdID__First,d0
	bhs.s Sound_QueueControl
	move.b d0,(Sound_SFXImmediate).l
	rts
PlayMusic:
	cmpi.b #MusID__First,d0
	blo.s Sound_QueueReturn
	cmpi.b #MusID__End,d0
	bhs.s PlaySound_Special
	tst.b (Sound_PendingSong).l
	bne.s .second
	move.b d0,(Sound_PendingSong).l
	rts
.second:
	move.b d0,(Sound_PendingSong2).l
	rts
Sound_QueueControl:
	cmpi.b #MusID_Stop,d0
	bne.s .queue
	clr.b (Sound_PendingSong).l
	clr.b (Sound_PendingSong2).l
	clr.b (Sound_ReadySong).l
.queue:
	tst.b (Clone_Driver_RAM+SMPS_RAM.variables.queue.v_playsnd1).l
	bne.s .second
	move.b d0,(Clone_Driver_RAM+SMPS_RAM.variables.queue.v_playsnd1).l
	rts
.second:
	move.b d0,(Clone_Driver_RAM+SMPS_RAM.variables.queue.v_playsnd4).l
	rts

ChangeMusicTempo:
	move.b d0,(Sound_TempoAdjust).l
	rts
ResetMusicTempo:
	clr.b (Sound_TempoAdjust).l
	clr.b (Sound_SpeedClock).l
	rts
PauseSoundDriver:
	move.b #1,(Clone_Driver_RAM+SMPS_RAM.f_pause).l
	rts
UnpauseSoundDriver:
	move.b #$80,(Clone_Driver_RAM+SMPS_RAM.f_pause).l
	rts

; Main-thread only. The busy flag prevents nested waits from preparing a
; second song or the audio interrupt from following a buffer being replaced.
Sound_PrepareMusic:
	tst.b (Sound_Initialized).l
	beq.w .return
	tst.b (Sound_LoadBusy).l
	bne.w .return
	tst.b (Sound_ReadySong).l
	bne.w .return
	tst.b (Sound_PendingSong).l
	beq.w .return
	movem.l d0-a6,-(sp)
	move.w sr,-(sp)
	disable_ints
	moveq #0,d5
	move.b (Sound_PendingSong).l,d5
	move.b (Sound_PendingSong2).l,(Sound_PendingSong).l
	clr.b (Sound_PendingSong2).l
	move.b #1,(Sound_LoadBusy).l
	move.w (sp),sr
	move.w d5,d0
	subq.w #MusID__First,d0
	mulu.w #Sound_MusicEntry.len,d0
	lea (MusicIndex).l,a2
	adda.l d0,a2
	movea.l Sound_MusicEntry.Source(a2),a0
	lea (Sound_MusicBuffer).l,a1
	btst #Sound_MusicJingle,Sound_MusicEntry.Flags(a2)
	beq.s .destination
	lea (Sound_JingleBuffer).l,a1
.destination:
	move.l a1,(Sound_ReadyBuffer).l
	move.b Sound_MusicEntry.Flags(a2),(Sound_ReadyFlags).l
	move.w Sound_MusicEntry.DecodedSize(a2),(Sound_ReadySize).l
	btst #Sound_MusicCompressed,Sound_MusicEntry.Flags(a2)
	beq.s .raw
	jsr (KosPlusDec).l
	bra.s .ready
.raw:
	move.w Sound_MusicEntry.DecodedSize(a2),d0
	subq.w #1,d0
.copy:
	move.b (a0)+,(a1)+
	dbf d0,.copy
.ready:
	disable_ints
	move.b d5,(Sound_ReadySong).l
	clr.b (Sound_LoadBusy).l
	move.w (sp)+,sr
	movem.l (sp)+,d0-a6
.return:
	rts

Sound_GetMusicFlags:
	moveq #0,d0
	move.b d7,d0
	subq.w #MusID__First,d0
	mulu.w #Sound_MusicEntry.len,d0
	lea (MusicIndex).l,a0
	move.b Sound_MusicEntry.Flags(a0,d0.w),d0
	rts
Sound_LoadPreparedMusic:
	movea.l (Sound_ReadyBuffer).l,a4
	move.b (Sound_ReadyFlags).l,(Sound_CurrentFlags).l
	move.b (Sound_ReadySong).l,(Sound_CurrentSong).l
	clr.b (Sound_ReadySong).l
	rts
Sound_MusicRestored:
	move.b (Sound_BackedSong).l,(Sound_CurrentSong).l
	moveq #0,d0
	move.b (Sound_CurrentSong).l,d0
	beq.s .return
	subq.w #MusID__First,d0
	mulu.w #Sound_MusicEntry.len,d0
	lea (MusicIndex).l,a0
	move.b Sound_MusicEntry.Flags(a0,d0.w),(Sound_CurrentFlags).l
.return:
	rts

; Enter only when the Z80 is outside its FM/SFX register-pair section.
; The worker rechecks MDLock after publishing FMBusy, closing the entry race.
Sound_AcquireZ80:
	stopZ80
	waitZ80
	move.b #1,(Z80_RAM+zAbsVar.MDLock).l
.wait:
	tst.b (Z80_RAM+zAbsVar.FMBusy).l
	beq.s .owned
	startZ80
	nop
	nop
	stopZ80
	waitZ80
	bra.s .wait
.owned:
	rts
Sound_ReleaseZ80:
	move.b #$2A,(SMPS_ym2612_a0).l
	clr.b (Z80_RAM+zAbsVar.MDLock).l
	startZ80
	rts

Sound_Update:
	tst.b (Sound_Initialized).l
	beq.w .return
	tst.b (Sound_LoadBusy).l
	bne.w .return
	tst.b (Sound_UpdateRunning).l
	bne.w .return
	move.b #1,(Sound_UpdateRunning).l
	movem.l d0-a6,-(sp)
	move.w sr,-(sp)
	disable_ints
	bsr.w Sound_AcquireZ80
	; Raster palette interrupts contain no YM/PSG or Z80-bus operations.
	; Let them preempt sequencing; each YM register/data pair masks IRQs.
	move.w #$2300,sr
	lea (Clone_Driver_RAM).l,a6
	bsr.w Sound_SyncSFXChannels
	tst.b (Sound_ReadySong).l
	beq.s .tick
	move.b (Sound_ReadySong).l,SMPS_RAM.variables.queue.v_playsnd1(a6)
.tick:
	jsr (SMPS_UpdateDriver).l
	tst.b SMPS_RAM.f_pause(a6)
	bne.s .publish
	tst.b (Sound_TempoAdjust).l
	beq.s .publish
	btst #Sound_MusicNoSpeedUp,(Sound_CurrentFlags).l
	bne.s .publish
	addq.b #1,(Sound_SpeedClock).l
	move.b (Sound_TempoAdjust).l,d0
	cmp.b (Sound_SpeedClock).l,d0
	bhi.s .publish
	clr.b (Sound_SpeedClock).l
	jsr (Clone_UpdateMusic).l
.publish:
	move.b SMPS_RAM.variables.bitfield2(a6),d0
	andi.b #1<<f_1up_playing,d0
	move.b d0,(Z80_RAM+zAbsVar.1upPlaying).l
	move.b SMPS_RAM.variables.v_fadein_counter(a6),(Z80_RAM+zAbsVar.FadeInFlag).l
	tst.b (Sound_SFXNormal).l
	beq.s .stereo
	move.b (Sound_SFXNormal).l,(Z80_RAM+zAbsVar.SFXUnknown).l
	clr.b (Sound_SFXNormal).l
.stereo:
	tst.b (Sound_SFXStereo).l
	beq.s .immediate
	move.b (Sound_SFXStereo).l,(Z80_RAM+zAbsVar.SFXStereoToPlay).l
	clr.b (Sound_SFXStereo).l
.immediate:
	tst.b (Sound_SFXImmediate).l
	beq.s .release
	move.b (Sound_SFXImmediate).l,(Z80_RAM+zAbsVar.QueueToPlay).l
	clr.b (Sound_SFXImmediate).l
.release:
	bsr.w Sound_ReleaseZ80
	clr.b (Sound_UpdateRunning).l
	move.w (sp)+,sr
	movem.l (sp)+,d0-a6
.return:
	rts

; Actual Z80 track flags own the shared channels. Sequencing continues while
; overridden; only hardware output yields. Release restores the current voice.
Sound_SyncSFXChannels:
	movem.l d0-d7/a0-a5,-(sp)
	lea (Z80_RAM+zSFX_FM3).l,a1
	lea .tracks(pc),a2
	moveq #SFX_TRACK_COUNT-1,d7
.loop:
	move.w (a2)+,d0
	lea (a6,d0.w),a5
	tst.b (a1)
	bpl.s .released
	bset #2,SMPS_Track.PlaybackControl(a5)
	bra.s .next
.released:
	bclr #2,SMPS_Track.PlaybackControl(a5)
	beq.s .next
	tst.b SMPS_Track.PlaybackControl(a5)
	bpl.s .next
	bset #1,SMPS_Track.PlaybackControl(a5)
	tst.b SMPS_Track.VoiceControl(a5)
	bmi.s .psg
	movem.l d7/a1-a2,-(sp)
	moveq #0,d0
	move.b SMPS_Track.VoiceIndex(a5),d0
	movea.l SMPS_Track.VoicePtr(a5),a1
	jsr (Clone_SetVoice).l
	movem.l (sp)+,d7/a1-a2
	bra.s .next
.psg:
	cmpi.b #$E0,SMPS_Track.VoiceControl(a5)
	bne.s .next
	move.b SMPS_Track.PSGNoise(a5),(psg_input).l
.next:
	lea zTrack.len(a1),a1
	dbf d7,.loop
	; DAC effects own FM6 as well as the DAC. They may change DAC enable and
	; panning without touching FM6's instrument; restore ownership at the next
	; music note when the sample has ended.
	tst.b (Z80_RAM+zDACSFXPlaying).l
	beq.s .dac_released
	bset #2,SMPS_RAM.v_music_dac_track.PlaybackControl(a6)
	bset #2,SMPS_RAM.v_music_fm6_track.PlaybackControl(a6)
	bra.s .done
.dac_released:
	bclr #2,SMPS_RAM.v_music_dac_track.PlaybackControl(a6)
	beq.s .done
	bclr #2,SMPS_RAM.v_music_fm6_track.PlaybackControl(a6)
	bset #6,SMPS_RAM.v_music_dac_track.PlaybackControl(a6)
	bset #6,SMPS_RAM.v_music_fm6_track.PlaybackControl(a6)
.done:
	movem.l (sp)+,d0-d7/a0-a5
	rts
.tracks:
	dc.w SMPS_RAM.v_music_fm3_track,SMPS_RAM.v_music_fm4_track,SMPS_RAM.v_music_fm5_track
	dc.w SMPS_RAM.v_music_psg1_track,SMPS_RAM.v_music_psg2_track,SMPS_RAM.v_music_psg3_track
