# Create build folder
mkdir build
cd build

# Install SourceMod
wget --input-file=http://sourcemod.net/smdrop/$SM_VERSION/sourcemod-latest-linux
tar -xzf $(cat sourcemod-latest-linux)

# Copy sp and compiler to build dir
cp -r ../scripting addons/sourcemod
cd addons/sourcemod/scripting

# Install Dependencies
wget "https://raw.githubusercontent.com/nosoop/SM-TFEconData/master/scripting/include/tf_econ_data.inc" -O include/tf_econ_data.inc
wget "https://raw.githubusercontent.com/peace-maker/DHooks2/dynhooks/sourcemod/scripting/include/dhooks.inc" -O include/dhooks.inc