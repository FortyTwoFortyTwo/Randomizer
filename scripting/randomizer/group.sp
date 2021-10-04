static RandomizedInfo g_eGroupInfo[MAX_GROUPS];	//List of groups on what to randomize

void Group_Init()
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
		g_eGroupInfo[i].Reset();
}

void Group_ClearType(RandomizedType nType)
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		if (g_eGroupInfo[i].nType == nType)
		{
			int[] iTargetList = new int[MaxClients];
			int iTargetCount = Group_GetTargetList(g_eGroupInfo[i].sGroup, iTargetList);
			
			g_eGroupInfo[i].Reset();
			
			//Randomize client after his group removed
			for (int j = 0; j < iTargetCount; j++)
				Loadout_RandomizeClient(iTargetList[j], nType);
		}
	}
}

void Group_Add(RandomizedInfo eInfo)
{
	//Find empty space to insert it
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		if (g_eGroupInfo[i].nType == RandomizedType_None)
		{
			g_eGroupInfo[i] = eInfo;
			Loadout_RandomizeGroup(i);
			
			//Refresh any clients using this
			int[] iTargetList = new int[MaxClients];
			int iTargetCount = Group_GetTargetList(eInfo.sGroup, iTargetList);
			for (int j = 0; j < iTargetCount; j++)
				Loadout_RandomizeClient(iTargetList[j], eInfo.nType);
			
			return;
		}
	}
}

bool Group_IsClientRandomized(int iClient, RandomizedType nType)
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType != nType)
			continue;
		
		int[] iTargetList = new int[MaxClients];
		int iTargetCount = Group_GetTargetList(eInfo.sTrigger, iTargetList);
		for (int j = 0; j < iTargetCount; j++)
			if (Group_TargetsClient(eInfo.sGroup, iClient, iTargetList[j]))
				return true;
	}
	
	return false;
}

void Group_TriggerRandomizeClient(int iClient, RandomizedReroll nReroll)
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType == RandomizedType_None)
			continue;
		
		if (!Group_TargetsClient(eInfo.sTrigger, iClient))
			continue;
		
		if (!(eInfo.nReroll & nReroll))
			continue;
		
		if (eInfo.bSame)
		{
			//Use group to randomize same loadout to distribute all clients in group
			Loadout_RandomizeGroup(i);
		}
		else
		{
			//Randomize each clients
			int[] iTargetList = new int[MaxClients];
			int iTargetCount = Group_GetTargetList(eInfo.sGroup, iTargetList, iClient);
			for (int j = 0; j < iTargetCount; j++)
				Loadout_RandomizeClient(iTargetList[j], eInfo.nType);
		}
	}
}

void Group_TriggerRandomizeAll(RandomizedReroll nReroll)
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType == RandomizedType_None)
			continue;
		
		if (!(eInfo.nReroll & nReroll))
			continue;
		
		if (eInfo.bSame)
		{
			//Use group to randomize same loadout to distribute all clients in group
			Loadout_RandomizeGroup(i);
		}
		else
		{
			int[] iTargetList = new int[MaxClients];
			int iTargetCount = Group_GetTargetList(eInfo.sGroup, iTargetList);
			for (int j = 0; j < iTargetCount; j++)
				Loadout_RandomizeClient(iTargetList[j], eInfo.nType);
		}
	}
}

int Group_GetClientSameInfoPos(int iClient, RandomizedType nType)
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType != nType)
			continue;
		
		if (!eInfo.bSame)
			continue;
		
		if (!Group_TargetsClient(eInfo.sGroup, iClient))
			continue;
		
		return i;
	}
	
	return -1;
}

bool Group_IsPosSameForClients(int[] iClients, int iCount, int iPos, RandomizedType nType)
{
	RandomizedInfo eInfo;
	eInfo = g_eGroupInfo[iPos];
	if (eInfo.nType != nType)
		return false;
	
	if (!eInfo.bSame)
		return false;
	
	int[] iTargetList = new int[MaxClients];
	int iTargetCount = Group_GetTargetList(eInfo.sGroup, iTargetList);
	for (int i = 0; i < iCount; i++)
		if (Group_IsInList(iClients[i], iTargetList, iTargetCount))
			return true;
	
	return false;
}

void Group_GetInfoFromPos(int iPos, RandomizedInfo eBuffer)
{
	eBuffer = g_eGroupInfo[iPos];
}

bool Group_GetInfoFromClient(int iClient, RandomizedType nType, RandomizedInfo eBuffer)
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType != nType)
			continue;
		
		int[] iTargetList = new int[MaxClients];
		int iTargetCount = Group_GetTargetList(eInfo.sTrigger, iTargetList);
		for (int j = 0; j < iTargetCount; j++)
		{
			if (Group_TargetsClient(eInfo.sGroup, iClient, iTargetList[j]))
			{
				eBuffer = eInfo;
				return true;
			}
		}
	}
	
	return false;
}

int Group_GetTargetList(const char[] sGroup, int[] iTargetList, int iAdmin = 0, char sGroupName[MAX_TARGET_LENGTH] = NULL_STRING)
{
	bool bIsML;
	return ProcessTargetString(sGroup, iAdmin, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sGroupName, sizeof(sGroupName), bIsML);
}

bool Group_TargetsClient(const char[] sGroup, int iClient, int iAdmin = 0)
{
	int[] iTargetList = new int[MaxClients];
	int iTargetCount = Group_GetTargetList(sGroup, iTargetList, iAdmin);
	for (int i = 0; i < iTargetCount; i++)
		if (iTargetList[i] == iClient)
			return true;
	
	return false;
}

bool Group_RandomizeFromClients(RandomizedType nType, const int[] iTargetList, int iTargetCount, char sGroupName[MAX_TARGET_LENGTH])
{
	//Check if list of clients is valid for randomize
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo; 
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType != nType && nType != RandomizedType_None)
			continue;
		
		if (!eInfo.bSame)
			continue;
		
		int[] iBufferList = new int[MaxClients];
		int iBufferCount = Group_GetTargetList(eInfo.sGroup, iBufferList, _, sGroupName);
		
		int iFound = 0;	//-1 if found none, 1 if found so far
		
		for (int j = 0; j < iBufferCount; j++)
		{
			if (Group_IsInList(iBufferList[j], iTargetList, iTargetCount))
			{
				if (iFound != -1)
					iFound = 1;
				else
					return false;
			}
			else
			{
				if (iFound != 1)
					iFound = -1;
				else
					return false;
			}
		}
	}
	
	//List is good, can randomize
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo; 
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType != nType && nType != RandomizedType_None)
			continue;
		
		Loadout_RandomizeGroup(i);
	}
	
	return true;
}

bool Group_IsInList(int iClient, const int[] iTargetList, int iTargetCount)
{
	for (int i = 0; i < iTargetCount; i++)
		if (iTargetList[i] == iClient)
			return true;
	
	return false;
}