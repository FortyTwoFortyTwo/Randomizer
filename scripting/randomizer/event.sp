void Event_Init()
{
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("post_inventory_application", Event_PlayerInventoryUpdate);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
}

public Action Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	Group_RandomizeAll(RandomizedReroll_Round);
	
	if (event.GetBool("full_reset"))
		Group_RandomizeAll(RandomizedReroll_FullRound);
}

public Action Event_PlayerInventoryUpdate(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
	g_bClientRefresh[iClient] = false;	//Client respawned, dont need force refresh demand
	
	//Because of blocking ValidateWeapons and ValidateWearables, make sure action weapon is correct
	Address pActionItem = SDKCall_GetLoadoutItem(iClient, TF2_GetPlayerClass(iClient), LoadoutSlot_Action);
	bool bFound;
	
	int iWeapon, iPos;
	while (TF2_GetItemFromLoadoutSlot(iClient, LoadoutSlot_Action, iWeapon, iPos))
	{
		if (!TF2_IsValidEconItemView(pActionItem) || GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") != LoadFromAddress(pActionItem + view_as<Address>(g_iOffsetItemDefinitionIndex), NumberType_Int16))
			TF2_RemoveItem(iClient, iWeapon);
		else
			bFound = true;
	}
	
	if (!bFound && TF2_IsValidEconItemView(pActionItem))
		TF2_EquipWeapon(iClient, TF2_GiveNamedItem(iClient, pActionItem));
	
	//Refill charge meters
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		float flVal;
		if (!TF2_WeaponFindAttribute(iWeapon, "item_meter_resupply_denied", flVal) || flVal == 0.0)
			Properties_AddWeaponChargeMeter(iClient, iWeapon, 100.0);
	}
	
	if (Group_IsClientRandomized(iClient, RandomizedType_Rune))
		SDKCall_SetCarryingRuneType(GetEntityAddress(iClient) + view_as<Address>(g_iOffsetPlayerShared), g_eClientInfo[iClient].iRuneType);
	
	if (Group_IsClientRandomized(iClient, RandomizedType_Weapons))
		RefreshClientWeapons(iClient);
}

public Action Event_PlayerHurt(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	int iDamage = event.GetInt("damageamount");
	
	if (0 < iAttacker <= MaxClients && iAttacker != iClient)
	{
		//Increase meter for Gas Passer
		int iWeapon, iPos;
		while (TF2_GetItemFromAttribute(iAttacker, "item_meter_charge_type", iWeapon, iPos))
		{
			//Could add check whenever if item_meter_charge_type value is 3, meh
			
			float flRate;
			if (!TF2_WeaponFindAttribute(iWeapon, "item_meter_damage_for_full_charge", flRate))
				continue;
			
			flRate = float(iDamage) / flRate * 100.0;
			Properties_AddWeaponChargeMeter(iAttacker, iWeapon, flRate);
		}
	}
}

public Action Event_PlayerDeath(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iVictim = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	int iAssister = GetClientOfUserId(event.GetInt("assister"));
	bool bDeadRinger = (event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER) != 0;
	
	if (bDeadRinger)
	{
		g_bFeignDeath[iVictim] = true;
	}
	else
	{
		if (0 < iAttacker <= MaxClients && iVictim != iAttacker)
			Group_RandomizeClient(iVictim, RandomizedReroll_Death);
		else if (iVictim == iAttacker)
			Group_RandomizeClient(iVictim, RandomizedReroll_Suicide);
		else
			Group_RandomizeClient(iVictim, RandomizedReroll_Environment);
	}
	
	if (0 < iAttacker <= MaxClients && iVictim != iAttacker)
		Group_RandomizeClient(iAttacker, RandomizedReroll_Kill);
	if (0 < iAssister <= MaxClients && iVictim != iAssister)
		Group_RandomizeClient(iAssister, RandomizedReroll_Assist);
}