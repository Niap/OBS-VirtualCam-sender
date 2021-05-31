# OBS-VirtualCam-sender
Send yuv data to OBS virtual camera on windows &amp; mac platform

# For windows

1. Download form (CatxFish/obs-virtual-cam)[https://github.com/CatxFish/obs-virtual-cam/releases] or build from source if you need.
2. Regist dll , must regist 32 bit dll on my test.then open your zoom or other meeting software. check if OBS-Camera exists.
```
regsvr32 "C:\Program Files\obs-studio\bin\32bit\obs-virtualsource.dll"
```
3. switch to Windows dirctory .use cmake to generate Visual Studio project.
```
cmake -B build .
cmake --build ./build --config Debug --target ALL_BUILD
```
4. DO NOT use control-c to interapt programe ,let the programe filish itself. IT"S IMPORTANT!.

# For Mac

1. Download From (johnboiles/obs-mac-virtualcam)[https://github.com/johnboiles/obs-mac-virtualcam/releases] or build from source if you need.
2. Install the pkg package or copy the plugin file to target DAL folder.
3. Build source from MacOS folder. 
```
cmake . & make
```
4. open zoom or other software then run our OBS-virualcam-serder program.