CXX=clang++
AS=clang

ELF_TARGET=jezos.elf
ISO_TARGET=jezos.iso
IMG_TARGET=jezos.img

GRUB_EFI=BOOTX64.EFI

TARGET-TRIPLE=-target x86_64-unknown-none
LD=ld.lld

CXXFLAGS=-static -c -ffreestanding -nostdlib -mno-red-zone
ASFLAGS=$(CXXFLAGS)
LDFLAGS=-static
LINK_SCRIPT=linker.ld

SOURCES=boot.S

OBJECTS=$(patsubst %.S, %.o, $(SOURCES))

bootdisk: build
	mv $(ELF_TARGET) isodir_bios/boot/$(ELF_TARGET)
	grub-mkrescue -o $(ISO_TARGET) isodir_bios

bios-run: bootdisk
	qemu-system-x86_64 -cdrom $(ISO_TARGET)

debug-bios: CXXFLAGS+=-ggdb
debug-bios: ASFLAGS+=-ggdb
debug-bios: bootdisk
	qemu-system-x86_64 -cdrom $(ISO_TARGET) -s & sleep 1 && gdb isodir_bios/boot/$(ELF_TARGET) -x gdb.script

efi: build
	mv $(ELF_TARGET) isodir_efi/boot/$(ELF_TARGET)
	grub-mkstandalone -O x86_64-efi -o $(GRUB_EFI) "boot/grub/grub.cfg=grub_build.cfg"
	dd if=/dev/zero of=$(IMG_TARGET) bs=512 count=93750
	parted $(IMG_TARGET) -s -a minimal mklabel gpt
	parted $(IMG_TARGET) -s -a minimal mkpart EFI FAT16 2048s 93716s
	parted $(IMG_TARGET) -s -a minimal toggle 1 boot
	dd if=/dev/zero of=/tmp/part.img bs=512 count=91669
	mformat -i /tmp/part.img -h 32 -t 32 -n 64 -c 1 ::
	mmd -i /tmp/part.img ::/EFI
	mmd -i /tmp/part.img ::/EFI/BOOT
	mmd -i /tmp/part.img ::/boot
	mmd -i /tmp/part.img ::/boot/grub
	mcopy -i /tmp/part.img $(GRUB_EFI) ::/EFI/BOOT
	mcopy -i /tmp/part.img isodir_efi/boot/grub/grub.cfg ::/boot/grub
	mcopy -i /tmp/part.img isodir_efi/boot/$(ELF_TARGET) ::/boot
	dd if=/tmp/part.img of=$(IMG_TARGET) bs=512 count=91669 seek=2048 conv=notrunc

efi-run: efi
	qemu-system-x86_64 -pflash OVMF.fd $(IMG_TARGET)


debug-efi: CXXFLAGS+=-ggdb
debug-efi: ASFLAGS+=-ggdb
debug-efi: efi
	qemu-system-x86_64 -pflash OVMF.fd $(IMG_TARGET) -s -S & sleep 1 && gdb isodir_efi/boot/$(ELF_TARGET) -x gdb.script

build: $(OBJECTS)
	$(LD) $(LDFLAGS) -T $(LINK_SCRIPT) -o $(ELF_TARGET) $<

%.o : %.S
	$(AS) $(TARGET-TRIPLE) $(ASFLAGS) -o $@ $<

clean:
	rm -f $(ISO_TARGET) $(OBJECTS) $(ELF_TARGET) $(IMG_TARGET) isodir*/boot/$(ELF_TARGET) /tmp/part.img $(GRUB_EFI)
