
;  Nifty James' Famous Expanded Memory Disk Drive
;  (C) Copyright 1987 by Mike Blaszczak.  All Rights Reserved

;  Version 1.01  of  24 May 1987
;  Version 1.10  of  25 May 1987
;  Version 1.15  of  31 May 1987

;  Shareware  $10     Please contribute!

;  Assemble with
;	MASM NJRAMD;
;	LINK NJRAMD;
;	EXE2BIN NJRAMD.EXE NJRAMD.SYS
;	DEL NJRAMD.EXE

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
;   I/O Ports

Speak		equ	061h		; speaker port
SpeakMask	equ	011111110b	; mask for speaker set bit
SpeakToggle	equ	000000010b	; toggle bit for the speaker

; ---------------------------------------------------------------------------
;   DOS Calls

; These are DOS functions used by the driver.

DisplayOut	equ	002h		; call to print a single character
PrintString	equ	009h		; call to print a '$' string
GetDOSVersion	equ	030h		; call to get the DOS version #

; ---------------------------------------------------------------------------
;  E/EMM Routines

; These are the E/EMM functions that we use.  (These are specific functions
; of the EMM interrupt.)

E_PageBase	equ	041h		; determine the Page Fram Base Addr
E_Counts	equ	042h		; determine free/total mem
E_Open		equ	043h		; open, allocate, obtain handle ID
E_MapPage	equ	044h		; map a logical page into window
E_Version	equ	046h		; get the E/EMM version number
E_Save		equ	047h		; save mapping context
E_Restore	equ	048h		; restore mapping context

; ---------------------------------------------------------------------------
;  Driver Equates

; This is the media descriptor byte.  Since our RAM drive is not 2 sided,
; does not have 8 sectors per track, and is not removable, we use 0F8h.
; At least, that's what the IBM DTR manual says.

MediaD		equ	0F8h

; These are equates used by the driver.  They are all status and
; error flags, as defined in the DOS Technical Reference Manual.

;                        FEDCBA9876543210 <- BIT NUMBERS
errorflag	equ	01000000000000000b	; error bit flag
busystat	equ	00000001000000000b	; busy status bit flag
donestat	equ	00000000100000000b	; done status bit flag

err_writeprot	equ	0		; write protect violation
err_badunit	equ	1		; unknown unit number
err_notready	equ	2		; device not ready
err_unknown	equ	3		; unknown command
err_CRC		equ	4		; error CRC command
err_reqlen	equ	5		; bad request length
err_seek	equ	6		; seek failure
err_badmedia	equ	7		; bad media
err_badsector	equ	8		; sector not found
err_badwrite	equ	10		; write fault
err_badread	equ	11		; read fault
err_general	equ	12		; general failure

; ---------------------------------------------------------------------------
;  Structure Definitions

;  The structures defined here are used to find information in the
;  various request header formats.  Of course, being structures, they
;  don't take up space... they are used to define offsets for the
;  addressing of the request header.

rq	equ	es:[bx]			; base address used in routines

;  -- Request Header (General Format)

rhead	struc
	rlen	db	?	; length of the structure
	unitn	db	?	; unit number
	command	db	?	; command code
	status	dw	?	; status code (returned by us)
		db	8 dup(?); reserved bytes
rhead	ends


;  -- Request Header (INIT Command)

inithead	struc
		db	(type rhead) dup (?)
	units	db	?	; number of units
	ndadro	dw	?	; ending address offset
	ndadrs	dw	?	; ending address segment
	bpboff	dw	?	; BPB offset pointer
	bpbseg	dw	?	; BPB segment pointer
	taglet	db	?	; drive tag letter
inithead	ends

;  -- Request Header (Media Check)

mediahead	struc
		db	(type rhead) dup (?)
	media	db	?	; our meida descriptor byte
	change	db	?	; changed media flag
mediahead	ends

;  -- Request Header (Build BPB)

bbpbhead	struc
		db	(type rhead) dup (?)
		db	?	; media descriptor byte
	baoff	dw	?	; transferr buffer address offset
	baseg	dw	?	; transferr buffer address segment
		dw	?	; BIOS parameter block pointer
		dw	?	; BIOS parameter block pointer
bbpbhead	ends

;  -- Request Header (Read and Write)

rwhead		struc
		db	(type rhead) dup (?)
		db	?	; media descriptor byte
	tbaoff	dw	?	; transferr buffer address offset
	tbaseg	dw	?	; transferr buffer address segment
	count	dw	?	; sector count
	strtsec	dw	?	; starting sector number
rwhead		ends


; With these headers defined as they are, access to the request header
; and command info fields is greatly simplified.  By setting ES:BX to
; point to the request header, the information can be easily referenced
; by using constructs such as

;		mov	rq.count,ax
;  or
;		mov	al,rq.command

; Note that any part of the program can easily reference any particular
; command's structure, since the line

;		db	(type rhead) dup (?)

; makes all the command-specific structures "equivalent".

;  This macro is used during debugging.  It prints a single character
; via the BIOS screen interface, and leaves the registers unchanged.

ifdef	DEBUG

	if1
		%OUT  DEBUG Version
	endif
	PrintChar	macro	Char
	
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
		
			endm

else
	PrintChar	macro	Char		; if not debugging, blow it off
			endm
endif

; ---------------------------------------------------------------------------
;  Public declarations for SYMDEB

; These are public declarations included to allow SYMDEB to know where
; various lables and addresses are.  They are only needed for debugging,
; and serve no other useful purpose.

PUBLIC NextPlace
PUBLIC Attrib, JumpTable, TopCommand, RBPoint, RBPointOff, RBPointSeg, SaveSS
PUBLIC SaveSP, SaveAX, EMMHandle, EMMBase, StackTop, STRATPROC, Strategy
PUBLIC INTPROC, Interrupt, NoSaveM, FreakOut, IOCTLInput, ReadNoWait
PUBLIC InputStatus, InputFlush, badcommand, BigLog, NoRestore, MC, MediaCheck
PUBLIC BBPB, BuildBPB, BPBArray, OurBoot, OurBPB, SecSize, SecPerCluster
PUBLIC RDirLen, DiskSize, SecPerFAT, BootCode, TAddr, TAddrOff, TAddrSeg
PUBLIC TDone, TCount, TSector, RSEC, Read, ReadLoop, ReadDone
PUBLIC ReadFinish, ReadError, WSEC, Write, WriteLoop, WriteDone, WriteFinish
PUBLIC WriteError, CLIPPER, RangeError, InRange, SPEAKERCLICK, MakeClick
PUBLIC NoClick, SpeakerFlag, LastTime, GS, GetSector, CantGet, LastResident,
PUBLIC EMMPresent, GenFailHook, EMMPresent2, MemForMe, EatingWhite, GotOption
PUBLIC NoBump, NotSilence, PagesLoop, LastDigit, NotPages, Unrecognized
PUBLIC EndOfLine, GoodSize, GotPages, BigBust, ReTry, GoodCombo, NoKludge
PUBLIC WipeOut, WipeOut2, FindFree, CalcEMMFree, CalcDiskFree, ClickOkay
PUBLIC MsgOkay, InitFail, GenFail, HowMuch, RqdPages, MajorVersion, OurVolume
PUBLIC Banner, EMMIDString, General, NoEMMThere, EMMError, Init
PUBLIC NoMem, TooBig, BadOption, NoClicking, Installed, DriveName, InstalledB
PUBLIC Installed2, UsedSpace, Bin2Dec, Bin2DecLoop, Bin2DecDigit, WorkAreaL
PUBLIC WorkAreaH

; ---------------------------------------------------------------------------

driver		segment	para public 
		assume	cs:driver,ds:driver,es:driver,ss:driver

		org	0		; drivers begin at zero
firstplace	equ	this byte	; this is the first byte

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
; Only the functions marked with a "*" in their comment field
; are actually implemented.  (Since this is a block device, only
; some of the areas are actually used.)

	dw	offset	Init		;  0 * initialize
	dw	offset	MediaCheck	;  1 * media check
	dw	offset	BuildBPB	;  2 * build BIOS parameter block
	dw	offset	IOCTLInput	;  3   I/O Control (Input)
	dw	offset	Read		;  4 * read from device
	dw	offset	ReadNoWait	;  5   read from device (nondest,
					;	no wait, char only)
	dw	offset	InputStatus	;  6   input status
	dw	offset	InputFlush	;  7   flush pending input
	dw	offset	Write		;  8 * Write data
	dw	offset	Write		;  9 * Write data with Verify
;
;	dw	offset	OutputStat	; 10   Output status
;	dw	offset	OutputFlush	; 11   flush pending output
;	dw	offset	IOCTLOutput	; 12   I/O Control (Output)
;	dw	offset	DeviceOpen	; 13   Open Device
;	dw	offset	DeviceClose	; 14   Close Device
;	dw	offset	Removeable	; 15   Removable media check
;
	;  (The commands above 9 are all not implemented -- we don't
	;   make entries for them to optimize for space (and speed).
	;   The equate TopCommand must be set to the last used
	;   command code.)

TopCommand	equ	9		; highest valid command

RBPoint		label	dword		; Pointer to request buffer
RBPointOff	dw	0		; offset part
RBPointSeg	dw	0		; segment part

SaveSS		dw	0		; save place for the SS register
SaveSP		dw	0		; save place for the SP register
SaveAX		dw	0		; save place for the accumulator

EMMHandle	dw	0		; our handle, as assigned by the EMM
EMMBase		dw	0		; base of the EMM physical window

; ---------------------------------------------------------------------------
;  TDATA

;  This is a "temporary" data area that is used to hold the data used
;  by the transfer routines.

TAddr		label	dword
TAddrOff	dw	0		; the transferr (read to, write from)
TAddrSeg	dw	0		;  address

TDone		dw	0		; count of sectors done
TCount		dw	0		; number of sectors to do
TSector		dw	0		; the sector to be transfer

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

		push	bx		; save the other regs
		push	cx
		push	dx
		push	bp
		push	si
		push	di
		pushf			; and the flags
		cld			;  set the string direction up

		push	es		; save the segregs
		push	ds

		mov	ds,ax		; setup the data segment register

		mov	ax,0FFFFh	; wipe out any memory of previous
		mov	LastTime,ax	;  page mappings

	; Note that during calls we use DS to point to our local data
	; and ES to point to the request header.

		les	bx,RBPoint	; get the request buffer
		mov	al,rq.command	;  get the command
		cbw

; be sure that the command is in our range

		cmp	al,TopCommand	; fifteen is the highest for us
		jg	badcommand	;  too high! bad command

; it's a good command - be on the lookout for an unorthodox
; initialization call

		or	al,al		; is it function zero?
		je	NoSaveM		;  yes, don't save the map context

		push	ax		;  no, save the AX register
		mov	ah,E_Save	; save the mapping context
		mov	dx,EMMHandle	;  under our handle
		int	EMM		; ask the manager to do it
		or	ah,ah		; if there was an error,
		jnz	FreakOut	;  freak out!
		pop	ax		; if not, get the AX back

NoSaveM:	shl	ax,1		; (one word offset = 2 bytes)
		mov	si,ax

; fake a "short call" by setting the return address to the exit routine

		mov	ax,offset BigLog
		push	ax
		xor	ax,ax			; clear our status
		jmp	cs:JumpTable[si]	; and hop to it!
		jmp	short BigLog

; ---------------------------------------------------------------------------
;   We come here if we run into an EMM error.  We'll set the "General
;   Failure" flag, and return to MS-DOS

FreakOut:	mov	rq.status,(errorflag+err_general)
						; general failure
						; and error settings
		jmp	short BigLog

; ---------------------------------------------------------------------------
;   Ran into an unsupported command -  set the flag in the status word.


IOCTLInput:
ReadNoWait:	; those table entries are invalid commands
InputStatus:
InputFlush:
		pop	ax		; (forget about the short call)
badcommand:
		mov	ax,(err_unknown+errorflag)  ; an unknown command err

; ---------------------------------------------------------------------------
;   This is the mass exit; everone splits through this point!  When we
;   arrive here, the AX reg will contain the word to be put into the
;   status word.  We'll do that:

BigLog:		
PrintChar 'X'
		les	bx,cs:RBPoint		; point to the request block
		push	ax
		mov	al,rq.command		; was it an init?
		and	al,al			;  yes!  don't restore
		pop	ax
		je	NoRestore

		push	ax
		mov	ah,E_Restore		; restore the EMS
		mov	dx,EMMHandle		;  mapping context
		int	EMM
		or	ah,ah			; if there was an error
		pop	ax
		jnz	FreakOut

NoRestore:	or	ax,donestat		; set the done status
		mov	rq.status,ax

;  Now, we just undo the registers.

		pop	ds		; the seg regs
		pop	es

		popf			; the flags
		pop	di
		pop	si		; and the data regs
		pop	bp
		pop	dx
		pop	cx
		pop	bx

PrintChar 'd'
		mov	ax,CS:SaveAX
		mov	sp,CS:SaveSP	; restore the calling stack
		mov	ss,CS:SaveSS
		ret

INTPROC		endp

; ---------------------------------------------------------------------------
;  MEDIA CHECK

;  This command checks to see if the media has been removed and replaced.
;  Since a RAM drive is non-removable media, this command will always
;  return a "false".

MC		proc	near
PrintChar 'M'
MediaCheck:
		mov	rq.change,1	; media has not been changed
PrintChar 'm'
		ret			; return to leave
MC		endp

; ---------------------------------------------------------------------------
;  BUILD BIOS PARAMETER BLOCK

;  This command simply "builds" a BPB by telling DOS where it is located.

BBPB		proc	near
BuildBPB:
PrintChar 'P'
		mov	rq.bpboff,offset OurBPB		; the offset
		mov	rq.bpbseg,cs			; in our CS
PrintChar 'p'
		ret

BPBArray	dw	offset OurBPB

OurBoot:	db	0,0,0
		db	'NiftyEMS'	;  whodat?
		
OurBPB:
SecSize		dw	512		; standard DOS sector size
SecPerCluster	db	1		; sectors per allocation unit
		dw	1		; number of reserved sectors
		db	1		; number of copies of the FAT
RDirLen		dw	32		; number of root directory entries

DiskSize	dw	1024		; number of sectors on the disk
		db	MediaD		; (media descriptor)
SecPerFAT	dw	1		; number of sectors per FAT

		dw	8		; sectors per track
		dw	1		; number of heads
		dw	0		; number of hidden sectors
BootCode:

OurBootLen	equ	this byte - OurBoot

BBPB		endp


; ---------------------------------------------------------------------------
;  READ

;  This command reads the specified number of sectors starting at the 
;  given sector.  It returns the number of sectors actually read.  Errors
;  are returned if the sector is out of range, or if the number of sectors
;  is past the end of the disk.  (The error checking is done in the
;  CLIPPER procedure.)  This procedure doesn't do much itself.  It's
;  body is mostly a string move instruction.  The starting address
;  and ending address are set up by the CLIPPER procedure.

RSEC		proc	near
Read:
PrintChar 'R'
		call	CLIPPER		; do the clipping, if need be

ReadLoop:	mov	ax,TCount	; are we done transferring yet?
		cmp	TDone,ax
		je	ReadDone	; yes!  quit the loop

		mov	ax,TSector	; no ... do some more!
		call	GetSector
		jc	ReadError
PrintChar 'y'

		mov	si,di		; setup the get from address
		les	di,TAddr	; get the store to address
		mov	cx,256		; number of words to move
		mov	ds,EMMBase

	rep	movsw			; move it!

		mov	ax,cs		; get addressing back
		mov	ds,ax

		add	TAddrOff,512	; increment transferr address
		inc	TDone
		inc	TSector
		jmp	short ReadLoop

ReadDone:	xor	ax,ax		; clear error flags

ReadFinish:	les	bx,[RBPoint]	; point to request header
		push	ax
		mov	ax,TDone	; store actual transferred
		mov	rq.Count,ax
		pop	ax
		jmp	MakeClick	; finish clicking

ReadError:	mov	ax,(err_badread+errorflag)  ; there was an error!
		jmp	short ReadFinish

RSEC		endp


; ---------------------------------------------------------------------------
;  WRITE

;  This command writes the specified number of sectors starting at the
;  given sector.  It returns the number of sectors actually written.
;  Errors are returned if the sector is out of range, or if the number
;  of sectors is past the end of the disk.  (The error checking is done
;  in the CLIPPER procedure.)  The procedure does very little itself;
;  it's body consists mostly of a string move instruction.  The
;  source, destination, and other counts are set up by the CLIPPER
;  procedure.

WSEC		proc	near
Write:
PrintChar 'W'
		call	CLIPPER		; do the clipping, if need be

WriteLoop:	mov	ax,TCount	; are we done transferring yet?
		cmp	TDone,ax
		je	WriteDone	; yep, we are, quit the loop

		mov	ax,TSector	; no ... do some more!
		call	GetSector
		jc	WriteError
PrintChar 'k'
		mov	es,EMMBase
		lds	si,cs:TAddr	; get the store to address
		mov	cx,256		; number of words to move

	rep	movsw			; move it!

		mov	ax,cs		; reset addressing back
		mov	ds,ax

		add	TAddrOff,512	; increment transferr address
		inc	TDone		; count of sectors
		inc	TSector		; and current sector number
		jmp	short WriteLoop

WriteDone:	xor	ax,ax		; clear error flags

WriteFinish:	les	bx,[RBPoint]	; point to request header
		push	ax
		mov	ax,TDone	; store actual transferred
		mov	rq.Count,ax
		pop	ax
		jmp	MakeClick	; finish clicking

WriteError:	mov	ax,(err_badwrite+errorflag)  ; there was an error!
		jmp	short WriteFinish


WSEC		endp

; ---------------------------------------------------------------------------
;  Clipper

;  This local procedure checks the parameters passed to the READ and
;  WRITE commands to be sure that they are valid.  If they are indeed
;  valid, it will call the speaker click procedure to take care of
;  the "audible" options.  It also saves the context of the EMM, and 
;  sets up the EMM to work with our process.

CLIPPER		proc	near

		mov	cx,rq.strtsec	; get the starting sector number
		mov	TSector,cx
		cmp	cx,DiskSize	; is it larger than the drive?
		jg	RangeError	;  yes!  there's an error

		mov	ax,rq.count
		mov	TCount,ax		; save it for later
		add	cx,ax		; add in the number of sec to read
		cmp	cx,DiskSize	; is it larger than life?
		jle	InRange		;  no... it's okay

RangeError:	pop	ax		; forget our our return address
		mov	ax,err_badsector; that's a bad sector!
		or	ax,errorflag	;  (and that's an error in my book)
		mov	rq.count,0	; no sectors were read, you know
		ret			;  return back to the dispatcher

InRange:	mov	ax,rq.tbaoff		; get the transfer base addr
		mov	TAddrOff,ax
		mov	ax,rq.tbaseg
		mov	TAddrSeg,ax
		xor	ax,ax		; zero transferred count
		mov	TDone,ax

		; just flow through to MakeClick

CLIPPER		endp

; ---------------------------------------------------------------------------
;  This is a local procedure that clicks the speaker transparently.  It
;  is executed at the end of the CLIPPER procedure, which is excuted
;  at the very beginning of the "READ" and "WRITE" functions.  It is
;  also JMP'd to at the end of the READ and WRITE routines, and the RET
;  at the end of this procedure will return to the caller of the READ
;  and WRITE functions.  (Saves 2 bytes and a bunch of clocks, hey.)

SPEAKERCLICK	proc	near

MakeClick:	pushf
		cmp	SpeakerFlag,0		; should we?
		je	NoClick			;  no, forget it happened

		push	ax			; yes, save the accumulator
		in	al,Speak
		and	al,SpeakMask		; mask out the bit we don't need
		xor	al,SpeakToggle		; toggle the control bit
		out	Speak,al		; and re-output it
		pop	ax			; retrieve the accumulator

NoClick:	popf
		ret			; return to the caller

SpeakerFlag	db	1		; one if we should be ticking
					;	(the default is ticking)

SPEAKERCLICK	endp

; ---------------------------------------------------------------------------
;  GetSector

;  This routine calls the EMM to map the page with the requested sector
;  into the physical window.  On entry, AX contains the requested sector.
;  On exit, the EMS is setup so that the requested sector is in the window.
;  [EMMBASE]:DI will point to it.  This routine is rather funky; it does
;  the mapping using the slippery shift functions, instead of using DIV
;  or a lookup table.  *SUPER FAST*!

GS		proc	near

GetSector:
PrintChar 'G'
		cmp	ax,DiskSize	; check the range!
		jg	CantGet

		push	ax		; save a copy of the number
		mov	cl,5
		shr	ax,cl		; divide the sector by 32
					;   so that AX=EMM Page

		cmp	ax,LastTime	; is it the same thing 
		je	Optimized	;  we got last time?

		mov	LastTime,ax	; remember it for later

		mov	bx,ax		; nah, we'll have to get this one
		mov	ah,E_MapPage
		mov	al,0		; map it into zero
		mov	dx,EMMHandle
		int	EMM
		or	ah,ah		; was there an error?
		jne	CantGet

Optimized:	pop	ax		; retrieve the remainder
		and	ax,01Fh		; mask out high bits of offset
		mov	cl,9
		shl	ax,cl		; find the offset of the sector
		mov	di,ax
		clc
PrintChar 'g'
		jmp	short MakeClick	; tick-tock on the way out

CantGet:	pop	ax	; forget the remainder, since there was err
		stc		; set the error flag, if error
		ret

; An ingenious optimization, if I must say so myself.  This variable holds
; the last EMS logical page that was fetched by this routine.  This way,
; the program never gets the same page twice in a row.  It's reset to
; 0FFFFh by the Interrupt routine so that we won't forget to get a page
; when one hasn't been attained.  (0FFFFh is a unique code that will never
; correspond to an actual page.)  Since DOS often does more than one
; sequential read or write in a single call to the driver, this small
; feature can save quite a bit of time.

LastTime	dw	0FFFFh

GS		endp

; ---------------------------------------------------------------------------
;  This label marks the last byte of the device driver that actually
;  remains resident.  This driver takes less than 800 bytes, guaranteed.

LastResident:
; ---------------------------------------------------------------------------
;  INITIALIZE

;  This command sets up the internal data used by NJRAMD.  The procedure
;  sets the EMM to get the number of pages that the user requests.  (The
;  information following the specification in the CONFIG.SYS file is
;  parsed to find the user parameters.  See the NJFRAMD.DOC file to find
;  the format of the CONFIG information.)  The procedure requests memory
;  from the EMM

Init:
PrintChar 'I'
		mov	dx,offset Banner
		mov	ah,PrintString		; show our copyright!
		int	21h

		mov	ah,GetDOSVersion	; get the DOS version
		int	21h
		mov	MajorVersion,al

		xor	ax,ax			; point to the 0000 segment
		mov	es,ax
		mov	bx,(EMM*4)+2		; find the EMM interrupt
		mov	ax,es:[bx]
		mov	es,ax			; point to the EMM device
		mov	di,10			; header

		mov	si,offset EMMIDString	; point to the EMM identifier
		mov	cx,8
	repz	cmpsb				; compare a bunch of bytes
		jz	EMMPresent

		mov	dx,offset NoEMMThere	; point to our error
		jmp	InitFail		;  the EMM isn't there!!

EMMPresent:	; the Extended Memory Manager is present.  It's okay!
		; get the EMM Page base, and save it for future reference.

		mov	ah,E_PageBase		; get the page base
		int	EMM
		or	ah,ah
		je	EMMPresent2		; general failure?
GenFailHook:	jmp	GenFail			;  (RELATIVE JMP OUT OF RANGE

EMMPresent2:	mov	EMMBase,bx		; save it for later

		mov	ah,E_Counts		; get count of available
		int	EMM			; memory
		or	ah,ah
		jne	GenFailHook		; general failure?
						;  (RELATIVE JMP OUT OF RANGE)

		cmp	bx,0		; is there any left for me?
		jne	MemForMe

		mov	dx,offset NoMem	; print error
		jmp	InitFail

MemForMe:	mov	HowMuch,bx		; remember how much is left

	; We will now attempt to parse the line of the CONFIG.SYS
	; file to see if any of our options are on it.

		les	bx,[RBPoint]		; get pointer to header
		les	si,es:[bx+18]		; get pointer to commands

EatingWhite:	mov	al,es:[si]		; get the next byte
		inc	si
		cmp	al,cr			; is it a carriage return?
		je	EndOfLine
		cmp	al,'-'			; is it an option marker?
		je	GotOption		; yeah! go process it!
		cmp	al,'/'
		jne	EatingWhite		; no... go back for more

	; We are now pointing at the text of an option.  We will
	; get the option into the al to see exactly what it is, and we
	; will then act accordningly.

GotOption:	mov	al,es:[si]		; get the option
		inc	si			;  and increment the pointer
		cmp	al,'a'			; bump it to upper case?
		jl	NoBump			;  no need to
		cmp	al,'z'
		jg	NoBump			;  no need to

		sub	al,('a' - 'A')		; make it lower case
		
NoBump:		cmp	al,'S'			; is it a silence option?
		jne	NotSilence		;   no...
		mov	SpeakerFlag,0		; yes, it is.  Reset the option!
		jmp	EatingWhite		; and eat up until end of
						;  this option

NotSilence:	cmp	al,'P'			; is it the pages option?
		jne	NotPages

	; We will handle the pages option by reading the command line until
	; a non-numeric character.  The resulting number will be the number
	; of pages that the user requested.

		xor	dx,dx		; zero the result

PagesLoop:	mov	al,es:[si]	; get the character
		inc	si
		cmp	al,'0'		; is it a number?
		jl	LastDigit	;  nope!
		cmp	al,'9'		; is it a number?
		jg	LastDigit	;  note!

		push	ax		; save the digit temporarily
		mov	ax,10
		mul	dx		; multiply it out
		pop	dx		; pop the digit into dx

		and	dx,0Fh		; make a decimal digit of it
		add	dx,ax		; add it into the sum
		jmp	short PagesLoop

LastDigit:	mov	RqdPages,dx	; save requested number of pages
		and	dx,dx		; is the requested page number zero?
		je	BadPages	;  yeah!  can't have that
		cmp	al,cr		; was that last char a CR?
		je	EndOfLine	;  yes! end of the parse
		jne	EatingWhite	;  no, go back for more parsing

BadPages:	mov	dx,offset TooSmall
BadPages2:	jmp	InitFail

NotPages:
Unrecognized:	mov	dx,offset BadOption	; don't install
		jmp	short BadPages2



EndOfLine:	; The parsing is done!  We will now check to see if the
		; requested size is bigger than the available memory.

		mov	ax,RqdPages		; is the reqested amount
		cmp	HowMuch,ax		;  greater than available?
		jge	GoodSize		; no, size is good

		mov	dx,offset TooBig	; yes, that's an error
		jmp	InitFail

GoodSize:	; Now, we'll try to allocate that many pages.  If the user
		; didn't specify a number of pages, the default is 32 pages,
		; which is 512k of storage.

		mov	bx,ax
		mov	ah,E_Open	; open a new handle of (BX) pages
		int	EMM
		or	ah,ah
		je	GotPages	; (RELATIVE JMP OUT OF RANGE)
		jmp	GenFail

GotPages:	mov	EMMHandle,dx		; save the handle for later

	; We will now setup the information in the BPB to reflect the
	; status of the RAM drive.  First, we'll store the DiskSize.

		mov	ax,RqdPages		; get number of pages
		mov	cl,5			; thirty-two 512-byte sectors
		shl	ax,cl			;  in a 16384-byte page
		mov	DiskSize,ax		; store it in BPB

	; Now, we'll figure out how many entries there will be in the
	; root directory.  We will allow 1 root directory entry for
	; each 2k of storage that the disk has.  We won't allow moer
	; than 512 root dir entries, though.

		mov	cl,2			; figure out length of
		shr	ax,cl			; root directory
		cmp	ax,512			;  1 entry per 2k of storage
		jl	BigBust			;  up to 512

		mov	ax,512

BigBust:	add	ax,31			; make sure it's a multiple
		and	ax,not 31		; of 32  (round it)
		mov	RDirLen,ax

	; Since we use a 12-bit FAT, we must have 4087 clusters or less.
	; We will start with a 1024-byte cluster, and double the cluster
	; size until we have enough FAT space.  The maximum amount of
	; memory on a single EMS card is 2 megabytes.  A user must
	; configure about 3.75 megabytes of memory as a RAM drive to
	; cause the program to use 2048-byte clusters... otherwise, the
	; drive will have 1024-byte clusters.

		mov	cx,2			; Two clusters per sector
						;  for starters.

ReTry:		mov	ax,DiskSize		; get the disk size
		xor	dx,dx
		div	cx			; AX = (DiskSize/SPC)
		cmp	ax,4087			; is it less than 4087?
		jl	GoodCombo		;  yeah!
		shl	cx,1			; no. double the SPC and
		jnc	ReTry			; try it again

GoodCombo:	mov	SecPerCluster,cl	; save SPC number

	; AX still is set to the number of clusters on the disk.  Very
	; useful number, you know.  We will find now the amount of FAT
	; space that is needed.

		mov	bx,ax		; ax = clustsers
		add	ax,ax		; ax = 2*(clusters)
		add	ax,bx		; ax = 3*(clusetrs)
		shr	ax,1		; ax = 1.5*(clusters)

		xor	dx,dx		;	  (FAT Length)
		mov	cx,512		; AX =	----------------
		div	cx		;       (BytesPerSector)

		or	dx,dx		; is there a remainder?
		je	NoKludge
		inc	ax		;  yes, add another sector

NoKludge:	mov	SecPerFAT,ax	; store it in the BPB

	; The BPB is now set up properly.  We will now "format" the
	; RAM disk.  First, we will have to set all the RAM area to
	; zero.  (Even on extremely large "drives", this doesn't take
	; very long.  Especially if you have an IBM PS/2 System 80 --
	; and then, all the chicks will dig ya!)

		mov	cx,RqdPages	; get number of pages in disk

WipeOut:	mov	bx,cx		; ask for this page
		dec	bx
		mov	dx,EMMHandle	; into physical page zero
		mov	ah,E_MapPage
		mov	al,0
		int	EMM

		or	ah,ah
		je	WipeOut2	; if there was an error, get out
		jmp	GenFail		;	(RELATIVE JMP OUT OF RANGE)

WipeOut2:	mov	es,EMMBase	; get addressing to it
		xor	ax,ax		; store a zero
		mov	di,ax		; zero the destination
		push	cx
		mov	cx,8192		; *words* in a page
	repne	stosw

		pop	cx
		loop	WipeOut		; if more, go back

	; Now that everything is zeroed, we will copy the pseudo-boot
	; sector that we have.  DOS uses some of this information while
	; reading and writing the disk, so we set it up there.

		xor	ax,ax		; get the 0 sector
		call	GetSector
		mov	es,EMMBase
		mov	si,offset OurBoot
		mov	cx,OurBootLen
	rep	movsb			; move it in there

	; The boot sector has been written in.  We will now set up
	; the FAT.  This task is rather simplified, since we only
	; have one copy of the FAT.

		mov	ax,1
		call	GetSector	; get sector 1
		mov	byte ptr es:[di],MediaD
		mov	word ptr es:[di+1],0FFFFh

	; Now, we will figure out where the first directory sector is.
	; *WARNING* - This code assumes that there is only one copy of
	; the FAT, and that there is one reserved sector.  If ya change
	; the drive to have 2 copies of the FAT, or modify it to have
	; reserved sectors (for whatever reason you'd wanna do that),
	; you'll have to change this code fragment!

		mov	ax,SecPerFAT
		inc	ax		; AX = first dir sector
		call	GetSector
		mov	si,offset OurVolume
		mov	cx,OurVolumeLen		; move words
	rep	movsw

	; Phew!  Now the whole thing is done!  We will show the user
	; what has been done.  First, we will figure out what device
	; tag that we have.  We will tell the user about it.  DOS versions
	; earlier than 3.00 don't let us know what our device tag is,
	; so we can't tell the user.

		les	bx,[RBPoint]	; point to the header, again
		mov	al,rq.taglet	; get the tag letter
		add	al,'A'		; change it to a capital drive letter.
		mov	DriveName,al

		mov	bx,offset LastResident	; calculate used size
		xor	ax,ax
		mov	si,offset UsedSpace
		call	Bin2Dec			; store it in the messgae

		mov	ah,E_Counts		; find amount of space left
		int	EMM			; in the EMS memory
		or	ah,ah
		je	FindFree
		jmp	GenFail

FindFree:	xor	ax,ax		; zero high side (the EMM call put
					;  the # of free pages in BX.)
		mov	cx,14		; multiply the # of pages by 16k
CalcEMMFree:	rcl	bx,1		; shift it low side
		rcl	ax,1		;  and carry though to high side
		loop	CalcEMMFree

		mov	si,offset Installed2
		call	Bin2Dec		; put it into the message!

		mov	ax,DiskSize	; get sectors of disk space
		sub	ax,SecPerFAT	; subtract space used by the FAT
		mov	bx,ax		; put that subtotal in bx

		mov	ax,RDirLen	; get the entries in the root dir
		mov	cl,4
		shr	ax,cl		; divide by # of entries per sec
		sub	bx,ax		; subtract some more
		dec	bx		; and adjust down

		mov	cx,9		; multiply the answer by 512
		xor	ax,ax		; zero the high side
CalcDiskFree:	rcl	bx,1		; shift low side up
		rcl	ax,1		;  shift high side over, with carry
		loop	CalcDiskFree

		mov	si,offset Installed
		call	Bin2Dec		; store it in the message

		mov	al,SpeakerFlag		; is there clicking?
		or	al,al
		jne	ClickOkay
		mov	ah,PrintString
		mov	dx,offset NoClicking	; tell the user that it's
		int	21h			; been diasbled.

ClickOkay:	mov	al,MajorVersion
		cmp	al,3		; is it version three?
		je	MsgOkay

		mov	al,eos		; its version two
		mov	DriveName,al
	
MsgOkay:	mov	dx,offset Installed	;print part one of 
		mov	ah,PrintString		;  installed! message
		int	21h

		mov	dx,offset InstalledB	;print part two
		int	21h

		les	bx,[RBPoint]		; get that pesky pointer

		mov	ax,offset LastResident 	; show DOS where we end
		mov	rq.ndadro,ax		;   offset
		mov	ax,cs			; show DOS were we end
		mov	rq.ndadrs,ax		;   segment
		mov	rq.bpbseg,ax		; show DOS the BPB array

		mov	rq.units,1		; we installed one unit
		mov	ax,offset BPBArray	; BPB array offset
		mov	rq.bpboff,ax

		xor	ax,ax		; no return value
		ret

; ---------------------------------------------------------------------------
;  Init failure

;  We will come here if there is a failure during the initialization
;  of the driver.  We print a message letting the user know why we can't
;  install, and we then zero ourselves out so that DOS doesn't waste any
;  memory on us.

InitFail:	push	dx		; save the specific error
		mov	dx,offset General
		mov	ah,PrintString
		int	21h

		pop	dx		; now print specific error
		mov	ah,PrintString
		int	21h

		les	bx,[RBPoint]	; point to the request header
		mov	ax,cs

		mov	rq.ndadrs,ax	; ending address is zero

		xor	ax,ax		;  because no memory is taken
		mov	rq.ndadro,ax	;  since we failed
		mov	rq.units,al	; no units, either
PrintChar 'i'
		ret

; ---------------------------------------------------------------------------
;  General Failure

;  There was an EMM Failure during the installation.  If such is the case,
;  we will terminate with an error message, and then go to the regular
;  fail routine.

GenFail:	mov	dx,offset EMMError
		jmp	short InitFail


; ---------------------------------------------------------------------------
;  Transient Data Area

;  The TDA contains the variables used by the Initialization segment of
;  the device driver.  It doesn't stay resident.

HowMuch		dw	?		; amount of free EMS, in pages
RqdPages	dw	32		; amount of pages requested
					;	(512k is the default)
MajorVersion	db	3		; the DOS major version number

OurVolume	db	'Niftys_Disk'	; 11-byte volume name
		db	000001000b	;  volume label attribute
		db	10 dup (0)	; reserved space
		dw	953
			;FEDCBA9876543210b
			;YYYYYYYMMMMDDDDD
		dw	00000111010111001b	; DATE = May 25, 1987
		db	6 dup (0)	; more reserved space

OurVolumeLen	equ	16

; ---------------------------------------------------------------------------
;  Messages

;  These are messages that are used by the initialization section of the
;  driver.

Banner		db	cr,lf,"Nifty James Famous E/EMS RAMdisk Drive",cr,lf
		db	'Copyright 1987 by Mike Blaszczak',cr,lf
		db	'Version 1.15 of 31 May 1987',cr,lf,lf,eos

EMMIDString	db	'EMMXXXX0'

General		db	'Device not installed.',cr,lf,eos

NoEMMThere	db	'The EMM is not installed.',cr,lf,lf,eos

EMMError	db	'EMM failure during installation.',cr,lf,lf,eos

NoMem		db	'No free EMM Memory.',cr,lf,lf,eos

TooBig		db	'Requested size too big to fit.',cr,lf,lf,eos

TooSmall	db	"Can't have zero disk size.",cr,lf,lf,eos

BadOption	db	'Unrecognized option encountered.',cr,lf,lf,eos

NoClicking	db	'Clicking suppressed.',cr,lf,eos

; "Installed" marks the beginning of the information that is printed
; if the device is successfully installed.  The beginning of each
; line has eight spaces, which are filled with the information by the
; BIN2DEC procedure.  There is then one more space, so that the end
; of the number doesn't bump the first word... thus, a total of nine
; spaces begin the Installed, Installed2, and UsedSpace labels.

Installed	db	'         bytes available on RAM drive '
DriveName	db	'_:.',eos

InstalledB	db	cr,lf
Installed2	db	'         bytes left in EMS storage.',cr,lf
UsedSpace	db	'         bytes of standard DOS memory were'
		db	' taken.',cr,lf,lf
		db	eos

; ---------------------------------------------------------------------------
;  Init Subroutines

;  The following area contains subroutines used by the INIT procedure of
;  the device driver.  They aren't kept in memory after the device has been
;  installed.

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

driver		ends
		end

; That's a wrap.
; Special thanks to Bob Brody and Dr File Finder~~~~~~~~~~~~.

