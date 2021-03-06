public void OnSQLConnect(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		SetFailState("(OnSQLConnect) Can't connect to mysql");
		return;
	}
	
	g_dDB = view_as<Database>(CloneHandle(hndl));
	
	CreateTable();
}

void CreateTable()
{
	// TODO: Add support for DEFAULT_FLAG
	char sQuery[1024];
	Format(sQuery, sizeof(sQuery),
	"CREATE TABLE IF NOT EXISTS `weaponPaints` ( \
		`id` INT NOT NULL AUTO_INCREMENT, \
		`communityid` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL, \
		`classname` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL, \
		`defindex` int(11) NOT NULL DEFAULT '0', \
		`wear` FLOAT NOT NULL DEFAULT '%.4f', \
		`seed` int(11) NOT NULL DEFAULT '%d', \
		`quality` int(11) NOT NULL DEFAULT '%d', \
		`flag` varchar(18) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '', \
		PRIMARY KEY (`id`), \
		UNIQUE KEY (`communityid`, `classname`) \
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;", DEFAULT_WEAR, DEFAULT_SEED, DEFAULT_QUALITY);
	
	if (g_bDebug)
	{
		LogMessage(sQuery);
	}
	
	g_dDB.Query(SQL_CreateTable, sQuery);
}

public void SQL_CreateTable(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null || strlen(error) > 0)
	{
		SetFailState("(SQL_CreateTable) Fail at Query: %s", error);
		return;
	}
	delete results;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientValid(i))
		{
			LoadClientPaints(i);
		}
	}
}

void LoadClientPaints(int client)
{
	char sCommunityID[32];
	if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
	{
		LogError("Auth failed for client index %d", client);
		return;
	}
	
	char sQuery[512];
	Format(sQuery, sizeof(sQuery), "SELECT communityid, classname, defindex, wear, seed, quality, flag FROM weaponPaints WHERE communityid = \"%s\";", sCommunityID);
	
	if (g_bDebug)
	{
		LogMessage(sQuery);
	}
	
	g_dDB.Query(SQL_LoadClientPaints, sQuery, GetClientUserId(client));
}

public void SQL_LoadClientPaints(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null || strlen(error) > 0)
	{
		SetFailState("(SQL_LoadClientPaints) Fail at Query: %s", error);
		return;
	}
	else
	{
		if(results.HasResults)
		{
			int client = GetClientOfUserId(data);
				
			if (IsClientValid(client))
			{
				while (results.FetchRow())
				{
					char sClass[WP_CLASSNAME], sCommunityID[WP_COMMUNITYID], sFlag[WP_FLAG];
					int iDefIndex, iSeed, iQuality;
					float fWear;

					results.FetchString(0, sCommunityID, sizeof(sCommunityID));
					results.FetchString(1, sClass, sizeof(sClass));
					iDefIndex = results.FetchInt(2);
					fWear = results.FetchFloat(3);
					iSeed = results.FetchInt(4);
					iQuality = results.FetchInt(5);
					results.FetchString(6, sFlag, sizeof(sFlag));

					if (strlen(sClass) > 7)
					{
						int iCache[paintsCache];

						strcopy(iCache[pC_sCommunityID], WP_COMMUNITYID, sCommunityID);
						strcopy(iCache[pC_sClassName], WP_CLASSNAME, sClass);
						iCache[pC_iDefIndex] = iDefIndex;
						iCache[pC_fWear] = fWear;
						iCache[pC_iSeed] = iSeed;
						iCache[pC_iQuality] = iQuality;
						strcopy(iCache[pC_sFlag], WP_FLAG, sFlag);

						g_aCache.PushArray(iCache[0]);

						if (g_bDebug)
						{
							LogMessage("[SQL_LoadClientPaints] Player: \"%L\" - CommunityID: %s - Classname: %s - DefIndex: %d - Wear: %.4f - Seed: %d - Quality: %d - Flag: %s", client, iCache[pC_sCommunityID], iCache[pC_sClassName], iCache[pC_iDefIndex], iCache[pC_fWear], iCache[pC_iSeed], iCache[pC_iQuality], iCache[pC_sFlag]);
						}
					}
				}
				
				g_bReady[client] = true;
			}
		}
	}
}
