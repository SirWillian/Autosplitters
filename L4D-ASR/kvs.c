#include <stdbool.h>

#include "asr.h"
#include "intdefs.h"
#include "kvs.h"

#include "./libc/libc.h"

static Address kvs_strings;
static ProcessId gamepid;

void kvs_init(ProcessId game_proc, Address str_base) {
    kvs_strings = str_base;
    gamepid = game_proc;
}

bool kvs_read(Address kvs_addr, struct KeyValues *out) {
    return process_read(gamepid, kvs_addr, (u8 *)out, sizeof(struct KeyValues));
}

bool kvs_symtostr(int sym, char *buf, int buf_len) {
    return process_read(gamepid, kvs_strings + sym, (u8 *)buf, buf_len);
}

bool kvs_streq(struct KeyValues *kv, const char *str, int str_len) {
    char strval[256]; // arbitrary size
    if (!process_read(gamepid, kv->strval, (u8 *)strval, 256)) return false;
    return !memcmp(str, strval, str_len + 1); // +1 for nul terminator
}

bool kvs_getsubkey(struct KeyValues *kv, const char *key, int key_len,
        struct KeyValues *out) {
    struct KeyValues tmp;
    for (Address addr = kv->child; addr; addr = tmp.next) {
        if (!kvs_read(addr, &tmp)) return false;
        char kv_key[256]; // arbitrary size. kv keys can be of any length
        if (!kvs_symtostr(tmp.keysymbol, kv_key, sizeof(kv_key))) return false;
        if (!memcmp(key, kv_key, key_len + 1)) {
            *out = tmp;
            return true;
        }
    }
    return false;
}
