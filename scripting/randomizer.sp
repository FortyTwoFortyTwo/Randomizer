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

#define PLUGIN_VERSION			"1.1.0"
#define PLUGIN_VERSION_REVISION	"manual"

#define TF_MAXPLAYERS	32
#define CONFIG_MAXCHAR	64

#define CLASS_MIN	1	//First valid TFClassType, Scout
#define CLASS_MAX	9	//Last valid TFClassType, Engineer

#define ATTRIB_AIR_DASH_COUNT	250

#define PARTICLE_BEAM_BLU	"medicgun_beam_blue"
#define PARTICLE_BEAM_RED	"medicgun_beam_red"

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
	TF_AMMO_DUMMY = 0,
	TF_AMMO_PRIMARY,	//General primary weapon ammo
	TF_AMMO_SECONDARY,	//General secondary weapon ammo
	TF_AMMO_METAL,		//Engineer's metal
	TF_AMMO_GRENADES1,	//Weapon misc ammo 1, in randomizer we force all melee weapon misc ammo to this
	TF_AMMO_GRENADES2,	//Weapon misc ammo 2, in randomizer we force all secondary weapon misc ammo to this
	TF_AMMO_COUNT
};

enum Button
{
	Button_Invalid = -1,
	
	Button_Attack2 = 0,
	Button_Attack3,
	Button_Reload,
	
	Button_MAX
}

enum struct WeaponWhitelist	//Whitelist of allowed weapon indexs
{
	ArrayList aClassname;
	ArrayList aAttrib;
	ArrayList aIndex;
	
	void Load(KeyValues kv, const char[] sSection)
	{
		if (kv.JumpToKey(sSection, false))
		{
			if (kv.GotoFirstSubKey(false))	//netprop name
			{
				do
				{
					char sType[CONFIG_MAXCHAR], sValue[CONFIG_MAXCHAR];
					kv.GetSectionName(sType, sizeof(sType));
					kv.GetString(NULL_STRING, sValue, sizeof(sValue));
					
					if (StrEqual(sType, "classname", false))
					{
						if (!this.aClassname)
							this.aClassname = new ArrayList(CONFIG_MAXCHAR);
						
						this.aClassname.PushString(sValue);
					}
					else if (StrEqual(sType, "attrib", false))
					{
						if (!this.aAttrib)
							this.aAttrib = new ArrayList();
						
						this.aAttrib.Push(TF2Econ_TranslateAttributeNameToDefinitionIndex(sValue));
					}
					else if (StrEqual(sType, "index", false))
					{
						if (!this.aIndex)
							this.aIndex = new ArrayList();
						
						this.aIndex.Push(StringToInt(sValue));
					}
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
			kv.GoBack();
		}
	}
	
	bool IsIndexAllowed(int iIndex)
	{
		if (this.aClassname)
		{
			char sClassname[256];
			TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
			
			int iLength = this.aClassname.Length;
			for (int i = 0; i < iLength; i++)
			{
				char sBuffer[256];
				this.aClassname.GetString(i, sBuffer, sizeof(sBuffer));
				if (StrEqual(sClassname, sBuffer))
					return true;
			}
		}
		
		if (this.aAttrib)
		{
			ArrayList aIndexAttrib = TF2Econ_GetItemStaticAttributes(iIndex);
			int iIndexAttribLength = aIndexAttrib.Length;
			int iAllowedAttribLength = this.aAttrib.Length;
			
			for (int i = 0; i < iIndexAttribLength; i++)
			{
				int iIndexAttrib = aIndexAttrib.Get(i);
				for (int j = 0; j < iAllowedAttribLength; j++)
				{
					if (iIndexAttrib == this.aAttrib.Get(j))
					{
						delete aIndexAttrib;
						return true;
					}
				}
			}
			
			delete aIndexAttrib;
		}
		
		if (this.aIndex)
		{
			int iLength = this.aIndex.Length;
			for (int i = 0; i < iLength; i++)
				if (iIndex == this.aIndex.Get(i))
					return true;
		}
		
		return false;
	}
	
	bool IsEmpty()
	{
		return !this.aClassname && !this.aAttrib && !this.aIndex;
	}
	
	void Delete()
	{
		delete this.aClassname;
		delete this.aAttrib;
		delete this.aIndex;
	}
}

bool g_bEnabled;
bool g_bTF2Items;
bool g_bAllowGiveNamedItem;
int g_iOffsetItemDefinitionIndex = -1;
ConVar g_cvEnabled;

TFClassType g_iClientClass[TF_MAXPLAYERS+1];
int g_iClientWeaponIndex[TF_MAXPLAYERS+1][WeaponSlot_BuilderEngie+1];
int g_iAllowPlayerClass[TF_MAXPLAYERS+1];
int g_iMedigunBeamRef[TF_MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};
Handle g_hTimerClientHud[TF_MAXPLAYERS+1];

#include "randomizer/controls.sp"
#include "randomizer/huds.sp"
#include "randomizer/viewmodels.sp"
#include "randomizer/weapons.sp"

#include "randomizer/ammo.sp"
#include "randomizer/commands.sp"
#include "randomizer/dhook.sp"
#include "randomizer/patch.sp"
#include "randomizer/sdkcall.sp"
#include "randomizer/sdkhook.sp"
#include "randomizer/stocks.sp"

public Plugin myinfo =
{
	name = "Randomizer",
	author = "42",
	description = "Gamemode where everyone plays as random class with random weapons",
	version = PLUGIN_VERSION ... "." ... PLUGIN_VERSION_REVISION,
	url = "https://github.com/FortyTwoFortyTwo/Randomizer",
};

public void OnPluginStart()
{
	LoadTranslations("randomizer.phrases");
	
	//OnLibraryAdded dont always call TF2Items on plugin start
	g_bTF2Items = LibraryExists("TF2Items");
	
	GameData hGameData = new GameData("randomizer");
	if (!hGameData)
		SetFailState("Could not find randomizer gamedata");
	
	Patch_Init(hGameData);
	DHook_Init(hGameData);
	SDKCall_Init(hGameData);
	g_iOffsetItemDefinitionIndex = hGameData.GetOffset("CEconItemView::m_iItemDefinitionIndex");
	
	delete hGameData;
	
	Ammo_Init();
	Commands_Init();
	Controls_Init();
	Huds_Init();
	ViewModels_Init();
	Weapons_Init();
	
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_PlayerInventoryUpdate);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_iClientClass[iClient] = TFClass_Unknown;
		
		for (int iSlot = 0; iSlot < sizeof(g_iClientWeaponIndex[]); iSlot++)
			g_iClientWeaponIndex[iClient][iSlot] = -1;
	}
	
	CreateConVar("randomizer_version", PLUGIN_VERSION ... "." ... PLUGIN_VERSION_REVISION, "Randomizer plugin version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_cvEnabled = CreateConVar("randomizer_enabled", "1", "Enable Randomizer?", _, true, 0.0, true, 1.0);
	g_cvEnabled.AddChangeHook(ConVar_EnableChanged);
}

public void OnPluginEnd()
{
	if (g_bEnabled)
		DisableRandomizer();
}

public void OnMapStart()
{
	PrecacheParticleSystem(PARTICLE_BEAM_RED);
	PrecacheParticleSystem(PARTICLE_BEAM_BLU);
	
	Controls_Refresh();
	Huds_Refresh();
	ViewModels_Refresh();
	Weapons_Refresh();
	
	if (g_bEnabled)
		DHook_HookGamerules();
	
	if (g_cvEnabled.BoolValue && !g_bEnabled)
		EnableRandomizer();	//Have to be in OnMapStart
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "TF2Items"))
	{
		g_bTF2Items = true;
		
		//We cant allow TF2Items load while GiveNamedItem already hooked due to crash
		if (DHook_IsGiveNamedItemActive())
			SetFailState("Do not load TF2Items midgame while Randomizer is already loaded!");
	}
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "TF2Items"))
	{
		g_bTF2Items = false;
		
		if (!g_bEnabled)
			return;
		
		//TF2Items unloaded with GiveNamedItem unhooked, we can now safely hook GiveNamedItem ourself
		for (int iClient = 1; iClient <= MaxClients; iClient++)
			if (IsClientInGame(iClient))
				DHook_HookGiveNamedItem(iClient);
	}
}

public void OnClientPutInServer(int iClient)
{
	if (!g_bEnabled)
		return;
	
	g_hTimerClientHud[iClient] = CreateTimer(0.2, Huds_ClientDisplay, iClient, TIMER_REPEAT);
	
	DHook_HookGiveNamedItem(iClient);
	DHook_HookClient(iClient);
	SDKHook_HookClient(iClient);
	
	GenerateRandomWeapon(iClient);
}

public void OnClientDisconnect(int iClient)
{
	if (!g_bEnabled)
		return;
	
	g_hTimerClientHud[iClient] = null;
	DHook_UnhookGiveNamedItem(iClient);
}

public void OnPlayerRunCmdPost(int iClient, int iButtons, int iImpulse, const float vecVel[3], const float vecAngles[3], int iWeapon, int iSubtype, int iCmdNum, int iTickCount, int iSeed, const int iMouse[2]) 
{
	if (!g_bEnabled)
		return;
	
	//Call DoClassSpecialSkill for detour to manage with any weapons replaced from attack2 to attack3 or reload
	if (iButtons & IN_ATTACK3 || iButtons & IN_RELOAD)
		SDKCall_DoClassSpecialSkill(iClient);
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (!g_bEnabled)
		return;
	
	if (StrContains(sClassname, "tf_weapon_") == 0)
	{
		SDKHook_HookWeapon(iEntity);
		DHook_HookWeapon(iEntity);
	}
	
	if (StrContains(sClassname, "item_healthkit") == 0)
		SDKHook_HookHealthKit(iEntity);
	else if (StrEqual(sClassname, "tf_projectile_stun_ball") || StrEqual(sClassname, "tf_projectile_ball_ornament"))
		DHook_HookStunBall(iEntity);
	else if (StrEqual(sClassname, "tf_weapon_sword"))
		DHook_HookSword(iEntity);
	else if (StrContains(sClassname, "obj_") == 0)
		DHook_HookObject(iEntity);
	else if (StrEqual(sClassname, "tf_dropped_weapon"))
		RemoveEntity(iEntity);
}

public void ConVar_EnableChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!!StringToInt(newValue))
		EnableRandomizer();
	else
		DisableRandomizer();
}

void EnableRandomizer()
{
	g_bEnabled = true;
	Patch_Enable();
	
	DHook_EnableDetour();
	DHook_HookGamerules();
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient))
			OnClientPutInServer(iClient);
}

void DisableRandomizer()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			OnClientDisconnect(iClient);
			SDKHook_UnhookClient(iClient);
		}
	}
	
	DHook_DisableDetour();
	DHook_UnhookGamerules();
	
	Patch_Disable();
	g_bEnabled = false;
	
	int iBuilding = MaxClients+1;
	while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) > MaxClients)
		RemoveEntity(iBuilding);
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient) && IsPlayerAlive(iClient))
			TF2_RegeneratePlayer(iClient);
}

public void GenerateRandomWeapon(int iClient)
{
	//Detach client's object so it doesnt get destroyed on losing toolbox
	int iBuilding = MaxClients+1;
	while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) > MaxClients)
		if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == iClient)
			SDKCall_RemoveObject(iClient, iBuilding);
	
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
	if (!g_bEnabled)
		return;
	
	//New round, generate new weapons for everyone
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient))
			GenerateRandomWeapon(iClient);
}

public Action Event_PlayerSpawn(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
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
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
	bool bKeepWeapon[WeaponSlot_BuilderEngie+1];
	
	int iWeapon;
	int iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		char sClassname[256];
		GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
		int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		int iSlot = TF2_GetSlot(iWeapon);
		
		if (g_iClientWeaponIndex[iClient][iSlot] == iIndex)
			bKeepWeapon[iSlot] = true;
		else if (!CanKeepWeapon(iClient, sClassname, iIndex))
			TF2_RemoveItem(iClient, iWeapon);
	}
	
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		//Create weapon
		if (g_iClientWeaponIndex[iClient][iSlot] >= 0 && !bKeepWeapon[iSlot])
		{
			iWeapon = TF2_CreateAndEquipWeapon(iClient, g_iClientWeaponIndex[iClient][iSlot], iSlot);
			if (iWeapon <= MaxClients)
			{
				PrintToChat(iClient, "Unable to create weapon! index (%d)", g_iClientWeaponIndex[iClient][iSlot]);
				LogError("Unable to create weapon! index (%d)", g_iClientWeaponIndex[iClient][iSlot]);
			}
			else if (ViewModels_ShouldBeInvisible(iWeapon, g_iClientClass[iClient]))
			{
				ViewModels_EnableInvisible(iWeapon);
			}
		}
	}
	
	if (TF2_GetItemFromClassname(iClient, "tf_weapon_builder") > MaxClients)
	{
		//Find any toolbox thay may have been detached from client, reattach it
		int iBuilding = MaxClients+1;
		while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) > MaxClients)
			if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == iClient)
				SDKCall_AddObject(iClient, iBuilding);
	}
	
	//Set active weapon if dont have one
	if (GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") <= MaxClients)
	{
		for (int iSlot = 0; iSlot <= WeaponSlot_Melee; iSlot++)
		{
			iWeapon = GetPlayerWeaponSlot(iClient, iSlot);	//Dont want wearable
			if (iWeapon > MaxClients)
			{
				SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
				break;
			}
		}
	}
	
	Controls_RefreshClient(iClient);
	Huds_RefreshClient(iClient);
}

public Action Event_PlayerDeath(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	bool bDeadRinger = (event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER) != 0;
	
	//Only generate new weapons if killed from attacker
	if (0 < iAttacker <= MaxClients && IsClientInGame(iAttacker) && iClient != iAttacker && !bDeadRinger)
		RequestFrame(GenerateRandomWeapon, iClient);	//Can be buggy if done same frame as death
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
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (CanKeepWeapon(iClient, sClassname, iIndex))
		return Plugin_Continue;
	
	return Plugin_Handled;
}