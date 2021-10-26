/* TABs are every three columns	*/
/*---------------------------------------------------------
 *                                                        *
 *	Nifty James' Famous SORT Tool									 *
 * Version 1.00 of 08 May 1988									 *
 * Version 1.05 of 19 May 1988									 *
 * Version 1.10 of 03 July 1988									 *
 * Version 1.11 of 30 October 1988								 *
 *																			 *
 * (C) Copyright 1988 by Mike Blaszczak						 *
 * All Rights Reserved.  World Rights Reserved.				 *
 *																			 *
 * COMPILE WITH COMPACT MODEL!									 *
 * LINK with COMPARES.OBJ and /EXEPACK!						 *
 *																			 *
 * Written for Microsoft C Version 5.00 under MS-DOS 3.10 *
 * Revised (slightly) for Microsoft C Version 5.10			 *
 *																			 *
 --------------------------------------------------------*/

/* ------------------------------------------------------------------------ */
/*	Program-specific #defines
*/

#define MAXFILES	17			/* maximum number of open temp files	*/
#define SWAPFILES	64			/* maximum number of merge files			*/
#define LINESIZE	2047		/* maximum characters on a line			*/
#define MEMLINES	(12*1024)/* maximum number of lines in memory	*/

#define OUTOFMEM	1			/* errorlevel for out of memory			*/
#define BADUSAGE	2			/* errorlevel for bad command line		*/
#define BADFILE	3			/* errorlevel for bad file name			*/
#define BADREAD	4			/* something awry reading or writing	*/
#define BADWRITE	5
#define BADPARAM	6			/* got an invalid/out of range param	*/

/* ------------------------------------------------------------------------ */
/* Debugging switches
*/

/* #define DEBUG					/* general debugging switch				*/
/* #define MERGEBUG				/* debugging merge functions				*/

/* ------------------------------------------------------------------------ */
/*	Language-extension #defines
*/

#define ELEMENTS(array) (sizeof(array)/sizeof(array[0]))

#define boolean	unsigned char
#define FALSE		0
#define TRUE		(!FALSE)

/* ------------------------------------------------------------------------ */
/* Needed #include files
*/

#include <dos.h>
#include	<io.h>
#include <malloc.h>
#include <process.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* ------------------------------------------------------------------------ */
/* File Buffers and File Name areas
*/

FILE *tempfiles[SWAPFILES];		/* array of pointers to temp file buffers */
char *tfilenames[SWAPFILES];		/* names of those files							*/
char *tempbuff[SWAPFILES];			/* line buffer for each file					*/
boolean tempused[SWAPFILES];		/* set true if that file was used			*/
long tempoffset[SWAPFILES];		/* place we're reading from in the file	*/

unsigned topfile = 0;				/* next unused temporary filename 			*/

FILE	*infile;							/* the main inputfile							*/
char	infilename[64];				/* the main inputfile's name					*/

FILE	*outfile;						/* the file to be written out					*/
char	outfilename[64];				/* the name of the file to be written out */

char	*lines[MEMLINES];				/* array of pointers to lines in memory	*/
int	topline;							/* next unused line								*/
char	buffer[LINESIZE];				/* buffer for reading and writing			*/

char	infilemode[3]		= "r";	/* the modespec (ie, "r" or "rb") for		*/
char	outfilemode[3]		= "w";	/* the various files.  set up by				*/
char	*tempfileinmode = infilemode;				/* makefilemodes()				*/
char	*tempfileoutmode= outfilemode;

/* ------------------------------------------------------------------------ */
/* global data
*/

int	readstatus;						/* result of last call to readrecord()		*/
int	result;							/* working result from fillmemory()			*/

int	bigmark;							/* used during the merge						*/
/* lastbigmark was removed in Version 1.11	*/
/* int	lastbigmark;				/* previous largest from tempbuff[]			*/
char	*biggest;						/* pointer to that entry in tempbuff[]		*/
unsigned workline;					/* current dump point in lines[]				*/

/* ------------------------------------------------------------------------ */
/* Statistics and tallies
*/

unsigned	long exchanges = 0L;		/* number of exchanges made during sort	*/
unsigned	long nailed = 0L;			/* number of blanks we nailed					*/
unsigned	long nuked = 0L;			/* number of dupes we nuked					*/
unsigned	long nlines = 0L;			/* input lines										*/
clock_t	initiated, terminated;	/* starting and finishing clock() times	*/
clock_t	reading, sorting, writing, merging;
clock_t	mergestart;					/* time spent in each section of program	*/

/* ------------------------------------------------------------------------ */
/* Options and flags
*/

char 		seper = '\0';		  		/* delimiter between fields					*/
boolean	reversed = FALSE; 		/* sort in normal order by default			*/
boolean	ignorewhite = FALSE;		/* ignore leading whitespace					*/
unsigned firstkey = 0;		  		/* use a primary key								*/
unsigned firstlen = LINESIZE;		/* width of primary key							*/
unsigned secondkey = 0;		  		/* use a secondary key							*/
unsigned secondlen = LINESIZE; 	/* width of second key							*/
unsigned thirdkey = 0;				/* use a third key								*/
unsigned thirdlen = LINESIZE;    /* width of third key							*/
unsigned fourthkey = 0;				/* use a fourth key								*/
unsigned fourthlen = LINESIZE;	/* width of fourth key							*/
unsigned fifthkey = 0;				/* use a fifth key								*/
unsigned fifthlen = LINESIZE;		/* width of fifth key							*/
/* skiprecs is new for 1.11	*/
unsigned	skiprecs = 0;				/* # of records to leave in place 0=none	*/
boolean	blastdupes = FALSE;		/* erase duplicate lines						*/
boolean	insensitive = FALSE;		/* ignore case										*/
boolean	skipblanks = FALSE;		/* remove blank lines from text				*/
boolean	verbose = FALSE;			/* verbose mode									*/
boolean	columns = FALSE;			/* use keys as colums and not fields		*/
size_t	recwidth = 0;				/* recwidth, 0 if not binary mode				*/

boolean	gotout = FALSE;			/* set when outfile specified					*/

/* ------------------------------------------------------------------------ */
/* Widely used messages
*/

char	*tempfileerror	= "\nCouldn't open file \"%s\" for temporary use.\n";
char	*progname		= "NJSORT: ";
char	*badwrite		= "NJSORT: Can't write record %u in file %s\n";
char	*badfputs		= "NJSORT: Can't write line %u in file %s\n";
char	*toobig			= " is wider than maximum record length";
char	*canthave		= "% Can't have both %s\n";

/* ------------------------------------------------------------------------ */
/* ANSI-Standard C-Language Declarations
*/

void		makefilenames(void);
void		makefilemodes(void);
void		writerecord(FILE *destfile, char *destname, char *record,
				unsigned number);
void		drainmemory(FILE *destfile, char *destname);
void		readrecord(char *destination, FILE *infile);
void		skiprecords(void);
unsigned	fillmemory(void);
void		ssort(size_t elements, int (*cmpcall)(const char *, const char *));
void		dosort(void);
void		showusage(void);
void		checkline(int, char**);
void		statusout(void);
void		pclock_t(clock_t t2print);
void		outstats(void);
void		main(int count, char *arglist[]);

/* ------------------------------------------------------------------------ */
/* external (assembly-language) comapre routines, with ANSI-Standard
 * function prototypes.
*/

extern int comp_0(const char *, const char *);
extern int comp_0x(const char *, const char *);
extern int comp_1(const char *, const char *);
extern int comp_1x(const char *, const char *);
extern int comp_2(const char *, const char *);
extern int comp_3(const char *, const char *);
extern int comp_bin(const char *, const char *);
extern int comp_gen(const char *, const char *);
extern int checkblank(char *string);
extern unsigned long compcalls;

/* ----------------------------------------------------------------------- */
/* This function makes the filenames for the program.  All the tfilenames
	are made, based on the process name and the content of the TEMP=
	environment variable.  The outfilename is made, based on the input
	file name.
*/

void makefilenames()
{
	char name_buffer[64];	/* temporary buffer for building each name	*/
	char drive[3];				/* drive, dir, filename, and ext are used		*/
	char dir[30];				/* by _splitpath and _makepath to build the	*/
	char filename[9];			/* filenames.											*/
	char ext[4];

	int n, myid;				/* loop counter and place holder for our pid	*/
	char *restplace;			/* temporary pointer									*/

	/* first, we'll chop up the input file name	*/
	_splitpath(infilename, drive, dir, filename, ext);

	/* if it has the extension .BAK, complain!	*/
	if (strcmp(ext, ".BAK") == 0)
		{
		fprintf(stderr, "%sCan't sort a file with extention .BAK\n", progname);
		exit(BADFILE);
		}

	/* if we never found a specific output file, create it here by
		making .BAK the extension of the file name we were given		*/
	if (!gotout)
		_makepath(outfilename, drive, dir, filename, ".BAK");

	/* try to find NJTEM, TMP, or TEMP in the environment	*/

	restplace = getenv("NJTEMP");
	if (restplace == NULL)
		restplace = getenv("TMP");
	if (restplace == NULL)
		restplace = getenv("TEMP");
	if (restplace != NULL)
		_splitpath(restplace, drive, dir, filename, ext);

	/* now, find the process ID and use that to name our temp files	*/

	myid = getpid();
	sprintf(filename, "SRT%5.5d", myid);

	/* create a name for each temp file ... SRT<pid>.###	*/

	for (n = 0; n<SWAPFILES; n++)
		{
		sprintf(ext, ".%3.3d", n);
		_makepath(name_buffer, drive, dir, filename, ext);
		restplace = strdup(name_buffer);
		if (restplace == NULL)
			{
			fprintf(stderr, "%sNot enough memory\n", progname);
			exit(OUTOFMEM);
			}
		tfilenames[n] = restplace;
		}
	return;
}

/* ----------------------------------------------------------------------- */
/* this function will set up the file mode variables so that they
	correctly reflect the file mode that we will need to use.
*/

void	makefilemodes()
{
	/* the default modes are correct for ASCII sorting.	*/

	if (!recwidth)
		return;

	/* otherwise, we must concatinate a "b" for binary mode	*/

	strcat(infilemode, "b");
	strcat(outfilemode, "b");
	return;
}

/* ----------------------------------------------------------------------- */
/*	This function is called by drainmemory() to write a record to the
	output file.  It takes care of any errors that may occurr.
*/

void writerecord(FILE *destfile, char *destname, char *record,
	unsigned number)
{
	register size_t written;

	/* if we're in binary mode, write() the record ... otherwise,
		use fputs() to send it out to disk.									*/

	if (recwidth)
		{
		/* in version 1.11, I changed this from an fwrite() call to
			a write() call for greatly improved file creation speed.	*/

/*		written = fwrite(record, sizeof(char), recwidth, destfile); */
		written = write(fileno(destfile), record, recwidth);
		if (written != recwidth)
			{
			fprintf(stderr, badwrite, number+1, destname);
			exit(BADWRITE);
			}
		}
	else
		{
		if (fputs(record, destfile))
			{
			fprintf(stderr, badfputs, number+1, destname);
			exit(BADWRITE);
			}
		}

	return;
}

/* ----------------------------------------------------------------------- */
/* This function frees up all the memory pointed to by the lines[] array
	as it writes the array to the specified file.
*/

void drainmemory(FILE *destfile, char *destname)
{
	register unsigned n;
	register char *lastone;
	clock_t writeentry;

	printf("Writing... ");
	writeentry = clock();

	/* write one record, at least, and prime "writerecord"	*/

	writerecord(destfile, destname, lines[0], 0);
	lastone = lines[0];

	/* write each record from memory		*/

	for (n = 1; n<topline; n++)
		{

		/* if this one is the same as the last one, and blastdupes
			is a selected option, don't write it but do remember that
			we "nuked" it ... for the statistics display in /v			*/

		if (blastdupes && (strcmp(lines[n], lastone) == 0))
			nuked++;
		else
			writerecord(destfile, destname, lines[n], n);

		/* free the memory from the record previous	*/

		free(lines[n-1]);
		lines[n-1] = NULL;
		lastone = lines[n];
		}

	/* free the last record, and now add the time we spent here to the
		total	*/

	free(lines[n]);
	writing += clock()-writeentry;

	return;
}

/* ----------------------------------------------------------------------- */
/* fillmemory() depends on this routine to read a line or block into	buffer.
	readrecord() is used by fillmemory() when the program needs a line or
	record from the input file.  it reads the block into buffer and reports
	any errors that occur.
*/

void readrecord(char *destspot, FILE *sourcefile)
{
	register size_t wegot;

	/* do this for binary modes	*/
	if (recwidth)
		{
		wegot = fread((char *) destspot, sizeof(char), recwidth, sourcefile);
		if (wegot == 0 || wegot == recwidth)
			return;
		fprintf(stderr, "\n%sRecord %lu was incompletely read,", progname, nlines);
		fprintf(stderr, " only %u of %u bytes.\n", wegot, recwidth);

		exit(BADREAD);
		}
	else
	/* do this for ASCII mode	*/
		{
		if (feof(sourcefile))
			return;
		fgets(destspot, ELEMENTS(buffer), sourcefile);
		if (destspot[strlen(destspot)-1] != '\n')
			{
			fprintf(stderr, "%sInput line %lu exceeds %u characters.\n", progname, nlines, LINESIZE);
			exit(BADREAD);
			}
		}

	return;
}

/* ----------------------------------------------------------------------- */
/* This function checks to see if the user asked that we skip any records.
	If it is so, we will skip the records by reading them in from the
	input file and then and writing them out to the output file before the
	sort even starts (we are called from main()).
*/

void	skiprecords()
{
	unsigned	temporary;

	if (!skiprecs)
		return;

	/* there are records to skip	*/

	printf("Skipping %u record", skiprecs);
	if (skiprecs > 1)
		putchar('s');
	putchar('\n');

	/* just read through and skip them!  */

	for (temporary = skiprecs; temporary > 0; temporary--)
		{
		if (feof(infile))
			{
			fprintf(stderr, "%sthere weren't enough input records to skip %u\n",	progname, skiprecs);
			exit(BADPARAM);
			}

		readrecord(buffer, infile);
		writerecord(outfile, outfilename, buffer, skiprecs-temporary+1);
		}

	return;
}

/* ----------------------------------------------------------------------- */
/* This function reads as much as possible from the input file.  If all
	the file was read into memory (if EOF was reached), the routine returns
	zero.  Otherwise, it returns a 1 when it runs out of memory or runs out
	of slots in the lines[] array.
*/

unsigned fillmemory()
{
	register char *place;			/* destination for the item we just read	*/
	clock_t readentry;				/* time it took us to read things			*/
	boolean	extraused;				/* TRUE if we used the extra memory			*/
	char *extra;						/* a pointer to the extra memory record	*/

	/* tell the world what we're up to	*/

	printf("\nReading... ");
	topline = 0;
	readentry = clock();

	/* initialize the extra memory area	*/
	extraused = FALSE;
	if (!recwidth)
		extra = (char *) malloc(LINESIZE);
	else
		extra = (char *) malloc(recwidth);

	/* read one record	*/

	readrecord(buffer, infile);

	/* while the file isn't over	*/

	while(!feof(infile))
		{
		/* increment the number of record read	*/
		nlines++;

		/* if we're doing line by line, malloc the length of the string	*/
		if (!recwidth)
			{
			if (checkblank(buffer))
				{
				nailed++;
				continue;
				}
			place = malloc(strlen(buffer)+1);
			}
		/* otherwise, malloc the width of a record	*/
		else
			place = malloc(recwidth);

		/* if we ran out of memory just then, use the extra bit of memory
			that	we grabbed on the way in here.									*/

		if (place == NULL)
			{
			lines[topline++] = extra;
			if (!recwidth)
				strcpy(extra, buffer);
			else
				memcpy(extra, buffer, recwidth);
			reading += clock()-readentry;
			return(1);
			}

		/* otherwise, just add the place to the top of our list	*/
		else
			lines[topline++] = place;

		/* and copy the information in to there		*/
		if (recwidth)
			memcpy(place, buffer, recwidth);
		else
			strcpy(place, buffer);

		/* if we're at the end of our rope, give up	*/
		if (topline == MEMLINES)
			{
			reading += clock()-readentry;
			return(1);
			}

		/* otherwise, have another	*/
		readrecord(buffer, infile);
		}


	/* if the file ended and we read everything, we didn't need the
		extra  bit of memory ... so we can free it up.	*/
	free(extra);

	reading += clock()-readentry;

	return(0);
}

/* ----------------------------------------------------------------------- */
/* This is the sort engine.
*/

void	ssort(size_t elements, int (*cmpcall)(const char *, const char *))
{
	register int	i, j;
	int				gap;
	char				*p1, *p2, *temp;

	for (gap=1; gap <= elements; gap = 3*gap + 1)
		;

	for (gap /= 3;  gap > 0; gap /= 3)
		{
		for (i = gap; i < elements; i++)
			for (j=i-gap; j >= 0; j -= gap)
			{
				p1 = lines[j];
				p2 = lines[j+gap];

				if ((*cmpcall)(p1, p2) <= 0)
					break;

				exchanges++;
				temp = lines[j];
				lines[j] = lines[j+gap];
				lines[j+gap] = temp;
				
			}
		putchar('.');
		}
}

/* ----------------------------------------------------------------------- */
/*	This routine sorts all the information in memory.  It calls ssort() for
	most of the work.
*/

void dosort()
{
	clock_t sortentry;

	if (topline == 0)
		return;

	sortentry = clock();
	printf("Sorting...");

	/* decide what compare routine to call ssort() with, and just do it	*/

   if (recwidth)
      ssort((size_t) topline, comp_bin);
	else
		{
	   if (columns || seper)
   	   ssort((size_t) topline, comp_3);
		else
			{
			if (ignorewhite)
				ssort((size_t) topline, comp_2);
			else
				ssort((size_t) topline, comp_1x);
			}
		}

	putchar(' ');

	sorting += clock()-sortentry;
	return;	
}

/* ----------------------------------------------------------------------- */
/* showusage() prints out the usage of the program to educate the user
*/

void showusage()
{
	fprintf(stderr, "Usage:\t%s <infile> [<outfile>] [<options>]\n", progname);
	fputs("\tif <outfile> is unspecified, <infile> will be rewritten as .BAK\n\n", stderr);
	fputs("\t<options> are:\n", stderr);
	fputs("\t\t/F# specify first key field number\n", stderr);
	fputs("\t\t/S# specify second key field number\n", stderr);
	fputs("\t\t/T# specify third key field number\n", stderr);
	fputs("\t\t/Q# specify fourth key field number\n", stderr);
	fputs("\t\t/P# specify fifth key field number\n", stderr);
	fputs("\t\t/Mc specify field separation character\n", stderr);
	fputs("\t\t/N  reguard key numbers as column numbers\n\n", stderr);

	fputs("\t\t/B  remove blank lines\n", stderr);
	fputs("\t\t/C  case insensitive sort\n", stderr);
	fputs("\t\t/D  remove duplicate lines\n", stderr);
	fputs("\t\t/I  ignore leading whitespace\n", stderr);
	fputs("\t\t/On leave first n records of file in order\n", stderr);
	fputs("\t\t/R  sort in reverse order\n", stderr);
	fputs("\t\t/V  display sort stats\n", stderr);
	fputs("\t\t/W# specify record width and use binary mode", stderr);
	exit(BADUSAGE);
}

/* ----------------------------------------------------------------------- */
/* This routine sets the flags and checks the arguments.
	It also sets up the firstlen ... fifthlen variables.
*/

void checkline(int aargc, char *aargv[])
{
	boolean gotin = 0;
	char *temp;
	int stepper;
	int widest;

	for (stepper = 1; stepper<aargc; stepper++)
		{
		strupr(aargv[stepper]);
		if (*aargv[stepper] != '/' && *aargv[stepper] != '-')
			{
			if (gotin && gotout)
				showusage();
			if (gotin)
				{
				strcpy(outfilename, aargv[stepper]);
				gotout = TRUE;
				}
			else
				{
				strcpy(infilename, aargv[stepper]);
				gotin = TRUE;
				}
			}
		else
			{
			switch (aargv[stepper][1])
				{
				case 'B':	skipblanks = TRUE;
								break;
				case 'C':	insensitive = TRUE;
								break;
				case 'D':	blastdupes = TRUE;
								break;
				case 'F':	firstkey = (unsigned) atol(&aargv[stepper][2]);
								break;
				case 'I':	ignorewhite = TRUE;
								break;
				case 'M':	seper = aargv[stepper][2];
								break;
				case 'N':	columns = TRUE;
								break;
				case 'O':	skiprecs = (unsigned) atol(&aargv[stepper][2]);
								break;
				case 'P':   fifthkey = (unsigned) atol(&aargv[stepper][2]);
								break;
				case 'Q':	fourthkey = (unsigned) atol(&aargv[stepper][2]);
								break;
				case 'R':	reversed = TRUE;
								break;
				case 'S':	secondkey = (unsigned) atol(&aargv[stepper][2]);
								break;
				case 'T':	thirdkey = (unsigned) atol(&aargv[stepper][2]);
								break;
				case 'V':   verbose = TRUE;
								break;
				case 'W':   recwidth = (unsigned) atol(&aargv[stepper][2]);
								break;
				default:		showusage();
				}
			}
		}

	/* now that we have all of the options, check their validity	*/

	if (columns && seper)
		{
		fprintf(stderr, canthave, progname, "/N and /M");
		exit(BADUSAGE);
		}

	if (seper && recwidth)
		{
		fprintf(stderr, canthave, progname, "/M and /W");
		exit(BADUSAGE);
		}

	if (recwidth && columns)
		{
		fprintf(stderr, canthave, progname, "/W and /N");
		exit(BADUSAGE);
		}

	if (recwidth && blastdupes)
		{
		fprintf(stderr, canthave, progname, "/W and /D");
		exit(BADUSAGE);
		}

	if (recwidth && ignorewhite)
		{
		fprintf(stderr, canthave, progname, "/W and /I");
		exit(BADUSAGE);
		}

	if (recwidth && insensitive)
		{											 
		fprintf(stderr, canthave, progname, "/W and /C");
		exit(BADUSAGE);
		}

   if (recwidth)
      if (firstkey>recwidth || secondkey>recwidth || thirdkey>recwidth ||
            fourthkey>recwidth || fifthkey>recwidth)
         {
         fprintf(stderr, "%skey offset is greater than recwidth.\n", progname);
         exit(BADUSAGE);
         }

	if (!firstkey && !secondkey && !thirdkey && !fourthkey && !fifthkey &&
			(columns || seper))
		{
		fprintf(stderr, "%smust have at least one field with /N or /M\n", progname);
		exit(BADUSAGE);
		}

	if (!gotin)
		showusage();

	if (!columns && !recwidth)
		return;

	if (firstkey > LINESIZE)
		{
		fprintf(stderr, "%sfirstkey%s\n", progname, toobig);
		exit(BADPARAM);
		}

	if (secondkey > LINESIZE)
		{
		fprintf(stderr, "%ssecondkey%s\n", progname, toobig);
		exit(BADPARAM);
		}

	if (thirdkey > LINESIZE)
		{
		fprintf(stderr, "%sthirdkey%s\n", progname, toobig);
		exit(BADPARAM);
		}

	if (fourthkey > LINESIZE)
		{
		fprintf(stderr, "%sthirdkey%s\n", progname, toobig);
		exit(BADPARAM);
		}

	if (fifthkey > LINESIZE)
		{
		fprintf(stderr, "%sthirdkey%s\n", progname, toobig);
		exit(BADPARAM);
		}


	/*  this code computes the width of each field:
		 if a field is bounded on the right by another field, then its width
		 is computed.  if a field isn't bounded on the right by another field,
		 its width is set to the maximum ... LINESIZE.				*/

	for (stepper = 0; stepper<LINESIZE; stepper++)
			buffer[stepper] = ' ';
	buffer[LINESIZE-1] = '\0';

	if (recwidth)
		widest = recwidth;
	else
		widest = LINESIZE;

	buffer[firstkey]	= '*';
	buffer[secondkey]	= '*';
	buffer[thirdkey]	= '*';
	buffer[fourthkey] = '*';
	buffer[fifthkey]	= '*';
	if (recwidth)
		buffer[recwidth] = '*';			/* make sure that we don't overstep the
													buffer on the binary sort	*/

	temp = strchr(buffer+firstkey+1, '*');
	if (temp == NULL)
		firstlen = widest;
	else
		firstlen = temp - (buffer+firstkey);

	temp = strchr(buffer+secondkey+1, '*');
	if (temp == NULL)
		secondlen = widest;
	else
		secondlen = temp - (buffer+secondkey);

	temp = strchr(buffer+thirdkey+1, '*');
	if (temp == NULL)
		thirdlen = widest;
	else
		thirdlen = temp - (buffer+thirdkey);

	temp = strchr(buffer+fourthkey+1, '*');
	if (temp == NULL)
		fourthlen = widest;
	else
		fourthlen = temp - (buffer+fourthkey);

	temp = strchr(buffer+fifthkey+1, '*');
	if (temp == NULL)
		fifthlen = widest;
	else
		fifthlen = temp - (buffer+fifthkey);

	return;
}

/* ----------------------------------------------------------------------- */
/* This routine lets the user know what's up.
*/

void statusout()
{
	printf("Sorting file \"%s\" into \"%s\"\n", infilename, outfilename);
	if (blastdupes)
		puts("Removing duplicate lines");
	if (skipblanks)
		puts("Removing blank lines");

	if (insensitive)
		puts("Case insensitive sort");
	if (reversed)
		puts("Backwards sort order");

	if (ignorewhite)
		puts("Ignore leading whitespace");
	if (verbose)
		puts("Verbose mode");

	if (columns || seper)
		{
		printf("Sorting by %s\n", columns ? "columns" : "keys");
		if (firstkey)
			printf(" Key 1 = %4u   ", firstkey);
		if (secondkey)
			printf(" Key 2 = %4u   ", secondkey);
		if (thirdkey)
			printf(" Key 3 = %4u   ", thirdkey);
		if (fourthkey)
			printf(" Key 4 = %4u   ", fourthkey);
		if (fifthkey)
			printf(" Key 5 = %4u", fifthkey);
		}
	if (columns)
		{
		if (firstkey)
			printf("\nWidth 1= %4u   ", firstlen);
		if (secondkey)
			printf("Width 2= %4u   ", secondlen);
		if (thirdkey)
			printf("Width 3= %4u   ", thirdlen);
		if (fourthkey)
			printf("Width 4= %4u   ", fourthlen);
		if (fifthkey)
			printf("Width 5= %4u\n", fifthlen);
		}

	if (recwidth)
		{
		printf("Binary mode - record width is %d byte", recwidth);
/* version 1.11		*/
		if (recwidth > 1)
			putchar('s');
		putchar('\n');
/* version 1.11 ends	*/
		}

	putchar('\n');
	return;
}

/* ----------------------------------------------------------------------- */
/* This routine prints out a clock_t variable as a decimal number.  NOTE
	that this routine relies upon CLK_TCK being #defined to 1000.  Other
	compilers (than Microsoft) might not use this!   Turbo C does not!
*/

void pclock_t(clock_t t2print)
{
	printf("%7ld.%02ld", t2print/CLK_TCK, t2print%(CLK_TCK*10));
	return;
}

/* ----------------------------------------------------------------------- */
/* This function prints the verbose mode statistics to the user.
*/

void outstats()
{
	register char *itemword;

	if (!verbose)
		return;

	terminated = clock();

	if (recwidth)
		itemword = "records";
	else
		itemword = " lines ";

	printf("\nTemporary files used     : %10d\n", topfile);
	printf("Total %s read       : %10lu  Time Read   : ", itemword, nlines);
	pclock_t(reading);
	printf("\nBlank %s removed    : %10lu  Time Writing: ", itemword, nailed);
	pclock_t(writing);
	printf("\nDuplicate %s removed: %10lu  Time Sorting: ", itemword, nuked);
	pclock_t(sorting);
	printf("\nTotal %s written    : %10lu  Time Merging: ", itemword,
													nlines - nailed - nuked);
	pclock_t(merging);

	
	printf("\n\nCompare routine calls    : %10lu  ", compcalls);
	printf("Elapsed time      :  ");
	pclock_t(terminated-initiated);
	printf("\nExchanges during sort    : %10lu  ", exchanges);

	printf("%s per second: %10ld\n\n", itemword,
									(nlines*CLK_TCK)/(terminated-initiated));
	return;
}

/* ----------------------------------------------------------------------- */

void main(int argc, char *argv[])
{
	register int gc;		/* general purpose loop counter	*/

	for (gc = 0; gc<SWAPFILES; gc++)
		{
		tempused[gc] = FALSE;
		tempoffset[gc] = 0L;
		}

	reading = writing = sorting = merging = 0L;

	fclose(stdin);
	fclose(stdprn);
	fclose(stdaux);		/* free up more file handles	*/

	puts("Nifty James' Famous SORT Tool\nVersion 1.11 of 30 October 1988");
	puts("(C) Copyright 1988 by Mike Blaszczak\n");

	if (argc<2)
		showusage();

	checkline(argc, argv);
	makefilenames();

	makefilemodes();

	initiated = clock();
	infile = fopen(infilename, infilemode);
	if (infile == NULL)
		{
		fprintf(stderr, "%sCan't open file \"%s\" for input.\n", progname, infilename);
		exit(BADREAD);
		}

	outfile = fopen(outfilename, outfilemode);
	if (outfile == NULL)
		{
		fprintf(stderr, "%sCouldn't open file \"%s\" for output.\n",
			progname, outfilename);
		exit(BADWRITE);
		}

	/* the nitty-gritty	*/
	statusout();

/* version 1.11	*/
	/* at this point, the input file is open.  check to see if we're
		supposed to skip any of it off the top.			*/

	skiprecords();

/* end version 1.11	*/

	result = fillmemory();	/* read some of the file	*/

	dosort();
	if (result == 0)			/* enirely in-memory sort, if it fits	*/
		{
		drainmemory(outfile, outfilename);
		fcloseall();
		puts("Sorted!\007");
		outstats();
		exit(0);
		}

	/*	can't sort in one pass ... so, we'll use the tempfiles	*/

	do {
		tempfiles[topfile] = fopen(tfilenames[topfile], tempfileoutmode);
		if (tempfiles[topfile] == NULL)
			{
			fprintf(stderr, tempfileerror, tfilenames[topfile]);
			exit(BADWRITE);
			}
		drainmemory(tempfiles[topfile], tfilenames[topfile]);

		if (recwidth)
			tempbuff[topfile] = (char *) malloc(recwidth);
		else
			tempbuff[topfile] = (char *) malloc(LINESIZE);

		if (tempbuff[topfile] == NULL)
			{
			fprintf(stderr, "%sCouldn't setup temporary buffer #%d\n",
				progname, topfile);
			exit(BADWRITE);
			}
		fclose(tempfiles[topfile]);
		topfile++;
		if (topfile == MAXFILES)
			{
			fprintf(stderr, "%sToo many temporary files!  Can't sort.\n",
				progname, topfile);
			exit(BADWRITE);
			}
		result = fillmemory();
		dosort();
	} while (result != 0);
	fclose(infile);

	/* Now, there is some sorted data in memory and in each of the temfiles
		we just merge these together into the outfile.								*/

	/* first, we'll open each of the tempfiles for input							*/

	for (gc = 0; gc<topfile; gc++)
		{
		tempfiles[gc] = fopen(tfilenames[gc], tempfileinmode);
		if (tempfiles[gc] == NULL)
			{
			fprintf(stderr, tempfileerror, tfilenames[gc]);
			exit(BADREAD);
			}
		readrecord(tempbuff[gc], tempfiles[gc]);
		}

	/* Now, we just loop through the highest lines of each file and
			see which is the lowest.  When a file runs out, we make it NULL
			so that we know not to check it's top line anymore.  When we
			find the "uppermost" line, we write it out and read another
			line to fill that file.													*/

	printf("\nMerging...");
	mergestart = clock();

	if (topline == 0)
		topline = -1;		/* keep from writing nothing	*/

	while(1)
		{

		/* we'll initialize the biggest here to null, and then try to find
			a valid, real place for it to point to until we can find the
			biggest	*/

			biggest = NULL;

			for (gc = 0; gc<topfile; gc++)
				if (tempfiles[gc] != NULL)
					{
					biggest = tempbuff[gc];
					break;
					}

		/* if there are no valid datum, we'll break out of the loop	*/

			if (biggest == NULL)
				break;

		/* otherwise, we'll look through the valid data again and see if
			we can find a tempbuff bigger than the arbitrary biggest that
			we picked.		*/

			for (gc = 0; gc<topfile; gc++)
				if (tempfiles[gc] != NULL)
					if (comp_gen(tempbuff[gc], biggest) <= 0)
						{
						biggest = tempbuff[gc];
						bigmark = gc;
						}

		/* now that we know which is the "highest" record in our buffer
			pool, we'll see if any record in memory is bigger than the
			one we think we should write.  if we find one, we will write
			it out to the file.	*/

			if (topline != -1)
				while(comp_gen(lines[workline], biggest) < 0)
					{
					writerecord(outfile, outfilename, lines[workline], workline);
					workline++;
					if (workline == topline)
						{
						topline = -1;
						break;
						}
					}

/*	Version 1.11 fix	*/

		/* here, we will check to see if the file we just wrote a
			record from is empty.  if it is, we will make the buffer
			NULL so we won't consider it later.	*/

			if (tempfiles[bigmark] == NULL)
				printf("bigmark %d was null.\n", bigmark);

			if (feof(tempfiles[bigmark]))
				{
				fclose(tempfiles[bigmark]);
				tempfiles[bigmark] = NULL;
				remove(tfilenames[bigmark]);

				free(tempbuff[bigmark]);
				tempbuff[bigmark] = NULL;
				free(tfilenames[bigmark]);
				tfilenames[bigmark] = NULL;

				putchar('.');
				}

		/* now, we'll write the biggest one from our buffer pool	*/
		/* since that file isn't done, we will refill its entry in
			the buffer pool	*/
			
			else
				{
				writerecord(outfile, outfilename, biggest, 0);
				readrecord(tempbuff[bigmark], tempfiles[bigmark]);
				}

/* end Version 1.11 fix	*/

		}

	/* if the memory isn't empty, we will dump that to the output
		file at this time, too.	*/

	if (topline != -1)
		while (workline < topline)
			{
			writerecord(outfile, outfilename, lines[workline], workline);
			workline++;
			}

	/* stop the clock!	*/

	merging = clock() - mergestart;

	printf(" Merged!\n");

	/* close up the output file, beep at the user, and print the
		statistics	*/

	fclose(outfile);
	puts("Sorted!\007");
	outstats();
	exit(0);
}

