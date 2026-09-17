#include "NexiiUI/queue-header.lsl"

/*
    Queue does data loading for you
    
    For example loading:
    * Profile Picture as texture
    * Group Insignia as texture
    * Agent's Display Name
    
    When it comes to textures, the queue is also responsible for replacing the texture key
    of a linkset face, allowing you to easily hand off that responsibility to Queue
    
    Queue caches data into linkset data as:
    * agent + "_picture"
    * group + "_insignia"
    * agent + "_displayName"
    
    There are also expiry timestamps used to tell if the cache might be out of date:
    * agent + "_picture.expiry"
    * group + "_insignia.expiry"
    * agent + "_displayName.expiry"
*/

list queueGroup;
list queueProfile;
list queueNames;
list queueMap;

key reqGroup = NULL_KEY;
key reqProfile = NULL_KEY;
key reqName = NULL_KEY;
key reqMap = NULL_KEY;

float lastHTTPRequest = -10.0;
#define REQUEST_GROUP(group) "https://world.secondlife.com/group/" + group, [HTTP_BODY_MAXLENGTH, 2048], ""
#define REQUEST_PROFILE(agent) "https://world.secondlife.com/resident/" + agent, [HTTP_BODY_MAXLENGTH, 512], ""
#define REQUEST_MAP(region) "http://api.gridsurvey.com/simquery.php?region=" + llEscapeURL(region) + "&item=objects_uuid", [], ""

#define TIMEOUT 0.1
#define INSIGNIA_EXPIRE 4*24*60*60 // Unlikely to change
#define PICTURE_EXPIRE 2*24*60*60 // Could change
#define DISPLAYNAME_EXPIRE 24*60*60 // Not that uncommon
#define MAP_EXPIRE 3*24*60*60 // Can change down to daily
#define INSIGNIA_MAX 256
#define PICTURE_MAX 256
#define DISPLAYNAME_MAX 64
#define MAP_MAX 64


renderTexture(integer link, integer face, key texture)
{
    list params = llGetLinkPrimitiveParams(link, [PRIM_TEXTURE, face]);
    if(params); else params = ["", <1,1,0>, <0,0,0>, 0.0];
    llSetLinkPrimitiveParamsFast(link, [PRIM_TEXTURE, face, texture] + llDeleteSubList(params, 0, 0));
}


integer cleanupCountdown;
cacheCleanup()
{
    if(cleanupCountdown --> 0) return;
    cleanupCountdown = 32;
    
    // Check for expired entries
    integer now = llGetUnixTime();
    integer count = llLinksetDataCountFound("^[0-9a-f\\-]{36}_(insignia|picture|displayName|map).expiry$");
    integer page = 4;
    integer pages = llCeil(count / (float)page);
    while(page --> 0)
    {
        list names = llLinksetDataFindKeys("^[0-9a-f\\-]{36}_(insignia|picture|displayName|map).expiry$", pages*page, pages);
        integer iterator = llGetListLength(names);
        while(iterator --> 0)
        {
            string name = llList2String(names, iterator);
            integer expiry = (integer)llLinksetDataRead(name);
            if(expiry < now)
            {
                llLinksetDataDelete(llDeleteSubString(name, llStringLength(name) - 7, -1));
                llLinksetDataDelete(name);
            }
        }
    }
    
    // Cap out the cache entries
    integer insignias = llLinksetDataCountFound("^[0-9a-f\\-]{36}_insignia.expiry$");
    while(insignias --> INSIGNIA_MAX) llLinksetDataDelete(llList2String(llLinksetDataFindKeys("^[0-9a-f\\-]{36}_insignia.expiry$", llFloor(llFrand(insignias)), 1), 0));
    
    integer pictures = llLinksetDataCountFound("^[0-9a-f\\-]{36}_picture.expiry$");
    while(pictures --> PICTURE_MAX) llLinksetDataDelete(llList2String(llLinksetDataFindKeys("^[0-9a-f\\-]{36}_picture.expiry$", llFloor(llFrand(pictures)), 1), 0));
    
    integer displayNames = llLinksetDataCountFound("^[0-9a-f\\-]{36}_displayName.expiry$");
    while(displayNames --> DISPLAYNAME_MAX) llLinksetDataDelete(llList2String(llLinksetDataFindKeys("^[0-9a-f\\-]{36}_displayName.expiry$", llFloor(llFrand(displayNames)), 1), 0));
    
    integer maps = llLinksetDataCountFound("^[0-9a-f\\-]{36}_map.expiry$");
    while(maps --> MAP_MAX) llLinksetDataDelete(llList2String(llLinksetDataFindKeys("^[0-9a-f\\-]{36}_map.expiry$", llFloor(llFrand(maps)), 1), 0));
}


default
{
    state_entry()
    {
        cacheCleanup();
    }
    
    link_message(integer sender, integer number, string text, key identifier)
    {
        if(number == LINK_QUEUE_GROUP)
        {
            queueGroup += text;
            
            llSetTimerEvent(FALSE);
            llSetTimerEvent(TIMEOUT);
        }
        
        else if(number == LINK_QUEUE_PROFILE)
        {
            queueProfile += text;
            
            llSetTimerEvent(FALSE);
            llSetTimerEvent(TIMEOUT);
        }
        
        else if(number == LINK_QUEUE_NAME)
        {
            queueNames += text;
            
            llSetTimerEvent(FALSE);
            llSetTimerEvent(TIMEOUT);
        }
        
        else if(number == LINK_QUEUE_MAP)
        {
            queueMap += text;
            
            llSetTimerEvent(FALSE);
            llSetTimerEvent(TIMEOUT);
        }
        
        /*
        TODO: Actually check link number as well maybe? Otherwise could deqeue on someone with same group
        else if(number == LINK_DEQUEUE_GROUP)
        {
            string group = llList2String(llJson2List(text), 0);
            integer index;
            integer count = llGetListLength(queueGroup);
            for(; index < count; ++index)
            {
                list queue = llJson2List(llList2String(queueGroup, index));
                if(llList2String(queue, 0) == group)
                {
                    index = count;
                    queueGroup = llDeleteSubList(queueGroup, index, index);
                }
            }
        }
        
        else if(number == LINK_DEQUEUE_PROFILE)
        {
            string agent = llList2String(llJson2List(text), 0);
            integer index;
            integer count = llGetListLength(queueProfile);
            for(; index < count; ++index)
            {
                list queue = llJson2List(llList2String(queueProfile, index));
                if(llList2String(queue, 0) == agent)
                {
                    index = count;
                    queueProfile = llDeleteSubList(queueProfile, index, index);
                }
            }
        }
        */
    }
    
    timer()
    {
        llSetTimerEvent(FALSE);
        float delta = llGetTime() - lastHTTPRequest;
        if(delta < 1.2) return llSetTimerEvent(delta);
        
        integer totalGroup = llGetListLength(queueGroup);
        integer totalProfile = llGetListLength(queueProfile);
        integer totalNames = llGetListLength(queueNames);
        integer totalMap = llGetListLength(queueMap);
        
        if(totalGroup && reqGroup == NULL_KEY)
        {
            list queue = llJson2List(llList2String(queueGroup, 0));
            string group = llList2String(queue, 0);
            integer link = llList2Integer(queue, 1);
            integer face = llList2Integer(queue, 2);
            
            string texture = llLinksetDataRead(group + "_insignia");
            integer expiry = (integer)llLinksetDataRead(group + "_insignia.expiry");
            if(texture != "" && llGetUnixTime() < expiry)
            {
                queueGroup = llDeleteSubList(queueGroup, 0, 0);
                renderTexture(link, face, texture);
                llSetTimerEvent(TIMEOUT);
            }
            
            else
            {
                // If you want to swap the face to show it is now loading
                //renderTexture(link, face, TEXTURE_GROUP_LOADING);
                reqGroup = llHTTPRequest(REQUEST_GROUP(group));
                lastHTTPRequest = llGetTime();
            }
        }
        
        else if(totalProfile && reqProfile == NULL_KEY)
        {
            list queue = llJson2List(llList2String(queueProfile, 0));
            string agent = llList2String(queue, 0);
            integer link = llList2Integer(queue, 1);
            integer face = llList2Integer(queue, 2);
            
            string texture = llLinksetDataRead(agent + "_picture");
            integer expiry = (integer)llLinksetDataRead(agent + "_picture.expiry");
            if(texture != "" && llGetUnixTime() < expiry)
            {
                queueProfile = llDeleteSubList(queueProfile, 0, 0);
                renderTexture(link, face, texture);
                llSetTimerEvent(TIMEOUT);
            }
            
            else
            {
                // If you want to swap the face to show it is now loading
                //renderTexture(link, face, TEXTURE_PROFILE_LOADING);
                reqProfile = llHTTPRequest(REQUEST_PROFILE(agent));
                lastHTTPRequest = llGetTime();
            }
        }
        
        else if(totalMap && reqMap == NULL_KEY)
        {
            list queue = llJson2List(llList2String(queueMap, 0));
            string region = llList2String(queue, 0);
            integer link = llList2Integer(queue, 1);
            integer face = llList2Integer(queue, 2);
            
            string texture = llLinksetDataRead(region + "_map");
            integer expiry = (integer)llLinksetDataRead(region + "_map.expiry");
            if(texture != "" && llGetUnixTime() < expiry)
            {
                queueMap = llDeleteSubList(queueMap, 0, 0);
                renderTexture(link, face, texture);
                llSetTimerEvent(TIMEOUT);
            }
            
            else
            {
                // If you want to swap the face to show it is now loading
                //renderTexture(link, face, TEXTURE_PROFILE_LOADING);
                reqMap = llHTTPRequest(REQUEST_MAP(region));
                lastHTTPRequest = llGetTime();
            }
        }
        
        
        if(totalNames && reqName == NULL_KEY)
        {
            list queue = llJson2List(llList2String(queueNames, 0));
            string agent = llList2String(queue, 0);
            
            string displayName = llLinksetDataRead(agent + "_displayName");
            integer expiry = (integer)llLinksetDataRead(agent + "_displayName.expiry");
            if(displayName != "" && llGetUnixTime() < expiry)
            {
                queueNames = llDeleteSubList(queueNames, 0, 0);
            }
            
            else
            {
                reqName = llRequestDisplayName(agent);
            }
        }
    }
    
    http_response(key request, integer status, list metadata, string body)
    {
        #define needleImageID "<meta name=\"imageid\" content=\""
        
        if(request == reqGroup)
        {
            // If we had a 502 Bad Gateway then just retry a bit later
            if(llSubStringIndex(body, "502 Bad Gateway") != -1)
            {
                llSleep(1.5);
                list queue = llJson2List(llList2String(queueGroup, 0));
                string group = llList2String(queue, 0);
                reqGroup = llHTTPRequest(REQUEST_GROUP(group));
                lastHTTPRequest = llGetTime();
                return;
            }
            
            reqGroup = NULL_KEY;
            list queue = llJson2List(llList2String(queueGroup, 0));
            queueGroup = llDeleteSubList(queueGroup, 0, 0);
            string group = llList2String(queue, 0);
            integer link = llList2Integer(queue, 1);
            integer face = llList2Integer(queue, 2);
            
            integer pointer = llSubStringIndex(body, needleImageID);
            if(pointer != -1)
            {
                pointer += llStringLength(needleImageID);
                string texture = llGetSubString(body, pointer, pointer + 35);
                integer expiry = llGetUnixTime() + INSIGNIA_EXPIRE;
                cacheCleanup();
                llLinksetDataWrite(group + "_insignia", texture);
                llLinksetDataWrite(group + "_insignia.expiry", (string)expiry);
                renderTexture(link, face, texture);
            } else llOwnerSay("Unable to find group texture for secondlife:///app/group/" + group + "/inspect in\n" + body);
        }
        
        else if(request == reqMap)
        {
            if(status != 200)
            {
                // Failed, retries?
                // llOwnerSay("Unable to find map texture for " + region + "; GET " + (string)status + " " + body);
                return;
            }
            
            reqMap = NULL_KEY;
            list queue = llJson2List(llList2String(queueMap, 0));
            queueMap = llDeleteSubList(queueMap, 0, 0);
            string region = llList2String(queue, 0);
            integer link = llList2Integer(queue, 1);
            integer face = llList2Integer(queue, 2);
            
            string texture = body; // The body is just the texture key
            integer expiry = llGetUnixTime() + MAP_EXPIRE;
            cacheCleanup();
            llLinksetDataWrite(region + "_map", texture);
            llLinksetDataWrite(region + "_map.expiry", (string)expiry);
            renderTexture(link, face, texture);
        }
        
        else if(request == reqProfile)
        {
            // If we had a 502 Bad Gateway then just retry a bit later
            if(llSubStringIndex(body, "502 Bad Gateway") != -1)
            {
                llSleep(1.5);
                list queue = llJson2List(llList2String(queueProfile, 0));
                string agent = llList2String(queue, 0);
                reqProfile = llHTTPRequest(REQUEST_PROFILE(agent));
                lastHTTPRequest = llGetTime();
                return;
            }
            
            reqProfile = NULL_KEY;
            
            list queue = llJson2List(llList2String(queueProfile, 0));
            queueProfile = llDeleteSubList(queueProfile, 0, 0);
            string agent = llList2String(queue, 0);
            integer link = llList2Integer(queue, 1);
            integer face = llList2Integer(queue, 2);
            
            integer pointer = llSubStringIndex(body, needleImageID);
            if(pointer != -1)
            {
                pointer += llStringLength(needleImageID);
                string texture = llGetSubString(body, pointer, pointer + 35);
                integer expiry = llGetUnixTime() + PICTURE_EXPIRE;
                cacheCleanup();
                llLinksetDataWrite(agent + "_picture", texture);
                llLinksetDataWrite(agent + "_picture.expiry", (string)expiry);
                renderTexture(link, face, texture);
            } else llOwnerSay("Unable to find profile texture for secondlife:///app/agent/" + agent + "/inspect in\n" + body);
        }
        
        llSetTimerEvent(TIMEOUT);
    }
    
    dataserver(key request, string data)
    {
        if(request == reqName)
        {
            reqName = NULL_KEY;
            
            list queue = llJson2List(llList2String(queueNames, 0));
            queueNames = llDeleteSubList(queueNames, 0, 0);
            string agent = llList2String(queue, 0);
            integer expiry = llGetUnixTime() + DISPLAYNAME_EXPIRE;
            cacheCleanup();
            llLinksetDataWrite(agent + "_displayName", data);
            llLinksetDataWrite(agent + "_displayName.expiry", (string)expiry);
            
            llSetTimerEvent(TIMEOUT);
        }
    }
}
