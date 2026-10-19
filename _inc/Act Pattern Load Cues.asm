; Each act owns two physical request lists: Main during the title card,
; Extra after terrain loading. Common recipes expand here; add act-only
; plcm entries below a recipe, or replace it with a custom list.
; Main shares the queue with Main2 and the larger Tails life-art list.
; Extra owns all 16 entries. Empty lists use -1.
ActPLC_Main_Reserve equ (PLC_Main2_End-PLC_Main2-2)/6+(PLC_Main2-PLC_LivesTails-2)/6
actplcheader macro {INTLABEL}
__LABEL__ label *
		dc.w (__LABEL___End-__LABEL__-2)/6-1
		endm
actplcend macro list,reserved
		if (*-list-2)/6+reserved>16
			fatal "Act PLC and shared art exceed the 16-entry request queue"
		endif
		endm

PLC_GHZ1_Main: actplcheader
		PLC_GHZ_Art
PLC_GHZ1_Main_End: actplcend PLC_GHZ1_Main,ActPLC_Main_Reserve

PLC_GHZ1_Extra: actplcheader
		PLC_GHZ2_Art
PLC_GHZ1_Extra_End: actplcend PLC_GHZ1_Extra,0

PLC_GHZ2_Main: actplcheader
		PLC_GHZ_Art
PLC_GHZ2_Main_End: actplcend PLC_GHZ2_Main,ActPLC_Main_Reserve

PLC_GHZ2_Extra: actplcheader
		PLC_GHZ2_Art
PLC_GHZ2_Extra_End: actplcend PLC_GHZ2_Extra,0

PLC_GHZ3_Main: actplcheader
		PLC_GHZ_Art
PLC_GHZ3_Main_End: actplcend PLC_GHZ3_Main,ActPLC_Main_Reserve

PLC_GHZ3_Extra: actplcheader
		PLC_GHZ2_Art
PLC_GHZ3_Extra_End: actplcend PLC_GHZ3_Extra,0

PLC_GHZ4_Main: actplcheader
		PLC_GHZ_Art
PLC_GHZ4_Main_End: actplcend PLC_GHZ4_Main,ActPLC_Main_Reserve

PLC_GHZ4_Extra: actplcheader
		PLC_GHZ2_Art
PLC_GHZ4_Extra_End: actplcend PLC_GHZ4_Extra,0

PLC_LZ1_Main: actplcheader
		PLC_LZ_Art
PLC_LZ1_Main_End: actplcend PLC_LZ1_Main,ActPLC_Main_Reserve

PLC_LZ1_Extra: actplcheader
		PLC_LZ2_Art
PLC_LZ1_Extra_End: actplcend PLC_LZ1_Extra,0

PLC_LZ2_Main: actplcheader
		PLC_LZ_Art
PLC_LZ2_Main_End: actplcend PLC_LZ2_Main,ActPLC_Main_Reserve

PLC_LZ2_Extra: actplcheader
		PLC_LZ2_Art
PLC_LZ2_Extra_End: actplcend PLC_LZ2_Extra,0

PLC_LZ3_Main: actplcheader
		PLC_LZ_Art
PLC_LZ3_Main_End: actplcend PLC_LZ3_Main,ActPLC_Main_Reserve

PLC_LZ3_Extra: actplcheader
		PLC_LZ2_Art
PLC_LZ3_Extra_End: actplcend PLC_LZ3_Extra,0

PLC_LZ4_Main: actplcheader
		PLC_LZ_Art
PLC_LZ4_Main_End: actplcend PLC_LZ4_Main,ActPLC_Main_Reserve

PLC_LZ4_Extra: actplcheader
		PLC_LZ2_Art
PLC_LZ4_Extra_End: actplcend PLC_LZ4_Extra,0

PLC_CPZ1_Main: actplcheader
		PLC_CPZ_Art
PLC_CPZ1_Main_End: actplcend PLC_CPZ1_Main,ActPLC_Main_Reserve

PLC_CPZ1_Extra: actplcheader
		PLC_CPZ2_Art
PLC_CPZ1_Extra_End: actplcend PLC_CPZ1_Extra,0

PLC_CPZ2_Main: actplcheader
		PLC_CPZ_Art
PLC_CPZ2_Main_End: actplcend PLC_CPZ2_Main,ActPLC_Main_Reserve

PLC_CPZ2_Extra: actplcheader
		PLC_CPZ2_Art
PLC_CPZ2_Extra_End: actplcend PLC_CPZ2_Extra,0

PLC_CPZ3_Main: actplcheader
		PLC_CPZ_Art
PLC_CPZ3_Main_End: actplcend PLC_CPZ3_Main,ActPLC_Main_Reserve

PLC_CPZ3_Extra: actplcheader
		PLC_CPZ2_Art
PLC_CPZ3_Extra_End: actplcend PLC_CPZ3_Extra,0

PLC_CPZ4_Main: actplcheader
		PLC_CPZ_Art
PLC_CPZ4_Main_End: actplcend PLC_CPZ4_Main,ActPLC_Main_Reserve

PLC_CPZ4_Extra: actplcheader
		PLC_CPZ2_Art
PLC_CPZ4_Extra_End: actplcend PLC_CPZ4_Extra,0

PLC_EHZ1_Main: actplcheader
		PLC_EHZ_Art
PLC_EHZ1_Main_End: actplcend PLC_EHZ1_Main,ActPLC_Main_Reserve

PLC_EHZ1_Extra: actplcheader
		PLC_EHZ2_Art
PLC_EHZ1_Extra_End: actplcend PLC_EHZ1_Extra,0

PLC_EHZ2_Main: actplcheader
		PLC_EHZ_Art
PLC_EHZ2_Main_End: actplcend PLC_EHZ2_Main,ActPLC_Main_Reserve

PLC_EHZ2_Extra: actplcheader
		PLC_EHZ2_Art
PLC_EHZ2_Extra_End: actplcend PLC_EHZ2_Extra,0

PLC_EHZ3_Main: actplcheader
		PLC_EHZ_Art
PLC_EHZ3_Main_End: actplcend PLC_EHZ3_Main,ActPLC_Main_Reserve

PLC_EHZ3_Extra: actplcheader
		PLC_EHZ2_Art
PLC_EHZ3_Extra_End: actplcend PLC_EHZ3_Extra,0

PLC_EHZ4_Main: actplcheader
		PLC_EHZ_Art
PLC_EHZ4_Main_End: actplcend PLC_EHZ4_Main,ActPLC_Main_Reserve

PLC_EHZ4_Extra: actplcheader
		PLC_EHZ2_Art
PLC_EHZ4_Extra_End: actplcend PLC_EHZ4_Extra,0

PLC_HPZ1_Main: actplcheader
		PLC_HPZ_Art
PLC_HPZ1_Main_End: actplcend PLC_HPZ1_Main,ActPLC_Main_Reserve

PLC_HPZ1_Extra: actplcheader
		PLC_HPZ2_Art
PLC_HPZ1_Extra_End: actplcend PLC_HPZ1_Extra,0

PLC_HPZ2_Main: actplcheader
		PLC_HPZ_Art
PLC_HPZ2_Main_End: actplcend PLC_HPZ2_Main,ActPLC_Main_Reserve

PLC_HPZ2_Extra: actplcheader
		PLC_HPZ2_Art
PLC_HPZ2_Extra_End: actplcend PLC_HPZ2_Extra,0

PLC_HPZ3_Main: actplcheader
		PLC_HPZ_Art
PLC_HPZ3_Main_End: actplcend PLC_HPZ3_Main,ActPLC_Main_Reserve

PLC_HPZ3_Extra: actplcheader
		PLC_HPZ2_Art
PLC_HPZ3_Extra_End: actplcend PLC_HPZ3_Extra,0

PLC_HPZ4_Main: actplcheader
		PLC_HPZ_Art
PLC_HPZ4_Main_End: actplcend PLC_HPZ4_Main,ActPLC_Main_Reserve

PLC_HPZ4_Extra: actplcheader
		PLC_HPZ2_Art
PLC_HPZ4_Extra_End: actplcend PLC_HPZ4_Extra,0

PLC_HTZ1_Main: actplcheader
		PLC_HTZ_Art
PLC_HTZ1_Main_End: actplcend PLC_HTZ1_Main,ActPLC_Main_Reserve

PLC_HTZ1_Extra: actplcheader
		PLC_HTZ2_Art
PLC_HTZ1_Extra_End: actplcend PLC_HTZ1_Extra,0

PLC_HTZ2_Main: actplcheader
		PLC_HTZ_Art
PLC_HTZ2_Main_End: actplcend PLC_HTZ2_Main,ActPLC_Main_Reserve

PLC_HTZ2_Extra: actplcheader
		PLC_HTZ2_Art
PLC_HTZ2_Extra_End: actplcend PLC_HTZ2_Extra,0

PLC_HTZ3_Main: actplcheader
		PLC_HTZ_Art
PLC_HTZ3_Main_End: actplcend PLC_HTZ3_Main,ActPLC_Main_Reserve

PLC_HTZ3_Extra: actplcheader
		PLC_HTZ2_Art
PLC_HTZ3_Extra_End: actplcend PLC_HTZ3_Extra,0

PLC_HTZ4_Main: actplcheader
		PLC_HTZ_Art
PLC_HTZ4_Main_End: actplcend PLC_HTZ4_Main,ActPLC_Main_Reserve

PLC_HTZ4_Extra: actplcheader
		PLC_HTZ2_Art
PLC_HTZ4_Extra_End: actplcend PLC_HTZ4_Extra,0

PLC_LV61_Main: actplcheader
		PLC_Filler_Art
PLC_LV61_Main_End: actplcend PLC_LV61_Main,ActPLC_Main_Reserve

PLC_LV61_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV61_Extra_End: actplcend PLC_LV61_Extra,0

PLC_LV62_Main: actplcheader
		PLC_Filler_Art
PLC_LV62_Main_End: actplcend PLC_LV62_Main,ActPLC_Main_Reserve

PLC_LV62_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV62_Extra_End: actplcend PLC_LV62_Extra,0

PLC_LV63_Main: actplcheader
		PLC_Filler_Art
PLC_LV63_Main_End: actplcend PLC_LV63_Main,ActPLC_Main_Reserve

PLC_LV63_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV63_Extra_End: actplcend PLC_LV63_Extra,0

PLC_LV64_Main: actplcheader
		PLC_Filler_Art
PLC_LV64_Main_End: actplcend PLC_LV64_Main,ActPLC_Main_Reserve

PLC_LV64_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV64_Extra_End: actplcend PLC_LV64_Extra,0

PLC_LV71_Main: actplcheader
		PLC_Filler_Art
PLC_LV71_Main_End: actplcend PLC_LV71_Main,ActPLC_Main_Reserve

PLC_LV71_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV71_Extra_End: actplcend PLC_LV71_Extra,0

PLC_LV72_Main: actplcheader
		PLC_Filler_Art
PLC_LV72_Main_End: actplcend PLC_LV72_Main,ActPLC_Main_Reserve

PLC_LV72_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV72_Extra_End: actplcend PLC_LV72_Extra,0

PLC_LV73_Main: actplcheader
		PLC_Filler_Art
PLC_LV73_Main_End: actplcend PLC_LV73_Main,ActPLC_Main_Reserve

PLC_LV73_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV73_Extra_End: actplcend PLC_LV73_Extra,0

PLC_LV74_Main: actplcheader
		PLC_Filler_Art
PLC_LV74_Main_End: actplcend PLC_LV74_Main,ActPLC_Main_Reserve

PLC_LV74_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV74_Extra_End: actplcend PLC_LV74_Extra,0

PLC_SMZ1_Main: actplcheader
		PLC_SMZ_Art
PLC_SMZ1_Main_End: actplcend PLC_SMZ1_Main,ActPLC_Main_Reserve

PLC_SMZ1_Extra: actplcheader
		PLC_SMZ2_Art
PLC_SMZ1_Extra_End: actplcend PLC_SMZ1_Extra,0

PLC_SMZ2_Main: actplcheader
		PLC_SMZIndoor_Art
PLC_SMZ2_Main_End: actplcend PLC_SMZ2_Main,ActPLC_Main_Reserve

PLC_SMZ2_Extra: actplcheader
		PLC_SMZ2_Art
PLC_SMZ2_Extra_End: actplcend PLC_SMZ2_Extra,0

PLC_SMZ3_Main: actplcheader
		PLC_SMZ_Art
PLC_SMZ3_Main_End: actplcend PLC_SMZ3_Main,ActPLC_Main_Reserve

PLC_SMZ3_Extra: actplcheader
		PLC_SMZ2_Art
PLC_SMZ3_Extra_End: actplcend PLC_SMZ3_Extra,0

PLC_SMZ4_Main: actplcheader
		PLC_SMZ_Art
PLC_SMZ4_Main_End: actplcend PLC_SMZ4_Main,ActPLC_Main_Reserve

PLC_SMZ4_Extra: actplcheader
		PLC_SMZ2_Art
PLC_SMZ4_Extra_End: actplcend PLC_SMZ4_Extra,0

PLC_LV91_Main: actplcheader
		PLC_Filler_Art
PLC_LV91_Main_End: actplcend PLC_LV91_Main,ActPLC_Main_Reserve

PLC_LV91_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV91_Extra_End: actplcend PLC_LV91_Extra,0

PLC_LV92_Main: actplcheader
		PLC_Filler_Art
PLC_LV92_Main_End: actplcend PLC_LV92_Main,ActPLC_Main_Reserve

PLC_LV92_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV92_Extra_End: actplcend PLC_LV92_Extra,0

PLC_LV93_Main: actplcheader
		PLC_Filler_Art
PLC_LV93_Main_End: actplcend PLC_LV93_Main,ActPLC_Main_Reserve

PLC_LV93_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV93_Extra_End: actplcend PLC_LV93_Extra,0

PLC_LV94_Main: actplcheader
		PLC_Filler_Art
PLC_LV94_Main_End: actplcend PLC_LV94_Main,ActPLC_Main_Reserve

PLC_LV94_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV94_Extra_End: actplcend PLC_LV94_Extra,0

PLC_PP1_Main: actplcheader
		PLC_PP_Art
PLC_PP1_Main_End: actplcend PLC_PP1_Main,ActPLC_Main_Reserve

PLC_PP1_Extra: actplcheader
		PLC_Filler2_Art
PLC_PP1_Extra_End: actplcend PLC_PP1_Extra,0

PLC_PP2_Main: actplcheader
		PLC_PP_Art
PLC_PP2_Main_End: actplcend PLC_PP2_Main,ActPLC_Main_Reserve

PLC_PP2_Extra: actplcheader
		PLC_Filler2_Art
PLC_PP2_Extra_End: actplcend PLC_PP2_Extra,0

PLC_PP3_Main: actplcheader
		PLC_PP_Art
PLC_PP3_Main_End: actplcend PLC_PP3_Main,ActPLC_Main_Reserve

PLC_PP3_Extra: actplcheader
		PLC_Filler2_Art
PLC_PP3_Extra_End: actplcend PLC_PP3_Extra,0

PLC_PP4_Main: actplcheader
		PLC_PP_Art
PLC_PP4_Main_End: actplcend PLC_PP4_Main,ActPLC_Main_Reserve

PLC_PP4_Extra: actplcheader
		PLC_Filler2_Art
PLC_PP4_Extra_End: actplcend PLC_PP4_Extra,0

PLC_LVB1_Main: actplcheader
		PLC_Filler_Art
PLC_LVB1_Main_End: actplcend PLC_LVB1_Main,ActPLC_Main_Reserve

PLC_LVB1_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVB1_Extra_End: actplcend PLC_LVB1_Extra,0

PLC_LVB2_Main: actplcheader
		PLC_Filler_Art
PLC_LVB2_Main_End: actplcend PLC_LVB2_Main,ActPLC_Main_Reserve

PLC_LVB2_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVB2_Extra_End: actplcend PLC_LVB2_Extra,0

PLC_LVB3_Main: actplcheader
		PLC_Filler_Art
PLC_LVB3_Main_End: actplcend PLC_LVB3_Main,ActPLC_Main_Reserve

PLC_LVB3_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVB3_Extra_End: actplcend PLC_LVB3_Extra,0

PLC_LVB4_Main: actplcheader
		PLC_Filler_Art
PLC_LVB4_Main_End: actplcend PLC_LVB4_Main,ActPLC_Main_Reserve

PLC_LVB4_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVB4_Extra_End: actplcend PLC_LVB4_Extra,0

PLC_LVC1_Main: actplcheader
		PLC_Filler_Art
PLC_LVC1_Main_End: actplcend PLC_LVC1_Main,ActPLC_Main_Reserve

PLC_LVC1_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVC1_Extra_End: actplcend PLC_LVC1_Extra,0

PLC_LVC2_Main: actplcheader
		PLC_Filler_Art
PLC_LVC2_Main_End: actplcend PLC_LVC2_Main,ActPLC_Main_Reserve

PLC_LVC2_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVC2_Extra_End: actplcend PLC_LVC2_Extra,0

PLC_LVC3_Main: actplcheader
		PLC_Filler_Art
PLC_LVC3_Main_End: actplcend PLC_LVC3_Main,ActPLC_Main_Reserve

PLC_LVC3_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVC3_Extra_End: actplcend PLC_LVC3_Extra,0

PLC_LVC4_Main: actplcheader
		PLC_Filler_Art
PLC_LVC4_Main_End: actplcend PLC_LVC4_Main,ActPLC_Main_Reserve

PLC_LVC4_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVC4_Extra_End: actplcend PLC_LVC4_Extra,0

PLC_LVD1_Main: actplcheader
		PLC_Filler_Art
PLC_LVD1_Main_End: actplcend PLC_LVD1_Main,ActPLC_Main_Reserve

PLC_LVD1_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVD1_Extra_End: actplcend PLC_LVD1_Extra,0

PLC_LVD2_Main: actplcheader
		PLC_Filler_Art
PLC_LVD2_Main_End: actplcend PLC_LVD2_Main,ActPLC_Main_Reserve

PLC_LVD2_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVD2_Extra_End: actplcend PLC_LVD2_Extra,0

PLC_LVD3_Main: actplcheader
		PLC_Filler_Art
PLC_LVD3_Main_End: actplcend PLC_LVD3_Main,ActPLC_Main_Reserve

PLC_LVD3_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVD3_Extra_End: actplcend PLC_LVD3_Extra,0

PLC_LVD4_Main: actplcheader
		PLC_Filler_Art
PLC_LVD4_Main_End: actplcend PLC_LVD4_Main,ActPLC_Main_Reserve

PLC_LVD4_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVD4_Extra_End: actplcend PLC_LVD4_Extra,0

PLC_LVE1_Main: actplcheader
		PLC_Filler_Art
PLC_LVE1_Main_End: actplcend PLC_LVE1_Main,ActPLC_Main_Reserve

PLC_LVE1_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVE1_Extra_End: actplcend PLC_LVE1_Extra,0

PLC_LVE2_Main: actplcheader
		PLC_Filler_Art
PLC_LVE2_Main_End: actplcend PLC_LVE2_Main,ActPLC_Main_Reserve

PLC_LVE2_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVE2_Extra_End: actplcend PLC_LVE2_Extra,0

PLC_LVE3_Main: actplcheader
		PLC_Filler_Art
PLC_LVE3_Main_End: actplcend PLC_LVE3_Main,ActPLC_Main_Reserve

PLC_LVE3_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVE3_Extra_End: actplcend PLC_LVE3_Extra,0

PLC_LVE4_Main: actplcheader
		PLC_Filler_Art
PLC_LVE4_Main_End: actplcend PLC_LVE4_Main,ActPLC_Main_Reserve

PLC_LVE4_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVE4_Extra_End: actplcend PLC_LVE4_Extra,0

PLC_LVF1_Main: actplcheader
		PLC_Filler_Art
PLC_LVF1_Main_End: actplcend PLC_LVF1_Main,ActPLC_Main_Reserve

PLC_LVF1_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVF1_Extra_End: actplcend PLC_LVF1_Extra,0

PLC_LVF2_Main: actplcheader
		PLC_Filler_Art
PLC_LVF2_Main_End: actplcend PLC_LVF2_Main,ActPLC_Main_Reserve

PLC_LVF2_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVF2_Extra_End: actplcend PLC_LVF2_Extra,0

PLC_LVF3_Main: actplcheader
		PLC_Filler_Art
PLC_LVF3_Main_End: actplcend PLC_LVF3_Main,ActPLC_Main_Reserve

PLC_LVF3_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVF3_Extra_End: actplcend PLC_LVF3_Extra,0

PLC_LVF4_Main: actplcheader
		PLC_Filler_Art
PLC_LVF4_Main_End: actplcend PLC_LVF4_Main,ActPLC_Main_Reserve

PLC_LVF4_Extra: actplcheader
		PLC_Filler2_Art
PLC_LVF4_Extra_End: actplcend PLC_LVF4_Extra,0

PLC_LV101_Main: actplcheader
		PLC_Filler_Art
PLC_LV101_Main_End: actplcend PLC_LV101_Main,ActPLC_Main_Reserve

PLC_LV101_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV101_Extra_End: actplcend PLC_LV101_Extra,0

PLC_LV102_Main: actplcheader
		PLC_Filler_Art
PLC_LV102_Main_End: actplcend PLC_LV102_Main,ActPLC_Main_Reserve

PLC_LV102_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV102_Extra_End: actplcend PLC_LV102_Extra,0

PLC_LV103_Main: actplcheader
		PLC_Filler_Art
PLC_LV103_Main_End: actplcend PLC_LV103_Main,ActPLC_Main_Reserve

PLC_LV103_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV103_Extra_End: actplcend PLC_LV103_Extra,0

PLC_LV104_Main: actplcheader
		PLC_Filler_Art
PLC_LV104_Main_End: actplcend PLC_LV104_Main,ActPLC_Main_Reserve

PLC_LV104_Extra: actplcheader
		PLC_Filler2_Art
PLC_LV104_Extra_End: actplcend PLC_LV104_Extra,0
