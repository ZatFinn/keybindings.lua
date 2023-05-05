keybindings_config = {
    mods = {
        alt = {'lalt', 'ralt'},
        ctrl =	{'rctrl', 'lctrl'},
        shift =	{'rshift', 'lshift'},
        gui =	{'rgui', 'lgui'},
        p8ctrl = {'rgui', 'lgui', 'rctrl', 'lctrl'}
    },
    actions = {
        -- generic
        fullscreen = {'alt, return'},
        full_quit =	{'ctrl, q'},
        full_reload = {'ctrl, r'},
        copy = {'p8ctrl, c'},
        cut = {'p8ctrl, x'},
        paste = {'p8ctrl, v'},
        --
        -- pico-8 keys
        --
        k_left = {'left', 'kp4'},
        k_right = {'right', 'kp6'},
        k_up = {'up', 'kp8'},
        k_down = {'down', 'kp5'},
        k_jump = {'z', 'c', 'n', 'kp-', 'kp1', 'insert'},
        k_dash = {'x', 'v', 'm', '8', 'kp2', 'delete'},
        k_pause = {'return', 'escape'},
        k_seven = {'7'},
        -- held
        hold_left = {'shift, $k_left'},
        hold_right = {'shift, $k_right'},
        hold_up = {'shift, $k_up'},
        hold_down = {'shift, $k_down'},
        hold_jump = {'shift, $k_jump'},
        hold_dash = {'shift, $k_dash'},
        hold_pause = {'shift, $k_pause'},
        hold_seven = {'shift, $k_seven'},
        -- toggle all (visual mode)
        all_left = {'alt, $k_left'},
        all_right = {'alt, $k_right'},
        all_up = {'alt, $k_up'},
        all_down = {'alt, $k_down'},
        all_jump = {'alt, $k_jump'},
        all_dash = {'alt, $k_dash'},
        all_pause = {'alt, $k_pause'},
        all_seven = {'alt, $k_seven'},
        --
        -- pico-8 tas
        --
        prev_frame = {'k'},
        next_frame = {'l'},
        full_rewind = {'d'},
        playback = {'p'},
        reset_tas = {'shift, r'},
        save_tas = {'m'},
        open_tas = {'shift, w'},
        insert_blank = {'insert'},
        duplicate = {'p8ctrl, insert'},
        delete = {'delete'},
        visual = {'shift, l'},
        undo = {'p8ctrl, z'},
        redo = {'shift, $undo'},
        screenshot = {'f1', 'f6'},
        gif_rec_start = {'f3', 'f8', 'p8ctrl, 8'},
        gif_rec_stop = {'f4', 'f9', 'p8ctrl, 9'},
        --
        -- celeste tas
        --
        prev_level = {'s'},
        next_level = {'f'},
        rewind = {'shift, d'},
        level_gif = {'shift, g'},
        clean_save = {'u'},
        full_playback = {'shift, n'},
        inc_djump = {'shift, ='},
        dec_djump = {'-'},
        reset_djump = {'='},
        print_pos = {'y'},
        -- jank offset editing mode
        jank_offset = {'a'},
        inc_jank = {'up'},
        dec_jank = {'down'},
        quit_jank = {'$jank_offset'},
        -- rng seeding mode
        rng_seeding = {'b'},
        dec_rng = {'down'},
        inc_rng = {'up'},
        prev_object = {'left'},
        next_object = {'right'},
        quit_rng = {'$rng_seeding'},
        --
        -- visual mode
        --
        go_to_start = {'home'},
        go_to_end = {'end'},
        exit_visual = {'escape'},
        --
        -- console
        --
        console = {'p8ctrl, t'},
        del_backward = {'backspace'},
        prev_char = {'left'},
        next_char = {'right'},
        prev_word = {'alt, left'},
        next_word = {'alt, right'},
        cmd_go_to_end = {'ctrl, right'},
        cmd_go_to_start = {'ctrl, left'},
        next_command = {'down'},
        prev_command = {'up'},
        clear_line = {'ctrl, c'},
        complete_command = {'tab'},
        send_line = {'return'},

    }
}



local keybindings = {}

-- each action has the form: "mod1 mod2 mod3, key", the part with the mods can be omitted 
local action_bindings = {}

-- the user expects ctrl+t not to be recognized as t, but l+k to be recognized as both
local mods_list = {} -- each entry has the form: ctrl = {"lctrl", "rctrl"}

-- local actions_down = {}

-- check if only the modifiers passed are down
local function check_mods(mods)
    -- these two are formatted as follow, to allow determining faster whether they contain an element: {["mod"] = true}
    local raw_mods_to_hold = {}
    local raw_mods_not_to_hold = {}
    for m, binds in pairs(mods_list) do
        local m_in_mods = false
        for _, mods_item in ipairs(mods) do
            if m == mods_item then
                m_in_mods = true
                break
            end
        end
        if m_in_mods then
            for _, bind in ipairs(binds) do
                raw_mods_to_hold[bind] = true
            end
        end
    end
    for m, binds in pairs(mods_list) do
        for _, bind in ipairs(binds) do
            if not raw_mods_to_hold[bind] then
                raw_mods_not_to_hold[bind] = true
            end
        end
    end
    for bind, _ in pairs(raw_mods_not_to_hold) do
        if love.keyboard.isDown(bind) then
            return false
        end
    end
    local empty = true
    for bind, _ in pairs(raw_mods_to_hold) do
        empty = false
        if love.keyboard.isDown(bind) then
            return true -- either one is fine
        end
    end
    return empty -- if empty, nothing to hold
end

local function parse_bind_str(action)
    local action_table = {mods = {}, keys = {}}
    local mods_str, key_str = string.match(action, "(.*),(.*)")
    if not key_str then -- if no mod has been specified, so the match failed
        key_str = action
        mods_str = nil
    end
    if mods_str ~= nil then
        for m in mods_str:gmatch("[^%s]+") do
            table.insert(action_table.mods, m)
        end
    end
    
    if not key_str then
        print(("Error, no key specified: %q"):format(action))
        return nil
    end
    for k in key_str:gmatch("[^%s]+") do
        table.insert(action_table.keys, k)
    end

    local new_keys = {}
    for i, k in ipairs(action_table.keys) do
        local sub_key = string.match(k, "$(.*)") -- check if the key starts with a $
        if sub_key then -- the key represent another binding
            local sub_action_bindings = action_bindings[sub_key]
            if not sub_action_bindings then
                print(("no other binding found matching %q"):format(sub_key))
                return nil
            end
            for _, sub_bind in ipairs(sub_action_bindings) do
                local sub_action_tbl = parse_bind_str(sub_bind)
                if sub_action_tbl ~= nil then
                    for _, m in ipairs(sub_action_tbl.mods) do
                        table.insert(action_table.mods, m)
                    end
                    for _, new_k in ipairs(sub_action_tbl.keys) do
                        table.insert(new_keys, new_k)
                    end
                end
            end
        else -- raw key
            table.insert(new_keys, k)
        end
    end
    action_table.keys = new_keys
    return action_table
end

function keybindings.load_global_config()
    action_bindings = deepcopy_no_api(keybindings_config.actions)
    mods_list = deepcopy_no_api(keybindings_config.mods)
end

function keybindings.dispatch_actions(key, scancode, isrepeat, _actionpressed)
    for action, binds in pairs(action_bindings) do
        for _, b in ipairs(binds) do
            local action_table = parse_bind_str(b)
            if action_table == nil then
                print("coundl't parse", b)
                return
            end
            local action_emitted = false
            for _, testkey in ipairs(action_table.keys) do
                if key == testkey and check_mods(action_table.mods) then
                    _actionpressed(action, isrepeat)
                    action_emitted = true
                end
            end
            if action_emitted then
                break -- only emit action once if it has several bindings
            end
        end
    end
end

function keybindings.is_action_down(action)
    local binds = action_bindings[action]
    if not binds then
        print(action, "isn't a valid action")
    end
    for _, b in ipairs(binds) do
        local action_tbl = parse_bind_str(b)
        if not action_tbl then
            print("couldn't parse", b)
            return
        end
        for _, testkey in ipairs(action_tbl.keys) do
            if love.keyboard.isDown(testkey) and check_mods(action_tbl.mods) then
                return true
            end
        end
    end
end

return keybindings