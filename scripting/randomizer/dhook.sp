enum struct Detour
{
	char sName[64];
	Handle hDetour;
	DHookCallback callbackPre;
	DHookCallback callbackPost;
}

static ArrayList g_aDHookDetours;

static Handle g_hDHookSecondaryAttack;
static Handle g_hDHookGetEffectBarAmmo;
static Handle g_hDHookSwing;
static Handle g_hDHookMyTouch;
static Handle g_hDHookPipebombTouch;
static Handle g_hDHookOnDecapitation;
static Handle g_hDHookKilled;
static Handle g_hDHookCanBeUpgraded;
static Handle g_hDHookForceRespawn;
static Handle g_hDHookEquipWearable;
static Handle g_hDHookGetAmmoCount;
static Handle g_hDHookGiveNamedItem;
static Handle g_hDHookClientCommand;
static Handle g_hDHookFrameUpdatePostEntityThink;

static bool g_bSkipGetMaxAmmo;
static int g_iClientGetChargeEffectBeingProvided;
static int g_iWeaponGetLoadoutItem = INVALID_ENT_REFERENCE;
static bool g_bManageBuilderWeapons;
static ArrayList g_aValidateWearables;
static bool g_bValidateWearablesDisguised;
static int g_iBuildingKilledSapper = INVALID_ENT_REFERENCE;

static int g_iHookIdGiveNamedItem[TF_MAXPLAYERS];
static int g_iHookIdClientCommand[TF_MAXPLAYERS];
static int g_iHookIdForceRespawnPre[TF_MAXPLAYERS];
static int g_iHookIdForceRespawnPost[TF_MAXPLAYERS];
static int g_iHookIdEquipWearable[TF_MAXPLAYERS];
static int g_iHookIdGetAmmoCount[TF_MAXPLAYERS];
static bool g_bDoClassSpecialSkill[TF_MAXPLAYERS];
static bool g_bApplyBiteEffectsChocolate[TF_MAXPLAYERS];

static int g_iDHookGamerulesPre;
static int g_iDHookGamerulesPost;

public void DHook_Init(GameData hGameData)
{
	g_aDHookDetours = new ArrayList(sizeof(Detour));
	
	DHook_CreateDetour(hGameData, "CTFPlayer::GiveAmmo", DHook_GiveAmmoPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetMaxAmmo", DHook_GetMaxAmmoPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::Taunt", DHook_TauntPre, DHook_TauntPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::CanAirDash", DHook_CanAirDashPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::ValidateWeapons", DHook_ValidateWeaponsPre, DHook_ValidateWeaponsPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::ValidateWearables", DHook_ValidateWearablesPre, DHook_ValidateWearablesPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::ManageBuilderWeapons", DHook_ManageBuilderWeaponsPre, DHook_ManageBuilderWeaponsPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::DoClassSpecialSkill", DHook_DoClassSpecialSkillPre, DHook_DoClassSpecialSkillPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::EndClassSpecialSkill", DHook_EndClassSpecialSkillPre, DHook_EndClassSpecialSkillPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetChargeEffectBeingProvided", DHook_GetChargeEffectBeingProvidedPre, DHook_GetChargeEffectBeingProvidedPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::IsPlayerClass", DHook_IsPlayerClassPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetLoadoutItem", DHook_GetLoadoutItemPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetEntityForLoadoutSlot", DHook_GetEntityForLoadoutSlotPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetMaxHealthForBuffing", DHook_GetMaxHealthForBuffingPre, DHook_GetMaxHealthForBuffingPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::TeamFortress_CalculateMaxSpeed", DHook_CalculateMaxSpeedPre, DHook_CalculateMaxSpeedPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::TakeHealth", DHook_TakeHealthPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::CheckBlockBackstab", DHook_CheckBlockBackstabPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::CanPickupBuilding", _, DHook_CanPickupBuildingPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::DropRune", DHook_DropRunePre, _);
	DHook_CreateDetour(hGameData, "CTFPlayerClassShared::CanBuildObject", DHook_CanBuildObjectPre, _);
	DHook_CreateDetour(hGameData, "CTFKnife::DisguiseOnKill", DHook_DisguiseOnKillPre, DHook_DisguiseOnKillPost);
	DHook_CreateDetour(hGameData, "CTFLunchBox::ApplyBiteEffects", DHook_ApplyBiteEffectsPre, DHook_ApplyBiteEffectsPost);
	DHook_CreateDetour(hGameData, "CTFGameStats::Event_PlayerFiredWeapon", DHook_PlayerFiredWeaponPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayerShared::UpdateRageBuffsAndRage", DHook_UpdateRageBuffsAndRagePre, _);
	DHook_CreateDetour(hGameData, "CTFPlayerShared::ModifyRage", DHook_ModifyRagePre, _);
	DHook_CreateDetour(hGameData, "CTFPlayerShared::ActivateRageBuff", DHook_ActivateRageBuffPre, DHook_ActivateRageBuffPost);
	DHook_CreateDetour(hGameData, "HandleRageGain", DHook_HandleRageGainPre, _);
	
	g_hDHookSecondaryAttack = DHook_CreateVirtual(hGameData, "CBaseCombatWeapon::SecondaryAttack");
	g_hDHookGetEffectBarAmmo = DHook_CreateVirtual(hGameData, "CTFWeaponBase::GetEffectBarAmmo");
	g_hDHookSwing = DHook_CreateVirtual(hGameData, "CTFWeaponBaseMelee::Swing");
	g_hDHookMyTouch = DHook_CreateVirtual(hGameData, "CItem::MyTouch");
	g_hDHookPipebombTouch = DHook_CreateVirtual(hGameData, "CTFGrenadePipebombProjectile::PipebombTouch");
	g_hDHookOnDecapitation = DHook_CreateVirtual(hGameData, "CTFDecapitationMeleeWeaponBase::OnDecapitation");
	g_hDHookKilled = DHook_CreateVirtual(hGameData, "CBaseObject::Killed");
	g_hDHookCanBeUpgraded = DHook_CreateVirtual(hGameData, "CBaseObject::CanBeUpgraded");
	g_hDHookForceRespawn = DHook_CreateVirtual(hGameData, "CBasePlayer::ForceRespawn");
	g_hDHookEquipWearable = DHook_CreateVirtual(hGameData, "CBasePlayer::EquipWearable");
	g_hDHookGetAmmoCount = DHook_CreateVirtual(hGameData, "CBaseCombatCharacter::GetAmmoCount");
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
	g_iHookIdForceRespawnPre[iClient] = DHookEntity(g_hDHookForceRespawn, false, iClient, _, DHook_ForceRespawnPre);
	g_iHookIdForceRespawnPost[iClient] = DHookEntity(g_hDHookForceRespawn, true, iClient, _, DHook_ForceRespawnPost);
	g_iHookIdEquipWearable[iClient] = DHookEntity(g_hDHookEquipWearable, true, iClient, _, DHook_EquipWearablePost);
	g_iHookIdGetAmmoCount[iClient] = DHookEntity(g_hDHookGetAmmoCount, false, iClient, _, DHook_GetAmmoCountPre);
	g_iHookIdClientCommand[iClient] = DHookEntity(g_hDHookClientCommand, true, iClient, _, DHook_ClientCommandPost);
}

void DHook_UnhookClient(int iClient)
{
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
	
	if (g_iHookIdGetAmmoCount[iClient])
	{
		DHookRemoveHookID(g_iHookIdGetAmmoCount[iClient]);
		g_iHookIdGetAmmoCount[iClient] = 0;	
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
		DHookEntity(g_hDHookGetEffectBarAmmo, true, iEntity, _, DHook_GetEffectBarAmmoPost);
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
	else if (StrContains(sClassname, "obj_") == 0 && !StrEqual(sClassname, "obj_attachment_sapper"))
	{
		DHookEntity(g_hDHookKilled, false, iEntity, _, DHook_KilledPre);
		DHookEntity(g_hDHookKilled, true, iEntity, _, DHook_KilledPost);
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

public MRESReturn DHook_GiveAmmoPre(int iClient, Handle hReturn, Handle hParams)
{
	//Detour is used instead of virtual because non-virtual CTFPlayer::GiveAmmo directly calls CBaseCombatCharacter::GiveAmmo in non-virtual way
	int iForceWeapon = Properties_GetForceWeaponAmmo();
	if (iForceWeapon != INVALID_ENT_REFERENCE)
		Properties_ResetForceWeaponAmmo();
	
	if (g_bSkipGetMaxAmmo)
		return MRES_Ignored;
	
	int iCount = DHookGetParam(hParams, 1);
	if (iCount <= 0)
		return MRES_Ignored;
	
	int iAmmoType = DHookGetParam(hParams, 2);
	if (iAmmoType == TF_AMMO_METAL)	//Nothing fancy for metal
		return MRES_Ignored;
	
	bool bSuppressSound = DHookGetParam(hParams, 3);
	EAmmoSource eAmmoSource = DHookGetParam(hParams, 4);
	
	Properties_SaveActiveWeaponAmmo(iClient);
	g_bSkipGetMaxAmmo = true;
	
	int iTotalAdded;
	
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
				iAdd = RoundToFloor(float(iCount) / float(DEFAULT_MAX_AMMO) * float(iMaxAmmo));	//based from DEFAULT_MAX_AMMO at GetMaxAmmo
			
			int iCurrent = Properties_GetWeaponPropInt(iWeapon, "m_iAmmo");
			iAdd = TF2_GiveAmmo(iClient, iWeapon, iCurrent, iAdd, iAmmoType, bSuppressSound, eAmmoSource);
			Properties_SetWeaponPropInt(iWeapon, "m_iAmmo", iCurrent + iAdd);
			iTotalAdded += iAdd;
		}
	}
	
	//Set ammo back to what it was for active weapon
	Properties_UpdateActiveWeaponAmmo(iClient);
	
	g_bSkipGetMaxAmmo = false;
	
	DHookSetReturn(hReturn, iTotalAdded);
	return MRES_Supercede;
}

public MRESReturn DHook_GetMaxAmmoPre(int iClient, Handle hReturn, Handle hParams)
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
		DHookSetParam(hParams, 2, TF2_GetDefaultClassFromItem(iWeapon));
		return MRES_ChangedHandled;
	}
	
	if (DHookGetParam(hParams, 1) == TF_AMMO_METAL)
	{
		//Engineer have max metal 200 while others have 100
		DHookSetParam(hParams, 2, TFClass_Engineer);
		return MRES_ChangedHandled;
	}
	
	DHookSetReturn(hReturn, DEFAULT_MAX_AMMO);
	return MRES_Supercede;
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

public MRESReturn DHook_ValidateWearablesPre(int iClient, Handle hParams)
{
	//This function validates both wearable weapons and cosmetics, avoid having it destroyed by disguising as disguise weapon
	int iWearable;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable*")) > MaxClients)
	{
		if (GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity") == iClient)
		{
			int iIndex = GetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex");
			for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
			{
				int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
				
				bool bDisguise;
				if (LoadoutSlot_Primary <= iSlot <= LoadoutSlot_PDA2 && Group_IsClientRandomized(iClient, RandomizedType_Weapons))
					bDisguise = true;
				else if (iSlot == LoadoutSlot_Misc && Group_IsClientRandomized(iClient, RandomizedType_Cosmetics))
					bDisguise = true;
				
				if (bDisguise && !GetEntProp(iWearable, Prop_Send, "m_bDisguiseWearable"))
				{
					SetEntProp(iWearable, Prop_Send, "m_bDisguiseWearable", true);
					
					if (!g_aValidateWearables)
						g_aValidateWearables = new ArrayList();
					
					g_aValidateWearables.Push(iWearable);
				}
				
				if (iSlot != -1)
					break;
			}
		}
	}
	
	if (g_aValidateWearables)
	{
		SetClientClass(iClient, TFClass_Spy);
		
		if (!TF2_IsPlayerInCondition(iClient, TFCond_Disguised))
		{
			TF2_AddConditionFake(iClient, TFCond_Disguised);
			g_bValidateWearablesDisguised = true;
		}
	}
}

public MRESReturn DHook_ValidateWearablesPost(int iClient, Handle hParams)
{
	if (!g_aValidateWearables)
		return;
	
	int iLength = g_aValidateWearables.Length;
	for (int i = 0; i < iLength; i++)
		SetEntProp(g_aValidateWearables.Get(i), Prop_Send, "m_bDisguiseWearable", false);
	
	delete g_aValidateWearables;
	
	RevertClientClass(iClient);
	
	if (g_bValidateWearablesDisguised)
		TF2_RemoveConditionFake(iClient, TFCond_Disguised);
	
	g_bValidateWearablesDisguised = false;
}

public MRESReturn DHook_ManageBuilderWeaponsPre(int iClient, Handle hParams)
{
	if (Group_IsClientRandomized(iClient, RandomizedType_Weapons))
		return MRES_Supercede;	//Don't do anything, we'll handle it
	
	g_bManageBuilderWeapons = true;
	return MRES_Ignored;
}

public MRESReturn DHook_ManageBuilderWeaponsPost(int iClient, Handle hParams)
{
	g_bManageBuilderWeapons = false;
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
		if (!Controls_CanUse(iClient, iWeapon))
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
	if (g_iWeaponGetLoadoutItem == -1 || !Group_IsClientRandomized(iClient, RandomizedType_Weapons))	//not inside ValidateWeapons
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
	SetClientClass(iClient, TF2_GetDefaultClassFromItem(iWeapon));
	
	DHookSetReturn(hReturn, GetEntityAddress(iWeapon) + view_as<Address>(GetEntSendPropOffs(iWeapon, "m_Item", true)));
	return MRES_Supercede;
}

public MRESReturn DHook_GetEntityForLoadoutSlotPre(int iClient, Handle hReturn, Handle hParams)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return MRES_Ignored;
	
	int iSlot = DHookGetParam(hParams, 1);
	if (iSlot < 0 || iSlot > WeaponSlot_Building)
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

public MRESReturn DHook_GetMaxHealthForBuffingPre(int iClient, Handle hReturn)
{
	if (g_bWeaponDecap[iClient])
		return;
	
	//Set decap to any eyelanders, all should have same value
	int iWeapon, iPos;
	if (TF2_GetItemFromClassname(iClient, "tf_weapon_sword", iWeapon, iPos))
		Properties_LoadWeaponPropInt(iClient, iWeapon, "m_iDecapitations");
}

public MRESReturn DHook_GetMaxHealthForBuffingPost(int iClient, Handle hReturn)
{
	if (g_bWeaponDecap[iClient])
		return;
	
	//Set back to active weapon
	Properties_LoadActiveWeaponPropInt(iClient, "m_iDecapitations");
}

public MRESReturn DHook_CalculateMaxSpeedPre(int iClient, Handle hReturn, Handle hParams)
{
	if (!IsClientInGame(iClient) || g_bWeaponDecap[iClient])	//IsClientInGame check is needed, weird game
		return;
	
	//Set decap to any eyelanders, all should have same value
	int iWeapon, iPos;
	if (TF2_GetItemFromClassname(iClient, "tf_weapon_sword", iWeapon, iPos))
		Properties_LoadWeaponPropInt(iClient, iWeapon, "m_iDecapitations");
}

public MRESReturn DHook_CalculateMaxSpeedPost(int iClient, Handle hReturn, Handle hParams)
{
	if (!IsClientInGame(iClient) || g_bWeaponDecap[iClient])
		return;
	
	//Set back to active weapon
	Properties_LoadActiveWeaponPropInt(iClient, "m_iDecapitations");
}

public MRESReturn DHook_CanBuildObjectPre(Address pPlayerClassShared, Handle hReturn, Handle hParams)
{
	if (g_bManageBuilderWeapons)
		return MRES_Ignored;	//Do class check if inside CTFPlayer::ManageBuilderWeapons
	
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
	if (g_iGainingRageWeapon != INVALID_ENT_REFERENCE || iClient <= 0 || iClient > MaxClients)
		return MRES_Ignored;
	
	float flRageType = TF2_GetAttributeAdditive(iClient, "mod soldier buff type");
	if (!flRageType) //We don't have any rage items, don't need to do anything
		return MRES_Ignored;
	
	RequestFrame(Properties_UpdateRageBuffsAndRage, iClient);
	return MRES_Supercede;
}

public MRESReturn DHook_ModifyRagePre(Address pPlayerShared, Handle hParams)
{
	int iClient = SDKCall_GetBaseEntity(pPlayerShared - view_as<Address>(g_iOffsetPlayerShared));
	if (iClient && g_iGainingRageWeapon == INVALID_ENT_REFERENCE)
	{
		DataPack hPack = new DataPack();
		hPack.WriteCell(GetClientSerial(iClient));
		hPack.WriteFloat(DHookGetParam(hParams, 1));
		
		RequestFrame(Properties_ModifyRage, hPack);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_ActivateRageBuffPre(Address pPlayerShared, Handle hParams)
{
	int iClient = SDKCall_GetBaseEntity(pPlayerShared - view_as<Address>(g_iOffsetPlayerShared));
	if (!iClient)
		return MRES_Ignored;
	
	//First param is unused, named pBuffItem.
	// But TF2 pass this param as either buff banner or player itself :japanese_goblin:
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon == INVALID_ENT_REFERENCE)
		return MRES_Ignored;
	
	int iBuffType = DHookGetParam(hParams, 2);
	float flClientRageType = TF2_GetAttributeAdditive(iClient, "mod soldier buff type");
	TF2Attrib_SetByName(iClient, "mod soldier buff type", float(iBuffType) - flClientRageType);
	
	Properties_LoadRageProps(iClient, iWeapon);
	return MRES_Ignored;
}

public MRESReturn DHook_ActivateRageBuffPost(Address pPlayerShared, Handle hParams)
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

public MRESReturn DHook_HandleRageGainPre(Handle hParams)
{
	//Banners, Phlogistinator and Hitman Heatmaker use m_flRageMeter with class check, call this function to each weapons
	//Must be called a frame, will crash if detour is called while inside a detour
	if (g_iGainingRageWeapon != INVALID_ENT_REFERENCE || DHookIsNullParam(hParams, 1))
		return MRES_Ignored;
	
	DataPack hPack = new DataPack();
	hPack.WriteCell(GetClientSerial(DHookGetParam(hParams, 1)));
	hPack.WriteCell(DHookGetParam(hParams, 2));
	hPack.WriteFloat(DHookGetParam(hParams, 3));
	hPack.WriteFloat(DHookGetParam(hParams, 4));
	
	RequestFrame(Properties_HandleRageGain, hPack);
	return MRES_Supercede;
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
}

public MRESReturn DHook_GetEffectBarAmmoPost(int iWeapon, Handle hReturn)
{
	//This function is only called for GetAmmoCount, GetMaxAmmo and GiveAmmo
	Properties_SetForceWeaponAmmo(iWeapon);
}

public MRESReturn DHook_MyTouchPre(int iHealthKit, Handle hReturn, Handle hParams)
{
	//Has heavy class check for lunchbox
	int iClient = GetEntPropEnt(iHealthKit, Prop_Send, "m_hOwnerEntity");
	if (0 < iClient <= MaxClients && IsClientInGame(iClient))
		g_iAllowPlayerClass[iClient]++;
}

public MRESReturn DHook_MyTouchPost(int iHealthKit, Handle hReturn, Handle hParams)
{
	int iClient = GetEntPropEnt(iHealthKit, Prop_Send, "m_hOwnerEntity");
	if (0 < iClient <= MaxClients && IsClientInGame(iClient))
		g_iAllowPlayerClass[iClient]--;
}

public MRESReturn DHook_PipebombTouchPre(int iStunBall, Handle hParams)
{
	int iClient = GetEntPropEnt(iStunBall, Prop_Send, "m_hOwnerEntity");
	if (0 < iClient <= MaxClients && IsClientInGame(iClient))
	{
		g_iAllowPlayerClass[iClient]++;	//Has scout class check
		
		if (IsClassname(iStunBall, "tf_projectile_stun_ball"))
		{
			//Find sandman that could pick up this ball
			int iTargetWeapon = INVALID_ENT_REFERENCE;
			float flTargetTime;
			
			int iWeapon, iPos;
			while (TF2_GetItemFromClassname(iClient, "tf_weapon_bat_wood", iWeapon, iPos))
			{
				float flTime = GetEntPropFloat(iWeapon, Prop_Send, "m_flEffectBarRegenTime");
				if (flTime > flTargetTime)
				{
					iTargetWeapon = iWeapon;
					flTargetTime = flTime;
				}
			}
			
			if (iTargetWeapon != INVALID_ENT_REFERENCE)
				Properties_SetForceWeaponAmmo(iTargetWeapon, 1);	//Set priority to 1 so other hooks dont reset it
		}
	}
}

public MRESReturn DHook_PipebombTouchPost(int iStunBall, Handle hParams)
{
	int iClient = GetEntPropEnt(iStunBall, Prop_Send, "m_hOwnerEntity");
	if (0 < iClient <= MaxClients && IsClientInGame(iClient))
	{
		g_iAllowPlayerClass[iClient]--;
		Properties_ResetForceWeaponAmmo(1);
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

public MRESReturn DHook_KilledPre(int iObject)
{
	//There is 1 Param, CTakeDamageInfo ref, but not listed as it gives windows crashes
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
			while (TF2_GetItemFromAttribute(iClient, "mod sentry killed revenge", iTempWeapon, iPos))
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
				while (TF2_GetItemFromAttribute(iAttacker, "sapper kills collect crits", iTempWeapon, iPos))
					Properties_AddWeaponPropInt(iTempWeapon, "m_iRevengeCrits", iCount);
			}
			
			//Set back to active weapon
			Properties_LoadActiveWeaponPropInt(iAttacker, "m_iRevengeCrits");
		}
	}
	
	g_iBuildingKilledSapper = INVALID_ENT_REFERENCE;
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
	//Update incase of changing group
	UpdateClientInfo(iClient);
	
	//Detach client's object so it doesnt get destroyed on class change
	int iBuilding = MaxClients+1;
	while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) > MaxClients)
		if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == iClient)
			SDKCall_RemoveObject(iClient, iBuilding);
	
	if (Group_IsClientRandomized(iClient, RandomizedType_Class))
	{
		TFClassType nClass = g_eClientInfo[iClient].nClass;
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

public MRESReturn DHook_GetAmmoCountPre(int iClient, Handle hReturn, Handle hParams)
{
	int iWeapon = Properties_GetForceWeaponAmmo();
	if (iWeapon != INVALID_ENT_REFERENCE)
	{
		Properties_ResetForceWeaponAmmo();
		DHookSetReturn(hReturn, Properties_GetWeaponPropInt(iWeapon, "m_iAmmo"));
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
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

public MRESReturn DHook_CheckBlockBackstabPre(int iClient, Handle hReturn, Handle hParams)
{
	if (TF2_IsPlayerInCondition(iClient, TFCond_RuneResist))
		return MRES_Ignored;	//Let TF2 handle it, even though there nothing here
	
	//Check each razorback and only break one if available
	int iWeapon, iPos;
	while (TF2_GetItemFromAttribute(iClient, "backstab shield", iWeapon, iPos))
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
		
		DHookSetReturn(hReturn, true);
		return MRES_Supercede;
	}
	
	DHookSetReturn(hReturn, false);
	return MRES_Supercede;
}

public MRESReturn DHook_CanPickupBuildingPost(int iClient, Handle hReturn, Handle hParams)
{
	if (DHookGetReturn(hReturn))
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
		DHookSetReturn(hReturn, false);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_DropRunePre(int iClient, Handle hParams)
{
	//TODO check if client is in randomize mode
	return MRES_Supercede;
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