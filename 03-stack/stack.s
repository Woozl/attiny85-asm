.section .text
.org 0x0000

.set SPH, 0x3E ; stack pointer high (only bits 0:1 used on ATtiny85)
.set SPL, 0x3D ; stack pointer low
.set RAMEND, 0x025F ; the last SRAM address

; first, load the high byte of RAMEND into r16, and then use OUT to
; load it into the SPH data register:
ldi r16, hi8(RAMEND)
out SPH, r16

; do the same for the low byte
ldi r16, lo8(RAMEND)
out SPL, r16

; we use OUT instead of STS (store direct to data address) since 
; OUT stores using the IO register relative addresses. If we used
; STS, we'd have to use the actual data memory address, which are
; offset by 0x20, so the data memory address for SPH and SPL are
; actually 0x5E and 0x5D, respectively. Usually the IO registers
; are written via their relative address in the docs, so we should
; just use OUT/IN when working with the IO registers.

; now that we have the stack pointer initialized, we can use the
; stack to improve our program flow.

; ======= new instructions ======= ;

; rcall - relative subroutine call
; rcall k
; PC <- PC + k + 1 (we go to the instruction at address k)
; STACK <- PC + 1  (we save the address after the rcall to the
;                   stack so we can return to it)
; SP <- SP - 2     (decrement the stack pointer since we added
;                   the return address to it)

; this is a 16-bit opcode that does a few things for us. it acts
; like the rjmp command in that it updates the program counter to
; move execution to another location in program memory. However,
; it also uses the stack to "remember" where we came from. It does
; this by pushing the address of the instruction right after the
; rcall to the stack (updating and updating the stack pointer to
; match). Now, we can use the ret instruction to return execution
; to right after where we called into the subroutine.

; Note that the AVR instruction set also specifies a normal call
; 32-bit instruction. This isn't necessary on the ATtiny85 since
; the 12-bit rcall address k is able to address all 4096 (+/-2048)
; addresses in the 8Kb program memory.



; ret - return from subroutine
; ret
; PC <- STACK
; SP <- SP + 2

; the complement to rcall. It will pop the top value off the stack
; and set the PC to that value to return execution to the calling
; site.

; ================================ ;


ldi r16, 0x01
ldi r17, 0x02
rcall add

; hold the program here once it's finished
end:
  rjmp end

add:
  add r16, r17 
  ret

