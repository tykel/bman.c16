;------------------------------------------------------------------------------
; bman.asm
; A Bomberman (R) clone for Chip16
; Copyright 2024 Tim Kelsall.
;------------------------------------------------------------------------------

init:               nop

game_loop:          call handle_pad
                    call move_plyrs
                    cls
                    bgc 0x5
                    call drw_grid
                    call drw_plyrs
                    call drw_objs
                    vblnk
                    jmp game_loop

handle_pad:         ldm r0, 0xfff0
                    ldi r1, data.vec_plyrs
                    ldi r4, data.spr_plyr
                    ldi rf, 0
                    stm rf, r1
                    addi r1, 2
                    stm rf, r1
                    ldi r1, data.vec_plyrs
                    cmpi r0, 0
                    jz .handle_padZ
.handle_pad0:       ldm r2, data.speed_plyrs
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
.handle_padZ:       ret

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
                    ldm r4, r4
                    andi r4, 0xff
                    jz .drw_gridL1
                    drw r2, r3, data.spr_blck
.drw_gridL1:        subi r1, 1
                    jn .drw_gridZ
                    subi r2, 16
                    jnn .drw_gridL
                    ldi r2, 304
                    subi r3, 16
                    jnn .drw_gridL
.drw_gridZ:         ret

drw_plyrs:          ldi r0, 0
                    call drw_plyr
                    ret

drw_objs:           spr 0x0201
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
                    drw r1, r2, r3
                    ret

debug.x0:   dw 0
debug.y0:   dw 0
debug.x1:   dw 0
debug.y1:   dw 0
debug.spr:  dw 0xffff

data.sp:            dw 0

data.ptr_spr_plyr:  dw data.spr_plyr

data.pos_plyrs:     dw 16, 16

data.speed_plyrs:   dw 1
data.vec_plyrs:     dw 0, 0
; Use Up=0, Down=1, Left=2, Right=3. 
data.dir_plyrs:     dw 1

data.move_lut:      dw 2,0,  13,0,
                    dw 2,13, 13,13,
                    dw 0,0,  0, 13,
                    dw 13,0, 13,13,

data.spr_blck:      db 0x02, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x20
                    db 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22
                    db 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22
                    db 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22
                    db 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22
                    db 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22
                    db 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22
                    db 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22
                    db 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22
                    db 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22
                    db 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22
                    db 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22
                    db 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22
                    db 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22
                    db 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22
                    db 0x02, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x20

data.level:         db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
                    db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
                    db 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff
                    db 0xff, 0x00, 0x00, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00
                    db 0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0xff
                    db 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff
                    db 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff
                    db 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff
                    db 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff
                    db 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff
                    db 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff
                    db 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff
                    db 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff
                    db 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff
                    db 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff
                    db 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff
                    db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
                    db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
