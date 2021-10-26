
# Nifty James Shareware #

This repository includes the source code for shareware that I wrote in the late 1980s and early 1990s. The programs are named after Nifty James, a cartoon character in a strip drawn by a school friend of mine.

These are all tools and utilities written for 16-bit DOS. Mostly in assembly, but there's some C here too. If you were active in the BBS scene (or on services like The Source, CompuServe, or NWI) you might recognize me or even the utilities.

Each of the applications has its own documentation, and to preserve the integrity of the original archives, I didn't rename the documentation file. Back in the day, `*.DOC` files might still be text files.


## NJCHIME - Grandfather Clock Chimes ##

This TSR program watches the clock and plays chimes on the quarter-hour, just like a grandfather clock. There are a few different chime songs it can play. I wrote this for my father, since he had built a huge grandfather clock from a kit and enjoyed it. The TSR emulated that clock.

## NJDUMP - Object File Dumper ##

I was fascinated with the OBJ file format that the Microsoft tools generated -- the output from the compiler and assembler. After getting documentation about the file format from Microsoft, I wrote this dumper to learn more about the file format. My intention was to write a linker eventually, but I never got that far.


## NJFRERAM - Free Memory Display ##

This TSR loads up and shows the amount of free memory in the top right corner of the display. Since you've only got 640 kilobytes, you've got to keep an eye on it. At all times.

## NJLQP - Letter Quality Printer ##

Dot-matrix printers were cheap and fast; to get really nice looking output, you needed a daisy-wheel printer. But those were slow and expensive, and not so flexible. (Where I worked in the late 80s, we had a laser printer ... it cost about 20 grand, and I can't imagine what it caused per page.)

NJLQP had a high-resolution bitmapped font built-in. It would read a file, converting that font to graphics for the Epson printers, and "micro feed" the paper. Instead of printing characters in an array of 5x7 dots, it effectively printed 15x21 dots. That was slower -- but not *that* slow, and certainly much cheaper than the alternative, fancy printers.

## NJMOVE - File Move Utility ##

For a while, DOS had a function that would move a file, but not a command that would move a file. NJMOVE implemented such a command.


## NJPARK - Hard drive head parking ##

NJPARK would issue commands to Seagate drives to park their heads.


## NJPL - Program Logger ##

I thought it would be an interesting idea to log programs that I ran. NJPL is a program logger: it would wrap any program you'd like, run it, and log the program name and execution time to a file. You might notice it in some of the makefiles in these directories, so I could learn how much time I spent building and linking.

I wanted to enhance this to be a TSR that hooked the DOS program execute function directly, but never got around to it.

## NJRAMD - RAM disk ##

This program implements a RAM disk in EMS memory. This and NJLQP were the two most popular programs I wrote. NJLQP even turned up in some forensic analysis of compromised voting machines in New Jeresy! The program was based on a sample in a Ray Duncan book, if I remember correctly. I added lots of bells and whistles to it, including some status information that could be shown on the little four-digit display that PC's Limited computers had on their front panel.

## NJSORT - Sort program ##

This Sort tool was an implementation of an external sort -- it could sort more data than would fit into memory at once. IT could sort binary files and text files, too.

## NJTIDY - File cleanup ##

NJTIDY would wander around and find files that could be cleaned up, and delete them. `*.BAK` files would pile up if you were editing lots of stuff, and this program fixed that. It could be configured to find other file extensions and nuke those, too. *Really* dangerous stuff.


# Thirty Years Ago #

It's hard for me to believe I wrote these programs thirty years ago. I know that many more people used them than those that paid for them, but I'm very thankful to the people that did. The extra cash wasn't a ton, but it got me started since, at this same era, I had just moved out of my parents' house and was starting college ... only to drop out and work full time.

A few of the programs got onto "best files" lists, and a few were even given capsule reviews in magazines. It was a good time.

Looking back on the code, it's a bit embarrassing. These are all the first apps I wrote; I hadn't any training and just taught myself. And I was only 16 or 18 or so. Can you imagine?