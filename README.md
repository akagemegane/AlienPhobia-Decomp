# Alien Phobia: functional Pascal rebuild

This is a functional Turbo Pascal decompilation of Alien Phobia, developed by Wah-Software in 1997 for MS-DOS.

Contains the standalone Turbo Pascal 7.0 source/data package. All files belong
in the repository root; no source or asset subdirectories are required.

In MS-DOS, from this directory:

```bat
SET TP=C:\TP
BUILD
PHOBIA NOSOUND
```

Manual compiler command:

```bat
C:\TP\BIN\TPC.EXE PHOBIA.PAS /B /TC:\TP\BIN /UC:\TP\UNITS
```

You need to supply your own Turbo Pascal installation. See [README.TXT](README.TXT) for requirements, sound configuration, controls and troubleshooting details.

See [NOTICE.TXT](NOTICE.TXT) for provenance and licensing status.

The clean DOS build and `NOSOUND` smoke test pass. The sound-enabled smoke
run exits before its completion marker; use `NOSOUND` for now.

This is a functional decompilation. The exact original compiler version is not known.

For the sake of transparency, this project extensively uses AI code.