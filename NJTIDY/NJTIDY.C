/***************************************************************************
*									   *
*	Nifty James' Famous Disk Tidy Program				   *
*									   *
*	(C) Copyright 1987 by Mike Blaszczak All Rights Reserved	   *
*									   *
*	Version 1.00 of  7 December 1987				   *
*	Version 1.10 of 18 December 1987				   *
*	Version 2.00 of 19 January  1988				   *
*	Version 2.10 of 26 January  1988				   *
*	Written for the Microsoft Optimizing C Compiler, Version 5.00	   *
*			(Use the COMPACT model)				   *
*									   *
***************************************************************************/

#include <dos.h>
#include <malloc.h>
#include <stdio.h>
#include <string.h>

#include <noenv.h>

#define MAXEXT		64
#define	MAXSTACK	7168
#define	MAX_PATH_LEN	64

unsigned scrap;				/* temporary var for _dos call	*/
unsigned olddrive;			/* current drive at start	*/

char	*extlist[MAXEXT];		/* list of extensions to del	*/
int	topext = 1;			/* first free ext entry		*/

int	deleteit;			/* flag for work loop		*/

char    *subdirlist[MAXSTACK];		/* list of subdirectories 	*/
int     topdir = 1;			/* first free subdirlist entry	*/
int	worktop = 0;			/* used as iteration counter	*/

int	index;				/* loop variable		*/
int	extents;			/* loop through extensions	*/

char	tempname[MAX_PATH_LEN];		/* temporary name for file dels */

long	deleted =0L;			/* number of files deleted	*/
unsigned long totalbytes =0L;		/* number of bytes freed	*/

unsigned        result;			/* result of _dos operations	*/
struct  find_t  c_file;			/* structure for _dos ops	*/

int	confirm_mode = 0;		/* set to 1 if we should ask	*/

int	returnval;			/* return from deleteone()	*/

/* ---------------------------------------------------------------------- */ 

int deleteone(n)
int n;
{
	register int tempval;
	int reply;
	int thischar;

	strcpy(tempname, subdirlist[n]);
	tempname[strlen(tempname)-3] = '\0';
	strcat(tempname, c_file.name);

	if (confirm_mode == 1)
	{
		printf("Delete file %s? (Y/N/Q)  ", tempname);
		while(1)
		{
			thischar = 0;
			while(thischar == 0)
			{
				thischar = getch();
				thischar = toupper(thischar);
				if (thischar != 'N' && thischar != 'Y' &&
					thischar != 'Q')
				{
					thischar = 0;
					continue;
				}
				reply = thischar;
				break;
			}

			switch (reply)
			{
				case 'Q' :	printf("Quit");
						break;
				case 'Y' :	printf("Yes");
						break;
				case 'N' :	printf("No");
						break;
			}

			thischar = 0;
			while(thischar == 0)
			{
				thischar = getch();
				if (thischar == '\b')
				{
					printf("\b\b  \b\b");
					if (reply == 'Y')
						printf("\b \b");
					if (reply == 'Q')
						printf("\b\b  \b\b");
					reply = 0;
					continue;
				}
				if (thischar == '\r')
					goto gotanswer;
			}
		}
gotanswer:	if (reply == 'N')
			return(0);
		if (reply == 'Q')
		{
			putch('\n');
			return(-1);
		}
	}
	else
		printf("Deleting file %s", tempname);
	tempval = remove(tempname);

	if(tempval == -1)
		printf(" (couldn't remove file) ");

	return(tempval);
}	

/* ---------------------------------------------------------------------- */ 

void main(argc, argv)
int argc;
char *argv[];
{
	puts("Nifty James' Famous Disk Tidier");
	puts("Version 2.10 of 26 January 1988");
	puts("(C)Copyright 1987, 1988 by Mike Blaszczak\n");

	_dos_getdrive(&olddrive);

	subdirlist[0] = "\\*.*";
	extlist[0] = ".BAK";

	for(extents = 1; extents<argc; extents++)   {
		strupr(argv[extents]);

		if (*argv[extents] == '-' || *argv[extents] == '/')
		{
			if (argv[extents][1] == 'P')
			{
				confirm_mode = 1;
				continue;
			}
			else
			{
showusage:			puts("Usage:\n\t");
				puts("NJTIDY <drivespec> [/P] <extlist>\n");
				exit(1);
			}
		}

		if (strchr(argv[extents], ':') != NULL)
		{
			_dos_setdrive(*argv[extents]-'A'+1, &scrap);
			_dos_getdrive(&scrap);
			if (scrap != *argv[extents]-'A'+1)
			{
				puts("NJTIDY: Invalid drive name");
				exit(1);
			}
			continue;
		}

		if (topext == MAXEXT)
			goto outmem;
		if (NULL == (extlist[topext] = (char *) malloc(strlen(argv[extents])+5)) )
			goto outmem;
		strcpy(extlist[topext], ".");
		strcat(extlist[topext++], argv[extents]);
	}

	while(worktop<topdir)	{	

	result = _dos_findfirst(subdirlist[worktop], _A_SUBDIR, &c_file);

		while(result == 0)
		{
			if (c_file.name[0] != '.' &&
			    c_file.attrib == _A_SUBDIR)
			{
				if ( topdir == MAXSTACK ||
				    (subdirlist[topdir] = (char *) malloc(MAX_PATH_LEN)) == NULL )
				{
outmem:					puts("NJTIDY: Out of memory error\n");
					exit(1);
				}
				strcpy(subdirlist[topdir], subdirlist[worktop]);
				subdirlist[topdir][strlen(subdirlist[topdir])-3] = '\0';
				strcat(subdirlist[topdir], c_file.name);
				strcat(subdirlist[topdir++], "\\*.*");
			}
			result = _dos_findnext(&c_file);
		}
		worktop++;
	}

	for(index = 0; index < topdir; index++)
	{
		result = _dos_findfirst(subdirlist[index], _A_NORMAL, &c_file);

		while(result == 0)
		{
			if (c_file.size == 0L && c_file.attrib != _A_SUBDIR)
			{
				returnval = deleteone(index);
				if( returnval == -1)
					goto bailout;
				if( returnval == 0)
				{
					deleted++;
					continue;
				}
			}

			deleteit = 0;

			for (extents = 0; extents < topext; extents++)
				if (strstr(c_file.name, extlist[extents]) != NULL)
				{
					deleteit = 1;
					break;
				}

			if (deleteit == 1)
			{
				returnval = deleteone(index);
				if (returnval == -1)
					goto bailout;
				if (returnval == 0)
				{
					putchar('\n');
					deleted++;
					totalbytes += c_file.size;
				}
			}
			result = _dos_findnext(&c_file);
		}
	}		

bailout:
	if(deleted == 0L)
		puts("\nNo files were deleted\n");
	else
		printf("\n%ld files were deleted for a total of %lu bytes freed.\n",
			deleted, totalbytes);

	_dos_setdrive(olddrive, &scrap);
	exit(0);
}

