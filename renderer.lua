local vutil = require "vutil"

local Renderer = ...

function Renderer.new(window, scene)
  local newRenderer = {
    window = window,
    scene = scene,
    relaySize = 15,
    relayColor = vec4(0.5, 0.5, 0.4, 1.0),
    rayColor = vec4(1.0, 1.0, 0.5, 0.5),
    wallColor = vec4(0.7, 0.7, 0.7, 1.0)
  }

  setmetatable(newRenderer, { __index = Renderer })

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
  newRenderer.shaderProgram = am.program(vshader, fshader)

  newRenderer.MVP = mat4(mat2(2 / window.width, 0, 0, 2 / window.height))

  newRenderer.wallRenderBind = am.bind({
    vert = am.vec2_array({vec2(0), vec2(0)}),
    color = newRenderer.wallColor,
    MVP = newRenderer.MVP
  }):tag("wallRenderBind")
  newRenderer.wallRenderer = am.use_program(newRenderer.shaderProgram) ^ newRenderer.wallRenderBind ^ am.draw("lines")

  newRenderer.rayRenderBind = am.bind({
    vert = am.vec2_array({vec2(0), vec2(0)}),
    color = newRenderer.rayColor,
    MVP = newRenderer.MVP
  }):tag("rayRenderBind")
  newRenderer.rayRenderer = am.use_program(newRenderer.shaderProgram) ^ newRenderer.rayRenderBind ^ am.draw("line_strip")

  newRenderer.relayRenderBind = am.bind({
    vert = am.vec2_array({vec2(0), vec2(0)}),
    color = newRenderer.relayColor,
    MVP = newRenderer.MVP
  }):tag("relayRenderBind")
  newRenderer.relayRenderer = am.use_program(newRenderer.shaderProgram) ^ newRenderer.relayRenderBind ^ am.draw("triangles")

  scene:append(newRenderer.wallRenderer)
  scene:append(newRenderer.relayRenderer)
  scene:append(newRenderer.rayRenderer)

  return newRenderer
end

function Renderer:setWalls(walls)
  if #walls == 0 then
    walls = {vec2(0)}
  end

  self.wallRenderBind.vert = am.vec2_array(walls)
end

function Renderer:setRay(ray)
  if #ray == 0 then
    ray = {vec2(0)}
  end

  self.rayRenderBind.vert = am.vec2_array(ray)
end

function Renderer:setRelays(relays)

  self.relayRenderBind.vert = am.vec2_array(self:buildRelayTriangles(relays))
end

function Renderer:buildRelayTriangles(relays)
  if #relays == 0 then
    return {vec2(0)}
  end

  local points = {}
  for i, relay in ipairs(relays) do
    table.insert(points, relay[1] + vutil.withAngle(relay[2]) * self.relaySize)
    table.insert(points, relay[1] + vutil.withAngle(relay[2] + 2.3) * self.relaySize * 0.5)
    table.insert(points, relay[1] + vutil.withAngle(relay[2] - 2.3) * self.relaySize * 0.5)
  end
  return points
end

function Renderer.lineStripToLines(strip)
  local lines = {}
  for i = 1, #strip - 1 do
    table.insert(lines, strip[i])
    table.insert(lines, strip[i + 1])
  end
  return lines
end
