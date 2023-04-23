function _init()
    -- *************
    --     DEBUG
    -- *************
    reveal = false -- reveal mine locations during game
    fill = false -- show values for each space
    -- *************

    -- enable devkit mouse
    poke(0x5F2D, 1)

    -- which screen is the user on?
    -- boot up to menu screen
    menu = true
    play = false
    option = false

    -- list of falling icons on menu screen
    icons = {}

    -- which control scheme to use?
    controller = true
    mouse = false

    -- allow user to change controls from pico-8 menu
    menuitem(1, "control: controller", set_control)

    -- mouse x and y
    mo_x = 0
    mo_y = 0

    -- menu cursor x and y
    menu_x = 28
    menu_y = 80

    -- sticky key checker when starting game
    -- prevents the player holding key down and accidentally digging
    sticky = false

    -- store pb
    -- empty by default
    pb = false

    -- current colour theme
    theme_select = 1

    -- list of themes
    -- {main, accent}
    themes = {
        -- blue (white)
        {12, 7},

        -- orange (white)
        {9, 7}
    }
end

function initialise()
    -- current time
    ct = 0

    -- width of board
    width = 16

    -- height of board
    height = 15

    -- number of mines
    mcount = 10

    -- number of flags available (automaticall set to no. of mines)
    fcount = mcount

    -- number of correctly placed flags
    ccount = 0

    -- has the player lost?
    lose = false

    -- has the player won?
    win = false

    -- player
    p = {
        -- pixel coordinates
        x = 64,
        y = 64,

        -- map coordinates
        mx = 9,
        my = 8
    }

    -- create mine list
    mine_list = {}

    -- make a matrix filled with 0's
    -- 0's represent an empty space
    -- numbers represent the number of adjacent mines
    -- true represents a mine
    grid = gen_matrix(0)

    -- create a matrix for flags
    -- false represents no flag
    -- true represents flag
    flags = gen_matrix(false)

    -- create a matrix for dug places
    -- false represents not yet dug
    -- true represents dug
    digs = gen_matrix(false)

    -- is this the player's first dig?
    -- used to wait to create the mine list
    first = true
end

function _update()
    -- if mouse enabled, capture positions
    if mouse then
        mo_x = stat(32)
        mo_y = stat(33)
    end

    -- if playing...
    if play and not (lose or win) then
        -- update movement
        if controller then
            if btnp(0) and p.x != 0 then
                p.x -= 8
                p.mx -= 1
            elseif btnp(1) and p.x != 120 then
                p.x += 8
                p.mx += 1
            elseif btnp(2) and p.y != 8 then
                p.y -= 8
                p.my -= 1
            elseif btnp(3) and p.y != 120 then
                p.y += 8
                p.my += 1
            end
        elseif mouse then
            p.x = mo_x - mo_x%8
            p.y = mo_y - mo_y%8

            p.mx = p.x / 8 +1
            p.my = p.y / 8

            -- if not still pressing key from menu, disable sticky
            if not (sticky and stat(34) == 1) then
                sticky = false
            end
        end

        -- if the game has started, update the time
        if not first then
            ct = flr(t()) - record
        end

        -- add menu item to return to title
        menuitem(2, "return to title", ensure)

        -- if the player hasn't already lost
        -- makes sure there's no iteration of matrices that haven't been made yet
        if not lose then
            -- if it isn't the first dig
            if not first then
                -- count the number of correctly placed flags
                ccount = 0
                for col=1, #grid do
                    for row=1, #grid[col] do
                        if grid[col][row] == true and flags[col][row] == true then
                            ccount += 1
                        end
                    end
                end

                -- if the player has flagged all mined, uncover all the mines
                -- DOESN'T WORK
                if ccount == mcount then
                    for col in all(grid) do
                        for row in all(grid[col]) do
                            if type(grid[col][row]) == "number" then
                                uncover({col, row})
                            end
                        end
                    end
                    
                    -- player has won
                    win = true

                    -- record the pb
                    -- add trailing 0 if needed
                    if ct%60 < 10 then
                        pb = {tostr(ct\60), "0"..tostr(ct%60)}
                    else
                        pb = {tostr(ct\60), tostr(ct%60)}
                    end
                end
            end

            -- x or right click for flag
            if (btnp("5") or stat(34) == 2) and not wait then
                -- wait for player to lift key
                if stat(34) == 2 then
                    wait = true
                end

                -- if that space hasn't already been dug
                if not digs[p.mx][p.my] then
                    -- if there is already a flag there
                    if flags[p.mx][p.my] == true then
                        -- remove the flag, and add one to the flag count
                        flags[p.mx][p.my] = false
                        fcount += 1
                    -- if there wasn't already a flag there...
                    else
                        -- if the player still has flags left...
                        if fcount != 0 then
                            -- add a flag and take one from the flag count
                            flags[p.mx][p.my] = true
                            fcount -= 1
                        end
                    end
                end
            end

            -- if waiting and user isn't pressing dig, then stop waiting
            -- now allows user to press dig normally
            if wait == true and stat(34) != 2 then
                wait = false
            end

            -- o or left click for dig
            if (btnp("4") or (stat(34) == 1 and not sticky)) and not wait then
                if first then
                    -- create a list of mines
                    mine_list = create_mines(width, height, mcount)

                    for mine in all(mine_list) do
                        --printh(mine[1]..", "..mine[2], "log", false)

                        -- change all the mine positions to true
                        grid[mine[1]][mine[2]] = true
                    end

                    -- fill in the rest of the spaces with numbers for adjacent mines
                    grid = fill_adj(grid)

                    first = false
                    record = flr(t())
                end

                -- don't try and dig a space with a flag
                if flags[p.mx][p.my] != true then
                    for loc in all(mine_list) do
                        -- if that location is in the mine list...
                        if loc[1] == p.mx and loc[2] == p.my then
                            -- the player loses
                            lose = true
                        end
                    end

                    -- if there isn't a mine there, dig that space
                    if not lose then
                        --printh("", "log", true)
                        uncover({p.mx, p.my})
                    end
                end
            end
        end
    -- if the player has lost or won
    elseif win or lose then
        -- x for return
        if btnp(5) then
            win = false
            lose = false
            initialise()
        end

        -- o for return to menu
        if btnp(4) then
            win = false
            lose = false
            play = false
            menu = true
        end
    -- if the player is in the main menu
    elseif menu then
        -- if using controller
        if controller then
            -- movement
            if btnp(3) and menu_y != 96 then
                menu_y += 16
            elseif btnp(2) and menu_y != 80 then
                menu_y -= 16
            end

            -- if selected option
            if btnp(5) then
                -- disable menu
                menu = false

                -- if "play" selected, start the game
                if menu_y == 80 then
                    play = true
                    initialise()
                -- if "options" selected, go to options
                else
                    menu_y = 80
                    option = true
                end
            end
        -- if using mouse
        elseif mouse then
            -- bounds for "play" and "options" on main menu
            hover_play = (36 < mo_x and mo_x < 54) and (80 < mo_y and mo_y < 88)
            hover_options = (36 < mo_x and mo_x < 66) and (96 < mo_y and mo_y < 104)

            -- set cursor position if hovering over an option
            if hover_play then
                menu_y = 80
            elseif hover_options then
                menu_y = 96
            else
                menu_y = false
            end
            
            -- if left clicking
            if stat(34) == 1 then
                menu = false
                -- if hovering over "play", start the game
                if hover_play then
                    play = true
                    -- ensure player doesn't dig immedediately when loading game
                    sticky = true
                    initialise()
                -- if hovering over "options", go to options
                elseif hover_options then
                    menu_y = 80
                    option = true
                end
            end
        end
    -- if the player is in the options
    elseif option then
        -- if using controller
        if controller then
            -- movement
            if btnp(3) and menu_y != 96 then
                menu_y += 16
            elseif btnp(2) and menu_y != 80 then
                menu_y -= 16
            end

            -- x to select option
            if btnp(5) then
                if menu_y == 80 then
                    if theme_select != #themes then
                        theme_select += 1
                    else
                        theme_select = 1
                    end
                end
            -- o to return to menu
            elseif btnp(4) then
                option = false
                menu = true
                -- place cursor on "options"
                menu_y = 96
            end

        -- if using mouse
        elseif mouse then
            -- bounds for "play" and "options" on main menu
            hover_play = (36 < mo_x and mo_x < 54) and (80 < mo_y and mo_y < 88)
            hover_options = (36 < mo_x and mo_x < 66) and (96 < mo_y and mo_y < 104)

            -- set cursor position if hovering over an option
            if hover_play then
                menu_y = 80
            elseif hover_options then
                menu_y = 96
            else
                menu_y = false
            end
            
            --[[
            -- if left clicking
            if stat(34) == 1 then
                menu = false
                -- if hovering over "play", start the game
                if hover_play then
                    play = true
                    -- ensure player doesn't dig immedediately when loading game
                    sticky = true
                    initialise()
                -- if hovering over "options", go to options
                elseif hover_options then
                    menu_y = 80
                    option = true
                end
            end
            --]]
        end
    end
end

function _draw()
    if win then
        -- draw all dug spaces
        draw_digs()

        -- draw message box and border
        rectfill(18, 39, 109, 72, 9)
        rectfill(19, 40, 108, 71, 7)

        -- draw message shadow
        print("you win!", sin(t()*0.5)*10+49, sin(t())*5+48, 6)

        -- draw message
        print("you win!", sin(t()*0.5)*10+48, sin(t())*5+47, 2)

        -- draw options
        print("❎ replay", 22, 58, 13)
        print("🅾️ return to menu")
    elseif lose then
        -- draw message box and border
        rectfill(18, 39, 109, 72, 9)
        rectfill(19, 40, 108, 71, 7)

        -- draw message shadow
        print("you lose...", sin(t()*0.5)*6+42, 47, 6)

        -- draw message
        print("you lose...", sin(t()*0.5)*6+43, 46, 2)

        -- draw options
        print("❎ to replay", 22, 58, 13)
        print("🅾️ to return to menu")
    elseif play then
        -- clear screen with grey background
        cls(13)

        -- record current seconds
        -- add leading 0 if needed
        if ct % 60 < 10 then
            secs = ":0"..ct % 60
        else
            secs = ":"..ct % 60
        end

        -- record current mins
        -- add leading space if needed
        if ct \ 60 < 10 then
            mins = " "..ct \ 60
        else
            mins = ct \ 60
        end

        -- print time in top right corner
        print(mins..secs, 108, 1, 7)

        -- draw the map
        map(0, 0)

        -- draw flag icon and count in top left corner
        spr(3, 0, 0)
        print(fcount, 8, 1, 7)

        -- DEBUG: draw mines
        if reveal then
            foreach(mine_list, draw_mine)
        end

        -- draw flags and dug spaces
        draw_flags()
        draw_digs()

        -- DEBUG: draw all space values
        if fill then
            draw_matrix()
        end
    
        -- draw square cursor
        spr(17, p.x, p.y)
    elseif menu then
        -- draw main frame and background
        draw_title_menu("❎ TO SELECT")

        -- draw best time box
        rectfill(76, 81, 99, 103, 6)
        print("best:", 77, 82, 7)
        if pb == false then
            print("---", 77, 92, 2)
        else
            print(pb[1]..":"..pb[2], 77, 92, 2)
        end

        -- set a background for whichever option is currently selected
        if menu_y == 80 then
            rectfill(37, 81, 53, 87, 6)

            print("play", 38, 82, 7)
            print("options", 38, 98, 6)
        elseif menu_y == 96 then
            rectfill(37, 97, 65, 103, 6)

            print("play", 38, 82, 6)
            print("options", 38, 98, 7)
        else
            print("play", 38, 82, 6)
            print("options", 38, 98, 6)
        end

        -- if the player is hovering over an option, draw the flag next to it
        if menu_y != false then
            spr(3, menu_x, menu_y)
        end
    -- if the player is in the options menu
    elseif option then
        -- draw main frame and background
        draw_title_menu("🅾️ TO RETURN")
        
        -- set a background for whichever option is currently selected
        if menu_y == 80 then
            rectfill(37, 81, 57, 87, 6)

            print("theme", 38, 82, 7)
            print("control", 38, 98, 6)
        elseif menu_y == 96 then
            rectfill(37, 97, 65, 103, 6)

            print("theme", 38, 82, 6)
            print("control", 38, 98, 7)
        else
            print("theme", 38, 82, 6)
            print("control", 38, 98, 6)
        end

        -- theme preview
        rectfill(75, 81, 81, 87, themes[theme_select][1])
        pset(75, 81, themes[theme_select][2])
        pset(81, 81, themes[theme_select][2])
        pset(75, 87, themes[theme_select][2])
        pset(81, 87, themes[theme_select][2])

        if controller then spr(34, 75, 97) else spr(33, 75, 97) end

        -- if the player is hovering over an option, draw the flag next to it
        if menu_y != false then
            spr(3, menu_x, menu_y)
        end
    end

    -- if mouse control is enabled, draw the cursor
    if mouse then
        spr(20, mo_x, mo_y)
    end
end

function gen_matrix(fill)
    m = {}
    for c1=1, width do
        local column = {}
        for c2=1, height do
            add(column, fill)
        end

        add(m, column)
    end

    return m
end

function draw_mine(loc)
    spr(4, loc[1]*8-8, loc[2]*8)
end

function draw_flags()
    for c1=1, #flags do
        for c2=1, #flags[c1] do
            if flags[c1][c2] then
                spr(3, c1*8-8, c2*8)
            end
        end
    end
end

function draw_digs()
    for c1=1, #digs do
        for c2=1, #digs[c1] do
            if digs[c1][c2] then
                rectfill(c1*8-8, c2*8, c1*8-1, c2*8+7, themes[theme_select][1])

                if type(grid[c1][c2]) == "number" and grid[c1][c2] >= 1 then
                    print(grid[c1][c2], c1*8-5, c2*8+2, 7)
                end
            end
        end
    end
end

function draw_matrix()
    for c1=1, #grid do
        for c2=1, #grid[c1] do
            if type(grid[c1][c2]) == "number" and grid[c1][c2] != 0 then
                print(grid[c1][c2], c1*8-5, c2*8+2, 8)
            end
        end
    end
end

function uncover(loc)
    digs[loc[1]][loc[2]] = true

    -- if the current location is empty (no adjacent)...
    if grid[loc[1]][loc[2]] == 0 then
        -- uncover all the spaces around it
        for pcol=-1, 1 do
            for prow=-1, 1 do
                if not (pcol == 0 and prow == 0) then
                    local probe = {loc[1]+pcol, loc[2]+prow}

                    if
                    probe[1] > 0 and
                    probe[1] < 17 and
                    probe[2] > 0 and
                    probe[2] < 16 then
                        if 
                        digs[probe[1]][probe[2]] != true and
                        flags[probe[1]][probe[2]] != true then
                            uncover({probe[1], probe[2]})
                        end
                    end
                end
            end
        end
    end
end

function set_control(b)
    if(b&1 > 0) then
        menuitem(1, "control: controller")
        controller = true
        mouse = false
        menu_y = 80
    end

    if(b&2 > 0) then
        menuitem(1,"control: mouse")
        mouse = true
        controller = false
    end
    return true
end

function ensure()
    menuitem(2, "are you sure?", to_title)
    return true
end

function to_title()
    menu = true
    play = false
end

function draw_title_menu(info_message)
    -- fill with white background
    cls(7)

    -- set to + draw pattern
    -- create background
    -- set back to normal fill
    fillp(◆)
    rectfill(0, 0, 128, 128, themes[theme_select][1])
    fillp(█)
    
    -- if there are fewer than 15 icons in the background, spawn a new one
    if #icons < 15 then
        -- add an icon to the list
        add(icons, {
            -- centre of x movement
            -- sin wave moves greater and less than this value
            x_base = flr(rnd(120)),

            -- multiplier for range of horizontal movement
            multi = rnd(1),

            -- position on screen
            -- spawn off screen
            x = -20,
            y = flr(rnd(120))-120,

            -- sprite (random: flag or mine)
            s = flr(rnd(2))+3,

            -- downwards speed
            speed = flr(rnd(2))+0.4,

            -- draw icon at coords
            draw = function(self)
                spr(self.s, self.x, self.y)
            end,

            -- fall down
            -- move left and right, following sin graph
            fall = function(self)
                self.y += self.speed
                self.x = self.x_base + sin(t()*self.multi)*5
            end,

            -- delete self if off screen
            check = function(self)
                if self.y > 130 then
                    del(icons, self)
                end
            end
        })
    end

    -- for each icon, draw it, make it fall, and check if it's off screen
    for i in all(icons) do
        i:draw()
        i:fall()
        i:check()
    end

    -- draw background and border
    rectfill(19, 15, 108, 112, 1)
    rectfill(20, 16, 107, 111, 7)

    if info_message then
        rectfill(59, 112, 108, 118, 1)
        print(info_message, 60, 113, 7)
    end

    -- draw grid as title background
    for c1=16, 64, 16 do
        for c2=20, 100, 16 do
            spr(1, c2, c1)
        end
    end

    for c1=24, 64, 16 do
        for c2=28, 100, 16 do
            spr(1, c2, c1)
        end
    end

    -- draw "mini" background and letters
    rectfill(28, 24, 59, 31, themes[theme_select][1])
    print("m", 30, 26, 7)
    print("i", 38, 26)
    print("n", 46, 26)
    print("i", 54, 26)

    --rectfill(28, 32, 99, 63, 7)

    -- draw "mines" logo
    sspr(0, 32, 72, 63, 28, 32)
end