#define FILEPATH_CONFIG_WEAPONS "configs/randomizer/weapons.cfg"
#define FILEPATH_CONFIG_RESKINS "configs/randomizer/reskins.cfg"

static ArrayList g_aWeapons;
static ArrayList g_aWeaponsClass[CLASS_MAX+1];
static ArrayList g_aWeaponsSlot[WeaponSlot_Building+1];
static ArrayList g_aWeaponsClassSlot[CLASS_MAX+1][WeaponSlot_Building+1];

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
	
	delete g_aWeapons;
	
	for (int i = 0; i < sizeof(g_aWeaponsClass); i++)
		delete g_aWeaponsClass[i];
	
	for (int i = 0; i < sizeof(g_aWeaponsSlot); i++)
		delete g_aWeaponsSlot[i];
	
	for (int i = 0; i < sizeof(g_aWeaponsClassSlot); i++)
		for (int j = 0; j < sizeof(g_aWeaponsClassSlot[]); j++)
			delete g_aWeaponsClassSlot[i][j];
	
	g_mWeaponsName.Clear();
	
	Weapons_LoadList(kv, "AllClass", true);
	Weapons_LoadList(kv, "DefaultClass", false);
	
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

void Weapons_LoadList(KeyValues kv, const char[] sSection, bool bAllClass)
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
				
				if (bAllClass)
					Weapons_AddList(g_aWeapons, iIndex);
				
				for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
				{
					int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
					if (WeaponSlot_Primary <= iSlot <= WeaponSlot_Building)
					{
						Weapons_AddList(g_aWeaponsClassSlot[iClass][iSlot], iIndex);
						
						if (bAllClass)
						{
							Weapons_AddList(g_aWeaponsClass[iClass], iIndex);
							Weapons_AddList(g_aWeaponsSlot[iSlot], iIndex);
						}
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
		LogError("Randomizer Weapons config does not have section '%s'", sSection);
	}
}

void Weapons_AddList(ArrayList &aList, int iIndex)
{
	if (!aList)
		aList = new ArrayList();
	
	if (aList.FindValue(iIndex) == -1)	//Dont put multiple same index
		aList.Push(iIndex);
}

int Weapons_GetRandomIndex(TFClassType nClass = TFClass_Unknown, int iSlot = -1)
{
	ArrayList aList;
	
	if (nClass == TFClass_Unknown)
	{
		if (iSlot == -1)
			aList = g_aWeapons;
		else
			aList = g_aWeaponsSlot[iSlot];
	}
	else
	{
		if (iSlot == -1)
			aList = g_aWeaponsClass[nClass];
		else
			aList = g_aWeaponsClassSlot[nClass][iSlot];
	}
	
	if (!aList)
		return -1;
	
	int iLength = aList.Length;
	return aList.Get(GetRandomInt(0, iLength - 1));
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
	//Only g_aWeaponsClassSlot have all weapons listed
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_Building; iSlot++)
		{
			if (!g_aWeaponsClassSlot[iClass][iSlot])
				continue;
			
			int iLength = g_aWeaponsClassSlot[iClass][iSlot].Length;
			for (int i = 0; i < iLength; i++)
			{
				int iIndex = g_aWeaponsClassSlot[iClass][iSlot].Get(i);
				
				char sBuffer[64];
				Weapons_GetName(iIndex, sBuffer, sizeof(sBuffer));
				Format(sBuffer, sizeof(sBuffer), "%T", sBuffer, LANG_SERVER);
				if (StrContains(sBuffer, sName, false) != -1)
					return iIndex;
			}
		}
	}
	
	return -1;
}