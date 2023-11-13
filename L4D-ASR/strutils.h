#ifndef STRUTILS_H
#define STRUTILS_H

#include "asr.h"
#include "intdefs.h"

#define string(str) str, sizeof(str) - 1
#define print(message) runtime_print_message(string(message))
#define printval(val) do { \
    char printbuf[sizeof(#val) + 4 + sizeof(val)*2] = #val ": "; \
    hexformat(printbuf, sizeof(#val) + 1, (u64)val, sizeof(val)); \
    runtime_print_message(string(printbuf)); \
} while(0)

static void hexformat(char *buf, int off, u64 val, int bytes) {
    buf[off] = '0'; buf[off+1] = 'x';
    for (int i = bytes*2; i > 0; i--) {
        int remaining = val % 16;
        char digit = remaining >= 10 ? 'A' + remaining - 10 : '0' + remaining;
        buf[off + 1 + i] = digit;
        val /= 16;
    }
}

#endif
