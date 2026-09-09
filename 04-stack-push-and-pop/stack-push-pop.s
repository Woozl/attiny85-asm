.section .text
.org 0x0000

.set SPH, 0x3E
.set SPL, 0x3D
.set RAMEND, 0x025F

ldi r16, hi8(RAMEND)
out SPH, r16
ldi r16, lo8(RAMEND)
out SPL, r16

; we want this 42 - 21 calculation to work, but we're calling
; into the subroutine before we calculate the results with the
; sub command. If the subroutine uses the registers in use by
; the calling code, it's said to "clobber" those values. To
; solve this, we can use the "push" and "pop" command in the 
; subroutine to push values from registers onto the stack and
; pop them off at the end to restore them for the calling code.

; ======== new instructions ======== ;

; push - push register on stack
; push Rd
; STACK <- Rd
; SP <- SP - 1

; pop - pop register from stack
; pop Rd
; Rd <- STACK
; SP <- SP + 1

; ================================== ;

ldi r16, 42
ldi r17, 21

; after this instruction, the stack will have the the address
; of the "sub r16, r17" instruction on it so "ret" can return
; control flow when the subroutine is over.
rcall subroutine

sub r16, r17

end:
  rjmp end

subroutine:
  push r16 ; stack: { addr(sub r16, r17), 42 }
  push r17 ; stack: { addr(sub r16, r17), 42, 21 }

  ldi r16, 100 ; clobbers 42 in r16
  ldi r17, 100 ; clobbers 21 in r17 
  add r16, r17
  ; by this point, the original values in r16 and r17 are gone
  ; and replaced with 200 (r16) and 100 (r17)

  
  ; we can restore them by popping them off the stack. Note that
  ; we must do this in the exact opposite direction we pushed
  ; them on.
  pop r17 ; stack: { addr(sub r16, r17), 21 }
  pop r16 ; stack: { addr(sub r16, r17) }

  ; the ret instruction pops a value from the stack (which is
  ; hopefully the correct address!) and sets the program counter
  ; to it to return execution
  ret ; stack: { }
