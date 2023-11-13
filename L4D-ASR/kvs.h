#ifndef KVS_H
#define KVS_H

#include <stdbool.h>

#include "intdefs.h"

struct KeyValues {
	int keysymbol;
	Address strval;
	Address wstrval;
	union {
		int ival;
		float fval;
		Address pval;
	};
	char datatype;
	bool hasescapes;
	bool evalcond;
	//char unused;
	//struct KeyValues *next, *child, *chain;
    Address next, child, chain;
};

void kvs_init(u64 game_proc, Address str_base);
bool kvs_read(Address kvs_addr, struct KeyValues *out);
bool kvs_symtostr(int sym, char *buf, int buf_len);
bool kvs_streq(struct KeyValues *kv, const char *str, int str_len);
bool kvs_getsubkey(struct KeyValues *kv, const char *key, int key_len,
        struct KeyValues *out);
bool kvs_getnext(struct KeyValues *kv, struct KeyValues *out);

#endif
