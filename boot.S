.set MAGIC,		0xE85250D6
.set ARCH,		0x0
.set HEADER_LEN,	0x10
.set CHECKSUM,		0x100000000 - (MAGIC + ARCH + HEADER_LEN)

.section .multiboot
.align 8
.long MAGIC
.long ARCH
.long HEADER_LEN
.long CHECKSUM
.align 8
.long 0x0
.long 0x0
.long 0x8

.section .bss
.align 16
stack_bottom:
.skip 16384
stack_top:

.section .text
.global _kernel_start
.type _kernel_start, @function

_kernel_start:
mov $stack_top, %esp
cli
1:
hlt
jmp 1b

.size _kerbel_start, . - _kernel_start
