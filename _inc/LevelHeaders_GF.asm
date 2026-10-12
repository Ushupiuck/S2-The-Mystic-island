; ---------------------------------------------------------------------------
; "MAIN LEVEL LOAD BLOCK" (after Nemesis)
;
; This struct array tells the engine where to find all the art associated with
; a particular act. Each act gets three longwords, in which it stores three
; pointers (in the lower 24 bits) and three jump table indices (in the upper eight
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

; Dummy Good Future assets currently use the same source files as Present; keep four independent act entries.
LevelArtPointersGF:
		; GHZ
		levartptrs plcid_GHZ, plcid_GHZ2, palid_GHZ, GKosp_GHZ, GMap16_GHZ, GMap128_GHZ	; GHZ	; ACT 1
		levartptrs plcid_GHZ, plcid_GHZ2, palid_GHZ, GKosp_GHZ, GMap16_GHZ, GMap128_GHZ	; GHZ	; ACT 2
		levartptrs plcid_GHZ, plcid_GHZ2, palid_GHZ, GKosp_GHZ, GMap16_GHZ, GMap128_GHZ	; GHZ	; ACT 3
		levartptrs plcid_GHZ, plcid_GHZ2, palid_GHZ, GKosp_GHZ, GMap16_GHZ, GMap128_GHZ	; GHZ	; ACT 4

		; LZ
		levartptrs plcid_LZ,  plcid_LZ2,  palid_LZ,  GKosp_LZ,  GMap16_LZ,  GMap128_LZ	; LZ	; ACT 1
		levartptrs plcid_LZ,  plcid_LZ2,  palid_LZ,  GKosp_LZ,  GMap16_LZ,  GMap128_LZ	; LZ	; ACT 2
		levartptrs plcid_LZ,  plcid_LZ2,  palid_LZ,  GKosp_LZ,  GMap16_LZ,  GMap128_LZ	; LZ	; ACT 3
		levartptrs plcid_LZ,  plcid_LZ2,  palid_LZ,  GKosp_LZ,  GMap16_LZ,  GMap128_LZ	; LZ	; ACT 4

		; CPZ
		levartptrs plcid_CPZ, plcid_CPZ2, palid_CPZ, GKosp_CPZ, GMap16_CPZ, GMap128_CPZ	; CPZ	; ACT 1
		levartptrs plcid_CPZ, plcid_CPZ2, palid_CPZ, GKosp_CPZ, GMap16_CPZ, GMap128_CPZ	; CPZ	; ACT 2
		levartptrs plcid_CPZ, plcid_CPZ2, palid_CPZ, GKosp_CPZ, GMap16_CPZ, GMap128_CPZ	; CPZ	; ACT 3
		levartptrs plcid_CPZ, plcid_CPZ2, palid_CPZ, GKosp_CPZ, GMap16_CPZ, GMap128_CPZ	; CPZ	; ACT 4

		; EHZ
		levartptrs plcid_EHZ, plcid_EHZ2, palid_EHZ, GKosp_EHZ, GMap16_EHZ, GMap128_EHZ	; EHZ	; ACT 1
		levartptrs plcid_EHZ, plcid_EHZ2, palid_EHZ, GKosp_EHZ, GMap16_EHZ, GMap128_EHZ	; EHZ	; ACT 2
		levartptrs plcid_EHZ, plcid_EHZ2, palid_EHZ, GKosp_EHZ, GMap16_EHZ, GMap128_EHZ	; EHZ	; ACT 3
		levartptrs plcid_EHZ, plcid_EHZ2, palid_EHZ, GKosp_EHZ, GMap16_EHZ, GMap128_EHZ	; EHZ	; ACT 4

		; HPZ
		levartptrs plcid_HPZ, plcid_HPZ2, palid_HPZ, GKosp_HPZ, GMap16_HPZ, GMap128_HPZ	; HPZ	; ACT 1
		levartptrs plcid_HPZ, plcid_HPZ2, palid_HPZ, GKosp_HPZ, GMap16_HPZ, GMap128_HPZ	; HPZ	; ACT 2
		levartptrs plcid_HPZ, plcid_HPZ2, palid_HPZ, GKosp_HPZ, GMap16_HPZ, GMap128_HPZ	; HPZ	; ACT 3
		levartptrs plcid_HPZ, plcid_HPZ2, palid_HPZ, GKosp_HPZ, GMap16_HPZ, GMap128_HPZ	; HPZ	; ACT 4

		; HTZ
		levartptrs plcid_HTZ, plcid_HTZ2, palid_HTZ1, GKosp_HTZ, GMap16_HTZ, GMap128_HTZ	; HTZ	; ACT 1
		levartptrs plcid_HTZ, plcid_HTZ2, palid_HTZ1, GKosp_HTZ, GMap16_HTZ, GMap128_HTZ	; HTZ	; ACT 2
		levartptrs plcid_HTZ, plcid_HTZ2, palid_HTZ1, GKosp_HTZ, GMap16_HTZ, GMap128_HTZ	; HTZ	; ACT 3
		levartptrs plcid_HTZ, plcid_HTZ2, palid_HTZ1, GKosp_HTZ, GMap16_HTZ, GMap128_HTZ	; HTZ	; ACT 4

		; LV6 placeholder
		levartptrs plcid_Filler, plcid_Filler2, palid_MTZ, GKosp_MTZ, GMap16_MTZ, GMap128_MTZ	; LV6Z	; ACT 1
		levartptrs plcid_Filler, plcid_Filler2, palid_MTZ, GKosp_MTZ, GMap16_MTZ, GMap128_MTZ	; LV6Z	; ACT 2
		levartptrs plcid_Filler, plcid_Filler2, palid_MTZ, GKosp_MTZ, GMap16_MTZ, GMap128_MTZ	; LV6Z	; ACT 3
		levartptrs plcid_Filler, plcid_Filler2, palid_MTZ, GKosp_MTZ, GMap16_MTZ, GMap128_MTZ	; LV6Z	; ACT 4

		; LV7 placeholder
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV7, GMap16_LV7, GMap128_LV7	; LV7Z	; ACT 1
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV7, GMap16_LV7, GMap128_LV7	; LV7Z	; ACT 2
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV7, GMap16_LV7, GMap128_LV7	; LV7Z	; ACT 3
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV7, GMap16_LV7, GMap128_LV7	; LV7Z	; ACT 4

		; LV8 placeholder
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV8, GMap16_LV8, GMap128_LV8	; LV8Z	; ACT 1
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV8, GMap16_LV8, GMap128_LV8	; LV8Z	; ACT 2
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV8, GMap16_LV8, GMap128_LV8	; LV8Z	; ACT 3
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV8, GMap16_LV8, GMap128_LV8	; LV8Z	; ACT 4

		; LV9 placeholder
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV9, GMap16_LV9, GMap128_LV9	; LV9Z	; ACT 1
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV9, GMap16_LV9, GMap128_LV9	; LV9Z	; ACT 2
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV9, GMap16_LV9, GMap128_LV9	; LV9Z	; ACT 3
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV9, GMap16_LV9, GMap128_LV9	; LV9Z	; ACT 4

		; LVA placeholder
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVA, GMap16_LVA, GMap128_LVA	; LVAZ	; ACT 1
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVA, GMap16_LVA, GMap128_LVA	; LVAZ	; ACT 2
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVA, GMap16_LVA, GMap128_LVA	; LVAZ	; ACT 3
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVA, GMap16_LVA, GMap128_LVA	; LVAZ	; ACT 4

		; LVB placeholder
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVB, GMap16_LVB, GMap128_LVB	; LVBZ	; ACT 1
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVB, GMap16_LVB, GMap128_LVB	; LVBZ	; ACT 2
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVB, GMap16_LVB, GMap128_LVB	; LVBZ	; ACT 3
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVB, GMap16_LVB, GMap128_LVB	; LVBZ	; ACT 4

		; LVC placeholder
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVC, GMap16_LVC, GMap128_LVC	; LVCZ	; ACT 1
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVC, GMap16_LVC, GMap128_LVC	; LVCZ	; ACT 2
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVC, GMap16_LVC, GMap128_LVC	; LVCZ	; ACT 3
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVC, GMap16_LVC, GMap128_LVC	; LVCZ	; ACT 4

		; LVD placeholder
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVD, GMap16_LVD, GMap128_LVD	; LVDZ	; ACT 1
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVD, GMap16_LVD, GMap128_LVD	; LVDZ	; ACT 2
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVD, GMap16_LVD, GMap128_LVD	; LVDZ	; ACT 3
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVD, GMap16_LVD, GMap128_LVD	; LVDZ	; ACT 4

		; LVE placeholder
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVE, GMap16_LVE, GMap128_LVE	; LVEZ	; ACT 1
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVE, GMap16_LVE, GMap128_LVE	; LVEZ	; ACT 2
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVE, GMap16_LVE, GMap128_LVE	; LVEZ	; ACT 3
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVE, GMap16_LVE, GMap128_LVE	; LVEZ	; ACT 4

		; LVF placeholder
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVF, GMap16_LVF, GMap128_LVF	; LVFZ	; ACT 1
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVF, GMap16_LVF, GMap128_LVF	; LVFZ	; ACT 2
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVF, GMap16_LVF, GMap128_LVF	; LVFZ	; ACT 3
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LVF, GMap16_LVF, GMap128_LVF	; LVFZ	; ACT 4

		; LV10 placeholder
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV10, GMap16_LV10, GMap128_LV10	; LV10Z	; ACT 1
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV10, GMap16_LV10, GMap128_LV10	; LV10Z	; ACT 2
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV10, GMap16_LV10, GMap128_LV10	; LV10Z	; ACT 3
		levartptrs plcid_Filler, plcid_Filler2, palid_GHZ, GKosp_LV10, GMap16_LV10, GMap128_LV10	; LV10Z	; ACT 4
