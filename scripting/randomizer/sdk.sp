static Handle g_hSDKGetBaseEntity;
static Handle g_hSDKGetDefaultItemChargeMeterValue;
static Handle g_hSDKEquipWearable;
static Handle g_hSDKWeaponReset;
static Handle g_hSDKAddObject;
static Handle g_hSDKRemoveObject;
static Handle g_hSDKDoClassSpecialSkill;
static Handle g_hSDKUpdateItemChargeMeters;
static Handle g_hSDKDrainCharge;

static Handle g_hDHookSecondaryAttack;
static Handle g_hDHookCanBeUpgraded;
static Handle g_hDHookItemPostFrame;
static Handle g_hDHookGiveNamedItem;

static Address g_pPlayerShared;
static Address g_pPlayerSharedOuter;
static int g_iOffsetItemDefinitionIndex = -1;

static int g_iHookIdGiveNamedItem[TF_MAXPLAYERS+1];
static bool g_bDoClassSpecialSkill[TF_MAXPLAYERS+1];

public void SDK_Init()
{
	GameData hGameData = new GameData("randomizer");
	if (!hGameData)
		SetFailState("Could not find randomizer gamedata");
	
	DHook_CreateDetour(hGameData, "CTFPlayer::GetMaxAmmo", DHook_GetMaxAmmoPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::Taunt", DHook_TauntPre, DHook_TauntPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::CanAirDash", _, DHook_CanAirDashPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::ValidateWeapons", DHook_ValidateWeaponsPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::OnDealtDamage", DHook_OnDealtDamagePre, DHook_OnDealtDamagePost);
	DHook_CreateDetour(hGameData, "CTFPlayer::DoClassSpecialSkill", DHook_DoClassSpecialSkillPre, DHook_DoClassSpecialSkillPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetChargeEffectBeingProvided", DHook_GetChargeEffectBeingProvidedPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayerShared::UpdateChargeMeter", DHook_UpdateChargeMeterPre, DHook_UpdateChargeMeterPost);
	DHook_CreateDetour(hGameData, "CTFPlayerShared::ConditionGameRulesThink", _, DHook_ConditionGameRulesThinkPost);
	DHook_CreateDetour(hGameData, "CTFGameStats::Event_PlayerFiredWeapon", DHook_PlayerFiredWeaponPre, _);
	
	g_hDHookSecondaryAttack = DHook_CreateVirtual(hGameData, "CBaseCombatWeapon::SecondaryAttack");
	g_hDHookCanBeUpgraded = DHook_CreateVirtual(hGameData, "CBaseObject::CanBeUpgraded");
	g_hDHookItemPostFrame = DHook_CreateVirtual(hGameData, "CBasePlayer::ItemPostFrame");
	g_hDHookGiveNamedItem = DHook_CreateVirtual(hGameData, "CTFPlayer::GiveNamedItem");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBaseEntity::GetBaseEntity");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKGetBaseEntity = EndPrepSDKCall();
	if (!g_hSDKGetBaseEntity)
		LogError("Failed to create call: CBaseEntity::GetBaseEntity");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBaseEntity::GetDefaultItemChargeMeterValue");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	g_hSDKGetDefaultItemChargeMeterValue = EndPrepSDKCall();
	if (!g_hSDKGetDefaultItemChargeMeterValue)
		LogError("Failed to create call: CBaseEntity::GetDefaultItemChargeMeterValue");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBasePlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKEquipWearable = EndPrepSDKCall();
	if (!g_hSDKEquipWearable)
		LogError("Failed to create call: CBasePlayer::EquipWearable");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTFWeaponBase::WeaponReset");
	g_hSDKWeaponReset = EndPrepSDKCall();
	if (!g_hSDKWeaponReset)
		LogError("Failed to create call: CTFWeaponBase::WeaponReset");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::AddObject");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKAddObject = EndPrepSDKCall();
	if (g_hSDKAddObject == null)
		LogMessage("Failed to create call: CTFPlayer::AddObject");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::RemoveObject");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKRemoveObject = EndPrepSDKCall();
	if (g_hSDKRemoveObject == null)
		LogMessage("Failed to create call: CTFPlayer::RemoveObject");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::DoClassSpecialSkill");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKDoClassSpecialSkill = EndPrepSDKCall();
	if (!g_hSDKDoClassSpecialSkill)
		LogError("Failed to create call: CTFPlayer::DoClassSpecialSkill");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayerShared::UpdateItemChargeMeters");
	g_hSDKUpdateItemChargeMeters = EndPrepSDKCall();
	if (!g_hSDKUpdateItemChargeMeters)
		LogError("Failed to create call: CTFPlayerShared::UpdateItemChargeMeters");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CWeaponMedigun::DrainCharge");
	g_hSDKDrainCharge = EndPrepSDKCall();
	if (!g_hSDKDrainCharge)
		LogError("Failed to create call: CWeaponMedigun::DrainCharge");
	
	g_pPlayerShared = view_as<Address>(FindSendPropInfo("CTFPlayer", "m_Shared"));
	g_pPlayerSharedOuter = view_as<Address>(hGameData.GetOffset("CTFPlayerShared::m_pOuter"));
	g_iOffsetItemDefinitionIndex = hGameData.GetOffset("CEconItemView::m_iItemDefinitionIndex");
	
	delete hGameData;
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

void SDK_HookGiveNamedItem(int iClient)
{
	if (g_hDHookGiveNamedItem && !g_bTF2Items)
		g_iHookIdGiveNamedItem[iClient] = DHookEntity(g_hDHookGiveNamedItem, false, iClient, DHook_GiveNamedItemRemoved, DHook_GiveNamedItemPre);
}

void SDK_UnhookGiveNamedItem(int iClient)
{
	if (g_iHookIdGiveNamedItem[iClient])
	{
		DHookRemoveHookID(g_iHookIdGiveNamedItem[iClient]);
		g_iHookIdGiveNamedItem[iClient] = 0;	
	}
}

bool SDK_IsGiveNamedItemActive()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (g_iHookIdGiveNamedItem[iClient])
			return true;
	
	return false;
}

void SDK_HookClient(int iClient)
{
	DHookEntity(g_hDHookItemPostFrame, false, iClient, _, DHook_ItemPostFramePre);
}

void SDK_HookWeapon(int iWeapon)
{
	DHookEntity(g_hDHookSecondaryAttack, true, iWeapon, _, DHook_SecondaryWeaponPost);
	
	SDKHook(iWeapon, SDKHook_Reload, Hook_ReloadPre);
}

void SDK_HookObject(int iObject)
{
	DHookEntity(g_hDHookCanBeUpgraded, false, iObject, _, DHook_CanBeUpgradedPre);
	DHookEntity(g_hDHookCanBeUpgraded, true, iObject, _, DHook_CanBeUpgradedPost);
}

float SDK_GetDefaultItemChargeMeterValue(int iWeapon)
{
	if (g_hSDKGetDefaultItemChargeMeterValue)
		return SDKCall(g_hSDKGetDefaultItemChargeMeterValue, iWeapon);
	
	return 0.0;
}

void SDK_EquipWearable(int iClient, int iWearable)
{
	if (g_hSDKEquipWearable)
		SDKCall(g_hSDKEquipWearable, iClient, iWearable);
}

void SDK_WeaponReset(int iWeapon)
{
	if (g_hSDKWeaponReset)
		SDKCall(g_hSDKWeaponReset, iWeapon);
}

void SDK_AddObject(int iClient, int iObject)
{
	if (g_hSDKAddObject)
		SDKCall(g_hSDKAddObject, iClient, iObject);
}

void SDK_RemoveObject(int iClient, int iObject)
{
	if (g_hSDKRemoveObject)
		SDKCall(g_hSDKRemoveObject, iClient, iObject);
}

bool SDK_DoClassSpecialSkill(int iClient)
{
	if (g_hSDKDoClassSpecialSkill)
		return SDKCall(g_hSDKDoClassSpecialSkill, iClient);
	
	return false;
}

void SDK_UpdateItemChargeMeters(int iClient)
{
	if (g_hSDKUpdateItemChargeMeters)
	{
		Address pThis = GetEntityAddress(iClient) + g_pPlayerShared;
		SDKCall(g_hSDKUpdateItemChargeMeters, pThis);
	}
}

void SDK_DrainCharge(int iMedigun)
{
	if (g_hSDKDrainCharge)
		SDKCall(g_hSDKDrainCharge, iMedigun);
}

public MRESReturn DHook_GetMaxAmmoPre(int iClient, Handle hReturn, Handle hParams)
{
	int iAmmoType = DHookGetParam(hParams, 1);
	TFClassType nClass = DHookGetParam(hParams, 2);
	
	if (nClass != view_as<TFClassType>(-1))
		return MRES_Ignored;
	
	if (iAmmoType == TF_AMMO_METAL)
	{
		//Metal works differently, engineer have max metal 200 while others have 100
		DHookSetParam(hParams, 2, TFClass_Engineer);
		return MRES_ChangedHandled;
	}
	
	//By default iClassNumber returns -1, which would get client's class instead of given iClassNumber.
	//However using client's class can cause max ammo calculate to be incorrect,
	//We want to set iClassNumber to whatever class would normaly use weapon from iAmmoIndex.
	//TODO check shortstop's max ammo
	int iWeapon = TF2_GetItemFromAmmoType(iClient, iAmmoType);
	if (iWeapon <= MaxClients)
		return MRES_Ignored;
	
	TFClassType nDefaultClass = TF2_GetDefaultClassFromItem(iClient, iWeapon);
	DHookSetParam(hParams, 2, nDefaultClass);
	return MRES_ChangedHandled;
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
	//Atomizer's extra jumps does not work for non-scouts, fix that
	if (!DHookGetReturn(hReturn))
	{
		int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
		
		float flVal;
		if (!TF2_WeaponFindAttribute(iWeapon, ATTRIB_AIR_DASH_COUNT, flVal))
			return MRES_Ignored;
		
		int iAirDash = GetEntProp(iClient, Prop_Send, "m_iAirDash");
		if (iAirDash < RoundToNearest(flVal))
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
			SDK_WeaponReset(iWeapon);
	}
	
	return MRES_Supercede;
}

public MRESReturn DHook_OnDealtDamagePre(int iClient, Handle hParams)
{
	//Gas Passer meter have hardcode pyro check in this call
	TF2_SetPlayerClass(iClient, TFClass_Pyro);
}

public MRESReturn DHook_OnDealtDamagePost(int iClient, Handle hParams)
{
	TF2_SetPlayerClass(iClient, g_iClientClass[iClient]);
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
		int iButton = Controls_GetPassiveButtonBit(iClient, iSlot, bAllowAttack2);
		if (iButton > 0 && iButtons & iButton)
		{
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
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon <= MaxClients)
	{
		DHookSetReturn(hReturn, TF_CHARGE_NONE);
		return MRES_Supercede;
	}
	
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	if (!StrEqual(sClassname, "tf_weapon_medigun") || !GetEntProp(iWeapon, Prop_Send, "m_bChargeRelease") || GetEntProp(iWeapon, Prop_Send, "m_bHolstered"))
	{
		DHookSetReturn(hReturn, TF_CHARGE_NONE);
		return MRES_Supercede;
	}
	
	float flVal;
	if (TF2_WeaponFindAttribute(iWeapon, ATTRIB_SET_CHARGE_TYPE, flVal))
	{
		DHookSetReturn(hReturn, RoundToNearest(flVal));
		return MRES_Supercede;
	}
	
	DHookSetReturn(hReturn, TF_CHARGE_INVULNERABLE);
	return MRES_Supercede;
}

public MRESReturn DHook_UpdateChargeMeterPre(Address pPlayerShared)
{
	//This function is only used to manage demoshield meter, but have hardcode demoman class
	int iClient = GetClientFromPlayerShared(pPlayerShared);
	if (!IsPlayerAlive(iClient))
		return;
	
	TF2_SetPlayerClass(iClient, TFClass_DemoMan);
}

public MRESReturn DHook_UpdateChargeMeterPost(Address pPlayerShared)
{
	int iClient = GetClientFromPlayerShared(pPlayerShared);
	if (!IsPlayerAlive(iClient))
		return;
	
	TF2_SetPlayerClass(iClient, g_iClientClass[iClient]);
}

public MRESReturn DHook_ConditionGameRulesThinkPost(Address pPlayerShared)
{
	//There a medic call check for draining uber.
	//Pre and post hooks is a bit broken, so changing class to medic won't do the trick
	
	int iClient = GetClientFromPlayerShared(pPlayerShared);
	if (TF2_GetPlayerClass(iClient) == TFClass_Medic)
		return;
	
	int iSecondary = TF2_GetItemInSlot(iClient, WeaponSlot_Secondary);
	if (iSecondary <= MaxClients)
		return;
	
	char sClassname[256];
	GetEntityClassname(iSecondary, sClassname, sizeof(sClassname));
	if (!StrEqual(sClassname, "tf_weapon_medigun"))
		return;
	
	SDK_DrainCharge(iSecondary);
}

public MRESReturn DHook_ItemPostFramePre(int iClient)
{
	if (!IsPlayerAlive(iClient))
		return;
	
	//This is the only function that calls CTFPlayerShared::UpdateItemChargeMeters,
	// but only works if playing as default class, Loop through each weapons that
	// uses this function, and call with said class
	
	bool bClassPlayed[CLASS_MAX+1];
	bClassPlayed[g_iClientClass[iClient]] = true;
	
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		int iWeapon = TF2_GetItemInSlot(iClient, iSlot);
		
		float flVal;
		if (iWeapon > MaxClients && TF2_WeaponFindAttribute(iWeapon, ATTRIB_ITEM_METER_CHARGE_TYPE, flVal))
		{
			TFClassType nDefaultClass = TF2_GetDefaultClassFromItem(iClient, iWeapon);
			
			if (!bClassPlayed[nDefaultClass])
			{
				bClassPlayed[nDefaultClass] = true;
				
				TF2_SetPlayerClass(iClient, nDefaultClass);
				SDK_UpdateItemChargeMeters(iClient);
				TF2_SetPlayerClass(iClient, g_iClientClass[iClient]);
			}
		}
	}
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
		SDK_DoClassSpecialSkill(iClient);
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

public Action Hook_ReloadPre(int iWeapon)
{
	//Weapon unable to be reloaded from cloak, but coded in revolver only, and only for Spy class
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	if (TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

static int GetClientFromPlayerShared(Address pPlayerShared)
{
	Address pEntity = view_as<Address>(LoadFromAddress(pPlayerShared + g_pPlayerSharedOuter, NumberType_Int32));
	return SDKCall(g_hSDKGetBaseEntity, pEntity);
}