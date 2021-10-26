
/****************************************************************************
 *									    *
 *  Nifty James' Famous Expression Evaluator				    *
 *  Function Module							    *
 *									    *
 *  Version 1.00 for Microsoft C 5.00 under MS/PC DOS			    *
 *  Version 1.01							    *
 *									    *
 *  (C) Copyright 1988 by Mike Blaszczak     1 March 1988		    *
 *									    *
 ***************************************************************************/

#include <math.h>

#define	PI_DEFINED	(atan(1.0)*4.0)

#define BAD_CHAR        1
#define BAD_NUMBER      2
#define BIG_EXP         3
#define NO_MEMORY       4
#define FNO_MEMORY      5
#define FBAD_CHAR       6
#define FTOO_LONG       7
#define BAD_LPAREN      8
#define BAD_RPAREN      9
#define BAD_UNI         10
#define BAD_BIN         11
#define INTERNAL        12
#define NO_OPERAND      13
#define NOTHING_2DO	14
#define DIV_BY_0	15
#define INV_EXP		16
#define UNK_FUNC	17
#define BAD_TRIG	18
#define BAD_FACT	19
#define BAD_LOG		20

extern void check01(double);
extern void check1plus(double);

/* ----------------------------------------------------------------------- */

double doabs(passed)
double passed;
{
	return(fabs(passed));
}

/* ----------------------------------------------------------------------- */

double doacos(passed)
double passed;
{
	check01(passed);
	return(acos(passed));
}

/* ----------------------------------------------------------------------- */

double doacot(passed)
double passed;
{
	if(passed == 0)
		return(PI_DEFINED/2);
	return(atan(1.0/passed));
}

/* ----------------------------------------------------------------------- */

double doacsc(passed)
double passed;
{
	check1plus(passed);
	return(asin(1.0/passed));
}

/* ----------------------------------------------------------------------- */

double doasec(passed)
double passed;
{
	check1plus(passed);
	return(acos(1.0/passed));
}

/* ----------------------------------------------------------------------- */

double doasin(passed)
double passed;
{
	check01(passed);
	return(asin(passed));
}

/* ----------------------------------------------------------------------- */

double doatan(passed)
double passed;
{
	return(atan(passed));
}

/* ----------------------------------------------------------------------- */

double docos(passed)
double passed;
{
	return(cos(passed));
}


/* ----------------------------------------------------------------------- */

double docot(passed)
double passed;
{
	if(sin(passed) == 0)
		printerror(BAD_TRIG);
	return(1.0/tan(passed));
}

/* ----------------------------------------------------------------------- */

double dodeg(passed)
double passed;
{
	return(passed*180.0/PI_DEFINED);
}

/* ----------------------------------------------------------------------- */

double doexp(passed)
double passed;
{
	return(exp(passed));
}

/* ----------------------------------------------------------------------- */

double dofact(passed)
double passed;
{
	double result = 1.0;
	int counter;

	if (passed != floor(passed))
		printerror(BAD_FACT);

	counter = (int) result;
	for(counter = 2; counter<=passed; counter++)
		result *= counter;
	return(result);
}

/* ----------------------------------------------------------------------- */

double doln(passed)
double passed;
{
	if(passed < 1.0)
		printerror(BAD_LOG);
	return(log(passed));
}

/* ----------------------------------------------------------------------- */

double dolog(passed)
double passed;
{
	if(passed < 1.0)
		printerror(BAD_LOG);
	return(log10(passed));
}

/* ----------------------------------------------------------------------- */

double dopi(passed)
double passed;
{
	return(PI_DEFINED*passed);
}

/* ----------------------------------------------------------------------- */

double dorad(passed)
double passed;
{
	return(passed*PI_DEFINED/180.0);
}

/* ----------------------------------------------------------------------- */

double dosec(passed)
double passed;
{
	double temp;

	temp = cos(passed);
	if(temp == 0)
		printerror(BAD_TRIG);
	return(1.0/temp);
}

/* ----------------------------------------------------------------------- */

double dosin(passed)
double passed;
{
	return(sin(passed));
}

/* ----------------------------------------------------------------------- */

double dotan(passed)
double passed;
{
	if (cos(passed) == 0)
		printerror(BAD_TRIG);
	return(tan(passed));
}

