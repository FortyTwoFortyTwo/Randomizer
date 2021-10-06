void Event_Init()
{
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_point_captured", Event_PointCaptured);
	HookEvent("teamplay_flag_event", Event_FlagCaptured);
	HookEvent("post_inventory_application", Event_PlayerInventoryUpdate);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("pass_score", Event_PassScore);
}

public Action Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	Group_TriggerRandomizeAll(RandomizedAction_Round);
	
	if (event.GetBool("full_reset"))
		Group_TriggerRandomizeAll(RandomizedAction_RoundFull);
}

public Action Event_PointCaptured(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	char[] sCappers = new char[MaxClients];
	
	hEvent.GetString("cappers", sCappers, MaxClients+1);
	
	for (int i = 0; i < MaxClients; i++)
		if (sCappers[i])
			Group_TriggerRandomizeClient(view_as<int>(sCappers[i]), RandomizedAction_CPCapture);
}

public Action Event_FlagCaptured(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if (hEvent.GetInt("eventtype") != 2)	//Check if it actually capture and not other events
		return;
	
	int iClient = hEvent.GetInt("player");
	if (iClient <= 0 || iClient > MaxClients)
		return;
	
	Group_TriggerRandomizeClient(iClient, RandomizedAction_FlagCapture);
}

public Action Event_PlayerInventoryUpdate(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
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
}

public Action Event_PlayerSpawn(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
	//Between post_inventory_application and player_spawn all conds were removed, so have to refresh here
	Loadout_RefreshClient(iClient);
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
	int iCustomKill = event.GetInt("customkill");
	
	if (bDeadRinger)
	{
		g_bFeignDeath[iVictim] = true;
	}
	else
	{
		Group_TriggerRandomizeClient(iVictim, RandomizedAction_Death);
		
		if (0 < iAttacker <= MaxClients && iVictim != iAttacker)
			Group_TriggerRandomizeClient(iVictim, RandomizedAction_DeathKill);
		else if (iCustomKill == TF_CUSTOM_SUICIDE)
			Group_TriggerRandomizeClient(iVictim, RandomizedAction_DeathSuicide);
		else
			Group_TriggerRandomizeClient(iVictim, RandomizedAction_DeathEnv);
	}
	
	if (0 < iAttacker <= MaxClients && iVictim != iAttacker)
		Group_TriggerRandomizeClient(iAttacker, RandomizedAction_Kill);
	if (0 < iAssister <= MaxClients && iVictim != iAssister)
		Group_TriggerRandomizeClient(iAssister, RandomizedAction_Assist);
}

public Action Event_PassScore(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = event.GetInt("scorer");
	Group_TriggerRandomizeClient(iClient, RandomizedAction_PassScore);
}