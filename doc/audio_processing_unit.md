# RISCBoy Audio Processing Unit (APU)

Goals:

- Resource budget: 100 LUTs (excluding system interface and digital DACs), two BRAMs
- 48 kHz 8 bit stereo output when running at 36 MHz
- Provide similar capability to an original Gameboy with default microcode
- Be rather more capable with user-supplied microcode
- Easy to use as a dumb wave-out ring buffer interface
- Fun to program

Design is still at the handwaving stage, I might have to adjust features downward or budget upward.

## Memory Architecture

Two 256x16 block RAMs, each with one write port and one read port. This assumes iCE40, but other FPGA block RAMs can support similar partitioning with some waste.

One memory (IRAM) contains the audio generation code. The registers (e.g. 8x16b) are stored at the top of this memory. The other memory (WRAM) contains wave sample tables, user configuration variables which can be used as software-defined control registers, and the core registers are *also* stored at the top of this memory. There is no memory for buffering of audio samples between the APU and the audio DACs: the APU runs in hard real time, with a fixed cycle budget for each audio sample.

Having the registers mirrored to both memories allows two source registers to be fetched in one cycle. The separate read and write port on IRAM allow the next instruction to be fetched on the same cycle that the current instruction's result is written back. So a typical register-to-register instruction will take two cycles:

1. Read both source registers
2. Write back result register, and fetch next instruction

At an ISA level, IRAM is read-only, and WRAM is read-write (using conventional load/store instructions). The system has write-only access to IRAM when the APU is halted, and no access when it is running. The system has read-write access to WRAM at all times, but has lower access priority than the APU, so may stall.

The APU has minimal linked-load store-conditional support on WRAM accesses: if the APU performs a linked load to some address, followed by a conditional store, and the system has written to that address in the intervening cycles, the store is suppressed (NOP'd). The APU is not able to detect that this has happened, and the system has no corresponding mechanism of its own. The use case is for the APU to perform read-modify-writes of some control variable (e.g. decrementing a volume) whilst the system concurrently performs *writes only* on that variable, in which case this ll-sc mechanism resolves the race between the write and the read-modify-write.

## Arithmetic

The APU uses two data types, each stored in a single register:

- 16-bit integers
- Pairs of 8-bit integers (SIMD)

The `88` format is for SIMD processing of stereo audio, and most arithmetic instructions use this format. The `16` format is used where higher precision or larger count is required, e.g. for phase accumulation.

All `88` arithmetic is signed-saturating. 16-bit arithmetic may be signed-saturating, or regular modular arithmetic.

Operations wishlist for 8+8:

- Saturating add (e.g. channel blending)
- 8x0.4 multiply (volume envelope; multiply 8-bit integer by 4-bit fractional in range 0..15/16)
- Some kind of swizzling move

Operations wishlist for 16:

- Signed-saturating add and subtract
- Modular add and subtract
- LFSR (polynomial in second source register; right-shift by 1, XOR masked by shifted-out LSB)

## Control Flow

There are two branch flags:
 - ZH (upper half of result was 0)
 - ZL (lower half of result was 0)

Branches test both flags against "true" or "don't care". So:

- `bxx` always branch
- `bxz` branch if lower half zero
- `bzx` branch if upper half zero
- `bzz` branch if all zeroes

Greater/less-than comparisons are performed with the help of saturating arithmetic.

TBD whether branches will be relative or absolute, but probably no indirect branches (so no procedure calls). We have more instruction slots than we have cycles per sample, so microcode is probably going to be fully unrolled rather than using loops and procedure calls.

## Load/Store Instructions

Only halfword load/stores are supported. Note that WRAM is always halfword-addressed, i.e. if two halfwords are consecutive in memory, the difference between their addresses is 1. The load/store data may represent a single 16-bit value or a pair of 8-bit values.

There are two addressing modes:

- Absolute immediate (loads or stores)
- Immediate with register ring (loads only)

The first is the most common. The entire address is supplied directly by the instruction word. Because we have more instruction slots available than cycles per sample, programs will generally be completely unrolled, so there is little purpose in being able to immediately index a data structure at offsets from a register-resident pointer.

Mnemonics are `ld` and `st`. Additionally there is a linked load, `ldl`, and conditional store, `stc`. `ldl` executes as a normal load, and additionally sets a hidden flag -- the *exclusive* flag -- that is cleared if the system writes to the address that the `ldl` loaded from, or any `stc` is executed. `stc` executes as a normal `st` when the exclusive flag is set (and additionally clears the flag), but executes as a NOP when the flag is clear.

Ok it's time to talk about the other addressing mode. The lower 5 address bits come from the upper 5 bits of a register, and the upper address bits come from an instruction immediate. This is used to index a 32-sample wave table stored in WRAM. The *upper* 5 bits of the register are used, so that the full 16 bits of that register can be used for fractional phase accumulation. Effectively the register is treated as a 5.11 fixed point number. Only a load is provided, and the mnemonic is `ldw`, where the w stands for "WTF".

Probably also some kind of immediate load (`ldi`). 8 bit immediate, same as address size. Ideally, can go to upper, lower or both halves of the destination register.

## Output

An `out` instruction outputs one `88` sample pair to the DACs.

Generally the APU will have finished calculating a sample slightly before the allotted time elapses. When this happens, the APU is stalled until the next audio sample period begins.

The APU runs in hard real time. There is (probably) no buffering of samples in between the APU and the DACs. It might be desirable to add a 1-deep sample buffer externally, for the case where the occasional sample has a longer runtime, e.g. some control update that happens once per 1024 samples, but the APU is designed to not need this in general.

## Interrupts

An `irq` instruction sets the interrupt flag. The system clears the flag to acknowledge the interrupt. Yup that's it.

Main use case is for dumb audio ring buffers with half-empty or quarter-empty interrupts. The audio ring buffer is constructed from multiple stacked 32-sample ring tables, which are addressed in a strictly incrementing fashion.
