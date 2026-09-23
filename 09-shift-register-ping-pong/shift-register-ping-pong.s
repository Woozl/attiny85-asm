; Using 8 LEDs wired up to the output of the shift register in a
; line, light up one LED at a time so that it "bounces" back and
; forth over 2 seconds.

; SN74HC595N shift register -> ATtiny85:
;  SRCLK (pin 11) -> PB2 / USCK (pin 7)
;  SER (pin 14)   -> PB1 / DO (pin 6)
;  RCLK (pin 12)  -> PB4 (pin 3)

; IO registers - IO addresses (IN/OUT/SBI/CBI)
.set PINB, 0x16
.set DDRB, 0x17
.set PORTB, 0x18
.set SPL, 0x3D
.set SPH, 0x3E
.set SREG, 0x3F
.set USIBR, 0x10
.set USIDR, 0x0F
.set USISR, 0x0E
.set USICR, 0x0D
.set TCCR0A, 0x2A
.set TCCR0B, 0x33
.set GTCCR, 0x2C
.set TCNT0, 0x32
.set OCR0A, 0x29
.set OCR0B, 0x28
.set TIMSK, 0x39
.set TIFR, 0x38

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
rjmp timer ; 0x000A TIMER0_COMPA - Timer/Counter0 Compare Match A
rjmp reset ; 0x000B TIMER0_COMPB - Timer/Counter0 Compare Match B
rjmp reset ; 0x000C WDT          - Watchdog Time-out
rjmp reset ; 0x000D USI_START    - USI START
rjmp reset ; 0x000E USI_OVF      - USI Overflow

reset:
  ldi r16, hi8(RAMEND)
  out SPH, r16
  ldi r16, lo8(RAMEND)
  out SPL, r16
  
  rcall main

  end:
    rjmp end

main:
  ; ======== PIN CONFIG ======== ;
  ; set DO, USCK, and PB4 as output:
  in r16, DDRB
  ori r16, 0b00010110
  out DDRB, r16

  ; ======== USI CONFIG ======== ;
  ; 3-Wire Mode
  ;   USIWM (USICR[5:4]) = 01
  ; Shift on USCK edge postive edge 
  ;   USICS (USICR[3:2]) = 10
  in r16, USICR
  ori r16, 0b00011000
  out USICR, r16

  ; ======= TIMER CONFIG ======= ;
  ; Mode of operation: Clear Timer on Compare Match (CTC)
  ;   WGM02 (TCCR0B[3]) = 0
  ;   WGM01 (TCCR0A[1]) = 1
  ;   WGM00 (TCCR0A[0]) = 0
  in r16, TCCR0B
  ori r16, 0b00000000
  out TCCR0B, r16
  
  in r16, TCCR0A
  ori r16, 0b00000010
  out TCCR0A, r16
  
  ; Set a clk_i/o / 8 prescaler:
  ;   CS02 (TCCR0B[2]) = 0
  ;   CS01 (TCCR0B[1]) = 1
  ;   CS01 (TCCR0B[0]) = 0
  in r16, TCCR0B
  ori r16, 0b00000010
  out TCCR0B, r16

  ; 8us/timer tick, compare match after 125 ticks
  ; 125 * 8us = interrupt every 1ms
  ldi r16, 124
  out OCR0A, r16

  ; enable the interrupt for when TCNT0 == OCR0A
  ;   OCIE0A (TIMSK[4]) = 1
  in r16, TIMSK
  ori r16, 0b00010000
  out TIMSK, r16

  ; ===== INITIAL VALUES ===== ;
  ldi r18, 0         ; delay counter 
  ldi r20, 0b00000001 ; light position
  ldi r19, 1         ; light direction (1 = left, -1 = right)

  ; === GLOBAL INT ENABLE ==== ;
  sei

  ; continuously shift out the value in r20 as fast as the processor
  ; allows. The timer interrupt will update r20 at the appropriate 
  ; timing.
  loop:
    out USIDR, r20
    
    ; we need to toggle USITC 16 times so we get 8 positive clock edges
    ldi r16, 16
    shift:
      ; toggle clock port pin
      ;   USITC (USICR[0]) = 1
      in r17, USICR
      ori r17, 0b00000001 
      out USICR, r17 

      dec r16
      brne shift 

    ; pulse the latch pin
    sbi PINB, 4
    sbi PINB, 4

    rjmp loop

  ret

; this interrupt fires every 1ms. We want to move the LED by one
; position every ~143 ms, so lets keep that count in r18
timer:
  ; we need to push SREG onto the stack because the main subroutine
  ; is using a dec/brne pair and this interrupt could execute between
  ; those instructions and cause an incorrect shift out once it returns
  in r21, SREG
  push r21

  inc r18

  cpi r18, 143
  breq timer_match
  
  rjmp timer_return ; no match, return from interrupt

  timer_match:
    ldi r18, 0 ; reset counter

    ; if r19 is 1, left shift, if it's -1, right shift
    cpi r19, 1
    breq left_shift

    cpi r19, -1
    breq right_shift

    left_shift:
      ldi r19, 1
      cpi r20, 0b10000000
      breq right_shift
      lsl r20
      rjmp timer_return

    right_shift:
      ldi r19, -1
      cpi r20, 0b00000001
      breq left_shift
      lsr r20
      rjmp timer_return

  timer_return:
    pop r21
    out SREG, r21
    reti
