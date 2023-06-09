function _init()
    -- *** DEBUG ***
    reveal = false -- reveal mines 
    fill = false -- show spaces
    grid_log = false -- print grid pos
    mouse_log = false -- print mouse coords
    title_only = false -- for gifs
    one_mine = false

    printh("", "log", true) -- clear log
    -- *************

    -- enable devkit mouse
    poke(0x5F2D, 1)

    -- enable save file
    cartdata("someguy17-mini-mines")
    -- 1-6: themes
    -- 7-9: PBs

    -- version number
    ver = "1.17.1"

    -- screens
    -- boot to title
    menu = true
    play = false
    difficulty = false
    option = false
    deleting = false
    guide = false

    -- falling icons on title
    icons = {}

    -- control scheme
    controller = true
    mouse = {false, 1}

    -- change controls in p8 menu
    menuitem(1, "control: gamepad", set_control)

    -- mouse x and y
    mo_x = 0
    mo_y = 0

    -- menu cursor x and y
    menu_c = 1

    -- prevents accidental key press
    main_stick = false

    -- pbs; retrieve from save data
    pb = {
        easy = false,
        med = false,
        hard = false
    }

    if dget(7) != 0 then
        pb["easy"] = dget(7)
    end

    if dget(8) != 0 then
        pb["med"] = dget(8)
    end

    if dget(9) != 0 then
        pb["hard"] = dget(9)
    end

    -- false if no
    -- difficulty if yes
    new_pb = false

    -- current colour theme
    ct = 1

    -- list of themes
    themes = {
        -- blue (white)
        {main = 12, bg = 7, accent = 1, gamebg = 13},
    }

    -- unlockable themes
    unlock = {
        -- unlock by playing easy mode
        easy = {
            -- orange (white)
            {main = 9, bg = 7, accent = 1, gamebg = 3, id = 1},

            -- red (white)
            {main = 8, bg = 7, accent = 0, gamebg = 0, id = 2}
        },

        -- unlock by playing medium mode
        med = {
            -- pink (white)
            {main = 14, bg = 7, accent = 8, gamebg = 2, id = 3},

            -- light green (dark green)
            {main = 11, bg = 3, accent = 5, gamebg = 3, id = 4}
        },

        -- unlock by playing hard mode
        hard = {
            -- brown (purple)
            {main = 4, bg = 2, accent = 1, gamebg = 3, id = 5},

            -- beige (purple)
            {main = 15, bg = 7, accent = 13, gamebg = 4, id = 6}
        }
    }

    for diff_name, diff_themes in pairs(unlock) do
        local count = 0
        for theme in all(diff_themes) do
            count += 1
            if dget(theme["id"]) == 1 then
                -- add new theme
                add(themes, theme)
                -- remove from list
                del(unlock[diff_name], theme)
            end
        end
    end

    -- new theme unlocked?
    new_theme = false

    win_count = {
        easy = 0,
        med = 0,
        hard = 0
    }

    -- title option coords
    tc = {
        {37, 81, 53, 87},
        {37, 89, 57, 95},
        {37, 97, 65, 103}
    }

    -- difficulty/pb coords
    dc = {
        {37, 81, 53, 87},
        {37, 89, 61, 95},
        {37, 97, 53, 103}
    }

    pbc = {
        {55, 84, 75, 84},
        {63, 92, 75, 92},
        {55, 100, 75, 100}
    }

    -- option menu coords
    oc = {
        {37, 79, 57, 85},
        {37, 90, 65, 96},
        {37, 101, 81, 107}
    }

    -- flashing on guide page
    mine_flash = 0
    show_mines = false

    -- bouncing letters
    bcount = 1
    timer = 0

    -- hold to action on win/loss
    hold_timer = 2
    ticker = 0

    -- frames between explosions
    explosion_interval = 5

    -- wait counter and actual time for post-explosion
    wait = 0
    final_wait = 25

    -- screen shake strength
    shake_strength = 0

    -- hide win/loss screen
    hide = false

    -- guide page
    page = 1
end

function initialise(diff)
    play = true
    sfx(9)

    time = 0

    -- current difficulty
    size = diff
    
    if diff == "easy" then
        w = 7 -- width of board
        h = 7 -- height of board
        mcount = 5 -- number of mines

        -- player
        p = {
            -- pixel coords
            x = 60,
            y = 64,

            -- map coords
            mx = 4,
            my = 4
        }

        -- grid limits
        xlim = {36, 84}
        ylim = {40, 88}
    elseif diff == "med" then
        w = 11
        h = 11
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
        w = 16
        h = 15
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

    -- DEBUG
    if one_mine then
        mcount = 1
    end

    -- x and y offsets
    xoff = 64-(8*w/2)
    yoff = 60-(8*h/2)

    -- available flags
    fcount = mcount

    -- correctly placed flags
    ccount = 0

    win = false
    lose = false
    winning = false
    losing = false

    mine_list = {}
    explosions = {}
    particles = {}

    -- 0 = empty; num = no. adj mines; true = mine
    grid = gen_matrix(0)

    -- false = no flag; true = flag
    flags = gen_matrix(false)

    -- false = not dug; true = dug
    digs = gen_matrix(false)

    -- player's first dig?
    -- wait to create mine list
    first = true

    -- show win/loss screen by default
    hide = false
end

function _update()
    -- remove "return to title" by default
    menuitem(2)

    if controller then
        -- control scheme
        main = btn(5)
        alt = btn(4)

        menuitem(1, "control: gamepad", set_control)

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
    elseif mouse[1] then
        -- positions
        mo_x = stat(32)
        mo_y = stat(33)

        menuitem(1, "control: mouse "..mouse[2], set_control)

        -- left and right click
        if play and mouse[2] == 1 then
            main = stat(34) == 2
            alt = stat(34) == 1
        else
            main = stat(34) == 1
            alt = stat(34) == 2
        end

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
            -- hide or show win/loss screen
            if btnp(3) and not hide then
                hide = true
                sfx(11)
            elseif btnp(2) and hide then
                hide = false
                sfx(12)
            end

            if not hide then
                -- x for replay
                if main then
                    -- if holding, increase bar
                    if main_stick then
                        ticker += 0.1
                        sfx(13)
                    -- if let go, reset bar
                    else
                        main_stick = true
                        ticker = 0
                    end

                    -- if the bar is full, reset the game
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
                    -- same bar system as above
                    if alt_stick then
                        ticker += 0.1
                        sfx(13)
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

                        sfx(6)

                        menu_c = 1
                        menu = true
                    end
                else
                    ticker = 0
                end
            end
        elseif mouse[1] then
            -- hover bounds
            hover_replay = hover(36, 57, 60, 63)
            hover_quit = hover(36, 64, 92, 70)
            
            -- hide bounds change depending on whether screen is already hidden or not
            if not hide then
                if new_theme then
                    hover_hide = hover(92, 88, 109, 93)
                else
                    hover_hide = hover(92, 72, 109, 77)
                end
            else
                hover_hide = hover(111, 122, 127, 127)
            end

            -- if left clicking
            if main and not main_stick then
                main_stick = true
                alt_stick = true

                if hover_replay and not hide then
                    win = false
                    lose = false

                    new_pb = false
                    new_theme = false

                    initialise(size)
                elseif hover_quit and not hide then
                    win = false
                    lose = false
                    play = false

                    new_pb = false
                    new_theme = false

                    sfx(6)

                    menu = true
                elseif hover_hide then
                    -- if pressing "hide"
                    if not hide then
                        sfx(11)
                        hide = true

                    -- if pressing "show"
                    elseif hide then
                        sfx(12)
                        hide = false
                    end
                end
            end
        end
    elseif winning then
        -- if the shine hasn't left the screen yet, move it across
        if shine-(8*w)-2 < xoff+(8*w)+120 then
            shine += 10
        -- once off the screen, show the win screen
        else
            winning = false
            win = true
        end
    elseif losing then
        -- hold x to speed up explosions
        if main and not main_stick then
            explosion_timer = explosion_interval
        end

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
                -- indicator of whether the sound has been played for it or not
                add(target, false)

                -- indicator of sprite phase
                add(target, 0)

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

        -- if a sound hasn't been played for an explosion, play it
        for explosion in all(explosions) do
            if not explosion[3] and #explosions > 1 then
                sfx(7)
                explosion[3] = true
            end

            if explosion[4] <= 5 then
                explosion[4] += 1
            end
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
            if btnp(3) and menu_c != 3 then
                sfx(4)
                menu_c += 1
            elseif btnp(2) and menu_c != 1 then
                sfx(4)
                menu_c -= 1
            end
        elseif mouse[1] then
            -- bounds for "play" and "options" on main menu
            hover_easy = hover(37, 81, 53, 87)
            hover_medium = hover(37, 89, 61, 95)
            hover_hard = hover(37, 97, 53, 103)
            hover_return_difficulty = hover(82, 113, 108, 118)

            -- set cursor position if hovering over an option
            if hover_easy then
                menu_c = 1
            elseif hover_medium then
                menu_c = 2
            elseif hover_hard then
                menu_c = 3
            else
                menu_c = false
            end
        end

        -- x to select option
        if main and not main_stick then
            main_stick = true
            alt_stick = true

            -- difficulty selection
            if menu_c == 1 then
                difficulty = false
                play = true
                initialise("easy")
            elseif menu_c == 2 then
                difficulty = false
                play = true
                initialise("med")
            elseif menu_c == 3 then
                difficulty = false
                play = true
                initialise("hard")
            elseif mouse[1] and hover_return_difficulty then
                sfx(6)
                difficulty = false
                menu = true
            end
        end

        -- o to return to title
        if controller and alt and not alt_stick then
            alt_stick = true

            -- disable difficulty menu
            difficulty = false
            sfx(6)

            -- go back to main menu
            menu_c = 1
            menu = true
        end
    elseif play then
        -- if in game, add the "return to title" option
        menuitem(2, "return to title", ensure)

        -- if the player has started the game (dug their first space)
        if not first then
            -- only record time once game has started
            time = flr(t()) - record

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
                winning = true
                play = false
                sfx(10)

                -- set position of shine
                shine = xoff-1

                -- record the pb if needed
                if pb[size] == false or (time < pb[size]) then
                    pb[size] = time
                    if size == "easy" then
                        dset(7, time)
                    elseif size == "med" then
                        dset(8, time)
                    elseif size == "hard" then
                        dset(9, time)
                    end

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
                #unlock[size] != 0 then
                    -- record the unlock in the user's save file
                    dset(unlock[size][1]["id"], 1)

                    -- add the new theme to the player's collection
                    add(themes, unlock[size][1])

                    -- new theme unlocked
                    new_theme = unlock[size][1]

                    -- remove it from the original list
                    del(unlock[size], unlock[size][1])
                end
            end
        end

        -- check if the player is within the grid
        -- if not, they won't be able to dig or flag
        in_bound = (1 <= p.mx and p.mx <= w) and (1 <= p.my and p.my <= h)
        
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
        elseif mouse[1] then
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
                mine_list = create_mines(w, h, mcount, {p.mx, p.my})

                -- change all the mine positions to true
                for mine in all(mine_list) do
                    --printh(mine[1]..", "..mine[2], "log", false)
                    grid[mine[1]][mine[2]] = true
                end

                -- fill in the rest of the spaces with numbers for adjacent mines
                grid = fill_adj(grid, w, h)

                first = false
                record = flr(t())
            end

            -- don't try and dig a space with a flag
            if flags[p.mx][p.my] != true then
                -- if the dug space is in the mine list, the player has lost
                if check_loss({p.mx, p.my}) then
                    init_loss({p.mx, p.my})
                end

                -- if there isn't a mine there, dig that space
                if not losing then
                    --printh("", "log", true)

                    -- if that space has already been dug, and there's a number there
                    if
                    type(grid[p.mx][p.my]) == "number" and
                    digs[p.mx][p.my] == true then
                        sfx(2)

                        -- uncover all the spaces around it
                        for pcol=-1, 1 do
                            for prow=-1, 1 do
                                if not (pcol == 0 and prow == 0) then
                                    -- create a probe (an adjacent location to check)
                                    local probe = {p.mx+pcol, p.my+prow}
                                    -- if the probe is within bounds
                                    if
                                    probe[1] >= 1 and
                                    probe[1] <= w and
                                    probe[2] >= 1 and
                                    probe[2] <= h then
                                        -- uncover if there isn't a flag
                                        if flags[probe[1]][probe[2]] == false then
                                            uncover(probe)
                                        end
                                    end
                                end
                            end
                        end

                        -- if any mines were found by auto-dig, add them to the list
                        if #explosions > 0 then
                            losing = true
                            play = false
                            main_stick = true
                            alt_stick = true
                            
                            -- leave a pause before exploding
                            explosion_timer = flr(-2.5*explosion_interval)
                            explosion_counter = 0
                        end
                    end

                    -- if that space hasn't already been dug, play sfx
                    if digs[p.mx][p.my] != true then
                        sfx(2)

                        -- chain-uncover the rest of the spaces
                        uncover({p.mx, p.my})
                    end
                end
            end
        end
    elseif menu then
        if controller then
            -- movement
            if btnp(3) and menu_c != 3 then
                sfx(4)
                menu_c += 1
            elseif btnp(2) and menu_c != 1 then
                sfx(4)
                menu_c -= 1
            end
        else
            -- bounds for "play" and "options" on main menu
            hover_play = hover(37, 81, 53, 87)
            hover_guide = hover(37, 89, 57, 95)
            hover_options = hover(37, 97, 65, 103)

            -- set cursor position if hovering over an option
            if hover_play then
                menu_c = 1
            elseif hover_guide then
                menu_c = 2
            elseif hover_options then
                menu_c = 3
            else
                menu_c = false
            end
        end

        -- x to select option
        if main and not main_stick then
            main_stick = true

            if menu_c == 1 then -- play
                sfx(5)
                menu = false
                difficulty = true
            elseif menu_c == 2 then -- guide
                sfx(5)
                menu = false
                guide = true
            elseif menu_c == 3 then -- options
                sfx(5)
                menu = false
                option = true
                menu_c = 1
            end
        end
    elseif guide then
        if mine_flash != 30 then
            mine_flash += 1
        else
            mine_flash = 0
            show_mines = not show_mines
        end

        -- return to title screen
        if controller then
            if btnp(1) and page != 2 then
                sfx(4)
                page = 2
            elseif btnp(0) and page != 1 then
                sfx(4)
                page = 1
            end

            -- o to return
            if alt and not alt_stick then
                sfx(6)
                alt_stick = true
                guide = false
                page = 1
                menu = true
            end
        else
            -- bounds for "return" in guide menu
            hover_return_guide = hover(92, 119, 118, 123)
            hover_p1 = hover(110, 63, 118, 69)
            hover_p2 = hover(10, 63, 18, 69)

            if main and not main_stick then
                if hover_return_guide then
                    sfx(6)
                    main_stick = true
                    guide = false
                    page = 1
                    menu = true
                elseif hover_p1 and page == 1 then
                    sfx(4)
                    main_stick = true
                    page = 2
                elseif hover_p2 and page == 2 then
                    sfx(4)
                    main_stick = true
                    page = 1
                end
            end
        end
    elseif option then
        if controller then
            -- movement
            if btnp(3) and menu_c != 3 then
                sfx(4)
                menu_c += 1
            elseif btnp(2) and menu_c != 1 then
                sfx(4)
                menu_c -= 1
            end
        elseif mouse[1] then
            -- bounds for "play" and "options" on main menu
            hover_theme = hover(37, 79, 57, 85)
            hover_control = hover(37, 90, 65, 96)
            hover_del_save = hover(37, 101, 81, 107)
            hover_return_options = hover(82, 113, 108, 118)

            -- set cursor position if hovering over an option
            if hover_theme then
                menu_c = 1
            elseif hover_control then
                menu_c = 2
            elseif hover_del_save then
                menu_c = 3
            else
                menu_c = false
            end
        end

        -- x to select option
        if main and not main_stick then
            main_stick = true

            if menu_c == 1 then
                if #themes != 1 then sfx(14) end

                -- change theme
                ct = (ct!=#themes and ct+1 or 1)
            elseif menu_c == 2 then
                sfx(5)
                -- switch to mouse
                if controller then
                    controller = false
                    mouse[1] = true
                    mouse[2] = 1
                elseif mouse[2] == 1 then
                    -- change to mouse scheme 2
                    mouse[2] = 2
                else
                    -- change to controller
                    mouse[1] = false
                    controller = true
                end
            elseif menu_c == 3 then
                sfx(5)
                -- go to delete save data screen
                option = false
                deleting = true
                if controller then
                    control_store = "controller"
                else
                    -- only allow controller
                    -- if using mouse, remember that and put it back on after
                    controller = true
                    mouse[1] = false
                    control_store = "mouse"
                end
            elseif mouse[1] and hover_return_options then
                sfx(6)
                options = false
                menu = true
            end
        -- o to return to menu
        elseif controller and alt and not alt_stick then
            alt_stick = true
            sfx(6)

            option = false
            menu = true

            -- place cursor on "options"
            menu_c = 3
        end
    elseif deleting then
        -- x to delete
        if main then
            -- if holding, increase bar
            if main_stick then
                ticker += 0.1
                sfx(13)
            -- if let go, reset bar
            else
                main_stick = true
                ticker = 0
            end

            -- if the bar is full, delete save
            if flr(ticker) == (hold_timer*2) then
                ticker = 0

                -- delete save data
                for c=0, 9 do
                    dset(c, 0)
                end

                -- reset the cart
                run()
            end
        else
            ticker = 0
        end

        -- o to return to options
        if alt and not alt_stick then
            alt_stick = true
            sfx(6)

            option = true
            deleting = false

            -- return to original control method
            if control_store == "controller" then
                menu_c = 3
            elseif control_store == "mouse" then
                controller = false
                mouse[1] = true
            end
        end
    end
end

function _draw()
    if title_only then
        -- draw background
        draw_menu_background()

        -- draw background and border
        draw_menu_border(20, 34, 107, 89)

        -- draw "mini mines"
        rectfill(28, 41, 59, 48, themes[ct]["main"])
        sspr(80, 40, 32, 8, 28, 41)
        sspr(0, 32, 72, 32, 28, 50)
    elseif win or lose then
        -- draw the win or loss screen
        draw_win_loss(win)
    elseif winning then
        -- clear screen with grey background
        cls(themes[ct]["gamebg"])

        -- print time in top right corner
        print(mins..secs, 108, 1, 7)

        -- draw flag icon and count in top left corner
        spr(3, 0, 0)
        print(fcount, 8, 1, 7)

        -- draw the map
        map(0, 0, xoff, yoff, w, h+1)

        -- draw all dug spaces and flags
        draw_digs()
        draw_flags()

        -- draw the win shine
        line(shine-3, 8+yoff, shine-(8*w)-2, 8+yoff+(8*h)-1, 6)
        line(shine-2, 8+yoff, shine-(8*w)-1, 8+yoff+(8*h)-1, 7)
        line(shine-1, 8+yoff, shine-(8*w), 8+yoff+(8*h)-1, 7)
        line(shine, 8+yoff, shine-(8*w)+1, 8+yoff+(8*h)-1, 7)

        -- don't need to cover sides on hard mode
        if size != "hard" then
            -- cover up the sides of the game grid to hide the shine
            rectfill(0, 8, xoff-1, 128, themes[ct]["gamebg"])
            rectfill(xoff+(8*w), 8, 128, 128, themes[ct]["gamebg"])
        end
    elseif losing then
        -- reset the camera so top bar isn't affected by shake
        camera(0, 0)

        -- clear screen with grey background
        cls(themes[ct]["gamebg"])

        -- print time in top right corner
        print(mins..secs, 108, 1, 7)

        -- draw flag icon and count in top left corner
        spr(3, 0, 0)
        print(fcount, 8, 1, 7)

        -- if there are any explosions to do, shake the screen
        if #explosions > 1 then
            shake()
        end

        -- draw the map
        map(0, 0, xoff, yoff, w, h+1) 

        -- draw all dug spaces and flags
        draw_digs()
        draw_flags()

        if reveal then
            foreach(mine_list, draw_mine)
        end

        -- are all explosions the first ones? (can be multiple through auto-dig)
        local flag = true
        for exp in all(explosions) do
            if exp[3] != "first" then
                flag = false
            end
        end

        -- if so, then only show the mine, not the explosion
        -- creates a moment before they all start exploding
        if flag then
            for exp in all(explosions) do
                draw_mine(exp)
            end
        else
            -- draw explosions
            foreach(explosions, draw_explosion)
            draw_particles()
        end
    elseif difficulty then
        -- draw main frame and background
        if controller then
            draw_title_menu("❎ TO SELECT")
        elseif mouse[1] then
            draw_title_menu("RETURN")
        end

        draw_difficulty(menu_c)
    elseif play then
        -- clear screen with background
        cls(themes[ct]["gamebg"])

        -- record current seconds
        -- add leading 0 if needed
        secs = (time%60<10 and ":0" or ":")..time % 60

        -- record current mins
        -- add leading space if needed
        mins = (time\60<10 and " " or "")..time \ 60

        -- draw flag icon and count in top left corner
        spr(3, 0, 0)
        print(fcount, 8, 1, 7)

        -- print control hints in the middle
        if controller then
            print("❎-flag   🅾️-dig", 30, 1, themes[ct]["accent"])
        elseif mouse[2] == 2 then
            print("l-dig   r-flag", 34, 1, themes[ct]["accent"])
        else
            print("l-flag   r-dig", 34, 1, themes[ct]["accent"])
        end

        -- print time in top right corner
        print(mins..secs, 108, 1, 7)

        -- draw the map
        map(0, 0, xoff, yoff, w, h+1) 

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
        if p.my > 0 then
            spr(17, p.x, p.y)
        end
    elseif menu then
        -- draw main frame and background
        if controller then
            draw_title_menu("❎ TO SELECT")
        elseif mouse[1] then
            draw_title_menu()
        end
    
        -- set a background for whichever option is currently selected
        -- if the player is hovering over an option, draw the flag next to it
        draw_title_options(menu_c)
    elseif guide then
        if controller then
            -- draw the guide with the controller prompt
            draw_guide("🅾️ TO RETURN")
        elseif mouse[1] then
            -- draw the guide with the mouse prompt
            draw_guide("RETURN")
        end
    elseif option then
        -- draw main frame and background
        if controller then
            draw_title_menu("🅾️ TO RETURN")
        elseif mouse[1] then
            draw_title_menu("RETURN")
        end
        
        -- set a background for whichever option is currently selected
        draw_option_options(menu_c)

        -- theme preview
        rectfill(75, 79, 81, 85, themes[ct]["main"])
        spr(35, 75, 79)

        -- theme counter
        print(ct.."/"..#themes, 90, 80, 13)

        -- draw controller/mouse sprite
        if controller then
            spr(34, 75, 90)
        elseif mouse[2] == 1 then
            spr(49, 75, 90)
        else
            spr(50, 75, 90)
        end
    elseif deleting then
        -- draw main frame and background
        draw_title_menu("🅾️ TO RETURN")

        print("ARE YOU SURE\nYOU WANT TO\ndelete save data?", 25, 78, 0)

        if main then
            rectfill(27, 99, 27+(49*ticker/(hold_timer*2)), 105, 6)
        end
        print("❎ TO delete", 28, 100, 13)
    end

    -- if mouse control is enabled, draw the cursor
    if mouse[1] then
        spr(20, mo_x, mo_y)
    end

    -- debug: print mouse and/or grid coords
    draw_coords()
end

-- *** EXTRA FUNCTIONS ***

-- ** INITIALISNG **
function gen_matrix(fill)
-- generate a matrix using the h and w
-- can fill each position with a value
    m = {}
    for c1=1, w do
        local column = {}
        for c2=1, h do
            add(column, fill)
        end
        add(m, column)
    end
    return m
end



-- ** MODIFYING **
function uncover(loc)
-- recursively uncover a space, and all other spaces around it
    -- if the location passed in is a mine, add it to the explosion list
    if check_loss(loc) then
        add(explosions, {loc[1], loc[2], "first", 0})
        del(mine_list, {loc[1], loc[2]})
        add_particles({loc[1], loc[2]})
        sfx(8)
    
    -- if it wasn't a mine, dig the current space
    elseif not losing then
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
                        probe[1] <= w and
                        probe[2] >= 1 and
                        probe[2] <= h then
                            -- if that space hasn't already been dug, and doesn't have a flag, uncover it
                            if 
                            digs[probe[1]][probe[2]] != true and
                            flags[probe[1]][probe[2]] != true then
                                uncover(probe)
                            end
                        end
                    end
                end
            end
        end
    end
end

function add_particles(loc)
-- generate particles for an explosion
    -- up to 10 particles per explosion
    for i=1, flr(rnd(10))+1 do
        -- place it randomly around the explosion centre
        local x = xoff+loc[1]*8-4+flr(rnd(16))-8
        local y = yoff+loc[2]*8+4+flr(rnd(16))-8

        -- pick a colour
        local col = flr(rnd(2))+1
        if col == 1 then
            col = 2 -- purple
        elseif col == 2 then
            col = 4 -- brown
        elseif col == 3 then
            col = 5 -- dark green
        end

        -- add the particle to the list
        add(particles, {x, y, col})
    end
end

function check_loss(loc)
-- check if a dig results in a loss (clicked a mine)
    for mine in all(mine_list) do
        if mine[1] == loc[1] and mine[2] == loc[2] then
            -- if a mine, return true
            return true
        end
    end

    -- if no mines, return false
    return false
end

function init_loss(loc)
-- switch to losing animation
    -- the player loses
    losing = true
    play = false
    main_stick = true
    alt_stick = true

    -- make sure the current mine explodes first
    add(explosions, {loc[1], loc[2], "first", 0})
    del(mine_list, {loc[1], loc[2]})
    add_particles({loc[1], loc[2]})
    sfx(8)

    explosion_timer = flr(-2.5*explosion_interval)
    explosion_counter = 0
end



-- ** DRAWING **

-- ** Menus **
function draw_menu_background()
-- draw the menu background and falling icons
    -- fill with accent background
    cls(themes[ct]["bg"])

    -- set to + draw pattern
    -- create background
    -- set back to normal fill
    fillp(◆)
    rectfill(0, 0, 128, 128, themes[ct]["main"])
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
end

function draw_menu_border(x1, y1, x2, y2, col)
-- draw background and border
    rectfill(x1-1, y1-1, x2+1, y2+1, col)
    rectfill(x1, y1, x2, y2, 7)
end

function draw_title_menu(info_message)
-- draw the title screen
    -- draw the background and falling icons
    draw_menu_background()

    -- draw background and border
    draw_menu_border(20, 16, 107, 111, themes[ct]["accent"])

    -- if an info message was passed in, draw it appropriately
    if info_message then
        if info_message == "RETURN" then
            rectfill(82, 112, 108, 118, themes[ct]["accent"])
            print(info_message, 84, 113, 7)
        else
            rectfill(59, 112, 108, 118, themes[ct]["accent"])
            print(info_message, 60, 113, 7)
        end
    end

    -- draw grid as title background
    map(0, 0, 20, 8, 11, 8)

    -- draw "mini" background and letters
    rectfill(28, 24, 59, 31, themes[ct]["main"])
    sspr(80, 40, 32, 8, 28, 24)

    -- draw "mines" logo
    sspr(0, 32, 72, 32, 28, 32)

    -- draw the version number
    print(ver, 100-string_l(ver), 26, 13)
end

function draw_title_options(c)
-- draw title options
    if c then
        -- option background
        rectfill(tc[c][1], tc[c][2], tc[c][3], tc[c][4], 6)
        
        -- preview sprite
        sspr(c*24-24, 64, 24, 24, 76, 81)
        
        -- flag
        spr(3, 28, 80+8*c-8)
    end

    -- options
    print("play", 38, 82, c==1 and 7 or 6)
    print("guide", 38, 90, c==2 and 7 or 6)
    print("options", 38, 98, c==3 and 7 or 6)

end

function draw_difficulty(c)
-- draw difficulty options
    if c then
        -- option background
        rectfill(dc[c][1], dc[c][2], dc[c][3], dc[c][4], 6)

        -- line connecting option and pb
        line(pbc[c][1], pbc[c][2], pbc[c][3], pbc[c][4], 6)

        -- flag cursor
        spr(3, 28, 80+8*c-8)
    end

    print("BEST", 77, 75, 6)

    -- options
    print("easy", 38, 82, c == 1 and 7 or 6)
    print("medium", 38, 90, c == 2 and 7 or 6)
    print("hard", 38, 98, c == 3 and 7 or 6)

    -- pbs
    draw_pb("easy", 77, 82, c == 1 and 13 or 6)
    draw_pb("med", 77, 90, c == 2 and 13 or 6)
    draw_pb("hard", 77, 98, c == 3 and 13 or 6)
end

function draw_pb(diff, x, y, col)
-- draw personal best
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

function draw_guide(info_message)
-- draw the guide screen
    -- draw background and falling icons
    draw_menu_background()

    -- draw background and border
    draw_menu_border(11, 11, 117, 117, themes[ct]["accent"])

    -- if an info messaeg was passed in, draw it appropriately
    if info_message then
        if info_message == "RETURN" then
            rectfill(92, 119, 118, 123, themes[ct]["accent"])
            print(info_message, 94, 118, 7)
        else
            rectfill(69, 119, 118, 124, themes[ct]["accent"])
            print(info_message, 70, 119, 7)
        end
    end

    -- draw "mini" background and letters
    rectfill(18, 18, 34, 24, themes[ct]["main"])
    print("mini", 19, 19, 7)

    -- draw "mines"
    sspr(80, 32, 40, 8, 36, 17)

    -- page 1
    if page == 1 then
        print("❎ / right click TO dig\nrevealing no. of\nadjacent mines", 19, 27, themes[ct]["main"])
        
        print("🅾️ / left click TO flag\nto mark a mine", 19, 48, 8)

        -- draw grid border
        rect(27, 67, 100, 108, 13)

        -- draw grid
        map(0, 0, 28, 60, 9, 6)

        print("FLAG ALL MINES TO WIN!", 22, 110, 0)

        -- timer alternates between hiding and showing mines
        if show_mines then
            spr(4, 68, 76)
            spr(4, 76, 92)
            spr(4, 36, 92)
        end

        -- fill in spaces on sample grid
        rectfill(76, 76, 99, 91, themes[ct]["main"])
        rectfill(84, 76, 99, 99, themes[ct]["main"])
        rectfill(68, 84, 75, 107, themes[ct]["main"])
        rectfill(76, 100, 99, 107, themes[ct]["main"])

        -- draw numbers
        sspr(0, 96, 24, 36, 68, 76)

        -- flag sprite
        spr(3, 76, 92)

        -- arrow to move to next page
        rectfill(110, 63, 118, 69, themes[ct]["accent"])
        print("➡️", 111, 64, 7)
    -- page 2
    elseif page == 2 then
        print("UNLOCK themes BY BEATING\nYOUR best times!\n", 19, 27, themes[ct]["main"])
        sspr(72, 0, 94, 5, 47, 27) -- colourful "themes"
        
        print("CHANGE controls\nIN options OR\npico-8 menu!", 22, 45)
        print("controls", 50, 45, themes[ct]["accent"])
        spr(33, 90, 48) -- mouse icon
        spr(34, 99, 48) -- controller icon

        print("HOLD ❎ OR lC to\nexplode faster!", 22, 69, 4)
        spr(19, 95, 69) -- crator icon
        spr(6, 100, 72) -- mini-explosion icon

        print("re-dig TO dig\nsurrounding\nspaces!", 22, 90, 0)
        spr(18, 94, 96) -- dug space icon
        spr(154, 94, 96) -- "1" icon
        
        -- repurpose timer to flash auto-dig spaces
        if show_mines then
            -- fill in dug spaces
            rectfill(86, 88, 101, 111, themes[ct]["main"])
            rectfill(102, 88, 109, 103, themes[ct]["main"])
            sspr(72, 64, 24, 24, 86, 88) -- auto-dig spaces sprites
        end
        
        spr(17, 94, 96) -- cursor sprite
        
        -- arrow to move to previous page
        rectfill(10, 63, 18, 69, themes[ct]["accent"])
        print("⬅️", 11, 64, 7)
    end
end

function draw_option_options(c)
-- draw options menu options
    if c then
        -- option background
        rectfill(oc[c][1], oc[c][2], oc[c][3], oc[c][4], 6)

        -- flag cursor
        spr(3, 28, 78+11*c-11)
    end
    
    print("theme", 38, 80, c==1 and 7 or 6)
    print("control", 38, 91, c==2 and 7 or 6)
    print("delete save", 38, 102, c==3 and 0 or 2)

end

function draw_win_loss(win)
-- draw the win/loss window
    -- clear screen with grey background
    cls(themes[ct]["gamebg"])

    -- draw the map
    map(0, 0, xoff, yoff, w, h+1) 

    -- draw all dug spaces and flags
    draw_digs()
    draw_flags()
    foreach(explosions, draw_explosion) -- explosions too, if lost
    draw_particles()

    -- print time in top right corner
    print(mins..secs, 108, 1, 7)

    -- draw flag icon and count in top left corner
    spr(3, 0, 0)
    print(fcount, 8, 1, 7)

    -- the actual window
    if not hide then
        -- if a new theme was just unlocked
        if type(new_theme) == "table" then
            -- draw message box and border with extra space for theme info
            draw_menu_border(19, 40, 108, 87, 9)
            
            bprint("new theme!", 37, 76, new_theme["accent"], 3)

            -- theme preview
            rectfill(82, 75, 88, 81, new_theme["main"])
            spr(35, 82, 75)

            if controller then
                rectfill(80, 88, 109, 94, 9)
                print("⬇️ HIDE", 81, 89, 7)
            elseif mouse[1] then
                rectfill(92, 88, 109, 93, 9)
                print("HIDE", 93, 88, 7)
            end
        else
            -- draw message box and border normally
            draw_menu_border(19, 40, 108, 71, 9)

            if controller then
                rectfill(80, 72, 109, 78, 9)
                print("⬇️ HIDE", 81, 73, 7)
            elseif mouse[1] then
                rectfill(92, 72, 109, 77, 9)
                print("HIDE", 93, 72, 7)
            end
        end

        if win then
            -- draw message shadow
            print("you win!", sin(t()*0.5)*10+49, sin(t())*5+48, 6)
    
            -- draw message
            print("you win!", sin(t()*0.5)*10+48, sin(t())*5+47, 2)
    
            if new_pb then
                pb_message()
            end
        else
            -- draw message shadow
            print("you lose...", sin(t()*0.5)*6+42, 47, 6)
    
            -- draw message
            print("you lose...", sin(t()*0.5)*6+43, 46, 2)
        end
    
        -- draw options
        win_lose_message(ticker)
    else
        if controller then
            rectfill(99, 121, 127, 127, 9)
            print("⬆️ SHOW", 100, 122, 7)
        elseif mouse[1] then
            rectfill(111, 122, 127, 127, 9)
            print("SHOW", 112, 122, 7)
        end
    end
end

function pb_message()
-- draw the "new PB" message
    sspr(72, 8, 13, 15, 113, flr(sin(t()))+8)
end

function win_lose_message(timer)
-- draw the win/loss options
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
    elseif mouse[1] then
        -- set a background for whichever option is currently selected
        if hover_replay then
            rectfill(36, 57, 60, 63, 6)

            print("replay", 37, 58, 13)
            print("return to menu", 37, 65)
        elseif hover_quit then
            rectfill(36, 64, 92, 70, 6)

            print("replay", 37, 58, 13)
            print("return to menu", 37, 65)
        else
            print("replay", 37, 58, 13)
            print("return to menu", 37, 65)
        end
    end
end

function bprint(s, x, y, col, t)
-- print some text, but make the letters periodically bounce like a wave
    -- s: string
    -- x and y: coords
    -- t: speed

    -- increment a timer
    if timer == t then
        timer = 0

        -- increment the letter to bounce
        if bcount != #s then
            bcount += 1
        else
            bcount = 1
        end
    else
        timer += 1
    end

    -- substrings
    local first = sub(s, 0, bcount-1)
    local letter = s[bcount]
    local last = sub(s, bcount+1)

    -- print each one, moving the bounced letter up a bit
    print(first, x, y, col)
    print(letter, x+(4*#first), y-1, col)
    print(last, x+(4*(#first))+4, y, col)
end


-- ** In-game **
function draw_mine(loc)
-- draw a mine
    spr(4, xoff+loc[1]*8-8, yoff+loc[2]*8)
end

function draw_flags()
-- draw all placed flags
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
-- draw all dug spaces
    for c1=1, #digs do
        for c2=1, #digs[c1] do
            if digs[c1][c2] then
                -- draw the coloured background
                rectfill(xoff+c1*8-8, yoff+c2*8, xoff+c1*8-1, yoff+c2*8+7, themes[ct]["main"])

                -- draw the number if needed
                if type(grid[c1][c2]) == "number" and grid[c1][c2] >= 1 then
                    print(grid[c1][c2], xoff+c1*8-5, yoff+c2*8+2, 7)
                end
            end
        end
    end
end

function draw_explosion(exp)
-- draw an explosion (multi-phase)
    -- position
    local x = xoff+exp[1]*8-8
    local y = yoff+exp[2]*8

    -- first phase: initial blast
    if exp[4] < 2 then
        spr(6, x, y)

    -- second phase: big blast
    elseif exp[4] <= 5 then
        sspr(56, 0, 16, 16, x-4, y-4)
    
    -- third phase: crater
    else
        spr(19, x, y)
    end
end

function draw_particles()
-- draw particles
    for particle in all(particles) do
        pset(particle[1], particle[2], particle[3])
    end
end

function shake()
-- apply screen shake
    -- screen position
    local x = 20-rnd(40)
    local y = 20-rnd(40)

    -- apply strength
    x *= shake_strength
    y *= shake_strength

    -- move the camera
    camera(x, y)

    -- decay the shake scrength
    shake_strength *= 0.75
    if (shake_strength < 0.05) shake_strength = 0
end



-- ** MENUITEMS **
function set_control(b)
-- control scheme menuitem
    -- ignore left/right inputs
    if(b&1 > 0) or (b&2 > 0) then
        return true
    end

    -- x to select control scheme
    if controller then
        menuitem(1, "control: mouse 1")
        mouse[1] = true -- enable mouse
        mouse[2] = 1 -- mouse scheme 1
        controller = false
    elseif mouse[1] then
        if mouse[2] == 1 then
            menuitem(1, "control: mouse 2")
            mouse[2] = 2 -- mouse scheme 2
        elseif mouse[2] == 2 then
            menuitem(1, "control: gamepad")
            controller = true
            mouse[1] = false

            if not menu_c then
                menu_c = 1
            end
        end
    end

    -- keep pico-8 menu open even after selecting an option
    return true
end
    
function ensure(b)
-- check that user wants to quit to title
    -- ignore right/left button presses
    if (b&1 > 0) or (b&2 > 0) then
        return true
    end

    -- ask the user to confirm their choice
    menuitem(2, "are you sure?", to_title)
    return true
end

function to_title(b)
-- once user confirms, actually quit to title
    -- ignore right/left button presses
    if (b&1 > 0) or (b&2 > 0) then
        return true
    end

    -- set the option back to normal, and return to the menu
    menuitem(2, "return to title", ensure)
    play = false
    option = false
    guide = false
    menu_c = 1
    menu = true
end




-- ** OTHER ** --
function string_l(s)
-- return the length of a string in pixels
    -- each character is 3 pixels, with a 1-pixel space between
    return (#s * 3) + (#s - 1)
end

function hover(x1, y1, x2, y2)
-- check if the mouse is hovering over a certain region
    return (x1 <= mo_x and mo_x <= x2) and (y1 <= mo_y and mo_y <= y2)
end


-- ** DEBUG **
function draw_matrix()
-- draw all adjacency numbers
    for c1=1, #grid do
        for c2=1, #grid[c1] do
            if type(grid[c1][c2]) == "number" and grid[c1][c2] != 0 then
                print(grid[c1][c2], xoff+c1*8-5, yoff+c2*8+2, 8)
            end
        end
    end
end

function draw_coords()
-- draw mouse coords in top left corner
    cursor(0, 0, 0)

    if mouse_log then
        print(mo_x)
        print(mo_y)
    end

    if grid_log and play then
        print(p.mx)
        print(p.my)
    end
end