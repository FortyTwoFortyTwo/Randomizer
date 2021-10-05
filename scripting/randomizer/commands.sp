static char g_sSlotName[][] = {
	"Primary",
	"Secondary",
	"Melee",
	"PDA1",
	"PDA2",
	"Building",
};

void Commands_Init()
{
	RegConsoleCmd("sm_cantsee", Command_CantSee);
	
	RegAdminCmd("sm_rndclass", Command_Class, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_rndsetweapon", Command_SetWeapon, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_rndsetslotweapon", Command_SetSlotWeapon, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_rndgiveweapon", Command_GiveWeapon, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_rndrune", Command_Rune, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_rndgenerate", Command_Generate, ADMFLAG_CHANGEMAP);
}

public Action Command_CantSee(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iClient == 0)
		return Plugin_Handled;
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon <= MaxClients)
		return Plugin_Handled;
	
	if (ViewModels_ToggleInvisible(iWeapon))
		ReplyToCommand(iClient, "Your active weapon is now transparent.");
	else
		ReplyToCommand(iClient, "Your active weapon is now fully visible.");
	
	return Plugin_Handled;
}

public Action Command_Class(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "Format: sm_rndclass <@target> <class string>");
		return Plugin_Handled;
	}
	
	char sGroup[32], sClass[32];
	GetCmdArg(1, sGroup, sizeof(sGroup));
	GetCmdArg(2, sClass, sizeof(sClass));
	TFClassType nClass = TF2_GetClass(sClass);
	if (nClass == TFClass_Unknown)
	{
		ReplyToCommand(iClient, "Unable to get class '%s'", sClass);
		return Plugin_Handled;
	}
	
	int[] iTargetList = new int[MaxClients];
	char sGroupName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sGroup, iClient, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sGroupName, sizeof(sGroupName), bIsML);
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "Could not find anyone to set class");
		return Plugin_Handled;
	}
	
	Loadout_SetClass(iTargetList, iTargetCount, nClass);
	
	ReplyToCommand(iClient, "Set %s class to %s", sGroupName, sClass);
	return Plugin_Handled;
}

public Action Command_SetWeapon(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "Format: sm_rndsetweapon <@target> <weapon name/defindex and slot>");
		return Plugin_Handled;
	}
	
	char sGroup[32];
	GetCmdArg(1, sGroup, sizeof(sGroup));
	
	int[] iTargetList = new int[MaxClients];
	char sGroupName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sGroup, iClient, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sGroupName, sizeof(sGroupName), bIsML);
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "Could not find anyone to set weapons");
		return Plugin_Handled;
	}
	
	RandomizedWeapon eWeapon[MAX_WEAPONS];
	int iCount = GetWeaponsFromCommand(iClient, eWeapon);
	if (iCount == 0)
		return Plugin_Handled;
	
	Loadout_SetWeapon(iTargetList, iTargetCount, eWeapon, iCount);
	
	if (iCount == 1)
	{
		char sName[256];
		Weapons_GetName(eWeapon[0].iIndex, sName, sizeof(sName));
		Format(sName, sizeof(sName), "%T", sName, LANG_SERVER);
		ReplyToCommand(iClient, "Set %s weapon '%s' for slot '%s'", sGroupName, sName, g_sSlotName[eWeapon[0].iSlot]);
	}
	else
	{
		ReplyToCommand(iClient, "Set %s %d weapons", sGroupName, iCount);
	}
	
	return Plugin_Handled;
}

public Action Command_SetSlotWeapon(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "Format: sm_rndsetweapon <@target> <weapon name/defindex and slot>");
		return Plugin_Handled;
	}
	
	char sGroup[32];
	GetCmdArg(1, sGroup, sizeof(sGroup));
	
	int[] iTargetList = new int[MaxClients];
	char sGroupName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sGroup, iClient, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sGroupName, sizeof(sGroupName), bIsML);
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "Could not find anyone to set weapons");
		return Plugin_Handled;
	}
	
	RandomizedWeapon eWeapon[MAX_WEAPONS];
	int iCount = GetWeaponsFromCommand(iClient, eWeapon);
	if (iCount == 0)
		return Plugin_Handled;
	
	Loadout_SetSlotWeapon(iTargetList, iTargetCount, eWeapon, iCount);
	
	if (iCount == 1)
	{
		char sName[256];
		Weapons_GetName(eWeapon[0].iIndex, sName, sizeof(sName));
		Format(sName, sizeof(sName), "%T", sName, LANG_SERVER);
		ReplyToCommand(iClient, "Set %s weapon '%s' for slot '%s'", sGroupName, sName, g_sSlotName[eWeapon[0].iSlot]);
	}
	else
	{
		ReplyToCommand(iClient, "Set %s %d weapons", sGroupName, iCount);
	}
	
	return Plugin_Handled;
}

public Action Command_GiveWeapon(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "Format: sm_rndgiveweapon <@target> <weapon name/defindex and slot>");
		return Plugin_Handled;
	}
	
	char sGroup[32];
	GetCmdArg(1, sGroup, sizeof(sGroup));
	
	int[] iTargetList = new int[MaxClients];
	char sGroupName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sGroup, iClient, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sGroupName, sizeof(sGroupName), bIsML);
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "Could not find anyone to give weapons");
		return Plugin_Handled;
	}
	
	RandomizedWeapon eWeapon[MAX_WEAPONS];
	int iCount = GetWeaponsFromCommand(iClient, eWeapon);
	if (iCount == 0)
		return Plugin_Handled;
	
	Loadout_GiveWeapon(iTargetList, iTargetCount, eWeapon, iCount);
	
	if (iCount == 1)
	{
		char sName[256];
		Weapons_GetName(eWeapon[0].iIndex, sName, sizeof(sName));
		Format(sName, sizeof(sName), "%T", sName, LANG_SERVER);
		ReplyToCommand(iClient, "Set %s weapon '%s' for slot '%s'", sGroupName, sName, g_sSlotName[eWeapon[0].iSlot]);
	}
	else
	{
		ReplyToCommand(iClient, "Set %s %d weapons", sGroupName, iCount);
	}
	
	return Plugin_Handled;
}

public Action Command_Rune(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "Format: sm_rndrune <@target> <rune id>");
		return Plugin_Handled;
	}
	
	char sGroup[32], sRuneType[32];
	GetCmdArg(1, sGroup, sizeof(sGroup));
	GetCmdArg(2, sRuneType, sizeof(sRuneType));
	
	int iRuneType;
	if (!StringToIntEx(sRuneType, iRuneType))
	{
		ReplyToCommand(iClient, "Unknown rune id '%s'", sRuneType);
		return Plugin_Handled;
	}
	else if (iRuneType < -1 || iRuneType >= g_iRuneCount)
	{
		ReplyToCommand(iClient, "Rune id must be between -1 to %d", g_iRuneCount - 1);
		return Plugin_Handled;
	}
	
	int[] iTargetList = new int[MaxClients];
	char sGroupName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sGroup, iClient, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sGroupName, sizeof(sGroupName), bIsML);
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "Could not find anyone to set rune");
		return Plugin_Handled;
	}
	
	Loadout_SetRune(iTargetList, iTargetCount, iRuneType);
	
	ReplyToCommand(iClient, "Set %s rune to %d", sGroupName, iRuneType);
	return Plugin_Handled;
}

public Action Command_Generate(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 1)
	{
		ReplyToCommand(iClient, "Format: sm_rndgenerate <@target>");
		return Plugin_Handled;
	}
	
	char sGroup[32];
	GetCmdArg(1, sGroup, sizeof(sGroup));
	
	int[] iTargetList = new int[MaxClients];
	char sGroupName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sGroup, iClient, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sGroupName, sizeof(sGroupName), bIsML);
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "Could not find anyone to regenerate class and weapons");
		return Plugin_Handled;
	}
	
	for (int i = 0; i < iTargetCount; i++)
	{
		Loadout_RandomizeClientAll(iTargetList[i]);
		Loadout_RefreshClient(iTargetList[i]);
	}
	
	ReplyToCommand(iClient, "Regenerated %s loadout", sGroupName);
	return Plugin_Handled;
}

int GetWeaponsFromCommand(int iClient, RandomizedWeapon eWeapon[MAX_WEAPONS])
{
	//Grab whole args, skip first 1 arg on target
	char sCommand[256];
	GetCmdArgString(sCommand, sizeof(sCommand));
	int iArg = 1, iLen = strlen(sCommand);
	for (int i = 1; i < iLen; i++)
	{
		if (sCommand[i] == ' ' && sCommand[i-1] != ' ')
			iArg++;
	
		if (iArg == 2)
		{
			Format(sCommand, sizeof(sCommand), sCommand[i+1]);
			break;
		}
	}
	
	char sWeapons[MAX_WEAPONS][64];
	int iCount = ExplodeString(sCommand, ",", sWeapons, sizeof(sWeapons), sizeof(sWeapons[]));
	for (int i = 0; i < iCount; i++)
	{
		TrimString(sWeapons[i]);
		eWeapon[i].iSlot = RemoveSlotFromCommand(sWeapons[i], sizeof(sWeapons[]));
		
		if (!StringToIntEx(sWeapons[i], eWeapon[i].iIndex))
			eWeapon[i].iIndex = Weapons_GetIndexFromName(sWeapons[i]);
		
		if (eWeapon[i].iIndex == -1)
		{
			ReplyToCommand(iClient, "Unable to find weapon by name '%s'", sWeapons[i]);
			return 0;
		}
		
		bool bValid;
		
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			int iSlot = TF2_GetSlotFromIndex(eWeapon[i].iIndex, view_as<TFClassType>(iClass));
			if (eWeapon[i].iSlot != -1 && eWeapon[i].iSlot == iSlot)
			{
				bValid = true;
				break;
			}
			else if (eWeapon[i].iSlot == -1 && 0 <= iSlot <= WeaponSlot_Building)
			{
				eWeapon[i].iSlot = iSlot;
				bValid = true;
				break;
			}
		}
		
		if (!bValid)
		{
			if (eWeapon[i].iSlot == -1)
			{
				ReplyToCommand(iClient, "Cannot find valid slot for Weapon index '%d'", eWeapon[i].iIndex);
			}
			else
			{
				char sName[256];
				Weapons_GetName(eWeapon[i].iIndex, sName, sizeof(sName));
				Format(sName, sizeof(sName), "%T", sName, LANG_SERVER);
				ReplyToCommand(iClient, "Weapon '%s' cannot be used for slot '%s'", sName, g_sSlotName[eWeapon[i].iSlot]);
			}
			
			return 0;
		}
	}
	
	return iCount;
}

int RemoveSlotFromCommand(char[] sCommand, int iLength)
{
	char sWeapon[8][64];	//Need a better name instead of just without s...
	int iCount = ExplodeString(sCommand, " ", sWeapon, sizeof(sWeapon), sizeof(sWeapon[]));
	for (int i = 0; i < iCount; i++)
	{
		for (int iSlot = 0; iSlot < sizeof(g_sSlotName); iSlot++)
		{
			if (StrContains(g_sSlotName[iSlot], sWeapon[i], false) == 0)
			{
				char sBuffer[64];
				if (i == 0)
					Format(sBuffer, sizeof(sBuffer), "%s ", sWeapon[i]);
				else
					Format(sBuffer, sizeof(sBuffer), " %s", sWeapon[i]);
				
				ReplaceString(sCommand, iLength, sBuffer, "", false);
				return iSlot;
			}
		}
	}
	
	return -1;
}