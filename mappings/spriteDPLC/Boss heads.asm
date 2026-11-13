; Shared Eggman/EggRobo head DPLCs: count, then packed tile runs.
; Frames 0-6 read Eggman face; 7-10 read Egg Robo head.
DPLC_BossHeads:
	dc.w .frame0-DPLC_BossHeads
	dc.w .frame1-DPLC_BossHeads
	dc.w .frame2-DPLC_BossHeads
	dc.w .frame3-DPLC_BossHeads
	dc.w .frame4-DPLC_BossHeads
	dc.w .frame5-DPLC_BossHeads
	dc.w .frame6-DPLC_BossHeads
	dc.w .frame7-DPLC_BossHeads
	dc.w .frame8-DPLC_BossHeads
	dc.w .frame9-DPLC_BossHeads
	dc.w .frame10-DPLC_BossHeads
.frame0:	dc.w 1
	dc.w $4000
.frame1:	dc.w 1
	dc.w $4005
.frame2:	dc.w 1
	dc.w $500A
.frame3:	dc.w 4
	dc.w $000A
	dc.w $0010
	dc.w $000C
	dc.w $2011
.frame4:	dc.w 1
	dc.w $7014
.frame5:	dc.w 2
	dc.w $0000
	dc.w $501C
.frame6:	dc.w 1
	dc.w $7022
.frame7:	dc.w 1
	dc.w $7000
.frame8:	dc.w 1
	dc.w $7008
.frame9:	dc.w 1
	dc.w $7010
.frame10:	dc.w 1
	dc.w $7018
	even
