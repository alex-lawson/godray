local vutil = require "vutil"

local Renderer = require "renderer"
local LevelManager = require "levelmanager"

local win = am.window{
    title = "GOD*RAY",
    width = 800,
    height = 600,
    resizable = false
}
win.scene = am.group()

local renderer = Renderer.new(win, win.scene)
local level = LevelManager.new()

win.scene:append(am.translate(vec2(-win.width / 2 + 10, win.height / 2 - 10)) ^ am.text("", vec4(1), "left", "top"):tag("debugInfo"))

function levelChanged()
  level:updateRay()
  renderer:setRelays(level.relays)
  renderer:setRay(level.ray)
  renderer:setWalls(level:wallRenderGeometry())
end

local selectedRelay
local pendingPoint

win.scene:action(function(scene)
    local mousePosition = win:mouse_position()
    win.scene("debugInfo").text = mousePosition.x .. ", " .. mousePosition.y .. "   walls " .. #level.walls / 2 .. "   relays " .. #level.relays

    if win:mouse_pressed("left") then
      if not pendingPoint then
        selectedRelay = level:relayNearPoint(mousePosition, 20)

        if not selectedRelay then
          pendingPoint = mousePosition
        end
      else
        level:addWall(pendingPoint, mousePosition)

        levelChanged()

        pendingPoint = mousePosition
      end
    elseif win:mouse_pressed("right") then
      if pendingPoint then
        pendingPoint = nil
        level.wallPreview = nil
        renderer:setWalls(level:wallRenderGeometry())
      end
    end

    if pendingPoint then
      level.wallPreview = {pendingPoint, mousePosition}
      renderer:setWalls(level:wallRenderGeometry())
    end

    if selectedRelay then
      if win:mouse_down("left") then
        selectedRelay[2] = vutil.angle(mousePosition - selectedRelay[1])
        levelChanged()
      else
        selectedRelay = nil
      end
    end

    if not selectedRelay and not pendingPoint then
      if win:key_pressed("1") then
        level:addRelay(mousePosition, 0)
        levelChanged()
      elseif win:key_pressed("backspace") then
        toRemove = level:relayNearPoint(mousePosition, 20)
        if toRemove then
          level:removeRelay(toRemove)
          levelChanged()
        end
      end
    end
  end)

level:addDemoWalls()
level:addDemoRelays()
levelChanged()
