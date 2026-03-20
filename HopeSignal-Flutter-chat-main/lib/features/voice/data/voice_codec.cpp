#include <stdint.h>
#include <stdlib.h>

extern "C"
{

    int compress_audio(const uint8_t *in_data, int in_len, uint8_t *out_data, int out_cap)
    {
        if (in_data == nullptr || out_data == nullptr || in_len <= 0 || out_cap <= 0)
            return -1;

        int out_index = 0;
        for (int i = 0; i < in_len;)
        {
            uint8_t value = in_data[i];
            int count = 1;
            while (i + count < in_len && in_data[i + count] == value && count < 255)
                count++;

            if (out_index + 2 > out_cap)
                return -1;
            out_data[out_index++] = (uint8_t)count;
            out_data[out_index++] = value;
            i += count;
        }
        return out_index;
    }

    int decompress_audio(const uint8_t *in_data, int in_len, uint8_t *out_data, int out_cap)
    {
        if (in_data == nullptr || out_data == nullptr || in_len <= 1 || out_cap <= 0)
            return -1;

        int out_index = 0;
        for (int i = 0; i + 1 < in_len; i += 2)
        {
            int count = in_data[i];
            uint8_t value = in_data[i + 1];
            if (out_index + count > out_cap)
                return -1;
            for (int j = 0; j < count; j++)
            {
                out_data[out_index++] = value;
            }
        }
        return out_index;
    }
}
