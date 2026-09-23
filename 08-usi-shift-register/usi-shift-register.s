; SN74HC595 shift register -> ATtiny85:
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
  ldi r16, hi8(RAMEND)
  out SPH, r16
  ldi r16, lo8(RAMEND)
  out SPL, r16
  
  rcall main

  end:
    rjmp end

main:
  ; set DO, USCK, and PB4 as output:
  in r16, DDRB
  ori r16, 0b00010110
  out DDRB, r16

  ; 3-Wire Mode
  ;   USIWM (USICR[5:4]) = 01
  ; Shift on USCK edge postive edge 
  ;   USICS (USICR[3:2]) = 10
  in r16, USICR
  ori r16, 0b00011000
  out USICR, r16

  ; infinite loop, write 00010010 to the shift register
  loop:
    ldi r16, 0b00010010
    out USIDR, r16
    
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

