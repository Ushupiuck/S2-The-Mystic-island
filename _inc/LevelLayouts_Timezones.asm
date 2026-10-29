; Dummy timezone layouts currently copy Present, with four entries per zone.
; Edit these files independently when adding time-travel layouts.
; ---------------------------------------------------------------------------
Level_Index_Past:
		dc.w PLevel_GHZ1-Level_Index_Past
		dc.w PLevel_GHZ2-Level_Index_Past
		dc.w PLevel_GHZ3-Level_Index_Past
		dc.w PLevel_GHZ4-Level_Index_Past
		dc.w PLevel_LZ1-Level_Index_Past
		dc.w PLevel_LZ2-Level_Index_Past
		dc.w PLevel_LZ3-Level_Index_Past
		dc.w PLevel_LZ4-Level_Index_Past
		dc.w PLevel_CPZ1-Level_Index_Past
		dc.w PLevel_CPZ2-Level_Index_Past
		dc.w PLevel_CPZ3-Level_Index_Past
		dc.w PLevel_CPZ4-Level_Index_Past
		dc.w PLevel_EHZ1-Level_Index_Past
		dc.w PLevel_EHZ2-Level_Index_Past
		dc.w PLevel_EHZ3-Level_Index_Past
		dc.w PLevel_EHZ4-Level_Index_Past
		dc.w PLevel_HPZ1-Level_Index_Past
		dc.w PLevel_HPZ2-Level_Index_Past
		dc.w PLevel_HPZ3-Level_Index_Past
		dc.w PLevel_HPZ4-Level_Index_Past
		dc.w PLevel_HTZ1-Level_Index_Past
		dc.w PLevel_HTZ2-Level_Index_Past
		dc.w PLevel_HTZ3-Level_Index_Past
		dc.w PLevel_HTZ4-Level_Index_Past
		dc.w PLevel_MTZ1-Level_Index_Past
		dc.w PLevel_MTZ2-Level_Index_Past
		dc.w PLevel_MTZ3-Level_Index_Past
		dc.w PLevel_MTZ4-Level_Index_Past

		dc.w PLevel_LV071-Level_Index_Past
		dc.w PLevel_LV072-Level_Index_Past
		dc.w PLevel_LV073-Level_Index_Past
		dc.w PLevel_LV074-Level_Index_Past
		dc.w PLevel_SMZ1-Level_Index_Past
		dc.w PLevel_SMZ2-Level_Index_Past
		dc.w PLevel_SMZ3-Level_Index_Past
		dc.w PLevel_SMZ4-Level_Index_Past
		dc.w PLevel_LV091-Level_Index_Past
		dc.w PLevel_LV092-Level_Index_Past
		dc.w PLevel_LV093-Level_Index_Past
		dc.w PLevel_LV094-Level_Index_Past
		dc.w PLevel_LV0A1-Level_Index_Past
		dc.w PLevel_LV0A2-Level_Index_Past
		dc.w PLevel_LV0A3-Level_Index_Past
		dc.w PLevel_LV0A4-Level_Index_Past
		dc.w PLevel_LV0B1-Level_Index_Past
		dc.w PLevel_LV0B2-Level_Index_Past
		dc.w PLevel_LV0B3-Level_Index_Past
		dc.w PLevel_LV0B4-Level_Index_Past
		dc.w PLevel_LV0C1-Level_Index_Past
		dc.w PLevel_LV0C2-Level_Index_Past
		dc.w PLevel_LV0C3-Level_Index_Past
		dc.w PLevel_LV0C4-Level_Index_Past
		dc.w PLevel_LV0D1-Level_Index_Past
		dc.w PLevel_LV0D2-Level_Index_Past
		dc.w PLevel_LV0D3-Level_Index_Past
		dc.w PLevel_LV0D4-Level_Index_Past
		dc.w PLevel_LV0E1-Level_Index_Past
		dc.w PLevel_LV0E2-Level_Index_Past
		dc.w PLevel_LV0E3-Level_Index_Past
		dc.w PLevel_LV0E4-Level_Index_Past
		dc.w PLevel_LV0F1-Level_Index_Past
		dc.w PLevel_LV0F2-Level_Index_Past
		dc.w PLevel_LV0F3-Level_Index_Past
		dc.w PLevel_LV0F4-Level_Index_Past

PLevel_GHZ1:
 if MegaCDMode1
		binclude "level/layout/past/GHZ_1.kosp"
 else
		binclude "md-only/layout/past/GHZ_1.kosp"
 endif
		even
PLevel_GHZ2:
 if MegaCDMode1
		binclude "level/layout/past/GHZ_2.kosp"
 else
		binclude "md-only/layout/past/GHZ_2.kosp"
 endif
		even
PLevel_GHZ3:
 if MegaCDMode1
		binclude "level/layout/past/GHZ_3.kosp"
 else
		binclude "md-only/layout/past/GHZ_3.kosp"
 endif
		even
PLevel_GHZ4:
 if MegaCDMode1
		binclude "level/layout/past/GHZ_4.kosp"
 else
		binclude "md-only/layout/past/GHZ_4.kosp"
 endif
		even
PLevel_LZ1:
 if MegaCDMode1
		binclude "level/layout/past/LZ_1.kosp"
 else
		binclude "md-only/layout/past/LZ_1.kosp"
 endif
		even
PLevel_LZ2:
 if MegaCDMode1
		binclude "level/layout/past/LZ_2.kosp"
 else
		binclude "md-only/layout/past/LZ_2.kosp"
 endif
		even
PLevel_LZ3:
 if MegaCDMode1
		binclude "level/layout/past/LZ_3.kosp"
 else
		binclude "md-only/layout/past/LZ_3.kosp"
 endif
		even
PLevel_LZ4:
 if MegaCDMode1
		binclude "level/layout/past/LZ_4.kosp"
 else
		binclude "md-only/layout/past/LZ_4.kosp"
 endif
		even
PLevel_CPZ1:
 if MegaCDMode1
		binclude "level/layout/past/CPZ_1.kosp"
 else
		binclude "md-only/layout/past/CPZ_1.kosp"
 endif
		even
PLevel_CPZ2:
 if MegaCDMode1
		binclude "level/layout/past/CPZ_2.kosp"
 else
		binclude "md-only/layout/past/CPZ_2.kosp"
 endif
		even
PLevel_CPZ3:
 if MegaCDMode1
		binclude "level/layout/past/CPZ_3.kosp"
 else
		binclude "md-only/layout/past/CPZ_3.kosp"
 endif
		even
PLevel_CPZ4:
 if MegaCDMode1
		binclude "level/layout/past/CPZ_4.kosp"
 else
		binclude "md-only/layout/past/CPZ_4.kosp"
 endif
		even
PLevel_EHZ1:
 if MegaCDMode1
		binclude "level/layout/past/EHZ_1.kosp"
 else
		binclude "md-only/layout/past/EHZ_1.kosp"
 endif
		even
PLevel_EHZ2:
 if MegaCDMode1
		binclude "level/layout/past/EHZ_2.kosp"
 else
		binclude "md-only/layout/past/EHZ_2.kosp"
 endif
		even
PLevel_EHZ3:
 if MegaCDMode1
		binclude "level/layout/past/EHZ_3.kosp"
 else
		binclude "md-only/layout/past/EHZ_3.kosp"
 endif
		even
PLevel_EHZ4:
 if MegaCDMode1
		binclude "level/layout/past/EHZ_4.kosp"
 else
		binclude "md-only/layout/past/EHZ_4.kosp"
 endif
		even
PLevel_HPZ1:
 if MegaCDMode1
		binclude "level/layout/past/HPZ_1.kosp"
 else
		binclude "md-only/layout/past/HPZ_1.kosp"
 endif
		even
PLevel_HPZ2:
 if MegaCDMode1
		binclude "level/layout/past/HPZ_2.kosp"
 else
		binclude "md-only/layout/past/HPZ_2.kosp"
 endif
		even
PLevel_HPZ3:
 if MegaCDMode1
		binclude "level/layout/past/HPZ_3.kosp"
 else
		binclude "md-only/layout/past/HPZ_3.kosp"
 endif
		even
PLevel_HPZ4:
 if MegaCDMode1
		binclude "level/layout/past/HPZ_4.kosp"
 else
		binclude "md-only/layout/past/HPZ_4.kosp"
 endif
		even
PLevel_HTZ1:
 if MegaCDMode1
		binclude "level/layout/past/HTZ_1.kosp"
 else
		binclude "md-only/layout/past/HTZ_1.kosp"
 endif
		even
PLevel_HTZ2:
 if MegaCDMode1
		binclude "level/layout/past/HTZ_2.kosp"
 else
		binclude "md-only/layout/past/HTZ_2.kosp"
 endif
		even
PLevel_HTZ3:
 if MegaCDMode1
		binclude "level/layout/past/HTZ_3.kosp"
 else
		binclude "md-only/layout/past/HTZ_3.kosp"
 endif
		even
PLevel_HTZ4:
 if MegaCDMode1
		binclude "level/layout/past/HTZ_4.kosp"
 else
		binclude "md-only/layout/past/HTZ_4.kosp"
 endif
		even
PLevel_MTZ1:
 if MegaCDMode1
		binclude "level/layout/past/MTZ_1.kosp"
 else
		binclude "md-only/layout/past/MTZ_1.kosp"
 endif
		even
PLevel_MTZ2:
 if MegaCDMode1
		binclude "level/layout/past/MTZ_2.kosp"
 else
		binclude "md-only/layout/past/MTZ_2.kosp"
 endif
		even
PLevel_MTZ3:
 if MegaCDMode1
		binclude "level/layout/past/MTZ_3.kosp"
 else
		binclude "md-only/layout/past/MTZ_3.kosp"
 endif
		even
PLevel_MTZ4:
 if MegaCDMode1
		binclude "level/layout/past/MTZ_4.kosp"
 else
		binclude "md-only/layout/past/MTZ_4.kosp"
 endif
		even

PLevel_LV071:
 if MegaCDMode1
		binclude "level/layout/past/LV07_1.kosp"
 else
		binclude "md-only/layout/past/LV07_1.kosp"
 endif
		even
PLevel_LV072:
 if MegaCDMode1
		binclude "level/layout/past/LV07_2.kosp"
 else
		binclude "md-only/layout/past/LV07_2.kosp"
 endif
		even
PLevel_LV073:
 if MegaCDMode1
		binclude "level/layout/past/LV07_3.kosp"
 else
		binclude "md-only/layout/past/LV07_3.kosp"
 endif
		even
PLevel_LV074:
 if MegaCDMode1
		binclude "level/layout/past/LV07_4.kosp"
 else
		binclude "md-only/layout/past/LV07_4.kosp"
 endif
		even
PLevel_SMZ1:
 if MegaCDMode1
		binclude "level/layout/past/SMZ_1.kosp"
 else
		binclude "md-only/layout/past/SMZ_1.kosp"
 endif
		even
PLevel_SMZ2:
 if MegaCDMode1
		binclude "level/layout/past/SMZ_2.kosp"
 else
		binclude "md-only/layout/past/SMZ_2.kosp"
 endif
		even
PLevel_SMZ3:
 if MegaCDMode1
		binclude "level/layout/past/SMZ_3.kosp"
 else
		binclude "md-only/layout/past/SMZ_3.kosp"
 endif
		even
PLevel_SMZ4:
 if MegaCDMode1
		binclude "level/layout/past/SMZ_4.kosp"
 else
		binclude "md-only/layout/past/SMZ_4.kosp"
 endif
		even
PLevel_LV091:
 if MegaCDMode1
		binclude "level/layout/past/LV09_1.kosp"
 else
		binclude "md-only/layout/past/LV09_1.kosp"
 endif
		even
PLevel_LV092:
 if MegaCDMode1
		binclude "level/layout/past/LV09_2.kosp"
 else
		binclude "md-only/layout/past/LV09_2.kosp"
 endif
		even
PLevel_LV093:
 if MegaCDMode1
		binclude "level/layout/past/LV09_3.kosp"
 else
		binclude "md-only/layout/past/LV09_3.kosp"
 endif
		even
PLevel_LV094:
 if MegaCDMode1
		binclude "level/layout/past/LV09_4.kosp"
 else
		binclude "md-only/layout/past/LV09_4.kosp"
 endif
		even
PLevel_LV0A1:
 if MegaCDMode1
		binclude "level/layout/past/LV0A_1.kosp"
 else
		binclude "md-only/layout/past/LV0A_1.kosp"
 endif
		even
PLevel_LV0A2:
 if MegaCDMode1
		binclude "level/layout/past/LV0A_2.kosp"
 else
		binclude "md-only/layout/past/LV0A_2.kosp"
 endif
		even
PLevel_LV0A3:
 if MegaCDMode1
		binclude "level/layout/past/LV0A_3.kosp"
 else
		binclude "md-only/layout/past/LV0A_3.kosp"
 endif
		even
PLevel_LV0A4:
 if MegaCDMode1
		binclude "level/layout/past/LV0A_4.kosp"
 else
		binclude "md-only/layout/past/LV0A_4.kosp"
 endif
		even
PLevel_LV0B1:
 if MegaCDMode1
		binclude "level/layout/past/LV0B_1.kosp"
 else
		binclude "md-only/layout/past/LV0B_1.kosp"
 endif
		even
PLevel_LV0B2:
 if MegaCDMode1
		binclude "level/layout/past/LV0B_2.kosp"
 else
		binclude "md-only/layout/past/LV0B_2.kosp"
 endif
		even
PLevel_LV0B3:
 if MegaCDMode1
		binclude "level/layout/past/LV0B_3.kosp"
 else
		binclude "md-only/layout/past/LV0B_3.kosp"
 endif
		even
PLevel_LV0B4:
 if MegaCDMode1
		binclude "level/layout/past/LV0B_4.kosp"
 else
		binclude "md-only/layout/past/LV0B_4.kosp"
 endif
		even
PLevel_LV0C1:
 if MegaCDMode1
		binclude "level/layout/past/LV0C_1.kosp"
 else
		binclude "md-only/layout/past/LV0C_1.kosp"
 endif
		even
PLevel_LV0C2:
 if MegaCDMode1
		binclude "level/layout/past/LV0C_2.kosp"
 else
		binclude "md-only/layout/past/LV0C_2.kosp"
 endif
		even
PLevel_LV0C3:
 if MegaCDMode1
		binclude "level/layout/past/LV0C_3.kosp"
 else
		binclude "md-only/layout/past/LV0C_3.kosp"
 endif
		even
PLevel_LV0C4:
 if MegaCDMode1
		binclude "level/layout/past/LV0C_4.kosp"
 else
		binclude "md-only/layout/past/LV0C_4.kosp"
 endif
		even
PLevel_LV0D1:
 if MegaCDMode1
		binclude "level/layout/past/LV0D_1.kosp"
 else
		binclude "md-only/layout/past/LV0D_1.kosp"
 endif
		even
PLevel_LV0D2:
 if MegaCDMode1
		binclude "level/layout/past/LV0D_2.kosp"
 else
		binclude "md-only/layout/past/LV0D_2.kosp"
 endif
		even
PLevel_LV0D3:
 if MegaCDMode1
		binclude "level/layout/past/LV0D_3.kosp"
 else
		binclude "md-only/layout/past/LV0D_3.kosp"
 endif
		even
PLevel_LV0D4:
 if MegaCDMode1
		binclude "level/layout/past/LV0D_4.kosp"
 else
		binclude "md-only/layout/past/LV0D_4.kosp"
 endif
		even
PLevel_LV0E1:
 if MegaCDMode1
		binclude "level/layout/past/LV0E_1.kosp"
 else
		binclude "md-only/layout/past/LV0E_1.kosp"
 endif
		even
PLevel_LV0E2:
 if MegaCDMode1
		binclude "level/layout/past/LV0E_2.kosp"
 else
		binclude "md-only/layout/past/LV0E_2.kosp"
 endif
		even
PLevel_LV0E3:
 if MegaCDMode1
		binclude "level/layout/past/LV0E_3.kosp"
 else
		binclude "md-only/layout/past/LV0E_3.kosp"
 endif
		even
PLevel_LV0E4:
 if MegaCDMode1
		binclude "level/layout/past/LV0E_4.kosp"
 else
		binclude "md-only/layout/past/LV0E_4.kosp"
 endif
		even
PLevel_LV0F1:
 if MegaCDMode1
		binclude "level/layout/past/LV0F_1.kosp"
 else
		binclude "md-only/layout/past/LV0F_1.kosp"
 endif
		even
PLevel_LV0F2:
 if MegaCDMode1
		binclude "level/layout/past/LV0F_2.kosp"
 else
		binclude "md-only/layout/past/LV0F_2.kosp"
 endif
		even
PLevel_LV0F3:
 if MegaCDMode1
		binclude "level/layout/past/LV0F_3.kosp"
 else
		binclude "md-only/layout/past/LV0F_3.kosp"
 endif
		even
PLevel_LV0F4:
 if MegaCDMode1
		binclude "level/layout/past/LV0F_4.kosp"
 else
		binclude "md-only/layout/past/LV0F_4.kosp"
 endif
		even

; ---------------------------------------------------------------------------
Level_Index_GoodFuture:
		dc.w GLevel_GHZ1-Level_Index_GoodFuture
		dc.w GLevel_GHZ2-Level_Index_GoodFuture
		dc.w GLevel_GHZ3-Level_Index_GoodFuture
		dc.w GLevel_GHZ4-Level_Index_GoodFuture
		dc.w GLevel_LZ1-Level_Index_GoodFuture
		dc.w GLevel_LZ2-Level_Index_GoodFuture
		dc.w GLevel_LZ3-Level_Index_GoodFuture
		dc.w GLevel_LZ4-Level_Index_GoodFuture
		dc.w GLevel_CPZ1-Level_Index_GoodFuture
		dc.w GLevel_CPZ2-Level_Index_GoodFuture
		dc.w GLevel_CPZ3-Level_Index_GoodFuture
		dc.w GLevel_CPZ4-Level_Index_GoodFuture
		dc.w GLevel_EHZ1-Level_Index_GoodFuture
		dc.w GLevel_EHZ2-Level_Index_GoodFuture
		dc.w GLevel_EHZ3-Level_Index_GoodFuture
		dc.w GLevel_EHZ4-Level_Index_GoodFuture
		dc.w GLevel_HPZ1-Level_Index_GoodFuture
		dc.w GLevel_HPZ2-Level_Index_GoodFuture
		dc.w GLevel_HPZ3-Level_Index_GoodFuture
		dc.w GLevel_HPZ4-Level_Index_GoodFuture
		dc.w GLevel_HTZ1-Level_Index_GoodFuture
		dc.w GLevel_HTZ2-Level_Index_GoodFuture
		dc.w GLevel_HTZ3-Level_Index_GoodFuture
		dc.w GLevel_HTZ4-Level_Index_GoodFuture
		dc.w GLevel_MTZ1-Level_Index_GoodFuture
		dc.w GLevel_MTZ2-Level_Index_GoodFuture
		dc.w GLevel_MTZ3-Level_Index_GoodFuture
		dc.w GLevel_MTZ4-Level_Index_GoodFuture

		dc.w GLevel_LV071-Level_Index_GoodFuture
		dc.w GLevel_LV072-Level_Index_GoodFuture
		dc.w GLevel_LV073-Level_Index_GoodFuture
		dc.w GLevel_LV074-Level_Index_GoodFuture
		dc.w GLevel_SMZ1-Level_Index_GoodFuture
		dc.w GLevel_SMZ2-Level_Index_GoodFuture
		dc.w GLevel_SMZ3-Level_Index_GoodFuture
		dc.w GLevel_SMZ4-Level_Index_GoodFuture
		dc.w GLevel_LV091-Level_Index_GoodFuture
		dc.w GLevel_LV092-Level_Index_GoodFuture
		dc.w GLevel_LV093-Level_Index_GoodFuture
		dc.w GLevel_LV094-Level_Index_GoodFuture
		dc.w GLevel_LV0A1-Level_Index_GoodFuture
		dc.w GLevel_LV0A2-Level_Index_GoodFuture
		dc.w GLevel_LV0A3-Level_Index_GoodFuture
		dc.w GLevel_LV0A4-Level_Index_GoodFuture
		dc.w GLevel_LV0B1-Level_Index_GoodFuture
		dc.w GLevel_LV0B2-Level_Index_GoodFuture
		dc.w GLevel_LV0B3-Level_Index_GoodFuture
		dc.w GLevel_LV0B4-Level_Index_GoodFuture
		dc.w GLevel_LV0C1-Level_Index_GoodFuture
		dc.w GLevel_LV0C2-Level_Index_GoodFuture
		dc.w GLevel_LV0C3-Level_Index_GoodFuture
		dc.w GLevel_LV0C4-Level_Index_GoodFuture
		dc.w GLevel_LV0D1-Level_Index_GoodFuture
		dc.w GLevel_LV0D2-Level_Index_GoodFuture
		dc.w GLevel_LV0D3-Level_Index_GoodFuture
		dc.w GLevel_LV0D4-Level_Index_GoodFuture
		dc.w GLevel_LV0E1-Level_Index_GoodFuture
		dc.w GLevel_LV0E2-Level_Index_GoodFuture
		dc.w GLevel_LV0E3-Level_Index_GoodFuture
		dc.w GLevel_LV0E4-Level_Index_GoodFuture
		dc.w GLevel_LV0F1-Level_Index_GoodFuture
		dc.w GLevel_LV0F2-Level_Index_GoodFuture
		dc.w GLevel_LV0F3-Level_Index_GoodFuture
		dc.w GLevel_LV0F4-Level_Index_GoodFuture

GLevel_GHZ1:
 if MegaCDMode1
		binclude "level/layout/good future/GHZ_1.kosp"
 else
		binclude "md-only/layout/good future/GHZ_1.kosp"
 endif
		even
GLevel_GHZ2:
 if MegaCDMode1
		binclude "level/layout/good future/GHZ_2.kosp"
 else
		binclude "md-only/layout/good future/GHZ_2.kosp"
 endif
		even
GLevel_GHZ3:
 if MegaCDMode1
		binclude "level/layout/good future/GHZ_3.kosp"
 else
		binclude "md-only/layout/good future/GHZ_3.kosp"
 endif
		even
GLevel_GHZ4:
 if MegaCDMode1
		binclude "level/layout/good future/GHZ_4.kosp"
 else
		binclude "md-only/layout/good future/GHZ_4.kosp"
 endif
		even
GLevel_LZ1:
 if MegaCDMode1
		binclude "level/layout/good future/LZ_1.kosp"
 else
		binclude "md-only/layout/good future/LZ_1.kosp"
 endif
		even
GLevel_LZ2:
 if MegaCDMode1
		binclude "level/layout/good future/LZ_2.kosp"
 else
		binclude "md-only/layout/good future/LZ_2.kosp"
 endif
		even
GLevel_LZ3:
 if MegaCDMode1
		binclude "level/layout/good future/LZ_3.kosp"
 else
		binclude "md-only/layout/good future/LZ_3.kosp"
 endif
		even
GLevel_LZ4:
 if MegaCDMode1
		binclude "level/layout/good future/LZ_4.kosp"
 else
		binclude "md-only/layout/good future/LZ_4.kosp"
 endif
		even
GLevel_CPZ1:
 if MegaCDMode1
		binclude "level/layout/good future/CPZ_1.kosp"
 else
		binclude "md-only/layout/good future/CPZ_1.kosp"
 endif
		even
GLevel_CPZ2:
 if MegaCDMode1
		binclude "level/layout/good future/CPZ_2.kosp"
 else
		binclude "md-only/layout/good future/CPZ_2.kosp"
 endif
		even
GLevel_CPZ3:
 if MegaCDMode1
		binclude "level/layout/good future/CPZ_3.kosp"
 else
		binclude "md-only/layout/good future/CPZ_3.kosp"
 endif
		even
GLevel_CPZ4:
 if MegaCDMode1
		binclude "level/layout/good future/CPZ_4.kosp"
 else
		binclude "md-only/layout/good future/CPZ_4.kosp"
 endif
		even
GLevel_EHZ1:
 if MegaCDMode1
		binclude "level/layout/good future/EHZ_1.kosp"
 else
		binclude "md-only/layout/good future/EHZ_1.kosp"
 endif
		even
GLevel_EHZ2:
 if MegaCDMode1
		binclude "level/layout/good future/EHZ_2.kosp"
 else
		binclude "md-only/layout/good future/EHZ_2.kosp"
 endif
		even
GLevel_EHZ3:
 if MegaCDMode1
		binclude "level/layout/good future/EHZ_3.kosp"
 else
		binclude "md-only/layout/good future/EHZ_3.kosp"
 endif
		even
GLevel_EHZ4:
 if MegaCDMode1
		binclude "level/layout/good future/EHZ_4.kosp"
 else
		binclude "md-only/layout/good future/EHZ_4.kosp"
 endif
		even
GLevel_HPZ1:
 if MegaCDMode1
		binclude "level/layout/good future/HPZ_1.kosp"
 else
		binclude "md-only/layout/good future/HPZ_1.kosp"
 endif
		even
GLevel_HPZ2:
 if MegaCDMode1
		binclude "level/layout/good future/HPZ_2.kosp"
 else
		binclude "md-only/layout/good future/HPZ_2.kosp"
 endif
		even
GLevel_HPZ3:
 if MegaCDMode1
		binclude "level/layout/good future/HPZ_3.kosp"
 else
		binclude "md-only/layout/good future/HPZ_3.kosp"
 endif
		even
GLevel_HPZ4:
 if MegaCDMode1
		binclude "level/layout/good future/HPZ_4.kosp"
 else
		binclude "md-only/layout/good future/HPZ_4.kosp"
 endif
		even
GLevel_HTZ1:
 if MegaCDMode1
		binclude "level/layout/good future/HTZ_1.kosp"
 else
		binclude "md-only/layout/good future/HTZ_1.kosp"
 endif
		even
GLevel_HTZ2:
 if MegaCDMode1
		binclude "level/layout/good future/HTZ_2.kosp"
 else
		binclude "md-only/layout/good future/HTZ_2.kosp"
 endif
		even
GLevel_HTZ3:
 if MegaCDMode1
		binclude "level/layout/good future/HTZ_3.kosp"
 else
		binclude "md-only/layout/good future/HTZ_3.kosp"
 endif
		even
GLevel_HTZ4:
 if MegaCDMode1
		binclude "level/layout/good future/HTZ_4.kosp"
 else
		binclude "md-only/layout/good future/HTZ_4.kosp"
 endif
		even
GLevel_MTZ1:
 if MegaCDMode1
		binclude "level/layout/good future/MTZ_1.kosp"
 else
		binclude "md-only/layout/good future/MTZ_1.kosp"
 endif
		even
GLevel_MTZ2:
 if MegaCDMode1
		binclude "level/layout/good future/MTZ_2.kosp"
 else
		binclude "md-only/layout/good future/MTZ_2.kosp"
 endif
		even
GLevel_MTZ3:
 if MegaCDMode1
		binclude "level/layout/good future/MTZ_3.kosp"
 else
		binclude "md-only/layout/good future/MTZ_3.kosp"
 endif
		even
GLevel_MTZ4:
 if MegaCDMode1
		binclude "level/layout/good future/MTZ_4.kosp"
 else
		binclude "md-only/layout/good future/MTZ_4.kosp"
 endif
		even

GLevel_LV071:
 if MegaCDMode1
		binclude "level/layout/good future/LV07_1.kosp"
 else
		binclude "md-only/layout/good future/LV07_1.kosp"
 endif
		even
GLevel_LV072:
 if MegaCDMode1
		binclude "level/layout/good future/LV07_2.kosp"
 else
		binclude "md-only/layout/good future/LV07_2.kosp"
 endif
		even
GLevel_LV073:
 if MegaCDMode1
		binclude "level/layout/good future/LV07_3.kosp"
 else
		binclude "md-only/layout/good future/LV07_3.kosp"
 endif
		even
GLevel_LV074:
 if MegaCDMode1
		binclude "level/layout/good future/LV07_4.kosp"
 else
		binclude "md-only/layout/good future/LV07_4.kosp"
 endif
		even
GLevel_SMZ1:
 if MegaCDMode1
		binclude "level/layout/good future/SMZ_1.kosp"
 else
		binclude "md-only/layout/good future/SMZ_1.kosp"
 endif
		even
GLevel_SMZ2:
 if MegaCDMode1
		binclude "level/layout/good future/SMZ_2.kosp"
 else
		binclude "md-only/layout/good future/SMZ_2.kosp"
 endif
		even
GLevel_SMZ3:
 if MegaCDMode1
		binclude "level/layout/good future/SMZ_3.kosp"
 else
		binclude "md-only/layout/good future/SMZ_3.kosp"
 endif
		even
GLevel_SMZ4:
 if MegaCDMode1
		binclude "level/layout/good future/SMZ_4.kosp"
 else
		binclude "md-only/layout/good future/SMZ_4.kosp"
 endif
		even
GLevel_LV091:
 if MegaCDMode1
		binclude "level/layout/good future/LV09_1.kosp"
 else
		binclude "md-only/layout/good future/LV09_1.kosp"
 endif
		even
GLevel_LV092:
 if MegaCDMode1
		binclude "level/layout/good future/LV09_2.kosp"
 else
		binclude "md-only/layout/good future/LV09_2.kosp"
 endif
		even
GLevel_LV093:
 if MegaCDMode1
		binclude "level/layout/good future/LV09_3.kosp"
 else
		binclude "md-only/layout/good future/LV09_3.kosp"
 endif
		even
GLevel_LV094:
 if MegaCDMode1
		binclude "level/layout/good future/LV09_4.kosp"
 else
		binclude "md-only/layout/good future/LV09_4.kosp"
 endif
		even
GLevel_LV0A1:
 if MegaCDMode1
		binclude "level/layout/good future/LV0A_1.kosp"
 else
		binclude "md-only/layout/good future/LV0A_1.kosp"
 endif
		even
GLevel_LV0A2:
 if MegaCDMode1
		binclude "level/layout/good future/LV0A_2.kosp"
 else
		binclude "md-only/layout/good future/LV0A_2.kosp"
 endif
		even
GLevel_LV0A3:
 if MegaCDMode1
		binclude "level/layout/good future/LV0A_3.kosp"
 else
		binclude "md-only/layout/good future/LV0A_3.kosp"
 endif
		even
GLevel_LV0A4:
 if MegaCDMode1
		binclude "level/layout/good future/LV0A_4.kosp"
 else
		binclude "md-only/layout/good future/LV0A_4.kosp"
 endif
		even
GLevel_LV0B1:
 if MegaCDMode1
		binclude "level/layout/good future/LV0B_1.kosp"
 else
		binclude "md-only/layout/good future/LV0B_1.kosp"
 endif
		even
GLevel_LV0B2:
 if MegaCDMode1
		binclude "level/layout/good future/LV0B_2.kosp"
 else
		binclude "md-only/layout/good future/LV0B_2.kosp"
 endif
		even
GLevel_LV0B3:
 if MegaCDMode1
		binclude "level/layout/good future/LV0B_3.kosp"
 else
		binclude "md-only/layout/good future/LV0B_3.kosp"
 endif
		even
GLevel_LV0B4:
 if MegaCDMode1
		binclude "level/layout/good future/LV0B_4.kosp"
 else
		binclude "md-only/layout/good future/LV0B_4.kosp"
 endif
		even
GLevel_LV0C1:
 if MegaCDMode1
		binclude "level/layout/good future/LV0C_1.kosp"
 else
		binclude "md-only/layout/good future/LV0C_1.kosp"
 endif
		even
GLevel_LV0C2:
 if MegaCDMode1
		binclude "level/layout/good future/LV0C_2.kosp"
 else
		binclude "md-only/layout/good future/LV0C_2.kosp"
 endif
		even
GLevel_LV0C3:
 if MegaCDMode1
		binclude "level/layout/good future/LV0C_3.kosp"
 else
		binclude "md-only/layout/good future/LV0C_3.kosp"
 endif
		even
GLevel_LV0C4:
 if MegaCDMode1
		binclude "level/layout/good future/LV0C_4.kosp"
 else
		binclude "md-only/layout/good future/LV0C_4.kosp"
 endif
		even
GLevel_LV0D1:
 if MegaCDMode1
		binclude "level/layout/good future/LV0D_1.kosp"
 else
		binclude "md-only/layout/good future/LV0D_1.kosp"
 endif
		even
GLevel_LV0D2:
 if MegaCDMode1
		binclude "level/layout/good future/LV0D_2.kosp"
 else
		binclude "md-only/layout/good future/LV0D_2.kosp"
 endif
		even
GLevel_LV0D3:
 if MegaCDMode1
		binclude "level/layout/good future/LV0D_3.kosp"
 else
		binclude "md-only/layout/good future/LV0D_3.kosp"
 endif
		even
GLevel_LV0D4:
 if MegaCDMode1
		binclude "level/layout/good future/LV0D_4.kosp"
 else
		binclude "md-only/layout/good future/LV0D_4.kosp"
 endif
		even
GLevel_LV0E1:
 if MegaCDMode1
		binclude "level/layout/good future/LV0E_1.kosp"
 else
		binclude "md-only/layout/good future/LV0E_1.kosp"
 endif
		even
GLevel_LV0E2:
 if MegaCDMode1
		binclude "level/layout/good future/LV0E_2.kosp"
 else
		binclude "md-only/layout/good future/LV0E_2.kosp"
 endif
		even
GLevel_LV0E3:
 if MegaCDMode1
		binclude "level/layout/good future/LV0E_3.kosp"
 else
		binclude "md-only/layout/good future/LV0E_3.kosp"
 endif
		even
GLevel_LV0E4:
 if MegaCDMode1
		binclude "level/layout/good future/LV0E_4.kosp"
 else
		binclude "md-only/layout/good future/LV0E_4.kosp"
 endif
		even
GLevel_LV0F1:
 if MegaCDMode1
		binclude "level/layout/good future/LV0F_1.kosp"
 else
		binclude "md-only/layout/good future/LV0F_1.kosp"
 endif
		even
GLevel_LV0F2:
 if MegaCDMode1
		binclude "level/layout/good future/LV0F_2.kosp"
 else
		binclude "md-only/layout/good future/LV0F_2.kosp"
 endif
		even
GLevel_LV0F3:
 if MegaCDMode1
		binclude "level/layout/good future/LV0F_3.kosp"
 else
		binclude "md-only/layout/good future/LV0F_3.kosp"
 endif
		even
GLevel_LV0F4:
 if MegaCDMode1
		binclude "level/layout/good future/LV0F_4.kosp"
 else
		binclude "md-only/layout/good future/LV0F_4.kosp"
 endif
		even

; ---------------------------------------------------------------------------
Level_Index_BadFuture:
		dc.w BLevel_GHZ1-Level_Index_BadFuture
		dc.w BLevel_GHZ2-Level_Index_BadFuture
		dc.w BLevel_GHZ3-Level_Index_BadFuture
		dc.w BLevel_GHZ4-Level_Index_BadFuture
		dc.w BLevel_LZ1-Level_Index_BadFuture
		dc.w BLevel_LZ2-Level_Index_BadFuture
		dc.w BLevel_LZ3-Level_Index_BadFuture
		dc.w BLevel_LZ4-Level_Index_BadFuture
		dc.w BLevel_CPZ1-Level_Index_BadFuture
		dc.w BLevel_CPZ2-Level_Index_BadFuture
		dc.w BLevel_CPZ3-Level_Index_BadFuture
		dc.w BLevel_CPZ4-Level_Index_BadFuture
		dc.w BLevel_EHZ1-Level_Index_BadFuture
		dc.w BLevel_EHZ2-Level_Index_BadFuture
		dc.w BLevel_EHZ3-Level_Index_BadFuture
		dc.w BLevel_EHZ4-Level_Index_BadFuture
		dc.w BLevel_HPZ1-Level_Index_BadFuture
		dc.w BLevel_HPZ2-Level_Index_BadFuture
		dc.w BLevel_HPZ3-Level_Index_BadFuture
		dc.w BLevel_HPZ4-Level_Index_BadFuture
		dc.w BLevel_HTZ1-Level_Index_BadFuture
		dc.w BLevel_HTZ2-Level_Index_BadFuture
		dc.w BLevel_HTZ3-Level_Index_BadFuture
		dc.w BLevel_HTZ4-Level_Index_BadFuture
		dc.w BLevel_MTZ1-Level_Index_BadFuture
		dc.w BLevel_MTZ2-Level_Index_BadFuture
		dc.w BLevel_MTZ3-Level_Index_BadFuture
		dc.w BLevel_MTZ4-Level_Index_BadFuture

		dc.w BLevel_LV071-Level_Index_BadFuture
		dc.w BLevel_LV072-Level_Index_BadFuture
		dc.w BLevel_LV073-Level_Index_BadFuture
		dc.w BLevel_LV074-Level_Index_BadFuture
		dc.w BLevel_SMZ1-Level_Index_BadFuture
		dc.w BLevel_SMZ2-Level_Index_BadFuture
		dc.w BLevel_SMZ3-Level_Index_BadFuture
		dc.w BLevel_SMZ4-Level_Index_BadFuture
		dc.w BLevel_LV091-Level_Index_BadFuture
		dc.w BLevel_LV092-Level_Index_BadFuture
		dc.w BLevel_LV093-Level_Index_BadFuture
		dc.w BLevel_LV094-Level_Index_BadFuture
		dc.w BLevel_LV0A1-Level_Index_BadFuture
		dc.w BLevel_LV0A2-Level_Index_BadFuture
		dc.w BLevel_LV0A3-Level_Index_BadFuture
		dc.w BLevel_LV0A4-Level_Index_BadFuture
		dc.w BLevel_LV0B1-Level_Index_BadFuture
		dc.w BLevel_LV0B2-Level_Index_BadFuture
		dc.w BLevel_LV0B3-Level_Index_BadFuture
		dc.w BLevel_LV0B4-Level_Index_BadFuture
		dc.w BLevel_LV0C1-Level_Index_BadFuture
		dc.w BLevel_LV0C2-Level_Index_BadFuture
		dc.w BLevel_LV0C3-Level_Index_BadFuture
		dc.w BLevel_LV0C4-Level_Index_BadFuture
		dc.w BLevel_LV0D1-Level_Index_BadFuture
		dc.w BLevel_LV0D2-Level_Index_BadFuture
		dc.w BLevel_LV0D3-Level_Index_BadFuture
		dc.w BLevel_LV0D4-Level_Index_BadFuture
		dc.w BLevel_LV0E1-Level_Index_BadFuture
		dc.w BLevel_LV0E2-Level_Index_BadFuture
		dc.w BLevel_LV0E3-Level_Index_BadFuture
		dc.w BLevel_LV0E4-Level_Index_BadFuture
		dc.w BLevel_LV0F1-Level_Index_BadFuture
		dc.w BLevel_LV0F2-Level_Index_BadFuture
		dc.w BLevel_LV0F3-Level_Index_BadFuture
		dc.w BLevel_LV0F4-Level_Index_BadFuture

BLevel_GHZ1:
 if MegaCDMode1
		binclude "level/layout/bad future/GHZ_1.kosp"
 else
		binclude "md-only/layout/bad future/GHZ_1.kosp"
 endif
		even
BLevel_GHZ2:
 if MegaCDMode1
		binclude "level/layout/bad future/GHZ_2.kosp"
 else
		binclude "md-only/layout/bad future/GHZ_2.kosp"
 endif
		even
BLevel_GHZ3:
 if MegaCDMode1
		binclude "level/layout/bad future/GHZ_3.kosp"
 else
		binclude "md-only/layout/bad future/GHZ_3.kosp"
 endif
		even
BLevel_GHZ4:
 if MegaCDMode1
		binclude "level/layout/bad future/GHZ_4.kosp"
 else
		binclude "md-only/layout/bad future/GHZ_4.kosp"
 endif
		even
BLevel_LZ1:
 if MegaCDMode1
		binclude "level/layout/bad future/LZ_1.kosp"
 else
		binclude "md-only/layout/bad future/LZ_1.kosp"
 endif
		even
BLevel_LZ2:
 if MegaCDMode1
		binclude "level/layout/bad future/LZ_2.kosp"
 else
		binclude "md-only/layout/bad future/LZ_2.kosp"
 endif
		even
BLevel_LZ3:
 if MegaCDMode1
		binclude "level/layout/bad future/LZ_3.kosp"
 else
		binclude "md-only/layout/bad future/LZ_3.kosp"
 endif
		even
BLevel_LZ4:
 if MegaCDMode1
		binclude "level/layout/bad future/LZ_4.kosp"
 else
		binclude "md-only/layout/bad future/LZ_4.kosp"
 endif
		even
BLevel_CPZ1:
 if MegaCDMode1
		binclude "level/layout/bad future/CPZ_1.kosp"
 else
		binclude "md-only/layout/bad future/CPZ_1.kosp"
 endif
		even
BLevel_CPZ2:
 if MegaCDMode1
		binclude "level/layout/bad future/CPZ_2.kosp"
 else
		binclude "md-only/layout/bad future/CPZ_2.kosp"
 endif
		even
BLevel_CPZ3:
 if MegaCDMode1
		binclude "level/layout/bad future/CPZ_3.kosp"
 else
		binclude "md-only/layout/bad future/CPZ_3.kosp"
 endif
		even
BLevel_CPZ4:
 if MegaCDMode1
		binclude "level/layout/bad future/CPZ_4.kosp"
 else
		binclude "md-only/layout/bad future/CPZ_4.kosp"
 endif
		even
BLevel_EHZ1:
 if MegaCDMode1
		binclude "level/layout/bad future/EHZ_1.kosp"
 else
		binclude "md-only/layout/bad future/EHZ_1.kosp"
 endif
		even
BLevel_EHZ2:
 if MegaCDMode1
		binclude "level/layout/bad future/EHZ_2.kosp"
 else
		binclude "md-only/layout/bad future/EHZ_2.kosp"
 endif
		even
BLevel_EHZ3:
 if MegaCDMode1
		binclude "level/layout/bad future/EHZ_3.kosp"
 else
		binclude "md-only/layout/bad future/EHZ_3.kosp"
 endif
		even
BLevel_EHZ4:
 if MegaCDMode1
		binclude "level/layout/bad future/EHZ_4.kosp"
 else
		binclude "md-only/layout/bad future/EHZ_4.kosp"
 endif
		even
BLevel_HPZ1:
 if MegaCDMode1
		binclude "level/layout/bad future/HPZ_1.kosp"
 else
		binclude "md-only/layout/bad future/HPZ_1.kosp"
 endif
		even
BLevel_HPZ2:
 if MegaCDMode1
		binclude "level/layout/bad future/HPZ_2.kosp"
 else
		binclude "md-only/layout/bad future/HPZ_2.kosp"
 endif
		even
BLevel_HPZ3:
 if MegaCDMode1
		binclude "level/layout/bad future/HPZ_3.kosp"
 else
		binclude "md-only/layout/bad future/HPZ_3.kosp"
 endif
		even
BLevel_HPZ4:
 if MegaCDMode1
		binclude "level/layout/bad future/HPZ_4.kosp"
 else
		binclude "md-only/layout/bad future/HPZ_4.kosp"
 endif
		even
BLevel_HTZ1:
 if MegaCDMode1
		binclude "level/layout/bad future/HTZ_1.kosp"
 else
		binclude "md-only/layout/bad future/HTZ_1.kosp"
 endif
		even
BLevel_HTZ2:
 if MegaCDMode1
		binclude "level/layout/bad future/HTZ_2.kosp"
 else
		binclude "md-only/layout/bad future/HTZ_2.kosp"
 endif
		even
BLevel_HTZ3:
 if MegaCDMode1
		binclude "level/layout/bad future/HTZ_3.kosp"
 else
		binclude "md-only/layout/bad future/HTZ_3.kosp"
 endif
		even
BLevel_HTZ4:
 if MegaCDMode1
		binclude "level/layout/bad future/HTZ_4.kosp"
 else
		binclude "md-only/layout/bad future/HTZ_4.kosp"
 endif
		even
BLevel_MTZ1:
 if MegaCDMode1
		binclude "level/layout/bad future/MTZ_1.kosp"
 else
		binclude "md-only/layout/bad future/MTZ_1.kosp"
 endif
		even
BLevel_MTZ2:
 if MegaCDMode1
		binclude "level/layout/bad future/MTZ_2.kosp"
 else
		binclude "md-only/layout/bad future/MTZ_2.kosp"
 endif
		even
BLevel_MTZ3:
 if MegaCDMode1
		binclude "level/layout/bad future/MTZ_3.kosp"
 else
		binclude "md-only/layout/bad future/MTZ_3.kosp"
 endif
		even
BLevel_MTZ4:
 if MegaCDMode1
		binclude "level/layout/bad future/MTZ_4.kosp"
 else
		binclude "md-only/layout/bad future/MTZ_4.kosp"
 endif
		even

BLevel_LV071:
 if MegaCDMode1
		binclude "level/layout/bad future/LV07_1.kosp"
 else
		binclude "md-only/layout/bad future/LV07_1.kosp"
 endif
		even
BLevel_LV072:
 if MegaCDMode1
		binclude "level/layout/bad future/LV07_2.kosp"
 else
		binclude "md-only/layout/bad future/LV07_2.kosp"
 endif
		even
BLevel_LV073:
 if MegaCDMode1
		binclude "level/layout/bad future/LV07_3.kosp"
 else
		binclude "md-only/layout/bad future/LV07_3.kosp"
 endif
		even
BLevel_LV074:
 if MegaCDMode1
		binclude "level/layout/bad future/LV07_4.kosp"
 else
		binclude "md-only/layout/bad future/LV07_4.kosp"
 endif
		even
BLevel_SMZ1:
 if MegaCDMode1
		binclude "level/layout/bad future/SMZ_1.kosp"
 else
		binclude "md-only/layout/bad future/SMZ_1.kosp"
 endif
		even
BLevel_SMZ2:
 if MegaCDMode1
		binclude "level/layout/bad future/SMZ_2.kosp"
 else
		binclude "md-only/layout/bad future/SMZ_2.kosp"
 endif
		even
BLevel_SMZ3:
 if MegaCDMode1
		binclude "level/layout/bad future/SMZ_3.kosp"
 else
		binclude "md-only/layout/bad future/SMZ_3.kosp"
 endif
		even
BLevel_SMZ4:
 if MegaCDMode1
		binclude "level/layout/bad future/SMZ_4.kosp"
 else
		binclude "md-only/layout/bad future/SMZ_4.kosp"
 endif
		even
BLevel_LV091:
 if MegaCDMode1
		binclude "level/layout/bad future/LV09_1.kosp"
 else
		binclude "md-only/layout/bad future/LV09_1.kosp"
 endif
		even
BLevel_LV092:
 if MegaCDMode1
		binclude "level/layout/bad future/LV09_2.kosp"
 else
		binclude "md-only/layout/bad future/LV09_2.kosp"
 endif
		even
BLevel_LV093:
 if MegaCDMode1
		binclude "level/layout/bad future/LV09_3.kosp"
 else
		binclude "md-only/layout/bad future/LV09_3.kosp"
 endif
		even
BLevel_LV094:
 if MegaCDMode1
		binclude "level/layout/bad future/LV09_4.kosp"
 else
		binclude "md-only/layout/bad future/LV09_4.kosp"
 endif
		even
BLevel_LV0A1:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0A_1.kosp"
 else
		binclude "md-only/layout/bad future/LV0A_1.kosp"
 endif
		even
BLevel_LV0A2:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0A_2.kosp"
 else
		binclude "md-only/layout/bad future/LV0A_2.kosp"
 endif
		even
BLevel_LV0A3:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0A_3.kosp"
 else
		binclude "md-only/layout/bad future/LV0A_3.kosp"
 endif
		even
BLevel_LV0A4:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0A_4.kosp"
 else
		binclude "md-only/layout/bad future/LV0A_4.kosp"
 endif
		even
BLevel_LV0B1:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0B_1.kosp"
 else
		binclude "md-only/layout/bad future/LV0B_1.kosp"
 endif
		even
BLevel_LV0B2:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0B_2.kosp"
 else
		binclude "md-only/layout/bad future/LV0B_2.kosp"
 endif
		even
BLevel_LV0B3:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0B_3.kosp"
 else
		binclude "md-only/layout/bad future/LV0B_3.kosp"
 endif
		even
BLevel_LV0B4:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0B_4.kosp"
 else
		binclude "md-only/layout/bad future/LV0B_4.kosp"
 endif
		even
BLevel_LV0C1:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0C_1.kosp"
 else
		binclude "md-only/layout/bad future/LV0C_1.kosp"
 endif
		even
BLevel_LV0C2:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0C_2.kosp"
 else
		binclude "md-only/layout/bad future/LV0C_2.kosp"
 endif
		even
BLevel_LV0C3:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0C_3.kosp"
 else
		binclude "md-only/layout/bad future/LV0C_3.kosp"
 endif
		even
BLevel_LV0C4:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0C_4.kosp"
 else
		binclude "md-only/layout/bad future/LV0C_4.kosp"
 endif
		even
BLevel_LV0D1:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0D_1.kosp"
 else
		binclude "md-only/layout/bad future/LV0D_1.kosp"
 endif
		even
BLevel_LV0D2:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0D_2.kosp"
 else
		binclude "md-only/layout/bad future/LV0D_2.kosp"
 endif
		even
BLevel_LV0D3:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0D_3.kosp"
 else
		binclude "md-only/layout/bad future/LV0D_3.kosp"
 endif
		even
BLevel_LV0D4:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0D_4.kosp"
 else
		binclude "md-only/layout/bad future/LV0D_4.kosp"
 endif
		even
BLevel_LV0E1:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0E_1.kosp"
 else
		binclude "md-only/layout/bad future/LV0E_1.kosp"
 endif
		even
BLevel_LV0E2:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0E_2.kosp"
 else
		binclude "md-only/layout/bad future/LV0E_2.kosp"
 endif
		even
BLevel_LV0E3:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0E_3.kosp"
 else
		binclude "md-only/layout/bad future/LV0E_3.kosp"
 endif
		even
BLevel_LV0E4:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0E_4.kosp"
 else
		binclude "md-only/layout/bad future/LV0E_4.kosp"
 endif
		even
BLevel_LV0F1:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0F_1.kosp"
 else
		binclude "md-only/layout/bad future/LV0F_1.kosp"
 endif
		even
BLevel_LV0F2:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0F_2.kosp"
 else
		binclude "md-only/layout/bad future/LV0F_2.kosp"
 endif
		even
BLevel_LV0F3:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0F_3.kosp"
 else
		binclude "md-only/layout/bad future/LV0F_3.kosp"
 endif
		even
BLevel_LV0F4:
 if MegaCDMode1
		binclude "level/layout/bad future/LV0F_4.kosp"
 else
		binclude "md-only/layout/bad future/LV0F_4.kosp"
 endif
		even
