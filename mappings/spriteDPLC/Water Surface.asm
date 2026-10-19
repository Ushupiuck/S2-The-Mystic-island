; One eight-tile wave during play; both interleaved phases while paused.
		dc.w .empty-DPLC_Water_Surface
		dc.w .phase0-DPLC_Water_Surface
		dc.w .phase1-DPLC_Water_Surface
		dc.w .phase2-DPLC_Water_Surface
		dc.w .pause0-DPLC_Water_Surface
		dc.w .pause1-DPLC_Water_Surface
		dc.w .pause2-DPLC_Water_Surface
.empty:	dc.w 0
.phase0:	dc.w 1,$7000
.phase1:	dc.w 1,$7008
.phase2:	dc.w 1,$7010
.pause0:	dc.w 2,$7000,$7008
.pause1:	dc.w 1,$F008
.pause2:	dc.w 2,$7010,$7008
