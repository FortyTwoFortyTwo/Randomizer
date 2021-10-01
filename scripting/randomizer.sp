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

#define PLUGIN_VERSION			"1.9.0"
#define PLUGIN_VERSION_REVISION	"manual"

#define TF_MAXPLAYERS	34	//32 clients + 1 for 0/world/console + 1 for replay/SourceTV
#define CONFIG_MAXCHAR	64

#define CLASS_MIN	1	//First valid TFClassType, TFClass_Scout
#define CLASS_MAX	9	//Last valid TFClassType, TFClass_Engineer

#define TEAM_MIN	2	//First valid TFTeam, TFTeam_Red
#define TEAM_MAX	3	//Last valid TFTeam, TFTeam_Blue

#define DEFAULT_MAX_AMMO	1000	//Used for cases when 2 weapons use same ammotype, number only matters when diving for ammo pickups
#define MAX_WEAPONS		40			//Max 48 m_hMyWeapons, give 8 as a space for other weapons (PDA, action etc)

#define PARTICLE_BEAM_BLU	"medicgun_beam_blue"
#define PARTICLE_BEAM_RED	"medicgun_beam_red"

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
	TF_AMMO_GRENADES1,	//Weapon misc ammo 1
	TF_AMMO_GRENADES2,	//Weapon misc ammo 2
	TF_AMMO_GRENADES3,
	TF_AMMO_COUNT
};

enum EAmmoSource
{
	kAmmoSource_Pickup,					// this came from either a box of ammo or a player's dropped weapon
	kAmmoSource_Resupply,				// resupply cabinet and/or full respawn
	kAmmoSource_DispenserOrCart,		// the player is standing next to an engineer's dispenser or pushing the cart in a payload game
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

enum RandomizedType	//What to randomize
{
	RandomizedType_None = -1,
	RandomizedType_Class,		//Player Class
	RandomizedType_Weapons,		//Weapons
	RandomizedType_Cosmetics,	//Cosmetics
	RandomizedType_Rune,	//Rune Rune
	RandomizedType_MAX,
}

enum RandomizedTarget	//Who to randomize
{
	RandomizedTarget_None = -1,
	RandomizedTarget_Self,		//Only self
	RandomizedTarget_Global,	//Everyone in group
	RandomizedTarget_Same,		//Everyone in group as same loadout
}

enum RandomizedReroll	//When should loadout be rerolled
{
	RandomizedReroll_None			= 0,
	RandomizedReroll_Death			= (1<<0),	//Non-environment death
	RandomizedReroll_Environment	= (1<<1),	//Environment death
	RandomizedReroll_Suicide		= (1<<2),	//Suicide death
	RandomizedReroll_Kill			= (1<<3),	//Kill
	RandomizedReroll_Assist			= (1<<4),	//Assist
	RandomizedReroll_Round			= (1<<5),	//Round start
	RandomizedReroll_FullRound		= (1<<6),	//Full round start
	RandomizedReroll_Capture		= (1<<7),	//Control point or flag capture
	RandomizedReroll_Force			= (0xFFFFFFFF),	//Force reroll
}

enum struct RandomizedInfo
{
	RandomizedType nType;				//What type to randomize
	char sTarget[MAX_TARGET_LENGTH];	//Who to call for randomization
	RandomizedTarget nTarget;			//Who get randomized
	RandomizedReroll nReroll;			//When to reroll loadout
	
	TFClassType nClass;	//Class
	int iRuneType;	//Type of rune
	int iOldRuneType;	//Previous rune type
	
	void SetRuneType(int iRunType)
	{
		this.iOldRuneType = this.iRuneType;
		this.iRuneType = iRunType;
	}
	
	void Reset()
	{
		this.nType = RandomizedType_None;
		this.sTarget = "";
		this.nTarget = RandomizedTarget_None;
		this.nReroll = RandomizedReroll_None;
		
		this.nClass = TFClass_Unknown;
		this.iRuneType = -1;
		this.iOldRuneType = -1;
	}
}

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
int g_iRuneCount;
int g_iOffsetItemDefinitionIndex = -1;
int g_iOffsetPlayerShared;

ConVar g_cvEnabled;
ConVar g_cvWeaponsFromClass;
ConVar g_cvWeaponsCount;
ConVar g_cvWeaponsSlotCount[WeaponSlot_Melee+1];
ConVar g_cvCosmeticsConflicts;
ConVar g_cvRandomize[view_as<int>(RandomizedType_MAX)];
ConVar g_cvDroppedWeapons;
ConVar g_cvHuds;

RandomizedInfo g_eClientInfo[TF_MAXPLAYERS];
RandomizedWeapon g_eClientWeapon[TF_MAXPLAYERS][CLASS_MAX+1];
bool g_bClientRefresh[TF_MAXPLAYERS];

TFClassType g_iClientCurrentClass[TF_MAXPLAYERS];
int g_iAllowPlayerClass[TF_MAXPLAYERS];
bool g_bFeignDeath[TF_MAXPLAYERS];
bool g_bWeaponDecap[TF_MAXPLAYERS];
Handle g_hTimerClientHud[TF_MAXPLAYERS];

int g_iGainingRageWeapon = INVALID_ENT_REFERENCE;
int g_iClientEurekaTeleporting;
bool g_bKillRune;

#include "randomizer/controls.sp"
#include "randomizer/huds.sp"
#include "randomizer/viewmodels.sp"
#include "randomizer/weapons.sp"

#include "randomizer/commands.sp"
#include "randomizer/convar.sp"
#include "randomizer/dhook.sp"
#include "randomizer/event.sp"
#include "randomizer/group.sp"
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
	LoadTranslations("core.phrases");
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
	
	Group_Init();	//Group before convar
	
	Commands_Init();
	ConVar_Init();
	Controls_Init();
	Event_Init();
	Huds_Init();
	ViewModels_Init();
	Weapons_Init();
	
	AddCommandListener(Event_EurekaTeleport, "eureka_teleport");
	AddCommandListener(Event_DropItem, "dropitem");
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_eClientInfo[iClient].Reset();
		ResetWeaponIndex(g_eClientWeapon[iClient]);
	}
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
	
	if (!g_iRuneCount)
		LoadRuneCount();
	
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

public void OnGameFrame()
{
	//See if any force refresh is needed
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			if (g_bClientRefresh[iClient])
				RefreshClient(iClient);
		}
	}
}

public void OnClientPutInServer(int iClient)
{
	if (!g_bEnabled)
		return;
	
	g_hTimerClientHud[iClient] = CreateTimer(0.2, Huds_ClientDisplay, iClient);
	
	DHook_HookGiveNamedItem(iClient);
	DHook_HookClient(iClient);
	SDKHook_HookClient(iClient);
	
	Group_RandomizeClient(iClient, RandomizedReroll_Force);
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

public void TF2_OnConditionAdded(int iClient, TFCond nCond)
{
	if (!g_bEnabled)
		return;
	
	if (nCond == TFCond_RuneKnockout)	//Just giving knockout rune isnt enough, TF2 gave both knockout and melee only cond
		TF2_AddCondition(iClient, TFCond_RestrictToMelee, TFCondDuration_Infinite);
	
	//TODO remove melee cond when knockout cond removed aswell
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (!g_bEnabled)
		return;
	
	DHook_OnEntityCreated(iEntity, sClassname);
	SDKHook_OnEntityCreated(iEntity, sClassname);
	
	if (StrEqual(sClassname, "tf_dropped_weapon") && !g_cvDroppedWeapons.BoolValue)
		RemoveEntity(iEntity);
	else if (StrEqual(sClassname, "item_powerup_rune") && g_bKillRune)
		RemoveEntity(iEntity);
}

public void OnEntityDestroyed(int iEntity)
{
	if (0 <= iEntity < 2048)
		Properties_RemoveWeapon(iEntity);
}

void EnableRandomizer()
{
	g_bEnabled = true;
	Patch_Enable();
	
	DHook_EnableDetour();
	DHook_HookGamerules();
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			OnClientPutInServer(iClient);
			RefreshClient(iClient);
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
		RefreshClient(iClient);
}

void LoadRuneCount()
{
	g_iRuneCount = 0;
	
	//Figure out how many Rune there is by model, if invalid rune type is passed,
	// default model is used, which is same as rune type 0
	char sModel[PLATFORM_MAX_PATH], sDefaultModel[PLATFORM_MAX_PATH];
	int iRune = CreateEntityByName("item_powerup_rune");
	int iOffset = FindDataMapInfo(iRune, "m_bDisabled") + 28;
	
	DispatchSpawn(iRune);
	GetEntityModel(iRune, sDefaultModel, sizeof(sDefaultModel));
	RemoveEntity(iRune);
	
	do
	{
		g_iRuneCount++;
		
		iRune = CreateEntityByName("item_powerup_rune");
		SetEntData(iRune, iOffset, g_iRuneCount);
		
		DispatchSpawn(iRune);
		GetEntityModel(iRune, sModel, sizeof(sModel));
		RemoveEntity(iRune);
	}
	while (!StrEqual(sModel, sDefaultModel));
}

void RefreshClient(int iClient)
{
	g_bClientRefresh[iClient] = false;
	
	if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))	//Player will regardless get refreshed on spawn
		return;
	
	UpdateClientInfo(iClient);
	
	if (Group_IsClientRandomized(iClient, RandomizedType_Class))
		TF2_SetPlayerClass(iClient, g_eClientInfo[iClient].nClass);
	
	if (Group_IsClientRandomized(iClient, RandomizedType_Weapons))
		RefreshClientWeapons(iClient);
	
	if (Group_IsClientRandomized(iClient, RandomizedType_Rune))
	{
		SDKCall_SetCarryingRuneType(GetEntityAddress(iClient) + view_as<Address>(g_iOffsetPlayerShared), g_eClientInfo[iClient].iRuneType);
	}
	else if (g_eClientInfo[iClient].iOldRuneType != -1)
	{
		SDKCall_SetCarryingRuneType(GetEntityAddress(iClient) + view_as<Address>(g_iOffsetPlayerShared), -1);
		g_eClientInfo[iClient].iOldRuneType = -1;
	}
	
	//Destroy any cosmetics left
	int iCosmetic;
	while ((iCosmetic = FindEntityByClassname(iCosmetic, "tf_wearable*")) > MaxClients)
	{
		if (GetEntPropEnt(iCosmetic, Prop_Send, "m_hOwnerEntity") == iClient)
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
	
	static const int iSlotCosmetics[] = {
		LoadoutSlot_Head,
		LoadoutSlot_Misc,
		LoadoutSlot_Misc2
	};
	
	if (!Group_IsClientRandomized(iClient, RandomizedType_Cosmetics))
	{
		//Default cosmetics
		TFClassType nClass = TF2_GetPlayerClass(iClient);
		for (int i = 0; i < sizeof(iSlotCosmetics); i++)
		{
			Address pItem = SDKCall_GetLoadoutItem(iClient, nClass, iSlotCosmetics[i]);
			if (TF2_IsValidEconItemView(pItem))
				TF2_EquipWeapon(iClient, TF2_GiveNamedItem(iClient, pItem));
		}
	}
	else
	{
		int iMaxCosmetics = 0 /*g_cvRandomCosmetics.IntValue*/;	//TODO change this
		if (iMaxCosmetics == 0)	//Good ol TF2 2007
			return;
		
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
}

void RefreshClientWeapons(int iClient)
{
	Properties_SaveActiveWeaponAmmo(iClient);
	
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	
	int iWeapon, iPos;
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
			continue;
		}
		
		//CTFPlayer::ItemsMatch doesnt like normal item quality, so lets use unique instead
		if (view_as<TFQuality>(GetEntProp(iWeapon, Prop_Send, "m_iEntityQuality")) == TFQual_Normal)
			SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", TFQual_Unique);
		
		TF2_EquipWeapon(iClient, iWeapon);
		
		//Fill charge meter
		float flVal;
		if (!TF2_WeaponFindAttribute(iWeapon, "item_meter_resupply_denied", flVal) || flVal == 0.0)
			Properties_AddWeaponChargeMeter(iClient, iWeapon, 100.0);
		
		//Fill ammo
		if (HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType"))
		{
			int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
			if (iAmmoType != -1)
			{
				int iMaxAmmo = TF2_GetMaxAmmo(iClient, iWeapon, iAmmoType);
				int iAmmo = TF2_GiveAmmo(iClient, iWeapon, 0, iMaxAmmo, iAmmoType, true, kAmmoSource_Resupply);
				Properties_SetWeaponPropInt(iWeapon, "m_iAmmo", iAmmo);
				if (iWeapon == GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon"))
					Properties_UpdateActiveWeaponAmmo(iClient);
			}
		}
		
		if (ViewModels_ShouldBeInvisible(iWeapon, nClass))
			ViewModels_EnableInvisible(iWeapon);
		
		g_eClientWeapon[iClient][nClass].iRef[iPos] = EntIndexToEntRef(iWeapon);
	}
	
	//Set active weapon if dont have one
	//TODO update this
	if (GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") == INVALID_ENT_REFERENCE)
	{
		for (int iSlot = 0; iSlot <= WeaponSlot_Melee; iSlot++)
		{
			iWeapon = GetPlayerWeaponSlot(iClient, iSlot);	//Dont want wearable
			if (iWeapon != INVALID_ENT_REFERENCE)
			{
				TF2_SwitchToWeapon(iClient, iWeapon);
				break;
			}
		}
	}
}

void RandomizeClass(RandomizedInfo eGroup)
{
	eGroup.nClass = TF2_GetRandomClass();
}

void RandomizeWeapon(RandomizedWeapon eRandomized[CLASS_MAX+1])
{
	for (int iClass = 0; iClass < sizeof(eRandomized); iClass++)
		eRandomized[iClass].Reset();
	
	bool bWeaponsFromClass = g_cvWeaponsFromClass.BoolValue;
	
	int iMinCount = g_cvWeaponsCount.IntValue;
	int iSlotMinCount;
	int iSlotForceCount[WeaponSlot_Melee+1];
	
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_Melee; iSlot++)
	{
		iSlotForceCount[iSlot] = g_cvWeaponsSlotCount[iSlot].IntValue;
		iSlotMinCount += iSlotForceCount[iSlot];
	}
	
	if (iMinCount > iSlotMinCount)
		iMinCount -= iSlotMinCount;
	else if (iMinCount < iSlotMinCount)
		iMinCount = 0;
	
	if (bWeaponsFromClass)
	{
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			int iSlotCount[WeaponSlot_Melee+1];
			iSlotCount = iSlotForceCount;
			
			for (int i = 0; i < iMinCount; i++)
			{
				int iIndex = Weapons_GetRandomIndex(view_as<TFClassType>(iClass));
				int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
				eRandomized[iClass].Add(iIndex, iSlot);
				
				if (WeaponSlot_Primary <= iSlot <= WeaponSlot_Melee && iSlotCount[iSlot] > 0)
				{
					//General random used one of min slot count, allow another general random
					iSlotCount[iSlot]--;
					iMinCount++;
				}
			}
			
			//Fill remaining as force slot
			for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_Melee; iSlot++)
				for (int i = 0; i < iSlotCount[iSlot]; i++)
					eRandomized[iClass].Add(Weapons_GetRandomIndex(view_as<TFClassType>(iClass), iSlot), iSlot);
		}
	}
	else
	{
		int iSlotCount[WeaponSlot_Melee+1];
		iSlotCount = iSlotForceCount;
		
		for (int i = 0; i < iMinCount; i++)
		{
			int iIndex = Weapons_GetRandomIndex();
			
			//Pick random slot
			int iSlot = -1;
			do
			{
				iSlot = TF2_GetSlotFromIndex(iIndex, TF2_GetRandomClass());
			}
			while (iSlot == -1);
			
			for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
				eRandomized[iClass].Add(iIndex, iSlot);
			
			if (WeaponSlot_Primary <= iSlot <= WeaponSlot_Melee && iSlotCount[iSlot] > 0)
			{
				//General random used one of min slot count, allow another general random
				iSlotCount[iSlot]--;
				iMinCount++;
			}
		}
		
		//Fill remaining as force slot
		for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_Melee; iSlot++)
		{
			for (int i = 0; i < iSlotCount[iSlot]; i++)
			{
				int iIndex = Weapons_GetRandomIndex(TFClass_Unknown, iSlot);
				for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
					eRandomized[iClass].Add(iIndex, iSlot);
			}
		}
	}
	
	//Randomize PDAs based on class (engineer & spy)
	for (int iSlot = WeaponSlot_PDA; iSlot <= WeaponSlot_Building; iSlot++)
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
			eRandomized[iClass].Add(Weapons_GetRandomIndex(view_as<TFClassType>(iClass), iSlot), iSlot);
}

void RandomizeCosmetics()
{
	//... :/
}

void RandomizeRune(RandomizedInfo eGroup)
{
	eGroup.SetRuneType(GetRandomInt(0, g_iRuneCount - 1));
}

void UpdateClientInfo(int iClient)
{
	RandomizedInfo eInfo;
	RandomizedWeapon eWeapon[CLASS_MAX+1];
	
	if (Group_GetClientSameInfo(iClient, RandomizedType_Class, eInfo))
		g_eClientInfo[iClient].nClass = eInfo.nClass;
	
	if (Group_GetClientSameWeapon(iClient, RandomizedType_Weapons, eWeapon))
		CopyRandomizedWeapon(eWeapon, g_eClientWeapon[iClient]);
	
//	if (Group_GetClientSameInfo(iClient, RandomizedType_Cosmetics, eInfo))
//		g_eClientInfo[iClient].nClass = eInfo.nClass;
	
	if (Group_GetClientSameInfo(iClient, RandomizedType_Rune, eInfo))
	{
		g_eClientInfo[iClient].iOldRuneType = eInfo.iOldRuneType;
		g_eClientInfo[iClient].iRuneType = eInfo.iRuneType;
	}
}

void CopyRandomizedWeapon(const RandomizedWeapon eInput[CLASS_MAX+1], RandomizedWeapon eOutput[CLASS_MAX+1])
{
	//Dont whipe ref if index and slot is the same
	for (int iClass = 0; iClass < sizeof(eInput); iClass++)
	{
		for (int i = 0; i < MAX_WEAPONS; i++)
		{
			if (eOutput[iClass].iIndex[i] != eInput[iClass].iIndex[i] || eOutput[iClass].iSlot[i] != eInput[iClass].iSlot[i])
			{
				eOutput[iClass].iIndex[i] = eInput[iClass].iIndex[i];
				eOutput[iClass].iSlot[i] = eInput[iClass].iSlot[i];
				eOutput[iClass].iRef[i] = eInput[iClass].iRef[i];
			}
		}
	}
}

void SetRandomizedWeapon(RandomizedWeapon eRandomized[CLASS_MAX+1], RandomizedWeapon eList, int iCount)
{
	ResetWeaponIndex(eRandomized);
	
	for (int j = 0; j < iCount; j++)
		AddRandomizedWeapon(eRandomized, eList.iIndex[j], eList.iSlot[j]);
}

void SetSlotRandomizedWeapon(RandomizedWeapon eRandomized[CLASS_MAX+1], RandomizedWeapon eList, int iCount)
{
	bool bSlot[WeaponSlot_Building+1];
	
	for (int i = 0; i < iCount; i++)
	{
		if (!bSlot[eList.iSlot[i]])
		{
			RemoveRandomizedWeaponBySlot(eRandomized, eList.iSlot[i]);
			bSlot[eList.iSlot[i]] = true;
		}
		
		AddRandomizedWeapon(eRandomized, eList.iIndex[i], eList.iSlot[i]);
	}
}

void GiveRandomizedWeapon(RandomizedWeapon eRandomized[CLASS_MAX+1], RandomizedWeapon eList, int iCount)
{
	for (int j = 0; j < iCount; j++)
		AddRandomizedWeapon(eRandomized, eList.iIndex[j], eList.iSlot[j]);
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

void RemoveRandomizedWeaponBySlot(RandomizedWeapon eRandomized[CLASS_MAX+1], int iSlot)
{
	for (int iClass = 0; iClass < sizeof(eRandomized); iClass++)
		eRandomized[iClass].RemoveBySlot(iSlot);
}

void ResetWeaponIndex(RandomizedWeapon eRandomized[CLASS_MAX+1])
{
	for (int iClass = 0; iClass < sizeof(eRandomized); iClass++)
		eRandomized[iClass].Reset();
}

public Action Event_EurekaTeleport(int iClient, const char[] sCommand, int iArgs)
{
	g_iClientEurekaTeleporting = iClient;
	return Plugin_Continue;
}

public Action Event_DropItem(int iClient, const char[] sCommand, int iArgs)
{
	static bool bSkip;
	if (bSkip)
		return Plugin_Continue;
	
	if (Group_IsClientRandomized(iClient, RandomizedType_Rune))
	{
		//Call itself but without rune cond, so item flag can be dropped
		SDKCall_SetCarryingRuneType(GetEntityAddress(iClient) + view_as<Address>(g_iOffsetPlayerShared), -1);
		bSkip = true;
		FakeClientCommand(iClient, "dropitem");
		bSkip = false;
		SDKCall_SetCarryingRuneType(GetEntityAddress(iClient) + view_as<Address>(g_iOffsetPlayerShared), g_eClientInfo[iClient].iRuneType);
		return Plugin_Handled;
	}
	
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