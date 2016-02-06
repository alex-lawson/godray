local vutil = require "vutil"

MinimumBounce = 3
RaySnapDistance = 10

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
    mirrorPreview = nil,
    lastRecursion = 0
  }

  setmetatable(newLevelManager, { __index = LevelManager })

  return newLevelManager
end

-- RELAY MANAGEMENT

function LevelManager:setSource(sourcePos, sourceAngle)
  self.sourcePos = sourcePos
  self.sourceAngle = sourceAngle
end

function LevelManager:addRelay(position, angle, reflective)
  table.insert(self.relays, {position, angle, reflective})
end

function LevelManager:removeRelay(relay)
  table.remove(self.relays, table.search(self.relays, relay))
end

function LevelManager:relayMirrorGeometry()
  local geometry = {}
  for i, relay in ipairs(self.relays) do
    if relay[3] then
      table.insert(geometry, relay[1] + vutil.withAngle(relay[2] + math.pi * 0.5) * RaySnapDistance)
      table.insert(geometry, relay[1] + vutil.withAngle(relay[2] - math.pi * 0.5) * RaySnapDistance)
    end
  end
  return geometry
end

function LevelManager:addDemoRelays()
  self:addRelay(vec2(self.sourcePos.x, 0), 0)
end

-- RAY MANAGEMENT

function LevelManager:updateRay()
  self.ray, self.lastRecursion = self:traceRay(self.sourcePos, self.sourceAngle)
end

function LevelManager:traceRay(position, angle, points, recursion, lastMirror)
  points = points or {position}
  recursion = recursion or 0

  if recursion > 10 then return points, recursion end

  -- log("tracing ray with recursion %s position %s angle %s", recursion, position, angle)
  local searchEndpoint = position + vutil.withAngle(angle) * self.maxRayLength
  local relay = self:relayNearLine(position, searchEndpoint, RaySnapDistance, lastMirror)
  if relay then
    local oldIndex = table.search(points, relay[1])
    if oldIndex == #points - 1 then
      return points, recursion
    elseif relay[3] then
      local v = relay[1] - position
      local reflectVector = vutil.reflect(v, vutil.withAngle(relay[2]))
      table.insert(points, relay[1])
      return self:traceRay(relay[1], vutil.angle(reflectVector), points, recursion + 1)
    elseif oldIndex then
      table.insert(points, relay[1])
      return points, recursion
    else
      table.insert(points, relay[1])
      return self:traceRay(relay[1], relay[2], points, 0)
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

  if collidesMirror and mirrorDist < MinimumBounce and
      (#points < 2 or vutil.dist(points[#points], points[#points - 1])) then
    return points, 99
  elseif collidesMirror and (not collidesWall or wallDist > mirrorDist) then
    local v = mirrorPoint - position
    local sv = mirror[2] - mirror[1]
    local normal = vutil.norm(vec2(-sv.y, sv.x))
    local reflectVector = vutil.reflect(v, normal)
    table.insert(points, mirrorPoint)
    return self:traceRay(mirrorPoint, vutil.angle(reflectVector), points, recursion + 1, mirror)
  elseif collidesWall then
    table.insert(points, wallPoint)
    return points, recursion
  end

  table.insert(points, searchEndpoint)
  return points, recursion
end

function LevelManager:relayNearLine(p, q, maxDist, excludeMirror)
  maxDist = maxDist or 15
  local bestRelay, bestDist
  for i, relay in ipairs(self.relays) do
    if relay[1] ~= p then
      local thisDist = vutil.distToSegment(relay[1], p, q)
      if thisDist < maxDist and (not bestDist or thisDist < bestDist) then
        if not self:collidesWall(p, relay[1]) and not self:collidesMirror(p, relay[1], excludeMirror) then
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
  table.insert(self.walls, {p, q})
end

function LevelManager:addMirror(p, q)
  table.insert(self.mirrors, {p, q})
end

function LevelManager:removeWall(wall)
  table.remove(self.walls, table.search(self.walls, wall))
end

function LevelManager:removeMirror(mirror)
  table.remove(self.mirrors, table.search(self.mirrors, mirror))
end

function LevelManager:wallNearPoint(p, maxDist)
  return self.segmentNearPoint(self.walls, p, maxDist)
end

function LevelManager:mirrorNearPoint(p, maxDist)
  return self.segmentNearPoint(self.mirrors, p, maxDist)
end

function LevelManager.segmentNearPoint(segments, p, maxDist)
  maxDist = maxDist or 15
  local bestSegment, bestDist
  for i, segment in ipairs(segments) do
    local thisDist = vutil.distToSegment(p, segment[1], segment[2])
    if thisDist <= maxDist and (not bestDist or thisDist < bestDist) then
      bestDist = thisDist
      bestSegment = segment
    end
  end
  return bestSegment, bestDist
end

function LevelManager:wallRenderGeometry()
  return self.geometryWithPreview(self.walls, self.wallPreview)
end

function LevelManager:mirrorRenderGeometry()
  local finalGeometry = self:relayMirrorGeometry()
  table.append(finalGeometry, self.geometryWithPreview(self.mirrors, self.mirrorPreview))
  return finalGeometry
end

function LevelManager.geometryWithPreview(baseGeometry, previewGeometry)
  local finalGeometry = {}

  for i, segment in ipairs(baseGeometry) do
    table.append(finalGeometry, segment)
  end

  if previewGeometry then
    table.append(finalGeometry, previewGeometry)
  end

  return finalGeometry
end

function LevelManager:collidesWall(p, q)
  return self.collidesSegment(self.walls, p, q)
end

function LevelManager:collidesMirror(p, q, exclude)
  -- log("searching for mirrors excluding %s %s", exclude and exclude[1] or "nothing", exclude and exclude[2] or "at all")
  return self.collidesSegment(self.mirrors, p, q, exclude)
end

function LevelManager.collidesSegment(segments, p, q, exclude)
  for i, segment in ipairs(segments) do
    if not (exclude and segment[1] == exclude[1] and segment[2] == exclude[2]) then
      if vutil.intersects(p, q, segment[1], segment[2]) then
        return true
      end
    else
      -- log("ignoring segment %s %s", segment[1], segment[2])
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

function LevelManager.collidesSegmentAt(segments, p, q, exclude)
  local bestPoint, bestDist, bestSegment
  for i, segment in ipairs(segments) do
    if segment ~= exclude then
      if vutil.intersects(p, q, segment[1], segment[2]) then
        local thisPoint = vutil.floor(vutil.intersectsAt(p, q, segment[1], segment[2]))
        local thisDist = vutil.dist(p, thisPoint)
        if not bestDist or thisDist < bestDist then
          bestPoint = thisPoint
          bestDist = thisDist
          bestSegment = segment
        end
      end
    else
      -- log("AT ignoring segment %s %s", segment[1], segment[2])
    end
  end
  return bestPoint, bestDist, bestSegment
end

function LevelManager:addDemoWalls()
  self.walls = {
    {vec2(-400, -200),
    vec2(-50, -200)},
    {vec2(-50, -200),
    vec2(50, -280)},
    {vec2(50, -280),
    vec2(400, -280)}
  }
end

function LevelManager:addDemoMirrors()
  self.mirrors = {
    {vec2(200, 50),
    vec2(300, -50)},
    {vec2(-300, 0),
    vec2(-200, 30)},
    {vec2(-300, 0),
    vec2(-200, -30)}
  }
end
