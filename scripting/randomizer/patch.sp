#define PATCH_MAX	16

enum struct Patch
{
	Address pAddress;
	int iPatchCount;
	int iValueOriginal[PATCH_MAX];
	int iValueReplacement[PATCH_MAX];
	bool bEnable;
	
	void Load(GameData hGameData, const char[] sPatchName)
	{
		this.pAddress = hGameData.GetAddress(sPatchName);
		if (!this.pAddress)
		{
			LogError("Failed to find address for key %s", sPatchName);
			return;
		}
		
		char sKeyValue[PATCH_MAX * 4];
		if (!hGameData.GetKeyValue(sPatchName, sKeyValue, sizeof(sKeyValue)))
		{
			LogError("Failed to find key value for %s", sPatchName);
			return;
		}
		
		char sBytes[PATCH_MAX][4];
		this.iPatchCount = ExplodeString(sKeyValue, "\\x", sBytes, sizeof(sBytes), sizeof(sBytes[])) - 1;
		for (int i = 0; i < this.iPatchCount; i++)
		{
			this.iValueOriginal[i] = LoadFromAddress(this.pAddress + view_as<Address>(i), NumberType_Int8);
			this.iValueReplacement[i] = StringToInt(sBytes[i+1], 16);
		}
	}
	
	void Enable()
	{
		if (this.bEnable)
			return;
		
		for (int i = 0; i < this.iPatchCount; i++)
		{
			PrintToServer("%X: %02X -> %02X", this.pAddress + view_as<Address>(i), this.iValueOriginal[i], this.iValueReplacement[i]);
			StoreToAddress(this.pAddress + view_as<Address>(i), this.iValueReplacement[i], NumberType_Int8);
		}
		
		this.bEnable = true;
	}
	
	void Disable()
	{
		if (!this.bEnable)
			return;
		
		for (int i = 0; i < this.iPatchCount; i++)
		{
			PrintToServer("%X: %02X -> %02X", this.pAddress + view_as<Address>(i), this.iValueReplacement[i], this.iValueOriginal[i]);
			StoreToAddress(this.pAddress + view_as<Address>(i), this.iValueOriginal[i], NumberType_Int8);
		}
		
		this.bEnable = false;
	}
}

static Patch g_patchSpeedDemomanClassCheck;
static Patch g_patchSpeedMedic1ClassCheck;
static Patch g_patchSpeedMedic2ClassCheck;
static Patch g_patchSpeedHeavyClassCheck;
static Patch g_patchSpeedSteakCondFailed;
static Patch g_patchSpeedSteakCondPassed;

void Patch_Init(GameData hGameData)
{
	g_patchSpeedDemomanClassCheck.Load(hGameData, "Patch_SpeedDemomanClassCheck");
	g_patchSpeedMedic1ClassCheck.Load(hGameData, "Patch_SpeedMedic1ClassCheck");
	g_patchSpeedMedic2ClassCheck.Load(hGameData, "Patch_SpeedMedic2ClassCheck");
	g_patchSpeedHeavyClassCheck.Load(hGameData, "Patch_SpeedHeavyClassCheck");
	g_patchSpeedSteakCondFailed.Load(hGameData, "Patch_SpeedSteakCondFailed");
	g_patchSpeedSteakCondPassed.Load(hGameData, "Patch_SpeedSteakCondPassed");
	
	g_patchSpeedDemomanClassCheck.Enable();
	g_patchSpeedMedic1ClassCheck.Enable();
	g_patchSpeedMedic2ClassCheck.Enable();
	g_patchSpeedHeavyClassCheck.Enable();
	g_patchSpeedSteakCondFailed.Enable();
	g_patchSpeedSteakCondPassed.Enable();
}

void Patch_ResetAll()
{
	g_patchSpeedDemomanClassCheck.Disable();
	g_patchSpeedMedic1ClassCheck.Disable();
	g_patchSpeedMedic2ClassCheck.Disable();
	g_patchSpeedHeavyClassCheck.Disable();
	g_patchSpeedSteakCondFailed.Disable();
	g_patchSpeedSteakCondPassed.Disable();
}