local vutil = require "vutil"
local tutil = require "tutil"
local RayRelay = require "rayrelay"

MaxRayLength = 1500
RayColor = vec4(1.0, 1.0, 0.5, 0.5)
RayRotationRate = 2

local win = am.window{
    title = "GOD*RAY",
    width = 800,
    height = 600,
    resizable = false
}

win.scene = am.group()

local vshader = [[
    precision mediump float;
    attribute vec2 vert;
    uniform mat4 MVP;
    void main() {
        gl_Position = MVP * vec4(vert, 0, 1);
    }
]]
local fshader = [[
    precision mediump float;
    uniform vec4 color;
    void main() {
        gl_FragColor = color;
    }
]]
local shader_program = am.program(vshader, fshader)

local geometry = {
  vec2(-400, -200),
  vec2(-50, -200),
  vec2(-50, -200),
  vec2(50, -280),
  vec2(50, -280),
  vec2(400, -280)
}
local geoArray = am.vec2_array(geometry)
local geoColor = vec4(0.7, 0.7, 0.7, 1.0)
local MVP = mat4(mat2(2 / win.width, 0, 0, 2 / win.height))

win.scene:append(am.use_program(shader_program) ^ am.bind({
    vert = geoArray,
    color = geoColor,
    MVP = MVP
  }):tag("levelGeometry") ^ am.draw("lines"))

win.scene:append(am.use_program(shader_program) ^ am.bind({
    vert = am.vec2_array({vec2(0), vec2(0)}),
    color = vec4(1),
    MVP = MVP
  }):tag("previewGeometry") ^ am.draw("lines"))

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

function propagateActive(relay, visited)
  visited = visited or {}
  table.insert(visited, relay)
  if relay.target and not tutil.find(visited, relay.target) then
    table.merge(visited, propagateActive(relay.target, visited))
  end
  return visited
end

local primeSource = RayRelay.new(vec2(-300, 400), -math.pi / 2, true)
primeSource:makePermanent()
win.scene:append(primeSource.node)

local firstRelay = RayRelay.new(vec2(-300, 200), -math.pi / 4, true)
addRayRelay(firstRelay)
primeSource:setTarget(firstRelay)
firstRelay:checkCollision(geometry)

function updateActive()
  local activeRelays = propagateActive(primeSource)
  -- log("Found active relays %s", table.tostring(activeRelays))
  for i, relay in ipairs(rayRelays) do
    relay:setActive(tutil.find(activeRelays, relay) ~= false)
  end
end

local selectedRelay
local pendingPoint

win.scene:action(function(scene)
    updateActive()
    local mousePosition = win:mouse_position()
    win.scene("mousePosition").text = mousePosition.x .. ", " .. mousePosition.y

    if win:mouse_pressed("left") then
      if not pendingPoint then
        selectedRelay = findRayRelay(mousePosition)

        if not selectedRelay then
          pendingPoint = mousePosition
        end
      else
        table.insert(geometry, pendingPoint)
        table.insert(geometry, mousePosition)
        win.scene("levelGeometry").vert = am.vec2_array(geometry)

        pendingPoint = mousePosition
      end
    elseif win:mouse_pressed("right") then
      if pendingPoint then
        pendingPoint = nil
        win.scene("previewGeometry").hidden = true
      end
    end

    if pendingPoint then
      win.scene("previewGeometry").vert = am.vec2_array({pendingPoint, mousePosition})
      win.scene("previewGeometry").hidden = false
    end

    if selectedRelay then
      if win:mouse_down("left") then
        selectedRelay:setAngle(vutil.angle(mousePosition - selectedRelay.position))
        selectedRelay:checkCollision(geometry)
        selectedRelay:findTarget(rayRelays, geometry)
      else
        selectedRelay = nil
      end
    end

    if not selectedRelay and not pendingPoint then
      if win:key_pressed("1") then
        local relay = RayRelay.new(mousePosition, -math.pi / 2, false)
        addRayRelay(relay)
      elseif win:key_pressed("backspace") then
        local toRemove = findRayRelay(mousePosition)
        if toRemove and not toRemove.permanent then
          removeRayRelay(toRemove)
        end
      end
    end
  end)
