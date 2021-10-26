/*  dumptwo.c	*/

#include <stdio.h>
#include <string.h>
#include <mytypes.h>
#include "njdump.h"

extern  int min(int, int);

/* ----------------------------------------------------------------------- */

		/* handle an ENDREC		*/

void doendrec()
{
	int	typ;

	writeheader();
	getlen();

	typ = fgetc(infile);

	switch(typ)	{
		case 0:	printf("*** End of overlay ***");
			break;
		case 1: printf("*** End of block ***");
			break;
		default:printf("*** INVALID ENDREC TYPE ***");
	}

	printf("\n\n");
	checksum += typ;

	checkit();
	return;
}


