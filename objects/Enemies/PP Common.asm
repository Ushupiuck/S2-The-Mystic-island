; A range trigger may use either live actor. Empty slots, death routines and
; scripted transport/respawn locks are not attack targets. Return C = valid.
PP_ValidTarget:
        tst.l code(a1)
        beq.s .inactive
        cmpi.b #6,obRoutine(a1)
        bhs.s .inactive
        btst #7,obControl(a1)
        bne.s .inactive
        ori #1,ccr
        rts
.inactive:
        andi #$FE,ccr
        rts
