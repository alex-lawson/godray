local vutil = require "vutil"
local tutil = require "tutil"

local RayRelay = ...

function RayRelay.new(position, angle, active)
  local newRayRelay = {
    position = position,
    length = MaxRayLength
  }

  local offDrawables = am.group():tag("offDrawables")
  offDrawables:append(am.circle(vec2(0, 0), 5, vec4(0.8, 0.4, 0.2, 1.0)))
  offDrawables:append(am.rect(0, -1, 8, 1, vec4(0.8, 0.4, 0.2, 1.0)))
  local onDrawables = am.group():tag("onDrawables")
  onDrawables:append(am.circle(vec2(0, 0), 5, RayColor))
  onDrawables:append(am.rect(0, -2, MaxRayLength, 2, RayColor))
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

function RayRelay:inSight(p, geometry)
  for i = 1, #geometry - 1, 2 do
    local a = geometry[i]
    local b = geometry[i + 1]
    if vutil.intersects(self.position, p, a, b) then
      return false
    end
  end
  return true
end

function RayRelay:checkCollision(geometry)
  local bestPoint
  local bestDist
  local lineEnd = vutil.floor(self.position + vutil.withAngle(self.angle) * MaxRayLength)
  for i = 1, #geometry - 1, 2 do
    local a = geometry[i]
    local b = geometry[i + 1]
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
    self.length = bestDist
  else
    self.length = MaxRayLength
  end
  self.node("onDrawables")("rect").x2 = self.length
end

function RayRelay:setTarget(target)
  if target then
    self.target = target
    self:setAngle(vutil.angle(target.position - self.position))
    self.length = vutil.dist(self.position, target.position)
    self.node("onDrawables")("rect").x2 = self.length
  else
    if self.target then
      self.target = nil
    end
  end
end

function RayRelay:findTarget(relays, geometry)
  local snapDist = 15
  local snapTo
  local closestDistance = 1000
  local lineEnd = self.position + vutil.withAngle(self.angle) * self.length
  -- log("Finding targets in ray %s to %s", self.position, lineEnd)
  for _, relay in pairs(relays) do
    if relay ~= self then
      if self:inSight(relay.position, geometry) then
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
    self.target:checkCollision(geometry)
    self.target:findTarget(relays, geometry)
  else
    self:setTarget(nil)
  end
end

function RayRelay:rayLine()
  return self.position, self.position + vutil.withAngle(self.angle)
end
