@echo off
REM make
REM Assembles and links the 32-bit ASM program into .exe which can be used by WinDBG
REM Uses MicroSoft Macro Assembler version 6.11 and 32-bit Incremental Linker version 5.10.7303

REM /c     assemble without linking
REM /coff  generate object code to be linked into flat memory model 
REM /Zi    generate symbolic debugging information for WinDBG
REM /Fl    Generate a listing file
ML /c /coff /Zi In_a_Tight_Corner.asm
if errorlevel 1 goto terminate

REM /debug              generate symbolic debugging information
REM /subsystem:console  generate console application code
REM /entry:start        entry point from WinDBG to the program 
REM                     the entry point of the program must be _start

REM /out:In_a_Tight_Corner.exe  output In_a_Tight_Corner.exe code
REM In_a_Tight_Corner.obj       input In_a_Tight_Corner.obj
REM Kernel32.lib                library procedures to be invoked from the program
REM irvine32.lib
REM user32.lib

LINK /INCREMENTAL:no /debug /subsystem:console /entry:start /out:In_a_Tight_Corner.exe In_a_Tight_Corner.obj Kernel32.lib irvine32.lib user32.lib
if errorlevel 1 goto terminate

REM Display all files related to this program:
DIR In_a_Tight_Corner.*

:terminate
pause