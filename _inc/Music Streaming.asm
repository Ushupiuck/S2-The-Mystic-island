; Mega Drive 68000. Prepare complete scores on the main thread and fill the
; Z80's read-only pages when requested. The CD owns Kos+.
musprop_uncompressed	= 1<<4
musprop_nospeedup	= 1<<5
musprop_palmode		= 1<<6
musprop_1up		= 1<<7

; Bias the eight-byte playlist so the song ID is the index.
Music_IndexByID = Music_Index-(MusID__First<<3)

MusicEntry macro source,size,flags
	dc.l	source
	dc.w	size
	dc.b	flags,0
	endm

MusicPacked macro filename
	binclude	filename
	endm

; PlayMusic/PlaySound already own the bus. Publish a cached score now so
; resurfacing and other common returns can use the very next sound tick.
Music_QueueHint:
		move.b	d0,(Music_PendingSong).l
		tst.b	(Z80_RAM+zMusicSlotBusy).l
		bne.s	.return
		tst.b	(Music_LoadBusy).l
		bne.s	.return
		movem.l	d1-d2/a1,-(sp)
		lea	(Music_StageSongs).l,a1
		moveq	#1,d2
		rept	Music_StageCount-1
		cmp.b	(a1)+,d0
		beq.s	.cached
		addq.b	#1,d2
		endm
		cmp.b	(a1),d0
		bne.s	.done
.cached:
		moveq	#0,d1
		move.b	d0,d1
		lsl.w	#3,d1
		lea	(Music_IndexByID+6).l,a1
		move.b	(a1,d1.w),(Z80_RAM+zMusicReadyFlags).l
		move.b	d2,(Z80_RAM+zMusicReadySlot).l
		move.b	d0,(Z80_RAM+zMusicReadySong).l
		clr.b	(Music_PendingSong).l
.done:
		movem.l	(sp)+,d1-d2/a1
.return:
		rts

; Prepare the latest queue hint, or an ID requested by KeH after arbitration.
; A slot remains immutable while it is live or saved for a 1-up return.
Music_Prepare:
		tst.b	(Music_PendingSong).l
		beq.s	Music_QueueHint.return
		tst.b	(Music_LoadBusy).l
		bne.s	Music_QueueHint.return
		movem.l	d0-d1/d4-d7/a0-a2,-(sp)
		move.w	sr,-(sp)
		disable_ints
		stopZ80
		waitZ80
		tst.b	(Z80_RAM+zMusicSlotBusy).l
		bne.w	.release
		moveq	#0,d7
		move.b	(Music_PendingSong).l,d7
		clr.b	(Music_PendingSong).l
		cmp.b	(Z80_RAM+zMusicReadySong).l,d7
		beq.w	.release

		; A previously decoded song can be published again in place.
		lea	(Music_StageSongs).l,a2
		moveq	#Music_StageCount-1,d6
.findCached:
		cmp.b	(a2)+,d7
		dbeq	d6,.findCached
		beq.w	.cached

		moveq	#1,d6
		move.b	(Z80_RAM+zAbsVar.MusicSlot).l,d0
		moveq	#0,d1
		tst.b	(Z80_RAM+zAbsVar.1upPlaying).l
		beq.s	.findSlot
		move.b	(Z80_RAM+zSaveVar.MusicSlot).l,d1
.findSlot:
		cmp.b	d0,d6
		beq.s	.nextSlot
		cmp.b	d1,d6
		bne.s	.slot
.nextSlot:
		addq.b	#1,d6
		bra.s	.findSlot
.slot:
		lea	(Music_StageSongs-1).l,a2
		clr.b	(a2,d6.w)
		clr.b	(Z80_RAM+zMusicReadySong).l
		st	(Music_LoadBusy).l
		startZ80
		move.w	(sp),sr

		move.w	d7,d0
		lsl.w	#3,d0
		lea	(Music_IndexByID).l,a2
		adda.w	d0,a2
		movea.l	(a2)+,a0
		move.w	(a2)+,d4
		move.b	(a2),d5
		move.w	d6,d0
		ror.w	#16-Music_StageShift,d0	; one-based slot times stage capacity
		lea	(Music_StageData-Music_StageCapacity).l,a1
		adda.w	d0,a1
		btst	#4,d5
		bne.s	.raw
		bsr.w	KosPlusDec
.pad:
		; A read may peek a byte past the last event on the final page.
		neg.w	d4
		andi.w	#Music_PageSize-1,d4
		subq.w	#1,d4
		bmi.s	.publish
.padByte:
		clr.b	(a1)+
		dbf	d4,.padByte
.publish:
		disable_ints
		stopZ80
		waitZ80
		lea	(Music_StageSongs-1).l,a2
		move.b	d7,(a2,d6.w)
		clr.b	(Music_LoadBusy).l
		bra.s	.publishHeld
.cached:
		neg.w	d6
		addq.w	#Music_StageCount,d6
		move.w	d7,d0
		lsl.w	#3,d0
		lea	(Music_IndexByID+6).l,a2
		move.b	(a2,d0.w),d5
.publishHeld:
		move.b	d5,(Z80_RAM+zMusicReadyFlags).l
		move.b	d6,(Z80_RAM+zMusicReadySlot).l
		move.b	d7,(Z80_RAM+zMusicReadySong).l
.release:
		startZ80
		move.w	(sp)+,sr
		movem.l	(sp)+,d0-d1/d4-d7/a0-a2
		rts
.raw:
		move.w	d4,d0
		subq.w	#1,d0
.copyRaw:
		move.b	(a0)+,(a1)+
		dbf	d0,.copyRaw
		bra.s	.pad

; Spend the existing PAL delay servicing pending pages. Leave full uploads
; of short scores for the ordinary VBlank exit.
Music_WaitPAL:
		tst.b	(Music_ServiceReady).l
		beq.s	.legacy
		cmpi.b	#MCD_StatusReady,(MCD_status).w
		beq.s	.ready
.legacy:
		move.w	#$700,d0
		dbf	d0,*
		rts
.ready:
		lea	(Music_BusSignal).l,a4
		move.w	(MCD_MainStopwatch).l,d6
.poll:
		move.w	(MCD_MainStopwatch).l,d5
		sub.w	d6,d5
		andi.w	#$FFF,d5
		cmpi.w	#60,d5		; leave time for one worst-case page fill
		bhs.s	.wait
		moveq	#0,d0
		move.b	(a4),d0
		subq.b	#1,d0
		cmpi.b	#Music_PageCount,d0
		bhs.s	.poll
		stopZ80
		waitZ80
		tst.b	(Z80_RAM+zMusicCacheValid).l
		bne.s	.fill
		moveq	#0,d4
		move.b	(Z80_RAM+zAbsVar.MusicSlot).l,d4
		bsr.w	Music_GetStageScore
		cmpi.w	#Music_CacheSlots*Music_PageSize,d1
		bls.s	.release
.fill:
		bsr.w	Music_FillPage
		clr.b	(a4)
		startZ80
		bra.s	.poll
.release:
		startZ80
.wait:
		move.w	(MCD_MainStopwatch).l,d5
		sub.w	d6,d5
		andi.w	#$FFF,d5
		cmpi.w	#76,d5		; about 2.34 ms, like the former DBF
		blo.s	.wait
		rts

; The Z80 posts a page number, a song ID with bit 7 set, or a lookahead hint.
; The caller has seen a request. Recheck after masking interrupts because
; VBlank can service it before a foreground caller gets here. Hold the Z80
; while taking the request so a new page can't replace an earlier song ID.
Music_Service:
		disableIntsSave
		lea	(Music_BusSignal).l,a4
		tst.b	(a4)
		beq.s	.return
		stopZ80
		waitZ80
		moveq	#0,d0
		move.b	(a4),d0
		cmpi.b	#Music_PageCount,d0
		bhi.s	.songOrHint
		subq.w	#1,d0
		bsr.w	Music_FillPage
.release:
		clr.b	(a4)
.resume:
		startZ80
.return:
		enableIntsSave
		rts
.songOrHint:
		cmpi.b	#Music_LookaheadSignal,d0
		beq.s	.lookahead
		tst.b	(Music_PendingSong).l
		bne.s	.release
		andi.b	#$7F,d0
		cmp.b	(Z80_RAM+zMusicSongRequest).l,d0
		bne.s	.release
		move.b	d0,(Music_PendingSong).l
		bra.s	.release

.lookahead:
		; Leave the next Z80 VBlank IRQ room even if all six pages miss.
		; VBlank itself is reserved for the VDP and mandatory refills.
		btst	#3,(vdp_control_port+1).l
		bne.s	.release
		moveq	#0,d0
		move.b	(vdp_control_port+4).l,d0
		cmpi.b	#168,d0
		bhs.s	.release
		; A six-page prefetch must also finish before an upcoming water split.
		; Retain this optional hint until the split has run or a tick replaces it.
		tst.b	(Water_flag).w
		beq.s	.hintReady
		moveq	#0,d1
		move.b	(v_hbla_pal_line).w,d1
		cmpi.b	#224-1,d1
		beq.s	.hintReady
		sub.w	d0,d1
		bls.s	.hintReady
		cmpi.w	#56,d1
		blo.s	.resume
.hintReady:
		; A hint expires as soon as a new tick starts.
		tst.b	(Z80_RAM+zMusicTickBusy).l
		bne.s	.release
		cmpi.b	#Music_ScoreBase>>8,(Z80_RAM+zMusicReadBase+1).l
		bne.s	.release
		bsr.s	Music_Prefetch
		bra.s	.release

; A new score has no track state yet. Prime its header, opening command
; spans and selected instruments in one grant, after KeH has stopped using
; the old cache. Do not overwrite a playing score while preparing MD slots.
Music_PrefetchStart:
		movem.l	d5-d7/a5-a6,-(sp)
		movea.l	a0,a5
		moveq	#0,d7
		move.b	2(a5),d7
		add.b	3(a5),d7
		subq.w	#1,d7
		bmi.s	.done
		lea	6(a5),a6
		moveq	#Music_CacheSlots-1,d6
.track:
		moveq	#0,d0
		move.b	1(a6),d0
		lsl.w	#8,d0
		move.b	(a6),d0
		move.w	a6,d1
		sub.w	a5,d1
		addq.w	#2,d1
		add.w	d1,d0			; relative to the end of the pointer
		moveq	#31,d5
		bsr.s	Music_PrefetchTrack
		tst.w	d6
		beq.s	.done
		lea	4(a6),a6
		moveq	#0,d1
		move.b	3(a5),d1
		cmp.w	d1,d7
		bhs.s	.next
		addq.w	#2,a6			; PSG headers also have tone/unused bytes
.next:
		dbf	d7,.track
.done:
		movem.l	(sp)+,d5-d7/a5-a6
		rts

; A track has reached a branch or page boundary. Read nearby held cursors
; from the staged score and fill up to six pages in this one bus grant.
Music_Prefetch:
		movem.l	d5-d7/a5-a6,-(sp)
		bsr.w	Music_GetStage
		movea.l	a0,a5
		lea	(Z80_RAM+zTracksStart).l,a6
		moveq	#MUSIC_TRACK_COUNT-1,d7
		moveq	#6,d6
.track:
		btst	#7,zTrack.PlaybackControl(a6)
		beq.s	.next
		move.b	zTrack.DurationTimeout(a6),d0
		subq.b	#1,d0
		cmpi.b	#16,d0
		bhs.s	.next
		moveq	#0,d0
		move.b	zTrack.DataPointerHigh(a6),d0
		lsl.w	#8,d0
		move.b	zTrack.DataPointerLow(a6),d0
		subi.w	#Music_ScoreBase,d0
		moveq	#7,d5
		bsr.s	Music_PrefetchTrack
		tst.w	d6
		beq.s	.done
.next:
		lea	zTrack.len(a6),a6
		dbf	d7,.track
.done:
		movem.l	(sp)+,d5-d7/a5-a6
		rts

; Follow commands to the next timed event. d5 bounds command traversal;
; d6 bounds missing pages. a5 is the immutable decoded score.
Music_PrefetchTrack:
.command:
		cmpi.w	#Music_StageCapacity-5,d0
		bhs.s	.done
		bsr.w	Music_PrefetchPage
		beq.s	.done
		move.w	d0,-(sp)
		addq.w	#4,d0			; command parameters/note duration may straddle
		bsr.w	Music_PrefetchPage
		move.w	(sp)+,d0
		tst.w	d6
		beq.s	.done
		lea	(a5,d0.w),a3
		moveq	#0,d1
		move.b	(a3),d1
		subi.b	#$E0,d1
		cmpi.b	#$1B,d1
		bhs.s	.done			; reached a note or duration
		moveq	#0,d2
		lea	Music_PrefetchLengths(pc),a2
		move.b	(a2,d1.w),d2
		beq.s	.done			; return, stop, or a counted loop
		cmpi.b	#$16,d1
		beq.s	.jump
		cmpi.b	#$18,d1
		beq.s	.call
		cmpi.b	#$F,d1
		beq.s	.voice
		add.w	d2,d0
.advance:
		dbf	d5,.command
.done:
		rts
.call:
		addq.w	#1,d0
.jump:
		move.b	2(a3),d1
		lsl.w	#8,d1
		move.b	1(a3),d1
		addq.w	#2,d0
		add.w	d1,d0
		bra.s	.advance		; follow nested calls to the first timed event

.voice:
		moveq	#0,d1
		move.b	1(a3),d1
		mulu.w	#25,d1
		moveq	#0,d2
		move.b	1(a5),d2
		lsl.w	#8,d2
		move.b	(a5),d2
		add.w	d2,d1
		cmpi.w	#Music_StageCapacity-25,d1
		bhi.s	.skipVoice
		move.w	d0,-(sp)
		move.w	d1,d0
		bsr.w	Music_PrefetchPage
		beq.s	.voiceDone
		addi.w	#24,d0
		bsr.w	Music_PrefetchPage
.voiceDone:
		move.w	(sp)+,d0
		tst.w	d6
		beq.s	.done
.skipVoice:
		addq.w	#2,d0
		bra.s	.advance

; d0 is an offset in the live score. Return Z if the fill budget is spent.
Music_PrefetchPage:
		move.w	d0,d1
		lsr.w	#Music_PageShift,d1
		lea	(Z80_RAM+zMusicPageMap).l,a1
		tst.b	(a1,d1.w)
		bne.s	.return
		move.w	d0,-(sp)
		move.w	d1,d0
		movea.l	a5,a0
		bsr.w	Music_FillStagedPage
		bset	#5,(a1,d0.w)
		move.b	#(Music_ScoreBase+Music_StageCapacity)>>8,(Z80_RAM+zReadScoreLastHigh+1).l
		move.w	(sp)+,d0
		subq.w	#1,d6
.return:
		rts

Music_PrefetchLengths:
		dc.b	2,2,2,0,0,2,2,1,2,2,2,2,2,1,1,2
		dc.b	5,1,0,2,1,2,3,0,3,1,2
		even

; The foreground and CD waits retain their live registers across a refill.
Music_ServiceSave:
		movem.l	d0-d4/a0-a4,-(sp)
		bsr.w	Music_Service
		movem.l	(sp)+,d0-d4/a0-a4
		rts

Music_GetStage:
		moveq	#0,d4
		move.b	(Z80_RAM+zAbsVar.MusicSlot).l,d4
		move.w	d4,d1
		ror.w	#16-Music_StageShift,d1
		lea	(Music_StageData-Music_StageCapacity).l,a0
		adda.w	d1,a0
		rts

; d0.w is a virtual page index. Bus is granted until the map byte is written.
Music_FillPage:
		bsr.s	Music_GetStage
		tst.b	(Z80_RAM+zMusicCacheValid).l
		bne.s	Music_FillStagedPage
		move.l	a0,-(sp)
		bsr.s	Music_FillStagedPage
		movea.l	(sp)+,a0
		cmpi.b	#Music_ScoreBase>>8,(Z80_RAM+zMusicReadBase+1).l
		bne.s	.return
		tst.b	(Z80_RAM+zMusicStarting).l
		beq.s	.return
		bra.w	Music_PrefetchStart
.return:
		rts
Music_FillStagedPage:
		lea	(Z80_RAM+zMusicPageMap).l,a1
		lea	(Music_PageTags).l,a2
		tst.b	(Z80_RAM+zMusicCacheValid).l
		bne.s	.keepCache
		bsr.w	Music_GetStageScore
		cmpi.w	#Music_CacheSlots*Music_PageSize,d1
		bls.w	.resident
		move.b	#Music_ScoreBase&$FF,(Z80_RAM+zMusicReadBase).l
		move.b	#Music_ScoreBase>>8,(Z80_RAM+zMusicReadBase+1).l
		cmp.b	(Music_CacheSong).l,d4
		beq.s	.reuseCache
		move.b	d4,(Music_CacheSong).l
		moveq	#Music_CacheSlots-1,d3
		bsr.w	Music_ClearSlots
		; Keep the first instrument pages out of the track-page clock.
		; These patches are shared by all FM channels and reused across sections.
		moveq	#0,d1
		move.b	1(a0),d1
		lsl.w	#8,d1
		move.b	(a0),d1
		lsr.w	#Music_PageShift,d1
		move.b	d1,(Music_FirstVoicePage).l
		move.b	#Music_VoicePageSlots,(Music_NextPage).l
		bra.s	.keepCache
.reuseCache:
		tst.b	(a1,d0.w)
		bne.w	.publish
.keepCache:
		move.w	d0,d1
		lsl.w	#Music_PageShift,d1
		adda.w	d1,a0

		move.w	d0,d2
		sub.b	(Music_FirstVoicePage).l,d2
		cmpi.b	#Music_VoicePageSlots,d2
		blo.s	.tag
		moveq	#0,d2
		move.b	(Music_NextPage).l,d2
.candidate:
		moveq	#0,d1
		move.b	(a2,d2.w),d1
		beq.s	.tag
		bclr	#5,-1(a1,d1.w)
		beq.s	.evict
		addq.w	#1,d2
		cmpi.w	#Music_CacheSlots,d2
		blo.s	.candidate
		moveq	#Music_VoicePageSlots,d2
		bra.s	.candidate
.evict:
		clr.b	-1(a1,d1.w)
.tag:
		move.w	d0,d1
		addq.w	#1,d1
		move.b	d1,(a2,d2.w)
		cmpi.w	#Music_VoicePageSlots,d2
		blo.s	.destination
		move.w	d2,d3
		addq.w	#1,d3
		cmpi.w	#Music_CacheSlots,d3
		blo.s	.nextSlot
		moveq	#Music_VoicePageSlots,d3
.nextSlot:
		move.b	d3,(Music_NextPage).l
.destination:
		lea	(Z80_RAM+zMusicCache).l,a3
		move.w	d2,d1
		lsl.w	#Music_PageShift,d1
		adda.w	d1,a3
		addi.w	#zMusicCache/Music_PageSize,d2
		ror.b	#2,d2
		moveq	#0,d1			; one page, with its nonzero map byte in d2
.copyPages:
		; Keep one unrolled byte copy for both page fills and whole scores.
		rept	Music_PageSize
		move.b	(a0)+,(a3)+
		endm
		dbf	d1,.copyPages
		tst.b	d2
		beq.s	.residentReady
		move.b	d2,(a1,d0.w)
.publish:
		st	(Z80_RAM+zMusicPageRequest).l
		st	(Z80_RAM+zMusicCacheValid).l
		rts
.residentReady:
		move.b	#zMusicCache&$FF,(Z80_RAM+zMusicReadBase).l
		move.b	#zMusicCache>>8,(Z80_RAM+zMusicReadBase+1).l
		bra.s	.publish
.resident:
		; A short song only evicts the slots it physically overwrites.
		; The previous paged song can reuse the others after a jingle.
		subq.w	#1,d1
		lsr.w	#Music_PageShift,d1
		move.w	d1,d3
		bsr.s	Music_ClearSlots
		lea	(Z80_RAM+zMusicCache).l,a3
		moveq	#0,d2			; a resident score publishes no page-map entry
		bra.w	.copyPages

; Clear tags and mappings for slots d3 through zero. d1 is preserved.
Music_ClearSlots:
		lea	1(a2,d3.w),a3
		moveq	#0,d2
.slot:
		move.b	-(a3),d2
		beq.s	.next
		clr.b	-1(a1,d2.w)
		clr.b	(a3)
.next:
		dbf	d3,.slot
		rts

; d4 is the staging slot. Return the song ID in d4 and decoded size in d1.
Music_GetStageScore:
		lea	(Music_StageSongs-1).l,a3
		move.b	(a3,d4.w),d4
		move.w	d4,d1
		lsl.w	#3,d1
		lea	(Music_IndexByID).l,a3
		move.w	4(a3,d1.w),d1
		rts
