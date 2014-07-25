Kael's Housing Tour
===================
_Making Public Houses Public_

Please send feedback to james@geekwagon.net.

Description
-----------
Kael's Housing Tour permits users to visit public houses with a slash command or through the 
right-click of a player's name in chat or through their nameplate. It was designed for people to 
select a 'tour guide' and visit houses as a group through an opt-in feature applicable only in 
player housing. Setting a tour guide permits another user to direct your character (and an unlimited
number of others) to zone from one house to another together. This is useful for the Be My Guest 
achievement. A full description of features are listed below:


![Screenshot](http://geekwagon.net/projects/HousingTour/khtss2.png)


Why
---
It's called Kael's Housing Tour because Kaelish on Stormtalon rallied together a full raid of 
Exiles to roam  public properties. The original intention was to get the "Be My Guest I" 
achievement, but it turned out to be a fun way to see what people did with their houses. This addon
was created to make it easier for a Tour Guide to port their horde of followers to the same public
property in a short amount of time.


Install
-------
This addon can also be downloaded from [Curse](http://www.curse.com/ws-addons/wildstar/222538-kaels-housing-tour).

If downloading from GitHub be sure to download the master branch. You may need to rename the 
extracted folder from `HousingTour-master` to `HousingTour`.

After downloading, extract to the WildStar Addon directory. Usually found at 
`C:\Users\<windows user name>\AppData\Roaming\NCSOFT\WildStar\Addons`. You can also get to it 
by typing `%appdata%\NCSOFT\WildStar\Addons` into a Windows Explorer address bar or search bar.


How to Use
----------
### General Use
Right click option to **Tour Home** works in chat or on a selected player. Clicking on yourself will 
give the option **Go Home** which is what it sounds like.

Slash command `/ht` brings up the main form (see below for full list of slash commands). There is no
way to search for a player in the form (comming later). You can quickly search for a player name by 
typing; `/ht <PlayerName>`. Player name is not case sensitive.

Most people don't like to type (this is a mystery to me), so check out the **Public List** button at
the bottom of the main form. This will take a moment, but gives a list of all public properties 
(except yourself) found in your faction on the server. Clicking on a player in **Public List** will 
take you to that property. 

As of writing this, a house set to public can take up to a week before it's recognized by the server
as public.

### Joining a Tour
**Important Notice**  
This mod will automatically port you to a public house _only if_ (1) the addon is installed and 
enabled, _only if_ (2) you are in player housing, _only if_ (3) you are opted in (check box), and 
_only if_ (4) you have typed in a Tour Guide's name. Once you meet those _four_ requirements a red
message will display in the addon's window. At this point the Tour Guide can port you without 
further warning.

In case it's not intuitive; to join a tour click the "Join a Tour" check box (it's a round box).

By default there is no tour guide, you must set one with the "Change Guide" button. Type the Tour 
Guide's name (spelled correctly) into the box. This is also not case sensitve.

At this point, if you're in player housing, you've meet all the requirements in the **Important 
Notice** above and can be automatically ported by the tour guide.

### Leading a Tour
**You join a tour and set yourself as the Tour Guide.**

So, you suckered some people! I mean... got a group to tour houses (probably seeking the Be My Guest
achievement).

As a Tour Guide the right click menu option will change to "Send Tour Here". This will take you, and
everyone with you set as their tour guide, to that player's home provided it is public. Players not 
in housing will not be ported.

Tour Guides can also use the new **Public List** window. After you set yourself as a guide, player 
names clicked on in **Public List** will take the tour there.

### Options Panel
**Silent Mode** will keep the main form from popping up every time you attempt to go to a players 
house from the command line (ie `/ht PlayerName`). The form still comes up when using `/ht` or 
`/htg`. 

**Output to Chat** Will put the message (or something similar) seen in the status box in the debug
chat channel. It's not ideal, but it will give some feedback when using silent mode.

The options are saved account wide at 
`%appdata%\NCSOFT\WildStar\AddonSaveData\<wildstar account>\Kael's Housing Tour_0_Acct.xml`.

### List of Slash Commands
The following commands are available for anyone to use.
* `/HousingTour` or `/ht` Opens main form.
* `/HousingTour <PlayerName>` Port you to PlayerName's public property.
* `/ht <PlayerName>` Shorter version of previous command.
* `/ht ~` Takes you home.

These commands are only for the tour guide.
* `/HousingTourGuide <PlayerName>` Will take the tour the named player's house if it's public.
* `/htg <PlayerName>` Keyboard stroke saving alternative to previous command.
* `/htg ~` Sends all players to their respective houses.


Triggers for Other Addons
-------------------------
Other addon's can make use of Kael's Housing Tour search feature. To go to another players property
use:

    local ht = Apollo.GetAddon("HousingTour")
    ht:PropertySearch("PlayerName", [silent])

The second parameter, [silent], is an optional boolean value. If set to true the Housing Tour GUI
will not show up.

Other addons can use the following two triggers:

    Apollo.RegisterEventHandler("HT-PropertySearch", "yourFunction", self)
    
A table will be passed to your function that is `{sSearchFor = "PlayerName"}`. I know it's kind of
pointless to be a table, but this gives options for future expansion with less breakage.

    Apollo.RegisterEventHandler("HT-PropertySearchSuccess", "yourFunction", self)

This event also passes a table to your function. This one has two strings; `sSentTo` is the player
name that was searched for. The other is `sType` and it will have "home", "neighbor", or "public"
depending on the method that got the player to the property.

Here is a quick example function for both events:

    function yourFunction(tData)
        if tData.strSearchFor ~= nil then
            Print("searched for " .. tData.strSearchFor)
        end
        if tData.sSentTo ~=nil then
            Print(tData.strSentTo .. " : " .. tData.strType)
        end
        return
    end


License
-------
This addon is licensed under the MIT License (MIT) using Copyright (c) 2014 James Pryor and 
K. L. Phan, see LICENSE.txt included with this addon, or 
[read this summary](https://www.tldrlegal.com/l/mit).


For the Future
--------------
There are more features than we can write down that we'd like to add to _Housing Tour_. Here is a
short list of what is in the near future.

* ~~A context (right click) menu.~~
* ~~Event triggers to support other addons.~~
* ~~Auto stop searching after set number of non-unique property searches.~~
* ~~Keep the gui from popping up _all_ the time.~~
* ~~List of all public properties.~~

* Visual searching indicator.
* Speed dial, for example: `/ht 1` will take you to the player you've set as number 1.
* Auto neighbor speed dial, for example: `/ht n1` will take you to your first neighbor... in some
  order.
* More awesome public search.
* Announce Be My Guest achievement to tour.
* History of where the tour went, so people can go back and see the cool things again.


Change Log
----------
### 2014-07-18
Initial release.

### 2014-07-19
* Triggers added.

### 2014-07-25
* Slight visual improvements.
* Searching for public property will now auto stop after 1000 searches if no more unique properties
  are found.
* Added an options panel with two whole options!
* Option: **Silent Mode** allows you to visit properties from the command line without the main form
  poping up all the time.
* Option: **Output to Chat**, in case silent mode is too quiet.
* Public list... just go play with it. It's awesome.






