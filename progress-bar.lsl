#define TEXTURE_PROGRESS "10b15206-6a1b-7170-3368-2bd73fcc5ba6" // Texture for the sliding progress bar, assumes left half is solid and right half is transparent

// This function draws the progress bar as primitive params list that can be inserted into a llSetLinkPrimitiveParamsFast call. The reason to return a list so that you can batch other primitive params together for performant batched rendering
list progressBar(float progress, float delta, float total)
{
    // Convert down to 0.0-1.0 range
    progress /= total;
    delta /= total;
    
    list params = [];
    
    // Show the subtraction bar
    if(delta < 0.0)
    {
        delta = progress - delta;
        params += [PRIM_COLOR, 1, <1, 0, 0>, 1];
    }
    
    // Show addition bar
    else if(delta > 0.0)
    {
        progress -= delta;
        delta = progress + delta;
        params += [PRIM_COLOR, 1, <0, 1, 0>, 1];
    }
    
    if(progress < 0.0) progress = 0.0; else if(progress > 1.0) progress = 1.0;
    if(delta < 0.0) delta = 0.0; else if(delta > 1.0) delta = 1.0;
    
    params += [
        PRIM_TEXTURE, 0, TEXTURE_PROGRESS, <-.5, 1, 0>, <.25 - progress * .5, 0, 0>, 0,
        PRIM_TEXTURE, 1, TEXTURE_PROGRESS, <-.5, 1, 0>, <.25 - delta * .5, 0, 0>, 0
    ];
    
    return params;
}

