.section .init

.global start

.global flashio_worker_begin
.global flashio_worker_end

.global isp_flasher_begin
.global isp_flasher_end

start:

# warm up flashmemio
li t6, 0x01000000
lw t6, 0(t6)

# zero-initialize register file
addi x1, zero, 0
li   x2, 0x04001000
# x2 (sp) is initialized by reset
addi x3, zero, 0
addi x4, zero, 0
addi x5, zero, 0
addi x6, zero, 0
addi x7, zero, 0
addi x8, zero, 0
addi x9, zero, 0
addi x10, zero, 0
addi x11, zero, 0
addi x12, zero, 0
addi x13, zero, 0
addi x14, zero, 0
addi x15, zero, 0
addi x16, zero, 0
addi x17, zero, 0
addi x18, zero, 0
addi x19, zero, 0
addi x20, zero, 0
addi x21, zero, 0
addi x22, zero, 0
addi x23, zero, 0
addi x24, zero, 0
addi x25, zero, 0
addi x26, zero, 0
addi x27, zero, 0
addi x28, zero, 0
addi x29, zero, 0
addi x30, zero, 0
addi x31, zero, 0

# zero initialize scratchpad memory
# setmemloop:
# sw zero, 0(x1)
# addi x1, x1, 4
# blt x1, sp, setmemloop

# call main

li t0, 0x02000020
li t1, 206
li t2, 0x00000055
li t4, 0x02000010
li t5, 10
# reg_uart_clkdiv = 206
sw t1, 4(t0)


mL0:
# gpio = ~gpio
lw t1, 0(t4)
not t1, t1
sw t1, 0(t4)

# loop read
li t3, 80000

mL1:
lw t1, 0(t0)
beq t1, t2, mRun
addi t3, t3, -1
bne t3, zero, mL1

addi t5, t5, -1
bne t5, zero, mL0

la t0, flstart
jalr t0
endloop:
j endloop

mRun:
# go to flasher
li a0, 0x04000000
la a1, flashio_worker_begin
j isp_flasher_begin
# a0 ... instr buffer pointer
#   0 instr
#   1-3 addr
#   4-259 page dat
# a1 ... flashio pointer

flashio_worker_begin:
# a0 ... data pointer
# a1 ... data length
# a2 ... optional WREN cmd (0 = disable)

# address of SPI ctrl reg
li   t0, 0x02000000

# Set CS high, IO0 is output
li   t1, 0x120
sh   t1, 0(t0)

# Enable Manual SPI Ctrl
sb   zero, 3(t0)

# Send optional WREN cmd
beqz a2, flashio_worker_L1
li   t5, 8
andi t2, a2, 0xff
flashio_worker_L4:
srli t4, t2, 7
sb   t4, 0(t0)
ori  t4, t4, 0x10
sb   t4, 0(t0)
slli t2, t2, 1
andi t2, t2, 0xff
addi t5, t5, -1
bnez t5, flashio_worker_L4
sb   t1, 0(t0)

# SPI transfer
flashio_worker_L1:
beqz a1, flashio_worker_L3
li   t5, 8
lbu  t2, 0(a0)
flashio_worker_L2:
srli t4, t2, 7
sb   t4, 0(t0)
ori  t4, t4, 0x10
sb   t4, 0(t0)
lbu  t4, 0(t0)
andi t4, t4, 2
srli t4, t4, 1
slli t2, t2, 1
or   t2, t2, t4
andi t2, t2, 0xff
addi t5, t5, -1
bnez t5, flashio_worker_L2
sb   t2, 0(a0)
addi a0, a0, 1
addi a1, a1, -1
j    flashio_worker_L1
flashio_worker_L3:

# Wait for tw when writing SR
beqz a2, flashio_worker_L6
li t1, 32
sb   t1, 0(t0)
li t1, 30000
flashio_worker_L5:
addi t1, t1, -1
bnez t1, flashio_worker_L5;

flashio_worker_L6:

# Back to MEMIO mode
li   t1, 0x80
sb   t1, 3(t0)

ret
flashio_worker_end:



isp_flasher_begin:
# a0 ... instr buffer pointer
#   0 instr
#   1-3 addr
#   4-259 page dat
# a1 ... flashio pointer

# address of UART dat reg
li t0, 0x02000020
addi t6, x0, 0
addi a4, a1, 0

# instr read
isp_flasher_IREAD:
lw t1, 0(t0)
blt t1, x0, isp_flasher_IREAD

li t2, 0x55
beq t1, t2, isp_flasher_ACK
li t2, 0x10
beq t1, t2, isp_flasher_WBUF
li t2, 0x30
beq t1, t2, isp_flasher_ESEC
li t2, 0x40
beq t1, t2, isp_flasher_WPAG
li t2, 0xF0
beq t1, t2, isp_flasher_RST

j isp_flasher_IREAD

# ack
# 0x55
# 0x56
isp_flasher_ACK:
li t1, 0x56
sw t1, 0(t0)
j isp_flasher_IREAD

# write buffer
# 0x10 len dat0-datn
# 0x11 ....                       chk 
isp_flasher_WBUF:
li t1, 0x11
sw t1, 0(t0)

addi t2, a0, 4
isp_flasher_RLEN:
lw t1, 0(t0)
blt t1, x0, isp_flasher_RLEN
addi t1, t1, 1
addi t6, t1, 0

addi t4, x0, 0

isp_flasher_RDAT:
lw t3, 0(t0)
blt t3, x0, isp_flasher_RDAT
sb t3, 0(t2)
addi t2, t2, 1
addi t1, t1, -1
add t4, t4, t3
bnez t1, isp_flasher_RDAT

isp_flasher_RCOMP:
andi t4, t4, 0xFF
sw t4, 0(t0)

j isp_flasher_IREAD

# sector erase
# 0x30 addr2-0
# 0x31                     0x32
isp_flasher_ESEC:
li t1, 0x31
sw t1, 0(t0)

# prepare instr and addr
li t1, 0x20
sb t1, 0(a0)
isp_flasher_ERADA:
lw t1, 0(t0)
blt t1, x0, isp_flasher_ERADA
sb t1, 1(a0)
isp_flasher_ERADB:
lw t1, 0(t0)
blt t1, x0, isp_flasher_ERADB
sb t1, 2(a0)
isp_flasher_ERADC:
lw t1, 0(t0)
blt t1, x0, isp_flasher_ERADC
sb t1, 3(a0)

# call flashio to proceed erase
addi a1, x0, 4
addi a2, x0, 6
addi sp, sp, -4
sw ra, 0(sp)
jal ra, isp_flasher_CFLASH
lw ra, 0(sp)
addi sp, sp, 4

# call flashio to check status byte
isp_flasher_ECSTAT:
li t1, 0x05
sb t1, 0(a0)
addi a1, x0, 2
addi a2, x0, 0
addi sp, sp, -4
sw ra, 0(sp)
jal ra, isp_flasher_CFLASH
lw ra, 0(sp)
addi sp, sp, 4
lbu t2, 1(a0)
andi t2, t2, 1
bnez t2, isp_flasher_ECSTAT

li t1, 0x32
sw t1, 0(t0)
j isp_flasher_IREAD

# page write
# page length saved in t6 from last wbuf
# flashio have 16.25ms wait to fit WRSR tw requirement so no wait in page write
# 0x40 addr0 - 2
# 0x41                   0x42
isp_flasher_WPAG:
li t1, 0x41
sw t1, 0(t0)

li t1, 0x02
sb t1, 0(a0)
isp_flasher_WRADA:
lw t1, 0(t0)
blt t1, x0, isp_flasher_WRADA
sb t1, 1(a0)
isp_flasher_WRADB:
lw t1, 0(t0)
blt t1, x0, isp_flasher_WRADB
sb t1, 2(a0)
isp_flasher_WRADC:
lw t1, 0(t0)
blt t1, x0, isp_flasher_WRADC
sb t1, 3(a0)

beqz t6, isp_flasher_WFIN

# call flashio
addi a1, t6, 4
addi a2, x0, 6
addi sp, sp, -4
sw ra, 0(sp)
jal ra, isp_flasher_CFLASH
lw ra, 0(sp)
addi sp, sp, 4

isp_flasher_WFIN:
li t1, 0x42
sw t1, 0(t0)
j isp_flasher_IREAD

# reset system
# 0xF0
# 0xF1
isp_flasher_RST:
li t1, 0xF1
sw t1, 0(t0)

# better impl on software reset planned
# stack pointer
li x2, 0x04001000
li t1, 0x00000000
jalr x0, t1, 0

isp_flasher_CFLASH:
addi sp, sp, -36
# ra a0 t0 - t6
sw ra, 32(sp)
sw a0, 28(sp)
sw t0, 24(sp)
sw t1, 20(sp)
sw t2, 16(sp)
sw t3, 12(sp)
sw t4, 8(sp)
sw t5, 4(sp)
sw t6, 0(sp)
# call flashio_worker
jalr a4

lw ra, 32(sp)
lw a0, 28(sp)
lw t0, 24(sp)
lw t1, 20(sp)
lw t2, 16(sp)
lw t3, 12(sp)
lw t4, 8(sp)
lw t5, 4(sp)
lw t6, 0(sp)
addi sp, sp, 36
ret

isp_flasher_end:
