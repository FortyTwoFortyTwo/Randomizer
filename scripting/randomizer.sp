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

#define PLUGIN_VERSION			"1.7.0"
#define PLUGIN_VERSION_REVISION	"manual"

#define TF_MAXPLAYERS	34	//32 clients + 1 for 0/world/console + 1 for replay/SourceTV
#define CONFIG_MAXCHAR	64

#define CLASS_MIN	1	//First valid TFClassType, TFClass_Scout
#define CLASS_MAX	9	//Last valid TFClassType, TFClass_Engineer

#define TEAM_MIN	2	//First valid TFTeam, TFTeam_Red
#define TEAM_MAX	3	//Last valid TFTeam, TFTeam_Blue

#define DEFAULT_MAX_AMMO	1000	//Used for cases when 2 weapons use same ammotype, number only matters when diving for ammo pickups
#define MAX_WEAPONS		56			//Max 48 tf_weapon and 8 tf_wearable from TF2

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
	WeaponSlot_PDA,
	WeaponSlot_PDA2,
	WeaponSlot_Building
};

enum
{
	LoadoutSlot_Primary = 0,
	LoadoutSlot_Secondary,
	LoadoutSlot_Melee,
	LoadoutSlot_Utility,
	LoadoutSlot_Building,
	LoadoutSlot_PDA,
	LoadoutSlot_PDA2,
	LoadoutSlot_Head,
	LoadoutSlot_Misc,
	LoadoutSlot_Action,
	LoadoutSlot_Misc2
}

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

enum
{
	HudMode_None = 0,
	HudMode_Text = 1,
	HudMode_Menu = 2,
	
	HudMode_MAX
};

enum Button
{
	Button_Invalid = -1,
	
	Button_Attack2 = 0,
	Button_Attack3,
	Button_Reload,
	
	Button_MAX
};

enum struct RandomizedWeapon
{
	int iIndex[MAX_WEAPONS];//Index to set
	int iSlot[MAX_WEAPONS];	//Slot to use
	int iRef[MAX_WEAPONS];	//Weapon entity if exists
	
	void Reset()
	{
		for (int iPos = 0; iPos < MAX_WEAPONS; iPos++)
		{
			this.iIndex[iPos] = -1;
			this.iSlot[iPos] = -1;
			this.iRef[iPos] = INVALID_ENT_REFERENCE;
		}
	}
	
	void Add(int iIndex, int iSlot, int iWeapon = INVALID_ENT_REFERENCE)
	{
		if (iIndex == -1)
			return;
		
		for (int iPos = 0; iPos < MAX_WEAPONS; iPos++)
		{
			if (this.iIndex[iPos] == -1)
			{
				this.iIndex[iPos] = iIndex;
				this.iSlot[iPos] = iSlot;
				
				if (iWeapon != INVALID_ENT_REFERENCE)
					this.iRef[iPos] = EntIndexToEntRef(iWeapon);
				
				return;
			}
		}
	}
	
	void RemoveBySlot(int iSlot)
	{
		for (int iPos = 0; iPos < MAX_WEAPONS; iPos++)
		{
			if (this.iSlot[iPos] == iSlot)
			{
				this.iIndex[iPos] = -1;
				this.iSlot[iPos] = -1;
				this.iRef[iPos] = INVALID_ENT_REFERENCE;
			}
		}
	}
	
	bool HasWeapon(int iWeapon)
	{
		if (iWeapon == INVALID_ENT_REFERENCE)
			return false;
		
		int iRef = EntIndexToEntRef(iWeapon);
		
		for (int iPos = 0; iPos < MAX_WEAPONS; iPos++)
			if (this.iRef[iPos] == iRef)
				return true;
		
		return false;
	}
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
int g_iOffsetPlayerShared;

ConVar g_cvEnabled;
ConVar g_cvWeaponsFromClass;
ConVar g_cvWeaponsCount;
ConVar g_cvCosmeticsConflicts;
ConVar g_cvRandomClass;
ConVar g_cvRandomWeapons;
ConVar g_cvRandomCosmetics;
ConVar g_cvTeamClass;
ConVar g_cvTeamWeapons;
ConVar g_cvTeamCosmetics;
ConVar g_cvDroppedWeapons;
ConVar g_cvHuds;

TFClassType g_iTeamClass[TEAM_MAX+1];
RandomizedWeapon g_eTeamWeapon[TEAM_MAX+1][CLASS_MAX+1];

TFClassType g_iClientClass[TF_MAXPLAYERS];
RandomizedWeapon g_eClientWeapon[TF_MAXPLAYERS][CLASS_MAX+1];

TFClassType g_iClientCurrentClass[TF_MAXPLAYERS];
int g_iAllowPlayerClass[TF_MAXPLAYERS];
bool g_bFeignDeath[TF_MAXPLAYERS];
Handle g_hTimerClientHud[TF_MAXPLAYERS];

int g_iClientEurekaTeleporting;

#include "randomizer/controls.sp"
#include "randomizer/huds.sp"
#include "randomizer/viewmodels.sp"
#include "randomizer/weapons.sp"

#include "randomizer/ammo.sp"
#include "randomizer/commands.sp"
#include "randomizer/dhook.sp"
#include "randomizer/patch.sp"
#include "randomizer/properties.sp"
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
	g_iOffsetPlayerShared = FindSendPropInfo("CTFPlayer", "m_Shared");
	
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
	
	AddCommandListener(Event_EurekaTeleport, "eureka_teleport");
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_iClientClass[iClient] = TFClass_Unknown;
		ResetWeaponIndex(g_eClientWeapon[iClient]);
	}
	
	CreateConVar("randomizer_version", PLUGIN_VERSION ... "." ... PLUGIN_VERSION_REVISION, "Randomizer plugin version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_cvEnabled = CreateConVar("randomizer_enabled", "1", "Enable Randomizer?", _, true, 0.0, true, 1.0);
	g_cvEnabled.AddChangeHook(ConVar_EnableChanged);
	
	g_cvWeaponsFromClass = CreateConVar("randomizer_weaponsfromclass", "0", "Should generated weapon only be from class that can normally equip?", _, true, 0.0, true, 1.0);
	g_cvWeaponsFromClass.AddChangeHook(ConVar_RandomChanged);
	
	g_cvWeaponsCount = CreateConVar("randomizer_weaponscount", "-1", "How many weapons to randomly generate, -1 for each slot by one?", _, true, -1.0, true, float(MAX_WEAPONS));
	g_cvWeaponsCount.AddChangeHook(ConVar_RandomChanged);
	
	g_cvCosmeticsConflicts = CreateConVar("randomizer_cosmeticsconflicts", "1", "Should generated cosmetics check for possible conflicts?", _, true, 0.0, true, 1.0);
	g_cvCosmeticsConflicts.AddChangeHook(ConVar_RandomChanged);
	
	g_cvRandomClass = CreateConVar("randomizer_randomclass", "1", "Randomizes player class. 0 = no randomize, 1 = randomize every death, 2 = randomize every round, 3 = each team get same randomize, 4 = everyone get same randomize.", _, true, 0.0, true, float(Mode_MAX - 1));
	g_cvRandomClass.AddChangeHook(ConVar_RandomChanged);
	
	g_cvRandomWeapons = CreateConVar("randomizer_randomweapons", "1", "Randomizes player weapons. 0 = no randomize, 1 = randomize every death, 2 = randomize every round, 3 = each team get same randomize, 4 = everyone get same randomize.", _, true, 0.0, true, float(Mode_MAX - 1));
	g_cvRandomWeapons.AddChangeHook(ConVar_RandomChanged);
	
	g_cvRandomCosmetics = CreateConVar("randomizer_randomcosmetics", "3", "How many cosmetics to randomly generate, -1 for no randomize", _, true, -1.0);
	g_cvRandomCosmetics.AddChangeHook(ConVar_RandomChanged);
	
	g_cvTeamClass = CreateConVar("randomizer_teamclass", "1", "Teams to randomize class. 1 = both teams, 2 = only red team, 3 = only blu team.", _, true, 1.0, true, float(TEAM_MAX));
	g_cvTeamClass.AddChangeHook(ConVar_TeamChanged);
	
	g_cvTeamWeapons = CreateConVar("randomizer_teamweapons", "1", "Teams to randomize weapons. 1 = both teams, 2 = only red team, 3 = only blu team.", _, true, 1.0, true, float(TEAM_MAX));
	g_cvTeamWeapons.AddChangeHook(ConVar_TeamChanged);
	
	g_cvTeamCosmetics = CreateConVar("randomizer_teamcosmetics", "1", "Teams to randomize cosmetics. 1 = both teams, 2 = only red team, 3 = only blu team.", _, true, 1.0, true, float(TEAM_MAX));
	g_cvTeamCosmetics.AddChangeHook(ConVar_TeamChanged);
	
	g_cvDroppedWeapons = CreateConVar("randomizer_droppedweapons", "0", "Allow dropped weapons?", _, true, 0.0, true, 1.0);
	g_cvHuds = CreateConVar("randomizer_huds", "1", "Hud to use to display weapons. 0 = none, 1 = hud text, 2 = menu.", _, true, 0.0, true, float(HudMode_MAX - 1));
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
	
	g_hTimerClientHud[iClient] = CreateTimer(0.2, Huds_ClientDisplayText, iClient, TIMER_REPEAT);
	
	DHook_HookGiveNamedItem(iClient);
	DHook_HookClient(iClient);
	SDKHook_HookClient(iClient);
	
	RandomizeClientWeapon(iClient);
}

public void OnClientDisconnect(int iClient)
{
	if (!g_bEnabled)
		return;
	
	g_hTimerClientHud[iClient] = null;
	DHook_UnhookGiveNamedItem(iClient);
	DHook_UnhookClient(iClient);
}
/*
public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float vecVel[3], float vecAngles[3], int &iWeapon, int &iSubtype, int &iCmdNum, int &iTickCount, int &iSeed, int iMouse[2])
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iWeapon)	//Client want to switch weapon
	{
		if (GetEntPropEnt(iClient, Prop_Send, "m_hLastWeapon") == iWeapon)
			return Plugin_Continue;
		
		int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
		if (iActiveWeapon == INVALID_ENT_REFERENCE)
			return Plugin_Continue;
		
		int iSlot = TF2_GetSlot(iWeapon);
		int iActiveSlot = TF2_GetSlot(iActiveWeapon);
		
		if (iActiveSlot + 1 == iSlot)
		{
			//Go to next weapon
			int iPos = Huds_GetPositionFromWeapon(iClient, iActiveWeapon);
			do
			{
				iPos++;
				iWeapon = Huds_GetWeaponFromPosition(iClient, iPos);
				
				if (iWeapon == INVALID_ENT_REFERENCE)
					iPos = 0;	//Reset loop
				else if (TF2_CanSwitchTo(iClient, iWeapon))
					return Plugin_Changed;
			}
			while (iActiveWeapon != iWeapon);
			return Plugin_Continue;
		}
		else if (iActiveSlot - 1 == iSlot)
		{
			//Go to previous weapon
			int iPos = Huds_GetPositionFromWeapon(iClient, iActiveWeapon);
			do
			{
				iPos--;
				iWeapon = Huds_GetWeaponFromPosition(iClient, iPos);
				
				if (iWeapon == INVALID_ENT_REFERENCE)
					iPos = Huds_GetPositionCount(iClient);	//Reset loop
				else if (TF2_CanSwitchTo(iClient, iWeapon))
					return Plugin_Changed;
			}
			while (iActiveWeapon != iWeapon);
			return Plugin_Continue;
		}
		
		
	}
	
	return Plugin_Continue;
}
*/
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

public void OnEntityDestroyed(int iEntity)
{
	if (0 <= iEntity < 2048)
	{
		Ammo_RemoveWeapon(iEntity);
		Properties_RemoveWeapon(iEntity);
	}
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
		RandomizeTeamWeapon();
		
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsClientInGame(iClient))
			{
				RandomizeClientWeapon(iClient);
				
				if (IsPlayerAlive(iClient) && IsTeamRandomized(TF2_GetClientTeam(iClient)))
					TF2_RespawnPlayer(iClient);
			}
		}
	}
}

public void ConVar_TeamChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_bEnabled)
	{
		//Update client and team weapons if it's status was updated from cvar
		int iOldTeam = StringToInt(oldValue);
		int iNewTeam = StringToInt(newValue);
		
		bool bAnyTeam = (iOldTeam < TEAM_MIN || iNewTeam < TEAM_MIN);
		
		for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
		{
			bool bThisTeam = (iOldTeam == iTeam || iNewTeam == iTeam);
			if ((bAnyTeam && !bThisTeam) || (bThisTeam && !bAnyTeam))
			{
				for (int iClient = 1; iClient <= MaxClients; iClient++)
					if (IsClientInGame(iClient) && IsPlayerAlive(iClient) && GetClientTeam(iClient) == iTeam)
						TF2_RespawnPlayer(iClient);
			}
		}
	}
}

void EnableRandomizer()
{
	g_bEnabled = true;
	Patch_Enable();
	
	DHook_EnableDetour();
	DHook_HookGamerules();
	
	RandomizeTeamWeapon();
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			OnClientPutInServer(iClient);
			
			if (IsPlayerAlive(iClient) && (IsClassRandomized(iClient) || IsWeaponRandomized(iClient)))
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

void RandomizeTeamWeapon(TFTeam iForceTeam = TFTeam_Unassigned)
{
	for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
	{
		g_iTeamClass[iTeam] = TFClass_Unknown;
		ResetWeaponIndex(g_eTeamWeapon[iTeam]);
	}
	
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
			TFClassType nClass = TF2_GetRandomClass();
			for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
				g_iTeamClass[iTeam] = nClass;
		}
	}
	
	switch (g_cvRandomWeapons.IntValue)
	{
		case Mode_Team:
		{
			for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
				if (iForceTeam == TFTeam_Unassigned || iForceTeam == view_as<TFTeam>(iTeam))
					RandomizeWeaponIndex(g_eTeamWeapon[iTeam]);
		}
		case Mode_All:
		{
			RandomizedWeapon eWeapon[CLASS_MAX + 1];
			RandomizeWeaponIndex(eWeapon);
			
			for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
				CopyRandomizedWeapon(eWeapon, g_eTeamWeapon[iTeam]);
		}
	}
}

void RandomizeClientWeapon(int iClient)
{
	switch (g_cvRandomClass.IntValue)
	{
		case Mode_Normal, Mode_NormalRound: g_iClientClass[iClient] = TF2_GetRandomClass();
		case Mode_Team, Mode_All: g_iClientClass[iClient] = g_iTeamClass[TF2_GetClientTeam(iClient)];
		default: g_iClientClass[iClient] = TFClass_Unknown;
	}
	
	switch (g_cvRandomWeapons.IntValue)
	{
		case Mode_Normal, Mode_NormalRound: RandomizeWeaponIndex(g_eClientWeapon[iClient]);
		case Mode_Team, Mode_All: CopyRandomizedWeapon(g_eTeamWeapon[TF2_GetClientTeam(iClient)], g_eClientWeapon[iClient]);
		default: ResetWeaponIndex(g_eClientWeapon[iClient]);
	}
}

bool IsTeamRandomized(TFTeam nTeam)
{
	TFTeam nCvarTeam = view_as<TFTeam>(g_cvTeamClass.IntValue);
	if (nCvarTeam < view_as<TFTeam>(TEAM_MIN) || nTeam == nCvarTeam)
		return true;
	
	nCvarTeam = view_as<TFTeam>(g_cvTeamWeapons.IntValue);
	return nCvarTeam < view_as<TFTeam>(TEAM_MIN) || nTeam == nCvarTeam;
}

bool IsClassRandomized(int iClient)
{
	TFTeam nClientTeam = TF2_GetClientTeam(iClient);
	TFTeam nCvarTeam = view_as<TFTeam>(g_cvTeamClass.IntValue);
	if (nCvarTeam > TFTeam_Spectator && nClientTeam != nCvarTeam)
		return false;
	
	return g_cvRandomClass.IntValue != Mode_None;
}

bool IsWeaponRandomized(int iClient)
{
	TFTeam nClientTeam = TF2_GetClientTeam(iClient);
	TFTeam nCvarTeam = view_as<TFTeam>(g_cvTeamWeapons.IntValue);
	if (nCvarTeam > TFTeam_Spectator && nClientTeam != nCvarTeam)
		return false;
	
	return g_cvRandomWeapons.IntValue != Mode_None;
}

bool IsCosmeticRandomized(int iClient)
{
	TFTeam nClientTeam = TF2_GetClientTeam(iClient);
	TFTeam nCvarTeam = view_as<TFTeam>(g_cvTeamCosmetics.IntValue);
	if (nCvarTeam > TFTeam_Spectator && nClientTeam != nCvarTeam)
		return false;
	
	return g_cvRandomCosmetics.IntValue >= 0;
}

void CopyRandomizedWeapon(const RandomizedWeapon eInput[CLASS_MAX+1], RandomizedWeapon eOutput[CLASS_MAX+1])
{
	for (int iClass = 0; iClass < sizeof(eInput); iClass++)
		eOutput[iClass] = eInput[iClass];
}

void AddRandomizedWeapon(RandomizedWeapon eRandomized[CLASS_MAX+1], int iIndex, int iSlot)
{
	if (iSlot > WeaponSlot_Melee || g_cvWeaponsFromClass.BoolValue)
	{
		//Add index to each classes if valid
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
			if (TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass)) == iSlot)
				eRandomized[iClass].Add(iIndex, iSlot);
	}
	else
	{
		//Add index to all classes
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
			eRandomized[iClass].Add(iIndex, iSlot);
	}
}

void SetRandomizedWeaponBySlot(RandomizedWeapon eRandomized[CLASS_MAX+1], int iIndex, int iSlot)
{
	//Clear all weapons by given slot, then add to list
	for (int iClass = 0; iClass < sizeof(eRandomized); iClass++)
		eRandomized[iClass].RemoveBySlot(iSlot);
	
	AddRandomizedWeapon(eRandomized, iIndex, iSlot);
}

void RandomizeWeaponIndex(RandomizedWeapon eRandomized[CLASS_MAX+1])
{
	for (int iClass = 0; iClass < sizeof(eRandomized); iClass++)
		eRandomized[iClass].Reset();
	
	if (g_cvWeaponsFromClass.BoolValue)
	{
		//Randomize for each classes
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
			for (int iSlot = 0; iSlot <= WeaponSlot_Building; iSlot++)
				eRandomized[iClass].Add(Weapons_GetRandomIndexFromSlot(iSlot, view_as<TFClassType>(iClass)), iSlot);
	}
	else if (g_cvWeaponsCount.IntValue > -1)
	{
		int iCount = g_cvWeaponsCount.IntValue;
		
		for (int i = 0; i < iCount; i++)
		{
			//Randomize same index for all classes
			int iIndex = Weapons_GetRandomIndex(TFClass_Unknown);
			
			for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
			{
				int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
				if (iSlot == -1)
				{
					//Pick random slot
					do
					{
						iSlot = TF2_GetSlotFromIndex(iIndex, TF2_GetRandomClass());
					}
					while (iSlot == -1);
				}
				
				eRandomized[iClass].Add(iIndex, iSlot);
			}
		}
	}
	else
	{
		//Randomize same index for all classes
		for (int iSlot = 0; iSlot <= WeaponSlot_Melee; iSlot++)
		{
			int iIndex = Weapons_GetRandomIndexFromSlot(iSlot, TFClass_Unknown);
			
			for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
				eRandomized[iClass].Add(iIndex, iSlot);
		}
		
		//Randomize PDAs based on class (engineer & spy)
		for (int iSlot = WeaponSlot_PDA; iSlot <= WeaponSlot_Building; iSlot++)
			for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
				eRandomized[iClass].Add(Weapons_GetRandomIndexFromSlot(iSlot, view_as<TFClassType>(iClass)), iSlot);
	}
}

void ResetWeaponIndex(RandomizedWeapon eRandomized[CLASS_MAX+1])
{
	for (int iClass = 0; iClass < sizeof(eRandomized); iClass++)
		eRandomized[iClass].Reset();
}

public Action Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	RandomizeTeamWeapon();
	
	//Update client weapons
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			RandomizeClientWeapon(iClient);
			
			if (IsPlayerAlive(iClient) && (IsClassRandomized(iClient) || IsWeaponRandomized(iClient)))
				TF2_RespawnPlayer(iClient);
		}
	}
}

public Action Event_PlayerSpawn(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
	if (!IsCosmeticRandomized(iClient))
		return;
	
	//Destroy any cosmetics left
	int iCosmetic;
	while ((iCosmetic = FindEntityByClassname(iCosmetic, "tf_wearable*")) > MaxClients)
	{
		if (GetEntPropEnt(iCosmetic, Prop_Send, "m_hOwnerEntity") == iClient || GetEntPropEnt(iCosmetic, Prop_Send, "moveparent") == iClient)
		{
			int iIndex = GetEntProp(iCosmetic, Prop_Send, "m_iItemDefinitionIndex");
			for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
			{
				int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
				if (iSlot == LoadoutSlot_Misc)
				{
					TF2_RemoveItem(iClient, iCosmetic);
					continue;
				}
			}
		}
	}
	
	int iMaxCosmetics = g_cvRandomCosmetics.IntValue;
	if (iMaxCosmetics == 0)	//Good ol TF2 2007
		return;
	
	static const int iSlotCosmetics[] = {
		LoadoutSlot_Head,
		LoadoutSlot_Misc,
		LoadoutSlot_Misc2
	};
	
	Address pPossibleItems[CLASS_MAX * sizeof(iSlotCosmetics)];
	int iPossibleCount;
	
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		for (int i = 0; i < sizeof(iSlotCosmetics); i++)
		{
			Address pItem = SDKCall_GetLoadoutItem(iClient, view_as<TFClassType>(iClass), iSlotCosmetics[i]);
			if (TF2_IsValidEconItemView(pItem))
			{
				pPossibleItems[iPossibleCount] = pItem;
				iPossibleCount++;
			}
		}
	}
	
	SortIntegers(view_as<int>(pPossibleItems), iPossibleCount, Sort_Random);
	
	if (iMaxCosmetics > iPossibleCount)
		iMaxCosmetics = iPossibleCount;
	
	if (g_cvCosmeticsConflicts.BoolValue)
	{
		int iCount;
		
		for (int i = 0; i < iPossibleCount; i++)
		{
			int iIndex = LoadFromAddress(pPossibleItems[i] + view_as<Address>(g_iOffsetItemDefinitionIndex), NumberType_Int16);
			int iMask = TF2Econ_GetItemEquipRegionMask(iIndex);
			bool bConflicts;
			
			//Find any possible cosmetic conflicts, both weapon and cosmetic
			int iItem;
			int iPos;
			while (TF2_GetItem(iClient, iItem, iPos, true))
			{
				int iItemIndex = GetEntProp(iItem, Prop_Send, "m_iItemDefinitionIndex");
				if (0 <= iItemIndex < 65535 && iMask & TF2Econ_GetItemEquipRegionMask(iItemIndex))
				{
					bConflicts = true;
					break;
				}
			}
			
			if (!bConflicts)
			{
				TF2_EquipWeapon(iClient, TF2_GiveNamedItem(iClient, pPossibleItems[i]));
				iCount++;
				if (iCount == iMaxCosmetics)
					break;
			}
		}
	}
	else
	{
		for (int i = 0; i < iMaxCosmetics; i++)
			TF2_EquipWeapon(iClient, TF2_GiveNamedItem(iClient, pPossibleItems[i]));
	}
}

public Action Event_PlayerInventoryUpdate(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	
	//Because of blocking ValidateWeapons and ValidateWearables, make sure action weapon is correct
	Address pActionItem = SDKCall_GetLoadoutItem(iClient, nClass, LoadoutSlot_Action);
	bool bFound;
	
	int iWeapon;
	int iPos;
	while (TF2_GetItemFromLoadoutSlot(iClient, LoadoutSlot_Action, iWeapon, iPos))
	{
		if (!TF2_IsValidEconItemView(pActionItem) || GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") != LoadFromAddress(pActionItem + view_as<Address>(g_iOffsetItemDefinitionIndex), NumberType_Int16))
			TF2_RemoveItem(iClient, iWeapon);
		else
			bFound = true;
	}
	
	if (!bFound && TF2_IsValidEconItemView(pActionItem))
		TF2_EquipWeapon(iClient, TF2_GiveNamedItem(iClient, pActionItem));
	
	if (!IsWeaponRandomized(iClient))
		return;
	
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		char sClassname[256];
		GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
		int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		
		if (CanKeepWeapon(iClient, sClassname, iIndex))
			continue;
		
		if (!g_eClientWeapon[iClient][nClass].HasWeapon(iWeapon))
			TF2_RemoveItem(iClient, iWeapon);
	}
	
	
	for (iPos = 0; iPos < MAX_WEAPONS; iPos++)
	{
		if (g_eClientWeapon[iClient][nClass].iRef[iPos] != INVALID_ENT_REFERENCE && !IsValidEntity(g_eClientWeapon[iClient][nClass].iRef[iPos]))
			g_eClientWeapon[iClient][nClass].iRef[iPos] = INVALID_ENT_REFERENCE;
		
		if (g_eClientWeapon[iClient][nClass].iRef[iPos] != INVALID_ENT_REFERENCE)
			continue;
		
		int iIndex = g_eClientWeapon[iClient][nClass].iIndex[iPos];
		if (iIndex == -1 || !ItemIsAllowed(iIndex))
			continue;
		
		int iSlot = g_eClientWeapon[iClient][nClass].iSlot[iPos];
		
		Address pItem = TF2_FindReskinItem(iClient, iIndex);
		if (pItem)
			iWeapon = TF2_GiveNamedItem(iClient, pItem, iSlot);
		else
			iWeapon = TF2_CreateWeapon(iClient, iIndex, iSlot);
		
		if (iWeapon == INVALID_ENT_REFERENCE)
		{
			PrintToChat(iClient, "Unable to create weapon! index '%d'", iIndex);
			LogError("Unable to create weapon! index '%d'", iIndex);
		}
		
		//CTFPlayer::ItemsMatch doesnt like normal item quality, so lets use unique instead
		if (view_as<TFQuality>(GetEntProp(iWeapon, Prop_Send, "m_iEntityQuality")) == TFQual_Normal)
			SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", TFQual_Unique);
		
		TF2_EquipWeapon(iClient, iWeapon);
		
		if (ViewModels_ShouldBeInvisible(iWeapon, nClass))
			ViewModels_EnableInvisible(iWeapon);
		
		g_eClientWeapon[iClient][nClass].iRef[iPos] = EntIndexToEntRef(iWeapon);
	}
	
	
	//Set ammo to 0, CTFPlayer::GetMaxAmmo detour will correct this, adding ammo by current
	for (int iAmmoType = 0; iAmmoType < TF_AMMO_COUNT; iAmmoType++)
		SetEntProp(iClient, Prop_Send, "m_iAmmo", 0, _, iAmmoType);
	
	//Set active weapon if dont have one
	//TODO update this
	if (GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") == INVALID_ENT_REFERENCE)
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
	
	if (bDeadRinger)
		g_bFeignDeath[iClient] = true;
	
	//Only generate new weapons if killed from attacker, and it's a normal round
	if (0 < iAttacker <= MaxClients && IsClientInGame(iAttacker) && iClient != iAttacker && !bDeadRinger && g_cvRandomWeapons.IntValue == Mode_Normal)
		RandomizeClientWeapon(iClient);
}

public Action Event_EurekaTeleport(int iClient, const char[] sCommand, int iArgs)
{
	g_iClientEurekaTeleporting = iClient;
	return Plugin_Continue;
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
		g_iClientCurrentClass[iClient] = TF2_GetPlayerClass(iClient);
	
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