/*

This section is used to fix bugs, mostly class checks by changing instructions in TF2 memory.
It loops through each lists in gamedata by numbers, starting from 01. Ends loop when number at "PatchSig" could not be found.
"PatchSig" is used to find matching signature in TF2 memory.
"PatchReplace" is memory used to set in TF2 memory. Applies in same position as address from "PatchSig"

makememsearch.idc, a modification of makesig.idc, is recommended to use to make signatures. Source code can be found here:
https://github.com/FortyTwoFortyTwo/Randomizer/blob/master/scripts/makememsearch.idc

*/

#define PATCH_MAX		64
#define PATCH_SPLIT		"\\x"

#define PATCH_SEARCH	"PatchSig"
#define PATCH_REPLACE	"PatchReplace"

enum struct Patch
{
	Address pAddress;
	int iPatchCount;
	int iValueOriginal[PATCH_MAX];
	int iValueReplacement[PATCH_MAX];
	bool bFirstPatch;
	
	bool Load(GameData hGameData, const char[] sName, bool bSkipWarning = false)
	{
		//PatchReplace should be checked for more numbers instead of PatchSig,
		// would help report error if PatchSig broke from TF2 update
		
		char sBuffer[32];
		char sReplaceValue[PATCH_MAX * 4];
		Format(sBuffer, sizeof(sBuffer), PATCH_REPLACE ... "_%s", sName);
		if (!hGameData.GetKeyValue(sBuffer, sReplaceValue, sizeof(sReplaceValue)))
		{
			if (!bSkipWarning)
				LogError("Could not find Gamedata key value '%s'", sBuffer);
			
			return false;	//No more numbers to search
		}
		
		this.iPatchCount = Patch_StringToMemory(sReplaceValue, this.iValueReplacement);
		if (this.iPatchCount <= 0)
		{
			LogError("Gamedata key '%s' has invalid memory value '%s'", sBuffer, sReplaceValue);
			return true;
		}
		
		Format(sBuffer, sizeof(sBuffer), PATCH_SEARCH ... "_%s", sName);
		this.pAddress = hGameData.GetAddress(sBuffer);
		if (!this.pAddress)
		{
			LogError("Could not find Gamedata address or invalid value '%s'", sBuffer);
			this.iPatchCount = 0;
			return true;
		}
		
		for (int i = 0; i < this.iPatchCount; i++)
			this.iValueOriginal[i] = LoadFromAddress(this.pAddress + view_as<Address>(i), NumberType_Int8);
		
		return true;
	}
	
	bool Enable()
	{
		for (int i = 0; i < this.iPatchCount; i++)
			StoreToAddress(this.pAddress + view_as<Address>(i), this.iValueReplacement[i], NumberType_Int8, !this.bFirstPatch);
		
		// Updating mem access only need to be done once to each patches, after first patch we don't need to update mem access again
		if (!this.bFirstPatch)
		{
			this.bFirstPatch = true;
			return true;
		}
		
		return false;
	}
	
	void Disable()
	{
		// Assuming that Enable() is called before Disable(), not needing to update mem access
		
		for (int i = 0; i < this.iPatchCount; i++)
			StoreToAddress(this.pAddress + view_as<Address>(i), this.iValueOriginal[i], NumberType_Int8, false);
	}
}

enum struct PatchSpeed
{
	Address pAddress;
	int iValueOriginal;
	int bFirstPatch;
}

static ArrayList g_aSpeedPatches;	//Arrays of PatchSpeed
static Patch g_pIsPlayerClass;
int g_iAllowPlayerClass;

void Patch_Init(GameData hGameData)
{
	int iWildcardMemory[PATCH_MAX];
	int iWhitelistCount = Patch_GetGamedataMemory(hGameData, "PatchWildcard_Speed", iWildcardMemory);
	
	int iMaxBits = Patch_GetGamedataValueInt(hGameData, "PatchBits_Speed");
	
	Address pAddress = hGameData.GetMemSig("CTFPlayer::TeamFortress_CalculateMaxSpeed");
	
	g_aSpeedPatches = new ArrayList(sizeof(PatchSpeed));
	int iCount = 0;
	
	do
	{
		iCount++;
		char sKey[64];
		Format(sKey, sizeof(sKey), "PatchSearch_Speed%02d", iCount);
		
		int iMemory[PATCH_MAX];
		int iMemoryCount = Patch_GetGamedataMemory(hGameData, sKey, iMemory);
		if (iMemoryCount == 0)
			break;
		
		int iPosition;
		PatchSpeed patch;
		for (Address pOffset; pOffset < view_as<Address>(iMaxBits); pOffset++)
		{
			if (Patch_CheckValue(pAddress + pOffset, iMemory[iPosition], patch, iWildcardMemory, iWhitelistCount))
			{
				iPosition++;
			}
			else if (iPosition > 0)
			{
				iPosition = 0;
				if (Patch_CheckValue(pAddress + pOffset, iMemory[iPosition], patch, iWildcardMemory, iWhitelistCount))
					iPosition++;
			}
			
			if (iPosition >= iMemoryCount)
			{
				g_aSpeedPatches.PushArray(patch);
				iPosition = 0;
			}
		}
	}
	while (iCount);	//Infinite loop until break
	
	int iLength = g_aSpeedPatches.Length;
	int iMaxCount = Patch_GetGamedataValueInt(hGameData, "PatchCount_Speed");
	if (iLength != iMaxCount)
	{
		LogError("Found unexpected amount of speed patches to apply (expected %d, found %d), listing offsets found:", iMaxCount, iLength);
		for (int i = 0; i < iLength; i++)
		{
			PatchSpeed patch;
			g_aSpeedPatches.GetArray(i, patch);
			LogError("#%02d: %d", i + 1, patch.pAddress - pAddress);
		}
		
		g_aSpeedPatches.Clear();
	}
	
	g_pIsPlayerClass.Load(hGameData, "IsPlayerClass");
}

bool Patch_CheckValue(Address pAddress, int iExpected, PatchSpeed patch, int iWildcardMemory[PATCH_MAX], int iWhitelistCount)
{
	int iValue = LoadFromAddress(pAddress, NumberType_Int8);
	
	if (iValue == iExpected)
	{
		return true;
	}
	else if (iExpected == 0x2A)
	{
		patch.pAddress = pAddress;
		patch.iValueOriginal = iValue;
		
		for (int i = 0; i < iWhitelistCount; i++)
			if (iValue == iWildcardMemory[i])
				return true;
	}
	
	return false;
}

void Patch_SetSpeed(TFClassType nClass)
{
	int iLength = g_aSpeedPatches.Length;
	for (int i = 0; i < iLength; i++)
	{
		PatchSpeed patch;
		g_aSpeedPatches.GetArray(i, patch);
		StoreToAddress(patch.pAddress, nClass, NumberType_Int8, !patch.bFirstPatch);
		if (!patch.bFirstPatch)
		{
			patch.bFirstPatch = true;
			g_aSpeedPatches.SetArray(i, patch);
		}
	}
}

void Patch_RevertSpeed()
{
	int iLength = g_aSpeedPatches.Length;
	for (int i = 0; i < iLength; i++)
	{
		PatchSpeed patch;
		g_aSpeedPatches.GetArray(i, patch);
		StoreToAddress(patch.pAddress, patch.iValueOriginal, NumberType_Int8);
	}
}

void Patch_EnableIsPlayerClass()
{
	if (g_iAllowPlayerClass == 0)
		g_pIsPlayerClass.Enable();
	
	g_iAllowPlayerClass++;
}

void Patch_DisableIsPlayerClass()
{
	g_iAllowPlayerClass--;
	
	if (g_iAllowPlayerClass == 0)
		g_pIsPlayerClass.Disable();
}

int Patch_StringToMemory(const char[] sValue, int iMemory[PATCH_MAX])
{
	char sBytes[PATCH_MAX][4];
	int iCount = ExplodeString(sValue, PATCH_SPLIT, sBytes, sizeof(sBytes), sizeof(sBytes[])) - 1;
	for (int i = 0; i < iCount; i++)
	{
		if (!StringToIntEx(sBytes[i+1], iMemory[i], 16))
			return 0;
	}
	
	return iCount;
}

int Patch_GetGamedataMemory(GameData hGameData, const char[] sKey, int iMemory[PATCH_MAX])
{
	char sBuffer[PATCH_MAX * 4];
	hGameData.GetKeyValue(sKey, sBuffer, sizeof(sBuffer));
	return Patch_StringToMemory(sBuffer, iMemory);
}

int Patch_GetGamedataValueInt(GameData hGameData, const char[] sKey)
{
	char sValue[12];
	hGameData.GetKeyValue(sKey, sValue, sizeof(sValue));
	return StringToInt(sValue);
}
