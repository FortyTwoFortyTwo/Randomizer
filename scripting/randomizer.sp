#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf_econ_data>
#include <tf2attributes>
#include <dhooks>

#pragma newdecls required

#define TF_MAXPLAYERS 32

#define CLASS_MIN	1	//First valid TFClassType, Scout
#define CLASS_MAX	9	//Last valid TFClassType, Engineer

#define ITEM_PDA_BUILD		25
#define ITEM_PDA_DESTROY	26
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

ArrayList g_aIndexList[WeaponSlot_BuilderEngie+1];
ArrayList g_aHud;

TFClassType g_iClientClass[TF_MAXPLAYERS+1];
int g_iClientWeaponIndex[TF_MAXPLAYERS+1][WeaponSlot_BuilderEngie+1];

#include "randomizer/hud.sp"
#include "randomizer/config.sp"
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
	RegAdminCmd("weapon", Command_Weapon, ADMFLAG_CHANGEMAP);
	RegAdminCmd("generate", Command_Generate, ADMFLAG_CHANGEMAP);
	
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_PlayerInventoryUpdate);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	SDK_Init();
	SDK_EnableDetour();
	
	Config_InitTemplates();
	Config_LoadTemplates();
	
	CreateWeaponList();
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_iClientClass[iClient] = TFClass_Unknown;
		
		for (int iSlot = 0; iSlot < sizeof(g_iClientWeaponIndex[]); iSlot++)
			g_iClientWeaponIndex[iClient][iSlot] = -1;
		
		if (IsClientInGame(iClient))
			OnClientPutInServer(iClient);
	}
}
/*
public void OnPluginEnd()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			
		}
	}
}
*/
public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_PreThink, Hud_ClientDisplay);
	SDKHook(iClient, SDKHook_PreThink, Weapons_ClientThink);
	
	GenerateRandonWeapon(iClient);
}

public void CreateWeaponList()
{
	for (int iSlot = 0; iSlot < sizeof(g_aIndexList); iSlot++)
	{
		if (g_aIndexList[iSlot] != null)
			delete g_aIndexList[iSlot];
		
		g_aIndexList[iSlot] = TF2Econ_GetItemList(FilterTF2EconSlot, iSlot);
	}
}

public bool FilterTF2EconSlot(int iIndex, int iSlot)
{
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		if (TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass)) == iSlot)
		{
			//Make sure weapon is not in any of blacklists
			
			//Attributes
			ArrayList aAttrib = TF2Econ_GetItemStaticAttributes(iIndex);
			int iAttribLength = aAttrib.Length;
			for (int i = 0; i < iAttribLength; i++)	//Loop through all attribs index have
			{
				int iAttrib = aAttrib.Get(i, 0);	//0 is Attrib index, 1 is value of attrib
				int iBlacklistLength = g_aBlacklistAttrib.Length;
				for (int j = 0; j < iBlacklistLength; j++)	//Loop through all blacklist attribs
				{
					if (iAttrib == g_aBlacklistAttrib.Get(j))
					{
						delete aAttrib;
						return false;
					}
				}
			}
			
			delete aAttrib;
			
			//Classname
			char sClassname[256];
			TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
			int iBlacklistLength = g_aBlacklistClassname.Length;
			for (int i = 0; i < iBlacklistLength; i++)
			{
				char sBuffer[CONFIG_MAXCHAR];
				g_aBlacklistClassname.GetString(i, sBuffer, sizeof(sBuffer));
				if (StrEqual(sClassname, sBuffer, false))
					return false;
			}
			
			//Names
			char sName[256];
			TF2Econ_GetItemName(iIndex, sName, sizeof(sName));
			iBlacklistLength = g_aBlacklistName.Length;
			for (int i = 0; i < iBlacklistLength; i++)
			{
				char sBuffer[CONFIG_MAXCHAR];
				g_aBlacklistName.GetString(i, sBuffer, sizeof(sBuffer));
				if (StrContains(sName, sBuffer, false) > -1)
					return false;
			}
			
			//Index
			iBlacklistLength = g_aBlacklistIndex.Length;
			for (int i = 0; i < iBlacklistLength; i++)
				if (iIndex == g_aBlacklistIndex.Get(i))
					return false;
			
			//Should be safe to add list after reaching here
			//LogMessage("Adding Weapon | Index %d | Slot %d | Name %s", iIndex, iSlot, sName);
			return true;
		}
	}
	
	return false;
}

public void GenerateRandonWeapon(int iClient)
{
	//Random Class
	g_iClientClass[iClient] = view_as<TFClassType>(GetRandomInt(CLASS_MIN, CLASS_MAX));
	//TF2_SetPlayerClass(iClient, g_iClientClass[iClient]);
	SetEntProp(iClient, Prop_Send, "m_iDesiredPlayerClass", view_as<int>(g_iClientClass[iClient]));
	
	for (int iSlot = 0; iSlot < sizeof(g_iClientWeaponIndex[]); iSlot++)
			g_iClientWeaponIndex[iClient][iSlot] = -1;
		
	//Random Weapon
	for (int iSlot = 0; iSlot <= WeaponSlot_Melee; iSlot++)
	{
		if (g_aIndexList[iSlot].Length <= 0)
			ThrowError("[randomizer] Index list slot %d is empty!", iSlot);
		
		int iRandom = GetRandomInt(0, g_aIndexList[iSlot].Length-1);
		int iIndex = g_aIndexList[iSlot].Get(iRandom);
		
		g_iClientWeaponIndex[iClient][iSlot] = iIndex;
		
		//If Wrench or Gunslinger, give building tools aswell
		//TODO config support?
		char sClassname[256];
		TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
		if (StrEqual(sClassname, "tf_weapon_wrench") || StrEqual(sClassname, "tf_weapon_robot_arm"))
		{
			g_iClientWeaponIndex[iClient][WeaponSlot_PDABuild] = ITEM_PDA_BUILD;
			g_iClientWeaponIndex[iClient][WeaponSlot_PDADestroy] = ITEM_PDA_DESTROY;
			g_iClientWeaponIndex[iClient][WeaponSlot_BuilderEngie] = ITEM_PDA_TOOLBOX;
		}
	}
	
	//Reset Gas Passer meter
	//TODO config support?
	SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, 1);
	
	if (IsPlayerAlive(iClient))
		TF2_RespawnPlayer(iClient);
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
	
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		TF2_RemoveItemInSlot(iClient, iSlot);
		
		int iIndex = g_iClientWeaponIndex[iClient][iSlot];
		if (iIndex < 0)
			continue;
		
		//Create weapon
		TF2_CreateAndEquipWeapon(iClient, iIndex, iSlot);
	}
}

public Action Event_PlayerHurt(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	int iDamageAmount = event.GetInt("damageamount");
	
	if (iClient <= 0 || iClient > MaxClients || iAttacker <= 0 || iAttacker > MaxClients) return;
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator || TF2_GetClientTeam(iAttacker) <= TFTeam_Spectator) return;
	if (iClient == iAttacker) return;
	
	//Fill Gas Meter
	float flMeter = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 1);
	if (0.0 < flMeter < 100.0)
	{
		flMeter += iDamageAmount / ITEM_GASPASSER_METER_DAMAGE * 100.0;
		if (flMeter > 100.0) flMeter = 100.0;
		SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", flMeter, 1);
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

public Action Command_Weapon(int iClient, int iArgs)
{
	if (iArgs <= 1) return Plugin_Handled;
	
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