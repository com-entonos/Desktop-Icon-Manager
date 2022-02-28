
-- G.J. Parker (c) 2021
-- simple AppleScript routines for dealing w/ icons on desktop

script ApplescriptBridge
    
    property parent : class "NSObject"
    property iconSet : {}         -- this data is shared w/ swift app- swift doesn't know what it is and we don't care
    property numDesktop : {}      -- just the number of items on the the Desktop, swift wants to know to update some user info
    property numArrangement : {}  -- just the number of items stored in iconSet, swift wants to know to update some user info
    
    property iconWindows : {}     -- list of Finder window that are in icon view
    property getWindows : {}      -- list of Finder window names that are in icon view
    property saveWindowBounds = false   -- should a Finder window remember it's size?
    property saveWindowPosition = false -- should a Finder window remember it's position?
    property tWindow = missing value    -- working Finder window, it's up to AppleScript to keep track
    
    on rememorize()  -- we're going to update iconSet
        if count of iconSet > 0 then   -- do we have a valid iconSet?
            if count of iconSet < 6 then    -- are we updating iconSet for Desktop?
                set tWindow to missing value
                memorize()
            else                            -- updating iconSet for a Finder window
                setTWindow()                    -- find window
                if tWindow is missing value then
                    beep                        -- can't find window, abort
                else                            -- determine if we should save Finder window position and/or size
                    if (count of iconSet > 6) then -- either position or size or both are stored
                        set saveWindowPosition to (count of iconSet > 7 or count of (item 7 of iconSet) < 3) -- either both position and size or just position
                        set saveWindowBounds to (count of iconSet > 7 or count of (item 7 of iconSet) > 2)   -- either both position and size or just size
                    else
                        set saveWindowPosition to false
                        set saveWindowBounds to false
                    end if
                    memorize()  -- found window, go memorize
                end if
            end if
        else
            beep -- should never happen
        end if
    end rememorize
    
    on memorize() -- memorize icon name/positions (and screen size, icon size and text size)
        if tWindow is missing value then -- save Desktop
            tell application "Finder" -- go get names, positions, current screen size, icon size and text size...
                set iconNames to name of items of desktop
                set iconPositions to desktop position of items of desktop
                copy the bounds of the desktop's window to the screenSize
                set iconSize to icon size of (icon view options of desktop's window)
                set textSize to text size of (icon view options of desktop's window)
            end tell
            set iconSet to {iconNames, iconPositions, screenSize, iconSize, textSize} -- array of arrays
        else -- save Finder window pointed to by tWindow
            tell application "Finder"
                copy the bounds of the desktop's window to the screenSize
                copy the bounds of tWindow to windowBounds
                copy the position of tWindow to windowPosition
                set iconNames to name of items of tWindow
                set iconPositions to position of items of tWindow
                set iconSize to icon size of (icon view options of tWindow)
                set textSize to text size of (icon view options of tWindow)
                set aliasWindow to posix path of (target of tWindow as alias) -- /path/to/folder
                -- set aliasWindow to (target of tWindow) as text  -- VOLUME:Path:To:Folder:
                -- set aliasWindow to target of tWindow  -- errors
            end tell
            set iconSet to {iconNames, iconPositions, screenSize, iconSize, textSize, aliasWindow}
            if saveWindowPosition then set end of iconSet to windowPosition
            if saveWindowBounds then set end of iconSet to windowBounds
        end if
        set numDesktop to (count of iconNames)  -- we have this, might as well store it
        copy numDesktop to numArrangement
    end memorize

    on listWindows()
        set getWindows to {}
        set iconWindows to {}
        tell application "Finder"
            repeat with w in (Finder windows whose current view is icon view) as list
                set end of iconWindows to w
                set end of getWindows to w's name
            end repeat
        end tell
    end listWindows
    
    to targetWindow() -- return index of iconWindows that tWindow points to, otherwise return 0
        repeat with x from 1 to count of iconWindows
            if tWindow = item x of iconWindows then return x
        end repeat
        return 0
    end targetWindow

    to setTargetWindow:idx  -- set tWindow to item idx of iconWindows, otherwise set to 'missing value'
        set tWindow to missing value
        if idx as integer < 1 or idx as integer > count of iconWindows then return  -- 'idx as integer < 1 or' is bug fix for 4.0.1
        tell application "Finder"
            set tWindow to (item (idx as integer) of iconWindows)
            try
                set x to position of tWindow
            on error
                set tWindow to missing value
            end try
        end tell
    end setTargetWindow

    on setTWindow()  -- set tWindow to posix path of item 6 of iconSet
        tell application "Finder"
            repeat with w in (Finder windows whose current view is icon view) as list -- loop through all Finder windows that are in icon view
                if posix path of (target of w as alias) as text is item 6 of iconSet as text then -- is this window pointing to posix path of iconSet?
                    copy w to tWindow
                    return
                end if
            end repeat
        end tell
        set tWindow to missing value -- not present
    end setTWindow
    
    on restore() -- given iconSet, restore Desktop icons to the correct postions (along w/ icon size and text size). if screen size changed, scale the postions
        if count of iconSet > 0 then
            set iconNames to item 1 of iconSet
            set iconPositions to item 2 of iconSet
            set screenSize to item 3 of iconSet
            set iconSize to item 4 of iconSet
            set textSize to item 5 of iconSet
            set numArrangement to (count of iconNames) -- might as well store it
            
            if count of iconSet < 6 then        -- we're doing the Desktop?
                tell application "Finder"           -- find current screen size and get rid of arranged by if screen size changed
                    copy the bounds of the desktop's window to the newScreenSize -- get current resolution
                    if arrangement of (icon view options of desktop's window) ­ not arranged and newScreenSize ­ screenSize then
                        set arrangement of (icon view options of desktop's window) to not arranged -- we have to turn off Snap to Grid or whatever else if resolution changed
                    end if
                    set newIconSize to icon size of (icon view options of desktop's window)
                    set newTextSize to text size of (icon view options of desktop's window)
                end tell
                
                if iconSize ­ newIconSize  then -- if icon sizes change, change it back (may require a Finder restart)
                    ignoring application responses
                        tell application "Finder" to set icon size of (icon view options of desktop's window) to iconSize as integer
                    end ignoring
                end if
                
                if textSize ­ newTextSize then -- if text sizes change, change it back (may require a Finder restart)
                    ignoring application responses
                        tell application "Finder" to set text size of (icon view options of desktop's window) to textSize as integer
                    end ignoring
                end if
                
                set newdx to item 1 of newScreenSize as integer -- scaling parameters incase screen size changed
                set newdy to item 2 of newScreenSize as integer
                set xrel to ((item 3 of newScreenSize as integer) - newdx) / ((item 3 of screenSize as integer) - (item 1 of screenSize as integer))
                set yrel to ((item 4 of newScreenSize as integer) - newdy) / ((item 4 of screenSize as integer) - (item 2 of screenSize as integer))
                
                repeat with i from 1 to number of items of iconNames -- for each desktop icon, compute and put back at the old position
                    ignoring application responses
                        tell application "Finder" to set desktop position of item (item i of iconNames as string) of desktop to {newdx + (0.5 + ((item 1 of (item i of iconPositions)) as integer - newdx) * xrel) div 1, newdy + (0.5 + ((item 2 of (item i of iconPositions)) as integer - newdy) * yrel) div 1} -- new position
                    end ignoring
                end repeat
            else                                    -- we're restoring a Finder window
                setTWindow()                            -- find Finder window...
                if tWindow is missing value then        -- no such window open in icon view, so let's make one
                    tell application "Finder"
                        try
                            set tWindow to make new Finder window
                            set target of tWindow to posix file (item 6 of iconSet as text)  -- (POSIX file p as text)
                            set current view of tWindow to icon view
                        on error
                            tell application "Finder" to close tWindow
                            set tWindow to missing value
                        end try
                    end tell
                end if
                if tWindow is missing value then  -- if no such posix path exists, beep and get out
                    beep
                else
                    tell application "Finder" -- find current screen size and get rid of arranged by if screen size changed
                        copy the bounds of the desktop's window to the newScreenSize -- get current resolution
                        copy the position of tWindow to pos  -- set pos to actual position in case we don't need to change it
                        set newIconSize to icon size of (icon view options of tWindow)
                        set newTextSize to text size of (icon view options of tWindow)
                    end tell
                    
                    if iconSize as integer ­ newIconSize as integer  then -- if icon sizes change, change it back (may require a Finder restart)
                        ignoring application responses
                            tell application "Finder" to set icon size of (icon view options of tWindow) to iconSize as integer
                        end ignoring
                    end if
                    
                    if textSize as integer ­ newTextSize as integer then -- if text sizes change, change it back (may require a Finder restart)
                        ignoring application responses
                            tell application "Finder" to set text size of (icon view options of tWindow) to textSize as integer
                        end ignoring
                    end if
                    
                    set newdx to item 1 of newScreenSize as integer -- scaling parameters incase screen size changed
                    set newdy to item 2 of newScreenSize as integer
                    set xrel to ((item 3 of newScreenSize as integer) - newdx) / ((item 3 of screenSize as integer) - (item 1 of screenSize as integer))
                    set yrel to ((item 4 of newScreenSize as integer) - newdy) / ((item 4 of screenSize as integer) - (item 2 of screenSize as integer))
                    if count of iconSet > 6 then -- position and/or size of window needs to be restored
                        ignoring application responses
                            if count of iconSet > 7 or count of (item 7 of iconSet) < 3 then -- either both position and size or just position
                                set pos to {newdx + (0.5 + ((item 1 of (item 7 of iconSet)) as integer - newdx) * xrel) div 1, newdy + (0.5 + ((item 2 of (item 7 of iconSet)) as integer - newdy)*yrel) div 1} -- new position
                                tell application "Finder" to set tWindow's position to pos  -- restore (scaled) position
                            end if
                            if count of iconSet > 7 or count of (item 7 of iconSet) > 3 then  -- either both position and size or just size
                                set i to 7
                                if count of iconSet > 7 then set i to 8  -- both position and size
                                tell application "Finder" to set tWindow's bounds to {item 1 of pos as integer, item 2 of pos as integer, item 1 of pos as integer + ((item 3 of (item i of iconSet)) as integer) - ((item 1 of (item i of iconSet)) as integer), item 2 of pos as integer + ((item 4 of (item i of iconSet)) as integer) - ((item 2 of (item i of iconSet)) as integer)} -- restore (not scaled) size
                            end if
                        end ignoring
                    end if
                    
                    repeat with i from 1 to number of items in iconNames -- and finally restore icon positions
                        ignoring application responses
                            tell application "Finder" to set position of item (item i of iconNames as string) of tWindow to {item 1 of (item i of iconPositions) as integer, item 2 of (item i of iconPositions) as integer}
                        end ignoring
                    end repeat
                    
                end if
                
                -- for 4.0.1
                set versionString to system version of (system info)
                considering numeric strings
                    if versionString < "10.13.0" then -- we need to toggle view (or something) for icon positions to be updated
                        tell application "Finder"
                            set current view of tWindow to list view
                            set current view of tWindow to icon view
                        end tell
                    end if
                end considering
                
            end if
        end if
    end restore
    
    on showNewIcons()
        if count of iconSet > 0 then
            set iconNames to item 1 of iconSet
            set notWindow to (count of iconSet < 6)
            if not notWindow then
                setTWindow()
                if tWindow is missing value then
                    beep
                    return
                end if
            end if
            
            set oldNames to {} -- force list to be a list of strings - bridge may confuse things...
            repeat with i from 1 to number of items of iconNames
                set end of oldNames to item i of iconNames as string
            end repeat
            
            if notWindow then
                tell application "Finder" to set newIconNames to name of items of desktop  -- get current list of icon names
            else
                if tWindow is missing value then return
                tell application "Finder" to set newIconNames to name of items in tWindow
            end if
            set numDesktop to (count of newIconNames)
            
            set newIcons to {}  -- find new icons
            repeat with x in newIconNames
                if {x as string} is not in oldNames then set end of newIcons to x
            end repeat
            
            if count of newIcons > 0 then -- if there are new icons, select them and get out
                set sel to {}
                tell application "Finder"
                    repeat with aName in newIcons
                        if notWindow then
                            set end of sel to item aName of desktop
                        else
                            set end of sel to item aName in tWindow
                        end if
                    end repeat
                    activate
                    
                    if notWindow then
                        activate window of desktop
                    else
                        --activate Finder window of tWindow
                        activate tWindow
                    end if
                    set selection to sel
                end tell
                tell application "DIM" to activate -- and regain focus
            else -- no new icons, just beep
                beep
            end if
        end if
    end showNewIcons
    
    on numOnDesktop() -- set the current count of icons on Desktop
        if count of iconSet < 6 then
            tell application "Finder" to set numDesktop to (count desktop's items)
        else
            setTWindow()
            if tWindow is not missing value then
                tell application "Finder" to set numDesktop to (count tWindow's items)
            else
                set numDesktop to -1
            end if
        end if
    end numOnDesktop
    
    on numInSet() -- set current count of items in iconSet
        set numArrangement to count (item 1 of iconSet)
    end numInSet
    
    on testBridge()
        try
            tell application "Finder" to set x to arrangement of (icon view options of desktop's window)
            return "yes"
        on error
            return "no"
        end try
    end testBridge
    
end script

