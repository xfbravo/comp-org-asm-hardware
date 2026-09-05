    lui   t0, 0x40000
    addi  t1, zero, 72
    jal   ra, putc
    addi  t1, zero, 105
    jal   ra, putc
    addi  t1, zero, 46
    jal   ra, putc
    addi  t1, zero, 13
    jal   ra, putc
    addi  t1, zero, 10
    jal   ra, putc
    lui   t2, 0x00002
    addi  t2, t2, 38
    sw    t2, 16(t0)
echo_loop:
    lw    t3, 8(t0)
    andi  t3, t3, 2
    beq   t3, zero, echo_loop
    lw    t1, 4(t0)
    jal   ra, putc
    sw    t1, 16(t0)
    beq   zero, zero, echo_loop
putc:
wait_tx:
    lw    t3, 8(t0)
    andi  t3, t3, 1
    beq   t3, zero, wait_tx
    sw    t1, 0(t0)
    jalr  zero, 0(ra)
