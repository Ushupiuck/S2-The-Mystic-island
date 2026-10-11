; ---------------------------------------------------------------------------
; S1 special-stage background, using the normal block and chunk tables.
; Two live 64x32 planes replace the seven FG frames and duplicate BG maps.
; Birds/fish share a 64-tile bank driven by Dynamic_Normal. Only their checker
; arrangement and the opaque transition need different FG layouts. That opaque
; frame hides BG replacements and preloads the next family's animation art.
; ---------------------------------------------------------------------------

S1_SSBGLoad:
		lea	SSBG_Blocks(pc),a0
		lea	(v_16x16).w,a1
		bsr.w	KosPlusDec
		lea	SSBG_Chunks(pc),a0
		lea	(Chunk_Table).l,a1
		bsr.w	KosPlusDec
		clr.w	(v_ssbg_fg_frame).l
		clr.w	(v_ssbg_fg_uploaded).l
		move.w	#1,(v_ssbg_bg_uploaded).l
		move.w	#1,(v_ssbg_bg_wanted).l
		move.w	#16,(v_ssbg_fg_build_row).l
		move.w	#16,(v_ssbg_bg_build_row).l
		clr.w	(v_ssbg_art_uploaded).l
		clr.w	(v_ssbg_anim_counter).l
		lea	SSBG_Layouts(pc),a0
		lea	(v_ssbg_fg_buffer).l,a1
		bsr.w	S1SS_BgDrawPlane
		copyTilemap	v_ssbg_fg_buffer,vram_fg,64,32
		lea	SSBG_Layouts+4*8(pc),a0
		lea	(v_ssbg_bg_buffer).l,a1
		bsr.w	S1SS_BgDrawPlane
		copyTilemap	v_ssbg_bg_buffer,vram_bg,64,32
		moveq	#8,d0		; first fish frame, loaded beneath the opaque FG
		bra.w	S1SS_AnimateTiles

; a0 = four-by-two chunk layout, a1 = 64x32 tile-word buffer.
; Generated chunks contain block IDs without chunk-level flips/collision bits;
; all original tile palette, priority and flip flags are in v_16x16.
S1SS_BgDrawPlane:
		moveq	#0,d6
		moveq	#16,d4
; d6 = first block row, d4 = number of block rows, a1 = plane buffer base.
S1SS_BgDrawRows:
		move.w	d6,d0
		lsl.w	#8,d0
		adda.w	d0,a1
		lea	(v_16x16).w,a4
		lea	(Chunk_Table).l,a5
.row:
		move.w	d6,d0
		lsr.w	#3,d0
		lsl.w	#2,d0
		lea	(a0,d0.w),a2
		move.w	d6,d0
		andi.w	#7,d0
		lsl.w	#4,d0
		moveq	#4-1,d7
.chunk:
		moveq	#0,d1
		move.b	(a2)+,d1
		lsl.w	#7,d1
		add.w	d0,d1
		lea	(a5,d1.w),a3
		moveq	#8-1,d5
.block:
		move.w	(a3)+,d1
		lsl.w	#3,d1
		move.l	(a4,d1.w),(a1)+
		move.l	4(a4,d1.w),$7C(a1)
		dbf	d5,.block
		dbf	d7,.chunk
		lea	$80(a1),a1
		addq.w	#1,d6
		subq.w	#1,d4
		bne.s	.row
		rts

; Called after the regular scroll animation, outside VBlank. Only the opaque
; transition frame may replace plane B. The clouds repeat after 256 pixels,
; so a 64x32 plane also preserves the old 64x64 vertical scrolling exactly.
S1SS_BgPrepare:
		move.w	(v_ssbg_bg_wanted).l,d0
		cmp.w	(v_ssbg_bg_uploaded).l,d0
		beq.s	.preloadart
		tst.w	(v_bsbganim).w
		bne.s	.foreground
		lsl.w	#3,d0
		lea	SSBG_Layouts+3*8(pc),a0
		adda.w	d0,a0
		lea	(v_ssbg_bg_buffer).l,a1
		move.w	(v_ssbg_bg_build_row).l,d6
		moveq	#4,d4		; keep map construction inside the frame budget
		bsr.w	S1SS_BgDrawRows
		move.w	d6,(v_ssbg_bg_build_row).l
		cmpi.w	#16,d6
		blo.s	.foreground
		move.w	(v_ssbg_bg_wanted).l,(v_ssbg_bg_uploaded).l
		move.l	#v_ssbg_bg_buffer,d1
		move.w	#vram_bg,d2
		move.w	#plane_size_64x32/2,d3
		bsr.w	QueueDMATransfer
		bra.s	.foreground	; never combine a whole-plane DMA with an art upload
.preloadart:
		tst.w	(v_bsbganim).w
		bne.s	.foreground
		moveq	#2,d0		; first bird frame
		tst.w	(v_ssbg_bg_wanted).l
		beq.s	.animate
		moveq	#8,d0		; first fish frame
.animate:
		bsr.w	S1SS_AnimateTiles
.foreground:
		move.w	(v_palbs_num).w,d0
		andi.w	#$1F,d0
		lsl.w	#2,d0
		lea	S1SS_BgCycle(pc),a0
		moveq	#0,d1		; opaque arrangement
		tst.b	1(a0,d0.w)
		beq.s	.gotlayout
		moveq	#1,d1		; birds
		cmpi.b	#8,1(a0,d0.w)
		blo.s	.gotlayout
		moveq	#2,d1		; fish
.gotlayout:
		cmp.w	(v_ssbg_fg_frame).l,d1
		beq.s	.buildforeground
		move.w	d1,(v_ssbg_fg_frame).l
		clr.w	(v_ssbg_fg_build_row).l
.buildforeground:
		move.w	(v_ssbg_fg_build_row).l,d6
		cmpi.w	#16,d6
		bhs.s	.return
		lsl.w	#3,d1		; arrangement 0,1,2 -> eight-byte layout
		lea	SSBG_Layouts(pc),a0
		adda.w	d1,a0
		lea	(v_ssbg_fg_buffer).l,a1
		moveq	#4,d4
		bsr.w	S1SS_BgDrawRows
		move.w	d6,(v_ssbg_fg_build_row).l
.return:
		rts

; Called before ProcessDMAQueue in Vint_S1SS. Keeping this selection in VBlank
; makes pause and the frozen exit fade retain the currently displayed frame.
S1SS_BgVBlank:
		tst.w	(f_pause).w
		bne.s	.return
		tst.w	(v_palbs_time).w
		bne.s	.return
		move.w	(v_palbs_num).w,d0
		andi.w	#$1F,d0
		lsl.w	#2,d0
		lea	S1SS_BgCycle(pc),a0
		move.b	1(a0,d0.w),d0
		andi.w	#$FF,d0
		moveq	#0,d1
		tst.w	d0
		beq.s	.gotlayout
		moveq	#1,d1
		cmpi.w	#8,d0
		blo.s	.gotlayout
		moveq	#2,d1
.gotlayout:
		cmp.w	(v_ssbg_fg_uploaded).l,d1
		beq.s	.animatedframe
		cmpi.w	#16,(v_ssbg_fg_build_row).l
		bne.s	.return
		move.w	d1,(v_ssbg_fg_uploaded).l
		move.l	#v_ssbg_fg_buffer,d1
		move.w	#vram_fg,d2
		move.w	#plane_size_64x32/2,d3
		bra.w	QueueDMATransfer
.animatedframe:
		tst.w	d0
		bne.s	S1SS_AnimateTiles
.return:
		rts

; d0 = original animation ID (2,4,6 birds / 8,10,12 fish). The special stage
; keeps its original palette clock; the existing animated-tile engine performs
; the art transfer using a private counter, without disturbing level scripts.
S1SS_AnimateTiles:
		cmp.w	(v_ssbg_art_uploaded).l,d0
		beq.s	.return
		move.w	d0,(v_ssbg_art_uploaded).l
		lea	AnimCue_S1SSBirds(pc),a2
		cmpi.w	#8,d0
		blo.s	.birds
		subq.w	#6,d0
		lea	AnimCue_S1SSFish(pc),a2
.birds:
		lsr.w	#1,d0
		subq.w	#1,d0
		lea	(v_ssbg_anim_counter).l,a3
		clr.b	(a3)
		move.b	d0,1(a3)
		jmp	(Dynamic_Normal_AtCounter).l
.return:
		rts

AnimCue_S1SSBirds:	zoneanimstart
		zoneanimdecl 0, Art_S1SSBGBirds, ArtTile_SS_Background_Animated, 3, 64
		dc.b 0, $40, $80
		even
		zoneanimend
AnimCue_S1SSFish:	zoneanimstart
		zoneanimdecl 0, Art_S1SSBGFish, ArtTile_SS_Background_Animated, 3, 64
		dc.b 0, $40, $80
		even
		zoneanimend

; Rebuild these files with build_tools/convert_s1_ss_background.py.
SSBG_Blocks:	binclude "mappings/16x16/S1 Special Stage BG.kosp"
		even
SSBG_Chunks:	binclude "mappings/128x128/S1 Special Stage BG.kosp"
		even
SSBG_Layouts:	binclude "level/layout/S1 Special Stage BG.bin"
		even
