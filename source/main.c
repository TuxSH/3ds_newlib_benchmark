#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <3ds.h>
#include "funcs.h"

#define BUFSIZE (30u << 20)
#define NUMMB   1u

typedef void *(*TestFunc)(void *restrict, const void *restrict, size_t);
typedef void *(*TestFuncFill)(void *restrict, int, size_t);

u8 *s_buffer;

//bool __ctru_speedup = true;
extern u32 __ctru_linear_heap_size;

void benchmark(const char *name, TestFunc f)
{
    GSPGPU_FlushDataCache(s_buffer, BUFSIZE);
    s_buffer[(NUMMB << 20) + 0x5000] = 0x37;
    u64 t0 = svcGetSystemTick();
    f(s_buffer + 1, 1+ s_buffer + (NUMMB<<20), NUMMB << 20);
    u64 t1 = svcGetSystemTick();
    u64 dt = t1 - t0;
    u64 speed = 1024 * 1ull * SYSCLOCK_ARM11 * NUMMB / dt;
    if (s_buffer[0x5000] != 0x37)
        printf("oops\n");
    printf("%s: %llu KiB/s\n", name, speed);
}

void benchmarkFill(const char *name, TestFuncFill f)
{
    GSPGPU_FlushDataCache(s_buffer, BUFSIZE);
    u64 t0 = svcGetSystemTick();
    f(s_buffer+1, 0xCC, NUMMB << 20);
    u64 t1 = svcGetSystemTick();
    u64 dt = t1 - t0;
    u64 speed = 1024 * 1ull * SYSCLOCK_ARM11 * NUMMB / dt;
    if (s_buffer[0x5000] != 0xCC)
        printf("oops\n");
    printf("%s: %llu KiB/s\n", name, speed);
}

int main(int argc, char* argv[])
{
    gfxInitDefault();
    consoleInit(GFX_TOP, NULL);

    svcKernelSetState(10, 0);
    s_buffer = linearMemAlign(BUFSIZE, 0x1000);
    //s_buffer = (u8 *)(osConvertVirtToPhys(s_buffer) | 0x80000000);
    //s_buffer = (u8 *)0x9FF00000;
    printf("Hello, world!\n");
    printf("lin heap size is %lx\n", __ctru_linear_heap_size);

    if (s_buffer == NULL)
        printf("Failed to allocate\n");
    else
    {
        benchmark("newlib memcpy", memcpy);
        benchmark("armv6 optimized memcpy", xmemcpy);
        benchmark("armv4 optimized memcpy", xmemcpy_v4);

        //benchmarkFill("newlib memset", memset);
        //benchmarkFill("armv6 optimized memset", xmemset);
    }


    // Main loop
    while (aptMainLoop())
    {
        gspWaitForVBlank();
        gfxSwapBuffers();
        hidScanInput();

        // Your code goes here
        u32 kDown = hidKeysDown();
        if (kDown & KEY_START)
            break; // break in order to return to hbmenu
    }

    gfxExit();
    return 0;
}
