#ifndef PROCESS_H
#define PROCESS_H

#include <stdbool.h>

#include "intdefs.h"

struct byte_pattern {
    const u8 *const bytes;
    int byte_len;
    const u8 *const wildcards; // indices of the wildcard bytes
    int wildcards_len;
};

bool process_read_addr(ProcessId process, u64 addr, Address *out);
Address process_scan(u64 process, const struct byte_pattern *pattern,
        Address start, usize scan_size);

#endif