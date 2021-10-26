
/****************************************************************
 *								*
 *  Nifty James' Famous Program Logger  (NJPL)			*
 *								*
 *  Version 1.00, of 2 January 1988				*
 *								*
 *  Written for Microsoft C Version 5.00, and MASM 5.00.	*
 *								*
 *  (C)opyright 1988 by Mike Blaszczak, all Rights Reserved.	*
 *								*
 ***************************************************************/

/*		After compiling, use EXEMOD NJPL /MAX 210		*/

#include <stdlib.h>
#include <dos.h>
#include <malloc.h>
#include <errno.h>
#include <stdio.h>
#include <process.h>
#include <string.h>
#include <mytypes.h>

#define	OFF	0
#define	ON	100

struct njtm {
	byte	hsec;		/* hundreths of seconds	*/
	byte	sec;		/* seconds		*/
	byte	min;		/* minutes		*/
	byte	hour;		/* hours		*/
	byte	day;		/* day	of month	*/
	byte	wday;		/* day of week		*/
	int	year;		/* year			*/
	byte	month;		/* month of year	*/
};

extern int errno;	/* error value returned from spawn		*/
char	total[128];	/* the entire command line that program gets	*/
char	program[64];	/* name/path of the program that we're running	*/
int	tflag;		/* terseness flag				*/
struct njtm *pstart, *pend;	/* starting and ending times of program	*/
double	et;		/* time it took the program to run, in seconds	*/

char *temp, tchar;	/* temp pointer for looking at environment, etc	*/
char datafile[64];	/* data file to use for log file		*/
char datapath[64];	/* path to the datafile				*/
char mastfile[64];	/* name of the master file			*/

FILE *outfile;		/* log file for output				*/

/* -------------------------------------------------------------------- */

void peh()
{
	printf("NJPL: Fatal Error - ");
	return;
}

/* -------------------------------------------------------------------- */

struct njtm *getnjtm()
{
	union REGS in, out;
	struct njtm *place;

	place = (struct njtm *) malloc(sizeof(struct njtm));
	if (place == NULL)
	{
		peh();
		puts("Can't allocate memory\n");
		exit(255);
	}

	in.h.ah = 0x2A;			/* get the date from DOS	*/
	intdos(&in, &out);

	place->year = out.x.cx;
	place->day  = out.h.dl;
	place->month= out.h.dh;
	place->wday = out.h.al;

	in.h.ah = 0x2C;			/* get the time from DOS	*/
	intdos(&in, &out);

	place->hsec  = out.h.dl;
	place->sec   = out.h.dh;
	place->min   = out.h.cl;
	place->hour  = out.h.ch;

	return(place);			/* return a pointer to the new structure */
}

/* -------------------------------------------------------------------- */

void prnjtm(outspec, place)
struct njtm *place;
FILE *outspec;
{
	/*  write the passed time value as "year mm dd hh:mm:ss.hh "
		to the specified file	*/

	fprintf(outspec, "%2d %2.2d %2.2d ",
			place->year-1900, place->month, place->day);
	fprintf(outspec, "%2.2d:%2.2d:%2.2d.%2.2d ",
			place->hour, place->min, place->sec, place->hsec);
	return;
}

/* -------------------------------------------------------------------- */

byte monthlen[12] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

double fnjtm(q)
struct njtm *q;
{
	/*  convert the njtm structure into a double ... seconds since
		1 jan 1980 at 00:00			*/

	double value;
	int n;

	value  = (double) (q->hsec/100.0 + q->sec + q->min*60);
	value += q->hour*3600.0 + q->day*86400.0;

	for(n=0; n< (q->month-1); n++)
		value += monthlen[n]*86400.0;

	value += ((q->year)-1970)*31536000.0;

	for (n=1972; n<(q->year); n += 4)
		value += 86400.0;

	return(value);
}

/* -------------------------------------------------------------------- */

double njtmdiff(a, b)
struct njtm *a, *b;
{
	/*  find the difference in seconds between a and b.  a is
		assumed to be larger than b.		*/

	double fa, fb;

	fa = fnjtm(a);
	fb = fnjtm(b);

	return(fa-fb);
}

/* -------------------------------------------------------------------- */

char *progname(av0)
char *av0;
{
	/* return a pointer to the program name	*/

	char *location, *end;

	if ((location = strrchr(av0, '\\')) == NULL)
		location = av0;
	else
		location++;

	end = malloc(14);

	strcpy(end, location);

	for(location = end; *location != '.'; location++);
	*location = '\0';

	strupr(end);		/*	make it uppercase!	*/
	return(end);
}

/* -------------------------------------------------------------------- */

void outrecord()
{
	prnjtm(outfile, pstart);
	prnjtm(outfile, pend);
	fprintf(outfile, "| %.2f {[%s]} {[%s]}\n", et, program, total);
	return;
}

/* -------------------------------------------------------------------- */

char	sysfile[64];			/* name of the system file	*/

void sysrecord(mode)
int mode;
{
	if (temp == NULL)
		datapath[0] = '\0';
	else
	{
		strcpy(datapath, temp);
		tchar = datapath[strlen(datapath)-1];
		if (tchar != ':' && tchar != '\\')
			strcat(datapath, "\\");
	}

	strcpy(sysfile, datapath);
	strcat(sysfile, "SYSUSAGE.PLF");

	outfile = fopen(sysfile, "a");
	if (outfile == NULL)
	{
		peh();
		printf("Couldn't open system log file.  File is \"%s\"\n\n", mastfile);
		exit(255);
	}

	pstart = getnjtm();

	if(mode == ON)
		fprintf(outfile, "on  ");
	else
		fprintf(outfile, "off ");
	prnjtm(outfile, pstart);
	putc('\n', outfile);
	
	fclose(outfile);
	exit(0);
}

/* -------------------------------------------------------------------- */

void main(argc, argv)
int argc;
char *argv[];
{
	int retval;		/*  errorlevel from returned file	*/

	if (argc == 1)
	{
showusage:	puts("Nifty James' Famous Program Logger\nVersion 1.00 of 2 January 1988\n");
		puts("Usage\n\tnjpl [-t] <command line>\n\t[-t] specifies terse operation");
		puts("or\n\tnjpl [-on | -off]");
		puts("\t[-on] and [-off] record system turnon and turnoff time");
		puts("\tin the system record.\n");
		exit(255);
	}

	temp = getenv(progname(argv[0]));

	if(stricmp(argv[1], "-off") == 0 || stricmp(argv[1], "/off") == 0)
		sysrecord(OFF);

	if(stricmp(argv[1], "-on") == 0 || stricmp(argv[1], "/on") == 0)
		sysrecord(ON);

	tflag = 0;
	if (*argv[1] ==  '/' || *argv[1] == '-')
		if(*(argv[1]+1) == 'T' || *(argv[1]+1) == 't')
			tflag = 1;
		else
			goto showusage;

	total[0] = '\0';
	strcpy(program, argv[tflag+1]);

	for(retval = tflag+2; retval < argc; retval++)
		strcat(total, argv[retval]);

	while(*temp == '\t' || *temp == ' ')
		*temp-- = '\0';

	pstart = getnjtm();
	retval = spawnlp( P_WAIT, program, "x", total, NULL);
	pend = getnjtm();
	et = njtmdiff(pend, pstart);


	if (retval == -1)
	{	peh();
		switch (errno)  {

		case	E2BIG:		puts("Environment or command line too big");
					break;
	
		case	EINVAL:		puts("Internal error\n");
					break;

		case	ENOENT:		puts("Bad command or file name\n");
					break;

		case	ENOEXEC:	puts("Not an executable file\n");
					break;

		case	ENOMEM:		puts("Not enough memory\n");
					break;
		}
	}
	else
	{

		if(!tflag)
		{	printf("Program started at ");
			prnjtm(stdout, pstart);
			printf("\nProgram  ended  at ");
			prnjtm(stdout, pend);
			printf("\nProgram took %.2f seconds to run\n", et);
		}		

		temp = getenv(progname(argv[0]));

		if (temp == NULL)
			datapath[0] = '\0';
		else
		{	strcpy(datapath, temp);
			tchar = datapath[strlen(datapath)-1];
			if (tchar != ':' && tchar != '\\')
				strcat(datapath, "\\");
		}

		strcpy(mastfile, datapath);
		strcat(mastfile, progname(argv[0]));
		strcat(mastfile, ".PLF");

		outfile = fopen(mastfile, "a");
		if (outfile == NULL)
		{	peh();
			printf("Couldn't open master file.  File is \"%s\"\n\n", mastfile);
			exit(255);
		}

		outrecord();
		fclose(outfile);
	}
	exit(retval);
}

