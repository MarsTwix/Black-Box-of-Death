#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <basecomm>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#include <colorlib>
#include <sourcecomms>
#undef REQUIRE_PLUGIN
#include <blackboxofdeath_core>

#pragma newdecls required

#define SHORT_NAME "Black Box Of Death"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Black Box Of Death"
#define PLUGIN_AUTHOR "Marstix & C0RP3N"
#define PLUGIN_DESCRIPTION "This plugin fogs people who are in range, exclusive to the ones that are immune to the fog and you can buy it in the shop"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "clwo.eu"


//the sound for the radiojammer
#define SOUND_JAMMER "ttt_clwo/ECM Jammer Sound Effect.mp3"

//shop convars
ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cLongName = null;
ConVar g_cCount = null;
ConVar g_cActivation = null;
ConVar g_cLimit = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version = PLUGIN_VERSION,
    url = PLUGIN_URL
};
 
public void OnPluginStart()
{
    TTT_IsGameCSGO();
    TTT_LoadTranslations();
   
    TTT_StartConfig("radioJammer");
    CreateConVar("ttt2_RadioJammer_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("ttt_radio_jammer_name", "RadioJammer", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("ttt_radio_jammer_price", "1000", "The amount of credits RadioJammer costs as traitor. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("ttt_radio_jammer_sort_prio", "0", "The sorting priority of the RadioJammer in the shop menu.");
    g_cCount = AutoExecConfig_CreateConVar("ttt_radio_jammer_count", "3", "Amount of RadioJammer purchases per round");
    g_cActivation = AutoExecConfig_CreateConVar("ttt_radio_jammer_activation_mode", "1", "Which activation mode? 0 - New, over !inventory menu; 1 - Old, on purchase", _, true, 0.0, true, 1.0);
    g_cLimit = AutoExecConfig_CreateConVar("ttt_radio_jammer_station_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    TTT_EndConfig();
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME);
    }
}

public void TTT_OnVersionReceive(int version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetPluginVersion());
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

    RegisterItem();
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public void OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sName[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sName, sizeof(sName));
   
    TTT_RegisterShopItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);
}
 
public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        if (StrEqual(itemshort, SHORT_NAME, false))
        {
            int role = TTT_GetClientRole(client);
           
            if (role != TTT_TEAM_TRAITOR)
            {
                return Plugin_Stop;
            }
           
            if (g_cActivation.IntValue == 0)
            {
                TTT_AddInventoryItem(client, SHORT_NAME);
            }
            else if (g_cActivation.IntValue == 1)
            {
                TTT_AddItemUsage(client, SHORT_NAME);
                CreateBox(client);
            }
        }
    }
    return Plugin_Continue;
}

public void TTT_OnInventoryMenuItemSelect(int client, const char[] itemshort)
{
    if (StrEqual(itemshort, SHORT_NAME, false))
    {
        CreateBox(client);
    }
}
