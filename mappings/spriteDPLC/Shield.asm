; Current classic-shield pixels, streamed one frame at a time.
; Frames 0-4 use four tiles; the large flash uses twelve. Mappings address
; the start of the shared bank after each upload, retaining their flips.
		dc.w .empty-DPLC_Shield	; cache zero means no art is loaded
		dc.w .frame0-DPLC_Shield
		dc.w .frame1-DPLC_Shield
		dc.w .frame2-DPLC_Shield
		dc.w .frame3-DPLC_Shield
		dc.w .frame4-DPLC_Shield
		dc.w .frame5-DPLC_Shield
.empty:
		dc.w 0
.frame0:
		dc.w 1,$3000
.frame1:
		dc.w 1,$3004
.frame2:
		dc.w 1,$3008
.frame3:
		dc.w 1,$300C
.frame4:
		dc.w 1,$3010
.frame5:
		dc.w 1,$B014
		even
