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
	
	char sTarget[32], sClass[32];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	GetCmdArg(2, sClass, sizeof(sClass));
	TFClassType nClass = TF2_GetClass(sClass);
	if (nClass == TFClass_Unknown)
	{
		ReplyToCommand(iClient, "Unable to get class '%s'", sClass);
		return Plugin_Handled;
	}
	
	int[] iTargetList = new int[MaxClients];
	char sTargetName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML);
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "Could not find anyone to set class");
		return Plugin_Handled;
	}
	
	char sBadName[MAX_TARGET_LENGTH];
	if (!Group_IsTargetListGood(RandomizedType_Class, iTargetList, iTargetCount, sBadName))
	{
		ReplyToCommand(iClient, "Could not target '%s' when some, but not all is '%s'", sTargetName, sBadName);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < iTargetCount; i++)
	{
		RandomizedInfo eInfo;
		if (Group_GetClientSameInfo(iTargetList[i], RandomizedType_Class, eInfo))
		{
			eInfo.nClass = nClass;
			Group_SetInfo(eInfo);
		}
		
		g_eClientInfo[iTargetList[i]].nClass = nClass;
		RefreshClient(iTargetList[i]);
	}
	
	ReplyToCommand(iClient, "Set %s class to %s", sTargetName, sClass);
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
	
	char sTarget[32];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	
	int[] iTargetList = new int[MaxClients];
	char sTargetName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML);
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "Could not find anyone to set weapons");
		return Plugin_Handled;
	}
	
	char sBadName[MAX_TARGET_LENGTH];
	if (!Group_IsTargetListGood(RandomizedType_Weapons, iTargetList, iTargetCount, sBadName))
	{
		ReplyToCommand(iClient, "Could not target '%s' when some, but not all is '%s'", sTargetName, sBadName);
		return Plugin_Handled;
	}
	
	RandomizedWeapon eWeapon;
	int iCount = GetWeaponsFromCommand(iClient, eWeapon);
	if (iCount == 0)
		return Plugin_Handled;
	
	for (int i = 0; i < iTargetCount; i++)
	{
		RandomizedWeapon eBuffer[CLASS_MAX+1];
		if (Group_GetClientSameWeapon(iTargetList[i], RandomizedType_Weapons, eBuffer))
		{
			SetRandomizedWeapon(eBuffer, eWeapon, iCount);
			
			RandomizedInfo eInfo;
			Group_GetClientSameInfo(iTargetList[i], RandomizedType_Weapons, eInfo);
			Group_SetWeapon(eInfo, eBuffer);
		}
		
		SetRandomizedWeapon(g_eClientWeapon[iTargetList[i]], eWeapon, iCount);
		RefreshClient(iTargetList[i]);
	}
	
	if (iCount == 1)
	{
		char sName[256];
		Weapons_GetName(eWeapon.iIndex[0], sName, sizeof(sName));
		Format(sName, sizeof(sName), "%T", sName, LANG_SERVER);
		ReplyToCommand(iClient, "Set %s weapon '%s' for slot '%s'", sTargetName, sName, g_sSlotName[eWeapon.iSlot[0]]);
	}
	else
	{
		ReplyToCommand(iClient, "Set %s %d weapons", sTargetName, iCount);
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
	
	char sTarget[32];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	
	int[] iTargetList = new int[MaxClients];
	char sTargetName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML);
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "Could not find anyone to set weapons");
		return Plugin_Handled;
	}
	
	char sBadName[MAX_TARGET_LENGTH];
	if (!Group_IsTargetListGood(RandomizedType_Weapons, iTargetList, iTargetCount, sBadName))
	{
		ReplyToCommand(iClient, "Could not target '%s' when some, but not all is '%s'", sTargetName, sBadName);
		return Plugin_Handled;
	}
	
	RandomizedWeapon eWeapon;
	int iCount = GetWeaponsFromCommand(iClient, eWeapon);
	if (iCount == 0)
		return Plugin_Handled;
	
	for (int i = 0; i < iTargetCount; i++)
	{
		RandomizedWeapon eBuffer[CLASS_MAX+1];
		if (Group_GetClientSameWeapon(iTargetList[i], RandomizedType_Weapons, eBuffer))
		{
			SetSlotRandomizedWeapon(eBuffer, eWeapon, iCount);
			
			RandomizedInfo eInfo;
			Group_GetClientSameInfo(iTargetList[i], RandomizedType_Weapons, eInfo);
			Group_SetWeapon(eInfo, eBuffer);
		}
		
		SetSlotRandomizedWeapon(g_eClientWeapon[iTargetList[i]], eWeapon, iCount);
		RefreshClient(iTargetList[i]);
	}
	
	if (iCount == 1)
	{
		char sName[256];
		Weapons_GetName(eWeapon.iIndex[0], sName, sizeof(sName));
		Format(sName, sizeof(sName), "%T", sName, LANG_SERVER);
		ReplyToCommand(iClient, "Set %s weapon '%s' for slot '%s'", sTargetName, sName, g_sSlotName[eWeapon.iSlot[0]]);
	}
	else
	{
		ReplyToCommand(iClient, "Set %s %d weapons", sTargetName, iCount);
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
	
	char sTarget[32];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	
	int[] iTargetList = new int[MaxClients];
	char sTargetName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML);
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "Could not find anyone to give weapons");
		return Plugin_Handled;
	}
	
	char sBadName[MAX_TARGET_LENGTH];
	if (!Group_IsTargetListGood(RandomizedType_Weapons, iTargetList, iTargetCount, sBadName))
	{
		ReplyToCommand(iClient, "Could not target '%s' when some, but not all is '%s'", sTargetName, sBadName);
		return Plugin_Handled;
	}
	
	RandomizedWeapon eWeapon;
	int iCount = GetWeaponsFromCommand(iClient, eWeapon);
	if (iCount == 0)
		return Plugin_Handled;
	
	for (int i = 0; i < iTargetCount; i++)
	{
		RandomizedWeapon eBuffer[CLASS_MAX+1];
		if (Group_GetClientSameWeapon(iTargetList[i], RandomizedType_Weapons, eBuffer))
		{
			GiveRandomizedWeapon(eBuffer, eWeapon, iCount);
			
			RandomizedInfo eInfo;
			Group_GetClientSameInfo(iTargetList[i], RandomizedType_Weapons, eInfo);
			Group_SetWeapon(eInfo, eBuffer);
		}
		
		GiveRandomizedWeapon(g_eClientWeapon[iTargetList[i]], eWeapon, iCount);
		RefreshClient(iTargetList[i]);
	}
	
	if (iCount == 1)
	{
		char sName[256];
		Weapons_GetName(eWeapon.iIndex[0], sName, sizeof(sName));
		Format(sName, sizeof(sName), "%T", sName, LANG_SERVER);
		ReplyToCommand(iClient, "Set %s weapon '%s' for slot '%s'", sTargetName, sName, g_sSlotName[eWeapon.iSlot[0]]);
	}
	else
	{
		ReplyToCommand(iClient, "Set %s %d weapons", sTargetName, iCount);
	}
	
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
	
	char sTarget[32];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	
	int[] iTargetList = new int[MaxClients];
	char sTargetName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML);
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "Could not find anyone to regenerate class and weapons");
		return Plugin_Handled;
	}
	
	char sBadName[MAX_TARGET_LENGTH];
	if (!Group_IsTargetListGood(RandomizedType_None, iTargetList, iTargetCount, sBadName))	//RandomizedType_None as all types
	{
		ReplyToCommand(iClient, "Could not target '%s' when some, but not all is '%s'", sTargetName, sBadName);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < iTargetCount; i++)
	{
		Group_RandomizeClient(iTargetList[i], RandomizedReroll_Force);
		RefreshClient(iTargetList[i]);
	}
	
	ReplyToCommand(iClient, "Regenerated %s loadout", sTargetName);
	return Plugin_Handled;
}

int GetWeaponsFromCommand(int iClient, RandomizedWeapon eWeapon)
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
		eWeapon.iSlot[i] = RemoveSlotFromCommand(sWeapons[i], sizeof(sWeapons[]));
		
		if (!StringToIntEx(sWeapons[i], eWeapon.iIndex[i]))
			eWeapon.iIndex[i] = Weapons_GetIndexFromName(sWeapons[i]);
		
		if (eWeapon.iIndex[i] == -1)
		{
			ReplyToCommand(iClient, "Unable to find weapon by name '%s'", sWeapons[i]);
			return 0;
		}
		
		bool bValid;
		
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			int iSlot = TF2_GetSlotFromIndex(eWeapon.iIndex[i], view_as<TFClassType>(iClass));
			if (eWeapon.iSlot[i] != -1 && eWeapon.iSlot[i] == iSlot)
			{
				bValid = true;
				break;
			}
			else if (eWeapon.iSlot[i] == -1 && 0 <= iSlot <= WeaponSlot_Building)
			{
				eWeapon.iSlot[i] = iSlot;
				bValid = true;
				break;
			}
		}
		
		if (!bValid)
		{
			if (eWeapon.iSlot[i] == -1)
			{
				ReplyToCommand(iClient, "Cannot find valid slot for Weapon index '%d'", eWeapon.iIndex[i]);
			}
			else
			{
				char sName[256];
				Weapons_GetName(eWeapon.iIndex[i], sName, sizeof(sName));
				Format(sName, sizeof(sName), "%T", sName, LANG_SERVER);
				ReplyToCommand(iClient, "Weapon '%s' cannot be used for slot '%s'", sName, g_sSlotName[eWeapon.iSlot[i]]);
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