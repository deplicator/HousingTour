For Other Addon Developers
--------------------------

Other addon's can make use of Kael's Housing Tour search feature. To go to another players property
use:

    local ht = Apollo.GetAddon("HousingTour")
    ht:PropertySearch("PlayerName", [silent])

The second parameter, [silent], is an optional boolean value. If set to true the Housing Tour GUI
will not show up.

Other addons can use the following three triggers:

    Apollo.RegisterEventHandler("HT-PropertySearch", "yourFunction", self)
    
A table will be passed to your function that is `{strSearchFor = "PlayerName"}`. I know it's kind of
pointless to be a table, but this gives options for future expansion with less breakage.

    Apollo.RegisterEventHandler("HT-PropertySearchSuccess", "yourFunction", self)

This event also passes a table to your function. This one has two strings; `strSentTo` is the player
name that was searched for. The other is `strType` and it will have "home", "neighbor", or "public"
depending on the method that got the player to the property.

Finally there is a trigger for when the search times out. It passes the same table as 
HT-PropertySearch.

    Apollo.RegisterEventHandler("HT-PropertySearchTimeout", "yourFunction", self)


Here is a quick example of yourFunction:

    function yourFunction(tData)
        if tData.strSearchFor ~= nil then
            Print("searched for " .. tData.strSearchFor)
        end
        if tData.sSentTo ~=nil then
            Print(tData.strSentTo .. " : " .. tData.strType)
        end
        return
    end