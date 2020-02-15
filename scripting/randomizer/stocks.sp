stock void AddEffectFlags(int iEntity, int iEffects)
{
    SetEntProp(iEntity, Prop_Send, "m_fEffects", iEffects | GetEntProp(iEntity, Prop_Send, "m_fEffects"));
}

stock void RemoveEffectFlags(int iEntity, int iEffects)
{
    SetEntProp(iEntity, Prop_Send, "m_fEffects", ~iEffects & GetEntProp(iEntity, Prop_Send, "m_fEffects"));
}

stock int TF2_CreateAndEquipWeapon(int iClient, int iIndex, int iSlot)
{
	char sClassname[256];
	TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
	
	//We want to translate classname to correct classname AND slot wanted
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		int iClassSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
		if (iClassSlot == iSlot)
		{
			TF2Econ_TranslateWeaponEntForClass(sClassname, sizeof(sClassname), view_as<TFClassType>(iClass));
			break;
		}
	}
	
	int iWeapon = CreateEntityByName(sClassname);
	
	if (IsValidEntity(iWeapon))
	{
		SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iIndex);
		SetEntProp(iWeapon, Prop_Send, "m_bInitialized", 1);
		
		SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", 6);
		SetEntProp(iWeapon, Prop_Send, "m_iEntityLevel", 1);
		
		DispatchSpawn(iWeapon);
		SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true);
		
		if (StrContains(sClassname, "tf_weapon") == 0)
		{
			//ViewModel_CreateWeapon(iClient, iSlot, iWeapon);
			
			EquipPlayerWeapon(iClient, iWeapon);
			
			//Set ammo to 0, CTFPlayer::GetMaxAmmo detour will correct this, adding ammo by current
			int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
			if (iAmmoType > -1)
				SetEntProp(iClient, Prop_Send, "m_iAmmo", 0, _, iAmmoType);
			
			//Reset charge meter
			SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, iSlot);
		}
		else if (StrContains(sClassname, "tf_wearable") == 0)
		{
			SDK_EquipWearable(iClient, iWeapon);
		}
		else
		{
			AcceptEntityInput(iWeapon, "Kill");
			return -1;
		}
	}
	else
	{
		PrintToChat(iClient, "Unable to create weapon! index (%d) classname (%s)", iIndex, sClassname);
		LogError("Unable to create weapon! index (%d), classname (%s)", iIndex, sClassname);
	}
	
	return iWeapon;
}

stock bool TF2_WeaponFindAttribute(int iWeapon, int iAttrib, float &flVal)
{
	int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	ArrayList aAttribs = TF2Econ_GetItemStaticAttributes(iIndex);
	
	int iPos = aAttribs.FindValue(iAttrib, 0);
	if (iPos >= 0)
	{
		flVal = aAttribs.Get(iPos, 1);
		delete aAttribs;
		return true;
	}
	
	delete aAttribs;
	return false;
}

stock int TF2_GetItemInSlot(int iClient, int iSlot)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	
	//If weapon not found in slot, check if it a wearable
	if (!IsValidEntity(iWeapon))
		return TF2_GetWearableInSlot(iClient, iSlot);
	
	return iWeapon;
}

stock int TF2_GetWearableInSlot(int iClient, int iSlot)
{
	//SDK call for get wearable doesnt work if different class use different wearable
	//Still a problem with weapons useable with more than 1 slots... may be able to get away with it if checking GetPlayerWeaponSlot first
	
	int iWearable = MaxClients+1;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable*")) > MaxClients)
	{
		if (GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity") == iClient || GetEntPropEnt(iWearable, Prop_Send, "moveparent") == iClient)
		{
			int iIndex = GetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex");
			for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
			{
				int iWearableSlot = TF2Econ_GetItemSlot(iIndex, view_as<TFClassType>(iClass));
				if (iWearableSlot == iSlot)
					return iWearable;
			}
		}
	}
	
	return -1;
}

stock int TF2_GetSlotFromItem(int iClient, int iWeapon)
{
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
		if (iWeapon == TF2_GetItemInSlot(iClient, iSlot))
			return iSlot;
	
	return -1;
}

stock int TF2_GetSlotFromIndex(int iIndex, TFClassType nClass = TFClass_Unknown)
{
	int iSlot = TF2Econ_GetItemSlot(iIndex, nClass);
	if (iSlot >= 0)
	{
		// Econ reports wrong slots for Engineer and Spy
		switch (nClass)
		{
			case TFClass_Engineer:
			{
				switch (iSlot)
				{
					case 4: iSlot = WeaponSlot_BuilderEngie; // Toolbox
					case 5: iSlot = WeaponSlot_PDABuild; // Construction PDA
					case 6: iSlot = WeaponSlot_PDADestroy; // Destruction PDA
				}
			}
			case TFClass_Spy:
			{
				switch (iSlot)
				{
					case 1: iSlot = WeaponSlot_Primary; // Revolver
					case 4: iSlot = WeaponSlot_Secondary; // Sapper
					case 5: iSlot = WeaponSlot_PDADisguise; // Disguise Kit
					case 6: iSlot = WeaponSlot_InvisWatch; // Invis Watch
				}
			}
		}
	}
	
	return iSlot;
}

stock TFClassType TF2_GetDefaultClassFromItem(int iClient, int iWeapon)
{
	int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	int iSlot = TF2_GetSlotFromItem(iClient, iWeapon);
	
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		int iClassSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
		if (iClassSlot == iSlot)
			return view_as<TFClassType>(iClass);
	}
	
	return TFClass_Unknown;
}

stock void TF2_RemoveItemInSlot(int iClient, int iSlot)
{
	TF2_RemoveWeaponSlot(iClient, iSlot);

	int iWearable = TF2_GetWearableInSlot(iClient, iSlot);
	if (iWearable > MaxClients)
		TF2_RemoveWearable(iClient, iWearable);
}

stock int TF2_GetAmmo(int iWeapon)
{
	if (!HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType")) return -1;

	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType == -1) return -1;
	
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity"); 
	return GetEntProp(iClient, Prop_Send, "m_iAmmo", _, iAmmoType);
}

stock void TF2_SetAmmo(int iWeapon, int iAmmo)
{
	if (!HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType")) return;

	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType == -1) return;
	
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity"); 
	SetEntProp(iClient, Prop_Send, "m_iAmmo", iAmmo, _, iAmmoType);
}

stock void TF2_SetMetal(int iClient, int iMetal)
{
	SetEntProp(iClient, Prop_Send, "m_iAmmo", iMetal, _, TF_AMMO_METAL);
}

stock int TF2_GetItemFromAmmoType(int iClient, int iAmmoType)
{
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		int iWeapon = TF2_GetItemInSlot(iClient, iSlot);
		if (iWeapon <= MaxClients || !HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType"))
			continue;
		
		if (GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType") == iAmmoType)
			return iWeapon;
	}
	
	return -1;
}

stock void StringToLower(char[] sString)
{
	int iLength = strlen(sString);
	for(int i = 0; i < iLength; i++)
		sString[i] = CharToLower(sString[i]);
}