; Main-CPU aliases into PRG-RAM bank 0. Reserve the conventional sub-BIOS
; area even though the current raw bootstrap does not execute Sega's BIOS.
; Chunk storage is the first user allocation, immediately after $0000-$5FFF.
MCD_BIOS_RAM_End: equ $6000
MCD_UserRAM_Start: equ MCD_ProgramRAM+MCD_BIOS_RAM_End
Chunk_Table: equ MCD_UserRAM_Start
Chunk_Table_End: equ Chunk_Table+$8000
MCD_UserRAM_End: equ Chunk_Table_End
		if Chunk_Table_End>MCD_ProgramRAM+$20000
			fatal "Chunk storage exceeds the main CPU's PRG-RAM bank-0 window"
		endif
