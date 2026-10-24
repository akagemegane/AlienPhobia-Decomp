ALIEN PHOBIA - FUNCTIONAL TURBO PASCAL REBUILD
================================================

Functional decompilation of Alien Phobia v1.1 by Wah-Software.
This is a standalone source rebuild, not a byte-matching reproduction.
The exact original compiler version is unknown.

All sources and game data live in this directory. Run the executable with this directory as the current directory.

BUILD UNDER MS-DOS
------------------
Requirements:
  * MS-DOS or a DOSBox-X DOS session.
  * Turbo Pascal 7.0 DOS compiler (TPC.EXE), TURBO.TPL and standard units.
    Supply your own compiler; it is not included.
  * A 286 or later CPU for the generated instructions, VGA graphics,
    and sufficient free conventional memory for the compiler and game.
  * Optional Sound Blaster audio: an XMS driver such as HIMEM.SYS,
    at least 190 KB free XMS, and a correct BLASTER environment variable.

The rebuild has been tested with DOSBox-X, not physical DOS hardware.

Example compiler installation:
  C:\TP\BIN\TPC.EXE
  C:\TP\BIN\TURBO.TPL
  C:\TP\UNITS\... (standard units, if installed separately)

Put this repository's files in a DOS directory such as C:\PHOBIA.
At the DOS prompt, type:

  C:
  CD \PHOBIA
  SET TP=C:\TP
  BUILD

BUILD.BAT defaults to C:\TP if TP is unset. TP is the directory containing
BIN and UNITS, without a trailing backslash. Use DOS 8.3 paths without
spaces. Run BUILD from the directory containing PHOBIA.PAS.

To compile manually without the batch file, type this single line:

  C:\TP\BIN\TPC.EXE PHOBIA.PAS /B /TC:\TP\BIN /UC:\TP\UNITS

Replace each C:\TP if your compiler is elsewhere. /B rebuilds required
units, /T locates TURBO.TPL, and /U locates units. USES clauses determine
the compilation order. No separate linker command is needed. Success
produces PHOBIA.EXE and .TPU files in this directory.

Python, MSYS2, Watcom, objdiff and host build tools are not required.

RUN
---
First try:

  PHOBIA NOSOUND

For Sound Blaster audio, enable XMS and set BLASTER to match your hardware
or emulator. Example for port 220, IRQ 7, DMA 1 and HDMA 5:

  SET BLASTER=A220 I7 D1 H5
  PHOBIA

Use settings appropriate to your card. The game can fall back to the PC
speaker when initialization fails. NOSOUND is accepted as either the
first or second command-line argument.

Known limitation: during packaging, the clean DOS build and NOSOUND
60-frame smoke run passed, but the sound-enabled smoke run exited before
writing its completion marker. The cause has not been diagnosed. Use
NOSOUND for now; complete sound-enabled gameplay is not verified.

Controls:
  Left/Right arrows: rotate
  Up arrow: thrust
  Enter: fire
  Scroll Lock: end the round
  Score screen: enter a name when prompted; D quits, N starts another round

ALIEN.DA1 stores high scores and is modified when saving. Back it up if
you want to preserve the initial scores.

Optional bounded smoke run:

  PHOBIA NOSOUND /SMOKE

This runs at least 60 gameplay frames, then enters the score screen.
Press D to finish. Success writes GAME.RES with PASS 0000:380A and the
frame count. This is a smoke test, not exhaustive gameplay validation.

FILES
-----
PHOBIA.PAS   Main program
FAPP.PAS     Initialization, resources and game loop
FCORE.PAS    Game state, movement, collision, rendering and effects
FGFX.PAS     Graphics allocation and palette fading
FHW.PAS      Sound Blaster, DMA and mixer
FINPUT.PAS   Keyboard interrupt handler and video helpers
FRECOVER.PAS Resource, string, environment and other recovered helpers
FSCORES.PAS  High-score display, entry and persistence
FSOUND.PAS   Sample loading and XMS streaming
RXMS.PAS     XMS interface
*.DAT        Original graphics, palettes and audio
ALIEN.DA1    Original initial high scores
FILE_ID.DIZ  Original game identification
BUILD.BAT    Manual MS-DOS build
README.md    GitHub landing page
NOTICE.TXT   Provenance and licensing status
STATUS.TXT   Recovery accounting when packaged
MANIFEST.TXT SHA-256 hashes of packaged files
