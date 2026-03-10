; ---------------------------------------------------------------------------
; makes a VDP address difference
vdpCommDelta function addr,((addr&$3FFF)<<16)|((addr&$C000)>>14)

; makes a VDP command
vdpComm function addr,type,rwd,(((type&rwd)&3)<<30)|((addr&$3FFF)<<16)|(((type&rwd)&$FC)<<2)|((addr&$C000)>>14)

; calc VDP address
vdpCalc function loc,($40000000|vdpCommDelta(loc))

; sign-extends a 32-bit integer to 64-bit
; all RAM addresses are run through this function to allow them to work in both 16-bit and 32-bit addressing modes
ramaddr function x,-(-x)&$FFFFFFFF

; function using these variables
id function ptr,((ptr-offset)/ptrsize+idstart)

; function to convert two separate nibble into a byte
nibbles_to_byte function nibble1,nibble2,(((nibble1)<<4)&$F0)|((nibble2)&$FF)

; function to convert two separate bytes into a word
bytes_to_word function byte1,byte2,(((byte1)<<8)&$FF00)|((byte2)&$FF)

; function to convert two separate word into a long
words_to_long function word1,word2,(((word1)<<16)&$FFFF0000)|((word2)&$FFFF)

; function to convert two separate bytes and word into a word
bytes_word_to_long function byte1,byte2,word,((((byte1)<<24)&$FF000000)|(((byte2)<<16)&$FF0000)|((word)&$FFFF))

; function to convert four separate bytes into a long
bytes_to_long function byte1,byte2,byte3,byte4,(((byte1)<<24)&$FF000000)|(((byte2)<<16)&$FF0000)|(((byte3)<<8)&$FF00)|((byte4)&$FF)

; calculates initial loop counter value for a dbf loop
; that writes n bytes total at x bytes per iteration
bytesToXcnt function n,x,n/x-1

; calculates initial loop counter value for a dbf loop
; that writes n bytes total at 4 bytes per iteration
bytesToLcnt function n,bytesToXcnt(n,4)

; calculates initial loop counter value for a dbf loop
; that writes n bytes total at 2 bytes per iteration
bytesToWcnt function n,bytesToXcnt(n,2)

; calculates initial loop counter value for a normal loop
; that writes n bytes total at x bytes per iteration
bytesTo2Xcnt function n,x,n/x

; calculates initial loop counter value for a normal loop
; that writes n bytes total at 4 bytes per iteration
bytesTo2Lcnt function n,bytesTo2Xcnt(n,4)

; calculates initial loop counter value for a normal loop
; that writes n bytes total at 2 bytes per iteration
bytesTo2Wcnt function n,bytesTo2Xcnt(n,2)
; ---------------------------------------------------------------------------

; values for the type argument
VRAM = %100001
CRAM = %101011
VSRAM = %100101

; values for the rwd argument
READ = %001100
WRITE = %000111
DMA = %100111
; ---------------------------------------------------------------------------
; macros to convert from tile index to art tiles, block mapping or VRAM address.
make_art_tile function addr,pal,pri,((pri&1)<<15)|((pal&3)<<13)|(addr&tile_mask)
make_block_tile function addr,flx,fly,pal,pri,((pri&1)<<15)|((pal&3)<<13)|((fly&1)<<12)|((flx&1)<<11)|(addr&tile_mask)
tiles_to_bytes function addr,((addr&$7FF)<<5)
make_block_tile_pair function addr,flx,fly,pal,pri,((make_block_tile(addr,flx,fly,pal,pri)<<16)|make_block_tile(addr,flx,fly,pal,pri))
; ---------------------------------------------------------------------------
; macros for defining animated PLC script lists
zoneanimstart macro {INTLABEL}
__LABEL__ label *
zoneanimcount := 0
zoneanimcur := "__LABEL__"
	dc.w zoneanimcount___LABEL__	; Number of scripts for a zone (-1)
    endm

zoneanimend macro
zoneanimcount_{"\{zoneanimcur}"} = zoneanimcount-1
    endm

zoneanimdeclanonid := 0

zoneanimdecl macro duration,artaddr,vramaddr,numentries,numvramtiles
zoneanimdeclanonid := zoneanimdeclanonid + 1
start:
	dc.l (duration&$FF)<<24|artaddr
	dc.w tiles_to_bytes(vramaddr)
	dc.b numentries, numvramtiles
zoneanimcount := zoneanimcount + 1
    endm
; macro to declare an offset table
offsetTable macro {INTLABEL}
current_offset_table := __LABEL__
__LABEL__ label *
    endm

; macro to declare an entry in an offset table
offsetTableEntry macro ptr
	dc.ATTRIBUTE ptr-current_offset_table
    endm
; ---------------------------------------------------------------------------
; function to calculate the location of a tile in plane mappings
planeLoc function width,col,line,(((width * line) + col) * 2)

; function to calculate the location of a tile in plane mappings with a width of 40 cells
planeLocH32 function col,line,(($40 * line) + (2 * col))

; function to calculate the location of a tile in plane mappings with a width of 40 cells
planeLocH28 function col,line,(($50 * line) + (2 * col))

; function to calculate the location of a tile in plane mappings with a width of 64 cells
planeLocH40 function col,line,(($80 * line) + (2 * col))

; function to calculate the location of a tile in plane mappings with a width of 128 cells
planeLocH80 function col,line,(($100 * line) + (2 * col))
; ---------------------------------------------------------------------------
; some variables and functions to help define those constants (redefined before a new set of IDs)
offset :=	0					; this is the start of the pointer table
ptrsize :=	1					; this is the size of a pointer (should be 1 if the ID is a multiple of the actual size)
idstart :=	0					; value to add to all IDs

; ---------------------------------------------------------------------------
; Set a VRAM address via the VDP control port.
; input: 16-bit VRAM address, control port (default is (vdp_control_port).l)
; ---------------------------------------------------------------------------

locVRAM:	macro loc,controlport
		if ("controlport"=="")
		move.l	#($40000000+(((loc)&$3FFF)<<16)+(((loc)&$C000)>>14)),(vdp_control_port).l
		else
		move.l	#($40000000+(((loc)&$3FFF)<<16)+(((loc)&$C000)>>14)),controlport
		endif
		endm

; ---------------------------------------------------------------------------
; DMA copy data from 68K (ROM/RAM) to the VRAM
; input: source, length, destination
; ---------------------------------------------------------------------------

writeVRAM:	macro source,destination
		lea	(vdp_control_port).l,a5
		move.l	#$94000000+((((source_end-source)>>1)&$FF00)<<8)+$9300+(((source_end-source)>>1)&$FF),(a5)
		move.l	#$96000000+(((source>>1)&$FF00)<<8)+$9500+((source>>1)&$FF),(a5)
		move.w	#$9700+((((source>>1)&$FF0000)>>16)&$7F),(a5)
		move.w	#$4000+((destination)&$3FFF),(a5)
		move.w	#$80+(((destination)&$C000)>>14),(v_dma_thunk).w
		move.w	(v_dma_thunk).w,(a5)
		endm

; ---------------------------------------------------------------------------
; DMA copy data from 68K (ROM/RAM) to the CRAM
; input: source, length, destination
; ---------------------------------------------------------------------------

writeCRAM:	macro source,destination
		lea	(vdp_control_port).l,a5
		move.l	#$94000000+((((source_end-source)>>1)&$FF00)<<8)+$9300+(((source_end-source)>>1)&$FF),(a5)
		move.l	#$96000000+(((source>>1)&$FF00)<<8)+$9500+((source>>1)&$FF),(a5)
		move.w	#$9700+((((source>>1)&$FF0000)>>16)&$7F),(a5)
		move.w	#$C000+(destination&$3FFF),(a5)
		move.w	#$80+((destination&$C000)>>14),(v_dma_thunk).w
		move.w	(v_dma_thunk).w,(a5)
		endm

; ---------------------------------------------------------------------------
; DMA fill VRAM with a value
; input: value, length, destination
; ---------------------------------------------------------------------------

fillVRAM:	macro byte,start,end
		lea	(vdp_control_port).l,a5
		move.w	#$8F01,(a5) ; Set increment to 1, since DMA fill writes bytes
		move.l	#$94000000+((((end)-(start)-1)&$FF00)<<8)+$9300+(((end)-(start)-1)&$FF),(a5)
		move.w	#$9780,(a5)
		move.l	#$40000080+(((start)&$3FFF)<<16)+(((start)&$C000)>>14),(a5)
		move.w	#(byte)|(byte)<<8,(vdp_data_port).l
.wait:		move.w	(a5),d1
		btst	#1,d1
		bne.s	.wait
		move.w	#$8F02,(a5) ; Set increment back to 2, since the VDP usually operates on words
		endm

; ---------------------------------------------------------------------------
; Fill portion of RAM with 0
; input: start, end
; ---------------------------------------------------------------------------

clearRAM macro startaddr,endaddr
	if startaddr>endaddr
		fatal "Starting address of clearRAM \{startaddr} is after ending address \{endaddr}."
	elseif startaddr==endaddr
		warning "clearRAM is clearing zero bytes. Turning this into a nop instead."
		exitm
	endif
	if ((startaddr)&$8000)==0
		lea	(startaddr).l,a1
	else
		lea	(startaddr).w,a1
	endif
		moveq	#0,d0
	if ((startaddr)&1)
		move.b	d0,(a1)+
	endif
		move.w	#bytesToLcnt((endaddr-startaddr) - ((startaddr)&1)),d1
.loop:		move.l	d0,(a1)+
		dbf	d1,.loop
	if (((endaddr-startaddr) - ((startaddr)&1))&2)
		move.w	d0,(a1)+
	endif
	if (((endaddr-startaddr) - ((startaddr)&1))&1)
		move.b	d0,(a1)+
	endif
		endm

; ---------------------------------------------------------------------------
; tells the Z80 to stop
; ---------------------------------------------------------------------------

stopZ80:	macro
		move.w	#$100,(Z80_Bus_Request).l ; stop the Z80
		endm
; ---------------------------------------------------------------------------
; wait for Z80 to stop
; ---------------------------------------------------------------------------

waitZ80:	macro
.wait:		btst	#0,(Z80_Bus_Request).l
		bne.s	.wait ; loop until it says it's stopped
		endm

; ---------------------------------------------------------------------------
; reset the Z80
; ---------------------------------------------------------------------------
resetZ80:	macro
		move.w	#$100,(Z80_Reset).l
		endm

resetZ80a:	macro
		move.w	#0,(Z80_Reset).l
		endm
; ---------------------------------------------------------------------------
; start the Z80
; ---------------------------------------------------------------------------
startZ80:	macro
		move.w	#0,(Z80_Bus_Request).l    ; start the Z80
		endm

; ---------------------------------------------------------------------------
; function to make a little-endian 16-bit pointer for the Z80 sound driver
	ifndef kehmusic
z80_ptr function x,(x)<<8&$FF00|(x)>>8&$7F|$80
	else
z80_ptr function x,(x)<<8&$FF00|(x)>>8&$FF
	endif

; macro to declare a little-endian 16-bit pointer for the Z80 sound driver
rom_ptr_z80 macro addr
	dc.w z80_ptr(addr)
    endm

; aligns the start of a bank, and detects when the bank's contents is too large
; can also print the amount of free space in a bank with DebugSoundbanks set
startBank macro {INTLABEL}
	align	$8000
__LABEL__ label *
soundBankStart := __LABEL__
soundBankName := "__LABEL__"
    endm

DebugSoundbanks := 0

finishBank macro
	if * > soundBankStart + $8000
		fatal "soundBank \{soundBankName} must fit in $8000 bytes but was $\{*-soundBankStart}. Try moving something to the other bank."
	elseif (DebugSoundbanks<>0)&&(MOMPASS=1)
		message "soundBank \{soundBankName} has $\{$8000+soundBankStart-*} bytes free at end."
	endif
    endm

; ---------------------------------------------------------------------------
; disable interrupts
; ---------------------------------------------------------------------------

disable_ints:	macro
		move	#$2700,sr
		endm

; ---------------------------------------------------------------------------
; enable interrupts
; ---------------------------------------------------------------------------

enable_ints:	macro
		move	#$2300,sr
		endm

; ---------------------------------------------------------------------------
; disable interrupts
; ---------------------------------------------------------------------------

disableIntsSave macro
	move.w	sr,-(sp)							; save current interrupt mask
	disable_ints								; mask off interrupts
    endm

; ---------------------------------------------------------------------------
; enable interrupts
; ---------------------------------------------------------------------------

enableIntsSave macro
	move.w	(sp)+,sr							; restore interrupts to previous state
    endm

; ---------------------------------------------------------------------------
; long conditional jumps
; ---------------------------------------------------------------------------

jhi:		macro loc
		bls.s	.nojump
		jmp	loc
.nojump:
		endm

jcc:		macro loc
		bcs.s	.nojump
		jmp	loc
.nojump:
		endm

jhs:		macro loc
		jcc	loc
		endm

jls:		macro loc
		bhi.s	.nojump
		jmp	loc
.nojump:
		endm

jcs:		macro loc
		bcc.s	.nojump
		jmp	loc
.nojump:
		endm

jlo:		macro loc
		jcs	loc
		endm

jeq:		macro loc
		bne.s	.nojump
		jmp	loc
.nojump:
		endm

jne:		macro loc
		beq.s	.nojump
		jmp	loc
.nojump:
		endm

jgt:		macro loc
		ble.s	.nojump
		jmp	loc
.nojump:
		endm

jge:		macro loc
		blt.s	.nojump
		jmp	loc
.nojump:
		endm

jle:		macro loc
		bgt.s	.nojump
		jmp	loc
.nojump:
		endm

jlt:		macro loc
		bge.s	.nojump
		jmp	loc
.nojump:
		endm

jpl:		macro loc
		bmi.s	.nojump
		jmp	loc
.nojump:
		endm

jmi:		macro loc
		bpl.s	.nojump
		jmp	loc
.nojump:
		endm

; ---------------------------------------------------------------------------
; check if the object moves out of range
; input: location to branch to if out of range, x-axis pos (obX(a0) by default)
; ---------------------------------------------------------------------------

out_of_range:	macro exit,specpos
		if ("specpos"<>"")
		move.w	specpos,d0		; get object position (if specified as not obX)
		else
		move.w	obX(a0),d0	; get object position
		endif
		andi.w	#-$80,d0	; round down to nearest $80
		sub.w	(Camera_X_pos_coarse).w,d0		; approx distance between object and screen
		cmpi.w	#128+320+192,d0
		bhi.ATTRIBUTE	exit
		endm

; ---------------------------------------------------------------------------
; Identical to the above, except it uses jhi. Since out_of_range only covers
; short & long branches. jhi compensates for this, at the cost of a few extra cycles
; ---------------------------------------------------------------------------

out_of_range2:	macro exit,specpos
		if ("specpos"<>"")
		move.w	specpos,d0		; get object position (if specified as not obX)
		else
		move.w	obX(a0),d0	; get object position
		endif
		andi.w	#-$80,d0	; round down to nearest $80
		sub.w	(Camera_X_pos_coarse).w,d0		; approx distance between object and screen
		cmpi.w	#128+320+192,d0
		jhi	(exit).l
		endm

; ---------------------------------------------------------------------------
; check if object moves out of range
; input: location to jump to if out of range, x-axis pos pre-fed)
; ---------------------------------------------------------------------------

out_of_range3:	macro exit
		andi.w	#-$80,d0	; round down to nearest $80
		sub.w	(Camera_X_pos_coarse).w,d0		; approx distance between object and screen
		cmpi.w	#128+320+192,d0
		bhi.ATTRIBUTE	exit
		endm

; ---------------------------------------------------------------------------
; Copy a tilemap from 68K (ROM/RAM) to the VRAM without using DMA
; input: source, destination, width [cells], height [cells]
; ---------------------------------------------------------------------------

copyTilemap:	macro source,destination,width,height
		lea	(source).l,a1
		locVRAM	destination,d0
		moveq	#width-1,d1
		moveq	#height-1,d2
		bsr.w	PlaneMapToVRAM_H40
		endm
		
; tells the VDP to copy a region of 68k memory to VRAM or CRAM or VSRAM
dma68kToVDP macro source,dest,length,type
	lea	(VDP_control_port).l,a5
	move.l	#(($9400|((((length)>>1)&$FF00)>>8))<<16)|($9300|(((length)>>1)&$FF)),(a5)
	move.l	#(($9600|((((source)>>1)&$FF00)>>8))<<16)|($9500|(((source)>>1)&$FF)),(a5)
	move.w	#$9700|(((((source)>>1)&$FF0000)>>16)&$7F),(a5)
	move.w	#((vdpComm(dest,type,DMA)>>16)&$FFFF),(a5)
	move.w	#(vdpComm(dest,type,DMA)&$FFFF),(v_dma_thunk).w
	move.w	(v_dma_thunk).w,(a5)
    endm		