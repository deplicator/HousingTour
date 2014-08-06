Kael's Housing Tour
-------------------

### Description
List all public properties and makes it easier to visit them.

Create a tour group that makes the Be My Guest achievement easier to obtain.

Supported by [Neighbor Notes](http://www.curse.com/ws-addons/wildstar/221450-neighbor-notes).

![Screenshot](http://geekwagon.net/projects/HousingTour/khtss2.png)

#### Download
* [Curse](http://www.curse.com/ws-addons/wildstar/222538-kaels-housing-tour)
* [GitHub](https://github.com/deplicator/HousingTour/releases/tag/v2)

#### Install
After downloading, extract to the WildStar Addon directory (default is 
`%appdata%\NCSOFT\WildStar\Addons`).

If necessary rename the extracted folder to `HousingTour`.


### How to Use
Adds right click options **Tour Home** on other players and **Go Home** for you.

Search for public property with `/ht <PlayerName>` (see below for full list of slash commands).

**Public List** brings up a list of all public properties, visit them by click on player name.

#### Join a Tour
**Important Notice**: This mod can automatically port you without notice _only if_ (1) you are in 
player housing, _only if_ (2) you are opted in (check box), and _only if_ (3) you have typed in a 
Tour Guide's name. Once you meet those requirements the Tour Guide can port you without further 
warning.

In case it's not intuitive; to join a tour click the **Join a Tour** check box (it's a round box).

You must set a tour guide with the "Change Guide" button. This is not case sensitive.

#### Lead a Tour
To lead a tour, click **Join a Tour** and set yourself as the tour guide.

So, you suckered some people! I mean... got a group to tour houses (probably seeking the Be My Guest
achievement).

As a Tour Guide the right click menu option will change to **Send Tour Here**. This will take you, 
and everyone in housing with you as their guide, to that player's home provided it is public.

Tour Guides can also use the new **Public List** window. After you set yourself as a guide, player 
names clicked on in **Public List** will take the tour there.

#### Options
**Silent Mode** keeps the main form opening when visiting a property from slash command. It still 
opens with `/ht`.

**Output to Chat** puts the message seen in the main form in the debug chat channel.

**Search Intensity** is the number of searches for public properties when no more unique properties 
are found. Higher numbers means longer search. The default of 1000 usually works just fine, but 
crank it up if you think it's not finding someone.

The options are saved account wide at 
`%appdata%\NCSOFT\WildStar\AddonSaveData\<wildstar account>\Kael's Housing Tour_0_Acct.xml`.

#### List of Slash Commands
The following commands are available for anyone to use.
* `/HousingTour` or `/ht` Opens main form.
* `/HousingTour <PlayerName>` Port you to PlayerName's public property.
* `/ht <PlayerName>` Shorter version of previous command.
* `/ht ~` Takes you home.
* `/ht pl` Opens Public List.

These commands are only for the tour guide.
* `/HousingTourGuide <PlayerName>` Will take the tour the named player's house if it's public.
* `/htg <PlayerName>` Keyboard stroke saving alternative to previous command.
* `/htg ~` Sends all players to their respective houses.


### License
This addon is licensed under the MIT License (MIT) using Copyright (c) 2014 James Pryor and 
K. L. Phan, see LICENSE.txt included with this addon, or 
[read this summary](https://www.tldrlegal.com/l/mit).

Please send feedback to <mailto:james@geekwagon.net>.

----------------------------------------------------------------------------------------------------

### Change Log

#### 2014-07-18  
* Initial release.

#### 2014-07-19  
* Triggers added.

#### 2014-07-25 | _v2 Free hugs with every purchase._
* Slight visual improvements.
* Searching for public property will now auto stop after 1000 searches if no more unique properties
  are found.
* Added an options panel with two whole options!
* Option: **Silent Mode** allows you to visit properties from the command line without the main form
  popping up all the time.
* Option: **Output to Chat**, in case silent mode is too quiet.
* Public list... just go play with it. It's awesome.

#### 2014-??-?? | _v3 Oh my, look at all this work we have left to do._
* Option: **Search Intensity** is the number of searches for public properties done when no more
  unique properties are found.
* New slash command to go strait to Public List, `/ht pl`,
* Added "working" indicator to Public List.
* Added `/home` as an alternative to `/ht ~`. In the future it will take you home even if not in
  housing (by way of Recall - House), but it doesn't appear to possible with the current api.
* Change right click menu so it only shows up while in a housing zone, and only on players.
* Public List now shows any property you have access to (like non-public neighbors and yourself).
* Public List is searchable!





  