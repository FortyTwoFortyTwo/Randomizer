# Randomizer

TF2 Gamemode where everyone plays as random class with random weapons, a rewritten of many old randomizer plugins.

## Development
This plugin is currently in early development, barely enough for testing but likely will contain bugs, missing bits around or weapon just don't work on some classes. This plugin aims to:
- Not break from upcoming major TF2 update, however gamedata will likely needs updating from it.
- Not break any balances from TF2 weapon rebalances update.
- Keeping as low hardcodes as possible, weapon not working for specific class, etc.

## Features
Apart from the obvious random class and weapon generator, this plugin currently includes:
- Many hook/detours on several SDK functions that have hardcode player classes, fixed by simply changing player class during SDK functions.
- Config with list of weapons to select from random pool, along with name for each weapons for HUD display.
- Config with huds to specify every weapons which netprop and maths to calculate meters to display.