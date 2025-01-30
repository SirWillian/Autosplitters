#include <stdbool.h>

#include "asr.h"
#include "intdefs.h"
#include "kvs.h"

#include "./libc/libc.h"

static Address kvs_strings;
static ProcessId gamepid;
bool iskvv2;

void kvs_init(ProcessId game_proc, Address kvs_obj, Address str_base) {
    Address kvs_vt;
    process_read(game_proc, kvs_obj, (u8 *)&kvs_vt, sizeof(Address));
    u8 first_func_byte;
    process_read(game_proc, kvs_vt + 20, &first_func_byte, 1);
    iskvv2 = first_func_byte != 0xC2 || first_func_byte != 0xC3;
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
    for (Address addr = iskvv2 ? kv->v2.child : kv->v1.child; addr;
            addr = iskvv2 ? tmp.v2.next : tmp.v1.next) {
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
