#include "opj_flutter.h"
#include "openjpeg/src/lib/openjp2/openjpeg.h"
#include <stdlib.h>
#include <string.h>

/* Memory stream state for in-memory JP2 decoding. */
typedef struct {
    const uint8_t* data;
    size_t length;
    size_t position;
} mem_stream_t;

static OPJ_SIZE_T mem_read(void* p_buffer, OPJ_SIZE_T p_nb_bytes, void* p_user_data) {
    mem_stream_t* s = (mem_stream_t*)p_user_data;
    size_t remaining = s->length - s->position;
    if (remaining == 0) return (OPJ_SIZE_T)-1;  /* EOF */

    size_t to_read = p_nb_bytes < remaining ? p_nb_bytes : remaining;
    memcpy(p_buffer, s->data + s->position, to_read);
    s->position += to_read;
    return to_read;
}

static OPJ_OFF_T mem_skip(OPJ_OFF_T p_nb_bytes, void* p_user_data) {
    mem_stream_t* s = (mem_stream_t*)p_user_data;
    OPJ_OFF_T old_pos = (OPJ_OFF_T)s->position;
    OPJ_OFF_T new_pos = old_pos + p_nb_bytes;

    if (new_pos < 0) return -1;
    if ((size_t)new_pos > s->length) {
        s->position = s->length;
        return (OPJ_OFF_T)(s->length) - old_pos;
    }

    s->position = (size_t)new_pos;
    return p_nb_bytes;
}

static OPJ_BOOL mem_seek(OPJ_OFF_T p_nb_bytes, void* p_user_data) {
    mem_stream_t* s = (mem_stream_t*)p_user_data;
    if (p_nb_bytes < 0 || (size_t)p_nb_bytes > s->length) return OPJ_FALSE;
    s->position = (size_t)p_nb_bytes;
    return OPJ_TRUE;
}

static int clamp_component(opj_image_comp_t* comp, size_t idx) {
    if (comp->prec == 0) return 0;

    int value = comp->data[idx];

    /* Handle signed components */
    if (comp->sgnd) {
        value += (1 << (comp->prec - 1));
    }

    /* Scale to 8-bit */
    if (comp->prec > 8) {
        value >>= (comp->prec - 8);
    } else if (comp->prec < 8) {
        value <<= (8 - comp->prec);
    }

    if (value < 0) return 0;
    if (value > 255) return 255;
    return value;
}

int opj_flutter_decode(
    const uint8_t* data,
    size_t data_length,
    int codec_type,
    uint8_t** out_rgba,
    int32_t* out_width,
    int32_t* out_height)
{
    if (!data || data_length == 0 || !out_rgba || !out_width || !out_height) {
        return -1;
    }

    *out_rgba = NULL;
    *out_width = 0;
    *out_height = 0;

    /* Create decoder */
    opj_codec_t* codec = opj_create_decompress((OPJ_CODEC_FORMAT)codec_type);
    if (!codec) return -2;

    /* Set parameters */
    opj_dparameters_t params;
    opj_set_default_decoder_parameters(&params);
    if (!opj_setup_decoder(codec, &params)) {
        opj_destroy_codec(codec);
        return -3;
    }

    /* Create memory stream */
    mem_stream_t state = { .data = data, .length = data_length, .position = 0 };

    opj_stream_t* stream = opj_stream_create(0, OPJ_TRUE);
    if (!stream) {
        opj_destroy_codec(codec);
        return -4;
    }

    opj_stream_set_read_function(stream, mem_read);
    opj_stream_set_skip_function(stream, mem_skip);
    opj_stream_set_seek_function(stream, mem_seek);
    opj_stream_set_user_data(stream, &state, NULL);
    opj_stream_set_user_data_length(stream, data_length);

    /* Read header */
    opj_image_t* image = NULL;
    if (!opj_read_header(stream, codec, &image)) {
        opj_stream_destroy(stream);
        opj_destroy_codec(codec);
        return -5;
    }

    /* Decode */
    if (!opj_decode(codec, stream, image)) {
        opj_image_destroy(image);
        opj_stream_destroy(stream);
        opj_destroy_codec(codec);
        return -6;
    }

    /* Extract dimensions */
    int32_t w = (int32_t)(image->x1 - image->x0);
    int32_t h = (int32_t)(image->y1 - image->y0);
    uint32_t nc = image->numcomps;

    if (w <= 0 || h <= 0) {
        opj_image_destroy(image);
        opj_stream_destroy(stream);
        opj_destroy_codec(codec);
        return -7;
    }

    /* Guard against unreasonable dimensions (max 10000x10000 = 100MP).
     * Also prevents integer overflow in rgba_size on 32-bit platforms. */
    if (w > 10000 || h > 10000) {
        opj_image_destroy(image);
        opj_stream_destroy(stream);
        opj_destroy_codec(codec);
        return -9;
    }

    /* Allocate RGBA output buffer */
    size_t rgba_size = (size_t)w * (size_t)h * 4;
    uint8_t* rgba = (uint8_t*)malloc(rgba_size);
    if (!rgba) {
        opj_image_destroy(image);
        opj_stream_destroy(stream);
        opj_destroy_codec(codec);
        return -8;
    }

    /* Convert to RGBA */
    for (int32_t y = 0; y < h; y++) {
        for (int32_t x = 0; x < w; x++) {
            size_t src_idx = (size_t)y * (size_t)w + (size_t)x;
            size_t dst_idx = src_idx * 4;

            if (nc >= 3) {
                rgba[dst_idx + 0] = (uint8_t)clamp_component(&image->comps[0], src_idx);
                rgba[dst_idx + 1] = (uint8_t)clamp_component(&image->comps[1], src_idx);
                rgba[dst_idx + 2] = (uint8_t)clamp_component(&image->comps[2], src_idx);
                rgba[dst_idx + 3] = nc >= 4
                    ? (uint8_t)clamp_component(&image->comps[3], src_idx) : 255;
            } else {
                uint8_t gray = (uint8_t)clamp_component(&image->comps[0], src_idx);
                rgba[dst_idx + 0] = gray;
                rgba[dst_idx + 1] = gray;
                rgba[dst_idx + 2] = gray;
                rgba[dst_idx + 3] = nc >= 2
                    ? (uint8_t)clamp_component(&image->comps[1], src_idx) : 255;
            }
        }
    }

    *out_rgba = rgba;
    *out_width = w;
    *out_height = h;

    opj_image_destroy(image);
    opj_stream_destroy(stream);
    opj_destroy_codec(codec);
    return 0;
}

void opj_flutter_free(uint8_t* ptr, size_t length) {
    if (ptr) {
        /* Security: zero buffer before freeing (PII data) */
        memset(ptr, 0, length);
        free(ptr);
    }
}
