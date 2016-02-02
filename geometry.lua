local vutil = require "vutil"
local tutil = require "tutil"

local Geometry = ...

function Geometry.new()
  local newGeometry = {
    walls = {},
    wallPreview = nil
  }

  setmetatable(newGeometry, { __index = Geometry })

  newGeometry.walls = {
    vec2(-400, -200),
    vec2(-50, -200),
    vec2(-50, -200),
    vec2(50, -280),
    vec2(50, -280),
    vec2(400, -280)
  }

  return newGeometry
end

function Geometry:wallGeometry()
  if self.wallPreview then
    local finalWalls = table.shallow_copy(self.walls)
    table.append(finalWalls, self.wallPreview)
    return finalWalls
  else
    return self.walls
  end
end

function Geometry:addWall(p, q)
  table.insert(self.walls, p)
  table.insert(self.walls, q)
end
