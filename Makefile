bman.c16: bman.asm gfx.asm data/player.bin
	as16 $^ -m -o $@
	
data/player.bin: bmp/player.bmp
	img16 $< -o $@ -k 4
