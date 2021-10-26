
/****************************************************************************
 *                                                                          *
 *  Nifty James' Famous Expression Evaluator                                *
 *  Main Module								    *
 *                                                                          *
 *  Version 1.00 for Microsoft C 5.00 under MS/PC DOS                       *
 *  Version 1.01							    *
 *									    *
 *  Note:  While the VAX switch exists, this sourcecode has not been	    *
 *	  completely modified for the VAX systems.			    *
 *                                                                          *
 *  (C) Copyright 1988 by Mike Blaszczak     1 March 1988		    *
 *                                                                          *
 ***************************************************************************/

#include <malloc.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#ifndef	MSDOS			/* avoid redef error (defined by some
					compilers		*/
#define MSDOS			/* MSDOS version		*/
#endif

/* #define	VAX			/* VAX-11 C 1.5 Version for VMS	*/

/*      list of token types     */

#define NUMBER          1
#define FUNCTION        2
#define BIN_OP          3
#define UNI_OP          4
#define RT_PAREN        5
#define LT_PAREN        6

/*	a macro to make life easier	*/

#define ctoi(ch)        (ch - '0')

/*      the function lists      */

extern double doabs(double);
extern double acos(double);
extern double acot(double);
extern double doacos(double);
extern double doacot(double);
extern double doacsc(double);
extern double doasec(double);
extern double doasin(double);
extern double doatan(double);
extern double docos(double);
extern double docot(double);
extern double dodeg(double);
extern double doexp(double);
extern double dofact(double);
extern double doln(double);
extern double dolog(double);
extern double dopi(double);
extern double dorad(double);
extern double dosec(double);
extern double dosin(double);
extern double dotan(double);

void dumptree();		/* forward declaration	*/

struct functions_entry {
        double (*execute)(double);
        char *name;
        char *describe;
};

struct functions_entry functions_list[] =
{
        {doabs,         "abs",          "absolute value"},
        {doacos,        "acos",         "arccosine"},
        {doacot,        "acot",         "arccotangent"},
        {doacsc,        "acsc",         "arccosecant"},
        {doasec,        "asec",         "arcsecant"},
        {doasin,        "asin",         "arcsine"},
        {doatan,        "atan",         "arctangent"},
        {docos,         "cos",          "cosine"},
        {docot,         "cot",          "cotangent"},
        {dodeg,         "deg",          "convert radians to degrees"},
        {doexp,         "exp",          "e to a power"},
        {dofact,        "fact",         "factorial"},
        {doln,          "ln",           "natural logarithm"},
        {dolog,         "log",          "base 10 logarithm"},
        {dopi,          "pi",           "pi units"},
        {dorad,         "rad",          "convert degrees to radians"},
        {dosec,         "sec",          "secant"},
        {dosin,         "sin",          "sine"},
        {dotan,         "tan",          "tangent"},
        {NULL,          "0",            "0"},
};

/*      how a token is stored           */

struct token {
        int kind;               /*  kind of token this is               */
        double value;           /*  value of a NUMBER                   */
        char oper;              /*  character of BIN_OP or UNI_OP       */
        char *fname;            /*  name of FUNCTION                    */
        int column;             /*  column where this came from         */
        struct token *previous; /*  link to the previous token          */
        struct token *next;     /*  link to the next token              */
};

/* poiners to the head and tail of the list.  gothrough is used to
        walk the list           */

struct token *head, *tail, *gothrough;

/* pointers to the rightmost left parenthesis and the matching leftmost
        right parenthesis, plus one to get there ... used in deciding
        which op to evaluate() next.    */

struct token *rightmost, *leftmost, *walker;

/* before and after are used to greatly simplify unlinking items from
        the list of tokens.                                             */

struct token *after, *before;

int     binvalid;               /* 0 if binary op is vaild in this context */
int     univalid;               /* 0 if unary operator is valid in context */
int     rparen, lparen;         /* count of right and left parenthesis     */

int     topprecedence;          /* precedence of the highst precedence     */

/* this is a list of errors             */

char    *errorlist[] = {
        "Invalid Usage -- check documentation",
#define BAD_CHAR        1
        "Unknown character",
#define BAD_NUMBER      2
        "Invalid number",
#define BIG_EXP         3
        "Exponent is too big",
#define NO_MEMORY       4
        "No more token space",
#define FNO_MEMORY      5
        "No more function space",
#define FBAD_CHAR       6
        "Bad character in function name",
#define FTOO_LONG       7
        "Function name too long",
#define BAD_LPAREN      8
        "Parenthesis don't balance; too many left parenthesis",
#define BAD_RPAREN      9
        "Parenthesis don't balance; too many right parenthesis",
#define BAD_UNI         10
        "Unary operator in bad context",
#define BAD_BIN         11
        "Binary operator in bad context",
#define INTERNAL        12
        "Internal Error!  Go call Nifty!",
#define NO_OPERAND      13
        "No operand for specified operation",
#define NOTHING_2DO     14
        "Nothing between parenthesis",
#define DIV_BY_0        15
        "Division by zero",
#define INV_EXP         16
        "Nonreal exponentiation",
#define UNK_FUNC        17
        "Unknown function",
#define BAD_TRIG        18
        "Out of range value for trig function",
#define BAD_FACT        19
        "Bad value for factorial",
#define BAD_LOG         20
        "Bad value for logarihtm",
#define NO_UNIVAL	21
	"No operator for unary operator",
};

/*      These character lists are valid for each token they name        */
/*      they are in the arrays by order of precedence; lower precedence
        is listed first                                                 */

char vbinops[] = "+-/*%^";              /* valid binary operators       */
char vuniops[] = "-";                   /* valid unary operators        */
char vnum[]    = "0123456789.";         /* valid numbers                */
char func[]    = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";  /* valid function names */

char *work;                     /*  pointer to step through line        */
char line[250];                 /*  line to parse                       */
char progname[15];              /*  our program's name                  */

double result = 0.0;            /* the crux of the biscut               */

/* ---------------------------------------------------------------------- */
/* stores the program's name in the progname array                        */

void setprogname(argv0)
char *argv0;
{
        register char *start, *end;

#ifdef MSDOS
	/* handle DOS <3.0 correctly	*/

	if (strcmp(argv0, "C") == 0)
	{
		strcpy(progname, "NJEVAL");
		return;
	}
#endif

	/*  the name starts after the last backslash	*/
        start = strrchr(argv0, '\\');
	if (start == NULL)
		start = argv0;
	else
		start++;

	/*  and before the period			*/
        end = strrchr(start, '.');
	if (end == NULL)
		end = argv0 + strlen(argv0);

	/* 	copy and uppercase it			*/
        strncpy(progname, start, (end-start));
        strupr(progname);
        return;
}

/* ---------------------------------------------------------------------- */
/* print an error and flag a character; col is offset in line[]           */

void printerrorat(errnum, col)
int errnum, col;
{
        register int ctr;

        printf("%s: error number %d: %s\n%s\n",
                        progname, errnum, errorlist[errnum], line);

	/*	point to specified place	*/
        for(ctr = 1; ctr<col; ctr++)
                putchar(' ');
        puts("^");
        exit(1);
}

/* ---------------------------------------------------------------------- */
/*      print an error and flag the current spot on the line              */

void printerror(errnumber)
int errnumber;
{
        printerrorat(errnumber, (int) (work-line));
}

/* ---------------------------------------------------------------------- */
/* check to see if a value is in [0,1]                                    */

void check01(value)
double value;
{
        if (value > 1.0 || value < 0.0)
                printerror(BAD_TRIG);
        else
                return;
}

/* ---------------------------------------------------------------------- */
/* check to see if a value is in [0,1]                                    */

void check1plus(value)
double value;
{
        if(value < 1.0 && value > -1.0)
                printerror(BAD_TRIG);
        else
                return;
}

/* ---------------------------------------------------------------------- */
/* delete the parenthesis surrounding a term                              */

void killbrackets(place)
struct token *place;
{
        struct token *leftside;
        struct token *rightside;

	/* leftside points to left hand parenthesis, 
	   rightside to the right	*/

        leftside = place->previous;
        rightside = place->next;


	/* before is the token before the parenthesis	*/
	before = leftside->previous;
	/* after is the token after it			*/
	after = leftside->next;
	/* make the token after the parenthesis point back to the
		token before the parenthesis		*/
	after->previous = before;

	/* if this is the first token, change head	*/
        if(leftside == head)
        {
        	head = place;
	        place->previous = NULL;
        }
        else
	/* otherwise, change the one before the parenthesis to
		point to the one after it		*/
        	before->next = after;

	/* same thing, wrong side		*/

	before = rightside->previous;
        after = rightside->next;
        before->next = after;
        if(rightside == tail)
        {
                tail = place;
                place->next = NULL;
        }
        else
                after->previous = before;

#ifdef DEBUG
                dumptree();
#endif

        /* free up that memory */
	free(leftside);
        free(rightside);
        return;
}

/* ---------------------------------------------------------------------- */
/* make a spot for a new token                                            */

struct token *newtoken()
{
        register struct token *temporary;

	/* try to get space	*/
        temporary = malloc(sizeof(struct token));
        if (temporary == NULL)
                printerror(NO_MEMORY);

	/* zero out the new space	*/

        temporary->fname = NULL;
        temporary->value = 0.0;
        temporary->previous = temporary->next = NULL;
        temporary->kind = 0;
        temporary->oper = '\0';
        temporary->column = (int) (work-line);
        return(temporary);
}

/* ---------------------------------------------------------------------- */
/*      display the list                                                  */

void dumptree()
{
#ifdef DEBUG
        register struct token *dumper;

        dumper = head;
        while(dumper != NULL)
        {
                printf("kind = ");
                switch(dumper->kind)
                {
                        case BIN_OP :   puts("binary operator");
                                        break;

                        case UNI_OP :   puts("unary operator");
                                        break;

                        case RT_PAREN:  puts("right parenthesis");
                                        break;

                        case LT_PAREN:  puts("left parenthesis");
                                        break;

                        case NUMBER:    puts("number");
                                        break;

                        case FUNCTION:  puts("function");
                                        break;

                        default:        printf("unknown, type = %d\n",
                                                        dumper->kind);
                }

                printf("fname = ");
                if(dumper->fname == NULL)
                        puts("NULL");
                else
                        printf("\"%s\"\n", dumper->fname);

                printf("oper = '%c'\n", dumper->oper);
                printf("value = %f\n\n", dumper->value);
                dumper = dumper->next;
        }
#endif
        return;
}

/* ---------------------------------------------------------------------- */
/* evaluate a simple expression; place points at the operator or
   function name.  this routine will delete the operands from the
   list and replace the operator with the result of the operation.
   result is also set to the result of the operation, as, if this
   is the last evaluate(), then that's the result of the expression       */

void evaluate(place)
struct token *place;
{
        double operand1, operand2;
        struct token *after, *before, *uniop;
        int evaluated, looker;

	/* if its a number, then what's to do?	*/

        if(place->kind == NUMBER)
        {
                result = place->value;
                return;
        }

	/*  if its not evaluatable, give up	*/

        if(place->kind != BIN_OP && place->kind != UNI_OP &&
                place->kind != FUNCTION)
        {                       /* big trouble in little china! */
                dumptree();
                printerror(INTERNAL);
        }

	/*  before points to the token before the place, after is after it */

        before = place->previous;
        after = place->next;

        switch(place->kind)
        {
        case BIN_OP:            /* evaluate a binary operator   */
                {
                        if(place->next == NULL || place->previous == NULL)
                                printerrorat(NO_OPERAND, place->column);
                        operand1 = place->previous->value;
                        operand2 = place->next->value;
				/* execute operation with operands	*/
                        switch (place->oper)
                        {
                                case '+':       result = operand1+operand2;
                                                break;
                                case '-':       result = operand1-operand2;
                                                break;
                                case '*':       result = operand1*operand2;
                                                break;
                                case '/':       if (operand2 == 0)
                                                        printerrorat(DIV_BY_0, after->column);
                                                result = operand1/operand2;
                                                break;
                                case '%':       if (operand2 == 0)
                                                        printerrorat(DIV_BY_0, after->column);
                                                result = fmod(operand1, operand2);
                                                break;
                                case '^':       result = pow(operand1, operand2);
                                                break;
                                default:        printerror(INTERNAL);
                        }
                }
                break;
        case UNI_OP:    /* evaluate a unary operator    */
                {
                        if(place->next == NULL)
                                printerrorat(NO_OPERAND, place->column);
			uniop = place;
			while(uniop->next->kind != NUMBER)
				if (uniop == NULL)
					printerrorat(NO_UNIVAL, place->column);
				else
					uniop = uniop->next;				
                        operand1 = uniop->next->value;
                        switch (place->oper)
                        {
                                case '-':       result = -operand1;
                                                break;
                                default:        printerror(INTERNAL);
                        }
                }
                break;
        case FUNCTION:  /* evaluate a function  */
                {
                        if(place->next == NULL)
                                printerrorat(NO_OPERAND, place->column);
                        if(place->next->kind != NUMBER)
                                printerror(INTERNAL);

                        operand1 = place->next->value;

                        evaluated = 0;
                        looker = 0;
                        while(functions_list[looker].execute != NULL)
                        {
                                if(strnicmp(functions_list[looker].name, place->fname, 3) == 0)
                                {
                                        result = (*functions_list[looker].execute)(operand1);
                                        evaluated = 1;
                                }
                                looker++;
                        }
                        if(!evaluated)
                                printerrorat(UNK_FUNC, place->column);
                }
                break;
        default:
                        printerror(INTERNAL);
        }

        /* delete operands, as appropriate              */
        switch(place->kind)
        {
                case FUNCTION:
        /* free space used by function name             */
                        free(place->fname);
                        place->fname = NULL;

                        place = place->next;
                        place->value = result;

/*                      killbrackets(place);            */
                        break;
                case BIN_OP:
        /* delete operator and right operand            */
                        before->next = after->next;
                        before->next->previous = before;

        /* change value of right operand to evaluated   */
                        before->value = result;
                        before->kind = NUMBER;

        /* update tail, if need be                      */
                        if(after == tail)
                                tail = before;
                        break;
                case UNI_OP:
			uniop->next->value = result;
			before->next = after;
			after->previous = before;
			break;
                default:
                        printerror(INTERNAL);
        }

#ifdef DEBUG
        printf("%.20g\n", result);
#endif
        return;
}

/* ---------------------------------------------------------------------- */
/*      insert a number into the list                                     */

void getnumber()
{
        double thenumber = 0.0;		/* the number that was there	*/
        double multiplier;		/* weight of the digit read	*/
        int exponent = 0;		/* the exponent we found	*/
        char haddecimal = 0;		/* 1 if we saw '.', 0 otherwise */
        char exponentmode = 0;		/* 1 if we had E | D, 0 other	*/
        struct token *newnumber;	/* pointer to the number token	*/

        for( ; (strchr("0123456789.DE", *work) != NULL) &&
                    *work ; work++)
        {
                if (*work == '.')
                {
                        if (haddecimal || exponentmode)
                                printerror(BAD_NUMBER);
                        haddecimal = 1;
                        multiplier = 0.1;
                        continue;
                }

                if ('0' <= *work && *work <= '9')
                {
                        if(!exponentmode)
                        {
                                if(haddecimal)
                                {
                                        thenumber += multiplier * ctoi(*work);
                                        multiplier /= 10;
                                }
                                else
                                        thenumber = thenumber*10 + ctoi(*work);
                        }
                        else
                        {
				if(*work == '-')
					exponent -= exponent;
				else
				{
	                                exponent = exponent*10 + ctoi(*work);
        	                        if(exponent > 327 || exponent < -327)
                	                        printerror(BIG_EXP);
				}
                        }
                        continue;
                }

                if (*work == 'D' || *work == 'E')
                {
			if (work[1] == '-')
			{
				exponentmode = -1;
				work++;
			}
			else
			{
				if (work[1] == '+')
					work++;
				exponentmode = 1;
			}
                        continue;
                }

        }
        work--;

        newnumber = newtoken();

        newnumber->kind = NUMBER;
        newnumber->value = thenumber * pow(10,exponent*exponentmode);

        if(tail != NULL)
                tail->next = newnumber;
        else
                head = newnumber;
        newnumber->previous = tail;
        tail = newnumber;
        return;
}

/* ---------------------------------------------------------------------- */
/*      insert a binary operator into the list                            */

void getbinop()
{
        register struct token *newbinop;

        newbinop = newtoken();

        newbinop->kind = BIN_OP;
        newbinop->oper = *work;

        if(tail != NULL)
                tail->next = newbinop;
        else
                head = newbinop;
        newbinop->previous = tail;
        tail = newbinop;

        return;
}

/* ---------------------------------------------------------------------- */
/*      insert a unary operator into the list                             */

void getuniop()
{
        register struct token *newuniop;

        newuniop = newtoken();

        newuniop->kind = UNI_OP;
        newuniop->oper = *work;

        if(tail != NULL)
                tail->next = newuniop;
        else
                head = newuniop;
        newuniop->previous = tail;
        tail = newuniop;

        return;
}

/* ---------------------------------------------------------------------- */
/*      put a left parenthesis into the list                              */

void getlp()
{
        register struct token *newleft;

        newleft = newtoken();

        newleft->kind = LT_PAREN;

        if (tail != NULL)
                tail->next = newleft;
        else
                head = newleft;
        newleft->previous = tail;
        tail = newleft;
}

/* ---------------------------------------------------------------------- */
/*      put a right parenthesis into the list                             */

void getrp()
{
        register struct token *newright;

        newright = newtoken();

        newright->kind = RT_PAREN;

        if (tail != NULL)
                tail->next = newright;
        else
                head = newright;
        newright->previous = tail;
        tail = newright;
        return;
}

/* ---------------------------------------------------------------------- */
/*      place a function into the list                                    */

void getfunc()
{
        struct token *newfunc;
        char myname[80];
        int mynamelen = 0;
        char *resting;

        while(1)
        {
                if(*work == '(')
                        break;
                if(*work > 'Z' || *work < 'A')
                        printerror(FBAD_CHAR);
                myname[mynamelen++] = *work;
                if(mynamelen > 70)
                        printerror(FTOO_LONG);
                work++;
        }
        myname[mynamelen++] = '\0';

        newfunc = newtoken();
        newfunc->kind = FUNCTION;
        if (tail != NULL)
                tail->next = newfunc;
        else
                head = newfunc;
        newfunc->previous = tail;
        tail = newfunc;

        resting = (char *) malloc(mynamelen+2);
        if (resting == NULL)
                printerror(FNO_MEMORY);

        strcpy(resting, myname);
        newfunc->fname = resting;
        lparen++;
        return;
}

/* ---------------------------------------------------------------------- */
/*      this function returns the integral precedence value of the
        operator in the token record pointed to by place.  note that
        binary operators have lower precedences than unary operators.
        lower precedence has a return value closer to zero.             */
int precedenceof(place)
struct token *place;
{
        if(place->kind == UNI_OP)
                return(strchr(vuniops, place->oper) - vuniops + 100);
        else
                return(strchr(vbinops, place->oper) - vbinops + 1);
}

/* ---------------------------------------------------------------------- */

void main(argc, argv)
int argc;
char *argv[];
{
        int n;

        setprogname(argv[0]);

        puts("Nifty James' Famous Evaluator");
        puts("Version 1.01 of 1 March 1988");
        puts("(C) Copyright 1988 by Mike Blaszczak\n");

/* get the command line all into line[] */

#ifdef MSDOS
        line[0] = '\0';
        work = line;
        for(n = 1; n<argc; n++)
                strcat(line, argv[n]);
#endif

#ifdef VAX
	gets(line);
#endif
        strupr(line);

        if(strlen(line) == 0)
        {
                puts("\nUsage:\n");
                puts("\tnjeval <expression>\n");
                puts("\t<expression> may include numbers, both inplicit and scientific");
                puts("\t\tas well as the operators +, -, /, %, *, and ^, and may use");
                puts("\t\tthe following functions:\n");
                for(n=0; functions_list[n].execute != NULL; n++)
                        printf("\t\t%s()\t%s\n", functions_list[n].name, functions_list[n].describe);
                putchar('\n');
                printerror(0, 1);
        }

        binvalid = 0;           /* initialize parser state      */
        univalid = 1;
        rparen = 0;
        lparen = 0;

        head = NULL;
        tail = NULL;

/* start it with a left parenthesis     */

        getlp();

/* zip through the list, handling all the characters and placing tokens
        into the list, if need be.              */

        for( ; *work ; work++)
        {
/* whitespace */

                if(*work == ' ' || *work == '\t')
                        continue;

/* number */

                if(strchr(vnum, *work) != NULL)
                {
                        getnumber();
                        univalid = 0;
                        binvalid = 1;
                        continue;
                }

/* unary operator */

                if(strchr(vuniops, *work) != NULL)
                {
                        if(!univalid)
                        {
                                if(strchr(vbinops, *work) == NULL)
                                        printerror(BAD_UNI);
                        }
                        else    /* fall through to binop if it is that
                                        context         */
                        {
                                getuniop();
                                univalid = 1;
                                binvalid = 0;
                                continue;
                        }
                }

/* binary operator              */

                if(strchr(vbinops, *work) != NULL)
                {
                        getbinop();
                        univalid = 1;
                        binvalid = 0;
                        continue;
                }

/* left parenthesis             */

                if(*work == '(')
                {
                        getlp();
                        univalid = 1;
                        binvalid = 0;
                        lparen++;
                        continue;
                }

/*  right parenthesis           */

                if(*work == ')')
                {
                        getrp();
                        univalid = 0;
                        binvalid = 1;
                        rparen++;
                        continue;
                }

/*   function name              */
/*   NOTE THAT FUNCTION NAMES MUST END IN (,
        and that getfunc() will add a '(' to
        the token list                          */

                if('A' <= *work && *work <= 'Z')
                {
                        getfunc();
                        univalid = 1;
                        binvalid = 0;
                        continue;
                }

                printerror(BAD_CHAR);
        }

        getrp();                /* surround expression with parenthesis */

        /* check to see that there is a valid number of parenthesis     */

        if(lparen > rparen)
                printerrorat(BAD_LPAREN, strchr(line, '(')-line+1);
        if(lparen < rparen)
                printerrorat(BAD_RPAREN, strrchr(line, ')')-line+1);

        dumptree();

        if (head->next != tail->previous)
        {
                /* if there's something to evaluate, do it!             */
                /* (but first wipe out unneeded parenthesis             */

        walker = head->next;

        while(walker != tail)
        {
                if(walker->kind == NUMBER && walker->previous->kind == LT_PAREN
                        && walker->next->kind == RT_PAREN)
                        killbrackets(walker);
                walker = walker->next;
        }

        while(head != tail)
        {
                walker = leftmost = head;
                if(leftmost->next->kind == RT_PAREN)
                        printerrorat(NOTHING_2DO, leftmost->column);
                while(walker->kind != RT_PAREN)
                {
                        if (walker->kind == LT_PAREN || walker->kind == FUNCTION)
                        {
                                leftmost = walker;
                                if(leftmost->next->kind == RT_PAREN)
                                        printerrorat(NOTHING_2DO, leftmost->column);
                        }
                        walker = walker->next;
                }

                rightmost = walker;
                topprecedence = 0;
                gothrough = leftmost->next;
                walker = leftmost;

                if(leftmost->kind == FUNCTION && leftmost->next == rightmost->previous)
                {
                        evaluate(leftmost);
                        killbrackets(leftmost->next);
                }
                else
                {
                        while(walker != rightmost)
                        {
                                if((walker->kind == BIN_OP || walker->kind == UNI_OP)
                                        && (topprecedence < precedenceof(walker)))
                                {
                                        gothrough = walker;
                                        topprecedence = precedenceof(walker);
                                }
                                walker = walker->next;
                        }
                        evaluate(gothrough);

        /* if we have just (constant), then delete the parenthesis      */
                        if(leftmost->next == rightmost->previous)
                        {

        /* if they're our original (), then we're done!                 */
                                if(leftmost == head && rightmost == tail)
                                        break;
                                if (leftmost->kind != FUNCTION)
        /* otherwise, wipe them out                                     */
                                killbrackets(leftmost->next);
                }
                }

#ifdef DEBUG
                printf("Head = %p\nTail = %p\nRightmost = %p\nLeftmost = %p\n",
                        (void far *) head, (void far *) tail,
                        (void far *) rightmost, (void far *) leftmost);
#endif
        }
        }
        else
                result = head->next->value;

        printf("%s = %.20g\n", line, result);

#ifdef MSDOS
        exit(0);
#else
	return;
#endif
}
