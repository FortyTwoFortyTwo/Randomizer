enum struct Detour
{
	char sName[64];
	DynamicDetour hDetour;
	DHookCallback callbackPre;
	DHookCallback callbackPost;
}

enum struct Hook
{
	DynamicHook hHook;
	DHookCallback callbackPre;
	DHookCallback callbackPost;
	DHookRemovalCB callbackRemoval;
	int iHookIdPre[MAXPLAYERS + 1];
	int iHookIdPost[MAXPLAYERS + 1];
	
	void HookClient(int iClient)
	{
		if (this.callbackPre != INVALID_FUNCTION)
			this.iHookIdPre[iClient] = this.hHook.HookEntity(Hook_Pre, iClient, this.callbackPre, this.callbackRemoval);
		
		if (this.callbackPost != INVALID_FUNCTION)
			this.iHookIdPost[iClient] = this.hHook.HookEntity(Hook_Post, iClient, this.callbackPost, this.callbackRemoval);
	}
	
	void UnhookClient(int iClient)
	{
		DHook_UnhookId(this.iHookIdPre[iClient]);
		DHook_UnhookId(this.iHookIdPost[iClient]);
	}
	
	void HookEntity(int iEntity)
	{
		if (this.callbackPre != INVALID_FUNCTION)
			this.hHook.HookEntity(Hook_Pre, iEntity, this.callbackPre, this.callbackRemoval);
		
		if (this.callbackPost != INVALID_FUNCTION)
			this.hHook.HookEntity(Hook_Post, iEntity, this.callbackPost, this.callbackRemoval);
	}
	
	void HookGamerules()
	{
		if (this.callbackPre != INVALID_FUNCTION)
			this.iHookIdPre[0] = this.hHook.HookGamerules(Hook_Pre, this.callbackPre, this.callbackRemoval);
		
		if (this.callbackPost != INVALID_FUNCTION)
			this.iHookIdPost[0] = this.hHook.HookGamerules(Hook_Post, this.callbackPost, this.callbackRemoval);
	}
	
	void UnhookGamerules()
	{
		DHook_UnhookId(this.iHookIdPre[0]);
		DHook_UnhookId(this.iHookIdPost[0]);
	}
}

static ArrayList g_aDHookDetours;
static ArrayList g_aDHookClientHooks;

static Hook g_DHookGiveNamedItem;
static Hook g_DHookTranslateViewmodelHandActivityInternal;
static Hook g_DHookSecondaryAttack;
static Hook g_DHookGetEffectBarAmmo;
static Hook g_DHookSmack;
static Hook g_DHookSwing;
static Hook g_DHookGetSwordSpeedMod;
static Hook g_DHookGetSwordHealthMod;
static Hook g_DHookKilled;
static Hook g_DHookCanBeUpgraded;
static Hook g_DHookFrameUpdatePostEntityThink;

static bool g_bSkipGetMaxAmmo;
static ArrayList g_aAllowWearables;
static bool g_bInitClass;
static int g_iInitClassActiveWeapon = INVALID_ENT_REFERENCE;
static int g_iInitClassWeapons[48] = {INVALID_ENT_REFERENCE, ...};
static int g_iBuildingKilledSapper = INVALID_ENT_REFERENCE;

static bool g_bDoClassSpecialSkill[MAXPLAYERS + 1];
static bool g_bDoClassSpecialSkillClass[MAXPLAYERS + 1];
static bool g_bApplyBiteEffectsChocolate[MAXPLAYERS + 1];
static bool g_bHalloweenGiant[MAXPLAYERS + 1];

public void DHook_Init(GameData hGameData)
{
	g_aDHookDetours = new ArrayList(sizeof(Detour));
	g_aDHookClientHooks = new ArrayList(sizeof(Hook));
	
	DHook_CreateDetour(hGameData, "CTFPlayer::GiveAmmo", DHook_GiveAmmoPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetMaxAmmo", DHook_GetMaxAmmoPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::Taunt", DHook_TauntPre, DHook_TauntPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::CanAirDash", DHook_CanAirDashPre, DHook_CanAirDashPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::Weapon_GetWeaponByType", _, DHook_GetWeaponByTypePost);
	DHook_CreateDetour(hGameData, "CTFPlayer::DoClassSpecialSkill", DHook_DoClassSpecialSkillPre, DHook_DoClassSpecialSkillPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::EndClassSpecialSkill", DHook_EndClassSpecialSkillPre, DHook_EndClassSpecialSkillPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetChargeEffectBeingProvided", DHook_GetChargeEffectBeingProvidedPre, DHook_GetChargeEffectBeingProvidedPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetMaxHealthForBuffing", DHook_GetMaxHealthForBuffingPre, DHook_GetMaxHealthForBuffingPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::TeamFortress_CalculateMaxSpeed", DHook_CalculateMaxSpeedPre, DHook_CalculateMaxSpeedPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::TakeHealth", DHook_TakeHealthPre, DHook_TakeHealthPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::CheckBlockBackstab", DHook_CheckBlockBackstabPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::CanPickupBuilding", _, DHook_CanPickupBuildingPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::DropRune", DHook_DropRunePre, _);
	DHook_CreateDetour(hGameData, "CTFPlayerClassShared::CanBuildObject", DHook_CanBuildObjectPre, _);
	DHook_CreateDetour(hGameData, "CEconEntity::UpdateModelToClass", DHook_UpdateModelToClassPre, _);
	DHook_CreateDetour(hGameData, "CTFKnife::DisguiseOnKill", DHook_DisguiseOnKillPre, DHook_DisguiseOnKillPost);
	DHook_CreateDetour(hGameData, "CTFLunchBox::ApplyBiteEffects", DHook_ApplyBiteEffectsPre, DHook_ApplyBiteEffectsPost);
	DHook_CreateDetour(hGameData, "CTFGameStats::Event_PlayerFiredWeapon", DHook_PlayerFiredWeaponPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayerShared::UpdateRageBuffsAndRage", DHook_UpdateRageBuffsAndRagePre, _);
	DHook_CreateDetour(hGameData, "CTFPlayerShared::ModifyRage", DHook_ModifyRagePre, _);
	DHook_CreateDetour(hGameData, "CTFPlayerShared::ActivateRageBuff", DHook_ActivateRageBuffPre, DHook_ActivateRageBuffPost);
	DHook_CreateDetour(hGameData, "CTFGameRules::ApplyOnDamageModifyRules", DHook_ApplyOnDamageModifyRulesPre, _);
	DHook_CreateDetour(hGameData, "HandleRageGain", DHook_HandleRageGainPre, _);
	
	DHook_CreateClientHook(hGameData, "CBaseEntity::Event_Killed", DHook_EventKilledPre);
	DHook_CreateClientHook(hGameData, "CBaseEntity::Event_KilledOther", DHook_EventKilledOtherPre);
	DHook_CreateClientHook(hGameData, "CBasePlayer::ForceRespawn", DHook_ForceRespawnPre, DHook_ForceRespawnPost);
	DHook_CreateClientHook(hGameData, "CBasePlayer::ClientCommand", _, DHook_ClientCommandPost);
	DHook_CreateClientHook(hGameData, "CBasePlayer::EquipWearable", _, DHook_EquipWearablePost);
	DHook_CreateClientHook(hGameData, "CBaseCombatCharacter::GetAmmoCount", DHook_GetAmmoCountPre);
	DHook_CreateClientHook(hGameData, "CBaseMultiplayerPlayer::SpeakConceptIfAllowed", DHook_SpeakConceptIfAllowedPre);
	DHook_CreateClientHook(hGameData, "CTFPlayer::InitClass", DHook_InitClassPre, DHook_InitClassPost);
	
	g_DHookGiveNamedItem = DHook_CreateHook(hGameData, "CTFPlayer::GiveNamedItem", DHook_GiveNamedItemPre, _, DHook_GiveNamedItemRemoved);
	g_DHookTranslateViewmodelHandActivityInternal = DHook_CreateHook(hGameData, "CEconEntity::TranslateViewmodelHandActivityInternal", DHook_TranslateViewmodelHandActivityInternalPre, DHook_TranslateViewmodelHandActivityInternalPost);
	g_DHookSecondaryAttack = DHook_CreateHook(hGameData, "CBaseCombatWeapon::SecondaryAttack", _, DHook_SecondaryWeaponPost);
	g_DHookGetEffectBarAmmo = DHook_CreateHook(hGameData, "CTFWeaponBase::GetEffectBarAmmo", _, DHook_GetEffectBarAmmoPost);
	g_DHookSmack = DHook_CreateHook(hGameData, "CTFWeaponBaseMelee::Smack", _, DHook_SmackPost);
	g_DHookSwing = DHook_CreateHook(hGameData, "CTFWeaponBaseMelee::Swing", DHook_SwingPre);
	g_DHookGetSwordSpeedMod = DHook_CreateHook(hGameData, "CTFSword::GetSwordSpeedMod", DHook_GetSwordModPre, DHook_GetSwordModPost);
	g_DHookGetSwordHealthMod = DHook_CreateHook(hGameData, "CTFSword::GetSwordHealthMod", DHook_GetSwordModPre, DHook_GetSwordModPost);
	g_DHookKilled = DHook_CreateHook(hGameData, "CBaseObject::Killed", DHook_KilledPre, DHook_KilledPost);
	g_DHookCanBeUpgraded = DHook_CreateHook(hGameData, "CBaseObject::CanBeUpgraded", DHook_CanBeUpgradedPre, DHook_CanBeUpgradedPost);
	g_DHookFrameUpdatePostEntityThink = DHook_CreateHook(hGameData, "CGameRules::FrameUpdatePostEntityThink", DHook_FrameUpdatePostEntityThinkPre, DHook_FrameUpdatePostEntityThinkPost);
}

static void DHook_CreateDetour(GameData hGameData, const char[] sName, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	Detour detour;
	detour.hDetour = DynamicDetour.FromConf(hGameData, sName);
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

static Hook DHook_CreateHook(GameData hGameData, const char[] sName, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION, DHookRemovalCB callbackRemoval = INVALID_FUNCTION)
{
	Hook hook;
	hook.hHook = DynamicHook.FromConf(hGameData, sName);
	if (!hook.hHook)
	{
		LogError("Failed to create hook: %s", sName);
	}
	else
	{
		hook.callbackPre = callbackPre;
		hook.callbackPost = callbackPost;
		hook.callbackRemoval = callbackRemoval;
	}
	
	return hook;
}

static void DHook_CreateClientHook(GameData hGameData, const char[] sName, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	Hook hook;
	hook = DHook_CreateHook(hGameData, sName, callbackPre, callbackPost);
	if (hook.hHook)
		g_aDHookClientHooks.PushArray(hook);
}

void DHook_EnableDetour()
{
	int iLength = g_aDHookDetours.Length;
	for (int i = 0; i < iLength; i++)
	{
		Detour detour;
		g_aDHookDetours.GetArray(i, detour);
		
		if (detour.callbackPre != INVALID_FUNCTION)
			if (!detour.hDetour.Enable(Hook_Pre, detour.callbackPre))
				LogError("Failed to enable pre detour: %s", detour.sName);
		
		if (detour.callbackPost != INVALID_FUNCTION)
			if (!detour.hDetour.Enable(Hook_Post, detour.callbackPost))
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
			if (!detour.hDetour.Disable(Hook_Pre, detour.callbackPre))
				LogError("Failed to disable pre detour: %s", detour.sName);
		
		if (detour.callbackPost != INVALID_FUNCTION)
			if (!detour.hDetour.Disable(Hook_Post, detour.callbackPost))
				LogError("Failed to disable post detour: %s", detour.sName);
	}
}

void DHook_HookGiveNamedItem(int iClient)
{
	if (g_DHookGiveNamedItem.hHook && !g_bTF2Items)
		g_DHookGiveNamedItem.HookClient(iClient);
}

void DHook_UnhookGiveNamedItem(int iClient)
{
	g_DHookGiveNamedItem.UnhookClient(iClient);
}

bool DHook_IsGiveNamedItemActive()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (g_DHookGiveNamedItem.iHookIdPre[iClient])
			return true;
	
	return false;
}

void DHook_HookClient(int iClient)
{
	int iLength = g_aDHookClientHooks.Length;
	for (int i = 0; i < iLength; i++)
	{
		Hook hook;
		g_aDHookClientHooks.GetArray(i, hook);
		hook.HookClient(iClient);
		g_aDHookClientHooks.SetArray(i, hook);
	}
}

void DHook_UnhookClient(int iClient)
{
	int iLength = g_aDHookClientHooks.Length;
	for (int i = 0; i < iLength; i++)
	{
		Hook hook;
		g_aDHookClientHooks.GetArray(i, hook);
		hook.UnhookClient(iClient);
		g_aDHookClientHooks.SetArray(i, hook);
	}
}

static void DHook_UnhookId(int &iId)
{
	if (iId)
	{
		DHookRemoveHookID(iId);
		iId = 0;
	}
}

void DHook_OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (StrContains(sClassname, "tf_weapon_") == 0)
	{
		SDKHook(iEntity, SDKHook_SpawnPost, DHook_SpawnPost);
		g_DHookTranslateViewmodelHandActivityInternal.HookEntity(iEntity);
		g_DHookSecondaryAttack.HookEntity(iEntity);
		g_DHookGetEffectBarAmmo.HookEntity(iEntity);
	}
	
	if (StrContains(sClassname, "obj_") == 0 && !StrEqual(sClassname, "obj_attachment_sapper"))
	{
		g_DHookKilled.HookEntity(iEntity);
		g_DHookCanBeUpgraded.HookEntity(iEntity);
	}
}

void DHook_HookGamerules()
{
	g_DHookFrameUpdatePostEntityThink.HookGamerules();
}

void DHook_UnhookGamerules()
{
	g_DHookFrameUpdatePostEntityThink.UnhookGamerules();
}

public void DHook_SpawnPost(int iWeapon)
{
	if (TF2_GetSlot(iWeapon) == WeaponSlot_Melee)
	{
		if (HasEntProp(iWeapon, Prop_Send, "m_bBroken"))
			g_DHookSmack.HookEntity(iWeapon);
		
		g_DHookSwing.HookEntity(iWeapon);
	}
	
	if (IsClassname(iWeapon, "tf_weapon_sword"))
	{
		g_DHookGetSwordSpeedMod.HookEntity(iWeapon);
		g_DHookGetSwordHealthMod.HookEntity(iWeapon);
	}
}

public MRESReturn DHook_GiveAmmoPre(int iClient, DHookReturn hReturn, DHookParam hParams)
{
	//Detour is used instead of virtual because non-virtual CTFPlayer::GiveAmmo directly calls CBaseCombatCharacter::GiveAmmo in non-virtual way
	int iForceWeapon = Properties_GetForceWeaponAmmo();
	if (iForceWeapon != INVALID_ENT_REFERENCE)
		Properties_ResetForceWeaponAmmo();
	
	if (g_bSkipGetMaxAmmo)
		return MRES_Ignored;
	
	int iCount = hParams.Get(1);
	if (iCount <= 0)
		return MRES_Ignored;
	
	int iAmmoType = hParams.Get(2);
	if (iAmmoType == TF_AMMO_METAL)	//Nothing fancy for metal
		return MRES_Ignored;
	
	bool bSuppressSound = hParams.Get(3);
	EAmmoSource eAmmoSource = hParams.Get(4);
	
	Properties_SaveActiveWeaponAmmo(iClient);
	g_bSkipGetMaxAmmo = true;
	
	int iTotalAdded;
	int iMaxAmmoTF2 = SDKCall_GetMaxAmmo(iClient, iAmmoType);	//TF2 calculation for max ammo, which is usually incorrect
	
	//Give the ammo to each weapons by ammotype
	int iMaxWeapons = GetMaxWeapons();
	for (int i = 0; i < iMaxWeapons; i++)
	{
		int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		
		bool bGive;
		if (iForceWeapon == INVALID_ENT_REFERENCE && iWeapon != INVALID_ENT_REFERENCE && GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType") == iAmmoType)
			bGive = true;
		else if (iForceWeapon != INVALID_ENT_REFERENCE && iForceWeapon == iWeapon)
			bGive = true;
		
		if (bGive)
		{
			int iMaxAmmo = TF2_GetMaxAmmo(iClient, iWeapon, iAmmoType);
			
			int iAdd = iCount;
			if (iForceWeapon == INVALID_ENT_REFERENCE)
				iAdd = RoundToFloor(float(iCount) * float(iMaxAmmo) / float(iMaxAmmoTF2));
			
			int iCurrent = Properties_GetWeaponPropInt(iWeapon, "m_iAmmo");
			iAdd = TF2_GiveAmmo(iClient, iWeapon, iCurrent, iAdd, iAmmoType, bSuppressSound, eAmmoSource);
			Properties_SetWeaponPropInt(iWeapon, "m_iAmmo", iCurrent + iAdd);
			iTotalAdded += iAdd;
		}
	}
	
	//Set ammo back to what it was for active weapon
	Properties_UpdateActiveWeaponAmmo(iClient);
	
	g_bSkipGetMaxAmmo = false;
	
	hReturn.Value = iTotalAdded;
	return MRES_Supercede;
}

public MRESReturn DHook_GetMaxAmmoPre(int iClient, DHookReturn hReturn, DHookParam hParams)
{
	int iWeapon = Properties_GetForceWeaponAmmo();
	if (iWeapon != INVALID_ENT_REFERENCE)
		Properties_ResetForceWeaponAmmo();	//Could add primary ammo type check, but it should always be true anyway
	
	if (g_bSkipGetMaxAmmo)
		return MRES_Ignored;
	
	if (iWeapon != INVALID_ENT_REFERENCE)
	{
		//Shouldn't need to worry with multiple weapons using same index, only
		// TF_AMMO_GRENADES1 and TF_AMMO_GRENADES2 is used here
		hParams.Set(2, TF2_GetDefaultClassFromItem(iWeapon));
		return MRES_ChangedHandled;
	}
	
	if (hParams.Get(1) == TF_AMMO_METAL)
	{
		//Engineer have max metal 200 while others have 100
		hParams.Set(2, TFClass_Engineer);
		return MRES_ChangedHandled;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_TauntPre(int iClient, DHookParam hParams)
{
	if (!g_cvFixTaunt.BoolValue)
		return MRES_Ignored;

	//Dont allow taunting if disguised or cloaked
	if (TF2_IsPlayerInCondition(iClient, TFCond_Disguising) || TF2_IsPlayerInCondition(iClient, TFCond_Disguised) || TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
		return MRES_Supercede;
	
	//Player wants to taunt, set class to whoever can actually taunt with active weapon
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon == INVALID_ENT_REFERENCE)
		return MRES_Ignored;
	
	SetClientClass(iClient, TF2_GetDefaultClassFromItem(iWeapon));
	return MRES_Ignored;
}

public MRESReturn DHook_TauntPost(int iClient, DHookParam hParams)
{
	if (!g_cvFixTaunt.BoolValue)
		return MRES_Ignored;

	if (TF2_IsPlayerInCondition(iClient, TFCond_Disguising) || TF2_IsPlayerInCondition(iClient, TFCond_Disguised) || TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
		return MRES_Supercede;
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon == INVALID_ENT_REFERENCE)
		return MRES_Ignored;
	
	//Set class back to what it was
	RevertClientClass(iClient);
	return MRES_Ignored;
}

public MRESReturn DHook_CanAirDashPre(int iClient, DHookReturn hReturn)
{
	if (TF2_GetPlayerClass(iClient) == TFClass_Scout)
		return MRES_Ignored;
	
	//Soda Popper and Atomizer's extra jumps does not work for non-scouts, fix that
	int iAirDash = GetEntProp(iClient, Prop_Send, "m_iAirDash");
	
	if (TF2_IsPlayerInCondition(iClient, TFCond_CritHype) && iAirDash <= 6)
	{
		SetEntProp(iClient, Prop_Send, "m_iAirDash", iAirDash + 1);
		hReturn.Value = true;
		return MRES_Supercede;
	}
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon == INVALID_ENT_REFERENCE)
		return MRES_Ignored;
	
	if (iAirDash < RoundToNearest(TF2Attrib_HookValueFloat(0.0, "air_dash_count", iWeapon)))
	{
		SetEntProp(iClient, Prop_Send, "m_iAirDash", iAirDash + 1);
		hReturn.Value = true;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_CanAirDashPost(int iClient, DHookReturn hReturn)
{
	//Client should always air dash if this returns true
	if (hReturn.Value)
	{
		//Lose hype meter
		int iWeapon, iPos;
		while (TF2_GetItem(iClient, iWeapon, iPos))
		{
			float flVal = TF2Attrib_HookValueFloat(0.0, "hype_resets_on_jump", iWeapon);	//Despite what name says, it doesn't fully reset
			if (flVal)
			{
				float flHypeMeter = Properties_GetWeaponPropFloat(iWeapon, "m_flHypeMeter");
				Properties_SetWeaponPropFloat(iWeapon, "m_flHypeMeter", max(0.0, flHypeMeter - flVal));
			}
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_GetWeaponByTypePost(int iClient, DHookReturn hReturn, DHookParam hParams)
{
	//This detour is to fix crash from engineer using sapper,
	// prioritize which weapon to return by active weapon.
	// "type" here is a whole load of different slot can't be arsed to list here,
	// just use returned weapon as loadout slot to find
	int iReturnWeapon = hReturn.Value;
	if (iReturnWeapon == INVALID_ENT_REFERENCE)
		return MRES_Ignored;
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon == INVALID_ENT_REFERENCE || iReturnWeapon == iActiveWeapon)
		return MRES_Ignored;
	
	int iReturnSlot = TF2Econ_GetItemDefaultLoadoutSlot(GetEntProp(iReturnWeapon, Prop_Send, "m_iItemDefinitionIndex"));
	int iActiveSlot = TF2Econ_GetItemDefaultLoadoutSlot(GetEntProp(iActiveWeapon, Prop_Send, "m_iItemDefinitionIndex"));
	if (iReturnSlot == iActiveSlot)
	{
		hReturn.Value = iActiveWeapon;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_DoClassSpecialSkillPre(int iClient, DHookReturn hReturn)
{
	//There 4 things going on in this function depending on player class attempting to:
	//If Grappling Hook active weapon, activate rune
	//If Demoman, detonate stickies or charge
	//If Engineer, pickup buildings
	//If Spy, cloak or uncloak
	
	g_bDoClassSpecialSkill[iClient] = true;	// To stop DHook_SecondaryWeaponPost from calling this again
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon == INVALID_ENT_REFERENCE)
		return MRES_Ignored;
	
	int iButtons = GetClientButtons(iClient);
	
	int iWeapon, iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		if (!Controls_CanUse(iClient, iWeapon))
			continue;
		
		int iButton = Controls_GetPassiveButtonBit(iClient, iWeapon);
		if (iButton > 0 && iButtons & iButton)
		{
			g_bDoClassSpecialSkillClass[iClient] = true;
			Controls_OnPassiveUse(iClient, iWeapon);
			SetClientClass(iClient, TF2_GetDefaultClassFromItem(iWeapon));
			return MRES_Ignored;
		}
	}
	
	//Cant find any valid passive weapon to use, prevent function called
	hReturn.Value = false;
	return MRES_Supercede;
}

public MRESReturn DHook_DoClassSpecialSkillPost(int iClient, DHookReturn hReturn)
{
	if (g_bDoClassSpecialSkillClass[iClient])
	{
		RevertClientClass(iClient);
		g_bDoClassSpecialSkillClass[iClient] = false;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_EndClassSpecialSkillPre(int iClient, DHookReturn hReturn)
{
	//Only have demoman check to end charge
	SetClientClass(iClient, TFClass_DemoMan);
	return MRES_Ignored;
}

public MRESReturn DHook_EndClassSpecialSkillPost(int iClient, DHookReturn hReturn)
{
	RevertClientClass(iClient);
	return MRES_Ignored;
}

public MRESReturn DHook_GetChargeEffectBeingProvidedPre(int iClient, DHookReturn hReturn)
{
	if (IsClientInGame(iClient))
		SetClientClass(iClient, TFClass_Medic);	//Has medic class check for getting uber types
	
	return MRES_Ignored;
}

public MRESReturn DHook_GetChargeEffectBeingProvidedPost(int iClient, DHookReturn hReturn)
{
	if (IsClientInGame(iClient))
		RevertClientClass(iClient);
	
	return MRES_Ignored;
}

public MRESReturn DHook_GetMaxHealthForBuffingPre(int iClient, DHookReturn hReturn)
{
	if (TF2_IsPlayerInCondition(iClient, TFCond_HalloweenGiant))
	{
		// Don't modify HP by giant yet, may need to update value from eyelander
		g_bHalloweenGiant[iClient] = true;
		TF2_RemoveConditionFake(iClient, TFCond_HalloweenGiant);
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_GetMaxHealthForBuffingPost(int iClient, DHookReturn hReturn)
{
	int iMax = hReturn.Value;
	int iNewMax = iMax;
	
	if (TF2_GetPlayerClass(iClient) != TFClass_DemoMan)
	{
		// Need to manually call virtual
		
		// Only need to call once, all swords should have same value
		int iWeapon, iPos;
		if (TF2_GetItemFromClassname(iClient, "tf_weapon_sword", iWeapon, iPos))
			iNewMax += SDKCall_GetSwordHealthMod(iWeapon);
	}
	
	if (g_bHalloweenGiant[iClient])
	{
		g_bHalloweenGiant[iClient] = false;
		TF2_AddConditionFake(iClient, TFCond_HalloweenGiant);
		
		static ConVar cvHealthScale;
		if (!cvHealthScale)
			cvHealthScale = FindConVar("tf_halloween_giant_health_scale");
		
		// Is it floor by default when float becomes int?
		iNewMax = RoundToFloor(float(iNewMax) * cvHealthScale.FloatValue);
	}
	
	if (iNewMax != iMax)
	{
		hReturn.Value = iNewMax;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_CalculateMaxSpeedPre(int iClient, DHookReturn hReturn, DHookParam hParams)
{
	if (!IsClientInGame(iClient))	//IsClientInGame check is needed, weird game
		return MRES_Ignored;
	
	// Eyelander kill causing client to be at same speed as Demoman
	if (TF2_GetPlayerClass(iClient) != TFClass_Unknown)
		SetClientClassOriginal(iClient);
	
	Patch_SetSpeed(TF2_GetPlayerClass(iClient));
	
	int iWeapon, iPos;
	
	//Set hype to any baby face blaster, all should have same value
	if (TF2_GetItemFromClassname(iClient, "tf_weapon_pep_brawler_blaster", iWeapon, iPos))
		Properties_LoadWeaponPropFloat(iClient, iWeapon, "m_flHypeMeter");
	
	return MRES_Ignored;
}

public MRESReturn DHook_CalculateMaxSpeedPost(int iClient, DHookReturn hReturn, DHookParam hParams)
{
	if (!IsClientInGame(iClient))
		return MRES_Ignored;
	
	//Set hype meter back to active weapon, unless if were in PreThink hook for meter drainage
	if (g_iHypeMeterLoaded[iClient] == INVALID_ENT_REFERENCE)
		Properties_LoadActiveWeaponPropFloat(iClient, "m_flHypeMeter");
	else
		Properties_LoadWeaponPropFloat(iClient, g_iHypeMeterLoaded[iClient], "m_flHypeMeter");
	
	if (TF2_GetPlayerClass(iClient) != TFClass_Unknown)
		RevertClientClass(iClient);
	
	return MRES_Ignored;
}

public MRESReturn DHook_CanBuildObjectPre(Address pPlayerClassShared, DHookReturn hReturn, DHookParam hParams)
{
	if (g_bInitClass)
		return MRES_Ignored;	//Do class check if inside CTFPlayer::ManageBuilderWeapons
	
	hReturn.Value = true;
	return MRES_Supercede;
}

public MRESReturn DHook_UpdateModelToClassPre(int iWeapon)
{
	//Custom viewmodel can weirdly bug out on weapons with "provide_on_active" attribute,
	// Prevent UpdateModelToClass from being called again, which usually happens on weapon switch
	
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	if (iClient != INVALID_ENT_REFERENCE)
		return MRES_Supercede;
	
	return MRES_Ignored;
}

public MRESReturn DHook_DisguiseOnKillPre(int iWeapon)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	SetClientClass(iClient, TFClass_Spy);
	return MRES_Ignored;
}

public MRESReturn DHook_DisguiseOnKillPost(int iWeapon)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	RevertClientClass(iClient);
	return MRES_Ignored;
}

public MRESReturn DHook_ApplyBiteEffectsPre(int iWeapon, DHookParam hParams)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");	
	
	if (TF2Attrib_HookValueFloat(0.0, "set_weapon_mode", iWeapon))
		g_bApplyBiteEffectsChocolate[iClient] = true;
	
	return MRES_Ignored;
}

public MRESReturn DHook_ApplyBiteEffectsPost(int iWeapon, DHookParam hParams)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");	
	g_bApplyBiteEffectsChocolate[iClient] = false;
	return MRES_Ignored;
}

public MRESReturn DHook_PlayerFiredWeaponPre(Address pGameStats, DHookParam hParams)
{
	//Not all weapons remove disguise
	int iClient = hParams.Get(1);
	
	if (TF2_IsPlayerInCondition(iClient, TFCond_Disguising))
		TF2_RemoveCondition(iClient, TFCond_Disguising);
	
	if (TF2_IsPlayerInCondition(iClient, TFCond_Disguised))
		TF2_RemoveCondition(iClient, TFCond_Disguised);
	
	return MRES_Ignored;
}

public MRESReturn DHook_UpdateRageBuffsAndRagePre(Address pPlayerShared)
{
	int iClient = SDKCall_GetBaseEntity(pPlayerShared - view_as<Address>(g_iOffsetPlayerShared));
	if (g_iGainingRageWeapon != INVALID_ENT_REFERENCE || iClient <= 0 || iClient > MaxClients)
		return MRES_Ignored;
	
	if (!TF2Attrib_HookValueFloat(0.0, "set_buff_type", iClient))
		return MRES_Ignored;	//We don't have any rage items, don't need to do anything
	
	RequestFrame(Properties_UpdateRageBuffsAndRage, iClient);
	return MRES_Supercede;
}

public MRESReturn DHook_ModifyRagePre(Address pPlayerShared, DHookParam hParams)
{
	int iClient = SDKCall_GetBaseEntity(pPlayerShared - view_as<Address>(g_iOffsetPlayerShared));
	if (iClient && g_iGainingRageWeapon == INVALID_ENT_REFERENCE)
	{
		DataPack hPack = new DataPack();
		hPack.WriteCell(GetClientSerial(iClient));
		hPack.WriteFloat(hParams.Get(1));
		
		RequestFrame(Properties_ModifyRage, hPack);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_ActivateRageBuffPre(Address pPlayerShared, DHookParam hParams)
{
	int iClient = SDKCall_GetBaseEntity(pPlayerShared - view_as<Address>(g_iOffsetPlayerShared));
	if (!iClient)
		return MRES_Ignored;
	
	//First param is unused, named pBuffItem.
	// But TF2 pass this param as either buff banner or player itself :japanese_goblin:
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon == INVALID_ENT_REFERENCE)
		return MRES_Ignored;
	
	int iBuffType = hParams.Get(2);
	float flClientRageType = TF2Attrib_HookValueFloat(0.0, "set_buff_type", iClient);
	TF2Attrib_SetByName(iClient, "mod soldier buff type", float(iBuffType) - flClientRageType);
	
	Properties_LoadRageProps(iClient, iWeapon);
	return MRES_Ignored;
}

public MRESReturn DHook_ActivateRageBuffPost(Address pPlayerShared, DHookParam hParams)
{
	int iClient = SDKCall_GetBaseEntity(pPlayerShared - view_as<Address>(g_iOffsetPlayerShared));
	if (!iClient)
		return MRES_Ignored;
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon == INVALID_ENT_REFERENCE)
		return MRES_Ignored;
	
	TF2Attrib_RemoveByName(iClient, "mod soldier buff type");
	Properties_SaveRageProps(iClient, iWeapon);
	return MRES_Ignored;
}

public MRESReturn DHook_ApplyOnDamageModifyRulesPre(Address pGamerules, DHookReturn hReturn, DHookParam hParams)
{
	if (g_bOnTakeDamage)
	{
		g_bOnTakeDamage = false;
		Patch_EnableIsPlayerClass();
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_HandleRageGainPre(DHookParam hParams)
{
	//Banners, Phlogistinator and Hitman Heatmaker use m_flRageMeter with class check, call this function to each weapons
	//Must be called a frame, will crash if detour is called while inside a detour
	if (g_iGainingRageWeapon != INVALID_ENT_REFERENCE || hParams.IsNull(1))
		return MRES_Ignored;
	
	DataPack hPack = new DataPack();
	hPack.WriteCell(GetClientSerial(hParams.Get(1)));
	hPack.WriteCell(hParams.Get(2));
	hPack.WriteFloat(hParams.Get(3));
	hPack.WriteFloat(hParams.Get(4));
	
	RequestFrame(Properties_HandleRageGain, hPack);
	return MRES_Supercede;
}

public MRESReturn DHook_SmackPost(int iWeapon)
{
	if (!GetEntProp(iWeapon, Prop_Send, "m_bBroken"))
		return MRES_Ignored;
	
	//Bottle and Caber may've updated its model after smack, where only client(?) bothered to update it's model,
	// so we'll have to update model index prop just so custom viewmodels can work
	char sModel[PLATFORM_MAX_PATH];
	int iModelIndex = INVALID_STRING_INDEX;
	if (IsClassname(iWeapon, "tf_weapon_stickbomb"))
	{
		sModel = "models/workshop/weapons/c_models/c_caber/c_caber_exploded.mdl";
		iModelIndex = GetModelIndex(sModel);
	}
	else
	{
		GetEntityModel(iWeapon, sModel, sizeof(sModel), "m_iWorldModelIndex");
		if (StrContains(sModel, "_broken.mdl") != -1)
			return MRES_Ignored;	//Model is already updated
		
		ReplaceString(sModel, sizeof(sModel), ".mdl", "_broken.mdl");
		if (!FileExists(sModel, true))
			ReplaceString(sModel, sizeof(sModel), "workshop/", "");	// Scottish Handshake hahaaaa
		
		iModelIndex = PrecacheModel(sModel);
	}
	
	SetEntProp(iWeapon, Prop_Send, "m_iWorldModelIndex", iModelIndex);
	
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	ViewModels_UpdateArms(iClient);
	return MRES_Ignored;
}

public MRESReturn DHook_SwingPre(int iWeapon, DHookReturn hReturn)
{
	//Not all melee weapons call to end demo charge
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	if (0 < iClient <= MaxClients)
		SDKCall_EndClassSpecialSkill(iClient);
	
	return MRES_Ignored;
}

public MRESReturn DHook_GetSwordModPre(int iWeapon, DHookReturn hReturn)
{
	// For both speed and health hooks
	
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	if (g_bWeaponDecap[iClient])
		return MRES_Ignored;
	
	if (0 < iClient <= MaxClients)
		Properties_LoadWeaponPropInt(iClient, iWeapon, "m_iDecapitations");
	
	return MRES_Ignored;
}

public MRESReturn DHook_GetSwordModPost(int iWeapon, DHookReturn hReturn)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	if (g_bWeaponDecap[iClient])
		return MRES_Ignored;
	
	if (0 < iClient <= MaxClients)
		Properties_LoadActiveWeaponPropInt(iClient, "m_iDecapitations");
	
	return MRES_Ignored;
}

public MRESReturn DHook_TranslateViewmodelHandActivityInternalPre(int iWeapon, DHookReturn hReturn, DHookParam hParams)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	SetClientClass(iClient, TF2_GetDefaultClassFromItem(iWeapon));
	return MRES_Ignored;
}

public MRESReturn DHook_TranslateViewmodelHandActivityInternalPost(int iWeapon, DHookReturn hReturn, DHookParam hParams)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	RevertClientClass(iClient);
	return MRES_Ignored;
}

public MRESReturn DHook_SecondaryWeaponPost(int iWeapon)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	
	//If DoClassSpecialSkill not called during secondary attack, do it anyway lol
	if (!g_bDoClassSpecialSkill[iClient])
	{
		g_bDoClassSpecialSkill[iClient] = true;
		SDKCall_DoClassSpecialSkill(iClient);
	}
	
	g_bDoClassSpecialSkill[iClient] = false;
	
	//Sandvich might've thrown out and switched weapon while inside SecondaryWeapon call, save charge meter
	Properties_SaveWeaponPropFloat(iClient, iWeapon, "m_flItemChargeMeter", TF2_GetSlot(iWeapon));
	return MRES_Ignored;
}

public MRESReturn DHook_GetEffectBarAmmoPost(int iWeapon, DHookReturn hReturn)
{
	//This function is only called for GetAmmoCount, GetMaxAmmo and GiveAmmo
	Properties_SetForceWeaponAmmo(iWeapon);
	return MRES_Ignored;
}

public MRESReturn DHook_KilledPre(int iObject)
{
	//There is 1 Param, CTakeDamageInfo ref, but not listed in windows as it gives crashes
	//Save current revenge count, then set to 0 for both builder and attacker
	
	int iClient = GetEntPropEnt(iObject, Prop_Send, "m_hBuilder");
	if (0 < iClient <= MaxClients)
	{
		Properties_SaveActiveWeaponPropInt(iClient, "m_iRevengeCrits");
		SetEntProp(iClient, Prop_Send, "m_iRevengeCrits", 0);
	}
	
	g_iBuildingKilledSapper = TF2_GetSapper(iObject);
	if (g_iBuildingKilledSapper != INVALID_ENT_REFERENCE)
	{
		int iAttacker = GetEntPropEnt(g_iBuildingKilledSapper, Prop_Send, "m_hBuilder");
		if (0 < iAttacker <= MaxClients)
		{
			Properties_SaveActiveWeaponPropInt(iAttacker, "m_iRevengeCrits");
			SetEntProp(iAttacker, Prop_Send, "m_iRevengeCrits", 0);
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_KilledPost(int iObject)
{
	int iClient = GetEntPropEnt(iObject, Prop_Send, "m_hBuilder");
	if (0 < iClient <= MaxClients)
	{
		//Increase count for sentry_killed_revenge
		int iCount = GetEntProp(iClient, Prop_Send, "m_iRevengeCrits");
		if (iCount > 0)
		{
			int iTempWeapon, iPos;
			while (TF2_GetItemFromAttribute(iClient, "sentry_killed_revenge", iTempWeapon, iPos))
				Properties_AddWeaponPropInt(iTempWeapon, "m_iRevengeCrits", iCount);
		}
		
		//Set back to active weapon
		Properties_LoadActiveWeaponPropInt(iClient, "m_iRevengeCrits");
	}
	
	//Sapper is detached in post hook as object is being removed
	
	//Revenge collected is from any reason building is removed (CBaseObject::UpdateOnRemove) instead from fancy destroyed (CBaseObject::Killed)
	// Is it worth hooking UpdateOnRemove? meh...
	
	if (g_iBuildingKilledSapper != INVALID_ENT_REFERENCE)
	{
		int iAttacker = GetEntPropEnt(g_iBuildingKilledSapper, Prop_Send, "m_hBuilder");
		if (0 < iAttacker <= MaxClients)
		{
			//Increase count for sapper_kills_collect_crits
			int iCount = GetEntProp(iAttacker, Prop_Send, "m_iRevengeCrits");
			if (iCount > 0)
			{
				int iTempWeapon, iPos;
				while (TF2_GetItemFromAttribute(iAttacker, "sapper_kills_collect_crits", iTempWeapon, iPos))
					Properties_AddWeaponPropInt(iTempWeapon, "m_iRevengeCrits", iCount);
			}
			
			//Set back to active weapon
			Properties_LoadActiveWeaponPropInt(iAttacker, "m_iRevengeCrits");
		}
	}
	
	g_iBuildingKilledSapper = INVALID_ENT_REFERENCE;
	return MRES_Ignored;
}

public MRESReturn DHook_CanBeUpgradedPre(int iObject, DHookReturn hReturn, DHookParam hParams)
{
	//This function have engineer class check
	int iClient = hParams.Get(1);
	SetClientClass(iClient, TFClass_Engineer);
	return MRES_Ignored;
}

public MRESReturn DHook_CanBeUpgradedPost(int iObject, DHookReturn hReturn, DHookParam hParams)
{
	int iClient = hParams.Get(1);
	RevertClientClass(iClient);
	return MRES_Ignored;
}

public MRESReturn DHook_EventKilledPre(int iClient, DHookParam hParams)
{
	//Remove rune so it won't be dropped as pickupable
	if (Group_IsClientRandomized(iClient, RandomizedType_Rune))
		Loadout_ResetClientRune(iClient);
	
	return MRES_Ignored;
}

public MRESReturn DHook_EventKilledOtherPre(int iClient, DHookParam hParams)
{
	int iVictim = hParams.Get(1);
	if (iVictim <= 0 || iVictim > MaxClients)
		return MRES_Ignored;
	
	if (TF2_GetPlayerClass(iClient) != TFClass_DemoMan && TF2_GetClientTeam(iClient) != TF2_GetClientTeam(iVictim))
	{
		// Manually award charge meters
		// There whole achivements were missing, but meh, too much effort to make it work
		float flRefill = 0.0;
		TF2Attrib_HookValueFloat(flRefill, "kill_refills_meter", iClient);
		
		if (TF2_IsPlayerInCondition(iClient, TFCond_RuneKnockout))	// really should be GetCarryingRuneType, but good enough
			flRefill *= 0.2;
		
		int iDamageType = hParams.GetObjectVar(2, g_iOffsetDamageType, ObjectValueType_Int);
		int iDamageCustom = hParams.GetObjectVar(2, g_iOffsetDamageCustom, ObjectValueType_Int);
		
		if (flRefill > 0 && ((iDamageType & DMG_MELEE) || (iDamageCustom == TF_CUSTOM_CHARGE_IMPACT)))
		{
			float flMeter = GetEntProp(iClient, Prop_Send, "m_flChargeMeter") + (flRefill * 100.0);
			SetEntProp(iClient, Prop_Send, "m_flChargeMeter", clamp(flMeter, 0.0, 100.0));
		}
	}
	
	if (TF2_GetPlayerClass(iClient) != TFClass_Sniper)
	{
		// Manually give rages
		float flRageGain = 0.0;
		TF2Attrib_HookValueFloat(flRageGain, "rage_on_kill", iClient);
		if (flRageGain != 0.0)
			SDKCall_ModifyRage(GetEntityAddress(iClient) + view_as<Address>(g_iOffsetPlayerShared), flRageGain);
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_ForceRespawnPre(int iClient)
{
	//Update incase of changing group
	Loadout_UpdateClientInfo(iClient);
	
	//Reset decap count
	int iWeapon, iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
		Properties_SetWeaponPropInt(iWeapon, "m_iDecapitations", 0);
	
	//Detach client's object so it doesnt get destroyed on class change
	int iBuilding = MaxClients+1;
	while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) > MaxClients)
		if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == iClient)
			SDKCall_RemoveObject(iClient, iBuilding);
	
	if (Group_IsClientRandomized(iClient, RandomizedType_Class))
	{
		TFClassType nClass = Loadout_GetClientClass(iClient);
		if (nClass != TFClass_Unknown)
			SetEntProp(iClient, Prop_Send, "m_iDesiredPlayerClass", view_as<int>(nClass));
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_ForceRespawnPost(int iClient)
{
	//Reattach client's object back
	int iBuilding = MaxClients+1;
	while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) > MaxClients)
		if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == iClient)
			SDKCall_AddObject(iClient, iBuilding);
	
	return MRES_Ignored;
}

public MRESReturn DHook_ClientCommandPost(int iClient, DHookReturn hReturn, DHookParam hParams)
{
	if (g_iClientEurekaTeleporting)
	{
		RevertClientClass(iClient);
		g_iClientEurekaTeleporting = 0;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_EquipWearablePost(int iClient, DHookParam hParams)
{
	//New wearable is given from somewhere, refresh controls and huds
	Controls_RefreshClient(iClient);
	Huds_RefreshClient(iClient);
	return MRES_Ignored;
}

public MRESReturn DHook_GetAmmoCountPre(int iClient, DHookReturn hReturn, DHookParam hParams)
{
	int iWeapon = Properties_GetForceWeaponAmmo();
	if (iWeapon != INVALID_ENT_REFERENCE)
	{
		Properties_ResetForceWeaponAmmo();
		hReturn.Value = Properties_GetWeaponPropInt(iWeapon, "m_iAmmo");
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_SpeakConceptIfAllowedPre(int iClient, DHookReturn hReturn, DHookParam hParams)
{
	// There a spy check for silent YER kill
	int iConcept = hParams.Get(1);
	if (iConcept == MP_CONCEPT_KILLED_PLAYER)
	{
		int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
		if (iActiveWeapon == INVALID_ENT_REFERENCE)
			return MRES_Ignored;
		
		int iMode;
		TF2Attrib_HookValueInt(iMode, "set_weapon_mode", iActiveWeapon);
		if (iMode == 1)	// KNIFE_DISGUISE_ONKILL
		{
			hReturn.Value = false;
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_GiveNamedItemPre(int iClient, DHookReturn hReturn, DHookParam hParams)
{
	if (hParams.IsNull(1) || hParams.IsNull(3))
	{
		hReturn.Value = 0;
		return MRES_Supercede;
	}
	
	if (g_bAllowGiveNamedItem)
		return MRES_Ignored;
	
	int iIndex = hParams.GetObjectVar(3, g_iOffsetItemDefinitionIndex, ObjectValueType_Int) & 0xFFFF;
	if (CanEquipIndex(iClient, iIndex))
		return MRES_Ignored;
	
	hReturn.Value = 0;
	return MRES_Supercede;
}

public void DHook_GiveNamedItemRemoved(int iHookId)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (g_DHookGiveNamedItem.iHookIdPre[iClient] == iHookId)
		{
			g_DHookGiveNamedItem.iHookIdPre[iClient] = 0;
			return;
		}
	}
}

public MRESReturn DHook_InitClassPre(int iClient)
{
	g_bInitClass = true;
	g_iClientInitClass = iClient;
	
	//Give rune so health and ammo can be calculated correctly, but TF2 will remove it after validate
	if (Group_IsClientRandomized(iClient, RandomizedType_Rune))
		Loadout_ApplyClientRune(iClient);
	
	g_iInitClassActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	//ValidateWeapons validates non-wearable weapons, remove em at m_hMyWeapons so there nothing to validates!
	for (int i = 0; i < sizeof(g_iInitClassWeapons); i++)
	{
		g_iInitClassWeapons[i] = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		if (g_iInitClassWeapons[i] == INVALID_ENT_REFERENCE)
			continue;
		
		if (Group_IsClientRandomized(iClient, RandomizedType_Spells))
		{
			if (IsClassname(g_iInitClassWeapons[i], "tf_weapon_spellbook") || (FindConVar("tf_grapplinghook_enable").BoolValue && IsClassname(g_iInitClassWeapons[i], "tf_weapon_grapplinghook")))
			{
				//Skip CanEquipIndex and allow keep action weapons without deleting it
				SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", INVALID_ENT_REFERENCE, i);
				continue;
			}
		}
		
		//Check if weapon is randomizer-generated
		if (!CanEquipIndex(iClient, GetEntProp(g_iInitClassWeapons[i], Prop_Send, "m_iItemDefinitionIndex")))
		{
			SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", INVALID_ENT_REFERENCE, i);
			continue;
		}
		
		//If we reached here, TF2 can manage this weapon, forget weapon in the list when readding later
		g_iInitClassWeapons[i] = INVALID_ENT_REFERENCE;
	}
	
	//ValidateWearables validates both wearable weapons and cosmetics, avoid having it destroyed by disguising as disguise weapon
	int iWearableCount = TF2_GetWearableCount(iClient);
	for (int i = 0; i < iWearableCount; i++)
	{
		int iWearable = TF2_GetWearable(iClient, i);
		if (iWearable == INVALID_ENT_REFERENCE || GetEntData(iWearable, g_iOffsetAlwaysAllow, 1))	//TF2 already planning not to delete this
			continue;
		
		int iIndex = GetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex");
		
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
			
			bool bAllow;
			if (LoadoutSlot_Primary <= iSlot <= LoadoutSlot_PDA2 && Group_IsClientRandomized(iClient, RandomizedType_Weapons))
				bAllow = true;
			else if (iSlot == LoadoutSlot_Misc && Group_IsClientRandomized(iClient, RandomizedType_Cosmetics))
				bAllow = true;
			
			if (bAllow)
			{
				SetEntData(iWearable, g_iOffsetAlwaysAllow, true, 1);
				
				if (!g_aAllowWearables)
					g_aAllowWearables = new ArrayList();
				
				g_aAllowWearables.Push(iWearable);
			}
			
			if (iSlot != -1)
				break;
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_InitClassPost(int iClient)
{
	for (int i = 0; i < sizeof(g_iInitClassWeapons); i++)
	{
		int iMaxWeapons = GetMaxWeapons();
		for (int j = 0; j < iMaxWeapons; j++)
		{
			//Check if TF2 didn't generated a new weapon in this position
			if (GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", j) == INVALID_ENT_REFERENCE)
			{
				SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", g_iInitClassWeapons[i], j);
				break;
			}
		}
		
		g_iInitClassWeapons[i] = INVALID_ENT_REFERENCE;
		
		if (g_iInitClassWeapons[i] != INVALID_ENT_REFERENCE)
			Properties_SetWeaponPropInt(g_iInitClassWeapons[i], "m_iAmmo", 0);
	}
	
	if (g_aAllowWearables)
	{
		int iLength = g_aAllowWearables.Length;
		for (int i = 0; i < iLength; i++)
			SetEntData(g_aAllowWearables.Get(i), g_iOffsetAlwaysAllow, false, 1);
		
		delete g_aAllowWearables;
	}
	
	//Make sure active weapon is still the same and not switched in a buggy way, e.g. quick-fix overheal
	if (IsValidEntity(g_iInitClassActiveWeapon))
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", g_iInitClassActiveWeapon);
	
	//Also messed up huds because of m_hMyWeapons
	Huds_RefreshClient(iClient);
	
	g_bInitClass = false;
	return MRES_Ignored;
}

public MRESReturn DHook_TakeHealthPre(int iClient, DHookReturn hReturn, DHookParam hParams)
{
	// We dont want randomizer's class changes with different max health to affect here
	SetClientClassOriginal(iClient);
	
	if (g_bApplyBiteEffectsChocolate[iClient]) 
	{
		hParams.Set(2, DMG_GENERIC);
		return MRES_ChangedHandled;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_TakeHealthPost(int iClient, DHookReturn hReturn, DHookParam hParams)
{
	RevertClientClass(iClient);
	return MRES_Ignored;
}

public MRESReturn DHook_CheckBlockBackstabPre(int iClient, DHookReturn hReturn, DHookParam hParams)
{
	if (TF2_IsPlayerInCondition(iClient, TFCond_RuneResist))
		return MRES_Ignored;	//Let TF2 handle it, even though there nothing here
	
	//Check each razorback and only break one if available
	int iWeapon, iPos;
	while (TF2_GetItemFromAttribute(iClient, "set_blockbackstab_once", iWeapon, iPos))
	{
		if (Properties_GetWeaponPropFloat(iWeapon, "m_flItemChargeMeter") < 100.0)
			continue;
		
		Properties_SetWeaponPropFloat(iWeapon, "m_flItemChargeMeter", 0.0);
		
		//CTFWearable::Break
		BfWrite bf = UserMessageToBfWrite(StartMessageAll("BreakModel"));
		bf.WriteShort(GetEntProp(iWeapon, Prop_Send, "m_nModelIndex"));
		
		//Not the correct method from weapon GetAbsOrigin & GetAbsAngles but eh
		float vecOrigin[3], vecAngles[3];
		GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", vecOrigin);
		GetEntPropVector(iClient, Prop_Send, "m_angRotation", vecAngles);
		bf.WriteVecCoord(vecOrigin);
		bf.WriteAngles(vecAngles);
		
		bf.WriteShort(GetEntProp(iWeapon, Prop_Send, "m_nSkin"));
		EndMessage();
		
		SetEntProp(iWeapon, Prop_Send, "m_fEffects", GetEntProp(iWeapon, Prop_Send, "m_fEffects")|EF_NODRAW);
		
		hReturn.Value = true;
		return MRES_Supercede;
	}
	
	hReturn.Value = false;
	return MRES_Supercede;
}

public MRESReturn DHook_CanPickupBuildingPost(int iClient, DHookReturn hReturn, DHookParam hParams)
{
	if (hReturn.Value)
	{
		//Can client actually switch away from active weapon?
		// spinning Minigun and charging Cow Mangler doesn't want to get switched away
		int iBuilder, iPos;
		if (TF2_GetItemFromClassname(iClient, "tf_weapon_pda_engineer_build", iBuilder, iPos))
		{
			//Should really be switching to tf_weapon_builder instead of tf_weapon_pda_engineer_build, but tf_weapon_builder is a hacky weapon
			TF2_SwitchToWeapon(iClient, iBuilder);
			if (GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") == iBuilder)
				return MRES_Ignored;	//Yes, can switch
		}
		
		//No we cant
		hReturn.Value = false;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_DropRunePre(int iClient, DHookParam hParams)
{
	if (Group_IsClientRandomized(iClient, RandomizedType_Rune))
		return MRES_Supercede;
	
	return MRES_Ignored;
}

public MRESReturn DHook_FrameUpdatePostEntityThinkPre()
{
	//This function call all clients to reduce medigun charge from medic class check
	Patch_EnableIsPlayerClass();
	return MRES_Ignored;
}

public MRESReturn DHook_FrameUpdatePostEntityThinkPost()
{
	Patch_DisableIsPlayerClass();
	return MRES_Ignored;
}