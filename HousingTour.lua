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

    -- When single player commands are used, start search.
    if string.lower(strCommand) == "housingtour" or string.lower(strCommand) == "ht" then
        self:PropertySearch(strInputPlayer, self.tOptions['bSilentMode'])

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
    if strInputPlayer == "pl" then
        self.wndPublicList:Show(true)
        self.strPlayerSearch = "pl"
        self.tPublicList = {}
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
        Event_FireGenericEvent("HT-PropertySearchSuccess",
                               {strSentTo = GameLib.GetPlayerUnit():GetName(),
                                strType = "home"})
        self.wndMain:FindChild("StatusMsg"):SetText("Welcome home.")

        -- Command line output.
        if(self.tOptions['bCmdLineOut']) then Print("Arriving at your property.") end

        -- Tour message.
        if self.bTourOpt then
            self.wndMain:FindChild("TourMsg"):SetText(self.strGuide .. " has sent the tour to your place!")
        end

        return

    -- Check if search is a neighbor... sound faster than random public searches.
    else
        local tNeighbors = HousingLib.GetNeighborList()
        for index = 1, #tNeighbors do
            if string.lower(tNeighbors[index].strCharacterName) == self.strPlayerSearch then
                HousingLib.VisitNeighborResidence(tNeighbors[index].nId)
                Event_FireGenericEvent("HT-PropertySearchSuccess",
                                       {strSentTo = strInputPlayer,
                                        strType = "neighbor"})
                self.wndMain:FindChild("StatusMsg"):SetText(tNeighbors[index].strCharacterName .. " is your neighbor!")

                -- Command line output.
                if(self.tOptions['bCmdLineOut']) then Print("Arriving at: " .. tNeighbors[index].strCharacterName .. "'s property.") end

                -- Tour message.
                if self.bTourOpt then
                    self.wndMain:FindChild("TourMsg"):SetText(self.strGuide .. " has sent the tour to your neighbor " .. tNeighbors[index].strCharacterName .. ".")
                end

                return
            end
        end

        -- If all else fails, start the public search.
        self.wndMain:FindChild("StatusMsg"):SetText("Searching for " .. strInputPlayer .. ".")

        -- Command line output.
        if(self.tOptions['bCmdLineOut']) then Print("Searching for " .. strInputPlayer .. ".") end

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

        -- Public list window.
        local publicfound = self.wndPublicList:FindChild("PublicFound")
        -- Remove previous results.
        publicfound:DestroyChildren()
        -- Temporary array used to sort self.tPublicList by key.
        local aTemp = {}
        -- Populate temp array with correct order.
        for key in pairs(self.tPublicList) do
            table.insert(aTemp, key)
        end
        table.sort(aTemp)

        -- Populate public list window from temp array.
        for index, name in ipairs(aTemp) do
            local wndPublicListItem = Apollo.LoadForm(self.xmlDoc, "PublicListItem", publicfound, self)
            wndPublicListItem:FindChild("PublicListButton"):SetText(name)
        end
        publicfound:SetText("")
        
        publicfound:ArrangeChildrenVert()
        return
	end

    -- Boolean to determine when player is found.
	local bFound = false

    -- GetRandomResidenceList always returns 25 random residences (as far as I can tell).
	local tResidences = HousingLib.GetRandomResidenceList()
    for i = 1, 25 do
        local strPlayerFound = tResidences[i].strCharacterName
        local nIdFound = tResidences[i].nId

        -- Add found player Public List table and window.
        if self.tPublicList[strPlayerFound] == nil then
            self.tPublicList[strPlayerFound] = 1
            self.nRepeteNumber = 0
        else
            self.nRepeteNumber = self.nRepeteNumber + 1
        end

        -- Player property found as public property, go there.
        if string.lower(strPlayerFound) == self.strPlayerSearch then
            bFound = true
            self.bFind = false
            self.nTotalSearches = 0
            self.tPublicList = {}
            self.nRepeteNumber = 0
            HousingLib.RequestRandomVisit(tResidences[i].nId)
            Event_FireGenericEvent("HT-PropertySearchSuccess",
                                   {strSentTo = strPlayerFound,
                                    strType = "public"})
            self.wndMain:FindChild("StatusMsg"):SetText("You have arrived at " .. strPlayerFound .. "'s house!")

            -- Command line output.
            if(self.tOptions['bCmdLineOut']) then Print("Arriving at: " .. strPlayerFound .. "'s property.") end

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

        self.wndMain:FindChild("SearchedMsg"):SetText("Unique Properties Found: " .. nUnique)
        self.nTotalSearches = self.nTotalSearches + 1

        if self.nRepeteNumber > self.tOptions.nAutoStop then
            Event_FireGenericEvent("HT-PropertySearchTimeout",
                                   {strSearchFor = self.strPlayerSearch})
            if self.strPlayerSearch ~= "pl" then
                self.wndMain:FindChild("StatusMsg"):SetText("Stopped search for " .. self.strPlayerSearch .. ". The last " .. self.tOptions.nAutoStop .. " searches found no more unique properties. The player doesn't exist or is not set to public.")
                if(self.tOptions['bCmdLineOut']) then Print("Gave up searching for " .. self.strPlayerSearch .. ".") end
            else
                self.wndMain:FindChild("StatusMsg"):SetText("Public list is done.")
                self.wndPublicList:FindChild("PublicListWorking"):Show(false)
            end

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

-- Save addon options, should always be called with 2.
function HousingTour:OnSave(tSaveType)
    if tSaveType == GameLib.CodeEnumAddonSaveLevel.Account then
        local tSave = self.tOptions
        return tSave
    else
        return
    end
end

-- Restore addon options.
function HousingTour:OnRestore(tSaveType, tData)
    self.tOptions = tData
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

-- When the "Public List" button is clicked.
function HousingTour:OnPublicList()
    self.wndPublicList:Invoke()
    self:PropertySearch("pl")
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
-- PublicListForm Functions
-----------------------------------------------------------------------------------------------
-- When the close button is clicked on the public list window.
function HousingTour:OnPublicListClose()
    self.wndPublicList:Close()
end

-- Clicking on a name in the public list
function HousingTour:OnPublicListButton(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
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

-----------------------------------------------------------------------------------------------
-- HousingTour Instance
-----------------------------------------------------------------------------------------------
local HousingTourInst = HousingTour:new()
HousingTourInst:Init()
