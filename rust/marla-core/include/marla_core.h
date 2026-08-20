#ifndef MARLA_CORE_H
#define MARLA_CORE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

uint32_t marla_core_api_version(void);
uint32_t marla_core_classify_surface(const char *bundle_id);

typedef struct MarlaTranslationHandle MarlaTranslationHandle;
typedef void (*MarlaTranslationEventCallback)(
    const uint8_t *event_json,
    size_t event_json_length,
    void *context
);

MarlaTranslationHandle *marla_translation_start(
    const uint8_t *request_json,
    size_t request_json_length,
    MarlaTranslationEventCallback callback,
    void *context
);

MarlaTranslationHandle *marla_model_list_start(
    const uint8_t *request_json,
    size_t request_json_length,
    MarlaTranslationEventCallback callback,
    void *context
);

MarlaTranslationHandle *marla_ocr_start(
    const uint8_t *request_json,
    size_t request_json_length,
    MarlaTranslationEventCallback callback,
    void *context
);

void marla_translation_cancel(MarlaTranslationHandle *handle);
void marla_translation_release(MarlaTranslationHandle *handle);

#ifdef __cplusplus
}
#endif

#endif
