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
	
	void Enable(bool bUpdateMemAccess = true)
	{
		for (int i = 0; i < this.iPatchCount; i++)
			StoreToAddress(this.pAddress + view_as<Address>(i), this.iValueReplacement[i], NumberType_Int8, bUpdateMemAccess);
	}
	
	void Disable(bool bUpdateMemAccess = true)
	{
		for (int i = 0; i < this.iPatchCount; i++)
			StoreToAddress(this.pAddress + view_as<Address>(i), this.iValueOriginal[i], NumberType_Int8, bUpdateMemAccess);
	}
}

static ArrayList g_aPatches;	//Arrays of Patch
static Patch g_pIsPlayerClass;
int g_iAllowPlayerClass;

void Patch_Init(GameData hGameData)
{
	g_aPatches = new ArrayList(sizeof(Patch));
	int iCount = 0;
	
	do
	{
		iCount++;
		char sNumber[16];
		Format(sNumber, sizeof(sNumber), "%02d", iCount);
		
		Patch patch;
		if (!patch.Load(hGameData, sNumber, true))
			break;
		
		g_aPatches.PushArray(patch);
	}
	while (iCount);	//Infinite loop until break
	
	g_pIsPlayerClass.Load(hGameData, "IsPlayerClass");
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

void Patch_EnableIsPlayerClass()
{
	// Don't update mem access to reduce lag
	if (g_iAllowPlayerClass == 0)
		g_pIsPlayerClass.Enable(false);
	
	g_iAllowPlayerClass++;
}

void Patch_DisableIsPlayerClass()
{
	g_iAllowPlayerClass--;
	
	if (g_iAllowPlayerClass == 0)
		g_pIsPlayerClass.Disable(false);
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