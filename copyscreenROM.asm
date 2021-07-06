;Copy a screen from 16384 to OZ Map
;Needs to be reworked for each game..
;Rewriting so can ROM it..
;
;
;


    MODULE  screen

    INCLUDE "interrpt.def"

    INCLUDE "define.def"


    XREF    cksound
    XREF    myflags
    XREF    ozbank
    XREF    ozaddr
    XREF    WILLYY

    XDEF    ozscrcpy
    XDEF    ozscrcpy_noc

;Myflags
;bit 0 = sound on/off
;bit 1 = game/intro
;bit 2 = standard/define keys
;bit 3 = resoluion
;bit 4 = inverse
;bit 5 = cheat on/off
;bit 6 = referred to by lives
;bit 7 = on/off flag

          
.ozscrcpy
    call    cksound         ;might as well do it here!
.ozscrcpy_noc  
    ld      hl,segstor
    ld      a,(hl)
    push    af
    ld      a,(ozbank)
    ld      (hl),a
    out     (segment),a
    ld      de,ozfullcpy
    ld      a,(myflags)
    bit     3,a              ;bit 3
    jr      z,ozskhalf
    ld      de,ozhalfcpy
.ozskhalf
    exx
    ld      c,0
    bit     4,a
    jr      z,ozskinv
    ld      c,255
.ozskinv
    ld      hl,(ozaddr)
    exx
    call    oz_di
    push    af
    call    ozcallch
    pop     af
    call    oz_ei
    pop     af
    ld      (segstor),a
    out     (segment),a
    ret

.ozcallch
          push de
          ret

.ozfullcpy
    ld      a,(WILLYY)
    rlca
    rlca
    rlca
    rlca
    and     15
    cp      12
    jr      c,scrcpya
    ld      a,11
.scrcpya  
    sub     3
    jr      nc,scrcpy0
    xor     a
.scrcpy0  
    ld      b,a
    ld      c,8
.scrcpy1  
    push    bc
    ld      a,b
    and     248
    add     a,bakscr2/256
    ld      d,a
    ld      a,b
    and     7
    rrca
    rrca
    rrca
    ld      e,a
    ;OZ screen is handled like characters..grrr!
    ld      c,32
.scrcpy2
    ld      b,8
    push    de
.scrcpy3  
    ld      a,(de)
    exx
    xor     c
    ld      (hl),a
    inc     hl
    exx
    inc     d
    djnz    scrcpy3
    pop     de
    inc     e
    dec     c
    jp      nz,scrcpy2

    pop     bc
    inc     b
.scrcpy36 
    ex      af,af
    dec     c
    jp      nz,scrcpy1
    ret


;Screen copy for half size

.ozhalfcpy
    ld      de,bakscr2
.ozhalfcpy1
    ld      b,4
.ozhalfcpy2
    ld      a,(de)
    exx
    xor     c
    ld      (hl),a
    inc     hl
    exx
    inc     d
    inc     d
    djnz    ozhalfcpy2
    ld      a,d
    sub     8
    ld      d,a
    ld      a,e
    add     a,32
    ld      e,a
    ld      b,4
.ozhalfcpy3
    ld      a,(de)
    exx
    xor     c
    ld      (hl),a
    inc     hl
    exx
    inc     d
    inc     d
    djnz    ozhalfcpy3
    ld       a,d
    sub     8
    ld      d,a
    ld      a,e
    sub     31
    ld      e,a
    and     31
    jp      nz,ozhalfcpy1
    ld      a,e
    add     a,32
    ld      e,a
    and     a
    jp      nz,ozhalfcpy1
    ld      a,d
    add     a,8
    ld      d,a
    cp      bakscr2hig+16
    jp      c,ozhalfcpy1
    ret

