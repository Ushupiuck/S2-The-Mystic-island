; Cartridge-only work RAM, appended to the common upper-RAM allocation.
; The default Mode 1 build does not reserve any of these buffers.
MD_WorkRAM_Start:
Camera_RAM_copy:		ds.l	2
Camera_BG_copy:			ds.l	2
Camera_BG2_copy:			ds.l	2
Camera_BG3_copy:			ds.l	2
Scroll_flags_copy:		ds.w	1
Scroll_flags_BG_copy:		ds.w	1
Scroll_flags_BG2_copy:		ds.w	1
Scroll_flags_BG3_copy:		ds.w	1
Block_cache:			ds.w	512/16*2
Kos_decomp_buffer:		ds.b	$1000
Kos_decomp_buffer_End:
v_ngfx_buffer:			ds.b	$200
v_ngfx_buffer_end:
v_plc_ptrnemcode:		ds.l	1
v_plc_repeatcount:		ds.l	1
v_plc_paletteindex:		ds.l	1
v_plc_previousrow:		ds.l	1
v_plc_dataword:			ds.l	1
v_plc_shiftvalue:		ds.l	1
Kos_decomp_stored_Wregisters:	ds.w	6
Kos_decomp_stored_Lregisters:	ds.l	3
Kos_decomp_stored_SR:		ds.w	1
Kos_decomp_bookmark:		ds.l	1
Kos_description_field:		ds.w	1
; Three era banks, with room beyond the largest authored list (263 placements).
MD_ObjectPlacementCount = $180
Object_Respawn_Table:		ds.b	MD_ObjectPlacementCount*3
Object_Respawn_Table_end:
	if (*) & 1
			ds.b	1
	endif
Object_Respawn_Base:		ds.l	1
Object_load_addr_front:		ds.l	1
Object_load_addr_back:		ds.l	1
Object_layout_base:		ds.l	1
Object_respawn_index_front:	ds.w	1
Object_respawn_index_back:	ds.w	1
Object_Timezone:			ds.b	1
Object_TimeMask:			ds.b	1
MD_WorkRAM_End:
