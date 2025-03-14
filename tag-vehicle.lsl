/// Dependencies:
// https://github.com/Martin-Pitt/NexiiLSL
// "NexiiLSL/linkset.lsl"
// "NexiiLSL/texture.lsl"
// "NexiiLSL/damage-types.lsl"

// https://github.com/Martin-Pitt/NexiiText4
// "NexiiText4/renderer.lsl"

// https://github.com/Martin-Pitt/NexiiUI
// "NexiiUI/digit.lsl"
// "NexiiUI/tag-header.lsl"

/*
    Vehicle Tags are special UI meshes that can be used to show an armored combat vehicle's name and health
    
    You can also define VEHICLE_PATCH so that it attaches a patch below the tag
    which you can resize to show additional context such as crew members
*/


renderVehicleTag(string vehicle)
{
    string identifier = "VEHICLE_" + vehicle;
    list label; // [link0, pos0, link1, pos1, ...]
    
    integer linkVehicleTag = LinksetResourceReserve("LinkVehicles");
    #ifdef VEHICLE_PATCH
    integer linkPatch = LinksetResourceReserve("LinkPatches");
    #endif
    vector tagPos = <0.03,0,0>;
    vector patchPos = <-.05,0.73,0>;
    label += [
        linkVehicleTag, tagPos
        #ifdef VEHICLE_PATCH
        , linkPatch, patchPos
        #endif
    ];
    #ifdef VEHICLE_PATCH
    vector patchSize = <0.1, 2.17, 0.216>;
    #endif
    
    // Get and render the name
    Anchor = <0,0,0>;
    Color = <1,1,1>;
    FontSize = 0.2;
    LineHeight = 1.1;
    islandX = Cursor.x = -.27;
    islandY = Cursor.y = -.05;
    
    string name = llKey2Name(vehicle);
    text(name);
    label += llDeleteSubList(textRender(), 0, 1);
    
    // Render the tag
    llSetLinkPrimitiveParamsFast(linkVehicleTag, [
        PRIM_SIZE, <0.1, 3.531, 0.216>,
        PRIM_TEXTURE, FACE_PROFILE, TEXTURE_TRANSPARENT, <1,.0838,0>, <0,0.125,0>, 0,
        PRIM_COLOR, FACE_PROFILE, <1,1,1>*.15, 1,
        PRIM_COLOR, FACE_ICON, <1,1,1>, 1,
        
        PRIM_TEXTURE, FACE_TRIM, TEXTURE_TRIM, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, FACE_BAR_HEALTH, TEXTURE_BAR, <1,1,0>, <-0.5,0,0>, 0,
        PRIM_TEXTURE, FACE_BAR_DELTA, TEXTURE_BAR, <1,1,0>, <-0.5,0,0>, 0,
        #ifdef VEHICLE_HEALTH_BY_DEFAULT
        // Show health bar by default
        PRIM_COLOR, FACE_TRIM, <1,1,1>, 1,
        PRIM_COLOR, FACE_BAR_HEALTH, <0,1,0>, 1,
        PRIM_COLOR, FACE_BAR_DELTA, <1,0,0>, 1,
        PRIM_COLOR, FACE_DIGITS_HEALTH, <1,1,1>, 1,
        PRIM_COLOR, FACE_DIGITS_MAX, <1,1,1>, 1
        #else
        // Hide health bar by default
        PRIM_COLOR, FACE_TRIM, <1,1,1>, 0,
        PRIM_COLOR, FACE_BAR_HEALTH, <0,1,0>, 0,
        PRIM_COLOR, FACE_BAR_DELTA, <1,0,0>, 0,
        PRIM_COLOR, FACE_DIGITS_HEALTH, <1,1,1>, 0,
        PRIM_COLOR, FACE_DIGITS_MAX, <1,1,1>, 0
        #endif
        
        #ifdef VEHICLE_PATCH
        ,
        PRIM_LINK_TARGET, linkPatch,
        PRIM_POS_LOCAL, patchPos,
        PRIM_SIZE, patchSize,
        PRIM_COLOR, ALL_SIDES, <0,0,0>, 1
        ] + computePatch(patchSize) + [
        #endif
    ]);
    
    llLinksetDataWrite(identifier, llList2Json(JSON_ARRAY, label));
}

releaseVehicleTag(string vehicle)
{
    string identifier = "VEHICLE_" + vehicle;
    list label = llJson2List(llLinksetDataRead(identifier));
    llLinksetDataDelete(identifier);
    
    integer linkVehicleTag = llList2Integer(label, 0);
    #ifdef VEHICLE_PATCH
    integer linkPatch = llList2Integer(label, 2);
    #endif
    list params = [
        PRIM_LINK_TARGET, linkVehicleTag,
        PRIM_POS_LOCAL, <0,0,0>,
        PRIM_SIZE, <.01,.01,.01>,
        PRIM_COLOR, ALL_SIDES, <0,0,0>, 0
        #ifdef VEHICLE_PATCH
        ,
        PRIM_LINK_TARGET, linkPatch,
        PRIM_POS_LOCAL, <0,0,0>,
        PRIM_SIZE, <.01,.01,.01>
        #endif
    ];
    
    #ifdef VEHICLE_PATCH
    label = llDeleteSubList(label, 0, 3);
    #else
    label = llDeleteSubList(label, 0, 1);
    #endif
    
    integer index; integer total;
    for(index = 0, total = llGetListLength(label); index < total; index += 2)
    {
        integer link = llList2Integer(label, index);
        params += [
            PRIM_LINK_TARGET, link,
            PRIM_POS_LOCAL, <0,0,0>,
            PRIM_SIZE, <.01,.01,.01>,
            PRIM_COLOR, ALL_SIDES, <0,0,0>, 0
        ];
    }
    llSetLinkPrimitiveParamsFast(0, params);
    
    LinksetResourceRelease("LinkVehicles", linkVehicleTag);
    #ifdef VEHICLE_PATCH
    LinksetResourceRelease("LinkPatches", linkPatch);
    #endif
    textBin([0, 0] + label);
}

list updateVehicleTag(string vehicle)
{
    string identifier = "VEHICLE_" + vehicle;
    list label = llJson2List(llLinksetDataRead(identifier));
    integer linkVehicleTag = llList2Integer(label, 0);
    
    float health = llGetHealth(vehicle);
    integer hp;
    integer hpMax;
    
    // Try to get the standardised hover text health hp/max
    string text = (string)llGetObjectDetails(vehicle, [OBJECT_TEXT]);
    if(text == "") jump skipHealthValues;
    
    list temp = llParseString2List(text, [" "], ["/"]);
    integer div = llListFindList(temp, ["/"]);
    if(div == -1) jump skipHealthValues;
    
    hpMax = llList2Integer(temp, div + 1);
    if(!hpMax) { hpMax = 0; jump skipHealthValues; }
    
    string strHP = llList2String(temp, div - 1);
    float floatHP = (float)strHP;
    integer intHP = (integer)strHP;
    if(strHP == (string)floatHP) hp = llCeil(floatHP);
    else if(strHP == (string)intHP) hp = intHP;
    else if(intHP) hp = intHP; // Last resort, if it's a positive value then lets try use it anyway
    else { hp = hpMax = 0; jump skipHealthValues; }
    
    health /= float(hpMax); // Scale health to [0.0-1.0] range
    
    @skipHealthValues;
    
    float healthPrev;
    if(llLinksetDataRead(identifier + "_health"))
         healthPrev = (float)llLinksetDataRead(identifier + "_health");
    else healthPrev = health;
    llLinksetDataWrite(identifier + "_health", (string)health);
    
    // Show as ded -- possible to misidentify vehicles that have no prim health and no LBA
    if(health <= 0) return [
        PRIM_LINK_TARGET, linkVehicleTag,
        PRIM_COLOR, FACE_TRIM, <1,1,1>, 1,
        PRIM_COLOR, FACE_BAR_HEALTH, <0,1,0>, 1,
        PRIM_COLOR, FACE_BAR_DELTA, <1,0,0>, 1,
        PRIM_COLOR, FACE_DIGITS_HEALTH, <1,1,1>, 0,
        PRIM_COLOR, FACE_DIGITS_MAX, <1,1,1>, 0,
        PRIM_TEXTURE, FACE_TRIM, TEXTURE_TRANSPARENT, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, FACE_ICON] + DamageTypeAsIcon(-100) + [
        PRIM_TEXTURE, FACE_BAR_HEALTH, TEXTURE_TRANSPARENT, <1,1,0>, <(health > 0) * -.5,0,0>, 0,
        PRIM_TEXTURE, FACE_BAR_DELTA, TEXTURE_TRANSPARENT, <1,1,0>, <(healthPrev > 0) * -.5,0,0>, 0,
        PRIM_TEXTURE, FACE_DIGITS_HEALTH, TEXTURE_TRANSPARENT, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, FACE_DIGITS_MAX, TEXTURE_TRANSPARENT, <1,1,0>, <0,0,0>, 0
    ];
    
    // Prim health but no visible or hidden hovertext indicating the hp/max
    else if(!hpMax) return [
        PRIM_LINK_TARGET, linkVehicleTag,
        PRIM_COLOR, FACE_TRIM, <1,1,1>, 1,
        PRIM_COLOR, FACE_BAR_HEALTH, <0,1,0>, 1,
        PRIM_COLOR, FACE_BAR_DELTA, <1,0,0>, 1,
        PRIM_COLOR, FACE_DIGITS_HEALTH, <1,1,1>, 0,
        PRIM_COLOR, FACE_DIGITS_MAX, <1,1,1>, 1,
        PRIM_TEXTURE, FACE_TRIM, TEXTURE_TRANSPARENT, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, FACE_ICON, TEXTURE_TRANSPARENT, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, FACE_BAR_HEALTH, TEXTURE_BAR, <1,1,0>, <(health > 0) * -.5,0,0>, 0,
        PRIM_TEXTURE, FACE_BAR_DELTA, TEXTURE_BAR, <1,1,0>, <(healthPrev > 0) * -.5,0,0>, 0,
        PRIM_TEXTURE, FACE_DIGITS_HEALTH, TEXTURE_TRANSPARENT, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, FACE_DIGITS_MAX, DIGIT(llCeil(health))
    ];
    
    // Full health progress bar and number displays possible
    return [
        PRIM_LINK_TARGET, linkVehicleTag,
        PRIM_COLOR, FACE_TRIM, <1,1,1>, 1,
        PRIM_COLOR, FACE_BAR_HEALTH, <0,1,0>, 1,
        PRIM_COLOR, FACE_BAR_DELTA, <1,0,0>, 1,
        PRIM_COLOR, FACE_DIGITS_HEALTH, <1,1,1>, 1,
        PRIM_COLOR, FACE_DIGITS_MAX, <1,1,1>, 1,
        PRIM_TEXTURE, FACE_TRIM, TEXTURE_TRIMDIV, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, FACE_ICON, TEXTURE_TRANSPARENT, <1,1,0>, <0,0,0>, 0,
        PRIM_TEXTURE, FACE_BAR_HEALTH, TEXTURE_BAR, <1,1,0>, <health * -.5,0,0>, 0,
        PRIM_TEXTURE, FACE_BAR_DELTA, TEXTURE_BAR, <1,1,0>, <healthPrev * -.5,0,0>, 0,
        PRIM_TEXTURE, FACE_DIGITS_HEALTH, DIGIT(hp),
        PRIM_TEXTURE, FACE_DIGITS_MAX, DIGIT(hpMax)
    ];
}
