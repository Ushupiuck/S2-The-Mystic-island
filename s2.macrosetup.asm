	padding off		; we don't want AS padding out dc.b instructions
	;listing off		; We don't need to generate anything for a listing file
	listing on		; Want full listing file
	;listing noskipped	; Want listing file, but only the non-skipped part of conditional assembly
	;listing purecode	; Want listing file, but only the final code in expanded macros
	page	0		; Don't want form feeds
	supmode on		; we don't need warnings about privileged instructions


paddingSoFar set 0

; 128 = 80h = z80, 32988 = 80DCh = z80unDoC
notZ80 function cpu,(cpu<>128)&&(cpu<>32988)

; make org safer (impossible to overwrite previously assembled bytes) and count padding
; and also make it work in Z80 code without creating a new segment
org macro address
	if notZ80(MOMCPU)
		if address < *
			error "too much stuff before org $\{address} ($\{(*-address)} bytes)"
		elseif address > *
paddingSoFar	set paddingSoFar + address - *
			!org address
		endif
	else
		if address < $
			error "too much stuff before org 0\{address}h (0\{($-address)}h bytes)"
		else
			while address > $
				db 0
			endm
		endif
	endif
    endm

; define an alternate org that fills the extra space with 0s instead of FFs
org0 macro address
.diff := address - *
	if .diff < 0
		error "too much stuff before org0 $\{address} ($\{(-diff)} bytes)"
	else
		while .diff > 1024
							; AS can only generate 1 kb of code on a single line
			dc.b [1024]0
.diff := .diff - 1024
		endm
		dc.b [.diff]0
	endif
    endm

; define the cnop pseudo-instruction
cnop macro offset,alignment
	if notZ80(MOMCPU)
		org (*-1+(alignment)-((*-1+(-(offset)))#(alignment)))
	else
		org ($-1+(alignment)-(($-1+(-(offset)))#(alignment)))
	endif
    endm

; define an alternate cnop that fills the extra space with 0s instead of FFs
cnop0 macro offset,alignment
	org0 (*-1+(alignment)-((*-1+(-(offset)))#(alignment)))
    endm

; redefine align in terms of cnop, because the built-in align can be stupid sometimes
align macro alignment
	cnop 0,alignment
    endm

; define an alternate align that fills the extra space with 0s instead of FFs
align0 macro alignment
	cnop0 0,alignment
    endm

; define the even pseudo-instruction
even macro
	if notZ80(MOMCPU)
		if (*)&1
paddingSoFar		set paddingSoFar+1
			dc.b 0 ;ds.b 1 
		endif
	else
		if ($)&1
			db 0
		endif
	endif
    endm

; make ds work in Z80 code without creating a new segment
ds macro
	if notZ80(MOMCPU)
		!ds.ATTRIBUTE ALLARGS
	else
		rept ALLARGS
			db 0
		endm
	endif
   endm

; define a trace macro
; lets you easily check what address a location in this disassembly assembles to
trace macro optionalMessageWithoutQuotes
	if MOMPASS=1
		if ("ALLARGS"<>"")
			message "#\{tracenum/1.0}: line=\{MOMLINE/1.0} PC=$\{(*)&$FFFFFFFF} msg=ALLARGS"
		else
			message "#\{tracenum/1.0}: line=\{MOMLINE/1.0} PC=$\{(*)&$FFFFFFFF}"
		endif
tracenum := (tracenum+1)
	endif
   endm
tracenum := 0

bit function nBits,1<<(nBits-1)
setBit function nBits,1<<(nBits)
signmask function val,nBits,-((-(val&bit(nBits)))&bit(nBits))
signextend function val,nBits,(val+signmask(val,nBits))!signmask(val,nBits)
signextendB function val,signextend(val,8)
roundFloatToInteger function float,INT(float+0.5)
min function a,b,b!((a!b)&(-(a<b)))
max function a,b,a!((a!b)&(-(a<b)))
chkop function op,ref,(substr(lowstring(op),0,strlen(ref))<>ref)

_move	macro
		!move.ATTRIBUTE ALLARGS
	endm
_add	macro
		!add.ATTRIBUTE ALLARGS
	endm
_addq	macro
		!addq.ATTRIBUTE ALLARGS
	endm
_cmp	macro
		!cmp.ATTRIBUTE ALLARGS
	endm
_cmpi	macro
		!cmpi.ATTRIBUTE ALLARGS
	endm
_clr	macro
		!clr.ATTRIBUTE ALLARGS
	endm
_tst	macro
		!tst.ATTRIBUTE ALLARGS
	endm
addi_	macro
		!addq.ATTRIBUTE ALLARGS
	endm
subi_	macro
		!subq.ATTRIBUTE ALLARGS
	endm
adda_	macro
		!addq.ATTRIBUTE ALLARGS
	endm
