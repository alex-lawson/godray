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
    wallPreview = nil,
    mirrors = {},
    mirrorPreview = nil
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
end

function LevelManager:removeRelay(relay)
  table.remove(self.relays, table.search(self.relays, relay))
end

function LevelManager:removeRelayAt(position)
  self.relays = table.filter(self.relays, function(r) return r[1] ~= position end)
end

function LevelManager:addDemoRelays()
  self:addRelay(vec2(self.sourcePos.x, 0), 0)
end

-- RAY MANAGEMENT

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

-- WALL AND MIRROR MANAGEMENT

-- TODO: abstract segment manager

function LevelManager:addWall(p, q)
  table.insert(self.walls, p)
  table.insert(self.walls, q)
end

function LevelManager:addMirror(p, q)
  table.insert(self.mirrors, p)
  table.insert(self.mirrors, q)
end

function LevelManager:removeWall(index)
  table.remove(self.walls, index)
  table.remove(self.walls, index)
end

function LevelManager:removeMirror(index)
  table.remove(self.mirrors, index)
  table.remove(self.mirrors, index)
end

function LevelManager:wallNearPoint(p, maxDist)
  return self.segmentNearPoint(self.walls, p, maxDist)
end

function LevelManager:mirrorNearPoint(p, maxDist)
  return self.segmentNearPoint(self.mirrors, p, maxDist)
end

function LevelManager.segmentNearPoint(segments, p, maxDist)
  maxDist = maxDist or 15
  local bestIndex, bestDist
  for i = 1, #segments - 1, 2 do
    local a = segments[i]
    local b = segments[i + 1]
    local thisDist = vutil.distToSegment(p, a, b)
    if thisDist <= maxDist and (not bestDist or thisDist < bestDist) then
      bestDist = thisDist
      bestIndex = i
    end
  end
  return bestIndex, bestDist
end

function LevelManager:wallRenderGeometry()
  return self.geometryWithPreview(self.walls, self.wallPreview)
end

function LevelManager:mirrorRenderGeometry()
  return self.geometryWithPreview(self.mirrors, self.mirrorPreview)
end

function LevelManager.geometryWithPreview(baseGeometry, previewGeometry)
  if previewGeometry then
    local finalGeometry = table.shallow_copy(baseGeometry)
    table.append(finalGeometry, previewGeometry)
    return finalGeometry
  else
    return baseGeometry
  end
end

function LevelManager:collidesWall(p, q)
  return self.collidesSegment(self.walls, p, q)
end

function LevelManager:collidesMirror(p, q)
  return self.collidesSegment(self.mirrors, p, q)
end

function LevelManager.collidesSegment(segments, p, q)
  if #segments < 2 then return false end

  for i = 1, #segments - 1, 2 do
    local a = segments[i]
    local b = segments[i + 1]
    if vutil.intersects(p, q, a, b) then
      return true
    end
  end
  return false
end

function LevelManager:collidesWallAt(p, q)
  return self.collidesSegmentAt(self.walls, p, q)
end

function LevelManager:collidesMirrorAt(p, q)
  return self.collidesSegmentAt(self.mirrors, p, q)
end

function LevelManager.collidesSegmentAt(segments, p, q)
  if #segments < 2 then return nil end
  local bestPoint, bestDist, bestSegment
  for i = 1, #segments - 1, 2 do
    local a = segments[i]
    local b = segments[i + 1]
    if vutil.intersects(p, q, a, b) then
      local thisPoint = vutil.floor(vutil.intersectsAt(p, q, a, b))
      local thisDist = vutil.dist(p, thisPoint)
      if not bestDist or thisDist < bestDist then
        bestPoint = thisPoint
        bestDist = thisDist
        bestSegment = {a, b}
      end
    end
  end
  return bestPoint, bestDist, bestSegment
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

function LevelManager:addDemoMirrors()
  self.mirrors = {
    vec2(200, 50),
    vec2(300, -50)
  }
end
