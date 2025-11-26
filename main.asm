; ===========================================================================
; Sonic the Mystic Island Project -- For the Mega Drive
; ===========================================================================

FixBugs			= 1	; change to 1 to enable bugfixes
AdvancedHandler		= 0	; 0 for Sonic 1's Error handler, 1 for the Advanced Error handler
zeroOffsetOptimization	= 1	; if 1, makes a handful of zero-offset instructions smaller
TimeTravel		= 1	; if 1, allows time-travel mechanics (W.I.P)
BackupSRAM		= 1
AddressSRAM		= 3	; 0 = odd+even; 2 = even only; 3 = odd only

	CPU 68000
	include	"s2.macrosetup.asm"
	include	"s2.macros.asm"
	include	"s2.constants.asm"
	include	"sound/_smps2asm_inc.asm"
 if AdvancedHandler
	include	"Debugger.asm"
 endif

StartOfRom:
    if * <> 0
	fatal "StartOfRom was $\{*} but it should be 0"
    endif
Vectors:
		dc.l v_systemstack,	EntryPoint,	BusError,	AddressError
		dc.l IllegalInstr,	ZeroDivide,	ChkInstr,	TrapvInstr
		dc.l PrivilegeViol,	Trace,		Line1010Emu,	Line1111Emu
		dc.l ErrorExcept,	ErrorExcept,	ErrorExcept,	ErrorExcept
		dc.l ErrorExcept,	ErrorExcept,	ErrorExcept,	ErrorExcept
		dc.l ErrorExcept,	ErrorExcept,	ErrorExcept,	ErrorExcept
		dc.l ErrorExcept,	ErrorTrap,	ErrorTrap,	ErrorTrap
		dc.l H_Int,		ErrorTrap,	V_Int,		ErrorTrap
		dc.l ErrorTrap,		ErrorTrap,	ErrorTrap,	ErrorTrap
		dc.l ErrorTrap,		ErrorTrap,	ErrorTrap,	ErrorTrap
		dc.l ErrorTrap,		ErrorTrap,	ErrorTrap,	ErrorTrap
		dc.l ErrorTrap,		ErrorTrap,	ErrorTrap,	ErrorTrap
		dc.l ErrorTrap,		ErrorTrap,	ErrorTrap,	ErrorTrap
		dc.l ErrorTrap,		ErrorTrap,	ErrorTrap,	ErrorTrap
		dc.l ErrorTrap,		ErrorTrap,	ErrorTrap,	ErrorTrap
		dc.l ErrorTrap,		ErrorTrap,	ErrorTrap,	ErrorTrap
		dc.b "SEGA MEGA DRIVE "			; Console name
		dc.b "(C)SEGA 2025.OCT"			; Copyright holder and release year
		dc.b "SONIC THE HEDGEHOG: EGGMAN ATTACKS              " ; Domestic name
		dc.b "SONIC THE HEDGEHOG: EGGMAN ATTACKS              " ; International name
		dc.b "GM 00004049-01"			; Version (leftover from Sonic 1)
Checksum:	dc.w $0000				; Checksum (patched later if incorrect)
		dc.b "J               "			; I/O support
		dc.l StartOfRom				; Start address of ROM
ROMEndLoc:	dc.l EndOfRom-1				; End address of ROM
		dc.l v_start&$FFFFFF			; Start address of RAM
		dc.l (v_end-1)&$FFFFFF			; End address of RAM
		dc.b $52, $41, $A0+(BackupSRAM<<6)+(AddressSRAM<<3), $20 ; Backup RAM ID
		dc.l $00200001				; Backup RAM start address
		dc.l $002003FF				; Backup RAM end address
		dc.b "            "			; Modem support
		dc.b "                                                "	; Notes (unused, anything can be put in this space, but it has to be 48 bytes.)
		dc.b "JUE             "			; Country code (region)
EndOfHeader:
; ---------------------------------------------------------------------------

InitValues:	dc.w	$8000
		dc.w	bytesToLcnt($10000)
		dc.w	$100

		dc.l	Z80_RAM			; Z80 RAM start	location
		dc.l	Z80_Bus_Request		; Z80 bus request
		dc.l	Z80_Reset		; Z80 reset
		dc.l	vdp_data_port		; VDP data port
		dc.l	vdp_control_port	; VDP control port

VDPInitValues:		; values for VDP registers
		dc.b	4			; VDP $80 - 8-colour mode
		dc.b	$14			; VDP $81 - Megadrive mode, DMA enable
		dc.b	($C000>>10)		; VDP $82 - foreground nametable address
		dc.b	($F000>>10)		; VDP $83 - window nametable address
		dc.b	($E000>>13)		; VDP $84 - background nametable address
		dc.b	($D800>>9)		; VDP $85 - sprite table address
		dc.b	0			; VDP $86 - unused
		dc.b	0			; VDP $87 - background colour
		dc.b	0			; VDP $88 - unused
		dc.b	0			; VDP $89 - unused
		dc.b	255			; VDP $8A - HBlank register
		dc.b	0			; VDP $8B - full screen scroll
		dc.b	$81			; VDP $8C - 40 cell display
		dc.b	($DC00>>10)		; VDP $8D - hscroll table address
		dc.b	0			; VDP $8E - unused
		dc.b	1			; VDP $8F - VDP increment
		dc.b	1			; VDP $90 - 64 cell hscroll size
		dc.b	0			; VDP $91 - window h position
		dc.b	0			; VDP $92 - window v position
		dc.w	$FFFF			; VDP $93/94 - DMA length
		dc.w	0			; VDP $95/96 - DMA source
		dc.b	$80			; VDP $97 - DMA fill VRAM
VDPInitValues_End:
		dc.l	$40000080		; value	for VRAM fill

Z80StartupCodeBegin:
		; Z80 instructions (not the sound driver; that gets loaded later)
    save
    CPU Z80			; start assembling Z80 code
    phase 0			; pretend we're at address 0
	xor	a		; clear a to 0
	ld	bc,((Z80_RAM_end-Z80_RAM)-zStartupCodeEndLoc)-1	; prepare to loop this many times
	ld	de,zStartupCodeEndLoc+1	; initial destination address
	ld	hl,zStartupCodeEndLoc	; initial source address
	ld	sp,hl		; set the address the stack starts at
	ld	(hl),a		; set first byte of the stack to 0
	ldir			; loop to fill the stack (entire remaining available Z80 RAM) with 0
	pop	ix		; clear ix
	pop	iy		; clear iy
	ld	i,a		; clear i
	ld	r,a		; clear r
	pop	de		; clear de
	pop	hl		; clear hl
	pop	af		; clear af
	ex	af,af'		; swap af with af'
	exx			; swap bc/de/hl with their shadow registers too
	pop	bc		; clear bc
	pop	de		; clear de
	pop	hl		; clear hl
	pop	af		; clear af
	ld	sp,hl		; clear sp
	di			; clear iff1 (for interrupt handler)
	im	1		; interrupt handling mode = 1
	ld	(hl),0E9h	; replace the first instruction with a jump to itself
	jp	(hl)		; jump to the first instruction (to stay there forever)
zStartupCodeEndLoc:
    dephase	; stop pretending
	restore
    padding off	; unfortunately our flags got reset so we have to set them again...
Z80StartupCodeEnd:

		dc.w $8104				; VDP display mode
		dc.w $8F02				; VDP increment
		dc.l $C0000000				; value	for CRAM Write mode
		dc.l $40000010				; value	for VSRAM write	mode

PSGInitValues:
		dc.b $9F, $BF, $DF, $FF		; values for PSG channel volumes
PSGInitValues_End:
; ---------------------------------------------------------------------------

ErrorTrap:
		nop
		nop
		bra.s	ErrorTrap
; ---------------------------------------------------------------------------

EntryPoint:
		tst.l	(Z80_port_1_control).l		; test Port A Ctrl
		bne.s	PortA_OK
		tst.w	(Z80_expansion_control).l	; test Port C Ctrl

PortA_OK:
		bne.s	PortC_OK
		lea	InitValues(pc),a5
		movem.w	(a5)+,d5-d7
		movem.l	(a5)+,a0-a4
		move.b	Z80_version-Z80_Bus_Request(a1),d0		; get hardware version
		andi.b	#$F,d0
		beq.s	SkipSecurity
		move.l	#"SEGA",security_addr-Z80_Bus_Request(a1)

SkipSecurity:
		move.w	(a4),d0
		moveq	#0,d0
		movea.l	d0,a6
		move.l	a6,usp
		moveq	#VDPInitValues_End-VDPInitValues-1,d1

VDPInitLoop:
		move.b	(a5)+,d5
		move.w	d5,(a4)
		add.w	d7,d5
		dbf	d1,VDPInitLoop
		move.l	(a5)+,(a4)
		move.w	d0,(a3)
		move.w	d7,(a1)
		move.w	d7,(a2)

WaitForZ80:
		btst	d0,(a1)
		bne.s	WaitForZ80
		moveq	#Z80StartupCodeEnd-Z80StartupCodeBegin-1,d2

Z80InitLoop:
		move.b	(a5)+,(a0)+
		dbf	d2,Z80InitLoop
		move.w	d0,(a2)
		move.w	d0,(a1)
		move.w	d7,(a2)

ClearRAMLoop:
		move.l	d0,-(a6)
		dbf	d6,ClearRAMLoop
		move.l	(a5)+,(a4)
		move.l	(a5)+,(a4)
		moveq	#bytesToLcnt($80),d3

ClearCRAMLoop:
		move.l	d0,(a3)
		dbf	d3,ClearCRAMLoop
		move.l	(a5)+,(a4)
		moveq	#bytesToLcnt($50),d4

ClearVSRAMLoop:
		move.l	d0,(a3)
		dbf	d4,ClearVSRAMLoop
		moveq	#PSGInitValues_End-PSGInitValues-1,d5

PSGInitLoop:
		move.b	(a5)+,psg_input-vdp_data_port(a3)
		dbf	d5,PSGInitLoop
		move.w	d0,(a2)
		movem.l	(a6),d0-a6
		disable_ints

PortC_OK:	; Fall through to GameProgram
-		move.w	(vdp_control_port).l,d1
		btst	#1,d1
		bne.s	-	; wait till a DMA is completed
		lea	(v_start&$FFFFFF).l,a6
		moveq	#0,d7
		move.w	#bytesToLcnt(v_end-v_start),d6
-		move.l	d7,(a6)+
		dbf	d6,-
		move.b	(HW_Version).l,d0
		andi.b	#$C0,d0
		move.b	d0,(v_megadrive).w

		bsr.w	InitDMAQueue
		bsr.w	VDPSetupGame
		bsr.w	SoundDriverLoad
		bsr.w	JoypadInit
		move.w	#SegaScreen,(v_gamemode).w
	;	bra.w	MainGameLoop
	;	align	$366
MainGameLoop:
		movea.w	(v_gamemode).w,a0	; jump to apt location in ROM
		jsr	(a0)
		bra.s	MainGameLoop	; loop indefinitely
; ===========================================================================
; vertical and horizontal interrupt handlers
	;	align	$434
V_Int:
		movem.l	d0-a6,-(sp)		; save all the registers to the stack
		lea	(vdp_data_port).l,a6
		lea	vdp_control_port-vdp_data_port(a6),a5
		tst.b	(v_vbla_counter).w
		beq.s	Vint_Lag_Main
.wait		moveq	#8,d0
		and.w	vdp_control_port-vdp_control_port(a5),d0
		beq.s	.wait
		move.l	#vdpComm(0,VSRAM,WRITE),vdp_control_port-vdp_control_port(a5)
		move.l	(v_scrposy_vdp).w,vdp_data_port-vdp_data_port(a6)	; send screen y-axis pos. to VSRAM
		btst	#0,(vdp_control_port-vdp_control_port)+1(a5)
		beq.s	+					; branch if it's not a PAL system
		move.w	#$700,d0
		dbf	d0,*	; wait here doing nothing for a while...
+
		st	(v_vbla_counter).w
		st	(f_hbla_pal).w
		movea.w	(v_vbla_routine).w,a0
		jsr	(a0)

VintRet:
		addq.l	#1,(Vint_runcount).w
		movem.l	(sp)+,d0-a6
		rte
; ===========================================================================
; loc_B86: VintSub0:
Vint_Lag:
		addq.w	#4,sp			; Don't execute "VintRet" twice

Vint_Lag_Main:
		addq.w	#1,(Lag_frame_count).w
		; branch if a level or demo is running
		move.w	(v_gamemode).w,d0
		cmpi.w	#Demo,d0			; Demo play Mode?
		beq.s	VInt_0_Level			; return if not
		cmpi.w	#Level,d0			; Zone play Mode?
		bne.w	VintRet				; return if not
; ===========================================================================

VInt_0_Level:
		tst.b	(Water_flag).w
		beq.w	VintRet
		move.w	(vdp_control_port).l,d0
		btst	#6,(v_megadrive).w
		beq.s	+	; branch if it isn't a PAL system

		move.w	#14344/8-1,d0
		dbf	d0,*	; otherwise waste a bit of time here
+
		st	(f_hbla_pal).w
		stopZ80
		waitZ80
		tst.b	(f_wtr_state).w
		bne.s	VInt_0_FullyUnderwater
		writeCRAM	v_palette,0
		bra.s	VInt_0_Water_Cont

VInt_0_FullyUnderwater:
		writeCRAM	v_palette_water,0

VInt_0_Water_Cont:
		move.w	(v_hbla_hreg).w,(a5)
		move.w	#$8200+(vram_fg>>10),(vdp_control_port).l
		startZ80	; rather than always branching to "VintRet",
		addq.l	#1,(Vint_runcount).w	; we'll optimize by copying it here.
		movem.l	(sp)+,d0-a6
		rte
; ===========================================================================
; loc_CAA: VintSub2:
Vint_SEGA:
		bsr.w	Do_ControllerPal
		tst.w	(v_generictimer).w
		beq.w	Set_Kos_Bookmark
		subq.w	#1,(v_generictimer).w
		bra.w	Set_Kos_Bookmark
; ===========================================================================
; loc_CAE: VintSub14:
Vint_PCM:
		move.b	(Vint_runcount+3).w,d0
		andi.w	#$F,d0
		bne.s	+	; run the following code once every 16 frames

		stopZ80
		waitZ80
		bsr.w	ReadJoypads
		startZ80
+
		tst.w	(v_generictimer).w
		beq.w	Set_Kos_Bookmark
		subq.w	#1,(v_generictimer).w
		bra.w	Set_Kos_Bookmark
; ===========================================================================
; loc_CBC: VintSub4:
Vint_Title:
		bsr.w	Do_ControllerPal
		bsr.w	ProcessDPLC
		tst.w	(v_generictimer).w
		beq.w	Set_Kos_Bookmark
		subq.w	#1,(v_generictimer).w
		bra.w	Set_Kos_Bookmark
; ===========================================================================
; loc_CD8: VintSub10:
Vint_Pause:
		cmpi.w	#BonusStage,(v_gamemode).w
		beq.w	Vint_S1SS
		cmpi.w	#SpecialStage,(v_gamemode).w
		beq.w	Vint_S2SS	; Branch if we're in either a bonus or Special stage
; loc_CE2: VintSub8:
Vint_Level:
		stopZ80
		waitZ80
		bsr.w	ReadJoypads
		tst.b	(f_wtr_state).w
		bne.s	+
		writeCRAM	v_palette,0
		bra.s	++
+
		writeCRAM	v_palette_water,0
+
		move.w	(v_hbla_hreg).w,(a5)
		move.w	#$8200+(vram_fg>>10),(vdp_control_port).l
		writeVRAM	v_hscrolltablebuffer,vram_hscroll
		writeVRAM	Sprite_Table,vram_sprites
		bsr.w	ProcessDMAQueue
		startZ80
		movem.l	(Camera_RAM).w,d0-d7
		movem.l	d0-d7,(Camera_RAM_copy).w
		movem.l	(Scroll_flags).w,d0-d3
		movem.l	d0-d3,(Scroll_flags_copy).w
		move.l	(v_bg3scrposy_vdp).w,(Camera_X_pos_copy).w
		enable_ints
		tst.b	(Water_flag).w
		beq.s	Do_Updates
		cmpi.b	#92,(v_hbla_line).w
		bhs.s	Do_Updates
		st	(f_doupdatesinhblank).w
	;	addq.l	#4,sp
	;	bsr.w	Set_Kos_Bookmark	; rather than always branching to "VintRet",
	;	addq.l	#1,(Vint_runcount).w	; we'll optimize by copying it here.
	;	movem.l	(sp)+,d0-a6
	;	rte
		bra.w	Set_Kos_Bookmark
;+
	;	pea	(Set_Kos_Bookmark).w
; ---------------------------------------------------------------------------
; Subroutine to run a demo for an amount of time
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; Demo_Time:
Do_Updates:
		bsr.w	LoadTilesAsYouMove
	;	jsr	(LoadTilesAsYouMove).l
		jsr	(HudUpdate).l
		clr.w	(Lag_frame_count).w
		bsr.w	ProcessDPLC2
		tst.w	(v_generictimer).w
		beq.w	Set_Kos_Bookmark
		subq.w	#1,(v_generictimer).w
		bra.w	Set_Kos_Bookmark
; End of function Do_Updates

; ---------------------------------------------------------------------------
		align	$82E
Vint_Pause_specialStage:
		stopZ80
		waitZ80
		bsr.w	ReadJoypads
		tst.b	(SS_Last_Alternate_HorizScroll_Buf).w
		beq.s	+
		dma68kToVDP SS_Horiz_Scroll_Buf_2,VRAM_Horiz_Scroll_Table,VRAM_Horiz_Scroll_Table_Size,VRAM
		bra.s	++
+
		dma68kToVDP SS_Horiz_Scroll_Buf_1,VRAM_Horiz_Scroll_Table,VRAM_Horiz_Scroll_Table_Size,VRAM
+
		startZ80
		rts
; ===========================================================================
		align	$8A4
Vint_S2SS:
		stopZ80
		waitZ80
		bsr.w	ReadJoypads
		move.w	(vdp_control_port).l,d0		; These 3 lines used to be a branch to "SSSet_VScroll"
		move.l	#vdpComm($0000,VSRAM,WRITE),(vdp_control_port).l	; Now part of the routine itself
		move.l	(Vscroll_Factor).w,(vdp_data_port).l	; (As a minor optimization)
		dma68kToVDP Normal_palette,$0000,palette_line_size*4,CRAM
		dma68kToVDP Sprite_Table,VRAM_Sprite_Attribute_Table,VRAM_Sprite_Attribute_Table_Size,VRAM
		tst.b	(SS_Alternate_HorizScroll_Buf).w
		beq.s	.loc_906
		dma68kToVDP SS_Horiz_Scroll_Buf_2,VRAM_Horiz_Scroll_Table,VRAM_Horiz_Scroll_Table_Size,VRAM
		bra.s	.loc_92A
; ---------------------------------------------------------------------------

.loc_906:
		dma68kToVDP SS_Horiz_Scroll_Buf_1,VRAM_Horiz_Scroll_Table,VRAM_Horiz_Scroll_Table_Size,VRAM

.loc_92A:
		tst.b	(SSTrack_Orientation).w		; Is the current track frame flipped?
		beq.s	++				; Branch if not
		moveq	#0,d0
		move.b	(SSTrack_drawing_index).w,d0	; Get drawing position
		cmpi.b	#4,d0				; Have we finished drawing and streaming track frame?
		bge.s	++				; Branch if yes (nothing to draw)
		add.b	d0,d0				; Convert to index
		tst.b	(SS_Alternate_PNT).w		; [(SSTrack_drawing_index) * 2] = subroutine
		beq.s	+				; Branch if not using the alternate Plane A name table
		addi_.w	#8,d0				; ([(SSTrack_drawing_index) * 2] + 8) = subroutine
+
		move.w	SS_PNTA_Transfer_Table(pc,d0.w),d0
		jsr	SS_PNTA_Transfer_Table(pc,d0.w)
+
		bsr.w	SSRun_Animation_Timers
		addi_.b	#1,(SSTrack_drawing_index).w	; Run track timer
		move.b	(SSTrack_drawing_index).w,d0	; Get new timer value
		cmp.b	d1,d0				; Is it less than the player animation timer?
		blt.s	+++				; Branch if so
		clr.b	(SSTrack_drawing_index).w	; Start drawing new frame
		lea	(vdp_control_port).l,a6
		tst.b	(SS_Alternate_PNT).w		; Are we using the alternate address for plane A?
		beq.s	+				; Branch if not
		move.w	#$8200|(VRAM_SS_Plane_A_Name_Table1/$400),(a6)	; Set PNT A base to $C000
		bra.s	++
; ===========================================================================
;off_97A
SS_PNTA_Transfer_Table:	offsetTable
		offsetTableEntry.w loc_A50	; 0
		offsetTableEntry.w loc_A76	; 1
		offsetTableEntry.w loc_A9C	; 2
		offsetTableEntry.w loc_AC2	; 3
		offsetTableEntry.w loc_9B8	; 4
		offsetTableEntry.w loc_9DE	; 5
		offsetTableEntry.w loc_A04	; 6
		offsetTableEntry.w loc_A2A	; 7
; ===========================================================================
+
		move.w	#$8200|(VRAM_SS_Plane_A_Name_Table2/$400),(a6)	; Set PNT A base to $8000
+
		eori.b	#1,(SS_Alternate_PNT).w		; Toggle flag
+
		bsr.w	ProcessDMAQueue
		startZ80
		bsr.w	ProcessDPLC2
		tst.w	(v_generictimer).w
		beq.w	Set_Kos_Bookmark
		subq.w	#1,(v_generictimer).w
		bra.w	Set_Kos_Bookmark
; ---------------------------------------------------------------------------
; (!)
; Each of these functions copies one fourth of pattern name table A into VRAM
; from a buffer in main RAM. $700 bytes are copied each frame, with the target
; area in VRAM depending on the current drawing position.
loc_9B8:
		dma68kToVDP PNT_Buffer,VRAM_SS_Plane_A_Name_Table1 + 0 * (PNT_Buffer_End-PNT_Buffer),PNT_Buffer_End-PNT_Buffer,VRAM
		rts
; ---------------------------------------------------------------------------
loc_9DE:
		dma68kToVDP PNT_Buffer,VRAM_SS_Plane_A_Name_Table1 + 1 * (PNT_Buffer_End-PNT_Buffer),PNT_Buffer_End-PNT_Buffer,VRAM
		rts
; ---------------------------------------------------------------------------
loc_A04:
		dma68kToVDP PNT_Buffer,VRAM_SS_Plane_A_Name_Table1 + 2 * (PNT_Buffer_End-PNT_Buffer),PNT_Buffer_End-PNT_Buffer,VRAM
		rts
; ---------------------------------------------------------------------------
loc_A2A:
		dma68kToVDP PNT_Buffer,VRAM_SS_Plane_A_Name_Table1 + 3 * (PNT_Buffer_End-PNT_Buffer),PNT_Buffer_End-PNT_Buffer,VRAM
		rts
; ---------------------------------------------------------------------------
loc_A50:
		dma68kToVDP PNT_Buffer,VRAM_SS_Plane_A_Name_Table2 + 0 * (PNT_Buffer_End-PNT_Buffer),PNT_Buffer_End-PNT_Buffer,VRAM
		rts
; ---------------------------------------------------------------------------
loc_A76:
		dma68kToVDP PNT_Buffer,VRAM_SS_Plane_A_Name_Table2 + 1 * (PNT_Buffer_End-PNT_Buffer),PNT_Buffer_End-PNT_Buffer,VRAM
		rts
; ---------------------------------------------------------------------------
loc_A9C:
		dma68kToVDP PNT_Buffer,VRAM_SS_Plane_A_Name_Table2 + 2 * (PNT_Buffer_End-PNT_Buffer),PNT_Buffer_End-PNT_Buffer,VRAM
		rts
; ---------------------------------------------------------------------------
loc_AC2:
		dma68kToVDP PNT_Buffer,VRAM_SS_Plane_A_Name_Table2 + 3 * (PNT_Buffer_End-PNT_Buffer),PNT_Buffer_End-PNT_Buffer,VRAM
		rts
; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

;sub_B02
SSRun_Animation_Timers:
		move.w	(SS_Cur_Speed_Factor).w,d0		; Get current speed factor
		cmp.w	(SS_New_Speed_Factor).w,d0		; Has the speed factor changed?
		beq.s	+					; Branch if yes
		move.l	(SS_New_Speed_Factor).w,(SS_Cur_Speed_Factor).w	; Save new speed factor
		clr.b	(SSTrack_duration_timer).w		; Reset timer
+
		subi_.b	#1,(SSTrack_duration_timer).w		; Run track timer
		bgt.s	+					; Branch if not expired yet
		lea	(SSAnim_Base_Duration).l,a0
		move.w	(SS_Cur_Speed_Factor).w,d0		; The current speed factor is an index
		lsr.w	#1,d0
		move.b	(a0,d0.w),d1
		move.b	d1,(SS_player_anim_frame_timer).w	; New player animation length (later halved)
		move.b	d1,(SSTrack_duration_timer).w		; New track timer
		subq.b	#1,(SS_player_anim_frame_timer).w	; Subtract one
		rts
; ---------------------------------------------------------------------------
+
		move.b	(SS_player_anim_frame_timer).w,d1	; Get current player animation length
		addq.b	#1,d1					; Increase it
		rts
; End of function SSRun_Animation_Timers

; ===========================================================================
;byte_B46
SSAnim_Base_Duration:
		dc.b 60
		dc.b 30	; 1
		dc.b 15	; 2
		dc.b 10	; 3
		dc.b  8	; 4
		dc.b  6	; 5
		dc.b  5	; 6
		dc.b  0	; 7
		even
; ===========================================================================
;VintSub1A
Vint_CtrlDMA:
		stopZ80
		waitZ80
		bsr.w	ProcessDMAQueue
		startZ80
		rts
; ===========================================================================
; loc_E02: VintSubA:
Vint_S1SS:
		stopZ80
		waitZ80
		bsr.w	ReadJoypads
		writeCRAM	v_palette,0
		writeVRAM	Sprite_Table,vram_sprites
		writeVRAM	v_hscrolltablebuffer,vram_hscroll
		bsr.w	ProcessDMAQueue
		startZ80
		bsr.w	PalCycle_S1SS
		tst.w	(v_generictimer).w
		beq.w	Set_Kos_Bookmark
		subq.w	#1,(v_generictimer).w
		bra.w	Set_Kos_Bookmark
; ===========================================================================
; loc_EA2: VintSubC: VintSub18:
Vint_TitleCard:
		stopZ80
		waitZ80
		bsr.w	ReadJoypads
		tst.b	(f_wtr_state).w
		bne.s	+
		writeCRAM	v_palette,0
		bra.s	++

+
		writeCRAM	v_palette_water,0
+
		move.w	(v_hbla_hreg).w,(a5)
		writeVRAM	v_hscrolltablebuffer,vram_hscroll
		writeVRAM	Sprite_Table,vram_sprites
		bsr.w	ProcessDMAQueue
		startZ80
		movem.l	(Camera_RAM).w,d0-d7
		movem.l	d0-d7,(Camera_RAM_copy).w
		movem.l	(Scroll_flags).w,d0-d1
		movem.l	d0-d1,(Scroll_flags_copy).w
		bsr.w	LoadTilesAsYouMove
		jsr	(HudUpdate).l
		bsr.w	ProcessDPLC
		bra.w	Set_Kos_Bookmark
; ===========================================================================
; loc_F98: VintSub12:
Vint_Fade:
		bsr.w	Do_ControllerPal
		move.w	(v_hbla_hreg).w,(a5)
		bra.w	ProcessDPLC
; ===========================================================================
; loc_FA4: VintSub16:
Vint_SSResults:
		stopZ80
		waitZ80
		bsr.w	ReadJoypads
		writeCRAM	v_palette,0
		writeVRAM	Sprite_Table,vram_sprites
		writeVRAM	v_hscrolltablebuffer,vram_hscroll
		bsr.w	ProcessDMAQueue
		startZ80
		bsr.w	ProcessDPLC
		tst.w	(v_generictimer).w
		beq.w	Set_Kos_Bookmark
		subq.w	#1,(v_generictimer).w
		bra.w	Set_Kos_Bookmark

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; sub_103C:
Do_ControllerPal:
		stopZ80
		waitZ80
		bsr.w	ReadJoypads
		tst.b	(f_wtr_state).w ; is water above top of screen?
		bne.s	.waterabove	; if yes, branch
		writeCRAM	v_palette,0
		bra.s	.waterbelow

.waterabove:
		writeCRAM	v_palette_water,0

.waterbelow:
		writeVRAM	Sprite_Table,vram_sprites
		writeVRAM	v_hscrolltablebuffer,vram_hscroll
		bsr.w	Process_DMA_Queue
		startZ80
		rts
; End of function Do_ControllerPal

; ||||||||||||||| E N D   O F   V - I N T |||||||||||||||||||||||||||||||||||

; ===========================================================================
; Start of H-INT code
H_Int:
		tst.b	(f_hbla_pal).w
		beq.w	H_Int_done
		disable_ints
		sf	(f_hbla_pal).w
		movem.l	a0-a1,-(sp)
		lea	(vdp_data_port).l,a1
		move.w	#$8A00+224-1,4(a1)		; write %1101 %1111 to register 10 (interrupt every 224th line)
		lea	(v_palette_water).w,a0		; load palette from RAM
		move.l	#$C0000000,4(a1)		; set VDP to write to CRAM address $00
	rept (palette_size)/4
		move.l	(a0)+,(a1)			; move palette to CRAM (all 64 colors at once)
	endm
		movem.l	(sp)+,a0-a1
		tst.b	(f_doupdatesinhblank).w
		beq.s	H_Int_done
		sf	(f_doupdatesinhblank).w
		movem.l	d0-a6,-(sp)
		bsr.w	Do_Updates
		movem.l	(sp)+,d0-a6

H_Int_done:
		rte

; ===========================================================================
; game code
; ---------------------------------------------------------------------------
; Subroutine to initialize joypads
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


JoypadInit:
		stopZ80
		waitZ80
		moveq	#$40,d0
		move.b	d0,(HW_Port_1_Control).l
		move.b	d0,(HW_Port_2_Control).l
		move.b	d0,(HW_Expansion_Control).l
		startZ80
		rts
; End of function JoypadInit

; ---------------------------------------------------------------------------
; Subroutine to read joypad input, and send it to the RAM
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


ReadJoypads:
		lea	(v_jpadhold1).w,a0		; address where joypad states are written
		lea	(HW_Port_1_Data).l,a1		; first joypad port
		bsr.s	Joypad_Read			; do the first joypad
		addq.w	#2,a1				; do the second joypad

Joypad_Read:
		sf	(a1)
		nop
		nop
		move.b	(a1),d0
		lsl.b	#2,d0
		andi.b	#$C0,d0
		move.b	#$40,(a1)
		nop
		nop
		move.b	(a1),d1
		andi.b	#$3F,d1
		or.b	d1,d0
		not.b	d0
		move.b	(a0),d1
		eor.b	d0,d1
		move.b	d0,(a0)+
		and.b	d0,d1
		move.b	d1,(a0)+
		rts
; End of function ReadJoypads


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


VDPSetupGame:
		lea	(vdp_control_port).l,a0
		lea	(vdp_data_port).l,a1
		lea	(VDPSetupArray).l,a2
		moveq	#bytesToWcnt(VDPSetupArray_End-VDPSetupArray),d7

VDP_Loop:
		move.w	(a2)+,(a0)
		dbf	d7,VDP_Loop
		move.w	(VDPSetupArray+2).l,d0
		move.w	d0,(v_vdp_buffer1).w
		move.w	#$8A00+224-1,(v_hbla_hreg).w
		moveq	#0,d0
		move.l	#$40000010,(vdp_control_port).l	; write to VRAM port
		move.w	d0,(a1)
		move.w	d0,(a1)
		move.l	#$C0000000,(vdp_control_port).l	; write to CRAM port
		move.w	#bytesToWcnt(palette_size),d7	; get palette size

VDP_ClrCRAM:
		move.w	d0,(a1)
		dbf	d7,VDP_ClrCRAM
		clr.l	(v_scrposy_vdp).w
		clr.l	(v_scrposx_vdp).w
		move.l	d1,-(sp)
		fillVRAM	0,0,$10000	; clear the entirety of VRAM
		move.l	(sp)+,d1
		rts
; End of function VDPSetupGame

; ===========================================================================
VDPSetupArray:
		dc.w $8004				; H-INT disabled
		dc.w $8134			; Mega Drive display, DMA enabled, V-INT enabled
		dc.w $8200+(vram_fg>>10)	; PNT A base: $C000
		dc.w $8300+(vram_window>>10)	; PNT W base: $A000
		dc.w $8400+(vram_bg>>13)	; PNT B base: $E000
		dc.w $8500+(vram_sprites>>9)	; Sprite attribute table base: $F800
		dc.w $8600
		dc.w $8700			; Background palette/color: 0/0
		dc.w $8800
		dc.w $8900
		dc.w $8A00			; H-INT every scanline
		dc.w $8B00			; EXT-INT off, V scroll by screen, H scroll by screen
		dc.w $8C81			; H res 40 cells, no interlace, S/H disabled
		dc.w $8D00+(vram_hscroll>>10)
		dc.w $8E00
		dc.w $8F02			; VRAM pointer increment: $0002
		dc.w $9001			; Scroll table size: 64x32
		dc.w $9100			; Disable window
		dc.w $9200			; Disable window
VDPSetupArray_End:

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


ClearScreen:
		fillVRAM 0, vram_fg, vram_fg+plane_size_64x32 ; clear foreground namespace
		fillVRAM 0, vram_bg, vram_bg+plane_size_64x32 ; clear background namespace
		clr.l	(v_scrposy_vdp).w
		clr.l	(v_scrposx_vdp).w
		clearRAM Sprite_Table,Sprite_Table_end
		clearRAM v_hscrolltablebuffer,v_hscrolltablebuffer_end_padded
		rts
; End of function ClearScreen

; ---------------------------------------------------------------------------
; Subroutine to transfer a plane map to VRAM
; ---------------------------------------------------------------------------

; control register:
;    CD1 CD0 A13 A12 A11 A10 A09 A08     (D31-D24)
;    A07 A06 A05 A04 A03 A02 A01 A00     (D23-D16)
;     ?   ?   ?   ?   ?   ?   ?   ?      (D15-D8)
;    CD5 CD4 CD3 CD2  ?   ?  A15 A14     (D7-D0)
;
;	A00-A15 - address
;	CD0-CD3 - code
;	CD4 - 1 if VRAM copy DMA mode. 0 otherwise.
;	CD5 - DMA operation
;
;	Bits CD3-CD0:
;	0000 - VRAM read
;	0001 - VRAM write
;	0011 - CRAM write
;	0100 - VSRAM read
;	0101 - VSRAM write
;	1000 - CRAM read
;
; d0 = control register
; d1 = width
; d2 = heigth
; a1 = source address

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; ShowVDPGraphics: PlaneMapToVRAM:
PlaneMapToVRAM_H40:
		lea	(vdp_data_port).l,a6
		move.l	#vdpCommDelta(planeLoc(64,0,1)),d4	; $800000
-		move.l	d0,vdp_control_port-vdp_data_port(a6)	; move d0 to VDP_control_port
		move.w	d1,d3
-		move.w	(a1)+,(a6)	; from source address to destination in VDP
		dbf	d3,-		; next tile
		add.l	d4,d0		; increase destination address by $80 (1 line)
		dbf	d2,--		; next line
		rts
; End of function PlaneMapToVRAM_H40

; ---------------------------------------------------------------------------
; Alternate subroutine to transfer a plane map to VRAM
; (used for Special Stage background)
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; sub_142E: ShowVDPGraphics2: PlaneMapToVRAM2:
PlaneMapToVRAM_H80_SpecialStage:
		lea	(vdp_data_port).l,a6
		move.l	#vdpCommDelta(planeLoc(128,0,1)),d4	; $1000000
-		move.l	d0,vdp_control_port-vdp_data_port(a6)	; move d0 to VDP_control_port
		move.w	d1,d3
-		move.w	(a1)+,(a6)	; from source address to destination in VDP
		dbf	d3,-		; next tile
		add.l	d4,d0		; increase destination address by $80 (1 line)
		dbf	d2,--		; next line
		rts
; End of function PlaneMapToVRAM_H80_SpecialStage

; ---------------------------------------------------------------------------
; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||
; ---------------------------------------------------------------------------
; Subroutine to load the sound driver
; ---------------------------------------------------------------------------

SoundDriverLoad:
		move.w	#$100,(Z80_Bus_Request).l	; stop the Z80
		resetZ80

		lea	(Snd_Driver).l,a0
		lea	(Z80_RAM).l,a1
		bsr.w	KosPlusDec
		btst	#0,(VDP_control_port+1).l	; check video mode
		sne	(Z80_RAM+zPalModeByte).l	; set if PAL

		resetZ80a
		nop
		nop
		nop
		nop
		resetZ80
		startZ80	; start the Z80
		rts
; End of function SoundDriverLoad
; ---------------------------------------------------------------------------
; MM: these functions now write directly to Z80 RAM
; If Music_to_play is clear, move d0 into Music_to_play,
; else move d0 into Music_to_play_2.

PlaySound_Special:
PlayMusic:
		disable_ints
		stopZ80
		waitZ80
		tst.b	(Z80_RAM+zAbsVar.QueueToPlay).l
		bne.s	+
		move.b	d0,(Z80_RAM+zAbsVar.QueueToPlay).l
		startZ80
		enable_ints
		rts
+
		move.b	d0,(Z80_RAM+zAbsVar.SFXToPlay).l
		startZ80
		enable_ints
		rts
; End of function PlayMusic
; ---------------------------------------------------------------------------
; play a sound in alternating speakers (as in the ring collection sound)

PlaySoundStereo:
		disable_ints
		stopZ80
		waitZ80
		move.b	d0,(Z80_RAM+zAbsVar.SFXStereoToPlay).l
		startZ80
		enable_ints
		rts
; End of function PlaySoundStereo
; ---------------------------------------------------------------------------
; play a sound if the source is onscreen

PlaySoundLocal:
		tst.b	obRender(a0)
		bpl.s	+	; rts

PlaySound:
		disable_ints
		stopZ80
		waitZ80
		move.b	d0,(Z80_RAM+zAbsVar.SFXUnknown).l
		startZ80
		enable_ints
+
		rts
; End of function PlaySoundLocal

; ===========================================================================
; MM: this routine and the table below control what PCM sample plays on the Sega screen
ChangeSegaSound:
		stopZ80
		waitZ80
		move.b	d0,(Z80_RAM+zPCMSound).l
		startZ80
		rts

SegaSndTblEntry	macro	offset,length,pitch
		dc.b	pitch,(offset>>15)&$FF
		dc.w	zROMWindow|(offset&$7FFF),length
		endm

SegaSndTbl:
	SegaSndTblEntry	Snd_Sega,Snd_Sega_End-Snd_Sega,$A


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||
; MM: use these routines to pause/unpause sound
PauseSoundDriver:
		disable_ints
		stopZ80
		waitZ80
		move.b	#$7F,(Z80_RAM+zAbsVar.StopMusic).l
		startZ80
		enable_ints
		rts

UnpauseSoundDriver:
		disable_ints
		stopZ80
		waitZ80
		move.b	#$80,(Z80_RAM+zAbsVar.StopMusic).l
		startZ80
		enable_ints
		rts
; ---------------------------------------------------------------------------

		include	"_inc/PauseGame.asm"

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||
; ---------------------------------------------------------------------------
; Subroutine to load pattern load cues (aka to queue pattern load requests)
; ---------------------------------------------------------------------------

; ARGUMENTS
; d0 = index of PLC list (see ArtLoadCues)

; NOTICE: This subroutine does not check for buffer overruns. The programmer
;	  (or hacker) is responsible for making sure that no more than
;	  16 load requests are copied into the buffer.
;    _________DO NOT PUT MORE THAN 16 LOAD REQUESTS IN A LIST!__________
;         (or if you change the size of v_plc_buffer, the limit becomes (v_plc_buffer_Only_End-v_plc_buffer)/6)

; PLCLoad:
LoadPLC:
		movem.l	a1-a2,-(sp)		; Save registers
		lea	(ArtLoadCues).l,a1	; Prepare PLC list index
		add.w	d0,d0			; Get pointer to PLC list
		move.w	(a1,d0.w),d0
		lea	(a1,d0.w),a1
		lea	(v_plc_buffer).w,a2	; Prepare PLC buffer

.Loop:
		tst.l	(a2)			; Is this PLC entry free?
		beq.s	.FoundFree		; If so, branch
		addq.w	#6,a2			; Check next entry
		bra.s	.Loop

.FoundFree:
		move.w	(a1)+,d0		; Get number of PLC entries
		bmi.s	.End			; If it's 0 (or less), branch

.Load:
		move.l	(a1)+,(a2)+		; Copy art pointer
		move.w	(a1)+,(a2)+		; Copy VRAM location
		dbf	d0,.Load		; Loop until all entries are queued
		moveq	#0,d0
		move.l	d0,(a2)+		; clear the last cue to avoid overcopying it
		move.w	d0,(a2)+
.End:
		movem.l	(sp)+,a1-a2		; Restore registers
		rts
; End of function LoadPLC


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||
; Queue pattern load requests, but clear the PLQ first

; ARGUMENTS
; d0 = index of PLC list (see ArtLoadCues)

; NOTICE: This subroutine does not check for buffer overruns. The programmer
;	  (or hacker) is responsible for making sure that no more than
;	  16 load requests are copied into the buffer.
;	  _________DO NOT PUT MORE THAN 16 LOAD REQUESTS IN A LIST!__________
;         (or if you change the size of v_plc_buffer, the limit becomes (v_plc_buffer_Only_End-v_plc_buffer)/6)

NewPLC:
		movem.l	a1-a2,-(sp)		; Save registers
		lea	(ArtLoadCues).l,a1	; Prepare PLC list index
		add.w	d0,d0
		move.w	(a1,d0.w),d0
		lea	(a1,d0.w),a1
		bsr.s	ClearPLC		; Clear PLCs
		lea	(v_plc_buffer).w,a2	; Prepare PLC buffer
		move.w	(a1)+,d0		; Get number of PLC entries
		bmi.s	.End			; If it's 0 (or less), branch

.Load:
		move.l	(a1)+,(a2)+		; Copy art pointer
		move.w	(a1)+,(a2)+		; Copy VRAM location
		dbf	d0,.Load		; Loop until all entries are queued
		moveq	#0,d0
		move.l	d0,(a2)+		; clear the last cue to avoid overcopying it
		move.w	d0,(a2)+

.End:
		movem.l	(sp)+,a1-a2		; Restore registers
		rts
; End of function NewPLC


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; Clear the pattern load queue ($FFF680 - $FFF700)

ClearPLC:
		lea	(v_plc_buffer).w,a2
		moveq	#bytesToLcnt(v_plc_buffer_end-v_plc_buffer),d0

.Clear:
		clr.l	(a2)+
		dbf	d0,.Clear
		rts
; End of function ClearPLC


; ---------------------------------------------------------------------------
; Subroutine to use graphics listed in a pattern load cue
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; RunPLC:
RunPLC_RAM:
		tst.l	(v_plc_buffer).w
		beq.s	locret_1730
		tst.w	(v_plc_patternsleft).w
		bne.s	locret_1730
		movea.l	(v_plc_buffer).w,a0
		lea	NemPCD_WriteRowToVDP(pc),a3
		nop
		lea	(v_ngfx_buffer).w,a1
		move.w	(a0)+,d2
		bpl.s	loc_16FE
		adda.w	#NemPCD_WriteRowToVDP_XOR-NemPCD_WriteRowToVDP,a3

loc_16FE:
		andi.w	#$7FFF,d2
		bsr.w	NemDec_BuildCodeTable
		move.b	(a0)+,d5
		asl.w	#8,d5
		move.b	(a0)+,d5
		moveq	#$10,d6
		moveq	#0,d0
		move.l	a0,(v_plc_buffer).w
		move.l	a3,(v_plc_ptrnemcode).w
		move.l	d0,(v_plc_repeatcount).w
		move.l	d0,(v_plc_paletteindex).w
		move.l	d0,(v_plc_previousrow).w
		move.l	d5,(v_plc_dataword).w
		move.l	d6,(v_plc_shiftvalue).w
		move.w	d2,(v_plc_patternsleft).w

locret_1730:
		rts
; End of function RunPLC_RAM


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||
; Process one PLC from the queue

; sub_1732:
ProcessDPLC:
		tst.w	(v_plc_patternsleft).w		; Is there anything to decompress?
		beq.w	ProcessDPLC_Done		; If not, branch

ProcessDPLC_Large:
		move.w	#9,(v_plc_framepatternsleft).w
		moveq	#0,d0				; Get VRAM address
		move.w	(v_plc_buffer+4).w,d0
		addi.w	#9*$20,(v_plc_buffer+4).w	; Advance VRAM address
		bra.s	ProcessDPLC_Main

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||
; Process one PLC from the queue

; loc_174E:
ProcessDPLC2:
		tst.w	(v_plc_patternsleft).w		; Is there anything to decompress?
		beq.s	ProcessDPLC_Done		; If not, branch
		tst.b	(f_lockscreen).w		; Is the screen locked?
		bne.s	ProcessDPLC_Large		; If so, go with the large batch instead
		move.w	#3,(v_plc_framepatternsleft).w
		moveq	#0,d0				; Get VRAM address
		move.w	(v_plc_buffer+4).w,d0
		addi.w	#3*$20,(v_plc_buffer+4).w	; Advance VRAM address
; loc_1766:
ProcessDPLC_Main:
		lea	(vdp_control_port).l,a4		; Set VDP write command
		lsl.l	#2,d0
		lsr.w	#2,d0
		ori.w	#$4000,d0
		swap	d0
		move.l	d0,(a4)
		subq.w	#4,a4				; Prepare data port
		movea.l	(v_plc_buffer).w,a0		; Get decompression registers
		movea.l	(v_plc_ptrnemcode).w,a3
		move.l	(v_plc_repeatcount).w,d0
		move.l	(v_plc_paletteindex).w,d1
		move.l	(v_plc_previousrow).w,d2
		move.l	(v_plc_dataword).w,d5
		move.l	(v_plc_shiftvalue).w,d6
		lea	(v_ngfx_buffer).w,a1

.Decomp:
		movea.w	#8,a5				; Store decompressed tile in VRAM
		bsr.w	NemPCD_NewRow
		subq.w	#1,(v_plc_patternsleft).w	; Decrement total tile count
		beq.s	ProcessDPLC_Pop			; If this art is finished being decompressed, branch
		subq.w	#1,(v_plc_framepatternsleft).w	; Decrement number of tiles left to decompress in this batch
		bne.s	.Decomp				; If we are not done, branch
		move.l	a0,(v_plc_buffer).w
		move.l	a3,(v_plc_ptrnemcode).w
		move.l	d0,(v_plc_repeatcount).w
		move.l	d1,(v_plc_paletteindex).w
		move.l	d2,(v_plc_previousrow).w
		move.l	d5,(v_plc_dataword).w
		move.l	d6,(v_plc_shiftvalue).w

ProcessDPLC_Done:
		rts
; ===========================================================================
; pop one request off the buffer so that the next one can be filled
; loc_17CC:
ProcessDPLC_Pop:
		lea	(v_plc_buffer).w,a0
		moveq	#bytesToLcnt(v_plc_buffer_only_end-v_plc_buffer-6),d0

loc_17D2:
		move.l	6(a0),(a0)+
		dbf	d0,loc_17D2
	if (v_plc_buffer_only_end-v_plc_buffer-6)&2
		move.w	6(a0),(a0)
	endif
		clr.l	(v_plc_buffer_only_end-6).w
		rts
; End of function ProcessDPLC


; ---------------------------------------------------------------------------
; Subroutine to execute a pattern load cue directly from the ROM
; rather than loading them into the queue first
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


QuickPLC:
		move.w	(a1)+,d1

.Load:
		movea.l	(a1)+,a0
		moveq	#0,d0
		move.w	(a1)+,d0
		lsl.l	#2,d0
		lsr.w	#2,d0
		ori.w	#$4000,d0
		swap	d0
		move.l	d0,(vdp_control_port).l
		bsr.s	NemDec
		dbf	d1,.Load
		rts
; End of function QuickPLC

; ===========================================================================
		include "_inc/Nemesis Decompression.asm"
; ===========================================================================
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


KosPlusArt_To_VDP:
		movea.l	a1,a3		; a1 will be changed by KosPlusDec, so we're backing it up to a3
		bsr.s	KosPlusDec
		move.l	a3,d1		; move the backed-up a1 to d1
		andi.l	#$FFFFFF,d1	; d1 will be used in the DMA transfer as the Source Address
		move.l	a1,d3		; move end address of decompressed art to d3
		sub.l	a3,d3		; subtract 'start address of decompressed art' from 'end address of decompressed art', giving you the size of the decompressed art
		lsr.l	#1,d3		; divide size of decompressed art by two, d3 will be used in the DMA transfer as the Transfer Length (size/2)
		move.w	a2,d2		; move VRAM address to d2, d2 will be used in the DMA transfer as the Destination Address
		movea.l	a1,a3		; backup a1, this allows the same address to be used by multiple calls to KosPlusArt_To_VDP without constant redefining
		bsr.w	QueueDMATransfer	; transfer *Transfer Length* of data from *Source Address* to *Destination Address*
		movea.l	a3,a1		; restore a1
		rts

; ===========================================================================
		include "_inc/KosinskiPlus.asm"
		include "_inc/DMA Queue.asm"
; ===========================================================================

; ---------------------------------------------------------------------------
; Subroutine to queue Moduled Kosinski PLC's per level
; ---------------------------------------------------------------------------

LoadKosPLC:
	;	movem.l	a1-a6,-(sp)	; Save registers -- Optional
		lea	(KosMLoadCues).l,a6
		; level specific checks go here.
		; Sonic & knuckles default are provided as an example.
	;	move.w	#$D00,d0	; Angel island intro skip
	;	cmpi.b	#$16,(Current_zone).w
	;	beq.s	loc_2F798
	;	move.w	#$E00,d0	; Multiplayer start
	;	cmpi.w	#$1700,(Current_zone_and_act).w
	;	bne.s	loc_2F79E

; loc_2F79E:
		moveq	#0,d0
		move.w	(Current_ZoneAndAct).w,d0

; loc_2F7A2:
		ror.b	#2,d0
		lsr.w	#5,d0
		adda.w	(a6,d0.w),a6

; ---------------------------------------------------------------------------
; This is the part that processes the current table entry
; can be called manually by loading the entry directly into a6
; input:	lea	(PLCKosM_[ENTRY_NAME]).l,a6
; ---------------------------------------------------------------------------

QuickKosPLC:
		move.w	(a6)+,d6
		bmi.s	.exit		; if there's nothing, we bail!

-		movea.l	(a6)+,a1
		move.w	(a6)+,d2
		bsr.s	Queue_Kos_Module	; Process 4 entries
		dbf	d6,-	; loop until we're finished

.exit:
	;	movem.l	(sp)+,a1-a6	; Restore registers -- Optional
		rts
; End of function LoadKosPLC
; ---------------------------------------------------------------------------

; ===========================================================================
		include "_inc/KosinkiPlus_Moduled.asm"
		include "_inc/Enigma Decompression.asm"
; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to fade in from black
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; Pal_FadeTo:
Pal_FadeFromBlack:
		move.w	#$3F,(v_pfade_start).w
; Pal_FadeTo2:
Pal_FadeFromBlack2:
		moveq	#0,d0
		lea	(v_palette).w,a0
		move.b	(v_pfade_start).w,d0
		adda.w	d0,a0
		moveq	#cBlack,d1
		move.b	(v_pfade_size).w,d0

loc_2162:
		move.w	d1,(a0)+
		dbf	d0,loc_2162			; fill palette with $000 (black)
		moveq	#$16-1,d4

.loop:
		move.w	#Vint_Fade,(v_vbla_routine).w
		bsr.w	WaitForVint
		bsr.s	Pal_FadeIn
		bsr.w	RunPLC_RAM
		dbf	d4,.loop
		rts
; End of function Pal_FadeFromBlack

; ---------------------------------------------------------------------------
; Subroutine to update all colours once
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Pal_FadeIn:
		moveq	#0,d0
		lea	(v_palette).w,a0
		lea	(v_palette_fading).w,a1
		move.b	(v_pfade_start).w,d0
		adda.w	d0,a0
		adda.w	d0,a1
		move.b	(v_pfade_size).w,d0

.loop:
		bsr.s	Pal_AddColor
		dbf	d0,.loop
		tst.b	(Water_flag).w
		beq.s	.return
		moveq	#0,d0
		lea	(v_palette_water).w,a0
		lea	(v_palette_water_fading).w,a1
		move.b	(v_pfade_start).w,d0
		adda.w	d0,a0
		adda.w	d0,a1
		move.b	(v_pfade_size).w,d0

.loop2:
		bsr.s	Pal_AddColor
		dbf	d0,.loop2

.return:
		rts
; End of function Pal_FadeIn

; ---------------------------------------------------------------------------
; Subroutine to update a single colour once
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Pal_AddColor:
		move.w	(a1)+,d2
		move.w	(a0),d3
		cmp.w	d2,d3
		beq.s	Pal_AddNone
		move.w	d3,d1
		addi.w	#$200,d1
		cmp.w	d2,d1
		bhi.s	Pal_AddGreen
		move.w	d1,(a0)+
		rts
; ---------------------------------------------------------------------------

Pal_AddGreen:
		move.w	d3,d1
		addi.w	#$20,d1
		cmp.w	d2,d1
		bhi.s	Pal_AddRed
		move.w	d1,(a0)+
		rts
; ---------------------------------------------------------------------------

Pal_AddRed:
		addq.w	#2,(a0)+
		rts
; ---------------------------------------------------------------------------
; Pal_NoAdd:
Pal_AddNone:
		addq.w	#2,a0
		rts
; End of function Pal_AddColor


; ---------------------------------------------------------------------------
; Subroutine to fade out to black
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; Pal_FadeFrom:
Pal_FadeToBlack:
		move.w	#$3F,(v_pfade_start).w
		moveq	#$16-1,d4

loc_21F8:
		move.w	#Vint_Fade,(v_vbla_routine).w
		bsr.w	WaitForVint
		bsr.s	Pal_FadeOut
		bsr.w	RunPLC_RAM
		dbf	d4,loc_21F8
		rts
; End of function Pal_FadeFrom

; ---------------------------------------------------------------------------
; Subroutine to update all colours once
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Pal_FadeOut:
		moveq	#0,d0
		lea	(v_palette).w,a0
		move.b	(v_pfade_start).w,d0
		adda.w	d0,a0
		move.b	(v_pfade_size).w,d0

loc_221E:
		bsr.s	Pal_DecColor
		dbf	d0,loc_221E
		moveq	#0,d0
		lea	(v_palette_water).w,a0
		move.b	(v_pfade_start).w,d0
		adda.w	d0,a0
		move.b	(v_pfade_size).w,d0

loc_2234:
		bsr.s	Pal_DecColor
		dbf	d0,loc_2234
		rts
; End of function Pal_FadeOut


; ---------------------------------------------------------------------------
; Subroutine to update a single colour once
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Pal_DecColor:
		move.w	(a0),d2
		beq.s	Pal_NoDec
		move.w	d2,d1
		andi.w	#$E,d1
		beq.s	Pal_DecGreen
		subq.w	#2,(a0)+
		rts
; ---------------------------------------------------------------------------

Pal_DecGreen:
		move.w	d2,d1
		andi.w	#$E0,d1
		beq.s	Pal_DecBlue
		subi.w	#$20,(a0)+
		rts
; ---------------------------------------------------------------------------

Pal_DecBlue:
		move.w	d2,d1
		andi.w	#$E00,d1
		beq.s	Pal_NoDec
		subi.w	#$200,(a0)+
		rts
; ---------------------------------------------------------------------------

Pal_NoDec:
		addq.w	#2,a0
		rts
; End of function Pal_DecColor


; =============== S U B R O U T I N E =======================================


Pal_MakeWhite:
		move.w	#$3F,(v_pfade_start).w
		moveq	#0,d0
		lea	(v_palette).w,a0
		move.b	(v_pfade_start).w,d0
		adda.w	d0,a0
		move.w	#cWhite,d1
		move.b	(v_pfade_size).w,d0

loc_2286:
		move.w	d1,(a0)+
		dbf	d0,loc_2286
		move.w	#$16-1,d4

loc_2290:
		move.w	#Vint_Fade,(v_vbla_routine).w
		bsr.w	WaitForVint
		bsr.s	Pal_WhiteToBlack
		bsr.w	RunPLC_RAM
		dbf	d4,loc_2290
		rts
; End of function Pal_MakeWhite


; =============== S U B R O U T I N E =======================================


Pal_WhiteToBlack:
		moveq	#0,d0
		lea	(v_palette).w,a0
		lea	(v_palette_fading).w,a1
		move.b	(v_pfade_start).w,d0
		adda.w	d0,a0
		adda.w	d0,a1
		move.b	(v_pfade_size).w,d0

loc_22BC:
		bsr.s	Pal_DecColor2
		dbf	d0,loc_22BC
		tst.b	(Water_flag).w
		beq.s	locret_22E4
		moveq	#0,d0
		lea	(v_palette_water).w,a0
		lea	(v_palette_water_fading).w,a1
		move.b	(v_pfade_start).w,d0
		adda.w	d0,a0
		adda.w	d0,a1
		move.b	(v_pfade_size).w,d0

loc_22DE:
		bsr.s	Pal_DecColor2
		dbf	d0,loc_22DE

locret_22E4:
		rts
; End of function Pal_WhiteToBlack


; =============== S U B R O U T I N E =======================================


Pal_DecColor2:
		move.w	(a1)+,d2
		move.w	(a0),d3
		cmp.w	d2,d3
		beq.s	loc_2312
		move.w	d3,d1
		subi.w	#$200,d1
		blo.s	loc_22FE
		cmp.w	d2,d1
		blo.s	loc_22FE
		move.w	d1,(a0)+
		rts
; ---------------------------------------------------------------------------

loc_22FE:
		move.w	d3,d1
		subi.w	#$20,d1
		blo.s	loc_230E
		cmp.w	d2,d1
		blo.s	loc_230E
		move.w	d1,(a0)+
		rts
; ---------------------------------------------------------------------------

loc_230E:
		subq.w	#2,(a0)+
		rts
; ---------------------------------------------------------------------------

loc_2312:
		addq.w	#2,a0
		rts
; End of function Pal_DecColor2


; =============== S U B R O U T I N E =======================================


Pal_MakeFlash:
		move.w	#$3F,(v_pfade_start).w
		move.w	#$16-1,d4

loc_2320:
		move.w	#Vint_Fade,(v_vbla_routine).w
		bsr.w	WaitForVint
		bsr.s	Pal_ToWhite
		bsr.w	RunPLC_RAM
		dbf	d4,loc_2320
		rts
; End of function Pal_MakeFlash


; =============== S U B R O U T I N E =======================================


Pal_ToWhite:
		moveq	#0,d0
		lea	(v_palette).w,a0
		move.b	(v_pfade_start).w,d0
		adda.w	d0,a0
		move.b	(v_pfade_size).w,d0

loc_2346:
		bsr.s	Pal_AddColor2
		dbf	d0,loc_2346
		moveq	#0,d0
		lea	(v_palette_water).w,a0
		move.b	(v_pfade_start).w,d0
		adda.w	d0,a0
		move.b	(v_pfade_size).w,d0

loc_235C:
		bsr.s	Pal_AddColor2
		dbf	d0,loc_235C
		rts
; End of function Pal_ToWhite


; =============== S U B R O U T I N E =======================================


Pal_AddColor2:
		move.w	(a0),d2
		cmpi.w	#$EEE,d2
		beq.s	loc_23A0
		move.w	d2,d1
		andi.w	#$E,d1
		cmpi.w	#$E,d1
		beq.s	loc_237C
		addq.w	#2,(a0)+
		rts
; ---------------------------------------------------------------------------

loc_237C:
		move.w	d2,d1
		andi.w	#$E0,d1
		cmpi.w	#$E0,d1
		beq.s	loc_238E

loc_2388:
		addi.w	#$20,(a0)+
		rts
; ---------------------------------------------------------------------------

loc_238E:
		move.w	d2,d1
		andi.w	#$E00,d1
		cmpi.w	#$E00,d1
		beq.s	loc_23A0
		addi.w	#$200,(a0)+
		rts
; ---------------------------------------------------------------------------

loc_23A0:
		addq.w	#2,a0
		rts
; End of function Pal_AddColor2


; =============== S U B R O U T I N E =======================================


PalCycle_Sega:
		tst.b	(v_pcyc_time+1).w
		bne.s	loc_2404
		lea	(v_palette+$20).w,a1
		lea	(Pal_Sega1).l,a0
		moveq	#5,d1
		move.w	(v_pcyc_num).w,d0

loc_23BA:
		bpl.s	loc_23C4
		addq.w	#2,a0
		subq.w	#1,d1
		addq.w	#2,d0
		bra.s	loc_23BA
; ---------------------------------------------------------------------------

loc_23C4:
		move.w	d0,d2
		andi.w	#$1E,d2
		bne.s	loc_23CE
		addq.w	#2,d0

loc_23CE:
		cmpi.w	#$60,d0
		bcc.s	loc_23D8
		move.w	(a0)+,(a1,d0.w)

loc_23D8:
		addq.w	#2,d0
		dbf	d1,loc_23C4
		move.w	(v_pcyc_num).w,d0
		addq.w	#2,d0
		move.w	d0,d2
		andi.w	#$1E,d2
		bne.s	loc_23EE
		addq.w	#2,d0

loc_23EE:
		cmpi.w	#$64,d0
		blt.s	loc_23FC
		move.w	#$401,(v_pcyc_time).w
		moveq	#-$C,d0

loc_23FC:
		move.w	d0,(v_pcyc_num).w
		moveq	#1,d0
		rts
; ---------------------------------------------------------------------------

loc_2404:
		subq.b	#1,(v_pcyc_time).w
		bpl.s	loc_2456
		move.b	#4,(v_pcyc_time).w
		move.w	(v_pcyc_num).w,d0
		addi.w	#$C,d0
		cmpi.w	#$30,d0
		blo.s	loc_2422
		moveq	#0,d0
		rts
; ---------------------------------------------------------------------------

loc_2422:
		move.w	d0,(v_pcyc_num).w
		lea	(Pal_Sega2).l,a0
		lea	(a0,d0.w),a0
		lea	(v_palette+4).w,a1
		move.l	(a0)+,(a1)+
		move.l	(a0)+,(a1)+
		move.w	(a0)+,(a1)
		lea	(v_palette+$20).w,a1
		moveq	#0,d0
		moveq	#$2C,d1

loc_2442:
		move.w	d0,d2
		andi.w	#$1E,d2
		bne.s	loc_244C
		addq.w	#2,d0

loc_244C:
		move.w	(a0),(a1,d0.w)
		addq.w	#2,d0
		dbf	d1,loc_2442

loc_2456:
		moveq	#1,d0
		rts
; End of function PalCycle_Sega

; ---------------------------------------------------------------------------
Pal_Sega1:	binclude "palette/Sega1.bin"
		even
Pal_Sega2:	binclude "palette/Sega2.bin"
		even

; =============== S U B R O U T I N E =======================================


PalLoad1:
		lea	(PalPointers).l,a1
		lsl.w	#3,d0
		adda.w	d0,a1
		movea.l	(a1)+,a2
		movea.w	(a1)+,a3
		adda.w	#palette_size,a3
		move.w	(a1)+,d7

.loop:
		move.l	(a2)+,(a3)+
		dbf	d7,.loop
		rts
; End of function PalLoad1


; =============== S U B R O U T I N E =======================================


PalLoad2:
		lea	(PalPointers).l,a1
		lsl.w	#3,d0
		adda.w	d0,a1
		movea.l	(a1)+,a2
		movea.w	(a1)+,a3
		move.w	(a1)+,d7

.loop:
		move.l	(a2)+,(a3)+
		dbf	d7,.loop
		rts
; End of function PalLoad2


; =============== S U B R O U T I N E =======================================


PalLoad3_Water:
		lea	(PalPointers).l,a1
		lsl.w	#3,d0
		adda.w	d0,a1
		movea.l	(a1)+,a2
		movea.w	(a1)+,a3
		suba.l	#palette_size,a3
		move.w	(a1)+,d7

.loop:
		move.l	(a2)+,(a3)+
		dbf	d7,.loop
		rts
; End of function PalLoad3_Water


; =============== S U B R O U T I N E =======================================


PalLoad4_Water:
		lea	(PalPointers).l,a1
		lsl.w	#3,d0
		adda.w	d0,a1
		movea.l	(a1)+,a2
		movea.w	(a1)+,a3
		suba.l	#palette_size*2,a3
		move.w	(a1)+,d7

.loop:
		move.l	(a2)+,(a3)+
		dbf	d7,.loop
		rts
; End of function PalLoad4_Water

; ===========================================================================

		include	"_inc/Palette Pointers.asm"

; ---------------------------------------------------------------------------
; Palette data
; ---------------------------------------------------------------------------
Pal_SegaBG:	binclude	"palette/Sega Background.bin"
		even
Pal_Title:	binclude	"palette/Title Screen.bin"
		even
Pal_LevelSel:	binclude	"palette/Level Select.bin"
		even
Pal_SonicTails:	binclude	"palette/Sonic and Tails.bin"
		even
Pal_GHZ:	binclude	"palette/GHZ.bin"
		even
Pal_LZ:		binclude	"palette/LZ.bin"
		even
Pal_CPZ:	binclude	"palette/CPZ.bin"
		even
Pal_EHZ:	binclude	"palette/EHZ.bin"
		even
Pal_HPZ:	binclude	"palette/HPZ.bin"
		even
Pal_HTZ:	binclude	"palette/HTZ.bin"
		even
Pal_LZ4:	binclude	"palette/LZ4.bin"
		even
Pal_LZ4Water:	binclude	"palette/LZ4 Underwater.bin"
		even
Pal_HPZWater:	binclude	"palette/HPZ Underwater.bin"
		even
Pal_HPZSonWat:	binclude	"palette/HPZ Sonic Underwater.bin"
		even
Pal_LZSonWater:	binclude	"palette/LZ Sonic Underwater.bin"
		even
Pal_SBZSonWat:	binclude	"palette/LZ4 Sonic Underwater.bin"
		even
Pal_Special:	binclude	"palette/Special Stage.bin"
		even
Pal_SSResult:	binclude	"palette/Special Stage Results.bin"
		even
Pal_S1Continue:	binclude	"palette/Continue Screen.bin"
		even
Pal_S1Ending:	binclude	"palette/Ending.bin"
		even
; ===========================================================================
		include	"_inc/PaletteCycle.asm"

Pal_HTZCyc1:	binclude "palette/Hill Top Lava.bin"
		even
Pal_HTZCyc2:	binclude "palette/Hill Top Lava Delay.bin"
		even
Pal_GHZCyc:	binclude "palette/GHZ Water.bin"
		even
Pal_EHZCyc:	binclude "palette/EHZ Water.bin"
		even
Pal_CPZCyc1:	binclude "palette/CPZ Cycle 1.bin"
		even
Pal_CPZCyc2:	binclude "palette/CPZ Cycle 2.bin"
		even
Pal_CPZCyc3:	binclude "palette/CPZ Cycle 3.bin"
		even
Pal_MTZCyc1:	binclude "palette/MTZ Cycle 1.bin"
		even
Pal_MTZCyc2:	binclude "palette/MTZ Cycle 2.bin"
		even
Pal_MTZCyc3:	binclude "palette/MTZ Cycle 3.bin"
		even
Pal_HPZCyc1:	binclude "palette/HPZ Water Cycle.bin"
		even
Pal_HPZCyc2:	binclude "palette/HPZ Underwater Cycle.bin"
		even
Pal_WZCyc:	binclude "palette/WZ Cycle.bin"
		even
; ---------------------------------------------------------------------------
; Subroutine to perform vertical synchronization
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; DelayProgram:
WaitForVint:
		lea	(v_vbla_counter).w,a0
		move.b	#1,(a0)
		enable_ints

.wait:
		tst.b	(a0)
		bpl.s	.wait
		clr.b	(a0)
		rts
; End of function WaitForVint

; ---------------------------------------------------------------------------
; Subroutine to generate a pseudo-random number in d0
; d0 = (RNG & $FFFF0000) | ((RNG*41 & $FFFF) + ((RNG*41 & $FFFF0000) >> 16))
; RNG = ((RNG*41 + ((RNG*41 & $FFFF) << 16)) & $FFFF0000) | (RNG*41 & $FFFF)
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; PseudoRandomNumber:
RandomNumber:
		move.l	(v_random).w,d1
		bne.s	+
		move.l	#$2A6D365A,d1
+		; set the high word of d0 to be the high word of the RNG
		; and multiply the RNG by 41
		move.l	d1,d0
		asl.l	#2,d1
		add.l	d0,d1
		asl.l	#3,d1
		add.l	d0,d1
		; add the low word of the RNG to the high word of the RNG
		; and set the low word of d0 to be the result
		move.w	d1,d0
		swap	d1
		add.w	d1,d0
		move.w	d0,d1
		swap	d1
		move.l	d1,(v_random).w
		rts
; End of function RandomNumber

; ---------------------------------------------------------------------------
; Subroutine to calculate sine and cosine of an angle
; d0 = input byte = angle (360 degrees == 256)
; d0 = output word = 255 * sine(angle)
; d1 = output word = 255 * cosine(angle)
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


CalcSine:
		andi.w	#$FF,d0
		add.w	d0,d0
		addi.w	#$80,d0
		move.w	Sine_Data(pc,d0.w),d1		; cos
		subi.w	#$80,d0
		move.w	Sine_Data(pc,d0.w),d0		; sin
		rts
; End of function CalcSine

; ===========================================================================
Sine_Data:	binclude "misc/sinewave.bin"
		even
; ---------------------------------------------------------------------------
; Subroutine to calculate arctangent of y/x
; d1 = input x
; d2 = input y
; d0 = output angle (360 degrees == 256)
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


CalcAngle:
		movem.l	d3-d4,-(sp)
		moveq	#0,d3
		moveq	#0,d4
		move.w	d1,d3
		move.w	d2,d4
		or.w	d3,d4
		beq.s	CalcAngle_Zero			; special case return if x and y are both 0
		move.w	d2,d4
		tst.w	d3				; calculate absolute value of x
		bpl.s	loc_2F68
		neg.w	d3

loc_2F68:
		tst.w	d4				; calculate absolute value of y
		bpl.s	loc_2F70
		neg.w	d4

loc_2F70:
		cmp.w	d3,d4
		bcc.s	loc_2F82
		lsl.l	#8,d4
		divu.w	d3,d4
		moveq	#0,d0
		move.b	AngleData(pc,d4.w),d0
		bra.s	loc_2F8C
; ---------------------------------------------------------------------------

loc_2F82:
		lsl.l	#8,d3
		divu.w	d4,d3
		moveq	#$40,d0
		sub.b	AngleData(pc,d3.w),d0

loc_2F8C:
		tst.w	d1
		bpl.s	loc_2F98
		neg.w	d0
		addi.w	#$80,d0

loc_2F98:
		tst.w	d2
		bpl.s	loc_2FA4
		neg.w	d0
		addi.w	#$100,d0

loc_2FA4:
		movem.l	(sp)+,d3-d4
		rts
; ===========================================================================
; loc_2FAA:
CalcAngle_Zero:
		moveq	#$40,d0
		movem.l	(sp)+,d3-d4
		rts
; End of function CalcAngle

; ===========================================================================
AngleData:	binclude "misc/angles.bin"
		even
; ===========================================================================
; ---------------------------------------------------------------------------
; Sega logo
; ---------------------------------------------------------------------------

SegaScreen:
		move.b	#bgm_Stop,d0
		bsr.w	PlaySound_Special
		bsr.w	ClearPLC
		bsr.w	Pal_FadeToBlack
		lea	(vdp_control_port).l,a6
		move.w	#$8000+4,(a6)	; use 8-colour mode
		move.w	#$8200+(vram_fg>>10),(a6) ; set foreground nametable address
		move.w	#$8400+(vram_bg>>13),(a6) ; set background nametable address
		move.w	#$8700,(a6)	; set background colour (palette entry 0)
		move.w	#$8B00,(a6)	; full-screen vertical scrolling
		move.w	#$8C00+$81,(a6)
		sf	(f_wtr_state).w
		disable_ints
		move.w	(v_vdp_buffer1).w,d0
		andi.b	#$BF,d0
		move.w	d0,(vdp_control_port).l
		bsr.w	ClearScreen
		locVRAM ArtTile_Sega_Tiles*tile_size
		lea	(Nem_SegaLogo).l,a0
		bsr.w	NemDec
		lea	(Chunk_Table).l,a1
		lea	(Eni_SegaLogo).l,a0
		move.w	#make_art_tile(ArtTile_Sega_Tiles,0,0),d0
		bsr.w	EniDec
		copyTilemap	Chunk_Table,vram_bg+$510,24,8
		copyTilemap	Chunk_Table+$180,vram_fg,40,28
		tst.b	(v_megadrive).w			; is console Japanese?
		bmi.s	.loadpal			; if not, branch
		copyTilemap	Chunk_Table+$A40,vram_fg+$53A,3,2 ; hide "TM" with a white rectangle

.loadpal:
		moveq	#palid_SegaBG,d0
		bsr.w	PalLoad2
		move.w	#-$A,(v_pcyc_num).w
		moveq	#0,d0
		move.w	d0,(v_pcyc_time).w
		move.w	d0,(v_pal_buffer+$12).w
		move.w	d0,(v_pal_buffer+$10).w
		move.w	(v_vdp_buffer1).w,d0
		ori.b	#$40,d0
		move.w	d0,(vdp_control_port).l

Sega_WaitPalette:
		move.w	#Vint_SEGA,(v_vbla_routine).w
		bsr.w	WaitForVint
		bsr.w	PalCycle_Sega
		bne.s	Sega_WaitPalette
	;	moveq	#0,d0	; unnecessary, at least according to tests so far
		bsr.w	ChangeSegaSound
		move.b	#sfx_Sega,d0
		bsr.w	PlaySound
		move.w	#Vint_SEGA,(v_vbla_routine).w
		bsr.w	WaitForVint
		move.w	#100,(v_generictimer).w

Sega_WaitEnd:
		move.w	#Vint_PCM,(v_vbla_routine).w
		bsr.w	WaitForVint
		tst.w	(v_generictimer).w
		beq.s	Sega_GoToTitleScreen
		move.b	(v_jpadpress1).w,d0	; is Start button pressed?
		or.b	(v_jpadpress2).w,d0	; (either player)
		andi.b	#btnStart,d0
		beq.s	Sega_WaitEnd

Sega_GoToTitleScreen:
		move.w	#TitleScreen,(v_gamemode).w
		rts
; ===========================================================================

TitleScreen:
		move.b	#bgm_Stop,d0
		bsr.w	PlaySound_Special ; stop music
		bsr.w	ClearPLC
		bsr.w	Pal_FadeToBlack
		disable_ints
		lea	(vdp_control_port).l,a6
		move.w	#$8000+4,(a6)	; 8-colour mode
		move.w	#$8200+(vram_fg>>10),(a6) ; set foreground nametable address
		move.w	#$8400+(vram_bg>>13),(a6) ; set background nametable address
		move.w	#$9001,(a6)	; 64-cell hscroll size
		move.w	#$9200,(a6)	; window vertical position
		move.w	#$8B03,(a6)
		move.w	#$8720,(a6)	; set background colour (palette line 2, entry 0)
		sf	(f_wtr_state).w
		move.w	#$8C00+$81,(a6)	; H res 40 cells, no interlace, S/H disabled
		bsr.w	ClearScreen
		clearRAM v_spritequeue,v_spritequeue_end
		clearRAM v_objspace,v_objend
		clearRAM v_levelvariables,v_levelvariables_end
		clearRAM Camera_RAM,Camera_RAM_End
		clearRAM v_palette_fading,v_palette_fading_end

		lea	(Kosp_CreditText).l,a0		; load alphabet
		lea	(Chunk_Table).l,a1
		move.w	#tiles_to_bytes(ArtTile_SonicTeamPresents),a2
		bsr.w	KosPlusArt_To_VDP
		moveq	#palid_SonicTails,d0
		bsr.w	PalLoad1
		_move.b	#id_Obj90,(v_sonicteam).w	; load "SONIC TEAM PRESENTS" object
		jsr	(ExecuteObjects).l
		jsr	(BuildSprites).l
        	bsr.w	Pal_FadeFromBlack
		disable_ints
		lea	(Kosp_Title).l,a0
		lea	(Chunk_Table).l,a1
		move.w	#tiles_to_bytes(ArtTile_Title_Foreground),a2
		bsr.w	KosPlusArt_To_VDP
		locVRAM	ArtTile_Title_Sonic_And_Tails*tile_size
		; This uses Nemesis Compression for two reasons:
		; First, the speed tradeoff plays against us in this case, Making the previous screen
		; Banish too early. Secondly, it's one of the few cases were
		; it compresses worse in Kosp/Kospm
		lea	(Nem_TitleSonicTails).l,a0
		bsr.w	NemDec		; Would be too fast (making the previous screen banish too early)
		lea	(vdp_data_port).l,a6	; and waste space
		locVRAM	ArtTile_Level_Select_Font*tile_size,4(a6)
		lea	(Art_Text).l,a5
		move.w	#bytesToWcnt(Art_Text_End-Art_Text),d1
-		move.w	(a5)+,(a6)
		dbf	d1,-

		moveq	#0,d0
		move.b	d0,(v_lastlamp).w
		move.w	d0,(Debug_placement_mode).w
		move.w	d0,(f_demo).w
		move.w	d0,(v_pcyc_time).w
		move.b	d0,(Current_Timezone).w
		move.w	#id_GHZ<<8,(Current_ZoneAndAct).w
		bsr.w	Pal_FadeToBlack
		disable_ints
		lea	(Chunk_Table).l,a1
		lea	(Eni_TitleMap).l,a0
		move.w	#make_art_tile(ArtTile_Title_Foreground,0,0),d0
		bsr.w	EniDec
		copyTilemap	Chunk_Table,vram_fg,40,28
		lea	(Chunk_Table).l,a1
		lea	(Kosp_TitleBg1).l,a0
		bsr.w	KosPlusDec
		copyTilemap	Chunk_Table,vram_bg,32,28
		lea	(Chunk_Table).l,a1
		lea	(Kosp_TitleBg2).l,a0
		bsr.w	KosPlusDec
		copyTilemap	Chunk_Table,vram_bg+64,32,28
		moveq	#palid_Title,d0
		bsr.w	PalLoad1
		move.b	#bgm_Title,d0
		bsr.w	PlaySound_Special
	;	clr.b	(Debug_mode_flag).w
		move.w	#376,(v_generictimer).w
		clearRAM v_sonicteam,v_sonicteam+object_size
		_move.b	#id_Obj91,(v_titlesonic).w
		_move.b	#id_Obj91,(v_titletails).w
		_move.b	#id_Obj93,(v_pressstart).w
		move.b	#1,(v_titletails+obFrame).w
		jsr	(ExecuteObjects).l
		jsr	(BuildSprites).l
		moveq	#plcid_Main,d0
		bsr.w	NewPLC
	;	move.w	#id_EHZ<<8,(Current_ZoneAndAct).w
		moveq	#0,d0
		move.w	d0,(v_title_dcount).w
		move.w	d0,(v_title_ccount).w
		move.w	d0,(Sonic_Pos_Record_Buf).w
		move.w	#4,(Sonic_Pos_Record_Index).w
		move.w	(v_vdp_buffer1).w,d0
		ori.b	#$40,d0
		move.w	d0,(vdp_control_port).l
		bsr.w	Pal_FadeFromBlack

TitleScreen_Loop:
		move.w	#Vint_Title,(v_vbla_routine).w
		bsr.w	WaitForVint
		jsr	(ExecuteObjects).l
		jsr	(BuildSprites).l
		bsr.w	Deform_TitleScreen
	;	bsr.w	PalCycle_TitleScreen	; For reference, in case this is implemented
		bsr.w	RunPLC_RAM
		lea	(LvlSelCode).l,a0
		move.w	(v_title_dcount).w,d0
		adda.w	d0,a0
		move.b	(v_jpadpress1).w,d0
		andi.b	#$F,d0
		cmp.b	(a0),d0
		bne.s	Title_Cheat_NoMatch
		addq.w	#1,(v_title_dcount).w
		tst.b	d0
		bne.s	Title_Cheat_CountC
		lea	(f_levselcheat).w,a0
		move.w	(v_title_ccount).w,d1
		lsr.w	#1,d1
		andi.w	#3,d1
		beq.s	Title_Cheat_PlayRing
		tst.b	(v_megadrive).w
		bpl.s	Title_Cheat_PlayRing
		moveq	#1,d1
		move.b	d1,1(a0,d1.w)

Title_Cheat_PlayRing:
		move.b	#1,(a0,d1.w)
		move.b	#sfx_Ring,d0
		bsr.w	PlaySound_Special
		bra.s	Title_Cheat_CountC
; ---------------------------------------------------------------------------

Title_Cheat_NoMatch:
		tst.b	d0
		beq.s	Title_Cheat_CountC
		cmpi.w	#9,(v_title_dcount).w
		beq.s	Title_Cheat_CountC
		clr.w	(v_title_dcount).w

Title_Cheat_CountC:
		move.b	(v_jpadpress1).w,d0
		andi.b	#btnC,d0
		beq.s	Title_Cheat_NoC
		addq.w	#1,(v_title_ccount).w

Title_Cheat_NoC:
		tst.w	(v_generictimer).w
		beq.w	PrepareDemo
		andi.b	#btnStart,(v_jpadpress1).w
		beq.w	TitleScreen_Loop

Title_CheckLvlSel:
		tst.b	(f_levselcheat).w
		beq.w	PlayLevel
		moveq	#palid_LevelSel,d0
		bsr.w	PalLoad2
		clearRAM v_hscrolltablebuffer,v_hscrolltablebuffer_end
		move.l	d0,(v_scrposy_vdp).w
		disable_ints
		lea	(vdp_data_port).l,a6
		move.l	#$60000003,(vdp_control_port).l
		move.w	#bytesToLcnt($1000),d1

LevelSelect_ClearVRAM:
		move.l	d0,(a6)
		dbf	d1,LevelSelect_ClearVRAM
		bsr.w	LevelSelect_TextLoad

LevelSelect_Loop:
		move.w	#Vint_Title,(v_vbla_routine).w
		bsr.w	WaitForVint
		bsr.w	LevelSelect_Controls
		bsr.w	RunPLC_RAM
		tst.l	(v_plc_buffer).w
		bne.s	LevelSelect_Loop
		andi.b	#btnABC+btnStart,(v_jpadpress1).w
		beq.s	LevelSelect_Loop
		move.w	(v_levselitem).w,d0
		cmpi.w	#$14,d0
		bne.s	loc_3570
		move.w	(v_levselsound).w,d0
	;	cmpi.w	#$9F,d0
	;	beq.s	loc_354C
	;	cmpi.w	#$9E,d0
	;	beq.s	loc_355A

;loc_353A:
		bsr.w	PlaySound_Special
		bra.s	LevelSelect_Loop
; ---------------------------------------------------------------------------

; loc_354C:
	;	move.w	#Ending,(v_gamemode).w
	;	move.w	#id_EndZ<<8,(Current_ZoneAndAct).w
	;	rts
; ---------------------------------------------------------------------------

; loc_355A:
	;	move.w	#Credits,(v_gamemode).w
	;	move.b	#bgm_Credits,d0
	;	bsr.w	PlaySound_Special
	;	clr.w	(v_creditsnum).w
	;	rts
; ---------------------------------------------------------------------------

loc_3570:
		add.w	d0,d0
		move.w	LevelSelect_LevelOrder(pc,d0.w),d0
		bmi.w	LevelSelect_Loop
		cmpi.w	#id_SS<<8,d0
		bne.s	LevelSelect_Level
		move.w	#BonusStage,(v_gamemode).w
		clr.w	(Current_ZoneAndAct).w
		move.b	#3,(v_lives).w
		moveq	#0,d0
		move.w	d0,(v_rings).w
		move.l	d0,(v_time).w
		move.l	d0,(v_score).w
		move.l	#5000,(v_scorelife).w
		rts
; ---------------------------------------------------------------------------
LevelSelect_LevelOrder:
		dc.b id_GHZ,0
		dc.b id_GHZ,1
		dc.b id_GHZ,2
		dc.b id_MZ,0
		dc.b id_MZ,1
		dc.b id_MZ,2
		dc.b id_HPZ,0
		dc.b id_HPZ,1
		dc.b id_HPZ,2
		dc.b id_LZ,0
		dc.b id_LZ,1
		dc.b id_LZ,2
		dc.b id_EHZ,0
		dc.b id_EHZ,1
		dc.b id_EHZ,2
		dc.b id_HTZ,0
		dc.b id_HTZ,1
		dc.b id_LZ,3
		dc.b id_HTZ,2
		dc.b id_SS,0
		dc.w $8000
; ---------------------------------------------------------------------------

LevelSelect_Level:
		andi.w	#$3FFF,d0
		move.w	d0,(Current_ZoneAndAct).w

PlayLevel:
		move.w	#Level,(v_gamemode).w
		move.b	#3,(v_lives).w
		moveq	#0,d0
		move.w	d0,(v_rings).w
		move.l	d0,(v_time).w
		move.l	d0,(v_score).w
		move.b	d0,(v_lastbonus).w
	;	move.b	d0,(v_lastspecial).w	; TODO
		move.b	d0,(v_emeralds).w
		move.l	d0,(v_emldlist).w
		move.l	d0,(v_emldlist+4).w
		move.b	d0,(v_continues).w
		move.l	#5000,(v_scorelife).w
		move.b	#bgm_Fade,d0
		bra.w	PlaySound_Special
; ---------------------------------------------------------------------------
LvlSelCode:	dc.b btnUp, btnDn, btnDn, btnDn, btnDn, btnUp, 0, $FF	; up, down, down, down, down, up
; ---------------------------------------------------------------------------

PrepareDemo:
		move.w	#30,(v_generictimer).w

.keepgoing:
		move.w	#Vint_Title,(v_vbla_routine).w
		bsr.w	WaitForVint
		bsr.w	RunPLC_RAM
		move.w	(v_objspace+obX).w,d0
		addq.w	#2,d0
		move.w	d0,(v_objspace+obX).w
		cmpi.w	#$1C00,d0
		blo.s	RunDemo
		move.w	#SegaScreen,(v_gamemode).w
		rts
; ---------------------------------------------------------------------------

RunDemo:
		andi.b	#btnStart,(v_jpadpress1).w	; was the Start button pressed?
		bne.w	Title_CheckLvlSel	; if so, branch
		tst.w	(v_generictimer).w
		bne.s	PrepareDemo.keepgoing
		move.b	#bgm_Fade,d0
		bsr.w	PlaySound_Special	; fade out music
		move.w	(v_demonum).w,d0	; load demo number
		andi.w	#7,d0
		add.w	d0,d0
		move.w	Demo_Levels(pc,d0.w),d0	; load level number for demo
		move.w	d0,(Current_ZoneAndAct).w
		addq.w	#1,(v_demonum).w	; add 1 to demo number
		cmpi.w	#4,(v_demonum).w	; is this the 4th demo?
		blo.s	RunDemo2		; if so, continue
		clr.w	(v_demonum).w	; reset the demo counter & loop

RunDemo2:
		move.w	#1,(f_demo).w		; activate Demo mode
		move.w	#Demo,(v_gamemode).w	; set gamemode to $8 (demo)
		cmpi.w	#id_EndZ<<8,d0		; is this the ending?
		bne.s	Demo_Level		; if so, skip
		move.w	#BonusStage,(v_gamemode).w	; set gamemode to $10 (Special stage)
		clr.w	(Current_ZoneAndAct).w	; clear level number
		clr.b	(v_lastbonus).w		; clear bonus stage number

Demo_Level:
		move.b	#3,(v_lives).w	; reset lives, rings, time, score, and extra life points
		moveq	#0,d0
		move.w	d0,(v_rings).w
	;	move.w	#100,(v_ring1uplimit).w	; reset ring 1-up flag -- TODO --
		move.l	d0,(v_time).w
		move.l	d0,(v_score).w
		move.l	#5000,(v_scorelife).w
		rts
; ---------------------------------------------------------------------------
; Levels used in demos
; ---------------------------------------------------------------------------
Demo_Levels:
		dc.w id_GHZ<<8
		dc.w id_CPZ<<8
		dc.w id_EHZ<<8
		dc.w id_HPZ<<8
		dc.w id_HTZ<<8
		dc.w id_HTZ<<8
		dc.w id_HTZ<<8
		dc.w id_HTZ<<8
		dc.w id_HTZ<<8
		dc.w id_HPZ<<8
		dc.w id_HPZ<<8
		dc.w id_HPZ<<8
		dc.w id_HPZ<<8

; =============== S U B R O U T I N E =======================================


LevelSelect_Controls:
		move.b	(v_jpadpress1).w,d1
		andi.b	#btnUp+btnDn,d1
		bne.s	loc_3706
		subq.w	#1,(v_levseldelay).w
		bpl.s	loc_3740

loc_3706:
		move.w	#12-1,(v_levseldelay).w
		move.b	(v_jpadhold1).w,d1
		andi.b	#btnUp+btnDn,d1
		beq.s	loc_3740
		move.w	(v_levselitem).w,d0
		btst	#bitUp,d1
		beq.s	loc_3726
		subq.w	#1,d0
		bhs.s	loc_3726
		moveq	#$14,d0

loc_3726:
		btst	#bitDn,d1
		beq.s	loc_3736
		addq.w	#1,d0
		cmpi.w	#$15,d0
		blo.s	loc_3736
		moveq	#0,d0

loc_3736:
		move.w	d0,(v_levselitem).w
		bra.s	LevelSelect_TextLoad
; ---------------------------------------------------------------------------

loc_3740:
		cmpi.w	#$14,(v_levselitem).w
		bne.w	locret_377A
		move.b	(v_jpadpress1).w,d1
		andi.b	#btnL+btnR,d1
		beq.w	locret_377A
		move.w	(v_levselsound).w,d0
		btst	#bitL,d1
		beq.s	loc_3762
		subq.w	#1,d0
		bhs.s	loc_3762
		move.w	#$FF,d0

loc_3762:
		btst	#bitR,d1
		beq.s	loc_3772
		addq.w	#1,d0
		cmpi.w	#$FF,d0
		blo.s	loc_3772
		moveq	#0,d0

loc_3772:
		move.w	d0,(v_levselsound).w
		; Fall through
; End of function LevelSelect_Controls


; =============== S U B R O U T I N E =======================================

textpos:	= ($40000000+(($E210&$3FFF)<<16)+(($E210&$C000)>>14))
					; $E210 is a VRAM address

LevelSelect_TextLoad:
		lea	LevelSelect_Text(pc),a1
		lea	(vdp_data_port).l,a6
		move.l	#textpos,d4
		move.w	#$8680,d3
		moveq	#$15-1,d1

loc_3794:
		move.l	d4,4(a6)
		bsr.s	LevSel_ChgLine
		addi.l	#$800000,d4
		dbf	d1,loc_3794
		moveq	#0,d0
		move.w	(v_levselitem).w,d0
		move.w	d0,d1
		move.l	#textpos,d4
		lsl.w	#7,d0
		swap	d0
		add.l	d0,d4
		lea	LevelSelect_Text(pc),a1
		lsl.w	#3,d1
		move.w	d1,d0
		add.w	d1,d1
		add.w	d0,d1
		adda.w	d1,a1
		move.w	#$C680,d3
		move.l	d4,4(a6)
		bsr.s	LevSel_ChgLine
		move.w	#$8680,d3
		cmpi.w	#$14,(v_levselitem).w
		bne.s	LevSel_DrawSnd
		move.w	#$C680,d3

LevSel_DrawSnd:
		locVRAM	vram_bg+$C30		; sound test position on screen
		move.w	(v_levselsound).w,d0
		move.b	d0,d2
		lsr.b	#4,d0
		bsr.s	LevSel_ChgSnd
		move.b	d2,d0
		; falls through to LevSel_ChgSnd
; End of function LevelSelect_TextLoad


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


LevSel_ChgSnd:
		andi.w	#$F,d0
		cmpi.b	#$A,d0		; is digit $A-$F?
		blo.s	LevSel_Numb	; if not, branch
		addq.b	#7,d0		; use alpha characters

LevSel_Numb:
		add.w	d3,d0
		move.w	d0,(a6)
locret_377A:
		rts
; End of function LevSel_ChgSnd


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


LevSel_ChgLine:
		moveq	#$18-1,d2		; number of characters per line

LevSel_LineLoop:
		moveq	#0,d0
		move.b	(a1)+,d0	; get character
		bpl.s	LevSel_CharOk	; branch if valid
		clr.w	(a6)		; use blank character
		dbf	d2,LevSel_LineLoop
		rts


LevSel_CharOk:
		add.w	d3,d0		; combine char with VRAM setting
		move.w	d0,(a6)		; send to VRAM
		dbf	d2,LevSel_LineLoop
		rts
; End of function LevSel_ChgLine

; ---------------------------------------------------------------------------
LevelSelect_Text:
		binclude	"mappings/misc/Level select text.bin"
		even
; ---------------------------------------------------------------------------
MusicList:	dc.b bgm_GHZ
		dc.b bgm_LZ
		dc.b bgm_MZ
		dc.b bgm_SLZ
		dc.b bgm_SYZ
		dc.b bgm_SBZ
		dc.b MusID_MTZ
		even
; ===========================================================================
; ---------------------------------------------------------------------------
; Level
; DEMO AND ZONE LOOP (MLS values $08, $0C; bit 7 set indicates that load routine is running)
; ---------------------------------------------------------------------------
Demo:
		bra.s	+
Level:
		clr.w	(f_demo).w
+		bset	#7,(v_gamemode).w	; GameModeFlag_TitleCard
		tst.w	(f_demo).w	; are we on an ending demo?
		bmi.s	Level_NoMusicFade	; if so, branch
		move.b	#bgm_Fade,d0
		bsr.w	PlaySound_Special

Level_NoMusicFade:
		bsr.w	ClearPLC
		bsr.w	Pal_FadeToBlack
		tst.w	(f_demo).w	; are we on an ending demo?
		bmi.s	Level_ClrRam	; if so, branch
		disable_ints
		locVRAM	ArtTile_Title_Card*tile_size
		lea	(Nem_TitleCard).l,a0	; load title card patterns
		bsr.w	NemDec
		enable_ints
		moveq	#0,d1
		move.w	(Current_ZoneAndAct).w,d1
		ror.b	#2,d1
		lsr.w	#3,d1
		move.w	d1,d0
		lsr.w	#1,d0
		add.w	d0,d1
		lea	(LevelArtPointers).l,a2
		moveq	#0,d0
		move.b	(a2,d1.w),d0
		beq.s	loc_3BB0
		bsr.w	LoadPLC

loc_3BB0:
		moveq	#plcid_Main2,d0
		bsr.w	LoadPLC

Level_ClrRam:
		clearRAM v_spritequeue,v_spritequeue_end
		clearRAM v_objspace,v_objend
		clearRAM v_levelvariables,v_levelvariables_end
		clearRAM v_misc_variables,v_misc_variables_end
		clearRAM v_timingvariables,v_timingvariables_end
		; TODO switch for a proper water table
		moveq	#0,d0
		moveq	#0,d1
		move.b	(Current_Zone).w,d0
		cmpi.b	#id_LZ,d0	; are we on Labyrinth Zone?
		seq.b	d1		; if so, set
		cmpi.b	#id_HPZ,d0	; are we on Hidden Palace Zone?
		seq.b	d0		; if so, set
		or.b	d1,d0		; it's either one or the other
		move.b	d0,(Water_flag).w
		bsr.w	ClearScreen
		lea	(vdp_control_port).l,a6
		move.w	#$8B00+3,(a6)	; set horizontal scrolling single pixel rows mode
		move.w	#$8200+(vram_fg>>10),(a6)
		move.w	#$8400+(vram_bg>>13),(a6)
		move.w	#$8500+(vram_sprites>>9),(a6)
		move.w	#$9001,(a6)
		move.w	#$8000+4,(a6)
		move.w	#$8700+(2<<4)+0,(a6)	; set background color to first slot of line 2
		move.w	#$8A00+224-1,(v_hbla_hreg).w
		move.w	(v_hbla_hreg).w,(a6)
		ResetDMAQueue
		moveq	#palid_SonicTails,d0
		bsr.w	PalLoad2
		bsr.w	CheckLevelForWater
		tst.w	(f_demo).w	; are we on an ending demo?
		bmi.s	Level_SkipTtlCard	; if so, branch
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
;		cmpi.w	#(id_LZ<<8)+3,(Current_ZoneAndAct).w
;		bne.s	Level_BgmNotLZ4
;		moveq	#5,d0

;Level_BgmNotLZ4:
;		cmpi.w	#(id_SBZ<<8)+2,(Current_ZoneAndAct).w
;		bne.s	Level_PlayBgm
;		moveq	#6,d0

Level_PlayBgm:
		lea	MusicList(pc),a1	; load music playlist
		move.b	(a1,d0.w),d0
		bsr.w	PlaySound		; play music
		_move.b	#id_Obj94,(v_titlecard).w	; load title card object

Level_TtlCardLoop:
		move.w	#Vint_TitleCard,(v_vbla_routine).w
		bsr.w	WaitForVint
		bsr.w	Process_Kos_Queue
		jsr	(ExecuteObjects).l
		jsr	(BuildSprites).l
		bsr.w	RunPLC_RAM
		bsr.w	Process_Kos_Module_Queue
		move.w	(v_ttlcardact+obX).w,d0
		cmp.w	(v_ttlcardact+objoff_30).w,d0
		bne.s	Level_TtlCardLoop
		tst.l	(v_plc_buffer).w
		bne.s	Level_TtlCardLoop
		move.w	#Vint_TitleCard,(v_vbla_routine).w
		bsr.w	WaitForVint
		jsr	(HUD_Base).l

Level_SkipTtlCard:
		moveq	#palid_SonicTails,d0
		bsr.w	PalLoad1
		bsr.w	LevelSizeLoad
		bsr.w	DeformBGLayer
		bset	#2,(Scroll_flags).w
		bsr.w	LoadZone
	;	bsr.w	MainLevelLoadBlock
		jsr	(LoadAnimatedBlocks).l
		bsr.w	LoadTilesFromStart
		bsr.w	LoadCollisionIndexes
		bsr.w	WaterEffects
		_move.b	#id_Obj01,(v_player).w	; load Sonic object
	;	tst.w	(f_demo).w		; are we on an ending demo?
	;	bmi.s	LevelInit_LoadTails	; if not, branch
;		cmpi.b	#id_EHZ,(Current_Zone).w; This is an example on how to skip
;		beq.s	Level_ChkDebug		; the 2nd player, if neccesary

;LevelInit_LoadTails:	; Disabled until his AI &/or character selection is implemented
		_move.b	#id_Obj02,(v_player2).w	; load Tails object
		move.w	(v_player+obX).w,(v_player2+obX).w	; copy player 1's x position to player 2
		move.w	(v_player+obY).w,(v_player2+obY).w	; copy player 1's y position to player 2
		subi.w	#32,(v_player2+obX).w	; set player 2's x position 32 pixels behind player 1's

Level_ChkDebug:
		tst.b	(f_debugcheat).w
		beq.s	Level_ChkWater
		btst	#bitA,(v_jpadhold1).w
		beq.s	Level_ChkWater
		move.b	#1,(Debug_mode_flag).w

Level_ChkWater:
		clr.w	(v_jpadholdlogical).w
		clr.w	(v_jpadhold1).w
		tst.b	(Water_flag).w
		beq.s	Level_LoadObj
		_move.b	#id_Obj07,(v_watersurface1).w
		move.w	#$60,(v_watersurface1+obX).w
		_move.b	#id_Obj07,(v_watersurface2).w
		move.w	#$120,(v_watersurface2+obX).w

Level_LoadObj:
		jsr	(ObjectsManager).l
		jsr	(RingsManager).l
		jsr	(ExecuteObjects).l
		jsr	(BuildSprites).l
		jsr	(Animate_Tiles).l
		moveq	#0,d0
		tst.b	(v_lastlamp).w
		bne.s	Level_SkipClr
		move.w	d0,(v_rings).w
		move.l	d0,(v_time).w
		move.b	d0,(v_lifecount).w

Level_SkipClr:
		move.b	d0,(f_timeover).w
		move.b	d0,(v_shield).w
		move.b	d0,(v_invinc).w
		move.b	d0,(v_shoes).w
		move.w	d0,(Debug_placement_mode).w
		move.w	d0,(Level_Inactive_flag).w
		move.w	d0,(Timer_frames).w
		bsr.w	OscillateNumInit
		move.b	#1,(f_scorecount).w
		move.b	#1,(f_ringcount).w
		move.b	#1,(f_timecount).w
		move.w	#4,(Sonic_Pos_Record_Index).w
		moveq	#0,d0
		move.w	d0,(Sonic_Pos_Record_Buf).w
		move.w	d0,(Demo_button_index).w
		lea	(Demo_Index).l,a1
		move.b	(Current_Zone).w,d0
		lsl.w	#2,d0
		movea.l	(a1,d0.w),a1
		tst.w	(f_demo).w	; is this an ending demo?
		bpl.s	Level_Demo	; if not, branch
		lea	(DemoEndDataPtr).l,a1
		move.w	(v_creditsnum).w,d0
		subq.w	#1,d0
		lsl.w	#2,d0
		movea.l	(a1,d0.w),a1

Level_Demo:
		move.b	1(a1),(Demo_press_counter).w
		subq.b	#1,(Demo_press_counter).w
		move.w	#1800,(v_generictimer).w
		tst.w	(f_demo).w	; is this an ending demo?
		bpl.s	Level_ChkWaterPal	; if not, branch
		move.w	#60*9,(v_generictimer).w
		cmpi.w	#4,(v_creditsnum).w
		bne.s	Level_ChkWaterPal
		move.w	#510,(v_generictimer).w

Level_ChkWaterPal:
		tst.b	(Water_flag).w
		beq.s	Level_Delay
		moveq	#palid_HPZWater,d0
		cmpi.w	#(id_LZ<<8)+3,(Current_ZoneAndAct).w ; is level SBZ3 (LZ4) ?
		bne.s	Level_WtrNotHtz
		moveq	#palid_SBZ3Water,d0

Level_WtrNotHtz:
		bsr.w	PalLoad4_Water

Level_Delay:
		moveq	#4-1,d1

Level_DelayLoop:
		move.w	#Vint_Level,(v_vbla_routine).w
		bsr.w	WaitForVint
		dbf	d1,Level_DelayLoop
		move.w	#$202F,(v_pfade_start).w
		bsr.w	Pal_FadeFromBlack2
		tst.w	(f_demo).w	; is this an ending demo?
		bmi.s	Level_ClrTitleCard	; if so, branch
		addq.b	#2,(v_ttlcardname+obRoutine).w
		addq.b	#4,(v_ttlcardzone+obRoutine).w
		addq.b	#4,(v_ttlcardact+obRoutine).w
		addq.b	#4,(v_ttlcardoval+obRoutine).w
		bra.s	Level_StartGame
; ===========================================================================

Level_ClrTitleCard:
		moveq	#plcid_Explode,d0
		bsr.w	LoadPLC
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
		addi.w	#plcid_GHZAnimals,d0
		bsr.w	LoadPLC
		bsr.w	LoadKosPLC

Level_StartGame:
		bclr	#7,(v_gamemode).w	; GameModeFlag_TitleCard

; ---------------------------------------------------------------------------
; Main level loop (when all title card and loading sequences are finished)
; ---------------------------------------------------------------------------
Level_MainLoop:
		bsr.w	PauseGame
		move.w	#Vint_Level,(v_vbla_routine).w
		bsr.w	Process_Kos_Queue
		bsr.w	WaitForVint
		addq.w	#1,(Timer_frames).w
		bsr.w	RandomNumber
		bsr.w	MoveSonicInDemo
		bsr.w	WaterEffects
		jsr	(ExecuteObjects).l
		tst.w	(Level_Inactive_flag).w
		bne.w	Level
		tst.w	(Debug_placement_mode).w
		bne.s	Level_DoScroll
		cmpi.b	#6,(v_player+obRoutine).w
		bhs.s	Level_SkipScroll

Level_DoScroll:
		bsr.w	DeformBGLayer

Level_SkipScroll:
		bsr.w	ChangeWaterSurfacePos
		jsr	(RingsManager).l
		jsr	(Animate_Tiles).l
		bsr.w	PalCycle_Load
		bsr.w	RunPLC_RAM
		jsr     (Process_Kos_Module_Queue).l
		bsr.w	OscillateNumDo
		bsr.w	ChangeRingFrame
		bsr.w	SignpostArtLoad
		jsr	(BuildSprites).l
		jsr	(ObjectsManager).l
		cmpi.w	#Demo,(v_gamemode).w
		beq.s	Level_ChkDemo
		cmpi.w	#Level,(v_gamemode).w
		beq.w	Level_MainLoop
		rts
; ---------------------------------------------------------------------------

Level_ChkDemo:
		cmpi.b	#6,(v_player+obRoutine).w	; is Sonic dead?
		beq.s	Level_EndDemo			; if so, skip ahead
		tst.w	(Level_Inactive_flag).w		; is level set to restart?
		bne.s	Level_EndDemo			; if so, branch
		tst.w	(v_generictimer).w		; is there time left on the demo?
		beq.s	Level_EndDemo			; if not, branch
		cmpi.w	#Demo,(v_gamemode).w
		beq.w	Level_MainLoop
		move.w	#SegaScreen,(v_gamemode).w
		rts
; ---------------------------------------------------------------------------

Level_EndDemo:
		cmpi.w	#Demo,(v_gamemode).w
		bne.s	Level_FadeDemo
		move.w	#SegaScreen,(v_gamemode).w
		tst.w	(f_demo).w
		bpl.s	Level_FadeDemo
	;	move.w	#Credits,(v_gamemode).w	; TODO
		move.w	#SegaScreen,(v_gamemode).w

Level_FadeDemo:
		move.w	#60,(v_generictimer).w
		move.w	#$3F,(v_pfade_start).w
		clr.w	(PalChangeSpeed).w

Level_FDLoop:
		move.w	#Vint_Level,(v_vbla_routine).w
		bsr.w	WaitForVint
		bsr.w	MoveSonicInDemo
		jsr	(ExecuteObjects).l
		jsr	(BuildSprites).l
		jsr	(ObjectsManager).l
		subq.w	#1,(PalChangeSpeed).w
		bpl.s	loc_400E
		move.w	#2,(PalChangeSpeed).w
		bsr.w	Pal_FadeOut

loc_400E:
		tst.w	(v_generictimer).w
		bne.s	Level_FDLoop
		rts

		include	"_inc/WaterFeatures.asm"
		include "_inc/MoveSonicInDemo.asm"

; ---------------------------------------------------------------------------
; Demos - Normal gameplay & Ending
; ---------------------------------------------------------------------------
Demo_GHZ:	binclude	"demodata/WIP/Intro - GHZ.bin"
		even
Demo_CPZ:	binclude	"demodata/Intro - CPZ.bin"
		even
Demo_EHZ:	binclude	"demodata/Intro - EHZ.bin"
		even
Demo_HPZ:	binclude	"demodata/Intro - HPZ.bin"
		even
Demo_HTZ:	binclude	"demodata/Intro - HTZ.bin"
		even
; The following DEMO's are deprecated & need to be remade
Demo_EndGHZ1:	binclude	"demodata/WIP/Ending - GHZ1.bin"
		even
Demo_EndMZ:	binclude	"demodata/WIP/Ending - MZ.bin"
		even
Demo_EndSYZ:	binclude	"demodata/WIP/Ending - SYZ.bin"
		even
Demo_EndLZ:	binclude	"demodata/WIP/Ending - LZ.bin"
		even
Demo_EndSLZ:	binclude	"demodata/WIP/Ending - SLZ.bin"
		even
Demo_EndSBZ1:	binclude	"demodata/WIP/Ending - SBZ1.bin"
		even
Demo_EndSBZ2:	binclude	"demodata/WIP/Ending - SBZ2.bin"
		even
Demo_EndGHZ2:	binclude	"demodata/WIP/Ending - GHZ2.bin"
		even

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; ColIndexLoad:
LoadCollisionIndexes:
		moveq	#0,d0
		move.w	(Current_ZoneAndAct).w,d0
	;	move.w	d0,d1
	;	lsr.w	#5,d0
	;	andi.w	#$FF,d1
	;	lsl.w	#1,d1
	;	add.w	d1,d0
		ror.b	#2,d0
		lsr.w	#4,d0		; d0 = Zone*4
		moveq	#0,d1
		move.b	(Current_Timezone).w,d1		; 0 = Present, 1 = Past, 2 = Good Future, 3 = Bad Future
		lsl.w	#2,d1				; d1 *= 4 (pointer size)
		lea	(TimeZoneTable).l,a1
		movea.l	(a1,d1.w),a1			; a1 = pointer table for current timezone
		adda.l	d0,a1
		move.l	(a1),d0
		move.l	d0,(v_colladdr1).w
		addq.l	#1,d0
		move.l	d0,(v_colladdr2).w
		move.l	(v_colladdr1).w,(Collision_addr).w
		rts
; End of function LoadCollisionIndexes

; ===========================================================================
; ---------------------------------------------------------------------------
; Array of Pointer tables, per timezone.
; Time travel is yet to be added, so for now, all tables point to the same
; Pointer.
; ---------------------------------------------------------------------------
TimeZoneTable:
 if TimeTravel=1
		dc.l ColPointers	; 0 - Present
		dc.l PColPointers	; 1 - Past
		dc.l GColPointers	; 2 - Good Future
		dc.l BColPointers	; 3 - Bad Future
 else		; Main entry + 3 dummy Entries
		dc.l ColPointers	; 0 - Present
		dc.l ColPointers	; 1 - Past
		dc.l ColPointers	; 2 - Good Future
		dc.l ColPointers	; 3 - Bad Future
 endif
; ---------------------------------------------------------------------------
; Pointers to collision indexes
; Contains an array of pointers to the primary collision index data for each
; level. 1 pointer for act, pointing to an interleaved collision index.
; ---------------------------------------------------------------------------
ColPointers:
		dc.l Col_GHZ1		; act 1
		dc.l Col_GHZ2		; act 2
		dc.l Col_GHZ3		; act 3
		dc.l Col_GHZ4		; act 4
		dc.l Col_LZ1		; labyrinth zone
		dc.l Col_LZ2
		dc.l Col_LZ3
		dc.l Col_LZ4
		dc.l Col_CPZ1		; chemical plant
		dc.l Col_CPZ2
		dc.l Col_CPZ3
		dc.l Col_CPZ4
		dc.l Col_EHZ1
		dc.l Col_EHZ2
		dc.l Col_EHZ3
		dc.l Col_EHZ4
		dc.l Col_HPZ1
		dc.l Col_HPZ2
		dc.l Col_HPZ3
		dc.l Col_HPZ4
		dc.l Col_HTZ1
		dc.l Col_HTZ2
		dc.l Col_HTZ3
		dc.l Col_HTZ4
		dc.l Col_GHZ1		; Good Ending
		dc.l Col_GHZ2		; Bad Ending
 if TimeTravel=1
; ---------------------------------------------------------------------------
; Pointers to collision indexes
; Contains an array of pointers to the primary collision index data for each
; level. 1 pointer for act, pointing to an interleaved collision index.
; ---------------------------------------------------------------------------
PColPointers:
		dc.l PCol_GHZ1		; act 1
		dc.l PCol_GHZ2		; act 2
		dc.l PCol_GHZ3		; act 3
		dc.l PCol_GHZ4		; act 4
		dc.l PCol_LZ1		; labyrinth zone
		dc.l PCol_LZ2
		dc.l PCol_LZ3
		dc.l PCol_LZ4
		dc.l PCol_CPZ1		; chemical plant
		dc.l PCol_CPZ2
		dc.l PCol_CPZ3
		dc.l PCol_CPZ4
		dc.l PCol_EHZ1
		dc.l PCol_EHZ2
		dc.l PCol_EHZ3
		dc.l PCol_EHZ4
		dc.l PCol_HPZ1
		dc.l PCol_HPZ2
		dc.l PCol_HPZ3
		dc.l PCol_HPZ4
		dc.l PCol_HTZ1
		dc.l PCol_HTZ2
		dc.l PCol_HTZ3
		dc.l PCol_HTZ4
		dc.l PCol_GHZ1		; Good Ending
		dc.l PCol_GHZ2		; Bad Ending
; ---------------------------------------------------------------------------
; Pointers to collision indexes
; Contains an array of pointers to the primary collision index data for each
; level. 1 pointer for act, pointing to an interleaved collision index.
; ---------------------------------------------------------------------------
GColPointers:
		dc.l GCol_GHZ1		; act 1
		dc.l GCol_GHZ2		; act 2
		dc.l GCol_GHZ3		; act 3
		dc.l GCol_GHZ4		; act 4
		dc.l GCol_LZ1		; labyrinth zone
		dc.l GCol_LZ2
		dc.l GCol_LZ3
		dc.l GCol_LZ4
		dc.l GCol_CPZ1		; chemical plant
		dc.l GCol_CPZ2
		dc.l GCol_CPZ3
		dc.l GCol_CPZ4
		dc.l GCol_EHZ1
		dc.l GCol_EHZ2
		dc.l GCol_EHZ3
		dc.l GCol_EHZ4
		dc.l GCol_HPZ1
		dc.l GCol_HPZ2
		dc.l GCol_HPZ3
		dc.l GCol_HPZ4
		dc.l GCol_HTZ1
		dc.l GCol_HTZ2
		dc.l GCol_HTZ3
		dc.l GCol_HTZ4
		dc.l GCol_GHZ1		; Good Ending
		dc.l GCol_GHZ2		; Bad Ending
; ---------------------------------------------------------------------------
; Pointers to collision indexes
; Contains an array of pointers to the primary collision index data for each
; level. 1 pointer for act, pointing to an interleaved collision index.
; ---------------------------------------------------------------------------
BColPointers:
		dc.l BCol_GHZ1		; act 1
		dc.l BCol_GHZ2		; act 2
		dc.l BCol_GHZ3		; act 3
		dc.l BCol_GHZ4		; act 4
		dc.l BCol_LZ1		; labyrinth zone
		dc.l BCol_LZ2
		dc.l BCol_LZ3
		dc.l BCol_LZ4
		dc.l BCol_CPZ1		; chemical plant
		dc.l BCol_CPZ2
		dc.l BCol_CPZ3
		dc.l BCol_CPZ4
		dc.l BCol_EHZ1
		dc.l BCol_EHZ2
		dc.l BCol_EHZ3
		dc.l BCol_EHZ4
		dc.l BCol_HPZ1
		dc.l BCol_HPZ2
		dc.l BCol_HPZ3
		dc.l BCol_HPZ4
		dc.l BCol_HTZ1
		dc.l BCol_HTZ2
		dc.l BCol_HTZ3
		dc.l BCol_HTZ4
		dc.l BCol_GHZ1		; Good Ending
		dc.l BCol_GHZ2		; Bad Ending
 endif
		include	"_inc/Oscillatory Routines.asm"

; =============== S U B R O U T I N E =======================================


ChangeRingFrame:
		subq.b	#1,(v_ani0_time).w
		bpl.s	loc_4754
		move.b	#11,(v_ani0_time).w
		subq.b	#1,(v_ani0_frame).w
		andi.b	#7,(v_ani0_frame).w

loc_4754:
		subq.b	#1,(v_ani1_time).w
		bpl.s	loc_476A
		move.b	#7,(v_ani1_time).w
		addq.b	#1,(v_ani1_frame).w
		andi.b	#3,(v_ani1_frame).w

loc_476A:
		subq.b	#1,(v_ani2_time).w
		bpl.s	loc_4788
		move.b	#7,(v_ani2_time).w
		addq.b	#1,(v_ani2_frame).w
		cmpi.b	#6,(v_ani2_frame).w
		blo.s	loc_4788
		clr.b	(v_ani2_frame).w

loc_4788:
		tst.b	(v_ani3_time).w
		beq.s	.return
		moveq	#0,d0
		move.b	(v_ani3_time).w,d0
		add.w	(v_ani3_buf).w,d0
		move.w	d0,(v_ani3_buf).w
		rol.w	#7,d0
		andi.w	#3,d0
		move.b	d0,(v_ani3_frame).w
		subq.b	#1,(v_ani3_time).w
.return:
		rts
; End of function ChangeRingFrame


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

nosignpost macro actid
		cmpi.w	#actid,(Current_ZoneAndAct).w
		beq.ATTRIBUTE	.return	; rts
    endm

; sub_4BD2:
SetLevelEndType:
;		clr.w	(Level_Has_Signpost).w	; set level type to non-signpost
;		nosignpost.w $301	; emerald hill Act 2
;		nosignpost.w $XYY	; metropolis Act 3
;		nosignpost.w $XYY	; wing_fortress Act 1
;		nosignpost.w $502	; hill top  Act 2
;		nosignpost.w $XYY	; oil_ocean Act 2
;		nosignpost.s $XYY	; mystic cave Act 2
;		nosignpost.s $XYY	; casino night Act 2
;		nosignpost.s $XYY	; chemical plant Act 2
;		nosignpost.s $XYY	; death egg Act 1
;		nosignpost.s $XYY	; aquatic ruin Act 2
;		nosignpost.s $XYY	; sky chase Act 1
;		move.w	#1,(Level_Has_Signpost).w	; set level type to signpost
.return:
		rts
; End of function SetLevelEndType


; =============== S U B R O U T I N E =======================================


SignpostArtLoad:
		tst.w	(Debug_placement_mode).w
		bne.w	SetLevelEndType.return
		cmpi.w	#$301,(Current_ZoneAndAct).w
		beq.s	SetLevelEndType.return
		cmpi.b	#2,(Current_Act).w
		beq.s	SetLevelEndType.return
		move.w	(Camera_RAM).w,d0
		move.w	(Camera_Max_X_pos).w,d1
		subi.w	#$100,d1
		cmp.w	d1,d0
		blt.s	SetLevelEndType.return
		tst.b	(f_timecount).w
		beq.s	SetLevelEndType.return
		cmp.w	(Camera_Min_X_pos).w,d1
		beq.s	SetLevelEndType.return
		move.w	d1,(Camera_Min_X_pos).w
		moveq	#plcid_Signpost,d0
		bra.w	NewPLC
; End of function SignpostArtLoad

; ---------------------------------------------------------------------------

; ===========================================================================
; Sonic 1 Special Stage
; GameMode10:
BonusStage:
		move.w	#sfx_EnterSS,d0
		bsr.w	PlaySound_Special
		bsr.w	Pal_MakeFlash
		disable_ints
		lea	(vdp_control_port).l,a6
		move.w	#$8B03,(a6)	; line scroll mode
		move.w	#$8004,(a6)	; 8-colour mode
		move.w	#$8A00+175,(v_hbla_hreg).w
		move.w	#$9011,(a6)
		move.w	(v_vdp_buffer1).w,d0
		andi.b	#$BF,d0
		move.w	d0,(vdp_control_port).l
		ResetDMAQueue
		bsr.w	ClearScreen
		enable_ints
		fillVRAM	0, ArtTile_SS_Plane_1*tile_size+plane_size_64x32, ArtTile_SS_Plane_5*tile_size
		bsr.w	S1_SSBGLoad
	;	moveq	#plcid_SpecialStage,d0
		lea	(PLC_S1SpecialStage).l,a1
		bsr.w	QuickPLC
		clearRAM v_objspace,v_objend
		clearRAM v_levelvariables,v_levelvariables_end
		clearRAM v_timingvariables,v_timingvariables_end
		clearRAM v_ngfx_buffer,v_ngfx_buffer_end
		sf	(f_wtr_state).w
		clr.w	(Level_Inactive_flag).w
		moveq	#palid_Special,d0
		bsr.w	PalLoad1		; load special stage palette
		bsr.w	BonusStage_Load		; load SS layout data
		clr.l	(Camera_X_pos).w
		clr.l	(Camera_Y_pos).w
		move.b	#id_Obj04,(v_player).w ; load special stage Sonic object
		bsr.w	PalCycle_S1SS
		clr.w	(v_ssangle).l	; set stage angle to "upright"
		move.w	#$40,(v_ssrotate).l ; set stage rotation speed
		move.w	#bgm_SS,d0
		bsr.w	PlaySound	; play special stage BG	music
		clr.w	(v_rings).w
		clr.b	(v_lifecount).w
;		move.w	#100,(v_ring1uplimit).w	; TODO: IMPLEMENT reset ring 1-up flag
		clr.w	(Debug_placement_mode).w
		move.w	#60*30,(v_generictimer).w
		tst.b	(f_debugcheat).w ; has debug cheat been entered?
		beq.s	SS_NoDebug	; if not, branch
		btst	#bitA,(v_jpadhold1).w ; is A button pressed?
		beq.s	SS_NoDebug	; if not, branch
		move.b	#1,(Debug_mode_flag).w ; enable debug mode

SS_NoDebug:
		move.w	(v_vdp_buffer1).w,d0
		ori.b	#$40,d0
		move.w	d0,(vdp_control_port).l
		bsr.w	Pal_MakeWhite

; ---------------------------------------------------------------------------
; Main Special Stage loop
; ---------------------------------------------------------------------------

SS_MainLoop:
		bsr.w	PauseGame
		move.w	#Vint_S1SS,(v_vbla_routine).w
		bsr.w	WaitForVint
		move.w	(v_jpadhold1).w,(v_jpadholdlogical).w
		jsr	(ExecuteObjects).l
		jsr	(BuildSprites).l
		bsr.w	S1SS_ShowLayout
		bsr.w	S1SS_BgAnimate
		cmpi.w	#BonusStage,(v_gamemode).w ; is game mode $10 (special stage)?
		beq.w	SS_MainLoop	; if yes, branch
		move.w	#Level,(v_gamemode).w ; set screen mode to $0C (level)
		cmpi.w	#(id_SBZ<<8)+3,(Current_ZoneAndAct).w ; is level number higher than FZ?
		blo.s	SS_Finish	; if not, branch
		clr.w	(Current_ZoneAndAct).w	; set to GHZ1

SS_Finish:
		move.w	#60,(v_generictimer).w ; set delay time to 1 second
		move.w	#$3F,(v_pfade_start).w
		clr.w	(PalChangeSpeed).w

SS_FinLoop:
		move.w	#Vint_SSResults,(v_vbla_routine).w
		bsr.w	WaitForVint
		jsr	(ExecuteObjects).l
		jsr	(BuildSprites).l
		bsr.w	S1SS_ShowLayout
		bsr.w	S1SS_BgAnimate
		subq.w	#1,(PalChangeSpeed).w
		bpl.s	loc_5214
		move.w	#2,(PalChangeSpeed).w
		bsr.w	Pal_ToWhite

loc_5214:
		tst.w	(v_generictimer).w
		bne.s	SS_FinLoop
		disable_ints
		lea	(vdp_control_port).l,a6
		move.w	#$8200+(vram_fg>>10),(a6) ; set foreground nametable address
		move.w	#$8400+(vram_bg>>13),(a6) ; set background nametable address
		move.w	#$9001,(a6)
		bsr.w	ClearScreen
		locVRAM	ArtTile_Title_Card*tile_size
		lea	(Nem_TitleCard).l,a0	; load title card patterns
		bsr.w	NemDec
		jsr	(HUD_Base).l
		ResetDMAQueue
		enable_ints
		moveq	#palid_SSResult,d0
		bsr.w	PalLoad2		; load results screen palette
		moveq	#plcid_Main,d0
		bsr.w	NewPLC
		moveq	#plcid_SSResult,d0
		bsr.w	LoadPLC			; load results screen patterns
		lea	(PLCKosM_SSResult).l,a6
		bsr.w	QuickKosPLC
		move.b	#1,(f_scorecount).w	; update score counter
		move.b	#1,(f_endactbonus).w	; update ring bonus counter
		move.w	(v_rings).w,d0
		move.w	d0,d1			; multiply rings by 10
		lsl.w	#3,d0
		add.w	d1,d0
		add.w	d1,d0
		move.w	d0,(v_ringbonus).w	; set rings bonus
		move.w	#bgm_GotThrough,d0
		jsr	(PlaySound_Special).l	; play end-of-level music
		clearRAM v_objspace,v_objend	; clear object RAM
		_move.b	#id_Obj96,(v_endcard).w	; load results screen object

SS_NormalExit:
		bsr.w	PauseGame
		move.w	#Vint_TitleCard,(v_vbla_routine).w
		bsr.w	WaitForVint
		bsr.w	Process_Kos_Queue
		jsr	(ExecuteObjects).l
		jsr	(BuildSprites).l
		bsr.w	RunPLC_RAM
		bsr.w	Process_Kos_Module_Queue
		tst.w	(Level_Inactive_flag).w
		beq.s	SS_NormalExit
		tst.l	(v_plc_buffer).w
		bne.s	SS_NormalExit
		move.w	#sfx_EnterSS,d0
		bsr.w	PlaySound_Special
		bra.w	Pal_MakeFlash
; ---------------------------------------------------------------------------
; Special stage	background loading subroutine
; ---------------------------------------------------------------------------

; =============== S U B R O U T I N E =======================================


S1_SSBGLoad:
		lea	(v_ssbuffer1).l,a1
		lea	(Eni_BSBg1).l,a0 ; load	mappings for the birds and fish
		move.w	#make_art_tile(ArtTile_SS_Background_Fish,2,0),d0
		bsr.w	EniDec
		locVRAM	ArtTile_SS_Plane_1*tile_size+plane_size_64x32,d3
		lea	(v_ssbuffer1+$80).l,a2
		moveq	#7-1,d7

loc_5302:
		move.l	d3,d0
		moveq	#4-1,d6
		moveq	#0,d4
		cmpi.w	#3,d7
		bhs.s	loc_5310
		moveq	#1,d4

loc_5310:
		moveq	#8-1,d5

loc_5312:
		movea.l	a2,a1
		eori.b	#1,d4
		bne.s	loc_5326
		cmpi.w	#6,d7
		bne.s	loc_5336
		lea	(v_ssbuffer1).l,a1

loc_5326:
		movem.l	d0-d4,-(sp)
		moveq	#8-1,d1
		moveq	#8-1,d2
		bsr.w	PlaneMapToVRAM_H40
		movem.l	(sp)+,d0-d4

loc_5336:
		addi.l	#$100000,d0
		dbf	d5,loc_5312
		addi.l	#$3800000,d0
		eori.b	#1,d4
		dbf	d6,loc_5310
		addi.l	#$10000000,d3
		bpl.s	loc_5360
		swap	d3
		addi.l	#$C000,d3
		swap	d3

loc_5360:
		adda.w	#$80,a2
		dbf	d7,loc_5302
		lea	(v_ssbuffer1).l,a1
		lea	(Eni_BSBg2).l,a0 ; load	mappings for the clouds
		move.w	#make_art_tile(ArtTile_SS_Background_Clouds,2,0),d0
		bsr.w	EniDec
		copyTilemap	v_ssbuffer1,ArtTile_SS_Plane_5*tile_size,64,32
		lea	(v_ssbuffer1).l,a1
		locVRAM	ArtTile_SS_Plane_5*tile_size+plane_size_64x32,d0
		moveq	#64-1,d1
		moveq	#64-1,d2
		bra.w	PlaneMapToVRAM_H40
; End of function S1_SSBGLoad

; ---------------------------------------------------------------------------
; Palette cycling routine - special stage
; ---------------------------------------------------------------------------

; =============== S U B R O U T I N E =======================================


PalCycle_S1SS:
		tst.w	(f_pause).w
		bne.s	locret_5424
		subq.w	#1,(v_palbs_time).w
		bpl.s	locret_5424
		lea	(vdp_control_port).l,a6
		move.w	(v_palbs_num).w,d0
		addq.w	#1,(v_palbs_num).w
		andi.w	#$1F,d0
		lsl.w	#2,d0
		lea	(word_547A).l,a0
		adda.w	d0,a0
		move.b	(a0)+,d0
		bpl.s	loc_53D0
		move.w	#$1FF,d0

loc_53D0:
		move.w	d0,(v_palbs_time).w
		moveq	#0,d0
		move.b	(a0)+,d0
		move.w	d0,(v_bsbganim).w
		lea	(word_54FA).l,a1
		lea	(a1,d0.w),a1
		move.w	#$8200,d0
		move.b	(a1)+,d0
		move.w	d0,(a6)
		move.b	(a1),(v_scrposy_vdp).w
		move.w	#$8400,d0
		move.b	(a0)+,d0
		move.w	d0,(a6)
		move.l	#$40000010,(vdp_control_port).l
		move.l	(v_scrposy_vdp).w,(vdp_data_port).l
		moveq	#0,d0
		move.b	(a0)+,d0
		bmi.s	loc_5426
		lea	Pal_S1SSCyc1(pc),a1
		adda.w	d0,a1
		lea	(v_palette+$4E).w,a2
		move.l	(a1)+,(a2)+
		move.l	(a1)+,(a2)+
		move.l	(a1)+,(a2)+

locret_5424:
		rts
; ---------------------------------------------------------------------------

loc_5426:
		clr.w	d1
		cmpi.w	#$8A,d0
		blo.s	loc_5432
		addq.w	#1,d1

loc_5432:
		moveq	#0,d2
		move.w	d1,d2
		move.w	d1,d3
		lsl.w	#5,d1
		lsl.w	#3,d2
		add.w	d2,d1
		add.w	d3,d1
		add.w	d3,d1
		lea	Pal_S1SSCyc2(pc),a1
		adda.w	d1,a1
		andi.w	#$7F,d0
		bclr	#0,d0
		beq.s	loc_5456
		lea	(v_palette+$6E).w,a2
		move.l	(a1),(a2)+
		move.l	4(a1),(a2)+
		move.l	8(a1),(a2)+

loc_5456:
		adda.w	#$C,a1
		lea	(v_palette+$5A).w,a2
		cmpi.w	#$A,d0
		blo.s	loc_546C
		subi.w	#$A,d0
		lea	(v_palette+$7A).w,a2

loc_546C:
		move.w	d0,d1
		add.w	d0,d0
		add.w	d1,d0
		adda.w	d0,a1
		move.l	(a1)+,(a2)+
		move.w	(a1)+,(a2)+
		rts
; End of function PalCycle_S1SS

; ---------------------------------------------------------------------------
SSBGData:	macro time,anim,vram,index,flag1,flag2
		dc.b	(time), (anim), ((vram)*tile_size)>>13
	if flag1
		dc.b	(index)|$80|(flag2)
	else
		dc.b	(index)*12
	endif
		endm

word_547A:
		; Time, anim, BG VRAM, palette cycle index & flags
		SSBGData  3,  0, ArtTile_SS_Plane_6, 18, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_6, 16, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_6, 14, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_6, 12, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_6, 10, TRUE , TRUE

		SSBGData  3,  0, ArtTile_SS_Plane_6,  0, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_6,  2, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_6,  4, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_6,  6, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_6,  8, TRUE , FALSE

		SSBGData  7,  8, ArtTile_SS_Plane_6,  0, FALSE, FALSE
		SSBGData  7, 10, ArtTile_SS_Plane_6,  1, FALSE, FALSE
		SSBGData -1, 12, ArtTile_SS_Plane_6,  2, FALSE, FALSE
		SSBGData -1, 12, ArtTile_SS_Plane_6,  2, FALSE, FALSE
		SSBGData  7, 10, ArtTile_SS_Plane_6,  1, FALSE, FALSE
		SSBGData  7,  8, ArtTile_SS_Plane_6,  0, FALSE, FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_5,  8, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_5,  6, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_5,  4, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_5,  2, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_5,  0, TRUE , TRUE

		SSBGData  3,  0, ArtTile_SS_Plane_5, 10, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_5, 12, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_5, 14, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_5, 16, TRUE , FALSE
		SSBGData  3,  0, ArtTile_SS_Plane_5, 18, TRUE , FALSE

		SSBGData  7,  2, ArtTile_SS_Plane_5,  3, FALSE, FALSE
		SSBGData  7,  4, ArtTile_SS_Plane_5,  4, FALSE, FALSE
		SSBGData -1,  6, ArtTile_SS_Plane_5,  5, FALSE, FALSE
		SSBGData -1,  6, ArtTile_SS_Plane_5,  5, FALSE, FALSE
		SSBGData  7,  4, ArtTile_SS_Plane_5,  4, FALSE, FALSE
		SSBGData  7,  2, ArtTile_SS_Plane_5,  3, FALSE, FALSE
		even

SSFGData:	macro vram,y
		dc.b ((vram)*tile_size)>>10, (y)>>8
		endm

word_54FA:
		; FG VRAM, Y coordinate
		SSFGData ArtTile_SS_Plane_1, $100
		SSFGData ArtTile_SS_Plane_2,    0
		SSFGData ArtTile_SS_Plane_2, $100
		SSFGData ArtTile_SS_Plane_3,    0
		SSFGData ArtTile_SS_Plane_3, $100
		SSFGData ArtTile_SS_Plane_4,    0
		SSFGData ArtTile_SS_Plane_4, $100
		even

Pal_S1SSCyc1:	binclude	"palette/Cycle - Special Stage 1.bin"
		even
Pal_S1SSCyc2:	binclude	"palette/Cycle - Special Stage 2.bin"
		even

; ---------------------------------------------------------------------------
; Subroutine to	make the special stage background animated
; ---------------------------------------------------------------------------

; =============== S U B R O U T I N E =======================================


S1SS_BgAnimate:
		move.w	(v_bsbganim).w,d0
		bne.s	loc_5634
		clr.w	(Camera_BG_Y_pos).w
		move.w	(Camera_BG_Y_pos).w,(v_bgscrposy_vdp).w

loc_5634:
		cmpi.w	#8,d0
		bhs.s	loc_568C
		cmpi.w	#6,d0
		bne.s	loc_564E
		addq.w	#1,(Camera_BG3_X_pos).w
		addq.w	#1,(Camera_BG_Y_pos).w
		move.w	(Camera_BG_Y_pos).w,(v_bgscrposy_vdp).w

loc_564E:
		lea	byte_5709(pc),a1
		lea	(v_ngfx_buffer).w,a3
		moveq	#10-1,d3

loc_5664:
		move.w	2(a3),d0
		bsr.w	CalcSine
		move.w	(a1)+,d2
		muls.w	d0,d2
		swap	d2
		move.w	d2,(a3)+
		move.w	(a1)+,d2
		add.w	d2,(a3)+
		dbf	d3,loc_5664
		lea	(v_ngfx_buffer).w,a3
		lea	byte_56F6(pc),a2
		bra.s	loc_56BC
; ---------------------------------------------------------------------------

loc_568C:
		cmpi.w	#$C,d0
		bne.s	loc_56B2
		subq.w	#1,(Camera_BG3_X_pos).w
		lea	(v_ssscroll_buffer).l,a3
		move.l	#$18000,d2
		moveq	#7-1,d1

loc_56A2:
		move.l	(a3),d0
		sub.l	d2,d0
		move.l	d0,(a3)+
		subi.l	#$2000,d2
		dbf	d1,loc_56A2

loc_56B2:
		lea	(v_ssscroll_buffer).l,a3
		lea	byte_5701(pc),a2

loc_56BC:
		lea	(v_hscrolltablebuffer).w,a1
		move.w	(Camera_BG3_X_pos).w,d0
		neg.w	d0
		swap	d0
		moveq	#0,d3
		move.b	(a2)+,d3
		move.w	(Camera_BG_Y_pos).w,d2
		neg.w	d2
		andi.w	#$FF,d2
		add.w	d2,d2
		add.w	d2,d2

loc_56D8:
		move.w	(a3),d0
		addq.w	#4,a3
		moveq	#0,d1
		move.b	(a2)+,d1
		subq.w	#1,d1

loc_56E2:
		move.l	d0,(a1,d2.w)
		addq.w	#4,d2
		andi.w	#$3FC,d2
		dbf	d1,loc_56E2
		dbf	d3,loc_56D8
		rts
; End of function S1SS_BgAnimate

; ---------------------------------------------------------------------------
byte_56F6:				; SStage_Scroll_Buffer2
		dc.b 9, $28		; d3, d1
		dc.b $18, $10
		dc.b $28, $18
		dc.b $10, $30
		dc.b $18, 8
		dc.b $10, 0
byte_5701:				; SStage_Scroll_Buffer
		dc.b 6, $30		; d3, d1
		dc.b $30, $30
		dc.b $28, $18
		dc.b $18, $18
byte_5709:
		dc.w $800, 2		; sin, cos
		dc.w $400, -1
		dc.w $200, 3
		dc.w $800, -1
		dc.w $400, 2
		dc.w $200, 3
		dc.w $800, -3
		dc.w $400, 2
		dc.w $200, 3
		dc.w $200, -1
; ---------------------------------------------------------------------------
; New Subroutine to show the bonus stage layout
; Uses S3&K mapping format, except as dc.b instead of dc.w
; ---------------------------------------------------------------------------

; =============== S U B R O U T I N E =======================================

BS_ShowLayout:
		bsr.w	SS_AniWallsRings
		bsr.w	SS_AniItems
; Calculate x/y positions of each cell in a 16x16 grid when rotated
		lea	(v_ssbuffer3).l,a1		; address to write grid coords
		move.b	(v_ssangle).l,d0
		bsr.w	CalcSine			; convert to sine/cosine
		move.w	d0,d4
		move.w	d1,d5
		muls.w	#$18,d4				; ss_block_width
		muls.w	#$18,d5				; ss_block_width
		moveq	#0,d2
		move.w	(Camera_X_pos).w,d2
		divu.w	#$18,d2
		swap	d2
		neg.w	d2
		subi.w	#$B4,d2
		moveq	#0,d3
		move.w	(Camera_Y_pos).w,d3
		divu.w	#$18,d3
		swap	d3
		neg.w	d3
		subi.w	#$B4,d3
		moveq	#$10-1,d7			; grid is 16 cells high

.loop_gridrow:
		movem.w	d0-d2,-(sp)
		movem.w	d0-d1,-(sp)
		neg.w	d0
		muls.w	d2,d1
		muls.w	d3,d0
		move.l	d0,d6
		add.l	d1,d6
		movem.w	(sp)+,d0/d1
		muls.w	d2,d0
		muls.w	d3,d1
		add.l	d0,d1
		move.l	d6,d2
		moveq	#$10-1,d6			; grid is 16 cells wide

.loop_gridcell:
		move.l	d2,d0
		asr.l	#8,d0
		move.w	d0,(a1)+
		move.l	d1,d0
		asr.l	#8,d0
		move.w	d0,(a1)+
		add.l	d5,d2
		add.l	d4,d1
		dbf	d6,.loop_gridcell		; repeat for all cells in row
		movem.w	(sp)+,d0-d2
		addi.w	#$18,d3
		dbf	d7,.loop_gridrow		; repeat for all rows

; Populate the 16x16 grid with sprites based on the level layout
		lea	(v_ssbuffer1).l,a0
		moveq	#0,d0
		move.w	(Camera_Y_pos).w,d0		; get camera y pos
		divu.w	#$18,d0				; divide by size of wall sprite (24 pixels)
		lsl.w	#7,d0				; multiply by width of level ($80)
		ext.l	d0
		adda.l	d0,a0				; jump to correct row in level
		moveq	#0,d0
		move.w	(Camera_X_pos).w,d0		; get camera x pos
		divu.w	#$18,d0				; divide by size of wall sprite (24 pixels)
		adda.w	d0,a0				; jump to correct block in level
		lea	(v_ssbuffer2).l,a2		; t2ansformation grid
		lea	v_ssbuffer3-v_ssbuffer2(a2),a1	; load object xypos
		lea	(Sprite_Table).w,a6		; the following commented out code was added in S3&K
		moveq	#80-1,d7			; max sprites
		moveq	#0,d6
		move.b	(v_spritecount).w,d6	; Sprites_drawn in S3&K
		sub.b	d6,d7
		lsl.w	#3,d6
		adda.w	d6,a6
		moveq	#$10-1,d2

.levelloop:
		moveq	#$10-1,d3

.objloop:
		moveq	#0,d0
		move.b	(a0)+,d0			; get level block
		beq.s	.nextlevel			; skip if 0 (blank)
		cmpi.b	#$4E,d0				; in S3K, since there's less blocks, this becomes $13 (decimal 19)
		bhi.s	.nextlevel			; ...or if above $4E (decimal 78) (invalid)

		move.w	(a1),d4				; get grid x pos
		addi.w	#288,d4
		cmpi.w	#112,d4
		blo.s	.nextlevel			; branch if off screen
		cmpi.w	#464,d4
		bhs.s	.nextlevel

		move.w	2(a1),d5			; get grid y pos
		addi.w	#240,d5
		cmpi.w	#112,d5
		blo.s	.nextlevel
		cmpi.w	#368,d5
		bhs.s	.nextlevel

		lsl.w	#3,d0
		lea	(a2,d0.w),a4
		movea.l	(a4)+,a3			; get mappings pointer
		move.w	(a4)+,d6			; get frame id
		add.w	d6,d6
		adda.w	(a3,d6.w),a3			; apply frame id to mappings pointer
		move.w	(a4),d6				; VRAM
		move.w	(a3)+,d1			; number of sprite pieces
		subq.w	#1,d1				; "
		bmi.s	.nextlevel			; if there are 0 pieces, branch

.setmap:
		move.b	(a3)+,d0			; get y-offset
		ext.w	d0				; byte to word
		add.w	d5,d0				; add y-position
		move.w	d0,(a6)+			; write to buffer
		move.b	(a3)+,(a6)+			; write sprite size
		addq.w	#1,a6				; skip sprite link
		move.w	(a3)+,d0			; get art tile
		add.w	d6,d0				; add art tile offset
		move.w	d0,(a6)+			; write to buffer
		move.w	(a3)+,d0			; get x-offset
		add.w	d4,d0				; add x-position
		andi.w	#$1FF,d0			; keep within 512px
		bne.s	.writeX
		addq.w	#1,d0

.writeX:
		move.w	d0,(a6)+			; write to buffer
		subq.w	#1,d7				; decrease sprite counter
		dbmi	d1,.setmap			; process next sprite piece
		bmi.s	.finish

.nextlevel:
		addq.w	#4,a1				; next object xypos
		dbf	d3,.objloop
		lea	$70(a0),a0
		dbf	d2,.levelloop

.finish:
		move.w	d7,d6
		bmi.s	.end
		moveq	#0,d0

.clear:
		move.w	d0,(a6)
		addq.w	#8,a6
		dbf	d7,.clear

.end:
		subi.w	#80-1,d6
		neg.w	d6
		move.b	d6,(v_spritecount).w
		rts
; End of function BS_ShowLayout
; ---------------------------------------------------------------------------
; New Subroutine to show the special stage layout
; ---------------------------------------------------------------------------

; =============== S U B R O U T I N E =======================================

S1SS_ShowLayout:
		bsr.w	SS_AniWallsRings
		bsr.w	SS_AniItems
; Calculate x/y positions of each cell in a 16x16 grid when rotated
		move.w	d5,-(sp)			; save sprite count to stack	; S3&K removes this
		lea	(v_ssbuffer3).l,a1		; address to write grid coords
		move.b	(v_ssangle).l,d0
		jsr	(CalcSine).l			; convert to sine/cosine
		move.w	d0,d4
		move.w	d1,d5
		muls.w	#$18,d4				; ss_block_width
		muls.w	#$18,d5				; ss_block_width
		moveq	#0,d2
		move.w	(Camera_X_pos).w,d2
		divu.w	#$18,d2
		swap	d2
		neg.w	d2
		subi.w	#$B4,d2
		moveq	#0,d3
		move.w	(Camera_Y_pos).w,d3
		divu.w	#$18,d3
		swap	d3
		neg.w	d3
		subi.w	#$B4,d3
		moveq	#$10-1,d7			; grid is 16 cells high

.loop_gridrow:
		movem.w	d0-d2,-(sp)
		movem.w	d0-d1,-(sp)
		neg.w	d0
		muls.w	d2,d1
		muls.w	d3,d0
		move.l	d0,d6
		add.l	d1,d6
		movem.w	(sp)+,d0/d1
		muls.w	d2,d0
		muls.w	d3,d1
		add.l	d0,d1
		move.l	d6,d2
		moveq	#$10-1,d6			; grid is 16 cells wide

.loop_gridcell:
		move.l	d2,d0
		asr.l	#8,d0
		move.w	d0,(a1)+
		move.l	d1,d0
		asr.l	#8,d0
		move.w	d0,(a1)+
		add.l	d5,d2
		add.l	d4,d1
		dbf	d6,.loop_gridcell		; repeat for all cells in row
		movem.w	(sp)+,d0-d2
		addi.w	#$18,d3
		dbf	d7,.loop_gridrow		; repeat for all rows

; Populate the 16x16 grid with sprites based on the level layout
		move.w	(sp)+,d5		; S3&K removes this
		lea	(v_ssbuffer1).l,a0
		moveq	#0,d0
		move.w	(Camera_Y_pos).w,d0		; get camera y pos
		divu.w	#$18,d0				; divide by size of wall sprite (24 pixels)
		lsl.w	#7,d0				; multiply by width of level ($80)
		ext.l	d0
		adda.l	d0,a0				; jump to correct row in level
		moveq	#0,d0
		move.w	(Camera_X_pos).w,d0		; get camera x pos
		divu.w	#$18,d0				; divide by size of wall sprite (24 pixels)
		adda.w	d0,a0				; jump to correct block in level
		lea	(v_ssbuffer3).l,a4		; transformation grid
;		lea	(Sprite_Table).w,a2		; the following commented out code was added in S3&K
;		moveq	#0,d5
;		move.b	(v_spritecount).w,d5	; Sprites_drawn in S3&K
;		move.w	d5,d0
;		lsl.w	#3,d0
;		adda.w	d0,a2
		moveq	#$10-1,d7

ssloop_spriterow:
		moveq	#$10-1,d6

ssloop_sprite:
		moveq	#0,d0
		move.b	(a0)+,d0			; get level block
		beq.s	.loc_19C9A			; skip if 0 (blank)
		cmpi.b	#$4E,d0				; in S3K, since there's less blocks, this becomes $13 (decimal 19)
		bhi.s	.loc_19C9A			; ...or if above $4E (decimal 78) (invalid)
		move.w	(a4),d3				; get grid x pos
		addi.w	#288,d3
		cmpi.w	#112,d3
		blo.s	.loc_19C9A			; branch if off screen
		cmpi.w	#464,d3
		bhs.s	.loc_19C9A
		move.w	2(a4),d2			; get grid y pos
		addi.w	#240,d2
		cmpi.w	#112,d2
		blo.s	.loc_19C9A
		cmpi.w	#368,d2
		bhs.s	.loc_19C9A
		lea	(v_ssbuffer2).l,a5
		lsl.w	#3,d0
		lea	(a5,d0.w),a5
		movea.l	(a5)+,a1			; get mappings pointer
		move.w	(a5)+,d1			; get frame id
		add.w	d1,d1
		adda.w	(a1,d1.w),a1			; apply frame id to mappings pointer
		movea.w	(a5)+,a3			; get tile id
		moveq	#0,d1
		move.b	(a1)+,d1			; get number of sprite pieces from mappings
		subq.b	#1,d1				; branch if 0
		bmi.s	.loc_19C9A			; build sprites from mappings

.BuildSprites_Special:
		cmpi.b	#$50,d5				; check sprite limit
		beq.s	.loc_19C9A
		move.b	(a1)+,d0			; get y-offset
		ext.w	d0
		add.w	d2,d0				; add y-position
		move.w	d0,(a2)+			; write to buffer
		move.b	(a1)+,(a2)+			; write sprite size
		addq.b	#1,d5				; increase sprite counter
;		addq.w	#1,a2			; set as sprite link (S3&K method)
		move.b	d5,(a2)+			; set as sprite link
		move.b	(a1)+,d0			; get art tile
		lsl.w	#8,d0
		move.b	(a1)+,d0
		add.w	a3,d0				; add art tile offset
		move.w	d0,(a2)+			; write to buffer
		move.b	(a1)+,d0			; get x-offset
		ext.w	d0
		add.w	d3,d0				; add x-position
		andi.w	#$1FF,d0			; keep within 512px
		bne.s	.writeX
		addq.w	#1,d0

.writeX:
		move.w	d0,(a2)+
		dbf	d1,.BuildSprites_Special

.loc_19C9A:
		addq.w	#4,a4				; next sprite
		dbf	d6,ssloop_sprite
		lea	$70(a0),a0			; next row
		dbf	d7,ssloop_spriterow
		move.b	d5,(v_spritecount).w
		cmpi.b	#$50,d5				; max number of sprites ($50)
		beq.s	.spritelimit			; branch if at limit
		clr.l	(a2)
		rts
; ---------------------------------------------------------------------------

.spritelimit:
		clr.b	-5(a2)
		rts
; End of function S1SS_ShowLayout

; ---------------------------------------------------------------------------
; Subroutine to	animate	walls and rings	in the special stage
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


SS_AniWallsRings:
		lea	(v_ssbuffer2+$C).l,a1
		moveq	#0,d0
		move.b	(v_ssangle).l,d0
		lsr.b	#2,d0
		andi.w	#$F,d0
		moveq	#$23,d1

-		move.w	d0,(a1)
		addq.w	#8,a1
		dbf	d1,-
		lea	(v_ssbuffer2+5).l,a1
		subq.b	#1,(v_ani1_time).w
		bpl.s	loc_19CFA
		move.b	#7,(v_ani1_time).w
		addq.b	#1,(v_ani1_frame).w
		andi.b	#3,(v_ani1_frame).w

loc_19CFA:
		move.b	(v_ani1_frame).w,$1D0(a1)
		subq.b	#1,(v_ani2_time).w
		bpl.s	loc_19D16
		move.b	#7,(v_ani2_time).w
		addq.b	#1,(v_ani2_frame).w
		andi.b	#1,(v_ani2_frame).w

loc_19D16:
		move.b	(v_ani2_frame).w,d0
		move.b	d0,$138(a1)
		move.b	d0,$160(a1)
		move.b	d0,$148(a1)
		move.b	d0,$150(a1)
		move.b	d0,$1D8(a1)
		move.b	d0,$1E0(a1)
		move.b	d0,$1E8(a1)
		move.b	d0,$1F0(a1)
		move.b	d0,$1F8(a1)
		move.b	d0,$200(a1)
		subq.b	#1,(v_ani3_time).w
		bpl.s	loc_19D58
		move.b	#4,(v_ani3_time).w
		addq.b	#1,(v_ani3_frame).w
		andi.b	#3,(v_ani3_frame).w

loc_19D58:
		move.b	(v_ani3_frame).w,d0
		move.b	d0,$168(a1)
		move.b	d0,$170(a1)
		move.b	d0,$178(a1)
		move.b	d0,$180(a1)
		subq.b	#1,(v_ani0_time).w
		bpl.s	loc_19D82
		move.b	#7,(v_ani0_time).w
		subq.b	#1,(v_ani0_frame).w
		andi.b	#7,(v_ani0_frame).w

loc_19D82:
		lea	(v_ssbuffer2+$16).l,a1
		lea	(S1SS_WaRiVramSet).l,a0
		moveq	#0,d0
		move.b	(v_ani0_frame).w,d0
		add.w	d0,d0
		lea	(a0,d0.w),a0
		move.w	(a0),(a1)
		move.w	2(a0),8(a1)
		move.w	4(a0),$10(a1)
		move.w	6(a0),$18(a1)
		move.w	8(a0),$20(a1)
		move.w	$A(a0),$28(a1)
		move.w	$C(a0),$30(a1)
		move.w	$E(a0),$38(a1)
		adda.w	#$20,a0
		adda.w	#$48,a1
		move.w	(a0),(a1)
		move.w	2(a0),8(a1)
		move.w	4(a0),$10(a1)
		move.w	6(a0),$18(a1)
		move.w	8(a0),$20(a1)
		move.w	$A(a0),$28(a1)
		move.w	$C(a0),$30(a1)
		move.w	$E(a0),$38(a1)
		adda.w	#$20,a0
		adda.w	#$48,a1
		move.w	(a0),(a1)
		move.w	2(a0),8(a1)
		move.w	4(a0),$10(a1)
		move.w	6(a0),$18(a1)
		move.w	8(a0),$20(a1)
		move.w	$A(a0),$28(a1)
		move.w	$C(a0),$30(a1)
		move.w	$E(a0),$38(a1)
		adda.w	#$20,a0
		adda.w	#$48,a1
		move.w	(a0),(a1)
		move.w	2(a0),8(a1)
		move.w	4(a0),$10(a1)
		move.w	6(a0),$18(a1)
		move.w	8(a0),$20(a1)
		move.w	$A(a0),$28(a1)
		move.w	$C(a0),$30(a1)
		move.w	$E(a0),$38(a1)
		adda.w	#$20,a0
		adda.w	#$48,a1
		rts
; End of function SS_AniWallsRings

; ---------------------------------------------------------------------------
S1SS_WaRiVramSet:
		dc.w $0142, $6142, $0142, $0142, $0142, $0142, $0142, $6142
		dc.w $0142, $6142, $0142, $0142, $0142, $0142, $0142, $6142
		dc.w $2142, $0142, $2142, $2142, $2142, $2142, $2142, $0142
		dc.w $2142, $0142, $2142, $2142, $2142, $2142, $2142, $0142
		dc.w $4142, $2142, $4142, $4142, $4142, $4142, $4142, $2142
		dc.w $4142, $2142, $4142, $4142, $4142, $4142, $4142, $2142
		dc.w $6142, $4142, $6142, $6142, $6142, $6142, $6142, $4142
		dc.w $6142, $4142, $6142, $6142, $6142, $6142, $6142, $4142
		even
; ---------------------------------------------------------------------------
; Subroutine to	remove items when you collect them in the special stage
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


SS_RemoveCollectedItem:
		lea	(v_ssitembuffer).l,a2
		move.w	#(v_ssitembuffer_end-v_ssitembuffer)/8-1,d0

.loop:
		tst.b	(a2)
		beq.s	.return
		addq.w	#8,a2
		dbf	d0,.loop

.return:
		rts
; End of function SS_RemoveCollectedItem

; ---------------------------------------------------------------------------
; Subroutine to	animate	special	stage items when you touch them
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


SS_AniItems:
		lea	(v_ssitembuffer).l,a0
		move.w	#(v_ssitembuffer_end-v_ssitembuffer)/8-1,d7

.loop:
		moveq	#0,d0
		move.b	(a0),d0
		beq.s	.no_update
		lsl.w	#2,d0
		movea.l	S1SS_AniIndex-4(pc,d0.w),a1
		jsr	(a1)

.no_update:
		addq.w	#8,a0
		dbf	d7,.loop
.return:	rts
; End of function SS_AniItems

; ---------------------------------------------------------------------------
S1SS_AniIndex:
		dc.l SS_AniRingSparks
		dc.l SS_AniBumper
		dc.l SS_Ani1Up
		dc.l SS_AniReverse
		dc.l SS_AniEmeraldSparks
		dc.l SS_AniGlassBlock
; ---------------------------------------------------------------------------

SS_AniRingSparks:
		subq.b	#1,2(a0)
		bpl.s	SS_AniItems.return
		move.b	#5,2(a0)
		moveq	#0,d0
		move.b	3(a0),d0
		addq.b	#1,3(a0)
		movea.l	4(a0),a1
		move.b	SS_AniRingData(pc,d0.w),d0
		move.b	d0,(a1)
		bne.s	SS_AniItems.return
		clr.l	(a0)
		clr.l	4(a0)
		rts
; ---------------------------------------------------------------------------
SS_AniRingData:	dc.b $42, $43, $44, $45, 0
		even
; ---------------------------------------------------------------------------

SS_AniBumper:
		subq.b	#1,2(a0)
		bpl.s	SS_AniItems.return
		move.b	#7,2(a0)
		moveq	#0,d0
		move.b	3(a0),d0
		addq.b	#1,3(a0)
		movea.l	4(a0),a1
		move.b	SS_AniBumpData(pc,d0.w),d0
		bne.s	SS_AniReverse.update
		clr.l	(a0)
		clr.l	4(a0)
		move.b	#$25,(a1)
		rts
; ---------------------------------------------------------------------------
SS_AniBumpData:	dc.b $32, $33, $32, $33, 0
		even
; ---------------------------------------------------------------------------

SS_Ani1Up:
		subq.b	#1,2(a0)
		bpl.s	SS_AniReverse.return
		move.b	#5,2(a0)
		moveq	#0,d0
		move.b	3(a0),d0
		addq.b	#1,3(a0)
		movea.l	4(a0),a1
		move.b	SS_Ani1UpData(pc,d0.w),d0	; shared across objects
		move.b	d0,(a1)
		bne.s	SS_AniReverse.return
		clr.l	(a0)
		clr.l	4(a0)
		rts
; ---------------------------------------------------------------------------

SS_AniReverse:
		subq.b	#1,2(a0)
		bpl.s	SS_AniReverse.return
		move.b	#7,2(a0)
		moveq	#0,d0
		move.b	3(a0),d0
		addq.b	#1,3(a0)
		movea.l	4(a0),a1
		move.b	SS_AniRevData(pc,d0.w),d0
		bne.s	.update
		clr.l	(a0)
		clr.l	4(a0)
		move.b	#$2B,(a1)
		rts
; ---------------------------------------------------------------------------

.update:
		move.b	d0,(a1)
.return:	rts
; ---------------------------------------------------------------------------

SS_AniEmeraldSparks:
		subq.b	#1,2(a0)
		bpl.s	SS_AniReverse.return
		move.b	#5,2(a0)
		moveq	#0,d0
		move.b	3(a0),d0
		addq.b	#1,3(a0)
		movea.l	4(a0),a1
		move.b	SS_Ani1UpData(pc,d0.w),d0	; shared across objects
		move.b	d0,(a1)
		bne.s	SS_AniReverse.return
		clr.l	(a0)
		clr.l	4(a0)
		move.b	#4,(v_objspace+obRoutine).w
		move.w	#sfx_SSGoal,d0
		jmp	(PlaySound_Special).l
; ---------------------------------------------------------------------------
SS_Ani1UpData:	dc.b $46, $47, $48, $49, 0
SS_AniRevData:	dc.b $2B, $31, $2B, $31, 0
SS_AniGlassData:dc.b $4B, $4C, $4D, $4E, $4B, $4C, $4D, $4E, 0
		even
; ---------------------------------------------------------------------------

SS_AniGlassBlock:
		subq.b	#1,2(a0)
		bpl.s	SS_AniReverse.return
		move.b	#1,2(a0)
		moveq	#0,d0
		move.b	3(a0),d0
		addq.b	#1,3(a0)
		movea.l	4(a0),a1
		move.b	SS_AniGlassData(pc,d0.w),d0
		move.b	d0,(a1)
		bne.s	SS_AniReverse.return
		move.b	4(a0),(a1)
		clr.l	(a0)
		clr.l	4(a0)
		rts
; ---------------------------------------------------------------------------
; Special stage	layout pointers
; ---------------------------------------------------------------------------
Bonus_LayoutIndex:
		dc.l BS_1
		dc.l BS_2
		dc.l BS_3
		dc.l BS_4
		dc.l BS_5
		dc.l BS_6
		even
; ---------------------------------------------------------------------------
; Subroutine to	load the bonus stage layout
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


BonusStage_Load:
		moveq	#0,d0
		move.b	(v_lastbonus).w,d0	; load number of last bonus stage entered
		addq.b	#1,(v_lastbonus).w
		cmpi.b	#6,(v_lastbonus).w
		blo.s	S1SS_ChkEmldNum
		sf	(v_lastbonus).w		; reset if higher than 6

S1SS_ChkEmldNum:
		cmpi.b	#6,(v_emeralds).w	; do you have all emeralds?
		beq.s	S1SS_LoadData		; if yes, branch
		moveq	#0,d1
		move.b	(v_emeralds).w,d1
		subq.b	#1,d1
		blo.s	S1SS_LoadData
		lea	(v_emldlist).w,a3	; check which emeralds you have

S1SS_ChkEmldLoop:
		cmp.b	(a3,d1.w),d0
		bne.s	S1SS_ChkEmldRepeat
		bra.s	BonusStage_Load
; ---------------------------------------------------------------------------

S1SS_ChkEmldRepeat:
		dbf	d1,S1SS_ChkEmldLoop

S1SS_LoadData:
		; Load player position data
		lsl.w	#2,d0
		lea	Bonus_StartLoc(pc,d0.w),a1
		move.w	(a1)+,(v_player+obX).w
		move.w	(a1)+,(v_player+obY).w
		; Load layout data
		movea.l	Bonus_LayoutIndex(pc,d0.w),a0
		lea	(v_ssbuffer2).l,a1
		bsr.w	KosPlusDec
		; Clear everything from v_ssbuffer1 to v_ssbuffer2
		lea	(v_ssbuffer1).l,a1
		move.w	#bytesToLcnt(v_ssbuffer2-v_ssbuffer1),d0

S1SS_ClrRAM3:
		clr.l	(a1)+
		dbf	d0,S1SS_ClrRAM3
		; Copy $1000 of data from v_ssbuffer2 to v_ssblockbuffer,
		; inserting $40 bytes of padding for every $40 bytes copied.
		lea	(v_ssblockbuffer).l,a1
		lea	(v_ssbuffer2).l,a0
		moveq	#bytesToXcnt(v_ssblockbuffer_end-v_ssblockbuffer,$80),d1
-		moveq	#$40-1,d2
-		move.b	(a0)+,(a1)+
		dbf	d2,-
		lea	$40(a1),a1
		dbf	d1,--

		lea	(v_ssblocktypes+8).l,a1
		lea	(S1SS_MapIndex).l,a0
		moveq	#bytesToXcnt(S1SS_MapIndex_End-S1SS_MapIndex,6),d1
-		move.l	(a0)+,(a1)+
		clr.w	(a1)+
		move.b	-4(a0),-1(a1)
		move.w	(a0)+,(a1)+
		dbf	d1,-
		lea	(v_ssitembuffer).l,a1
		move.w	#bytesToLcnt(v_ssitembuffer_end-v_ssitembuffer),d1

-		clr.l	(a1)+
		dbf	d1,-
		rts
; End of function BonusStage_Load

; ---------------------------------------------------------------------------
; Bonus stage start locations
; ---------------------------------------------------------------------------
Bonus_StartLoc:	include	"_inc/Start Location Array - Bonus Stages.asm"
		even
; ---------------------------------------------------------------------------
S1SS_MapIndex:
		include	"_inc/Special Stage Mappings & VRAM Pointers.asm"
S1SS_MapIndex_End:
		even
Map_SSWalls:	include	"mappings/sprite/S1/SS Walls.asm"
Map_SS_R:	include	"mappings/sprite/S1/SS R Block.asm"
Map_SS_Glass:	include	"mappings/sprite/S1/SS Glass Block.asm"
Map_SS_Up:	include	"mappings/sprite/S1/SS UP Block.asm"
Map_SS_Down:	include	"mappings/sprite/S1/SS DOWN Block.asm"
Map_SS_Bump:	include	"mappings/sprite/S1/SS Bumper.asm"
Map_SS_Ring:	include	"mappings/sprite/S1/SS Rings.asm"
		include	"mappings/sprite/S1/SS Chaos Emeralds.asm"
		include	"objects/Bonus & Special Stages/04 Player in Bonus Stage.asm"

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||
; Load only art assets (Kos modules) from LevelArtPointers
; Each entry = 8 bytes: PLC+Art1, PLC+Art2

LoadZone:
		moveq	#0,d0
		move.w	(Current_ZoneAndAct).w,d0
		ror.b	#2,d0
		lsr.w	#3,d0
		move.w	d0,d1
		lsr.w	#1,d1
		add.w	d1,d0
		lea	(LevelArtPointers).l,a2
		lea	(a2,d0.w),a2

		move.l	(a2)+,d0
		andi.l	#$FFFFFF,d0	; 8x8 tile pointer
		movea.l	d0,a0
		lea	(Chunk_Table).l,a1
		bsr.w	KosPlusDec
		move.w	a1,d3
		move.w	d3,d7
		andi.w	#$FFF,d3

		lsr.w	#1,d3
		rol.w	#4,d7
		andi.w	#$F,d7

-		move.w	d7,d2
		lsl.w	#7,d2
		lsl.w	#5,d2
		move.l	#$FFFFFF,d1
		move.w	d2,d1
		jsr	(QueueDMATransfer).l
		move.w	d7,-(sp)
		move.w	#Vint_TitleCard,(v_vbla_routine).w
		bsr.w	WaitForVint
		bsr.w	RunPLC_RAM
		move.w	(sp)+,d7
		move.w	#$800,d3
		dbf	d7,-
		; And now the 2nd half; blocks, chunks & layout!
		moveq	#0,d0
		move.w	(Current_ZoneAndAct).w,d0
		ror.b	#2,d0
		lsr.w	#3,d0		; d0 = 8 * (4*Z + A)
		move.w	d0,d1
		lsr.w	#1,d1
		add.w	d1,d0
		lea	(LevelArtPointers).l,a2
		lea	(a2,d0.w),a2
		move.l	a2,-(sp)
		addq.w	#4,a2
		move.l	(a2)+,d0
		andi.l	#$FFFFFF,d0	; pointer to block mappings
		movea.l	d0,a0
		lea	(v_16x16).w,a1
		bsr.w	KosPlusDec	; load block maps
		move.l	(a2)+,d0
		andi.l	#$FFFFFF,d0	; pointer to chunk mappings
		movea.l	d0,a0
		lea	(v_128x128).l,a1
		bsr.w	KosPlusDec
		bsr.s	LevelLayoutLoad
		movea.l	(sp)+,a2	; zone specific pointer in LevelArtPointers
		addq.w	#4,a2
		moveq	#0,d0
		move.b	(a2),d0	; PLC2 ID
		beq.s	+
		bsr.w	LoadPLC
+
		addq.w	#4,a2
		moveq	#0,d0
		move.b	(a2),d0	; palette ID
		bra.w	PalLoad1
; End of function LoadZone

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to load a level layout from RAM
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

LevelLayoutLoad:
		moveq	#0,d0
		move.w	(Current_ZoneAndAct).w,d0
		move.w	d0,d1
		lsr.w	#5,d0
		andi.w	#$FF,d1
		add.w	d1,d1
		add.w	d1,d0
		lea	(Level_Index).l,a0
		move.w	(a0,d0.w),d0
		adda.l	d0,a0
		lea	(v_lvllayout).w,a1
		bra.w	KosPlusDec

; End of function LevelLayoutLoad
SpecialStage:
	;	cmpi.b	#7,(Current_Special_Stage).w
	;	blo.s	+
	;	move.b	#0,(Current_Special_Stage).w
;+
		move.w	#sfx_EnterSS,d0
		bsr.w	PlaySound_Special
		bsr.w	Pal_MakeFlash
		disable_ints
		lea	(vdp_control_port).l,a6
		move.w	#$8B03,(a6)		; EXT-INT disabled, V scroll by screen, H scroll by line
		move.w	#$8004,(a6)		; H-INT disabled
		move.w	#$8ADF,(v_hbla_hreg).w	; H-INT every 224th scanline
		move.w	#$8200|(VRAM_SS_Plane_A_Name_Table1/$400),(a6)	; PNT A base: $C000
		move.w	#$8400|(VRAM_SS_Plane_B_Name_Table/$2000),(a6)	; PNT B base: $A000
		move.w	#$8C08,(a6)		; H res 32 cells, no interlace, S/H enabled
		move.w	#$9003,(a6)		; Scroll table size: 128x32
		move.w	#$8700,(a6)		; Background palette/color: 0/0
		move.w	#$8D00|(VRAM_Horiz_Scroll_Table/$400),(a6)		; H scroll table base: $FC00
		move.w	#$8500|(VRAM_Sprite_Attribute_Table/$200),(a6)	; Sprite attribute table base: $F800
		move.w	(v_vdp_buffer1).w,d0
		andi.b	#$BF,d0
		move.w	d0,(vdp_control_port).l
		rts
; =============== S U B R O U T I N E =======================================


LevelSizeLoad:
		clr.w	(Scroll_flags).w
		clr.w	(Scroll_flags_BG).w
		clr.w	(Scroll_flags_BG2).w
		clr.w	(Scroll_flags_BG3).w
		clr.w	(Scroll_flags_copy).w
		clr.w	(Scroll_flags_BG_copy).w
		clr.w	(Scroll_flags_BG2_copy).w
		clr.w	(Scroll_flags_BG3_copy).w
		clr.b	(Deform_lock).w
		moveq	#0,d0
		move.b	d0,(Dynamic_Resize_Routine).w
		move.w	(Current_ZoneAndAct).w,d0
		lsl.b	#6,d0
		lsr.w	#3,d0
		lea	LevelSizeArray(pc,d0.w),a0
		move.l	(a0)+,d0
		move.l	d0,(Camera_Min_X_pos).w
		move.l	d0,(Camera_Min_X_pos_target).w
		move.l	(a0)+,d0
		move.l	d0,(Camera_Min_Y_pos).w
		move.l	d0,(Camera_Min_Y_pos_target).w
		move.w	#$1010,(Horiz_block_crossed_flag).w
		move.w	#$60,(Camera_Y_pos_bias).w
		bra.w	LevelSize_CheckLamp
; ===========================================================================
LevelSizeArray:
		;    |-------------------------------------Left boundary
		;    |      |------------------------------Right boundary
		;    |      |      |-----------------------Top boundary
		;    |      |      |      |----------------Bottom boundary
		dc.w $0000, $24BF, $0000, $0300	; GHZ1
		dc.w $0000, $1EBF, $0000, $0300	; GHZ2
		dc.w $0000, $2960, $0000, $0300	; GHZ3
		dc.w $0000, $2ABF, $0000, $0300	; GHZ4
		dc.w $0000, $3FFF, $0000, $0720	; LZ1
		dc.w $0000, $3FFF, $0000, $0720	; LZ2
		dc.w $0000, $3FFF, $0000, $0800	; LZ3
		dc.w $0000, $3FFF, $0000, $0720	; LZ4
		dc.w $0000, $3FFF, $0000, $0720	; CPZ1 (MZ1)
		dc.w $0000, $3FFF, $0000, $0720	; CPZ2 (MZ2)
		dc.w $0000, $3FFF, $0000, $0720	; CPZ3 (MZ3)
		dc.w $0000, $3FFF, $0000, $0720	; CPZ4 (MZ4)
		dc.w $0000, $29A0, $0000, $0320	; EHZ1 (SLZ1)
		dc.w $0000, $2940, $0000, $0420	; EHZ2 (SLZ2)
		dc.w $0000, $25C0, $0000, $0720	; EHZ3 (SLZ3)
		dc.w $0000, $3FFF, $0000, $0720	; EHZ4 (SLZ4)
		dc.w $0000, $3FFF, $0000, $0720	; HPZ1 (SYZ1)
		dc.w $0000, $3FFF, $0000, $0720	; HPZ2 (SYZ2)
		dc.w $0000, $3FFF, $0000, $0720	; HPZ3 (SYZ3)
		dc.w $0000, $3FFF, $0000, $0720	; HPZ4 (SYZ4)
		dc.w $0000, $3FFF, $0000, $0720	; HTZ1 (SBZ1)
		dc.w $0000, $1E40, $FF00, $0720	; HTZ2 (SBZ2)
		dc.w $0000, $3FFF, $0510, $0720	; HTZ3 (SBZ3)
		dc.w $0000, $3FFF, $0000, $0720	; HTZ4 (SBZ4)
		dc.w $0000, $3FFF, $0000, $0110	; ZONE 6  1 (Was S1 Good Ending)
		dc.w $0000, $3FFF, $0000, $0110	; ZONE 6  2 (Was S1 Bad Ending)
		dc.w $0000, $3FFF, $0000, $0320	; ZONE 6  3
		dc.w $0000, $3FFF, $0000, $0320	; ZONE 6  4
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 7  1
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 7  2
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 7  3
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 7  4
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 8  1
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 8  2
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 8  3
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 8  4
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 9  1
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 9  2
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 9  3
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 9  4
		dc.w $0000, $3FFF, $0000, $0800	; ZONE A  1
		dc.w $0000, $3FFF, $0000, $0800	; ZONE A  2
		dc.w $0000, $3FFF, $0000, $0800	; ZONE A  3
		dc.w $0000, $3FFF, $0000, $0800	; ZONE A  4
		dc.w $0000, $3FFF, $0000, $0800	; ZONE B  1
		dc.w $0000, $3FFF, $0000, $0800	; ZONE B  2
		dc.w $0000, $3FFF, $0000, $0800	; ZONE B  3
		dc.w $0000, $3FFF, $0000, $0800	; ZONE B  4
		dc.w $0000, $3FFF, $0000, $0800	; ZONE C  1
		dc.w $0000, $3FFF, $0000, $0800	; ZONE C  2
		dc.w $0000, $3FFF, $0000, $0800	; ZONE C  3
		dc.w $0000, $3FFF, $0000, $0800	; ZONE C  4
		dc.w $0000, $3FFF, $0000, $0800	; ZONE D  1
		dc.w $0000, $3FFF, $0000, $0800	; ZONE D  2
		dc.w $0000, $3FFF, $0000, $0800	; ZONE D  3
		dc.w $0000, $3FFF, $0000, $0800	; ZONE D  4
		dc.w $0000, $3FFF, $0000, $0800	; ZONE E  1
		dc.w $0000, $3FFF, $0000, $0800	; ZONE E  2
		dc.w $0000, $3FFF, $0000, $0800	; ZONE E  3
		dc.w $0000, $3FFF, $0000, $0800	; ZONE E  4
		dc.w $0000, $3FFF, $0000, $0800	; ZONE F  1
		dc.w $0000, $3FFF, $0000, $0800	; ZONE F  2
		dc.w $0000, $3FFF, $0000, $0800	; ZONE F  3
		dc.w $0000, $3FFF, $0000, $0800	; ZONE F  4
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 10 1
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 10 2
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 10 3
		dc.w $0000, $3FFF, $0000, $0800	; ZONE 10 4
; ===========================================================================
S1EndingStartLoc:
		dc.w  $50,   $3B0, $EA0,  $46C, $1750, $BD,  $A00,  $62C
		dc.w  $BB0,  $4C,  $1570, $16C, $1B0,  $72C, $1400, $2AC
; ===========================================================================

LevelSize_CheckLamp:
		tst.b	(v_lastlamp).w
		beq.s	LevelSize_StartLoc
		jsr	(Lamppost_LoadInfo).l
		move.w	(v_player+obX).w,d1
		move.w	(v_player+obY).w,d0
		bra.s	LevelSize_StartLocLoaded
; ---------------------------------------------------------------------------

LevelSize_StartLoc:
		move.w	(Current_ZoneAndAct).w,d0
		lsl.b	#6,d0
		lsr.w	#4,d0
		lea	StartLocArray(pc,d0.w),a1
		tst.w	(f_demo).w	; is this an ending demo?
		bpl.s	loc_58CE	; if not, skip this part

		move.w	(v_creditsnum).w,d0
		subq.w	#1,d0
		lsl.w	#2,d0
		lea	S1EndingStartLoc(pc,d0.w),a1

loc_58CE:
		moveq	#0,d1
		move.w	(a1)+,d1
		move.w	d1,(v_player+obX).w
		moveq	#0,d0
		move.w	(a1),d0
		move.w	d0,(v_player+obY).w

LevelSize_StartLocLoaded:
		subi.w	#$A0,d1
		bhs.s	loc_58E6
		moveq	#0,d1

loc_58E6:
		move.w	(Camera_Max_X_pos).w,d2
		cmp.w	d2,d1
		blo.s	loc_58F0
		move.w	d2,d1

loc_58F0:
		move.w	d1,(Camera_X_pos).w
		subi.w	#$60,d0
		bhs.s	loc_5900
		moveq	#0,d0

loc_5900:
		cmp.w	(Camera_Max_Y_pos).w,d0
		blt.s	loc_590A
		move.w	(Camera_Max_Y_pos).w,d0

loc_590A:
		move.w	d0,(Camera_Y_pos).w
		bra.w	BgScrollSpeed
; End of function LevelSizeLoad

; ---------------------------------------------------------------------------
StartLocArray:
		binclude	"startpos/GHZ_1.bin"	; GHZ1
		binclude	"startpos/GHZ_2.bin"	; GHZ2
		binclude	"startpos/GHZ_3.bin"	; GHZ3
		binclude	"startpos/GHZ_4.bin"	; GHZ4
		binclude	"startpos/LZ_1.bin"	; LZ1
		binclude	"startpos/LZ_2.bin"	; LZ2
		binclude	"startpos/LZ_3.bin"	; LZ3
		binclude	"startpos/LZ_4.bin"	; LZ4
		binclude	"startpos/CPZ_1.bin"	; CPZ1
		binclude	"startpos/CPZ_2.bin"	; CPZ2
		binclude	"startpos/CPZ_3.bin"	; CPZ3
		binclude	"startpos/CPZ_4.bin"	; CPZ4
		binclude	"startpos/EHZ_1.bin"	; EHZ1
		binclude	"startpos/EHZ_2.bin"	; EHZ2
		binclude	"startpos/EHZ_3.bin"	; EHZ3
		binclude	"startpos/EHZ_4.bin"	; EHZ4
		binclude	"startpos/HPZ_1.bin"	; HPZ1
		binclude	"startpos/HPZ_2.bin"	; HPZ2
		binclude	"startpos/HPZ_3.bin"	; HPZ3
		binclude	"startpos/HPZ_4.bin"	; HPZ4
		binclude	"startpos/HTZ_1.bin"	; HTZ1
		binclude	"startpos/HTZ_2.bin"	; HTZ2
		binclude	"startpos/HTZ_3.bin"	; HTZ2
		binclude	"startpos/HTZ_4.bin"	; HTZ4
		binclude	"startpos/006_1.bin"	; S1 Ending 1
		binclude	"startpos/006_2.bin"	; S1 Ending 2
		binclude	"startpos/006_3.bin"	; S1 Ending 3
		binclude	"startpos/006_4.bin"	; S1 Ending 4

; =============== S U B R O U T I N E =======================================


BgScrollSpeed:
		tst.b	(v_lastlamp).w	; was a star pole hit yet?
		bne.s	.skip		; if yes, branch
		move.w	d0,(Camera_BG_Y_pos).w
		move.w	d0,(Camera_BG2_Y_pos).w
		move.w	d1,(Camera_BG_X_pos).w
		move.w	d1,(Camera_BG2_X_pos).w
		move.w	d1,(Camera_BG3_X_pos).w

.skip:
		moveq	#0,d2
		move.b	(Current_Zone).w,d2
		add.w	d2,d2
		move.w	BgScroll_Index(pc,d2.w),d2
		jmp	BgScroll_Index(pc,d2.w)
; End of function BgScrollSpeed

; ---------------------------------------------------------------------------
BgScroll_Index:
		dc.w BgScroll_GHZ-BgScroll_Index
		dc.w BgScroll_LZ-BgScroll_Index
		dc.w BgScroll_CPZ-BgScroll_Index
		dc.w BgScroll_EHZ-BgScroll_Index
		dc.w BgScroll_HPZ-BgScroll_Index
		dc.w BgScroll_EHZ-BgScroll_Index
		dc.w BgScroll_S1Ending-BgScroll_Index
; ---------------------------------------------------------------------------

BgScroll_GHZ:
		clr.l	(Camera_BG_X_pos).w
		clr.l	(Camera_BG_Y_pos).w
		clr.l	(Camera_BG2_Y_pos).w
		clr.l	(Camera_BG3_Y_pos).w
		lea	(v_bgscroll_buffer).w,a2
		clr.l	(a2)+
		clr.l	(a2)+
		clr.l	(a2)+
		rts
; ---------------------------------------------------------------------------

BgScroll_LZ:
		asr.l	#1,d0
		move.w	d0,(Camera_BG_Y_pos).w
		rts
; ---------------------------------------------------------------------------

BgScroll_CPZ:
		lsr.w	#2,d0
		move.w	d0,(Camera_BG_Y_pos).w
		clr.l	(Camera_BG_X_pos).w
		clr.l	(Camera_BG2_X_pos).w
		rts
; ---------------------------------------------------------------------------

BgScroll_EHZ:
		; identical to BgScroll_GHZ
		clr.l	(Camera_BG_X_pos).w
		clr.l	(Camera_BG_Y_pos).w
		clr.l	(Camera_BG2_Y_pos).w
		clr.l	(Camera_BG3_Y_pos).w
		lea	(v_bgscroll_buffer).w,a2
		clr.l	(a2)+
		clr.l	(a2)+
		clr.l	(a2)+
		rts
; ---------------------------------------------------------------------------

BgScroll_HPZ:
		asr.w	#1,d0
		move.w	d0,(Camera_BG_Y_pos).w
		clr.l	(Camera_BG_X_pos).w
		rts
; ---------------------------------------------------------------------------

BgScroll_S1SYZ:						; leftover from Sonic 1
		asl.l	#4,d0
		move.l	d0,d2
		asl.l	#1,d0
		add.l	d2,d0
		asr.l	#8,d0
		addq.w	#1,d0
		move.w	d0,(Camera_BG_Y_pos).w
		clr.l	(Camera_BG_X_pos).w
		rts
; ---------------------------------------------------------------------------

BgScroll_S1Ending:
		move.w	(Camera_RAM).w,d0
		asr.w	#1,d0
		move.w	d0,(Camera_BG_X_pos).w
		move.w	d0,(Camera_BG2_X_pos).w
		asr.w	#2,d0
		move.w	d0,d1
		add.w	d0,d0
		add.w	d1,d0
		move.w	d0,(Camera_BG3_X_pos).w
		clr.l	(Camera_BG_Y_pos).w
		clr.l	(Camera_BG2_Y_pos).w
		clr.l	(Camera_BG3_Y_pos).w
		lea	(v_bgscroll_buffer).w,a2
		clr.l	(a2)+
		clr.l	(a2)+
		clr.l	(a2)+
-		rts

; ---------------------------------------------------------------------------
; Background layer deformation subroutines
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; DeformLayers:
DeformBGLayer:
		tst.b	(Deform_lock).w
		bne.s	-
		clr.w	(Scroll_flags).w
		clr.w	(Scroll_flags_BG).w
		clr.w	(Scroll_flags_BG2).w
		clr.w	(Scroll_flags_BG3).w
		lea	(v_player).w,a0
		lea	(Camera_RAM).w,a1
		lea	(Horiz_block_crossed_flag).w,a2
		lea	(Scroll_flags).w,a3
		lea	(Camera_X_pos_diff).w,a4
		lea	(Horiz_scroll_delay_val).w,a5
		lea	(Sonic_Pos_Record_Buf).w,a6
		bsr.w	ScrollHorizontal
		lea	(Camera_Y_pos).w,a1
		lea	(Verti_block_crossed_flag).w,a2
		lea	(Camera_Y_pos_diff).w,a4
		bsr.w	ScrollVertical
		bsr.w	DynScreenResizeLoad
		move.w	(Camera_Y_pos).w,(v_scrposy_vdp).w
		move.w	(Camera_BG_Y_pos).w,(v_bgscrposy_vdp).w
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
		add.w	d0,d0
		move.w	Deform_Index(pc,d0.w),d0
		jmp	Deform_Index(pc,d0.w)
; End of function DeformBGLayer

; ---------------------------------------------------------------------------
Deform_Index:	dc.w Deform_GHZ-Deform_Index
		dc.w Deform_LZ-Deform_Index
		dc.w Deform_CPZ-Deform_Index
		dc.w Deform_EHZ-Deform_Index
		dc.w Deform_HPZ-Deform_Index
		dc.w Deform_HTZ-Deform_Index
		dc.w Deform_GHZ-Deform_Index
; ---------------------------------------------------------------------------

Deform_GHZ:
	; block 3 - distant mountains
		move.w	(Camera_X_pos_diff).w,d4
		ext.l	d4
		asl.l	#6,d4	; shaving some cycles off
;		move.l	d4,d1
;		asl.l	#1,d4
;		add.l	d1,d4
		moveq	#0,d6	; changes from 0 to 6 in Palmtree panic
		bsr.w	ScrollBlock6
	; block 2 - hills & waterfalls
		move.w	(Camera_X_pos_diff).w,d4
		ext.l	d4
		asl.l	#7,d4
		moveq	#0,d6	; changes from 0 to 4 in Palmtree panic
		bsr.w	ScrollBlock5
	; calculate Y position
		lea	(v_hscrolltablebuffer).w,a1
		move.w	(Camera_Y_pos).w,d0
		andi.w	#$7FF,d0
		lsr.w	#5,d0
		neg.w	d0
		addi.w	#$20,d0
		bpl.s	.limitY
		moveq	#0,d0
.limitY:
		move.w	d0,d4
		move.w	d0,(v_bgscrposy_vdp).w
		move.w	(Camera_RAM).w,d0
		neg.w	d0
		swap	d0
	; auto-scroll clouds
		lea	(v_bgscroll_buffer).w,a2
		addi.l	#$10000,(a2)+
		addi.l	#$C000,(a2)+
		addi.l	#$8000,(a2)+
	;	addi.l	#$4000,(a2)+	; Palmtree panic has 1 extra scroll layer
	; calculate background scroll
		move.w	(v_bgscroll_buffer).w,d0
		add.w	(Camera_BG3_X_pos).w,d0
		neg.w	d0
		moveq	#32-1,d1
		sub.w	d4,d1
		blo.s	.gotoCloud2
.cloudLoop1:		; upper cloud (32px)
		move.l	d0,(a1)+
		dbf	d1,.cloudLoop1

.gotoCloud2:
		move.w	(v_bgscroll_buffer+4).w,d0
		add.w	(Camera_BG3_X_pos).w,d0
		neg.w	d0
		moveq	#16-1,d1
.cloudLoop2:		; middle cloud (16px)
		move.l	d0,(a1)+
		dbf	d1,.cloudLoop2
		move.w	(v_bgscroll_buffer+8).w,d0
		add.w	(Camera_BG3_X_pos).w,d0
		neg.w	d0
		moveq	#16-1,d1
.cloudLoop3:		; lower cloud (16px)
		move.l	d0,(a1)+
		dbf	d1,.cloudLoop3
		moveq	#48-1,d1
		move.w	(Camera_BG3_X_pos).w,d0
		neg.w	d0
.mountainLoop:		; distant mountains (48px)
		move.l	d0,(a1)+
		dbf	d1,.mountainLoop
		moveq	#40-1,d1
		move.w	(Camera_BG2_X_pos).w,d0
		neg.w	d0
.hillLoop:		; hills & waterfalls (40px)
		move.l	d0,(a1)+
		dbf	d1,.hillLoop
		move.w	(Camera_BG2_X_pos).w,d0
		move.w	(Camera_RAM).w,d2
		sub.w	d0,d2
		ext.l	d2
		asl.l	#8,d2
		divs.w	#$68,d2
		ext.l	d2
		asl.l	#8,d2
		moveq	#0,d3
		move.w	d0,d3
		moveq	#72-1,d1
		add.w	d4,d1
.waterLoop:		; water deformation
		move.w	d3,d0
		neg.w	d0
		move.l	d0,(a1)+
		swap	d3
		add.l	d2,d3
		swap	d3
		dbf	d1,.waterLoop
		rts
; ---------------------------------------------------------------------------

Deform_LZ:
		move.w	(Camera_X_pos_diff).w,d4
		ext.l	d4
		asl.l	#7,d4
		move.w	(Camera_Y_pos_diff).w,d5
		ext.l	d5
		asl.l	#7,d5
		bsr.w	ScrollBlock1
		move.w	(Camera_BG_Y_pos).w,(v_bgscrposy_vdp).w
		lea	(Deform_LZ_Data1).l,a3
		lea	(Drown_WobbleData).l,a2
		move.b	(v_lz_deform).w,d2
		move.b	d2,d3
		addi.w	#$80,(v_lz_deform).w
		add.w	(Camera_BG_Y_pos).w,d2
		andi.w	#$FF,d2
		add.w	(Camera_Y_pos).w,d3
		andi.w	#$FF,d3
		lea	(v_hscrolltablebuffer).w,a1
		move.w	#224-1,d1
		move.w	(Camera_RAM).w,d0
		neg.w	d0
		move.w	d0,d6
		swap	d0
		move.w	(Camera_BG_X_pos).w,d0
		neg.w	d0
		move.w	(v_waterpos1).w,d4
		move.w	(Camera_Y_pos).w,d5

loc_5EC6:
		cmp.w	d4,d5
		bge.s	loc_5ED8
		move.l	d0,(a1)+
		addq.w	#1,d5
		addq.b	#1,d2
		addq.b	#1,d3
		dbf	d1,loc_5EC6
		rts
; ---------------------------------------------------------------------------

loc_5ED8:
		move.b	(a3,d3.w),d4
		ext.w	d4
		add.w	d6,d4
		move.w	d4,(a1)+
		move.b	(a2,d2.w),d4
		ext.w	d4
		add.w	d0,d4
		move.w	d4,(a1)+
		addq.b	#1,d2
		addq.b	#1,d3
		dbf	d1,loc_5ED8
		rts
; ---------------------------------------------------------------------------
Deform_LZ_Data1:dc.b   1,  1,  2,  2,  3,  3,  3,  3,  2,  2,  1,  1,  0,  0,  0,  0
		dc.b   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
		dc.b   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
		dc.b   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
		dc.b   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
		dc.b   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
		dc.b   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
		dc.b   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
		dc.b $FF,$FF,$FE,$FE,$FD,$FD,$FD,$FD,$FE,$FE,$FF,$FF,  0,  0,  0,  0
		dc.b   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
		dc.b   1,  1,  2,  2,  3,  3,  3,  3,  2,  2,  1,  1,  0,  0,  0,  0
		dc.b   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
		dc.b   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
		dc.b   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
		dc.b   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
		dc.b   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
; ---------------------------------------------------------------------------

Deform_CPZ:
		move.w	(Camera_X_pos_diff).w,d4
		ext.l	d4
		asl.l	#5,d4
		move.w	(Camera_Y_pos_diff).w,d5
		ext.l	d5
		asl.l	#6,d5
		bsr.w	ScrollBlock1
		move.w	(Camera_BG_Y_pos).w,(v_bgscrposy_vdp).w
		lea	(v_hscrolltablebuffer).w,a1
		move.w	#224-1,d1
		move.w	(Camera_RAM).w,d0
		neg.w	d0
		swap	d0
		move.w	(Camera_BG_X_pos).w,d0
		neg.w	d0

loc_6026:
		move.l	d0,(a1)+
		dbf	d1,loc_6026
		rts

; ---------------------------------------------------------------------------

Deform_TitleScreen:
		move.w	(Camera_BG_Y_pos).w,(v_bgscrposy_vdp).w
		move.w	(Camera_RAM).w,d0
		cmpi.w	#$1C00,d0
		bhs.s	loc_60B6
		addq.w	#8,d0

loc_60B6:
		move.w	d0,(Camera_RAM).w
		lea	(v_hscrolltablebuffer).w,a1
		move.w	(Camera_RAM).w,d2
		neg.w	d2
		clr.w	d0
		bra.s	+
; ---------------------------------------------------------------------------

Deform_EHZ:
		; Update the background's vertical scrolling.
		move.w	(Camera_BG_Y_pos).w,(v_bgscrposy_vdp).w
		; Update the background's (and foreground's) horizontal scrolling.
		; This creates an elaborate parallax effect.
		lea	(v_hscrolltablebuffer).w,a1
		move.w	(Camera_RAM).w,d0
		neg.w	d0
		move.w	d0,d2
		swap	d0
+		clr.w	d0
		; Do 22 lines.
		move.w	#22-1,d1
-		move.l	d0,(a1)+
		dbf	d1,-

		move.w	d2,d0
		asr.w	#6,d0
		; Do 58 lines.
		move.w	#58-1,d1
-		move.l	d0,(a1)+
		dbf	d1,-

		move.w	d0,d3
		; Make the 'ripple' animate every 8 frames.
		move.b	(Vint_runcount+3).w,d1
		andi.w	#7,d1
		bne.s	+
		subq.w	#1,(v_bgscroll_buffer).w
+
		move.w	(v_bgscroll_buffer).w,d1
		andi.w	#$1F,d1
		lea	(Deform_EHZ_Data).l,a2
		lea	(a2,d1.w),a2
		; Do 21 lines.
		move.w	#21-1,d1
-		move.b	(a2)+,d0
		ext.w	d0
		add.w	d3,d0
		move.l	d0,(a1)+
		dbf	d1,-

		clr.w	d0
		; Do 11 lines.
		move.w	#11-1,d1
-		move.l	d0,(a1)+
		dbf	d1,-

		move.w	d2,d0
		asr.w	#4,d0
		; Do 16 lines.
		move.w	#16-1,d1
-		move.l	d0,(a1)+
		dbf	d1,-

		move.w	d2,d0
		asr.w	#4,d0
		move.w	d0,d1
		asr.w	#1,d1
		add.w	d1,d0
		; Do 16 lines.
		move.w	#16-1,d1
-		move.l	d0,(a1)+
		dbf	d1,-

		move.l	d0,d4
		swap	d4
		move.w	d2,d0
		asr.w	#1,d0
		move.w	d2,d1
		asr.w	#3,d1
		sub.w	d1,d0
		ext.l	d0
		asl.l	#8,d0
		divs.w	#$30,d0
		ext.l	d0
		asl.l	#8,d0
		clr.w	d3
		move.w	d2,d3
		asr.w	#3,d3
		; Do 15 lines.
		move.w	#15-1,d1
-		move.w	d4,(a1)+
		move.w	d3,(a1)+
		swap	d3
		add.l	d0,d3
		swap	d3
		dbf	d1,-
		; Do 18 lines.
		move.w	#18/2-1,d1
-		move.w	d4,(a1)+
		move.w	d3,(a1)+
		move.w	d4,(a1)+
		move.w	d3,(a1)+
		swap	d3
		add.l	d0,d3
		add.l	d0,d3
		swap	d3
		dbf	d1,-
		; Do 45 lines.
		moveq	#45/3-1,d1
-		move.w	d4,(a1)+
		move.w	d3,(a1)+
		move.w	d4,(a1)+
		move.w	d3,(a1)+
		move.w	d4,(a1)+
		move.w	d3,(a1)+
		swap	d3
		add.l	d0,d3
		add.l	d0,d3
		add.l	d0,d3
		swap	d3
		dbf	d1,-

		move.w	d4,(a1)+
		move.w	d3,(a1)+
		move.w	d4,(a1)+
		move.w	d3,(a1)+
		rts
; End of function Deform_TitleScreen

; ---------------------------------------------------------------------------
Deform_EHZ_Data:
		dc.b   1,  2,  1,  3,  1,  2,  2,  1,  2,  3,  1,  2,  1,  2,  0,  0; 16
		dc.b   2,  0,  3,  2,  2,  3,  2,  2,  1,  3,  0,  0,  1,  0,  1,  3; 32
		dc.b   1,  2,  1,  3,  1,  2,  2,  1,  2,  3,  1,  2,  1,  2,  0,  0; 48
		dc.b   2,  0,  3,  2,  2,  3,  2,  2,  1,  3,  0,  0,  1,  0,  1,  3; 64
		dc.b   1,  2	; 66
		even
; ---------------------------------------------------------------------------

Bg_Scroll_X:
		lea	(v_hscrolltablebuffer).w,a1
		move.w	#224/16+1-1,d1
		move.w	(Camera_RAM).w,d0
		neg.w	d0
		swap	d0
		andi.w	#$F,d2
		add.w	d2,d2
		move.w	(a2)+,d0
		jmp	loc_6324(pc,d2.w)
; ---------------------------------------------------------------------------

loc_6322:
		move.w	(a2)+,d0

loc_6324:
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		move.l	d0,(a1)+
		dbf	d1,loc_6322
		rts
; ---------------------------------------------------------------------------

Deform_HPZ:
		move.w	(Camera_X_pos_diff).w,d4
		ext.l	d4
		asl.l	#6,d4
		moveq	#2,d6
		bsr.w	ScrollBlock4
		move.w	(Camera_Y_pos_diff).w,d5
		ext.l	d5
		asl.l	#7,d5
		moveq	#6,d6
		bsr.w	ScrollBlock2

		; Update the background's vertical scrolling.
		move.w	(Camera_BG_Y_pos).w,(v_bgscrposy_vdp).w

		; Rather than scroll each individual line of the background, this
		; zone scrolls entire blocks of lines (16 lines) at once. The scroll
		; value of each row is written to 'TempArray_LayerDef', before it is
		; applied to 'Horiz_Scroll_Buf' in 'Deform_HPZ_Continued'. This is
		; vaguely similar to how Chemical Plant Zone scrolls its background,
		; even overflowing 'Horiz_Scroll_Buf' in the same way.
		lea	(v_bgscroll_buffer).w,a1
		move.w	(Camera_RAM).w,d2
		neg.w	d2

		; Do 8 line blocks.
		move.w	d2,d0
		asr.w	#1,d0
		move.w	#8-1,d1
loc_637E:	move.w	d0,(a1)+
		dbf	d1,loc_637E

		move.w	d2,d0
		asr.w	#3,d0
		sub.w	d2,d0
		ext.l	d0
		asl.l	#3,d0
		asr.w	#3,d0	; replaced with asr.w #3,d0 to save 150 cycles
		ext.l	d0
		asl.l	#4,d0
		asl.l	#8,d0
		moveq	#0,d3
		move.w	d2,d3
		asr.w	#1,d3
		lea	(v_bgscroll_buffer+(8+7+26+7)*2).w,a2
		swap	d3
		add.l	d0,d3
		swap	d3
		move.w	d3,(a1)+
		move.w	d3,(a1)+
		move.w	d3,(a1)+
		move.w	d3,-(a2)
		move.w	d3,-(a2)
		move.w	d3,-(a2)
		swap	d3
		add.l	d0,d3
		swap	d3
		move.w	d3,(a1)+
		move.w	d3,(a1)+
		move.w	d3,-(a2)
		move.w	d3,-(a2)
		swap	d3
		add.l	d0,d3
		swap	d3
		move.w	d3,(a1)+
		move.w	d3,-(a2)
		swap	d3
		add.l	d0,d3
		swap	d3
		move.w	d3,(a1)+
		move.w	d3,-(a2)

		; Do 26 line blocks.
		move.w	(Camera_BG_X_pos).w,d0
		neg.w	d0
		move.w	#26-1,d1
loc_63E0:	move.w	d0,(a1)+
		dbf	d1,loc_63E0
		adda.w	#7*2,a1	; Skip 7 line blocks which were done earlier.

		; Do 24 line blocks.
		move.w	d2,d0
		asr.w	#1,d0
		moveq	#24-1,d1
loc_63F2:	move.w	d0,(a1)+
		dbf	d1,loc_63F2

		lea	(v_bgscroll_buffer).w,a2
		move.w	(Camera_BG_Y_pos).w,d0
		move.w	d0,d2
		andi.w	#$3F0,d0
		lsr.w	#3,d0
		lea	(a2,d0.w),a2
		bra.w	Bg_Scroll_X
; ---------------------------------------------------------------------------

Deform_HTZ:
		move.w	(Camera_BG_Y_pos).w,(v_bgscrposy_vdp).w
		lea	(v_hscrolltablebuffer).w,a1
		move.w	(Camera_RAM).w,d0
		neg.w	d0
		move.w	d0,d2
		swap	d0
		move.w	d2,d0
		asr.w	#3,d0
		move.w	#128-1,d1

loc_642C:
		move.l	d0,(a1)+
		dbf	d1,loc_642C
		move.l	d0,d4
		move.w	d2,d0
		asr.w	#1,d0
		move.w	d2,d1
		asr.w	#3,d1
		sub.w	d1,d0
		ext.l	d0
		asl.l	#4,d0
		divs.w	#$18,d0
		ext.l	d0
		asl.l	#4,d0
		asl.l	#8,d0
		moveq	#0,d3
		move.w	d2,d3
		asr.w	#3,d3
		swap	d3
		add.l	d0,d3
		swap	d3
		move.w	d3,d4
		move.l	d4,(a1)+
		move.l	d4,(a1)+
		move.l	d4,(a1)+
		swap	d3
		add.l	d0,d3
		swap	d3
		move.w	d3,d4
		move.l	d4,(a1)+
		move.l	d4,(a1)+
		move.l	d4,(a1)+
		move.l	d4,(a1)+
		move.l	d4,(a1)+
		swap	d3
		add.l	d0,d3
		swap	d3
		move.w	d3,d4
		move.w	#7-1,d1

loc_647E:
		move.l	d4,(a1)+
		dbf	d1,loc_647E
		swap	d3
		add.l	d0,d3
		add.l	d0,d3
		swap	d3
		move.w	d3,d4
		move.w	#8-1,d1

loc_6492:
		move.l	d4,(a1)+
		dbf	d1,loc_6492
		swap	d3
		add.l	d0,d3
		add.l	d0,d3
		swap	d3
		move.w	d3,d4
		move.w	#10-1,d1

loc_64A6:
		move.l	d4,(a1)+
		dbf	d1,loc_64A6
		swap	d3
		add.l	d0,d3
		add.l	d0,d3
		add.l	d0,d3
		swap	d3
		move.w	d3,d4
		move.w	#15-1,d1

loc_64BC:
		move.l	d4,(a1)+
		dbf	d1,loc_64BC
		swap	d3
		add.l	d0,d3
		add.l	d0,d3
		add.l	d0,d3
		swap	d3
		move.w	#3-1,d2

loc_64D0:
		move.w	d3,d4
		move.w	#16-1,d1

loc_64D6:
		move.l	d4,(a1)+
		dbf	d1,loc_64D6
		swap	d3
		add.l	d0,d3
		add.l	d0,d3
		add.l	d0,d3
		add.l	d0,d3
		swap	d3
		dbf	d2,loc_64D0
		rts

; =============== S U B R O U T I N E =======================================


ScrollHorizontal:
		move.w	(a1),d4
		bsr.s	ScrollHoriz
		move.w	(a1),d0
		andi.w	#16,d0
		move.b	(a2),d1
		eor.b	d1,d0
		bne.s	locret_6512
		eori.b	#16,(a2)
		move.w	(a1),d0
		sub.w	d4,d0
		bpl.s	loc_650E
		bset	#2,(a3)
		rts
; ---------------------------------------------------------------------------

loc_650E:
		bset	#3,(a3)

locret_6512:
		rts
; End of function ScrollHorizontal


; =============== S U B R O U T I N E =======================================

;sub_6514:
ScrollHoriz:
	if FixBugs
		; To prevent the bug that is described below, this caps the position
		; array index offset so that it does not access position data from
		; before the spin dash was performed. Note that this required
		; modifications to 'Sonic_UpdateSpindash' and 'Tails_UpdateSpindash'.
		move.b	Horiz_scroll_delay_val-Camera_Delay(a5),d1	; should scrolling be delayed?
		beq.s	.scrollNotDelayed				; if not, branch
		lsl.b	#2,d1		; multiply by 4, the size of a position buffer entry
		subq.b	#1,Horiz_scroll_delay_val-Camera_Delay(a5)	; reduce delay value
		move.b	Sonic_Pos_Record_Index+1-Camera_Delay(a5),d0
		sub.b	Horiz_scroll_delay_val+1-Camera_Delay(a5),d0
		cmp.b	d0,d1
		blo.s	.doNotCap
		move.b	d0,d1
.doNotCap:
	else
		; The intent of this code is to make the camera briefly lag behind the
		; player right after releasing a spin dash, however it does this by
		; simply making the camera use position data from previous frames. This
		; means that if the camera had been moving recently enough, then
		; releasing a spin dash will cause the camera to jerk around instead of
		; remain still. This can be encountered by running into a wall, and
		; quickly turning around and spin dashing away. Sonic 3 would have had
		; this same issue with the Fire Shield's dash abiliity, but it shoddily
		; works around the issue by resetting the old position values to the
		; current position (see 'Reset_Player_Position_Array').
		move.w	Horiz_scroll_delay_val-Camera_Delay(a5),d1	; should scrolling be delayed?
		beq.s	.scrollNotDelayed				; if not, branch
		subi.w	#$100,d1					; reduce delay value
		move.w	d1,Horiz_scroll_delay_val-Camera_Delay(a5)
		moveq	#0,d1
		move.b	Horiz_scroll_delay_val-Camera_Delay(a5),d1	; get delay value
		lsl.b	#2,d1		; multiply by 4, the size of a position buffer entry
		addq.b	#4,d1
	endif
		move.w	Sonic_Pos_Record_Index-Camera_Delay(a5),d0
		sub.b	d1,d0
		move.w	(a6,d0.w),d0
		andi.w	#$3FFF,d0
		bra.s	.checkIfShouldScroll
; ---------------------------------------------------------------------------

.scrollNotDelayed:
		move.w	obX(a0),d0

.checkIfShouldScroll:
		sub.w	(a1),d0
		subi.w	#(320/2)-16,d0
		blt.s	.scrollLeft
		subi.w	#16,d0
		bge.s	.scrollRight
		clr.w	(a4)
		rts
; ---------------------------------------------------------------------------

.scrollLeft:
		cmpi.w	#-16,d0
		bgt.s	.maxNotReached
		move.w	#-16,d0

.maxNotReached:
		add.w	(a1),d0
		cmp.w	(Camera_Min_X_pos).w,d0
		bgt.s	.doScroll
		move.w	(Camera_Min_X_pos).w,d0
		bra.s	.doScroll
; ---------------------------------------------------------------------------

.scrollRight:
		cmpi.w	#16,d0
		blo.s	.maxNotReached2
		move.w	#16,d0

.maxNotReached2:
		add.w	(a1),d0
		cmp.w	(Camera_Max_X_pos).w,d0
		blt.s	.doScroll
		move.w	(Camera_Max_X_pos).w,d0

.doScroll:
		move.w	d0,d1
		sub.w	(a1),d1
		asl.w	#8,d1
		move.w	d0,(a1)
		move.w	d1,(a4)
		rts
; End of function ScrollHoriz


; =============== S U B R O U T I N E =======================================


ScrollVertical:
		moveq	#0,d1
		move.w	obY(a0),d0
		sub.w	(a1),d0
		btst	#2,obStatus(a0)
		beq.s	loc_6598
		subq.w	#5,d0

loc_6598:
		btst	#1,obStatus(a0)
		beq.s	loc_65B8
		addi.w	#32,d0
		sub.w	(Camera_Y_pos_bias).w,d0
		blo.s	loc_6602
		subi.w	#64,d0
		bhs.s	loc_6602
		tst.b	(Camera_Max_Y_Pos_Changing).w
		bne.s	loc_6614
		clr.w	(a4)
		rts
; ---------------------------------------------------------------------------

loc_65B8:
		sub.w	(Camera_Y_pos_bias).w,d0
		bne.s	loc_65C8
		tst.b	(Camera_Max_Y_Pos_Changing).w
		bne.s	loc_6614

; loc_65C4:
		clr.w	(a4)
		rts
; ---------------------------------------------------------------------------

loc_65C8:
		cmpi.w	#$60,(Camera_Y_pos_bias).w
		bne.s	loc_65F0
		move.w	obInertia(a0),d1
		bpl.s	loc_65D8
		neg.w	d1

loc_65D8:
		cmpi.w	#$800,d1
		bhs.s	loc_6602
		move.w	#$600,d1
		cmpi.w	#6,d0
		bgt.s	loc_665C
		cmpi.w	#-6,d0
		blt.s	loc_662A
		bra.s	loc_661A
; ---------------------------------------------------------------------------

loc_65F0:
		move.w	#$200,d1
		cmpi.w	#2,d0
		bgt.s	loc_665C
		cmpi.w	#-2,d0
		blt.s	loc_662A
		bra.s	loc_661A
; ---------------------------------------------------------------------------

loc_6602:
		move.w	#$1000,d1
		cmpi.w	#16,d0
		bgt.s	loc_665C
		cmpi.w	#-16,d0
		blt.s	loc_662A
		bra.s	loc_661A
; ---------------------------------------------------------------------------

loc_6614:
		moveq	#0,d0
		move.b	d0,(Camera_Max_Y_Pos_Changing).w

loc_661A:
		moveq	#0,d1
		move.w	d0,d1
		add.w	(a1),d1
		tst.w	d0
		bpl.w	loc_6664
		bra.w	loc_6634
; ---------------------------------------------------------------------------

loc_662A:
		neg.w	d1
		ext.l	d1
		asl.l	#8,d1
		add.l	(a1),d1
		swap	d1

loc_6634:
		cmp.w	(Camera_Min_Y_pos).w,d1
		bgt.s	loc_6686
		cmpi.w	#$FF00,d1
		bgt.s	loc_6656
		andi.w	#$7FF,d1
		andi.w	#$7FF,obY(a0)
		andi.w	#$7FF,(a1)
		andi.w	#$3FF,obX(a1)
		bra.s	loc_6686
; ---------------------------------------------------------------------------

loc_6656:
		move.w	(Camera_Min_Y_pos).w,d1
		bra.s	loc_6686
; ---------------------------------------------------------------------------

loc_665C:
		ext.l	d1
		asl.l	#8,d1
		add.l	(a1),d1
		swap	d1

loc_6664:
		cmp.w	(Camera_Max_Y_pos).w,d1
		blt.s	loc_6686
		subi.w	#$800,d1
		blo.s	loc_6682
		andi.w	#$7FF,obY(a0)
		subi.w	#$800,(a1)
		andi.w	#$3FF,obX(a1)
		bra.s	loc_6686
; ---------------------------------------------------------------------------

loc_6682:
		move.w	(Camera_Max_Y_pos).w,d1

loc_6686:
		move.w	(a1),d4
		swap	d1
		move.l	d1,d3
		sub.l	(a1),d3
		ror.l	#8,d3
		move.w	d3,(a4)
		move.l	d1,(a1)
		move.w	(a1),d0
		andi.w	#16,d0
		move.b	(a2),d1
		eor.b	d1,d0
		bne.s	locret_66B4
		eori.b	#16,(a2)
		move.w	(a1),d0
		sub.w	d4,d0
		bpl.s	loc_66B0
		bset	#0,(a3)
		rts
; ---------------------------------------------------------------------------

loc_66B0:
		bset	#1,(a3)

locret_66B4:
		rts
; End of function ScrollVertical


; =============== S U B R O U T I N E =======================================


ScrollBlock1:
		move.l	(Camera_BG_X_pos).w,d2
		move.l	d2,d0
		add.l	d4,d0
		move.l	d0,(Camera_BG_X_pos).w
		move.l	d0,d1
		swap	d1
		andi.w	#16,d1
		move.b	(Horiz_block_crossed_flag_BG).w,d3
		eor.b	d3,d1
		bne.s	loc_66EA
		eori.b	#16,(Horiz_block_crossed_flag_BG).w
		sub.l	d2,d0
		bpl.s	loc_66E4
		bset	#2,(Scroll_flags_BG).w
		bra.s	loc_66EA
; ---------------------------------------------------------------------------

loc_66E4:
		bset	#3,(Scroll_flags_BG).w

loc_66EA:
		move.l	(Camera_BG_Y_pos).w,d3
		move.l	d3,d0
		add.l	d5,d0
		move.l	d0,(Camera_BG_Y_pos).w
		move.l	d0,d1
		swap	d1
		andi.w	#16,d1
		move.b	(Verti_block_crossed_flag_BG).w,d2
		eor.b	d2,d1
		bne.s	locret_671E
		eori.b	#16,(Verti_block_crossed_flag_BG).w
		sub.l	d3,d0
		bpl.s	loc_6718
		bset	#0,(Scroll_flags_BG).w
		rts
; ---------------------------------------------------------------------------

loc_6718:
		bset	#1,(Scroll_flags_BG).w

locret_671E:
		rts
; End of function ScrollBlock1


; =============== S U B R O U T I N E =======================================


ScrollBlock2:
		move.l	(Camera_BG_Y_pos).w,d3
		move.l	d3,d0
		add.l	d5,d0
		move.l	d0,(Camera_BG_Y_pos).w
		move.l	d0,d1
		swap	d1
		andi.w	#16,d1
		move.b	(Verti_block_crossed_flag_BG).w,d2
		eor.b	d2,d1
		bne.s	locret_6752
		eori.b	#16,(Verti_block_crossed_flag_BG).w
		sub.l	d3,d0
		bpl.s	loc_674C
		bset	d6,(Scroll_flags_BG).w
		rts
; ---------------------------------------------------------------------------

loc_674C:
		addq.b	#1,d6
		bset	d6,(Scroll_flags_BG).w

locret_6752:
		rts
; End of function ScrollBlock2

; ---------------------------------------------------------------------------

ScrollBlock3:
		move.w	(Camera_BG_Y_pos).w,d3
		move.w	d0,(Camera_BG_Y_pos).w
		move.w	d0,d1
		andi.w	#16,d1
		move.b	(Verti_block_crossed_flag_BG).w,d2
		eor.b	d2,d1
		bne.s	locret_6782
		eori.b	#16,(Verti_block_crossed_flag_BG).w
		sub.w	d3,d0
		bpl.s	loc_677C
		bset	#0,(Scroll_flags_BG).w
		rts
; ---------------------------------------------------------------------------

loc_677C:
		bset	#1,(Scroll_flags_BG).w

locret_6782:
		rts

; =============== S U B R O U T I N E =======================================


ScrollBlock4:
		move.l	(Camera_BG_X_pos).w,d2
		move.l	d2,d0
		add.l	d4,d0
		move.l	d0,(Camera_BG_X_pos).w
		move.l	d0,d1
		swap	d1
		andi.w	#16,d1
		move.b	(Horiz_block_crossed_flag_BG).w,d3
		eor.b	d3,d1
		bne.s	locret_67B6
		eori.b	#16,(Horiz_block_crossed_flag_BG).w
		sub.l	d2,d0
		bpl.s	loc_67B0
		bset	d6,(Scroll_flags_BG).w
		rts
; ---------------------------------------------------------------------------

loc_67B0:
		addq.b	#1,d6
		bset	d6,(Scroll_flags_BG).w

locret_67B6:
		rts
; End of function ScrollBlock4


; =============== S U B R O U T I N E =======================================


ScrollBlock5:
		move.l	(Camera_BG2_X_pos).w,d2
		move.l	d2,d0
		add.l	d4,d0
		move.l	d0,(Camera_BG2_X_pos).w
		move.l	d0,d1
		swap	d1
		andi.w	#16,d1
		move.b	(Horiz_block_crossed_flag_BG2).w,d3
		eor.b	d3,d1
		bne.s	locret_67EA
		eori.b	#16,(Horiz_block_crossed_flag_BG2).w
		sub.l	d2,d0
		bpl.s	loc_67E4
		bset	d6,(Scroll_flags_BG2).w
		rts
; ---------------------------------------------------------------------------

loc_67E4:
		addq.b	#1,d6
		bset	d6,(Scroll_flags_BG2).w

locret_67EA:
		rts
; End of function ScrollBlock5


; =============== S U B R O U T I N E =======================================


ScrollBlock6:
		move.l	(Camera_BG3_X_pos).w,d2
		move.l	d2,d0
		add.l	d4,d0
		move.l	d0,(Camera_BG3_X_pos).w
		move.l	d0,d1
		swap	d1
		andi.w	#16,d1
		move.b	(Horiz_block_crossed_flag_BG3).w,d3
		eor.b	d3,d1
		bne.s	locret_681E
		eori.b	#16,(Horiz_block_crossed_flag_BG3).w
		sub.l	d2,d0
		bpl.s	loc_6818
		bset	d6,(Scroll_flags_BG3).w
		rts
; ---------------------------------------------------------------------------

loc_6818:
		addq.b	#1,d6
		bset	d6,(Scroll_flags_BG3).w

locret_681E:
		rts
; End of function ScrollBlock6

; =============== S U B R O U T I N E =======================================


LoadTilesAsYouMove:
		lea	(vdp_control_port).l,a5
		lea	(vdp_data_port).l,a6
		; First, update the background
		lea	(Scroll_flags_BG_copy).w,a2
		lea	(Camera_BG_copy).w,a3
		lea	(v_lvllayoutbg).w,a4
		move.w	#$6000,d2
		bsr.w	DrawBGScrollBlock1
		lea	(Scroll_flags_BG2_copy).w,a2
		lea	(Camera_BG2_copy).w,a3
		bsr.w	DrawBGScrollBlock2
		; REV01 added a third scroll block, though, technically,
		; the RAM for it was already there in REV00
		lea	(Scroll_flags_BG3_copy).w,a2
		lea	(Camera_BG3_copy).w,a3
		bsr.w	DrawBGScrollBlock3
		; Then, update the foreground
		lea	(Scroll_flags_copy).w,a2
		lea	(Camera_RAM_copy).w,a3
		lea	(v_lvllayout).w,a4
		move.w	#$4000,d2
		; The FG's update function is inlined here
		tst.b	(Screen_redraw_flag).w
		beq.s	loc_68E6
		clr.b	(Screen_redraw_flag).w
		moveq	#-16,d4
		moveq	#((224+16+16)/16)-1,d6

loc_68BE:
		movem.l	d4-d6,-(sp)
		moveq	#-16,d5
		move.w	d4,d1
		bsr.w	Calc_VRAM_Pos
		move.w	d1,d4
		moveq	#-16,d5
		bsr.w	DrawBlocks_LR
		movem.l	(sp)+,d4-d6
		addi.w	#16,d4
		dbf	d6,loc_68BE
		clr.b	(Scroll_flags_copy).w
		rts
; ---------------------------------------------------------------------------
; Draw_FG:
loc_68E6:
		tst.b	(a2)
		beq.s	locret_694A
		bclr	#0,(a2)
		beq.s	loc_6900
		moveq	#-16,d4
		moveq	#-16,d5
		bsr.w	Calc_VRAM_Pos
		moveq	#-16,d4
		moveq	#-16,d5
		bsr.w	DrawBlocks_LR

loc_6900:
		bclr	#1,(a2)
		beq.s	loc_691A
		move.w	#224,d4
		moveq	#-16,d5
		bsr.w	Calc_VRAM_Pos
		move.w	#224,d4
		moveq	#-16,d5
		bsr.w	DrawBlocks_LR

loc_691A:
		bclr	#2,(a2)
		beq.s	loc_6930
		moveq	#-16,d4
		moveq	#-16,d5
		bsr.w	Calc_VRAM_Pos
		moveq	#-16,d4
		moveq	#-16,d5
		bsr.w	sub_6CFE

loc_6930:
		bclr	#3,(a2)
		beq.s	locret_694A
		moveq	#-16,d4
		move.w	#320,d5
		bsr.w	Calc_VRAM_Pos
		moveq	#-16,d4
		move.w	#320,d5
		bra.w	sub_6CFE

locret_694A:
		rts
; End of function LoadTilesAsYouMove


; =============== S U B R O U T I N E =======================================


sub_694C:
		tst.b	(a2)
		beq.s	locret_69B0
		bclr	#0,(a2)
		beq.s	loc_6966
		moveq	#-16,d4
		moveq	#-16,d5
		bsr.w	sub_70C0
		moveq	#-16,d4
		moveq	#-16,d5
		bsr.w	DrawBlocks_LR

loc_6966:
		bclr	#1,(a2)
		beq.s	loc_6980
		move.w	#224,d4
		moveq	#-16,d5
		bsr.w	sub_70C0
		move.w	#224,d4
		moveq	#-16,d5
		bsr.w	DrawBlocks_LR

loc_6980:
		bclr	#2,(a2)
		beq.s	loc_6996
		moveq	#-16,d4
		moveq	#-16,d5
		bsr.w	sub_70C0
		moveq	#-16,d4
		moveq	#-16,d5
		bsr.w	sub_6CFE

loc_6996:
		bclr	#3,(a2)
		beq.s	locret_69B0
		moveq	#-16,d4
		move.w	#320,d5
		bsr.w	sub_70C0
		moveq	#-16,d4
		move.w	#320,d5
		bra.w	sub_6CFE

locret_69B0:
		rts
; End of function sub_694C


; =============== S U B R O U T I N E =======================================

DrawBGScrollBlock1:
		tst.b	(a2)
		beq.w	locret_6A80
		bclr	#0,(a2)
		beq.s	loc_69CE
		moveq	#-16,d4
		moveq	#-16,d5
		bsr.w	Calc_VRAM_Pos
		moveq	#-16,d4
		moveq	#-16,d5
		bsr.w	DrawBlocks_LR

loc_69CE:
		bclr	#1,(a2)
		beq.s	loc_69E8
		move.w	#224,d4
		moveq	#-16,d5
		bsr.w	Calc_VRAM_Pos
		move.w	#224,d4
		moveq	#-16,d5
		bsr.w	DrawBlocks_LR

loc_69E8:
		bclr	#2,(a2)
		beq.s	loc_69FE
		moveq	#-16,d4
		moveq	#-16,d5
		bsr.w	Calc_VRAM_Pos
		moveq	#-16,d4
		moveq	#-16,d5
		bsr.w	sub_6CFE

loc_69FE:
		bclr	#3,(a2)
		beq.s	loc_6A18
		moveq	#-16,d4
		move.w	#320,d5
		bsr.w	Calc_VRAM_Pos
		moveq	#-16,d4
		move.w	#320,d5
		bsr.w	sub_6CFE

loc_6A18:
		bclr	#4,(a2)
		beq.s	loc_6A30
		moveq	#-16,d4
		moveq	#0,d5
		bsr.w	Calc_VRAM_Pos_2
		moveq	#-16,d4
		moveq	#0,d5
		moveq	#(512/16)-1,d6
		bsr.w	DrawBlocks_LR_3

loc_6A30:
		bclr	#5,(a2)
		beq.s	loc_6A4C
		move.w	#224,d4
		moveq	#0,d5
		bsr.w	Calc_VRAM_Pos_2
		move.w	#224,d4
		moveq	#0,d5
		moveq	#(512/16)-1,d6
		bsr.w	DrawBlocks_LR_3

loc_6A4C:
		bclr	#6,(a2)
		beq.s	loc_6A64
		moveq	#-16,d4
		moveq	#-16,d5
		bsr.w	Calc_VRAM_Pos
		moveq	#-16,d4
		moveq	#-16,d5
		moveq	#(512/16)-1,d6
		bsr.w	DrawBlocks_LR_2

loc_6A64:
		bclr	#7,(a2)
		beq.s	locret_6A80
		move.w	#224,d4
		moveq	#-16,d5
		bsr.w	Calc_VRAM_Pos
		move.w	#224,d4
		moveq	#-16,d5
		moveq	#(512/16)-1,d6
		bra.w	DrawBlocks_LR_2

locret_6A80:
		rts
; End of function DrawBGScrollBlock1


; =============== S U B R O U T I N E =======================================


DrawBGScrollBlock2:
		tst.b	(a2)
		beq.w	locret_6ACE
		cmpi.b	#id_SBZ,(Current_Zone).w
		beq.w	Draw_SBz
		bclr	#0,(a2)
		beq.s	loc_6AAE
		move.w	#224/2,d4
		moveq	#-16,d5
		bsr.w	Calc_VRAM_Pos
		move.w	#224/2,d4
		moveq	#-16,d5
		moveq	#3-1,d6
		bsr.w	DrawBlocks_TB_2

loc_6AAE:
		bclr	#1,(a2)
		beq.s	locret_6ACE
		move.w	#224/2,d4
		move.w	#320,d5
		bsr.w	Calc_VRAM_Pos
		move.w	#224/2,d4
		move.w	#320,d5
		moveq	#3-1,d6
		bra.w	DrawBlocks_TB_2

locret_6ACE:
		rts
; ---------------------------------------------------------------------------
byte_6AD0:
		dc.b   0
		dc.b   0,  0,  0,  0,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  4,  4
		dc.b   4,  4,  4,  4,  4,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2
		even
; ---------------------------------------------------------------------------

Draw_SBz:
		moveq	#-16,d4
		bclr	#0,(a2)
		bne.s	loc_6B04
		bclr	#1,(a2)
		beq.s	loc_6B4C
		move.w	#224,d4

loc_6B04:
		lea	byte_6AD0+1(pc),a0
		move.w	(Camera_BG_Y_pos).w,d0
		add.w	d4,d0
		andi.w	#$1F0,d0
		lsr.w	#4,d0
		move.b	(a0,d0.w),d0
		lea	(word_6C78).l,a3
		movea.w	(a3,d0.w),a3
		beq.s	loc_6B38
		moveq	#-16,d5
		movem.l	d4-d5,-(sp)
		bsr.w	Calc_VRAM_Pos
		movem.l	(sp)+,d4-d5
		bsr.w	DrawBlocks_LR
		bra.s	loc_6B4C
; ---------------------------------------------------------------------------

loc_6B38:
		moveq	#0,d5
		movem.l	d4-d5,-(sp)
		bsr.w	Calc_VRAM_Pos_2
		movem.l	(sp)+,d4-d5
		moveq	#(512/16)-1,d6
		bsr.w	DrawBlocks_LR_3

loc_6B4C:
		tst.b	(a2)
		bne.s	loc_6B52
		rts
; ---------------------------------------------------------------------------

loc_6B52:
		moveq	#-16,d4
		moveq	#-16,d5
		move.b	(a2),d0
		andi.b	#$A8,d0
		beq.s	loc_6B66
		lsr.b	#1,d0
		move.b	d0,(a2)
		move.w	#320,d5

loc_6B66:
		lea	byte_6AD0(pc),a0
		move.w	(Camera_BG_Y_pos).w,d0
		andi.w	#$1F0,d0
		lsr.w	#4,d0
		lea	(a0,d0.w),a0
		bra.w	loc_6C80
; End of function DrawBGScrollBlock2


; =============== S U B R O U T I N E =======================================


DrawBGScrollBlock3:
		tst.b	(a2)
		beq.w	locret_6BC8
		cmpi.b	#id_MZ,(Current_Zone).w
		beq.w	Draw_Mz
		bclr	#0,(a2)
		beq.s	loc_6BA8
		move.w	#64,d4
		moveq	#-16,d5
		bsr.w	Calc_VRAM_Pos
		move.w	#64,d4
		moveq	#-16,d5
		moveq	#3-1,d6
		bsr.w	DrawBlocks_TB_2

loc_6BA8:
		bclr	#1,(a2)
		beq.s	locret_6BC8
		move.w	#64,d4
		move.w	#320,d5
		bsr.w	Calc_VRAM_Pos
		move.w	#64,d4
		move.w	#320,d5
		moveq	#3-1,d6
		bra.w	DrawBlocks_TB_2

locret_6BC8:
		rts
; ---------------------------------------------------------------------------
byte_6BCA:	dc.b 0
		dc.b   2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2
		dc.b   2,  2,  2,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4
		dc.b   4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4
		dc.b   4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4
		even
; ---------------------------------------------------------------------------

Draw_Mz:
		moveq	#-16,d4
		bclr	#0,(a2)
		bne.s	loc_6C1E
		bclr	#1,(a2)
		beq.s	loc_6C48
		move.w	#224,d4

loc_6C1E:
		lea	byte_6BCA+1(pc),a0
		move.w	(Camera_BG_Y_pos).w,d0
		add.w	d4,d0
		andi.w	#$3F0,d0
		lsr.w	#4,d0
		move.b	(a0,d0.w),d0
		movea.w	word_6C78(pc,d0.w),a3
		moveq	#-16,d5
		movem.l	d4-d5,-(sp)
		bsr.w	Calc_VRAM_Pos
		movem.l	(sp)+,d4-d5
		bsr.w	DrawBlocks_LR

loc_6C48:
		tst.b	(a2)
		bne.s	loc_6C4E
		rts
; ---------------------------------------------------------------------------

loc_6C4E:
		moveq	#-16,d4
		moveq	#-16,d5
		move.b	(a2),d0
		andi.b	#$A8,d0
		beq.s	loc_6C62
		lsr.b	#1,d0
		move.b	d0,(a2)
		move.w	#320,d5

loc_6C62:
		lea	byte_6BCA(pc),a0
		move.w	(Camera_BG_Y_pos).w,d0
		andi.w	#$7F0,d0
		lsr.w	#4,d0
		lea	(a0,d0.w),a0
		bra.s	loc_6C80
; ---------------------------------------------------------------------------
word_6C78:	dc.w Camera_BG_copy
		dc.w Camera_BG_copy
		dc.w Camera_BG2_copy
		dc.w Camera_BG3_copy
; ---------------------------------------------------------------------------

loc_6C80:
		moveq	#16-1,d6
		move.l	#$800000,d7

loc_6C8E:
		moveq	#0,d0
		move.b	(a0)+,d0
		btst	d0,(a2)
		beq.s	loc_6CB6
		movea.w	word_6C78(pc,d0.w),a3
		movem.l	d4-d5/a0,-(sp)
		movem.l	d4-d5,-(sp)
		bsr.w	GetBlockData
		movem.l	(sp)+,d4-d5
		bsr.w	Calc_VRAM_Pos
		bsr.w	sub_6F70
		movem.l	(sp)+,d4-d5/a0

loc_6CB6:
		addi.w	#16,d4
		dbf	d6,loc_6C8E
		clr.b	(a2)
		rts
; End of function DrawBGScrollBlock3


; =============== S U B R O U T I N E =======================================


sub_6CFE:
		moveq	#16-1,d6
; End of function sub_6CFE


; =============== S U B R O U T I N E =======================================


DrawBlocks_TB_2:
		add.w	(a3),d5
		add.w	4(a3),d4
		move.l	#$800000,d7
		move.l	d0,d1
		bsr.w	sub_6E98

loc_6D18:
		move.w	(a0),d3
		andi.w	#$3FF,d3
		lsl.w	#3,d3
		lea	(v_16x16).w,a1
		adda.w	d3,a1
		move.l	d1,d0
		bsr.w	sub_6F70
		adda.w	#16,a0
		addi.w	#$100,d1
		andi.w	#$FFF,d1
		addi.w	#16,d4
		move.w	d4,d0
		andi.w	#$70,d0
		bne.s	loc_6D48
		bsr.w	sub_6E98

loc_6D48:
		dbf	d6,loc_6D18
		rts
; End of function DrawBlocks_TB_2


; =============== S U B R O U T I N E =======================================


DrawBlocks_LR_2:
		add.w	(a3),d5
		add.w	4(a3),d4
		bra.s	loc_6D94
; End of function DrawBlocks_LR_2


; =============== S U B R O U T I N E =======================================


DrawBlocks_LR:
		moveq	#(1+320/16+1)-1,d6 ; Just enough blocks to cover the screen.
		add.w	(a3),d5
; End of function DrawBlocks_LR


; =============== S U B R O U T I N E =======================================


DrawBlocks_LR_3:
		add.w	4(a3),d4

loc_6D94:
		move.l	a2,-(sp)
		move.w	d6,-(sp)
		lea	(Block_cache).w,a2
		move.l	d0,d1
		or.w	d2,d1
		swap	d1
		move.l	d1,-(sp)
		move.l	d1,(a5)
		swap	d1
		bsr.w	sub_6E98

loc_6DB2:
		move.w	(a0),d3
		andi.w	#$3FF,d3
		lsl.w	#3,d3
		lea	(v_16x16).w,a1
		adda.w	d3,a1
		bsr.w	sub_6ED0
		addq.w	#2,a0
		addq.b	#4,d1
		bpl.s	loc_6DD4
		andi.b	#$7F,d1
		swap	d1
		move.l	d1,(a5)
		swap	d1

loc_6DD4:
		addi.w	#$10,d5
		move.w	d5,d0
		andi.w	#$70,d0
		bne.s	loc_6DE4
		bsr.s	sub_6E98

loc_6DE4:
		dbf	d6,loc_6DB2
		move.l	(sp)+,d1
		addi.l	#$800000,d1
		lea	(Block_cache).w,a2
		move.l	d1,(a5)
		swap	d1
		move.w	(sp)+,d6

loc_6DFA:
		move.l	(a2)+,(a6)
		addq.b	#4,d1
		bmi.s	loc_6E0A
		ori.b	#$80,d1
		swap	d1
		move.l	d1,(a5)
		swap	d1

loc_6E0A:
		dbf	d6,loc_6DFA
		movea.l	(sp)+,a2
		rts
; End of function DrawBlocks_LR_3


; =============== S U B R O U T I N E =======================================


sub_6E98:
		movem.l	d4-d5,-(sp)
		move.w	d4,d3
		add.w	d3,d3
		andi.w	#$F00,d3
		lsr.w	#3,d5
		move.w	d5,d0
		lsr.w	#4,d0
		andi.w	#$7F,d0
		add.w	d3,d0
		moveq	#-1,d3
		move.b	(a4,d0.w),d3
		andi.w	#$FF,d3
		lsl.w	#7,d3
		andi.w	#$70,d4
		andi.w	#$E,d5
		add.w	d4,d3
		add.w	d5,d3
		movea.l	d3,a0
		movem.l	(sp)+,d4-d5
		rts
; End of function sub_6E98


; =============== S U B R O U T I N E =======================================


sub_6ED0:
		btst	#3,(a0)
		bne.s	loc_6EFC
		btst	#2,(a0)
		bne.s	loc_6EE2
		move.l	(a1)+,(a6)
		move.l	(a1)+,(a2)+
		rts
; ---------------------------------------------------------------------------

loc_6EE2:
		move.l	(a1)+,d3
		eori.l	#$8000800,d3
		swap	d3
		move.l	d3,(a6)
		move.l	(a1)+,d3
		eori.l	#$8000800,d3
		swap	d3
		move.l	d3,(a2)+
		rts
; ---------------------------------------------------------------------------

loc_6EFC:
		btst	#2,(a0)
		bne.s	loc_6F18
		move.l	(a1)+,d0
		move.l	(a1)+,d3
		eori.l	#$10001000,d3
		move.l	d3,(a6)
		eori.l	#$10001000,d0
		move.l	d0,(a2)+
		rts
; ---------------------------------------------------------------------------

loc_6F18:
		move.l	(a1)+,d0
		move.l	(a1)+,d3
		eori.l	#$18001800,d3
		swap	d3
		move.l	d3,(a6)
		eori.l	#$18001800,d0
		swap	d0
		move.l	d0,(a2)+
		rts
; End of function sub_6ED0


; =============== S U B R O U T I N E =======================================


sub_6F32:
		btst	#3,(a0)
		bne.s	loc_6F50
		btst	#2,(a0)
		bne.s	loc_6F42
		move.l	(a1)+,(a6)
		rts
; ---------------------------------------------------------------------------

loc_6F42:
		move.l	(a1)+,d3
		eori.l	#$8000800,d3
		swap	d3
		move.l	d3,(a6)
		rts
; ---------------------------------------------------------------------------

loc_6F50:
		btst	#2,(a0)
		bne.s	loc_6F62
		move.l	(a1)+,d3
		eori.l	#$10001000,d3
		move.l	d3,(a6)
		rts
; ---------------------------------------------------------------------------

loc_6F62:
		move.l	(a1)+,d3
		eori.l	#$18001800,d3
		swap	d3
		move.l	d3,(a6)
		rts
; End of function sub_6F32


; =============== S U B R O U T I N E =======================================


sub_6F70:
		or.w	d2,d0
		swap	d0
		btst	#3,(a0)
		bne.s	loc_6FAC
		btst	#2,(a0)
		bne.s	loc_6F8C
		move.l	d0,(a5)
		move.l	(a1)+,(a6)
		add.l	d7,d0
		move.l	d0,(a5)
		move.l	(a1)+,(a6)
		rts
; ---------------------------------------------------------------------------

loc_6F8C:
		move.l	d0,(a5)
		move.l	(a1)+,d3
		eori.l	#$8000800,d3
		swap	d3
		move.l	d3,(a6)
		add.l	d7,d0
		move.l	d0,(a5)
		move.l	(a1)+,d3
		eori.l	#$8000800,d3
		swap	d3
		move.l	d3,(a6)
		rts
; ---------------------------------------------------------------------------

loc_6FAC:
		btst	#2,(a0)
		bne.s	loc_6FD2
		move.l	d5,-(sp)
		move.l	d0,(a5)
		move.l	(a1)+,d5
		move.l	(a1)+,d3
		eori.l	#$10001000,d3
		move.l	d3,(a6)
		add.l	d7,d0
		move.l	d0,(a5)
		eori.l	#$10001000,d5
		move.l	d5,(a6)
		move.l	(sp)+,d5
		rts
; ---------------------------------------------------------------------------

loc_6FD2:
		move.l	d5,-(sp)
		move.l	d0,(a5)
		move.l	(a1)+,d5
		move.l	(a1)+,d3
		eori.l	#$18001800,d3
		swap	d3
		move.l	d3,(a6)
		add.l	d7,d0
		move.l	d0,(a5)
		eori.l	#$18001800,d5
		swap	d5
		move.l	d5,(a6)
		move.l	(sp)+,d5
		rts
; End of function sub_6F70


; =============== S U B R O U T I N E =======================================


DrawBlock:
		or.w	d2,d0
		swap	d0
		btst	#3,(a0)
		bne.s	DrawFlipY
		btst	#2,(a0)
		bne.s	DrawFlipX
		move.l	d0,(a5)
		move.l	(a1)+,(a6)
		rts
; ---------------------------------------------------------------------------

DrawFlipX:
		move.l	d0,(a5)
		move.l	(a1)+,d3
		eori.l	#$8000800,d3
		swap	d3
		move.l	d3,(a6)
		rts
; ---------------------------------------------------------------------------

DrawFlipY:
		btst	#2,(a0)
		bne.s	DrawFlipXY
		move.l	d0,(a5)
		move.l	(a1)+,d3
		eori.l	#$10001000,d3
		move.l	d3,(a6)
		rts
; ---------------------------------------------------------------------------

DrawFlipXY:
		move.l	d0,(a5)
		move.l	(a1)+,d3
		eori.l	#$18001800,d3
		swap	d3
		move.l	d3,(a6)
		rts
; End of function DrawBlock


; =============== S U B R O U T I N E =======================================


GetBlockData:
		add.w	(a3),d5
		add.w	4(a3),d4
		lea	(v_16x16).w,a1
		move.w	d4,d3
		add.w	d3,d3
		andi.w	#$F00,d3
		lsr.w	#3,d5
		move.w	d5,d0
		lsr.w	#4,d0
		andi.w	#$7F,d0
		add.w	d3,d0
		moveq	#-1,d3
		move.b	(a4,d0.w),d3
		andi.w	#$FF,d3
		lsl.w	#7,d3
		andi.w	#$70,d4
		andi.w	#$E,d5
		add.w	d4,d3
		add.w	d5,d3
		movea.l	d3,a0
		move.w	(a0),d3
		andi.w	#$3FF,d3
		lsl.w	#3,d3
		adda.w	d3,a1
		rts
; End of function GetBlockData


; =============== S U B R O U T I N E =======================================
; sub_7084:
Calc_VRAM_Pos:
		add.w	(a3),d5

Calc_VRAM_Pos_2:
		add.w	4(a3),d4
		andi.w	#$F0,d4
		andi.w	#$1F0,d5
		lsl.w	#4,d4
		lsr.w	#2,d5
		add.w	d5,d4
		moveq	#3,d0
		swap	d0
		move.w	d4,d0
		rts
; End of function Calc_VRAM_Pos_2


; =============== S U B R O U T I N E =======================================


sub_70C0:
		add.w	4(a3),d4
		add.w	(a3),d5
		andi.w	#$F0,d4
		andi.w	#$1F0,d5
		lsl.w	#4,d4
		lsr.w	#2,d5
		add.w	d5,d4
		moveq	#2,d0
		swap	d0
		move.w	d4,d0
		rts
; End of function sub_70C0


; =============== S U B R O U T I N E =======================================


LoadTilesFromStart:
		lea	(vdp_control_port).l,a5
		lea	(vdp_data_port).l,a6
		lea	(Camera_RAM).w,a3
		lea	(v_lvllayout).w,a4
		move.w	#$4000,d2
		bsr.s	DrawChunks
		lea	(Camera_BG_X_pos).w,a3
		lea	(v_lvllayoutbg).w,a4
		move.w	#$6000,d2
		tst.b	(Current_Zone).w
		beq.w	Draw_GHz_Bg
; End of function LoadTilesFromStart


; =============== S U B R O U T I N E =======================================


DrawChunks:
		moveq	#-16,d4
		moveq	#((224+16+16)/16)-1,d6

loc_7144:
		movem.l	d4-d6,-(sp)
		moveq	#0,d5
		move.w	d4,d1
		bsr.w	Calc_VRAM_Pos
		move.w	d1,d4
		moveq	#0,d5
		moveq	#(512/16)-1,d6
		disable_ints
		bsr.w	DrawBlocks_LR_2
		enable_ints
		movem.l	(sp)+,d4-d6
		addi.w	#16,d4
		dbf	d6,loc_7144
		rts
; End of function DrawChunks


; ---------------------------------------------------------------------------

Draw_GHz_Bg:
		moveq	#0,d4
		moveq	#((224+16+16)/16)-1,d6

loc_71A4:
		movem.l	d4-d6,-(sp)
		lea	(byte_71CA).l,a0
		move.w	(Camera_BG_Y_pos).w,d0
		add.w	d4,d0
		andi.w	#$F0,d0
		bsr.w	sub_7232
		movem.l	(sp)+,d4-d6
		addi.w	#16,d4
		dbf	d6,loc_71A4
		rts
; ---------------------------------------------------------------------------
byte_71CA:	dc.b   0,  0,  0,  0,  6,  6,  6,  4,  4,  4,  0,  0,  0,  0,  0,  0
; ---------------------------------------------------------------------------
; Draw_Mz_Bg:
		moveq	#-16,d4
		moveq	#((224+16+16)/16)-1,d6

loc_71DE:
		movem.l	d4-d6,-(sp)
		lea	byte_6BCA+1(pc),a0
		move.w	(Camera_BG_Y_pos).w,d0
		add.w	d4,d0
		andi.w	#$3F0,d0
		bsr.w	sub_7232
		movem.l	(sp)+,d4-d6
		addi.w	#16,d4
		dbf	d6,loc_71DE
		rts
; ---------------------------------------------------------------------------
; Draw_SBz_Bg:
		moveq	#-16,d4
		moveq	#((224+16+16)/16)-1,d6

loc_7206:
		movem.l	d4-d6,-(sp)
		lea	byte_6AD0+1(pc),a0
		move.w	(Camera_BG_Y_pos).w,d0
		add.w	d4,d0
		andi.w	#$1F0,d0
		bsr.w	sub_7232
		movem.l	(sp)+,d4-d6
		addi.w	#16,d4
		dbf	d6,loc_7206
		rts
; ---------------------------------------------------------------------------
word_722A:	dc.w Camera_BG_X_pos
		dc.w Camera_BG_X_pos
		dc.w Camera_BG2_X_pos
		dc.w Camera_BG3_X_pos

; =============== S U B R O U T I N E =======================================


sub_7232:
		lsr.w	#4,d0
		move.b	(a0,d0.w),d0
		movea.w	word_722A(pc,d0.w),a3
		beq.s	loc_725A
		moveq	#-16,d5
		movem.l	d4-d5,-(sp)
		bsr.w	Calc_VRAM_Pos
		movem.l	(sp)+,d4-d5
		disable_ints
		bsr.w	DrawBlocks_LR
		enable_ints
		rts
; ---------------------------------------------------------------------------

loc_725A:
		moveq	#0,d5
		movem.l	d4-d5,-(sp)
		bsr.w	Calc_VRAM_Pos_2
		movem.l	(sp)+,d4-d5
		moveq	#(512/16)-1,d6
		bra.w	DrawBlocks_LR_3
; End of function sub_7232


; =============== S U B R O U T I N E =======================================


DynScreenResizeLoad:
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
		add.w	d0,d0
		move.w	DynResize_Index(pc,d0.w),d0
		jsr	DynResize_Index(pc,d0.w) ; run level-specific events
		moveq	#2,d1
		move.w	(Camera_Max_Y_pos_target).w,d0
		sub.w	(Camera_Max_Y_pos).w,d0 ; has the lower level boundary changed recently?
		beq.s	locret_756A	; if not, branch
		bhs.s	loc_756C
		neg.w	d1
		move.w	(Camera_Y_pos).w,d0
		cmp.w	(Camera_Max_Y_pos_target).w,d0
		bls.s	loc_7560
		move.w	d0,(Camera_Max_Y_pos).w
		andi.w	#-2,(Camera_Max_Y_pos).w

loc_7560:
		add.w	d1,(Camera_Max_Y_pos).w
		move.b	#1,(Camera_Max_Y_Pos_Changing).w

locret_756A:
		rts
; ---------------------------------------------------------------------------

loc_756C:
		move.w	(Camera_Y_pos).w,d0
		addq.w	#8,d0
		cmp.w	(Camera_Max_Y_pos).w,d0
		blo.s	loc_7586
		btst	#1,(v_player+obStatus).w
		beq.s	loc_7586
		add.w	d1,d1
		add.w	d1,d1

loc_7586:
		add.w	d1,(Camera_Max_Y_pos).w
		move.b	#1,(Camera_Max_Y_Pos_Changing).w
		rts
; End of function DynScreenResizeLoad

; ---------------------------------------------------------------------------
DynResize_Index:
		dc.w DynResize_GHZ-DynResize_Index
		dc.w DynResize_LZ-DynResize_Index
		dc.w DynResize_CPZ-DynResize_Index
		dc.w DynResize_EHZ-DynResize_Index
		dc.w DynResize_HPZ-DynResize_Index
		dc.w DynResize_HTZ-DynResize_Index
		dc.w DynResize_S1Ending-DynResize_Index
; ---------------------------------------------------------------------------

DynResize_GHZ:
		moveq	#0,d0
		move.b	(Current_Act).w,d0
		add.w	d0,d0
		move.w	DynResize_GHZ_Index(pc,d0.w),d0
		jmp	DynResize_GHZ_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynResize_GHZ_Index:
		dc.w DynResize_GHZ1-DynResize_GHZ_Index
		dc.w DynResize_GHZ2-DynResize_GHZ_Index
		dc.w DynResize_GHZ3-DynResize_GHZ_Index
		dc.w DynResize_GHZ4-DynResize_GHZ_Index	; Filler
; ---------------------------------------------------------------------------

DynResize_GHZ1:
		move.w	#$300,(Camera_Max_Y_pos_target).w
		cmpi.w	#$1780,(Camera_RAM).w
		blo.s	locret_75CA
		move.w	#$400,(Camera_Max_Y_pos_target).w

locret_75CA:
		rts
; ---------------------------------------------------------------------------

DynResize_GHZ2:
		move.w	#$300,(Camera_Max_Y_pos_target).w
		cmpi.w	#$ED0,(Camera_RAM).w
		blo.s	locret_75FC
		move.w	#$200,(Camera_Max_Y_pos_target).w
		cmpi.w	#$1600,(Camera_RAM).w
		blo.s	locret_75FC
		move.w	#$400,(Camera_Max_Y_pos_target).w
		cmpi.w	#$1D60,(Camera_RAM).w
		blo.s	locret_75FC
		move.w	#$300,(Camera_Max_Y_pos_target).w

locret_75FC:
		rts
; ---------------------------------------------------------------------------

DynResize_GHZ3:
		moveq	#0,d0
		move.b	(Dynamic_Resize_Routine).w,d0
		move.w	DynResize_GHZ3_Index(pc,d0.w),d0
		jmp	DynResize_GHZ3_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynResize_GHZ3_Index:
		dc.w DynResize_GHZ3_Main-DynResize_GHZ3_Index
		dc.w DynResize_GHZ3_Boss-DynResize_GHZ3_Index
		dc.w DynResize_GHZ3_End-DynResize_GHZ3_Index
; ---------------------------------------------------------------------------

DynResize_GHZ3_Main:
		move.w	#$300,(Camera_Max_Y_pos_target).w
		cmpi.w	#$380,(Camera_RAM).w
		blo.s	locret_7658
		move.w	#$310,(Camera_Max_Y_pos_target).w
		cmpi.w	#$960,(Camera_RAM).w
		blo.s	locret_7658
		cmpi.w	#$280,(Camera_Y_pos).w
		blo.s	loc_765A
		move.w	#$400,(Camera_Max_Y_pos_target).w
		cmpi.w	#$1380,(Camera_RAM).w
		bhs.s	loc_7650
		move.w	#$4C0,(Camera_Max_Y_pos_target).w
		move.w	#$4C0,(Camera_Max_Y_pos).w

loc_7650:
		cmpi.w	#$1700,(Camera_RAM).w
		bhs.s	loc_765A

locret_7658:
		rts
; ---------------------------------------------------------------------------

loc_765A:
		move.w	#$300,(Camera_Max_Y_pos_target).w
		addq.b	#2,(Dynamic_Resize_Routine).w
		rts
; ---------------------------------------------------------------------------

DynResize_GHZ3_Boss:
		cmpi.w	#$960,(Camera_RAM).w
		bhs.s	loc_7672
		subq.b	#2,(Dynamic_Resize_Routine).w

loc_7672:
		cmpi.w	#$2960,(Camera_RAM).w
		blo.s	locret_76AA
		bsr.w	FindFreeObj
		bne.s	loc_7692
		_move.b	#id_Obj3D,obID(a1)
		move.w	#$2A60,obX(a1)
		move.w	#$280,obY(a1)

loc_7692:
		move.w	#bgm_Boss,d0
		jsr	(PlaySound).l
		move.b	#1,(f_lockscreen).w
		addq.b	#2,(Dynamic_Resize_Routine).w
		moveq	#plcid_Boss,d0
		jmp	(LoadPLC).l
; ---------------------------------------------------------------------------

locret_76AA:
		rts
; ---------------------------------------------------------------------------

DynResize_GHZ3_End:
		move.w	(Camera_RAM).w,(Camera_Min_X_pos).w
		rts
; ---------------------------------------------------------------------------

DynResize_GHZ4:
		rts
; ---------------------------------------------------------------------------

DynResize_LZ:
		moveq	#0,d0
		move.b	(Current_Act).w,d0
		add.w	d0,d0
		move.w	DynResize_LZ_Index(pc,d0.w),d0
		jmp	DynResize_LZ_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynResize_LZ_Index:
		dc.w DynResize_LZ1-DynResize_LZ_Index
		dc.w DynResize_LZ2-DynResize_LZ_Index
		dc.w DynResize_LZ3-DynResize_LZ_Index
		dc.w DynResize_LZ4-DynResize_LZ_Index
; ---------------------------------------------------------------------------

DynResize_LZ1:
		rts
; ---------------------------------------------------------------------------

DynResize_LZ2:
		rts
; ---------------------------------------------------------------------------

DynResize_LZ3:
		tst.b	(f_switch+$F).w
		beq.s	loc_76EA
		lea	(v_lvllayout+$206).w,a1
		cmpi.b	#7,(a1)
		beq.s	loc_76EA
		move.b	#7,(a1)
		move.w	#sfx_Rumbling,d0
		jsr	(PlaySound_Special).l

loc_76EA:
		tst.b	(Dynamic_Resize_Routine).w
		bne.s	locret_7724
		cmpi.w	#$1CA0,(Camera_RAM).w
		blo.s	locret_7724
		cmpi.w	#$600,(Camera_Y_pos).w
		bhs.s	locret_7724
		bsr.w	FindFreeObj
		bne.s	loc_770C
		_move.b	#id_Obj77,obID(a1)

loc_770C:
		move.w	#bgm_Boss,d0
		jsr	(PlaySound).l
		move.b	#1,(f_lockscreen).w
		addq.b	#2,(Dynamic_Resize_Routine).w
		moveq	#plcid_Boss,d0
		jmp	(LoadPLC).l
; ---------------------------------------------------------------------------

locret_7724:
		rts
; ---------------------------------------------------------------------------

DynResize_LZ4:
		cmpi.w	#$D00,(Camera_RAM).w
		blo.s	locret_774E
		cmpi.w	#$18,(v_player+obY).w
		bhs.s	locret_774E
		clr.b	(v_lastlamp).w
		move.w	#1,(Level_Inactive_flag).w
		move.w	#(id_SBZ<<8)+2,(Current_ZoneAndAct).w
		move.b	#1,(f_playerctrl).w

locret_774E:
		rts
; ---------------------------------------------------------------------------

DynResize_CPZ:
		moveq	#0,d0
		move.b	(Current_Act).w,d0
		add.w	d0,d0
		move.w	DynResize_CPZ_Index(pc,d0.w),d0
		jmp	DynResize_CPZ_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynResize_CPZ_Index:
		dc.w DynResize_CPZ1-DynResize_CPZ_Index
		dc.w DynResize_CPZ2-DynResize_CPZ_Index
		dc.w DynResize_CPZ3-DynResize_CPZ_Index
		dc.w DynResize_CPZ4-DynResize_CPZ_Index
; ---------------------------------------------------------------------------

DynResize_CPZ1:
		rts
; ---------------------------------------------------------------------------

DynResize_CPZ2:
		rts
; ===========================================================================

DynResize_CPZ3:
		moveq	#0,d0
		move.b	(Dynamic_Resize_Routine).w,d0
		move.w	DynCPZ3_Index(pc,d0.w),d0
		jmp	DynCPZ3_Index(pc,d0.w)
; ===========================================================================
DynCPZ3_Index:
		dc.w DynResize_CPZ3_BossCheck-DynCPZ3_Index
		dc.w DynResize_CPZ3_Null-DynCPZ3_Index
; ===========================================================================

DynResize_CPZ3_BossCheck:
		cmpi.w	#$480,(Camera_RAM).w
		blt.s	DynResize_CPZ3_Null
		cmpi.w	#$740,(Camera_RAM).w
		bgt.s	DynResize_CPZ3_Null
		move.w	(Camera_Max_Y_pos).w,d0
		cmp.w	(Camera_Y_pos).w,d0
		bne.s	DynResize_CPZ3_Null
		move.w	#$740,(Camera_Max_X_pos).w
		move.w	#$480,(Camera_Min_X_pos).w
		addq.b	#2,(Dynamic_Resize_Routine).w
		bsr.w	FindFreeObj
		bne.s	DynResize_CPZ3_Null
		_move.b	#id_Obj55,obID(a1)			; load Obj55 (EHZ boss, likely CPZ boss at one point)
		move.w	#$680,obX(a1)
		move.w	#$540,obY(a1)
		moveq	#plcid_Boss,d0
		jmp	(LoadPLC).l
; ---------------------------------------------------------------------------

DynResize_CPZ3_Null:
		rts
; ---------------------------------------------------------------------------

DynResize_CPZ4:
		rts
; ---------------------------------------------------------------------------

DynResize_EHZ:
		moveq	#0,d0
		move.b	(Current_Act).w,d0
		add.w	d0,d0
		move.w	DynResize_EHZ_Index(pc,d0.w),d0
		jmp	DynResize_EHZ_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynResize_EHZ_Index:
		dc.w DynResize_EHZ1-DynResize_EHZ_Index
		dc.w DynResize_EHZ2-DynResize_EHZ_Index
		dc.w DynResize_EHZ3-DynResize_EHZ_Index
		dc.w DynResize_EHZ4-DynResize_EHZ_Index
; ---------------------------------------------------------------------------

DynResize_EHZ1:
		rts
; ---------------------------------------------------------------------------

DynResize_EHZ2:
		moveq	#0,d0
		move.b	(Dynamic_Resize_Routine).w,d0
		move.w	DynResize_EHZ2_Index(pc,d0.w),d0
		jmp	DynResize_EHZ2_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynResize_EHZ2_Index:
		dc.w DynResize_EHZ2_01-DynResize_EHZ2_Index
		dc.w DynResize_EHZ2_02-DynResize_EHZ2_Index
		dc.w DynResize_EHZ2_03-DynResize_EHZ2_Index
; ---------------------------------------------------------------------------

DynResize_EHZ2_01:
		cmpi.w	#$26E0,(Camera_RAM).w
		blo.s	locret_795A
		move.w	(Camera_RAM).w,(Camera_Min_X_pos).w
		move.w	#$390,(Camera_Max_Y_pos_target).w
		move.w	#$390,(Camera_Max_Y_pos).w
		addq.b	#2,(Dynamic_Resize_Routine).w
		bsr.w	FindFreeObj
		bne.s	loc_7946
		_move.b	#id_Obj55,obID(a1)	; load EHZ Boss object
		move.b	#$81,obSubtype(a1)
		move.w	#$29D0,obX(a1)
		move.w	#$426,obY(a1)

loc_7946:
		move.w	#bgm_Boss,d0
		jsr	(PlaySound).l
		move.b	#1,(f_lockscreen).w
		moveq	#plcid_Boss,d0
		jmp	(LoadPLC).l
; ---------------------------------------------------------------------------

locret_795A:
		rts
; ---------------------------------------------------------------------------

DynResize_EHZ2_02:
		cmpi.w	#$2880,(Camera_RAM).w
		blo.s	+
		move.w	#$2880,(Camera_Min_X_pos).w
		addq.b	#2,(Dynamic_Resize_Routine).w
+
		rts
; ---------------------------------------------------------------------------

DynResize_EHZ2_03:
		tst.b	(Boss_defeated_flag).w
		beq.s	+
		move.w	#SegaScreen,(v_gamemode).w
+
		rts
; ---------------------------------------------------------------------------

DynResize_EHZ3:
		rts
; ---------------------------------------------------------------------------

DynResize_EHZ4:
		rts
; ---------------------------------------------------------------------------

DynResize_HPZ:	; Misnomer, this is Spring Yard's DynResize
		moveq	#0,d0
		move.b	(Current_Act).w,d0
		add.w	d0,d0
		move.w	DynResize_HPZ_Index(pc,d0.w),d0
		jmp	DynResize_HPZ_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynResize_HPZ_Index:
		dc.w DynResize_HPZ1-DynResize_HPZ_Index
		dc.w DynResize_HPZ2-DynResize_HPZ_Index
		dc.w DynResize_HPZ3-DynResize_HPZ_Index
		dc.w DynResize_HPZ4-DynResize_HPZ_Index
; ---------------------------------------------------------------------------

DynResize_HPZ1:
		rts
; ---------------------------------------------------------------------------

DynResize_HPZ2:
		move.w	#$520,(Camera_Max_Y_pos_target).w
		cmpi.w	#$25A0,(Camera_RAM).w
		blo.s	locret_7A1A
		move.w	#$420,(Camera_Max_Y_pos_target).w
		cmpi.w	#$4D0,(v_player+obY).w
		blo.s	locret_7A1A
		move.w	#$520,(Camera_Max_Y_pos_target).w

locret_7A1A:
		rts
; ---------------------------------------------------------------------------

DynResize_HPZ3:
		moveq	#0,d0
		move.b	(Dynamic_Resize_Routine).w,d0
		move.w	DynResize_HPZ3_Index(pc,d0.w),d0
		jmp	DynResize_HPZ3_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynResize_HPZ3_Index:
		dc.w DynResize_HPZ3_Main-DynResize_HPZ3_Index
		dc.w DynResize_HPZ3_Boss-DynResize_HPZ3_Index
		dc.w DynResize_HPZ3_End-DynResize_HPZ3_Index
; ---------------------------------------------------------------------------

DynResize_HPZ3_Main:
		cmpi.w	#$2AC0,(Camera_RAM).w
		blo.s	locret_7A46
		bsr.w	FindFreeObj
		bne.s	locret_7A46
		_move.b	#id_Obj76,obID(a1)	; load object 76
		addq.b	#2,(Dynamic_Resize_Routine).w

locret_7A46:
		rts
; ---------------------------------------------------------------------------

DynResize_HPZ3_Boss:
		cmpi.w	#$2C00,(Camera_RAM).w
		blo.s	locret_7A78
		move.w	#$4CC,(Camera_Max_Y_pos_target).w
		bsr.w	FindFreeObj
		bne.s	loc_7A64
		_move.b	#id_Obj75,obID(a1)	; load object 75
		addq.b	#2,(Dynamic_Resize_Routine).w

loc_7A64:
		move.w	#bgm_Boss,d0
		jsr	(PlaySound).l
		move.b	#1,(f_lockscreen).w
		moveq	#plcid_Boss,d0
		jmp	(LoadPLC).l
; ---------------------------------------------------------------------------

locret_7A78:
		rts
; ---------------------------------------------------------------------------

DynResize_HPZ3_End:
		move.w	(Camera_RAM).w,(Camera_Min_X_pos).w
		rts
; ---------------------------------------------------------------------------

DynResize_HPZ4:
		rts
; ---------------------------------------------------------------------------

DynResize_HTZ:	; Misnomer, this is Scrap brain's DynResize
		moveq	#0,d0
		move.b	(Current_Act).w,d0
		add.w	d0,d0
		move.w	DynResize_HTZ_Index(pc,d0.w),d0
		jmp	DynResize_HTZ_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynResize_HTZ_Index:
		dc.w DynResize_HTZ1-DynResize_HTZ_Index
		dc.w DynResize_HTZ2-DynResize_HTZ_Index
		dc.w DynResize_HTZ3-DynResize_HTZ_Index
		dc.w DynResize_HTZ4-DynResize_HTZ_Index
; ---------------------------------------------------------------------------

DynResize_HTZ1:
		move.w	#$720,(Camera_Max_Y_pos_target).w
		cmpi.w	#$1880,(Camera_RAM).w
		blo.s	locret_7ABA
		move.w	#$620,(Camera_Max_Y_pos_target).w
		cmpi.w	#$2000,(Camera_RAM).w
		blo.s	locret_7ABA
		move.w	#$2A0,(Camera_Max_Y_pos_target).w

locret_7ABA:
		rts
; ---------------------------------------------------------------------------

DynResize_HTZ2:
		moveq	#0,d0
		move.b	(Dynamic_Resize_Routine).w,d0
		move.w	DynResize_HTZ2_Index(pc,d0.w),d0
		jmp	DynResize_HTZ2_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynResize_HTZ2_Index:
		dc.w loc_7AD2-DynResize_HTZ2_Index
		dc.w loc_7AF4-DynResize_HTZ2_Index
		dc.w loc_7B12-DynResize_HTZ2_Index
		dc.w loc_7B30-DynResize_HTZ2_Index
; ---------------------------------------------------------------------------

loc_7AD2:
		move.w	#$800,(Camera_Max_Y_pos_target).w
		cmpi.w	#$1800,(Camera_RAM).w
		blo.s	locret_7AF2
		move.w	#$510,(Camera_Max_Y_pos_target).w
		cmpi.w	#$1E00,(Camera_RAM).w
		blo.s	locret_7AF2
		addq.b	#2,(Dynamic_Resize_Routine).w

locret_7AF2:
		rts
; ---------------------------------------------------------------------------

loc_7AF4:
		cmpi.w	#$1EB0,(Camera_RAM).w
		blo.s	locret_7B10
		bsr.w	FindFreeObj
		bne.s	locret_7B10
		_move.b	#id_Obj83,obID(a1) ; load object 83 (collapsing block object in S1)
		addq.b	#2,(Dynamic_Resize_Routine).w
		moveq	#plcid_EggmanSBZ2,d0
		jmp	(LoadPLC).l		; load SBZ2 Eggman patterns
; ---------------------------------------------------------------------------

locret_7B10:
		rts
; ---------------------------------------------------------------------------

loc_7B12:
		cmpi.w	#$1F60,(Camera_RAM).w
		blo.s	loc_7B2E
		bsr.w	FindFreeObj
		bne.s	loc_7B28
		_move.b	#id_Obj82,obID(a1)	; load object 82 (SBZ Eggman in S1)
		addq.b	#2,(Dynamic_Resize_Routine).w

loc_7B28:
		move.b	#1,(f_lockscreen).w

loc_7B2E:
		move.w	(Camera_RAM).w,(Camera_Min_X_pos).w
		rts
; ---------------------------------------------------------------------------

loc_7B30:
		cmpi.w	#$2050,(Camera_RAM).w
		blo.s	loc_7B3A
		rts
; ---------------------------------------------------------------------------

loc_7B3A:
		move.w	(Camera_RAM).w,(Camera_Min_X_pos).w
		rts
; ---------------------------------------------------------------------------

DynResize_HTZ3:
		moveq	#0,d0
		move.b	(Dynamic_Resize_Routine).w,d0
		move.w	DynResize_HTZ3_Index(pc,d0.w),d0
		jmp	DynResize_HTZ3_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynResize_HTZ3_Index:
		dc.w DynResize_HTZ3_Main-DynResize_HTZ3_Index
		dc.w DynResize_HTZ3_Boss-DynResize_HTZ3_Index
		dc.w DynResize_HTZ3_End-DynResize_HTZ3_Index
		dc.w DynResize_HTZ3_Null-DynResize_HTZ3_Index
		dc.w DynResize_HTZ3_End2-DynResize_HTZ3_Index
; ---------------------------------------------------------------------------

DynResize_HTZ3_Main:
		cmpi.w	#$2148,(Camera_RAM).w
		blo.s	loc_7B6C
		addq.b	#2,(Dynamic_Resize_Routine).w
		moveq	#plcid_FZBoss,d0
		jsr	(LoadPLC).l

loc_7B6C:
		move.w	(Camera_RAM).w,(Camera_Min_X_pos).w
		rts
; ---------------------------------------------------------------------------

DynResize_HTZ3_Boss:
		cmpi.w	#$2300,(Camera_RAM).w
		blo.s	loc_7B8A
		bsr.w	FindFreeObj
		bne.s	loc_7B8A
		_move.b	#id_Obj85,obID(a1)	; load object 85 (final boss object)
		addq.b	#2,(Dynamic_Resize_Routine).w
		move.b	#1,(f_lockscreen).w

loc_7B8A:
		move.w	(Camera_RAM).w,(Camera_Min_X_pos).w
		rts
; ---------------------------------------------------------------------------

DynResize_HTZ3_End:
		cmpi.w	#$2450,(Camera_RAM).w
		blo.s	loc_7B98
		addq.b	#2,(Dynamic_Resize_Routine).w

loc_7B98:
		move.w	(Camera_RAM).w,(Camera_Min_X_pos).w
		rts
; ---------------------------------------------------------------------------

DynResize_HTZ3_Null:
		rts
; ---------------------------------------------------------------------------

DynResize_HTZ3_End2:
		move.w	(Camera_RAM).w,(Camera_Min_X_pos).w
		rts
; ---------------------------------------------------------------------------

DynResize_HTZ4:
		rts
; ---------------------------------------------------------------------------

DynResize_S1Ending:
		rts
; ---------------------------------------------------------------------------

DynResize_MZ:
		moveq	#0,d0
		move.b	(Current_Act).w,d0
		add.w	d0,d0
		move.w	DynResize_MZ_Index(pc,d0.w),d0
		jmp	DynResize_MZ_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynResize_MZ_Index:
		dc.w DynResize_MZ1-DynResize_MZ_Index
		dc.w DynResize_MZ2-DynResize_MZ_Index
		dc.w DynResize_MZ3-DynResize_MZ_Index
		dc.w DynResize_MZ4-DynResize_MZ_Index
; ---------------------------------------------------------------------------

DynResize_MZ1:					; leftover from Sonic 1
		moveq	#0,d0
		move.b	(Dynamic_Resize_Routine).w,d0
		move.w	DynMZ1_Index(pc,d0.w),d0
		jmp	DynMZ1_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynMZ1_Index:
		dc.w loc_777E-DynMZ1_Index
		dc.w loc_77AE-DynMZ1_Index
		dc.w loc_77F2-DynMZ1_Index
		dc.w loc_781C-DynMZ1_Index
; ---------------------------------------------------------------------------

loc_777E:
		move.w	#$1D0,(Camera_Max_Y_pos_target).w
		cmpi.w	#$700,(Camera_RAM).w
		blo.s	+
		move.w	#$220,(Camera_Max_Y_pos_target).w
		cmpi.w	#$D00,(Camera_RAM).w
		blo.s	+
		move.w	#$340,(Camera_Max_Y_pos_target).w
		cmpi.w	#$340,(Camera_Y_pos).w
		blo.s	+
		addq.b	#2,(Dynamic_Resize_Routine).w
+
		rts
; ---------------------------------------------------------------------------

loc_77AE:
		cmpi.w	#$340,(Camera_Y_pos).w
		bhs.s	loc_77BC
		subq.b	#2,(Dynamic_Resize_Routine).w
		rts
; ---------------------------------------------------------------------------

loc_77BC:
		clr.w	(Camera_Min_Y_pos).w
		cmpi.w	#$E00,(Camera_RAM).w
		bhs.s	+
		move.w	#$340,(Camera_Min_Y_pos).w
		move.w	#$340,(Camera_Max_Y_pos_target).w
		cmpi.w	#$A90,(Camera_RAM).w
		bhs.s	+
		move.w	#$500,(Camera_Max_Y_pos_target).w
		cmpi.w	#$370,(Camera_Y_pos).w
		blo.s	+
		addq.b	#2,(Dynamic_Resize_Routine).w
+
		rts
; ---------------------------------------------------------------------------

loc_77F2:
		cmpi.w	#$370,(Camera_Y_pos).w
		bhs.s	loc_7800
		subq.b	#2,(Dynamic_Resize_Routine).w
		rts
; ---------------------------------------------------------------------------

loc_7800:
		cmpi.w	#$500,(Camera_Y_pos).w
		blo.s	+
		cmpi.w	#$B80,(Camera_RAM).w
		blo.s	+
		move.w	#$500,(Camera_Min_Y_pos).w
		addq.b	#2,(Dynamic_Resize_Routine).w
+
		rts
; ---------------------------------------------------------------------------

loc_781C:
		cmpi.w	#$B80,(Camera_RAM).w
		bhs.s	loc_7832
		cmpi.w	#$340,(Camera_Min_Y_pos).w
		beq.s	locret_786A
		subq.w	#2,(Camera_Min_Y_pos).w
		rts
; ---------------------------------------------------------------------------

loc_7832:
		cmpi.w	#$500,(Camera_Min_Y_pos).w
		beq.s	loc_7848
		cmpi.w	#$500,(Camera_Y_pos).w
		blo.s	locret_786A
		move.w	#$500,(Camera_Min_Y_pos).w

loc_7848:
		cmpi.w	#$E70,(Camera_RAM).w
		blo.s	locret_786A
		clr.w	(Camera_Min_Y_pos).w
		move.w	#$500,(Camera_Max_Y_pos_target).w
		cmpi.w	#$1430,(Camera_RAM).w
		blo.s	locret_786A
		move.w	#$210,(Camera_Max_Y_pos_target).w

locret_786A:
		rts
; ---------------------------------------------------------------------------

DynResize_MZ2:					; leftover from Sonic 1
		move.w	#$520,(Camera_Max_Y_pos_target).w
		cmpi.w	#$1700,(Camera_X_pos).w
		blo.s	+
		move.w	#$200,(Camera_Max_Y_pos_target).w
+
		rts
; ---------------------------------------------------------------------------

DynResize_MZ3:					; leftover from Sonic 1
		moveq	#0,d0
		move.b	(Dynamic_Resize_Routine).w,d0
		move.w	DynMZ3_Index(pc,d0.w),d0
		jmp	DynMZ3_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynMZ3_Index:
		dc.w DynResize_MZ3Boss-DynMZ3_Index
		dc.w DynResize_MZ3End-DynMZ3_Index
; ---------------------------------------------------------------------------

DynResize_MZ3Boss:
		move.w	#$720,(Camera_Max_Y_pos_target).w
		cmpi.w	#$1560,(Camera_X_pos).w
		bcs.s	.return
		move.w	#$210,(Camera_Max_Y_pos_target).w
		cmpi.w	#$17F0,(Camera_X_pos).w
		bcs.s	.return
		bsr.w	FindFreeObj
		bne.s	+
		_move.b	#id_Obj55,obID(a1)			; load Obj55 (EHZ boss, Placeholder)
		move.w	#$19F0,obX(a1)
		move.w	#$22C,obY(a1)
+
		move.w	#bgm_Boss,d0
		jsr	(PlaySound).l	; play boss music
		move.b	#1,(f_lockscreen).w ; lock screen
		addq.b	#2,(Dynamic_Resize_Routine).w
		moveq	#plcid_Boss,d0
		jmp	(LoadPLC).l
; ---------------------------------------------------------------------------

.return:
		rts
; ---------------------------------------------------------------------------

DynResize_MZ3End:
		move.w	(Camera_RAM).w,(Camera_Min_X_pos).w
		rts
; ---------------------------------------------------------------------------

DynResize_MZ4:
		rts
; ---------------------------------------------------------------------------

DynResize_SLZ:
		moveq	#0,d0
		move.b	(Current_Act).w,d0
		add.w	d0,d0
		move.w	DynResize_SLZ_Index(pc,d0.w),d0
		jmp	DynResize_SLZ_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynResize_SLZ_Index:
		dc.w DynResize_SLZ1-DynResize_SLZ_Index
		dc.w DynResize_SLZ2-DynResize_SLZ_Index
		dc.w DynResize_SLZ3-DynResize_SLZ_Index
		dc.w DynResize_SLZ4-DynResize_SLZ_Index
; ---------------------------------------------------------------------------

DynResize_SLZ1:
		rts
; ---------------------------------------------------------------------------

DynResize_SLZ2:
		rts
; ---------------------------------------------------------------------------

DynResize_SLZ3:					; leftover from Sonic 1
		moveq	#0,d0
		move.b	(Dynamic_Resize_Routine).w,d0
		move.w	DynSLZ3_Index(pc,d0.w),d0
		jmp	DynSLZ3_Index(pc,d0.w)
; ---------------------------------------------------------------------------
DynSLZ3_Index:
		dc.w loc_7996-DynSLZ3_Index
		dc.w loc_79AA-DynSLZ3_Index
		dc.w loc_79D6-DynSLZ3_Index
; ---------------------------------------------------------------------------

loc_7996:
		cmpi.w	#$1E70,(Camera_RAM).w
		blo.s	+
		move.w	#$210,(Camera_Max_Y_pos_target).w
		addq.b	#2,(Dynamic_Resize_Routine).w
+
		rts
; ---------------------------------------------------------------------------

loc_79AA:
		cmpi.w	#$2000,(Camera_RAM).w
		blo.s	locret_79D4
		bsr.w	FindFreeObj
		bne.s	loc_79BC
		_move.b	#id_Obj7A,obID(a1)	; load object 7A

loc_79BC:
		move.w	#bgm_Boss,d0
		jsr	(PlaySound).l
		move.b	#1,(f_lockscreen).w
		addq.b	#2,(Dynamic_Resize_Routine).w
		moveq	#plcid_Boss,d0
		jmp	(LoadPLC).l
; ---------------------------------------------------------------------------

locret_79D4:
		rts
; ---------------------------------------------------------------------------

loc_79D6:
		move.w	(Camera_RAM).w,(Camera_Min_X_pos).w
		rts
; ---------------------------------------------------------------------------

DynResize_SLZ4:
		rts
; ---------------------------------------------------------------------------
		include	"objects/25 & 37 Rings.asm"
Ani_Obj25:	dc.w byte_ABEC-Ani_Obj25
byte_ABEC:	dc.b   5,  4,  5,  6,  7,$FC
		even
; ===========================================================================
; ---------------------------------------------------------------------------
; sprite mappings
; ---------------------------------------------------------------------------
Map_Ring:	binclude	"mappings/sprite/obj37_a.bin"
		even

		include	"objects/26 Monitor.asm"
		include	"objects/29 Monitor Content Power-Up.asm"

; =============== S U B R O U T I N E =======================================


Obj26_SolidSides:
		lea	(v_player).w,a1
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	loc_B20E
		move.w	d1,d3
		add.w	d3,d3
		cmp.w	d3,d0
		bhi.s	loc_B20E
		move.b	obHeight(a1),d3
		ext.w	d3
		add.w	d3,d2
		move.w	obY(a1),d3
		sub.w	obY(a0),d3
		add.w	d2,d3
		bmi.s	loc_B20E
		add.w	d2,d2
		cmp.w	d2,d3
		bhs.s	loc_B20E
		tst.b	(f_playerctrl).w
		bmi.s	loc_B20E
		cmpi.b	#6,(v_player+obRoutine).w
		bhs.s	loc_B20E
		tst.w	(Debug_placement_mode).w
		bne.s	loc_B20E
		cmp.w	d0,d1
		bhs.s	loc_B204
		add.w	d1,d1
		sub.w	d1,d0

loc_B204:
		cmpi.w	#$10,d3
		blo.s	loc_B212

loc_B20A:
		moveq	#1,d1
		rts
; ---------------------------------------------------------------------------

loc_B20E:
		moveq	#0,d1
		rts
; ---------------------------------------------------------------------------

loc_B212:
		moveq	#0,d1
		move.b	obActWid(a0),d1
		addq.w	#4,d1
		move.w	d1,d2
		add.w	d2,d2
		add.w	obX(a1),d1
		sub.w	obX(a0),d1
		bmi.s	loc_B20A
		cmp.w	d2,d1
		bhs.s	loc_B20A
		moveq	#-1,d1
		rts
; End of function Obj26_SolidSides

; ===========================================================================
; animation script
Ani_obj26:	dc.w byte_B246-Ani_obj26
		dc.w byte_B24A-Ani_obj26
		dc.w byte_B252-Ani_obj26
		dc.w byte_B25A-Ani_obj26
		dc.w byte_B262-Ani_obj26
		dc.w byte_B26A-Ani_obj26
		dc.w byte_B272-Ani_obj26
		dc.w byte_B27A-Ani_obj26
		dc.w byte_B282-Ani_obj26
		dc.w byte_B28A-Ani_obj26
		dc.w byte_B292-Ani_obj26
byte_B246:	dc.b   1,  0,  1,$FF
byte_B24A:	dc.b   1,  0,  2,  2,  1,  2,  2,$FF
byte_B252:	dc.b   1,  0,  3,  3,  1,  3,  3,$FF
byte_B25A:	dc.b   1,  0,  4,  4,  1,  4,  4,$FF
byte_B262:	dc.b   1,  0,  5,  5,  1,  5,  5,$FF
byte_B26A:	dc.b   1,  0,  6,  6,  1,  6,  6,$FF
byte_B272:	dc.b   1,  0,  7,  7,  1,  7,  7,$FF
byte_B27A:	dc.b   1,  0,  8,  8,  1,  8,  8,$FF
byte_B282:	dc.b   1,  0,  9,  9,  1,  9,  9,$FF
byte_B28A:	dc.b   1,  0, $A, $A,  1, $A, $A,$FF
byte_B292:	dc.b   2,  0,  1, $B,$FE,  1
		even

; ---------------------------------------------------------------------------
; sprite mappings
; ---------------------------------------------------------------------------
Map_Obj26:	binclude	"mappings/sprite/obj26.bin"
		even
; ---------------------------------------------------------------------------
		include	"objects/28 Animals.asm"
		include	"objects/2A Points.asm"
; ---------------------------------------------------------------------------
Map_Obj28a:
		dc.w word_A006-Map_Obj28a
		dc.w word_A010-Map_Obj28a
		dc.w word_9FFC-Map_Obj28a
word_9FFC:	dc.w 1
		dc.w $F406,    0,    0,$FFF8
word_A006:	dc.w 1
		dc.w $F406,    6,    3,$FFF8
word_A010:	dc.w 1
		dc.w $F406,   $C,    6,$FFF8
Map_Obj28:
		dc.w word_A02A-Map_Obj28
		dc.w word_A034-Map_Obj28
		dc.w word_A020-Map_Obj28
word_A020:	dc.w 1
		dc.w $F406,    0,    0,$FFF8
word_A02A:	dc.w 1
		dc.w $FC05,    6,    3,$FFF8
word_A034:	dc.w 1
		dc.w $FC05,   $A,    5,$FFF8
Map_Obj28b:
		dc.w word_A04E-Map_Obj28b
		dc.w word_A058-Map_Obj28b
		dc.w word_A044-Map_Obj28b
word_A044:	dc.w 1
		dc.w $F406,    0,    0,$FFF8
word_A04E:	dc.w 1
		dc.w $FC09,    6,    3,$FFF4
word_A058:	dc.w 1
		dc.w $FC09,   $C,    6,$FFF4
Map_Obj2A:
		dc.w word_A070-Map_Obj2A
		dc.w word_A07A-Map_Obj2A
		dc.w word_A084-Map_Obj2A
		dc.w word_A08E-Map_Obj2A
		dc.w word_A0A0-Map_Obj2A
		dc.w word_A0AA-Map_Obj2A
		dc.w word_A0BC-Map_Obj2A
word_A070:	dc.w 1
		dc.w $F805,    2,    1,$FFF8
word_A07A:	dc.w 1
		dc.w $F805,    6,    3,$FFF8
word_A084:	dc.w 1
		dc.w $F805,   $A,    5,$FFF8
word_A08E:	dc.w 2
		dc.w $F801,    0,    0,$FFF8
		dc.w $F805,   $E,    7,	   0
word_A0A0:	dc.w 1
		dc.w $F801,    0,    0,$FFFC
word_A0AA:	dc.w 2
		dc.w $F805,    2,    1,$FFF0
		dc.w $F805,   $E,    7,	   0
word_A0BC:	dc.w 2
		dc.w $F805,   $A,    5,$FFF0
		dc.w $F805,   $E,    7,	   0
		even
; ---------------------------------------------------------------------------
		include	"objects/S1/24, 27 & 3F Explosions.asm"
; ---------------------------------------------------------------------------
Map_GroundExplosion:
		binclude	"mappings/sprite/Ground Explosion.bin"
		even
Map_Obj27:
		dc.w word_9A26-Map_Obj27
		dc.w word_9A30-Map_Obj27
		dc.w word_9A3A-Map_Obj27
		dc.w word_9A44-Map_Obj27
		dc.w word_9A66-Map_Obj27
word_9A26:	dc.w 1
		dc.w $F809,    0,    0,$FFF4
word_9A30:	dc.w 1
		dc.w $F00F,    6,    3,$FFF0
word_9A3A:	dc.w 1
		dc.w $F00F,  $16,   $B,$FFF0
word_9A44:	dc.w 4
		dc.w $EC0A,  $26,  $13,$FFEC
		dc.w $EC05,  $2F,  $17,	   4
		dc.w  $405,$182F,$1817,$FFEC
		dc.w $FC0A,$1826,$1813,$FFFC
word_9A66:	dc.w 4
		dc.w $EC0A,  $33,  $19,$FFEC
		dc.w $EC05,  $3C,  $1E,	   4
		dc.w  $405,$183C,$181E,$FFEC
		dc.w $FC0A,$1833,$1819,$FFFC
Map_Obj3F:
		dc.w word_9A26-Map_Obj3F
		dc.w word_9A92-Map_Obj3F
		dc.w word_9A9C-Map_Obj3F
		dc.w word_9A44-Map_Obj3F
		dc.w word_9A66-Map_Obj3F
word_9A92:	dc.w 1
		dc.w $F00F,  $40,  $20,$FFF0
word_9A9C:	dc.w 1
		dc.w $F00F,  $50,  $28,$FFF0
		even
; ---------------------------------------------------------------------------
		include	"objects/Empty Slots/10.asm"
		include	"objects/11 Bridge.asm"
; ---------------------------------------------------------------------------
; Sprite mappings - GHZ, HPZ & EHZ bridges
; ---------------------------------------------------------------------------
Map_obj11_GHZ:	binclude	"mappings/sprite/obj11_GHZ.bin"
		even
Map_obj11_HPZ:	binclude	"mappings/sprite/obj11_HPZ.bin"
		even
Map_obj11:	binclude	"mappings/sprite/obj11_EHZ.bin"
		even
; ===========================================================================

; ---------------------------------------------------------------------------
		include	"objects/15 Swinging Platforms.asm"
; ---------------------------------------------------------------------------
Map_Obj15:	dc.w word_8534-Map_Obj15
		dc.w word_8546-Map_Obj15
		dc.w word_8550-Map_Obj15
word_8534:	dc.w 2
		dc.w $F809,    4,    2,$FFE8
		dc.w $F809,    4,    2,	   0
word_8546:	dc.w 1
		dc.w $F805,    0,    0,$FFF8
word_8550:	dc.w 1
		dc.w $F805,   $A,    5,$FFF8
Map_Obj15_CPZ:	dc.w word_855C-Map_Obj15_CPZ
word_855C:	dc.w 2
		dc.w $F00F,    8,    4,$FFE0
		dc.w $F00F, $808, $804,	   0
Map_Obj15_EHZ:	dc.w word_8574-Map_Obj15_EHZ
		dc.w word_85B6-Map_Obj15_EHZ
		dc.w word_85C0-Map_Obj15_EHZ
word_8574:	dc.w 8
		dc.w $F00F,    4,    2,$FFE0
		dc.w $F00F, $804, $802,	   0
		dc.w $F005,  $14,   $A,$FFD0
		dc.w $F005, $814, $80A,	 $20
		dc.w $1004,  $18,   $C,$FFE0
		dc.w $1004, $818, $80C,	 $10
		dc.w $1001,  $1A,   $D,$FFF8
		dc.w $1001, $81A, $80D,	   0
word_85B6:	dc.w 1
		dc.w $F805,$4000,$4000,$FFF8
word_85C0:	dc.w 1
		dc.w $F805,  $1C,   $E,$FFF8
Map_Obj48:	dc.w word_85D2-Map_Obj48
		dc.w word_8604-Map_Obj48
		dc.w word_8626-Map_Obj48
		dc.w word_8648-Map_Obj48
word_85D2:	dc.w 6
		dc.w $F004,  $24,  $12,$FFF0
		dc.w $F804,$1024,$1012,$FFF0
		dc.w $E80A,    0,    0,$FFE8
		dc.w $E80A, $800, $800,	   0
		dc.w	$A,$1000,$1000,$FFE8
		dc.w	$A,$1800,$1800,	   0
word_8604:	dc.w 4
		dc.w $E80A,    9,    4,$FFE8
		dc.w $E80A, $809, $804,	   0
		dc.w	$A,$1009,$1004,$FFE8
		dc.w	$A,$1809,$1804,	   0
word_8626:	dc.w 4
		dc.w $E80A,  $12,    9,$FFE8
		dc.w $E80A,  $1B,   $D,	   0
		dc.w	$A,$181B,$180D,$FFE8
		dc.w	$A,$1812,$1809,	   0
word_8648:	dc.w 4
		dc.w $E80A, $81B, $80D,$FFE8
		dc.w $E80A, $812, $809,	   0
		dc.w	$A,$1012,$1009,$FFE8
		dc.w	$A,$101B,$100D,	   0
		even
; ---------------------------------------------------------------------------
		include	"objects/17 Spiked Pole Helix.asm"
Map_Obj17:	include	"mappings/sprite/S1/Spiked Pole Helix.asm"

		include	"objects/18 Platforms.asm"
; ---------------------------------------------------------------------------
Map_Obj18x:	dc.w word_8ADE-Map_Obj18x
		dc.w word_8AF0-Map_Obj18x
word_8ADE:	dc.w 2
		dc.w $F40B,  $3C,  $1E,$FFE8
		dc.w $F40B,  $48,  $24,	   0
word_8AF0:	dc.w $A
		dc.w $F40F,  $CA,  $65,$FFE0
		dc.w  $40F,  $DA,  $6D,$FFE0
		dc.w $240F,  $DA,  $6D,$FFE0
		dc.w $440F,  $DA,  $6D,$FFE0
		dc.w $640F,  $DA,  $6D,$FFE0
		dc.w $F40F, $8CA, $865,	   0
		dc.w  $40F, $8DA, $86D,	   0
		dc.w $240F, $8DA, $86D,	   0
		dc.w $440F, $8DA, $86D,	   0
		dc.w $640F, $8DA, $86D,	   0
Map_Obj18:	dc.w word_8B46-Map_Obj18
		dc.w word_8B68-Map_Obj18
word_8B46:	dc.w 4
		dc.w $F40B,  $3B,  $1D,$FFE0
		dc.w $F407,  $3F,  $1F,$FFF8
		dc.w $F407,  $3F,  $1F,	   8
		dc.w $F403,  $47,  $23,	 $18
word_8B68:	dc.w $A
		dc.w $F40F,  $C5,  $62,$FFE0
		dc.w  $40F,  $D5,  $6A,$FFE0
		dc.w $240F,  $D5,  $6A,$FFE0
		dc.w $440F,  $D5,  $6A,$FFE0
		dc.w $640F,  $D5,  $6A,$FFE0
		dc.w $F40F, $8C5, $862,	   0
		dc.w  $40F, $8D5, $86A,	   0
		dc.w $240F, $8D5, $86A,	   0
		dc.w $440F, $8D5, $86A,	   0
		dc.w $640F, $8D5, $86A,	   0
		dc.w	 2,    3,$F60B,	 $49
		dc.w   $24,$FFE0,$F607,	 $51
		dc.w   $28,$FFF8,$F60B,	 $55
		dc.w   $2A,    8,    2,	   2
		dc.w $F80F,  $21,  $10,$FFE0
		dc.w $F80F,  $21,  $10,	   0
		even
; ---------------------------------------------------------------------------
; Sprite mappings - EHZ platforms
; ---------------------------------------------------------------------------
Map_obj18_EHZ:	include	"mappings/sprite/18 - EHZ platforms mappings.asm"
; ---------------------------------------------------------------------------
		include	"objects/1A Collapsing Platforms.asm"
		include	"objects/S1/1B Collapsing Floors.asm"
; ---------------------------------------------------------------------------

Ledge_Fragment:
		lea	byte_8EF2(pc),a4
		cmpi.b	#id_HPZ,(Current_Zone).w
		bne.s	+
		lea	byte_8F0B(pc),a4
+		addq.b	#2,obFrame(a0)

loc_8E70:
		moveq	#0,d0
		move.b	obFrame(a0),d0
		add.w	d0,d0
		movea.l	obMap(a0),a3
		adda.w	(a3,d0.w),a3
		move.w	(a3)+,d1
		subq.w	#1,d1
		bset	#5,obRender(a0)
		_move.b	obID(a0),d4
		move.b	obRender(a0),d5
		movea.l	a0,a1
		bra.s	+
; ---------------------------------------------------------------------------
.loop		bsr.w	FindFreeObj
		bne.s	+++
		addq.w	#8,a3

+		move.b	#4,obRoutine(a1)
		_move.b	d4,obID(a1)
		move.l	a3,obMap(a1)
		move.b	d5,obRender(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.w	obPriority(a0),obPriority(a1)
		move.b	obActWid(a0),obActWid(a1)
		move.b	obHeight(a0),obHeight(a1)
		move.b	(a4)+,objoff_38(a1)
		cmpa.l	a0,a1
		bhs.s	+
		bsr.w	DisplaySprite2
+		dbf	d1,.loop

+		bsr.w	DisplaySprite
		move.w	#sfx_Collapse,d0
		jmp	(PlaySound_Special).l
; ---------------------------------------------------------------------------
byte_8EF2:	dc.b $1C,$18,$14,$10
		dc.b $1A,$16,$12, $E
		dc.b  $A,  6,$18,$14
		dc.b $10, $C,  8,  4
		dc.b $16,$12, $E, $A
		dc.b   6,  2,$14,$10
		dc.b  $C,  0
byte_8F0B:	dc.b $18,$1C,$20,$1E
		dc.b $1A,$16,  6, $E
		dc.b $14,$12, $A,  2
byte_8F17:	dc.b $1E,$16, $E,  6
		dc.b $1A,$12, $A,  2
byte_8F1F:	dc.b $16,$1E,$1A,$12
		dc.b   6, $E, $A,  2
		even

Obj1A_Conf:	binclude	"misc/GHZ Collapsing Ledge Heightmap.bin"
		even
Map_Obj1A:	dc.w word_8F60-Map_Obj1A
		dc.w word_8FE2-Map_Obj1A
		dc.w word_9064-Map_Obj1A
		dc.w word_912E-Map_Obj1A
word_8F60:	dc.w $10
		dc.w $C80E,  $57,  $2B,	 $10
		dc.w $D00D,  $63,  $31,$FFF0
		dc.w $E00D,  $6B,  $35,	 $10
		dc.w $E00D,  $73,  $39,$FFF0
		dc.w $D806,  $7B,  $3D,$FFE0
		dc.w $D806,  $81,  $40,$FFD0
		dc.w $F00D,  $87,  $43,	 $10
		dc.w $F00D,  $8F,  $47,$FFF0
		dc.w $F005,  $97,  $4B,$FFE0
		dc.w $F005,  $9B,  $4D,$FFD0
		dc.w	$D,  $9F,  $4F,	 $10
		dc.w	 5,  $A7,  $53,	   0
		dc.w	$D,  $AB,  $55,$FFE0
		dc.w	 5,  $B3,  $59,$FFD0
		dc.w $100D,  $AB,  $55,	 $10
		dc.w $1005,  $B7,  $5B,	   0
word_8FE2:	dc.w $10
		dc.w $C80E,  $57,  $2B,	 $10
		dc.w $D00D,  $63,  $31,$FFF0
		dc.w $E00D,  $6B,  $35,	 $10
		dc.w $E00D,  $73,  $39,$FFF0
		dc.w $D806,  $7B,  $3D,$FFE0
		dc.w $D806,  $BB,  $5D,$FFD0
		dc.w $F00D,  $87,  $43,	 $10
		dc.w $F00D,  $8F,  $47,$FFF0
		dc.w $F005,  $97,  $4B,$FFE0
		dc.w $F005,  $C1,  $60,$FFD0
		dc.w	$D,  $9F,  $4F,	 $10
		dc.w	 5,  $A7,  $53,	   0
		dc.w	$D,  $AB,  $55,$FFE0
		dc.w	 5,  $B7,  $5B,$FFD0
		dc.w $100D,  $AB,  $55,	 $10
		dc.w $1005,  $B7,  $5B,	   0
word_9064:	dc.w $19
		dc.w $C806,  $5D,  $2E,	 $20
		dc.w $C806,  $57,  $2B,	 $10
		dc.w $D005,  $67,  $33,	   0
		dc.w $D005,  $63,  $31,$FFF0
		dc.w $E005,  $6F,  $37,	 $20
		dc.w $E005,  $6B,  $35,	 $10
		dc.w $E005,  $77,  $3B,	   0
		dc.w $E005,  $73,  $39,$FFF0
		dc.w $D806,  $7B,  $3D,$FFE0
		dc.w $D806,  $81,  $40,$FFD0
		dc.w $F005,  $8B,  $45,	 $20
		dc.w $F005,  $87,  $43,	 $10
		dc.w $F005,  $93,  $49,	   0
		dc.w $F005,  $8F,  $47,$FFF0
		dc.w $F005,  $97,  $4B,$FFE0
		dc.w $F005,  $9B,  $4D,$FFD0
		dc.w	 5,  $8B,  $45,	 $20
		dc.w	 5,  $8B,  $45,	 $10
		dc.w	 5,  $A7,  $53,	   0
		dc.w	 5,  $AB,  $55,$FFF0
		dc.w	 5,  $AB,  $55,$FFE0
		dc.w	 5,  $B3,  $59,$FFD0
		dc.w $1005,  $AB,  $55,	 $20
		dc.w $1005,  $AB,  $55,	 $10
		dc.w $1005,  $B7,  $5B,	   0
word_912E:	dc.w $19
		dc.w $C806,  $5D,  $2E,	 $20
		dc.w $C806,  $57,  $2B,	 $10
		dc.w $D005,  $67,  $33,	   0
		dc.w $D005,  $63,  $31,$FFF0
		dc.w $E005,  $6F,  $37,	 $20
		dc.w $E005,  $6B,  $35,	 $10
		dc.w $E005,  $77,  $3B,	   0
		dc.w $E005,  $73,  $39,$FFF0
		dc.w $D806,  $7B,  $3D,$FFE0
		dc.w $D806,  $BB,  $5D,$FFD0
		dc.w $F005,  $8B,  $45,	 $20
		dc.w $F005,  $87,  $43,	 $10
		dc.w $F005,  $93,  $49,	   0
		dc.w $F005,  $8F,  $47,$FFF0
		dc.w $F005,  $97,  $4B,$FFE0
		dc.w $F005,  $C1,  $60,$FFD0
		dc.w	 5,  $8B,  $45,	 $20
		dc.w	 5,  $8B,  $45,	 $10
		dc.w	 5,  $A7,  $53,	   0
		dc.w	 5,  $AB,  $55,$FFF0
		dc.w	 5,  $AB,  $55,$FFE0
		dc.w	 5,  $B7,  $5B,$FFD0
		dc.w $1005,  $AB,  $55,	 $20
		dc.w $1005,  $AB,  $55,	 $10
		dc.w $1005,  $B7,  $5B,	   0
		even
Map_Obj1A_HPZ:	dc.w word_92FE-Map_Obj1A_HPZ
		dc.w word_9340-Map_Obj1A_HPZ
		dc.w word_9340-Map_Obj1A_HPZ
word_92FE:	dc.w 8
		dc.w $F00D,    0,    0,$FFD0
		dc.w	$D,    8,    4,$FFD0
		dc.w $F005,    4,    2,$FFF0
		dc.w $F005, $804, $802,	   0
		dc.w	 5,   $C,    6,$FFF0
		dc.w	 5, $80C, $806,	   0
		dc.w $F00D, $800, $800,	 $10
		dc.w	$D, $808, $804,	 $10
word_9340:	dc.w $C
		dc.w $F005,    0,    0,$FFD0
		dc.w $F005,    4,    2,$FFE0
		dc.w $F005,    4,    2,$FFF0
		dc.w $F005, $804, $802,	   0
		dc.w $F005, $804, $802,	 $10
		dc.w $F005, $800, $800,	 $20
		dc.w	 5,    8,    4,$FFD0
		dc.w	 5,   $C,    6,$FFE0
		dc.w	 5,   $C,    6,$FFF0
		dc.w	 5, $80C, $806,	   0
		dc.w	 5, $80C, $806,	 $10
		dc.w	 5, $808, $804,	 $20
		even
Obj1A_Conf_HPZ:
		dc.b $10,$10,$10,$10
		dc.b $10,$10,$10,$10
		dc.b $10,$10,$10,$10
		dc.b $10,$10,$10,$10
		dc.b $10,$10,$10,$10
		dc.b $10,$10,$10,$10
		dc.b $10,$10,$10,$10
		dc.b $10,$10,$10,$10
		dc.b $10,$10,$10,$10
		dc.b $10,$10,$10,$10
		dc.b $10,$10,$10,$10
		dc.b $10,$10,$10,$10
		even
Map_Obj1B:	dc.w word_9200-Map_Obj1B
		dc.w word_9222-Map_Obj1B
		dc.w word_9264-Map_Obj1B
		dc.w word_9286-Map_Obj1B
word_9200:	dc.w 4
		dc.w $F80D,    0,    0,$FFE0
		dc.w  $80D,    0,    0,$FFE0
		dc.w $F80D,    0,    0,	   0
		dc.w  $80D,    0,    0,	   0
word_9222:	dc.w 8
		dc.w $F805,    0,    0,$FFE0
		dc.w $F805,    0,    0,$FFF0
		dc.w $F805,    0,    0,	   0
		dc.w $F805,    0,    0,	 $10
		dc.w  $805,    0,    0,$FFE0
		dc.w  $805,    0,    0,$FFF0
		dc.w  $805,    0,    0,	   0
		dc.w  $805,    0,    0,	 $10
word_9264:	dc.w 4
		dc.w $F80D,    0,    0,$FFE0
		dc.w  $80D,    8,    4,$FFE0
		dc.w $F80D,    0,    0,	   0
		dc.w  $80D,    8,    4,	   0
word_9286:	dc.w 8
		dc.w $F805,    0,    0,$FFE0
		dc.w $F805,    4,    2,$FFF0
		dc.w $F805,    0,    0,	   0
		dc.w $F805,    4,    2,	 $10
		dc.w  $805,    8,    4,$FFE0
		dc.w  $805,   $C,    6,$FFF0
		dc.w  $805,    8,    4,	   0
		dc.w  $805,   $C,    6,	 $10
		even
; ---------------------------------------------------------------------------
		include	"objects/1C Scenery.asm"
Map_Obj1C_01:	include	"mappings/sprite/obj1C.asm"
; ---------------------------------------------------------------------------

		include	"objects/S1/30 SBZ Small Door.asm"
Map_Obj30:
		dc.w word_95BA-Map_Obj30
		dc.w word_95CC-Map_Obj30
		dc.w word_95DE-Map_Obj30
		dc.w word_95F0-Map_Obj30
		dc.w word_9602-Map_Obj30
		dc.w word_9614-Map_Obj30
		dc.w word_9626-Map_Obj30
		dc.w word_9638-Map_Obj30
		dc.w word_964A-Map_Obj30
word_95BA:	dc.w 2
		dc.w $E007, $800, $800,$FFF8
		dc.w	 7, $800, $800,$FFF8
word_95CC:	dc.w 2
		dc.w $DC07, $800, $800,$FFF8
		dc.w  $407, $800, $800,$FFF8
word_95DE:	dc.w 2
		dc.w $D807, $800, $800,$FFF8
		dc.w  $807, $800, $800,$FFF8
word_95F0:	dc.w 2
		dc.w $D407, $800, $800,$FFF8
		dc.w  $C07, $800, $800,$FFF8
word_9602:	dc.w 2
		dc.w $D007, $800, $800,$FFF8
		dc.w $1007, $800, $800,$FFF8
word_9614:	dc.w 2
		dc.w $CC07, $800, $800,$FFF8
		dc.w $1407, $800, $800,$FFF8
word_9626:	dc.w 2
		dc.w $C807, $800, $800,$FFF8
		dc.w $1807, $800, $800,$FFF8
word_9638:	dc.w 2
		dc.w $C407, $800, $800,$FFF8
		dc.w $1C07, $800, $800,$FFF8
word_964A:	dc.w 2
		dc.w $C007, $800, $800,$FFF8
		dc.w $2007, $800, $800,$FFF8
; ---------------------------------------------------------------------------
		include	"objects/Empty Slots/1D.asm"
		include	"objects/S1/1E Ball Hog.asm"
		include	"objects/S1/1F Crabmeat.asm"
		include	"objects/Empty Slots/20.asm"
		include	"objects/Empty Slots/21.asm"
; ---------------------------------------------------------------------------
Map_BallHogV:	binclude	"mappings/sprite/Vertical Ballhog.bin"
		even
Map_BallHogH:	binclude	"mappings/sprite/Horizontal Ballhog.bin"
		even
; ===========================================================================
; animation script
Ani_obj1F:	dc.w byte_A30C-Ani_obj1F
		dc.w byte_A30F-Ani_obj1F
		dc.w byte_A312-Ani_obj1F
		dc.w byte_A315-Ani_obj1F
		dc.w byte_A31A-Ani_obj1F
		dc.w byte_A31F-Ani_obj1F
		dc.w byte_A324-Ani_obj1F
		dc.w byte_A327-Ani_obj1F
byte_A30C:	dc.b  $F,  0,$FF
byte_A30F:	dc.b  $F,  2,$FF
byte_A312:	dc.b  $F,$22,$FF
byte_A315:	dc.b  $F,  1,$21,  0,$FF
byte_A31A:	dc.b  $F,$21,  3,  2,$FF
byte_A31F:	dc.b  $F,  1,$23,$22,$FF
byte_A324:	dc.b  $F,  4,$FF
byte_A327:	dc.b   1,  5,  6,$FF
		even

; ---------------------------------------------------------------------------
; Sprite mappings
; ---------------------------------------------------------------------------
Map_obj1F:	binclude	"mappings/sprite/obj1F.bin"
		even

		include	"objects/S1/22 Buzz Bomber.asm"
		include	"objects/S1/23 Buzz Bomber Missile.asm"
; ===========================================================================
; animation script
Ani_obj22:	dc.w byte_A652-Ani_obj22
		dc.w byte_A656-Ani_obj22
		dc.w byte_A65A-Ani_obj22
byte_A652:	dc.b   1,  0,  1,$FF
byte_A656:	dc.b   1,  2,  3,$FF
byte_A65A:	dc.b   1,  4,  5,$FF
		even
Ani_obj23:	dc.w byte_A662-Ani_obj23
		dc.w byte_A666-Ani_obj23
byte_A662:	dc.b   7,  0,  1,$FC
byte_A666:	dc.b   1,  2,  3,$FF
		even
; ---------------------------------------------------------------------------
; sprite mappings - Buzz Bomber
; ---------------------------------------------------------------------------
Map_obj22:	binclude	"mappings/sprite/obj22.bin"
		even
; ---------------------------------------------------------------------------
; sprite mappings - Buzz Bomber missile
; ---------------------------------------------------------------------------
Map_obj23:	binclude	"mappings/sprite/obj23.bin"
		even
; ===========================================================================
; ---------------------------------------------------------------------------
		include	"objects/91 Title Sonic And Tails.asm"
Map_TitleST:	binclude "mappings/sprite/Sonic & Tails on the title screen.bin"
		even

		include	"objects/92 Title screen palette handler.asm"
		include	"objects/93 Press Start Button.asm"
Map_PSB:	binclude "mappings/sprite/press start button.bin"
		even
; ---------------------------------------------------------------------------
		include	"objects/2B Chopper.asm"
Map_Obj2B:	binclude	"mappings/sprite/obj2B.bin"	; Green hill
		even
Map_obj2B_1:	binclude	"mappings/sprite/obj2B_1.bin"	; Emerald hill
		even

; ---------------------------------------------------------------------------
		include	"objects/S1/2C Jaws.asm"
; ---------------------------------------------------------------------------
Map_Jaws:
Map_Obj2C:	dc.w word_B880-Map_Obj2C
		dc.w word_B892-Map_Obj2C
		dc.w word_B8A4-Map_Obj2C
		dc.w word_B8B6-Map_Obj2C
word_B880:	dc.w 2
		dc.w $F40E,    0,    0,$FFF0
		dc.w $F505,  $18,   $C,	 $10
word_B892:	dc.w 2
		dc.w $F40E,   $C,    6,$FFF0
		dc.w $F505,  $1C,   $E,	 $10
word_B8A4:	dc.w 2
		dc.w $F40E,    0,    0,$FFF0
		dc.w $F505,$1018,$100C,	 $10
word_B8B6:	dc.w 2
		dc.w $F40E,   $C,    6,$FFF0
		dc.w $F505,$101C,$100E,	 $10
		even
; ---------------------------------------------------------------------------
		include	"objects/Bonus & Special Stages/7A Special Stage Entry.asm"
		include	"objects/Bonus & Special Stages/7B Giant Ring.asm"
		include	"objects/Bonus & Special Stages/7C Ring Flash.asm"
		include	"objects/94 Title Cards.asm"
		include	"objects/95 Got Through Card.asm"
		include	"objects/Bonus & Special Stages/96 Special Stage Results.asm"
		include	"objects/Bonus & Special Stages/97 SS Result Chaos Emeralds.asm"
		include	"objects/98 Game Over.asm"
		include	"objects/36 Spikes.asm"
		include	"objects/S1/3B Purple Rock.asm"
Map_Obj36:	include	"mappings/sprite/obj36.asm"
Map_Obj3B:	include	"mappings/sprite/S1/Purple Rock.asm"
Map_Obj12:	dc.w word_14444-Map_Obj12
word_14444:	dc.w 2
		dc.w $F00F,    0,    0,$FFE0
		dc.w $F00F,  $10,    8,	   0
		even; ---------------------------------------------------------------------------
Map_SpecialWarp:
		binclude	"mappings/sprite/Special Stage Warp.bin"
		even
Map_GiantRing:
		binclude	"mappings/sprite/GiantRing.bin"
		even
Map_GiantRingFlash:
		binclude	"mappings/sprite/GiantRingFlash.bin"
		even
Map_SSR:	include		"mappings/sprite/SSResults.asm"
Map_SSRE:	binclude	"mappings/sprite/SSR Emeralds.bin"
		even
Map_Card:	include	"mappings/sprite/Title_Cards.asm"
Map_Over:	include	"mappings/sprite/Game_Over.asm"
Map_Got:	include	"mappings/sprite/Got_Through.asm"
; ---------------------------------------------------------------------------
		include	"objects/S1/3C Smashable Wall.asm"
		include	"objects/S1/sub SmashObject.asm"
; ---------------------------------------------------------------------------
Obj3C_FragSpdRight:
		dc.w  $400,-$500
		dc.w  $600,-$100
		dc.w  $600, $100
		dc.w  $400, $500
		dc.w  $600,-$600
		dc.w  $800,-$200
		dc.w  $800, $200
		dc.w  $600, $600
Obj3C_FragSpdLeft:
		dc.w -$600,-$600
		dc.w -$800,-$200
		dc.w -$800, $200
		dc.w -$600, $600
		dc.w -$400,-$500
		dc.w -$600,-$100
		dc.w -$600, $100
		dc.w -$400, $500
; ---------------------------------------------------------------------------
Map_Obj3C:	dc.w word_CA6C-Map_Obj3C
		dc.w word_CAAE-Map_Obj3C
		dc.w word_CAF0-Map_Obj3C
word_CA6C:	dc.w 8
		dc.w $E005,    0,    0,$FFF0
		dc.w $F005,    0,    0,$FFF0
		dc.w	 5,    0,    0,$FFF0
		dc.w $1005,    0,    0,$FFF0
		dc.w $E005,    4,    2,	   0
		dc.w $F005,    4,    2,	   0
		dc.w	 5,    4,    2,	   0
		dc.w $1005,    4,    2,	   0
word_CAAE:	dc.w 8
		dc.w $E005,    4,    2,$FFF0
		dc.w $F005,    4,    2,$FFF0
		dc.w	 5,    4,    2,$FFF0
		dc.w $1005,    4,    2,$FFF0
		dc.w $E005,    4,    2,	   0
		dc.w $F005,    4,    2,	   0
		dc.w	 5,    4,    2,	   0
		dc.w $1005,    4,    2,	   0
word_CAF0:	dc.w 8
		dc.w $E005,    4,    2,$FFF0
		dc.w $F005,    4,    2,$FFF0
		dc.w	 5,    4,    2,$FFF0
		dc.w $1005,    4,    2,$FFF0
		dc.w $E005,    8,    4,	   0
		dc.w $F005,    8,    4,	   0
		dc.w	 5,    8,    4,	   0
		dc.w $1005,    8,    4,	   0
		even
; ---------------------------------------------------------------------------


; ===========================================================================
; ---------------------------------------------------------------------------
; This runs the code of all the objects that are in Object_RAM
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; ObjectsLoad:
ExecuteObjects:
		lea	(v_objspace).w,a0
		moveq	#(v_objend-v_objspace)/object_size-1,d7	; run the first $80 objects out of levels
		moveq	#0,d0
		cmpi.b	#6,(v_player+obRoutine).w	; is Sonic dead?
		bhs.s	ExecuteObjectsWhenPlayerIsDead	; if yes, branch

; ---------------------------------------------------------------------------
; This is THE place where each individual object's code gets called from
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; sub_CB44:
RunObject:
		move.b	obID(a0),d0			; get the object's ID
		beq.s	.skip				; if it's obj00, skip it
		add.w	d0,d0
		add.w	d0,d0				; d0 = object ID * 4
		movea.l	Obj_Index-4(pc,d0.w),a1		; load the address of the object's code
		jsr	(a1)				; dynamic call! to one of the the entries in Obj_Index
		moveq	#0,d0

.skip:
		lea	object_size(a0),a0		; load obj address
		dbf	d7,RunObject
		rts
; ---------------------------------------------------------------------------
; this skips certain objects to make enemies and things pause when Sonic dies
; loc_CB5E:
ExecuteObjectsWhenPlayerIsDead:
		moveq	#(v_lvlobjspace-v_objspace)/object_size-1,d7
		bsr.s	RunObject
		moveq	#(v_lvlobjend-v_lvlobjspace)/object_size-1,d7

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_CB64:
ExecuteObjectsDisplayOnly:
		moveq	#0,d0
		move.b	obID(a0),d0			; get the object's ID
		beq.s	loc_CB74			; if it's obj00, skip it
		tst.b	obRender(a0)			; should we render it?
		bpl.s	loc_CB74			; if not, skip it
		move.w	obPriority(a0),d0		; move priority to d0
		btst	#6,obRender			; is the compound sprites flag set?
		beq.s	+				; if not, branch
		move.w	#$200,d0			; override priority
+
		bsr.w	DisplaySprite3			; Display the object using d0

loc_CB74:
		lea	next_object(a0),a0		; load obj address
		dbf	d7,ExecuteObjectsDisplayOnly
		rts
; End of function ExecuteObjects

; ===========================================================================
; ---------------------------------------------------------------------------
; OBJECT POINTER ARRAY ; object pointers ; sprite pointers ; object list ; sprite list
;
; This array contains the pointers to all the objects used in the game.
; ---------------------------------------------------------------------------
Obj_Index:
ptr_Obj01:		dc.l Obj01	; Sonic
ptr_Obj02:		dc.l Obj02	; Tails
ptr_Obj03:		dc.l Obj03	; Collision plane/layer switcher
ptr_Obj04:		dc.l BonusPlayer; Sonic or Tails in the Bonus Stage
ptr_Obj05:		dc.l Obj05	; Tails' tails
ptr_Obj06:		dc.l Obj06	; Twisting spiral pathway in EHZ
ptr_Obj07:		dc.l WaterSurface	; Surface of the water
ptr_Obj08:		dc.l Splash		; Water splash in HPZ
ptr_Obj09:		dc.l Bubbles		; Bubble maker
ptr_Obj0A:		dc.l Obj0A		; Small bubbles from Sonic's face while underwater
ptr_Obj0B:		dc.l Obj0B	; (S1) Pole that breaks in LZ
ptr_Obj0C:		dc.l FlapDoor	; (S1) Flapping door in LZ
ptr_Obj0D:		dc.l Obj0D	; End of level signpost
ptr_Obj0E:		dc.l ObjNull	; Empty
ptr_Obj0F:		dc.l ObjNull	; Empty

ptr_Obj10:		dc.l ObjNull	; Empty
ptr_Obj11:		dc.l Obj11	; Bridges in GHZ, EHZ and HPZ
ptr_Obj12:		dc.l ObjNull
ptr_Obj13:		dc.l Obj13	; Waterfall from Hidden Palace Zone
ptr_Obj14:		dc.l ObjNull
ptr_Obj15:		dc.l Obj15	; Swinging platforms in GHZ, CPZ and EHZ
ptr_Obj16:		dc.l Obj16	; Diagonally moving lift from HTZ
ptr_Obj17:		dc.l Obj17	; (S1) GHZ rotating log helix spikes
ptr_Obj18:		dc.l Obj18	; Stationary/moving platforms from GHZ and EHZ
ptr_Obj19:		dc.l Obj19	; Platform from CPZ
ptr_Obj1A:		dc.l Obj1A	; Collapsing platform from GHZ and HPZ
ptr_Obj1B:		dc.l Obj1B
ptr_Obj1C:		dc.l Obj1C	; Stage decorations in GHZ, EHZ, HTZ and HPZ
ptr_Obj1D:		dc.l ObjNull
ptr_Obj1E:		dc.l ObjVBallhog
ptr_Obj1F:		dc.l Obj1F	; (S1) Crabmeat from GHZ

ptr_Obj20:		dc.l ObjNull
ptr_Obj21:		dc.l ObjNull
ptr_Obj22:		dc.l Obj22	; (S1) Buzz Bomber from GHZ
ptr_Obj23:		dc.l Obj23	; (S1) Buzz Bomber/Newtron missile
ptr_Obj24:		dc.l Obj24	; Ballhog bomb explosion
ptr_Obj25:		dc.l Obj25	; A ring
ptr_Obj26:		dc.l Obj26	; Monitor
ptr_Obj27:		dc.l Obj27	; An explosion, giving off an animal and 100 points
ptr_Obj28:		dc.l Obj28	; Animal and the 100 points from a badnik
ptr_Obj29:		dc.l Obj29	; Monitor contents (code for power-up behavior and rising image)
ptr_Obj2A:		dc.l Points	; "100 points" text
ptr_Obj2B:		dc.l Obj2B	; (S1) Chopper from GHZ
ptr_Obj2C:		dc.l Obj2C	; (S1) Jaws from LZ
ptr_Obj2D:		dc.l ObjNull
ptr_Obj2E:		dc.l ObjNull
ptr_Obj2F:		dc.l ObjNull

ptr_Obj30:		dc.l Obj30	; (S1) Small door from SBZ
ptr_Obj31:		dc.l ObjNull
ptr_Obj32:		dc.l ObjNull
ptr_Obj33:		dc.l ObjNull
ptr_Obj34:		dc.l ObjNull
ptr_Obj35:		dc.l ObjNull
ptr_Obj36:		dc.l Obj36	; Vertical spikes
ptr_Obj37:		dc.l Obj37	; Scattering rings (generated when Sonic or Tails are hurt and has rings)
ptr_Obj38:		dc.l Obj38	; Shield
ptr_Obj39:		dc.l ObjNull
ptr_Obj3A:		dc.l ObjNull
ptr_Obj3B:		dc.l Obj3B	; Rocks and Emeralds (GHZ, HPZ)
ptr_Obj3C:		dc.l Obj3C	; (S1) Breakable wall
ptr_Obj3D:		dc.l Obj3D	; (S1) GHZ boss
ptr_Obj3E:		dc.l Obj3E	; Egg prison
ptr_Obj3F:		dc.l Obj3F	; Boss explosion

ptr_Obj40:		dc.l Obj40	; (S1) Motobug from GHZ
ptr_Obj41:		dc.l Obj41	; Spring
ptr_Obj42:		dc.l Obj42	; (S1) Newtron from GHZ
ptr_Obj43:		dc.l ObjNull
ptr_Obj44:		dc.l Obj44	; (S1) Breakable wall
ptr_Obj45:		dc.l ObjNull
ptr_Obj46:		dc.l ObjNull
ptr_Obj47:		dc.l Obj47
ptr_Obj48:		dc.l Obj48	; (S1) Eggman's wrecking ball
ptr_Obj49:		dc.l Obj49	; Waterfall sound effect
ptr_Obj4A:		dc.l Obj4A	; Octus from HPZ
ptr_Obj4B:		dc.l Obj4B	; Buzzer from EHZ
ptr_Obj4C:		dc.l Obj4C	; BBat from HPZ
ptr_Obj4D:		dc.l Obj4D	; Stego/Stegway from HPZ
ptr_Obj4E:		dc.l Obj4E	; Gator from HPZ
ptr_Obj4F:		dc.l Obj4F	; Redz (dinosaur badnik) from HPZ

ptr_Obj50:		dc.l Obj50	; Seahorse/Aquis from HPZ
ptr_Obj51:		dc.l Obj51	; Skyhorse from HPZ
ptr_Obj52:		dc.l Obj52	; BFish from HPZ
ptr_Obj53:		dc.l Obj53	; Empty
ptr_Obj54:		dc.l Obj54	; Snail badnik from EHZ
ptr_Obj55:		dc.l Obj55	; EHZ boss
ptr_Obj56:		dc.l Obj56	; EHZ boss part 2
ptr_Obj57:		dc.l Obj57	; EHZ boss part 3
ptr_Obj58:		dc.l Obj58	; EHZ boss part 4
ptr_Obj59:		dc.l ObjNull
ptr_Obj5A:		dc.l ObjNull
ptr_Obj5B:		dc.l ObjNull
ptr_Obj5C:		dc.l ObjNull
ptr_Obj5D:		dc.l ObjNull
ptr_Obj5E:		dc.l Obj5E	; Seesaw from Hill Top Zone
ptr_Obj5F:		dc.l ObjNull

ptr_Obj60:		dc.l ObjNull
ptr_Obj61:		dc.l ObjNull
ptr_Obj62:		dc.l ObjNull
ptr_Obj63:		dc.l ObjNull
ptr_Obj64:		dc.l ObjNull
ptr_Obj65:		dc.l ObjNull
ptr_Obj66:		dc.l ObjNull
ptr_Obj67:		dc.l ObjNull
ptr_Obj68:		dc.l ObjNull
ptr_Obj69:		dc.l ObjNull
ptr_Obj6A:		dc.l ObjNull
ptr_Obj6B:		dc.l ObjNull
ptr_Obj6C:		dc.l ObjNull
ptr_Obj6D:		dc.l ObjNull
ptr_Obj6E:		dc.l ObjNull
ptr_Obj6F:		dc.l ObjNull

ptr_Obj70:		dc.l ObjNull
ptr_Obj71:		dc.l ObjNull
ptr_Obj72:		dc.l ObjNull
ptr_Obj73:		dc.l ObjNull
ptr_Obj74:		dc.l ObjNull
ptr_Obj75:		dc.l ObjNull
ptr_Obj76:		dc.l ObjNull
ptr_Obj77:		dc.l ObjNull
ptr_Obj78:		dc.l ObjNull
ptr_Obj79:		dc.l Obj79	; Checkpoint
ptr_Obj7A:		dc.l SpecialStageEntry
ptr_Obj7B:		dc.l GiantRing	; Bonus stage entry
ptr_Obj7C:		dc.l GiantRingFlash
ptr_Obj7D:		dc.l Obj7D	; Hidden points at end of stage
ptr_Obj7E:		dc.l ObjNull
ptr_Obj7F:		dc.l ObjNull

ptr_Obj80:		dc.l ObjNull	; Was originally Continue Screen Elements, but was completely stripped out
ptr_Obj81:		dc.l ObjNull	; Was originally Continue Screen Sonic, but was completely stripped out
ptr_Obj82:		dc.l ObjNull	; Was originally Eggman - Scrap Brain 2, but was completely stripped out
ptr_Obj83:		dc.l ObjNull	; Was originally SBZ Eggman's Crumbling Floor, but was completely stripped out
ptr_Obj84:		dc.l ObjNull	; Was originally FZ Eggman's Cylinders, but was completely stripped out
ptr_Obj85:		dc.l ObjNull	; Was originally Boss - Final, but was completely stripped out
ptr_Obj86:		dc.l ObjNull	; Was originally FZ Plasma Ball Launcher, but was completely stripped out
ptr_Obj87:		dc.l ObjNull	; Was originally Ending Sequence Sonic, but was completely stripped out
ptr_Obj88:		dc.l ObjNull	; Was originally Ending Sequence Emeralds, but was completely stripped out
ptr_Obj89:		dc.l ObjNull	; Was originally Ending Sequence STH, but was completely stripped out
ptr_Obj8A:		dc.l ObjNull
ptr_Obj8B:		dc.l ObjNull	; Was originally Try Again & End Eggman, but was completely stripped out
ptr_Obj8C:		dc.l ObjNull	; Was originally Try Again Emeralds, but was completely stripped out
ptr_Obj8D:		dc.l ObjNull
ptr_Obj8E:		dc.l ObjNull
ptr_Obj8F:		dc.l ObjNull

ptr_Obj90:		dc.l Credits		; "SONIC TEAM PRESENTS" screen and credits
ptr_Obj91:		dc.l TitleSonicTails	; Sonic and Tails from the title screen
ptr_Obj92:		dc.l TitlePaletteHandler		; TODO
ptr_Obj93:		dc.l PressStartButton	; Press Start Button
ptr_Obj94:		dc.l TitleCards		; Level title card
ptr_Obj95:		dc.l GotThrough		; End of level results screen
ptr_Obj96:		dc.l BonusGotThrough	; Special Stage Results
ptr_Obj97:		dc.l ChaosEmeralds	; SS Result Chaos Emeralds (These now belong to S2 special stages, so... To be changed)
ptr_Obj98:		dc.l GameOver		; Game Over/Time Over text
ptr_Obj99:		dc.l ObjNull
ptr_Obj9A:		dc.l ObjNull
ptr_Obj9B:		dc.l ObjNull
ptr_Obj9C:		dc.l ObjNull
ptr_Obj9D:		dc.l ObjNull
ptr_Obj9E:		dc.l ObjNull
ptr_Obj9F:		dc.l ObjNull

ptr_ObjA0:		dc.l ObjNull
ptr_ObjA1:		dc.l ObjNull
ptr_ObjA2:		dc.l ObjNull
ptr_ObjA3:		dc.l ObjNull
ptr_ObjA4:		dc.l ObjNull
ptr_ObjA5:		dc.l ObjNull
ptr_ObjA6:		dc.l ObjNull
ptr_ObjA7:		dc.l ObjNull
ptr_ObjA8:		dc.l ObjNull
ptr_ObjA9:		dc.l ObjNull
ptr_ObjAA:		dc.l ObjNull
ptr_ObjAB:		dc.l ObjNull
ptr_ObjAC:		dc.l ObjNull
ptr_ObjAD:		dc.l ObjNull
ptr_ObjAE:		dc.l ObjNull
ptr_ObjAF:		dc.l ObjNull

ptr_ObjB0:		dc.l ObjNull
ptr_ObjB1:		dc.l ObjNull
ptr_ObjB2:		dc.l ObjNull
ptr_ObjB3:		dc.l ObjNull
ptr_ObjB4:		dc.l ObjNull
ptr_ObjB5:		dc.l ObjNull
ptr_ObjB6:		dc.l ObjNull
ptr_ObjB7:		dc.l ObjNull
ptr_ObjB8:		dc.l ObjNull
ptr_ObjB9:		dc.l ObjNull
ptr_ObjBA:		dc.l ObjNull
ptr_ObjBB:		dc.l ObjNull
ptr_ObjBC:		dc.l ObjNull
ptr_ObjBD:		dc.l ObjNull
ptr_ObjBE:		dc.l ObjNull
ptr_ObjBF:		dc.l ObjNull

ptr_ObjC0:		dc.l ObjNull
ptr_ObjC1:		dc.l ObjNull
ptr_ObjC2:		dc.l ObjNull
ptr_ObjC3:		dc.l ObjNull
ptr_ObjC4:		dc.l ObjNull
ptr_ObjC5:		dc.l ObjNull
ptr_ObjC6:		dc.l ObjNull
ptr_ObjC7:		dc.l ObjNull
ptr_ObjC8:		dc.l ObjNull
ptr_ObjC9:		dc.l ObjNull
ptr_ObjCA:		dc.l ObjNull
ptr_ObjCB:		dc.l ObjNull
ptr_ObjCC:		dc.l ObjNull
ptr_ObjCD:		dc.l ObjNull
ptr_ObjCE:		dc.l ObjNull
ptr_ObjCF:		dc.l ObjNull

ptr_ObjD0:		dc.l ObjNull
ptr_ObjD1:		dc.l ObjNull
ptr_ObjD2:		dc.l ObjNull
ptr_ObjD3:		dc.l ObjNull
ptr_ObjD4:		dc.l ObjNull
ptr_ObjD5:		dc.l ObjNull
ptr_ObjD6:		dc.l ObjNull
ptr_ObjD7:		dc.l ObjNull
ptr_ObjD8:		dc.l ObjNull
ptr_ObjD9:		dc.l ObjNull
ptr_ObjDA:		dc.l ObjNull
ptr_ObjDB:		dc.l ObjNull
ptr_ObjDC:		dc.l ObjNull
ptr_ObjDD:		dc.l ObjNull
ptr_ObjDE:		dc.l ObjNull
ptr_ObjDF:		dc.l ObjNull

ptr_ObjE0:		dc.l ObjNull
ptr_ObjE1:		dc.l ObjNull
ptr_ObjE2:		dc.l ObjNull
ptr_ObjE3:		dc.l ObjNull
ptr_ObjE4:		dc.l ObjNull
ptr_ObjE5:		dc.l ObjNull
ptr_ObjE6:		dc.l ObjNull
ptr_ObjE7:		dc.l ObjNull
ptr_ObjE8:		dc.l ObjNull
ptr_ObjE9:		dc.l ObjNull
ptr_ObjEA:		dc.l ObjNull
ptr_ObjEB:		dc.l ObjNull
ptr_ObjEC:		dc.l ObjNull
ptr_ObjED:		dc.l ObjNull
ptr_ObjEE:		dc.l ObjNull
ptr_ObjEF:		dc.l ObjNull

ptr_ObjF0:		dc.l ObjNull
ptr_ObjF1:		dc.l ObjNull
ptr_ObjF2:		dc.l ObjNull
ptr_ObjF3:		dc.l ObjNull
ptr_ObjF4:		dc.l ObjNull
ptr_ObjF5:		dc.l ObjNull
ptr_ObjF6:		dc.l ObjNull
ptr_ObjF7:		dc.l ObjNull
ptr_ObjF8:		dc.l ObjNull
ptr_ObjF9:		dc.l ObjNull
ptr_ObjFA:		dc.l ObjNull
ptr_ObjFB:		dc.l ObjNull
ptr_ObjFC:		dc.l ObjNull
ptr_ObjFD:		dc.l ObjNull
ptr_ObjFE:		dc.l ObjNull
ptr_ObjFF:		dc.l ObjNull

id_Obj01:	equ ((ptr_Obj01-Obj_Index)/4)+1
id_Obj02:	equ ((ptr_Obj02-Obj_Index)/4)+1
id_Obj03:	equ ((ptr_Obj03-Obj_Index)/4)+1
id_Obj04:	equ ((ptr_Obj04-Obj_Index)/4)+1
id_Obj05:	equ ((ptr_Obj05-Obj_Index)/4)+1
id_Obj06:	equ ((ptr_Obj06-Obj_Index)/4)+1
id_Obj07:	equ ((ptr_Obj07-Obj_Index)/4)+1
id_Obj08:	equ ((ptr_Obj08-Obj_Index)/4)+1
id_Obj09:	equ ((ptr_Obj09-Obj_Index)/4)+1
id_Obj0A:	equ ((ptr_Obj0A-Obj_Index)/4)+1
id_Obj0B:	equ ((ptr_Obj0B-Obj_Index)/4)+1
id_Obj0C:	equ ((ptr_Obj0C-Obj_Index)/4)+1
id_Obj0D:	equ ((ptr_Obj0D-Obj_Index)/4)+1
id_Obj0E:	equ ((ptr_Obj0E-Obj_Index)/4)+1
id_Obj0F:	equ ((ptr_Obj0F-Obj_Index)/4)+1

id_Obj10:	equ ((ptr_Obj10-Obj_Index)/4)+1
id_Obj11:	equ ((ptr_Obj11-Obj_Index)/4)+1
id_Obj12:	equ ((ptr_Obj12-Obj_Index)/4)+1
id_Obj13:	equ ((ptr_Obj13-Obj_Index)/4)+1
id_Obj14:	equ ((ptr_Obj14-Obj_Index)/4)+1
id_Obj15:	equ ((ptr_Obj15-Obj_Index)/4)+1
id_Obj16:	equ ((ptr_Obj16-Obj_Index)/4)+1
id_Obj17:	equ ((ptr_Obj17-Obj_Index)/4)+1
id_Obj18:	equ ((ptr_Obj18-Obj_Index)/4)+1
id_Obj19:	equ ((ptr_Obj19-Obj_Index)/4)+1
id_Obj1A:	equ ((ptr_Obj1A-Obj_Index)/4)+1
id_Obj1B:	equ ((ptr_Obj1B-Obj_Index)/4)+1
id_Obj1C:	equ ((ptr_Obj1C-Obj_Index)/4)+1
id_Obj1D:	equ ((ptr_Obj1D-Obj_Index)/4)+1
id_Obj1E:	equ ((ptr_Obj1E-Obj_Index)/4)+1
id_Obj1F:	equ ((ptr_Obj1F-Obj_Index)/4)+1

id_Obj20:	equ ((ptr_Obj20-Obj_Index)/4)+1
id_Obj21:	equ ((ptr_Obj21-Obj_Index)/4)+1
id_Obj22:	equ ((ptr_Obj22-Obj_Index)/4)+1
id_Obj23:	equ ((ptr_Obj23-Obj_Index)/4)+1
id_Obj24:	equ ((ptr_Obj24-Obj_Index)/4)+1
id_Obj25:	equ ((ptr_Obj25-Obj_Index)/4)+1
id_Obj26:	equ ((ptr_Obj26-Obj_Index)/4)+1
id_Obj27:	equ ((ptr_Obj27-Obj_Index)/4)+1
id_Obj28:	equ ((ptr_Obj28-Obj_Index)/4)+1
id_Obj29:	equ ((ptr_Obj29-Obj_Index)/4)+1
id_Obj2A:	equ ((ptr_Obj2A-Obj_Index)/4)+1
id_Obj2B:	equ ((ptr_Obj2B-Obj_Index)/4)+1
id_Obj2C:	equ ((ptr_Obj2C-Obj_Index)/4)+1
id_Obj2D:	equ ((ptr_Obj2D-Obj_Index)/4)+1
id_Obj2E:	equ ((ptr_Obj2E-Obj_Index)/4)+1
id_Obj2F:	equ ((ptr_Obj2F-Obj_Index)/4)+1

id_Obj30:	equ ((ptr_Obj30-Obj_Index)/4)+1
id_Obj31:	equ ((ptr_Obj31-Obj_Index)/4)+1
id_Obj32:	equ ((ptr_Obj32-Obj_Index)/4)+1
id_Obj33:	equ ((ptr_Obj33-Obj_Index)/4)+1
id_Obj34:	equ ((ptr_Obj34-Obj_Index)/4)+1
id_Obj35:	equ ((ptr_Obj35-Obj_Index)/4)+1
id_Obj36:	equ ((ptr_Obj36-Obj_Index)/4)+1
id_Obj37:	equ ((ptr_Obj37-Obj_Index)/4)+1
id_Obj38:	equ ((ptr_Obj38-Obj_Index)/4)+1
id_Obj39:	equ ((ptr_Obj39-Obj_Index)/4)+1
id_Obj3A:	equ ((ptr_Obj3A-Obj_Index)/4)+1
id_Obj3B:	equ ((ptr_Obj3B-Obj_Index)/4)+1
id_Obj3C:	equ ((ptr_Obj3C-Obj_Index)/4)+1
id_Obj3D:	equ ((ptr_Obj3D-Obj_Index)/4)+1
id_Obj3E:	equ ((ptr_Obj3E-Obj_Index)/4)+1
id_Obj3F:	equ ((ptr_Obj3F-Obj_Index)/4)+1

id_Obj40:	equ ((ptr_Obj40-Obj_Index)/4)+1
id_Obj41:	equ ((ptr_Obj41-Obj_Index)/4)+1
id_Obj42:	equ ((ptr_Obj42-Obj_Index)/4)+1
id_Obj43:	equ ((ptr_Obj43-Obj_Index)/4)+1
id_Obj44:	equ ((ptr_Obj44-Obj_Index)/4)+1
id_Obj45:	equ ((ptr_Obj45-Obj_Index)/4)+1
id_Obj46:	equ ((ptr_Obj46-Obj_Index)/4)+1
id_Obj47:	equ ((ptr_Obj47-Obj_Index)/4)+1
id_Obj48:	equ ((ptr_Obj48-Obj_Index)/4)+1
id_Obj49:	equ ((ptr_Obj49-Obj_Index)/4)+1
id_Obj4A:	equ ((ptr_Obj4A-Obj_Index)/4)+1
id_Obj4B:	equ ((ptr_Obj4B-Obj_Index)/4)+1
id_Obj4C:	equ ((ptr_Obj4C-Obj_Index)/4)+1
id_Obj4D:	equ ((ptr_Obj4D-Obj_Index)/4)+1
id_Obj4E:	equ ((ptr_Obj4E-Obj_Index)/4)+1
id_Obj4F:	equ ((ptr_Obj4F-Obj_Index)/4)+1

id_Obj50:	equ ((ptr_Obj50-Obj_Index)/4)+1
id_Obj51:	equ ((ptr_Obj51-Obj_Index)/4)+1
id_Obj52:	equ ((ptr_Obj52-Obj_Index)/4)+1
id_Obj53:	equ ((ptr_Obj53-Obj_Index)/4)+1
id_Obj54:	equ ((ptr_Obj54-Obj_Index)/4)+1
id_Obj55:	equ ((ptr_Obj55-Obj_Index)/4)+1
id_Obj56:	equ ((ptr_Obj56-Obj_Index)/4)+1
id_Obj57:	equ ((ptr_Obj57-Obj_Index)/4)+1
id_Obj58:	equ ((ptr_Obj58-Obj_Index)/4)+1
id_Obj59:	equ ((ptr_Obj59-Obj_Index)/4)+1
id_Obj5A:	equ ((ptr_Obj5A-Obj_Index)/4)+1
id_Obj5B:	equ ((ptr_Obj5B-Obj_Index)/4)+1
id_Obj5C:	equ ((ptr_Obj5C-Obj_Index)/4)+1
id_Obj5D:	equ ((ptr_Obj5D-Obj_Index)/4)+1
id_Obj5E:	equ ((ptr_Obj5E-Obj_Index)/4)+1
id_Obj5F:	equ ((ptr_Obj5F-Obj_Index)/4)+1

id_Obj60:	equ ((ptr_Obj60-Obj_Index)/4)+1
id_Obj61:	equ ((ptr_Obj61-Obj_Index)/4)+1
id_Obj62:	equ ((ptr_Obj62-Obj_Index)/4)+1
id_Obj63:	equ ((ptr_Obj63-Obj_Index)/4)+1
id_Obj64:	equ ((ptr_Obj64-Obj_Index)/4)+1
id_Obj65:	equ ((ptr_Obj65-Obj_Index)/4)+1
id_Obj66:	equ ((ptr_Obj66-Obj_Index)/4)+1
id_Obj67:	equ ((ptr_Obj67-Obj_Index)/4)+1
id_Obj68:	equ ((ptr_Obj68-Obj_Index)/4)+1
id_Obj69:	equ ((ptr_Obj69-Obj_Index)/4)+1
id_Obj6A:	equ ((ptr_Obj6A-Obj_Index)/4)+1
id_Obj6B:	equ ((ptr_Obj6B-Obj_Index)/4)+1
id_Obj6C:	equ ((ptr_Obj6C-Obj_Index)/4)+1
id_Obj6D:	equ ((ptr_Obj6D-Obj_Index)/4)+1
id_Obj6E:	equ ((ptr_Obj6E-Obj_Index)/4)+1
id_Obj6F:	equ ((ptr_Obj6F-Obj_Index)/4)+1

id_Obj70:	equ ((ptr_Obj70-Obj_Index)/4)+1
id_Obj71:	equ ((ptr_Obj71-Obj_Index)/4)+1
id_Obj72:	equ ((ptr_Obj72-Obj_Index)/4)+1
id_Obj73:	equ ((ptr_Obj73-Obj_Index)/4)+1
id_Obj74:	equ ((ptr_Obj74-Obj_Index)/4)+1
id_Obj75:	equ ((ptr_Obj75-Obj_Index)/4)+1
id_Obj76:	equ ((ptr_Obj76-Obj_Index)/4)+1
id_Obj77:	equ ((ptr_Obj77-Obj_Index)/4)+1
id_Obj78:	equ ((ptr_Obj78-Obj_Index)/4)+1
id_Obj79:	equ ((ptr_Obj79-Obj_Index)/4)+1
id_Obj7A:	equ ((ptr_Obj7A-Obj_Index)/4)+1
id_Obj7B:	equ ((ptr_Obj7B-Obj_Index)/4)+1
id_Obj7C:	equ ((ptr_Obj7C-Obj_Index)/4)+1
id_Obj7D:	equ ((ptr_Obj7D-Obj_Index)/4)+1
id_Obj7E:	equ ((ptr_Obj7E-Obj_Index)/4)+1
id_Obj7F:	equ ((ptr_Obj7F-Obj_Index)/4)+1

id_Obj80:	equ ((ptr_Obj80-Obj_Index)/4)+1
id_Obj81:	equ ((ptr_Obj81-Obj_Index)/4)+1
id_Obj82:	equ ((ptr_Obj82-Obj_Index)/4)+1
id_Obj83:	equ ((ptr_Obj83-Obj_Index)/4)+1
id_Obj84:	equ ((ptr_Obj84-Obj_Index)/4)+1
id_Obj85:	equ ((ptr_Obj85-Obj_Index)/4)+1
id_Obj86:	equ ((ptr_Obj86-Obj_Index)/4)+1
id_Obj87:	equ ((ptr_Obj87-Obj_Index)/4)+1
id_Obj88:	equ ((ptr_Obj88-Obj_Index)/4)+1
id_Obj89:	equ ((ptr_Obj89-Obj_Index)/4)+1
id_Obj8A:	equ ((ptr_Obj8A-Obj_Index)/4)+1
id_Obj8B:	equ ((ptr_Obj8B-Obj_Index)/4)+1
id_Obj8C:	equ ((ptr_Obj8C-Obj_Index)/4)+1
id_Obj8D:	equ ((ptr_Obj8D-Obj_Index)/4)+1
id_Obj8E:	equ ((ptr_Obj8E-Obj_Index)/4)+1
id_Obj8F:	equ ((ptr_Obj8F-Obj_Index)/4)+1

id_Obj90:	equ ((ptr_Obj90-Obj_Index)/4)+1
id_Obj91:	equ ((ptr_Obj91-Obj_Index)/4)+1
id_Obj92:	equ ((ptr_Obj92-Obj_Index)/4)+1
id_Obj93:	equ ((ptr_Obj93-Obj_Index)/4)+1
id_Obj94:	equ ((ptr_Obj94-Obj_Index)/4)+1
id_Obj95:	equ ((ptr_Obj95-Obj_Index)/4)+1
id_Obj96:	equ ((ptr_Obj96-Obj_Index)/4)+1
id_Obj97:	equ ((ptr_Obj97-Obj_Index)/4)+1
id_Obj98:	equ ((ptr_Obj98-Obj_Index)/4)+1
id_Obj99:	equ ((ptr_Obj99-Obj_Index)/4)+1
id_Obj9A:	equ ((ptr_Obj9A-Obj_Index)/4)+1
id_Obj9B:	equ ((ptr_Obj9B-Obj_Index)/4)+1
id_Obj9C:	equ ((ptr_Obj9C-Obj_Index)/4)+1
id_Obj9D:	equ ((ptr_Obj9D-Obj_Index)/4)+1
id_Obj9E:	equ ((ptr_Obj9E-Obj_Index)/4)+1
id_Obj9F:	equ ((ptr_Obj9F-Obj_Index)/4)+1

id_ObjA0:	equ ((ptr_ObjA0-Obj_Index)/4)+1
id_ObjA1:	equ ((ptr_ObjA1-Obj_Index)/4)+1
id_ObjA2:	equ ((ptr_ObjA2-Obj_Index)/4)+1
id_ObjA3:	equ ((ptr_ObjA3-Obj_Index)/4)+1
id_ObjA4:	equ ((ptr_ObjA4-Obj_Index)/4)+1
id_ObjA5:	equ ((ptr_ObjA5-Obj_Index)/4)+1
id_ObjA6:	equ ((ptr_ObjA6-Obj_Index)/4)+1
id_ObjA7:	equ ((ptr_ObjA7-Obj_Index)/4)+1
id_ObjA8:	equ ((ptr_ObjA8-Obj_Index)/4)+1
id_ObjA9:	equ ((ptr_ObjA9-Obj_Index)/4)+1
id_ObjAA:	equ ((ptr_ObjAA-Obj_Index)/4)+1
id_ObjAB:	equ ((ptr_ObjAB-Obj_Index)/4)+1
id_ObjAC:	equ ((ptr_ObjAC-Obj_Index)/4)+1
id_ObjAD:	equ ((ptr_ObjAD-Obj_Index)/4)+1
id_ObjAE:	equ ((ptr_ObjAE-Obj_Index)/4)+1
id_ObjAF:	equ ((ptr_ObjAF-Obj_Index)/4)+1

id_ObjB0:	equ ((ptr_ObjB0-Obj_Index)/4)+1
id_ObjB1:	equ ((ptr_ObjB1-Obj_Index)/4)+1
id_ObjB2:	equ ((ptr_ObjB2-Obj_Index)/4)+1
id_ObjB3:	equ ((ptr_ObjB3-Obj_Index)/4)+1
id_ObjB4:	equ ((ptr_ObjB4-Obj_Index)/4)+1
id_ObjB5:	equ ((ptr_ObjB5-Obj_Index)/4)+1
id_ObjB6:	equ ((ptr_ObjB6-Obj_Index)/4)+1
id_ObjB7:	equ ((ptr_ObjB7-Obj_Index)/4)+1
id_ObjB8:	equ ((ptr_ObjB8-Obj_Index)/4)+1
id_ObjB9:	equ ((ptr_ObjB9-Obj_Index)/4)+1
id_ObjBA:	equ ((ptr_ObjBA-Obj_Index)/4)+1
id_ObjBB:	equ ((ptr_ObjBB-Obj_Index)/4)+1
id_ObjBC:	equ ((ptr_ObjBC-Obj_Index)/4)+1
id_ObjBD:	equ ((ptr_ObjBD-Obj_Index)/4)+1
id_ObjBE:	equ ((ptr_ObjBE-Obj_Index)/4)+1
id_ObjBF:	equ ((ptr_ObjBF-Obj_Index)/4)+1

id_ObjC0:	equ ((ptr_ObjC0-Obj_Index)/4)+1
id_ObjC1:	equ ((ptr_ObjC1-Obj_Index)/4)+1
id_ObjC2:	equ ((ptr_ObjC2-Obj_Index)/4)+1
id_ObjC3:	equ ((ptr_ObjC3-Obj_Index)/4)+1
id_ObjC4:	equ ((ptr_ObjC4-Obj_Index)/4)+1
id_ObjC5:	equ ((ptr_ObjC5-Obj_Index)/4)+1
id_ObjC6:	equ ((ptr_ObjC6-Obj_Index)/4)+1
id_ObjC7:	equ ((ptr_ObjC7-Obj_Index)/4)+1
id_ObjC8:	equ ((ptr_ObjC8-Obj_Index)/4)+1
id_ObjC9:	equ ((ptr_ObjC9-Obj_Index)/4)+1
id_ObjCA:	equ ((ptr_ObjCA-Obj_Index)/4)+1
id_ObjCB:	equ ((ptr_ObjCB-Obj_Index)/4)+1
id_ObjCC:	equ ((ptr_ObjCC-Obj_Index)/4)+1
id_ObjCD:	equ ((ptr_ObjCD-Obj_Index)/4)+1
id_ObjCE:	equ ((ptr_ObjCE-Obj_Index)/4)+1
id_ObjCF:	equ ((ptr_ObjCF-Obj_Index)/4)+1

id_ObjD0:	equ ((ptr_ObjD0-Obj_Index)/4)+1
id_ObjD1:	equ ((ptr_ObjD1-Obj_Index)/4)+1
id_ObjD2:	equ ((ptr_ObjD2-Obj_Index)/4)+1
id_ObjD3:	equ ((ptr_ObjD3-Obj_Index)/4)+1
id_ObjD4:	equ ((ptr_ObjD4-Obj_Index)/4)+1
id_ObjD5:	equ ((ptr_ObjD5-Obj_Index)/4)+1
id_ObjD6:	equ ((ptr_ObjD6-Obj_Index)/4)+1
id_ObjD7:	equ ((ptr_ObjD7-Obj_Index)/4)+1
id_ObjD8:	equ ((ptr_ObjD8-Obj_Index)/4)+1
id_ObjD9:	equ ((ptr_ObjD9-Obj_Index)/4)+1
id_ObjDA:	equ ((ptr_ObjDA-Obj_Index)/4)+1
id_ObjDB:	equ ((ptr_ObjDB-Obj_Index)/4)+1
id_ObjDC:	equ ((ptr_ObjDC-Obj_Index)/4)+1
id_ObjDD:	equ ((ptr_ObjDD-Obj_Index)/4)+1
id_ObjDE:	equ ((ptr_ObjDE-Obj_Index)/4)+1
id_ObjDF:	equ ((ptr_ObjDF-Obj_Index)/4)+1

id_ObjE0:	equ ((ptr_ObjE0-Obj_Index)/4)+1
id_ObjE1:	equ ((ptr_ObjE1-Obj_Index)/4)+1
id_ObjE2:	equ ((ptr_ObjE2-Obj_Index)/4)+1
id_ObjE3:	equ ((ptr_ObjE3-Obj_Index)/4)+1
id_ObjE4:	equ ((ptr_ObjE4-Obj_Index)/4)+1
id_ObjE5:	equ ((ptr_ObjE5-Obj_Index)/4)+1
id_ObjE6:	equ ((ptr_ObjE6-Obj_Index)/4)+1
id_ObjE7:	equ ((ptr_ObjE7-Obj_Index)/4)+1
id_ObjE8:	equ ((ptr_ObjE8-Obj_Index)/4)+1
id_ObjE9:	equ ((ptr_ObjE9-Obj_Index)/4)+1
id_ObjEA:	equ ((ptr_ObjEA-Obj_Index)/4)+1
id_ObjEB:	equ ((ptr_ObjEB-Obj_Index)/4)+1
id_ObjEC:	equ ((ptr_ObjEC-Obj_Index)/4)+1
id_ObjED:	equ ((ptr_ObjED-Obj_Index)/4)+1
id_ObjEE:	equ ((ptr_ObjEE-Obj_Index)/4)+1
id_ObjEF:	equ ((ptr_ObjEF-Obj_Index)/4)+1

id_ObjF0:	equ ((ptr_ObjF0-Obj_Index)/4)+1
id_ObjF1:	equ ((ptr_ObjF1-Obj_Index)/4)+1
id_ObjF2:	equ ((ptr_ObjF2-Obj_Index)/4)+1
id_ObjF3:	equ ((ptr_ObjF3-Obj_Index)/4)+1
id_ObjF4:	equ ((ptr_ObjF4-Obj_Index)/4)+1
id_ObjF5:	equ ((ptr_ObjF5-Obj_Index)/4)+1
id_ObjF6:	equ ((ptr_ObjF6-Obj_Index)/4)+1
id_ObjF7:	equ ((ptr_ObjF7-Obj_Index)/4)+1
id_ObjF8:	equ ((ptr_ObjF8-Obj_Index)/4)+1
id_ObjF9:	equ ((ptr_ObjF9-Obj_Index)/4)+1
id_ObjFA:	equ ((ptr_ObjFA-Obj_Index)/4)+1
id_ObjFB:	equ ((ptr_ObjFB-Obj_Index)/4)+1
id_ObjFC:	equ ((ptr_ObjFC-Obj_Index)/4)+1
id_ObjFD:	equ ((ptr_ObjFD-Obj_Index)/4)+1
id_ObjFE:	equ ((ptr_ObjFE-Obj_Index)/4)+1
id_ObjFF:	equ ((ptr_ObjFF-Obj_Index)/4)+1
; ---------------------------------------------------------------------------
; Subroutine translating object speed to update object position
; This moves the object horizontally and vertically
; but does not apply gravity to it
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||
; SpeedToPos:

ObjectMove:
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		rts
; End of function ObjectMove

; =============== S U B R O U T I N E =======================================

ObjectMove_Parent:
		movem.w	obVelX(a1),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a1)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+obX(a0)
		add.l	d2,obY(a1)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+obY(a0)
		rts
; End of function ObjectMove_Parent

; =============== S U B R O U T I N E =======================================

ObjectMove_Reserved:
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,objoff_30(a0)			; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+obX(a0)
		add.l	d2,objoff_34(a0)			; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+obY(a0)
		rts
; End of function ObjectMove_Reserved

; =============== S U B R O U T I N E =======================================
; BossMove:
ObjectMove_Reserved2:
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,objoff_30(a0)			; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+obX(a0)
		add.l	d2,objoff_38(a0)			; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+obY(a0)
		rts
; End of function ObjectMove_Reserved2

; ---------------------------------------------------------------------------
; Subroutine to make an object move and fall downward increasingly fast
; This moves the object horizontally and vertically
; and also applies gravity to its speed
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||
; ObjectFall:

ObjectMoveAndFall:
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$38,obVelY(a0)				; increase vertical speed (apply gravity)
		rts
; End of function ObjectMoveAndFall

; =============== S U B R O U T I N E =======================================

ObjectMoveAndFall_LightGravity:
		moveq	#$20,d1

ObjectMoveAndFall_CustomGravity:
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+obX(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+obY(a0)
		add.w	d1,obVelY(a0)				; increase vertical speed (apply gravity)
		rts
; End of function ObjectMoveAndFall_LightGravity

; =============== S U B R O U T I N E =======================================

ObjectMoveAndFall_Parent:
		moveq	#$38,d1

ObjectMoveAndFall_Parent_CustomGravity:
		movem.w	obVelX(a1),d0/d2				; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a1)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+obX(a0)
		add.l	d2,obY(a1)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+obY(a0)
		add.w	d1,obVelY(a1)				; increase vertical speed (apply gravity)
		rts
; End of function ObjectMoveAndFall_Parent

; =============== S U B R O U T I N E =======================================

ObjectMoveAndFall_Reserved:
		movem.w	obVelX(a0),d0/d2				; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,objoff_30(a0)			; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+obX(a0)
		add.l	d2,objoff_34(a0)			; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+obY(a0)
		addi.w	#$38,obVelY(a0)				; increase vertical speed (apply gravity)
		rts
; End of function ObjectMoveAndFall_Reserved

; ---------------------------------------------------------------------------
; Subroutine to display a sprite/object, when a0 is the object RAM
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


DisplaySprite:
		lea	(v_spritequeue).w,a1
		adda.w	obPriority(a0),a1
		cmpi.w	#$7E,(a1)
		bhs.s	.return
		addq.w	#2,(a1)
		adda.w	(a1),a1
		move.w	a0,(a1)
.return:	rts
; End of function DisplaySprite

; ---------------------------------------------------------------------------
; Subroutine to display a sprite/object, when a1 is the object RAM
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; DisplayA1Sprite:
DisplaySprite2:
		lea	(v_spritequeue).w,a2
		adda.w	obPriority(a1),a2
		cmpi.w	#$7E,(a2)
		bhs.s	.return
		addq.w	#2,(a2)
		adda.w	(a2),a2
		move.w	a1,(a2)
.return:	rts
; End of function DisplaySprite2

; ---------------------------------------------------------------------------
; Subroutine to display a sprite/object, when a0 is the object RAM
; and d0 is already (priority/2)&$380
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; DisplaySprite_Param:
DisplaySprite3:
		lea	(v_spritequeue).w,a1
		adda.w	d0,a1
		cmpi.w	#$7E,(a1)
		bhs.s	.return
		addq.w	#2,(a1)
		adda.w	(a1),a1
		move.w	a0,(a1)
.return:	rts
; End of function DisplaySprite3

; ===========================================================================
; ---------------------------------------------------------------------------
; Routines to mark an enemy/monitor/ring/platform as destroyed
; a0 = the object
; ---------------------------------------------------------------------------
RememberState:
MarkObjGone:
		out_of_range.s	loc_CEB0
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
; does nothing instead of calling DisplaySprite in the case of no deletion
; a0 = the object
MarkObjGone2:
		out_of_range.s	loc_CEB0
		rts
; ---------------------------------------------------------------------------
; Special case where the x-coordinate is pre-fed by the object itself
; a0 = the object
MarkObjGone3:
		out_of_range3.s	loc_CEB0
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

loc_CEB0:
		lea	(v_objstate).w,a2
		moveq	#0,d0
		move.b	obRespawnNo(a0),d0
		beq.s	DeleteObject
		bclr	#7,2(a2,d0.w)

; ---------------------------------------------------------------------------
; Subroutine to delete an object
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

ObjNull:	; The anti-life equation
DeleteObject:
		movea.l	a0,a1
; sub_CF3C:
DeleteObject2:
		moveq	#0,d1
		moveq	#bytesToLcnt(object_size),d0	; we want to clear up to the next object
		; delete the object by setting all of its bytes to 0
-		move.l	d1,(a1)+
		dbf	d0,-
		rts
; End of function DeleteObject

; ---------------------------------------------------------------------------
; Subroutine to animate a sprite using an animation script
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


AnimateSprite:
		moveq	#0,d0
		move.b	obAnim(a0),d0			; move animation number to d0
		cmp.b	obPrevAni(a0),d0		; is animation set to change?
		beq.s	Anim_Run			; if not, branch

		move.b	d0,obPrevAni(a0)		; set previous animation to current one
		clr.b	obAniFrame(a0)			; reset animation
		clr.b	obTimeFrame(a0)			; reset frame duration
; loc_CF64:
Anim_Run:
		subq.b	#1,obTimeFrame(a0)		; subtract 1 from frame duration
		bpl.s	Anim_Wait			; if time remains, branch
		add.w	d0,d0
		adda.w	(a1,d0.w),a1			; calculate address of appropriate animation script
		move.b	(a1),obTimeFrame(a0)		; load frame duration
		moveq	#0,d1
		move.b	obAniFrame(a0),d1		; load current frame number
		move.b	1(a1,d1.w),d0			; read sprite number from script
		cmp.b	#$FA,d0				; MJ: is it a flag from FA to FF?
		bhs.s	Anim_End_FF			; MJ: if so, branch to flag routines
; loc_CF80:
Anim_Next:
		move.b	d0,d1				; move animation number to current frame number
		andi.b	#$1F,d0
		move.b	d0,obFrame(a0)			; load sprite number
		move.b	obStatus(a0),d0			; match the orientation dictated by the object
		rol.b	#3,d1				; with the orientation used by the object engine
		eor.b	d0,d1
		andi.b	#3,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		addq.b	#1,obAniFrame(a0)		; next frame number
; locret_CFA4:
Anim_Wait:
		rts
; ===========================================================================
; loc_CFA6:
Anim_End_FF:
		addq.b	#1,d0				; is the end flag = $FF ?
		bne.s	Anim_End_FE			; if not, branch
		clr.b	obAniFrame(a0)			; restart the animation
		move.b	1(a1),d0			; read sprite number
		bra.s	Anim_Next
; ===========================================================================
; loc_CFB6:
Anim_End_FE:
		addq.b	#1,d0				; is the end flag = $FE ?
		bne.s	Anim_End_FD			; if not, branch
		move.b	2(a1,d1.w),d0			; read the next byte in the script
		sub.b	d0,obAniFrame(a0)		; jump back d0 bytes in the script
		sub.b	d0,d1
		move.b	1(a1,d1.w),d0			; read sprite number
		bra.s	Anim_Next
; ===========================================================================
; loc_CFCA:
Anim_End_FD:
		addq.b	#1,d0				; is the end flag = $FD ?
		bne.s	Anim_End_FC			; if not, branch
		move.b	2(a1,d1.w),obAnim(a0)		; read next byte, run that animation
		rts
; ===========================================================================
; loc_CFD6:
Anim_End_FC:
		addq.b	#1,d0				; is the end flag = $FC ?
		bne.s	Anim_End_FB			; if not, branch
		addq.b	#2,obRoutine(a0)		; jump to next routine
		rts
; ===========================================================================
; loc_CFE0:
Anim_End_FB:
		addq.b	#1,d0				; is the end flag = $FB ?
		bne.s	Anim_End_FA			; if not, branch
		clr.b	obAniFrame(a0)			; reset animation
		clr.b	ob2ndRout(a0)			; reset 2nd routine counter
		rts
; ===========================================================================
; loc_CFF0:
Anim_End_FA:
		addq.b	#1,d0				; is the end flag = $FA ?
		bne.s	Anim_End			; if not, branch
		addq.b	#2,ob2ndRout(a0)		; jump to next routine
		rts
; ===========================================================================
; locret_CFFA:
Anim_End:
		rts
; End of function AnimateSprite

; ---------------------------------------------------------------------------
BldSpr_ScrPos:	dc.l 0
		dc.l Camera_RAM
		dc.l Camera_BG_X_pos
		dc.l Camera_BG3_X_pos

; =============== S U B R O U T I N E =======================================


BuildSprites:
		lea	(Sprite_Table).w,a2
		moveq	#0,d5
		moveq	#0,d4
		tst.b	(Level_started_flag).w
		beq.s	+
		jsr	(BuildHUD).l
		bsr.w	BuildRings
+
		lea	(v_spritequeue).w,a4
		moveq	#7,d7	; 8 priority levels

BuildSprites_LevelLoop:
		tst.w	(a4)	; does this level have any objects?
		beq.w	BuildSprites_NextLevel	; if not, check the next one
		moveq	#2,d6

BuildSprites_ObjLoop:
		movea.w	(a4,d6.w),a0 ; a0=object
		; These are sanity checks, to detect invalid objects which should not
		; have been queued for display. S3K gets rids of them compeletely,
		; since they should not be needed and they just slow this code down.
		tst.b	obID(a0)		; is this object slot occupied?
		beq.w	BuildSprites_Crash	; if not, branch
		tst.l	obMap(a0)		; does this object have any mappings?
		beq.w	BuildSprites_NextObj	; if not, branch
		andi.b	#$7F,obRender(a0)	; clear on-screen flag
		move.b	obRender(a0),d0
		move.w	obX(a0),d3
		move.w	obY(a0),d2
		move.b	d0,d4
		btst	#6,d0		; is the multi-draw flag set?
		bne.w	BuildSprites_MultiDraw	; if it is, branch
		andi.w	#$C,d0		; is this to be positioned by screen coordinates?
		beq.s	BuildSprites_ScreenSpaceObj	; if it is, branch
		movea.l	BldSpr_ScrPos(pc,d0.w),a1
		moveq	#0,d0
		move.b	obActWid(a0),d0
		sub.w	(a1),d3
		move.w	d3,d1
		add.w	d0,d1	; is the object right edge to the left of the screen?
		bmi.w	BuildSprites_NextObj	; if it is, branch
		move.w	d3,d1
		sub.w	d0,d1
		cmpi.w	#320,d1	; is the object left edge to the right of the screen?
		bge.w	BuildSprites_NextObj	; if it is, branch
		addi.w	#128,d3	; VDP sprites start at 128px
		btst	#4,d4		; is the accurate Y check flag set?
		beq.s	BuildSprites_ApproxYCheck	; if not, branch
		moveq	#0,d0
		move.b	obHeight(a0),d0
		sub.w	obMap(a1),d2
		move.w	d2,d1
		add.w	d0,d1
		bmi.s	BuildSprites_NextObj	; if the object is above the screen
		move.w	d2,d1
		sub.w	d0,d1
		cmpi.w	#224,d1
		bge.s	BuildSprites_NextObj	; if the object is below the screen
		addi.w	#128,d2
		bra.s	BuildSprites_DrawSprite
; ---------------------------------------------------------------------------

BuildSprites_ScreenSpaceObj:
		move.w	obScreenY(a0),d2
		move.w	obScreenX(a0),d3
		bra.s	BuildSprites_DrawSprite
; ---------------------------------------------------------------------------

BuildSprites_ApproxYCheck:
		move.w	obY(a0),d2
		sub.w	obMap(a1),d2
		addi.w	#128,d2
	andi.w	#$7FF,d2
		cmpi.w	#$60,d2	; assume Y radius to be 32 pixels
		blo.s	BuildSprites_NextObj
		cmpi.w	#$180,d2
		bhs.s	BuildSprites_NextObj

BuildSprites_DrawSprite:
		movea.l	obMap(a0),a1
		moveq	#0,d1
		btst	#5,d4	; is the static mappings flag set?
		bne.s	+	; if it is, branch
		move.b	obFrame(a0),d1
		add.w	d1,d1
		adda.w	(a1,d1.w),a1
		move.w	(a1)+,d1
		subq.w	#1,d1	; get number of pieces
		bmi.s	++	; if there are 0 pieces, branch
+
		bsr.w	DrawSprite	; draw the sprite
+
		ori.b	#$80,obRender(a0)	; set on-screen flag

BuildSprites_NextObj:
		addq.w	#2,d6	; load next object
		subq.w	#2,(a4)	; decrement object count
		bne.w	BuildSprites_ObjLoop	; if there are objects left, repeat

BuildSprites_NextLevel:
		lea	$80(a4),a4
		dbf	d7,BuildSprites_LevelLoop
		move.b	d5,(v_spritecount).w
		; Terminate the sprite list.
		; If the sprite list is full, then set the link field of the last
		; entry to 0. Otherwise, push the next sprite offscreen and set its
		; link field to 0. You might be thinking why this doesn't just do the
		; first one no matter what. Well, think about what if the sprite list
		; was empty: then it would access data before the start of the list.
		cmpi.b	#80,d5	; was the sprite limit reached?
		beq.s	+	; if it was, branch
		clr.l	(a2)	; set link field to 0
		rts
+
		clr.b	-5(a2)	; set link field to 0
		rts
; ---------------------------------------------------------------------------

BuildSprites_Crash:
		move.w	(1).w,d0	; force a crash if the object has a blank ID/mapping pointers
		bra.s	BuildSprites_NextObj
; ---------------------------------------------------------------------------

BuildSprites_MultiDraw:
		move.l	a4,-(sp)
		lea	(Camera_RAM).w,a4
		movea.w	obGfx(a0),a3
		movea.l	obMap(a0),a5
		moveq	#0,d0

		; check if object is within X bounds
		move.b	mainspr_width(a0),d0	; load pixel width
		move.w	obX(a0),d3
		sub.w	(a4),d3
		move.w	d3,d1
		add.w	d0,d1
		bmi.w	BuildSprites_MultiDraw_NextObj
		move.w	d3,d1
		sub.w	d0,d1
		cmpi.w	#320,d1
		bge.w	BuildSprites_MultiDraw_NextObj
	addi.w	#128,d3

	; check if object is within Y bounds
	btst	#4,d4
	beq.s	+
	moveq	#0,d0
	move.b	mainspr_height(a0),d0	; load pixel height
		move.w	obY(a0),d2
		sub.w	4(a4),d2
	move.w	d2,d1
	add.w	d0,d1
	bmi.w	BuildSprites_MultiDraw_NextObj
	move.w	d2,d1
	sub.w	d0,d1
	cmpi.w	#224,d1
	bge.w	BuildSprites_MultiDraw_NextObj
	addi.w	#128,d2
	bra.s	++
+
	move.w	obY(a0),d2
	sub.w	4(a4),d2
		addi.w	#128,d2
	andi.w	#$7FF,d2
		cmpi.w	#$60,d2
		blo.s	BuildSprites_MultiDraw_NextObj
		cmpi.w	#$180,d2
		bhs.s	BuildSprites_MultiDraw_NextObj
+
	moveq	#0,d1
	move.b	mainspr_mapframe(a0),d1	; get current frame
	beq.s	+
	add.w	d1,d1
	movea.l	a5,a1
	adda.w	(a1,d1.w),a1
	move.w	(a1)+,d1
	subq.w	#1,d1
	bmi.s	+
	move.w	d4,-(sp)
	bsr.w	ChkDrawSprite	; draw the sprite
	move.w	(sp)+,d4
+
		ori.b	#$80,obRender(a0)	; set onscreen flag
		lea	subspr_data(a0),a6
		moveq	#0,d0
		move.b	mainspr_childsprites(a0),d0	; get child sprite count
		subq.w	#1,d0		; if there are 0, go to next object
		blo.s	BuildSprites_MultiDraw_NextObj

-		swap	d0
		move.w	(a6)+,d3	; get X pos
		sub.w	(a4),d3
		addi.w	#128,d3
		move.w	(a6)+,d2	; get Y pos
		sub.w	4(a4),d2
		addi.w	#128,d2
	andi.w	#$7FF,d2
		addq.w	#1,a6
		moveq	#0,d1
		move.b	(a6)+,d1	; get mapping frame
		add.w	d1,d1
		movea.l	a5,a1
		adda.w	(a1,d1.w),a1
		move.w	(a1)+,d1
		subq.w	#1,d1
		bmi.s	+
	move.w	d4,-(sp)
		bsr.w	ChkDrawSprite
	move.w	(sp)+,d4
+
		swap	d0
		dbf	d0,-	; repeat for number of child sprites

BuildSprites_MultiDraw_NextObj:
		movea.l	(sp)+,a4
		bra.w	BuildSprites_NextObj
; End of function BuildSprites


; =============== S U B R O U T I N E =======================================


DrawSprite:
		movea.w	obGfx(a0),a3

ChkDrawSprite:
		btst	#0,d4	; is the sprite to be X-flipped?
		bne.s	DrawSprite_FlipX	; if it is, branch
		btst	#1,d4	; is the sprite to be Y-flipped?
		bne.w	DrawSprite_FlipY	; if it is, branch

DrawSprite_Loop:
	; In a rather overzealous optimisation, this game doesn't check if
	; the sprite limit has been reached every time it processes a sprite
	; piece. Naturally, this leads to the 'Sprite_Table' buffer being
	; overflowed if too many sprites are processed. To mitigate this, the
	; developers placed an $80 byte large spill buffer after
	; 'Sprite_Table', to 'catch' the overflow. Unfortunately, this spill
	; buffer is not big enough to catch all overflow: this oversight is
	; responsible for the famous 'Ashua' bug. To fix this, we'll just
	; undo this optimistaion. Sonic 3 & Knuckles undid this optimistaion
	; too, but heavily optimised the rest of 'BuildSprites' to make up
	; for it.
		cmpi.b	#$50,d5		; has the sprite limit been reached?
		bhs.s	DrawSprite_Done	; if it has, branch
		move.b	(a1)+,d0
		ext.w	d0
		add.w	d2,d0
		move.w	d0,(a2)+	; set Y pos
		move.b	(a1)+,(a2)+	; set sprite size
		addq.b	#1,d5
		move.b	d5,(a2)+	; set link field
		move.w	(a1)+,d0
		add.w	a3,d0
		move.w	d0,(a2)+	; set art tile and flags
		addq.w	#2,a1
		move.w	(a1)+,d0
		add.w	d3,d0
		andi.w	#$1FF,d0
		bne.s	+
		addq.w	#1,d0	; avoid activating sprite masking
+
		move.w	d0,(a2)+	; set X pos
		dbf	d1,DrawSprite_Loop	; repeat for next sprite

DrawSprite_Done:
		rts
; ---------------------------------------------------------------------------

DrawSprite_FlipX:
		btst	#1,d4	; is it to be Y-flipped as well?
		bne.w	DrawSprite_FlipXY	; if it is, branch

-
	cmpi.b	#80,d5		; has the sprite limit been reached?
	bhs.s	++		; if it has, branch
		move.b	(a1)+,d0
		ext.w	d0
		add.w	d2,d0
		move.w	d0,(a2)+
		move.b	(a1)+,d4	; store size for later use
		move.b	d4,(a2)+
		addq.b	#1,d5
		move.b	d5,(a2)+
		move.w	(a1)+,d0
		add.w	a3,d0
		eori.w	#$800,d0	; toggle X flip flag
		move.w	d0,(a2)+
		addq.w	#2,a1
		move.w	(a1)+,d0
		neg.w	d0	; negate X offset
		move.b	CellOffsets_XFlip(pc,d4.w),d4
		sub.w	d4,d0	; subtract sprite size
		add.w	d3,d0
		andi.w	#$1FF,d0
		bne.s	+
		addq.w	#1,d0
+
		move.w	d0,(a2)+
		dbf	d1,-
+
		rts
; ---------------------------------------------------------------------------
; offsets for horizontally mirrored sprite pieces
CellOffsets_XFlip:
		dc.b   8,  8,  8,  8	; 4
		dc.b $10,$10,$10,$10	; 8
		dc.b $18,$18,$18,$18	; 12
		dc.b $20,$20,$20,$20	; 16
; offsets for vertically mirrored sprite pieces
CellOffsets_YFlip:
		dc.b   8,$10,$18,$20	; 4
		dc.b   8,$10,$18,$20	; 8
		dc.b   8,$10,$18,$20	; 12
		dc.b   8,$10,$18,$20	; 16
; ---------------------------------------------------------------------------

DrawSprite_FlipY:
-
	cmpi.b	#80,d5		; has the sprite limit been reached?
	bhs.s	++		; if it has, branch
		move.b	(a1)+,d0
		move.b	(a1),d4
		ext.w	d0
		neg.w	d0
		move.b	CellOffsets_YFlip(pc,d4.w),d4
		sub.w	d4,d0
		add.w	d2,d0
		move.w	d0,(a2)+	; set Y pos
		move.b	(a1)+,(a2)+	; set size
		addq.b	#1,d5
		move.b	d5,(a2)+	; set link field
		move.w	(a1)+,d0
		add.w	a3,d0
		eori.w	#$1000,d0	; toggle Y flip flag
		move.w	d0,(a2)+	; set art tile and flags
		addq.w	#2,a1
		move.w	(a1)+,d0
		add.w	d3,d0
		andi.w	#$1FF,d0
		bne.s	+
		addq.w	#1,d0
+
		move.w	d0,(a2)+	; set X pos
		dbf	d1,-
+
		rts
; ---------------------------------------------------------------------------
; offsets for vertically mirrored sprite pieces
CellOffsets_YFlip2:
		dc.b   8,$10,$18,$20	; 4
		dc.b   8,$10,$18,$20	; 8
		dc.b   8,$10,$18,$20	; 12
		dc.b   8,$10,$18,$20	; 16
; ---------------------------------------------------------------------------

DrawSprite_FlipXY:
-
	cmpi.b	#80,d5		; has the sprite limit been reached?
	bhs.s	++		; if it has, branch
		move.b	(a1)+,d0
		move.b	(a1),d4
		ext.w	d0
		neg.w	d0
		move.b	CellOffsets_YFlip2(pc,d4.w),d4
		sub.w	d4,d0
		add.w	d2,d0
		move.w	d0,(a2)+
		move.b	(a1)+,d4
		move.b	d4,(a2)+
		addq.b	#1,d5
		move.b	d5,(a2)+
		move.w	(a1)+,d0
		add.w	a3,d0
		eori.w	#$1800,d0	; toggle X and Y flip flags
		move.w	d0,(a2)+
		addq.w	#2,a1
		move.w	(a1)+,d0
		neg.w	d0
		move.b	CellOffsets_XFlip2(pc,d4.w),d4
		sub.w	d4,d0
		add.w	d3,d0
		andi.w	#$1FF,d0
		bne.s	+
		addq.w	#1,d0
+
		move.w	d0,(a2)+
		dbf	d1,DrawSprite_FlipXY
+
		rts
; End of function DrawSprite

; ---------------------------------------------------------------------------
; offsets for horizontally mirrored sprite pieces
CellOffsets_XFlip2:
		dc.b   8,  8,  8,  8	; 4
		dc.b $10,$10,$10,$10	; 8
		dc.b $18,$18,$18,$18	; 12
		dc.b $20,$20,$20,$20	; 16
; ---------------------------------------------------------------------------
		include	"objects/S1/sub ChkObjectVisible.asm"
; ============================================================================
; ----------------------------------------------------------------------------
; Pseudo-object that manages where rings are placed onscreen
; as you move through the level, and otherwise updates them.
; ----------------------------------------------------------------------------

; RingPosLoad:
RingsManager:
		moveq	#0,d0
		move.b	(Rings_manager_routine).w,d0
		move.w	RingsManager_States(pc,d0.w),d0
		jmp	RingsManager_States(pc,d0.w)
; End of function RingsManager

; ===========================================================================
; RPL_Index:
RingsManager_States:
		dc.w RingsManager_Init-RingsManager_States
		dc.w RingsManager_Main-RingsManager_States
; ===========================================================================
; RPL_Main:
RingsManager_Init:
		addq.b	#2,(Rings_manager_routine).w	; => RingsManager_Main
		bsr.w	RingsManager_Setup		; perform initial setup
		lea	(Ring_Positions).w,a1
		move.w	(Camera_RAM).w,d4
		subq.w	#8,d4
		bhi.s	loc_D896
		moveq	#1,d4				; no negative values allowed
		bra.s	loc_D896
; ---------------------------------------------------------------------------

loc_D892:
		lea	6(a1),a1			; load next ring

loc_D896:
		cmp.w	2(a1),d4			; is the X pos of the ring < camera X pos?
		bhi.s	loc_D892			; if it is, check next ring
		move.w	a1,(Ring_start_addr).w		; set start addresses
		move.w	a1,(Ring_start_addr_P2).w
		addi.w	#$150,d4			; advance by a screen
		bra.s	loc_D8AE
; ---------------------------------------------------------------------------

loc_D8AA:
		lea	6(a1),a1			; load next ring

loc_D8AE:
		cmp.w	2(a1),d4			; is the X pos of the ring < camera X + 336?
		bhi.s	loc_D8AA			; if it is, check next ring
		move.w	a1,(Ring_end_addr).w		; set end addresses
		move.w	a1,(Ring_end_addr_P2).w
		move.b	#1,(Level_started_flag).w
		rts
; ===========================================================================
; RPL_Next:
RingsManager_Main:
		lea	(Ring_Positions).w,a1
		move.w	#255-1,d1			; do 255 rings

loc_D8CC:
		move.b	(a1),d0				; is there a ring in this slot?
		beq.s	loc_D8EA			; if not, branch
		bmi.s	loc_D8EA
		subq.b	#1,(a1)				; decrement timer
		bne.s	loc_D8EA			; if it's not 0 yet, branch
		move.b	#6,(a1)				; reset timer
		addq.b	#1,1(a1)			; increment frame
		cmpi.b	#8,1(a1)			; is it destruction time yet?
		bne.s	loc_D8EA			; if not, branch
		move.w	#-1,(a1)			; destroy ring

loc_D8EA:
		lea	6(a1),a1
		dbf	d1,loc_D8CC

		; update ring start and end addresses
		movea.w	(Ring_start_addr).w,a1
		move.w	(Camera_RAM).w,d4
		subq.w	#8,d4
		bhi.s	loc_D906
		moveq	#1,d4
		bra.s	loc_D906
; ---------------------------------------------------------------------------

loc_D902:
		lea	6(a1),a1

loc_D906:
		cmp.w	2(a1),d4
		bhi.s	loc_D902
		bra.s	loc_D910
; ---------------------------------------------------------------------------

loc_D90E:
		subq.w	#6,a1

loc_D910:
		cmp.w	-4(a1),d4
		bls.s	loc_D90E
		move.w	a1,(Ring_start_addr).w		; update start address

		movea.w	(Ring_end_addr).w,a2
		addi.w	#$150,d4
		bra.s	loc_D928
; ---------------------------------------------------------------------------

loc_D924:
		lea	6(a2),a2

loc_D928:
		cmp.w	2(a2),d4
		bhi.s	loc_D924
		bra.s	loc_D932
; ---------------------------------------------------------------------------

loc_D930:
		subq.w	#6,a2

loc_D932:
		cmp.w	-4(a2),d4
		bls.s	loc_D930
		move.w	a2,(Ring_end_addr).w		; update end address
		move.w	a1,(Ring_start_addr_P2).w	; otherwise, copy over P1 addresses
		move.w	a2,(Ring_end_addr_P2).w
		rts
; ---------------------------------------------------------------------------
; Subroutine to handle ring collision
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; sub_D998:
Touch_Rings:
		movea.w	(Ring_start_addr).w,a1
		movea.w	(Ring_end_addr).w,a2
		cmpa.w	#v_player,a0
		beq.s	+
		movea.w	(Ring_start_addr_P2).w,a1
		movea.w	(Ring_end_addr_P2).w,a2
+
		cmpa.l	a1,a2
		beq.w	locret_DA36
		cmpi.w	#90,flashtime(a0)
		bhs.s	locret_DA36
		move.w	obX(a0),d2
		move.w	obY(a0),d3
		subq.w	#8,d2
		moveq	#0,d5
		move.b	obHeight(a0),d5
		subq.b	#3,d5
		sub.w	d5,d3
	if FixBugs
		cmpi.b	#AniIDSonAni_Duck,obAnim(a0)
	else
		; Bug: This does not check either player's ducking frame!
		; Sonic's ducking frame is $80, and Tails's frame is $5B.
		; However, this does work for Sonic 1's mapping frames.
		cmpi.b	#$39,obFrame(a0)
	endif
		bne.s	loc_D9E0
		addi.w	#$C,d3
		moveq	#$A,d5

loc_D9E0:
		move.w	#6,d1
		move.w	#12,d6
		move.w	#$10,d4
		add.w	d5,d5

loc_D9EE:
		tst.w	(a1)
		bne.w	loc_DA2C
		move.w	2(a1),d0
		sub.w	d1,d0
		sub.w	d2,d0
		bhs.s	loc_DA06
		add.w	d6,d0
		blo.s	loc_DA0C
		bra.w	loc_DA2C
; ---------------------------------------------------------------------------

loc_DA06:
		cmp.w	d4,d0
		bhi.w	loc_DA2C

loc_DA0C:
		move.w	4(a1),d0
		sub.w	d1,d0
		sub.w	d3,d0
		bhs.s	loc_DA1E
		add.w	d6,d0
		blo.s	loc_DA24
		bra.w	loc_DA2C
; ---------------------------------------------------------------------------

loc_DA1E:
		cmp.w	d5,d0
		bhi.w	loc_DA2C

loc_DA24:
		move.w	#$604,(a1)
		bsr.w	CollectRing

loc_DA2C:
		lea	6(a1),a1
		cmpa.l	a1,a2
		bne.w	loc_D9EE

locret_DA36:
		rts
; End of function Touch_Rings


; =============== S U B R O U T I N E =======================================


BuildRings:
		movea.w	(Ring_start_addr).w,a0
		movea.w	(Ring_end_addr).w,a4
		cmpa.l	a0,a4
		bne.s	loc_DA46
		rts
; ---------------------------------------------------------------------------

loc_DA46:
		lea	(Camera_RAM).w,a3

loc_DA4A:
		tst.w	(a0)
		bmi.w	loc_DAA8
		move.w	2(a0),d3
		sub.w	Camera_X_pos-Camera_RAM(a3),d3
		addi.w	#128,d3
		move.w	4(a0),d2
		sub.w	Camera_Y_pos-Camera_RAM(a3),d2
		addq.w	#8,d2
		bmi.s	loc_DAA8
		cmpi.w	#224+16,d2
		bge.s	loc_DAA8
		addi.w	#128-8,d2
		lea	(off_DC04).l,a1
		moveq	#0,d1
		move.b	1(a0),d1
		bne.s	loc_DA84
		move.b	(v_ani1_frame).w,d1

loc_DA84:
		add.w	d1,d1
		adda.w	(a1,d1.w),a1
		move.b	(a1)+,d0
		ext.w	d0
		add.w	d2,d0
		move.w	d0,(a2)+
		move.b	(a1)+,(a2)+
		addq.b	#1,d5
		move.b	d5,(a2)+
		move.w	(a1)+,d0
		addi.w	#make_art_tile(ArtTile_Ring,1,0),d0
		move.w	d0,(a2)+
		addq.w	#2,a1
		move.w	(a1)+,d0
		add.w	d3,d0
		move.w	d0,(a2)+

loc_DAA8:
		lea	6(a0),a0
		cmpa.l	a0,a4
		bne.w	loc_DA4A
		rts
; End of function BuildRings


; ---------------------------------------------------------------------------
; Subroutine to perform initial rings manager setup
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; RingsManager2:
RingsManager_Setup:
		clearRAM Ring_Positions, Ring_Positions_End
		moveq	#0,d0
		move.w	(Current_ZoneAndAct).w,d0
		lsl.b	#6,d0
		lsr.w	#5,d0
		lea	(RingPos_Index).l,a1
		move.w	(a1,d0.w),d0
		lea	(a1,d0.w),a1
		lea	(Ring_Positions+6).w,a2
; loc_DB88:
RingsMgr_NextRowOrCol:
		move.w	(a1)+,d2
		bmi.s	RingsMgr_SortRings
		move.w	(a1)+,d3
		bmi.s	RingsMgr_RingCol
		move.w	d3,d0
		rol.w	#4,d0
		andi.w	#7,d0
		andi.w	#$FFF,d3
; loc_DB9C:
RingsMgr_NextRingInRow:
		clr.w	(a2)+
		move.w	d2,(a2)+
		move.w	d3,(a2)+
		addi.w	#$18,d2
		dbf	d0,RingsMgr_NextRingInRow
		bra.s	RingsMgr_NextRowOrCol
; ===========================================================================
; loc_DBAE:
RingsMgr_RingCol:
		move.w	d3,d0
		rol.w	#4,d0
		andi.w	#7,d0
		andi.w	#$FFF,d3
; loc_DBBA:
RingsMgr_NextRingInCol:
		clr.w	(a2)+
		move.w	d2,(a2)+
		move.w	d3,(a2)+
		addi.w	#$18,d3
		dbf	d0,RingsMgr_NextRingInCol
		bra.s	RingsMgr_NextRowOrCol
; ===========================================================================
; loc_Dbhs:
RingsMgr_SortRings:
		moveq	#-1,d0
		move.l	d0,(a2)+
		lea	(Ring_Positions+2).w,a1
		move.w	#255-1,d3

loc_DBD8:
		move.w	d3,d4
		lea	6(a1),a2
		move.w	(a1),d0

loc_DBE0:
		tst.w	(a2)
		beq.s	loc_DBF2
		cmp.w	(a2),d0
		bls.s	loc_DBF2
		move.l	(a1),d1
		move.l	(a2),d0
		move.l	d0,(a1)
		move.l	d1,(a2)
		swap	d0

loc_DBF2:
		lea	6(a2),a2
		dbf	d4,loc_DBE0
		lea	6(a1),a1
		dbf	d3,loc_DBD8
		rts
; End of function RingsManager_Setup

; ---------------------------------------------------------------------------
off_DC04:	include	"mappings/sprite/Rings.asm"

; ===========================================================================
; ---------------------------------------------------------------------------
; Objects Manager
; Subroutine that keeps track of any objects that need to remember
; their state, such as monitors or enemies.
;
; input variables:
;  -none-
;
; writes:
;  d0, d1
;  d2 = respawn index of object to load
;  d6 = camera position
;
;  a0 = address in object placement list
;  a2 = respawn table
; ---------------------------------------------------------------------------

; ObjPosLoad:
ObjectsManager:
		moveq	#0,d0
		move.b	(Obj_placement_routine).w,d0
		move.w	ObjectsManager_States(pc,d0.w),d0
		jmp	ObjectsManager_States(pc,d0.w)
; End of function ObjectsManager

; ===========================================================================
; OPL_Index:
ObjectsManager_States:
		dc.w ObjectsManager_Init-ObjectsManager_States
		dc.w ObjectsManager_Main-ObjectsManager_States
; ===========================================================================
; loc_DC68:
ObjectsManager_Init:
		addq.b	#2,(Obj_placement_routine).w
		move.w	(Current_ZoneAndAct).w,d0
		move.w	d0,d1
		lsr.w	#5,d0
		andi.w	#$FF,d1
		add.w	d1,d1
		add.w	d1,d0
;		lsl.b	#6,d0
;		lsr.w	#4,d0
		lea	(ObjPos_Index).l,a0
		movea.l	a0,a1
		adda.w	(a0,d0.w),a0
		move.l	a0,(Obj_load_addr_right).w
		move.l	a0,(Obj_load_addr_left).w
		move.l	a0,(Obj_load_addr_right_P2).w
		move.l	a0,(Obj_load_addr_left_P2).w
		lea	(v_objstate).w,a2
		move.w	#$101,(a2)+
		move.w	#bytesToLcnt(v_objstate_end-v_objstate-2),d0

loc_DC9C:
		clr.l	(a2)+
		dbf	d0,loc_DC9C

		; Clear the last word, since the above loop only does longwords.
	if (v_objstate_end-v_objstate-2)&2
		clr.w	(a2)+
	endif
		lea	(v_objstate).w,a2
		moveq	#0,d2
		move.w	(Camera_RAM).w,d6
		subi.w	#$80,d6
		bhs.s	loc_DCB4
		moveq	#0,d6

loc_DCB4:
		andi.w	#-$80,d6
		movea.l	(Obj_load_addr_right).w,a0

loc_DCBC:
		cmp.w	(a0),d6
		bls.s	loc_DCCE
		tst.b	4(a0)
		bpl.s	loc_DCCA
		move.b	(a2),d2
		addq.b	#1,(a2)

loc_DCCA:
		addq.w	#6,a0
		bra.s	loc_DCBC
; ===========================================================================

loc_DCCE:
		move.l	a0,(Obj_load_addr_right).w
		move.l	a0,(Obj_load_addr_right_P2).w
		movea.l	(Obj_load_addr_left).w,a0
		subi.w	#$80,d6
		blo.s	loc_DCF2

loc_DCE0:
		cmp.w	(a0),d6
		bls.s	loc_DCF2
		tst.b	4(a0)
		bpl.s	loc_DCEE
		addq.b	#1,1(a2)

loc_DCEE:
		addq.w	#6,a0
		bra.s	loc_DCE0
; ===========================================================================

loc_DCF2:
		move.l	a0,(Obj_load_addr_left).w
		move.l	a0,(Obj_load_addr_left_P2).w
		move.w	#-1,(Camera_X_pos_last).w
		move.w	#-1,(Camera_X_pos_last_P2).w
; ===========================================================================
; loc_DD14:
ObjectsManager_Main:
		move.w	(Camera_RAM).w,d1
		subi.w	#$80,d1
		andi.w	#-$80,d1
		move.w	d1,(Camera_X_pos_coarse).w
		lea	(v_objstate).w,a2
		moveq	#0,d2
		move.w	(Camera_RAM).w,d6
		andi.w	#-$80,d6
		cmp.w	(Camera_X_pos_last).w,d6
		beq.s	loc_DD94.return
		bge.s	loc_DD9A
		move.w	d6,(Camera_X_pos_last).w
		movea.l	(Obj_load_addr_left).w,a0
		subi.w	#$80,d6
		blo.s	loc_DD76

loc_DD4A:
		cmp.w	-6(a0),d6
		bge.s	loc_DD76
		subq.w	#6,a0
		tst.b	4(a0)
		bpl.s	loc_DD60
		subq.b	#1,1(a2)
		move.b	1(a2),d2

loc_DD60:
		bsr.w	sub_E0D2
		bne.s	loc_DD6A
		subq.w	#6,a0
		bra.s	loc_DD4A
; ===========================================================================

loc_DD6A:
		tst.b	4(a0)
		bpl.s	loc_DD74
		addq.b	#1,1(a2)

loc_DD74:
		addq.w	#6,a0

loc_DD76:
		move.l	a0,(Obj_load_addr_left).w
		movea.l	(Obj_load_addr_right).w,a0
		addi.w	#$300,d6

loc_DD82:
		cmp.w	-6(a0),d6
		bgt.s	loc_DD94
		tst.b	-2(a0)
		bpl.s	loc_DD90
		subq.b	#1,(a2)

loc_DD90:
		subq.w	#6,a0
		bra.s	loc_DD82
; ===========================================================================

loc_DD94:
		move.l	a0,(Obj_load_addr_right).w
.return:	rts
; ===========================================================================

loc_DD9A:
		move.w	d6,(Camera_X_pos_last).w
		movea.l	(Obj_load_addr_right).w,a0
		addi.w	#$280,d6

loc_DDA6:
		cmp.w	(a0),d6
		bls.s	loc_DDBA
		tst.b	4(a0)
		bpl.s	loc_DDB4
		move.b	(a2),d2
		addq.b	#1,(a2)

loc_DDB4:
		bsr.w	sub_E0D2
		beq.s	loc_DDA6

loc_DDBA:
		move.l	a0,(Obj_load_addr_right).w
		movea.l	(Obj_load_addr_left).w,a0
		subi.w	#$300,d6
		blo.s	loc_DDDA

loc_DDC8:
		cmp.w	(a0),d6
		bls.s	loc_DDDA
		tst.b	4(a0)
		bpl.s	loc_DDD6
		addq.b	#1,1(a2)

loc_DDD6:
		addq.w	#6,a0
		bra.s	loc_DDC8
; ===========================================================================

loc_DDDA:
		move.l	a0,(Obj_load_addr_left).w
		rts

; =============== S U B R O U T I N E =======================================


sub_E0D2:
		tst.b	4(a0)
		bpl.s	loc_E0E6
		bset	#7,2(a2,d2.w)
		beq.s	loc_E0E6
		addq.w	#6,a0
		moveq	#0,d0
		rts
; ---------------------------------------------------------------------------

loc_E0E6:
		bsr.w	FindFreeObj
		bne.s	FindFreeObj.return
		move.w	(a0)+,obX(a1)
		move.w	(a0)+,d0
		move.w	d0,d1
		andi.w	#$FFF,d0
		move.w	d0,obY(a1)
		rol.w	#2,d1
		andi.b	#3,d1
		move.b	d1,obRender(a1)
		move.b	d1,obStatus(a1)
		move.b	(a0)+,d0
		bpl.s	loc_E116
		andi.b	#$7F,d0
		move.b	d2,obRespawnNo(a1)

loc_E116:
		_move.b	d0,obID(a1)
		move.b	(a0)+,obSubtype(a1)
		moveq	#0,d0
		rts
; End of function sub_E0D2


; ===========================================================================
; ---------------------------------------------------------------------------
; Single object loading subroutine
; Find an empty object array
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_E182: SingleObjectLoad:
FindFreeObj:
		lea	(v_lvlobjspace).w,a1		; a1=object
		move.w	#(v_lvlobjend-v_lvlobjspace)/object_size-1,d0	; search to end of table

.loop:
		tst.b	obID(a1)			; is object RAM slot empty?
		beq.s	.return				; if yes, branch
		lea	object_size(a1),a1		; load obj address ; goto next object RAM slot
		dbf	d0,.loop			; repeat until end

.return:
		rts
; End of function FindFreeObj

; ===========================================================================
; ---------------------------------------------------------------------------
; Single object loading subroutine
; Find an empty object array AFTER the current one in the table
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_E198: S1SingleObjectLoad2:
FindNextFreeObj:
		movea.l	a0,a1
		move.w	#v_lvlobjend,d0
		sub.w	a0,d0				; subtract current object location
		lsr.w	#object_size_bits,d0		; divide by $40
		subq.w	#1,d0				; keep from going over the object zone
		blo.s	FindFreeObj.return

.loop:
		tst.b	obID(a1)			; is object RAM slot empty?
		beq.s	FindFreeObj.return		; if yes, branch
		lea	object_size(a1),a1		; load obj address ; goto next object RAM slot
		dbf	d0,.loop			; repeat until end
		rts
; End of function FindNextFreeObj

		include	"objects/41 Springs.asm"
; ===========================================================================
; byte_E934:
Obj41_SlopeData_DiagUp:
		dc.b $10,$10,$10,$10
		dc.b $10,$10,$10,$10
		dc.b $10,$10,$10,$10
		dc.b  $E, $C, $A,  8
		dc.b   6,  4,  2,  0
		dc.b $FE,$FC,$FC,$FC
		dc.b $FC,$FC,$FC,$FC
		even

; byte_E950:
Obj41_SlopeData_DiagDown:
		dc.b $F4,$F0,$F0,$F0
		dc.b $F0,$F0,$F0,$F0
		dc.b $F0,$F0,$F0,$F0
		dc.b $F2,$F4,$F6,$F8
		dc.b $FA,$FC,$FE,  0
		dc.b   2,  4,  4,  4
		dc.b   4,  4,  4,  4
		even

; animation script
Ani_obj41:	dc.w byte_E978-Ani_obj41
		dc.w byte_E97B-Ani_obj41
		dc.w byte_E987-Ani_obj41
		dc.w byte_E98A-Ani_obj41
		dc.w byte_E996-Ani_obj41
		dc.w byte_E999-Ani_obj41
byte_E978:	dc.b  $F,  0,$FF
byte_E97B:	dc.b   0,  1,  0,  0,  2,  2,  2,  2
		dc.b   2,  2,$FD,  0
byte_E987:	dc.b  $F,  3,$FF
byte_E98A:	dc.b   0,  4,  3,  3,  5,  5,  5,  5
		dc.b   5,  5,$FD,  2
byte_E996:	dc.b  $F,  7,$FF
byte_E999:	dc.b   0,  8,  7,  7,  9,  9,  9,  9
		dc.b   9,  9,$FD,  4
		even

; animation script
Ani_MovingSpring:
.Wheel:
		dc.w	byte_209C6A-.Wheel
byte_209C6A:	dc.b   8,  0,1,    $FF
		even
; ----------------------------------------------------------------------------
; Primary sprite mappings for springs
; ----------------------------------------------------------------------------
Map_obj41:
		dc.w word_EA4A-Map_obj41
		dc.w word_EA5C-Map_obj41
		dc.w word_EA66-Map_obj41
		dc.w word_EA78-Map_obj41
		dc.w word_EA8A-Map_obj41
		dc.w word_EA94-Map_obj41
		dc.w word_EAA6-Map_obj41
		dc.w word_EAB8-Map_obj41
		dc.w word_EADA-Map_obj41
		dc.w word_EAF4-Map_obj41
		dc.w word_EB16-Map_obj41

word_EA4A:
		dc.w 2
		dc.w $F00D,    0,    0,$FFF0
		dc.w	 5,    8,    4,$FFF8
word_EA5C:
		dc.w 1
		dc.w $F80D,    0,    0,$FFF0
word_EA66:
		dc.w 2
		dc.w $E00D,    0,    0,$FFF0
		dc.w $F007,   $C,    6,$FFF8
word_EA78:
		dc.w 2
		dc.w $F003,    0,    0,	   0
		dc.w $F801,    4,    2,$FFF8
word_EA8A:
		dc.w 1
		dc.w $F003,    0,    0,$FFF8
word_EA94:
		dc.w 2
		dc.w $F003,    0,    0,	 $10
		dc.w $F809,    6,    3,$FFF8
word_EAA6:
		dc.w 2
		dc.w	$D,$1000,$1000,$FFF0
		dc.w $F005,$1008,$1004,$FFF8
word_EAB8:
		dc.w 4
		dc.w $F00D,    0,    0,$FFF0
		dc.w	 5,    8,    4,	   0
		dc.w $FB05,   $C,    6,$FFF6
		dc.w	 5,$201C,$200E,$FFF0
word_EADA:
		dc.w 3
		dc.w $F60D,    0,    0,$FFEA
		dc.w  $605,    8,    4,$FFFA
		dc.w	 5,$201C,$200E,$FFF0
word_EAF4:
		dc.w 4
		dc.w $E60D,    0,    0,$FFFB
		dc.w $F605,    8,    4,	  $B
		dc.w $F30B,  $10,    8,$FFF6
		dc.w	 5,$201C,$200E,$FFF0
word_EB16:
		dc.w 4
		dc.w	$D,$1000,$1000,$FFF0
		dc.w $F005,$1008,$1004,	   0
		dc.w $F505,$100C,$1006,$FFF6
		dc.w $F005,$301C,$300E,$FFF0
		even
; -------------------------------------------------------------------------------
; Secondary sprite mappings for springs
; -------------------------------------------------------------------------------
Map_obj41a:
		dc.w word_EB4A-Map_obj41a
		dc.w word_EB5C-Map_obj41a
		dc.w word_EB66-Map_obj41a
		dc.w word_EB78-Map_obj41a
		dc.w word_EB8A-Map_obj41a
		dc.w word_EB94-Map_obj41a
		dc.w word_EBA6-Map_obj41a
		dc.w word_EC38-Map_obj41a
		dc.w word_EC5A-Map_obj41a
		dc.w word_EC74-Map_obj41a
		dc.w word_EC96-Map_obj41a
word_EB4A:
		dc.w 2
		dc.w $F00D,    0,    0,$FFF0
		dc.w	 5,    8,    4,$FFF8
word_EB5C:
		dc.w 1
		dc.w $F80D,    0,    0,$FFF0
word_EB66:
		dc.w 2
		dc.w $E00D,    0,    0,$FFF0
		dc.w $F007,   $C,    6,$FFF8
word_EB78:
		dc.w 2
		dc.w $F003,    0,    0,	   0
		dc.w $F801,    4,    2,$FFF8
word_EB8A:
		dc.w 1
		dc.w $F003,    0,    0,$FFF8
word_EB94:
		dc.w 2
		dc.w $F003,    0,    0,	 $10
		dc.w $F809,    6,    3,$FFF8
word_EBA6:
		dc.w 2
		dc.w	$D,$1000,$1000,$FFF0
		dc.w $F005,$1008,$1004,$FFF8
word_EC38:
		dc.w 4
		dc.w $F00D,    0,    0,$FFF0
		dc.w	 5,    8,    4,	   0
		dc.w $FB05,   $C,    6,$FFF6
		dc.w	 5,  $1C,   $E,$FFF0
word_EC5A:
		dc.w 3
		dc.w $F60D,    0,    0,$FFEA
		dc.w  $605,    8,    4,$FFFA
		dc.w	 5,  $1C,   $E,$FFF0
word_EC74:
		dc.w 4
		dc.w $E60D,    0,    0,$FFFB
		dc.w $F605,    8,    4,	  $B
		dc.w $F30B,  $10,    8,$FFF6
		dc.w	 5,  $1C,   $E,$FFF0
word_EC96:
		dc.w 4
		dc.w	$D,$1000,$1000,$FFF0
		dc.w $F005,$1008,$1004,	   0
		dc.w $F505,$100C,$1006,$FFF6
		dc.w $F005,$101C,$100E,$FFF0
		even
; ----------------------------------------------------------------------------
; Sprite mappings - GHZ springs
; ----------------------------------------------------------------------------
Map_obj41_GHZ:	binclude	"mappings/sprite/obj41_GHZ.bin"
		even
MapSpr_MovingSpring:
Map_MovingSpring:
		dc.w	.frame1-Map_MovingSpring
		dc.w	.frame2-Map_MovingSpring

.frame1:
		dc.w 1
		dc.w $F805, 0, 0, $FFF8
.frame2:
		dc.w 1
		dc.w $F805, 4, 2, $FFF8
		even

		include	"objects/S1/42 Newtron.asm"
Map_obj42:	binclude	"mappings/sprite/obj42.bin"
		even

		include	"objects/S1/44 GHZ Edge Walls.asm"
Map_obj44:	binclude	"mappings/sprite/obj44.bin"
		even

; ===========================================================================

Obj0B:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj0B_Index(pc,d0.w),d1
		jmp	Obj0B_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj0B_Index:	dc.w loc_141C8-Obj0B_Index
		dc.w loc_1421C-Obj0B_Index
		dc.w loc_1422A-Obj0B_Index
; ---------------------------------------------------------------------------

loc_141C8:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj0B,obMap(a0)
		move.w	#make_art_tile(ArtTile_Level,3,1),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$10,obActWid(a0)
		move.w	#$200,obPriority(a0)
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		andi.w	#$F0,d0
		addi.w	#$10,d0
		move.w	d0,d1
		subq.w	#1,d0
		move.w	d0,objoff_30(a0)
		move.w	d0,objoff_32(a0)
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		andi.w	#$F,d0
		addq.w	#1,d0
		lsl.w	#4,d0
		move.b	d0,objoff_36(a0)

loc_1421C:
		move.b	(Vint_runcount+3).w,d0
		add.b	objoff_36(a0),d0
		bne.s	loc_14254
		addq.b	#2,obRoutine(a0)

loc_1422A:
		subq.w	#1,objoff_30(a0)
		bpl.s	loc_14248
		move.w	#$7F,objoff_30(a0)
		tst.b	obAnim(a0)
		beq.s	loc_14242
		move.w	objoff_32(a0),objoff_30(a0)

loc_14242:
		bchg	#0,obAnim(a0)

loc_14248:
		lea	off_1428A(pc),a1
		jsr	(AnimateSprite).l

loc_14254:
		tst.b	obFrame(a0)
		bne.s	loc_1426E
		moveq	#0,d1
		move.b	obActWid(a0),d1
		moveq	#$11,d3
		move.w	obX(a0),d4
		bsr.w	PlatformObject
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------

loc_1426E:
		btst	#3,obStatus(a0)
		beq.s	loc_14286
		lea	(v_player).w,a1
		bclr	#3,obStatus(a1)
		bclr	#3,obStatus(a0)

loc_14286:
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------
off_1428A:	dc.w byte_1428E-off_1428A
		dc.w byte_14296-off_1428A
byte_1428E:	dc.b   7,  0,  1,  2,  3,  4,$FE,  1
byte_14296:	dc.b   7,  4,  3,  2,  1,  0,$FE,  1
		even
Map_Obj0B:	dc.w word_142A8-Map_Obj0B
		dc.w word_142B2-Map_Obj0B
		dc.w word_142BC-Map_Obj0B
		dc.w word_142C6-Map_Obj0B
		dc.w word_142D0-Map_Obj0B
word_142A8:	dc.w 1
		dc.w $F00C,  $11,    8,$FFF0		; 0
word_142B2:	dc.w 1
		dc.w $E80F,  $15,   $A,$FFF0		; 0
word_142BC:	dc.w 1
		dc.w $F40F,  $25,  $12,$FFF0		; 0
word_142C6:	dc.w 1
		dc.w	$F,$1015,$100A,$FFF0		; 0
word_142D0:	dc.w 1
		dc.w $100C,$1011,$1008,$FFF0		; 0
		even
; ---------------------------------------------------------------------------
; Object 0C - flapping door (LZ)
; ---------------------------------------------------------------------------

FlapDoor:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Flap_Index(pc,d0.w),d1
		jmp	Flap_Index(pc,d1.w)
; ===========================================================================
Flap_Index:	dc.w Flap_Main-Flap_Index
		dc.w Flap_OpenClose-Flap_Index

flap_time = objoff_32		; time between opening/closing
flap_wait = objoff_30		; time until change
; ===========================================================================

Flap_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Flap,obMap(a0)
		move.w	#make_art_tile(ArtTile_LZ_Flapping_Door,2,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$28,obActWid(a0)
		moveq	#0,d0
		move.b	obSubtype(a0),d0						; move subtype to d0
		add.w	d0,d0								; multiply by 60 frames (1 second)
		add.w	d0,d0
		move.w	d0,d1
		lsl.w	#4,d0
		sub.w	d1,d0
		move.w	d0,flap_time(a0) ; set flap delay time

Flap_OpenClose:	; Routine 2
		subq.w	#1,flap_wait(a0) ; decrement time delay
		bpl.s	.wait		; if time remains, branch
		move.w	flap_time(a0),flap_wait(a0) ; reset time delay
		bchg	#0,obAnim(a0)	; open/close door
		tst.b	obRender(a0)
		bpl.s	.nosound
		move.w	#sfx_Door,d0
		jsr	(PlaySound_Special).l	; play door sound

.wait:
.nosound:
		lea	Ani_Flap(pc),a1
		bsr.w	AnimateSprite
		clr.b	(f_wtunnelallow).w ; enable wind tunnel
		tst.b	obFrame(a0)	; is the door open?
		bne.w	MarkObjGone	; if yes, branch
;		move.w	(v_player+obX).w,d0	; this commented out bugfix
;		move.w	obX(a0),d1	; is broken: it just mirrors
;		btst	#0,obRender(a0)	; the collision accordingly
;		beq.s	.flipped
;		not.w	d0
;		not.w	d1
;.flipped:
;		cmp.w	d1,d0	; has Sonic passed through the door?
;		bhs.w	MarkObjGone	; if yes, branch
		move.b	#1,(f_wtunnelallow).w ; disable wind tunnel
		moveq	#$13,d1
		moveq	#$20,d2
		move.w	d2,d3
		addq.w	#1,d3
		move.w	obX(a0),d4
		bsr.w	SolidObject	; make the door solid
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------
; Mappings & Animation script - flapping door (LZ)
; ---------------------------------------------------------------------------
Map_Flap:
		binclude	"mappings/sprite/Flapping Door.bin"
		even
; ---------------------------------------------------------------------------
Ani_Flap:	dc.w .opening-Ani_Flap
		dc.w .closing-Ani_Flap
.opening:	dc.b 3,	0, 1, 2, afBack, 1
.closing:	dc.b 3,	2, 1, 0, afBack, 1
		even
		include	"objects/0D Signpost.asm"
Map_obj0D:	include	"mappings/sprite/obj0D.asm"
		even

		include	"objects/Empty slots/0E.asm"
		include	"objects/Empty slots/0F.asm"
; ===========================================================================
		include	"objects/S1/40 Moto Bug.asm"
Map_obj40:	binclude	"mappings/sprite/obj40.bin"
		even

; ===========================================================================
; ---------------------------------------------------------------------------
; Solid object subroutines (includes spikes, blocks, rocks etc)
; These check collision of Sonic/Tails with objects on the screen
;
; input variables:
; d1 = object width
; d2 = object height / 2 (when jumping)
; d3 = object height / 2 (when walking)
; d4 = object x-axis position
;
; address registers:
; a0 = the object to check collision with
; a1 = sonic or tails (set inside these subroutines)
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


SolidObject:
		lea	(v_player).w,a1			; a1=character
		moveq	#3,d6
		movem.l	d1-d4,-(sp)			; store input registers
		bsr.s	sub_F456			; first collision check with Sonic
		movem.l	(sp)+,d1-d4			; restore input registers
		lea	(v_player2).w,a1		; a1=character ; now check collision with Tails
		tst.b	obRender(a1)
		bpl.w	locret_F490			; return if not Tails
		addq.b	#1,d6

sub_F456:
		btst	d6,obStatus(a0)
		beq.w	SolidObject_OnScreenTest
		move.w	d1,d2
		add.w	d2,d2
		btst	#1,obStatus(a1)
		bne.s	loc_F47A
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	loc_F47A
		cmp.w	d2,d0
		blo.s	loc_F488

loc_F47A:
		bclr	#3,obStatus(a1)
		bclr	d6,obStatus(a0)
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------
loc_F488:
		move.w	d4,d2
		bsr.w	MvSonicOnPtfm
		moveq	#0,d4

locret_F490:
		rts
; End of function SolidObject

; ===========================================================================
; alternate function to check for collision even if off-screen, unused
; in this build...
; SolidObject_Always:
		lea	(v_player).w,a1			; a1=character
		moveq	#3,d6
		movem.l	d1-d4,-(sp)
		bsr.s	SolidObject_Always_SingleCharacter
		movem.l	(sp)+,d1-d4
		lea	(v_player2).w,a1		; a1=character
		addq.b	#1,d6
; loc_F4A8:
SolidObject_Always_SingleCharacter:
		btst	d6,obStatus(a0)
		beq.w	SolidObject_cont
		move.w	d1,d2
		add.w	d2,d2
		btst	#1,obStatus(a1)
		bne.s	loc_F4CC
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	loc_F4CC
		cmp.w	d2,d0
		blo.s	loc_F4DA

loc_F4CC:
		bclr	#3,obStatus(a1)
		bclr	d6,obStatus(a0)
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------

loc_F4DA:
		move.w	d4,d2
		bsr.w	MvSonicOnPtfm
		moveq	#0,d4
		rts
; End of function SolidObject_Always

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to collide Sonic/Tails with the top of a sloped
; solid like diagonal springs; unused in this build...
;
; input variables:
; d1 = object width
; d2 = object height / 2 (when jumping)
; d3 = object height / 2 (when walking)
; d4 = object x-axis position
;
; address registers:
; a0 = the object to check collision with
; a1 = sonic or tails (set inside these subroutines)
; a2 = height data for slope
; ---------------------------------------------------------------------------
		lea	(v_player).w,a1			; a1=character
		moveq	#3,d6
		movem.l	d1-d4,-(sp)
		bsr.s	SlopedSolid_SingleCharacter
		movem.l	(sp)+,d1-d4
		lea	(v_player2).w,a1		; a1=character
		addq.b	#1,d6
; loc_F4FA:
SlopedSolid_SingleCharacter:
		btst	d6,obStatus(a0)
		beq.w	SlopedSolid_cont
		move.w	d1,d2
		add.w	d2,d2
		btst	#1,obStatus(a1)
		bne.s	loc_F51E
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	loc_F51E
		cmp.w	d2,d0
		blo.s	loc_F52C

loc_F51E:
		bclr	#3,obStatus(a1)
		bclr	d6,obStatus(a0)
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------

loc_F52C:
		move.w	d4,d2
		bsr.w	sub_F748
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------
; loc_F536:
SlopedSolid_cont:
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.w	SolidObject_TestClearPush
		move.w	d1,d3
		add.w	d3,d3
		cmp.w	d3,d0
		bhi.w	SolidObject_TestClearPush
		move.w	d0,d5
		btst	#0,obRender(a0)
		beq.s	loc_F55C
		not.w	d5
		add.w	d3,d5

loc_F55C:
		lsr.w	#1,d5
		move.b	(a2,d5.w),d3
		sub.b	(a2),d3
		ext.w	d3
		move.w	obY(a0),d5
		sub.w	d3,d5
		move.b	obHeight(a1),d3
		ext.w	d3
		add.w	d3,d2
		move.w	obY(a1),d3
		sub.w	d5,d3
		addq.w	#4,d3
		add.w	d2,d3
		bmi.w	SolidObject_TestClearPush
		move.w	d2,d4
		add.w	d4,d4
		cmp.w	d4,d3
		bhs.w	SolidObject_TestClearPush
		bra.w	SolidObject_ChkBounds
; ===========================================================================
; loc_F590:
SolidObject_OnScreenTest:
		tst.b	obRender(a0)
		bpl.w	SolidObject_TestClearPush
; loc_F598:
SolidObject_cont:
		; We now perform the x portion of a bounding box check.  To do this, we assume a
		; coordinate system where the x origin is at the object's left edge.
		move.w	obX(a1),d0			; load Sonic's x position...
		sub.w	obX(a0),d0			; ... and calculate his x position relative to the object
		add.w	d1,d0				; assume object's left edge is at (0,0).  This is also Sonic's distance to the object's left edge.
		bmi.w	SolidObject_TestClearPush	; branch, if Sonic is outside the object's left edge
		move.w	d1,d3
		add.w	d3,d3				; calculate object's width
		cmp.w	d3,d0
		bhi.w	SolidObject_TestClearPush	; branch, if Sonic is outside the object's right edge
		; We now perform the y portion of a bounding box check.  To do this, we assume a
		; coordinate system where the y origin is at the highest y position relative to the object
		; at which Sonic would still collide with it.  This point is
		;   y_pos(object) - width(object)/2 - y_radius(Sonic) - 4,
		; where object is stored in (a0), Sonic in (a1), and height(object)/2 in d2.  This way
		; of doing it causes the object's hitbox to be vertically off-center by -4 pixels.
		move.b	obHeight(a1),d3			; load Sonic's y radius
		ext.w	d3
		add.w	d3,d2				; calculate maximum distance for a top collision
		move.w	obY(a1),d3			; load Sonic's y position
		sub.w	obY(a0),d3			; ... and calculate his y position relative to the object
		addq.w	#4,d3				; assume a slightly lower position for Sonic
		add.w	d2,d3				; assume the highest position where Sonic would still be colliding with the object to be (0,0)
		bmi.w	SolidObject_TestClearPush	; branch, if Sonic is above this point
		move.w	d2,d4
		add.w	d4,d4				; calculate minimum distance for a bottom collision
		cmp.w	d4,d3
		bhs.w	SolidObject_TestClearPush	; branch, if Sonic is below this point
; loc_F5D2:
SolidObject_ChkBounds:
		tst.b	(f_playerctrl).w
		bmi.w	SolidObject_TestClearPush	; branch, if object collisions are disabled for Sonic
		cmpi.b	#6,obRoutine(a1)		; is Sonic dead?
		bhs.w	loc_F680			; if yes, branch
		tst.w	(Debug_placement_mode).w
		bne.w	loc_F680			; branch, if in Debug Mode

		move.w	d0,d5
		cmp.w	d0,d1
		bhs.s	loc_F5FA			; branch, if Sonic is to the object's left
		add.w	d1,d1
		sub.w	d1,d0
		move.w	d0,d5				; calculate Sonic's distance to the object's right edge...
		neg.w	d5				; ... and calculate the absolute value

loc_F5FA:
		move.w	d3,d1
		cmp.w	d3,d2
		bhs.s	loc_F608
		subq.w	#4,d3
		sub.w	d4,d3
		move.w	d3,d1
		neg.w	d1

loc_F608:
		cmp.w	d1,d5
		bhi.w	loc_F684			; branch, if horizontal distance is greater than vertical distance

		cmpi.w	#4,d1
		bls.s	loc_F65A
		tst.w	d0
		beq.s	loc_F634
		bmi.s	loc_F622
		tst.w	obVelX(a1)
		bmi.s	loc_F634
		bra.s	loc_F628
; ===========================================================================

loc_F622:
		tst.w	obVelX(a1)
		bpl.s	loc_F634

loc_F628:
		clr.w	obInertia(a1)
		clr.w	obVelX(a1)

loc_F634:
		sub.w	d0,obX(a1)
		btst	#1,obStatus(a1)
		bne.s	loc_F65A
		move.l	d6,d4
		addq.b	#2,d4				; Character is pushing, not standing
		bset	d4,obStatus(a0)
		bset	#5,obStatus(a1)
		move.w	d6,d4
		addi.b	#$D,d4
		bset	d4,d6				; This sets bits 0 (Sonic) or 1 (Tails) of high word of d6
		moveq	#1,d4
		rts
; ===========================================================================

loc_F65A:
		bsr.s	sub_F678
		move.w	d6,d4
		addi.b	#$D,d4
		bset	d4,d6				; This sets bits 0 (Sonic) or 1 (Tails) of high word of d6
		moveq	#1,d4
		rts
; ===========================================================================
; loc_F668:
SolidObject_TestClearPush:
		move.l	d6,d4
		addq.b	#2,d4
		btst	d4,obStatus(a0)
		beq.s	loc_F680
		move.w	#AniIDSonAni_Run,obAnim(a1)

sub_F678:
		move.l	d6,d4
		addq.b	#2,d4
		bclr	d4,obStatus(a0)

loc_F680:
		moveq	#0,d4
		rts
; ===========================================================================

loc_F684:
		tst.w	d3
		bmi.s	loc_F690
		cmpi.w	#$10,d3
		blo.s	loc_F6D2
		bra.s	SolidObject_TestClearPush
; ===========================================================================

loc_F690:
		tst.w	obVelY(a1)
		beq.s	loc_F6B2
		bpl.s	loc_F6A6
		tst.w	d3
		bpl.s	loc_F6A6
		sub.w	d3,obY(a1)
		clr.w	obVelY(a1)

loc_F6A6:
		move.w	d6,d4
		addi.b	#$F,d4
		bset	d4,d6				; This sets bits 2 (Sonic) or 3 (Tails) of high word of d6
		moveq	#-2,d4
		rts
; ===========================================================================

loc_F6B2:
		btst	#1,obStatus(a1)
		bne.s	loc_F6A6
		move.l	a0,-(sp)
		movea.l	a1,a0
		jsr	(KillSonic).l
		movea.l	(sp)+,a0			; load obj address
		move.w	d6,d4
		addi.b	#$F,d4
		bset	d4,d6				; This sets bits 2 (Sonic) or 3 (Tails) of high word of d6
		moveq	#-2,d4
		rts
; ===========================================================================

loc_F6D2:
		subq.w	#4,d3
		moveq	#0,d1
		move.b	obActWid(a0),d1
		move.w	d1,d2
		add.w	d2,d2
		add.w	obX(a1),d1
		sub.w	obX(a0),d1
		bmi.s	loc_F70A
		cmp.w	d2,d1
		bhs.s	loc_F70A
		tst.w	obVelY(a1)
		bmi.s	loc_F70A
		sub.w	d3,obY(a1)
		subq.w	#1,obY(a1)
		bsr.w	RideObject_SetRide
		move.w	d6,d4
		addi.b	#$11,d4
		bset	d4,d6				; This sets bits 4 (Sonic) or 5 (Tails) of high word of d6
		moveq	#-1,d4
		rts
; ===========================================================================

loc_F70A:
		moveq	#0,d4
		rts
; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to change Sonic's position with a platform
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; sub_F70E:
MvSonicOnPtfm:
		move.w	obY(a0),d0
		sub.w	d3,d0
	;	bra.s	loc_F71E
; ===========================================================================
		; a couple lines of unused/leftover/dead code from Sonic 1 ; a0=object
	;	move.w	obY(a0),d0
	;	subi.w	#9,d0

loc_F71E:
		tst.b	(f_playerctrl).w
		bmi.s	locret_F746
		cmpi.b	#6,obRoutine(a1)
		bhs.s	locret_F746
		tst.w	(Debug_placement_mode).w
		bne.s	locret_F746
		moveq	#0,d1
		move.b	obHeight(a1),d1
		sub.w	d1,d0
		move.w	d0,obY(a1)
		sub.w	obX(a0),d2
		sub.w	d2,obX(a1)

locret_F746:
		rts
; End of function MvSonicOnPtfm


; =============== S U B R O U T I N E =======================================


sub_F748:
		btst	#3,obStatus(a1)
		beq.s	locret_F788
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		lsr.w	#1,d0
		btst	#0,obRender(a0)
		beq.s	loc_F768
		not.w	d0
		add.w	d1,d0

loc_F768:
		move.b	(a2,d0.w),d1
		ext.w	d1
		move.w	obY(a0),d0
		sub.w	d1,d0
		moveq	#0,d1
		move.b	obHeight(a1),d1
		sub.w	d1,d0
		move.w	d0,obY(a1)
		sub.w	obX(a0),d2
		sub.w	d2,obX(a1)

locret_F788:
		rts
; End of function sub_F748


; =============== S U B R O U T I N E =======================================


PlatformObject:
		lea	(v_player).w,a1
		moveq	#3,d6
		movem.l	d1-d4,-(sp)
		bsr.s	sub_F7A0
		movem.l	(sp)+,d1-d4
		lea	(v_player2).w,a1
		addq.b	#1,d6

sub_F7A0:
		btst	d6,obStatus(a0)
		beq.w	PlatformObject_cont
		move.w	d1,d2
		add.w	d2,d2
		btst	#1,obStatus(a1)
		bne.s	+
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	+
		cmp.w	d2,d0
		blo.s	loc_F7D2
+
		bclr	#3,obStatus(a1)
		bset	#1,obStatus(a1)
		bclr	d6,obStatus(a0)
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------
loc_F7D2:
		move.w	d4,d2
		bsr.w	MvSonicOnPtfm
		moveq	#0,d4
		rts
; End of function sub_F7A0


; =============== S U B R O U T I N E =======================================


SlopedPlatform:
		lea	(v_player).w,a1
		moveq	#3,d6
		movem.l	d1-d4,-(sp)
		bsr.s	sub_F7F2
		movem.l	(sp)+,d1-d4
		lea	(v_player2).w,a1
		addq.b	#1,d6
; End of function SlopedPlatform


; =============== S U B R O U T I N E =======================================


sub_F7F2:
		btst	d6,obStatus(a0)
		beq.w	SlopedPlatform_cont
		move.w	d1,d2
		add.w	d2,d2
		btst	#1,obStatus(a1)
		bne.s	loc_F816
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	loc_F816
		cmp.w	d2,d0
		blo.s	loc_F824

loc_F816:
		bclr	#3,obStatus(a1)
		bclr	d6,obStatus(a0)
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------

loc_F824:
		move.w	d4,d2
		bsr.w	sub_F748
		moveq	#0,d4
		rts
; End of function sub_F7F2


; =============== S U B R O U T I N E =======================================


sub_F82E:
		lea	(v_player).w,a1
		moveq	#3,d6
		movem.l	d1-d4,-(sp)
		bsr.s	sub_F844
		movem.l	(sp)+,d1-d4
		lea	(v_player2).w,a1
		addq.b	#1,d6
; End of function sub_F82E


; =============== S U B R O U T I N E =======================================


sub_F844:
		btst	d6,obStatus(a0)
		beq.w	loc_F9A0
		move.w	d1,d2
		add.w	d2,d2
		btst	#1,obStatus(a1)
		bne.s	loc_F868
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	loc_F868
		cmp.w	d2,d0
		blo.s	loc_F876

loc_F868:
		bclr	#3,obStatus(a1)
		bclr	d6,obStatus(a0)
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------

loc_F876:
		move.w	d4,d2
		bsr.w	MvSonicOnPtfm
		moveq	#0,d4
		rts
; End of function sub_F844


; =============== S U B R O U T I N E =======================================


sub_F880:
		tst.w	obVelY(a1)
		bmi.w	locret_F966
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.w	locret_F966
		cmp.w	d2,d0
		bhs.w	locret_F966
		bra.s	loc_F8BC
; ---------------------------------------------------------------------------

PlatformObject_cont:
		tst.w	obVelY(a1)
		bmi.w	locret_F966
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.w	locret_F966
		add.w	d1,d1
		cmp.w	d1,d0
		bhs.w	locret_F966

loc_F8BC:
		move.w	obY(a0),d0
		sub.w	d3,d0

loc_F8C2:
		move.w	obY(a1),d2
		move.b	obHeight(a1),d1
		ext.w	d1
		add.w	d2,d1
		addq.w	#4,d1
		sub.w	d1,d0
		bhi.w	locret_F966
		cmpi.w	#-$10,d0
		blo.w	locret_F966
		tst.b	(f_playerctrl).w
		bmi.w	locret_F966
		cmpi.b	#6,obRoutine(a1)
		bhs.w	locret_F966
		add.w	d0,d2
		addq.w	#3,d2
		move.w	d2,obY(a1)
; sub_F8F8:
RideObject_SetRide:
		btst	#3,obStatus(a1)
		beq.s	loc_F916
		moveq	#0,d0
		move.b	standonobject(a1),d0
		lsl.w	#object_size_bits,d0
		addi.l	#v_objspace,d0
		movea.l	d0,a3
		bclr	#3,obStatus(a3)

loc_F916:
		move.w	a0,d0
		subi.w	#v_objspace,d0
		lsr.w	#object_size_bits,d0
		andi.w	#$7F,d0
		move.b	d0,standonobject(a1)
		clr.b	obAngle(a1)
		clr.w	obVelY(a1)
		move.w	obVelX(a1),obInertia(a1)
		btst	#1,obStatus(a1)
		beq.s	loc_F95C
		move.l	a0,-(sp)
		movea.l	a1,a0
		move.w	a0,d1
		subi.w	#v_objspace,d1
		bne.s	loc_F954
		jsr	(Sonic_ResetOnFloor).l
		bra.s	loc_F95A
; ===========================================================================

loc_F954:
		jsr	(Tails_ResetTailsOnFloor).l

loc_F95A:
		movea.l	(sp)+,a0

loc_F95C:
		bset	#3,obStatus(a1)
		bset	d6,obStatus(a0)

locret_F966:
		rts
; ===========================================================================
; loc_F968:
SlopedPlatform_cont:
		tst.w	obVelY(a1)
		bmi.w	locret_F966
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	locret_F966
		add.w	d1,d1
		cmp.w	d1,d0
		bhs.s	locret_F966
		btst	#0,obRender(a0)
		beq.s	loc_F98E
		not.w	d0
		add.w	d1,d0

loc_F98E:
		lsr.w	#1,d0
		move.b	(a2,d0.w),d3
		ext.w	d3
		move.w	obY(a0),d0
		sub.w	d3,d0
		bra.w	loc_F8C2
; ---------------------------------------------------------------------------

loc_F9A0:
		tst.w	obVelY(a1)
		bmi.w	locret_F966
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.w	locret_F966
		add.w	d1,d1
		cmp.w	d1,d0
		bhs.w	locret_F966
		move.w	obY(a0),d0
		sub.w	d3,d0
		bra.w	loc_F8C2

; =============== S U B R O U T I N E =======================================


sub_F9C8:
		move.w	d1,d2
		add.w	d2,d2
		lea	(v_player).w,a1
		btst	#1,obStatus(a1)
		bne.s	loc_F9E8
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	loc_F9E8
		cmp.w	d2,d0
		blo.s	locret_F9FA

loc_F9E8:
		bclr	#3,obStatus(a1)
		move.b	#2,obRoutine(a0)
		bclr	#3,obStatus(a0)

locret_F9FA:
		rts
; End of function sub_F9C8

; ===========================================================================
; ---------------------------------------------------------------------------
; Object 01 - Sonic
; ---------------------------------------------------------------------------

Obj01:
		tst.w	(Debug_placement_mode).w	; is debug mode being used?
		beq.s	Obj01_Normal			; if not, branch
		jmp	(DebugMode).l
; ===========================================================================

Obj01_Normal:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj01_Index(pc,d0.w),d1
		jmp	Obj01_Index(pc,d1.w)
; ===========================================================================
Obj01_Index:
		dc.w Obj01_Init-Obj01_Index		; 0
		dc.w Obj01_Control-Obj01_Index		; 2
		dc.w Obj01_Hurt-Obj01_Index		; 4
		dc.w Obj01_Dead-Obj01_Index		; 6
		dc.w Obj01_ResetLevel-Obj01_Index	; 8
; ===========================================================================
; Obj01_Main:
Obj01_Init:
		addq.b	#2,obRoutine(a0)		; => Obj01_Control
		move.b	#$13,obHeight(a0)		; this sets Sonic's collision height (2*pixels)
		move.b	#9,obWidth(a0)
		move.l	#Map_Sonic,obMap(a0)
		move.w	#$100,obPriority(a0)
		move.b	#$18,obActWid(a0)
		move.b	#4,obRender(a0)
		move.w	#$600,(Sonic_top_speed).w	; set Sonic's top speed
		move.w	#$C,(Sonic_acceleration).w	; set Sonic's acceleration
		move.w	#$80,(Sonic_deceleration).w	; set Sonic's deceleration
		tst.b	(v_lastlamp).w
		bne.s	Obj01_Init_Continued
		; only happens when not starting at a checkpoint:
		move.w	#make_art_tile(ArtTile_Sonic,0,0),obGfx(a0)
		move.b	#$C,obTopSolidBit(a0)
		move.b	#$D,obLRBSolidBit(a0)
		move.w	obX(a0),(v_lamp_xpos).w
		move.w	obY(a0),(v_lamp_ypos).w
		move.w	obGfx(a0),(v_lamp_mainchar).w
		move.w	obTopSolidBit(a0),(v_lamp_solid).w

Obj01_Init_Continued:
		clr.b	objoff_2C(a0)			; flips_remaining
		move.b	#4,objoff_2D(a0)		; flip_speed
		clr.b	(Super_Sonic_flag).w
		move.b	#30,(v_air).w			; v_air(a0)
		subi.w	#$20,obX(a0)
		addq.w	#4,obY(a0)
		clr.w	(Sonic_Pos_Record_Index).w

		move.w	#$40-1,d2
-		bsr.w	Sonic_RecordPos
		clr.w	(a1,d0.w)
		dbf	d2,-
		addi.w	#$20,obX(a0)
		subq.w	#4,obY(a0)

; ---------------------------------------------------------------------------
; Normal state for Sonic
; ---------------------------------------------------------------------------

Obj01_Control:
		tst.b	(Debug_mode_flag).w		; is debug cheat enabled?
		beq.s	loc_FAB0			; if not, branch
		btst	#bitB,(v_jpadpress1).w		; is button B pressed?
		beq.s	loc_FAB0			; if not, branch
		move.w	#1,(Debug_placement_mode).w	; change Sonic into ring/item
		clr.b	(f_lockctrl).w			; unlock control
		rts
; -----------------------------------------------------------------------
loc_FAB0:
		tst.b	(f_lockctrl).w			; are controls locked?
		bne.s	loc_FABC			; if yes, branch
		move.w	(v_jpadhold1).w,(v_jpadholdlogical).w	; copy new held buttons, to enable joypad

loc_FABC:
		btst	#0,(f_playerctrl).w		; is Sonic interacting with another object that holds him in place or controls his movement somehow?
		bne.s	Obj01_ControlsLock		; if yes, branch to skip Sonic's control
		moveq	#0,d0
		move.b	obStatus(a0),d0
		andi.w	#6,d0
		move.w	Obj01_Modes(pc,d0.w),d1
		jsr	Obj01_Modes(pc,d1.w)		; run Sonic's movement control code

Obj01_ControlsLock:
		bsr.s	Sonic_Display
		bsr.w	Sonic_RecordPos
		bsr.w	Sonic_Water
		move.b	(Primary_Angle).w,objoff_36(a0)
		move.b	(Secondary_Angle).w,objoff_37(a0)
		tst.b	(f_wtunnelmode).w
		beq.s	loc_FAFE
		tst.b	obAnim(a0)
		bne.s	loc_FAFE
		move.b	obPrevAni(a0),obAnim(a0)

loc_FAFE:
		bsr.w	Sonic_Animate
		tst.b	(f_playerctrl).w
		bmi.w	LoadSonicDynPLC
		jsr	(TouchResponse).l
		bra.w	LoadSonicDynPLC

; ===========================================================================
; secondary states under state Obj01_Control
Obj01_Modes:	dc.w Obj01_MdNormal-Obj01_Modes
		dc.w Obj01_MdAir-Obj01_Modes
		dc.w Obj01_MdRoll-Obj01_Modes
		dc.w Obj01_MdJump-Obj01_Modes
; Used for when invincibility wears off
MusicList_Sonic:dc.b bgm_GHZ
		dc.b bgm_LZ
		dc.b bgm_MZ
		dc.b bgm_SLZ
		dc.b bgm_SYZ
		dc.b bgm_SBZ
		dc.b MusID_MTZ
		even

; ===========================================================================

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Sonic_Display:
		move.w	flashtime(a0),d0
		beq.s	Obj01_Display
		subq.w	#1,flashtime(a0)
		lsr.w	#3,d0
		bhs.s	Obj01_ChkInvin
; loc_FB2E:
Obj01_Display:
		jsr	(DisplaySprite).l
; loc_FB34:
Obj01_ChkInvin:						; Checks if invincibility has expired and (should) disables it if it has
		tst.b	(v_invinc).w
		beq.s	Obj01_ChkShoes
		tst.w	invtime(a0)
;		beq.s	Obj01_ChkShoes
		bra.s	Obj01_ChkShoes			; invincibility timer is currently disabled
		subq.w	#1,invtime(a0)
		bne.s	Obj01_ChkShoes
		tst.b	(f_lockscreen).w
		bne.s	Obj01_RmvInvin
		cmpi.w	#12,(v_air).w
		blo.s	Obj01_RmvInvin
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
;		cmpi.w	#(id_LZ<<8)+3,(Current_ZoneAndAct).w	; Leftover check from Sonic 1 for SBZ3
;		bne.s	loc_FB66
;		moveq	#5,d0

;loc_FB66:
		lea	MusicList_Sonic(pc),a1
		move.b	(a1,d0.w),d0
		jsr	(PlaySound).l
; loc_FB74:
Obj01_RmvInvin:
		clr.b	(v_invinc).w
; loc_FB7A:
Obj01_ChkShoes:						; Checks if Speed Shoes have expired and disables them if they have.
		tst.b	(v_shoes).w
		beq.s	Obj01_ExitChk
		tst.w	shoetime(a0)
		beq.s	Obj01_ExitChk
		subq.w	#1,shoetime(a0)
		bne.s	Obj01_ExitChk
		move.w	#$600,(Sonic_top_speed).w
		move.w	#$C,(Sonic_acceleration).w
		move.w	#$80,(Sonic_deceleration).w
		clr.b	(v_shoes).w
		move.w	#bgm_Slowdown,d0
		jmp	(PlaySound).l
; ---------------------------------------------------------------------------
; locret_FBAE:
Obj01_ExitChk:
		rts
; End of function Sonic_Display


; ---------------------------------------------------------------------------
; Subroutine to record Sonic's previous positions for invincibility stars
; and input/status flags for Tails' AI to follow
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_FBB2: CopySonicMovesForTails:
Sonic_RecordPos:
		move.w	(Sonic_Pos_Record_Index).w,d0
		lea	(Sonic_Pos_Record_Buf).w,a1
		lea	(a1,d0.w),a1
		move.w	obX(a0),(a1)+
		move.w	obY(a0),(a1)+
		addq.b	#4,(Sonic_Pos_Record_Index+1).w
		lea	(Sonic_Stat_Record_Buf).w,a1
		lea	(a1,d0.w),a1
		move.w	(v_jpadhold1).w,(a1)+
		move.b	obStatus(a0),(a1)+
		move.b	obGfx(a0),(a1)+
		rts
; End of function Sonic_RecordPos

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine for Sonic when he's underwater
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_FC06:
Sonic_Water:
		tst.b	(Water_flag).w
		bne.s	Obj01_InWater
.return:	rts
; ---------------------------------------------------------------------------
; loc_FC0E: Obj01_InLevelWithWater:
Obj01_InWater:
		move.w	(v_waterpos1).w,d0
		cmp.w	obY(a0),d0			; is Sonic above water?
		bge.s	Obj01_OutWater			; if yes, branch

		bset	#6,obStatus(a0)			; set underwater flag
		bne.s	Sonic_Water.return		; if already underwater, branch

		bsr.w	ResumeMusic
		move.b	#id_Obj0A,(v_sonicbubbles).w		; load Obj0A (sonic's breathing bubbles) at $FFFFB340
		move.b	#$81,(v_sonicbubbles+obSubtype).w
		move.w	#$300,(Sonic_top_speed).w
		move.w	#6,(Sonic_acceleration).w
		move.w	#$40,(Sonic_deceleration).w
		asr	obVelX(a0)
		asr	obVelY(a0)			; memory oprands can only be shifted one at a time
		asr	obVelY(a0)
		beq.s	Sonic_Water.return
		move.b	#id_Obj08,(v_splash).w		; splash animation
		move.w	#sfx_Splash,d0			; splash sound
		jmp	(PlaySound_Special).l
; ---------------------------------------------------------------------------
; Obj01_NotInWater:
Obj01_OutWater:
		bclr	#6,obStatus(a0)			; unset underwater flag
		beq.s	Sonic_Water.return		; if already unset, branch

		bsr.w	ResumeMusic
		move.w	#$600,(Sonic_top_speed).w
		move.w	#$C,(Sonic_acceleration).w
		move.w	#$80,(Sonic_deceleration).w
		asl	obVelY(a0)
		tst.w	obVelY(a0)
		beq.w	Sonic_Water.return
		move.b	#id_Obj08,(v_splash).w		; splash animation
		cmpi.w	#-$1000,obVelY(a0)
		bgt.s	loc_FC98
		move.w	#-$1000,obVelY(a0)		; limit upward y velocity exiting the water

loc_FC98:
		move.w	#sfx_Splash,d0			; splash sound
		jmp	(PlaySound_Special).l
; End of function Sonic_Water

; ===========================================================================
; ---------------------------------------------------------------------------
; Start of subroutine Obj01_MdNormal
; Called if Sonic is neither airborne nor rolling this frame
; ---------------------------------------------------------------------------

Obj01_MdNormal:
		bsr.w	Sonic_CheckSpindash
		bsr.w	Sonic_Jump
		bsr.w	Sonic_SlopeResist
		bsr.w	Sonic_Move
		bsr.w	Sonic_Roll
		bsr.w	Sonic_LevelBound
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		bsr.w	AnglePos
		bra.w	Sonic_SlopeRepel
; End of subroutine Obj01_MdNormal

; ===========================================================================
; Start of subroutine Obj01_MdAir
; Called if Sonic is airborne, but not in a ball (thus, probably not jumping)
; Obj01_MdJump:
Obj01_MdAir:
		bsr.w	Sonic_JumpHeight
		bsr.w	Sonic_ChgJumpDir
		bsr.w	Sonic_LevelBound
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$38,obVelY(a0)				; increase vertical speed (apply gravity)
		btst	#6,obStatus(a0)			; is Sonic underwater?
		beq.s	loc_FCEA			; if not, branch
		subi.w	#$28,obVelY(a0)			; reduce gravity by $28 ($38-$28=$10)

loc_FCEA:
		bsr.w	Sonic_JumpAngle
		bra.w	Sonic_DoLevelCollision
; End of subroutine Obj01_MdAir

; ===========================================================================
; Start of subroutine Obj01_MdRoll
; Called if Sonic is in a ball, but not airborne (thus, probably rolling)

Obj01_MdRoll:
		bsr.w	Sonic_Jump
		bsr.w	Sonic_RollRepel
		bsr.w	Sonic_RollSpeed
		bsr.w	Sonic_LevelBound
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		bsr.w	AnglePos
		bra.w	Sonic_SlopeRepel
; End of subroutine Obj01_MdRoll

; ===========================================================================
; Start of subroutine Obj01_MdJump
; Called if Sonic is in a ball and airborne (he could be jumping but not necessarily)
; Notes: This is identical to Obj01_MdAir, at least at this outer level.
;        Why they gave it a separate copy of the code, I don't know.
; Obj01_MdJump2:
Obj01_MdJump:
		bsr.w	Sonic_HomingAttack
		bsr.w	Sonic_JumpHeight
		bsr.w	Sonic_ChgJumpDir
		bsr.w	Sonic_LevelBound
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$38,obVelY(a0)				; increase vertical speed (apply gravity)
		btst	#6,obStatus(a0)			; is Sonic underwater?
		beq.s	loc_FD34			; if not, branch
		subi.w	#$28,obVelY(a0)			; reduce gravity by $28 ($38-$28=$10)

loc_FD34:
		bsr.w	Sonic_JumpAngle
		bra.w	Sonic_DoLevelCollision
; End of subroutine Obj01_MdJump


; ---------------------------------------------------------------------------
; Subroutine to make Sonic walk/run
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Sonic_Move:
		move.w	(Sonic_top_speed).w,d6
		move.w	(Sonic_acceleration).w,d5
		move.w	(Sonic_deceleration).w,d4
		tst.b	(f_slidemode).w
		bne.w	Obj01_Traction
		tst.w	objoff_2E(a0)
		bne.w	Obj01_UpdateSpeedOnGround
		btst	#bitL,(v_jpadholdlogical).w	; is left being pressed?
		beq.s	loc_FD66			; if not, branch
		bsr.w	Sonic_MoveLeft

loc_FD66:
		btst	#bitR,(v_jpadholdlogical).w	; is right being pressed?
		beq.s	loc_FD72			; if not, branch
		bsr.w	Sonic_MoveRight

loc_FD72:
		move.b	obAngle(a0),d0
		addi.b	#$20,d0
		andi.b	#$C0,d0				; is Sonic on a slope?
		bne.w	Obj01_UpdateSpeedOnGround	; if yes, branch
		tst.w	obInertia(a0)			; is Sonic moving?
		bne.w	Obj01_UpdateSpeedOnGround	; if yes, branch
		bclr	#5,obStatus(a0)
		cmpi.b	#AniIDSonAni_WallRecoil2,obAnim(a0)
		beq.s	loc_FD9E
		move.b	#AniIDSonAni_Wait,obAnim(a0)	; use "standing" animation

loc_FD9E:
		btst	#3,obStatus(a0)
		beq.s	Sonic_Balance
		moveq	#0,d0
		move.b	standonobject(a0),d0
		lsl.w	#object_size_bits,d0
		lea	(v_player).w,a1			; a1=character
		lea	(a1,d0.w),a1			; a1=object
		tst.b	obStatus(a1)
		bmi.s	Sonic_LookUp
		moveq	#0,d1
		move.b	obActWid(a1),d1
		move.w	d1,d2
		add.w	d2,d2
		subq.w	#4,d2
		add.w	obX(a0),d1
		sub.w	obX(a1),d1
		cmpi.w	#4,d1
		blt.s	loc_FE00
		cmp.w	d2,d1
		bge.s	loc_FDF0
		bra.s	Sonic_LookUp
; ---------------------------------------------------------------------------

Sonic_Balance:
		jsr	(ChkFloorEdge).l
		cmpi.w	#$C,d1
		blt.s	Sonic_LookUp
		cmpi.b	#3,objoff_36(a0)
		bne.s	loc_FDF8

loc_FDF0:
		bclr	#0,obStatus(a0)
		move.b	#AniIDSonAni_Balance,obAnim(a0)
		bra.s	Obj01_UpdateSpeedOnGround
; ---------------------------------------------------------------------------

loc_FDF8:
		cmpi.b	#3,objoff_37(a0)
		bne.s	Sonic_LookUp

loc_FE00:
		bset	#0,obStatus(a0)
		move.b	#AniIDSonAni_Balance,obAnim(a0)
		bra.s	Obj01_UpdateSpeedOnGround
; ---------------------------------------------------------------------------

Sonic_LookUp:
		btst	#bitUp,(v_jpadholdlogical).w	; is up being pressed?
		beq.s	Sonic_Duck			; if not, branch
		move.b	#AniIDSonAni_LookUp,obAnim(a0)	; use "looking up" animation
		bra.s	Obj01_UpdateSpeedOnGround
; ---------------------------------------------------------------------------

Sonic_Duck:
		btst	#bitDn,(v_jpadholdlogical).w	; is down being pressed?
		beq.s	Obj01_UpdateSpeedOnGround	; if not, branch
		move.b	#AniIDSonAni_Duck,obAnim(a0)	; use "ducking" animation

; ---------------------------------------------------------------------------
; updates Sonic's speed on the ground
; ---------------------------------------------------------------------------
; loc_FE2C:
Obj01_UpdateSpeedOnGround:
		move.b	(v_jpadholdlogical).w,d0
		andi.b	#btnL|btnR,d0	; is left/right being pressed?
		bne.s	Obj01_Traction			; if yes, branch
		move.w	obInertia(a0),d0
		beq.s	Obj01_Traction
		bmi.s	Obj01_SettleLeft

; slow down when facing right and not pressing a direction
; Obj01_SettleRight:
		sub.w	d5,d0
		bhs.s	loc_FE46
		clr.w	d0

loc_FE46:
		move.w	d0,obInertia(a0)
		bra.s	Obj01_Traction
; ---------------------------------------------------------------------------
; slow down when facing left and not pressing a direction
; loc_FE4C:
Obj01_SettleLeft:
		add.w	d5,d0
		bhs.s	loc_FE54
		clr.w	d0

loc_FE54:
		move.w	d0,obInertia(a0)

; increase or decrease speed on the ground
; loc_FE58:
Obj01_Traction:
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	obInertia(a0),d1
		asr.l	#8,d1
		move.w	d1,obVelX(a0)
		muls.w	obInertia(a0),d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)

; stops Sonic from running through walls that meet the ground
; loc_FE76:
Obj01_CheckWallsOnGround:
		move.b	obAngle(a0),d0
		addi.b	#$40,d0
		bmi.s	locret_FEF6
		move.b	#$40,d1				; rotate 90 degress clockwise
		tst.w	obInertia(a0)			; check if Sonic's moving
		beq.s	locret_FEF6			; if not, branch
		bmi.s	loc_FE8E			; if negative, branch
		neg.w	d1				; rotate counterclockwise

loc_FE8E:
		move.b	obAngle(a0),d0
		add.b	d1,d0
		move.w	d0,-(sp)
		bsr.w	CalcRoomInFront
		move.w	(sp)+,d0
		tst.w	d1
		bpl.s	locret_FEF6
		asl.w	#8,d1
		addi.b	#$20,d0
		andi.b	#$C0,d0
		beq.s	loc_FEF2
		cmpi.b	#$40,d0
		beq.s	loc_FED8
		cmpi.b	#$80,d0
		beq.s	loc_FED2
		cmpi.w	#$600,obVelX(a0)		; is Sonic at max speed?
		bge.s	Sonic_WallRecoil		; if yes, branch
		add.w	d1,obVelX(a0)
		bset	#5,obStatus(a0)
		clr.w	obInertia(a0)
locret_FEF6:
		rts
; ---------------------------------------------------------------------------

loc_FED2:
		sub.w	d1,obVelY(a0)
		rts
; ---------------------------------------------------------------------------

loc_FED8:
		cmpi.w	#-$600,obVelX(a0)		; is Sonic at max speed?
		ble.s	Sonic_WallRecoil		; if yes, branch
		sub.w	d1,obVelX(a0)
		bset	#5,obStatus(a0)
		clr.w	obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_FEF2:
		add.w	d1,obVelY(a0)
		rts

; ---------------------------------------------------------------------------
; Subroutine to recoil Sonic off a wall if moving a top speed
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Sonic_WallRecoil:
		move.b	#4,obRoutine(a0)
		bsr.w	Sonic_ResetOnFloor
		bset	#1,obStatus(a0)
		move.w	#-$200,d0
		tst.w	obVelX(a0)
		bpl.s	Sonic_WallRecoil_Right
		neg.w	d0

Sonic_WallRecoil_Right:
		move.w	d0,obVelX(a0)
		move.w	#-$400,obVelY(a0)
		clr.w	obInertia(a0)
		move.b	#AniIDSonAni_WallRecoil1,obAnim(a0)
		move.b	#1,ob2ndRout(a0)
		move.w	#sfx_Death,d0
		jmp	(PlaySound_Special).l
; End of function Sonic_Move


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Sonic_MoveLeft:
		move.w	obInertia(a0),d0
		beq.s	+
		bpl.s	Sonic_TurnLeft ; if Sonic is already moving to the right, branch
+
		bset	#0,obStatus(a0)
		bne.s	+
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)	; force walking animation to restart if it's already in-progress
+
		sub.w	d5,d0	; add acceleration to the left
		move.w	d6,d1
		neg.w	d1
		cmp.w	d1,d0	; compare new speed with top speed
		bgt.s	+	; if new speed is less than the maximum, branch
		add.w	d5,d0	; remove this frame's acceleration change
		cmp.w	d1,d0	; compare speed with top speed
		ble.s	+	; if speed was already greater than the maximum, branch
		move.w	d1,d0	; limit speed on ground going left
+
		move.w	d0,obInertia(a0)
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		rts
; ---------------------------------------------------------------------------
; loc_FF70:
Sonic_TurnLeft:
		sub.w	d4,d0
		bhs.s	+
		move.w	#-$80,d0
+
		move.w	d0,obInertia(a0)
		move.b	obAngle(a0),d1
		addi.b	#$20,d1
		andi.b	#$C0,d1
		bne.s	.return
		cmpi.w	#$400,d0
		blt.s	.return
		move.b	#AniIDSonAni_Stop,obAnim(a0)
		bclr	#0,obStatus(a0)
		move.w	#sfx_Skid,d0
		jmp	(PlaySound_Special).l
		; TODO: Uncomment and implement these lines. When that time comes, the jmp will change, too.
	;	cmpi.b	#12,air_left(a0)
	;	blo.s	return_1A744	; if he's drowning, branch to not make dust
	;	move.b	#6,(Sonic_Dust+routine).w
	;	move.b	#$15,(Sonic_Dust+mapping_frame).w
.return:
		rts
; End of function Sonic_MoveLeft


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Sonic_MoveRight:
		move.w	obInertia(a0),d0
		bmi.s	Sonic_TurnRight
		bclr	#0,obStatus(a0)
		beq.s	+
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
+
		add.w	d5,d0	; add acceleration to the right
		cmp.w	d6,d0	; compare new speed with top speed
		blt.s	+	; if new speed is less than the maximum, branch
		sub.w	d5,d0	; remove this frame's acceleration change
		cmp.w	d6,d0	; compare speed with top speed
		bge.s	+	; if speed was already greater than the maximum, branch
		move.w	d6,d0	; limit speed on ground going right
+
		move.w	d0,obInertia(a0)
		move.b	#AniIDSonAni_Walk,obAnim(a0)
locret_1000C:
		rts
; ---------------------------------------------------------------------------
; loc_FFD6:
Sonic_TurnRight:
		add.w	d4,d0
		bhs.s	loc_FFDE
		move.w	#$80,d0

loc_FFDE:
		move.w	d0,obInertia(a0)
		move.b	obAngle(a0),d1
		addi.b	#$20,d1
		andi.b	#$C0,d1
		bne.s	locret_1000C
		cmpi.w	#-$400,d0
		bgt.s	locret_1000C
		move.b	#AniIDSonAni_Stop,obAnim(a0)
		bset	#0,obStatus(a0)
		move.w	#sfx_Skid,d0
		jmp	(PlaySound_Special).l
; End of function Sonic_MoveRight


; =============== S U B R O U T I N E =======================================


Sonic_RollSpeed:
		move.w	(Sonic_top_speed).w,d6
		asl.w	#1,d6
		move.w	(Sonic_acceleration).w,d5
		asr.w	#1,d5
		move.w	(Sonic_deceleration).w,d4
		asr.w	#2,d4
		tst.b	(f_slidemode).w
		bne.w	loc_1008A
		tst.w	objoff_2E(a0)
		bne.s	loc_10046
		btst	#bitL,(v_jpadholdlogical).w
		beq.s	loc_1003A
		bsr.w	Sonic_RollLeft

loc_1003A:
		btst	#bitR,(v_jpadholdlogical).w
		beq.s	loc_10046
		bsr.w	Sonic_RollRight

loc_10046:
		move.w	obInertia(a0),d0
		beq.s	loc_10068
		bmi.s	loc_1005C
		sub.w	d5,d0
		bhs.s	loc_10056
		clr.w	d0

loc_10056:
		move.w	d0,obInertia(a0)
		bra.s	loc_10068
; ---------------------------------------------------------------------------

loc_1005C:
		add.w	d5,d0
		bhs.s	loc_10064
		clr.w	d0

loc_10064:
		move.w	d0,obInertia(a0)

loc_10068:
		tst.w	obInertia(a0)
		bne.s	loc_1008A
		bclr	#2,obStatus(a0)
		move.b	#$13,obHeight(a0)
		move.b	#9,obWidth(a0)
		move.b	#5,obAnim(a0)
		subq.w	#5,obY(a0)

loc_1008A:
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	obInertia(a0),d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)
		muls.w	obInertia(a0),d1
		asr.l	#8,d1
		cmpi.w	#$1000,d1
		ble.s	loc_100AE
		move.w	#$1000,d1

loc_100AE:
		cmpi.w	#-$1000,d1
		bge.s	loc_100B8
		move.w	#-$1000,d1

loc_100B8:
		move.w	d1,obVelX(a0)
		bra.w	Obj01_CheckWallsOnGround
; End of function Sonic_RollSpeed


; =============== S U B R O U T I N E =======================================


Sonic_RollLeft:
		move.w	obInertia(a0),d0
		beq.s	loc_100C8
		bpl.s	loc_100D6

loc_100C8:
		bset	#0,obStatus(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

loc_100D6:
		sub.w	d4,d0
		bhs.s	loc_100DE
		move.w	#-$80,d0

loc_100DE:
		move.w	d0,obInertia(a0)
		rts
; End of function Sonic_RollLeft


; =============== S U B R O U T I N E =======================================


Sonic_RollRight:
		move.w	obInertia(a0),d0
		bmi.s	loc_100F8
		bclr	#0,obStatus(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

loc_100F8:
		add.w	d4,d0
		bhs.s	loc_10100
		move.w	#$80,d0

loc_10100:
		move.w	d0,obInertia(a0)
		rts
; End of function Sonic_RollRight


; =============== S U B R O U T I N E =======================================


Sonic_ChgJumpDir:
		move.w	(Sonic_top_speed).w,d6
		move.w	(Sonic_acceleration).w,d5
		asl.w	#1,d5
		btst	#4,obStatus(a0)
		bne.s	loc_10150
		move.w	obVelX(a0),d0
		btst	#bitL,(v_jpadholdlogical).w
		beq.s	+
		bset	#0,obStatus(a0)
		sub.w	d5,d0	; add acceleration to the left
		move.w	d6,d1
		neg.w	d1
		cmp.w	d1,d0	; compare new speed with top speed
		bgt.s	+	; if new speed is less than the maximum, branch
		add.w	d5,d0	; remove this frame's acceleration change
		cmp.w	d1,d0	; compare speed with top speed
		ble.s	+	; if speed was already greater than the maximum, branch
		move.w	d1,d0	; limit speed on ground going left
+
		btst	#bitR,(v_jpadholdlogical).w
		beq.s	+
		bclr	#0,obStatus(a0)
		add.w	d5,d0	; add acceleration to the right
		cmp.w	d6,d0	; compare new speed with top speed
		blt.s	+	; if new speed is less than the maximum, branch
		sub.w	d5,d0	; remove this frame's acceleration change
		cmp.w	d6,d0	; compare speed with top speed
		bge.s	+	; if speed was already greater than the maximum, branch
		move.w	d6,d0	; limit speed on ground going right
+
		move.w	d0,obVelX(a0)

loc_10150:
		cmpi.w	#$60,(Camera_Y_pos_bias).w
		beq.s	loc_10162
		bhs.s	loc_1015E
		addq.w	#4,(Camera_Y_pos_bias).w

loc_1015E:
		subq.w	#2,(Camera_Y_pos_bias).w

loc_10162:
		cmpi.w	#-$400,obVelY(a0)
		blo.s	locret_10190
		move.w	obVelX(a0),d0
		move.w	d0,d1
		asr.w	#5,d1
		beq.s	locret_10190
		bmi.s	loc_10184
		sub.w	d1,d0
		bhs.s	loc_1017E
		clr.w	d0

loc_1017E:
		move.w	d0,obVelX(a0)
		rts
; ---------------------------------------------------------------------------

loc_10184:
		sub.w	d1,d0
		blo.s	loc_1018C
		clr.w	d0

loc_1018C:
		move.w	d0,obVelX(a0)

locret_10190:
		rts
; End of function Sonic_ChgJumpDir


; =============== S U B R O U T I N E =======================================

; Sonic_LevelBoundaries:
Sonic_LevelBound:
		move.l	obX(a0),d1
		move.w	obVelX(a0),d0
		ext.l	d0
		asl.l	#8,d0
		add.l	d0,d1
		swap	d1
		move.w	(Camera_Min_X_pos).w,d0
		addi.w	#$10,d0
		cmp.w	d1,d0
		bhi.s	loc_101FA
		move.w	(Camera_Max_X_pos).w,d0
		addi.w	#$128,d0
		tst.b	(f_lockscreen).w
		bne.s	loc_101C0
		addi.w	#$40,d0

loc_101C0:
		cmp.w	d1,d0
		bls.s	loc_101FA

loc_101C4:
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		blt.s	loc_101D4
		rts
; ---------------------------------------------------------------------------

loc_101D4:
		cmpi.w	#(id_SBZ<<8)+1,(Current_ZoneAndAct).w
		bne.w	KillCharacter
		cmpi.w	#$2000,(v_player+obX).w
		blo.w	KillCharacter
		clr.b	(v_lastlamp).w
		move.w	#1,(Level_Inactive_flag).w
		move.w	#(id_LZ<<8)+3,(Current_ZoneAndAct).w
		rts
; ---------------------------------------------------------------------------

loc_101FA:
		move.w	d0,obX(a0)
		clr.w	obX+2(a0)
		clr.w	obVelX(a0)
		clr.w	obInertia(a0)
		bra.s	loc_101C4
; End of function Sonic_LevelBound


; =============== S U B R O U T I N E =======================================


Sonic_Roll:
		tst.b	(f_slidemode).w
		bne.s	Obj01_NoRoll
		move.w	obInertia(a0),d0
		bpl.s	loc_10220
		neg.w	d0

loc_10220:
		cmpi.w	#$80,d0
		blo.s	Obj01_NoRoll
		move.b	(v_jpadholdlogical).w,d0
		andi.b	#btnL|btnR,d0
		bne.s	Obj01_NoRoll
		btst	#bitDn,(v_jpadholdlogical).w
		bne.s	loc_1023A

Obj01_NoRoll:
		rts
; ---------------------------------------------------------------------------

loc_1023A:
		btst	#2,obStatus(a0)
		beq.s	Obj01_DoRoll
		rts
; ---------------------------------------------------------------------------

Obj01_DoRoll:
		bset	#2,obStatus(a0)
		move.b	#$E,obHeight(a0)
		move.b	#7,obWidth(a0)
		move.b	#2,obAnim(a0)
		addq.w	#5,obY(a0)
		move.w	#sfx_Roll,d0
		jsr	(PlaySound_Special).l
		tst.w	obInertia(a0)
		bne.s	locret_10276
		move.w	#$200,obInertia(a0)

locret_10276:
		rts
; End of function Sonic_Roll


; =============== S U B R O U T I N E =======================================


Sonic_Jump:
		move.b	(v_jpadpresslogical).w,d0
		andi.b	#btnABC,d0
		beq.w	locret_1031C
		moveq	#0,d0
		move.b	obAngle(a0),d0
		addi.b	#$80,d0
		bsr.w	sub_13102
		cmpi.w	#6,d1
		blt.w	locret_1031C
		move.w	#$680,d2
		btst	#6,obStatus(a0)
		beq.s	loc_102AA
		move.w	#$380,d2

loc_102AA:
		moveq	#0,d0
		move.b	obAngle(a0),d0
		subi.b	#$40,d0
		jsr	(CalcSine).l
		muls.w	d2,d1
		asr.l	#8,d1
		add.w	d1,obVelX(a0)
		muls.w	d2,d0
		asr.l	#8,d0
		add.w	d0,obVelY(a0)
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		addq.l	#4,sp
		move.b	#1,objoff_3C(a0)
		clr.b	objoff_38(a0)
		move.w	#sfx_Jump,d0
		jsr	(PlaySound_Special).l
		move.b	#$13,obHeight(a0)
		move.b	#9,obWidth(a0)
		btst	#2,obStatus(a0)
		bne.s	loc_1031E
		move.b	#$E,obHeight(a0)
		move.b	#7,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		bset	#2,obStatus(a0)
		addq.w	#5,obY(a0)

locret_1031C:
		rts
; ---------------------------------------------------------------------------

loc_1031E:
		bset	#4,obStatus(a0)
		rts
; End of function Sonic_Jump


; =============== S U B R O U T I N E =======================================


Sonic_JumpHeight:
		tst.b	objoff_3C(a0)
		beq.s	loc_10352
		move.w	#-$400,d1
		btst	#6,obStatus(a0)
		beq.s	loc_1033C
		move.w	#-$200,d1

loc_1033C:
		cmp.w	obVelY(a0),d1
		ble.s	locret_10350
		move.b	(v_jpadholdlogical).w,d0
		andi.b	#btnABC,d0
		bne.s	locret_10350
		move.w	d1,obVelY(a0)

locret_10350:
		rts
; ---------------------------------------------------------------------------

loc_10352:
		cmpi.w	#-$FC0,obVelY(a0)
		bge.s	locret_10360
		move.w	#-$FC0,obVelY(a0)

locret_10360:
		rts
; End of function Sonic_JumpHeight

; ---------------------------------------------------------------------------
; Subroutine to launch a homing attack
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

Sonic_HomingAttack:
		moveq	#btnABC,d0		; is any of the buttons ABC...
		and.b	(v_jpadpresslogical).w,d0	; ...pressed?
		beq.s	.homeend		; if not, branch

		move.w	#sfx_Teleport,d0	; play dash sound as a test
		jmp	(PlaySound_Special).l

.homeend:
		rts
; End of function Sonic_HomingAttack

; ---------------------------------------------------------------------------
; Subroutine to check for starting to charge a spindash
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; Sonic_Spindash:
Sonic_CheckSpindash:
		tst.b	spindash_flag(a0)
		bne.s	Sonic_UpdateSpindash
		cmpi.b	#AniIDSonAni_Duck,obAnim(a0)
		bne.s	locret_10394
		move.b	(v_jpadpresslogical).w,d0
		andi.b	#btnABC,d0
		beq.w	locret_10394
		move.b	#AniIDSonAni_Spindash,obAnim(a0)
		move.w	#sfx_Roll,d0
		jsr	(PlaySound_Special).l
		addq.l	#4,sp
		move.b	#1,spindash_flag(a0)

locret_10394:
		rts
; ===========================================================================
; loc_10396:
Sonic_UpdateSpindash:
		move.b	(v_jpadholdlogical).w,d0
		btst	#bitDn,d0
		bne.s	Sonic_ChargingSpindash

		; unleash the charged spindash and start rolling quickly:
		move.b	#$E,obHeight(a0)
		move.b	#7,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		addq.w	#5,obY(a0)			; add the difference between Sonic's rolling and standing heights
		clr.b	spindash_flag(a0)
	if FixBugs
		; To fix a bug in 'ScrollHoriz', we need an extra variable, so this
		; code has been modified to make the delay value only a single byte.
		; This is used by the fixed 'ScrollHoriz'.
		move.b	#$20,(Horiz_scroll_delay_val).w
		; Back up the position array index for later.
		move.b	(Sonic_Pos_Record_Index+1).w,(Horiz_scroll_delay_val+1).w
	else
		move.w	#$2000,(Horiz_scroll_delay_val).w
	endif
		move.w	#$800,obInertia(a0)
		btst	#0,obStatus(a0)
		beq.s	loc_103D4
		neg.w	obInertia(a0)

loc_103D4:
		bset	#2,obStatus(a0)
		rts
; ===========================================================================
; loc_103DC:
Sonic_ChargingSpindash:
		move.b	(v_jpadpresslogical).w,d0
		andi.b	#btnABC,d0
		beq.w	loc_103EA
		nop

loc_103EA:
		addq.l	#4,sp
		rts
; End of function Sonic_CheckSpindash


; =============== S U B R O U T I N E =======================================


Sonic_SlopeResist:
		move.b	obAngle(a0),d0
		addi.b	#$60,d0
		cmpi.b	#$C0,d0
		bhs.s	locret_10422
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	#$20,d0
		asr.l	#8,d0
		tst.w	obInertia(a0)
		beq.s	locret_10422
		bmi.s	loc_1041E
		tst.w	d0
		beq.s	locret_1041C
		add.w	d0,obInertia(a0)

locret_1041C:
		rts
; ---------------------------------------------------------------------------

loc_1041E:
		add.w	d0,obInertia(a0)

locret_10422:
		rts
; End of function Sonic_SlopeResist


; =============== S U B R O U T I N E =======================================


Sonic_RollRepel:
		move.b	obAngle(a0),d0
		addi.b	#$60,d0
		cmpi.b	#$C0,d0
		bhs.s	locret_1045E
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	#$50,d0
		asr.l	#8,d0
		tst.w	obInertia(a0)
		bmi.s	loc_10454
		tst.w	d0
		bpl.s	loc_1044E
		asr.l	#2,d0

loc_1044E:
		add.w	d0,obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_10454:
		tst.w	d0
		bmi.s	loc_1045A
		asr.l	#2,d0

loc_1045A:
		add.w	d0,obInertia(a0)

locret_1045E:
		rts
; End of function Sonic_RollRepel


; =============== S U B R O U T I N E =======================================


Sonic_SlopeRepel:
		nop
		tst.b	objoff_38(a0)
		bne.s	locret_1049A
		tst.w	objoff_2E(a0)
		bne.s	loc_1049C
		move.b	obAngle(a0),d0
		addi.b	#$20,d0
		andi.b	#$C0,d0
		beq.s	locret_1049A
		move.w	obInertia(a0),d0
		bpl.s	loc_10484
		neg.w	d0

loc_10484:
		cmpi.w	#$280,d0
		bhs.s	locret_1049A
		clr.w	obInertia(a0)
		bset	#1,obStatus(a0)
		move.w	#$1E,objoff_2E(a0)

locret_1049A:
		rts
; ---------------------------------------------------------------------------

loc_1049C:
		subq.w	#1,objoff_2E(a0)
		rts
; End of function Sonic_SlopeRepel


; =============== S U B R O U T I N E =======================================


Sonic_JumpAngle:
		move.b	obAngle(a0),d0	; get Sonic's angle
		beq.s	loc_104BC	; if already 0, branch
		bpl.s	loc_104B2	; if higher than 0, branch
		addq.b	#2,d0		; increase angle
		bhs.s	loc_104B0
		moveq	#0,d0

loc_104B0:
		bra.s	loc_104B8
; ---------------------------------------------------------------------------

loc_104B2:
		subq.b	#2,d0
		bhs.s	loc_104B8
		moveq	#0,d0

loc_104B8:
		move.b	d0,obAngle(a0)

loc_104BC:
		move.b	objoff_27(a0),d0
		beq.s	.return
		tst.w	obInertia(a0)
		bmi.s	loc_104E0
		move.b	objoff_2D(a0),d1
		add.b	d1,d0
		bhs.s	+
		subq.b	#1,objoff_2C(a0)
		bhs.s	+
		clr.b	objoff_2C(a0)
		moveq	#0,d0
+
		move.b	d0,objoff_27(a0)
.return:
		rts
; ---------------------------------------------------------------------------

loc_104E0:
		move.b	objoff_2D(a0),d1
		sub.b	d1,d0
		bhs.s	loc_104F6
		subq.b	#1,objoff_2C(a0)
		bhs.s	loc_104F6
		clr.b	objoff_2C(a0)
		moveq	#0,d0

loc_104F6:
		move.b	d0,objoff_27(a0)
		rts
; End of function Sonic_JumpAngle


; =============== S U B R O U T I N E =======================================

; Sonic_Floor:
Sonic_DoLevelCollision:
		move.l	(v_colladdr1).w,(Collision_addr).w
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	+
		move.l	(v_colladdr2).w,(Collision_addr).w
+
		move.b	obLRBSolidBit(a0),d5
		move.w	obVelX(a0),d1
		move.w	obVelY(a0),d2
		jsr	(CalcAngle).l
		subi.b	#$20,d0
		andi.b	#$C0,d0
		cmpi.b	#$40,d0
		beq.w	loc_105E4
		cmpi.b	#$80,d0
		beq.w	loc_10646
		cmpi.b	#$C0,d0
		beq.w	loc_106A2
		bsr.w	Sonic_HitWall
		tst.w	d1
		bpl.s	+
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)
+
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	+
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
+
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	.return
		move.b	obVelY(a0),d2
		addq.b	#8,d2
		neg.b	d2
		cmp.b	d2,d1
		bge.s	+
		cmp.b	d2,d0
		blt.s	.return
+
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Sonic_ResetOnFloor
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		move.b	d3,d0
		addi.b	#$20,d0
		andi.b	#$40,d0
		bne.s	loc_105C0
		move.b	d3,d0
		addi.b	#$10,d0
		andi.b	#$20,d0
		beq.s	loc_105B2
		asr	obVelY(a0)
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_105B2:
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_105C0:
		clr.w	obVelX(a0)
		cmpi.w	#$FC0,obVelY(a0)
		ble.s	loc_105D4
		move.w	#$FC0,obVelY(a0)

loc_105D4:
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_105E4:
		bsr.w	Sonic_HitWall
		tst.w	d1
		bpl.s	loc_105FE
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)
		move.w	obVelY(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_105FE:
		bsr.w	Sonic_DontRunOnWalls
		tst.w	d1
		bpl.s	loc_10618
		sub.w	d1,obY(a0)
		tst.w	obVelY(a0)
		bpl.s	.return
		clr.w	obVelY(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_10618:
		tst.w	obVelY(a0)
		bmi.s	.return
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Sonic_ResetOnFloor
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_10646:
		bsr.w	Sonic_HitWall
		tst.w	d1
		bpl.s	loc_10658
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)

loc_10658:
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	loc_1066A
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)

loc_1066A:
		bsr.w	Sonic_DontRunOnWalls
		tst.w	d1
		bpl.s	.return
		sub.w	d1,obY(a0)
		move.b	d3,d0
		addi.b	#$20,d0
		andi.b	#$40,d0
		bne.s	loc_1068A
		clr.w	obVelY(a0)
.return:
		rts
; ---------------------------------------------------------------------------

loc_1068A:
		move.b	d3,obAngle(a0)
		bsr.w	Sonic_ResetOnFloor
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_106A2:
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	loc_106BC
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
		move.w	obVelY(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_106BC:
		bsr.w	Sonic_DontRunOnWalls
		tst.w	d1
		bpl.s	loc_106D6
		sub.w	d1,obY(a0)
		tst.w	obVelY(a0)
		bpl.s	.return
		clr.w	obVelY(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_106D6:
		tst.w	obVelY(a0)
		bmi.s	.return
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Sonic_ResetOnFloor
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)

.return:
		rts
; End of function Sonic_DoLevelCollision


; =============== S U B R O U T I N E =======================================


Sonic_ResetOnFloor:
		btst	#4,obStatus(a0)
		beq.s	loc_10712
		nop
		nop
		nop

loc_10712:
		bclr	#5,obStatus(a0)
		bclr	#1,obStatus(a0)
		bclr	#4,obStatus(a0)
		btst	#2,obStatus(a0)
		beq.s	loc_10748
		bclr	#2,obStatus(a0)
		move.b	#$13,obHeight(a0)
		move.b	#9,obWidth(a0)
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		subq.w	#5,obY(a0)

loc_10748:
		clr.b	objoff_3C(a0)
		clr.w	(v_itembonus).w
		clr.b	objoff_27(a0)
		rts
; End of function Sonic_ResetOnFloor

; ---------------------------------------------------------------------------

Obj01_Hurt:
		tst.b	ob2ndRout(a0)
		bmi.w	loc_107E8
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$30,obVelY(a0)
		btst	#6,obStatus(a0)
		beq.s	loc_1077E
		subi.w	#$20,obVelY(a0)

loc_1077E:
		bsr.w	Sonic_HurtStop
		bsr.w	Sonic_LevelBound
		bsr.w	Sonic_RecordPos
		bsr.w	Sonic_Water
		bsr.w	Sonic_Animate
		bsr.w	LoadSonicDynPLC
		jmp	(DisplaySprite).l

; =============== S U B R O U T I N E =======================================


Sonic_HurtStop:
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		blo.w	KillCharacter
		bsr.w	Sonic_DoLevelCollision
		btst	#1,obStatus(a0)
		bne.s	locret_107E6
		moveq	#0,d0
		move.w	d0,obVelY(a0)
		move.w	d0,obVelX(a0)
		move.w	d0,obInertia(a0)
		tst.b	ob2ndRout(a0)
		beq.s	loc_107D6
		move.b	#-1,ob2ndRout(a0)
		move.b	#AniIDSonAni_WallRecoil2,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

loc_107D6:
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		subq.b	#2,obRoutine(a0)
		move.w	#120,flashtime(a0)

locret_107E6:
		rts
; End of function Sonic_HurtStop

; ---------------------------------------------------------------------------

loc_107E8:
		cmpi.b	#AniIDSonAni_WallRecoil2,obAnim(a0)
		bne.s	loc_107FA
		move.b	(v_jpadpress1).w,d0
		andi.b	#btnUp|btnDn|btnL|btnR|btnABC,d0
		beq.s	loc_10804

loc_107FA:
		subq.b	#2,obRoutine(a0)
		clr.b	ob2ndRout(a0)

loc_10804:
		bsr.w	Sonic_RecordPos
		bsr.w	Sonic_Animate
		bsr.w	LoadSonicDynPLC
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------
; Obj01_Death:
Obj01_Dead:
		bsr.w	Sonic_GameOver
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$38,obVelY(a0)				; increase vertical speed (apply gravity)
		bsr.w	Sonic_RecordPos
		bsr.w	Sonic_Animate
		bsr.w	LoadSonicDynPLC
		jmp	(DisplaySprite).l

; =============== S U B R O U T I N E =======================================


Sonic_GameOver:
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#$100,d0
		cmp.w	obY(a0),d0
		bhs.w	locret_108B4
		move.w	#-$38,obVelY(a0)
		addq.b	#2,obRoutine(a0)
		clr.b	(f_timecount).w
		addq.b	#1,(f_lifecount).w
		subq.b	#1,(v_lives).w
		bne.s	loc_10888
		clr.w	objoff_3A(a0)
		_move.b	#id_Obj98,(v_gameovertext1).w
		_move.b	#id_Obj98,(v_gameovertext2).w
		move.b	#1,(v_gameovertext2+obFrame).w
		clr.b	(f_timeover).w

loc_10876:
		move.w	#bgm_GameOver,d0
		jsr	(PlaySound).l
		moveq	#plcid_GameOver,d0
		jmp	(LoadPLC).l
; ---------------------------------------------------------------------------

loc_10888:
		move.w	#60,objoff_3A(a0)
		tst.b	(f_timeover).w
		beq.s	locret_108B4
		clr.w	objoff_3A(a0)
		_move.b	#id_Obj98,(v_gameovertext1).w
		_move.b	#id_Obj98,(v_gameovertext2).w
		move.b	#2,(v_gameovertext1+obFrame).w
		move.b	#3,(v_gameovertext2+obFrame).w
		move.w	#bgm_GameOver,d0
		jsr	(PlaySound).l
		moveq	#plcid_GameOver,d0
		jmp	(LoadPLC).l
; ---------------------------------------------------------------------------

locret_108B4:
		rts
; End of function Sonic_GameOver

; ---------------------------------------------------------------------------

Obj01_ResetLevel:
		tst.w	objoff_3A(a0)
		beq.s	locret_108C8
		subq.w	#1,objoff_3A(a0)
		bne.s	locret_108C8
		move.w	#1,(Level_Inactive_flag).w

locret_108C8:
		rts

; =============== S U B R O U T I N E =======================================


Sonic_Animate:
		lea	SonicAniData(pc),a1	; Get animation script
	;	tst.b	(Super_Sonic_flag).w	; Are we Super?
	;	beq.s	+			; Skip if not
	;	lea	AniSuperSonic(pc),a1	; Get Super animation script
;+
		moveq	#0,d0			; Get current animation
		move.b	obAnim(a0),d0
		cmp.b	obPrevAni(a0),d0	; has animation changed?
		beq.s	SAnim_Do		; if not, branch
		move.b	d0,obPrevAni(a0)	; set previous animation
		clr.b	obAniFrame(a0)		; reset animation frame
		clr.b	obTimeFrame(a0)		; reset frame duration
		bclr	#5,obStatus(a0)		; clear pushing flag

SAnim_Do:
		add.w	d0,d0
		adda.w	(a1,d0.w),a1		; jump to appropriate animation	script
		move.b	(a1),d0
		bmi.s	SAnim_Do2		; if animation is walk/run/roll/jump, branch
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		subq.b	#1,obTimeFrame(a0)	; subtract 1 from frame duration
		bpl.s	SAnim_Delay		; if time remains, branch
		move.b	d0,obTimeFrame(a0)	; load frame duration
		; fall through
; -------------------------------------------------------------------------

SAnim_WalkRun:
		moveq	#0,d1
		move.b	obAniFrame(a0),d1	; load current frame number
		move.b	1(a1,d1.w),d0		; read sprite number from script
		beq.s	SAnim_Next		; If it's a frame ID, branch
		bpl.s	SAnim_Next
		cmpi.b	#$FD,d0			; is it a flag from FC to FF?
;		bhs.s	SAnim_End_FF		; MJ: if so, branch to flag routines
		bge.s	SAnim_End_FF		; MJ: if so, branch to flag routines

SAnim_Next:
		move.b	d0,obFrame(a0)		; load sprite number
		addq.b	#1,obAniFrame(a0)	; next frame number

SAnim_Delay:
		rts
; ---------------------------------------------------------------------------
SAnim_End_FF:
		addq.b	#1,d0			; is the end flag = $FF?
		bne.s	SAnim_End_FE		; if not, branch
		clr.b	obAniFrame(a0)		; restart the animation
		move.b	1(a1),d0		; read sprite number
		bra.s	SAnim_Next
; ---------------------------------------------------------------------------
SAnim_End_FE:
		addq.b	#1,d0			; is the end flag = $FE?
		bne.s	SAnim_End_FD		; if not, branch
		move.b	2(a1,d1.w),d0		; read the next byte in the script
		sub.b	d0,obAniFrame(a0)	; jump back d0 bytes in the script
		sub.b	d0,d1
		move.b	1(a1,d1.w),d0		; read sprite number
		bra.s	SAnim_Next
; ---------------------------------------------------------------------------
SAnim_End_FD:
		addq.b	#1,d0			; is the end flag = $FD?
		bne.s	SAnim_End		; if not, branch
		move.b	2(a1,d1.w),obAnim(a0)	; read next byte, run that animation

SAnim_End:
		rts
; ---------------------------------------------------------------------------

SAnim_Do2:
		subq.b	#1,obTimeFrame(a0)
		bpl.s	SAnim_End
		addq.b	#1,d0
		bne.w	loc_10A44
		moveq	#0,d0
		move.b	objoff_27(a0),d0
		bne.w	loc_109EA
		moveq	#0,d1
		move.b	obAngle(a0),d0
		move.b	obStatus(a0),d2
		andi.b	#1,d2
		bne.s	loc_10984
		not.b	d0

loc_10984:
		addi.b	#$10,d0
		bpl.s	loc_1098C
		moveq	#3,d1

loc_1098C:
		andi.b	#$FC,obRender(a0)
		eor.b	d1,d2
		or.b	d2,obRender(a0)
		btst	#5,obStatus(a0)
		bne.w	loc_10A88
		lsr.b	#4,d0
		andi.b	#6,d0
		move.w	obInertia(a0),d2
		bpl.s	loc_109B0
		neg.w	d2

loc_109B0:
		lea	SonicAni_Run(pc),a1
		cmpi.w	#$600,d2
		bhs.s	loc_109C2
		lea	SonicAni_Walk(pc),a1

loc_109C2:
		move.b	d0,d1
		lsr.b	#1,d1
		add.b	d1,d0
		add.b	d0,d0
		add.b	d0,d0
		move.b	d0,d3
		neg.w	d2
		addi.w	#$800,d2
		bpl.s	loc_109D8
		moveq	#0,d2

loc_109D8:
		lsr.w	#8,d2
		lsr.w	#1,d2	; divide by 512
		move.b	d2,obTimeFrame(a0)
		bsr.w	SAnim_WalkRun
		add.b	d3,obFrame(a0)
		rts
; ---------------------------------------------------------------------------

loc_109EA:
		move.b	objoff_27(a0),d0
		moveq	#0,d1
		move.b	obStatus(a0),d2
		andi.b	#1,d2
		bne.s	loc_10A1E
		andi.b	#$FC,obRender(a0)
		moveq	#0,d2
		or.b	d2,obRender(a0)
		addi.b	#$B,d0
		divu.w	#$16,d0
		addi.b	#$9B,d0
		move.b	d0,obFrame(a0)
		clr.b	obTimeFrame(a0)
		rts
; ---------------------------------------------------------------------------

loc_10A1E:
		moveq	#3,d2
		andi.b	#$FC,obRender(a0)
		or.b	d2,obRender(a0)
		neg.b	d0
		addi.b	#$8F,d0
		divu.w	#$16,d0
		addi.b	#$9B,d0
		move.b	d0,obFrame(a0)
		clr.b	obTimeFrame(a0)
		rts
; ---------------------------------------------------------------------------

loc_10A44:
		addq.b	#1,d0
		bne.s	loc_10A88
		move.w	obInertia(a0),d2
		bpl.s	loc_10A50
		neg.w	d2

loc_10A50:
		lea	SonicAni_Roll2(pc),a1
		cmpi.w	#$600,d2
		bhs.s	loc_10A62
		lea	SonicAni_Roll(pc),a1

loc_10A62:
		neg.w	d2
		addi.w	#$400,d2
		bpl.s	loc_10A6C
		moveq	#0,d2

loc_10A6C:
		lsr.w	#8,d2
		move.b	d2,obTimeFrame(a0)
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		bra.w	SAnim_WalkRun
; ---------------------------------------------------------------------------

loc_10A88:
		move.w	obInertia(a0),d2
		bmi.s	loc_10A90
		neg.w	d2

loc_10A90:
		addi.w	#$800,d2
		bpl.s	loc_10A98
		moveq	#0,d2

loc_10A98:
		lsr.w	#6,d2
		move.b	d2,obTimeFrame(a0)
		lea	SonicAni_Push(pc),a1
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		bra.w	SAnim_WalkRun
; End of function Sonic_Animate
; ===========================================================================
; ---------------------------------------------------------------------------
; Animation script - Sonic
; ---------------------------------------------------------------------------
SonicAniData:	dc.w SonicAni_Walk-SonicAniData
		dc.w SonicAni_Run-SonicAniData
		dc.w SonicAni_Roll-SonicAniData
		dc.w SonicAni_Roll2-SonicAniData
		dc.w SonicAni_Push-SonicAniData
		dc.w SonicAni_Wait-SonicAniData
		dc.w SonicAni_Balance-SonicAniData
		dc.w SonicAni_LookUp-SonicAniData
		dc.w SonicAni_Duck-SonicAniData
		dc.w SonicAni_Spindash-SonicAniData
		dc.w SonicAni_WallRecoil1-SonicAniData
		dc.w SonicAni_WallRecoil2-SonicAniData
		dc.w SonicAni_0C-SonicAniData
		dc.w SonicAni_Stop-SonicAniData
		dc.w SonicAni_Float1-SonicAniData
		dc.w SonicAni_Float2-SonicAniData
		dc.w SonicAni_Spring-SonicAniData
		dc.w SonicAni_S1LZHang-SonicAniData
		dc.w SonicAni_Unused12-SonicAniData
		dc.w SonicAni_Unused13-SonicAniData
		dc.w SonicAni_Unused14-SonicAniData
		dc.w SonicAni_Bubble-SonicAniData
		dc.w SonicAni_DeathBW-SonicAniData
		dc.w SonicAni_Drown-SonicAniData
		dc.w SonicAni_Death-SonicAniData
		dc.w SonicAni_Unused19-SonicAniData
		dc.w SonicAni_Hurt-SonicAniData
		dc.w SonicAni_S1LZSlide-SonicAniData
		dc.w SonicAni_Blank-SonicAniData
		dc.w SonicAni_Float3-SonicAniData
		dc.w SonicAni_1E-SonicAniData
SonicAni_Walk:		dc.b $FF,$10,$11,$12,$13,$14,$15,$16,$17, $C, $D, $E, $F,$FF
SonicAni_Run:		dc.b $FF,$3C,$3D,$3E,$3F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
SonicAni_Roll:		dc.b $FE,$6C,$70,$6D,$70,$6E,$70,$6F,$70,$FF
SonicAni_Roll2:		dc.b $FE,$6C,$70,$6D,$70,$6E,$70,$6F,$70,$FF
SonicAni_Push:		dc.b $FD,$77,$78,$79,$7A,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
SonicAni_Wait:		dc.b   7,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1
			dc.b   1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  2
			dc.b   3,  3,  3,  4,  4,  5,  5,$FE,  4
SonicAni_Balance:	dc.b	7,$89,$8A,$FF
SonicAni_LookUp:	dc.b   5,  6,  7,$FE,  1
SonicAni_Duck:		dc.b   5,$7F,$80,$FE,  1
SonicAni_Spindash:	dc.b	 0,$71,$72,$71,$73,$71,$74,$71,$75,$71,$76,$71,$FF
SonicAni_WallRecoil1:	dc.b $3F,$82,$FF
SonicAni_WallRecoil2:	dc.b   7, 8, 8, 9,$FD,	5
SonicAni_0C:		dc.b   7,  9,$FD,  5
SonicAni_Stop:		dc.b   3,$81,$82,$83,$84,$85,$86,$87,$88,$FE,  2
SonicAni_Float1:	dc.b   7,$94,$96,$FF
SonicAni_Float2:	dc.b   7,$91,$92,$93,$94,$95,$FF
SonicAni_Spring:	dc.b $2F,$7E,$FD,  0
SonicAni_S1LZHang:	dc.b	 5,$8F,$90,$FF
SonicAni_Unused12:	dc.b	$F,$43,$43,$43,$FE,  1
SonicAni_Unused13:	dc.b	$F,$43,$44,$FE,	 1
SonicAni_Unused14:	dc.b $3F,$49,$FF
SonicAni_Bubble:	dc.b  $B,$97,$97,$12,$13,$FD,  0
SonicAni_DeathBW:	dc.b $20,$9A,$FF
SonicAni_Drown:		dc.b $20,$99,$FF
SonicAni_Death:		dc.b $20,$98,$FF
SonicAni_Unused19:	dc.b	 3,$4E,$4F,$50,$51,$52,	 0,$FE,	 1
SonicAni_Hurt:		dc.b $40,$8D,$FF
SonicAni_S1LZSlide:	dc.b	  9,$8D,$8E,$FF
SonicAni_Blank:		dc.b $77,  0,$FD,  0
SonicAni_Float3:	dc.b   3,$91,$92,$93,$94,$95,$FF
SonicAni_1E:		dc.b   3,$3C,$FD,  0
		even
; ---------------------------------------------------------------------------
; Sonic pattern loading subroutine
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


LoadSonicDynPLC:
		moveq	#0,d0
		move.b	obFrame(a0),d0
		cmp.b	(Sonic_LastLoadedDPLC).w,d0
		beq.s	LoadSonicDynPLC.return
		move.b	d0,(Sonic_LastLoadedDPLC).w
		lea	(SonicDynPLC).l,a2
		add.w	d0,d0
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,d5
		subq.w	#1,d5
		bmi.s	LoadSonicDynPLC.return
		move.w	#ArtTile_Sonic*tile_size,d4

.SPLC_ReadEntry:
		moveq	#0,d1
		move.w	(a2)+,d1
		move.w	d1,d3
		lsr.w	#8,d3
		andi.w	#$F0,d3
		addi.w	#$10,d3
		andi.w	#$FFF,d1
		lsl.l	#5,d1
		addi.l	#Art_Sonic,d1
		move.w	d4,d2
		add.w	d3,d4
		add.w	d3,d4
		jsr	(QueueDMATransfer).l
		dbf	d5,.SPLC_ReadEntry

.return:
		rts
; End of function LoadSonicDynPLC

; ===========================================================================
KillCharacter:
		jmp	(KillSonic).l
; ===========================================================================
;----------------------------------------------------------------------------
; Object 02 - Tails
;----------------------------------------------------------------------------

Obj02:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj02_Index(pc,d0.w),d1
		jmp	Obj02_Index(pc,d1.w)
; ===========================================================================
Obj02_Index:	dc.w Obj02_Init-Obj02_Index		; 0
		dc.w Obj02_Control-Obj02_Index		; 2
		dc.w Obj02_Hurt-Obj02_Index		; 4
		dc.w Obj02_Dead-Obj02_Index		; 6
		dc.w Obj02_ResetLevel-Obj02_Index	; 8
; ===========================================================================
; Obj02_Main:
Obj02_Init:
		addq.b	#2,obRoutine(a0)
		move.b	#$F,obHeight(a0)
		move.b	#9,obWidth(a0)
		move.l	#Map_Tails,obMap(a0)
		move.w	#make_art_tile(ArtTile_Tails,0,0),obGfx(a0)
		move.w	#$100,obPriority(a0)
		move.b	#$18,obActWid(a0)
		move.b	#$84,obRender(a0)
		move.w	#$600,(Sonic_top_speed).w
		move.w	#$C,(Sonic_acceleration).w
		move.w	#$80,(Sonic_deceleration).w
		move.b	#$C,obTopSolidBit(a0)
		move.b	#$D,obLRBSolidBit(a0)
		clr.b	objoff_2C(a0)
		move.b	#4,objoff_2D(a0)
		move.b	#id_Obj05,(v_player2tails).w		; load Tails' tails at $B1C0

; ---------------------------------------------------------------------------
; Normal state for Tails
; ---------------------------------------------------------------------------
Obj02_Control:
		bsr.w	Tails_Control
		btst	#0,(f_playerctrl).w		; is Tails interacting with another object that holds him in place or controls his movement somehow?
		bne.s	Obj02_ControlsLock		; if yes, branch to skip Tails' control
		moveq	#0,d0
		move.b	obStatus(a0),d0
		andi.w	#6,d0
		move.w	Obj02_Modes(pc,d0.w),d1
		jsr	Obj02_Modes(pc,d1.w)		; run Tails' movement code

Obj02_ControlsLock:
		bsr.s	Tails_Display
		bsr.w	RecordTailsMoves
		move.b	(Primary_Angle).w,objoff_36(a0)
		move.b	(Secondary_Angle).w,objoff_37(a0)
		bsr.w	Tails_Animate
		tst.b	(f_playerctrl).w
		bmi.s	loc_10CFC
		jsr	(TouchResponse).l

loc_10CFC:
		bra.w	LoadTailsDynPLC
; ===========================================================================
Obj02_Modes:	dc.w Obj02_MdNormal-Obj02_Modes
		dc.w Obj02_MdJump-Obj02_Modes
		dc.w Obj02_MdRoll-Obj02_Modes
		dc.w Obj02_MdJump2-Obj02_Modes
; ===========================================================================
; same as Sonic's...
MusicList_Tails:dc.b bgm_GHZ
		dc.b bgm_LZ
		dc.b bgm_MZ
		dc.b bgm_SLZ
		dc.b bgm_SYZ
		dc.b bgm_SBZ
		dc.b MusID_MTZ
		even

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Tails_Display:
		move.w	flashtime(a0),d0
		beq.s	Obj02_Display
		subq.w	#1,flashtime(a0)
		lsr.w	#3,d0
		bhs.s	Obj02_ChkInvinc
; loc_10D1E:
Obj02_Display:
		jsr	(DisplaySprite).l
; loc_10D24:
Obj02_ChkInvinc:
		; checks if invincibility has expired and disables it if it has,
		; and unlike Sonic's version, functions normally...
		tst.b	(v_invinc).w
		beq.s	Obj02_ChkShoes
		tst.w	invtime(a0)
		beq.s	Obj02_ChkShoes
		subq.w	#1,invtime(a0)
		bne.s	Obj02_ChkShoes
		tst.b	(f_lockscreen).w
		bne.s	Obj02_RmvInvin
		cmpi.w	#12,(v_air).w
		blo.s	Obj02_RmvInvin
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
;		cmpi.w	#(id_LZ<<8)+3,(Current_ZoneAndAct).w
;		bne.s	loc_10D54
;		moveq	#5,d0

;loc_10D54:
		lea	MusicList_Tails(pc),a1
		move.b	(a1,d0.w),d0
		jsr	(PlaySound).l
; loc_10D62:
Obj02_RmvInvin:
		clr.b	(v_invinc).w
; loc_10D68:
Obj02_ChkShoes:
		; checks if Speed Shoes have expired and disables them if they have
		tst.b	(v_shoes).w
		beq.s	Obj02_ExitChk
		tst.w	shoetime(a0)
		beq.s	Obj02_ExitChk
		subq.w	#1,shoetime(a0)
		bne.s	Obj02_ExitChk
		move.w	#$600,(Sonic_top_speed).w
		move.w	#$C,(Sonic_acceleration).w
		move.w	#$80,(Sonic_deceleration).w
; Obj02_RmvSpeed:
		clr.b	(v_shoes).w
		move.w	#bgm_Slowdown,d0		; slow down tempo
		jmp	(PlaySound).l
; ===========================================================================
; locret_10D9C:
Obj02_ExitChk:
		rts
; End of function Tails_Display


; =============== S U B R O U T I N E =======================================


Tails_Control:
		move.b	(v_jpadhold2).w,d0
		andi.b	#btnUp+btnDn+btnL+btnR+btnABC,d0
		beq.s	TailsC_NoKeysPressed
		clr.w	(word_F700).w
		move.w	#$12C,(Tails_control_counter).w
		rts
; ---------------------------------------------------------------------------

TailsC_NoKeysPressed:
		tst.w	(Tails_control_counter).w
		beq.s	TailsC_DoControl
		subq.w	#1,(Tails_control_counter).w
		rts
; ---------------------------------------------------------------------------

TailsC_DoControl:
		move.w	(Tails_CPU_routine).w,d0
		move.w	TailsC_Index(pc,d0.w),d0
		jmp	TailsC_Index(pc,d0.w)
; End of function Tails_Control

; ---------------------------------------------------------------------------
TailsC_Index:	dc.w TailsC_00-TailsC_Index
		dc.w TailsC_02-TailsC_Index
		dc.w TailsC_04-TailsC_Index
		dc.w TailsC_CopySonicMoves-TailsC_Index
; ---------------------------------------------------------------------------

TailsC_00:
		move.w	#6,(Tails_CPU_routine).w
		rts
; ---------------------------------------------------------------------------

TailsC_02:
		move.w	#6,(Tails_CPU_routine).w
		rts
; ---------------------------------------------------------------------------
		move.w	#$40,(word_F706).w
		move.w	#4,(Tails_CPU_routine).w

TailsC_04:
		move.w	#6,(Tails_CPU_routine).w
		rts
; ---------------------------------------------------------------------------

TailsC_CopySonicMoves:
		move.w	(v_player+obX).w,d0
		sub.w	obX(a0),d0
		bpl.s	loc_10E38
		neg.w	d0

loc_10E38:
		cmpi.w	#$C0,d0
		blo.s	loc_10E40
		nop

loc_10E40:
		lea	(Sonic_Pos_Record_Buf).w,a1
		move.w	#$10,d1
		lsl.b	#2,d1
		addq.b	#4,d1
		move.w	(Sonic_Pos_Record_Index).w,d0
		sub.b	d1,d0
		lea	(Sonic_Stat_Record_Buf).w,a1
		move.w	(a1,d0.w),(v_jpadhold2).w
		rts

; =============== S U B R O U T I N E =======================================


RecordTailsMoves:
		move.w	(Tails_Pos_Record_Index).w,d0
		lea	(Tails_Pos_Record_Buf).w,a1
		lea	(a1,d0.w),a1
		move.w	obX(a0),(a1)+
		move.w	obY(a0),(a1)+
		addq.b	#4,(Tails_Pos_Record_Index+1).w
		rts
; End of function RecordTailsMoves

; ---------------------------------------------------------------------------

Obj02_MdNormal:
		bsr.w	Tails_Spindash
		bsr.w	Tails_Jump
		bsr.w	Tails_SlopeResist
		bsr.w	Tails_Move
		bsr.w	Tails_Roll
		bsr.w	Tails_LevelBoundaries
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		bsr.w	AnglePos
		bra.w	Tails_SlopeRepel
; ---------------------------------------------------------------------------

Obj02_MdJump:
		bsr.w	Tails_JumpHeight
		bsr.w	Tails_ChgJumpDir
		bsr.w	Tails_LevelBoundaries
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$38,obVelY(a0)				; increase vertical speed (apply gravity)
		btst	#6,obStatus(a0)
		beq.s	loc_10EC0
		subi.w	#$28,obVelY(a0)

loc_10EC0:
		bsr.w	Tails_JumpAngle
		bra.w	Tails_Floor
; ---------------------------------------------------------------------------

Obj02_MdRoll:
		bsr.w	Tails_Jump
		bsr.w	Tails_RollRepel
		bsr.w	Tails_RollSpeed
		bsr.w	Tails_LevelBoundaries
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		bsr.w	AnglePos
		bra.w	Tails_SlopeRepel
; ---------------------------------------------------------------------------

Obj02_MdJump2:
		bsr.w	Tails_JumpHeight
		bsr.w	Tails_ChgJumpDir
		bsr.w	Tails_LevelBoundaries
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$38,obVelY(a0)				; increase vertical speed (apply gravity)
		btst	#6,obStatus(a0)
		beq.s	loc_10F0A
		subi.w	#$28,obVelY(a0)

loc_10F0A:
		bsr.w	Tails_JumpAngle
		bra.w	Tails_Floor

; =============== S U B R O U T I N E =======================================


Tails_Move:
		move.w	(Sonic_top_speed).w,d6
		move.w	(Sonic_acceleration).w,d5
		move.w	(Sonic_deceleration).w,d4
		tst.b	(f_slidemode).w
		bne.w	loc_11026
		tst.w	objoff_2E(a0)
		bne.w	loc_10FFA
		btst	#bitL,(v_jpadhold2).w
		beq.s	loc_10F3C
		bsr.w	Tails_MoveLeft

loc_10F3C:
		btst	#bitR,(v_jpadhold2).w
		beq.s	loc_10F48
		bsr.w	Tails_MoveRight

loc_10F48:
		move.b	obAngle(a0),d0
		addi.b	#$20,d0
		andi.b	#$C0,d0
		bne.w	loc_10FFA
		tst.w	obInertia(a0)
		bne.w	loc_10FFA
		bclr	#5,obStatus(a0)
		move.b	#AniIDSonAni_Wait,obAnim(a0)
		btst	#3,obStatus(a0)
		beq.s	Tails_Balance
		moveq	#0,d0
		move.b	standonobject(a0),d0
		lsl.w	#object_size_bits,d0
		lea	(v_player).w,a1
		lea	(a1,d0.w),a1
		tst.b	obStatus(a1)
		bmi.s	Tails_LookUp
		moveq	#0,d1
		move.b	obActWid(a1),d1
		move.w	d1,d2
		add.w	d2,d2
		subq.w	#4,d2
		add.w	obX(a0),d1
		sub.w	obX(a1),d1
		cmpi.w	#4,d1
		blt.s	loc_10FCE
		cmp.w	d2,d1
		bge.s	loc_10FBE
		bra.s	Tails_LookUp
; ---------------------------------------------------------------------------

Tails_Balance:
		jsr	(ObjHitFloor).l
		cmpi.w	#$C,d1
		blt.s	Tails_LookUp
		cmpi.b	#3,objoff_36(a0)
		bne.s	loc_10FC6

loc_10FBE:
		bclr	#0,obStatus(a0)
		bra.s	loc_10FD4
; ---------------------------------------------------------------------------

loc_10FC6:
		cmpi.b	#3,objoff_37(a0)
		bne.s	Tails_LookUp

loc_10FCE:
		bset	#0,obStatus(a0)

loc_10FD4:
		move.b	#AniIDSonAni_Balance,obAnim(a0)
		bra.s	loc_10FFA
; ---------------------------------------------------------------------------

Tails_LookUp:
		btst	#bitUp,(v_jpadhold2).w
		beq.s	Tails_Duck
		move.b	#AniIDSonAni_LookUp,obAnim(a0)
		bra.s	loc_10FFA
; ---------------------------------------------------------------------------

Tails_Duck:
		btst	#bitDn,(v_jpadhold2).w
		beq.s	loc_10FFA
		move.b	#AniIDSonAni_Duck,obAnim(a0)

loc_10FFA:
		move.b	(v_jpadhold2).w,d0
		andi.b	#btnL+btnR,d0
		bne.s	loc_11026
		move.w	obInertia(a0),d0
		beq.s	loc_11026
		bmi.s	loc_1101A
		sub.w	d5,d0
		bhs.s	loc_11014
		clr.w	d0

loc_11014:
		move.w	d0,obInertia(a0)
		bra.s	loc_11026
; ---------------------------------------------------------------------------

loc_1101A:
		add.w	d5,d0
		bhs.s	loc_11022
		clr.w	d0

loc_11022:
		move.w	d0,obInertia(a0)

loc_11026:
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	obInertia(a0),d1
		asr.l	#8,d1
		move.w	d1,obVelX(a0)
		muls.w	obInertia(a0),d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)

loc_11044:
		move.b	obAngle(a0),d0
		addi.b	#$40,d0
		bmi.s	locret_110B4
		move.b	#$40,d1
		tst.w	obInertia(a0)
		beq.s	locret_110B4
		bmi.s	loc_1105C
		neg.w	d1

loc_1105C:
		move.b	obAngle(a0),d0
		add.b	d1,d0
		move.w	d0,-(sp)
		bsr.w	CalcRoomInFront
		move.w	(sp)+,d0
		tst.w	d1
		bpl.s	locret_110B4
		asl.w	#8,d1
		addi.b	#$20,d0
		andi.b	#$C0,d0
		beq.s	loc_110B0
		cmpi.b	#$40,d0
		beq.s	loc_1109E
		cmpi.b	#$80,d0
		beq.s	loc_11098
		add.w	d1,obVelX(a0)
		bset	#5,obStatus(a0)
		clr.w	obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_11098:
		sub.w	d1,obVelY(a0)
		rts
; ---------------------------------------------------------------------------

loc_1109E:
		sub.w	d1,obVelX(a0)
		bset	#5,obStatus(a0)
		clr.w	obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_110B0:
		add.w	d1,obVelY(a0)

locret_110B4:
		rts
; End of function Tails_Move


; =============== S U B R O U T I N E =======================================


Tails_MoveLeft:
		move.w	obInertia(a0),d0
		beq.s	+
		bpl.s	loc_110EA
+
		bset	#0,obStatus(a0)
		bne.s	+
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
+
		sub.w	d5,d0	; add acceleration to the left
		move.w	d6,d1
		neg.w	d1
		cmp.w	d1,d0	; compare new speed with top speed
		bgt.s	+	; if new speed is less than the maximum, branch
		add.w	d5,d0	; remove this frame's acceleration change
		cmp.w	d1,d0	; compare speed with top speed
		ble.s	+	; if speed was already greater than the maximum, branch
		move.w	d1,d0	; limit speed on ground going left
+
		move.w	d0,obInertia(a0)
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

loc_110EA:
		sub.w	d4,d0
		bhs.s	+
		move.w	#-$80,d0
+
		move.w	d0,obInertia(a0)
		move.b	obAngle(a0),d1
		addi.b	#$20,d1
		andi.b	#$C0,d1
		bne.s	.return
		cmpi.w	#$400,d0
		blt.s	.return
		move.b	#AniIDSonAni_Stop,obAnim(a0)
		bclr	#0,obStatus(a0)
		move.w	#sfx_Skid,d0
		jmp	(PlaySound_Special).l

.return:
		rts
; End of function Tails_MoveLeft


; =============== S U B R O U T I N E =======================================


Tails_MoveRight:
		move.w	obInertia(a0),d0
		bmi.s	loc_11150
		bclr	#0,obStatus(a0)
		beq.s	+
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
+
		add.w	d5,d0	; add acceleration to the right
		cmp.w	d6,d0	; compare new speed with top speed
		blt.s	+	; if new speed is less than the maximum, branch
		sub.w	d5,d0	; remove this frame's acceleration change
		cmp.w	d6,d0	; compare speed with top speed
		bge.s	+	; if speed was already greater than the maximum, branch
		move.w	d6,d0	; limit speed on ground going right
+
		move.w	d0,obInertia(a0)
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

loc_11150:
		add.w	d4,d0
		bhs.s	+
		move.w	#$80,d0
+
		move.w	d0,obInertia(a0)
		move.b	obAngle(a0),d1
		addi.b	#$20,d1
		andi.b	#$C0,d1
		bne.s	.return
		cmpi.w	#-$400,d0
		bgt.s	.return
		move.b	#AniIDSonAni_Stop,obAnim(a0)
		bset	#0,obStatus(a0)
		move.w	#sfx_Skid,d0
		jmp	(PlaySound_Special).l

.return:
		rts
; End of function Tails_MoveRight


; =============== S U B R O U T I N E =======================================


Tails_RollSpeed:
		move.w	(Sonic_top_speed).w,d6
		asl.w	#1,d6
		move.w	(Sonic_acceleration).w,d5
		asr.w	#1,d5
		move.w	(Sonic_deceleration).w,d4
		asr.w	#2,d4
		tst.b	(f_slidemode).w
		bne.w	loc_11204
		tst.w	objoff_2E(a0)
		bne.s	loc_111C0
		btst	#bitL,(v_jpadhold2).w
		beq.s	loc_111B4
		bsr.w	Tails_RollLeft

loc_111B4:
		btst	#bitR,(v_jpadhold2).w
		beq.s	loc_111C0
		bsr.w	Tails_RollRight

loc_111C0:
		move.w	obInertia(a0),d0
		beq.s	loc_111E2
		bmi.s	loc_111D6
		sub.w	d5,d0
		bhs.s	loc_111D0
		clr.w	d0

loc_111D0:
		move.w	d0,obInertia(a0)
		bra.s	loc_111E2
; ---------------------------------------------------------------------------

loc_111D6:
		add.w	d5,d0
		bhs.s	loc_111DE
		clr.w	d0

loc_111DE:
		move.w	d0,obInertia(a0)

loc_111E2:
		tst.w	obInertia(a0)
		bne.s	loc_11204
		bclr	#2,obStatus(a0)
		move.b	#$F,obHeight(a0)
		move.b	#9,obWidth(a0)
		move.b	#AniIDSonAni_Wait,obAnim(a0)
		subq.w	#5,obY(a0)

loc_11204:
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	obInertia(a0),d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)
		muls.w	obInertia(a0),d1
		asr.l	#8,d1
		cmpi.w	#$1000,d1
		ble.s	loc_11228
		move.w	#$1000,d1

loc_11228:
		cmpi.w	#-$1000,d1
		bge.s	loc_11232
		move.w	#-$1000,d1

loc_11232:
		move.w	d1,obVelX(a0)
		bra.w	loc_11044
; End of function Tails_RollSpeed


; =============== S U B R O U T I N E =======================================


Tails_RollLeft:
		move.w	obInertia(a0),d0
		beq.s	loc_11242
		bpl.s	loc_11250

loc_11242:
		bset	#0,obStatus(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

loc_11250:
		sub.w	d4,d0
		bhs.s	loc_11258
		move.w	#-$80,d0

loc_11258:
		move.w	d0,obInertia(a0)
		rts
; End of function Tails_RollLeft


; =============== S U B R O U T I N E =======================================


Tails_RollRight:
		move.w	obInertia(a0),d0
		bmi.s	loc_11272
		bclr	#0,obStatus(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

loc_11272:
		add.w	d4,d0
		bhs.s	loc_1127A
		move.w	#$80,d0

loc_1127A:
		move.w	d0,obInertia(a0)
		rts
; End of function Tails_RollRight


; =============== S U B R O U T I N E =======================================


Tails_ChgJumpDir:
		move.w	(Sonic_top_speed).w,d6
		move.w	(Sonic_acceleration).w,d5
		asl.w	#1,d5
		btst	#4,obStatus(a0)
		bne.s	loc_112CA
		move.w	obVelX(a0),d0
		btst	#bitL,(v_jpadhold2).w
		beq.s	+
		bset	#0,obStatus(a0)
		sub.w	d5,d0	; add acceleration to the left
		move.w	d6,d1
		neg.w	d1
		cmp.w	d1,d0	; compare new speed with top speed
		bgt.s	+	; if new speed is less than the maximum, branch
		add.w	d5,d0	; remove this frame's acceleration change
		cmp.w	d1,d0	; compare speed with top speed
		ble.s	+	; if speed was already greater than the maximum, branch
		move.w	d1,d0	; limit speed on ground going left
+
		btst	#bitR,(v_jpadhold2).w
		beq.s	+
		bclr	#0,obStatus(a0)
		add.w	d5,d0	; add acceleration to the right
		cmp.w	d6,d0	; compare new speed with top speed
		blt.s	+	; if new speed is less than the maximum, branch
		sub.w	d5,d0	; remove this frame's acceleration change
		cmp.w	d6,d0	; compare speed with top speed
		bge.s	+	; if speed was already greater than the maximum, branch
		move.w	d6,d0	; limit speed on ground going right
+
		move.w	d0,obVelX(a0)

loc_112CA:
		cmpi.w	#$60,(Camera_Y_pos_bias).w
		beq.s	loc_112DC
		bhs.s	loc_112D8
		addq.w	#4,(Camera_Y_pos_bias).w

loc_112D8:
		subq.w	#2,(Camera_Y_pos_bias).w

loc_112DC:
		cmpi.w	#-$400,obVelY(a0)
		blo.s	locret_1130A
		move.w	obVelX(a0),d0
		move.w	d0,d1
		asr.w	#5,d1
		beq.s	locret_1130A
		bmi.s	loc_112FE
		sub.w	d1,d0
		bhs.s	loc_112F8
		clr.w	d0

loc_112F8:
		move.w	d0,obVelX(a0)
		rts
; ---------------------------------------------------------------------------

loc_112FE:
		sub.w	d1,d0
		blo.s	loc_11306
		clr.w	d0

loc_11306:
		move.w	d0,obVelX(a0)

locret_1130A:
		rts
; End of function Tails_ChgJumpDir


; =============== S U B R O U T I N E =======================================


Tails_LevelBoundaries:
		move.l	obX(a0),d1
		move.w	obVelX(a0),d0
		ext.l	d0
		asl.l	#8,d0
		add.l	d0,d1
		swap	d1
		move.w	(Camera_Min_X_pos).w,d0
		addi.w	#$10,d0
		cmp.w	d1,d0
		bhi.s	loc_11374
		move.w	(Camera_Max_X_pos).w,d0
		addi.w	#$128,d0
		tst.b	(f_lockscreen).w
		bne.s	loc_1133A
		addi.w	#$40,d0

loc_1133A:
		cmp.w	d1,d0
		bls.s	loc_11374

loc_1133E:
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		blt.s	loc_1134E
		rts
; ---------------------------------------------------------------------------

loc_1134E:
		cmpi.w	#(id_SBZ<<8)+1,(Current_ZoneAndAct).w
		bne.w	KillCharacter
		cmpi.w	#$2000,obX(a0)
		blo.w	KillCharacter
		clr.b	(v_lastlamp).w
		move.w	#1,(Level_Inactive_flag).w
		move.w	#(id_LZ<<8)+3,(Current_ZoneAndAct).w
		rts
; ---------------------------------------------------------------------------

loc_11374:
		move.w	d0,obX(a0)
		clr.w	obX+2(a0)
		clr.w	obVelX(a0)
		clr.w	obInertia(a0)
		bra.s	loc_1133E
; End of function Tails_LevelBoundaries


; =============== S U B R O U T I N E =======================================


Tails_Roll:
		tst.b	(f_slidemode).w
		bne.s	locret_113B2
		move.w	obInertia(a0),d0
		bpl.s	loc_1139A
		neg.w	d0

loc_1139A:
		cmpi.w	#$80,d0
		blo.s	locret_113B2
		move.b	(v_jpadhold2).w,d0
		andi.b	#btnL|btnR,d0
		bne.s	locret_113B2
		btst	#bitDn,(v_jpadhold2).w
		bne.s	loc_113B4

locret_113B2:
		rts
; ---------------------------------------------------------------------------

loc_113B4:
		btst	#2,obStatus(a0)
		beq.s	loc_113BE
		rts
; ---------------------------------------------------------------------------

loc_113BE:
		bset	#2,obStatus(a0)
		move.b	#$E,obHeight(a0)
		move.b	#7,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		addq.w	#5,obY(a0)
		move.w	#sfx_Roll,d0
		jsr	(PlaySound_Special).l
		tst.w	obInertia(a0)
		bne.s	locret_113F0
		move.w	#$200,obInertia(a0)

locret_113F0:
		rts
; End of function Tails_Roll


; =============== S U B R O U T I N E =======================================


Tails_Jump:
		move.b	(v_jpadpress2).w,d0
		andi.b	#btnABC,d0
		beq.w	locret_11496
		moveq	#0,d0
		move.b	obAngle(a0),d0
		addi.b	#$80,d0
		bsr.w	sub_13102
		cmpi.w	#6,d1
		blt.w	locret_11496
		move.w	#$680,d2
		btst	#6,obStatus(a0)
		beq.s	loc_11424
		move.w	#$380,d2

loc_11424:
		moveq	#0,d0
		move.b	obAngle(a0),d0
		subi.b	#$40,d0
		jsr	(CalcSine).l
		muls.w	d2,d1
		asr.l	#8,d1
		add.w	d1,obVelX(a0)
		muls.w	d2,d0
		asr.l	#8,d0
		add.w	d0,obVelY(a0)
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		addq.l	#4,sp
		move.b	#1,objoff_3C(a0)
		clr.b	$38(a0)
		move.w	#sfx_Jump,d0
		jsr	(PlaySound_Special).l
		move.b	#$F,obHeight(a0)
		move.b	#9,obWidth(a0)
		btst	#2,obStatus(a0)
		bne.s	loc_11498
		move.b	#$E,obHeight(a0)
		move.b	#7,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		bset	#2,obStatus(a0)
		addq.w	#5,obY(a0)

locret_11496:
		rts
; ---------------------------------------------------------------------------

loc_11498:
		bset	#4,obStatus(a0)
		rts
; End of function Tails_Jump


; =============== S U B R O U T I N E =======================================


Tails_JumpHeight:
		tst.b	objoff_3C(a0)
		beq.s	loc_114CC
		move.w	#-$400,d1
		btst	#6,obStatus(a0)
		beq.s	loc_114B6
		move.w	#-$200,d1

loc_114B6:
		cmp.w	obVelY(a0),d1
		ble.s	locret_114CA
		move.b	(v_jpadhold2).w,d0
		andi.b	#btnABC,d0
		bne.s	locret_114CA
		move.w	d1,obVelY(a0)

locret_114CA:
		rts
; ---------------------------------------------------------------------------

loc_114CC:
		cmpi.w	#$F040,obVelY(a0)
		bge.s	locret_114DA
		move.w	#$F040,obVelY(a0)

locret_114DA:
		rts
; End of function Tails_JumpHeight


; =============== S U B R O U T I N E =======================================


Tails_Spindash:
		tst.b	spindash_flag(a0)
		bne.s	loc_11510
		cmpi.b	#AniIDSonAni_Duck,obAnim(a0)
		bne.s	locret_1150E
		move.b	(v_jpadpress2).w,d0
		andi.b	#btnABC,d0
		beq.w	locret_1150E
		move.b	#AniIDSonAni_Spindash,obAnim(a0)
		move.w	#sfx_Roll,d0
		jsr	(PlaySound_Special).l
		addq.l	#4,sp
		move.b	#1,spindash_flag(a0)

locret_1150E:
		rts
; ---------------------------------------------------------------------------

loc_11510:
		move.b	(v_jpadhold2).w,d0
		btst	#bitDn,d0
		bne.s	loc_11556
		move.b	#$E,obHeight(a0)
		move.b	#7,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		addq.w	#5,obY(a0)
		clr.b	spindash_flag(a0)
	if FixBugs
		; To fix a bug in 'ScrollHoriz', we need an extra variable, so this
		; code has been modified to make the delay value only a single byte.
		; This is used by the fixed 'ScrollHoriz'.
		move.b	#$20,(Horiz_scroll_delay_val).w
		; Back up the position array index for later.
		move.b	(Tails_Pos_Record_Index+1).w,(Horiz_scroll_delay_val+1).w
	else
		move.w	#$2000,(Horiz_scroll_delay_val).w
	endif
		move.w	#$800,obInertia(a0)
		btst	#0,obStatus(a0)
		beq.s	loc_1154E
		neg.w	obInertia(a0)

loc_1154E:
		bset	#2,obStatus(a0)
		rts
; ---------------------------------------------------------------------------

loc_11556:
		move.b	(v_jpadpress2).w,d0
		andi.b	#btnABC,d0
		beq.w	loc_11564
		nop

loc_11564:
		addq.l	#4,sp
		rts
; End of function Tails_Spindash


; =============== S U B R O U T I N E =======================================


Tails_SlopeResist:
		move.b	obAngle(a0),d0
		addi.b	#$60,d0
		cmpi.b	#$C0,d0
		bhs.s	locret_1159C
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	#$20,d0
		asr.l	#8,d0
		tst.w	obInertia(a0)
		beq.s	locret_1159C
		bmi.s	loc_11598
		tst.w	d0
		beq.s	locret_11596
		add.w	d0,obInertia(a0)

locret_11596:
		rts
; ---------------------------------------------------------------------------

loc_11598:
		add.w	d0,obInertia(a0)

locret_1159C:
		rts
; End of function Tails_SlopeResist


; =============== S U B R O U T I N E =======================================


Tails_RollRepel:
		move.b	obAngle(a0),d0
		addi.b	#$60,d0
		cmpi.b	#$C0,d0
		bhs.s	locret_115D8
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	#$50,d0
		asr.l	#8,d0
		tst.w	obInertia(a0)
		bmi.s	loc_115CE
		tst.w	d0
		bpl.s	loc_115C8
		asr.l	#2,d0

loc_115C8:
		add.w	d0,obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_115CE:
		tst.w	d0
		bmi.s	loc_115D4
		asr.l	#2,d0

loc_115D4:
		add.w	d0,obInertia(a0)

locret_115D8:
		rts
; End of function Tails_RollRepel


; =============== S U B R O U T I N E =======================================


Tails_SlopeRepel:
		nop
		tst.b	objoff_38(a0)
		bne.s	locret_11614
		tst.w	objoff_2E(a0)
		bne.s	loc_11616
		move.b	obAngle(a0),d0
		addi.b	#$20,d0
		andi.b	#$C0,d0
		beq.s	locret_11614
		move.w	obInertia(a0),d0
		bpl.s	loc_115FE
		neg.w	d0

loc_115FE:
		cmpi.w	#$280,d0
		bhs.s	locret_11614
		clr.w	obInertia(a0)
		bset	#1,obStatus(a0)
		move.w	#$1E,objoff_2E(a0)

locret_11614:
		rts
; ---------------------------------------------------------------------------

loc_11616:
		subq.w	#1,objoff_2E(a0)
		rts
; End of function Tails_SlopeRepel


; =============== S U B R O U T I N E =======================================


Tails_JumpAngle:
		move.b	obAngle(a0),d0
		beq.s	loc_11636
		bpl.s	loc_1162C
		addq.b	#2,d0
		bhs.s	loc_11632
		moveq	#0,d0
		bra.s	loc_11632
; ---------------------------------------------------------------------------

loc_1162C:
		subq.b	#2,d0
		bhs.s	loc_11632
		moveq	#0,d0

loc_11632:
		move.b	d0,obAngle(a0)

loc_11636:
		move.b	objoff_27(a0),d0
		beq.s	locret_11674
		tst.w	obInertia(a0)
		bmi.s	loc_1165A
		move.b	objoff_2D(a0),d1
		add.b	d1,d0
		bhs.s	loc_11670
		subq.b	#1,objoff_2C(a0)
		bhs.s	loc_11670
		clr.b	objoff_2C(a0)
		moveq	#0,d0
		bra.s	loc_11670
; ---------------------------------------------------------------------------

loc_1165A:
		move.b	objoff_2D(a0),d1
		sub.b	d1,d0
		bhs.s	loc_11670
		subq.b	#1,objoff_2C(a0)
		bhs.s	loc_11670
		clr.b	objoff_2C(a0)
		moveq	#0,d0

loc_11670:
		move.b	d0,objoff_27(a0)

locret_11674:
		rts
; End of function Tails_JumpAngle


; =============== S U B R O U T I N E =======================================


Tails_Floor:
		move.b	obLRBSolidBit(a0),d5
		move.w	obVelX(a0),d1
		move.w	obVelY(a0),d2
		jsr	(CalcAngle).l
		subi.b	#$20,d0
		andi.b	#$C0,d0
		cmpi.b	#$40,d0
		beq.w	loc_11746
		cmpi.b	#$80,d0
		beq.w	loc_117A8
		cmpi.b	#$C0,d0
		beq.w	loc_11804
		bsr.w	Sonic_HitWall
		tst.w	d1
		bpl.s	loc_116BA
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)

loc_116BA:
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	loc_116CC
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)

loc_116CC:
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	locret_11744
		move.b	obVelY(a0),d2
		addq.b	#8,d2
		neg.b	d2
		cmp.b	d2,d1
		bge.s	loc_116E4
		cmp.b	d2,d0
		blt.s	locret_11744

loc_116E4:
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Tails_ResetTailsOnFloor
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		move.b	d3,d0
		addi.b	#$20,d0
		andi.b	#$40,d0
		bne.s	loc_11722
		move.b	d3,d0
		addi.b	#$10,d0
		andi.b	#$20,d0
		beq.s	loc_11714
		asr	obVelY(a0)
		bra.s	loc_11736
; ---------------------------------------------------------------------------

loc_11714:
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_11722:
		clr.w	obVelX(a0)
		cmpi.w	#$FC0,obVelY(a0)
		ble.s	loc_11736
		move.w	#$FC0,obVelY(a0)

loc_11736:
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	locret_11744
		neg.w	obInertia(a0)

locret_11744:
		rts
; ---------------------------------------------------------------------------

loc_11746:
		bsr.w	Sonic_HitWall
		tst.w	d1
		bpl.s	loc_11760
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)
		move.w	obVelY(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_11760:
		bsr.w	Sonic_DontRunOnWalls
		tst.w	d1
		bpl.s	loc_1177A
		sub.w	d1,obY(a0)
		tst.w	obVelY(a0)
		bpl.s	locret_11778
		clr.w	obVelY(a0)

locret_11778:
		rts
; ---------------------------------------------------------------------------

loc_1177A:
		tst.w	obVelY(a0)
		bmi.s	locret_117A6
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	locret_117A6
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Tails_ResetTailsOnFloor
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)

locret_117A6:
		rts
; ---------------------------------------------------------------------------

loc_117A8:
		bsr.w	Sonic_HitWall
		tst.w	d1
		bpl.s	loc_117BA
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)

loc_117BA:
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	loc_117CC
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)

loc_117CC:
		bsr.w	Sonic_DontRunOnWalls
		tst.w	d1
		bpl.s	locret_11802
		sub.w	d1,obY(a0)
		move.b	d3,d0
		addi.b	#$20,d0
		andi.b	#$40,d0
		bne.s	loc_117EC
		clr.w	obVelY(a0)
		rts
; ---------------------------------------------------------------------------

loc_117EC:
		move.b	d3,obAngle(a0)
		bsr.w	Tails_ResetTailsOnFloor
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	locret_11802
		neg.w	obInertia(a0)

locret_11802:
		rts
; ---------------------------------------------------------------------------

loc_11804:
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	loc_1181E
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
		move.w	obVelY(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_1181E:
		bsr.w	Sonic_DontRunOnWalls
		tst.w	d1
		bpl.s	loc_11838
		sub.w	d1,obY(a0)
		tst.w	obVelY(a0)
		bpl.s	locret_11836
		clr.w	obVelY(a0)

locret_11836:
		rts
; ---------------------------------------------------------------------------

loc_11838:
		tst.w	obVelY(a0)
		bmi.s	locret_11864
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	locret_11864
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Tails_ResetTailsOnFloor
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)

locret_11864:
		rts
; End of function Tails_Floor


; =============== S U B R O U T I N E =======================================


Tails_ResetTailsOnFloor:
		btst	#4,obStatus(a0)
		beq.s	loc_11874
		nop
		nop
		nop

loc_11874:
		bclr	#5,obStatus(a0)
		bclr	#1,obStatus(a0)
		bclr	#4,obStatus(a0)
		btst	#2,obStatus(a0)
		beq.s	loc_118AA
		bclr	#2,obStatus(a0)
		move.b	#$F,obHeight(a0)
		move.b	#9,obWidth(a0)
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		subq.w	#1,obY(a0)

loc_118AA:
		clr.b	objoff_3C(a0)
		clr.w	(v_itembonus).w
		clr.b	objoff_27(a0)
		rts
; End of function Tails_ResetTailsOnFloor

; ---------------------------------------------------------------------------

Obj02_Hurt:
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$30,obVelY(a0)
		btst	#6,obStatus(a0)
		beq.s	loc_118D8
		subi.w	#$20,obVelY(a0)

loc_118D8:
		bsr.w	Tails_HurtStop
		bsr.w	Tails_LevelBoundaries
		bsr.w	Tails_Animate
		bsr.w	LoadTailsDynPLC
		jmp	(DisplaySprite).l

; =============== S U B R O U T I N E =======================================


Tails_HurtStop:
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		blo.w	KillCharacter
		bsr.w	Tails_Floor
		btst	#1,obStatus(a0)
		bne.s	locret_1192A
		moveq	#0,d0
		move.w	d0,obVelY(a0)
		move.w	d0,obVelX(a0)
		move.w	d0,obInertia(a0)
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		move.b	#2,obRoutine(a0)
		move.w	#120,flashtime(a0)

locret_1192A:
		rts
; End of function Tails_HurtStop

; ---------------------------------------------------------------------------

Obj02_Dead:
		bsr.w	Tails_GameOver
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$38,obVelY(a0)				; increase vertical speed (apply gravity)
		bsr.w	Tails_Animate
		bsr.w	LoadTailsDynPLC
		jmp	(DisplaySprite).l

; =============== S U B R O U T I N E =======================================


Tails_GameOver:
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#$100,d0
		cmp.w	obY(a0),d0
		bhs.w	locret_11986
		move.w	(v_player+obX).w,d0
		subi.w	#$40,d0
		move.w	d0,obX(a0)
		move.w	(v_player+obY).w,d0
		subi.w	#$80,d0
		move.w	d0,obY(a0)
		move.b	#2,obRoutine(a0)
		andi.w	#$7FFF,obGfx(a0)
		move.b	#$C,obTopSolidBit(a0)
		move.b	#$D,obLRBSolidBit(a0)
		nop

locret_11986:
		rts
; End of function Tails_GameOver

; ---------------------------------------------------------------------------

Obj02_ResetLevel:
		tst.w	objoff_3A(a0)
		beq.s	locret_1199A
		subq.w	#1,objoff_3A(a0)
		bne.s	locret_1199A
		move.w	#1,(Level_Inactive_flag).w

locret_1199A:
		rts

; =============== S U B R O U T I N E =======================================


Tails_Animate:
		lea	TailsAniData(pc),a1

Tails_Animate2:
		moveq	#0,d0
		move.b	obAnim(a0),d0
		cmp.b	obPrevAni(a0),d0
		beq.s	loc_119BE
		move.b	d0,obPrevAni(a0)
		clr.b	obAniFrame(a0)
		clr.b	obTimeFrame(a0)

loc_119BE:
		add.w	d0,d0
		adda.w	(a1,d0.w),a1
		move.b	(a1),d0
		bmi.s	loc_11A2E
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		subq.b	#1,obTimeFrame(a0)
		bpl.s	locret_119FC
		move.b	d0,obTimeFrame(a0)
; End of function Tails_Animate


; =============== S U B R O U T I N E =======================================


sub_119E4:
		moveq	#0,d1
		move.b	obAniFrame(a0),d1
		move.b	1(a1,d1.w),d0
		cmpi.b	#$F0,d0
		bhs.s	loc_119FE

loc_119F4:
		move.b	d0,obFrame(a0)
		addq.b	#1,obAniFrame(a0)

locret_119FC:
		rts
; ---------------------------------------------------------------------------

loc_119FE:
		addq.b	#1,d0
		bne.s	loc_11A0E
		sf	obAniFrame(a0)
		move.b	1(a1),d0
		bra.s	loc_119F4
; ---------------------------------------------------------------------------

loc_11A0E:
		addq.b	#1,d0
		bne.s	loc_11A22
		move.b	2(a1,d1.w),d0
		sub.b	d0,obAniFrame(a0)
		sub.b	d0,d1
		move.b	1(a1,d1.w),d0
		bra.s	loc_119F4
; ---------------------------------------------------------------------------

loc_11A22:
		addq.b	#1,d0
		bne.s	locret_11A2C
		move.b	2(a1,d1.w),obAnim(a0)

locret_11A2C:
		rts
; End of function sub_119E4

; ---------------------------------------------------------------------------

loc_11A2E:
		subq.b	#1,obTimeFrame(a0)
		bpl.s	locret_119FC
		addq.b	#1,d0
		bne.w	loc_11B0E
		moveq	#0,d0
		move.b	objoff_27(a0),d0
		bne.w	loc_11AB4
		moveq	#0,d1
		move.b	obAngle(a0),d0
		move.b	obStatus(a0),d2
		andi.b	#1,d2
		bne.s	loc_11A56
		not.b	d0

loc_11A56:
		addi.b	#$10,d0
		bpl.s	loc_11A5E
		moveq	#3,d1

loc_11A5E:
		andi.b	#$FC,obRender(a0)
		eor.b	d1,d2
		or.b	d2,obRender(a0)
		lsr.b	#4,d0
		andi.b	#6,d0
		move.w	obInertia(a0),d2
		bpl.s	loc_11A78
		neg.w	d2

loc_11A78:
		move.b	d0,d3
		add.b	d3,d3
		add.b	d3,d3
		lea	(TailsAni_Walk).l,a1
		cmpi.w	#$600,d2
		blo.s	loc_11A9A
		lea	(TailsAni_Run).l,a1
		move.b	d0,d1
		lsr.b	#1,d1
		add.b	d1,d0
		add.b	d0,d0
		move.b	d0,d3

loc_11A9A:
		neg.w	d2
		addi.w	#$800,d2
		bpl.s	loc_11AA4
		moveq	#0,d2

loc_11AA4:
		lsr.w	#8,d2
		move.b	d2,obTimeFrame(a0)
		bsr.w	sub_119E4
		add.b	d3,obFrame(a0)
		rts
; ---------------------------------------------------------------------------

loc_11AB4:
		move.b	objoff_27(a0),d0
		moveq	#0,d1
		move.b	obStatus(a0),d2
		andi.b	#1,d2
		bne.s	loc_11AE8
		andi.b	#$FC,obRender(a0)
		moveq	#0,d2
		or.b	d2,obRender(a0)
		addi.b	#$B,d0
		divu.w	#$16,d0
		addi.b	#$75,d0
		move.b	d0,obFrame(a0)
		sf	obTimeFrame(a0)
		rts
; ---------------------------------------------------------------------------

loc_11AE8:
		moveq	#3,d2
		andi.b	#$FC,obRender(a0)
		or.b	d2,obRender(a0)
		neg.b	d0
		addi.b	#$8F,d0
		divu.w	#$16,d0
		addi.b	#$75,d0
		move.b	d0,obFrame(a0)
		sf	obTimeFrame(a0)
		rts
; ---------------------------------------------------------------------------

loc_11B0E:
		addq.b	#1,d0
		bne.s	loc_11B52
		move.w	obInertia(a0),d2
		bpl.s	loc_11B1A
		neg.w	d2

loc_11B1A:
		lea	(TailsAni_Roll2).l,a1
		cmpi.w	#$600,d2
		bhs.s	loc_11B2C
		lea	(TailsAni_Roll).l,a1

loc_11B2C:
		neg.w	d2
		addi.w	#$400,d2
		bpl.s	loc_11B36
		moveq	#0,d2

loc_11B36:
		lsr.w	#8,d2
		move.b	d2,obTimeFrame(a0)
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		bra.w	sub_119E4
; ---------------------------------------------------------------------------

loc_11B52:
		addq.b	#1,d0
		bne.s	loc_11B88
		move.w	obInertia(a0),d2
		bmi.s	loc_11B5E
		neg.w	d2

loc_11B5E:
		addi.w	#$800,d2
		bpl.s	loc_11B66
		moveq	#0,d2

loc_11B66:
		lsr.w	#6,d2
		move.b	d2,obTimeFrame(a0)
		lea	(TailsAni_Push_NoArt).l,a1
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		bra.w	sub_119E4
; ---------------------------------------------------------------------------

loc_11B88:
		move.w	(v_player2+obVelX).w,d1
		move.w	(v_player2+obVelY).w,d2
		jsr	(CalcAngle).l
		moveq	#0,d1
		move.b	obStatus(a0),d2
		andi.b	#1,d2
		bne.s	loc_11BA6
		not.b	d0
		bra.s	loc_11BAA
; ---------------------------------------------------------------------------

loc_11BA6:
		addi.b	#$80,d0

loc_11BAA:
		addi.b	#$10,d0
		bpl.s	loc_11BB2
		moveq	#3,d1

loc_11BB2:
		andi.b	#$FC,obRender(a0)
		eor.b	d1,d2
		or.b	d2,obRender(a0)
		lsr.b	#3,d0
		andi.b	#$C,d0
		move.b	d0,d3
		lea	(byte_11E3C).l,a1
		move.b	#3,obTimeFrame(a0)
		bsr.w	sub_119E4
		add.b	d3,obFrame(a0)
		rts
; ---------------------------------------------------------------------------
TailsAniData:	dc.w TailsAni_Walk-TailsAniData
		dc.w TailsAni_Run-TailsAniData
		dc.w TailsAni_Roll-TailsAniData
		dc.w TailsAni_Roll2-TailsAniData
		dc.w TailsAni_Push_NoArt-TailsAniData
		dc.w TailsAni_Wait-TailsAniData
		dc.w TailsAni_Balance_NoArt-TailsAniData
		dc.w TailsAni_LookUp-TailsAniData
		dc.w TailsAni_Duck-TailsAniData
		dc.w TailsAni_Spindash-TailsAniData
		dc.w TailsAni_0A-TailsAniData
		dc.w TailsAni_0B-TailsAniData
		dc.w TailsAni_0C-TailsAniData
		dc.w TailsAni_Stop-TailsAniData
		dc.w TailsAni_Fly-TailsAniData
		dc.w TailsAni_0F-TailsAniData
		dc.w TailsAni_Jump-TailsAniData
		dc.w TailsAni_11-TailsAniData
		dc.w TailsAni_12-TailsAniData
		dc.w TailsAni_13-TailsAniData
		dc.w TailsAni_14-TailsAniData
		dc.w TailsAni_15-TailsAniData
		dc.w TailsAni_Death1-TailsAniData
		dc.w TailsAni_UnusedDrown-TailsAniData
		dc.w TailsAni_Death2-TailsAniData
		dc.w TailsAni_19-TailsAniData
		dc.w TailsAni_1A-TailsAniData
		dc.w TailsAni_1B-TailsAniData
		dc.w TailsAni_1C-TailsAniData
		dc.w TailsAni_1D-TailsAniData
		dc.w TailsAni_1E-TailsAniData
TailsAni_Walk:	dc.b $FF,$10,$11,$12,$13,$14,$15, $E, $F,$FF
TailsAni_Run:	dc.b $FF,$2E,$2F,$30,$31,$FF,$FF,$FF,$FF,$FF
TailsAni_Roll:	dc.b   1,$48,$47,$46,$FF
TailsAni_Roll2:	dc.b   1,$48,$47,$46,$FF
TailsAni_Push_NoArt:dc.b $FD,  9, $A, $B, $C, $D, $E,$FF
TailsAni_Wait:	dc.b   7,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  3,  2,  1,  1,  1
		dc.b   1,  1,  1,  1,  1,  3,  2,  1,  1,  1,  1,  1,  1,  1,  1,  1
		dc.b   5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5
		dc.b   6,  7,  8,  7,  8,  7,  8,  7,  8,  7,  8,  6,$FE,$1C
TailsAni_Balance_NoArt:dc.b $1F,  1,  2,  3,  4,  5,  6,  7,  8,$FF
TailsAni_LookUp:dc.b $3F,  4,$FF
TailsAni_Duck:	dc.b $3F,$5B,$FF
TailsAni_Spindash:dc.b	 0,$60,$61,$62,$FF
TailsAni_0A:	dc.b $3F,$82,$FF
TailsAni_0B:	dc.b   7,  8,  8,  9,$FD,  5
TailsAni_0C:	dc.b   7,  9,$FD,  5
TailsAni_Stop:	dc.b   7,  1,  2,$FF
TailsAni_Fly:	dc.b   7,$5E,$5F,$FF
TailsAni_0F:	dc.b   7,  1,  2,  3,  4,  5,$FF
TailsAni_Jump:	dc.b   3,$59,$5A,$59,$5A,$59,$5A,$59,$5A,$59,$5A,$59,$5A,$FD,  0
TailsAni_11:	dc.b   4,  1,  2,$FF
TailsAni_12:	dc.b  $F,  1,  2,  3,$FE,  1
TailsAni_13:	dc.b  $F,  1,  2,$FE,  1
TailsAni_14:	dc.b $3F,  1,$FF
TailsAni_15:	dc.b  $B,  1,  2,  3,  4,$FD,  0
TailsAni_Death1:dc.b $20,$5D,$FF
TailsAni_UnusedDrown:dc.b $2F,$5D,$FF
TailsAni_Death2:dc.b   3,$5D,$FF
TailsAni_19:	dc.b   3,$5D,$FF
TailsAni_1A:	dc.b   3,$5C,$FF
TailsAni_1B:	dc.b   7,  1,  1,$FF
TailsAni_1C:	dc.b $77,  0,$FD,  0
TailsAni_1D:	dc.b   3,  1,  2,  3,  4,  5,  6,  7,  8,$FF
TailsAni_1E:	dc.b   3,  1,  2,  3,  4,  5,  6,  7,  8,$FF
		even
; ---------------------------------------------------------------------------
; Tails' Tails pattern loading subroutine
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; LoadTailsDynPLC_F600:
LoadTailsTailsDynPLC:
		moveq	#0,d0
		move.b	obFrame(a0),d0
		cmp.b	(TailsTails_LastLoadedDPLC).w,d0
		beq.s	LoadTailsDynPLC.return
		move.b	d0,(TailsTails_LastLoadedDPLC).w
		lea	(TailsDynPLC).l,a2
		add.w	d0,d0
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,d5
		subq.w	#1,d5
		bmi.s	LoadTailsDynPLC.return
		move.w	#ArtTile_TailsTails*tile_size,d4
		bra.s	LoadTailsDynPLC.TPLC_ReadEntry
; End of function LoadTailsTailsDynPLC

; ---------------------------------------------------------------------------
; Tails pattern loading subroutine
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


LoadTailsDynPLC:
		moveq	#0,d0
		move.b	obFrame(a0),d0
		cmp.b	(Tails_LastLoadedDPLC).w,d0
		beq.s	LoadTailsDynPLC.return
		move.b	d0,(Tails_LastLoadedDPLC).w
		lea	(TailsDynPLC).l,a2
		add.w	d0,d0
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,d5
		subq.w	#1,d5
		bmi.s	LoadTailsDynPLC.return
		move.w	#ArtTile_Tails*tile_size,d4
; loc_11D50:
.TPLC_ReadEntry:
		moveq	#0,d1
		move.w	(a2)+,d1
		move.w	d1,d3
		lsr.w	#8,d3
		andi.w	#$F0,d3
		addi.w	#$10,d3
		andi.w	#$FFF,d1
		lsl.l	#5,d1
		addi.l	#Art_Tails,d1
		move.w	d4,d2
		add.w	d3,d4
		add.w	d3,d4
		jsr	(QueueDMATransfer).l
		dbf	d5,.TPLC_ReadEntry

.return:
		rts
; End of function LoadTailsDynPLC

; ===========================================================================
; ---------------------------------------------------------------------------
; Object 05 - Tails' tails
; ---------------------------------------------------------------------------

Obj05:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj05_Index(pc,d0.w),d1
		jmp	Obj05_Index(pc,d1.w)
; ===========================================================================
Obj05_Index:	dc.w Obj05_Init-Obj05_Index
		dc.w Obj05_Main-Obj05_Index

Tails_prev_anim = objoff_30
; ===========================================================================

Obj05_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Tails,obMap(a0)
		move.w	#make_art_tile(ArtTile_TailsTails,0,0),obGfx(a0)
		move.w	#$100,obPriority(a0)
		move.b	#$18,obActWid(a0)
		move.b	#4,obRender(a0)

Obj05_Main:
		move.b	(v_player2+obAngle).w,obAngle(a0)
		move.b	(v_player2+obStatus).w,obStatus(a0)
		move.w	(v_player2+obX).w,obX(a0)
		move.w	(v_player2+obY).w,obY(a0)
		moveq	#0,d0
		move.b	(v_player2+obAnim).w,d0
		cmp.b	Tails_prev_anim(a0),d0
		beq.s	loc_11DE6
		move.b	d0,Tails_prev_anim(a0)
		move.b	Obj05_Animations(pc,d0.w),obAnim(a0)

loc_11DE6:
		lea	(Obj05_AniData).l,a1
		bsr.w	Tails_Animate2
		bsr.w	LoadTailsTailsDynPLC
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------
Obj05_Animations:
		dc.b   0,  0
		dc.b   3,  3
		dc.b   0,  1
		dc.b   0,  2
		dc.b   1,  7
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		dc.b   0,  0
		even

Obj05_AniData:	dc.w byte_11E2A-Obj05_AniData
		dc.w byte_11E2D-Obj05_AniData
		dc.w byte_11E34-Obj05_AniData
		dc.w byte_11E3C-Obj05_AniData
		dc.w byte_11E42-Obj05_AniData
		dc.w byte_11E48-Obj05_AniData
		dc.w byte_11E4E-Obj05_AniData
		dc.w byte_11E54-Obj05_AniData
byte_11E2A:	dc.b $20,  0,$FF
byte_11E2D:	dc.b   7,  9, $A, $B, $C, $D,$FF
byte_11E34:	dc.b   3,  9, $A, $B, $C, $D,$FD,  1
byte_11E3C:	dc.b $FC,$49,$4A,$4B,$4C,$FF
byte_11E42:	dc.b   3,$4D,$4E,$4F,$50,$FF
byte_11E48:	dc.b   3,$51,$52,$53,$54,$FF
byte_11E4E:	dc.b   3,$55,$56,$57,$58,$FF
byte_11E54:	dc.b   2,$81,$82,$83,$84,$FF
		even
; ---------------------------------------------------------------------------
		include	"objects/06 EHZ Spiral.asm"

; =============== S U B R O U T I N E =======================================


ResumeMusic:
		cmpi.w	#12,(v_air).w
		bhi.s	loc_12310
		move.w	#bgm_SYZ,d0
		cmpi.w	#id_LZ<<8+3,(Current_ZoneAndAct).w
		bne.s	loc_122F6
		move.w	#bgm_SBZ,d0

loc_122F6:
		tst.b	(v_invinc).w
		beq.s	loc_12300
		move.w	#bgm_Invincible,d0

loc_12300:
		tst.b	(f_lockscreen).w
		beq.s	loc_1230A
		move.w	#bgm_Boss,d0

loc_1230A:
		jsr	(PlaySound).l

loc_12310:
		move.w	#30,(v_air).w
		clr.b	(v_sonicbubbles+objoff_32).w
		rts
; End of function ResumeMusic

; ---------------------------------------------------------------------------
		include	"objects/38 Shield and Invincibility.asm"
Map_obj38:	binclude	"mappings/sprite/obj38.bin"
		even
; ===========================================================================
Ani_obj38:	dc.w byte_125C2-Ani_obj38
		dc.w byte_125CE-Ani_obj38
		dc.w byte_125D4-Ani_obj38
		dc.w byte_125EE-Ani_obj38
		dc.w byte_12608-Ani_obj38
byte_125C2:	dc.b   0,  5,  0,  5,  1,  5,  2,  5,  3,  5,  4,$FF
byte_125CE:	dc.b   5,  4,  5,  6,  7,$FF
byte_125D4:	dc.b   0,  4,  4,  0,  4,  4,  0,  5,  5,  0,  5,  5,  0,  6,  6,  0
		dc.b   6,  6,  0,  7,  7,  0,  7,  7,  0,$FF
byte_125EE:	dc.b   0,  4,  4,  0,  4,  0,  0,  5,  5,  0,  5,  0,  0,  6,  6,  0
		dc.b   6,  0,  0,  7,  7,  0,  7,  0,  0,$FF
byte_12608:	dc.b   0,  4,  0,  0,  4,  0,  0,  5,  0,  0,  5,  0,  0,  6,  0,  0
		dc.b   6,  0,  0,  7,  0,  0,  7,  0,  0,$FF
		even

; =============== S U B R O U T I N E =======================================

; Sonic_AnglePos:
AnglePos:
		move.l	(v_colladdr1).w,(Collision_addr).w
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	loc_12A14
		move.l	(v_colladdr2).w,(Collision_addr).w

loc_12A14:
		move.b	obTopSolidBit(a0),d5
		btst	#3,obStatus(a0)
		beq.s	loc_12A2C
		moveq	#0,d0
		move.b	d0,(Primary_Angle).w
		move.b	d0,(Secondary_Angle).w
		rts
; ---------------------------------------------------------------------------

loc_12A2C:
		moveq	#3,d0
		move.b	d0,(Primary_Angle).w
		move.b	d0,(Secondary_Angle).w
		move.b	obAngle(a0),d0
		addi.b	#$20,d0
		bpl.s	loc_12A4E
		move.b	obAngle(a0),d0
		bpl.s	loc_12A48
		subq.b	#1,d0

loc_12A48:
		addi.b	#$20,d0
		bra.s	loc_12A5A
; ---------------------------------------------------------------------------

loc_12A4E:
		move.b	obAngle(a0),d0
		bpl.s	loc_12A56
		addq.b	#1,d0

loc_12A56:
		addi.b	#$1F,d0

loc_12A5A:
		andi.b	#$C0,d0
		cmpi.b	#$40,d0
		beq.w	Sonic_WalkVertL
		cmpi.b	#$80,d0
		beq.w	Sonic_WalkCeiling
		cmpi.b	#$C0,d0
		beq.w	Sonic_WalkVertR
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(Primary_Angle).w,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	FindFloor
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		neg.w	d0
		add.w	d0,d3
		lea	(Secondary_Angle).w,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	FindFloor
		move.w	(sp)+,d0
		bsr.w	Sonic_Angle
		tst.w	d1
		beq.s	locret_12AE4
		bpl.s	loc_12AE6
		cmpi.w	#-$E,d1
		blt.s	locret_12AE4
		add.w	d1,obY(a0)

locret_12AE4:
		rts
; ---------------------------------------------------------------------------

loc_12AE6:
		cmpi.w	#$E,d1
		bgt.s	loc_12AF2

loc_12AEC:
		add.w	d1,obY(a0)
		rts
; ---------------------------------------------------------------------------

loc_12AF2:
		tst.b	stick_to_convex(a0)
		bne.s	loc_12AEC
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
		rts
; End of function AnglePos

; =============== S U B R O U T I N E =======================================


Sonic_Angle:
		move.b	(Secondary_Angle).w,d2
		cmp.w	d0,d1
		ble.s	loc_12B84
		move.b	(Primary_Angle).w,d2
		move.w	d0,d1

loc_12B84:
		btst	#0,d2
		bne.s	loc_12B90
		move.b	d2,obAngle(a0)
		rts
; ---------------------------------------------------------------------------

loc_12B90:
		move.b	obAngle(a0),d2
		addi.b	#$20,d2
		andi.b	#$C0,d2
		move.b	d2,obAngle(a0)
		rts
; End of function Sonic_Angle

; ---------------------------------------------------------------------------

Sonic_WalkVertR:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		neg.w	d0
		add.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(Primary_Angle).w,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	FindWall
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(Secondary_Angle).w,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	FindWall
		move.w	(sp)+,d0
		bsr.w	Sonic_Angle
		tst.w	d1
		beq.s	.return
		bpl.s	loc_12C14
		cmpi.w	#-$E,d1
		blt.s	.return
		add.w	d1,obX(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_12C14:
		cmpi.w	#$E,d1
		bgt.s	loc_12C20

loc_12C1A:
		add.w	d1,obX(a0)
		rts
; ---------------------------------------------------------------------------

loc_12C20:
		tst.b	stick_to_convex(a0)
		bne.s	loc_12C1A
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
		rts
; ---------------------------------------------------------------------------

Sonic_WalkCeiling:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d2
		eori.w	#$F,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(Primary_Angle).w,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	FindFloor
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d2
		eori.w	#$F,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		sub.w	d0,d3
		lea	(Secondary_Angle).w,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	FindFloor
		move.w	(sp)+,d0
		bsr.w	Sonic_Angle
		tst.w	d1
		beq.s	.return
		bpl.s	loc_12CB2
		cmpi.w	#-$E,d1
		blt.s	.return
		sub.w	d1,obY(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_12CB2:
		cmpi.w	#$E,d1
		bgt.s	loc_12CBE

loc_12CB8:
		sub.w	d1,obY(a0)
		rts
; ---------------------------------------------------------------------------

loc_12CBE:
		tst.b	stick_to_convex(a0)
		bne.s	loc_12CB8
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
		rts
; ---------------------------------------------------------------------------

Sonic_WalkVertL:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		sub.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d3
		eori.w	#$F,d3
		lea	(Primary_Angle).w,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	FindWall
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d3
		eori.w	#$F,d3
		lea	(Secondary_Angle).w,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	FindWall
		move.w	(sp)+,d0
		bsr.w	Sonic_Angle
		tst.w	d1
		beq.s	.return
		bpl.s	loc_12D50
		cmpi.w	#-$E,d1
		blt.s	.return
		sub.w	d1,obX(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_12D50:
		cmpi.w	#$E,d1
		bgt.s	loc_12D5C

loc_12D56:
		sub.w	d1,obX(a0)
		rts
; ---------------------------------------------------------------------------

loc_12D5C:
		tst.b	stick_to_convex(a0)
		bne.s	loc_12D56
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
		rts

; =============== S U B R O U T I N E =======================================


Floor_ChkTile:
		move.w	d2,d0		; y_pos
		add.w	d0,d0
		andi.w	#$F00,d0	; rounded 2*y_pos
		move.w	d3,d1		; x_pos
		lsr.w	#3,d1
		move.w	d1,d4
		lsr.w	#4,d1		; x_pos/128 = x_of_chunk
		andi.w	#$7F,d1
		add.w	d1,d0		; d0 is relevant chunk ID now
		moveq	#-1,d1
		clr.w	d1		; d1 is now $FFFF0000 = Chunk_Table
		lea	(v_lvllayout).w,a1
		move.b	(a1,d0.w),d1	; move 128*128 chunk ID to d1
		add.w	d1,d1
		move.w	.table(pc,d1.w),d1
		move.w	d2,d0		; y_pos
		andi.w	#$70,d0
		add.w	d0,d1
		andi.w	#$E,d4		; x_pos/8
		add.w	d4,d1
		movea.l	d1,a1		; address of block ID
		rts
; End of function Floor_ChkTile
; ===========================================================================
; precalculated values for Find_Tile
; (Sonic 1 calculated it every time instead of using a table)
.table:
c := 0
	rept 256
		dc.w	c
c := c+$80
	endm
; ===========================================================================

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; Scans vertically for up to 2 16x16 blocks to find solid ground or ceiling.
; d2 = y_pos
; d3 = x_pos
; d5 = ($c,$d) or ($e,$f) - solidity type bit (L/R/B or top)
; d6 = $0000 for no flip, $0800 for vertical flip
; a3 = delta-y for next location to check if current one is empty
; a4 = pointer to angle buffer
; returns relevant block ID in (a1)
; returns distance in d1
; returns angle in (a4)

FindFloor:
		bsr.w	Floor_ChkTile
		move.w	(a1),d0
		move.w	d0,d4
		andi.w	#$3FF,d0
		beq.s	loc_12DBE
		btst	d5,d4
		bne.s	loc_12DCC

loc_12DBE:
		add.w	a3,d2
		bsr.w	FindFloor2
		sub.w	a3,d2
		addi.w	#$10,d1
		rts
; ---------------------------------------------------------------------------

loc_12DCC:
		movea.l	(Collision_addr).w,a2
		add.w	d0,d0
		move.b	(a2,d0.w),d0
		andi.w	#$FF,d0
		beq.s	loc_12DBE
		cmpi.b	#6,(Current_Zone).w
		beq.s	+
		cmpi.b	#1,(Current_Zone).w
		beq.s	+
		tst.b	(Current_Zone).w
		beq.s	+
		lea	(AngleMap).l,a2
		bra.s	++
+
		lea	(S1_AngleMap).l,a2
+		move.b	(a2,d0.w),(a4)
		lsl.w	#4,d0
		move.w	d3,d1
		btst	#$A,d4
		beq.s	+
		not.w	d1
		neg.b	(a4)
+
		btst	#$B,d4
		beq.s	+
		addi.b	#$40,(a4)
		neg.b	(a4)
		subi.b	#$40,(a4)
+
		andi.w	#$F,d1
		add.w	d0,d1
		cmpi.b	#6,(Current_Zone).w
		beq.s	+
		cmpi.b	#1,(Current_Zone).w
		beq.s	+
		tst.b	(Current_Zone).w
		beq.s	+
		lea	(ColArray1).l,a2
		bra.s	++
+
		lea	(S1_ColArray1).l,a2
+		move.b	(a2,d1.w),d0
		ext.w	d0
		eor.w	d6,d4
		btst	#$B,d4
		beq.s	+
		neg.w	d0
+
		tst.w	d0
		beq.w	loc_12DBE
		bmi.s	loc_12E38
		cmpi.b	#$10,d0
		beq.s	loc_12E44
		move.w	d2,d1
		andi.w	#$F,d1
		add.w	d1,d0
		move.w	#$F,d1
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

loc_12E38:
		move.w	d2,d1
		andi.w	#$F,d1
		add.w	d1,d0
		bpl.w	loc_12DBE

loc_12E44:
		sub.w	a3,d2
		bsr.w	FindFloor2
		add.w	a3,d2
		subi.w	#$10,d1
		rts
; End of function FindFloor


; =============== S U B R O U T I N E =======================================


FindFloor2:
		bsr.w	Floor_ChkTile
		move.w	(a1),d0
		move.w	d0,d4
		andi.w	#$3FF,d0
		beq.s	loc_12E64
		btst	d5,d4
		bne.s	loc_12E72

loc_12E64:
		move.w	#$F,d1
		move.w	d2,d0
		andi.w	#$F,d0
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

loc_12E72:
		movea.l	(Collision_addr).w,a2
		add.w	d0,d0
		move.b	(a2,d0.w),d0
		andi.w	#$FF,d0
		beq.s	loc_12E64
		cmpi.b	#6,(Current_Zone).w
		beq.s	+
		cmpi.b	#1,(Current_Zone).w
		beq.s	+
		tst.b	(Current_Zone).w
		beq.s	+
		lea	(AngleMap).l,a2
		bra.s	++
+
		lea	(S1_AngleMap).l,a2
+		move.b	(a2,d0.w),(a4)
		lsl.w	#4,d0
		move.w	d3,d1
		btst	#$A,d4
		beq.s	loc_12E96
		not.w	d1
		neg.b	(a4)

loc_12E96:
		btst	#$B,d4
		beq.s	loc_12EA6
		addi.b	#$40,(a4)
		neg.b	(a4)
		subi.b	#$40,(a4)

loc_12EA6:
		andi.w	#$F,d1
		add.w	d0,d1
		cmpi.b	#6,(Current_Zone).w
		beq.s	+
		cmpi.b	#1,(Current_Zone).w
		beq.s	+
		tst.b	(Current_Zone).w
		beq.s	+
		lea	(ColArray1).l,a2
		bra.s	++
+
		lea	(S1_ColArray1).l,a2
+		move.b	(a2,d1.w),d0
		ext.w	d0
		eor.w	d6,d4
		btst	#$B,d4
		beq.s	loc_12EC2
		neg.w	d0

loc_12EC2:
		tst.w	d0
		beq.w	loc_12E64
		bmi.s	loc_12ED8
		move.w	d2,d1
		andi.w	#$F,d1
		add.w	d1,d0
		move.w	#$F,d1
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

loc_12ED8:
		move.w	d2,d1
		andi.w	#$F,d1
		add.w	d1,d0
		bpl.w	loc_12E64
		not.w	d1
		rts
; End of function FindFloor2


; =============== S U B R O U T I N E =======================================


FindWall:
		bsr.w	Floor_ChkTile
		move.w	(a1),d0
		move.w	d0,d4
		andi.w	#$3FF,d0
		beq.s	loc_12EFA
		btst	d5,d4
		bne.s	loc_12F08

loc_12EFA:
		add.w	a3,d3
		bsr.w	FindWall2
		sub.w	a3,d3
		addi.w	#$10,d1
		rts
; ---------------------------------------------------------------------------

loc_12F08:
		movea.l	(Collision_addr).w,a2
		add.w	d0,d0
		move.b	(a2,d0.w),d0
		andi.w	#$FF,d0
		beq.s	loc_12EFA
		cmpi.b	#6,(Current_Zone).w
		beq.s	+
		cmpi.b	#1,(Current_Zone).w
		beq.s	+
		tst.b	(Current_Zone).w
		beq.s	+
		lea	(AngleMap).l,a2
		bra.s	++
+
		lea	(S1_AngleMap).l,a2
+		move.b	(a2,d0.w),(a4)
		lsl.w	#4,d0
		move.w	d2,d1
		btst	#$B,d4
		beq.s	loc_12F34
		not.w	d1
		addi.b	#$40,(a4)
		neg.b	(a4)
		subi.b	#$40,(a4)

loc_12F34:
		btst	#$A,d4
		beq.s	loc_12F3C
		neg.b	(a4)

loc_12F3C:
		andi.w	#$F,d1
		add.w	d0,d1
		cmpi.b	#6,(Current_Zone).w
		beq.s	+
		cmpi.b	#1,(Current_Zone).w
		beq.s	+
		tst.b	(Current_Zone).w
		beq.s	+
		lea	(ColArray2).l,a2
		bra.s	++
+
		lea	(S1_ColArray2).l,a2
+		move.b	(a2,d1.w),d0
		ext.w	d0
		eor.w	d6,d4
		btst	#$A,d4
		beq.s	loc_12F58
		neg.w	d0

loc_12F58:
		tst.w	d0
		beq.w	loc_12EFA
		bmi.s	loc_12F74
		cmpi.b	#$10,d0
		beq.s	loc_12F80
		move.w	d3,d1
		andi.w	#$F,d1
		add.w	d1,d0
		move.w	#$F,d1
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

loc_12F74:
		move.w	d3,d1
		andi.w	#$F,d1
		add.w	d1,d0
		bpl.w	loc_12EFA

loc_12F80:
		sub.w	a3,d3
		bsr.w	FindWall2
		add.w	a3,d3
		subi.w	#$10,d1
		rts
; End of function FindWall


; =============== S U B R O U T I N E =======================================


FindWall2:
		bsr.w	Floor_ChkTile
		move.w	(a1),d0
		move.w	d0,d4
		andi.w	#$3FF,d0
		beq.s	loc_12FA0
		btst	d5,d4
		bne.s	loc_12FAE

loc_12FA0:
		move.w	#$F,d1
		move.w	d3,d0
		andi.w	#$F,d0
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

loc_12FAE:
		movea.l	(Collision_addr).w,a2
		add.w	d0,d0
		move.b	(a2,d0.w),d0
		andi.w	#$FF,d0
		beq.s	loc_12FA0
		cmpi.b	#6,(Current_Zone).w
		beq.s	+
		cmpi.b	#1,(Current_Zone).w
		beq.s	+
		tst.b	(Current_Zone).w
		beq.s	+
		lea	(AngleMap).l,a2
		bra.s	++
+
		lea	(S1_AngleMap).l,a2
+		move.b	(a2,d0.w),(a4)
		lsl.w	#4,d0
		move.w	d2,d1
		btst	#$B,d4
		beq.s	loc_12FDA
		not.w	d1
		addi.b	#$40,(a4)
		neg.b	(a4)
		subi.b	#$40,(a4)

loc_12FDA:
		btst	#$A,d4
		beq.s	loc_12FE2
		neg.b	(a4)

loc_12FE2:
		andi.w	#$F,d1
		add.w	d0,d1
		cmpi.b	#6,(Current_Zone).w
		beq.s	+
		cmpi.b	#1,(Current_Zone).w
		beq.s	+
		tst.b	(Current_Zone).w
		beq.s	+
		lea	(ColArray2).l,a2
		bra.s	++
+
		lea	(S1_ColArray2).l,a2
+		move.b	(a2,d1.w),d0
		ext.w	d0
		eor.w	d6,d4
		btst	#$A,d4
		beq.s	loc_12FFE
		neg.w	d0

loc_12FFE:
		tst.w	d0
		beq.w	loc_12FA0
		bmi.s	loc_13014
		move.w	d3,d1
		andi.w	#$F,d1
		add.w	d1,d0
		move.w	#$F,d1
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

loc_13014:
		move.w	d3,d1
		andi.w	#$F,d1
		add.w	d1,d0
		bpl.w	loc_12FA0
		not.w	d1
		rts
; End of function FindWall2

; =============== S U B R O U T I N E =======================================

; Sonic_WalkSpeed:
CalcRoomInFront:
		move.l	(v_colladdr1).w,(Collision_addr).w
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	loc_13094
		move.l	(v_colladdr2).w,(Collision_addr).w

loc_13094:
		move.b	obLRBSolidBit(a0),d5
		move.l	obX(a0),d3
		move.l	obY(a0),d2
		move.w	obVelX(a0),d1
		ext.l	d1
		asl.l	#8,d1
		add.l	d1,d3
		move.w	obVelY(a0),d1
		ext.l	d1
		asl.l	#8,d1
		add.l	d1,d2
		swap	d2
		swap	d3
		move.b	d0,(Primary_Angle).w
		move.b	d0,(Secondary_Angle).w
		move.b	d0,d1
		addi.b	#$20,d0
		bpl.s	loc_130D4
		move.b	d1,d0
		bpl.s	loc_130CE
		subq.b	#1,d0

loc_130CE:
		addi.b	#$20,d0
		bra.s	loc_130DE
; ---------------------------------------------------------------------------

loc_130D4:
		move.b	d1,d0
		bpl.s	loc_130DA
		addq.b	#1,d0

loc_130DA:
		addi.b	#$1F,d0

loc_130DE:
		andi.b	#$C0,d0
		beq.w	loc_131DE
		cmpi.b	#$80,d0
		beq.w	loc_133B0
		andi.b	#$38,d1
		bne.s	loc_130F6
		addq.w	#8,d2

loc_130F6:
		cmpi.b	#$40,d0
		beq.w	loc_13478
		addi.w	#$A,d3
		lea	(Primary_Angle).w,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	FindWall
		move.b	#$C0,d2
		move.b	(Primary_Angle).w,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3

.return:
		rts
; End of function CalcRoomInFront


; =============== S U B R O U T I N E =======================================


sub_13102:
		move.l	(v_colladdr1).w,(Collision_addr).w
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	loc_1311A
		move.l	(v_colladdr2).w,(Collision_addr).w

loc_1311A:
		move.b	obLRBSolidBit(a0),d5
		move.b	d0,(Primary_Angle).w
		move.b	d0,(Secondary_Angle).w
		addi.b	#$20,d0
		andi.b	#$C0,d0
		cmpi.b	#$40,d0
		beq.w	loc_13408
		cmpi.b	#$80,d0
		beq.w	Sonic_DontRunOnWalls
		cmpi.b	#$C0,d0
		beq.w	loc_1328E

loc_13146:
		move.l	(v_colladdr1).w,(Collision_addr).w
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	loc_1315E
		move.l	(v_colladdr2).w,(Collision_addr).w

loc_1315E:
		move.b	obTopSolidBit(a0),d5
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(Primary_Angle).w,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	FindFloor
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		sub.w	d0,d3
		lea	(Secondary_Angle).w,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	FindFloor
		move.w	(sp)+,d0
		clr.b	d2

loc_131BE:
		move.b	(Secondary_Angle).w,d3
		cmp.w	d0,d1
		ble.s	.skip
		move.b	(Primary_Angle).w,d3
		exg	d0,d1

.skip:
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3

.return:
		rts
; End of function sub_13102

; ---------------------------------------------------------------------------
		; unused
	;	move.w	obY(a0),d2
	;	move.w	obX(a0),d3

loc_131DE:
		addi.w	#$A,d2
		lea	(Primary_Angle).w,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	FindFloor
		clr.b	d2
		move.b	(Primary_Angle).w,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3

.return:
		rts

; =============== S U B R O U T I N E =======================================

; Sonic_HitFloor:
ChkFloorEdge:
		move.w	obX(a0),d3
		move.w	obY(a0),d2
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.l	(v_colladdr1).w,(Collision_addr).w
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	loc_1322E
		move.l	(v_colladdr2).w,(Collision_addr).w

loc_1322E:
		lea	(Primary_Angle).w,a4
		clr.b	(a4)
		movea.w	#$10,a3
		clr.w	d6
		move.b	obTopSolidBit(a0),d5
		bsr.w	FindFloor
		move.b	(Primary_Angle).w,d3
		btst	#0,d3
		beq.s	.return
		clr.b	d3

.return:
		rts
; End of function ChkFloorEdge


; =============== S U B R O U T I N E =======================================

;  ObjGetFloorDist:
ObjHitFloor:
		move.w	obX(a0),d3

ObjHitFloor2:
		move.w	obY(a0),d2
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d2
		lea	(Primary_Angle).w,a4
		clr.b	(a4)
		movea.w	#$10,a3
		clr.w	d6
		moveq	#$C,d5
		bsr.w	FindFloor
		move.b	(Primary_Angle).w,d3
		btst	#0,d3
		beq.s	.return
		clr.b	d3

.return:
		rts
; End of function ObjHitFloor

; ---------------------------------------------------------------------------

loc_1328E:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		sub.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(Primary_Angle).w,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	FindWall
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(Secondary_Angle).w,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	FindWall
		move.w	(sp)+,d0
		move.b	#$C0,d2
		move.b	(Secondary_Angle).w,d3
		cmp.w	d0,d1
		ble.s	.skip
		move.b	(Primary_Angle).w,d3
		exg	d0,d1

.skip:
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3

.return:
		rts

; =============== S U B R O U T I N E =======================================


sub_132EE:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		addi.w	#$A,d3
		lea	(Primary_Angle).w,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	FindWall
		move.b	#$C0,d2
		move.b	(Primary_Angle).w,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3

.return:
		rts
; End of function sub_132EE

; =============== S U B R O U T I N E =======================================


ObjHitWallRight:
		add.w	obX(a0),d3
		move.w	obY(a0),d2
		lea	(Primary_Angle).w,a4
		clr.b	(a4)
		movea.w	#$10,a3
		clr.w	d6
		moveq	#$D,d5
		bsr.w	FindWall
		move.b	(Primary_Angle).w,d3
		btst	#0,d3
		beq.s	.return
		move.b	#$C0,d3

.return:
		rts
; End of function ObjHitWallRight


; =============== S U B R O U T I N E =======================================


Sonic_DontRunOnWalls:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d2
		eori.w	#$F,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(Primary_Angle).w,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	FindFloor
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d2
		eori.w	#$F,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		sub.w	d0,d3
		lea	(Secondary_Angle).w,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	FindFloor
		move.w	(sp)+,d0
		move.b	#$80,d2
		move.b	(Secondary_Angle).w,d3
		cmp.w	d0,d1
		ble.s	.skip
		move.b	(Primary_Angle).w,d3
		exg	d0,d1

.skip:
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3

.return:
		rts
; End of function Sonic_DontRunOnWalls

; ---------------------------------------------------------------------------
		; unused
	;	move.w	obY(a0),d2
	;	move.w	obX(a0),d3

loc_133B0:
		subi.w	#$A,d2
		eori.w	#$F,d2
		lea	(Primary_Angle).w,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	FindFloor
		move.b	#$80,d2
		move.b	(Primary_Angle).w,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3

.return:
		rts
; ---------------------------------------------------------------------------

ObjHitCeiling:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d2
		eori.w	#$F,d2
		lea	(Primary_Angle).w,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		moveq	#$D,d5
		bsr.w	FindFloor
		move.b	(Primary_Angle).w,d3
		btst	#0,d3
		beq.s	.return
		move.b	#$80,d3

.return:
		rts
; ---------------------------------------------------------------------------

loc_13408:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		sub.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d3
		eori.w	#$F,d3
		lea	(Primary_Angle).w,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	FindWall
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d3
		eori.w	#$F,d3
		lea	(Secondary_Angle).w,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	FindWall
		move.w	(sp)+,d0
		move.b	#$40,d2
		move.b	(Secondary_Angle).w,d3
		cmp.w	d0,d1
		ble.s	.skip
		move.b	(Primary_Angle).w,d3
		exg	d0,d1

.skip:
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3

.return:
		rts

; =============== S U B R O U T I N E =======================================


Sonic_HitWall:
		move.w	obY(a0),d2
		move.w	obX(a0),d3

loc_13478:
		subi.w	#$A,d3
		eori.w	#$F,d3
		lea	(Primary_Angle).w,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	FindWall
		move.b	#$40,d2
		move.b	(Primary_Angle).w,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3

.return:
		rts
; End of function Sonic_HitWall

; ---------------------------------------------------------------------------
; Subroutine to detect when an object hits a wall to its left
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


ObjHitWallLeft:
		add.w	obX(a0),d3
		move.w	obY(a0),d2
		eori.w	#$F,d3
		lea	(Primary_Angle).w,a4
		clr.b	(a4)
		movea.w	#-$10,a3
		move.w	#$400,d6
		moveq	#$D,d5
		bsr.w	FindWall
		move.b	(Primary_Angle).w,d3
		btst	#0,d3
		beq.s	.return
		move.b	#$40,d3

.return:
		rts
; ---------------------------------------------------------------------------
		include	"objects/79 Lamppost.asm"
; ---------------------------------------------------------------------------
Map_Obj79:	dc.w word_1370A-Map_Obj79
		dc.w word_1372C-Map_Obj79
		dc.w word_1374E-Map_Obj79
word_1370A:	dc.w 4
		dc.w $E801,$2000,$2000,$FFF8
		dc.w $E801,$2800,$2800,	   0
		dc.w $F803,    6,    3,$FFF8
		dc.w $F803, $806, $803,	   0
word_1372C:	dc.w 4
		dc.w $E801,    2,    1,$FFF8
		dc.w $E801, $802, $801,	   0
		dc.w $F803,    6,    3,$FFF8
		dc.w $F803, $806, $803,	   0
word_1374E:	dc.w 4
		dc.w $E801,$2004,$2002,$FFF8
		dc.w $E801,$2804,$2802,	   0
		dc.w $F803,    6,    3,$FFF8
		dc.w $F803, $806, $803,	   0
		even
; ---------------------------------------------------------------------------
		include	"objects/S1/7D Hidden Bonuses.asm"
; ---------------------------------------------------------------------------
Map_Obj7D:
		dc.w word_13852-Map_Obj7D
		dc.w word_13854-Map_Obj7D
		dc.w word_1385E-Map_Obj7D
		dc.w word_13868-Map_Obj7D
word_13852:	dc.w 0
word_13854:	dc.w 1
		dc.w $F40E,    0,    0,$FFF0
word_1385E:	dc.w 1
		dc.w $F40E,   $C,    6,$FFF0
word_13868:	dc.w 1
		dc.w $F40E,  $18,   $C,$FFF0
		even
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Object 47 - pinball bumper (SYZ)
; ---------------------------------------------------------------------------

Obj47:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Bump_Index(pc,d0.w),d1
		jmp	Bump_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Bump_Index:	dc.w Bump_Main-Bump_Index
		dc.w Bump_Hit-Bump_Index
; ---------------------------------------------------------------------------

Bump_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.b	#4,obRender(a0)
		move.b	#$10,obActWid(a0)
		move.w	#$80,obPriority(a0)
		move.b	#$D7,obColType(a0)
		move.l	#Map_Bump,obMap(a0)
		move.w	#make_art_tile(ArtTile_Bumper,0,0),obGfx(a0)
		move.w	obX(a0),objoff_30(a0)	; setting these up for later!
		move.w	obY(a0),objoff_32(a0)

Bump_Hit:	; Routine 2
		move.b	obColProp(a0),d0
		beq.s	+
		lea	(v_player).w,a1
		bclr	#0,obColProp(a0)
		beq.s	loc_138CA
		bsr.s	Bumper_bump

loc_138CA:
		lea	(v_player2).w,a1
		bclr	#1,obColProp(a0)
		beq.s	loc_138D8
		bsr.s	Bumper_bump

loc_138D8:
		clr.b	obColProp(a0)
+		lea	Ani_Bump(pc),a1
		bsr.w	AnimateSprite
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------
Ani_Bump:	dc.w byte_13988-Ani_Bump
		dc.w byte_1398B-Ani_Bump
byte_13988:	dc.b  $F,  0,$FF
byte_1398B:	dc.b   3,  1,  2,  1,  2,$FD,  0
		even
; ---------------------------------------------------------------------------

; =============== S U B R O U T I N E =======================================


Bumper_bump:
		move.w	obX(a0),d1
		move.w	obY(a0),d2
		sub.w	obX(a1),d1
		sub.w	obY(a1),d2
		jsr	(CalcAngle).l
		jsr	(CalcSine).l
		muls.w	#-$700,d1
		asr.l	#8,d1
		move.w	d1,obVelX(a1)	; bounce Sonic away
		muls.w	#-$700,d0
		asr.l	#8,d0
		move.w	d0,obVelY(a1)	; bounce Sonic away
		bset	#1,obStatus(a1)
		bclr	#4,obStatus(a1)
		bclr	#5,obStatus(a1)
		clr.b	objoff_3C(a1)
		move.b	#1,obAnim(a0)	; use "hit" animation
		move.w	#sfx_Bumper,d0
		jsr	(PlaySound_Special).l	; play bumper sound
		lea	(v_objstate).w,a2
		moveq	#0,d0
		move.b	obRespawnNo(a0),d0
		beq.s	.addscore
		cmpi.b	#$8A,2(a2,d0.w)
		bhs.s	locret_13974
		addq.b	#1,2(a2,d0.w)

.addscore:
		moveq	#1,d0
		jsr	(AddPoints).l
		bsr.w	FindFreeObj
		bne.s	locret_13974
		_move.b	#id_Obj2A,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	#4,obFrame(a1)

locret_13974:
		rts
; End of function S1Obj47_Bump

; ---------------------------------------------------------------------------
Map_Bump:	dc.w word_13998-Map_Bump
		dc.w word_139AA-Map_Bump
		dc.w word_139BC-Map_Bump
word_13998:	dc.w 2
		dc.w $F007,    0,    0,$FFF0
		dc.w $F007, $800, $800,	   0
word_139AA:	dc.w 2
		dc.w $F406,    8,    4,$FFF4
		dc.w $F402, $808, $804,	   4
word_139BC:	dc.w 2
		dc.w $F007,   $E,    7,$FFF0
		dc.w $F007, $80E, $807,	   0
		even
; ---------------------------------------------------------------------------
		include	"objects/03 Collision Switcher.asm"
Map_Obj03:	include	"mappings/sprite/obj03.asm"
		even
		include	"objects/07 Water Surface.asm"
		include	"objects/08 Water Splash.asm"
		include	"objects/09 Bubbles.asm"
		include	"objects/0A Drowning Countdown.asm"
; ---------------------------------------------------------------------------
Map_Obj07:
		dc.w word_155AC-Map_Obj07
		dc.w word_155C6-Map_Obj07
		dc.w word_155E0-Map_Obj07
		dc.w word_155FA-Map_Obj07
		dc.w word_1562C-Map_Obj07
		dc.w word_1565E-Map_Obj07
word_155AC:	dc.w 3
		dc.w $F80D,    0,    0,$FFA0		; 0
		dc.w $F80D,    0,    0,$FFE0		; 4
		dc.w $F80D,    0,    0,	 $20		; 8
word_155C6:	dc.w 3
		dc.w $F80D,    8,    4,$FFA0		; 0
		dc.w $F80D,    8,    4,$FFE0		; 4
		dc.w $F80D,    8,    4,	 $20		; 8
word_155E0:	dc.w 3
		dc.w $F80D,  $10,    8,$FFA0		; 0
		dc.w $F80D,  $10,    8,$FFE0		; 4
		dc.w $F80D,  $10,    8,	 $20		; 8
word_155FA:	dc.w 6
		dc.w $F80D,    0,    0,$FFA0		; 0
		dc.w $F80D,    8,    4,$FFC0		; 4
		dc.w $F80D,    0,    0,$FFE0		; 8
		dc.w $F80D,    8,    4,	   0		; 12
		dc.w $F80D,    0,    0,	 $20		; 16
		dc.w $F80D,    8,    4,	 $40		; 20
word_1562C:	dc.w 6
		dc.w $F80D,    8,    4,$FFA0		; 0
		dc.w $F80D,  $10,    8,$FFC0		; 4
		dc.w $F80D,    8,    4,$FFE0		; 8
		dc.w $F80D,  $10,    8,	   0		; 12
		dc.w $F80D,    8,    4,	 $20		; 16
		dc.w $F80D,  $10,    8,	 $40		; 20
word_1565E:	dc.w 6
		dc.w $F80D,  $10,    8,$FFA0		; 0
		dc.w $F80D,    8,    4,$FFC0		; 4
		dc.w $F80D,  $10,    8,$FFE0		; 8
		dc.w $F80D,    8,    4,	   0		; 12
		dc.w $F80D,  $10,    8,	 $20		; 16
		dc.w $F80D,    8,    4,	 $40		; 20
		even
; ---------------------------------------------------------------------------
Map_Obj09_Bubbles:
		dc.w word_13D1C-Map_Obj09_Bubbles
		dc.w word_13D26-Map_Obj09_Bubbles
		dc.w word_13D30-Map_Obj09_Bubbles
		dc.w word_13D3A-Map_Obj09_Bubbles
		dc.w word_13D44-Map_Obj09_Bubbles
		dc.w word_13D4E-Map_Obj09_Bubbles
		dc.w word_13D58-Map_Obj09_Bubbles
		dc.w word_13D62-Map_Obj09_Bubbles
		dc.w word_13D84-Map_Obj09_Bubbles
		dc.w word_13DA6-Map_Obj09_Bubbles
		dc.w word_13DB0-Map_Obj09_Bubbles
		dc.w word_13DBA-Map_Obj09_Bubbles
		dc.w word_13DC4-Map_Obj09_Bubbles
		dc.w word_13DCE-Map_Obj09_Bubbles
		dc.w word_13DD8-Map_Obj09_Bubbles
		dc.w word_13DE2-Map_Obj09_Bubbles
		dc.w word_13DEC-Map_Obj09_Bubbles
		dc.w word_13DF6-Map_Obj09_Bubbles
		dc.w word_13E00-Map_Obj09_Bubbles
		dc.w word_13E0A-Map_Obj09_Bubbles
		dc.w word_13E14-Map_Obj09_Bubbles
		dc.w word_13E1E-Map_Obj09_Bubbles
		dc.w word_13E28-Map_Obj09_Bubbles
word_13D1C:	dc.w 1
		dc.w $FC00,    0,    0,$FFFC		; 0
word_13D26:	dc.w 1
		dc.w $FC00,    1,    0,$FFFC		; 0
word_13D30:	dc.w 1
		dc.w $FC00,    2,    1,$FFFC		; 0
word_13D3A:	dc.w 1
		dc.w $F805,    3,    1,$FFF8		; 0
word_13D44:	dc.w 1
		dc.w $F805,    7,    3,$FFF8		; 0
word_13D4E:	dc.w 1
		dc.w $F40A,   $B,    5,$FFF4		; 0
word_13D58:	dc.w 1
		dc.w $F00F,  $14,   $A,$FFF0		; 0
word_13D62:	dc.w 4
		dc.w $F005,  $24,  $12,$FFF0		; 0
		dc.w $F005, $824, $812,	   0		; 4
		dc.w	 5,$1024,$1012,$FFF0		; 8
		dc.w	 5,$1824,$1812,	   0		; 12
word_13D84:	dc.w 4
		dc.w $F005,  $28,  $14,$FFF0		; 0
		dc.w $F005, $828, $814,	   0		; 4
		dc.w	 5,$1028,$1014,$FFF0		; 8
		dc.w	 5,$1828,$1814,	   0		; 12
word_13DA6:	dc.w 1
		dc.w $F406,  $2C,  $16,$FFF8		; 0
word_13DB0:	dc.w 1
		dc.w $F406,  $32,  $19,$FFF8		; 0
word_13DBA:	dc.w 1
		dc.w $F406,  $38,  $1C,$FFF8		; 0
word_13DC4:	dc.w 1
		dc.w $F406,  $3E,  $1F,$FFF8		; 0
word_13DCE:	dc.w 1
		dc.w $F406,$2044,$2022,$FFF8		; 0
word_13DD8:	dc.w 1
		dc.w $F406,$204A,$2025,$FFF8		; 0
word_13DE2:	dc.w 1
		dc.w $F406,$2050,$2028,$FFF8		; 0
word_13DEC:	dc.w 1
		dc.w $F406,$2056,$202B,$FFF8		; 0
word_13DF6:	dc.w 1
		dc.w $F406,$205C,$202E,$FFF8		; 0
word_13E00:	dc.w 1
		dc.w $F406,$2062,$2031,$FFF8		; 0
word_13E0A:	dc.w 1
		dc.w $F805,  $68,  $34,$FFF8		; 0
word_13E14:	dc.w 1
		dc.w $F805,  $6C,  $36,$FFF8		; 0
word_13E1E:	dc.w 1
		dc.w $F805,  $70,  $38,$FFF8		; 0
word_13E28:	dc.w 0
		even
; ---------------------------------------------------------------------------
Map_Obj0A_Countdown:
		dc.w word_123B0-Map_Obj0A_Countdown
word_123B0:
		dc.w 1
		dc.w $E80E,    0,    0,$FFF2
		even
; ---------------------------------------------------------------------------
; Object 13 - HPZ waterfall
; ---------------------------------------------------------------------------

Obj13:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj13_Index(pc,d0.w),d1
		jmp	Obj13_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj13_Index:	dc.w loc_1446C-Obj13_Index
		dc.w loc_14532-Obj13_Index
		dc.w loc_14584-Obj13_Index
; ---------------------------------------------------------------------------

loc_1446C:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj13,obMap(a0)
		move.w	#make_art_tile(ArtTile_HPZ_Waterfall,3,1),obGfx(a0)
		move.b	#4,obRender(a0)
		move.b	#$10,obActWid(a0)
		move.w	#$80,obPriority(a0)
		move.b	#$12,obFrame(a0)
		bsr.s	sub_144D4
		move.b	#$A0,obHeight(a1)
		bset	#4,obRender(a1)
		move.l	a1,objoff_38(a0)
		move.w	obY(a0),objoff_34(a0)
		move.w	obY(a0),objoff_36(a0)
		cmpi.b	#$10,obSubtype(a0)
		blo.s	loc_14518
		bsr.s	sub_144D4
		move.l	a1,objoff_3C(a0)
		move.w	obY(a0),obY(a1)
		addi.w	#$98,obY(a1)
		bra.s	loc_14518

; =============== S U B R O U T I N E =======================================


sub_144D4:
		jsr	(FindNextFreeObj).l
		bne.s	.return
		_move.b	#id_Obj13,obID(a1)
		addq.b	#4,obRoutine(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.l	#Map_Obj13,obMap(a1)
		move.w	#make_art_tile(ArtTile_HPZ_Waterfall,3,1),obGfx(a1)
		move.b	#4,obRender(a1)
		move.b	#$10,obActWid(a1)
		move.w	#$80,obPriority(a1)
.return:	rts
; End of function sub_144D4

; ---------------------------------------------------------------------------

loc_14518:
		moveq	#0,d1
		move.b	obSubtype(a0),d1
		move.w	objoff_34(a0),d0
		subi.w	#$78,d0
		lsl.w	#4,d1
		add.w	d1,d0
		move.w	d0,obY(a0)
		move.w	d0,objoff_34(a0)

loc_14532:
		movea.l	objoff_38(a0),a1
		move.b	#$12,obFrame(a0)
		move.w	objoff_34(a0),d0
		move.w	(v_waterpos1).w,d1
		cmp.w	d0,d1
		bhs.s	loc_1454A
		move.w	d1,d0

loc_1454A:
		move.w	d0,obY(a0)
		sub.w	objoff_36(a0),d0
		addi.w	#$80,d0
		bmi.s	loc_1459C
		lsr.w	#4,d0
		move.w	d0,d1
		cmpi.w	#$F,d0
		blo.s	loc_14564
		moveq	#$F,d0

loc_14564:
		move.b	d0,obFrame(a1)
		cmpi.b	#$10,obSubtype(a0)
		blo.s	loc_14584
		movea.l	objoff_3C(a0),a1
		subi.w	#$F,d1
		bhs.s	loc_1457C
		moveq	#0,d1

loc_1457C:
		addi.w	#$13,d1
		move.b	d1,obFrame(a1)

loc_14584:
		out_of_range.w	DeleteObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

loc_1459C:
		moveq	#$13,d0
		move.b	d0,obFrame(a0)
		move.b	d0,obFrame(a1)
		out_of_range.w	DeleteObject
		rts
; ---------------------------------------------------------------------------
Map_Obj13:	dc.w word_1460E-Map_Obj13
		dc.w word_14618-Map_Obj13
		dc.w word_1462A-Map_Obj13
		dc.w word_1463C-Map_Obj13
		dc.w word_14656-Map_Obj13
		dc.w word_14670-Map_Obj13
		dc.w word_14692-Map_Obj13
		dc.w word_146B4-Map_Obj13
		dc.w word_146DE-Map_Obj13
		dc.w word_14708-Map_Obj13
		dc.w word_1473A-Map_Obj13
		dc.w word_1476C-Map_Obj13
		dc.w word_147A6-Map_Obj13
		dc.w word_147E0-Map_Obj13
		dc.w word_14822-Map_Obj13
		dc.w word_14864-Map_Obj13
		dc.w word_148AE-Map_Obj13
		dc.w word_148AE-Map_Obj13
		dc.w word_148AE-Map_Obj13
		dc.w word_1460C-Map_Obj13
		dc.w word_148C0-Map_Obj13
		dc.w word_148CA-Map_Obj13
		dc.w word_148D4-Map_Obj13
		dc.w word_148E6-Map_Obj13
		dc.w word_148F8-Map_Obj13
		dc.w word_14912-Map_Obj13
		dc.w word_1492C-Map_Obj13
		dc.w word_1494E-Map_Obj13
word_1460C:	dc.w 0
word_1460E:	dc.w 1
		dc.w $800C,  $10,    8,$FFF0		; 0
word_14618:	dc.w 2
		dc.w $800C,  $10,    8,$FFF0		; 0
		dc.w $880D,  $2D,  $16,$FFF0		; 4
word_1462A:	dc.w 2
		dc.w $800C,  $10,    8,$FFF0		; 0
		dc.w $880F,    0,    0,$FFF0		; 4
word_1463C:	dc.w 3
		dc.w $800C,  $10,    8,$FFF0		; 0
		dc.w $880F,    0,    0,$FFF0		; 4
		dc.w $A80D,  $2D,  $16,$FFF0		; 8
word_14656:	dc.w 3
		dc.w $800C,  $10,    8,$FFF0		; 0
		dc.w $880F,    0,    0,$FFF0		; 4
		dc.w $A80F,    0,    0,$FFF0		; 8
word_14670:	dc.w 4
		dc.w $800C,  $10,    8,$FFF0		; 0
		dc.w $880F,    0,    0,$FFF0		; 4
		dc.w $A80F,    0,    0,$FFF0		; 8
		dc.w $C80D,  $2D,  $16,$FFF0		; 12
word_14692:	dc.w 4
		dc.w $800C,  $10,    8,$FFF0		; 0
		dc.w $880F,    0,    0,$FFF0		; 4
		dc.w $A80F,    0,    0,$FFF0		; 8
		dc.w $C80F,    0,    0,$FFF0		; 12
word_146B4:	dc.w 5
		dc.w $800C,  $10,    8,$FFF0		; 0
		dc.w $880F,    0,    0,$FFF0		; 4
		dc.w $A80F,    0,    0,$FFF0		; 8
		dc.w $C80F,    0,    0,$FFF0		; 12
		dc.w $E80D,  $2D,  $16,$FFF0		; 16
word_146DE:	dc.w 5
		dc.w $800C,  $10,    8,$FFF0		; 0
		dc.w $880F,    0,    0,$FFF0		; 4
		dc.w $A80F,    0,    0,$FFF0		; 8
		dc.w $C80F,    0,    0,$FFF0		; 12
		dc.w $E80F,    0,    0,$FFF0		; 16
word_14708:	dc.w 6
		dc.w $800C,  $10,    8,$FFF0		; 0
		dc.w $880F,    0,    0,$FFF0		; 4
		dc.w $A80F,    0,    0,$FFF0		; 8
		dc.w $C80F,    0,    0,$FFF0		; 12
		dc.w $E80F,    0,    0,$FFF0		; 16
		dc.w  $80D,  $2D,  $16,$FFF0		; 20
word_1473A:	dc.w 6
		dc.w $800C,  $10,    8,$FFF0		; 0
		dc.w $880F,    0,    0,$FFF0		; 4
		dc.w $A80F,    0,    0,$FFF0		; 8
		dc.w $C80F,    0,    0,$FFF0		; 12
		dc.w $E80F,    0,    0,$FFF0		; 16
		dc.w  $80F,    0,    0,$FFF0		; 20
word_1476C:	dc.w 7
		dc.w $800C,  $10,    8,$FFF0		; 0
		dc.w $880F,    0,    0,$FFF0		; 4
		dc.w $A80F,    0,    0,$FFF0		; 8
		dc.w $C80F,    0,    0,$FFF0		; 12
		dc.w $E80F,    0,    0,$FFF0		; 16
		dc.w  $80F,    0,    0,$FFF0		; 20
		dc.w $280D,  $2D,  $16,$FFF0		; 24
word_147A6:	dc.w 7
		dc.w $800C,  $10,    8,$FFF0		; 0
		dc.w $880F,    0,    0,$FFF0		; 4
		dc.w $A80F,    0,    0,$FFF0		; 8
		dc.w $C80F,    0,    0,$FFF0		; 12
		dc.w $E80F,    0,    0,$FFF0		; 16
		dc.w  $80F,    0,    0,$FFF0		; 20
		dc.w $280F,    0,    0,$FFF0		; 24
word_147E0:	dc.w 8
		dc.w $800C,  $10,    8,$FFF0		; 0
		dc.w $880F,    0,    0,$FFF0		; 4
		dc.w $A80F,    0,    0,$FFF0		; 8
		dc.w $C80F,    0,    0,$FFF0		; 12
		dc.w $E80F,    0,    0,$FFF0		; 16
		dc.w  $80F,    0,    0,$FFF0		; 20
		dc.w $280F,    0,    0,$FFF0		; 24
		dc.w $480D,  $2D,  $16,$FFF0		; 28
word_14822:	dc.w 8
		dc.w $800C,  $10,    8,$FFF0		; 0
		dc.w $880F,    0,    0,$FFF0		; 4
		dc.w $A80F,    0,    0,$FFF0		; 8
		dc.w $C80F,    0,    0,$FFF0		; 12
		dc.w $E80F,    0,    0,$FFF0		; 16
		dc.w  $80F,    0,    0,$FFF0		; 20
		dc.w $280F,    0,    0,$FFF0		; 24
		dc.w $480F,    0,    0,$FFF0		; 28
word_14864:	dc.w 9
		dc.w $800C,  $10,    8,$FFF0		; 0
		dc.w $880F,    0,    0,$FFF0		; 4
		dc.w $A80F,    0,    0,$FFF0		; 8
		dc.w $C80F,    0,    0,$FFF0		; 12
		dc.w $E80F,    0,    0,$FFF0		; 16
		dc.w  $80F,    0,    0,$FFF0		; 20
		dc.w $280F,    0,    0,$FFF0		; 24
		dc.w $480F,    0,    0,$FFF0		; 28
		dc.w $680D,  $2D,  $16,$FFF0		; 32
word_148AE:	dc.w 2
		dc.w $F00A,  $18,   $C,$FFE8		; 0
		dc.w $F00A, $818, $80C,	   0		; 4
word_148C0:	dc.w 1
		dc.w $E00D,  $2D,  $16,$FFF0		; 0
word_148CA:	dc.w 1
		dc.w $E00F,    0,    0,$FFF0		; 0
word_148D4:	dc.w 2
		dc.w $E00F,    0,    0,$FFF0		; 0
		dc.w	$D,  $2D,  $16,$FFF0		; 4
word_148E6:	dc.w 2
		dc.w $E00F,    0,    0,$FFF0		; 0
		dc.w	$F,    0,    0,$FFF0		; 4
word_148F8:	dc.w 3
		dc.w $E00F,    0,    0,$FFF0		; 0
		dc.w	$F,    0,    0,$FFF0		; 4
		dc.w $200D,  $2D,  $16,$FFF0		; 8
word_14912:	dc.w 3
		dc.w $E00F,    0,    0,$FFF0		; 0
		dc.w	$F,    0,    0,$FFF0		; 4
		dc.w $200F,    0,    0,$FFF0		; 8
word_1492C:	dc.w 4
		dc.w $E00F,    0,    0,$FFF0		; 0
		dc.w	$F,    0,    0,$FFF0		; 4
		dc.w $200F,    0,    0,$FFF0		; 8
		dc.w $400D,  $2D,  $16,$FFF0		; 12
word_1494E:	dc.w 4
		dc.w $E00F,    0,    0,$FFF0		; 0
		dc.w	$F,    0,    0,$FFF0		; 4
		dc.w $200F,    0,    0,$FFF0		; 8
		dc.w $400F,    0,    0,$FFF0		; 12
		even
; ---------------------------------------------------------------------------
		include	"objects/Empty slots/14.asm"
; ---------------------------------------------------------------------------
; Object 5E - HTZ see-saw
; ---------------------------------------------------------------------------

Obj5E:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj5E_Index(pc,d0.w),d1
		jsr	Obj5E_Index(pc,d1.w)
		out_of_range.w	DeleteObject,objoff_30(a0)
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
Obj5E_Index:	dc.w See_Main-Obj5E_Index
		dc.w See_Slope-Obj5E_Index
		dc.w loc_14F10.return-Obj5E_Index
		dc.w See_Spikeball-Obj5E_Index
		dc.w See_MoveSpike-Obj5E_Index
		dc.w See_SpikeFall-Obj5E_Index
; ---------------------------------------------------------------------------

See_Main:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_obj5E,obMap(a0)
		move.w	#make_art_tile(ArtTile_HTZ_Seesaw,0,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$30,obActWid(a0)
		move.w	obX(a0),objoff_30(a0)
		tst.b	obSubtype(a0)	; is object type 00 ?
		bne.s	.noball		; if not, branch

		bsr.w	FindNextFreeObj
		bne.s	.noball
		_move.b	#id_Obj5E,obID(a1)	; load spikeball object
		addq.b	#6,obRoutine(a1)	; use See_Spikeball routine
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.l	a0,objoff_3C(a1)

.noball:
		btst	#0,obStatus(a0)	; is seesaw flipped?
		beq.s	.noflip		; if not, branch
		move.b	#2,obFrame(a0)	; use different frame

.noflip:
		move.b	obFrame(a0),objoff_3A(a0)

See_Slope:
		move.b	objoff_3A(a0),d1
		btst	#3,obStatus(a0) ; p1_standing_bit
		beq.s	loc_14D9A
		moveq	#2,d1
		lea	(v_player).w,a1
		move.w	obX(a0),d0
		sub.w	obX(a1),d0
		bhs.s	+
		neg.w	d0
		moveq	#0,d1
+
		cmpi.w	#8,d0
		bhs.s	+
		moveq	#1,d1
+
		btst	#4,obStatus(a0) ; p2_standing_bit
		beq.s	See_ChgFrame
		moveq	#2,d2
		lea	(v_player2).w,a1
		move.w	obX(a0),d0
		sub.w	obX(a1),d0
		bhs.s	+
		neg.w	d0
		moveq	#0,d2
+
		cmpi.w	#8,d0
		bhs.s	+
		moveq	#1,d2
+
		add.w	d2,d1
		cmpi.w	#3,d1
		bne.s	+
		addq.w	#1,d1
+
		lsr.w	#1,d1
		bra.s	See_ChgFrame
; ---------------------------------------------------------------------------

loc_14D9A:
		btst	#4,obStatus(a0) ; p2_standing_bit
		beq.s	See_StoodOn
		moveq	#2,d1
		lea	(v_player2).w,a1
		move.w	obX(a0),d0
		sub.w	obX(a1),d0
		bhs.s	+
		neg.w	d0
		moveq	#0,d1
+
		cmpi.w	#8,d0
		bhs.s	See_ChgFrame
		moveq	#1,d1
		bra.s	See_ChgFrame
; ===========================================================================
See_StoodOn:
		move.w	(v_player+obVelY).w,d0
		move.w	(v_player2+obVelY).w,d2
		cmp.w	d0,d2
		blt.s	+
		move.w	d2,d0
+
		move.w	d0,objoff_38(a0)


See_ChgFrame:
		move.b	obFrame(a0),d0
		cmp.b	d1,d0		; does frame need to change?
		beq.s	.noflip		; if not, branch
		bhs.s	.reduce_frame
		addq.b	#2,d0

.reduce_frame:
		subq.b	#1,d0
		move.b	d0,obFrame(a0)
		move.b	d1,objoff_3A(a0)
		bclr	#0,obRender(a0)
		btst	#1,obFrame(a0)
		beq.s	.noflip
		bset	#0,obRender(a0)

.noflip:
		lea	See_DataSlope(pc),a2
		btst	#0,obFrame(a0)
		beq.s	+
		lea	See_DataFlat(pc),a2
+
		move.w	obX(a0),-(sp)
		moveq	#0,d1
		move.b	obActWid(a0),d1
		moveq	#8,d3
		move.w	(sp)+,d4
		bra.w	SlopedPlatform
; End of function See_ChgFrame

; ---------------------------------------------------------------------------

See_Spikeball:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_obj5Eb,obMap(a0)
		move.w	#make_art_tile(ArtTile_HTZ_Seesaw,0,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$8B,obColType(a0)
		move.b	#$C,obActWid(a0)
		move.w	obX(a0),objoff_30(a0)
		addi.w	#$28,obX(a0)
		addi.w	#$10,obY(a0)
		move.w	obY(a0),objoff_34(a0)
		move.b	#1,obFrame(a0)
		btst	#0,obStatus(a0)
		beq.s	See_MoveSpike
		subi.w	#$50,obX(a0)
		move.b	#2,objoff_3A(a0)

See_MoveSpike:
		movea.l	objoff_3C(a0),a1
		moveq	#0,d0
		move.b	objoff_3A(a0),d0
		sub.b	objoff_3A(a1),d0
		beq.s	loc_14EF2
		bhs.s	loc_14EB0
		neg.b	d0

loc_14EB0:
		move.w	#-$818,d1
		move.w	#-$114,d2
		cmpi.b	#1,d0
		beq.s	loc_14ED6
		move.w	#-$AF0,d1
		move.w	#-$CC,d2
		cmpi.w	#$A00,objoff_38(a1)
		blt.s	loc_14ED6
		move.w	#-$E00,d1
		move.w	#-$A0,d2

loc_14ED6:
		move.w	d1,obVelY(a0)
		move.w	d2,obVelX(a0)
		move.w	obX(a0),d0
		sub.w	objoff_30(a0),d0
		bhs.s	+
		neg.w	obVelX(a0)
+
		addq.b	#2,obRoutine(a0)
		; fall through
; ---------------------------------------------------------------------------

See_SpikeFall:
		tst.w	obVelY(a0)
		bpl.s	loc_14F4E
		jsr	(ObjectMoveAndFall).l
		move.w	objoff_34(a0),d0
		subi.w	#$2F,d0
		cmp.w	obY(a0),d0
		bgt.s	loc_14F10.return
		jmp	(ObjectMoveAndFall).l
; ---------------------------------------------------------------------------

loc_14EF2:
		lea	See_YPos(pc),a2
		moveq	#0,d0
		move.b	obFrame(a1),d0
		move.w	#$28,d2
		move.w	obX(a0),d1
		sub.w	objoff_30(a0),d1
		bhs.s	loc_14F10
		neg.w	d2
		addq.w	#2,d0

loc_14F10:
		add.w	d0,d0
		move.w	objoff_34(a0),d1
		add.w	(a2,d0.w),d1
		move.w	d1,obY(a0)
		add.w	objoff_30(a0),d2
		move.w	d2,obX(a0)
		clr.w	obXSub(a0)	; x_sub/obXSub
		clr.w	obYSub(a0)	; y_sub/obYSub
.return:	rts
; ---------------------------------------------------------------------------

loc_14F4E:
		jsr	(ObjectMoveAndFall).l
		movea.l	objoff_3C(a0),a1
		lea	See_YPos(pc),a2
		moveq	#0,d0
		move.b	obFrame(a1),d0
		move.w	obX(a0),d1
		sub.w	objoff_30(a0),d1
		bhs.s	loc_14F6E
		addq.w	#2,d0

loc_14F6E:
		add.w	d0,d0
		move.w	objoff_34(a0),d1
		add.w	(a2,d0.w),d1
		cmp.w	obY(a0),d1
		bgt.s	loc_14F10.return
		movea.l	objoff_3C(a0),a1
		moveq	#2,d1
		tst.w	obVelX(a0)
		bmi.s	loc_14F8C
		moveq	#0,d1

loc_14F8C:
		move.b	d1,objoff_3A(a1)
		move.b	d1,objoff_3A(a0)
		cmp.b	obFrame(a1),d1
		beq.s	loc_14FB6
		lea	(v_player).w,a2
		bclr	#3,obStatus(a1)
		beq.s	loc_14FA8
		bsr.s	sub_14FC4

loc_14FA8:
		lea	(v_player2).w,a2
		bclr	#4,obStatus(a1)
		beq.s	loc_14FB6
		bsr.s	sub_14FC4

loc_14FB6:
		clr.w	obVelX(a0)
		clr.w	obVelY(a0)
		subq.b	#2,obRoutine(a0)
		rts

; =============== S U B R O U T I N E =======================================


sub_14FC4:
		move.w	obVelY(a0),obVelY(a2)
		neg.w	obVelY(a2)
		bset	#1,obStatus(a2)
		bclr	#3,obStatus(a2)
		clr.b	objoff_3C(a2)
		move.b	#$10,obAnim(a2)
		move.b	#2,obRoutine(a2)
		move.w	#sfx_Spring,d0
		jmp	(PlaySound_Special).l
; End of function sub_14FC4

; ---------------------------------------------------------------------------
See_YPos:	dc.w	 -8,  -$1C,  -$2F,  -$1C,    -8	; 0
See_DataSlope:	dc.b  $14, $14,	$16, $18, $1A, $1C, $1A	; 0
		dc.b  $18, $16,	$14, $13, $12, $11, $10	; 7
		dc.b   $F,  $E,	 $D,  $C,  $B,	$A,   9	; 14
		dc.b	8,   7,	  6,   5,   4,	 3,   2	; 21
		dc.b	1,   0,	 -1,  -2,  -3,	-4,  -5	; 28
		dc.b   -6,  -7,	 -8,  -9, -$A, -$B, -$C	; 35
		dc.b  -$D, -$E,	-$E, -$E, -$E, -$E, -$E	; 42
See_DataFlat:	dc.b	5,   5,	  5,   5,   5,	 5,   5	; 0
		dc.b	5,   5,	  5,   5,   5,	 5,   5	; 7
		dc.b	5,   5,	  5,   5,   5,	 5,   5	; 14
		dc.b	5,   5,	  5,   5,   5,	 5,   5	; 21
		dc.b	5,   5,	  5,   5,   5,	 5,   5	; 28
		dc.b	5,   5,	  5,   5,   5,	 5,   5	; 35
		dc.b	5,   5,	  5,   5,   5,	 5,   0	; 42
		even
; -------------------------------------------------------------------------------
; sprite mappings
; -------------------------------------------------------------------------------
Map_obj5E:	binclude	"mappings/sprite/obj5E_a.bin"
; -------------------------------------------------------------------------------
; sprite mappings
; -------------------------------------------------------------------------------
Map_obj5Eb:	binclude	"mappings/sprite/obj5E_b.bin"
		even
;--------------------------------------------------------------------------------
; Object 16 - the HTZ platform that goes down diagonally
; and stops after a while (in the final, it falls)
;--------------------------------------------------------------------------------

Obj16:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj16_Index(pc,d0.w),d1
		jmp	Obj16_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj16_Index:	dc.w Obj16_Init-Obj16_Index
		dc.w Obj16_Main-Obj16_Index
; ---------------------------------------------------------------------------

Obj16_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj16,obMap(a0)
		move.w	#make_art_tile(ArtTile_HtzZipline,2,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$20,obActWid(a0)
		clr.b	obFrame(a0)
		move.w	#$80,obPriority(a0)
		move.w	obX(a0),objoff_30(a0)
		move.w	obY(a0),objoff_32(a0)

Obj16_Main:
		move.w	obX(a0),-(sp)
		bsr.w	sub_15184
		moveq	#0,d1
		move.b	obActWid(a0),d1
		move.w	#-$28,d3
		move.w	(sp)+,d4
		bsr.w	PlatformObject
		move.w	objoff_30(a0),d0
		out_of_range2	DeleteObject
		jmp	(DisplaySprite).l

; =============== S U B R O U T I N E =======================================


sub_15184:
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		andi.w	#$F,d0
		add.w	d0,d0
		move.w	Obj16_SubIndex(pc,d0.w),d1
		jmp	Obj16_SubIndex(pc,d1.w)
; End of function sub_15184

; ---------------------------------------------------------------------------
Obj16_SubIndex:	dc.w Obj16_InitMove-Obj16_SubIndex
		dc.w Obj16_Move-Obj16_SubIndex
		dc.w Obj16_NoMove-Obj16_SubIndex
; ---------------------------------------------------------------------------

Obj16_InitMove:
		move.b	obStatus(a0),d0
		andi.b	#$18,d0
		beq.s	Obj16_NoMove
		addq.b	#1,obSubtype(a0)
		move.w	#$200,obVelX(a0)
		; This fixes issues with the object being flipped horizontally
		btst	#0,obStatus(a0)
		beq.s	.facingright
		neg.w	obVelX(a0)

.facingright:
		move.w	#$100,obVelY(a0)
		move.w	#$A0,objoff_34(a0)
		rts
; ---------------------------------------------------------------------------

Obj16_Move:
		jsr	(ObjectMove).l
		subq.w	#1,objoff_34(a0)
		bne.s	Obj16_NoMove
		addq.b	#1,obSubtype(a0)

Obj16_NoMove:
		rts
; ---------------------------------------------------------------------------
Map_Obj16:	include	"mappings/sprite/obj16.asm"
		even
; ---------------------------------------------------------------------------
; Object 19 - CPZ platforms moving side	to side
;----------------------------------------------------------------------------

Obj19:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj19_Index(pc,d0.w),d1
		jmp	Obj19_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj19_Index:	dc.w Obj19_Init-Obj19_Index
		dc.w Obj19_Main-Obj19_Index
Obj19_WidthArray:
		dc.b $20,0
		dc.b $20,1
		dc.b $20,2
		dc.b $40,3
		dc.b $30,4
; ---------------------------------------------------------------------------

Obj19_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj19,obMap(a0)
		move.w	#make_art_tile(ArtTile_CPZ_Platform,3,0),obGfx(a0)
		move.b	#4,obRender(a0)
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		lsr.w	#3,d0
		andi.w	#$1E,d0
		lea	Obj19_WidthArray(pc,d0.w),a2
		move.b	(a2)+,obActWid(a0)
		move.b	(a2)+,obFrame(a0)
		move.w	#$200,obPriority(a0)
		move.w	obX(a0),objoff_30(a0)
		move.w	obY(a0),objoff_32(a0)
		andi.b	#$F,obSubtype(a0)

Obj19_Main:
		move.w	obX(a0),-(sp)
		bsr.w	Obj19_Modes
		moveq	#0,d1
		move.b	obActWid(a0),d1
		move.w	#$10,d3
		move.w	(sp)+,d4
		bsr.w	PlatformObject
		out_of_range2	DeleteObject,objoff_30(a0)
		jmp	(DisplaySprite).l

; =============== S U B R O U T I N E =======================================


Obj19_Modes:
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		andi.w	#$F,d0
		add.w	d0,d0
		move.w	Obj19_SubIndex(pc,d0.w),d1
		jmp	Obj19_SubIndex(pc,d1.w)
; End of function Obj19_Modes

; ---------------------------------------------------------------------------
Obj19_SubIndex:	dc.w locret_1537A-Obj19_SubIndex
		dc.w loc_1537C-Obj19_SubIndex
		dc.w loc_1539C-Obj19_SubIndex
		dc.w loc_153AC-Obj19_SubIndex
		dc.w loc_1539C-Obj19_SubIndex
		dc.w loc_153CC-Obj19_SubIndex
		dc.w loc_153EC-Obj19_SubIndex
		dc.w loc_1540E-Obj19_SubIndex
		dc.w loc_15430-Obj19_SubIndex
		dc.w loc_1539C-Obj19_SubIndex
		dc.w loc_15450-Obj19_SubIndex
; ---------------------------------------------------------------------------

locret_1537A:
		rts
; ---------------------------------------------------------------------------

loc_1537C:
		move.b	(v_oscillate+$E).w,d0
		move.w	#$60,d1
		btst	#0,obStatus(a0)
		beq.s	loc_15390
		neg.w	d0
		add.w	d1,d0

loc_15390:
		move.w	objoff_30(a0),d1
		sub.w	d0,d1
		move.w	d1,obX(a0)
		rts
; ---------------------------------------------------------------------------

loc_1539C:
		move.b	obStatus(a0),d0
		andi.b	#$18,d0
		beq.s	locret_153AA
		addq.b	#1,obSubtype(a0)

locret_153AA:
		rts
; ---------------------------------------------------------------------------

loc_153AC:
		moveq	#0,d3
		move.b	obActWid(a0),d3
		bsr.w	ObjHitWallRight
		tst.w	d1
		bmi.s	loc_153C6
		addq.w	#1,obX(a0)
		move.w	obX(a0),objoff_30(a0)
		rts
; ---------------------------------------------------------------------------

loc_153C6:
		clr.b	obSubtype(a0)
		rts
; ---------------------------------------------------------------------------

loc_153CC:
		moveq	#0,d3
		move.b	obActWid(a0),d3
		bsr.w	ObjHitWallRight
		tst.w	d1
		bmi.s	loc_153E6
		addq.w	#1,obX(a0)
		move.w	obX(a0),objoff_30(a0)
		rts
; ---------------------------------------------------------------------------

loc_153E6:
		addq.b	#1,obSubtype(a0)
		rts
; ---------------------------------------------------------------------------

loc_153EC:
		jsr	(ObjectMove).l
		addi.w	#$18,obVelY(a0)
		bsr.w	ObjHitFloor
		tst.w	d1
		bpl.w	locret_1540C
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		clr.b	obSubtype(a0)

locret_1540C:
		rts
; ---------------------------------------------------------------------------

loc_1540E:
		tst.b	(f_switch+2).w
		beq.s	loc_15418
		subq.b	#3,obSubtype(a0)

loc_15418:
		addq.l	#6,sp
		out_of_range2	DeleteObject,objoff_30(a0)
		rts
; ---------------------------------------------------------------------------

loc_15430:
		move.b	(v_oscillate+$1E).w,d0
		move.w	#$80,d1
		btst	#0,obStatus(a0)
		beq.s	loc_15444
		neg.w	d0
		add.w	d1,d0

loc_15444:
		move.w	objoff_32(a0),d1
		sub.w	d0,d1
		move.w	d1,obY(a0)
		rts
; ---------------------------------------------------------------------------

loc_15450:
		moveq	#0,d3
		move.b	obActWid(a0),d3
		add.w	d3,d3
		moveq	#8,d1
		btst	#0,obStatus(a0)
		beq.s	loc_15466
		neg.w	d1
		neg.w	d3

loc_15466:
		tst.w	objoff_36(a0)
		bne.s	loc_15492
		move.w	obX(a0),d0
		sub.w	objoff_30(a0),d0
		cmp.w	d3,d0
		beq.s	loc_15484
		add.w	d1,obX(a0)
		move.w	#$12C,objoff_34(a0)
		rts
; ---------------------------------------------------------------------------

loc_15484:
		subq.w	#1,objoff_34(a0)
		bne.s	locret_15490
		move.w	#1,objoff_36(a0)

locret_15490:
		rts
; ---------------------------------------------------------------------------

loc_15492:
		move.w	obX(a0),d0
		sub.w	objoff_30(a0),d0
		beq.s	loc_154A2
		sub.w	d1,obX(a0)
		rts
; ---------------------------------------------------------------------------

loc_154A2:
		clr.w	objoff_36(a0)
		subq.b	#1,obSubtype(a0)
		rts
; ---------------------------------------------------------------------------
Map_Obj19:	dc.w word_154AE-Map_Obj19
word_154AE:	dc.w 2
		dc.w $F00F,    0,    0,$FFE0		; 0
		dc.w $F00F, $800, $800,	   0		; 4
		even
; ---------------------------------------------------------------------------
; Object 49 - EHZ waterfalls
; ---------------------------------------------------------------------------

Obj49:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj49_Index(pc,d0.w),d1
		jmp	Obj49_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj49_Index:	dc.w Obj49_Init-Obj49_Index
		dc.w Obj49_Main-Obj49_Index
; ---------------------------------------------------------------------------

Obj49_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj49,obMap(a0)
		move.w	#make_art_tile(ArtTile_Waterfall,1,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.b	#$20,obActWid(a0)
		move.w	obX(a0),objoff_30(a0)
		move.b	#$80,obHeight(a0)
		bset	#4,obRender(a0)

Obj49_Main:
		out_of_range2	DeleteObject
		move.w	obX(a0),d1
		move.w	d1,d2
		subi.w	#$40,d1
		addi.w	#$40,d2
		move.b	obSubtype(a0),d3
		clr.b	obFrame(a0)
		move.w	(v_player+obX).w,d0
		cmp.w	d1,d0
		blo.s	loc_15728
		cmp.w	d2,d0
		bhs.s	loc_15728
		move.b	#1,obFrame(a0)
		add.b	d3,obFrame(a0)
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_15728:
		move.w	(v_player2+obX).w,d0
		cmp.w	d1,d0
		blo.s	loc_1573A
		cmp.w	d2,d0
		bhs.s	loc_1573A
		move.b	#1,obFrame(a0)

loc_1573A:
		add.b	d3,obFrame(a0)
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------
Map_Obj49:	dc.w word_1574E-Map_Obj49
		dc.w word_15760-Map_Obj49
		dc.w word_157F2-Map_Obj49
		dc.w word_157F4-Map_Obj49
		dc.w word_157F2-Map_Obj49
		dc.w word_15816-Map_Obj49
word_1574E:	dc.w 2
		dc.w $800D,    0,    0,$FFE0		; 0
		dc.w $800D,    0,    0,	   0		; 4
word_15760:	dc.w $12
		dc.w $800D,    0,    0,$FFE0		; 0
		dc.w $800D,    0,    0,	   0		; 4
		dc.w $800F,    8,    4,$FFE0		; 8
		dc.w $800F,    8,    4,	   0		; 12
		dc.w $A00F,    8,    4,$FFE0		; 16
		dc.w $A00F,    8,    4,	   0		; 20
		dc.w $C00F,    8,    4,$FFE0		; 24
		dc.w $C00F,    8,    4,	   0		; 28
		dc.w $E00F,    8,    4,$FFE0		; 32
		dc.w $E00F,    8,    4,	   0		; 36
		dc.w	$F,    8,    4,$FFE0		; 40
		dc.w	$F,    8,    4,	   0		; 44
		dc.w $200F,    8,    4,$FFE0		; 48
		dc.w $200F,    8,    4,	   0		; 52
		dc.w $400F,    8,    4,$FFE0		; 56
		dc.w $400F,    8,    4,	   0		; 60
		dc.w $600F,    8,    4,$FFE0		; 64
		dc.w $600F,    8,    4,	   0		; 68
word_157F2:	dc.w 0
word_157F4:	dc.w 4
		dc.w $E00F,    8,    4,$FFE0		; 0
		dc.w $E00F,    8,    4,	   0		; 4
		dc.w	$F,    8,    4,$FFE0		; 8
		dc.w	$F,    8,    4,	   0		; 12
word_15816:	dc.w $A
		dc.w $C00F,    8,    4,$FFE0		; 0
		dc.w $C00F,    8,    4,	   0		; 4
		dc.w $E00F,    8,    4,$FFE0		; 8
		dc.w $E00F,    8,    4,	   0		; 12
		dc.w	$F,    8,    4,$FFE0		; 16
		dc.w	$F,    8,    4,	   0		; 20
		dc.w $200F,    8,    4,$FFE0		; 24
		dc.w $200F,    8,    4,	   0		; 28
		dc.w $400F,    8,    4,$FFE0		; 32
		dc.w $400F,    8,    4,	   0		; 36
		even
; ---------------------------------------------------------------------------
; Object 4D - Stegway badnik
;----------------------------------------------------------------------------

Obj4D:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj4D_Index(pc,d0.w),d1
		jmp	Obj4D_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj4D_Index:	dc.w Obj4D_Init-Obj4D_Index
		dc.w Obj4D_Main-Obj4D_Index
; ---------------------------------------------------------------------------

Obj4D_Init:
		move.l	#Map_Obj4D,obMap(a0)
		move.w	#make_art_tile(ArtTile_Stegway,1,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$A,obColType(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$18,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#$18,obWidth(a0)
		jsr	(ObjectMoveAndFall).l
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	locret_158DC
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		addq.b	#2,obRoutine(a0)

locret_158DC:
		rts
; ---------------------------------------------------------------------------

Obj4D_Main:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Obj4D_SubIndex(pc,d0.w),d1
		jsr	Obj4D_SubIndex(pc,d1.w)
		lea	Ani_Obj4D(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------
Obj4D_SubIndex:	dc.w loc_158FE-Obj4D_SubIndex
		dc.w loc_15922-Obj4D_SubIndex
; ---------------------------------------------------------------------------

loc_158FE:
		subq.w	#1,objoff_30(a0)
		bpl.s	locret_15920
		addq.b	#2,ob2ndRout(a0)
		move.w	#-$80,obVelX(a0)
		clr.b	obAnim(a0)
		bchg	#0,obStatus(a0)
		bne.s	locret_15920
		neg.w	obVelX(a0)

locret_15920:
		rts
; ---------------------------------------------------------------------------

loc_15922:
		bsr.w	sub_1596C
		jsr	(ObjectMoveAndFall).l
		jsr	(ObjHitFloor).l
		cmpi.w	#-8,d1
		blt.s	loc_15948
		cmpi.w	#$C,d1
		bge.s	locret_15946
		clr.w	obVelY(a0)
		add.w	d1,obY(a0)

locret_15946:
		rts
; ---------------------------------------------------------------------------

loc_15948:
		subq.b	#2,ob2ndRout(a0)
		move.w	#59,objoff_30(a0)
		move.w	obVelX(a0),d0
		ext.l	d0
		asl.l	#8,d0
		sub.l	d0,obX(a0)
		clr.w	obVelX(a0)
		move.b	#1,obAnim(a0)
		rts

; =============== S U B R O U T I N E =======================================


sub_1596C:
		move.w	obX(a0),d0
		sub.w	(v_player+obX).w,d0
		bmi.s	loc_159A0
		cmpi.w	#$60,d0
		bgt.s	locret_15990
		btst	#0,obStatus(a0)
		bne.s	loc_15992
		move.b	#2,obAnim(a0)
		move.w	#-$200,obVelX(a0)

locret_15990:
		rts
; ---------------------------------------------------------------------------

loc_15992:
		clr.b	obAnim(a0)
		move.w	#$80,obVelX(a0)
		rts
; ---------------------------------------------------------------------------

loc_159A0:
		cmpi.w	#-$60,d0
		blt.s	locret_15990
		btst	#0,obStatus(a0)
		beq.s	loc_159BC
		move.b	#2,obAnim(a0)
		move.w	#$200,obVelX(a0)
		rts
; ---------------------------------------------------------------------------

loc_159BC:
		clr.b	obAnim(a0)
		move.w	#-$80,obVelX(a0)
		rts
; End of function sub_1596C

; ---------------------------------------------------------------------------
Ani_Obj4D:	dc.w byte_159D0-Ani_Obj4D
		dc.w byte_159DE-Ani_Obj4D
		dc.w byte_159E1-Ani_Obj4D
byte_159D0:	dc.b   2,  0,  0,  0,  3,  3,  4,  1,  1,  2,  5,  5,  5,$FF
byte_159DE:	dc.b  $F,  0,$FF
byte_159E1:	dc.b   2,  6,  7,$FF
		even
Map_Obj4D:	dc.w word_159F6-Map_Obj4D
		dc.w word_15A20-Map_Obj4D
		dc.w word_15A4A-Map_Obj4D
		dc.w word_15A74-Map_Obj4D
		dc.w word_15A9E-Map_Obj4D
		dc.w word_15AC8-Map_Obj4D
		dc.w word_15AF2-Map_Obj4D
		dc.w word_15B14-Map_Obj4D
word_159F6:	dc.w 5
		dc.w $F005,    0,    0,$FFF0		; 0
		dc.w $F005,    4,    2,	   0		; 4
		dc.w $F801,    8,    4,$FFE8		; 8
		dc.w	 5,   $A,    5,$FFF0		; 12
		dc.w	 9,  $22,  $11,	   0		; 16
word_15A20:	dc.w 5
		dc.w $F005,    0,    0,$FFF0		; 0
		dc.w $F005,    4,    2,	   0		; 4
		dc.w $F801,    8,    4,$FFE8		; 8
		dc.w	 5,   $E,    7,$FFF0		; 12
		dc.w	 9,  $22,  $11,	   0		; 16
word_15A4A:	dc.w 5
		dc.w $F005,    0,    0,$FFF0		; 0
		dc.w $F005,    4,    2,	   0		; 4
		dc.w $F801,    8,    4,$FFE8		; 8
		dc.w	 5,  $12,    9,$FFF0		; 12
		dc.w	 9,  $22,  $11,	   0		; 16
word_15A74:	dc.w 5
		dc.w $F005,    0,    0,$FFF0		; 0
		dc.w $F005,    4,    2,	   0		; 4
		dc.w $F801,    8,    4,$FFE8		; 8
		dc.w	 5,   $A,    5,$FFF0		; 12
		dc.w	 9,  $28,  $14,	   0		; 16
word_15A9E:	dc.w 5
		dc.w $F005,    0,    0,$FFF0		; 0
		dc.w $F005,    4,    2,	   0		; 4
		dc.w $F801,    8,    4,$FFE8		; 8
		dc.w	 5,   $E,    7,$FFF0		; 12
		dc.w	 9,  $28,  $14,	   0		; 16
word_15AC8:	dc.w 5
		dc.w $F005,    0,    0,$FFF0		; 0
		dc.w $F005,    4,    2,	   0		; 4
		dc.w $F801,    8,    4,$FFE8		; 8
		dc.w	 5,  $12,    9,$FFF0		; 12
		dc.w	 9,  $28,  $14,	   0		; 16
word_15AF2:	dc.w 4
		dc.w $F00B,  $16,   $B,$FFE8		; 0
		dc.w $F005,    4,    2,	   0		; 4
		dc.w	 9,  $22,  $11,	   0		; 8
		dc.w $FB01,  $2E,  $17,	 $1A		; 12
word_15B14:	dc.w 4
		dc.w $F00B,  $16,   $B,$FFE8		; 0
		dc.w $F005,    4,    2,	   0		; 4
		dc.w	 9,  $28,  $14,	   0		; 8
		dc.w $FB01,  $30,  $18,	 $1A		; 12
		even
;----------------------------------------------------------------------------
		include	"objects/Empty slots/53.asm"
;----------------------------------------------------------------------------
; Object 52 - Piranha badnik
;----------------------------------------------------------------------------

Obj52:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj52_Index(pc,d0.w),d1
		jmp	Obj52_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj52_Index:	dc.w Obj52_Init-Obj52_Index
		dc.w Obj52_Main-Obj52_Index
		dc.w Obj52_Leap-Obj52_Index
; ---------------------------------------------------------------------------

Obj52_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj52,obMap(a0)
		move.w	#make_art_tile(ArtTile_BFish,1,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$A,obColType(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$10,obActWid(a0)
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		move.b	d0,d1
		andi.w	#$F0,d1
		add.w	d1,d1
		add.w	d1,d1
		move.w	d1,objoff_3A(a0)
		move.w	d1,objoff_3C(a0)
		andi.w	#$F,d0
		lsl.w	#6,d0
		subq.w	#1,d0
		move.w	d0,objoff_30(a0)
		move.w	d0,objoff_32(a0)
		move.w	#-$80,obVelX(a0)
		move.l	#-$48000,objoff_36(a0)
		move.w	obY(a0),objoff_34(a0)
		bset	#6,obStatus(a0)
		btst	#0,obStatus(a0)
		beq.s	Obj52_Main
		neg.w	obVelX(a0)

Obj52_Main:
		cmpi.w	#-1,objoff_3A(a0)
		beq.s	loc_15BE4
		subq.w	#1,objoff_3A(a0)

loc_15BE4:
		subq.w	#1,objoff_30(a0)
		bpl.s	loc_15C06
		move.w	objoff_32(a0),objoff_30(a0)
		neg.w	obVelX(a0)
		bchg	#0,obStatus(a0)
		move.b	#1,obPrevAni(a0)
		move.w	objoff_3C(a0),objoff_3A(a0)

loc_15C06:
		lea	Ani_Obj52(pc),a1
		jsr	(AnimateSprite).l
		jsr	(ObjectMove).l
		tst.w	objoff_3A(a0)
		bgt.s	+
		cmpi.w	#-1,objoff_3A(a0)
		beq.s	+
		move.l	#-$48000,objoff_36(a0)
		addq.b	#2,obRoutine(a0)
		move.w	#-1,objoff_3A(a0)
		move.b	#2,obAnim(a0)
		move.w	#1,objoff_3E(a0)
+		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------

Obj52_Leap:
		move.w	#$390,(v_waterpos1).w
		lea	Ani_Obj52(pc),a1
		jsr	(AnimateSprite).l
		move.w	objoff_3E(a0),d0
		sub.w	d0,objoff_30(a0)
		bsr.w	sub_15CF8
		tst.l	objoff_36(a0)
		bpl.s	loc_15CA0
		move.w	obY(a0),d0
		cmp.w	(v_waterpos1).w,d0
		bgt.s	+
		move.b	#3,obAnim(a0)
		bclr	#6,obStatus(a0)
		tst.b	objoff_2A(a0)
		bne.s	+
		move.w	obVelX(a0),d0
		asl.w	#1,d0
		move.w	d0,obVelX(a0)
		addq.w	#1,objoff_3E(a0)
		st	objoff_2A(a0)
+		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------

loc_15CA0:
		move.w	obY(a0),d0
		cmp.w	(v_waterpos1).w,d0
		bgt.s	loc_15CB4
		move.b	#1,obAnim(a0)
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------

loc_15CB4:
		clr.b	obAnim(a0)
		bset	#6,obStatus(a0)
		bne.s	loc_15CCE
		move.l	objoff_36(a0),d0
		asr.l	#1,d0
		move.l	d0,objoff_36(a0)
		nop

loc_15CCE:
		move.w	objoff_34(a0),d0
		cmp.w	obY(a0),d0
		bgt.s	+
		subq.b	#2,obRoutine(a0)
		tst.b	objoff_2A(a0)
		beq.s	+
		move.w	obVelX(a0),d0
		asr.w	#1,d0
		move.w	d0,obVelX(a0)
		sf	objoff_2A(a0)
+		jmp	(MarkObjGone).l

; =============== S U B R O U T I N E =======================================


sub_15CF8:
		move.l	obX(a0),d2
		move.l	obY(a0),d3
		move.w	obVelX(a0),d0
		ext.l	d0
		asl.l	#8,d0
		add.l	d0,d2
		add.l	objoff_36(a0),d3
		btst	#6,obStatus(a0)
		beq.s	loc_15D34
		tst.l	objoff_36(a0)
		bpl.s	loc_15D2C
		addi.l	#$1000,objoff_36(a0)
		addi.l	#$1000,objoff_36(a0)

loc_15D2C:
		subi.l	#$1000,objoff_36(a0)

loc_15D34:
		addi.l	#$1800,objoff_36(a0)
		move.l	d2,obX(a0)
		move.l	d3,obY(a0)
		rts
; End of function sub_15CF8

; ---------------------------------------------------------------------------
Ani_Obj52:	dc.w byte_15D4E-Ani_Obj52
		dc.w byte_15D52-Ani_Obj52
		dc.w byte_15D56-Ani_Obj52
		dc.w byte_15D5A-Ani_Obj52
byte_15D4E:	dc.b  $E,  0,  1,$FF			; 0
byte_15D52:	dc.b   3,  0,  1,$FF			; 0
byte_15D56:	dc.b  $E,  2,  3,$FF			; 0
byte_15D5A:	dc.b   3,  2,  3,$FF			; 0
		even
Map_Obj52:	dc.w word_15D66-Map_Obj52
		dc.w word_15D70-Map_Obj52
		dc.w word_15D7A-Map_Obj52
		dc.w word_15D84-Map_Obj52
word_15D66:	dc.w 1
		dc.w $F00F,    0,    0,$FFF0		; 0
word_15D70:	dc.w 1
		dc.w $F00F,  $10,    8,$FFF0		; 0
word_15D7A:	dc.w 1
		dc.w $F00F,  $20,  $10,$FFF0		; 0
word_15D84:	dc.w 1
		dc.w $F00F,  $30,  $18,$FFF0		; 0
		even
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 4F - Redz (dinosaur badnik) from HPZ
; ---------------------------------------------------------------------------

Obj4F:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj4F_Index(pc,d0.w),d1
		jmp	Obj4F_Index(pc,d1.w)
; ===========================================================================
Obj4F_Index:	dc.w Obj4F_Init-Obj4F_Index
		dc.w Obj4F_Main-Obj4F_Index
		dc.w Obj4F_Delete-Obj4F_Index
; ===========================================================================

Obj4F_Init:
		move.l	#Map_obj4F,obMap(a0)
		move.w	#make_art_tile(ArtTile_Redz,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#6,obWidth(a0)
		move.b	#$C,obColType(a0)
		jsr	(ObjectMoveAndFall).l
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		addq.b	#2,obRoutine(a0)
		bchg	#0,obStatus(a0)
.return:	rts
; ===========================================================================

Obj4F_Main:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Obj4F_SubIndex(pc,d0.w),d1
		jsr	Obj4F_SubIndex(pc,d1.w)
		lea	Ani_obj4F(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ===========================================================================
Obj4F_SubIndex:	dc.w Obj4F_MoveLeft-Obj4F_SubIndex
		dc.w Obj4F_ChkFloor-Obj4F_SubIndex
; ===========================================================================
; loc_15E58:
Obj4F_MoveLeft:
		subq.w	#1,objoff_30(a0)		; is Redz not moving?
		bpl.s	locret_15E7A			; if not, branch
		addq.b	#2,ob2ndRout(a0)
		move.w	#-$80,obVelX(a0)
		move.b	#1,obAnim(a0)
		bchg	#0,obStatus(a0)
		bne.s	locret_15E7A
		neg.w	obVelX(a0)

locret_15E7A:
		rts
; ===========================================================================
; loc_15E7C:
Obj4F_ChkFloor:
		jsr	(ObjectMove).l
		jsr	(ObjHitFloor).l
		cmpi.w	#-8,d1
		blt.s	Obj4F_StopMoving
		cmpi.w	#$C,d1
		bge.s	Obj4F_StopMoving
		add.w	d1,obY(a0)
		rts
; ---------------------------------------------------------------------------
; loc_15E98:
Obj4F_StopMoving:
		subq.b	#2,ob2ndRout(a0)
		move.w	#60-1,objoff_30(a0)		; pause for 1 second
		clr.w	obVelX(a0)
		clr.b	obAnim(a0)
		rts
; ===========================================================================

Obj4F_Delete:
		jmp	(DeleteObject).l
; ===========================================================================
; animation script
Ani_obj4F:	dc.w byte_15EB8-Ani_obj4F
		dc.w byte_15EBB-Ani_obj4F
byte_15EB8:	dc.b   9,  1,$FF
byte_15EBB:	dc.b   9,  0,  1,  2,  1,$FF,  0
; ---------------------------------------------------------------------------
; Sprite mappings - Redz (dinosaur badnik) from HPZ
; ---------------------------------------------------------------------------
Map_obj4F:	binclude	"mappings/sprite/obj4F.bin"
		even
; ---------------------------------------------------------------------------
; Object 50 - Aquis badnik from HPZ
;----------------------------------------------------------------------------

Obj50:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj50_Index(pc,d0.w),d1
		jmp	Obj50_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj50_Index:	dc.w Obj50_Init-Obj50_Index
		dc.w loc_15FDA-Obj50_Index
		dc.w loc_16006-Obj50_Index
		dc.w loc_16030-Obj50_Index
		dc.w Obj50_Routine08-Obj50_Index
		dc.w Obj50_Routine0A-Obj50_Index
; ---------------------------------------------------------------------------

Obj50_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj50,obMap(a0)
		move.w	#make_art_tile(ArtTile_Aquis,1,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$A,obColType(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.w	#-$100,obVelX(a0)
		move.b	obSubtype(a0),d0
		move.b	d0,d1
		andi.w	#$F0,d1
		lsl.w	#4,d1
		move.w	d1,objoff_2E(a0)
		move.w	d1,objoff_30(a0)
		andi.w	#$F,d0
		lsl.w	#4,d0
		subq.w	#1,d0
		move.w	d0,objoff_32(a0)
		move.w	d0,objoff_34(a0)
		move.w	obY(a0),objoff_2A(a0)
		jsr	(FindFreeObj).l
		bne.s	loc_15FDA
		_move.b	#id_Obj50,obID(a1)
		move.b	#4,obRoutine(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		addi.w	#$A,obX(a1)
		subq.w	#6,obY(a1)	; addi #-6 to subq #6
		move.l	#Map_Obj50,obMap(a1)
		move.w	#make_art_tile(ArtTile_Aquis_Child,1,0),obGfx(a1)
		ori.b	#4,obRender(a1)
		move.w	#$180,obPriority(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	#3,obAnim(a1)
		move.l	a1,objoff_36(a0)
		move.l	a0,objoff_36(a1)
		bset	#6,obStatus(a0)

loc_15FDA:
		lea	Ani_Obj50(pc),a1
		jsr	(AnimateSprite).l
		move.w	#$39C,(v_waterpos1).w
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Obj50_SubIndex(pc,d0.w),d1
		jsr	Obj50_SubIndex(pc,d1.w)
		bsr.w	sub_161D8
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------
Obj50_SubIndex:	dc.w loc_16046-Obj50_SubIndex
		dc.w loc_16058-Obj50_SubIndex
		dc.w loc_16066-Obj50_SubIndex
; ---------------------------------------------------------------------------

loc_16006:
		movea.l	objoff_36(a0),a1
		tst.b	obID(a1)
		beq.w	loc_1639A
		cmpi.b	#id_Obj50,obID(a1)
		bne.w	loc_1639A
		btst	#7,obStatus(a1)
		bne.w	loc_1639A
		lea	(Ani_Obj50).l,a1
		jsr	(AnimateSprite).l
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_16030:
		bsr.w	loc_162FC
		jsr	(ObjectMove).l
		lea	(Ani_Obj50).l,a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------

loc_16046:
		jsr	(ObjectMove).l
		bsr.w	sub_162DE
		bsr.w	sub_16184
		tst.b	objoff_2C(a0)
		beq.s	loc_16168.return
		move.w	(v_player+obX).w,d0
		move.w	(v_player+obY).w,d1
		sub.w	obY(a0),d1
		bpl.s	loc_16168.return
		cmpi.w	#-$30,d1
		blt.s	loc_16168.return
		sub.w	obX(a0),d0
		cmpi.w	#$48,d0
		bgt.s	loc_16168.return
		cmpi.w	#-$48,d0
		blt.s	loc_16168.return
		tst.w	d0
		bpl.s	loc_1615A
		cmpi.w	#-$28,d0
		bgt.s	loc_16168.return
		btst	#0,obStatus(a0)
		bne.s	loc_16168.return
		bra.s	loc_16168
; ---------------------------------------------------------------------------

loc_1615A:
		cmpi.w	#$28,d0
		blt.s	loc_16168.return
		btst	#0,obStatus(a0)
		beq.s	loc_16168.return

loc_16168:
		moveq	#$20,d0
		cmp.w	objoff_32(a0),d0
		bgt.s	.return
		move.b	#4,ob2ndRout(a0)
		move.b	#1,obAnim(a0)
		move.w	#-$400,obVelY(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_16058:
		jsr	(ObjectMove).l
		bsr.w	sub_162DE
		move.w	obY(a0),d0
		tst.b	objoff_2C(a0)
		bne.s	loc_161C4
		cmp.w	(v_waterpos1).w,d0
		bgt.s	.return
		subq.b	#2,ob2ndRout(a0)
		st	objoff_2C(a0)
		clr.w	obVelY(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_161C4:
		cmp.w	objoff_2A(a0),d0
		blt.s	loc_16058.return
		subq.b	#2,ob2ndRout(a0)
		sf	objoff_2C(a0)
		clr.w	obVelY(a0)
		rts
; ---------------------------------------------------------------------------

loc_16066:
		jsr	(ObjectMoveAndFall).l
		bsr.w	sub_162DE
		bsr.w	sub_16078
		move.w	obY(a0),d0
		cmp.w	(v_waterpos1).w,d0
		blt.s	.return
		move.b	#2,ob2ndRout(a0)
		clr.b	obAnim(a0)
		move.w	objoff_30(a0),objoff_2E(a0)
		move.w	#$40,obVelY(a0)
		sf	objoff_2D(a0)
.return:	rts

; =============== S U B R O U T I N E =======================================


sub_16078:
		tst.b	objoff_2D(a0)
		bne.s	.return
		tst.w	obVelY(a0)
		bpl.s	loc_16086
.return:	rts
; ---------------------------------------------------------------------------

loc_16086:
		st	objoff_2D(a0)
		jsr	(FindFreeObj).l
		bne.s	locret_160F2
		_move.b	#id_Obj50,obID(a1)
		move.b	#6,obRoutine(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.l	#Map_Obj50,obMap(a1)
		move.w	#make_art_tile(ArtTile_Aquis_Child,1,0),obGfx(a1)
		ori.b	#4,obRender(a1)
		move.w	#$180,obPriority(a1)
		move.b	#$E5,obColType(a1)
		move.b	#2,obAnim(a1)
		move.w	#$C,d0
		move.w	#$10,d1
		move.w	#-$300,d2
		btst	#0,obStatus(a0)
		beq.s	loc_160E6
		neg.w	d1
		neg.w	d2

loc_160E6:
		sub.w	d0,obY(a1)
		sub.w	d1,obX(a1)
		move.w	d2,obVelX(a1)

locret_160F2:
		rts
; End of function sub_16078


; =============== S U B R O U T I N E =======================================


sub_16184:
		subq.w	#1,objoff_2E(a0)
		bne.s	.return
		move.w	objoff_30(a0),objoff_2E(a0)
		addq.b	#2,ob2ndRout(a0)
		move.w	#-$40,d0
		tst.b	objoff_2C(a0)
		beq.s	+
		neg.w	d0
+		move.w	d0,obVelY(a0)

.return:
		rts
; End of function sub_16184


; =============== S U B R O U T I N E =======================================


sub_161D8:
		moveq	#$A,d0
		moveq	#-6,d1
		movea.l	objoff_36(a0),a1
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obRespawnNo(a0),obRespawnNo(a1)
		move.b	obRender(a0),obRender(a1)
		btst	#0,obStatus(a1)
		beq.s	loc_16208
		neg.w	d0

loc_16208:
		add.w	d0,obX(a1)
		add.w	d1,obY(a1)
		rts
; End of function sub_161D8

; ---------------------------------------------------------------------------

Obj50_Routine08:
		jsr	(ObjectMoveAndFall).l
		bsr.w	sub_16228
		lea	Ani_Obj50(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l

; =============== S U B R O U T I N E =======================================


sub_16228:
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	loc_16242
		add.w	d1,obY(a0)
		move.w	obVelY(a0),d0
		asr.w	#1,d0
		neg.w	d0
		move.w	d0,obVelY(a0)

loc_16242:
		subq.b	#1,obColProp(a0)
		beq.w	loc_1639A
		rts
; End of function sub_16228

; ---------------------------------------------------------------------------

Obj50_Routine0A:
		bsr.w	sub_1629E
		tst.b	ob2ndRout(a0)
		beq.s	.return
		subq.w	#1,objoff_2C(a0)
		beq.w	loc_1639A
		move.w	(v_player+obX).w,obX(a0)
		move.w	(v_player+obY).w,obY(a0)
		addi.w	#$C,obY(a0)
		subq.b	#1,objoff_2A(a0)
		bne.s	loc_16290
		move.b	#3,objoff_2A(a0)
		bchg	#0,obStatus(a0)
		bchg	#0,obRender(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_16290:
		lea	Ani_Obj50(pc),a1
		jsr	(AnimateSprite).l
		jmp	(DisplaySprite).l

; =============== S U B R O U T I N E =======================================


sub_1629E:
		tst.b	ob2ndRout(a0)
		bne.s	.return
		move.b	(v_player+obRoutine).w,d0
		cmpi.b	#2,d0
		bne.s	.return
		move.w	(v_player+obX).w,obX(a0)
		move.w	(v_player+obY).w,obY(a0)
		ori.b	#4,obRender(a0)
		move.w	#$80,obPriority(a0)
		move.b	#5,obAnim(a0)
		st	ob2ndRout(a0)
		move.w	#$12C,objoff_2C(a0)
		move.b	#3,objoff_2A(a0)
.return:	rts
; End of function sub_1629E


; =============== S U B R O U T I N E =======================================


sub_162DE:
		subq.w	#1,objoff_32(a0)
		bpl.s	.return
		move.w	objoff_34(a0),objoff_32(a0)
		neg.w	obVelX(a0)
		bchg	#0,obStatus(a0)
		move.b	#1,obPrevAni(a0)

.return:
		rts
; End of function sub_162DE

; ---------------------------------------------------------------------------

loc_162FC:
		tst.b	obColProp(a0)
		beq.w	sub_162DE.return
		moveq	#2,d3

loc_16306:
		jsr	(FindFreeObj).l
		bne.s	loc_16378
		_move.b	obID(a0),obID(a1)
		move.b	#8,obRoutine(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.l	obMap(a0),obMap(a1)
		move.w	#make_art_tile(ArtTile_Aquis_Child,1,0),obGfx(a1)
		ori.b	#4,obRender(a1)
		move.w	#$180,obPriority(a1)
		move.w	#-$100,obVelY(a1)
		move.b	#4,obAnim(a1)
		move.b	#$78,obColProp(a1)
		cmpi.w	#1,d3
		beq.s	loc_16372
		blt.s	loc_16364
		move.w	#$C0,obVelX(a1)
		subi.w	#$C0,obVelY(a1)
		bra.s	loc_16378
; ---------------------------------------------------------------------------

loc_16364:
		move.w	#-$100,obVelX(a1)
		subi.w	#$40,obVelY(a1)
		bra.s	loc_16378
; ---------------------------------------------------------------------------

loc_16372:
		move.w	#$40,obVelX(a1)

loc_16378:
		dbf	d3,loc_16306
		jsr	(FindFreeObj).l
		bne.s	loc_1639A
		_move.b	obID(a0),obID(a1)
		move.b	#$A,obRoutine(a1)
		move.l	obMap(a0),obMap(a1)
		move.w	#make_art_tile(ArtTile_Aquis_Child,1,0),obGfx(a1)

loc_1639A:
		jmp	(DeleteObject).l
; ---------------------------------------------------------------------------
Ani_Obj50:	dc.w byte_163B0-Ani_Obj50
		dc.w byte_163B3-Ani_Obj50
		dc.w byte_163BB-Ani_Obj50
		dc.w byte_163C1-Ani_Obj50
		dc.w byte_163C5-Ani_Obj50
		dc.w byte_163C8-Ani_Obj50
		dc.w byte_163CB-Ani_Obj50
		dc.w byte_163CF-Ani_Obj50
byte_163B0:	dc.b  $E,  0,$FF
byte_163B3:	dc.b   5,  3,  4,  3,  4,  3,  4,$FF
byte_163BB:	dc.b   3,  5,  6,  7,  6,$FF
byte_163C1:	dc.b   3,  1,  2,$FF
byte_163C5:	dc.b   1,  5,$FF
byte_163C8:	dc.b  $E,  8,$FF
byte_163CB:	dc.b   1,  9, $A,$FF
byte_163CF:	dc.b   5, $B, $C, $B, $C, $B, $C,$FF
		even
Map_Obj50:	dc.w word_163F2-Map_Obj50
		dc.w word_1640C-Map_Obj50
		dc.w word_16416-Map_Obj50
		dc.w word_16420-Map_Obj50
		dc.w word_16442-Map_Obj50
		dc.w word_16464-Map_Obj50
		dc.w word_1646E-Map_Obj50
		dc.w word_16478-Map_Obj50
		dc.w word_16482-Map_Obj50
		dc.w word_1648C-Map_Obj50
		dc.w word_164AE-Map_Obj50
		dc.w word_164D0-Map_Obj50
		dc.w word_164FA-Map_Obj50
word_163F2:	dc.w 3
		dc.w $E80D,    0,    0,$FFF0		; 0
		dc.w $F809,  $16,   $B,$FFF8		; 4
		dc.w  $805,  $24,  $12,$FFF8		; 8
word_1640C:	dc.w 1
		dc.w $F805,  $28,  $14,$FFF8		; 0
word_16416:	dc.w 1
		dc.w $F805,  $2C,  $16,$FFF8		; 0
word_16420:	dc.w 4
		dc.w $E809,    8,    4,$FFF0		; 0
		dc.w $E801,   $E,    7,	   8		; 4
		dc.w $F809,  $16,   $B,$FFF8		; 8
		dc.w  $805,  $24,  $12,$FFF8		; 12
word_16442:	dc.w 4
		dc.w $E809,  $10,    8,$FFF0		; 0
		dc.w $E801,   $E,    7,	   8		; 4
		dc.w $F809,  $16,   $B,$FFF8		; 8
		dc.w  $805,  $24,  $12,$FFF8		; 12
word_16464:	dc.w 1
		dc.w $F801,  $30,  $18,$FFFC		; 0
word_1646E:	dc.w 1
		dc.w $F801,  $32,  $19,$FFFC		; 0
word_16478:	dc.w 1
		dc.w $F801,  $34,  $1A,$FFFC		; 0
word_16482:	dc.w 1
		dc.w $F80D,  $36,  $1B,$FFF0		; 0
word_1648C:	dc.w 4
		dc.w $E80D,    0,    0,$FFF0		; 0
		dc.w $F805,  $1C,   $E,$FFF8		; 4
		dc.w $F801,  $20,  $10,	   8		; 8
		dc.w  $805,  $24,  $12,$FFF8		; 12
word_164AE:	dc.w 4
		dc.w $E80D,    0,    0,$FFF0		; 0
		dc.w $F805,  $1C,   $E,$FFF8		; 4
		dc.w $F801,  $22,  $11,	   8		; 8
		dc.w  $805,  $24,  $12,$FFF8		; 12
word_164D0:	dc.w 5
		dc.w $E809,    8,    4,$FFF0		; 0
		dc.w $E801,   $E,    7,	   8		; 4
		dc.w $F805,  $1C,   $E,$FFF8		; 8
		dc.w $F801,  $20,  $10,	   8		; 12
		dc.w  $805,  $24,  $12,$FFF8		; 16
word_164FA:	dc.w 5
		dc.w $E809,  $10,    8,$FFF0		; 0
		dc.w $E801,   $E,    7,	   8		; 4
		dc.w $F805,  $1C,   $E,$FFF8		; 8
		dc.w $F801,  $22,  $11,	   8		; 12
		dc.w  $805,  $24,  $12,$FFF8		; 16
		even
; ---------------------------------------------------------------------------
; Object 51 - Aquis badnik from HPZ
; ---------------------------------------------------------------------------

Obj51:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	off_16532(pc,d0.w),d1
		jmp	off_16532(pc,d1.w)
; ---------------------------------------------------------------------------
off_16532:	dc.w loc_1653E-off_16532
		dc.w loc_1659C-off_16532
		dc.w loc_165C0-off_16532
		dc.w 0
		dc.w Obj50_Routine08-off_16532
		dc.w Obj50_Routine0A-off_16532
; ---------------------------------------------------------------------------

loc_1653E:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj50,obMap(a0)
		move.w	#make_art_tile(ArtTile_Aquis,1,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$A,obColType(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.b	#6,obAnim(a0)
		move.b	obSubtype(a0),d0
		andi.w	#$F,d0
		move.w	d0,d1
		lsl.w	#5,d1
		subq.w	#1,d1
		move.w	d1,objoff_32(a0)
		move.w	d1,objoff_34(a0)
		move.w	obY(a0),objoff_2A(a0)
		move.w	obY(a0),objoff_2E(a0)
		addi.w	#$60,objoff_2E(a0)
		move.w	#-$100,obVelX(a0)

loc_1659C:
		lea	Ani_Obj50(pc),a1
		jsr	(AnimateSprite).l
		move.w	#$39C,(v_waterpos1).w
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	off_165BC(pc,d0.w),d1
		jsr	off_165BC(pc,d1.w)
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------
off_165BC:	dc.w loc_165D4-off_165BC
		dc.w loc_165EA-off_165BC
; ---------------------------------------------------------------------------

loc_165C0:
		bsr.w	loc_162FC
		jsr	(ObjectMove).l
		lea	Ani_Obj50(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------

loc_165D4:
		jsr	(ObjectMove).l
		bsr.w	sub_162DE
		bsr.w	loc_16626
		bsr.w	loc_16708
		bra.w	loc_16678
; ---------------------------------------------------------------------------

loc_165EA:
		jsr	(ObjectMove).l
		bsr.w	sub_162DE
		bsr.w	loc_16626
		bsr.w	loc_16708
		bra.w	loc_16600
; ---------------------------------------------------------------------------

loc_16600:
		subq.w	#1,objoff_30(a0)
		beq.s	loc_16614
		move.w	objoff_30(a0),d0
		cmpi.w	#$12,d0
		beq.w	loc_1669E
		rts
; ---------------------------------------------------------------------------

loc_16614:
		subq.b	#2,ob2ndRout(a0)
		move.b	#6,obAnim(a0)
		move.w	#180,objoff_30(a0)
		rts
; ---------------------------------------------------------------------------

loc_16626:
		sf	objoff_2D(a0)
		sf	objoff_2C(a0)
		sf	objoff_36(a0)
		move.w	(v_player+obX).w,d0
		sub.w	obX(a0),d0
		bpl.s	loc_16646
		btst	#0,obStatus(a0)
		bne.s	loc_1664E
		bra.s	loc_16652
; ---------------------------------------------------------------------------

loc_16646:
		btst	#0,obStatus(a0)
		bne.s	loc_16652

loc_1664E:
		st	objoff_2C(a0)

loc_16652:
		move.w	(v_player+obY).w,d0
		sub.w	obY(a0),d0
		cmpi.w	#-4,d0
		blt.s	.return
		cmpi.w	#4,d0
		bgt.s	loc_16672
		st	objoff_2D(a0)
		clr.w	obVelY(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_16672:
		st	objoff_36(a0)
		rts
; ---------------------------------------------------------------------------

loc_16678:
		tst.b	objoff_2C(a0)
		bne.s	.return
		subq.w	#1,objoff_30(a0)
		bgt.s	.return
		tst.b	objoff_2D(a0)
		beq.s	.return
		move.b	#7,obAnim(a0)
		move.w	#$24,objoff_30(a0)
		addq.b	#2,ob2ndRout(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_1669E:
		jsr	(FindFreeObj).l
		bne.s	.return
		_move.b	#id_Obj51,obID(a1)
		move.b	#4,obRoutine(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.l	#Map_Obj50,obMap(a1)
		move.w	#make_art_tile(ArtTile_Aquis_Child,1,0),obGfx(a1)
		ori.b	#4,obRender(a1)
		move.w	#$180,obPriority(a1)
		move.b	#2,obAnim(a1)
		move.b	#$E5,obColType(a1)
		move.w	#$C,d0
		move.w	#$10,d1
		move.w	#-$300,d2
		btst	#0,obStatus(a0)
		beq.s	+
		neg.w	d1
		neg.w	d2
+		sub.w	d0,obY(a1)
		sub.w	d1,obX(a1)
		move.w	d2,obVelX(a1)

.return:
		rts
; ---------------------------------------------------------------------------

loc_16708:
		tst.b	objoff_2D(a0)
		bne.s	.return
		tst.b	objoff_36(a0)
		beq.s	loc_16738
		move.w	objoff_2E(a0),d0
		cmp.w	obY(a0),d0
		ble.s	loc_1675C
		tst.b	objoff_2C(a0)
		beq.s	loc_16730
		move.w	objoff_2A(a0),d0
		cmp.w	obY(a0),d0
		bge.s	loc_1675C
.return:	rts
; ---------------------------------------------------------------------------

loc_16730:
		move.w	#$180,obVelY(a0)
		rts
; ---------------------------------------------------------------------------

loc_16738:
		move.w	objoff_2A(a0),d0
		cmp.w	obY(a0),d0
		bge.s	loc_1675C
		tst.b	objoff_2C(a0)
		beq.s	loc_16754
		move.w	objoff_2E(a0),d0
		cmp.w	obY(a0),d0
		ble.s	loc_1675C
		rts
; ---------------------------------------------------------------------------

loc_16754:
		move.w	#-$180,obVelY(a0)
		rts
; ---------------------------------------------------------------------------

loc_1675C:
		move.w	d0,obY(a0)
		clr.w	obVelY(a0)
		rts
; ---------------------------------------------------------------------------

; ===========================================================================
; ---------------------------------------------------------------------------
; Object 4B - Buzzer from EHZ
; ---------------------------------------------------------------------------

Obj4B:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj4B_Index(pc,d0.w),d1
		jmp	Obj4B_Index(pc,d1.w)
; ===========================================================================
Obj4B_Index:	dc.w Obj4B_Init-Obj4B_Index
		dc.w Obj4B_Main-Obj4B_Index
		dc.w Obj4B_Flame-Obj4B_Index
		dc.w Obj4B_Projectile-Obj4B_Index
; ===========================================================================
; loc_167AA:
Obj4B_Projectile:
		jsr	(ObjectMove).l
		lea	Ani_obj4B(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ===========================================================================
; loc_167BC:
Obj4B_Flame:
		movea.l	objoff_2A(a0),a1
		tst.b	(a1)
		beq.w	loc_17854
		tst.w	objoff_30(a1)
		bmi.s	loc_167CE
		rts
; ---------------------------------------------------------------------------

loc_167CE:
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		move.b	obStatus(a1),obStatus(a0)
		move.b	obRender(a1),obRender(a0)
		lea	Ani_obj4B(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ===========================================================================

Obj4B_Init:
		move.l	#Map_obj4B,obMap(a0)
		move.w	#make_art_tile(ArtTile_Buzzer,0,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$A,obColType(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#$18,obWidth(a0)
		move.w	#$180,obPriority(a0)
		addq.b	#2,obRoutine(a0)		; => Obj4B_Main

		; load exhaust flame object
		jsr	(FindNextFreeObj).l
		bne.s	locret_1689E

		_move.b	#id_Obj4B,obID(a1)			; load obj4B
		move.b	#4,obRoutine(a1)		; => Obj4B_Flame
		move.l	#Map_obj4B,obMap(a1)
		move.w	#make_art_tile(ArtTile_Buzzer,0,0),obGfx(a1)
		move.w	#$200,obPriority(a1)
		move.b	#$10,obActWid(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obRender(a0),obRender(a1)
		move.b	#1,obAnim(a1)
		move.l	a0,objoff_2A(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	#$100,objoff_2E(a0)
		move.w	#-$100,obVelX(a0)
		btst	#0,obRender(a0)
		beq.s	locret_1689E
		neg.w	obVelX(a0)

locret_1689E:
		rts
; ===========================================================================

Obj4B_Main:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Obj4B_Main_Index(pc,d0.w),d1
		jsr	Obj4B_Main_Index(pc,d1.w)
		lea	Ani_obj4B(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ===========================================================================
Obj4B_Main_Index:	dc.w Obj4B_Roaming-Obj4B_Main_Index
			dc.w Obj4B_Shooting-Obj4B_Main_Index
; ===========================================================================
; loc_168C0:
Obj4B_Roaming:
		bsr.w	Obj4B_ChkPlayers
		subq.w	#1,objoff_30(a0)
		move.w	objoff_30(a0),d0
		cmpi.w	#15,d0
		beq.s	Obj4B_TurnAround
		tst.w	d0
		bpl.s	locret_168E4
		subq.w	#1,objoff_2E(a0)
		jgt	(ObjectMove).l
		move.w	#30,objoff_30(a0)

locret_168E4:
		rts
; ---------------------------------------------------------------------------
; loc_168E6:
Obj4B_TurnAround:
		sf	objoff_32(a0)			; reenable shooting
		neg.w	obVelX(a0)			; reverse movement direction
		bchg	#0,obRender(a0)
		bchg	#0,obStatus(a0)
		move.w	#$100,objoff_2E(a0)
		rts

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; sub_16902:
Obj4B_ChkPlayers:
		tst.b	objoff_32(a0)
		bne.w	locret_1694E			; branch, if shooting is disabled
		move.w	obX(a0),d0
		sub.w	(v_player+obX).w,d0		; a1=character
		move.w	d0,d1
		bpl.s	loc_16918
		neg.w	d0

loc_16918:
		; test if player is inside an 8 pixel wide strip
		cmpi.w	#$28,d0
		blt.s	locret_1694E
		cmpi.w	#$30,d0
		bgt.s	locret_1694E

		tst.w	d1				; test sign of distance
		bpl.s	Obj4B_PlayerIsLeft		; branch, if player is left from object
		btst	#0,obRender(a0)
		beq.s	locret_1694E			; branch, if object is facing right
		bra.s	Obj4B_ReadyToShoot
; ---------------------------------------------------------------------------
; loc_16932:
Obj4B_PlayerIsLeft:
		btst	#0,obRender(a0)
		bne.s	locret_1694E			; branch, if object is facing left
; loc_1693A:
Obj4B_ReadyToShoot:
		st	objoff_32(a0)			; disable shooting
		addq.b	#2,ob2ndRout(a0)		; => Obj4B_Shooting
		move.b	#3,obAnim(a0)			; play shooting animation
		move.w	#$32,objoff_34(a0)

locret_1694E:
		rts
; End of function Obj4B_ChkPlayers

; ===========================================================================
; loc_16950:
Obj4B_Shooting:
		move.w	objoff_34(a0),d0		; get timer value
		subq.w	#1,d0				; decrement
		blt.s	Obj4B_DoneShooting		; branch, if timer has expired
		move.w	d0,objoff_34(a0)		; update timer value
		cmpi.w	#$14,d0				; has timer reached a certain value?
		beq.s	Obj4B_ShootProjectile		; if yes, branch
		rts
; ===========================================================================
; loc_16964:
Obj4B_DoneShooting:
		subq.b	#2,ob2ndRout(a0)		; => Obj4B_Roaming
		rts
; ===========================================================================
; loc_1696A:
Obj4B_ShootProjectile:
		jsr	(FindNextFreeObj).l
		bne.s	locret_169D8

		_move.b	#id_Obj4B,obID(a1)			; load obj4B
		move.b	#6,obRoutine(a1)		; => Obj4B_Projectile
		move.l	#Map_obj4B,obMap(a1)
		move.w	#make_art_tile(ArtTile_Buzzer,0,0),obGfx(a1)
		move.w	#$200,obPriority(a1)
		move.b	#$98,obColType(a1)
		move.b	#$10,obActWid(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obRender(a0),obRender(a1)
		move.b	#2,obAnim(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	#13,d0				; absolute horizontal offset for stinger
		move.w	#$180,obVelY(a1)
		move.w	#-$180,obVelX(a1)
		btst	#0,obRender(a1)			; is object facing left?
		beq.s	locret_169D8			; if not, branch
		neg.w	obVelX(a1)			; move in other direction
		neg.w	d0				; make offset negative

locret_169D8:
		add.w	d0,obX(a1)			; align horizontally with stinger
		rts
; ===========================================================================
; animation script
; off_169DA:
Ani_obj4B:	dc.w byte_169E2-Ani_obj4B
		dc.w byte_169E5-Ani_obj4B
		dc.w byte_169E9-Ani_obj4B
		dc.w byte_169ED-Ani_obj4B
byte_169E2:	dc.b  $F,  0,$FF
byte_169E5:	dc.b   2,  3,  4,$FF
byte_169E9:	dc.b   3,  5,  6,$FF
byte_169ED:	dc.b   9,  1,  1,  1,  1,  1,$FD,  0,  0
		even
; ---------------------------------------------------------------------------
; Sprite mappings
; ---------------------------------------------------------------------------
Map_obj4B:	binclude	"mappings/sprite/obj4B.bin"
		even
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 4A - Octus badnik - TODO
; ---------------------------------------------------------------------------

Obj4A:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj4A_Index(pc,d0.w),d1
		jmp	Obj4A_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj4A_Index:	dc.w loc_16ADE-Obj4A_Index
		dc.w loc_16B44-Obj4A_Index
		dc.w loc_16AD2-Obj4A_Index
		dc.w loc_16AB6-Obj4A_Index
; ---------------------------------------------------------------------------

loc_16AB6:
		subq.w	#1,objoff_2C(a0)
		bmi.s	loc_16AC0
		rts
; ---------------------------------------------------------------------------

loc_16AC0:
		jsr	(ObjectMoveAndFall).l
		lea	Ani_Obj4A(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------

loc_16AD2:
		subq.w	#1,objoff_2C(a0)
		beq.w	loc_17854
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_16ADE:
		move.l	#Map_Obj4A,obMap(a0)
		move.w	#make_art_tile(ArtTile_Octus,1,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$A,obColType(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#8,obWidth(a0)
		jsr	(ObjectMoveAndFall).l
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	loc_16B3C
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		addq.b	#2,obRoutine(a0)
		move.w	obX(a0),d0
		sub.w	(v_player+obX).w,d0
		bpl.s	loc_16B3C
		bchg	#0,obStatus(a0)

loc_16B3C:
		move.w	obY(a0),objoff_2A(a0)
		rts
; ---------------------------------------------------------------------------

loc_16B44:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Obj4A_SubIndex(pc,d0.w),d1
		jsr	Obj4A_SubIndex(pc,d1.w)
		lea	Ani_Obj4A(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------
Obj4A_SubIndex:	dc.w Obj4A_Init-Obj4A_SubIndex
		dc.w Obj4A_Main-Obj4A_SubIndex
		dc.w loc_16BAA-Obj4A_SubIndex
		dc.w loc_16C7C-Obj4A_SubIndex
; ---------------------------------------------------------------------------

Obj4A_Init:
		move.w	obX(a0),d0
		sub.w	(v_player+obX).w,d0
		cmpi.w	#$80,d0
		bgt.s	locret_16B86
		cmpi.w	#-$80,d0
		blt.s	locret_16B86
		addq.b	#2,ob2ndRout(a0)
		move.b	#1,obAnim(a0)

locret_16B86:
		rts
; ---------------------------------------------------------------------------

Obj4A_Main:
		subi.l	#$18000,obY(a0)
		move.w	objoff_2A(a0),d0
		sub.w	obY(a0),d0
		cmpi.w	#$20,d0
		ble.s	locret_16BA8
		addq.b	#2,ob2ndRout(a0)
		clr.w	objoff_2C(a0)

locret_16BA8:
		rts
; ---------------------------------------------------------------------------

loc_16BAA:
		subq.w	#1,objoff_2C(a0)
		beq.w	loc_16C76
		bpl.w	locret_16C74
		move.w	#30,objoff_2C(a0)
		jsr	(FindFreeObj).l
		bne.s	loc_16C10
		_move.b	#id_Obj4A,obID(a1)
		move.b	#4,obRoutine(a1)
		move.l	#Map_Obj4A,obMap(a1)
		move.b	#4,obFrame(a1)
		move.w	#make_art_tile(ArtTile_Octus_Child,1,0),obGfx(a1)
		move.w	#$180,obPriority(a1)
		move.b	#$10,obActWid(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	#$1E,objoff_2C(a1)
		move.b	obRender(a0),obRender(a1)
		move.b	obStatus(a0),obStatus(a1)

loc_16C10:
		jsr	(FindFreeObj).l
		bne.s	locret_16C74
		_move.b	#id_Obj4A,obID(a1)
		move.b	#6,obRoutine(a1)
		move.l	#Map_Obj4A,obMap(a1)
		move.w	#make_art_tile(ArtTile_Octus_Child,1,0),obGfx(a1)
		move.w	#$200,obPriority(a1)
		move.b	#$10,obActWid(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	#$F,objoff_2C(a1)
		move.b	obRender(a0),obRender(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	#2,obAnim(a1)
		move.w	#-$580,obVelX(a1)
		btst	#0,obRender(a1)
		beq.s	locret_16C74
		neg.w	obVelX(a1)

locret_16C74:
		rts
; ---------------------------------------------------------------------------

loc_16C76:
		addq.b	#2,ob2ndRout(a0)
		rts
; ---------------------------------------------------------------------------

loc_16C7C:
		move.w	#-6,d0
		btst	#0,obRender(a0)
		beq.s	loc_16C8A
		neg.w	d0

loc_16C8A:
		add.w	d0,obX(a0)
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------
Ani_Obj4A:	dc.w byte_16C98-Ani_Obj4A
		dc.w byte_16C9B-Ani_Obj4A
		dc.w byte_16CA0-Ani_Obj4A
byte_16C98:	dc.b  $F,  0,$FF			; 0
byte_16C9B:	dc.b   3,  1,  2,  3,$FF		; 0
byte_16CA0:	dc.b   2,  5,  6,$FF			; 0
		even

Map_Obj4A:	dc.w word_16CB2-Map_Obj4A
		dc.w word_16CC4-Map_Obj4A
		dc.w word_16CDE-Map_Obj4A
		dc.w word_16CF8-Map_Obj4A
		dc.w word_16D12-Map_Obj4A
		dc.w word_16D1C-Map_Obj4A
		dc.w word_16D26-Map_Obj4A
word_16CB2:	dc.w 2
		dc.w $F00D,    0,    0,$FFF0		; 0
		dc.w	$D,    8,    4,$FFF0		; 4
word_16CC4:	dc.w 3
		dc.w $F00D,    0,    0,$FFF0		; 0
		dc.w	 9,  $10,    8,$FFE8		; 4
		dc.w	 9,  $16,   $B,	   0		; 8
word_16CDE:	dc.w 3
		dc.w $F00D,    0,    0,$FFF0		; 0
		dc.w	 9,  $1C,   $E,$FFE8		; 4
		dc.w	 9,  $22,  $11,	   0		; 8
word_16CF8:	dc.w 3
		dc.w $F00D,    0,    0,$FFF0		; 0
		dc.w	 9,  $28,  $14,$FFE8		; 4
		dc.w	 9,  $2E,  $17,	   0		; 8
word_16D12:	dc.w 1
		dc.w $F001,  $34,  $1A,$FFF7		; 0
word_16D1C:	dc.w 1
		dc.w $F201,  $36,  $1B,$FFF0		; 0
word_16D26:	dc.w 1
		dc.w $F201,  $38,  $1C,$FFF0		; 0
		even
;----------------------------------------------------------------------------
; Object 4C - BBat badnik from HPZ
;----------------------------------------------------------------------------

Obj4C:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj4C_Index(pc,d0.w),d1
		jmp	Obj4C_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj4C_Index:	dc.w Obj4C_Init-Obj4C_Index
		dc.w loc_16DA2-Obj4C_Index
		dc.w loc_16E10-Obj4C_Index
; ---------------------------------------------------------------------------

Obj4C_Init:
		move.l	#Map_Obj4C,obMap(a0)
		move.w	#make_art_tile(ArtTile_BBat,0,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$A,obColType(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#8,obWidth(a0)
		addq.b	#2,obRoutine(a0)
		move.w	obY(a0),objoff_2E(a0)
		rts
; ---------------------------------------------------------------------------

loc_16DA2:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Obj4C_SubIndex(pc,d0.w),d1
		jsr	Obj4C_SubIndex(pc,d1.w)
		bsr.w	sub_16DC8
		lea	Ani_Obj4C(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------
Obj4C_SubIndex:	dc.w loc_16F2E-Obj4C_SubIndex
		dc.w loc_16F66-Obj4C_SubIndex
		dc.w loc_16F72-Obj4C_SubIndex

; =============== S U B R O U T I N E =======================================


sub_16DC8:
		move.b	objoff_3F(a0),d0
		jsr	(CalcSine).l
		asr.w	#6,d0
		add.w	objoff_2E(a0),d0
		move.w	d0,obY(a0)
		addq.b	#4,objoff_3F(a0)
		rts
; End of function sub_16DC8


; =============== S U B R O U T I N E =======================================


sub_16DE2:
		move.w	obX(a0),d0
		sub.w	(v_player+obX).w,d0
		cmpi.w	#$80,d0
		bgt.s	locret_16E0E
		cmpi.w	#-$80,d0
		blt.s	locret_16E0E
		move.b	#4,ob2ndRout(a0)
		move.b	#2,obAnim(a0)
		move.w	#8,objoff_2A(a0)
		clr.b	objoff_3E(a0)

locret_16E0E:
		rts
; End of function sub_16DE2

; ---------------------------------------------------------------------------

loc_16E10:
		bsr.w	sub_16F0E
		bsr.w	sub_16EB0
		bsr.w	sub_16E30
		jsr	(ObjectMove).l
		lea	Ani_Obj4C(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l

; =============== S U B R O U T I N E =======================================


sub_16E30:
		tst.b	objoff_3D(a0)
		beq.s	locret_16E42
		bset	#0,obRender(a0)
		bset	#0,obStatus(a0)

locret_16E42:
		rts
; End of function sub_16E30


; =============== S U B R O U T I N E =======================================


sub_16E44:
		subq.w	#1,objoff_2C(a0)
		bpl.s	locret_16E8E
		move.w	obX(a0),d0
		sub.w	(v_player+obX).w,d0
		cmpi.w	#$60,d0
		bgt.s	loc_16E90
		cmpi.w	#-$60,d0
		blt.s	loc_16E90
		tst.w	d0
		bpl.s	loc_16E68
		st	objoff_3D(a0)

loc_16E68:
		move.b	#$40,objoff_3F(a0)
		move.w	#$400,obInertia(a0)
		move.b	#4,obRoutine(a0)
		move.b	#3,obAnim(a0)
		move.w	#$C,objoff_2A(a0)
		move.b	#1,objoff_3E(a0)
		moveq	#0,d0

locret_16E8E:
		rts
; ---------------------------------------------------------------------------

loc_16E90:
		cmpi.w	#$80,d0
		bgt.s	loc_16E9C
		cmpi.w	#-$80,d0
		bgt.s	locret_16E8E

loc_16E9C:
		move.b	#1,obAnim(a0)
		clr.b	ob2ndRout(a0)
		move.w	#$18,objoff_2A(a0)
		rts
; End of function sub_16E44


; =============== S U B R O U T I N E =======================================


sub_16EB0:
		tst.b	objoff_3D(a0)
		bne.s	loc_16ECA
		moveq	#0,d0
		move.b	objoff_3F(a0),d0
		cmpi.w	#$C0,d0
		bge.s	loc_16EDE
		addq.b	#2,d0
		move.b	d0,objoff_3F(a0)
		rts
; ---------------------------------------------------------------------------

loc_16ECA:
		moveq	#0,d0
		move.b	objoff_3F(a0),d0
		cmpi.w	#$C0,d0
		beq.s	loc_16EDE
		subq.b	#2,d0
		move.b	d0,objoff_3F(a0)
		rts
; ---------------------------------------------------------------------------

loc_16EDE:
		sf	objoff_3D(a0)
		clr.b	obAnim(a0)
		move.b	#2,obRoutine(a0)
		clr.b	ob2ndRout(a0)
		move.w	#$18,objoff_2A(a0)
		move.b	#1,obAnim(a0)
		bclr	#0,obRender(a0)
		bclr	#0,obStatus(a0)
		rts
; End of function sub_16EB0


; =============== S U B R O U T I N E =======================================


sub_16F0E:
		move.b	objoff_3F(a0),d0
		jsr	(CalcSine).l
		muls.w	obInertia(a0),d1
		asr.l	#8,d1
		move.w	d1,obVelX(a0)
		muls.w	obInertia(a0),d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)
		rts
; End of function sub_16F0E

; ---------------------------------------------------------------------------

loc_16F2E:
		subq.w	#1,objoff_2A(a0)
		bpl.s	locret_16F64
		bsr.w	sub_16DE2
		beq.s	locret_16F64
		jsr	(RandomNumber).l
		andi.b	#$FF,d0
		bne.s	locret_16F64
		move.w	#$18,objoff_2A(a0)
		move.w	#30,objoff_2C(a0)
		addq.b	#2,ob2ndRout(a0)
		move.b	#1,obAnim(a0)
		clr.b	objoff_3E(a0)

locret_16F64:
		rts
; ---------------------------------------------------------------------------

loc_16F66:
		subq.b	#1,objoff_2A(a0)
		bpl.s	locret_16F70
		subq.b	#2,ob2ndRout(a0)

locret_16F70:
		rts
; ---------------------------------------------------------------------------

loc_16F72:
		bsr.w	sub_16E44
		beq.s	locret_16FB8
		subq.w	#1,objoff_2A(a0)
		bne.s	locret_16FB8
		move.b	objoff_3E(a0),d0
		beq.s	loc_16FA0
		clr.b	objoff_3E(a0)
		move.w	#8,objoff_2A(a0)
		bset	#0,obRender(a0)
		bset	#0,obStatus(a0)
		rts
; ---------------------------------------------------------------------------

loc_16FA0:
		move.b	#1,objoff_3E(a0)
		move.w	#$C,objoff_2A(a0)
		bclr	#0,obRender(a0)
		bclr	#0,obStatus(a0)

locret_16FB8:
		rts
; ---------------------------------------------------------------------------
Ani_Obj4C:	dc.w byte_16FC2-Ani_Obj4C
		dc.w byte_16FC6-Ani_Obj4C
		dc.w byte_16FD5-Ani_Obj4C
		dc.w byte_16FE6-Ani_Obj4C
byte_16FC2:	dc.b   1,  0,  5,$FF
byte_16FC6:	dc.b   1,  1,  6,  1,  6,  2,  7,  2,  7,  1,  6,  1,  6,$FD,  0
byte_16FD5:	dc.b   1,  1,  6,  1,  6,  2,  7,  3,  8,  4,  9,  4,  9,  3,  8,$FE
		dc.b  $A
byte_16FE6:	dc.b   3, $A, $B, $C, $D, $E,$FF
		even

Map_Obj4C:	dc.w word_1700C-Map_Obj4C
		dc.w word_1702E-Map_Obj4C
		dc.w word_17050-Map_Obj4C
		dc.w word_17072-Map_Obj4C
		dc.w word_17094-Map_Obj4C
		dc.w word_170AE-Map_Obj4C
		dc.w word_170D0-Map_Obj4C
		dc.w word_170F2-Map_Obj4C
		dc.w word_17114-Map_Obj4C
		dc.w word_17136-Map_Obj4C
		dc.w word_17150-Map_Obj4C
		dc.w word_1716A-Map_Obj4C
		dc.w word_17184-Map_Obj4C
		dc.w word_17196-Map_Obj4C
		dc.w word_171A8-Map_Obj4C
word_1700C:	dc.w 4
		dc.w $F005,    0,    0,$FFF8		; 0
		dc.w	 5,    4,    2,$FFF8		; 4
		dc.w $F00B,    8,    4,	   5		; 8
		dc.w $F00B, $808, $804,$FFE3		; 12
word_1702E:	dc.w 4
		dc.w $F005,    0,    0,$FFF8		; 0
		dc.w	 5,    4,    2,$FFF8		; 4
		dc.w $F60D,  $14,   $A,	   5		; 8
		dc.w $F60D, $814, $80A,$FFDB		; 12
word_17050:	dc.w 4
		dc.w $F005,    0,    0,$FFF8		; 0
		dc.w	 5,    4,    2,$FFF8		; 4
		dc.w $F80D,  $1C,   $E,	   4		; 8
		dc.w $F80D, $81C, $80E,$FFDC		; 12
word_17072:	dc.w 4
		dc.w $F005,    0,    0,$FFF8		; 0
		dc.w	 5,    4,    2,$FFF8		; 4
		dc.w $F805,  $24,  $12,$FFEC		; 8
		dc.w $F805,  $28,  $14,	   4		; 12
word_17094:	dc.w 3
		dc.w $F801,  $2C,  $16,	   0		; 0
		dc.w $F005,    0,    0,$FFF8		; 4
		dc.w	 5,    4,    2,$FFF8		; 8
word_170AE:	dc.w 4
		dc.w $F005,    0,    0,$FFF8		; 0
		dc.w	 5,  $2E,  $17,$FFF8		; 4
		dc.w $F00B,    8,    4,	   5		; 8
		dc.w $F00B, $808, $804,$FFE3		; 12
word_170D0:	dc.w 4
		dc.w $F005,    0,    0,$FFF8		; 0
		dc.w	 5,  $2E,  $17,$FFF8		; 4
		dc.w $F60D,  $14,   $A,	   5		; 8
		dc.w $F60D, $814, $80A,$FFDB		; 12
word_170F2:	dc.w 4
		dc.w $F005,    0,    0,$FFF8		; 0
		dc.w	 5,  $2E,  $17,$FFF8		; 4
		dc.w $F80D,  $1C,   $E,	   4		; 8
		dc.w $F80D, $81C, $80E,$FFDC		; 12
word_17114:	dc.w 4
		dc.w $F005,    0,    0,$FFF8		; 0
		dc.w	 5,  $2E,  $17,$FFF8		; 4
		dc.w $F805,  $28,  $14,	   4		; 8
		dc.w $F805,  $24,  $12,$FFEC		; 12
word_17136:	dc.w 3
		dc.w $F801,  $2C,  $16,	   0		; 0
		dc.w $F005,    0,    0,$FFF8		; 4
		dc.w	 5,  $2E,  $17,$FFF8		; 8
word_17150:	dc.w 3
		dc.w $F007,  $32,  $19,$FFF8		; 0
		dc.w $F80D,  $1C,   $E,	   4		; 4
		dc.w $F80D, $81C, $80E,$FFDC		; 8
word_1716A:	dc.w 3
		dc.w $F007,  $32,  $19,$FFF8		; 0
		dc.w $F805,  $28,  $14,	   4		; 4
		dc.w $F805,  $24,  $12,$FFEC		; 8
word_17184:	dc.w 2
		dc.w $F801,  $2C,  $16,	   0		; 0
		dc.w $F007,  $32,  $19,$FFF8		; 4
word_17196:	dc.w 2
		dc.w $F801, $82C, $816,$FFF8		; 0
		dc.w $F007,  $32,  $19,$FFF8		; 4
word_171A8:	dc.w 3
		dc.w $F007,  $32,  $19,$FFF8		; 0
		dc.w $F805, $828, $814,$FFEC		; 4
		dc.w $F805, $824, $812,	   4		; 8
		even
;----------------------------------------------------------------------------
; Object 4E - Gator badnik from HPZ
;----------------------------------------------------------------------------

Obj4E:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj4E_Index(pc,d0.w),d1
		jmp	Obj4E_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj4E_Index:	dc.w Obj4E_Init-Obj4E_Index
		dc.w Obj4E_Main-Obj4E_Index
; ---------------------------------------------------------------------------

Obj4E_Init:
		move.l	#Map_Obj4E,obMap(a0)
		move.w	#make_art_tile(ArtTile_Gator,1,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$A,obColType(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#8,obWidth(a0)
		jsr	(ObjectMoveAndFall).l
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	locret_17238
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		addq.b	#2,obRoutine(a0)

locret_17238:
		rts
; ---------------------------------------------------------------------------

Obj4E_Main:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Obj4E_SubIndex(pc,d0.w),d1
		jsr	Obj4E_SubIndex(pc,d1.w)
		lea	Ani_Obj4E(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------
Obj4E_SubIndex:	dc.w loc_1725A-Obj4E_SubIndex
		dc.w loc_1727E-Obj4E_SubIndex
; ---------------------------------------------------------------------------

loc_1725A:
		subq.w	#1,objoff_30(a0)
		bpl.s	locret_1727C
		addq.b	#2,ob2ndRout(a0)
		move.w	#-$C0,obVelX(a0)
		clr.b	obAnim(a0)
		bchg	#0,obStatus(a0)
		bne.s	locret_1727C
		neg.w	obVelX(a0)

locret_1727C:
		rts
; ---------------------------------------------------------------------------

loc_1727E:
		bsr.w	sub_172B6
		jsr	(ObjectMove).l
		jsr	(ObjHitFloor).l
		cmpi.w	#-8,d1
		blt.s	loc_1729E
		cmpi.w	#$C,d1
		bge.s	loc_1729E
		add.w	d1,obY(a0)
		rts
; ---------------------------------------------------------------------------

loc_1729E:
		subq.b	#2,ob2ndRout(a0)
		move.w	#60-1,objoff_30(a0)
		clr.w	obVelX(a0)
		move.b	#1,obAnim(a0)
		rts

; =============== S U B R O U T I N E =======================================


sub_172B6:
		move.w	obX(a0),d0
		sub.w	(v_player+obX).w,d0
		bmi.s	loc_172D0
		cmpi.w	#$40,d0
		bgt.s	loc_172E6
		btst	#0,obStatus(a0)
		beq.s	loc_172DE
		rts
; ---------------------------------------------------------------------------

loc_172D0:
		cmpi.w	#-$40,d0
		blt.s	loc_172E6
		btst	#0,obStatus(a0)
		beq.s	loc_172E6

loc_172DE:
		move.b	#2,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

loc_172E6:
		clr.b	obAnim(a0)
		rts
; End of function sub_172B6

; ---------------------------------------------------------------------------
Ani_Obj4E:	dc.w byte_172F4-Ani_Obj4E
		dc.w byte_172FC-Ani_Obj4E
		dc.w byte_172FF-Ani_Obj4E
byte_172F4:	dc.b   3,  0,  4,  2,  3,  1,  5,$FF
byte_172FC:	dc.b  $F,  0,$FF
byte_172FF:	dc.b   3,  6, $A,  8,  9,  7, $B,$FF,  0
		even

Map_Obj4E:	dc.w word_17320-Map_Obj4E
		dc.w word_17342-Map_Obj4E
		dc.w word_17364-Map_Obj4E
		dc.w word_17386-Map_Obj4E
		dc.w word_173A8-Map_Obj4E
		dc.w word_173CA-Map_Obj4E
		dc.w word_173EC-Map_Obj4E
		dc.w word_1740E-Map_Obj4E
		dc.w word_17430-Map_Obj4E
		dc.w word_17452-Map_Obj4E
		dc.w word_17474-Map_Obj4E
		dc.w word_17496-Map_Obj4E
word_17320:	dc.w 4
		dc.w $F80E,    0,    0,$FFE4		; 0
		dc.w $F805,  $18,   $C,	   4		; 4
		dc.w	 1,  $1C,   $E,	   4		; 8
		dc.w	 5,  $20,  $10,	  $C		; 12
word_17342:	dc.w 4
		dc.w $F80E,    0,    0,$FFE4		; 0
		dc.w $F805,  $18,   $C,	   4		; 4
		dc.w	 1,  $1C,   $E,	   4		; 8
		dc.w	 5,  $24,  $12,	  $C		; 12
word_17364:	dc.w 4
		dc.w $F80E,    0,    0,$FFE4		; 0
		dc.w $F805,  $18,   $C,	   4		; 4
		dc.w	 1,  $1C,   $E,	   4		; 8
		dc.w	 5,  $28,  $14,	  $C		; 12
word_17386:	dc.w 4
		dc.w $F80E,    0,    0,$FFE4		; 0
		dc.w $F805,  $18,   $C,	   4		; 4
		dc.w	 1,  $1E,   $F,	   4		; 8
		dc.w	 5,  $20,  $10,	  $C		; 12
word_173A8:	dc.w 4
		dc.w $F80E,    0,    0,$FFE4		; 0
		dc.w $F805,  $18,   $C,	   4		; 4
		dc.w	 1,  $1E,   $F,	   4		; 8
		dc.w	 5,  $24,  $12,	  $C		; 12
word_173CA:	dc.w 4
		dc.w $F80E,    0,    0,$FFE4		; 0
		dc.w $F805,  $18,   $C,	   4		; 4
		dc.w	 1,  $1E,   $F,	   4		; 8
		dc.w	 5,  $28,  $14,	  $C		; 12
word_173EC:	dc.w 4
		dc.w $F00B,   $C,    6,$FFEC		; 0
		dc.w $F805,  $18,   $C,	   4		; 4
		dc.w	 1,  $1C,   $E,	   4		; 8
		dc.w	 5,  $20,  $10,	  $C		; 12
word_1740E:	dc.w 4
		dc.w $F00B,   $C,    6,$FFEC		; 0
		dc.w $F805,  $18,   $C,	   4		; 4
		dc.w	 1,  $1C,   $E,	   4		; 8
		dc.w	 5,  $24,  $12,	  $C		; 12
word_17430:	dc.w 4
		dc.w $F00B,   $C,    6,$FFEC		; 0
		dc.w $F805,  $18,   $C,	   4		; 4
		dc.w	 1,  $1C,   $E,	   4		; 8
		dc.w	 5,  $28,  $14,	  $C		; 12
word_17452:	dc.w 4
		dc.w $F00B,   $C,    6,$FFEC		; 0
		dc.w $F805,  $18,   $C,	   4		; 4
		dc.w	 1,  $1E,   $F,	   4		; 8
		dc.w	 5,  $20,  $10,	  $C		; 12
word_17474:	dc.w 4
		dc.w $F00B,   $C,    6,$FFEC		; 0
		dc.w $F805,  $18,   $C,	   4		; 4
		dc.w	 1,  $1E,   $F,	   4		; 8
		dc.w	 5,  $24,  $12,	  $C		; 12
word_17496:	dc.w 4
		dc.w $F00B,   $C,    6,$FFEC		; 0
		dc.w $F805,  $18,   $C,	   4		; 4
		dc.w	 1,  $1E,   $F,	   4		; 8
		dc.w	 5,  $28,  $14,	  $C		; 12
		even
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 54 - Snail badnik from	EHZ
; ---------------------------------------------------------------------------

Obj54:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj54_Index(pc,d0.w),d1
		jmp	Obj54_Index(pc,d1.w)
; ===========================================================================
Obj54_Index:	dc.w Obj54_Init-Obj54_Index
		dc.w Obj54_Move-Obj54_Index
		dc.w loc_177B4-Obj54_Index
		dc.w loc_177EC-Obj54_Index
		dc.w loc_17772-Obj54_Index
; ===========================================================================

Obj54_Init:
		move.l	#Map_obj54,obMap(a0)
		move.w	#make_art_tile(ArtTile_Snail,0,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$A,obColType(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#$E,obWidth(a0)
		jsr	(FindNextFreeObj).l
		bne.s	loc_17670
		_move.b	#id_Obj54,obID(a1)
		move.b	#6,obRoutine(a1)
		move.l	#Map_obj54,obMap(a1)
		move.w	#make_art_tile(ArtTile_Snail,1,0),obGfx(a1)
		move.w	#$180,obPriority(a1)
		move.b	#$10,obActWid(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obRender(a0),obRender(a1)
		move.l	a0,objoff_2A(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	#2,obFrame(a1)

loc_17670:
		addq.b	#2,obRoutine(a0)
		move.w	#-$80,d0
		btst	#0,obStatus(a0)
		beq.s	loc_17682
		neg.w	d0

loc_17682:
		move.w	d0,obVelX(a0)
		rts
; ===========================================================================
; loc_17688:
Obj54_Move:
		bsr.w	sub_176D0
		jsr	(ObjectMove).l
		jsr	(ObjHitFloor).l
		cmpi.w	#-8,d1
		blt.s	Obj54_Display
		cmpi.w	#$C,d1
		bge.s	Obj54_Display
		add.w	d1,obY(a0)
		lea	Ani_Obj54(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ===========================================================================
; loc_176B4:
Obj54_Display:
		addq.b	#2,obRoutine(a0)
		move.w	#$14,objoff_30(a0)
		st	objoff_34(a0)
		lea	Ani_Obj54(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l

; =============== S U B R O U T I N E =======================================


sub_176D0:
		tst.b	objoff_35(a0)
		bne.s	locret_17712
		move.w	(v_player+obX).w,d0
		sub.w	obX(a0),d0
		cmpi.w	#$64,d0
		bgt.s	locret_17712
		cmpi.w	#-$64,d0
		blt.s	locret_17712
		tst.w	d0
		bmi.s	loc_176F8
		btst	#0,obStatus(a0)
		beq.s	locret_17712
		bra.s	loc_17700
; ---------------------------------------------------------------------------

loc_176F8:
		btst	#0,obStatus(a0)
		bne.s	locret_17712

loc_17700:
		move.w	obVelX(a0),d0
		asl.w	#2,d0
		move.w	d0,obVelX(a0)
		st	objoff_35(a0)
		bra.w	sub_17714

locret_17712:
		rts
; End of function sub_176D0


; =============== S U B R O U T I N E =======================================


sub_17714:
		jsr	(FindNextFreeObj).l
		bne.s	locret_17770
		_move.b	#id_Obj54,obID(a1)
		move.b	#8,obRoutine(a1)
		move.l	#Map_obj4B,obMap(a1)
		move.w	#make_art_tile(ArtTile_Buzzer,0,0),obGfx(a1)
		move.w	#$200,obPriority(a1)
		move.b	#$10,obActWid(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obRender(a0),obRender(a1)
		move.l	a0,objoff_2A(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		addq.w	#7,obY(a1)
		addi.w	#$D,obX(a1)
		move.b	#1,obAnim(a1)

locret_17770:
		rts
; End of function sub_17714

; ---------------------------------------------------------------------------

loc_17772:
		movea.l	objoff_2A(a0),a1
		cmpi.b	#id_Obj54,obID(a1)
		bne.w	loc_17854
		tst.b	objoff_34(a1)
		bne.w	loc_17854
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		addq.w	#7,obY(a0)
		moveq	#$D,d0
		btst	#0,obStatus(a0)
		beq.s	loc_177A2
		neg.w	d0

loc_177A2:
		add.w	d0,obX(a0)
		lea	(Ani_obj4B).l,a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------

loc_177B4:
		subq.w	#1,objoff_30(a0)
		bpl.s	+
		neg.w	obVelX(a0)
		jsr	(ObjectMoveAndFall).l
		move.w	obVelX(a0),d0
		asr.w	#2,d0
		move.w	d0,obVelX(a0)
		bchg	#0,obStatus(a0)
		bchg	#0,obRender(a0)
		subq.b	#2,obRoutine(a0)
		sf	objoff_34(a0)
		sf	objoff_35(a0)
+		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------

loc_177EC:
		movea.l	objoff_2A(a0),a1
		cmpi.b	#id_Obj54,obID(a1)
		bne.w	loc_17854
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		move.b	obStatus(a1),obStatus(a0)
		move.b	obRender(a1),obRender(a0)
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------
Ani_Obj54:	dc.w byte_17818-Ani_Obj54
		dc.w byte_1781C-Ani_Obj54
byte_17818:	dc.b   5,  0,  1,$FF
byte_1781C:	dc.b   1,  0,  1,$FF
		even
; ---------------------------------------------------------------------------
; Sprite mappings
; ---------------------------------------------------------------------------
Map_obj54:	binclude	"mappings/sprite/obj54.bin"
; ---------------------------------------------------------------------------

loc_17854:
		jmp	(DeleteObject).l
;----------------------------------------------------------------------------
; Object 57 - sub object of the	EHZ boss
;----------------------------------------------------------------------------

Obj57:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	off_17892(pc,d0.w),d1
		jmp	off_17892(pc,d1.w)
; ---------------------------------------------------------------------------
off_17892:	dc.w loc_1789E-off_17892
		dc.w loc_178C4-off_17892
		dc.w loc_17920-off_17892
		dc.w loc_17952-off_17892
		dc.w loc_1797C-off_17892
		dc.w loc_17996-off_17892
; ---------------------------------------------------------------------------

loc_1789E:
		clr.b	obColType(a0)
		cmpi.w	#$29D0,obX(a0)
		ble.s	loc_178B6
		subq.w	#1,obX(a0)
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_178B6:
		move.w	#$29D0,obX(a0)
		addq.b	#2,ob2ndRout(a0)
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_178C4:
		moveq	#0,d0
		move.b	objoff_2C(a0),d0
		move.w	off_178D2(pc,d0.w),d1
		jmp	off_178D2(pc,d1.w)
; ---------------------------------------------------------------------------
off_178D2:	dc.w loc_178D6-off_178D2
		dc.w loc_178FC-off_178D2
; ---------------------------------------------------------------------------

loc_178D6:
		cmpi.w	#$41E,obY(a0)
		bge.s	loc_178E8
		addq.w	#1,obY(a0)
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_178E8:
		addq.b	#2,objoff_2C(a0)
		bset	#0,objoff_2D(a0)
		move.w	#$3C,objoff_2A(a0)
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_178FC:
		subq.w	#1,objoff_2A(a0)
		bpl.s	+
		move.w	#-$200,obVelX(a0)
		addq.b	#2,ob2ndRout(a0)
		move.b	#$F,obColType(a0)
		bset	#1,objoff_2D(a0)
+		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_17920:
		bsr.w	sub_17A8C
		bsr.w	sub_17A6A
		move.w	objoff_2E(a0),d0
		lsr.w	#1,d0
		subi.w	#$14,d0
		move.w	d0,obY(a0)
		clr.w	objoff_2E(a0)
		move.l	obX(a0),d2
		move.w	obVelX(a0),d0
		ext.l	d0
		asl.l	#8,d0
		add.l	d0,d2
		move.l	d2,obX(a0)
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_17952:
		subq.w	#1,objoff_3C(a0)
		bpl.w	BossDefeated
		bset	#0,obStatus(a0)
		bclr	#7,obStatus(a0)
		clr.w	obVelX(a0)
		addq.b	#2,ob2ndRout(a0)
		move.w	#-$26,objoff_3C(a0)
		move.w	#$C,objoff_2A(a0)
		rts
; ---------------------------------------------------------------------------

loc_1797C:
		addq.w	#1,obY(a0)
		subq.w	#1,objoff_2A(a0)
		bpl.s	+
		addq.b	#2,ob2ndRout(a0)
		clr.b	objoff_2C(a0)
+		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_17996:
		moveq	#0,d0
		move.b	objoff_2C(a0),d0
		move.w	off_179A8(pc,d0.w),d1
		jsr	off_179A8(pc,d1.w)
-		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------
off_179A8:	dc.w loc_179AE-off_179A8
		dc.w loc_17A22-off_179A8
		dc.w loc_17A3C-off_179A8
; ---------------------------------------------------------------------------

loc_179AE:
		bclr	#0,objoff_2D(a0)
		jsr	(FindNextFreeObj).l
		bne.s	-
		_move.b	#id_Obj58,obID(a1)
		move.l	a0,objoff_34(a1)
		move.l	#Map_Obj58,obMap(a1)
		move.w	#make_art_tile($540,1,0),obGfx(a1)
		move.b	#4,obRender(a1)
		move.b	#$20,obActWid(a1)
		move.w	#$200,obPriority(a1)
		move.l	obX(a0),obX(a1)
		move.l	obY(a0),obY(a1)
		addi.w	#$C,obY(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obRender(a0),obRender(a1)
		move.b	#8,obRoutine(a1)
		move.b	#2,obAnim(a1)
		move.w	#$10,objoff_2A(a1)
		move.w	#$32,objoff_2A(a0)
		addq.b	#2,objoff_2C(a0)
		rts
; ---------------------------------------------------------------------------

loc_17A22:
		subq.w	#1,objoff_2A(a0)
		bpl.s	locret_17A3A
		bset	#2,objoff_2D(a0)
		move.w	#$60,objoff_2A(a0)
		addq.b	#2,objoff_2C(a0)

locret_17A3A:
		rts
; ---------------------------------------------------------------------------

loc_17A3C:
		subq.w	#1,obY(a0)
		subq.w	#1,objoff_2A(a0)
		bpl.s	locret_17A68
		addq.w	#1,obY(a0)
		addq.w	#2,obX(a0)
		cmpi.w	#$2B08,obX(a0)
		blo.s	locret_17A68
		tst.b	(Boss_defeated_flag).w
		bne.s	locret_17A68
		move.b	#1,(Boss_defeated_flag).w
		jmp	(DeleteObject).l
; ---------------------------------------------------------------------------

locret_17A68:
		rts

; =============== S U B R O U T I N E =======================================


sub_17A6A:
		move.w	obX(a0),d0
		cmpi.w	#$2720,d0
		ble.s	loc_17A7A
		cmpi.w	#$2B08,d0
		blt.s	locret_17A8A

loc_17A7A:
		bchg	#0,obStatus(a0)
		bchg	#0,obRender(a0)
		neg.w	obVelX(a0)

locret_17A8A:
		rts
; End of function sub_17A6A


; =============== S U B R O U T I N E =======================================


sub_17A8C:
		cmpi.b	#6,ob2ndRout(a0)
		bhs.s	locret_17AD2
		tst.b	obStatus(a0)
		bmi.s	loc_17AD4
		tst.b	obColType(a0)
		bne.s	locret_17AD2
		tst.b	objoff_3E(a0)
		bne.s	loc_17AB6
		move.b	#$20,objoff_3E(a0)
		move.w	#sfx_HitBoss,d0
		jsr	(PlaySound_Special).l

loc_17AB6:
		lea	(v_palette+$22).w,a1
		moveq	#0,d0
		tst.w	(a1)
		bne.s	loc_17AC4
		move.w	#cWhite,d0

loc_17AC4:
		move.w	d0,(a1)
		subq.b	#1,objoff_3E(a0)
		bne.s	locret_17AD2
		move.b	#$F,obColType(a0)

locret_17AD2:
		rts
; ---------------------------------------------------------------------------

loc_17AD4:
		moveq	#100,d0
		bsr.w	AddPoints
		move.b	#6,ob2ndRout(a0)
		move.w	#180-1,objoff_3C(a0)
		bset	#3,objoff_2D(a0)
		rts
; End of function sub_17A8C

; ---------------------------------------------------------------------------
; Object 58 - sub object of the	EHZ boss
; ---------------------------------------------------------------------------

Obj58:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	off_17AFC(pc,d0.w),d1
		jmp	off_17AFC(pc,d1.w)
; ---------------------------------------------------------------------------
off_17AFC:	dc.w loc_17B2A-off_17AFC
		dc.w loc_17BB0-off_17AFC
		dc.w loc_17C02-off_17AFC
		dc.w loc_17CE4-off_17AFC
		dc.w loc_17B06-off_17AFC
; ---------------------------------------------------------------------------

loc_17B06:
		subq.w	#1,obY(a0)
		subq.w	#1,objoff_2A(a0)
		bpl.s	+
		clr.b	obRoutine(a0)
		lea	(Ani_Obj58).l,a1
		jsr	(AnimateSprite).l
+		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_17B2A:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	off_17B38(pc,d0.w),d1
		jmp	off_17B38(pc,d1.w)
; ---------------------------------------------------------------------------
off_17B38:	dc.w loc_17B3C-off_17B38
		dc.w loc_17B86-off_17B38
; ---------------------------------------------------------------------------

loc_17B3C:
		movea.l	objoff_34(a0),a1
		cmpi.b	#id_Obj55,obID(a1)
		bne.w	Obj58_Delete
		btst	#0,objoff_2D(a1)
		beq.s	loc_17B60
		move.b	#1,obAnim(a0)
		move.w	#$18,objoff_2A(a0)
		addq.b	#2,ob2ndRout(a0)

loc_17B60:
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		move.b	obStatus(a1),obStatus(a0)
		move.b	obRender(a1),obRender(a0)
		lea	(Ani_Obj58).l,a1
		jsr	(AnimateSprite).l
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_17B86:
		subq.w	#1,objoff_2A(a0)
		bpl.s	loc_17BA2
		cmpi.w	#-$10,objoff_2A(a0)
		ble.w	Obj58_Delete
		addq.w	#1,obY(a0)
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_17BA2:
		lea	(Ani_Obj58).l,a1
		jsr	(AnimateSprite).l
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_17BB0:
		movea.l	objoff_34(a0),a1
		cmpi.b	#id_Obj55,obID(a1)
		bne.w	Obj58_Delete
		btst	#1,objoff_2D(a1)
		beq.s	+
		btst	#2,objoff_2D(a1)
		bne.w	loc_17BF2
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		addq.w	#8,obY(a0)
		move.b	obStatus(a1),obStatus(a0)
		move.b	obRender(a1),obRender(a0)
+		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_17BF2:
		move.b	#8,obFrame(a0)
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_17C02:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	off_17C10(pc,d0.w),d1
		jmp	off_17C10(pc,d1.w)
; ---------------------------------------------------------------------------
off_17C10:	dc.w loc_17C18-off_17C10
		dc.w loc_17C36-off_17C10
		dc.w loc_17C96-off_17C10
		dc.w loc_17CC2-off_17C10
; ---------------------------------------------------------------------------

loc_17C18:
		movea.l	objoff_34(a0),a1
		cmpi.b	#id_Obj55,obID(a1)
		bne.w	Obj58_Delete
		btst	#1,objoff_2D(a1)
		beq.s	+
		addq.b	#2,ob2ndRout(a0)
+		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_17C36:
		movea.l	objoff_34(a0),a1
		cmpi.b	#id_Obj55,obID(a1)
		bne.w	Obj58_Delete
		move.b	obStatus(a1),obStatus(a0)
		move.b	obRender(a1),obRender(a0)
		tst.b	obStatus(a0)
		bpl.s	loc_17C58
		addq.b	#2,ob2ndRout(a0)

loc_17C58:
		bsr.w	sub_17A6A
		jsr	(ObjectMoveAndFall).l
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	loc_17C6E
		add.w	d1,obY(a0)

loc_17C6E:
		move.w	#$100,obVelY(a0)
		cmpi.w	#$80,obPriority(a0)
		bne.s	loc_17C88
		move.w	obY(a0),d0
		movea.l	objoff_34(a0),a1
		add.w	d0,objoff_2E(a1)

loc_17C88:
		lea	(Ani_Obj58a).l,a1
		jsr	(AnimateSprite).l
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_17C96:
		subq.w	#1,objoff_2A(a0)
		bpl.w	+
		addq.b	#2,ob2ndRout(a0)
		move.w	#$A,objoff_2A(a0)
		move.w	#-$300,obVelY(a0)
		cmpi.w	#$80,obPriority(a0)
		beq.s	+
		neg.w	obVelX(a0)
/		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_17CC2:
		subq.w	#1,objoff_2A(a0)
		bpl.s	-
		jsr	(ObjectMoveAndFall).l
		bsr.w	ObjHitFloor
		tst.w	d1
		bpl.s	loc_17CE0
		move.w	#-$200,obVelY(a0)
		add.w	d1,obY(a0)

loc_17CE0:
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------

loc_17CE4:
		movea.l	objoff_34(a0),a1
		cmpi.b	#id_Obj55,obID(a1)
		bne.w	Obj58_Delete
		btst	#3,objoff_2D(a1)
		bne.s	loc_17D4A
		bsr.w	sub_17D6A
		btst	#1,objoff_2D(a1)
		beq.s	+
		move.b	#$8B,obColType(a0)
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		move.b	obStatus(a1),obStatus(a0)
		move.b	obRender(a1),obRender(a0)
		addi.w	#$10,obY(a0)
		move.w	#-$36,d0
		btst	#0,obStatus(a0)
		beq.s	loc_17D38
		neg.w	d0

loc_17D38:
		add.w	d0,obX(a0)
		lea	(Ani_Obj58a).l,a1
		jsr	(AnimateSprite).l
+		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

loc_17D4A:
		move.w	#-3,d0
		btst	#0,obStatus(a0)
		beq.s	loc_17D58
		neg.w	d0

loc_17D58:
		add.w	d0,obX(a0)
		lea	(Ani_Obj58a).l,a1
		jsr	(AnimateSprite).l
		jmp	(DisplaySprite).l

; =============== S U B R O U T I N E =======================================


sub_17D6A:
		cmpi.b	#1,obColProp(a1)
		beq.s	loc_17D74
		rts
; ---------------------------------------------------------------------------

loc_17D74:
		move.w	obX(a0),d0
		sub.w	(v_player+obX).w,d0
		bpl.s	loc_17D88
		btst	#0,obStatus(a1)
		bne.s	loc_17D92
		rts
; ---------------------------------------------------------------------------

loc_17D88:
		btst	#0,obStatus(a1)
		beq.s	loc_17D92
		rts
; ---------------------------------------------------------------------------

loc_17D92:
		bset	#3,objoff_2D(a1)
		rts
; End of function sub_17D6A


; =============== S U B R O U T I N E =======================================


sub_17D9A:
		jsr	(FindNextFreeObj).l
		bne.s	loc_17E0E
		_move.b	#id_Obj58,obID(a1)
		move.l	a0,objoff_34(a1)
		move.l	#Map_Obj58a,obMap(a1)
		move.w	#make_art_tile($4C0,1,0),obGfx(a1)
		move.b	#4,obRender(a1)
		move.b	#$10,obActWid(a1)
		move.w	#$80,obPriority(a1)
		move.b	#$10,obHeight(a1)
		move.b	#$10,obWidth(a1)
		move.l	obX(a0),obX(a1)
		move.l	obY(a0),obY(a1)
		addi.w	#$1C,obX(a1)
		addi.w	#$C,obY(a1)
		move.w	#-$200,obVelX(a1)
		move.b	#4,obRoutine(a1)
		move.b	#4,obFrame(a1)
		move.b	#1,obAnim(a1)
		move.w	#$16,objoff_2A(a1)

loc_17E0E:
		jsr	(FindNextFreeObj).l
		bne.s	loc_17E82
		_move.b	#id_Obj58,obID(a1)
		move.l	a0,objoff_34(a1)
		move.l	#Map_Obj58a,obMap(a1)
		move.w	#make_art_tile($4C0,1,0),obGfx(a1)
		move.b	#4,obRender(a1)
		move.b	#$10,obActWid(a1)
		move.w	#$80,obPriority(a1)
		move.b	#$10,obHeight(a1)
		move.b	#$10,obWidth(a1)
		move.l	obX(a0),obX(a1)
		move.l	obY(a0),obY(a1)
		subi.w	#$C,obX(a1)
		addi.w	#$C,obY(a1)
		move.w	#-$200,obVelX(a1)
		move.b	#4,obRoutine(a1)
		move.b	#4,obFrame(a1)
		move.b	#1,obAnim(a1)
		move.w	#$4B,objoff_2A(a1)

loc_17E82:
		jsr	(FindNextFreeObj).l
		bne.s	loc_17EF6
		_move.b	#id_Obj58,obID(a1)
		move.l	a0,objoff_34(a1)
		move.l	#Map_Obj58a,obMap(a1)
		move.w	#make_art_tile($4C0,1,0),obGfx(a1)
		move.b	#4,obRender(a1)
		move.b	#$10,obActWid(a1)
		move.w	#$100,obPriority(a1)
		move.b	#$10,obHeight(a1)
		move.b	#$10,obWidth(a1)
		move.l	obX(a0),obX(a1)
		move.l	obY(a0),obY(a1)
		subi.w	#$2C,obX(a1)
		addi.w	#$C,obY(a1)
		move.w	#-$200,obVelX(a1)
		move.b	#4,obRoutine(a1)
		move.b	#6,obFrame(a1)
		move.b	#2,obAnim(a1)
		move.w	#$30,objoff_2A(a1)

loc_17EF6:
		jsr	(FindNextFreeObj).l
		bne.s	locret_17F52
		_move.b	#id_Obj58,obID(a1)
		move.l	a0,objoff_34(a1)
		move.l	#Map_Obj58a,obMap(a1)
		move.w	#make_art_tile($4C0,1,0),obGfx(a1)
		move.b	#4,obRender(a1)
		move.b	#$10,obActWid(a1)
		move.w	#$80,obPriority(a1)
		move.l	obX(a0),obX(a1)
		move.l	obY(a0),obY(a1)
		subi.w	#$36,obX(a1)
		addq.w	#8,obY(a1)
		move.b	#6,obRoutine(a1)
		move.b	#1,obFrame(a1)
		clr.b	obAnim(a1)

locret_17F52:
		rts
; End of function sub_17D9A

; ---------------------------------------------------------------------------

loc_17F54:
		jsr	(FindNextFreeObj).l
		bne.s	loc_17F98
		_move.b	#id_Obj58,obID(a1)
		move.l	a0,objoff_34(a1)
		move.l	#Map_Obj58a,obMap(a1)
		move.w	#make_art_tile($4C0,0,0),obGfx(a1)
		move.b	#4,obRender(a1)
		move.b	#$20,obActWid(a1)
		move.w	#$100,obPriority(a1)
		move.l	obX(a0),obX(a1)
		move.l	obY(a0),obY(a1)
		move.b	#2,obRoutine(a1)

loc_17F98:
		bsr.w	sub_17D9A
		subq.w	#8,objoff_38(a0)
		move.w	#$2A00,obX(a0)
		move.w	#$2C0,obY(a0)
		jsr	(FindNextFreeObj).l
		bne.s	locret_17FF8
		_move.b	#id_Obj58,obID(a1)
		move.l	a0,objoff_34(a1)
		move.l	#Map_Obj58,obMap(a1)
		move.w	#make_art_tile($540,1,0),obGfx(a1)
		move.b	#4,obRender(a1)
		move.b	#$20,obActWid(a1)
		move.w	#$200,obPriority(a1)
		move.l	obX(a0),obX(a1)
		move.l	obY(a0),obY(a1)
		move.w	#$1E,objoff_2A(a1)
		clr.b	obRoutine(a1)

locret_17FF8:
		rts
; ---------------------------------------------------------------------------
Obj58_Delete:
		jmp	(DeleteObject).l
; ---------------------------------------------------------------------------
Ani_Obj58:	dc.w byte_18000-Ani_Obj58
		dc.w byte_18004-Ani_Obj58
		dc.w byte_1801A-Ani_Obj58
byte_18000:	dc.b   1,  5,  6,$FF			; 0
byte_18004:	dc.b   1,  1,  1,  1,  2,  2,  2,  3,  3,  3,  4,  4,  4,  0,  0,  0
		dc.b   0,  0,  0,  0,  0,$FF		; 16
byte_1801A:	dc.b   1,  0,  0,  0,  0,  0,  0,  0,  0,  4,  4,  4,  3,  3,  3,  2
		dc.b   2,  2,  1,  1,  1,  5,  6,$FE,  2,  0 ; 16
		even

Map_Obj58:	dc.w word_18042-Map_Obj58
		dc.w word_1804C-Map_Obj58
		dc.w word_18076-Map_Obj58
		dc.w word_180A0-Map_Obj58
		dc.w word_180BA-Map_Obj58
		dc.w word_180D4-Map_Obj58
		dc.w word_180EE-Map_Obj58
word_18042:	dc.w 1
		dc.w $D805,    0,    0,	   2		; 0
word_1804C:	dc.w 5
		dc.w $D805,    4,    2,	   2		; 0
		dc.w $D80D,   $C,    6,	 $12		; 4
		dc.w $D80D,   $C,    6,	 $32		; 8
		dc.w $D80D,   $C,    6,$FFE2		; 12
		dc.w $D80D,   $C,    6,$FFC2		; 16
word_18076:	dc.w 5
		dc.w $D805,    4,    2,	   2		; 0
		dc.w $D80D,   $C,    6,	 $12		; 4
		dc.w $D805,    8,    4,	 $32		; 8
		dc.w $D80D,   $C,    6,$FFE2		; 12
		dc.w $D805,    8,    4,$FFD2		; 16
word_180A0:	dc.w 3
		dc.w $D805,    4,    2,	   2		; 0
		dc.w $D80D,   $C,    6,	 $12		; 4
		dc.w $D80D,   $C,    6,$FFE2		; 8
word_180BA:	dc.w 3
		dc.w $D805,    4,    2,	   2		; 0
		dc.w $D805,    8,    4,	 $12		; 4
		dc.w $D805,    8,    4,$FFF2		; 8
word_180D4:	dc.w 3
		dc.w $D805,    0,    0,	   2		; 0
		dc.w $D80D,   $C,    6,	 $12		; 4
		dc.w $D80D,   $C,    6,	 $32		; 8
word_180EE:	dc.w 3
		dc.w $D805,    4,    2,	   2		; 0
		dc.w $D80D,   $C,    6,$FFE2		; 4
		dc.w $D80D,   $C,    6,$FFC2		; 8
Ani_Obj58a:	dc.w byte_1810E-Ani_Obj58a
		dc.w byte_18113-Ani_Obj58a
		dc.w byte_18117-Ani_Obj58a
byte_1810E:	dc.b   5,  1,  2,  3,$FF
byte_18113:	dc.b   1,  4,  5,$FF
byte_18117:	dc.b   1,  6,  7,$FF
		even

Map_Obj58a:	dc.w word_1812E-Map_Obj58a
		dc.w word_18148-Map_Obj58a
		dc.w word_18152-Map_Obj58a
		dc.w word_1815C-Map_Obj58a
		dc.w word_18166-Map_Obj58a
		dc.w word_18170-Map_Obj58a
		dc.w word_1817A-Map_Obj58a
		dc.w word_18184-Map_Obj58a
		dc.w word_1818E-Map_Obj58a
word_1812E:	dc.w 3
		dc.w $F00F,    0,    0,$FFD0		; 0
		dc.w $F00F,  $10,    8,$FFF0		; 4
		dc.w $F00F,  $20,  $10,	 $10		; 8
word_18148:	dc.w 1
		dc.w $F00F,  $30,  $18,$FFF0		; 0
word_18152:	dc.w 1
		dc.w $F00F,  $40,  $20,$FFF0		; 0
word_1815C:	dc.w 1
		dc.w $F00F,  $50,  $28,$FFF0		; 0
word_18166:	dc.w 1
		dc.w $F00F,  $60,  $30,$FFF0		; 0
word_18170:	dc.w 1
		dc.w $F00F,$1060,$1030,$FFF0		; 0
word_1817A:	dc.w 1
		dc.w $F00F,  $70,  $38,$FFF0		; 0
word_18184:	dc.w 1
		dc.w $F00F,$1070,$1038,$FFF0		; 0
word_1818E:	dc.w 3
		dc.w $F00F,$8000,$8000,$FFD0		; 0
		dc.w $F00F,$8010,$8008,$FFF0		; 4
		dc.w $F00F,$8020,$8010,	 $10		; 8
		even
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 55 - EHZ boss
; the bottom part of the vehicle with the ability to fly is the parent object
; ---------------------------------------------------------------------------

Obj55:		; TODO - Replace with it's Final counterpart
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj55_Index(pc,d0.w),d1
		jmp	Obj55_Index(pc,d1.w)
; ===========================================================================
Obj55_Index:
		dc.w Obj55_Init-Obj55_Index	; 0 - Init
		dc.w loc_18302-Obj55_Index	; 2 - Flying vehicle, bottom = main object
		dc.w loc_18340-Obj55_Index	; 4 - Propeller normal
		dc.w loc_18372-Obj55_Index	; 6 - Vehicle on ground
		dc.w loc_18410-Obj55_Index	; 8 - Wheels
	;	dc.w loc_2F7F4-Obj55_Index	; A - Spike
	;	dc.w loc_2F52A-Obj55_Index	; C - Propeller after defeat
	;	dc.w loc_2F8DA-Obj55_Index	; E - Flying vehicle, top
; ===========================================================================

; #7,status(ax) set via collision response routine (Touch_Enemy_Part2)
; 	when after a hit collision_property(ax) = hitcount has reached zero
; objoff_2A(ax) used as timer (countdown)
; objoff_2C(ax) tertiary rountine counter
; #0,objoff_2D(ax) set when Robotnik is on ground
; #1,objoff_2D(ax) set when Robotnik is active (moving back & forth)
; #2,objoff_2D(ax) set when Robotnik is flying off after being defeated
;	#3,objoff_2D(ax) flag to separate spike from vehicle
; objoff_2E(ax)	y_position of wheels
;	objoff_34(ax) parent object
; objoff_3C(ax)	timer after defeat

; loc_181E4:
Obj55_Init:
		move.l	#Map_Obj55,obMap(a0)	; main object
		move.w	#make_art_tile($400,1,0),obGfx(a0) ; vehicle with ability to fly, bottom part
		ori.b	#4,obRender(a0)
		move.b	#$20,obActWid(a0)
		move.w	#$180,obPriority(a0)
		move.b	#$F,obColType(a0)
		move.b	#8,obColProp(a0)
		addq.b	#2,obRoutine(a0)
		move.w	obX(a0),objoff_30(a0)
		move.w	obY(a0),objoff_38(a0)
		move.b	obSubtype(a0),d0
		cmpi.b	#$81,d0
		bne.s	loc_18230
		addi.w	#$60,obGfx(a0)

loc_18230:
		jsr	(FindNextFreeObj).l
		bne.w	loc_182E8
		_move.b	#id_Obj55,obID(a1)
		move.l	a0,objoff_34(a1)
		move.l	a1,objoff_34(a0)
		move.l	#Map_Obj55,obMap(a1)
		move.w	#make_art_tile($400,0,0),obGfx(a1)
		move.b	#4,obRender(a1)
		move.b	#$20,obActWid(a1)
		move.w	#$180,obPriority(a1)
		move.l	obX(a0),obX(a1)
		move.l	obY(a0),obY(a1)
		addq.b	#4,obRoutine(a1)
		move.b	#1,obAnim(a1)
		move.b	obRender(a0),obRender(a1)
		move.b	obSubtype(a0),d0
		cmpi.b	#$81,d0
		bne.s	loc_18294
		addi.w	#$60,obGfx(a1)

loc_18294:
		tst.b	obSubtype(a0)
		bmi.s	loc_182E8
		jsr	(FindNextFreeObj).l
		bne.s	loc_182E8
		_move.b	#id_Obj55,obID(a1)
		move.l	a0,objoff_34(a1)

loc_182AC:
		move.l	#Map_Obj55a,obMap(a1)
		move.w	#make_art_tile($4D0,0,0),obGfx(a1)
		move.b	#1,obTimeFrame(a0)

loc_182C0:
		move.b	#4,obRender(a1)
		move.b	#$20,obActWid(a1)
		move.w	#$180,obPriority(a1)
		move.l	obX(a0),obX(a1)
		move.l	obY(a0),obY(a1)
		addq.b	#6,obRoutine(a1)
		move.b	obRender(a0),obRender(a1)

loc_182E8:
		move.b	obSubtype(a0),d0
		andi.w	#$7F,d0
		add.w	d0,d0
		add.w	d0,d0
		movea.l	dword_182FA(pc,d0.w),a1
		jmp	(a1)
; ===========================================================================
dword_182FA:	dc.l 0
		dc.l loc_17F54
; ===========================================================================

loc_18302:
		move.b	obSubtype(a0),d0
		andi.w	#$7F,d0
		add.w	d0,d0
		add.w	d0,d0
		movea.l	dword_18338(pc,d0.w),a1
		jsr	(a1)
		lea	(Ani_Obj55a).l,a1
		jsr	(AnimateSprite).l
		move.b	obStatus(a0),d0
		andi.b	#3,d0
		andi.b	#$FC,obRender(a0)
		or.b	d0,obRender(a0)
		jmp	(DisplaySprite).l
; ===========================================================================
dword_18338:	dc.l 0
		dc.l Obj57
; ===========================================================================

loc_18340:
		movea.l	objoff_34(a0),a1
		move.l	obX(a1),obX(a0)
		move.l	obY(a1),obY(a0)
		move.b	obStatus(a1),obStatus(a0)
		move.b	obRender(a1),obRender(a0)
		movea.l	#Ani_Obj55a,a1
		jsr	(AnimateSprite).l
		jmp	(DisplaySprite).l
; ===========================================================================
byte_1836E:	dc.b   0,$FF,  1,  0
; ===========================================================================

loc_18372:
		btst	#7,obStatus(a0)
		bne.s	loc_183C6
		movea.l	objoff_34(a0),a1
		move.l	obX(a1),obX(a0)
		move.l	obY(a1),obY(a0)
		move.b	obStatus(a1),obStatus(a0)
		move.b	obRender(a1),obRender(a0)
		subq.b	#1,obTimeFrame(a0)
		bpl.s	loc_183BA
		move.b	#1,obTimeFrame(a0)
		move.b	objoff_2A(a0),d0
		addq.b	#1,d0
		cmpi.b	#2,d0
		ble.s	loc_183B0
		moveq	#0,d0

loc_183B0:
		move.b	byte_1836E(pc,d0.w),obFrame(a0)
		move.b	d0,objoff_2A(a0)

loc_183BA:
		cmpi.b	#$FF,obFrame(a0)
		bne.w	loc_18452
		rts
; ===========================================================================

loc_183C6:
		movea.l	objoff_34(a0),a1
		btst	#6,objoff_2E(a1)
		bne.s	loc_183D4
		rts
; ===========================================================================

loc_183D4:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj55b,obMap(a0)
		move.w	#make_art_tile($4D8,0,0),obGfx(a0)
		clr.b	obFrame(a0)
		move.b	#5,obTimeFrame(a0)
		movea.l	objoff_34(a0),a1
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		addq.w	#4,obY(a0)
		subi.w	#$28,obX(a0)
		rts
; ===========================================================================

loc_18410:
		subq.b	#1,obTimeFrame(a0)
		bpl.s	loc_18452
		move.b	#5,obTimeFrame(a0)
		addq.b	#1,obFrame(a0)
		cmpi.b	#4,obFrame(a0)
		bne.w	loc_18452
		clr.b	obFrame(a0)
		movea.l	objoff_34(a0),a1
		move.b	(a1),d0
		beq.w	Obj56_Delete
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		addq.w	#4,obY(a0)
		subi.w	#$28,obX(a0)

loc_18452:
		jmp	(DisplaySprite).l
; ===========================================================================

Obj56:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj56_Index(pc,d0.w),d1
		jmp	Obj56_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj56_Index:	dc.w Obj56_Init-Obj56_Index
		dc.w Obj56_Animate-Obj56_Index
; ---------------------------------------------------------------------------

Obj56_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj56,obMap(a0)
		move.w	#make_art_tile($5A0,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$80,obPriority(a0)
		clr.b	obColType(a0)
		move.b	#$C,obActWid(a0)
		move.b	#7,obTimeFrame(a0)
		clr.b	obFrame(a0)
		rts
; ---------------------------------------------------------------------------

Obj56_Animate:
		subq.b	#1,obTimeFrame(a0)
		bpl.s	loc_184BA
		move.b	#7,obTimeFrame(a0)
		addq.b	#1,obFrame(a0)
		cmpi.b	#7,obFrame(a0)
		beq.s	Obj56_Delete

loc_184BA:
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

Obj56_Delete:
		jmp	(DeleteObject).l
; ---------------------------------------------------------------------------
Map_Obj55a:	dc.w word_184C2-Map_Obj55a
		dc.w word_184CC-Map_Obj55a
word_184C2:	dc.w 1
		dc.w	 5,    0,    0,	 $1C		; 0
word_184CC:	dc.w 1
		dc.w	 5,    4,    2,	 $1C		; 0
Map_Obj55b:	dc.w word_184DE-Map_Obj55b
		dc.w word_184E8-Map_Obj55b
		dc.w word_184F2-Map_Obj55b
		dc.w word_184FC-Map_Obj55b
word_184DE:	dc.w 1
		dc.w $F805,    0,    0,$FFF8		; 0
word_184E8:	dc.w 1
		dc.w $F805,    4,    2,$FFF8		; 0
word_184F2:	dc.w 1
		dc.w $F805,    8,    4,$FFF8		; 0
word_184FC:	dc.w 1
		dc.w $F805,   $C,    6,$FFF8		; 0
Map_Obj56:	dc.w word_18514-Map_Obj56
		dc.w word_1851E-Map_Obj56
		dc.w word_18528-Map_Obj56
		dc.w word_18532-Map_Obj56
		dc.w word_1853C-Map_Obj56
		dc.w word_18546-Map_Obj56
		dc.w word_18550-Map_Obj56
word_18514:	dc.w 1
		dc.w $F805,    0,    0,$FFF8		; 0
word_1851E:	dc.w 1
		dc.w $F00F,    4,    2,$FFF0		; 0
word_18528:	dc.w 1
		dc.w $F00F,  $14,   $A,$FFF0		; 0
word_18532:	dc.w 1
		dc.w $F00F,  $24,  $12,$FFF0		; 0
word_1853C:	dc.w 1
		dc.w $F00F,  $34,  $1A,$FFF0		; 0
word_18546:	dc.w 1
		dc.w $F00F,  $44,  $22,$FFF0		; 0
word_18550:	dc.w 1
		dc.w $F00F,  $54,  $2A,$FFF0		; 0
Ani_Obj55a:	dc.w byte_1855E-Ani_Obj55a
		dc.w byte_18561-Ani_Obj55a
byte_1855E:	dc.b  $F,  0,$FF
byte_18561:	dc.b   7,  1,  2,$FF
		even

Map_Obj55:	dc.w word_1856C-Map_Obj55
		dc.w word_1858E-Map_Obj55
		dc.w word_185B0-Map_Obj55
word_1856C:	dc.w 4
		dc.w $F805,    0,    0,$FFE0		; 0
		dc.w  $805,    4,    2,$FFE0		; 4
		dc.w $F80F,    8,    4,$FFF0		; 8
		dc.w $F807,  $18,   $C,	 $10		; 12
word_1858E:	dc.w 4
		dc.w $E805,  $28,  $14,$FFE0		; 0
		dc.w $E80D,  $30,  $18,$FFF0		; 4
		dc.w $E805,  $24,  $12,	 $10		; 8
		dc.w $D805,  $20,  $10,	   2		; 12
word_185B0:	dc.w 4
		dc.w $E805,  $28,  $14,$FFE0		; 0
		dc.w $E80D,  $38,  $1C,$FFF0		; 4
		dc.w $E805,  $24,  $12,	 $10		; 8
		dc.w $D805,  $20,  $10,	   2		; 12
		even
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 90 - "SONIC TEAM PRESENTS" screen and credits
; ---------------------------------------------------------------------------

Credits:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Cred_Index(pc,d0.w),d1
		jmp	Cred_Index(pc,d1.w)
; ===========================================================================
Cred_Index:	dc.w Credits_Init-Cred_Index
		dc.w Credits_Display-Cred_Index
; ===========================================================================

Credits_Init:
		addq.b	#2,obRoutine(a0)
		move.w	#$120,obX(a0)
		move.w	#$F0,obScreenY(a0)
		move.l	#Map_Credits,obMap(a0)
		move.w	#make_art_tile(ArtTile_Credits_Font,0,0),obGfx(a0)
		move.w	(v_creditsnum).w,d0		; load credits index number
		move.b	d0,obFrame(a0)			; display appropriate credits
		sf	obRender(a0)

		cmpi.w	#TitleScreen,(v_gamemode).w	; but if this is the title screen...
		bne.s	Credits_Display
		move.w	#make_art_tile(ArtTile_SonicTeamPresents,0,0),obGfx(a0)	; we change the VRAM adress
		move.b	#$A,obFrame(a0)			; & manually display "SONIC TEAM PRESENTS"
; ===========================================================================
; loc_18660:
Credits_Display:
		jmp	(DisplaySprite).l
; ===========================================================================
; ---------------------------------------------------------------------------
; Sprite mappings - Sonic Team Presents/Credits
; ---------------------------------------------------------------------------
Map_Credits:	binclude	"mappings/sprite/Sonic Team Presents.bin"
		even
; ===========================================================================
		include "objects/S1/3D Boss - Green Hill.asm"
		include "objects/S1/48 Eggman's Swinging Ball.asm"
; ---------------------------------------------------------------------------
Ani_Eggman:	dc.w byte_192E0-Ani_Eggman
		dc.w byte_192E3-Ani_Eggman
		dc.w byte_192E7-Ani_Eggman
		dc.w byte_192EB-Ani_Eggman
		dc.w byte_192EF-Ani_Eggman
		dc.w byte_192F3-Ani_Eggman
		dc.w byte_192F7-Ani_Eggman
		dc.w byte_192FB-Ani_Eggman
		dc.w byte_192FE-Ani_Eggman
		dc.w byte_19302-Ani_Eggman
		dc.w byte_19306-Ani_Eggman
		dc.w byte_19309-Ani_Eggman
byte_192E0:	dc.b  $F,  0,$FF
byte_192E3:	dc.b   5,  1,  2,$FF
byte_192E7:	dc.b   3,  1,  2,$FF
byte_192EB:	dc.b   1,  1,  2,$FF
byte_192EF:	dc.b   4,  3,  4,$FF
byte_192F3:	dc.b $1F,  5,  1,$FF
byte_192F7:	dc.b   3,  6,  1,$FF
byte_192FB:	dc.b  $F, $A,$FF
byte_192FE:	dc.b   3,  8,  9,$FF
byte_19302:	dc.b   1,  8,  9,$FF
byte_19306:	dc.b  $F,  7,$FF
byte_19309:	dc.b   2,  9,  8, $B, $C, $B, $C,  9,  8,$FE,  2
		even

Map_Eggman:	dc.w word_1932E-Map_Eggman
		dc.w word_19360-Map_Eggman
		dc.w word_19372-Map_Eggman
		dc.w word_19384-Map_Eggman
		dc.w word_1939E-Map_Eggman
		dc.w word_193B8-Map_Eggman
		dc.w word_193D2-Map_Eggman
		dc.w word_193EC-Map_Eggman
		dc.w word_1940E-Map_Eggman
		dc.w word_19418-Map_Eggman
		dc.w word_19422-Map_Eggman
		dc.w word_19424-Map_Eggman
		dc.w word_19436-Map_Eggman
word_1932E:	dc.w 6
		dc.w $EC01,   $A,    5,$FFE4
		dc.w $EC05,   $C,    6,	  $C
		dc.w $FC0E,$2010,$2008,$FFE4
		dc.w $FC0E,$201C,$200E,	   4
		dc.w $140C,$2028,$2014,$FFEC
		dc.w $1400,$202C,$2016,	  $C
word_19360:	dc.w 2
		dc.w $E404,    0,    0,$FFF4
		dc.w $EC0D,    2,    1,$FFEC
word_19372:	dc.w 2
		dc.w $E404,    0,    0,$FFF4
		dc.w $EC0D,  $35,  $1A,$FFEC
word_19384:	dc.w 3
		dc.w $E408,  $3D,  $1E,$FFF4
		dc.w $EC09,  $40,  $20,$FFEC
		dc.w $EC05,  $46,  $23,	   4
word_1939E:	dc.w 3
		dc.w $E408,  $4A,  $25,$FFF4
		dc.w $EC09,  $4D,  $26,$FFEC
		dc.w $EC05,  $53,  $29,	   4
word_193B8:	dc.w 3
		dc.w $E408,  $57,  $2B,$FFF4
		dc.w $EC09,  $5A,  $2D,$FFEC
		dc.w $EC05,  $60,  $30,	   4
word_193D2:	dc.w 3
		dc.w $E404,  $64,  $32,	   4
		dc.w $E404,    0,    0,$FFF4
		dc.w $EC0D,  $35,  $1A,$FFEC
word_193EC:	dc.w 4
		dc.w $E409,  $66,  $33,$FFF4
		dc.w $E408,  $57,  $2B,$FFF4
		dc.w $EC09,  $5A,  $2D,$FFEC
		dc.w $EC05,  $60,  $30,	   4
word_1940E:	dc.w 1
		dc.w  $405,  $2D,  $16,	 $22
word_19418:	dc.w 1
		dc.w  $405,  $31,  $18,	 $22
word_19422:	dc.w 0
word_19424:	dc.w 2
		dc.w	 8, $12A, $195,	 $22
		dc.w  $808,$112A,$1995,	 $22
word_19436:	dc.w 2
		dc.w $F80B, $12D, $199,	 $22
		dc.w	 1, $139, $1AB,	 $3A
Map_BossItems:	dc.w word_19458-Map_BossItems
		dc.w word_19462-Map_BossItems
		dc.w word_19474-Map_BossItems
		dc.w word_1947E-Map_BossItems
		dc.w word_19488-Map_BossItems
		dc.w word_19492-Map_BossItems
		dc.w word_194B4-Map_BossItems
		dc.w word_194C6-Map_BossItems
word_19458:	dc.w 1
		dc.w $F805,    0,    0,$FFF8
word_19462:	dc.w 2
		dc.w $FC04,    4,    2,$FFF8
		dc.w $F805,    0,    0,$FFF8
word_19474:	dc.w 1
		dc.w $FC00,    6,    3,$FFFC
word_1947E:	dc.w 1
		dc.w $1409,    7,    3,$FFF4
word_19488:	dc.w 1
		dc.w $1405,   $D,    6,$FFF8
word_19492:	dc.w 4
		dc.w $F004,  $11,    8,$FFF8
		dc.w $F801,  $13,    9,$FFF8
		dc.w $F801, $813, $809,	   0
		dc.w  $804,  $15,   $A,$FFF8
word_194B4:	dc.w 2
		dc.w	 5,  $17,   $B,	   0
		dc.w	 0,  $1B,   $D,	 $10
word_194C6:	dc.w 2
		dc.w $1804,  $1C,   $E,	   0
		dc.w	$B,  $1E,   $F,	 $10

; =============== S U B R O U T I N E =======================================


BossDefeated:
		move.b	(Vint_runcount+3).w,d0
		andi.b	#7,d0
		bne.s	locret_18EA0
		jsr	(FindFreeObj).l
		bne.s	locret_18EA0
		_move.b	#id_Obj3F,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		jsr	(RandomNumber).l
		move.w	d0,d1
		moveq	#0,d1
		move.b	d0,d1
		lsr.b	#2,d1
		subi.w	#$20,d1
		add.w	d1,obX(a1)
		lsr.w	#8,d0
		lsr.b	#3,d0
		add.w	d0,obY(a1)

locret_18EA0:
		rts
; End of function BossDefeated

; ---------------------------------------------------------------------------
; Object 3E - prison capsule
;----------------------------------------------------------------------------

Obj3E:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj3E_Index(pc,d0.w),d1
		jsr	Obj3E_Index(pc,d1.w)
		out_of_range2	DeleteObject
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------
Obj3E_Index:	dc.w Obj3E_Init-Obj3E_Index
		dc.w Obj3E_BodyMain-Obj3E_Index
		dc.w Obj3E_Switched-Obj3E_Index
		dc.w Obj3E_Explosion-Obj3E_Index
		dc.w Obj3E_Explosion-Obj3E_Index
		dc.w Obj3E_Explosion-Obj3E_Index
		dc.w Obj3E_Animals-Obj3E_Index
		dc.w Obj3E_EndAct-Obj3E_Index
Obj3E_Var:	dc.b   2,$20,  4,  0
		dc.b   4, $C,  5,  1
		dc.b   6,$10,  4,  3
		dc.b   8,$10,  3,  5
; ---------------------------------------------------------------------------

Obj3E_Init:
		move.l	#Map_Obj3E,obMap(a0)
		move.w	#make_art_tile(ArtTile_Prison_Capsule,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	obY(a0),objoff_30(a0)
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		lsl.w	#2,d0
		lea	Obj3E_Var(pc,d0.w),a1
		move.b	(a1)+,obRoutine(a0)
		move.b	(a1)+,obActWid(a0)
		move.b	(a1)+,obPriority(a0)
		move.w	obPriority(a0),d0
		lsr.w	#1,d0
		andi.w	#$380,d0
		move.w	d0,obPriority(a0)
		move.b	(a1)+,obFrame(a0)
		cmpi.w	#8,d0
		bne.s	.return
		move.b	#6,obColType(a0)
		move.b	#8,obColProp(a0)

.return:
		rts
; ---------------------------------------------------------------------------

Obj3E_BodyMain:
		cmpi.b	#2,(Boss_defeated_flag).w
		beq.s	loc_1959C
		moveq	#$2B,d1
		moveq	#$18,d2
		moveq	#$18,d3
		move.w	obX(a0),d4
		jmp	(SolidObject).l
; ---------------------------------------------------------------------------

loc_1959C:
		tst.b	ob2ndRout(a0)
		beq.s	loc_195B2
		clr.b	ob2ndRout(a0)
		bclr	#3,(v_objspace+obStatus).w
		bset	#1,(v_objspace+obStatus).w

loc_195B2:
		move.b	#2,obFrame(a0)
		rts
; ---------------------------------------------------------------------------

Obj3E_Switched:
		move.w	#$17,d1
		move.w	#8,d2
		move.w	#8,d3
		move.w	obX(a0),d4
		jsr	(SolidObject).l
		lea	Ani_Obj3E(pc),a1
		jsr	(AnimateSprite).l
		move.w	objoff_30(a0),obY(a0)
		move.b	obStatus(a0),d0
		andi.b	#$18,d0
		beq.s	locret_19620
		addq.w	#8,obY(a0)
		move.b	#$A,obRoutine(a0)
		move.b	#60,obTimeFrame(a0)
		clr.b	(f_timecount).w
		clr.b	(f_lockscreen).w
		move.b	#1,(f_lockctrl).w
		move.w	#8<<btnR,(v_jpadholdlogical).w
		clr.b	ob2ndRout(a0)
		bclr	#3,(v_objspace+obStatus).w
		bset	#1,(v_objspace+obStatus).w

locret_19620:
		rts
; ---------------------------------------------------------------------------

Obj3E_Explosion:
		moveq	#7,d0
		and.b	(Vint_runcount+3).w,d0
		bne.s	loc_19660
		jsr	(FindFreeObj).l
		bne.s	loc_19660
		_move.b	#id_Obj3F,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		jsr	(RandomNumber).l
		moveq	#0,d1
		move.b	d0,d1
		lsr.b	#2,d1
		subi.w	#$20,d1
		add.w	d1,obX(a1)
		lsr.w	#8,d0
		lsr.b	#3,d0
		add.w	d0,obY(a1)

loc_19660:
		subq.b	#1,obTimeFrame(a0)
		beq.s	loc_19668
		rts
; ---------------------------------------------------------------------------

loc_19668:
		move.b	#2,(Boss_defeated_flag).w
		move.b	#$C,obRoutine(a0)
		move.b	#6,obFrame(a0)
		move.b	#150,obTimeFrame(a0)
		addi.w	#$20,obY(a0)
		moveq	#7,d6
		move.w	#$9A,d5
		moveq	#-$1C,d4

-		jsr	(FindFreeObj).l
		bne.s	.return
		_move.b	#id_Obj28,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		add.w	d4,obX(a1)
		addq.w	#7,d4
		move.w	d5,objoff_36(a1)
		subq.w	#8,d5
		dbf	d6,-

.return:
		rts
; ---------------------------------------------------------------------------

Obj3E_Animals:
		moveq	#7,d0
		and.b	(Vint_runcount+3).w,d0
		bne.s	loc_196F8
		jsr	(FindFreeObj).l
		bne.s	loc_196F8
		_move.b	#id_Obj28,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		jsr	(RandomNumber).l
		andi.w	#$1F,d0
		subq.w	#6,d0
		tst.w	d1
		bpl.s	loc_196EE
		neg.w	d0

loc_196EE:
		add.w	d0,obX(a1)
		move.w	#$C,objoff_36(a1)

loc_196F8:
		subq.b	#1,obTimeFrame(a0)
		bne.s	.return
		addq.b	#2,obRoutine(a0)
		move.b	#60*3,obTimeFrame(a0)

.return:
		rts
; ---------------------------------------------------------------------------

Obj3E_EndAct:
		moveq	#id_Obj3E,d0
		moveq	#id_Obj28,d1
		moveq	#object_size,d2
		lea	(v_player2).w,a1
-		cmp.b	(a1),d1
		beq.s	loc_196F8.return
		adda.w	d2,a1
		dbf	d0,-

		jsr	(Load_EndOfAct).l
		jmp	(DeleteObject).l
; ---------------------------------------------------------------------------
Ani_Obj3E:	dc.w byte_19730-Ani_Obj3E
		dc.w byte_19730-Ani_Obj3E
byte_19730:	dc.b 2,	1,	3,	$FF
		even

Map_Obj3E:	dc.w word_19742-Map_Obj3E
		dc.w word_1977C-Map_Obj3E
		dc.w word_19786-Map_Obj3E
		dc.w word_197B8-Map_Obj3E
		dc.w word_197C2-Map_Obj3E
		dc.w word_197D4-Map_Obj3E
		dc.w word_197DE-Map_Obj3E
word_19742:	dc.w 7
		dc.w $E00C,$2000,$2000,$FFF0
		dc.w $E80D,$2004,$2002,$FFE0
		dc.w $E80D,$200C,$2006,	   0
		dc.w $F80E,$2014,$200A,$FFE0
		dc.w $F80E,$2020,$2010,	   0
		dc.w $100D,$202C,$2016,$FFE0
		dc.w $100D,$2034,$201A,	   0
word_1977C:	dc.w 1
		dc.w $F809,  $3C,  $1E,$FFF4
word_19786:	dc.w 6
		dc.w	 8,$2042,$2021,$FFE0
		dc.w  $80C,$2045,$2022,$FFE0
		dc.w	 4,$2049,$2024,	 $10
		dc.w  $80C,$204B,$2025,	   0
		dc.w $100D,$202C,$2016,$FFE0
		dc.w $100D,$2034,$201A,	   0
word_197B8:	dc.w 1
		dc.w $F809,  $4F,  $27,$FFF4
word_197C2:	dc.w 2
		dc.w $E80E,$2055,$202A,$FFF0
		dc.w	$E,$2061,$2030,$FFF0
word_197D4:	dc.w 1
		dc.w $F007,$206D,$2036,$FFF8
word_197DE:	dc.w 0
		even
; ---------------------------------------------------------------------------

; =============== S U B R O U T I N E =======================================


TouchResponse:
		jsr	(Touch_Rings).l
		move.w	obX(a0),d2
		move.w	obY(a0),d3
		subq.w	#8,d2
		moveq	#0,d5
		move.b	obHeight(a0),d5
		subq.b	#3,d5
		sub.w	d5,d3
		cmpi.b	#AniIDSonAni_Duck,obAnim(a0)
		bne.s	loc_19812
		addi.w	#$C,d3
		moveq	#$A,d5

loc_19812:
		move.w	#$10,d4
		add.w	d5,d5
		lea	(v_lvlobjspace).w,a1
		move.w	#(v_lvlobjend-v_lvlobjspace)/object_size-1,d6

loc_19820:
		move.b	obColType(a1),d0
		bne.s	Touch_Height

loc_19826:
		lea	object_size(a1),a1
		dbf	d6,loc_19820
		moveq	#0,d0
		rts
; ---------------------------------------------------------------------------
Touch_Sizes:	dc.b $14,$14
		dc.b  $C,$14
		dc.b $14, $C
		dc.b   4,$10
		dc.b  $C,$12
		dc.b $10,$10
		dc.b   6,  6
		dc.b $18, $C
		dc.b  $C,$10
		dc.b $10, $C
		dc.b   8,  8
		dc.b $14,$10
		dc.b $14,  8
		dc.b  $E, $E
		dc.b $18,$18
		dc.b $28,$10
		dc.b $10,$18
		dc.b   8,$10
		dc.b $20,$70
		dc.b $40,$20
		dc.b $80,$20
		dc.b $20,$20
		dc.b   8,  8
		dc.b   4,  4
		dc.b $20,  8
		dc.b  $C, $C
		dc.b   8,  4
		dc.b $18,  4
		dc.b $28,  4
		dc.b   4,  8
		dc.b   4,$18
		dc.b   4,$28
		dc.b   4,$20
		dc.b $18,$18
		dc.b  $C,$18
		dc.b $48,  8
; ---------------------------------------------------------------------------

Touch_Height:
		andi.w	#$3F,d0
		add.w	d0,d0
		lea	Touch_Sizes-2(pc,d0.w),a2
		moveq	#0,d1
		move.b	(a2)+,d1
		move.w	obX(a1),d0
		sub.w	d1,d0
		sub.w	d2,d0
		bhs.s	loc_1989C
		add.w	d1,d1
		add.w	d1,d0
		blo.s	loc_198A2
		bra.w	loc_19826
; ---------------------------------------------------------------------------

loc_1989C:
		cmp.w	d4,d0
		bhi.w	loc_19826

loc_198A2:
		moveq	#0,d1
		move.b	(a2)+,d1
		move.w	obY(a1),d0
		sub.w	d1,d0
		sub.w	d3,d0
		bhs.s	loc_198BA
		add.w	d1,d1
		add.w	d1,d0
		blo.s	loc_198C0
		bra.w	loc_19826
; ---------------------------------------------------------------------------

loc_198BA:
		cmp.w	d5,d0
		bhi.w	loc_19826

loc_198C0:
		move.b	obColType(a1),d1
		andi.b	#$C0,d1
		beq.w	Touch_Enemy
		cmpi.b	#$C0,d1
		beq.s	Touch_Special
		tst.b	d1
		bmi.w	Touch_Hurt
		move.b	obColType(a1),d0
		andi.b	#$3F,d0
		cmpi.b	#6,d0
		beq.s	loc_198FA
		cmpi.w	#90,flashtime(a0)
		bhs.s	.return
		move.b	#4,obRoutine(a1)
.return:	rts
; ---------------------------------------------------------------------------

loc_198FA:
		tst.w	obVelY(a0)
		bpl.s	loc_19926
		move.w	obY(a0),d0
		subi.w	#$10,d0
		cmp.w	obY(a1),d0
		blo.s	loc_19912.return

loc_1990E:
		neg.w	obVelY(a0)

loc_19912:
		move.w	#-$180,obVelY(a1)
		tst.b	ob2ndRout(a1)
		bne.s	.return
		move.b	#4,ob2ndRout(a1)
.return:	rts
; ---------------------------------------------------------------------------

loc_19926:
		cmpi.b	#AniIDSonAni_Roll,obAnim(a0)
		bne.s	.return
		neg.w	obVelY(a0)
		move.b	#4,obRoutine(a1)
.return:	rts
; ---------------------------------------------------------------------------

Touch_Special:
		move.b	obColType(a1),d1	; Get collision_flags
		andi.b	#$3F,d1			; Get only collision size (but that doesn't seems to be its use here?)
		cmpi.b	#6,d1
		beq.s	Touch_D7
		cmpi.b	#7,d1
		beq.w	Touch_Unknown
		cmpi.b	#$A,d1
		beq.s	Touch_D7
		cmpi.b	#$B,d1
		beq.w	Touch_Caterkiller
		cmpi.b	#$C,d1
		beq.s	Touch_Yadrin
		cmpi.b	#$14,d1
		beq.s	Touch_D7
		cmpi.b	#$15,d1
		beq.s	Touch_D7
		cmpi.b	#$16,d1
		beq.s	Touch_D7
		cmpi.b	#$17,d1
		beq.s	Touch_D7
		cmpi.b	#$18,d1
		beq.s	Touch_D7
		cmpi.b	#$1A,d1
		beq.s	Touch_Inv
		cmpi.b	#$21,d1
		beq.s	Touch_E1
		rts
; ---------------------------------------------------------------------------

Touch_Yadrin:
		sub.w	d0,d5
		cmpi.w	#8,d5
		bhs.s	Touch_Enemy
		move.w	obX(a1),d0
		subq.w	#4,d0
		btst	#0,obStatus(a1)
		beq.s	loc_19B42
		subi.w	#$10,d0

loc_19B42:
		sub.w	d2,d0
		bhs.s	loc_19B4E
		addi.w	#$18,d0
		blo.w	Touch_Hurt
		bra.s	Touch_Enemy
; ---------------------------------------------------------------------------

loc_19B4E:
		cmp.w	d4,d0
		bhi.s	Touch_Enemy
		bra.w	Touch_Hurt
; ---------------------------------------------------------------------------

Touch_D7:
		move.w	a0,d1
		subi.w	#v_player,d1
		beq.s	Touch_E1
		addq.b	#1,obColProp(a1)

Touch_E1:
		addq.b	#1,obColProp(a1)
		rts
; ---------------------------------------------------------------------------

Touch_Unknown:	; Touch_E2?
		move.b	#2,obColProp(a1)	; set collision property to 2 (?)
		bra.s	Touch_Enemy
; ---------------------------------------------------------------------------

Touch_Inv:	; Touch_E3?
		st	obColProp(a1)	; set to -1 (as if invulnerable?)
	;	bra.s	Touch_Enemy
; ---------------------------------------------------------------------------

Touch_Enemy:
		btst	#obStatusSecondary_isInvincible,obStatusSecondary(a0)	; is Sonic invincible?
		bne.s	.noharm			; if yes, branch
		cmpi.b	#AniIDSonAni_Spindash,obAnim(a0)
		beq.s	.noharm
		cmpi.b	#AniIDSonAni_Roll,obAnim(a0)
		bne.w	Touch_Hurt

.noharm:
		tst.b	obColProp(a1)
		beq.s	Touch_KillEnemy	; skip if zero
		neg.w	obVelX(a0)
		neg.w	obVelY(a0)
		asr	obVelX(a0)
		asr	obVelY(a0)
		clr.b	obColType(a1)
		subq.b	#1,obColProp(a1)
		bne.s	.return
		bset	#7,obStatus(a1)
.return:	rts
; ---------------------------------------------------------------------------

Touch_KillEnemy:
		bset	#7,obStatus(a1)
		moveq	#0,d0
		move.w	(v_itembonus).w,d0
		addq.w	#2,(v_itembonus).w
		cmpi.w	#6,d0
		blo.s	loc_19994
		moveq	#6,d0

loc_19994:
		move.w	d0,objoff_3E(a1)
		move.w	Enemy_Points(pc,d0.w),d0
		cmpi.w	#$20,(v_itembonus).w
		blo.s	loc_199AE
		move.w	#1000,d0
		move.w	#10,objoff_3E(a1)

loc_199AE:
		bsr.w	AddPoints
		_move.b	#id_Obj27,obID(a1)
		clr.b	obRoutine(a1)
		tst.w	obVelY(a0)
		bmi.s	loc_199D4
		move.w	obY(a0),d0
		cmp.w	obY(a1),d0
		bhs.s	loc_199DC
		neg.w	obVelY(a0)
		rts
; ---------------------------------------------------------------------------

loc_199D4:
		addi.w	#$100,obVelY(a0)
		rts
; ---------------------------------------------------------------------------

loc_199DC:
		subi.w	#$100,obVelY(a0)
		rts
; ---------------------------------------------------------------------------
Enemy_Points:
		dc.w 10, 20, 50, 100
; ---------------------------------------------------------------------------

Touch_Caterkiller:
		bset	#7,obStatus(a1)

Touch_Hurt:
		tst.b	(v_invinc).w
		bne.w	Hurt_ChkSpikes.exit
		tst.w	flashtime(a0)
		bne.w	Hurt_ChkSpikes.exit
		movea.l	a1,a2
; End of function TouchResponse

; =============== S U B R O U T I N E =======================================


HurtSonic:
		tst.b	(v_shield).w
		bne.s	HurtShield
		tst.w	(v_rings).w
		bne.s	.skip
		tst.b	(Debug_mode_flag).w
		bne.s	HurtShield
		bra.w	KillSonic
.skip:
		jsr	(FindFreeObj).l
		bne.s	HurtShield
		_move.b	#id_Obj37,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)

HurtShield:
		clr.b	(v_shield).w
		move.b	#4,obRoutine(a0)
		jsr	(Sonic_ResetOnFloor).l
		bset	#1,obStatus(a0)
		move.w	#-$400,obVelY(a0)
		move.w	#-$200,obVelX(a0)
		btst	#6,obStatus(a0)
		beq.s	Hurt_Reverse
		move.w	#-$200,obVelY(a0)
		move.w	#-$100,obVelX(a0)

Hurt_Reverse:
		move.w	obX(a0),d0
		cmp.w	obX(a2),d0
		blo.s	Hurt_ChkSpikes
		neg.w	obVelX(a0)

Hurt_ChkSpikes:
		clr.w	obInertia(a0)
		move.b	#AniIDSonAni_Hurt,obAnim(a0)
		move.w	#60*2,flashtime(a0)
-		move.w	#sfx_Death,d0
		cmpi.b	#id_Obj36,obID(a2)
		bne.s	+
;		cmpi.b	#id_Obj16,obID(a2)	; Used to be the LZ Harpoon in Sonic 1
;		bne.s	+			; It's been replaced by the HTZ lifts
		move.w	#sfx_HitSpikes,d0
+		jsr	(PlaySound_Special).l
.exit:
		moveq	#-1,d0
		rts
; End of function HurtSonic


; =============== S U B R O U T I N E =======================================


KillSonic:
		tst.w	(Debug_placement_mode).w
		bne.s	.exit
		clr.b	(v_invinc).w
		move.b	#6,obRoutine(a0)
		jsr	(Sonic_ResetOnFloor).l
		bset	#1,obStatus(a0)
		move.w	#-$700,obVelY(a0)
		clr.w	obVelX(a0)
		clr.w	obInertia(a0)
		move.w	obY(a0),objoff_38(a0)
		move.b	#AniIDSonAni_Death,obAnim(a0)
		bset	#7,obGfx(a0)
		move.w	#sfx_Death,d0
		cmpi.b	#id_Obj36,obID(a2)
		bne.s	+
;		cmpi.b	#id_Obj16,obID(a2)	; Used to be the LZ Harpoon in Sonic 1
;		bne.s	+			; It's been replaced by the HTZ lifts
		move.w	#sfx_HitSpikes,d0
+		jsr	(PlaySound_Special).l
.exit:
		moveq	#-1,d0
		rts

; End of function KillSonic

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to animate stage art
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; DynamicArtCues:
Animate_Tiles:
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
		add.w	d0,d0
		add.w	d0,d0
		move.w	DynArtCue_Index+2(pc,d0.w),d1
		lea	DynArtCue_Index(pc,d1.w),a2
		move.w	DynArtCue_Index(pc,d0.w),d0
		jmp	DynArtCue_Index(pc,d0.w)
; End of function Animate_Tiles

; ---------------------------------------------------------------------------
; ZONE ANIMATION PROCEDURES AND SCRIPTS
;
; Each zone gets two entries in this jump table. The first entry points to the
; zone's animation procedure (usually Dynamic_Null, AKA none). The second points
; to the zone's animation script.
;
; Seems like stage IDs were already being shifted, since listings for $07-$0F
; can be found, alongside HPZ's art listed from $08 (its ID in the final).
; ---------------------------------------------------------------------------
DynArtCue_Index:
		dc.w Dynamic_NullGHZ-DynArtCue_Index	; GHZ
		dc.w Dynamic_Null-DynArtCue_Index	; GHZ
		dc.w Dynamic_Null-DynArtCue_Index	; LZ
		dc.w Dynamic_Null-DynArtCue_Index	; LZ
		dc.w Dynamic_Normal-DynArtCue_Index	; CPZ
		dc.w Animated_CPZ-DynArtCue_Index	; CPZ
		dc.w Dynamic_Normal-DynArtCue_Index	; EHZ
		dc.w AnimCue_EHZ-DynArtCue_Index	; EHZ
		dc.w Dynamic_Normal-DynArtCue_Index	; HPZ
		dc.w AnimCue_HPZ-DynArtCue_Index	; HPZ
		dc.w Dynamic_Normal-DynArtCue_Index	; HTZ
		dc.w AnimCue_EHZ-DynArtCue_Index	; HTZ
		dc.w Dynamic_Null-DynArtCue_Index	; 06
		dc.w Dynamic_Null-DynArtCue_Index	; 06
		dc.w Dynamic_Null-DynArtCue_Index	; 07
		dc.w Dynamic_Null-DynArtCue_Index	; 07
		dc.w Dynamic_Normal-DynArtCue_Index	; 08
		dc.w Dynamic_Null-DynArtCue_Index	; 08
		dc.w Dynamic_Null-DynArtCue_Index	; 09
		dc.w Dynamic_Null-DynArtCue_Index	; 09
		dc.w Dynamic_Null-DynArtCue_Index	; 0A
		dc.w Dynamic_Null-DynArtCue_Index	; 0A
		dc.w Dynamic_Null-DynArtCue_Index	; 0B
		dc.w Dynamic_Null-DynArtCue_Index	; 0B
		dc.w Dynamic_Null-DynArtCue_Index	; 0C
		dc.w Dynamic_Null-DynArtCue_Index	; 0C
		dc.w Dynamic_Null-DynArtCue_Index	; 0D
		dc.w Dynamic_Null-DynArtCue_Index	; 0D
		dc.w Dynamic_Null-DynArtCue_Index	; 0E
		dc.w Dynamic_Null-DynArtCue_Index	; 0E
		dc.w Dynamic_Null-DynArtCue_Index	; 0F
		dc.w Dynamic_Null-DynArtCue_Index	; 0F
; ===========================================================================

Dynamic_Null:
		rts
; ===========================================================================

Dynamic_NullGHZ:
		rts
; ===========================================================================

Dynamic_Normal:
		lea	(Anim_Counters).w,a3
;.customCounters:
		move.w	(a2)+,d6	; Get number of scripts in list
		bmi.s	.exit		; If there's none, bail

.loop:
		subq.b	#1,(a3)		; Tick down frame duration
		bcc.s	.nextscript	; If frame isn't over, move on to next script

;.nextframe:
		moveq	#0,d0
		move.b	1(a3),d0	; Get current frame
		cmp.b	6(a2),d0	; Have we processed the last frame in the script?
		blo.s	.notlastframe
		moveq	#0,d0		; If so, reset to first frame
		move.b	d0,1(a3)	; ''
; loc_3FF48:
.notlastframe:
		addq.b	#1,1(a3)	; Consider this frame processed; set counter to next frame
		move.b	(a2),(a3)	; Set frame duration to global duration value
		bpl.s	.globalduration
		; If script uses per-frame durations, use those instead
		add.w	d0,d0
		move.b	9(a2,d0.w),(a3)	; Set frame duration to current frame's duration value
; loc_3FF56:
.globalduration:
; Prepare for DMA transfer
		; Get relative address of frame's art
		move.b	8(a2,d0.w),d0	; Get tile ID
		lsl.w	#5,d0		; Turn it into an offset
		; Get VRAM destination address
		move.w	4(a2),d2
		; Get ROM source address
		move.l	(a2),d1		; Get start address of animated tile art
		andi.l	#$FFFFFF,d1
		add.l	d0,d1		; Offset into art, to get the address of new frame
		; Get size of art to be transferred
		moveq	#0,d3
		move.b	7(a2),d3
		lsl.w	#4,d3		; Turn it into actual size (in words)
		; Use d1, d2 and d3 to queue art for transfer
		jsr	(QueueDMATransfer).l
; loc_3FF78:
.nextscript:
		move.b	6(a2),d0	; Get total size of frame data
		tst.b	(a2)		; Is per-frame duration data present?
		bpl.s	.globalduration2; If not, keep the current size; it's correct
		add.b	d0,d0		; Double size to account for the additional frame duration data
; loc_3FF82:
.globalduration2:
		addq.b	#1,d0
		andi.w	#$FE,d0		; Round to next even address, if it isn't already
		lea	8(a2,d0.w),a2	; Advance to next script in list
		addq.w	#2,a3		; Advance to next script's slot in a3 (usually Anim_Counters)
		dbf	d6,.loop
.exit:
		rts
; ===========================================================================
; ZONE ANIMATION SCRIPTS
;
; The Dynamic_Normal subroutine uses these scripts to reload certain tiles,
; thus animating them. All the relevant art must be uncompressed, because
; otherwise the subroutine would spend so much time waiting for the art to be
; decompressed that the VBLANK window would close before all the animating was done.
;
;    zoneanimdecl -1, Art_Flowers1, ArtTile_Art_Flowers1, 6, 2
;	-1			Global frame duration. If -1, then each frame will use its own duration, instead
;	ArtUnc_Flowers1		Source address
;	ArtTile_ArtUnc_Flowers1	Destination VRAM address
;	6			Number of frames
;	2			Number of tiles to load into VRAM for each frame
;
;    dc.b   0,$7F		; Start of the script proper
;	0			Tile ID of first tile in ArtUnc_Flowers1 to transfer
;	$7F			Frame duration. Only here if global duration is -1


AnimCue_EHZ:	zoneanimstart
		; Flowers
		zoneanimdecl -1, Art_Flowers1, ArtTile_Art_Flowers1, 6, 2
		dc.b   0,$7F		; Start of the script proper
		dc.b   2,$13
		dc.b   0,  7
		dc.b   2,  7
		dc.b   0,  7
		dc.b   2,  7
		even
		; Flowers
		zoneanimdecl -1, Art_Flowers2, ArtTile_Art_Flowers2, 8, 2
		dc.b   2,$7F
		dc.b   0, $B
		dc.b   2, $B
		dc.b   0, $B
		dc.b   2,  5
		dc.b   0,  5
		dc.b   2,  5
		dc.b   0,  5
		even
		; Flowers
		zoneanimdecl 7, Art_Flowers3, ArtTile_Art_Flowers3, 2, 2
		dc.b   0
		dc.b   2
		even
		; Flowers
		zoneanimdecl -1, Art_Flowers4, ArtTile_Art_Flowers4, 8, 2
		dc.b   0,$7F
		dc.b   2,  7
		dc.b   0,  7
		dc.b   2,  7
		dc.b   0,  7
		dc.b   2, $B
		dc.b   0, $B
		dc.b   2, $B
		even
		; Pulsing thing against checkered background
		zoneanimdecl 1, Art_EHZPulseBall, ArtTile_Art_EHZPulseBall, 6, 2
		dc.b   0,  2
		dc.b   4,  6
		dc.b   4,  2
		even
		zoneanimend

Animated_CPZ:	zoneanimstart
		; Animated background section in CPZ and DEZ
		zoneanimdecl 4, Art_CPZAnimBGPlates, ArtTile_ArtUnc_CPZAnimBack, 8, 2
		dc.b   0
		dc.b   2
		dc.b   4
		dc.b   6
		dc.b   8
		dc.b  $A
		dc.b  $C
		dc.b  $E
		even
	zoneanimend



AnimCue_HPZ:	zoneanimstart
		; Pulsing orb from HPZ
		zoneanimdecl 8, Art_HPZPulseOrb, ArtTile_Art_HPZPulseOrb_1, 6, 8
		dc.b   0
		dc.b   0
		dc.b   8
		dc.b $10
		dc.b $10
		dc.b   8
		even
		; Pulsing orb from HPZ
		zoneanimdecl 8, Art_HPZPulseOrb, ArtTile_Art_HPZPulseOrb_2, 6, 8
		dc.b   8
		dc.b $10
		dc.b $10
		dc.b   8
		dc.b   0
		dc.b   0
		even
		; Pulsing orb from HPZ
		zoneanimdecl 8, Art_HPZPulseOrb, ArtTile_Art_HPZPulseOrb_3, 6, 8
		dc.b $10
		dc.b   8
		dc.b   0
		dc.b   0
		dc.b   8
		dc.b $10
		even
		zoneanimend

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to load animated blocks
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; LoadMap16Delta:
LoadAnimatedBlocks:
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
		add.w	d0,d0
		move.w	AnimPatMaps(pc,d0.w),d0
		lea	AnimPatMaps(pc,d0.w),a0
		tst.w	(a0)
		beq.s	.return
		lea	(v_16x16).w,a1
		adda.w	(a0)+,a1
		move.w	(a0)+,d1
; loc_1AD14:
.LoadLevelBlocks:
		move.w	(a0)+,(a1)+
		dbf	d1,.LoadLevelBlocks

.return:
		rts
; End of function LoadAnimatedBlocks

; ===========================================================================
; like with the animated stage art, this already lists stages up to $0F and
; includes an entry for the final HPZ level slot, and this time even lists
; CPZ's final level slot
; Map16Delta_Index:
AnimPatMaps:
		dc.w APM_None-AnimPatMaps	; GHZ
		dc.w APM_None-AnimPatMaps	; LZ
		dc.w APM_CPZ-AnimPatMaps	; CPZ
		dc.w APM_EHZ-AnimPatMaps	; EHZ
		dc.w APM_HPZ-AnimPatMaps	; HPZ
		dc.w APM_EHZ-AnimPatMaps	; HTZ
		dc.w APM_None-AnimPatMaps	; 06
		dc.w APM_None-AnimPatMaps	; 07
		dc.w APM_HPZ-AnimPatMaps	; 08
		dc.w APM_None-AnimPatMaps	; 09
		dc.w APM_None-AnimPatMaps	; 0A
		dc.w APM_None-AnimPatMaps	; 0B
		dc.w APM_None-AnimPatMaps	; 0C
		dc.w APM_None-AnimPatMaps	; 0D
		dc.w APM_None-AnimPatMaps	; 0E
		dc.w APM_None-AnimPatMaps	; 0F
		dc.w APM_None-AnimPatMaps	; 10

begin_animpat macro {INTLABEL}
__LABEL__ label *
__LABEL___Len := __LABEL___End - __LABEL___Blocks
	dc.w $1800 - __LABEL___Len
	dc.w bytesToWcnt(__LABEL___Len)
__LABEL___Blocks:
    endm

APM_EHZ:	begin_animpat
		dc.w make_block_tile(ArtTile_Art_EHZPulseBall+$0,0,0,2,0),make_block_tile(ArtTile_Art_EHZPulseBall+$0,1,0,2,0)
		dc.w make_block_tile(ArtTile_Art_EHZPulseBall+$1,0,0,2,0),make_block_tile(ArtTile_Art_EHZPulseBall+$1,1,0,2,0)

		dc.w make_block_tile(ArtTile_Checkers+$0,1,0,2,0),make_block_tile(ArtTile_Art_EHZPulseBall+$0,0,0,2,0)
		dc.w make_block_tile(ArtTile_Checkers+$0,0,0,2,0),make_block_tile(ArtTile_Art_EHZPulseBall+$1,0,0,2,0)

		dc.w make_block_tile(ArtTile_Art_EHZPulseBall+$0,1,0,2,0),make_block_tile(ArtTile_Checkers+$0,0,0,2,0)
		dc.w make_block_tile(ArtTile_Art_EHZPulseBall+$1,1,0,2,0),make_block_tile(ArtTile_Checkers+$0,1,0,2,0)

		dc.w make_block_tile(ArtTile_Art_Flowers1+$0,0,0,3,0),make_block_tile(ArtTile_Art_Flowers1+$0,1,0,3,0)
		dc.w make_block_tile(ArtTile_Art_Flowers1+$1,0,0,3,0),make_block_tile(ArtTile_Art_Flowers1+$1,1,0,3,0)

		dc.w make_block_tile(ArtTile_Art_Flowers2+$0,0,0,3,1),make_block_tile(ArtTile_Art_Flowers2+$0,1,0,3,1)
		dc.w make_block_tile(ArtTile_Art_Flowers2+$1,0,0,3,1),make_block_tile(ArtTile_Art_Flowers2+$1,1,0,3,1)

		dc.w make_block_tile(ArtTile_Art_Flowers3+$0,0,0,3,0),make_block_tile(ArtTile_Art_Flowers3+$0,1,0,3,0)
		dc.w make_block_tile(ArtTile_Art_Flowers3+$1,0,0,3,0),make_block_tile(ArtTile_Art_Flowers3+$1,1,0,3,0)

		dc.w make_block_tile(ArtTile_Art_Flowers4+$0,0,0,3,1),make_block_tile(ArtTile_Art_Flowers4+$0,1,0,3,1)
		dc.w make_block_tile(ArtTile_Art_Flowers4+$1,0,0,3,1),make_block_tile(ArtTile_Art_Flowers4+$1,1,0,3,1)
APM_EHZ_End:

APM_CPZ:	begin_animpat
		dc.w make_block_tile(ArtTile_ArtUnc_CPZAnimBack+$0,0,0,2,0),make_block_tile(ArtTile_ArtUnc_CPZAnimBack+$1,0,0,2,0)
		dc.w make_block_tile(ArtTile_ArtUnc_CPZAnimBack+$0,0,0,2,0),make_block_tile(ArtTile_ArtUnc_CPZAnimBack+$1,0,0,2,0)
APM_CPZ_End:

APM_HPZ:	begin_animpat
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$0,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$1,0,0,3,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$2,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$3,0,0,3,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$4,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$5,0,0,3,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$6,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$7,0,0,3,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$0,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$1,0,0,3,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$2,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$3,0,0,3,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$4,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$5,0,0,3,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$6,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$7,0,0,3,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$0,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$1,0,0,3,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$2,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$3,0,0,3,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$4,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$5,0,0,3,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$6,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$7,0,0,3,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$0,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$1,0,0,2,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$2,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$3,0,0,2,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$4,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$5,0,0,2,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$6,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$7,0,0,2,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$0,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$1,0,0,2,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$2,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$3,0,0,2,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$4,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$5,0,0,2,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$6,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$7,0,0,2,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$0,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$1,0,0,2,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$2,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$3,0,0,2,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$4,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$5,0,0,2,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$6,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$7,0,0,2,0)

		dc.w make_block_tile(ArtTile_Level+$0,0,0,0,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$0,0,0,3,0)
		dc.w make_block_tile(ArtTile_Level+$0,0,0,0,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$2,0,0,3,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$1,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$4,0,0,3,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$3,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$6,0,0,3,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$5,0,0,3,0),make_block_tile(ArtTile_Level+$0,0,0,0,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$7,0,0,3,0),make_block_tile(ArtTile_Level+$0,0,0,0,0)

		dc.w make_block_tile(ArtTile_Level+$0,0,0,0,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$0,0,0,3,0)
		dc.w make_block_tile(ArtTile_Level+$0,0,0,0,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$2,0,0,3,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$1,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$4,0,0,3,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$3,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$6,0,0,3,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$5,0,0,3,0),make_block_tile(ArtTile_Level+$0,0,0,0,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$7,0,0,3,0),make_block_tile(ArtTile_Level+$0,0,0,0,0)

		dc.w make_block_tile(ArtTile_Level+$0,0,0,0,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$0,0,0,3,0)
		dc.w make_block_tile(ArtTile_Level+$0,0,0,0,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$2,0,0,3,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$1,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$4,0,0,3,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$3,0,0,3,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$6,0,0,3,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$5,0,0,3,0),make_block_tile(ArtTile_Level+$0,0,0,0,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$7,0,0,3,0),make_block_tile(ArtTile_Level+$0,0,0,0,0)

		dc.w make_block_tile(ArtTile_Level+$0,0,0,0,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$0,0,0,2,0)
		dc.w make_block_tile(ArtTile_Level+$0,0,0,0,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$2,0,0,2,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$1,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$4,0,0,2,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$3,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_1+$6,0,0,2,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$5,0,0,2,0),make_block_tile(ArtTile_Level+$0,0,0,0,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_1+$7,0,0,2,0),make_block_tile(ArtTile_Level+$0,0,0,0,0)

		dc.w make_block_tile(ArtTile_Level+$0,0,0,0,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$0,0,0,2,0)
		dc.w make_block_tile(ArtTile_Level+$0,0,0,0,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$2,0,0,2,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$1,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$4,0,0,2,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$3,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_2+$6,0,0,2,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$5,0,0,2,0),make_block_tile(ArtTile_Level+$0,0,0,0,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_2+$7,0,0,2,0),make_block_tile(ArtTile_Level+$0,0,0,0,0)

		dc.w make_block_tile(ArtTile_Level+$0,0,0,0,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$0,0,0,2,0)
		dc.w make_block_tile(ArtTile_Level+$0,0,0,0,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$2,0,0,2,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$1,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$4,0,0,2,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$3,0,0,2,0),make_block_tile(ArtTile_Art_HPZPulseOrb_3+$6,0,0,2,0)

		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$5,0,0,2,0),make_block_tile(ArtTile_Level+$0,0,0,0,0)
		dc.w make_block_tile(ArtTile_Art_HPZPulseOrb_3+$7,0,0,2,0),make_block_tile(ArtTile_Level+$0,0,0,0,0)
APM_HPZ_End:

APM_None:
		dc.w 0
APM_None_End:

; ===========================================================================
; ---------------------------------------------------------------------------
; Sprite mappings - SCORE, TIME, RINGS
; ---------------------------------------------------------------------------
Map_obj21:	include	"mappings/sprite/obj21.asm"

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to draw the HUD
; ---------------------------------------------------------------------------

; loc_40804:
BuildHUD:
		moveq	#0,d1			; Reset HUD frame index
		btst	#3,(Timer_frames+1).w	; Only blink on certain frames
		bne.s	.skipBlink
		tst.w	(v_rings).w		; No rings?
		bne.s	.checkTime
		addq.w	#1,d1			; +1 = RING blink frame

.checkTime:
		cmpi.b	#9,(v_timemin).w	; 9:00 reached?
		bne.s	.skipBlink
		addq.w	#2,d1			; +2 = TIME blink frame

.skipBlink:
	;	move.b	(Level_started_flag).w,d3
	;	ext.w	d3
	;	bpl.s	+
	;	addq.w	#2,d3
	;	move.b	d3,(Level_started_flag).w
+
		move.w	#128+16,d3		; HUD X pos
		move.w	#128+136,d2		; HUD Y pos
		lea	Map_obj21(pc),a1	; Map data base
		movea.w	#make_art_tile(ArtTile_HUD,0,0),a3 ; Art tile setup
		add.w	d1,d1			; Word offset (2 bytes per entry)
		adda.w	(a1,d1.w),a1		; Advance to correct HUD frame
		move.w	(a1)+,d1
		subq.w	#1,d1
		bmi.s	.return
		jmp	(DrawSprite_Loop).l	; Draw the HUD icon

.return:
		rts
; End of function BuildHUD

; ---------------------------------------------------------------------------
; Subroutine to add points to the score counter
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


AddPoints:
		move.b	#1,(f_scorecount).w
		lea	(v_score).w,a3
		add.l	d0,(a3)
		move.l	#999999,d1
		cmp.l	(a3),d1
		bhi.s	loc_1B214
		move.l	d1,(a3)

loc_1B214:
		move.l	(a3),d0
		cmp.l	(v_scorelife).w,d0
		blo.s	BuildHUD.return
		addi.l	#5000,(v_scorelife).w
		addq.b	#1,(v_lives).w
		addq.b	#1,(f_lifecount).w
		move.w	#bgm_ExtraLife,d0
		jmp	(PlaySound).l
; End of function AddPoints


; =============== S U B R O U T I N E =======================================


HudUpdate:
		nop
		lea	(vdp_data_port).l,a6
		tst.b	(Debug_mode_flag).w	; is debug mode on?
		bne.w	HudUpdate_Debug	; if yes, branch
		tst.b	(f_scorecount).w	; does the score need updating?
		beq.s	loc_1B266	; if not, branch
		clr.b	(f_scorecount).w
		locVRAM	(ArtTile_HUD+$1A)*tile_size,d0	; set VRAM address
		move.l	(v_score).w,d1	; load score
		bsr.w	HUD_Score

loc_1B266:
		tst.b	(f_ringcount).w	; does the ring counter need updating?
		beq.s	Hud_ChkTime	; if not, branch
		bpl.s	loc_1B272
		bsr.w	HUD_LoadZero

loc_1B272:
		clr.b	(f_ringcount).w
		locVRAM	(ArtTile_HUD+$30)*tile_size,d0	; set VRAM address
		moveq	#0,d1
		move.w	(v_rings).w,d1
		bsr.w	HUD_Rings

Hud_ChkTime:
		tst.b	(f_timecount).w
		bpl.s	.continue
		move.b	#1,(f_timecount).w
		bra.s	+
; ---------------------------------------------------------------------------

.continue:
		beq.s	Hud_ChkLives
		tst.w	(f_pause).w
		bne.s	Hud_ChkLives
		lea	(v_time).w,a1
		cmpi.l	#9<<16|59<<8|59,(a1)+		; if the timer has passed 9:59...
		beq.s	TimeOver			; ...Branch & kill the characters
		addq.b	#1,-(a1)
		cmpi.b	#60,(a1)
		blo.s	Hud_ChkLives
		clr.b	(a1)
		addq.b	#1,-(a1)
		cmpi.b	#60,(a1)
		blo.s	+
		clr.b	(a1)
		addq.b	#1,-(a1)
		cmpi.b	#9,(a1)
		blo.s	+
		move.b	#9,(a1)
+
		locVRAM	(ArtTile_HUD+$28)*tile_size,d0
		moveq	#0,d1
		move.b	(v_timemin).w,d1
		bsr.w	HUD_Mins
		locVRAM	(ArtTile_HUD+$2C)*tile_size,d0
		moveq	#0,d1
		move.b	(v_timesec).w,d1
		bsr.w	HUD_Secs

Hud_ChkLives:
		tst.b	(f_lifecount).w
		beq.s	loc_1B2F0
		clr.b	(f_lifecount).w
		bsr.w	HUD_Lives	; bsr to bra

loc_1B2F0:	; for special stages, for some reason? if commented out, numbers won't load
		tst.b	(f_endactbonus).w
		beq.s	TimeOver.return
		clr.b	(f_endactbonus).w
		locVRAM	ArtTile_Bonuses*tile_size
		moveq	#0,d1
		move.w	(v_timebonus).w,d1
		bsr.w	HUD_TimeRingBonus
		moveq	#0,d1
		move.w	(v_ringbonus).w,d1
	;	moveq	#0,d1
	;	move.w	(Bonus_Countdown_3).w,d1	 ; load perfect bonus
		bra.w	HUD_TimeRingBonus
; ===========================================================================
; kills the player if the time has reached 9:59
TimeOver:
		clr.b	(f_timecount).w
		lea	(v_player).w,a0
		movea.l	a0,a2
		bsr.w	KillSonic
		move.b	#1,(f_timeover).w

.return:
		rts
; ---------------------------------------------------------------------------

HudUpdate_Debug:
		bsr.w	HUDDebug_XY
		tst.b	(f_ringcount).w
		beq.s	loc_1B354
		bpl.s	loc_1B340
		bsr.w	HUD_LoadZero

loc_1B340:
		clr.b	(f_ringcount).w
		locVRAM	(ArtTile_HUD+$30)*tile_size,d0	; set VRAM address
		moveq	#0,d1
		move.w	(v_rings).w,d1
		bsr.w	HUD_Rings

loc_1B354:
;		locVRAM	(ArtTile_HUD+$28)*tile_size,d0
;		moveq	#0,d1
;		move.w	(Lag_frame_count).w,d1
;		bsr.w	HUD_Mins
		locVRAM	(ArtTile_HUD+$2C)*tile_size,d0	; set VRAM address
		moveq	#0,d1
		move.b	(v_spritecount).w,d1
		bsr.w	HUD_Secs
		tst.b	(f_lifecount).w
		beq.s	+
		clr.b	(f_lifecount).w
		bsr.w	HUD_Lives

+		; for special stages, for some reason? if commented out, numbers won't load
		tst.b	(f_endactbonus).w
		beq.s	+
		clr.b	(f_endactbonus).w
		locVRAM	ArtTile_Bonuses*tile_size
		moveq	#0,d1
		move.w	(v_timebonus).w,d1
		bsr.w	HUD_TimeRingBonus
		moveq	#0,d1
		move.w	(v_ringbonus).w,d1
	;	moveq	#0,d1
	;	move.w	(Bonus_Countdown_3).w,d1	 ; load perfect bonus
		bsr.w	HUD_TimeRingBonus

loc_1B372:
		tst.w	(f_pause).w
		bne.s	+
		lea	(v_time).w,a1
		addq.b	#1,-(a1)
		cmpi.b	#60,(a1)
		blo.s	+
		clr.b	(a1)
		addq.b	#1,-(a1)
		cmpi.b	#60,(a1)
		blo.s	+
		clr.b	(a1)
		addq.b	#1,-(a1)
		cmpi.b	#9,(a1)
		blo.s	+
		move.b	#9,(a1)
+
		rts
; End of function HudUpdate


; =============== S U B R O U T I N E =======================================


HUD_LoadZero:
		locVRAM	(ArtTile_HUD+$30)*tile_size
		lea	HUD_TilesZero(pc),a2
		moveq	#3-1,d2
		bra.s	loc_1B3CC
; End of function HUD_LoadZero


; =============== S U B R O U T I N E =======================================


HUD_Base:
		lea	(vdp_data_port).l,a6
		bsr.w	HUD_Lives
		locVRAM	(ArtTile_HUD+$18)*tile_size
		lea	HUD_TilesBase(pc),a2
		moveq	#$F-1,d2

loc_1B3CC:
		lea	Art_HUD(pc),a1

loc_1B3D0:
		moveq	#$10-1,d1
		move.b	(a2)+,d0
		bmi.s	loc_1B3EC
		ext.w	d0
		lsl.w	#5,d0
		lea	(a1,d0.w),a3

loc_1B3E0:
		move.l	(a3)+,(a6)
		dbf	d1,loc_1B3E0
		dbf	d2,loc_1B3D0
		rts
; ---------------------------------------------------------------------------

loc_1B3EC:
		clr.l	(a6)
		dbf	d1,loc_1B3EC
		dbf	d2,loc_1B3D0
		rts
; End of function HUD_Base

; ---------------------------------------------------------------------------
HUD_TilesBase:	dc.b $16,$FF,$FF,$FF,$FF,$FF,$FF,  0,  0,$14,  0,  0
HUD_TilesZero:	dc.b $FF,$FF,  0,  0

; =============== S U B R O U T I N E =======================================


HUDDebug_XY:
		locVRAM	(ArtTile_HUD+$18)*tile_size		; set VRAM address
		move.w	(Camera_RAM).w,d1
		swap	d1
		move.w	(v_player+obX).w,d1
		bsr.s	HUDDebug_XY2
		move.w	(Camera_Y_pos).w,d1
		swap	d1
		move.w	(v_player+obY).w,d1
; End of function HUDDebug_XY


; =============== S U B R O U T I N E =======================================


HUDDebug_XY2:
		moveq	#8-1,d6
		lea	Art_Text(pc),a1

loc_1B430:
		rol.w	#4,d1
		move.w	d1,d2
		andi.w	#$F,d2
		cmpi.w	#$A,d2
		blo.s	loc_1B442
		addq.w	#7,d2

loc_1B442:
		lsl.w	#5,d2
		lea	(a1,d2.w),a3
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		swap	d1
		dbf	d6,loc_1B430
		rts
; End of function HUDDebug_XY2


; =============== S U B R O U T I N E =======================================


HUD_Rings:
		lea	HUD_100(pc),a2
		moveq	#3-1,d6
		bra.s	loc_1B472
; End of function HUD_Rings


; =============== S U B R O U T I N E =======================================


HUD_Score:
		lea	HUD_100000(pc),a2
		moveq	#6-1,d6

loc_1B472:
		moveq	#0,d4
		lea	Art_HUD(pc),a1

loc_1B478:
		moveq	#0,d2
		move.l	(a2)+,d3

loc_1B47C:
		sub.l	d3,d1
		blo.s	loc_1B484
		addq.w	#1,d2
		bra.s	loc_1B47C
; ---------------------------------------------------------------------------

loc_1B484:
		add.l	d3,d1
		tst.w	d2
		beq.s	loc_1B48E
		move.w	#1,d4

loc_1B48E:
		tst.w	d4
		beq.s	loc_1B4BC
		lsl.w	#6,d2
		move.l	d0,4(a6)
		lea	(a1,d2.w),a3
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)

loc_1B4BC:
		addi.l	#$400000,d0
		dbf	d6,loc_1B478
		rts
; End of function HUD_Score

; ---------------------------------------------------------------------------
; Subroutine to	load countdown numbers on the continue screen
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; Technically unused
ContScrCounter:
		locVRAM	ArtTile_Continue_Number*tile_size
		lea	(vdp_data_port).l,a6
		lea	HUD_10(pc),a2
		moveq	#2-1,d6
		moveq	#0,d4
		lea	Art_HUD(pc),a1 ; load numbers patterns

ContScr_Loop:
		moveq	#0,d2
		move.l	(a2)+,d3

loc_1C95A:
		sub.l	d3,d1
		blo.s	loc_1C962
		addq.w	#1,d2
		bra.s	loc_1C95A
; ===========================================================================

loc_1C962:
		add.l	d3,d1
		lsl.w	#6,d2
		lea	(a1,d2.w),a3
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		dbf	d6,ContScr_Loop	; repeat 1 more	time
		rts
; End of function ContScrCounter
; ---------------------------------------------------------------------------
HUD_100000:	dc.l 100000
HUD_10000:	dc.l 10000
HUD_1000:	dc.l 1000
HUD_100:	dc.l 100
HUD_10:		dc.l 10
HUD_1:		dc.l 1

; =============== S U B R O U T I N E =======================================


HUD_Mins:
		lea	HUD_1(pc),a2
		moveq	#1-1,d6
		bra.s	loc_1B546
; End of function HUD_Mins


; =============== S U B R O U T I N E =======================================


HUD_Secs:
		lea	HUD_10(pc),a2
		moveq	#2-1,d6

loc_1B546:
		moveq	#0,d4
		lea	Art_HUD(pc),a1

loc_1B54C:
		moveq	#0,d2
		move.l	(a2)+,d3

loc_1B550:
		sub.l	d3,d1
		blo.s	loc_1B558
		addq.w	#1,d2
		bra.s	loc_1B550
; ---------------------------------------------------------------------------

loc_1B558:
		add.l	d3,d1
		tst.w	d2
		beq.s	loc_1B562
		moveq	#1,d4

loc_1B562:
		lsl.w	#6,d2
		move.l	d0,4(a6)
		lea	(a1,d2.w),a3
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		addi.l	#$400000,d0
		dbf	d6,loc_1B54C
		rts
; End of function HUD_Secs


; =============== S U B R O U T I N E =======================================


HUD_TimeRingBonus:
		lea	HUD_1000(pc),a2
		moveq	#4-1,d6
		moveq	#0,d4
		lea	Art_HUD(pc),a1

loc_1B5A4:
		moveq	#0,d2
		move.l	(a2)+,d3

loc_1B5A8:
		sub.l	d3,d1
		blo.s	loc_1B5B0
		addq.w	#1,d2
		bra.s	loc_1B5A8
; ---------------------------------------------------------------------------

loc_1B5B0:
		add.l	d3,d1
		tst.w	d2
		beq.s	loc_1B5BA
		moveq	#1,d4

loc_1B5BA:
		tst.w	d4
		beq.s	loc_1B5EA
		lsl.w	#6,d2
		lea	(a1,d2.w),a3
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		dbf	d6,loc_1B5A4
		rts
; ---------------------------------------------------------------------------

loc_1B5EA:
		moveq	#$10-1,d5

loc_1B5EC:
		clr.l	(a6)
		dbf	d5,loc_1B5EC
		dbf	d6,loc_1B5A4
		rts
; End of function HUD_TimeRingBonus

; =============== S U B R O U T I N E =======================================


HUD_Lives:
		locVRAM	(ArtTile_Lives_Counter+9)*tile_size,d0	; set VRAM address
		moveq	#0,d1
		move.b	(v_lives).w,d1
		lea	HUD_10(pc),a2
		moveq	#2-1,d6
		moveq	#0,d4
		lea	Art_LivesNums(pc),a1

loc_1B610:
		move.l	d0,4(a6)
		moveq	#0,d2
		move.l	(a2)+,d3

loc_1B618:
		sub.l	d3,d1
		blo.s	loc_1B620
		addq.w	#1,d2
		bra.s	loc_1B618
; ---------------------------------------------------------------------------

loc_1B620:
		add.l	d3,d1
		tst.w	d2
		beq.s	loc_1B62A
		moveq	#1,d4

loc_1B62A:
		tst.w	d4
		beq.s	loc_1B650

loc_1B62E:
		lsl.w	#5,d2
		lea	(a1,d2.w),a3
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		move.l	(a3)+,(a6)
		addi.l	#$400000,d0
		dbf	d6,loc_1B610
		rts
; ---------------------------------------------------------------------------

loc_1B650:
		tst.w	d6
		beq.s	loc_1B62E
		moveq	#8-1,d5

loc_1B656:
		clr.l	(a6)
		dbf	d5,loc_1B656
		addi.l	#$400000,d0
		dbf	d6,loc_1B610
		rts
; End of function HUD_Lives

; ---------------------------------------------------------------------------
 if AdvancedHandler=0
BusError:
		move.b	#2,(v_errortype).w
		bra.s	ErrorMsg_TwoAddresses
; ---------------------------------------------------------------------------

AddressError:
		move.b	#4,(v_errortype).w
		bra.s	ErrorMsg_TwoAddresses
; ---------------------------------------------------------------------------

IllegalInstr:
		move.b	#6,(v_errortype).w
		addq.l	#2,2(sp)
		bra.s	ErrorMessage
; ---------------------------------------------------------------------------

ZeroDivide:
		move.b	#8,(v_errortype).w
		bra.s	ErrorMessage
; ---------------------------------------------------------------------------

ChkInstr:
		move.b	#$A,(v_errortype).w
		bra.s	ErrorMessage
; ---------------------------------------------------------------------------

TrapvInstr:
		move.b	#$C,(v_errortype).w
		bra.s	ErrorMessage
; ---------------------------------------------------------------------------

PrivilegeViol:
		move.b	#$E,(v_errortype).w
		bra.s	ErrorMessage
; ---------------------------------------------------------------------------

Trace:
		move.b	#$10,(v_errortype).w
		bra.s	ErrorMessage
; ---------------------------------------------------------------------------

Line1010Emu:
		move.b	#$12,(v_errortype).w
		addq.l	#2,2(sp)
		bra.s	ErrorMessage
; ---------------------------------------------------------------------------

Line1111Emu:
		move.b	#$14,(v_errortype).w
		addq.l	#2,2(sp)
		bra.s	ErrorMessage
; ---------------------------------------------------------------------------

ErrorExcept:
		clr.b	(v_errortype).w
		bra.s	ErrorMessage
; ---------------------------------------------------------------------------

ErrorMsg_TwoAddresses:
		disable_ints
		addq.w	#2,sp
		move.l	(sp)+,(v_spbuffer).w
		addq.w	#2,sp
		movem.l	d0-sp,(v_regbuffer).w
		bsr.s	ShowErrorMsg
		move.l	2(sp),d0
		bsr.w	ShowErrAddress
		move.l	(v_spbuffer).w,d0
		bsr.w	ShowErrAddress
		bsr.w	ErrorWaitForC
		movem.l	(v_regbuffer).w,d0-sp
		enable_ints
		rte
; ---------------------------------------------------------------------------

ErrorMessage:
		disable_ints
		movem.l	d0-sp,(v_regbuffer).w
		bsr.s	ShowErrorMsg
		move.l	2(sp),d0
		bsr.w	ShowErrAddress
		bsr.w	ErrorWaitForC
		movem.l	(v_regbuffer).w,d0-sp
		enable_ints
		rte

; =============== S U B R O U T I N E =======================================


ShowErrorMsg:
		lea	(vdp_data_port).l,a6
		locVRAM	ArtTile_Error_Handler_Font*tile_size
		lea	Art_Text(pc),a0
		move.w	#bytesToWcnt(Art_Text_End-Art_Text),d1
.loadgfx:	move.w	(a0)+,(a6)
		dbf	d1,.loadgfx

		moveq	#0,d0
		move.b	(v_errortype).w,d0
		move.w	ErrorText(pc,d0.w),d0
		lea	ErrorText(pc,d0.w),a0
		locVRAM	vram_fg+$604

		moveq	#$13-1,d1
.showchars:	moveq	#0,d0
		move.b	(a0)+,d0
		addi.w	#-'0'+ArtTile_Error_Handler_Font,d0 ; rebase from ASCII to a VRAM index
		move.w	d0,(a6)
		dbf	d1,.showchars	; repeat for number of characters
		rts
; End of function ShowErrorMsg

; ---------------------------------------------------------------------------
ErrorText:
		dc.w .exception-ErrorText	; $00
		dc.w .bus-ErrorText		; $02
		dc.w .address-ErrorText		; $04
		dc.w .illinstruct-ErrorText	; $06
		dc.w .zerodivide-ErrorText	; $08
		dc.w .chkinstruct-ErrorText	; $0A
		dc.w .trapv-ErrorText		; $0C
		dc.w .privilege-ErrorText	; $0E
		dc.w .trace-ErrorText		; $10
		dc.w .line1010-ErrorText	; $12
		dc.w .line1111-ErrorText	; $14
.exception:	dc.b "ERROR EXCEPTION    "
.bus:		dc.b "BUS ERROR          "
.address:	dc.b "ADDRESS ERROR      "
.illinstruct:	dc.b "ILLEGAL INSTRUCTION"
.zerodivide:	dc.b "@ERO DIVIDE        "
.chkinstruct:	dc.b "CHK INSTRUCTION    "
.trapv:		dc.b "TRAPV INSTRUCTION  "
.privilege:	dc.b "PRIVILEGE VIOLATION"
.trace:		dc.b "TRACE              "
.line1010:	dc.b "LINE 1010 EMULATOR "
.line1111:	dc.b "LINE 1111 EMULATOR "
		even

; =============== S U B R O U T I N E =======================================


ShowErrAddress:
		move.w	#ArtTile_Error_Handler_Font+10,(a6)	; display "$" symbol
		moveq	#8-1,d2

ShowErrAddress_DigitLoop:
		rol.l	#4,d0
		bsr.s	ShowErrDigit
		dbf	d2,ShowErrAddress_DigitLoop
		rts
; End of function ShowErrAddress


; =============== S U B R O U T I N E =======================================


ShowErrDigit:
		move.w	d0,d1
		andi.w	#$F,d1
		cmpi.w	#$A,d1
		blo.s	ShowErrDigit_NoOverflow
		addq.w	#7,d1		; add 7 for characters A-F

ShowErrDigit_NoOverflow:
		addi.w	#ArtTile_Error_Handler_Font,d1
		move.w	d1,(a6)
		rts
; End of function ShowErrDigit


; =============== S U B R O U T I N E =======================================


ErrorWaitForC:
		jsr	(ReadJoypads).l
;		cmpi.b	#btnC,(v_jpadpress1).w	; is button C pressed? temporarily commented out
		cmpi.b	#btnC,(v_jpadhold1).w	; is button C held?
		bne.w	ErrorWaitForC		; if not, branch
		rts
; End of function ErrorWaitForC
 endif
; ---------------------------------------------------------------------------
Art_HUD:	binclude	"art/uncompressed/HUD Numbers.bin"
		even
Art_LivesNums:	binclude	"art/uncompressed/Lives Counter Numbers.bin"
		even
Art_Text:	binclude	"art/uncompressed/Level select and Debug Mode text.bin"
Art_Text_End:	even
; ---------------------------------------------------------------------------

; ===========================================================================
; ---------------------------------------------------------------------------
; When debug mode is currently in use
; ---------------------------------------------------------------------------

DebugMode:
		moveq	#0,d0
		move.b	(Debug_placement_mode).w,d0
		move.w	DebugIndex(pc,d0.w),d1
		jmp	DebugIndex(pc,d1.w)
; ===========================================================================
DebugIndex:
		dc.w Debug_Init-DebugIndex
		dc.w Debug_Main-DebugIndex
; ===========================================================================

Debug_Init:	; Routine 0
		addq.b	#2,(Debug_placement_mode).w
		move.w	(Camera_Min_Y_pos).w,(v_limittopdb).w
		move.w	(Camera_Max_Y_pos_target).w,(v_limitbtmdb).w
		clr.w	(Camera_Min_Y_pos).w
		move.w	#$720,(Camera_Max_Y_pos_target).w	; Sonic 2 doesn't bothers
		andi.w	#$7FF,(v_player+obY).w
		andi.w	#$7FF,(Camera_Y_pos).w
		andi.w	#$3FF,(Camera_BG_Y_pos).w
		clr.b	obFrame(a0)
		clr.b	obAnim(a0)
		bclr #1,(v_player+obStatus).w	; clear 'in air' bit
		cmpi.w	#BonusStage,(v_gamemode).w ; is this the Special Stage?
		bne.s	.islevel			; if not, branch
		move.b	#7-1,(Current_Zone).w		; set the debug object list and reset Special Stage rotation
		clr.w	(v_ssrotate).l		; stop special stage rotation
		clr.w	(v_ssangle).l		; make special stage "upright"
		moveq	#6,d0			; force zone 6's (S1 ending) debug object list
		bra.s	.selectlist
; ===========================================================================

.islevel:
		moveq	#0,d0
		move.b	(Current_Zone).w,d0

.selectlist:
		lea	DebugList(pc),a2
		add.w	d0,d0
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,d6
		cmp.b	(Debug_object).w,d6	; have you gone past the last item?
		bhi.s	.noreset		; if not, branch
		clr.b	(Debug_object).w	; back to start of list
.noreset:
		bsr.w	LoadDebugObjectSprite
		move.b	#12,(Debug_Accel_Timer).w
		move.b	#1,(Debug_Speed).w

Debug_Main:	; Routine 2
		moveq	#6,d0				; force zone 6's debug object list (was the ending in S1)
		cmpi.w	#BonusStage,(v_gamemode).w ; is this the Special Stage?
		beq.s	.isntlevel			; if yes, branch

		moveq	#0,d0
		move.b	(Current_Zone).w,d0

.isntlevel:
		lea	DebugList(pc),a2
		add.w	d0,d0
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,d6
		bsr.w	Debug_Control
		jmp	(DisplaySprite).l

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Debug_Control:
		moveq	#0,d4
		moveq	#1,d1
		move.b	(v_jpadpress1).w,d4
		andi.w	#btnUp|btnDn|btnL|btnR,d4	; is up/down/left/right	pressed?
		bne.s	.dirpressed		; if so, branch
		move.b	(v_jpadhold1).w,d0
		andi.w	#btnUp|btnDn|btnL|btnR,d0	; is up/down/left/right	held?
		bne.s	.dirheld	; if so, branch
		move.b	#12,(Debug_Accel_Timer).w
		move.b	#15,(Debug_Speed).w
		bra.w	Debug_ControlObjects
; ===========================================================================

.dirheld:
		subq.b	#1,(Debug_Accel_Timer).w
		bne.s	Debug_TimerNotOver
		move.b	#1,(Debug_Accel_Timer).w
		addq.b	#1,(Debug_Speed).w
		bne.s	.dirpressed
		move.b	#-1,(Debug_Speed).w
.dirpressed:
		move.b	(v_jpadhold1).w,d4

Debug_TimerNotOver:
		moveq	#0,d1
		move.b	(Debug_Speed).w,d1
		addq.w	#1,d1
		swap	d1
		asr.l	#4,d1
		move.l	obY(a0),d2
		move.l	obX(a0),d3

		; move up
		btst	#bitUp,d4	; is up	being pressed?
		beq.s	.upNotHeld	; if not, branch
		sub.l	d1,d2
		moveq	#0,d0
		move.w	(Camera_Min_Y_pos).w,d0
		swap	d0
		cmp.l	d0,d2
		bge.s	.minYPosNotReached
		move.l	d0,d2
.minYPosNotReached:

.upNotHeld:
		; move down
		btst	#bitDn,d4	; is down being	pressed?
		beq.s	.downNotHeld	; if not, branch
		add.l	d1,d2
		moveq	#0,d0
		move.w	(Camera_Max_Y_pos_target).w,d0
		addi.w	#224-1,d0
		swap	d0
		cmp.l	d0,d2
		blt.s	.maxYPosNotReached
		move.l	d0,d2
.maxYPosNotReached:

.downNotHeld:
		; move left
		btst	#bitL,d4
		beq.s	.leftNotHeld
		sub.l	d1,d3
		bcc.s	.minXPosNotReached
		moveq	#0,d3
.minXPosNotReached:

.leftNotHeld:
		; move right
		btst	#bitR,d4
		beq.s	.rightNotHeld
		add.l	d1,d3

.rightNotHeld:
		move.l	d2,obY(a0)
		move.l	d3,obX(a0)
; loc_1BBF4:
Debug_ControlObjects:
		btst	#bitA,(v_jpadhold1).w	; is button A pressed?
		beq.s	Debug_SpawnObject	; if not, branch
		btst	#bitC,(v_jpadpress1).w	; is button C pressed?
		beq.s	Debug_CycleObjects	; if not, branch
		; Cycle backwards though object list
		subq.b	#1,(Debug_object).w	; go back 1 item
		bcc.s	LoadDebugObjectSprite
		add.b	d6,(Debug_object).w
		bra.s	LoadDebugObjectSprite
; ===========================================================================
; loc_1BC10:
Debug_CycleObjects:
		btst	#bitA,(v_jpadpress1).w	; is button A pressed?
		beq.s	Debug_SpawnObject	; if not, branch
		; Cycle backwards though object list
		addq.b	#1,(Debug_object).w	; go forwards 1 item
		cmp.b	(Debug_object).w,d6
		bhi.s	LoadDebugObjectSprite
		clr.b	(Debug_object).w

; ===========================================================================
; loc_1bhsC: Debug_ShowItem:
LoadDebugObjectSprite:
		moveq	#0,d0
		move.b	(Debug_object).w,d0
		lsl.w	#3,d0
		move.l	(a2,d0.w),obMap(a0)
		move.w	6(a2,d0.w),obGfx(a0)
		move.b	5(a2,d0.w),obFrame(a0)
;		move.b	4(a2,d0.w),obSubtype(a0)	; this does... something with the object's subtype
		rts
; End of function Debug_ShowItem

; ===========================================================================
; loc_1BC2C:
Debug_SpawnObject:
		btst	#bitC,(v_jpadpress1).w	; is button C pressed?
		beq.s	Debug_ExitDebugMode	; if not, branch
		; spawn object
		jsr	(FindFreeObj).l
		bne.s	Debug_ExitDebugMode
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		_move.b	obMap(a0),obID(a1)	; load obj
		move.b	obRender(a0),obRender(a1)
		andi.b	#$7F,obRender(a1)
		move.b	obRender(a0),obStatus(a1)
		andi.b	#$7F,obStatus(a1)
		moveq	#0,d0
		move.b	(Debug_object).w,d0
		lsl.w	#3,d0
		move.b	4(a2,d0.w),obSubtype(a1)
		rts
; ===========================================================================
; loc_1BC70:
Debug_ExitDebugMode:
		btst	#bitB,(v_jpadpress1).w	; is button B pressed?
		beq.w	stayindebug		; if not, branch
		; exit Debug Mode
		moveq	#0,d0
		move.w	d0,(Debug_placement_mode).w	; deactivate debug mode
		disable_ints
	;	bsr.w	HUD_Base
		move.b	#1,(f_scorecount).w
		move.b	#$80,(f_ringcount).w
		enable_ints
		lea	(v_player).w,a1 ; a1=character
		move.l	#Map_Sonic,(v_player+obMap).w
		move.w	#make_art_tile(ArtTile_Sonic,0,0),(v_player+obGfx).w
		bsr.s	Debug_ResetPlayerStats
		move.b	#$13,obHeight(a1)	; y_radius
		move.b	#9,obWidth(a1)		; x_radius
		move.w	(v_limittopdb).w,(Camera_Min_Y_pos).w
		move.w	(v_limitbtmdb).w,(Camera_Max_Y_pos_target).w
		cmpi.w	#BonusStage,(v_gamemode).w ; is this the Bonus Stage?
		bne.s	stayindebug			; if not, branch

		clr.w	(v_ssangle).l			; again, this resets the Special Stage rotation
		move.w	#$40,(v_ssrotate).l		; and Sonic's art for whatever reason
		move.b	#AniIDSonAni_Roll,(v_player+obAnim).w
		bset	#2,(v_player+obStatus).w
		bset	#1,(v_player+obStatus).w

stayindebug:
		rts
; End of function Debug_Control


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Debug_ResetPlayerStats:
		moveq	#0,d0
		move.b	d0,obAnim(a1)
		move.w	d0,obXSub(a1)	; x_sub
		move.w	d0,obYSub(a1)	; y_sub
		move.b	d0,obControl(a1)	; Not yet implemented in NA, but we'll clear it anyways in preparation for when it's actually ported
		move.b	d0,spindash_flag(a1)
		move.w	d0,obVelX(a1)
		move.w	d0,obVelY(a1)
		move.w	d0,obInertia(a1)
		andi.b	#1<<6,obStatus(a1)	; Preserve the 'is underwater' flag, and clear everything else.
		ori.b	#2,obStatus(a1)		; Set the 'is rolling' flag.
		move.b	#2,obRoutine(a1)
		clr.b	ob2ndRout(a1)
		rts
; End of function Debug_ResetPlayerStats


; =============== S U B R O U T I N E =======================================


AutoTunnel_GetPath:	; In Sonic 2, this is found at loc_27310
		move.b	obSubtype(a0),d0
		bpl.s	loc_297D6
		andi.w	#$1F,d0			; If negative, then the path is reversed
		add.w	d0,d0
		add.w	d0,d0
		lea	(AutoTunnel_Data).l,a2	; in S2, this was a word table. It's now longwords
		movea.l	(a2,d0.w),a2	; Get address of movement data
		move.w	(a2)+,d0
		subq.w	#4,d0
		move.w	d0,4(a4)
		lea	(a2,d0.w),a2
		move.w	(a2)+,d4
		move.w	d4,obX(a1)
		move.w	(a2)+,d5
		move.w	d5,obY(a1)		; Set absolute position of player
		subq.w	#8,a2
		bra.s	loc_2980C
; ---------------------------------------------------------------------------

loc_297D6:
		cmpi.b	#$10,d0
		bne.s	loc_297E6
		cmpi.w	#2,(Player_mode).w
		bne.s	loc_297E6
		moveq	#0,d0			; If playing as Tails, use path 0 when doing path $10

loc_297E6:
		andi.w	#$1F,d0
		add.w	d0,d0
		add.w	d0,d0
		lea	(AutoTunnel_Data).l,a2
		movea.l	(a2,d0.w),a2
		move.w	(a2)+,4(a4)
		subq.w	#4,4(a4)
		move.w	(a2)+,d4
		move.w	d4,obX(a1)
		move.w	(a2)+,d5
		move.w	d5,obY(a1)		; Set absolute position of player

loc_2980C:
		move.l	a2,6(a4)
		move.w	(a2)+,d4
		move.w	(a2)+,d5		; Get next position
		move.w	#$1000,d2

AutoTunnel_CalcSpeed:
		moveq	#0,d0
		move.w	d2,d3
		move.w	d4,d0
		sub.w	obX(a1),d0
		bge.s	loc_29828
		neg.w	d0
		neg.w	d2			; Change X velocity depending on direction of destination

loc_29828:
		moveq	#0,d1
		move.w	d5,d1
		sub.w	$14(a1),d1
		bge.s	loc_29836
		neg.w	d1
		neg.w	d3			; Change Y velocity depending on direction of destination

loc_29836:
		cmp.w	d0,d1
		blo.s	loc_29868
		moveq	#0,d1			; If X distance is less than Y distance
		move.w	d5,d1
		sub.w	obY(a1),d1
		swap	d1
		divs.w	d3,d1
		moveq	#0,d0
		move.w	d4,d0
		sub.w	obX(a1),d0
		beq.s	loc_29854
		swap	d0
		divs.w	d1,d0

loc_29854:
		move.w	d0,obVelX(a1)		; Calculate and set X velocity assuming a Y velocity of $10 pixels
		move.w	d3,obVelY(a1)
		tst.w	d1
		bpl.s	loc_29862
		neg.w	d1

loc_29862:
		move.w	d1,2(a4)		; The quotient of the distance/speed produces a proper timer used for movement
		rts
; ---------------------------------------------------------------------------

loc_29868:
		moveq	#0,d0			; If Y distance is less than X distance
		move.w	d4,d0
		sub.w	obX(a1),d0
		swap	d0
		divs.w	d2,d0
		moveq	#0,d1
		move.w	d5,d1
		sub.w	obY(a1),d1
		beq.s	loc_29882
		swap	d1
		divs.w	d0,d1

loc_29882:
		move.w	d1,obVelY(a1)	; Calculate and set Y velocity assuming a X velocity of $10 pixels
		move.w	d2,obVelX(a1)
		tst.w	d0
		bpl.s	loc_29890
		neg.w	d0

loc_29890:
		move.w	d0,2(a4)	; See above
		rts
; End of function AutoTunnel_GetPath

; ===========================================================================
; ---------------------------------------------------------------------------
; S2 sound driver (Kosinski+)
; ---------------------------------------------------------------------------
; loc_EC0E8:
Snd_Driver:
	save
	include "s2.sounddriver.asm" ; CPU Z80
	restore
	padding off
	!org (Snd_Driver+Size_of_Snd_driver_guess) ; don't worry; I know what I'm doing


; loc_ED04C:
Snd_Driver_End:
; ---------------------------------------------------------------------------
		include	"_inc/DebugList.asm"
		include	"_inc/LevelHeaders.asm"
		include	"_inc/Pattern Load Cues.asm"
; ---------------------------------------------------------------------------
; Music pointers
; ---------------------------------------------------------------------------
musprop_uncompressed	= 1<<4	; $10
musprop_nospeedup	= 1<<5	; $20
musprop_palmode	= 1<<6		; $40
musprop_1up	= 1<<7		; $80
zmakePlaylistEntry macro addr,val
	dc.b	addr/$8000	; bank
	rom_ptr_z80	addr
	if "val"<>""
	dc.b	val
	else
	dc.b	0
	endif
	endm

	include "musicbanks.gen.asm"

zSoundIndexEntry macro pointer, priority
	rom_ptr_z80	pointer
	dc.b	priority
	endm

; ------------------------------------------------------------------------------
; Sound effect bank
; ------------------------------------------------------------------------------
SndSFX1_Start:	startBank

	include "sfxbank.gen.asm"

	; something else for DAC sounds
	; First byte selects one of the DAC samples.  The number that
	; follows it is a wait time between each nibble written to the DAC
	; (thus higher = slower)
	;ensure1byteoffset 2*48
; zbyte_124F:
DACSample	macro	pPtr,pDelay,pFlags
	dc.b	pPtr/$8000
	;dc.w	z80_ptr(pPtr)
	dc.b	(z80_ptr(pPtr)&$FF00)>>8
	dc.b	z80_ptr(pPtr)&$FF
	;dc.w	pPtr_End-pPtr
	dc.b	(pPtr_End-pPtr)&$FF
	dc.b	((pPtr_End-pPtr)&$FF00)>>8

	; Lemme explain what's going on here: the Z80 is clocked at 3579545Hz.
	; 1Hz means 1 cycle per second. So, we divide the clock by the playback speed
	; we want. This gets us a kind of delta: the amount of cycles the Z80 needs to occupy
	; itself before sending the next sample, to get the correct playback speed.
	; Our way of controlling playback speed is through a 'djnz' instruction, so we need to
	; get a djnz counter from this delta. First, we subtract the number of cycles the actual
	; update loop takes - which, in the case of the PCM loop, is 70 - that will leave us
	; with the cycles that really matter: these are the 'spare' cycles, ones that won't
	; otherwise be used by the normal update loop. Instead, we artificially use them with
	; the aforementioned djnz loop. To get the djnz loop counter, we divide our remaining
	; cycles by the amount of cycles one djnz loop takes, which is 13. We also add 1,
	; because 1 to a djnz instruction technically means 0 (and 0 means 255, so we obviously
	; can't use that).
	; We use '*2' in the DPCM converter a couple of times because the DPCM loop updates
	; the sample twice (one for each nibble in a byte of sample data).
	; An extra thing we do is perform rounding, to get more-accurate conversions, hence
	; the '*10's and '+5'.
	if pFlags&1
		; PCM
		dc.b	((((((3579545*10)/pDelay)-(70*10))/13)+5)/10)+1
	else
		; DPCM
		dc.b	(((((((3579545*10)*2)/pDelay)-(176*10))/(13*2))+5)/10)+1
	endif

	dc.b	pFlags
	endm

	include "dacinfo.gen.asm"
	include "musicinfo.gen.asm"

	even

	finishBank

; -------------------------------------------------------------------------------
; Sega Intro Sound
; 8-bit unsigned raw audio at 16Khz
; -------------------------------------------------------------------------------
; loc_F1E8C:
Snd_Sega:		BINCLUDE	"sound/PCM/SEGA.bin"
Snd_Sega_End:		even

	if Snd_Sega_End - Snd_Sega > $8000
		fatal "Sega sound must fit within $8000 bytes, but you have a $\{Snd_Sega_End-Snd_Sega} byte Sega sound."
	endif
	if Snd_Sega_End - Snd_Sega > Size_of_SEGA_sound
		fatal "Size_of_SEGA_sound = $\{Size_of_SEGA_sound}, but you have a $\{Snd_Sega_End-Snd_Sega} byte Sega sound."
	endif
; ---------------------------------------------------------------------------
; DAC samples
; ---------------------------------------------------------------------------
	include "dacbanks.gen.asm"
		even
; -------------------------------------------------------------------------------
Kosp_Title:		binclude	"art/kosinski/level/8x8 - Title.kosp"
Nem_TitleSonicTails:	binclude	"art/nemesis/Title Sonic and Tails.nem"
			even
Nem_SegaLogo:		binclude	"art/nemesis/Sega Logo (JP1).nem"
			even
; ---------------------------------------------------------------------------
; Misc. compressed data - Tilemaps
; ---------------------------------------------------------------------------
Eni_SegaLogo:	binclude	"tilemaps/Sega Logo (JP1).eni"
		even
Eni_TitleMap:	binclude	"tilemaps/Title Emblem.eni"
		even
Kosp_TitleBg1:	binclude	"tilemaps/Title Background - 1.kosp"
Kosp_TitleBg2:	binclude	"tilemaps/Title Background - 2.kosp"
; ---------------------------------------------------------------------------
; Uncompressed Assets
; ---------------------------------------------------------------------------
		align $20
Art_Sonic:	binclude	"art/uncompressed/Sonic's art.bin"
Art_Tails:	binclude	"art/uncompressed/Tails' art.bin"
Art_SplashDust:	binclude	"art/uncompressed/Dust and water splash.bin"
Art_BigRing:	binclude	"art/uncompressed/Giant Ring.bin"
Map_Sonic:	include		"mappings/sprite/Sonic.asm"
SonicDynPLC:	include		"mappings/spriteDPLC/Sonic.asm"
Map_Tails:	include		"mappings/sprite/Tails.asm"
TailsDynPLC:	include		"mappings/spriteDPLC/Tails.asm"
; ---------------------------------------------------------------------------
; Misc. animated tiles
; ---------------------------------------------------------------------------
			align $20
Art_Flowers1:		binclude	"art/uncompressed/EHZ and HTZ flowers - 1.bin"
Art_Flowers2:		binclude	"art/uncompressed/EHZ and HTZ flowers - 2.bin"
Art_Flowers3:		binclude	"art/uncompressed/EHZ and HTZ flowers - 3.bin"
Art_Flowers4:		binclude	"art/uncompressed/EHZ and HTZ flowers - 4.bin"
Art_CPZAnimBGPlates:	binclude	"art/uncompressed/CPZ animated background section.bin"
Art_EHZPulseBall:	binclude	"art/uncompressed/Pulsing ball against checkered background (EHZ).bin"
Art_HPZPulseOrb:	binclude	"art/uncompressed/Pulsing orb (HPZ).bin"
; ---------------------------------------------------------------------------
; Green Hill Zone stage assets
; ---------------------------------------------------------------------------
Nem_Stalk:	binclude	"art/nemesis/S1/GHZ Flower Stalk.nem"
		even
Nem_Swing:	binclude	"art/nemesis/S1/GHZ Swinging Platform.nem"
		even
Nem_GHZ_Bridge:	binclude	"art/nemesis/S1/GHZ Bridge.nem"
		even
Nem_GHZ_Ball:	binclude	"art/nemesis/S1/GHZ Giant Ball.nem"
		even
Nem_GHZ_Spikes:	binclude	"art/nemesis/S1/GHZ Spiked Log.nem"
		even
Nem_GHZ_Rock:	binclude	"art/nemesis/S1/GHZ Purple Rock.nem"
		even
Nem_GHZ_BWall:	binclude	"art/nemesis/S1/GHZ Breakable Wall.nem"
		even
Nem_GHZ_SWall:	binclude	"art/nemesis/S1/GHZ Edge Wall.nem"
		even
; ---------------------------------------------------------------------------
; Rustic Ruins Zone stage assets
; ---------------------------------------------------------------------------
Kospm_FlapDoor:	binclude	"art/moduled kosinski/Flapping Door.kospm"
; ---------------------------------------------------------------------------
; Chemical Plant Zone stage assets
; ---------------------------------------------------------------------------
Nem_CPZ_FloatingPlatform:	binclude	"art/nemesis/CPZ Floating Platform.nem"
		even
; ---------------------------------------------------------------------------
; Emerald Hill Zone stage assets
; ---------------------------------------------------------------------------
Nem_EHZ_Waterfall:	binclude	"art/nemesis/Waterfall tiles.nem"
			even
Nem_EHZ_Bridge:		binclude	"art/nemesis/EHZ bridge.nem"
			even
; ---------------------------------------------------------------------------
; Hidden Palace Zone stage assets
; ---------------------------------------------------------------------------
Nem_HPZ_Bridge:		binclude	"art/nemesis/HPZ bridge.nem"
			even
Nem_HPZ_Waterfall:	binclude	"art/nemesis/HPZ waterfall.nem"
			even
Nem_HPZ_Emerald:	binclude	"art/nemesis/HPZ Emerald.nem"
			even
Nem_HPZ_Platform:	binclude	"art/nemesis/HPZ Platform.nem"
			even
Nem_HPZ_PulsingBall:	binclude	"art/nemesis/HPZ Pulsing Ball.nem"
			even
Nem_HPZ_Various:	binclude	"art/nemesis/HPZ Various.nem"
			even
; ---------------------------------------------------------------------------
; Hill Top Zone stage assets
; ---------------------------------------------------------------------------
Nem_EHZ_Fireball:	binclude	"art/nemesis/Fireball 1.nem"
			even
Nem_HTZ_Fireball:	binclude	"art/nemesis/Fireball 2.nem"
			even
Nem_HTZ_Lift:		binclude	"art/nemesis/HTZ zip-line platform.nem"
			even
Nem_HTZ_AutomaticDoor:	binclude	"art/nemesis/HTZ Autodoor.nem"
			even
Nem_HTZ_Seesaw:		binclude	"art/nemesis/See-saw in HTZ.nem"
			even
; ---------------------------------------------------------------------------
; Compressed graphics - enemies
; ---------------------------------------------------------------------------
		; Kosinski art in general is even by default
Kospm_BallhogV:	binclude	"art/moduled kosinski/Enemy Ballhog (Vertical).kospm"
Kospm_BallhogH:	binclude	"art/moduled kosinski/Enemy Ballhog (Horizontal).kospm"
Kospm_Chopper:	binclude	"art/moduled kosinski/Enemy Chopper.kospm"
Kospm_Motobug:	binclude	"art/moduled kosinski/Enemy Motobug.kospm"
Kospm_Crabmeat:	binclude	"art/moduled kosinski/Enemy Crabmeat.kospm"
Kospm_Buzz:	binclude	"art/moduled kosinski/Enemy Buzz Bomber.kospm"
Kospm_Newtron:	binclude	"art/moduled kosinski/Enemy Newtron.kospm"
Kospm_Burrobot:	binclude	"art/moduled kosinski/Enemy Burrobot.kospm"
Kospm_Jaws:	binclude	"art/moduled kosinski/Enemy Jaws.kospm"
Kospm_Yadrin:	binclude	"art/moduled kosinski/Enemy Yadrin.kospm"
Kospm_Basaran:	binclude	"art/moduled kosinski/Enemy Basaran.kospm"
Kospm_Splats:	binclude	"art/moduled kosinski/Enemy Splats.kospm"
Kospm_Bomb:	binclude	"art/moduled kosinski/Enemy Bomb.kospm"
Kospm_Orbinaut:	binclude	"art/moduled kosinski/Enemy Orbinaut.kospm"
Kospm_Cater:	binclude	"art/moduled kosinski/Enemy Caterkiller.kospm"
Kospm_BBat:	binclude	"art/moduled kosinski/Enemy BBat.kospm"
Kospm_Redz:	binclude	"art/moduled kosinski/Enemy Redz.kospm"
Nem_Gator:	binclude	"art/nemesis/Enemy Gator.nem"
		even
Nem_Buzzer:	binclude	"art/nemesis/Enemy Buzzer.nem"
		even
Nem_Octus:	binclude	"art/nemesis/Enemy Octus.nem"
		even
Nem_Stegway:	binclude	"art/nemesis/Enemy Stegway.nem"
		even
Nem_BFish:	binclude	"art/nemesis/Enemy BFish.nem"
		even
Nem_Aquis:	binclude	"art/nemesis/Enemy Aquis.nem"
		even
Nem_MBubbler:	binclude	"art/nemesis/Enemy Bubbler's Mother.nem"
		even
Nem_Bubbler:	binclude	"art/nemesis/Enemy Bubbler.nem"
		even
Nem_Snail:	binclude	"art/nemesis/Enemy Snail.nem"
		even
Nem_Crawl:	binclude	"art/nemesis/Enemy Crawl.nem"
		even
Nem_Masher:	binclude	"art/nemesis/Enemy Masher.nem"
		even
; ---------------------------------------------------------------------------
; Compressed graphics - various
; ---------------------------------------------------------------------------
Nem_TitleCard:	binclude	"art/nemesis/Title Cards.nem"
		even
Nem_GameOver:	binclude	"art/nemesis/Game Over.nem"
		even
Nem_Signpost:	binclude	"art/nemesis/Signpost.nem"
		even
Nem_HUD:	binclude	"art/nemesis/HUD.nem"
		even
Nem_Points:	binclude	"art/nemesis/Numbers.nem"
		even
Nem_Lives:	binclude	"art/nemesis/Sonic lives counter.nem"
		even
Nem_Ring:	binclude	"art/nemesis/Ring.nem"
		even
Nem_Monitors:	binclude	"art/nemesis/Monitor and contents.nem"
		even
Nem_Shield:	binclude	"art/nemesis/Shield.nem"
		even
Nem_Stars:	binclude	"art/nemesis/Stars.nem"
		even
Nem_Lamppost:	binclude	"art/nemesis/Lamppost.nem"
		even
Nem_HSpring:	binclude	"art/nemesis/S1/Spring Horizontal.nem"
		even
Nem_VSpring:	binclude	"art/nemesis/S1/Spring Vertical.nem"
		even
Nem_HSpring2:	binclude	"art/nemesis/Horizontal spring.nem"
		even
Nem_VSpring2:	binclude	"art/nemesis/Vertical spring.nem"
		even
Nem_DSpring:	binclude	"art/nemesis/Diagonal spring.nem"
		even
Nem_Bumper:	binclude	"art/nemesis/Bumper.nem"
		even
Nem_VSpikes:	binclude	"art/nemesis/Spikes.nem"
		even
Nem_Button:	binclude	"art/nemesis/Button.nem"
		even
Nem_Water:	binclude	"art/nemesis/Water Surface.nem"
		even
Nem_BigFlash:	binclude	"art/nemesis/S1/Giant Ring Flash.nem"
		even
Nem_Bonus:	binclude	"art/nemesis/S1/Hidden Bonuses.nem"
		even
; ---------------------------------------------------------------------------
; Compressed graphics - continue screen
; ---------------------------------------------------------------------------
; These files are already even, so...
Kospm_ContSonic:	binclude	"art/moduled kosinski/Continue Screen Sonic.kospm"
Kospm_ContTails:	binclude	"art/moduled kosinski/Continue screen Tails.kospm"
Kospm_MiniSonic:	binclude	"art/moduled kosinski/Mini Sonic Continue.kospm"
Kospm_MiniTails:	binclude	"art/moduled kosinski/Mini Tails Continue.kospm"
; ---------------------------------------------------------------------------
; Compressed graphics - animals
; ---------------------------------------------------------------------------
Nem_Bunny:	binclude	"art/nemesis/Animal Rabbit.nem"
		even
Nem_Chicken:	binclude	"art/nemesis/Animal Chicken.nem"
		even
Nem_Penguin:	binclude	"art/nemesis/Animal Penguin.nem"
		even
Nem_Seal:	binclude	"art/nemesis/Animal Seal.nem"
		even
Nem_Pig:	binclude	"art/nemesis/Animal Pig.nem"
		even
Nem_Flicky:	binclude	"art/nemesis/Animal Flicky.nem"
		even
Nem_Squirrel:	binclude	"art/nemesis/Animal Squirrel.nem"
		even
; ---------------------------------------------------------------------------
; Compressed graphics - Bosses and explosions
; ---------------------------------------------------------------------------
Nem_EggPod:	binclude	"art/nemesis/Boss Ship.nem"
		even
Nem_EggPodJets:	binclude	"art/nemesis/Boss Ship Boost.nem"
		even
Nem_EHZ_Boss:	binclude	"art/nemesis/EHZ boss.nem"
		even
Nem_EggChopper:	binclude	"art/nemesis/Chopper blades for EHZ boss.nem"
		even
Nem_CPZ_Boss:	binclude	"art/nemesis/CPZ boss.nem"
		even
Nem_Smoke:	binclude	"art/nemesis/Smoke trail from CPZ boss.nem"
		even
Nem_Explosion:	binclude	"art/nemesis/Explosion.nem"
		even
Nem_BossExplosion:
		binclude	"art/nemesis/Large explosion.nem"
		even
Nem_GroundExplosion:
		binclude	"art/nemesis/Explosion - Ground.nem"
		even
; ---------------------------------------------------------------------------
; Compressed graphics - Ending (Leftover placeholder - to be re-used)
; ---------------------------------------------------------------------------
Nem_EndEm:	binclude	"art/nemesis/S1/Ending - Emeralds.nem"
		even
Nem_EndSonic:	binclude	"art/nemesis/S1/Ending - Sonic.nem"
		even
Kospm_EndFlowers:	binclude	"art/moduled kosinski/Ending - Flowers.kospm"
Kospm_EndStalk:	binclude	"art/moduled kosinski/Ending - Flower Stalk.kospm"
Kosp_CreditText:	binclude	"art/kosinski/Ending - Credits.kosp"
Kospm_TryAgain:	binclude	"art/moduled kosinski/Ending - Try Again.kospm"
Nem_EndStH:	binclude	"art/nemesis/S1/Ending - StH Logo.nem"
		even
; ---------------------------------------------------------------------------
; Compressed graphics - Level placeholders
; ---------------------------------------------------------------------------
		even
; ---------------------------------------------------------------------------
; Compressed graphics - Bonus & Special stages
; ---------------------------------------------------------------------------
Nem_Warp:	binclude	"art/nemesis/Bonus & Special Stage/Bonus Stage Flash.nem" ; entry to bonus stage flash
		even
Nem_SSWalls:	binclude	"art/nemesis/Bonus & Special Stage/Bonus Stage Walls.nem" ; bonus stage walls
		even
Nem_SSBgFish:	binclude	"art/nemesis/Bonus & Special Stage/Bonus Birds & Fish.nem" ; bonus stage birds and fish background
		even
Nem_SSBgCloud:	binclude	"art/nemesis/Bonus & Special Stage/Bonus Clouds.nem" ; bonus stage clouds background
		even
Nem_SSGOAL:	binclude	"art/nemesis/Bonus & Special Stage/Bonus Stage GOAL.nem" ; bonus stage GOAL block
		even
Nem_SSRBlock:	binclude	"art/nemesis/Bonus & Special Stage/Bonus Stage R.nem"	; bonus stage R block
		even
Nem_SS1UpBlock:	binclude	"art/nemesis/Bonus & Special Stage/Bonus Stage 1UP.nem" ; bonus stage 1UP block
		even
Nem_SSEmStars:	binclude	"art/nemesis/Bonus & Special Stage/Bonus Stage Emerald Twinkle.nem" ; bonus stage stars from a collected emerald
		even
Nem_SSRedWhite:	binclude	"art/nemesis/Bonus & Special Stage/Bonus Stage Red-White.nem" ; bonus stage red/white block
		even
Nem_SSUpDown:	binclude	"art/nemesis/Bonus & Special Stage/Bonus Stage UP-DOWN.nem" ; bonus stage UP/DOWN block
		even
Nem_SSEmerald:	binclude	"art/nemesis/Bonus & Special Stage/Bonus Stage Emeralds.nem" ; bonus stage chaos emeralds
		even
Nem_SSGhost:	binclude	"art/nemesis/Bonus & Special Stage/Bonus Stage Ghost.nem" ; bonus stage ghost block
		even
Nem_SSWBlock:	binclude	"art/nemesis/Bonus & Special Stage/Bonus Stage W.nem"	; bonus stage W block
		even
Nem_SSGlass:	binclude	"art/nemesis/Bonus & Special Stage/Bonus Stage Glass.nem" ; bonus stage destroyable glass block
		even
Nem_ResultEm:	binclude	"art/nemesis/Bonus & Special Stage/Bonus Stage Result Emeralds.nem" ; chaos emeralds on special stage results screen
		even
Nem_SpecialBack:
		binclude	"art/nemesis/Bonus & Special Stage/Background art for special stage.nem"
		even
Nem_SpecialHUD:	binclude	"art/nemesis/Bonus & Special Stage/Sonic and Miles number text from special stage.nem"
		even
Nem_SpecialStart:
		binclude	"art/nemesis/Bonus & Special Stage/Start text from special stage.nem" ; Also includes checkered flag
		even
Nem_SpecialStars:
		binclude	"art/nemesis/Bonus & Special Stage/Stars in special stage.nem"
		even
Nem_SpecialRings:
		binclude	"art/nemesis/Bonus & Special Stage/Special stage ring art.nem"
		even
Nem_SpecialFlatShadow:
		binclude	"art/nemesis/Bonus & Special Stage/Horizontal shadow from special stage.nem"
		even
Nem_SpecialDiagShadow:
		binclude	"art/nemesis/Bonus & Special Stage/Diagonal shadow from special stage.nem"
		even
Nem_SpecialSideShadow:
		binclude	"art/nemesis/Bonus & Special Stage/Vertical shadow from special stage.nem"
		even
Nem_SpecialExplosion:
		binclude	"art/nemesis/Bonus & Special Stage/Explosion from special stage.nem"
		even
Nem_SpecialBomb:
		binclude	"art/nemesis/Bonus & Special Stage/Bomb from special stage.nem"
		even
Nem_SpecialEmerald:
		binclude	"art/nemesis/Bonus & Special Stage/Emerald from special stage.nem"
		even
Nem_SpecialMessages:
		binclude	"art/nemesis/Bonus & Special Stage/Special stage messages and icons.nem"
		even
Nem_SpecialSonicAndTails:
		binclude	"art/nemesis/Bonus & Special Stage/Sonic and Tails animation frames in special stage.nem" ; [fixBugs] In this file, Tails' arms are tan instead of orange.
		even
Nem_SpecialTailsText:
		binclude	"art/nemesis/Bonus & Special Stage/Tails text patterns from special stage.nem"
		even
;----------------------------------------------------------------------------
; Special stage level patterns
; Note: Only one line of each tile is stored in this archive. The other 7 lines are
;  the same as this one line, so to get the full tiles, each line needs to be
;  duplicated 7 times over.
;----------------------------------------------------------------------------
Nem_Special:	binclude	"art/nemesis/Bonus & Special Stage/Special Half Pipe.nem"
	even
; ---------------------------------------------------------------------------
; Bonus & Special Stage data
; ---------------------------------------------------------------------------
		binclude	"Bonus & Special Stages/Special stage layouts.kosp"
		binclude	"Bonus & Special Stages/Special stage object layout.kosp"
		binclude	"Bonus & Special Stages/Special stage object perspective data.kosp"
BS_1:		binclude	"Bonus & Special Stages/1.kosp"
BS_2:		binclude	"Bonus & Special Stages/2.kosp"
BS_3:		binclude	"Bonus & Special Stages/3.kosp"
BS_4:		binclude	"Bonus & Special Stages/4.kosp"
BS_5:		binclude	"Bonus & Special Stages/5.kosp"
BS_6:		binclude	"Bonus & Special Stages/6.kosp"
;-----------------------------------------------------------------------------------
; Bonus & Special Stage Assets
;-----------------------------------------------------------------------------------
Eni_BSBg1:	binclude	"tilemaps/BS Background 1.eni" ; bonus stage background (mappings)
Eni_BSBg2:	binclude	"tilemaps/BS Background 2.eni" ; bonus stage background (mappings)
Eni_SpecialBack:
		binclude	"tilemaps/Main background mappings for special stage.eni"
Eni_SpecialBackBottom:
		binclude	"tilemaps/Lower background mappings for special stage.eni"

;-----------------------------------------------------------------------------------
; Exit curve + slope up
;-----------------------------------------------------------------------------------
MapSpec_Rise1:		BINCLUDE	"mappings/special stage/Slope up - Frame 1.bin"
MapSpec_Rise2:		BINCLUDE	"mappings/special stage/Slope up - Frame 2.bin"
MapSpec_Rise3:		BINCLUDE	"mappings/special stage/Slope up - Frame 3.bin"
MapSpec_Rise4:		BINCLUDE	"mappings/special stage/Slope up - Frame 4.bin"
MapSpec_Rise5:		BINCLUDE	"mappings/special stage/Slope up - Frame 5.bin"
MapSpec_Rise6:		BINCLUDE	"mappings/special stage/Slope up - Frame 6.bin"
MapSpec_Rise7:		BINCLUDE	"mappings/special stage/Slope up - Frame 7.bin"
MapSpec_Rise8:		BINCLUDE	"mappings/special stage/Slope up - Frame 8.bin"
MapSpec_Rise9:		BINCLUDE	"mappings/special stage/Slope up - Frame 9.bin"
MapSpec_Rise10:		BINCLUDE	"mappings/special stage/Slope up - Frame 10.bin"
MapSpec_Rise11:		BINCLUDE	"mappings/special stage/Slope up - Frame 11.bin"
MapSpec_Rise12:		BINCLUDE	"mappings/special stage/Slope up - Frame 12.bin"
MapSpec_Rise13:		BINCLUDE	"mappings/special stage/Slope up - Frame 13.bin"
MapSpec_Rise14:		BINCLUDE	"mappings/special stage/Slope up - Frame 14.bin"
MapSpec_Rise15:		BINCLUDE	"mappings/special stage/Slope up - Frame 15.bin"
MapSpec_Rise16:		BINCLUDE	"mappings/special stage/Slope up - Frame 16.bin"
MapSpec_Rise17:		BINCLUDE	"mappings/special stage/Slope up - Frame 17.bin"

;-----------------------------------------------------------------------------------
; Straight path
;-----------------------------------------------------------------------------------
MapSpec_Straight1:	BINCLUDE	"mappings/special stage/Straight path - Frame 1.bin"
MapSpec_Straight2:	BINCLUDE	"mappings/special stage/Straight path - Frame 2.bin"
MapSpec_Straight3:	BINCLUDE	"mappings/special stage/Straight path - Frame 3.bin"
MapSpec_Straight4:	BINCLUDE	"mappings/special stage/Straight path - Frame 4.bin"

;-----------------------------------------------------------------------------------
; Exit curve + slope down
;-----------------------------------------------------------------------------------
MapSpec_Drop1:		BINCLUDE	"mappings/special stage/Slope down - Frame 1.bin"
MapSpec_Drop2:		BINCLUDE	"mappings/special stage/Slope down - Frame 2.bin"
MapSpec_Drop3:		BINCLUDE	"mappings/special stage/Slope down - Frame 3.bin"
MapSpec_Drop4:		BINCLUDE	"mappings/special stage/Slope down - Frame 4.bin"
MapSpec_Drop5:		BINCLUDE	"mappings/special stage/Slope down - Frame 5.bin"
MapSpec_Drop6:		BINCLUDE	"mappings/special stage/Slope down - Frame 6.bin"
MapSpec_Drop7:		BINCLUDE	"mappings/special stage/Slope down - Frame 7.bin"
MapSpec_Drop8:		BINCLUDE	"mappings/special stage/Slope down - Frame 8.bin"
MapSpec_Drop9:		BINCLUDE	"mappings/special stage/Slope down - Frame 9.bin"
MapSpec_Drop10:		BINCLUDE	"mappings/special stage/Slope down - Frame 10.bin"
MapSpec_Drop11:		BINCLUDE	"mappings/special stage/Slope down - Frame 11.bin"
MapSpec_Drop12:		BINCLUDE	"mappings/special stage/Slope down - Frame 12.bin"
MapSpec_Drop13:		BINCLUDE	"mappings/special stage/Slope down - Frame 13.bin"
MapSpec_Drop14:		BINCLUDE	"mappings/special stage/Slope down - Frame 14.bin"
MapSpec_Drop15:		BINCLUDE	"mappings/special stage/Slope down - Frame 15.bin"
MapSpec_Drop16:		BINCLUDE	"mappings/special stage/Slope down - Frame 16.bin"
MapSpec_Drop17:		BINCLUDE	"mappings/special stage/Slope down - Frame 17.bin"

;-----------------------------------------------------------------------------------
; Curved path
;-----------------------------------------------------------------------------------
MapSpec_Turning1:	BINCLUDE	"mappings/special stage/Curve right - Frame 1.bin"
MapSpec_Turning2:	BINCLUDE	"mappings/special stage/Curve right - Frame 2.bin"
MapSpec_Turning3:	BINCLUDE	"mappings/special stage/Curve right - Frame 3.bin"
MapSpec_Turning4:	BINCLUDE	"mappings/special stage/Curve right - Frame 4.bin"
MapSpec_Turning5:	BINCLUDE	"mappings/special stage/Curve right - Frame 5.bin"
MapSpec_Turning6:	BINCLUDE	"mappings/special stage/Curve right - Frame 6.bin"

;-----------------------------------------------------------------------------------
; Exit curve
;-----------------------------------------------------------------------------------
MapSpec_Unturn1:	BINCLUDE	"mappings/special stage/Curve right - Frame 7.bin"
MapSpec_Unturn2:	BINCLUDE	"mappings/special stage/Curve right - Frame 8.bin"
MapSpec_Unturn3:	BINCLUDE	"mappings/special stage/Curve right - Frame 9.bin"
MapSpec_Unturn4:	BINCLUDE	"mappings/special stage/Curve right - Frame 10.bin"
MapSpec_Unturn5:	BINCLUDE	"mappings/special stage/Curve right - Frame 11.bin"

;-----------------------------------------------------------------------------------
; Enter curve
;-----------------------------------------------------------------------------------
MapSpec_Turn1:		BINCLUDE	"mappings/special stage/Begin curve right - Frame 1.bin"
MapSpec_Turn2:		BINCLUDE	"mappings/special stage/Begin curve right - Frame 2.bin"
MapSpec_Turn3:		BINCLUDE	"mappings/special stage/Begin curve right - Frame 3.bin"
MapSpec_Turn4:		BINCLUDE	"mappings/special stage/Begin curve right - Frame 4.bin"
MapSpec_Turn5:		BINCLUDE	"mappings/special stage/Begin curve right - Frame 5.bin"
MapSpec_Turn6:		BINCLUDE	"mappings/special stage/Begin curve right - Frame 6.bin"
MapSpec_Turn7:		BINCLUDE	"mappings/special stage/Begin curve right - Frame 7.bin"
; ---------------------------------------------------------------------------
; Compressed graphics - primary patterns and block mappings
; ---------------------------------------------------------------------------
; ===========================================================================
; Zone 00
Kosp_GHZ:	binclude	"art/kosinski/level/8x8 - GHZ.kosp"
Map16_GHZ:	binclude	"mappings/16x16/GHZ.kosp"
Map128_GHZ:	binclude	"mappings/128x128/GHZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 endif
; ===========================================================================
; Zone 01
Kosp_LZ:	binclude	"art/kosinski/level/8x8 - LZ.kosp"
Map16_LZ:	binclude	"mappings/16x16/LZ.kosp"
Map128_LZ:	binclude	"mappings/128x128/LZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - LZ.kosp"
		binclude	"mappings/16x16/LZ.kosp"
		binclude	"mappings/128x128/LZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - LZ.kosp"
		binclude	"mappings/16x16/LZ.kosp"
		binclude	"mappings/128x128/LZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - LZ.kosp"
		binclude	"mappings/16x16/LZ.kosp"
		binclude	"mappings/128x128/LZ.kosp"
 endif
; ===========================================================================
; Zone 02
Kosp_CPZ:	binclude	"art/kosinski/level/8x8 - CPZ.kosp"
Map16_CPZ:	binclude	"mappings/16x16/CPZ.kosp"
Map128_CPZ:	binclude	"mappings/128x128/CPZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - CPZ.kosp"
		binclude	"mappings/16x16/CPZ.kosp"
		binclude	"mappings/128x128/CPZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - CPZ.kosp"
		binclude	"mappings/16x16/CPZ.kosp"
		binclude	"mappings/128x128/CPZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - CPZ.kosp"
		binclude	"mappings/16x16/CPZ.kosp"
		binclude	"mappings/128x128/CPZ.kosp"
 endif
; ===========================================================================
; Zone 03
Kosp_EHZ:	binclude	"art/kosinski/level/8x8 - EHZ.kosp"
Map16_EHZ:	binclude	"mappings/16x16/EHZ.kosp"
Map128_EHZ:	binclude	"mappings/128x128/EHZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - EHZ.kosp"
		binclude	"mappings/16x16/EHZ.kosp"
		binclude	"mappings/128x128/EHZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - EHZ.kosp"
		binclude	"mappings/16x16/EHZ.kosp"
		binclude	"mappings/128x128/EHZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - EHZ.kosp"
		binclude	"mappings/16x16/EHZ.kosp"
		binclude	"mappings/128x128/EHZ.kosp"
 endif
; ===========================================================================
; Zone 04
Kosp_HPZ:	binclude	"art/kosinski/level/8x8 - HPZ.kosp"
Map16_HPZ:	binclude	"mappings/16x16/HPZ.kosp"
Map128_HPZ:	binclude	"mappings/128x128/HPZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - HPZ.kosp"
		binclude	"mappings/16x16/HPZ.kosp"
		binclude	"mappings/128x128/HPZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - HPZ.kosp"
		binclude	"mappings/16x16/HPZ.kosp"
		binclude	"mappings/128x128/HPZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - HPZ.kosp"
		binclude	"mappings/16x16/HPZ.kosp"
		binclude	"mappings/128x128/HPZ.kosp"
 endif
; ===========================================================================
; Zone 05
Kosp_HTZ:	binclude	"art/kosinski/level/8x8 - HTZ.kosp"
Map16_HTZ:	binclude	"mappings/16x16/HTZ.kosp"
Map128_HTZ:	binclude	"mappings/128x128/HTZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - HTZ.kosp"
		binclude	"mappings/16x16/HTZ.kosp"
		binclude	"mappings/128x128/HTZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - HTZ.kosp"
		binclude	"mappings/16x16/HTZ.kosp"
		binclude	"mappings/128x128/HTZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - HTZ.kosp"
		binclude	"mappings/16x16/HTZ.kosp"
		binclude	"mappings/128x128/HTZ.kosp"
 endif
; ===========================================================================
; Zone 06 (Filler; currently S1's leftover ending)
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 endif
; From here onwards, filler data for the NEW levels.
; ===========================================================================
; Zone 07
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 endif
; ===========================================================================
; Zone 08
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 endif
; ===========================================================================
; Zone 09
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 endif
; ===========================================================================
; Zone $0A
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 endif
; ===========================================================================
; Zone $0B
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 endif
; ===========================================================================
; Zone $0C
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 endif
; ===========================================================================
; Zone $0D
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 endif
; ===========================================================================
; Zone $0E
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 endif
; ===========================================================================
; Zone $0F
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 endif
; ===========================================================================
; Zone $10
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 if TimeTravel=1
; Past
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Good Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
; Bad Future
		binclude	"art/kosinski/level/8x8 - GHZ.kosp"
		binclude	"mappings/16x16/GHZ.kosp"
		binclude	"mappings/128x128/GHZ.kosp"
 endif
; ---------------------------------------------------------------------------
S1_AngleMap:	binclude	"collision/S1/Angle Map.bin"
		even
S1_ColArray1:	binclude	"collision/S1/Collision Array (Normal).bin"
		even
S1_ColArray2:	binclude	"collision/S1/Collision Array (Rotated).bin"
		even
; ---------------------------------------------------------------------------
AngleMap:	binclude	"collision/Curve and resistance mapping.bin"
		even
ColArray1:	binclude	"collision/Collision array 1.bin"
		even
ColArray2:	binclude	"collision/Collision array 2.bin"
		even
; ---------------------------------------------------------------------------
; Present Collision
; ---------------------------------------------------------------------------
Col_GHZ1:	binclude	"collision/present/GHZ1.bin"	; To be replaced
		even
Col_GHZ2:	binclude	"collision/present/GHZ2.bin"	; To be replaced
		even
Col_GHZ3:	binclude	"collision/present/GHZ3.bin"	; To be replaced
		even
Col_GHZ4:	binclude	"collision/present/GHZ4.bin"	; To be replaced
		even
Col_LZ1:	binclude	"collision/present/LZ1.bin"
		even
Col_LZ2:	binclude	"collision/present/LZ2.bin"
		even
Col_LZ3:	binclude	"collision/present/LZ3.bin"
		even
Col_LZ4:	binclude	"collision/present/LZ4.bin"
		even
Col_EHZ1:	binclude	"collision/present/EHZ1.bin"
		even
Col_EHZ2:	binclude	"collision/present/EHZ2.bin"
		even
Col_EHZ3:	binclude	"collision/present/EHZ3.bin"
		even
Col_EHZ4:	binclude	"collision/present/EHZ4.bin"
		even
Col_CPZ1:	binclude	"collision/present/CPZ1.bin"
		even
Col_CPZ2:	binclude	"collision/present/CPZ2.bin"
		even
Col_CPZ3:	binclude	"collision/present/CPZ3.bin"
		even
Col_CPZ4:	binclude	"collision/present/CPZ4.bin"
		even
Col_HPZ1:	binclude	"collision/present/HPZ1.bin"
		even
Col_HPZ2:	binclude	"collision/present/HPZ2.bin"
		even
Col_HPZ3:	binclude	"collision/present/HPZ3.bin"
		even
Col_HPZ4:	binclude	"collision/present/HPZ4.bin"
		even
Col_HTZ1:	binclude	"collision/present/HTZ1.bin"
		even
Col_HTZ2:	binclude	"collision/present/HTZ2.bin"
		even
Col_HTZ3:	binclude	"collision/present/HTZ3.bin"
		even
Col_HTZ4:	binclude	"collision/present/HTZ4.bin"
		even
 if TimeTravel=1
; ---------------------------------------------------------------------------
; Past Collision
; ---------------------------------------------------------------------------
PCol_GHZ1:	binclude	"collision/past/GHZ1.bin"	; To be replaced
		even
PCol_GHZ2:	binclude	"collision/past/GHZ2.bin"	; To be replaced
		even
PCol_GHZ3:	binclude	"collision/past/GHZ3.bin"	; To be replaced
		even
PCol_GHZ4:	binclude	"collision/past/GHZ4.bin"	; To be replaced
		even
PCol_LZ1:	binclude	"collision/past/LZ1.bin"
		even
PCol_LZ2:	binclude	"collision/past/LZ2.bin"
		even
PCol_LZ3:	binclude	"collision/past/LZ3.bin"
		even
PCol_LZ4:	binclude	"collision/past/LZ4.bin"
		even
PCol_EHZ1:	binclude	"collision/past/EHZ1.bin"
		even
PCol_EHZ2:	binclude	"collision/past/EHZ2.bin"
		even
PCol_EHZ3:	binclude	"collision/past/EHZ3.bin"
		even
PCol_EHZ4:	binclude	"collision/past/EHZ4.bin"
		even
PCol_CPZ1:	binclude	"collision/past/CPZ1.bin"
		even
PCol_CPZ2:	binclude	"collision/past/CPZ2.bin"
		even
PCol_CPZ3:	binclude	"collision/past/CPZ3.bin"
		even
PCol_CPZ4:	binclude	"collision/past/CPZ4.bin"
		even
PCol_HPZ1:	binclude	"collision/past/HPZ1.bin"
		even
PCol_HPZ2:	binclude	"collision/past/HPZ2.bin"
		even
PCol_HPZ3:	binclude	"collision/past/HPZ3.bin"
		even
PCol_HPZ4:	binclude	"collision/past/HPZ4.bin"
		even
PCol_HTZ1:	binclude	"collision/past/HTZ1.bin"
		even
PCol_HTZ2:	binclude	"collision/past/HTZ2.bin"
		even
PCol_HTZ3:	binclude	"collision/past/HTZ3.bin"
		even
PCol_HTZ4:	binclude	"collision/past/HTZ4.bin"
		even
; ---------------------------------------------------------------------------
; Good Future Collision
; ---------------------------------------------------------------------------
GCol_GHZ1:	binclude	"collision/good future/GHZ1.bin"	; To be replaced
		even
GCol_GHZ2:	binclude	"collision/good future/GHZ2.bin"	; To be replaced
		even
GCol_GHZ3:	binclude	"collision/good future/GHZ3.bin"	; To be replaced
		even
GCol_GHZ4:	binclude	"collision/good future/GHZ4.bin"	; To be replaced
		even
GCol_LZ1:	binclude	"collision/good future/LZ1.bin"
		even
GCol_LZ2:	binclude	"collision/good future/LZ2.bin"
		even
GCol_LZ3:	binclude	"collision/good future/LZ3.bin"
		even
GCol_LZ4:	binclude	"collision/good future/LZ4.bin"
		even
GCol_EHZ1:	binclude	"collision/good future/EHZ1.bin"
		even
GCol_EHZ2:	binclude	"collision/good future/EHZ2.bin"
		even
GCol_EHZ3:	binclude	"collision/good future/EHZ3.bin"
		even
GCol_EHZ4:	binclude	"collision/good future/EHZ4.bin"
		even
GCol_CPZ1:	binclude	"collision/good future/CPZ1.bin"
		even
GCol_CPZ2:	binclude	"collision/good future/CPZ2.bin"
		even
GCol_CPZ3:	binclude	"collision/good future/CPZ3.bin"
		even
GCol_CPZ4:	binclude	"collision/good future/CPZ4.bin"
		even
GCol_HPZ1:	binclude	"collision/good future/HPZ1.bin"
		even
GCol_HPZ2:	binclude	"collision/good future/HPZ2.bin"
		even
GCol_HPZ3:	binclude	"collision/good future/HPZ3.bin"
		even
GCol_HPZ4:	binclude	"collision/good future/HPZ4.bin"
		even
GCol_HTZ1:	binclude	"collision/good future/HTZ1.bin"
		even
GCol_HTZ2:	binclude	"collision/good future/HTZ2.bin"
		even
GCol_HTZ3:	binclude	"collision/good future/HTZ3.bin"
		even
GCol_HTZ4:	binclude	"collision/good future/HTZ4.bin"
		even
; ---------------------------------------------------------------------------
; Bad Future Collision
; ---------------------------------------------------------------------------
BCol_GHZ1:	binclude	"collision/bad future/GHZ1.bin"	; To be replaced
		even
BCol_GHZ2:	binclude	"collision/bad future/GHZ2.bin"	; To be replaced
		even
BCol_GHZ3:	binclude	"collision/bad future/GHZ3.bin"	; To be replaced
		even
BCol_GHZ4:	binclude	"collision/bad future/GHZ4.bin"	; To be replaced
		even
BCol_LZ1:	binclude	"collision/bad future/LZ1.bin"
		even
BCol_LZ2:	binclude	"collision/bad future/LZ2.bin"
		even
BCol_LZ3:	binclude	"collision/bad future/LZ3.bin"
		even
BCol_LZ4:	binclude	"collision/bad future/LZ4.bin"
		even
BCol_EHZ1:	binclude	"collision/bad future/EHZ1.bin"
		even
BCol_EHZ2:	binclude	"collision/bad future/EHZ2.bin"
		even
BCol_EHZ3:	binclude	"collision/bad future/EHZ3.bin"
		even
BCol_EHZ4:	binclude	"collision/bad future/EHZ4.bin"
		even
BCol_CPZ1:	binclude	"collision/bad future/CPZ1.bin"
		even
BCol_CPZ2:	binclude	"collision/bad future/CPZ2.bin"
		even
BCol_CPZ3:	binclude	"collision/bad future/CPZ3.bin"
		even
BCol_CPZ4:	binclude	"collision/bad future/CPZ4.bin"
		even
BCol_HPZ1:	binclude	"collision/bad future/HPZ1.bin"
		even
BCol_HPZ2:	binclude	"collision/bad future/HPZ2.bin"
		even
BCol_HPZ3:	binclude	"collision/bad future/HPZ3.bin"
		even
BCol_HPZ4:	binclude	"collision/bad future/HPZ4.bin"
		even
BCol_HTZ1:	binclude	"collision/bad future/HTZ1.bin"
		even
BCol_HTZ2:	binclude	"collision/bad future/HTZ2.bin"
		even
BCol_HTZ3:	binclude	"collision/bad future/HTZ3.bin"
		even
BCol_HTZ4:	binclude	"collision/bad future/HTZ4.bin"
		even
 endif
; ---------------------------------------------------------------------------
; Level layouts, four entries per act
; ---------------------------------------------------------------------------
Level_Index:
		; Zone 00
		dc.w Level_GHZ1-Level_Index
		dc.w Level_GHZ2-Level_Index
		dc.w Level_GHZ3-Level_Index
		dc.w Level_GHZ4-Level_Index
		; Zone 01 - Placeholder entries
		dc.w Level_LZ1-Level_Index
		dc.w Level_LZ2-Level_Index
		dc.w Level_LZ3-Level_Index
		dc.w Level_LZ4-Level_Index
		; Zone 02
		dc.w Level_CPZ1-Level_Index
		dc.w Level_CPZ2-Level_Index
		dc.w Level_CPZ3-Level_Index
		dc.w Level_CPZ4-Level_Index
		; Zone 03
		dc.w Level_EHZ1-Level_Index
		dc.w Level_EHZ2-Level_Index
		dc.w Level_EHZ3-Level_Index
		dc.w Level_EHZ4-Level_Index
		; Zone 04
		dc.w Level_HPZ1-Level_Index
		dc.w Level_HPZ2-Level_Index
		dc.w Level_HPZ3-Level_Index
		dc.w Level_HPZ4-Level_Index
		; Zone 05
		dc.w Level_HTZ1-Level_Index
		dc.w Level_HTZ2-Level_Index
		dc.w Level_HTZ3-Level_Index
		dc.w Level_HTZ4-Level_Index
		; Zone 06 - Placeholder entries
		dc.w Level_MTZ1-Level_Index
		dc.w Level_MTZ2-Level_Index
		dc.w Level_MTZ3-Level_Index
		dc.w Level_MTZ4-Level_Index

Level_GHZ1:	binclude	"level/layout/GHZ_1.kosp"
Level_GHZ2:	binclude	"level/layout/GHZ_2.kosp"
Level_GHZ3:	binclude	"level/layout/GHZ_3.kosp"
Level_GHZ4:	binclude	"level/layout/GHZ_4.kosp"

Level_LZ1:	binclude	"level/layout/LZ_1.kosp"
Level_LZ2:	binclude	"level/layout/LZ_2.kosp"
Level_LZ3:	binclude	"level/layout/LZ_3.kosp"
Level_LZ4:	binclude	"level/layout/LZ_4.kosp"

Level_CPZ1:	binclude	"level/layout/CPZ_1.kosp"
Level_CPZ2:	binclude	"level/layout/CPZ_2.kosp"
Level_CPZ3:	binclude	"level/layout/CPZ_3.kosp"
Level_CPZ4:	binclude	"level/layout/CPZ_4.kosp"

Level_EHZ1:	binclude	"level/layout/EHZ_1.kosp"
Level_EHZ2:	binclude	"level/layout/EHZ_2.kosp"
Level_EHZ3:	binclude	"level/layout/EHZ_3.kosp"
Level_EHZ4:	binclude	"level/layout/EHZ_4.kosp"

Level_HPZ1:	binclude	"level/layout/HPZ_1.kosp"
Level_HPZ2:	binclude	"level/layout/HPZ_2.kosp"
Level_HPZ3:	binclude	"level/layout/HPZ_3.kosp"
Level_HPZ4:	binclude	"level/layout/HPZ_4.kosp"

Level_HTZ1:	binclude	"level/layout/HTZ_1.kosp"
Level_HTZ2:	binclude	"level/layout/HTZ_2.kosp"
Level_HTZ3:	binclude	"level/layout/HTZ_3.kosp"
Level_HTZ4:	binclude	"level/layout/HTZ_4.kosp"

Level_MTZ1:	binclude	"level/layout/MTZ_1.kosp"
Level_MTZ2:	binclude	"level/layout/MTZ_2.kosp"
Level_MTZ3:	binclude	"level/layout/MTZ_3.kosp"
Level_MTZ4:	binclude	"level/layout/MTZ_4.kosp"
Level_Null:	dc.l	0
; --------------------------------------------------------------------------------------
; Object layouts
; --------------------------------------------------------------------------------------
; Macro for marking the boundaries of an object layout file
ObjectLayoutBoundary macro
		dc.w	$FFFF,$0000,$0000
    endm

ObjPos_Index:
		dc.w ObjPos_GHZ1-ObjPos_Index
		dc.w ObjPos_GHZ2-ObjPos_Index
		dc.w ObjPos_GHZ3-ObjPos_Index
		dc.w ObjPos_GHZ4-ObjPos_Index

		dc.w ObjPos_LZ1-ObjPos_Index
		dc.w ObjPos_LZ2-ObjPos_Index
		dc.w ObjPos_LZ3-ObjPos_Index
		dc.w ObjPos_LZ4-ObjPos_Index

		dc.w ObjPos_CPZ1-ObjPos_Index
		dc.w ObjPos_CPZ2-ObjPos_Index
		dc.w ObjPos_CPZ3-ObjPos_Index
		dc.w ObjPos_CPZ4-ObjPos_Index

		dc.w ObjPos_EHZ1-ObjPos_Index
		dc.w ObjPos_EHZ2-ObjPos_Index
		dc.w ObjPos_EHZ3-ObjPos_Index
		dc.w ObjPos_EHZ4-ObjPos_Index

		dc.w ObjPos_HPZ1-ObjPos_Index
		dc.w ObjPos_HPZ2-ObjPos_Index
		dc.w ObjPos_HPZ3-ObjPos_Index
		dc.w ObjPos_HPZ4-ObjPos_Index

		dc.w ObjPos_HTZ1-ObjPos_Index
		dc.w ObjPos_HTZ2-ObjPos_Index
		dc.w ObjPos_HTZ3-ObjPos_Index
		dc.w ObjPos_HTZ4-ObjPos_Index

		dc.w ObjPos_Ending-ObjPos_Index
		dc.w ObjPos_Ending-ObjPos_Index
		dc.w ObjPos_Ending-ObjPos_Index
		dc.w ObjPos_Ending-ObjPos_Index

		ObjectLayoutBoundary
ObjPos_GHZ1:	binclude	"level/objects/GHZ_1.bin"
		ObjectLayoutBoundary
ObjPos_GHZ2:	binclude	"level/objects/GHZ_2.bin"
		ObjectLayoutBoundary
ObjPos_GHZ3:	binclude	"level/objects/GHZ_3.bin"
		ObjectLayoutBoundary
ObjPos_GHZ4:	binclude	"level/objects/GHZ_4.bin"
		ObjectLayoutBoundary
ObjPos_LZ1:	binclude	"level/objects/LZ_1.bin"
		ObjectLayoutBoundary
ObjPos_LZ2:	binclude	"level/objects/LZ_2.bin"
		ObjectLayoutBoundary
ObjPos_LZ3:	binclude	"level/objects/LZ_3.bin"
		ObjectLayoutBoundary
ObjPos_LZ4:	binclude	"level/objects/LZ_4.bin"
		ObjectLayoutBoundary
ObjPos_CPZ1:	binclude	"level/objects/CPZ_1.bin"
		ObjectLayoutBoundary
ObjPos_CPZ2:	binclude	"level/objects/CPZ_2.bin"
		ObjectLayoutBoundary
ObjPos_CPZ3:	binclude	"level/objects/CPZ_3.bin"
		ObjectLayoutBoundary
ObjPos_CPZ4:	binclude	"level/objects/CPZ_4.bin"
		ObjectLayoutBoundary
ObjPos_EHZ1:	binclude	"level/objects/EHZ_1.bin"
		ObjectLayoutBoundary
ObjPos_EHZ2:	binclude	"level/objects/EHZ_2.bin"
		ObjectLayoutBoundary
ObjPos_EHZ3:	binclude	"level/objects/EHZ_3.bin"
		ObjectLayoutBoundary
ObjPos_EHZ4:	binclude	"level/objects/EHZ_4.bin"
		ObjectLayoutBoundary
ObjPos_HPZ1:	binclude	"level/objects/HPZ_1.bin"
		ObjectLayoutBoundary
ObjPos_HPZ2:	binclude	"level/objects/HPZ_2.bin"
		ObjectLayoutBoundary
ObjPos_HPZ3:	binclude	"level/objects/HPZ_3.bin"
		ObjectLayoutBoundary
ObjPos_HPZ4:	binclude	"level/objects/HPZ_4.bin"
		ObjectLayoutBoundary
ObjPos_HTZ1:	binclude	"level/objects/HTZ_1.bin"
		ObjectLayoutBoundary
ObjPos_HTZ2:	binclude	"level/objects/HTZ_2.bin"
		ObjectLayoutBoundary
ObjPos_HTZ3:	binclude	"level/objects/HTZ_3.bin"
		ObjectLayoutBoundary
ObjPos_HTZ4:	binclude	"level/objects/HTZ_4.bin"
		ObjectLayoutBoundary
ObjPos_Ending:	binclude	"level/objects/S1/ending.bin"
		ObjectLayoutBoundary
ObjPos_Null:	ObjectLayoutBoundary
		even
; ---------------------------------------------------------------------------
		; platform objects in LZ (unused)
		dc.w ObjPos_LZ1pf1-ObjPos_Index,ObjPos_LZ1pf2-ObjPos_Index
		dc.w ObjPos_LZ2pf1-ObjPos_Index,ObjPos_LZ2pf2-ObjPos_Index
		dc.w ObjPos_LZ3pf1-ObjPos_Index,ObjPos_LZ3pf2-ObjPos_Index
		dc.w ObjPos_LZ1pf1-ObjPos_Index,ObjPos_LZ1pf2-ObjPos_Index
		; platform objects in SBZ (unused)
		dc.w ObjPos_SBZ1pf1-ObjPos_Index,ObjPos_SBZ1pf2-ObjPos_Index
		dc.w ObjPos_SBZ1pf3-ObjPos_Index,ObjPos_SBZ1pf4-ObjPos_Index
		dc.w ObjPos_SBZ1pf5-ObjPos_Index,ObjPos_SBZ1pf6-ObjPos_Index
		dc.w ObjPos_SBZ1pf1-ObjPos_Index,ObjPos_SBZ1pf2-ObjPos_Index
ObjPos_LZ1pf1:	binclude	"level/objects/S1/lz1pf1.bin"
		ObjectLayoutBoundary
ObjPos_LZ1pf2:	binclude	"level/objects/S1/lz1pf2.bin"
		ObjectLayoutBoundary
ObjPos_LZ2pf1:	binclude	"level/objects/S1/lz2pf1.bin"
		ObjectLayoutBoundary
ObjPos_LZ2pf2:	binclude	"level/objects/S1/lz2pf2.bin"
		ObjectLayoutBoundary
ObjPos_LZ3pf1:	binclude	"level/objects/S1/lz3pf1.bin"
		ObjectLayoutBoundary
ObjPos_LZ3pf2:	binclude	"level/objects/S1/lz3pf2.bin"
		ObjectLayoutBoundary
ObjPos_SBZ1pf1:	binclude	"level/objects/S1/sbz1pf1.bin"
		ObjectLayoutBoundary
ObjPos_SBZ1pf2:	binclude	"level/objects/S1/sbz1pf2.bin"
		ObjectLayoutBoundary
ObjPos_SBZ1pf3:	binclude	"level/objects/S1/sbz1pf3.bin"
		ObjectLayoutBoundary
ObjPos_SBZ1pf4:	binclude	"level/objects/S1/sbz1pf4.bin"
		ObjectLayoutBoundary
ObjPos_SBZ1pf5:	binclude	"level/objects/S1/sbz1pf5.bin"
		ObjectLayoutBoundary
ObjPos_SBZ1pf6:	binclude	"level/objects/S1/sbz1pf6.bin"
		ObjectLayoutBoundary
; ---------------------------------------------------------------------------
; Ring layouts; one entry per act, four entries per zone
; ---------------------------------------------------------------------------
RingPos_Index:
		dc.w RingPos_GHZ1-RingPos_Index
		dc.w RingPos_GHZ2-RingPos_Index
		dc.w RingPos_GHZ3-RingPos_Index
		dc.w RingPos_GHZ4-RingPos_Index

		dc.w RingPos_LZ1-RingPos_Index
		dc.w RingPos_LZ2-RingPos_Index
		dc.w RingPos_LZ3-RingPos_Index
		dc.w RingPos_LZ4-RingPos_Index

		dc.w RingPos_CPZ1-RingPos_Index
		dc.w RingPos_CPZ2-RingPos_Index
		dc.w RingPos_CPZ3-RingPos_Index
		dc.w RingPos_CPZ1-RingPos_Index

		dc.w RingPos_EHZ1-RingPos_Index
		dc.w RingPos_EHZ2-RingPos_Index
		dc.w RingPos_EHZ3-RingPos_Index
		dc.w RingPos_EHZ4-RingPos_Index

		dc.w RingPos_HPZ1-RingPos_Index
		dc.w RingPos_HPZ2-RingPos_Index
		dc.w RingPos_HPZ3-RingPos_Index
		dc.w RingPos_HPZ4-RingPos_Index

		dc.w RingPos_HTZ1-RingPos_Index
		dc.w RingPos_HTZ2-RingPos_Index
		dc.w RingPos_HTZ3-RingPos_Index
		dc.w RingPos_HTZ4-RingPos_Index

RingPos_GHZ1:	binclude	"level/rings/GHZ_1.bin"
		even
RingPos_GHZ2:	binclude	"level/rings/GHZ_2.bin"
		even
RingPos_GHZ3:	binclude	"level/rings/GHZ_3.bin"
		even
RingPos_GHZ4:	binclude	"level/rings/GHZ_4.bin"
		even
RingPos_LZ1:	binclude	"level/rings/LZ_1.bin"
		even
RingPos_LZ2:	binclude	"level/rings/LZ_2.bin"
		even
RingPos_LZ3:	binclude	"level/rings/LZ_3.bin"
		even
RingPos_LZ4:	binclude	"level/rings/LZ_4.bin"
		even
RingPos_CPZ1:	binclude	"level/rings/CPZ_1.bin"
		even
RingPos_CPZ2:	binclude	"level/rings/CPZ_2.bin"
		even
RingPos_CPZ3:	binclude	"level/rings/CPZ_3.bin"
		even
RingPos_CPZ4:	binclude	"level/rings/CPZ_4.bin"
		even
RingPos_EHZ1:	binclude	"level/rings/EHZ_1.bin"
		even
RingPos_EHZ2:	binclude	"level/rings/EHZ_2.bin"
		even
RingPos_EHZ3:	binclude	"level/rings/EHZ_3.bin"
		even
RingPos_EHZ4:	binclude	"level/rings/EHZ_4.bin"
		even
RingPos_HPZ1:	binclude	"level/rings/HPZ_1.bin"
		even
RingPos_HPZ2:	binclude	"level/rings/HPZ_2.bin"
		even
RingPos_HPZ3:	binclude	"level/rings/HPZ_3.bin"
		even
RingPos_HPZ4:	binclude	"level/rings/HPZ_4.bin"
		even
RingPos_HTZ1:	binclude	"level/rings/HTZ_1.bin"
		even
RingPos_HTZ2:	binclude	"level/rings/HTZ_2.bin"
		even
RingPos_HTZ3:	binclude	"level/rings/HTZ_3.bin"
		even
RingPos_HTZ4:	binclude	"level/rings/HTZ_4.bin"
		even
; ---------------------------------------------------------------------------
; These subroutines are yet to be properly implemented
; ---------------------------------------------------------------------------
; =============== S U B R O U T I N E =======================================


Find_SonicTails:
		moveq	#0,d0			; d0 = 0 if Sonic/Tails is left of object, 2 if right of object
		moveq	#0,d1			; d1 = 0 if Sonic/Tails is above object, 2 if below object
		lea	(v_player).w,a1
		move.w	obX(a0),d2
		sub.w	obX(a1),d2
		bpl.s	+
		neg.w	d2
		addq.w	#2,d0
+
		lea	(v_player2).w,a2
		move.w	obX(a0),d3
		sub.w	obX(a2),d3
		bpl.s	+
		neg.w	d3
		addq.w	#2,d1
+
		cmp.w	d3,d2
		bls.s	+
		movea.l	a2,a1
		move.w	d1,d0
		move.w	d3,d2
+
		moveq	#0,d1
		move.w	obY(a0),d3
		sub.w	obY(a1),d3
		bpl.s	+
		neg.w	d3
		addq.w	#2,d1
+
		rts
; End of function Find_SonicTails


; =============== S U B R O U T I N E =======================================


Change_FlipX:
		bclr	#0,obRender(a0)
		tst.w	d0
		beq.s	+
		bset	#0,obRender(a0)
+
		rts
; End of function Change_FlipX


; =============== S U B R O U T I N E =======================================


Change_FlipXWithVelocity:
		bclr	#0,obRender(a0)
		tst.w	obVelX(a0)
		bmi.s	+
		bset	#0,obRender(a0)
+
		rts
; End of function Change_FlipXWithVelocity


; =============== S U B R O U T I N E =======================================

parent3 = 		$46 ; word ; parent of child objects
Change_FlipXUseParent:
		bclr	#0,obRender(a0)
		movea.w	parent3(a0),a1	; this doesn't exist yet; as object
		btst	#0,obRender(a1)	; variables end at $3F in this game
		beq.s	+
		bset	#0,obRender(a0)
+
		rts
; End of function Change_FlipXUseParent


; =============== S U B R O U T I N E =======================================


Find_OtherObject:
		moveq	#0,d0			; d0 = 0 if other object is left of calling object, 2 if right of it
		moveq	#0,d1			; d1 = 0 if other object is above calling object, 2 if below it
		move.w	obX(a0),d2
		sub.w	obX(a1),d2
		bpl.s	+
		neg.w	d2
		addq.w	#2,d0
+
		moveq	#0,d1
		move.w	obY(a0),d3
		sub.w	obY(a1),d3
		bpl.s	+
		neg.w	d3
		addq.w	#2,d1
+
		rts
; End of function Find_OtherObject
; ---------------------------------------------------------------------------
AutoTunnel_Data:
		dc.l AutoTunnel_00
		dc.l AutoTunnel_01_02
		dc.l AutoTunnel_01_02
		dc.l AutoTunnel_03
		dc.l AutoTunnel_04
		dc.l AutoTunnel_05
		dc.l AutoTunnel_06
		dc.l AutoTunnel_07
		dc.l AutoTunnel_08
		dc.l AutoTunnel_09
		dc.l AutoTunnel_0A
		dc.l AutoTunnel_0B
		dc.l AutoTunnel_0C
		dc.l AutoTunnel_0D
		dc.l AutoTunnel_0E
		dc.l AutoTunnel_0F
		dc.l AutoTunnel_10
		dc.l AutoTunnel_11
		dc.l AutoTunnel_12
		dc.l AutoTunnel_13
		dc.l AutoTunnel_14
		dc.l AutoTunnel_15		; LRZ2 first
		dc.l AutoTunnel_16
		dc.l AutoTunnel_17
		dc.l AutoTunnel_18
		dc.l AutoTunnel_19
		dc.l SpriteTerminator
		dc.l SpriteTerminator
		dc.l SpriteTerminator
		dc.l SpriteTerminator
		dc.l SpriteTerminator
		dc.l SpriteTerminator

AutoTunnel_00:
		dc.w   $C
		dc.w   $F60,  $578
		dc.w   $F60,  $548
		dc.w   $F60,  $378
AutoTunnel_01_02:
		dc.w   $38
		dc.w   $D40,  $770
		dc.w   $D48,  $770
		dc.w   $D50,  $770
		dc.w   $D58,  $770
		dc.w   $D60,  $770
		dc.w   $DB0,  $770
		dc.w   $DD0,  $77C
		dc.w   $DE0,  $79C
		dc.w   $DD6,  $7BC
		dc.w   $DB6,  $7CE
		dc.w   $D96,  $7CE
		dc.w   $D86,  $7C8
		dc.w   $D70,  $7A8
		dc.w   $D70,  $688
AutoTunnel_03:
		dc.w   $28
		dc.w   $D30,  $770
		dc.w   $DB0,  $770
		dc.w   $DD0,  $77C
		dc.w   $DE0,  $79C
		dc.w   $DD6,  $7BC
		dc.w   $DB6,  $7CE
		dc.w   $D96,  $7CE
		dc.w   $D86,  $7C8
		dc.w   $D70,  $7A8
		dc.w   $D70,  $748
AutoTunnel_04:
		dc.w  $38
		dc.w  $2CC0,  $9F0
		dc.w  $2CC8,  $9F0
		dc.w  $2CD0,  $9F0
		dc.w  $2CD8,  $9F0
		dc.w  $2CE0,  $9F0
		dc.w  $2D30,  $9F0
		dc.w  $2D50,  $9FC
		dc.w  $2D60,  $A1C
		dc.w  $2D56,  $A3C
		dc.w  $2D36,  $A4E
		dc.w  $2D16,  $A4E
		dc.w  $2D06,  $A48
		dc.w  $2CF0,  $A28
		dc.w  $2CF0,  $908
AutoTunnel_05:
		dc.w  $28
		dc.w  $2CB0,  $9F0
		dc.w  $2D30,  $9F0
		dc.w  $2D50,  $9FC
		dc.w  $2D60,  $A1C
		dc.w  $2D56,  $A3C
		dc.w  $2D36,  $A4E
		dc.w  $2D16,  $A4E
		dc.w  $2D06,  $A48
		dc.w  $2CF0,  $A28
		dc.w  $2CF0,  $9C8
AutoTunnel_06:
		dc.w  $38
		dc.w  $3640,  $A70
		dc.w  $3648,  $A70
		dc.w  $3650,  $A70
		dc.w  $3658,  $A70
		dc.w  $3660,  $A70
		dc.w  $36B0,  $A70
		dc.w  $36D0,  $A7C
		dc.w  $36E0,  $A9C
		dc.w  $36D6,  $ABC
		dc.w  $36B6,  $ACE
		dc.w  $3696,  $ACE
		dc.w  $3686,  $AC8
		dc.w  $3670,  $AA8
		dc.w  $3670,  $988
AutoTunnel_07:
		dc.w  $28
		dc.w  $3630,  $A70
		dc.w  $36B0,  $A70
		dc.w  $36D0,  $A7C
		dc.w  $36E0,  $A9C
		dc.w  $36D6,  $ABC
		dc.w  $36B6,  $ACE
		dc.w  $3696,  $ACE
		dc.w  $3686,  $AC8
		dc.w  $3670,  $AA8
		dc.w  $3670,  $A48
AutoTunnel_08:
		dc.w  $38
		dc.w  $37C0,  $7F0
		dc.w  $37C8,  $7F0
		dc.w  $37D0,  $7F0
		dc.w  $37D8,  $7F0
		dc.w  $37E0,  $7F0
		dc.w  $3830,  $7F0
		dc.w  $3850,  $7FC
		dc.w  $3860,  $81C
		dc.w  $3856,  $83C
		dc.w  $3836,  $84E
		dc.w  $3816,  $84E
		dc.w  $3806,  $848
		dc.w  $37F0,  $828
		dc.w  $37F0,  $708
AutoTunnel_09:
		dc.w  $28
		dc.w  $37B0,  $7F0
		dc.w  $3830,  $7F0
		dc.w  $3850,  $7FC
		dc.w  $3860,  $81C
		dc.w  $3856,  $83C
		dc.w  $3836,  $84E
		dc.w  $3816,  $84E
		dc.w  $3806,  $848
		dc.w  $37F0,  $828
		dc.w  $37F0,  $7C8
AutoTunnel_0A:
		dc.w  $38
		dc.w  $29C0,  $470
		dc.w  $29C8,  $470
		dc.w  $29D0,  $470
		dc.w  $29D8,  $470
		dc.w  $29E0,  $470
		dc.w  $2A30,  $470
		dc.w  $2A50,  $47C
		dc.w  $2A60,  $49C
		dc.w  $2A56,  $4BC
		dc.w  $2A36,  $4CE
		dc.w  $2A16,  $4CE
		dc.w  $2A06,  $4C8
		dc.w  $29F0,  $4A8
		dc.w  $29F0,  $388
AutoTunnel_0B:
		dc.w  $28
		dc.w  $29B0,  $470
		dc.w  $2A30,  $470
		dc.w  $2A50,  $47C
		dc.w  $2A60,  $49C
		dc.w  $2A56,  $4BC
		dc.w  $2A36,  $4CE
		dc.w  $2A16,  $4CE
		dc.w  $2A06,  $4C8
		dc.w  $29F0,  $4A8
		dc.w  $29F0,  $448
AutoTunnel_0C:
		dc.w  $104
		dc.w  $26C0,  $530
		dc.w  $26C0,  $6E0
		dc.w  $26B2,  $700
		dc.w  $2692,  $710
		dc.w  $25F2,  $710
		dc.w  $25D2,  $704
		dc.w  $25C0,  $6E4
		dc.w  $25C0,  $4B4
		dc.w  $25B0,  $484
		dc.w  $2590,  $464
		dc.w  $2560,  $450
		dc.w  $24D0,  $450
		dc.w  $2490,  $43B
		dc.w  $2450,  $41F
		dc.w  $2400,  $410
		dc.w  $2300,  $410
		dc.w  $22D0,  $415
		dc.w  $22A0,  $42B
		dc.w  $2280,  $448
		dc.w  $2240,  $468
		dc.w  $2200,  $470
		dc.w  $21C0,  $468
		dc.w  $2180,  $448
		dc.w  $2160,  $42B
		dc.w  $2130,  $415
		dc.w  $2100,  $410
		dc.w  $20D0,  $415
		dc.w  $20A0,  $42B
		dc.w  $2080,  $448
		dc.w  $2040,  $468
		dc.w  $2000,  $470
		dc.w  $1FC0,  $468
		dc.w  $1F80,  $448
		dc.w  $1F60,  $42B
		dc.w  $1F30,  $415
		dc.w  $1F00,  $410
		dc.w  $1ED0,  $415
		dc.w  $1EA0,  $42B
		dc.w  $1E80,  $448
		dc.w  $1E40,  $468
		dc.w  $1E00,  $470
		dc.w  $1C70,  $470
		dc.w  $1C40,  $440
		dc.w  $1C40,  $320
		dc.w  $1C50,  $300
		dc.w  $1C70,  $2F0
		dc.w  $1F80,  $2F0
		dc.w  $1FD0,  $2E4
		dc.w  $2000,  $2C8
		dc.w  $2020,  $2AB
		dc.w  $2040,  $29A
		dc.w  $2080,  $290
		dc.w  $20C0,  $2A7
		dc.w  $2170,  $357
		dc.w  $21B0,  $370
		dc.w  $2400,  $370
		dc.w  $2440,  $380
		dc.w  $2480,  $390
		dc.w  $24B0,  $384
		dc.w  $24C0,  $364
		dc.w  $24C0,   $C4
		dc.w  $2490,   $90
		dc.w  $2450,   $9C
		dc.w  $2440,   $CC
		dc.w  $2440,   $FC
AutoTunnel_0D:
		dc.w  $64
		dc.w  $33C0,  $130
		dc.w  $33C0,  $1E0
		dc.w  $33D0,  $200
		dc.w  $3400,  $210
		dc.w  $3450,  $220
		dc.w  $34A0,  $270
		dc.w  $34C0,  $2A0
		dc.w  $34C0,  $460
		dc.w  $34CE,  $480
		dc.w  $34F0,  $490
		dc.w  $3710,  $490
		dc.w  $372E,  $480
		dc.w  $3740,  $460
		dc.w  $3740,  $330
		dc.w  $3720,  $310
		dc.w  $35F0,  $310
		dc.w  $35CE,  $300
		dc.w  $35C0,  $2E0
		dc.w  $35C0,   $40
		dc.w  $35CC,   $20
		dc.w  $3600,   $10
		dc.w  $3690,   $10
		dc.w  $36B4,   $20
		dc.w  $36C0,   $40
		dc.w  $36C0,   $80
AutoTunnel_0E:
		dc.w  $38
		dc.w  $14C0,  $AB0
		dc.w  $14C0,  $B60
		dc.w  $14D0,  $B80
		dc.w  $14F0,  $B90
		dc.w  $1610,  $B90
		dc.w  $1630,  $B80
		dc.w  $1640,  $B60
		dc.w  $1640,  $8C0
		dc.w  $1650,  $8A0
		dc.w  $1670,  $890
		dc.w  $1890,  $890
		dc.w  $18B0,  $89C
		dc.w  $18C0,  $8BC
		dc.w  $18C0,  $8FC
AutoTunnel_0F:
		dc.w  $38
		dc.w  $3840,  $730
		dc.w  $3840,  $860
		dc.w  $3832,  $880
		dc.w  $3802,  $890
		dc.w  $37D2,  $884
		dc.w  $37C0,  $864
		dc.w  $37C0,  $3D4
		dc.w  $37D0,  $3B4
		dc.w  $37F0,  $39C
		dc.w  $3820,  $390
		dc.w  $3990,  $390
		dc.w  $39B0,  $39C
		dc.w  $39C0,  $3BC
		dc.w  $39C0,  $3FC
AutoTunnel_10:
		dc.w   $7C
		dc.w   $F60,  $5C8
		dc.w   $F60,  $950
		dc.w   $F64,  $980
		dc.w   $F68,  $990
		dc.w   $F73,  $9B0
		dc.w   $F82,  $9D0
		dc.w   $F8C,  $9E0
		dc.w   $F98,  $9F0
		dc.w   $FA5,  $A00
		dc.w   $FB5,  $A10
		dc.w   $FC5,  $A1C
		dc.w   $FD5,  $A28
		dc.w   $FF5,  $A38
		dc.w  $1005,  $A40
		dc.w  $1025,  $A4A
		dc.w  $1035,  $A4C
		dc.w  $1055,  $A50
		dc.w  $1265,  $A50
		dc.w  $12A5,  $A48
		dc.w  $12C5,  $A3C
		dc.w  $12E5,  $A2C
		dc.w  $12F5,  $A20
		dc.w  $1305,  $A14
		dc.w  $1315,  $A08
		dc.w  $1320,  $9F8
		dc.w  $132F,  $9E8
		dc.w  $1343,  $9C8
		dc.w  $1350,  $9A8
		dc.w  $135A,  $988
		dc.w  $1360,  $958
		dc.w  $1360,  $878
AutoTunnel_11:
		dc.w  $7C
		dc.w  $3760,  $1C8
		dc.w  $3760,  $510
		dc.w  $375A,  $540
		dc.w  $3750,  $560
		dc.w  $3743,  $580
		dc.w  $372F,  $5A0
		dc.w  $3720,  $5B0
		dc.w  $3715,  $5C0
		dc.w  $3705,  $5CC
		dc.w  $36F5,  $5D8
		dc.w  $36E5,  $5E4
		dc.w  $36C5,  $5F4
		dc.w  $36A5,  $600
		dc.w  $3665,  $608
		dc.w  $3655,  $608
		dc.w  $3635,  $604
		dc.w  $3625,  $602
		dc.w  $3605,  $5F8
		dc.w  $35F5,  $5F0
		dc.w  $35D5,  $5E0
		dc.w  $35C5,  $5D4
		dc.w  $35B5,  $5C8
		dc.w  $35A5,  $5B8
		dc.w  $3598,  $5A8
		dc.w  $358C,  $598
		dc.w  $3582,  $588
		dc.w  $3573,  $568
		dc.w  $3568,  $548
		dc.w  $3564,  $538
		dc.w  $3560,  $508
		dc.w  $3560,  $478
AutoTunnel_12:
		dc.w  $7C
		dc.w  $3460,  $5C8
		dc.w  $3460,  $690
		dc.w  $345A,  $6C0
		dc.w  $3450,  $6E0
		dc.w  $3443,  $700
		dc.w  $342F,  $720
		dc.w  $3420,  $730
		dc.w  $3415,  $740
		dc.w  $3405,  $74C
		dc.w  $33F5,  $758
		dc.w  $33E5,  $764
		dc.w  $33C5,  $774
		dc.w  $33A5,  $780
		dc.w  $3365,  $788
		dc.w  $3355,  $788
		dc.w  $3335,  $784
		dc.w  $3325,  $782
		dc.w  $3305,  $778
		dc.w  $32F5,  $770
		dc.w  $32D5,  $760
		dc.w  $32C5,  $754
		dc.w  $32B5,  $748
		dc.w  $32A5,  $738
		dc.w  $3298,  $728
		dc.w  $328C,  $718
		dc.w  $3282,  $708
		dc.w  $3273,  $6E8
		dc.w  $3268,  $6C8
		dc.w  $3264,  $6B8
		dc.w  $3260,  $688
		dc.w  $3260,  $5F8
AutoTunnel_13:
		dc.w  $28
		dc.w  $1C70,  $730
		dc.w  $1C70,  $6C0
		dc.w  $1C62,  $6A0
		dc.w  $1C42,  $692
		dc.w  $1C32,  $692
		dc.w  $1C12,  $69B
		dc.w  $1C00,  $6BB
		dc.w  $1C08,  $6DB
		dc.w  $1C28,  $6F0
		dc.w  $1CA8,  $6F0
AutoTunnel_14:
		dc.w  $28
		dc.w  $3670,  $830
		dc.w  $3670,  $7C0
		dc.w  $3662,  $7A0
		dc.w  $3642,  $792
		dc.w  $3632,  $792
		dc.w  $3612,  $79B
		dc.w  $3600,  $7BB
		dc.w  $3608,  $7DB
		dc.w  $3628,  $7F0
		dc.w  $36A8,  $7F0
AutoTunnel_15:
		dc.w  $30
		dc.w  $11B8,  $6F0
		dc.w  $1270,  $6F0
		dc.w  $128C,  $6F3
		dc.w  $12A1,  $6FE
		dc.w  $12AD,  $710
		dc.w  $12B0,  $728
		dc.w  $12B0,  $8B0
		dc.w  $12AC,  $8D1
		dc.w  $12A0,  $8E3
		dc.w  $128C,  $8EE
		dc.w  $1270,  $8F0
		dc.w  $11B8,  $8F0
AutoTunnel_16:
		dc.w  $80
		dc.w  $17B8,  $B70
		dc.w  $1870,  $B70
		dc.w  $1890,  $B6D
		dc.w  $18A0,  $B63
		dc.w  $18AD,  $B53
		dc.w  $18B0,  $B33
		dc.w  $18B0,  $8B0
		dc.w  $18B2,  $893
		dc.w  $18BC,  $880
		dc.w  $18CE,  $872
		dc.w  $18F0,  $870
		dc.w  $1A70,  $870
		dc.w  $1A90,  $86D
		dc.w  $1AA2,  $862
		dc.w  $1AAE,  $84E
		dc.w  $1AB0,  $830
		dc.w  $1AB0,  $6B0
		dc.w  $1AB2,  $692
		dc.w  $1ABD,  $67E
		dc.w  $1AD2,  $671
		dc.w  $1AF0,  $670
		dc.w  $1B70,  $670
		dc.w  $1B90,  $66D
		dc.w  $1BA2,  $662
		dc.w  $1BAF,  $64E
		dc.w  $1BB0,  $630
		dc.w  $1BB0,  $4B0
		dc.w  $1BB0,  $495
		dc.w  $1BA2,  $47E
		dc.w  $1B8D,  $471
		dc.w  $1B70,  $470
		dc.w  $1AB8,  $470
AutoTunnel_17:
		dc.w  $2C
		dc.w  $22B8,   $70
		dc.w  $2370,   $70
		dc.w  $2390,   $73
		dc.w  $23A1,   $7E
		dc.w  $23AD,   $90
		dc.w  $23B0,   $B0
		dc.w  $23B0,  $1B0
		dc.w  $23B2,  $1D1
		dc.w  $23BF,  $1E4
		dc.w  $23D6,  $1F0
		dc.w  $2448,  $1F0
AutoTunnel_18:
		dc.w  $58
		dc.w  $2D48,  $7F0
		dc.w  $2CF0,  $7F0
		dc.w  $2CD0,  $7EE
		dc.w  $2CBD,  $7E3
		dc.w  $2CB2,  $7D0
		dc.w  $2CB0,  $7B0
		dc.w  $2CB0,  $430
		dc.w  $2CB1,  $411
		dc.w  $2CBB,  $3FF
		dc.w  $2CCF,  $3F2
		dc.w  $2CF0,  $3F0
		dc.w  $2D70,  $3F0
		dc.w  $2D90,  $3ED
		dc.w  $2DA2,  $3E2
		dc.w  $2DAF,  $3CE
		dc.w  $2DB0,  $3B0
		dc.w  $2DB0,  $330
		dc.w  $2DB2,  $311
		dc.w  $2DBC,  $2FE
		dc.w  $2DD1,  $2F1
		dc.w  $2DEF,  $2F0
		dc.w  $30F0,  $2F0
AutoTunnel_19:
		dc.w  $30
		dc.w  $3A38,  $3F0
		dc.w  $3AF0,  $3F0
		dc.w  $3B10,  $3EE
		dc.w  $3B23,  $3E0
		dc.w  $3B2F,  $3CA
		dc.w  $3B30,  $3B0
		dc.w  $3B30,  $230
		dc.w  $3B32,  $211
		dc.w  $3B3C,  $1FF
		dc.w  $3B50,  $1F2
		dc.w  $3B70,  $1F0
		dc.w  $3BC8,  $1F0
SpriteTerminator:
		ObjectLayoutBoundary

 if AdvancedHandler
; ===========================================================================
; ---------------------------------------------------------------------------
; Debugging modules
; ---------------------------------------------------------------------------

   include   "SampleDebugger.asm"
   include   "ErrorHandler.asm"

; ---------------------------------------------------------------------------
; WARNING!
;	DO NOT put any data from now on! DO NOT use ROM padding!
;	Symbol data should be appended here after ROM is compiled
;	by ConvSym utility, otherwise debugger modules won't be able
;	to resolve symbol names.
; ---------------------------------------------------------------------------
 else
	;	align	$3FFFFF			; Pad to 4MB
		even
 endif
EndOfRom:
	if MOMPASS=2
		; "About" because it will be off by the same amount that Size_of_Snd_driver_guess is incorrect (if you changed it), and because I may have missed a small amount of internal padding somewhere
		message "ROM size is $\{EndOfRom-StartOfRom} bytes (\{(EndOfRom-StartOfRom)/1024.0} KiB). About $\{paddingSoFar} bytes are padding. "
	endif
	END