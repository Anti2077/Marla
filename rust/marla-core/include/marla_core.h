#ifndef MARLA_CORE_H
#define MARLA_CORE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

uint32_t marla_core_api_version(void);
uint32_t marla_core_classify_surface(const char *bundle_id);

#ifdef __cplusplus
}
#endif

#endif
