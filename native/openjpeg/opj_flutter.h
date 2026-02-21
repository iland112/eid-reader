#ifndef OPJ_FLUTTER_H
#define OPJ_FLUTTER_H

#include <stdint.h>
#include <stddef.h>

#ifdef _WIN32
#define OPJ_FLUTTER_EXPORT __declspec(dllexport)
#else
#define OPJ_FLUTTER_EXPORT __attribute__((visibility("default")))
#endif

/**
 * Decode a JPEG 2000 image from memory to RGBA pixel data.
 *
 * @param data        Input JP2/J2K data buffer.
 * @param data_length Length of input data in bytes.
 * @param codec_type  0 = J2K codestream, 2 = JP2 container.
 * @param out_rgba    Output: pointer to allocated RGBA buffer (caller must free with opj_flutter_free).
 * @param out_width   Output: image width in pixels.
 * @param out_height  Output: image height in pixels.
 * @return 0 on success, non-zero on failure.
 */
OPJ_FLUTTER_EXPORT int opj_flutter_decode(
    const uint8_t* data,
    size_t data_length,
    int codec_type,
    uint8_t** out_rgba,
    int32_t* out_width,
    int32_t* out_height);

/**
 * Free a buffer allocated by opj_flutter_decode.
 * Zeroes the buffer before freeing (security: PII data).
 *
 * @param ptr    Pointer to the buffer.
 * @param length Length of the buffer in bytes.
 */
OPJ_FLUTTER_EXPORT void opj_flutter_free(uint8_t* ptr, size_t length);

#endif /* OPJ_FLUTTER_H */
