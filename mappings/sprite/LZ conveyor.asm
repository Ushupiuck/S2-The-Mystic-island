; All wheel frames share one DPLC bank; normal/spiked platforms stay resident.
Map_LConv:
		dc.w Map_LConv_0-Map_LConv
		dc.w Map_LConv_0-Map_LConv
		dc.w Map_LConv_0-Map_LConv
		dc.w Map_LConv_0-Map_LConv
		dc.w Map_LConv_4-Map_LConv
		dc.w Map_LConv_5-Map_LConv
Map_LConv_0:
		dc.w 1
		dc.b $F0, $0F, $00, $00, $FF, $F0
Map_LConv_4:
		dc.w 1
		dc.b $F8, $0D, $00, $10, $FF, $F0
Map_LConv_5:
		dc.w 1
		dc.b $F8, $0D, $00, $18, $FF, $F0
