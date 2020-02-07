char g_sViewModelClass[][] = {
	"",
	"models/weapons/c_models/c_scout_arms.mdl",
	"models/weapons/c_models/c_sniper_arms.mdl",
	"models/weapons/c_models/c_soldier_arms.mdl",
	"models/weapons/c_models/c_demo_arms.mdl",
	"models/weapons/c_models/c_medic_arms.mdl",
	"models/weapons/c_models/c_heavy_arms.mdl",
	"models/weapons/c_models/c_pyro_arms.mdl",
	"models/weapons/c_models/c_spy_arms.mdl",
	"models/weapons/c_models/c_engineer_arms.mdl",
};

int g_iViewModelIndex[sizeof(g_sViewModelClass)];

int g_iViewModelHand[TF_MAXPLAYERS+1][WeaponSlot_BuilderEngie+1];

void ViewModel_Precache()
{
	for (int i = 1; i < sizeof(g_sViewModelClass); i++)
		g_iViewModelIndex[i] = PrecacheModel(g_sViewModelClass[i]);
}

stock int ViewModel_GetIndex(TFClassType nClass)
{
	return g_iViewModelIndex[nClass];
}

stock bool ViewModel_GetFromItem(int iWeapon, char[] sModel, int iLength, int &iModelIndex, TFClassType &nClass)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	int iSlot = TF2_GetSlotFromItem(iClient, iWeapon);
	int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		if (TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass)) == iSlot)
		{
			iModelIndex = g_iViewModelIndex[iClass];
			nClass = view_as<TFClassType>(iClass);
			Format(sModel, iLength, g_sViewModelClass[iClass]);
			return true;
		}
	}
	
	return false;
}

stock int ViewModel_CreateWeapon(int iClient, int iSlot, int iWeapon)
{
	TFClassType nDefaultClass = TF2_GetDefaultClassFromItem(iClient, iWeapon);
	
	g_iViewModelHand[iClient][iSlot] = ViewModel_Create(iClient, g_iViewModelIndex[nDefaultClass]);
	int iViewModelWeapon = ViewModel_Create(iClient, GetEntProp(iWeapon, Prop_Send, "m_nModelIndex"));
	
	SetEntPropEnt(g_iViewModelHand[iClient][iSlot], Prop_Send, "m_hWeaponAssociatedWith", iWeapon);
	SetEntPropEnt(iViewModelWeapon, Prop_Send, "m_hWeaponAssociatedWith", iWeapon);
	
	SetEntPropEnt(iWeapon, Prop_Send, "m_hExtraWearableViewModel", g_iViewModelHand[iClient][iSlot]);
	/*
	SetVariantString("!activator");
	AcceptEntityInput(iViewModel, "SetParent", iOldViewModel);
	*/
	return iViewModel;
}

stock int ViewModel_Create(int iClient, int iModelIndex)
{
	int iViewModel = CreateEntityByName("tf_wearable_vm");
	SetEntProp(iViewModel, Prop_Send, "m_nModelIndex", iModelIndex);
	SetEntProp(iViewModel, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL);
	SetEntProp(iViewModel, Prop_Send, "m_iTeamNum", GetClientTeam(iClient));
	SetEntProp(iViewModel, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(iViewModel, Prop_Send, "m_CollisionGroup", 11);
	SetEntPropEnt(iViewModel, Prop_Send, "m_hOwnerEntity", iClient);
	
	SetEntProp(iViewModel, Prop_Send, "m_bValidatedAttachedEntity", true);
	
	DispatchSpawn(iViewModel);
	SetVariantString("!activator");
	ActivateEntity(iViewModel);
	
	SDK_EquipWearable(iClient, iViewModel);
	
	return iViewModel;
}

public void ViewModel_Think(int iClient)
{
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon <= MaxClients)
		return;
	
	int iOldViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if (iOldViewModel > MaxClients)
		AddEffectFlags(iOldViewModel, EF_NODRAW);
	
	int iSlotActive = TF2_GetSlotFromItem(iClient, iWeapon);
	for (int iSlot = 0; iSlot <= WeaponSlot_Melee; iSlot++)
	{
		if (g_iViewModelHand[iClient][iSlot] > MaxClients)
		{
			if (iSlot == iSlotActive)
				RemoveEffectFlags(g_iViewModelHand[iClient][iSlot], EF_NODRAW);
			else
				AddEffectFlags(g_iViewModelHand[iClient][iSlot], EF_NODRAW);
		}
	}
}

public void ViewModel_WeaponSwitch(int iClient, int iWeapon)
{
	int iOldViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if (iOldViewModel > MaxClients)
		AddEffectFlags(iOldViewModel, EF_NODRAW);
	
	int iSlotActive = TF2_GetSlotFromItem(iClient, iWeapon);
	for (int iSlot = 0; iSlot <= WeaponSlot_Melee; iSlot++)
	{
		if (g_iViewModelHand[iClient][iSlot] > MaxClients)
		{
			if (iSlot == iSlotActive)
				RemoveEffectFlags(g_iViewModelHand[iClient][iSlot], EF_NODRAW);
			else
				AddEffectFlags(g_iViewModelHand[iClient][iSlot], EF_NODRAW);
		}
	}
}