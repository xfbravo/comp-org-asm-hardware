wait_rx:
    lui   t0, 0x40000
    lw    t1, 8(t0)
    andi  t1, t1, 2
    beq   t1, zero, wait_rx
    lw    t2, 4(t0)
    sw    t2, 0(t0)
    sw    t2, 16(t0)
    beq   zero, zero, wait_rx
