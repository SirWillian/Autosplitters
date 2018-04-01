// 1.0 splitting notes:
// On some computers, including mine (G4Vi), the 'cutscenePlaying' variables
// are not set, so another state called '1.0_alt' is provided, however those variables
// are weird too, so we check for a combination to get rid of the seemingly random false positives
// those offsets that can be used are as follows:
// client.dll+4F04DB (can't be casted to bool)
// client.dll+590AC4 (can be casted to bool?)
// client.dll+590AC6 (can be casted to bool?)

//Original 1.0 offsets
state("hl2", "1.0")
{
	bool     gameLoading      : "engine.dll", 0x5D1E6C;	
	bool     cutscenePlaying1 : "client.dll", 0x522954;
	bool     cutscenePlaying2 : "client.dll", 0x522A50;     
	bool     scoreboardLoad   : "client.dll", 0x5900E9;
	bool     hasControl       : "client.dll", 0x574950, 0x0C;
}

state("left4dead", "1.0")
{
	bool     gameLoading      : "engine.dll", 0x5D1E6C;	
	bool     cutscenePlaying1 : "client.dll", 0x522954;
	bool     cutscenePlaying2 : "client.dll", 0x522A50;	
	bool     scoreboardLoad   : "client.dll", 0x5900E9;
	bool     hasControl       : "client.dll", 0x574950, 0x0C;
}

//Alternative 1.0 offsets
state("hl2", "1.0_alt")
{
    bool     gameLoading      : "engine.dll", 0x5D1E6C;
    bool     cutscenePlaying1 : "client.dll", 0x590AC4;	
	bool     cutscenePlaying2 : "client.dll", 0x590AC6;	
    bool     scoreboardLoad   : "client.dll", 0x5900E9;
	bool     hasControl       : "client.dll", 0x574950, 0x0C;
}


state("left4dead", "1.0_alt")
{
    bool     gameLoading      : "engine.dll", 0x5D1E6C;
    bool     cutscenePlaying1 : "client.dll", 0x590AC4;	
	bool     cutscenePlaying2 : "client.dll", 0x590AC6;	
    bool     scoreboardLoad   : "client.dll", 0x5900E9;
	bool     hasControl       : "client.dll", 0x574950, 0x0C;
}


state("left4dead", "Newest")
{
	bool     gameLoading      : "engine.dll", 0x5AB994;
	bool     cutscenePlaying1 : "client.dll", 0x545C14;
	bool     cutscenePlaying2 : "client.dll", 0x545D14;
	bool     scoreboardLoad   : "client.dll", 0x5B3E91;
	bool     hasControl       : "client.dll", 0x5B3E94, 0x0C;
}

startup
{
	settings.Add("campaignSplit", true, "Split after each campaign");
	settings.Add("chapterSplit", true, "Split inbetween chapters", "campaignSplit");
	settings.Add("scoreboardVSgameLoading", true, "Split chapters on Scoreboard vs Game Loading", "chapterSplit");
	settings.SetToolTip("scoreboardVSgameLoading", "Toggle between splitting chapters when the scoreboard shows up (checked) and when the loading between chapters begins (unchecked).");
	
	settings.Add("splitOnce", false, "Split only when the run ends");
	settings.SetToolTip("splitOnce","These checkboxes only matter if you didn't check \"Split after each campaign\". They indicate what category you are running.");
	settings.Add("ILs", false, "Individual Campaigns", "splitOnce");
	settings.SetToolTip("ILs","You need to check every category above the category you are running because of how the splitter was made.");
	settings.Add("originalCampaigns", false, "Original Campaigns","ILs");
	settings.Add("allCampaigns", false, "All Campaigns","originalCampaigns");
	
	settings.Add("cutscenelessStart", false, "Autostart on cutsceneless campaigns");
	settings.SetToolTip("cutscenelessStart", "Uses a different method to detect when to autostart. Causes the splitter to autostart on every level");
	
	settings.Add("alternateVersionCheck", false, "Manual version selection");
	settings.SetToolTip("alternateVersionCheck", "Select the game version you are running manually. Leave this unchecked for automatic version selection.");
	settings.Add("version1005", false, "Version 1.0", "alternateVersionCheck");
	settings.SetToolTip("version1005", "Make sure to check all the checkboxes above the game version you wanna run");
	settings.Add("version1005alt", false, "Version 1.0 (Alternative Offsets)", "alternateVersionCheck");
	settings.SetToolTip("version1005alt", "Make sure to check all the checkboxes above the game version you wanna run");
	settings.Add("versionNewest", false, "Newest Version", "alternateVersionCheck");
	settings.SetToolTip("versionNewest", "Make sure to check all the checkboxes above the game version you wanna run");
		
	settings.Add("betterStartDetection", true, "Better start detection");
	settings.SetToolTip("betterStartDetection", "Polls the game more often when a run is not started, minor performance cost then, but resets to the regular value once it finds a start point.");
	
	settings.Add("debug", false, "See internal values through DebugView");
	settings.SetToolTip("debug", "See the values that the splitter is using to make actions. Requires DebugView. This setting may cause additional lag, so only have this checked if needed.");
	
	vars.CurrentVersion="";
	vars.RegularRefreshRate=30;
	vars.StartRefreshRate=300;
	refreshRate=vars.RegularRefreshRate;
}

init
{
	print("Game process found");
	
	print("Game main module size is " + modules.First().ModuleMemorySize.ToString());
	
	vars.Version1005= memory.ReadString(modules.Where(m => m.ModuleName == "engine.dll").First().BaseAddress + 0x40CF48, 7);
	vars.Version1035= memory.ReadString(modules.Where(m => m.ModuleName == "engine.dll").First().BaseAddress + 0x3E7304, 7);
	vars.IsAltOffsets = false;
	
	print("Looking for game version...");
	if(settings["alternateVersionCheck"])
	{
		if(settings["versionNewest"])
			version="Newest";
		else if(settings["version1005"])
			version="1.0";
		else if(settings["version1005alt"])
		{
		    version="1.0_alt";
			vars.IsAltOffsets = true;
		}
	}
	
	else
	{
		if(vars.CurrentVersion=="")
		{
			if(vars.Version1005=="1.0.0.5")
				version="1.0";
			else if(vars.Version1035=="1.0.3.5")
				version="Newest";
			else
				version="";
		}
	}
	
	if(version!="")
		print("Current version is " + version);
	else
		print("Unknown game version");
	vars.CurrentVersion=version;
	
	vars.campaignsCompleted=0;
	if(settings["allCampaigns"])
		vars.totalCampaignNumber=6;
	else if (settings["originalCampaigns"])
		vars.totalCampaignNumber=4;
	else if (settings["ILs"])
		vars.totalCampaignNumber=1;
	else
		vars.totalCampaignNumber=-1;
	
	if(settings["splitOnce"] && !settings["campaignSplit"])
		print("Total campaign number is " + vars.totalCampaignNumber.ToString());
	
	vars.startRun=false;
}

start
{
    if(settings["betterStartDetection"])
	{
	    //increase the chance it of starting properly by bumping this up temporarily
	    if(!vars.startRun)
	    {
	        refreshRate=vars.StartRefreshRate;	
	    }
	    else
	    {
	        refreshRate=vars.RegularRefreshRate;
	    }
	}
    
    
	
	if(settings["cutscenelessStart"] && old.gameLoading && !vars.startRun)
	{
		vars.startRun=true;
		print("Autostart triggered");
	}
	
	if(settings["cutscenelessStart"] && !current.gameLoading && current.hasControl && vars.startRun)
	{
		vars.startRun=false;
		print("Run autostarted");
		return true;
	}
	
	
	if((!vars.startRun && old.gameLoading) && !current.gameLoading)
	{
	    //if the cutscene starts
		if(current.cutscenePlaying1 || current.cutscenePlaying2)
	    {
            vars.startRun=true;
		    print("Autostart triggered");			
		       
	    }
		//if we load before the cutscene starts, remember it for when the cutscene starts
	    else
	    {   
		    print("Loaded before cutscene, passing gameLoading on");
		    current.gameLoading	= old.gameLoading;			    
	    }	           		
	}	
	else if(vars.startRun)
	{
	    //if we are loading and weren't already loading, there was an aborted start
	    if(current.gameLoading && !old.gameLoading)
	    {
	        vars.startRun = false;	
	    }
		//if the cutscene just ended
	    else if((old.cutscenePlaying1 || old.cutscenePlaying2) && !(current.cutscenePlaying1 || current.cutscenePlaying2))
	    {
		    vars.startRun=false;
		    print("Run autostarted");
		    return true;
	    }
	}	
}

split
{
	
	if(settings["campaignSplit"])
	{
	    //Split on finales		
		if((current.cutscenePlaying1 || current.cutscenePlaying2) && !(old.cutscenePlaying1 || old.cutscenePlaying2))
		{
		    print("Split on finale");
		    return true;		    	
		}
				
		
		//Split inbetween chapters
		if(settings["chapterSplit"])
		{
			if(settings["scoreboardVSgameLoading"])
			{
				if(!old.scoreboardLoad && current.scoreboardLoad)
				{
					print("Split at the end of a chapter at the scoreboard");
					return true;
				}
			}
			else
			{
				if(!old.gameLoading && current.gameLoading && !(current.cutscenePlaying1 || current.cutscenePlaying2))
				{
					print("Split at the end of a chapter when it began to load");
					return true;
				}
			}
		}
	}
	
	
	//Split only when the run ends
	if(settings["splitOnce"])
	{
		if((current.cutscenePlaying1 || current.cutscenePlaying2) && !old.cutscenePlaying1 && !old.cutscenePlaying2)
		{
			vars.campaignsCompleted++;
			print("Campaign count is now " + vars.campaignsCompleted.ToString());
		}
		if(vars.campaignsCompleted==vars.totalCampaignNumber)
		{
			print("Ended the run.");
			return true;
		}
	}
}

isLoading
{
	return current.gameLoading;
}

update
{
	if(settings["debug"])
	{
		print("Values:\n current.gameLoading = " + current.gameLoading.ToString() +		
		"\n current.cutscenePlaying1 = " + current.cutscenePlaying1.ToString() +
		"\n current.cutscenePlaying2 = " + current.cutscenePlaying2.ToString() +		
		"\n current.scoreboardLoad1 = " + current.scoreboardLoad.ToString() +
		"\n current.hasControl = " + current.hasControl.ToString() +
		//"\n refreshRate = " + refreshRate.ToString() +
		"\n vars.startRun = " + vars.startRun.ToString());
	}
	
	
	//HUGE MEME
	if(vars.IsAltOffsets)
	{	    
	    //if(current.cutscenePlaying2 || current.cutscenePlaying1) 
		{
		    //if we are in control or both cutscene variables aren't set, ignore
		    if(current.hasControl || !(current.cutscenePlaying2 && current.cutscenePlaying1))
		    {
		        current.cutscenePlaying1 = false;
		        current.cutscenePlaying2 = false;
		    }	
		}		
		
    }	
	else if(version == "")
		return false;
}

exit
{
	print("Game closed.");
}