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
  renderer:setMirrors(level:mirrorRenderGeometry())
end

local selectedRelay
local pendingWall
local pendingMirror

function clearPendingWall()
  if pendingWall then
    pendingWall = nil
    level.wallPreview = nil
    renderer:setWalls(level:wallRenderGeometry())
  end
end

function clearPendingMirror()
  if pendingMirror then
    pendingMirror = nil
    level.mirrorPreview = nil
    renderer:setMirrors(level:mirrorRenderGeometry())
  end
end

win.scene:action(function(scene)
    local mousePosition = win:mouse_position()
    win.scene("debugInfo").text = mousePosition.x .. ", " .. mousePosition.y .. "   walls " .. #level.walls / 2 .. "   mirrors " .. #level.mirrors / 2 .. "   relays " .. #level.relays

    if win:mouse_pressed("left") then
      clearPendingWall()
      clearPendingMirror()
      selectedRelay = level:relayNearPoint(mousePosition, 20)
    elseif win:mouse_pressed("right") then
      clearPendingWall()
      clearPendingMirror()
    end

    if pendingWall then
      level.wallPreview = {pendingWall, mousePosition}
      renderer:setWalls(level:wallRenderGeometry())
    end

    if pendingMirror then
      level.mirrorPreview = {pendingMirror, mousePosition}
      renderer:setMirrors(level:mirrorRenderGeometry())
    end

    if selectedRelay then
      if win:mouse_down("left") then
        selectedRelay[2] = vutil.angle(mousePosition - selectedRelay[1])
        levelChanged()
      else
        selectedRelay = nil
      end
    end

    if not selectedRelay then
      if win:key_pressed("r") then
        clearPendingWall()
        clearPendingMirror()
        level:addRelay(mousePosition, 0)
        levelChanged()
      elseif win:key_pressed("1") then
        if pendingWall then
          level:addWall(pendingWall, mousePosition)
          levelChanged()
        end

        if not pendingMirror then
          pendingWall = mousePosition
        else
          clearPendingMirror()
        end
      elseif win:key_pressed("2") then
        if pendingMirror then
          level:addMirror(pendingMirror, mousePosition)
          levelChanged()
        end

        if not pendingWall then
          pendingMirror = mousePosition
        else
          clearPendingWall()
        end
      elseif win:key_pressed("backspace") then
        clearPendingWall()
        clearPendingMirror()
        -- TODO: proper entity management
        local relay, relayDist = level:relayNearPoint(mousePosition, 15)
        local wallIndex, wallDist = level:wallNearPoint(mousePosition, 8)
        local mirrorIndex, mirrorDist = level:mirrorNearPoint(mousePosition, 8)
        local t = {{relay, relayDist}, {wall, wallDist}, {mirror, mirrorDist}}
        table.sort(t, function(a, b) return b[2] == nil or (a[2] ~= nil and a[2] < b[2]) or false end)
        if t[1][2] then
          if relay and t[1][2] == relayDist then
            level:removeRelay(relay)
          elseif wallIndex and t[1][2] == wallDist then
            level:removeWall(wallIndex)
          elseif mirrorIndex and t[1][2] == mirrorDist then
            level:removeMirror(mirrorIndex)
          end
          levelChanged()
        end
      end
    end
  end)

level:addDemoWalls()
level:addDemoMirrors()
level:addDemoRelays()
levelChanged()
