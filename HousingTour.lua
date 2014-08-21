-----------------------------------------------------------------------------------------------
-- Client Lua Script for HousingTour
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "string"
require "Unit"
require "FriendshipLib"
require "HousingLib"

-----------------------------------------------------------------------------------------------
-- HousingTour Module Definition
-----------------------------------------------------------------------------------------------
local HousingTour = {}

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function HousingTour:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- initialize variables here
    self.wndMain = nil          -- Main form.
    self.wndAvailableList = nil -- Available Properties form
    self.wndHistoryForm = nil   -- Form that shows where you've been.
    
    self.strPlayerSearch = ""   -- Player name searched in lower case used for searching.
    self.bFind = false          -- Boolean to halt searching.
    self.tAvailableList = {}    -- Table of unique player names with housing set to public.
    self.nTotalSearches = 0     -- Number of searches done.
    self.nRepeteNumber = 0      -- Number of searches done when nothing unique added to tAvailableList.

    self.bTourOpt = false       -- Boolean to option into tour, must be true for auto-porting.
    self.strGuide = ""          -- Tour guide name, must have contents for auto-porting.

    self.tHistory = {}          -- Table for where your characters have been.
    self.tOptions = {}          -- Table for saved options.
    return o
end

function HousingTour:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end


-----------------------------------------------------------------------------------------------
-- HousingTour OnLoad
-----------------------------------------------------------------------------------------------
function HousingTour:OnLoad()

	self.xmlDoc = XmlDoc.CreateFromFile("HousingTour.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
    self.contextMenu = Apollo.GetAddon("ContextMenuPlayer")

    self:ContextMenuCheck()

    Apollo.RegisterEventHandler("HousingRandomResidenceListRecieved", "PublicPropertySearch", self)
    Apollo.RegisterEventHandler("TargetUnitChanged", "ContextMenuCheck", self)
    --Apollo.RegisterEventHandler("VarChange_ZoneName", "OnChangeZoneName", self)
    Apollo.RegisterEventHandler("SubZoneChanged", "OnZoneChange", self)
    
    -- Custom Sprites
    Apollo.LoadSprites("HousingTourSprites.xml", "HousingTourSprites")

    -- Change channel name for testing.
    self.htChannel = ICCommLib.JoinChannel("KaelsHousingTour-live", "OnIncomingMessage", self)

end


-----------------------------------------------------------------------------------------------
-- HousingTour OnDocLoaded
-----------------------------------------------------------------------------------------------
function HousingTour:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "HousingTourForm", nil, self)
        self.wndAvailableList = Apollo.LoadForm(self.xmlDoc, "AvailableListForm", nil, self)
        self.wndHistoryForm = Apollo.LoadForm(self.xmlDoc, "HistoryForm", nil, self)

		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load Housing Tour form.")
			return
		end

        if self.wndAvailableList == nil then
            Apollo.AddAddonErrorText(self, "Could not load Available List Form.")
            return
        end
        
        if self.wndHistoryForm == nil then
            Apollo.AddAddonErrorText(self, "Could not load History Form.")
            return
        end

	    self.wndMain:Show(false, true)
        self.wndAvailableList:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil

		-- Register handlers for events, slash commands and timer, etc.
		Apollo.RegisterSlashCommand("HousingTour", "OnHousingTourOn", self)
		Apollo.RegisterSlashCommand("housingtour", "OnHousingTourOn", self)
        Apollo.RegisterSlashCommand("HT", "OnHousingTourOn", self)
        Apollo.RegisterSlashCommand("ht", "OnHousingTourOn", self)
        Apollo.RegisterSlashCommand("HousingTourGuide", "OnHousingTourOn", self)
        Apollo.RegisterSlashCommand("housingtourguide", "OnHousingTourOn", self)
		Apollo.RegisterSlashCommand("HTG", "OnHousingTourOn", self)
		Apollo.RegisterSlashCommand("htg", "OnHousingTourOn", self)
		Apollo.RegisterSlashCommand("Home", "OnHousingTourOn", self)
		Apollo.RegisterSlashCommand("home", "OnHousingTourOn", self)

        -- Set defaults and restore saved options.
        if self.tOptions.bSilentMode == nil then self.tOptions.bSilentMode = false end
        self.wndMain:FindChild('SilentModeCheckbox'):SetCheck(self.tOptions['bSilentMode'])
        
        if self.tOptions.bCmdLineOut == nil then self.tOptions.bCmdLineOut = false end
        self.wndMain:FindChild('CmdLineOutCheckbox'):SetCheck(self.tOptions['bCmdLineOut'])
        
        if self.tOptions.nAutoStop == nil then self.tOptions.nAutoStop = 1000 end
        self.wndMain:FindChild("SearchIntesityTextBox"):SetText(self.tOptions.nAutoStop)
        self.wndMain:FindChild('AutoStopSliderBar'):SetValue(self.tOptions.nAutoStop)

 	end
end

-----------------------------------------------------------------------------------------------
-- HousingTour General Functions
-----------------------------------------------------------------------------------------------

-- When slash command are used.
-- @param strCommand        Slash command used to call.
-- @param strInputPlayer    The player name to search for.
function HousingTour:OnHousingTourOn(strCommand, strInputPlayer)

    -- Show main form.
    self.wndMain:Invoke()

    -- Alert user if they are not in player housing zone.
    if not HousingLib.IsHousingWorld() then
        self.wndMain:FindChild("StatusMsg"):SetText("You must be in player housing to use this addon.")

        -- Command line output.
        if(self.tOptions['bCmdLineOut']) then Print("You must be in player housing to use this addon.") end
        return
    end
    
    if string.lower(strCommand) == "home" then
        self:PropertySearch("~", self.tOptions['bSilentMode'])
        return
    end

    -- When single player commands are used, start search.
    if string.lower(strCommand) == "housingtour" or string.lower(strCommand) == "ht" then
        self:PropertySearch(strInputPlayer, self.tOptions['bSilentMode'])
        return
        
    -- When tour guide commands are used.
    elseif string.lower(strCommand) == "housingtourguide" or string.lower(strCommand) == "htg" then

        -- Initial messages.
        self.wndMain:FindChild("SearchedMsg"):SetText("Unique Properties Found: 0")

        -- Player is not a tour guide.
        if string.lower(GameLib.GetPlayerUnit():GetName()) ~= string.lower(self.strGuide) then
            self.wndMain:FindChild("StatusMsg"):SetText("Type /ht PlayerName to search for and visit a public property.")
            self.wndMain:FindChild("TourMsg"):SetText("You are not a tour guide.")
            return

        -- Check for player search string
        elseif strInputPlayer == nil or strInputPlayer == "" then
            self.wndMain:FindChild("StatusMsg"):SetText("Type /htg PlayerName to search for and visit a public property.")
            return

        -- Send message to the masses to begin search!
        else
            self.wndMain:FindChild("StatusMsg"):SetText("Sending tour to " .. strInputPlayer .. ".")
            local tToSend = {}
            tToSend["strGuide"] = self.strGuide
            tToSend["strSearch"] = strInputPlayer
            self.htChannel:SendMessage(tToSend)     -- send message data to others
            self:OnIncomingMessage(nil, tToSend)    -- send message data to self
            return
        end
    end
end


-- Search for player in non-public places first. This is also where outside should hook in.
-- @param strInputPlayer    The player name to search for.
-- @param [bSilent]         If set to true main form will not pop up.
function HousingTour:PropertySearch(strInputPlayer, bSilent)

    -- Set optional bSilent parameter if not present.
    if bSilent == nil then
        bSilent = false
    end

    -- Initial messages.
    self.wndMain:FindChild("SearchedMsg"):SetText("No search initiated.")
    self.wndMain:FindChild("TourMsg"):SetText("")
    
    -- Get strait to making public list.
    if strInputPlayer == "al" or strInputPlayer == "pl" then
        self.wndAvailableList:Show(true)
        self.strPlayerSearch = "al"
        self.tAvailableList = {}
        self.nTotalSearches = 0
        self.bFind = true
        HousingLib.RequestRandomResidenceList()
        self.wndMain:Show(not bSilent or self.bTourOpt)
        self.wndMain:FindChild("StatusMsg"):SetText("Please wait a moment while public list is created.")
        return
    end

    -- Hide main form if bSilent set to true. Main form will always show while on a tour.
    self.wndMain:Show(not bSilent or self.bTourOpt)

    -- Check for player search string.
    if strInputPlayer == nil or strInputPlayer == "" then
        self.wndMain:Show(true) -- If no search string is passed always show main form.
        if self.wndMain:FindChild("StatusMsg"):GetText() == "" then
            self.wndMain:FindChild("StatusMsg"):SetText("Type /ht PlayerName to search for and visit a player's property.")
        end
        return
    end

    -- Custom event trigger for beginning of search.
    Event_FireGenericEvent("HT-PropertySearch", {strSearchFor = strInputPlayer})

    -- Set normalized search string.
    self.strPlayerSearch = string.lower(strInputPlayer)

    -- Handle searching for yourself.
    if self.strPlayerSearch == string.lower(GameLib.GetPlayerUnit():GetName())
    or self.strPlayerSearch == "~" then
        HousingLib.RequestTakeMeHome()
        self:PostTravel(GameLib.GetPlayerUnit():GetName(), "home")
        return

    -- Check if search is a neighbor... sound faster than random public searches.
    else
        local tNeighbors = HousingLib.GetNeighborList()
        for index = 1, #tNeighbors do
            if string.lower(tNeighbors[index].strCharacterName) == self.strPlayerSearch then
                HousingLib.VisitNeighborResidence(tNeighbors[index].nId)
                self:PostTravel(strInputPlayer, "neighbor")
                return
            end
        end

        -- If all else fails, start the public search.
        self.wndMain:FindChild("StatusMsg"):SetText("Searching for " .. strInputPlayer .. ".")

        -- Command line output.
        if(self.tOptions['bCmdLineOut']) then Print("Searching for " .. strInputPlayer .. ".") end

        -- Setup global variables.
        self.tAvailableList = {}
        self.nTotalSearches = 0
        self.bFind = true

        -- Kick off random public property search.
        HousingLib.RequestRandomResidenceList()
        return
    end
end


-- Search for public property by player name, kicks off anytime RequestRandomResidenceList() is
-- called.
function HousingTour:PublicPropertySearch()

    local tNeighbors = HousingLib.GetNeighborList()

	if not self.bFind then
        -- and non-public neighbors to list
        for index in pairs(tNeighbors) do
            if self.tAvailableList[tNeighbors[index].strCharacterName] == nil then
                self.tAvailableList[tNeighbors[index].strCharacterName] = {}
                self.tAvailableList[tNeighbors[index].strCharacterName].strResidenceName = ""
                self.tAvailableList[tNeighbors[index].strCharacterName].strRelation = "neighbor"
                self.tAvailableList[tNeighbors[index].strCharacterName].bPublic = false
            end
        end
        -- add yourself to the list
        if self.tAvailableList[GameLib.GetPlayerUnit():GetName()] == nil then
            self.tAvailableList[GameLib.GetPlayerUnit():GetName()] = {}
            self.tAvailableList[GameLib.GetPlayerUnit():GetName()].strResidenceName = ""
            self.tAvailableList[GameLib.GetPlayerUnit():GetName()].strRelation = "yourself"
            self.tAvailableList[GameLib.GetPlayerUnit():GetName()].bPublic = false
        end
        self:PopulateAvailableList()
        return
	end

    -- Boolean to determine when player is found.
	local bFound = false

    -- GetRandomResidenceList always returns 25 random residences (as far as I can tell).
	local tResidences = HousingLib.GetRandomResidenceList()
    for i = 1, 25 do
        local strPlayerFound = tResidences[i].strCharacterName

        -- Add found player to Public List table.
        if self.tAvailableList[strPlayerFound] == nil then
            self.tAvailableList[strPlayerFound] = {}
            self.tAvailableList[strPlayerFound].strResidenceName = tResidences[i].strResidenceName
            self.tAvailableList[strPlayerFound].bPublic = true
            self.tAvailableList[strPlayerFound].strRelation = "none"
            
            -- If relation to neighbor if they are a neighbor.
            for index = 1, #tNeighbors do
                if tNeighbors[index].strCharacterName == strPlayerFound then
                    self.tAvailableList[strPlayerFound].strRelation = "neighbor"
                end
            end
            
            self.nRepeteNumber = 0
        else
            self.nRepeteNumber = self.nRepeteNumber + 1
        end

        -- Player property found as public property, go there.
        if string.lower(strPlayerFound) == self.strPlayerSearch then
            bFound = true
            self.bFind = false
            self.nTotalSearches = 0
            self.tAvailableList = {}
            self.nRepeteNumber = 0
            HousingLib.RequestRandomVisit(tResidences[i].nId)
            self:PostTravel(strPlayerFound, "public")            
            return
        end
  	end

    -- Count properties searched so far.
    if not bFound then
        local nUnique = 0
        for _ in pairs(self.tAvailableList) do
            nUnique = nUnique + 1
        end

        self.wndMain:FindChild("SearchedMsg"):SetText("Unique Properties Found: " .. nUnique)
        self.nTotalSearches = self.nTotalSearches + 1

        if self.nRepeteNumber > self.tOptions.nAutoStop then
            Event_FireGenericEvent("HT-PropertySearchTimeout",
                                   {strSearchFor = self.strPlayerSearch})
            if self.strPlayerSearch ~= "al" then
                self.wndMain:FindChild("StatusMsg"):SetText("Stopped search for " .. self.strPlayerSearch .. ". The last " .. self.tOptions.nAutoStop .. " searches found no more unique properties. The player doesn't exist or is not set to public.")
                if(self.tOptions['bCmdLineOut']) then Print("Gave up searching for " .. self.strPlayerSearch .. ".") end
            else
                self.wndMain:FindChild("StatusMsg"):SetText("Public list is done.")
                self.wndAvailableList:FindChild("AvailableListWorking"):Show(false)
            end

            self.bFind = false
        end
    end

    HousingLib.RequestRandomResidenceList()
end


-- After traveling, do these things.
function HousingTour:PostTravel(strSentTo, strType, strZone)
        
        if(strType ~= "outside") then
            Event_FireGenericEvent("HT-PropertySearchSuccess", {strSentTo = strSentTo, strType = strType})
        end
                                
        if(strType == "home") then
            self.wndMain:FindChild("StatusMsg"):SetText("Welcome home.")

            -- Command line output.
            if(self.tOptions['bCmdLineOut']) then Print("Arriving at your property.") end
            
            -- Tour message.
            if self.bTourOpt then
                self.wndMain:FindChild("TourMsg"):SetText(self.strGuide .. " has sent the tour to your place!")
            end
            
        elseif(strType == "neighbor") then
            self.wndMain:FindChild("StatusMsg"):SetText(strSentTo .. " is your neighbor!")
            
            -- Command line output.
            if(self.tOptions['bCmdLineOut']) then Print("Arriving at: " .. strSentTo .. "'s property.") end

            -- Tour message.
            if self.bTourOpt then
                self.wndMain:FindChild("TourMsg"):SetText(self.strGuide .. " has sent the tour to your neighbor " .. strSentTo .. ".")
            end

        elseif(strType == "public") then
            self.wndMain:FindChild("StatusMsg"):SetText("You have arrived at " .. strSentTo .. "'s house!")

            -- Command line output.
            if(self.tOptions['bCmdLineOut']) then Print("Arriving at: " .. strSentTo .. "'s property.") end

            -- Tour message.
            if self.bTourOpt then
                self.wndMain:FindChild("TourMsg"):SetText(self.strGuide .. " has sent the tour to " .. strSentTo .. "'s property.")
            end
        end

        -- update history table
        self.tHistory[self:FormatCurrentTimeSortable()] = {self:FormatCurrentTime(),            -- easy to read time
                                                           GameLib.GetPlayerUnit():GetName(),   -- who you visited on
                                                           strSentTo,                           -- who you visited
                                                           strType,                             -- relation
                                                           GameLib.GetCurrentZoneMap().strName, -- zone
                                                           strZone}                             -- subzone? 

end


-- Update public list with initial results and search results.
function HousingTour:PopulateAvailableList(strSearchString)
    
    if strSearchString == nil then
        strSearchString = ""
    end
    
	local bSearchString = string.len(strSearchString) > 0
	self.wndAvailableList:FindChild("SearchClearBtn"):Show(bSearchString)

    -- Available  list window.
    local availablefound = self.wndAvailableList:FindChild("AvailableFound")
    
    -- Remove previous results.
    availablefound:DestroyChildren()
    
    -- Temporary array used to sort self.tAvailableList by key.
    self.arTemp = {}
    
    -- Populate temp array with correct order and limited by search string.
    for key in pairs(self.tAvailableList) do
        if bSearchString and key:lower():find(strSearchString:lower(), 1, true) then
            table.insert(self.arTemp, key)
        elseif not bSearchString then
            table.insert(self.arTemp, key)
        end
    end
    
    -- Sort list
    table.sort(self.arTemp)
    
    -- Populate available list window from temp array.
    for index, name in ipairs(self.arTemp) do
        local wndAvailableListItem = Apollo.LoadForm(self.xmlDoc, "AvailableListItem", availablefound, self)

        wndAvailableListItem:FindChild("AvailableListButton"):SetText(name)
        wndAvailableListItem:FindChild("AvailableListButton"):SetTooltip(self.tAvailableList[name].strResidenceName)
        if self.tAvailableList[name].strRelation == "neighbor" then
            wndAvailableListItem:FindChild("StatusBox"):SetText("n")
            wndAvailableListItem:FindChild("StatusBox"):SetTooltip("This is your neighbor.")
        elseif self.tAvailableList[name].strRelation == "yourself" then
            wndAvailableListItem:FindChild("StatusBox"):SetText("y")
            wndAvailableListItem:FindChild("StatusBox"):SetTooltip("This is you.")
        else
            wndAvailableListItem:FindChild("StatusBox"):SetText("p")
            wndAvailableListItem:FindChild("StatusBox"):SetTooltip("This property is public.")
        end
    end
    
    availablefound:SetText("")
    availablefound:ArrangeChildrenVert()
end


-- Multi-check to be sure the user wants to be part of a housing tour and auto-ported around. Return
-- false if any check is not met, and true if all are met.
function HousingTour:AutoPortCheck()

    -- Player in housing zone.
    if not HousingLib.IsHousingWorld() then
        return false

    -- Joint a tour checkbox is checked.
    elseif not self.bTourOpt then
        return false

    -- Guide named must not be blank.
    elseif self.strGuide == "" or self.strGuide == nil then
        return false

    -- If three conditions are met, return true.
    else
        return true

    end
end


-- Handle incoming messages from other clients.
function HousingTour:OnIncomingMessage(channel, tMsg)

    -- User must meet all auto port requirements to join a tour.
    if self:AutoPortCheck() then

        -- Tour guide set must match guide in message.
        if string.lower(tMsg.strGuide) == string.lower(self.strGuide) then
            self.wndMain:Invoke()
            self.wndMain:FindChild("TourMsg"):SetText(tMsg.strGuide .. " is attempting to send you to " .. tMsg.strSearch .. "'s property.")
            self:PropertySearch(tMsg.strSearch, false)
            return
        end
    end
end


-- Add an extra button to the player context menu
function HousingTour:ContextMenuCheck()
    local oldRedrawAll = self.contextMenu.RedrawAll
    
    self.contextMenu.RedrawAll = function(context)
        -- Check if right clicking on player
        if self.contextMenu.unitTarget == nil or self.contextMenu.unitTarget:IsACharacter() then
            -- check if in housing 
            if self.contextMenu.wndMain ~= nil and HousingLib.IsHousingWorld() then
                local wndButtonList = self.contextMenu.wndMain:FindChild("ButtonList")
                if wndButtonList ~= nil then
                    local wndNew = wndButtonList:FindChildByUserData("BtnHousingTour")

                    if not wndNew then
                        wndNew = Apollo.LoadForm(self.contextMenu.xmlDoc, "BtnRegular", wndButtonList, self.contextMenu)
                        if string.lower(self.strGuide) == string.lower(GameLib.GetPlayerUnit():GetName()) then
                            wndNew:SetData("BtnGuideTour")
                            wndNew:FindChild("BtnText"):SetText("Send Tour Here")
                        else
                            wndNew:SetData("BtnHousingTour")
                            if self.contextMenu.strTarget == GameLib.GetPlayerUnit():GetName() then
                                wndNew:FindChild("BtnText"):SetText("Go Home")
                            else
                                wndNew:FindChild("BtnText"):SetText("Tour Home")
                            end
                        end
                    end
                end
            end
        end
        oldRedrawAll(context)
    end

    -- catch the event fired when the player clicks the context menu
    local oldContextClick = self.contextMenu.ProcessContextClick
    self.contextMenu.ProcessContextClick = function(context, eButtonType)
        if eButtonType == "BtnHousingTour" then
            self:OnHousingTourOn('ht', self.contextMenu.strTarget)
        elseif eButtonType == "BtnGuideTour" then
            self:OnHousingTourOn('htg', self.contextMenu.strTarget)
        else
            oldContextClick(context, eButtonType)
        end
    end
    
end


-- Returns sortable time format string
function HousingTour:FormatCurrentTimeSortable()
    local tTime = GameLib.GetLocalTime()
    local strSortTime = string.format("%04d%02d%02d%02d%02d%02d", tTime.nYear, tTime.nMonth, tTime.nDay, tTime.nHour, tTime.nMinute, tTime.nSecond)
    return strSortTime
end


-- Returns an easier to read time format string
function HousingTour:FormatCurrentTime()
    local nYear = GameLib.GetLocalTime().nYear
    local arMonths = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
    local strMonth = arMonths[GameLib.GetLocalTime().nMonth]
    local nDay = GameLib.GetLocalTime().nDay
    local strTime = GameLib.GetLocalTime().strFormattedTime
    return strMonth .. " " .. nDay .. ", " .. nYear .. " " .. strTime
end


-- Log when player move and not using Housing Tour
-- This only seems to be called when the subzone text shows up on the screen. That doesn't always
-- happen when visiting other properties. No idea why.
function HousingTour:OnZoneChange(oVar, strZone)
    self:PostTravel(nil, "outside", strZone)
end


-- Update history form from history table.
function HousingTour:RefreshHistory()
    -- History form.
    local historyForm = self.wndHistoryForm:FindChild("Background")
    
    -- Remove previous results.
    historyForm:DestroyChildren()
    
    local arTempHistory = {}
    
    -- Populate temp array with correct order and limited by search string.
    for key in pairs(self.tHistory) do
        table.insert(arTempHistory, key)
    end
    
    -- Sort list decending
    table.sort(arTempHistory, function(a, b) return a > b end)

    
    -- Populate history form
    local colorhelps = true -- because modulus won't work
    
    for index, timestamp in ipairs(arTempHistory) do    
        if(self.tHistory[timestamp][5] == "Housing Skymap" and self.tHistory[timestamp][3] ~= nul) then
            local wndHistoryItem = Apollo.LoadForm(self.xmlDoc, "HistoryItem", historyForm, self)
            wndHistoryItem:FindChild("when"):SetText(self.tHistory[timestamp][1])
            wndHistoryItem:FindChild("what"):SetText(self.tHistory[timestamp][2] .. " visits " .. self.tHistory[timestamp][3])
            if(colorhelps) then
                wndHistoryItem:SetBGColor(ff310000)
                colorhelps = false
            else
                colorhelps = true
            end
        end
        
    end
    historyForm:ArrangeChildrenVert()
end


-- Save addon options, should always be called with 2.
function HousingTour:OnSave(tSaveType)
    local tSave = {}
    if tSaveType == GameLib.CodeEnumAddonSaveLevel.Account then
        tSave.tOptions = self.tOptions
        tSave.tHistory = self.tHistory
        return tSave
    else
        return
    end
end


-- Restore addon options.
function HousingTour:OnRestore(tSaveType, tData)
    self.tOptions = tData.tOptions
    self.tHistory = tData.tHistory
end


-----------------------------------------------------------------------------------------------
-- HousingTourForm Functions
-----------------------------------------------------------------------------------------------
-- When the OK or Close button is clicked.
function HousingTour:OnOK()
    self:OnSave(2)
	self.wndMain:Close()
    self.wndMain:FindChild("OptionsForm"):Show(false)
    self.wndMain:FindChild("OptionsCheckbox"):SetCheck(false)
end

-- When the Options box is checked.
function HousingTour:OnOptionsCheck()
    self.wndMain:FindChild("OptionsForm"):Show(true)
end

-- When the Options box is UNchecked.
function HousingTour:OnOptionsUncheck()
    self.wndMain:FindChild("OptionsForm"):Show(false)
    self:OnSave(2)
end

-- When the "Stop Searching" button is clicked.
function HousingTour:OnStopSearching()
    self.bFind = false
    self.wndMain:FindChild("StatusMsg"):SetText("Search stopped. Use /ht PlayerName to search again.")
end

-- When "Join a Tour" is checked.
function HousingTour:OnTourOptIn()
    self.wndMain:FindChild("GuideTextBox"):SetText(self.strGuide)
    self.wndMain:FindChild("ChangeGuideBtnBlock"):Show(false)
    self.bTourOpt = true
    if self.strGuide == "" then
        self.wndMain:FindChild("TourMsg"):SetText("You must choose a tour guide.")
    else
        self.wndMain:FindChild("TourMsg"):SetText("You will be ported to public housing with " .. self.strGuide .. ".")
    end
end

-- When "Join a Tour" is unchecked.
function HousingTour:OnTourOptOut()
    self.strGuide = ""
    self.wndMain:FindChild("GuideTextBox"):SetText("")
    self.wndMain:FindChild("ChangeGuideBtnBlock"):Show(true)
    self.bTourOpt = false
    self.wndMain:FindChild("TourMsg"):SetText("")
end

-- When "Change Guide" button is clicked.
function HousingTour:OnChangeGuide()
    self.wndMain:FindChild("ChangeGuideForm"):Show(true)

    if self.strGuide == "" then
        self.wndMain:FindChild("ChangeGuideBox"):SetText("Kaelish")
    else
        self.wndMain:FindChild("ChangeGuideBox"):SetText(self.strGuide)
    end
end

-- When the "Change Guide Submit" button is clicked.
function HousingTour:OnGuideChangeSubmit()
    self.strGuide = self.wndMain:FindChild("ChangeGuideBox"):GetText()
    self.wndMain:FindChild("GuideTextBox"):SetText(self.strGuide)
    self.wndMain:FindChild("ChangeGuideForm"):Show(false)
    self.wndMain:FindChild("TourMsg"):SetText("You will be ported to public housing with " .. self.strGuide .. ".")
end

-- When the "Change Guide Close" button is clicked.
function HousingTour:OnGuideChangeClose()
    self.wndMain:FindChild("ChangeGuideForm"):Show(false)
end

-- When the "The List" button is clicked.
function HousingTour:OnAvailableList()
    self.wndAvailableList:Invoke()
    self:PropertySearch("al")
end

-- History button
function HousingTour:OnHistoryFormOpen()
    self:RefreshHistory()
    self.wndHistoryForm:Invoke()
end


-- Options Panel --
-- bSilentMode Mode checkbox.
function HousingTour:OnSilentModeCheck()
    self.tOptions['bSilentMode'] = true
end

function HousingTour:OnSilentModeUncheck()
    self.tOptions['bSilentMode'] = false
end

-- Command Line Output checkbox.
function HousingTour:OnCmdLineOutCheck()
    self.tOptions['bCmdLineOut'] = true
end

function HousingTour:OnCmdLineOutUncheck()
    self.tOptions['bCmdLineOut'] = false
end

function HousingTour:OnAutoStopSliderChanged(wndHandler, wndControl)
    self.tOptions.nAutoStop = wndHandler:GetValue()
    self.wndMain:FindChild("SearchIntesityTextBox"):SetText(wndHandler:GetValue())
end


-----------------------------------------------------------------------------------------------
-- AvailableListForm Functions
-----------------------------------------------------------------------------------------------
-- When the close button is clicked on the public list window.
function HousingTour:OnAvailableListClose()
    self.wndAvailableList:Close()
end

-- Clicking on a name in the public list
function HousingTour:OnAvailableListButton(wndHandler, wndControl)
	-- You are not the tour guide
    if string.lower(self.strGuide) ~= string.lower(GameLib.GetPlayerUnit():GetName()) then
        self:PropertySearch(wndHandler:GetText(), self.tOptions['bSilentMode'])
    else
        self.wndMain:FindChild("StatusMsg"):SetText("Sending tour to " .. wndHandler:GetText() .. ".")
        local tToSend = {}
        tToSend["strGuide"] = self.strGuide
        tToSend["strSearch"] = wndHandler:GetText()
        self.htChannel:SendMessage(tToSend)     -- send message data to others
        self:OnIncomingMessage(nil, tToSend)    -- send message data to self
        return
    end
end

-- Typing in search box
function HousingTour:OnSearchBoxChanged(wndHandler, wndControl)
	self:PopulateAvailableList(self.wndAvailableList:FindChild("SearchBox"):GetText())
end

-- Clear search results
function HousingTour:OnSearchClearBtn()
    self:PopulateAvailableList()
end

-----------------------------------------------------------------------------------------------
-- HistoryForm Functions
-----------------------------------------------------------------------------------------------
function HousingTour:OnHistoryCloseButton(wndHandler, wndControl, eMouseButton)
	self.wndHistoryForm:Show(false)	
end


-----------------------------------------------------------------------------------------------
-- HousingTour Instance
-----------------------------------------------------------------------------------------------
local HousingTourInst = HousingTour:new()
HousingTourInst:Init()
