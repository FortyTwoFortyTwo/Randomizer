static Handle g_hDHookSecondaryAttack;
static Handle g_hDHookCanBeUpgraded;
static Handle g_hDHookGiveNamedItem;
static Handle g_hDHookFrameUpdatePostEntityThink;

static int g_iOffsetItemDefinitionIndex = -1;
static int g_iClientCalculateMaxSpeed;

static int g_iHookIdGiveNamedItem[TF_MAXPLAYERS+1];
static bool g_bDoClassSpecialSkill[TF_MAXPLAYERS+1];
static int g_iAllowPlayerClass[TF_MAXPLAYERS+1];

public void DHook_Init(GameData hGameData)
{
	DHook_CreateDetour(hGameData, "CTFPlayer::GetMaxAmmo", DHook_GetMaxAmmoPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::Taunt", DHook_TauntPre, DHook_TauntPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::CanAirDash", _, DHook_CanAirDashPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::ValidateWeapons", DHook_ValidateWeaponsPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::DoClassSpecialSkill", DHook_DoClassSpecialSkillPre, DHook_DoClassSpecialSkillPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetChargeEffectBeingProvided", DHook_GetChargeEffectBeingProvidedPre, DHook_GetChargeEffectBeingProvidedPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::IsPlayerClass", DHook_IsPlayerClassPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetEntityForLoadoutSlot", DHook_GetEntityForLoadoutSlotPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::TeamFortress_CalculateMaxSpeed", DHook_CalculateMaxSpeedPre, DHook_CalculateMaxSpeedPost);
	DHook_CreateDetour(hGameData, "CTFPlayerShared::InCond", _, DHook_InCondPost);
	DHook_CreateDetour(hGameData, "CTFGameStats::Event_PlayerFiredWeapon", DHook_PlayerFiredWeaponPre, _);
	
	g_hDHookSecondaryAttack = DHook_CreateVirtual(hGameData, "CBaseCombatWeapon::SecondaryAttack");
	g_hDHookCanBeUpgraded = DHook_CreateVirtual(hGameData, "CBaseObject::CanBeUpgraded");
	g_hDHookGiveNamedItem = DHook_CreateVirtual(hGameData, "CTFPlayer::GiveNamedItem");
	g_hDHookFrameUpdatePostEntityThink = DHook_CreateVirtual(hGameData, "CGameRules::FrameUpdatePostEntityThink");
	
	g_iOffsetItemDefinitionIndex = hGameData.GetOffset("CEconItemView::m_iItemDefinitionIndex");
}

static void DHook_CreateDetour(GameData hGameData, const char[] sName, DHookCallback preCallback = INVALID_FUNCTION, DHookCallback postCallback = INVALID_FUNCTION)
{
	Handle hDetour = DHookCreateFromConf(hGameData, sName);
	if (!hDetour)
	{
		LogError("Failed to create detour: %s", sName);
	}
	else
	{
		if (preCallback != INVALID_FUNCTION)
			if (!DHookEnableDetour(hDetour, false, preCallback))
				LogError("Failed to enable pre detour: %s", sName);
		
		if (postCallback != INVALID_FUNCTION)
			if (!DHookEnableDetour(hDetour, true, postCallback))
				LogError("Failed to enable post detour: %s", sName);
		
		delete hDetour;
	}
}

static Handle DHook_CreateVirtual(GameData hGameData, const char[] sName)
{
	Handle hHook = DHookCreateFromConf(hGameData, sName);
	if (!hHook)
		LogError("Failed to create hook: %s", sName);
	
	return hHook;
}

void DHook_HookGiveNamedItem(int iClient)
{
	if (g_hDHookGiveNamedItem && !g_bTF2Items)
		g_iHookIdGiveNamedItem[iClient] = DHookEntity(g_hDHookGiveNamedItem, false, iClient, DHook_GiveNamedItemRemoved, DHook_GiveNamedItemPre);
}

void DHook_UnhookGiveNamedItem(int iClient)
{
	if (g_iHookIdGiveNamedItem[iClient])
	{
		DHookRemoveHookID(g_iHookIdGiveNamedItem[iClient]);
		g_iHookIdGiveNamedItem[iClient] = 0;	
	}
}

bool DHook_IsGiveNamedItemActive()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (g_iHookIdGiveNamedItem[iClient])
			return true;
	
	return false;
}

void DHook_HookClient(int iClient)
{
	SDKHook(iClient, SDKHook_PreThink, Hook_PreThink);
	SDKHook(iClient, SDKHook_PreThinkPost, Hook_PreThinkPost);
}

void DHook_HookWeapon(int iWeapon)
{
	DHookEntity(g_hDHookSecondaryAttack, true, iWeapon, _, DHook_SecondaryWeaponPost);
	
	SDKHook(iWeapon, SDKHook_Reload, Hook_ReloadPre);
}

void DHook_HookObject(int iObject)
{
	DHookEntity(g_hDHookCanBeUpgraded, false, iObject, _, DHook_CanBeUpgradedPre);
	DHookEntity(g_hDHookCanBeUpgraded, true, iObject, _, DHook_CanBeUpgradedPost);
}

void DHook_HookGamerules()
{
	DHookGamerules(g_hDHookFrameUpdatePostEntityThink, false, _, DHook_FrameUpdatePostEntityThinkPre);
	DHookGamerules(g_hDHookFrameUpdatePostEntityThink, true, _, DHook_FrameUpdatePostEntityThinkPost);
}

public MRESReturn DHook_GetMaxAmmoPre(int iClient, Handle hReturn, Handle hParams)
{
	int iAmmoType = DHookGetParam(hParams, 1);
	TFClassType nClass;
	
	//By default iClassNumber returns -1, which would get client's class instead of given iClassNumber.
	// However using client's class can cause max ammo calculate to be incorrect,
	// we want to set iClassNumber to whatever class would normaly use weapon from iAmmoIndex.
	// Also update ammotype since we may have moved it somewhere else
	if (Ammo_GetDefaultType(iClient, iAmmoType, nClass))
	{
		DHookSetParam(hParams, 1, iAmmoType);
		DHookSetParam(hParams, 2, nClass);
		return MRES_ChangedHandled;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_TauntPre(int iClient, Handle hParams)
{
	//Player wants to taunt, set class to whoever can actually taunt with active weapon
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon <= MaxClients)
		return;
	
	TFClassType nClass = TF2_GetDefaultClassFromItem(iClient, iWeapon);
	if (nClass != TFClass_Unknown)
		TF2_SetPlayerClass(iClient, nClass);
}

public MRESReturn DHook_TauntPost(int iClient, Handle hParams)
{
	//Set class back to what it was
	TF2_SetPlayerClass(iClient, g_iClientClass[iClient]);
}

public MRESReturn DHook_CanAirDashPost(int iClient, Handle hReturn)
{
	if (iClient == -1)
		return MRES_Ignored;
	
	//Soda Popper and Atomizer's extra jumps does not work for non-scouts, fix that
	if (!DHookGetReturn(hReturn))
	{
		int iAirDash = GetEntProp(iClient, Prop_Send, "m_iAirDash");
		
		if (TF2_IsPlayerInCondition(iClient, TFCond_CritHype) && iAirDash <= 6)
		{
			SetEntProp(iClient, Prop_Send, "m_iAirDash", iAirDash + 1);
			DHookSetReturn(hReturn, true);
			return MRES_Supercede;
		}
		
		float flVal;
		int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
		if (TF2_WeaponFindAttribute(iWeapon, ATTRIB_AIR_DASH_COUNT, flVal) && iAirDash < RoundToNearest(flVal))
		{
			SetEntProp(iClient, Prop_Send, "m_iAirDash", iAirDash + 1);
			DHookSetReturn(hReturn, true);
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_ValidateWeaponsPre(int iClient, Handle hParams)
{
	//Dont validate any weapons, TF2 attempting to remove randomizer weapon for player's TF2 loadout,
	// however need to manually call WeaponReset virtual so randomizer weapons get restored back to what it was
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		int iWeapon = TF2_GetItemInSlot(iClient, iSlot);
		if (iWeapon > MaxClients)
			SDKCall_WeaponReset(iWeapon);
	}
	
	return MRES_Supercede;
}

public MRESReturn DHook_DoClassSpecialSkillPre(int iClient, Handle hReturn)
{
	//There 3 things going on in this function depending on player class attempting to:
	//If Demoman, detonate stickies or charge
	//If Engineer, pickup buildings
	//If Spy, cloak or uncloak
	
	g_bDoClassSpecialSkill[iClient] = true;
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon <= MaxClients)
		return MRES_Ignored;
	
	int iButtons = GetClientButtons(iClient);
	bool bAllowAttack2 = true;
	
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		if (Controls_IsPassiveInCooldown(iClient, iSlot))
			continue;
		
		int iButton = Controls_GetPassiveButtonBit(iClient, iSlot, bAllowAttack2);
		if (iButton > 0 && iButtons & iButton)
		{
			Controls_OnPassiveUse(iClient, iSlot);
			TF2_SetPlayerClass(iClient, TF2_GetDefaultClassFromItem(iClient, TF2_GetItemInSlot(iClient, iSlot)));
			return MRES_Ignored;
		}
	}
	
	//Cant find any valid passive weapon to use, prevent function called
	DHookSetReturn(hReturn, false);
	return MRES_Supercede;
}

public MRESReturn DHook_DoClassSpecialSkillPost(int iClient, Handle hReturn)
{
	TF2_SetPlayerClass(iClient, g_iClientClass[iClient]);
}

public MRESReturn DHook_GetChargeEffectBeingProvidedPre(int iClient, Handle hReturn)
{
	//Has medic class check for getting uber types
	g_iAllowPlayerClass[iClient]++;
}

public MRESReturn DHook_GetChargeEffectBeingProvidedPost(int iClient, Handle hReturn)
{
	g_iAllowPlayerClass[iClient]--;
}

public MRESReturn DHook_IsPlayerClassPre(int iClient, Handle hReturn, Handle hParams)
{
	if (g_iAllowPlayerClass[iClient] > 0)
	{
		DHookSetReturn(hReturn, true);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_GetEntityForLoadoutSlotPre(int iClient, Handle hReturn, Handle hParams)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return MRES_Ignored;
	
	int iSlot = DHookGetParam(hParams, 1);
	if (iSlot < 0 || iSlot > WeaponSlot_BuilderEngie)
		return MRES_Ignored;
	
	//This function sucks as it have default class check, lets do this ourself
	int iWeapon = TF2_GetItemInSlot(iClient, iSlot);
	if (iWeapon <= MaxClients)
	{
		DHookSetReturn(hReturn, 0);
		return MRES_Supercede;
	}
	
	DHookSetReturn(hReturn, iWeapon);
	return MRES_Supercede;
}

public MRESReturn DHook_CalculateMaxSpeedPre(int iClient, Handle hReturn, Handle hParams)
{
	if (g_iClientCalculateMaxSpeed)
		return;
	
	g_iClientCalculateMaxSpeed = iClient;
}

public MRESReturn DHook_CalculateMaxSpeedPost(int iClient, Handle hReturn, Handle hParams)
{
	if (g_iClientCalculateMaxSpeed != iClient)
		return;
	
	g_iClientCalculateMaxSpeed = 0;
}

public MRESReturn DHook_InCondPost(Address pPlayerShared, Handle hReturn, Handle hParams)
{
	if (!g_iClientCalculateMaxSpeed)
		return MRES_Ignored;
	
	if (DHookGetParam(hParams, 1) == TFCond_CritCola && DHookGetReturn(hReturn))
	{
		//We are in CritCola cond while wanting to return true to gain extra speed, however
		// this is only for steak and not crit-a-cola, only return true if weapon is steak
		int iSecondary = TF2_GetItemInSlot(g_iClientCalculateMaxSpeed, WeaponSlot_Secondary);
		if (iSecondary > MaxClients)
		{
			char sClassname[256];
			GetEntityClassname(iSecondary, sClassname, sizeof(sClassname));
			if (!StrEqual(sClassname, "tf_weapon_lunchbox"))
			{
				DHookSetReturn(hReturn, false);
				return MRES_Supercede;
			}
		}
	}
	
	return MRES_Ignored;
}

public void Hook_PreThink(int iClient)
{
	//PreThink have way too many IsPlayerClass check, always return true during it
	g_iAllowPlayerClass[iClient]++;
}

public void Hook_PreThinkPost(int iClient)
{
	g_iAllowPlayerClass[iClient]--;
}

public MRESReturn DHook_PlayerFiredWeaponPre(Address pGameStats, Handle hParams)
{
	//Not all weapons remove disguise
	int iClient = DHookGetParam(hParams, 1);
	
	if (TF2_IsPlayerInCondition(iClient, TFCond_Disguising))
		TF2_RemoveCondition(iClient, TFCond_Disguising);
	
	if (TF2_IsPlayerInCondition(iClient, TFCond_Disguised))
		TF2_RemoveCondition(iClient, TFCond_Disguised);
}

public MRESReturn DHook_SecondaryWeaponPost(int iWeapon)
{
	//Why is this function getting called from tf_viewmodel angery
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	if (StrContains(sClassname, "tf_weapon_") != 0)
		return;
	
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	
	//If DoClassSpecialSkill not called during secondary attack, do it anyway lol
	if (!g_bDoClassSpecialSkill[iClient])
	{
		g_bDoClassSpecialSkill[iClient] = true;
		SDKCall_DoClassSpecialSkill(iClient);
	}
	
	g_bDoClassSpecialSkill[iClient] = false;
}

public MRESReturn DHook_CanBeUpgradedPre(int iObject, Handle hReturn, Handle hParams)
{
	//This function have engineer class check
	int iClient = DHookGetParam(hParams, 1);
	TF2_SetPlayerClass(iClient, TFClass_Engineer);
}

public MRESReturn DHook_CanBeUpgradedPost(int iObject, Handle hReturn, Handle hParams)
{
	int iClient = DHookGetParam(hParams, 1);
	TF2_SetPlayerClass(iClient, g_iClientClass[iClient]);
}

public MRESReturn DHook_GiveNamedItemPre(int iClient, Handle hReturn, Handle hParams)
{
	if (DHookIsNullParam(hParams, 1) || DHookIsNullParam(hParams, 3))
	{
		DHookSetReturn(hReturn, 0);
		return MRES_Override;
	}
	
	char sClassname[256];
	DHookGetParamString(hParams, 1, sClassname, sizeof(sClassname));
	int iIndex = DHookGetParamObjectPtrVar(hParams, 3, g_iOffsetItemDefinitionIndex, ObjectValueType_Int) & 0xFFFF;
	
	Action action = GiveNamedItem(iClient, sClassname, iIndex);
	if (action >= Plugin_Handled)
	{
		DHookSetReturn(hReturn, 0);
		return MRES_Override;
	}
	
	return MRES_Ignored;
}

public void DHook_GiveNamedItemRemoved(int iHookId)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (g_iHookIdGiveNamedItem[iClient] == iHookId)
		{
			g_iHookIdGiveNamedItem[iClient] = 0;
			return;
		}
	}
}

public MRESReturn DHook_FrameUpdatePostEntityThinkPre()
{
	//This function call all clients to reduce medigun charge from medic class check
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		g_iAllowPlayerClass[iClient]++;
}

public MRESReturn DHook_FrameUpdatePostEntityThinkPost()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		g_iAllowPlayerClass[iClient]--;
}

public Action Hook_ReloadPre(int iWeapon)
{
	//Weapon unable to be reloaded from cloak, but coded in revolver only, and only for Spy class
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	if (TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
		return Plugin_Handled;
	
	return Plugin_Continue;
}