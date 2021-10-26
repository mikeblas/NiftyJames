	page	60,150
	title	NJMOVE - Nifty James' MOVE Utility
	subttl	(C) 1989 Blaszczak

;
; Nifty James' Famous Move Utility
; Version 1.00 of 16 January 1989
; (C) Copyright 1989 By Mike Blaszczak
;

;
; This file is written for the Microsoft Macro Assembler,
; Version 5.10 or higher.  The program will not properly
; operate under any DOS version less than 2.00, but will
; work with any PC-DOS or MS-DOS Versions 2.00 and above.
; This is an .EXE file, and should not be run through
; EXE2BIN.  The executable file should be packed, or the
; LINK option /EXEPACK should be used.
;


; ----------------------------------------------------------------------------
;	ASCII Equates

eos	equ	000h		; end-of-string character
bell	equ	007h		; bell beeper
bs	equ	008h		; back-space
tab	equ	009h		; tab
lf	equ	00Ah		; line-feed character
cr	equ	00Dh		; carriage return
ctrlz	equ	01Ah		; control zee (aka, EOF)
eof	equ	ctrlz
space	equ	020h		; blank space


; ----------------------------------------------------------------------------
;	DOS Function Calls and constants

INTDOS	equ	021h

STDIN	equ	0		; standard output file handle
STDOUT	equ	1		; standard input file handle

NormalAttrib	equ	000h		; normal attribute byte (nothing set)
SubDirAttrib	equ	010h		; attribute for a directory

PutChar	equ	002h		; put character to stdout
GetChar	equ	007h		; get char from stdin, with no echo
GetDefDisk	equ	019h		; get current default disk drive
SetDTA	equ	01Ah		; set the DOS DTA address
FreeSpace	equ	036h		; get disk free space
CreateHandle	equ	03Ch		; create a file handle
OpenHandle	equ	03Dh		; open a file handle
CloseHandle	equ	03Eh		; close a file handle
ReadHandle	equ	03Fh		; read from a file or device
WriteHandle	equ	040h		; write to a file or device
DeleteFile	equ	041h		; delete a file name
GetAttrib	equ	04300h		; get file attributes
SetAttrib	equ	04301h		; set file attributes
IOCTL	equ	044h		; I/O control/status call
GetDefDir	equ	047h		; get current default directory
Terminate	equ	04Ch		; terminate this program
FindFirst	equ	04Eh		; find first file matching wildcard
FindNext	equ	04Fh		; find next file matching wildcard
RenameFile	equ	056h		; rename a file
GetDateTime	equ	05700h		; get date or time
SetDateTime	equ	05701h		; set date or time
NormalizePath	equ	060h		; normalize pathname
GetPSP	equ	062h		; get the programs PSP

; note that NormalizePath is an undocumented call.  DS:SI points to a
; path specification which may contain a drive specifier.  ES:DI points
; to a buffer for the normalized pathname.  The file simply fixes the
; "." and ".." references in the file, making the pathname as short as
; possible.  This expansion is simply used so the user knows *exactly*
; where the file is coming from.  Microsoft, in their infinite (heh)
; wisdom (hah) did not document this very useful function call.


; ----------------------------------------------------------------------------
;	ERRORLEVEL values that we return

ERR_None	equ	0		; none!
ERR_Usage	equ	1		; problem on command line
ERR_NotFound	equ	2		; file not found
ERR_BadFile	equ	3		; given a device, or an unparsable
ERR_CopyProblem	equ	4		; problem while copying
ERR_Renaming	equ	5		; problem while renaming


; These are the data structures used in this program.  The first is used
; internally to describe the way a file name is broken down into its
; components.

FileDriveLen	equ	3
FilePathLen	equ	65
FileNameLen	equ	9
FileExtLen	equ	5

FileNameS	struc
drive	db	FileDriveLen dup(?)	; drive		B:
path	db    	FilePathLen  dup(?)	; path		\bin\booger
fname	db	FileNameLen  dup(?)	; filename	njmove
fext	db	FileExtLen   dup(?)	; extension	asm
FileNameS	ends


; This data structure is the one that DOS uses to store the DTA.  When
; we call FINDFIRST and FINDNEXT, this information will be set up to contain
; the rest of the file that we are moving.

DOSDTAS	struc
_dta_reserved	db	21 dup (?)	; reserved space
dta_attribute	db	?		; attribute byte
dta_time	dw	?		; file modification time
dta_date	dw	?		; file modification date
dta_size	dd	?		; file size (doubleword!)
dta_fname	db	13 dup (?)	; file name (ASCIIZ)
DOSDTAS	ends


; ============================================================================
	.model	small
	.stack	0100h		; get a *real* stack


; ============================================================================
; Our data area follows.  This data area contains both initialized and
; uninitialized data.						    

	.data

Banner	db	"Nifty James' Famous Move Utility",cr,lf
	db	"Version 1.00 of 16 January 1989",cr,lf
	db	"(C)Copyright 1989 by Mike Blaszczak",cr,lf
	db	lf,eos

NoSpace	db	"NJMOVE: Destination device ran out of space"
CRLFSet	db	cr,lf,eos

NoSelf	db	"NJMOVE: A File can not be moved into itself"
	db	cr,lf,eos

CantWrite	db	"NJMOVE: Couldn't write to destination device"
	db	cr,lf,eos

CantRead	db	"NJMOVE: Couldn't read from source device"
	db	cr,lf,eos

CantSDevice	db	"NJMOVE: Can't move from a device"
	db	cr,lf,eos

CantDDevice	db	"NJMOVE: Can't move to a device"
	db	cr,lf,eos

BadSource	db	"NJMOVE: Bad Source File Specification"
	db	cr,lf,eos

BadDest	db	"NJMOVE: Bad Destination File Specification"
	db	cr,lf,eos

CouldntRename	db	"NJMOVE: Could not perform rename operation"
	db	cr,lf,eos

NameCollide	db	"NJMOVE: File naming collision; file already exists"
	db	cr,lf,eos

CouldntDIR	db	"NJMOVE: Couldn't get default directory of drive "
	db	eos

NoMatches	db	"NJMOVE: No files matched ",eos

UAborted	db	cr,lf,"NJMOVE: User Aborted",cr,lf,lf,eos

Usage	db	"Usage:",cr,lf
	db	tab,"NJMOVE <source> <dest> [/C]",cr,lf
	db	lf
	db	tab,"<source>",tab,"source file name",cr,lf
	db	tab,"<dest>",tab,tab,"destination file name",cr,lf
	db	tab,tab," both file names may "
	db	"contain wildcards",cr,lf
	db	tab,"[/C]",tab,"specifies optional confirmation"
	db	cr,lf,lf,eos

MovingMess	db	"Moving ",eos
MoveCMess	db	"Move ",eos

CopyingMess	db	"Copying ",eos
CopyCMess	db	"Copy ",eos

ToMess	db	" to ",eos

BackSlash	db	"\",eos

DotStar	db	"."
Star	db	"*",eos

ConfirmPrompt	db	"? [No] ",eos


confirmmode	db	0		; set if the /C was to be found
copymode	db	0		; set to one if we must copy
				;  from disk to disk instead of
				;  just renaming the files
	even

sourcespec	dw	0		; source file specification
destspec	dw	0		; destination spec

sourcewildf	db	0		; set if sourcef has wildcard name
sourcewilde	db	0		; set if sourcef has wildcard ext
sourcehase	db	0		; set if sourcef has extension
sourcef	FileNameS <>		; source description
sourcefile	db	64 dup (0)	; total file name

destwildf	db	0		; set if destf has wildcard name
destwilde	db	0		; set if destf has wildcard ext
desthase	db	0		; set if destf has extension
destf	FileNameS <>		; destination description
destfile	db	64 dup (0)	; total file name

mydta	DOSDTAS <>		; a place for DOS to store its stuff
				; during FINDFIRST + FINDNEXT

; These variables are used by the copyfile procedure

sourceh	dw	?		; handle for source file
desth	dw	?		; destination file handle

; ----------------------------------------------------------------------------
; These areas are all data buffers that are not initialized, generally.

	even

argvectors	dw	64 dup (0)	; pointers to each argumnet
argcount	dw	0		; count of arguments
argbuff	db	128 dup (0)	; buffer to hold args for DS access

CopyBufferLen	equ	16384
copybuffer	db	CopyBufferLen dup (?)
				; this buffer is used while copying

temppath	db	FilePathLen dup(?)
				; area used by check4path and
				; normalizepath

fixedpath	db	FilePathLen dup(?)
				; area used by normalize path, too.

; This area is used by the confirm procedure

confirmreply	db	?


; ============================================================================
; This is the program code.  The execution of the program starts at the
; very first instruction here.

	.code

	; first, put the banner of our program on the screen

	mov	ax,@data
	mov	ds,ax
	mov	si,offset Banner
	call	putstr

	; set the DTA to point to our area

	mov	ah,SetDTA
	mov	dx,offset mydta
	int	INTDOS

	; then, parse the command line

	call	parseline

	; convert all of the arguments to upper case

	mov	ax,@data
	mov	ds,ax

	mov	di,offset argvectors

arguploop:	mov	si,[di]		; get the next arg
	add	di,2

	and	si,si		; is it 0000?
	je	doneargup

	call	strupr
	jmp	short arguploop

doneargup:
	; then, find the source file and dest file (maybe),
	; and check for options, too


	mov	di,offset argvectors
checkargsloop:
	mov	si,[di]		; get the next arg
	add	di,2

	and	si,si		; end of list?
	je	donecheckargs

	mov	al,[si]		; nope!	 check it
	cmp	al,'/'
	je	gotoption
	cmp	al,'-'
	jne	notoption

gotoption:	inc	si		; get the next character of option
	mov	al,[si]
	cmp	al,'C'		; confirm?
	jne	showusage	; nope! error!

	mov	al,1
	mov	confirmmode,al	; confirmation mode
	jmp	short checkargsloop

notoption:	mov	ax,sourcespec	; do we have a source file?
	and	ax,ax
	jne	gotsource

	mov	sourcespec,si	; nope!  this is our new source spec
	jmp	short checkargsloop

gotsource:	mov	ax,destspec	; how about a dest?
	and	ax,ax
	jne	showusage

	mov	destspec,si	; nope!  this is the dest spec
	jmp	short checkargsloop

	; now, see if we have enough arugments
donecheckargs:
	mov	ax,argcount	; did we get any args?
	and	ax,ax
	jne	noshowusage	; if not, we must

showusage:
	mov	si,offset Usage	; display the usage
	call	putstr
	mov	ah,Terminate	; and then
	mov	al,ERR_Usage	; terminate with error status
	call	exit

noshowusage:
	cmp	ax,1
	ja	gotdest		; was there a destination filespec?

nogotdest:
	mov	si,offset Star	; nope. asume dest filespec was
	mov	di,offset destf.fname	; *.*
	call	strcpy
	mov	si,offset DotStar
	mov	di,offset destf.fext
	call	strcpy
	jmp	short destsetup

gotdest:	; yes!  call splitfilename to handle
	mov	si,destspec	; the parse of the filename
	mov	di,offset destf	; into the destf area
	call	splitfilename

destsetup:
	; before we goof with anything, see if the
	; destination has a file extension

	mov	si,offset destf.fext
	call	strlen
	and	cx,cx		; something there?
	je	destno

	mov	al,1
	mov	desthase,al	; yes! flag it!


destno:	mov	si,offset destf.drive
	call	strlen		; was there a drive name given?
	and	cx,cx
	jne	gotdestdrive

	mov	ah,GetDefDisk		; nope-get default from DOS
	int	INTDOS
	add	al,'A'			; make it ASCII
	mov	[si],al
	inc	si			; store it
	mov	byte ptr [si],':'	; add a colon
	inc	si
	mov	byte ptr [si],eos	; and a zilcher

gotdestdrive:
	mov	si,offset destf.path
	call	strlen		; was there a file path?
	and	cx,cx
	jne	gotdestpath

	; put the default file path into the destf area
	; first, put a backslash in there

	mov	di,offset destf.path
	mov	si,offset BackSlash
	call	strcpy

	; then ask DOS to put the default path into the
	; copybuffer area

	mov	si,offset copybuffer
	mov	ah,GetDefDir
	mov	dl,[destf.drive]	; whats the drive?
	sub	dl,('A'-1)
	int	INTDOS
	jnc	nodestdirproblem

	call	newline			; print error message
	mov	si,offset CouldntDIR
	call	putstr
	add	dl,('A'-1)		; for that drive
	mov	ah,PutChar
	int	INTDOS
	call	newline
	mov	al,ERR_BadFile
	call	exit
	
nodestdirproblem:	; now, concatenate it together.  we will end up with
	; \path\place

	mov	si,offset copybuffer
	mov	di,offset destf.path
	call	strcat

	; if the path is not just \, add a trailing \ to it
	
	mov	si,offset copybuffer
	call	strlen
	cmp	cx,1
	jb	gotdestpath

	mov	di,offset destf.path
	mov	si,offset BackSlash
	call	strcat

gotdestpath:
	; now, we'll see if the filename is there

	mov	si,offset destf.fname
	call	strlen
	mov	bx,cx

	mov	si,offset destf.fext
	call	strlen		; now, cx = strlen(fext)
				;   and bx = strlen(fname)

	and	cx,cx		; is cx zero?
	je	destnoproblem
	
	and	bx,bx
	jne	destnoproblem

	; we've found that there is no filename but there is an extension.
	; that's not too good.

	mov	si,offset BadDest
	call	putstr
	mov	al,ERR_BadFile
	call	exit

destnoproblem:
	and	bx,bx		; does filename exist?
	jne	desthasfn

	mov	si,offset Star	; nope ... copy a star there
	mov	di,offset destf.fname
	call	strcpy

desthasfn:
	and	cx,cx		; okay, does the extension exist
	jne	destfixed

	mov	si,offset DotStar; nope, copy ".*" into it
	mov	di,offset destf.fext
	call	strcpy

destfixed:
	; now, check to see if there's a wildcard in the filename
	mov	si,offset destf.fname
	mov	ah,'?'
	call	strchr
	and	ax,ax		; is it?
	jne	desthaswildf

	mov	si,offset destf.fname
	mov	ah,'*'		; how about a star?
	call	strchr
	and	ax,ax
	je	destnowildf

desthaswildf:
	mov	al,1
	mov	destwildf,al	; set the flag

destnowildf:
	; see if the destination extension has a wildcard
	mov	si,offset destf.fext
	mov	ah,'?'
	call	strchr
	and	ax,ax		; is it?
	jne	desthaswilde

	mov	si,offset destf.fext
	mov	ah,'*'
	call	strchr
	and	ax,ax
	je	destdone

desthaswilde:
	mov	al,1
	mov	destwilde,al

destdone:	; normalize the path for the destf

	mov	si,offset destf
	call	normpath

	; does the filename have a wildcard?

	mov	al,destwildf
	and	al,al
	jne	destcompleted

	; does it have an extension?

	mov	al,desthase
	and	al,al
	jne	destcompleted

	; if not, check to see if the filename is a directory

	mov	si,offset destf
	call	check4dir
	and	ax,ax		; did it work?
	je	destcompleted

	mov	destwilde,al	; yes! extension and filename
	mov	destwildf,al	; are wildcards now
	
destcompleted:	; the destination file is all set up!
	; now, we can parse the source file name

	mov	si,sourcespec
	mov	di,offset sourcef
	call	splitfilename

	; before we touch anything, see if we were given
	; a file extension

	mov	si,offset sourcef.fext
	call	strlen
	and	cx,cx		; anything there?
	je	sourceno

	mov	al,1
	mov	sourcehase,al	; yes! flag it


sourceno:	; check 'n' see if there is a drive there

	mov	si,offset sourcef.drive
	call	strlen
	and	cx,cx
	jne	gotsourcedrive

	mov	ah,GetDefDisk		; nope-get default from DOS
	int	INTDOS
	add	al,'A'
	mov	[si],al
	inc	si
	mov	byte ptr [si],':'	; and store a colon after it
	inc	si
	mov	byte ptr [si],eos	; and a zilcher around it

gotsourcedrive:
	mov	si,offset sourcef.path
	call	strlen		; was there a file path?
	and	cx,cx
	jne	gotsourcepath

	; put the default file path into the sourcef area
	; first, put a backslash in there

	mov	si,offset BackSlash
	mov	di,offset sourcef.path
	call	strcpy

	; then ask DOS to put the default path into the
	; copy buffer area

	mov	si,offset copybuffer
	mov	ah,GetDefDir
	mov	dl,[sourcef.drive]	; whats the drive?
	sub	dl,('A'-1)	; make into A=1, B=2 ... for DOS
	int	INTDOS
	jnc	nosourcedirprob

	call	newline			; print error message
	mov	si,offset CouldntDIR
	call	putstr
	add	dl,('A'-1)		; for that drive
	mov	ah,PutChar
	int	INTDOS
	call	newline
	mov	al,ERR_BadFile
	call	exit

nosourcedirprob:	; now, concatenate it togethre

	mov	si,offset copybuffer
	mov	di,offset sourcef.path
	call	strcat

	; if the path is not just \, add a trailing \ to it
	mov	si,offset copybuffer
	call	strlen
	cmp	cx,1
	jb	gotsourcepath

	mov	di,offset sourcef.path
	mov	si,offset BackSlash
	call	strcat

gotsourcepath:
	; make sure there's a filename, even if its a wildcard.
	; check that it was a valid filename, too.

	mov	si,offset sourcef.fname
	call	strlen
	mov	bx,cx

	mov	si,offset sourcef.fext
	call	strlen		; now, cx = strlen(fext)
				;	and bx = strlen(fname)

	and	cx,cx
	je	sourcenoproblem

	and	bx,bx
	jne	sourcenoproblem

	; we've found that there is no filename but there is an extension
	; that's not good

	mov	si,offset BadSource
	call	putstr
	mov	al,ERR_BadFile
	call	exit

sourcenoproblem:
	and	bx,bx		; does filename exist?
	jne	sourcehasf

	mov	si,offset Star	; nope ... copy a astar in there
	mov	di,offset sourcef.fname
	call	strcpy

sourcehasf:
	and	cx,cx		; does extension exist?
	jne	sourcedone
	mov	si,offset DotStar
	mov	di,offset sourcef.fext
	call	strcpy

	; now, check to see if there's a wildcard in the filename
	mov	si,offset sourcef.fname
	mov	ah,'?'
	call	strchr
	and	ax,ax		; is it?
	jne	sourcehaswildf

	mov	si,offset sourcef.fname
	mov	ah,'*'		; how about a star?
	call	strchr
	and	ax,ax
	je	sourcenowildf

sourcehaswildf:
	mov	al,1
	mov	sourcewildf,al	; set the flag

sourcenowildf:
	; see if the sourceination extension has a wildcard
	mov	si,offset sourcef.fext
	mov	ah,'?'
	call	strchr
	and	ax,ax		; is it?
	jne	sourcehaswilde

	mov	si,offset sourcef.fext
	mov	ah,'*'
	call	strchr
	and	ax,ax
	je	sourcedone

sourcehaswilde:
	mov	al,1
	mov	sourcewilde,al

sourcedone:	; last, normalize the source file path

	mov	si,offset sourcef
	call	normpath

	mov	al,sourcewildf
	and	al,al
	jne	sourcecompleted

	mov	al,sourcehase
	and	al,al
	jne	sourcecompleted

	mov	si,offset sourcef
	call	check4dir
	and	ax,ax		; did it work?
	je	sourcecompleted

	mov	sourcewildf,al	; yes! filename and
	mov	sourcewilde,al	; extension are now wildcards!


sourcecompleted:	; filenames are all set!
	; okay, almost there!  check to see if the drives
	; are the same.  if they are, we're renaming.  if
	; they're not, we're copying and deleting.

	mov	si,offset sourcef.drive
	mov	al,[si]
	mov	si,offset destf.drive
	cmp	al,[si]
	je	workhorse

	mov	al,1		; set copying flag
	mov	copymode,al

	; right! everything is ready.  we'll make the source
	; file name into something meaningful

workhorse:	mov	si,offset sourcef
	mov	di,offset sourcefile
	call	makefilename

	; just for kicks, we'll try to open that file.

	mov	ah,OpenHandle
	mov	al,0
	mov	dx,offset sourcefile
	int	INTDOS

	jc	dothefindfirst

	mov	bx,ax
	mov	ah,IOCTL
	mov	al,0		; see if it is a device
	int	INTDOS

	and	dx,0080h	; check ISDEV bit
	je	notdevice

deviceblowout:	mov	si,offset CantSDevice
	call	putstr
	mov	ax,ERR_BadFile
	call	exit


notdevice:	mov	ah,CloseHandle
	int	INTDOS


	; we'll try to find the first matching file

dothefindfirst:	mov	ah,FindFirst
	mov	dx,offset sourcefile
	xor	cx,cx
	int	INTDOS

	jnc	foundone

notfound:	mov	si,offset NoMatches
	call	putstr
	mov	si,offset sourcefile
	call	putstr
	call	newline
	mov	ax,ERR_NotFound
	call	exit

	; this loop is the main thing.  we've called findfirst,
	; and the dta block is set up with the file we found.
	; we'll figure out the destination file name, and
	; then move or copy the file.

	; at the bottom of the loop, we'll call findnext and
	; see if there are more matching files.  if its there,
	; we can loop back here and process that next file.

foundone:	mov	si,offset mydta
	mov	di,offset sourcef
	call	popfound
	mov	si,offset sourcef
	mov	di,offset sourcefile
	call	makefilename

	; if the source filename has a wildcard *and* the
	; dest filename has a wild card, copy source filename
	; into the destination filename

	mov	al,destwildf
	and	al,al
	je	notwildf

	mov	si,offset sourcef.fname
	mov	di,offset destf.fname
	call	strcpy


notwildf:	; if the source file extension has a wildcard,	and
	; the destination extension has a wildcard, copy
	; the source extension into the destination extension

	mov	al,destwilde
	and	al,al
	je	notwilde

	mov	si,offset sourcef.fext
	mov	di,offset destf.fext
	call	strcpy


notwilde:	; create the destination file into an ASCIIZ string

	mov	si,offset destf
	mov	di,offset destfile
	call	makefilename

	; print a message for what we are going to do

	mov	al,copymode
	mov	ah,confirmmode

	and	al,al
	je	wearemoving

	mov	si,offset CopyingMess	; we're copying

	and	ah,ah
	je	printsource		; without confirmation

	mov	si,offset CopyCMess
	jne	printsource

wearemoving:	mov	si,offset MovingMess	; we're moving
	and	ah,ah
	je	printsource		; without confirmation?

	mov	si,offset MoveCMess


printsource:	call	putstr

	; either
	;   "Moving sourcefile to destfile"
	; or
	;   "Copying sourcefile to destfile"

	mov	si,offset sourcefile
	call	putstr

whereto:	; print " to "

	mov	si,offset ToMess
	call	putstr

	mov	si,offset destfile
	call	putstr


	; before we actually do it, call confirmation, if need be

	and	ah,ah
	jne	askfirst	; no confirmation

	call	newline
	jmp	short goahead

askfirst:	call	getyesno	; do confirmation
	call	newline

	cmp	ax,0		; no?
	je	loopbottom	; skip it, then

	cmp	ax,1		; yes?
	je	goahead		; go right ahead

	xor	ax,ax		; all of them!
	mov	confirmmode,al	; (forget about confirming)

	; actually do it

goahead:	mov	al,copymode
	and	al,al
	jne	doacopy

doamove:
	mov	dx,offset sourcefile
	mov	di,offset destfile
	mov	ah,RenameFile
	int	INTDOS
	jnc	loopbottom

	; decide which error happened.  AX=0005 is bad name,
	; anything else is different.

	mov	bx,ax
	mov	al,ERR_Renaming
	
	mov	si,offset NameCollide
	cmp	bx,5
	je	renamingcollision

	mov	si,offset CouldntRename

renamingcollision:	call	newline
	call	putstr
	mov	ah,ERR_Renaming
	call	exit

doacopy:	call	copyfile

loopbottom:	mov	ah,FindNext
	int	INTDOS
	jc	cleanexit	; relative jnc out of range
	jmp	foundone


	
	
cleanexit:
	mov	al,ERR_None	; return with no error
	call	exit



; ============================================================================
; These subroutines are used by the programs' main routine


; ----------------------------------------------------------------------------
; exit
; On entry, AL contains the error level that the program should return.
;
; This routine will terminate to DOS.  It does no housekeeping functions.

exit	proc	near

	mov	ah,Terminate	; make a Terminate call
	int	INTDOS

exit	endp


; ----------------------------------------------------------------------------
; strlen
; On entry, DS:SI points to a string.
;
; On return, CX will contain the length of the string.

strlen	proc	near

	push	ax
	push	si

	xor	cx,cx		; zero the length count

sl_c:	mov	al,[si]		; get a character
	inc	si
	inc	cx		; increment pointer and count
	and	al,al		; is it end of string?
	jne	sl_c		;  loop back if it isn't

	dec	cx		; adjust the count down

	pop	si
	pop	ax
	ret

strlen	endp



; ----------------------------------------------------------------------------
; newline
; This routine prints a carriage return and a linefeed.  We will destroy
; no registers.


newline	proc	near

	push	si
	push	ds		; save the DS:SI
	push	ax

	mov	ax,@data
	mov	ds,ax
	mov	si,offset CRLFSet
	call	putstr

	pop	ax		; restore the registers
	pop	ds
	pop	si
	ret

newline	endp


; ----------------------------------------------------------------------------
; putstr
; On entry, DS:SI points to a string.
;
; This routine prints the passed string to STDOUT, and does nothing else.
; The string is not altered in any way.

putstr	proc	near

	push	dx
	push	cx
	push	bx
	push	ax		; save the regs we use
	push	si

	xor	cx,cx		; zero the length count

ps_l:	mov	al,[si]		; get a character
	inc	si
	inc	cx		; increment pointer and count
	and	al,al		; is it end of string?
	jne	ps_l		;  loop back if it isn't

	dec	cx		; adjust the count down

	mov	ah,WriteHandle	; ask DOS to write to the stdout
	mov	bx,STDOUT
	
	pop	si		; restore the SI
	mov	dx,si		; and put it into dx for DOS
	int	INTDOS

	pop	ax
	pop	bx
	pop	cx
	pop	dx
	ret

putstr	endp


; ----------------------------------------------------------------------------
; strcat
; On entry, DS:SI points to the concatenant, and ES:DI points to the
; concatenand:
;
;	DS:SI -> "Have Antlers"
;	ES:DI -> "Mooses "
;	call	strcat
;	ES:DI -> "Mooses Have Antlers"


strcat	proc	near

	push	ax
	push	si		; save the registers
	push	di

	; first, find the end

sc_next:	mov	al,es:[di]	; get the char
	inc	di
	and	al,al		; is it zilcher?
	jne	sc_next		; nope ... keep looping

	dec	di		; point to the zilcher

	; now, we can just call strcpy to move the concatenant
	; over the end of the concatenand.

	call	strcpy

	pop	di
	pop	si
	pop	ax

	ret
strcat	endp


; ----------------------------------------------------------------------------
; strcpy
; On entry, DS:SI points to a string and ES:DI points to storage space.
;
; This routine will copy the string from DS:SI to ES:DI.

strcpy	proc	near

	push	di		; save the registers we use
	push	si
	push	ax

sc_nextc:	mov	al,[si]		; get another character
	inc	si
	mov	es:[di],al	; store it
	inc	di

	and	al,al		; if that was the 0 character, quit
	jne	sc_nextc	; else keep working on the string

	pop	ax		; restore the registers we used
	pop	si
	pop	di
	ret
strcpy	endp


; ----------------------------------------------------------------------------
; strchr
; On entry, DS:SI points to a string, and ah contains a character to match.
; The routine will work forward through the string until it finds the end
; of the string or matches the character.  On return, AX will be 0000 if
; there was no match, or DS:AX will point to the character in the string
; if the character wasn't found.

strchr	proc	near

	push	si		; save si

strchrnc:	mov	al,[si]		; get a character
	inc	si		; and increment pointer
	cmp	al,ah		; is it a match?
	je	strchrhit

	and	al,al		; nope.  was it '\0'?
	jne	strchrnc	; if not, go do more

	xor	ax,ax		; yes, the string ended
	je	strchrexit	; so make AX null for failure

strchrhit:	mov	ax,si		; got the character!
	dec	ax		; put pointer into ax

strchrexit:	pop	si		; restore si
	ret			; and go home

strchr	endp


; ----------------------------------------------------------------------------
; strrchr
; On entry, DS:SI points to a string, and ah contains a character to match.
; The routine will step backward, starting at the end of the string, and
; work until it finds a match.  If the program makes it through the whole
; string without finding the character, it will return with AX set to 0000.
; Otherwise, DS:AX points the the last occurrence of the character in the
; string.


strrchr	proc	near

	push	cx		; save the registers we use
	push	si
	xor	cx,cx		; zero cx since we use it to count

strrchrfe:	mov	al,[si]		; get the next character
	inc	si		; increment the pointer
	inc	cx		; increment the count of chars
	and	al,al		; is this the end of the string?
	jne	strrchrfe

	cmp	cx,0		; is the string empty?
	je	strrchrfail	; if so, automatic failure

strrchrloop:	dec	si		; point to the null
	mov	al,[si]		; is that the character?
	cmp	ah,al
	je	strrchrhit	; if so, we've hit!
	dec	cx
	jne	strrchrloop	; if not, loop more

strrchrfail:	xor	ax,ax
	je	strrchrexit	; return AX as 0000

strrchrhit:	mov	ax,si		; got the character! move pointer
				; into ax

strrchrexit:	pop	si
	pop	cx
	ret

strrchr	endp


; ----------------------------------------------------------------------------
; strupr
; On entry, DS:SI points to a string and ES:DI points to storage space.
;
; This routine will convert the entire content of the string to uppercase.
; It won't alter any registers, nor will it change non-alphabetic characters
; in the str.


strupr	proc	near

	cld
	push	ax
	push	si

struprloop:	lodsb			; get the next character
	and	al,al		; is it zilcho?
	je	struprdone

	cmp	al,'a'		; is it less than 'a'?
	jl	struprloop	; yep ... keep looping

	cmp	al,'z'		; is it bigger than 'z'?
	jg	struprloop	; yes; don't modify it

	sub	al,('a' - 'A')
	mov	[si-1],al	; restore that character
	jmp	short struprloop

struprdone:	pop	si
	pop	ax
	ret

strupr	endp


; ----------------------------------------------------------------------------
; parseline
; This routine tries to parse the command line.  It sets up the variables
; in the data segment (argcount and arglist), as well as copying the
; information into a local area in the data segment.  The routine will
; not preserve any of the registers it uses.

parseline	proc	near

	mov	ah,GetPSP	; get the PSP from DOS
	int	INTDOS

	mov	ds,bx		; move the PSP into ds
	mov	si,0081h	; address the command line

	xor	dx,dx
	mov	dl,[si-1]	; get the length of the line
	add	dl,081h

	mov	ax,@data	; now, set up ES to point to our
	mov	es,ax		; own data areas
	mov	di,offset argbuff


nextarg:
eatwhite:
	mov	al,[si]
	inc	si		; get the next character

	cmp	al,space	; is it a space?
	je	eatwhite
	cmp	al,tab		; or a tab?
	je	eatwhite	; yes ... skip over it

	dec	si		; point si at the first non-white
	push	si		; and save a copy of it for later

eatarg:	mov	al,[si]		; get the last character
	inc	si
	cmp	al,space	; is it a whitespace?
	jle	gotarg
	jmp	short eatarg	; nope... keep skipping

gotarg:
	dec	si
	mov	byte ptr [si],0	; make the argument a string

	pop	ax		; get the pointer to this arg

	xchg	ax,si		; put si into DS:SI

	call	strcpy		; store in our data segment

	call	strlen		; get the length of the string
	push	cx		; save it

	xchg	si,ax

	and	cx,cx		; if this string has no length,
	je	added		;  don't add it to the table

	; here, DS:AX points to the end of the string and
	; ES:DI points to the place where the string was stored.
	; DS:SI still points to the beginning of the string.

add2table:	mov	ax,es:argcount
	shl	ax,1		; get offset into array
	add	ax,offset argvectors
	xchg	ax,si
	mov	es:[si],di	; store the offset of this arg
	xchg	si,ax

	inc	es:argcount	; increment the count of args

added:
	; adjust ES:DI

	pop	cx
	add	di,cx		; get the length and fix it in
	inc	di		; make DS:SI point to the next
	inc	si		; free spot

	; see if we are done

	cmp	dx,si
	ja	nextarg

wearedone:
	ret
parseline	endp


; ----------------------------------------------------------------------------
; splitfilename
; this procedure accepts ds:si as a pointer to a full file name.  it also
; expects that es:di points to a FileNameS.  The routine will copy
; information from the full file name into the FileNameS structure.

splitfilename	proc	near

	push	cx
	push	si		; save the regs we use
	push	di

	; to get started, check to see if there's a drivespec

	mov	al,[si+1]	; is there a colon for the
	cmp	al,':'		; second character?
	jne	sfn_nodrive	; nope! don't worry about it

sfn_gotdrive:	mov	es:[di+1].drive,al	; store the colon
	mov	al,[si]			; get the drive letter
	mov	es:[di].drive,al
	add	di,2		; make es:di point after it
	add	si,2		; and make si point after drive


sfn_nodrive:	; since there's no drive spec, just zero the drive.

	xor	ax,ax
	mov	es:[di].drive,al ; stick it


sfn_drivedone:	; now that drive is done, point es:di to the path

	pop	di		; point to the path area
	push	di
	add	di,path

	; see if there was a path in the filename we got

	mov	al,[si]		; get the first char
	cmp	al,'.'
	jne	sfn_notrelpath
	je	sfn_hasrelpath


sfn_notrelpath:	mov	ah,'\'		; the path character
	call	strchr

	and	ax,ax		; is AX == 0000?
	jne	sfn_haspath

sfn_hasrelpath:	mov	ax,si		; yes -- point to the start of
				; the string

sfn_haspath:	; there's a path!  now, try to find the *last*
	; character of the path.

	mov	dx,ax		; save AX for now
	mov	ah,'\'
	call	strrchr		; find the last '\'
	xchg	ax,dx

	and	dx,dx
	jne	sfn_hasend

	; hmph!  there is no '\', either way you look
	; does the path begin with '.'?

	cmp	byte ptr [si],'.'
	jne	sfn_nopath	; nope!  no path name
				; yes!  relative path name!


sfn_relpath:	call	strlen		; if no '\', point to end of
	mov	dx,si		;   string
	add	dx,cx

	cmp	ax,dx		; is our end and start equal?
	je	sfn_nopath	; no path here, mon!

	; now, copy the string from DS:AX to DS:DX into ES:DI.

sfn_hasend:	mov	si,ax		; start with ax
	mov	cx,FilePathLen-2

sfn_movepath:	mov	al,[si]
	inc	si		; get this character
	mov	es:[di],al	; and store it in path
	inc	di

	dec	cx		; decrement max char count.
	jne	sfn_movingpath	; if too many, truncate

	mov	al,'\'
	mov	es:[di],al	; truncate with a backslash
	inc	di
	mov	si,dx		; update the pointer so's it
	inc	si		; points to the filename now
	jmp	short sfn_movedpath

sfn_movingpath:
	cmp	dx,si		; is si>dx?  (work to dx)
	jae	sfn_movepath	; no ... keep looping

sfn_movedpath:
sfn_nopath:	xor	ax,ax		; set up the ax so we can
	mov	es:[di],al	; store a null in .path area

	; now, we have the path done.  mess with moving
	; the file name and the extension. DS:SI already
	; points to the file name.

sfn_pathdone:	pop	di		; make es:di point to filename
	push	di
	add	di,fname

	mov	cx,FileNameLen

sfn_movefn:	mov	al,[si]		; get the next character
	cmp	al,'.'		; end of filename?
	je	sfn_gotext

	dec	cx		; too many characters?
	jne	sfn_moveingfn	; yep!  truncate.

	mov	al,0
	mov	es:[di],al	; terminate the filename
sfn_blowoff:	mov	al,[si]		; skip ahead until we find eos or
	cmp	al,'.'		; a period
	je	sfn_gotext
	inc	si
	and	al,al		; is it a zilcher?
	jne	sfn_blowoff
	je	sfn_movedfn

sfn_moveingfn:
	mov	es:[di],al	; store this character
	inc	si
	inc	di
	and	al,al		; did we just write an eos?
	jne	sfn_movefn

sfn_movedfn:	xor	ax,ax
	pop	di		; make addressing to strucutre
	push	di
	mov	es:[di].fext,al
	jmp	short sfn_exit	; and split this joint

sfn_gotext:	mov	ah,0		; write an end-of-string for
	mov	es:[di],ah	; the filename, first

	mov	cx,FileExtLen

	pop	di
	push	di
	add	di,fext		; make es:di point to filename

sfn_moveext:	mov	es:[di],al	; store the character
	inc	si
	inc	di		; increment the pointers
	and	al,al		; did we just write a '\0'?
	je	sfn_exit

	cmp	cx,0		; is it zero yet?
	jne	snf_movingext

	mov	al,0
	dec	di
	mov	es:[di],al
	jmp	short sfn_exit

snf_movingext:	dec	cx
	mov	al,[si]		; get next character
	jmp	short sfn_moveext

sfn_exit:
	; on the way out, we will check to see if the path
	; name was a relative file.  if so, we will make
	; sure a slash is appended to it.

	pop	di
	push	di
	add	di,path

	mov	al,[di]
	cmp	al,'.'		; not a relative, no problem
	jne	sfn_nofix

	; fix relative path

	mov	si,di
	call	strlen
	add	si,cx
	dec	si		; point to last character
	mov	al,[si]		; get that character
	cmp	al,'\'		; slash?
	je	sfn_nofix	;   no problem

	inc	si		; make it a slash
	mov	byte ptr [si],'\'
	inc	si
	mov	byte ptr [si],eos

sfn_nofix:	; restore the regs we saved
	pop	di
	pop	si
	pop	cx
	ret
splitfilename	endp


; ----------------------------------------------------------------------------
; makefilename
; On entry, DS:SI points to a FileNameS, and ES:DI points to a storage
; buffer for a file name.  The routine will string all of the elements
; of the strucutre together to make a real full file name.

makefilename	proc	near

	push	ax
	push	si
	push	di
	mov	ax,si		; put base pointer into ax

	; first copy the drive specifier

	mov	si,ax
	add	si,drive	; copy the drive
	call	strcpy

	; then concatenate the path

	mov	si,ax
	add	si,path
	call	strcat

	; then concatenate the filename

	mov	si,ax
	add	si,fname
	call	strcat
	
	; now concatenate the extension

	mov	si,ax
	add	si,fext
	call	strcat

	; that's all!

	pop	di
	pop	si	; restore the registers and return home
	pop	ax
	ret
makefilename	endp


; ----------------------------------------------------------------------------
; popfound
; This routine accepts a pointer to a DOSDTAS in DS:DI, and a pointer to
; a FileNameS in ES:DI.  It takes the filename and extension fields from
; the DOSDTAS and puts them into the fname and fext portions of the
; FileNameS structure.

popfound	proc

	push	ax
	push	cx
	push	dx
	push	si	; save the regs we use
	push	di
	
	mov	dx,si		; and make a copy of the parms
	mov	cx,di		; to easily address the structs

	; first, work on moving the filename

	mov	si,dx
	add	si,dta_fname

	mov	di,cx
	add	di,fname

popfoundf:	mov	al,[si]		; get this char
	cmp	al,'.'		; period yet?
	je	popfounde
	mov	es:[di],al	; store it

	and	al,al		; is it a zilcher?	
	jne	popfoundfing

	mov	di,cx		; yep!  zilch out extension too
	add	di,fext
	mov	es:[di],al
	jmp	short popfounddone


popfoundfing:	inc	di
	inc	si
	jmp	short popfoundf	; loop for more

popfounde:	mov	ah,0
	mov	es:[di],ah	; terminate the filename with 0
	mov	di,cx

	add	di,fext		; point to the extension

popfoundw:	mov	es:[di],al
	inc	di
	inc	si
	and	al,al		; is it zero?
	je	popfounddone	; yes, quit!
	mov	al,[si]		;(get next char)
	jne	popfoundw	; nope ... keep working

popfounddone:
	pop	di
	pop	si		; restore registers
	pop	dx
	pop	cx
	pop	ax
	ret
popfound	endp


; ----------------------------------------------------------------------------
; copyfile
; this procedure completely copies a file.  it copies the file in
; sourcefile to the file in destfile.  If there is an error during
; the copy, the destfile is automatically deleted and the program
; terminates via exit.  If the copy is successful, the source file
; is deleted.  The dest file will inherit the same file time and
; date stamp as the source file.

copyfile	proc	near

	; first, try to open the dest file for reading

	mov	ah,OpenHandle		; open the
	mov	dx,offset destfile	; dest for
	mov	al,0			; reading
	int	INTDOS
	jc	cf_nameokay

	; we could read the source file!  the file already
	; exists, so we must abort.

	mov	bx,ax
	mov	ah,CloseHandle		; close the handle and
	call	newline
	mov	si,offset NameCollide	; print an error!
	call	putstr
	mov	ah,ERR_CopyProblem
	call	exit

cf_nameokay:	; try to open the source file

	mov	ah,OpenHandle		; open the 
	mov	dx,offset sourcefile	; source for
	mov	al,0			; for reading
	int	INTDOS

	; was there an error?

	jnc	cf_noopenerr

cf_cantread:	call	newline			; couldn't open; print
	mov	si,offset CantRead	; an error message
	call	putstr
	mov	ah,ERR_CopyProblem
	call	exit			; and terminate

cf_noopenerr:	mov	sourceh,ax		; save the handle

	mov	ah,CreateHandle		; open
	mov	dx,offset destfile	; desination
	xor	cx,cx			; no attribute
	int	INTDOS

	jnc	cf_nowriteopen

cf_cantwrite:	call	newline			; couldn't write; print
	mov	si,offset CantWrite	; an error message
	call	putstr
	mov	ah,ERR_CopyProblem
	call	exit			; and terminate!

cf_nowriteopen:	mov	desth,ax

cf_nextbunch:	mov	ah,ReadHandle		; read
	mov	cx,CopyBufferLen	; all we can
	mov	bx,sourceh		; from the source
	mov	dx,offset copybuffer	; into the buffer
	int	INTDOS

	jnc	cf_canread		; no read error?

	mov	dx,offset destfile	; delete the dest file
	mov	ah,DeleteFile
	int	INTDOS
	jmp	short cf_cantread	; print error and quit

cf_canread:
	and	ax,ax			; (Was it zero?)
	je	cf_closeup		; yes! go close the files

	mov	cx,ax			; take what we read
	mov	ah,WriteHandle		; and write it
	mov	dx,offset copybuffer	; from the buffer
	mov	bx,desth		; to the destination
	int	INTDOS

	jnc	cf_canwrite		; write error!

	mov	dx,offset destfile	; delete the dest file
	mov	ah,DeleteFile
	int	INTDOS
	jmp	short cf_cantwrite	; print error and quit

cf_canwrite:
	cmp	cx,ax			; did we write 'em all?
	jne	cf_cantwrite		; no?  that's a problem!
	je	cf_nextbunch

cf_closeup:
	mov	ax,GetDateTime		; get the date
	mov	bx,sourceh		; from the source file
	int	INTDOS

	mov	ax,SetDateTime		; set the date
	mov	bx,desth		; to the dest file
	int	INTDOS

	mov	bx,desth		; close dest file
	mov	ah,CloseHandle
	int	INTDOS

	mov	bx,sourceh		; close source file
	mov	ah,CloseHandle
	int	INTDOS

	;	get the source file's attribute byte

	mov	dx,offset sourcefile
	mov	ax,GetAttrib
	int	INTDOS

	;	set the dest file's attribute byte

	mov	dx,offset destfile
	mov	ax,SetAttrib		; CX is already set
	or	cx,020h			; but set archive bit
	int	INTDOS
	
	;	set the source file's attribute byte to normal

	mov	dx,offset sourcefile
	mov	ax,SetAttrib
	mov	cx,NormalAttrib		; reset source file
					; so we can now
	mov	dx,offset sourcefile	; delete the source file
	mov	ah,DeleteFile
	int	INTDOS

	ret
copyfile	endp


; ----------------------------------------------------------------------------
; getyesno
; This procedure prints a yes/no prompt on the screen and gets an answer.
; the routine accepts "y", "1", and "t" as affirmative responses.  the
; routine accepts "n", "0", and "f" as negative responses.  If the routine
; is given an affirmative response, it will return AX as 0001.  If it is
; given a negative reply, it will send back 0000 in AX.  If the routine
; receives "a" in reply to its prompt, it will return a 0002 in AX.

getyesno	proc	near

	mov	si,offset ConfirmPrompt	; print prompt
	call	putstr

gyn_delete:	xor	ax,ax
	mov	confirmreply,al

gyn_loop:	mov	ah,GetChar	; get one character
	int	INTDOS
	cmp	al,'a'
	jl	gyn_noup
	cmp	al,'z'
	jg	gyn_noup

	sub	al,('a'-'A')	; make it uppercase

gyn_noup:	mov	ah,confirmreply
	and	ah,ah
	jne	gyn_checkcr	; we got a letter, is this one
				; a carriage return?

	cmp	al,cr		; carriage return?
	je	gyn_negative	; yep, default is no!

	cmp	al,ctrlz	; control zee?
	jne	gyn_notzee

	; if CTRL+Z is pressed, we must quit here.

	mov	si,offset UAborted
	call	putstr		; make a message about it
	mov	al,ERR_None	; exit with no errors
	call	exit

gyn_notzee:	cmp	al,space	; is this character lower than ' '?
	jle	gyn_loop	; yep, ignore it

	cmp	al,'Y'		; filter out unwanted chars
	je	gyn_okay	;

	cmp	al,'N'
	je	gyn_okay

	cmp	al,'A'
	je	gyn_okay

	cmp	al,'0'
	je	gyn_okay

	cmp	al,'1'
	je	gyn_okay

	cmp	al,'T'
	je	gyn_okay

	cmp	al,'F'
	jne	gyn_loop

gyn_okay:
	mov	confirmreply,al	; store the character

	mov	ah,PutChar	; and echo it to the screen
	mov	dl,al
	int	INTDOS
	jmp	short gyn_loop	; go loop back for more

gyn_checkcr:	cmp	al,cr		; is this one a carriage return?
	je	gyn_replied	; yes! process the reply

	cmp	al,bs		; is this one a backspace?
	jne	gyn_loop	; no! bad char, ignore it

	mov	ah,PutChar	; put a backspace
	mov	dl,bs
	int	INTDOS

	mov	ah,PutChar	; put a space to whiteout
	mov	dl,space	; the character typed
	int	INTDOS

	mov	ah,PutChar	; and another BS to fix cursor
	mov	dl,bs
	int	INTDOS

	jmp	gyn_delete

gyn_replied:	mov	al,confirmreply	; get the reply, and decide what
				;	to do

	cmp	al,'A'
	je	gyn_everything

	cmp	al,'0'
	je	gyn_negative
	cmp	al,'F'
	je	gyn_negative
	cmp	al,'N'
	je	gyn_negative

	cmp	al,'Y'
	je	gyn_affirm
	cmp	al,'1'
	je	gyn_affirm
	cmp	al,'T'
	je	gyn_affirm
	jmp	gyn_loop	; somehow a bad char got in


gyn_everything:	mov	ax,2		; reply "all"
	ret

gyn_negative:	mov	ax,0		; negative reply
	ret

gyn_affirm:	mov	ax,1		; affirmative reply
	ret

getyesno	endp


; ----------------------------------------------------------------------------
; check4dir
; this routine accepts DI as a pointer to a FileNameS.  It will check
; to see if the file name section of the file name is actually a directory.
; if it is, it will move the file name to the end of the path field and
; make the file name null.  if not, it simply returns without changing
; the structure.  We have to do this because DOS won't understand us if
; we specify a subdirectory without tacking \*.* onto the end of it.
; If we end up changing anything, AX is set to one.  If not, AX is zilch.
;

check4dir	proc	near

	push	si		; save the pointer

	mov	di,offset temppath
	call	strcpy		; move drive to temppath

	mov	di,offset temppath
	add	si,path		; get the path
	call	strcat

	mov	di,offset temppath
	pop	si
	push	si
	add	si,fname
	call	strcat		; and finally add the filename

	mov	ah,FindFirst
	mov	dx,offset temppath
	mov	cx,SubDirAttrib	; get directories only
	int	INTDOS
	jnc	c4d_worked

	; return with al set to zero to indicate that
	; we didn't change the filename

	xor	ax,ax		; make a zilcher out of ax
	pop	si
	ret

	; it *is* a subdir!
	; concatenate the file to the path


c4d_worked:	pop	si
	push	si
	mov	di,si
	add	di,path
	add	si,fname
	call	strcat		; add filename to path

	mov	si,offset BackSlash
	call	strcat		; add backslash to path
	
	mov	si,offset Star	; put a star into the filename
	pop	di
	push	di
	add	di,fname
	call	strcpy

	mov	si,offset DotStar
	pop	di
	push	di
	add	di,fext		; and a ".*" into extension
	call	strcpy
	
c4d_end:	mov	ax,1		; ax=1, success!
	pop	si		; pop register and return!
	ret
check4dir	endp


; ----------------------------------------------------------------------------
; normpath
; this proc accepts a pointer to a FileNameS in DS:SI.  The proc will
; call DOS to have it normalize the path -- this simply means that the
; procedure will resolve any relative (ie, including "." or "..")
; file path references.  Note that the function call used here is
; undocumented.

normpath	proc	near

	push	di		; save the registers
	push	si


	mov	di,offset temppath
	call	strcpy		; copy drive and path to
	add	si,path		; a temporary area
	call	strcat

	mov	ah,NormalizePath
	mov	si,offset temppath
	mov	di,offset fixedpath
	int	INTDOS

	pop	si
	mov	di,si		; copy the path back
	add	di,path
	mov	si,(offset fixedpath)+2
	call	strcpy
	
	pop	di		; restore
	ret			; and return
normpath	endp


; ----------------------------------------------------------------------------
; That's a wrap.  Written under the influence of Tom Petty, Rush, and REM.

	end

