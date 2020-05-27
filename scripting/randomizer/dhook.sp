enum struct Detour
{
	char sName[64];
	Handle hDetour;
	DHookCallback callbackPre;
	DHookCallback callbackPost;
}

static ArrayList g_aDHookDetours;
static ArrayList g_aDHookVirtuals;

static Handle g_hDHookGiveAmmo;
static Handle g_hDHookSecondaryAttack;
static Handle g_hDHookPipebombTouch;
static Handle g_hDHookOnDecapitation;
static Handle g_hDHookCanBeUpgraded;
static Handle g_hDHookGiveNamedItem;
static Handle g_hDHookFrameUpdatePostEntityThink;

static bool g_bSkipHandleRageGain;
static int g_iClientGetChargeEffectBeingProvided;

static bool g_bHookGiveNamedItem[TF_MAXPLAYERS];
static bool g_bDoClassSpecialSkill[TF_MAXPLAYERS];

public void DHook_Init(GameData hGameData)
{
	g_aDHookDetours = new ArrayList(sizeof(Detour));
	g_aDHookVirtuals = new ArrayList();
	
	DHook_CreateDetour(hGameData, "CTFPlayer::GetMaxAmmo", DHook_GetMaxAmmoPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::Taunt", DHook_TauntPre, DHook_TauntPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::CanAirDash", DHook_CanAirDashPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::ValidateWeapons", DHook_ValidateWeaponsPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::ManageBuilderWeapons", DHook_ManageBuilderWeaponsPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::DoClassSpecialSkill", DHook_DoClassSpecialSkillPre, DHook_DoClassSpecialSkillPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetChargeEffectBeingProvided", DHook_GetChargeEffectBeingProvidedPre, DHook_GetChargeEffectBeingProvidedPost);
	DHook_CreateDetour(hGameData, "CTFPlayer::IsPlayerClass", DHook_IsPlayerClassPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayer::GetEntityForLoadoutSlot", DHook_GetEntityForLoadoutSlotPre, _);
	DHook_CreateDetour(hGameData, "CTFPlayerClassShared::CanBuildObject", DHook_CanBuildObjectPre, _);
	DHook_CreateDetour(hGameData, "CTFGameStats::Event_PlayerFiredWeapon", DHook_PlayerFiredWeaponPre, _);
	DHook_CreateDetour(hGameData, "HandleRageGain", DHook_HandleRageGainPre, _);
	
	g_hDHookGiveAmmo = DHook_CreateVirtual(hGameData, "CBaseCombatCharacter::GiveAmmo");
	g_hDHookSecondaryAttack = DHook_CreateVirtual(hGameData, "CBaseCombatWeapon::SecondaryAttack");
	g_hDHookPipebombTouch = DHook_CreateVirtual(hGameData, "CTFGrenadePipebombProjectile::PipebombTouch");
	g_hDHookOnDecapitation = DHook_CreateVirtual(hGameData, "CTFDecapitationMeleeWeaponBase::OnDecapitation");
	g_hDHookCanBeUpgraded = DHook_CreateVirtual(hGameData, "CBaseObject::CanBeUpgraded");
	g_hDHookGiveNamedItem = DHook_CreateVirtual(hGameData, "CTFPlayer::GiveNamedItem");
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

void DHook_HookClient(int iClient)
{
	DHook_HookVirtualEntity(g_hDHookGiveAmmo, iClient, DHook_GiveAmmoPre, _);
	DHook_HookGiveNamedItem(iClient);
}

void DHook_HookGiveNamedItem(int iClient)
{
	if (g_hDHookGiveNamedItem && !g_bTF2Items)
	{
		DHook_HookVirtualEntity(g_hDHookGiveNamedItem, iClient, DHook_GiveNamedItemPre, _);
		g_bHookGiveNamedItem[iClient] = true;
	}
}

bool DHook_IsGiveNamedItemActive()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (g_bHookGiveNamedItem[iClient])
			return true;
	
	return false;
}

void DHook_ClientDisconnect(int iClient)
{
	g_bHookGiveNamedItem[iClient] = false;
}

void DHook_HookEntity(int iEntity, const char[] sClassname)
{
	if (StrContains(sClassname, "tf_weapon_") == 0)
		DHook_HookVirtualEntity(g_hDHookSecondaryAttack, iEntity, _, DHook_SecondaryWeaponPost);
	
	if (StrEqual(sClassname, "tf_projectile_stun_ball") || StrEqual(sClassname, "tf_projectile_ball_ornament"))
		DHook_HookVirtualEntity(g_hDHookPipebombTouch, iEntity, DHook_PipebombTouchPre, DHook_PipebombTouchPost);
	else if (StrEqual(sClassname, "tf_weapon_sword"))
		DHook_HookVirtualEntity(g_hDHookOnDecapitation, iEntity, DHook_OnDecapitationPre, DHook_OnDecapitationPost);
	else if (StrContains(sClassname, "obj_") == 0)
		DHook_HookVirtualEntity(g_hDHookCanBeUpgraded, iEntity, DHook_CanBeUpgradedPre, DHook_CanBeUpgradedPost);
}

void DHook_HookGamerules()
{
	DHook_HookVirtualGamerules(g_hDHookFrameUpdatePostEntityThink, DHook_FrameUpdatePostEntityThinkPre, DHook_FrameUpdatePostEntityThinkPost);
}

void DHook_HookVirtualEntity(Handle hVirtual, int iEntity, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	if (callbackPre != INVALID_FUNCTION)
		g_aDHookVirtuals.Push(DHookEntity(hVirtual, false, iEntity, DHook_UnhookVirtual, callbackPre));
	
	if (callbackPost != INVALID_FUNCTION)
		g_aDHookVirtuals.Push(DHookEntity(hVirtual, true, iEntity, DHook_UnhookVirtual, callbackPost));
}

void DHook_HookVirtualGamerules(Handle hVirtual, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	if (callbackPre != INVALID_FUNCTION)
		g_aDHookVirtuals.Push(DHookGamerules(hVirtual, false, DHook_UnhookVirtual, callbackPre));
	
	if (callbackPost != INVALID_FUNCTION)
		g_aDHookVirtuals.Push(DHookGamerules(hVirtual, true, DHook_UnhookVirtual, callbackPost));
}

public void DHook_UnhookVirtual(int iHookId)
{
	int iPos = g_aDHookVirtuals.FindValue(iHookId);
	if (iPos >= 0)
		g_aDHookVirtuals.Erase(iPos);
}

void DHook_UnhookVirtualAll()
{
	int iLength = g_aDHookVirtuals.Length;
	for (int i = iLength - 1; i >= 0; i--)
		DHookRemoveHookID(g_aDHookVirtuals.Get(i));
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
	if (iWeapon > MaxClients && TF2_WeaponFindAttribute(iWeapon, ATTRIB_AIR_DASH_COUNT, flVal) && iAirDash < RoundToNearest(flVal))
	{
		SetEntProp(iClient, Prop_Send, "m_iAirDash", iAirDash + 1);
		DHookSetReturn(hReturn, true);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_ValidateWeaponsPre(int iClient, Handle hParams)
{
	//Dont validate any weapons, TF2 attempting to remove randomizer weapon for player's TF2 loadout,
	// however need to manually call WeaponReset virtual so randomizer weapons get restored back to what it was
	int iWeapon;
	int iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		char sClassname[256];
		GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
		if (StrContains(sClassname, "tf_weapon_") == 0)
			SDKCall_WeaponReset(iWeapon);
	}
	
	return MRES_Supercede;
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
	bool bAllowAttack2 = true;
	
	int iWeapon;
	int iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		if (Controls_IsPassiveInCooldown(iClient, iWeapon))
			continue;
		
		int iButton = Controls_GetPassiveButtonBit(iClient, iWeapon, bAllowAttack2);
		if (iButton > 0 && iButtons & iButton)
		{
			Controls_OnPassiveUse(iClient, iWeapon);
			TF2_SetPlayerClass(iClient, TF2_GetDefaultClassFromItem(iClient, iWeapon));
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
	if (IsClientInGame(iClient))
	{
		//Has medic class check for getting uber types
		TF2_SetPlayerClass(iClient, TFClass_Medic);
		g_iClientGetChargeEffectBeingProvided = iClient;
	}
}

public MRESReturn DHook_GetChargeEffectBeingProvidedPost(int iClient, Handle hReturn)
{
	// iClient is a lie in this detour
	if (g_iClientGetChargeEffectBeingProvided)
		TF2_SetPlayerClass(g_iClientGetChargeEffectBeingProvided, g_iClientClass[g_iClientGetChargeEffectBeingProvided]);
	
	g_iClientGetChargeEffectBeingProvided = 0;
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

public MRESReturn DHook_PlayerFiredWeaponPre(Address pGameStats, Handle hParams)
{
	//Not all weapons remove disguise
	int iClient = DHookGetParam(hParams, 1);
	
	if (TF2_IsPlayerInCondition(iClient, TFCond_Disguising))
		TF2_RemoveCondition(iClient, TFCond_Disguising);
	
	if (TF2_IsPlayerInCondition(iClient, TFCond_Disguised))
		TF2_RemoveCondition(iClient, TFCond_Disguised);
}

public MRESReturn DHook_HandleRageGainPre(Handle hParams)
{
	//Banners, Phlogistinator and Hitman Heatmaker use m_flRageMeter with class check, call this function to each weapons
	//Must be called a frame, will crash if detour is called while inside a detour
	//TODO somehow make multiple m_flRageMeter to seperate each ones
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
		TFClassType nClass = TF2_GetDefaultClassFromItem(iClient, iWeapon);
		if (bCalledClass[nClass])	//Already called as same class, dont double value
			continue;
		
		bCalledClass[nClass] = true;
		
		TF2_SetPlayerClass(iClient, nClass);
		SDKCall_HandleRageGain(iClient, iRequiredBuffFlags, flDamage, fInverseRageGainScale);
	}
	
	TF2_SetPlayerClass(iClient, g_iClientClass[iClient]);
	g_bSkipHandleRageGain = false;
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
	TF2_SetPlayerClass(iClient, TF2_GetDefaultClassFromItem(iClient, iSword));
}

public MRESReturn DHook_OnDecapitationPost(int iSword, Handle hParams)
{
	int iClient = GetEntPropEnt(iSword, Prop_Send, "m_hOwnerEntity");
	TF2_SetPlayerClass(iClient, g_iClientClass[iClient]);
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