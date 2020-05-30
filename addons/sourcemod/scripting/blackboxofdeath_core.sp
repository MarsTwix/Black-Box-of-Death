#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt>

#pragma newdecls required

//Definitions
#define SND_BOX "ttt_clwo/Smoke Grenade Sound Effect.mp3"
#define debug "[DEBUG] "
#define MAXENTITIES 2048

//flag and entity, general nums 
int g_iActiveBoxes = 0;
int SmokeOfBox[MAXENTITIES];
int g_iFog = -1;

enum struct PlayerData 
{
    //Nums
    int ClientBox;
    float BoxPosition[3];

    //Bools
    bool InRange;
    bool foggedByBox;
    bool BoxStoppped;
    bool ShowFog;

    //Timers
    Handle hBoxEnd;
    Handle hLoopSound;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

//Convars
ConVar g_cRangeEnabled = null;
ConVar g_cFogRange = null;
ConVar g_cCeaseTime = null;
 
public Plugin myinfo =
{
    name = "Black Box Of Death",
    author = "MarsTwix & C0rp3n",
    description = "This plugin fogs people who are in range, exclusive to the ones that are immune to the fog",
    version = "1.0.0",
    url = "clwo.eu"
};
 
public void OnPluginStart()
{
    LoadTranslations("common.phrases.txt");
    g_cRangeEnabled = AutoExecConfig_CreateConVar("ttt_box_range_enable", "1", "Sets whether range of the box is enabled");
    g_cFogRange = AutoExecConfig_CreateConVar("ttt_box_mute_range", "1000", "The range within a player get fogged by the box");
    g_cCeaseTime = AutoExecConfig_CreateConVar("ttt_box_cease_time", "30.0", "The time the box stops working");

    RegConsoleCmd("sm_spawnbox", Command_SpawnBox, "Spawns a Black Box Of Death");
    RegConsoleCmd("sm_clearbox", Command_ClearBox, "Clears a Black Box Of Death of a client");

    RegConsoleCmd("sm_vars", Command_Vars, "Show variables of client or given target");

    HookEvent("round_end", Event_RoundEnd);
}

public void OnMapStart()
{
    PrecacheSound(SND_BOX);

    LoopClients(i)
    {
        SetFlag(g_iActiveBoxes, i, false);
        g_iPlayer[i].foggedByBox = false;
        g_iPlayer[i].BoxStoppped = true;
        g_iPlayer[i].InRange = false;
        g_iPlayer[i].ShowFog = false;
    }

    int iEnt = -1;
    iEnt = FindEntityByClassname(-1, "env_fog_controller");
    
    if (IsValidEntity(iEnt)) 
    {
        g_iFog = iEnt;
    }
    else
    {
        g_iFog = CreateEntityByName("env_fog_controller");
        DispatchSpawn(g_iFog);
    }
    SetupBlackout();
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    LoopClients(i)
    {
        ClientReset(i);
        if (HasFlag(g_iActiveBoxes, i) == true)
        {
            DestroyBox(i);
            AcceptEntityInput(g_iFog, "TurnOff");
            g_iPlayer[i].ShowFog = false;
            DispatchKeyValueFloat(g_iFog, "farz", 0.0);
            
        }
    }

}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
    LoopClients(i)
    {
        ClientReset(i);
    }
}

public void OnClientPutInServer(int client)
{
    g_iPlayer[client].hBoxEnd = INVALID_HANDLE;
    g_iPlayer[client].hLoopSound = INVALID_HANDLE;
    ClientReset(client);
    AcceptEntityInput(g_iFog, "TurnOff");
    g_iPlayer[client].ShowFog = false;
}

Action Command_Vars(int client, int args)
{
    if (args == 0)
    {
        char name[32];
        GetClientName(client, name, sizeof(name));
        PrintToConsoleAll("Varaibles of %s:", name);
        PrintToConsoleAll("InRange: %b", g_iPlayer[client].InRange);
        PrintToConsoleAll("foggedByBox: %b", g_iPlayer[client].foggedByBox);
        PrintToConsoleAll("ShowFog: %b", g_iPlayer[client].ShowFog);
    }

    else if (args == 1)
    {
        char arg1[32], name[32];
        GetCmdArg(1, arg1, sizeof(arg1));
        int target = FindTarget(client, arg1);

        if (target == -1)
        {
            return Plugin_Handled;
        }

        GetClientName(target, name, sizeof(name));

        PrintToConsoleAll("Varaibles of %s:", name);
        PrintToConsoleAll("InRange: %b", g_iPlayer[target].InRange);
        PrintToConsoleAll("foggedByBox: %b", g_iPlayer[target].foggedByBox);
        PrintToConsoleAll("ShowFog: %b", g_iPlayer[target].ShowFog);
    }
    else
    {
        ReplyToCommand(client, "Usage: sm_vars (name)");
    }
    return Plugin_Handled;
}

Action Command_ClearBox(int client, int args)
{
    if (args == 0)
    {
        if (HasFlag(g_iActiveBoxes, client))
        {
            DestroyBox(client);
        }
        else
        {
            ReplyToCommand(client, "You don't have a active box!");
        }
    }

    else if (args == 1)
    {
        char arg1[32], name[32];
        GetCmdArg(1, arg1, sizeof(arg1));
        int target = FindTarget(client, arg1);

        if (target == -1)
        {
            return Plugin_Handled;
        }

        GetClientName(target, name, sizeof(name));

        if (HasFlag(g_iActiveBoxes, target))
        {
            DestroyBox(target);
        }
        else
        {
            ReplyToCommand(client, "%s doesn't have a active box!", name);
        }
    }

    else
    {
        ReplyToCommand(client, "Usage: sm_clearbox (name)");
    }
    return Plugin_Handled;
}

Action Command_SpawnBox(int client, int args)
{
    CreateBox(client);
}

//The creation of the box
public void CreateBox(int client)
{
    char model[PLATFORM_MAX_PATH] = "models/props/cs_office/projector.mdl";
    DataPack data;

    LoopClients(i)
    {
        if (g_cRangeEnabled.BoolValue == true)
        {
            g_iPlayer[i].InRange = false;
        }
    }

    if (!HasFlag(g_iActiveBoxes, client))
    {
        //creating entity
        int entity = CreateEntityByName("prop_physics_multiplayer");

        //getting spawnpoint of entity
        float vPos[3];
        float ang[3];
        GetClientAbsOrigin(client, vPos);
        GetClientAbsAngles(client, ang);
        vPos[0] = (vPos[0]+(16*(Cosine(DegToRad(ang[1])))));

        //Modelling entity
        PrecacheModel(model);  
        SetEntityModel(entity, model);
        SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
        SetEntityRenderColor(entity, 0, 0, 0);
        SetEntProp(entity, Prop_Send, "m_nSolidType", 6);
        SetEntProp(entity, Prop_Data, "m_takedamage", 2);
        SetEntProp(entity, Prop_Data, "m_iHealth", 1);
        DispatchKeyValue(entity, "Physics Mode", "1");

        //saving which entity belongs to a client
        g_iPlayer[client].ClientBox = entity;

        //Spawning entity at spawnpoint
        DispatchSpawn(entity);
        TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

        //add a sound to the entity
        EmitSoundToAll(SND_BOX, entity);

        //Saves that a client's entity is active, set it that the it didn't stop yet and save the client's box position.
        SetFlag(g_iActiveBoxes, client, true);
        g_iPlayer[client].BoxStoppped = false;
        g_iPlayer[client].BoxPosition = vPos;

        SetupSmoke(entity, client);

        /*
        ~ prob some bad code, since it will fog everyone even if not inrange.
        if (g_cRangeEnabled.BoolValue == false)
        {
            LoopValidClients(i)
            {
                if (IsPlayerAlive(i)  && (!BaseComm_IsClientMuted(i) || SourceComms_GetClientMuteType(i) != bNot))
                {
                    //SetClientListeningFlags(i, VOICE_MUTED);
                    g_iPlayer[i].foggedByBox = true;
                    PrintToChat(i, "You are fogged!");
                }
            }
        }
        */
        char name[32], time[16];

        FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
        GetClientName(client, name, sizeof(name));
        PrintToConsoleAll(debug ... "[%s] %s has placed a box!", time, name);

        //Timer so the box will eventually stop
        g_iPlayer[client].hBoxEnd = CreateDataTimer(g_cCeaseTime.FloatValue, Timer_JammerEnd, data);
        data.WriteCell(client);
        data.WriteCell(entity);

        //make timer that will loop the sound, if the stop time is too long 
        if (g_cCeaseTime.FloatValue > 28.0)
        {
            
            g_iPlayer[client].hLoopSound = CreateTimer(28.0, Timer_LoophLoopSound, entity, TIMER_REPEAT);
            
        }
    }

    //stops people from spamming the box
    else
    {
        PrintToChat(client, "You already have a mute box running!");
    }
}

//If the box gets destroyed it will unfog people
public void OnEntityDestroyed(int entity)
{
    //checking if the destroyed entity is a box
    LoopClients(i)
    {
        if(g_iPlayer[i].ClientBox == entity && g_iPlayer[i].BoxStoppped == false)
        {   
            //stop smoke of entity
            SetEntPropFloat(SmokeOfBox[entity], Prop_Send, "m_FadeEndTime", (0.0));

            //clear timers, like sounds and that the box already has been stopped
            TTT_ClearTimer(g_iPlayer[i].hBoxEnd);
            TTT_ClearTimer(g_iPlayer[i].hLoopSound);
            g_iPlayer[i].BoxStoppped = true;

            //stop sound and set client's box to inactive
            StopSound(entity, SNDCHAN_AUTO, SND_BOX);

            char name[32], time[16];
            GetClientName(i, name, sizeof(name));
            FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
            PrintToConsoleAll(debug ... "[%s] The box of %s has been destroyed!", time, name);
            SetFlag(g_iActiveBoxes, i, false);

            //Unfog everybody if this was the last box
            LoopValidClients(x)
            {
                if (g_iPlayer[x].foggedByBox == true && g_iActiveBoxes == 0)
                {   
                    AcceptEntityInput(g_iFog, "TurnOff");
                    g_iPlayer[x].ShowFog = false;
                    DispatchKeyValueFloat(g_iFog, "farz", 0.0);
                    g_iPlayer[x].foggedByBox = false;

                    GetClientName(x, name, sizeof(name));
                    FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
                    PrintToConsoleAll(debug ... "[%s] %s got unfogged", time, name);
                }
            } 
        }
    }      
}

//If the time of the box will run out it will stop
public Action Timer_JammerEnd(Handle timer, DataPack data)
{
    int client;
    int entity;
    
    data.Reset();
    client = data.ReadCell();
    entity = data.ReadCell();

    //clearing sound time and stop sound and set box to inactive and save that the box is stopped.
    TTT_ClearTimer(g_iPlayer[client].hLoopSound);

    char name[32], time[16];
    GetClientName(client, name, sizeof(name));
    FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
    PrintToConsoleAll(debug ... "[%s] The box of %s has been stopped!", time, name);

    SetFlag(g_iActiveBoxes, client, false);
    StopSound(entity, SNDCHAN_AUTO, SND_BOX);
    g_iPlayer[client].BoxStoppped = true;

    //Unfog everybody if this was the last box
    LoopValidClients(i)
    {
        if (g_iPlayer[i].foggedByBox == true && g_iActiveBoxes == 0)
        {

            AcceptEntityInput(g_iFog, "TurnOff");
            g_iPlayer[client].ShowFog = false;
            DispatchKeyValueFloat(g_iFog, "farz", 0.0);
            g_iPlayer[i].foggedByBox = false;

            FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
            GetClientName(i, name, sizeof(name));
            PrintToConsoleAll(debug ... "[%s] %s got unfogged", time, name);
        }
    }
}

//will keep the sound playing if the timer is longer than 28 seconds
public Action Timer_LoophLoopSound(Handle timer, int entity)
{
    EmitSoundToAll(SND_BOX, entity);
}

//Checks every game frame 
public void OnGameFrame()
{
    if (g_cRangeEnabled.BoolValue == true)
    {
        EntityPositionRefresh();

        InRangeChecker();

        InRangeFogger();
        
    }
}

//Client will be unfogged, because of death
public Action TTT_OnClientDeathPre(int client)
{
    if (g_iPlayer[client].foggedByBox == true)
    {
        char name[32], time[16];

        AcceptEntityInput(g_iFog, "TurnOff");
        g_iPlayer[client].ShowFog = false;
        DispatchKeyValueFloat(g_iFog, "farz", 0.0);
        g_iPlayer[client].foggedByBox = false;
        
        FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
        GetClientName(client, name, sizeof(name));
        PrintToConsoleAll(debug ... "[%s] %s got unfogged, because of death", time, name);
    }
}

//Checks if box position is changed and saves the new position
void EntityPositionRefresh()
{
    LoopClients(i)
    {
        if (HasFlag(g_iActiveBoxes, i))
        {
            float EntityPosition[3];
            GetEntPropVector(g_iPlayer[i].ClientBox, Prop_Send, "m_vecOrigin", EntityPosition);
            for (int x = 0; x <= 2; x++)
            {
                if (EntityPosition[x] != g_iPlayer[i].BoxPosition[x])
                {
                    g_iPlayer[i].BoxPosition = EntityPosition;

                    //keep the smoke on the new position of the box
                    TeleportEntity(SmokeOfBox[g_iPlayer[i].ClientBox], EntityPosition, NULL_VECTOR, NULL_VECTOR);
                }
            }
        }
    }
}

//Checks if people are in or out range of all boxes
void InRangeChecker()
{
    float cPos[3];
    //Y = the client that is inrange or out range
    LoopValidClients(y)
    {
        GetClientAbsOrigin(y, cPos);
        //X = the client that might have a running box
        LoopValidClients(x)
        {
            //If Y is inrange of any box it will save it and go to the next Y, else it will save Y is inrange and goes to the next Y
            float Distance = GetVectorDistance(cPos, g_iPlayer[x].BoxPosition);
            if (Distance <= g_cFogRange.IntValue && HasFlag(g_iActiveBoxes, x))
            {
                g_iPlayer[y].InRange = true;
                break;
            }

            else
            {
                g_iPlayer[y].InRange = false;
            }
        }
    }
}

//If client is inrange it will fog and if out range it will unfog
void InRangeFogger()
{
    LoopValidClients(i)
    {
        if (g_iPlayer[i].foggedByBox == false && IsPlayerAlive(i) && g_iPlayer[i].InRange == true /*&& !BaseComm_IsClientMuted(i)  && SourceComms_GetClientMuteType(i) != bNot*/ )
        {
            char name[32], time[16];

            AcceptEntityInput(g_iFog, "TurnOn");
            g_iPlayer[i].ShowFog = true;
            SDKHook(g_iFog, SDKHook_SetTransmit, Hook_SetTransmit);
            DispatchKeyValueFloat(g_iFog, "farz", 125.0);
            g_iPlayer[i].foggedByBox = true;

            FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
            GetClientName(i, name, sizeof(name));
            PrintToConsoleAll(debug ... "[%s] %s got fogged, because in the range of the box", time, name);
        }

        else if (g_iPlayer[i].foggedByBox == true && g_iPlayer[i].InRange == false && g_iPlayer[i].foggedByBox == true)
        {
            char name[32], time[16];

            AcceptEntityInput(g_iFog, "TurnOff");
            g_iPlayer[i].ShowFog = false;
            SDKHook(g_iFog, SDKHook_SetTransmit, Hook_SetTransmit);
            DispatchKeyValueFloat(g_iFog, "farz", 0.0);
            g_iPlayer[i].foggedByBox = false;

            FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
            GetClientName(i, name, sizeof(name));
            PrintToConsoleAll(debug ... "[%s] %s got unfogged, because out of the range of the box", time, name);
        }
    }
}

//Sets a client's settings to default
void ClientReset(int client)
{
    AcceptEntityInput(g_iFog, "TurnOff");
    g_iPlayer[client].ShowFog = false;
    DispatchKeyValueFloat(g_iFog, "farz", 0.0);
    TTT_ClearTimer(g_iPlayer[client].hBoxEnd);
    TTT_ClearTimer(g_iPlayer[client].hLoopSound);


    g_iPlayer[client].foggedByBox = false;
    SetFlag(g_iActiveBoxes, client, false);
    g_iPlayer[client].BoxStoppped = true;
}

//destroys/clears the box of the client
void DestroyBox(int client)
{
    char name[32], time[16];
    AcceptEntityInput(g_iPlayer[client].ClientBox, "Kill");

    ClientReset(client);

    StopSound(g_iPlayer[client].ClientBox, SNDCHAN_AUTO, SND_BOX);

    FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
    GetClientName(client, name, sizeof(name));
    PrintToConsoleAll(debug ... "[%s] The box of %s has been Removed!", time, name);
}

//custom flag setters and checkers
bool HasFlag(int flag, int index)
{
    return flag & (1 << index) != 0;
}

bool SetFlag(int &flag, int index, bool value)
{
    if (value)
    {
        flag |= (1 << index);
    }
    else
    {
        flag &= ~(1 << index);
    }
}

////Creation, modeling and spawning of the smoke
void SetupSmoke(int entity, int client)
{   
    //creating and modeling smoke
    int SmokeIndex = CreateEntityByName("env_particlesmokegrenade" );
    SetEntProp(SmokeIndex, Prop_Send, "m_CurrentStage", 2);

    //setting time when smokes starts and stops
    SetEntPropFloat(SmokeIndex, Prop_Send, "m_FadeStartTime", 0.0);
    SetEntPropFloat(SmokeIndex, Prop_Send, "m_FadeEndTime", (g_cCeaseTime.FloatValue+5.0));

    //spawning at client's entity
    DispatchSpawn(SmokeIndex);
    ActivateEntity(SmokeIndex);
    TeleportEntity(SmokeIndex, g_iPlayer[client].BoxPosition, NULL_VECTOR, NULL_VECTOR);

    //save which smoke belongs to which entity
    SmokeOfBox[entity] = SmokeIndex;
}

//Creation, modeling of the fog
void SetupBlackout()
{
    if(IsValidEntity(g_iFog))
    {
        DispatchSpawn(g_iFog);
        DispatchKeyValue(g_iFog, "fogblend", "0");
        DispatchKeyValue(g_iFog, "fogcolor", "0 0 0");
        DispatchKeyValue(g_iFog, "fogcolor2", "0 0 0");
        DispatchKeyValueFloat(g_iFog, "fogstart", 0.0);
        DispatchKeyValueFloat(g_iFog, "fogend", 100.0);
        DispatchKeyValueFloat(g_iFog, "fogmaxdensity", 1.0);
        DispatchKeyValueFloat(g_iFog, "farz", 0.0);
        AcceptEntityInput(g_iFog, "TurnOff");
        SDKHook(g_iFog, SDKHook_SetTransmit, Hook_SetTransmit);
    }
}

//denies Fog for people out of the range.
public Action Hook_SetTransmit(int entity, int client) 
{
    char time[16];
    FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
    PrintToConsoleAll(debug ... "[%s] SetTransmit has been reached!", time);
    if(!g_iPlayer[client].ShowFog)
    {
		return Plugin_Stop;
    }
    return Plugin_Continue;
}

//A native so you can use this plugin in other plugin
public int Native_CreateBox(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!TTT_IsClientValid(client))
    {
        PrintToServer("Invalid client (%d)", client);
        return;
    }
    CreateBox(client);
}