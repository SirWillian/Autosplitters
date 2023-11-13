#ifndef LIBC_H
#define LIBC_H
// We are compiling with -nostdlib, so I'm borrowing some implementations
// from openbsd

#include <stddef.h>

int memcmp(const void *s1, const void *s2, unsigned long n);
void *memcpy(void *s1, const void *s2, unsigned long n);
size_t strlen(const char *str);

#endif