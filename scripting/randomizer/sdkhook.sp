void SDKHook_HookClient(int iClient)
{
	SDKHook(iClient, SDKHook_PreThink, Client_PreThink);
	SDKHook(iClient, SDKHook_PreThinkPost, Client_PreThinkPost);
	SDKHook(iClient, SDKHook_OnTakeDamage, Client_OnTakeDamage);
	SDKHook(iClient, SDKHook_OnTakeDamagePost, Client_OnTakeDamagePost);
}

void SDKHook_UnhookClient(int iClient)
{
	SDKUnhook(iClient, SDKHook_PreThink, Client_PreThink);
	SDKUnhook(iClient, SDKHook_PreThinkPost, Client_PreThinkPost);
	SDKUnhook(iClient, SDKHook_OnTakeDamage, Client_OnTakeDamage);
	SDKUnhook(iClient, SDKHook_OnTakeDamagePost, Client_OnTakeDamagePost);
}

void SDKHook_HookWeapon(int iWeapon)
{
	SDKHook(iWeapon, SDKHook_SpawnPost, Weapon_SpawnPost);
	SDKHook(iWeapon, SDKHook_Reload, Weapon_Reload);
}

void SDKHook_HookHealthKit(int iHealthKit)
{
	SDKHook(iHealthKit, SDKHook_Touch, HealthKit_Touch);
	SDKHook(iHealthKit, SDKHook_TouchPost, HealthKit_TouchPost);
}

public Action Client_OnTakeDamage(int iVictim, int &iAttacker, int &iInflicter, float &flDamage, int &iDamageType, int &iWeapon, float vecForce[3], float vecForcePos[3], int iDamageCustom)
{
	g_iAllowPlayerClass[iVictim]++;
}

public void Client_OnTakeDamagePost(int iVictim, int iAttacker, int iInflicter, float flDamage, int iDamageType, int iWeapon, const float vecForce[3], const float vecForcePos[3], int iDamageCustom)
{
	g_iAllowPlayerClass[iVictim]--;
}

public void Client_PreThink(int iClient)
{
	//Non-team colored weapons can show incorrect viewmodel skin
	int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if (iViewModel > MaxClients)
		SetEntProp(iViewModel, Prop_Send, "m_nSkin", GetEntProp(iClient, Prop_Send, "m_nSkin"));
	
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
	
	int iMedigun = TF2_GetItemFromClassname(iClient, "tf_weapon_medigun");
	if (iMedigun < MaxClients)
		return;
	
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

public void Client_PreThinkPost(int iClient)
{
	g_iAllowPlayerClass[iClient]--;
}

public void Weapon_SpawnPost(int iWeapon)
{
	Ammo_OnWeaponSpawned(iWeapon);
}

public Action Weapon_Reload(int iWeapon)
{
	//Weapon unable to be reloaded from cloak, but coded in revolver only, and only for Spy class
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	if (TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action HealthKit_Touch(int iHealthKit)
{
	//Has heavy class check for lunchbox, and ensure GiveAmmo is done to secondary slot
	int iClient = GetEntPropEnt(iHealthKit, Prop_Send, "m_hOwnerEntity");
	if (0 < iClient <= MaxClients && IsClientInGame(iClient))
	{
		g_iAllowPlayerClass[iClient]++;
		Ammo_SetGiveAmmoSlot(WeaponSlot_Secondary);
	}
}

public void HealthKit_TouchPost(int iHealthKit)
{
	int iClient = GetEntPropEnt(iHealthKit, Prop_Send, "m_hOwnerEntity");
	if (0 < iClient <= MaxClients && IsClientInGame(iClient))
	{
		g_iAllowPlayerClass[iClient]--;
		Ammo_SetGiveAmmoSlot(-1);
	}
}