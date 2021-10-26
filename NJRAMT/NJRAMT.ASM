
;	Nifty James' Famous Expanded Memory Tester
;	(C) Copyright 1987 by Mike Blaszczak.  All Rights Reserved.

;   Version 1.00 of 21 Oct 1987

;   Shareware  $5    Please register!

;   Assemble with:
;	MASM NJRAMT;
;	LINK NJRAMD;
;	EXE2BIN NJRAMT.EXE NJRAMT.SYS
;	DEL NJRAMT.EXE

;   for enhanced processor version:

;	MASM /DV286 NJRAMT,NJRAMTXP;
;	LINK NJRAMTXP;
;	EXE2BIN NJRAMTXP.EXE NJRAMTXP.SYS
;	DEL NJRAMTXP.EXE

;  --> DEVICE DRIVER FORMAT FILE <--
;  -->  REMEMBER TO USE EXE2BIN  <--

; ---------------------------------------------------------------------------

;   ASCII Characters

bell		equ	7		; bell character
tab		equ	9		; tab character
lf		equ	10		; linefeed
cr		equ	13		; carriage return
space		equ	32		; space
eos		equ	'$'		; end of DOS string

; ---------------------------------------------------------------------------

EMM		equ	067h		; the E/EMS memory manager

; ---------------------------------------------------------------------------
;  Structure Definitions

;  The structures defined here are used to find information in the
;  various request header formats.  Of course, being structures, they
;  don't take up space... they are used to define offsets for the
;  addressing of the request header.

donestat	equ	00000000100000000b	; done status bit flag

rq	equ	es:[bx]			; base address used in routines

;  -- Request Header (General Format)

inithead	struc
	rlen	db	?	; length of the structure
	unitn	db	?	; unit number
	command	db	?	; command code
	status	dw	?	; status code (returned by us)
		db	8 dup(?); reserved bytes
	units	db	?	; number of units
	ndadro	dw	?	; ending address offset
	ndadrs	dw	?	; ending address segment
	bpboff	dw	?	; BPB offset pointer
	bpbseg	dw	?	; BPB segment pointer
	taglet	db	?	; drive tag letter
inithead	ends

; ---------------------------------------------------------------------------
;   DOS Calls

; These are DOS functions used by the driver.

DisplayOut	equ	002h		; call to print a single character
PrintString	equ	009h		; call to print a '$' string
CheckKeyboard	equ	00Bh		; call to check for a key
GetDOSVersion	equ	030h		; call to get the DOS version #

; ---------------------------------------------------------------------------
;  I/O Ports

Speak		equ	061h		; speaker port
SpeakMask	equ	011111110b	; mask for speaker set bit
SpeakToggle	equ	000000010b	; toggle bit for the speaker

; ---------------------------------------------------------------------------
;  E/EMM Routines

; These are the E/EMM functions that we use.  (These are specific functions
; of the EMM interrupt.)

E_PageBase	equ	041h		; determine the Page Fram Base Addr
E_Counts	equ	042h		; determine free/total mem
E_Open		equ	043h		; open, allocate, obtain handle ID
E_MapPage	equ	044h		; map a logical page into window
E_Close		equ	045h		; close handle and free pages
E_Version	equ	046h		; get the E/EMM version number

ifdef  V286
	.286
	if1
		%OUT	Enhanced processor version
	endif
	ifdef	PCL
	if1
		%OUT	for the PC's Limited 286/386
	endif
	endif
else
	if1
		%OUT	Standard Version
	endif
endif


;  This macro is used during debugging.  It prints a single character
; via the BIOS screen interface, and leaves the registers unchanged.

ifdef	DEBUG

	if1
		%OUT  DEBUG Version
	endif
	PrintChar	macro	Char
		ifdef	PCL

			push	ax
			mov	al,Char
			out	095h,al		; put it digit 3 of smartvu
			pop	ax

		else
	
			push	ax		; save the regs
			push	bx
			push	dx
			mov	ah,15
			int	010h		; get the current page
			mov	al,Char
			mov	ah,14		; print the character
			int	010h

			xor	dx,dx
			mov	ah,0		; also to printer
			mov	al,Char
			int	017h

			pop	dx
			pop	bx		;restore the regs
			pop	ax

			endif
			endm

else
	PrintChar	macro	Char		; if not debugging, blow it off
			endm
endif

; ---------------------------------------------------------------------------

tester		segment	para public 
		assume	cs:tester,ds:tester,es:tester,ss:tester

		org	0		; begin at zero

; ---------------------------------------------------------------------------
;  Device Header

; This area contains the header information.  It is used by DOS when loading
; the device driver, and it contains information used to describe the
; driver to the DOS environment.

NextPlace	dw	-1,-1		; pointer to next driver
Attrib		dw	00010000000000000b		; attribute word
			;FEDCBA9876543210

					; device is non-ibm and block mode
					; doesn't support IOCTL, is not
					; a network device

		dw	offset Strategy		; the strategy entry
		dw	offset Interrupt	; the interrupt entry
		db	1,'NJ_DISK'		;  Nifty James' Disk!

; ---------------------------------------------------------------------------

JumpTable	label word

; This area is a "Jump Table" that is used to dispatch the code.
; Only the init function is implemented.  This driver will only
; run during the CONFIG.SYS file.  After that, it entirely clears
; itself from memory.

	dw	offset	Init		;  0 * initialize

	;  (The commands above init are all not implemented -- we don't
	;   make entries for them to optimize for space (and speed).
	;   The equate TopCommand must be set to the last used
	;   command code.)

TopCommand	equ	1		; highest valid command

RBPoint		label	dword		; Pointer to request buffer
RBPointOff	dw	0		; offset part
RBPointSeg	dw	0		; segment part

SaveSS		dw	0		; save place for the SS register
SaveSP		dw	0		; save place for the SP register
SaveAX		dw	0		; save place for the accumulator

EMMHandle	dw	0		; our handle, as assigned by the EMM
EMMBase		dw	0		; base of the EMM physical window

; ---------------------------------------------------------------------------
;  The local stack

		even			; make the stack a word-aligned area
		dw	64 dup (0DEADh)
StackTop:

; ---------------------------------------------------------------------------
;  Strategy Entry Point For the Device Driver

;  This routine simply stores the pointer to the request header
;  so that request header has it.  That's all it does.  Really.

STRATPROC	proc	far

Strategy:
	mov	cs:RBPointOff,bx
	mov	cs:RBPointSeg,es	; just store the pointer
	ret				; and get outta here!
	; (isn't it ironic that the shortest routine is called "Strategy"?)
STRATPROC	endp

; ---------------------------------------------------------------------------
;  Interrupt Entry Point For the Device Driver

;  This routine executes the command contained in the passed request header.
;  DOS has called STRATEGY, and that routine stored a pointer to the request
;  header for our use.  We will construct our own stack area because the 
;  EMM uses a great deal of stack space.

INTPROC		proc	far
Interrupt:	
PrintChar 'D'
		mov	CS:SaveSS,ss		; save the SS register
		mov	CS:SaveSP,sp		; save the SP register
		mov	CS:SaveAX,ax

		cli
		mov	ax,offset StackTop	; initialize our stack
		mov	sp,ax
		mov	ax,cs
		mov	ss,ax
		sti

	ifdef V286
		pusha
	else
		push	bx		; save the other regs
		push	cx
		push	dx
		push	bp
		push	si
		push	di
	endif

		pushf			; and the flags
		cld			;  set the string direction up
		push	es
		push	ds

	; Note that during calls we use DS to point to our local data
	; and ES to point to the request header.

		les	bx,cs:RBPoint	; get the request buffer

		call	Init

; ---------------------------------------------------------------------------
;   This is the mass exit; everone splits through this point!  When we
;   arrive here, the AX reg will contain the word to be put into the
;   status word.  We'll do that:

BigLog:		
PrintChar 'X'
		les	bx,cs:RBPoint		; point to the request block
NoRestore:	or	ax,donestat		; set the done status
		mov	rq.status,ax

;  Now, we just undo the registers.

		pop	ds		; the seg regs
		pop	es

		popf			; the flags
	ifdef V286
		popa
	else
		pop	di
		pop	si		; and the data regs
		pop	bp
		pop	dx
		pop	cx
		pop	bx
	endif

PrintChar 'd'
		cli
		mov	ax,CS:SaveAX
		mov	sp,CS:SaveSP	; restore the calling stack
		mov	ss,CS:SaveSS
		sti
		ret

INTPROC		endp

; ---------------------------------------------------------------------------

testpage 	proc	near

	; This procedure tests the EMS block that is currently mapped
	; at EMSBASE:0000 through EMSBASE:3FFF.  The routine will return
	; with AX set to 0000h if no error occurred.  If an error occurs,
	; it returns with AX set to 0FFFFh.

		mov	es,EMSBase

		mov	ax,0FFFFh	; write all ones
		call	testset
		jne	testfail	; nope, it failed

		xor	ax,ax		; write all zeros
		call	testset
		jne	testfail

		mov	ax,0AA55h	; write 1010101001010101 pattern
		call	testset
		jne	testfail

		mov	ax,055AAh	; write 0101010110101010 pattern
		call	testset
		jne	testfail

		xor	ax,ax		; test was successful,
		ret			; return with AX = 0

testfail:	mov	ax,0FFFFh	; AX = 0FFFFh, test failed.
		ret

testpage	endp


testset		proc	near

		cld
		mov	di,0
		mov	cx,8192		; 8192 words
	rep	stosw

		mov	di,0		; try to check them
		mov	cx,8190
testsetloop:	cmp	es:[di],ax
		jne	testsetexit
		inc	di
		inc	di
		loop	testsetloop

testsetexit:	cmp	cx,0		; see if it's zero
		ret			; and return with results of comparison

testset		endp

; ---------------------------------------------------------------------------

PrintPage	proc	near

		xor	ax,ax			; print "page x tested"
		mov	si,offset TestingSpot
		mov	bx,CurrentPage
		call	Bin2Dec			; convert page # to ASCII

		mov	ah,PrintString		; print it
		mov	dx,offset TestingMsg
		int	21h

		in	al,Speak		; and then make a click
		and	al,SpeakMask
		xor	al,SpeakToggle
		out	Speak,al

		ret

PrintPage	endp

; ---------------------------------------------------------------------------

PrintError	proc	near

		xor	ax,ax			; print "error at page"
		mov	si,offset ErrorSpot	;  message
		mov	bx,CurrentPage
		call	Bin2Dec			; convert page number to ASCII

		mov	ah,PrintString		; and print it
		mov	dx,offset ErrorMsg
		int	21h

		ret


PrintError	endp

; ---------------------------------------------------------------------------

Init		proc	near

		mov	ax,cs
		mov	ds,ax

		mov	ah,PrintString		;print the banner
		mov	dx,offset Banner
		int	21h

		push	es
		xor	ax,ax			; point to the 0000 segment
		mov	es,ax
		mov	bx,(EMM*4)+2		; find the EMM interrupt
		mov	ax,es:[bx]
		mov	es,ax			; point to the EMM device
		mov	di,10			; header

		mov	si,offset EMMIDString	; point to the EMM identifier
		mov	cx,8
	repz	cmpsb				; compare a bunch of bytes
		pop	es
		jz	EMMPresent

		mov	dx,offset NoEMMThere	; point to our error
		jmp	InitFail		;  the EMM isn't there!!

EMMPresent:	mov	ah,E_PageBase		; get the page base
		int	EMM
		or	ah,ah
		jne	GenFail

		mov	EMSBase,bx		; store it

		mov	ah,E_Counts		; get count of pages available
		int	EMM
		or	ah,ah
		jne	GenFail

		cmp	bx,dx		; is it all unused?
		je	AllMine

		mov	dx,offset NotAllMem
		jmp	InitFail

AllMine:	push 	dx		; save count

		mov	ah,E_Open	; bx already has count
		int	EMM
		and	ah,ah
		jne	GenFail

		mov	EMSHandle,dx	; save the handle

		pop	cx		; retrieve count

PageLoop:	push	cx
		mov	ah,E_MapPage	; map the current page
		mov	al,0		; into logical window 0
		mov	bx,CurrentPage
		mov	dx,EMSHandle
		int	EMM
		and	ah,ah
		jne	GenFail

		call	PrintPage
		call	TestPage	; test a page
		cmp	ax,0		; is it zero?
		je	NoError

		call	PrintError

NoError:	pop	cx

		mov	ah,CheckKeyboard	; check for a keypress
		int	21h
		and	al,al		; was there?
		jne	fallout		;  yep, get out of here

		inc	CurrentPage
		loop	PageLoop

		mov	dx,offset TestedMsg	; print end message
		mov	ah,PrintString
		int	21h

fallout:	mov	ah,E_Close	; release the EMS memory we took
		mov	dx,EMSHandle
		int	EMM
		and	ah,ah
		jne	GenFail

endit:		les	bx,cs:RBPoint	; get ES:BX back
		xor	ax,ax
		mov	rq.ndadro,ax	;ending address is CS:0000
		mov	rq.units,al	;don't take any unit numbers

		mov	ax,cs
		mov	rq.ndadrs,ax

		ret			; return to the dispatcher routine

GenFail:	mov	dx,offset EMMError

InitFail:	push	dx
		mov	dx,offset General	;print error header
		mov	ah,PrintString
		int	21h
		pop	dx

		mov	ah,PrintString		; and then the error itself
		int	21h
		jmp	endit

Init		endp

; ---------------------------------------------------------------------------
;  BIN2DEC

;  This routine converts a binary number, in AX:BX, to decimal notation.
;  It will convert up to 8 digits, and will supress leading zeros.  The
;  routine should be called with DS:SI set to point to the area to store
;  the converted number.

Bin2Dec		proc	near

		push	es		; save the registers
		push	ds
		push	di
		push	si

		mov	WorkAreaL,bx
		mov	WorkAreaH,ax	; put the number on our scratchpad

		mov	ax,ds		; point to the answer with ES:DI
		mov	es,ax
		mov	di,si
		add	di,7

		mov	si,offset WorkAreaL	; point at scratchpad

Bin2DecLoop:	push	si

		xor	bx,bx		; done flag
		mov	cx,2		; 2 words in our number
		mov	dx,bx		; clear remainder
		add	si,2		; point to the high end

Bin2DecDigit:	push	cx		; save word count
		mov	ax,[si]		; get the digit
		mov	cx,10
		div	cx		; convert it
		mov	[si],ax		; store it back
		or	bx,ax		; set the done flag appropriately
		sub	si,2		; point to next lower
		pop	cx
		loop	Bin2DecDigit

		or	dl,'0'		; make it into a decimal digit
		mov	[di],dl		; and store it
		dec	di		; adjust pointer

		pop	si		; get the pointer back
		and	bx,bx		; is the result zero?
		jne	Bin2DecLoop	; nope!  Do more!

		pop	si		; retrieve the used registers
		pop	di
		pop	ds
		pop	es
		ret

WorkAreaL	dw	0		; low end of the work area
WorkAreaH	dw	0		; high side of the work area

Bin2Dec		endp

; ---------------------------------------------------------------------------

EMSHandle	dw	?		; our EMS handle number
EMSBase		dw	?		; base segment of EMS
CurrentPage	dw	?		; current page that we're testing

TestingMsg	db	'Page '
TestingSpot	db	'         tested',cr,eos

TestedMsg	db	'All Pages Tested!     ',cr,lf,eos

ErrorMsg	db	'Error on Page '
ErrorSpot	db	'        !',bell,cr,lf,eos

Banner		db	lf,"Nifty James' Famous EMS Memory Tester",cr,lf
		db	"Version 1.00 of 21 Oct 1987",cr,lf
	ifdef	V286
		db	"Enhanced Processor Version",cr,lf
	endif
		db	lf,eos

EMMIDString	db	'EMMXXXX0'

General		db	'Device not installed.',cr,lf,eos

NoEMMThere	db	'The EMM is not installed.',cr,lf,lf,eos

EMMError	db	'EMM failure during testing.',cr,lf,lf,eos

NotAllMem	db	'EMM Memory not entirely empty.',cr,lf,lf,eos

tester		ends
		end

