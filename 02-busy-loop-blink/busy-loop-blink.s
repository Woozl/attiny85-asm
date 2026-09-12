; I have an LED's anode connected to pin PB4

; these .set directives are just like macros:
; .set <symbol>, <expression>
.set PINB, 0x16
.set DDRB, 0x17
.set PORTB, 0x18

.section .text
.org 0x0000

; First we need to write 1 to bit 4 (DDB4) of the DDRB register
; to set the direction as output
sbi DDRB, 4

; Then, we could toggle the pin on (1) and off (0) by setting the
; PORTB4 bit in the PORTB register

; Turning the pin on:
; sbi PORTB, 4

; Turning the pin off:
; cbi PORTB, 4


; ======= new instructions ======= ;

; sbi - set bit in io register
; sbi A, b
; sets the bth bit of io address A to 1

; cbi - clear bit in io register
; cbi A, b
; clears the bth bit of io address A to 0

; ================================ ;



loop:
  ; instead, if we write a 1 to the bit in the pin input register,
  ; it toggles the output of the pin. This only works when the pin
  ; is in output mode.
  sbi PINB, 4
  rjmp delay ; noop

; our delay code from the last project
delay:
  ldi r18, 42
  outer:
    ldi r17, 31
    middle:
      ldi r16, 255
      inner:
        dec r16
        brne inner
      dec r17
      brne middle
    dec r18
    brne outer
rjmp loop
