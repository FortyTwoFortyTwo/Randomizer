static int g_iMedigunBeamRef[MAXPLAYERS] = {INVALID_ENT_REFERENCE, ...};
static int g_iTouchLunchbox = INVALID_ENT_REFERENCE;

void SDKHook_HookClient(int iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamage, Client_OnTakeDamage);
	SDKHook(iClient, SDKHook_OnTakeDamagePost, Client_OnTakeDamagePost);
	SDKHook(iClient, SDKHook_PreThink, Client_PreThink);
	SDKHook(iClient, SDKHook_PreThinkPost, Client_PreThinkPost);
	SDKHook(iClient, SDKHook_PostThink, Client_PostThink);
	SDKHook(iClient, SDKHook_PostThinkPost, Client_PostThinkPost);
	SDKHook(iClient, SDKHook_WeaponEquip, Client_WeaponEquip);
	SDKHook(iClient, SDKHook_WeaponEquipPost, Client_WeaponEquipPost);
	SDKHook(iClient, SDKHook_WeaponSwitch, Client_WeaponSwitch);
	SDKHook(iClient, SDKHook_WeaponSwitchPost, Client_WeaponSwitchPost);
	SDKHook(iClient, SDKHook_WeaponCanSwitchTo, Client_WeaponCanSwitchTo);
	SDKHook(iClient, SDKHook_WeaponCanSwitchToPost, Client_WeaponCanSwitchToPost);
}

void SDKHook_UnhookClient(int iClient)
{
	SDKUnhook(iClient, SDKHook_OnTakeDamage, Client_OnTakeDamage);
	SDKUnhook(iClient, SDKHook_OnTakeDamagePost, Client_OnTakeDamagePost);
	SDKUnhook(iClient, SDKHook_PreThink, Client_PreThink);
	SDKUnhook(iClient, SDKHook_PreThinkPost, Client_PreThinkPost);
	SDKUnhook(iClient, SDKHook_PostThink, Client_PostThink);
	SDKUnhook(iClient, SDKHook_PostThinkPost, Client_PostThinkPost);
	SDKUnhook(iClient, SDKHook_WeaponEquip, Client_WeaponEquip);
	SDKUnhook(iClient, SDKHook_WeaponEquipPost, Client_WeaponEquipPost);
	SDKUnhook(iClient, SDKHook_WeaponSwitch, Client_WeaponSwitch);
	SDKUnhook(iClient, SDKHook_WeaponSwitchPost, Client_WeaponSwitchPost);
	SDKUnhook(iClient, SDKHook_WeaponCanSwitchTo, Client_WeaponCanSwitchTo);
	SDKUnhook(iClient, SDKHook_WeaponCanSwitchToPost, Client_WeaponCanSwitchToPost);
}

void SDKHook_OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (StrContains(sClassname, "tf_weapon_") == 0)
		SDKHook(iEntity, SDKHook_Reload, Weapon_Reload);
	else if (StrEqual(sClassname, "item_healthkit_small"))
		SDKHook(iEntity, SDKHook_SpawnPost, HealthKit_SpawnPost);
	
	if (StrContains(sClassname, "item_healthkit") == 0 || StrEqual(sClassname, "tf_projectile_stun_ball") || StrEqual(sClassname, "tf_projectile_ball_ornament"))
	{
		SDKHook(iEntity, SDKHook_Touch, Item_Touch);
		SDKHook(iEntity, SDKHook_TouchPost, Item_TouchPost);
	}
}

public Action Client_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &flDamage, int &iDamageType, int &iWeapon, float vecDamageForce[3], float vecDamagePosition[3], int iDamageCustom)
{
	//Enable IsPlayerClass patch at ApplyOnDamageModifyRules detour,
	// so proper soldier/demoman class check can be done for rocket jumping,
	// before ApplyOnDamageModifyRules detour is called
	g_bOnTakeDamage = true;
	
	if (0 < iAttacker <= MaxClients)
	{
		if (iWeapon != INVALID_ENT_REFERENCE && HasEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"))	// iWeapon is not always actually a weapon
		{
			//Set attacker class to whatever default class from weapon,
			// IsPlayerClass not always called on linux,
			// and some class checks don't even use IsPlayerClass.
			SetClientClass(iAttacker, TF2_GetDefaultClassFromItem(iWeapon));
			g_bOnTakeDamageClass = true;
			
			Properties_LoadWeaponPropInt(iAttacker, iWeapon, "m_iDecapitations");
			g_bWeaponDecap[iAttacker] = true;
		}
		
		//Setup collecting revenge crits for diamondback
		Properties_SaveActiveWeaponPropInt(iAttacker, "m_iRevengeCrits");
		SetEntProp(iAttacker, Prop_Send, "m_iRevengeCrits", 0);
	}
	
	return Plugin_Continue;
}

public void Client_OnTakeDamagePost(int iVictim, int iAttacker, int iInflictor, float flDamage, int iDamageType, int iWeapon, const float vecDamageForce[3], const float vecDamagePosition[3], int iDamageCustom)
{
	if (!g_bOnTakeDamage)
		Patch_DisableIsPlayerClass();
	
	g_bOnTakeDamage = false;
	g_bFeignDeath[iVictim] = false;
	
	if (g_bOnTakeDamageClass)
	{
		RevertClientClass(iAttacker);
		g_bOnTakeDamageClass = false;
	}
	
	if (0 < iAttacker <= MaxClients)
	{
		if (iWeapon != INVALID_ENT_REFERENCE && HasEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"))
		{
			Properties_SaveWeaponPropInt(iAttacker, iWeapon, "m_iDecapitations");
			g_bWeaponDecap[iAttacker] = false;
			
			if (IsClassname(iWeapon, "tf_weapon_sword"))
			{
				//Set same value to all eyelanders
				int iDecap = Properties_GetWeaponPropInt(iWeapon, "m_iDecapitations");
				
				int iTempWeapon, iPos;
				while (TF2_GetItemFromClassname(iAttacker, "tf_weapon_sword", iTempWeapon, iPos))
					Properties_SetWeaponPropInt(iTempWeapon, "m_iDecapitations", iDecap);
			}
		}
		
		int iRevengeCrits = GetEntProp(iAttacker, Prop_Send, "m_iRevengeCrits");
		if (iRevengeCrits > 0)
		{
			//Add revenge crit to all diamondbacks
			int iTempWeapon, iPos;
			while (TF2_GetItemFromAttribute(iAttacker, "sapper_kills_collect_crits", iTempWeapon, iPos))	//This is not a sapper kill...
				Properties_AddWeaponPropInt(iTempWeapon, "m_iRevengeCrits", iRevengeCrits);
		}
		
		//Set it back
		Properties_LoadActiveWeaponPropInt(iAttacker, "m_iRevengeCrits");
	}
}

public void Client_PreThink(int iClient)
{
	//Make sure player cant use primary or secondary attack while cloaked
	if (TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
	{
		int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
		if (iWeapon > MaxClients)
		{
			float flGameTime = GetGameTime();
			if (GetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack") - 0.5 < flGameTime)
				SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", flGameTime + 0.5);
			
			if (GetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack") - 0.5 < flGameTime)
				SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", flGameTime + 0.5);
		}
	}
	
	//PreThink have way too many IsPlayerClass check, always return true during it
	Patch_EnableIsPlayerClass();
	
	int iWeapon, iPos;
	if (TF2_GetItemFromClassname(iClient, "tf_weapon_soda_popper", iWeapon, iPos))
	{
		Properties_LoadWeaponPropFloat(iClient, iWeapon, "m_flHypeMeter");
		g_iHypeMeterLoaded[iClient] = iWeapon;
	}
	
	// Medigun beams doesnt show if player is not medic, and we can't fix that in SDK because it all in clientside
	if (TF2_GetPlayerClass(iClient) == TFClass_Medic)
		return;
	
	static char sParticle[][] = {
		"",
		"",
		PARTICLE_BEAM_RED,
		PARTICLE_BEAM_BLU,
	};
	
	iWeapon = INVALID_ENT_REFERENCE, iPos = 0;
	while (TF2_GetItemFromClassname(iClient, "tf_weapon_medigun", iWeapon, iPos))
	{
		if (!IsValidEntity(g_iMedigunBeamRef[iClient]))
			g_iMedigunBeamRef[iClient] = TF2_SpawnParticle(sParticle[TF2_GetClientTeam(iClient)], iWeapon);
		
		int iPatient = GetEntPropEnt(iWeapon, Prop_Send, "m_hHealingTarget");
		int iControlPoint = GetEntPropEnt(g_iMedigunBeamRef[iClient], Prop_Send, "m_hControlPointEnts", 0);
		
		if (0 < iPatient <= MaxClients)
		{
			//Using active weapon so beam connects to nice spot
			int iActiveWeapon = GetEntPropEnt(iPatient, Prop_Send, "m_hActiveWeapon");
			if (iActiveWeapon != iControlPoint)
			{
				//We just started healing someone
				SetEntPropEnt(g_iMedigunBeamRef[iClient], Prop_Send, "m_hControlPointEnts", iActiveWeapon, 0);
				SetEntProp(g_iMedigunBeamRef[iClient], Prop_Send, "m_iControlPointParents", iActiveWeapon, _, 0);
				
				ActivateEntity(g_iMedigunBeamRef[iClient]);
				AcceptEntityInput(g_iMedigunBeamRef[iClient], "Start");
			}
		}
		
		if (iPatient <= 0 && iControlPoint > 0)
		{
			//We just stopped healing someone
			SetEntPropEnt(g_iMedigunBeamRef[iClient], Prop_Send, "m_hControlPointEnts", -1, 0);
			SetEntProp(g_iMedigunBeamRef[iClient], Prop_Send, "m_iControlPointParents", -1, _, 0);
			
			AcceptEntityInput(g_iMedigunBeamRef[iClient], "Stop");
		}
	}
}

public void Client_PreThinkPost(int iClient)
{
	Patch_DisableIsPlayerClass();
	
	//m_flEnergyDrinkMeter meant to be used for scout drinks, but TFCond_CritCola shared Buffalo Steak and Cleaner's Carbine
	//TODO fix this when player have multiple weapons
	if (TF2_IsPlayerInCondition(iClient, TFCond_CritCola))
	{
		int iWeapon, iPos;
		if (TF2_GetItemFromClassname(iClient, "tf_weapon_lunchbox_drink", iWeapon, iPos))
			SetEntPropFloat(iClient, Prop_Send, "m_flEnergyDrinkMeter", 100.0);
	}
	
	//Save revenge crits from weapons fired or manmelter crit collected
	Properties_SaveActiveWeaponPropInt(iClient, "m_iRevengeCrits");
	
	//Save hype meter drainage to all soda popper
	g_iHypeMeterLoaded[iClient] = INVALID_ENT_REFERENCE;
	float flHypeMeter = GetEntPropFloat(iClient, Prop_Send, "m_flHypeMeter");
	int iWeapon, iPos;
	while (TF2_GetItemFromClassname(iClient, "tf_weapon_soda_popper", iWeapon, iPos))
		Properties_SetWeaponPropFloat(iWeapon, "m_flHypeMeter", flHypeMeter);
	
	Properties_LoadActiveWeaponPropFloat(iClient, "m_flHypeMeter");
}

public void Client_PostThink(int iClient)
{
	//CTFPlayerShared::UpdateItemChargeMeters is called inside CTFPlayer::ItemPostFrame/PostThink
	// Update charge meters ourself and forget changes TF2 did after PostThink
	
	int iWeapon, iPos;
	while (TF2_GetItemFromAttribute(iClient, "item_meter_charge_type", iWeapon, iPos))
	{
		float flRate = TF2Attrib_HookValueFloat(0.0, "item_meter_charge_rate", iWeapon);
		if (!flRate)
			continue;
		
		flRate = GetGameFrameTime() / flRate * 100.0;
		Properties_AddWeaponChargeMeter(iClient, iWeapon, flRate);
	}
}

public void Client_PostThinkPost(int iClient)
{
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != INVALID_ENT_REFERENCE)
	{
		//If meter is increased, its from TF2 charge meters itself, reverse it
		// Otherwise it might've decreased as consumed, save it
		int iSlot = TF2_GetSlot(iActiveWeapon);
		if (Properties_GetWeaponPropFloat(iActiveWeapon, "m_flItemChargeMeter") < GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", iSlot))
			Properties_LoadWeaponPropFloat(iClient, iActiveWeapon, "m_flItemChargeMeter", iSlot);
		else
			Properties_SaveWeaponPropFloat(iClient, iActiveWeapon, "m_flItemChargeMeter", iSlot);
	}
}

public Action Client_WeaponEquip(int iClient, int iWeapon)
{
	SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", iClient);	//So client's class can be attempted first for TF2_GetDefaultClassFromItem
	
	ViewModels_UpdateArms(iClient, iWeapon);	// Set arms for the weapon were about to equip
	
	//Change class before equipping the weapon, otherwise anims and reload times are odd
	SetClientClass(iClient, TF2_GetDefaultClassFromItem(iWeapon));
	
	// Don't allow robotarm model screw up anims
	if (TF2Attrib_HookValueFloat(0.0, "wrench_builds_minisentry", iClient) == 1.0)
		TF2Attrib_SetByName(iClient, "mod wrench builds minisentry", -1.0);	// 1.0 + -1.0 = 0.0
	
	return Plugin_Continue;
}

public void Client_WeaponEquipPost(int iClient, int iWeapon)
{
	TF2Attrib_RemoveByName(iClient, "mod wrench builds minisentry");
	
	RevertClientClass(iClient);
	
	ViewModels_UpdateArms(iClient);
	
	//Refresh controls and huds
	Controls_RefreshClient(iClient);
	Huds_RefreshClient(iClient);
}

public Action Client_WeaponSwitch(int iClient, int iWeapon)
{
	ViewModels_UpdateArms(iClient);	// Incase if weapons were to be not properly set up yet for draw animation
	
	//Save current active weapon properties before potentally switched out
	Properties_SaveActiveWeaponAmmo(iClient);
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != INVALID_ENT_REFERENCE)
	{
		Properties_SaveWeaponPropInt(iClient, iActiveWeapon, "m_iRevengeCrits");
		Properties_SaveWeaponPropFloat(iClient, iActiveWeapon, "m_flItemChargeMeter", TF2_GetSlot(iActiveWeapon));
	}
	
	return Plugin_Continue;
}

public void Client_WeaponSwitchPost(int iClient, int iWeapon)
{
	ViewModels_UpdateArms(iClient);	// Update arms model with new active weapon
	
	//Update ammo for new active weapon
	Properties_UpdateActiveWeaponAmmo(iClient);
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != INVALID_ENT_REFERENCE)
	{
		int iRevengeCrits = GetEntProp(iClient, Prop_Send, "m_iRevengeCrits");
		if (iRevengeCrits > 0 && Properties_GetWeaponPropInt(iActiveWeapon, "m_iRevengeCrits") == 0)
			TF2_RemoveCondition(iClient, TFCond_Kritzkrieged);
		else if (iRevengeCrits == 0 && Properties_GetWeaponPropInt(iActiveWeapon, "m_iRevengeCrits") > 0)
			TF2_AddCondition(iClient, TFCond_Kritzkrieged, TFCondDuration_Infinite);
		
		Properties_LoadRageProps(iClient, iActiveWeapon);
		Properties_LoadWeaponPropInt(iClient, iActiveWeapon, "m_iDecapitations");
		Properties_LoadWeaponPropInt(iClient, iActiveWeapon, "m_iRevengeCrits");
		Properties_LoadWeaponPropFloat(iClient, iActiveWeapon, "m_flHypeMeter");
		Properties_LoadWeaponPropFloat(iClient, iActiveWeapon, "m_flItemChargeMeter", TF2_GetSlot(iActiveWeapon));
	}
}

public Action Client_WeaponCanSwitchTo(int iClient, int iWeapon)
{
	if (iWeapon == INVALID_ENT_REFERENCE)
		return Plugin_Continue;
	
	Properties_SaveActiveWeaponAmmo(iClient);
	
	//Set ammo to weapon wanting to switch, see if allow or deny
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType != -1 && iAmmoType != TF_AMMO_METAL)
		Properties_LoadWeaponPropInt(iClient, iWeapon, "m_iAmmo", iAmmoType);
	
	return Plugin_Continue;
}

public void Client_WeaponCanSwitchToPost(int iClient, int iWeapon)
{
	if (iWeapon == INVALID_ENT_REFERENCE)
		return;
	
	//Update ammo back to whatever active weapon is
	Properties_UpdateActiveWeaponAmmo(iClient);
}

public Action Weapon_Reload(int iWeapon)
{
	//Weapon unable to be reloaded from cloak, but coded in revolver only, and only for Spy class
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	if (TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public void HealthKit_SpawnPost(int iHealthKit)
{
	//Feigh death drops health pack if have Candy Cane active. Why? No idea
	int iClient = GetEntPropEnt(iHealthKit, Prop_Send, "m_hOwnerEntity");
	if (0 < iClient <= MaxClients && g_bFeignDeath[iClient])
		RemoveEntity(iHealthKit);
}

public Action Item_Touch(int iItem, int iToucher)
{
	if (iToucher <= 0 || iToucher > MaxClients)
		return Plugin_Continue;
	
	//All items using this hook has class check on picking up
	Patch_EnableIsPlayerClass();
	g_iTouchItem = iItem;
	g_iTouchToucher = iToucher;
	g_iTouchLunchbox = INVALID_ENT_REFERENCE;
	
	char sClassname[256];
	GetEntityClassname(iItem, sClassname, sizeof(sClassname));
	if (StrContains(sClassname, "item_healthkit") == 0)
	{
		//Find sandvich to use to refill
		float flTargetMeter = 100.0;
		
		int iWeapon, iPos;
		while (TF2_GetItemFromClassname(iToucher, "tf_weapon_lunchbox", iWeapon, iPos))
		{
			float flChargeMeter = Properties_GetWeaponPropFloat(iWeapon, "m_flItemChargeMeter");
			if (flChargeMeter < flTargetMeter)
			{
				g_iTouchLunchbox = iWeapon;
				flTargetMeter = flChargeMeter;
			}
		}
		
		if (g_iTouchLunchbox != INVALID_ENT_REFERENCE)
		{
			Properties_SetForceWeaponAmmo(g_iTouchLunchbox);
			
			int iActiveWeapon = GetEntPropEnt(iToucher, Prop_Send, "m_hActiveWeapon");
			if (iActiveWeapon != INVALID_ENT_REFERENCE)
				Properties_SaveWeaponPropFloat(iToucher, iActiveWeapon, "m_flItemChargeMeter", TF2_GetSlot(iActiveWeapon));
			
			Properties_LoadWeaponPropFloat(iToucher, g_iTouchLunchbox, "m_flItemChargeMeter", TF2_GetSlot(g_iTouchLunchbox));
		}
	}
	else if (StrEqual(sClassname, "tf_projectile_stun_ball"))
	{
		//Find sandman that could pick up this ball
		int iTargetWeapon = INVALID_ENT_REFERENCE;
		float flTargetTime;
		
		int iWeapon, iPos;
		while (TF2_GetItemFromClassname(iToucher, "tf_weapon_bat_wood", iWeapon, iPos))
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
	
	return Plugin_Continue;
}

public void Item_TouchPost(int iItem, int iToucher)
{
	if (iToucher <= 0 || iToucher > MaxClients)
		return;
	
	Patch_DisableIsPlayerClass();
	Properties_ResetForceWeaponAmmo(1);
	
	if (g_iTouchLunchbox != INVALID_ENT_REFERENCE)
		Properties_SaveWeaponPropFloat(iToucher, g_iTouchLunchbox, "m_flItemChargeMeter", TF2_GetSlot(g_iTouchLunchbox));
	
	g_iTouchItem = INVALID_ENT_REFERENCE;
	g_iTouchToucher = INVALID_ENT_REFERENCE;
	g_iTouchLunchbox = INVALID_ENT_REFERENCE;
}