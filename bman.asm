;------------------------------------------------------------------------------
; bman.asm
; A Bomberman (R) clone for Chip16
; Copyright 2024 Tim Kelsall.
;------------------------------------------------------------------------------

init:               nop

game_loop:          call handle_pad
                    call move_plyrs
                    call handle_bombs
                    cls
                    bgc 0xb
                    call drw_grid
                    call drw_objs
                    call drw_plyrs
                    vblnk
                    jmp game_loop

handle_bombs:       ldm r0, data.num_bombs
                    ldi r1, data.bombs
                    ldi r2, 6
.handle_bombsL:     subi r0, 1
                    jn .handle_bombsZ
                    mul r0, r2, r3
                    add r3, r1
                    addi r3, 4      ; offsetof(bomb.timer)
                    ldm r4, r3
                    subi r4, 1
                    stm r4, r3
                    jnz .handle_bombsL
                    subi r3, 4
                    ldi r4, 0
                    ldm r5, r3
                    stm r4, r3
                    addi r3, 2
                    ldm r6, r3
                    stm r4, r3
                    addi r3, 2
                    stm r4, r3
                    subi r0, 1
                    stm r0, data.num_bombs
                    push r0
                    push r1
                    push r2
                    mov r0, r5
                    mov r1, r6
                    call expl_bomb
                    pop r2
                    pop r1
                    pop r0
                    jmp .handle_bombsL
.handle_bombsZ:     ret

expl_bomb:          ldi ra, 32
.expl_bombL:        push r0
                    push r1
                    add r0, ra
                    subi r0, 16
                    call map_put_flame
                    pop r1
                    pop r0
                    subi ra, 16
                    jnn .expl_bombL
                    ldi ra, 32
.expl_bombL2:       push r0
                    push r1
                    add r1, ra
                    subi r1, 16
                    call map_put_flame
                    pop r1
                    pop r0
                    subi ra, 16
                    jnn .expl_bombL2
.expl_bombSnd:      sng 0x30, 0xf3f3
                    ldi r0, 2000
                    snp r0, 200
                    ret

map_put_flame:      shr r1, 4
                    muli r1, 20
                    shr r0, 4
                    add r0, r1
                    addi r0, data.level
                    ldm r1, r0
                    mov r2, r1
                    andi r2, 0xff               ; empty : skip 
                    jz .map_put_flameZ
                    cmpi r2, 0x80               ; 128 == v: solid tile
                    jle .map_put_flameZ         ; 128 < v < 255 : destr. tile
                    andi r1, 0xff00
                    addi r1, 40                 ; add a 40-frame flame
                    stm r1, r0
.map_put_flameZ:    ret

handle_pad:         ldm r0, 0xfff0
                    ldi r1, data.vec_plyrs
                    ldm r4, data.anikey
                    divi r4, 5
                    muli r4, 512
                    addi r4, data.spr_plyr
                    ldi rf, 0
                    stm rf, r1
                    addi r1, 2
                    stm rf, r1
                    ldi r1, data.vec_plyrs
                    cmpi r0, 0
                    jnz .handle_pad0
                    ldi r0, 0
                    stm r0, data.anikey
                    jmp .handle_padZ
.handle_pad0:       ldm r9, data.anikey
                    subi r9, 1
                    jnn .handle_pad1
                    ldi r9, 19
.handle_pad1:       stm r9, data.anikey
                    ldm r2, data.speed_plyrs
.handle_padUp:      tsti r0, 1
                    jz .handle_padDn
                    addi r4, 128
                    stm r4, data.ptr_spr_plyr
                    addi r1, 2
                    neg r3, r2
                    stm r3, r1
                    ldi r2, 0
                    stm r2, data.dir_plyrs
                    jmp .handle_padZ
.handle_padDn:      tsti r0, 2
                    jz .handle_padLf
                    stm r4, data.ptr_spr_plyr
                    addi r1, 2
                    stm r2, r1
                    ldi r2, 1
                    stm r2, data.dir_plyrs
                    jmp .handle_padZ
.handle_padLf:      tsti r0, 4
                    jz .handle_padRt
                    addi r4, 256
                    stm r4, data.ptr_spr_plyr
                    neg r3, r2
                    stm r3, r1
                    ldi r2, 2
                    stm r2, data.dir_plyrs
                    jmp .handle_padZ
.handle_padRt:      tsti r0, 8
                    jz .handle_padZ
                    addi r4, 384
                    stm r4, data.ptr_spr_plyr
                    stm r2, r1
                    ldi r2, 3
                    stm r2, data.dir_plyrs
                    jmp .handle_padZ
.handle_padZ:       tsti r0, 64 ; A
                    jz .handle_padZZ
.handle_padAb:      ldi r1, 1
                    stm r1, data.num_bombs
                    ldi r1, data.pos_plyrs
                    ldi r2, data.bombs
                    ldm r3, r1
                    andi r3, 0xfff0
                    addi r3, 8
                    mov r4, r3
                    shr r4, 4
                    stm r3, r2
                    addi r1, 2
                    addi r2, 2
                    ldm r3, r1
                    andi r3, 0xfff0
                    addi r3, 8
                    stm r3, r2
                    addi r2, 2
                    ldi r1, 60  ; Set bomb with 60 frame timer
                    stm r1, r2
                    ;shr r3, 4
                    ;muli r3, 20
                    ;add r3, r4
                    ;addi r3, data.level
                    ;ldm r2, r3
                    ;andi r2, 0xff00
                    ;ori r2, 1
                    ;stm r2, r3
.handle_padZZ:      ret

move_plyrs:         ldi r2, data.pos_plyrs
                    ldm r0, r2  ; pos.x
                    addi r2, 2
                    ldm r1, r2  ; pos.y
                    ldi r2, data.vec_plyrs
                    ldm r3, r2  ; vec.x
                    add r0, r3, r8  ; x = pos.x + vec.x
                    addi r2, 2
                    ldm r3, r2  ; vec.y
                    add r1, r3, r9  ; y = pos.y + vec.y
                    
                    ldm r2, data.dir_plyrs
                    shl r2, 3
                    addi r2, data.move_lut
                    ldm r3, r2  ; x0 = x + move_lut[vec_dir].x0
                    add r3, r8
                    stm r3, debug.x0
                    addi r2, 2
                    ldm r4, r2  ; y0 = y + move_lut[vec_dir].y0
                    add r4, r9
                    stm r4, debug.y0
                    push r0
                    push r1
                    mov r0, r3
                    mov r1, r4
                    call map_contents_at
                    mov r3, r0
                    pop r1
                    pop r0
                    cmpi r3, 0
                    jnz .move_plyrsZ
                    addi r2, 2
                    ldm r3, r2  ; x1 = x + move_lut[vec_dir].x1
                    add r3, r8
                    stm r3, debug.x1
                    addi r2, 2
                    ldm r4, r2  ; y1 = y + move_lut[vec_dir].y1
                    add r4, r9
                    stm r4, debug.y1
                    mov r0, r3
                    mov r1, r4
                    call map_contents_at
                    cmpi r0, 0
                    jnz .move_plyrsZ
                    ldi r2, data.pos_plyrs
                    stm r8, r2  ; pos.x = x
                    addi r2, 2
                    stm r9, r2  ; pos.y = y
.move_plyrsZ:       ret

map_contents_at:    shr r0, 4   ; tile.x = pos.x / 16
                    shr r1, 4   ; tile.y = pos.y / 16
                    muli r1, 20
                    add r0, r1
                    addi r0, data.level ; tile_addr = (tile.y*20) * tile.x + data.level
                    ldm r0, r0
                    andi r0, 0xff
                    ret

drw_grid:           spr 0x1008
                    ldi r0, data.level
                    ldi r1, 299             ; r1 <= tile counter
                    ldi r2, 304             ; r2 <= tile x in pixels
                    ldi r3, 224             ; r3 <= tile y in pixels
.drw_gridL:         add r0, r1, r4
                    ldm r5, r4
                    mov r8, r5
                    andi r8, 0xff00
                    ldi r6, data.spr_blck
                    andi r5, 0xff
                    jz .drw_gridL1
                    mov r7, r5
                    subi r7, 128
                    muli r7, 128
                    add r6, r7
                    cmpi r5, 128
                    jge .drw_gridL0
                    subi r5, 1
                    add r5, r8
                    stm r5, r4
                    ldi r6, data.spr_expl
.drw_gridL0:        drw r2, r3, r6
.drw_gridL1:        subi r1, 1
                    jn .drw_gridZ
                    subi r2, 16
                    jnn .drw_gridL
                    ldi r2, 304
.drw_gridL2:        subi r3, 16
                    jnn .drw_gridL
.drw_gridZ:         ret

drw_plyrs:          ;push r0
                    ;push r1
                    ;push r2
                    ;push r3
                    ldi r0, 0
                    call drw_plyr
                    ;pop r3
                    ;pop r2
                    ;pop r1
                    ;pop r0
                    ret

drw_objs:           ldm r0, data.num_bombs
.drw_objsBbL:       subi r0, 1
                    jn .drw_objsA
.drw_objsBbs:       mov r1, r0
                    muli r1, 6
                    addi r1, data.bombs
                    ldm r2, r1
                    addi r1, 2
                    ldm r1, r1
                    subi r2, 8
                    subi r1, 8
                    drw r2, r1, data.spr_bomb
                    jmp .drw_objsBbL
.drw_objsA:         ret
                    spr 0x0201              ; debug markers for collision detection
                    ldm r0, debug.x0
                    ldm r1, debug.y0
                    drw r0, r1, debug.spr
                    ldm r0, debug.x1
                    ldm r1, debug.y1
                    drw r0, r1, debug.spr
                    ret

; drw_plyr
; r0: player index
drw_plyr:           shl r0, 2   ; player index to offset in pos_plyrs
                    addi r0, data.pos_plyrs
                    ldm r1, r0  ; r1 <= player x 
                    addi r0, 2
                    ldm r2, r0  ; r2 <= player y
                    spr 0x1008
                    ldm r3, data.ptr_spr_plyr
                    subi r1, 8
                    subi r2, 8
                    drw r1, r2, r3
                    tsti r2, 8  ; Only redraw tiles if player in top half of cell
                    jnz .drw_plyrZ
                    addi r1, 3  ; Use collision offsets for this
                    andi r1, 0xfff0
                    push r1
                    addi r2, 16
                    andi r2, 0xfff0
                    push r2
                    mov r0, r1
                    mov r1, r2
                    call map_contents_at    ; If there is a block here, redraw
                    mov r4, r0
                    pop r3
                    pop r2
                    cmpi r0, 0
                    jz .drw_plyrT0
                    subi r4, 128
                    muli r4, 128
                    addi r4, data.spr_blck
                    drw r2, r3, r4
.drw_plyrT0:        addi r2, 16             ; Now check to the right
                    andi r2, 0xfff0
                    mov r0, r2
                    mov r1, r3
                    call map_contents_at    ; If there is a block here, redraw
                    cmpi r0, 0
                    jz .drw_plyrZ
                    subi r0, 128
                    muli r0, 128
                    addi r0, data.spr_blck
                    drw r2, r3, r0
.drw_plyrZ:         ret

debug.x0:   dw 0
debug.y0:   dw 0
debug.x1:   dw 0
debug.y1:   dw 0
debug.spr:  dw 0xffff

data.anikey:        dw 0
data.sp:            dw 0

data.ptr_spr_plyr:  dw data.spr_plyr

data.pos_plyrs:     dw 24, 24

data.speed_plyrs:   dw 1
data.vec_plyrs:     dw 0, 0
; Use Up=0, Down=1, Left=2, Right=3. 
data.dir_plyrs:     dw 1

data.move_lut:      dw -4,-3,  3,-3,
                    dw -4, 2,  3, 2,
                    dw -4,-3, -4, 2,
                    dw  3,-3,  3, 2,

data.num_bombs:     dw 0
; Format: x : word, y : word, timer: word
data.bombs:         dw 0,0,0,  0,0,0,  0,0,0,  0,0,0,
                    dw 0,0,0,  0,0,0,  0,0,0,  0,0,0,

data.level:         db 0x80,0x80,0x80,0x80,0x80,0x80,0x80,0x80,0x80,0x80
                    db 0x80,0x80,0x80,0x80,0x80,0x80,0x80,0x80,0x80,0x80
                    db 0x80,0x00,0x00,0x00,0x81,0x81,0x81,0x81,0x00,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x80
                    db 0x80,0x80,0x00,0x80,0x81,0x80,0x00,0x80,0x00,0x80
                    db 0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x80
                    db 0x80,0x81,0x81,0x00,0x81,0x00,0x00,0x00,0x00,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x80
                    db 0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x00
                    db 0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x80
                    db 0x80,0x00,0x00,0x00,0x00,0x00,0x00,0x81,0x81,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x81,0x80
                    db 0x80,0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x81,0x80
                    db 0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x80
                    db 0x80,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x80
                    db 0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x00
                    db 0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x80
                    db 0x80,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x80
                    db 0x80,0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x80
                    db 0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x80
                    db 0x80,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x80
                    db 0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x00
                    db 0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x80,0x80
                    db 0x80,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x81,0x81,0x81,0x80
                    db 0x80,0x80,0x80,0x80,0x80,0x80,0x80,0x80,0x80,0x80
                    db 0x80,0x80,0x80,0x80,0x80,0x80,0x80,0x80,0x80,0x80
