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
rjmp pwm   ; 0x000A TIMER0_COMPA - Timer/Counter0 Compare Match A
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
  ; configure OC0B (PB1) pin as output
  sbi DDRB, 1

  ; this time, we're going to use OC0B as output, so we set the
  ; appropriate bits in TCCR0A so the hardware tells the OC0B pin
  ; to go low when there's a match (goes high when count is 0x00).
  ;   COM0B1 (TCCR0A[5]) = 1
  ;   COM0B0 (TCCR0A[4]) = 0
  in r16, TCCR0A
  ori r16, 0b00100000
  out TCCR0A, r16

  ; this time, we're going to use fast PWM mode 7. This means that
  ; the counter will count from 0x00 to OCR0A (rather than 0xFF in
  ; mode 3). This gives us a bit more control over the period of
  ; of the PWM waveform (we want to target 1ms). This will let us
  ; use OCR0A for double duty--to generate a consistent 1ms 
  ; interrupt routine at the end of every cycle.
  ;   WGM02 (TCCR0B[3]) = 1
  ;   WGM01 (TCCR0A[1]) = 1
  ;   WGM00 (TCCR0A[0]) = 1
  in r16, TCCR0B
  ori r16, 0b00001000
  out TCCR0B, r16 

  in r16, TCCR0A
  ori r16, 0b00000011
  out TCCR0A, r16

  ; set OCR0A to 124. This gives the timer 125 ticks per period.
  ldi r16, 124 
  out OCR0A, r16

  ; set a /8 prescaler. This gives us a TCNT0 increment every 8us
  ; (given a 1MHz system clock). Since we're in mode 7 and the timer
  ; wraps around at 124 (the value we just put in OCR0A), the PWM 
  ; waveform period is 125 x 8us = 1ms (1KHz).
  ;   CS02 (TCCR0B[2]) = 0
  ;   CS01 (TCCR0B[1]) = 1
  ;   CS01 (TCCR0B[0]) = 0
  in r16, TCCR0B
  ori r16, 0b00000010
  out TCCR0B, r16

  ; now lets use our other compare register (OCR0B) to set the duty
  ; cycle. We can set this to any value between 0 and 124 (OCR0A).
  ; Let's begin it at 0 for a 0% duty cycle
  ldi r16, 0
  out OCR0B, r16

  ; enable the interrupt on Output Compare A match (at the end of
  ; the PWM period)
  ;   OCIE0A (TIMSK[4]) = 1
  in r16, TIMSK
  ori r16, 0b00010000
  out TIMSK, r16

  ; store a global value indicating if the duty cycle is increasing
  ; or decreasing. Since we're starting the duty cycle at 0%, it's
  ; starting out increasing.
  ldi r17, 1

  ; also store a counter for the pwm subroutine to keep track of 
  ; if it needs to increment OCR0B or not (it only does it every
  ; 8th call)
  ldi r18, 0

  sei ; enable I-bit

  ret

; this interrupt gets called every time the timer reaches it's 125
; tick (every 1ms). The goal is to have the duty cycle start at 0%,
; fade up to 100% over 1 second, and back down to 0% over the next
; second. If we want the fade to happen linearly, we need to inc/dec
; OCR0B by 1 every 8ms. 
pwm:
  ; first, check if we're on the 8th iteration of this subroutine
  cpi r18, 7
  brne not_8th_iter
  ; if we got past the above rjmp, we're on the 8th iteration:
  ;   1) move the duty cycle
  ;   2) clear the iteration counter (set r18 to 0)
  ;   3) exit the subroutine

  ; ======= moving duty cycle ======= ; 
  in r16, OCR0B

  ; if OCR0B is 0, we need to set the direction (r17) positive
  ; before adding
  cpi r16, 0
  breq set_increasing

  ; if OCR0B is OCR0A, we need to set the direction (r17) negative
  ; before adding
  in r19, OCR0A
  cp r16, r19
  breq set_decreasing

  ; if OCR0B was any other value, no need to change r17 before adding
  rjmp add_to_ocr0b

  set_increasing:
  ldi r17, 1
  rjmp add_to_ocr0b

  set_decreasing:
  ldi r17, -1
  rjmp add_to_ocr0b

  add_to_ocr0b:
  add r16, r17 ; +/- 1 to OCR0B
  out OCR0B, r16
  ; ================================= ; 

  clr r18 ; clear the iteration counter
  rjmp pwm_end ; exit the subroutine

  ; if we weren't at the 8th iteration of the loop (r18 != 7)
  ; we just need to increase the iteration count and then leave the
  ; interrupt routine
  not_8th_iter:
  inc r18

  pwm_end:
  reti
