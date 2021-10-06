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
			int[] iGroupList = new int[MaxClients];
			int iGroupCount = Group_GetAllGroupList(g_eGroupInfo[i], iGroupList);
			
			g_eGroupInfo[i].Reset();
			
			//Randomize client after his group removed
			for (int j = 0; j < iGroupCount; j++)
				Loadout_RandomizeClient(iGroupList[j], nType);
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
			
			//Randomize group for "same"
			Loadout_RandomizeGroup(i);
			
			//Randomize everyone in group for not "same"
			int[] iGroupList = new int[MaxClients];
			int iGroupCount = Group_GetAllGroupList(eInfo, iGroupList);
			for (int j = 0; j < iGroupCount; j++)
				Loadout_RandomizeClient(iGroupList[j], eInfo.nType);
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
		
		if (Group_IsClientInAllGroup(eInfo, iClient))
			return true;
	}
	
	return false;
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
		
		if (Group_IsClientInAllGroup(eInfo, iClient))
			return i;
	}
	
	return -1;
}

void Group_GetInfoFromClient(int iClient, RandomizedType nType, RandomizedInfo eBuffer)
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType != nType)
			continue;
		
		if (Group_IsClientInAllGroup(eInfo, iClient))
		{
			eBuffer = eInfo;
			return;
		}
	}
}

void Group_GetInfoFromPos(int iPos, RandomizedInfo eBuffer)
{
	eBuffer = g_eGroupInfo[iPos];
}

bool Group_CanRandomizePosForClients(int iPos, RandomizedType nType, const int[] iClients, int iCount)
{
	RandomizedInfo eInfo; 
	eInfo = g_eGroupInfo[iPos];
	if (eInfo.nType != nType)
		return false;
	
	if (!eInfo.bSame)
		return false;
	
	int[] iGroupList = new int[MaxClients];
	int iGroupCount = Group_GetAllGroupList(eInfo, iGroupList);
	for (int i = 0; i < iGroupCount; i++)
	{
		int iFound = 0;	//-1 if found none, 1 if found so far
		
		if (Group_IsClientInList(iGroupList[i], iClients, iCount))
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
	
	return true;
}

void Group_TriggerRandomizeClient(int iClient, RandomizedAction nAction)
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType == RandomizedType_None)
			continue;
		
		if (!(eInfo.nAction & nAction))
			continue;
		
		if (!Group_IsClientInTrigger(eInfo, iClient))
			continue;
		
		if (eInfo.bSame)
		{
			//Use group to randomize same loadout to distribute all clients in group
			Loadout_RandomizeGroup(i);
		}
		else
		{
			//Randomize each clients
			int[] iGroupList = new int[MaxClients];
			int iGroupCount = Group_GetGroupList(eInfo, iGroupList, iClient);
			for (int j = 0; j < iGroupCount; j++)
				Loadout_RandomizeClient(iGroupList[j], eInfo.nType);
		}
	}
}

void Group_TriggerRandomizeAll(RandomizedAction nAction)
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType == RandomizedType_None)
			continue;
		
		if (!(eInfo.nAction & nAction))
			continue;
		
		if (eInfo.bSame)
		{
			//Use group to randomize same loadout to distribute all clients in group
			Loadout_RandomizeGroup(i);
		}
		else
		{
			int[] iGroupList = new int[MaxClients];
			int iGroupCount = Group_GetAllGroupList(eInfo, iGroupList);
			for (int j = 0; j < iGroupCount; j++)
				Loadout_RandomizeClient(iGroupList[j], eInfo.nType);
		}
	}
}

int Group_GetTriggerList(RandomizedInfo eInfo, int[] iTriggerList)
{
	char sGroupName[MAX_TARGET_LENGTH];
	bool bIsML;
	return ProcessTargetString(eInfo.sTrigger, 0, iTriggerList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sGroupName, sizeof(sGroupName), bIsML);
}

int Group_GetGroupList(RandomizedInfo eInfo, int[] iGroupList, int iTrigger)
{
	char sGroupName[MAX_TARGET_LENGTH];
	bool bIsML;
	return ProcessTargetString(eInfo.sGroup, iTrigger, iGroupList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sGroupName, sizeof(sGroupName), bIsML);
}

int Group_GetAllGroupList(RandomizedInfo eInfo, int[] iBufferList)
{
	int iBufferCount;
	
	int[] iTriggerList = new int[MaxClients];
	int iTriggerCount = Group_GetTriggerList(eInfo, iTriggerList);
	for (int i = 0; i < iTriggerCount; i++)
	{
		int[] iGroupList = new int[MaxClients];
		int iGroupCount = Group_GetGroupList(eInfo, iGroupList, iTriggerList[i]);
		for (int j = 0; j < iGroupCount; j++)
		{
			if (!Group_IsClientInList(iGroupList[j], iBufferList, iBufferCount))
			{
				iBufferList[iBufferCount] = iGroupList[j];
				iBufferCount++;
			}
		}
	}
	
	return iBufferCount;
}

bool Group_IsClientInTrigger(RandomizedInfo eInfo, int iClient)
{
	int[] iTriggerList = new int[MaxClients];
	int iTriggerCount = Group_GetTriggerList(eInfo, iTriggerList);
	return Group_IsClientInList(iClient, iTriggerList, iTriggerCount);
}

bool Group_IsClientInAllGroup(RandomizedInfo eInfo, int iClient)
{
	int[] iGroupList = new int[MaxClients];
	int iGroupCount = Group_GetAllGroupList(eInfo, iGroupList);
	return Group_IsClientInList(iClient, iGroupList, iGroupCount);
}

bool Group_IsClientInList(int iClient, const int[] iList, int iCount)
{
	for (int i = 0; i < iCount; i++)
		if (iList[i] == iClient)
			return true;
	
	return false;
}