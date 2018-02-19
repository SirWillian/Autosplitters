state("theturingtest")
{
	bool gameLoading   : 0x2D8CCC0;
	byte chapterNumber : 0x2DB9078, 0xB0, 0x238, 0x64;
	byte sectorNumber  : 0x2DB9060, 0x114;
	bool restartScreen : 0x2DB9078, 0x100;
}

startup
{
	settings.Add("sectorSplit", false, "Split after every sector");
	settings.SetToolTip("sectorSplit", "Leaving this unchecked will still split every chapter");
	
	vars.loadHiccups=0;
	vars.considerHiccups=false;
	vars.maxHiccups=0;
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
	if(current.chapterNumber!=0) //The load flag goes up during the landing at Europa but it's not a loading
		return (current.gameLoading || vars.considerHiccups);
}

update
{
	if(old.sectorNumber!=current.sectorNumber || (!old.restartScreen && current.restartScreen))
	{
		vars.loadHiccups=0;
		vars.considerHiccups=false;
		
		if(current.chapterNumber == 8)
			vars.maxHiccups=3;
		else if(current.sectorNumber > 70)
			vars.maxHiccups=1;
		else if(current.sectorNumber % 10 == 0)
			vars.maxHiccups=2;
		else
			vars.maxHiccups=3;		
	}
	
	if(vars.loadHiccups > vars.maxHiccups)
		vars.considerHiccups=false;
	
	if(old.gameLoading && !current.gameLoading)
		vars.loadHiccups++;
	
	if((old.restartScreen && !current.restartScreen)  || old.chapterNumber!=current.chapterNumber)
		vars.considerHiccups=true;
}

exit
{
	print("Game closed.");
}