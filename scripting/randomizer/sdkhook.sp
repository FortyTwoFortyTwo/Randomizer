void SDKHook_HookClient(int iClient)
{
	SDKHook(iClient, SDKHook_PreThink, Client_PreThink);
	SDKHook(iClient, SDKHook_PreThinkPost, Client_PreThinkPost);
	SDKHook(iClient, SDKHook_WeaponEquip, Client_WeaponEquip);
	SDKHook(iClient, SDKHook_WeaponEquipPost, Client_WeaponEquipPost);
}

void SDKHook_UnhookClient(int iClient)
{
	SDKUnhook(iClient, SDKHook_PreThink, Client_PreThink);
	SDKUnhook(iClient, SDKHook_PreThinkPost, Client_PreThinkPost);
	SDKUnhook(iClient, SDKHook_WeaponEquip, Client_WeaponEquip);
	SDKUnhook(iClient, SDKHook_WeaponEquipPost, Client_WeaponEquipPost);
}

void SDKHook_OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (StrContains(sClassname, "tf_weapon_") == 0)
	{
		SDKHook(iEntity, SDKHook_SpawnPost, Weapon_SpawnPost);
		SDKHook(iEntity, SDKHook_Reload, Weapon_Reload);
	}
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