-- ==============================================================
-- Snake 贪吃蛇  (esp-claw app)
-- 适配: 2寸 SPI LCD + 五向开关 + XYAB 按键 的自定义游戏机板
-- 按键 GPIO 在下面 CONFIG 区按实际原理图修改
-- ==============================================================
local display = require("display")
local sys = require("system")
local dly = require("delay")
local button_ok, button = pcall(require, "button")

-- ---------------- CONFIG: 按你的原理图修改这里 ----------------
local ACTIVE_LEVEL = 0      -- 按键按下时的电平 (接地按键=0)
-- 五向开关 (F1=GPIO5, F2=GPIO21, F3=GPIO3, F4=GPIO4, F5=GPIO2)
-- 方向定义是猜测值: 若实际方向不对, 交换下面四行即可
local KEY_UP    = 5         -- F1
local KEY_DOWN  = 21        -- F2
local KEY_LEFT  = 3         -- F3
local KEY_RIGHT = 4         -- F4
local KEY_OK    = 2         -- F5(中键): 暂停/开始
-- XYAB 按键: X=GPIO8, Y=GPIO6, A=GPIO9, B=GPIO7 (A=开始/确认, B=退出)
local KEY_A = 9
local KEY_B = 7
-- ----------------------------------------------------------------

local CELL = 8              -- 蛇身格子大小(像素)

local ok, screen = pcall(display.open)
if not ok or not screen then
    print("[snake] display.open failed: " .. tostring(screen))
    return
end
local info = screen:info()
local SW, SH = info.width, info.height
print(string.format("[snake] screen %dx%d", SW, SH))

local C_BG    = display.color(12, 16, 24)
local C_FIELD = display.color(28, 36, 48)
local C_GRID  = display.color(38, 48, 62)
local C_SNAKE = display.color(70, 200, 120)
local C_HEAD  = display.color(180, 255, 160)
local C_FOOD  = display.color(235, 80, 70)
local C_TEXT  = display.color(235, 235, 235)
local C_MUTED = display.color(140, 150, 165)

-- 按键句柄
local keys = {}
if button_ok and button then
    local defs = {
        up = KEY_UP, down = KEY_DOWN, left = KEY_LEFT,
        right = KEY_RIGHT, ok = KEY_OK, a = KEY_A, b = KEY_B,
    }
    for name, gpio in pairs(defs) do
        local h, err = button.new(gpio, ACTIVE_LEVEL, 500, 50)
        if h then keys[name] = h
        else print(string.format("[snake] button %s(gpio%d) failed: %s", name, gpio, tostring(err))) end
    end
else
    print("[snake] button module unavailable")
end

local function pressed(name)
    local h = keys[name]
    if not h then return false end
    local lvl, err = button.get_key_level(h)
    if not lvl then return false end
    return lvl == ACTIVE_LEVEL
end

-- ---------------- 游戏状态 ----------------
local state = "title"       -- title / run / pause / over
local snake, dir, next_dir, food, score, best = nil, nil, nil, nil, 0, 0
local frame_ms = 110

local COLS = math.floor((SW - 8) / CELL)
local ROWS = math.floor((SH - 40) / CELL)
local OX = math.floor((SW - COLS * CELL) / 2)
local OY = 32

local function spawn_food()
    while true do
        local fx = math.random(0, COLS - 1)
        local fy = math.random(0, ROWS - 1)
        local hit = false
        for _, seg in ipairs(snake) do
            if seg.x == fx and seg.y == fy then hit = true break end
        end
        if not hit then food = { x = fx, y = fy } return end
    end
end

local function reset()
    snake = {
        { x = math.floor(COLS / 2),     y = math.floor(ROWS / 2) },
        { x = math.floor(COLS / 2) - 1, y = math.floor(ROWS / 2) },
        { x = math.floor(COLS / 2) - 2, y = math.floor(ROWS / 2) },
    }
    dir, next_dir = { x = 1, y = 0 }, { x = 1, y = 0 }
    score, frame_ms = 0, 110
    spawn_food()
end

local function set_dir(dx, dy)
    -- 禁止 180 度掉头
    if dir.x + dx == 0 and dir.y + dy == 0 then return end
    next_dir = { x = dx, y = dy }
end

local function read_keys()
    if pressed("up") then set_dir(0, -1) end
    if pressed("down") then set_dir(0, 1) end
    if pressed("left") then set_dir(-1, 0) end
    if pressed("right") then set_dir(1, 0) end
end

local function step()
    dir = next_dir
    local head = snake[1]
    local nx, ny = head.x + dir.x, head.y + dir.y
    -- 撞墙 / 撞自己 → 结束
    if nx < 0 or nx >= COLS or ny < 0 or ny >= ROWS then
        state = "over"
        if score > best then best = score end
        return
    end
    for i, seg in ipairs(snake) do
        if i < #snake and seg.x == nx and seg.y == ny then
            state = "over"
            if score > best then best = score end
            return
        end
    end
    table.insert(snake, 1, { x = nx, y = ny })
    if nx == food.x and ny == food.y then
        score = score + 10
        if frame_ms > 60 then frame_ms = frame_ms - 3 end  -- 逐渐加速
        spawn_food()
    else
        table.remove(snake)
    end
end

-- ---------------- 绘制 ----------------
local function px(gx, gy, color)
    screen:fill_rect(OX + gx * CELL + 1, OY + gy * CELL + 1, CELL - 2, CELL - 2, color)
end

local function draw_common()
    screen:fill_rect(0, 0, SW, OY - 4, display.color(8, 10, 16))
    screen:text(8, 8, string.format("SCORE %04d", score), { color = C_TEXT, font_size = 14 })
    local bs = string.format("BEST %04d", best)
    local tw = screen:measure_text(bs, { font_size = 14 })
    screen:text(SW - tw - 8, 8, bs, { color = C_MUTED, font_size = 14 })
    screen:fill_rect(OX - 2, OY - 2, COLS * CELL + 4, ROWS * CELL + 4, C_FIELD)
    for gx = 1, COLS - 1 do
        screen:fill_rect(OX + gx * CELL, OY, 1, ROWS * CELL, C_GRID)
    end
    for gy = 1, ROWS - 1 do
        screen:fill_rect(OX, OY + gy * CELL, COLS * CELL, 1, C_GRID)
    end
end

local function center_text(y, text, color, size)
    local tw = screen:measure_text(text, { font_size = size })
    screen:text(math.floor((SW - tw) / 2), y, text, { color = color, font_size = size })
end

local function draw()
    screen:begin({ clear = C_BG })
    draw_common()
    px(food.x, food.y, C_FOOD)
    for i, seg in ipairs(snake) do
        px(seg.x, seg.y, i == 1 and C_HEAD or C_SNAKE)
    end
    if state == "title" then
        screen:fill_rect(0, SH / 2 - 46, SW, 92, display.color(8, 10, 16))
        center_text(SH / 2 - 38, "SNAKE", C_SNAKE, 24)
        center_text(SH / 2 - 4, "五向键/方向键 移动", C_TEXT, 12)
        center_text(SH / 2 + 16, "中键 或 A 开始", C_MUTED, 12)
    elseif state == "pause" then
        center_text(SH / 2 - 10, "PAUSED", C_TEXT, 20)
        center_text(SH / 2 + 16, "中键 继续", C_MUTED, 12)
    elseif state == "over" then
        screen:fill_rect(0, SH / 2 - 46, SW, 92, display.color(8, 10, 16))
        center_text(SH / 2 - 38, "GAME OVER", C_FOOD, 22)
        center_text(SH / 2 - 6, string.format("SCORE %d  BEST %d", score, best), C_TEXT, 13)
        center_text(SH / 2 + 18, "A 重新开始", C_MUTED, 12)
    end
    screen:present()
end

-- ---------------- 主循环 ----------------
math.randomseed(math.floor(sys.millis()) & 0x7fffffff)
reset()

local t0 = sys.millis()
while true do
    local now = sys.millis()

    if state == "title" or state == "over" then
        if pressed("ok") or pressed("a") then reset() state = "run" end
    elseif state == "run" then
        read_keys()
        if pressed("ok") then state = "pause" end
        if pressed("b") then state = "title" end
    elseif state == "pause" then
        if pressed("ok") or pressed("a") then state = "run" end
        if pressed("b") then state = "title" end
    end

    if state == "run" then step() end
    draw()

    local sl = frame_ms - (sys.millis() - now)
    if sl > 0 then dly.delay_ms(sl) end
end
