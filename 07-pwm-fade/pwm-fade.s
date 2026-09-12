; IO registers - IO addresses (IN/OUT/SBI/CBI)
.set PINB, 0x16
.set DDRB, 0x17
.set PORTB, 0x18
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

; SRAM / data space addresses (LDS, STS)
.set RAMSTART, 0x0060
.set RAMEND, 0x025F

.section .text
.org 0x0000

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
rjmp reset ; 0x000A TIMER0_COMPA - Timer/Counter0 Compare Match A
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
  ; configure OC0A (PB0) pin as output
  sbi DDRB, 0

  ; we need to set these bits in TCCR0A to disable OC0A on compare
  ; match, and enable OC0A on at BOTTOM (when TCNT0 == 0x00). Note,
  ; these bits have different meanings depending on the timer mode.
  ;   COM0A1 (TCCR0A[7]) = 1
  ;   COM0A0 (TCCR0A[6]) = 0
  in r16, TCCR0A
  ori r16, 0b10000000
  out TCCR0A, r16

  ; we need to set the waveform generation mode to mode 3, which is
  ; the fast PWM mode where the timer loops around after 0xFF
  ; (rather than a custom compare value in OCR0A like mode 7 does).
  ;   WGM02 (TCCR0B[3]) = 0
  ;   WGM01 (TCCR0A[1]) = 1
  ;   WGM00 (TCCR0A[0]) = 1
  in r16, TCCR0B
  ori r16, 0b00000000
  out TCCR0B, r16 

  in r16, TCCR0A
  ori r16, 0b00000011
  out TCCR0A, r16

  ; set a /8 prescaler. This gives us a TCNT0 increment every 8us
  ; (given a 1MHz system clock). Since we're in mode 3, the timer
  ; wraps around at 0xFF, the PWM waveform period is 256 x 8us =
  ; 2.048ms (~488Hz).
  ;   CS02 (TCCR0B[2]) = 0
  ;   CS01 (TCCR0B[1]) = 1
  ;   CS01 (TCCR0B[0]) = 0
  in r16, TCCR0B
  ori r16, 0b00000010
  out TCCR0B, r16

  ; next, set the output compare register A that will be used to
  ; toggle the output pin OC0A off. Lets choose 0x7F for a 50%
  
  ; duty cycle.
  ldi r16, 0xFF / 2
  out OCR0A, r16

  sei ; enable I-bit

  ret

