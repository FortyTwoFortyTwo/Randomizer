stock void Client_AddHealth(int iClient, int iAdditionalHeal, int iMaxOverHeal=0)
{
	int iMaxHealth = SDK_GetMaxHealth(iClient);
	int iHealth = GetEntProp(iClient, Prop_Send, "m_iHealth");
	int iTrueMaxHealth = iMaxHealth+iMaxOverHeal;
	
	if (iHealth < iTrueMaxHealth)
	{
		iHealth += iAdditionalHeal;
		if (iHealth > iTrueMaxHealth) iHealth = iTrueMaxHealth;
		SetEntProp(iClient, Prop_Send, "m_iHealth", iHealth);
	}
}

stock int TF2_CreateAndEquipWeapon(int iClient, int iIndex)
{
	char sClassname[256];
	TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
	TF2Econ_TranslateWeaponEntForClass(sClassname, sizeof(sClassname), TF2_GetPlayerClass(iClient));	//Will this break with class equipping any weapons?
	
	int iWeapon = CreateEntityByName(sClassname);
	
	if (IsValidEntity(iWeapon))
	{
		SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iIndex);
		SetEntProp(iWeapon, Prop_Send, "m_bInitialized", 1);
		
		// Allow quality / level override by updating through the offset.
		char sNetClass[64];
		GetEntityNetClass(iWeapon, sNetClass, sizeof(sNetClass));
		SetEntData(iWeapon, FindSendPropInfo(sNetClass, "m_iEntityQuality"), 6);
		SetEntData(iWeapon, FindSendPropInfo(sNetClass, "m_iEntityLevel"), 1);
			
		SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", 6);
		SetEntProp(iWeapon, Prop_Send, "m_iEntityLevel", 1);
		
		DispatchSpawn(iWeapon);
		SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true);
		
		if (StrContains(sClassname, "tf_weapon") == 0)
		{
			EquipPlayerWeapon(iClient, iWeapon);
			
			//Not sure if this even works
			int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
			if (iAmmoType > -1)
			{
				int iAmmo = SDK_GetMaxAmmo(iClient, iAmmoType);
				SetEntProp(iClient, Prop_Send, "m_iAmmo", iAmmo, _, iAmmoType);
			}
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
		PrintToChatAll("Unable to create weapon for client (%N), class (%d), classname (%s)", iClient, TF2_GetPlayerClass(iClient), sClassname);
		LogError("Unable to create weapon for client (%N), class (%d), classname (%s)", iClient, TF2_GetPlayerClass(iClient), sClassname);
	}
	
	return iWeapon;
}

stock bool TF2_WeaponFindAttribute(int iWeapon, int iAttrib, float &flVal)
{
	Address addAttrib = TF2Attrib_GetByDefIndex(iWeapon, iAttrib);
	if (addAttrib == Address_Null)
	{
		int iItemDefIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		int iAttributes[16];
		float flAttribValues[16];

		int iMaxAttrib = TF2Attrib_GetStaticAttribs(iItemDefIndex, iAttributes, flAttribValues);
		for (int i = 0; i < iMaxAttrib; i++)
		{
			if (iAttributes[i] == iAttrib)
			{
				flVal = flAttribValues[i];
				return true;
			}
		}
		return false;
	}
	flVal = TF2Attrib_GetValue(addAttrib);
	return true;
}

stock int TF2_GetItemInSlot(int iClient, int iSlot)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	if (!IsValidEdict(iWeapon))
	{
		//If weapon not found in slot, check if it a wearable
		int iWearable = SDK_GetEquippedWearable(iClient, iSlot);
		if (IsValidEdict(iWearable))
			iWeapon = iWearable;
	}
	
	return iWeapon;
}

stock int TF2_GetSlotFromWeapon(int iClient, int iWeapon)
{
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
		if (iWeapon == TF2_GetItemInSlot(iClient, iSlot))
			return iSlot;
	
	return -1;
}

stock void TF2_RemoveItemInSlot(int client, int slot)
{
	TF2_RemoveWeaponSlot(client, slot);

	int iWearable = SDK_GetEquippedWearable(client, slot);
	if (iWearable > MaxClients)
	{
		SDK_RemoveWearable(client, iWearable);
		AcceptEntityInput(iWearable, "Kill");
	}
}

stock int TF2_GetCurrentAmmo(int iWeapon)
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