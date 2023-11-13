@echo off
if not exist .build\ (
	md .build
	attrib +H .build
)

clang.exe --target=wasm32 -c -nostdlib -flto -O3 libc/memcmp.c -o .build/memcmp.o
clang.exe --target=wasm32 -c -nostdlib -flto -O3 libc/memcpy.c -o .build/memcpy.o
clang.exe --target=wasm32 -c -nostdlib -flto -O3 libc/strlen.c -o .build/strlen.o
clang.exe --target=wasm32 -c -nostdlib -flto -O3 process.c -o .build/process.o
clang.exe --target=wasm32 -c -nostdlib -flto -O3 kvs.c -o .build/kvs.o
clang.exe --target=wasm32 -c -nostdlib -flto -O3 main.c -o .build/main.o
clang.exe --target=wasm32 -nostdlib -mexec-model=reactor -Wl,--no-entry -Wl,--allow-undefined-file=asr.syms ^
.build/memcmp.o .build/memcpy.o .build/strlen.o .build/process.o .build/kvs.o .build/main.o -o .build/l4d.wasm