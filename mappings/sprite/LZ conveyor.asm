; Conveyor wheels (0-3), normal platform (4), spiked platform (5).
Map_LConv:
		dc.w Map_LConv_0-Map_LConv
		dc.w Map_LConv_1-Map_LConv
		dc.w Map_LConv_2-Map_LConv
		dc.w Map_LConv_3-Map_LConv
		dc.w Map_LConv_4-Map_LConv
		dc.w Map_LConv_5-Map_LConv
Map_LConv_0:
		dc.w 1
		dc.b $F0, $0F, $00, $00, $FF, $F0
Map_LConv_1:
		dc.w 1
		dc.b $F0, $0F, $00, $10, $FF, $F0
Map_LConv_2:
		dc.w 1
		dc.b $F0, $0F, $00, $20, $FF, $F0
Map_LConv_3:
		dc.w 1
		dc.b $F0, $0F, $00, $30, $FF, $F0
Map_LConv_4:
		dc.w 1
		dc.b $F8, $0D, $00, $40, $FF, $F0
Map_LConv_5:
		dc.w 1
		dc.b $F8, $0D, $00, $48, $FF, $F0
