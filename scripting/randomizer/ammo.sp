static StringMap g_mWeaponCurrentAmmo;
static int g_iAmmoForceWeapon = INVALID_ENT_REFERENCE;

void Ammo_Init()
{
	g_mWeaponCurrentAmmo = new StringMap();
}

int Ammo_GetWeaponAmmo(int iWeapon)
{
	char sRef[16];
	IntToString(EntIndexToEntRef(iWeapon), sRef, sizeof(sRef));
	
	int iValue;
	g_mWeaponCurrentAmmo.GetValue(sRef, iValue);
	return iValue;
}

void Ammo_SetWeaponAmmo(int iWeapon, int iAmmo)
{
	char sRef[16];
	IntToString(EntIndexToEntRef(iWeapon), sRef, sizeof(sRef));
	
	g_mWeaponCurrentAmmo.SetValue(sRef, iAmmo);
}

void Ammo_SaveActiveWeapon(int iClient)
{
	if (g_iAmmoForceWeapon != INVALID_ENT_REFERENCE)
		ThrowError("Ammo_SaveActiveWeapon called unexpected when g_iAmmoForceWeapon '%d' is active", g_iAmmoForceWeapon);
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon == INVALID_ENT_REFERENCE || !HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType"))
		return;
	
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType == -1)
		return;
	
	int iAmmo = GetEntProp(iClient, Prop_Send, "m_iAmmo", _, iAmmoType);
	
	char sRef[16];
	IntToString(EntIndexToEntRef(iWeapon), sRef, sizeof(sRef));
	g_mWeaponCurrentAmmo.SetValue(sRef, iAmmo);
}

void Ammo_UpdateActiveWeapon(int iClient)
{
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon == INVALID_ENT_REFERENCE || !HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType"))
		return;
	
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType == -1)
		return;
	
	char sRef[16];
	IntToString(EntIndexToEntRef(iWeapon), sRef, sizeof(sRef));
	
	int iValue;
	if (!g_mWeaponCurrentAmmo.GetValue(sRef, iValue))
		return;
	
	SetEntProp(iClient, Prop_Send, "m_iAmmo", iValue, _, iAmmoType);
}

void Ammo_RemoveWeapon(int iWeapon)
{
	char sRef[16];
	IntToString(EntIndexToEntRef(iWeapon), sRef, sizeof(sRef));
	g_mWeaponCurrentAmmo.Remove(sRef);
}

void Ammo_SetForceWeapon(int iWeapon)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	Ammo_SaveActiveWeapon(iClient);
	
	int iAmmo = Ammo_GetWeaponAmmo(iWeapon);
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	SetEntProp(iClient, Prop_Send, "m_iAmmo", iAmmo, _, iAmmoType);
	
	g_iAmmoForceWeapon = iWeapon;
}

void Ammo_ResetForceWeapon()
{
	if (g_iAmmoForceWeapon != INVALID_ENT_REFERENCE)
		Ammo_UpdateActiveWeapon(GetEntPropEnt(g_iAmmoForceWeapon, Prop_Send, "m_hOwnerEntity"));
	
	g_iAmmoForceWeapon = INVALID_ENT_REFERENCE;
}

int Ammo_GetForceWeapon()
{
	return g_iAmmoForceWeapon;
}