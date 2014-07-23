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
    self.strPlayerSearch = ""   -- Player name searched in lower case used for searching.
    self.bFind = false          -- Boolean to halt searching.
    self.tPublicList = {}       -- Table of unique player names with housing set to public.
    self.nTotalSearches = 0     -- Number of searches done.
    self.nRepeteNumber = 0      -- Number of searches done when nothing unique added to tPublicList.

    self.bTourOpt = false       -- Boolean to option into tour, must be true for auto-porting.
    self.strGuide = ""          -- Tour guide name, must have contents for auto-porting.
    
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

    -- Add an extra button to the player context menu
    local oldRedrawAll = self.contextMenu.RedrawAll
    self.contextMenu.RedrawAll = function(context)
        if self.contextMenu.wndMain ~= nil then
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

    Apollo.RegisterEventHandler("HousingRandomResidenceListRecieved", "PublicPropertySearch", self)

    -- Change channel name for testing.
    self.htChannel = ICCommLib.JoinChannel("KaelsHousingTour-live", "OnIncomingMessage", self)
    
end


-----------------------------------------------------------------------------------------------
-- HousingTour OnDocLoaded
-----------------------------------------------------------------------------------------------
function HousingTour:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "HousingTourForm", nil, self)
        self.wndPublicList = Apollo.LoadForm(self.xmlDoc, "PublicListForm", nil, self)
        
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end

        if self.wndPublicList == nil then
            Apollo.AddAddonErrorText(self, "Could not load the show all window for some reason.")
            Print("error")
            return
        end

	    self.wndMain:Show(false, true)
        self.wndPublicList:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil

		-- Register handlers for events, slash commands and timer, etc.
		Apollo.RegisterSlashCommand("HousingTour",      "OnHousingTourOn", self)
		Apollo.RegisterSlashCommand("housingtour",      "OnHousingTourOn", self)
        Apollo.RegisterSlashCommand("HT",               "OnHousingTourOn", self)
        Apollo.RegisterSlashCommand("ht",               "OnHousingTourOn", self)
        Apollo.RegisterSlashCommand("HousingTourGuide", "OnHousingTourOn", self)
        Apollo.RegisterSlashCommand("housingtourguide", "OnHousingTourOn", self)
		Apollo.RegisterSlashCommand("HTG",              "OnHousingTourOn", self)
		Apollo.RegisterSlashCommand("htg",              "OnHousingTourOn", self)

        -- Set defaults and restore saved options.
        if self.tOptions.bSilentMode == nil then self.tOptions.bSilentMode = false end
        if self.tOptions.bCmdLineOut == nil then self.tOptions.bCmdLineOut = false end
        self.wndMain:FindChild('SilentModeCheckbox'):SetCheck(self.tOptions['bSilentMode'])
        self.wndMain:FindChild('CmdLineOutCheckbox'):SetCheck(self.tOptions['bCmdLineOut'])
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

    -- When single player commands are used, start search.
    if string.lower(strCommand) == "housingtour" or string.lower(strCommand) == "ht" then
        self:PropertySearch(strInputPlayer, self.tOptions['bSilentMode'])

    -- When tour guide commands are used.
    elseif string.lower(strCommand) == "housingtourguide" or string.lower(strCommand) == "htg" then

        -- Initial messages.
        self.wndMain:FindChild("SearchedMsg"):SetText("Unique Properties Searched: 0")

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
            self.wndMain:FindChild("StatusMsg"):SetText("Sending horde to " .. strInputPlayer .. ".")
            local tToSend = {}
            tToSend["strGuide"] = self.strGuide
            tToSend["strSearch"] = strInputPlayer
            self:OnIncomingMessage(nil, tToSend)    -- send message data to self
            self.htChannel:SendMessage(tToSend)     -- send message data to others
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
    self.wndMain:FindChild("StatusMsg"):SetText("")
    self.wndMain:FindChild("SearchedMsg"):SetText("Search not required.")
    self.wndMain:FindChild("TourMsg"):SetText("")

    -- Hide main form if bSilent set to true. Main form will always show while on a tour.
    self.wndMain:Show(not bSilent or self.bTourOpt)

    -- Alert user if they are not in player housing zone.
    if not HousingLib.IsHousingWorld() then
        self.wndMain:FindChild("StatusMsg"):SetText("You must be in player housing to use this addon.  ")
        
        -- Command line output.
        if(self.tOptions['bCmdLineOut']) then Print("You must be in player housing to use this addon.") end
    end
    
    -- Check for player search string.
    if strInputPlayer == nil or strInputPlayer == "" then
        self.wndMain:Show(true) -- If no search string is passed always show main form.
        self.wndMain:FindChild("StatusMsg"):SetText(self.wndMain:FindChild("StatusMsg"):GetText() .. "Type /ht PlayerName to search for and visit a public property.")
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
        Event_FireGenericEvent("HT-PropertySearchSuccess",
                               {strSentTo = GameLib.GetPlayerUnit():GetName(),
                                strType = "home"})
        self.wndMain:FindChild("StatusMsg"):SetText("Welcome home.")
        
        -- Command line output.
        if(self.tOptions['bCmdLineOut']) then Print("Arriving at: " .. GameLib.GetPlayerUnit():GetName()) end

        -- Tour message.
        if self.bTourOpt then
            self.wndMain:FindChild("TourMsg"):SetText(self.strGuide .. " has sent the tour to your place!")
        end

        return
    else

        -- Check if search is a neighbor... sound faster than random public searches.
        local tNeighbors = HousingLib.GetNeighborList()
        for index = 1, #tNeighbors do
            if string.lower(tNeighbors[index].strCharacterName) == self.strPlayerSearch then
                HousingLib.VisitNeighborResidence(tNeighbors[index].nId)
                Event_FireGenericEvent("HT-PropertySearchSuccess",
                                       {strSentTo = strInputPlayer,
                                        strType = "neighbor"})
                self.wndMain:FindChild("StatusMsg"):SetText(tNeighbors[index].strCharacterName .. " is your neighbor!")
                
                -- Command line output.
                if(self.tOptions['bCmdLineOut']) then Print("Arriving at: " .. tNeighbors[index].strCharacterName) end

                -- Tour message.
                if self.bTourOpt then
                    self.wndMain:FindChild("TourMsg"):SetText(self.strGuide .. " has sent the tour to your neighbor " .. tNeighbors[index].strCharacterName .. ".")
                end

                return
            end
        end

        -- If all else fails, start the public search.
        self.wndMain:FindChild("StatusMsg"):SetText("Searching for " .. strInputPlayer .. ".")

        -- Setup global variables.
        self.tPublicList = {}
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

	if not self.bFind then
        return
	end

    -- Boolean to determine when player is found.
	local bFound = false

    -- GetRandomResidenceList always returns 25 random residences (as far as I can tell).
	local tResidences = HousingLib.GetRandomResidenceList()
    for i = 1, 25 do
        local strPlayerFound = tResidences[i].strCharacterName
        local nIdFound = tResidences[i].nId

        -- Add found player to a table.
        if self.tPublicList[strPlayerFound] == nil then
            self.tPublicList[strPlayerFound] = 1
            self.nRepeteNumber = 0
        else
            self.nRepeteNumber = self.nRepeteNumber + 1
        end
        
        -- Player property found as public property, go there.
        if string.lower(strPlayerFound) == self.strPlayerSearch  then
            bFound = true
            self.bFind = false
            self.nTotalSearches = 0
            self.tPublicList = {}
            self.nRepeteNumber = 0
            HousingLib.RequestRandomVisit(tResidences[i].nId)
            Event_FireGenericEvent("HT-PropertySearchSuccess",
                                   {strSentTo = strInputPlayer,
                                    strType = "public"})
            self.wndMain:FindChild("StatusMsg"):SetText("You have arrived at " .. strPlayerFound .. "'s house!")
            
            -- Tour message.
            if self.bTourOpt then
                self.wndMain:FindChild("TourMsg"):SetText(self.strGuide .. " has sent the tour to " .. strPlayerFound .. "'s property.")
            end
            return
        end
  	end

    -- Count properties searched so far.
    if not bFound then
        local nUnique = 0
        for _ in pairs(self.tPublicList) do
            nUnique = nUnique + 1
        end

        self.wndMain:FindChild("SearchedMsg"):SetText("Unique Properties Searched: " .. nUnique)
        self.nTotalSearches = self.nTotalSearches + 1

        if self.nRepeteNumber > 5000 then
            Event_FireGenericEvent("HT-PropertySearchTimeout",
                                   {strSearchFor = strInputPlayer})
            self.wndMain:FindChild("StatusMsg"):SetText("Auto Stop: The last 5,000 searches found no more unique properties. You are probably not going to find it.")
            self.bFind = false
        end
    end

    HousingLib.RequestRandomResidenceList()
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


function HousingTour:OnSave(tSaveType)
    
    if tSaveType == GameLib.CodeEnumAddonSaveLevel.Account then
        Print(tSaveType)
        Print(GameLib.CodeEnumAddonSaveLevel.Account)
        
        local tSave = self.tOptions
        return tSave
    else
        return
    end
end


function HousingTour:OnRestore(tSaveType, tData)
    Print("data loaded")
    self.tOptions = tData
end


-----------------------------------------------------------------------------------------------
-- HousingTourForm Functions
-----------------------------------------------------------------------------------------------
-- When the OK or Close button is clicked.
function HousingTour:OnOK()
    self:OnSave(2)
	self.wndMain:Close()
    self.wndPublicList:Close()
    self.wndMain:FindChild("OptionsForm"):Show(false)
    self.wndMain:FindChild("OptionsCheckbox"):SetCheck(false)
    self.bFind = false
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

-- When the "Show All" button is clicked.
function HousingTour:OnPublicList()
    self.wndPublicList:Invoke()
end

-- When the close button is clicked on the public list window.
function HousingTour:OnPublicListClose()
    self.wndPublicList:Close()
end


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


-----------------------------------------------------------------------------------------------
-- HousingTour Instance
-----------------------------------------------------------------------------------------------
local HousingTourInst = HousingTour:new()
HousingTourInst:Init()
