#define FILEPATH_CONFIG_VIEWMODELS "configs/randomizer/viewmodels.cfg"

methodmap ViewModelsInvisible < StringMap
{
	public ViewModelsInvisible()
	{
		return view_as<ViewModelsInvisible>(new StringMap());
	}
	
	public void Set(const char[] sClassname, const char[] sTF2Class)
	{
		TFClassType nClass = TF2_GetClass(sTF2Class);
		
		bool bInvisible[10];
		this.GetArray(sClassname, bInvisible, sizeof(bInvisible));
		bInvisible[nClass] = true;
		this.SetArray(sClassname, bInvisible, sizeof(bInvisible));
	}
	
	public bool Exists(int iWeapon, TFClassType nClass)
	{
		char sClassname[CONFIG_MAXCHAR];
		GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
		
		bool bInvisible[10];
		this.GetArray(sClassname, bInvisible, sizeof(bInvisible));
		return bInvisible[nClass];
	}
}

static ViewModelsInvisible g_mViewModelsInvisible;

void ViewModels_Init()
{
	g_mViewModelsInvisible = new ViewModelsInvisible();
}

void ViewModels_Refresh()
{
	KeyValues kv = LoadConfig(FILEPATH_CONFIG_VIEWMODELS, "ViewModels");
	if (!kv)
		return;
	
	g_mViewModelsInvisible.Clear();
	
	if (kv.JumpToKey("Invisible"))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				char sClassname[CONFIG_MAXCHAR], sTF2Class[CONFIG_MAXCHAR];
				kv.GetSectionName(sClassname, sizeof(sClassname));
				kv.GetString(NULL_STRING, sTF2Class, sizeof(sTF2Class));
				
				g_mViewModelsInvisible.Set(sClassname, sTF2Class);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
	}
}

bool ViewModels_ShouldBeInvisible(int iWeapon, TFClassType nClass)
{
	return g_mViewModelsInvisible.Exists(iWeapon, nClass);
}

bool ViewModels_ToggleInvisible(int iWeapon)
{
	if (GetEntityRenderMode(iWeapon) == RENDER_NORMAL)
	{
		ViewModels_EnableInvisible(iWeapon);
		return true;
	}
	else
	{
		ViewModels_DisableInvisible(iWeapon);
		return false;
	}
}

void ViewModels_EnableInvisible(int iWeapon)
{
	SetEntityRenderMode(iWeapon, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iWeapon, 255, 255, 255, 75);
}

void ViewModels_DisableInvisible(int iWeapon)
{
	SetEntityRenderMode(iWeapon, RENDER_NORMAL); 
	SetEntityRenderColor(iWeapon, 255, 255, 255, 255);
}