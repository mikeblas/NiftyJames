
  
/* --------------------------------------------------------------------------
   Nifty James' Famous File Find Utility

   Version 1.00 of 20 November 1989
   Version 1.10 of 16 December 1989
   Version 1.11 of  5 January  1990
   Version 1.12 of 13 February 1990
   Version 1.50 of 25 March    1990
   Version 2.00 of  3 April    1990
	Version 2.10 of 25 August   1991 

   (C) Copyright 1989, 1990, 1991 by Mike Blaszczak
   All Rights Reserved.

   Written for the Microsoft C Compiler Version 6.00AX.
   LINK with an increased stack size!
*/


/* --------------------------------------------------------------------------
   Needed #include Files
*/

#pragma pack(1)                           /* don't space structure members */
#include <ctype.h>
#include <dos.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include	<time.h>

#define  byte     unsigned char
#define  word     unsigned int
#define  dword    unsigned long
#define  boolean  char
#define  TRUE     (1==1)
#define  FALSE    (!TRUE)

#define ELEMENTS(array) (sizeof(array)/sizeof(array[0]))

/* --------------------------------------------------------------------------
   Structures used here
*/

struct   fullfilename               /* used internally to hold filenames   */
{
   char  filename[9];
   char  fileextension[4];
};


/* This is the "local file header" for zip files.  The zip_lfh structure
   preceeds each file in the ZIP file, and describes the individual files
   stored there.  Note that we read one of these and then fseek() over it
   by using the value in zip_lfh.csize to get the new area.
*/

struct   zip_lfh
{
   dword signature;                 /* signature, must be 0x04034B50       */
   word  exversion;                 /* version needed to extract           */
   word  bitflags;                  /* general purpose bit flags           */
   word  compression;               /* compression method                  */
   word  modtime;
   word  moddate;                   /* last modification time and date     */
   dword crc32;                     /* crc32 filecheck for file            */
   dword csize;                     /* compressed size                     */
   dword usize;                     /* uncompressed size                   */
   word  fnlength;                  /* filename length                     */
   word  extralength;               /* extra field length                  */
};

/* This is the "local file header" for ARC files.  The arc_lfh structure
   preceeds each file in the ARC file, and describes the individual files
   stored there.  Note that we read one of these and then fseek() over
   the compressed file by using the value arc_lfh.csize to get the new
   area.

   Note that ARC and PAK files use this same structure!
*/

struct   arc_lfh
{
   byte  marker;                    /* always 01Ah                         */
   byte  compression;               /* how was this file stored?           */
   char  filename[13];              /* filename is always 13 long          */
   dword csize;                     /* compressed size                     */
   word  date;                      /* date of original file               */
   word  time;                      /* time of original file               */
   word  crc;                       /* sixteen-bit CRC for this file       */
   dword usize;                     /* uncompressed size                   */
};


struct   lzh_lfh
{
   byte  unknown[7];                /* unknown area                        */
   dword csize;                     /* compressed size                     */
   dword usize;                     /* original size                       */
   word  time;                      /* last modification of date and time  */
   word  date;                      /*     of the stored file              */
   byte  unknown3[2];
   byte  fnlength;                  /* length of file name                 */
};


struct   zoo_lfh
{
   word  time;                      /* last modification of date and time  */
   word  date;                      /*     of the stored file              */       
   word  unknownword;
   dword usize;                     /* original file size                  */
   dword csize;                     /* compressed size                     */
   byte  unknown[10];               /* unknown area ...                    */
   char  filename[13];              /* ASCIIZ filename                     */
};

struct   dwc_lfh
{
   char  name[13];                  /* file name                           */
   dword size;                      /* original size                       */
   dword time;                      /* file timestamp                      */
   dword new_size;                  /* compressed size                     */
   dword pos;                       /* fseek() of this file in archive     */
   byte  method;                    /* compression code                    */
   byte  comment_size;              /* length of file comment              */
   byte  directory_size;            /* length of directory name tag        */
   word  crc;                       /* file CRC value                      */
};


/* DWC files are different because they have a big archive-wide information
   area that NJFIND needs to use.  This is defined in dwc_block.
*/

struct   dwc_block
{
   word  size;                      /* size of this structure              */
   byte  ent_sz;                    /* size of dwc_lfh structure           */
   char  header[13];                /* name of header file for listings    */
   dword time;                      /* timestamp of last archive change    */
   dword entries;                   /* entries in the archive              */
   char  id[3];                     /* "DWC" to identify archive           */
};


/*	ARJ files are even stranger; they have their own information block
   which is defined here, starting in Version 2.10.
*/

struct	arj_lfh
{
	unsigned int	wHeaderID;
	unsigned int	wBasicHeaderSize;
	unsigned char	bFirstHeaderSize;
	unsigned char	bArchiverVersionNumber;
   unsigned char  bMinimumToExtract;
	unsigned char	bHostOS;
	unsigned char	bARJFlags;
	unsigned char	bMethod;
	unsigned char	bFileType;
	unsigned char	bReserved;
	unsigned long	dwDateTimeStamp;
	unsigned long	dwCompressedSize;
	unsigned long	dwOriginalSize;
	unsigned long	dwOriginalFileCRC;
	unsigned int	wEntryNamePos;
	unsigned int	wFileAccessMode;
	unsigned int	wHostData;
};



/* --------------------------------------------------------------------------
   Global Variables
*/

unsigned       result;              /* stored result of _dos_find*() calls */
char           *temp;               /* temporary pointer for strings       */
char           *extension;          /* pointer to file extension           */
char           template[_MAX_PATH]; /* template to match files searched    */
char           *inputfile;          /* pointer to wildcard name            */

struct fullfilename
               tempfullname,        /* full name of file we're working on  */
               matchname;           /* name to match                       */

unsigned       found =0;            /* count of found files                */
unsigned long  totallength = 0L;    /* total of file lengths               */

unsigned       archivefound = 0;    /* count of found files in archves     */
unsigned long  archivetotallength = 0L;
                                    /* total file lengths of archive files.*/

struct zip_lfh zipworker;           /* workspace for zip files             */
struct arc_lfh arcworker;           /* workspace for arc files             */
struct lzh_lfh lzhworker;           /* workspace for lzh files             */
struct zoo_lfh zooworker;           /* workspace for zoo files             */

boolean        searchzips = TRUE;   /* flags for options on searching      */
boolean        searchlzhs = TRUE;   /*    the different archive types      */
boolean        searchzoos = TRUE;
boolean        searcharcs = TRUE;
boolean        searchpaks = TRUE;
boolean        searchdwcs = TRUE;
boolean			searcharjs = TRUE;

boolean        verbose = FALSE;     /* TRUE for verbose mode               */
boolean        progress = FALSE;    /* TRUE to show progress               */
boolean        totalsmode = FALSE;  /* TURE for display totals             */
boolean        changedrive = FALSE; /* set TRUE if user changed disks      */

boolean        broken = FALSE;      /* set true if user does CTRL+BREAK    */

boolean        alldrives = FALSE;   /* search through all drives           */

char           fiftyspaces[55];     /* a bunch of spaces for printmatch()  */

unsigned       drivecount;          /* used to change disk drives          */
unsigned       newdrive;
unsigned       olddrive;
unsigned       lastdrive;
char           newdriveletter[3];

char           drivelist[28];       /* list of drives to search            */
char           *currentdrive;

char  			szFileNameBuffer[4096];


/* --------------------------------------------------------------------------
   Global Constants
*/

const char     *fmessageread  = "Couldn't open file \"%s\" for read.\n";
const char     *readbinary    = "rb";
const char     *notsearching  = "Not searching %s files\n";
const char     *eraseline     = "\t\t\t\t\t\t\t\t\t\r";
const char     *wfi           = " was found in ";
const char     *swfis         = "%s was found in %s%s";

const char *month3names[12] =
{
   "Jan", "Feb", "Mar", "Apr", "May", "Jun",
   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
};


/* --------------------------------------------------------------------------
   ANSI-C Standard Function Prototypes
*/

void  processzip(char *filename, struct find_t *info);
void  processpak(char *filename, struct find_t *info);
void  processarc(char *filename, struct find_t *info);
void  processlzh(char *filename, struct find_t *info);
void  processzoo(char *filename, struct find_t *info);
void  processdwc(char *filename, struct find_t *info);
void	processarj(char *filename, struct find_t *info);

void  printinside(char *filename, char *archive, dword filesize, word date, word time);
void  printinsidedwc(char *filename, char *archive, dword filesize, time_t date);
void  printmatch(char *filename, dword filesize, word date, word time);
void  printdate(word date);
void  printtime(word time);
int   comparenames(struct fullfilename *left, struct fullfilename *right);
void  maketemplate(void);
void  makefullname(struct fullfilename *ffn, char *path);
void  searchdir(char *dirname);
void  showusage(void);
void  handleoption(char *option, boolean inenvironment);
void  breakout(void);
void  builddrivelist(void);
void  handleenvironment(void);
void  main(int argc, char *argv[]);


/* --------------------------------------------------------------------------
*/

void  processzip(char *filename, struct find_t *info)
{
   FILE                 *zipfile;
   char                 *insidefilename = NULL;
   struct fullfilename  zipfullname;
   char                 *temporary;

#if defined(DEBUG)
   printf("processzip(\"%s\")\n", info->name);
#endif

   /* if the file name doesn't match the requested template name,
      return now and don't even bother opening the zip file.
   */

   if (comparenames(&tempfullname, &matchname) == 0)
      {
      found++;
      if (totalsmode == FALSE)
         if (verbose == TRUE)
            printmatch(filename, info->size, info->wr_date, info->wr_time);
         else
            printf("%s%s\n", newdriveletter, filename);

      totallength += info->size;
      }

   if (searchzips == FALSE)
      return;

   /* open the zip file by name and see if it was successful.
   */

   zipfile = fopen(filename, readbinary);
   if (zipfile == NULL)
      {
      fprintf(stderr, fmessageread, filename);
      return;
      }

   /* loop through the whole file
   */

   while(!feof(zipfile))
      {
   /* read the local file header.
      if we don't get it, break the loop.
      At this same time, check it for a valid signature.
   */

      if (fread(&zipworker, sizeof(struct zip_lfh), (size_t) 1, zipfile) != 1)
         break;

      if (zipworker.signature != 0x04034B50)
         break;

   /* free the temporary file name area
      and allocate a space for the new name.
      read it from the zip file.
   */
      insidefilename = szFileNameBuffer;

      if (fread((void *) insidefilename,  zipworker.fnlength, (size_t) 1, zipfile) != 1)
         break;
      insidefilename[zipworker.fnlength] = '\0';

      temporary = strrchr(insidefilename, '/');
      if (temporary != NULL)
         temporary++;
      else
         temporary = insidefilename;

      makefullname(&zipfullname, temporary);
      if (comparenames(&zipfullname, &matchname) == 0)
         {
         archivefound++;
         archivetotallength += zipworker.usize;
         if (totalsmode == FALSE)
            if (verbose == TRUE)
               printinside(filename, temporary, zipworker.usize,
                  zipworker.moddate, zipworker.modtime);
            else
               {
               printf(swfis, temporary, newdriveletter, filename);
               putchar('\n');
               }
         }
      else
         if (progress == TRUE)
            printf("%s%s\t\t\r", newdriveletter, temporary);

#if defined(DEBUG)
      printf("temporary = \"%s\"\n", temporary);
#endif

   /* seek around the compressed file.
   */
      fseek(zipfile, zipworker.csize + zipworker.extralength, SEEK_CUR);

   /* at this point, the file pointer is once again at the
      next local file header ...
   */
      }


   if (progress == TRUE)
      printf(eraseline);
   fclose(zipfile);
   return;
}


/* --------------------------------------------------------------------------
*/

void  processpak(char *filename, struct find_t *info)
{
   FILE                 *pakfile;
   struct fullfilename  pakfullname;

#if defined(DEBUG)
   printf("processpak(\"%s\")\n", info->name);
#endif

   /* if the file name doesn't match the requested template name,
      return now and don't even bother opening the zip file.
   */

   if (comparenames(&tempfullname, &matchname) == 0)
      {
      found++;
      if (totalsmode == FALSE)
         if (verbose == TRUE)
            printmatch(filename, info->size, info->wr_date, info->wr_time);
         else
            printf("%s%s\n", newdriveletter, filename);
      totallength += info->size;
      }

   if (searchpaks == FALSE)
      return;

   /* open the pak file by name and see if it was successful.
   */

   pakfile = fopen(filename, readbinary);
   if (pakfile == NULL)
      {
      fprintf(stderr, fmessageread, filename);
      return;
      }

   /* loop through the whole file
   */

   while(!feof(pakfile))
      {
   /* read the local file header.
      if we don't get it, break the loop.
   */

      if (fread(&arcworker, sizeof(struct arc_lfh), (size_t) 1, pakfile) != 1)
         break;

   /* check the compression method.
      if it is zero, the pak file is over.
   */

      if (arcworker.compression == 0)
         break;

      makefullname(&pakfullname, arcworker.filename);
      if (comparenames(&pakfullname, &matchname) == 0)
         {
         archivefound++;
         archivetotallength += arcworker.usize;
         if (totalsmode == FALSE)
            if (verbose == TRUE)
               printinside(filename, arcworker.filename, arcworker.usize,
                  arcworker.date, arcworker.time);
            else
               {
               printf(swfis, arcworker.filename, newdriveletter, filename);
               putchar('\n');
               }
         }
      else
         if (progress == TRUE)
            printf("%s\t\t\r", arcworker.filename);

#if defined(DEBUG)
      printf("filename = \"%s\"\n", arcworker.filename);
#endif

   /* seek around the compressed file.
   */
      fseek(pakfile, arcworker.csize, SEEK_CUR);

   /* at this point, the file pointer is once again at the
      next local file header ...
   */
      }

   if (progress == TRUE)
      printf(eraseline);
   fclose(pakfile);
   return;
}


/* --------------------------------------------------------------------------
*/

void  processarc(char *filename, struct find_t *info)
{
   FILE                 *arcfile;
   struct fullfilename  arcfullname;

#if defined(DEBUG)
   printf("processarc(\"%s\")\n", info->name);
#endif

   /* if the file name doesn't match the requested template name,
      return now and don't even bother opening the zip file.
   */

   if (comparenames(&tempfullname, &matchname) == 0)
      {
      found++;
      if (totalsmode == FALSE)
         if (verbose == TRUE)
            printmatch(filename, info->size, info->wr_date, info->wr_time);
         else
            printf("%s%s\n", newdriveletter, filename);
      totallength += info->size;
      }

   if (searcharcs == FALSE)
      return;

   /* open the arc file by name and see if it was successful.
   */

   arcfile = fopen(filename, readbinary);
   if (arcfile == NULL)
      {
      fprintf(stderr, fmessageread, filename);
      return;
      }

   /* loop through the whole file
   */

   while(!feof(arcfile))
      {
   /* read the local file header.
      if we don't get it, break the loop.
   */

      if (fread(&arcworker, sizeof(struct arc_lfh), (size_t) 1, arcfile) != 1)
         break;

   /* check the compression method.
      if it is zero, the pak file is over.
   */

      if (arcworker.compression == 0)
         break;

      makefullname(&arcfullname, arcworker.filename);
      if (comparenames(&arcfullname, &matchname) == 0)
         {
         archivefound++;
         archivetotallength += arcworker.usize;
         if (totalsmode == FALSE)
            if (verbose == TRUE)
               printinside(filename, arcworker.filename, arcworker.usize,
                  arcworker.date, arcworker.time);
            else
               {
               printf(swfis, arcworker.filename, newdriveletter, filename);
               putchar('\n');
               }
         }
      else
         if (progress == TRUE)
            printf("%s\t\t\r", arcworker.filename);

#if defined(DEBUG)
      printf("filename = \"%s\"\n", arcworker.filename);
#endif

   /* seek around the compressed file.
   */
      fseek(arcfile, arcworker.csize, SEEK_CUR);

   /* at this point, the file pointer is once again at the
      next local file header ...
   */
      }

   if (progress == TRUE)
      printf(eraseline);
   fclose(arcfile);
   return;
}


/* --------------------------------------------------------------------------
*/

void  processlzh(char *filename, struct find_t *info)
{
   FILE                 *lzhfile;
   char                 *insidefilename = NULL;
   struct fullfilename  lzhfullname;
   char                 *temporary;

#if defined(DEBUG)
   printf("processlzh(\"%s\")\n", info->name);
#endif

   /* if the file name doesn't match the requested template name,
      return now and don't even bother opening the lzh file.
   */

   if (comparenames(&tempfullname, &matchname) == 0)
      {
      found++;
      if (totalsmode == FALSE)
         if (verbose == TRUE)
            printmatch(filename, info->size, info->wr_date, info->wr_time);
         else
            printf("%s%s\n", newdriveletter, filename);
      totallength += info->size;
      }

   if (searchlzhs == FALSE)
      return;

   /* open the lzh file by name and see if it was successful.
   */

   lzhfile = fopen(filename, readbinary);
   if (lzhfile == NULL)
      {
      fprintf(stderr, fmessageread, filename);
      return;
      }

   /* loop through the whole file
   */

   while(!feof(lzhfile))
      {
   /* read the local file header.
      if we don't get it, break the loop.
   */

      if (fread(&lzhworker, sizeof(struct lzh_lfh), (size_t) 1, lzhfile) != 1)
         break;

      insidefilename = szFileNameBuffer;

      if (fread((void *) insidefilename,  lzhworker.fnlength, (size_t) 1, lzhfile) != 1)
         break;
      insidefilename[lzhworker.fnlength] = '\0';

      temporary = strrchr(insidefilename, '\\');
      if (temporary != NULL)
         {
         temporary++;
         }
      else
         {
         temporary = insidefilename;
         }

      makefullname(&lzhfullname, temporary);
      if (comparenames(&lzhfullname, &matchname) == 0)
         {
         archivefound++;
         archivetotallength += lzhworker.usize;
         if (totalsmode == FALSE)
            if (verbose == TRUE)
               printinside(filename, temporary, lzhworker.usize,
                  lzhworker.date, lzhworker.time);
            else
               {
               printf(swfis, temporary, newdriveletter, filename);
               putchar('\n');
               }
         }
      else
         if (progress == TRUE)
            printf("%s\t\t\r", temporary);

#if defined(DEBUG)
      printf("temporary = \"%s\"\n", temporary);
#endif

   /* seek around the compressed file.
   */
      fseek(lzhfile, lzhworker.csize+2L, SEEK_CUR);

   /* at this point, the file pointer is once again at the
      next local file header ...
   */
      }

   if (progress == TRUE)
      printf(eraseline);
   fclose(lzhfile);
   return;
}


/* --------------------------------------------------------------------------
*/

void  processzoo(char *filename, struct find_t *info)
{
   FILE                 *zoofile;
   struct fullfilename  zoofullname;
   int                  thischar;

#if defined(DEBUG)
   printf("processzoo(\"%s\")\n", info->name);
#endif

   /* if the file name doesn't match the requested template name,
      return now and don't even bother opening the zip file.
   */

   if (comparenames(&tempfullname, &matchname) == 0)
      {
      if (totalsmode == FALSE)
         if (verbose == TRUE)
            printmatch(filename, info->size, info->wr_date, info->wr_time);
         else
            printf("%s%s\n", filename);
      found++;
      totallength += info->size;
      }

   if (searchzoos == FALSE)
      return;

   /* open the zoo file by name and see if it was successful.
   */

   zoofile = fopen(filename, readbinary);
   if (zoofile == NULL)
      {
      fprintf(stderr, fmessageread, filename);
      return;
      }

   /* first, skip over the ZOO FILE message
   */

   while (!feof(zoofile))
      {
      thischar = fgetc(zoofile);
      if (thischar == 0x1A)
         break;
      }

   if (feof(zoofile))
      {
      fclose(zoofile);
      return;
      }

   /* skip over more header junk */

   fseek(zoofile, 38L, SEEK_CUR);

   /* loop through the whole file
   */

   while(!feof(zoofile))
      {
   /* read the local file header.
      if we don't get it, break the loop.
   */

      if (fread(&zooworker, sizeof(struct zoo_lfh), (size_t) 1, zoofile) != 1)
         break;

   /* check the compression method.
      if it is zero, the pak file is over.
   */

      if (zooworker.filename[0] == '\0')
         break;

      strupr(zooworker.filename);
      makefullname(&zoofullname, zooworker.filename);
      if (comparenames(&zoofullname, &matchname) == 0)
         {
         archivefound++;
         totallength += zooworker.usize;
         if (totalsmode == FALSE)
            if (verbose == TRUE)
               printinside(filename, zooworker.filename, zooworker.usize,
                  zooworker.date, zooworker.time);
            else
               {
               printf(swfis, zooworker.filename, newdriveletter, filename);
               putchar('\n');
               }
         }
      else
         if (progress == TRUE)
            printf("%s\t\t\r", zooworker.filename);

#if defined(DEBUG)
      printf("filename = \"%s\"\n", zooworker.filename);
#endif

   /* seek around the compressed file.
   */
      fseek(zoofile, zooworker.csize+34L, SEEK_CUR);

   /* at this point, the file pointer is once again at the
      next local file header ...
   */
      }

   if (progress == TRUE)
      printf(eraseline);
   fclose(zoofile);
   return;
}


/* --------------------------------------------------------------------------
*/

void  processdwc(char *filename, struct find_t *info)
{
   char                 buff[256];
   dword                entrycount;
   long                 l;
   int                  num;
   int                  i=-1;
   int                  j;
   FILE                 *dwcfile;
   struct dwc_block     archive_block;
   struct dwc_lfh       dwc_entry;
   struct fullfilename  dwcfullname;

#if defined(DEBUG)
   printf("processdwc(\"%s\")\n", info->name);
#endif

   /* if the file name doesn't match the requested template name,
      return now and don't even bother opening the zip file.
   */

   if (comparenames(&tempfullname, &matchname) == 0)
      {
      if (totalsmode == FALSE)
         if (verbose == TRUE)
            printmatch(filename, info->size, info->wr_date, info->wr_time);
         else
            printf("%s%s\n", filename);
      found++;
      totallength += info->size;
      }

   if (searchzoos == FALSE)
      return;

   /* open the zoo file by name and see if it was successful.
   */

   dwcfile = fopen(filename, readbinary);
   if (dwcfile == NULL)
      {
      fprintf(stderr, fmessageread, filename);
      return;
      }

   /* find (and read) the archive descriptor structure
   */

   for (j=1; j <11 && i<0; j++)
      {
      if (fseek(dwcfile, (long) - (ELEMENTS(buff)*j - (j-1)*5), SEEK_END))
         {
         fseek(dwcfile, 0L, SEEK_SET);
         }
      else
         {
         l = ftell(dwcfile);
         }

      num = fread((void *) buff, sizeof(char), ELEMENTS(buff), dwcfile);

      for (i = num-3; i>=0 && strncmp(buff+i, "DWC", 3); i--)
         ;
      }

   if (i<0)
      {
      fprintf(stderr, "NJFIND: Invalid DWC file format in file %s\n", filename);
      fclose(dwcfile);
      return;
      }

   l += i+3;

   fseek(dwcfile, l - sizeof(archive_block), SEEK_SET);
   fread((void *) &archive_block, sizeof(archive_block), 1, dwcfile);

   if (archive_block.entries > 5000 || archive_block.entries < 0)
      {
      fprintf(stderr, "NJFIND: Invalid DWC file format in file %s\n", filename);
      fclose(dwcfile);
      return;
      }

   l -= ((long) archive_block.entries * archive_block.ent_sz +
      archive_block.size);

   fseek(dwcfile, l, SEEK_SET);

   /* get each one   */

   for (entrycount = 0; entrycount < archive_block.entries; entrycount++)
      {
      fread((void *) &dwc_entry, sizeof(dwc_entry), 1, dwcfile);

      if (sizeof(dwc_entry) < archive_block.ent_sz)
         fseek(dwcfile, (long) (archive_block.ent_sz - sizeof(dwc_entry)), SEEK_CUR);

      makefullname(&dwcfullname, dwc_entry.name);

      if (comparenames(&dwcfullname, &matchname) == 0)
         {
         archivefound++;
         archivetotallength += dwc_entry.new_size;
         if (totalsmode == FALSE)
            if (verbose == TRUE)
               {
               printinsidedwc(filename, dwc_entry.name, dwc_entry.new_size,
                  dwc_entry.time);
               }
            else
               {
               printf(swfis, dwc_entry.name, newdriveletter, filename);
               putchar('\n');
               }
         }
      else
         if (progress == TRUE)
            printf("%s%s\t\t\r", newdriveletter, dwc_entry.name);
      }


   if (progress == TRUE)
      printf(eraseline);

   fclose(dwcfile);
   return;
}


/* --------------------------------------------------------------------------
*/

void  processarj(char *pstrFileName, struct find_t *info)
{
   FILE                 *fARJFile;
   char						*pstrTemporary;
   struct fullfilename  zipfullname;
   unsigned int         wExtHeaderSize;
   boolean              bSkippedHeader;
   struct arj_lfh       sBlock;
   int                  nNameLength;

   fARJFile = fopen(pstrFileName, "rb");
   if (fARJFile == NULL)
      {
		fprintf(stderr, "NJFIND: Invalid ARJ file format in %s\n", pstrFileName);
		fclose(fARJFile);
      return;
      }

   bSkippedHeader = FALSE;

   while (!feof(fARJFile))
      {
      fread(&sBlock, sizeof(struct arj_lfh), 1, fARJFile);

      if (sBlock.wBasicHeaderSize == 0)
         continue;

      nNameLength = sBlock.wBasicHeaderSize-sizeof(struct arj_lfh)+4;

      fread(szFileNameBuffer, 1, nNameLength, fARJFile);

      fseek(fARJFile, 4L, SEEK_CUR);

      while ((wExtHeaderSize = (unsigned int) getw(fARJFile)) != 0)
         {
         fseek(fARJFile, wExtHeaderSize+2, SEEK_CUR);
         }

      fseek(fARJFile, sBlock.dwCompressedSize, SEEK_CUR);

      if (bSkippedHeader == FALSE)
         {
         bSkippedHeader = TRUE;
         }
      else
         {
         pstrTemporary = strchr(szFileNameBuffer, '/');

         if (pstrTemporary != NULL)
            {
            pstrTemporary++;
            }
         else
            {
            pstrTemporary = szFileNameBuffer;
            }

         makefullname(&zipfullname, pstrTemporary);
         if (comparenames(&zipfullname, &matchname) == 0)
            {
            archivefound++;
				archivetotallength += sBlock.dwOriginalSize;

	  	      if (totalsmode == FALSE)
					{
					if (verbose == TRUE)
						{
      	   	   printinside(pstrFileName, pstrTemporary, sBlock.dwOriginalSize,
         	   	   (word) (sBlock.dwDateTimeStamp >> 16),
							(word) (sBlock.dwDateTimeStamp & 0x0000FFFFL));
						}
   	         else
      	         {
	      	      printf(swfis, szFileNameBuffer, newdriveletter, pstrFileName);
   	      	   putchar('\n');
	      	      }
      	      }
				}
			else
				{
				if (progress == TRUE)
					{
					printf("%s%s\t\t\r", newdriveletter, szFileNameBuffer);
					}
				}
         }
      }

   fclose(fARJFile);
   return;
}



/* --------------------------------------------------------------------------
*/

void  processnormal(char *filename, struct find_t *info)
{
#if defined(DEBUG)
   printf("processnormal(\"%s\")   ", info->name);
   printf("comparenames = %d\n", comparenames(&tempfullname, &matchname));
#endif

   if (comparenames(&tempfullname, &matchname) == 0)
      {
      found++;
      if (totalsmode == FALSE)
         if (verbose == TRUE)
            printmatch(filename, info->size, info->wr_date, info->wr_time);
         else
            printf("%s%s\n", newdriveletter, filename);
      totallength += info->size;
      }
   else
      if (progress == TRUE)
         printf("%s\t\t\r", info->name);

   return;
}


/* --------------------------------------------------------------------------
   printinside() prints out the file information from within an archive.
   This makes it different than printmatch only in that the file name
   *and* the name of the archive the file was in are printed.
*/

void  printinside(char *filename, char *archive,
               dword filesize, word date, word time)
{
   int   count;

   count = strlen(filename) + 14 + strlen(archive) + strlen(newdriveletter);
   printf(swfis, archive, newdriveletter, filename);

   if (count > 48)
      {
      putchar('\n');
      printf("%s", fiftyspaces);
      }
   else
      while (count < 48)
         {
         putchar(' ');
         count++;
         }

   printf("%8lu ", filesize);
   printdate(date);
   printtime(time);
   putchar('\n');

   return;
}



/* --------------------------------------------------------------------------
   printinsidedwc() prints out the file information from within a DWC
	archive.  DWC archives are a little different because they store
	the date and time stamp for each file in the Unix-like "localtime()"
	format.

	For this function, then, we've repleaced the printdate() and
	printtime() calls with slightly different code.
*/

void  printinsidedwc(char *filename, char *archive,
				dword filesize, time_t date)
{
   int   count;
	struct tm *filetime;

	filetime = localtime(&date);

   count = strlen(filename) + 14 + strlen(archive) + strlen(newdriveletter);
   printf(swfis, archive, newdriveletter, filename);

   if (count > 48)
      {
      putchar('\n');
      printf("%s", fiftyspaces);
      }
   else
      while (count < 48)
         {
         putchar(' ');
         count++;
         }

   printf("%8lu ", filesize);

	printf("%02d-%s-%d  ", filetime->tm_mday, month3names[filetime->tm_mon],
		filetime->tm_year);

	printf("%2.2d:%2.2d:%2.2d\n", filetime->tm_hour, filetime->tm_min,
		filetime->tm_sec);

	return;
}



/* --------------------------------------------------------------------------
*/

void	printinsidearj(char *filename, char *archive, dword filesize, dword date, dword time)
{
   int   count;

   count = strlen(filename) + 14 + strlen(archive) + strlen(newdriveletter);
   printf(swfis, archive, newdriveletter, filename);

	if (count > 48)
		{
		putchar('\n');
		printf("%s", fiftyspaces);
		}
	else
		{
		while (count < 48)
			{
			putchar(' ');
			count++;
			}
		}

	printf("%8lu ", filesize);
	printdate((word) (date >> 16));
	printtime((word) (time & 0x0000FFFFL));
	putchar('\n');
	return;
}


/* --------------------------------------------------------------------------
   printmatch() prints out the file's information.  It does this all in a
   neat, tidy way.  The width of 50 characters for the file name is imposed
   because for eleven characters of a date, eight characters for a time,
   one character for a space, and nine characters for a file size.
*/

void  printmatch(char *filename, dword filesize, word date, word time)
{
   int count;

   count = strlen(filename)+strlen(newdriveletter);
   printf("%s%s", newdriveletter, filename);

   if (count > 48)
      {
      putchar('\n');
      printf("%s", fiftyspaces);
      }
   else
      while (count < 48)
         {
         putchar(' ');
         count++;
         }

   printf("%8lu ", filesize);
   printdate(date);
   printtime(time);
   putchar('\n');

   return;
}

/* --------------------------------------------------------------------------
   printdate() accepts a word of the DOS date and prints it out in
   the format "DD-MMM-CC".  MMM is a three-letter name for the month.
*/

void  printdate(word date)
{
   printf("%02d-%s-%d  ", date & 0x001F,
      month3names[((date >> 5) & 0x000F) -1], 1980+(date >> 9));

   return;
}


/* --------------------------------------------------------------------------
   printtime() accepts the DOS-format for the time as a word and
   prints out the time in the format "HH:MM:SS".  Note that the
   time is in twenty-four hour format.
*/

void  printtime(word time)
{
   printf("%2.2d:%2.2d:%2.2d", 
      time >> 11, (time >> 5) & 0x003F, (time & 0x001F) << 1);

   return;
}


/* --------------------------------------------------------------------------
   This function compares two fill file name structures.  It ignores
   question marks during the comparison, so it will match filenames that
   have expanded wildcards.  This routine will return a zero if the files
   are equivalent (or match by wildcard), and will return a one if the
   files names are not comparable.
*/

int   comparenames(struct fullfilename *left, struct fullfilename *right)
{
   register char  *source;                /* working pointers for compare  */
   register char  *dest;

   source = left->filename;
   dest   = right->filename;

   while(*source && *dest)
      {
      if (*source != '?' && *dest != '?')
         if (*source != *dest)
            return 1;               /* not equal!  */
      source++;
      dest++;
      }

   /* code added version 1.11 */

   if (*source == '\0' && *dest != '\0')
      return 1;

   /* end code added version 1.11   */

   source = left->fileextension;
   dest   = right->fileextension;

   while(*source && *dest)
      {
      if (*source != '?' && *dest != '?')       /* skip questionmarks   */
         if (*source != *dest)
            return 1;               /* not equal!  */
      source++;
      dest++;
      }

   /* code added version 1.11 */

   if (*source == '\0' && *dest != '\0')
      return 1;

   /* end code added version 1.11   */

   return 0;                        /* zero indicates success  */
}


/* --------------------------------------------------------------------------
   maketemplate() takes inputfile[] and expands all the asterisks to
   question marks.  This is done once, first, so that the checkmatch()
   routine can more quickly and efficiently check for matches in file
   names.
*/

void  maketemplate()
{
   register char  *source = inputfile; /* pointers for copying data  */
   register char  *dest = template;
   int   count = 0;                    /* count of template length   */
   int   inextension = 0;              /* set after we get a .       */

   *dest++ = '\\';

   while(*source != '\0' && count < 13 && inextension < 4)
      {
      if (*source != '*')
         {
         *dest++ = *source;
         count++;
         if (count == 9 || *source == '.')
            inextension++;
         source++;
         }
      else
         {
         if (inextension != 0)
            {
            for ( ; inextension<4; inextension++)
               *dest++ = '?';
            *dest = '\0';
            break;
            }
         else
            {
            for ( ; count<8; count++)
               *dest++ = '?';
            *dest++ = '.';
            inextension = 1;
            source++;
            if (*source == '.')
               source++;
            }
         }
      }

   *dest = '\0';
   return;
}


/* --------------------------------------------------------------------------
   makefullname() accepts a pointer to a DOS path name and a pointer to
   a fullfilename structure.  makefullname() puts the file name from
   the path into the fullfilename structure and returns.
*/

void  makefullname(struct fullfilename *ffn, char *path)
{
   register char  *source;
   register char  *dest;
   int            counter;

   source = strrchr(path, '\\');
   if (source == NULL)
      source = path;
   else
      source++;

   for (dest = ffn->filename, counter = 0; *source && counter<8; counter++)
      if (*source == '.')
         *dest++ = ' ';
      else
         *dest++ = *source++;

   *dest = '\0';
   if (*source != '\0')
      source++;

   for (dest = ffn->fileextension, counter = 0; counter<3; counter++)
      if (*source == '\0')
         *dest++ = ' ';
      else
         *dest++ = *source++;

   *dest = '\0';

   return;
}


/* --------------------------------------------------------------------------
   searchdir() accepts the name of a directory.  That name *MUST* include
   wildcards, and may include a partial filename, a full pathname, or a
   drive specification.

   The function will search all directories and go lower, and will call
   itself recursively if it finds any more subdirectories.  In this way,
   it traverses the subdirectory tree in an "inorder" fasion.
*/

void searchdir(char *dirname)
{
   char           temppath[_MAX_PATH];
   char           thisfilename[_MAX_PATH];
   struct find_t  dirinfo;


   strcpy(temppath, dirname);
   result = _dos_findfirst(temppath, _A_NORMAL | _A_SUBDIR, &dirinfo);

   do {
      strcpy(thisfilename, dirname);
      *(strrchr(thisfilename, '\\')+1) = '\0';
      strcat(thisfilename, dirinfo.name);
#if defined(DEBUG)
      printf("%s ", thisfilename);
#endif

      if ((dirinfo.attrib & _A_SUBDIR) &&
           dirinfo.name[0] != '.')
         {
#if defined(DEBUG)
         printf("(DIRECTORY)\n");
#endif
         strcat(thisfilename, "\\*.*");
         searchdir(thisfilename);
         }
      else
         {
#if defined(DEBUG)
         putchar('\n');
#endif

         while(broken == FALSE)
            {
            extension = strchr(thisfilename, '.');
            if (*(extension-1) == '\\')
               break;

            makefullname(&tempfullname, thisfilename);

            if (extension != NULL)
               {
               if (strcmp(extension, ".LZH") == 0)
                  {
                  processlzh(thisfilename, &dirinfo);
                  break;
                  }

         /* Note that we call the same routine for .PAK and .ARC.
            They have the same (basic) format!
         */

               if (strcmp(extension, ".PAK") == 0)
                  {
                  processpak(thisfilename, &dirinfo);
                  break;
                  }

               if (strcmp(extension, ".ARC") == 0)
                  {
                  processarc(thisfilename, &dirinfo);
                  break;
                  }

               if (strcmp(extension, ".ZOO") == 0)
                  {
                  processzoo(thisfilename, &dirinfo);
                  break;
                  }

               if (strcmp(extension, ".ZIP") == 0)
                  {
                  processzip(thisfilename, &dirinfo);
                  break;
                  }

         /* DWC was added in version 2.00 */

               if (strcmp(extension, ".DWC") == 0)
                  {
                  processdwc(thisfilename, &dirinfo);
                  break;
                  }

			/* ARJ was added in version 2.10 */

					if (strcmp(extension, ".ARJ") == 0)
						{
						processarj(thisfilename, &dirinfo);
						break;
						}
               
               }

            processnormal(thisfilename, &dirinfo);
            break;
            }
         }

      result = _dos_findnext(&dirinfo);
      } while (result == 0 && broken == FALSE);

   if (progress == TRUE)
      printf(eraseline);
   return;
}


/* --------------------------------------------------------------------------
   showusage() is a kind of error routine.  It is called when we get confused
   parsing the command line and bail out gracefully.  This prints the
   program usage and quits.
*/

void  showusage()
{
   fputs("Usage: NJFIND [options] <filespec>\n", stderr);
   fputs("[options] include:\n", stderr);
   fputs("\t/A - do not search *.ARC files\n", stderr);
	fputs("\t/J - do not search *.ARJ files\n", stderr);
   fputs("\t/W - do not search *.DWC files\n", stderr);
   fputs("\t/L - do not search *.LZH files\n", stderr);
   fputs("\t/P - do not search *.PAK files\n", stderr);
   fputs("\t/O - do not search *.ZOO files\n", stderr);
   fputs("\t/Z - do not search *.ZIP files\n", stderr);
   fputs("\t/N - only search normal files (combo of /W /J /O /Z /P /A /L)\n\n", stderr);
   fputs("\t/V - verbose mode; prints statistics\n", stderr);
   fputs("\t/T - totals mode; prints no found filenames\n", stderr);
   fputs("\t/D - progress display prints filenames as searched\n", stderr);
   fputs("\t/R - run search across all DOS drives\n\n", stderr);

   exit(1);
}


/* --------------------------------------------------------------------------
   handleoption() takes care of the options the program accepts.  since
   these are all just switches, we just tweak the boolean variables that
   represent each option.
*/

void  handleoption(char *option, boolean inenvironment)
{
   switch(toupper(*option))
      {
      case 'N':   searchzoos =
                  searchpaks =
                  searcharcs =
                  searchlzhs =            /* normal files ...     */
                  searchzips = FALSE;
                  fprintf(stderr, notsearching, "ARC, ARJ, DWC, LZH, PAK, ZIP, or ZOO");
                  break;

      case 'O':   searchzoos = FALSE;     /* turn off ZOO files   */
                  fprintf(stderr, notsearching, "ZOO");
                  break;

   /* added code, version 2.00   */

      case 'W':   searchdwcs = FALSE;     /* turn off DWC files   */
                  fprintf(stderr, notsearching, "DWC");
                  break;

   /* end added code */

	/* added code, version 2.10	*/

		case 'J':	searcharjs = FALSE;
						fprintf(stderr, notsearching, "ARJ");
						break;

	/* end added code	*/

      case 'Z':   searchzips = FALSE;     /* turn off ZIP files   */
                  fprintf(stderr, notsearching, "ZIP");
                  break;

      case 'A':   searcharcs = FALSE;     /* turn off ARC files   */
                  fprintf(stderr, notsearching, "ARC");
                  break;

      case 'L':   searchlzhs = FALSE;
                  fprintf(stderr, notsearching, "LZH");
                  break;

      case 'P':   searchpaks = FALSE;
                  fprintf(stderr, notsearching, "PAK");
                  break;

      case 'V':   verbose = TRUE;
                  fputs("Verbose mode\n", stderr);
                  break;

      case 'D':   progress = TRUE;
                  fputs("Progress displays enabled\n", stderr);
                  break;

      case 'T':   totalsmode = TRUE;
                  fputs("Totals mode only\n", stderr);
                  break;

   /* added code, version 1.10   */

      case 'R':   alldrives = TRUE;
                  fputs("Search all drives\n", stderr);
                  break;

   /* end of added code          */

      default:    fprintf(stderr, "NJFIND: Unrecognized Option '%c'", *option);
      
   /* added code, version 2.00   */

                  if (inenvironment == TRUE)
                     fprintf(stderr, " in NJFIND environment variable");
                  fputc('\n', stderr);
                  fputc('\n', stderr);

   /* end added code */
                  showusage();
      }

   return;
}


/* --------------------------------------------------------------------------
   builddrivelist() sets drivelist to an ASCII string of the drive
   letters that are valid on this system.  drivelist will only contain
   the identifiers of hard disk drives (with the media type 0xF8.)
   This function was added for Version 1.10.  This function was changed
	with Version 2.10 to accomodate DOS 5.0.
*/

void builddrivelist()
{
   union REGS     inregs;
   struct SREGS   segregs;

   unsigned int   far *walker;
   unsigned int   far *newwalker;
   unsigned int   far *nextone_off;
   unsigned int   far *nextone_seg;
   char  far *media_type;
   char  *dest;

   dest = drivelist;
   *dest = '\0';

   inregs.h.ah = 0x52;
   int86x(0x21, &inregs, &inregs, &segregs);

   FP_OFF(newwalker) = inregs.x.bx;
   FP_SEG(newwalker) = segregs.es;

   FP_OFF(walker) = newwalker[0];
   FP_SEG(walker) = newwalker[1];

   while(1)
      {

      if (_osmajor == 2)
         {
         media_type = (char far *) walker + 0x16;
         nextone_off = walker + 0x0C;
         nextone_seg = walker + 0x0D;
         }
      else if (_osmajor == 3)
         {
         media_type = (char far *) walker + 0x16;
         nextone_off = walker + 0x0C;
         nextone_seg = walker + 0x0D;
         }
      else if (_osmajor == 4 || _osmajor == 5)
         {
         media_type = (char far *) walker + 0x17;
         nextone_off = (unsigned int far *) ((char far *) walker + 0x19);
         nextone_seg = (unsigned int far *) ((char far *) walker + 0x1B);
         }

      if ((*media_type & 0x00FF) == 0xF8)
         {
         *dest++ = (char) *walker + 'A';
         *dest = '\0';
         }

      FP_OFF(walker) = *nextone_off;
      FP_SEG(walker) = *nextone_seg;

      if ((*walker & 0x00FF) > 26)
         break;

      if (FP_OFF(walker) == 0xFFFF)
         break;
      }

   return;
}


/* --------------------------------------------------------------------------
   The breakout() function handles the SIGINT signal for the program.
   Here, we simply set a flag so that the working loop will terminate
   and return.  This allows us to leave neatly, by resetting the
   current drive and printing out our totals.  (That doesn't take very
   long and should not be much of an annoyance to the user.)
*/

void  breakout()
{
   signal(SIGINT, SIG_IGN);
   signal(SIGINT, breakout);

   putchar('\n');
   broken = TRUE;

   return;
}


/* --------------------------------------------------------------------------
   handleenvironment() takes care of looking at the environment to
   find NJFIND settings.  If such an entry is found, it is parsed by
   running pointers through it and calling handleoption().

   This function is new for Version 2.00.
*/

void handleenvironment()
{
   char *environment;
   char *walker;
   char *destination;
   char copy[10];
   int  len;

   environment = getenv("NJFIND");
   if (environment == NULL)
      return;

#if defined(DEBUG)
   printf("NJFIND found!\n");
#endif

   walker = environment;

   while (*walker != '\0')
      {
      while (isspace(*walker))
         {
         walker++;
         }

      if (*walker == '\0')
         break;

      destination = copy;
      len = 0;

      while (!isspace(*walker) && *walker != '\0')
         {
         *destination++ = *walker++;
         *destination = '\0';

         if (++len == ELEMENTS(copy))
            {
            fputs("NJFIND: option too long in environment\n", stderr);
            exit(1);
            }
         }

      if (copy[0] == '/' || copy[0] == '-')
         handleoption(copy+1, TRUE);
      else
         {
         fputs("NJFIND: only options supported in environment\n", stderr);
         exit(1);
         }

      }

   return;
}


/* --------------------------------------------------------------------------
   The Main Thang.
*/

void main(int argc, char *argv[])
{
   int   argcounter;
   char  *userfilespec;

   signal(SIGINT, breakout);

   for (argcounter = 0; argcounter < 50; argcounter++)
      fiftyspaces[argcounter] = ' ';
   fiftyspaces[argcounter] = '\0';

   fputs("Nifty James' File Finder\n", stderr);
   fputs("Version 2.10/ASP of 25 August 1991 \n", stderr);
   fputs("(C) Copyright 1989, 1990, 1991 by Mike Blaszczak\n\n", stderr);

   builddrivelist();

   if (argc < 2)
		{
      showusage();
		}

   userfilespec = NULL;
   for (argcounter = 1; argcounter<argc; argcounter++)
		{
      if (argv[argcounter][0] == '/' || argv[argcounter][0] == '-')
			{
         handleoption(argv[argcounter]+1, FALSE);
			}
      else
			{
         if (userfilespec == NULL)
				{
            userfilespec = argv[argcounter];
				}
         else
            {
            fputs("Only one filespec allowed!\n\n", stderr);
            exit(1);
            }
			}
		}

   handleenvironment();

   /* moved from handleoption in version 2.00   */

   fputc('\n', stderr);

   /* end of moved code */

   _dos_getdrive(&olddrive);
   newdriveletter[0] = '\0';

   if (userfilespec == NULL)
      {
      userfilespec = "X:\\*.*";
      userfilespec[0] = (char) olddrive + 'A';
      drivelist[0] = userfilespec[0];
      drivelist[1] = '\0';
      }
   else
      if (alldrives == FALSE)
         {
         if (userfilespec[1] == ':')
            {
            *userfilespec = (char) toupper(*userfilespec);
            newdrive = (unsigned) (*userfilespec - 'A' +1);
            _dos_setdrive(newdrive, &drivecount);
            _dos_getdrive(&lastdrive);

            if (lastdrive != newdrive)
               {
               fprintf(stderr, "NJFIND: Invalid drive %c:.\n", *userfilespec);
               fprintf(stderr, "        Valid drives are A: to %c:\n",
                  drivelist[strlen(drivelist)-1]);
               exit(1);
               }
            else
               {
               changedrive = TRUE;
               drivelist[0] = *userfilespec;
               drivelist[1] = '\0';
               userfilespec += 2;
               }
            }
         else
            {
            drivelist[0] = (char) (olddrive + 'A' -1);
            drivelist[1] = '\0';
            }
         }
      else
         {
         changedrive = TRUE;
         if (userfilespec[1] == ':')
            userfilespec += 2;
         }

   inputfile = strupr(userfilespec);
   maketemplate();
   makefullname(&matchname, template);
#if defined(DEBUG)
   printf("template: %s\n", template);
#endif

   for (currentdrive = drivelist; *currentdrive != '\0';
            currentdrive++)
      {
      newdriveletter[0] = *currentdrive;
      newdriveletter[1] = ':';
      newdriveletter[2] = '\0';
      newdrive = (unsigned) (*currentdrive - 'A' +1);
      _dos_setdrive(newdrive, &drivecount);
      searchdir("\\*.*");
      }

   if (broken == TRUE)
      printf("\nNJFIND: Searching interrupted!\n\n");

   /* print out statistics */

   printf("\n   %5u file", found);
   if (found != 1)
      putchar('s');
   printf(" found.\n");
   printf("   %5u archived file", archivefound);
   if (archivefound != 1)
      putchar('s');
   printf(" found.\n");

   if (found != 0 && archivefound != 0)
      printf("   %5u files found in total.\n", found + archivefound);
   else
      putchar('\n');

   putchar('\n');

   if (totalsmode == TRUE || verbose == TRUE)
      {
      if (found != 0)
         printf("Found files total %lu bytes.\n", totallength);
      if (archivefound != 0)
         printf("Found archive files total %lu bytes.\n", archivetotallength);
      }

   if (changedrive == TRUE)
      _dos_setdrive(olddrive, &drivecount);

   exit(0);
}


