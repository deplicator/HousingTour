Kael's Housing Tour
===================
This is still a very early version, please let me know of bugs at james@geekwagon.net.

**Important Notice**
This mod will automatically port you to a public house _only if_ (1) the addon is enabled, _only 
if_ (2) you are in player housing, _only if_ (3) you are opted in (check box), and _only if_ (4) 
you have typed in a Tour Guide's name. Once you meet those _four_ requirements a bright red message
will display in the addon's window and in your chat debug. At this point the Tour Guide can port 
you without further warning.


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
Will add more detailed instructions based on where this addon is available for download.

Download and unzip to your WildStar Addon directory. Usually found at 
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
* `/ht ~` Sends Player to their house.

It's a safe bet once the Unique Properties Searched number maxes out, the house you are looking for
doesn't exist or isn't listed as public. This is also a decent estimate of the number of public 
properties available to your faction on your server. 

As of writing this, a house set to public can take up to a week before it's recognized by the 
server as public.
 
In case it's not intuitive; to join a tour click the "Join a Tour" check box (it's a round box).

You can change the Tour Guide with the "Change Guide" button. You'll have to type the Tour Guide's 
name (spelled correctly), but it's not case sensitive.


### As a Guide
It should be noted you'll have to join your own tour and set yourself as the Tour Guide.

As a Tour Guide the right click menu option "Tour Home" will change to "Send Tour Here". This will 
take you, and everyone with you set as their tour guide, to that player's home. Players not in 
housing will not be ported.

* `/HousingTourGuide <PlayerName>` Will take you and anyone else in the housing zone with you set 
  as their Tour Guide to the named player's house if it's public.
* `/htg <PlayerName>` Keyboard stroke saving alternative to previous command.
* `/htg ~` Sends all Players to their respective houses.


License
-------
The MIT License (MIT) Copyright (c) 2014 James Pryor (geekwagon.net) and K.L. Phan (klphan.com), see
LICENSE.txt included with this addon, or [read this summary](https://www.tldrlegal.com/l/mit).


For the Future
--------------
There are more features than we can write down that I'd like to add to _Housing Tour_. Here is a
short list of what we'd like to add in the near future.

* A right clickable list of everyone in the tour (at least for the guide)
* Speed dial, for example: `/ht 1` will take you to the player you've set as number 1.
* Auto neighbor speed dial, for example: `/ht n1` will take you to your first neighbor... in some
  order.
* History of where the tour went, so people can go back and see the cool things again.

