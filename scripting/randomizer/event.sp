void Event_Init()
{
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_PlayerInventoryUpdate);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
}


public Action Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	RandomizeTeamWeapon();
	
	//Update client weapons
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			RandomizeClientWeapon(iClient);
			
			if (IsPlayerAlive(iClient) && (IsClassRandomized(iClient) || IsWeaponRandomized(iClient)))
				TF2_RespawnPlayer(iClient);
		}
	}
}

public Action Event_PlayerSpawn(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
	g_bClientRespawn[iClient] = false;	//Client respawned, dont need force respawn demand
	
	if (!IsCosmeticRandomized(iClient))
		return;
	
	//Destroy any cosmetics left
	int iCosmetic;
	while ((iCosmetic = FindEntityByClassname(iCosmetic, "tf_wearable*")) > MaxClients)
	{
		if (GetEntPropEnt(iCosmetic, Prop_Send, "m_hOwnerEntity") == iClient)
		{
			int iIndex = GetEntProp(iCosmetic, Prop_Send, "m_iItemDefinitionIndex");
			for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
			{
				int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
				if (iSlot == LoadoutSlot_Misc)
				{
					TF2_RemoveItem(iClient, iCosmetic);
					continue;
				}
			}
		}
	}
	
	int iMaxCosmetics = g_cvRandomCosmetics.IntValue;
	if (iMaxCosmetics == 0)	//Good ol TF2 2007
		return;
	
	static const int iSlotCosmetics[] = {
		LoadoutSlot_Head,
		LoadoutSlot_Misc,
		LoadoutSlot_Misc2
	};
	
	Address pPossibleItems[CLASS_MAX * sizeof(iSlotCosmetics)];
	int iPossibleCount;
	
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		for (int i = 0; i < sizeof(iSlotCosmetics); i++)
		{
			Address pItem = SDKCall_GetLoadoutItem(iClient, view_as<TFClassType>(iClass), iSlotCosmetics[i]);
			if (TF2_IsValidEconItemView(pItem))
			{
				pPossibleItems[iPossibleCount] = pItem;
				iPossibleCount++;
			}
		}
	}
	
	SortIntegers(view_as<int>(pPossibleItems), iPossibleCount, Sort_Random);
	
	if (iMaxCosmetics > iPossibleCount)
		iMaxCosmetics = iPossibleCount;
	
	if (g_cvCosmeticsConflicts.BoolValue)
	{
		int iCount;
		
		for (int i = 0; i < iPossibleCount; i++)
		{
			int iIndex = LoadFromAddress(pPossibleItems[i] + view_as<Address>(g_iOffsetItemDefinitionIndex), NumberType_Int16);
			int iMask = TF2Econ_GetItemEquipRegionMask(iIndex);
			bool bConflicts;
			
			//Find any possible cosmetic conflicts, both weapon and cosmetic
			int iItem;
			int iPos;
			while (TF2_GetItem(iClient, iItem, iPos, true))
			{
				int iItemIndex = GetEntProp(iItem, Prop_Send, "m_iItemDefinitionIndex");
				if (0 <= iItemIndex < 65535 && iMask & TF2Econ_GetItemEquipRegionMask(iItemIndex))
				{
					bConflicts = true;
					break;
				}
			}
			
			if (!bConflicts)
			{
				TF2_EquipWeapon(iClient, TF2_GiveNamedItem(iClient, pPossibleItems[i]));
				iCount++;
				if (iCount == iMaxCosmetics)
					break;
			}
		}
	}
	else
	{
		for (int i = 0; i < iMaxCosmetics; i++)
			TF2_EquipWeapon(iClient, TF2_GiveNamedItem(iClient, pPossibleItems[i]));
	}
}

public Action Event_PlayerInventoryUpdate(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	
	//Because of blocking ValidateWeapons and ValidateWearables, make sure action weapon is correct
	Address pActionItem = SDKCall_GetLoadoutItem(iClient, nClass, LoadoutSlot_Action);
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
	
	if (!IsWeaponRandomized(iClient))
		return;
	
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		char sClassname[256];
		GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
		int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		
		if (CanKeepWeapon(iClient, sClassname, iIndex))
			continue;
		
		if (!g_eClientWeapon[iClient][nClass].HasWeapon(iWeapon))
			TF2_RemoveItem(iClient, iWeapon);
	}
	
	
	for (iPos = 0; iPos < MAX_WEAPONS; iPos++)
	{
		if (g_eClientWeapon[iClient][nClass].iRef[iPos] != INVALID_ENT_REFERENCE && !IsValidEntity(g_eClientWeapon[iClient][nClass].iRef[iPos]))
			g_eClientWeapon[iClient][nClass].iRef[iPos] = INVALID_ENT_REFERENCE;
		
		if (g_eClientWeapon[iClient][nClass].iRef[iPos] != INVALID_ENT_REFERENCE)
			continue;
		
		int iIndex = g_eClientWeapon[iClient][nClass].iIndex[iPos];
		if (iIndex == -1 || !ItemIsAllowed(iIndex))
			continue;
		
		int iSlot = g_eClientWeapon[iClient][nClass].iSlot[iPos];
		
		Address pItem = TF2_FindReskinItem(iClient, iIndex);
		if (pItem)
			iWeapon = TF2_GiveNamedItem(iClient, pItem, iSlot);
		else
			iWeapon = TF2_CreateWeapon(iClient, iIndex, iSlot);
		
		if (iWeapon == INVALID_ENT_REFERENCE)
		{
			PrintToChat(iClient, "Unable to create weapon! index '%d'", iIndex);
			LogError("Unable to create weapon! index '%d'", iIndex);
			continue;
		}
		
		//CTFPlayer::ItemsMatch doesnt like normal item quality, so lets use unique instead
		if (view_as<TFQuality>(GetEntProp(iWeapon, Prop_Send, "m_iEntityQuality")) == TFQual_Normal)
			SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", TFQual_Unique);
		
		//Fill charge meter
		float flVal;
		if (!TF2_WeaponFindAttribute(iWeapon, "item_meter_resupply_denied", flVal) || flVal == 0.0)
			Properties_AddWeaponChargeMeter(iClient, iWeapon, 100.0);
		
		TF2_EquipWeapon(iClient, iWeapon);
		
		if (ViewModels_ShouldBeInvisible(iWeapon, nClass))
			ViewModels_EnableInvisible(iWeapon);
		
		g_eClientWeapon[iClient][nClass].iRef[iPos] = EntIndexToEntRef(iWeapon);
	}
	
	//Set ammo to 0, CTFPlayer::GetMaxAmmo detour will correct this, adding ammo by current
	for (int iAmmoType = 0; iAmmoType < TF_AMMO_COUNT; iAmmoType++)
		SetEntProp(iClient, Prop_Send, "m_iAmmo", 0, _, iAmmoType);
	
	//Set active weapon if dont have one
	//TODO update this
	if (GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") == INVALID_ENT_REFERENCE)
	{
		for (int iSlot = 0; iSlot <= WeaponSlot_Melee; iSlot++)
		{
			iWeapon = GetPlayerWeaponSlot(iClient, iSlot);	//Dont want wearable
			if (iWeapon > MaxClients)
			{
				SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
				break;
			}
		}
	}
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
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	bool bDeadRinger = (event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER) != 0;
	
	if (bDeadRinger)
		g_bFeignDeath[iClient] = true;
	
	//Only generate new weapons if killed from attacker, and it's a normal round
	if (0 < iAttacker <= MaxClients && IsClientInGame(iAttacker) && iClient != iAttacker && !bDeadRinger && g_cvRandomWeapons.IntValue == Mode_Normal)
		RandomizeClientWeapon(iClient);
}