#define FILEPATH_CONFIG_WEAPONS "configs/randomizer/weapons.cfg"
#define FILEPATH_CONFIG_RESKINS "configs/randomizer/reskins.cfg"

static ArrayList g_aWeapons[CLASS_MAX+1][WeaponSlot_BuilderEngie+1];
static StringMap g_mWeaponsName;
static StringMap g_mWeaponsReskins;

public void Weapons_Init()
{
	g_mWeaponsName = new StringMap();
	g_mWeaponsReskins = new StringMap();
}

public void Weapons_Refresh()
{
	KeyValues kv = LoadConfig(FILEPATH_CONFIG_WEAPONS, "Weapons");
	if (!kv)
		return;
	
	for (int i = 0; i < sizeof(g_aWeapons); i++)
		for (int j = 0; j < sizeof(g_aWeapons[]); j++)
			delete g_aWeapons[i][j];
	
	g_mWeaponsName.Clear();
	
	Weapons_LoadSlot(kv, "Primary", WeaponSlot_Primary);
	Weapons_LoadSlot(kv, "Secondary", WeaponSlot_Secondary);
	Weapons_LoadSlot(kv, "Melee", WeaponSlot_Melee);
	Weapons_LoadSlot(kv, "PDABuild", WeaponSlot_PDABuild);
	Weapons_LoadSlot(kv, "PDADestroy", WeaponSlot_PDADestroy);
	Weapons_LoadSlot(kv, "Toolbox", WeaponSlot_BuilderEngie);
	Weapons_LoadSlot(kv, "DisguiseKit", WeaponSlot_PDADisguise);
	Weapons_LoadSlot(kv, "InvisWatch", WeaponSlot_InvisWatch);
	
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
				char sIndex[16], sName[256];
				kv.GetSectionName(sIndex, sizeof(sIndex));
				kv.GetString(NULL_STRING, sName, sizeof(sName));
				
				int iIndex;
				if (!StringToIntEx(sIndex, iIndex))
				{
					LogError("Randomizer Weapons config have invalid integer index: %s", sIndex);
					continue;
				}
				
				if (!TranslationPhraseExists(sName))
				{
					LogError("Found weapon index '%d' but translation '%s' doesn't exist", iIndex, sName);
					continue;
				}
				
				if (!g_aWeapons[CLASS_ALL][iSlot])
					g_aWeapons[CLASS_ALL][iSlot] = new ArrayList();
				
				g_aWeapons[CLASS_ALL][iSlot].Push(iIndex);
				
				for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
				{
					if (TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass)) == iSlot)
					{
						if (!g_aWeapons[iClass][iSlot])
							g_aWeapons[iClass][iSlot] = new ArrayList();
						
						g_aWeapons[iClass][iSlot].Push(iIndex);
					}
				}
				
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

int Weapons_GetRandomIndex(int iSlot, TFClassType nClass)
{
	if (!g_aWeapons[nClass][iSlot])
		return -1;
	
	int iLength = g_aWeapons[nClass][iSlot].Length;
	return g_aWeapons[nClass][iSlot].Get(GetRandomInt(0, iLength - 1));
}

bool Weapons_GetName(int iIndex, char[] sBuffer, int iLength)
{
	char sIndex[16];
	IntToString(iIndex, sIndex, sizeof(sIndex));
	return g_mWeaponsName.GetString(sIndex, sBuffer, iLength);
}

int Weapons_GetReskinIndex(int iIndex)
{
	char sIndex[12];
	IntToString(iIndex, sIndex, sizeof(sIndex));
	g_mWeaponsReskins.GetValue(sIndex, iIndex);
	return iIndex;
}