;
;Disassembly of Jet Set Willy, done by John Elliott with the Dazzlestar 
;disassembler under cp/M.
;
; Reconstructed for the z88, 30/6/98 -> 22/7/98
; Turned into a z88 application 25/11/98 -> 27/11/98


    MODULE  jetset
    INCLUDE "define.def"
    INCLUDE "stdio.def"
    INCLUDE "map.def"
    INCLUDE "screen.def"
    INCLUDE "memory.def"
    INCLUDE "error.def"
    INCLUDE "integer.def"
    INCLUDE "time.def"
    INCLUDE "interrpt.def"
    INCLUDE "syspar.def"

    ;For application
    XDEF    baswindres
    XDEF    windini
    XDEF    oz_init
    XDEF    introsetup
    XDEF    gameinfo
    XDEF    redefsetup
    XDEF    windsetup
    XDEF    gamein
    XDEF    tablesetup
    ;For keys
    XDEF    pkeys
    XREF    keys
    XREF    kfind
    XREF    ktest1
    XREF    mapkey
    ;For Screen
    XDEF    myflags
    XDEF    WILLYY
    XDEF    ozaddr
    XDEF    myworksp
    XDEF    ozbank
    XREF    ozscrcpy
    ;For redefine
    XDEF    redefine
    XREF    ozread



;When changing screen over, will have pressed key in anycase,,,

.clpause
    xor    a
    ld     (pausect),a
    ret


; Main entry point
.gamein
    ;Dump up the title screen..
    ;call_oz(os_pur)         ;Purge keyboard buffer
    ld     hl,T85E2
    set    0,(hl)
.attractrst
    xor    a
    ld     (genpos),a
    call   introsetup
    ld     hl,tunedata
    call   tuneplay          ;Play the tune
    jr     nc,attract
    cp     13
    jp     z,startgame       ;start the game
    jp     redefine

;Hmmm..attract mode, scroll etc!
.attract
    ld     bc,3
    call_oz(os_dly)
    ld     hl,(genpos)
    ld     de,scrolltext  ;Scrollify the message
    ld     h,0
    add    hl,de
    ld     de,8192+32+256        ;(1,0)
    call   print32
    ld     a,(genpos)
    and    31
    add    a,50
    call   scrollsnd
    call   ozread
    cp     13
    jr     z,startgame
    and    223
    cp     'R'
    jp     z,redefine
    ld     a,(genpos)
    inc    a
    cp     $E0      ;End of scrolly?
    ld     (genpos),a
    jr     nz,attract ;$-42
    jr     attractrst          ;Restart at L8813

.startgame
    call   clpause       ;exits with a=0
    ld     (TICKER),a
    ld     (B85CD),a
    ld     (flags),a
    ld     (ticktime),a
    ld     (STATUS),a     ;Playing in normal mode
    add    a,48             ;a="0"
    ld     hl,itemtext
    ld     (hl),a
    inc    hl
    ld     (hl),a
    inc    hl
    ld     (hl),a
.cheatlives
    ld     a,7       ;Initial no. of lives
    ld     (LIVES),a
.CHEATPOSY
    ld     a,$D0
    ld     (WILLYY),a     ;Willy's Y-coordinate
.CHEATROOM
    ld     a,33      ;Initial room 33
    ld     (ROOM),a
.CHEATPOSX
    ld      hl,bakscr2att+256+$B4  ;$5DB4 Willy's initial X-coordinate
    ld      (WILLYX),hl
    ;Copy the objects down into RAM from ROM
    ld      hl,object_store
    ld      de,objstklow
    ld      bc,513
    ld      a,(hl)
    ld      (itemcount),a   ;256-no. items to collect
    ldir
    ;Mark end of guardians
    ld      a,255
    ld      (guardend),a

    ld      hl,myflags
    res     1,(hl)
    res     7,(hl)
    call    windclr
    ld      hl,$3720  ;" 7"
    ld      (CTIME),hl
    ld      hl,$3030  ;"00"
    ld      (CTIME1),hl
    ld      a,':'
    ld      (ctimecol),a
    ld      hl,$6D61     ;"am"
    ld      (ctimeper),hl

;
;**  Enter and draw room
;

.drawroom
    ld      a,(ROOM)
    add     a,roomshigh
    ld      h,a       ;Find room address, move room to 8000h.
    ld      l,0       ;1 room = 1 page
    push    hl
    ld      bc,128
    add     hl,bc
    ld      de,cur_room_dat
    ldir
    ld      ix,guardian  ;Guardian table for room
    ld      de,guardwork
    ld      a,8       ;max 8 guardians/room
.drawroom1
    ex      af,af'
    ld      l,(ix+0)  ;(ix+0)=Guardian ID
    res     7,l
    ld      h,0
    add     hl,hl
    add     hl,hl
    add     hl,hl          ;Becomes A000h + 8*L
    ld      bc,49152+960  ;CHANGE - to get to new guard entry
    add     hl,bc
    ld      bc,2
    ldir
    ld      a,(ix+1)
    ld      (de),a
    inc     hl
    inc     de
    ld      bc,5
    ldir
    inc     ix
    inc     ix
    ex      af,af'
    dec     a
    jr      nz,drawroom1

    ;Make a back up of initial data lest willy die
    ld      hl,WILLYY ;Room initialisation data
    ld      de,initdata
    ld      bc,7
    ldir
    pop     hl        ;address of screen data..
    call    plotroom

    ;CHANGE print the info in an OZ window...
    call    displegends
    xor     a
    ld      (B85D6),a



.mloop
    call    prlives




;We have two back screens - one which contains the room
;And the other which is copy of this and the sprites are 
;printed on, this is then copied to the front screen..bizarre!
;Attributes used to check..
;Copy the master one to the scratch one
    ld      hl,bakscr1att
    ld      de,bakscr2att
    ld      bc,512
    ldir
    ld      hl,bakscr1
    ld      de,bakscr2
    ld      bc,4096
    ldir
    call    moveguard
    ld      a,(STATUS)     ;At end of game?
    cp      3
    call    nz,movewilly
    ld      a,(WILLYY)
    cp      $E1
    call    nc,roomup       ;Move up
    ld      a,(STATUS)
    cp      3               ;At end of game?
    call    nz,C95C8
    ld      a,(STATUS)
    cp      2               ;Moving right at speed?
    call    z,autoright     ;Check for collision with lavatory
    call    domaria         ;Handle Maria & bathroom lavatory
    call    doguard         ;Handle guardians etc
    call    doconvey        ;Animate conveyor belts
    call    ckobjects       ;Handle collection of items also does colour

.scrcpy
    ;     ld      bc,2
    ;     call_oz(os_dly)
    call    ozscrcpy
    ld      a,(STATUS)     ;Is manual control allowed?
    and     2
    rrca
    ld      hl,W85D2
    or      (hl)
    ld      (hl),a
    ld      a,(B85CD)
    or      A
    jr      z,R8A26 ;$+17
    dec     A
    ld      (B85CD),a
    rlca
    rlca
    rlca
    and     @00111000
    ;doing sommat to 23552 etc
    ld      hl,bakscr2att
    ld      de,bakscr2att+1
    ld      bc,511
    ld      (hl),a
    ldir

.R8A26
    call    dispcounts

    ld      a,(ticktime) ;Ticker
    inc     a
    ld      (ticktime),a
    jr      nz,skipclock ;$+5B
    ;This handles the clock..
    ld      ix,CTIME
    inc     (ix+4)
    ld      a,(ix+4)
    cp      ':'
    jr      nz,skipclock ;$+4D
    ld      (ix+4),'0'
    inc     (ix+3)
    ld      a,(ix+3)
    cp      '6'  ;$36
    jr      nz,skipclock ;$+3F
    ld      (ix+3),$30
    ld      a,(ix+0)
    cp      '1'  ;$31
    jr      nz,skipclock0 ;$+22
    inc     (ix+1)
    ld      a,(ix+1)
    cp      '3'       ;$33
    jr      nz,skipclock ;$+2A
    ld      a,(ix+5)
    cp      'p'      ;$70
    jp      z,gamein
    ld      (ix+0),' '
    ld      (ix+1),'1' ;$31
    ld      (ix+5),'p' ;$70
    jr      skipclock     ;$+14

.skipclock0
    inc     (ix+1)
    ld      a,(ix+1)
    cp      ':'  ;$3A
    jr      nz,skipclock ;$+0A
    ld      (ix+1),'0' ;$30
    ld      (ix+0),'1' ;$31

;keyboard routines for quit/pause/music on/off
;these are accessed via OZ..hopefully work...
.skipclock
    call    ozread
    xor     a
    ld      (key),a
    call    keys            ;Ready keyboard without OZ
    ld      a,e
    ld      (key),a
    and     a
    call    nz,clpause
.nostorekey
    bit     7,e             ;inverse toggle
    jr      z,noinvtog
    ld      a,(myflags)
    xor     16              ;bit 4
    ld      (myflags),a

.noinvtog
    bit     5,e
    jp      nz,gamein       ;ESC pressed, go straight to title screen
    ld      hl,pausect
    inc     (hl)
    jr      z,pause0
    bit     2,e             ;pause
    jr      z,notpause
.pause0
    call    ppausetx

    ld      hl,myflags
    set     7,(hl)
.PAUSE
    call_oz(os_in)
    call    keys
    bit     2,e
    jr      z,PAUSE
    ld      hl,myflags
    res     7,(hl)
    

.ENDPAUSE
.notpause
    ld      hl,T85E2
    ld      a,(flags)
    cp      255
.CHEATIMMORTAL
    jp      z,loselife        ;Death?
    bit     6,e
    jr      z,skipswtune
    ld      a,(myflags)
    xor     8                 ;screen size
    ld      (myflags),a
.skipswtune
    bit     3,e
    jr      z,R8B36

    bit     0,(hl)
    jr      nz,R8B38 ;$+0A
    ld      a,(hl)
    xor     3
    ld      (hl),a
    jr      R8B38     ;$+04
.R8B36
    res     0,(hl)
.R8B38
    bit     1,(hl)
    jr        nz,skipmusic ;$+36
    ld      a,(myflags)
    rrca
    jr      c,skipmusic
    call    oz_di
    push    af
    ld      hl,TICKER
    inc     (hl)
    ld      a,(hl)
    and     $7E       ;6-bit value
    rrca           ;0-63
    ld      e,a
    ld      d,0
.tuneaddr
    ld      hl,richman      ;The in-game tune
    add     hl,de
    ld      a,(LIVES)       ;Make it worse as lives decrease :-)
    rlca
    rlca
    sub     $1C
    neg
    add     a,(hl)
    ld      d,a             ;D=note

    ld      a,($4B0)        ;pick up value at port, and mask speaker...
    and     63
    ld      e,d
    ld      bc,3
.inmusic1
    out     ($B0),a
    dec     e
    jr      nz,inmusic2
    ld      e,d
    xor     64
.inmusic2
    djnz    inmusic1
    dec     c
    jr      nz,inmusic1
    call    ressound
    pop     af
    call    oz_ei
;
;Check for WRITETYPER teleportation.
;
.skipmusic
    ld      a,(wtmode)
    cp      10
    jr      nz,nowrttyper
    ld      a,60
    call    ktest1
    jr      c,nowrttyper
    call    ozread
    ld      bc,$EFB2
    in      a,(c)
    cpl
    and     63
    ld      (ROOM),a
    call    ozread
    jp      drawroom

.nowrttyper
    ld      a,(wtmode)
    cp       $0A
    jr      z,ckwrt2        ;WRITETYPER already on, don't bother
    ;Check for writetyper cheat...
    ld      a,(ROOM)
    cp      $1C
    jr      nz,ckwrt2       ;Not in room 28 (1st Landing), don't bother
    ld      a,(WILLYY)
    cp      $D0
    jr      nz,ckwrt2       ;Not standing on floor, don't bother
    ld      ix,writetype
    ld      a,(wtmode)
    ld      e,a
    ld      d,0
    add     ix,de
    call    kfind
    inc     d
    jr      z,ckwrt2
    dec     d
    call    ozread
    ld      hl,wtmode
    ld      a,d
    cp      (ix+0)
    jr      z,ckwrt1
    cp      (ix-1)
    jr      z,ckwrt2
    ld      (hl),255
;     xor  A
;     ld      (wtmode),a     ;Wrong. Go back to beginning of WRITETYPER.
.ckwrt1
    inc     (hl)
.ckwrt2
    jp      mloop

;.ckwrt1
;     ld      a,(Wtmode)
;     inc     a
;     ld      (wtmode),a
;     jp   mloop



;loselife..

.loselife
    ld      a,$47
.loselife1
    ld      e,a
    cpl
    and     7
    rlca
    rlca
    rlca
    or      7
    ld      d,a
    ld      c,e
    rrc     C
    rrc     C  
    rrc     C
    call    dosound1
    ld      a,e
    dec     a
    cp      $3F
    jr      nz,loselife1 ;$-2E
    ld      hl,LIVES
    ld      a,(hl)
    or      a
    jr      z,gameover          ;Game over
.cheatlife
    ld      a,(myflags)
    bit     5,a
    jr      nz,cheating_lives
    dec     (hl)                ;NOP out for infinite lives
.cheating_lives
    ld      hl,initdata
    ld      de,WILLYY           ;Willy's starting position in this room
    ld      bc,7
    ldir
    jp      drawroom            ;Redraw room



.gameover
    call    cls                 ;exits with a=0
    ld      (genpos),a
    ld      de,willyright       ;Willy facing right CHANGE
    ld      hl,willydiepos
    ld      c,a                 ;c,0 ; a=0
    call    gdraw
    ld      de,barrel           ;Barrel  CHANGE
    ld      hl,barrelpos
    ld      c,a                 ;gdraw exits with a=0
    call    gdraw

;This bit animates the barrel
.gameover1
    ld      a,(genpos)
    ld      c,a
    ld      b,scrtablehig
    ld      a,(bc)
    or      $0F
    ld      L,a
    inc     bc
    ld      a,(bc)
;     sub  20H      ;not needed - am printing on back screen in anycase
    ld      h,a
    ld      de,thefoot          ;The foot 
    ld      c,0
    call    gdraw
    ld      a,(genpos)
    ld      (WILLYY),a
    call    ozscrcpy            ;Copy screen to map
    ld      a,(genpos)
    cpl
    ld      d,a
    ld      bc,64
    call    dosound1
    ld      a,(genpos)
    add     a,4
    ld      (genpos),a
    cp      196
    jr      nz,gameover1 

;CHANGE   ;not sure what to do with these ones
;This prints GAME OVER and sparkles it

    ld      hl,gameovert
    ld      de,9216+11+32       ;4,11
    ld      c,14
    call    print
    call_oz(os_pur)
    ld      bc,500
    call_oz(os_tin)
    jp      gamein

;plot the room, done in two halves...!

.plotroom
    call    genatt              ;Generate room attributes
    ld      ix,bakscr1att
    ld      a,bakscr1hig        ;these are bak screens, ix=attribute
    ld      (plotroom3_var),a
    call    plotroom1
    ld      ix,bakscr1att+256
    ld      a,bakscr1hig+8
    ld      (plotroom3_var),a

.plotroom1
    ld      c,0
.plotroom2
    ld      E,C
    ld      a,(ix+0)
    ld      hl,airdata
    ld      bc,54
    cpir
    ld      c,E
    ld      b,8
    ld      a,(plotroom3_var)
    ld      d,a
.plotroom4
    ld      a,(hl)
    ld      (de),a
    inc     hl
    inc     d
    djnz plotroom4
    inc     ix
    inc     c
    jr      nz,plotroom2
    ret

.genatt
;     ld      hl,cur_room_dat  ;Room description (entered in with this..)
    ld      ix,bakscr1att
.genatt1
    ld      a,(hl)         ;Top 2 bits
    rlca
    rlca
    call    genatt3        ;Plot a square
    ld      a,(hl)         ;Next 2 bits
    rrca
    rrca
    rrca
    rrca
    call    genatt3          ;Next 2 bits
    ld      a,(hl)
    rrca
    rrca
    call    genatt3          ;Bottom 2 bits
    ld      a,(hl)
    call    genatt3
    inc     hl
    ld      a,l       ;Continue until all drawn
    and     $80
    jr      z,genatt1
    ld      a,(convlen) ;Conveyor length
    or      a
    jr      z,genatt5
    ld      b,a
    ld      hl,(convsta)     ;Conveyor start
    ld      de,bakscr1att-24064
    add     hl,de
    ld      a,(convdata) ;Conveyor colour
.genatt2
    ld      (hl),a
    inc     hl
    djnz    genatt2
.genatt5
    ld      a,(ramplen) ;Ramp length
    or      a
    ret     z
    ld      hl,(rampst)     ;Ramp start
    ld      de,bakscr1att-24064
    add     hl,de
    ld      a,(rampdir) ;Ramp direction
    and     1
    rlca
    add     a,$DF
    ld      e,a
    ld      d,$FF
    ld      a,(ramplen) ;Ramp length
    ld      b,a
    ld      a,(rampdata) ;Ramp colour
.genatt4
    ld      (hl),a
    add     hl,de
    djnz    genatt4
    ret

.genatt3
    and     3
    ld      c,a
    rlca
    rlca      ;A:=A*9
    rlca
    add     a,C
    add     a,$A0-128
    ld      e,a
    ld      d,cur_roomdathig
    ld      a,(de)
    ld      (ix+0),a
    inc     ix
    ret


;This looks like main movement loop
.movewilly
    ld      a,(B85D6)
    dec     A
    bit     7,a
    jp      z,L8ED4
    ld      a,(flags)
    cp      1
    jr      nz,R8E36 ;$+55
    ld      a,(B85D5)
    and     $FE
    sub     8
    ld      hl,WILLYY ;Height
    add     a,(hl)
    ld      (hl),a
    cp      $F0       ;dodgy..was F0
    jp      nc,roomup  ;Move up

    call    C8E9C
    ld      a,(earthdata)
    cp      (hl)
    jp      z,L8EBC
    inc     hl
    cp      (hl)
    jp      z,L8EBC
    ld      a,(B85D5)
    inc     A
    ld      (B85D5),a
    sub     8
    jp      P,L8E11
    NEG
.L8E11
    inc     A
    rlca
    rlca
    rlca
    ld      d,a
    ld      c,$20
    call    dosound1
    ld      a,(B85D5)
    cp      $12
    jp      z,L8EB0
    cp      $10
    jr      z,R8E36 ;$+07
    cp      $0D
    jp      nz,fininp
;I think this is just general move in height
.R8E36
    ld      a,(WILLYY)     ;Height
    and     $0E
    jr      nz,R8E62 ;$+27
    ld      hl,(WILLYX)
    ld      de,$40         ;64
    add     hl,de
;changed a bit here     SPECIFIC
    ld      a,h
    and     3
;     xor  3    
    jp      z,roomdown  ;Move down
    ld      a,(firedata)
    cp      (hl)
    jr      z,R8E62 ;$+15
    inc      hl
    ld      a,(firedata)
    cp      (hl)
    jr      z,R8E62 ;$+0E
    ld      a,(airdata)
    cp      (hl)
    dec     hl
    jp      nz,L8ED4
    cp      (hl)
    jp      nz,L8ED4
.R8E62
    ld      a,(flags)
    cp      1
    jp      z,fininp
    ld      hl,wspranim
    res     1,(hl)
    ld      a,(flags)
    or      A
    jp      z,L8EB6
    inc     A
    cp      $10
    jr      nz,R8E7D ;$+04
    ld      a,$0C
;This is acting like a falling count?
.R8E7D
    ld      (flags),a
    rlca
    rlca
    rlca
    rlca
    ld      d,a
    ld      c,32
    call    dosound1
    ld      a,(WILLYY)
    add     a,8
    ld      (WILLYY),a
.concoord
.C8E9C
    and     $F0
    ld      L,a

    xor     A
    rl      L
    ADC     a,bakscr2att/256
    ld      h,a
    ld      a,(WILLYX)
    and     31
    or      L
    ld      L,a
    ld      (WILLYX),hl
    ret

.L8EB0
    ld      a,6
    ld      (flags),a
    ret

.L8EB6
    ld      a,2
    ld      (flags),a
    ret

.L8EBC
    ld      a,(WILLYY)
    add     a,16
    and     $F0
    ld      (WILLYY),a
    call    C8E9C
    ld      a,2
    ld      (flags),a
    ld      hl,wspranim
    res     1,(hl)
    ret

;Come here when we aren't jumping
.L8ED4

    ld      e,255
    ld      a,(B85D6)
    dec     a
    bit     7,a
    jr      z,R8EFA ;$+1E
    ld      a,(flags)
    cp      $0C
    jp      nc,diewilly2
    xor     A
    ld      (flags),a
    ld      a,(convdata)
    cp      (hl)
    jr      z,R8EF4 ;$+06
    inc     hl
    cp      (hl)
    jr      nz,R8EFA ;$+08
.R8EF4
    ld      a,(convdir) ;Conveyor direction
    sub     3
    ld      e,a
;Scan keyboard/read kempston - CHANGE?
;Have to leave e with
; bit 0 reset = right
; bit 1 reset = left
.R8EFA
    ld      a,255     ;63
    and     e
    ld      e,a
    ld      a,(STATUS)
    and     2
    rrca
    xor     e
    ld      e,a
    

    ld      d,0
    ld      a,(key)
    and     3
    cpl
    and     e
    ld      e,a
;Need to sort out pause control here
.R8F42
    ld      c,0
    bit     1,e
    jr      nz,R8F51
;We have had movement left..
    ld      c,4
    call    clpause
.R8F51
    bit     0,e
    jr      nz,R8F5E
    set     3,C
    call    clpause
.R8F5E
    ld      a,(wspranim)
    add     a,C
    ld      c,a
    ld      b,0
    ld      hl,wsprtab
    add     hl,bc
    ld      a,(hl)
    ld      (wspranim),a
    ld      a,(key)
    bit     4,a
    jr      z,fininp
;This deals with jump
.gotjump
    ld      a,(STATUS)     ;Is manual control allowed?
    bit     1,a
    jr      nz,fininp ;$+28
    call    clpause   ;sets a=0
    ld      (B85D5),a
    inc     a
    ld      (flags),a
    ld      a,(B85D6)
    dec     A
    bit     7,a
    jr      nz,fininp ;$+15
    ld      a,$F0
    ld      (B85D6),a
    ld      a,(WILLYY)
    and     $F0       ;1111000
    ld      (WILLYY),a
    ld      hl,wspranim
    set     1,(hl)
    ret

.fininp
    ld      a,(wspranim)
    and     2
    ret     Z
    ld      a,(B85D6)
    dec     A
    bit     7,a
    ret     Z
    ld      a,(wspranim)
    and     1
    jp      z,L9042
    ld      a,(W85D2)
    or      A
    jr      z,R8FDC ;$+07
    dec     A
    ld      (W85D2),a
    ret

;Deals with moving left/right
.R8FDC
    ld      a,(flags)
    ld      bc,0
;     cp   0
    and     a
    jr      nz,R900A ;$+26      ;no ramp?
    ld      hl,(WILLYX)
    ld      bc,0
    ld      a,(rampdir)
    dec     A
    or      $A1
    xor     $E0
    ld      e,a       ;34/64         
    ld      d,0
    add     hl,de
    ld      a,(rampdata)
    cp      (hl)
    jr      nz,R900A ;$+0E
    ld      bc,32
    ld      a,(rampdir)
    or      A
    jr      nz,R900A ;$+05
    ld      bc,$FFE0       ;-32
.R900A
    ld      hl,(WILLYX)
    ld      a,L
    and     31
    jp      z,roomleft ;Move left
    add     hl,bc
    dec     hl
    ld      de,$20
    add     hl,de
;     ld      a,h
;     cp   bakscr2atthig
;     jr   c,skipearth1
    ld      a,(earthdata)
    cp      (hl)
    ret     Z
.skipearth1
    ld      a,(WILLYY)
    SRA     C
    add     a,C
    ld      b,a
    and     $0F
    jr      z,R9032 ;$+0B
    add     hl,de
;     ld      a,h
;     cp   bakscr2atthig
;     jr   c,skipearth2
    ld      a,(earthdata)
    cp      (hl)
    ret     Z
.skipearth2
    or      A
    Sbc     hl,de
.R9032
    or      A
    Sbc     hl,de
    ld      (WILLYX),hl
    ld      a,b
    ld      (WILLYY),a
    ld      a,3
    ld      (W85D2),a
    ret

.L9042
    ld      a,(W85D2)
    cp      3
    jr      z,R904E ;$+07
    inc     A
    ld      (W85D2),a
    ret

.R904E
    ld      a,(flags)
    ld      bc,0
    or      A
    jr        nz,R9078 ;$+23
    ld      hl,(WILLYX)
    ld      a,(rampdir)
    dec     A
    or      $9D            ;CHANGE
    xor     $BF
    ld      e,a
    ld      d,0
    add     hl,de
    ld      a,(rampdata)
    cp      (hl)
    jr      nz,R9078 ;$+0E
    ld      bc,$20
    ld      a,(rampdir)
    or      A
    jr      z,R9078 ;$+05
    ld      bc,$FFE0
.R9078
    ld      hl,(WILLYX)
    add     hl,bc
    inc     hl
    inc     hl
    ld      a,L
    and     31
    jp      z,roomright
    ld      de,$20
    ld      a,(earthdata)
    add     hl,de
    cp      (hl)
    ret     Z
    ld      a,(WILLYY)
    SRA     C
    add     a,C
    ld      b,a
    and     $0F
    jr      z,R90A1 ;$+0B
    ld      a,(earthdata)
    add     hl,de
    cp      (hl)
    ret     Z
    or      A
    Sbc     hl,de
.R90A1
    or      A
    Sbc     hl,de
    ld      a,h
    cp      bakscr2att/256
    jr      c,skipearth3
    ld      a,(earthdata)
    cp      (hl)
    ret     Z
.skipearth3
    dec     hl
    ld      (WILLYX),hl
    xor     A
    ld      (W85D2),a
    ld      a,b
    ld      (WILLYY),a
    ret

.diewilly
    pop     hl
.diewilly2    
    pop     hl
.CHEATDIE
    ld      a,$FF
    ld      (flags),a ;Used in collision detection.
    jp      scrcpy

;Move the guardians?

.moveguard
    ld      ix,guardwork
.moveguard1
    ld      a,(ix+0)  ;End of guardians?
    cp      255
    ret     Z
    and     3         ;Guardian type
    jp      z,move_next        ;0 or arrow
    cp      1
    jp      z,move_horiz        ;Moving horizontally
    cp      2
    jp      z,move_vertic        ;Moving vertically
;This is rope
    bit     7,(ix+0)
    jr      z,move_ropeleft        ;Rope
;Move the roperight..dunno how..it just does!
    ld      a,(ix+1)
    bit     7,a
    jr      z,R90F5 ;$+11
    sub     2
    cp      $94
    jr      nc,R911D ;$+33
    sub     2
    cp      $80
    jr      nz,R911D ;$+2D
    xor     A
    jr      R911D     ;$+2A

.R90F5
    add     a,2
    cp      $12
    jr      nc,R911D ;$+24
    add     a,2
    jr      R911D     ;$+20

.move_ropeleft
    ld      a,(ix+1)
    bit     7,a
    jr      nz,R9115 ;$+11
    sub     2
    cp      $14
    jr      nc,R911D ;$+13
    sub     2
    or      A
    jr      nz,R911D ;$+0E
    ld      a,$80
    jr      R911D     ;$+0A

.R9115
    add     a,2
    cp      $92
    jr      nc,R911D ;$+04
    add     a,2
.R911D
    ld      (ix+1),a
    and     $7F
    cp      (ix+7)
    jp      nz,move_next
    ld      a,(ix+0)
    xor     $80
    ld      (ix+0),a
    jp      move_next
;***END OF ROPE STUFF

.move_horiz
    bit     7,(ix+0)
    jr        nz,move_horizright ;$+25
    ld      a,(ix+0)
    sub     $20
    and     $7F
    ld      (ix+0),a
    cp      $60
    jr      c,move_next ;$+71
    ld      a,(ix+2)
    and     $1F
    cp      (ix+6)
    jr      z,R9156 ;$+07
    dec     (ix+2)
    jr      move_next     ;$+62

.R9156
    ld      (ix+0),$81
    jr      move_next     ;$+5C

.move_horizright
    ld      a,(ix+0)
    add     a,32
    or      $80
    ld      (ix+0),a
    cp      $A0
    jr      nc,move_next ;$+4E
    ld      a,(ix+2)
    and     31
    cp      (ix+7)
    jr      z,R9179 ;$+07
    inc     (ix+2)
    jr      move_next     ;$+3F

.R9179
    ld      (ix+0),$61
    jr      move_next     ;$+39

;**END OF HORIZ GUARDIAN


.move_vertic
    ld      a,(ix+0)  ;High-speed animation?
    xor     8
    ld      (ix+0),a
    and     24
    jr      z,R9193 ;$+0A
    ld      a,(ix+0)
    add     a,32
    ld      (ix+0),a
.R9193
    ld      a,(ix+3)  ;Height
    add     a,(ix+4)  ;Direction, U/D
    ld      (ix+3),a
    cp      (ix+7)
    jr      nc,R91AE ;$+0F
    cp      (ix+6)
    jr      z,R91A8 ;$+04
    jr      nc,move_next ;$+10
.R91A8
    ld      a,(ix+6)
    ld      (ix+3),a
.R91AE
    ld      a,(ix+4)
    NEG
    ld      (ix+4),a

;***END OF VERTICAL GUARDIANS


.move_next
    ld      de,8
    add     ix,de
    jp      moveguard1

;Do guardians
.doguard
    ld      ix,guardwork
.doguard1
    ld      a,(ix+0)
    cp      255
    ret     Z
    and     7    ;Guardian type
    jp      z,doguard_next
    cp      3    ;Rope
    jp      z,doguard_rope
    cp      4
    jr      z,doguard_arrow ;Arrow
;Normal guardian
    ld      e,(ix+3)  ;Y
    ld      d,scrtablehig
    ld      a,(de)
    ld      l,a
    ld      a,(ix+2)  ;X
    and     $1F
    add     a,L
    ld      l,a
    ld      a,E
    rlca
    and     1
    add     a,bakscr2att/256
    ld      h,a
    ld      de,$1F
    ld      a,(ix+1)
    and     $0F
    add     a,56
    and     $47
    ld      c,a
    ld      a,(hl)
    and     @00111000
    xor     C
    ld      c,a
    ld      (hl),C
    inc     hl
    ld      (hl),C
    add     hl,de
    ld      (hl),C
    inc     hl
    ld      (hl),C
    ld      a,(ix+3)
    and     $0E
    jr      z,R920F ;$+06
    add     hl,de
    ld      (hl),C
    inc     hl
    ld      (hl),C
.R920F
    ld      c,1
    ld      a,(ix+1)
    and     (ix+0)
    or      (ix+2)
    and     $E0
    ld      e,a
    ld      a,(ix+5)      ;change?
;convert on the fly to the proper location in EPROM
;25/11
    ld      d,a
    ld      hl,9152 ;CHANGE diff
    add     hl,de
    ex      de,hl
    ld      h,scrtablehig
    ld      l,(ix+3)
    ld      a,(ix+2)
    and     31
    or      (hl)
    inc     hl
    ld      h,(hl)
    ld      l,a
    call    gdraw     ;Draw a monster?
    jp      nz,diewilly2
    jp      doguard_next

.doguard_arrow
    bit     7,(ix+0)
    jr      nz,doguard_arrow1 ;$+09
    dec     (ix+4)
    ld      c,$2C
    jr      doguard_arrow2     ;$+07

.doguard_arrow1
    inc     (ix+4)
    ld      c,$F4
.doguard_arrow2
    ld      a,(ix+4)
    cp      C
    jr      nz,doguard_arrow5 ;$+15
    ld      a,(myflags)
    rrca
    jp      c,doguard_next
    ld      bc,$280
;This is almost identical to
;the standard dosound1
    ld      a,($4B0)
    and     63
.doguard_arrow3
    out     ($B0),a
    xor     64
.doguard_arrow4
    djnz doguard_arrow4     ;$-00
    ld      b,c
    dec     c
    jr      nz,doguard_arrow3 ;$-08
    call    ressound
    jp      doguard_next

.doguard_arrow5
    and     $E0
    jp      nz,doguard_next
    ld      e,(ix+2)
    ld      d,scrtablehig
    ld      a,(de)
    add     a,(ix+4)
    ld      l,a
    ld      a,E
    and     $80
    rlca
    add     a,bakscr2att/256
    ld      h,a
    ld      (ix+5),0
    ld      a,(hl)
    and     7
    cp      7
    jr      nz,doguard_arrow6 ;$+05
    dec     (ix+5)
.doguard_arrow6
    ld      a,(hl)
    or      7
    ld      (hl),a
    inc     de
    ld      a,(de)
    ld      h,a
    dec     h
    ld      a,(ix+6)
    ld      (hl),a
    inc     h
    ld      a,(hl)
    and     (ix+5)
    jp      nz,diewilly2
    ld      (hl),$FF
    inc     h
    ld      a,(ix+6)
    ld      (hl),a
    jp      doguard_next

;End of doguard_arrow

.doguard_rope
    ld      IY,scrtable ;CHANGE
    ld      (ix+9),0
    ld      a,(ix+2)
    ld      (ix+3),a
    ld      (ix+5),$80
.L92B6
    ld      a,(IY+0)
    add     a,(ix+3)       ;offset from start of line
    ld      l,a
    ld      h,(IY+1)       ;hl=rope at top of screen address
    ld      a,(B85D6)
    or      A
    jr      nz,R92D6 ;$+12
    ld      a,(ix+5)
    and     (hl)
    jr      z,R930E ;$+44
    ld      a,(ix+9)
    ld      (B85D6),a
    set     0,(ix+$0B)
.R92D6
    cp      (ix+9)
    jr      nz,R930E ;$+35
    bit     0,(ix+$0B)
    jr      z,R930E ;$+2F
    ld      b,(ix+3)
    ld      a,(ix+5)
    ld      c,1
    cp      4
    jr      c,R92FC ;$+11
    ld      c,0
    cp      16
    jr      c,R92FC ;$+0B
    dec     B
    ld      c,3
    cp      64
    jr      c,R92FC ;$+04
    ld      c,2
.R92FC
    ld      (W85D2),bc
    ld      a,iyl ;Undocumented
    sub     16
    ld      (WILLYY),a
    push    hl
    call    C8E9C
    pop     hl
;     jr   R930E     ;$+02

;plot the damn thing to screen..
.R930E
    ld      a,(ix+5)
    or      (hl)
    ld      (hl),a
    ld      a,(ix+9)
    add     a,(ix+1)
    ld      e,a
    set     7,e
    ld      d,0
    ld      hl,ropetable
    add     hl,de
;     ld      h,131
    ld      c,(hl)
    ld      b,0
    add     IY,bc
    res     7,e
    ld      d,0
    ld      hl,ropetable
    add     hl,de
    ld      a,(hl)
    or      A
    jr      z,R9350 ;$+29
    ld      b,a
    bit     7,(ix+1)
    jr      z,R9341 ;$+13
.R9330
    rlc     (ix+5)
    bit     0,(ix+5)
    jr      z,R933D ;$+05
    dec     (ix+3)
.R933D
    djnz    R9330     ;$-0D
    jr      R9350     ;$+11

.R9341
    rrc     (ix+5)
    bit     7,(ix+5)
    jr      z,R934E ;$+05
    inc     (ix+3)
.R934E
    djnz    R9341     ;$-0D
.R9350
    ld      a,(ix+9)
    cp      (ix+4)
    jr      z,R935E ;$+08
    inc     (ix+9)
    jp      L92B6

.R935E
    ld      a,(B85D6)
    bit     7,a
    jr      z,R936F ;$+0C
    inc     A
    ld      (B85D6),a
    res     0,(ix+$0B)
    jr      doguard_next     ;$+46

.R936F
    bit     0,(ix+$0B)
    jr      z,doguard_next ;$+40
    ld      a,(wspranim)
    bit     1,a
    jr      z,doguard_next ;$+39
    rrca
    xor     (ix+0)
    rlca
    rlca
    and     2
    dec     A
    ld      hl,B85D6
    add     a,(hl)
    ld      (hl),a
    ld      a,(exitU)
    ld      c,a
    ld      a,(ROOM)  ;Is upward exit = current room?
    cp      C
    jr      nz,R939B ;$+09
    ld      a,(hl)         ;If so, don't let Willy near the roof
    cp      $0C
    jr      nc,R939B ;$+04
    ld      (hl),$0C
.R939B
    ld      a,(hl)
    cp      (ix+4)
    jr      c,doguard_next ;$+14
    jr      z,doguard_next ;$+12
    ld      (hl),$F0
    ld      a,(WILLYY)
    and     $F8       ;11110111
    ld      (WILLYY),a
    xor     A
    ld      (flags),a
;     jr   doguard_next     ;$+02

.doguard_next
    ld      de,8
    add     ix,de
    jp      doguard1


;***END OF DO GUARDIANS

;Deleted some gubbins..

;Check to see if we have hit an object..

.ckobjects    
    ld      h,objtablehig
    ld      a,(objstklow) ;hl -> bottom of object stack
    ld      l,a
.ckobjects1
    ld      c,(hl)
    res     7,C
    ld      a,(ROOM)  ;Is this item in the current room?
    or      64
    cp      C
    jp      nz,ckobjects3  ;No
    ld      a,(hl)
    rlca
    and     1         ;Address = 0x5C00+(([hl]&0x80) << 1)+ [hl+256]
    add     a,bakscr2att/256
    ld      d,a
    inc     H
    ld      e,(hl)         ;de becomes address in 5C00-5DFF
    dec     H
    ld      a,(de)
    and     7         ;Is Willy at the item's coordinates?
    cp      7
    jr      nz,ckobjects2 ;$+3F

    ld      ix,itemtext  ;Increment onscreen item count
.incitems
    inc     (ix+2)
    ld      a,(ix+2)
    cp      '9'+1
    jr      nz,itemsound
    ld      (ix+2),'0'
    dec     ix
    jr      incitems     ;$-10


.itemsound
    ld      a,(myflags)
    rrca
    jp      c,skipitemsnd
    ld      a,($4B0)        ;Make item-collection sound.
    and     63
    ld      c,$80
.itemsound1
    out     ($B0),a
    xor     64             ;does border and speacker
    ld      e,a
    ld      a,$90
    sub     c
    ld      b,a
    ld      a,e
.itemsound2
    djnz itemsound2
    dec     c
    dec     c
    jr      nz,itemsound1
    call    ressound
;
.skipitemsnd
    ld      a,(itemcount) ;We've got another item
    inc     a
    ld      (itemcount),a
    jr      nz,gotobject  ;All done?
    ld      a,1
    ld      (STATUS),a     ;If that was the last object, flag it
.gotobject
    res     6,(hl)         ;Flag item as collected
    jr      ckobjects3

.ckobjects2
    ld      a,(ticktime) ;Ticker
    add     a,L       ;Add item number
    and     3
    add     a,3       ;A=4-7, item colour
    ld      c,a
    ld      a,(de)
    and     248
    or      C         ;Reset item ink to A
    ld      (de),a         ;(de -> item attributes)
;     ld      a,(hl)
    ld      a,d
    rlca
    rlca
;Adjusted for this set up..
    rlca
;     rlca
    and     8
    adc     a,bakscr2hig          ;de:=item address in main screen
    ld      d,a
    push    hl
;This is a kludge to make things flash on z88
    ld      hl,scrbitmap
    rr      c
    jr      c,ckobjects2_1
    ld      hl,blank  ;Item bitmap
.ckobjects2_1
    ld      b,8
.ckobjects2_2
    ld      a,(hl)
    ld      (de),a
    inc     hl
    inc     d
    djnz ckobjects2_2
    pop     hl
.ckobjects3
    inc     l         ;Next item
    jp      nz,ckobjects1
    ret


;print a sprite
;Entry: hl=screen address
;       de=sprite
;        c=flag (bit 0)
; if bit 0 set, check to see that it is clear before plotting, if not
;then say zap willy

.gdraw    
    ld      b,16     ;Draw generic sprite
.gdraw1
    bit     0,C
    ld      a,(de)
    jr      z,gdraw2 ;$+06
    and     (hl)
.CHEATMONSTER
    ret     nz
    ld      a,(de)
    or      (hl)
.gdraw2
    ld      (hl),a
    inc     L
    inc     de
    bit     0,C
    ld      a,(de)
    jr      z,gdraw3 ;$+06
    and     (hl)
    ret     nz
    ld      a,(de)
    or      (hl)
.gdraw3
    ld      (hl),a
    dec     L
    inc     de
    ld      a,h
    sub     bakscr2hig-64
    inc     a
    ld      h,a

    and     7
    jr      nz,gdraw4 ;$+12
    ld      a,H
    sub     8
    ld      h,a
    ld      a,L
    add     a,32
    ld      l,a
    and     224
    jr      nz,gdraw4 ;$+06
    ld      a,H
    add     a,8
    ld      h,a
.gdraw4
    ld      a,h
    add     a,bakscr2hig-64
    ld      h,a
    djnz    gdraw1     ;$-2E
    xor     A
    ret

.roomleft
    ld      a,(exitL)
    ld      (ROOM),a  ;Move left
    ld      a,(WILLYX)
    or      31
    and     254      ;Reset X to 30
    ld      (WILLYX),a
    pop     hl
    jp      drawroom

.roomright
    ld      a,(exitR) ;Move right
    ld      (ROOM),a
    ld      a,(WILLYX)     ;Reset X to 0
    and     $E0
    ld      (WILLYX),a
    pop     hl
    jp      drawroom

;Go to room above

.roomup
    ld      a,(exitU)
    ld      (ROOM),a
    ld      a,(WILLYX)
    and     31
    add     a,$A0
    ld      (WILLYX),a
    ld      a,bakscr2att/256+1
    ld      (WILLYX+1),a
    ld      a,$D0         ;Willy at floor level in room above
    ld      (WILLYY),a
    xor     A
    ld      (flags),a
    pop     hl
    jp      drawroom

.roomdown
    ld      a,(exitD)
    ld      (ROOM),a
    xor     A         ;Move Willy to top of new room.
    ld      (WILLYY),a     ;Willy at ceiling level in room above
    ld      a,(flags)
    cp      $0B
    jr      nc,roomdown1
    ld      a,2
    ld      (flags),a
.roomdown1
    ld      a,(WILLYX)
    and     31
    ld      (WILLYX),a
    ld      a,bakscr2att/256
    ld      (WILLYX+1),a
    pop     hl
    jp      drawroom

.doconvey
    ld      hl,(convsta)     ;Conveyor start
    ld      a,H
    and     1
    rlca
    rlca
    rlca
    add     a,bakscr1hig          ;7000h or 7800h CHANGE
    ld      h,a
    ld      e,L
    ld      d,H       ;de=dest. address
    ld      a,(convlen) ;Conveyor length
    or      A
    ret     Z
    ld      b,a       ;B=length
    ld      a,(convdir) ;Conveyor direction
    or      A
    jr      nz,doconvey2
    ld      a,(hl)         ;Animate the conveyor graphic
    rlc     A
    rlc     A
    inc     h
    inc     h
    ld      c,(hl)
    rrc     C
    rrc     C
.doconvey1
    ld      (de),a
    ld      (hl),c
    inc     l
    inc     e
    djnz    doconvey1
    ret

.doconvey2
    ld      a,(hl)    ;Moving the other way
    rrc     a
    rrc     a
    inc     h
    inc     h
    ld      c,(hl)
    rlc     c
    rlc     c
    jr      doconvey1

.domaria
    ld      a,(ROOM)
    cp      35       ;Master Bedroom
    jr      nz,dotoilet  ;Handle bathroom lavatory
    ld      a,(STATUS)     ;Should Maria be there at all?
    or      A
    jr      nz,domaria2
    ld      a,(ticktime) ;Ticker - is her foot down or up?
    and     2
    rrca
    rrca
    rrca
    rrca
    or      $80
    ld      e,a
    ld      a,(WILLYY)
    cp      $D0
    jr      z,domaria1        ;At ground level?
    ld      e,$C0
    cp      $C0      ;As we get higher,
    jr      nc,domaria1
    ld      e,$E0         ;Maria animates.
.domaria1
    ld      d,$9C          ;CHANGE
    ld      hl,9152         ;CHANGE - diff between sprites
    add     hl,de
    ex      de,hl
    ld      hl,mariapos  ;Write Maria-sprite.
    ld      c,1
    call    gdraw
    jp      nz,diewilly2
    ld      hl,$4545
    ld      (bakscr2att+$6E),hl     ;$5D6E
    ld      hl,$0707
    ld      (bakscr2att+$8E),hl     ;$5D8E
    ret

;Maria isn't there, so must touch the bed

.domaria2
    ld      a,(WILLYX)
    and  31
    cp   6
    ret  NC
    ld      a,2
    ld      (STATUS),a     ;When Willy hits the bed, switch to auto
    ret

.autoright
    ld      a,(ROOM)  ;Called when moving right on automatic
    cp   33       ;Bathroom?
    ret  nz
    ld      a,(WILLYX)
    cp   $bc
    ret  nz
    xor  A
    ld      (ticktime),a
    ld      a,3
    ld      (STATUS),a     ;Head down lavatory
    ret

.dotoilet
    ld      a,(ROOM)
    cp      33  ;Bathroom?
    ret     nz
    ld      a,(ticktime)
    and     1
    rrca
    rrca
    rrca
    ld      e,a       ;Lavatory sprite, Willy absent
    ld      a,(STATUS)
    cp      3
    jr      nz,dotoilet1
    set     6,E       ;Lavatory sprite, Willy present
.dotoilet1
    ld      d,$A6
    ld      ix,scrtable+$D0  ;T82D0  ;Lookup table entry      ;CHANGE
    ld      bc,$101C
    call    pdraw
    ld      hl,$0707
    ld      (bakscr2att+$bc),hl     ;$5DBC
    ld      (bakscr2att+$DC),hl     ;$5DDC
    ret

.C95C8
    ld      hl,(WILLYX)
    ld      b,0
    ld      a,(rampdir)
    and     1
    add     a,$40
    ld      e,a
    ld      d,0
    add     hl,de
    ld      a,(rampdata)
    cp      (hl)
    jr      nz,R95F8 ;$+1C
    ld      a,(flags)
    or      A
    jr      nz,R95F8 ;$+16
    ld      a,(W85D2)
    and     3
    rlca
    rlca
    ld      b,a
    ld      a,(rampdir)
    and     1
    dec     a
    xor     $0C
    xor     b
    and     $0C
    ld      b,a
.R95F8
    ld      hl,(WILLYX)
    ld      de,$1F
    ld      c,$0F
    call    C961E
    inc     hl
    call    C961E
    add     hl,de
    call    C961E
    inc     hl
    call    C961E
    ld      a,(WILLYY)
    add     a,b
    ld      c,a
    add     hl,de
    call    C961E
    inc     hl
    call    C961E
    jr      R9637     ;$+1B

.C961E
    ld      a,(airdata)
    cp      (hl)
    jr      nz,R962F ;$+0D
    ld      a,C
    and     $0F
    jr      z,R962F ;$+08
    ld      a,(airdata)
    or      7
    ld      (hl),a
.R962F
    ld      a,(firedata)
;added in 19/7/98
    cp      255
    ret     z
    cp      (hl)
    jp      z,diewilly
    ret

.R9637
    ld      a,(WILLYY)
    add     a,b
    ld      ixh,scrtablehig    ;Undocumented      CHANGE
    ld      ixl,a ;ix:=T8200+WILLYY+B
    ld      a,(wspranim)
    and     1
    rrca
    ld      e,a
    ld      a,(W85D2)
    and     3
    rrca
    rrca
    rrca
    or      e
    ld      e,a
    ld      d,$9D       ;Willy sprite at 9Dxxh
;
;This could be changed to: ld a,(ROOM+xxh) ! or A ! jr z, R9660 ! ld d,a
;
    ld      a,(ROOM)  ;The Nightmare Room
    cp      29
    jr      nz,notnightmare ;$+08
    ld      d,$B6
    ld      a,e       ;Pig sprite at B6xxh.
    xor     $80
    ld      e,a
.notnightmare
    ld      b,16          ;de=sprite address
    ld      a,(WILLYX)
    and     31       ;B=sprite height
    ld      c,a       ;C=sprite X
           ;ix -> mask lookup table entry
.pdraw
    ld      hl,9152         ;CHANGE diff between sprite
    add     hl,de
    ex      de,hl
.pdraw1
    ld      a,(ix+0)
    ld      h,(ix+1)  ;H=back screen address (back screen at 6000h)
    or      c         ;Low byte = height offset
    ld      l,a       ;hl=byte base address
    ld      a,(de)
    or      (hl)
    ld      (hl),a
    inc     hl
    inc     de
    ld      a,(de)
    or      (hl)
    ld      (hl),a
    inc     ix
    inc     ix
    inc     de
    djnz    pdraw1
    ret


;print routine:
;Entry: l=text to print
;       de=screen location to print to
;        d=y, e=x (+32 as for OZ)
;To be rewritten for z88

.print32
    ld      c,32
.print
    push    hl
    push    bc      ;keep number to print
    ;Move to Correct Location
    push    de
    ld      hl,printtext
    call_oz(gn_sop)
    pop     de
    ld      a,e
    call_oz(os_out)
    ld      a,d
    call_oz(os_out)
    ;Restore what we pushed...
    pop     bc
    pop     hl
.print1
    ld      a,(hl)
    call_oz(os_out)
    inc     hl
    dec     c
    jr      nz,print1
    ret




;Play title tune!

.tuneplay
    ld      a,(myflags)
    rrca
    jr      c,notuneplay
    ld      a,(hl)    ;Play a little tune
    cp      255
    ret     z

    ex      af,af'
    ; call    oz_di
    ; push    af
    ex      af,af'
    ld      bc,100
    ld      a,($4B0)
    and     63
    ld      e,(hl)
    ld      d,E
.tuneplay1
    out     ($B0),a
    dec     d
    jr      nz,tuneplay2
    ld      d,E
    xor     64
.tuneplay2
    djnz    tuneplay1
    ex      af,af
    ld      a,C
    cp      $32
    jr      nz,tuneplay3
    rl      e
.tuneplay3
    ex      af,af' 
    dec     c
    jr      nz,tuneplay1
    call    ressound
    ; pop     af
    ; call    oz_ei
    call    tunekey
    scf
    ret     z
    inc     hl
    jr      tuneplay     ;$-25

.notuneplay
    call    tunekey
    scf
    ret     z
    and     a
    jr      notuneplay


;Checks for ENTER (using OZ)
.tunekey
    call    ozread
    cp      13
    ret     z
    and     223
    cp      'R'
    ret



;This is the weird sound effect on scroll
;It's a bit dodgy..doing it this way...
;Probably won't work at all...CHANGE?
;Have to adapt this one slightly for no sound..
;Should be OK..simply won't come here!

.scrollsnd
    push    hl
    ex      af,af
    call    oz_di
    push    af
    ex      af,af
    ld      l,a
    ld      e,a
    ld      c,$B0
.scrollsnd1
    ld      a,l
    and     64
    ld      d,a
    ld      a,($4B0)
    and     63
    or      d
    ld      d,a
    ld      b,e
.scrollsnd2
    cp      b
    jr      nz,scrollsnd3
    ld      a,($4B0)
    and     63
    or      64
    ld      d,a
.scrollsnd3
    out     (C),d
    djnz    scrollsnd2
    dec     l
    jr      nz,scrollsnd1
    call    ressound
    pop     af
    call    oz_ei
    pop     hl
    ret

.dosound1
    ld      a,(myflags)
    rrca
    ret     c
    call    oz_di
    push    af
    ld      a,($4B0)
    and     63
.sound1_1
    out     ($B0),a
    xor     64
    ld      b,d
.sound1_2
    djnz sound1_2
    dec     c
    jr      nz,sound1_1 ;$-08
    pop     af
    call    oz_ei
.ressound
    ld      a,($4B0)
    and     63
    out     ($B0),a
    ld      ($4B0),a
    ret


;Routines to regenerate the display after being preempted..
.introsetup
    call    windclr
    ld      hl,(genpos)
    ld      h,0
    ld      de,scrolltext
    add     hl,de
    ld      de,8192+32+256  ;(1,0)
    call    print32
    ld      hl,redefprt
    ld      de,8192+33+768
    call    print32
.dotitlescr
    ld      hl,titscrstore
    ld      de,bakscr2
    ld      bc,506
    ldir 
    call    bakscr2
    ld      a,(myflags)
    and     @00100001       ;allow cheat to fall thru
    or      @00000010       ;set standard
    ld      (myflags),a
    xor     a
    ld      (WILLYY),a
    call    ozscrcpy
    xor     a
    ret




.gameinfo
    call    windclr
    call    ozscrcpy
    call    displegends
    call    dispcounts
    ld      hl,myflags
    bit     7,(hl)
    jp      nz,ppausetx
.prlives
    ld      hl,livest
    ld      de,9216+32+11          ;4,11
    ld      c,8
    call    print     
    ld      a,(LIVES)
    cp      8
    jr      c,gameinfo1
    ld      a,'C'-48
.gameinfo1
    add     a,48
    call_oz(os_out)
    ret

.dispcounts
    ld      hl,CTIME  ;print time
    ld      de,8761            ;(2,25)
    ld      c,6
    call    print
    ld      hl,itemtext  ;print items count
    ld      de,8752             ;(2,16)
    ld      c,3
    call    print
    ret



.displegends
    ld      hl,cur_room_tit  ;Room title
    ld      de,8192+32          ;(0,0)
    call    print32
    ld      hl,iteminfot
    ld      de,8704+32          ;(2,0)
    call    print32           
    ret

.ppausetx
    ld      hl,pauset
    ld      c,9
    ld      de,9216+32+11
    call    print
    ret



;Redefine keys, clear window, input, and then jp to introscreen
.redefine
    ld      hl,myflags
    set     2,(hl)
    ld      bc,10
    call_oz(os_dly)
    ld      b,5
    ld      hl,pkeys
    ld      de,deftext
.redefine1
    push    bc
    push    hl
    ld      (redefpos),de
    call    redefsetup
    inc     hl
    push    hl


.redefine2
    call    ozread
    call    kfind
    jr      nz,redefine2
    inc     d
    jr      z,redefine2
    dec     d
    push    de
    call    mapkey
    pop     bc
    jr      z,redefine2
    push    bc
    call    soundfx3
    pop     bc
    pop     de
    pop     hl
    ld      (hl),b
    inc     hl
    ld      bc,10
    call_oz(os_dly)
    pop     bc
    djnz    redefine1
;Check for cheat?
    ld      hl,pkeys
    ld      de,cheatkey
    ld      b,5
.ckcheat1
    ld      a,(de)
    cp      (hl)
    jr      nz,nodefcheat
    inc     hl
    inc     de
    djnz    ckcheat1
    call    warpcall
    ld      hl,myflags
    set     5,(hl)
.nodefcheat
    ld      hl,myflags
    res     2,(hl)
    jp      gamein

.defintro
    defb    1,'3','@',33+3,33
    defm    "ENTER KEY FOR:"
    defb    1,'3','@',33+5,35,0

.deftext
    defm    "RIGHT...\x00"
    defm    "LEFT....\x00"
    defm    "PAUSE...\x00"
    defm    "MUSIC...\x00"
    defm    "JUMP....\x00"

.redefsetup
    call    windclr
    ld      hl,defintro
    call_oz(gn_sop)
    ld      hl,(redefpos)
    call_oz(gn_sop)
    ret



;Oz stuff here...

;Blah, blah, blah...oz routines!!!


;Sort of strange warping sound
;Rising and falling..
    
.warpcall
    ld    hl,1600  
    ld    (snd_wkspc+5),hl
    ld    hl,-800  
    ld    (snd_wkspc+1),hl
    ld    hl,-100  
    ld    (snd_wkspc+3),hl
    ld      b,20
.warpcall1
    push bc
    call warps
    pop     bc
    djnz warpcall1
    ret   
    
.warps    ld    hl,(snd_wkspc+5)
    ld    de,6  
    call  beeper  
.warps1   ld    hl,(snd_wkspc+1)
.warps2   ld    de,(snd_wkspc+3)
    and   a  
    sbc   hl,de  
    ld    (snd_wkspc+1),hl
    jr    nz,warps3  
    ld    de,100  
    ld    (snd_wkspc+3),de
.warps3   ex    de,hl  
    ld    hl,1600  
    add   hl,de  
    ld    (snd_wkspc+5),hl
    ret   
    



;Make a beep (use for key define!)


.soundfx3
    ld      a,(myflags)
    rrca
    ret     c
    call  oz_di    
    push af
    ld      a,($4B0)
    and  63
    ld      ($4B0),a
    out  ($B0),a
    ld    e,150  
.fx2_1    out   ($B0),a  
    xor   64  
    ld    b,e  
.fx2_2    djnz  fx2_2  
    inc   e  
    jr    nz,fx2_1  
    pop     af
    call  oz_ei    
    ret 

.beeper
    ld      a,(myflags)
    rrca
    ret  c
    call    oz_di
    push    af
    ld       a,l
    srl     l
    srl     l
    cpl
    and     3
    ld      c,a
    ld      b,0
    ld      ix,beixp3
    add     ix,bc
    ;OZ stuff here..
    ld      a,($4B0)
    and     63
    ld      ($4B0),a
    out     ($B0),a
.beixp3
    nop
    nop
    nop
    inc  b
    inc  c
.behllp   
    dec     c
    jr      nz,behllp
    ld      c,$3F
    dec     b
    jp      nz,behllp
    xor     64
    out     ($B0),a
    ld      b,h
    ld      c,a
    bit     6,a            ;if o/p go again!
    jr      nz,be_again
    ld      a,d
    or      e
    jr      z,be_end
    ld      a,c
    ld      c,l
    dec     de
    jp      (ix)
.be_again
    ld      c,l
    inc     c
    jp      (ix)
.be_end
    pop     af
    call    oz_ei
    ret



.oz_init
    ;Do OZ stuff now..
    ld      hl,baswindres
    call_oz(gn_sop)
    call    windsetup
    call    tablesetup
    ld      hl,pkeys_default
    ld      de,pkeys
    ld      bc,8
    ldir
    xor     a
    ld      (myflags),a
    ret


.windsetup
    ld      hl,windini
    call_oz(gn_sop)
    ld       a,'5'          ;window number - ignored!
    ld      bc,mp_gra
    ld      hl,255
    call_oz(os_map)          ; create map width of 256 pixels
    ld      b,0
    ld      hl,0             ; dummy address
    ld      a,sc_hr0
    call_oz(os_sci)          ; get base address of map area (hires0)
    push    bc
    push    hl
    call_oz(os_sci)          ; (and re-write original address)
    pop     hl
    pop     bc
    ld       a,b
    ld      (ozbank),a
    ld      a,h
    and     63                ;mask to bank
    or      128               ;mask to segment 2 (32768)
    ld      h,a
    ld      (ozaddr),hl
    ret

.tablesetup
    ld      b,128
    ld      hl,scrtable
    ld      de,bakscr2
.ozinit1  
    ld      (hl),e
    inc     hl
    ld      (hl),d
    inc     hl
    ld      a,d
    add     a,64-bakscr2hig
    ld      d,a
    call    drow
    ld      a,d
    sub     64-bakscr2hig
    ld      d,a
    djnz    ozinit1
    ret

.drow
    inc     d
    ld      a,7      ;was 7  
    and     d  
    ret     nz
    ld      a,e  
    add     a,32  
    ld      e,a  
    ret     c
    ld      a,d
    sub     8  
    ld      d,a  
    ret

;Clear the back screen
.cls
    xor     a
    ld      hl,bakscr2
    ld      de,bakscr2+1
    ld      bc,4095  ;Clear top 2/3 of screen
    ld      (hl),a
    ldir
    ret



.baswindres
;          defm ""&1&"2H1"&$0C&$0

.clrscr
   defb    1,'7','#','3',32,32,32+94,32+8,128,1,'2','C','3',0

    
.windini
    defb    1,'7','#','3',32+7,32+1,32+34,32+7,131     ;dialogue box
    defb    1,'2','C','3',1,'4','+','T','U','R',1,'2','J','C'
    defb    1,'3','@',32,32  ;reset to (0,0)
    defm    "Jet Set Willy z88"
    defb    1,'3','@',32,32 ,1,'2','A',32+34  ;keep settings for 10
    defb    1,'7','#','3',32+8,32+3,32+32,32+5,128     ;dialogue box
    defb    1,'2','C','3'
    defb    1,'3','@',32,32,1,'2','+','B'
    defb    0
.windclr
    ld      hl,windclrt
    call_oz(gn_sop)
    ret


.windclrt
    defb 1
    defm "2C3\x012+B"
    defb  0


;       Hard Coded Data - Will not Change

;rope table...

;Tricky, the blank character uses part of the ropetable!
.blank    
.ropetable
    DefB   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DefB   1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2
    DefB   2,2,1,2,2,1,1,2,1,1,2,2,3,2,3,2,3,3,3,3,3,3,0,0,0,0,0,0
    DefB   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DefB   0,0,0,0,0,0,0,0,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
    DefB   6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
    DefB   4,6,6,4,6,4,6,4,6,4,4,4,6,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4
    DefB   4,4,4,4,4,4,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DefB   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;


;These are the sprite order for willy...
.wsprtab
    defb   0,1,0,1,1,3,1,3,2,0,2,0,0,1,2,3

.scrolltext
    defm   "+++++ Press ENTER to Start +++++  JET-set WILLY by Matthew "
    defm   "Smith  "
    defb   'C'
    defm   " 1984 SOFTWARE PROJECTS Ltd . . . . .Guide Willy to collect"
    defm   " all the items around the house before Midnight so Maria"
    defm   " will let you get to your bed. . . . . . .+++++ Press"
    defm   " ENTER to Start +++++"

.iteminfot   
    defm     "Items collected "
    defm     "000 Time "   ;00:00 m"
    defm     " 7:00am"
.gameovert
    defm   "\x01FGame Over!\x01F"
.livest      defm   "Lives ="      ;space flowing on into pauset
.pauset      defm   " Paused! "
.redefprt    defm   "  (Press \x01RR\x01R to redefine keys)"

.writetype
    defb    27,29,62,30,28,30,31,59,28,29    ;writetyper..

;Start of text to move to location
.printtext
    defb    1,'3','@',0

.cheatkey
    defb    61,29,62,28,50

.pkeys_default
    defb    59,61,39,15,10,16,17,7


.tunedata
    defb    $51,$3c,$33,$51,$3c,$33,$51,$3c,$33,$51,$3c,$33,$51,$3C
    defb    $33,$51,$3c,$33,$51,$3c,$33,$51,$3c,$33,$4c,$3c,$33,$4C
    defb    $3c,$33,$4c,$39,$2d,$4c,$39,$2d,$51,$40,$2d,$51,$3c,$33
    defb    $51,$3c,$36,$5b,$40,$36,$66,$51,$3c,$51,$3c,$33,$51,$3C
    defb    $33,$28,$3c,$28,$28,$36,$2d,$51,$36,$2d,$51,$36,$2d,$28
    defb    $36,$28,$28,$3c,$33,$51,$3c,$33,$26,$3c,$2d,$4c,$3c,$2D
    defb    $28,$40,$33,$51,$40,$33,$2d,$40,$36,$20,$40,$36,$3d,$79
    defb    $3d,$FF  ;Title screen tune

;       The InGame Tune - If I Was A Rich Man
.richman
    BINARY "assets/richman.mus"

;       The Title Screen Logo
.titscrstore
    BINARY "assets/jsw.scr"


;       Below here will be all the variables




DEFVARS         var_base
{
ROOM            ds.b    1
ticktime        ds.b    1
LIVES           ds.b    1
B85CD           ds.b    1
WILLYY          ds.b    1
wspranim        ds.b    1
flags           ds.b    1
W85D2           ds.b    1
WILLYX          ds.w    1
B85D5           ds.b    1
B85D6           ds.b    1
initdata        ds.b    7
itemcount       ds.b    1
STATUS          ds.b    1
pausect         ds.b    1
TICKER          ds.b    1
T85E2           ds.b    1
myflags         ds.b    1
wtmode          ds.b    1
genpos          ds.b    1
plotroom3_var   ds.b    1
ozbank          ds.b    1
ozaddr          ds.w    1
key             ds.b    1
pkeys           ds.b    8
snd_wkspc       ds.w    2
myworksp        ds.w    1
redefpos        ds.w    1
CTIME           ds.w    1
ctimecol        ds.b    1
CTIME1          ds.w    1
ctimeper        ds.w    1
itemtext        ds.b    3
guardwork       ds.b    64
guardend        ds.b    1
}