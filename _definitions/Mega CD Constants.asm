; Mode 1 retains the cartridge at $000000-$3FFFFF. No BIOS code is executed.
MCD_BootROM:		equ	$400000
MCD_ProgramRAM:		equ	$420000	; banked 128 KB main-CPU window
MCD_WordRAM:		equ	$600000	; 256 KB in 2M mode
MCD_SubControl:		equ	$A12000
MCD_MemoryMode:		equ	$A12002
MCD_MainCommand:	equ	$A12010
MCD_MainArgument:	equ	$A12012
MCD_MainToken:		equ	$A1201E
MCD_SubResult:		equ	$A12020
MCD_SubStatus:		equ	$A12022
MCD_SubAck:		equ	$A1202E
MCD_Ready:		equ	$4D31	; "M1"
MCD_CommandPing:	equ	1
MCD_CommandReturnRAM:	equ	2
MCD_CommandRingTick:	equ	3
MCD_CommandRingReset:	equ	4
MCD_StatusAbsent:	equ	0
MCD_StatusReady:	equ	1
MCD_StatusFailed:	equ	$FF
MCD_WaitLimit:		equ	$FFFF
MCD_SubMemoryMode:	equ	$FF8003
MCD_SubMainCommand:	equ	$FF8010
MCD_SubMainArgument:	equ	$FF8012
MCD_SubMainToken:	equ	$FF801E
MCD_SubOwnResult:	equ	$FF8020
MCD_SubOwnStatus:	equ	$FF8022
MCD_SubOwnAck:		equ	$FF802E

; ---------------------------------------------------------------------------
; PRG-RAM bounds and capacities; allocations are in Mega CD RAM.asm.
MCD_BIOS_RAM_End:		equ	$6000
MCD_ChunkTable_Size:		equ	$20000
MCD_ChunkTable_CurrentSize:	equ	$8000
MCD_RingSlots:			equ	255
