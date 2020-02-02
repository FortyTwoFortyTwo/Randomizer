#define FILEPATH_CONFIG_WEAPONS "configs/randomizer/weapons.cfg"

enum
{
	ConfigWeapon_Primary,
	ConfigWeapon_Secondary,
	ConfigWeapon_Melee,
	ConfigWeapon_PDABuild,
	ConfigWeapon_PDADestroy,
	ConfigWeapon_Toolbox,
	ConfigWeapon_DisguiseKit,
	ConfigWeapon_InvisWatch,
	ConfigWeapon_MAX
}

ArrayList g_aWeapons[ConfigWeapon_MAX];
StringMap g_mWeaponsName;

public void Weapons_Init()
{
	for (int i = 0; i < ConfigWeapon_MAX; i++)
		g_aWeapons[i] = new ArrayList();
	
	g_mWeaponsName = new StringMap();
}

public void Weapons_Refresh()
{
	KeyValues kv = LoadConfig(FILEPATH_CONFIG_WEAPONS, "Weapons");
	if (!kv)
		return;
	
	for (int i = 0; i < ConfigWeapon_MAX; i++)
		g_aWeapons[i].Clear();
	
	g_mWeaponsName.Clear();
	
	Weapons_LoadSlot(kv, "Primary", ConfigWeapon_Primary);
	Weapons_LoadSlot(kv, "Secondary", ConfigWeapon_Secondary);
	Weapons_LoadSlot(kv, "Melee", ConfigWeapon_Melee);
	Weapons_LoadSlot(kv, "PDABuild", ConfigWeapon_PDABuild);
	Weapons_LoadSlot(kv, "PDADestroy", ConfigWeapon_PDADestroy);
	Weapons_LoadSlot(kv, "Toolbox", ConfigWeapon_Toolbox);
	Weapons_LoadSlot(kv, "DisguiseKit", ConfigWeapon_DisguiseKit);
	Weapons_LoadSlot(kv, "InvisWatch", ConfigWeapon_InvisWatch);
	
	delete kv;
}

void Weapons_LoadSlot(KeyValues kv, char[] sSection, int iSlot)
{
	if (kv.JumpToKey(sSection))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				char sIndex[16], sName[256];
				kv.GetSectionName(sIndex, sizeof(sIndex));
				kv.GetString(NULL_STRING, sName, sizeof(sName));
				
				int iIndex;
				if (!StringToIntEx(sIndex, iIndex))
				{
					LogError("Randomizer Weapons config have invalid integer index: %s", sIndex);
					continue;
				}
				
				g_aWeapons[iSlot].Push(iIndex);
				g_mWeaponsName.SetString(sIndex, sName);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
	else
	{
		LogError("Randomizer Weapons config does not have this slot section: %s", sSection);
	}
}

int Weapons_GetRandomIndex(int iSlot, TFClassType nClass = TFClass_Unknown)
{
	int iPos = -1;
	
	switch (iSlot)
	{
		case WeaponSlot_Primary: iPos = ConfigWeapon_Primary;
		case WeaponSlot_Secondary: iPos = ConfigWeapon_Secondary;
		case WeaponSlot_Melee: iPos = ConfigWeapon_Melee;
	}
	
	switch (nClass)
	{
		case TFClass_Engineer:
		{
			switch (iSlot)
			{
				case WeaponSlot_PDABuild: iPos = ConfigWeapon_PDABuild;
				case WeaponSlot_PDADestroy: iPos = ConfigWeapon_PDADestroy;
				case WeaponSlot_BuilderEngie: iPos = ConfigWeapon_Toolbox;
			}
		}
		case TFClass_Spy:
		{
			switch (iSlot)
			{
				case WeaponSlot_PDADisguise: iPos = ConfigWeapon_DisguiseKit;
				case WeaponSlot_InvisWatch: iPos = ConfigWeapon_InvisWatch;
			}
		}
	}
	
	if (iPos == -1 || !g_aWeapons[iPos])
		return -1;
	
	int iLength = g_aWeapons[iPos].Length;
	if (iLength == 0)
		return -1;
	
	return g_aWeapons[iPos].Get(GetRandomInt(0, iLength - 1));
}

bool Weapons_GetName(int iIndex, char[] sBuffer, int iLength)
{
	char sIndex[16];
	IntToString(iIndex, sIndex, sizeof(sIndex));
	return g_mWeaponsName.GetString(sIndex, sBuffer, iLength);
}