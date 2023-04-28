function create_mines(width, height, mines, current)
    -- store mines
    local grid = {}

    -- keep adding mines until there's enough
    while #grid != mines do
        printh("---", "log")
        -- generate a mine location
        local loc = gen(width, height)
        printh("loc: "..loc[1]..", "..loc[2], "log")

        -- check if there's already a mine there, or that's where the player pressed
        local flag = false
        for mine in all(grid) do
            printh("checking against: "..mine[1]..", "..mine[2], "log")
            if
            (loc[1] == mine[1] and loc[2] == mine[2]) or
            (loc[1] == current[1] and loc[2] == current[2]) then
                printh("!!!", "log")
                -- if so, don't add that location to the list
                flag = true
            end
        end

        -- add valid mines to the list
        if not flag then
            printh("added!", "log")

            add(grid, loc)
        end
    end

    return grid
end

function gen(width, height)
    return {flr(rnd(width))+1, flr(rnd(height))+1}
end

function fill_adj(m, width, height)
    for mcol=1, #m do
        for mrow=1, #m[mcol] do
            if m[mcol][mrow] != true then
                local current = {mcol, mrow}
                --printh("----", "log")
                --printh("current: {"..current[1]..", "..current[2].."}", "log")

                for pcol=-1, 1 do
                    for prow=-1, 1 do
                        if not (pcol == 0 and prow == 0) then
                            local probe = {current[1]+pcol, current[2]+prow}
                            --printh("probe: {"..probe[1]..", "..probe[2].."}", "log")

                            if
                            probe[1] >= 1 and
                            probe[1] <= width and
                            probe[2] >= 1 and
                            probe[2] <= height then
                                --printh("passed!", "log")
                                if m[probe[1]][probe[2]] == true then
                                    --printh("added!", "log")
                                    m[current[1]][current[2]] += 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return m
end

function fil_adj(m, list)
    for mine in all(list) do
        local locs = {
            {mine[1]-1, mine[2]-1},
            {mine[1]-1, mine[2]},
            {mine[1]-1, mine[2]+1},
            {mine[1], mine[2]-1},
            {mine[1], mine[2]+1},
            {mine[1]+1, mine[2]-1},
            {mine[1]+1, mine[2]},
            {mine[1]+1, mine[2]+1}
        }

        local t = false
        local r = false
        local b = false
        local l = false

        if mine[1] == 1 then
            l = true
        end

        if mine[1] == 16 then
            r = true
        end

        if mine[2] == 1 then
            t = true
        end

        if mine[2] == 15 then
            b = true
        end

        count = 1
        while count <= #locs do
            deleted = false

            if
            t and locs[count][2] == mine[2]-1 or
            l and locs[count][1] == mine[1]-1 or
            r and locs[count][1] == mine[1]+1 or
            b and locs[count][2] == mine[2]+1
            then
                del(locs, locs[count])
                deleted = true
            end
            
            if not deleted then
                count += 1
            end
        end

        for loc in all(locs) do
            if m[loc[1]][loc[2]] != true then
                if m[loc[1]][loc[2]] == false then
                    m[loc[1]][loc[2]] = 0
                end

                m[loc[1]][loc[2]] += 1
            end
        end
    end

    return m
end