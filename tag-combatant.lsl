/// Dependencies:
// https://github.com/Martin-Pitt/NexiiLSL
// "NexiiLSL/linkset.lsl"

// https://github.com/Martin-Pitt/NexiiText4
// "NexiiText4/renderer.lsl"

// https://github.com/Martin-Pitt/NexiiUI
// "NexiiUI/queue-header.lsl"
// "NexiiUI/tag-header.lsl"

/*
    Combatant Tags are special UI meshes that can be used to show an agent's
    display name, group insignia, profile photo, and healthbar
*/


renderCombatantTag(string agent, string group)
{
    string identifier = "COMBATANT_" + agent;
    list label; // [link0, pos0, link1, pos1, ...]
    
    integer linkCombatantTag = LinksetResourceReserve("LinkCombatants");
    vector tagPos = <0.03,0,0>;
    label += [linkCombatantTag, tagPos];
    
    // Get and render the display name
    string name = llGetDisplayName(agent);
    if(name == "") name = llLinksetDataRead(agent + "_displayName"); // Check cache
    if(name == "") { // Push to queue and block render until response
        llMessageLinked(LINK_THIS, LINK_QUEUE_NAME, llList2Json(JSON_ARRAY, [agent]), "");
        while((name = llLinksetDataRead(agent + "_displayName")) == "") llSleep(4/45.);
    }
    
    Anchor = <0,0,0>;
    Color = <1,1,1>;
    FontSize = 0.2;
    LineHeight = 1.1;
    islandX = Cursor.x = 0;
    islandY = Cursor.y = -.05;
    text(name);
    label += llDeleteSubList(textRender(), 0, 1);
    
    // Render the tag
    list params = [
        PRIM_SIZE, <0.1, 3.531, 0.216>,
        PRIM_TEXTURE, FACE_PROFILE, TEXTURE_TRANSPARENT, <1,.0838,0>, <0,0.125,0>, 0,
        PRIM_COLOR, FACE_PROFILE, <1,1,1>*.15, 1,
        PRIM_COLOR, FACE_GROUP, <1,1,1>, 1,
        
        /* // Show health bar by default
        PRIM_TEXTURE, FACE_TRIM, TEXTURE_TRIM, <1,1,0>, <0,0,0>, 0,
        PRIM_COLOR, FACE_TRIM, <1,1,1>, 0,
        PRIM_TEXTURE, FACE_BAR_HEALTH, TEXTURE_BAR, <1,1,0>, <0,0,0>, 0,
        PRIM_COLOR, FACE_BAR_HEALTH, <0,1,0>, 1,
        PRIM_TEXTURE, FACE_BAR_DELTA, TEXTURE_BAR, <1,1,0>, <0,0,0>, 0,
        PRIM_COLOR, FACE_BAR_DELTA, <1,0,0>, 1
        /*/ // Hide health bar by default
        PRIM_TEXTURE, FACE_TRIM, TEXTURE_TRIM, <1,1,0>, <0,0,0>, 0,
        PRIM_COLOR, FACE_TRIM, <1,1,1>, 1,
        PRIM_TEXTURE, FACE_BAR_HEALTH, TEXTURE_BAR, <1,1,0>, <-0.5,0,0>, 0,
        PRIM_COLOR, FACE_BAR_HEALTH, <0,1,0>, 1,
        PRIM_TEXTURE, FACE_BAR_DELTA, TEXTURE_BAR, <1,1,0>, <-0.5,0,0>, 0,
        PRIM_COLOR, FACE_BAR_DELTA, <1,0,0>, 1
        //*/
    ];
    llSetLinkTextureAnim(linkCombatantTag,
        ANIM_ON | LOOP | SMOOTH,
        FACE_PROFILE,
        1, llCeil(1.79/0.15),
        3.0, 1.0,
        0.005
    );
    
    
    llLinksetDataWrite(identifier, llList2Json(JSON_ARRAY, label));
    
    // Queue up loading the profile and group pictures if not cached already
    llMessageLinked(LINK_THIS, LINK_QUEUE_PROFILE, llList2Json(JSON_ARRAY, [agent, linkCombatantTag, FACE_PROFILE]), "");
    if(group != "" && group != NULL_KEY)
    {
        params += [PRIM_TEXTURE, FACE_GROUP, TEXTURE_TRANSPARENT, <1,1,0>, <0,0,0>, 0];
        llMessageLinked(LINK_THIS, LINK_QUEUE_GROUP, llList2Json(JSON_ARRAY, [group, linkCombatantTag, FACE_GROUP]), "");
    }
    
    llSetLinkPrimitiveParamsFast(linkCombatantTag, params);
}

releaseCombatantTag(string agent)
{
    string identifier = "COMBATANT_" + agent;
    list label = llJson2List(llLinksetDataRead(identifier));
    llLinksetDataDelete(identifier);
    
    integer linkCombatantTag = llList2Integer(label, 0);
    list params = [
        PRIM_LINK_TARGET, linkCombatantTag,
        PRIM_POS_LOCAL, <0,0,0>,
        PRIM_SIZE, <.01,.01,.01>,
        PRIM_COLOR, ALL_SIDES, <0,0,0>, 0
    ];
    llSetLinkTextureAnim(linkCombatantTag, FALSE, ALL_SIDES, 1, 1, 1, 1, 0);
    
    label = llDeleteSubList(label, 0, 1);
    
    integer index; integer total = llGetListLength(label);
    for(; index < total; index += 2)
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
    
    LinksetResourceRelease("LinkCombatants", linkCombatantTag);
    textBin([0, 0] + label);
}

list updateCombatantTag(string agent)
{
    list details = llGetObjectDetails(agent, [OBJECT_HEALTH]);
    if(details); else return [];
    
    string identifier = "COMBATANT_" + agent;
    list label = llJson2List(llLinksetDataRead(identifier));
    integer linkCombatantTag = llList2Integer(label, 0);
    
    float health = llList2Float(details, 0) / 100.0;
    
    return [
        PRIM_LINK_TARGET, linkCombatantTag,
        
        PRIM_COLOR, FACE_TRIM, <1,1,1>, 0,
        PRIM_TEXTURE, FACE_BAR_HEALTH, TEXTURE_BAR, <1,1,0>, <health * -.5,0,0>, 0,
        PRIM_COLOR, FACE_BAR_HEALTH, <0,1,0>, 1,
        
        // TODO: Show deltas over time
        PRIM_TEXTURE, FACE_BAR_DELTA, TEXTURE_BAR, <1,1,0>, <health * -.5,0,0>, 0,
        PRIM_COLOR, FACE_BAR_DELTA, <1,0,0>, 1
    ];
}

