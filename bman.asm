;------------------------------------------------------------------------------
; bman.asm
; A Bomberman (R) clone for Chip16
; Copyright 2024 Tim Kelsall.
;------------------------------------------------------------------------------

init:               nop

game_loop:          ;call handle_pad
                    cls
                    bgc 0x3
                    call drw_grid
                    call drw_plyrs
                    call drw_objs
                    vblnk
                    jmp game_loop

drw_grid:           ret
drw_plyrs:          ret
drw_objs:           ret
