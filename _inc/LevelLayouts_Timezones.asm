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

PLevel_GHZ1:	binclude	"level/layout/past/GHZ_1.kosp"
PLevel_GHZ2:	binclude	"level/layout/past/GHZ_2.kosp"
PLevel_GHZ3:	binclude	"level/layout/past/GHZ_3.kosp"
PLevel_GHZ4:	binclude	"level/layout/past/GHZ_4.kosp"
PLevel_LZ1:	binclude	"level/layout/past/LZ_1.kosp"
PLevel_LZ2:	binclude	"level/layout/past/LZ_2.kosp"
PLevel_LZ3:	binclude	"level/layout/past/LZ_3.kosp"
PLevel_LZ4:	binclude	"level/layout/past/LZ_4.kosp"
PLevel_CPZ1:	binclude	"level/layout/past/CPZ_1.kosp"
PLevel_CPZ2:	binclude	"level/layout/past/CPZ_2.kosp"
PLevel_CPZ3:	binclude	"level/layout/past/CPZ_3.kosp"
PLevel_CPZ4:	binclude	"level/layout/past/CPZ_4.kosp"
PLevel_EHZ1:	binclude	"level/layout/past/EHZ_1.kosp"
PLevel_EHZ2:	binclude	"level/layout/past/EHZ_2.kosp"
PLevel_EHZ3:	binclude	"level/layout/past/EHZ_3.kosp"
PLevel_EHZ4:	binclude	"level/layout/past/EHZ_4.kosp"
PLevel_HPZ1:	binclude	"level/layout/past/HPZ_1.kosp"
PLevel_HPZ2:	binclude	"level/layout/past/HPZ_2.kosp"
PLevel_HPZ3:	binclude	"level/layout/past/HPZ_3.kosp"
PLevel_HPZ4:	binclude	"level/layout/past/HPZ_4.kosp"
PLevel_HTZ1:	binclude	"level/layout/past/HTZ_1.kosp"
PLevel_HTZ2:	binclude	"level/layout/past/HTZ_2.kosp"
PLevel_HTZ3:	binclude	"level/layout/past/HTZ_3.kosp"
PLevel_HTZ4:	binclude	"level/layout/past/HTZ_4.kosp"
PLevel_MTZ1:	binclude	"level/layout/past/MTZ_1.kosp"
PLevel_MTZ2:	binclude	"level/layout/past/MTZ_2.kosp"
PLevel_MTZ3:	binclude	"level/layout/past/MTZ_3.kosp"
PLevel_MTZ4:	binclude	"level/layout/past/MTZ_4.kosp"

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

GLevel_GHZ1:	binclude	"level/layout/good future/GHZ_1.kosp"
GLevel_GHZ2:	binclude	"level/layout/good future/GHZ_2.kosp"
GLevel_GHZ3:	binclude	"level/layout/good future/GHZ_3.kosp"
GLevel_GHZ4:	binclude	"level/layout/good future/GHZ_4.kosp"
GLevel_LZ1:	binclude	"level/layout/good future/LZ_1.kosp"
GLevel_LZ2:	binclude	"level/layout/good future/LZ_2.kosp"
GLevel_LZ3:	binclude	"level/layout/good future/LZ_3.kosp"
GLevel_LZ4:	binclude	"level/layout/good future/LZ_4.kosp"
GLevel_CPZ1:	binclude	"level/layout/good future/CPZ_1.kosp"
GLevel_CPZ2:	binclude	"level/layout/good future/CPZ_2.kosp"
GLevel_CPZ3:	binclude	"level/layout/good future/CPZ_3.kosp"
GLevel_CPZ4:	binclude	"level/layout/good future/CPZ_4.kosp"
GLevel_EHZ1:	binclude	"level/layout/good future/EHZ_1.kosp"
GLevel_EHZ2:	binclude	"level/layout/good future/EHZ_2.kosp"
GLevel_EHZ3:	binclude	"level/layout/good future/EHZ_3.kosp"
GLevel_EHZ4:	binclude	"level/layout/good future/EHZ_4.kosp"
GLevel_HPZ1:	binclude	"level/layout/good future/HPZ_1.kosp"
GLevel_HPZ2:	binclude	"level/layout/good future/HPZ_2.kosp"
GLevel_HPZ3:	binclude	"level/layout/good future/HPZ_3.kosp"
GLevel_HPZ4:	binclude	"level/layout/good future/HPZ_4.kosp"
GLevel_HTZ1:	binclude	"level/layout/good future/HTZ_1.kosp"
GLevel_HTZ2:	binclude	"level/layout/good future/HTZ_2.kosp"
GLevel_HTZ3:	binclude	"level/layout/good future/HTZ_3.kosp"
GLevel_HTZ4:	binclude	"level/layout/good future/HTZ_4.kosp"
GLevel_MTZ1:	binclude	"level/layout/good future/MTZ_1.kosp"
GLevel_MTZ2:	binclude	"level/layout/good future/MTZ_2.kosp"
GLevel_MTZ3:	binclude	"level/layout/good future/MTZ_3.kosp"
GLevel_MTZ4:	binclude	"level/layout/good future/MTZ_4.kosp"

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

BLevel_GHZ1:	binclude	"level/layout/bad future/GHZ_1.kosp"
BLevel_GHZ2:	binclude	"level/layout/bad future/GHZ_2.kosp"
BLevel_GHZ3:	binclude	"level/layout/bad future/GHZ_3.kosp"
BLevel_GHZ4:	binclude	"level/layout/bad future/GHZ_4.kosp"
BLevel_LZ1:	binclude	"level/layout/bad future/LZ_1.kosp"
BLevel_LZ2:	binclude	"level/layout/bad future/LZ_2.kosp"
BLevel_LZ3:	binclude	"level/layout/bad future/LZ_3.kosp"
BLevel_LZ4:	binclude	"level/layout/bad future/LZ_4.kosp"
BLevel_CPZ1:	binclude	"level/layout/bad future/CPZ_1.kosp"
BLevel_CPZ2:	binclude	"level/layout/bad future/CPZ_2.kosp"
BLevel_CPZ3:	binclude	"level/layout/bad future/CPZ_3.kosp"
BLevel_CPZ4:	binclude	"level/layout/bad future/CPZ_4.kosp"
BLevel_EHZ1:	binclude	"level/layout/bad future/EHZ_1.kosp"
BLevel_EHZ2:	binclude	"level/layout/bad future/EHZ_2.kosp"
BLevel_EHZ3:	binclude	"level/layout/bad future/EHZ_3.kosp"
BLevel_EHZ4:	binclude	"level/layout/bad future/EHZ_4.kosp"
BLevel_HPZ1:	binclude	"level/layout/bad future/HPZ_1.kosp"
BLevel_HPZ2:	binclude	"level/layout/bad future/HPZ_2.kosp"
BLevel_HPZ3:	binclude	"level/layout/bad future/HPZ_3.kosp"
BLevel_HPZ4:	binclude	"level/layout/bad future/HPZ_4.kosp"
BLevel_HTZ1:	binclude	"level/layout/bad future/HTZ_1.kosp"
BLevel_HTZ2:	binclude	"level/layout/bad future/HTZ_2.kosp"
BLevel_HTZ3:	binclude	"level/layout/bad future/HTZ_3.kosp"
BLevel_HTZ4:	binclude	"level/layout/bad future/HTZ_4.kosp"
BLevel_MTZ1:	binclude	"level/layout/bad future/MTZ_1.kosp"
BLevel_MTZ2:	binclude	"level/layout/bad future/MTZ_2.kosp"
BLevel_MTZ3:	binclude	"level/layout/bad future/MTZ_3.kosp"
BLevel_MTZ4:	binclude	"level/layout/bad future/MTZ_4.kosp"
