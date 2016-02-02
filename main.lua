local vutil = require "vutil"
local tutil = require "tutil"
local RayRelay = require "rayrelay"
local Renderer = require "renderer"
local Geometry = require "geometry"

MaxRayLength = 1500
RayRotationRate = 2

local win = am.window{
    title = "GOD*RAY",
    width = 800,
    height = 600,
    resizable = false
}
win.scene = am.group()

local geometry = Geometry.new()

local renderer = Renderer.new(win, win.scene)
renderer:setWallGeometry(geometry:wallGeometry())

win.scene:append(am.translate(vec2(-win.width / 2 + 10, win.height / 2 - 10)) ^ am.text("Mouse Position", vec4(1), "left", "top"):tag("mousePosition"))

local rayRelays = {}

function addRayRelay(relay)
  table.insert(rayRelays, relay)
  win.scene:append(relay.node)
end

function removeRayRelay(relay)
  win.scene:remove(relay.node)
  local i = tutil.find(rayRelays, relay)
  table.remove(rayRelays, i)
end

function findRayRelay(position)
  local searchDist = 20
  local closest
  local closestDistance = 1000
  for i, relay in ipairs(rayRelays) do
    local dist = vutil.dist(position, relay.position)
    if dist < searchDist and dist < closestDistance then
      closest = relay
      closestDistance = dist
    end
  end
  return closest
end

function propagateRay(thisRelay, relays, walls, visited)
  visited = visited or {}
  table.insert(visited, thisRelay)
  thisRelay:checkCollision(walls)
  thisRelay:findTarget(relays, walls)
  if thisRelay.target and not tutil.find(visited, thisRelay.target) then
    table.merge(visited, propagateRay(thisRelay.target, relays, walls, visited))
  end
  return visited
end

function buildRayGeometry(activeRelays)
  local rayGeometry = {}
  for i, relay in ipairs(activeRelays) do
    table.insert(rayGeometry, relay.position)
    table.insert(rayGeometry, relay:rayEndpoint())
  end
  return rayGeometry
end

local primeSource = RayRelay.new(vec2(-300, 400), -math.pi / 2, true)
primeSource:makePermanent()
win.scene:append(primeSource.node)

local firstRelay = RayRelay.new(vec2(-300, 200), -math.pi / 4, true)
addRayRelay(firstRelay)

function updateRelays()
  local activeRelays = propagateRay(primeSource, rayRelays, geometry.walls)

  renderer:setRayGeometry(buildRayGeometry(activeRelays))

  for i, relay in ipairs(rayRelays) do
    relay:setActive(tutil.find(activeRelays, relay) ~= false)
  end
end

local selectedRelay
local pendingPoint

win.scene:action(function(scene)
    local mousePosition = win:mouse_position()
    win.scene("mousePosition").text = mousePosition.x .. ", " .. mousePosition.y

    if win:mouse_pressed("left") then
      if not pendingPoint then
        selectedRelay = findRayRelay(mousePosition)

        if not selectedRelay then
          pendingPoint = mousePosition
        end
      else
        geometry:addWall(pendingPoint, mousePosition)
        renderer:setWallGeometry(geometry:wallGeometry())

        updateRelays()

        pendingPoint = mousePosition
      end
    elseif win:mouse_pressed("right") then
      if pendingPoint then
        pendingPoint = nil
        geometry.wallPreview = nil
        renderer:setWallGeometry(geometry:wallGeometry())
      end
    end

    if pendingPoint then
      geometry.wallPreview = {pendingPoint, mousePosition}
      renderer:setWallGeometry(geometry:wallGeometry())
    end

    if selectedRelay then
      if win:mouse_down("left") then
        selectedRelay:setAngle(vutil.angle(mousePosition - selectedRelay.position))
        selectedRelay:checkCollision(geometry.walls)
        selectedRelay:findTarget(rayRelays, geometry.walls)
        updateRelays()
      else
        selectedRelay = nil
      end
    end

    if not selectedRelay and not pendingPoint then
      if win:key_pressed("1") then
        local relay = RayRelay.new(mousePosition, -math.pi / 2, false)
        addRayRelay(relay)
        updateRelays()
      elseif win:key_pressed("backspace") then
        local toRemove = findRayRelay(mousePosition)
        if toRemove and not toRemove.permanent then
          removeRayRelay(toRemove)
          updateRelays()
        end
      end
    end
  end)

updateRelays()
