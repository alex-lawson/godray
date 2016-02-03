local vutil = require "vutil"

local RayRelay = ...

function RayRelay.new(position, angle, active)
  local newRayRelay = {
    onColor = vec4(1.0, 1.0, 0.5, 0.7),
    offColor = vec4(0.5, 0.5, 0.2, 1.0),
    position = position,
    length = MaxRayLength
  }

  local offDrawables = am.group():tag("offDrawables")
  offDrawables:append(am.circle(vec2(0, 0), 5, newRayRelay.offColor))
  offDrawables:append(am.rect(0, -1, 8, 1, newRayRelay.offColor))
  local onDrawables = am.group():tag("onDrawables")
  onDrawables:append(am.circle(vec2(0, 0), 5, newRayRelay.onColor))
  -- onDrawables:append(am.rect(0, -2, MaxRayLength, 2, newRayRelay.onColor))
  newRayRelay.node = am.translate(position) ^ am.rotate(0) ^ { onDrawables, offDrawables }

  setmetatable(newRayRelay, { __index = RayRelay })
  newRayRelay:setActive(active)
  newRayRelay:setAngle(angle)

  return newRayRelay
end

function RayRelay:makePermanent()
  self:setActive(true)
  self.permanent = true
end

function RayRelay:setActive(active)
  if not self.permanent and active ~= self.active then
    self.active = active
    self.node("offDrawables").hidden = self.active
    self.node("onDrawables").hidden = not self.active
  end
end

function RayRelay:setAngle(newAngle)
  self.angle = newAngle
  self.node("rotate").angle = newAngle
end

function RayRelay:setLength(newLength)
  self.length = newLength
  -- self.node("onDrawables")("rect").x2 = self.length
end

function RayRelay:propagateRay(relays, walls, visited)
  visited = visited or {}
  table.insert(visited, self)
  self:checkCollision(walls)
  self:findTarget(relays, walls)
  if self.target and not table.search(visited, self.target) then
    table.merge(visited, self.target:propagateRay(relays, walls, visited))
  end
  return visited
end

function RayRelay:inSight(p, walls)
  for i = 1, #walls - 1, 2 do
    local a = walls[i]
    local b = walls[i + 1]
    if vutil.intersects(self.position, p, a, b) then
      return false
    end
  end
  return true
end

function RayRelay:checkCollision(walls)
  local bestPoint
  local bestDist
  local lineEnd = vutil.floor(self.position + vutil.withAngle(self.angle) * MaxRayLength)
  for i = 1, #walls - 1, 2 do
    local a = walls[i]
    local b = walls[i + 1]
    if vutil.intersects(self.position, lineEnd, a, b) then
      local thisPoint = vutil.floor(vutil.intersectsAt(self.position, lineEnd, a, b))
      local thisDist = vutil.dist(self.position, thisPoint)
      if not bestDist or thisDist < bestDist then
        bestPoint = thisPoint
        bestDist = thisDist
      end
    end
  end
  if bestPoint then
    self:setLength(bestDist)
  else
    self:setLength(MaxRayLength)
  end
end

function RayRelay:setTarget(target)
  if target then
    self.target = target
    self:setAngle(vutil.angle(target.position - self.position))
    self:setLength(vutil.dist(self.position, target.position))
  else
    if self.target then
      self.target = nil
    end
  end
end

function RayRelay:updateTarget(relays, walls)
  if self.target then
    if not self:inSight(self.target.position, walls) then
      self:findTarget(relays, walls)
    end
  else
    self:findTarget(relays, walls)
  end
end

function RayRelay:findTarget(relays, walls)
  local snapDist = 15
  local snapTo
  local closestDistance = 1000
  local lineEnd = self:rayEndpoint()
  -- log("Finding targets in ray %s to %s", self.position, lineEnd)
  for _, relay in pairs(relays) do
    if relay ~= self then
      if self:inSight(relay.position, walls) then
        local thisDist = vutil.distToSegment(relay.position, self.position, lineEnd)
        -- log("relay at %s is %s from the line", relay.position, thisDist)
        if thisDist < snapDist and thisDist < closestDistance then
          snapTo = relay
          closestDistance = thisDist
        end
      end
    end
  end

  if snapTo then
    self:setTarget(snapTo)
  else
    self:setTarget(nil)
  end
end

function RayRelay:rayEndpoint()
  return self.position + vutil.withAngle(self.angle) * self.length
end
