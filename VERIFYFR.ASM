.model tiny
.286
.code
org 100h
										; cx - the number of the line being processed (counting from above)
										; ax - the absolute index of the last cell of the frame in this line
										; bx - the current index of the cell of the frame in this line
										; 1 SYMBOL == 2 BYTES (!!!)
CMD_PTR equ 81h
VIDEO_PTR equ 0b800h
cnsl_width equ 80d					; maximum number of symbol per line (in symbols)
top_ind equ 6					; number of symbols from above from the outloop frame (in symbols)
left_ind equ 12					; number of symbols on the left of the outloop frame (in symbols)
rel_top_ind equ 2			; number of symbol from upper outloop side to upper inside side (in symbols)
shadow_colour equ 72d

Start:	jmp main

;==========================================================
; PURPOSE: It is main procedure. Is engaged in calling functions and exiting program
; ENTRY: -
; ASSUMES: ES = 0b8000h
; DESTR: -
;==========================================================
MAIN proc
    call MAKE_FRAME
    lea bx, buffer
    mov di, buf_es_adr
    mov si, buf_es_adr
    add si, 40
    text_input:
    mov ch, 01h
    mov ah, 0
    int 16h             ; Reading keyboard input.
    cmp ah, 1ch
    je cmp_pass
    cmp ah, 0eh
    je clear

    add_new:
    mov [bx], al
    inc bx
    cmp di, si
    je text_input
    mov es:[di], ch
    inc di
    inc di
    jmp text_input

    clear:
    cmp di, buf_es_adr
    je text_input
    dec di
    dec di
    mov ch, 20h
    mov es:[di], ch
    dec bx
    mov ch, ?
    mov [bx], ch
    jmp text_input

    cmp_pass:
        call CHECKING_PASS
MAIN endp
;=======================================================================
; PURPOSE: paint frame in image memory.
; ENTRY: -
; ASSUMES: ES = 0b8000h
; DESTR:
;=======================================================================
MAKE_FRAME proc

    mov ax, 1003h
    mov bl, 00h
    int 10h

	mov bx, VIDEO_PTR						; The procedure for writing an
	mov dl, 32d							; address to a video memory segment
	mov es, bx
	mov cx, min_cx					; cx - the number of the line being processed (counting from above)
    mov Bx, start_bx

outer_loop:
    inc cx
	add bx, 2 * cnsl_width		; bx - the current index of the cell of the frame in this line
	cmp cx, max_cx
	jae make_shadow_line
										; Internal loop cycxes through columns
    									; incresing argument 'bx'
	call FILL_LINE					; checking what symbol should be next
    jmp outer_loop
make_shadow_line:
    call MAKE_SHADOW

    RET
MAKE_FRAME endp
;=======================================================
; PURPOSE: FILLS IN A ROW FROM 'BX' TO FILLING THE FRAME AFTER
; ENTRY: BX - POINTER TO FILLING CHARACTERS
;        DI - POINTER TO THE LINE TO BE FILLED IN
; ASSUMES: -
; DESTR: AX, BX
;=======================================================
FILLING proc
        xor ah, ah
        push cx
        add bx, frame_kind
        mov ax, ' '          ; AL - current filling symbol
        mov cx, 2            ; indent from left outloop frame side to left inside frame side
        call POPULATING
        mov cx, 1
        mov al, [bx]
        call POPULATING
        mov cx, fr_len
        sub cx, 6
        mov al, [bx+1]
        call POPULATING
        mov cx, 1
        mov al, [bx+2]
        call POPULATING
        mov cx, 1           ; indent from right outloop frame side to right inside frame side
        mov ax, ' '
        call POPULATING
        mov byte ptr es:[di+1], dl
        pop cx
        ret
FILLING endp
;============================================================
; PURPOSE: multiplies the character specified in al by the index di
; ENTRY: CX - number of filled symbols
;        dl - code of frame colour
;        di - index of first symbol
; ASSUMES: ES = 0b8000h
; DESTR: CX, DI
;============================================================
POPULATING proc
    next: stosw
        mov byte ptr es:[di-1], dl
    loop next
    RET
POPULATING endp
;============================================================
; Checking what symbol should be next
; ENTRY: cx - number of current line
; 		 bx - the current index of the cell of the frame in this line
;		 dl - code of current symbol
; ASSUMES: ES = 0b800h
; DESTR: NOTHING
; CHANGE: dl, SI, AX
;============================================================
FILL_LINE	proc
    push bx
    mov di, bx
    mov dl, byte ptr frame_colour
	cmp cx, in_frame_upper
	je upper
	jb other

	cmp cx, in_frame_lower
	je lower
	ja other

    inside:
        lea bx, middle_symb
        jmp continue
    upper:
        lea bx, top_symb
        jmp continue
    lower:
        lea bx, lower_symb
        jmp continue
    other:
        lea bx, other_symb

    continue:
        call FILLING
        pop bx
        cmp cx, mm_cx
        jne shadow
        ret
    shadow:
        mov byte ptr es:[di+3], shadow_colour

        cmp cx, in_frame_upper
        je put_heading
        cmp cx, in_frame_with_text
        je put_text
        ret

    put_heading:                            ; put the heading in the middle ot top frame
        push cx
        lea si, heading
        mov di, bx
        mov ax, fr_len
        sub ax, heading_len
        add di, ax
        div hui
        mov al, ah
        xor ah, ah
        add di, ax                          ; let's make sure that 'di' are even
        mov cx, heading_len
        put_title_symb: movsb
            inc di
        loop put_title_symb
        pop cx
        ret

    put_text:                               ; put the text inside the frame

        mov di, bx
        add di, 8
        mov buf_es_adr, di

        ret
FILL_LINE	endp
;===============================================================
; Puts the shadow effect in the right places
; ENTRY: cx - counter of lines
;		 bx - absolute counter of cell
; ASSUMES: ES = 0b800h
; DESTR: bx
;===============================================================
MAKE_SHADOW proc
    add bx, 2
    push cx
    cld
    mov cx, fr_len
    mov di, bx
    mov al, ' '
    next33: stosw
            mov byte ptr es:[di-1], shadow_colour
        loop next33
	pop cx
    ret
MAKE_SHADOW endp
;================================================================
; PURPOSE: the main function of the program
; ENTRY: string from STANDART INPUT
; ASSUMES: CS
;================================================================
CHECKING_PASS proc
    lea si, left_canary
    lea di, right_canary
    mov cx, canary_len
    mov ah, 0d
    call VERIFICATION       ; Checking the Canary's health

    lea si, buffer
    lea di, password
    mov cx, pass_len
    mov ah, 2d
    call VERIFICATION       ; Checking the password accuracy

    lea si, right_pass_alert
    mov cx, 43
    call PUT_ALERT
    call EXIT
CHECKING_PASS endp

;=======================================
; PURPOSE: Checking 2 string's equivalence
; ENTRY: SI - address of the 1st string
;        DI - address of the 2nd string
;        CX - length of the strings
;        AH - shift
; ASSUMES: CS
; DESTR: SI, DI, CX
;=======================================
VERIFICATION proc
    push es
    push ds
    pop es
    cld
    add ds:[si], ah
    cont_cmp: CMPSB                  ; Comparison of the strings
        jnz verify_died             ; If at least one pair of symbols are different - jump to the 'verify_died'
        add ds:[si], ah     ; THE CAESAR ENCODING
    loop cont_cmp
    pop es
    ret

    verify_died:
        pop es
	    lea si, wrong_pass_alert
        mov cx, 43
        call PUT_ALERT
        call EXIT
VERIFICATION endp
;=========================================
; PURPOSE: put message into the frame
; ENTRY: si - address of the message's text
;        di - address of the first symbol in frame
;        cx - length of the text
; ASSUMES: ES = 0B800H
; DESTR: DI, SI, CX
;=========================================
PUT_ALERT proc
    CLD
    mov di, buf_es_adr
    put_text_symb: movsb
        inc di
    loop put_text_symb
    ret
PUT_ALERT endp
;=========================================
; PURPOSE: Exit program
; ENTRY: -
; ASSUMES: CS
;=========================================
EXIT proc
    MOV AX, 4C13H
	INT 21H
    ret
EXIT endp
;============================================================
top_symb db '+-+...111'
middle_symb db '| |. .1 1'
lower_symb db '+-+...111'
other_symb db '         '
;=================================================================
fr_high dw 5                            ; outloop frame's height (in symbols)
fr_len dw 50                            ; outloop frame's width (in symbols)
frame_colour dw 139                       ; code of colour of the frame
frame_kind dw 0                         ; a configuration of inside frame (array '...symb')
N db 10
buf_es_adr dw 0
;=================================================================
mm_cx dw top_ind + 1        ; first line where the shadow is painted
min_cx dw top_ind		 	; start value of 'cx'
max_cx dw top_ind + 7		; finish 'cx' value
in_frame_upper dw top_ind + rel_top_ind ; number of symbol from upper console side to inside frame upper side
in_frame_with_text dw top_ind + rel_top_ind + 1
in_frame_lower dw top_ind + rel_top_ind + 3 ; number of symbol from upper console side to inside frame lower side
start_bx dw (top_ind * cnsl_width + left_ind) * 2	; start value of 'ax'
heading_len dw 14
heading db 'ENTER_PASSWORD'
hui db 2
;=================================================================
pass_len dw 15                         ; length of the right password
canary_len dw 3                        ; length of the left and right canary
left_canary db 'rip'
buffer db 15 DUP(?)              ; buffer that contains input string
right_canary db 'rip'
password db 'hkpcnaeqwpvfqyp'          ; right password

right_pass_alert db 'Success!!!', 40 DUP(' ')        ; message about right password
wrong_pass_alert DB 'Wrong password', 40 DUP(' ')    ; message about wrong password
end Start
