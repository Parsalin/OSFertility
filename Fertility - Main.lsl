/*
Fertility was made for use on os grids.
It's intended to be open source and written in such a way that other huds dont have power over this one unless it's given. ((any commands that could change things in the hud have to come from the owner or ask permission, none yet))
Any mods or additions made for this hud, please release them open source as well.
Please leave this header intact.

Base code written by Matthew Stevenson of youth nation.
*/

//names of things
//string noteName = "Fertility - Data";
string NOTECARD = "Fertility - Settings";

//owner
string Name;
key Owner;

//Web Server Data
key http_request_id;
key http_request_save_id;
key http_request_version_id;
string url = "http://sp.wa.darkheartsos.net:8080";
string username;
string password = "";
integer getPass = FALSE;
integer onlineMode = -1;
integer changeLineMode = FALSE;
integer saveOrload = -1;
integer initialize = 0; //0 = ask for password, 1 = check settings, 2 = Ask for gender
integer isNew = -1;

//Settings
integer showCycle = 0;
key partnerKey = NULL_KEY;

//notecard reading variables
integer intLine1;
key keyConfigQueryhandle;
key keyConfigUUID;

//Female only
list spermDonors = [];
list spermExpires = [];
integer maxDonors = 6;

key babyDaddyKey = NULL_KEY;
//string babyDaddyName = "";

//female cycle variables
integer cycleDayTimer;// counts up per rpday til = to next cycleeventtime
integer now; //timer set to unix time

//integer cycleTimerNext; //timer set to unix time
list nextCycleEventName = ["Ovulate", "Fertile", "Period", "Recovery"];//named events to come
list nextCycleEventRotations = [<0.7, 0, 0, 0.7>, <0, 0, 0, 1>, <-0.5, 0.5, 0.5, 0.5>, <-0.7, 0, 0, 0.7>, <1, 0, 0, 0>];
list nextCycleEventTime = [5,5,5,15];//time in rp days till cycle restarts.

//cycle timers
integer cycleStage = 0; //ovulate = 0, fertile = 1, period = 2, recovery = 3, -1 pregnant.

integer nextRPDay;// used to track next rp day.
integer rpDay = 0;//keep track of days to push stage forward
integer offlineRPDays = 0;

//main variables
integer dayLength = 6; //how many rl hours in a rp day
integer pregnancyDay = 0; //current rp days out of pregnancyTermLengthInDay
integer pregnancyTermLengthInDay = 280; //how long a term lasts before a baby can be born
integer termWeek = 0;
integer showPregnant = FALSE;
integer canBirth = FALSE;

//Force/RLV
integer canForce = FALSE;// if you make this true then the mod for force can force you to target others. How that is done is defined there.

//Fertility chance
integer fertilityChance = 30;//Chance that all goes right and the egg fertilizes and implants. if set to 0 no cycle will run.

//Male only
integer lastPewPew;
float cumBar = 0;//from 0.0 to 1.0.

//Shared globals
float globalVersion = 0.25;
integer canVersion = TRUE;
integer gender = -1; // 0 male 1 female 2 both

//nearby users
//list nearbyUserKey = [];
list otherUserKey = [];
list otherUserGender = [];
list otherRegionUserGender = [];
list usersTargetingMe = [];

//buffered lists
list otherUserKeyTemp = [];
list otherUserGenderTemp = [];
list otherRegionUserGenderTemp = [];
list usersTargetingMeTemp = [];

//partnered variables
integer isLinked = FALSE;
key currentTarget = NULL_KEY;

//hud info
list linkedButtons = [];//a list of all prims linked to the hud

//listener channels
integer pingChannel= -91283;//arbitrary but static ping channel
integer pingRegionChannel = -91284;//arbitrary but static region ping channel
integer menuChannel;//based on avi key

//Timers
integer tick = 0;//20 ticks, to give time for various things to happen and make changes before each new cycle begins.
integer scanTick = 0;
integer saveTick = 0;
integer timerDelay = 3;//how often each timer cycles
integer Settings = 0;

//longpress
integer held = FALSE;
integer longPress =0;

//debug
integer debugSpam = FALSE;

//functions:
string getAllSaveDataForDB()
{
    //http_request_id = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], "UN="+username+"|PW="+password+"|CM=save:"+getAllSaveDataForDB());
    string data = "";
    if(gender == -1)return [-1];
    data += "Name="+ (string)llKey2Name(llGetOwner());
    data += "|TOD="+ (string)now;
    data += "|Gender="+ (string)gender;
    //data += "|HudVersion="+ (string)globalVersion;
//If your a women
    if(gender == 1)
    {
    //Add to data cyclestage data
        data += "|CycleStage="+ (string)cycleStage;
    //Compile Donor and expires data
        string theseDonors = "";
        string theseExpires = "";
        if ( llGetListLength(spermDonors) > 1)
        {
            theseDonors = llDumpList2String(spermDonors,[","]);
            theseExpires = llDumpList2String(spermExpires,[","]);
        }
        else if ( llGetListLength(spermDonors) == 1)
        {
            theseDonors = llList2String(spermDonors,0);
            theseExpires =llList2String(spermExpires,0);
        }
        else if ( llGetListLength(spermDonors) < 1)
        {
            theseDonors = "None";
            theseExpires = "None";
        }
    //Just in case corrections
        if(theseDonors == "")theseDonors = "None";
        if(theseExpires == "") theseExpires = "None";
    //Add Donor and expires data for db
        data += "|Donors="+ theseDonors;
        data += "|Expires="+ theseExpires;
        
    //If your pregnant
        if(cycleStage == -1)
        {
            //Send
            if(babyDaddyKey != "" && babyDaddyKey != "None")
            {
                data += "|BabyDaddy="+ (string)babyDaddyKey;
                data += "|TermDay="+ (string)pregnancyDay;
            }
        }
        else
        {
            data += "|BabyDaddy=None";
            data += "|TermDay=None";
        }
    }
    
    if(debugSpam == TRUE)
    {
        llOwnerSay("Changes == "+(string) data);
    }
    return data;
}
loadFromDB(list Values)
{
    integer i;
    string debugingDB = "";
    for(i=0; i<llGetListLength(Values); i++)
    {
        list Value = llParseString2List(llList2String(Values,i), ["="], [""]);
            if(debugSpam == TRUE)llOwnerSay("DB: "+llDumpList2String(Value, ["="]));
            
            if(llToLower(llList2String(Value, 0)) == "name")
            {
                Name = llList2String(Value, 1);
                debugingDB += Name + " | "+ llList2String(Value, 1);
            }
            if(llToLower(llList2String(Value, 0)) == "gender")
            {
                gender = llList2Integer(Value, 1);
                debugingDB += (string)gender + " | "+ llList2String(Value, 1);
            }
            if(llToLower(llList2String(Value, 0)) == "tod")
            {
                now = llList2Integer(Value, 1);
                debugingDB += (string)now + " | "+ llList2String(Value, 1);
            }
            if(llToLower(llList2String(Value, 0)) == "donors")
            {
                if(llList2String(Value, 1) == "" || llList2String(Value, 1) == "None" )
                {
                    spermDonors = [];
                    debugingDB += llDumpList2String(spermDonors, ",") + " | "+ "''";
                    spermExpires = [];
                    debugingDB += llDumpList2String(spermExpires, ",") + " | "+ "None";
                }
                else
                {
                    list theseSperm = llParseString2List(llList2String(Value, 1),[","],[""]);
                    if(llGetListLength(theseSperm) <= 1)
                    {
                        spermDonors =  llList2String(Value, 1);
                    }
                    else
                    {
                        integer i = 0;
                        while(i < llGetListLength(theseSperm) )
                        {
                            if(llList2String(theseSperm, i) != "" && llList2String(theseSperm, i) != "None" ) spermDonors += llList2List(theseSperm, i, i);
                            i++;
                        }
                    }
                    debugingDB += (string)llGetListLength(spermDonors)+" "+llDumpList2String(spermDonors, ",") + " | "+ llList2String(Value, 1);
                }
            }
            if(llToLower(llList2String(Value, 0)) == "expires")
            {
                if(llList2String(Value, 1) == "" || llList2String(Value, 1) == "None" )
                {
                    spermExpires = [];
                    debugingDB += llDumpList2String(spermExpires, ",") + " | "+ "''";
                }
                else
                {
                    list theseExpires = llParseString2List(llList2String(Value, 1),[","],[""]);
                    if(llGetListLength(theseExpires) <= 1)
                    {
                        spermExpires =  llList2String(Value, 1);
                    }
                    else
                    {
                        integer i = 0;
                        while(i < llGetListLength(theseExpires) )
                        {
                            if(llList2String(theseExpires, i) != "" && llList2String(theseExpires, i) != "None" ) spermExpires += llList2List(theseExpires, i, i);
                            i++;
                        }
                    }
                    debugingDB += (string)llGetListLength(spermExpires)+" "+llDumpList2String(spermExpires,",") + " | "+ llList2String(Value, 1);
                }
            }

            if(llToLower(llList2String(Value, 0)) == "babydaddy")
            {
                babyDaddyKey = llList2String(Value, 1);
                debugingDB += (string)babyDaddyKey + " | "+ llList2String(Value, 1);
            }
            if(llToLower(llList2String(Value, 0)) == "termday")
            {
                pregnancyDay = llList2Integer(Value, 1);
                debugingDB += (string)pregnancyDay + " | "+ llList2String(Value, 1);
            }
            if(llToLower(llList2String(Value, 0)) == "cyclestage")
            {
                cycleStage = llList2Integer(Value, 1);
                debugingDB += (string) cycleStage + " | "+ llList2String(Value, 1);
            }
            debugingDB +="\n";
    }
    if(debugSpam == TRUE)
    {
        llOwnerSay("Changes == "+(string) debugingDB);
    }
}
//Find the link based on its name
integer getLinkFromList(string name)
{
    integer link = llListFindList(linkedButtons, [name]);
    if( link == -1) link = 999;
    return link+2;
}
integer checkMenuNeeded()
{
    integer needed = FALSE;
    //If linked
    if(llListFindList(usersTargetingMe,currentTarget) != -1 )
    {
        needed = TRUE;
    }
    //if victim near by
    //if mod actions available
    return needed;
}
list getActionsMenu()
{
    list buttons;
    buttons = ["Cum Inside"];
    return buttons;
}
updateLinkAlphas()
{
    llSetLinkAlpha(getLinkFromList(llGetObjectName()),1,ALL_SIDES);
    llSetLinkAlpha(getLinkFromList("fertility Hud"),1,ALL_SIDES);
    llSetLinkAlpha(getLinkFromList("Menu"),checkMenuNeeded(),ALL_SIDES);
    if(Settings > 0) llSetLinkAlpha(getLinkFromList("Settings"),1,ALL_SIDES);
    if(Settings <= 0) llSetLinkAlpha(getLinkFromList("Settings"),0,ALL_SIDES);
    if(onlineMode != -1)
    {
        llSetLinkAlpha(getLinkFromList("Online"),onlineMode,ALL_SIDES);
        llSetLinkAlpha(getLinkFromList("Offline"),!onlineMode,ALL_SIDES);
    }
    if(gender == 0)//your a boy show boys stuff
    {
            if(llGetListLength(otherUserKey) == 0)
            {
                llSetLinkAlpha(getLinkFromList("Girl"),0,ALL_SIDES);
            }
            else
            {
                llSetLinkAlpha(getLinkFromList("Girl"),1,ALL_SIDES);
            }
            if(usersTargetingMe == [])
            {
                llSetLinkAlpha(getLinkFromList("girl Hearts"),0,ALL_SIDES);
            }
            else
            {
                llSetLinkAlpha(getLinkFromList("girl Hearts"),1,ALL_SIDES);
            }
        }
        if(gender == 1)//your a girl show girl stuff
        {
            if(showCycle == 0)
            {
                integer i;
                for(i=0; i<6; i++)
                {
                    if(i==4 || i== 5)llSetLinkAlpha(getLinkFromList("Cycle"),1,i);
                }
            }
            else
            {
                llSetLinkAlpha(getLinkFromList("Cycle"),1,ALL_SIDES);
            }
            //set cycle link rotation
            if(llGetListLength(otherUserKey) == 0)
            {
                llSetLinkAlpha(getLinkFromList("Boy"),0,ALL_SIDES);
            }
            else
            {
                llSetLinkAlpha(getLinkFromList("Boy"),1,ALL_SIDES);
            }
            if(usersTargetingMe == [])
            {
                llSetLinkAlpha(getLinkFromList("boy Hearts"),0,ALL_SIDES);
            }
            else
            {
                llSetLinkAlpha(getLinkFromList("boy Hearts"),1,ALL_SIDES);
            }
        }

            if(currentTarget == NULL_KEY)
            {
                llSetText("",<1,1,1>,1);
            }
            else
            {
                integer i;
                if(llListFindList(usersTargetingMe,currentTarget) != -1 )
                {
                    llSetText("❤❤ "+llGetDisplayName(currentTarget)+" ❤❤", <1,1,1>,1);
                }
                else
                {
                    llSetText(">> "+llGetDisplayName(currentTarget), <1,1,1>,1);
                }
            }
}

default
{
    state_entry()
    {
        if(llGetOwner() != "9a9304c2-620d-496a-ba50-2bf45cf8dbd9")debugSpam = FALSE;
        Owner = llGetOwner();
        //Set link alphas
        integer i;
        for(i=2; i <= llGetNumberOfPrims(); i++)
        {
            linkedButtons += llGetLinkName(i);
            if(i>2)llSetLinkAlpha(i,0,ALL_SIDES);
        }
        llMessageLinked(LINK_SET,0,"%# ",NULL_KEY);
        
        //New user/password
        if(initialize == 0)
        {
            //new user ask the Question!
            menuChannel = (integer)("0x"+llGetSubString((string)llGetOwner(),0,4));
            llListen(menuChannel,"","","");
            llOwnerSay("Welcome to Fertility. \nRemember do not trust third-party versions.");
            llDialog(llGetOwner(), "\nRun in online or offline mode?
  Online mode will save your data to a server off grid.
  Offline mode only stores your data in the hud.", ["Online", "Offline"],menuChannel);
        }
    }
    touch_start(integer t)
    {
        if(onlineMode == 0)
        {
            if (llGetInventoryType(NOTECARD) != INVENTORY_NONE)
            {
                keyConfigQueryhandle = llGetNotecardLine(NOTECARD, intLine1);
                keyConfigUUID = llGetInventoryKey(NOTECARD);
            }
            else
            {
                llDialog(llGetOwner(),"Gender?", ["Male", "Female"], menuChannel);
            }
        }
        else
        {
            if(initialize == 0)
            {
                llResetScript();
            }
            if(initialize == 1)
            {
                password = "";
                llTextBox(llGetOwner(), "Type in your password:", menuChannel);
            }
            if(initialize == 2)
            {
                    if (llGetInventoryType(NOTECARD) != INVENTORY_NONE)
                    {
                        keyConfigQueryhandle = llGetNotecardLine(NOTECARD, intLine1);
                        keyConfigUUID = llGetInventoryKey(NOTECARD);
                    }
                    else
                    {
                        llDialog(llGetOwner(),"Gender?", ["Male", "Female"], menuChannel);
                    }
            }
        }
    }
    listen(integer c, string n, key id, string m)
    {
        if( id == llGetOwner() )
        {
            if(initialize == 0)// mode selected
            {
                if(m == "Online")
                {
                    initialize = 1;
                    onlineMode = 1;//online mode
                    username = llGetOwner();
                    password = "";
                    llTextBox(llGetOwner(), "Type in your password:", menuChannel);
                    return;
                }
                if(m == "Offline")
                {
                    initialize = 2;
                    onlineMode = 0;//offline mode
                    llOwnerSay("Offline mode chosen. \nYour hud progress may get reset if the script is reset, such as during hyper-gridding.");
                    //Get Settings
                    if (llGetInventoryType(NOTECARD) != INVENTORY_NONE)
                    {
                        keyConfigQueryhandle = llGetNotecardLine(NOTECARD, intLine1);
                        keyConfigUUID = llGetInventoryKey(NOTECARD);
                    }
                    else
                    {
                        llDialog(llGetOwner(),"Gender?", ["Male", "Female"], menuChannel);
                    }
                    return;
                }
            }
            if(initialize == 1)//password offered try it
            {
                if(onlineMode == 1 && password == "")
                {
                    password = llEscapeURL(m);
                    //http_request_id = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], "UN="+username+"|PW="+password+"|CM=Load:Gender");
                    http_request_id = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], "UN="+username+"|PW="+password+"|CM=Load:Name|Gender|TOD|Donors|Expires|BabyDaddy|TermDay|CycleStage");
                }
            }
            if(initialize == 2)//offline choose gender
            {
                if(m == "Male")   gender = 0;
                if(m == "Female") gender = 1;
                string output;
                output += "You chose ";
                if(gender == 0) output += "male.";
                if(gender == 1) output += "female.";
                llOwnerSay(output);
                if(gender != -1)state running;

            }
        }
    }
    http_response(key request_id, integer status, list metadata, string body)
    {
        if (request_id != http_request_id) return;// exit if unknown
        if (status == 499)
        {
            llOwnerSay("Connection was refused. Switching to Offline Mode.");
            onlineMode = FALSE;// exit if unknown
            //Get Settings
            initialize=2;
            if (llGetInventoryType(NOTECARD) != INVENTORY_NONE)
            {
                keyConfigQueryhandle = llGetNotecardLine(NOTECARD, intLine1);
                keyConfigUUID = llGetInventoryKey(NOTECARD);
            }
            else
            {
                llDialog(llGetOwner(),"Gender?", ["Male", "Female"], menuChannel);
            }
        }
        
        if(debugSpam == TRUE)llOwnerSay("ID: "+(string)request_id+" Status: "+ (string)status+" MetaData: "+ llDumpList2String(metadata, "|")+" Body: "+ body);
        
        //no user = new user
        if(body == "UserNotExists")
        {
             http_request_id = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], "UN="+username+"|PW="+password+"|CM=new:");
        }
        //wrong password try again
        if(body == "ErrorUserPwd")
        {
            password = "";
            llTextBox(llGetOwner(), "Wrong password, Type in your password:", menuChannel);
            return;
        }
        list bits = llParseString2List(body, ["|"],[""]);
        if(llList2String(bits,0)  == "CM=New")
        {
            if(llList2String(bits,1) == "okNewUser")
            {
                initialize=2;
                isNew = TRUE;
                 //Get Settings
                if (llGetInventoryType(NOTECARD) != INVENTORY_NONE)
                {
                    keyConfigQueryhandle = llGetNotecardLine(NOTECARD, intLine1);
                    keyConfigUUID = llGetInventoryKey(NOTECARD);
                }
                else
                {
                    llDialog(llGetOwner(),"Gender?", ["Male", "Female"], menuChannel);
                }
                return;
            }
        }
        if(llList2String(bits,0)  == "CM=Load")
        {
            if(llList2String(bits,1) == "Name=None")
            {
                initialize=2;
                isNew = TRUE;
            }
            else
            {
                isNew = FALSE;
                loadFromDB(bits);
                llOwnerSay("Loaded your account from DB.");
            }
            //gender = llList2Integer(bits,1);
            keyConfigQueryhandle = llGetNotecardLine(NOTECARD, intLine1);
            keyConfigUUID = llGetInventoryKey(NOTECARD);
        }
        
    }
    //Notecard Reader
    dataserver(key keyQueryId, string strData)
    {
        if (keyQueryId == keyConfigQueryhandle)
        {
            //if you reach eof and still don't know gender then ask for it.
            if (strData == EOF)
            {
                llOwnerSay("Loaded settings from notecard.");
                if(gender == -1)
                {
                    llDialog(llGetOwner(),"Gender?", ["Male", "Female"], menuChannel);
                    return;
                }
                else
                {
                    state running;
                }
            }

            keyConfigQueryhandle = llGetNotecardLine(NOTECARD, ++intLine1);

            if (llGetSubString (strData, 0, 0) != "#")              // is it a comment?
            {
                list data = llParseString2List(strData,["="],[]);//split around the =
                if(debugSpam == TRUE)llOwnerSay("NC: "+llDumpList2String(data, ["="]));
                if(llList2String(data,0) == "gender" && gender == -1)   gender = llList2Integer(data,1);
                if(llList2String(data,0) == "showCycle")   showCycle = llList2Integer(data,1);
                if(llList2String(data,0) == "fertilityChance")fertilityChance = llList2Integer(data,1);
                if(llList2String(data,0) == "maxDonors")maxDonors = llList2Integer(data,1);
                if(llList2String(data,0) == "dayLength")dayLength = llList2Integer(data,1);
                if(llList2String(data,0) == "pregnancyTermLengthInDay")pregnancyTermLengthInDay = llList2Integer(data,1);
                if(llList2String(data,0) == "onlyPartner")
                {
                    if(llList2Integer(data,1) != -1)
                    {
                        partnerKey = llList2Key(data,1);
                    }
                    else
                    {
                        partnerKey = NULL_KEY;
                    }
                }
            //RLV ((Cannot be detached. You can be force-sat via this hud.)) >Off by Default< 0 off, 1 on
                if(llList2String(data,0) == "allowRLV")
                {
                    
                }
            //Enables the force features. >off by default<  0 off 1 on
                if(llList2String(data,0) == "allowForce")
                {
                    
                }

                if(llList2String(data,0) == "cycleTimeOvulate")nextCycleEventTime = llListReplaceList(nextCycleEventTime,llList2Integer(data,1),0,0);
                if(llList2String(data,0) == "cycleTimeFertile")nextCycleEventTime = llListReplaceList(nextCycleEventTime,llList2Integer(data,1),1,1);
                if(llList2String(data,0) == "cycleTimePeriod")nextCycleEventTime = llListReplaceList(nextCycleEventTime,llList2Integer(data,1),2,2);
                if(llList2String(data,0) == "cycleTimeRecovery")nextCycleEventTime = llListReplaceList(nextCycleEventTime,llList2Integer(data,1),3,3);
            }
        }
    }
}
state running
{
    state_entry()
    {
        intLine1=0;
        if(now == 0){now= llGetUnixTime();}//define now.
        nextRPDay = now+((dayLength*60)*60);// define tomorrow once.
        menuChannel = (integer)("0x"+llGetSubString((string)llGetOwner(),0,5));;
        llListen(pingChannel,"","","");
        llListen(pingRegionChannel,"","","");
        llListen(menuChannel,"","","");
        llSetTimerEvent(timerDelay);
        //Save or load data to/from db
        //Update links on hud
        updateLinkAlphas();
        if(gender == 1)llSetLinkPrimitiveParams(getLinkFromList("Cycle"), [PRIM_ROT_LOCAL, (rotation)llList2Rot(nextCycleEventRotations, cycleStage)]);
        
        if(onlineMode == 1)
        {
            if(isNew)
            {
                //save
                llOwnerSay("Saving new account to DB.");
                http_request_id = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], "UN="+username+"|PW="+password+"|CM=save:"+getAllSaveDataForDB());
            }
            else
            {
                if(canVersion == TRUE)http_request_version_id = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], "UN="+username+"|PW="+password+"|CM=check:Version="+(string)globalVersion);
            }
        }
    }
    attach(key id)
    {
        if(id == NULL_KEY)
        {
            llSetTimerEvent(0);
        }
        else
        {
            llSetTimerEvent(timerDelay);
            if(canBirth == TRUE)llOwnerSay("Click the pink stage icon to have your baby.");
            
            if(onlineMode == TRUE)http_request_version_id = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], "UN="+username+"|PW="+password+"|CM=check:Version="+globalVersion);
        }
    }
    changed(integer c)
    {
        if(c & CHANGED_INVENTORY)
        {
            llResetScript();//intended, can be used now because database.
        }
        if(c & CHANGED_OWNER )
        {
            //llLinksetDataReset();
            llResetScript();//intended
        }
    }
    touch_start(integer t)
    {
        if(llDetectedKey(0) == llGetOwner())
        {
            longPress = 3;
            held = TRUE;
        }
    }
    touch_end(integer t)
    {
        if(llDetectedKey(0) != llGetOwner() )return;
        
        if(held == TRUE && longPress <= 0)
        {
            held = FALSE;
            return;
        }
        held = FALSE;
        if(llGetLinkName(llDetectedLinkNumber(0)) == "Menu")
        {
            list buttons = getActionsMenu();
            if(llGetListLength(buttons) >= 1) llDialog(llGetOwner(), "What would you like to do?", buttons, menuChannel);
        }
        if(llGetLinkName(llDetectedLinkNumber(0)) == "Boy" || llGetLinkName(llDetectedLinkNumber(0)) == "Girl")
        {
            //Output list
            string output = "Available Users: \n";
            integer i;
            for(i=0; i<llGetListLength(otherUserKey); i++)
            {
                output += llGetDisplayName(llList2Key(otherUserKey,i))+" "+llList2String(otherUserGender,i);
                if(llListFindList(llList2Key(otherUserKey,i),usersTargetingMe) != -1)
                {
                    output += " ❤";
                }
                output += ".\n";
            }
            llOwnerSay(output);
        }
        if(llGetLinkName(llDetectedLinkNumber(0)) == "Online" || llGetLinkName(llDetectedLinkNumber(0)) == "Offline")
        {
            if(onlineMode == 1)
            {
                //do I want people to switch to offline mode?
            }
            else
            {
                changeLineMode = TRUE;
                llDialog(llGetOwner(),"You are about to switch from offline to online mode, Choose:
Save - Save your current state to DB.
Load - Load your state from DB.
Cancel - Don't switch to online mode.", ["Save", "Load", "Cancel"], menuChannel);
            }
        }
        if(llGetLinkName(llDetectedLinkNumber(0)) == "Cycle" && gender == 1 && canBirth == TRUE)
        {
            llDialog(llGetOwner(),"Give birth to your baby?",["yes","no"],menuChannel);
        }
        if(llGetLinkName(llDetectedLinkNumber(0)) == "fertility Hud")
        {
            currentTarget = NULL_KEY;
            list Buttons;
            integer i;
            for(i=0; i<=11; i++)
            {
                if(i < llGetListLength(otherUserKey) )
                {
                    string n = llGetUsername(llList2Key(otherUserKey,i));
                    
                    if(llGetListLength(otherUserKey) > 0 && llGetListLength(otherUserKey) <= 11)
                    {
                        if(n != "")Buttons += n;//test
                    }
                    if(llGetListLength(otherUserKey) > 11)
                    {
                        if( i != 2 )
                        {
                            if(n != "")Buttons += n;
                        }
                        else
                        {
                            Buttons += "Next";
                        }
                    }
                    if(llGetListLength(otherUserKey) == 0)
                    {
                        Buttons += "No one.";
                    }
                }
            }
            //llOwnerSay(llDumpList2String(Buttons,["|"]));
            llDialog(llGetOwner(),"Who to target?", Buttons, menuChannel);
        }
        if(llGetLinkName(llDetectedLinkNumber(0)) == "Settings" && Settings > 0)
        {
            llDialog(llGetOwner(),"Settings:
    Restart - Will erase all data and reset hud.
    Data - Will dump all saved data to chat.", ["Restart", "Data"], menuChannel);
        }
    }
    link_message(integer link, integer n, string m, key id)
    {

        //this is where mod api will be done
    //Get api
        //Get basic Info
            //get gender
        if(llToLower(m) == "getgender")
        {
            llMessageLinked(LINK_SET, -1, "Gender|"+(string)gender,id);
        }
        if(gender == 1)
        {
            //get sperm donor info
                //get number of donor
            if(llToLower(m) == "getdonornum")
            {
                llMessageLinked(LINK_SET, -1, "DonorNum|"+(string)llGetListLength(spermDonors),id);
            }
                //get donor key
            if(llToLower(m) == "getdonorkeyat")
            {
                llMessageLinked(LINK_SET, -1, "DonorKey|"+(string)llList2String(spermDonors,n),id);
            }
                //get donor duration
            if(llToLower(m) == "getdonordurationat")
            {
                llMessageLinked(LINK_SET, -1, "DonorDuration|"+(string)llList2String(spermExpires,n),id);
            }
            //get cycleinfo
            //get stage
            if(llToLower(m) == "getcyclestage")
            {
                llMessageLinked(LINK_SET, -1, "CycleStage|"+(string)cycleStage,id);
            }
            //get pregnancyinfo
                //get day/week
            if(llToLower(m) == "getpregday")
            {
                llMessageLinked(LINK_SET, -1, "PregDay|"+(string)pregnancyDay,id);
            }
            if(llToLower(m) == "getpregweek")
            {
                llMessageLinked(LINK_SET, -1, "PregWeek|"+(string)termWeek,id);
            }
                //get baby daddy
            if(llToLower(m) == "getdaddykey")
            {
                llMessageLinked(LINK_SET, -1, "DaddyKey|"+(string)babyDaddyKey,id);
            }
                //get canbirth
            if(llToLower(m) == "getcanbirth")
            {
                llMessageLinked(LINK_SET, -1, "CanBirth|"+(string)canBirth,id);
            }
        }
    //Set api
        //Force Target
        if(llToLower(m) == "settarget")
        {
            if(canForce == TRUE)currentTarget = id;
        }
         //set sperm donor infor
            //remove donor key
        if(llToLower(m) == "removedonor")
        {
            spermDonors = llDeleteSubList(spermDonors, n, n);//remove the old sperm when it's found.
            spermExpires = llDeleteSubList(spermExpires, n, n);//remove the donors time stamp.
        }
            //change donor duration
        if(llToLower(m) == "setdonorduration")
        {
            //still deciding if i want to add this...
        }
        //set cycleinfo
            //set stage
        if(llToLower(m) == "setstage")
        {
            //still deciding if i want to add this...
        }
        //set pregnancyinfo
            //Show pregnant if pregnant
        if(llToLower(m) == "showpregnant")
        {
            if(cycleStage == -1) showPregnant = TRUE;
        }
            //intiate birth\
        if(llToLower(m) == "startbirth")
        {
            //still deciding if i want to add this...
        }
    }
    http_response(key request_id, integer status, list metadata, string body)
    {
            if(debugSpam == TRUE)llOwnerSay("ID: "+(string)request_id+" Status: "+ (string)status+" MetaData: "+ llDumpList2String(metadata, "|")+" Body: "+ body);
            
            //llOwnerSay("ID: "+(string)request_id+" Status: "+ (string)status+" MetaData: "+ llDumpList2String(metadata, "|")+" Body: "+ body);
            if (status == 499)
            {
                llResetScript();
            }
                    
            //no user = new user
            if(body == "UserNotExists")
            {
                 llResetScript();
            }
            //wrong password try again
            if(body == "ErrorUserPwd")
            {
                getPass = TRUE;
                password = "";
                llTextBox(llGetOwner(), "Wrong password, Type in your password:", menuChannel);
                return;
            }
        if(request_id == http_request_id)
        {
            if(body == "CM=Save|okUpdateData")
            {
                onlineMode = 1;
                if(canVersion == TRUE)
                {
                    http_request_version_id = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], "UN="+username+"|PW="+password+"|CM=check:Version="+(string)globalVersion);
                }
            }
            
            //no other errors caused a crash!
            list rawValues = llParseString2List(body,["|"],[""]);
            if(llToLower(llList2String(rawValues,0)) == "cm=load")
            {
                loadFromDB(rawValues);
                onlineMode = 1;//online mode
            }
        }
        if(request_id == http_request_version_id)
        {
            if(body == "CM=check|needsUpdate") //current < Global, Offer update.
            {
                llOwnerSay("Your hud is outdated. Would you like to update?");
                llDialog(llGetOwner(),"Your hud is outdated. Receive new one now?", ["Send it.", "I'll wait."], menuChannel);
                canVersion = TRUE;
            }
            if(body == "CM=check|okVersion") //current matches what is one file, stop asking
            {
                canVersion = FALSE;
            }
            if(body == "CM=check|okUpdated") //current = global, save personal.
            {
                canVersion = FALSE;
                http_request_version_id = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], "UN="+username+"|PW="+password+"|CM=save:Version="+(string)globalVersion);
            }
        }
    }
    listen(integer c, string n, key id, string m)
    {
        if( c == menuChannel && id == llGetOwner()) //Menus
        {
            if(m == "Cum Inside" && gender == 0)
            {
                if(llListFindList(usersTargetingMe, currentTarget) != -1)//if my target is also targeting me.
                {
                   llOwnerSay("You're trying to pewpew inside "+llGetUsername(currentTarget)+".");
                    llRegionSayTo(currentTarget, pingChannel, "pew "+(string)cumBar);
                    lastPewPew = llGetUnixTime();
                    cumBar = 0;
                }
            }
            if(changeLineMode == TRUE)
            {
                if(m == "Save")
                {
                    if(password == "")
                    {
                        saveOrload = 0;
                        getPass = TRUE;
                        username = llGetOwner();
                        password = "";
                        llTextBox(llGetOwner(), "Type in your password:", menuChannel);
                        return;
                    }
                    else
                    {
                        integer i;
                        for(i=2; i <= llGetNumberOfPrims(); i++)
                        {
                            linkedButtons += llGetLinkName(i);
                            if(i>2)llSetLinkAlpha(i,0,ALL_SIDES);
                        }
                        llMessageLinked(LINK_SET,0,"%# ",NULL_KEY);
                        llOwnerSay("Saving..");
                        http_request_id = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], "UN="+username+"|PW="+password+"|CM=save:"+getAllSaveDataForDB());
                    }
                }
                if(m == "Load")
                {
                    if(password == "")
                    {
                        saveOrload = 1;
                        getPass = TRUE;
                        username = llGetOwner();
                        password = "";
                        llTextBox(llGetOwner(), "Type in your password:", menuChannel);
                        return;
                    }
                    else
                    {
                        integer i;
                        for(i=2; i <= llGetNumberOfPrims(); i++)
                        {
                            linkedButtons += llGetLinkName(i);
                            if(i>2)llSetLinkAlpha(i,0,ALL_SIDES);
                        }
                        llMessageLinked(LINK_SET,0,"%# ",NULL_KEY);
                        llOwnerSay("Loading..");
                        http_request_id = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], "UN="+username+"|PW="+password+"|CM=Load:Name|Gender|TOD|Donors|Expires|BabyDaddy|TermDay|CycleStage");
                    }
                }
                if(m == "Cancel")
                {
                    llOwnerSay("Cancelled.");
                }
                changeLineMode = FALSE;
            }
            if(Settings > 0)
            {
                if(m == "Restart")
                {
                    llResetScript();//intended
                }
                if(m == "Data")
                {
                    string output = "Output: \n";
                    output += "Owner "+(string)Owner+"\n";
                    output += "Gender "+(string)gender+"\n";
                    output += "TOD "+(string)now+"\n";
                    output += "Donors "+llDumpList2String(spermDonors,[" "])+"\n";
                    output += "Expires "+llDumpList2String(spermExpires,[" "])+"\n";
                    output += "BabyDaddy "+(string)babyDaddyKey+"\n";
                    output += "TermDay "+(string)pregnancyDay+"\n";
                    output += "CycleStage "+(string)cycleStage+"\n";
                    output += "RpDay "+(string)rpDay+"\n";
                    llOwnerSay(output);
                }
            }
            if(getPass == 1)//password offered try it
            {
                if(password == "")
                {
                    password = llEscapeURL(m);
                    if(saveOrload == 0)
                    {
                        integer i;
                        for(i=2; i <= llGetNumberOfPrims(); i++)
                        {
                            linkedButtons += llGetLinkName(i);
                            if(i>2)llSetLinkAlpha(i,0,ALL_SIDES);
                        }
                        llMessageLinked(LINK_SET,0,"%# ",NULL_KEY);
                        llOwnerSay("Saving..");
                        http_request_id = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], "UN="+username+"|PW="+password+"|CM=save:"+getAllSaveDataForDB());
                    }
                    if(saveOrload == 1)
                    {
                        integer i;
                        for(i=2; i <= llGetNumberOfPrims(); i++)
                        {
                            linkedButtons += llGetLinkName(i);
                            if(i>2)llSetLinkAlpha(i,0,ALL_SIDES);
                        }
                        llMessageLinked(LINK_SET,0,"%# ",NULL_KEY);
                        llOwnerSay("Loading..");
                        http_request_id = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], "UN="+username+"|PW="+password+"|CM=Load:Name|Gender|TOD|Donors|Expires|BabyDaddy|TermDay|CycleStage");
                    }
                    saveOrload = -1;
                    getPass = FALSE;
                }
            }
            if(m == "yes")
            {
                llGiveInventory(llGetOwner(),"Fertility - Baby");
                cycleStage = 0;
                pregnancyDay = 0;
                canBirth = FALSE;
                showPregnant=FALSE;
                babyDaddyKey = NULL_KEY;
                llMessageLinked(LINK_SET,0,"%# ",NULL_KEY);
            }
            if(m == "no")
            {
                return;
            }
    //Respond to send new hud?
            if(m == "Send it.")
            {
                llOwnerSay("Your new hud is on its way...");
                canVersion = FALSE;
                http_request_id = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], "UN="+username+"|PW="+password+"|CM=requestnewhud:"+(string)llGetOwner());
            }
            if(m == "I'll wait.")
            {
                llOwnerSay("You can get a new one at the shop.");
                canVersion = FALSE;
                return;
            }
            if(m == "next")
            {
                           list Buttons;
            integer i;
            for(i=12; i<=23; i++)
            {
                if(i < llGetListLength(otherUserKey) )
                {
                    string n = llGetDisplayName(llList2Key(otherUserKey,i));
                    
                    if(llGetListLength(otherUserKey) > 0 && llGetListLength(otherUserKey) <= 11)
                    {
                        Buttons += n;
                    }
                    if(llGetListLength(otherUserKey) > 23)
                    {
                        if( i != 2 )
                        {
                            Buttons += n;
                        }
                        else
                        {
                            Buttons += "Next";
                        }
                    }
                    if(llGetListLength(otherUserKey) == 0)
                    {
                        Buttons += "No one.";
                    }
                }
            }
            //llOwnerSay(llDumpList2String(Buttons,["|"]));
            if( Buttons != [] ) llDialog(llGetOwner(),"Who to target?", Buttons, menuChannel);
            }
            integer i;
            for(i=0; i<llGetListLength(otherUserKey); i++)
            {
                if(m == llGetUsername(llList2Key(otherUserKey,i)) )
                {
                    //Set Selected Target
                    currentTarget = llList2Key(otherUserKey,i);
                    if(llListFindList(usersTargetingMe, currentTarget) != -1)
                    {
                        llSetText("❤❤ "+llGetDisplayName(currentTarget)+" ❤❤", <1,1,1>,1);
                    }
                    else
                    {
                        llSetText(">> "+llGetDisplayName(currentTarget), <1,1,1>,1);
                    }
                }
            }
        }
        //stop here if the object isn't your partner's hud
        if(partnerKey != NULL_KEY && llGetOwnerKey(id) != (key)partnerKey)return;
        
        if( c == pingChannel) //Whisper range
        {
            list str = llParseString2List(m,["|"],[""]);
            if(gender != 0)
            {
                if(m == "Ping" || m == "Ping-"+(string)Owner)
                {
                    llRegionSayTo(id, pingChannel, "Pong");
                    if(llListFindList(otherUserKeyTemp, [llGetOwnerKey(id)]) == -1)
                    {
                        otherUserKeyTemp += [llGetOwnerKey(id)];
                        otherUserGenderTemp += ["♂"];
                    }
                }
            }
            if(m == "Pong" && gender != 1)
            {
                if(llListFindList(otherUserKeyTemp, [llGetOwnerKey(id)]) == -1)
                {
                    otherUserKeyTemp += [llGetOwnerKey(id)];
                    otherUserGenderTemp += ["♀"];
                }
            }
            if(m == "❤")
            {
                if(llListFindList(usersTargetingMeTemp, [llGetOwnerKey(id)]) == -1)
                {
                    usersTargetingMeTemp += [llGetOwnerKey(id)];
                }
            }
            if(llGetSubString(m,0,2) == "pew")
            {
                if(llListFindList(usersTargetingMe, currentTarget) != -1)
                {
                    float num = (float)llDeleteSubString(m,0,3);
                    if(num > 1)return;//no spoofing longer lasting seed. get ignored!
                    
                    key thisSpermDonor = llGetOwnerKey(id);
                    if(llListFindList(spermDonors, thisSpermDonor) == -1)
                    {
                        llOwnerSay(llGetDisplayName(llGetOwnerKey(id))+" just came inside you.");
                        llInstantMessage(llGetOwnerKey(id),"You just came inside "+llGetDisplayName(llGetOwner())+".");
                        
                        spermDonors += thisSpermDonor;
                        spermExpires += now+(num*((dayLength*60)*60));
                        
                        //Check if fertile and if inseminated immediately added V1.51
                        //Only on first load added. Multi clicks won't trigger this check.
                        if(cycleStage == 1)//is fertile
                        {
                            if(llGetListLength(spermDonors) > 0)//is sperm present?
                            {
                                if(llRound(llFrand(100)) < fertilityChance)//did the sperm find the egg and implant
                                {
                                    //Yay you're pregnant
                                    key spermDonor = llList2Key(spermDonors,llFloor(llFrand(llGetListLength(spermDonors))));
                                    if(spermDonor == "" || spermDonor == NULL_KEY)return;//make sure baby has a daddy. or abort.
                                    pregnancyDay = 0;
                                    cycleStage = -1;
                                    babyDaddyKey = spermDonor;
                                    saveTick = 100;
                                }
                            }
                        }
                    }
                    else
                    {
                        llOwnerSay(llGetDisplayName(llGetOwnerKey(id))+" just came inside you again.");
                        llInstantMessage(llGetOwnerKey(id),"You just came inside "+llGetDisplayName(llGetOwner())+" again.");
                        
                        spermExpires = llListReplaceList(spermExpires, [now+(num*((dayLength*60)*60))], llListFindList(spermDonors, thisSpermDonor), llListFindList(spermDonors, thisSpermDonor) );
                    }
                }
            }
            updateLinkAlphas();
        }
        if( c == pingRegionChannel) //region range
        {
            list str = llParseString2List(m,["|"],[""]);
            if(gender != 0)//is a male
            {
                if(m == "Ping" || m == "Ping-"+(string)Owner)
                {
                    llRegionSayTo(id, pingChannel, "Pong");
                    if(llListFindList(otherUserKey, [llGetOwnerKey(id)]) == -1) otherRegionUserGender += ["♂"];
                }
            }
            if(m == "Pong" && gender != 1)//is a female
            {
                if(llListFindList(otherUserKey, [llGetOwnerKey(id)]) == -1)otherRegionUserGender += ["♀"];
            }
            updateLinkAlphas();
        }
    }
    timer()
    {
        if(held == TRUE && longPress>0)longPress--;
        if(held == TRUE && longPress<=0)
        {
            Settings = 300;
        }
        //Random Event tick
        tick++;
        if(tick >= 20)tick =0;
        //Scan for others tick
        scanTick++;
        if(scanTick >= 2){scanTick=0;}
        //save tick
        if(onlineMode == 1)
        {
            saveTick++;
            if(saveTick >= 60){saveTick=0;}
        }
        
        if(Settings > 0)Settings--;
        if(tick == 0)//listen, I know this isn't great...
        {
            //progress random event ticks. tummy talkers, magic, other...
        }
        if(scanTick == 0)
        {
            //My hacky way of by passing lots of list checking adding and removing.
            
            //dump temp list into used list
            otherUserKey = otherUserKeyTemp;
            otherUserGender = otherUserGenderTemp;
            otherRegionUserGender = otherRegionUserGenderTemp;
            usersTargetingMe = usersTargetingMeTemp;
            //clear temp list to listen for pings and responses.
            otherUserKeyTemp = [];
            otherUserGenderTemp = [];
            otherRegionUserGenderTemp = [];
            usersTargetingMeTemp = [];
            
            updateLinkAlphas();//called often for detection pimgs
            if(currentTarget != NULL_KEY) llRegionSayTo(currentTarget, pingChannel, "❤");
        }
        if(saveTick == 0 && onlineMode == 1)
        {
            http_request_id = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], "UN="+username+"|PW="+password+"|CM=save:"+getAllSaveDataForDB());
            http_request_save_id = http_request_id;
        }

        //Pings
        if(gender == 0)//male. Only males ping. And load builds up to full.
        {
            if(llGetUnixTime() >= lastPewPew)
            {
                lastPewPew = llGetUnixTime()+3;
                if(cumBar< 1)cumBar += 0.1;
                if(cumBar> 1)cumBar = 1;
            }
            if(partnerKey == NULL_KEY)
            {
                llWhisper(pingChannel, "Ping");
                llRegionSay(pingRegionChannel, "Ping");
            }
            else
            {
                llWhisper(pingChannel, "Ping-"+(string)partnerKey);
                llRegionSay(pingRegionChannel, "Ping-"+(string)partnerKey);
            }
        }
        if(gender == 1)//female. Only females pong. Cycle stage, Remove sperm donors, Check for pregnant. Pregnancy.
        {
            now = llGetUnixTime();
            while(now >= nextRPDay) //if now is bigger than previously set tomorrow
            {
                nextRPDay = nextRPDay+((dayLength*60)*60);//add a day
                offlineRPDays++;
                rpDay++;
            }
            while(rpDay >= 1)//step thru stored offline days or progress one day.
            {
                //cycle an rp day
                rpDay--;
                cycleDayTimer++;
                //remove old cum
                integer i;
                for(i=0; i<llGetListLength(spermDonors); i++)//check all sperm
                {
                    integer thisSperm = (integer)llList2Integer(spermExpires,i);
                    if(thisSperm < llGetUnixTime())//is sperm to old?
                    {
                        spermDonors = llDeleteSubList(spermDonors, i, i);//remove the old sperm when it's found.
                        spermExpires = llDeleteSubList(spermExpires, i, i);//remove the donor's timestamp.
                        if(spermDonors == []) spermDonors = ["None"];
                        if(spermExpires == []) spermExpires = ["None"];
                    }
                    else
                    {
                        spermExpires = llListReplaceList(spermExpires, thisSperm-((dayLength*60)*60),i, i);//reduce sperm time til be low zero
                    }
                }
                //if fertile, check per day to see if pregnant
                if(cycleStage == 1)//is fertile
                {
                    if(llGetListLength(spermDonors) > 0)//is sperm present?
                    {
                        
                        if(llRound(llFrand(100)) < fertilityChance)//did the sperm find the egg and implant
                        {
                            //Yay your pregnant
                            key spermDonor = llList2Key(spermDonors,llFloor(llFrand(llGetListLength(spermDonors))));
                            if(spermDonor == "" || spermDonor == NULL_KEY || spermDonor == "None")return;//make sure baby has a daddy. or abort.
                            pregnancyDay = 0;
                            cycleStage = -1;
                            babyDaddyKey = spermDonor;
                            saveTick = 100;
                        }
                    }
                }
                //if period, clear all cum once per day
                if(cycleStage == 2)//is period!
                {
                    spermDonors = ["None"];
                    spermExpires = ["None"];
                    saveTick = 100;
                }
                // if pregnant, progress pregnancy
                if(cycleStage == -1)//if you are pregnant
                {
                    if( babyDaddyKey == NULL_KEY) // End pregnancy if we don't have anything for the babydaddy
                    {
                        llInstantMessage("9a9304c2-620d-496a-ba50-2bf45cf8dbd9", "Pregnancy Lost.");
                        cycleStage = 0;
                        pregnancyDay = 0;
                        canBirth = FALSE;
                        showPregnant=FALSE;
                        babyDaddyKey = NULL_KEY;
                        llMessageLinked(LINK_SET,0,"%# ",NULL_KEY);
                    }
                    pregnancyDay++;
                    if(pregnancyDay >= pregnancyTermLengthInDay)
                    {
                        pregnancyDay = pregnancyTermLengthInDay;
                        llMessageLinked(LINK_SET,0,"%#Pregnancy due now.",NULL_KEY);//will need a link msg to display from link prim..
                    }
                    else if(pregnancyDay < pregnancyTermLengthInDay)
                    {
                        if(pregnancyDay > 14 && showPregnant == FALSE)
                        {
                            showPregnant = TRUE;
                        }
                        if(showPregnant == TRUE)
                        {
                            llSetLinkPrimitiveParams(getLinkFromList("Cycle"), [PRIM_ROT_LOCAL, (rotation)llList2Rot(nextCycleEventRotations, cycleStage)]);
                            llMessageLinked(LINK_SET,0,"%#Pregnancy Day: "+(string)pregnancyDay,NULL_KEY);//will need a link msg to display from link prim...
                        }
                    }
                }
                if(pregnancyDay >= pregnancyTermLengthInDay) //check if rp days >= term
                {
                    canBirth = TRUE;
                }
                else
                {
                    canBirth = FALSE;
                }
                //check if stepping into trigger stage "week 1 week 2" then trigger third party "shape change, other attachments"
                if( termWeek < llFloor(pregnancyDay/7) )
                {
                    termWeek = llFloor(pregnancyDay/7);
                    // do new week event here.
                }
            }
            //if not pregnant, progress cycle.
            if(cycleStage != -1)//not pregnant
            {
                /*string debug = "\n";
                debug += "Donors: "+(string)llGetListLength(spermDonors)+"\n";
                debug += "Doner Keys: "+llDumpList2String(spermDonors," | ")+"\n";
                debug += "Cum Expires at: "+llDumpList2String(spermExpires," | ")+"\n";
                debug += "Now: "+(string)llGetUnixTime()+"\n";
                llOwnerSay(debug);*/
                integer nextCycleStage = llList2Integer(nextCycleEventTime, cycleStage);
                if(cycleDayTimer >= nextCycleStage)
                {
                    cycleStage++;
                    if(cycleStage == 4)
                    {
                        cycleStage=0;
                    }
                    llMessageLinked(LINK_SET,0,"",NULL_KEY);
                    while(nextCycleStage <= 0 && cycleStage < 4 )//skip stages that have been set to zero via settings
                    {
                        cycleStage++;
                        if(cycleStage == 4)cycleStage=0;
                        nextCycleStage = llList2Integer(nextCycleEventTime, cycleStage);
                    }
                    llSetLinkPrimitiveParams(getLinkFromList("Cycle"), [PRIM_ROT_LOCAL, (rotation)llList2Rot(nextCycleEventRotations, cycleStage)]);
                    cycleDayTimer=0;
                }
            }
            if(offlineRPDays != 0)
            {
                if(offlineRPDays > 1)llOwnerSay(offlineRPDays+" RP days have passed.");
                offlineRPDays=0;
                saveTick = 100;
            }
            //female end
        }
    }
}
