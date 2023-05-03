local function warning(s)
    local info = debug.getinfo(3, "Sl")
    print("Warning: "..info.source..":"..info.currentline..": "..s)
end

local function split(str, chars)
    local result = {}
    for m in str:gmatch("[^"..chars.."]+") do
        local last = result[#result]
        -- there is no reason anyone would need to use \\\, because there are
        -- no keys that contain the literal \ and have more than one character.
        -- so we don't need to handle \\\
        if #result==0 or not (last:sub(#last)=="\\" and last:sub(#last-1)~="\\\\") then
            table.insert(result, m)
        else
            result[#result] = last:sub(1,#last-1)..m
        end
    end
    return result
end

local function list_to_hash(list)
    local result = {}
    for i=1,#list do
        result[list[i]]=i
    end
    return result
end

local c = {}

local active_chord -- defined later
local memory = {}
local old_keypressed, old_keyreleased
local hidden_k = {
    -- default binds for convenience
    ctrl="rctrl|lctrl",
    shift="rshift|lshift",
    alt="ralt|lalt",
    gui="rgui|lgui",
}
--local subset_of = {}
local hit_progression = false
local memory_limit = 1

local k_metatable = {
    __index=function(_, key)
        local real_value = hidden_k[key]
        local keytype = type(real_value)
        if keytype == "string" then

            for _,chunk in ipairs(split(real_value:gsub("%s",""),"|")) do

                local t = split(chunk,";")
                if #t==1 then
                    if active_chord>=c.chord(t[1]) then
                    --    for _,v in pairs(subset_of[key]) do
                    --        if c.k[v] then
                    --            return false
                    --        end
                    --    end
                        return true
                    end
                else
                    local result = true
                    if #t-1 > #memory then return false end
                    for i=#memory-#t+2,#memory do
                        result = result and ( memory[i]>=c.chord(t[i-#memory+#t-1]) )
                    end
                    result = result and (active_chord>=c.chord(t[#t]))
                    if result then
                        hit_progression = true
                        return true
                    end
                end
            end
            return false

        elseif keytype == "function" then
            return real_value(key)
        end
        return real_value
    end,
    __newindex = function(_, key, value)
        if type(value)=="table" or type(value)=="number" then
            warning("registering a value of the "..type(value).." type doesn't make sense, keeping it anyway")
        end
        hidden_k[key] = value
        local m = memory_limit
        for _,v in pairs(split(value,"|")) do
            m = math.max(m,#split(v,";"))
        end
        memory_limit = m
        --for k, v in pairs(hidden_k) do
        --    subset_of[k] = {}
        --    for kp, vp in pairs(hidden_k) do
        --        local is_subset = false
        --        for _, chunk in pairs(split(vp:gsub("%s",""),"|")) do
        --            if c.chord(chunk)>c.chord(v) or c.chord(chunk)>c.chord(k) then
        --                is_subset = true
        --            end
        --        end
        --        if is_subset then
        --            table.insert(subset_of[k],kp)
        --        end
        --    end
        --end
    end
}

local length={} -- unique value for indexing
local chord_metatable = {
    -- Unreachable code:
    --__call=function(chord)
    --    print(#chord)
    --    for key in pairs(chord) do
    --        if key~=length then
    --            if hidden_k[key]~=nil then
    --                if not c.k[key] then
    --                    return false
    --                end
    --            else
    --                if not ((key:sub(1,1)=="-" and #key>1)
    --                        and love.keyboard.isScancodeDown(key:sub(2))
    --                        or  love.keyboard.isDown(key)) then
    --                    return false
    --                end
    --            end
    --        end
    --    end
    --    return true
    --end,
    __eq=function(a,b)
        if a[length]~=b[length] then
            return false
        else
            for k in pairs(a) do
                if not b[k] then
                    return false
                end
            end
            return true
        end
    end,
    __le=function(b,a)
        -- check if b is subset of a
        if a[length]<b[length] then
            return false
        end
        for k in pairs(b) do
            if not a[k] then
                return false
            end
        end
        return true
    end,
    __lt=function(a,b)
        -- proper subset
        return (a<=b) and (a~=b)
    end,
    __newindex=function(chord,key,value)
        if not value then
            rawset(chord,length,chord[length]-(chord[key] and 1 or 0))
            rawset(chord,key,nil)
        else
            rawset(chord,length,chord[length]+(chord[key] and 0 or 1))
            rawset(chord,key,true)
        end
    end,
    __tostring=function(chord)
        local result = {}
        -- prioritized keys
        -- (in order)
        local priority = {
            "lalt",   "ralt",
            "lshift", "rshift",
            "lctrl",  "rctrl",
            "lgui",   "rgui"
        }
        for _,k in ipairs(priority) do
            if chord[k] then
                table.insert(result, k)
            end
        end
        for k in pairs(chord) do
            if k~=length
                and not hidden_k[k]
                and not (k:sub(1,1)=="-" and #k>1)
                then
                if not list_to_hash(priority)[k] then
                    table.insert(result, k)
                end
            end
        end
        return table.concat(result, " + ")
    end
}

function k_metatable.__call(self, key)
    warning("trying to call the key table. This is allowed, provided "..key.." is a string, but not recommended over indexing")
    return k_metatable.__index(self, key)
end

c.k = setmetatable({},k_metatable)

function c.chord(keystr)
    local result = {[length]=0}
    for _,k in ipairs(split(keystr:gsub("%s",""),"+")) do
        result[k] = true
        result[length] = result[length]+1
    end
    return setmetatable(result, chord_metatable)
end

active_chord = c.chord("")

function c.register(action,key)
    c.k[action] = key
end

function c.pretty_print_ongoing()
    local strings = {}
    for i=1,#memory do
        strings[i] = tostring(memory[i])
    end
    table.insert(strings,tostring(active_chord))
    return table.concat(strings,"; ")
end

function c.get_ongoing()
    return memory
end

function c.read_config(str,pr)
    local pr_hash = list_to_hash(pr)
    for line in str:gmatch("[^\n]+") do
        if line:sub(1,1)~="#" then
            local s = split(line,":")
            if not pr_hash[s[1]] then
                c.register(s[1],s[2])
            end
        end
    end
end

function c.create_config(write)
    local lines = {
        "# this is a config file for keybindings.lua",
        "# it was generated automatically",
    }
    for k in pairs(hidden_k) do
        table.insert(lines,table.concat({k,hidden_k[k]}, ":"))
    end
    local result = table.concat(lines,"\n")
    if write then
        local fh, e = love.filesystem.newFile(type(write)=="string" and write or "keys.conf","w")
        if e then
            error(e)
        else
            fh:write(result)
            fh:close()
        end
    end
    return result
end

function c.init(opts)
    if opts.file then
        local fh, e = love.filesystem.newFile(opts.file,"r")
        if e then
            error(e)
        else
            c.read_config(fh:read())
            fh:close()
        end
    end
    if not old_keypressed then
        old_keypressed = love.keypressed or function() end
    end
    if not old_keyreleased then
        old_keyreleased = love.keyreleased or function() end
    end
    function love.keypressed(key, scancode, ...)
        active_chord[key] = true
        active_chord["-"..scancode] = true
        for k in pairs(hidden_k) do
            if c.k[k] then
                active_chord[k] = true
            end
        end

        old_keypressed(key, scancode, ...)
    end
    function love.keyreleased(...)
        if active_chord~=c.chord("") then
            table.insert(memory, active_chord)
            if #memory > memory_limit then
                table.remove(memory, 1)
            end
            active_chord = c.chord("")
        end
        if hit_progression then
            hit_progression = false
            memory = {}
        end

        old_keyreleased(...)
    end
end

return c
