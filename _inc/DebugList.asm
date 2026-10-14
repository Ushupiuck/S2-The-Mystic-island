DebugList:
		dc.w Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList
		dc.w Debug_LZ-DebugList,Debug_LZ-DebugList,Debug_LZ-DebugList,Debug_LZ-DebugList
		dc.w Debug_CPZ-DebugList,Debug_CPZ-DebugList,Debug_CPZ-DebugList,Debug_CPZ-DebugList
		dc.w Debug_EHZ-DebugList,Debug_EHZ-DebugList,Debug_EHZ-DebugList,Debug_EHZ-DebugList
		dc.w Debug_HPZ-DebugList,Debug_HPZ-DebugList,Debug_HPZ-DebugList,Debug_HPZ-DebugList
		dc.w Debug_HTZ-DebugList,Debug_HTZ-DebugList,Debug_HTZ-DebugList,Debug_HTZ-DebugList
		dc.w Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList
		dc.w Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList
		dc.w Debug_SMZ-DebugList,Debug_SMZ-DebugList,Debug_SMZ-DebugList,Debug_SMZ-DebugList
		dc.w Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList
		dc.w Debug_PP-DebugList,Debug_PP-DebugList,Debug_PP-DebugList,Debug_PP-DebugList
		dc.w Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList
		dc.w Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList
		dc.w Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList
		dc.w Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList
		dc.w Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList,Debug_GHZ-DebugList

dbug:	macro map,object,subtype,frame,vram
	dc.l object,map
	dc.b subtype,frame
	dc.w vram
	endm

Debug_GHZ:	dc.w (Debug_GHZ_End-Debug_GHZ-2)/DebugEntry_size
;		mappings	object		subtype	frame	VRAM setting
	dbug	Map_Ring,	Obj12,	0,	0,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj26,	Obj26,	0,	0,	make_art_tile(ArtTile_Monitor,0,0)
	dbug	Map_Obj03,	Obj03,	0,	0,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj03,	Obj03,	9,	1,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj03,	Obj03,	$D,	5,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj17,	SwingingPtfm,	5,	0,	make_art_tile(ArtTile_GHZ_MZ_Swing,0,0)
	dbug	Map_Obj17,	SwingingPtfm,	$15,	0,	make_art_tile(ArtTile_GHZ_MZ_Swing,0,0)
	dbug	Map_Obj17,	SwingingPtfm,	$25,	0,	make_art_tile(ArtTile_GHZ_MZ_Swing,0,0)
	dbug	Map_Obj17,	SwingingPtfm,	$35,	0,	make_art_tile(ArtTile_GHZ_MZ_Swing,0,0)
	dbug	Map_GBall,	SwingingPtfm,	$45,	0,	make_art_tile(ArtTile_GHZ_Giant_Ball,2,0)
	dbug	Map_GBall,	SwingingPtfm,	$55,	0,	make_art_tile(ArtTile_GHZ_Giant_Ball,2,0)
	dbug	Map_Obj17,	SwingingPtfm,	$85,	0,	make_art_tile(ArtTile_GHZ_MZ_Swing,0,0)
;	dbug	Map_Obj17,	id_Obj17,	8,	0,	make_art_tile(ArtTile_GHZ_MZ_Swing,0,0)
	dbug	Map_Crab,	Crabmeat,	0,	0,	make_art_tile(ArtTile_Crabmeat,0,0)
	dbug	Map_obj22,	Obj22,	0,	0,	make_art_tile(ArtTile_Buzz_Bomber,0,0)
	dbug	Map_Obj2B,	Obj2B,	7,	0,	make_art_tile(ArtTile_Chopper,0,0)
	dbug	Map_BallHogV,	Ballhog,	$12,	0,	make_art_tile(ArtTile_Ball_HogV,1,0)
	dbug	Map_BallHogV,	Ballhog,	$13,	0,	make_art_tile(ArtTile_Ball_HogV,1,0)
	dbug	Map_BallHogH,	Ballhog,	$00,	0,	make_art_tile(ArtTile_Ball_HogH,1,0)
	dbug	Map_BallHogH,	Ballhog,	$06,	0,	make_art_tile(ArtTile_Ball_HogH,1,0)
	dbug	Map_Obj36,	Obj36,	0,	0,	make_art_tile(ArtTile_Spikes,0,0)
	dbug	Map_Obj18_GHZ,	Obj18,	0,	0,	make_art_tile(ArtTile_Level,2,0)
	dbug	Map_PRock,	Obj3B,	0,	0,	make_art_tile(ArtTile_GHZ_Purple_Rock,3,0)
	dbug	Map_obj40,	MotoBug,	0,	0,	make_art_tile(ArtTile_Moto_Bug,0,0)
	dbug	Map_obj41_GHZ,	Obj41,	0,	0,	make_art_tile(ArtTile_S1_Spring_Vertical,0,0)
	dbug	Map_Newtron,	Newtron,	0,	0,	make_art_tile(ArtTile_Newtron,0,0)
	dbug	Map_Newtron,	Newtron,	1,	0,	make_art_tile(ArtTile_Newtron,1,0)
	dbug	Map_obj44,	Obj44,	0,	0,	make_art_tile(ArtTile_GHZ_Edge_Wall,2,0)
	dbug	Map_Obj79,	Obj79,	1,	0,	make_art_tile(ArtTile_Lamppost,1,0)
	dbug	Map_GiantRing,	GiantRing,	0,	0,	make_art_tile(ArtTile_Giant_Ring,1,0)
Debug_GHZ_End:

Debug_LZ:	dc.w (Debug_LZ_End-Debug_LZ-2)/DebugEntry_size
;		mappings	object		subtype	frame	VRAM setting
	dbug	Map_Ring,	Obj12,	0,	0,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj26,	Obj26,	0,	0,	make_art_tile(ArtTile_Monitor,0,0)
	dbug	Map_Obj03,	Obj03,	0,	0,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj03,	Obj03,	9,	1,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj03,	Obj03,	$D,	5,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Mplat,	MorphingPlatform,	0,	0,	make_art_tile(ArtTile_MorphingOrbs,0,0)
	dbug	Map_Mplat,	MorphingPlatform,	0,	3,	make_art_tile(ArtTile_MorphingOrbs,0,0)
	dbug	Map_Obj36,	Obj36,	0,	0,	make_art_tile(ArtTile_Spikes,0,0)
	dbug	Map_obj41,	Obj41,	$81,	0,	make_art_tile(ArtTile_Spring_Vertical,0,0)
	dbug	Map_obj41,	Obj41,	$A0,	6,	make_art_tile(ArtTile_Spring_Vertical,0,0)
	dbug	Map_obj41,	Obj41,	$90,	3,	make_art_tile(ArtTile_Spring_Horizontal,0,0)
	dbug	Map_obj41,	Obj41,	$30,	7,	make_art_tile(ArtTile_Spring_Diagonal,0,0)
	dbug	Map_obj41,	Obj41,	$40,	$A,	make_art_tile(ArtTile_Spring_Diagonal,0,0)
Debug_LZ_End:

Debug_CPZ:	dc.w (Debug_CPZ_End-Debug_CPZ-2)/DebugEntry_size
;		mappings	object		subtype	frame	VRAM setting
	dbug	Map_Ring,	Obj12,	0,	0,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj26,	Obj26,	0,	0,	make_art_tile(ArtTile_Monitor,0,0)
	dbug	Map_Obj03,	Obj03,	0,	0,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj03,	Obj03,	9,	1,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj03,	Obj03,	$D,	5,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj0B,	Obj0B,	0,	0,	make_art_tile(ArtTile_Level,3,1)
	dbug	Map_Flap,	FlapDoor,	2,	0,	make_art_tile(ArtTile_LZ_Flapping_Door,2,0)
	dbug	Map_Obj19,	Obj19,	1,	0,	make_art_tile(ArtTile_CPZ_Platform,3,0)
	dbug	Map_Obj36,	Obj36,	0,	0,	make_art_tile(ArtTile_Spikes,0,0)
	dbug	Map_obj41,	Obj41,	$81,	0,	make_art_tile(ArtTile_Spring_Vertical,0,0)
	dbug	Map_obj41,	Obj41,	$90,	3,	make_art_tile(ArtTile_Spring_Horizontal,0,0)
	dbug	Map_obj41,	Obj41,	$A0,	6,	make_art_tile(ArtTile_Spring_Vertical,0,0)
	dbug	Map_obj41,	Obj41,	$30,	7,	make_art_tile(ArtTile_Spring_Diagonal,0,0)
	dbug	Map_obj41,	Obj41,	$40,	$A,	make_art_tile(ArtTile_Spring_Diagonal,0,0)
	dbug	Map_GiantRing,	GiantRing,	0,	0,	make_art_tile(ArtTile_Giant_Ring,1,0)
Debug_CPZ_End:

Debug_EHZ:	dc.w (Debug_EHZ_End-Debug_EHZ-2)/DebugEntry_size
;		mappings	object		subtype	frame	VRAM setting
	dbug	Map_Ring,	Obj12,	1,	0,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj26,	Obj26,	4,	5,	make_art_tile(ArtTile_Monitor,0,0)
	dbug	Map_Obj03,	Obj03,	0,	0,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj03,	Obj03,	9,	1,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj03,	Obj03,	$D,	5,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj79,	Obj79,	1,	0,	make_art_tile(ArtTile_Lamppost,0,0)
	dbug	Map_Waterfall1,	Obj49,	0,	0,	make_art_tile(ArtTile_Waterfall,1,0)
	dbug	Map_Waterfall1,	Obj49,	2,	3,	make_art_tile(ArtTile_Waterfall,1,0)
	dbug	Map_Waterfall1,	Obj49,	4,	5,	make_art_tile(ArtTile_Waterfall,1,0)
	dbug	Map_Obj18_EHZ,	Obj18,	1,	0,	make_art_tile(ArtTile_Level,2,0)
	dbug	Map_Obj18_EHZ,	Obj18,	$A,	1,	make_art_tile(ArtTile_Level,2,0)
	dbug	Map_Obj36,	Obj36,	0,	0,	make_art_tile(ArtTile_Spikes,0,0)
	dbug	Map_obj5E,	Obj5E,	0,	0,	make_art_tile(ArtTile_HTZ_Seesaw,0,0)
	dbug	Map_obj41,	Obj41,	$81,	0,	make_art_tile(ArtTile_Spring_Vertical,0,0)
	dbug	Map_obj41,	Obj41,	$90,	3,	make_art_tile(ArtTile_Spring_Horizontal,0,0)
	dbug	Map_obj41,	Obj41,	$A0,	6,	make_art_tile(ArtTile_Spring_Vertical,0,0)
	dbug	Map_obj41,	Obj41,	$30,	7,	make_art_tile(ArtTile_Spring_Diagonal,0,0)
	dbug	Map_obj41,	Obj41,	$40,	$A,	make_art_tile(ArtTile_Spring_Diagonal,0,0)
	dbug	Map_Buzzer,	Obj4B,	0,	0,	make_art_tile(ArtTile_Buzzer,0,0)
	dbug	Map_Snailbot,	Obj54,	0,	0,	make_art_tile(ArtTile_Snail,0,0)
	dbug	Map_Obj2B,	Obj2B,	3,	0,	make_art_tile(ArtTile_Chopper,0,0)
	dbug	Map_Obj2B,	Obj2B,	4,	0,	make_art_tile(ArtTile_Chopper,0,0)
	dbug	Map_GiantRing,	GiantRing,	0,	0,	make_art_tile(ArtTile_Giant_Ring,1,0)
Debug_EHZ_End:

Debug_HTZ:	dc.w (Debug_HTZ_End-Debug_HTZ-2)/DebugEntry_size
;		mappings	object		subtype	frame	VRAM setting
	dbug	Map_Ring,	Obj12,	0,	0,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj26,	Obj26,	0,	0,	make_art_tile(ArtTile_Monitor,0,0)
	dbug	Map_Obj03,	Obj03,	0,	0,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj03,	Obj03,	9,	1,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj03,	Obj03,	$D,	5,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj79,	Obj79,	1,	0,	make_art_tile(ArtTile_Lamppost,0,0)
	dbug	Map_Obj18_EHZ,	Obj18,	1,	0,	make_art_tile(ArtTile_Level,2,0)
	dbug	Map_Obj18_EHZ,	Obj18,	$A,	1,	make_art_tile(ArtTile_Level,2,0)
	dbug	Map_Obj36,	Obj36,	0,	0,	make_art_tile(ArtTile_Spikes,0,0)
	dbug	Map_obj5E,	Obj5E,	0,	0,	make_art_tile(ArtTile_HTZ_Seesaw,0,0)
	dbug	Map_obj41,	Obj41,	$81,	0,	make_art_tile(ArtTile_Spring_Vertical,0,0)
	dbug	Map_obj41,	Obj41,	$90,	3,	make_art_tile(ArtTile_Spring_Horizontal,0,0)
	dbug	Map_obj41,	Obj41,	$A0,	6,	make_art_tile(ArtTile_Spring_Vertical,0,0)
	dbug	Map_obj41,	Obj41,	$30,	7,	make_art_tile(ArtTile_Spring_Diagonal,0,0)
	dbug	Map_obj41,	Obj41,	$40,	$A,	make_art_tile(ArtTile_Spring_Diagonal,0,0)
	dbug	Map_Obj16,	Obj16,	0,	0,	make_art_tile(ArtTile_HtzZipline,2,0)
	dbug	Map_Obj16,	Obj1C,	4,	1,	make_art_tile(ArtTile_HtzZipline,2,0)
	dbug	Map_Obj16,	Obj1C,	5,	2,	make_art_tile(ArtTile_HtzZipline,2,0)
	dbug	Map_GiantRing,	GiantRing,	0,	0,	make_art_tile(ArtTile_Giant_Ring,1,0)
Debug_HTZ_End:

Debug_HPZ:	dc.w (Debug_HPZ_End-Debug_HPZ-2)/DebugEntry_size
;		mappings	object		subtype	frame	VRAM setting
	dbug	Map_Ring,	Obj12,	0,	0,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj26,	Obj26,	0,	0,	make_art_tile(ArtTile_Monitor,0,0)
	dbug	Map_Obj03,	Obj03,	0,	0,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj03,	Obj03,	9,	1,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Obj03,	Obj03,	$D,	5,	make_art_tile(ArtTile_Ring,1,0)
	dbug	Map_Waterfall2,	HPZ_Waterfall,	4,	4,	make_art_tile(ArtTile_HPZ_Waterfall,3,1)
	dbug	Map_Piranha,	Piranha,	0,	0,	make_art_tile(ArtTile_BFish,1,0)
	dbug	Map_Splats,	Splats,	0,	0,	make_art_tile(ArtTile_Splats,1,0)
	dbug	Map_Rhinobot,	Obj4D,	0,	0,	make_art_tile(ArtTile_Rhinobot,1,0)
	dbug	Map_Obj4E,	Obj4E,	0,	0,	make_art_tile(ArtTile_Gator,1,0)
	dbug	Map_Obj4C,	Obj4C,	0,	0,	make_art_tile(ArtTile_BBat,1,0)
	dbug	Map_Octus,	Octus,	0,	0,	make_art_tile(ArtTile_Octus,1,0)
	dbug	Map_Obj1A_HPZ,	Obj1A,	0,	0,	make_art_tile($34A,2,0)
	dbug	Map_HPZ_Orb,	Obj1C,	$21,	3,	make_art_tile($35A,3,1)
	dbug	Map_GiantRing,	GiantRing,	0,	0,	make_art_tile(ArtTile_Giant_Ring,1,0)
Debug_HPZ_End:

Debug_SMZ: dc.w (Debug_SMZ_End-Debug_SMZ-2)/DebugEntry_size
        dbug Map_Ring,Obj12,0,0,make_art_tile(ArtTile_Ring,1,0)
        dbug Map_Obj26,Obj26,4,0,make_art_tile(ArtTile_Monitor,0,0)
        dbug Map_obj41,Obj41,0,0,make_art_tile(ArtTile_Spring_Vertical,0,0)
        dbug Map_SMZ_Spin,SMZ_SpinPlatform,$80,0,ArtTile_SMZ_Spin
        dbug Map_SMZ_Saw,SMZ_Saws,0,0,ArtTile_SMZ_Saw|$4000
        dbug Map_SMZ_VanP,SMZ_VanishPlatform,0,0,ArtTile_SMZ_VanP|$4000
        dbug Map_MovSpring,WheelCarrier,0,0,ArtTile_Wheel
        dbug Map_MovSpring,WheelCarrier,1,0,ArtTile_Wheel
        dbug Map_MovSpring,WheelCarrier,2,0,ArtTile_Wheel
        dbug Map_MovSpring,WheelCarrier,3,0,ArtTile_Wheel
        dbug Map_MovSpring,WheelCarrier,4,0,ArtTile_Wheel
        dbug Map_MovSpring,WheelCarrier,5,0,ArtTile_Wheel
        dbug Map_MovSpring,WheelCarrier,6,0,ArtTile_Wheel
        dbug Map_MovSpring,WheelCarrier,7,0,ArtTile_Wheel
Debug_SMZ_End:

; LV0A is an editable asset/behavior library, not a port of the PP stage.
Debug_PP: dc.w (Debug_PP_End-Debug_PP-2)/DebugEntry_size
        dbug Map_PP_Anton,PP_Anton,0,0,ArtTile_PP_Anton
        dbug Map_PP_Anton,PP_Anton,1,0,ArtTile_PP_Anton
        dbug Map_PP_Mosqui1,PP_Mosqui,0,0,ArtTile_PP_Mosqui
        dbug Map_PP_Mosqui2,PP_Mosqui,1,0,ArtTile_PP_Mosqui
        dbug Map_PP_PataBata1,PP_PataBata,0,0,ArtTile_PP_PataBata
        dbug Map_PP_PataBata2,PP_PataBata,1,0,ArtTile_PP_PataBata
        dbug Map_PP_TagaTaga1,PP_TagaTaga,0,0,ArtTile_PP_TagaTaga
        dbug Map_PP_TagaTaga2,PP_TagaTaga,1,0,ArtTile_PP_TagaTaga
        dbug Map_PP_Tamabboh1,PP_Tamabboh,0,0,ArtTile_PP_Tamabboh
        dbug Map_PP_Tamabboh2,PP_Tamabboh,1,0,ArtTile_PP_Tamabboh
        dbug Map_Ring,Obj12,0,0,make_art_tile(ArtTile_Ring,1,0)
        dbug Map_Obj26,Obj26,4,0,ArtTile_Monitor
        dbug Map_obj41,Obj41,0,0,ArtTile_Spring_Vertical
        dbug Map_MovSpring,WheelCarrier,0,0,ArtTile_Wheel
        dbug Map_MovSpring,WheelCarrier,1,0,ArtTile_Wheel
        dbug Map_MovSpring,WheelCarrier,2,0,ArtTile_Wheel
        dbug Map_MovSpring,WheelCarrier,3,0,ArtTile_Wheel
        dbug Map_MovSpring,WheelCarrier,4,0,ArtTile_Wheel
        dbug Map_MovSpring,WheelCarrier,5,0,ArtTile_Wheel
        dbug Map_MovSpring,WheelCarrier,6,0,ArtTile_Wheel
        dbug Map_MovSpring,WheelCarrier,7,0,ArtTile_Wheel
Debug_PP_End:
