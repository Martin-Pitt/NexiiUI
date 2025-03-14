/// Dependencies:
// https://github.com/Martin-Pitt/NexiiLSL
// "NexiiLSL/texture.lsl"

// Render a digit 0-999 to texture parameters; Use like: [PRIM_TEXTURE, 2, NUMBER_DIGIT(integer number)]
// Number panels are sized 75x48, texture is 2048x2048
#define DIGIT(digit) \
    "5a8c0878-3352-be2f-8b06-d109cfb0c04b",\
    TEXTURE_COORDS(\
        37.5 + (digit + (digit>9)) % 27 * 75.,\
        24 + (digit + (digit>9)) / 27 * 48.,\
        75., 48.,\
        2048., 2048.\
    ), 0

// Center in panel
#define DIGIT_CENTER(digit) \
    "5a8c0878-3352-be2f-8b06-d109cfb0c04b",\
    TEXTURE_COORDS(\
        37.5 + (digit + (digit>9)) % 27 * 75. + ((digit<10) + (digit<100)) * 12.5,\
        24 + (digit + (digit >= 10)) / 27 * 48.,\
        75., 48.,\
        2048., 2048.\
    ), 0

// Left aligned
#define DIGIT_LEFT(digit) \
    "5a8c0878-3352-be2f-8b06-d109cfb0c04b",\
    TEXTURE_COORDS(\
        37.5 + (digit + (digit>9)) % 27 * 75. + ((digit<10) + (digit<100)) * 25,\
        24 + (digit + (digit>9)) / 27 * 48.,\
        75., 48.,\
        2048., 2048.\
    ), 0

