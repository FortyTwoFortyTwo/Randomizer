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
	
	bool bSapper;
	if (StrEqual(sClassname, "tf_weapon_builder") || StrEqual(sClassname, "tf_weapon_sapper"))
	{
		//Toolbox is nasty to create, use different method
		if (iSlot == WeaponSlot_BuilderEngie)
			return TF2_CreateAndEquipBuilder(iClient);
		
		//Otherwise assume this weapon is for sappers
		bSapper = true;
		
		//tf_weapon_sapper is bad and give client crashes
		sClassname = "tf_weapon_builder";
	}
	
	int iWeapon = CreateEntityByName(sClassname);
	if (IsValidEntity(iWeapon))
	{
		SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iIndex);
		SetEntProp(iWeapon, Prop_Send, "m_bInitialized", 1);
		
		SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", 6);
		SetEntProp(iWeapon, Prop_Send, "m_iEntityLevel", 1);
		
		if (bSapper)
		{
			SetEntProp(iWeapon, Prop_Send, "m_iObjectType", TFObject_Sapper);
			SetEntProp(iWeapon, Prop_Data, "m_iSubType", TFObject_Sapper);
		}
		
		DispatchSpawn(iWeapon);
		SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true);
		
		//Reset charge meter
		SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, iSlot);
		
		if (StrContains(sClassname, "tf_weapon") == 0)
		{
			EquipPlayerWeapon(iClient, iWeapon);
			
			//Set ammo to 0, CTFPlayer::GetMaxAmmo detour will correct this, adding ammo by current
			int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
			if (iAmmoType > -1)
				SetEntProp(iClient, Prop_Send, "m_iAmmo", 0, _, iAmmoType);
		}
		else if (StrContains(sClassname, "tf_wearable") == 0)
		{
			SDKCall_EquipWearable(iClient, iWeapon);
		}
		else
		{
			RemoveEntity(iWeapon);
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

stock int TF2_CreateAndEquipBuilder(int iClient)
{
	Address pItem = SDKCall_GetLoadoutItem(iClient, TFClass_Engineer, 4);	//Uses econ slot, 4 for toolbox
	if (TF2_IsValidEconItemView(pItem))
	{
		g_bAllowGiveNamedItem = true;
		int iWeapon = SDKCall_GiveNamedItem(iClient, "tf_weapon_builder", 0, pItem);
		g_bAllowGiveNamedItem = false;
		
		if (iWeapon > MaxClients)
		{
			SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", true, _, view_as<int>(TFObject_Dispenser));
			SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", true, _, view_as<int>(TFObject_Teleporter));
			SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", true, _, view_as<int>(TFObject_Sentry));
			SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", false, _, view_as<int>(TFObject_Sapper));
			
			EquipPlayerWeapon(iClient, iWeapon);
			return iWeapon;
		}
	}
	
	return -1;
}

stock bool TF2_IsValidEconItemView(Address pEconItemView)
{
	if (!pEconItemView)
		return false;
	
	int iIndex = LoadFromAddress(pEconItemView + view_as<Address>(g_iOffsetItemDefinitionIndex), NumberType_Int16);
	
	// 65535 is basically unsigned -1 in int16
	return 0 <= iIndex < 65535;
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

stock bool TF2_GetItem(int iClient, int &iWeapon, int &iPos)
{
	static int iMaxWeapons;
	if (!iMaxWeapons)
		iMaxWeapons = GetEntPropArraySize(iClient, Prop_Send, "m_hMyWeapons");
	
	while (iPos < iMaxWeapons)
	{
		iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", iPos);
		iPos++;
		
		if (iWeapon > MaxClients)
			return true;
		
		if (iPos == iMaxWeapons)
			iWeapon = MaxClients+1;
	}
	
	while ((iWeapon = FindEntityByClassname(iWeapon, "tf_wearable*")) > MaxClients)
	{
		if (GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity") == iClient || GetEntPropEnt(iWeapon, Prop_Send, "moveparent") == iClient)
		{
			int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
			for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
			{
				int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
				if (0 <= iSlot <= WeaponSlot_BuilderEngie)
					return true;
			}
		}
	}
	
	return false;
}

stock int TF2_GetItemFromClassname(int iClient, const char[] sClassname)
{
	int iWeapon;
	int iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		char sBuffer[256];
		GetEntityClassname(iWeapon, sBuffer, sizeof(sBuffer));
		if (StrEqual(sBuffer, sClassname))
			return iWeapon;
	}
	
	return -1;
}

stock int TF2_GetSlot(int iWeapon)
{
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	if (StrContains(sClassname, "tf_wearable") == 0)
	{
		int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
			if (0 <= iSlot <= WeaponSlot_BuilderEngie)
				return iSlot;
		}
	}
	else
	{
		return SDKCall_GetSlot(iWeapon);
	}
	
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
	int iSlot = TF2_GetSlot(iWeapon);
	
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		int iClassSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
		if (iClassSlot == iSlot)
			return view_as<TFClassType>(iClass);
	}
	
	return TFClass_Unknown;
}

stock void TF2_RemoveItem(int iClient, int iWeapon)
{
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	if (StrContains(sClassname, "tf_wearable") == 0)
	{
		//If wearable, just simply use TF2_RemoveWearable
		TF2_RemoveWearable(iClient, iWeapon);
		return;
	}
	
	int iExtraWearable = GetEntPropEnt(iWeapon, Prop_Send, "m_hExtraWearable");
	if (iExtraWearable != -1)
		TF2_RemoveWearable(iClient, iExtraWearable);
	
	iExtraWearable = GetEntPropEnt(iWeapon, Prop_Send, "m_hExtraWearableViewModel");
	if (iExtraWearable != -1)
		TF2_RemoveWearable(iClient, iExtraWearable);
	
	RemovePlayerItem(iClient, iWeapon);
	RemoveEntity(iWeapon);
}

stock int TF2_GetItemFromAmmoType(int iClient, int iAmmoType)
{
	int iWeapon;
	int iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		if (HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType") && GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType") == iAmmoType)
			return iWeapon;
	}
	
	return -1;
}

stock int TF2_SpawnParticle(const char[] sParticle, int iEntity)
{
	int iParticle = CreateEntityByName("info_particle_system");
	DispatchKeyValue(iParticle, "effect_name", sParticle);
	DispatchSpawn(iParticle);
	
	float vecOrigin[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecOrigin);
	TeleportEntity(iParticle, vecOrigin, NULL_VECTOR, NULL_VECTOR);
	
	SetVariantString("!activator");
	AcceptEntityInput(iParticle, "SetParent", iEntity);
	
	SetVariantString("weapon_bone_L");
	AcceptEntityInput(iParticle, "SetParentAttachment");
	
	//Return ref of entity
	return EntIndexToEntRef(iParticle);
}

stock int CanKeepWeapon(int iClient, const char[] sClassname, int iIndex)
{
	//Allow keep grappling hook and passtime gun
	if (g_bAllowGiveNamedItem || StrEqual(sClassname, "tf_weapon_grapplinghook") || StrEqual(sClassname, "tf_weapon_passtime_gun"))
		return true;
	
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		//Allow keep if randomizer weapon has same index, otherwise disallow
		int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
		if (0 <= iSlot <= WeaponSlot_BuilderEngie)
			return false;
	}
	
	//Allow keep cosmetics
	return true;
}

stock int PrecacheParticleSystem(const char[] sParticle)
{
	static int iParticleEffectNames = INVALID_STRING_TABLE;
	if (iParticleEffectNames == INVALID_STRING_TABLE)
		if ((iParticleEffectNames = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE)
			return INVALID_STRING_INDEX;
	
	int iIndex = FindStringIndex2(iParticleEffectNames, sParticle);
	if (iIndex == INVALID_STRING_INDEX)
	{
		int iNumStrings = GetStringTableNumStrings(iParticleEffectNames);
		if (iNumStrings >= GetStringTableMaxStrings(iParticleEffectNames))
			return INVALID_STRING_INDEX;
		
		AddToStringTable(iParticleEffectNames, sParticle);
		iIndex = iNumStrings;
	}

	return iIndex;
}

stock int FindStringIndex2(int iTableId, const char[] sParticle)
{
	char sBuffer[1024];
	int iNumStrings = GetStringTableNumStrings(iTableId);
	for (int i = 0; i < iNumStrings; i++)
	{
		ReadStringTable(iTableId, i, sBuffer, sizeof(sBuffer));
		if (StrEqual(sBuffer, sParticle))
			return i;
	}

	return INVALID_STRING_INDEX;
}