Kael's Housing Tour
===================
This is still a very early version, please let me know of bugs at james@geekwagon.net.

**Important Notice**
This mod will automatically port you to a public house _only if_ (1) the addon is installed and 
enabled, _only if_ (2) you are in player housing, _only if_ (3) you are opted in (check box), and 
_only if_ (4) you have typed in a Tour Guide's name. Once you meet those _four_ requirements a red
message will display in the addon's window. At this point the Tour Guide can port you without 
further warning.

![Screenshot](http://geekwagon.net/projects/HousingTour/khtss.png)

Why
---
It's called Kael's Housing Tour because Kaelish on Stormtalon rallied together a full raid of 
Exiles to roam  public properties. The original intention was to get the "Be My Guest I" 
achievement, but it turned out to be a fun way to see what people did with their houses. This addon
was created to make it easier for a Tour Guide to port their horde of followers to the same public
property in a short amount of time.

Also note the author of this addon has an affinity for the command line. As a side effect the slash 
commands tend to be tested more throughly than the gui.


Install
-------
This addon can also be downloaded from [Curse](http://www.curse.com/ws-addons/wildstar/222538-kaels-housing-tour).

If downloading from GitHub be sure to download the master branch. You may need to rename the 
extracted folder from `HousingTour-master` to `HousingTour`.

After downloading, extract to the WildStar Addon directory. Usually found at 
`C:\Users\<your windows user name>\AppData\Roaming\NCSOFT\WildStar\Addons`. You can also get to it 
by typing `%appdata%\NCSOFT\WildStar\Addons` into a Windows Explorer address bar or search bar.


How to Use
----------
### General Use
After installing this addon, clicking on a selected player's nameplate or a player's name in chat 
will give the option to "Tour Home". If you are in the player housing zone, this will immediately 
take you to that player's house if they are your neighbor or it will start a search of public 
housing for that player.

Clicking on yourself will give the option "Go Home" which is exactly what it sounds like.

* `/HousingTour <PlayerName>` Take you to PlayerName's public property. Without a PlayerName the
  addon window will open. PlayerName is not case sensitive.
* `/ht <PlayerName>` Shorter version of previous command.
* `/ht ~` Sends you home.

It's a safe bet once the Unique Properties Searched number stops increasing, the house you are 
looking for isn't public or doesn't exist. This is also a decent estimate of the number of public 
properties available to your faction on your server. 

As of writing this, a house set to public can take up to a week before it's recognized by the 
server as public.
 
In case it's not intuitive; to join a tour click the "Join a Tour" check box (it's a round box).

You can change the Tour Guide with the "Change Guide" button. You'll have to type the Tour Guide's 
name (spelled correctly), but it's not case sensitive.


### As a Guide
**You join a tour and set yourself as the Tour Guide.**

As a Tour Guide the right click menu option "Tour Home" will change to "Send Tour Here". This will 
take you, and everyone with you set as their tour guide, to that player's home. Players not in 
housing will not be ported.

* `/HousingTourGuide <PlayerName>` Will take you and anyone else in the housing zone with you set 
  as their Tour Guide to the named player's house if it's public.
* `/htg <PlayerName>` Keyboard stroke saving alternative to previous command.
* `/htg ~` Sends all players to their respective houses.


### Now with an Option
The silent mode check box will keep the main form from popping up every time you do a 
`/ht PlayerName` search. The form will still come up when you type `/ht` or `/htg`. The option is
saved account wide.

Maybe in the future we'll have two options.


### With other Addon's
Other addon's can make use of Kael's Housing Tour search feature. To go to another players property
use:

    local ht = Apollo.GetAddon("HousingTour")
    ht:PropertySearch("PlayerName", [silent])

The second parameter, [silent], is an optional boolean value. If set to true the Housing Tour GUI
will not show up.

Other addons can get use the following two triggers:

    Apollo.RegisterEventHandler("HT-PropertySearch", "yourFunction", self)
    
A table will be passed to your function that is `{strSearchFor = "PlayerName"}`. I know it's kind of
pointless to be a table, but this gives options for future expansion with less breakage.

    Apollo.RegisterEventHandler("HT-PropertySearchSuccess", "yourFunction", self)

This event also passes a table to your function. This one has two strings; `strSentTo` is the player
name that was searched for. The other is `strType` and it will have "home", "neighbor", or "public"
depending on the method that got the player to the property.

Here is a quick example function for both events:

    function yourFunction(tData)
        if tData.strSearchFor ~= nil then
            Print("searched for " .. tData.strSearchFor)
        end
        if tData.strSentTo ~=nil then
            Print(tData.strSentTo .. " : " .. tData.strType)
        end
        return
    end



License
-------
This addon is licensed under the MIT License (MIT) using Copyright (c) 2014 James Pryor and 
K.L. Phan, see LICENSE.txt included with this addon, or 
[read this summary](https://www.tldrlegal.com/l/mit).


For the Future
--------------
There are more features than we can write down that we'd like to add to _Housing Tour_. Here is a
short list of what is in the near future.

* ~~A context (right click) menu.~~
* ~~Event triggers to support other addons.~~
* ~~Auto stop searching after set number of non-unique property searches.~~
* ~~Keep the gui from popping up _all_ the time~~

* Visual searching indicator.
* Speed dial, for example: `/ht 1` will take you to the player you've set as number 1.
* Auto neighbor speed dial, for example: `/ht n1` will take you to your first neighbor... in some
  order.
* More awesome public search.
* History of where the tour went, so people can go back and see the cool things again.
