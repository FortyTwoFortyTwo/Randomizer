static char g_sRandomizedAction[][] = {
	"death",
	"death-kill",
	"death-env",
	"death-suicide",
	"kill",
	"assist",
	"round",
	"round-full",
	"cp-capture",
	"flag-capture",
	"pass-score",
};

enum ConVarResult
{
	ConVarResult_NotFound = 0,
	ConVarResult_Found = 1,
	ConVarResult_Error = 2,
}

void ConVar_Init()
{
	CreateConVar("randomizer_version", PLUGIN_VERSION ... "." ... PLUGIN_VERSION_REVISION, "Randomizer plugin version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_cvEnabled = CreateConVar("randomizer_enabled", "1", "Enable Randomizer?", _, true, 0.0, true, 1.0);
	g_cvEnabled.AddChangeHook(ConVar_EnableChanged);
	
	g_cvDroppedWeapons = CreateConVar("randomizer_droppedweapons", "0", "Allow dropped weapons?", _, true, 0.0, true, 1.0);
	g_cvHuds = CreateConVar("randomizer_huds", "1", "Hud to use to display weapons. 0 = none, 1 = hud text, 2 = menu.", _, true, 0.0, true, float(HudMode_MAX - 1));
	
	ConVar_AddType(RandomizedType_Class, "randomizer_class", "trigger=@all group=@me action=death-kill action=round", "How should class be randomized?");
	ConVar_AddType(RandomizedType_Weapons, "randomizer_weapons", "trigger=@all group=@me action=death-kill action=round count-primary=1 count-secondary=1 count-melee=1", "How should weapons be randomized?");
	ConVar_AddType(RandomizedType_Cosmetics, "randomizer_cosmetics", "trigger=@all group=@me action=death-kill action=round count=3 conflicts=1", "How should cosmetics be randomized?");
	ConVar_AddType(RandomizedType_Rune, "randomizer_rune", "", "How should rune be randomized?");
	ConVar_AddType(RandomizedType_Spells, "randomizer_spells", "", "How should spells be randomized?");
}

void ConVar_AddType(RandomizedType nType, const char[] sName, const char[] sDefault, const char[] sDesp)
{
	g_cvRandomize[nType] = CreateConVar(sName, sDefault, sDesp);
	g_cvRandomize[nType].AddChangeHook(ConVar_RandomizeChanged);
}

void ConVar_Refresh()
{
	for (RandomizedType nType; nType < RandomizedType_MAX; nType++)
	{
		char sBuffer[1024];
		g_cvRandomize[nType].GetString(sBuffer, sizeof(sBuffer));
		PrintToServer(sBuffer);
		ConVar_RandomizeChanged(g_cvRandomize[nType], "", sBuffer);
	}
}

public void ConVar_EnableChanged(ConVar convar, const char[] sOldValue, const char[] sNewValue)
{
	if (!!StringToInt(sNewValue))
		EnableRandomizer();
	else
		DisableRandomizer();
}

public void ConVar_RandomizeChanged(ConVar convar, const char[] sOldValue, const char[] sNewValue)
{
	static bool bSkip;
	if (bSkip)
		return;
	
	RandomizedType nType = ConVar_GetType(convar);
	
	if (!sNewValue[0])	//Empty string
	{
		Group_ClearType(nType);
		return;
	}
	
	RandomizedInfo eInfoList[MAX_GROUPS];
	int iInfoCount;
	
	char sGroups[32][256];
	int iGroupCount = ExplodeString(sNewValue, ",", sGroups, sizeof(sGroups), sizeof(sGroups[]));
	for (int i = 0; i < iGroupCount; i++)
	{
		RandomizedInfo eInfo;
		eInfo.Reset();
		eInfo.nType = nType;
		
		TrimString(sGroups[i]);
		char sParams[16][256];
		int iCount = ExplodeString(sGroups[i], " ", sParams, sizeof(sParams), sizeof(sParams[]));
		for (int j = 0; j < iCount; j++)
		{
			TrimString(sParams[j]);
			
			char sParam[3][256];
			if (ExplodeString(sParams[j], "=", sParam, sizeof(sParam), sizeof(sParam[])) != 2)
			{
				PrintToServer("Invalid param format '%s' (must be '<name>=<value>')", sParams[j]);
				bSkip = true;
				convar.SetString(sOldValue);
				bSkip = false;
				return;
			}
			
			ConVarResult nResult;
			
			nResult += ConVar_AddString("trigger", sParam, eInfo.sTrigger, sizeof(eInfo.sTrigger));
			nResult += ConVar_AddString("group", sParam, eInfo.sGroup, sizeof(eInfo.sGroup));
			nResult += ConVar_AddAction("action", sParam, eInfo.nAction);
			nResult += ConVar_AddInt("same", sParam, eInfo.bSame);
			nResult += ConVar_AddInt("count", sParam, eInfo.iCount);
			nResult += ConVar_AddInt("count-primary", sParam, eInfo.iCountSlot[WeaponSlot_Primary]);
			nResult += ConVar_AddInt("count-secondary", sParam, eInfo.iCountSlot[WeaponSlot_Secondary]);
			nResult += ConVar_AddInt("count-melee", sParam, eInfo.iCountSlot[WeaponSlot_Melee]);
			nResult += ConVar_AddInt("defaultclass", sParam, eInfo.bDefaultClass);
			nResult += ConVar_AddInt("conflicts", sParam, eInfo.bConflicts);
				
			if (nResult == ConVarResult_NotFound)
				PrintToServer("Invalid param name '%s'", sParam[0]);
			
			if (nResult != ConVarResult_Found)
			{
				bSkip = true;
				convar.SetString(sOldValue);
				bSkip = false;
				return;
			}
		}
		
		eInfoList[iInfoCount] = eInfo;
		iInfoCount++;
	}
	
	Group_ClearType(nType);
	
	for (int i = 0; i < iInfoCount; i++)
		Group_Add(eInfoList[i]);
}

RandomizedType ConVar_GetType(ConVar convar)
{
	for (int i = 0; i < sizeof(g_cvRandomize); i++)
		if (g_cvRandomize[i] == convar)
			return view_as<RandomizedType>(i);
	
	return RandomizedType_None;
}

ConVarResult ConVar_AddString(const char[] sName, const char[][] sParam, char[] sBuffer, int iLength)
{
	if (!StrEqual(sParam[0], sName, false))
		return ConVarResult_NotFound;
	
	if (sBuffer[0])
	{
		PrintToServer("Name '%s' must not be used multiple times in one group", sName);
		return ConVarResult_Error;
	}
	
	strcopy(sBuffer, iLength, sParam[1]);
	return ConVarResult_Found;
}

ConVarResult ConVar_AddAction(const char[] sName, const char[][] sParam, RandomizedAction &nAction)
{
	if (!StrEqual(sParam[0], sName, false))
		return ConVarResult_NotFound;
	
	for (int i = 0; i < sizeof(g_sRandomizedAction); i++)
	{
		if (StrEqual(g_sRandomizedAction[i], sParam[1], false))
		{
			if (nAction & view_as<RandomizedAction>(1<<i))
			{
				PrintToServer("Invalid '%s' value '%s' (must not be used multiple times in one group)", sName, sParam[1]);
				return ConVarResult_Error;
			}
			
			nAction |= view_as<RandomizedAction>(1<<i);
			return ConVarResult_Found;
		}
	}
	
	PrintToServer("Invalid '%s' value '%s'", sName, sParam[1]);
	return ConVarResult_Error;
}

ConVarResult ConVar_AddInt(const char[] sName, const char[][] sParam, int &iValue)
{
	if (!StrEqual(sParam[0], sName, false))
		return ConVarResult_NotFound;
	
	if (!StringToIntEx(sParam[1], iValue))
	{
		PrintToServer("Invalid '%s' value '%s' (must be integer)", sName, sParam[1]);
		return ConVarResult_Error;
	}
	
	return ConVarResult_Found;
}