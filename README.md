CamelForth for the DCPU-16
==========================

This is CamelForth-16, an implementation of the Forth programming language
for the fictional Mojang 16-bit DCPU. It is a fully-featured, standard, ANS-compatible
16-bit implementation of the language, including a glimpse of required 16/32-bit
mixed arithmetic.

It is a port of the popular CamelForth direct-threaded code (DTC) model,
derived directly from the existing Z-80 CP/M code by Brad Rodriguez.
Like CamelForth in general, it is licensed under the GPL.

For details on DCPU-16, see <http://0x10c.com/doc/dcpu-16.txt>,
but also see the yet-unpublished, semi-official changes at
<http://pastebin.com/raw.php?i=Q4JvQvnM>. CamelForth-16 is
written to the latter spec (v1.7),
and thus requires a recent, up-to-date simulator.
It was developed using an unofficial, patched version of the "highnerd rc1" simulator,
but can be run in any recent simulator that supports the required
devices (generic keyboard and LEM-1802 display), for example, hellige's simulator
from <https://github.com/hellige/dcpu> with the -g switch (SDL required).

For background on the Mojang DCPU and the 0x10c game,
check out <http://0x10c.com>.

For details on CamelForth, see <http://www.camelforth.com>.
For help and tutorials on Forth itself, see <http://www.forth.org>,
<http://www.forth.com> and <http://en.wikipedia.org/wiki/Forth_(programming_language)>.


Quick Start
-----------

The CamelForth-16 image is supplied as a big-endian image in the file camel16.o.
The choice for big-endian stems from it being the native format of Notch's simulator
it was developed in, and it being supported by popular up-to-date simulators such
as hellige's. Other formats such as little-endian or DAT source will be supplied shortly.

The CamelForth image, camel16.o, can be run from a SDL-enabled hellige
DCPU simulator directory as follows:

    ./dcpu -g ../path/to/camel16.o

Notice the need to include the -g option, and thus the SDL requirement.
CamelForth does not yet run in hellige's pure ncurses console environment.

In a setting with an extra SDL window open, remember to keep the input focus
on the simulator window to get keyboard input to register.
Also, CamelForth is case-sensitive, but does not fold case on input. Standard
Forth words have thus to be entered in uppercase.

Try 
    3 4 + .
to check out basic arithmetic, or
    355 10000 113 */ .
to try some mixed 16/32-bit arithmetic, delivering an amusing result.

Try
    WORDS
to get a listing of the Forth words supported by CamelForth-16.
Remember to enter it in upper case.
The WORDS listing can be interrupted by pressing a key anytime.

Check out the commented source listing (camel16.lst) for details.


The Assembler
-------------

CamelForth-16 comes with its own custom DCPU-16 assembler, which is currently
required to build a CamelForth-16 executable. The assembler is written in Ruby,
and implements the macros needed to define Forth headers and keep track of link
fields. It is not a full macro assembler however.

To recompile CamelForth-16 from its three source files, issue

    ./asm camel16.dasm

This will also produce an updated listing in camel16.lst.


Thanks
------

Thanks go out to Brad Rodriguez for a simple yet comprehensive model
implementation. Check out <http://www.camelforth.com> for other 
implementations on common, real microprocessors. As the saying goes,
"If you've seen one Forth, you've -- well, seen one Forth," but
porting CamelForth was exceptionally easy.

Thanks to Markus Persson (@notch) for 0x10c as such, for providing an interesting
challenge and a moving target that kept things lively this April (2012).
Check out <http://0x10c.com> for the upcoming game.

Last but not least, thanks to Charles Moore for Forth in general.
I hadn't touched Forth in many years now, and it all felt familiar (and "just right")
again. An amazing language and mindset.
Check out his site <http://www.colorforth.com/index.html>.
