# 00 - Instructions

This code performs a very simple add instruction. The next few programs probably
will not be very useful, but we can use a simulator / debugger to look at the
contents of the register to make sure it's working.

## Compiling the assembly

```sh
avr-gcc -mmcu=attiny85 -nostdlib -o instructions.elf instructions.s
```

This just converts the `instructions.s` file to a elf file. The elf file is a
binary file format but still contains some debug and additional information.

The `-mmcu` flag gives the assembler/linker some additional information to give
us an error if we tried to use a command that's only available on other AVR chips
(like `mul` for hardware multiplication). It also knows the flash size so it can
tell us if the program is too large.

The `-nostdlib` says to not use the C preprocessor CRT library. See the comment
in [instructions.s](./instructions.s) for more info.

We could disassemble the elf using this command:

```sh
avr-objdump -d instructions.elf
```

Resulting in this output:

```sh
instructions.elf:     file format elf32-avr


Disassembly of section .text:

00000000 <__ctors_end>:
   0:   00 e1           ldi     r16, 0x10       ; 16
   2:   10 e1           ldi     r17, 0x10       ; 16
   4:   01 0f           add     r16, r17
```


### Breaking down the opcode for the first LDI command:

From the AVR instruction docs, the LDI command opcode is:

```
1110 KKKK dddd KKKK
```

Where `K` is the 8-bit constant value and `d` is the register address.

We can see the memory at the `0x0000` address is `00 e1`. AVR is little-endian,
so the least-significant byte is stored at the lower memory address. Thus, to
get the actual opcode, we swap the 2 bytes to get `e1 00`. If we expand this
out:

```
1110 0001 0000 0000
1110 KKKK dddd KKKK
```

We see that the K constant matches the `0x10` written in the assembly, and the
data register `r16` maps to `0000`

Note that this makes sense why `ldi` can only access the upper 16 registers
(r16-r31). It only has 4 bits to address 16 registers, so it treats the `dddd`
as an offset starting from `r16`.



We can now take the elf file and convert it to Intel HEX, which is the 1-to-1
representation of the memory layout on the chip:

```sh
avr-objcopy -O ihex instructions.elf instructions.hex
```


## Running this program in the simulator

I'm using the [simavr](https://github.com/buserror/simavr) AVR simulator, which
has support for simulating the ATtiny85 and can read either the hex or elf files
(elf is preferred since it can use the debug info). We can set up the simulator
by running:

```sh
simavr -m attiny85 -g instructions.elf
```

That will listen for the gdb connection on port 1234. In a new terminal, start
gdb:

```sh
avr-gdb instructions.elf
```

This should throw you into gdb's interactive terminal. Issue this command to
connect to the `simavr` server running in the first terminal:

```
(gdb) target remote :1234
```

Now, load the elf's `.text` section into the simulator's flash memory:

```
(gdb) load
```

It should say it loaded 6 bytes at the beginning of program memory. Now, we can
step through our program with the `stepi` (step instruction) command, and view
the contents of the registers we're interested in using the `info registers r16 
r17` command:

```
(gdb) info registers r16 r17
r16            0x0                 0
r17            0x0                 0

(gdb) stepi
0x00000002 in __trampolines_start ()
(gdb) info registers r16 r17
r16            0x10                16
r17            0x0                 0

(gdb) stepi
0x00000004 in __trampolines_start ()
(gdb) info registers r16 r17
r16            0x10                16
r17            0x10                16

(gdb) stepi
0x00000006 in ?? ()

(gdb) info registers r16 r17
r16            0x20                32
r17            0x10                16
```
