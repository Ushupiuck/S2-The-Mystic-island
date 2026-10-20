; Physical sub-CPU PRG-RAM allocations. The MD sees a banked 128 KB window;
; a physical allocation end is not necessarily a directly usable MD pointer.
; Keep the conventional BIOS area and the chunk table as the first user block.
MCD_BIOS_RAM_End: equ $6000
MCD_ChunkTable_SubStart: equ MCD_BIOS_RAM_End

; Expand the existing chunk buffer from $8000 to $20000 physical bytes.
; This holds $100 editor-sized 256x256 chunks / $400 runtime 128x128 pieces.
; The CURRENT byte-indexed layout still loads/uses only its original $8000.
; Word layout IDs, two collision paths and SonLVL conversion are future work.
MCD_ChunkTable_Size: equ $20000
MCD_ChunkTable_CurrentSize: equ $8000
MCD_ChunkTable_SubEnd: equ MCD_ChunkTable_SubStart+MCD_ChunkTable_Size
MCD_SubUserRAM_End: equ MCD_ChunkTable_SubEnd
MCD_JobRAM_SubStart: equ MCD_SubUserRAM_End

; Ring jobs use bank 1, beyond the ENTIRE expanded chunk buffer.
MCD_RingSlots: equ 255
MCD_RingState_Sub: equ MCD_JobRAM_SubStart
MCD_RingEvents_Sub: equ MCD_RingState_Sub+$600
MCD_RingUpdates_Sub: equ MCD_RingEvents_Sub+$200
MCD_RingUpdateCount_Sub: equ MCD_RingUpdates_Sub+$400
MCD_RingActiveCount_Sub: equ MCD_RingUpdateCount_Sub+2
MCD_RingActiveList_Sub: equ MCD_RingUpdateCount_Sub+$10
MCD_RingJob_SubEnd: equ MCD_RingActiveList_Sub+$200
MCD_RingEvents_Bank1: equ MCD_ProgramRAM+(MCD_RingEvents_Sub&$1FFFF)
MCD_RingUpdates_Bank1: equ MCD_ProgramRAM+(MCD_RingUpdates_Sub&$1FFFF)
MCD_RingUpdateCount_Bank1: equ MCD_ProgramRAM+(MCD_RingUpdateCount_Sub&$1FFFF)

        if MCD_RingState_Sub<MCD_ChunkTable_SubEnd
            fatal "CD jobs overlap the expanded chunk buffer"
        endif
        if MCD_RingJob_SubEnd>$40000
            fatal "Ring job buffers exceed PRG-RAM bank 1"
        endif

; Current 128x128 format still uses only $8000 bytes, wholly in bank 0.
; These are the CURRENT used bounds for clears/overlays/readers, not the
; physical allocation end. The expanded buffer crosses PRG-RAM banks 0/1.
MCD_UserRAM_Start: equ MCD_ProgramRAM+MCD_ChunkTable_SubStart
Chunk_Table: equ MCD_UserRAM_Start
Chunk_Table_End: equ Chunk_Table+MCD_ChunkTable_CurrentSize
        if Chunk_Table_End>MCD_ProgramRAM+$20000
            fatal "Active chunk storage exceeds the MD PRG-RAM bank-0 window"
        endif
        if MCD_ChunkTable_Size<>$20000
            fatal "Expanded chunk buffer must be exactly 128 KB"
        endif
        if MCD_ChunkTable_SubEnd>$80000
            fatal "Expanded chunk buffer exceeds physical CD PRG RAM"
        endif
