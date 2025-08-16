; ---------------------------------------------------------------------------
; "MAIN LEVEL LOAD BLOCK" (after Nemesis)
;
; This struct array tells the engine where to find all the art associated with
; a particular zone. Each zone gets three longwords, in which it stores three
; pointers (in the lower 24 bits) and three jump table indeces (in the upper eight
; bits). The assembled data looks something like this:
;
; aaBBBBBB
; ccDDDDDD
; eeFFFFFF
;
; aa = index for primary pattern load request list
; BBBBBB = pointer to level art
; cc = index for secondary pattern load request list
; DDDDDD = pointer to 16x16 block mappings
; ee = index for palette
; FFFFFF = pointer to 128x128 block mappings
;
; Nemesis refers to this as the "main level load block". However, that name implies
; that this is code (obviously, it isn't), or at least that it points to the level's
; collision, object and ring placement arrays (it only points to art...
; although the 128x128 mappings do affect the actual level layout and collision)
; ---------------------------------------------------------------------------

; macro for declaring a "main level load block" (MLLB)
levartptrs macro plc1,plc2,palette,art,map16x16,map128x128
	dc.l (plc1<<24)|art
	dc.l (plc2<<24)|map16x16
	dc.l (palette<<24)|map128x128
    endm

LevelArtPointers:
		; GHZ
		levartptrs plcid_GHZ, plcid_GHZ2, palid_GHZ, Kosp_GHZ, Map16_GHZ, Map128_GHZ	; GHZ	; ACT 1
		levartptrs plcid_GHZ, plcid_GHZ2, palid_GHZ, Kosp_GHZ, Map16_GHZ, Map128_GHZ	; GHZ	; ACT 2
		levartptrs plcid_GHZ, plcid_GHZ2, palid_GHZ, Kosp_GHZ, Map16_GHZ, Map128_GHZ	; GHZ	; ACT 3
		levartptrs plcid_GHZ, plcid_GHZ2, palid_GHZ, Kosp_GHZ, Map16_GHZ, Map128_GHZ	; GHZ	; ACT 4

		; LZ
		levartptrs plcid_LZ,  plcid_LZ2,  palid_LZ,  Kosp_LZ,  Map16_LZ,  Map128_LZ	; LZ	; ACT 1
		levartptrs plcid_LZ,  plcid_LZ2,  palid_LZ,  Kosp_LZ,  Map16_LZ,  Map128_LZ	; LZ	; ACT 2
		levartptrs plcid_LZ,  plcid_LZ2,  palid_LZ,  Kosp_LZ,  Map16_LZ,  Map128_LZ	; LZ	; ACT 3
		levartptrs plcid_LZ,  plcid_LZ2,  palid_LZ,  Kosp_LZ,  Map16_LZ,  Map128_LZ	; LZ	; ACT 4

		; CPZ
		levartptrs plcid_CPZ, plcid_CPZ2, palid_CPZ, Kosp_CPZ, Map16_CPZ, Map128_CPZ	; CPZ	; ACT 1
		levartptrs plcid_CPZ, plcid_CPZ2, palid_CPZ, Kosp_CPZ, Map16_CPZ, Map128_CPZ	; CPZ	; ACT 2
		levartptrs plcid_CPZ, plcid_CPZ2, palid_CPZ, Kosp_CPZ, Map16_CPZ, Map128_CPZ	; CPZ	; ACT 3
		levartptrs plcid_CPZ, plcid_CPZ2, palid_CPZ, Kosp_CPZ, Map16_CPZ, Map128_CPZ	; CPZ	; ACT 4

		; EHZ
		levartptrs plcid_EHZ, plcid_EHZ2, palid_EHZ, Kosp_EHZ, Map16_EHZ, Map128_EHZ	; EHZ	; ACT 1
		levartptrs plcid_EHZ, plcid_EHZ2, palid_EHZ, Kosp_EHZ, Map16_EHZ, Map128_EHZ	; EHZ	; ACT 2
		levartptrs plcid_EHZ, plcid_EHZ2, palid_EHZ, Kosp_EHZ, Map16_EHZ, Map128_EHZ	; EHZ	; ACT 3
		levartptrs plcid_EHZ, plcid_EHZ2, palid_EHZ, Kosp_EHZ, Map16_EHZ, Map128_EHZ	; EHZ	; ACT 4

		; HPZ
		levartptrs plcid_HPZ, plcid_HPZ2, palid_HPZ, Kosp_HPZ, Map16_HPZ, Map128_HPZ	; HPZ	; ACT 1
		levartptrs plcid_HPZ, plcid_HPZ2, palid_HPZ, Kosp_HPZ, Map16_HPZ, Map128_HPZ	; HPZ	; ACT 2
		levartptrs plcid_HPZ, plcid_HPZ2, palid_HPZ, Kosp_HPZ, Map16_HPZ, Map128_HPZ	; HPZ	; ACT 3
		levartptrs plcid_HPZ, plcid_HPZ2, palid_HPZ, Kosp_HPZ, Map16_HPZ, Map128_HPZ	; HPZ	; ACT 4

		; HTZ
		levartptrs plcid_HTZ, plcid_HTZ2, palid_HTZ1, Kosp_HTZ, Map16_HTZ, Map128_HTZ	; HTZ	; ACT 1
		levartptrs plcid_HTZ, plcid_HTZ2, palid_HTZ1, Kosp_HTZ, Map16_HTZ, Map128_HTZ	; HTZ	; ACT 2
		levartptrs plcid_HTZ, plcid_HTZ2, palid_HTZ1, Kosp_HTZ, Map16_HTZ, Map128_HTZ	; HTZ	; ACT 3
		levartptrs plcid_HTZ, plcid_HTZ2, palid_HTZ1, Kosp_HTZ, Map16_HTZ, Map128_HTZ	; HTZ	; ACT 4

		; LV6 placeholder
		levartptrs 0,         0,          palid_GHZ, Kosp_GHZ, Map16_GHZ, Map128_GHZ	; LV6Z	; ACT 1
		levartptrs 0,         0,          palid_GHZ, Kosp_GHZ, Map16_GHZ, Map128_GHZ	; LV6Z	; ACT 2
		levartptrs 0,         0,          palid_GHZ, Kosp_GHZ, Map16_GHZ, Map128_GHZ	; LV6Z	; ACT 3
		levartptrs 0,         0,          palid_GHZ, Kosp_GHZ, Map16_GHZ, Map128_GHZ	; LV6Z	; ACT 4