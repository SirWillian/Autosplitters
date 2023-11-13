#include "intdefs.h"
#include "process.h"
#include "strutils.h"

bool process_read_addr(ProcessId process, u64 addr, Address *out) {
    return process_read(process, addr, (u8 *)out, sizeof(Address));
}

#define CHUNK_SIZE 0x1000
// Adapted from mlugg's one-pass algorithm
Address process_scan(u64 process, const struct byte_pattern *pattern,
        Address start, usize scan_size) {
    u8 chunk[CHUNK_SIZE];
    u64 mask[256]; // each possible value in a byte has an associated mask
    const u8 *const wild = pattern->wildcards;
    int pattern_len = pattern->byte_len, wildcards_len = pattern->wildcards_len;

    // The number of bits on the "mask" table elements needs to be at least
    // pattern_len + 1 long
    if (pattern_len >= sizeof(mask[0])*8) {
        print("ERROR: pattern too long\n");
        return 0;
    }

    // Compute byte mask from wildcards, init table then set remaining bits.
    // The mask is computed so that a byte that appears on e.g. the 5th and 7th
    // positions won't clear bits 5 and 7. Wildcard positions should also never
    // clear bits (i.e. if the 2nd position of the pattern is a wildcard, every
    // byte mask should allow bit 2 to remain set when applied). Ideally this
    // mask should be computed in compile time, but that's tough to do in C
    typeof(mask[0]) mask_initval = 0;
    for (int i = 0; i < wildcards_len; i++) mask_initval |= 2LL << wild[i];
    for (int i = 0; i < 256; i++) mask[i] = mask_initval;
    for (int i = 0, j = 0; i < pattern_len; i++) {
        if (__builtin_expect(j < wildcards_len && wild[j] == i, 0)) {
            j++;
            continue;
        }
        mask[pattern->bytes[i]] |= 2LL << i;
    }

    typeof(mask[0]) state = 0;
    Address end = start + scan_size;
    for (u64 p = start; p < end; p += CHUNK_SIZE) {
        int chunk_size = CHUNK_SIZE;
        if (__builtin_expect(p + CHUNK_SIZE > end, 0))
            chunk_size = end - p;
        if (__builtin_expect(!process_read(process, p, chunk, chunk_size), 0))
            return 0;
        // Try to shift bits from LSB to the pattern_len-th bit
        // A bit will only successfully shift to the end if the right sequence
        // of bytes is read. Otherwise, they get cleared by the mask
        for (int i = 0; i < chunk_size; i++) {
            state |= 1;
            state <<= 1;
            state &= mask[chunk[i]];
            if (__builtin_expect(state >> pattern_len, 0))
                return p + i - pattern_len + 1;
        }
    }
    return 0;
}
