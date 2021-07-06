# Jet Set Willy z88

This project contains the source code assets for building the z88 port of ZX Spectrum game Jet Set Willy.

## Compilation

To compile you'll need a modern version of z88dk setup and available in the path. The application can then be generated
by invoking `make`.

A .epr file and an OZ5 .app file will be generated.

## Background

The source code is pretty much as it was when released in 1998, so contains (amongst other things):

- Commented out code
- Cryptic labels
- Development comments/queries from the disassembly
- False comments

The following changes have been made:

- Update to assemble with the version of z80asm within z88dk
- Updates to remove old email addresses
- Interrupts aren't disabled whilst playing the themetune

As a result, the version has been bumped.

The game itself has been extensively disassembled, for information see, for example: https://skoolkit.ca/disassemblies/jet_set_willy/

## In-game Controls

The preset keys are:

Left    - O
Right   - P
Jump    - Space
Pause   - H

These movement keys can be redefined to suit your playing style/hand size!

There is also a set of control keys which cannot be redefined:

ESC     - Quit back to intro from game
TAB     - Toggle screen size - mini/standard
DEL     - Toggle inverse background

## Acknowledgements

Jet Set Willy was originally written by Matthew Smith and published by Software
Projects and Bug Byte.
