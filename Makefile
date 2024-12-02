ASM_FILES := bman.asm gfx.asm
BIN_FILES := data/player.bin

bman.c16: $(ASM_FILES) $(BIN_FILES)
	as16 $(ASM_FILES) -m -o $@
	
data/player.bin: bmp/player.bmp
	img16 $< -o $@ -k 4
