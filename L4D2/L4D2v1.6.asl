state("left4dead2", "")
{

}

state("left4dead2", "2.0.0.0")
{
	string32 whatsLoading     : "engine.dll", 0x53EC90;
	bool     gameLoading      : "engine.dll", 0x5CC89C;
	bool     cutscenePlaying1 : "client.dll", 0x66CEEC;
	bool     cutscenePlaying2 : "client.dll", 0x66D000;
	bool     finaleTrigger1   : "client.dll", 0x6ED110;
	bool     finaleTrigger2   : "client.dll", 0x6ED110;
	bool     scoreboardLoad1  : "client.dll", 0x6DB58D;
	bool     scoreboardLoad2  : "client.dll", 0x6FA215;
	bool     hasControl       : "client.dll", 0x68FBD4;
}

state("left4dead2", "2.0.0.8")
{
	string32 whatsLoading     : "engine.dll", 0x53EC90;
	bool     gameLoading      : "engine.dll", 0x5CC89C;
	bool     cutscenePlaying1 : "client.dll", 0x66D000;
	bool     cutscenePlaying2 : "client.dll", 0x66CEEC;
	bool     finaleTrigger1   : "client.dll", 0x6ED110;
	bool     finaleTrigger2   : "client.dll", 0x6ED110;
	bool     scoreboardLoad1  : "client.dll", 0x6FA215;
	bool     scoreboardLoad2  : "client.dll", 0x6DB58D;
	bool     hasControl       : "client.dll", 0x6FB304;
}

state("left4dead2", "2.0.1.2")
{
	string32 whatsLoading     : "engine.dll", 0x542D10;
	bool     gameLoading      : "engine.dll", 0x5D091C;
	bool     cutscenePlaying1 : "client.dll", 0x67647C;
	bool     cutscenePlaying2 : "client.dll", 0x676590;
	bool     finaleTrigger1   : "client.dll", 0x6F6810;
	bool     finaleTrigger2   : "client.dll", 0x6F6B14;
	bool     scoreboardLoad1  : "client.dll", 0x6E4C85;
	bool     scoreboardLoad2  : "client.dll", 0x703B35;
	bool     hasControl       : "client.dll", 0x704C24;
}

state("left4dead2", "2.0.2.7")
{
	string32 whatsLoading     : "engine.dll", 0x544D10;
	bool     gameLoading      : "engine.dll", 0x5D291C;
	bool     cutscenePlaying1 : "client.dll", 0x676698;
	bool     cutscenePlaying2 : "client.dll", 0x676584;
	bool     finaleTrigger1   : "client.dll", 0x6F68F0;
	bool     finaleTrigger2   : "client.dll", 0x6F6BF4;
	bool     scoreboardLoad1  : "client.dll", 0x703C15;
	bool     scoreboardLoad2  : "client.dll", 0x6E4D6D;
	bool     hasControl       : "client.dll", 0x704D04;
}

state("left4dead2", "2.0.4.5")
{
	string32 whatsLoading     : "engine.dll", 0x547F90;
	bool     gameLoading      : "engine.dll", 0x5DE494;
	bool     cutscenePlaying1 : "client.dll", 0x686F7C;
	bool     cutscenePlaying2 : "client.dll", 0x687090;
	bool     finaleTrigger1   : "client.dll", 0x7074E8;
	bool     finaleTrigger2   : "client.dll", 0x707824;
	bool     scoreboardLoad1  : "client.dll", 0x6F57BD;
	bool     scoreboardLoad2  : "client.dll", 0x714885;
	bool     hasControl       : "client.dll", 0x715974;
}


state("left4dead2", "2.0.7.5")
{
	string32 whatsLoading     : "engine.dll", 0x544490;
	bool     gameLoading      : "engine.dll", 0x5DA8CC;
	bool     cutscenePlaying1 : "client.dll", 0x688E14;
	bool     cutscenePlaying2 : "client.dll", 0x688F28;
	bool     finaleTrigger1   : "client.dll", 0x7092F8;
	bool     finaleTrigger2   : "client.dll", 0x709634;
	bool     scoreboardLoad1  : "client.dll", 0x6F761D;
	bool     scoreboardLoad2  : "client.dll", 0x7168A5;
	bool     hasControl       : "client.dll", 0x717994;
}

state("left4dead2", "2.0.9.1")
{
	string32 whatsLoading     : "engine.dll", 0x544490;
	bool     gameLoading      : "engine.dll", 0x5E19D4;
	bool     cutscenePlaying1 : "client.dll", 0x688E64;
	bool     cutscenePlaying2 : "client.dll", 0x688F78;
	bool     finaleTrigger1   : "client.dll", 0x709370;
	bool     finaleTrigger2   : "client.dll", 0x7096AC;
	bool     scoreboardLoad1  : "client.dll", 0x6F7685;
	bool     scoreboardLoad2  : "client.dll", 0x71691D;
	bool     hasControl       : "client.dll", 0x717A0C;
}

state("left4dead2", "Newest")
{
	string32 whatsLoading     : "engine.dll", 0x604A80;
	bool     gameLoading      : "engine.dll", 0x46C54C;
	bool     cutscenePlaying1 : "client.dll", 0x703D78;
	bool     cutscenePlaying2 : "client.dll", 0x703C64;
	bool     finaleTrigger1   : "client.dll", 0x788AD8;
	bool     finaleTrigger2   : "client.dll", 0x788E14;
	bool     scoreboardLoad1  : "client.dll", 0x796215;
	bool     scoreboardLoad2  : "client.dll", 0x776AB5;
	bool     hasControl       : "client.dll", 0x7972CC;
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
	settings.SetToolTip("ILs","To select the category you are running, make sure you check all the checkboxes above it.");
	settings.Add("mainCampaigns", false, "Main Campaigns","ILs");
	settings.Add("allCampaigns", false, "All Campaigns","mainCampaigns");
	
	settings.Add("cutscenelessStart", false, "Autostart on cutsceneless campaigns");
	settings.SetToolTip("cutscenelessStart", "Uses a different method to detect when to autostart. Causes the splitter to autostart on every level");
	
	settings.Add("foxyStart", true, "New start logic");
	settings.SetToolTip("foxyStart", "Use the new start logic. This should fix autostart for people which it wasn't working. Uncheck to revert to the old method.");
	
	settings.Add("alternateVersionCheck", false, "Manual version selection");
	settings.SetToolTip("alternateVersionCheck", "Select the game version you are running manually. Leave this unchecked for automatic version selection.");
	settings.Add("version2000", false, "Version 2.0.0.0", "alternateVersionCheck");
	settings.SetToolTip("version2000", "Make sure to check all the checkboxes above the game version you wanna run");
	settings.Add("version2008", false, "Version 2.0.0.8", "version2000");
	settings.Add("version2012", false, "Version 2.0.1.2", "version2008");
	settings.Add("version2027", false, "Version 2.0.2.7", "version2012");
	settings.Add("version2045", false, "Version 2.0.4.5", "version2027");
	settings.Add("version2075", false, "Version 2.0.7.5", "version2045");
	settings.Add("version2091", false, "Version 2.0.9.1", "version2075");
	settings.Add("versionNewest", false, "Newest Version", "version2091");
	
	settings.Add("debug", false, "See internal values through DebugView");
	settings.SetToolTip("debug", "See the values that the splitter is using to make actions. Requires DebugView. This setting may cause additional lag, so only have this checked if needed.");
	
	settings.CurrentDefaultParent = "debug";
	settings.Add("debugStart", false, "See values referring to autostart");
	settings.Add("debugSplit", false, "See values referring to autosplit");
	
	vars.CurrentVersion="";
	refreshRate=30;
}

init
{
	print("Game process found");
	
	print("Game main module size is " + modules.First().ModuleMemorySize.ToString());
	
	vars.VersionNewest= memory.ReadString(modules.Where(m => m.ModuleName == "engine.dll").First().BaseAddress + 0x694D28, 6);
	vars.Version2091= memory.ReadString(modules.Where(m => m.ModuleName == "engine.dll").First().BaseAddress + 0x404EF8, 7);
	vars.Version2075= memory.ReadString(modules.Where(m => m.ModuleName == "engine.dll").First().BaseAddress + 0x404EF8, 7);
	vars.Version2045= memory.ReadString(modules.Where(m => m.ModuleName == "engine.dll").First().BaseAddress + 0x408738, 7);
	vars.Version2027= memory.ReadString(modules.Where(m => m.ModuleName == "engine.dll").First().BaseAddress + 0x405558, 7);
	vars.Version2012= memory.ReadString(modules.Where(m => m.ModuleName == "engine.dll").First().BaseAddress + 0x4034F8, 7);
	vars.Version2008= memory.ReadString(modules.Where(m => m.ModuleName == "engine.dll").First().BaseAddress + 0x3FF4F0, 7);
	vars.Version2000= memory.ReadString(modules.Where(m => m.ModuleName == "engine.dll").First().BaseAddress + 0x3FF4A8, 7);
		
	print("Looking for game version...");
	if(settings["alternateVersionCheck"])
	{
		if(settings["versionNewest"])
			version="Newest";
		else if(settings["version2091"])
			version="2.0.9.1";
		else if(settings["version2075"])
			version="2.0.7.5";
		else if(settings["version2045"])
			version="2.0.4.5";
		else if(settings["version2027"])
			version="2.0.2.7";
		else if(settings["version2012"])
			version="2.0.1.2";
		else if(settings["version2008"])
			version="2.0.0.8";
		else if(settings["version2000"])
			version="2.0.0.0";
	}
	
	else
	{
		if(vars.CurrentVersion=="")
		{
			if(vars.VersionNewest=="2.1.5.")
				version="Newest";
			else if(vars.Version2091=="2.0.9.1")
				version="2.0.9.1";
			else if(vars.Version2075=="2.0.7.5")
				version="2.0.7.5";
			else if(vars.Version2045=="2.0.4.5")
				version="2.0.4.5";
			else if(vars.Version2027=="2.0.2.7")
				version="2.0.2.7";
			else if(vars.Version2012=="2.0.1.2")
				version="2.0.1.2";
			else if(vars.Version2008=="2.0.0.8")
				version="2.0.0.8";
			else if(vars.Version2000=="2.0.0.0")
				version="2.0.0.0";
			else
				version="";
		}
		else
			version=vars.CurrentVersion;
	}
	if(version=="")
		print("Unknown game version");
	else
		print("Game version is " + version);
	vars.CurrentVersion=version;
	
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
	vars.cutsceneStart = DateTime.MaxValue;
}

start
{
	if (settings["foxyStart"])
	{
		// Once we have control after a cutscene plays for at least 1 second, we're ready to start.
		if (current.hasControl && !current.gameLoading)
		{
			if (settings["cutscenelessStart"] || (DateTime.Now - vars.cutsceneStart > TimeSpan.FromSeconds(1)))
			{
				print("CUSTSCENE RAN FOR " + (DateTime.Now - vars.cutsceneStart));
				vars.cutsceneStart = DateTime.MaxValue;
				return true;
			}
			else if (!settings["cutscenelessStart"] && vars.cutsceneStart != DateTime.MaxValue)
			{
				// Sometimes the game sets 'current.hasControl' to 'false', even when you have control. We need to detect those cases in order to reset the cutscene timer.
				print("FALSE POSITIVE!");
				vars.cutsceneStart = DateTime.MaxValue;
			}
		}
		
		// If we're not loading, and the player does not have control, a cutscene must be playing. Mark the time.
		if (!old.hasControl && !current.hasControl && !current.gameLoading && vars.cutsceneStart == DateTime.MaxValue)
		{
			print("CUSTSCENE START!");
			vars.cutsceneStart = DateTime.Now;
		}
		
		return false;
	}
	else
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
		else if((current.cutscenePlaying1 || current.cutscenePlaying2) && !old.cutscenePlaying1 && !old.cutscenePlaying2 && (current.whatsLoading == "c7m3_port" || current.whatsLoading == "c5m5_bridge" || current.whatsLoading == "c6m3_port"))
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
		else if((current.cutscenePlaying1 || current.cutscenePlaying2) && !old.cutscenePlaying1 && !old.cutscenePlaying2 && (current.whatsLoading == "c7m3_port" || current.whatsLoading == "c5m5_bridge" || current.whatsLoading == "c6m3_port"))
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