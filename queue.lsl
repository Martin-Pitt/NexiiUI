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

key reqGroup = NULL_KEY;
key reqProfile = NULL_KEY;
key reqName = NULL_KEY;

float lastHTTPRequest = -10.0;
#define REQUEST_GROUP(group) "https://world.secondlife.com/group/" + group, [HTTP_BODY_MAXLENGTH, 2048], ""
#define REQUEST_PROFILE(agent) "https://world.secondlife.com/resident/" + agent, [HTTP_BODY_MAXLENGTH, 512], ""

#define TIMEOUT 0.1
#define INSIGNIA_EXPIRE 4*24*60*60 // Unlikely to change
#define PICTURE_EXPIRE 2*24*60*60 // Could change
#define DISPLAYNAME_EXPIRE 24*60*60 // Not that uncommon

renderGroup(integer link, integer face, key texture)
{
    list params = llGetLinkPrimitiveParams(link, [PRIM_TEXTURE, face]);
    if(params); else params = ["", <1,1,0>, <0,0,0>, 0.0];
    llSetLinkPrimitiveParamsFast(link, [PRIM_TEXTURE, face, texture] + llDeleteSubList(params, 0, 0));
}

renderProfile(integer link, integer face, key texture)
{
    list params = llGetLinkPrimitiveParams(link, [PRIM_TEXTURE, face]);
    if(params); else params = ["", <1,1,0>, <0,0,0>, 0.0];
    llSetLinkPrimitiveParamsFast(link, [PRIM_TEXTURE, face, texture] + llDeleteSubList(params, 0, 0));
}



default
{
    state_entry()
    {
        // Reset cache
        // llLinksetDataDeleteFound("^[0-9a-f\-]{36}_insignia", "");
        // llLinksetDataDeleteFound("^[0-9a-f\-]{36}_picture", "");
    }
    
    link_message(integer sender, integer number, string text, key identifier)
    {
        if(number == LINK_QUEUE_GROUP)
        {
            queueGroup += text;
            
            // If you want to swap the face to show it is in queue
            //list queue = llJson2List(text);
            //integer link = llList2Integer(queue, 1);
            //integer face = llList2Integer(queue, 2);
            //renderGroup(link, face, TEXTURE_GROUP_QUEUED);
            
            llSetTimerEvent(FALSE);
            llSetTimerEvent(TIMEOUT);
        }
        
        else if(number == LINK_QUEUE_PROFILE)
        {
            queueProfile += text;
            
            // If you want to swap the face to show it is in queue
            //list queue = llJson2List(text);
            //integer link = llList2Integer(queue, 1);
            //integer face = llList2Integer(queue, 2);
            //renderProfile(link, face, TEXTURE_PROFILE_QUEUED);
            
            llSetTimerEvent(FALSE);
            llSetTimerEvent(TIMEOUT);
        }
        
        else if(number == LINK_QUEUE_NAME)
        {
            queueNames += text;
            
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
                renderGroup(link, face, texture);
                llSetTimerEvent(TIMEOUT);
            }
            
            else
            {
                // If you want to swap the face to show it is now loading
                //renderGroup(link, face, TEXTURE_GROUP_LOADING);
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
                renderProfile(link, face, texture);
                llSetTimerEvent(TIMEOUT);
            }
            
            else
            {
                // If you want to swap the face to show it is now loading
                //renderProfile(link, face, TEXTURE_PROFILE_LOADING);
                reqProfile = llHTTPRequest(REQUEST_PROFILE(agent));
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
                llLinksetDataWrite(group + "_insignia", texture);
                llLinksetDataWrite(group + "_insignia.expiry", (string)expiry);
                renderGroup(link, face, texture);
            } else llOwnerSay("Unable to find group texture for secondlife:///app/group/" + group + "/inspect in\n" + body);
        }
        
        if(request == reqProfile)
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
                llLinksetDataWrite(agent + "_picture", texture);
                llLinksetDataWrite(agent + "_picture.expiry", (string)expiry);
                renderProfile(link, face, texture);
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
            llLinksetDataWrite(agent + "_displayName", data);
            llLinksetDataWrite(agent + "_displayName.expiry", (string)expiry);
            
            llSetTimerEvent(TIMEOUT);
        }
    }
}
