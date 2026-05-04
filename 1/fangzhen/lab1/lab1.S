    .org 0x0
    .text
    .global _start
_start:
    addi.w      $t0,$zero,0x1   # t0 = 1                              00000000 0280040c
    addi.w      $t1,$zero,0x1   # t1 = 1                              00000004 0280040d
    lu12i.w     $a0,-0x7fc00    # a0 = 0x80400000                     00000008 15008004
    addi.w      $a1,$a0,0x100   # a1 = 0x80400100                     0000000c 02840085
loop:
    add.w       $t2,$t0,$t1     # t2 = t0+t1                          00000010 0010358e
    addi.w      $t0,$t1,0x0     # t0 = t1                             00000014 028001ac
    addi.w      $t1,$t2,0x0     # t1 = t2                             00000018 028001cd
    st.w        $t2,$a0,0x0                                           0000001c 2980008e
    ld.w        $t3,$a0,0x0                                                    2880008f
    bne         $t2,$t3,end						00000024
    addi.w      $a0,$a0,0x4     # a0 += 4			00000028
    bne         $a0,$a1,loop						00000030
end:
    bne         $a0,$zero,end
