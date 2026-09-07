; lets try to get a value in a general purpose register toggling
; between 0x00 and 0xFF every second using a busy loop to delay

; since the cpu clock is running at 1MHz, we need to execute 1
; million cpu cycles between each toggle. We can use nested loops
; of counters to get to that. Each register can store 256 values
; in its 8 bits, but we also need to keep careful track of how
; many clock cycles each instruction we use takes.



;=== new instructions ===;

; com - one's complement
; com Rd
; Rd <- 0xFF - Rd
; basically it just flips all the bits

; rjmp - relative jump
; rjmp k
; PC <- PC + k + 1
; we use the labels here and the assembler knows how to convert
; that to the correct relative offset

; inc / dec - increment / decrement
; [inc/dec] Rd
; Rd <- Rd [+/-] 1

; brne - branch if not equal
; brne k
; if (Z==0) then PC <- PC + k + 1
; exactly like rjmp but only if the last calculation resulted in
; a zero

;========================; 



.section .text
.org 0x000

ldi r19, 0x00
main:
  com r19
  rjmp delay ; this is really a noop since we go straight into delay


; this delay code uses nested loops to try to get close to 1 second
; total execution time. Cycles per instruction:
; 
; ldi - 1 cycle
; dec - 1 cycle
; brne - 2 cycles if branching, 1 if not
; rjmp - 2 cycles
delay:

;-------------- this block takes 1,000,062 cycles ----------------;
ldi r18, 42
outer:

  ;-------------- this block takes 23,808 cycles -----------------;
  ldi r17, 31
  middle:

    ;-------------- this block takes 765 cycles ------------------;
    ldi r16, 255
    inner:
      dec r16
      brne inner
    ;-------------------------------------------------------------;

    dec r17
    brne middle
  ;---------------------------------------------------------------;

  dec r18
  brne outer
;-----------------------------------------------------------------;

rjmp main
