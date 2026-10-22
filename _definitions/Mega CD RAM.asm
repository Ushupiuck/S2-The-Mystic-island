; ---------------------------------------------------------------------------
; Physical sub-CPU PRG RAM
; The chunk table is the first user allocation after the conventional BIOS area.
; $100 editor-sized 256x256 chunks occupy $20000 bytes. The current byte-indexed
; layout still uses $8000; word IDs, two collision paths and SonLVL conversion
; remain future work.
; ---------------------------------------------------------------------------
	phase	MCD_BIOS_RAM_End
MCD_ChunkTable_SubStart:	ds.b	MCD_ChunkTable_Size
MCD_ChunkTable_SubEnd:
MCD_JobRAM_SubStart:
; Ring animation jobs use bank 1, beyond the entire expanded chunk buffer.
MCD_RingState_Sub:	ds.b	(MCD_RingSlots+1)*6
MCD_RingState_SubEnd:
MCD_RingEvents_Sub:	ds.w	MCD_RingSlots+1
MCD_RingUpdates_Sub:	ds.l	MCD_RingSlots+1
MCD_RingUpdateCount_Sub:	ds.w	1
MCD_RingActiveCount_Sub:	ds.w	1
			ds.b	$C	; pad the control header to $10 bytes
MCD_RingActiveList_Sub:	ds.w	MCD_RingSlots+1
MCD_RingJob_SubEnd:
; Terrain tables are resident here. No normal-frame MD PRG-RAM reader remains.
MCD_TerrainData_Sub:
MCD_TerrainBlocks_Sub:	ds.b	$1800
MCD_TerrainLayout_Sub:	ds.b	$1000
MCD_TerrainIndex_Sub:	ds.b	MCD_TerrainIndexCapacity
MCD_TerrainHeights_Sub:	ds.b	$1000
MCD_TerrainWidths_Sub:	ds.b	$1000
MCD_TerrainAngles_Sub:	ds.b	$100
MCD_TerrainData_SubEnd:
MCD_TerrainCamera_Sub:	ds.l	2
MCD_TerrainBG_Sub:	ds.l	2
MCD_TerrainBG2_Sub:	ds.l	2
MCD_TerrainBG3_Sub:	ds.l	2
MCD_TerrainFlags_Sub:	ds.w	1
MCD_TerrainBGFlags_Sub:	ds.w	1
MCD_TerrainBG2Flags_Sub:	ds.w	1
MCD_TerrainBG3Flags_Sub:	ds.w	1
MCD_TerrainBGY_Sub:	ds.w	1
MCD_TerrainZone_Sub:	ds.b	1
MCD_TerrainRedraw_Sub:	ds.b	1
MCD_TerrainFrame_SubEnd:
MCD_TerrainPath_Sub:	ds.l	1
MCD_TerrainPath1_Sub:	ds.l	1
MCD_TerrainPath2_Sub:	ds.l	1
MCD_TerrainPrimary_Sub:	ds.b	1
MCD_TerrainSecondary_Sub:	ds.b	1
MCD_TerrainObject_Sub:	ds.b	object_size
MCD_TerrainCache_Sub:	ds.l	32
MCD_Terrain_SubEnd:
; Loader working state, beyond the expanded chunks and resident terrain.
MCD_ObjectBoundary_Sub:	ds.b	omSize
MCD_ObjectPlacements_Sub:	ds.b	(MCD_ObjectPlacementCount+1)*omSize
MCD_ObjectRespawn_Sub:	ds.b	MCD_ObjectPlacementCount
MCD_ObjectRespawn_SubEnd:
MCD_ObjectFront_Sub:	ds.l	1
MCD_ObjectBack_Sub:	ds.l	1
MCD_ObjectRespawnFront_Sub:	ds.l	1
MCD_ObjectRespawnBack_Sub:	ds.l	1
MCD_ObjectCoarseX_Sub:	ds.w	1
MCD_ObjectCoarseY_Sub:	ds.w	1
MCD_ObjectXBehind_Sub:	ds.w	1
MCD_ObjectYAbove_Sub:	ds.w	1
MCD_ObjectMinY_Sub:	ds.w	1
MCD_ObjectFreeCount_Sub:	ds.w	1
MCD_ObjectSpawnCount_Sub:	ds.w	1
MCD_ObjectStreamBytes_Sub:	ds.w	1
MCD_ObjectRoutine_Sub:	ds.b	1
MCD_ObjectRetry_Sub:	ds.b	1
MCD_ObjectKeep_Sub:	ds.b	1
			ds.b	1
MCD_ObjectFreeSlots_Sub:	ds.w	MCD_ObjectSlotCount
MCD_Objects_SubEnd:
MCD_DecompCodeTable_Sub:	ds.b	$200
MCD_DecompOutSize_Sub:	ds.l	1
MCD_DecompOutBase_Sub:	ds.l	1
MCD_PLCInput_Sub:	ds.b	MCD_DecompInputSize
MCD_PLCTable_Sub:	ds.b	$200
MCD_PLCSource_Sub:	ds.l	1
MCD_PLCWriter_Sub:	ds.l	1
MCD_PLCRepeat_Sub:	ds.l	1
MCD_PLCPalette_Sub:	ds.l	1
MCD_PLCPrevious_Sub:	ds.l	1
MCD_PLCData_Sub:		ds.l	1
MCD_PLCShift_Sub:	ds.l	1
MCD_PLCRemaining_Sub:	ds.w	1
MCD_PLCProduced_Sub:	ds.w	1
MCD_SubUserRAM_End:
	dephase

; Keep the stack and MOVEM's final dummy read inside PRG RAM. A stack top at
; $80000 touches Word RAM after a full unwind and can stall once RET is set.
	phase	$7FC00
MCD_SubStack_Start:	ds.b	$3F0
MCD_SubStack_Top:	ds.l	4	; bus-read guard below the Word-RAM boundary
MCD_SubStack_End:
	dephase

	if MCD_RingState_Sub<MCD_ChunkTable_SubEnd
		fatal "CD jobs overlap the expanded chunk buffer"
	endif
	if MCD_RingJob_SubEnd>$40000
		fatal "Ring job buffers exceed PRG-RAM bank 1"
	endif
	if MCD_ChunkTable_Size<>$20000
		fatal "Expanded chunk buffer must be exactly 128 KB"
	endif
	if MCD_ChunkTable_SubEnd>$80000
		fatal "Expanded chunk buffer exceeds physical CD PRG RAM"
	endif

; ---------------------------------------------------------------------------
; Main-CPU view of the currently used chunks, in PRG-RAM bank 0
; These labels mirror the active $8000 bytes, not the full physical allocation.
; ---------------------------------------------------------------------------
	phase	MCD_ProgramRAM+MCD_ChunkTable_SubStart
MCD_UserRAM_Start:
Chunk_Table:		ds.b	MCD_ChunkTable_CurrentSize
Chunk_Table_End:
	dephase
	if Chunk_Table_End>MCD_ProgramRAM+$20000
		fatal "Active chunk storage exceeds the MD PRG-RAM bank-0 window"
	endif

; Main-CPU window aliases, valid only while PRG-RAM bank 1 is selected.
MCD_RingEvents_Bank1:		equ	MCD_ProgramRAM+(MCD_RingEvents_Sub&$1FFFF)
MCD_RingUpdates_Bank1:		equ	MCD_ProgramRAM+(MCD_RingUpdates_Sub&$1FFFF)
MCD_RingUpdateCount_Bank1:	equ	MCD_ProgramRAM+(MCD_RingUpdateCount_Sub&$1FFFF)

; Word RAM: one outgoing strip stream and a separate level-load/scene area.
; These aliases name the same 2M RAM viewed by each CPU, not extra allocations.
	phase	MCD_WordRAM
MCD_TerrainFrame:	ds.b	MCD_TerrainFrame_SubEnd-MCD_TerrainCamera_Sub
MCD_ObjectFrameMinY:	ds.w	1
MCD_ObjectFrameEnabled:	ds.b	1
			ds.b	1
MCD_ObjectFrameSlots:	ds.b	MCD_ObjectSlotBytes
MCD_PLCBudget:		ds.b	1
			ds.b	1
MCD_PLCTimeLimit:	ds.w	1
MCD_TerrainStream:	ds.b	$E000-$40
MCD_ObjectReply:	ds.w	2
MCD_ObjectSpawns:	ds.b	MCD_ObjectSlotCount*MCD_ObjectSpawnSize
			ds.b	$10000-($E000+4+MCD_ObjectSlotCount*MCD_ObjectSpawnSize)
MCD_TerrainStage:
MCD_TerrainBlockStage:	ds.b	$1800
MCD_TerrainLayoutStage:	ds.b	$1000
MCD_TerrainIndexStage:	ds.b	MCD_TerrainIndexCapacity
MCD_TerrainHeightStage:	ds.b	$1000
MCD_TerrainWidthStage:	ds.b	$1000
MCD_TerrainAngleStage:	ds.b	$100
MCD_TerrainStage_End:
			ds.b	$18000-(MCD_TerrainStage_End-MCD_WordRAM)
MCD_DecompInput:	ds.b	MCD_DecompInputSize
MCD_DecompOutput:	ds.b	MCD_DecompOutputSize
MCD_DecompPLC:		ds.b	MCD_DecompOutputSize
	dephase
MCD_PLCBudget_Sub:	equ	MCD_SubWordRAM+(MCD_PLCBudget-MCD_WordRAM)
MCD_PLCTimeLimit_Sub:	equ	MCD_SubWordRAM+(MCD_PLCTimeLimit-MCD_WordRAM)
MCD_DecompInput_Sub:	equ	MCD_SubWordRAM+(MCD_DecompInput-MCD_WordRAM)
MCD_DecompOutput_Sub:	equ	MCD_SubWordRAM+(MCD_DecompOutput-MCD_WordRAM)
MCD_DecompPLC_Sub:	equ	MCD_SubWordRAM+(MCD_DecompPLC-MCD_WordRAM)
MCD_TerrainFrame_Sub:	equ	MCD_SubWordRAM
MCD_TerrainStream_Sub:	equ	MCD_SubWordRAM+(MCD_TerrainStream-MCD_WordRAM)
MCD_TerrainStage_Sub:	equ	MCD_SubWordRAM+(MCD_TerrainStage-MCD_WordRAM)
MCD_ObjectFrameMinY_Sub:	equ	MCD_SubWordRAM+(MCD_ObjectFrameMinY-MCD_WordRAM)
MCD_ObjectFrameEnabled_Sub:	equ	MCD_SubWordRAM+(MCD_ObjectFrameEnabled-MCD_WordRAM)
MCD_ObjectFrameSlots_Sub:	equ	MCD_SubWordRAM+(MCD_ObjectFrameSlots-MCD_WordRAM)
MCD_ObjectReply_Sub:	equ	MCD_SubWordRAM+(MCD_ObjectReply-MCD_WordRAM)
	if MCD_SubUserRAM_End>MCD_SubStack_Start
		fatal "CD working storage overlaps the sub-CPU stack"
	endif
	if MCD_TerrainStage_End>MCD_WordRAM+$40000
		fatal "Terrain transport exceeds 2M Word RAM"
	endif
	if MCD_TerrainStream-MCD_TerrainFrame<>$40
		fatal "CD frame header must occupy exactly $40 bytes"
	endif
