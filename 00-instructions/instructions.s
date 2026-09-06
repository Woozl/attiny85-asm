; this assembly assumes we're not using avr-libc's startup code (crt)
; and just writing to the bare metal ourselves. This means we don't
; have the C code doing the following:
;   - setting up the vector interrupt table at the beginning of
;     program memory
;   - initializing the stack pointer register with the end of SRAM
;     (RAMEND).
;   - zeroing out the .bss section of our data SRAM
;   - clearing the "zero register" (r1)
;   - watchdog handling
;   - copying .data to data section

; instructions with "." in front of them are assembler directives.
; Since I'm using avr-gcc to compile, we have to use the GCC style
; directives. The below shows the original AVR assembler directives
; and then the equivalent gcc style.

; .cseg indicates the following instructions are a code segment and
; belong in the program memory. The corresponding .dseg directive
; is a data segment and indicates instructions will go in the SRAM
; data section. Remember the AVR chip are Harvard architecture with
; seperate data and program memory.

; gcc equivalents:
;   .cseg -> .section .text 
;   .dseg -> .section .bss

; .orig will set the location of the next instruction in program/data
; memory depending on which segment type we're in. Note that for this
; program, we're ignoring setting up the interrupt table at the top
; of the program memory. If we need to use interrupts, we'd have to 
; start our program at address 0x000F.

; gcc equivalent:
;   .orig -> .org

.section .text
.org 0x0000

; ldi - load immediate (16-bit instruction)
; ldi Rd, K
; Rd (destination register) <- K (8 bit constant value)
ldi r16, 16
ldi r17, 16
add r16, r17

