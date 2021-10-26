

; NJCHIME.ASM

; Nifty James' Famous Chimer Program
; Version 1.00 of 31 June 1988
 
; (C) Copyright 1988 by Mike "Nifty James" Blaszczak
; All Rights Reserved


;	ASCII codes

tab	equ	9
lf	equ	10		; linefeed
cr	equ	13		; carriage return
slash	equ	'/'		; slash
dash	equ	'-'		; minus
eos	equ	'$'		; end of string

;	DOS Interrupt Functions

PrintString	equ	009h		; print a '$'-terminated string
SetVec	equ	025h		; set an interrupt vector
GetTime	equ	02Ch		; get the system time
KeepProc           equ	031h            ; keep this process resident
GetVec	equ	035h		; get an interrupt vector
WriteHandle	equ	040h		; Write to a handle or device
Terminate	equ	04Ch		; exit with ERRORLEVEL

;	Interrupt Numbers

ClockTick	equ	01Ch
DOSINT	equ	021h

;	I/O Port Numbers

TimerPort	equ	042h		; 8253 timer data latch port
TimerCtrl	equ	043h		; 8253 timer control port
SpeakerPort	equ	061h
SpkrMaskOff	equ	011111100b	; Maks to turn speaker off
SpkrMaskOn	equ	000000011b	; Mask to turn speaker on

;	General Constants

BongTime	equ	15		; bong 5/6 ths of a second
BongRest	equ	15		; rest 5/6 ths between each bong

Middle_C	equ	2280
Treble_D	equ	2032
Treble_E	equ	1810
Treble_F	equ	1708
Treble_G	equ	1522
Treble_A	equ	1356
Treble_B	equ	1208
Upper_C	equ	1140
Upper_D	equ	1016
Upper_E	equ	905
Upper_F	equ	854


code	segment	para public 'CODE'
	assume es:nothing, ds:nothing, ss:nothing, cs:code

	org	100h
OfTheWorldAsWeKnowIt:
	jmp	OverResident

	dw	156 dup (0)
	dw	0
	dw	0
	dw	0	; padding
	dw	0

t_hours	db	?
t_minutes	db	?
t_ticks	dw	?

TicksMinute	equ	1092	; (18.2*60)
Ticks57Seconds	equ	1026	; (18.2*57)

Resting	db	0
RestDuration	db	0

Bonging	db	0
BongCount	db	0
BongResting	db	0
BongDuration	db	0

Playing	db	0
Duration	db	0

NotePointer	dw	0

Pacing	db	0

WorkCount	db	0	; length of this note
Working	db	0	; set to one if we are playing a note
Selection	db	0	; which chimeset we're playing

QuarterOffset	dw	0
HalfOffset	dw	0
ThreesOffset	dw	0
HourOffset	dw	0


OldTimerVec	label	dword	; the old tick vector
OldTimerVecO	dw	?
OldTimerVecS	dw	?

	assume	cs:code, ds:nothing, es:nothing, ss:nothing
	dw	'NJ'			; signature
Handler:
	pushf
	push	ax
	push	bx
	push	cx

	push	ds
	push	cs
	pop	ds

	assume	cs:code, ds:code, es:nothing, ss:nothing

	mov	ax,t_ticks	; increment our divide by 18 count
	inc	ax
	cmp	ax,TicksMinute
	mov	t_ticks,ax
	jne	FallOut		; if it's not 18, return

	xor	ax,ax		; zero the eighteen count
	mov	t_ticks,ax

FixMinutes:	mov	al,t_minutes	; increment minutes
	inc	al
	mov	t_minutes,al	; is it 60 minutes?
	cmp	al,60
	jne	FallOut		; nope, skip all that

	xor	al,al

	mov	t_minutes,al
	inc	t_hours

; ---------------------------------------------------------------------------

FallOut:	mov	al,Playing	; are we playing a note?
	and	al,al
	je	NotPlaying

	dec	Duration	; decrement the duration
	je	NoteOver

ReturnHome:	pop	ds
	pop	cx
	pop	bx
	pop	ax
	popf
	jmp	cs:[OldTimerVec]

NoteOver:	in	al,SpeakerPort	; stop the speaker, the note is done
	and	al,SpkrMaskOff
	out	SpeakerPort,al

	mov	al,1
	mov	Resting,al	; set resting flag
	dec	al
	mov	Playing,al	; reset note-playing flag
	jmp	short ReturnHome

NotPlaying:	mov	al,Resting	; check and see if we're playing
	and	al,al		;	a rest
	jne	WereResting
	jmp	NotResting

WereResting:	dec	RestDuration	; decrement the rest duration
	jne	ReturnHome

	push	si
	mov	ax,NotePointer
	mov	si,ax
	add	ax,4
	mov	NotePointer,ax	; increment the note pointer - store it
	mov	ax,[si]		; get this note

	cmp	ax,0FFFFh	; is it the last one?
	je	GotLastNote

	out	TimerPort,al
	xchg	ah,al
	out	TimerPort,al	; set the frequency

	in	al,SpeakerPort
	or	al,SpkrMaskOn
	out	SpeakerPort,al	; set the speaker on

	add	si,2		; get the note duration
	mov	ax,[si]		;  and rest duration
	mov	Duration,al
	mov	RestDuration,ah
	pop	si		; restore old SI

	mov	al,1
	mov	Playing,al	; turn Playing on
	dec	al		; turn Resting off
	mov	Resting,al
WayBackHome:	jmp	short ReturnHome	; and boogie


GotLastNote:	pop	si		; restore SI register

	mov	al,0
	mov	Playing,al
	mov	Resting,al	; neither playing nor resting

	mov	al,Selection	; are we just chirping?
	and	al,al
	je	ReturnHome	; yes ... don't bong

	mov	al,t_minutes
	mov	ah,1		; one bong for the
	cmp	al,30		; half hour?
	je	DoBong
	mov	ah,t_hours	; hour bongs for the
	cmp	ah,12		; adjust it?
	jle	noadjust
	sub	ah,12

noadjust:	and	al,al		; top of hour?
	jne	WayBackHome	; nope ... return home

DoBong:	mov	BongCount,ah	; store the count
DoBongAgain:	mov	ax,5424		; bong at 220Hz
	out	TimerPort,al
	xchg	al,ah
	out	TimerPort,al	; send it to the timer

	in	al,SpeakerPort
	or	al,SpkrMaskOn
	out	SpeakerPort,al	; set the speaker on

	mov	al,BongTime	; bong for 5/6ths of a second
	mov	Bonging,al	; set the bonging flag
	mov	BongDuration,al	; set duration
	mov	al,0
	mov	Playing,al	; turn playing off
	mov	Resting,al	; turn resting off
	jmp	WayBackHome

NotResting:	mov	al,Bonging	; are we bonging?
	and	al,al
	je	NotBonging

	dec	BongDuration
	jne	WayBackHome

	in	al,SpeakerPort
	and	al,SpkrMaskOff
	out	SpeakerPort,al	; turn speaker off

	mov	al,BongRest
	mov	BongResting,al	; setup bong pause length (1/6th)
	mov	BongDuration,al	;set bong pausing

	mov	al,0
	mov	Bonging,al	; set bonging to zero
OnWayBackHome:	jmp	short WayBackHome


NotBonging:	mov	al,BongResting	; are we bong resting?
	and	al,al
	je	NotBongResting

	dec	BongDuration	; decrement duration
	jne	WayBackHome

	mov	al,0		; set bonging flag to zero
	mov	BongResting,al

	dec	BongCount	; decrement the bong count
	jne	DoBongAgain

	mov	al,0
	mov	Bonging,al
	je	OnWayBackHome

NotBongResting:
	mov	ax,t_ticks	; see if we're at a 1 second
	mov	cl,18		; interval
	div	cl
	and	ah,ah		; zero?
	jne	OnWayBackHome

	mov	al,Selection	; see what kind of thing we should do
	and	al,al
	je	Chirping

	mov	ax,t_ticks
	cmp	ax,20		; is it in the first second?
	jge	OnWayBackHome	; nope, get out of here

	mov	al,t_minutes	; get minutes count
	mov	bx,HourOffset
	and	al,al
	je	DoIt

	mov	bx,QuarterOffset
	cmp	al,15
	je	DoIt

	mov	bx,HalfOffset
	cmp	al,30
	je	DoIt

	mov	bx,ThreesOffset
	cmp	al,45
	je	DoIt
	jne	OnWayBackHome

DoIt:	mov	NotePointer,bx
	mov	ah,1
	mov	Playing,ah
	mov	ax,[bx]		; get the note
	out	TimerPort,al
	xchg	al,ah
	out	TimerPort,al	; set up the timing

	add	bx,2
	in	al,SpeakerPort
	or	al,SpkrMaskOn
	out	SpeakerPort,al

	mov	ax,[bx]		; get rest and duration
	add	bx,2
	mov	NotePointer,bx	; but save the note pointer first

	mov	Duration,al
	mov	RestDuration,ah
GetBack:	jmp	ReturnHome


Chirping:	mov	al,t_minutes	; is minutes == 59
	cmp	al,59
	jne	GetBack

	mov	ax,t_ticks
	cmp	ax,Ticks57Seconds
	jne	GetBack

	mov	bx,005Ch
	jmp	DoIt

LastResident:		

; ---------------------------------------------------------------------------

OverResident:
	assume es:code, ds:code, ss:code, cs:code

	mov	dx,offset Banner	; tell 'em who you are
	mov	cx,BannerLen
	call	ShowMessage

	mov	ah,GetVec		; are we already installed?
	mov	al,ClockTick
	int	DOSINT

	assume es:nothing, ds:code, ss:code, cs:code

	mov	OldTimerVecS,es		; save the vector
	mov	OldTimerVecO,bx
	dec	bx
	dec	bx
	cmp	es:[bx],'NJ'
	jne	NotAlready

	mov	dx,offset Already	; already installed, error!
	mov	cx,AlreadyLen
	call	ShowMessage
BadGo:	mov	ah,Terminate
	mov	al,1
	int	DOSINT

NotAlready:	mov	si,080h			; look at the command line

CommLoop:	inc	si
	mov	al,[si]
	cmp	al,cr			; is it end of line?
	je	CommLooped
	cmp	al,slash		; is it an option?
	je	GotOption
	cmp	al,dash
	jne	CommLoop

GotOption:	inc	si
	mov	al,[si]			; get the option char
	cmp	al,cr
	je	CommLooped
	cmp	al,'m'			; is it the mode option?
	je	GotMOption
	cmp	al,'M'
	je	GotMOption

ShowUsage:	mov	dx,offset Usage
	mov	cx,UsageLen
	call	ShowMessage

	mov	ah,Terminate
	mov	al,1
	int	021h

GotMOption:	inc	si			; get parameter
	mov	al,[si]
	cmp	al,cr
	je	CommLooped

	sub	al,'0'
	cmp	al,3
	jg	ShowUsage		; error if it is out of range

	mov	Selection,al
	jmp	CommLoop		; loop back for more



CommLooped:
	mov	ah,GetTime		; Get our copy of the system
	int	DOSINT			; time initialized
	mov	t_hours,ch
       	mov	t_minutes,cl

	mov	al,dh
	mov	ah,0
	mov	cl,18
	mul	cl
	mov	t_ticks,ax

	mov	al,dl			; make hundreths into ticks
                   cbw
	mov	cl,5			; 1 tick = 5 hundreths 
	div	cl
	mov	ah,0
                   add	t_ticks,ax

	mov	ah,SetVec		; set up our int vector
	mov	al,ClockTick
	mov	dx,offset Handler
	int	DOSINT

	mov	dx,offset Installed	; print installed message
	mov	cx,InstalledLen
                   call	ShowMessage

	mov	al,Selection
	cbw
	shl	ax,1
	mov	si,offset ChimePtrs
	add	si,ax
	mov	si,[si]
	mov	di,05Ch
	mov	bx,offset QuarterOffset

BunchLoop:	mov	[bx],di		; save pointer to this one
	inc	bx
	inc	bx

MoveLoop:	mov	ax,[si]
	mov	[di],ax		; move this word
	inc	si
	inc	si		; up pointers
	inc	di
	inc	di

	cmp	ax,0FFFFh	; is it the end of this batch?
	jne	NotTheEnd

	mov	ax,[si]		; see if its the complete end
	and	ax,ax
	je	DoneMoving
	jne	BunchLoop	; nope ... move the next bunch

NotTheEnd:	mov	ax,[si]
	mov	[di],ax		; move the next words
	inc	si
	inc	si
	inc	di
	inc	di
	jne	MoveLoop	; move more
	

DoneMoving:	mov	si,offset SelectionPtrs ; print selection title
	mov	al,Selection
	cbw
	shl	ax,1
	add	si,ax
                   mov	dx,[si]
	mov	ah,PrintString
	int	DOSINT

                   mov	ah,KeepProc             ; now we'll TSR
                   mov	al,0                    ; with no ERRORLEVEL
                   mov	dx,offset LastResident
                   add	dx,15                   ; round size up
                   mov	cl,4
                   shr	dx,cl
                   int	DOSINT

; ---------------------------------------------------------------------------

ShowMessage	proc	near

	push	ax
	push	bx

	mov	ah,WriteHandle		; write it to stdout
	mov	bx,1
	int	DOSINT

                   pop	bx
	pop	ax
	ret
ShowMessage	endp

; ---------------------------------------------------------------------------

Banner	db	lf,"Nifty James' Famous Chimer Program",cr,lf
	db	"Version 1.00 of 30 March 1988",cr,lf
	db	"(C) Copyright 1988 by Mike Blaszczak",cr,lf
BannerLen	equ	this byte - Banner

Already	db	lf,"NJCHIME was already installed!",cr,lf
AlreadyLen	equ	this byte - Already

Installed	db	lf,"NJCHIME has been installed to play "
InstalledLen	equ	this byte - Installed

Usage	db	cr,lf,"Usage:",cr,lf
	db	tab,"NJCHIME [/M<mode>]",cr,lf,lf
	db	tab,"Mode is the chime to be played.",cr,lf,lf
	db	tab,"Mode 0 - Time Tones (default)",cr,lf
	db	tab,"Mode 1 - Westminster Chimes",cr,lf
	db	tab,"Mode 2 - Saint Michael Chimes",cr,lf
	db	tab,"Mode 3 - Whittington Chimes",cr,lf,lf
UsageLen	equ	this byte - Usage

SelectionPtrs	dw	offset	TimeTones
	dw	offset	Westminster
	dw	offset	StMichael
	dw	offset	Whittington

ChimePtrs	dw	offset	TimerChime
	dw	offset	WestMinsterChime
	dw	offset	SaintMichaelChime
	dw	offset	WhittingtonChime

TimeTones	db	"Time Tones.",cr,lf,eos
Westminster	db	"Westminster Chimes.",cr,lf,eos
StMichael	db	"Saint Michael's Chimes.",cr,lf,eos
Whittington	db	"Whittington Chimes.",cr,lf,eos

NoteStruc	struc
	divisor	dw	?
	duration	db	?
	intrarest	db	?
NoteStruc	ends

TimerChime	NoteStruc	<0254h, 3, 15>
	NoteStruc	<0254h, 3, 15>
	NoteStruc	<0254h, 3, 15>
	NoteStruc	<04A8h, 10, 8>
	dw		0FFFFh
	dw		00000h

WestMinsterChime	NoteStruc	<Upper_E,14, 4>
	NoteStruc	<Upper_D,14, 4>
	NoteStruc	<Upper_C,14, 4>
	NoteStruc	<Treble_G,14, 2>
	dw		0FFFFh
	NoteStruc	<Upper_C,14, 4>
	NoteStruc	<Upper_E,14, 4>
	NoteStruc	<Upper_D,14, 4>
	NoteStruc	<Treble_G,14, 4>
	NoteStruc	<Upper_C,14, 4>
	NoteStruc	<Upper_D,14, 4>
	NoteStruc	<Upper_E,14, 4>
	NoteStruc	<Upper_C,14, 4>
	dw		0FFFFh
	NoteStruc	<Treble_E,14, 4>
	NoteStruc	<Upper_C,14, 4>
	NoteStruc	<Upper_D,14, 4>
	NoteStruc	<Treble_G,14, 4>
	NoteStruc	<Treble_G,14, 4>
	NoteStruc	<Upper_D,14, 4>
	NoteStruc	<Upper_E,14, 4>
	NoteStruc	<Upper_C,14, 4>
	NoteStruc	<Upper_D,14, 4>
	NoteStruc	<Upper_C,14, 4>
	NoteStruc	<Treble_B,14, 4>
	NoteStruc	<Treble_G,14, 4>
	dw		0FFFFh
	NoteStruc	<Upper_C,14, 4>
	NoteStruc	<Upper_E,14, 4>
	NoteStruc	<Upper_D,14, 4>
	NoteStruc	<Treble_G,14, 4>
	NoteStruc	<Upper_C,14, 4>
	NoteStruc	<Upper_D,14, 4>
	NoteStruc	<Upper_E,14, 4>
	NoteStruc	<Upper_C,14, 4>
	NoteStruc	<Upper_E,14, 4>
	NoteStruc	<Upper_C,14, 4>
	NoteStruc	<Upper_D,14, 4>
	NoteStruc	<Treble_G,14, 4>
	NoteStruc	<Treble_G,14, 4>
	NoteStruc	<Upper_D,14, 4>
	NoteStruc	<Upper_E,14, 4>
	NoteStruc	<Upper_C,14, 4>
	dw		0FFFFh
	dw		00000h


SaintMichaelChime	NoteStruc	<Upper_F, 7, 2>
	NoteStruc	<Upper_E , 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Treble_F, 7, 2>
	dw		0FFFFh
	NoteStruc	<Upper_F , 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Upper_E , 7, 2>
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Treble_F, 7, 2>	;
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Upper_E , 7, 2>
	NoteStruc	<Upper_F , 7, 2>
	NoteStruc	<Treble_F, 7, 2>	;
	dw		0FFFFh
	NoteStruc	<Upper_E , 7, 2>
	NoteStruc	<Upper_F , 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Treble_F, 7, 2>	;
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Upper_E , 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Treble_F, 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Treble_F, 7, 2>	;
	NoteStruc	<Upper_F , 7, 2>
	NoteStruc	<Upper_E , 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Treble_F, 7, 2>	;
	dw		0FFFFh
	NoteStruc	<Upper_F , 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Upper_E , 7, 2>
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Treble_F, 7, 2>	;
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Upper_E , 7, 2>
	NoteStruc	<Upper_F , 7, 2>
	NoteStruc	<Treble_F, 7, 2>	;
	NoteStruc	<Upper_E , 7, 2>
	NoteStruc	<Upper_F , 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Treble_F, 7, 2>	;
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Upper_E , 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Treble_F, 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Treble_F, 7, 2>	;
	dw		0FFFFh
	dw		00000h

WhittingtonChime	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Treble_A, 7, 2>	;
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Treble_F, 7, 2>
	NoteStruc	<Treble_E, 7, 2>
	NoteStruc	<Treble_D, 7, 2>
	dw		0FFFFh
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Treble_E, 7, 2>	;
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Treble_F, 7, 2>
	NoteStruc	<Treble_D, 7, 2>	;
	NoteStruc	<Treble_E, 7, 2>
	NoteStruc	<Treble_F, 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Treble_B, 7, 2>	;
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Treble_D, 7, 2>
	dw		0FFFFh
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Treble_E, 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Treble_F, 7, 2>
	NoteStruc	<Treble_D, 7, 2>
	NoteStruc	<Treble_E, 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Treble_F, 7, 2>
	NoteStruc	<Treble_D, 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Treble_A, 7, 2>	;
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Treble_F, 7, 2>
	NoteStruc	<Treble_E, 7, 2>
	NoteStruc	<Treble_D, 7, 2>
	dw		0FFFFh
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Treble_E, 7, 2>	;
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Treble_F, 7, 2>
	NoteStruc	<Treble_D, 7, 2>	;
	NoteStruc	<Treble_E, 7, 2>
	NoteStruc	<Treble_F, 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Treble_B, 7, 2>	;
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Treble_D, 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Treble_E, 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Treble_F, 7, 2>
	NoteStruc	<Treble_D, 7, 2>
	NoteStruc	<Treble_E, 7, 2>
	NoteStruc	<Treble_G, 7, 2>
	NoteStruc	<Treble_B, 7, 2>
	NoteStruc	<Upper_D , 7, 2>
	NoteStruc	<Upper_C , 7, 2>
	NoteStruc	<Treble_A, 7, 2>
	NoteStruc	<Treble_F, 7, 2>
	NoteStruc	<Treble_D, 7, 2>
	dw		0FFFFh
	dw		00000h

code	ends
	end	OfTheWorldAsWeKnowIt



