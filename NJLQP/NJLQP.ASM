TITLE Letter Quality Print V 1.43
SUBTTL (C) MCMLXXXVI - Nifty James
PAGE 60,132

; Note -- The PUBLIC declarations are for the use of the SYMDEB utility.

; Warning -- This .ASM file contains control characters so that it will
; automatically set and reset an EPSON to condensed (132 character) mode!

; Nifty James' famous letter quality printer program.

;       ----->  VERSION 1.43  <-----

; Designed for the EPSON series printers.  This version has been
; tested on the FX-80, FX-100, and MX-100.  If you have a printer that
; this program doesn't run with, contact the author and let him know
; about it... a new version may be available.  If you can describe the
; problem technically, I can easily re-write the software.  If your
; printer isn't listed above, and the program works correctly, let me
; know, so others can benefit!

; Written with/for      Microsoft Macro Assebmler Package V4.0 (Amen.)
;                       IBM PC  DOS 3.10 (Hmmm..) (see the .DOC file!)
;                       Epson Series Printers (Banzai!)
;                       Users with a sense of humor (Hey!)

; Revision List:   V1.00 -- 20 Jan 1986 to 24 Feb 1986
;                  V1.20 -- 24 Feb 1986 to 15 Mar 1986
;                       (added the "output to" file name, -f and -s
;                        options, and better graphics characters)
;                  V1.32 -- 16 Mar 1986 to 05 May 1986
;                       (Macro Assembler Version 4.00, different
;                        structure, better loops, ect)
;                  V1.39 -- 06 May 1986 to 20 Aug 1986
;                       (Now it all works!)
;                  V1.41 -- 08 Mar 1987
;                       (Got rid of that annoying little arrow
;                        at the end of some files.)
;                  V1.42 -- 26 Mar 1987
;                       (Fixed a bug under DOS versions prior to
;                        DOS 3.00.  Thanks, AVATAR!)
;		   V1.43 -- 27 Mar 1987
;			(Changes for DOS 3.x, allowing more convenient
;			 use on the network.)

; This is a ShareWare program.  As far as I'm concerned, this means that
; I own the idea and concept, while you can throw the program around as
; you please.  I would very much appreciate it if you distribute the
; program with all the files included in theis ARCive... namely,
; NJLQP.ASM, EPSSET1.INC, NJLQP.COM and NJLQP.DOC. This eases
; updates, and makes it look like it did when it left here.  Thankya.

; I'm trying to scrape enough dough together to purchase A) the DOS 3.10
; Technical manual, and B) A mass storage device.  I'd more than welcome
; any contributions that you'd care to send.  I'm a high-school student;
; I suppose $10 or $15 is not too much to ask. Especially if you're using
; this program at a government post or at your job.  Just remember, you're
; probably making more than I am.

; Low bow department:   Hats off to Mike Todd of the IBMSIG on the $ource.
;                       Thanks to Mike Quinlan for help with IOCTL stuff.
;                       Kudos to Barbarian for helping me with "C".
;			Special thanks to Dr File Finder for distribution!
;			Thanks to Avatar for patience and persistence.

; To contact the author, send contributions, ideas, Christmas cards, or
;       marriage proposals:

;                               on Parti On NWI as NIFTY JAMES or MIKE B
;                               on CompuServe 76210,1546
; Nifty James                   via Parti On the Source : NIFTY JAMES
; % Mike Blazak                 via SMIAL on the Source : BCB922
; 112 Verlinden Dr              And under either name on finer BBS systems
; Monroeville, PA, 15146          around the country
;                               (Such as the Pitt-Bull Fido node, )

; Design philosophy:  "Grin and ignore it"

subttl Declarations - Equates
page +

; Here's the serious stuff --

                .radix  10      ;cuz that's how many fingers I have!
if1
        %OUT Start Pass 1
else
        %OUT Start Pass 2
endif

Bell            equ     7               ;ASCII  bell
Tab             equ     9               ;       tab
LF              equ     10              ;       line feed
FF              equ     12              ;       form feed
CR              equ     13              ;       carriage return
EOF             equ     26              ;       end of file
ESC             equ     27              ;       ESCape code
escape          equ     27              ;        ditto
Space           equ     32              ;       space


KeyLookCode     equ     006h            ;function to check the console
VersionCode	equ	030h		;function to get DOS version number
CreateCode      equ     03Ch            ;function to create and write a handle
OpenCode        equ     03Dh            ;function to open a DOS handle
CloseCode       equ     03Eh            ;function to close/flush a DOS handle
ReadCode        equ     03Fh            ;function no to read from DOS handle
WriteCode       equ     040h            ;function to write to DOS handle
DeleteCode      equ     041h            ;function to delete a DOS hanlde
AttribCode      equ     043h            ;function to modify attribute
IOCTLCode       equ     044h            ;function to set I/O Mode and format
Terminate       equ     04Ch            ;Terminate Call for DOS (w/ ERRORLEVEL)

UsageError      equ     1               ;ERRORLEVEL error for bad Usage
TooFullE        equ     2               ;ERRORLEVEL error for full output dev
FileError       equ     3               ;ERRORLEVEL error for can't open file
UserAborted     equ     4               ;ERRORLEVEL error for user abort (ESC)

STDIN           equ     0000h           ;standard input handle
STDOUT          equ     0001h           ;standard output handle
STDERR          equ     0002h           ;standard error output handle
STDPRN          equ     0004h           ;standard printer device

MaxArgs         equ     5               ;number of args that the program has
Opts            equ     3               ;number of -options
Files           equ     2               ;number of file names

SpaceNormal     equ     36              ;normal spacing (1/6 inch)
SpacePhase      equ     1               ;inter-phase spacing (1/216 inch)
SpaceFeed       equ     35              ;spacing after line (35/216 inch)

                        ;note that SpaceNormal == SpacePhase + SpaceFeed

page
subttl Declarations - Publics

		public	FBytes, CMDLen, CMDLine, LetQual
		public	UseTwo, LineOnePos, LineTwoPos, Phase
		public	FileNotOver,RBuffSiz, RBuffPos, RBuffCursor
		public	ThisChar, NextChar
		public	Banner, Usage, FF1M, NoSkipMsg, SkipMsg
		public	NotOpen, TooFull, Success, AbortM, StrokeN
		public	LeadIn, Spacing, SkipOn, SkipOff, DotCount
		public	Status, InFile, OutFile, OutError, OutFileName
		public	LineAddr, Rings, OneBuff, Args, POption
		public	FOption, EOption, DOSVer

		public	Genesis, EatWhite, SetAddr, EatGarbage
		public	EatG2, EGW, EGCR, DoneParsin, ShowUsage
		public	Exit, JustClose, NoClose
		public	OverShow, Oomlat, Oomlat2, NotPOpt, NotDOSThree
		public	GotAFile, GotInFile, FileOpened, SetOutHandle

		public	Prelims, TellPerf, TellPerf2, CheckMode
		public	CheckedOut, CheckedOut2, MainLoop
		public	MainLoop, NoKeyP, PostGetLine, NoEcho
		public	OnlyOne, BlankLine, Checks, MainNoForm
		public	CheckFOpt, Complete, Show

		public	PrintLine, PhaseLoop, PLineC, NotBeep
		public	PLNoAdd, PLBloop, Phase0End, Phase1End
		public	BellLoop, BellsOver

		public	CheckWhite, CheckWhiteL, CWNext
		public	CWExit, CWTrim, CWTrimL, CheckWhite

		public	SNewLine, LNewLine

		public	PrtOne, Prt1Err

		public  GetLine
		public	GMMarker, GMNotFF, GMGotCR, GMNotCR
		public	GMTabEX, GMTabEX2, GMNotTab, LoopBack
		public	PostStore, LoopBack2, ItsEnded

		public	GetChar, GetCharC, GetCharG, GetCharE

		public	PutPrint, PPFull

		public	LineOne, LineTwo, ReadBuffer

page
subttl Declarations - Memory and Storage

CSeg            segment para public
                assume  CS:CSeg,DS:CSeg,SS:CSeg

                org     0006h           ;free space (in the PSP)
FBytes          label   word

                org     0080h           ;tell me about the command line...
CMDLen          label   byte

                org     0081h
CMDLine         label   byte

                org     0100h           ;for the sake of all .COM files

LetQual         proc    far

                cld                     ;set direction up!
                jmp     Genesis         ;skip the data areas


                .XLIST                  ;turn listing off while I go get the
        INCLUDE EPSCHR1.INC
                .LIST                   ;character table file

UseTwo          db      ?               ;is line two valid? 1=Yes, 0=No
LineOnePos      db      ?
LineTwoPos      db      ?               ;line positions (lengths)
Phase           db      ?               ;pass number during graphics print

FileNotOver     dw      1               ; != 0 if file not over, == 0 if EOF
RBuffSiz        dw      ?               ;max size of ReadBuffer
RBuffPos        dw      ?               ;Chars in ReadBuffer
RBuffCursor     dw      ?               ;pointer to char that will be read next

ThisChar        db      0FFh            ;the character just read
NextChar        db      0FFh            ;the character that will be read next

Banner          db      cr,lf           ;advertising!
                db      "Nifty James' Letter Quality Printer -- "
                db      "Version 1.43 - Epson",cr,lf
                db      "[ESC] to abort print",cr,lf
BannerLen       equ     this byte - Banner

Usage           db      cr,lf
                db      'Usage:',cr,lf
                db      '  [path\]NJLQP [drive:][\path\]filename [[drive:][\path\]'
                db      'filename] [options]',cr,lf,lf
                db      tab,'options --',tab,'-f  print formfeed after file'
                db      cr,lf
                db      tab,tab,tab,'-p  print over perforation',cr,lf
                db      tab,tab,tab,'-e  echo the file to stdout',cr,lf
                db      lf
UsageLen        equ     this byte - Usage

FF1M            db      cr,lf,'Formfeeding after the file.',cr,lf
FF1MLen         equ     this byte - FF1M

NoSkipMsg       db      'Not '
SkipMsg         db      'Skipping over perforations.',cr,lf
SkipMsgLen      equ     this byte - SkipMsg
NoSkipMsgLen    equ     this byte - NoSkipMsg

NotOpen         db      cr,lf
                db      'NJLQP: Cannot open file',cr,lf
NotOpenLen      equ     this byte - NotOpen

TooFull         db      cr,lf
                db      'NJLQP: Output Device Full',cr,lf
TooFullL        equ     this byte - TooFull

Success         db      cr,lf                   ;the definition of SUCCESS?
                db      'NJLQP: File Printed!',cr,lf
StrokeN         db      cr,lf
SuccessLen      equ     this byte - Success

AbortM          db      cr,lf
                db      'NJLQP: Aborted by user',cr,lf
AbortMLen       equ     this byte - AbortM

LeadIn          db      escape,'L'              ;graphics mode set
LeadInLen       equ     2

Spacing         db      escape,'3'              ;line spacing set
SpacingLen      equ     2

DOSVer		db	0			;the current DOS version

SkipOn          db      escape,'N',6            ;skip over perf set
SkipOnLen       equ     3

SkipOff         db      escape,'O'              ;skip over perf cancel
SkipOffLen      equ     2


DotCount        dw      ?               ;number of graphic bytes to print

Status          db      ?               ;status of the read

FormFeed        equ     2               ;form-feed flag   (for Status flag)
Normal          equ     1               ;all's well flag
FileOver        equ     80h             ;file ended flag

InFile          dw      0FFFFh          ;input file handle
OutFile         dw      0FFFFh          ;output file handle
OutError        db      0		;set to one if OutFile must be erased
OutFileName     dw      0		;pointer to output file ASCIIZ name

                                ;note that the file handles will equal
                                ;0FFFFh until something is put into them


LineAddr        dw      ?               ;temp storage for pointer to line (PrintLine)
Rings           db      ?               ;times to ring the bell (PrintLine)

OneBuff         db      ?               ;single character buffer

Args            dw      MaxArgs dup(?)  ;array of pointers to command line

POption         db      0FFh            ;default is skipping over (true)
FOption         db      0               ;default is no form feed  (false)
EOption         db      0               ;default is no echo       (false)



page +
subttl Code - Main Routine

Genesis:        mov     ax,FBytes       ;set up buffer size
                sub     ax,(offset CodeSize)+40
                                        ;minus the prog/data size and 20
                                        ; words for the stack
                mov     RBuffSiz,ax

		mov	ah,VersionCode
		int	21h		; get version from DOS
		mov	DOSVer,al	; and save it for later

                mov     dx,MaxArgs      ;parse that sucker!
                mov     di,offset Args
                mov     si,offset CMDLine
                xor     ch,ch           ;zero the high byte
                mov     cl,CMDLen       ;set the low byte to length

EatWhite:       lodsb                   ;mov al,[si++]
                cmp     al,CR           ;is it a carriage return?
                je      DoneParsin
                cmp     al,Tab          ;is it a tab?
                je      EatWhite
                cmp     al,Space        ; or a space?
                je      EatWhite        ;yep, eat it up!

SetAddr:        ;now, we gots the first character of an argument in AL, and
                ;a pointer to the character after that in SI.  We'll stick
                ;the pointer into the ARGS array, and adjust the args count,
                ;which is in DX.  If DX is negative, there are too many args,
                ;and we'll tell the user what he's doing.

                dec     dx
                js      ShowUsage       ;if neg, then yell, kick, and scream

                mov     [di],si         ;set the pointer
                dec     word ptr [di]   ;the pointer must be dec'ed cuz the
                                        ;loops are funny
                inc     di              ;increment the pointer to the
                inc     di              ;ARGS array.

EatGarbage:     ;Okay, that's done.  We'll eat up the argument, since we
                ;already have a pointer to it.  If we reach white space,
                ;we'll go back to "EatWhite".  If we reach a carriage return,
                ;we're at the end of the command line, and we're done
                ;parsing.  When we reach white space or a carriage reutrn,
                ; we will stick a 0 there to mark the end of the arg.

                xor     ah,ah           ;make a zero so we have it for later

EatG2:          cmp     al,CR           ;is it a carriage return?
                je      EGCR            ; yep, handlit, handlit!

                cmp     al,Space        ;is it a Space?
                je      EGW
                cmp     al,Tab          ;or Tab?
                je      EGW             ; yep, go back to eat up more
                lodsb
                jne     EatG2

EGW:                                    ;righto, we got the white, so put
                                        ; a zero there

                dec     si              ;yes, its whitespace, so adjust
                mov     [si],ah         ;the pointer and stick a zero there
                inc     si
                jmp     short EatWhite	;and go eat up the white space

EGCR:           dec     si              ;stick a zero there and flow through
                mov     [si],ah         ;to...


DoneParsin:     ; Okey Doke.  We've got an array of pointers to the
                ; arguments in the command line, and all the commands are
                ; terminated by a 00h.  Look at the argument count to
                ; see if it indicates that the user doesn't know what he's
                ; doing.  But don't trash the DX reg (arg count).

                mov     ax,dx           ;make a copy of dx
                mov     dx,MaxArgs      ;and make dx := MaxArgs - dx
                sub     dx,ax
                mov     ax,dx           ;ax = dx

                je      ShowUsage       ;if there were no args
                js      ShowUsage       ;or there were too many args

                mov     dx,offset Banner
                mov     cx,BannerLen    ;otherwise, all's well and we
                call    Show            ;reward the user with the banner

                mov     dx,ax           ;retrieve copy of dx
                jmp     short OverShow	;skip over SHOWUSAGE so we can keep
					;all the branches short


ShowUsage:      mov     dx,offset Usage         ;point to usage string
                mov     cx,UsageLen             ;length of usage string
                call    Show
                mov     al,UsageError           ;report a usage error in ERRORLEV

Exit:           push    ax              ;save the ERRORLEVEL code

                mov     bx,OutFile
                mov     ch,OutError     ;should the OutputFile be erased?

                cmp     bx,STDPRN       ;is it the printer?
                je      NoClose         ;yes, don't do anything

                mov     ah,CloseCode    ;otherwise, close the file
                int     21h

                and     ch,0FFh         ;is the file garbage? (ch=OutError)
                je      JustClose       ;no, don't delete it.

                mov     ah,AttribCode   ;change attrib to zero
                xor     cx,cx
                mov     dx,OutFileName  ;get pointer to name
                int     21h

                mov     ah,DeleteCode   ;delete the file
                int     21h
                jmp     short NoClose

JustClose:      mov     ah,CloseCode
                mov     bx,OutFile
                int     21h

                pop     ax              ;get ERRORLEVEL back

BackDoor:
NoClose:        mov     ah,Terminate
                int     21h             ;get outta here!

;----------------------------------------------------------------------------

OverShow:               ; Now that we've (hopefully) got a pointer to the
                        ; args, we will try to parse them.  If we get too
                        ; may filenames too many options, or unrecognizable
                        ; options, exit through ShowUsage.  If we can't
                        ; open the input file, we tell the user about it
                        ; and exit.  Set the option flags as we go.

                mov     si,offset Args  ;get a pointer to the Args pointer

Oomlat:         dec     dx              ;decrement the arg counter
                jns     Oomlat2         ;done with all args?
                jmp	Prelims		; yes, go to it (rel jmp out of range)

Oomlat2:        mov     di,[si]         ; no, get a pointer to the first arg
                inc     si
                inc     si              ;and update the pointer to Args[]

                mov     ax,[di]         ;get two chars from the command line
                cmp     al,'-'          ;is it an option marker?
                jne     GotAFile        ; no, assume it's a file name

                and     ah,11011111b    ;make uppercase (mask out bit 32)

                cmp     ah,'P'          ;perforation option?
                jne     NotPOpt         ; no

                not     POption         ;toggle the option's flag
                jmp     short Oomlat	;und go baken fer more

NotPOpt:        cmp     ah,'E'          ;echo option?
                jne     NotFOpt         ; no

                not     EOption         ;toggle the option's flag
                jmp     short Oomlat	; izen yu siken of dur coot name, ja?

NotFOpt:        cmp     ah,'F'          ;then is it an "F"?
                jne     ShowUsage       ;no?  Tell the user about it

                not     FOption         ;toggle the F option's flag
                jmp     short Oomlat	;unt vee go du a leettle more


GotAFile:       mov     al,1            ;assume writing
                mov     ah,CreateCode   ;and creating a new file
		xor	cx,cx           ;creating with attibute 0000h

                mov     bx,InFile
                cmp     bx,0FFFFh       ;do we have an input file?
                jne     GotInFile       ; yea, go check output file
                mov     al,0            ;otherwise, we're reading
                mov     ah,OpenCode     ;and opening an existing file
		push	dx		;save args count
		mov	dl,DOSVer	;is it DOS 3.x?
		cmp	dl,3
		jne	NotDOSThree

		or	al,00100000b	;tell DOS that noone else 
					; can write it, but anyone can
					; read it

NotDOSThree:	pop	dx
                mov     bx,OutFile      ;do we already have the out file,
                cmp     bx,0FFFFh       ; by chance?
                je      GotInFile       ; no, ramble on
                jmp     ShowUsage       ; yea, tell user  (out of rel range)


GotInFile:      push    dx              ;save the args count
                mov     dx,di           ;make a pointer to the filename
                int     21h

                pop     dx              ;get args count back

                jae     FileOpened      ;if carry not set, continue

                mov     dx,offset NotOpen ;if carry set, then there's
                mov     cx,NotOpenLen     ;unrest!
                call    Show

                mov     al,FileError    ;and give up.
                jmp     Exit

FileOpened:     mov     bx,0FFFFh       ;what file was that?
                cmp     InFile,bx
                jne     SetOutHandle

                mov     InFile,ax       ;set input file handle
                jne	SetOutHandle	; (RELATIVE JUMP OUT OF RANGE)
		jmp	Oomlat		; jne Oomlat

SetOutHandle:   mov     OutFile,ax      ;set output file handle
                mov     OutFileName,di  ;set output file name pointer
                mov     ah,0FFh
                mov     OutError,ah     ;set error flag just in case

                je      Prelims
                jmp     Oomlat		;(RELATIVE JUMP OUT OF RANGE)

;----------------------------------------------------------------------------

Prelims:	; Now, we check to be sure that the OutFile has
		; actually been defined.  If it hasn't, default
		; to the STDPRN device, which should be the printer
		; or a device driver configured to rout STDPRN
		; to a COM port.  We'll also tell the user what
		; we are doing, as far as skipping over perfs or
		; not skipping over perfs is concerned.

		; After that, we use the IOCTL call to make sure
		; that the handle that we're writing to is set up
		; for binary mode. (Special thanks to Mike
		; Quinlan, Parti On The Source, "IBM ASSEMBLY" for
		; disclosing just what was happening here!)

                mov     bx,OutFile
                cmp     bx,0FFFFh               ;is it defined?
                jne     TellPerf                ; yea, move on to Perfs
                mov     bx,STDPRN
                mov     OutFile,bx

TellPerf:       mov     dx,offset NoSkipMsg     ;assume not skipping
                mov     cx,NoSkipMsgLen

                mov     ah,POption
                and     ah,ah                   ;is it 00 or FF?
                je      TellPerf2               ;yes, we're right, print it

                mov     dx,offset SkipMsg
                mov     cx,SkipMsgLen

TellPerf2:      call    Show                    ;show it
                call    SNewLine

                xor     ah,ah           ;clear error flag, for now
                mov     OutError,ah

CheckMode:      mov     ah,IOCTLCode    ;use IOCTL to get the file mode
                mov     bx,OutFIle      ;get a handle on things
                mov     al,0            ;device information
                int     21h             ;DOS returns info in DX

                test    dx,0020h        ;is this handle a device?
                jne     CheckedOut      ;no, already in binary mode

                or      dx,0020h        ;Set binary mode
                and     dh,0        ;  clear high side so we don't confuse DOS
                mov     ah,IOCTLCode    ;IOCTL to set a file mode
                mov     bx,OutFile      ;regain a grip on the handle of...
                mov     al,1            ;set device information
                int     21h

CheckedOut:             ;pass control to the more interesting stuff
                        ;like setting the skip over perf to the default

                mov     dx,offset SkipOn ;assume Skip is On
                mov     cx,SkipOnLen

                mov     al,POption      ;if our assumption is right,
                cmp     al,0FFh         ; then move on
                je      CheckedOut2

                mov     dx,offset SkipOff
                mov     cx,SkipOffLen   ;otherwise, get stuff for SkipOff

CheckedOut2:    call    PutPrint


;----------------------------------------------------------------------------

                        ; Righto.  Time to get down to the nitty gritty.
MainLoop:               ; The main routine calls GetLine and checks out
                        ; the status.  If the files over, we're done.
                        ; We print as many lines as need be, and handle
                        ; all the spacing and control codes here.  If
                        ; everything is hunky dory, we go back for more.


                mov     ah,KeyLookCode  ;check for ESC
                mov     dl,0FFh         ; keypress from keyboard
                int     21h
                je      NoKeyP          ;no key pressed?

                cmp     al,escape       ; was it escape?
                jne     NoKeyP          ; no, not ESC, ramble on

                mov     dx,offset AbortM        ;mention the error
                mov     cx,AbortMLen
                call    Show

                mov     dl,0FFh
                mov     OutError,dl     ;set OutError flag
                mov     al,UserAborted  ; and set ERRORLEVEL
                jmp     Exit            ; go for the door


NoKeyP:         call    GetLine         ;get a line
                call    CheckWhite      ;see if its all white stuff

PostGetLine:    mov     dx,offset LineOne
                mov     cl,LineOnePos
                cmp     cl,0                    ;is cx zero, per chance?
                je      BlankLine               ;hot damn, skip all the prints

                call    PrintLine               ;and print it

                cmp     EOption,0               ;is EOption true?
                je      NoEcho                  ; no, skip the echo

                call    Show                    ; yes, echo the line

NoEcho:         xor     ax,ax                   ;are there two lines?
                cmp     al,UseTwo
                je      OnlyOne                 ;nay, only one, ramble on...

                call    LNewLine                ;lprint a newline
                mov     cl,LineTwoPos
                xor     ch,ch
                mov     dx,offset LineTwo       ;print line two, otherwise
                call    PrintLine

OnlyOne:                                ;(Come here if there are no overstrikes)
                mov     cx,SpacingLen
                mov     dx,offset Spacing
                call    PutPrint                ;print spacing command

                mov     al,SpaceFeed
                call    PrtOne

BlankLine:                              ;(come here if the line is blank)
                call    LNewLine                ;and send a new line
		cmp	EOption,0
		je	Checks		; if echo is on, print blank
		call	SNewLine	; to STDOUT, also

Checks:         mov     ah,Status               ;so, whats up?
                cmp     ah,Normal
                je      MainLoop                ;if all's well, ramble on

                cmp     ah,FormFeed             ;got the Form Feed?
                jne     MainNoForm              ;if it's a form, then
                mov     al,FF                   ; get the form feed
                call    PrtOne                  ; print the FF
                jmp     MainLoop                ; and go loopin'...

MainNoForm:     mov     cx,SpacingLen           ;reset the spacing
                mov     dx,offset Spacing
                call    PutPrint

                mov     al,SpaceNormal          ;to the normal 36/216 (1/6) inch
                call    PrtOne


CheckFOpt:      mov     al,FOption      ;check the FF after file option
                cmp     al,0FFh         ;is it true?
                jne     Complete        ; no, don't form feed

                mov     dx,offset FF1M  ;otherwise,
                mov     cx,FF1MLen      ; say that we're about to feed
                call    Show

                mov     al,FF           ;and
                call    PrtOne          ;send form feed

Complete:       mov     cx,SuccessLen
                mov     dx,offset Success
                call    Show                    ;say that we're done

                xor     ax,ax                   ;zero AX
                jmp     Exit                    ;End of main routine



page +
subttl Code - Subroutines

Show            proc    near

                push    ax              ;save regs on stack
                push    bx
                mov     ah,WriteCode    ;write -->DX
                mov     bx,STDOUT       ;to STDOUT
                int     21h             ;via DOS
                pop     bx
                pop     ax
                ret                     ;return to caller

Show            endp

;----------------------------------------------------------------------------

PrintLine       proc    near            ;print line pointed to by DX, having CX characters

;       This section gets a little tricky; it's the heart of LQ printing.

;       The subroutine steps through all CX characters in the area at DX.
;       It loads a character from the DX buffer into AL.  The character
;       int AL is looked up at CHART (check the include file!) by this
;       formula:
;                       ADDR = (PASS*HALFWIDTH) + (CHAR*FULLWIDTH) + offset CHART

;       Where - Pass is 0 to 1, the pass of the printhead.
;               HalfWidth is half the width (in graphics columns) of a char
;               FullWidth is the entire width of a char
;               offset CHART is the offset of CHART in the Data Segment

;       Note that HalfWidth and FullWidth are defined in the include file.

;       In interests of speed, the method used here is not pretty; the
;       address calculation routine must be done twice for every character
;       printed.  Also, the comments are rather, well, cryptic. (Hey,
;       let's see *you* write good code in Ms. "Bergermister's" study hall!)

                push    di
                push    dx              ;way to work the stack, kid

                xor     ch,ch           ;zero useless high byte of cx
                push    cx

                mov     bx,cx           ;save regs and make copies
                mov     LineAddr,dx     ;store offset to line buffer

                xor     ax,ax           ;zero
                mov     Phase,al        ; the phase count
                mov     Rings,al        ; and the ring count

                mov     al,HalfWidth
                mul     bl              ;calculate number of graphics bytes
                mov     DotCount,ax     ;to print, and store it

PhaseLoop:
                mov     cx,LeadInLen            ;print the leadin
                mov     dx,offset LeadIn
                mov     bx,OutFile
                mov     ah,WriteCode
                int     21h

                mov     bx,DotCount             ;get length of graphics area
                mov     al,bl
                call    PrtOne
                mov     al,bh
                call    PrtOne                  ;and print it

                pop     bx                      ;get chars to print
                push    bx                      ;from the stack
                mov     di,LineAddr             ;get line address from temp

;       Okay, BX has the number of characters to print.  BP points
;       to where these characters are at.  All other registers are at
;       our disposal.  First, we calculate the address of the data for
;       the character at BP.

PLineC:         mov     al,[di]         ;get the character

                cmp     al,bell         ;is it a bell?
                jne     NotBeep

                inc     Rings           ;increment ring count
                mov     al,0            ;and print a null character

NotBeep:        mov     si,offset Chart ;get the offset of font table
                mov     dl,Phase
                cmp     dl,0
                je      PLNoAdd         ;do we need to add for Phase?
                add     si,HalfWidth

PLNoAdd:        mov     cl,FullWidth
                mul     cl              ;AX = CL * AL
                add     si,ax           ;add it to the offset

;       Then we print the font data containted at the calulated address

                mov     dx,si           ;print chars from calced font addr
                mov     cx,HalfWidth    ; and print a pass' worth of chars
                call    PutPrint        ; to selected output file

PLBloop:        inc     di              ;update pointer to chars
                dec     bx              ; and count of chars to print
                jne     PLineC          ; then loop back for more!

                mov     al,Phase        ;check out Phase to see what's up
                cmp     al,1
                je      Phase1End       ;done with Phase one...

;       At the end of the first phase, we must print the 1/216th inch line feed

Phase0End:      inc     Phase                   ;one up the Phase count

                mov     dx,offset Spacing       ;print Spacing command
                mov     cx,SpacingLen
                call    PutPrint

                mov     al,SpacePhase           ;feed 3/216 of an inch
                call    PrtOne
                call    LNewLine                ;and a newline sequence
                jmp     short PhaseLoop

;       The Calling routine must take care of the final newline, as there
;       may not be one, depending on the state of UseLineTwo.  It also must
;       reset the line spacing value.  On our way out, we'll print all the
;       bells that appeared on this line.  Then we'll pop the regs and
;       split.

Phase1End:      xor     cx,cx
                mov     cl,Rings        ;set up ring count
                mov     al,Bell         ; and bell character

BellLoop:       cmp     cl,0            ;zero?
                je      BellsOver       ; yep, done

                call    PrtOne          ; no, do another
                dec     cx
                jns     BellLoop        ;and loop back

BellsOver:      pop     cx
                pop     dx              ;get them regs back!
                pop     di
                ret                     ;and gowan home, kid

PrintLine       endp

;----------------------------------------------------------------------------

CheckWhite      proc    near

        ;we're called from mainloop after getline and before a check is
        ;made to see if the line length is zero.  We simply look through
        ;LineOne to see if it is only whitespace.  If so, we will
        ;zero LineOnePos.  If not, we'll look at the *end* of the line to
        ;be sure that there is no trailing white space.

                push    cx

                mov     si,offset LineOne       ;get the pointer
                mov     cl,LineOnePos           ; and the counter

CheckWhiteL:    lodsb                   ; get next byte and inc si

                cmp     al,space        ;is it space?
                jne     CWTrim          ; no, not whitespace, go check
                                        ;       trailing whitespace

CWNext:         dec     cl              ;decrement length
                jne     CheckWhiteL     ;   more?  loop back

                mov     LineOnePos,0    ;zero line one pos - buffer is
                                        ;  full of SPACEs
CWExit:         cld                     ;reset dir flag
                pop     cx
                ret

CWTrim:         cmp     LineOnePos,0            ; is it already zero?
                je      CWExit

                mov     si,(offset LineOne)-1   ;get offset
                mov     cl,LineOnePos           ;  and get the counter
                                                ;point to end of line first
                xor     ch,ch                   ; zero ch
                add     si,cx

                std             ; set direction down
CWTrimL:        lodsb                           ; get next byte
                cmp     al,space                ; is it a space?
                jne     CWExit                  ;  no, return

                dec     LineOnePos              ; decrement length
                jne     CWTrimL                 ;       loop back, if more
                je      CWExit                  ; ditch if done!


CheckWhite      endp

;----------------------------------------------------------------------------

SNewLine        proc    near            ;send a newline to stdout

                push    cx
                push    dx              ;save the regs

                mov     cx,2
                mov     dx,offset StrokeN       ;point to newline
                call    Show

                pop     dx
                pop     cx              ;pop regs and split
                ret

SNewLine        endp

;----------------------------------------------------------------------------

LNewLine        proc    near            ;send a newline to the output

                push    ax
                push    bx
                push    cx
                push    dx              ;save the regs, before its too late

                mov     bx,OutFile
                mov     cx,2            ;two characters in a newline
                mov     dx,offset StrokeN
                mov     ah,WriteCode
                int     21h

                pop     dx
                pop     cx
                pop     bx
                pop     ax              ;gimme that back!

                ret

LNewLine        endp

;----------------------------------------------------------------------------

PrtOne          proc    near            ;this prints a single character from
                                        ; AL to the handle in OutFile

                push    ax
                push    bx
                push    cx
                push    dx

                mov     OneBuff,al              ;put it in memory

                mov     ah,WriteCode
                mov     bx,OutFile
                mov     cx,1                    ;write that one character
                mov     dx,offset OneBuff       ;from that point in memory
                int     21h

                pop     dx
                pop     cx
                pop     bx
                pop     ax

                jb      Prt1Err         ;if there was an error, don't RET
                ret

Prt1Err:        pop     ax
                pop     ax              ;clean the stack off
                jmp     PPFull		;and go print the error

PrtOne          endp

;----------------------------------------------------------------------------

GetLine         proc    near            ;get the next line of text

                xor     ah,ah           ;zero the...
                mov     UseTwo,ah       ;       Two Line flag
                mov     LineOnePos,ah   ;       line lengths
                mov     LineTwoPos,ah

GMMarker:       call    GetChar         ;get a character

                mov     ah,ThisChar
                cmp     ah,0FFh         ;is it a pre-buffer character?
                je      GMMarker        ;yea, get more

                cmp     ah,FF           ;form feed?
                jne     GMNotFF
                mov     ah,FormFeed
                mov     Status,ah       ;set that flag
                ret                     ;and return

GMNotFF:        cmp     ah,CR           ;carriage return?
                jne     GMNotCR

GMGotCR:        mov     ah,Normal       ;Line ended, all normal.
                mov     Status,ah       ;set the flag
                ret

GMNotCR:        cmp     ah,LF           ;a line feed?
                je      LoopBack2       ;yea, just ignore it
                cmp     ah,tab          ;a tab?
                jne     GMNotTab

GMTabEx:        mov     dl,LineOnePos   ;expand the tab
                xor     dh,dh

GMTabEx2:       mov     dl,LineOnePos
                mov     di,dx
                mov     byte ptr [di+offset LineOne],space      ;with spaces
                inc     LineOnePos                      ;increment pointer
                inc     dl              ;make 1..256 into 0..255 to
                and     dl,00000111b    ; see if Pos is divisible by eight
                jne     GMTabEx2
                je      PostStore       ;skip storeing the tab,
                                        ;  since we expanded it

GMNotTab:       cmp     ah,EOF     ; is it end of file mark?
                je      ItsEnded   ;  yep.  end of file found!

LoopBack:       mov     dl,LineOnePos   ;get the line position
                xor     dh,dh           ;zero the high byte
                mov     di,dx                   ;and put the result into the offset reg
                mov     [di+offset LineOne],ah  ;stow the character
                inc     LineOnePos              ;and increment the line pos


PostStore:      cmp     dl,79           ;is it a full line?
                jae     GMGotCR         ;yes, split the line

LoopBack2:      cmp     FileNotOver,0   ;has the file ended?
                jne     GMMarker

ItsEnded:
                mov     ah,FileOver     ;yes, set the flag
                mov     Status,ah
                ret                     ;and return

GetLine         endp


;----------------------------------------------------------------------------

GetChar         proc    near            ;get a character and bump Last & This

GetCharC:       mov     dx,RBuffPos
                cmp     dx,0000h        ;need more chars?
                jne     GetCharG

                mov     cx,RBuffSiz             ;yea, get more characters
                mov     dx,offset ReadBuffer    ;Read more into the buffer
                mov     ah,ReadCode
                mov     bx,InFile       ;get file handle
                int     21h

                mov     RBuffPos,ax     ;move actual read count into BuffPos
                mov     FileNotOver,ax  ;       and into FileOver flag

                xor     bx,bx           ;and put the cursor on the first char
                mov     RBuffCursor,bx

GetCharG:       mov     di,RBuffCursor
                inc     RBuffCursor     ;pointer housekeeping
                dec     RBuffPos

                mov     al,[di]+ReadBuffer
                xchg    NextChar,al     ;bump up the old characters
                xchg    ThisChar,al

GetCharE:       ret                     ;and go home!

GetChar         endp

;----------------------------------------------------------------------------

PutPrint        proc    near

                        ; this subroutine calls DOS to output the
                        ; string -> DX, which is CX chars long. Same
                        ; as Show, but uses the handle in OutFile, and
                        ; can handle errors

                push    ax
                push    bx

                mov     bx,OutFile      ;get output file handle no.
                mov     ah,WriteCode
                int     21h             ;call DOS to write it.
                cmp     ax,cx

                pop     bx
                pop     ax
                jne     PPFull          ;if everything wasn't printed...

                ret             ;otherwise, we're outta here

PPFull:         mov     dx,offset TooFull ;then error!
                mov     cx,TooFullL
                call    Show            ;show the error

                mov     ah,0FFh         ;set output error flag so file
                mov     OutError,ah     ; will be deleted.

                mov     al,TooFullE     ;set ERRORLEVEL
                jmp     Exit            ;and go for the door.

PutPrint        endp

;----------------------------------------------------------------------------

page +
subttl Non-predefined Storage


LineOne         equ     this byte + 1   ;LineOne preprint buffer
LineTwo         equ     LineOne +  83   ;LineTwo preprint buffer

CodeSize        equ     LineTwo +  83

ReadBuffer      equ     LineTwo + 256   ;Read buffer for Block Reads

if1
        %OUT End   Pass 1
else
        %OUT End   Pass 2
endif

LetQual         endp
CSeg            ends
                end     LetQual

; Thats' the segments, and, guess what?
;       I'm outta here!
