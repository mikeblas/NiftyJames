
; Nifty James' Famous Disk Parker

; Version 1.00 of June 11, 1988 

; (C) Copyright 1988 by Mike Blaszczak
; All rights reserved.

lf	equ	10
cr	equ	13

Devices	equ	008h
Seek	equ	00Ch

ReadChar	equ	001h
WriteChar	equ	002h
Write	equ	040h

DISKINT	equ	013h
DOSINT	equ	021h


	.stack	256

	.model	small
	.data

Banner	db	"Nifty James' Disk Parker",cr,lf
	db	"(C) Copyright 1988 by Mike Blaszczak",cr,lf
	db	"All Rights Reserved",cr,lf
	db	"Version 1.00 of 15 June 1988",cr,lf,lf
BannerLen	equ	this byte - Banner

NoDrives	db	"No hard disk drives installed!",cr,lf,lf
NoDrivesLen	equ	this byte - NoDrives

Parking	db	"Parking disk unit "
ParkingLen	equ	this byte - Parking

ToCluster	db	" at cylinder "
ToClusterLen	equ	this byte - ToCluster

EndOfSentence	db	".",cr,lf
EndOfSentenceLen	equ	this byte - EndOfSentence

Done	db	cr,lf,"Heads Parked!  Press any key to",cr,lf
	db	"return to DOS, or shut down system now."
DoneLen	equ	this byte - Done

NumberBuffer	db	10 dup (' ')

DriveNumber	db	080h
DriveCount	db	0
CylinderSector	dw	0

	.code

Beginning:
	push	ds
	mov	ax,@data
	mov	ds,ax

	mov	ah,Write
	mov	cx,BannerLen
	mov	bx,1
	mov	dx,offset Banner
	int	DOSINT

	mov	ah,Devices
	mov	dl,080h
	int	DISKINT

	and	dl,dl		; any drives?
	jne	HasDrives

	mov	ah,Write
	mov	cx,NoDrivesLen
	mov	bx,1
	mov	dx,offset NoDrives
	int	DOSINT

BadExit:
	mov	ax,04C01h
	int	DOSINT


HasDrives:	mov	DriveCount,dl

NextDrive:	mov	ah,Devices
	mov	dl,DriveNumber
	int	DISKINT

NextBunch:	add	ch,8
	jnc	NoCarryCylinder
	add	cl,001000000b
	mov	ch,0

NoCarryCylinder:
	mov	CylinderSector,cx

	mov	ah,Seek
	mov	dl,DriveNumber
	mov	dh,0
	int	DISKINT

	mov	ah,Write
	mov	cx,ParkingLen
	mov	dx,offset Parking
	mov	bx,1
	int	DOSINT

	mov	al,DriveNumber
	and	ax,007Fh
	call	PrintInt

	mov	ah,Write
	mov	cx,ToClusterLen
	mov	dx,offset ToCluster
	mov	bx,1
	int	DOSINT

	mov	ax,CylinderSector
	and	al,011000000b
	mov	cl,6
	shr	al,cl
	xchg	al,ah
	call	PrintInt

	mov	ah,Write
	mov	cx,EndOfSentenceLen
	mov	dx,offset EndOfSentence
	mov	bx,1
	int	DOSINT

	inc	DriveNumber
	dec	DriveCount
	jne	NextDrive

	mov	ah,Write
	mov	cx,DoneLen
	mov	dx,offset Done
	mov	bx,1
	int	DOSINT

	mov	ah,ReadChar
	int	DOSINT

GoodExit:
	mov	ax,04C00h
	int	DOSINT



PrintInt	proc

	mov	dx,ax
	xor	cx,cx
	mov	di,offset NumberBuffer

PrintInt_1:	push	cx
	mov	ax,dx
	xor	dx,dx
	mov	cx,10
	div	cx
	xchg	ax,dx

	add	al,'0'
	mov	[di],al
	inc	di

	pop	cx
	inc	cx
	and	dx,dx
	jne	PrintInt_1

PrintInt_2:
	dec	di
	mov	dl,[di]
	mov	ah,WriteChar
	int	DOSINT
	loop	PrintInt_2

	ret

PrintInt	endp

	end	Beginning



