enum struct RandomizedLoadout
{
	TFClassType nClass;		//Class
	ArrayList aWeapons[CLASS_MAX+1];	//Arrays of RandomizedWeapon to set
	
	int iNextCosmeticId;	//Cosmetic id to use on refresh
	int iCurrentCosmeticId;	//Current cosmetic id 
	
	int iNextRuneType;		//Rune type to use on refresh
	int iCurrentRuneType;	//Current rune type
	
	bool bRerollSpell;		//Should client's spell be rerolled
	int iSpellIndex;		//Spell index to set
	
	bool bRandomized[RandomizedType_MAX];	//Is client currently randomized from type?
	
	int iClient;	//Client index if has one
	int iGroup;		//Group index if has one
	
	void Reset()
	{
		this.nClass = TFClass_Unknown;
		
		Loadout_RemoveWeapons(this);
		
		this.iNextCosmeticId = -1;
		this.iCurrentCosmeticId = -1;
		
		this.iNextRuneType = -1;
		this.iCurrentRuneType = -1;
		
		this.bRerollSpell = false;
		this.iSpellIndex = -1;
	}
	
	void AddWeapon(RandomizedWeapon eWeapon, int iClass)
	{
		if (eWeapon.iIndex == -1)
			return;
		
		if (!this.aWeapons[iClass])
			this.aWeapons[iClass] = new ArrayList(sizeof(RandomizedWeapon));
		
		this.aWeapons[iClass].PushArray(eWeapon);
	}
	
	void CopyWeapons(ArrayList aCopy[CLASS_MAX+1])
	{
		for (int iClass = 0; iClass < sizeof(aCopy); iClass++)
		{
			if (!aCopy[iClass])
			{
				delete this.aWeapons[iClass];
				continue;
			}
			
			//Copy array, then fill iRef to any same data
			ArrayList aOld = this.aWeapons[iClass];
			this.aWeapons[iClass] = aCopy[iClass].Clone();
			
			if (!aOld)
				continue;
			
			int iOldLength = aOld.Length;
			int iNewLength = this.aWeapons[iClass].Length;
			for (int iOldPos = 0; iOldPos < iOldLength; iOldPos++)
			{
				RandomizedWeapon eOldWeapon, eNewWeapon;
				aOld.GetArray(iOldPos, eOldWeapon);
				
				if (eOldWeapon.iRef == INVALID_ENT_REFERENCE || !IsValidEntity(eOldWeapon.iRef))
					continue;
				
				for (int iNewPos = 0; iNewPos < iNewLength; iNewPos++)
				{
					this.aWeapons[iClass].GetArray(iNewPos, eNewWeapon);
					if (eOldWeapon.iIndex == eNewWeapon.iIndex && eOldWeapon.iSlot == eNewWeapon.iSlot && eNewWeapon.iRef == INVALID_ENT_REFERENCE)
					{
						this.aWeapons[iClass].Set(iNewPos, eOldWeapon.iRef, RandomizedWeapon::iRef);
						break;
					}
				}
			}
			
			delete aOld;
		}
	}
	
	bool HasWeapon(int iWeapon, TFClassType nClass)
	{
		if (iWeapon == INVALID_ENT_REFERENCE || !this.aWeapons[nClass])
			return false;
		
		int iRef = EntIndexToEntRef(iWeapon);
		return this.aWeapons[nClass].FindValue(iRef, RandomizedWeapon::iRef) != -1;
	}
	
	void SetSpellIndex(int iIndex, bool bForce)
	{
		this.bRerollSpell = bForce;
		this.iSpellIndex = iIndex;
	}
	
	void GetInfo(RandomizedType nType, RandomizedInfo eInfo)
	{
		if (this.iClient != -1)
			Group_GetInfoFromClient(this.iClient, nType, eInfo);
		else if (this.iGroup != -1)
			Group_GetInfoFromPos(this.iGroup, eInfo);
	}
}

static RandomizedLoadout g_eLoadoutClient[MAXPLAYERS];
static RandomizedLoadout g_eLoadoutGroup[MAX_GROUPS];

static int g_iRandomizeCosmeticId;

static const int g_iLoadoutSlotWeapons[] = {
	LoadoutSlot_Primary,
	LoadoutSlot_Secondary,
	LoadoutSlot_Melee,
	LoadoutSlot_Building,
	LoadoutSlot_PDA,
	LoadoutSlot_PDA2,
};
	
static const int g_iLoadoutSlotCosmetics[] = {
	LoadoutSlot_Head,
	LoadoutSlot_Misc,
	LoadoutSlot_Misc2
};

void Loadout_Init()
{
	for (int i = 0; i < sizeof(g_eLoadoutClient); i++)
	{
		g_eLoadoutClient[i].Reset();
		g_eLoadoutClient[i].iClient = i;
		g_eLoadoutClient[i].iGroup = -1;
	}
	
	for (int i = 0; i < sizeof(g_eLoadoutGroup); i++)
	{
		g_eLoadoutGroup[i].Reset();
		g_eLoadoutGroup[i].iClient = -1;
		g_eLoadoutGroup[i].iGroup = i;
	}
}

// General

void Loadout_Randomize(RandomizedLoadout eLoadout, RandomizedType nType)
{
	switch (nType)
	{
		case RandomizedType_Class: Loadout_RandomizeClass(eLoadout);
		case RandomizedType_Weapons: Loadout_RandomizeWeapon(eLoadout);
		case RandomizedType_Cosmetics: Loadout_RandomizeCosmetics(eLoadout);
		case RandomizedType_Rune: Loadout_RandomizeRune(eLoadout);
		case RandomizedType_Spells: Loadout_RandomizeSpells(eLoadout);
	}
}

void Loadout_CopyGroupInfoToClient(int iClient, int iPos, RandomizedType nType)
{
	switch (nType)
	{
		case RandomizedType_Class: g_eLoadoutClient[iClient].nClass = g_eLoadoutGroup[iPos].nClass;
		case RandomizedType_Weapons: g_eLoadoutClient[iClient].CopyWeapons(g_eLoadoutGroup[iPos].aWeapons);
		case RandomizedType_Cosmetics: g_eLoadoutClient[iClient].iNextCosmeticId = g_eLoadoutGroup[iPos].iNextCosmeticId;
		case RandomizedType_Rune: g_eLoadoutClient[iClient].iNextRuneType = g_eLoadoutGroup[iPos].iNextRuneType;
		case RandomizedType_Spells: g_eLoadoutClient[iClient].SetSpellIndex(g_eLoadoutGroup[iPos].iSpellIndex, g_eLoadoutGroup[iPos].bRerollSpell);
	}
}

void Loadout_ResetClientInfo(int iClient, RandomizedType nType)
{
	switch (nType)
	{
		case RandomizedType_Class: g_eLoadoutClient[iClient].nClass = TFClass_Unknown;
		case RandomizedType_Weapons: Loadout_RemoveWeapons(g_eLoadoutClient[iClient]);
		case RandomizedType_Cosmetics: g_eLoadoutClient[iClient].iNextCosmeticId = -1;
		case RandomizedType_Rune: g_eLoadoutClient[iClient].iNextRuneType = -1;
		case RandomizedType_Spells: g_eLoadoutClient[iClient].SetSpellIndex(-1, false);
	}
}

void Loadout_ApplyClientLoadout(int iClient, RandomizedType nType)
{
	switch (nType)
	{
		case RandomizedType_Class: Loadout_ApplyClientClass(iClient);
		case RandomizedType_Weapons: Loadout_ApplyClientWeapons(iClient);
		case RandomizedType_Cosmetics: Loadout_ApplyClientCosmetics(iClient, g_iLoadoutSlotCosmetics, sizeof(g_iLoadoutSlotCosmetics));
		case RandomizedType_Rune: Loadout_ApplyClientRune(iClient);
		case RandomizedType_Spells: Loadout_ApplyClientSpells(iClient);
	}
}

void Loadout_ClearClientLoadout(int iClient, RandomizedType nType)
{
	switch (nType)
	{
	//	case RandomizedType_Class: {};
		case RandomizedType_Weapons: Loadout_ResetClientLoadout(iClient, g_iLoadoutSlotWeapons, sizeof(g_iLoadoutSlotWeapons));
		case RandomizedType_Cosmetics: Loadout_ResetClientLoadout(iClient, g_iLoadoutSlotCosmetics, sizeof(g_iLoadoutSlotCosmetics));
		case RandomizedType_Rune: Loadout_ResetClientRune(iClient);
	//	case RandomizedType_Spells: {};
	}
}

void Loadout_RandomizeClient(int iClient, RandomizedType nType)
{
	Loadout_Randomize(g_eLoadoutClient[iClient], nType);
	g_bClientRefresh[iClient] = true;
}

void Loadout_RandomizeClientAll(int iClient)
{
	for (RandomizedType nType; nType < RandomizedType_MAX; nType++)
	{
		if (Group_IsClientRandomized(iClient, nType) && Group_GetClientSameInfoPos(iClient, nType) == -1)
			Loadout_RandomizeClient(iClient, nType);
	}
}

void Loadout_RandomizeGroup(int iPos)
{
	//Only randomize if it for "same" param
	RandomizedInfo eInfo;
	Group_GetInfoFromPos(iPos, eInfo);
	if (!eInfo.bSame)
		return;
	
	Loadout_Randomize(g_eLoadoutGroup[iPos], eInfo.nType);
	
	int[] iGroupList = new int[MaxClients];
	int iGroupCount = Group_GetAllGroupList(eInfo, iGroupList);
	for (int i = 0; i < iGroupCount; i++)
		g_bClientRefresh[iGroupList[i]] = true;
}

void Loadout_UpdateClientInfo(int iClient)
{
	for (RandomizedType nType; nType < RandomizedType_MAX; nType++)
	{
		if (Group_IsClientRandomized(iClient, nType))
		{
			int iPos = Group_GetClientSameInfoPos(iClient, nType);
			if (iPos != -1)
				Loadout_CopyGroupInfoToClient(iClient, iPos, nType);
		}
		else
		{
			Loadout_ResetClientInfo(iClient, nType);
		}
	}
}

void Loadout_RefreshClient(int iClient)
{
	g_bClientRefresh[iClient] = false;
	
	if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))	//Player will regardless get refreshed on spawn
		return;
	
	Loadout_UpdateClientInfo(iClient);
	
	for (RandomizedType nType; nType < RandomizedType_MAX; nType++)
	{
		if (Group_IsClientRandomized(iClient, nType))
		{
			Loadout_ApplyClientLoadout(iClient, nType);
			g_eLoadoutClient[iClient].bRandomized[nType] = true;
		}
		else if (g_eLoadoutClient[iClient].bRandomized[nType])
		{
			Loadout_ClearClientLoadout(iClient, nType);
			g_eLoadoutClient[iClient].bRandomized[nType] = false;
		}
	}
}

void Loadout_ResetClientLoadout(int iClient, const int[] iSlots, int iCount)
{
	//Remove all items using its slot
	int iItem, iPos;
	while (TF2_GetItem(iClient, iItem, iPos, true))
	{
		int iIndex = GetEntProp(iItem, Prop_Send, "m_iItemDefinitionIndex");
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			int iSlot = TF2Econ_GetItemLoadoutSlot(iIndex, view_as<TFClassType>(iClass));
			for (int i = 0; i < iCount; i++)
			{
				if (iSlot == iSlots[i])
				{
					TF2_RemoveItem(iClient, iItem);
					continue;
				}
			}
		}
	}
	
	//Give default items
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	for (int i = 0; i < iCount; i++)
	{
		Address pItem = SDKCall_GetLoadoutItem(iClient, nClass, iSlots[i]);
		if (TF2_IsValidEconItemView(pItem))
			TF2_EquipWeapon(iClient, TF2_GiveNamedItem(iClient, pItem));
	}
}

// Class

void Loadout_RandomizeClass(RandomizedLoadout eLoadout)
{
	eLoadout.nClass = TF2_GetRandomClass();
}

void Loadout_SetClass(int[] iClients, int iCount, TFClassType nClass)
{
	for (int i = 0; i < sizeof(g_eLoadoutGroup); i++)
	{
		if (Group_CanRandomizePosForClients(i, RandomizedType_Class, iClients, iCount))
			g_eLoadoutGroup[i].nClass = nClass;
	}
	
	for (int i = 0; i < iCount; i++)
	{
		g_eLoadoutClient[iClients[i]].nClass = nClass;
		Loadout_RefreshClient(iClients[i]);
	}
}

TFClassType Loadout_GetClientClass(int iClient)
{
	return g_eLoadoutClient[iClient].nClass;
}

void Loadout_ApplyClientClass(int iClient)
{
	int iOldMaxHealth = SDKCall_GetMaxHealth(iClient);
	int iOldHealth = GetEntProp(iClient, Prop_Send, "m_iHealth");
	
	TF2_SetPlayerClass(iClient, g_eLoadoutClient[iClient].nClass);
	
	int iMaxHealth = SDKCall_GetMaxHealth(iClient);
	int iHealth = RoundToCeil(float(iMaxHealth) / float(iOldMaxHealth) * float(iOldHealth));
	SetEntProp(iClient, Prop_Send, "m_iHealth", iHealth);
	
	if (g_eLoadoutClient[iClient].nClass != TFClass_Spy && TF2_IsPlayerInCondition(iClient, TFCond_Disguised))
		TF2_RemoveCondition(iClient, TFCond_Disguised);
}

// Weapons

void Loadout_RandomizeWeapon(RandomizedLoadout eLoadout)
{
	Loadout_RemoveWeapons(eLoadout);
	
	RandomizedInfo eInfo;
	eLoadout.GetInfo(RandomizedType_Weapons, eInfo);
	
	int iMinCount = eInfo.iCount;
	
	int iSlotMinCount;
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_Melee; iSlot++)
		iSlotMinCount += eInfo.iCountSlot[iSlot];
	
	if (iMinCount > iSlotMinCount)
		iMinCount -= iSlotMinCount;
	else if (iMinCount <= iSlotMinCount)
		iMinCount = 0;
	
	if (eInfo.bDefaultClass)
	{
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			int iSlotCount[WeaponSlot_Melee+1];
			iSlotCount = eInfo.iCountSlot;
			
			for (int i = 0; i < iMinCount; i++)
			{
				RandomizedWeapon eWeapon;
				eWeapon.Reset();
				eWeapon.iIndex = Weapons_GetRandomIndex(view_as<TFClassType>(iClass));
				eWeapon.iSlot = TF2_GetSlotFromIndex(eWeapon.iIndex, view_as<TFClassType>(iClass));
				eLoadout.AddWeapon(eWeapon, iClass);
				
				if (WeaponSlot_Primary <= eWeapon.iSlot <= WeaponSlot_Melee && iSlotCount[eWeapon.iSlot] > 0)
				{
					//General random used one of min slot count, allow another general random
					iSlotCount[eWeapon.iSlot]--;
					iMinCount++;
				}
			}
			
			//Fill remaining as force slot
			RandomizedWeapon eWeapon;
			eWeapon.Reset();
			for (eWeapon.iSlot = WeaponSlot_Primary; eWeapon.iSlot <= WeaponSlot_Melee; eWeapon.iSlot++)
			{
				for (int i = 0; i < iSlotCount[eWeapon.iSlot]; i++)
				{
					eWeapon.iIndex = Weapons_GetRandomIndex(view_as<TFClassType>(iClass), eWeapon.iSlot);
					eLoadout.AddWeapon(eWeapon, iClass);
				}
			}
		}
	}
	else
	{
		int iSlotCount[WeaponSlot_Melee+1];
		iSlotCount = eInfo.iCountSlot;
		
		for (int i = 0; i < iMinCount; i++)
		{
			RandomizedWeapon eWeapon;
			eWeapon.Reset();
			eWeapon.iIndex = Weapons_GetRandomIndex();
			
			//Pick random slot
			do
			{
				eWeapon.iSlot = TF2_GetSlotFromIndex(eWeapon.iIndex, TF2_GetRandomClass());
			}
			while (eWeapon.iSlot == -1);
			
			for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
				eLoadout.AddWeapon(eWeapon, iClass);
			
			if (WeaponSlot_Primary <= eWeapon.iSlot <= WeaponSlot_Melee && iSlotCount[eWeapon.iSlot] > 0)
			{
				//General random used one of min slot count, allow another general random
				iSlotCount[eWeapon.iSlot]--;
				iMinCount++;
			}
		}
		
		//Fill remaining as force slot
		RandomizedWeapon eWeapon;
		eWeapon.Reset();
		for (eWeapon.iSlot = WeaponSlot_Primary; eWeapon.iSlot <= WeaponSlot_Melee; eWeapon.iSlot++)
		{
			for (int i = 0; i < iSlotCount[eWeapon.iSlot]; i++)
			{
				eWeapon.iIndex = Weapons_GetRandomIndex(TFClass_Unknown, eWeapon.iSlot);
				for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
					eLoadout.AddWeapon(eWeapon, iClass);
			}
		}
	}
	
	//Randomize PDAs based on class (engineer & spy)
	RandomizedWeapon eWeapon;
	eWeapon.Reset();
	for (eWeapon.iSlot = WeaponSlot_PDA; eWeapon.iSlot <= WeaponSlot_Building; eWeapon.iSlot++)
	{
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			eWeapon.iIndex = Weapons_GetRandomIndex(view_as<TFClassType>(iClass), eWeapon.iSlot);
			eLoadout.AddWeapon(eWeapon, iClass);
		}
	}
}

ArrayList Loadout_GetClientWeapons(int iClient, TFClassType nClass)
{
	return g_eLoadoutClient[iClient].aWeapons[nClass];
}

void Loadout_ApplyClientWeapons(int iClient)
{
	Properties_SaveActiveWeaponAmmo(iClient);
	
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	
	int iWeapon, iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		if (CanEquipIndex(iClient, iIndex))
			continue;
		
		if (!g_eLoadoutClient[iClient].HasWeapon(iWeapon, nClass))
			TF2_RemoveItem(iClient, iWeapon);
	}
	
	ArrayList aWeapons = g_eLoadoutClient[iClient].aWeapons[nClass];
	if (!aWeapons)
		return;
	
	int iLength = aWeapons.Length;
	for (int i = 0; i < iLength; i++)
	{
		RandomizedWeapon eWeapon;
		aWeapons.GetArray(i, eWeapon);
		
		if (eWeapon.iRef != INVALID_ENT_REFERENCE && !IsValidEntity(eWeapon.iRef))
			eWeapon.iRef = INVALID_ENT_REFERENCE;
		
		if (!ItemIsAllowed(eWeapon.iIndex))
			continue;
		
		if (eWeapon.iRef == INVALID_ENT_REFERENCE)
		{
			Address pItem = TF2_FindReskinItem(iClient, eWeapon.iIndex);
			if (pItem)
				iWeapon = TF2_GiveNamedItem(iClient, pItem, eWeapon.iSlot);
			else
				iWeapon = TF2_CreateWeapon(iClient, eWeapon.iIndex, eWeapon.iSlot);
			
			//CTFPlayer::ItemsMatch doesnt like normal item quality, so lets use unique instead
			if (view_as<TFQuality>(GetEntProp(iWeapon, Prop_Send, "m_iEntityQuality")) == TFQual_Normal)
				SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", TFQual_Unique);
			
			aWeapons.Set(i, EntIndexToEntRef(iWeapon), RandomizedWeapon::iRef);
		}
		else
		{
			iWeapon = EntRefToEntIndex(eWeapon.iRef);
		}
		
		if (GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity") != iClient)	//Is weapon not equipped yet?
		{
			TF2_EquipWeapon(iClient, iWeapon);
			
			//Fill charge meter
			if (!TF2Attrib_HookValueFloat(0.0, "item_meter_resupply_denied", iWeapon))
				Properties_AddWeaponChargeMeter(iClient, iWeapon, 100.0);
		}
	}
	
	//After all weapons has been given, fill ammo
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		if (!HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType"))
			continue;
		
		int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
		if (iAmmoType == -1)
			continue;
		
		int iMaxAmmo = TF2_GetMaxAmmo(iClient, iWeapon, iAmmoType);
		int iAmmo = TF2_GiveAmmo(iClient, iWeapon, 0, iMaxAmmo, iAmmoType, true, kAmmoSource_Resupply);
		Properties_SetWeaponPropInt(iWeapon, "m_iAmmo", iAmmo);
		if (iWeapon == GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon"))
			Properties_UpdateActiveWeaponAmmo(iClient);
	}
	
	//Set active weapon if dont have one
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != INVALID_ENT_REFERENCE)
		return;
	
	for (int iSlot = LoadoutSlot_Primary; iSlot <= LoadoutSlot_PDA2; iSlot++)
	{
		while (TF2_GetItemFromLoadoutSlot(iClient, iSlot, iWeapon, iPos))
		{
			if (TF2_CanSwitchTo(iClient, iWeapon))
			{
				TF2_SwitchToWeapon(iClient, iWeapon);
				return;
			}
		}
	}
}

void Loadout_AddWeapon(RandomizedLoadout eLoadout, RandomizedWeapon eList[MAX_WEAPONS], int iListCount)
{
	RandomizedInfo eInfo;
	eLoadout.GetInfo(RandomizedType_Weapons, eInfo);
	
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		for (int i = 0; i < iListCount; i++)
		{
			if (eList[i].iSlot > WeaponSlot_Melee || eInfo.bDefaultClass)
			{
				//Add index to each classes if default class or PDAs
				if (TF2_GetSlotFromIndex(eList[i].iIndex, view_as<TFClassType>(iClass)) == eList[i].iSlot)
					eLoadout.AddWeapon(eList[i], iClass);
			}
			else
			{
				//Add index to all classes
				eLoadout.AddWeapon(eList[i], iClass);
			}
		}
	}
}

void Loadout_RemoveWeapons(RandomizedLoadout eLoadout, int iSlot = -1)
{
	for (int i = 0; i < sizeof(RandomizedLoadout::aWeapons); i++)
	{
		if (!eLoadout.aWeapons[i])
			continue;
		
		int iLength = eLoadout.aWeapons[i].Length;
		for (int iPos = iLength - 1; iPos >= 0; iPos--)
		{
			RandomizedWeapon eWeapon;
			eLoadout.aWeapons[i].GetArray(iPos, eWeapon);
			if (iSlot != -1 && iSlot != eWeapon.iSlot)
				continue;
			
			if (eWeapon.iRef != INVALID_ENT_REFERENCE && IsValidEntity(eWeapon.iRef))
				TF2_RemoveItem(eLoadout.iClient, EntRefToEntIndex(eWeapon.iRef));
			
			eLoadout.aWeapons[i].Erase(iPos);
		}
		
		if (iSlot == -1)
			delete eLoadout.aWeapons[i];
	}
}

void Loadout_SetWeapon(int[] iClients, int iCount, RandomizedWeapon eList[MAX_WEAPONS], int iListCount)
{
	for (int i = 0; i < sizeof(g_eLoadoutGroup); i++)
	{
		if (Group_CanRandomizePosForClients(i, RandomizedType_Weapons, iClients, iCount))
		{
			Loadout_RemoveWeapons(g_eLoadoutGroup[i]);
			Loadout_AddWeapon(g_eLoadoutGroup[i], eList, iListCount);
		}
	}
	
	for (int i = 0; i < iCount; i++)
	{
		Loadout_RemoveWeapons(g_eLoadoutClient[iClients[i]]);
		Loadout_AddWeapon(g_eLoadoutClient[iClients[i]], eList, iListCount);
		Loadout_RefreshClient(iClients[i]);
	}
}

void Loadout_SetSlotWeapon(int[] iClients, int iCount, RandomizedWeapon eList[MAX_WEAPONS], int iListCount)
{
	for (int i = 0; i < sizeof(g_eLoadoutGroup); i++)
	{
		if (Group_CanRandomizePosForClients(i, RandomizedType_Weapons, iClients, iCount))
		{
			bool bSlot[WeaponSlot_Building+1];
			
			for (int j = 0; j < iCount; j++)
			{
				if (!bSlot[eList[j].iSlot])
				{
					Loadout_RemoveWeapons(g_eLoadoutGroup[i], eList[j].iSlot);
					bSlot[eList[j].iSlot] = true;
				}
			}
			
			Loadout_AddWeapon(g_eLoadoutGroup[i], eList, iListCount);
		}
	}
	
	for (int i = 0; i < iCount; i++)
	{
		bool bSlot[WeaponSlot_Building+1];
		
		for (int j = 0; j < iCount; j++)
		{
			if (!bSlot[eList[j].iSlot])
			{
				Loadout_RemoveWeapons(g_eLoadoutClient[iClients[i]], eList[j].iSlot);
				bSlot[eList[j].iSlot] = true;
			}
		}
		
		Loadout_AddWeapon(g_eLoadoutClient[iClients[i]], eList, iListCount);
		Loadout_RefreshClient(iClients[i]);
	}
}

void Loadout_GiveWeapon(int[] iClients, int iCount, RandomizedWeapon eList[MAX_WEAPONS], int iListCount)
{
	for (int i = 0; i < sizeof(g_eLoadoutGroup); i++)
	{
		if (Group_CanRandomizePosForClients(i, RandomizedType_Weapons, iClients, iCount))
			Loadout_AddWeapon(g_eLoadoutGroup[i], eList, iListCount);
	}
	
	for (int i = 0; i < iCount; i++)
	{
		Loadout_AddWeapon(g_eLoadoutClient[iClients[i]], eList, iListCount);
		Loadout_RefreshClient(iClients[i]);
	}
}

// Cosmetics

void Loadout_RandomizeCosmetics(RandomizedLoadout eLoadout)
{
	eLoadout.iNextCosmeticId = g_iRandomizeCosmeticId;
	g_iRandomizeCosmeticId++;
}

void Loadout_ApplyClientCosmetics(int iClient, const int[] iSlots, int iSlotCount)
{
	if (g_eLoadoutClient[iClient].iCurrentCosmeticId == g_eLoadoutClient[iClient].iNextCosmeticId)
		return;	//Dont need to reroll cosmetics
	
	g_eLoadoutClient[iClient].iCurrentCosmeticId = g_eLoadoutClient[iClient].iNextCosmeticId;
	
	//Destroy any cosmetics left
	int iWearableCount = TF2_GetWearableCount(iClient);
	for (int i = 0; i < iWearableCount; i++)
	{
		int iWearable = TF2_GetWearable(iClient, i);
		if (iWearable == INVALID_ENT_REFERENCE)
			continue;
		
		int iIndex = GetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex");
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
			if (iSlot == LoadoutSlot_Misc)
			{
				TF2_RemoveItem(iClient, iWearable);
				continue;
			}
		}
	}
	
	RandomizedInfo eGroup;
	Group_GetInfoFromClient(iClient, RandomizedType_Cosmetics, eGroup);
	
	int iMaxCosmetics = eGroup.iCount;
	if (iMaxCosmetics == 0)	//Good ol TF2 2007
		return;
		
	Address[] pPossibleItems = new Address[CLASS_MAX * iSlotCount];
	int iPossibleCount;
	
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		for (int i = 0; i < iSlotCount; i++)
		{
			Address pItem = SDKCall_GetLoadoutItem(iClient, view_as<TFClassType>(iClass), iSlots[i]);
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
	
	if (eGroup.bConflicts)
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

// Rune

void Loadout_RandomizeRune(RandomizedLoadout eLoadout)
{
	eLoadout.iNextRuneType = GetRandomInt(0, g_iRuneCount - 1);
}

void Loadout_SetRune(int[] iClients, int iCount, int iRuneType)
{
	for (int i = 0; i < sizeof(g_eLoadoutGroup); i++)
	{
		if (Group_CanRandomizePosForClients(i, RandomizedType_Rune, iClients, iCount))
			g_eLoadoutGroup[i].iNextRuneType = iRuneType;
	}
	
	for (int i = 0; i < iCount; i++)
	{
		g_eLoadoutClient[iClients[i]].iNextRuneType = iRuneType;
		Loadout_RefreshClient(iClients[i]);
	}
}

void Loadout_ApplyClientRune(int iClient)
{
	SDKCall_SetCarryingRuneType(GetEntityAddress(iClient) + view_as<Address>(g_iOffsetPlayerShared), g_eLoadoutClient[iClient].iNextRuneType);
	g_eLoadoutClient[iClient].iCurrentRuneType = g_eLoadoutClient[iClient].iNextRuneType;
}

public Action Loadout_TimerApplyClientRune(Handle hTimer, int iClient)
{
	if (IsClientInGame(iClient))
		Loadout_ApplyClientRune(iClient);
	
	return Plugin_Continue;
}

void Loadout_ResetClientRune(int iClient)
{
	if (g_eLoadoutClient[iClient].iCurrentRuneType != -1)
	{
		SDKCall_SetCarryingRuneType(GetEntityAddress(iClient) + view_as<Address>(g_iOffsetPlayerShared), -1);
		g_eLoadoutClient[iClient].iCurrentRuneType = -1;
	}
}

// Spells

void Loadout_RandomizeSpells(RandomizedLoadout eLoadout)
{
	eLoadout.bRerollSpell = true;
	eLoadout.iSpellIndex = -1;
}

void Loadout_ApplyClientSpells(int iClient)
{
	//If randomized spells is enabled and player dont have spellbook, give em one
	bool bEquip;
	int iSpellbook, iPos;
	if (!TF2_GetItemFromClassname(iClient, "tf_weapon_spellbook", iSpellbook, iPos))
	{
		iSpellbook = TF2_CreateWeapon(iClient, 1132, WeaponSlot_Building);
		bEquip = true;
	}
	
	//Spellbook should appear before other action items in m_hMyWeapons so HUD can appear
	int iMaxWeapons = GetMaxWeapons();
	int iActionItem = INVALID_ENT_REFERENCE;
	for (iPos = 0; iPos < iMaxWeapons; iPos++)
	{
		int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", iPos);
		if (iWeapon == INVALID_ENT_REFERENCE)
		{
			if (iActionItem != INVALID_ENT_REFERENCE)
				SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", iActionItem, iPos);
			
			break;
		}
		
		if (iWeapon == iSpellbook && iActionItem == INVALID_ENT_REFERENCE)	//Spellbook already first
			break;
		
		int iLoadoutSlot = TF2Econ_GetItemLoadoutSlot(GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"), TF2_GetPlayerClass(iClient));
		if (iLoadoutSlot == LoadoutSlot_Action)
		{
			iActionItem = iWeapon;
			SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", INVALID_ENT_REFERENCE, iPos);
		}
	}
	
	if (bEquip)
		TF2_EquipWeapon(iClient, iSpellbook);
	
	int iGrapplingHook;
	if (FindConVar("tf_grapplinghook_enable").BoolValue && !TF2_GetItemFromClassname(iClient, "tf_weapon_grapplinghook", iGrapplingHook, iPos))
		TF2_EquipWeapon(iClient, TF2_CreateWeapon(iClient, 1152, WeaponSlot_Building));	//Auto-equip grappling hook if forced to equip spell
	
	if (!g_eLoadoutClient[iClient].bRerollSpell)
		return;
	
	SDKCall_RollNewSpell(iSpellbook, 0, true);
	g_eLoadoutClient[iClient].bRerollSpell = false;
	
	int iOffset = FindSendPropInfo("CTFSpellBook", "m_flTimeNextSpell") - 8;
	if (g_eLoadoutClient[iClient].iSpellIndex != -1)
	{
		//Force set next spell index
		SetEntData(iSpellbook, iOffset, g_eLoadoutClient[iClient].iSpellIndex);
	}
	else
	{
		//Dont have force spell index, use whatever rolled value as so, for all groups aswell
		g_eLoadoutClient[iClient].iSpellIndex = GetEntData(iSpellbook, iOffset);
		
		iPos = Group_GetClientSameInfoPos(iClient, RandomizedType_Spells);
		if (iPos != -1)
		{
			g_eLoadoutGroup[iPos].iSpellIndex = g_eLoadoutClient[iClient].iSpellIndex;
			
			//Just update all client infos for new spell index
			for (int i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i))
					Loadout_UpdateClientInfo(i);
		}
	}
}