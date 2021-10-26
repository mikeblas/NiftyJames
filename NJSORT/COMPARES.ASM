
;   Nifty James' Famous Sort Tool
;	assembly language support module
;   Copyright 1988 by Mike Blaszczak
;   Version 1.00 of 08 May 1988
;   Version 1.05 of 19 May 1988
;   Version 1.10 of 03 July 1988
; for Microsoft Macro Assembler Version 5.10/DOS

;   This module provides fast compare routines for the main .C module.

;   Four compare routines are provided:

;	comp_0
;   Compare the two strings, paying attention only to reversed sort order.

;	comp_1
;   Compare the two strings, paying attention only to reversed sort order
;   and case insensitivity.

;	comp_2
;   Compare the two strings, paying attention to case insensitivity,
;   whitespace skipping, and reversed sort order.

;	comp_3
;   Compare the two strings, paying attention to case insnesitivity,
;   whitespace skipping, reversed sort order, and sort key fields or
;   columns.

;	comp_bin
;   Compare the two strings, treating them as binary data strings.
;   This compare is affected by order, only.  The compares are limited
;   in length only by their size -- there is no terminating character.


;   One support routine is provided:

;	checkblank
;   Determines if the passed string is a blank line.  Returns 0
;   if it is not a blank line or if skipblanks is not set.  Returns 1
;   if skipblanks is set and the line is empty or contains only
;   whitespace.

;   all comp_x routines accept two pointers to strings
;   all comp_xp routines accept two pointers to pointers to strings
;   checkblank accepts a pointer to a string
;   all routines return a signed integer

;   THIS MODULE IS HARDCODED FOR USE WITH THE COMPACT MODEL.

tab	equ	9
space	equ	32

	.model	compact,C
	.data

	extrn	seper:byte
	extrn	reversed:byte
	extrn	ignorewhite:byte
	extrn	firstkey:word
	extrn	firstlen:word
	extrn	secondkey:word
	extrn	secondlen:word
	extrn	thirdkey:word
	extrn	thirdlen:word
	extrn	fourthkey:word
	extrn	fourthlen:word
	extrn	fifthkey:word
	extrn	fifthlen:word
	extrn	blastdupes:byte
	extrn	insensitive:byte
	extrn	skipblanks:byte
	extrn	columns:byte
	extrn	recwidth:word

compcalls	label	dword
compcallslo	dw	0
compcallshi	dw	0

	public	compcalls

; ---------------------------------------------------------------------------

	.code

	extrn	strcmp:near
	extrn	stricmp:near
	extrn	strncmp:near
	extrn	strnicmp:near
	extrn	strlen:near
	extrn	memcmp:near

	public	comp_0x
	public	comp_1x



	public delcmp		; these are not really public, but
				; this makes it visibile to CodeView
	public inccalls
	public	colcmp
	public	domemcmp
	    
; ---------------------------------------------------------------------------

comp_gen	proc

	assume	ds:nothing

	mov	ax,recwidth	; is there a recwwidth?
	and	ax,ax
	je	comp_2		; nope, use comp_2
comp_gen2:	jmp	comp_bin	; yes,  use comp_bin

comp_gen	endp

; ---------------------------------------------------------------------------
comp_0x:	call	inccalls

comp_0	proc

	push	bp
	mov	bp,sp			; setup addressing

	mov	ax,[bp+4]		;first offset
	mov	bx,[bp+6]		;first segment
	mov	cx,[bp+8]		;second offset
	mov	dx,[bp+10]		;second segment

	assume	ds:nothing
	cmp	reversed,0		; are we reversed?
	assume ds:_DATA
	je	_comp_0_nr

	xchg	ax,cx
	xchg	bx,dx			; yes!  swap pointers around

_comp_0_nr:
	push	dx			; push everything in order
	push	cx
	push	bx
	push	ax
	assume	ds:nothing
	call	strcmp			; it's the fastest!
	assume ds:_DATA

	mov	sp,bp  			; restore registers
	pop	bp
	ret				; and return

comp_0	endp

; ---------------------------------------------------------------------------

comp_1x:	call	inccalls

comp_1	proc

	push	bp
	mov	bp,sp			; setup addressing

	mov	ax,[bp+4]		;first offset
	mov	bx,[bp+6]		;first segment
	mov	cx,[bp+8]		;second offset
	mov	dx,[bp+10]		;second segment

	assume	ds:nothing
	cmp	reversed,0		; are we reversed?
	je	_comp_1_nr
	assume	ds:_DATA

	xchg	ax,cx
	xchg	bx,dx			; yes!  swap pointers around

_comp_1_nr:
	push	dx			; push everything in order
	push	cx
	push	bx
	push	ax

	assume	ds:nothing
	cmp	insensitive,0
	assume ds:_DATA
	jne	_comp_1_ci
	call	strcmp			; it's the fastest!
	jmp	short _comp_1_re

_comp_1_ci:	call	stricmp
	
_comp_1_re:
	mov	sp,bp			; restore registers
	pop	bp
	ret				; and return

comp_1	endp

; ---------------------------------------------------------------------------

comp_2	proc

	push	bp
	mov	bp,sp			; setup addressing
	push	ds			; save the important regs
	push	si
	push	di

	mov	al,ignorewhite		; get the flag now

	lds	si,[bp+04]		; DS:SI --> first
	dec	si
	les	di,[bp+08]		; ES:DI --> second
	dec	di

	and	al,al			; is it set?
	je	_comp_2jc		; nope, just call it

	; skip whitespcae on first

_comp_21up:	inc	si
	mov	al,[si]
	cmp	al,space
	je	_comp_21up		; skip the space
	cmp	al,tab
	je	_comp_21up		; or the tab

	; skip whiespace on second

_comp_22up:	inc	di
	mov	al,es:[di]
	cmp	al,space		; skip the space
	je	_comp_22up
	cmp	al,tab
	je	_comp_22up

	; push the pointers and call!

_comp_2jc:
	push	es
	push	di
	push	ds
	push	si
	call	comp_1			; call next level down
	add	sp,8			; discard stack data

	pop	di
	pop	si
	pop	ds
	mov	sp,bp			; restore registers
	pop	bp
	ret				; and return

comp_2	endp

; ---------------------------------------------------------------------------

comp_3	proc

	push	bp
	mov	bp,sp			; setup addressing
	push	ds			; save the important regs
	push	si
	push	di

	assume	ds:nothing
	mov	al,ignorewhite		; get the flag now
	mov	ah,reversed

	lds	si,[bp+04]		; DS:SI --> first
	les	di,[bp+08]		; ES:DI --> second

	and	ah,ah			; is it reversed?
	jne	_comp_3nr		; nope, no need to reverse

	xchg	si,di			; yes, flip pointers
	push	es
	push	ds
	pop	es
	pop	ds			; around

_comp_3nr:
	and	al,al			; is it set?
	je	_comp_3jc		; nope, just call it
	dec	si			; downadjust pointers
	dec	di

	; skip whitespcae on first

_comp_31up:	inc	si
	mov	al,[si]
	cmp	al,space
	je	_comp_31up		; skip the space
	cmp	al,tab
	je	_comp_31up		; or the tab

	; skip whiespace on second

_comp_32up:	inc	di
	mov	al,es:[di]
	cmp	al,space		; skip the space
	je	_comp_32up
	cmp	al,tab
	je	_comp_32up

	; push the pointers and call!

_comp_3jc:
	mov	ax,firstkey
	mov	bx,firstlen
	push	bx
	push	ax
	push	ds
	push	si
	push	es
	push	di
	call	delcmp
	add	sp,12
	and	ax,ax
	jne	_comp_3end

	mov	ax,secondkey
	and	ax,ax
	je	_comp_3end
	call	inccalls
	mov	bx,secondlen
	push	bx
	push	ax
	push	ds
	push	si
	push	es
	push	di
	call	delcmp
	add	sp,12
	and	ax,ax
	jne	_comp_3end

	mov	ax,thirdkey
	and	ax,ax
	je	_comp_3end
	call	inccalls
	mov	bx,thirdlen
	push	bx
	push	ax
	push	ds
	push	si
	push	es
	push	di
	call	delcmp
	add	sp,12
	and	ax,ax
	jne	_comp_3end

	mov	ax,fourthkey
	and	ax,ax
	je	_comp_3end
	call	inccalls
	mov	bx,fourthlen
	push	bx
	push	ax
	push	ds
	push	si
	push	es
	push	di
	call	delcmp
	add	sp,12
	and	ax,ax
	jne	_comp_3end

	mov	ax,fifthkey
	and	ax,ax
	je	_comp_3end
	call	inccalls
	mov	bx,fifthlen
	push	bx
	push	ax
	push	ds
	push	si
	push	es
	push	di
	call	delcmp
	add	sp,12

_comp_3end:	pop	di
	pop	si
	pop	ds
	assume	ds:_DATA
	mov	sp,bp			; restore registers
	pop	bp
	ret				; and return

comp_3	endp

; ---------------------------------------------------------------------------

comp_bin	proc
	assume	ds:_DATA

	call	inccalls

	push	bp
	mov	bp,sp			; setup addressing
	push	ds			; save the important regs
	push	si
	push	di

	assume	ds:nothing
	mov	al,reversed

	lds	si,[bp+04]		; DS:SI --> first
	les	di,[bp+08]		; ES:DI --> second

	and	al,al			; is it reversed?
	jne	_comp_binnr		; nope, no need to reverse

	xchg	si,di			; yes, flip pointers
	push	es
	push	ds
	pop	es
	pop	ds			; around

_comp_binnr:
	mov	ax,firstkey
	mov	bx,firstlen		; get the first key
	call	domemcmp
	and	ax,ax			; is it equal?
	jne	_comp_binend		; yes, we can exit

	mov	ax,secondkey
	and	ax,ax			; compare by second key
	je	_comp_binend		; if it exists

	mov	bx,secondlen
	call	domemcmp
	and	ax,ax
	jne	_comp_binend

	mov	ax,thirdkey
	and	ax,ax
	je	_comp_binend

	mov	ax,thirdkey
	and	ax,ax
	je	_comp_binend

	mov	bx,thirdlen
	call	domemcmp
	and	ax,ax
	jne	_comp_binend

	mov	ax,fourthkey
	and	ax,ax
	je	_comp_binend

	mov	bx,fourthlen
	call	domemcmp
	and	ax,ax
	jne	_comp_binend

	mov	ax,fifthkey
	and	ax,ax
	je	_comp_binend

	mov	bx,fifthlen
	call	domemcmp

_comp_binend:	pop	di
	pop	si
	pop	ds
	assume	ds:_DATA
	mov	sp,bp			; restore registers
	pop	bp
	ret				; and return

comp_bin	endp

; ---------------------------------------------------------------------------

domemcmp	proc

	push	bx
	push	si
	push	di			; save the regs

	add	si,ax
	add	di,ax			; change the pointers to
					; the beginning of the key

	push	bx			; push the length
	push	ds
	push	si
	push	es
	push	di			; push operands
	call	memcmp			; compare the ranges!
	add	sp,10			; remove operands

	pop	di			; restore registers
	pop	si
	pop	bx
	ret

domemcmp	endp

; ---------------------------------------------------------------------------

delcmp	proc
	assume	ds:nothing

	push	bp
	mov	bp,sp			; setup addressing
	push	ds			; save the important regs
	push	es
	push	si
	push	di

delcmp2:	mov	bl,seper		; put the delimiter in a
					;   safe place
	mov	bh,insensitive		; remember the /C flag

	lds	si,[bp+4]		; DS:SI --> first
	dec	si
	les	di,[bp+8]		; ES:DI --> second
	dec	di
	mov	ax,[bp+12]		; AX = delimiter number

	assume	ds:nothing

	cmp	columns,0		; columns are a bit different
	jne	colcmp

	mov	ah,al			; AH = AL = delim number

delcmp_gd1:	dec	ah
	jz	delcmp_gd2
delcmp_gd1c:	inc	si
	cmp	[si],bl			; try to find a delimiter
	jne	delcmp_gd1c		; to get started
	je	delcmp_gd1

delcmp_gd2:	dec	al
	jz	delcmp_l
delcmp_gd2c:	inc	di
	cmp	es:[di],bl
	jne	delcmp_gd2c
	je	delcmp_gd2

delcmp_l:	inc	si			; compare next characters
	inc	di
	mov	ah,es:[di]		; get characters
	mov	al,[si]

	cmp	ah,al			; are they equal right now?
	jne	delcmp_tc

delcmp_cd:	cmp	al,bl			; they're equal!  is it delim?
	je	delcmp_eq		; yes, exit with a zero
	and	al,al			; is it '\0'?
	jne	delcmp_l		; nope, keep going

delcmp_eq:	xor	ax,ax			; return a zero!
	jmp	short delcmp_out

delcmp_tc:	and	bh,bh			; is it /C?
	je	delcmp_ma		;  nope, just split!

	xchg	ah,al
	sub	al,'A'			; knock the char out of alpha
	cmp	al,'Z'-'A'+1		; is it uppercase?
	sbb	cl,cl			; CL = FF if it is
	and	cl,'a'-'A'		; CL = 20 if it is
	add	al,cl			; now it's lowercase
	add	al,'A'			; now it's alpha again!
	xchg	ah,al			; do it again
	sub	al,'A'			;  for the other char
	cmp	al,'Z'-'A'+1
	sbb	cl,cl	
	and	cl,'a'-'A'
	add	al,cl	
	add	al,'A'	

	cmp	al,ah			; are they equal now?
	jne	delcmp_ma		;  nope, not equal, were out

delcmp_cdo:					; ...unless there was a delimiter
	cmp	al,bl			; is this one a delimiter?
	je	delcmp_ma		;  yes, find the answer
	cmp	ah,bl			; is this one a delimiter?
	je	delcmp_ma		;  yeah, use that
	and	ah,ah			; how about '\0'?
	je	delcmp_ma		;  banzai!
	and	al,al			; well, last shot
	jne	delcmp_l		; nope, go back and try again

delcmp_ma:	; subtract one from the other to get an answer
	; if first>second, +
	; if first<second, -

	xor	bx,bx
	mov	bl,ah
	mov	ah,0			; AX = <AL>,  BX = <AH>
	sub	ax,bx			; that's our answer!

delcmp_out:	pop	di	       
	pop	si
	pop	es
	pop	ds
	mov	sp,bp			; restore registers
	pop	bp
	ret				; and return to caller

	assume	ds:_DATA
delcmp	endp

; ---------------------------------------------------------------------------

colcmp	proc

	mov	bl,insensitive		; remember the /C flag
	mov	bh,ignorewhite		; and the /I flag
	
	lds	si,[bp+4]		; DS:SI --> first
	dec	si
	les	di,[bp+8]		; ES:DI --> second
	dec	di
	mov	ax,[bp+12]		; AX = delimiter number

	assume	ds:nothing

	mov	dx,firstkey
	cmp	ax,1
	jne	colcmpit

	mov	dx,secondkey
	cmp	ax,2
	jne	colcmpit

	mov	dx,thirdkey
	cmp	ax,3
	jne	colcmpit

	mov	dx,fourthkey
	cmp	ax,4
	jne	colcmpit

	mov	dx,fifthkey

colcmpit:	add	di,dx
	add	si,dx

	and	bh,bh
	je	colcmpnsws

	dec	si
colcmpss:	inc	si
	mov	al,[si]
	cmp	al,space
	je	colcmpss
	cmp	al,tab
	je	colcmpss

	dec	di
colcmpsd:	inc	di
	mov	al,[di]
	cmp	al,space
	je	colcmpsd
	cmp	al,tab
	je	colcmpsd

colcmpnsws:	mov	dx,[bp+14]	; get length

	push	dx
	push	es
	push	di
	push	ds
	push	si

	and	bl,bl			; should we ignore case?
	jne	colcmp_ni		;  yes! call strnicmp()

colcmp_n:	call	strncmp
	add	sp,6
	jmp	short	colcmp_out

colcmp_ni:	call	strnicmp
	add	sp,6
	jmp	short	colcmp_out

colcmp_out:	pop	di	       
	pop	si
	pop	es
	pop	ds
	mov	sp,bp			; restore registers
	pop	bp
	ret				; and return to caller

colcmp	endp

; ---------------------------------------------------------------------------

checkblank	proc

	cmp	skipblanks,0		;is flag set?
	jne	_cbdo			;yes, do the work

	xor	ax,ax			;otherwise, return with 0
	ret

_cbdo:	push	bp			; setup addressing
	mov	bp,sp
	push	si
	push	ds

	lds	si,[bp+4]		; get pointer

_cbwork:	lodsb			; get next character
	cmp	al,space
	je	_cbwork
	cmp	al,tab
	je	_cbwork		; if its white, keep looping
	cmp	al,0 		; if it's EOS, answer is 1!
	je	_cbyes	

	xor	ax,ax		; otherwise, answer is 0
	jmp	short _cbend

_cbyes:	mov	ax,1

_cbend:	pop	ds		; restore regs and split
	pop	si
	mov	sp,bp
	pop	bp
	ret

checkblank	endp

; ---------------------------------------------------------------------------

inccalls	proc
	assume ds:nothing

	inc	compcallslo		; increment _compcalls by 1
	jne	inccalls2

	inc	compcallshi

inccalls2:	ret
	assume	ds:_DATA
inccalls	endp

	end


