static int g_iMedigunBeamRef[TF_MAXPLAYERS] = {INVALID_ENT_REFERENCE, ...};

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
}

public Action Client_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &flDamage, int &iDamageType, int &iWeapon, float vecDamageForce[3], float vecDamagePosition[3], int iDamageCustom)
{
	g_iAllowPlayerClass[iVictim]++;
	
	if (0 < iAttacker <= MaxClients)
	{
		g_iAllowPlayerClass[iAttacker]++;
		
		if (iWeapon != INVALID_ENT_REFERENCE)
		{
			Properties_LoadWeaponPropInt(iAttacker, iWeapon, "m_iDecapitations");
			g_bWeaponDecap[iAttacker] = true;
		}
		
		//Setup collecting revenge crits for diamondback
		int iActiveWeapon = GetEntPropEnt(iAttacker, Prop_Send, "m_hActiveWeapon");
		if (iActiveWeapon != INVALID_ENT_REFERENCE)
			Properties_SaveWeaponPropInt(iAttacker, iActiveWeapon, "m_iRevengeCrits");
		
		SetEntProp(iAttacker, Prop_Send, "m_iRevengeCrits", 0);
	}
}

public void Client_OnTakeDamagePost(int iVictim, int iAttacker, int iInflictor, float flDamage, int iDamageType, int iWeapon, const float vecDamageForce[3], const float vecDamagePosition[3], int iDamageCustom)
{
	g_iAllowPlayerClass[iVictim]--;
	g_bFeignDeath[iVictim] = false;
	
	if (0 < iAttacker <= MaxClients)
	{
		g_iAllowPlayerClass[iAttacker]--;
		
		if (iWeapon != INVALID_ENT_REFERENCE)
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
			while (TF2_GetItemFromAttribute(iAttacker, "sapper kills collect crits", iTempWeapon, iPos))	//This is not a sapper kill...
				Properties_AddWeaponPropInt(iTempWeapon, "m_iRevengeCrits", iRevengeCrits);
		}
		
		//Set it back
		int iActiveWeapon = GetEntPropEnt(iAttacker, Prop_Send, "m_hActiveWeapon");
		if (iActiveWeapon != INVALID_ENT_REFERENCE)
			Properties_LoadWeaponPropInt(iAttacker, iActiveWeapon, "m_iRevengeCrits");
	}
}

public void Client_PreThink(int iClient)
{
	//Non-team colored weapons can show incorrect viewmodel skin
	int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if (iViewModel > MaxClients)
		SetEntProp(iViewModel, Prop_Send, "m_nSkin", GetEntProp(iClient, Prop_Send, "m_nSkin"));
	
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
	g_iAllowPlayerClass[iClient]++;
	
	// Medigun beams doesnt show if player is not medic, and we can't fix that in SDK because it all in clientside
	if (TF2_GetPlayerClass(iClient) == TFClass_Medic)
		return;
	
	static char sParticle[][] = {
		"",
		"",
		PARTICLE_BEAM_RED,
		PARTICLE_BEAM_BLU,
	};
	
	int iMedigun, iPos;
	while (TF2_GetItemFromClassname(iClient, "tf_weapon_medigun", iMedigun, iPos))
	{
		if (!IsValidEntity(g_iMedigunBeamRef[iClient]))
			g_iMedigunBeamRef[iClient] = TF2_SpawnParticle(sParticle[TF2_GetClientTeam(iClient)], iMedigun);
		
		int iPatient = GetEntPropEnt(iMedigun, Prop_Send, "m_hHealingTarget");
		int iControlPoint = GetEntPropEnt(g_iMedigunBeamRef[iClient], Prop_Send, "m_hControlPointEnts", 0);
		
		if (0 < iPatient <= MaxClients)
		{
			//Using active weapon so beam connects to nice spot
			int iWeapon = GetEntPropEnt(iPatient, Prop_Send, "m_hActiveWeapon");
			if (iWeapon != iControlPoint)
			{
				//We just started healing someone
				SetEntPropEnt(g_iMedigunBeamRef[iClient], Prop_Send, "m_hControlPointEnts", iWeapon, 0);
				SetEntProp(g_iMedigunBeamRef[iClient], Prop_Send, "m_iControlPointParents", iWeapon, _, 0);
				
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
	g_iAllowPlayerClass[iClient]--;
	
	//m_flEnergyDrinkMeter meant to be used for scout drinks, but TFCond_CritCola shared Buffalo Steak and Cleaner's Carbine
	//TODO fix this when player have multiple weapons
	if (TF2_IsPlayerInCondition(iClient, TFCond_CritCola))
	{
		int iWeapon, iPos;
		if (TF2_GetItemFromClassname(iClient, "tf_weapon_lunchbox_drink", iWeapon, iPos))
			SetEntPropFloat(iClient, Prop_Send, "m_flEnergyDrinkMeter", 100.0);
	}
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != INVALID_ENT_REFERENCE)
	{
		//Save revenge crits from weapons fired or manmelter crit collected
		Properties_SaveWeaponPropInt(iClient, iActiveWeapon, "m_iRevengeCrits");
	}
}

public void Client_PostThink(int iClient)
{
	//CTFPlayerShared::UpdateItemChargeMeters is called inside CTFPlayer::ItemPostFrame/PostThink
	// Update charge meters ourself and forget changes TF2 did after PostThink
	
	int iWeapon, iPos;
	while (TF2_GetItemFromAttribute(iClient, "item_meter_charge_type", iWeapon, iPos))
	{
		float flRate;
		if (!TF2_WeaponFindAttribute(iWeapon, "item_meter_charge_rate", flRate))
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
	//Change class before equipping the weapon, otherwise reload times are odd
	//This also somehow fixes sniper with a banner
	SetClientClass(iClient, TF2_GetDefaultClassFromItem(iWeapon));
}

public void Client_WeaponEquipPost(int iClient, int iWeapon)
{
	RevertClientClass(iClient);
	
	//Give robot arm viewmodel if weapon isnt good with current viewmodel
	if (ViewModels_ShouldUseRobotArm(iClient, iWeapon))
		TF2Attrib_SetByName(iWeapon, "mod wrench builds minisentry", 1.0);
	
	//Refresh controls and huds
	Controls_RefreshClient(iClient);
	Huds_RefreshClient(iClient);
}

public Action Client_WeaponSwitch(int iClient, int iWeapon)
{
	//Save current active weapon properties before potentally switched out
	Properties_SaveActiveWeaponAmmo(iClient);
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != INVALID_ENT_REFERENCE)
	{
		Properties_SaveWeaponPropInt(iClient, iActiveWeapon, "m_iRevengeCrits");
		Properties_SaveWeaponPropFloat(iClient, iActiveWeapon, "m_flItemChargeMeter", TF2_GetSlot(iActiveWeapon));
	}
}

public void Client_WeaponSwitchPost(int iClient, int iWeapon)
{
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
		Properties_LoadWeaponPropFloat(iClient, iActiveWeapon, "m_flItemChargeMeter", TF2_GetSlot(iActiveWeapon));
	}
}

public Action Client_WeaponCanSwitchTo(int iClient, int iWeapon)
{
	if (iWeapon == INVALID_ENT_REFERENCE)
		return;
	
	Properties_SaveActiveWeaponAmmo(iClient);
	
	//Set ammo to weapon wanting to switch, see if allow or deny
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType != -1 && iAmmoType != TF_AMMO_METAL)
		Properties_LoadWeaponPropInt(iClient, iWeapon, "m_iAmmo", iAmmoType);
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