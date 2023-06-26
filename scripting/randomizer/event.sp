void Event_Init()
{
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_point_captured", Event_PointCaptured);
	HookEvent("teamplay_flag_event", Event_FlagCaptured);
	HookEvent("post_inventory_application", Event_PlayerInventoryUpdate);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_regenerate", Event_PlayerRegenerate);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("pass_score", Event_PassScore);
	HookEvent("rocket_jump", Event_WeaponJump);
	HookEvent("sticky_jump", Event_WeaponJump);
}

public void Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	Group_TriggerRandomizeAll(RandomizedAction_Round);
	
	if (event.GetBool("full_reset"))
		Group_TriggerRandomizeAll(RandomizedAction_RoundFull);
}

public void Event_PointCaptured(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	char[] sCappers = new char[MaxClients];
	
	hEvent.GetString("cappers", sCappers, MaxClients+1);
	
	for (int i = 0; i < MaxClients; i++)
		if (sCappers[i])
			Group_TriggerRandomizeClient(view_as<int>(sCappers[i]), RandomizedAction_CPCapture);
}

public void Event_FlagCaptured(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if (hEvent.GetInt("eventtype") != 2)	//Check if it actually capture and not other events
		return;
	
	int iClient = hEvent.GetInt("player");
	if (iClient <= 0 || iClient > MaxClients)
		return;
	
	Group_TriggerRandomizeClient(iClient, RandomizedAction_FlagCapture);
}

public void Event_PlayerInventoryUpdate(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
	//Refill charge meters
	int iWeapon, iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		if (!TF2Attrib_HookValueFloat(0.0, "item_meter_resupply_denied", iWeapon))
			Properties_AddWeaponChargeMeter(iClient, iWeapon, 100.0);
	}
}

public void Event_PlayerSpawn(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
	Loadout_RefreshClient(iClient);
	
	//Set max health after giving weapons
	SetEntProp(iClient, Prop_Send, "m_iHealth", SDKCall_GetMaxHealth(iClient));
	
	//Because client caught sourcemod changes faster than its own prediction (somehow),
	// remove rune and add a delay to give it back so icon above head appears properly
	SDKCall_SetCarryingRuneType(GetEntityAddress(iClient) + view_as<Address>(g_iOffsetPlayerShared), -1);
	CreateTimer(0.2, Loadout_TimerApplyClientRune, iClient);
}

public void Event_PlayerRegenerate(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	//This event dont have any params, not even userid
	//Regenerate screws up max ammo after InitClass, give it back
	for (int iAmmoType = 0; iAmmoType < TF_AMMO_COUNT; iAmmoType++)
		GivePlayerAmmo(g_iClientInitClass, SDKCall_GetMaxAmmo(g_iClientInitClass, iAmmoType), iAmmoType, true);
}

public void Event_PlayerHurt(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	float flDamage = float(event.GetInt("damageamount"));
	
	if (0 < iAttacker <= MaxClients && iAttacker != iClient)
	{
		int iWeapon, iPos;
		while (TF2_GetItem(iAttacker, iWeapon, iPos))
		{
			float flRate = TF2Attrib_HookValueFloat(0.0, "item_meter_damage_for_full_charge", iWeapon);
			if (flRate)
			{
				//Increase meter for Gas Passer,
				// could add check whenever if item_meter_charge_type value is 3, meh
				flRate = flDamage / flRate * 100.0;
				Properties_AddWeaponChargeMeter(iAttacker, iWeapon, flRate);
			}
			
			if (TF2Attrib_HookValueFloat(0.0, "hype_on_damage", iWeapon) && !TF2_IsPlayerInCondition(iAttacker, TFCond_CritHype))
			{
				//Soda popper
				float flHype = RemapValClamped(flDamage, 1.0, 200.0, 1.0, 50.0);	//This really is valve's method for hype meter, weird
				flHype = min(Properties_GetWeaponPropFloat(iWeapon, "m_flHypeMeter") + flHype, 100.0);
				Properties_SetWeaponPropFloat(iWeapon, "m_flHypeMeter", flHype);
			}
			
			if (TF2Attrib_HookValueFloat(0.0, "boost_on_damage", iWeapon))
			{
				//Baby Face Blaster
				float flHype = Properties_GetWeaponPropFloat(iWeapon, "m_flHypeMeter");
				flHype = min(FindConVar("tf_scout_hype_pep_max").FloatValue, flHype + (max(FindConVar("tf_scout_hype_pep_min_damage").FloatValue, flDamage) / FindConVar("tf_scout_hype_pep_mod").FloatValue));
				Properties_SetWeaponPropFloat(iWeapon, "m_flHypeMeter", flHype);
			}
		}
	}
	
	int iWeapon, iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		float flVal = TF2Attrib_HookValueFloat(0.0, "lose_hype_on_take_damage", iWeapon);
		if (flVal)
		{
			float flHype = Properties_GetWeaponPropFloat(iWeapon, "m_flHypeMeter");
			Properties_SetWeaponPropFloat(iWeapon, "m_flHypeMeter", max(0.0, flHype - (flVal * flDamage)));
		}
	}
}

public void Event_PlayerDeath(Event event, const char[] sName, bool bDontBroadcast)
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

public void Event_PassScore(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = event.GetInt("scorer");
	Group_TriggerRandomizeClient(iClient, RandomizedAction_PassScore);
}

public void Event_WeaponJump(Event event, const char[] sName, bool bDontBroadcast)
{
	//Class check should be done by this point, revert class so pain sound can be played as actual class
	if (g_bOnTakeDamage)
		RevertClientClass(GetClientOfUserId(event.GetInt("userid")));
}