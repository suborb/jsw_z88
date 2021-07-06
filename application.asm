;       Startup For z88 Application
;
;       Contains DOR, Error Handler and other startup requirements



    MODULE  application

    XREF    windini
    XREF    baswindres
    XREF    gameinfo
    XREF    myflags
    XREF    gamein
    XREF    tablesetup

    XREF    oz_init
    XREF    windsetup
    XREF    introsetup
    XREF    redefsetup

    INCLUDE "define.def"
    INCLUDE "fileio.def"
    INCLUDE "stdio.def"
    INCLUDE "error.def"
    INCLUDE "time.def"
    INCLUDE "director.def"


    org     58368

; Application DOR

.in_dor defb    0,0,0   ; links to parent, brother, son
        defw    0       ;brother_add
        defb    0       ;brother_bank
        defb    0,0,0
        defb    $83     ; DOR type - application
        defb    indorend-indorstart
.indorstart     
        defb    '@'     ; key to info section
        defb    ininfend-ininfstart
.ininfstart     
        defw    0
        defb    'W'     ; application key
        defb    reqpag      ; 5K contigious RAM
        defw    0       ; overhead
        defw    0       ; unsafe workspace
        defw    0       ; safe workspace
        defw    entry   ; entry point
        defb    0       ; bank bindings
        defb    0
        defb    in_bank-1       ;segment 2
        defb    in_bank         ;segment 3
        defb    at_bad  ; application type
        defb    0       ; no caps lock
.ininfend       defb    'H'     ; key to help section
        defb    inhlpend-inhlpstart
.inhlpstart     defw    in_topics
        defb    in_bank
        defw    in_commands
        defb    in_bank
        defw    in_help
        defb    in_bank
        defb    0,0,0   ; no tokens
.inhlpend       defb    'N'     ; key to name section
        defb    innamend-innamstart
.innamstart     defm    "JSW Z88\x00"
.innamend       defb    $ff
.indorend

; Topic entries

.in_topics      defb    0

.inopt_topic    defb    inopt_topend-inopt_topic
        defm    "OPTIONS\x00"
        defb    0
        defb    0
        defb    1
        defb    inopt_topend-inopt_topic
.inopt_topend

.incom_topic    defb    incom_topend-incom_topic
        defm    "COMMANDS\x00"
        defb    0
        defb    0
        defb    0
        defb    incom_topend-incom_topic
.incom_topend
        defb    0

; Command entries

.in_commands    defb    0

.in_opts1       defb    in_opts2-in_opts1
        defb    $81
        defm    "OD\x00"
        defm    "Display\x00"
        defw    0
        defb    0
        defb    in_opts2-in_opts1

.in_opts2       defb    in_opts3-in_opts2
        defb    $85
        defm    "OI\x00"
        defm    "Invert\x00"
        defw    0
        defb    0
        defb    in_opts3-in_opts2

.in_opts3
;        defb    in_opts_end-in_opts3
;        defb    $82
;        defm    "OV"&0
;        defm    "Version"&0
;        defw    0
;        defb    0
;        defb    in_opts_end-in_opts3

.in_opts_end    defb    1

;.in_coms0       defb    in_coms1-in_coms0
;        defb    $84
;        defm    "L"&0
;        defm    "Load levels"&0
;        defw    0
;        defb    0
;        defb    in_coms1-in_coms0

.in_coms1       defb    in_coms2-in_coms1
        defb    $83
        defm    "R\x00"
        defm    "Redefine keys\x00"
        defw    0
        defb    0
        defb    in_coms2-in_coms1

.in_coms2       defb    in_coms_end-in_coms2
        defb    $80
        defm    "Q\x00"
        defm    "Quit\x00"
        defw    0
        defb    0
        defb    in_coms_end-in_coms2

.in_coms_end    defb    0


; Help entries

.in_help        defb    $7f
        defm    "A conversion of the ZX Spectrum Game\x7f"
        defm    "Originally written by Matthew Smith 1984\x7f"
        defm    "Converted by Dominic Morris\x7f"
        defm    "github.com/suborb/     \x7f"
        defm    "v2.01 - 6th   July    2021\x7f"
        defb    0

.nomemory
        defb    1,'3','@',32,32,1,'2','J','C'
        defm    "Not enough memory allocated to run JSW z88"
        defb    13,13
        defm    "Sorry, please try again later!"
        defb    0

.need_expanded
        
        defb    1,'3','@',32,32,1,'2','J','C'
        defm    "Sorry, JSW Z88 needs an expanded machine"
        defb    13,13
        defm    "Try again when you have expanded your machine"
        defb    0

.applname
        defm    "JSW z88\x00"
        

.entry
        jp      init
        scf
        ret


;Give back second screen attributes and line table
;        ld      bc,bakscr2att
;        ld      de,scrtable+256
;        or 	a
;        ret

;Entry point..ix points to info table
.init
    ld      a,(ix+2)
    cp      $20+reqpag
    ld      hl,nomemory
    jr      c,init_error
    ;Now find out if we have an expanded machine or not...
    ld      ix,-1
    ld      a,FA_EOF
    call_oz(os_frm)
    jr      z,init_continue
    ld      hl,need_expanded
.init_error
    push    hl
    ;Now define windows...
    ld      hl,baswindres  ;oops, no basic window!
    call_oz(gn_sop)
    ld      hl,windini
    call_oz(gn_sop)
    pop     hl
    call_oz(gn_sop)
    ld      bc,500
    call_oz(os_dly)
    xor     a
    call_oz(os_bye)

.init_continue
    ld      a,SC_DIS
    call_oz(Os_Esc)
    xor     a
    ld      b,a
    ld      hl,errhan
    call_oz(os_erh)
    call    oz_init
    ld      hl,applname
    call_oz(dc_nam)
    ;Flow into gamein
    jp      gamein





.errhan
    ret     z       ;fatal error
    cp      RC_Draw         ;rc_susp        (Rc_susp for BASIC!)
    jr      nz,errhan2
    push    af
    call    tablesetup
    call    windsetup
    ld      hl,myflags
    bit     1,(hl)
    jr      z,errhan_game
    ;Hmmm, it's the title screen problems..have been preempted, but
    ;not backed up map..so copy it back again!!!
    bit     2,(hl)
    call    z,introsetup
    call    nz,redefsetup
    jr      errhan3

;Interrupted during the game..

;Redefine the udgs..hopefully! - During the game
.errhan_game
    call    gameinfo        ;print the score etc...
.errhan3
    pop     af
.errhan2
    cp      RC_Quit                 ;they don't like us!
    jr      nz,no_error
    xor     a
    call_oz(os_bye)         

.no_error
    xor     a
    ret
