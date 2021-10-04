enum struct RandomizedLoadout
{
	TFClassType nClass;		//Class
	ArrayList aWeapons[CLASS_MAX+1];	//Arrays of RandomizedWeapon to set
	bool bRandomWeapons;	//Currently have random weapons?
	bool bRandomCosmetics;	//Currently have random cosmetics?
	int iRuneType;			//Type of rune
	int iOldRuneType;		//Previous rune type
	bool bRerollSpell;		//Should client's spell be rerolled?
	int iSpellIndex;		//Spell index to set
	
	int iClient;	//Client index if has one
	int iGroup;		//Group index if has one
	
	void Reset()
	{
		this.nClass = TFClass_Unknown;
		
		for (int i = 0; i < sizeof(RandomizedLoadout::aWeapons); i++)
			delete this.aWeapons[i];
		
		this.iRuneType = -1;
		this.iOldRuneType = -1;
		this.bRerollSpell = false;
		this.iSpellIndex = -1;
	}
	
	void ResetWeapon()
	{
		for (int i = 0; i < sizeof(RandomizedLoadout::aWeapons); i++)
			delete this.aWeapons[i];
	}
	
	void AddWeapon(RandomizedWeapon eWeapon, int iClass)
	{
		if (eWeapon.iIndex == -1)
			return;
		
		if (!this.aWeapons[iClass])
			this.aWeapons[iClass] = new ArrayList(sizeof(RandomizedWeapon));
		
		this.aWeapons[iClass].PushArray(eWeapon);
	}
	
	void RemoveWeaponsBySlot(int iSlot)
	{
		for (int i = 0; i < sizeof(RandomizedLoadout::aWeapons); i++)
		{
			if (!this.aWeapons[i])
				continue;
			
			int iPos;
			while ((iPos = this.aWeapons[i].FindValue(iSlot, RandomizedWeapon::iSlot)) != -1)
				this.aWeapons[i].Erase(iPos);
		}
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
	
	void SetRuneType(int iRuneType)
	{
		this.iOldRuneType = this.iRuneType;
		this.iRuneType = iRuneType;
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

static RandomizedLoadout g_eLoadoutClient[TF_MAXPLAYERS];
static RandomizedLoadout g_eLoadoutGroup[MAX_GROUPS];

static bool g_bRandomizeCosmetics[TF_MAXPLAYERS];

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
	
	int[] iTargetList = new int[MaxClients];
	int iTargetCount = Group_GetTargetList(eInfo.sGroup, iTargetList);
	for (int i = 0; i < iTargetCount; i++)
		g_bClientRefresh[iTargetList[i]] = true;
}

void Loadout_UpdateClientInfo(int iClient)
{
	int iPos;
	
	iPos = Group_GetClientSameInfoPos(iClient, RandomizedType_Class);
	if (iPos != -1)
		g_eLoadoutClient[iClient].nClass = g_eLoadoutGroup[iPos].nClass;
	else if (!Group_IsClientRandomized(iClient, RandomizedType_Class))
		g_eLoadoutClient[iClient].nClass = TFClass_Unknown;
	
	iPos = Group_GetClientSameInfoPos(iClient, RandomizedType_Weapons);
	if (iPos != -1)
		g_eLoadoutClient[iClient].CopyWeapons(g_eLoadoutGroup[iPos].aWeapons);
	else if (!Group_IsClientRandomized(iClient, RandomizedType_Weapons))
		g_eLoadoutClient[iClient].ResetWeapon();
	
	iPos = Group_GetClientSameInfoPos(iClient, RandomizedType_Rune);
	if (iPos != -1)
		g_eLoadoutClient[iClient].iRuneType = g_eLoadoutGroup[iPos].iRuneType;
	else if (!Group_IsClientRandomized(iClient, RandomizedType_Rune))
		g_eLoadoutClient[iClient].SetRuneType(-1);
	
	iPos = Group_GetClientSameInfoPos(iClient, RandomizedType_Spells);
	if (iPos != -1)
		g_eLoadoutClient[iClient].SetSpellIndex(g_eLoadoutGroup[iPos].iSpellIndex, g_eLoadoutGroup[iPos].bRerollSpell);
	else if (!Group_IsClientRandomized(iClient, RandomizedType_Spells))
		g_eLoadoutClient[iClient].SetSpellIndex(-1, false);
}

void Loadout_RefreshClient(int iClient)
{
	g_bClientRefresh[iClient] = false;
	
	if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))	//Player will regardless get refreshed on spawn
		return;
	
	Loadout_UpdateClientInfo(iClient);
	
	static const int iSlotWeapons[] = {
		LoadoutSlot_Primary,
		LoadoutSlot_Secondary,
		LoadoutSlot_Melee,
		LoadoutSlot_Building,
		LoadoutSlot_PDA,
		LoadoutSlot_PDA2,
	};
	
	static const int iSlotCosmetics[] = {
		LoadoutSlot_Head,
		LoadoutSlot_Misc,
		LoadoutSlot_Misc2
	};
	
	if (Group_IsClientRandomized(iClient, RandomizedType_Class))
		TF2_SetPlayerClass(iClient, g_eLoadoutClient[iClient].nClass);
	
	if (Group_IsClientRandomized(iClient, RandomizedType_Weapons))
		Loadout_RefreshClientWeapons(iClient);
	else if (g_eLoadoutClient[iClient].bRandomWeapons)
	{
		Loadout_ResetClientLoadout(iClient, iSlotWeapons, sizeof(iSlotWeapons));
		g_eLoadoutClient[iClient].bRandomWeapons = false;
	}
	
	if (Group_IsClientRandomized(iClient, RandomizedType_Cosmetics))
		Loadout_RefreshClientCosmetics(iClient, iSlotCosmetics, sizeof(iSlotCosmetics));
	else if (g_eLoadoutClient[iClient].bRandomCosmetics)
	{
		Loadout_ResetClientLoadout(iClient, iSlotCosmetics, sizeof(iSlotCosmetics));
		g_eLoadoutClient[iClient].bRandomCosmetics = false;
	}
	
	if (Group_IsClientRandomized(iClient, RandomizedType_Rune))
	{
		SDKCall_SetCarryingRuneType(GetEntityAddress(iClient) + view_as<Address>(g_iOffsetPlayerShared), g_eLoadoutClient[iClient].iRuneType);
	}
	else if (g_eLoadoutClient[iClient].iOldRuneType != -1)
	{
		SDKCall_SetCarryingRuneType(GetEntityAddress(iClient) + view_as<Address>(g_iOffsetPlayerShared), -1);
		g_eLoadoutClient[iClient].iOldRuneType = -1;
	}
	
	if (Group_IsClientRandomized(iClient, RandomizedType_Spells))
		Loadout_RefreshClientSpells(iClient);
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
			int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
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
		if (Group_IsPosSameForClients(iClients, iCount, i, RandomizedType_Class))
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

// Weapons

void Loadout_RandomizeWeapon(RandomizedLoadout eLoadout)
{
	eLoadout.ResetWeapon();
	
	RandomizedInfo eInfo;
	eLoadout.GetInfo(RandomizedType_Weapons, eInfo);
	
	int iMinCount = eInfo.iCount;
	
	int iSlotMinCount;
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_Melee; iSlot++)
		iSlotMinCount += eInfo.iCountSlot[iSlot];
	
	if (iMinCount > iSlotMinCount)
		iMinCount -= iSlotMinCount;
	else if (iMinCount < iSlotMinCount)
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

void Loadout_RefreshClientWeapons(int iClient)
{
	Properties_SaveActiveWeaponAmmo(iClient);
	
	g_eLoadoutClient[iClient].bRandomWeapons = true;
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	
	int iWeapon, iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		char sClassname[256];
		GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
		int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		
		if (CanKeepWeapon(iClient, sClassname, iIndex))
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
		
		if (eWeapon.iRef != INVALID_ENT_REFERENCE)
			continue;
		
		if (!ItemIsAllowed(eWeapon.iIndex))
			continue;
		
		Address pItem = TF2_FindReskinItem(iClient, eWeapon.iIndex);
		if (pItem)
			iWeapon = TF2_GiveNamedItem(iClient, pItem, eWeapon.iSlot);
		else
			iWeapon = TF2_CreateWeapon(iClient, eWeapon.iIndex, eWeapon.iSlot);
		
		if (iWeapon == INVALID_ENT_REFERENCE)
		{
			PrintToChat(iClient, "Unable to create weapon! index '%d'", eWeapon.iIndex);
			LogError("Unable to create weapon! index '%d'", eWeapon.iIndex);
			continue;
		}
		
		//CTFPlayer::ItemsMatch doesnt like normal item quality, so lets use unique instead
		if (view_as<TFQuality>(GetEntProp(iWeapon, Prop_Send, "m_iEntityQuality")) == TFQual_Normal)
			SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", TFQual_Unique);
		
		TF2_EquipWeapon(iClient, iWeapon);
		
		//Fill charge meter
		float flVal;
		if (!TF2_WeaponFindAttribute(iWeapon, "item_meter_resupply_denied", flVal) || flVal == 0.0)
			Properties_AddWeaponChargeMeter(iClient, iWeapon, 100.0);
		
		//Fill ammo
		if (HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType"))
		{
			int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
			if (iAmmoType != -1)
			{
				int iMaxAmmo = TF2_GetMaxAmmo(iClient, iWeapon, iAmmoType);
				int iAmmo = TF2_GiveAmmo(iClient, iWeapon, 0, iMaxAmmo, iAmmoType, true, kAmmoSource_Resupply);
				Properties_SetWeaponPropInt(iWeapon, "m_iAmmo", iAmmo);
				if (iWeapon == GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon"))
					Properties_UpdateActiveWeaponAmmo(iClient);
			}
		}
		
		if (ViewModels_ShouldBeInvisible(iWeapon, nClass))
			ViewModels_EnableInvisible(iWeapon);
		
		aWeapons.Set(i, EntIndexToEntRef(iWeapon), RandomizedWeapon::iRef);
	}
	
	//Set active weapon if dont have one
	//TODO update this
	if (GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") == INVALID_ENT_REFERENCE)
	{
		for (int iSlot = 0; iSlot <= WeaponSlot_Melee; iSlot++)
		{
			iWeapon = GetPlayerWeaponSlot(iClient, iSlot);	//Dont want wearable
			if (iWeapon != INVALID_ENT_REFERENCE)
			{
				TF2_SwitchToWeapon(iClient, iWeapon);
				break;
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

void Loadout_RemoveWeaponBySlot(RandomizedLoadout eLoadout, int iSlot)
{
	eLoadout.RemoveWeaponsBySlot(iSlot);
}

void Loadout_SetWeapon(int[] iClients, int iCount, RandomizedWeapon eList[MAX_WEAPONS], int iListCount)
{
	for (int i = 0; i < sizeof(g_eLoadoutGroup); i++)
	{
		if (Group_IsPosSameForClients(iClients, iCount, i, RandomizedType_Weapons))
		{
			g_eLoadoutGroup[i].ResetWeapon();
			
			for (int j = 0; j < iCount; j++)
				Loadout_AddWeapon(g_eLoadoutGroup[i], eList, iListCount);
		}
	}
	
	for (int i = 0; i < iCount; i++)
	{
		g_eLoadoutClient[iClients[i]].ResetWeapon();
		
		for (int j = 0; j < iCount; j++)
			Loadout_AddWeapon(g_eLoadoutClient[iClients[i]], eList, iListCount);
		
		Loadout_RefreshClient(iClients[i]);
	}
}

void Loadout_SetSlotWeapon(int[] iClients, int iCount, RandomizedWeapon eList[MAX_WEAPONS], int iListCount)
{
	for (int i = 0; i < sizeof(g_eLoadoutGroup); i++)
	{
		if (Group_IsPosSameForClients(iClients, iCount, i, RandomizedType_Weapons))
		{
			bool bSlot[WeaponSlot_Building+1];
			
			for (int j = 0; j < iCount; j++)
			{
				if (!bSlot[eList[j].iSlot])
				{
					Loadout_RemoveWeaponBySlot(g_eLoadoutGroup[i], eList[j].iSlot);
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
				Loadout_RemoveWeaponBySlot(g_eLoadoutClient[iClients[i]], eList[j].iSlot);
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
		if (Group_IsPosSameForClients(iClients, iCount, i, RandomizedType_Weapons))
		{
			for (int j = 0; j < iCount; j++)
				Loadout_AddWeapon(g_eLoadoutGroup[i], eList, iListCount);
		}
	}
	
	for (int i = 0; i < iCount; i++)
	{
		for (int j = 0; j < iCount; j++)
			Loadout_AddWeapon(g_eLoadoutClient[iClients[i]], eList, iListCount);
		
		Loadout_RefreshClient(iClients[i]);
	}
}

// Cosmetics

void Loadout_RandomizeCosmetics(RandomizedLoadout eLoadout)
{
	if (eLoadout.iClient != -1)
	{
		g_bRandomizeCosmetics[eLoadout.iClient] = true;
	}
	else if (eLoadout.iGroup != -1)
	{
		RandomizedInfo eInfo;
		Group_GetInfoFromPos(eLoadout.iGroup, eInfo);
		
		int[] iClients = new int[MaxClients];
		int iCount = Group_GetTargetList(eInfo.sGroup, iClients);
		for (int i = 0; i < iCount; i++)
			g_bRandomizeCosmetics[iClients[i]] = true;
	}
}

void Loadout_RefreshClientCosmetics(int iClient, const int[] iSlots, int iSlotCount)
{
	if (!g_bRandomizeCosmetics[iClient])
		return;
	
	g_eLoadoutClient[iClient].bRandomCosmetics = true;
	
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
	eLoadout.SetRuneType(GetRandomInt(0, g_iRuneCount - 1));
}

int Loadout_GetClientRune(int iClient)
{
	return g_eLoadoutClient[iClient].iRuneType;
}

void Loadout_SetRune(int[] iClients, int iCount, int iRuneType)
{
	for (int i = 0; i < sizeof(g_eLoadoutGroup); i++)
	{
		if (Group_IsPosSameForClients(iClients, iCount, i, RandomizedType_Rune))
			g_eLoadoutGroup[i].SetRuneType(iRuneType);
	}
	
	for (int i = 0; i < iCount; i++)
	{
		g_eLoadoutClient[iClients[i]].SetRuneType(iRuneType);
		Loadout_RefreshClient(iClients[i]);
	}
}

// Spells

void Loadout_RandomizeSpells(RandomizedLoadout eLoadout)
{
	eLoadout.bRerollSpell = true;
	eLoadout.iSpellIndex = -1;
}

void Loadout_RefreshClientSpells(int iClient)
{
	if (!g_eLoadoutClient[iClient].bRerollSpell)
		return;
	
	int iSpellBook, iPos;
	if (!TF2_GetItemFromClassname(iClient, "tf_weapon_spellbook", iSpellBook, iPos))
		return;
	
	SDKCall_RollNewSpell(iSpellBook, 0, true);
	g_eLoadoutClient[iClient].bRerollSpell = false;
	
	int iOffset = FindSendPropInfo("CTFSpellBook", "m_flTimeNextSpell") - 8;
	if (g_eLoadoutClient[iClient].iSpellIndex != -1)
	{
		//Force set next spell index
		SetEntData(iSpellBook, iOffset, g_eLoadoutClient[iClient].iSpellIndex);
	}
	else
	{
		//Dont have force spell index, use whatever rolled value as so, for all groups aswell
		g_eLoadoutClient[iClient].iSpellIndex = GetEntData(iSpellBook, iOffset);
		
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