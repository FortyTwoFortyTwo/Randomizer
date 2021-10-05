static char g_sRandomizedReroll[][] = {
	"death",
	"environment",
	"suicide",
	"kill",
	"assist",
	"round",
	"fullround",
	"capture",
};

void ConVar_Init()
{
	CreateConVar("randomizer_version", PLUGIN_VERSION ... "." ... PLUGIN_VERSION_REVISION, "Randomizer plugin version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_cvEnabled = CreateConVar("randomizer_enabled", "1", "Enable Randomizer?", _, true, 0.0, true, 1.0);
	g_cvEnabled.AddChangeHook(ConVar_EnableChanged);
	
	g_cvDroppedWeapons = CreateConVar("randomizer_droppedweapons", "0", "Allow dropped weapons?", _, true, 0.0, true, 1.0);
	g_cvHuds = CreateConVar("randomizer_huds", "1", "Hud to use to display weapons. 0 = none, 1 = hud text, 2 = menu.", _, true, 0.0, true, float(HudMode_MAX - 1));
	
	ConVar_AddType(RandomizedType_Class, "randomizer_class", "trigger=@all group=@me reroll=death reroll=round", "How should class be randomized?");
	ConVar_AddType(RandomizedType_Weapons, "randomizer_weapons", "trigger=@all group=@me reroll=death reroll=round count-primary=1 count-secondary=1 count-melee=1", "How should weapons be randomized?");
	ConVar_AddType(RandomizedType_Cosmetics, "randomizer_cosmetics", "trigger=@all group=@me reroll=death reroll=round count=3 conflicts=1", "How should cosmetics be randomized?");
	ConVar_AddType(RandomizedType_Rune, "randomizer_rune", "", "How should rune be randomized?");
	ConVar_AddType(RandomizedType_Spells, "randomizer_spells", "", "How should spells be randomized?");
}

void ConVar_AddType(RandomizedType nType, const char[] sName, const char[] sDefault, const char[] sDesp)
{
	g_cvRandomize[nType] = CreateConVar(sName, sDefault, sDesp);
	g_cvRandomize[nType].AddChangeHook(ConVar_RandomizeChanged);
	
	char sBuffer[1024];
	g_cvRandomize[nType].GetString(sBuffer, sizeof(sBuffer));
	ConVar_RandomizeChanged(g_cvRandomize[nType], "", sBuffer);
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
	RandomizedType nType = ConVar_GetType(convar);
	Group_ClearType(nType);
	
	//TODO revert convar value if error
	
	if (!sNewValue[0])	//Empty string
		return;
	
	char sGroups[32][256];
	int iGroupCount = ExplodeString(sNewValue, ",", sGroups, sizeof(sGroups), sizeof(sGroups[]));
	for (int i = 0; i < iGroupCount; i++)
	{
		RandomizedInfo eGroup;
		eGroup.nType = nType;
		
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
				return;
			}
			
			if (StrEqual(sParam[0], "trigger", false))
			{
				strcopy(eGroup.sTrigger, sizeof(eGroup.sTrigger), sParam[1]);
			}
			else if (StrEqual(sParam[0], "group", false))
			{
				strcopy(eGroup.sGroup, sizeof(eGroup.sGroup), sParam[1]);
			}
			else if (StrEqual(sParam[0], "reroll", false))
			{
				if (!ConVar_AddReroll(sParam[1], eGroup.nReroll))
				{
					PrintToServer("Invalid 'reroll' value '%s'", sParam[1]);
					return;
				}
			}
			else if (StrEqual(sParam[0], "same", false))
			{
				if (!StringToIntEx(sParam[1], eGroup.bSame))
				{
					PrintToServer("Invalid 'same' value '%s' (must be integer)", sParam[1]);
					return;
				}
			}
			else if (StrEqual(sParam[0], "count", false))
			{
				if (!StringToIntEx(sParam[1], eGroup.iCount))
				{
					PrintToServer("Invalid 'count' value '%s' (must be integer)", sParam[1]);
					return;
				}
			}
			else if (StrEqual(sParam[0], "count-primary", false))
			{
				if (!StringToIntEx(sParam[1], eGroup.iCountSlot[WeaponSlot_Primary]))
				{
					PrintToServer("Invalid 'count-primary' value '%s' (must be integer)", sParam[1]);
					return;
				}
			}
			else if (StrEqual(sParam[0], "count-secondary", false))
			{
				if (!StringToIntEx(sParam[1], eGroup.iCountSlot[WeaponSlot_Secondary]))
				{
					PrintToServer("Invalid 'count-secondary' value '%s' (must be integer)", sParam[1]);
					return;
				}
			}
			else if (StrEqual(sParam[0], "count-melee", false))
			{
				if (!StringToIntEx(sParam[1], eGroup.iCountSlot[WeaponSlot_Melee]))
				{
					PrintToServer("Invalid 'count' value '%s' (must be integer)", sParam[1]);
					return;
				}
			}
			else if (StrEqual(sParam[0], "defaultclass", false))
			{
				if (!StringToIntEx(sParam[1], eGroup.bDefaultClass))
				{
					PrintToServer("Invalid 'defaultclass' value '%s' (must be integer)", sParam[1]);
					return;
				}
			}
			else if (StrEqual(sParam[0], "conflicts", false))
			{
				if (!StringToIntEx(sParam[1], eGroup.bConflicts))
				{
					PrintToServer("Invalid 'conflicts' value '%s' (must be integer)", sParam[1]);
					return;
				}
			}
			else
			{
				PrintToServer("Invalid param name '%s'", sParam[0]);
				return;
			}
			
		}
		
		Group_Add(eGroup);
	}
}

RandomizedType ConVar_GetType(ConVar convar)
{
	for (int i = 0; i < sizeof(g_cvRandomize); i++)
		if (g_cvRandomize[i] == convar)
			return view_as<RandomizedType>(i);
	
	return RandomizedType_None;
}

bool ConVar_AddReroll(const char[] sBuffer, RandomizedReroll &nReroll)
{
	for (int i = 0; i < sizeof(g_sRandomizedReroll); i++)
	{
		if (StrContains(g_sRandomizedReroll[i], sBuffer, false) == 0)
		{
			nReroll |= view_as<RandomizedReroll>(1<<i);
			return true;
		}
	}
	
	return false;
}