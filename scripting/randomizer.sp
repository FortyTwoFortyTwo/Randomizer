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

#define MAX_WEAPONS		40			//Max 48 m_hMyWeapons, give 8 as a space for other weapons (PDA, action etc)
#define MAX_GROUPS		64

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
	RandomizedType_Rune,		//Rune from Mannpower
	RandomizedType_Spells,		//Spells from Halloween Spellbook
	
	RandomizedType_MAX,
}

enum RandomizedAction	//When should loadout be rerolled
{
	RandomizedAction_None			= 0,
	RandomizedAction_Death			= (1<<0),	//Any death
	RandomizedAction_DeathKill		= (1<<1),	//Death from player kill
	RandomizedAction_DeathEnv		= (1<<2),	//Death from environment
	RandomizedAction_DeathSuicide	= (1<<3),	//Death from suicide
	RandomizedAction_Kill			= (1<<4),	//Kill
	RandomizedAction_Assist			= (1<<5),	//Assist
	RandomizedAction_Round			= (1<<6),	//Round start
	RandomizedAction_RoundFull		= (1<<7),	//Full round start
	RandomizedAction_CPCapture		= (1<<8),	//Control point capture
	RandomizedAction_FlagCapture	= (1<<9),	//Flag capture
	RandomizedAction_PassScore		= (1<<10),	//Pass Goal
}

enum struct RandomizedInfo
{
	RandomizedType nType;				//What type to randomize
	char sTrigger[MAX_TARGET_LENGTH];	//Who can trigger the reroll
	char sGroup[MAX_TARGET_LENGTH];		//Who would get affected for randomization
	RandomizedAction nAction;			//When to reroll loadout
	bool bSame;							//Should everyone in group get same loadout
	int iCount;							//Amount to reroll (weapons and cosmetics)
	int iCountSlot[WeaponSlot_Melee+1];	//Amount to reroll for specific slot (weapons)
	bool bDefaultClass;					//Whenever if it should be default class only (weapons)
	bool bConflicts;					//Whenever to chec kfor conflicts (cosmetics)
	
	void Reset()
	{
		this.nType = RandomizedType_None;
		this.sGroup = "";
		this.sTrigger = "";
		this.nAction = RandomizedAction_None;
		this.bSame = false;
		this.iCount = 0;
		this.iCountSlot = { 0, 0, 0 };
		this.bDefaultClass = false;
		this.bConflicts = false;
	}
}

enum struct RandomizedWeapon
{
	int iIndex;	//Index to set
	int iSlot;	//Slot to use
	int iRef;	//Weapon entity if exists
	
	void Reset()
	{
		this.iIndex = -1;
		this.iSlot = -1;
		this.iRef = INVALID_ENT_REFERENCE;
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
int g_iOffsetItemDefinitionIndex;
int g_iOffsetPlayerShared;
int g_iOffsetAlwaysAllow;

ConVar g_cvEnabled;
ConVar g_cvDroppedWeapons;
ConVar g_cvHuds;
ConVar g_cvRandomize[view_as<int>(RandomizedType_MAX)];

bool g_bClientRefresh[TF_MAXPLAYERS];

TFClassType g_iClientCurrentClass[TF_MAXPLAYERS];
bool g_bFeignDeath[TF_MAXPLAYERS];
int g_iHypeMeterLoaded[TF_MAXPLAYERS] = {INVALID_ENT_REFERENCE, ...};
bool g_bWeaponDecap[TF_MAXPLAYERS];
Handle g_hTimerClientHud[TF_MAXPLAYERS];

bool g_bOnTakeDamage;
int g_iGainingRageWeapon = INVALID_ENT_REFERENCE;
int g_iTouchItem = INVALID_ENT_REFERENCE;
int g_iTouchToucher = INVALID_ENT_REFERENCE;
int g_iClientEurekaTeleporting;
int g_iClientInitClass;

#include "randomizer/controls.sp"
#include "randomizer/huds.sp"
#include "randomizer/viewmodels.sp"
#include "randomizer/weapons.sp"

#include "randomizer/commands.sp"
#include "randomizer/convar.sp"
#include "randomizer/dhook.sp"
#include "randomizer/event.sp"
#include "randomizer/group.sp"
#include "randomizer/loadout.sp"
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
	
	delete hGameData;
	
	//Any weapons using m_Item would work to get offset
	g_iOffsetItemDefinitionIndex = FindSendPropInfo("CTFWearable", "m_iItemDefinitionIndex") - FindSendPropInfo("CTFWearable", "m_Item");
	g_iOffsetPlayerShared = FindSendPropInfo("CTFPlayer", "m_Shared");
	
	/* This is an ugly way to get offset, but atleast it should almost never break from tf2 updates,
	 * tf2 updating offset before all of this wouldn't break, and reports error if tf2 ever somehow broke it.
	 *
	 * There are properties and netclass between m_bValidatedAttachedEntity and m_bDisguiseWearable:
	 * - CEconEntity::m_bValidatedAttachedEntity
	 * - CEconEntity::m_bHasParticleSystems
	 * - CEconEntity::m_hOldProvidee
	 * - CEconEntity::m_iOldOwnerClass
	 * - CEconWearable::m_bAlwaysAllow
	 * - CTFWearable::m_bDisguiseWearable
	 *
	 * Windows has an extra +4 offset, while Linux does not have any extra offset between each netclass,
	 * figure out by gap between properties on whenever were in windows or linux
	 */
	int iOffsetValidatedAttachedEntity = FindSendPropInfo("CTFWearable", "m_bValidatedAttachedEntity");
	int iOffsetDisguiseWearable = FindSendPropInfo("CTFWearable", "m_bDisguiseWearable");
	if (iOffsetDisguiseWearable - iOffsetValidatedAttachedEntity == 0x14)
		g_iOffsetAlwaysAllow = iOffsetDisguiseWearable - 0x08;	//Linux
	else if (iOffsetDisguiseWearable - iOffsetValidatedAttachedEntity == 0x14 + 0x08)
		g_iOffsetAlwaysAllow = iOffsetDisguiseWearable - 0x08 - 0x04;	//Windows
	else
		LogError("Could not figure out offset for CEconWearable::m_bAlwaysAllow");
	
	Commands_Init();
	ConVar_Init();
	Controls_Init();
	Event_Init();
	Group_Init();
	Huds_Init();
	Loadout_Init();
	ViewModels_Init();
	Weapons_Init();
	
	AddCommandListener(Console_EurekaTeleport, "eureka_teleport");
	AddCommandListener(Console_DropItem, "dropitem");
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
	
	ConVar_Refresh();	//After Weapons_Refresh
	
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
				Loadout_RefreshClient(iClient);
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
	
	Loadout_RandomizeClientAll(iClient);
}

public void OnClientDisconnect(int iClient)
{
	if (!g_bEnabled)
		return;
	
	//Dont drop rune from disconnect
	Loadout_ResetClientRune(iClient);
	
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
	
	if (nCond == TFCond_RestrictToMelee || nCond == TFCond_MeleeOnly)
	{
		//TFCond_RestrictToMelee is for heavy steak and knockout powerup,
		// TFCond_MeleeOnly is for halloween spells
		
		//Make sure client is actually switched to melee
		bool bSwitched;
		
		int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
		if (iActiveWeapon != INVALID_ENT_REFERENCE && (TF2_GetSlot(iActiveWeapon) == WeaponSlot_Melee || IsClassname(iActiveWeapon, "tf_weapon_grapplinghook")))
			bSwitched = true;	//Active weapon is already good, dont need to switch
		
		//Tempoary remove attribute TF2 applied so we can actually switch to it
		if (nCond == TFCond_MeleeOnly)
			TF2Attrib_RemoveByName(iClient, "disable weapon switch");
		
		int iWeapon, iPos;
		while (TF2_GetItemFromLoadoutSlot(iClient, LoadoutSlot_Melee, iWeapon, iPos))
		{
			if (iActiveWeapon == iWeapon || !TF2_CanSwitchTo(iClient, iWeapon))
				continue;
			
			if (!bSwitched)
			{
				TF2_SwitchToWeapon(iClient, iWeapon);
				bSwitched = true;
			}
			else
			{
				if (nCond == TFCond_MeleeOnly)
					TF2Attrib_SetByName(iClient, "disable weapon switch", 1.0);
				
				SetEntPropEnt(iClient, Prop_Send, "m_hLastWeapon", iWeapon);
				return;
			}
		}
		
		while (TF2_GetItemFromClassname(iClient, "tf_weapon_grapplinghook", iWeapon, iPos))
		{
			if (iActiveWeapon == iWeapon || !TF2_CanSwitchTo(iClient, iWeapon))
				continue;
			
			if (!bSwitched)
			{
				TF2_SwitchToWeapon(iClient, iWeapon);
				bSwitched = true;
			}
			else
			{
				if (nCond == TFCond_MeleeOnly)
					TF2Attrib_SetByName(iClient, "disable weapon switch", 1.0);
				
				SetEntPropEnt(iClient, Prop_Send, "m_hLastWeapon", iWeapon);
				return;
			}
		}
		
		SetEntPropEnt(iClient, Prop_Send, "m_hLastWeapon", INVALID_ENT_REFERENCE);
		if (nCond == TFCond_MeleeOnly)
			TF2Attrib_SetByName(iClient, "disable weapon switch", 1.0);
	}
}

public void TF2_OnConditionRemoved(int iClient, TFCond nCond)
{
	if (!g_bEnabled)
		return;
	
	//TODO dont remove cond if under steak effect, steak itself is already buggy that needs to be fixed
	if (nCond == TFCond_RuneKnockout)
		TF2_RemoveCondition(iClient, TFCond_RestrictToMelee);
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
		Properties_RemoveWeapon(iEntity);
		
		if (g_iTouchItem == iEntity) //SDKHook doesn't call hook while pending deletion, call it now
			Item_TouchPost(g_iTouchItem, g_iTouchToucher);
	}
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
			Loadout_RefreshClient(iClient);
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
		Loadout_RefreshClient(iClient);
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

bool CanEquipIndex(int iClient, int iIndex)
{
	int iSlot = -1;
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		iSlot = TF2Econ_GetItemLoadoutSlot(iIndex, view_as<TFClassType>(iClass));
		if (iSlot != -1)
			break;
	}
	
	//Allow utility (passtime gun)
	if (iSlot == LoadoutSlot_Utility)
		return true;
	
	if (LoadoutSlot_Primary <= iSlot <= LoadoutSlot_PDA2 && Group_IsClientRandomized(iClient, RandomizedType_Weapons))	//Dont allow weapons
		return false;
	
	if (iSlot == LoadoutSlot_Misc && Group_IsClientRandomized(iClient, RandomizedType_Cosmetics))	//Dont allow cosmetics
		return false;
	
	if (iSlot == LoadoutSlot_Action && Group_IsClientRandomized(iClient, RandomizedType_Spells))
	{
		//Don't allow wearable action items, so auto-equip spellbook HUD can appear properly client-side
		char sClassname[256];
		TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
		if (StrContains(sClassname, "tf_weapon") != 0)
			return false;
	}
	
	//Should be allowed
	return true;
}

public Action Console_EurekaTeleport(int iClient, const char[] sCommand, int iArgs)
{
	g_iClientEurekaTeleporting = iClient;
	SetClientClass(iClient, TFClass_Engineer);
	return Plugin_Continue;
}

public Action Console_DropItem(int iClient, const char[] sCommand, int iArgs)
{
	static bool bSkip;
	if (bSkip)
		return Plugin_Continue;
	
	if (Group_IsClientRandomized(iClient, RandomizedType_Rune))
	{
		//Call itself but without rune cond, so item flag can be dropped
		Loadout_ResetClientRune(iClient);
		bSkip = true;
		FakeClientCommand(iClient, "dropitem");
		bSkip = false;
		Loadout_ApplyClientRune(iClient);
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
	if (!g_bEnabled || g_bAllowGiveNamedItem)
		return Plugin_Continue;
	
	if (CanEquipIndex(iClient, iIndex))
		return Plugin_Continue;
	
	return Plugin_Handled;
}