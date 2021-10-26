/*  dumptwo.c	*/

#include <stdio.h>
#include <string.h>
#include <mytypes.h>
#include "njdump.h"

/* ----------------------------------------------------------------------- */

		/* return the minimum of two integers	*/

int min(a, b)
int a,b;

{
	if(a<b)
		return(a);
	else
		return(b);
}

/* ----------------------------------------------------------------------- */

		/*	handle a comment record		*/

void docommentrec()
{
	int len1, len2, lent;

	char rcomment[80];

	writeheader();
	lent = getlen();

	len1 = fgetc(infile);
	len2 = fgetc(infile);

	if (len1 & 0x80)
		printf("non");
	printf("purgable, ");

	if (len1 & 0x40)
		printf("non");
	printf("listable, ");

	printf("comment class = %d\n", len2);
	checksum += len1 + len2;

	fread(rcomment, sizeof(char), lent-3, infile);
	rcomment[lent-3] = '\0';

	for (len1=0; len1 < (lent-3); len1++)
		checksum += rcomment[len1];

	printf("\t\t\t\t\tcomment = \"%s\"\n", rcomment);

	checkit();
	return;
}

/* ----------------------------------------------------------------------- */

void dofixupprec()
{		/*  handle fixupp records	*/

	int lent, d, z, method, thred, frame, target;
	int trddat, loc, doffset, fixdat;
	unsigned locat, ifn, f;
	int m, s;

	writeheader();
	lent = getlen();

	while (lent > 1)
	{
		trddat = fgetc(infile);	checksum += trddat; lent--;
		if((trddat & 0x80) == 0)
		{	/* thread method	*/

			z = (trddat & 0x20) >> 5;
			method = (trddat & 0x1C) >> 2;
			thred = (trddat & 0x03);

			if (trddat & 0x40 == 0x40)
				printf("frame thread F");
			else
				printf("target thread T");

			printf("%d\n", method);

			if(method < 4  ||  method > 6)
			{
				ifn = getuw();	lent -= 2;
				printf("\t\t\t\t\t");
				if(trddat & 0x40 == 0x40)
					printf("frame = %4.4X\n", ifn);
				else
					printf("thread = %4.4X\n", ifn);
			}
		}
		else	{
			locat = fgetc(infile);  lent--;
			checksum += locat;  locat = locat + 256*trddat;

			doffset = locat & 0x03FF;
			loc = (trddat & 0x1C) >> 2;
			m = (trddat & 0x40) >> 6;
			s = (trddat & 0x20) >> 5;

			switch (loc) {
			case	0:	printf("lobyte   ");
					break;
			case	1:	printf("offset   ");
					break;
			case	2:	printf("base     ");
					break;
			case	3:	printf("pointer  ");
					break;
			case	4:	printf("hibyte   ");
					break;
			  default:	printf("invalid loc  ");
			}
	
			if (m)
				printf("segment");
			else
				printf("self");
			printf(" relative\n\t\t\t\t\t");
			lent--;
			fixdat = fgetc(infile);	checksum += fixdat;
			frame = (fixdat & 0x70) >> 4;
			target = (fixdat & 0x03);
			printf("frame = %2.2X,  target = %2.2X\n\t\t\t\t\t", frame, target);
			printf("data record offset = %4.4X\n", doffset);

			if ((fixdat & 0x80) == 0)	{
				f = fgetc(infile);	lent--;
				checksum += f;
				printf("\t\t\t\t\tframe datum = %2d\n", f);
			}

			if ((fixdat & 0x08) == 0)	{
				f = fgetc(infile);	lent--;
				checksum += f;
				printf("\t\t\t\t\ttarget datum = %2d\n", f);
			}

			if ((fixdat & 0x04) == 0)	{
				f = getuw();	lent -= 2;
				if (s == 1)	{
					s = fgetc(infile); lent--;
					f = f*256 + s;  checksum += s;
				}
				printf("\t\t\t\t\ttarget displacement = %6.6X\n", f);
			}
		}
		if (lent>1)	printf("\t\t\t\t    ");
	}

	checkit();
	return;
}

/* ----------------------------------------------------------------------- */

void domodend()
{
	int mattr, ell, modtyp, b1, b2;
	int enddat, f, t, p, s, frame, target;

	writeheader();
	getlen();

	modtyp = fgetc(infile);		checksum += modtyp;
	mattr = (modtyp >> 6);
	ell = modtyp & 1;

	printf("mod typ = ");

	if ((mattr && 2) == 0)
		printf("non-");
	printf("main module, ");

	if ((mattr && 1) == 0)
		printf("no ");
	puts("START ADDRS.");

	if ((mattr && 1) == 1)	{
		if(ell == 0)	{
			b1 = fgetc(infile), b2 = fgetc(infile);
			checksum += b1+b2;
			printf("\t\t\t\t\tStart Address (CS:IP) = %4.4X:", b1 + b2*256);
			b1 = fgetc(infile), b2 = fgetc(infile);
			checksum += b1+b2;
			printf("%4.4X\n", b1 + b2*256);
		}
		else	{
			enddat = fgetc(infile);	checksum += enddat;
			frame = (enddat & 0x70) >> 4;
			target = (enddat & 0x03);
			printf("frame = %2.2X,  target = %2.2X\n\t\t\t\t\t", frame, target);

			if ((enddat & 0x80) == 0)	{
				f = fgetc(infile);
				checksum += f;
				printf("\t\t\t\t\tframe datum = %2d\n", f);
			}

			if ((enddat & 0x08) == 0)	{
				f = fgetc(infile);
				checksum += f;
				printf("\t\t\t\t\ttarget datum = %2d\n", f);
			}

			if ((enddat & 0x04) == 0)	{
				f = getuw();
				if (s == 1)	{
					s = fgetc(infile);
					f = f*256 + s;  checksum += s;
				}
				printf("\t\t\t\t\ttarget displacement = %6.6X\n", f);
			}
		}
	}
	checkit();
	return;
}


/* ----------------------------------------------------------------------- */

		/* handle LHEADER and THEADER types	*/

void donamerecord()
{
	int len1, len2, lent;

	char rnam[80];

	writeheader();
	lent = getlen();

	len1 = fgetc(infile);  checksum += len1;

	fread(rnam, sizeof(char), len1, infile);

	rnam[len1] = '\0';

	for(len2=0; len1 != len2; len2++)
		checksum += rnam[len2];

	printf("name = \"%s\"\n", rnam);

	checkit();
	return;
}

/* ----------------------------------------------------------------------- */

		/* move count from source to dest, replacing nonprintable
			ASCII characters with '.'			*/

void bumpover(source, dest, count)
byte *source, *dest;
int count;
{
	byte *s, *d;
	int c;

	s = source;
	d = dest;

	for(c=1; c<=count; c++)
		if (*s<32 || *s>127)
			*d++ = '.', s++;
		else
			*d++ = *s++;

	*d = '\0';
	return;
}

/* ----------------------------------------------------------------------- */

		/*  read, format, and print out grpdix, segidx,
			and frameno if present			*/

int	doidx()
{
	int	grpidx, segidx, frameno;
	int	rval;

	rval = 0;

	grpidx = fgetc(infile);		checksum += grpidx;
	segidx = fgetc(infile);		checksum += segidx;

	if(grpidx == 0 && segidx == 0)
	{
		frameno = fgetc(infile);
		rval=1;	checksum += frameno;
	}

	if (grpidx != 0)
		printf("grppidx = \"%s\", ", namelist[grpidx]);

	if (segidx != 0)
		printf("segidx = \"%s\"", seglist[segidx]);

	if(segidx == 0 && grpidx == 0)
	{
		frameno = fgetc(infile); 
		checksum += frameno;
		printf("frame = %2d", frameno);
	}
	return(rval);
}

/* ----------------------------------------------------------------------- */

		/*  format and print out datlength bytes from the infile  */

void dodata(datlength)
int datlength;
{
	byte blockbuff[16], asciibuff[17];
	int	n, length, bsize;

	length = datlength;

	while(length>0)
	{
		bsize = min(16, length);
		length -= bsize;

		fread(blockbuff, sizeof(byte), bsize, infile);

		bumpover(blockbuff, asciibuff, bsize);
		printf("\n\t%-16s   ", asciibuff);

		for(n=0; n<bsize; n++)
		{
			checksum += blockbuff[n];
			printf("%2.2X", blockbuff[n]);
			if (n == 7 && bsize != 8)
				putchar('-');
			if(n != 15 && n != 7)
				putchar(' ');
		}
	}
	putchar('\n');
	return;
}

/* ----------------------------------------------------------------------- */

		/*  handle REDATA	*/

void doredata()
{
	int		tlen;
	unsigned	doffset;

	writeheader();			/* print out offset and rectype	*/

	tlen = getlen()-2;		/* get length	*/
	tlen -= doidx();		/* do the group index, segment index,
						and frame number	*/

	doffset = getuw();
	printf("\t\t\t\toffset = %4.4X\n", doffset);

	dodata(tlen);			/* print out data	*/

	putchar('\n');
	checkit();			/* do checksum and return	*/
	return;	
}

/* ----------------------------------------------------------------------- */

		/* handle LEDATA records	*/

void doledata()
{
	int lent, segidx, oset, n;

	int bsize;

	writeheader();
	lent = getlen()-4;

	segidx = fgetc(infile);
	oset = getuw();
	checksum += segidx;

	printf("seg = \"%s\", offset = %4.4X", seglist[segidx], oset);

	dodata(lent);
	
	putchar('\n');
	checkit();
	return;
}

/* ----------------------------------------------------------------------- */

	/*	handle external declarations	*/

void doextdef()
{
	int	lent, extnamelen, idx, typidx1, typidx2;
	char	extname[255];

	writeheader();
	lent = getlen()-2;

	while(lent>1)
	{
		extnamelen = fgetc(infile);	checksum += extnamelen;
		fread(extname, sizeof(char), extnamelen, infile);

		for(idx = 0; idx < extnamelen; idx++)
			checksum += extname[idx];

		extname[extnamelen] = '\0';	lent -= extnamelen+1;

		typidx1 = fgetc(infile);
		if (typidx1 > 127)
		{
			typidx2 = fgetc(infile);
			lent--; checksum += typidx2;
		}
		checksum += typidx1;	lent--;

		printf("\"%s\"\t", extname);

		if (extnamelen < 10)
			putchar('\t');

		printf("typidx = %d", typidx1);
		if (typidx1 > 127)
			printf("/%d", typidx2);

		printf("\n\t\t\t\t    ");
	}

	putchar('\n');
	checkit();
	return;
}

/* ----------------------------------------------------------------------- */

	/*	handle public definitions		*/

void dopubdef()
{
	int	grpidx, segidx, framenumber;
	unsigned	puboffset;
	int	lent, pubnamelen, idx, typidx1, typidx2;
	char	pubname[255];

	writeheader();
	lent = getlen()-2;

	lent -= doidx();		/*  get index and frame values	*/

	while(lent>1)
	{
		printf("\n\t\t\t");
		pubnamelen = fgetc(infile);	checksum += pubnamelen;
		fread(pubname, sizeof(char), pubnamelen, infile);

		for(idx = 0; idx < pubnamelen; idx++)
			checksum += pubname[idx];

		pubname[pubnamelen] = '\0';	lent -= pubnamelen+1;

		puboffset = getuw();	lent -= 3;
		typidx1 = fgetc(infile);
		if (typidx1 > 127)
		{
			typidx2 = fgetc(infile);
			lent--; checksum += typidx2;
		}
		checksum += typidx1;

		printf("symbol \"%s\", puboffset = %4.4X, ", pubname, puboffset);

		if (pubnamelen > 10)
			printf("\n\t\t\t\t");

		printf("typidx = %d", typidx1);
		if (typidx1 > 127)
			printf("/%d", typidx2);
	}

	putchar('\n');
	checkit();
	return;
}

/* ----------------------------------------------------------------------- */

	/*	handle a LINNUM record type ... print out line numbers	*/

void dolinnum()
{
	int	grpidx, segidx, framenumber;
	unsigned   lineno, lineoffset;
	int	lent, col;

	writeheader();
	lent = getlen()-2;

	grpidx = fgetc(infile);  checksum += grpidx;
	segidx = fgetc(infile);	 checksum += segidx;

	if (grpidx != 0)
		printf("grppidx = \"%s\", ", namelist[grpidx]);

	if (segidx != 0)
		printf("segidx = \"%s\"", seglist[segidx]);

	if(segidx == 0 && grpidx == 0)
	{
		framenumber = fgetc(infile); 
		checksum += framenumber;
		printf("frame = %2d", framenumber);
	}

	printf("\n\t\t\t");
	col = 0;

	while(lent > 1)
	{
		if(col == 2)
		{
			printf("\n\t\t\t");
			col = 1;
		}
		else
			col++;

		lineno = getuw(); lent -= 2;
		lineoffset = getuw(); lent -= 2;

		printf("line %5d at %4.4X\t", lineno, lineoffset);

	}

	putchar('\n');

	checkit();
	return;
}
