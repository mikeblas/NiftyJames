
;
;   Nifty James' FREE RAM program
;   Version 2.00 of 14 May 1987
;
;   Copyright 1987 by Mike Blaszczak, all Rights Reserved.
;
;   Shareware  $7
; 

;   ASCII Characters

tab		equ	9
lf		equ	10
cr		equ	13
space		equ	32

;   IBM Specific Keyboard Scan-codes

AltDown		equ	56		; ALT scancode
AltUp		equ	56 + 80h
RShiftDown	equ	54		; right-shift scancode
RShiftUp	equ	54 + 80h

;   BIOS Interrupts

Timer		equ	008h		; BIOS 18.2Hz function
Keyboard	equ	009h		; BIOS keypress call
Video		equ	010h		; BIOS video function
DiskService	equ	013h		; BIOS/XT BIOS disk service
TickTock	equ	01Ch		; the BIOS timer trap
SnagDOS		equ	028h		; a function to snag DOS by
SigVec		equ	0D0h		; vector to see if we're installed
EMM		equ	067h		; the E/EMS memory manager

;   I/O Ports

NMIPort		equ	020h		; the Interrupt controller port
KeyPort		equ	060h		; the keyboard's I/O port

;   DOS Calls

SetVec		equ	025h		; call to set an int vector
KEEP		equ	031h		; call to Terminate and Stay Res
Critical	equ	034h		; call to get the DOS critical flag
GetVec		equ	035h		; call to get an int vector
Allocate	equ	048h		; call to allocate memory
Terminate	equ	04Ch		; call to Terminate

;   E/EMS Routines

E_Status	equ	042h		; call to determine free/total mem


 ;   Public declarations for SYMDEB

PUBLIC First, StackArea, StackTop, Signature, SaveAX, SaveSS, SaveSP
PUBLIC ClockVec, ClockVecO, ClockVecS, Display, DisplayOff, DisplaySeg
PUBLIC DisplayPort, CriticalFlag, CriticalFlagO, CriticalFlagS, OTT, OTTO
PUBLIC OTTS, OKeyVec, OKeyVecO, OKeyVecS, OSnagger, OSnaggerO, OSnaggerS
PUBLIC ODiskCall, ODiskCallO, ODiskCallS, WorkFlag, UpdateFlag, AltFlag
PUBLIC ShiftFlag, Ticks, InDisk, InThere, HasEMem, DiskTrap, TCTrap, TCDone
PUBLIC TimeTrap, NotTime, KeyTrap, TryUpAlt, TryDnShift, TryUpShift, TripOut
PUBLIC DontGotNone, CheckEMode, TripOutOut, KeyOut, WorkTrap, WorkHard
PUBLIC NoWork, DoWork, EMSMode, DosMode, Calculate, CalcLoop, StickIt
PUBLIC Convert2, Convert3, IsMono, SynchLow, SynchHigh, PutUp, GetOut
PUBLIC CalcArea, AnswerArea, UnitsArea, BytesLine, EEMSLine, OverResident
PUBLIC Already, Exit, InstallMe, NoEMM, NotMono, ExitNow, Banner
PUBLIC DInstalled, EInstalled, Failed
PUBLIC EMSSig


CSeg		segment	para public 'CODE'
		assume	ds:CSeg,ss:CSeg,cs:CSeg

		org	100h

extrn   Show:near	; from NJLIB

First:		jmp	OverResident
		nop
StackArea	dw	19 dup(0DEADh)	; the stack for interrupts
StackTop	dw	0DEADh

Signature	db	'NJ'		; the signature

SaveAX		dw	0		; save the AX here
SaveSS		dw	0		; save the SS and SP here
SaveSP		dw	0



ClockVec	label	dword		; the original clock tick vector
ClockVecO	dw	0
ClockVecS	dw	0

Display		label	dword		; pointer to display storage
DisplayOff	dw	62*2
DisplaySeg	dw	0B800h		; assume the color card
DisplayPort	dw	03DAh		; display status port address

CriticalFlag	label	dword		; the DOS critical flag
CriticalFlagO	dw	0
CriticalFlagS	dw	0

OTT		label	dword		; the original BIOS Timer Trap
OTTO		dw	0
OTTS		dw	0

OKeyVec		label	dword		; the original keypress vector
OKeyVecO	dw	0
OKeyVecS	dw	0

OSnagger	label	dword		; the original DOS int 28h
OSnaggerO	dw	0
OSnaggerS	dw	0

ODiskCall	label	dword		; the disk services place
ODiskCallO	dw	0
ODiskCallS	dw	0

WorkFlag	dw	0		; semaphore; 1 if we should display
					;	     2 if we are in EEMS mode
UpdateFlag	dw	0		; semaphore; 1 if we should update

AltFlag		db	0		; set if ALT is pressed
ShiftFlag	db	0		; set if RShift is pressed

Ticks		db	0		; tick count for timer
InDisk		db	0		; semaphore; 1 if in disk control

InThere		db	0		; recursiveness flag
HasEMem		db	0		; set to 1 if E/EMS is present

; ---------------------------------------------------------------------------

DiskTrap:	inc	CS:InDisk	; set disk handler flag
		pushf
		call	CS:[ODiskCall]	; call the disk handler
		pushf
		dec	CS:InDisk	; reset disk handler flag
		popf
		iret			; return!

; ---------------------------------------------------------------------------

TCTrap:		pushf
		call	CS:[OTT]	; call the original
		pushf
		cli
		cmp	CS:[WorkFlag],0
		je	TCDone
		push	es
		push	bx		; check the critical flag
		les	bx,CS:[CriticalFlag]
		cmp	byte ptr es:[bx],0
		pop	bx
		pop	es
		jne	TCDone

		cmp	CS:[InDisk],0	; and the disk service flag
		jne	TCDone

		jmp	WorkHard

TCDone:		popf
		iret

; ---------------------------------------------------------------------------

TimeTrap:	pushf			; save flags
		push	ax

		inc	CS:Ticks	; increment ticks count
		mov	al,CS:Ticks	; is it time?
		cmp	al,18
		jne	NotTime		; no, not yet

		xor	ax,ax		; yes, zero time count
		mov	CS:Ticks,al
		mov	CS:UpdateFlag,1 ; set update flag

NotTime:	pop	ax
		popf
		jmp	CS:[ClockVec]
		
; ---------------------------------------------------------------------------

KeyTrap:	pushf
		push	ax

		in	al,KeyPort	; get key from keyboard
		cmp	al,AltDown	; was ALT pressed?
		jne	TryUpAlt	; no.  Maybe it was released?

		mov	CS:AltFlag,1	; yeah!  It was pressed, set flag
		jmp	short TripOut	; and flow through

TryUpAlt:	cmp	al,AltUp	; was ALT released?
		jne	TryDnShift	; no, maybe it was shift?

		mov	CS:AltFlag,0	; yeah!  ALT was released
		jmp	short TripOut	; reset flag and go through

TryDnShift:	cmp	al,RShiftDown	; okay.  Maybe RShifty was pressed?
		jne	TryUpShift	;  nah, maybe  it was released?

		mov	CS:ShiftFlag,1	; yeah! it was pressed, so set flag
		jmp	short TripOut	;  and jump through

TryUpShift:	cmp	al,RShiftUp	; well, maybe it was released?
		jne	KeyOut		;  no, guess not, just pass it thru

		mov	CS:ShiftFlag,0	;  yeah, it was released!

TripOut:	mov	al,CS:AltFlag	; so, is it both ALT and RSHIFT?
		and	al,CS:ShiftFlag
		je	KeyOut		; no, just pass thru

		mov	ax,CS:WorkFlag	; yes, it was!  update workflag
		inc	ax
		cmp	ax,3		; is it now off?
		jne	CheckEMode	;  no...
DontGotNone:	xor	ax,ax		;  yes, set to zero
		je	TripOutOut	;   and leave

CheckEMode:	cmp	ax,2		; is it now EMS mode?
		jne	TripOutOut	;  no, no need to check
		cmp	CS:HasEMem,1	;  yes.  do we have EMS?
		jne	DontGotNone	;  no, set to zero

TripOutOut:	mov	CS:WorkFlag,ax

KeyOut:		pop	ax
		popf

		jmp	CS:[OKeyVec]		
		
; ---------------------------------------------------------------------------


WorkTrap:	pushf			; simulate a INT
		call	CS:[OSnagger]
		pushf

WorkHard:	cmp	CS:[WorkFlag],0		; are we activated?
		je	NoWork			;  no, don't do work

		cmp	CS:[UpdateFlag],0	; is it time to update?
		je	NoWork			;  no, don't do work

		cmp	CS:[InThere],0		; are we getting recursive?
		jne	NoWork			;  yes, don't do work

		call	DoWork
NoWork:		popf
		iret		


DoWork:		cli			; turn off interrupts!
		cld			; and set direction up!!!
		mov	CS:SaveAX,ax	; save the stack seg from call
		mov	CS:SaveSP,sp
		mov	CS:SaveSS,ss

		mov	ax,cs			; point to our local
		mov	ss,ax			;  stack segment
		mov	ax,offset StackTop
		mov	sp,ax

		push	bx		; save all the regs we use
		push	cx
		push	dx
		push	si
		push	di
		push	ds
		push	es

		mov	ax,cs
		mov	ds,ax		; establish data seg addressing
		mov	es,ax

		inc	InThere		; don't be recursive
		mov	UpDateFlag,0	;  and don't do the work twice!

		cli			; reallow interrupts for now

		mov	cx,5		; move 10 bytes of message
		mov	di,offset UnitsArea	; into the units area
		cmp	WorkFlag,1
		je	DOSMode

EMSMode:	mov	si,offset EEMSLine
	repnz	movsw
		mov	ah,E_Status	; get the E/EMS status
		int	EMM		; from the EMM
	; BX contains EEMS pages free

		xor	ax,ax
		xchg	ax,bx		; make BX:AX = number of pages
		mov	cx,14		; mulitply by 2^14
		jmp	short CalcLoop	; to get number of bytes
		

DosMode:	mov	si,offset BytesLine
	repnz	movsw
		mov	ah,Allocate	; try to get a major amount of mem
		mov	bx,0FFFFh
		int	21h		; to see how much is free

Calculate:	xor	ax,ax		; zero the AX
		xchg	ax,bx		; now, AX = paragraphs and BX = 0
		mov	cx,4		; get # of bytes
CalcLoop:	rcl	ax,1		; multiply by two
		rcl	bx,1		; add in carry
		loop	CalcLoop

StickIt:
	; now, BX:AX contains bytes of free memory

		mov	CalcArea,ax		; store bytes
		mov	CalcArea+2,bx

		mov	di,offset AnswerArea
		mov	al,space
		mov	cx,7
	repnz	stosb

	; now, convert the number of bytes into ASCII, and store at
	; AnswerArea

		mov	si,offset CalcArea
		dec	di

Convert2:	push	si			; save source pointer

		xor	bx,bx			; done flag
		mov	cx,2			; 2 words in number
		xor	dx,dx			; previous remainder
		add	si,2			; point to high end

Convert3:	push	cx			; save count
		mov	ax,[si]			; get 16-bit digit
		mov	cx,10			; divisor of 10
		div	cx			; divide
		mov	[si],ax			; put 16-bit digit back
		or	bx,ax			; check for zero
		sub	si,2			; point to next 16-bit digit
		pop	cx			; restore count
		loop	Convert3		; do more

		or	dl,'0'		; make remainder into decimal digit
		mov	[di],dl		; store it
		dec	di		; and fix pointer

		pop	si		; restore source pointer
		cmp	bx,0		; was that the end?
		jnz	Convert2	; no, do more!

		mov	ah,15
		int	Video
		mov	cx,0B000h
		cmp	al,7
		je	IsMono
		mov	cx,0B800h
		add	ch,bh		; add the current page to it
		
IsMono:		mov	DisplaySeg,cx

		les	di,Display	; stuff it into the display!
		mov	si,offset AnswerArea
		mov	ah,7		; attribute
		mov	cx,18		; 17 characters in the message:
					; "xxxxxxx Bytes Free"

		mov	dx,DisplayPort	; get the status port number
		and	dx,dx		;  or is it mono?
		je	PutUp		;  yeah, skip synchro

SynchLow:				; wait for the synch to go low
		in	al,dx
		test	al,8
		jne	SynchLow

SynchHigh:				; wait for start of overscan
		in	al,dx
		test	al,8
		je	SynchHigh
	
PutUp:		lodsb			; load a byte of the message
		stosw			; store a word into the display
		loop	PutUp		; do the rest

GetOut:		cli			; disallow interrupts for crucial code
		dec	InThere		; clear work flag
		pop	es
		pop	ds		; reset the registers
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx

		mov	sp,CS:SaveSP		; restore the original stack
		mov	ss,CS:SaveSS
		mov	ax,CS:SaveAX

		sti				; re-allow ints and
		ret			; return to caller

CalcArea	dw	2 dup(0)

AnswerArea	db	8 dup (' ')
UnitsArea	db	"Bytes Free"

BytesLine	db	"Bytes Free"	; message for DOS Bytes
EEMSLine	db	"E/EMS Free"	; message for EEMS Bytes

; ---------------------------------------------------------------------------

OverResident:	mov	dx,offset Banner	; print the banner
		mov	cx,BannerLen
		call	Show

		mov	ah,GetVec		; see if already present
		mov	al,SigVec
		int	21h

		mov	ax,ES:[BX]		; see if the signature
		cmp	ax,'JN'			;  is there?
		jne	InstallMe

Already:	mov	dx,offset Failed	; already installed!
		mov	cx,FailedLen
		call	Show

Exit:		mov	ah,Terminate		; terminate with ERRORLEVEL
		mov	al,1
		int	21h

InstallMe:	; we should install ourselves.  First, check to see if
		; there is E/EMS present.

		mov	ah,GetVec		; get EMM Vector
		mov	al,EMM
		int	21h
		mov	di,000Ah	; point to device_name within
					;  the EMM driver
		mov	si,offset EMSSig
		mov	cx,8
		cld
	repe	cmpsb			; compare the bytes
		jne	NoEMM

		mov	HasEMem,1	; set EMEM flag to one

NoEMM:
		mov	ah,Critical		; get the DOS critical flag
		int	21h
		mov	CriticalFlagO,bx
		mov	CriticalFlagS,es

		mov	ah,GetVec		; handle the tick-tock
		mov	al,TickTock
		int	21h
		mov	OTTO,bx
		mov	OTTS,es

		mov	ah,SetVec
		mov	al,TickTock
		mov	dx,offset TCTrap
		int	21h

		mov	ah,GetVec
		mov	al,DiskService
		int	21h
		mov	ODiskCallO,bx
		mov	ODiskCallS,es
	
		mov	ah,GetVec
		mov	al,SnagDOS		; get originial INT 028h
		int	21h
		mov	OSnaggerO,bx
		mov	OSnaggerS,es
	
		mov	ah,GetVec		; get the current keyboard vec
		mov	al,Keyboard
		int	21h

		mov	OKeyVecO,bx
		mov	OKeyVecS,es

		mov	ah,GetVec		; get the clock-tick vec
		mov	al,Timer
		int	21h

		mov	ClockVecO,bx		; store clock vector
		mov	ax,es
		mov	ClockVecS,ax

		mov	ah,15		; call BIOS to get video mode
		int	Video
		cmp	al,7		; is it mono?
		jne	NotMono

		mov	ax,0B000h	; yes, change it to mono
		mov	DisplaySeg,ax	
		mov	ax,0
		mov	DisplayPort,ax

NotMono:	mov	ah,SetVec		; set an int vector
		mov	al,Timer		;  the timer's
		mov	dx,offset TimeTrap	; to our routine
		int	21h

		mov	ah,SetVec		; get the keypress vector
		mov	al,Keyboard
		mov	dx,offset KeyTrap
		int	21h

		mov	ah,SetVec		; get the snag DOS vector
		mov	al,SnagDOS
		mov	dx,offset WorkTrap
		int	21h

		mov	ah,SetVec		; set the signature pointer
		mov	al,SigVec
		mov	dx,offset Signature
		int	21h

		mov	dx,offset DInstalled
		mov	cx,DInstalledLen

		mov	al,HasEMem
		cmp	al,0
		je	ExitNow

		mov	dx,offset EInstalled
		mov	cx,EInstalledLen

ExitNow:
		call	Show

		mov	ah,KEEP		; terminate and stay resident
		mov	al,0	
		mov	dx,offset OverResident
		add	dx,15
		mov	cx,4
		shr	dx,cl
		int	21h

; ---------------------------------------------------------------------------

Banner		db	cr,lf,"Nifty James' FREE RAM program",cr,lf
		db	"Version 2.00 of 14 May 1987",cr,lf,lf,lf
BannerLen	equ	this byte - Banner

DInstalled	db	"NJFRERAM is installed!",cr,lf
		db	"Press <Alt>+<RightShift> to toggle the display",cr,lf,lf
DInstalledLen	equ	this byte - DInstalled

EInstalled	db	"NJFRERAM is installed!",cr,lf
		db	"EEMS Mode is active.",cr,lf
		db	"Press <Alt>+<RightShift> to move from DOS, to E/EMS, to off",cr,lf
EInstalledLen	equ	this byte - EInstalled

Failed		db	"NJFRERAM was already present!",cr,lf,lf
FailedLen	equ	this byte - Failed

EMSSig		db	"EMMXXXX0"

CSeg		ends
		end	First

