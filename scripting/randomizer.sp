#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf_econ_data>
#include <dhooks>

#undef REQUIRE_EXTENSIONS
#tryinclude <tf2items>
#define REQUIRE_EXTENSIONS

#pragma newdecls required

#define PLUGIN_VERSION			"1.5.0"
#define PLUGIN_VERSION_REVISION	"manual"

#define TF_MAXPLAYERS	34	//32 clients + 1 for 0/world/console + 1 for replay/SourceTV
#define CONFIG_MAXCHAR	64

#define CLASS_MIN	1	//First valid TFClassType, TFClass_Scout
#define CLASS_MAX	9	//Last valid TFClassType, TFClass_Engineer
#define TEAM_MIN	2	//First valid TFTeam, TFTeam_Red
#define TEAM_MAX	3	//Last valid TFTeam, TFTeam_Blue

#define ATTRIB_AIR_DASH_COUNT	250

#define PARTICLE_BEAM_BLU	"medicgun_beam_blue"
#define PARTICLE_BEAM_RED	"medicgun_beam_red"

enum TFQuality
{
	TFQual_None = -1,
	TFQual_Normal = 0,
	TFQual_Genuine,
	TFQual_Rarity2,         /**< Unused */
	TFQual_Vintage,
	TFQual_Rarity3,         /**< Unused */
	TFQual_Unusual,
	TFQual_Unique,
	TFQual_Community,
	TFQual_Developer,       /**< Known as Valve Quality */
	TFQual_Selfmade,
	TFQual_Customized,      /**< Unused */
	TFQual_Strange,
	TFQual_Completed,       /**< Unused */
	TFQual_Haunted,
	TFQual_Collectors,
	TFQual_Decorated,
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
	TF_AMMO_DUMMY = 0,
	TF_AMMO_PRIMARY,	//General primary weapon ammo
	TF_AMMO_SECONDARY,	//General secondary weapon ammo
	TF_AMMO_METAL,		//Engineer's metal
	TF_AMMO_GRENADES1,	//Weapon misc ammo 1, in randomizer we force all melee weapon misc ammo to this
	TF_AMMO_GRENADES2,	//Weapon misc ammo 2, in randomizer we force all secondary weapon misc ammo to this
	TF_AMMO_COUNT
};

enum
{
	Mode_None = 0,			//No randomization
	Mode_Normal = 1,		//Randomizes every death
	Mode_NormalRound = 2,	//Randomizes every round
	Mode_Team = 3,			//Everyone in each teams get same randomization every round
	Mode_All = 4,			//Everyone get same randomization every round
	
	Mode_MAX
};

enum ClientUpdate
{
	ClientUpdate_Round,
	ClientUpdate_Death,
	ClientUpdate_Spawn,
}

enum Button
{
	Button_Invalid = -1,
	
	Button_Attack2 = 0,
	Button_Attack3,
	Button_Reload,
	
	Button_MAX
};

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
ConVar g_cvRandomClass;
ConVar g_cvRandomWeapons;
ConVar g_cvDroppedWeapons;
ConVar g_cvHuds;

TFClassType g_iTeamClass[TEAM_MAX+1];
int g_iTeamWeaponIndex[TEAM_MAX + 1][WeaponSlot_BuilderEngie + 1];

TFClassType g_iClientClass[TF_MAXPLAYERS];
int g_iClientWeaponIndex[TF_MAXPLAYERS][WeaponSlot_BuilderEngie+1];

TFClassType g_iClientCurrentClass[TF_MAXPLAYERS];
int g_iAllowPlayerClass[TF_MAXPLAYERS];
int g_iMedigunBeamRef[TF_MAXPLAYERS] = {INVALID_ENT_REFERENCE, ...};
Handle g_hTimerClientHud[TF_MAXPLAYERS];

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
	
	g_cvRandomClass = CreateConVar("randomizer_randomclass", "1", "Randomizes player class. 0 = No randomize, 1 = randomize every death, 2 = randomize every round, 3 = each team get same randomize, 4 = everyone get same randomize.", _, true, 0.0, true, float(Mode_MAX - 1));
	g_cvRandomClass.AddChangeHook(ConVar_RandomChanged);
	
	g_cvRandomWeapons = CreateConVar("randomizer_randomweapons", "1", "Randomizes player weapons.  0 = No randomize, 1 = randomize every death, 2 = randomize every round, 3 = each team get same randomize, 4 = everyone get same randomize.", _, true, 0.0, true, float(Mode_MAX - 1));
	g_cvRandomWeapons.AddChangeHook(ConVar_RandomChanged);
	
	g_cvDroppedWeapons = CreateConVar("randomizer_droppedweapons", "0", "Allow dropped weapons?", _, true, 0.0, true, 1.0);
	g_cvHuds = CreateConVar("randomizer_huds", "1", "Enable weapon huds?", _, true, 0.0, true, 1.0);
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
	
	UpdateClientWeapon(iClient, ClientUpdate_Round);
}

public void OnClientDisconnect(int iClient)
{
	if (!g_bEnabled)
		return;
	
	g_hTimerClientHud[iClient] = null;
	DHook_UnhookGiveNamedItem(iClient);
	DHook_UnhookClient(iClient);
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
	
	DHook_OnEntityCreated(iEntity, sClassname);
	SDKHook_OnEntityCreated(iEntity, sClassname);
	
	if (StrEqual(sClassname, "tf_dropped_weapon") && !g_cvDroppedWeapons.BoolValue)
		RemoveEntity(iEntity);
}

public void ConVar_EnableChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!!StringToInt(newValue))
		EnableRandomizer();
	else
		DisableRandomizer();
}

public void ConVar_RandomChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_bEnabled)
	{
		//Update client and team weapons when convar value is updated
		UpdateTeamWeapon();
		
		for (int iClient = 1; iClient <= MaxClients; iClient++)
			if (IsClientInGame(iClient))
				TF2_RespawnPlayer(iClient);
	}
}

void EnableRandomizer()
{
	g_bEnabled = true;
	Patch_Enable();
	
	DHook_EnableDetour();
	DHook_HookGamerules();
	
	UpdateTeamWeapon();
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			OnClientPutInServer(iClient);
			
			if (TF2_GetClientTeam(iClient) > TFTeam_Spectator)
				TF2_RespawnPlayer(iClient);
		}
	}
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

void UpdateTeamWeapon(TFTeam iForceTeam = TFTeam_Unassigned)
{
	TFClassType iGlobalClass = TFClass_Unknown;
	
	//Randomize team/all class and weapons round if enabled
	switch (g_cvRandomClass.IntValue)
	{
		case Mode_Team:
		{
			for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
				if (iForceTeam == TFTeam_Unassigned || iForceTeam == view_as<TFTeam>(iTeam))
					g_iTeamClass[iTeam] = TF2_GetRandomClass();
		}
		case Mode_All:
		{
			iGlobalClass = TF2_GetRandomClass();
			for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
				g_iTeamClass[iTeam] = iGlobalClass;
		}
		default:
		{
			for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
				g_iTeamClass[iTeam] = TFClass_Unknown;
		}
	}
	
	switch (g_cvRandomWeapons.IntValue)
	{
		case Mode_Team:
		{
			for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
			{
				if (iForceTeam == TFTeam_Unassigned || iForceTeam == view_as<TFTeam>(iTeam))
				{
					TFClassType iClass = g_iTeamClass[iTeam];
					if (iClass == TFClass_Unknown)
						iClass = TF2_GetRandomClass();
					
					for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
						g_iTeamWeaponIndex[iTeam][iSlot] = Weapons_GetRandomIndex(iSlot, iClass);
				}
			}
		}
		case Mode_All:
		{
			for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
			{
				int iWeaponIndex = Weapons_GetRandomIndex(iSlot, iGlobalClass);
				for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
					g_iTeamWeaponIndex[iTeam][iSlot] = iWeaponIndex;
			}
		}
		default:
		{
			for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
				for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
					g_iTeamWeaponIndex[iTeam][iSlot] = -1;
		}
	}
}

void UpdateClientWeapon(int iClient, ClientUpdate iUpdate)
{
	TFTeam iTeam = TF2_GetClientTeam(iClient);
	
	switch (g_cvRandomClass.IntValue)
	{
		case Mode_None:
		{
			g_iClientClass[iClient] = TFClass_Unknown;
		}
		case Mode_Normal:
		{
			if (iUpdate == ClientUpdate_Round || iUpdate == ClientUpdate_Death)
				g_iClientClass[iClient] = TF2_GetRandomClass();
		}
		case Mode_NormalRound:
		{
			if (iUpdate == ClientUpdate_Round)
				g_iClientClass[iClient] = TF2_GetRandomClass();
		}
		case Mode_Team, Mode_All:
		{
			g_iClientClass[iClient] = g_iTeamClass[iTeam];
		}
	}
	
	switch (g_cvRandomWeapons.IntValue)
	{
		case Mode_None:
		{
			for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
				g_iClientWeaponIndex[iClient][iSlot] = -1;
		}
		case Mode_Normal:
		{
			if (iUpdate == ClientUpdate_Round || iUpdate == ClientUpdate_Death)
				for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
					g_iClientWeaponIndex[iClient][iSlot] = Weapons_GetRandomIndex(iSlot, g_iClientClass[iClient]);
		}
		case Mode_NormalRound:
		{
			if (iUpdate == ClientUpdate_Round)
				for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
					g_iClientWeaponIndex[iClient][iSlot] = Weapons_GetRandomIndex(iSlot, g_iClientClass[iClient]);
		}
		case Mode_Team, Mode_All:
		{
			for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
				g_iClientWeaponIndex[iClient][iSlot] = g_iTeamWeaponIndex[iTeam][iSlot];
		}
	}
}

public Action Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	UpdateTeamWeapon();
	
	//Update client weapons
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			UpdateClientWeapon(iClient, ClientUpdate_Round);
			
			if (TF2_GetClientTeam(iClient) > TFTeam_Spectator)
				if (g_cvRandomClass.IntValue != Mode_None || g_cvRandomWeapons.IntValue != Mode_None)
					TF2_RespawnPlayer(iClient);
		}
	}
}

public Action Event_PlayerInventoryUpdate(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
	if (!g_cvRandomWeapons.BoolValue)
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
		
		if (g_iClientWeaponIndex[iClient][iSlot] == Weapons_GetReskinIndex(iIndex))
			bKeepWeapon[iSlot] = true;
		else if (!CanKeepWeapon(iClient, sClassname, iIndex))
			TF2_RemoveItem(iClient, iWeapon);
	}
	
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		//Create weapon
		if (g_iClientWeaponIndex[iClient][iSlot] >= 0 && !bKeepWeapon[iSlot])
		{
			Address pItem = TF2_FindReskinItem(iClient, g_iClientWeaponIndex[iClient][iSlot]);
			if (pItem)
				iWeapon = TF2_GiveNamedItem(iClient, pItem, iSlot);
			else
				iWeapon = TF2_CreateWeapon(iClient, g_iClientWeaponIndex[iClient][iSlot], iSlot);
			
			if (iWeapon <= MaxClients)
			{
				PrintToChat(iClient, "Unable to create weapon! index (%d)", g_iClientWeaponIndex[iClient][iSlot]);
				LogError("Unable to create weapon! index (%d)", g_iClientWeaponIndex[iClient][iSlot]);
			}
			
			//CTFPlayer::ItemsMatch doesnt like normal item quality, so lets use unique instead
			if (view_as<TFQuality>(GetEntProp(iWeapon, Prop_Send, "m_iEntityQuality")) == TFQual_Normal)
				SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", TFQual_Unique);
			
			TF2_EquipWeapon(iClient, iWeapon);
			
			if (ViewModels_ShouldBeInvisible(iWeapon, TF2_GetPlayerClass(iClient)))
			{
				ViewModels_EnableInvisible(iWeapon);
			}
		}
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
		UpdateClientWeapon(iClient, ClientUpdate_Death);
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

void SetClientClass(int iClient, TFClassType nClass)
{
	if (g_iClientCurrentClass[iClient] == TFClass_Unknown)
	{
		g_iClientCurrentClass[iClient] = TF2_GetPlayerClass(iClient);
	}
	TF2_SetPlayerClass(iClient, nClass);
}

void RevertClientClass(int iClient)
{
	if (g_iClientCurrentClass[iClient] != TFClass_Unknown)
	{
		TF2_SetPlayerClass(iClient, g_iClientCurrentClass[iClient]);
		g_iClientCurrentClass[iClient] = TFClass_Unknown;
	}
}

public Action TF2Items_OnGiveNamedItem(int iClient, char[] sClassname, int iIndex, Handle &hItem)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (CanKeepWeapon(iClient, sClassname, iIndex))
		return Plugin_Continue;
	
	return Plugin_Handled;
}