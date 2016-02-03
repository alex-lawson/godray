local vutil = require "vutil"

local LevelManager = ...

function LevelManager.new()
  local newLevelManager = {
    maxRayLength = 1500,
    sourcePos = vec2(0, 400),
    sourceAngle = -math.pi / 2,
    relays = {},
    ray = {},
    walls = {},
    wallPreview = nil
  }

  setmetatable(newLevelManager, { __index = LevelManager })

  return newLevelManager
end

-- RELAY MANAGEMENT

function LevelManager:setSource(sourcePos, sourceAngle)
  self.sourcePos = sourcePos
  self.sourceAngle = sourceAngle
end

function LevelManager:addRelay(position, angle)
  table.insert(self.relays, {position, angle})
  -- self:update()
end

function LevelManager:removeRelay(relay)
  table.remove(self.relays, table.search(self.relays, relay))
  -- self:update()
end

function LevelManager:removeRelayAt(position)
  self.relays = table.filter(self.relays, function(r) return r[1] ~= position end)
  -- self:update()
end

function LevelManager:addDemoRelays()
  self:addRelay(vec2(self.sourcePos.x, 0), 0)
end

-- RAY TRACING ETC

function LevelManager:updateRay()
  self.ray = self:traceRay(self.sourcePos, self.sourceAngle)
end

function LevelManager:traceRay(position, angle, points)
  points = points or {position}

  local searchEndpoint = position + vutil.withAngle(angle) * self.maxRayLength

  local relay = self:relayNearLine(position, searchEndpoint)
  if relay then
    local oldIndex = table.search(points, relay[1])
    if oldIndex == #points - 1 then
      return points
    elseif oldIndex then
      table.insert(points, relay[1])
      return points
    else
      table.insert(points, relay[1])
      return self:traceRay(relay[1], relay[2], points)
    end
  end

  if self:collidesWall(position, searchEndpoint) then
    local collidePoint = self:collidesWallAt(position, searchEndpoint)
    table.insert(points, collidePoint)
    return points
  end

  table.insert(points, searchEndpoint)
  return points
end

function LevelManager:relayNearLine(p, q, maxDist)
  maxDist = maxDist or 15
  local bestRelay, bestDist
  for i, relay in ipairs(self.relays) do
    if relay[1] ~= p then
      local thisDist = vutil.distToSegment(relay[1], p, q)
      if thisDist < maxDist and (not bestDist or thisDist < bestDist) then
        if not self:collidesWall(p, relay[1]) then
          bestRelay = relay
          bestDist = thisDist
        end
      end
    end
  end
  return bestRelay, bestDist
end

function LevelManager:relayNearPoint(p, maxDist)
  maxDist = maxDist or 15
  local bestRelay, bestDist
  for i, relay in ipairs(self.relays) do
    local thisDist = vutil.dist(p, relay[1])
    if thisDist <= maxDist and (not bestDist or thisDist < bestDist) then
      bestRelay = relay
      bestDist = thisDist
    end
  end
  return bestRelay, bestDist
end

function LevelManager:collidesWall(p, q)
  for i = 1, #self.walls - 1, 2 do
    local a = self.walls[i]
    local b = self.walls[i + 1]
    if vutil.intersects(p, q, a, b) then
      return true
    end
  end
  return false
end

function LevelManager:collidesWallAt(p, q)
  local bestPoint, bestDist, bestWall
  for i = 1, #self.walls - 1, 2 do
    local a = self.walls[i]
    local b = self.walls[i + 1]
    if vutil.intersects(p, q, a, b) then
      local thisPoint = vutil.floor(vutil.intersectsAt(p, q, a, b))
      local thisDist = vutil.dist(p, thisPoint)
      if not bestDist or thisDist < bestDist then
        bestPoint = thisPoint
        bestDist = thisDist
        bestWall = {a, b}
      end
    end
  end
  return bestPoint, bestDist, bestWall
end

-- WALL MANAGEMENT

function LevelManager:addWall(p, q)
  table.insert(self.walls, p)
  table.insert(self.walls, q)
end

function LevelManager:wallRenderGeometry()
  if self.wallPreview then
    local finalWalls = table.shallow_copy(self.walls)
    table.append(finalWalls, self.wallPreview)
    return finalWalls
  else
    return self.walls
  end
end

function LevelManager:addDemoWalls()
  self.walls = {
    vec2(-400, -200),
    vec2(-50, -200),
    vec2(-50, -200),
    vec2(50, -280),
    vec2(50, -280),
    vec2(400, -280)
  }
end
