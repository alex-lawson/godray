local vutil = require "vutil"
local tutil = require "tutil"

local Renderer = ...

function Renderer.new(window, scene)
  local newRenderer = {
    window = window,
    scene = scene,
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

  -- newRenderer.rayRenderBind = am.bind({
  --   vert = am.vec2_array({vec2(0), vec2(0)}),
  --   color = newRenderer.rayColor,
  --   MVP = newRenderer.MVP
  -- }):tag("rayRenderBind")
  -- newRenderer.rayRenderer = am.use_program(newRenderer.shaderProgram) ^ newRenderer.rayRenderBind ^ am.draw("lines")

  scene:append(newRenderer.wallRenderer)
  -- scene:append(newRenderer.rayRenderer)

  return newRenderer
end

function Renderer:setWallGeometry(walls)
  self.wallRenderBind.vert = am.vec2_array(walls)
end

function Renderer:setRayGeometry(ray)
  -- self.rayRenderBind.vert = am.vec2_array(ray)
end
