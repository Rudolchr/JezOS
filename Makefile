CXX=clang++
AS=clang

TARGET=sos.bin
TARGET-TRIPLE=-target x86_64-unknown-none
LD=ld.lld

CXXFLAGS=-static -c -ffreestanding -nostdlib -mno-red-zone
ASFLAGS=$(CXXFLAGS)
LDFLAGS=-static
LINK_SCRIPT=linker.ld

SOURCES=boot.S

OBJECTS=$(patsubst %.S, %.o, $(SOURCES))

bootdisk: build
	mv sos.bin isodir_bios/boot/sos.bin
	grub-mkrescue -o sos.iso isodir_bios

bios-run: bootdisk
	qemu-system-x86_64 -cdrom sos.iso

debug-bios: CXXFLAGS+=-ggdb
debug-bios: ASFLAGS+=-ggdb
debug-bios: bootdisk
	qemu-system-x86_64 -cdrom sos.iso -s & sleep 1 && gdb isodir_bios/boot/sos.bin

efi: build
	mv sos.bin isodir_efi/boot/sos.bin
	grub-mkstandalone -O x86_64-efi -o BOOTX64.EFI "boot/grub/grub.cfg=grub_build.cfg"
	dd if=/dev/zero of=uefi.img bs=512 count=93750
	parted uefi.img -s -a minimal mklabel gpt
	parted uefi.img -s -a minimal mkpart EFI FAT16 2048s 93716s
	parted uefi.img -s -a minimal toggle 1 boot
	dd if=/dev/zero of=/tmp/part.img bs=512 count=91669
	mformat -i /tmp/part.img -h 32 -t 32 -n 64 -c 1 ::
	mmd -i /tmp/part.img ::/EFI
	mmd -i /tmp/part.img ::/EFI/BOOT
	mmd -i /tmp/part.img ::/boot
	mmd -i /tmp/part.img ::/boot/grub
	mcopy -i /tmp/part.img BOOTX64.EFI ::/EFI/BOOT
	mcopy -i /tmp/part.img isodir_efi/boot/grub/grub.cfg ::/boot/grub
	mcopy -i /tmp/part.img isodir_efi/boot/sos.bin ::/boot
	dd if=/tmp/part.img of=uefi.img bs=512 count=91669 seek=2048 conv=notrunc

efi-run: efi
	qemu-system-x86_64 -pflash OVMF.fd uefi.img


debug-efi: CXXFLAGS+=-ggdb
debug-efi: ASFLAGS+=-ggdb
debug-efi: efi
	qemu-system-x86_64 -pflash OVMF.fd uefi.img -s -S & sleep 1 && gdb isodir_efi/boot/sos.bin

build: $(OBJECTS)
	$(LD) $(LDFLAGS) -T $(LINK_SCRIPT) -o $(TARGET) $<

%.o : %.S
	$(AS) $(TARGET-TRIPLE) $(ASFLAGS) -o $@ $<

clean:
	rm -f *.iso *.o *.bin *.img isodir*/boot/sos.bin /tmp/part.img BOOTX64.EFI
