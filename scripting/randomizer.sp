#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf_econ_data>
#include <dhooks>

#pragma newdecls required

#define TF_MAXPLAYERS 32

#define CLASS_MIN	1	//First valid TFClassType, Scout
#define CLASS_MAX	9	//Last valid TFClassType, Engineer

#define ITEM_PDA_BUILD		25
#define ITEM_PDA_DESTROY	26
#define ITEM_PDA_DISGUISE	27
#define ITEM_PDA_TOOLBOX	28

#define ATTRIB_AIR_DASH_COUNT			250

enum
{
	WeaponSlot_Primary = 0,
	WeaponSlot_Secondary,
	WeaponSlot_Melee,
	WeaponSlot_PDABuild,
	WeaponSlot_PDADisguise = 3,
	WeaponSlot_PDADestroy,
	WeaponSlot_InvisWatch = 4,
	WeaponSlot_BuilderEngie,
	WeaponSlot_Unknown1,
	WeaponSlot_Head,
	WeaponSlot_Misc1,
	WeaponSlot_Action,
	WeaponSlot_Misc2
};

enum
{
	TF_AMMO_DUMMY = 0,	// Dummy index to make the CAmmoDef indices correct for the other ammo types.
	TF_AMMO_PRIMARY,
	TF_AMMO_SECONDARY,
	TF_AMMO_METAL,
	TF_AMMO_GRENADES1,
	TF_AMMO_GRENADES2,
	TF_AMMO_COUNT
};

TFClassType g_iClientClass[TF_MAXPLAYERS+1];
int g_iClientWeaponIndex[TF_MAXPLAYERS+1][WeaponSlot_BuilderEngie+1];

#include "randomizer/config.sp"
#include "randomizer/huds.sp"
#include "randomizer/sdk.sp"
#include "randomizer/stocks.sp"
#include "randomizer/weapons.sp"

public Plugin myinfo =
{
	name = "Randomizer",
	author = "42",
	description = "",
	version = "0.0.0",
	url = "",
};

public void OnPluginStart()
{
	RegAdminCmd("class", Command_Class, ADMFLAG_CHANGEMAP);
	RegAdminCmd("weapon", Command_Weapon, ADMFLAG_CHANGEMAP);
	RegAdminCmd("generate", Command_Generate, ADMFLAG_CHANGEMAP);
	
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_PlayerInventoryUpdate);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	SDK_Init();
	
	Config_Init();
	Huds_Init();
	Weapons_Init();
	
	Config_Refresh();
	Huds_Refresh();
	Weapons_Refresh();
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_iClientClass[iClient] = TFClass_Unknown;
		
		for (int iSlot = 0; iSlot < sizeof(g_iClientWeaponIndex[]); iSlot++)
			g_iClientWeaponIndex[iClient][iSlot] = -1;
		
		if (IsClientInGame(iClient))
			OnClientPutInServer(iClient);
	}
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_PreThink, Huds_ClientDisplay);
	SDK_HookClient(iClient);
	
	GenerateRandonWeapon(iClient);
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (StrContains(sClassname, "tf_weapon_") == 0)
		SDK_HookWeapon(iEntity);
}

public void GenerateRandonWeapon(int iClient)
{
	//Random Class
	g_iClientClass[iClient] = view_as<TFClassType>(GetRandomInt(CLASS_MIN, CLASS_MAX));
	SetEntProp(iClient, Prop_Send, "m_iDesiredPlayerClass", view_as<int>(g_iClientClass[iClient]));
	
	//Random Weapon
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
		g_iClientWeaponIndex[iClient][iSlot] = Weapons_GetRandomIndex(iSlot, g_iClientClass[iClient]);
	
	if (IsPlayerAlive(iClient))
	{
		TF2_RespawnPlayer(iClient);
		
		//If invalid active weapon, use primary weapon, otherwise secondary etc
		if (GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") <= MaxClients)
		{
			for (int iSlot = 0; iSlot <= WeaponSlot_Melee; iSlot++)
			{
				int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
				if (iWeapon > MaxClients)
				{
					SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
					break;
				}
			}
		}
	}
}

public Action Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	//New round, generate new weapons for everyone
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient))
			GenerateRandonWeapon(iClient);
}

public Action Event_PlayerSpawn(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
	TFClassType iClass = TF2_GetPlayerClass(iClient);
	
	//If client is playing incorrect class, set as that class
	if (iClass != g_iClientClass[iClient])
	{
		TF2_SetPlayerClass(iClient, g_iClientClass[iClient]);
		TF2_RespawnPlayer(iClient);
	}
}

public Action Event_PlayerInventoryUpdate(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
	for (int iSlot = 0; iSlot < WeaponSlot_BuilderEngie; iSlot++)	//Generating tf_weapon_builder is weird, allow engi keeps it
	{
		//Allow player keep weapon if same index
		int iWeapon = TF2_GetItemInSlot(iClient, iSlot);
		if (iWeapon > MaxClients && GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") == g_iClientWeaponIndex[iClient][iSlot])
			continue;
		
		TF2_RemoveItemInSlot(iClient, iSlot);
		
		//Create weapon
		if (g_iClientWeaponIndex[iClient][iSlot] >= 0)
			TF2_CreateAndEquipWeapon(iClient, g_iClientWeaponIndex[iClient][iSlot], iSlot);
	}
}

public Action Event_PlayerDeath(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	
	//Only generate new weapons if killed from attacker
	if (0 < iAttacker <= MaxClients && IsClientInGame(iAttacker) && iClient != iAttacker)
		RequestFrame(GenerateRandonWeapon, iClient);	//Can be buggy if done same frame as death
}

public Action Command_Class(int iClient, int iArgs)
{
	if (iArgs <= 0)
		return Plugin_Handled;
	
	char sClass[32];
	GetCmdArg(1, sClass, sizeof(sClass));
	TFClassType nClass = TF2_GetClass(sClass);
	if (nClass == TFClass_Unknown)
		return Plugin_Handled;
	
	g_iClientClass[iClient] = nClass;
	TF2_SetPlayerClass(iClient, nClass);
	
	if (IsPlayerAlive(iClient))
		TF2_RespawnPlayer(iClient);
	
	return Plugin_Handled;
}

public Action Command_Weapon(int iClient, int iArgs)
{
	if (iArgs <= 1)
		return Plugin_Handled;
	
	char sArg1[256], sArg2[256];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	
	g_iClientWeaponIndex[iClient][StringToInt(sArg1)] = StringToInt(sArg2);
	
	return Plugin_Handled;
}

public Action Command_Generate(int iClient, int iArgs)
{
	GenerateRandonWeapon(iClient);
	TF2_RespawnPlayer(iClient);
}

KeyValues LoadConfig(const char[] sFilepath, const char[] sName)
{
	char sConfigPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigPath, sizeof(sConfigPath), sFilepath);
	if(!FileExists(sConfigPath))
	{
		LogError("Failed to load Randomizer %s config file (file missing): %s", sName, sConfigPath);
		return null;
	}
	
	KeyValues kv = new KeyValues(sName);
	kv.SetEscapeSequences(true);

	if(!kv.ImportFromFile(sConfigPath))
	{
		LogError("Failed to parse Randomizer %s config file: %s", sName, sConfigPath);
		delete kv;
		return null;
	}
	
	return kv;
}