enum struct Detour
{
	char sName[64];
	Handle hDetour;
	DHookCallback callbackPre;
	DHookCallback callbackPost;
}

static ArrayList g_aDHookDetours;

static Handle g_hDHookGiveAmmo;
static Handle g_hDHookSecondaryAttack;
static Handle g_hDHookSwing;
static Handle g_hDHookMyTouch;
static Handle g_hDHookPipebombTouch;
static Handle g_hDHookOnDecapitation;
static Handle g_hDHookCanBeUpgraded;
static Handle g_hDHookForceRespawn;
static Handle g_hDHookEquipWearable;
static Handle g_hDHookGiveNamedItem;
static Handle g_hDHookClientCommand;
static Handle g_hDHookFrameUpdatePostEntityThink;

static bool g_bSkipHandleRageGain;
static TFClassType g_nClassGainingRage;
static bool g_bSkipUpdateRageBuffsAndRage = false;
static int g_iClientGetChargeEffectBeingProvided;
static int g_iWeaponGetLoadoutItem = -1;

static int g_iHookIdGiveNamedItem[TF_MAXPLAYERS+1];
static int g_iHookIdClientCommand[TF_MAXPLAYERS+1];
static int g_iHookIdGiveAmmo[TF_MAXPLAYERS+1];
static int g_iHookIdForceRespawnPre[TF_MAXPLAYERS+1];
static int g_iHookIdForceRespawnPost[TF_MAXPLAYERS+1];
static int g_iHookIdEquipWearable[TF_MAXPLAYERS+1];
static bool g_bDoClassSpecialSkill[TF_MAXPLAYERS+1];
static bool g_bApplyBiteEffectsChocolate[TF_MAXPLAYERS+1];

static int g_iDHookGamerulesPre;
static int g_iDHookGamerulesPost;

public void DHook_Init(GameData hGameData)
{
	g_aDHookDetours = new ArrayList(sizeof(Detour));
	
	DHook_CreateDetour(hGameData, "CTFPlayer::GetMaxAmmo", DHook_GetMaxAmmoPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::Taunt", DHook_TauntPre, DHook_TauntPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::CanAirDash", DHook_CanAirDashPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::ValidateWeapons", DHook_ValidateWeaponsPre, DHook_ValidateWeaponsPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::ManageBuilderWeapons", DHook_ManageBuilderWeaponsPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::DoClassSpecialSkill", DHook_DoClassSpecialSkillPre, DHook_DoClassSpecialSkillPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::EndClassSpecialSkill", DHook_EndClassSpecialSkillPre, DHook_EndClassSpecialSkillPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetChargeEffectBeingProvided", DHook_GetChargeEffectBeingProvidedPre, DHook_GetChargeEffectBeingProvidedPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::IsPlayerClass", DHook_IsPlayerClassPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetLoadoutItem", DHook_GetLoadoutItemPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetEntityForLoadoutSlot", DHook_GetEntityForLoadoutSlotPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::TakeHealth", DHook_TakeHealthPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayerClassShared::CanBuildObject", DHook_CanBuildObjectPre, _);
	DHook_CreateDetour(hGameData, "CTFKnife::DisguiseOnKill", DHook_DisguiseOnKillPre, DHook_DisguiseOnKillPost);
	DHook_CreateDetour(hGameData, "CTFLunchBox::ApplyBiteEffects", DHook_ApplyBiteEffectsPre, DHook_ApplyBiteEffectsPost);
	DHook_CreateDetour(hGameData, "CTFGameStats::Event_PlayerFiredWeapon", DHook_PlayerFiredWeaponPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayerShared::UpdateRageBuffsAndRage", DHook_UpdateRageBuffsAndRagePre, _);
	DHook_CreateDetour(hGameData, "CTFPlayerShared::ModifyRage", DHook_ModifyRagePre, DHook_ModifyRagePost);
	DHook_CreateDetour(hGameData, "CTFPlayerShared::ActivateRageBuff", DHook_ActivateRageBuffPre, DHook_ActivateRageBuffPost);
	DHook_CreateDetour(hGameData, "HandleRageGain", DHook_HandleRageGainPre, _);
	
	g_hDHookGiveAmmo = DHook_CreateVirtual(hGameData, "CBaseCombatCharacter::GiveAmmo");
	g_hDHookSecondaryAttack = DHook_CreateVirtual(hGameData, "CBaseCombatWeapon::SecondaryAttack");
	g_hDHookSwing = DHook_CreateVirtual(hGameData, "CTFWeaponBaseMelee::Swing");
	g_hDHookMyTouch = DHook_CreateVirtual(hGameData, "CItem::MyTouch");
	g_hDHookPipebombTouch = DHook_CreateVirtual(hGameData, "CTFGrenadePipebombProjectile::PipebombTouch");
	g_hDHookOnDecapitation = DHook_CreateVirtual(hGameData, "CTFDecapitationMeleeWeaponBase::OnDecapitation");
	g_hDHookCanBeUpgraded = DHook_CreateVirtual(hGameData, "CBaseObject::CanBeUpgraded");
	g_hDHookForceRespawn = DHook_CreateVirtual(hGameData, "CBasePlayer::ForceRespawn");
	g_hDHookEquipWearable = DHook_CreateVirtual(hGameData, "CBasePlayer::EquipWearable");
	g_hDHookGiveNamedItem = DHook_CreateVirtual(hGameData, "CTFPlayer::GiveNamedItem");
	g_hDHookClientCommand = DHook_CreateVirtual(hGameData, "CTFPlayer::ClientCommand");
	g_hDHookFrameUpdatePostEntityThink = DHook_CreateVirtual(hGameData, "CGameRules::FrameUpdatePostEntityThink");
}

static void DHook_CreateDetour(GameData hGameData, const char[] sName, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	Detour detour;
	detour.hDetour = DHookCreateFromConf(hGameData, sName);
	if (!detour.hDetour)
	{
		LogError("Failed to create detour: %s", sName);
	}
	else
	{
		strcopy(detour.sName, sizeof(detour.sName), sName);
		detour.callbackPre = callbackPre;
		detour.callbackPost = callbackPost;
		g_aDHookDetours.PushArray(detour);
	}
}

static Handle DHook_CreateVirtual(GameData hGameData, const char[] sName)
{
	Handle hHook = DHookCreateFromConf(hGameData, sName);
	if (!hHook)
		LogError("Failed to create hook: %s", sName);
	
	return hHook;
}

void DHook_EnableDetour()
{
	int iLength = g_aDHookDetours.Length;
	for (int i = 0; i < iLength; i++)
	{
		Detour detour;
		g_aDHookDetours.GetArray(i, detour);
		
		if (detour.callbackPre != INVALID_FUNCTION)
			if (!DHookEnableDetour(detour.hDetour, false, detour.callbackPre))
				LogError("Failed to enable pre detour: %s", detour.sName);
		
		if (detour.callbackPost != INVALID_FUNCTION)
			if (!DHookEnableDetour(detour.hDetour, true, detour.callbackPost))
				LogError("Failed to enable post detour: %s", detour.sName);
	}
}

void DHook_DisableDetour()
{
	int iLength = g_aDHookDetours.Length;
	for (int i = 0; i < iLength; i++)
	{
		Detour detour;
		g_aDHookDetours.GetArray(i, detour);
		
		if (detour.callbackPre != INVALID_FUNCTION)
			if (!DHookDisableDetour(detour.hDetour, false, detour.callbackPre))
				LogError("Failed to disable pre detour: %s", detour.sName);
		
		if (detour.callbackPost != INVALID_FUNCTION)
			if (!DHookDisableDetour(detour.hDetour, true, detour.callbackPost))
				LogError("Failed to disable post detour: %s", detour.sName);
	}
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
	g_iHookIdGiveAmmo[iClient] = DHookEntity(g_hDHookGiveAmmo, false, iClient, _, DHook_GiveAmmoPre);
	g_iHookIdForceRespawnPre[iClient] = DHookEntity(g_hDHookForceRespawn, false, iClient, _, DHook_ForceRespawnPre);
	g_iHookIdForceRespawnPost[iClient] = DHookEntity(g_hDHookForceRespawn, true, iClient, _, DHook_ForceRespawnPost);
	g_iHookIdEquipWearable[iClient] = DHookEntity(g_hDHookEquipWearable, true, iClient, _, DHook_EquipWearablePost);
	g_iHookIdClientCommand[iClient] = DHookEntity(g_hDHookClientCommand, true, iClient, _, DHook_ClientCommandPost);
}

void DHook_UnhookClient(int iClient)
{
	if (g_iHookIdGiveAmmo[iClient])
	{
		DHookRemoveHookID(g_iHookIdGiveAmmo[iClient]);
		g_iHookIdGiveAmmo[iClient] = 0;	
	}
	
	if (g_iHookIdForceRespawnPre[iClient])
	{
		DHookRemoveHookID(g_iHookIdForceRespawnPre[iClient]);
		g_iHookIdForceRespawnPre[iClient] = 0;	
	}
	
	if (g_iHookIdForceRespawnPost[iClient])
	{
		DHookRemoveHookID(g_iHookIdForceRespawnPost[iClient]);
		g_iHookIdForceRespawnPost[iClient] = 0;	
	}
	
	if (g_iHookIdEquipWearable[iClient])
	{
		DHookRemoveHookID(g_iHookIdEquipWearable[iClient]);
		g_iHookIdEquipWearable[iClient] = 0;	
	}
	if (g_iHookIdClientCommand[iClient])
	{
		DHookRemoveHookID(g_iHookIdClientCommand[iClient]);
		g_iHookIdClientCommand[iClient] = 0;
 }
}

void DHook_OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (StrContains(sClassname, "tf_weapon_") == 0)
	{
		SDKHook(iEntity, SDKHook_SpawnPost, DHook_SpawnPost);
		DHookEntity(g_hDHookSecondaryAttack, true, iEntity, _, DHook_SecondaryWeaponPost);
	}
	
	if (StrContains(sClassname, "item_healthkit") == 0)
	{
		DHookEntity(g_hDHookMyTouch, false, iEntity, _, DHook_MyTouchPre);
		DHookEntity(g_hDHookMyTouch, true, iEntity, _, DHook_MyTouchPost);
	}
	else if (StrEqual(sClassname, "tf_projectile_stun_ball") || StrEqual(sClassname, "tf_projectile_ball_ornament"))
	{
		DHookEntity(g_hDHookPipebombTouch, false, iEntity, _, DHook_PipebombTouchPre);
		DHookEntity(g_hDHookPipebombTouch, true, iEntity, _, DHook_PipebombTouchPost);
	}
	else if (StrEqual(sClassname, "tf_weapon_sword"))
	{
		DHookEntity(g_hDHookOnDecapitation, false, iEntity, _, DHook_OnDecapitationPre);
		DHookEntity(g_hDHookOnDecapitation, true, iEntity, _, DHook_OnDecapitationPost);
	}
	else if (StrContains(sClassname, "obj_") == 0)
	{
		DHookEntity(g_hDHookCanBeUpgraded, false, iEntity, _, DHook_CanBeUpgradedPre);
		DHookEntity(g_hDHookCanBeUpgraded, true, iEntity, _, DHook_CanBeUpgradedPost);
	}
}

void DHook_HookGamerules()
{
	g_iDHookGamerulesPre = DHookGamerules(g_hDHookFrameUpdatePostEntityThink, false, _, DHook_FrameUpdatePostEntityThinkPre);
	g_iDHookGamerulesPost = DHookGamerules(g_hDHookFrameUpdatePostEntityThink, true, _, DHook_FrameUpdatePostEntityThinkPost);
}

void DHook_UnhookGamerules()
{
	DHookRemoveHookID(g_iDHookGamerulesPre);
	DHookRemoveHookID(g_iDHookGamerulesPost);
}

public void DHook_SpawnPost(int iWeapon)
{
	if (TF2_GetSlot(iWeapon) == WeaponSlot_Melee)
		DHookEntity(g_hDHookSwing, false, iWeapon, _, DHook_SwingPre);
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
	//Dont allow taunting if disguised or cloaked
	if (TF2_IsPlayerInCondition(iClient, TFCond_Disguising) || TF2_IsPlayerInCondition(iClient, TFCond_Disguised) || TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
		return MRES_Supercede;
	
	//Player wants to taunt, set class to whoever can actually taunt with active weapon
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon <= MaxClients)
		return MRES_Ignored;
	
	TFClassType nClass = TF2_GetDefaultClassFromItem(iWeapon);
	if (nClass != TFClass_Unknown)
		SetClientClass(iClient, nClass);
	
	return MRES_Ignored;
}

public MRESReturn DHook_TauntPost(int iClient, Handle hParams)
{
	//Set class back to what it was
	RevertClientClass(iClient);
}

public MRESReturn DHook_CanAirDashPre(int iClient, Handle hReturn)
{
	if (TF2_GetPlayerClass(iClient) == TFClass_Scout)
		return MRES_Ignored;
	
	//Soda Popper and Atomizer's extra jumps does not work for non-scouts, fix that
	int iAirDash = GetEntProp(iClient, Prop_Send, "m_iAirDash");
	
	if (TF2_IsPlayerInCondition(iClient, TFCond_CritHype) && iAirDash <= 6)
	{
		SetEntProp(iClient, Prop_Send, "m_iAirDash", iAirDash + 1);
		DHookSetReturn(hReturn, true);
		return MRES_Supercede;
	}
	
	float flVal;
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon > MaxClients && TF2_WeaponFindAttribute(iWeapon, "air dash count", flVal) && iAirDash < RoundToNearest(flVal))
	{
		SetEntProp(iClient, Prop_Send, "m_iAirDash", iAirDash + 1);
		DHookSetReturn(hReturn, true);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_ValidateWeaponsPre(int iClient, Handle hParams)
{
	g_iWeaponGetLoadoutItem = 0;
}

public MRESReturn DHook_ValidateWeaponsPost(int iClient, Handle hParams)
{
	g_iWeaponGetLoadoutItem = -1;
	RevertClientClass(iClient);	//Reset from GetLoadoutItem hook
}

public MRESReturn DHook_ManageBuilderWeaponsPre(int iClient, Handle hParams)
{
	//Don't do anything, we'll handle it
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
	
	int iWeapon, iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		if (Controls_IsPassiveInCooldown(iClient, iWeapon))
			continue;
		
		if (!Controls_CanUseWhileInvis(iWeapon) && TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
			continue;
		
		int iButton = Controls_GetPassiveButtonBit(iClient, iWeapon);
		if (iButton > 0 && iButtons & iButton)
		{
			Controls_OnPassiveUse(iClient, iWeapon);
			SetClientClass(iClient, TF2_GetDefaultClassFromItem(iWeapon));
			return MRES_Ignored;
		}
	}
	
	//Cant find any valid passive weapon to use, prevent function called
	DHookSetReturn(hReturn, false);
	return MRES_Supercede;
}

public MRESReturn DHook_DoClassSpecialSkillPost(int iClient, Handle hReturn)
{
	RevertClientClass(iClient);
}

public MRESReturn DHook_EndClassSpecialSkillPre(int iClient, Handle hReturn)
{
	//Only have demoman check to end charge
	SetClientClass(iClient, TFClass_DemoMan);
}

public MRESReturn DHook_EndClassSpecialSkillPost(int iClient, Handle hReturn)
{
	RevertClientClass(iClient);
}

public MRESReturn DHook_GetChargeEffectBeingProvidedPre(int iClient, Handle hReturn)
{
	if (IsClientInGame(iClient))
	{
		//Has medic class check for getting uber types
		SetClientClass(iClient, TFClass_Medic);
		g_iClientGetChargeEffectBeingProvided = iClient;
	}
}

public MRESReturn DHook_GetChargeEffectBeingProvidedPost(int iClient, Handle hReturn)
{
	// iClient is a lie in this detour
	if (g_iClientGetChargeEffectBeingProvided)
		RevertClientClass(g_iClientGetChargeEffectBeingProvided);
	
	g_iClientGetChargeEffectBeingProvided = 0;
}

public MRESReturn DHook_IsPlayerClassPre(int iClient, Handle hReturn, Handle hParams)
{
	if (g_iAllowPlayerClass[iClient] > 0)
	{
		DHookSetReturn(hReturn, true);
		return MRES_Supercede;
	}
	
	if (g_iClientEurekaTeleporting == iClient) 
	{
		DHookSetReturn(hReturn, true);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_GetLoadoutItemPre(int iClient, Handle hReturn, Handle hParams)
{
	if (g_iWeaponGetLoadoutItem == -1 || !IsWeaponRandomized(iClient))	//not inside ValidateWeapons
		return MRES_Ignored;
	
	int iWeapon = -1;
	
	//We want to return item the same as whatever client is equipped, so ValidateWeapons dont need to delete any weapons
	do
	{
		iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", g_iWeaponGetLoadoutItem);
		g_iWeaponGetLoadoutItem++;
	}
	while (iWeapon == -1);
	
	//There also class type and weapon classname checks if they should have correct classname by class type
	int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	
	char sWeaponClassname[256], sIndexClassname[256];
	GetEntityClassname(iWeapon, sWeaponClassname, sizeof(sWeaponClassname));
	TF2Econ_GetItemClassName(iIndex, sIndexClassname, sizeof(sIndexClassname));
	
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		if (TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass)) >= WeaponSlot_Primary)
		{
			char sTemp[256];
			strcopy(sTemp, sizeof(sTemp), sIndexClassname);
			TF2Econ_TranslateWeaponEntForClass(sTemp, sizeof(sTemp), view_as<TFClassType>(iClass));
			if (StrEqual(sWeaponClassname, sTemp))
			{
				SetClientClass(iClient, view_as<TFClassType>(iClass));
				break;
			}
		}
	}
	
	DHookSetReturn(hReturn, GetEntityAddress(iWeapon) + view_as<Address>(GetEntSendPropOffs(iWeapon, "m_Item", true)));
	return MRES_Supercede;
}

public MRESReturn DHook_GetEntityForLoadoutSlotPre(int iClient, Handle hReturn, Handle hParams)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return MRES_Ignored;
	
	int iSlot = DHookGetParam(hParams, 1);
	if (iSlot < 0 || iSlot > WeaponSlot_BuilderEngie)
		return MRES_Ignored;
	
	//This function sucks as it have default class check, lets use GetPlayerWeaponSlot instead
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	if (iWeapon > MaxClients)
	{
		DHookSetReturn(hReturn, iWeapon);
		return MRES_Supercede;
	}
	
	DHookSetReturn(hReturn, 0);
	return MRES_Supercede;
}

public MRESReturn DHook_CanBuildObjectPre(Address pPlayerClassShared, Handle hReturn, Handle hParams)
{
	//Always return true no matter what
	DHookSetReturn(hReturn, true);
	return MRES_Supercede;
}

public MRESReturn DHook_DisguiseOnKillPre(int iWeapon)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	SetClientClass(iClient, TFClass_Spy);
}

public MRESReturn DHook_DisguiseOnKillPost(int iWeapon)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	RevertClientClass(iClient);
}

public MRESReturn DHook_ApplyBiteEffectsPre(int iWeapon, Handle hParams)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");	
	
	float flGivesHealth;
	TF2_WeaponFindAttribute(iWeapon, "lunchbox adds maxhealth bonus", flGivesHealth);
	if (flGivesHealth > 0)
		g_bApplyBiteEffectsChocolate[iClient] = true;
}

public MRESReturn DHook_ApplyBiteEffectsPost(int iWeapon, Handle hParams)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");	
	g_bApplyBiteEffectsChocolate[iClient] = false;
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

public MRESReturn DHook_UpdateRageBuffsAndRagePre(Address pPlayerShared)
{
	int iClient = SDKCall_GetBaseEntity(pPlayerShared - view_as<Address>(g_iOffsetPlayerShared));
	if (g_bSkipUpdateRageBuffsAndRage || iClient <= 0 || iClient > MaxClients)
		return MRES_Ignored;
	
	float flRageType = Rage_GetBuffTypeAttribute(iClient);
	if (!flRageType) //We don't have any rage items, don't need to do anything
		return MRES_Ignored;
	
	RequestFrame(Frame_UpdateRageBuffsAndRage, iClient);
	return MRES_Supercede;
}

public void Frame_UpdateRageBuffsAndRage(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return;
	
	bool bCalledClass[CLASS_MAX + 1];
	g_bSkipUpdateRageBuffsAndRage = true;
	float flRageType = Rage_GetBuffTypeAttribute(iClient);
	
	int iWeapon;
	int iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		if (iWeapon <= MaxClients)
			continue;
		
		float flVal;
		TF2_WeaponFindAttribute(iWeapon, "mod soldier buff type", flVal);
		if (!flVal)
			continue;
  
		TFClassType nClass = TF2_GetDefaultClassFromItem(iWeapon);
		if (bCalledClass[nClass])
			continue;
  
		bCalledClass[nClass] = true;
		//Apply the attribute to the player to make up for the difference. The total should now be the weapon's value
		TF2Attrib_SetByName(iClient, "mod soldier buff type", flVal - flRageType);
		Rage_LoadRageProps(iClient, nClass);
		SetClientClass(iClient, nClass);
		g_nClassGainingRage = nClass;
		
		SDKCall_UpdateRageBuffsAndRage(GetEntityAddress(iClient) + view_as<Address>(g_iOffsetPlayerShared));
  
		Rage_SaveRageProps(iClient, nClass);
	}
	
	g_nClassGainingRage = TFClass_Unknown;
	RevertClientClass(iClient);
	TF2Attrib_SetByName(iClient, "mod soldier buff type", 0.0);
	g_bSkipUpdateRageBuffsAndRage = false;
}

public MRESReturn DHook_ModifyRagePre(Address pPlayerShared, Handle hParams)
{
	int iClient = SDKCall_GetBaseEntity(pPlayerShared - view_as<Address>(g_iOffsetPlayerShared));
	if (iClient && g_nClassGainingRage != TFClass_Unknown)
		Rage_LoadRageProps(iClient, g_nClassGainingRage);
}

public MRESReturn DHook_ModifyRagePost(Address pPlayerShared, Handle hParams)
{
	int iClient = SDKCall_GetBaseEntity(pPlayerShared - view_as<Address>(g_iOffsetPlayerShared));
	if (iClient && g_nClassGainingRage != TFClass_Unknown)
		Rage_SaveRageProps(iClient, g_nClassGainingRage);
}

public MRESReturn DHook_ActivateRageBuffPre(Address pPlayerShared, Handle hParams)
{
	int iClient = SDKCall_GetBaseEntity(pPlayerShared - view_as<Address>(g_iOffsetPlayerShared));
	if (!iClient)
		return MRES_Ignored;
	
	//int iWeapon = DHookGetParam(hParams, 1); //First param is supposed to be the weapon, but I couldn't get it working
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon <= MaxClients)
		return MRES_Ignored;
	
	int iBuffType = DHookGetParam(hParams, 2);
	TFClassType nClass = TF2_GetDefaultClassFromItem(iWeapon);
	
	float flClientRageType = Rage_GetBuffTypeAttribute(iClient);
	TF2Attrib_SetByName(iClient, "mod soldier buff type", view_as<float>(iBuffType) - flClientRageType);
	
	Rage_LoadRageProps(iClient, nClass);
	return MRES_Ignored;
}

public MRESReturn DHook_ActivateRageBuffPost(Address pPlayerShared, Handle hParams)
{
	int iClient = SDKCall_GetBaseEntity(pPlayerShared - view_as<Address>(g_iOffsetPlayerShared));
	if (!iClient)
		return MRES_Ignored;
	
	//int iWeapon = DHookGetParam(hParams, 1);
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(iWeapon <= MaxClients)
		return MRES_Ignored;
	
	TFClassType nClass = TF2_GetDefaultClassFromItem(iWeapon);
	TF2Attrib_SetByName(iClient, "mod soldier buff type", 0.0);
	Rage_SaveRageProps(iClient, nClass);
	return MRES_Ignored;
}

public MRESReturn DHook_HandleRageGainPre(Handle hParams)
{
	//Banners, Phlogistinator and Hitman Heatmaker use m_flRageMeter with class check, call this function to each weapons
	//Must be called a frame, will crash if detour is called while inside a detour
	if (g_bSkipHandleRageGain ||  DHookIsNullParam(hParams, 1))
		return MRES_Ignored;
	
	DataPack hPack = new DataPack();
	hPack.WriteCell(GetClientSerial(DHookGetParam(hParams, 1)));
	hPack.WriteCell(DHookGetParam(hParams, 2));
	hPack.WriteFloat(DHookGetParam(hParams, 3));
	hPack.WriteFloat(DHookGetParam(hParams, 4));
	
	RequestFrame(Frame_HandleRageGain, hPack);
	return MRES_Supercede;
}

public void Frame_HandleRageGain(DataPack hPack)
{
	hPack.Reset();
	int iClient = GetClientFromSerial(hPack.ReadCell());
	int iRequiredBuffFlags = hPack.ReadCell();
	float flDamage = hPack.ReadFloat();
	float fInverseRageGainScale = hPack.ReadFloat();
	delete hPack;
	
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return;
	
	bool bCalledClass[CLASS_MAX + 1];
	g_bSkipHandleRageGain = true;
	
	int iWeapon;
	int iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		TFClassType nClass = TF2_GetDefaultClassFromItem(iWeapon);
		if (bCalledClass[nClass])	//Already called as same class, dont double value
			continue;
		
		bCalledClass[nClass] = true;
		
		SetClientClass(iClient, nClass);
		g_nClassGainingRage = nClass;
		SDKCall_HandleRageGain(iClient, iRequiredBuffFlags, flDamage, fInverseRageGainScale);
	}
	
	RevertClientClass(iClient);
	g_bSkipHandleRageGain = false;
	g_nClassGainingRage = TFClass_Unknown;
}

public MRESReturn DHook_GiveAmmoPre(int iClient, Handle hReturn, Handle hParams)
{
	int iSlot = Ammo_GetGiveAmmoSlot();
	Ammo_SetGiveAmmoSlot(-1);	//Entity may be destroyed, unable to set back to -1 in post hook
	if (iSlot >= WeaponSlot_Primary)
	{
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
		if (iWeapon > MaxClients)
		{
			DHookSetParam(hParams, 2, GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType"));
			return MRES_ChangedHandled;
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_SwingPre(int iWeapon, Handle hReturn)
{
	//Not all melee weapons call to end demo charge
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	if (0 < iClient <= MaxClients)
		SDKCall_EndClassSpecialSkill(iClient);
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

public MRESReturn DHook_MyTouchPre(int iHealthKit, Handle hReturn, Handle hParams)
{
	//Has heavy class check for lunchbox, and ensure GiveAmmo is done to secondary slot
	int iClient = GetEntPropEnt(iHealthKit, Prop_Send, "m_hOwnerEntity");
	if (0 < iClient <= MaxClients && IsClientInGame(iClient))
	{
		g_iAllowPlayerClass[iClient]++;
		Ammo_SetGiveAmmoSlot(WeaponSlot_Secondary);
	}
}

public MRESReturn DHook_MyTouchPost(int iHealthKit, Handle hReturn, Handle hParams)
{
	int iClient = GetEntPropEnt(iHealthKit, Prop_Send, "m_hOwnerEntity");
	if (0 < iClient <= MaxClients && IsClientInGame(iClient))
	{
		g_iAllowPlayerClass[iClient]--;
		Ammo_SetGiveAmmoSlot(-1);
	}
}

public MRESReturn DHook_PipebombTouchPre(int iStunBall, Handle hParams)
{
	//Has scout class check, and make sure GiveAmmo is given to melee weapon
	int iClient = GetEntPropEnt(iStunBall, Prop_Send, "m_hOwnerEntity");
	if (0 < iClient <= MaxClients && IsClientInGame(iClient))
	{
		g_iAllowPlayerClass[iClient]++;
		Ammo_SetGiveAmmoSlot(WeaponSlot_Melee);
	}
}

public MRESReturn DHook_PipebombTouchPost(int iStunBall, Handle hParams)
{
	int iClient = GetEntPropEnt(iStunBall, Prop_Send, "m_hOwnerEntity");
	if (0 < iClient <= MaxClients && IsClientInGame(iClient))
	{
		g_iAllowPlayerClass[iClient]--;
		Ammo_SetGiveAmmoSlot(-1);
	}
}

public MRESReturn DHook_OnDecapitationPre(int iSword, Handle hParams)
{
	//Has class check
	int iClient = GetEntPropEnt(iSword, Prop_Send, "m_hOwnerEntity");
	SetClientClass(iClient, TF2_GetDefaultClassFromItem(iSword));
}

public MRESReturn DHook_OnDecapitationPost(int iSword, Handle hParams)
{
	int iClient = GetEntPropEnt(iSword, Prop_Send, "m_hOwnerEntity");
	RevertClientClass(iClient);
}

public MRESReturn DHook_CanBeUpgradedPre(int iObject, Handle hReturn, Handle hParams)
{
	//This function have engineer class check
	int iClient = DHookGetParam(hParams, 1);
	SetClientClass(iClient, TFClass_Engineer);
}

public MRESReturn DHook_CanBeUpgradedPost(int iObject, Handle hReturn, Handle hParams)
{
	int iClient = DHookGetParam(hParams, 1);
	RevertClientClass(iClient);
}

public MRESReturn DHook_ForceRespawnPre(int iClient)
{
	//Detach client's object so it doesnt get destroyed on class change
	int iBuilding = MaxClients+1;
	while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) > MaxClients)
		if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == iClient)
			SDKCall_RemoveObject(iClient, iBuilding);
	
	if (IsClassRandomized(iClient))
	{
		TFClassType nClass = GetRandomizedClass(iClient);
		if (nClass != TFClass_Unknown)
			SetEntProp(iClient, Prop_Send, "m_iDesiredPlayerClass", view_as<int>(nClass));
	}
}

public MRESReturn DHook_ForceRespawnPost(int iClient)
{
	//Reattach client's object back
	int iBuilding = MaxClients+1;
	while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) > MaxClients)
		if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == iClient)
			SDKCall_AddObject(iClient, iBuilding);
}

public MRESReturn DHook_EquipWearablePost(int iClient, Handle hParams)
{
	//New wearable is given from somewhere, refresh controls and huds
	Controls_RefreshClient(iClient);
	Huds_RefreshClient(iClient);
}

public MRESReturn DHook_GiveNamedItemPre(int iClient, Handle hReturn, Handle hParams)
{
	if (DHookIsNullParam(hParams, 1) || DHookIsNullParam(hParams, 3))
	{
		DHookSetReturn(hReturn, 0);
		return MRES_Supercede;
	}
	
	char sClassname[256];
	DHookGetParamString(hParams, 1, sClassname, sizeof(sClassname));
	int iIndex = DHookGetParamObjectPtrVar(hParams, 3, g_iOffsetItemDefinitionIndex, ObjectValueType_Int) & 0xFFFF;
	
	if (CanKeepWeapon(iClient, sClassname, iIndex))
		return MRES_Ignored;
	
	DHookSetReturn(hReturn, 0);
	return MRES_Supercede;
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

public MRESReturn DHook_ClientCommandPost(int iClient, Handle hReturn, Handle hParams)
{
	if (iClient == g_iClientEurekaTeleporting)
		g_iClientEurekaTeleporting = 0;
}

public MRESReturn DHook_TakeHealthPre(int iClient, Handle hReturn, Handle hParams)
{
	if (g_bApplyBiteEffectsChocolate[iClient]) 
	{
		DHookSetParam(hParams, 2, DMG_GENERIC);
		return MRES_ChangedHandled;
	}
	return MRES_Ignored;
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