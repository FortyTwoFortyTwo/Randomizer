#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf_econ_data>
#include <tf2attributes>

#pragma newdecls required

#define TF_MAXPLAYERS 32

#define CLASS_MIN	1	//First valid TFClassType, Scout
#define CLASS_MAX	9	//Last valid TFClassType, Engineer

#define ITEM_PDA_BUILD		25
#define ITEM_PDA_DESTROY	26
#define ITEM_PDA_TOOLBOX	28

//Ammo attributes
#define ATTRIB_AMMO_SECONDARY_HIDDEN	25
#define ATTRIB_AMMO_PRIMARY_HIDDEN		37
//#define ATTRIB_AMMO_PRIMARY_BONUS		76
//#define ATTRIB_AMMO_PRIMARY_PENALTY	77
//#define ATTRIB_AMMO_SECONDARY_BONUS	78
//#define ATTRIB_AMMO_SECONDARY_PENALTY	79
#define ATTRIB_MAX_METAL				80

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

//Base Max Ammo for each 9 class, primary and secondary
int g_iClassMaxAmmo[][2] = {
	{-1, -1},	// Unknown
	{32, 36},	// Scout
	{25, 75},	// Sniper
	{20, 32},	// Soldier
	{16, 24},	// Demoman
	{150, 150},	// Medic
	{200, 32},	// Heavy
	{200, 32},	// Pyro
	{20, 24},	// Spy
	{32, 200},	// Engineer
};

ArrayList g_aIndexList[WeaponSlot_BuilderEngie+1];
ArrayList g_aHud;

TFClassType g_iClientClass[TF_MAXPLAYERS+1];
int g_iClientWeaponIndex[TF_MAXPLAYERS+1][WeaponSlot_BuilderEngie+1];
Handle g_hClientEventTimer[TF_MAXPLAYERS+1][WeaponSlot_BuilderEngie+1];

Handle g_hSDKGetMaxHealth;
Handle g_hSDKRemoveWearable;
Handle g_hSDKEquipWearable;
Handle g_hSDKGetMaxAmmo;

#include "randomizer/hud.sp"
#include "randomizer/config.sp"
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

public void OnPluginEnd()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			TF2Attrib_RemoveByDefIndex(iClient, ATTRIB_MAX_METAL);
		}
	}
}

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
	if (GetClientTeam(iClient) <= 1) return;
	
	//Non-engineers have max metal at 100, while we want it to be 200
	if (TF2_GetPlayerClass(iClient) != TFClass_Engineer)
		TF2Attrib_SetByDefIndex(iClient, ATTRIB_MAX_METAL, 2.0);
	else
		TF2Attrib_RemoveByDefIndex(iClient, ATTRIB_MAX_METAL);
	
	TF2Attrib_ClearCache(iClient);
	TF2_SetMetal(iClient, 200);
	
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		TF2_RemoveItemInSlot(iClient, iSlot);
		
		int iIndex = g_iClientWeaponIndex[iClient][iSlot];
		PrintToChatAll("client %N slot %d index %d", iClient, iSlot, iIndex);
		if (iIndex < 0) continue;
		
		//Create weapon
		int iWeapon = TF2_CreateAndEquipWeapon(iClient, iIndex, iSlot);
		
		//We want to scale max ammo to correct value as it different between class
		if (HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType"))
		{
			int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
			if (iAmmoType < 0) continue;
			
			//Think Shortstop ammo still bugged?
			
			int iMaxAmmo = 1;	//Special ammos is usually 1, but SDK call returns 0...
			
			if (1 <= iAmmoType <= 2)	//Normal primary & secondary ammo
			{
				TFClassType nWeaponClass = TFClass_Unknown;
				for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
				{
					if (TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass)) == iSlot)
					{
						nWeaponClass = view_as<TFClassType>(iClass);
						break;
					}
				}
				
				if (nWeaponClass == TFClass_Unknown)
					ThrowError("[randomizer] Unable to find class in slot %d that uses index %d!", iSlot, iIndex);
				
				float flAmmoScale = float(g_iClassMaxAmmo[nWeaponClass][iSlot]) / float(g_iClassMaxAmmo[TF2_GetPlayerClass(iClient)][iSlot]);
				if (flAmmoScale == 1.0) continue;
				
				float flOldAmmoScale = 1.0;
				switch (iSlot)
				{
					case WeaponSlot_Primary:
					{
						TF2_WeaponFindAttribute(iWeapon, ATTRIB_AMMO_PRIMARY_HIDDEN, flOldAmmoScale);
						TF2Attrib_SetByDefIndex(iWeapon, ATTRIB_AMMO_PRIMARY_HIDDEN, flAmmoScale * flOldAmmoScale);
					}
					case WeaponSlot_Secondary:
					{
						TF2_WeaponFindAttribute(iWeapon, ATTRIB_AMMO_SECONDARY_HIDDEN, flOldAmmoScale);
						TF2Attrib_SetByDefIndex(iWeapon, ATTRIB_AMMO_SECONDARY_HIDDEN, flAmmoScale * flOldAmmoScale);
					}
				}
				
				iMaxAmmo = SDK_GetMaxAmmo(iClient, iAmmoType);
			}
			
			//Refresh max ammo
			//PrintToChatAll("client (%N) slot (%d) max ammo (%d) ammo type (%d)", iClient, iSlot, iMaxAmmo, iAmmoType);
			SetEntProp(iClient, Prop_Send, "m_iAmmo", iMaxAmmo, _, iAmmoType);
		}
	}
}

public Action Event_PlayerHurt(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	int iDamageAmount = event.GetInt("damageamount");
	
	if (iClient <= 0 || iClient > MaxClients || iAttacker <= 0 || iAttacker > MaxClients) return;
	if (GetClientTeam(iClient) <= 1 || GetClientTeam(iAttacker) <= 1) return;
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

public void SDK_Init()
{
	Handle hGameData = LoadGameConfigFile("sdkhooks.games");
	if (hGameData == null) SetFailState("Could not find sdkhooks.games gamedata!");
	
	//Max health
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetMaxHealth = EndPrepSDKCall();
	if(g_hSDKGetMaxHealth == null)
		LogMessage("Failed to create call: CTFPlayer::GetMaxHealth!");
	
	delete hGameData;
	
	hGameData = LoadGameConfigFile("sm-tf2.games");
	if (hGameData == null) SetFailState("Could not find sm-tf2.games gamedata!");
	
	int iRemoveWearableOffset = GameConfGetOffset(hGameData, "RemoveWearable");
	
	//Remove Wearable
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(iRemoveWearableOffset);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKRemoveWearable = EndPrepSDKCall();
	if(g_hSDKRemoveWearable == null)
		LogMessage("Failed to create call: CBasePlayer::RemoveWearable!");
	
	//Equip Wearable
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(iRemoveWearableOffset-1);//Equip Wearable is right behind Remove Wearable, should be good if valve dont add one between
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKEquipWearable = EndPrepSDKCall();
	if(g_hSDKEquipWearable == null)
		LogMessage("Failed to create call: CBasePlayer::EquipWearable!");
	
	delete hGameData;
	
	hGameData = LoadGameConfigFile("randomizer");
	if (hGameData == null) SetFailState("Could not find randomizer gamedata!");
	
	//Get Max Ammo
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetMaxAmmo = EndPrepSDKCall();
	if(g_hSDKGetMaxAmmo == null)
		LogMessage("Failed to create call: CTFPlayer::GetMaxAmmo!");
}

stock int SDK_GetMaxHealth(int iClient)
{
	if (g_hSDKGetMaxHealth != null)
		return SDKCall(g_hSDKGetMaxHealth, iClient);
	return 0;
}

stock void SDK_RemoveWearable(int iClient, int iWearable)
{
	if(g_hSDKRemoveWearable != null)
		SDKCall(g_hSDKRemoveWearable, iClient, iWearable);
}

stock void SDK_EquipWearable(int iClient, int iWearable)
{
	if(g_hSDKEquipWearable != null)
		SDKCall(g_hSDKEquipWearable, iClient, iWearable);
}

stock int SDK_GetMaxAmmo(int iClient, int iSlot, TFClassType iClass = TFClass_Unknown)
{
	if(g_hSDKGetMaxAmmo != null)
		return SDKCall(g_hSDKGetMaxAmmo, iClient, iSlot, -1);
	return -1;
}