ASM_FILES := bman.asm gfx.asm
BIN_FILES := data/player.bin data/shadow.bin data/bomb.bin data/expl.bin data/block.bin data/crate.bin

bman.c16: $(ASM_FILES) $(BIN_FILES)
	as16 $(ASM_FILES) -m -o $@
	
data/%.bin: bmp/%.bmp
	img16 $< -o $@ -k 4
