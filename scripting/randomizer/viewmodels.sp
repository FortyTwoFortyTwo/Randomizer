char g_sViewModelsArms[][] = {
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

int ViewModels_GetClientArms(int iClient)
{
	int iArms = INVALID_ENT_REFERENCE;
	while ((iArms=FindEntityByClassname(iArms, "tf_wearable_vm")) != INVALID_ENT_REFERENCE)
	{
		if (iClient == GetEntPropEnt(iArms, Prop_Send, "m_hOwnerEntity") && GetEntPropEnt(iArms, Prop_Send, "m_hWeaponAssociatedWith") == INVALID_ENT_REFERENCE)
			return iArms;
	}
	
	return INVALID_ENT_REFERENCE;
}

void ViewModels_UpdateArmsModel(int iClient)
{
	bool bSameClass;
	
	int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if (iViewModel != INVALID_ENT_REFERENCE)
	{
		TFClassType nClass;
		
		int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
		if (iActiveWeapon != INVALID_ENT_REFERENCE)
			nClass = TF2_GetDefaultClassFromItem(iActiveWeapon);
		else
			nClass = TF2_GetPlayerClass(iClient);
		
		bSameClass = nClass == TF2_GetPlayerClass(iClient);
		if (bSameClass)
			RemoveEntityEffect(iViewModel, EF_NODRAW);
		else
			AddEntityEffect(iViewModel, EF_NODRAW);
		
		if (GetEntProp(iViewModel, Prop_Send, "m_nModelIndex") != GetModelIndex(g_sViewModelsArms[nClass]))
			SetEntityModel(iViewModel, g_sViewModelsArms[nClass]);
		
	}
	
	int iArms = ViewModels_GetClientArms(iClient);
	int iArmsModelIndex = GetModelIndex(g_sViewModelsArms[TF2_GetPlayerClass(iClient)]);
	if (iArms != INVALID_ENT_REFERENCE && GetEntProp(iArms, Prop_Send, "m_nModelIndex") != iArmsModelIndex)
	{
		RemoveEntity(iArms);
		iArms = INVALID_ENT_REFERENCE;
	}
	
	if (iArms == INVALID_ENT_REFERENCE)
		iArms = ViewModels_CreateWearable(iClient, "tf_wearable_vm", INVALID_ENT_REFERENCE, iArmsModelIndex);
	
	if (bSameClass)
		AddEntityEffect(iArms, EF_NODRAW);
	else
		RemoveEntityEffect(iArms, EF_NODRAW);
}

void ViewModels_UpdateArms(int iClient)
{
	ViewModels_UpdateArmsModel(iClient);
	
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	int iMaxWeapons = GetMaxWeapons();
	for (int i = 0; i < iMaxWeapons; i++)
	{
		int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		if (iWeapon == INVALID_ENT_REFERENCE)
			continue;
		
		bool bSameClass = TF2_GetDefaultClassFromItem(iWeapon) == nClass;
		
		SetEntProp(iWeapon, Prop_Send, "m_nCustomViewmodelModelIndex", GetEntProp(iWeapon, Prop_Send, "m_nModelIndex"));
		
		int iWearableViewModel = GetEntPropEnt(iWeapon, Prop_Send, "m_hExtraWearableViewModel");
		if (iWearableViewModel == INVALID_ENT_REFERENCE && !bSameClass)
		{
			iWearableViewModel = ViewModels_CreateWearable(iClient, "tf_wearable_vm", iWeapon, GetEntProp(iWeapon, Prop_Send, "m_iWorldModelIndex"));
		}
		else if (iWearableViewModel != INVALID_ENT_REFERENCE && bSameClass)
		{
			RemoveEntity(iWearableViewModel);
			iWearableViewModel = INVALID_ENT_REFERENCE;
		}
		
		if (iWearableViewModel != INVALID_ENT_REFERENCE)
		{
			if (iWeapon == iActiveWeapon)
				RemoveEntityEffect(iWearableViewModel, EF_NODRAW);
			else
				AddEntityEffect(iWearableViewModel, EF_NODRAW);
		}
	}
}

int ViewModels_CreateWearable(int iClient, const char[] sClassname, int iWeapon, int iModelIndex)
{
	int iWearable = CreateEntityByName(sClassname);
	
	float vecOrigin[3], vecAngles[3];
	GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", vecOrigin);
	GetEntPropVector(iClient, Prop_Send, "m_angRotation", vecAngles);
	TeleportEntity(iWearable, vecOrigin, vecAngles, NULL_VECTOR);
	
	SetEntProp(iWearable, Prop_Send, "m_bValidatedAttachedEntity", true);
	SetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity", iClient);
	SetEntProp(iWearable, Prop_Send, "m_iTeamNum", GetClientTeam(iClient));
	SetEntProp(iWearable, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID);
	SetEntProp(iWearable, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_WEAPON);
	SetEntProp(iWearable, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL);
	
	SetEntProp(iWearable, Prop_Send, "m_nModelIndex", iModelIndex);
	
	if (iWeapon != INVALID_ENT_REFERENCE)
	{
		SetEntPropEnt(iWearable, Prop_Send, "m_hWeaponAssociatedWith", iWeapon);
		SetEntPropEnt(iWeapon, Prop_Send, "m_hExtraWearableViewModel", iWearable);
	}
	
	DispatchSpawn(iWearable);
	
	if (StrEqual(sClassname, "tf_wearable_vm"))
	{
		SetVariantString("!activator");
		AcceptEntityInput(iWearable, "SetParent", GetEntPropEnt(iClient, Prop_Send, "m_hViewModel"));
	}
	else if (StrEqual(sClassname, "tf_wearable"))
	{
		SetVariantString("!activator");
		AcceptEntityInput(iWearable, "SetParent", iClient);
		AcceptEntityInput(iWeapon, "Clearparent");	//Disables the baseitem from appearing in thirdperson. However, weapon appears while taunting.
	}
	
	return iWearable;
}

void ViewModels_RemoveAll()
{
	int iViewmodel = INVALID_ENT_REFERENCE;
	while ((iViewmodel=FindEntityByClassname(iViewmodel, "tf_wearable_vm")) != INVALID_ENT_REFERENCE)
		RemoveEntity(iViewmodel);
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient))
			continue;
		
		int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
		if (iViewModel == INVALID_ENT_REFERENCE)
			continue;
		
		RemoveEntityEffect(iViewModel, EF_NODRAW);
		SetEntityModel(iViewModel, g_sViewModelsArms[TF2_GetPlayerClass(iClient)]);
	}
}

void ViewModels_RemoveFromWeapon(int iWeapon)
{
	int iViewmodel = INVALID_ENT_REFERENCE;
	while ((iViewmodel=FindEntityByClassname(iViewmodel, "tf_wearable_vm")) != INVALID_ENT_REFERENCE)
		if (GetEntPropEnt(iViewmodel, Prop_Send, "m_hWeaponAssociatedWith") == iWeapon)
			RemoveEntity(iViewmodel);
}