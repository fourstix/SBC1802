	.TITLE	"Spare Time Gizmos COSMAC Microsystem"
;	.SBTTL	"Bob Armstrong [09-SEP-2021]"

; Make sure the echo flag in BAUD.1 is turned on when there's a trap or power up!


;    .d8888b.  888888b.    .d8888b.   d888   .d8888b.   .d8888b.   .d8888b.  
;   d88P  Y88b 888  "88b  d88P  Y88b d8888  d88P  Y88b d88P  Y88b d88P  Y88b 
;   Y88b.      888  .88P  888    888   888  Y88b. d88P 888    888        888 
;    "Y888b.   8888888K.  888          888   "Y88888"  888    888      .d88P 
;       "Y88b. 888  "Y88b 888          888  .d8P""Y8b. 888    888  .od888P"  
;         "888 888    888 888    888   888  888    888 888    888 d88P"      
;   Y88b  d88P 888   d88P Y88b  d88P   888  Y88b  d88P Y88b  d88P 888"       
;    "Y8888P"  8888888P"   "Y8888P"  8888888 "Y8888P"   "Y8888P"  888888888  
;
;          Copyright (C) 2021-2024 By Spare Time Gizmos, Milpitas CA.

;++
;   This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
;   This program is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
; for more details.
;
;   You should have received a copy of the GNU General Public License along
; with this program; if not, write to the Free Software Foundation, Inc.,
; 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;--
;0000000001111111111222222222233333333334444444444555555555566666666667777777777
;1234567890123456789012345678901234567890123456789012345678901234567890123456789

	.MSFIRST \ .PAGE \ .CODES

	.NOLIST
	.INCLUDE "sbc1802.inc"	; SBC1802 hardware and environment definitions
	.INCLUDE "bios.inc"	; Mike's BIOS entry points and declarations
	.INCLUDE "ut71.inc"	; RCA's UT71 entry points and declarations
	.LIST

	.SBTTL	"The SBC1802"

;++
; OVERVIEW
;   After building the Elf 2000 almost 20 years ago, I decided it was time for
; another 1802 based project. The primary goal of the Elf2K was to be as much
; like the original Elf as possible, however this time around the goals were
; entirely different.
;
; My plan was to design a machine that
;
;    * could run both ElfOS and RCA MicroDOS
;    * used as many of the LSI RCA CDP18xx family chips as possible
;    * supported multiple peripherals and mass storage devices
;
;   I ended up splitting the design into two boards, a "base" board and an
; expansion board. Originally I planned to fit it all onto a single board but
; that ended up being too large and two boards, which can be stacked in the
; vertical dimension, are much more practical. The expannsion board is optional
; and the base board is functional without it. Also, the expansion bus is
; available for additional future, well, expansion.
;
; BASE BOARD
;
; The base board contains -
;
;    * CDP1805 CPU (an 1802 will work too)
;    * 32K EPROM and 64K battery backed up SRAM
;    * CDP1877 priority interrupt controller
;    * CDP1854 UART with CTS/RTS support and programmable baud rate
;    * CDP1879 real time clock with battery backup
;    * IDE/ATA interface
;    * POST display
;    * buffered expansion bus for the expansion card(s)
;    * basic front panel interface
;
;   The memory mapping can be programmed at runtime to support either the ElfOS
; or MicroDOS memory maps; 60K of RAM is available in ElfOS mode and 58K in
; MicroDOS mode. In addition, all 32K of the EPROM can be used by way of a
; simple bank switching scheme. The CDP1879 RTC, the CDP1877 PIC, and the memory
; control register (which controls the memory map/bank switching) are memory
; mapped and occupy 32 bytes of address space. Another 224 bytes of RAM are set
; aside for use by the EPROM firmware as scratchpad storage.
;
;   The base board also contains logic to drive a basic, "turn key" front panel.
; Indicators for POWER, RUN, DISK, and Q are included, along with switches or
; buttons for RESET and ATTENTION. The latter causes a user defined interrupt
; to occur. By using ribbon cables with a DIP header on one end it would be easy
; enough to co-opt the the POST display and DIP switches into front panel LED
; and switch registers. However, note that there is no support for LOAD mode,
; nor the memory protect function, used in the original Elf.
;
;   The base board can be used and is functional without the CDP1877 interrupt
; controller; after all, neither ElfOS nor MicroDOS actually use interrupts of
; any kind. Likewise the base board is functional without the CDP1879 real time
; clock  too, however you'll lose the ability to have the OS time set
; automatically.
;
;EXPANSION BOARD
;
; When installed on the base board, the expansion board adds -
;
;    * RCA style two level I/O
;    * Another CDP1854 serial port
;    * CDP1851 programmable I/O interface
;    * two CDP1855 multiply/divide units
;    * CDP1878 dual counter/timer
;    * AY-3-8912 programmable sound (aka music) generator
;
;   The base board alone has no I/O group logic, however when the expansion
; board is added it implements the standard RCA type two level I/O. With the
; expansion board present all base board ports are now mapped into group 0 or
; 1. I/O port #1 is implemented to write or read the I/O group select register.
;
;   The second serial interface is essentially identical to the primary SLU on
; the base board. This one also implements CTS/RTS handshaking and a
; programmable baud rate and character format.
;
;   The CDP1851 is a 24 bit programmable parallel I/O chip with all the I/O
; pins brought out to a header and are cleverly arranged so that it should be
; possible to implement a Centronics style parallel port. Alternatively they
; can be used as general purpose parallel I/Os as well. Likewise all the inputs
; and outputs for the CDP1878 dual timer/counter are brought out to a header,
; and/or the timers can also be used to generate CPU interrupts at programmed
; intervals.
;
;   The two CDP1855 MDUs are able to compute a 16x16 multiply or 32/16 divide
; operation in 16 clock cycles, which about as long as it takes the 1802/5 to
; execute a single instruction. You just write the desired values to the X and
; Y registers, do one NOP, and then read the result from the Z register.
;
;   The 8912 is a three voice programmable sound chip, including an envelope
; generator. This particular chip is the same one used in the Elf2K music card
; to play play simple MIDI tunes, and was super popular in 1980s vintage arcade
; games and 8 bit microcomputers. Google "chiptunes" for examples of the kinds
; of sounds it can produce. The three sound voices are mixed to produce left,
; center and right channels and sent to a stereo headphone jack.
;
;   Lastly, the expansion card is functional without one or even all of the
; specialty chips installed. The CDP1855s, second CDP1854, CDP1878, CDP1851 and
; the AY3-8912 may all be omitted if you're unable to source them.
;--
	
	.SBTTL	"Revision History"

;++
; 001	-- Start by stealing from the Elf2K project!
;
; 002	-- Create sbc1802.inc; set up the basic startup code and POST framework
;
; 003	-- EPROM checksum test, MCR test and RAM tests
;
; 004	-- CDP1854 SLU0 test
;
; 005	-- CDP1879 RTC test
;
; 006	-- CDP1877 PIC test.  Learn a lot about how the CDP1877 really works!
;
; 007	-- Stub out the expansion board tests. Console SLU0 initialization.
;
; 008	-- Go back and implement basic I/O group test.
;
; 009	-- Much futzing with the IDE detection to get something that works for
;	   one drive, two drives or zero drives!
;
; 010	-- Main loop, COMND, and some simple parsing functions.
;
; 011	-- Invent ERAM and DRAM, and port over EXAMINE and DEPOSIT.
;
; 012	-- Add INPUT and OUTPUT. Expand them to handle I/O groups.
;
; 013	-- Add RUN, CALL and CONTINUE.
;
; 014	-- Add SHOW REGISTERS, SET and TEST (both with no options yet).
;
; 015	-- Add SHOW DP, SHOW RTC and SET RTC.
;	   Change RAMPAGE/RAMSIZE to DPBASE/DPEND.
;
; 016	-- Add HELP and help text.
;
; 017	-- Add SHOW SLU and SET SLU0/SLU1.
;
; 018	-- Add SHOW CONFIGURATION.
;
; 019	-- Add SHOW BATTERY and SET YEAR.
;
; 020	-- Make the memory POST leave all of memory zeroed.
;
; 021	-- Add SHOW IDE and ElfOS boot sniffer.
;
; 022	-- Add Intel .HEX record loading.
;
; 023	-- Add exhaustive memory test, TEST RAM0|RAM1.
;
; 024	-- Implement POST for SLU1.
;
; 025	-- Fix bug is SHOW SLU that reports bogus data for SLU1.
;
; 026	-- Update the BOOT command to use the F_SDBOOT call.
;
; 027	-- Implement the DUMP command for any storage device.
;
; 028	-- Fix POST 1 to work with the redefined f_IDESIZE and F_IDEID.
;
; 029	-- Change "SHOW IDE" to "SHOW DISK" and rewrite it to work with all the
;	   new F_SDxxx calls so that it can be shared with "SHOW TAPE".
;
; 030	-- Add the "SHOW TAPE" command to show TU58 status.
;
; 031	-- Make the "BOOT" command with no argument boot the default device.
;
; 032	-- At GRPTS9: there's a SEX PC that should be SEX PC0!  THis caused
;	   hours and hours of head scratching!!!!!
;
; 033	-- Add 8912 music player and "TEST PSG" ...
;
; 034	-- Fix SHOW EF command so that groups really work (every time we print
;	   anything the group gets reset to BASEGRP!).
;
; 035	-- "E FFF0 FFFF" (or any examine that ends with $FFFF) loops forever!
;	   Explicitly check for address roll over and quit.
;
; 036	-- change our version numbering scheme to just "mm(eeeee)", where mm
;	   is the major version and eeeee is the edit number. Change the
;	   BIOS version number the same way.
;
; 037	-- show the configuration on boot (after the RTC and IDE) so the
;	   user will know the POST results
;
; 038	-- If two level I/O (and by inference, the expansion board) isn't installed,
;	   then skip the POSTs for SLU1, PPI, CTC, MDU and PSG ...
;
; 039	-- Allow "SET RESTART ddd" to boot from any storage unit.  Implement (it
;	   wasn't before!) "SET RESTART xxxx".  Change "SET RESTART NONE" to
;	   "SET NORESTART".
;
; 040	-- clean up the baud rate initialization and format setting for both SLUs.
;	   If no baud rate is saved, autobaud SLU0 and force SLU1 to 9600 8N1.
;
; 041	-- Invent TTYINI to set up both SLUs and call it from SYSINI, and also
; 	   after a breakpoint/trap.  Also, ensure that BAUD.1 gets set to 1 to
;	   enable echo.
;--
VERMAJ	.EQU	1	; major version number
VEREDT	.EQU	41	; and the edit level

	.SBTTL	"Startup Vectors"

;   After a reset the SBC1802 starts up with the BOOT memory map selected.  This
; maps the EPROM everywhere, both at addresses $0000 and $8000, and so the first
; instruction executed comes from right here.  There's nothing in the hardware
; to automatically change the memory map, and so the BOOT map stays selected
; until the first of the POST code at SYSINI explicitly changes it.
;
;   Even more importantly, remember that this chunk of memory here, from $8000
; to $87FF, is also the part where MicroDOS expects to find UT71.  We don't have
; to match the UT71 code exactly, but we must be careful to preserve all the
; entry vectors that MicroDOS programs expect.  Fortunately we have a 32K ROM
; at our disposal where as the RCA guys had only 2K, so we can afford to waste
; some space here and there.  
;
;   The first UT71 entry point that we have to work around comes at $813B, so we
; have a few bytes here for the startup code an copyright notices.  The first
; five bytes in EPROM are a DIS, $00 (to disable interrupts) and then a long
; branch to the POST code.  This code appears at $8000 in the ROM0/ROM1 and
; MicroDOS maps, but most importantly it appears at $0000 in the BOOT map.
	.ORG	COLD		; $8000 (or $0000 in the boot map!)
	DIS			; disable interrupts (just in case!)
	 .BYTE	 $00		; ...
	LBR	SYSINI		; go to SYSINI and start the self test

;   And then at $8005 is a branch to the warm start/breakpoint trap restart
; address.  This code skips the POST, prints out the saved user registers and
; then starts up the command scanner.
	.ORG	WARM		; should be $8005
	LBR	SYSIN5		; warm start

;   And lastly the firmware version, name, copyright notice and date all live
; at $8008.  These strings should appear at or near to the beginning of the
; EPROM, because we don't want them to be hard to find, after all!
VERSION:.BYTE	VERMAJ\ .WORD VEREDT
SYSTEM:	.TEXT	"\r\nSBC1802 FIRMWARE\000"
RIGHTS:	.TEXT	"Copyright (C) 2021-2024 by Spare Time Gizmos.  All rights reserved.\000"
#include "sysdat.asm"

; Skip over the rest of the space used by UT71 ...
	.ORG	UTBASE+UTSIZE

	.SBTTL	"POST Codes"

;++
;   The following pages (and there are several) of code test the various SBC1802
; peripherals and options.  The current power on self test (aka POST) status is
; shown on the 7 segment display.  Some POST failures are fatal and will halt
; the system with that code displayed.  In particular, POST codes F thru C -
; EPROM failures, MCR failures or RAM failures - prevent any kind of normal
; operation.
;
;   The other POST codes and tests are non-fatal and we simply remember, in a
; bit vector, which devices work and which ones don't.  A non-working device is
; not necessarily a sign of bad hardware; it may be that chip or option simply
; isn't installed.  The system is usable, at least on some level, without them.
;
;   The POST tests and associated displays are -
;
; blank   - CPU dead, gross hardware failure
; POST F  - EPROM checksum failure
; POST E  - MCR or memory mapping failure
; POST D  - RAM 1 bad
; POST C  - RAM 0 bad
; POST B  - I/O group select failure
; POST A  - CDP1854 SLU0 failure 
; POST 9  - CDP1879 RTC failure
; POST 8  - CDP1877 PIC tests
; POST 7  - CDP1854 SLU1 tests
; POST 6  - CDP1851 PPI tests
; POST 5  - CDP1878 TIMER tests
; POST 4  - CDP1855 MDU tests
; POST 3  - AY-3-8912 PSG tests
; POST 2  - autobaud
; POST 1  - IDE tests
; POST 0  - waiting for user input
; decimal - OS booted
;
;   Several conventions are followed during the POST routines -
;
;   * REGISTER 0 IS ALWAYS THE PC AND SCRT IS NOT AVAILABLE!
;   * After the memory tests, DP and SP are valid and point to the data page
;   * After the memory tests, the ROM0 memory map is always selected.
;   * P4 contains the bitmap of working hardware.
;   * Interrupts are disabled.
;--

	.SBTTL	"POST F - EPROM Test"

;   We come here shortly after a cold start.  Interrupts have been disabled and
; POST code F is currently displayed, however the memory map is still the BOOT
; map and we still have X=P=0.  The first test we want to do is to checksum the
; EPROM, which we can do using the BOOT map.  In fact we want to checksum EPROM
; using the BOOT map and by scanning addresses $0000 to $7FFF because this range
; covers the entire EPROMs with no "holes".  If we tried to checksum the space
; from $8000 to $FFFF we'd be messed up by the RAM space at $FExx and especially
; the memory mapped peripherals like the CDP1877 and CDP1879.
;
;   The checksum is calculated so that the 16 bit unsigned sum of all the bytes
; in the ROM, INCLUDING the last two bytes, is equal to the last two bytes.  If
; the EPROM checksum fails, then we just hang here with POST F displayed.
; Note that this code assumes a 32K byte EPROM starting at address $8000.
SYSINI:	POST(POSTF)		; POST F - let the world know we're alive

;   There are supposed to be some rudimentary CPU tests here, but I never
; got around to writing any!  We'll just fall into the EPROM checksum test...

ROMCHK:	RCLR(P1)		; checksum from $0000 to $7FFF
	RCLR(P2)		; and accumulate the checksum in P2
	SEX	P1		; use P1 to address memory now

; Read a byte and accumulate a 16 bit checksum in P2...
ROMCK1: GLO	P2		; get the low byte of the current total
	ADD			; add another byte from M(R(X))
	PLO	P2		; update the low byte
	GHI	P2		; and propagate any carry bit
	ADCI	$00		; ...
	PHI	P2		; ...
	IRX			; on to the next byte
	GHI	P1		; have we rolled over from $7FFF to $8000?
	XRI	$80		; ???
	LBNZ	ROMCK1		; not yet - keep checking

; Verify that what we calculated matches the last two bytes in EPROM...
	RLDI(P1,CHKSUM)		; the checksum lives here in EPROM
	GHI	P2		; get the high byte first
	SM			; does it equal the byte at $FFFE ?
	LBNZ	$		; fail if it doesn't
	IRX			; test the low byte next
	GLO	P2		; ...
	SM			; ...
	LBNZ	$		; ...

; Fall thru into the MCR/mapping test code...
	.SBTTL	"POST E - MCR and Memory Mapping Tests"

;   We know that the EPROM is working but we're still using the BOOT memory map.
; The next step is to figure out whether the memory mapping hardware works (more
; or less) and then switch to a map where RAM is accessible. Remember that right
; now the PC is somewhere in the $88xx range and only only safe memory maps are
; ROM0 or ROM1.  Switching to either the MicroDOS or ELfOS maps would crash us,
; since this part of EPROM would become unmapped.
;
;   Also remember that we have battery backup for RAM and it's possible that
; there's good stuff (i.e. stuff we want to keep!) stored in RAM right now.
; Whatever we do here has to be non-destructive.
MCRTST:	POST(POSTE)		; POST code E - MCR/mapping test

;   Write ROM1 to the MCR and then read it back to make sure the MCR actually
; changed.  Then write ROM0 to the MCR, read that back, and make sure we can
; really read back what we wrote.
	RLDI(P1,MCR)		; point P1 at the memory control register
	LDN	P1		; read the MCR
	ANI	MC.MASK		; check only the mapping bits
	LBNZ	$		; they should all be zero now
	LDI	MC.ROM1		; select the ROM1 map
	STR	P1		; ...
	LDN	P1		; read it back
	ANI	MC.MASK		; and be sure it changed
	XRI	MC.ROM1		; ...
	LBNZ	$		; spin forever if it's not working
	LDI	MC.ROM0		; do the same thing with the ROM0 map
	STR	P1		; ...
	LDN	P1		; ...
	ANI	MC.MASK		; ...
	XRI	MC.ROM0		; ...
	LBNZ	$		; ...

;   Right now EPROM should be mapped to the upper half of memory and SRAM #0
; mapped to the lower half.  Save the current contents of location 0 and then
; write $AA there.
	RCLR(P2)		; point P2 at location zero
	LDN	P2		; get the current value there
	PHI	P3		; save that for later
	LDI	$AA		; then write AA there
	STR	P2		; ...

;   Swap to ROM1 and that should make SRAM #1 to the lower half of RAM.  Save
; location zero again and this time write $55 to it instead...
	LDI	MC.ROM1		; switch to the ROM1 map
	STR	P1		; write the MCR
	LDN	P2		; save the new location zero
	PLO	P3		; ...
	LDI	$55		; and write 55 to this RAM chip
	STR	P2		; ...

;   Go back to the ROM0 map and check location zero to see if the $AA we wrote
; is still there.  If it is then restore the original contents of that byte.
	LDI	MC.ROM0		; back to the ROM0 map
	STR	P1		; ...
	LDN	P2		; read location zero
	XRI	$AA		; anything other than $AA is BAD
	LBNZ	$		; ...
	GHI	P3		; Great!
	STR	P2		; restore the original RAM contents

; Now verify that SRAM #1 hasn't changed ...
	LDI	MC.ROM1		; change the memory map again
	STR	P1		; ...
	LDN	P2		; ...
	XRI	$55		; this time it should be $55
	LBNZ	$		; ...
	GLO	P3		; restore the original contents
	STR	P2

;   Fall into the RAM key test WITH the ROM1 map still selected.  The ROM0/ROM1
; mapping mode has no effect on our data page mapping, and checking for the key
; with ROM1 selected is another little test.
;
;   There's a small delay here just to make the "E" POST code show up for a
; moment.  Totally wasteful, but it looks better when you can see it...
;;	DELAY(300)

	.SBTTL	"RAM Key Test"

;   The next step is to figure out whether our private RAM space (at $FExx) is
; working AND (assuming we have battery backup) whether the current contents
; are valid.  If the contents are valid then we want to leave it alone since
; there might be useful stuff stored in there, but if it's not then we 
; initialize the RAM to zeros.
KEYTST:	RLDI(P1,KEY)		; P1 points to the RAM key
	RLDI(P2,CHKSUM)		; and P2 points to the EPROM checksum
	SEX	P1		; let X point to EPROM

;   The RAM "key" should consist of the initials "RLA" (yes, those are mine!)
; followed by the checksum of this EPROM.  The latter ensures that the RAM
; contents are invalidated if the firmware is changed.
	LDXA			; get the first byte of the key
	XRI	'R'		; test it
	LBNZ	RAMTST		; branch if the key doesn't match
	LDXA			; next byte
	XRI	'L'		; ...
	LBNZ	RAMTST		; ...
	LDXA			; and the third
	XRI	'A'		; ...
	LBNZ	RAMTST		; ...
	LDN	P2		; finally, test the last two bytes ...
	XOR			;  ... against the EPROM checksum
	LBNZ	RAMTST		; ...
	IRX\ INC P2		; advance both pointers
	LDN	P2		; and test one more byte
	XOR			; ...
	LBNZ	RAMTST		; ...

; Here if the current RAM contents are valid...
	LBR	RAMOK		; skip the RAM test and initialization

	.SBTTL	"POST D and C - Basic RAM test"

;   Now that we know there's nothing in RAM worth keeping, we can do a very
; simple but destructive test on both RAM chips.  All this code does is to write
; each RAM location with its address and then go back to verify that all are
; correct.  It does this first for RAM1, which is currentlys selected, and then
; flips the memory map to select RAM0 and repeats the test.
;
;   It's pretty crude and not a 100% guarantee that RAM is working, but it's
; fast and easy.  There's a more extensive memory test in the firmware that can
; be invoked with the "TEST RAM" command if you want more.
;
;  POST code D is the RAM 1 test, and POST code C is the RAM 0 test.
RAMTST:	POST(POSTD)		; test RAM #1 first - POST code D

; Write each pair of bytes with its full 16 bit address ...
RAMTS1:	RCLR(P1)		; start from location zero
RAMTS2:	GLO P1\ STR P1\ INC P1	; save the address in two bytes
	GHI P1\ STR P1\ INC P1	; ...
	GHI P1\ XRI $80		; have we rolled over from $7FFF -> $8000?
	LBNZ	RAMTS2		; nope - keep writing

; Now go back and verify that each pair is correct ...
	RCLR(P1)		; ...
	SEX	P1		; ...
RAMTS3:	GLO P1\ XOR		; test the low byte 
	LBNZ	$		; spin forever if RAM is bad
	IRX\ GHI P1\ XOR	; and test the high byte
	LBNZ	$		; ...
	IRX\ GHI P1\ XRI $80	; quit when we've done all 32K bytes
	LBNZ	RAMTS3		; ...

; Make a third pass to zero everything in RAM ...
	RCLR(P1)		; ...
RAMT31:	LDI 0\ STR P1\ INC P1	; zero another byte
	GHI P1\ XRI $80		; have we done everything up to $7FFF?
	LBNZ	RAMT31		; no - keep going

;   We've successfully tested this one RAM chip - see which one it was and, if
; it was RAM1, then flip the mapping and test RAM0 next ...
	RLDI(P1,MCR)		; read the MCR to find out where we are
	LDN	P1		; ...
	ANI	MC.MASK		; check just the mapping bits
	XRI	MC.ROM0		; did we just test RAM 0?
	LBZ	RAMTS4		; yes - we're done now
	LDI	MC.ROM0		; no - test RAM #0 next
	STR	P1		; ...
	POST(POSTC)		; change the POST code to C
	LBR	RAMTS1		; and go test again

; Fall into the data page initialization code next ...
RAMTS4:
	.SBTTL	"Data Page Initialization"

;   Here when we're done testing RAM.  The ROM0 mapping is still selected, and
; we'll leave it that way for the rest of the POST.  The next step is to zero
; our own data page and then write the magic key to memory for the next time
; around.  Note that we have to wait until now to do this since the memory test
; we just finished scribbles over ALL of RAM, including what would become our
; own data page!
;
;   Note that POST code C is still displayed at the moment, but none of this
; code can fail so we don't really care ...
RAMINI:	RLDI(DP,DPBASE)		; point to our own data page
RAMIN1:	LDI	$00		; set memory to zero
	STR	DP		; zero this byte
	INC	DP		; and on to the next
	GLO	DP		; have we done them all?
	XRI	LOW(DPEND+1)	; ???
	LBNZ	RAMIN1		; nope - keep clearing...

; Store the correct "key" into the data page for the next time we're here ...
	RLDI(DP,KEY+4)		; DP points to the SRAM key
	RLDI(P1,CHKSUM+1)	; and P1 points to the EPROM checksum
	SEX	DP		; use DP to address memory
	LDN	P1		; store the two checksum bytes first
	STXD			; ...
	DEC	P1		; (and in "backwards" order!
	LDN	P1		; ...
	STXD			; ...
	LDI	'A'		; now store the rest of the key
	STXD			; (again, "backwards"!)
	LDI	'L'		; ...
	STXD			; ...
	LDI	'R'		; ...
	STXD			; ...

;   We're done with all memory tests!  Since we know that RAM is OK and useful,
; from now on DP will be valid and points to DPBASE, and SP will be valid and
; pointing to our private stack.  The ROM0 map is selected for the rest of the
; POST, and from now on we'll start accumulating a bitmap of working devices
; and options in P4 ...
RAMOK:	RLDI(P1,MCR)		; be sure ROM0 is selected
	LDI	MC.ROM0		; ...
	STR	P1		; ...
	RLDI(DP,DPBASE)		; setup DP
	RLDI(SP,STACK)		; setup SP
	RCLR(P4)		; and clear the map of working hardware

; Now fall into the I/O Group tests ...
	.SBTTL	"POST B - I/O Group Select Tests"

;   The next thing is to test whether the I/O group selection register is
; present and working.  This hardware is actually part of the expansion board
; and doesn't exist on the base board, so it's entirely possible that it isn't
; here. 
;
;   As is the RCA standard, the I/O group select register is always accessed by
; I/O port 1 IN ANY GROUP.  In the case of the SBC1802 this register is both
; writable AND readable, so testing it is as easy as writing values to it and
; then trying to back what we wrote.  Changing the I/O group select will change
; the devices selected, but as long as we only access port 1 we'll be fine.
GRPTST:	POST(POSTB)		; POST code B - I/O Group Test

;   The SBC1802 I/O group register implements six bits, D0 thru D5, although
; only D0 thru D3 are actually used.  First we do a basic test to see if the
; hardware is present at all ...
	OUT	GROUP		; write %1010 to the group register
	 .BYTE	 $0A		; ...
	SEX	SP		; then read it back
	INP	GROUP		; ...
	ANI	$F		; ...
	XRI	$0A		; did it work?
	LBNZ	NOGRP		; no - assume no hardware present

;   Looks like there is some kind of I/O group register out there, so go thru
; and test all sixteen possible bit combinations to make sure they all work.
; Note that any failure here is fatal and the POST hangs.  If the I/O group
; selection isn't working then we really can't be sure of which devices are
; being addressed, so the best plan is to quit while we're ahead.
GRPTS0:	LDI	$0F		; start testing with group F and work down
GRPTS1:	STR	SP		; ...
	OUT	GROUP		; write the test pattern to the group
	DEC SP\ DEC SP		; point to a free stack location
	INP	GROUP		; and try to read back what we wrote
	ANI	$0F		; ignore any extra bits
	INC	SP		; and point to our original test value
	XOR			; are they the same?
	LBNZ	$		; no - spin here forever!
	LDI	1		; decrement the test pattern
	SD			; ...
	LBDF	GRPTS1		; and keep going until we hit zero

;   All done - remember that we have I/O group hardware AND always leave with
; group 1 (the base board group) selected ...
GRPTS9:	SEX	PC0		; select the base group
	OUT	GROUP		; ...
	 .BYTE	 BASEGRP	; ...
	GHI	P4		; remember that group hardware is present
	ORI	H1.TLIO		; ...
	PHI	P4		; ...

; And fall into the next test ...
NOGRP:
	.SBTTL	"POST A - CDP1854 SLU0 Tests"

;   The next phase in the POST is to test SLU0, the CDP1854 UART that drives the
; console terminal port.  The CDP1854 doesn't have a loopback mode and, even
; worse, the control register is write only.  As such it isn't super testable,
; but we can do a few basic things like transmit a null byte and verify that the
; THRE and TSRE bits set as expected.  
;
;   The code also initializes the character format (always 8N1 for the console)
; and the baud rate.  If the data page contents are valid then the previously
; selected baud rate is restored; otherwise 9600bps is used as a default.  It's
; important that we initialize this here, because we're going to use the console
; UART later to generate interrupt requests for the PIC test.
SL0TST:	POST(POSTA)		; POST code A - SLU0 test

; Initialize the baud rate generator first...
	LDI LOW(SLBAUD)\ PLO DP	; point to the saved baud rate
	LDN	DP		; and read it
	LSNZ			; skip if a baud rate is saved
	 LDI	 BD.DFLT	; otherwise use the default
	SEX SP\ STR SP		; and store the baud rates
	OUT SLUBRG\ DEC SP	; turn on the baud rate generator

; Initialize the CDP1854 control register...
	SEX	PC0		; write the UART control word
	OUT	SL0CTL		; ...
	 .BYTE	 SL.8N1+SL.IE	; clear BREAK but set IE and format 8N1

;   Read the UART status register twice - the first time is just to clear any
; error or DA bits that might be left over - and then verify that the THRE and
; TSRE bits are set and the FE, PE, OE and DA bits are cleared.  
SL0TS0:	SEX	SP		; point to the stack again
	INP	SL0BUF		; clear the DA and OE bits
	INP	SL0STS		; then clear the THRE and TSRE bits
	NOP			; delay for just an instant
	INP	SL0STS		; and then read it again
	ANI	SL.THRE+SL.TSRE+SL.FE+SL.PE+SL.OE+SL.DA
	XRI	SL.THRE+SL.TSRE	; now these bits should be set
	LBNZ	NOSLU0		; quit now if failure

;   Even though the THRE bit is set AND the IE bit is set, the UART should not
; be interrupting because TR is not set.  Test that, and then set TR and test
; that IRQ is asserted.  Note that setting the TR bit in the control register
; is supposed to leave all other control bits unchanged.
	B_SL0IRQ  NOSLU0	; die if an interrupt is requested now
	SEX	PC0		; now set the TR bit
	OUT	SL0CTL		; ...
	 .BYTE	 SL.TR		; all other bits should be unaffected
	BN_SL0IRQ NOSLU0	; IRQ _should_ be set now

; Load two null bytes into the transmitter buffer and send them...
	OUT	SL0BUF		; send one null
	 .BYTE	 0		; ...
	NOP			; delay just a moment
	OUT	SL0BUF		; and then send another
	 .BYTE	 0		; ...

; Verify that THRE, TSRE and IRQ are now all cleared ...
	SEX	SP		; ...
	INP	SL0STS		; read the UART status again
	ANI	SL.THRE+SL.TSRE	; check both these bits
	LBNZ	NOSLU0		; fail if not set
	B_SL0IRQ  NOSLU0	; there should be no IRQ either

;   Now poll the status continuously.  The THRE bit should set first, followed
; later by the TSRE bit.  If these two bits don't get set, or they don't get set
; in that particular order, then we'll just spin here forever.
SL0TS2:	INP	SL0STS		; read the status
	ANI	SL.THRE+SL.TSRE	; we only care about these bits
	XRI	SL.THRE		; look for THRE to set first
	LBNZ	SL0TS2		; wait as long as necessary
SL0TS3:	INP	SL0STS		; now wait for TSRE to set too
	ANI	SL.THRE+SL.TSRE	; ...
	XRI	SL.THRE+SL.TSRE	; ...
	LBNZ	SL0TS3		; ...
	B_SL0IRQ  NOSLU0	; and the IRQ should go away too

; All done testing the UART. Leave with the IE and TR bits cleared ...
SL0TS9:	SEX PC0\ OUT SL0CTL	; ...
	 .BYTE	 SL.8N1		; clear IE and TR, set format 8N1
	GHI	P4		; set the SLU0 OK bit
	ORI	H1.SLU0		; ... in the hardware configuration
	PHI	P4		; ...
;;	DELAY(300)

; Fall into the next test ...
NOSLU0:
	.SBTTL	"POST 9 - CDP1879 Real Time Clock Tests"

;   Now test the CDP1879 real time clock chip.  Remember that this chip is
; memory mapped at address RTCBASE, so neither I/O instructions nor the I/O
; group select will help you here.  The good news is that the RTC has several
; registers that are read/write so we can easily test to see if it's present
; and working, but the bad news is that it might be busy keeping track of the
; time of day and we don't want to do anything that would screw it up.
RTCTST:	POST(POST9)		; the RTC test is POST 9

;   Initialize the clock control register for a 32kHz crystal and a 250ms square
; wave output.  If the clock is already running then this should be harmless,
; and if this is a brand new board (or the battery is dead) then we have to do
; this before the clock can do anything...
	RLDI(P1,RTCBASE+RTCCSR)	; point to the control/status register
	LDI	RT.STRT+RT.O32+RT.CK2
	STR	P1		; turn on the clock

;   Writing the control register (which we just did!) will clear any interrupt
; requests that might be present now.  That should drop the RTC IRQ output and
; clear the clock IRQ bit in the status register ...
	B_RTCIRQ NORTC		; IRQ should be cleared now
	LDN	P1		; check the status register too
	ANI	RT.CIRQ		; check the clock IRQ bit
	LBNZ	NORTC		; and it should be clear too

;   Now twiddle our thumbs and wait for the clock output to toggle.  This will
; set the IRQ output and also the clock IRQ flag in the status register.
RTCTS1:	LDN	P1		; read the status register
	ANI	RT.CIRQ		; wait for the clock IRQ to set
	LBZ	RTCTS1		; ...
	BN_RTCIRQ NORTC		; the IRQ output should also be set

;   That's all we're going to do for testing the RTC.  Disable the clock output
; to prevent any additional interrupts before proceeding ...
RTCTS2:	LDI	RT.STRT+RT.O32	; turn off the square wave output
	STR	P1		; ...
	LDN	P1		; read the status register
	ANI	RT.CIRQ+RT.AIRQ	; verify that both interrupt bits are cleared
	LBNZ	NORTC		; ...
	B_RTCIRQ  NORTC		; and the RTC IRQ output should go away too

; Set the RTC OK bit in the hardware status and we're done ...
	GHI	P4		; ...
	ORI	H1.RTC		; ...
	PHI	P4

; Fall into the PIC test ...
NORTC:
	.SBTTL	"POST 8 - CDP1877 Programmable Interrupt Controller Tests"

;   The next test is for the CDP1877 priority interrupt controller, aka PIC.
; Like the RTC and MCR, this device is memory mapped.  Worse, it does not have
; even on single read/write register - all the PIC registers are either read
; only or write only.  That makes it impossible to test for the basic existence
; of  the PIC by writing one of its registers and then trying to read back what
; we wrote.
;
;   Also, to test the PIC we need to cause an interrupt request to occur by some
; means, but fortunately we have two convenient ways to do this.  We have SLU0,
; which will interrupt when the transmitter is idle, and we have the RTC, which
; can generate periodic clock interrupts.  We've already tested both of those
; devices and at this point we know that they're working.
;
;   And we need a way to know when the PIC is telling the CPU to interrupt.  We
; could actually let the 1802 interrupt, but that's a bit awkward for testing.
; Fortunately there is an easier way - the INT output of the PIC is wired to
; bit 3 in the MCR, and we can tell if the PIC is requesting an interrupt simply
; by testing that bit.  Note that the logic for this bit is inverted, so a one
; bit is no interrupt request and a zero is an active interrupt.
;
;   The CDP1877 datasheet isn't too clear on a couple of the more subtle points
; of PIC operation.  Here are a few helpful hints that I learned the hard way:
;
;   * The IRn inputs are all NEGATIVE EDGE TRIGGERED.  The F-F associated with
;     each input is set by a falling edge on the IRn pin and is cleared when
;     that interrupt vector is delivered to the CPU.  The associated IRn input
;     will not interrupt again until it returns to high and then generates
;     another falling edge.
;
;   * A one bit in the MASK register DISABLES the corresponding interrupt.  A
;     MASK register of all zeros enables EVERYTHING!
;
;   * Reading the STATUS register gives you the current state of ALL IRn inputs,
;     regardless of whether they're masked or not.  Also, reading the STATUS
;     register CLEARS the interrupt F-F for any unmasked IRQs.  I don't think it
;     clears the F-F for masked interrupts though (but I'm not sure about that).
;
;   * Reading the POLL register simply returns the last byte of the calculated
;     interrupt vector for any active interrupt(s).  Remember that the PIC
;     always returns three bytes after an interrupt - C0 (LBR), the vector PAGE
;     (which is defined by us), and the vector address.  The last byte of this
;     sequence is the only thing that isn't predetermined and the POLL register
;     gives you a shortcut to get there without the whole LBR rigmarole.  Also,
;     like STATUS, reading the POLL register CLEARs the associated request F-F.

PICTST:	POST(POST8)		; POST 8 - CDP1877 PIC tests

;   We can't test the PIC unless the RTC and SLU0 are both OK.  If we were a
; little more motivated then it's possible that we could still do something,
; but I'm feeling lazy.  Just punt on the PIC if those other devices failed.
	GHI	P4		; get the hardware flags
	ANI	H1.SLU0+H1.RTC	; are both the RTC and SLU0 OK?
	XRI	H1.SLU0+H1.RTC	; ???
	LBNZ	NOPIC		; just give up if not

;   Initialize the PIC - set the vector address to $84C0 (from the example in
; the RCA datasheet - it doesn't really matter what we use here) and the vector
; interval to 4 bytes. Set the mask register so that only RTC interrupts are
; enabled - we're going to test to make sure that the SLU IRQ is masked out.
	RLDI(P1,PICBASE+PICMSK)	; address the mask register first
	LDI	~IM.RTC		; disable all IRQs EXCEPT the RTC
	STR	P1		; ...
	INC P1\ INC P1\ INC P1\ INC P1
	LDI	$C0+PI.VS4B+PI.NRMR
	STR	P1		; set the vector and spacing, reset pending IRQs
	INC P1\ INC P1\ INC P1\ INC P1
	LDI	$84		; ...
	STR	P1		; and lastly load the page register

;   Get SLU0 to request an interrupt by first setting IE and then setting TR.
; THRE should already be set, so that should cause an instant interrupt.
	OUT	SL0CTl		; first set IE
	 .BYTE	 SL.8N1+SL.IE	; ...
	OUT	SL0CTL		; and then set TR
	 .BYTE	 SL.TR		; ...
	BN_SL0IRQ $		; wait for the SLU0 IRQ ...

;   And also get the RTC to request an interrupt, so that we have multiple
; interrupts active.  Note that SLU0 is priority 4 and the RTC is priority 1
; (remembering that 7 is the highest and 0 the lowest), HOWEVER SLU0 interrupts
; are masked so the RTC should win...
	RLDI(P2,RTCBASE+RTCCSR)	; point to the RTC control/status register
	LDI	RT.STRT+RT.O32+RT.CK2
	STR	P2		; turn on the clock
	NOP			; FOR ALIGNMENT!
	BN_RTCIRQ  $		; and wait for the RTC interrupt

;   If we read the MCR now we should see that the PIC's INT output is asserted.
; Remember that this bit is inverted, so a zero means an active request.
	RLDI(P3,MCR)		; read the MCR 
	LDN	P3		; ...
	ANI	MC.PIRQ		; is the PIC requesting an interrupt?
	LBNZ	NOPIC		; no PIC if it isn't

;   Read the PIC vector register three times and we should receive $C0 (a LBR
; opcode), followed by $84 (the page address we just set, above), and lastly
; $C4 (the second vector offset, for IR1 and a spacing of 4).  BTW, remember
; that P1 still points to the PAGE register, and the VECTOR register is the
; same address!
	LDN	P1		; should get C0 ...
	XRI	$C0		; ...
	LBNZ	NOPIC		; no PIC/bad PIC if anything else
	LDN	P1		; then we should read $84
	XRI	$84		; ...
	LBNZ	NOPIC		; ...
	LDN	P1		; and this is the important part
	XRI	$C4		; the second vector should be selected!
	LBNZ	NOPIC		; ...

; Now change the MASK register to enable SLU0 interrupts ...
	LDI LOW(PICBASE+PICMSK)	; backup to the mask register
	PLO	P1		; ...
	LDI    ~(IM.SLU0+IM.RTC); enable both SLU0 and RTC interrupts now
	STR	P1		; ...

;   This time read the polling register, which is a shortcut to the last byte
; of the interrupt vector.  This time we should see $D0, which is $C0 (the base
; address we programmed, above) plus $10.  The latter is the correct offset for
; the SLU0 IR4 vector with a spacing of 4 bytes.
	INC P1\ INC P1\ INC P1\ INC P1
	LDN	P1		; get the PIC response
	XRI	$C0+$10		; looking for this result
	LBNZ	NOPIC		; nope - this PIC is bad!

;   That should have cleared all pending interrupt requests, so if we check the
; PIC's INT output now we should find that it ISN'T asserted any more ...
	LDN	P3		; ...
	ANI	MC.PIRQ		; is the PIC requesting an interrupt?
	LBZ	NOPIC		; (remember - 1 means no interrupt!)

; Success!  Reset the SLU and RTC back to normal ...
	SEX	PC0		; disasble SLU0 interrupts
	OUT	SL0CTl		; by clearing IE
	 .BYTE	 SL.8N1		; ...
	LDI	RT.STRT+RT.O32	; and turn off the RTC clock output
	STR	P2		; ...
	B_SL0IRQ  $		; be sure both IRQs are cleared
	B_RTCIRQ  $		; ...

;   Put the CDP1877 to sleep for now.  SET the mask register to all 1s (which
; will disable all interrupt sources) and clear the vector address.  Set the
; vector spacing to 4 bytes and reset any pending requests (shouldn't be any
; right now, but...)
	LDI LOW(PICBASE+PICMSK)	; backup to the mask register
	PLO	P1		; ...
	LDI	$FF		; disable all interrupt sources
	STR	P1		; ...
	INC P1\ INC P1\ INC P1\ INC P1
	LDI	PI.VS4B+PI.NRMR	; select 4 byte spacing and reset all requests
	STR	P1		; ...
	INC P1\ INC P1\ INC P1\ INC P1
	LDI	$00		; ...
	STR	P1		; and lastly load the page register

; Test one more time to be sure that there is NO IRQ to the CPU ...
	LDN	P3		; read the MCR
	ANI	MC.PIRQ		; is the PIC requesting an interrupt?
	LBZ	$		; (remember that 1 means no interrupt!)

; Set the PIC OK bit in the hardware status and we're done ...
	GHI	P4		; ...
	ORI	H1.PIC		; we have a functional PIC!
	PHI	P4		; ...

; Fall into the next test ...
NOPIC:

	.SBTTL	"Expansion Board Tests"

;++
;   The next group of POSTs - SLU1, parallel interface, Counter/Timer, 
; Multiply/Divide unit, and the programmable sound generator - are
; all expansion board device.  Before we start testing them we need to
; see if the two level I/O and the expansion board is even installed.
; If it isn't, then without the group select hardware some of these
; tests can have bad side effects on base board hardware (e.g. the
; SLU1 test will screw up the base board SLU0!).  
;
;  If there's no two level I/O, then skip directly to SYSINI2...
;--
EXPTST:	GHI	P4		; get the hardware flags
	ANI	H1.TLIO		; was two level I/O discovered?
	LBZ	SYSIN2		; no - skip all these tests

	.SBTTL	"POST 7 - CDP1854 SLU1 Tests"

;++
;   The next phase in the POST is to test SLU1, the CDP1854 UART that drives
; the TU58 serial disk (or whatever other peripheral you like).  It's very
; similar to the SLU0 test, but somewhat simplified.  A unique complication
; here is that there may be a TU58 connected to this port, and when we try to
; transmit null characters for testing the TU58 will respond by sending stuff
; back to us. That appears in the receiver buffer and can confuse the test.
;
;   To get around this, we would like to set the BREAK bit in the CDP1854
; control register and thus suppress anything from reaching the TU58.  We
; would like to, but we can't!  Turns out that on the CDP1854 the break bit,
; in addition to forcing TXD low, also inhibits the transmitter completely.
; THRE, TSRE will not set and bytes written to the THR are ignored as long
; as the BREAK bit is set.  Bummer!
;
;   So we just do our test anyway.  Probably the TU58 will be unhappy, but it
; will resynchronize as soon as TUINIT is called.
;
;   Note that the SLU0 code has already initialized the baud rate generator for
; SLU1, but we still need to program the UART character format.  That's either
; what was stored in the NVR or 8N1 by default.  And remember that SLU1 is on
; the expansion board and therefore is NOT in the default I/O group!
;--
SL1TST:	POST(POST7)		; POST code 7 - SLU1 test

; Initialize the CDP1854 control register...
	SEX PC0\ OUT GROUP	; first select SLU1 I/O group
	 .BYTE	 SL1GRP		; ...
	LDI LOW(SL1FMT)\ PLO DP	; point to the saved format
	LDN DP \ LSNZ		; skip if a format is saved
	 LDI	 SL.8N1		; otherwise use the default
	ORI	SL.IE		; turn on IE for testing
	SEX SP\ STR SP		; stick it on the stack too
	OUT SL1CTL\ DEC SP	; program the CDP1854 control register

;   Read the UART status register twice - the first time is just to clear any
; error or DA bits that might be left over - and then verify that the THRE and
; TSRE bits are set and the FE, PE, OE and DA bits are cleared.  
SL1TS0:	INP	SL1BUF		; clear the DA and OE bits
	INP	SL1STS		; then clear the THRE and TSRE bits
	NOP			; delay for just an instant
	INP	SL1STS		; and then read it again
	ANI	SL.THRE+SL.TSRE+SL.FE+SL.PE+SL.OE+SL.DA
	XRI	SL.THRE+SL.TSRE	; now these bits should be set
	LBNZ	NOSLU1		; quit now if failure

;   Even though the THRE bit is set AND the IE bit is set, the UART should not
; be interrupting because TR is not set.  Test that, and then set TR and test
; that IRQ is asserted.  Note that setting the TR bit in the control register
; is supposed to leave all other control bits unchanged.
	B_SL1IRQ  NOSLU1	; die if an interrupt is requested now
	SEX	PC0		; now set the TR bit
	OUT	SL1CTL		; ...
	 .BYTE	 SL.TR		; all other bits should be unaffected
	BN_SL1IRQ NOSLU1	; IRQ _should_ be set now

; Load two null bytes into the transmitter buffer and send them...
	OUT	SL1BUF		; send one null
	 .BYTE	 0		; ...
	NOP			; delay just a moment
	OUT	SL1BUF		; and then send another
	 .BYTE	 0		; ...

; Verify that THRE, TSRE and IRQ are now all cleared ...
	SEX	SP		; ...
	INP	SL1STS		; read the UART status again
	ANI	SL.TSRE+SL.THRE	; check both these bits
	LBNZ	NOSLU1		; fail if not set
	B_SL1IRQ  NOSLU1	; there should be no IRQ either

;   Now poll the status continuously.  The THRE bit should set first, followed
; later by the TSRE bit.  If these two bits don't get set, or they don't get set
; in that particular order, then we'll just spin here forever.
SL1TS2:	INP	SL1STS		; read the status
	ANI	SL.THRE+SL.TSRE	; we only care about these bits
	XRI	SL.THRE		; look for THRE to set first
	LBNZ	SL1TS2		; wait as long as necessary
SL1TS3:	INP	SL1STS		; now wait for TSRE to set too
	ANI	SL.THRE+SL.TSRE	; ...
	XRI	SL.THRE+SL.TSRE	; ...
	LBNZ	SL1TS3		; ...

;   Read the receiver buffer one more time to be sure DA and OE are cleared
; (since they will also cause an interrupt request) just in case the TU58
; managed to send us something.  Then test that the IRQ has gone away.
	NOP\ NOP\ NOP\ NOP	; give the TU58 a chance
	INP	SL1BUF		; clear the receiver buffer
	NOP			; ..
	B_SL1IRQ  NOSLU1	; and the IRQ should go away too

; All done testing the UART. Leave with the IE and TR bits cleared ...
SL1TS9:	SEX DP\ OUT SL1CTL	; update the control register
	GLO	P4		; set the SLU1 OK bit
	ORI	H0.SLU1		; ... in the hardware configuration
	PLO	P4		; ...
;;	DELAY(300)

; Fall into the next test ...
NOSLU1:	SEX	PC0		; restore the default I/O group select
	OUT	GROUP		; ...
	 .BYTE	 BASEGRP	; ...

	.SBTTL	"POST 6 - CDP1851 Parallel Port Tests"

; Fall into the next test ...
NOPPI:
	.SBTTL	"POST 5 - CDP1878 Timer/Counter Tests"

; Fall into the next test ...
NOCTC:
	.SBTTL	"POST 4 - CDP1855 Multiply/Divide Tests"

; Fall into the next test ...
NOMDU:
	.SBTTL	"POST 3 - AY-3-8192 Sound Generator Tests"

;++
;   POST 3 tests the AY-3-8912 programmable sound generator, aka the PSG.
; This device has no less than 16 registers, ALL of which are read/write,
; but all of them just program the output in various ways.  There are no
; status bits or anything like that which you can monitor for changes.
; Everything you read back from a register is just the same as what you
; wrote there a few moments ago!
;
;   That makes a self test kind of challenging, since we have no way to
; know really whether it is working or not.  The 8910 has two general
; purpose I/O ports, A and B, which can be programmed as outputs and
; have no effect on the sound generation.  The 8912 used in the SBC1802
; only has pins for port A, however internally both registers and ports
; are still implemented.  It just that on the 8912 only port A is
; bonded out.
;
;  The SBC1802 doesn't use these output pins at all, so we program
; both ports as outputs and then run thru setting all 256 possible
; values and reading them back to see if they work.  It's not much
; of a test for a sound generator, but it at least tells us that the
; data bus is wired up right.
;--
PSGTST:	POST(POST3)		; POST code 3 - PSG test
	OUT	GROUP		; select the PSG I/O group
	 .BYTE	PSGGRP		; ...
	OUT	PSGADDR		; select PSG control register R7
	 .BYTE	 PSGR7		; ...
	OUT	PSGDATA		; and program ports A and B as outputs
	 .BYTE	 $C0		; ...
	LDI 0\ PLO P1		; start testing with zero

;  Write all 256 possible values to ports A and B ...
PSGTS1:	SEX PC0\ OUT PSGADDR	; select PSG register R16
	 .BYTE	 PSGR16		; ... which is port A
	GLO T1\ STR SP\ SEX SP	; get the test pattern
	OUT PSGDATA\ DEC SP	; and load port A
	SEX PC0\ OUT PSGADDR	; now select PSG register R17
	 .BYTE	 PSGR17		; ... which is port B
	GLO T1\ XRI $FF\ STR SP	; complement the test pattern
	OUT PSGDATA\ DEC SP	; ... and load port B
	INP PSGDATA\ DEC SP	; read back port B
	SEX PC0\ OUT PSGADDR	; select port A again
	 .BYTE	 PSGR16		; ...
	SEX SP\ INP PSGDATA	; and read that
	INC SP\ ADD\ ADI 1	; they should be complements
	LBNZ	NOPSG		; no PSG if they're not
	INC P1\ GLO P1		; have we done 256 passes ?
	LBNZ	PSGTS1		; keep going until we have

; Here if the PSG is good!
PSGTS9:	SEX	PC0			; disable the PSG for now
	OUT PSGADDR\ .BYTE PSGR10	; mute channel A
	OUT PSGDATA\ .BYTE $00		; ...
	OUT PSGADDR\ .BYTE PSGR11	; mute channel B
	OUT PSGDATA\ .BYTE $00		; ...
	OUT PSGADDR\ .BYTE PSGR12	; mute channel C
	OUT PSGDATA\ .BYTE $00		; ...
	OUT PSGADDR\ .BYTE PSGR7	; turn off all mixer inputs
	OUT PSGDATA\ .BYTE $FF		; ports A and B are outputs
	GLO	P4		; set the PSG OK bit
	ORI	H0.PSG		; ... in the hardware configuration
	PLO	P4		; ...
	

; Fall into the next test ...
NOPSG:	SEX	PC0		; restore the default I/O group select
	OUT	GROUP		; ...
	 .BYTE	 BASEGRP	; ...

	.SBTTL	"POST 2 - Terminal Initialization"

;   If the RAM contents are valid and a baud rate has been saved, then we'll
; restore that setting now.  Note that the baud rate affects both the console
; SLU0 and the auxiliary SLU1 - the two ports don't necessarily have the same
; baud rate, but both are stored in the same byte.  The console terminal is
; always set to 8N1, however the character format for SLU1 is also stored in
; RAM.  If the terminal settings AREN'T saved in RAM, then we call the BIOS
; autobaud routine to figure out the console baud rate.  In this case SLU1
; defaults to 9600 baud and 8N1 as well.
;
;   And before we do any of that, we have to initialize the software SCRT
; (subroutine call and return technique) so we can call BIOS routines in the
; first place!
;
;   Post code 2 is displayed while we do this.  This is handy in the event
; autobaud is necessary, so that the user knows we're waiting for him to type
; <RETURN>!
SYSIN2:	POST(POST2)		; display POST code 2

; Call the BIOS routine to initialize the SCRT linkage ...
	RLDI(SP,STACK)		; initialize the stack pointer
	RLDI(A,SYSI20)		; continue processing from SYSIN3:
	LBR	F_INITCALL	; and intialize the SCRT routines

; See if terminal settings are saved in RAM, and use them if they are ...
SYSI20:	CALL(TTYINI)		; initialize all the SLU settings

; Print the system name, firmware and BIOS versions, and checksum...
	CALL(TCRLF)
	OUTSTR(SYSTEM)		; "SBC1802 FIRMWARE"
	INLMES(" V")		; ...
	RLDI(P3,VERSION)	; print the firmware version
	CALL(TVERSN)		; ...
	INLMES(" BIOS V")	; ...
	RLDI(P3,F_VERSION)	; followed by the BIOS version
	CALL(TVERSN)		; ...
	CALL(TSPACE)		; ...
	OUTSTR(SYSDAT)		; print the build date
	INLMES(" CHECKSUM ")	; and the EPROM checksum
	RLDI(P1,CHKSUM)		; stored here by the romcksum program
	SEX P1\ POPR(P2)	; ...
	CALL(THEX4)		; type that in HEX
	CALL(TCRLF)		; that's all for this line

; Print the copyright notice(s) ...
	OUTSTR(RIGHTS)		; then print the copyright notice
	CALL(TCRLF)\ CALL(TCRLF); ...

; If the CDP1879 RTC chip is installed, then print the date and time ...
	GHI	P4		; get the hardware flags again
	ANI	H1.RTC		; did we find the CDP1879?
	LBZ	SYSI24		; nope - skip this
	INLMES("RTC: ")
	CALL(SHOWNOW)		; type the current date/time
	CALL(TSPACE)
	CALL(SHOBAT)		; also show the backup battery state
	CALL(TCRLF)		; and finish the line
SYSI24:

	.SBTTL	"POST 1 - IDE Disk Drive Initialization"

;++
;   In POST 1 we probe for any attached disk drives (they're optional and there
; might not be any!).  If we find any we try to figure out their capacity and
; print some informational messages.
;
;   ElfOS presently supports only a single, master, drive however the BIOS and
; this code support a slave a well, with the restriction that if there is a 
; slave then there MUST be a master also.  You can't have a slave drive alone.
; In theory there's no reason the hardware couldn't support this, but the
; firmware won't deal with it.
;
;   We start by calling the BIOS F_IDERESET function which will set the software
; reset bit in the drive control register and then wait for the master drive to
; become ready.  The software reset actually resets BOTH drives, so even if a
; slave exists we only need to do this once.  If this call fails then there is
; no master drive and, by implication, no slave.
;
;   If the IDERESET succeeds then we call F_IDESIZE and F_IDEID to get the size
; and manufacturer/model of the drive.  These both get printed and we update
; the hardware flags to remember that the IDE master exists.  Then we try to
; do the same thing for the slave drive and, if that exists, we print a second
; line on the console and set the hardware flag for the slave.
;
;   We could in theory just call F_IDERESET or F_IDESIZE blindly, without
; knowing if the drive exists.  Both calls will time out and take the error
; return after approximately 5 seconds, but that's a painfully long time to
; sit around waiting for your system to boot up.  We can shortcut this delay
; by doing a few basic tests to see if any of the drive registers are
; accessible.  The LBA registers are a good choice - they're read/write and
; writing them doesn't cause the drive to do anything directly. 
;
;   One more comment - we don't try to probe for TU58 drives here, only IDE.
; That's because we don't know what's out there and there could be something
; (anything!) else connected to SLU1 and we don't want to screw it up.  You
; can always type "SHOW TAPE" if you want the status of TU58 drives.  The IDE
; hardware is dedicated to disk drives however, so it doesn't have that problem.
;--
SYSIN3:	OUTI(LEDS,POST1)	; POST 1 - IDE Initialization

; Probe the LBA registers to see if the master drive exists ...
	WRIDE(IDELBA3, ID.MST)	; be sure the master is selected
	WRIDE(IDELBA0, $55)	; write $55 to LBA0
	WRIDE(IDELBA1, $AA)	; and that complemented to LBA1
	RDIDE(IDELBA0)		; try to read back LBA0
	XRI	$55		; is it the right answer?
	LBNZ	NOIDE		; assume no drives exist if not

;  At a minimum, the master drive exists.  Call the BIOS IDERESET to reset both
; drive(s) and wait on the master to become ready ...
	CALL(F_IDERESET)	; reset both drive(s)
	LBDF	NOIDE		; if this fails then there are no drives

; Get the size and model name for the master drive ...
	RLDI(T2,ID.MST<<8)	; select the master unit
	CALL(F_IDESIZE)		; and get the size of the drive
	LBDF	NOIDE		; just bail if any errors occur
	RCOPY(P2,P1)		; put the drive size where we can print it
	INLMES("ID0: ")		; and tell the user that an IDE master exists
	CALL(TDECP2)		; type the drive size
	INLMES("MB ")		; ... in megabytes ...
	RLDI(P1,CMDBUF)		; need a temporary buffer for the drive name
	RLDI(T2,ID.MST<<8)	; select the master again
	CALL(F_IDEID)		; and get the drive model and manufacturer
	LBDF	NOMDL0		; this might not work, so don't give up
	OUTSTR(CMDBUF)		; print the model and manufacturer
NOMDL0:	CALL(TCRLF)		; ...
	GHI	P4		; update the hardware flags to say
	ORI	H1.IDE0		;  ... that the IDE master exists
	PHI	P4		; ...

;   Now that we know the master exists, for the slave drive it's safe to just
; call the F_IDESIZE and/or F_IDEID functions.  If no slave exists then they'll
; fail immediately without any timeout (or at least they should!)
	RLDI(T2,ID.SLV<<8)	; this time select the slave drive
	CALL(F_IDESIZE)		; try to get the drive size
	LBDF	NOIDE		; this fails if there is no slave
	RCOPY(P2,P1)		; ...
	INLMES("ID1: ")	; ...
	CALL(TDECP2)		; ...
	INLMES("MB ")		; ...
	RLDI(P1,CMDBUF)		; and get the drive model and manufacturer too
	RLDI(T2,ID.SLV<<8)	; ...
	CALL(F_IDEID)		; ...
	LBDF	NOMDL1		; the drive still exists even if this fails
	OUTSTR(CMDBUF)		; ...
NOMDL1:	CALL(TCRLF)		; ...
	GHI	P4		; update the hardware flags to say
	ORI	H1.IDE1		;  ... that the IDE slave exists
	PHI	P4		; ...

; Here if the IDE drives don't exist or don't work ...	
NOIDE:
	.SBTTL	"Software Initialization and Auto Boot"

; First save the hardware flags (the results of all the POST testing) ...
SYSIN4:	LDI LOW(HWFLAGS+1)	; point to HWFLAGS 
	PLO DP\ SEX DP		; ...
	PUSHR(P4)		; and save the POST results
	OUTI(LEDS,POST0)	; display POST 0 - startup complete

; Print the POST results ...
	INLMES("CFG: ")		; show the map of working devices
	CALL(SHOCF0)		; ...

;   If the OS type isn't set, presumably because RAM wasn't preserved, then
; default to ElfOS.  Initialize the user's saved context too, just in case.
	LDI LOW(OSTYPE)\ PLO DP	; point to the OSTYPE
	LDN	DP		; is the OS type already set?
	LBNZ	SYSI40		; skip this if it's already set
	LDI MC.ELOS\ STR DP	; default to ELFOS
	CALL(INIREGS)		; initialize the user context
SYSI40:

;   If the boot flag, BOOTF, is set to a non-zero value then we'll attempt an
; automatic boot from disk on power up.  If the bootstrap is unsuccessful
; (i.e. there's no drive or the media is not bootable) then we simply enter
; the command loop anyway.
	RLDI(DP,BOOTF)		; point DP to the boot flag
	LDA	DP		; and then load the boot flag
	LBZ	SYSI41		; if it's zero then skip all this
	ADI	AB.BOOT		; boot from mass storage device?
	LBDF	AUTOBT		; yes go do that

; Jump to a fixed 16 bit address at startup, with PC=R0 ...
	LDA DP\ PHI PC0		; get the restart address
	LDA DP\ PLO PC0		; ..
	SEP PC0			; and hope for the best!

; Here if there's not going to be any automatic boot ...
SYSI41:	OUTSTR(HLPMSG)		; always be helpful
	LBR	MAIN		; skip the restart code and read a command

; A helpful message ...
HLPMSG:	.TEXT	"\r\nFor help type HELP\r\n\r\n\000"

	.SBTTL	"Command Scanner"

;   The restart entry can be reached via the "warm start" vector at $8005.
; The only thing that really uses this is the BIOS, and the BIOS will jump here
; only if we encounter a breakpoint trap, OR if the user program calls the
; F_MINIMON function.  As far as we're concerned those are both the same.
SYSIN5:	CALL(TTYINI)		; reset the terminal baud rate
	CALL(SHOBPT)		; print the registers 
				; then fall into MAIN
;  Initialize (or rather, re-initialize) enough context so that things can still
; run even if some registers have been screwed up...
MAIN:	OUTI(LEDS,POST0)	; be sure the LEDs show 0
MAIN1:	RLDI(SP,STACK)\ SEX SP	; reset the stack pointer to the TOS
	RLDI(R1,F_TRAP)		; set up the breakpoint handler
	RLDI(DP,MCR)		; reset the memory map to ROM0
	LDI MC.ROM0\ STR DP	;  ... just in case somebody changed it
	RLDI(DP,DPBASE)		; lastly reset DP too

; Print the prompt and scan a command line...
	INLMES(">>>")		; print our prompt
	RLDI(P1,CMDBUF)		; address of the command line buffer
	RLDI(P3,CMDMAX)		; and the length of the same
	CALL(F_INPUTL)		; read a command line
	LBDF	MAIN		; branch if the line was terminated by ^C

;   Parse the command name, look it up, and execute it.  By convention while
; we're parsing the command line (which occupies a good bit of code, as you
; might imagine), P1 is always used as a command line pointer...
	RLDI(P1,CMDBUF)		; P1 always points to the command line
	CALL(ISEOL)		; is the line blank???
	LBDF	MAIN		; yes - just go read another
	RLDI(P2,CMDTBL)		; table of top level commands
	CALL(COMND)		; parse and execute the command
	LBR	MAIN		; and the do it all over again


;   This routine will echo a question mark, then all the characters from
; the start of the command buffer up to the location addressed by P1, and
; then another question mark and a CRLF.  After that it does a LBR to MAIN
; to restart the command scanner.  It's used to report syntax errors; for
; example, if the user types "BASEBALL" instead of "BASIC", he will see
; "?BASE?"...
CMDERR:	LDI	$00		; terminate the string in the command buffer
	INC	P1		; ...
	STR	P1		; at the location currently addressed by P1
;   Enter here (again with an LBR) to do the same thing, except at this
; point we'll echo the entire command line regardless of P1...
ERRALL:	CALL(TQUEST)		; print a question mark
	OUTSTR(CMDBUF)		; and whatever's in the command buffer
	CALL(TQUEST)		; and another question mark
	CALL(TCRLF)		; end the line
	LBR	MAIN		; and go read a new command

	.SBTTL	"Lookup and Dispatch Command Verbs"

;   This routine is called with P1 pointing to the first letter of a command
; (usually the first thing in the command buffer) and P2 pointing to a table
; of commands.  It searches the command table for a command that matches the
; command line and, if it finds one, dispatches to the correct action routine.
;
;   Commands can be any number of characters (not necessarily even letters)
; and may be abbreviated to a minimum length specified in the command table.
; For example, "BA", "BAS", "BASI" and "BASIC" are all valid for the "BASIC"
; command, however "BASEBALL" is not.
;
;   See the code at CMDTBL: for an example of how this table is formatted.
COMND:	PUSHR(P3)\ PUSHR(P4)	; save registers P3 and P4
	CALL(F_LTRIM)		; ignore any leading spaves
	RCOPY(P3,P1)		; save the pointer so we can back up
COMND1:	RCOPY(P1,P3)		; reset the to the start of the command
	LDA	P2		; get the minimum match for the next command
	LBZ	ERRALL		; end of command table if it's zero
	PLO	P4		; save the minimum match count

;   Compare characters on the command line with those in the command table
; and, as long as they match, advance both pointers....
COMND2:	LDN	P2		; take a peek at the next command table byte
	LBZ	COMN3A		; branch if it's the end of this command
	LDN	P1		; get the next command character
	CALL(FOLD)		; make it upper case
	SEX	P2		; now address the command table
	SM			; does the command line match the table?
	LBNZ	COMND3		; nope - skip over this command
	INC P2\ INC P1\ DEC P4	; increment table pointers and decrement count
	LBR	COMND2		; keep comparing characters

;   Here when we find something that doesn't match.  If enough characters
; DID match, then this is the command; otherwise move on to the next table
; entry...
COMND3:	SEX P2\ LDXA		; be sure P2 is at the end of this command
	LBNZ	COMND3		; keep going until we're there
	SKP			; skip over the INC
COMN3A:	INC	P2		; skip to the dispatch address
	GLO	P4		; how many characters matched?
	LBZ	COMND4		; branch if an exact match
	SHL			; test the sign bit of P4.0
	LBDF	COMND4		; more than an exact match

; This command doesn't match.  Skip it and move on to the next...
	INC P2\ INC P2		; skip two bytes for the dispatch address
	LBR	COMND1		; and then start over again

; This command matches!
COMND4:	SEX SP\ IRX		; restore P3 and P4
	POPR(P4)\ POPRL(P3)	; ...
	RLDI(T1,COMND5)		; switch the PC temporarily
	SEP	T1		; ...
COMND5:	SEX	P2		; ...
	POPR(PC)		; load the dispatch address into the PC
	LDI	0		; always return with D cleared!
	SEX SP\ SEP PC		; branch to the action routine

	.SBTTL	"Primary Command Table"

;   This table contains a list of all the firmware command names and the
; addresses of the routines that execute them.  Each table entry is formatted
; like this -
;
;	.BYTE	2, "BASIC", 0
;	.WORD	BASIC
;
; The first byte, 2 in this case, is the minimum number of characters that must
; match the command name ("BA" for "BASIC" in this case).  The next bytes are
; the full name of the command, terminated by a zero byte, and the last two
; bytes are the address of the routine that processes this command.

; This macro makes it easy to create a command table entry ...
#define CMD(len,name,routine)	.DB len, name, 0\ .DW routine

; And here's the actual table of commands ...
CMDTBL:
	CMD(2, "DUMP",       DDUMP)	; dump disk blocks
	CMD(1, "BOOT",       BOOCMD)	; boot from the primary IDE disk
	CMD(1, "EXAMINE",    EXAM)	; examine/dump memory bytes
	CMD(1, "DEPOSIT",    DEPOSIT)	; deposit data in memory
	CMD(3, "INPUT",      INPUT)	; test input port
	CMD(3, "OUTPUT",     OUTPUT)	;  "   output  "
	CMD(2, "CALL",       CALUSR)	; "call" a user's program
	CMD(2, "RUN",        RUNUSR)	; "run"  "   "     "   "
	CMD(4, "CONTINUE",   CONT)	; continue after a breakpoint
	CMD(2, "HELP",	     PHELP)	; print help text
	CMD(2, "SET",        SET)	; set options 
	CMD(2, "SHOW",       SHOW)	; show parameters and flags
	CMD(2, "TEST",	     TEST)	; test various hardware bits
	CMD(6, "FORMAT",     FORMAT)	; "format" a storage device
	CMD(1, ":",          IHEX)	; load Intel .HEX format files
	CMD(1, ";",	     MAIN)	; a comment

; The table always ends with a zero byte...
	.BYTE	0

	.SBTTL	"Examine Memory Command"

;  The E[XAMINE] command allows you to examine one or more bytes of memory in
; both hexadecimal and ASCII. This command accepts two formats of operands -
;
;	>>>E xxxx yyyy
;	- or -
;	>>>E xxxx
;
;   The first one will print the contents of all locations from xxxx to yyyy,
; printing 16 bytes per line.  The second format will print the contents of
; location xxxx only.  All addresses are in hex, of course.
;
;   A word about memory maps - this command assumes that you want to examine
; RAM, not EPROM (which you presumably already know the contents of anyway!).
; It calls the ERAM routine to actually fetch a byte from RAM, and this will
; dynamically switch between the ROM0 and ROM1 maps as neccessary to access
; RAM from locations $0000 thru $EFFF.  Addresses $F000 and above will still
; examine the BIOS area, and addresses in the data page can access our own data
; area, the MCR, PIC and RTC.  Nothing is currently done to stop this, but
; caution is advised...

EXAM:	CALL(HEXNW)		; scan the first parameter and put it in P2
	RCOPY(P3,P2)		; save that in a safe place
	CALL(ISEOL)		; is there more?
	LBDF	EXAM1		; no - examine with one operand
	CALL(HEXNW)		; otherwise scan a second parameter
	RCOPY(P4,P2)		; and save it in P4 for a while
	CALL(CHKEOL)		; now there had better be no more
	CALL(P3LEP4)		; are the parameters in the right order??
	LBNF	CMDERR		; error if not
	CALL(MEMDMP)		; go print in the memory dump format
	RETURN			; and then on to the next command

; Here for the one address form of the command...
EXAM1:	RCOPY(P2,P3)		; copy the address
	CALL(THEX4)		; and type it out
	INLMES("> ")		; ...
	CALL(ERAM)		; fetch the contents of that byte
	CALL(THEX2)		; and type that too
	CALL(TCRLF)		; type a CRLF and we're done
	RETURN			; ...

	.SBTTL	"Generic Memory Dump"

;++
;   This routine will dump, in both hexadecimal and ASCII, the block of memory
; between P3 and P4.  It's used by the EXAMINE command, but it can also be
; called from other random places, such as the dump disk sector command, and
; can be especially handy for chasing down bugs...
;
;CALL:
;	P3/ starting RAM address
;	P4/ ending RAM address
;	CALL(MEMDUMP)
;--
MEMDMP:	GLO P3\ ANI $F0\ PLO P3	; round P3 off to $xxx0
	GLO P4\ ORI $0F\ PLO P4	; and round P4 off to $xxxF
	CALL(F_INMSG)		; print column headers
	.TEXT	"        0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F\r\n\000"

; Print the address of this line (the first of a row of 16 bytes)...
MEMDM2:	RCOPY(P2,P3)		; copy the address of this byte
	CALL(THEX4)		; and then type it in hex
	INLMES("> ")		; type a > character after the address
	SKP			; skip the INC P3 the first time around

; Now print a row of 16 bytes in hexadecimal...
MEMDM3:	INC	P3		; on to the next byte...
	CALL(TSPACE)		; leave some room between bytes
	CALL(ERAM)		; get the next byte from memory
	CALL(THEX2)		; and type the data in two hex digits

; Here to advance to the next data byte...
MEMDM4:	GLO P3\ ANI $0F\ XRI $0F; have we done sixteen bytes??
	LBNZ	MEMDM3		; no - on to the next address

; Print all sixteen bytes again, put this time in ASCII...
MEMDM5:	CALL(TSPACE)		; leave a few blanks
	CALL(TSPACE)		; ...
	GLO P3\ ANI $F0\ PLO P3	; restore the address back to the beginning
	SKP			; skip the INC P3 the first time around

; If the next byte is a printing ASCII character, $20..$7E, then print it.
MEMDM6:	INC P3\ CALL(ERAM)	; on to the next byte
	PLO	BAUD		; save the original byte
	ANI	$60		; is it a control character??
	LBZ	MEMDM7		; yep - print a dot
	GLO	BAUD		; no - get the byte again
	ANI $7F\ XRI $7F	; is it a delete (rubout) ??
	LBZ	MEMDM7		; yep - print a dot
	XRI $7F\ CALL(F_TTY)	; no - restore the original byte and type
	LBR	MEMDM8		; on to the next byte

; Here if the character isn't printing - print a "." instead...
MEMDM7:	OUTCHR('.')		; do just that
MEMDM8:	GLO P3\ ANI $0F\ XRI $0F; have we done sixteen bytes?
	LBNZ	MEMDM6		; nope - keep printing

; We're done with this line of sixteen bytes....
	CALL(TCRLF)		; finish the line
	CALL(F_BRKTEST)		; does the user want to stop early?
	LBDF	MEMDM9		; branch if yes
	INC	P3		; on to the next byte
	GHI P3\ STR SP		; did we roll over from $FFFF to $0000?
	GLO P3\ OR		; check both bytes for zero
	LBZ	MEMDM9		; return now if we rolled over
	CALL(P3LEP4)		; have we done all of them?
	LBDF	MEMDM2		; nope, keep going
MEMDM9:	RETURN			; yep - all done

	.SBTTL	"Deposit Memory Command"

;   The D[EPOSIT] stores bytes in memory, and it accepts an address and a list
; of data bytes as operands:
;
;	>>>D xxxx dd dd dd dd dd dd dd dd ....
;
; This command would deposit the bytes dd ... into memory addresses beginning
; at xxxx.  Any number of data bytes may be specified; they are deposited into
; sequential addresses...
;
;   Like EXAMINE, this command uses the DRAM routine to handle the special case
; of depositing data into RAM #1, however in the case writing to memory in the
; BIOS area (i.e. addresses $F000 and up) is disallowed.  A "MEMORY ERROR" will
; occur if you try.

DEPOSIT:CALL(HEXNW) 		; scan the address first
	RCOPY(P3,P2)		; then save the address where it is safe
	CALL(ISSPAC)		; we'd better have found a space
	LBNF	CMDERR		; error if not

; This loop will read and store bytes...
DEP1:	CALL(HEXNW)		; read another parameter
	CALL(ISSPAC)		; and we'd better have found a space or EOL
	LBNF	CMDERR		; error if not
	GLO P2\ CALL(DRAM)	; store it in memory at (P3)
	LBDF	MEMERR		; ?MEMORY ERROR if not allowed
	INC	P3		; on to the next address
	CALL(ISEOL)		; end of line?
	LBNF	DEP1		; nope - keep scanning
	RETURN			; yes - all done now

; Here if the user tries to write to "protected" memory ...
MEMERR:	OUTSTR(MERMSG)
	LBR	MAIN
MERMSG:	.BYTE	"?MEMORY ERROR\r\n", 0


;   This routine will zero P2 bytes of RAM starting from location P1.  It uses
; the sam DRAM function as DEPOSIT so it's able to zero any part of user RAM,
; even the part that's shadowed by this EPROM.  Uses P3 ...
CLRMEM:	RCOPY(P3,P1)		; put the address in P3 for DRAM
CLRME1:	LDI 0\ CALL(DRAM)	; write one byte with zeros
	LBDF	MEMERR		; just in case of funny stuff
	INC P3			; increment the address
	DBNZ(P2,CLRME1)		; and loop until they're all done
	RETURN			; ...

	.SBTTL	"Access All of User RAM"

;   These two routines, ERAM and DRAM, handle the magic necessary to make all of
; RAM accessible to the user.  This might sound trivial, but remember that this
; EPROM is actually mapped to all addresses from $8000 and up.  Accessing the
; first half of RAM from $0000 to $7FFF is easy, but accessing the second half
; requires switching to the ROM1 map, flipping the upper address bit, and then
; accessing the corresponding location in low memory.  
;
;   And remember that addresses from $F000 and up are always mapped to the BIOS
; in any memory map.  This space, which would correspond to the upper 4K of RAM
; #1, can be accessed in the ROM1 map, but this is the only way it's ever
; visble.  No ElfOS nor MicroDOS program could ever access this RAM.  Rather
; than show this shadow area to the user, we map addresses $F000 and up to real
; memory.  This makes the BIOS portion of EPROM, our data page, and the memory
; mapped MCR, PIC and RTC registers, visble with ERAM.
;
;   The DRAM function, however, will refuse to change anything above $F000.
;
;   Note that no matter what else happens, both routines always switch back to
; the ROM0 map before returning!
;
;   Lastly, note that both routines trash T? which (in the interest of speed)
; they don't bother to save.  However NEITHER routine destroys the original
; address in P3.

; ERAM returns the contents of location P3 in D ...
ERAM:	GHI	P3		; get the upper address byte
	ANI	$F0		; is this address in the BIOS area?
	XRI	$F0		; ???
	LBZ	ERAM0		; yes - treat it like a real address
	ANI	$80		; is it in RAM0 or RAM1?
	LBZ	ERAM1		; RAM1 (remember that we flipped the MSB!)

; Here for an address in RAM0, or one from $F000 and up ...
ERAM0:	LDN P3\ RETURN		; just read the byte

; Here for an address in RAM1 - gotta do things the hard way ...
ERAM1:	RLDI(T1,MCR)		; access the memory control register
	LDI MC.ROM1\ STR T1	; and select the ROM1 map
	GHI P3\ XRI $80\ PHI P3	; flip the MSB of the address
	LDN	P3		; now we can actually read the byte
	PLO	BAUD		; save it in an extremely temporary location
	GHI P3\	XRI $80\ PHI P3	; restore the original address
	LDI MC.ROM0\ STR T1	; go back to the ROM0 map
	GLO	BAUD		; get the byte we worked so hard to get
	RETURN			; and we're finally done


;   DRAM writes the value in D to the location in P3.  It's essentially the
; reverse of ERAM, however in this case writes to locations $F000 and above are
; disallowed.  If P3 points to a disallowed address, DF=1 on return and nothing
; else is changed.
DRAM:	PLO	BAUD		; save the new byte in a (very) temporary loc
	GHI	P3		; get the upper address byte
	ANI	$F0		; is this address in the BIOS area?
	XRI	$F0		; ???
	LBZ	DRAM9		; yes - that always fails
	ANI	$80		; is it in RAM0 or RAM1?
	LBZ	DRAM1		; RAM1 (remember that we flipped the MSB!)

; Here for an address in RAM0 ...
DRAM0:	GLO BAUD\ STR P3	; just write the byte
	CDF\ RETURN		; signal success and we're done

; Here for an address from $F000 and up ...
DRAM9:	GLO	BAUD		; return D unchanged
	SDF\ RETURN		; and signal failure

; Here for an address in RAM1 - gotta do things the hard way ...
DRAM1:	RLDI(T1,MCR)		; access the memory control register
	LDI MC.ROM1\ STR T1	; and select the ROM1 map
	GHI P3\ XRI $80\ PHI P3	; flip the MSB of the address
	GLO BAUD\ STR P3	; save te original data byte now
	GHI P3\ XRI $80\ PHI P3	; restore the original address
	LDI MC.ROM0\ STR T1	; go back to the ROM0 map
	GLO	BAUD		; restore the original contents of D
	CDF\ RETURN		; signal success and we're done

	.SBTTL	"INPUT Command"

;   The IN[PUT] command reads the specified I/O port and prints the byte
; received in hexadecimal.  It actually has two forms -
;
;	>>>IN p
;	- or -
;	>>>IN p gg
;
;   The first form reads port p (1 <= p <= 7) in the base board I/O group, and
; the second form allows you to specify any other I/O group first.
INPUT:	CALL(HEXNW)		; read the port number

; Build an INP instruction out of the port number and store it at IOTBUF ...
	RLDI(P4,IOTBUF)		; point T1 at the IOT buffer
	GLO P2\ ANI 7		; trim the port address to just 3 bits
	LBZ	CMDERR		; error if port 0 selected
	ORI	$68		; turn it into an input instruction
	STR P4\ INC P4		; and store it in IOT
	LDI	$D0+PC		; load a "SEP PC" instruction
	STR P4\ DEC P4		; and store that in IOT+1

; See if an I/O group was specified, and handle that ...
	RLDI(P2,BASEGRP)	; default to the base board I/O group
	CALL(ISEOL)		; is there a second argument?
	LBDF	INPUT1		; no - use the base board group
	CALL(HEXNW)		; yes - go scan that too
	CALL(CHKEOL)		; and that had better be all

;   Execute the IOT and type the result.  The code above has stored two
; instructions, "INP p" and "SEP PC" in the data page at IOTBUF, and P4 points
; to the first of those two bytes.  After we select the I/O group we do a
; "SEP P4" to execute the INP and then return.
INPUT1:	GLO	P2		; get the desired I/O group
	STR SP\ SEX SP		; put it on the TOS
	OUT	GROUP		; select the I/O group
	DEC SP\ DEC SP		; leave the group number on the stack
	SEP	P4		; now execute the INP instruction
	DEC	SP		; and leave that result on the stack too

; Now type out the result ...
	INLMES("PORT ")		; ...
	DEC P4\ DEC P4\ LDN P4	; get the INP instruction again
	ANI 7\ ORI '0'\		; convert the port number to ASCII
	CALL(F_TTY)		; and type that
	INLMES(" GROUP ")	; next print the group number
	POPD\ PLO P4		; pop the INP result first and save it
	POPD\ CALL(THEX2)	; type the group number
	INLMES(" = ")		; ...
	GLO P4\ CALL(THEX2)	; finally, type the data we received
	LBR	TCRLF		; finish the line and we're done here!

	.SBTTL	"OUTPUT Command"

;   The OUT[PUT] command writes a byte to the specified I/O port.  Like INPUT,
; it has two forms depending on whether you want to specify an I/O group
;
;	>>>OUT p dd
;	- or -
;	>>>OUT p dd gg
;
;   The first form sends the byte dd to port p of the base board, and the second
; form sends dd to port p of group gg.  Note that if you want to specify an I/O
; group then it comes AFTER the data, not before.  That's a bit non-intuitive
; but optional arguments must be at the end of the line ...
OUTPUT:	CALL(HEXNW2)		; read at least two arguments - port and data

; Build an OUT instruction and store it at IOTBUF ...
	RLDI(P4,IOTBUF)		; point P4 at the IOT buffer
	GLO P3\ ANI 7		; get the port address and trim to 3 bits
	LBZ	CMDERR		; disallow port zero!
	ORI $60\ STR P4\ INC P4	; make an OUT and store it in IOTBUF
	GLO P2\ STR P4\ INC P4	; store the data byte at IOTBUF+1
	LDI	$D0+PC		; create a "SEP PC" instruction
	STR P4\ DEC P4\ DEC P4	; and store that in IOT+2

; Handle the I/O group, if specified ...
	RLDI(P2,BASEGRP)	; default to the base board I/O group
	CALL(ISEOL)		; is there a second argument?
	LBDF	OUTPU1		; no - use the base board group
	CALL(HEXNW)		; yes - go scan that too
	CALL(CHKEOL)		; and that had better be all

; This is pretty much like INPUT - select the group and then call IOTBUF ...
OUTPU1:	GLO	P2		; get the desired I/O group
	STR SP\ SEX SP		; put it on the TOS
	OUT GROUP\ DEC SP	; select the I/O group
	SEX	P4		; set X=P for IOT
	SEP	P4		; and execute the user's OUT instruction

;   A RETURN here will change the POST display back to 0.  That's OK, but it's
; nice to be able to use this command to exercise the display, so we explicitly
; branch back to MAIN1 instead.  That'll leave the POST display unchanged until
; after the next command executes.
	LBR	MAIN1		; and we're done

	.SBTTL	"RUN, CALL and CONTINUE Commands"

;   All three of these commands, RUN, CALL and CONTINUE, will start (or resume)
; execution of some user program, including either of the ElfOS or MicroDOS
; operating systems.
;
;	>>>RUN [ssss]
;
;   RUN clears all the user registers, sets R2 to the top of RAM and R0 to the
; starting address ssss (or zero if none is specified), disables interrupts and
; starts running with P=R0.
;
;	>>>CALL [ssss]
;   
;   CALL clears all the user registers, sets R4 and R5 to point to the standard
; BIOS SCRT CALL and RETURN routines, loads A with the restart address for this
; firmware, loads R3 with the starting address ssss (or zero if none is given),
; disables interrupts and starts running with P=R3.  In this case the user's
; program can return to this firmware simply by doing a RETURN at the top level.
;
;	>>>CONTINUE
;
;   CONTINUE resumes execution of the user program using all the saved context
; and NOTHING is initialized.  Hopefully the saved context is valid - otherwise
; you'll be unhappy with the results.  In particular, R2 must point to a valid
; stack somewhere in memory in order for this to succeed.

; Here for the RUN command ...
RUNUSR:	RCLR(P2)		; assume to start from $0000
	CALL(ISEOL)		; but is there any argument?
	LBDF	RUN1		; nope
	CALL(HEXNW)		; yes - go read the starting address
	CALL(CHKEOL)		; and then that had better be the end
RUN1:	RCOPY(R0,P2)		; put the start address in R0
	RLDI(DP,OSTYPE)\ LDN DP	; get the OS type/memory map to use
	LBR	F_RUN		; then go start the program


; Here for the CONTINUE command ...
CONT:	CALL(CHKEOL)		; no arguments are allowed
CONT1:	RLDI(DP,OSTYPE)\ LDN DP	; get the OS type/memory map to use
	LBR	F_CONTINUE	; continue execution with the saved context


; Here for the CALL command ...
CALUSR:	CALL(INIREGS)		; initialize all user registers
	CALL(ISEOL)		; is there a start address on the command line?
	LBDF	CONT1		; no - start from address $0000
	CALL(HEXNW)		; yes - go read the starting address
	CALL(CHKEOL)		; and then that had better be the end
	RLDI(DP,REGS+7)		; set user register R3
	SEX DP\ PUSHR(P2)	; to the start address
	LBR	CONT1		; load the OS type and go


;   This routine will initialize all of the saved user registers and context.
; R2, which will become the stack pointer, is initialized to the top of RAM.
; R4 and R5 are initialized to point to the BIOS SCRT CALL and RETURN routines,
; respectively. R6 is initialized with the BIOS call F_MINIMON - this means if
; the user program executes a RETURN from the topmost stack level it will end
; up back here.  And finally, it initializes X=2 and P=3.  All other registers,
; including D and DF, are set to zero. Note however that R3 IS NOT INITIALIZED!
; That's the starting address for whatever program we plan to run, and that's
; up to the caller.
INIREGS:RLDI(DP,REGS+32-1)	; point to the end of the saved register area
	RLDI(P2,32+3) \ SEX DP	; zero 16 registers, DF, D and XP
INIRE1:	LDI 0\ STXD		; zap another byte
	DBNZ(P2,INIRE1)		; and do them all
	RLDI(DP,REGS+13)	; start loading user registers with R6
	RLDI(P2,F_MINIMON)	; jump here if the user RETURNS
	PUSHR(P2)		; ... set R6 (A)
	RLDI(P2,F_RETURN)	; address of the SCRT RETURN routine
	PUSHR(P2)		; ... set R5 (RETPC)
	RLDI(P2,F_CALL)		; address of the SCRT CALL routine
	PUSHR(P2)		; ... set R4 (CALLPC)
	DEC DP\ DEC DP		; skip over R3
;   Why USRRAM-2 instead of USRRAM?  It's because of the kludge (er, "feature")
; which allows a user program to do a RETURN to get back to MINIMON.  If the
; stack is empty and you do a RETURN, then that will load A (which contains the
; address of F_MINIMON) into the PC.  Fine, but it also tries to pop the last
; A off the stack which, if SP starts out at $EFFF, will leave it pointing into
; the BIOS area above $F000.  When F_MINIMON tries to save D and (X,P) on the
; stack it will fail, since SP no longer points to RAM.  The solution is to
; leave two spare bytes on the TOS, and all is well.
	RLDI(P2,USRRAM-2)	; address of the top of RAM
	PUSHR(P2)		; ... set R2 (SP)
	RLDI(DP,SAVEXP)		; and lastly ...
	LDI $23\ STR DP		; ... set P=3 and X=2
	RETURN			; and quit

	.SBTTL	"BOOT Command"

;   The BOOT command attempts to bootstrap ElfOS from the specified storage
; device.  The specified device can be any one of ID0, ID1, TU0, or TU1.
;
;	>>>BOOT [xxx]
;
; If not specified the device defaults to ID0 (i.e. the IDE MASTER)...
BOOCMD:	CALL(ISEOL)		; was a device name given ?
	LBDF DEFBOO		; default to unit 0 if not
	CALL(GETDEV)		; get the storage device unit number
	PUSHD			; and save that for a moment
	CALL(CHKEOL)		; make sure there are no more arguments
	LBR	BOOCM2		; and then go boot

;   Enter here at DEFBOO to boot from the default device (unit 0).  Enter at
; AUTOBT to boot from the storage device in D.  The SYSINI routine calls the
; later if the auto restart flag is set to BOOT.
DEFBOO:	LDI 0			; select unit 0
AUTOBT:	PUSHD			; save that on the stack
				; and then continue with the boot process

; Boot the unit on the stack...
BOOCM2:	OUTSTR(BOOMSG)		; tell the user what we're doing
	POPD\ PUSHD		; get the unit number back
	CALL(PRTDEV)		; and type the device name
	INLMES(" ...")		; ...
	CALL(TCRLF)		; ...
	POPD			; restore the unit number
	CALL(F_SDBOOT)		; and ask the BIOS to bootstrap
	LBDF	DRVERR		; hardware OK but no ElfOS boot

; Here if the attached volume is not bootable ...
NOBOOT:	OUTSTR(BFAMSG)		; ?NOT BOOTABLE
	RETURN			; ...

; IDE bootstrap messages ...
BOOMSG:	.TEXT	"Booting \000"
BFAMSG:	.TEXT	"?NOT BOOTABLE\r\n\000"

	.SBTTL	"DUMP Storage Device Command"

;   The DUMP command can dump disk sectors from either IDE0 (master) or IDE1
; (slave) drive.  Sectors are read into memory and then dumped with the regular
; EXAMINE command, which dumps the data in both hexadecimal and ASCII.
;
;	>>>DUMP IDn nnnnn
;	- or -
;	>>>DUMP TUn nnnnn
;
; Where nnnnn is the desired LBA number.  Note that sector numbers are read in
; DECIMAL and are limited to 16 bits (we don't have a 32 bit decimal input
; function - sorry).  This limits us to dumping only the first 32Mb or so of
; disk space.  That's probably good enough ...
;
DDUMP:	CALL(GETDEV)\ PUSHD	; get the drive number and save that
	CALL(DECNQ)		; and get the block number
	CALL(CHKEOL)		; that should be the end of the command
	POPD\ PUSHD		; get the unit number back
	CALL(F_SDRESET)		; and initialize that drive
	LBDF	DRVERR		; quit if there was any drive error
	RCLR(P1)		; read into memory starting at zero
	POPD			; get the unit number back
	CALL(F_SDREAD)		; read one sector
	LBDF	DRVERR		; branch if disk error
	RCLR(P3)		; dump memory from $0000
	RLDI(P4,DSKBSZ-1)	;  ... to $1FF
	LBR	MEMDMP		; print that out and we're done

	.SBTTL	"Format Storage Device"

;++
;   The FORMAT command will erase all data on a storage device.  It doesn't
; really "format" it in the sense that you format a floppy diskette, but it
; does fill every sector on the device with random data.
;
;	>>>FORMAT IDn
;	- or -
;	>>>FORMAT TUn
;--

FORMAT:	CALL(GETDEV)\ PUSHD	; get the drive number and save that
	CALL(CHKEOL)		; should be no more arguments
	OUTSTR(FWNMSG)		; warn that this will erase all data
	POPD\ PUSHD		;  ... and give the device name
	CALL(PRTDEV)		;  ...
	INLMES("!\r\n")		;  ...
	CALL(CONFIRM)		; ask "Are you really, really sure??"
	LBNF	FORM99		; abort if he says no

; He's sure - start formatting!
	POPD\ PUSHD		; get the unit number back
	CALL(F_SDRESET)		; and initialize that drive
	LBDF	DRVERR		; branch if disk error
	QCLR(T2,T1)		; zero all 32 bits of the LBA

; Print the current block/sector we're writing ...
FORM10:	OUTSTR(WRTMSG)		; "Writing ..."
	RCOPY(P1,T1)		; and then print the sector number
	CALL(TDECP1)		; ...

; Fill the disk buffer with the low word of the LBA ...
FORM20:	RLDI(P1,DSKBUF+DSKBSZ)	; fill the disk buffer backwards
	RLDI(P2,DSKBSZ)		; count bytes here
FORM21:	SEX P1\ PUSHR(T1)	; store the LBA in the buffer
	DEC P2\ DBNZ(P2,FORM21)	; and do all 512 bytes

; Write this buffer to the disk ...
	RLDI(P1,DSKBUF)		; point to the disk buffer
	SEX SP\ POPD\ PUSHD	; get the unit number back
	CALL(F_SDWRITE)		; write to disk
	 LBDF	DRVERR		; write error
	INC T1			; increment the low LBA
	GLO T1\ LBNZ FORM20	; if not zero, then keep writing
	GHI T1\ LBNZ FORM10	; print the LBA every 256 sectors

; Right now, we just quite after 655536 sectors!!
	CALL(TCRLF)
FORM99:	RETURN

FWNMSG:	.TEXT	"THIS WILL ERASE ALL DATA ON \000"
WRTMSG:	.TEXT	"\rWRITING ... \000"

	.SBTTL	"Scan or Print Storage Device Names"

;   This routine will parse a storage device name - ID0, ID1, TU0 or TU1.
; If it succeeds it returns the storage device number in D, as would be used
; by a call to F_SDREAD/SDWRITE/SDRESET or F_SDBOOT.  If it fails to match
; the device name then it just jumps to ERRALL and aborts the command.
GETDEV:	RLDI(P2,SDTBL)		; point to the table of names
	LBR	COMND		; parse the name and return

; Table of drive names ...
SDTBL:	CMD(3, "ID0", SDID0)	; select the master drive
	CMD(3, "ID1", SDID1)	; select the slave drive
	CMD(3, "TU0", SDTU0)	; select TU58 unit 0
	CMD(3, "TU1", SDTU1)	; select TU58 unit 1
	.BYTE 0


; Here to select the master IDE drive 
SDID0:	CALL(HWTEST)		; make sure it's really installed
	 .WORD	 HWIDE0		; ...
	LDI 0\ RETURN		; return with D=0

; Here to select the slave IDE drve ...
SDID1:	CALL(HWTEST)		; make sure IDE1 exists
	 .WORD	 HWIDE1		; ...
	LDI 1\ RETURN		; return with storage unit 1

;   The TU58 drives require that SLU1 be installed, but beyond that we
; don't have any hardware configuration bit to indicate they exist.
; We'll just try to use them and if they don't exist then it'll fail.
SDTU0:	LDI 2\ LSKP		; select TU58 unit 0
SDTU1:	LDI 3			; select TU58 unit 1
	PUSHD			; save the selected unit
	CALL(HWTEST)		; make sure that SLU1 is installed
	 .WORD	HWSLU1		;  ...
	POPD\ RETURN		; and return the unit if it does


;   This routine will print the storage device name, given the unit number
; in D.  In some sense, it's the reverse of GETDEV ...
PRTDEV:	SHL\ SHL		; each name takes 4 bytes
	ADI	LOW(DEVNMS)	; index into the device name table
	PLO	P1		; ...
	LDI 0\ ADCI HIGH(DEVNMS); add the high part too
	PHI	P1		; ...
	LBR	F_MSG		; print the name and return ...

; Table of device names; exactly FOUR CHARACTERS EACH!
DEVNMS	.TEXT	"ID0\000ID1\000TU0\000TU1\000"

	.SBTTL	"HELP Command"

;   The HELP command prints a canned help file, which is stored in EPROM in
; plain ASCII. 
PHELP:	CALL(CHKEOL)		; HELP has no arguments
	RLDI(P1,HELP)		; nope - just print the whole text
	LBR	F_MSG		; ... print it and return

	.SBTTL	"SHOW, SET and TEST Commands"

;   These three little routines parse the SHOW, SET and TEST commands, each of
; which takes a secondary argument - e.g. "SHOW RTC", "SET BOOT", or "TEST RAM".
; All we have to do here is to parse the second word and dispatch ...

; Here for the SHOW command ...
SHOW:	RLDI(P2,SHOCMD)		; point to the table of SHOW commands
	LBR	COMND		; parse it (and call CMDERR if we can't!)

SHOCMD:	CMD(3, "REGISTERS"    , SHOREG)	; show registers (after a breakpoint)
	CMD(2, "DP"           , DPDUMP)	; show monitor data page
	CMD(3, "RTC"          , SHOWRTC); show the real time clock
	CMD(2, "EF"           , SHOWEF)	; print status of EF inputs
	CMD(3, "SLU"          , SHOSLU)	; print SLU0 settings
	CMD(4, "CONFIGURATION", SHOCFG)	; print hardware configuration
	CMD(3, "BATTERY"      , BATCMD)	; show backup battery state
	CMD(2, "OSTYPE"       , SHOOST)	; show current operating system
	CMD(3, "CPU"          , SHOCPU)	; print CPU type and speed
	CMD(3, "DISK"         , SHODSK) ; identify IDE drives
	CMD(3, "TAPE"	      , SHOTAP)	; identify TU58 drives
	CMD(3, "RESTART"      , SHORST)	; show restart option
	.BYTE	0


; SET command...
SET:	RLDI(P2,SETCMD)		; point to the table of SET commands
	LBR	COMND		; parse the argument and return

SETCMD:	CMD(1, "Q",	    SETQ)	; set Q (for testing)
	CMD(2, "RTC",       SETRTC)	; set the real time clock
	CMD(4, "SLU0",	    SETSL0)	; set SLU0 parameters
	CMD(4, "SLU1",      SETSL1)	; set SLU1 parameters
	CMD(4, "YEAR",      SETYR)	; set the current year
	CMD(2, "OSTYPE",    SETOST)	; set the operating system type
	CMD(3, "RESTART",   SETRST)	; set the boot options
	CMD(5, "NORESTART", SETRNO)	; clear the auto boot option
	.BYTE	0


; TEST command...
TEST:	RLDI(P2,TSTCMD)		; point to the table of TEST commands
	LBR	COMND		; parse the argument and return

TSTCMD:	CMD(4, "RAM0",   TSTRM0); exhaustive test for RAM0 chip
	CMD(4, "RAM1",   TSTRM1);   "    "    "    "  RAM1  "
	CMD(3, "PSG",	 TSTPSG); AY-3-8912 sound generator
	.BYTE	0

	.SBTTL	"Display User Context"

;   This routine will display the user registers that were saved after the last
; breakpoint trap.  It's used by the "SHOW REGISTERS" command, and is also
; called directly whenever a breakpoint trap occurs.

; Here to display the registers after a breakpoint trap ...
SHOBPT:	OUTSTR(BPTMSG)		; print "BREAKPOINT ..."
	LBR	SHORE1		; thenn go dump all the registers

; Here for the "SHOW REGISTERS" command...
SHOREG:	CALL(CHKEOL)		; should be the end of the line
				; Fall into SHORE1 ....

; Print a couple of CRLFs and then display X, D and DF...
SHORE1:	RLDI(DP,SAVEXP)		; point DP at the user's context info
	INLMES("XP=")		; ...
	SEX DP\ LDXA		; get the saved value of (X,P)
	CALL(THEX2)		;  ... and print it in hex
	INLMES(" D=")		; ...
	SEX DP\ LDXA		; now get the saved value of D
	CALL(THEX2)		; ...
	INLMES(" DF=")		; ...
	SEX DP\ LDXA		; and lastly get the saved DF
	ADI '0'\ CALL(F_TTY)	; ... it's just one bit!
	CALL(TCRLF)		; finish that line

;   Print the registers R(0) thru R(F) (remembering, of course, that R0 and
; R1 aren't really valid) on four lines, four registers per line...
	LDI 0\ PLO P3		; count the registers here
SHORE2:	OUTCHR('R')		; type "Rn="
	GLO P3\ CALL(THEX1)	; ...
	OUTCHR('=')		; ...
	SEX DP\ POPR(P2)	; now load the register contents from REGS:
	CALL(THEX4)		; type that as 4 hex digits
	CALL(TTABC)		; and finish with a tab
	INC	P3		; on to the next register
	GLO	P3		; get the register number
	ANI	$3		; have we done a multiple of four?
	LBNZ	SHORE2		; nope - keep going

; Here to end the line...
	CALL(TCRLF)		; finish off this line
	GLO	P3		; and get the register number again
	ANI	$F		; have we done all sixteen??
	LBNZ	SHORE2		; nope - not yet
	LBR	TCRLF		; yes - print another CRLF and return

; Messages...
BPTMSG:	.TEXT	"\r\nBREAK AT \000"

	.SBTTL	"Show the Current Date and Time"

;   The SHOW RTC command shows the current date and time from the CDP1879.
; It takes no arguments, and simply calls the SHOWNOW routine.  SHOWNOW is
; used here, and is called from the system startup to show the current date
; and time.
;
;	>>>SHOW RTC
;
SHOWRTC:CALL(CHKEOL)		; no arguments allowed
	CALL(HWTEST)		; make sure the RTC is installed
	 .WORD	 HWRTC		; ...
	CALL(SHOWNOW)		; show the current date/time
	LBR	TCRLF		; print a CRLF and return


; Here to show the current date/time....
SHOWNOW:RLDI(P1,TIMBUF)		; point to the six byte buffer
	CALL(F_GETTOD)		; ask the BIOS to read the clock
	RLDI(P1,CMDBUF)		; point to a temporary string
	RLDI(P2,TIMBUF)		; and point to the date buffer
	CALL(F_DTTOAS)		; convert the date to ASCII
	RLDI(P2,TIMBUF+3)	; point to the time buffer
	CALL(F_TMTOAS)		; and then conver the time
	OUTSTR(CMDBUF)		; print the date/time
	RETURN			; and we're all done

	.SBTTL	"Set Current Date and Time"

;   The SET RTC command will set the CDP1879 RTC time registers.  Note that the
; CDP1879 doesn't actually keep track of the year, but the BIOS will save
; whatever year we're given in our data page.  As long as memory is preserved
; by the battery then the BIOS will remember that year for all future calls to
; get the time.  When January 1st rolls around, you'll have to seet the date and
; time again to fix the year.
;
;	>>>SET RTC mm/dd/yyyy hh:mm:ss
;
;   Note that the syntax used for the date/time is exactly the same as the way
; it's printed by SHOW RTC ...
SETRTC:	CALL(HWTEST)		; make sure the RTC is installed
	 .WORD	 HWRTC		; ...
	CALL(F_LTRIM)		; ignore any leading spaces
	RLDI(0AH,TIMBUF)	; point to the time buffer
	CALL(F_ASTODT)		; try to parse an ASCII date
	LBDF	CMDERR		; branch if the format is illegal
	LDN	P1		; get the break character
	SMI	' '		; it had better be a space
	LBNZ	CMDERR		; bad date otherwise
;	CALL(F_LTRIM)		; skip the spaces
	CALL(F_ASTOTM)		; and now parse the time
	LBDF	CMDERR		; bad date
	CALL(CHKEOL)		; that should be the end

; If all is well, proceed to set the time...
	RLDI(P1,TIMBUF)		; point to the tim buffer again
	CALL(F_SETTOD)		; set the clock
	CALL(SHOWNOW)		; echo the new time
	LBR	TCRLF		; finish the line and return...

	.SBTTL	"SET YEAR Command"

;   Unfortunately the CDP1879 RTC does not keep track of the year (I guess
; they ran out of registers!) so the BIOS caches the year in our data page
; at location YEAR.  The regular BIOS SETTOD and GETTOD functions will take
; care of this transparently, but when the end of the year comes this means
; you have to reset the entire date and time just to roll over the year.
; This command lets you shortcut that process.
;
;CALL:
;	>>>SET YEAR nnnn
;
;   Note that the year should always be specified as four digits.  We'd
; like to just set the YEAR byte in the data page, but there's a catch.
; Although the CDP1879 doesn't keep track of the year, it DOES handle leap
; years and there there's a bit in the RTC MONTH register that tells the chip
; whether there should be a February 29th this year.  The BIOS SETTOD call
; handles this automatically and it's easier to just to let that deal with
; the problem for us.
;
SETYR:	CALL(HWTEST)		; make sure the RTC is installed
	 .WORD	 HWRTC		;  ...
	CALL(DECNW)		; scan a decimal number
	CALL(CHKEOL)		; there should be no more
	GHI P2\ LBNZ SETYR1	; cheesy test for a 4 digit year
	GLO P2\ SMI 72		; is the 2 digit year before 72?
	LBDF	SETYR2		; no - years 72..99 are in 1900
	GLO P2\ ADI 2000-1972	; yes - years 00..71 are in 2000
	LBR	SETYR2		; ...
SETYR1:	GLO P2\ SMI LOW(1972)	; fix the low byte of 4 digit years
SETYR2:	PLO	P2		; save it in P2
	RLDI(P1,TIMBUF)		; point to the six byte time buffer
	CALL(F_GETTOD)		; ask the BIOS for the current time
	RLDI(P1,TIMBUF+2)	; point to the year
	GLO P2\ STR P1		; change the year
	RLDI(P1,TIMBUF)		; ...
	CALL(F_SETTOD)		; change the date
	CALL(SHOWNOW)		; echo the result
	LBR	TCRLF		; finish the line and we're done

	.SBTTL	"SET Q Command"

;   The "SET Q 0" and "SET Q 1" commands may be used to test the Q output.
;
;	>>>SET Q 0
;	- or -
;	>>>SET Q 1
;
;   Nothing in the SBC1802 hardware uses Q directly (with the exception of the Q
; LED on the front panel!) but somebody might design something that does.
SETQ:	CALL(HEXNW)		; one parameter is required
	CALL(CHKEOL)		; no more arguments allowed
	GLO	P2		; get the LSB of the argument
	SHR			; and put the LSB in DF
	LBNF	RESETQ		; reset Q if the LSB is zero

; Here for "SET Q 1" ...
	SEQ			; nope - set Q
	RETURN			; and return

; Here for "SET Q 0"...
RESETQ:	REQ			; reset Q
	RETURN			; and return

	.SBTTL	"SHOW EF Command"

	PAGE

;++
;   The SHOW EF command prints the current state of all four EF inputs.  This
; command optionally takes an argument to specify an I/O group -
;
;	>>>SHOW EF
;	- or -
;	>>>SHOW EF gg
;
;   The state printed is the logical status, so EFx=1 implies that the input
; pin is low and vice versa.  
;
;   Note that we have to be a little careful here - calling any console I/O
; routine, like INLMES or F_TTY, will reset the group to 1!  To that end we
; construct a little routine in RAM at IOTBUF which will change the group
; like this
;
;	IOTBUF:	SEX	PC
;		OUT	GROUP
;		 <group>
;		RETURN
;--
SHOWEF:	RLDI(P4,IOTBUF)		; build the routine in IOTBUF ...
	LDI	($E0+PC)	;  ... execute inline I/O
	STR P4\ INC P4		;  ...
	LDI	($60+GROUP)	;  ...
	STR P4\ INC p4

; Now get the desired group number from the command line
	RLDI(P2,BASEGRP)	; default to the base board I/O group
	CALL(ISEOL)		; is there an argument?
	LBDF	SHOEF1		; no - use the base board group
	CALL(HEXNW)		; yes - go scan that too
	CALL(CHKEOL)		; and that had better be all
SHOEF1:	GLO	P2		; get the desired I/O group
	STR P4\ INC P4		;  ... and add that to IOTBUF
	LDI	($D0+RETPC)	; finish off the little subroutine
	STR	P4		;  ...
				; and start dumping the EFx flags
				
; Print EF1...
	INLMES("EF1=")		; print the flag name
	CALL(IOTBUF)		; select the right group
	LDI	'0'		; assume it's zero
	BN1	EFS1		; and branch if it really is zero
	LDI	'1'		; nope - it's one
EFS1:	CALL(F_TTY)		; print that and proceed

; Print EF2...
	INLMES(" EF2=")		; pretty much the same as above
	CALL(IOTBUF)		; ...
	LDI	'0'		; ...
	BN2	EFS2		; ...
	LDI	'1'		; ...
EFS2:	CALL(F_TTY)		; ...

; Print EF3...
	INLMES(" EF3=")		; just like always 
	CALL(IOTBUF)		; ...
	LDI	'0'		; ...
	BN3	EFS3		; ...
	LDI	'1'		; ...
EFS3:	CALL(F_TTY)		; ...

; Print EF4...
	INLMES(" EF4=")		; more of the same
	CALL(IOTBUF)		; ...
	LDI	'0'		; ...
	BN4	EFS4		; ...
	LDI	'1'		; ...
EFS4:	CALL(F_TTY)		; ...

; All done!
	LBR	TCRLF

	.SBTTL	"SHOW BATTERY"

;   The SHOW BATTERY command reports the status of the memory and RTC backup
; battery.  We don't have an ADC to tell us the exact battery voltage, but
; the DS1231 gives us a single bit - BATTERY OK or BATTERY FAIL.  That bit
; appears as a read only bit in the memory control register, and we can
; fetch it and print the result.
;
;	>>>SHOW BATTERY
;
BATCMD:	CALL(CHKEOL)		; no arguments allowed
	CALL(SHOBAT)		; print the battery status
	LBR	TCRLF		; then finish the line and return


; This routine is called at startup to show the battery status ...
SHOBAT:	INLMES("BATTERY ")	; ...
	RLDI(DP,MCR)\ LDA DP	; read the MCR
	ANI	MC.BBAT		; check the backup battery bit
	LBNZ	SHOBA1		; branch if the battery is good
	INLMES("FAIL")		; this man (er, battery) is dead, Jim ...
	RETURN			; ...
SHOBA1:	INLMES("OK")		; ...
	RETURN

	.SBTTL	"SHOW DP Command"

;   The SHOW DP command dumps the monitor data page, that is the memory space
; from $FE00 thru $FEDF.  It's exactly the same as the equivalent EXAMINE
; command, but it's shorter AND you don't have to remember all those magic 
; addresses.
;
;	>>>SHOW DP
;
;   Note that this DOES NOT dump the memory mapped peripherals - the MCR, RTC
; and PIC - that live from $FEE0 thru $FEFF.  You can still access those with
; the EXAMINE command if you want.
DPDUMP:	CALL(CHKEOL)		; no arguments allowed
DDUMP1:	RLDI(P3,DPBASE)		; start dumping from here
	RLDI(P4,DPEND)		; and stop here
	LBR	MEMDMP		; dump it out in the usual format

	.SBTTL	"SHOW SLU Command"

;   The SHOW SLU command will show the settings, baud rate and character format,
; for SLU0 and, if it is installed, SLU1.  Note that SLU0 is fixed at 8N1,
; however the baud rate can be changed.  SLU1 allows both the baud rate and the
; character format to be changed.
;
;	>>>SHOW SLU
;
SHOSLU:	CALL(CHKEOL)		; no arguments allowed

; SLU0 is always installed, one way or another ...
	INLMES("SLU0: ")		; tell him what's coming
	RLDI(DP,SLBAUD)\ LDN DP	; get the baud rate
	PHI	P3		; store that
	LDI SL.8N1\ PLO P3	; and SLU0 is fixed at 8N1
	CALL(SHOSL1)		; type that
	CALL(TCRLF)		; ...

; Show SLU1 if it is present ...
	CALL(ISHW)		; see if SLU1 is present
	 .WORD	 HWSLU1		; ...
	LBNF	SHOSLX		; quit now if it's not installed
	INLMES("SLU1: ")		; ...
	RLDI(DP,SLBAUD)\ LDN DP	; get the SLU1 baud rate
	SHR\ SHR\ SHR\ SHR	; baud rate for SLU1 is in the upper 4 bits
	PHI	P3		; ...
	INC DP\ LDN DP\ PLO P3	; get the character format from SL1FMT
	CALL(SHOSL1)		; type that
	CALL(TCRLF)		; ...
SHOSLX:	RETURN


;   This routine will print the settings for a particular SLU in a nice human
; readable format.  On call, P3.1 should contain the COM8116/8136 baud rate,
; and P3.0 should contain the CDP1854 UART control register settings.  Uses T1.
SHOSL1:	GHI P3\ ANI $F\ SHL	; get the baud rate times 2
	ADI LOW(BAUDS)\ PLO T1	; index into the baud rate table
	LDI 0\ ADCI HIGH(BAUDS)	; ...
	PHI T1\ SEX T1\ POPR(P1); get the actual baud rate
	CALL(TDECP1)		; type it in decimal
	INLMES(" baud ")	; ...
	GLO	P3		; get the UART settings
	SHR\ SHR\ SHR\ ANI 3	; grab the two WLS bits
	ADI 5\ CALL(THEX1)	; it's either 5, 6, 7 or 8 bits
	GLO P3\ ANI 3		; now get the EPE and PI bits
	ADI LOW(EPEPI)\ PLO T1	; index into the table
	LDI 0\ ADCI HIGH(EPEPI)	; ...
	PHI T1\	LDN T1		; ...
	CALL(F_TTY)		; type that
	GLO P3\ SHR\ SHR	; and lastly get the SBS bit
	ANI 1\ ADI 1		; convert that to either 1 or 2
	LBR	THEX1		; type that and return


;   Table of baud rates (indexed by the COM8116/8136 setting).  Note that the
; SBC1802 hardware is wired up such that the order of the COM8136 bits are
; REVERSED from what you read in the data sheet!  Sorry...
BAUDS:	.WORD	   50		; 0000
	.WORD	 1800		; 0001
	.WORD	  150		; 0010
	.WORD	 4800		; 0011
	.WORD	  110		; 0100
	.WORD	 2400		; 0101
	.WORD	  600		; 0110
	.WORD	 9600		; 0111
	.WORD	   75		; 1000
	.WORD	 2000		; 1001
	.WORD	  300		; 1010
	.WORD	 7200		; 1011
	.WORD	  134		; 1100
	.WORD	 3600		; 1101
	.WORD	 1200		; 1110
	.WORD	19200		; 1111

;   This table relates the two UART bits, EPE (even parity enable) and PI
; (parity inhibit) to the single letter mnemonic we all know and love ...
EPEPI:	.BYTE	'O'		; EPE=0 PI=0
	.BYTE	'N'		; EPE=0 PI=1
	.BYTE	'E'		; EPE=1 PI=0
	.BYTE	'N'		; EPE=1 PI=1

	.SBTTL	"SET SLU0/SLU1 Command"

;   The SET SLU command lets you change the settings for either SLU0 or 1.
; For SLU0 only the baud rate can be changed, however for SLU1 both the baud
; rate and the character format (e.g. 8N1, 7E2, etc) can be specified.
;
;	>>>SET SLU0 bbbbb
;	- or -
;	>>>SET SLU1 bbbbb
;	- or -
;	>>>SET SLU1 bbbbb fff
;
;    Where "bbbbb" is a standard baud rate (e.g. 9600, 19200, 300, etc) and
; "fff" is a character format (8N1, 7E2, etc).  Note that the CDP1854 only
; supports EVEN, ODD or NO parity - force mark and force space parity are not 
; supported, although the software could fake those.
;
;   Serial port settings are saved in the RAM and, if the battery backup is
; working, will be restored at the next power up.  This makes the settings
; "semi-permanent".  Also note that changing the console SLU0 baud rate takes
; effect IMMEDIATELY, so be prepared!

; Here for SET SLU0 ...
SETSL0:	CALL(SETBAUD)		; parse the baud rate argument
	PUSHD			; save it for later
	CALL(CHKEOL)		; no other arguments are allowed
	RLDI(DP,SLBAUD)\ LDN DP	; get the current baud rates
	ANI	BD.SLU1		; clear out the SLU0 setting
	IRX\ OR			; set the new baud rate
SETS01:	STR	DP		; and put that back
	OUTI(GROUP,BASEGRP)	; select the base board I/O group
	SEX DP\ OUT SLUBRG	; update the baud rate generator
	RETURN			; and we're done


; Here for SET SLU1 ...
;   Note that this command always fails if SLU1 is not installed.  You might
; think that it would be a harmless waste of time if SLU1 is absent, but
; remember that without the expansion board there's no I/O group selection.
; That means when we write the new character format to SLU1, below, we'd
; actually be changing SLU0!
SETSL1:	CALL(HWTEST)		; see if SLU1 is present
	 .WORD	 HWSLU1		; ...
	CALL(SETBAUD)		; parse the baud rate argument
	PUSHD			; save it for later
	CALL(ISEOL)		; are there more arguments?
	LBDF	SETS11		; nope - format not specified
	CALL(SETUFMT)		; parse the character format too
	PUSHD			; and save that as well
	CALL(CHKEOL)		; now we'd better be finished
	RLDI(DP,SL1FMT)		; point to the SLU1 character format
	POPD\ STR DP		; and update that
	OUTI(GROUP,SL1GRP)	; select the SLU1 I/O group
	SEX DP\ OUT SL1CTL	; and update the character format
SETS11:	SEX SP\ POPD		; get the baud rate back
	SHL\ SHL\ SHL\ SHL	; SLU1 is on the left
	STR	SP		; save it on the TOS for a second
	RLDI(DP,SLBAUD)\ LDN DP	; then get the old baud rate settings
	ANI	BD.SLU0		; clear out the SLU1 bits
	OR			; and set the new baud rate
	LBR	SETS01		; update the COM8116 and we're done


;   This routine reads the baud rate, a 16 bit decimal number, from the command
; line.  It looks this value up in the BAUDS table and returns the corresponding
; index, which is the COM8116/8136 code for that speed.  If there are any
; errors it just jumps to CMDERR and never returns ...
SETBAUD:CALL(DECNW)		; scan unsigned decimal argument
	RLDI(P3,BAUDS)		; point to the baud rate table
	RCLR(P4)		; and keep the index here
SETBD1:	SEX	P3		; point to the table
	GHI P2\ SM		; does the high byte match?
	LBNZ	SETBD2		; no - skip this entry
	GLO P2\ IRX\ SM		; does the low byte match?
	LBNZ	SETBD3		; nope
	GLO P4\ RETURN		; found a match - return the index in D
SETBD2:	IRX			; skip to the next entry
SETBD3:	IRX			; ...
	INC P4\ GLO P4		; have we checked all the entries?
	ANI	$F0		; ???
	LBZ	SETBD1		; no - keep looking
	LBR	CMDERR		; yes - just give up


;   And this routine parses the character format, strings like 8N1, 5E2, etc.
; It's harder than the baud rate because we have to spend time checking to
; make sure the user's input is valid.  Invalid inputs just branch to CMDERR
; and never return and, if we are successful, the CDP1854 control register bits
; are returned in D.
SETUFMT:CALL(ISEOL)		; make sure there is something there
SETFM1:	LBDF	CMDERR		; punt now if not
	LDA	P1		; the first character must be 5, 6, 7, or 8
	SMI '5'\ LBL  SETFM1	; check the low end first
	SMI 4\   LBGE SETFM1	; and it must be '8' or less
	ADI 4\ SHL\ SHL\ SHL	; restore and position the WLS bits
	PUSHD			; save those on the TOS for now
	LDA P1\ CALL(FOLD)\ IRX	; get the next character
	SMI 'E'\     LBZ SETFM2	; 'E' sets the EPE bit
	SMI 'N'-'E'\ LBZ SETFM3	; 'N' sets the PI bit
	SMI 'O'-'N'\ LBZ SETFM4	; 'O' sets nothing!
	LBR	CMDERR		; anything else is bad ...
SETFM2:	LDI SL.EPE\ LSKP	; set the EPE (even parity) bit
SETFM3: LDI SL.PI		; set the PI (parity inhibit) bit
	OR\ STR SP		; put that together with the WLS bits
SETFM4:	LDA	P1		; and get the third character
	SMI '1'\     LBZ SETFM6	; '1' sets nothing
	SMI '2'-'1'\ LBZ SETFM5	; '2' sets the SBS bit
	LBR	CMDERR		; and anything else is bad
SETFM5: LDI	SL.SBS		; set the stop bit select bit
	OR\ STR SP		; with the rest of the flags
SETFM6:	LDN SP\ RETURN		; return the flag byte and we're done

	.SBTTL	"Initialize Both SLUs Baud and Format"

;++
;   This routine will initialize the baud rate generator and character formats
; for both SLUs.  Usually these settings are saved in RAM at SLBAUD and SL1FMT,
; and if they are then we'll just use that.  If nothing is saved then we try
; to autobaud the console SLU0, and we default SLU1 to 9600 8N1.  The console
; is always set to 8N1 regardless.
;--

; See if terminal settings are saved in RAM, and use them if they are ...
TTYINI:	RLDI(DP,SLBAUD)		; get the baud rates from RAM
	LDN	DP		; ...
	LBZ	TTYI21		; branch if it's not set
	OUTI(GROUP,BASEGRP)	; first load the baud rate generator
	SEX DP\ OUT SLUBRG	; this sets both baud rates
	OUTI(SL0CTL,SL.8N1)	; always set SLU0 to 8N1
	LBR	TTYI22		; finish setting up SLU1 and we're done

;   Here if we need to autobaud.  Note that the BIOS will determine and store
; the the console baud rate at SLBAUD, however it will leave the auxiliary
; SLU1 baud unchanged.  Since that's not initialized either, we'll force it
; to 9600.
TTYI21:	LDI	BD.DFLT		; always set SLU1 to 9600
	STR	DP		; update SLBAUD
	LDI	SL.8N1		; set SLU1 to be 8N1 too
	INC DP\ STR DP		; update SL1FMT
	CALL(F_SETBD)		; now autobaud SLU0

;   Set the SLU1 character format according to what's saved at SL1FMT ...
; BUT, we have to be careful here - if the expansion board isn't installed then
; the base board doesn't decode I/O groups, and writing to the SLU1 UART will
; actually write to SLU0!  That's Bad, so test the HW flags to see if the
; expansion board is present before we do anything ...
TTYI22:	GHI	P4		; are I/O groups implemented ?
	ANI	H1.TLIO		; ??
	LBZ	TTYI23		; nope - skip this
	OUTI(GROUP,SL1GRP)	; now access SLU1
	SEX DP\ OUT SL1CTL	; send SL1FMT to the control register
	OUTI(GROUP,BASEGRP)	; return to the base board group to be safe

; Always be sure the local echo flag is set for CONGET!
TTYI23:	LDI 1\ PHI BAUD		; set BAUD.1 to 1
	RETURN			; and we're done

	.SBTTL	"SHOW CONFIGURATION"

;++
;   The SHOW CONFIGURATION (SHOW CONF is enough!) command lists the hardware
; options installed, including all the options on the main board and the
; expansion board.  The results are all determined by the hardware flags in
; HWFLAGS, which are set up by the POST.
;
;	>>>SHOW CONFIGURATION
;
;   Note that the alternate entry at SHOCF0 is used by SYSINI to show the
; POST results at startup...
;--
SHOCFG:	CALL(CHKEOL)		; this command has no arguments
SHOCF0:	RLDI(P1,HWLIST)		; point P3 at the list of options and flags
	RLDI(DP,HWFLAGS)	; point DP at the hardware flags
SHOCF1:	LDA	P1		; get the flags pointer
	LBZ	SHORAM		; finish by showing the memory size
	PLO	DP		; point at the right flags byte
	LDA	P1		; and get the option bit
	SEX DP\ AND		; see if the bit is set
	LBNZ	SHOCF2		; print the associated name if it is
	LDA P1\ BNZ $-1		; skip over the string
	LBR	SHOCF1		; on to the next option
SHOCF2:	CALL(F_MSG)		; type the option name
	CALL(TSPACE)		; and a space
	LBR	SHOCF1		; then keep looking

; Lastly, show the memory size ...
SHORAM:	CALL(F_FREEMEM)		; get the memory size from the BIOS
	INC	P1		; (it returns the last addressible byte)
	GHI P1\ SHR\ SHR	; convert bytes to kilobytes
	PLO P2\ LDI 0\ PHI P2	; ...
	CALL(TDECP2)		; type the memory size in decimal
	INLMES("K RAM")		; ...
	LBR	TCRLF		; finish the line


;   This table is a list of hardware options.  The first byte is the pointer
; (always assumed to be on our data page) to the associated hardware flags
; byte.  The second byte is the bit mask for that option, and the remainder
; of each entry is the name of the option in ASCIZ.
HWLIST:	.BYTE LOW(HWFLAGS+0), H1.TLIO, "TLIO",   0	; I/O group select
HWSLU0:	.BYTE LOW(HWFLAGS+0), H1.SLU0, "SLU0",   0	; CDP1854   (base)
HWSLU1:	.BYTE LOW(HWFLAGS+1), H0.SLU1, "SLU1",   0	; CDP1854   (expansion)
HWIDE0:	.BYTE LOW(HWFLAGS+0), H1.IDE0, "IDE0",   0	; master disk drive
HWIDE1:	.BYTE LOW(HWFLAGS+0), H1.IDE1, "IDE1",   0	; slave disk drive
HWRTC:	.BYTE LOW(HWFLAGS+0), H1.RTC,  "RTC",    0	; CDP1879   (base)
HWPIC:	.BYTE LOW(HWFLAGS+0), H1.PIC,  "PIC",    0	; CDP1877   (base)
HWPPI:	.BYTE LOW(HWFLAGS+1), H0.PPI,  "PPI",    0	; CDP1851   (expansion)
HWTMR:	.BYTE LOW(HWFLAGS+1), H0.TMR,  "TIMER",  0	; CDP1878   (expansion)
HWMDU:	.BYTE LOW(HWFLAGS+1), H0.MDU,  "MDU",    0	; CDP1855   (expansion)
HWPSG:	.BYTE LOW(HWFLAGS+1), H0.PSG,  "PSG",    0	; AY-3-8912 (expansion)
	.BYTE 0		      	       		 	; end of table


;   This routine will check whether a particular hardware option is installed
; on this system.  It's used by commands, e.g. SET SLU1 ..., that are allowed
; only when that option is present.  The argument, which is passed inline, is
; the address of the corresponding hardware table entry, above ..
;
;CALL:
;	CALL(ISHW)
;	 .WORD	 <hardware table entry>
;	<DF=1 if option installed, DF=0 if not>
;
;   Note that this routine uses T1.  It DOES NOT touch P1, which is likely
; still being used to parse the command line!
ISHW:	LDA A\ PHI T1		; fetch the inline argument
	LDA A\ PLO T1		; ...
ISHW1:	LDA T1\ PLO DP		; set up the HWFLAGS pointer
	LDI HIGH(HWFLAGS)\ PHI DP
	CDF			; assume option not installed
	LDA T1\	SEX DP\ AND	; but is that bit set?
	LSZ			; return DF=0 if not
	SDF			; yes!  return DF=1
ISHW2:	RETURN			; and we're done ...


;   This routine is the same - it tests whether a particular hardware option
; is installed - but this one will print an error and abort this command if
; the option is not present.  It returns only if the option is installed.
HWTEST:	LDA A\ PHI T1		; gotta load the argument here
	LDA A\ PLO T1		; ...
	CALL(ISHW1)		; see if it's installed
	LBDF	ISHW2		; return if the option exists
	CALL(TQUEST)		; not installed - print an error
	RCOPY(P1,T1)		; ... with the option name
	CALL(F_MSG)		; ...
	OUTSTR(HNIMSG)		; ...
	LBR	MAIN		; then abort this command

; "?xxxx NOT INSTALLED" error for absent hardware ...
HNIMSG:	.BYTE	" NOT INSTALLED\r\n", 0

	.SBTTL	"SET OSTYPE and SHOW OSTYPE"

;   These commands allow you to set the operating system type and therefore the
; memory map used for booting and during user program execution.  Right now
; the only options are either ELFOS or MICRODOS.
;
;	>>>SET OSTYPE ELFOS
;	- or -
;	>>>SET OSTYPE MICRODOS
;	- and -
;	>>>SHOW OSTYPE
;
;   The current OSTYPE affects the RUN, CALL and BOOT commands.  It also affects
; the memory map used by CONTINUE, however changing the OSTYPE in the middle of
; program execution probably won't lead to a happy ending.
;
SETOST:	RLDI(P2,OSLIST)		; table of operating system types
	LBR	COMND		; parse the argument and return

;   And here's the table of operating system types (there's only two!).  Fair
; warning - the SHOW OSTYPE command cheats and uses the same strings from this
; table to print out the current selection, so be careful about changing this!
OSLIST:
OSNELOS	.EQU	$+1
	CMD(3, "ELFOS",	   SETELOS)	; select the ElfOS system
OSNMDOS	.EQU   $+1
	CMD(3, "MICRODOS", SETMDOS)	; select the MicroDOS system
	.BYTE  0


; Here to select the ElfOS operating system ...
SETELOS:CALL(CHKEOL)		; that should be the end
	RLDI(DP,OSTYPE)		; set the OSTYPE flag
	LDI MC.ELOS\ STR DP	;  ... to ElfOS
	RETURN			; and we're done


; Here to select the MicroDOS operating system ...
SETMDOS:CALL(CHKEOL)		; that should be the end
	RLDI(DP,OSTYPE)		; set the OSTYPE flag
	LDI MC.MDOS\ STR DP	;  ... to MicroDOS
	RETURN			; and we're done


; Here to display the current OS type selection ...
SHOOST:	CALL(CHKEOL)		; should be the end of the command
	CALL(SHOWOS)		; do the real work
	LBR	TCRLF		; finish the line and return

;   Here to do the real work - this routine is called by SHOW OSTYPE and also
; by the BOOT command...
SHOWOS:	RLDI(DP,OSTYPE)\ LDN DP	; get the OSTYPE flag
	XRI MC.ELOS\ LBZ SHOOS1	; branch if it's ElfOS
	OUTSTR(OSNMDOS)\ RETURN	; nope - say "MICRODOS"
SHOOS1:	OUTSTR(OSNELOS)\ RETURN	; say "ELFOS"

	.SBTTL	"SET RESTART, SET NORESTART and SHOW RESTART Commands"

;   The SET RESTART command allows you to specify the action taken by this
; firmware on a warm start, i.e. one where the current RAM contents are valid.
; Remember that the SBC1802 has battery backup for the RAM, so that situation
; happens all the time.  There are two options -
;
;	>>>SET RESTART xxxx	- run program at memory address xxxx
;	>>>SET RESTART dddd	- attempt to boot from storage device
;
;   The first option, SET RESTART xxxx, obviously depends on there being some
; kind of restart routine stored in memory at a fixed address.  This routine
; is started with the equivalent of a RUN command (i.e. P=0).
;
;   The second one allows you to specify any mass storage device, ID0, ID1,
; TU0 or TU1, as the restart device.  We're very fortunate that NONE of these
; start with a valid hex digit; otherwise this might be ambiguous.
;
;   The SET NORESTART command cancels any current restart setting, and the
; next time you boot you'll get the ">>>" monitor prompt.
;
; SHOW RESTART is even easier - it simply lists the current setting.
;
;	>>>SHOW RESTART
;
SETRST:	CALL(ISEOL)\ LBDF CMDERR; and there had better be an argument there
	RCOPY(T1,P1)		; save a copy of the command line pointer

;   First attempt to scan the hex version of the command.  If this succeeds,
; then we know that's what we have.  If it fails to parse, then back up and
; rescan for a device name ...
	LDN	P1		; get the first character
	CALL(ISHEX)		; is it a hex number?
	LBNF	SETRE1		; nope - try NONE or BOOT
	CALL(HEXNW)		; read a hex number
	CALL(ISEOL)		; and check for end of line
	LBNF	SETRE1		; error - try the other format

; Here for the SET RESTART xxxx form.
	RLDI(DP,RESTA+1)	; point to the boot flag
	SEX DP\ PUSHR(P2)	; save the restart address to RESTA
	LDI AB.ADDR\ STXD	; set BOOTF to AB.ADDR
	RETURN			; and we're done


;   Here to test for the SET RESTART dddd form of the command ...  If the
; argument isn't a device name, then it's wrong!
SETRE1:	CALL(GETDEV)		; get the device number in D
	ORI	AB.BOOT		; set the mass storage boot flag
	PUSHD			; and save that for a second
	RLDI(DP,BOOTF)		; point to the boot flag
	POPD\ STR DP		; and store that option
	RETURN			; after that, we're done ...


; Here for SET NORESTART ...
SETRNO:	CALL(CHKEOL)		; no more arguments
	RLDI(DP,BOOTF)		; ...
	LDI AB.NONE\ STR DP	; set BOOTF to AB.NONE
	RETURN			; and that's all


; The "SHOW RESTART" command prints the current restart option and address...
SHORST:	CALL(CHKEOL)		; no arguments allowed here!
	RLDI(DP,BOOTF)\ LDA DP	; get the restart option
	LBZ	RESHLT		; zero -> SET NORESTART ...
	ADI	AB.BOOT		; test the mass storage boot flag
	LBDF	RESBOO		; yes - show the device name
				; otherwise print the restart address

; Here for RESTART xxxx ...
RESADR:	INLMES("RESTART @")
	SEX DP\ POPR(P2)	; get the restart address
	CALL(THEX4)		; type that in hex
	LBR	TCRLF		; finish the line and return

; Here for RESTART NONE (or unknown) ...
RESHLT:	INLMES("NONE")
	LBR	TCRLF

; And here for RESTART ... ...
RESBOO:	CALL(PRTDEV)		; print the device name
	LBR	TCRLF		; finish the line and we're done

	.SBTTL	"SHOW CPU Command"

;   The SHOW CPU command will figure out whether the CPU is an original 1802 or
; the "newer" 1804/5/6.  Better than that, if this system has the CDP1879 RTC
; installed, we will attempt to determine the CPU clock frequency.  This speed
; measurement is done with interrupts and DMA left ON, so it's especially handy
; if you're using the video card because it allows you to estimate the video
; display overhead.
;
;   BTW, the CPU speed is measured only if the RTC is present because we need
; the RTC's internal clock to give us a measurement of time that's independent
; of the CPU speed.  In principle there are other things that could be used as
; an independent time base (e.g. the baud rate clock for SLU0 comes to mind)
; but I'm too lazy to code all those options.
;
; AFAIK, there's no software way to distinguish between any of the 1804, 1805,
; or 1806 processors.
;
;	>>>SHOW CPU
;
SHOCPU:	CALL(CHKEOL)		; no more arguments

;  The first thing is to figure out whether the CPU is an 1802 or the newer
; 1805/6.  This is pretty easy because the 1805/6 have additional two byte
; opcodes which use 0x68 as the prefix, and on the original 1802 opcode 0x68
; is a no-op.  So the two byte sequence 0x68, 0x68 is just two no-ops on the
; 1802, and on the 1805/6 it's the "RLXA 8" (register load via X and advance)
; instruction.
	PUSHR(8)		; save register 8 just in case it's important
	RCLR(P1)		; make P1 be zero
	SEX	P1		; and then use that for X
	.BYTE	68H, 68H	; then do "RLXA 8"
	SEX	SP		; back to the real stack
	IRX\ POPRL(8)		; and restore R8

;   If P1 is still zero, then the CPU is an 1802.  If P1 has been incremented,
; then the CPU is a 1805/6...
	GLO	P1		; let's see
	LBZ	CPU02		; branch if it's a 1802
	INLMES("CDP1804/5/6")	; nope - it's a 1805/6 - lucky you!
	LBR	SHOCP0		; then continue with the speed measurement
CPU02:	INLMES("CDP1802")	; a more traditional type
SHOCP0:	

;   See if the RTC is present and, if it is, then turn on the periodic divider
; chain and program it for 2Hz (500ms intervals).  Note that this will cause
; an interrupt request, but the PIC is programmed to ignore RTC interrupts
; and the 1802 IE is cleared, anyway.
	CALL(ISHW)		; is the CDP1879 chip present?
	 .WORD	 HWRTC		; ???
	LBNF	SHOCP9		; nope - just skip all this mess
	INLMES(" - SPEED=")
	RCLR(P2)		; clear P2 (we'll use this for counting, later)
	RLDI(DP,RTCBASE+RTCCSR)	; point to the control/status register
	OUTI(GROUP,BASEGRP)	; select the baseboard EF flags
	LDI RT.STRT+RT.O32+RT.CSC\ STR DP ; turn on the clock

; Wait for the RTC IRQ, just to be sure we're synchronized with the clock.
SHOCP1:	BN_RTCIRQ	$	; wait for the RTC IRQ
	STR	DP		; loading the control register clears the IRQ


;   Now that we have a known real time interval, measuring the CPU clock is
; pretty simple.  We simply execute a loop that uses a known number of CPU
; cycles and count the iterations while we're waiting for the RTC IRQ to set
; again.
;
;   But wait, let's think for a minute first.  Suppose we use a simple "INC P2\
; BN_RTCIRQ..." loop?  This loop will take about 4 machine cycles, or 32 clocks.
; Since we could for exactly one second, to convert the iteration count to
; megahertz we just need to multiply by 32 (the number of clocks per iteration).
; Easy enough on paper, but it will require a 16x16 bit --> 32 bit multiply
; operation and, worse yet, it'll require a 32 bit binary to decimal conversion
; in order to print the result.  All that on a 1802!  Just thinking about it
; makes me want to go lie down...
;
;   Suppose we were a little bit smarter and made the loop take 1000 clocks
; instead of 32??  Then we'd have to multiply the iteration count by 1000, but
; wait - multiplying by 1000 is as easy as printing "000" after we type out the
; original count!  No quad precision multiplication or division, and we can use
; the regular TDECP2 routine to print the result.  Alright!
;
;   So, the following loop requires exactly 125 machine cycles per iteration,
; or 1000 clocks.  Since we time for exactly one second, the count that's left
; in P2 is the clock frequency (in Hertz) / 1000.  Just print it and add a few
; more zeros, and we're all set!
;
;   Now aren't you glad we thought about it first???
	NOP\ NOP\ NOP\ NOP\ NOP	; FOR ALINGMENT!
SHOCP2:	INC	P2		; [2] count iterations
	LDI	29		; [2] set up an inner delay loop
SHOC2A:	SMI	1		;   [2] count down
	BNZ	SHOC2A		;   [2]  ... until we get to zero
	NOP			; [3] plus three cycles for an odd total
	BN_RTCIRQ SHOCP2	; [2] wait until the RTC IRQ sets
				; Total = 29*4 + 3*2 + 3 = 125!!!

; All done, and the loop count is now in P2.
	LDI	RT.STRT+RT.O32	; turn off the RTC clock output
	STR	DP		;  ... before anything else!
	CALL(TDECP2)		; and type the result
	INLMES("000")		; multiply by 1000
SHOCP9:	LBR	TCRLF		; finish the line and we're done!!!

	.SBTTL	"SHOW DISK and SHOW TAPE Commands"

;++
;   The SHOW DISK and SHOW TAPE commands show the status of any attached IDE
; disk or TU58 tape drives.  This includes the raw drive size, manufacturer's
; make and model, and whether the drive contains an ElfOS bootable volume.
;
;	>>>SHOW DISK
;	>>>SHOW TAPE
;
;   Note that both these routines are implemented using the new F_SDxxx
; "storage device" routines, rather than the older direct F_IDExxx ones.
;
;   Also note that the unit numbers and the number of drives (two each for
; IDE and TU58) are both hardwired to agree with the current BIOS support.
; That's probably not the best, but it'll do for now.
;--

; Show IDE disk drives ...
SHODSK:	CALL(CHKEOL)		; no arguments allowed
	CALL(ISHW)		; is the master drive installed?
	 .WORD	 HWIDE0		; ???
	LBNF	NODRIVE		; no master (and we assume no slave)
	INLMES("ID0: ")		; ...
	LDI 0\ CALL(SHODRV)	; show the master drive
	CALL(ISHW)		; is there a slave too?
	 .WORD	 HWIDE1		; ???
	LBNF	SHOID1		; no - we're done now
	INLMES("ID1: ")		; ...
	LDI 1\ CALL(SHODRV)	; and show the slave too
SHOID1:	RETURN			; and we're done


; Show TU58 tape drives ...
SHOTAP:	CALL(CHKEOL)		; no arguments allowed
	CALL(ISHW)		; make sure SLU1 exists
	 .WORD	 HWSLU1		; ...
	LBNF	NODRIVE		; no TU58 if there's no SLU1!
	INLMES("TU0: ")		; ...
	LDI 2\ CALL(SHODRV)	; show TU58 unit 0 status
	INLMES("TU1: ")		; ...
	LDI 3\ LBR SHODRV	; and TU58 unit 1 too


; Here if there are no drives installed ...
NODRIVE:RLDI(P1,NDRMSG)		; ?NO DRIVES
	LBR	F_MSG		; print it and quit
NDRMSG:	.BYTE	"?NO DRIVES\r\n", 0


;++
;   And this routine does all the real work of showing the status
; of a single drive.
;
;	<D contains the storage device unit number>
;	CALL(SHODRV)
;--
SHODRV:	PUSHD\ PHI T2		; we'll need the unit number again!
	CALL(F_SDSIZE)		; and get the capacity of this drive
	LBDF	DRVERR		; no drive or drive error
	LDI 0\ CALL(TDEC32U)	; print the total number of sectors
	INLMES(" sectors ")	; ...
	CALL(TDECP1)		; then print the size in MB to
	INLMES("MB ")		; ...
	RLDI(P1,CMDBUF)		; now print the manufacturer
	POPD\ PUSHD		; restore the unit selection
	CALL(F_SDIDENT)		; try to get that information 
	LBDF	DRVERR		; shouldn't fail if SDSIZE worked, but ...
	RLDI(P1,CMDBUF+ID_MDL-1); trim trailing spaces
	CALL(RTRIM)		; ...
	OUTSTR(CMDBUF)		; and print that

;   Try to figure out if the drive contains an ElfOS bootable system.  To
; do that, we read sector 0 into memory and then call F_BTCHECK.  Note that
; if the I/O fails in this case we don't complain; we just assume it's not
; bootable.
	QCLR(T2,T1)		; read sector 0
	RLDI(P1,EO.BBUF)	;  ... into memory at $100
	POPD			; get the unit number back
	CALL(F_SDREAD)		; read that sector
	LBDF	TCRLF		; if it fails, then print CRLF and quit
	CALL(F_BTCHECK)		; see if it boots
	LBDF	TCRLF		; say nothing if it's not
	OUTSTR(EOSVOL)		; say that it's ElfOS bootable
	LBR	TCRLF		; finish the line and we're done

; Here for any error reading the drive ...
DRVERR:	RLDI(P1,DERMSG)		; ?DRIVE ERROR
	LBR	F_MSG		; print and return

; Messages ...
DERMSG:	.TEXT	"?DRIVE ERROR\r\n\000"
EOSVOL:	.TEXT	" ElfOS bootable\000"

	.SBTTL	"Load Intel HEX Records"

;   This routine will parse an Intel .HEX file record from the command line and,
; if the record is valid, deposit it in memory.  All Intel .HEX records start
; with a ":", and the command scanner just funnels all lines that start that
; way to here.  This means you can just send a .HEX file to the SBC1802 thru
; your terminal emulator, and there's no need for a special command to download
; it.  And since each Intel .HEX record ends with a checksum, error checking
; is automatic.
;
;   Intel .HEX records look like this -
;
;	>>>:bbaaaattdddddddddddd......ddcc
;
; Where
;
;	bb   is the count of data bytes in this record
;	aaaa is the memory address for the first data byte
;	tt   is the record type (00 -> data, 01 -> EOF)
;	dd   is zero or more bytes of data
;	cc   is the record checksum
;
;   All values are either two, or in the case of the address, four hex digits.
; All fields are fixed length and no spaces or characters other than hex digits
; (excepting the ":" of course) are allowed.
;
;   While this code is running, the following registers are used -
;
;	P1   - pointer to CMDBUF (contains the HEX record)
;	P2   - hex byte/word returned by GHEX2/GHEX4
;	P3   - memory address (from the aaaa field in the record)
;	T1.0 - record length (from the bb field)
;	T1.1 - record type (from the tt field)
;	T2.0 - checksum accumulator (8 bits only!)
;	T2.1 - temporary used by GHEX2/GHEX4
;
;   Lastly, note that when we get here the ":" has already been parsed, and
; P1 points to the first character of the "bb" field.
;
IHEX:	CALL(GHEX2)\ PLO T1	; record length -> T1.0
	LBNF	CMDERR		; syntax error
	CALL(GHEX4)		; out the load address in P3
	LBNF	CMDERR		; syntax error
	CALL(GHEX2)\ PHI T1	; record type -> T1.1
	LBNF	CMDERR		; syntax error

; The only allowed record types are 0 (data) and 1 (EOF)....
	LBZ	IHEX1		; branch if a data record
	SMI	1		; is it one?
	LBZ	IHEX4		; yes - EOF record

; Here for an unknown hex record type...
	OUTSTR(URCMSG)\	RETURN

;   Here for a data record - begin by accumulating the checksum.  Remember
; that the record checksum includes the four bytes (length, type and address)
; we've already read, although we can safely skip the record type since we know
; it's zero!
IHEX1:	GHI P3\ STR SP		; add the two address bytes
	GLO P3\ ADD\ STR SP	; ...
	GLO T1\ ADD		; and add the record length
	PLO	T2		; accumulate the checksum here

; Read the number of data bytes specified by T1.0...
IHEX2:	GLO	T1		; any more bytes to read???
	LBZ	IHEX3		; nope - test the checksum
	CALL(GHEX2)		; yes - get another data value
	LBNF	CMDERR		; syntax error
	STR SP\ SEX SP		; save the byte on the stack for a minute
	GLO T2\ ADD\ PLO T2	; and accumulate the checksum
	LDN SP\ CALL(DRAM)	; store the byte in memory at (P3)
	LBDF	MEMERR		; memory error
	INC P3\ DEC T1		; increment the address and count the bytes
	LBR	IHEX2		; and keep going

; Here when we've read all the data - verify the checksum byte...
IHEX3:	CALL(GHEX2)		; one more time
	LBNF	CMDERR		; syntax error
	STR SP\ GLO T2\ ADD	; add the checksum byte to the total so far
	LBNZ	IHEX6		; the result should be zero
	INLMES("OK")		; successful (believe it or not!!)
	LBR	TCRLF		; ...

;  Here for an EOF record.  Note that we carelessly ignore everything on the
; EOF record, including any data AND the checksum.  Strictly speaking we're
; not supposed to do that, but EOF records never have any data.
IHEX4:	INLMES("EOF")
	LBR	TCRLF

;   And here if the record checksum doesn't add up.  Ideally we should just
; ignore this entire record, but unfortunatley we've already stuffed all or
; part of it into memory.  It's too late now!
IHEX6:	OUTSTR(HCKMSG)
	RETURN

; HEX file parsing messages ...
HCKMSG:	.TEXT	"?CHECKSUM ERROR\r\n\000"
URCMSG:	.TEXT	"?UNKNOWN RECORD\r\n\000"

	.SBTTL	"Scan Two and Four Digit Hex Values"

;   These routines are used specifically to read Intel .HEX records.  We can't
; call the usual HEXNW, et al, functions here since they need a delimiter to
; stop scanning.  Calling HEXNW would just eat the entire remainder of the
; .HEX record and return only the last 16 bits!  So instead we have two special
; functions, GHEX2 and GHEX4, that scan fixed length fields.

;   This routine will read a four digit hex number pointed to by P1 and return
; its value in P3.  Other than a doubling of precision, it's exactly the same
; as GHEX2...
GHEX4:	CALL(GHEX2)\ PHI P3	; get the first two digits
	LBNF	GHEX40		; quit if we don't find them
	CALL(GHEX2)\ PLO P3	; then the next two digits
	LBNF	GHEX40		; not there
	SDF			; and return with DF set
GHEX40:	RETURN			; all done


;   This routine will scan a two hex number pointed to by P1 and return its
; value in D.  Unlike F_HEXIN, which will scan an arbitrary number of digits,
; in this case the number must contain exactly two digits - no more, and no
; less.  If we don't find two hex digits in the string addressed by P1, the
; DF bit will be cleared on return and P1 left pointing to the non-hex char.
GHEX2:	LDN	P1		; get the first character
	CALL(ISHEX)		; is it a hex digit???
	LBNF	GHEX40		; nope - quit now
	SHL\ SHL\ SHL\ SHL	; shift the first nibble left 4 bits
	PHI	T2		; and save it temporarily
	INC P1\	LDN P1		; then get the next character
	CALL(ISHEX)		; is it a hex digit?
	LBNF	GHEX20		; not there - quit now
	STR SP\ GHI T2\ OR	; put the two digits together
	INC P1\ SDF		; success!
GHEX20:	RETURN			; and we're all done

	.SBTTL	"TEST RAM0 and TEST RAM1 Commands"

;   The TEST RAM0 and TEST RAM1 commands run an exhaustive memory test on either
; of the two SRAM chips.  You might ask, "why not just test them both at the
; same time?"  That would be nice, but it's tricky because of the need to change
; the memory mapping in order to test RAM1.  Besides, this way the user always
; knows which RAM chip is bad :)
;
;	>>>TEST RAM0
;	- or -
;	>>>TEST RAM1
;
;   Note that each pass for one 32K SRAM chip takes about 45 seconds on the
; SBC1802.  You can abort the test at any time by pressing any key on the
; console, but until you do that the test loops forever.  Each passing test
; prints a "." and each failure prints a "X".

; Here to test RAM1 ...
TSTRM1:	CALL(TSTMEM)		; call the shared code
	 .WORD	RM1MSG		;  ... name of the RAM chip we're testing
	 .BYTE	MC.ROM1		;  ... memory mapping mode to use
	 .BYTE	$70		; and test that RAM up to $7000
	RETURN

; Here to test RAM0 ...
TSTRM0:	CALL(TSTMEM)		; call the shared code
	 .WORD	RM0MSG		;  ... name of the RAM chip we're testing
	 .BYTE	MC.ROM0		;  ... memory mapping mode to use
	 .BYTE	$80		;  ... test that RAM up to $8000
	RETURN

; Here's the main loop for testing either chip ...
TSTMEM:	CALL(CHKEOL)		; no more arguments
	CALL(CLRPEK)		; clear the pass and error counter
	OUTSTR(MTSMSG)		; TESTING RAM ...
	SEX A\ POPR(P1)		; print "RAM0" or "RAM1"
	CALL(F_MSG)		; ...
	RLDI(DP,MCR)		; change the memory mapping
	SEX A\ LDXA\ STR DP	; select either ROM0 or ROM1
TSTME1:	LDN	A		; get the top of RAM
	CALL(MEMTST)		; make one test pass
	LBDF	TSTME2		; branch if error
	OUTCHR('.')\ LBR TSTME3	; print a '.' for a good pass
TSTME2:	OUTCHR('X')		; or a "X" for a failure
TSTME3:	CALL(F_BRKTEST)		; does the user want to stop?
	LBNF	TSTME1		; nope - do another pass
	RLDI(DP,MCR)		; be sure the ROM0 map is selected
	LDI MC.ROM0\ STR DP	; ...
	CALL(TCRLF)		; finish the line of dots
	CALL(PRTPEK)		; print the pass/fail count
	INC A\ RETURN		; skip the top of RAM byte and return

; Messages ...
MTSMSG:	.TEXT	"TESTING RAM ... PRESS ANY KEY TO ABORT\r\n\000"
RM0MSG:	.TEXT	"RAM0: \000"
RM1MSG:	.TEXT	"RAM1: \000"

	.SBTTL	"Exhaustive Memory Test"

;   This routine will perform an exhaustive test on one of our RAM chips using
; the "Knaizuk and Hartmann" algorithm (Proceedings of the IEEE April 1977).
; This algorithm first fills memory with all ones ($FF bytes) and then writes a
; byte of zeros to every third location.  These values are read back and tested
; for errors, and then the procedure is repeated twice more, changing the
; positon of the zero byte each time.  After that the entire algorithm is
; repeated again, this time using a memory fill of $00 and every third byte is
; written with $FF.  Strange as it may seem, this test can actually detect
; any combination of stuck data and/or stuck address bits.  Each pass (six
; iterations) requires about 45 seconds for 32K RAM on a 2.5Mhz COSMAC.
;
;   Note that this code assumes the RAM chip to be tested is mapped into low
; RAM, from $0000 thru $7FFF.  If you want to test RAM chip #1 then it's up
; to the caller to change the memory mapping to ROM1 first.  When calling this
; routine, D should contain the first page number NOT to be tested so, for
; example, to test all of RAM0 you would pass $80 to test memory up to $7FFF.
;
;   In the case of RAM1 we have to be careful because, in the ROM1 map, the
; portion of RAM1 from $7E00 thru $7EDF is actually the same physical memory
; as our own data page from $FE00 thru $FEDF.  If we scribble over that while
; testing we'll crash ourselves!  In general there's no point in testing RAM1
; past $6FFF, since the upper 4K of this chip is always shadowed by the BIOS
; space anyway.  So, when testing RAM1 using the ROM0 map, pass $70 in D.
;
;CALL:
;	<D contains $80 or $70 (see above)>
;	CALL(RAMTST)
;	<return DF=0 if pass, DF=1 if fail>
; 
; Register usage for RAMTST:
;	P2   = memory address
;	P3.1 = filler byte
;	P3.0 = test byte
;	P4.0 = modulo 3 counter (current)
;	P4.1 = iteration number (modulo 3 counter for this pass)
;
;   Note that this routine doesn't actually print anything, good or bad, pass
; or fail.  It's up to the caller to do that.  It also doesn't print the failing
; data or address in the event of an error - it could, but given that there's
; only a single RAM chip being tested it probably isn't all that useful.
;
;   It does, however, increment the pass count, PASSK, every time thru.  And it
; also increments the error count, ERRORK, every time a failure is found.
;
MEMTST:	PUSHD			; push the top of RAM onto the stack
	CALL(INPASK)		; increment PASSK
	RLDI(P3,$FF00)		; load the first test pattern
MEMT0:	LDI 2\ PHI P4		; initialize the modulo 3 counter

; Loop 1 - fill memory with the filler byte...
MEMT1:	SEX SP\ IRX\ LDX	; get the memory size from the TOS
	SMI 1\ PHI P2\ DEC SP	; store to last location to test in P2
	LDI $FF\ PLO P2		; and the low byte is always FF
MEMT1A:	GHI P3\ SEX P2\ STXD	; store the filler byte at P2 in RAM
	GHI P2\ ANI $80		; has the address rolled over to $FFFF?
	LBZ	MEMT1A		; nope - keep filling
	CALL(F_BRKTEST)		; does the user want to stop now?
	LBDF	MEMT5		; yes - quit now

; Loop 2 - fill every third byte with the test byte...
MEMT2:	RCLR(P2)		; this time start at $0000
	GHI P4\ PLO P4		; reset the modulo 3 counter
MEMT2A:	GLO	P4		; get the modulo 3 counter
	LBNZ	MEMT2B		; branch if not the third iteration
	GLO P3\ STR P2		; third byte - store the test byte in memory
	LDI 3\ PLO P4		; then re-initialize the modulo 3 counter
MEMT2B:	DEC	P4		; decremement the modulo 3 counter
	INC P2\ GHI P2		; increment the address and get the high byte
	SEX SP\ IRX\ XOR\ DEC SP; does it equal the memory size on the TOS?
	LBNZ	MEMT2A		; nope - keep going
	CALL(F_BRKTEST)		; does the user want to stop now?
	LBDF	MEMT5		; yes - quit now

; Loop 3 - nearly the same as Loop 2, except this time we check the bytes...
MEMT3:	RCLR(P2)		; start at $0000
	GHI P4\ PLO P4		; reset the modulo 3 counter
MEMT3A:	GLO	P4		; get the modulo 3 counter
	LBNZ	MEMT3B		; branch if not the third iteration
	LDI 3\ PLO P4		; re-initialize the modulo 3 counter
	GLO P3\ SKP		; and get the test byte
MEMT3B:	GHI	P3		; not third byte - test against fill byte
	SEX P2\ XOR		; address memory with P2 and test the data
	LBZ	MEMT3C		; branch if success

; Here if we find a bad byte at the address in P2 ...
	CALL(INERRK)		; increment the error count
	SDF\ IRX\ RETURN	; give the error return

; Here if the test passes - on to the next location...
MEMT3C:	DEC	P4		; decremement the modulo 3 counter
	INC P2\ GHI P2		; increment the address and get the high byte
	SEX SP\ IRX\ XOR\ DEC SP; does it equial the memory size on the TOS?
	LBNZ	MEMT3A		; nope - keep going
	CALL(F_BRKTEST)		; does the user want to stop now?
	LBDF	MEMT5		; yes - quit now

; This pass is completed - move the position of the test byte and repeat...
	GHI P4\ SMI 1		; decrement the current modulo counter
	LBL	MEMT4		; branch if we've done three passes
	PHI	P4		; nope - try it again
	LBR	MEMT1		; and do another pass

;   We've done three passes with this test pattern.  Swap the filler and
; test bytes and then do it all over again ...
MEMT4:	GLO	P3		; is the test byte $00??
	LBNZ	MEMT5		; nope - we've been here before
	RLDI(P3,$00FF)		; yes - use 00 as the fill and FF as the test
	LBR	MEMT0		; reset the modulo counter and test again

; One complete test (six passes total) are completed..
MEMT5:	CDF\ IRX\ RETURN	; give the success return

	.SBTTL	"Diagnostic Support Routines"

;   This little routine will clear the current diagnostic pass and error
; counts (PASSK and ERRORK).  It's called at the start of most diagnostics.
CLRPEK:	RLDI(DP,PASSK+3)	; PASSK is first, then ERRORK
	SEX DP\ LDI 0		; ...
	STXD\ STXD		; clear ERRORK
	STXD\ STXD		; and clear PASSK
	RETURN			; all done


; Increment the current diagnostic pass counter...
INPASK:	LDI	LOW(PASSK+1)	; point to the LSB first
	LSKP			; and fall into INERRK...

; Increment the current diagnostic error counter...
INERRK:	LDI	LOW(ERRORK+1)	; point to ERRORK this time
	PLO DP\ SEX DP		; ...
	LDX\ ADI  1\ STXD	; increment the LSB
	LDX\ ADCI 0\ STR DP	; carry into the MSB
	RETURN			; and we're done


; Print the current diagnostic pass and error count...
PRTPEK:	RLDI(DP,PASSK)		; point DP at the pass counter
	SEX DP\ POPR(P1)	; load PASSK into P2
	CALL(TDECP1)		; print the pass count in decimal
	INLMES(" PASSES ")
	SEX DP\ POPR(P1)	; now load ERRORK into P2
	CALL(TDECP1)		; and print that
	INLMES(" ERRORS")	; ...
	LBR	TCRLF		; finish the line and we're done

	.SBTTL	"Tests AY-3-8912 Sound Generator Chip"

;++
;--
TSTPSG:	CALL(CHKEOL)
	RLDI(P4,MUSIC)
	LBR	PLAYER

	.SBTTL	"Play Music!"

;++
;   This routine will play music (or any random noise!) using the AY-3-8912
; programmable sound generator chip.  It interprets a byte stream generated
; by Len Shustek's MIDITONES program, 
;
;	http://code.google.com/p/miditones/
;
; Len's program takes a MIDI file and renders it for three basic tone generators
; and then outputs a simple stream of byte codes for the music.  Len documents
; the byte codes fairly well on his web page, so I won't repeat that part here.
;
; LIMITATIONS
;   Right now, Len's program only extracts tone (i.e. note) information from
; the MIDI - everything else is lost.  The 89102 is capable of independently
; controlling the volume for each of the three tone generators and it'd sound
; a lot better if some rudimentary dynamics/volume control was added. 
;
;CALL:
;	<P4 points to the byte stream from MIDITONES>
;	CALL(PLAYER)
;
; NOTE that pretty much all registers are used here!
;--

; Initialize the PSG ...
PLAYER:	OUTI(GROUP, PSGGRP)	; select the sound generator I/O group
	OUTPSG(PSGR6,  $00)	; disable the noise generator
	OUTPSG(PSGR7,  $38)	; turn on tones A, B & C
	OUTPSG(PSGR10, $00)	; mute channel A
	OUTPSG(PSGR11, $00)	; ... channel B
	OUTPSG(PSGR12, $00)	; ... and C
	OUTPSG(PSGR15, $00)	; disable envelope generator (we don't use it)

; Now we're ready to play ....
	CALL(PLAYLP)		; and away we go!!

; Reset the PSG and we're done...
	OUTPSG(PSGR10, $00)	; mute channel A
	OUTPSG(PSGR11, $00)	; ... channel B
	OUTPSG(PSGR12, $00)	; ... and C
	OUTPSG(PSGR7,  $3F)	; turn off all mixer inputs
	OUTI(GROUP, BASEGRP)	; select the base board I/O group again
	RETURN			; and back to the monitor

	.SBTTL	"Music Player Loop"

;++
;   This is the main loop of the AY-3-8912 music player.  It fetches the next
; note or function from the music stream and programmes the 8912 accordingly.
; P4 should point at the music stream.
;--
PLAYLP:	LDN	P4		; look ahead at the next byte
	ANI	$80		; check only the MSB
	LBNZ	PLAY1		; branch if it's a tone generator function

; It's a delay - this byte and the next byte are the interval, in milliseconds.
	LDA	P4		; get the first delay byte
	PHI	P1		; they're in big endian ordering
	LDA	P4		; and the second delay byte
	PLO	P1		; ...
;   Things get a little tricky now - with a 2.5MHz CPU crystal, it's not
; possible to generate an exact 1mS delay.  A delay of exactly 2mS can be done
; however, and we have the DLY2MS macro for that.  The DLY1MS macro attempts
; a 1mS delay, but it's off by 4 clocks or about 1.6uS.  Nobody would notice
; that, as long as we don't let the error accumulate (say, by putting DLY1MS
; inside a loop!).
	ANI	1		; was the delay interval odd?
	LBZ	PLAY10		; no - skip this
	DLY1MS			; yes - add an extra 1mS delay
	DEC	P1		; and adjust the count
PLAY10:	GLO P1\ STR SP		; see if the count is zero
	GHI P1\ OR		; ...
	LBZ	PLAYLP		; quit when it's zereo
	DLY2MS			; delay for 2mS
	DEC P1\ DEC P1		; decrement the count twice!
	LBR	PLAY10		; keep delaying until it's zero

;   It's not a delay.  A byte of $9t (where 't' is the tone generator number)
; starts a tone playing, and $89 stops it.  Officially the only other defined
; value is $F0, which means end of tune, but we interpret anything else as the
; end and stop playing.
PLAY1:	LDN	P4		; get the byte code again
	ANI	$F0		; look at just the top nibble
	SMI	$90		; check for $80 or $90
	LBZ	PLAY3		; branch if $80 - start a tone
	LBL	PLAY2		; branch if $90 - stop a tone
	RETURN			; otherwise we're done playing - quit!

;   Stop a tone generator.  This is a single byte code, and the lower nibble is
; the tone generator index - 0, 1 or 2.  In theory there could be more tone
; generators (up to 16, I guess) but we don't deal well with that case...
PLAY2:	LDA	P4		; get the command one more time
	ANI	$0F		; get only the generator number
	LBNZ	PLAY20		; if it's not zero, check channel B or C
	CALL(MUTEA)		; mute channel A
	LBR	PLAYLP		; ... and we're done
PLAY20:	SMI	1		; is it B or C ??
	LBNZ	PLAY21		; branch if channel C
	CALL(MUTEB)		; nope - mute channel B
	LBR	PLAYLP		; ...
PLAY21:	CALL(MUTEC)		; here if channel C
	LBR	PLAYLP		; ...


;   Start a tone generator.  This is a two byte code - the lower nibble of the
; first byte is the tone generator number, just like for MUTE.  The second
; byte is the MIDI note number, from 0 to 127.  The MIDI note number we have to
; actually look up in the note table in order to translate it to a counter
; value for the 8910 tone generator...
PLAY3:	LDA	P4		; dispatch by the tone generator number
	ANI	$0F		; ...
	LBNZ	PLAY30		; ... check channel B or C
	LDA	P4		; channel A - get the note number
	CALL(PLAYA)		; ... and play
	LBR	PLAYLP		; ... and we're done
PLAY30:	SMI	1		; is it B or C ??
	LBNZ	PLAY31		; branch if channel C
	LDA	P4		; get the note
	CALL(PLAYB)		; ... and play channel B
	LBR	PLAYLP		; ...
PLAY31:	LDA	P4		; get the note
	CALL(PLAYC)		; ... and play channel C
	LBR	PLAYLP		; ...

	.SBTTL	"PSG Functions to Control the Tone Generators"

; Play the MIDI note in D on tone generator A ...
PLAYA:	CALL(LDNOTE)		; get the tone generator setting
	GLO	P1		; get the low tone byte
	CALL(WRPSG)		; and write to R0
	 .DB	 PSGR0		;  ....
	GHI	P1		; then write the high byte
	CALL(WRPSG)		;  ....
	 .DB	 PSGR1		;  ... to R1
	OUTPSG(PSGR10, PSGVOL)	; and finally unmute channel A
	RETURN			; all done

; Play the MIDI note in D on tone generator B ...
PLAYB:	CALL(LDNOTE)		; get the tone generator setting
	GLO	P1		; get the low tone byte
	CALL(WRPSG)		; and write to R2
	 .DB	 PSGR2		;  ....
	GHI	P1		; then write the high byte
	CALL(WRPSG)		;  ....
	 .DB	 PSGR3		;  ... to R3
	OUTPSG(PSGR11, PSGVOL)	; and finally unmute channel B
	RETURN			; all done

; Play the MIDI note in D on tone generator C ...
PLAYC:	CALL(LDNOTE)		; get the tone generator setting
	GLO	P1		; get the low tone byte
	CALL(WRPSG)		; and write to R4
	 .DB	 PSGR4		;  ....
	GHI	P1		; then write the high byte
	CALL(WRPSG)		;  ....
	 .DB	 PSGR5		;  ... to R5
	OUTPSG(PSGR12, PSGVOL)	; and finally unmute channel C
	RETURN			; all done

; Mute channel A ...
MUTEA:	OUTPSG(PSGR10, $00)	; just set the volume to zero
	RETURN			; ...

; Mute channel B ...
MUTEB:	OUTPSG(PSGR11, $00)	; ...
	RETURN			; ...

; Mute channel C ...
MUTEC:	OUTPSG(PSGR12, $00)	; ...
	RETURN			; ...

	.SBTTL	"PSG Miscellaneous Subroutines"

; Write the byte in D to the PSG register indicated inline ...
WRPSG:	SEX	A		; point X at the inline register number
	OUT	PSGADDR		; send it to the PSG, increment A
	SEX	SP		; back to the stack
	STR	SP		; save D on the TOS
	OUT	PSGDATA		; and write the data byte
	DEC	SP		; correct for OUT, which increments X
	RETURN			; and we're done


; Read the PSG register indicated inline, return the result in D ...
RDPSG:	SEX	A		; point X at the register (inline)
	OUT	PSGADDR		; select that register, increment A
	SEX	SP		; point X at the TOS again
	INP	PSGDATA		; read the register into D and the TOS
	RETURN			; that's all


; Load the note table entry for the note in D into P1 ...
LDNOTE:	ADI	PSGKEY		; transpose the note if desired
	SHL			; multiply the index by two
	ADI	LOW(MIDINOTE)	; index into the MIDI note table
	PLO	T1		; and save that in the pointer
	LDI	HIGH(MIDINOTE)	; then set the high part 
	ADCI	0		; include any carry
	PHI	T1		; set the rest of the pointer
	LDA T1\ PHI P1		; get the note high byte
	LDN T1\ PLO P1		; and the low byte
	RETURN			; ...

	.SBTTL	"MIDI Note and Test Music Tables"

;++
;   This table is indexed by the MIDI note number, 0..127, and gives the
; corresponding 8912 tone generator setting.  In the SBC1802 the 8912 clock
; is the baud rate clock, 4.9152Mhz, divided by 4.  So these values are
; calculated assuming a 1.2288MHz clock for the 8912.
;
;   Note that this table contains only six octaves worth of notes to save
; space, although MIDI allows for much more.  The PSGKEY symbol is the offset
; applied to each note to get the correct table entry, remembering of course
; that each octave is 12 notes.
;--
PSGKEY	.EQU	-36+12
MIDINOTE:
;		   A      A#     B     C      C#      D      D#     E      F      F#     G      G#
	.WORD	 4697,  4433,  4184,  3950,  3728,  3519,  3321,  3135,  2959,  2793,  2636,  2488
	.WORD	 2348,  2217,  2092,  1975,  1864,  1759,  1661,  1567,  1479,  1396,  1318,  1244
	.WORD	 1174,  1108,  1046,   987,   932,   880,   830,   784,   740,   698,   659,   622
	.WORD	  587,   554,   523,   494,   466,   440,   415,   392,   370,   349,   329,   311
	.WORD	  294,   277,   262,   247,   233,   220,   208,   196,   185,   175,   165,   156
	.WORD	  147,   139,   131,   123,   116,   110,   104,    98,    92,    87,    82,    78


;++
;   And this table is some sample music that can be played with the "TEST PSG"
; command.  The first one is a simple set of scales, played first with single
; notes and then again with chords to demonstrate the polyphonic abilities of
; the 8912.   The second part is just a piece of popcorn - you'll recognize it!
MUSIC:
	; Scales ...
	.BYTE	$90, $48, $01, $BF, $90, $54, $01, $C0, $90, $53, $01, $C0
	.BYTE	$90, $51, $01, $C0, $80, $00, $05, $90, $4F, $01, $C0, $90, $4D
	.BYTE	$01, $C0, $90, $4C, $01, $C0, $90, $4A, $01, $C0, $80, $00, $05
	.BYTE	$90, $48, $03, $80, $80, $03, $85, $90, $48, $01, $C0, $90, $4C
	.BYTE	$91, $54, $01, $C0, $90, $53, $91, $4A, $01, $C0, $90, $48, $91
	.BYTE	$51, $01, $C0, $80, $81, $00, $05, $90, $47, $91, $4F, $01, $C0
	.BYTE	$90, $45, $91, $4D, $01, $C0, $90, $4C, $91, $43, $01, $C0, $90
	.BYTE	$41, $91, $4A, $01, $C0, $80, $81, $00, $05, $90, $40, $91, $48
	.BYTE	$03, $80, $80, $81, $03, $85, $90, $43, $91, $48, $92, $3C
	.BYTE	$01, $C0, $90, $51, $91, $4F, $92, $54, $01, $C0, $90, $51
	.BYTE	$91, $47, $92, $53, $01, $BF, $90, $51, $91, $48, $92, $4D
	.BYTE	$01, $C0, $80, $81, $82, $00, $06, $90, $4F, $91, $4C, $92, $48
	.BYTE	$01, $C0, $90, $4D, $91, $4A, $92, $41, $01, $BF, $90, $43, $91
	.BYTE	$4C, $92, $45, $01, $C0, $90, $41, $91, $4A, $92, $3E, $01, $C0
	.BYTE	$80, $81, $82, $00, $05, $90, $43, $91, $48, $92, $45, $05, $40
	.BYTE	$80, $81, $82
	; Pause ...
	.BYTE	$02, $FF
	; Popcorn ...
	.BYTE	$90, $54, $00, $D6, $90, $52, $00, $D6, $90, $54, $00, $D6
	.BYTE	$90, $4F, $00, $D7, $90, $4B, $00, $D6, $90, $4F, $00, $D6
	.BYTE	$90, $48, $01, $AD, $90, $54, $00, $D6, $90, $52, $00, $D6
	.BYTE	$90, $54, $00, $D7, $90, $4F, $00, $D6, $90, $4B, $00, $D6
	.BYTE	$90, $4F, $00, $D6, $90, $48, $01, $AD, $90, $54, $00, $D6
	.BYTE	$90, $56, $00, $D7, $90, $57, $00, $D6, $90, $54, $00, $6B
	.BYTE	$90, $57, $00, $D6, $90, $54, $00, $6B, $90, $57, $00, $D7
	.BYTE	$90, $56, $00, $D6, $90, $52, $00, $6B, $90, $56, $00, $D6
	.BYTE	$90, $52, $00, $6C, $90, $56, $00, $D6, $90, $54, $00, $D6
	.BYTE	$90, $52, $00, $D6, $90, $4F, $00, $D7, $90, $52, $00, $D6
	.BYTE	$90, $54, $01, $AD, $80
	; End of music ...
	.BYTE $F0

	.EJECT
	.EJECT
	.EJECT
	.EJECT
	.EJECT
	.EJECT
	.EJECT
	.EJECT
	.EJECT
	.EJECT
	.EJECT
	.EJECT
	.EJECT
	.EJECT
	.EJECT
;;	.TEXT	"THIS IS GARBAGE JUST TO CHANGE THE CHECKSUM"
	.EJECT

;   Here to confirm a really dangerous operation.  We return DF=1 if the user
; types either "Y" or "y", and DF=0 for absolutely anything else.
;
;   The alternate entry point at "YESORNO" does essentially the same thing,
; but it's up to the caller to print an appropriate message first.
CONFIRM:OUTSTR(CNFMSG)		; give the user a fair warning
YESORNO:CALL(F_READ)\ CALL(FOLD); read one character from console
	SMI	'Y'		; this is the only acceptable answer
	LBZ	CONFI1		; ...
	CDF\ LBR TCRLF		; no - return DF=0
CONFI1:	SDF\ LBR TCRLF		; yes - return DF=1
CNFMSG:	.TEXT	"ARE YOU SURE?\000"

	.SBTTL	"Command Parsing Functions"

;   Examine the character pointed to by P1 and if it's a space, tab, or end
; of line (NULL) then return with DF=1...
ISSPAC:	LDN	P1		; get the byte from the command line
	LBZ	ISSPA1		; return TRUE for EOL
	SMI	CH.TAB		; is it a tab?
	LBZ	ISSPA1		; yes - return true for that too
	SMI   ' '-CH.TAB	; no - what about a space?
	LBZ	ISSPA1		; that works as well
	CDF			; it's not a space, return DF=0
	RETURN			; ...
ISSPA1:	SDF			; it IS a space!
	RETURN


; If the character pointed to by P1 is EOL, then return with DF=1...
ISEOL:	CALL(F_LTRIM)		; ignore any trailing spaces
	LDN	P1		; get the byte from the command line
	LBZ	ISSPA1		; return DF=1 if it's EOL
	CDF			; otherwise return DF=0
	RETURN			; ...


; Just like ISEOL, but if the next character is NOT an EOL, then error ..
CHKEOL:	CALL(ISEOL)		; look for the end of line next
	LBNF	CMDERR		; abort this command if it's not
	RETURN			; otherwise do nothing


;   This routine will examine the ASCII character in D and, if it is a lower
; case letter 'a'..'z', it will fold it to upper case.  All other ASCII
; characters are left unchanged...
FOLD:	ANI	$7F		; only use seven bits
	PLO	BAUD		; save the character (very) temporarily
	SMI	'a'		; is it a lower case letter ???
	LBL	FOLD1		; not this time
	SMI   'z'-'a'+1		; check it against both ends of the range
	LBGE	FOLD1		; nope -- it's not a letter
	GLO	BAUD		; it is lower case - get the original character
	SMI	$20		; convert it to upper case
	RETURN			; and return that
FOLD1:	GLO	BAUD		; it's not lower case ...
	RETURN			; ... return the original character


;   This routine will examine the ASCII character in D and, if it is a hex
; character '0'..'9' or 'A'..'Z', it will convert it to the equivalent binary
; value and return it in D.  If the character in D is not a hex digit, then
; the DF will be cleared on return.
ISHEX:	ANI	$7F		; ...
	PLO	BAUD		; save the character temporarily
	SMI	'0'		; is the character a digit '0'..'9'??
	LBL	ISHEX3		; nope - there's no hope...
	SMI	10		; check the other end of the range
	LBL	ISHEX2		; it's a decimal digit - that's fine
	GLO	BAUD		; It isn't a decimal digit, so try again...
	CALL(FOLD)		; convert lower case 'a'..'z' to upper
	SMI	'A'		; ... check for a letter from A - F
	LBL	ISHEX3		; nope -- not a hex digit
	SMI	6		; check the other end of the range
	LBGE	ISHEX3		; no way this isn't a hex digit
; Here for a letter 'A' 	.. 'F'...
	ADI	6		; convert 'A' back to the value 10
; Here for a digit '0' .	. '9'...
ISHEX2:	ADI	10		; convert '0' back to the value 0
	SDF			; just in case
	RETURN			; return with DF=1!
; Here if the character 	isn't a hex digit at all...
ISHEX3:	GLO	BAUD		; get the original character back
	CDF			; and return with DF=0
	RETURN			; ...

;   The BIOS has a strcpy function but not a strncpy, so here's our own.  This
; routine copies bytes from the string pointed to by P1 to the destination
; pointed to by P2, up to P3 bytes.  It stops either when it finds a null byte
; in the source, or when it exhausts the byte count.  The destination string
; is always left null terminated in either case.
STRNCPY:LDA P1\ STR P2\ INC P2	; copy one byte
	LBZ	STRRET		; quit if we found EOS
	DEC	P3		; decrement the count
	GHI P3\ LBNZ STRNCPY	; keep copying if it's not zero
	GLO P3\ XRI 1		; is there only 1 byte left?
	LBNZ	STRNCPY		; no - more copying
	STR	P2		; yes - null terminte the destination
STRRET:	RETURN			; and we're done

;   The BIOS has a ltrim function but not an rtrim, so here's another one of
; our own.  This is a little kludgy because it doesn't check for the beginning
; of the string, and thus assumes that there's at least one space out there!
; Use with caution...
;
;   On call, P1 should point to the END of the string.  It backs up until it
; finds a non-space character, then moves forward one byte and replaces that
; with a null (EOS) byte.
RTRIM:	LDN P1\ DEC P1		; get a byte and back up
	LBZ	STRRET		; return if we find an EOS
	SMI	' '		; is this a space?
	LBZ	RTRIM		; yes - keep backing up
	LDI	0		; no - store an EOS in memory
	INC P1\ INC P1\ STR P1	; in the last non-null byte
	RETURN

	.SBTTL	"Scan Command Parameter Lists"

;   These routines will scan the parameter lists for commands which either
; one, two or three parameters, all of which are hex numbers.

; Scan two parameters and return them in registers P4 and P3...
HEXNW2:	CALL(HEXNW)		; scan the first parameter
	RCOPY(P3,P2)		; and save it
	CALL(ISEOL)		; there had better be more there
	LBDF	CMDERR		; error if not
				; fall into HEXNW to get another

; Scan a single parameter and return its value in register P2...
HEXNW:	CALL(F_LTRIM)		; ignore any leading spaces
	LDN	P1		; get the next character
	CALL(ISHEX)		; is it a hex digit?
	LBNF	CMDERR		; no - print error message and restart
	LBR	F_HEXIN		; scan a number and return in P2

; Scan a single DECIMAL parameter and return the value in P2...
DECNW:	CALL(F_LTRIM)		; ignore leading spaces
	CALL(F_ATOI)		; try to read a decimal string
	LBDF	CMDERR		; quit if nothing was found
	RETURN			; otherwise return the result in P2

; This routine will return DF=1 if (P3 .LE. P4) and DF=0 if it is not...
P3LEP4: GHI	P3		; First compare the high bytes
	STR	SP		; ....
	GHI	P4		; ....
	SM			; See if P4-P3 < 0 (which implies that P3 > P4)
	LBL	P3GTP4		; because it is an error if so
	LBNZ	P3LE0		; Return if the high bytes are not the same
	GLO	P3		; The high bytes are the same, so we must
	STR	SP		; repeat the test for the low bytes
	GLO	P4		; ....
	SM			; ....
	LBL	P3GTP4		; ....
P3LE0:	SDF			; return DF=1
	RETURN			; Everything is in the right order...
P3GTP4:	CDF			; return DF=0
	RETURN			; ...

	.SBTTL	"Output Decimal and Hexadecimal Numbers"

;   This routine will convert a four bit value in D (0..15) to a single hex
; digit and then type it on the console...
THEX1:	ANI	$0F		; trim to just 4 bits
	ADI	'0'		; convert to ASCII
	SMI	'9'+1		; is this digit A..F?
	LBL	THEX11		; branch if not
	ADI	'A'-'9'-1	; yes - adjust the range
THEX11:	ADI	'9'+1		; and restore the original character
	LBR	F_TTY		; type it and return

; This routine will type a two digit (1 byte) hex value from D...
THEX2:	PUSHD			; save the whole byte for a minute
	SHR\ SHR\ SHR\ SHR	; and type type MSD first
	CALL(THEX1)		; ...
	POPD			; pop the original byte
	LBR	THEX1		; and type the least significant digit

; This routine will type a four digit (16 bit) hex value from P2...
THEX4:	GHI	P2		; get the high byte
	CALL(THEX2)		; and type that first
	GLO	P2		; then type the low byte next
	LBR	THEX2		; and we're done

;   And finally, this routine will type an unsigned 16 bit value from P1 as
; a decimal number.  It's a pretty straight forward recursive routine and
; depends heavily on the BIOS F_DIVIDE function!  Note that the TDECP2 entry
; is identical except that it first copies the value from P2 to P1.
;
;   And notice that TDECxx (or rather, the BIOS F_DIV16 function really)
; trashes P4.  That breaks a lot of code which calls TDECxx, and so we 
; need to save and restore P4.  Since the basic decimal output is recursive,
; that means we have to wrap it with another function.
TDECP2:	RCOPY(P1,P2)		; type a value from P2 instead
TDECP1:	PUSHR(P4)		; save P4
	CALL(TDEC16)		; do the actual work
	IRX\ POPRL(P4)		; restore P4
	RETURN			; and we're done

; Here to do the real work of typing a decimal number in P1 ...
TDEC16:	RLDI(P2,10)		; set the divisor
	CALL(F_DIV16)		; divide P1 by ten
	GLO	P1		; get the remainder
	PUSHD			; and stack that for a minute
	RCOPY(P1,P4)		; transfer the quotient back to P1
	LBNZ	TDEC1A		; if the quotient isn't zero ...
	GHI	P1		;  ... then keep dividing
	LBZ	TDEC1B		;  ...
TDEC1A:	CALL(TDECP1)		; keep typing P1 recursively
TDEC1B:	POPD			; then get back the remainder
	LBR	THEX1		; type it in ASCII and return

	.SBTTL	"Type Version Number"

;   Type a version number as used by the firmware and the BIOS, in the format
; "MM(eeee)", where MM is the major version and eeee is the edit number.  All
; fields are decimal.  Version numbers are stored in three bytes (yes, three)
; as follows -
;
; VERSION: .BYTE  MAJOR
;	   .WORD  EDIT
;
; When this routine is called, P3 should point to this version number block.
TVERSN:	LDA	P3		; get the major version
	PLO	P2		; (TDECU wants a 16 bit argument!)
	LDI	0		; ...
	PHI	P2		; ...
	CALL(TDECP2)		; type that in decimal
	OUTCHR('(')		; ...
	LDA	P3		; now get the edit number
	PHI	P2		; ...
	LDA	P3		; this time it's 16 bits
	PLO	P2		; ...
	CALL(TDECP2)		; type it in decimal
	LDI	')'		; ...
	LBR	F_TTY		; and we're done

	.SBTTL	"Type Various Special Characters"

; This routine will type a carriage return/line feed pair on the console...
TCRLF:	LDI	CH.CRT		; type carriage return
	CALL(F_TTY)		; ...
	LDI	CH.LFD		; and then line feed
	LBR	F_TTY		; ...

; Type a single space on the console...
TSPACE:	LDI	' '		; this is what we want
	LBR	F_TTY		; and this is where we want it

; Type a (horizontal) tab...
TTABC:	LDI	CH.TAB		; ...
	LBR	F_TTY		; ...

; Type a question mark...
TQUEST:	LDI	'?'		; ...
	LBR	F_TTY		; ...

	.SBTTL	"32 bit Unsigned Decimal Input and Output"

;++
;   This routine will scan an unsigned decimal number from the command line
; and return a 32 bit value in (T2,T1).  Except for the quad precision
; aspect, it works pretty much like any of the other decimal input routines.
;
;CALL:
;	CALL(DECNQ)
;	<return with 32 bit value in (T2,T1)>
;
;   Note that if at least one decimal digit is not found, it will branch
; to CMDERR and never return!
;--
DECNQ:	CALL(F_LTRIM)		; skip any leading spaces
	LDN P1\ CALL(F_ISNUM)	; make sure there is at least one digit
	LBNF	CMDERR		; ... fail if not
	PUSHQ(P3,P4)		; we need these regsters for working space
	QCLR(T2,T1)		; accumulate the total here
DECNQ0:	LDN	P1		; get the next character
	CALL(F_ISNUM)		; is it a decimal digit
	LBNF	DECNQ1		; branch when we reach the end
	RCLR(P4)\ RLDI(P3,10)	; multiply the current total by 10
	CALL(MUL32)		; ...
	LDA P1\ SMI '0'		; get the character back and convert to binary
	SEX SP\ STR SP		; put it on the stack
	GLO T1\ ADD   \ PLO T1	; quad precision add one byte to (T2,T1)
	GHI T1\ ADCI 0\ PHI T1	; ...
	GLO T2\ ADCI 0\ PLO T2	; ...
	GHI T2\ ADCI 0\ PHI T2	; ...
	LBR	DECNQ0		; keep trying for more digits
DECNQ1:	SEX SP\ IRX\ POPQ(P3,P4); restore P3 and P4 
	RETURN			; and we're finished


;++
;   This routine converts the 32 bit unsigned value in the register pair
; (T2,T1) to ASCII decimal and types it out on the console.  A field width can 
; optionally be specified, and the output will be padded with leading spaces
; if necessary.  This is handy for lining up columns in the partition table,
; for example.
;
;CALL:
;	<(T2,T1) contain the value to type, and D contains the field width>
;	CALL(TDEC32U)
;
;   Note that P1 thru P4 are used but are saved and restored.  T3 is also used
; and is NOT saved.  T3.0 holds the number of leading spaces to print (this
; is decremented as we extract digits) and T3.1 holds the number of digits
; we have pushed onto the stack so far.
;
;   Fair warning - this takes a significant amount of stack space.  Just pushing
; the four registers, P1..P4, takes 8 bytes.  Added to that are the decimal
; digits we extract - a 32 bit number can have as many as 10 digits.  That's a
; total of 18 bytes of stack space, plus a couple more for calling DIV32 or
; THEX1...
;--
TDEC32U:PLO T3\ LDI 0\ PHI T3	; save the field width
	PUSHR(P1)\ PUSHR(P2)	; save (P2,P1)
	PUSHR(P3)\ PUSHR(P4)	; and (P4,P3)
TDEC320:RLDI(P3,10)\ RCLR(P4)	; put the divisor (10) in (P4,P3)
	CALL(DIV32)		; and divide (T2,T1) by (P4,P3)
	GLO P1\ PUSHD		; save the remainder on the stack
	GHI T3\ DEC T3		; decrement T3.0
	ADI 1\ PHI T3		;  ... and increment T3.1
	QBNZ(T2,T1,TDEC320)	; keep going until (T2,T1) is zero
TDEC321:GLO T3\ SHL		; do we need any leading spaces?
	LBDF	TDEC322		; branch if not
	CALL(TSPACE)		; yes - type one
	GHI T3\ DEC T3\ PHI T3	; and decrement T3.0 w/o affecting T3.1
	LBR	TDEC321		; keep spacing until T3.0 is negative
TDEC322:POPD\ CALL(THEX1)	; recover a digit and type it
	GHI T3\ SMI 1\ PHI T3	; decrement the count of digits pushed
	LBNZ	TDEC322		; and keep looping until we've popped them all
	IRX\ POPR(P4)\ POPR(P3)	; restore (P4,P3)
	POPR(P2)\ POPRL(P1)	; and restore (P2,P1)
	RETURN			; and we're finally done!

	.SBTTL	"Thirty Two Bit Quad Precision Multiply and Divide"

;   This routine performs a 32 bit by 32 bit multiply of the values in register
; pair (T2,T1) by the register pair (P4,P3) to give a 32 bit result in (T2,T1).
; Register pair (P2,P1) are used as a temporary to accumulate the result and
; are destroyed in the process.  Overflow is not detected.
;
;CALL:
;	<COMPUTE (T2,T1) * (P4,P3) -> (T2,T1)>
;	CALL(MUL32)
;
MUL32:	PUSHQ(P2,P1)		; save P2 and P1
	QCLR(P2,P1)		; accumulate the product here
MUL320:	QSHR(P4,P3)		; then shift the multiplier right
	LBNF	MUL321		; skip the add if the multipler LSB was zero
	QADD(P2,P1,T2,T1)	; add the multiplicand to the result
MUL321:	QSHL(T2,T1)		; shift the multiplicand left for next time
	QBNZ(P4,P3,MUL320)	; we can quit when the multiplier is zero
	QCOPY(T2,T1,P2,P1)	; transfer the result to (T2,T1)
	IRX\ POPQ(P2,P1)	; restore P2 and P1
	RETURN			; and we're done


;   And this routine performs a 32 bit by 32 bit division of the values in 
; register pair (T2,T1) by register pair (P4,P3) to give a 32 bit result in
; (T2,T1) and a 32 bit remainder in (P2,P1).  Division by zero is not detected
; (and no guarantees as to the result you'll get!).
;
;CALL:
;	<COMPUTE (T2,T1) / (P4,P3) -> (T2,T1), remainder in (P2,P1)>
;	CALL(DIV32)
;
DIV32:	LDI 33\ PLO BAUD	; keep a loop counter in BAUD.0
	QCLR(P2,P1)		; clear the remainder
	CDF			; ... and the first quotient bit
DIV320:	QSHLC(T2,T1)		; shift dividend MSB -> C, C -> quotient LSB
	DEC BAUD\ GLO BAUD	; decrement the loop counter
	LBZ	DIV322		; we're done when it reaches zero
	QSHLC(P2,P1)		; shift dividend MSB into remainder
	QSUB(P2,P1,P4,P3)	; and try to subtract
	LBL	DIV321		; if it doesn't fit, then restore
	SDF			; it fits - shift a 1 into the quotient
	LBR	DIV320		; and keep dividing
DIV321:	QADD(P2,P1,P4,P3)	; divisor didn't fit - restore remainder
	CDF			; and shift a 0 into the quotient
	LBR	DIV320		; and keep dividing
DIV322:	RETURN			; here when we're done

	.SBTTL	"The End"

	.END

