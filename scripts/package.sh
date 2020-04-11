# Go to build dir
cd build

# Create package dir
mkdir -p package/addons/sourcemod/plugins
mkdir -p package/addons/sourcemod/configs
mkdir -p package/addons/sourcemod/gamedata

# Copy all required stuffs to package
cp -r addons/sourcemod/plugins/randomizer.smx package/addons/sourcemod/plugins
cp -r ../configs/randomizer package/addons/sourcemod/configs
cp -r ../gamedata/randomizer.txt package/addons/sourcemod/gamedata
cp -r ../translations package/addons/sourcemod