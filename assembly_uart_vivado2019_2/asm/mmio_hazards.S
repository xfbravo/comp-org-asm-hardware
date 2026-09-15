# Dedicated MMIO/forwarding regression; never used as the board program.
    li s0,0x40000000
wait_two:
    lw t0,8(s0)
    andi t0,t0,480
    li t1,64
    bne t0,t1,wait_two
    lw t2,4(s0)
    sw t2,0(s0)
    sw t2,0(zero)
    lw t3,0(zero)
    sw t3,16(s0)
    beq t3,t2,forward_ok
    sw zero,0(s0)
    sw zero,16(s0)
forward_ok:
    lw t3,0(zero)
    beq t3,t2,load_branch_ok
    sw t2,4(zero)
    lw t4,4(s0)
load_branch_ok:
    jal ra,jump_ok
    lw t4,4(s0)
    addi a0,zero,99
jump_ok:
    auipc t4,0
    addi t4,t4,16
    jalr ra,0(t4)
    sw t2,16(s0)
indirect_ok:
    lw t4,4(s0)
    li t5,66
    bne t4,t5,fail
wait_tx:
    lw t0,8(s0)
    andi t0,t0,1
    beq t0,zero,wait_tx
    sw t4,0(s0)
    lw t0,4(zero)
    bne t0,zero,fail
    bne a0,zero,fail
    # Consecutive producers must use newer EX/MEM value rather than older MEM/WB.
    li t0,1
    addi t0,t0,1
    add t1,t0,zero
    li t2,2
    bne t1,t2,fail
    li t0,0x600d
    sw t0,16(s0)
done:
    jal zero,done
fail:
    li t0,0xbad
    sw t0,16(s0)
    jal zero,done
