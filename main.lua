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

win.scene:append(am.translate(vec2(-win.width / 2 + 10, win.height / 2 - 10)) ^ am.text("", vec4(1), "left", "top"):tag("debugLine1"))
win.scene:append(am.translate(vec2(-win.width / 2 + 10, win.height / 2 - 28)) ^ am.text("", vec4(1), "left", "top"):tag("debugLine2"))

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

function snapSegment(p, q, resolution)
  resolution = resolution or math.pi / 2

  local qa = vutil.angle(q - p)

  local bestAngle, bestDist
  for i = 0, math.floor((math.pi * 2) / resolution) do
    local thisAngle = i * resolution
    local angleDiff = ((((thisAngle - qa) % (2*math.pi)) + (3*math.pi)) % (2*math.pi)) - math.pi
    if not bestDist or math.abs(angleDiff) < bestDist then
      bestAngle = thisAngle
      bestDist = math.abs(angleDiff)
    end
  end

  return p + vutil.withAngle(bestAngle) * vutil.mag(q - p)
end

win.scene:action(function(scene)
    local mousePosition = vutil.floor(win:mouse_position())
    win.scene("debugLine1").text = mousePosition.x .. ", " .. mousePosition.y .. "   walls " .. #level.walls .. "   mirrors " .. #level.mirrors .. "   relays " .. #level.relays
    win.scene("debugLine2").text = "recursion " .. level.lastRecursion

    if win:mouse_pressed("left") then
      clearPendingWall()
      clearPendingMirror()
      selectedRelay = level:relayNearPoint(mousePosition, 20)
    elseif win:mouse_pressed("right") then
      clearPendingWall()
      clearPendingMirror()
    end

    if pendingWall then
      level.wallPreview = {pendingWall, snapSegment(pendingWall, mousePosition)}
      renderer:setWalls(level:wallRenderGeometry())
    end

    if pendingMirror then
      level.mirrorPreview = {pendingMirror, snapSegment(pendingMirror, mousePosition)}
      renderer:setMirrors(level:mirrorRenderGeometry())
    end

    if selectedRelay then
      if win:mouse_down("left") then
        selectedRelay[2] = vutil.angle(mousePosition - selectedRelay[1])
        if selectedRelay[3] then
          selectedRelay[2] = selectedRelay[2] + math.pi * 0.5
        end
        levelChanged()
      else
        selectedRelay = nil
      end
    end

    if not selectedRelay then
      if win:key_pressed("3") or win:key_pressed("4") then
        clearPendingWall()
        clearPendingMirror()
        level:addRelay(mousePosition, 0, win:key_pressed("4"))
        levelChanged()
      elseif win:key_pressed("1") then
        if pendingWall then
          local snapPosition = snapSegment(pendingWall, mousePosition)
          level:addWall(pendingWall, snapPosition)
          levelChanged()
          pendingWall = snapPosition
        elseif not pendingMirror then
          pendingWall = mousePosition
        else
          clearPendingWall()
        end
      elseif win:key_pressed("2") then
        if pendingMirror then
          local snapPosition = snapSegment(pendingMirror, mousePosition)
          level:addMirror(pendingMirror, snapPosition)
          levelChanged()
          pendingMirror = snapPosition
        elseif not pendingWall then
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
-- level:addDemoMirrors()
level:addDemoRelays()
levelChanged()
