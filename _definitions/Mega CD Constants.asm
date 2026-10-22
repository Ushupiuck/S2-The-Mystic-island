; Mode 1 retains the cartridge at $000000-$3FFFFF. No BIOS code is executed.
MCD_BootROM:		equ	$400000
MCD_ProgramRAM:		equ	$420000	; banked 128 KB main-CPU window
MCD_WordRAM:		equ	$600000	; 256 KB in 2M mode
MCD_SubControl:		equ	$A12000
MCD_MemoryMode:		equ	$A12002
MCD_MainCommand:	equ	$A12010
MCD_MainArgument:	equ	$A12012
MCD_MainToken:		equ	$A1201E
MCD_MainFlags:		equ	$A1200E
MCD_SubFlags:		equ	$A1200F
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
MCD_SubMainFlags:	equ	$FF800E
MCD_SubOwnFlags:		equ	$FF800F
MCD_ServiceReady:	equ	$80
MCD_ServiceError:	equ	$40
MCD_ServiceLanded:	equ	0	; bit number
MCD_ServiceInertia:	equ	1	; bit number

; ---------------------------------------------------------------------------
; PRG-RAM bounds and capacities; allocations are in Mega CD RAM.asm.
MCD_BIOS_RAM_End:		equ	$6000
MCD_ChunkTable_Size:		equ	$20000
MCD_ChunkTable_CurrentSize:	equ	$8000
MCD_RingSlots:			equ	255

; Terrain service. Object commands carry an optional input angle in the high
; byte. The six argument words are a compact sensor/object snapshot, never SSTs.
MCD_CommandTerrainLoad:		equ	5
MCD_CommandTerrainDraw:		equ	6
MCD_CommandTerrainFloor:		equ	7
MCD_CommandTerrainWall:		equ	8
MCD_CommandLayoutRead:		equ	9
MCD_CommandLayoutWrite:		equ	10
MCD_CommandTerrainAir:		equ	11
MCD_TerrainAnglePos:		equ	$20
MCD_TerrainRoomInFront:		equ	$21
MCD_TerrainRoomOverhead:		equ	$22
MCD_TerrainFloorPair:		equ	$23
MCD_TerrainCeilingPair:		equ	$24
MCD_TerrainFloorEdge:		equ	$25
MCD_TerrainFloorEdgeX:		equ	$26
MCD_TerrainObjectFloor:		equ	$27
MCD_TerrainObjectFloorX:		equ	$28
MCD_TerrainRightSensor:		equ	$29
MCD_TerrainLeftSensor:		equ	$2A
MCD_TerrainObjectRight:		equ	$2B
MCD_TerrainObjectLeft:		equ	$2C
MCD_TerrainObjectCeiling:		equ	$2D
MCD_TerrainObjectLast:		equ	MCD_TerrainObjectCeiling
MCD_TerrainIndexCapacity:		equ	$600
MCD_TerrainStreamCapacity:	equ	$E000
MCD_SubWordRAM:			equ	$80000

; Object placements and shared frame transport.
MCD_CommandObjectsLoad:		equ	12
MCD_CommandObjectState:		equ	13
MCD_ObjectPlacementCount:	equ	$300
MCD_ObjectPlacementCapacity:	equ	(MCD_ObjectPlacementCount+2)*omSize
MCD_ObjectSpawnSize:		equ	12
