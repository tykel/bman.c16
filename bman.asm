;------------------------------------------------------------------------------
; bman.asm
; A Bomberman (R) clone for Chip16
; Copyright 2024 Tim Kelsall.
;------------------------------------------------------------------------------

ID_FLAME_CENTER         equ 0x00
ID_FLAME_HORIZ_MID      equ 0x20
ID_FLAME_HORIZ_LEFT     equ 0x40
ID_FLAME_HORIZ_RIGHT    equ 0x60
ID_FLAME_VERT_MID       equ 0x80
ID_FLAME_VERT_TOP       equ 0xa0
ID_FLAME_VERT_BOTTOM    equ 0xc0
ID_TILE                 equ 0xe0
ID_TILE_0               equ 0xe0
ID_TILE_1               equ 0xe1
ID_PWRUP                equ 0xe8
ID_PWRUP_FLAMES_PLUS    equ 0xe8
ID_PWRUP_BOMBS_PLUS     equ 0xe9
ID_BOMB                 equ 0xf0

TIMER_FLAME             equ 0x1f

;------------------------------------------------------------------------------
; @@@ Entry point for the ROM [0x0000]
;------------------------------------------------------------------------------
menu:               jmp init
menu_loop:          call handle_menu
                    ldm r0, data.start_game
                    cmpi r0, 1
                    jz init
                    cls
                    bgc 0
                    call drw_menu
                    vblnk
                    jmp menu_loop

;------------------------------------------------------------------------------
clearmem:           ldi r0, 0
                    stm r0, data.bombs_list
.clearmem1:         ldi r1, data.flames_list
                    ldi r2, 32
                    ldi r3, .clearmem2
                    jmp .clearmem_zero
.clearmem2:         ldi r1, data.dtiles_list
                    ldi r2, 32
                    ldi r3, .clearmem3
                    jmp .clearmem_zero
.clearmem3:         ret
;--------
.clearmem_zero:     subi r2, 2
                    jn .clearmem_zeroZ
                    add r1, r2, r4
                    stm r0, r4
                    jmp .clearmem_zero
.clearmem_zeroZ:    jmp r3

;------------------------------------------------------------------------------
init:               call clearmem
                    pal data.palette
                    ldi r0, 0
                    stm r0, data.ko_plyrs
                    ldi r0, 24
                    ldi r1, data.pos_plyrs
                    stm r0, r1
                    addi r1, 2
                    stm r0, r1

game_loop:          ldm r0, data.ko_plyrs
                    cmpi r0, 0
                    jnz .game_loopKO
                    call handle_pad
                    call move_plyrs
                    call handle_bombs
                    call handle_flames
                    call handle_dtiles
                    cls
                    bgc 8
                    call drw_grid
                    call drw_plyrs
                    call drw_objs
                    call drw_hud
                    vblnk
                    jmp game_loop
.game_loopKO:       bgc 3
                    vblnk
                    vblnk
                    vblnk
                    vblnk
                    vblnk
                    vblnk
                    vblnk
                    vblnk
                    vblnk
                    vblnk
                    bgc 8
                    vblnk
                    vblnk
                    vblnk
                    vblnk
                    vblnk
                    vblnk
                    vblnk
                    vblnk
                    vblnk
                    vblnk
                    jmp init
                    jmp .game_loopKO

;------------------------------------------------------------------------------
; handle_menu()
;   Handle controller and menu logic.
;------------------------------------------------------------------------------
handle_menu:        ldm r0, 0xfff0
                    shr r0, 5
                    stm r0, data.start_game
                    ret

;------------------------------------------------------------------------------
; handle_flames()
;   Check for if cell under player has a flame. Updates ko_plyrs if so.
;------------------------------------------------------------------------------
handle_flames:      ldi r2, data.pos_plyrs
                    ldm r0, r2
                    addi r2, 2
                    ldm r1, r2
                    call map_contents_at
                    cmpi r0, 0
                    jz .handle_flamesZ
                    cmpi r0, ID_TILE
                    jge .handle_flamesZ
                    ldi r0, 1
.handle_flamesKO:   stm r0, data.ko_plyrs
.handle_flamesZ:    ret

;------------------------------------------------------------------------------
; handle_dtiles()
;   Decrement timers for all destr. tiles in list, and remove when reached 0.
;------------------------------------------------------------------------------
handle_dtiles:      ldi r0, data.dtiles_list
                    ldi r1, 0
.handle_dtilesL:    call list_256x8_iter
                    cmpi r1, 0
                    jz .handle_dtilesZ
.zz:                push r1
                    addi r1, 4
                    ldm r2, r1
                    subi r2, 1
                    stm r2, r1
                    pop r1
                    cmpi r2, 0
.yy:                jz .handle_dtilesE
                    tsti r2, 15
                    jz .handle_dtilesD
                    jmp .handle_dtilesL
.handle_dtilesE:    call list_256x8_erase
                    push r0
                    ldm r0, r1
                    divi r0, 16
                    push r1
                    addi r1, 2
                    ldm r1, r1
                    divi r1, 16
                    call level_remove
                    pop r1
                    pop r0
                    jmp .handle_dtilesL
.handle_dtilesD:    push r0
                    ldm r0, r1
                    divi r0, 16
                    push r1
                    addi r1, 2
                    ldm r1, r1
                    divi r1, 16
                    call level_inctile
                    pop r1
                    pop r0
                    jmp .handle_dtilesL
.handle_dtilesZ:    ret

;------------------------------------------------------------------------------
; list_insert()
;   Insert passed value into first empty element of list that is 0.
;
; IN:
;   r0: list addr.
;   r1: value
;------------------------------------------------------------------------------
list_insert:        push r2
                    push r3
                    push r1
                    ldi r1, 0x8000
                    mov r3, r0
                    addi r3, 32
                    ldm r2, r0
.list_insertL:      tst r2, r1
                    jz .list_insertZ
                    shr r1, 1
                    subi r3, 2
                    jmp .list_insertL
.list_insertZ:      or r2, r1
                    stm r2, r0
                    pop r1
                    stm r1, r3
                    pop r3
                    pop r2
                    ret

;------------------------------------------------------------------------------
; list_XXX()
; list_256x8_XXX()
;
;   Work with array-lists.
;   Supports insertion, removal, and traversal.
;
;   list_insert:    add given item to list
;   list_next:      reserve and return next available list entry
;   list_last:      pop last item from list
;   list_iter:      get next item list, using iterator
;   list_erase:     set list entry as empty
;
;   To iterate a 256x8 list and maybe erase an entry:
;       ldi r0, my_list
;       push r1
;       ldi r1, my_list_array
;   @:  call list_256x8_iter
;       ldm r2, r1
;       cmpi r2, 0
;       jnz @
;       call list_256x8_erase
;       ret
;       
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; list_256x8_erase()
;   Set list entry as empty.
;
; IN:
;   r0: list addr.
;   r1: list entry addr.
;------------------------------------------------------------------------------
list_256x8_erase:   push r1
                    push r2
                    push r3
                    push r4
                    sub r1, r0
                    subi r1, 32
                    divi r1, 8      ; entry id
                    ldi r2, 16
                    div r1, r2, r3  ; entry bitmask word
                    rem r1, r2, r4  ; entry bitmask word bit
                    ldi r2, 1
                    shl r2, r4      ; entry bitmask word bitmask
                    not r2          ; inverted to clear with bitwise AND
                    muli r3, 2
                    add r0, r3, r3  ; entyr bitmask word addr
                    ldm r4, r3
                    and r4, r2      ; clear bit
                    stm r4, r3      ; and store
                    pop r4
                    pop r3
                    pop r2
                    pop r1
                    ret

;------------------------------------------------------------------------------
; list_256x8_iter()
;   Return next non-empty list address, without modifying anything.
;   Return 0 if list is empty.
;
; IN:
;   r0: list addr.
;   r1: list entry addr. (use address of list entry 0 on first call)
; OUT:
;   r1: list entry addr.
;------------------------------------------------------------------------------
list_256x8_iter:    push r0
                    push r2
                    push r3
                    push r4
                    push r5
                    cmpi r1, 0
                    jnz .list_256x8_iterLL
                    mov r3, r0
                    addi r3, 2040                       ; r1=0, start from end of list
                    addi r3, 32                         ; account for bitmask
                    ldi r4, 0x8000
                    addi r0, 30
                    ldm r2, r0
                    jmp .list_256x8_iterA
.list_256x8_iterLL: ldm r4, data.list_256x8_iter.mask   ; r1!=0, resume from next pos
                    ldm r0, data.list_256x8_iter.mask_addr
                    ldm r2, r0
                    mov r3, r1
                    jmp .list_256x8_iterLZ
.list_256x8_iterA:  cmpi r2, 0
                    jz .list_256x8_iterZW
.list_256x8_iterL:  tst r2, r4
                    jnz .list_256x8_iterF
.list_256x8_iterLZ: shr r4, 1
                    jnz .list_256x8_iterLF
.list_256x8_iterZW: ldi r4, 0x8000
                    subi r0, 2
                    cmp r5, r0
                    jl .list_256x8_iterZE
.list_256x8_iterLF: subi r3, 8
                    jmp .list_256x8_iterL
.list_256x8_iterZE: ldi r1, 0
                    jmp .list_256x8_iterZ
.list_256x8_iterF:  mov r1, r3
.list_256x8_iterZ:  stm r0, data.list_256x8_iter.mask_addr
                    stm r4, data.list_256x8_iter.mask
                    pop r5
                    pop r4
                    pop r3
                    pop r2
                    pop r0
                    ret
data.list_256x8_iter.mask: dw 0
data.list_256x8_iter.mask_addr: dw 0

;------------------------------------------------------------------------------
; list_256x8_next()
;   Return next available list address.
;   Will mark the corresponding location as non-empty.
;
; IN:
;   r0: list addr.
; OUT:
;   r0: list entry addr.
;------------------------------------------------------------------------------
list_256x8_next:    push r2
                    push r3
                    push r1
list_256x8_nextLL:  ldi r1, 0x8000
                    mov r3, r0
                    addi r0, 30
                    addi r3, 2040
                    addi r3, 32
                    ldm r2, r0
.list_256x8_nextL:  tst r2, r1
                    jz .list_256x8_nextZ
                    shr r1, 1
                    jnz .list_256x8_nextLF
                    ldi r1, 0x8000
                    subi r0, 2
.list_256x8_nextLF: subi r3, 8
                    jmp .list_256x8_nextL
.list_256x8_nextZ:  or r2, r1
                    stm r2, r0
                    mov r0, r3
                    pop r1
                    pop r3
                    pop r2
                    ret

;------------------------------------------------------------------------------
; list_last()
;   Return address of last element in list.
;   That list entry will be marked as empty before return. (metadata modified)
;   Returns 0 if there are no non-empty entries in list. 
; IN:
;   r0: list addr.
; OUT:
;   r0: list entry addr.
;------------------------------------------------------------------------------
list_last:          push r1
                    push r2
                    push r3
                    ldm r1, r0
                    mov r2, r0
                    stm r0, data.list_last.r0
                    ldi r0, 0
                    tsti r1, 0xffff
                    jz .list_lastZ
                    ldi r3, 0x8000
                    addi r2, 32
.list_lastL:        tst r1, r3
                    jnz .list_lastZF
                    shr r3, 1
                    subi r2, 2
                    jmp .list_lastL
.list_lastZF:       not r3
                    and r1, r3
                    ldm r0, data.list_last.r0
                    stm r1, r0
                    ldm r0, r2
.list_lastZ:        pop r3
                    pop r2
                    pop r1
                    ret
data.list_last.r0:  dw 0

;------------------------------------------------------------------------------
; list_256x8_last()
;   Same but for 256-entry list of 8B structs.
;------------------------------------------------------------------------------
list_256x8_last:    push r1
                    push r2
                    push r3
                    ldm r1, r0
                    mov r2, r0
                    addi r0, 30
                    stm r0, data.list_256x8_last.r0
                    ldi r0, 0
                    tsti r1, 0xffff
                    jz .list_256x8_lastZ
                    ldi r3, 0x8000
                    addi r2, 2040
                    addi r2, 32
.list_256x8_lastL:  tst r1, r3
                    jnz .list_256x8_lastZF
                    shr r3, 1
                    jnz .list_256x8_lastLF
                    subi r0, 2
                    ldi r3, 0x8000
.list_256x8_lastLF: subi r2, 8
                    jmp .list_256x8_lastL
.list_256x8_lastZF: not r3
                    and r1, r3
                    ldm r0, data.list_256x8_last.r0
                    stm r1, r0
                    ldm r0, r2
.list_256x8_lastZ:  pop r3
                    pop r2
                    pop r1
                    ret

data.list_256x8_last.r0:  dw 0

;------------------------------------------------------------------------------
; handle_bombs()
;
; - First, for each bomb with timer-1==0, add bomb to expl_list.
; - Then, for each bomb in expl_list, call expl_bomb().
; - In expl_bomb() calls, for any bomb flames reach, insert bomb into expl_list.
;------------------------------------------------------------------------------
handle_bombs:       ldi r0, data.bombs
                    mov r1, r0
                    addi r1, 128
.handle_bombsL:     subi r1, 8
                    cmp r1, r0
                    jl .handle_bombsXL
                    mov r3, r1
                    addi r3, 4      ; offsetof(bomb.timer)
                    ldm r4, r3
                    cmpi r4, 0      ; bomb.timer == 0 already -> skip
                    jz .handle_bombsL
                    subi r4, 1      ; bomb.timer dec to 0 -> explode
                    stm r4, r3
                    jnz .handle_bombsL
                    push r0
                    ldi r0, data.expl_list
                    push r1
                    call list_insert
                    pop r1
                    pop r0
                    jmp .handle_bombsL
                    ; iterate expl_list
.handle_bombsXL:    ldi r0, data.expl_list
                    call list_last      ; => r0 = &bomb
                    cmpi r0, 0
                    jz .handle_bombsZ
.handle_bombsXLX:   addi r0, 6      ; offsetof(bomb.flags)
                    ldm r1, r0
                    andi r1, 3
                    shl r1, 1
                    addi r1, data.bombs_plyrs   ; offset to this player's bomb count
                    ldm r2, r1
                    addi r2, 1      ; increment it as a bomb of theirs just exploded
                    stm r2, r1      ; store it
                    subi r0, 6
                    push r0
                    push r1
                    mov r1, r0
                    ldm r0, r0          ; bomb.x
                    addi r1, 2
                    ldm r1, r1          ; bomb.y
                    call expl_bomb
                    pop r1
                    pop r0
                    jmp .handle_bombsXL
.handle_bombsZ:     ret

;------------------------------------------------------------------------------
; add_expl_bomb()
;   Add bomb at given location to the "exploding" list.
;
; IN:
;   r0: bomb.x
;   r1: bomb.y
;   r2: bomb.id
;------------------------------------------------------------------------------
add_expl_bomb:  andi r2, 0x0f
                muli r2, 8
                addi r2, data.bombs
                addi r2, 4
                ldi r3, 0                   ; Set bomb timer to 0
                stm r3, r2
                addi r2, 2
                ldm r3, r2
                subi r2, 6
                mov r1, r2
                ldi r0, data.expl_list
                call list_insert
                ret

;------------------------------------------------------------------------------
; expl_bomb()
;
; IN:
;   r0: bomb.x
;   r1: bomb.y
;------------------------------------------------------------------------------
expl_bomb:          ldm ra, data.pow_plyrs      ; Convert power to tile offs.
                    shl ra, 4

                    push r0
                    shr r0, 4
                    push r1
                    shr r1, 4
                    call level_remove
                    pop r1
                    pop r0

                    push r0                     ; Start
                    push r1
                    ldi r2, ID_FLAME_CENTER
                    call map_put_flame          ; Cell where player is located.
                    pop r1                      ; Assume nothing else there,
                    pop r0                      ; since a bomb was placed.

.expl_bombLeft:     ldi rc, 0                   ; Scan left, until solid...
.expl_bombLeftL:    addi rc, 16                 ; ...block or power extent...
                    ldi r2, ID_FLAME_HORIZ_MID
                    cmp rc, ra                  ; ...reached.
                    jg .expl_bombRight
                    jl .expl_bombLeftM
                    ldi r2, ID_FLAME_HORIZ_LEFT
.expl_bombLeftM:    push r0
                    push r1
                    sub r0, rc
                    call map_put_flame
                    pop r1
                    pop r0
                    cmpi r2, ID_TILE
                    jl .expl_bombLeftL          ; empty or flame
                    cmpi r2, ID_BOMB
                    jl .expl_bombLeftE          ; tile
                    pushall                     ; bomb
                    call add_expl_bomb
                    popall
                    jmp .expl_bombLeftL
.expl_bombLeftE:    cmpi rc, 16
                    jle .expl_bombRight
                    cmpi r2, ID_TILE
                    jnz .expl_bombRight
                    push r0
                    push r1
                    sub r0, rc
                    addi r0, 16
                    ldi r2, ID_FLAME_HORIZ_LEFT
                    call map_put_flame
                    pop r1
                    pop r0

.expl_bombRight:    ldi rc, 0                   ; Ditto, right...
.expl_bombRightL:   addi rc, 16
                    ldi r2, ID_FLAME_HORIZ_MID
                    cmp rc, ra
                    jg .expl_bombUp
                    jl .expl_bombRightM
                    ldi r2, ID_FLAME_HORIZ_RIGHT
.expl_bombRightM:   push r0
                    push r1
                    add r0, rc
                    call map_put_flame
                    pop r1
                    pop r0
                    cmpi r2, ID_TILE
                    jl .expl_bombRightL
                    cmpi r2, ID_BOMB
                    jl .expl_bombRightE
                    pushall
                    call add_expl_bomb
                    popall
                    jmp .expl_bombRightL
.expl_bombRightE:   cmpi rc, 16
                    jle .expl_bombUp
                    cmpi r2, ID_TILE
                    jnz .expl_bombUp
                    push r0
                    push r1
                    add r0, rc
                    subi r0, 16
                    ldi r2, ID_FLAME_HORIZ_RIGHT
                    call map_put_flame
                    pop r1
                    pop r0

.expl_bombUp:       ldi rc, 0                   ; Ditto, up...
.expl_bombUpL:      addi rc, 16
                    ldi r2, ID_FLAME_VERT_MID
                    cmp rc, ra
                    jg .expl_bombDown
                    jl .expl_bombUpM
                    ldi r2, ID_FLAME_VERT_TOP
.expl_bombUpM:      push r0
                    push r1
                    sub r1, rc
                    call map_put_flame
                    pop r1
                    pop r0
                    cmpi r2, ID_TILE
                    jl .expl_bombUpL
                    cmpi r2, ID_BOMB
                    jl .expl_bombUpE
                    pushall
                    call add_expl_bomb
                    popall
                    jmp .expl_bombUpL
.expl_bombUpE:      cmpi rc, 16
                    jle .expl_bombDown
                    cmpi r2, ID_TILE
                    jnz .expl_bombDown
                    push r0
                    push r1
                    sub r1, rc
                    addi r1, 16
                    ldi r2, ID_FLAME_VERT_TOP
                    call map_put_flame
                    pop r1
                    pop r0

.expl_bombDown:     ldi rc, 0                   ; Ditto, down...
.expl_bombDownL:    addi rc, 16
                    ldi r2, ID_FLAME_VERT_MID
                    cmp rc, ra
                    jg .expl_bombSnd
                    jl .expl_bombDownM
                    ldi r2, ID_FLAME_VERT_BOTTOM
.expl_bombDownM:    push r0
                    push r1
                    add r1, rc
                    call map_put_flame
                    pop r1
                    pop r0
                    cmpi r2, ID_TILE
                    jl .expl_bombDownL
                    cmpi r2, ID_BOMB
                    jl .expl_bombDownE
                    pushall
                    call add_expl_bomb
                    popall
                    jmp .expl_bombDownL
.expl_bombDownE:    cmpi rc, 16
                    jle .expl_bombSnd
                    cmpi r2, ID_TILE
                    jnz .expl_bombSnd
                    push r0
                    push r1
                    add r1, rc
                    subi r1, 16
                    ldi r2, ID_FLAME_VERT_BOTTOM
                    call map_put_flame
                    pop r1
                    pop r0

.expl_bombSnd:      sng 0x30, 0xf3f3            ; Play the explosion sound.
                    ldi r0, 2000
                    snp r0, 200
                    ret

;------------------------------------------------------------------------------
; map_put_flame()
;
; IN:
;   r0: pos.x
;   r1: pos.y
;   r2: flame id
;
; OUT:
;   r2: the (new) contents of the level map at pos.(x, y)
;------------------------------------------------------------------------------
map_put_flame:      stm r0, data.map_put_flame.r0
                    stm r1, data.map_put_flame.r1
                    stm r2, data.map_put_flame.r2
                    push r3
                    mov r3, r2
                    ldi r2, ID_TILE
                    cmpi r0, 0
                    jl .map_put_flameZ
                    cmpi r0, 304
                    jg .map_put_flameZ
                    cmpi r1, 0
                    jl .map_put_flameZ
                    cmpi r1, 304
                    jg .map_put_flameZ
                    shr r1, 4
                    muli r1, 20
                    shr r0, 4
                    add r0, r1
                    addi r0, data.level
                    ldm r1, r0
                    mov r2, r1
                    andi r2, 0xff
                    cmpi r2, ID_TILE
                    jz .map_put_flameZ          ; if tile is solid, skip
                    cmpi r2, ID_TILE_1
                    jnz .map_put_flameC         ; if tile is destr., replace it
                    mov r3, r2
                    addi r3, 1
                    andi r1, 0xff00
                    add r1, r3
                    stm r1, r0
                    ldi r0, data.dtiles_list
                    call list_256x8_next        ; get a dtiles list entry to populate
.z:                 ldm r1, data.map_put_flame.r0
                    stm r1, r0
                    addi r0, 2
                    ldm r1, data.map_put_flame.r1
                    stm r1, r0
                    addi r0, 2
                    ldi r1, 60
.zzz:               stm r1, r0
                    jmp .map_put_flameZ
.map_put_flameC:    cmpi r2, ID_FLAME_HORIZ_MID ; do not replace a center flame
                    jge .map_put_flameD
                    cmpi r2, 0
                    jg .map_put_flameZ          ; do not replace an existing flame
.map_put_flameD:    andi r1, 0xff00
                    add r1, r3                  ; use correct flame id
                    addi r1, TIMER_FLAME        ; add a 31-frame flame
.map_put_flameW:    stm r1, r0
.map_put_flameZ:    pop r3
                    ret
data.map_put_flame.r0:  dw 0
data.map_put_flame.r1:  dw 0
data.map_put_flame.r2:  dw 0

;------------------------------------------------------------------------------
; handle_pad()
;------------------------------------------------------------------------------
handle_pad:         ldm r0, 0xfff0
                    ldi r1, data.vec_plyrs
                    ldi r4, data.spr_plyr
                    ldi rf, 0
                    stm rf, r1
                    addi r1, 2
                    stm rf, r1
                    ldi r1, data.vec_plyrs
                    cmpi r0, 0
                    jnz .handle_pad0
                    ldi r0, 0
                    stm r0, data.anikey
                    jmp .handle_padZZ
.handle_pad0:       ldm r9, data.anikey
                    subi r9, 1
                    jnn .handle_pad1
                    ldi r9, 27
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
                    jmp .handle_padA
.handle_padDn:      tsti r0, 2
                    jz .handle_padLf
                    stm r4, data.ptr_spr_plyr
                    addi r1, 2
                    stm r2, r1
                    ldi r2, 1
                    stm r2, data.dir_plyrs
                    jmp .handle_padA
.handle_padLf:      tsti r0, 4
                    jz .handle_padRt
                    addi r4, 256
                    stm r4, data.ptr_spr_plyr
                    neg r3, r2
                    stm r3, r1
                    ldi r2, 2
                    stm r2, data.dir_plyrs
                    jmp .handle_padA
.handle_padRt:      tsti r0, 8
                    jz .handle_padA
                    addi r4, 384
                    stm r4, data.ptr_spr_plyr
                    stm r2, r1
                    ldi r2, 3
                    stm r2, data.dir_plyrs
                    jmp .handle_padA
.handle_padA:       tsti r0, 64 ; A
                    jz .handle_padZZ
                    ldm r0, data.btn_a_dn
                    cmpi r0, 0
                    jz .handle_padZZ
                    
                    ldi r1, data.pos_plyrs
                    ldm r5, r1
                    andi r5, 0xfff0
                    addi r5, 8
                    shr r5, 4
                    addi r1, 2
                    ldm r6, r1
                    andi r6, 0xfff0
                    addi r6, 8
                    shr r6, 4
                    muli r6, 20
                    add r5, r6
                    addi r5, data.level
                    ldm r6, r5
                    tsti r6, 0xff
                    jnz .handle_padZZ
                    
                    ldm r1, data.bombs_plyrs
                    cmpi r1, 0
                    jz .handle_padZZ
                    subi r1, 1
                    stm r1, data.bombs_plyrs

.handle_padAb:      ldi r2, data.bombs
                    mov r3, r2
                    addi r3, 120                ; 15 * 8 => 16th bomb offset
.handle_padAc:      addi r3, 4                  ; offs(bomb.timer) = 4
                    ldm r4, r3
                    subi r3, 4
                    cmpi r4, 0                  ; bomb.timer == 0 ? explode!
                    jz .handle_padAd
                    subi r3, 8                  ; otherwise, keep iterating
                    cmp r3, r2                  ; ( sizeof(bomb) == 8 )
                    jge .handle_padAc
.handle_padAd:      mov rc, r3                  ; rc <= bomb index
                    subi rc, data.bombs         ; i.e. (&bomb[i] - &bomb[0])/sizeof(bomb)
                    shr rc, 3
                    ldi r1, data.pos_plyrs
                    ldm r5, r1
                    andi r5, 0xfff0
                    addi r5, 8
                    mov ra, r5
                    shr ra, 4
                    stm r5, r3
                    addi r1, 2
                    addi r3, 2
                    ldm r5, r1
                    andi r5, 0xfff0
                    addi r5, 8
                    mov rb, r5
                    shr rb, 4
                    stm r5, r3
                    addi r3, 2
                    ldi r1, 75  ; Set bomb with 75 frame timer
                    stm r1, r3
                    addi r3, 2
                    ldm r5, data.pow_plyrs
                    shl r5, 2   ; bomb.flags.power in bits 2..7
                    stm r5, r3  ; Set bomb power to player power
                    muli rb, 20
                    add ra, rb
                    addi ra, data.level
                    ldm rb, ra
                    andi rb, 0xff00
                    addi rb, 0xf0
                    add rb, rc
.handle_padDBb:     stm rb, ra
.handle_padZZ:      ldm r0, 0xfff0
                    shr r0, 6
                    not r0
                    andi r0, 1
                    stm r0, data.btn_a_dn
                    ret

;------------------------------------------------------------------------------
; move_plyrs()
;
; IN:
;   r0: pos.x
;   r1: pos.y
;------------------------------------------------------------------------------
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
                    cmpi r3, ID_BOMB
                    jge .move_plyrs11
                    cmpi r3, ID_PWRUP
                    jge .move_plyrs1
                    cmpi r3, ID_TILE
                    jge .move_plyrsZ
.move_plyrs1:       push r2
                    push r3
                    mov r2, r3
                    call handle_pwrup
                    pop r3
                    pop r2
.move_plyrs11:      addi r2, 2
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
                    cmpi r0, ID_PWRUP
                    jge .move_plyrs2
                    cmpi r0, ID_TILE
                    jge .move_plyrsZ
.move_plyrs2:       ldi r2, data.pos_plyrs
                    stm r8, r2  ; pos.x = x
                    addi r2, 2
                    stm r9, r2  ; pos.y = y
.move_plyrsZ:       ret

;------------------------------------------------------------------------------
; handle_pwrup()
;
; IN:
;   r0: x
;   r1: y
;   r2: map item ID
;------------------------------------------------------------------------------
handle_pwrup:       ldm r0, debug.x0
                    ldm r1, debug.y0
                    shr r1, 4
                    muli r1, 20
                    shr r0, 4
                    add r0, r1
                    addi r0, data.level
                    ldm r1, r0
                    andi r1, 0xff00
                    stm r1, r0
                    cmpi r2, ID_PWRUP_FLAMES_PLUS
                    jnz .handle_pwrupA
                    ldm r0, data.pow_plyrs
                    addi r0, 1
                    stm r0, data.pow_plyrs
                    jmp .handle_pwrupZ
.handle_pwrupA:     cmpi r2, ID_PWRUP_BOMBS_PLUS
                    jnz .handle_pwrupZ
                    ldm r0, data.bombs_plyrs
                    addi r0, 1
                    stm r0, data.bombs_plyrs
.handle_pwrupZ:     ret

;------------------------------------------------------------------------------
; map_put_at()
;
; IN:
;   r0: x
;   r1: y
;   r2: val (low byte!)
;
; Write `val` to level array for pos (x,y).
;------------------------------------------------------------------------------
map_put_at:         shr r0, 4   ; tile.x = pos.x / 16
                    shr r1, 4   ; tile.y = pos.y / 16
                    muli r1, 20
                    add r0, r1
                    addi r0, data.level ; tile_addr = (tile.y*20) * tile.x + data.level
                    ldm r1, r0
                    andi r1, 0xff00
                    add r1, r2
                    stm r1, r0
                    ret

;------------------------------------------------------------------------------
; map_contents_at()
;
; IN:
;   r0: x
;   r1: y
; OUT:
;   r0: val (low byte!)
;
; Return level array byte value at pos (x,y).
;------------------------------------------------------------------------------
map_contents_at:    shr r0, 4   ; tile.x = pos.x / 16
                    shr r1, 4   ; tile.y = pos.y / 16
                    muli r1, 20
                    add r0, r1
                    addi r0, data.level ; tile_addr = (tile.y*20) * tile.x + data.level
                    ldm r0, r0
                    andi r0, 0xff
                    ret

;------------------------------------------------------------------------------
; get_spr_bomb()
;   Get correct sprite for bomb id.
;
; IN:
;   r0: bomb.id
;
; OUT:
;   r0: sprite addr.
;------------------------------------------------------------------------------
get_spr_bomb:       muli r0, 8
                    addi r0, data.bombs
                    addi r0, 4
                    ldm r0, r0
                    divi r0, 38             ; bomb.timer => [0,1] normal/red
                    muli r0, 384
                    push r1
                    ldm r1, data.anikey
                    divi r1, 10
                    muli r1, 128            ; anikey => frame [0..2] for anim.
                    add r0, r1
                    pop r1
                    addi r0, data.spr_bomb
                    ret

;------------------------------------------------------------------------------
; get_spr_flame()
;   Get correct sprite for flame id.
;
; IN:
;   r0: flame.id
;
; OUT:
;   r0: sprite addr.
;------------------------------------------------------------------------------
get_spr_flame:      muli r0, 8
                    addi r0, data.flames
                    addi r0, 4
                    push r1
                    mov r1, r0
                    ldm r0, r0
                    divi r0, 14             ; flame.timer => [0..2] expl.anim
                    muli r0, 896
                    addi r1, 2
                    ldm r1, r1
                    divi r1, 10
                    muli r1, 128            ; flame.flags => offset for correct spr
                    add r0, r1
                    pop r1
                    addi r0, data.spr_expl
                    ret

;------------------------------------------------------------------------------
; drw_grid()
;
; Draw level grid on-screen.
; Decrements flame timers.
;------------------------------------------------------------------------------
drw_grid:           spr 0x1008
                    ldi r0, data.level
                    ldi r1, 299             ; r1 <= tile counter
                    ldi r2, 304             ; r2 <= tile x in pixels
                    ldi r3, 224             ; r3 <= tile y in pixels
.drw_gridL:         add r0, r1, r4
                    ldm r5, r4
                    mov r8, r5
                    andi r8, 0xff00
                    ldi r6, data.spr_floor
                    andi r5, 0xff
                    jz .drw_gridL0
.drw_gridNF:        cmpi r5, ID_BOMB
                    jl .drw_gridLB
.drw_gridBb:        push r0
                    mov r0, r5
                    andi r0, 15
                    call get_spr_bomb
                    mov r6, r0
                    pop r0
                    jmp .drw_gridL0
.drw_gridLB:        cmpi r5, ID_PWRUP
                    jl .drw_gridLBlk
                    ldi r6, data.spr_pwrup_flame
                    andi r5, 7
                    muli r5, 128
                    add r6, r5
                    jmp .drw_gridL0
.drw_gridLBlk:      ldi r6, data.spr_blck
                    mov r7, r5              ; tile addr = (i - 128) * 128 + spr.blck
                    andi r7, 7
                    muli r7, 128
                    add r6, r7              ; r6 <= block tile sprite
                    cmpi r5, ID_TILE_0
                    jge .drw_gridL0
                    
.drw_gridLExp:      push r5
                    subi r5, 1              ; tile is expl. flame...
                    tsti r5, 0x1f
                    jnz .drw_gridLExp1
                    ldi r5, 0
.drw_gridLExp1:     add r5, r8              ; ... so decrement timer and...
                    stm r5, r4              ; ... write back to map.
                    pop r5
                    push r5
                    shr r5, 5               ; get flame id
                    muli r5, 128
                    ldi r6, data.spr_expl   ; r6 <= expl. flame sprite
                    add r6, r5              ; offset to correct flame segment
                    pop r5
                    andi r5, 0x1f
                    divi r5, 14
                    muli r5, 896
                    add r6, r5              ; r6 <= expl. flame sprite with anim.
.drw_gridL0:        drw r2, r3, r6
.drw_gridL1:        subi r1, 1
                    jn .drw_gridZ
                    subi r2, 16
                    jnn .drw_gridL
                    ldi r2, 304
.drw_gridL2:        subi r3, 16
                    jnn .drw_gridL
.drw_gridZ:         ret

;------------------------------------------------------------------------------
; drw_plyrs()
;------------------------------------------------------------------------------
drw_plyrs:          ldi r0, 0
                    call drw_plyr
                    ret

;------------------------------------------------------------------------------
; drw_objs()
;------------------------------------------------------------------------------
drw_objs:           ret
                    spr 0x0201              ; debug markers for collision detection
                    ldm r0, debug.x0
                    ldm r1, debug.y0
                    drw r0, r1, debug.spr
                    ldm r0, debug.x1
                    ldm r1, debug.y1
                    drw r0, r1, debug.spr
                    ret

;------------------------------------------------------------------------------
; drw_plyr()
;
; IN:
;   r0: player index
;------------------------------------------------------------------------------
drw_plyr:           shl r0, 2   ; player index to offset in pos_plyrs
                    addi r0, data.pos_plyrs
                    ldm r1, r0  ; r1 <= player x 
                    addi r0, 2
                    ldm r2, r0  ; r2 <= player y
                    spr 0x1008
                    subi r1, 8
                    subi r2, 8
                    drw r1, r2, data.spr_shdw
                    ldm r3, data.ptr_spr_plyr
                    ldm r4, data.anikey
                    divi r4, 7
                    muli r4, 512
                    add r3, r4
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
                    cmpi r0, ID_PWRUP
                    jl .drw_plyrDBL
                    addi r4, 128
.drw_plyrDBL:       subi r4, ID_TILE
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
                    cmpi r0, ID_PWRUP
                    jl .drw_plyrDBR
                    addi r0, 128
.drw_plyrDBR:       subi r0, ID_TILE
                    muli r0, 128
                    addi r0, data.spr_blck
                    drw r2, r3, r0
.drw_plyrZ:         ret

;------------------------------------------------------------------------------
; drw_hud()
;   Draw all interface on-screen.
;------------------------------------------------------------------------------
drw_hud:            ;call drw_debug_hud
                    ret

;------------------------------------------------------------------------------
; drw_debug_hud()
;   Draw debug-only information on-screen.
;------------------------------------------------------------------------------
drw_debug_hud:      ldm r0, data.pow_plyrs
                    ldi r1, data.str
                    call sub_r2bcd3
                    ldi r0, data.str
                    ldi r1, 0
                    ldi r2, 224
                    call sub_drwstr
                    ldm r0, data.bombs_plyrs
                    ldi r1, data.str
                    call sub_r2bcd3
                    ldi r0, data.str
                    ldi r1, 64
                    ldi r2, 224
                    call sub_drwstr
                    ret

;------------------------------------------------------------------------------
; drw_menu()
;   Draw menu screen graphics
;------------------------------------------------------------------------------
drw_menu:           ldi r0, data.str_start
                    ldi r1, 80
                    ldi r2, 104
                    call sub_drwstr
                    ldi r0, data.str_copyr1
                    ldi r1, 32
                    ldi r2, 200
                    call sub_drwstr
                    ldi r0, data.str_copyr2
                    ldi r1, 32
                    ldi r2, 216
                    call sub_drwstr
                    ret

;------------------------------------------------------------------------------
; level_inctile()
;   Add 1 to level map tile at given coordinates.
;
; IN:
;   r0: x
;   r1: y
;------------------------------------------------------------------------------
level_inctile:      push r0
                    push r1
                    muli r1, 20
                    addi r0, data.level
                    add r0, r1
                    ldm r1, r0
                    addi r1, 1
                    stm r1, r0
                    pop r1
                    pop r0
                    ret

;------------------------------------------------------------------------------
; level_remove()
;   Clear level map at given coordinates.
;
; IN:
;   r0: x
;   r1: y
;------------------------------------------------------------------------------
level_remove:       push r0
                    push r1
                    muli r1, 20
                    addi r0, data.level
                    add r0, r1
                    ldm r1, r0
                    andi r1, 0xff00
                    stm r1, r0
                    pop r1
                    pop r0
                    ret

;------------------------------------------------------------------------------
; BEGIN - Data

data.start_game:    dw 0

data.str:   db "   "

debug.x0:   dw 0
debug.y0:   dw 0
debug.x1:   dw 0
debug.y1:   dw 0
debug.spr:  dw 0x4444

data.btn_a_dn:      dw 0

data.anikey:        dw 0
data.sp:            dw 0

data.ptr_spr_plyr:  dw data.spr_plyr

data.pos_plyrs:     dw 0,0, 0,0, 0,0, 0,0

data.speed_plyrs:   dw 1, 1, 1, 1,
data.vec_plyrs:     dw 0,0, 0,0, 0,0, 0,0
; Use Up=0, Down=1, Left=2, Right=3. 
data.dir_plyrs:     dw 1, 1, 1, 1
data.pow_plyrs:     dw 1, 1, 1, 1

data.bombs_plyrs:   dw 1, 1, 1, 1

data.ko_plyrs:      dw 0, 0, 0, 0

data.move_lut:      dw -4,-3,  3,-3,
                    dw -4, 2,  3, 2,
                    dw -4,-3, -4, 2,
                    dw  3,-3,  3, 2,

; 1 bitfield word + 16 entries [0-f]
; 16x8
; Format: x : word, y : word, timer: word, flags: word
; flags:
;   bits 7..2 = power (# of extra cells in each direction for flame)
;   bits 1..0 = player
importbin data/zeros_2048.bin 0 2 data.bombs_list
importbin data/zeros_2048.bin 0 32 data.bombs

; 16 bitfield words + 256 entries [0-ff]
; 256x8
; Format: x : word, y : word, timer: word, flags: word
; flags:
;   bits 2..0 = flame direction/type
importbin data/zeros_2048.bin 0 32 data.flames_list
importbin data/zeros_2048.bin 0 2048 data.flames

; 16 bitfield words + 256 entries [0-ff]
; 256x8
; Format: x : word, y : word, timer: word, flags: word
; flags:
;   -
importbin data/zeros_2048.bin 0 32 data.dtiles_list
importbin data/zeros_2048.bin 0 2048 data.dtiles

; word 0: "busy" bitfield
; words 1..16: list elems
data.expl_list:     dw 0
                    dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

data.str_start:     db "Press START to begin"
                    db 0
data.str_copyr1:    db "Programming (C) 2024-5 T. Kelsall"
                    db 0
data.str_copyr2:    db "Graphics    (C) 2024-5 C. Kelsall"
                    db 0

; Level map format (hex):
;
; flame tile types: center, mid-horiz, mid-vert, left-horiz, right-horiz, top-vert, bottom-vert.
;
;   TTT VVVVV
;   ___ _____
;   000 00000   <empty>
;   000 ddddd   center-flame, `ddddd` frames remain
;   001 ddddd   mid-horiz-flame, `ddddd` frames remain
;   010 ddddd   left-horiz-flame, `ddddd` frames remain
;   011 ddddd   right-horiz-flame, `ddddd` frames remain
;   100 ddddd   mid-vert-flame, `ddddd` frames remain
;   101 ddddd   top-vert-flame, `ddddd` frames remain
;   110 ddddd   bottom-vert-flame, `ddddd` frames remain
;   111 00xxx   tile, `xxx` [e0 + 0..7]
;   111 01xxx   power-up, `xxx` [e8 + 0..7]
;       00 = +1 flame length
;       01 = +1 bomb drop
;   111 1xxxx   bomb, `xxxx` [f0 + 0..15]

data.level:         db 0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0
                    db 0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0
                    db 0xe0,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xe0
                    db 0xe0,0xe0,0x00,0xe0,0xe1,0xe0,0xe8,0xe0,0x00,0xe0
                    db 0x00,0xe0,0x00,0xe0,0x00,0xe0,0xe9,0xe0,0x00,0xe0
                    db 0xe0,0xe1,0xe1,0x00,0xe1,0x00,0x00,0x00,0x00,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xe0
                    db 0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0x00
                    db 0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0xe0
                    db 0xe0,0x00,0x00,0x00,0x00,0x00,0x00,0xe1,0xe1,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xe1,0xe0
                    db 0xe0,0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0xe1,0xe0
                    db 0x00,0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0
                    db 0xe0,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xe0
                    db 0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0x00
                    db 0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0xe0
                    db 0xe0,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xe0
                    db 0xe0,0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0
                    db 0x00,0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0
                    db 0xe0,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xe0
                    db 0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0x00
                    db 0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0x00,0xe0,0xe0
                    db 0xe0,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0xe1,0xe1,0xe1,0xe0
                    db 0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0
                    db 0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0
