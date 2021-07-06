

SRCFILES = application.asm copyscreenROM.asm game_keys.asm misc_oz.asm jsw.asm
OFILES = $(SRCFILES:.asm=.o)

all: jsw.epr

jsw.bin: $(OFILES)
	z88dk-z80asm -b -o$@ $^

romhdr.bin: romhdr.asm
	z88dk-z80asm -b -o$@ $^

%.o: %.asm
	zcc +z88 -c $^

jsw.epr: util/rompacker jsw.bin romhdr.bin
	util/rompacker $@ 32768 jsw.bin:58368 romhdr.bin:65472 assets/rooms.bin:32768 assets/gfx.bin:49152

util/rompacker:
	$(MAKE) -C util

clean:
	$(RM) -f *.o jsw.bin romhdr.bin jsw.epr jsw.app
	$(MAKE) -C util clean
	
