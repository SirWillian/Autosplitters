state("theturingtest")
{
	bool gameLoading   	: 0x2D8CCC0;
	byte chapterNumber 	: 0x2DB9078, 0xB0, 0x238, 0x64;
	short sectorNumber 	: 0x2DB9060, 0x114;
	bool restartScreen 	: 0x2DB9078, 0x100;
	//There must be a better way of doing this but I couldn't figure out any other way of reading a vector's abs.
	float xSpeed		: "PhysX3PROFILE_x64.dll", 0x284BF8, 0x3C0, 0x10, 0x14C;
	float ySpeed		: "PhysX3PROFILE_x64.dll", 0x284BF8, 0x3C0, 0x10, 0x150;
	float zSpeed		: "PhysX3PROFILE_x64.dll", 0x284BF8, 0x3C0, 0x10, 0x154;
}

startup
{
	settings.Add("sectorSplit", false, "Split after every sector");
	settings.SetToolTip("sectorSplit", "Leaving this unchecked will still split every chapter");
	settings.Add("disablePause", false, "Disable pausing on loads");
	settings.SetToolTip("disablePause", "Checking this will disable pausing the timer on loads (in case it's not working properly)");
	
	vars.loadHiccups=0;
	vars.considerHiccups=false;
	vars.maxHiccups=0;
	vars.cameFromRestart=false;
	vars.speedAbs=0.0;
}

init
{
	print("Game process found");
}

start
{
	if(current.chapterNumber==0 && old.gameLoading && !current.gameLoading && vars.loadHiccups==2)
		return true;
}

split
{
	return (current.chapterNumber!=old.chapterNumber || (settings["sectorSplit"] && current.sectorNumber!=old.sectorNumber));
}

isLoading
{
	if(!settings["disablePause"])
		if(current.chapterNumber!=0) //The load flag goes up during the landing at Europa but it's not a loading
			return ((current.gameLoading || vars.considerHiccups) && vars.speedAbs==0);
}

update
{
	if(old.sectorNumber!=current.sectorNumber || (!old.restartScreen && current.restartScreen))
	{
		vars.loadHiccups=0;
		vars.considerHiccups=false;
		vars.cameFromRestart=false;
		
		if(current.chapterNumber == 8)
			vars.maxHiccups=3;
		else if(current.sectorNumber > 70)
			vars.maxHiccups=1;
		else if(current.sectorNumber % 10 == 0)
			vars.maxHiccups=2;
		else
			vars.maxHiccups=3;		
	}
	
	if(old.gameLoading && !current.gameLoading)
		vars.loadHiccups++;
	
	if(vars.loadHiccups > vars.maxHiccups)
		vars.considerHiccups=false;
		
	if(old.restartScreen && !current.restartScreen)
		vars.cameFromRestart=true;
	
	if(old.chapterNumber!=current.chapterNumber || (!old.gameLoading && current.gameLoading && vars.cameFromRestart))
		vars.considerHiccups=true;
		
	//Speed absolute value
	vars.speedAbs = Math.Sqrt(Math.Pow(current.xSpeed,2) + Math.Pow(current.ySpeed,2) + Math.Pow(current.zSpeed,2));
}

exit
{
	print("Game closed.");
}