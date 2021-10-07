/*

This section is used to fix bugs, mostly class checks by changing instructions in TF2 memory.
It loops through each lists in gamedata by numbers, starting from 01. Ends loop when number at "PatchStart" could not be found.
"PatchStart" is used to determe where to start searching. Patch's function signature is generally used to start.
"PatchSearch" is used to find matching memory in TF2 memory. Must start at same place to apply patches for "PatchReplace".
"PatchReplace" is memory used to set in TF2 memory.

"PatchSearch" Should generaly only have few instructions, and value/destination as wildcard "x2A" as those commonly get changed in TF2 updates

*/

#define PATCH_MAX		64
#define PATCH_WILDCARD	0x2A	//Same as sourcemod's wildcard, ironically same as my name "42"
#define PATCH_SPLIT		"\\x"

#define PATCH_START		"PatchStart"
#define PATCH_SEARCH	"PatchSearch"
#define PATCH_REPLACE	"PatchReplace"

enum struct Patch
{
	Address pAddress;
	int iPatchCount;
	int iValueOriginal[PATCH_MAX];
	int iValueReplacement[PATCH_MAX];
	
	bool Load(GameData hGameData, int iNumber)
	{
		char sBuffer[32];
		Format(sBuffer, sizeof(sBuffer), PATCH_START ... "_%02d", iNumber);
		
		Address pStart = hGameData.GetAddress(sBuffer);
		if (!pStart)	//No more numbers to search
			return false;
		
		char sSearchValue[PATCH_MAX * 4];
		Format(sBuffer, sizeof(sBuffer), PATCH_SEARCH ... "_%02d", iNumber);
		if (!hGameData.GetKeyValue(sBuffer, sSearchValue, sizeof(sSearchValue)))
		{
			LogError("Failed to find Gamedata key for '%s'", sBuffer);
			return true;
		}
		
		int iMemorySearch[PATCH_MAX];
		int iSearchCount = Patch_StringToMemory(sSearchValue, iMemorySearch);
		if (iSearchCount <= 0)
		{
			LogError("Gamedata key '%s' has invalid memory value '%s'", sBuffer, sSearchValue);
			return true;
		}
		
		char sReplaceValue[PATCH_MAX * 4];
		Format(sBuffer, sizeof(sBuffer), PATCH_REPLACE ... "_%02d", iNumber);
		if (!hGameData.GetKeyValue(sBuffer, sReplaceValue, sizeof(sReplaceValue)))
		{
			LogError("Failed to find Gamedata key for '%s'", sBuffer);
			return true;
		}
		
		this.iPatchCount = Patch_StringToMemory(sReplaceValue, this.iValueReplacement);
		if (this.iPatchCount <= 0)
		{
			LogError("Gamedata key '%s' has invalid memory value '%s'", sBuffer, sReplaceValue);
			return true;
		}
		
		//Start searching
		int iOffset, iValidCount = 0;
		for (iOffset = 0; iOffset <= 0xFFFF; iOffset++)	//Surely there isn't any single function with more than 0xFFFF memory used, right?
		{
			if (iMemorySearch[iValidCount] == PATCH_WILDCARD)	//Wildcard, skip as valid
				iValidCount++;
			else if (iMemorySearch[iValidCount] == LoadFromAddress(pStart + view_as<Address>(iOffset), NumberType_Int8))
				iValidCount++;
			else	//Broke valid combo search, reset
				iValidCount = 0;
			
			if (iValidCount == iSearchCount)	//Search done
				break;
		}
		
		if (iValidCount != iSearchCount)
		{
			LogError("Could not find matching search memory for Gamedata key '" ... PATCH_SEARCH ... "_%02d'", iNumber);
			this.iPatchCount = 0;
			return true;
		}
		
		iOffset -= iSearchCount - 1;
		this.pAddress = pStart + view_as<Address>(iOffset);
		
		for (int i = 0; i < this.iPatchCount; i++)
			this.iValueOriginal[i] = LoadFromAddress(this.pAddress + view_as<Address>(i), NumberType_Int8);
		
		return true;
	}
	
	void Enable()
	{
		for (int i = 0; i < this.iPatchCount; i++)
			StoreToAddress(this.pAddress + view_as<Address>(i), this.iValueReplacement[i], NumberType_Int8);
	}
	
	void Disable()
	{
		for (int i = 0; i < this.iPatchCount; i++)
			StoreToAddress(this.pAddress + view_as<Address>(i), this.iValueOriginal[i], NumberType_Int8);
	}
}

static ArrayList g_aPatches;	//Arrays of Patch

void Patch_Init(GameData hGameData)
{
	g_aPatches = new ArrayList(sizeof(Patch));
	int iCount = 0;
	
	do
	{
		iCount++;
		
		Patch patch;
		if (!patch.Load(hGameData, iCount))
			break;
		
		g_aPatches.PushArray(patch);
	}
	while (iCount);	//Infinite loop until break
}

void Patch_Enable()
{
	int iLength = g_aPatches.Length;
	for (int i = 0; i < iLength; i++)
	{
		Patch patch;
		g_aPatches.GetArray(i, patch);
		patch.Enable();
	}
}

void Patch_Disable()
{
	int iLength = g_aPatches.Length;
	for (int i = 0; i < iLength; i++)
	{
		Patch patch;
		g_aPatches.GetArray(i, patch);
		patch.Disable();
	}
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