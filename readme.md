This is a powershell script made to download & update Stardew valley mods using Nexus Mods API (https://www.nexusmods.com/news/13921) to act as a (very) rudimentary mod manager.  I mostly created this to get a little more experience with web APIs and Powershell in general, so it's currently not meant for serious usage.  This is just a fun project!


Requirements:

- Nexus Mods Personal API Key (requires Premium)
    - Put this in a file called 'api-key.txt' in the script root
- Powershell (Latest preferred, should work with 5+)
- csv list of mods
    - Format like this: 
```
ModName,ModID
Animated Fish,5735
```
    - ModName can technically be whatever you want, currently it isn't passed to the script
    - ModID is the number found at the end of the URL when you visit the page for a given mod (ex: https://www.nexusmods.com/stardewvalley/mods/5735)

Dependencies:

- 7Zip4Powershell: https://www.powershellgallery.com/packages/7Zip4Powershell/