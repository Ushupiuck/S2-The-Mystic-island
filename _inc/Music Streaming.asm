; Mega Drive 68000. Prepare complete scores on the main thread and fill the
; Z80's read-only pages during its original VBlank update. The CD owns Kos+.
musprop_uncompressed	= 1<<4
musprop_nospeedup	= 1<<5
musprop_palmode		= 1<<6
musprop_1up		= 1<<7

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
		tst.b	(Z80_RAM+zMusicTickBusy).l
		bne.s	.return
		tst.b	(Music_LoadBusy).l
		bne.s	.return
		movem.l	d1-d2/a1,-(sp)
		lea	(Music_StageSongs-1).l,a1
		moveq	#1,d2
.find:
		cmp.b	(a1,d2.w),d0
		beq.s	.cached
		addq.w	#1,d2
		cmpi.w	#Music_StageCount+1,d2
		blo.s	.find
		bra.s	.done
.cached:
		moveq	#0,d1
		move.b	d0,d1
		subi.w	#MusID__First,d1
		lsl.w	#3,d1
		lea	(Music_Index+6).l,a1
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
		beq.w	.return
		tst.b	(Music_LoadBusy).l
		bne.w	.return
		movem.l	d0-d7/a0-a2,-(sp)
		move.w	sr,-(sp)
		disable_ints
		stopZ80
		waitZ80
		tst.b	(Z80_RAM+zMusicTickBusy).l
		bne.w	.release
		moveq	#0,d7
		move.b	(Music_PendingSong).l,d7
		clr.b	(Music_PendingSong).l
		cmp.b	(Z80_RAM+zMusicReadySong).l,d7
		beq.w	.release

		; A previously decoded song can be published again in place.
		lea	(Music_StageSongs-1).l,a2
		moveq	#1,d6
.findCached:
		cmp.b	(a2,d6.w),d7
		beq.w	.cached
		addq.w	#1,d6
		cmpi.w	#Music_StageCount+1,d6
		blo.s	.findCached

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
		clr.b	(a2,d6.w)
		clr.b	(Z80_RAM+zMusicReadySong).l
		st	(Music_LoadBusy).l
		startZ80
		move.w	(sp),sr

		bsr.w	Music_FindEntry
		movea.l	(a2)+,a0
		move.w	(a2)+,d4
		move.b	(a2),d5
		move.w	d6,d0
		lsl.w	#8,d0
		lsl.w	#5,d0
		lea	(Music_StageData-Music_StageCapacity).l,a1
		adda.w	d0,a1
		btst	#4,d5
		bne.s	.raw
		jsr	(KosPlusDec).l
		bra.s	.pad
.raw:
		move.w	d4,d0
		subq.w	#1,d0
.copyRaw:
		move.b	(a0)+,(a1)+
		dbf	d0,.copyRaw
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
		bsr.w	Music_FindEntry
		move.b	6(a2),d5
.publishHeld:
		move.b	d5,(Z80_RAM+zMusicReadyFlags).l
		move.b	d6,(Z80_RAM+zMusicReadySlot).l
		move.b	d7,(Z80_RAM+zMusicReadySong).l
.release:
		startZ80
		move.w	(sp)+,sr
		movem.l	(sp)+,d0-d7/a0-a2
.return:
		rts

Music_FindEntry:
		move.w	d7,d0
		subi.w	#MusID__First,d0
		lsl.w	#3,d0
		lea	(Music_Index).l,a2
		lea	(a2,d0.w),a2
		rts

; Spend the existing PAL delay servicing pending pages. Leave full uploads
; of short scores for the ordinary VBlank exit.
Music_WaitPAL:
		tst.b	(Music_ServiceReady).l
		beq.w	.legacy
		cmpi.b	#MCD_StatusReady,(MCD_status).w
		bne.w	.legacy
		lea	(Music_BusSignal).l,a4
		move.w	(MCD_MainStopwatch).l,d6
		tst.b	(Music_ServiceBusy).l
		bne.s	.wait
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
		st	(a4)
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
.legacy:
		move.w	#$700,d0
		dbf	d0,*
		rts

; Both VBlank exits call this after their VDP work. Keep the bus free between
; requests so KeH can finish the same tick and return to its DAC loop.
Music_Service:
		tst.b	(Music_ServiceReady).l
		beq.w	.return
		disableIntsSave
		tst.b	(Music_ServiceBusy).l
		bne.w	.restoreInts
		st	(Music_ServiceBusy).l
		lea	(Music_BusSignal).l,a4
		; Synchronize with the Z80 once. Its mailbox remains readable while
		; the sound CPU runs, so only an actual fill needs another grant.
		stopZ80
		waitZ80
		tst.b	(Z80_RAM+zMusicTickBusy).l
		beq.w	.idleHeld
		move.b	(a4),d0
		subq.b	#1,d0
		cmpi.b	#Music_PageCount,d0
		blo.s	.release
		st	(a4)
.release:
		startZ80
		enableIntsSave
		move.w	#2999,d7
		moveq	#0,d6
.poll:
		moveq	#0,d0
		move.b	(a4),d0
		beq.s	.tickComplete
		cmpi.b	#$FF,d0
		beq.s	.running
		cmpi.b	#Music_PageCount,d0
		bhi.s	.song
		subq.w	#1,d0
		disableIntsSave
		stopZ80
		waitZ80
		bsr.w	Music_FillPage
		st	(a4)
		startZ80
		enableIntsSave
		moveq	#1,d6
.running:
		dbf	d7,.poll
		bra.s	.done
.tickComplete:
		tst.b	d6
		bne.s	.done
		bsr.w	Music_Prefetch
.done:
		clr.b	(Music_ServiceBusy).l
.return:
		rts
.song:
		tst.b	(Music_PendingSong).l
		bne.s	.done
		andi.b	#$7F,d0
		move.b	d0,(Music_PendingSong).l
		bra.s	.done
.idleHeld:
		tst.b	(Music_PendingSong).l
		bne.s	.doneHeld
		move.b	(Z80_RAM+zMusicSongRequest).l,(Music_PendingSong).l
.doneHeld:
		startZ80
		enableIntsSave
		bra.s	.done
.restoreInts:
		enableIntsSave
		rts

; A quiet tick can preload a jump or call from one of the next held notes.
; The round-robin scan is bounded and never runs the command or advances a track.
Music_PrefetchLengths:
		dc.b	2,2,2,0,0,2,2,1,2,2,2,2,2,1,1,2
		dc.b	5,1,0,2,1,2,3,0,3,1,2
		even

Music_Prefetch:
		tst.b	(Music_CacheSong).l
		beq.w	.return
		disableIntsSave
		stopZ80
		waitZ80
		tst.b	(Z80_RAM+zMusicTickBusy).l
		bne.w	.release
		cmpi.b	#Music_ScoreBase>>8,(Z80_RAM+zMusicReadBase+1).l
		bne.w	.release
		bsr.w	Music_GetStage
		movea.l	a0,a5
		moveq	#0,d7
		move.b	(Music_NextTrack).l,d7
		moveq	#1,d6
.track:
		move.w	d7,d5
		mulu.w	#zTrack.len,d5
		lea	(Z80_RAM+zTracksStart).l,a6
		adda.w	d5,a6
		addq.b	#1,d7
		cmpi.b	#MUSIC_TRACK_COUNT,d7
		blo.s	.scan
		moveq	#0,d7
.scan:
		btst	#7,zTrack.PlaybackControl(a6)
		beq.w	.next
		move.b	zTrack.DurationTimeout(a6),d0
		subq.b	#2,d0
		cmpi.b	#11,d0
		bhs.w	.next
		moveq	#0,d0
		move.b	zTrack.DataPointerHigh(a6),d0
		lsl.w	#8,d0
		move.b	zTrack.DataPointerLow(a6),d0
		subi.w	#Music_ScoreBase,d0
		moveq	#3,d5
.command:
		cmpi.w	#Music_StageCapacity-3,d0
		bhs.w	.next
		lea	(a5,d0.w),a3
		moveq	#0,d1
		move.b	(a3),d1
		subi.b	#$E0,d1
		cmpi.b	#$1B,d1
		bhs.w	.next		; note or duration
		moveq	#0,d2
		lea	(Music_PrefetchLengths).l,a2
		move.b	(a2,d1.w),d2
		beq.w	.next		; return, stop, or a counted loop
		cmpi.b	#$16,d1
		beq.s	.jump
		cmpi.b	#$18,d1
		beq.s	.call
		add.w	d2,d0
		dbf	d5,.command
		bra.w	.next
.call:
		addq.w	#1,d0
.jump:
		moveq	#0,d1
		move.b	2(a3),d1
		lsl.w	#8,d1
		move.b	1(a3),d1
		addq.w	#2,d0
		add.w	d1,d0
		cmpi.w	#Music_StageCapacity,d0
		bhs.w	.next
		lsr.w	#Music_PageShift,d0
		lea	(Z80_RAM+zMusicPageMap).l,a1
		tst.b	(a1,d0.w)
		bne.w	.next
		bsr.w	Music_FillPage
		bset	#5,(a1,d0.w)
.next:
		dbf	d6,.track
		move.b	d7,(Music_NextTrack).l
.release:
		startZ80
		enableIntsSave
.return:
		rts

Music_GetStage:
		moveq	#0,d4
		move.b	(Z80_RAM+zAbsVar.MusicSlot).l,d4
		move.w	d4,d1
		lsl.w	#8,d1
		lsl.w	#5,d1
		lea	(Music_StageData-Music_StageCapacity).l,a0
		adda.w	d1,a0
		rts

; d0.w is a virtual page index. Bus is granted until the map byte is written.
Music_FillPage:
		lea	(Z80_RAM+zMusicPageMap).l,a1
		lea	(Music_PageTags).l,a2
		bsr.s	Music_GetStage
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
		clr.b	(Music_NextPage).l
		bra.s	.keepCache
.reuseCache:
		tst.b	(a1,d0.w)
		bne.s	.publish
.keepCache:
		move.w	d0,d1
		lsl.w	#Music_PageShift,d1
		adda.w	d1,a0

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
		moveq	#0,d2
		bra.s	.candidate
.evict:
		clr.b	-1(a1,d1.w)
.tag:
		move.w	d0,d1
		addq.w	#1,d1
		move.b	d1,(a2,d2.w)
		move.w	d2,d3
		addq.w	#1,d3
		cmpi.w	#Music_CacheSlots,d3
		blo.s	.nextSlot
		moveq	#0,d3
.nextSlot:
		move.b	d3,(Music_NextPage).l
		lea	(Z80_RAM+zMusicCache).l,a3
		move.w	d2,d1
		lsl.w	#Music_PageShift,d1
		adda.w	d1,a3
		bsr.s	Music_CopyPage
		addi.w	#zMusicCache/Music_PageSize,d2
		ror.b	#2,d2
		move.b	d2,(a1,d0.w)
.publish:
		st	(Z80_RAM+zMusicPageRequest).l
		st	(Z80_RAM+zMusicCacheValid).l
		rts
.resident:
		; A short song only evicts the slots it physically overwrites.
		; The previous paged song can reuse the others after a jingle.
		subq.w	#1,d1
		lsr.w	#Music_PageShift,d1
		move.w	d1,d3
		bsr.s	Music_ClearSlots
		lea	(Z80_RAM+zMusicCache).l,a3
.copyScore:
		bsr.s	Music_CopyPage
		dbf	d1,.copyScore
		move.b	#zMusicCache&$FF,(Z80_RAM+zMusicReadBase).l
		move.b	#zMusicCache>>8,(Z80_RAM+zMusicReadBase+1).l
		bra.s	.publish

; Clear tags and mappings for slots d3 through zero. d1 is preserved.
Music_ClearSlots:
		moveq	#0,d2
.slot:
		move.b	(a2,d3.w),d2
		beq.s	.next
		clr.b	-1(a1,d2.w)
		clr.b	(a2,d3.w)
.next:
		dbf	d3,.slot
		rts

Music_CopyPage:
		; Byte writes are required by the Z80 bus bridge.
		rept	Music_PageSize
		move.b	(a0)+,(a3)+
		endm
		rts

; d4 is the staging slot. Return the song ID in d4 and decoded size in d1.
Music_GetStageScore:
		lea	(Music_StageSongs-1).l,a3
		move.b	(a3,d4.w),d4
		move.w	d4,d1
		subi.w	#MusID__First,d1
		lsl.w	#3,d1
		lea	(Music_Index).l,a3
		move.w	4(a3,d1.w),d1
		rts
