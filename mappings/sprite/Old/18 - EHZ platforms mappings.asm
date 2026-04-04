; --------------------------------------------------------------------------------
; Sprite mappings - output from SonMapEd - Sonic 2 format
; --------------------------------------------------------------------------------

SME_8uUbs:	
		dc.w SME_8uUbs_4-SME_8uUbs, SME_8uUbs_16-SME_8uUbs	
SME_8uUbs_4:	dc.b 0, 2	
		dc.b $F4, $F, 2, $CD, 2, $66, $FF, $E0	
		dc.b $F4, $F, $A, $CD, $A, $66, 0, 0	
SME_8uUbs_16:	dc.b 0, 6	
		dc.b $F4, $F, 2, $DD, 2, $6E, $FF, $E0	
		dc.b $F4, $F, $A, $DD, $A, $6E, 0, 0	
		dc.b $14, $F, 2, $ED, 2, $76, $FF, $E0	
		dc.b $14, $F, $A, $ED, $A, $76, 0, 0	
		dc.b $34, $F, 2, $FD, 2, $7E, $FF, $E0	
		dc.b $34, $F, $A, $FD, $A, $7E, 0, 0	
		even