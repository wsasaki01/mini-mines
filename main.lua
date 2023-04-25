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
    guide = false

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
    new_pb = false

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

    mine_flash = 0
    show_mines = false
end

function initialise()
    -- current time
    ct = 0

    -- width of board
    width = 16

    -- height of board
    height = 15

    -- number of mines
    mcount = 1

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

        if not (sticky and stat(34) == 1) then
            sticky = false
        end
    end

    if play and not (lose or win) then
        -- update movement
        if controller then
            if btnp(0) and p.x != 0 then
                -- play sound
                sfx(0)
                p.x -= 8
                p.mx -= 1
            elseif btnp(1) and p.x != 120 then
                sfx(0)
                p.x += 8
                p.mx += 1
            elseif btnp(2) and p.y != 8 then
                sfx(0)
                p.y -= 8
                p.my -= 1
            elseif btnp(3) and p.y != 120 then
                sfx(0)
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

                -- if the player wins
                if ccount == mcount then
                    -- if the player has flagged all mined, uncover all the mines
                    for col=1, #grid do
                        for row=1, #grid[col] do
                            if type(grid[col][row]) == "number" then
                                uncover({col, row})
                            end
                        end
                    end
                    
                    -- player has won
                    win = true

                    -- record the pb if needed
                    if pb == false or (ct < pb) then
                        pb = ct
                        -- tell _update() that there's been a new pb
                        new_pb = true
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
                        sfx(3)
                        flags[p.mx][p.my] = false
                        fcount += 1
                    -- if there wasn't already a flag there...
                    else
                        -- if the player still has flags left...
                        if fcount != 0 then
                            -- add a flag and take one from the flag count
                            sfx(1)
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
                sticky = true
                
                if first then
                    -- create a list of mines
                    -- pass in current position to ensure no mine spawns there
                    mine_list = create_mines(width, height, mcount, {p.mx, p.my})

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
                        sfx(2)
                        uncover({p.mx, p.my})
                    end
                end
            end
        end
    elseif win or lose then
        if controller then
            -- x for return
            if btnp(5) then
                win = false
                lose = false
                new_pb = false

                initialise()
            end

            -- o for return to menu
            if btnp(4) then
                win = false
                lose = false
                play = false
                new_pb = false

                menu = true
            end
        elseif mouse then
            hover_replay = (21 <= mo_x and mo_x <= 69) and (57 <= mo_y and mo_y <= 63)
            hover_quit = (21 <= mo_x and mo_x <= 101) and (63 <= mo_y and mo_y <= 70)

            if stat(34) == 1 and not sticky then
                sticky = true
                if hover_replay then
                    win = false
                    lose = false
                    initialise()
                elseif hover_quit then
                    win = false
                    lose = false
                    play = false
                    menu = true
                end
            end
        end
    elseif menu then
        -- if using controller
        if controller then
            -- movement
            if btnp(3) and menu_y != 96 then
                sfx(4)
                menu_y += 8
            elseif btnp(2) and menu_y != 80 then
                sfx(4)
                menu_y -= 8
            end

            -- x to select option
            if btnp(5) then
                -- disable menu
                menu = false
                sfx(5)

                -- if "play" selected, start the game
                if menu_y == 80 then
                    play = true
                    initialise()
                -- if "guide" selected, go to guide screen
                elseif menu_y == 88 then
                    guide = true
                -- if "options" selected, go to options
                elseif menu_y == 96 then
                    menu_y = 80
                    option = true
                end
            end
        -- if using mouse
        elseif mouse then
            -- bounds for "play" and "options" on main menu
            hover_play = (36 < mo_x and mo_x < 54) and (80 < mo_y and mo_y < 88)
            hover_guide = (37 < mo_x and mo_x < 57) and (89 < mo_y and mo_y < 95)
            hover_options = (36 < mo_x and mo_x < 66) and (96 < mo_y and mo_y < 104)

            -- set cursor position if hovering over an option
            if hover_play then
                menu_y = 80
            elseif hover_guide then
                menu_y = 88
            elseif hover_options then
                menu_y = 96
            else
                menu_y = false
            end
            
            -- if left clicking
            if stat(34) == 1 and not sticky then
                -- ensure player click accidentally in next screen
                sticky = true

                -- if hovering over "play", start the game
                if hover_play then
                    sfx(5)
                    menu = false
                    play = true
                    initialise()
                -- if hovering over "play", start the game
                elseif hover_guide then
                    sfx(5)
                    menu = false
                    guide = true
                -- if hovering over "options", go to options
                elseif hover_options then
                    sfx(5)
                    menu = false
                    option = true
                end
            end
        end
    elseif guide then
        -- return to title screen
        if controller then
            if btnp(4) then
                sfx(6)
                guide = false
                menu = true
            end
        elseif mouse then
            -- bounds for "return" in guide menu
            hover_return_guide = (92 <= mo_x and mo_x <= 118) and (119 <= mo_y and mo_y <= 123)
            if stat(34) == 1 and not sticky and hover_return_guide then
                sticky = true
                guide = false
                menu = true
            end
        end
    elseif option then
        -- if using controller
        if controller then
            -- movement
            if btnp(3) and menu_y != 96 then
                sfx(4)
                menu_y += 16
            elseif btnp(2) and menu_y != 80 then
                sfx(4)
                menu_y -= 16
            end

            -- x to select option
            if btnp(5) then
                sfx(5)
                if menu_y == 80 then
                    if theme_select != #themes then
                        theme_select += 1
                    else
                        theme_select = 1
                    end
                elseif menu_y == 96 then
                    if controller then
                        controller = false
                        mouse = true
                    else
                        mouse = false
                        controller = true
                    end
                end
            -- o to return to menu
            elseif btnp(4) then
                sfx(6)
                option = false
                menu = true
                -- place cursor on "options"
                menu_y = 96
            end

        -- if using mouse
        elseif mouse then
            -- bounds for "play" and "options" on main menu
            hover_theme = (36 < mo_x and mo_x < 58) and (80 < mo_y and mo_y < 88)
            hover_control = (36 < mo_x and mo_x < 66) and (96 < mo_y and mo_y < 104)
            hover_return_options = (82 < mo_x and mo_x < 108) and (113 < mo_y and mo_y < 118)

            -- set cursor position if hovering over an option
            if hover_theme then
                menu_y = 80
            elseif hover_control then
                menu_y = 96
            else
                menu_y = false
            end
            
            -- if left clicking
            if stat(34) == 1 and not sticky then
                if menu_y == 80 then
                    sfx(5)
                    sticky = true
                    if theme_select != #themes then
                        theme_select += 1
                    else
                        theme_select = 1
                    end
                elseif menu_y == 96 then
                    sfx(5)
                    sticky = true
                    if controller then
                        controller = false
                        mouse = true
                    else
                        mouse = false
                        controller = true
                    end
                elseif hover_return_options then
                    sfx(6)
                    options = false
                    menu = true
                end
            end
        end
    end
end

function _draw()
    if win then
        -- clear screen with grey background
        cls(13)

        -- draw the map
        map(0, 0)

        -- draw all dug spaces and flags
        draw_digs()
        draw_flags()

        -- print time in top right corner
        print(mins..secs, 108, 1, 7)


        -- draw flag icon and count in top left corner
        spr(3, 0, 0)
        print(fcount, 8, 1, 7)

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

        if new_pb then
            pb_message()
        end
    elseif lose then
        -- clear screen with grey background
        cls(13)

        -- draw the map
        map(0, 0)

        -- draw all dug spaces and flags
        draw_digs()
        draw_flags()

        -- print time in top right corner
        print(mins..secs, 108, 1, 7)


        -- draw flag icon and count in top left corner
        spr(3, 0, 0)
        print(fcount, 8, 1, 7)
        
        -- draw message box and border
        rectfill(18, 39, 109, 72, 9)
        rectfill(19, 40, 108, 71, 7)

        -- draw message shadow
        print("you lose...", sin(t()*0.5)*6+42, 47, 6)

        -- draw message
        print("you lose...", sin(t()*0.5)*6+43, 46, 2)

        if controller then
            -- draw options
            print("❎ to replay", 22, 58, 13)
            print("🅾️ to return to menu")
        elseif mouse then
            hover_replay = (21 <= mo_x and mo_x <= 69) and (57 <= mo_y and mo_y <= 63)
            hover_quit = (21 <= mo_x and mo_x <= 101) and (63 <= mo_y and mo_y <= 70)

            -- set a background for whichever option is currently selected
            if hover_replay then
                rectfill(21, 57, 69, 63, 6)

                print("❎ to replay", 22, 58, 13)
                print("🅾️ to return to menu", 22, 65)
            elseif hover_quit then
                rectfill(21, 64, 101, 70, 6)

                print("❎ to replay", 22, 58, 13)
                print("🅾️ to return to menu", 22, 65)
            else
                print("❎ to replay", 22, 58, 13)
                print("🅾️ to return to menu", 22, 65)
            end
        end
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
        if controller then
            draw_title_menu("❎ TO SELECT")
        elseif mouse then
            draw_title_menu()
        end

        -- draw best time box
        rectfill(76, 81, 99, 103, 6)
        print("best:", 77, 82, 7)

        -- format the pb as needed
        if pb == false then
            pb_text = {"-", "-"}
        elseif pb%60 < 10 then
            pb_text = {tostr(pb\60), "0"..tostr(pb%60)}
        else
            pb_text = {tostr(pb\60), tostr(pb%60)}
        end

        -- display best score
        print(pb_text[1]..":"..pb_text[2], 77, 92, 2)

        -- set a background for whichever option is currently selected
        if menu_y == 80 then
            rectfill(37, 81, 53, 87, 6)

            print("play", 38, 82, 7)
            print("guide", 38, 90, 6)
            print("options", 38, 98, 6)
        elseif menu_y == 88 then
            rectfill(37, 89, 57, 95, 6)

            print("play", 38, 82, 6)
            print("guide", 38, 90, 7)
            print("options", 38, 98, 6)
        elseif menu_y == 96 then
            rectfill(37, 97, 65, 103, 6)

            print("play", 38, 82, 6)
            print("guide", 38, 90, 6)
            print("options", 38, 98, 7)
        else
            print("play", 38, 82, 6)
            print("guide", 38, 90, 6)
            print("options", 38, 98, 6)
        end

        -- if the player is hovering over an option, draw the flag next to it
        if menu_y != false then
            spr(3, menu_x, menu_y)
        end
    elseif guide then
        if controller then
            draw_guide("🅾️ TO RETURN")
        elseif mouse then
            draw_guide("RETURN")
        end
    elseif option then
        -- draw main frame and background
        if controller then
            draw_title_menu("🅾️ TO RETURN")
        elseif mouse then
            draw_title_menu("RETURN")
        end
        
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
        -- rounded corners
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

-- ***********************
--     EXTRA FUNCTIONS 
-- ***********************

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
    -- fill with accent background
    cls(themes[theme_select][2])

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
        if info_message == "RETURN" then
            rectfill(82, 112, 108, 118, 1)
            print(info_message, 84, 113, 7)
        else
            rectfill(59, 112, 108, 118, 1)
            print(info_message, 60, 113, 7)
        end
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

function draw_guide(info_message)
    -- fill with accent background
    cls(themes[theme_select][2])

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
    rectfill(10, 10, 118, 118, 1)
    rectfill(11, 11, 117, 117, 7)

    if info_message then
        if info_message == "RETURN" then
            rectfill(92, 119, 118, 123, 1)
            print(info_message, 94, 118, 7)
        else
            rectfill(69, 119, 118, 124, 1)
            print(info_message, 70, 119, 7)
        end
    end

    -- draw "mini" background and letters
    rectfill(18, 18, 34, 24, themes[theme_select][1])
    print("mini", 19, 19, 7)
    
    print("❎ / left click TO dig\nrevealing no. of\nadjacent mines", 19, 27, themes[theme_select][1])
    
    print("🅾️ / right click TO flag\nto mark a mine", 19, 48, 8)

    -- draw grid border
    rect(27, 67, 100, 108, 13)

    -- draw sample grid
    for col=28, 92, 16 do
        for row=68, 115, 16 do
            spr(1, col, row)
        end
    end

    for col=36, 90, 16 do
        for row=76, 100, 16 do
            spr(1, col, row)
        end
    end

    print("FLAG ALL MINES TO WIN!", 22, 110, 0)

    if mine_flash != 30 then
        mine_flash += 1
    else
        mine_flash = 0
        show_mines = not show_mines
    end

    if show_mines then
        spr(4, 68, 76)
        spr(4, 76, 92)
        spr(4, 36, 92)
    end

    rectfill(76, 76, 99, 91, themes[theme_select][1])
    rectfill(84, 76, 99, 99, themes[theme_select][1])
    rectfill(68, 84, 75, 107, themes[theme_select][1])
    rectfill(76, 100, 99, 107, themes[theme_select][1])

    print("1", 79, 78, 7)
    print("2", 79, 86, 7)
    print("2", 71, 86, 7)
    print("1", 71, 94, 7)
    print("1", 71, 102, 7)
    print("1", 79, 102, 7)
    print("1", 87, 102, 7)
    print("1", 87, 94, 7)
    print("1", 87, 86, 7)

    spr(3, 76, 92)
end

function pb_message()
    -- positioned below timer
    x = 113

    -- move up and down periodically
    y = flr(sin(t()*1))+11

    -- colouring
    pset(x+6, y-3, 1)
    line(x+5, y-2, x+7, y-2, 1)
    pset(x+6, y-2, 2)
    line(x+4, y-1, x+8, y-1, 1)
    line(x+5, y-1, x+7, y-1, 2)
    rectfill(x, y, x+12, y+11, 2)
    print("NEW\nPB!", x+1, y, 7)
    line(x, y+12, x+12, y+12, 0)
end