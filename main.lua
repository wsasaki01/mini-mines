function _init()
    -- *************
    --     DEBUG
    -- *************
    reveal = false -- reveal mine locations during game
    fill = false -- show values for each space
    -- *************

    -- enable devkit mouse
    poke(0x5F2D, 1)

    -- program version number
    ver = "0.25.2"

    -- which screen is the user on?
    -- boot up to menu screen
    menu = true
    play = false
    difficulty = false
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

    -- main_stick key checker when starting game
    -- prevents the player holding key down and accidentally digging
    main_stick = false

    -- store pbs for each mode
    -- false by default
    pb = {
        easy = false,
        med = false,
        hard = false
    }

    -- has a new pb just been set?
    -- false if no
    -- difficulty if yes
    new_pb = false

    -- current colour theme
    theme_select = 1

    -- list of themes
    -- main: primary colour (digs)
    -- bg: background (behind menus)
    -- accent: menu borders
    -- gamebg: background for actual game
    themes = {
        -- blue (white)
        {main = 12, bg = 7, accent = 1, gamebg = 13},
    }

    -- player unlocks more themes by winning games
    unlockable = {
        -- unlockable by playing easy mode
        easy = {
            -- orange (white)
            {main = 9, bg = 7, accent = 1, gamebg = 3},

            -- red (white)
            {main = 8, bg = 7, accent = 0, gamebg = 0}
        },

        -- unlockable by playing medium mode
        med = {
            -- pink (white)
            {main = 14, bg = 7, accent = 8, gamebg = 2},

            -- light green (dark green)
            {main = 11, bg = 3, accent = 5, gamebg = 3}
        },

        -- unlockable by playing hard mode
        hard = {
            -- brown (purple)
            {main = 4, bg = 2, accent = 1, gamebg = 3},

            -- beige (purple)
            {main = 15, bg = 7, accent = 13, gamebg = 4}
        }
    }

    -- has a new theme been unlocked this round?
    new_theme = false

    -- counters for number of wins on each mode
    win_count = {
        easy = 0,
        med = 0,
        hard = 0
    }

    -- counter for flashing mines on guide page
    mine_flash = 0
    show_mines = false

    -- counter for bouncing letters
    bcount = 1
    timer = 0

    -- hold to action on win/loss
    hold_timer = 2
    ticker = 0

    -- how many frames between each explosion
    explosion_interval = 5

    -- wait counter and actual time for post-explosion
    wait = 0
    final_wait = 25

    -- strength of screen shake
    shake_strength = 0

    printh("", "log", true)
end

function initialise(diff)
    -- current time
    ct = 0

    -- store the current difficulty
    size = diff
    if diff == "easy" then
        width = 7 -- width of board
        height = 7 -- height of board
        mcount = 1 -- number of mines

        -- player
        p = {
            -- pixel coordinates
            x = 60,
            y = 64,

            -- map coordinates
            mx = 4,
            my = 4
        }

        -- the limits for the cursor on the grid
        xlim = {36, 84}
        ylim = {40, 88}
    elseif diff == "med" then
        width = 11
        height = 11
        mcount = 15
        
        p = {
            x = 60,
            y = 64,

            mx = 6,
            my = 6
        }

        xlim = {20, 100}
        ylim = {24, 104}
    elseif diff == "hard" then
        width = 16
        height = 15
        mcount = 30
        
        p = {
            x = 64,
            y = 64,

            mx = 9,
            my = 8
        }

        xlim = {0, 120}
        ylim = {8, 120}
    end

    -- x and y offsets
    -- how far into the screen should the map be drawn?
    xoff = 64-(8*width/2)
    yoff = 60-(8*height/2)

    -- number of flags available (automaticall set to no. of mines)
    fcount = mcount

    -- number of correctly placed flags
    ccount = 0

    -- has the player won or lost, or in the loss animation?
    win = false
    lose = false
    losing = false

    -- create mine, explosion and particles lists
    mine_list = {}
    explosions = {}
    particles = {}

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
    -- allow user to return to title from pico-8 menu
    menuitem(2, "return to title", ensure)
    
    if controller then
        -- control scheme
        main = btn(5)
        alt = btn(4)

        -- sticky trackers for lc/x and rc/o
        -- when the player clicks either of these, the sticky is enabled
        -- actions are only allowed while sticky is false
        -- this ensures the player doesn't hold the button by accident, and press something in the next screen
        if main_stick and not main then
            main_stick = false
        end

        if alt_stick and not alt then
            alt_stick = false
        end
    elseif mouse then
        -- positions
        mo_x = stat(32)
        mo_y = stat(33)

        -- left and right click
        main = stat(34) == 1
        alt = stat(34) == 2

        -- sticky trackers
        if main_stick and not main then
            main_stick = false
        end

        if alt_stick and not alt then
            alt_stick = false
        end
    end

    if win or lose then
        if controller then
            -- x for replay
            if main then
                if main_stick then
                    ticker += 0.1
                else
                    main_stick = true
                    ticker = 0
                end

                if flr(ticker) == hold_timer then
                    ticker = 0

                    win = false
                    lose = false
                    new_pb = false
                    new_theme = false

                    main_stick = true
                    alt_stick = true
                    
                    initialise(size)
                end
            
            -- o for return to menu
            elseif alt then
                if alt_stick then
                    ticker += 0.1
                else
                    alt_stick = true
                    ticker = 0
                end

                if flr(ticker) == hold_timer then
                    ticker = 0

                    win = false
                    lose = false
                    play = false
                    new_pb = false
                    new_theme = false

                    menu_y = 80
                    menu = true
                end
            else
                ticker = false
            end
        elseif mouse then
            hover_replay = (21 <= mo_x and mo_x <= 69) and (57 <= mo_y and mo_y <= 63)
            hover_quit = (21 <= mo_x and mo_x <= 101) and (63 <= mo_y and mo_y <= 70)

            -- if left clicking
            if main and not main_stick then
                main_stick = true

                if hover_replay then
                    win = false
                    lose = false

                    new_pb = false
                    new_theme = false

                    initialise(size)
                elseif hover_quit then
                    win = false
                    lose = false
                    play = false

                    new_pb = false
                    new_theme = false

                    menu = true
                end
            end
        end
    elseif losing then
        -- when the timer reaches the interval, explode another mine
        if explosion_timer == explosion_interval then
            -- wait for a non-flagged mine
            non_flag = false
            local target
            while not non_flag and #mine_list != 0 do
                -- get a random mine from the list
                index = flr(rnd(#mine_list))+1
                target = mine_list[index]

                -- if that mine hasn't been flagged
                if flags[target[1]][target[2]] != true then
                    -- break loop
                    non_flag = true
                -- if that mine has been flagged
                else
                    -- remove it from the list
                    explosion_counter += 1
                    del(mine_list, mine_list[index])
                    target = false
                end
            end

            if target then
                -- add the explosion, particles
                add(explosions, target)
                add_particles(target)
                del(mine_list, target)

                -- reset timer
                explosion_timer = 0
                explosion_counter += 1

                shake_strength = 1
            end
        else
            explosion_timer += 1
        end

        -- when explosions are done, wait a bit
        if explosion_counter == mcount and shake_strength == 0 then
            wait += 1
        end

        -- after waiting a bit, show the loss screen
        if wait == final_wait then
            losing = false
            lose = true
            wait = 0
            explosion_counter = 0
        end
    elseif difficulty then
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
            if main and not main_stick then
                main_stick = true

                -- disable difficulty menu
                difficulty = false
                play = true
                sfx(5)

                -- difficulty selection
                if menu_y == 80 then
                    --easy
                    initialise("easy")
                elseif menu_y == 88 then
                    --medium
                    initialise("med")
                elseif menu_y == 96 then
                    --hard
                    initialise("hard")
                end
            end

            -- o to return to title
            if alt and not alt_stick then
                alt_stick = true

                -- disable difficulty menu
                difficulty = false
                sfx(6)

                -- go back to main menu
                menu_y = 80
                menu = true
            end
        elseif mouse then
            -- bounds for "play" and "options" on main menu
            hover_easy = (37 <= mo_x and mo_x <= 53) and (81 <= mo_y and mo_y <= 87)
            hover_medium = (37 <= mo_x and mo_x <= 61) and (89 <= mo_y and mo_y <= 95)
            hover_hard = (37 <= mo_x and mo_x <= 53) and (97 <= mo_y and mo_y <= 103)
            hover_return_difficulty = (82 < mo_x and mo_x < 108) and (113 < mo_y and mo_y < 118)

            -- set cursor position if hovering over an option
            if hover_easy then
                menu_y = 80
            elseif hover_medium then
                menu_y = 88
            elseif hover_hard then
                menu_y = 96
            else
                menu_y = false
            end
            
            -- left click to pick difficulty
            if main and not main_stick then
                main_stick = true

                if hover_easy then
                    sfx(5)
                    difficulty = false
                    play = true
                    initialise("easy")
                elseif hover_medium then
                    sfx(5)
                    difficulty = false
                    play = true
                    initialise("med")
                elseif hover_hard then
                    sfx(5)
                    difficulty = false
                    play = true
                    initialise("hard")
                elseif hover_return_difficulty then
                    sfx(6)
                    difficulty = false
                    menu = true
                end
            end
        end
    elseif play then
        -- if it isn't the first dig
        if not first then
            -- only record time once game has started
            ct = flr(t()) - record

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
                if pb[size] == false or (ct < pb[size]) then
                    pb[size] = ct
                    -- tell _update() that there's been a new pb
                    new_pb = true
                end

                -- add one to win counter for current difficulty
                win_count[size] += 1

                -- if this the player's first win or they set a new PB, and there's still themes to unlcok
                if
                (win_count[size] == 1 or
                win_count[size] % 5 or
                new_pb) and
                #unlockable[size] != 0 then
                    -- add the new theme to the player's collection
                    add(themes, unlockable[size][1])

                    -- new theme unlocked
                    new_theme = unlockable[size][1]

                    -- remove it from the original list
                    del(unlockable[size], unlockable[size][1])

                end
            end
        end

        -- check if the player is within the grid
        -- if not, they won't be able to dig or flag
        in_bound = (1 <= p.mx and p.mx <= width) and (1 <= p.my and p.my <= height)
        
        -- update movement, using cursor limits
        if controller then
            if btnp(0) and p.x != xlim[1] then
                -- play sound
                sfx(0)
                p.x -= 8
                p.mx -= 1
            elseif btnp(1) and p.x != xlim[2] then
                sfx(0)
                p.x += 8
                p.mx += 1
            elseif btnp(2) and p.y != ylim[1] then
                sfx(0)
                p.y -= 8
                p.my -= 1
            elseif btnp(3) and p.y != ylim[2] then
                sfx(0)
                p.y += 8
                p.my += 1
            end
        elseif mouse then
            -- start at offset
            -- find distance from current mouse to offset
            -- int. div. of 8 to find how many spaces that is
            -- mult. by 8 to actually set the position to that space
            p.x = xoff + ((mo_x-xoff)\8)*8
            p.y = yoff + ((mo_y-yoff)\8)*8

            -- find distance from current mouse to offset
            -- int. div. of 8 to find how many spaces that is
            p.mx = (mo_x - xoff) \ 8 +1
            p.my = (mo_y - yoff) \ 8
        end

        -- x or left click for flag
        if main and not main_stick and in_bound then
            -- wait for player to lift key
            main_stick = true

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

        -- o or right click for dig
        if alt and not alt_stick and in_bound then
            alt_stick = true
            
            if first then
                -- create a list of mines
                -- pass in current position to ensure no mine spawns there
                mine_list = create_mines(width, height, mcount, {p.mx, p.my})

                -- change all the mine positions to true
                for mine in all(mine_list) do
                    --printh(mine[1]..", "..mine[2], "log", false)
                    grid[mine[1]][mine[2]] = true
                end

                -- fill in the rest of the spaces with numbers for adjacent mines
                grid = fill_adj(grid, width, height)

                first = false
                record = flr(t())
            end

            -- don't try and dig a space with a flag
            if flags[p.mx][p.my] != true then
                for loc in all(mine_list) do
                    -- if that location is in the mine list...
                    if loc[1] == p.mx and loc[2] == p.my then
                        -- the player loses
                        losing = true

                        -- make sure the current mine explodes first
                        add(explosions, {p.mx, p.my})
                        del(mine_list, {p.mx, p.my})
                        add_particles({p.mx, p.my})

                        explosion_timer = flr(explosion_interval * 0.8)
                        explosion_counter = 0
                    end
                end

                -- if there isn't a mine there, dig that space
                if not losing then
                    --printh("", "log", true)

                    -- if that space hasn't already been dug, play sfx
                    if digs[p.mx][p.my] != true then
                        sfx(2)
                    end

                    -- chain-uncover the rest of the spaces
                    uncover({p.mx, p.my})
                end
            end
        end
    elseif menu then
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
            if main and not main_stick then
                main_stick = true

                -- disable menu
                menu = false
                sfx(5)

                -- if "play" selected, start the game
                if menu_y == 80 then
                    difficulty = true
                -- if "guide" selected, go to guide screen
                elseif menu_y == 88 then
                    guide = true
                -- if "options" selected, go to options
                elseif menu_y == 96 then
                    menu_y = 80
                    option = true
                end
            end
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
            if main and not main_stick then
                main_stick = true

                -- if hovering over "play", start the game
                if hover_play then
                    sfx(5)
                    menu = false
                    difficulty = true
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
            -- o to return
            if alt and not alt_stick then
                sfx(6)
                alt_stick = true
                guide = false
                menu = true
            end
        elseif mouse then
            -- bounds for "return" in guide menu
            hover_return_guide = (92 <= mo_x and mo_x <= 118) and (119 <= mo_y and mo_y <= 123)
            
            if main and not main_stick and hover_return_guide then
                sfx(6)
                main_stick = true
                guide = false
                menu = true
            end
        end
    elseif option then
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
            if main and not main_stick then
                main_stick = true
                sfx(5)

                if menu_y == 80 then
                    -- change theme
                    if theme_select != #themes then
                        theme_select += 1
                    else
                        theme_select = 1
                    end
                elseif menu_y == 96 then
                    -- switch to mouse
                    controller = false
                    mouse = true
                end
            -- o to return to menu
            elseif alt and not alt_stick then
                alt_stick = true
                sfx(6)

                option = false
                menu = true

                -- place cursor on "options"
                menu_y = 96
            end
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
            if main and not main_stick then
                main_stick = true

                if menu_y == 80 then
                    sfx(5)
                    if theme_select != #themes then
                        theme_select += 1
                    else
                        theme_select = 1
                    end
                elseif menu_y == 96 then
                    sfx(5)

                    -- change to controller
                    mouse = false
                    controller = true
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
        cls(themes[theme_select]["gamebg"])

        -- draw the map
        map(0, 0, xoff, yoff, width, height+1) 
        
        -- draw all dug spaces and flags
        draw_digs()
        draw_flags()

        -- print time in top right corner
        print(mins..secs, 108, 1, 7)

        -- draw flag icon and count in top left corner
        spr(3, 0, 0)
        print(fcount, 8, 1, 7)

        -- if a new theme was just unlocked
        if type(new_theme) == "table" then
            -- draw message box and border with extra space for theme info
            rectfill(18, 39, 109, 88, 9)
            rectfill(19, 40, 108, 87, 7)
            
            bprint("new theme!", 37, 76, new_theme["accent"], 3)

            -- theme preview
            rectfill(82, 75, 88, 81, new_theme["main"])

            pset(82, 75, 7)
            pset(82, 81, 7)
            pset(88, 75, 7)
            pset(88, 81, 7)
        else
            -- draw message box and border normally
            rectfill(18, 39, 109, 72, 9)
            rectfill(19, 40, 108, 71, 7)
        end

        -- draw message shadow
        print("you win!", sin(t()*0.5)*10+49, sin(t())*5+48, 6)

        -- draw message
        print("you win!", sin(t()*0.5)*10+48, sin(t())*5+47, 2)

        -- draw options
        win_lose_message(ticker)
        if new_pb then
            pb_message()
        end
    elseif lose then
        -- clear screen with grey background
        cls(themes[theme_select]["gamebg"])

        -- draw the map
        map(0, 0, xoff, yoff, width, height+1) 

        -- draw all dug spaces and flags
        draw_digs()
        draw_flags()
        foreach(explosions, draw_explosion)

        -- print time in top right corner
        print(mins..secs, 108, 1, 7)

        -- draw flag icon and count in top left corner
        spr(3, 0, 0)
        print(fcount, 8, 1, 7)
        
        -- draw explosion particles
        draw_particles()

        -- draw message box and border
        rectfill(18, 39, 109, 72, 9)
        rectfill(19, 40, 108, 71, 7)

        -- draw message shadow
        print("you lose...", sin(t()*0.5)*6+42, 47, 6)

        -- draw message
        print("you lose...", sin(t()*0.5)*6+43, 46, 2)
       
        -- draw options
        win_lose_message(ticker)
    elseif losing then
        -- clear screen with grey background
        cls(themes[theme_select]["gamebg"])

        -- print time in top right corner
        print(mins..secs, 108, 1, 7)

        -- draw flag icon and count in top left corner
        spr(3, 0, 0)
        print(fcount, 8, 1, 7)

        shake()

        -- draw the map
        map(0, 0, xoff, yoff, width, height+1) 

        -- draw all dug spaces and flags
        draw_digs()
        draw_flags()


        --foreach(mine_list, draw_mine)

        -- draw explosions
        foreach(explosions, draw_explosion)

        draw_particles()
    elseif difficulty then
        -- draw main frame and background
        if controller then
            draw_title_menu("❎ TO SELECT")
        elseif mouse then
            draw_title_menu("RETURN")
        end

        -- set a background for whichever option is currently selected
        if menu_y == 80 then
            -- option background
            rectfill(37, 81, 53, 87, 6)

            -- line connecting option and pb
            line(55, 84, 75, 84, 6)

            -- options
            print("easy", 38, 82, 7)
            print("medium", 38, 90, 6)
            print("hard", 38, 98, 6)

            -- pbs
            draw_pb("easy", 77, 82, 13)
            draw_pb("med", 77, 90, 6)
            draw_pb("hard", 77, 98, 6)
        elseif menu_y == 88 then
            rectfill(37, 89, 61, 95, 6)
            line(63, 92, 75, 92, 6)

            print("easy", 38, 82, 6)
            print("medium", 38, 90, 7)
            print("hard", 38, 98, 6)

            draw_pb("easy", 77, 82, 6)
            draw_pb("med", 77, 90, 13)
            draw_pb("hard", 77, 98, 6)
        elseif menu_y == 96 then
            rectfill(37, 97, 53, 103, 6)
            line(55, 100, 75, 100, 6)

            print("easy", 38, 82, 6)
            print("medium", 38, 90, 6)
            print("hard", 38, 98, 7)

            draw_pb("easy", 77, 82, 6)
            draw_pb("med", 77, 90, 6)
            draw_pb("hard", 77, 98, 13)
        else
            print("easy", 38, 82, 6)
            print("medium", 38, 90, 6)
            print("hard", 38, 98, 6)

            draw_pb("easy", 77, 82, 6)
            draw_pb("med", 77, 90, 6)
            draw_pb("hard", 77, 98, 6)
        end

        print("BEST", 77, 75, 6)

        -- if the player is hovering over an option, draw the flag next to it
        if menu_y != false then
            spr(3, menu_x, menu_y)
        end
    elseif play then
        -- clear screen with background
        cls(themes[theme_select]["gamebg"])

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
        map(0, 0, xoff, yoff, width, height+1) 

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
        if p.my != 0 then
            spr(17, p.x, p.y)
        end
    elseif menu then
        -- draw main frame and background
        if controller then
            draw_title_menu("❎ TO SELECT")
        elseif mouse then
            draw_title_menu()
        end
    
        -- set a background for whichever option is currently selected
        if menu_y == 80 then
            -- option background
            rectfill(37, 81, 53, 87, 6)

            -- options
            print("play", 38, 82, 7)
            print("guide", 38, 90, 6)
            print("options", 38, 98, 6)

            -- preview sprite
            sspr(0, 64, 24, 24, 76, 81)
        elseif menu_y == 88 then
            rectfill(37, 89, 57, 95, 6)

            print("play", 38, 82, 6)
            print("guide", 38, 90, 7)
            print("options", 38, 98, 6)
            
            sspr(24, 64, 24, 24, 76, 81)
        elseif menu_y == 96 then
            rectfill(37, 97, 65, 103, 6)

            print("play", 38, 82, 6)
            print("guide", 38, 90, 6)
            print("options", 38, 98, 7)

            sspr(48, 64, 24, 24, 76, 81)
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
        rectfill(75, 81, 81, 87, themes[theme_select]["main"])

        -- rounded corners
        --[[
        pset(75, 81, themes[theme_select]["bg"])
        pset(81, 81, themes[theme_select]["bg"])
        pset(75, 87, themes[theme_select]["bg"])
        pset(81, 87, themes[theme_select]["bg"])
        --]]

        pset(75, 81, 7)
        pset(81, 81, 7)
        pset(75, 87, 7)
        pset(81, 87, 7)

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
    spr(4, xoff+loc[1]*8-8, yoff+loc[2]*8)
end

function draw_flags()
    -- iterate through matrix and draw all placed flags
    for c1=1, #flags do
        for c2=1, #flags[c1] do
            if flags[c1][c2] == true then
                -- y value doesn't have -8 because the top bar accounts for it
                spr(3, xoff+c1*8-8, yoff+c2*8)
            end
        end
    end
end

function draw_digs()
    -- iterate through the matrix and draw all dug spaces
    for c1=1, #digs do
        for c2=1, #digs[c1] do
            if digs[c1][c2] then
                -- draw the coloured background
                rectfill(xoff+c1*8-8, yoff+c2*8, xoff+c1*8-1, yoff+c2*8+7, themes[theme_select]["main"])

                -- draw the number if needed
                if type(grid[c1][c2]) == "number" and grid[c1][c2] >= 1 then
                    print(grid[c1][c2], xoff+c1*8-5, yoff+c2*8+2, 7)
                end
            end
        end
    end
end

function draw_matrix()
    -- iterate through the matrix and draw all numbers
    -- for debug use
    for c1=1, #grid do
        for c2=1, #grid[c1] do
            if type(grid[c1][c2]) == "number" and grid[c1][c2] != 0 then
                print(grid[c1][c2], xoff+c1*8-5, yoff+c2*8+2, 8)
            end
        end
    end
end

function uncover(loc)
    -- dig the current space
    digs[loc[1]][loc[2]] = true

    -- if the current location is empty (no adjacent)
    if grid[loc[1]][loc[2]] == 0 then
        -- uncover all the spaces around it
        for pcol=-1, 1 do
            for prow=-1, 1 do
                if not (pcol == 0 and prow == 0) then
                    -- create a probe (an adjacent location to check)
                    local probe = {loc[1]+pcol, loc[2]+prow}

                    -- if the probe is within bounds
                    if
                    probe[1] >= 1 and
                    probe[1] <= width and
                    probe[2] >= 1 and
                    probe[2] <= height then
                        -- if that space hasn't already been dug, and doesn't have a flag, uncover it
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

function ensure(b)
    -- ignore right/left button presses
    if (b&1 > 0) or (b&2 > 0) then
        return true
    end

    -- ask the user to confirm their choice
    menuitem(2, "are you sure?", to_title)
    return true
end

function to_title(b)
    -- ignore right/left button presses
    if (b&1 > 0) or (b&2 > 0) then
        return true
    end

    -- set the option back to normal, and return to the menu
    menuitem(2, "return to title", ensure)
    play = false
    option = false
    guide = false
    menu_y = 80
    menu = true
end

function draw_title_menu(info_message)
    -- fill with accent background
    cls(themes[theme_select]["bg"])

    -- set to + draw pattern
    -- create background
    -- set back to normal fill
    fillp(◆)
    rectfill(0, 0, 128, 128, themes[theme_select]["main"])
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
    rectfill(19, 15, 108, 112, themes[theme_select]["accent"])
    rectfill(20, 16, 107, 111, 7)

    if info_message then
        if info_message == "RETURN" then
            rectfill(82, 112, 108, 118, themes[theme_select]["accent"])
            print(info_message, 84, 113, 7)
        else
            rectfill(59, 112, 108, 118, themes[theme_select]["accent"])
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
    rectfill(28, 24, 59, 31, themes[theme_select]["main"])
    print("m", 30, 26, 7)
    print("i", 38, 26)
    print("n", 46, 26)
    print("i", 54, 26)

    --rectfill(28, 32, 99, 63, 7)

    -- draw "mines" logo
    sspr(0, 32, 72, 32, 28, 32)

    print(ver, 100-string_l(ver), 26, 13)
end

function draw_guide(info_message)
    -- fill with accent background
    cls(themes[theme_select]["bg"])

    -- set to + draw pattern
    -- create background
    -- set back to normal fill
    fillp(◆)
    rectfill(0, 0, 128, 128, themes[theme_select]["main"])
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
    rectfill(10, 10, 118, 118, themes[theme_select]["accent"])
    rectfill(11, 11, 117, 117, 7)

    if info_message then
        if info_message == "RETURN" then
            rectfill(92, 119, 118, 123, themes[theme_select]["accent"])
            print(info_message, 94, 118, 7)
        else
            rectfill(69, 119, 118, 124, themes[theme_select]["accent"])
            print(info_message, 70, 119, 7)
        end
    end

    -- draw "mini" background and letters
    rectfill(18, 18, 34, 24, themes[theme_select]["main"])
    print("mini", 19, 19, 7)

    -- draw "mines"
    sspr(80, 32, 40, 8, 36, 17)
    
    print("❎ / left click TO dig\nrevealing no. of\nadjacent mines", 19, 27, themes[theme_select]["main"])
    
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

    rectfill(76, 76, 99, 91, themes[theme_select]["main"])
    rectfill(84, 76, 99, 99, themes[theme_select]["main"])
    rectfill(68, 84, 75, 107, themes[theme_select]["main"])
    rectfill(76, 100, 99, 107, themes[theme_select]["main"])

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

function win_lose_message(timer)
    if controller then
        -- draw a bar that fills up while the player holds the button
        if main then
            rectfill(21, 57, 21+48*timer/hold_timer, 63, 6)
        elseif alt then
            rectfill(21, 64, 21+80*timer/hold_timer, 70, 6)
        end

        -- draw options
        print("❎ to replay", 22, 58, 13)
        print("🅾️ to return to menu", 22, 65)
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
end

function draw_pb(diff, x, y, col)
    -- format the pb as needed
    if pb[diff] == false then
        pb_text = {"-", "-"}
    elseif pb[diff]%60 < 10 then
        pb_text = {tostr(pb[diff]\60), "0"..tostr(pb[diff]%60)}
    else
        pb_text = {tostr(pb[diff]\60), tostr(pb[diff]%60)}
    end

    -- display best score
    print(pb_text[1]..":"..pb_text[2], x, y, col)
end

function string_l(s)
    -- each character is 3 pixels, with a 1-pixel space between
    return (#s * 3) + (#s - 1)
end

-- bounce print: letters bounce like a wave
-- s: string
-- x and y: coords
-- t: speed
function bprint(s, x, y, col, t)
    if timer == t then
        timer = 0

        if bcount != #s then
            bcount += 1
        else
            bcount = 1
        end
    else
        timer += 1
    end

    local first = sub(s, 0, bcount-1)
    local letter = s[bcount]
    local last = sub(s, bcount+1)

    print(first, x, y, col)
    print(letter, x+(4*#first), y-1, col)
    print(last, x+(4*(#first))+4, y, col)
end

function draw_explosion(loc)
    spr(19, xoff+loc[1]*8-8, yoff+loc[2]*8)
end

function add_particles(loc)
    for i=1, flr(rnd(5))+1 do
        local x = xoff+loc[1]*8-4+flr(rnd(15))-7
        local y = yoff+loc[2]*8+4+flr(rnd(20))-7
        local col = flr(rnd(2))+1
        if col == 1 then
            col = 2
        elseif col == 2 then
            col = 4
        elseif col == 3 then
            col = 5
        end
        add(particles, {x, y, col})
    end
end

function draw_particles()
    for particle in all(particles) do
        pset(particle[1], particle[2], particle[3])
    end
end

function shake()
    local x = 16-rnd(32)
    local y = 16-rnd(32)

    x *= shake_strength
    y *= shake_strength

    camera(x, y)

    shake_strength *= 0.95
    if (shake_strength < 0.05) shake_strength = 0
end