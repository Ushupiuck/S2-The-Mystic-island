; Read-only KeH PSG envelopes in the shared SFX ROM bank.
; zVInt selects this bank before either music or SFX track updates.
PSG_EnvelopeIndex:
	; Each nonzero tone selects an attenuation curve.
	; $0 is loudest, $F is silent, and $80 holds the previous step.

	rom_ptr_z80 PSG_Envelope01
	rom_ptr_z80 PSG_Envelope02
	rom_ptr_z80 PSG_Envelope03
	rom_ptr_z80 PSG_Envelope04
	rom_ptr_z80 PSG_Envelope05
	rom_ptr_z80 PSG_Envelope06
	rom_ptr_z80 PSG_Envelope07
	rom_ptr_z80 PSG_Envelope08
	rom_ptr_z80 PSG_Envelope09
	rom_ptr_z80 PSG_Envelope10
	rom_ptr_z80 PSG_Envelope11
	rom_ptr_z80 PSG_Envelope12
	rom_ptr_z80 PSG_Envelope13
	rom_ptr_z80 PSG_EnvelopeShadowDancer
	rom_ptr_z80 PSG_EnvelopeShadowDancer03
	rom_ptr_z80 PSG_EnvelopeShadowDancer06
	rom_ptr_z80 PSG_EnvelopeShadowDancer08
PSG_Envelope01:
	dc.b	0,0,0,1,1,1,2,2,2,3,3,3,4,4,4,5
	dc.b	5,5,6,6,6,7,$80
PSG_Envelope02:
	dc.b	0,2,4,6,8,$10,$80
PSG_Envelope03:
	dc.b	0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,$80
PSG_Envelope04:
	dc.b	0,0,2,3,4,4,5,5,5,6,$80
PSG_Envelope06:
	dc.b	3,3,3,2,2,2,2,1,1,1,0,$80
PSG_Envelope05:
	dc.b	0,0,0,0,0,0,0,0,0,0,1,1
	dc.b	1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2
	dc.b	2,2,2,2,3,3,3,3,3,3,3,3,4,$80
PSG_Envelope07:
	dc.b	0,0,0,0,0,0,1,1,1,1,1,2,2,2,2,2
	dc.b	3,3,3,4,4,4,5,5,5,6,7,$80
PSG_Envelope08:
	dc.b	0,0,0,0,0,1,1,1,1,1,2,2,2,2,2,2
	dc.b	3,3,3,3,3,4,4,4,4,4,5,5,5,5,5,6
	dc.b	6,6,6,6,7,$80
PSG_Envelope09:
	dc.b	0,1,2,3,4,5,6,7,8,9,$0A,$0B,$0C,$0D,$0E,$0F,$80
PSG_Envelope10:
	dc.b	0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1
	dc.b	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
	dc.b	1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2
	dc.b	2,2,3,3,3,3,3,3,3,3,3,3,4,$80
PSG_Envelope11:
	dc.b	4,4,4,3,3,3,2,2,2,1,1,1,1,1,1,1
	dc.b	2,2,2,2,2,3,3,3,3,3,4,$80
PSG_Envelope12:
	dc.b	4,4,3,3,2,2,1,1,1,1,1,1,1,1,1,1
	dc.b	1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2
	dc.b	2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,3
	dc.b	3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
	dc.b	3,3,4,4,4,4,4,4,4,4,4,4,4,4,4,4
	dc.b	4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5
	dc.b	5,5,5,5,5,5,5,5,5,5,6,6,6,6,6,6
	dc.b	6,6,6,6,6,6,6,6,6,6,6,6,6,6,7,$80
PSG_Envelope13:
	dc.b	$0E,$0D,$0C,$0B,$0A,9,8,7,6,5,4,3,2,1,0,$80

PSG_EnvelopeShadowDancer:
	; Shadow Dancer envelope 7 (byte_62AE0). KeH uses $80 to hold.
	dc.b	0,0,7,1,1,7,2,2,4,4,6,7,8,$80

PSG_EnvelopeShadowDancer03:
	; byte_62A8E
	dc.b	0,0,1,1,3,3,4,5,$80
PSG_EnvelopeShadowDancer06:
	; byte_62AA2
	dc.b	8,8,8,7,6,5,4,3,2,0,0,0,0,0,0,0,0,0,0,$80
PSG_EnvelopeShadowDancer08:
	; byte_62AEE
	dc.b	0,0,8,8,$80

;	END of PSG_EnvelopeIndex ---------------------------
