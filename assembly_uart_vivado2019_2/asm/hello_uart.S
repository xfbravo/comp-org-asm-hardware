# Final command firmware, RV32I only. MMIO base s0; stack grows down from 4096.
# RAM: line[65] @256, sort[5] @384, decimal powers[10] @640.
# s1=line length, s2=discard, s3=previous CR. No local echo.
    li sp, 4096
    li s0, 0x40000000
    li s1, 0
    li s2, 0
    li s3, 0
    li t0, 1000000000
    sw t0, 640(zero)
    li t0, 100000000
    sw t0, 644(zero)
    li t0, 10000000
    sw t0, 648(zero)
    li t0, 1000000
    sw t0, 652(zero)
    li t0, 100000
    sw t0, 656(zero)
    li t0, 10000
    sw t0, 660(zero)
    li t0, 1000
    sw t0, 664(zero)
    li t0, 100
    sw t0, 668(zero)
    li t0, 10
    sw t0, 672(zero)
    li t0, 1
    sw t0, 676(zero)
    li t0, 0x2026
    sw t0, 16(s0)
    li a0, 72
    jal ra, putc
    li a0, 105
    jal ra, putc
    li a0, 46
    jal ra, putc
    jal ra, newline
receive:
    lw t0, 8(s0)
    andi t1, t0, 12
    beq t1, zero, rx_check
    li s2, 1
    # Empty RX reads also clear errors. A popped byte still gets delimiter handling.
    lw a0, 4(s0)
    andi t1, t0, 2
    beq t1, zero, receive
    jal zero, character
rx_check:
    andi t1, t0, 2
    beq t1, zero, receive
    lw a0, 4(s0)
character:
    li t0, 10
    bne a0, t0, not_lf
    bne s3, zero, skip_lf
    jal zero, line_end
skip_lf:
    li s3, 0
    jal zero, receive
not_lf:
    li s3, 0
    li t0, 13
    beq a0, t0, cr_end
    bne s2, zero, receive
    # Reject every non-protocol character, including embedded NUL and tabs.
    li t0, 32
    beq a0, t0, append
    li t0, 45
    beq a0, t0, append
    li t0, 48
    blt a0, t0, bad_line
    li t0, 58
    blt a0, t0, append
    li t0, 65
    blt a0, t0, bad_line
    li t0, 91
    blt a0, t0, append
bad_line:
    li s2, 1
    jal zero, receive
append:
    li t0, 64
    bge s1, t0, bad_line
    addi t0, s1, 256
    sb a0, 0(t0)
    addi s1, s1, 1
    jal zero, receive
cr_end:
    li s3, 1
line_end:
    bne s2, zero, discard_end
    beq s1, zero, receive
    addi t0, s1, 256
    sb zero, 0(t0)
    jal ra, command
    jal zero, reset_line
discard_end:
    jal ra, error
reset_line:
    li s1, 0
    li s2, 0
    jal zero, receive

# putc preserves all registers except t5/t6; callers may retain formatting state.
putc:
    lw t5, 8(s0)
    andi t5, t5, 1
    beq t5, zero, putc
    sw a0, 0(s0)
    jalr zero, 0(ra)
newline:
    addi sp, sp, -16
    sw ra, 12(sp)
    li a0, 13
    jal ra, putc
    li a0, 10
    jal ra, putc
    lw ra, 12(sp)
    addi sp, sp, 16
    jalr zero, 0(ra)
error:
    addi sp, sp, -16
    sw ra, 12(sp)
    li a0, 69
    jal ra, putc
    li a0, 82
    jal ra, putc
    jal ra, putc
    jal ra, newline
    lw ra, 12(sp)
    addi sp, sp, 16
    jalr zero, 0(ra)

command:
    addi sp, sp, -16
    sw ra, 12(sp)
    li s4, 256
    jal ra, spaces
    lbu t0, 0(s4)
    beq t0, zero, command_return
    li t1, 72
    beq t0, t1, help
    li t1, 65
    beq t0, t1, add_command
    li t1, 83
    beq t0, t1, sort_command
    jal zero, command_error
help:
    lbu t0, 1(s4)
    li t1, 69
    bne t0, t1, command_error
    lbu t0, 2(s4)
    li t1, 76
    bne t0, t1, command_error
    lbu t0, 3(s4)
    li t1, 80
    bne t0, t1, command_error
    addi s4, s4, 4
    jal ra, end_args
    beq a1, zero, command_error
    li a0, 72
    jal ra, putc
    li a0, 69
    jal ra, putc
    li a0, 76
    jal ra, putc
    li a0, 80
    jal ra, putc
    li a0, 32
    jal ra, putc
    li a0, 65
    jal ra, putc
    li a0, 68
    jal ra, putc
    jal ra, putc
    li a0, 32
    jal ra, putc
    li a0, 83
    jal ra, putc
    li a0, 79
    jal ra, putc
    li a0, 82
    jal ra, putc
    li a0, 84
    jal ra, putc
    jal zero, command_newline
add_command:
    lbu t0, 1(s4)
    li t1, 68
    bne t0, t1, command_error
    lbu t0, 2(s4)
    bne t0, t1, command_error
    lbu t0, 3(s4)
    li t1, 32
    bne t0, t1, command_error
    addi s4, s4, 4
    jal ra, number
    beq a1, zero, command_error
    mv s5, a0
    jal ra, number
    beq a1, zero, command_error
    mv s6, a0
    jal ra, end_args
    beq a1, zero, command_error
    add s7, s5, s6
    xor t0, s7, s5
    xor t1, s7, s6
    and t0, t0, t1
    blt t0, zero, command_error
    sw s7, 16(s0)
    mv a0, s7
    jal ra, print_number
    jal zero, command_newline
sort_command:
    lbu t0, 1(s4)
    li t1, 79
    bne t0, t1, command_error
    lbu t0, 2(s4)
    li t1, 82
    bne t0, t1, command_error
    lbu t0, 3(s4)
    li t1, 84
    bne t0, t1, command_error
    lbu t0, 4(s4)
    li t1, 32
    bne t0, t1, command_error
    addi s4, s4, 5
    li s5, 384
    li s6, 5
sort_parse:
    jal ra, number
    beq a1, zero, command_error
    sw a0, 0(s5)
    addi s5, s5, 4
    addi s6, s6, -1
    bne s6, zero, sort_parse
    jal ra, end_args
    beq a1, zero, command_error
    li s6, 4
sort_outer:
    li s5, 384
    mv s7, s6
sort_inner:
    lw t0, 0(s5)
    lw t1, 4(s5)
    bge t1, t0, no_swap
    sw t1, 0(s5)
    sw t0, 4(s5)
no_swap:
    addi s5, s5, 4
    addi s7, s7, -1
    bne s7, zero, sort_inner
    addi s6, s6, -1
    bne s6, zero, sort_outer
    lw t0, 384(zero)
    sw t0, 16(s0)
    li s5, 384
    li s6, 5
sort_print:
    lw a0, 0(s5)
    jal ra, print_number
    addi s5, s5, 4
    addi s6, s6, -1
    beq s6, zero, command_newline
    li a0, 32
    jal ra, putc
    jal zero, sort_print
command_error:
    jal ra, error
    jal zero, command_return
command_newline:
    jal ra, newline
command_return:
    lw ra, 12(sp)
    addi sp, sp, 16
    jalr zero, 0(ra)

# spaces/end_args preserve s5-s7 and ra; number returns a0 and a1=valid.
spaces:
    lbu t0, 0(s4)
    li t1, 32
    bne t0, t1, spaces_done
    addi s4, s4, 1
    jal zero, spaces
spaces_done:
    jalr zero, 0(ra)
end_args:
    addi sp, sp, -16
    sw ra, 12(sp)
    jal ra, spaces
    sltiu a1, t0, 1
    lw ra, 12(sp)
    addi sp, sp, 16
    jalr zero, 0(ra)
number:
    addi sp, sp, -16
    sw ra, 12(sp)
    jal ra, spaces
    li a0, 0
    li a1, 0
    li t2, 0
    li t3, 0
    li t1, 45
    bne t0, t1, digit
    li t2, 1
    addi s4, s4, 1
digit:
    lbu t0, 0(s4)
    addi t0, t0, -48
    li t1, 10
    bgeu t0, t1, number_end
    li t4, 214748364
    bltu t4, a0, number_bad
    bne a0, t4, digit_ok
    addi t1, t2, 7
    bltu t1, t0, number_bad
digit_ok:
    slli t1, a0, 3
    slli a0, a0, 1
    add a0, a0, t1
    add a0, a0, t0
    li t3, 1
    addi s4, s4, 1
    jal zero, digit
number_end:
    beq t3, zero, number_bad
    lbu t0, 0(s4)
    beq t0, zero, number_ok
    li t1, 32
    bne t0, t1, number_bad
number_ok:
    beq t2, zero, number_positive
    sub a0, zero, a0
number_positive:
    li a1, 1
number_bad:
    lw ra, 12(sp)
    addi sp, sp, 16
    jalr zero, 0(ra)

# Unsigned magnitude handles INT32_MIN. At most 9 subtractions per decimal digit.
print_number:
    addi sp, sp, -16
    sw ra, 12(sp)
    mv t0, a0
    bge a0, zero, magnitude
    sub t0, zero, a0
    li a0, 45
    jal ra, putc
magnitude:
    li t1, 640
    li t3, 0
print_digit:
    lw t2, 0(t1)
    li t4, 0
subtract_digit:
    bltu t0, t2, digit_ready
    sub t0, t0, t2
    addi t4, t4, 1
    jal zero, subtract_digit
digit_ready:
    bne t4, zero, emit_digit
    bne t3, zero, emit_digit
    li t6, 676
    bne t1, t6, next_digit
emit_digit:
    li t3, 1
    addi a0, t4, 48
    jal ra, putc
next_digit:
    addi t1, t1, 4
    li t6, 680
    blt t1, t6, print_digit
    lw ra, 12(sp)
    addi sp, sp, 16
    jalr zero, 0(ra)
