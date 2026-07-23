local NG = {}

---@type string
local Text = ""

---@type boolean
local Italic = false
---@type boolean
local Bold = false
---@type boolean
local Underlined = false
---@type boolean
local Strikethrough = false
---@type boolean
local Obfuscated = false

---@type boolean
local Glowing = false
---@type boolean
local Visible = true
---@type boolean
local Outline = false
---@type boolean
local Shadow = false
---@type vec
local BackgroundColor = vec(0, 0, 0)
---@type number
local BackgroundOpacity = 0.5
---@type vec?
local BackgroundColorPrev = nil
---@type number?
local BackgroundOpacityPrev = nil

---@type number
local Speed = 0
---@type number?
local SpeedPrev = nil
---@type "linear" | "bezier"
local Interpolation = "linear"
---@type table<number, vec>
local Positions = {}
---@type table<number, vec>?
local PositionsPrev = nil

---@type number
local ScrollPosition = 0

---@alias PositionsWithType { type: "linear" | "bezier", [number]: string }
---@alias PositionsWithoutType { type?: nil, [number]: string }
---@alias PositionTable PositionsWithType | PositionsWithoutType

---@class Definition
---@field text? string
---@field glowing? boolean
---@field visible? boolean
---@field outline? boolean
---@field shadow? boolean
---@field italic? boolean
---@field bold? boolean
---@field underlined? boolean
---@field strikethrough? boolean
---@field obfuscated? boolean
---@field scrollSpeed? number
---@field colors? PositionTable
---@field backgroundColor? string
---@field backgroundOpacity? number

---Used to set up custom text for your nameplate.<br><br>
---Example usage:
---```lua
---local NameplateGradients = require("NameplateGradients")
---function events.entity_init()
---    NameplateGradients.SetNameplate({
---        text = "Hello, world!",
---        colors = {
---            type = "bezier",
---            [0] = "#FF0000",
---            [0.5] = "#00FF00",
---            [1] = "#0000FF"
---        },
---        backgroundColor = "#000000",
---        backgroundOpacity = 0.25,
---        scrollSpeed = 1,
---        glowing = false,
---        visible = true,
---        outline = false,
---        shadow = false,
---        italic = false,
---        bold = false,
---        underlined = false,
---        strikethrough = false,
---        obfuscated = false
---    })
---end
---```
---- `text` is the text that gets shown. You can set this to anything. If not included, it will default to your display name.
---- `colors` sets everything having to do with gradients. If not included, your text will default to white.
---- `type` defines the blending type. The two options are `"linear"` and `"bezier"`.<br>
---Bezier is smooth and loops nicely no matter what colors you set at the start and end.<br>
---Linear transitions between colors in a zig-zag way. If the first and last colors are different, it will create a split.
---- `scrollSpeed` defines how fast your gradient scrolls. If not included, it defaults to 0, which is still.
---- `glowing` defines whether the text on your nameplate glows. It defaults to false.
---- `visible` makes your nameplate entirely visible or invisible. It defaults to false.
---- `italic` makes your text slanged. This, and the following ones default to `false`.
---- `bold` makes your text bold.
---- `underlined` makes your text underlined.
---- `strikethrough` draws a line over the text.
---- `obfuscated` makes your text glitchy.
---@param definition Definition
function NG.SetNameplate(definition)
    Text = definition.text or player:getName()
    Glowing = definition.glowing or false
    Visible = definition.visible or true
    Outline = definition.outline or false
    Shadow = definition.shadow or false
    Italic = definition.italic or false
    Bold = definition.bold or false
    Underlined = definition.underlined or false
    Strikethrough = definition.strikethrough or false
    Obfuscated = definition.obfuscated or false

    BackgroundColor = vectors.hexToRGB(definition.backgroundColor) or vec(0, 0, 0)
    BackgroundOpacity = definition.backgroundOpacity or 0.5

    Speed = definition.scrollSpeed or 0
    ScrollPosition = 0

    ---@type PositionTable
    local colors = definition.colors or {}
    Interpolation = colors.type or "linear"
    ---@type table<number, string>
    for key, value in pairs(colors) do
        if type(key) == "number" then
            Positions[key] = vectors.hexToRGB(value)
        end
    end

    local block, sky = nil, nil
    if Glowing then
        block, sky = 15, 15
    end

    nameplate.Entity
        :setVisible(Visible)
        :setOutline(Outline)
        :setShadow(Shadow)
        :setBackgroundColor(
            BackgroundOpacity,
            BackgroundColor.x,
            BackgroundColor.y,
            BackgroundColor.z
        )
        :setLight(block, sky)
end

---@param positions table<number, vec>
---@param mix number
---@param scroll number
---@return vec
local function bezierInterpolate(positions, mix, scroll)
    local keys = {}
    for k in pairs(positions) do table.insert(keys, k) end
    table.sort(keys)

    mix = (mix + scroll) % 1

    local pts = {}
    for _, k in ipairs(keys) do
        table.insert(pts, positions[k])
    end

    pts[#pts+1] = positions[keys[1]]

    local scaled = mix * (#keys)
    local index = math.floor(scaled) + 1
    local localMix = scaled - math.floor(scaled)

    local p0 = pts[index]
    local p1 = pts[index+1]

    return p0 + (p1 - p0) * localMix
end
---@param positions table<number, vec>
---@param mix number
---@param scroll number
---@return vec
local function linearInterpolate(positions, mix, scroll)
    local keys = {}
    for k in pairs(positions) do table.insert(keys, k) end
    table.sort(keys)

    mix = (mix + scroll) % 1

    local n = #keys

    local output
    for i = 1, n do
        local a = keys[i]
        local b = keys[i % n + 1]
        local va = positions[a]
        local vb = positions[b]

        local segLen = b > a and (b - a) or (1 - a + b)
        local rel = (mix - a) % 1 / segLen

        if (mix >= a and mix <= b) or (b < a and (mix >= a or mix <= b)) then
            output = va + (vb - va) * rel
            break
        end
    end
    return output
end

function events.tick()
    local gradPos = ScrollPosition * (Speed / 100)
    local pText = {}
    for char in Text:gmatch("[\x00-\x7F\xC2-\xF4][\x80-\xBF]*") do
        table.insert(pText, char)
    end
    local json = {}
    for i, c in ipairs(pText) do
        local mix = (i - 1) / #pText
        local rgb
        if Interpolation == "linear" then
            rgb = linearInterpolate(Positions, mix, gradPos)
        elseif Interpolation == "bezier" then
            rgb = bezierInterpolate(Positions, mix, gradPos)
        end
        table.insert(json, {
            text = c,
            color = "#"..vectors.rgbToHex(rgb),
            bold = Bold,
            italic = Italic,
            underlined = Underlined,
            strikethrough = Strikethrough,
            obfuscated = Obfuscated,
            hoverEvent = { -- Just added this just to add Am's hover event lol this isn't original
                action = "show_text",
                contents = {
                    { text = 'Hey guys, ', color = 'white', bold = true},
                    { text = 'Am ', color = '#005748'},
                    { text = 'here!', color = 'white'},
                    { text = '\n - IGN/UUID: AmityD / 78b22c6c-83b9-419e-9674-1e5cb5310e6f', color = 'gray', bold = false},
                    { text = '\n - Pronouns: he/him', color = 'gray', bold = false},
                    { text = '\n (ps i wanna make this avatar vanilla+\ninstead of going all out and adding bloat)', color = 'gray', bold = false}
                }
            }
        })
    end
    nameplate.ALL:setText(toJson(json))
    ScrollPosition = ScrollPosition + 1
end

---@param str string
---@return boolean
local function isHex(str)
    return #str == 6 and str:find("^[0-9a-fA-F]+$") ~= nil
end
---@param str string
---@return table<string>
local function separateStr(str)
    local sep = {}
    for part in str:gmatch("([^,]+)") do
        table.insert(sep, part)
    end
    return sep
end
---@param entry string
---@return number?, string?
local function separateEntry(entry)
    local indexStr, hexStr = entry:match("^(.-)=(.+)$")
    if not indexStr or not hexStr then
        return nil, nil
    end
    if not isHex(hexStr) then
        hexStr = nil
    end
    local index = tonumber(indexStr)
    if index ~= nil then
        if index < 0 or index > 1 then
            index = nil
        end
    end
    return index, hexStr
end
---@param cmd string
local function changeColor(cmd)
    if PositionsPrev == nil then
        PositionsPrev = Positions
    end
    if (cmd == "" or cmd == "reset") then
        Positions = PositionsPrev
        PositionsPrev = nil
        return
    end
    local str = cmd:gsub("%s+", "")
    str = str:gsub("#", "")
    if isHex(str) then
        Positions = { [0] = vectors.hexToRGB(str) }
    else
        local strList = separateStr(str)
        local positions = {}
        for _, entry in ipairs(strList) do
            local index, hex = separateEntry(entry)
            if index == nil or hex == nil then
                print("Colors not in correct format.")
                return
            end
            positions[index] = vectors.hexToRGB(hex)
        end
        Positions = positions
    end
end
---@param cmd string
local function changeInterpolation(cmd)
    if cmd == "" then
        if Interpolation == "linear" then Interpolation = "bezier"
        elseif Interpolation == "bezier" then Interpolation = "linear" end
    elseif cmd == "linear" then
        Interpolation = "linear"
    elseif cmd == "bezier" then
        Interpolation = "bezier"
    else
        print("Interpolation type not recognized.")
    end
end
---@param cmd string
local function changeText(cmd)
    if cmd == "reset" or cmd == "" then
        Text = player:getName()
    else
        if #cmd > 64 then
            print("The text can only be 64 characters long.")
            return
        end
        Text = cmd
    end
end
---@param cmd string
local function changeScrollSpeed(cmd)
    if SpeedPrev == nil then
        SpeedPrev = Speed
    end
    if cmd == "" or cmd == "reset" then
        Speed = SpeedPrev
        SpeedPrev = nil
        return
    end
    local amount = tonumber(cmd)
    if amount == nil then
        print("Provided scroll speed is not a valid number.")
        return
    end
    Speed = amount
end
local function toggleVisibility()
    Visible = not Visible
    nameplate.Entity:setVisible(Visible)
end
local function toggleOutline()
    Outline = not Outline
    nameplate.Entity:setOutline(Outline)
end
local function toggleShadow()
    Shadow = not Shadow
    nameplate.Entity:setShadow(Shadow)
end
---@param cmd string
local function changeBackground(cmd)
    if BackgroundColorPrev == nil then
        BackgroundColorPrev = BackgroundColor
    end
    if BackgroundOpacityPrev == nil then
        BackgroundOpacityPrev = BackgroundOpacity
    end
    if cmd:sub(1, 5) == "color" then
        local str = cmd:sub(7)
        if str == "" or str == "reset" then
            BackgroundColor = BackgroundColorPrev
            BackgroundColorPrev = nil
        else
            if str:sub(1, 1) == "#" then
                str = str:sub(2)
            end
            if isHex(str) then
                BackgroundColor = vectors.hexToRGB(str)
            else
                print("Background color is not in proper format.")
                return
            end
        end
    elseif cmd:sub(1, 7) == "opacity" then
        local str = cmd:sub(9)
        if str == "" or str == "reset" then
            BackgroundOpacity = BackgroundOpacityPrev
            BackgroundOpacityPrev = nil
        else
            local opacity = tonumber(str)
            if opacity == nil then
                print("Opacity has to be a number.")
                return
            elseif opacity > 1 or opacity < 0 then
                print("Opacity has to be a number between 0 and 1.")
                return
            else
                BackgroundOpacity = opacity
            end
        end
    elseif cmd == "" or cmd == "reset" then
        BackgroundColor = BackgroundColorPrev
        BackgroundColorPrev = nil
        BackgroundOpacity = BackgroundOpacityPrev
        BackgroundOpacityPrev = nil
    else
        print("Incorrect keyword was provided.")
        return
    end
    nameplate.Entity:setBackgroundColor(
        BackgroundOpacity,
        BackgroundColor.x,
        BackgroundColor.y,
        BackgroundColor.z
    )
end
local function toggleGlowing()
    Glowing = not Glowing
    local block, sky = nil, nil
    if Glowing then
        block, sky = 15, 15
    end
    nameplate.Entity:setLight(block, sky)
end

function events.CHAT_SEND_MESSAGE(msg)
    local cmd = msg:lower()
    if cmd:sub(1, 3) == "?np" then
        if cmd:sub(5, 9) == "color" then changeColor(cmd:sub(11))
        elseif cmd:sub(5, 14) == "background" then changeBackground(cmd:sub(16))
        elseif cmd:sub(5, 17) == "interpolation" then changeInterpolation(cmd:sub(19))
        elseif cmd:sub(5, 8) == "text" then changeText(msg:sub(10))
        elseif cmd:sub(5, 15) == "scrollspeed" then changeScrollSpeed(cmd:sub(17))
        elseif cmd:sub(5, 10) == "italic" then Italic = not Italic
        elseif cmd:sub(5, 8) == "bold" then Bold = not Bold
        elseif cmd:sub(5, 14) == "underlined" then Underlined = not Underlined
        elseif cmd:sub(5, 17) == "strikethrough" then Strikethrough = not Strikethrough
        elseif cmd:sub(5, 14) == "obfuscated" then Obfuscated = not Obfuscated
        elseif cmd:sub(5, 11) == "visible" then toggleVisibility()
        elseif cmd:sub(5, 11) == "outline" then toggleOutline()
        elseif cmd:sub(5, 10) == "shadow" then toggleShadow()
        elseif cmd:sub(5, 11) == "glowing" then toggleGlowing()
        else print("Invalid command.") end
        return nil
    end
    return msg
end

return NG