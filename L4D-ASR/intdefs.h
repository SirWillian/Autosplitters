#ifndef INTDEFS_H
#define INTDEFS_H

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long long u64;
typedef int i32;
typedef long long i64;

// WASM32 type
typedef u32 usize;

// ASR defs
typedef u32 Address; // 32-bit game
typedef u64 ProcessId;

#endif // INTDEFS_H
