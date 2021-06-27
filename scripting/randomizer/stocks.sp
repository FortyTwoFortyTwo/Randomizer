stock int TF2_CreateWeapon(int iClient, int iIndex, int iSlot)
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
		bSapper = true;
		
		//tf_weapon_sapper is bad and give client crashes
		sClassname = "tf_weapon_builder";
	}
	
	int iWeapon = CreateEntityByName(sClassname);
	if (IsValidEntity(iWeapon))
	{
		SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iIndex);
		SetEntProp(iWeapon, Prop_Send, "m_bInitialized", 1);
		
		SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", TFQual_Unique);
		SetEntProp(iWeapon, Prop_Send, "m_iEntityLevel", 1);
		
		if (bSapper)
		{
			SetEntProp(iWeapon, Prop_Send, "m_iObjectType", TFObject_Sapper);
			SetEntProp(iWeapon, Prop_Data, "m_iSubType", TFObject_Sapper);
		}
		
		DispatchSpawn(iWeapon);
		
		//Reset charge meter
		SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, iSlot);
	}
	else
	{
		PrintToChat(iClient, "Unable to create weapon! index (%d) classname (%s)", iIndex, sClassname);
		LogError("Unable to create weapon! index (%d), classname (%s)", iIndex, sClassname);
	}
	
	return iWeapon;
}

stock int TF2_GiveNamedItem(int iClient, Address pItem, int iSlot)
{
	int iIndex = LoadFromAddress(pItem + view_as<Address>(g_iOffsetItemDefinitionIndex), NumberType_Int16);
	int iSubType = 0;
	TFClassType nClassBuilder = TFClass_Unknown;
	
	char sClassname[256];
	TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
	
	//We want to translate classname to correct classname AND slot wanted
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		int iClassSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
		if (iClassSlot == iSlot)
		{
			TF2Econ_TranslateWeaponEntForClass(sClassname, sizeof(sClassname), view_as<TFClassType>(iClass));
			
			if (StrEqual(sClassname, "tf_weapon_builder") || StrEqual(sClassname, "tf_weapon_sapper"))
				nClassBuilder = view_as<TFClassType>(iClass);
			
			break;
		}
	}
	
	if (nClassBuilder == TFClass_Spy)
		iSubType = view_as<int>(TFObject_Sapper);
	
	g_bAllowGiveNamedItem = true;
	int iWeapon = SDKCall_GiveNamedItem(iClient, sClassname, iSubType, pItem, true);
	g_bAllowGiveNamedItem = false;
	
	if (nClassBuilder == TFClass_Engineer)
	{
		SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", true, _, view_as<int>(TFObject_Dispenser));
		SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", true, _, view_as<int>(TFObject_Teleporter));
		SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", true, _, view_as<int>(TFObject_Sentry));
		SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", false, _, view_as<int>(TFObject_Sapper));
	}
	
	return iWeapon;
}

stock int TF2_EquipWeapon(int iClient, int iWeapon)
{
	SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true);
	
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
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
}

stock Address TF2_FindReskinItem(int iClient, int iIndex)
{
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		int iSlot = TF2Econ_GetItemLoadoutSlot(iIndex, view_as<TFClassType>(iClass));
		Address pItem = SDKCall_GetLoadoutItem(iClient, view_as<TFClassType>(iClass), iSlot);
		if (TF2_IsValidEconItemView(pItem) && Weapons_GetReskinIndex(LoadFromAddress(pItem + view_as<Address>(g_iOffsetItemDefinitionIndex), NumberType_Int16)) == iIndex)
			return pItem;
	}
	
	return Address_Null;
}

stock bool TF2_IsValidEconItemView(Address pItem)
{
	if (!pItem)
		return false;
	
	int iIndex = LoadFromAddress(pItem + view_as<Address>(g_iOffsetItemDefinitionIndex), NumberType_Int16);
	
	// 65535 is basically unsigned -1 in int16
	return 0 <= iIndex < 65535;
}

stock bool TF2_WeaponFindAttribute(int iWeapon, char[] sAttrib, float &flVal)
{
	Address pAttrib = TF2Attrib_GetByName(iWeapon, sAttrib);
	if (pAttrib != Address_Null)
	{
		flVal = TF2Attrib_GetValue(pAttrib);
		return true;
	}
	
	return false;
}

stock bool TF2_IndexFindAttribute(int iIndex, const char[] sAttrib, float &flVal)
{
	ArrayList aAttribs = TF2Econ_GetItemStaticAttributes(iIndex);
	int iAttrib = TF2Econ_TranslateAttributeNameToDefinitionIndex(sAttrib);
	
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
	//Could be looped through client slots, but would cause issues with >1 weapons in same slot
	
	static int iMaxWeapons;
	if (!iMaxWeapons)
		iMaxWeapons = GetEntPropArraySize(iClient, Prop_Send, "m_hMyWeapons");
	
	//Loop though all weapons (non-wearables)
	while (iPos < iMaxWeapons)
	{
		iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", iPos);
		iPos++;
		
		if (iWeapon > MaxClients)
			return true;
		
		//Reset iWeapon for wearable loop below
		if (iPos == iMaxWeapons)
			iWeapon = MaxClients+1;
	}
	
	//Loop through all weapon wearables (don't allow cosmetics)
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
	int iSlot = TF2Econ_GetItemLoadoutSlot(iIndex, nClass);
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

stock TFClassType TF2_GetDefaultClassFromItem(int iWeapon)
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

stock TFClassType TF2_GetRandomClass()
{
	return view_as<TFClassType>(GetRandomInt(CLASS_MIN, CLASS_MAX));
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
	
	//Below similar to TF2_RemoveWeaponSlot, but only removes 1 weapon instead of all weapons in 1 slot
	
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
	//Only primary, secondary and melee should have ammo, keep this simple for optimization
	for (int iSlot = 0; iSlot <= WeaponSlot_Melee; iSlot++)
	{
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
		if (iWeapon > MaxClients && GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType") == iAmmoType)
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

stock bool ItemIsAllowed(int iIndex)
{
	if (GameRules_GetProp("m_bPlayingMedieval") || (GameRules_GetRoundState() == RoundState_Stalemate && FindConVar("mp_stalemate_meleeonly").BoolValue))
	{
		//TF2 hack!
		char sClassname[256];
		TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
		if (StrEqual(sClassname, "tf_weapon_passtime_gun"))
			return true;
		
		//For medieval and melee stalemate, allow melee and spy PDA
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
			if (iSlot == WeaponSlot_Melee)
				return true;
			else if ((iSlot == WeaponSlot_PDADisguise || iSlot == WeaponSlot_InvisWatch) && view_as<TFClassType>(iClass) == TFClass_Spy)
				return true;
		}
		
		//For medieval, allow medieval weapons
		if (GameRules_GetProp("m_bPlayingMedieval"))
		{
			float flVal;
			if (TF2_IndexFindAttribute(iIndex, "allowed in medieval mode", flVal) && flVal)
				return true;
		}
		
		return false;
	}
	
	return true;
}

stock bool CanKeepWeapon(int iClient, const char[] sClassname, int iIndex)
{
	if (g_bAllowGiveNamedItem || !IsWeaponRandomized(iClient))
		return true;
	
	//Allow grappling hook and passtime gun
	if (StrEqual(sClassname, "tf_weapon_grapplinghook") || StrEqual(sClassname, "tf_weapon_passtime_gun"))
		return true;
	
	//Don't allow weapons from client loadout slots
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
		if (WeaponSlot_Primary <= iSlot <= WeaponSlot_BuilderEngie)
			return false;
	}
	
	//Allow cosmetics
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