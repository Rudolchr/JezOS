#include "boot/multiboot2.h"

.extern kernel_main

.set MAGIC,		MULTIBOOT2_HEADER_MAGIC # 0xE85250D6
.set ARCH,		MULTIBOOT_ARCHITECTURE_I386 # 0x0
.set HEADER_LEN,	multiboot_header_end - multiboot_header_start # 0x10
.set CHECKSUM,		0x100000000 - (MAGIC + ARCH + HEADER_LEN)

.section .multiboot
multiboot_header_start:
.align MULTIBOOT_HEADER_ALIGN
.long MAGIC
.long ARCH
.long HEADER_LEN
.long CHECKSUM

#entry_tag_start:
#.align MULTIBOOT_TAG_ALIGN
#.short MULTIBOOT_HEADER_TAR_ADDRESS
#.short MULTIBOOT_HEADER_TAG_OPTIONAL
#.long entry_tag_end - entry_tag_start
#.long multiboot_header_start
#.long 0
#.long 0
#
#entry_tag_end:
#entry_addr_start:
#.align MULTIBOOT_TAG_ALIGN
#.short MULTIBOOT_HEADER_TAG_ENTRY_ADDRESS_EFI64
#.short MULTIBOOT_HEADER_TAG_OPTIONAL
#.long entry_addr_start - entry_addr_end
#.long _kernel_start
#
#entry_addr_end:

framebuffer_tag_start:
.align MULTIBOOT_TAG_ALIGN
.short MULTIBOOT_HEADER_TAG_FRAMEBUFFER
.short MULTIBOOT_HEADER_TAG_OPTIONAL
.long framebuffer_tag_end - framebuffer_tag_start
.long 1024
.long 768
.long 32
framebuffer_tag_end:

.align MULTIBOOT_TAG_ALIGN
.short MULTIBOOT_HEADER_TAG_END
.short 0x0
.long 0x8
multiboot_header_end:

.section .bss
.align 16
stack_bottom:
.skip 16384
stack_top:

.section .text
.global _kernel_start
.type _kernel_start, @function

_kernel_start:
mov $stack_top, %rsp
mov %rbx, %rdi
call kernel_main
cli
1:
hlt
jmp 1b

.size _kernel_start, . - _kernel_start
