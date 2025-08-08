; ---------------------------------------------------------------------------
; "MAIN LEVEL LOAD BLOCK" (after Nemesis)
;
; This struct array tells the engine where to find all the art associated with
; a particular zone. Each zone gets four longwords, in which it stores four
; pointers (in the lower 24 bits) and three jump table indeces (in the upper eight
; bits). The assembled data looks something like this:
;
; aaBBBBBB
; ccDDDDDD
; EEEEEE
; ffgghhii
;
; aa = index for primary pattern load request list
; BBBBBB = unused, pointer to level art
; cc = index for secondary pattern load request list
; DDDDDD = pointer to 16x16 block mappings
; EEEEEE = pointer to 128x128 block mappings
; ff = unused, always 0
; gg = unused, music track
; hh = unused, palette
; ii = palette
;
; Nemesis refers to this as the "main level load block". However, that name implies
; that this is code (obviously, it isn't), or at least that it points to the level's
; collision, object and ring placement arrays (it only points to palettes and 16x16
; mappings although the 128x128 mappings do affect the actual level layout and collision)
; ---------------------------------------------------------------------------

; macro for declaring a "main level load block" (MLLB)
levartptrs macro plc1,plc2,art,map16x16,map128x128,music,palette
	dc.l (plc1<<24)|art
	dc.l (plc2<<24)|map16x16
	dc.l map128x128
	dc.b 0,music,palette,palette
	endm

; MainLoadBlocks:
LevelArtPointers:
		levartptrs plcid_GHZ, plcid_GHZ2, Kosp_GHZ, Map16_GHZ, Map128_GHZ, bgm_GHZ, palid_GHZ    ; GHZ  ; GREEN HILL ZONE
		levartptrs plcid_LZ,  plcid_LZ2,  Kosp_LZ,  Map16_LZ,  Map128_LZ,  bgm_LZ,  palid_LZ     ; LZ   ; LABYRINTH ZONE
		levartptrs plcid_CPZ, plcid_CPZ2, Kosp_CPZ, Map16_CPZ, Map128_CPZ, bgm_MZ,  palid_CPZ    ; CPZ  ; CHEMICAL PLANT ZONE
		levartptrs plcid_EHZ, plcid_EHZ2, Kosp_EHZ, Map16_EHZ, Map128_EHZ, bgm_SLZ, palid_EHZ    ; EHZ  ; EMERALD HILL ZONE
		levartptrs plcid_HPZ, plcid_HPZ2, Kosp_HPZ, Map16_HPZ, Map128_HPZ, bgm_SYZ, palid_HPZ    ; HPZ  ; HIDDEN PALACE ZONE
		levartptrs plcid_HTZ, plcid_HTZ2, Kosp_HTZ, Map16_HTZ, Map128_HTZ, bgm_SBZ, palid_HTZ1   ; HTZ  ; HILL TOP ZONE
		levartptrs 0,         0,          Kosp_GHZ, Map16_GHZ, Map128_GHZ, bgm_SBZ, palid_Ending ; LEV6 ; LEVEL 6 (UNUSED, SONIC 1 ENDING)

; macro for declaring a "main level load block" (MLLB)
levartptrsM macro plc1,plc2,palette,art1,art2,map16x161,map16x162,map128x1281,map128x1282
	dc.l (plc1<<24)|art1
	dc.l (plc2<<24)|art2
	dc.l (palette<<24)|map16x161
	dc.l (palette<<24)|map16x162
	dc.l map128x1281
	dc.l map128x1282
    endm

LevelArtPointersM:
		levartptrsM plcid_GHZ, plcid_GHZ2, palid_GHZ, Kosp_GHZ, Kosp_GHZ, Map16_GHZ, Map16_GHZ, Map128_GHZ, Map128_GHZ    ; GHZ  ; GREEN HILL ZONE
		levartptrsM plcid_GHZ, plcid_GHZ2, palid_GHZ, Kosp_GHZ, Kosp_GHZ, Map16_GHZ, Map16_GHZ, Map128_GHZ, Map128_GHZ    ; GHZ  ; GREEN HILL ZONE
		levartptrsM plcid_GHZ, plcid_GHZ2, palid_GHZ, Kosp_GHZ, Kosp_GHZ, Map16_GHZ, Map16_GHZ, Map128_GHZ, Map128_GHZ    ; GHZ  ; GREEN HILL ZONE
		levartptrsM plcid_GHZ, plcid_GHZ2, palid_GHZ, Kosp_GHZ, Kosp_GHZ, Map16_GHZ, Map16_GHZ, Map128_GHZ, Map128_GHZ    ; GHZ  ; GREEN HILL ZONE

		levartptrsM plcid_GHZ, plcid_GHZ2, palid_GHZ, Kosp_GHZ, Kosp_GHZ, Map16_GHZ, Map16_GHZ, Map128_GHZ, Map128_GHZ    ; GHZ  ; GREEN HILL ZONE
		levartptrsM plcid_GHZ, plcid_GHZ2, palid_GHZ, Kosp_GHZ, Kosp_GHZ, Map16_GHZ, Map16_GHZ, Map128_GHZ, Map128_GHZ    ; GHZ  ; GREEN HILL ZONE


LoadEnemyArt:
         lea	off_2F7BE(pc),a6
; ---------------------------------------------------------------------------

loc_2F79E:
		move.w	(Current_ZoneAndAct).w,d0

loc_2F7A2:
		ror.b	#1,d0
		lsr.w	#6,d0
		adda.w	(a6,d0.w),a6
		move.w	(a6)+,d6
		bmi.s	locret_2F7BC

loc_2F7AE:
		movea.l	(a6)+,a1
		move.w	(a6)+,d2
		jsr	(Queue_Kos_Module).l
		dbf	d6,loc_2F7AE

locret_2F7BC:
		rts
; End of function LoadEnemyArt
off_2F7BE:
;=============================================================================
        dc.w PLCKosM_Standard-off_2F7BE ; $00 Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $00 Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $01 Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $01 Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $02 Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $02 Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $03 Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $03 Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $04 Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $04 Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $05 Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $05 Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $06 Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $06 Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $07 Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $07 Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $08 Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $08 Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $09 Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $09 Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $0A Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $0A Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $0B Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $0B Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $0C Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $0C Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $0D Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $0D Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $0E Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $0E Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $0F Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $0F Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $10 Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $10 Act 2
;=============================================================================
		dc.w PLCKosM_Standard-off_2F7BE ; $11 Act 1
		dc.w PLCKosM_Standard-off_2F7BE ; $11 Act 2
; ===========================================================================
; macro for a pattern load request list header
; must be on the same line as a label that has a corresponding _End label later
plrKosMlistheader macro {INTLABEL}
__LABEL__ label *
	dc.w (((__LABEL___End - __LABEL__Plc) / 6) - 1)
__LABEL__Plc:
    endm

; macro for a pattern load request
plrKosMeq macro toVRAMaddr,fromROMaddr
	dc.l	fromROMaddr
	dc.w	tiles_to_bytes(toVRAMaddr)
    endm



PLCKosM_Standard:	plrKosMlistheader
	plrKosMeq ArtTile_KosM_Explosion, ArtKosM_Explosion
PLCKosM_Standard_End		