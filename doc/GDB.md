# Connect GDB with Kernel
Build with debug flags.

#### BIOS
run `qemu-system-x86_64 -cdrom sos.iso -s`.
In a new terminal run `gdb ./isodir_bios/boot/sos.bin`.

#### UEFI
run `qemu-system-x86_64 -bios OVMD.fd uefi.img -s -S`
In a new terminal run `gdb ./isodir_efi/boot/sos.bin`

### GDB
In gdb cli set breakpoint e.g. `_kernel_start`
Attach to qemu with `target remote :1234`
