static char g_sRandomizedTarget[][] = {
	"self",
	"global",
	"same",
};

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
	
	g_cvWeaponsFromClass = CreateConVar("randomizer_weaponsfromclass", "0", "Should generated weapon only be from class that can normally equip?", _, true, 0.0, true, 1.0);
	g_cvWeaponsFromClass.AddChangeHook(ConVar_RandomizeChanged);
	
	g_cvWeaponsCount = CreateConVar("randomizer_weaponscount", "0", "How many weapons at minimum to randomly generate?", _, true, 0.0, true, float(MAX_WEAPONS));
	g_cvWeaponsCount.AddChangeHook(ConVar_RandomizeChanged);
	
	g_cvWeaponsSlotCount[WeaponSlot_Primary] = CreateConVar("randomizer_weaponscount_primary", "1", "How many primary weapons at minimum to randomly generate?", _, true, 0.0, true, float(MAX_WEAPONS));
	g_cvWeaponsSlotCount[WeaponSlot_Primary].AddChangeHook(ConVar_RandomizeChanged);
	
	g_cvWeaponsSlotCount[WeaponSlot_Secondary] = CreateConVar("randomizer_weaponscount_secondary", "1", "How many secondary weapons at minimum to randomly generate?", _, true, 0.0, true, float(MAX_WEAPONS));
	g_cvWeaponsSlotCount[WeaponSlot_Secondary].AddChangeHook(ConVar_RandomizeChanged);
	
	g_cvWeaponsSlotCount[WeaponSlot_Melee] = CreateConVar("randomizer_weaponscount_melee", "1", "How many melee weapons at minimum to randomly generate?", _, true, 0.0, true, float(MAX_WEAPONS));
	g_cvWeaponsSlotCount[WeaponSlot_Melee].AddChangeHook(ConVar_RandomizeChanged);
	
	g_cvCosmeticsConflicts = CreateConVar("randomizer_cosmeticsconflicts", "1", "Should generated cosmetics check for possible conflicts?", _, true, 0.0, true, 1.0);
//	g_cvCosmeticsConflicts.AddChangeHook(ConVar_CosmeticsChanged);
	
	ConVar_AddType(RandomizedType_Class, "randomizer_class", "@all self death, @all global round", "How should class be randomized?");
	ConVar_AddType(RandomizedType_Weapons, "randomizer_weapons", "@all self death, @all global round", "How should weapons be randomized?");
	ConVar_AddType(RandomizedType_Cosmetics, "randomizer_cosmetics", "@all self death, @all global round", "How should mannpower be randomized?");	//TODO
	ConVar_AddType(RandomizedType_Mannpower, "randomizer_mannpower", "", "How should class be randomized?");
	
	g_cvDroppedWeapons = CreateConVar("randomizer_droppedweapons", "0", "Allow dropped weapons?", _, true, 0.0, true, 1.0);
	g_cvHuds = CreateConVar("randomizer_huds", "1", "Hud to use to display weapons. 0 = none, 1 = hud text, 2 = menu.", _, true, 0.0, true, float(HudMode_MAX - 1));
}

void ConVar_AddType(RandomizedType nType, const char[] sName, const char[] sDefault, const char[] sDesp)
{
	g_cvRandomize[nType] = CreateConVar(sName, sDefault, sDesp);
	g_cvRandomize[nType].AddChangeHook(ConVar_RandomizeChanged);
	
	char sBuffer[256];
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
	
	if (!sNewValue[0])	//Empty string
		return;
	
	char sGroups[32][256];
	int iGroupCount = ExplodeString(sNewValue, ",", sGroups, sizeof(sGroups), sizeof(sGroups[]));
	for (int i = 0; i < iGroupCount; i++)
	{
		RandomizedInfo eGroup;
		eGroup.nType = nType;
		
		TrimString(sGroups[i]);
		char sBuffer[16][256];
		int iCount = ExplodeString(sGroups[i], " ", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));
		for (int j = 0; j < iCount; j++)
		{
			TrimString(sBuffer[j]);
			if (ConVar_GetTarget(sBuffer[j], eGroup.nTarget))
				continue;
			
			if (ConVar_AddFlag(sBuffer[j], eGroup.nReroll))
				continue;
			
			strcopy(eGroup.sTarget, sizeof(eGroup.sTarget), sBuffer[j]);
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

bool ConVar_GetTarget(const char[] sBuffer, RandomizedTarget &nTarget)
{
	for (int i = 0; i < sizeof(g_sRandomizedTarget); i++)
	{
		if (StrContains(g_sRandomizedTarget[i], sBuffer, false) == 0)
		{
			nTarget = view_as<RandomizedTarget>(i);
			return true;
		}
	}
	
	return false;
}

bool ConVar_AddFlag(const char[] sBuffer, RandomizedReroll &nReroll)
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