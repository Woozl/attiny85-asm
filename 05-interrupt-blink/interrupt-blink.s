; IO registers
.set SPL, 0x3D
.set SPH, 0x3E
.set SREG, 0x3F
.set TCCR0A, 0x2A ; Timer/Counter Control Register A
.set TCCR0B, 0x33 ; Timer/Counter0 Control Register
.set GTCCR, 0x2C ; General Timer/Counter Control Register 
.set TCNT0, 0x32 ; Timer/Counter Register
.set OCR0A, 0x29 ; Output/Compare Register A
.set OCR0B, 0x28 ; Output/Compare Register B
.set TIMSK, 0x39 ; Timer/Counter Interrupt Mask Register
.set TIFR, 0x38 ; Timer/Counter Interrupt Flag Register

.set RAMEND, 0x025F

.section .text
.org 0x0000

; interrupt vector table at the start of program memory. The hardware 
; always points the program counter at these locations when an enabled
; interrupt occurs
rjmp reset ; 0x0000 RESET
rjmp reset ; 0x0001 INT0         - External Interrupt Request 0
rjmp reset ; 0x0002 PCINT0       - Pin Change Interrupt Request 0
rjmp reset ; 0x0003 TIMER1_COMPA - Timer/Counter1 Compare Match A
rjmp reset ; 0x0004 TIMER1_OVF   - Timer/Counter1 Overflow
rjmp reset ; 0x0005 TIMER0_OVF   - Timer/Counter0 Overflow
rjmp reset ; 0x0006 EE_RDY       - EEPROM Ready
rjmp reset ; 0x0007 ANA_COMP     - Analog Comparator
rjmp reset ; 0x0008 ADC          - ADC Conversion Complete
rjmp reset ; 0x0009 TIMER1_COMPB - Timer/Counter1 Compare Match B
rjmp timer ; 0x000A TIMER0_COMPA - Timer/Counter0 Compare Match A
rjmp reset ; 0x000B TIMER0_COMPB - Timer/Counter0 Compare Match B
rjmp reset ; 0x000C WDT          - Watchdog Time-out
rjmp reset ; 0x000D USI_START    - USI START
rjmp reset ; 0x000E USI_OVF      - USI Overflow

reset:
  ; set up stack pointer
  ldi r16, hi8(RAMEND)
  out SPH, r16
  ldi r16, lo8(RAMEND)
  out SPL, r16
  
  ; call into main subroutine
  rcall main

  end:
    rjmp end

main:
  ; we're going to use Timer/Counter0

  ; Mode of operation: Clear Timer on Compare Match (CTC)
  ;   This means when the value of the counter in TCNT0 == OCR0A, it
  ;   triggers an interrupt
  
  ; To set CTC mode we need to set these bits (see table 11-5):
  ;   WGM02 (TCCR0B[3]) = 0
  ;   WGM01 (TCCR0A[1]) = 1
  ;   WGM00 (TCCR0A[0]) = 0

  in r16, TCCR0B
  ori r16, 0b00000000
  out TCCR0B, r16
  
  in r16, TCCR0A
  ori r16, 0b00000010
  out TCCR0A, r16
  
  ; Next, we set a clk_i/o / 8 prescaler (see table 11-6):
  ;   CS02 (TCCR0B[2]) = 0
  ;   CS01 (TCCR0B[1]) = 1
  ;   CS01 (TCCR0B[0]) = 0

  in r16, TCCR0B
  ori r16, 0b00000010
  out TCCR0B, r16

  ; next, we need to write a value to the output compare register
  ; that continuously gets compared to the value of the counter

  ldi r16, 124 ; see comment in interrupt for why we choose 124
  out OCR0A, r16

  ; enable the interrupt for when TCNT0 == OCR0A
  ;   OCIE0A (TIMSK[4]) = 1

  in r16, TIMSK
  ori r16, 0b00010000
  out TIMSK, r16

  ; finally, enable the global interrupts (I-bit) in SREG

  sei ; special global interrupt enable instruction
  
  ldi r16, 0

  ret

timer:
  inc r16

  reti
