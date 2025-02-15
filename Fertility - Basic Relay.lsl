integer relayChannel;
key speakerKey;

default
{
    state_entry()
    {
            relayChannel = (integer)("0x"+llGetSubString((string)llGetOwner(),0,6));;
            llListen(relayChannel,"","","");
    }
    on_rez(integer t)
    {
        llResetScript();
    }
    listen(integer c, string n, key id, string m)
    {
        if(id == llGetOwner() || llGetOwnerKey(id) == llGetOwner())//only listen to owner and owner objects with relay
        {
            speakerKey = id;
            //do
            if(llToLower(m) == "cycle")
            {
                llMessageLinked(LINK_THIS, -1, "getcyclestage",id);
            }
            if(llToLower(m) == "daddyname")
            {
                llMessageLinked(LINK_THIS, -1, "getDaddyKey",id);
            }
        }
        else
        {
            //ask permission
        }
    }
    link_message(integer link, integer n, string m, key id)
    {
        list data  = llParseString2List(m, ["|"],[""]);
        if(llList2String(data,0) == "CycleStage")
        {
            string msg = "Stage|";
            if(llList2Integer(data,1) == -1 )
            {
                llMessageLinked(LINK_THIS, -1, "showPregnant",id);
                msg +="Pregnant";
            }
            if(llList2Integer(data,1) == 0 )msg +="Ovulate soon";
            if(llList2Integer(data,1) == 1 )msg +="Fertile";
            if(llList2Integer(data,1) == 2 )msg +="Period";
            if(llList2Integer(data,1) == 3 )msg +="Recovery";
            llRegionSayTo(speakerKey, relayChannel, msg);
        }
        if(llList2String(data,0) == "DaddyKey")
        {
            
            string msg = "Daddy|";
            string name = llKey2Name(llList2Key(data,1));
            if(name != "") 
            {   
                msg += name;
            }
            else
            {
                msg += "Notaround";
            }
            llRegionSayTo(speakerKey, relayChannel, msg);
        }
    }
}
