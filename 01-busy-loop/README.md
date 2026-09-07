# 01 - Busy Loop

I created this project expecting that I could watch the r19 register
flip once a second in the TUI. Unfortunately, when gdb is controlling
simavr, simavr lets it control the timing, rather than respect the
`-f` frequency flag for real-time simulation. However, we can still
use gdb with a breakpoint on main to ensure the the loop logic is
working, which it is.

I think the next project will use this code but toggle a GPIO pin
rather than r19, so we can run it on the hardware and ensure correct
timing.
