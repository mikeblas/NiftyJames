

	.model small

	.data


save_ss	dw	?
save_sp	dw	?

	.code

	public	_int_2E

_int_2E	proc	near

	push	bp
	mov	bp,sp
	push	si
	push	di
	push	ds
	push	es

	mov	ax,DGROUP
	mov	ds,ax		; set up DS

	mov	save_sp,sp
	mov	save_ss,ss

	mov	si,[bp+4]	; set up si

	int	02Eh

	mov	ax,DGROUP
	mov	ds,ax

	cli
	mov	sp,save_sp
	mov	ss,save_ss
	sti

	pop	es
	pop	ds
	pop	di
	pop	si
	pop	bp

	mov	ax,0		; check for carry return
	jc	_int_2E_exit

	mov	ax,-1

_int_2E_exit:	ret

_int_2E	endp
	end



