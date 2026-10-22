; ===========================================================================
; Sonic the Mystic Island Project -- Mega-CD sub-68000 program
; ===========================================================================
; Runs in CD PRG RAM from address 0; MCD_SubEntry is its reset entry point.
; md-main.asm embeds/uploads this program and supplies the shared _definitions.
; Only CD-CPU code belongs here or in its subsystem includes. Main-CPU bus,
; DMA and mailbox callers remain on the Mega Drive side.

	CPU 68000
		dc.l	MCD_SubStack_Top,MCD_SubEntry
		rept	24
		dc.l	MCD_SubError
		endm
		dc.l	MCD_SubIRQ2
		rept	37
		dc.l	MCD_SubError
		endm
MCD_SubEntry:
		move.w	#$2700,sr
		clr.b	($FF8033).l		; mask Gate Array IRQ sources
		clr.w	($FF8030).l		; stop timer
		move.b	#$FF,($FF0011).l		; silence PCM channels
		bset	#0,(MCD_SubMemoryMode).l	; give main CPU 2M Word RAM
		move.w	#MCD_Ready,(MCD_SubOwnStatus).l
		move.b	#MCD_ServiceReady,(MCD_SubOwnFlags).l
		move.w	(MCD_SubMainToken).l,d7
		not.w	d7			; process the staged boot request too
.wait:
		move.w	(MCD_SubMainToken).l,d6
		cmp.w	d6,d7
		beq.w	.wait
		moveq	#0,d0
		move.b	(MCD_SubMainCommand+1).l,d0
		lsl.w	#2,d0
		lea	.handlers(pc),a0
		movea.l	(a0,d0.w),a0
		move.w	(MCD_SubMainCommand).l,d0
		move.b	#MCD_ServiceReady,(MCD_SubOwnFlags).l
		jmp	(a0)
.unknown:
		moveq	#-1,d0
		bra.w	.done
.ping:
		move.w	(MCD_SubMainArgument).l,d0
		bra.w	.done
.returnRAM:
		bset	#0,(MCD_SubMemoryMode).l
		moveq	#0,d0
		bra.w	.done
.ringTick:
		bsr.w	MCD_SubRingTick
		bra.w	.done
.ringReset:
		bsr.w	MCD_SubRingReset
		bra.w	.done
.terrainLoad:
		bsr.w	MCD_SubTerrainLoad
		bra.w	.done
.objectsLoad:
		bsr.w	MCD_SubObjectsLoad
		bra.w	.done
.objectState:
		bsr.w	MCD_SubObjectState
		bra.w	.done
.layout:
		bsr.w	MCD_SubTerrainLayout
		bra.w	.done
.terrainDraw:
		movem.l	d6-d7,-(sp)
		bsr.w	MCD_SubTerrainDraw
		bra.w	.terrainDone
.terrainProbe:
		movem.l	d6-d7,-(sp)
		bsr.w	MCD_SubTerrainProbe
		bra.w	.terrainDone
.terrainObject:
		movem.l	d6-d7,-(sp)
		bsr.w	MCD_SubTerrainObject
		bra.s	.terrainDone
.artFrame:
		movem.l	d6-d7,-(sp)
		bsr.w	MCD_SubArtFrame
		bra.s	.terrainDone
.decompress:
		movem.l	d6-d7,-(sp)
		bsr.w	MCD_SubDecompress
		bra.s	.terrainDone
.terrainAir:
		movem.l	d6-d7,-(sp)
		bsr.w	MCD_SubTerrainAir
.terrainDone:
		movem.l	(sp)+,d6-d7
.done:
		move.w	d0,(MCD_SubOwnResult).l
		move.w	d6,d7
		move.w	d7,(MCD_SubOwnAck).l
		bra.w	.wait
.handlers:
		dc.l	.done,.ping,.returnRAM,.ringTick,.ringReset
		dc.l	.terrainLoad,.terrainDraw,.terrainProbe,.terrainProbe
		dc.l	.layout,.layout,.terrainAir
		dc.l	.objectsLoad,.objectState
		dc.l	.decompress,.decompress,.decompress,.decompress,.artFrame
		rept	$20-19
		dc.l	.unknown
		endm
		rept	MCD_TerrainObjectLast-MCD_TerrainAnglePos+1
		dc.l	.terrainObject
		endm
		rept	$100-MCD_TerrainObjectLast-1
		dc.l	.unknown
		endm
.handlersEnd:
		if .handlersEnd-.handlers<>$100*4
			fatal "CD command dispatch must cover all byte commands"
		endif
MCD_SubIRQ2:
		rte
MCD_SubError:
		move.b	#MCD_ServiceReady|MCD_ServiceError,(MCD_SubOwnFlags).l
		move.w	#$FFFF,(MCD_SubOwnStatus).l
		bra.s	*

; Only animation state lives here. Ring coordinates, collision and rewards
; remain on the main CPU. d6/d7 belong to the mailbox and must be preserved.
MCD_SubRingReset:
		lea	(MCD_RingState_Sub).l,a0
		move.w	#bytesToLcnt(MCD_RingState_SubEnd-MCD_RingState_Sub),d1
.clear:
		clr.l	(a0)+
		dbf	d1,.clear
		clr.w	(MCD_RingUpdateCount_Sub).l
		clr.w	(MCD_RingActiveCount_Sub).l
		moveq	#0,d0
		rts

MCD_SubRingTick:
		lea	(MCD_RingState_Sub).l,a0
		lea	(MCD_RingEvents_Sub).l,a1
		lea	(MCD_RingActiveList_Sub).l,a3
		move.w	(MCD_RingActiveCount_Sub).l,d4
		move.w	(MCD_SubMainArgument).l,d1
		subq.w	#1,d1
		bmi.s	.tick
.event:
		move.w	(a1)+,d2
		move.w	#$601,(a0,d2.w)
		move.w	d4,d3
		add.w	d3,d3
		move.w	d2,(a3,d3.w)
		addq.w	#1,d4
		dbf	d1,.event
.tick:
		lea	(MCD_RingUpdates_Sub).l,a4
		moveq	#0,d5
		move.w	d4,d1
		subq.w	#1,d1
		bmi.s	.done
.active:
		move.w	(a3),d2
		move.w	(a0,d2.w),d3
		subi.w	#$100,d3		; timer byte--
		cmpi.w	#$100,d3
		bhs.s	.store
		addi.w	#$601,d3		; timer=6, frame++
		cmpi.b	#5,d3
		bne.s	.store
		moveq	#-1,d3
		subq.w	#1,d4
		move.w	d4,d0
		add.w	d0,d0
		; Remove by replacing this slot with the unprocessed last entry.
		lea	(MCD_RingActiveList_Sub).l,a2
		move.w	(a2,d0.w),(a3)
		bra.s	.output
.store:
		addq.w	#2,a3
.output:
		move.w	d3,(a0,d2.w)
		move.w	d2,(a4)+
		move.w	d3,(a4)+
		addq.w	#1,d5
		dbf	d1,.active
.done:
		move.w	d5,(MCD_RingUpdateCount_Sub).l
		move.w	d4,(MCD_RingActiveCount_Sub).l
		move.w	d4,d0
		rts
		even
		include "_inc/Mega CD Terrain.asm"
		include "_inc/Mega CD Objects.asm"

		include "_inc/Mega CD Decompression.asm"
