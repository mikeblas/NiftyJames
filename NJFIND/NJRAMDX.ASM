; DEBUG   EQU TRUE

V286    EQU TRUE                        ; No XMS on 8088 PC's!

;  Nifty James' Famous Expanded Memory Disk Drive
;  (C) Copyright 1987 by Mike Blaszczak.  All Rights Reserved

;  Version 1.01  of  24 May 1987
;  Version 1.10  of  25 May 1987
;  Version 1.15  of  31 May 1987
;  Version 1.20  of  16 Oct 1987

;  Modified Terje Mathisen 20 March 90
;  Version 1.02 of XMS-compatible NJRAMDX 14 Sep 1990
;  Version 1.40  of  23 Jun 1991 by Mike Blaszczak

;  Shareware  $15     Please contribute!

;  Assemble with
;	TASM NJRAMDX
;		(Comment out V286 EQU TRU for 8088 version.)
;	TLINK /t NJRAMDX, NJRAMDX.SYS

;  --> DEVICE DRIVER FORMAT FILE <--

; ---------------------------------------------------------------------------

;   ASCII Characters

bell		equ	7		; bell character
tab		equ	9		; tab character
lf		equ	10		; linefeed
cr		equ	13		; carriage return
space		equ	32		; space
eos		equ	'$'		; end of DOS string

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
;  XMS Routines

; These are the XMS functions that we use.  (These are specific functions
; of the XMS call.)

X_Counts	equ	08h		; determine free/total mem
X_Alloc		equ	09h		; open, allocate, obtain handle ID
X_Version	equ	00h		; get the XMS version number
X_Move		equ	0Bh		; move an XMS block

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

rq	equ	es:bx			; base address used in routines

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

;		mov	[rq.count],ax
;  or
;		mov	al,[rq.command]

; Note that any part of the program can easily reference any particular
; command's structure, since the line

;		db	(type rhead) dup (?)

; makes all the command-specific structures "equivalent".

; XMS Extended Memory Move structure

ExtendedMemoryMove     STRUC
  NrOfBytes       dw 0,0
  SourceHandle    dw 0
  SourceOffset    dw 0,0
  DestHandle      dw 0
  DestOffset      dw 0,0
ExtendedMemoryMove     ENDS

; Check to see if this is the 286 version

ifdef  V286
	.286
;	if1
		%OUT	Enhanced processor version
;	endif
	ifdef	PCL
;	if1
		%OUT	for the PC's Limited 286/386
;	endif
	endif
else
;	if1
		%OUT	Standard Version
;	endif
endif

;  This macro is used during debugging.  It prints a single character
; via the BIOS screen interface, and leaves the registers unchanged.

ifdef	DEBUG

;	if1
		%OUT  DEBUG Version
;	endif
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
;			int	017h

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
;  Public declarations for SYMDEB

; These are public declarations included to allow SYMDEB to know where
; various lables and addresses are.  They are only needed for debugging,
; and serve no other useful purpose.

IF 1

PUBLIC NextPlace
PUBLIC Attrib, JumpTable, TopCommand, RBPoint, RBPointOff, RBPointSeg, SaveSS
PUBLIC SaveSP, StackTop, STRATPROC, Strategy
PUBLIC INTPROC, Interrupt, FreakOut, IOCTLInput, ReadNoWait
PUBLIC InputStatus, InputFlush, badcommand, BigLog, MC, MediaCheck
PUBLIC BBPB, BuildBPB, BPBArray, OurBoot, OurBPB, SecSize, SecPerCluster
PUBLIC RDirLen, DiskSize, SecPerFAT, BootCode
PUBLIC RSEC, Read
PUBLIC WSEC, Write
PUBLIC TestValues, RangeError, SPEAKERCLICK, MakeClick
PUBLIC SpeakerFlag, LastResident
PUBLIC EatingWhite, GotOption
PUBLIC NoBump, NotSilence, PagesLoop, LastDigit, NotPages, NotUseAll
PUBLIC Unrecognized, EndOfLine, BigBust, ReTry
PUBLIC GoodCombo, WipeOut
PUBLIC CalcDiskFree, ClickOkay, MsgOkay, InitFail, GenFail, HowMuch
PUBLIC RqdPages, MajorVersion, OurVolume, Banner, General
PUBLIC NoEMMThere, EMMError, Init, NoMem, TooBig, BadOption, NoClicking
PUBLIC Installed, DriveName, InstalledB, Installed2, UsedSpace, Bin2Dec
PUBLIC Bin2DecLoop, Bin2DecDigit, WorkAreaL, WorkAreaH

ENDIF

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
		db	1,'NJTMDSK'		;  Nifty James/TM' Disk!

; ---------------------------------------------------------------------------

        ALIGN 2

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

R_EMM   ExtendedMemoryMove <>           ; EMM block for read requests
W_EMM   ExtendedMemoryMove <>           ; EMM block for write

EMM_Vector      dd ?

; ---------------------------------------------------------------------------
;  The local stack

		even			; make the stack a word-aligned area
		dw	128 dup ('TM')  ; HIMEM.SYS may need 256 byte stack!
StackTop:

; ---------------------------------------------------------------------------
;  Strategy Entry Point For the Device Driver

;  This routine simply stores the pointer to the request header
;  so that request header has it.  That's all it does.  Really.

STRATPROC	proc	far

Strategy:
	mov	[cs:RBPointOff],bx
	mov	[cs:RBPointSeg],es	; just store the pointer
	ret				; and get outta here!
	; (isn't it ironic that the shortest routine is called "Strategy"?)
STRATPROC	endp

; ---------------------------------------------------------------------------
;  Interrupt Entry Point For the Device Driver

;  This routine executes the command contained in the passed request header.
;  DOS has called STRATEGY, and that routine stored a pointer to the request
;  header for our use.  We will construct our own stack area because the 
;  XMS driver uses a great deal of stack space. (Up to 256 bytes!)

INTPROC		proc	far
Interrupt:	
PrintChar 'D'
                push    ax                      ; TMA

		mov	[CS:SaveSS],ss		; save the SS register
		mov	[CS:SaveSP],sp		; save the SP register

                mov     ax, cs                  ;TMA mod
		cli
		mov	ss, ax
		mov	sp, offset StackTop	; initialize our stack
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

		mov	ds,ax		; setup the data segment register

	; Note that during calls we use DS to point to our local data
	; and ES to point to the request header.

		les	bx,[RBPoint]	; get the request buffer
		mov	al,[rq.command]	;  get the command
		cbw                     ; word for jump table

; be sure that the command is in our range

		cmp	al,TopCommand	; fifteen is the highest for us
		 ja	badcommand	;  too high!    # UNSIGNED! TMA

                shl	ax,1		; (one word offset = 2 bytes)
		mov	si,ax

; fake a "short call" by setting the return address to the exit routine

	ifdef V286
		push	offset BigLog
        else
		mov	ax,offset BigLog
		push	ax
        endif
		mov	ax,donestat		; assume OK
		jmp	JumpTable[si]           ; and hop to it!

; ---------------------------------------------------------------------------
;   We come here if we run into an XMS error.  We'll set the "General
;   Failure" flag, and return to MS-DOS

FreakOut:	mov	ax,(errorflag+err_general+donestat)
						; general failure
						; and error settings
		jmp	short BigLog

; ---------------------------------------------------------------------------
;   Ran into an unsupported command -  set the flag in the status word.

BadInit:        ; A second INIT call is a NO-NO
IOCTLInput:
ReadNoWait:	; those table entries are invalid commands
InputStatus:
InputFlush:
		pop	ax		; (forget about the short call)
badcommand:
	mov	ax,(err_unknown+errorflag+donestat) ; an unknown command err

; ---------------------------------------------------------------------------
;   This is the mass exit; everone splits through this point!  When we
;   arrive here, the AX reg will contain the word to be put into the
;   status word.  We'll do that:

BigLog:		
PrintChar 'X'

		mov	[rq.status],ax

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
		mov	ss,[CS:SaveSS]
		mov	sp,[CS:SaveSP]	; restore the calling stack
		sti

                pop     ax              ; TMA
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
		mov	[rq.change],1	; media has not been changed
PrintChar 'm'
		ret			; return to leave
MC		endp

; ---------------------------------------------------------------------------
;  BUILD BIOS PARAMETER BLOCK

;  This command simply "builds" a BPB by telling DOS where it is located.

BBPB		proc	near
BuildBPB:
PrintChar 'P'
		mov	[rq.bpboff],OFFSET OurBPB      	; the offset
		mov	[rq.bpbseg],cs			; in our CS
PrintChar 'p'
		ret

BPBArray	dw	offset OurBPB

OurBoot:	db	0,0,0
		db	'TerjeXMS'	;  whodat?
		
OurBPB:
SecSize		dw	512		; standard DOS sector size
SecPerCluster	db	1		; sectors per allocation unit
		dw	1		; number of reserved sectors
		db	1		; number of copies of the FAT
RDirLen		dw	32		; number of root directory sectors TMA

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
;  WRITE

;  This command writes the specified number of sectors starting at the
;  given sector.  It returns the number of sectors actually written.
;  Errors are returned if the sector is out of range, or if the number
;  of sectors
;  is past the end of the disk.  (The error checking is done in the
;  TestValues procedure.)  This procedure doesn't do much itself.  It's
;  body is mostly an XMS move call.

WSEC		proc	near
Write:
	ifdef PCL
		mov	al,'N'
		out	097h,al
		mov	al,'J'
		out	096h,al		; display "NJ-W" on Smart-Vu
		mov	al,'-'
		out	095h,al
		mov	al,'W'
		out	094h,al
	endif

PrintChar 'W'

                mov     si, offset W_EMM

                call    TestValues

                mov     [si.DestOffset+1],ax

                mov     [si.SourceOffset],cx
                mov     [si.SourceOffset+2],dx

                 jmp     Do_XMS_Transfer

WSEC		endp

; ---------------------------------------------------------------------------
;  READ

;  This command reads the specified number of sectors starting at the 
;  given sector.  It returns the number of sectors actually read.  Errors
;  are returned if the sector is out of range, or if the number of sectors
;  is past the end of the disk.  (The error checking is done in the
;  TestValues procedure.)  This procedure doesn't do much itself.  It's
;  body is mostly a call for an XMS move instruction.

RSEC		proc	near
Read:

	ifdef PCL
		mov	al,'N'
		out	097h,al
		mov	al,'J'
		out	096h,al		; display "NJ-R" on Smart-Vu
		mov	al,'-'
		out	095h,al
		mov	al,'R'
		out	094h,al
	endif

PrintChar 'R'

                mov     si, offset R_EMM

                call    TestValues      ; AX = Sec# Shl 1, DX:CX = TBA

                mov     [si.SourceOffset+1],ax

                mov     [si.DestOffset],cx
                mov     [si.DestOffset+2],dx

Do_XMS_Transfer:                        ; Common code for Read & Write
                mov     ah, X_Move
                call    [EMM_Vector]
                or      ax,ax
                 jz     XMS_Transfer_Error

                mov     ax,donestat	; OK!

ReadClick label byte
		jmp     MakeClick	; finish clicking

XMS_Transfer_Error:
                mov	ax,(err_general+errorflag+donestat)
                mov     [rq.Count],0    ; Tell DOS nothing done!

WriteClick label byte
		 jmp     MakeClick	; finish clicking
        
RSEC		endp


RangeError:	pop	ax		; forget our return address
		mov	ax,err_badsector + errorflag + donestat ; TMA
		mov	[rq.count],0	; no sectors were read, you know
		ret			;  return back to the dispatcher

TestValues      proc near

                mov     ax,[rq.strtsec]
                mov     dx,ax
                mov     cx,[rq.count]
                add     dx,cx
                 jc     RangeError
                cmp     dx,DiskSize
                 ja     RangeError

                shl     ax,1            ; 512 byte/sector = 256 Shl 1
                shl     cx,1            ; NrOfSectors Shl 9
                mov     [si.NrOfBytes+1],cx
                mov     cx,[rq.tbaoff]
                mov     dx,[rq.tbaseg]

TestValues      endp

; ---------------------------------------------------------------------------
;  This is a local procedure that clicks the speaker transparently.  It
;  is executed at the end of the TestValues procedure, which is excuted
;  at the very beginning of the "READ" and "WRITE" functions.  It is
;  also JMP'd to at the end of the READ and WRITE routines, and the RET
;  at the end of this procedure will return to the caller of the READ
;  and WRITE functions.  (Saves 2 bytes and a bunch of clocks, hey.)

;  From here modified by TMA: Uses self-modifying code to decrease the size

;  If no clicks, the init call will modify the PUSHF to a RETN, and save
;  the rest of the proc from staying resident. The JMPs from READ & WRITE
;  to this proc will also be patched into RETNs. This way, we don't have to
;  test the SpeakerFlag at each call.

SPEAKERCLICK	proc	near

MakeClick:	pushf

		push	ax			; yes, save the accumulator
		in	al,Speak
		and	al,SpeakMask		; mask out the bit we don't need
		xor	al,SpeakToggle		; toggle the control bit
                jmp     $+2                     ; For fast PC's
		out	Speak,al		; and re-output it
		pop	ax			; retrieve the accumulator

                popf
NearRet label byte                      ; TMA Use this to get RETN opcode
		ret			; return to the caller

SPEAKERCLICK	endp

; ---------------------------------------------------------------------------
;  This label marks the last byte of the device driver that actually
;  remains resident.  This driver takes less than 800 bytes, guaranteed.

LastResident    dw      $               ; Current End Of Program

SpeakerFlag	db	1		; one if we should be ticking

                JUMPS                   ; Non-critical code

; ---------------------------------------------------------------------------
;  INITIALIZE

;  This command sets up the internal data used by NJRAMD.  The procedure
;  sets the XMS to get the number of kB that the user requests.  (The
;  information following the specification in the CONFIG.SYS file is
;  parsed to find the user parameters.  See the NJFRAMD.DOC file to find
;  the format of the CONFIG information.)  The procedure requests memory
;  from the XMS driver

Init:
PrintChar 'I'
		mov	dx,offset Banner
		mov	ah,PrintString		; show our copyright!
		int	21h

		mov	ah,GetDOSVersion	; get the DOS version
		int	21h
		mov	[MajorVersion],al

                mov     ax,4300h
                int     2Fh                     ; Is an XMS driver loaded?
                cmp     al,80h
		mov	dx,offset NoEMMThere	; point to our error
		 jne	InitFail                ; No XMS driver!

PrintChar '1'
                ; the XMS is present.  It's okay! Get EMM_Vector to call

                mov     ax,4310h
                int     2Fh
                mov     word ptr [EMM_Vector],bx
                mov     word ptr [EMM_Vector+2],es

		mov	ah,X_Counts		; get count of available
		call    [EMM_Vector]		; memory
; QEMM 5.1	or	bl,bl
;		 jl	GenFail 		; general failure?

PrintChar '2'
		cmp	ax,16		; At least 16 kB?
		mov	dx,offset NoMem	; print error
		 jb     InitFail

PrintChar '3'
                mov	[HowMuch],ax		; remember how much is left

	; We will now attempt to parse the line of the CONFIG.SYS
	; file to see if any of our options are on it.

		les	bx,[RBPoint]		; get pointer to header
		les	si,es:[bx+18]		; get pointer to commands

EatingWhite:	lods byte ptr es:[si]		; get the next byte
		cmp	al,cr			; is it a carriage return?
		 je	EndOfLine
                cmp     al,'0'
		 jb	NotPages
                cmp     al,'9'
                 ja     NotPages

	; We will handle the pages option by reading the command line until
	; a non-numeric character.  The resulting number will be the number
	; of kB that the user requested.

		xor	dx,dx		; zero the result
                sub     al,'0'
                mov     dl,al

PagesLoop:	lods    byte ptr [es:si]; get the character
		cmp	al,'0'		; is it a number?
		 jb	LastDigit	;  nope!
		cmp	al,'9'		; is it a number?
		 ja	LastDigit	;  note!

		push	ax		; save the digit temporarily
		mov	ax,10
		mul	dx		; multiply it out
		pop	dx		; pop the digit into dx

		and	dx,0Fh		; make a decimal digit of it
		add	dx,ax		; add it into the sum
		jmp	short PagesLoop

LastDigit:	mov	[RqdPages],dx	; save requested number of pages
		cmp	dx,16		; is the requested # of KB < 16
		 jb	BadPages	;  yeah!  can't have that
		cmp	al,cr		; was that last char a CR?
		 je	EndOfLine	;  yes! end of the parse
		 jne	EatingWhite	;  no, go back for more parsing

BadPages:	mov	dx,offset TooSmall
BadPages2:	jmp	InitFail

NotPages:
		cmp	al,'-'			; is it an option marker?
		 je	GotOption		; yeah! go process it!
		cmp	al,'/'
		 jne	EatingWhite		; no... go back for more

	; We are now pointing at the text of an option.  We will
	; get the option into the al to see exactly what it is, and we
	; will then act accordningly.

GotOption:	lods byte ptr es:[si]		; get the option
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

NotSilence:
                cmp	al,'A'			; is it use all memory?
		 jne	NotUseAll

		mov	ax,[HowMuch]
		mov	[RqdPages],ax		; request them all (KB)
		 jmp	EatingWhite

NotUseAll:
Unrecognized:	mov	dx,offset BadOption	; don't install
		 jmp	InitFail


EndOfLine:	; The parsing is done!  We will now check to see if the
		; requested size is bigger than the available memory.

PrintChar 'e'
		mov	ax,[RqdPages]		; is the reqested amount
		cmp	ax,[HowMuch]		;  greater than available?
		mov	dx,offset TooBig	; error msg
		 ja      InitFail		; yes, abort

; Now, we'll try to allocate that many kB.  If the user
; didn't specify a number of kB, the default is 512

PrintChar '4'
		mov	dx,ax
		mov	ah,X_Alloc	; open a new handle of (DX) kB
                call    [EMM_Vector]
		or	ax,ax
		 jz	GenFail

PrintChar '5'
                mov	[R_EMM.SourceHandle],dx ; save the handle for later
                mov     [W_EMM.DestHandle],dx

	; We will now setup the information in the BPB to reflect the
	; status of the RAM drive.  First, we'll store the DiskSize.

		mov	ax,[RqdPages]		; get number of pages
		shl	ax,1                    ; 2 sectors in one KB
;                add     ax,7
;                and     ax, NOT 7               ; Should be divisible by 8!
		mov	[DiskSize],ax		; store it in BPB

	; Now, we'll figure out how many entries there will be in the
	; root directory.  We will allow 1 root directory entry for
	; each 2k of storage that the disk has.  We won't allow more
	; than 512 root dir entries, though.

	ifdef	V286
		shr	ax,2
	else
		shr	ax,1			; figure out length of
		shr	ax,1			; root directory
	endif
		cmp	ax,512			;  1 entry per 2k of storage
		 jb	BigBust			;  up to 512

		mov	ax,512

BigBust:	add	ax,31			; make sure it's a multiple
		and	ax,not 31		; of 32  (round it up)
		mov	[RDirLen],ax

	; Since we use a 12-bit FAT, we must have 4087 clusters or less.
	; We will start with a 1024-byte cluster, and double the cluster
	; size until we have enough FAT space. A user must
	; configure about 3.75 megabytes of memory as a RAM drive to
	; cause the program to use 2048-byte clusters... otherwise, the
	; drive will have 1024-byte clusters.

		mov	cx,2			; Two clusters per sector
						;  for starters.

ReTry:		mov	ax,[DiskSize]		; get the disk size
		xor	dx,dx
		div	cx			; AX = (DiskSize/SPC)
		cmp	ax,4087			; is it less than 4087?
		 jb	GoodCombo		;  yeah!
		shl	cx,1			; no. double the SPC and
		 jnc	ReTry			; try it again
                 jmp    GenFail                 ; 64kB cluster is an error!

GoodCombo:	mov	[SecPerCluster],cl	; save SPC number

PrintChar '6'

	; AX still is set to the number of clusters on the disk.  Very
	; useful number, you know.  We will find now the amount of FAT
	; space that is needed.

		mov	bx,ax		; ax = clustsers
		add	ax,ax		; ax = 2*(clusters)
		add	ax,bx		; ax = 3*(clusetrs)

                inc     ax              ; In case of odd # of clusters  TMA

		shr	ax,1		; ax = 1.5*(clusters)

                add     ax,511          ; To round up                   TMA

		xor	dx,dx		;	  (FAT Length)
		mov	cx,512		; AX =	----------------
		div	cx		;       (BytesPerSector)

                mov	[SecPerFAT],ax	; store it in the BPB

	; The BPB is now set up properly.  We will now "format" the
	; RAM disk.  First, we will have to set all the RAM area to
	; zero.  (Even on extremely large "drives", this doesn't take
	; very long.)

                mov     di, OFFSET InitBuffer   ; Make a block of ZERO's
                push    cs
                pop     es
                mov     cx, 512
                xor     ax,ax
                rep     stosw

		mov	cx,[DiskSize]	; get number of sectors on disk
                shr     cx,1            ; CX = # of KB
                mov     si, OFFSET W_EMM; Use W_EMM for all writing

;                mov     [si.DestOffset+1],0    ; Init to 0
                mov     [si.NrOfBytes],1024
                mov     [si.SourceOffset], OFFSET InitBuffer
                mov     [si.SourceOffset+2], CS

WipeOut:
                mov     ah, X_Move
                call    [EMM_Vector]
                or      ax,ax
		 jz	GenFail

        	add     [si.DestOffset+1],4     ; 4 * 256 = 1024 = 1 kB
		 loop	WipeOut		; if more, go back

PrintChar '7'

	; Now that everything is zeroed, we will copy the pseudo-boot
	; sector that we have.  DOS uses some of this information while
	; reading and writing the disk, so we set it up there.

                mov     [si.DestOffset+1],0    ; Init to 0
                mov     [si.NrOfBytes], (OurBootLen + 1) AND 0FFFEh
                mov     [si.SourceOffset], OFFSET OurBoot

                mov     ah,X_Move
		call	[EMM_Vector]
                or      ax,ax
                 jz     GenFail

PrintChar '8'

	; The boot sector has been written in.  We will now set up
	; the FAT.  This task is rather simplified, since we only
	; have one copy of the FAT.

		mov	byte ptr [InitBuffer],MediaD
		mov	word ptr [InitBuffer+1],0FFFFh

                mov     [si.DestOffset+1],2     ; 2 * 256 = 1 sector
                mov     [si.NrOfBytes], 4
                mov     [si.SourceOffset], OFFSET InitBuffer

                mov     ah,X_Move
		call	[EMM_Vector]
                or      ax,ax
                 jz     GenFail

PrintChar '9'

	; Now, we will figure out where the first directory sector is.
	; *WARNING* - This code assumes that there is only one copy of
	; the FAT, and that there is one reserved sector.  If ya change
	; the drive to have 2 copies of the FAT, or modify it to have
	; reserved sectors (for whatever reason you'd wanna do that),
	; you'll have to change this code fragment!

		mov	ax,[SecPerFAT]
		inc	ax		; AX = first dir sector
                shl     ax,1            ; * 2 for 256 byte blocks
                mov     [si.DestOffset+1],ax
                mov     [si.NrOfBytes], (OurVolumeLen + 1) AND 0FFFEh
                mov     [si.SourceOffset], OFFSET OurVolume

                mov     ah,X_Move
		call	[EMM_Vector]
                or      ax,ax
                 jz     GenFail

; Initialize W_EMM.NrOfBytes back to Zero

                mov     [si.NrOfBytes],0
PrintChar '!'

	; Phew!  Now the whole thing is done!  We will show the user
	; what has been done.  First, we will figure out what device
	; tag that we have.  We will tell the user about it.  DOS versions
	; earlier than 3.00 don't let us know what our device tag is,
	; so we can't tell the user.

; TMA:  First, check if not clicking, if so disable that part:

                cmp     SpeakerFlag, 0		; is there clicking?
		 jne	UsingClick

                mov     al, [NearRet]
                mov     byte ptr [MakeClick], al ; RETN opcode    TMA
                mov     [ReadClick], al
                mov     [WriteClick], al

                mov     [LastResident], offset MakeClick + 1  ; Reduce RAM TMA

UsingClick:	
		les	bx,[RBPoint]	; point to the header, again
		mov	al,[rq.taglet]	; get the tag letter
		add	al,'A'		; change it to a capital drive letter.
		mov	[DriveName],al

		mov	bx,[LastResident] ; calculate used size
		xor	ax,ax
		mov	si,offset UsedSpace
		call	Bin2Dec			; store it in the messgae

		mov	ah,X_Counts		; find amount of space left
                call    [EMM_Vector]
		or	bl,bl
		 jl	GenFail

PrintChar '"'
                mov     cl,6        ; AX:BX = (Space left SHL 16) SHR 6 = KB
                xor     bx,bx           ; Zero low word
@@1:
                shr     ax,1
                rcr     bx,1
                 loop   @@1

		mov	si,offset Installed2
		call	Bin2Dec		; put it into the message!

		mov	bx,[DiskSize]	; get sectors of disk space
		sub	bx,[SecPerFAT]	; subtract space used by the FAT

		mov	ax,[RDirLen]	; get the entries in the root dir
	ifdef V286
		shr	ax,4
	else
		mov	cl,4
		shr	ax,cl		; divide by # of entries per sec
	endif
		sub	bx,ax		; subtract some more
		dec	bx		; and adjust down for boot sector

		mov	cx,9		; multiply the answer by 512
		xor	ax,ax		; zero the high side
CalcDiskFree:	shl	bx,1		; shift low side up
		rcl	ax,1		;  shift high side over, with carry
		 loop	CalcDiskFree

		mov	si,offset Installed
		call	Bin2Dec		; store it in the message

		cmp     [SpeakerFlag], 0  ; is there clicking?
		 jne	ClickOkay

		mov	ah,PrintString
		mov	dx,offset NoClicking	; tell the user that it's
		int	21h			; been disabled.

ClickOkay:
		cmp	[MajorVersion],3	; is it version three+?
		 jae	MsgOkay

		mov	[DriveName],eos   ; TMA Ver 2.x, so no drive letter
	
MsgOkay:	mov	dx,offset Installed	;print part one of 
		mov	ah,PrintString		;  installed! message
		int	21h

		mov	dx,offset InstalledB	;print part two
		int	21h

		les	bx,[RBPoint]		; get that pesky pointer

		mov	ax, [LastResident] 	; show DOS where we end  TMA
		mov	[rq.ndadro],ax		;   offset
		                		; show DOS were we end
		mov	[rq.ndadrs],cs		;   segment
		mov	[rq.bpbseg],cs		; show DOS the BPB array

		mov	[rq.units],1		; we installed one unit
		mov	[rq.bpboff],OFFSET BPBArray ; BPB array offset

                mov     [JumpTable], OFFSET BadInit ; In case second INIT call

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

		mov	[rq.ndadrs],ax	; ending address is zero

		xor	ax,ax		;  because no memory is taken
		mov	[rq.ndadro],ax	;  since we failed
		mov	[rq.units],al	; no units, either
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
RqdPages	dw	512		; amount of pages requested
					;	(512k is the default)
MajorVersion	db	3		; the DOS major version number

MTIME   MACRO h,m,s
        dw  (h SHL 11) + (m SHL 5) + (s SHR 1)
        ENDM

MDATE   MACRO y,m,d
        dw  ((y-80) SHL 9) + (m SHL 5) + d
        ENDM

OurVolume	db	'Terjes_Disk'	; 11-byte volume name
		db	000001000b	;  volume label attribute
		db	10 dup (0)	; reserved space
			;FEDCBA9876543210b
; File Time & Date
		MTIME 23 08 40          ; 23:08:40
		MDATE 90 09 30          ; 90-09-30
		db	6 dup (0)	; more reserved space

OurVolumeLen	equ	$ - OFFSET OurVolume

; ---------------------------------------------------------------------------
;  Messages

;  These are messages that are used by the initialization section of the
;  driver.

Banner	label byte
  db cr,lf
  db 'NJ/TMa Ram Disk (C) 1987 by Mike Blaszczak',cr,lf
  ifdef V286
    ifdef PCL
      db "PC's Limited "
    else
      db '286 '
    endif
  endif
  db 'XMS Version 1.02 (C) Terje Mathisen ',??time,' ',??date,cr,lf

  db  cr,lf,eos

General		db	'Device not installed.',cr,lf,eos

NoEMMThere	db	'The XMS driver is not installed.',cr,lf,lf,eos

EMMError	db	'XMS failure during installation.',cr,lf,lf,eos

NoMem		db	'No free XMS Memory.',cr,lf,lf,eos

TooBig		db	'Requested size too big to fit.',cr,lf,lf,eos

TooSmall	db	"Can't have disk size < 16kB.",cr,lf,lf,eos

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
Installed2	db	'         bytes left in XMS storage.',cr,lf
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

InitBuffer      label byte              ; Use 1kB from here for init

driver		ends
		end

; That's a wrap.
; Special thanks to Bob Brody and Dr File Finder

