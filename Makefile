CXX=clang++
AS=clang
LD=ld.lld

TARGET_TRIPLE=-target x86_64-unknown-none
COMMON_FLAGS=-c $(TARGET_TRIPLE) -ffreestanding -nostdlib -nostdinc -fno-builtin -mno-red-zone
ASFLAGS=$(COMMON_FLAGS)
CXXFLAGS= $(COMMON_FLAGS) -nostdinc++
LDFLAGS=-static

BIN=bin
SRC=src
INCLUDE=include
MACHINE=machine
3RD_PARTY=3rd_party

ELF_TARGET=jezos.elf
ISO_TARGET=jezos.iso
IMG_TARGET=jezos.img

TMP_IMG=tmp.img
GRUB_EFI=BOOTX64.EFI

BOOT_EFI=$(MACHINE)/bootloader/isodir_efi
BOOT_BIOS=$(MACHINE)/bootloader/isodir_bios
GRUB_BUILD=$(MACHINE)/bootloader/grub_build.cfg
EFI_GRUB_CFG=$(BOOT_EFI)/boot/grub/grub.cfg
OVMF=$(MACHINE)/boot/bios/OVMF.fd
LINKER_SCRIPT=$(MACHINE)/linker.ld

OVMF=$(3RD_PARTY)/bios/OVMF.fd

INCLUDE_PATHS=-I $(INCLUDE) -I $(3RD_PARTY)/include

CXX_SOURCE=\
	     $(wildcard $(SRC)/*.cc) \
	     $(wildcard $(SRC)/*/*.cc) \
	     $(wildcard $(SRC)/*/*/*.cc)
AS_SOURCE=\
	   $(wildcard $(MASCHINE)/*.S) \
	   $(wildcard $(MACHINE)/*/*.S)

SOURCES= $(CXX_SOURCE) $(AS_SOURCE)

VPATH=$(dir $(CXX_SOURCE) $(AS_SOURCE))

OBJECT_FILES=$(patsubst %.cc, $(BIN)/%.o, $(patsubst %.S, $(BIN)/%.o, $(notdir $(SOURCES))))

.PHONY: clean build debug-efi debug-bios efi bios efi-run bios-run

bios: build
	mv $(BIN)/$(ELF_TARGET) $(BOOT_BIOS)/boot/$(ELF_TARGET)
	grub-mkrescue -o $(BIN)/$(ISO_TARGET) $(BOOT_BIOS)

bios-run: bios
	qemu-system-x86_64 -cdrom $(BIN)/$(ISO_TARGET)

debug-bios: COMMON_FLAGS+=-ggdb3
debug-bios: bios
	qemu-system-x86_64 -cdrom $(BIN)/$(ISO_TARGET) -s & sleep 1 && gdb -x gdb.script $(BOOT_BIOS)/boot/$(ELF_TARGET)

efi: build
	dd if=/dev/zero of=$(BIN)/$(IMG_TARGET) bs=512 count=102400
	dd if=/dev/zero of=$(BIN)/$(TMP_IMG) bs=512 count=92160
	cp $(BIN)/$(ELF_TARGET) $(BOOT_EFI)/boot/$(ELF_TARGET)
	grub-mkstandalone -O x86_64-efi -o $(BIN)/$(GRUB_EFI) "boot/grub/grub.cfg=$(GRUB_BUILD)"
	parted $(BIN)/$(IMG_TARGET) -s -a minimal mklabel gpt
	parted $(BIN)/$(IMG_TARGET) -s -a minimal mkpart EFI fat32 2048s 100352s
	parted $(BIN)/$(IMG_TARGET) -s -a minimal toggle 1 boot
	mformat -i $(BIN)/$(TMP_IMG) -h 32 -t 32 -n 80 -c 1 ::
	mmd -i $(BIN)/$(TMP_IMG) ::/EFI
	mmd -i $(BIN)/$(TMP_IMG) ::/EFI/BOOT
	mmd -i $(BIN)/$(TMP_IMG) ::/boot
	mmd -i $(BIN)/$(TMP_IMG) ::/boot/grub
	mcopy -i $(BIN)/$(TMP_IMG) $(BIN)/$(GRUB_EFI) ::/efi/boot
	mcopy -i $(BIN)/$(TMP_IMG) $(EFI_GRUB_CFG) ::/boot/grub
	mcopy -i $(BIN)/$(TMP_IMG) $(BIN)/$(ELF_TARGET) ::/boot
	dd if=$(BIN)/$(TMP_IMG) of=$(BIN)/$(IMG_TARGET) bs=512 count=91136 seek=2048 conv=notrunc

efi-run: efi
	qemu-system-x86_64 -pflash $(OVMF) $(BIN)/$(IMG_TARGET)

debug-efi: COMMON_FLAGS+=-ggdb3
debug-efi: efi
	qemu-system-x86_64 -pflash $(OVMF) $(BIN)/$(IMG_TARGET) -s -S & sleep 1 && gdb -x gdb.script $(BOOT_EFI)/boot/$(ELF_TARGET)

test:
	echo $(SOURCES)
	echo $(OBJECT_FILES)
	echo $(INCLUDE_PATHS)

build: $(OBJECT_FILES)
	$(LD) $(LDFLAGS) -T $(LINKER_SCRIPT) -o $(BIN)/$(ELF_TARGET) $^

$(BIN)/%.o: %.cc
	$(CXX) $(TARGET_TRIPLE) $(CXXFLAGS) $(INCLUDE_PATHS) -o $@ $<

$(BIN)/%.o: %.S
	$(AS) $(TARGET_TRIPLE) $(ASFLAGS) $(INCLUDE_PATHS) -o $@ $<

clean:
	rm -f bin/*
	rm -f $(BOOT_BIOS)/boot/$(ELF_TARGET)
