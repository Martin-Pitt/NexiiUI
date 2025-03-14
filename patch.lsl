/*
    Patches are special flat mesh surfaces for uniform/consistent corners
    For example if you have a rounded corners on a window and wanted the corners
    to look the same no matter the size of the window
    
    You also need to #define the following constants:
    PATCH_SCALE -- this is the maximum size of a patch you expect, for example 6m or 0.5m,
                   the smallest size you can therefore have is that divided by 6,
                   e.g. 1m or ~.0833m respectively
    PATCH_CORNER -- Texture used for corners of the patch
    PATCH_BORDER -- Texture used for the straight edges
    
    Example:
#include "NexiiUI/patch.lsl"
#define PATCH_SCALE 2.5
#define PATCH_CORNER "190639dc-a421-b0d8-f730-c0157ea53e63"
#define PATCH_BORDER "92fb8db3-14ab-a0ab-14d9-8afa98813342"
*/

list computePatch(vector size) {
    vector repeat = <size.y, size.z, 0> / PATCH_SCALE;
    vector offset = <.5,.5,0>;
    return [
        PRIM_TEXTURE, 0, PATCH_CORNER, repeat * .990, offset + <.00125,-.00125,0>, 0,
        PRIM_TEXTURE, 1, PATCH_BORDER, repeat * .990, offset + <.00125,-.00125,0>, 0,
        PRIM_TEXTURE, 2, PATCH_BORDER, <repeat.y, repeat.x, 0> * .990, offset + <.00125,-.00125,0>, 0
    ];
}
