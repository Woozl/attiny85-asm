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

; SRAM / data space addresses (STS, LDS)
.set RAMSTART, 0x0060
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

  ; next, we need to write a value to the output compare register that
  ; continuously gets compared to the value of the counter
  ldi r16, 124 ; see comment in interrupt for why we choose 124
  out OCR0A, r16

  ; enable the interrupt for when TCNT0 == OCR0A
  ;   OCIE0A (TIMSK[4]) = 1
  in r16, TIMSK
  ori r16, 0b00010000
  out TIMSK, r16

  ; clear our 1000ms counter before enabling interrupts
  rcall clear_counter

  ; finally, enable the global interrupts (I-bit) in SREG
  sei ; special global interrupt enable instruction

  ; set pin PB4 as output
  sbi DDRB, 4

  ret

; this timer interrupt routine will fire every 1ms:
;   clk_cpu = 1MHz (I have the CKDIV8 fuse set, which divides
;                   the 8MHz clock by 8, to give us 1MHz)
;   
; we set the timer0 clock prescale to clk_cpu / 8. This means the timer
; will increment every 8us. We want this interrupt subroutine to run every
; 1ms, so we have the OCR0A set to reset at 124, giving us 125 clock ticks
;   125 ticks * 8ns = 1000ns = 1ms
;
; Each time this subroutine runs, we can increment a counter to keep track
; of the number of elapsed milliseconds. When the timer reaches 999, we know
; 1 second has passed and can toggle the LED. Since a single register can
; only hold 8 bits, we can split it between two address in RAM, letting us
; store a combined 16-bit value.
timer:
  push r16
  push r17
  push r18
  push r19

  ; define 0 and 1 constants in register for add / adc instructions.
  ; Normal increment won't work because it doesn't set the carry (C) bit.
  ; We need to have a zero constant so we can use adc (Rd <- Rd + Rr + C)
  ldi r17, 0
  ldi r18, 1

  ; add 1 to the [RAMSTART + 1 : RAMSTART] combo 
  ; RAMSTART + 1 (0x0061) is the high byte
  ; RAMSTART (0x0060) is the low byte

  lds r16, RAMSTART ; get low byte from SRAM
  add r16, r18 ; add 1 to it (will set C bit if overflows)
  sts RAMSTART, r16 ; store incremented low byte back to SRAM
  lds r16, RAMSTART + 1 ; load high byte from SRAM
  adc r16, r17 ; increment the high byte if low byte overflowed
  sts RAMSTART + 1, r16 ; store high byte back to SRAM 
 
  ; load our compare value (999) to [r19:r18] combo using assember helpers
  ldi r19, hi8(999)
  ldi r18, lo8(999)

  ; load our current count
  lds r17, RAMSTART + 1
  lds r16, RAMSTART

  ; subtracts Rd - Rr and sets Z bit if result is 0 (doesn't modify registers)
  cp r16, r18
  ; same as cp but takes into account carry bit: Rd - Rr - C
  cpc r17, r19
  ; if the timer reached 999, reset it and toggle the led 
  brne noteq
    rcall clear_counter
    rcall toggle_led
  noteq:
  
  pop r19
  pop r18
  pop r17
  pop r16
  reti

; our counter will be in the two lowest available slots in SRAM (0x0060 and
; 0x0061). this subroutine will clear both of those addresses
clear_counter:
  push r16
  ldi r16, 0x00

  sts RAMSTART, r16
  sts RAMSTART + 1, r16

  pop r16
  ret

toggle_led:
  sbi PINB, 4
  ret
