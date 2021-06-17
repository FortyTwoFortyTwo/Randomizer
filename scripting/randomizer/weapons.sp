#define FILEPATH_CONFIG_WEAPONS "configs/randomizer/weapons.cfg"
#define FILEPATH_CONFIG_RESKINS "configs/randomizer/reskins.cfg"

enum
{
	ConfigWeapon_Invalid = -1,
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

static int g_iWeaponsInfoId;
static ArrayList g_aWeapons[ConfigWeapon_MAX];
static StringMap g_mWeaponsReskins;

public void Weapons_Init()
{
	g_iWeaponsInfoId = 1;	//Dont start at 0
	
	for (int i = 0; i < ConfigWeapon_MAX; i++)
		g_aWeapons[i] = new ArrayList(sizeof(WeaponInfo));
	
	g_mWeaponsReskins = new StringMap();
}

public void Weapons_Refresh()
{
	KeyValues kv = LoadConfig(FILEPATH_CONFIG_WEAPONS, "Weapons");
	if (!kv)
		return;
	
	for (int i = 0; i < ConfigWeapon_MAX; i++)
	{
		int iLength = g_aWeapons[i].Length;
		for (int j = 0; j < iLength; j++)
		{
			WeaponInfo info;
			g_aWeapons[i].GetArray(j, info);
			delete info.aAttrib;
		}
		
		g_aWeapons[i].Clear();
	}
	
	Weapons_LoadSlot(kv, "Primary", ConfigWeapon_Primary);
	Weapons_LoadSlot(kv, "Secondary", ConfigWeapon_Secondary);
	Weapons_LoadSlot(kv, "Melee", ConfigWeapon_Melee);
	Weapons_LoadSlot(kv, "PDABuild", ConfigWeapon_PDABuild);
	Weapons_LoadSlot(kv, "PDADestroy", ConfigWeapon_PDADestroy);
	Weapons_LoadSlot(kv, "Toolbox", ConfigWeapon_Toolbox);
	Weapons_LoadSlot(kv, "DisguiseKit", ConfigWeapon_DisguiseKit);
	Weapons_LoadSlot(kv, "InvisWatch", ConfigWeapon_InvisWatch);
	
	delete kv;
	
	kv = LoadConfig(FILEPATH_CONFIG_RESKINS, "Reskins");
	if (!kv)
		return;
	
	g_mWeaponsReskins.Clear();
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char sIndex[12];
			kv.GetSectionName(sIndex, sizeof(sIndex));
			
			int iIndex;
			if (!StringToIntEx(sIndex, iIndex))
			{
				LogError("Randomizer Reskins config have invalid integer index: %s", sIndex);
				continue;
			}
			
			char sValue[512];
			kv.GetString(NULL_STRING, sValue, sizeof(sValue));
			
			char sValueExploded[64][12];
			int iCount = ExplodeString(sValue, " ", sValueExploded, sizeof(sValueExploded), sizeof(sValueExploded[]));
			
			for (int i = 0; i < iCount; i++)
				g_mWeaponsReskins.SetValue(sValueExploded[i], iIndex);
		}
		while (kv.GotoNextKey(false));
	}
	
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
				WeaponInfo info;
				
				char sIndex[16];
				kv.GetSectionName(sIndex, sizeof(sIndex));
				
				if (StrEqual(sIndex, "weapon"))
				{
					info.bCustom = true;
					info.iIndex = kv.GetNum("index");
					kv.GetString("name", info.sName, sizeof(info.sName));
					kv.GetString("classname", info.sClassname, sizeof(info.sClassname));
					
					if (kv.JumpToKey("attrib"))
					{
						if (kv.GotoFirstSubKey(false))
						{
							info.aAttrib = new ArrayList(2);
							
							do
							{
								char sAttribName[CONFIG_MAXCHAR];
								kv.GetSectionName(sAttribName, sizeof(sAttribName));
								int iAttrib = TF2Econ_TranslateAttributeNameToDefinitionIndex(sAttribName) & 0xFFFF;	//For server using older econ data plugin
								
								if (iAttrib == -1)
								{
									LogError("Randomizer Weapons config have unknown attribute name: %s", sAttribName);
									continue;
								}
								
								int iPos = info.aAttrib.Length;
								info.aAttrib.Resize(iPos + 1);
								info.aAttrib.Set(iPos, iAttrib, 0);
								info.aAttrib.Set(iPos, kv.GetFloat(NULL_STRING), 1);
							}
							while (kv.GotoNextKey(false));
							kv.GoBack();
						}
						
						kv.GoBack();
					}
				}
				else if (StringToIntEx(sIndex, info.iIndex))
				{
					kv.GetString(NULL_STRING, info.sName, sizeof(info.sName));
				}
				else
				{
					LogError("Randomizer Weapons config have invalid value: %s", sIndex);
					continue;
				}
				
				if (!TranslationPhraseExists(info.sName))
					//TODO better error
					LogError("Found weapon index '%d' but translation '%s' doesn't exist", info.iIndex, info.sName);
				
				info.iId = g_iWeaponsInfoId;
				g_aWeapons[iSlot].PushArray(info);
				
				g_iWeaponsInfoId++;
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

void Weapons_GetRandomInfo(WeaponInfo info, int iSlot, TFClassType nClass = TFClass_Unknown)
{
	int iPos = Weapons_GetConfigSlot(iSlot, nClass);
	if (iPos == ConfigWeapon_Invalid || !g_aWeapons[iPos])
	{
		WeaponInfo nothing;
		info = nothing;
		return;
	}
	
	int iLength = g_aWeapons[iPos].Length;
	if (iLength == 0)
	{
		WeaponInfo nothing;
		info = nothing;
		return;
	}
	
	g_aWeapons[iPos].GetArray(GetRandomInt(0, iLength - 1), info);
}

void Weapons_GetInfoFromIndex(int iIndex, WeaponInfo info, int iSlot, TFClassType nClass = TFClass_Unknown)
{
	int iPos = Weapons_GetConfigSlot(iSlot, nClass);
	if (iPos == ConfigWeapon_Invalid || !g_aWeapons[iPos])
	{
		WeaponInfo nothing;
		info = nothing;
		return;
	}
	
	int iLength = g_aWeapons[iPos].Length;
	for (int i = 0; i < iLength; i++)
	{
		g_aWeapons[iPos].GetArray(i, info);
		if (!info.bCustom && info.iIndex == iIndex)	//Ignore custom weapons
			return;
	}
	
	//Cant find one
	WeaponInfo nothing;
	info = nothing;
}

void Weapons_GetInfoFromName(int iClient, const char[] sName, WeaponInfo info, int iSlot, TFClassType nClass = TFClass_Unknown)
{
	int iPos = Weapons_GetConfigSlot(iSlot, nClass);
	if (iPos == ConfigWeapon_Invalid || !g_aWeapons[iPos])
	{
		WeaponInfo nothing;
		info = nothing;
		return;
	}
	
	int iLength = g_aWeapons[iPos].Length;
	for (int i = 0; i < iLength; i++)
	{
		char sBuffer[256];
		g_aWeapons[iPos].GetArray(i, info);
		
		Format(sBuffer, sizeof(sBuffer), "%T", info.sName, iClient);
		if (StrContains(sBuffer, sName, false) == 0)
			return;
		
		Format(sBuffer, sizeof(sBuffer), "%T", info.sName, LANG_SERVER);
		if (StrContains(sBuffer, sName, false) == 0)
			return;
	}
	
	//Cant find one
	WeaponInfo nothing;
	info = nothing;
}

int Weapons_GetConfigSlot(int iSlot, TFClassType nClass = TFClass_Unknown)
{
	switch (iSlot)
	{
		case WeaponSlot_Primary: return ConfigWeapon_Primary;
		case WeaponSlot_Secondary: return ConfigWeapon_Secondary;
		case WeaponSlot_Melee: return ConfigWeapon_Melee;
	}
	
	switch (nClass)
	{
		case TFClass_Engineer:
		{
			switch (iSlot)
			{
				case WeaponSlot_PDABuild: return ConfigWeapon_PDABuild;
				case WeaponSlot_PDADestroy: return ConfigWeapon_PDADestroy;
				case WeaponSlot_BuilderEngie: return ConfigWeapon_Toolbox;
			}
		}
		case TFClass_Spy:
		{
			switch (iSlot)
			{
				case WeaponSlot_PDADisguise: return ConfigWeapon_DisguiseKit;
				case WeaponSlot_InvisWatch: return ConfigWeapon_InvisWatch;
			}
		}
	}
	
	return ConfigWeapon_Invalid;
}

int Weapons_GetReskinIndex(int iIndex)
{
	char sIndex[12];
	IntToString(iIndex, sIndex, sizeof(sIndex));
	g_mWeaponsReskins.GetValue(sIndex, iIndex);
	return iIndex;
}