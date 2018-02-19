state("theturingtest")
{
	bool gameLoading: 0x2D8CCC0;
	byte chapterNumber: 0x2DB9078, 0xB0, 0x238, 0x64;
}

startup
{

}

init
{
	print("Game process found");
}

/*start
{

}*/

split
{
	return (current.chapterNumber!=old.chapterNumber);
}

isLoading
{
	if(current.chapterNumber!=0)
		return current.gameLoading;
}

update
{
	
}

exit
{
	print("Game closed.");
}