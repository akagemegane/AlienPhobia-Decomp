@echo off
rem Turbo Pascal 7.0 - run from this directory under MS-DOS.
if "%TP%"=="" set TP=C:\TP
if not exist %TP%\BIN\TPC.EXE goto notpc
%TP%\BIN\TPC.EXE PHOBIA.PAS /B /T%TP%\BIN /U%TP%\UNITS
if errorlevel 1 goto failed
echo.
echo Build complete: PHOBIA.EXE
echo Run PHOBIA NOSOUND for the first test.
goto end
:notpc
echo TPC.EXE was not found in %TP%\BIN.
echo Set TP to your Turbo Pascal directory, then run BUILD again.
echo Example: SET TP=C:\TP
goto end
:failed
echo.
echo Compilation failed. See the compiler error above.
:end
