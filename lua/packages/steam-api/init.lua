-- Libraries
local promise = promise
local string = string
local http = http
local util = util

-- Variables
local table_concat = table.concat
local math_Round = math.Round
local tonumber = tonumber
local tostring = tostring
local ipairs = ipairs
local select = select
local HTTP = HTTP
local type = type

function string.IsSteamID( str )
    return string.match( str, "^STEAM_%d+:%d+:%d+$" ) ~= nil
end

local apikey = CreateConVar( "steam_apikey", "", bit.bor( FCVAR_ARCHIVE, FCVAR_PROTECTED ), "https://steamcommunity.com/dev/apikey" )

module( "steam_api" )

-- BaseURL
BaseURL = "https://api.steampowered.com/"

-- Type/Enums
PROFILE = 1
GROUP = 2
OFFICIAL_GAME_GROUP = 3

local function getStrings( tbl )
    local result = {}
    for _, value in ipairs( tbl ) do
        local valueType = type( value )
        if valueType == "table" then
            for _, str in ipairs( value ) do
                result[ #result + 1 ] = str
            end
        elseif valueType == "number" then
            value = tonumber( value )
        end

        if valueType == "string" then
            result[ #result + 1 ] = value
        end
    end

    return result
end

local function getParameters( countName, ... )
    local parameters, count = {}, 0

    for _, value in ipairs( getStrings( { ... } ) ) do
        parameters[ "publishedfileids[" .. count .. "]" ] = value
        count = count + 1
    end

    parameters[ countName ] = tostring( count )

    return parameters
end

GetPublishedFileDetails = promise.Async( function( ... )
    local ok, result = http.Post( BaseURL .. "ISteamRemoteStorage/GetPublishedFileDetails/v1/", getParameters( "itemcount", ... ) ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    local code = result.code
    if code ~= 200 then
        return promise.Reject( select( -1, http.GetStatusDescription( code ) ) )
    end

    local body = result.body
    if not body then return promise.Reject( "request failed, no result" ) end

    local tbl = util.JSONToTable( body )
    if not tbl then return promise.Reject( "not JSON is returned, probably an error in API accessing" ) end

    local response = tbl.response
    if not response then return promise.Reject( "no response expected" ) end
    if response.result ~= 1 then return promise.Reject( "no result" ) end

    return response.publishedfiledetails
end )

-- GetPublishedFileDetails( "2958334539", "2955227497" ):Then( PrintTable )

GetCollectionDetails = promise.Async( function( ... )
    local ok, result = http.Post( BaseURL .. "ISteamRemoteStorage/GetCollectionDetails/v1/", getParameters( "collectioncount", ... ) ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    local code = result.code
    if code ~= 200 then
        return promise.Reject( select( -1, http.GetStatusDescription( code ) ) )
    end

    local body = result.body
    if not body then return promise.Reject( "request failed, no result" ) end

    local tbl = util.JSONToTable( body )
    if not tbl then return promise.Reject( "not JSON is returned, probably an error in API accessing" ) end

    local response = tbl.response
    if not response then return promise.Reject( "no response expected" ) end
    if response.result ~= 1 then return promise.Reject( "no result" ) end

    return response.collectiondetails
end )

-- GetCollectionDetails( "2952388775" ):Then( PrintTable )

GetPlayerSummaries = promise.Async( function( ... )
    local steamids = getStrings( {...} )
    if #steamids > 100 then return promise.Reject( "too many steamids" ) end

    for index, steamid in ipairs( steamids ) do
        if not string.IsSteamID( steamid ) then continue end
        steamids[ index ] = util.SteamIDTo64( steamid )
    end

    local ok, result = HTTP( {
        ["url"] = BaseURL .. "ISteamUser/GetPlayerSummaries/v2/",
        ["parameters"] = {
            ["key"] = apikey:GetString(),
            ["steamids"] = table_concat( steamids, ", " )
        }
    } ):SafeAwait()

    if not ok then return promise.Reject( result ) end

    local code = result.code
    if code ~= 200 then
        return promise.Reject( select( -1, http.GetStatusDescription( code ) ) )
    end

    local body = result.body
    if not body then return promise.Reject( "request failed, no result" ) end

    local tbl = util.JSONToTable( body )
    if not tbl then return promise.Reject( "not JSON is returned, probably an error in API accessing" ) end

    local response = tbl.response
    if not response then return promise.Reject( "no response expected" ) end

    return response.players
end )

-- GetPlayerSummaries( "STEAM_0:1:70096775", "76561198860822909" ):Then( PrintTable )

GetPlayerBans = promise.Async( function( ... )
    local steamids = getStrings( {...} )

    for index, steamid in ipairs( steamids ) do
        if not string.IsSteamID( steamid ) then continue end
        steamids[ index ] = util.SteamIDTo64( steamid )
    end

    local ok, result = HTTP( {
        ["url"] = BaseURL .. "ISteamUser/GetPlayerBans/v1/",
        ["parameters"] = {
            ["key"] = apikey:GetString(),
            ["steamids"] = table_concat( steamids, ", " )
        }
    } ):SafeAwait()

    if not ok then return promise.Reject( result ) end

    local code = result.code
    if code ~= 200 then
        return promise.Reject( select( -1, http.GetStatusDescription( code ) ) )
    end

    local body = result.body
    if not body then return promise.Reject( "request failed, no result" ) end

    local tbl = util.JSONToTable( body )
    if not tbl then return promise.Reject( "not JSON is returned, probably an error in API accessing" ) end

    local players = tbl.players
    if not players then return promise.Reject( "no players expected" ) end

    return players
end )

-- GetPlayerBans( "76561198860822909", "76561198193524370" ):Then( PrintTable )

GetUserGroupList = promise.Async( function( steamid )
    if string.IsSteamID( steamid ) then
        steamid = util.SteamIDTo64( steamid )
    end

    local ok, result = HTTP( {
        ["url"] = BaseURL .. "ISteamUser/GetUserGroupList/v1/",
        ["parameters"] = {
            ["key"] = apikey:GetString(),
            ["steamid"] = steamid
        }
    } ):SafeAwait()

    if not ok then return promise.Reject( result ) end

    local code = result.code
    if code ~= 200 then
        return promise.Reject( select( -1, http.GetStatusDescription( code ) ) )
    end

    local body = result.body
    if not body then return promise.Reject( "request failed, no result" ) end

    local tbl = util.JSONToTable( body )
    if not tbl then return promise.Reject( "not JSON is returned, probably an error in API accessing" ) end

    local response = tbl.response
    if not response then return promise.Reject( "no response expected" ) end
    if not response.success then return promise.Reject( "no result" ) end

    return response.groups
end )

-- GetUserGroupList( "STEAM_0:1:70096775" ):Then( PrintTable )

GetGroupMembers = promise.Async( function( groupName )
    local ok, result = http.Fetch( "https://steamcommunity.com/groups/" .. groupName .. "/memberslistxml/?xml=1" ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    local code = result.code
    if code ~= 200 then
        return promise.Reject( select( -1, http.GetStatusDescription( code ) ) )
    end

    local body = result.body
    if not body then return promise.Reject( "request failed, no result" ) end

    local sids = {}
    for sid64 in string.gmatch( body, "<steamID64>(%d+)</steamID64>" ) do
        sids[ #sids + 1 ] = sid64
    end

    return sids
end )

-- GetGroupMembers( "thealium" ):Then( function( tbl )
--     print( #tbl )
-- end )

GetSteamLevel = promise.Async( function( steamid )
    if string.IsSteamID( steamid ) then
        steamid = util.SteamIDTo64( steamid )
    end

    local ok, result = HTTP( {
        ["url"] = BaseURL .. "IPlayerService/GetSteamLevel/v1/",
        ["parameters"] = {
            ["key"] = apikey:GetString(),
            ["steamid"] = steamid
        }
    } ):SafeAwait()

    if not ok then return promise.Reject( result ) end

    local code = result.code
    if code ~= 200 then
        return promise.Reject( select( -1, http.GetStatusDescription( code ) ) )
    end

    local body = result.body
    if not body then return promise.Reject( "request failed, no result" ) end

    local tbl = util.JSONToTable( body )
    if not tbl then return promise.Reject( "not JSON is returned, probably an error in API accessing" ) end

    local response = tbl.response
    if not response then return promise.Reject( "no response expected" ) end

    return response.player_level
end )

-- GetSteamLevel( "STEAM_0:1:70096775" ):Then( print )

ResolveVanityURL = promise.Async( function( vanityurl, url_type )
    local ok, result = HTTP( {
        ["url"] = BaseURL .. "ISteamUser/ResolveVanityURL/v1/",
        ["parameters"] = {
            ["vanityurl"] = string.gsub( string.gsub( vanityurl, "https?://steamcommunity%.com/%w+/", "" ), "[/\\]*", "" ),
            ["url_type"] = url_type or PROFILE,
            ["key"] = apikey:GetString()
        }
    } ):SafeAwait()

    if not ok then return promise.Reject( result ) end

    local code = result.code
    if code ~= 200 then
        return promise.Reject( select( -1, http.GetStatusDescription( code ) ) )
    end

    local body = result.body
    if not body then return promise.Reject( "request failed, no result" ) end

    local tbl = util.JSONToTable( body )
    if not tbl then return promise.Reject( "not JSON is returned, probably an error in API accessing" ) end

    local response = tbl.response
    if not response then return promise.Reject( "no response expected" ) end
    if response.success ~= 1 then return promise.Reject( "no result" ) end

    return response.steamid
end )

-- ResolveVanityURL( "https://steamcommunity.com/id/PrikolMen/" ):Then( print )

HasVAC = promise.Async( function( steamid )
    if string.IsSteamID( steamid ) then
        steamid = util.SteamIDTo64( steamid )
    end

    local ok, result = http.Fetch( "https://steamcommunity.com/profiles/" .. steamid .. "/?xml=1" ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    local code = result.code
    if code ~= 200 then
        return promise.Reject( select( -1, http.GetStatusDescription( code ) ) )
    end

    local body = result.body
    if not body then return promise.Reject( "request failed, no result" ) end

    return string.match( body, "<vacBanned>(%d)</vacBanned>" ) == "1"
end )

-- HasVAC( "STEAM_0:0:116629321" ):Then( function( has )
--     print( "tr", has )
-- end )

-- HasVAC( "STEAM_0:1:70096775" ):Then( function( has )
--     print( "pr", has )
-- end )

GetFriendList = promise.Async( function( steamid, relationship )
    if string.IsSteamID( steamid ) then
        steamid = util.SteamIDTo64( steamid )
    end

    local ok, result = HTTP( {
        ["url"] = string.format( "%sISteamUser/GetFriendList/v0001/?key=%s&steamid=%s&relationship=%s&format=json", BaseURL, apikey:GetString(), steamid, relationship or "friend" ),
        ["type"] = "application/json"
    } ):SafeAwait()

    if not ok then return promise.Reject( result ) end

    local code = result.code
    if code ~= 200 then
        return promise.Reject( select( -1, http.GetStatusDescription( code ) ) )
    end

    local body = result.body
    if not body then return promise.Reject( "request failed, no result" ) end

    local tbl = util.JSONToTable( body )
    if not tbl then return promise.Reject( "not JSON is returned, probably an error in API accessing" ) end

    return tbl.friendslist.friends
end )

-- GetFriendList( "STEAM_0:1:95980398" ):Then( PrintTable )

GetAchievements = promise.Async( function( steamid, appid )
    if string.IsSteamID( steamid ) then
        steamid = util.SteamIDTo64( steamid )
    end

    local ok, result = HTTP( {
        ["url"] = string.format( "%sISteamUserStats/GetPlayerAchievements/v0001/?key=%s&steamid=%s&appid=%s", BaseURL, apikey:GetString(), steamid, appid ),
        ["type"] = "application/json"
    } ):SafeAwait()

    if not ok then return promise.Reject( result ) end

    local code = result.code
    if code ~= 200 then
        return promise.Reject( select( -1, http.GetStatusDescription( code ) ) )
    end

    local body = result.body
    if not body then return promise.Reject( "request failed, no result" ) end

    local tbl = util.JSONToTable( body )
    if not tbl then return promise.Reject( "not JSON is returned, probably an error in API accessing" ) end

    return tbl.playerstats
end )

-- GetAchievements( "76561198100459279", 4000 ):Then( PrintTable )

GetOwnedGames = promise.Async( function( steamid, include_appinfo, include_played_free_games, appids_filter )
    if string.IsSteamID( steamid ) then
        steamid = util.SteamIDTo64( steamid )
    end

    local ok, result = HTTP( {
        ["url"] = BaseURL .. "IPlayerService/GetOwnedGames/v1/",
        ["parameters"] = {
            ["include_played_free_games"] = include_played_free_games == true,
            ["include_appinfo"] = include_appinfo == true,
            ["appids_filter"] = appids_filter,
            ["key"] = apikey:GetString(),
            ["steamid"] = steamid
        }
    } ):SafeAwait()

    if not ok then return promise.Reject( result ) end

    local code = result.code
    if code ~= 200 then
        return promise.Reject( select( -1, http.GetStatusDescription( code ) ) )
    end

    local body = result.body
    if not body then return promise.Reject( "request failed, no result" ) end

    local tbl = util.JSONToTable( body )
    if not tbl then return promise.Reject( "not JSON is returned, probably an error in API accessing" ) end

    local response = tbl.response
    if not response then return promise.Reject( "no response expected" ) end

    return {
        ["count"] = response.game_count,
        ["games"] = response.games
    }
end )

-- GetOwnedGames( "STEAM_0:1:70096775" ):Then( function( result )
--     print( result.games, result.count )
-- end )

GetOwnedGame = promise.Async( function( steamid, appid, include_appinfo, include_played_free_games )
    if string.IsSteamID( steamid ) then
        steamid = util.SteamIDTo64( steamid )
    end

    if type( appid ) ~= "number" then
        appid = tonumber( appid )
    end

    if type( appid ) ~= "number" then return promise.Reject( "invalid appid" ) end

    local ok, result = GetOwnedGames( steamid, include_appinfo, include_played_free_games ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    for _, app in ipairs( result.games ) do
        if app.appid == appid then return app end
    end
end )

-- GetOwnedGame( "STEAM_0:1:70096775", "4000" ):Then( PrintTable )

GetGarrysMod = promise.Async( function( steamid, include_appinfo )
    local ok, result = GetOwnedGame( steamid, 4000, include_appinfo ):SafeAwait()
    if not ok then return promise.Reject( result ) end
    return result
end )

-- GetGarrysMod( "STEAM_0:1:70096775" ):Then( PrintTable )

GetGarrysModHours = promise.Async( function( steamid )
    local ok, result = GetGarrysMod( steamid ):SafeAwait()
    if not ok then return promise.Reject( result ) end
    return math_Round( result.playtime_forever / 60, 1 )
end )

-- GetGarrysModHours( "STEAM_0:1:70096775" ):Then( print )