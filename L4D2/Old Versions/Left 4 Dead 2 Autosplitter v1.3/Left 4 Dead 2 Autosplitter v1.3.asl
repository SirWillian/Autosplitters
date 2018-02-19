state("left4dead2")
{
	
}

state("left4dead2", "Newest")
{
	string32 whatsLoading     : "engine.dll", 0x604A80;
	bool     gameLoading      : "engine.dll", 0x46C54C;
	bool     cutscenePlaying1 : "client.dll", 0x702D78;
	bool     cutscenePlaying2 : "client.dll", 0x702C64;
	bool     finaleTrigger1   : "client.dll", 0x787AD8;
	bool     finaleTrigger2   : "client.dll", 0x787E14;
	bool     campaignLoading  : "client.dll", 0x787AD8;
	bool     scoreboardLoad1  : "client.dll", 0x795215;
	bool     scoreboardLoad2  : "client.dll", 0x775AB5;
	bool     hasControl       : "client.dll", 0x7962CC;
}

state("left4dead2", "2.0.0.8")
{
	string32 whatsLoading     : "engine.dll", 0x53EC90;
	bool     gameLoading      : "engine.dll", 0x5CC89C;
	bool     cutscenePlaying1 : "client.dll", 0x66D000;
	bool     cutscenePlaying2 : "client.dll", 0x66CEEC;
	bool     finaleTrigger1   : "client.dll", 0x6ED110;
	bool     finaleTrigger2   : "client.dll", 0x6ED110;
	bool     campaignLoading  : "engine.dll", 0x3C9C8F;
	bool     scoreboardLoad1  : "client.dll", 0x6FA215;
	bool     scoreboardLoad2  : "client.dll", 0x6DB58D;
	bool     hasControl       : "client.dll", 0x6FB304;
}

state("left4dead2", "2.0.2.7")
{
	string32 whatsLoading     : "engine.dll", 0x544D10;
	bool     gameLoading      : "engine.dll", 0x5D291C;
	bool     cutscenePlaying1 : "client.dll", 0x676698;
	bool     cutscenePlaying2 : "client.dll", 0x676584;
	bool     finaleTrigger1   : "client.dll", 0x6F68F0;
	bool     finaleTrigger2   : "client.dll", 0x6F6BF4;
	bool     campaignLoading  : "engine.dll", 0x3CFC8F;
	bool     scoreboardLoad1  : "client.dll", 0x703C15;
	bool     scoreboardLoad2  : "client.dll", 0x6E4D6D;
	bool     hasControl       : "client.dll", 0x704D04;
}

state("left4dead2", "2.0.9.1")
{
	string32 whatsLoading     : "engine.dll", 0x544490;
	bool     gameLoading      : "engine.dll", 0x5E19D4;
	bool     cutscenePlaying1 : "client.dll", 0x688E64;
	bool     cutscenePlaying2 : "client.dll", 0x688F78;
	bool     finaleTrigger1   : "client.dll", 0x709370;
	bool     finaleTrigger2   : "client.dll", 0x7096AC;
	bool     campaignLoading  : "engine.dll", 0x3CF937;
	bool     scoreboardLoad1  : "client.dll", 0x6F7685;
	bool     scoreboardLoad2  : "client.dll", 0x71691D;
	bool     hasControl       : "client.dll", 0x717A0C;
}

startup
{
	settings.Add("campaignSplit", true, "Split after each campaign");
	settings.Add("chapterSplit", true, "Split inbetween chapters", "campaignSplit");
	settings.Add("scoreboardVSgameLoading", true, "Split chapters on Scoreboard vs Game Loading", "chapterSplit");
	settings.SetToolTip("scoreboardVSgameLoading", "Toggle between splitting chapters when the scoreboard shows up (checked) and when the loading between chapters begins (unchecked).");
	
	settings.Add("splitOnce", false, "Split only when the run ends");
	settings.SetToolTip("splitOnce","These checkboxes only matter if you didn't check \"Split after each campaign\". They indicate what category you are running.");
	settings.Add("ILs", false, "Individual Levels", "splitOnce");
	settings.SetToolTip("ILs","You need to check every category above the category you are running because of how the splitter was made.");
	settings.Add("mainCampaigns", false, "Main Campaigns","ILs");
	settings.Add("allCampaigns", false, "All Campaigns","mainCampaigns");	
	
	settings.Add("cutscenelessStart", false, "Autostart on cutsceneless campaigns");
	settings.SetToolTip("cutscenelessStart", "Uses a different method to detect when to autostart. Causes the splitter to autostart on every level");
	
	settings.Add("versionDifference", true, "Version 2.0.2.7 vs 2.0.9.1");
	settings.SetToolTip("versionDifference", "Toggle between versions 2.0.2.7 (checked) and 2.0.9.1 (unchecked). Doesn't matter when playing versions different than these ones. Save and reopen your LiveSplit layout after switching this checkbox.");
	
	settings.Add("debug", false, "See internal values through DebugView");
	settings.SetToolTip("debug", "See the values that the splitter is using to make actions. Requires DebugView. This setting may cause additional lag, so only have this checked if needed.");
	
	settings.CurrentDefaultParent = "debug";
	settings.Add("debugStart", false, "See values referring to autostart");
	settings.Add("debugSplit", false, "See values referring to autosplit");
	
	refreshRate=30;
}

init
{
	print("Game process found");
	
	print("Game main module size is " + modules.First().ModuleMemorySize.ToString());
	
	switch(modules.First().ModuleMemorySize)
	{
		case 471040:
			version = "2.0.0.8";
			break;
		case 1740800: //Very odd value, but I guess it can happen
			version = "2.0.0.8";
			break;
		case 385024:
			version = "Newest";
			break;
		case 778240:
			if(settings["versionDifference"])
				version = "2.0.2.7";
			else
				version = "2.0.9.1";
			break;
	}
	
	if(version!="")
		print("Current version is " + version);
	else
		print("Current version is unknown");
	vars.campaignsCompleted=0;
	if(settings["allCampaigns"])
		vars.totalCampaignNumber=13;
	else if (settings["mainCampaigns"])
		vars.totalCampaignNumber=5;
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
		if((current.finaleTrigger1 || current.finaleTrigger2) && !old.finaleTrigger1 && !old.finaleTrigger2)
		{
			print("Split on finale");
			return true;
		}
		else if((current.cutscenePlaying1 || current.cutscenePlaying2) && !old.cutscenePlaying1 && !old.cutscenePlaying2 && current.whatsLoading == "c7m3_port")
		{
			print("Split on THE BEST CAMPAIGN EVER");
			return true;
		}
		//Split inbetween chapters
		if(settings["chapterSplit"])
		{
			if(settings["scoreboardVSgameLoading"])
			{
				if(!current.finaleTrigger1 && !current.finaleTrigger2 && !old.scoreboardLoad1 && !old.scoreboardLoad2 && (current.scoreboardLoad1 || current.scoreboardLoad2))
				{
					print("Split at the end of a chapter at the scoreboard");
					return true;
				}
			}
			else
			{
				if(!current.finaleTrigger1 && !current.finaleTrigger2 && !old.gameLoading && current.gameLoading && (current.scoreboardLoad1 || current.scoreboardLoad2))
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
		if((current.finaleTrigger1 || current.finaleTrigger2) && !old.finaleTrigger1 && !old.finaleTrigger2)
		{
			vars.campaignsCompleted++;
			print("Campaign count is now " + vars.campaignsCompleted.ToString());
		}
		else if((current.cutscenePlaying1 || current.cutscenePlaying2) && !old.cutscenePlaying1 && !old.cutscenePlaying2 && current.whatsLoading == "c7m3_port")
		{
			vars.campaignsCompleted++;
			print("Finished THE BEST CAMPAIGN EVER and the campaign sum is now " + vars.campaignsCompleted.ToString());
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
	if (version=="")
		return false;
	else
		return current.gameLoading;
}

update
{
	if(settings["debug"])
	{
		if(settings["debugStart"]) 
		{
			print("Autostart:\n current.gameLoading = " + current.gameLoading.ToString() +
			"\n current.cutscenePlaying1 = " + current.cutscenePlaying1.ToString() +
			"\n current.cutscenePlaying2 = " + current.cutscenePlaying2.ToString() +
			"\n current.hasControl = " + current.hasControl.ToString() +
			"\n vars.startRun = " + vars.startRun.ToString());
		}
		if(settings["debugSplit"])
		{
			print("Autosplit:\n current.finaleTrigger1 = " + current.finaleTrigger1.ToString() +
			"\n current.finaleTrigger2 = " + current.finaleTrigger2.ToString() +
			"\n current.cutscenePlaying1 = " + current.cutscenePlaying1.ToString() +
			"\n current.cutscenePlaying2 = " + current.cutscenePlaying2.ToString() +
			"\n current.whatsLoading = " + current.whatsLoading);
			if(settings["chapterSplit"])
			{
				print(" current.scoreboardLoad1 = " + current.scoreboardLoad1.ToString() +
				"\n current.scoreboardLoad2 = " + current.scoreboardLoad2.ToString() +
				"\n current.gameLoading = " + current.gameLoading.ToString());
			}
			if(settings["splitOnce"])
			{
				print(" vars.campaignsCompleted = " + vars.campaignsCompleted.ToString() +
				"\n vars.totalCampaignNumber = " + vars.totalCampaignNumber.ToString());
			}
		}
	}
	
	if(version == "")
		return false;
}

exit
{
	print("Game closed.");
}