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
    self.wndMain = nil
    self.strPlayerSearch = ""   -- Player name searched in lower case used for searching.
    self.bFind = false          -- Boolean to halt searching.
    self.tUnique = {}           -- Table of unique player names with housing set to public.
    self.nTotalSearches = 0     -- Number of searches done.

    self.bTourOpt = false       -- Boolean to option into tour, must be true for auto-porting.
    self.strGuide = ""          -- Tour guide name, must have contents for auto-porting.
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
            self:OnHousingTourOn(nil, self.contextMenu.strTarget)
        elseif eButtonType == "BtnGuideTour" then
            self:SendHorde(nil, self.contextMenu.strTarget)
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
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
        -- Slash commands for single player use.
		Apollo.RegisterSlashCommand("HousingTour", "OnHousingTourOn", self)
		Apollo.RegisterSlashCommand("housingtour", "OnHousingTourOn", self)
        Apollo.RegisterSlashCommand("ht", "OnHousingTourOn", self)
        
        -- Slash commands for tour guide use.
        Apollo.RegisterSlashCommand("HousingTourGuide", "SendHorde", self)
        Apollo.RegisterSlashCommand("housingtourguide", "SendHorde", self)
		Apollo.RegisterSlashCommand("htg", "SendHorde", self)

		-- Do additional Addon initialization here

	end
end

-----------------------------------------------------------------------------------------------
-- HousingTour General Functions
-----------------------------------------------------------------------------------------------

-- Single player use slash commands.
-- @param strCommand        Slash command passed.
-- @param strInputPlayer    The player name to search for.
-- @param bSilent           Optional parameter, if set to true gui will not pop up.
function HousingTour:OnHousingTourOn(strCommand, strInputPlayer, bSilent)

    if bSilent == nil then
        bSilent = false
    end
    
    if not bSilent then
        self.wndMain:Invoke()
    end
    

    self.wndMain:FindChild("SearchedMsg"):SetText("Unique Properties Searched: 0")
    self.wndMain:FindChild("TourMsg"):SetText("")

    -- Alert user if they are not in player housing zone.
    if not HousingLib.IsHousingWorld() then
        self.wndMain:FindChild("StatusMsg"):SetText("You must be in player housing to use this addon.")
        return

    -- Check for player search string
    elseif strInputPlayer == nil or strInputPlayer == "" then
        self.wndMain:FindChild("StatusMsg"):SetText("Type /ht PlayerName to search for and visit a public property.")
        return

    -- Start searching.
    else
        self:PropertySearch(strInputPlayer, false)
    end
end


-- Search for player in non-public places first.
-- @param strInputPlayer    The player name to search for.
function HousingTour:PropertySearch(strInputPlayer)

    -- Custom event can be picked up by event handlers in another addon.
    Event_FireGenericEvent("HT-PropertySearch", {strSearchFor = strInputPlayer})
    
    self.strPlayerSearch = string.lower(strInputPlayer)

    -- Handle searching for yourself.
    if self.strPlayerSearch == string.lower(GameLib.GetPlayerUnit():GetName())
    or self.strPlayerSearch == "~" then
        HousingLib.RequestTakeMeHome()
        Event_FireGenericEvent("HT-PropertySearchSuccess", {strSentTo = GameLib.GetPlayerUnit():GetName(), strType = "home"})
        self.wndMain:FindChild("StatusMsg"):SetText("Welcome home.")
        if self.bTourOpt then
            self.wndMain:FindChild("TourMsg"):SetText(self.strGuide .. " has sent the tour to your place!")
        end
        return

    else

        -- Check if search is a neighbor... sound faster than random public searches.
        local arNeighbors = HousingLib.GetNeighborList()
        for index = 1, #arNeighbors do
            if string.lower(arNeighbors[index].strCharacterName) == self.strPlayerSearch then
                HousingLib.VisitNeighborResidence(arNeighbors[index].nId)
                Event_FireGenericEvent("HT-PropertySearchSuccess", {strSentTo = strInputPlayer, strType = "neighbor"})
                self.wndMain:FindChild("StatusMsg"):SetText(arNeighbors[index].strCharacterName .. " is your neighbor!")
                if self.bTourOpt then
                    self.wndMain:FindChild("TourMsg"):SetText(self.strGuide .. " has sent the tour to your neighbor " .. arNeighbors[index].strCharacterName .. ".")
                end
                return
            end
        end
   
        -- If all else fails, start the public search.
        self.wndMain:FindChild("StatusMsg"):SetText("Searching for " .. strInputPlayer .. ".")

        -- Setup global variables.
        self.tUnique = {}
        self.nTotalSearches = 0
        self.bFind = true

        -- Kick off random public property search.
        HousingLib.RequestRandomResidenceList()
        return
    end
end


-- Search for public property by player name, kicks off anytime RequestRandomResidenceList() is called.
function HousingTour:PublicPropertySearch()

	if self.bFind == false then
        return
	end
    
    -- Boolean to determine when player is found.
	local bFound = false
    
	local arResidences = HousingLib.GetRandomResidenceList()
	local i = 0
	while i < 25 do
    	i = i + 1
        local strPlayerFound = arResidences[i].strCharacterName
        self.tUnique[strPlayerFound] = 1
        if string.lower(strPlayerFound) == self.strPlayerSearch  then
            bFound = true
            self.bFind = false
            self.nTotalSearches = 0
            self.tUnique = {}
            HousingLib.RequestRandomVisit(arResidences[i].nId)
            Event_FireGenericEvent("HT-PropertySearchSuccess", {strSentTo = strInputPlayer, strType = "public"})
            self.wndMain:FindChild("StatusMsg"):SetText("You have arrived at " .. strPlayerFound .. "'s house!")
            if self.bTourOpt then
                self.wndMain:FindChild("TourMsg"):SetText(self.strGuide .. " has sent the tour to " .. strPlayerFound .. "'s property.")
            end
            return
        end
  	end
    
    -- Count properties searched so far.
    if bFound == false then
        local nUnique = 0
        for _ in pairs(self.tUnique) do 
            nUnique = nUnique + 1 
        end
        
        self.wndMain:FindChild("SearchedMsg"):SetText("Unique Properties Searched: " .. nUnique)
        self.nTotalSearches = self.nTotalSearches + 1
        i = 0
    end
    
    HousingLib.RequestRandomResidenceList()
end


-- Tour Guide use slash commands.
-- @param strCommand           
-- @param strInputPlayer    The player name to search for.
function HousingTour:SendHorde(strCommand, strInputPlayer)
    self.wndMain:Invoke()
    self.wndMain:FindChild("SearchedMsg"):SetText("Unique Properties Searched: 0")
    self.wndMain:FindChild("TourMsg"):SetText("")
    
     -- Alert user if they are not in player housing zone.
    if not HousingLib.IsHousingWorld() then
        self.wndMain:FindChild("StatusMsg"):SetText("You must be in player housing to use this addon.")
        return
    
    -- Alert user if they are not a tour guide.
    elseif string.lower(GameLib.GetPlayerUnit():GetName()) ~= string.lower(self.strGuide) then
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
            self:PropertySearch(tMsg.strSearch)
            return
        end
    end
end



-----------------------------------------------------------------------------------------------
-- HousingTourForm Functions
-----------------------------------------------------------------------------------------------
-- When the OK or Close button is clicked
function HousingTour:OnOK()
	self.wndMain:Close() -- hide the window
    self.bFind = false
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
    self.wndMain:FindChild("ChangeGuideWindow"):Show(true)

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
    self.wndMain:FindChild("ChangeGuideWindow"):Show(false)
    self.wndMain:FindChild("TourMsg"):SetText("You will be ported to public housing with " .. self.strGuide .. ".")
end


-- When the "Change Guide Close" button is clicked.
function HousingTour:OnGuideChangeClose()
    self.wndMain:FindChild("ChangeGuideWindow"):Show(false)
end



-----------------------------------------------------------------------------------------------
-- HousingTour Instance
-----------------------------------------------------------------------------------------------
local HousingTourInst = HousingTour:new()
HousingTourInst:Init()
