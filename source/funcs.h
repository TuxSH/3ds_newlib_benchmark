#pragma once

#include <string.h>

void *xmemcpy(void *restrict dst, const void *restrict src, size_t count);
void *xmemcpy_v4(void *restrict dst, const void *restrict src, size_t count);
void *xmemset(void *dst, int ch, size_t count);
