#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <basecomm>
#include <voiceannounce_ex>
#include <ttt>

#pragma newdecls required

//Definitions
#define SND_Jammer "ttt_clwo/ECM Jammer Sound Effect.mp3"
#define debug "[DEBUG] "
#define MAXENTITIES 2048

//flag and entity, general nums 
int g_iActiveRadios = 0;

enum struct PlayerData 
{
    //Nums
    int ClientRadio;
    float RadioPosition[3];

    //Bools
    bool InRange;
    bool MutedByRadio;
    bool RadioStoppped;
    bool Muted;
    bool UsedMic;

    //Timers
    Handle hRadioEnd;
    Handle hLoopSound;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

//Convars
ConVar g_cRangeEnabled = null;
ConVar g_cMuteRange = null;
ConVar g_cCeaseTime = null;
 
public Plugin myinfo =
{
    name = "RadioJammer",
    author = "MarsTwix & C0rp3n",
    description = "A radio that jams player's mics, like in payday 2",
    version = "1.0.0",
    url = "clwo.eu"
};
 
public void OnPluginStart()
{
    LoadTranslations("common.phrases.txt");
    g_cRangeEnabled = AutoExecConfig_CreateConVar("ttt_radio_jammer_range_enable", "1", "Sets whether range of the radio jammer is enabled");
    g_cMuteRange = AutoExecConfig_CreateConVar("ttt_radio_jammer_mute_range", "1000", "The range within a player get muted by the radio jammer");
    g_cCeaseTime = AutoExecConfig_CreateConVar("ttt_radio_jammer_cease_time", "10.0", "The time the radio jammer stops working");

    RegConsoleCmd("sm_spawnradio", Command_SpawnRadio, "Spawns a Radio Jammer");
    RegConsoleCmd("sm_clearradio", Command_ClearRadio, "Clears a Radio Jammer of a client");

    RegConsoleCmd("sm_vars", Command_Vars, "Show variables of client or given target");

    HookEvent("round_end", Event_RoundEnd);
}

public void OnMapStart()
{
    PrecacheSound(SND_Jammer);

    LoopClients(i)
    {
        SetFlag(g_iActiveRadios, i, false);
        g_iPlayer[i].MutedByRadio = false;
        g_iPlayer[i].RadioStoppped = true;
        g_iPlayer[i].InRange = false;
        g_iPlayer[i].UsedMic = false;
    }
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    LoopClients(i)
    {
        ClientReset(i);
        if (HasFlag(g_iActiveRadios, i) == true)
        {
            DestroyRadio(i);
        }
    }

}

public void OnClientPutInServer(int client)
{
    g_iPlayer[client].hRadioEnd = INVALID_HANDLE;
    g_iPlayer[client].hLoopSound = INVALID_HANDLE;
    ClientReset(client);
}

Action Command_Vars(int client, int args)
{
    if (args == 0)
    {
        char name[32];
        GetClientName(client, name, sizeof(name));
        PrintToConsoleAll("Varaibles of %s:", name);
        PrintToConsoleAll("InRange: %b", g_iPlayer[client].InRange);
        PrintToConsoleAll("MutedByRadio: %b", g_iPlayer[client].MutedByRadio);
    
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
        PrintToConsoleAll("MutedByRadio: %b", g_iPlayer[target].MutedByRadio);
    }
    else
    {
        ReplyToCommand(client, "Usage: sm_vars (name)");
    }
    return Plugin_Handled;
}

Action Command_ClearRadio(int client, int args)
{
    if (args == 0)
    {
        if (HasFlag(g_iActiveRadios, client))
        {
            DestroyRadio(client);
        }
        else
        {
            ReplyToCommand(client, "You don't have a active jammer!");
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

        if (HasFlag(g_iActiveRadios, target))
        {
            DestroyRadio(target);
        }
        else
        {
            ReplyToCommand(client, "%s doesn't have a active jammer!", name);
        }
    }

    else
    {
        ReplyToCommand(client, "Usage: sm_clearradio (name)");
    }
    return Plugin_Handled;
}

Action Command_SpawnRadio(int client, int args)
{
    CreateJammer(client);
}

//The creation of the jammer
public void CreateJammer(int client)
{
    char model[PLATFORM_MAX_PATH] = "models/props/cs_office/radio.mdl";
    DataPack data;

    LoopClients(i)
    {
        if (g_cRangeEnabled.BoolValue == true)
        {
            g_iPlayer[i].InRange = false;
        }
    }

    if (!HasFlag(g_iActiveRadios, client))
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
        SetEntProp(entity, Prop_Send, "m_nSolidType", 6);
        SetEntProp(entity, Prop_Data, "m_takedamage", 2);
        SetEntProp(entity, Prop_Data, "m_iHealth", 1);
        DispatchKeyValue(entity, "Physics Mode", "1");

        //saving which entity belongs to a client
        g_iPlayer[client].ClientRadio = entity;

        //Spawning entity at spawnpoint
        DispatchSpawn(entity);
        TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

        //add a sound to the entity
        EmitSoundToAll(SND_Jammer, entity);

        //Saves that a client's entity is active, set it that the it didn't stop yet and save the client's jammer position.
        SetFlag(g_iActiveRadios, client, true);
        g_iPlayer[client].RadioStoppped = false;
        g_iPlayer[client].RadioPosition = vPos;

        if (g_cRangeEnabled.BoolValue == false)
        {
            LoopValidClients(i)
            {
                if (IsPlayerAlive(i) && (!BaseComm_IsClientMuted(i) /*|| SourceComms_GetClientMuteType(i) != bNot*/))
                {
                    SetClientListeningFlags(i, VOICE_MUTED);
                    g_iPlayer[i].MutedByRadio = true;
                    PrintHintText(i, "You are muted by a radio jammer, try to destroy it!");
                }
            }
        }
        char name[32], time[16];

        FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
        GetClientName(client, name, sizeof(name));
        PrintToConsoleAll(debug ... "[%s] %s has placed a jammer!", time, name);

        //Timer so the jammer will eventually stop
        g_iPlayer[client].hRadioEnd = CreateDataTimer(g_cCeaseTime.FloatValue, Timer_JammerEnd, data);
        data.WriteCell(client);
        data.WriteCell(entity);

        //make timer that will loop the sound, if the stop time is too long 
        if (g_cCeaseTime.FloatValue > 28.0)
        {
            
            g_iPlayer[client].hLoopSound = CreateTimer(28.0, Timer_LoophLoopSound, entity, TIMER_REPEAT);
            
        }
    }

    //stops people from spamming the jammer
    else
    {
        PrintToChat(client, "You already have a mute jammer running!");
    }
}

//If the jammer gets destroyed it will unfog people
public void OnEntityDestroyed(int entity)
{
    //checking if the destroyed entity is a jammer
    LoopClients(i)
    {
        if(g_iPlayer[i].ClientRadio == entity && g_iPlayer[i].RadioStoppped == false)
        {   
            //clear timers, like sounds and that the jammer already has been stopped
            TTT_ClearTimer(g_iPlayer[i].hRadioEnd);
            TTT_ClearTimer(g_iPlayer[i].hLoopSound);
            g_iPlayer[i].RadioStoppped = true;

            //stop sound and set client's jammer to inactive
            StopSound(entity, SNDCHAN_AUTO, SND_Jammer);

            char name[32], time[16];
            GetClientName(i, name, sizeof(name));
            FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
            PrintToConsoleAll(debug ... "[%s] The jammer of %s has been destroyed!", time, name);
            SetFlag(g_iActiveRadios, i, false);

            //Unfog everybody if this was the last jammer
            LoopValidClients(x)
            {
                if (g_iPlayer[x].MutedByRadio == true && g_iActiveRadios == 0)
                {   
                    SetClientListeningFlags(x, VOICE_NORMAL);
                    PrintHintText(x, "");
                    g_iPlayer[x].MutedByRadio = false;

                    GetClientName(x, name, sizeof(name));
                    FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
                    PrintToConsoleAll(debug ... "[%s] %s got unmuted", time, name);
                }
            } 
        }
    }      
}

//If the time of the jammer will run out it will stop
public Action Timer_JammerEnd(Handle timer, DataPack data)
{
    int client;
    int entity;
    
    data.Reset();
    client = data.ReadCell();
    entity = data.ReadCell();

    //clearing sound time and stop sound and set jammer to inactive and save that the jammer is stopped.
    TTT_ClearTimer(g_iPlayer[client].hLoopSound);

    char name[32], time[16];
    GetClientName(client, name, sizeof(name));
    FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
    PrintToConsoleAll(debug ... "[%s] The jammer of %s has been stopped!", time, name);

    SetFlag(g_iActiveRadios, client, false);
    StopSound(entity, SNDCHAN_AUTO, SND_Jammer);
    g_iPlayer[client].RadioStoppped = true;

    //Unfog everybody if this was the last jammer
    LoopValidClients(i)
    {
        if (g_iPlayer[i].MutedByRadio == true && g_iActiveRadios == 0)
        {
            SetClientListeningFlags(i, VOICE_NORMAL);
            PrintHintText(client, "");
            g_iPlayer[i].MutedByRadio = false;

            FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
            GetClientName(i, name, sizeof(name));
            PrintToConsoleAll(debug ... "[%s] %s got unmuted", time, name);
        }
    }
}

//will keep the sound playing if the timer is longer than 28 seconds
public Action Timer_LoophLoopSound(Handle timer, int entity)
{
    EmitSoundToAll(SND_Jammer, entity);
}

//Checks every game frame 
public void OnGameFrame()
{
    if (g_cRangeEnabled.BoolValue == true)
    {
        EntityPositionRefresh();

        InRangeChecker();

        InRangeMuter();
        
    }
    LoopValidClients(i)
    {
        if (g_iPlayer[i].MutedByRadio)
        {
            PrintHintText(i, "You are muted by a radio jammer, try to destroy it!");
        }
    }
}

//Client will be unmuted, because of death
public Action TTT_OnClientDeathPre(int client)
{
    if (g_iPlayer[client].MutedByRadio == true)
    {
        SetClientListeningFlags(client, VOICE_NORMAL);
        PrintHintText(client, "");
        g_iPlayer[client].MutedByRadio = false;

        char name[32], time[16];
        FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
        GetClientName(client, name, sizeof(name));
        PrintToConsoleAll(debug ... "[%s] %s got unmuted, because of death", time, name);
    }
}

//Checks if jammer position is changed and saves the new position
void EntityPositionRefresh()
{
    LoopClients(i)
    {
        if (HasFlag(g_iActiveRadios, i))
        {
            float EntityPosition[3];
            GetEntPropVector(g_iPlayer[i].ClientRadio, Prop_Send, "m_vecOrigin", EntityPosition);
            for (int x = 0; x <= 2; x++)
            {
                if (EntityPosition[x] != g_iPlayer[i].RadioPosition[x])
                {
                    g_iPlayer[i].RadioPosition = EntityPosition;
                }
            }
        }
    }
}

//Checks if people are in or out range of all jammeres
void InRangeChecker()
{
    float cPos[3];
    //Y = the client that is inrange or out range
    LoopValidClients(y)
    {
        GetClientAbsOrigin(y, cPos);
        //X = the client that might have a running jammer
        LoopValidClients(x)
        {
            //If Y is inrange of any jammer it will save it and go to the next Y, else it will save Y is inrange and goes to the next Y
            float Distance = GetVectorDistance(cPos, g_iPlayer[x].RadioPosition);
            if (Distance <= g_cMuteRange.IntValue && HasFlag(g_iActiveRadios, x))
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
void InRangeMuter()
{
    LoopValidClients(i)
    {
        if (g_iPlayer[i].MutedByRadio == false && IsPlayerAlive(i) && g_iPlayer[i].InRange == true && !BaseComm_IsClientMuted(i) /*&& SourceComms_GetClientMuteType(i) != bNot*/ )
        {
            SetClientListeningFlags(i, VOICE_MUTED);
            g_iPlayer[i].MutedByRadio = true;
            PrintHintText(i, "You are muted by a radio jammer, try to destroy it!");

            char name[32], time[16];
            FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
            GetClientName(i, name, sizeof(name));
            PrintToConsoleAll(debug ... "[%s] %s got muted, because in the range of the jammer", time, name);
        }

        else if (g_iPlayer[i].MutedByRadio == true && g_iPlayer[i].InRange == false)
        {
            g_iPlayer[i].MutedByRadio = false;
            SetClientListeningFlags(i, VOICE_NORMAL);
            PrintHintText(i, "");
               
            char name[32], time[16];
            FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
            GetClientName(i, name, sizeof(name));
            PrintToConsoleAll(debug ... "[%s] %s got unmuted, because out of the range of the jammer", time, name);
        }
    }
}

public void OnClientSpeakingEx(int client)
{
    if (g_iPlayer[client].MutedByRadio == true && g_iPlayer[client].UsedMic == false)
    {
        EmitSoundToClient(client, SND_Jammer);
        g_iPlayer[client].UsedMic = true;
    }
}

public void OnClientSpeakingEnd(int client)
{
    if (g_iPlayer[client].UsedMic == true)
    {    
        StopSound(client, SNDCHAN_AUTO, SND_Jammer);
        g_iPlayer[client].UsedMic = false;
    }
}

//Sets a client's settings to default
void ClientReset(int client)
{
    TTT_ClearTimer(g_iPlayer[client].hRadioEnd);
    TTT_ClearTimer(g_iPlayer[client].hLoopSound);

    g_iPlayer[client].MutedByRadio = false;
    SetFlag(g_iActiveRadios, client, false);
    g_iPlayer[client].RadioStoppped = true;
}

//destroys/clears the jammer of the client
void DestroyRadio(int client)
{
    char name[32], time[16];
    AcceptEntityInput(g_iPlayer[client].ClientRadio, "Kill");

    ClientReset(client);

    StopSound(g_iPlayer[client].ClientRadio, SNDCHAN_AUTO, SND_Jammer);

    FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
    GetClientName(client, name, sizeof(name));
    PrintToConsoleAll(debug ... "[%s] The jammer of %s has been Removed!", time, name);
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

//A native so you can use this plugin in other plugin
public int Native_CreateRadio(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!TTT_IsClientValid(client))
    {
        PrintToServer("Invalid client (%d)", client);
        return;
    }
    CreateRadio(client);
}