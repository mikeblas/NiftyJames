
/***************************************************************************
 * 									   *
 *  NJDUMP  -  Nifty James' .OBJ module utility				   *
 *									   *
 *  Displays the format and contents of .OBJ and .LIB files.		   *
 *									   *
 *  (C) Copyright 1987 by Mike Blaszczak.  All rights reserved.  	   *
 *  	Written under Microsoft C Version 4.00.				   *
 *									   *
 **************************************************************************/

#include <stdio.h>
#include <process.h>
#include <string.h>
#include <io.h>
#include <malloc.h>
#include <mytypes.h>
#include <njlib.h>

/* .OBJ record types	*/

struct indexes {
		byte	segni, clani, oni;
};

struct {
		char		name[7];
		int		id;
		unsigned	times;

} rectypes[] = {  

   { "RHEADR",  0x6E, 0 }, { "REGINT",  0x70, 0 },{ "REDATA",  0x72, 0 },
   { "RIDATA",  0x74, 0 }, { "OVLDEF",  0x76, 0 }, { "ENDREC",  0x78, 0 },
   { "BLKDEF",  0x7A, 0 }, { "BLKEND",  0x7C, 0 }, { "DEBSYM",  0x7E, 0 },
   { "THEADR",  0x80, 0 }, { "LHEADR",  0x82, 0 }, { "PEDATA",  0x84, 0 },
   { "PIDATA",  0x86, 0 }, { "COMENT",  0x88, 0 }, { "MODEND",  0x8A, 0 },
   { "EXTDEF",  0x8C, 0 }, { "TYPDEF",  0x8E, 0 }, { "PUBDEF",  0x90, 0 },
   { "LOCSYM",  0x92, 0 }, { "LINNUM",  0x94, 0 }, { "LNAMES",  0x96, 0 },
   { "SEGDEF",  0x98, 0 }, { "GRPDEF",  0x9A, 0 }, { "FIXUPP",  0x9C, 0 },
   { "LEDATA",  0xA0, 0 }, { "LIDATA",  0xA2, 0 }, { "LIBHED",  0xA4, 0 },
   { "LIBNAM",  0xA6, 0 }, { "LIBLOC",  0xA8, 0 }, { "LIBDIC",  0xAA, 0 },
   { "unknow",  0xFF, 0  }
};

extern void doextdef(void);			/* defined in DUMPTWO.C    */
extern void doredata(void);			/* defined in DUMPTWO.C    */
extern void dopubdef(void);			/* defined in DUMPTWO.C    */
extern void dolinnum(void);
extern void docommentrec(void);
extern void domodend(void);			/* defined in DUMPTWO.C    */
extern void donamerecord(void);
extern int min(int, int);
extern void dofixupprec(void);			/* defined in DUMPTWO.C    */
extern void doledata(void);			/* defined in DUMPTWO.C    */

extern void doendrec(void);			/* defined in DUMPTHRE.C   */

#define rtRHEADR	0x6E
#define rtREGINT	0x70
#define rtREDATA	0x72	/* dumptwo.c	*/
#define rtRIDATA	0x74
#define rtOVLDEF	0x76
#define rtENDREC	0x78	/* dumpthre.c	*/
#define rtBLKDEF	0x7A
#define rtBLKEND	0x7C
#define rtDEBSYM	0x7E
#define	rtTHEADR	0x80	/* dumptwo.c	*/
#define rtLHEADR	0x82	/* dumptwo.c	*/
#define rtPEDATA	0x84
#define rtPIDATA	0x86
#define rtCOMENT	0x88	/* dumptwo.c	*/
#define rtMODEND	0x8A	/* dumptwo.c	*/
#define rtEXTDEF	0x8C	/* dumptwo.c	*/
#define rtTYPDEF	0x8E
#define rtPUBDEF	0x90	/* dumptwo.c	*/
#define rtLOCSYM	0x92
#define rtLINNUM	0x94	/* dumptwo.c	*/
#define rtLNAMES	0x96	/* njdump.c	*/
#define rtSEGDEF	0x98	/* njdump.c	*/
#define rtGRPDEF	0x9A	/* njdump.c	*/
#define rtFIXUPP	0x9C	/* dumptwo.c	*/
#define rtLEDATA	0xA0	/* dumptwo.c	*/
#define rtLIDATA	0xA2

/* .LIB record types	*/

#define rtLIBHED	0xA4
#define rtLIBNAM	0xA6
#define	rtLIBLOC	0xA8
#define rtLIBDIC	0xAA


FILE *infile;		/* input file buffer		*/
char infilename[64];	/* input file name		*/
char tempname[64];	/* temporary input file name	*/

int crectype;		/* current record type		*/
unsigned int checksum;	/* checksum of this record	*/
unsigned long crecord;	/* record number		*/
boolean	working;	/* TRUE if loop should continue, FALSE if not	*/

char *namelist[1024];	/* list of names	*/
int topname =1;		/* top name on the list	*/

char *seglist[1024];	/* list of segments	*/
int topseg =1;

/* ----------------------------------------------------------------------- */

void writeheader()
{
	register int i, j;

	printf("\n%6lu  ", crecord);
	printf("%10.10lX   ", lseek(fileno(infile), 0L, SEEK_CUR)-(infile->_cnt)-1 );

	for(j=0, i=0; rectypes[i].id != 0xFF; i++)
		if(rectypes[i].id == crectype)
			j = i;

	if (j == 0)
		printf("%4.2X unknown   ", crectype);
	else
	{
		rectypes[j].times++;
		printf("%4.2X  %s   ", crectype, rectypes[j].name);
	}

	return;
}

/* ----------------------------------------------------------------------- */
int getlen()
{
	int mylen1, mylen2;

	mylen1 = fgetc(infile), mylen2 = fgetc(infile);
	checksum += mylen1+mylen2;
	return (mylen1 + mylen2*256);
}

/* ----------------------------------------------------------------------- */

void checkit()
{
	byte value, actual;

	value = (char) (checksum & 0x00FF);	/* truncate to one byte	*/
	value = (~value)+1;
	actual = (byte) fgetc(infile);
	if (value != actual)
	{
		puts("***** checksum mismatch");
		printf("\tcomputed %d\tactual   %d\n", value, actual);
	}
	return;
}

/* ----------------------------------------------------------------------- */

void skiprecord()
{
	/* this procedure skips over the current record (and prints
		a message to that effect	*/

	unsigned int skipbytes;

	writeheader();
	skipbytes = fgetc(infile) + fgetc(infile)*256;
	printf("skipping over %u bytes\n", skipbytes);
	fseek(infile, (long) skipbytes, SEEK_CUR);
	return;
}

/* ----------------------------------------------------------------------- */

unsigned getuw()
{
	/* gets an unsigned word from the file	*/

	unsigned int b1, b2;

	b1 = fgetc(infile), b2 = fgetc(infile);
	checksum += b1+b2;

	return(b1+b2*256);
}

/* ----------------------------------------------------------------------- */

int getsw()
{
	/* gets a signed word from the file	*/

	int b1, b2;
	b1 = fgetc(infile), b2 = fgetc(infile);
	checksum += b1+b2;

	return(b1+b2*256);
}

/* ----------------------------------------------------------------------- */

void dogrpdef()
{
	int tlen, type, segidx, extidx, claidx, ovlidx, ltl;
	unsigned mglen, glen, framenumber;

	writeheader();
	tlen = getlen()-2;

	segidx = fgetc(infile);
	checksum += segidx;

	printf("Group name = \"%s\"\n", namelist[segidx]);
	

	while(tlen>0)
	{
		printf("\t\t\t\t\t");

		type = fgetc(infile);  checksum += type;  tlen--;
	
		switch (type)	{
			case 0xFF :	segidx = fgetc(infile);
					checksum += segidx;	tlen--;
					printf("segment = \"%s\"\n", seglist[segidx-1]);
					break;

			case 0xFE :	extidx = fgetc(infile);
					checksum += extidx;	tlen--;
					printf("external = \"%s\"\n", namelist[extidx]);
					break;
	
			case 0xFD :	segidx = fgetc(infile);
					extidx = fgetc(infile);
					ovlidx = fgetc(infile);
					checksum += segidx+extidx+ovlidx;
					tlen -= 3;
					printf("segment = \"%s\"\n\t\t\t\t\t", namelist[segidx]);
					printf("class   = \"%s\"\n\t\t\t\t\t", namelist[extidx]);
					printf("overlay = \"%s\"\n\t\t\t\t\t", namelist[ovlidx]);
					break;

			case 0xFB :	ltl = fgetc(infile); tlen--; checksum += ltl;
					mglen = getuw();
					glen = getuw(); tlen -= 4;
					printf("max group length = ");
					if (ltl & 1)
						printf("65536");
					else
						printf("%5d", mglen);
					printf("\n\t\t\t\t\tgroup length = ");
					if (ltl & 2)
						printf("65536");
					else
						printf("%5d", glen);
					putchar('\n');
					break;

			case 0xFA :	framenumber = getuw(); tlen -= 2;
					printf("frame number = %d\n", framenumber);
					break;
		}
	}

	checkit();
	return;
}

/* ----------------------------------------------------------------------- */

void dosegdef()
{
	int a, b, c, p, tlen, temp, b1, b2;

	int ltldat, frameno, segname, claname, ovename;

	unsigned maxlen, seglen, goffset, offset;

	writeheader();
	tlen = getlen();

	temp = fgetc(infile);  checksum += temp;

	a = (temp >> 5);
	c = (temp & 0x1C) >> 2;
	b = (temp & 2) >> 1;
	p = (temp & 1);

	if (a == 0)
		printf("absolute\n"); 
	if (a>0 && a<5)
		printf("relocatable ");
	if (a == 5)
		printf("unnamed absolute portion of MAS\n");
	if (a == 6)
		printf("LTL, paragraph aligned\n");


	switch (a)	{
		case 1: printf("byte aligned");
			break;
		case 2: printf("word aligned");
			break;
		case 3: printf("paragraph aligned");
			break;
		case 4: printf("page aligned");
			break;
	}

	switch (c)	{
		case 0:	puts(" PRIVATE");
			break;
		case 2: puts(" PUBLIC");
			break;
		case 5: puts(" STACK");
			break;
		case 6:	puts(" COMMON");
			break;
	}

	printf("\t\t\t\t\t");

	if (a == 0 || a == 5)
	{
		frameno = getsw();
		offset = fgetc(infile);
		checksum += offset;

		printf("frame number = %6d, offset = %2d\n");
		printf("\t\t\t\t\t");
	}

	if (a == 6)
	{
		ltldat = fgetc(infile);	checksum += ltldat;
		if (ltldat & 0x80)
			printf("group member, ");


		maxlen = getuw();
		goffset = getuw();

		printf("maxlen = ");

		if (ltldat & 1)
			printf("65536\n");
		else
			printf("%5d\n", maxlen);

		printf("\t\t\t\t\tgroup offset = %5d\n", goffset);
		printf("\t\t\t\t\t");
	}

	printf("seglen = ");
	seglen = getuw();

	if (b == 1)
		printf("65536");
	else
		printf("%5u", seglen);

	printf(", c = %d\n", c);

	if(a != 5)
	{
		segname = fgetc(infile);
		claname = fgetc(infile);
		ovename = fgetc(infile);
		checksum += segname + claname+ ovename;

		if ( (seglist[topseg] = strdup(namelist[segname])) == NULL)
		{
			puts("\n\nFATAL ERROR: out of memory");
			fclose(infile);
			exit(1);
		}
		topseg++;

		if(segname != 1)
		{
			printf("\t\t\t\t\t");
			printf("segname     = \"%s\"\n", namelist[segname]);
		}
		if(claname != 1)
		{
			printf("\t\t\t\t\t");
			printf("classname   = \"%s\"\n", namelist[claname]);
		}
		if(ovename != 1)
		{
			printf("\t\t\t\t\t");
			printf("overlayname = \"%s\"\n", namelist[ovename]);
		}
	}

	checkit();
	return;
}

/* ----------------------------------------------------------------------- */

void dolnames()
{
	int	reps, j, k, q, lent;
	char	rnam[80];

	writeheader();
	lent = getlen()-2;
	k = 0;

	while(lent>0)
	{
		if (k != 0)
			printf("\t\t\t\t    ");

		j = fgetc(infile);	checksum += j;
		lent -= j+1;

		if (j == 0)
			rnam[0] = '\0';
		else
		{
			fread(rnam, sizeof(char), j, infile);
			rnam[j] = '\0';
		}

		for(q=0; q<j; q++)
			checksum += rnam[q];

		if (strlen(rnam) == 0)
			strcpy(rnam, "(undefined)");

		printf("name %2d = \"%s\"\n", k++, rnam);

		if ( (namelist[topname] = strdup(rnam) ) == NULL)
		{
			puts("\n\nFATAL ERROR: out of memory");
			fclose(infile);
			exit(1);
		}

		topname++;
	}

	checkit();
	return;
}

/* ----------------------------------------------------------------------- */

void main(argc, argv)
int argc;
char **argv;
{
	puts("Nifty James' Object Module Dumper  Version 0.50");
	puts("Copyright (C) Mike Blaszczak, 1987.  All rights reserved.\n");

	if (argc == 1)
	{
		printf("input file name [.OBJ]: ");
		gets(tempname);
		putchar('\n');
	}
	else
	{
		strcpy(tempname, argv[1]);
	}
	if (strchr(tempname, '.') == NULL)
		strmfe(infilename, tempname, "obj");
	else
		strcpy(infilename, tempname);

	if ( (infile = fopen(infilename, "rb")) == NULL)
	{
		printf("Couldn't open file \"%s\" for input.\n", infilename);
		exit(1);
	}

	crecord = 0L;
	working = TRUE;

	puts("  REC#    Offset    RecID  RecName         Contents / Data\n  ----    ------    -----  -------         ---------------");

	while(working)
	{	
		crectype = fgetc(infile);
		checksum = crectype;  crecord++;

		if (crectype == -1)
		{	working = FALSE;
			goto wipeout;
		}

		switch(crectype) {

			case rtLHEADR:
			case rtTHEADR:	donamerecord();
					break;

			case rtREDATA:	doredata();
					break;

			case rtLEDATA:	doledata();
					break;

			case rtLNAMES:	dolnames();
					break;

			case rtPUBDEF:	dopubdef();
					break;

			case rtCOMENT:	docommentrec();
					break;

			case rtFIXUPP:	dofixupprec();
					break;

			case rtEXTDEF:	doextdef();
					break;

			case rtMODEND:	domodend();
					break;

			case rtGRPDEF:	dogrpdef();
					break;

			case rtSEGDEF:  dosegdef();
					break;

			case rtENDREC:	doendrec();
					break;

			case rtLINNUM:	dolinnum();
					break;

			default:	skiprecord();
		}

wipeout:	working = working;
	}

	fclose(infile);
	exit(0);
}
