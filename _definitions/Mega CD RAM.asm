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
MCD_SubUserRAM_End:
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
