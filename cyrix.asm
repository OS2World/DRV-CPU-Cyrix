        page    50,132
        .286

        .xlist
        INCL_BASE  equ  1
        include OS2.INC
        .list

        extrn   DosWrite:far

        public  header
        public  devhlp
        public  msg1
        public  msg2
        public  msg3
        public  cBytesWritten
        public  tInterrupt
        public  fError
        public  fEnabled
        public  strategy
        public  init
        public  enable
        public  strategy9
        public  dataPtr

DGROUP  group   _DATA

_DATA   segment word    public  'DATA'
header  label   dword
        dd      -1
        dw      1000000010000000b       ; char device, OS/2 1.x level
        dw      strategy
        dw      0
        db      'Cyrix   '
        db      8 dup (0)

        align   4
devhlp  label   dword
        dw      ?
        dw      ?

fEnabled        label   byte
        db      -1                      ; -1 => cache not enabled
                                        ; 0 => cache enabled
        ;
        ; put all data to remain resident before msg1
        ;
msg1    label   byte
        db      13,10,10
        db      'Cyrix Device Driver version 1.0.'
        db      13,10
msg1_l  equ     ($ - offset msg1)

msg2    label   byte
        db      13,10,10
        db      'Install failed.'
        db      13,10
msg2_l  equ     ($ - offset msg2)

msg3    label   byte
        db      13,10,10
        db      'Install successful.'
        db      13,10
msg3_l  equ     ($ - offset msg3)

fError  label   byte
        db      -1                      ; -1 => install failed
                                        ; 0 => install successful
cBytesWritten   label   word
        dw      ?

_DATA   ends

_TEXT   segment word    public  'CODE'
        assume  cs:_TEXT, ds:DGROUP, es:NOTHING

strategy        proc    far
;;;;        int 3
        cmp     byte ptr es:[bx+2],0    ; init?
        mov     ax,8103h                ; assume not
        jne     strategy9

        call    init
        jc      @F

        mov     byte ptr fError,0       ; signal no error during install

@@:
        ;
        ; assume error occurred during install
        ;
        lea     ax,DGROUP:msg2
        mov     cx,msg2_l
        cmp     byte ptr fError,0
        jne     @F

        lea     ax,DGROUP:msg3
        mov     cx,msg3_l

@@:
        push    1
        push    ds
        push    ax              ; offset of message

        push    cx              ; length of message

        push    ds              
        push    offset DGROUP:cBytesWritten

        call    DosWrite

        mov     ax,0810ch               ; error, done, general failure
        cmp     byte ptr fError,-1
        je      strategy9

        mov     ax,0100h                ; no error, done

strategy9:
        mov     word ptr es:[bx+3],ax
        ret
strategy        endp

enable  proc    near
        .386p

        push    eax
        push    ebx

        cli
        jmp     $+2

        ; disable cache filling & flush cache
        mov     eax,cr0
        mov     ebx,eax         ; save copy cr0

        and     eax,(10011111111111111111111111111111b)
        mov     cr0,eax

        ; flush cache
        db      00001111b, 00001000b    ; invalidate cache (invd)

        ; turn on NC0, NC1, & BARB
        ; NC0
        ; bit 0 = 1 inhibits caching  1st 64K bytes at each 1Mb boundary
        ;
        ; NC1
        ; bit 1 = 1 inhibits caching of memory addresses 09ffffh to 0ffffffh
        ; 
        ; BARB
        ; bit 5 = 1 forces cache to flush when HOLD state entered
        ; (HOLD state entered when BUS master active (or DRAM refresh?)
        ;
        mov     al,0c0h
        out     22h,al
        mov     al,23h
        out     23h,al

        ; set start address equal to 0 & block size to disabled for NCR1
        mov     al,0c5h
        out     22h,al
        mov     al,0
        out     23h,al
        mov     al,0c6h
        out     22h,al
        mov     al,0
        out     23h,al

        ; set start address to 0 & block size to disabled for NCR2
        mov     al,0c8h
        out     22h,al
        mov     al,0
        out     23h,al
        mov     al,0c9h
        out     22h,al
        mov     al,0
        out     23h,al

        ; set start address to 0 & block size to disabled for NCR3
        mov     al,0cbh
        out     22h,al
        mov     al,0h
        out     23h,al
        mov     al,0cch
        out     22h,al
        mov     al,0h
        out     23h,al

        ; set start address to 0 & block size to disabled for NCR4
        mov     al,0ceh
        out     22h,al
        mov     al,0h
        out     23h,al
        mov     al,0cfh
        out     22h,al
        mov     al,0
        out     23h,al

        ; enable cache filling
        mov     eax,ebx         ; restore cr0
        or      eax,01100000000000000000000000000000b
        mov     cr0,eax

        pop     ebx
        pop     eax

        sti

        .286
        ret
enable  endp

        align   4
dataPtr label   word
        dw      _DATA

        align   4
tInterrupt      proc    far
        ; must save used registers
        push    cx
        push    ds

        ;
        ; point DS to local data
        ;
        mov     ds,cs:dataPtr

        ;
        ; see if we been here before
        ;
        xor     cx,cx
        xchg    cl,fEnabled
        jcxz    tInterrupt9

        call    enable

        align   4
tInterrupt9:
        pop     ds
        pop     cx
        ret
tInterrupt      endp

        ;
        ; put all code to remain resident before init
        ;
init    proc    near
        ;
        ; announce presence
        ;
        push    1
        push    ds
        push    offset DGROUP:msg1
        push    msg1_l

        push    ds
        push    offset DGROUP:cBytesWritten
        call    DosWrite

        ;
        ; save address of devhlp entry point
        ;
        mov     ax,es:[bx+14]
        mov     word ptr devhlp+0,ax
        mov     ax,es:[bx+16]
        mov     word ptr devhlp+2,ax

        ;
        ; add timer handler to list of timer handlers
        ;
        lea     ax,_TEXT:tInterrupt
        mov     dl,29                   ; add timer function
        call    devhlp
        jnc     @F

        ;
        ; call failed => don't install driver
        ;
        mov     word ptr es:[bx+14],0
        mov     word ptr es:[bx+16],0
        jmp     short init9

@@:
        ;
        ; tell kernel what to keep resident
        ;
        mov     word ptr es:[bx+14],offset CS:init
        mov     word ptr es:[bx+16],offset DGROUP:msg1

init9:
        ret
init    endp

_TEXT   ends

        end
