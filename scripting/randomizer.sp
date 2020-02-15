#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf_econ_data>
#include <dhooks>

#undef REQUIRE_EXTENSIONS
#tryinclude <tf2items>
#define REQUIRE_EXTENSIONS

#pragma newdecls required

#define TF_MAXPLAYERS 32

#define CLASS_MIN	1	//First valid TFClassType, Scout
#define CLASS_MAX	9	//Last valid TFClassType, Engineer

#define ATTRIB_AIR_DASH_COUNT			250

// entity effects
enum
{
	EF_BONEMERGE			= (1<<0),	// Performs bone merge on client side
	EF_BRIGHTLIGHT			= (1<<1),	// DLIGHT centered at entity origin
	EF_DIMLIGHT				= (1<<2),	// player flashlight
	EF_NOINTERP				= (1<<3),	// don't interpolate the next frame
	EF_NOSHADOW				= (1<<4),	// Don't cast no shadow
	EF_NODRAW				= (1<<5),	// don't draw entity
	EF_NORECEIVESHADOW		= (1<<6),	// Don't receive no shadow
	EF_BONEMERGE_FASTCULL	= (1<<7),	// For use with EF_BONEMERGE. If this is set, then it places this ent's origin at its
										// parent and uses the parent's bbox + the max extents of the aiment.
										// Otherwise, it sets up the parent's bones every frame to figure out where to place
										// the aiment, which is inefficient because it'll setup the parent's bones even if
										// the parent is not in the PVS.
	EF_ITEM_BLINK			= (1<<8),	// blink an item so that the user notices it.
	EF_PARENT_ANIMATES		= (1<<9),	// always assume that the parent entity is animating
};

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

bool g_bTF2Items;

TFClassType g_iClientClass[TF_MAXPLAYERS+1];
int g_iClientWeaponIndex[TF_MAXPLAYERS+1][WeaponSlot_BuilderEngie+1];

#include "randomizer/commands.sp"
#include "randomizer/controls.sp"
#include "randomizer/huds.sp"
#include "randomizer/sdk.sp"
#include "randomizer/stocks.sp"
#include "randomizer/viewmodels.sp"
#include "randomizer/weapons.sp"

public Plugin myinfo =
{
	name = "Randomizer",
	author = "42",
	description = "Gamemode where everyone plays as random class with random weapons",
	version = "0.0.0",
	url = "https://github.com/FortyTwoFortyTwo/Randomizer",
};

public void OnPluginStart()
{
	//OnLibraryAdded dont always call TF2Items on plugin start
	g_bTF2Items = LibraryExists("TF2Items");
	
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_PlayerInventoryUpdate);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	SDK_Init();
	
	Commands_Init();
	Controls_Init();
	Huds_Init();
	Weapons_Init();
	
	Controls_Refresh();
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

public void OnMapStart()
{
	ViewModel_Precache();
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "TF2Items"))
	{
		g_bTF2Items = true;
		
		//We cant allow TF2Items load while GiveNamedItem already hooked due to crash
		if (SDK_IsGiveNamedItemActive())
			SetFailState("Do not load TF2Items midgame while Randomizer is already loaded!");
	}
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "TF2Items"))
	{
		g_bTF2Items = false;
		
		//TF2Items unloaded with GiveNamedItem unhooked, we can now safely hook GiveNamedItem ourself
		for (int iClient = 1; iClient <= MaxClients; iClient++)
			if (IsClientInGame(iClient))
				SDK_HookGiveNamedItem(iClient);
	}
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_PreThink, Huds_ClientDisplay);
//	SDKHook(iClient, SDKHook_PreThink, ViewModel_Think);
	
//	SDKHook(iClient, SDKHook_WeaponSwitchPost, ViewModel_WeaponSwitch);
	
	SDK_HookGiveNamedItem(iClient);
	
	GenerateRandonWeapon(iClient);
}

public void OnClientDisconnect(int iClient)
{
	SDK_UnhookGiveNamedItem(iClient);
}

public void OnPlayerRunCmdPost(int iClient, int iButtons, int iImpulse, const float vecVel[3], const float vecAngles[3], int iWeapon, int iSubtype, int iCmdNum, int iTickCount, int iSeed, const int iMouse[2]) 
{
	//Call DoClassSpecialSkill for detour to manage with any weapons replaced from attack2 to reload
	if (iButtons & IN_RELOAD)
		SDK_DoClassSpecialSkill(iClient);
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
	
	for (int iSlot = 0; iSlot < WeaponSlot_BuilderEngie; iSlot++)	//Generating tf_weapon_builder is weird, allow engi keeps it
	{
		//Allow player keep weapon if same index
		int iWeapon = TF2_GetItemInSlot(iClient, iSlot);
		if (iWeapon > MaxClients && GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") == g_iClientWeaponIndex[iClient][iSlot])
			continue;
		
		TF2_RemoveItemInSlot(iClient, iSlot);
		g_iViewModelHand[iClient][iSlot] = -1;
		
		//Create weapon
		if (g_iClientWeaponIndex[iClient][iSlot] >= 0)
		{
			TF2_CreateAndEquipWeapon(iClient, g_iClientWeaponIndex[iClient][iSlot], iSlot);
			
			//Check if weapon actually generated and equipped
			iWeapon = TF2_GetItemInSlot(iClient, iSlot);
			if (iWeapon <= MaxClients)
			{
				PrintToChat(iClient, "Unable to create weapon! index (%d)", g_iClientWeaponIndex[iClient][iSlot]);
				LogError("Unable to create weapon! index (%d)", g_iClientWeaponIndex[iClient][iSlot]);
			}
		}
	}
	
	Huds_RefreshClient(iClient);
	
	//Validate active weapon after deleting and generating weapons
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

public Action Event_PlayerDeath(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	bool bDeadRinger = (event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER) != 0;
	
	//Only generate new weapons if killed from attacker
	if (0 < iAttacker <= MaxClients && IsClientInGame(iAttacker) && iClient != iAttacker && !bDeadRinger)
		RequestFrame(GenerateRandonWeapon, iClient);	//Can be buggy if done same frame as death
}

KeyValues LoadConfig(const char[] sFilepath, const char[] sName)
{
	char sConfigPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigPath, sizeof(sConfigPath), sFilepath);
	if (!FileExists(sConfigPath))
	{
		LogError("Failed to load Randomizer %s config file (file missing): %s", sName, sConfigPath);
		return null;
	}
	
	KeyValues kv = new KeyValues(sName);
	kv.SetEscapeSequences(true);

	if (!kv.ImportFromFile(sConfigPath))
	{
		LogError("Failed to parse Randomizer %s config file: %s", sName, sConfigPath);
		delete kv;
		return null;
	}
	
	return kv;
}

public Action TF2Items_OnGiveNamedItem(int iClient, char[] sClassname, int iIndex, Handle &hItem)
{
	return GiveNamedItem(iClient, sClassname, iIndex);
}

public Action GiveNamedItem(int iClient, const char[] sClassname, int iIndex)
{
	//Only allow cosmetics and tf_weapon_builder, otherwise dont generate player's TF2 loadout
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
		if (0 <= iSlot < WeaponSlot_BuilderEngie)
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}