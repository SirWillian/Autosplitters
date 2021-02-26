state("left4dead")
{

}

state("hl2")
{

}

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
	settings.Add("AutomaticGameTime", true, "Automatically set splits to Game Time");
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
	settings.Add("versionNewest", false, "Newest Version", "version1005");
	
	settings.Add("debug", false, "See internal values through DebugView");
	settings.SetToolTip("debug", "See the values that the splitter is using to make actions. Requires DebugView. This setting may cause additional lag, so only have this checked if needed.");
	
	vars.CurrentVersion="";
	refreshRate=30;
}

init
{
	print("Game process found");
	
	print("Game main module size is " + modules.First().ModuleMemorySize.ToString());
	
	vars.Version1005= memory.ReadString(modules.Where(m => m.ModuleName == "engine.dll").First().BaseAddress + 0x40CF48, 7);
	vars.VersionNewest= memory.ReadString(modules.Where(m => m.ModuleName == "engine.dll").First().BaseAddress + 0x3E7304, 6);
	
	print("Looking for game version...");
	if(settings["alternateVersionCheck"])
	{
		if(settings["versionNewest"])
			version="Newest";
		else if(settings["version1005"])
			version="1.0";
	}
	
	else
	{
		if(vars.CurrentVersion=="")
		{
			if(vars.Version1005=="1.0.0.5")
				version="1.0";
			else if(vars.VersionNewest=="1.0.3.")
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
	if (settings["AutomaticGameTime"])
	{
		timer.CurrentTimingMethod = TimingMethod.GameTime;
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
	
	if(old.gameLoading && (current.cutscenePlaying1 || current.cutscenePlaying2) && !vars.startRun)
	{
		vars.startRun=true;
		print("Autostart triggered");
	}
	
	else if(!current.gameLoading && (old.cutscenePlaying1 || old.cutscenePlaying2) && !current.cutscenePlaying1 && !current.cutscenePlaying2 && vars.startRun)
	{
		vars.startRun=false;
		print("Run autostarted");
		return true;
	}
}

split
{
	//Split on finales
	if(settings["campaignSplit"])
	{
		if(!current.gameLoading && (current.cutscenePlaying1 || current.cutscenePlaying2) && !old.cutscenePlaying1 && !old.cutscenePlaying2)
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
		"\n vars.startRun = " + vars.startRun.ToString());
	}
	
	if(version == "")
		return false;
}

exit
{
	print("Game closed.");
}