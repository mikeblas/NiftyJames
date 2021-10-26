 /***************************************************************\
 *                                                               *
 *   Nifty James' Program log Report generator                   *
 *                                                               *
 *   Version 1.00 of 2 January 1988                              *
 *                                                               *
 *   Written for Microsoft C Version 5.00 and MASM 5.00          *
 *                                                               *
 *   (C) Copyright 1988 by Mike Blaszczak, All Rights Reserved   *
 *                                                               *
 \***************************************************************/

#include <malloc.h>
#include <math.h>
#include <mytypes.h>		/****************************************/
#include <search.h>		/*    COMPILE WITH THE COMPACT MODEL    */
#include <stdlib.h>		/****************************************/
#include <stdio.h>
#include <string.h>

#define FORMFEED	12	/* form feed character			*/

#define MAXLINES        8192	/* max number of progs + cmd lines	*/
#define MAXPROGS        4096	/* max number of programs to handle	*/
#define LINEWID		10	/* number of cmd line chars to use	*/

#define ON		1	/* return values for readsysentry()	*/
#define OFF		2
#define NEVER		5

int	lastsysentry = NEVER;	/* getsysentry() was never called	*/

FILE    *infile;                /* our input file tag and buffer        */
char    infilename[64];         /* the name of the input file           */
char    *temp;                  /* temporary result pointer             */

FILE	*sysfile;		/* the systemlog file			*/
char	sysfilename[64];	/* the name of the system log file	*/

unsigned long linenumber;	/* current line number in infile	*/
unsigned long syslinenumber;	/* current line number in sysfile	*/

int     cstartyear;             /* program's starting   year            */
int     cstartmonth;            /*                      month           */
int     cstartday;              /*                      day             */
int     cstarthour;             /*                      hour            */
int     cstartminute;           /*                      minute          */
int     cstartsecond;           /*                      second          */
int     cstarthundred;          /*                      hundredths      */

int     cendyear;               /* program's ending     year            */
int     cendmonth;              /*                      month           */
int     cendday;                /*                      day             */
int     cendhour;               /*                      hour            */
int     cendminute;             /*                      minute          */
int     cendsecond;             /*                      second          */
int     cendhundred;            /*                      hundred         */

double  ctimethere;             /* time spent in the program            */

char	cprogname[16];		/* current programs name		*/
char	ccmdline[128];		/* current programs command line	*/

boolean uprog = FALSE;          /* usage per program                    */
boolean uline = FALSE;          /* usage per program with command line  */
boolean dprog = FALSE;          /* program usage per day                */
boolean dline = FALSE;          /* program + command line per day       */
boolean sys   = FALSE;		/* system usage statistics		*/

int     n;                      /* loop counters                        */

struct program_total {
	char    *name;          /* program's name                       */
	double  timethere;      /* total time spent there               */
};

struct program_line_total {
	char    *name;          /* program's name			*/
	char    *line;          /* program's program			*/
	double  timethere;      /* total time spent there		*/
};

struct  prog_entry	{
	char	*name;		/* program's name			*/
	unsigned long times;	/* number of times it was run		*/
	double	timethere;	/* time inside that program		*/
};

struct	line_entry	{
	char	*name;		/* name of the program			*/
	char	*line;		/* program's command line		*/
	unsigned long times;	/* number of times it was run		*/
	double	timethere;	/* time in that program			*/
};

unsigned long	startdate = 0xFFFFFFFF;
unsigned long	enddate = 0L;

struct	line_entry *line_list[MAXLINES];
int	topline =0;

struct	prog_entry *prog_list[MAXPROGS];
int     topprog =0;

struct program_line_total *program_lines[MAXLINES];
int     toppline =0;

struct program_total      *program_total[MAXPROGS];
int     topptotal =0;

char *month_name[] = {
		"January",   "February", "March",    "April",
		"May",       "June",     "July",     "Augst",
		"September", "October",  "November", "December" };

int monthlen[12] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

int upto[12];	/* see beginning of main() for init of this		*/

struct njtm {
	int	hsec;		/* hundreths of seconds	*/
	int	sec;		/* seconds		*/
	int	min;		/* minutes		*/
	int	hour;		/* hours		*/
	int	day;		/* day	of month	*/
	int	wday;		/* day of week		*/
	int	year;		/* year			*/
	int	month;		/* month of year	*/
};

struct njtm syson, sysoff;	/* for dosysuse() routines	*/

/* ----------------------------------------------------------------------- */

unsigned long	u_min(unsigned long, unsigned long);
unsigned long	u_max(unsigned long, unsigned long);
unsigned long	datenumber(int, int, int);
char	*plural(unsigned long);
void	memoryend(void);
void	freelinelist(void);
int	comp_lineentry(struct line_entry **, struct line_entry **);
void    buildlinelist(void);
void	freeproglist(void);
int	comp_progentry(struct prog_entry **, struct prog_entry **);
void	buildproglist(void);
void    openup(void);
void	openupsys(void);
void    closedown(void);
void	closedownsys(void);
void	sysinvalid(void);
void	invalid(void);
void    readentry(void);
void	printtime(double);
void	dodline(void);
void	douline(void);
void	dodprog(void);
void	douline(void);
void	dosysuse(void);

/* ----------------------------------------------------------------------- */

unsigned long u_min(a,b)
unsigned long a, b;
{
	if (a<=b)
		return(a);
	else
		return(b);
}

/* ----------------------------------------------------------------------- */

unsigned long u_max(a,b)
unsigned long a, b;
{
	if (a>=b)
		return(a);
	else
		return(b);
}

/* ----------------------------------------------------------------------- */

unsigned long datenumber(month, day, year)
int month, day, year;		/* convert a date to a unique number */
{
	unsigned long retval;
	register int n;

	/* expects year == years since 1900	*/

	retval = 365 * year;
	retval += day;
	retval += upto[month-1];

	for (n = 80; n<year; n+=4)
		retval++;

	return(retval);
}

/* ----------------------------------------------------------------------- */

char	*plural(n)
unsigned long n;
{
	if(n == 1)
		return("");
	else
		return("s");
}

/* ----------------------------------------------------------------------- */

void	memoryend()
{
	fputs("NJPR: Out of Memory\n", stderr);
	closedown();
	exit(2);
}

/* ----------------------------------------------------------------------- */

void	freelinelist()
{
	while(topline--)
	{
		free(line_list[topline]->name);
		free(line_list[topline]->line);
		free(line_list[topline]);
	}
	topline=0;
	return;
}

/* ----------------------------------------------------------------------- */

int	comp_lineentry(arg1, arg2)
struct line_entry	**arg1, **arg2;
{
	register int temp;

	temp = stricmp((*arg1)->name, (*arg2)->name);

	if(temp != 0)
		return(temp);
	else
		return(stricmp((*arg1)->line, (*arg2)->line));
}

/* ----------------------------------------------------------------------- */

void    buildlinelist()
{
	register int work;
	register char *temp;

	if(topline != 0)
		return;

	openup();

	while(!feof(infile))
	{
		readentry();

		for(work = 0; work < topline; work++)
			if(stricmp(line_list[work]->name, cprogname) == 0 &&
			   strnicmp(line_list[work]->line, ccmdline, LINEWID) == 0)
			{
				line_list[work]->times++;
				line_list[work]->timethere += ctimethere;
				goto already;
			}

		line_list[topline] =
			(struct line_entry *) malloc(sizeof(struct line_entry));

		if(line_list[topline] == NULL)
			memoryend();

		if( (temp = malloc(strlen(cprogname)+2)) == NULL)
			memoryend();

		line_list[topline]->name = temp;
		strcpy(line_list[topline]->name, cprogname);

		if( (temp = malloc(strlen(ccmdline)+2)) == NULL)
			memoryend();

		line_list[topline]->timethere = ctimethere;
		line_list[topline]->times = 1L;

		line_list[topline]->line = temp;
		strcpy(line_list[topline]->line, ccmdline);
		topline++;

		if (topline > MAXLINES)
			memoryend();

already:        ;
	}

	qsort((void *) line_list, (size_t) topline, sizeof(struct line_entry *),
			 comp_lineentry);

	closedown();
	return;
}

/* ----------------------------------------------------------------------- */

void	freeproglist()
{
	while(topprog--)
	{
		free(prog_list[topprog]->name);
		free(prog_list[topprog]);
	}
	topprog =0;
	return;
}

/* ----------------------------------------------------------------------- */

int	comp_progentry(arg1, arg2)
struct	prog_entry **arg1, **arg2;
{
	return(stricmp((*arg1)->name, (*arg2)->name ));
}

/* ----------------------------------------------------------------------- */

void    buildproglist()
{
	register int work;
	register char *temp;

	if (topprog != 0)
		return;

	openup();

	while(!feof(infile))
	{
		readentry();

		for(work = 0; work < topprog; work++)
			if(stricmp(prog_list[work]->name, cprogname) == 0)
			{
				prog_list[work]->times++;
				prog_list[work]->timethere += ctimethere;
				goto already;
			}

		prog_list[topprog] = (struct prog_entry *)
			malloc(sizeof(struct prog_entry));

		if(prog_list[topprog] == NULL)
			memoryend();

		if( (temp = malloc(strlen(cprogname)+2)) == NULL)
			memoryend();

		prog_list[topprog]->timethere = ctimethere;
		prog_list[topprog]->name = temp;
		prog_list[topprog]->times = 1L;
		strcpy(prog_list[topprog]->name, cprogname);
		topprog++;

		if(topprog >MAXPROGS)
			memoryend();

already:        ;
	}

	qsort((void *) prog_list, (size_t) topprog, sizeof(struct prog_entry *),
			 comp_progentry);

	closedown();
	return;
}

/* ----------------------------------------------------------------------- */

void	invalid()
{
	fprintf(stderr, "NJPR: invalid data in NJPL.PLF around line %lu\n",
			linenumber);
	closedown();
	exit(3);
}

/* ----------------------------------------------------------------------- */

void	sysinvalid()
{
	fprintf(stderr, "NJPR: invalid data in SYSUSAGE.PLF around line %lu\n",
			syslinenumber);
	closedown();
	exit(3);
}

/* ----------------------------------------------------------------------- */

char    readentry_buff[384];

void readentry()
{
	char            *dest, *source;
	char            *work;

	if( NULL == fgets(readentry_buff, sizeof(readentry_buff), infile))
		return;

	linenumber++;
	if( 7 != 
		sscanf(readentry_buff, "%d%d%d%d:%d:%d.%d",
			&cstartyear, &cstartmonth, &cstartday, &cstarthour,
			&cstartminute, &cstartsecond, &cstarthundred) )
		   invalid();
	if( 7 != 
		sscanf(readentry_buff, "%d%d%d%d:%d:%d.%d",
			&cendyear, &cendmonth, &cendday, &cendhour,
			&cendminute, &cendsecond, &cendhundred) )
		   invalid();
	startdate = u_min(startdate, datenumber(cstartmonth, cstartday, cstartyear));
	enddate = u_max(enddate, datenumber(cstartmonth, cstartday, cstartyear));

	if ( (work = strchr(readentry_buff, '|')) == NULL)
		invalid();

	work += 2;
	sscanf(work, "%lf", &ctimethere);

	if ( ctimethere == 0.0)
		invalid();

	dest = cprogname;
	source = strstr(work, "{[")+2;

	while(*source != ']' && source[1] != '}')
		*dest++ = *source++;
	*dest = '\0';

	if(strlen(cprogname) == 0)
		invalid();

	source += 5;
	dest = ccmdline;

	while(*source != ']' && source[1] != '}')
		*dest++ = *source++;
	*dest = '\0';

	return;
}

/* ----------------------------------------------------------------------- */

void openupsys()
{
	if ( (sysfile = fopen(sysfilename, "r")) == NULL)
	{
		fprintf(stderr, "NJPL: Couldn't open input file \"%s\"\n", sysfilename);
		fcloseall();
		exit(2);
	}

	syslinenumber = 0L;
	return;
}

/* ----------------------------------------------------------------------- */

void openup()
{
	if ( (infile = fopen(infilename, "r")) == NULL)
	{	fprintf(stderr, "NJPL: Couldn't open input file \"%s\"\n");
		fcloseall();
		exit(2);
	}

	linenumber = 0L;
	return;
}

/* ----------------------------------------------------------------------- */

void closedownsys()
{	fclose(sysfile);
	return;
}

/* ----------------------------------------------------------------------- */

void closedown()
{	fclose(infile);
	return;
}

/* ----------------------------------------------------------------------- */

void printdate(d)
unsigned long d;
{	register int n;
	int day, month, year;

	year = (d / 365) + 1900;

	d = (d % 365);

	for(n = 1980; n<year; n+=4)
		d--;

	month = 0;

	for(n = 0; d>monthlen[n]; n++)
	{	month++;
		d -= monthlen[n];
	}

	day = (int) d;

	printf("%d %s %d", day, month_name[month], year);
	return;
}

/* ----------------------------------------------------------------------- */

void printtime(t)
double t;
{
	int hours, minutes, seconds, hunds;

	hours   = (int) (t / 3600.0);
	minutes = (int) (fmod(t, 3600.0) / 60.0);
	seconds = (int) fmod(t, 60);
	hunds   = (int) ( (t - floor(t)) * 100.0 );

	printf("%d:%2.2d:%2.2d.%2.2d", hours, minutes, seconds, hunds);

	return;
}

/* ----------------------------------------------------------------------- */

void douline()
{
	register int index;
	double grandusage = 0.0;

	puts("Total task usage:");

	buildlinelist();

	for(index = 0; index < topline; index++)
		grandusage += line_list[index]->timethere;

	for(index = 0; index < topline; index++)
	{
		printf("\t%s %.60s\n\twas executed %lu time%s for ",
			line_list[index]->name, line_list[index]->line,
			line_list[index]->times, plural(line_list[index]->times));
		printtime(line_list[index]->timethere);
		printf(", or %.3f%% of total usage\n\n",
			100.0 * (line_list[index]->timethere / grandusage));
	}

	printf("\n\tTotal time ");
	printtime(grandusage);
	printf("\n\tReport starts on ");
	printdate(startdate);
	printf(" and ends on ");
	printdate(enddate);

	puts("\n");

	putchar(FORMFEED);
	return;
}

/* ----------------------------------------------------------------------- */

void douprog()
{
	register int index;
	double grandusage = 0.0;

	puts("Total program usage:");

	buildproglist();

	for(index = 0; index < topprog; index++)
		grandusage += prog_list[index]->timethere;

	for(index = 0; index < topprog; index++)
	{
		printf("\t%s twas executed %lu time%s for ",
			prog_list[index]->name, prog_list[index]->times,
			plural(prog_list[index]->times));
		printtime(prog_list[index]->timethere);
		printf(", or %.3f%% of total usage\n",
			100.0 * (prog_list[index]->timethere / grandusage));
	}

	printf("\n\tTotal time ");
	printtime(grandusage);
	printf("\n\tReport starts on ");
	printdate(startdate);
	printf(" and ends on ");
	printdate(enddate);

	puts("\n");
	putchar(FORMFEED);
	return;
}

/* ----------------------------------------------------------------------- */

void dodprog()
{
	int daynumber =-1;	/* the day that we're currently listing	*/
	register int index;
	int maxdex, mindex, temp;
	double daytotal;

	puts("Daily program usage:");

	buildproglist();
	openup();

	for (index = 0; index < topprog; index++)
	{
		prog_list[index]->times = 0L;
		prog_list[index]->timethere = 0.0;
	}

	while(!feof(infile))
	{
		readentry();

		if (!(daynumber == -1 || daynumber == cstartday))
		{
			daynumber = cstartday;
			printf("\nFor %d %s 19%d:\n", cstartday,
				month_name[cstartmonth-1],  cstartyear);
			daytotal = 0.0;
			for(index = 0; index < topprog; index++)
				daytotal += prog_list[index]->timethere;
			for(index = 0; index < topprog; index++)
				if(prog_list[index]->timethere != 0.0)
				{
					printf("\t%-8s was run %lu time%s and was active for ",
						prog_list[index]->name,
						prog_list[index]->times,
						plural(prog_list[index]->times));
					printtime(prog_list[index]->timethere);
					printf(" (%.3f%%)\n", 100.0 * prog_list[index]->timethere / daytotal);
				}
			printf("\ttotal usage: ");
			printtime(daytotal);
			puts("\n");
			for (index = 0; index < topprog; index++)
			{
				prog_list[index]->timethere = 0.0;
				prog_list[index]->times = 0L;
			}
		}

		/* find the current program in the list, and tack it on	*/

		maxdex = topprog;
		mindex = 0;

		while(1)
		{
			index = (maxdex + mindex) >> 1;
			temp = stricmp(prog_list[index]->name, cprogname);
			if(temp == 0)
				break;
			if(temp < 0)
				mindex = index;
			else
				maxdex = index;
			if (maxdex == mindex)
			{
				index = maxdex;
				break;
			}
		}
		prog_list[index]->timethere += ctimethere;
		prog_list[index]->times++;
		daynumber = cstartday;
	}

	closedown();

	putchar(FORMFEED);
	return;
}

/* ----------------------------------------------------------------------- */

void dodline()
{
	int daynumber =-1;	/* the day that we're currently listing	*/
	register int index;
	char *temporary;
	int maxdex, mindex, temp;
	double daytotal;

	puts("Daily task usage:");

	freelinelist();
	openup();

	while(!feof(infile))
	{
		readentry();

		if (!(daynumber == -1 || daynumber == cstartday))
		{
			daynumber = cstartday;
			printf("\nFor %d %s 19%d:\n", cstartday,
				month_name[cstartmonth-1],  cstartyear);
			daytotal = 0.0;
			for(index = 0; index < topline; index++)
				daytotal += line_list[index]->timethere;
			for(index = 0; index < topline; index++)
				if(line_list[index]->timethere != 0.0)
				{
					printf("\t%-8s %s\n\twas run %lu time%s and was active for ",
						line_list[index]->name,
						line_list[index]->line,
						line_list[index]->times,
						plural(line_list[index]->times));
					printtime(line_list[index]->timethere);
					printf(" (%.3f%%)\n", 100 * line_list[index]->timethere / daytotal);
				}
			printf("\ttotal usage: ");
			printtime(daytotal);
			puts("\n");
			freelinelist();
		}

		/* find the current program in the list, and tack it on	*/

		daynumber = cstartday;

		for(index = 0; index < topline; index++)
			if(stricmp(line_list[index]->name, cprogname) == 0 &&
			   strnicmp(line_list[index]->line, ccmdline, LINEWID) == 0)
			{
				line_list[index]->times++;
				line_list[index]->timethere += ctimethere;
				goto already;
			}

		line_list[topline] =
			(struct line_entry *) malloc(sizeof(struct line_entry));

		if(line_list[topline] == NULL)
			memoryend();

		if( (temporary = malloc(strlen(cprogname)+2)) == NULL)
			memoryend();

		line_list[topline]->name = temporary;
		strcpy(line_list[topline]->name, cprogname);

		if( (temporary = malloc(strlen(ccmdline)+2)) == NULL)
			memoryend();

		line_list[topline]->timethere = ctimethere;
		line_list[topline]->times = 1L;

		line_list[topline]->line = temporary;
		strcpy(line_list[topline]->line, ccmdline);
		topline++;

		if (topline > MAXLINES)
			memoryend();
already:        ;
	}

	closedown();

	putchar(FORMFEED);
	return;
}

/* ----------------------------------------------------------------------- */

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

/* ----------------------------------------------------------------------- */

int readsysentry()
{
	int retval = 0;
	char *work;

	if( NULL == fgets(readentry_buff, sizeof(readentry_buff), sysfile))
		return(retval);
	syslinenumber++;

	if (strncmp(readentry_buff, "off",3) == 0)
		retval = OFF;
	if (strncmp(readentry_buff, "on ",3) == 0)
		retval = ON;

	if (retval == 0)
		sysinvalid();
	if (retval == ON && lastsysentry == ON)
		return(0);
	if (retval == OFF && lastsysentry == OFF)
		return(0);

	work = &readentry_buff[4];

	if (retval == ON)
	{		/* cure if...else ambiguity	*/
		if ( 7 !=
		sscanf(work, "%d%d%d%d:%d:%d.%d",
			&syson.year, &syson.month, &syson.day,
			&syson.hour, &syson.min, &syson.sec, &syson.hsec))
		sysinvalid();
	}
	else
	{
		if ( 7 !=
		sscanf(work, "%d%d%d%d:%d:%d.%d",
			&sysoff.year, &sysoff.month, &sysoff.day,
			&sysoff.hour, &sysoff.min, &sysoff.sec, &sysoff.hsec))
		sysinvalid();
	}	
	return(retval);
}

/* ----------------------------------------------------------------------- */

void printnjtm(that)
struct njtm *that;
{
	printf("%2.2d %s %4.4d %2.2d:%2.2d:%2.2d.%2.2d",
		that->day, month_name[that->month-1], that->year+1900,
		that->hour, that->min, that->sec, that->hsec);
	return;
}

/* ----------------------------------------------------------------------- */

void dosysuse()
{
	double daytotal = 0.0;		/* system uptime per day	*/
	double grandtotal=0.0;		/* total system uptime		*/
	double dtemp;
	unsigned long thisdate=0L;	/* the day that we're doing	*/
	unsigned long temp;

	openupsys();
	puts("System Usage Totals:");

	while(!feof(sysfile))
		if(readsysentry() == OFF)
		{
			temp = datenumber(syson.month, syson.day, syson.year);
			if (thisdate != temp && thisdate != 0L)
			{	printf("\tSystem usage on ");
				printdate(thisdate);
				printf(" was ");
				printtime(daytotal);
				putchar('\n');
				daytotal = 0.0;
			}

			thisdate = temp;
			dtemp = njtmdiff(&sysoff, &syson);
			grandtotal += dtemp;
			daytotal += dtemp;
		}

	printf("\tSystem usage on ");
	printdate(thisdate);
	printf("was ");
	printtime(daytotal);

	printf("\n   Total system usage: ");
	printtime(grandtotal);
	putchar('\n');

	closedownsys();
	putchar(FORMFEED);
	return;
}

/* ----------------------------------------------------------------------- */

void main(argc, argv)
int argc;
char *argv[];
{
	register int n;

	upto[0] = 0;
	for(n = 1; n<12; n++)
		upto[n] = upto[n-1] + monthlen[n];

	fputs("Nifty James' Famous Program Log Reporter\n", stderr);
	fputs("Version 1.00 of 2 January 1988\n\n", stderr);

	if ( argc == 1 )
	{
showusage:      puts("Usage:\n");
		puts("\tNJPR [/DP] [/DT] [/OP] [/OT] [/SY]\n");
		puts("\t\t/DP - Generates program listing by day");
		puts("\t\t/DT - Generates task listing by day");
		puts("\t\t/OP - Generates overall program listing");
		puts("\t\t/OT - Generates overall task listing");
		puts("\t\t/SY - Generates system usage report\n");
		puts("\t\t(options may appear in any order)");
		exit(1);
	}

	for(n = 1; n<argc; n++)
	{
		if(*argv[n] != '-' && *argv[n] != '/')
			goto showusage;
		if(argv[n][1] == 'D' || argv[n][1] == 'd')
		{
			if(argv[n][2] == 'P' || argv[n][2] == 'p')
				dprog = TRUE;
			else
				if(argv[n][2] == 'T' || argv[n][2] == 't')
					dline = TRUE;
				else
					goto showusage;
		}
		else
		{
			if((argv[n][1] == 'S' || argv[n][1] == 's') &&
			   (argv[n][2] == 'Y' || argv[n][2] == 'y'))
					sys = TRUE;
			else
			{
				if(argv[n][1] != 'O' && argv[n][1] != 'o')
					goto showusage;
				if(argv[n][2] == 'P' || argv[n][2] == 'p')
					uprog = TRUE;
				else
					if(argv[n][2] == 'T' || argv[n][2] == 't')
						uline = TRUE;
					else
						goto showusage;
			}
		}
	}

	if ( (temp = getenv("NJPL")) == NULL )
	{
		fputs("NJPL couldn't be found in the environment.\n", stderr);
		fprintf(stderr, "Enter the drive or directory where the NJPL files can be found: ");
		gets(infilename);
		strcpy(sysfilename, infilename);
	}
	else
	{
		strcpy(sysfilename, temp);
		strcpy(infilename, temp);
	}

	if (infilename[strlen(infilename)] != '\\')
		strcat(infilename, "\\");

	if (sysfilename[strlen(sysfilename)] != '\\')
		strcat(sysfilename, "\\");

	strcat(infilename, "NJPL.PLF");
	strcat(sysfilename,"SYSUSAGE.PLF");

 	if(uline)	douline();
	if(dline)	dodline();
	freelinelist();

	if(uprog)	douprog();
	if(dprog)	dodprog();
	freeproglist();

	if(sys)		dosysuse();
	exit(0);
}

