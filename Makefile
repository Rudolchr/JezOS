CXX=clang++
AS=clang
LD=ld.lld

TARGET_TRIPLE=-target x86_64-unknown-none
CXXFLAGS= -c $(TARGET_TRIPLE) -ffreestanding -nostdlib -nostdinc -nostdinc++ -fno-builtin -mno-red-zone
ASFLAGS=-c $(TARGET_TRIPLE) -ffreestanding -nostdlib -nostdinc -fno-builtin -mno-red-zone
LDFLAGS=-static

BIN=bin
SRC=src
INCLUDE=include
MACHINE=machine

ELF_TARGET=jezos.elf
ISO_TARGET=jezos.iso
IMG_TARGET=jezos.img

BOOT_EFI=$(MACHINE)/bootloader/isodir_efi
BOOT_BIOS=$(MACHINE)/bootloader/isodir_bios
GRUB_BUILD=$(MACHINE)/bootloader/grub_build.cfg
OVMF=$(MACHINE)/boot/bios/OVMF.fd
LINKER_SCRIPT=$(MACHINE)/linker.ld

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

debug-bios: CXXFLAGS+=-ggdb
debug-bios: ASFLAGS+=-ggdb
debug-bios: bios
	qemu-system-x86_64 -cdrom $(BIN)/$(ISO_TARGET) -s & sleep 1 && gdb -x gdb.script $(BOOT_BIOS)/boot/$(ELF_TARGET)

test:
	echo $(SOURCES)
	echo $(OBJECT_FILES)

build: $(OBJECT_FILES)
	$(LD) $(LDFLAGS) -T $(LINKER_SCRIPT) -o $(BIN)/$(ELF_TARGET) $^

$(BIN)/%.o: %.cc
	$(CXX) $(TARGET_TRIPLE) $(CXXFLAGS) -I $(INCLUDE) -o $@ $<

$(BIN)/%.o: %.S
	$(AS) $(TARGET_TRIPLE) $(ASFLAGS) -I $(INCLUDE) -o $@ $<

clean:
	rm -f bin/*
	rm -f $(BOOT_BIOS)/boot/$(ELF_TARGET)
