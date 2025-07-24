SampleDebugger:
	Console.WriteLine "%<pal1>Camera (FG): %<pal0>%<.w Camera_X_pos>-%<.w Camera_Y_pos>"
	Console.WriteLine "%<pal1>Camera (BG): %<pal0>%<.w Camera_BG_X_pos>-%<.w Camera_BG_Y_pos>"
    Console.WriteLine "%<pal1>Sonic Pos: %<pal0>%<.w v_player+obX>-%<.w v_player+obY>"
    Console.WriteLine "%<pal1>Sonic Frame: %<pal0>%<.w v_player+obFrame>"
	Console.BreakLine
	
	Console.WriteLine "%<pal1>Objects IDs in slots:%<pal0>"
	Console.Write "%<setw>%<39>"       ; format slots table nicely ...

	lea 	v_objspace, a0
	move.w 	#(v_lvlobjend-v_objspace)/object_size-1, d0
	
	.DisplayObjSlot:
	    Console.Write "%<.b (a0)> "
	    lea       next_object(a0), a0
	    dbf       d0, .DisplayObjSlot

	rts