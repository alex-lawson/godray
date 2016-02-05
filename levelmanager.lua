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

function LevelManager:traceRay(position, angle, points, recursion, lastMirror)
  points = points or {position}
  recursion = recursion or 0

  if recursion > 10 then return points end

  -- log("tracing ray with recursion %s position %s angle %s", recursion, position, angle)

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
      return self:traceRay(relay[1], relay[2], points, recursion + 1)
    end
  end

  local wallPoint, wallDist
  local collidesWall = self:collidesWall(position, searchEndpoint)
  if collidesWall then
    wallPoint, wallDist = self:collidesWallAt(position, searchEndpoint)
  end

  local mirrorPoint, mirrorDist, mirror
  local collidesMirror = self:collidesMirror(position, searchEndpoint, lastMirror)
  if collidesMirror then
    mirrorPoint, mirrorDist, mirror = self:collidesMirrorAt(position, searchEndpoint, lastMirror)
  end

  if collidesMirror and (not collidesWall or wallDist > mirrorDist) then
    local v = mirrorPoint - position
    local sv = mirror[2] - mirror[1]
    local normal = vec2(-sv.y, sv.x)
    if vutil.pointRightOfLine(position, mirror[1], mirror[2]) ~= vutil.pointRightOfLine(mirrorPoint + normal, mirror[1], mirror[2]) then
      normal = vec2(sv.y, -sv.x)
    end
    normal = vutil.norm(normal)
    local reflectVector = vutil.reflect(v, normal)
    -- mirrorPoint = mirrorPoint + (1.2 * normal)
    table.insert(points, mirrorPoint)
    return self:traceRay(mirrorPoint, vutil.angle(reflectVector), points, recursion + 1, mirror)
  elseif collidesWall then
    table.insert(points, wallPoint)
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
        if not self:collidesWall(p, relay[1]) and not self:collidesMirror(p, relay[1]) then
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

function LevelManager:collidesMirror(p, q, exclude)
  -- log("searching for mirrors excluding %s %s", exclude and exclude[1] or "nothing", exclude and exclude[2] or "at all")
  return self.collidesSegment(self.mirrors, p, q, exclude)
end

function LevelManager.collidesSegment(segments, p, q, exclude)
  if #segments < 2 then return false end

  for i = 1, #segments - 1, 2 do
    local a = segments[i]
    local b = segments[i + 1]
    if not (exclude and a == exclude[1] and b == exclude[2]) then
      if vutil.intersects(p, q, a, b) then
        return true
      end
    else
      -- log("ignoring segment %s %s", a, b)
    end
  end
  return false
end

function LevelManager:collidesWallAt(p, q)
  return self.collidesSegmentAt(self.walls, p, q)
end

function LevelManager:collidesMirrorAt(p, q, exclude)
  return self.collidesSegmentAt(self.mirrors, p, q, exclude)
end

function LevelManager.collidesSegmentAt(segments, p, q)
  if #segments < 2 then return nil end
  local bestPoint, bestDist, bestSegment
  for i = 1, #segments - 1, 2 do
    local a = segments[i]
    local b = segments[i + 1]
    if not (exclude and a == exclude[1] and b == exclude[2]) then
      if vutil.intersects(p, q, a, b) then
        local thisPoint = vutil.floor(vutil.intersectsAt(p, q, a, b))
        local thisDist = vutil.dist(p, thisPoint)
        if not bestDist or thisDist < bestDist then
          bestPoint = thisPoint
          bestDist = thisDist
          bestSegment = {a, b}
        end
      end
    else
      -- log("AT ignoring segment %s %s", a, b)
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
