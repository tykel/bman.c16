ASM_FILES := bman.asm gfx.asm util.asm
BIN_FILES := data/palette.bin data/player.bin data/shadow.bin data/bomb.bin data/expl.bin data/block.bin data/crate.bin data/floor.bin data/pwrup_flame.bin data/pwrup_bombs.bin

bman.c16: $(ASM_FILES) $(BIN_FILES)
	as16 $(ASM_FILES) -m -o $@

data/palette.bin: palette.txt
	xxd -r -p $< $@

data/%.bin: bmp/%.bmp
	img16 $< -o $@ -k 8 -pb data/palette.bin -d
