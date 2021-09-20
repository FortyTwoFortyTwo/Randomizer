#define FILEPATH_CONFIG_WEAPONS "configs/randomizer/weapons.cfg"
#define FILEPATH_CONFIG_RESKINS "configs/randomizer/reskins.cfg"

static ArrayList g_aWeapons[CLASS_MAX+1];
static ArrayList g_aWeaponsFromSlot[CLASS_MAX+1][WeaponSlot_Building+1];
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
		delete g_aWeapons[i];
	
	for (int i = 0; i < sizeof(g_aWeaponsFromSlot); i++)
		for (int j = 0; j < sizeof(g_aWeaponsFromSlot[]); j++)
			delete g_aWeaponsFromSlot[i][j];
	
	g_mWeaponsName.Clear();
	
	Weapons_LoadSlot(kv, "Primary", WeaponSlot_Primary);
	Weapons_LoadSlot(kv, "Secondary", WeaponSlot_Secondary);
	Weapons_LoadSlot(kv, "Melee", WeaponSlot_Melee);
	Weapons_LoadSlot(kv, "PDABuild", WeaponSlot_PDA);
	Weapons_LoadSlot(kv, "PDADestroy", WeaponSlot_PDA2);
	Weapons_LoadSlot(kv, "Toolbox", WeaponSlot_Building);
	Weapons_LoadSlot(kv, "DisguiseKit", WeaponSlot_PDA);
	Weapons_LoadSlot(kv, "InvisWatch", WeaponSlot_PDA2);
	
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
				
				if (!g_aWeapons[TFClass_Unknown])
					g_aWeapons[0] = new ArrayList();	//lol sourcepawn compiler
				
				if (g_aWeapons[0].FindValue(iIndex) == -1)	//Dont put multiple same index from different slots
					g_aWeapons[0].Push(iIndex);
				
				if (!g_aWeaponsFromSlot[TFClass_Unknown][iSlot])
					g_aWeaponsFromSlot[TFClass_Unknown][iSlot] = new ArrayList();
				
				g_aWeaponsFromSlot[TFClass_Unknown][iSlot].Push(iIndex);
				
				for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
				{
					if (TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass)) == iSlot)
					{
						if (!g_aWeapons[iClass])
							g_aWeapons[iClass] = new ArrayList();
						
						if (g_aWeapons[iClass].FindValue(iIndex) == -1)
							g_aWeapons[iClass].Push(iIndex);
						
						if (!g_aWeaponsFromSlot[iClass][iSlot])
							g_aWeaponsFromSlot[iClass][iSlot] = new ArrayList();
						
						g_aWeaponsFromSlot[iClass][iSlot].Push(iIndex);
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

int Weapons_GetRandomIndex(TFClassType nClass)
{
	if (!g_aWeapons[nClass])
		return -1;
	
	int iLength = g_aWeapons[nClass].Length;
	return g_aWeapons[nClass].Get(GetRandomInt(0, iLength - 1));
}

int Weapons_GetRandomIndexFromSlot(int iSlot, TFClassType nClass)
{
	if (!g_aWeaponsFromSlot[nClass][iSlot])
		return -1;
	
	int iLength = g_aWeaponsFromSlot[nClass][iSlot].Length;
	return g_aWeaponsFromSlot[nClass][iSlot].Get(GetRandomInt(0, iLength - 1));
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

int Weapons_GetIndexFromName(const char[] sName)
{
	if (!g_aWeapons[TFClass_Unknown])
		return -1;
	
	int iLength = g_aWeapons[0].Length;
	for (int i = 0; i < iLength; i++)
	{
		int iIndex = g_aWeapons[0].Get(i);
		
		char sBuffer[64];
		Weapons_GetName(iIndex, sBuffer, sizeof(sBuffer));
		Format(sBuffer, sizeof(sBuffer), "%T", sBuffer, LANG_SERVER);
		if (StrContains(sBuffer, sName, false) != -1)
			return iIndex;
	}
	
	return -1;
}