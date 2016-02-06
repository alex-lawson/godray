local vutil = ...

function vutil.norm(v)
  return v / vutil.mag(v)
end

function vutil.floor(v)
  return vec2(math.floor(v.x), math.floor(v.y))
end

function vutil.mag(v)
  return math.sqrt(v.x ^ 2 + v.y ^ 2)
end

function vutil.dist(v1, v2)
  return vutil.mag(v2 - v1)
end

function vutil.angle(v)
  return math.atan2(v.y, v.x)
end

function vutil.rotate(v, angle)
  local sinAngle = math.sin(angle)
  local cosAngle = math.cos(angle)

  return vec2(
    v[1] * cosAngle - v[2] * sinAngle,
    v[1] * sinAngle + v[2] * cosAngle
  )
end

function vutil.withAngle(angle)
  return vutil.rotate({1, 0}, angle)
end

function vutil.dot(v1, v2)
  return v1.x * v2.x + v1.y * v2.y
end

function vutil.cross(v1, v2)
  return v1.x * v2.y - v2.x * v1.y
end

function vutil.reflect(v, normal)
  return v - 2 * vutil.dot(v, normal) * normal
end

function vutil.distToLine(p, l1, l2)
  local v = l2 - l1
  local w = p - l1

  local c1 = vutil.dot(w, v)
  local c2 = vutil.dot(v, v)
  local b = c1 / c2

  local p2 = l1 + b * v
  return vutil.dist(p, p2)
end

function vutil.distToSegment(p, s1, s2)
  local v = s2 - s1
  local w = p - s1

  local c1 = vutil.dot(w, v)
  if c1 <= 0 then
    return vutil.dist(p, s1)
  end

  local c2 = vutil.dot(v, v)
  if c2 <= c1 then
    return vutil.dist(p, s2)
  end

  local b = c1 / c2
  local p2 = s1 + b * v
  return vutil.dist(p, p2)
end

-- check if segment pq's bounding box intersects that of segment rs
function vutil.boundingBoxesIntersect(p, q, r, s)
    return math.min(p.x, q.x) <= math.max(r.x, s.x) and math.max(p.x, q.x) >= math.min(r.x, s.x) and
           math.min(p.y, q.y) <= math.max(r.y, s.y) and math.max(p.y, q.y) >= math.min(r.y, s.y)
end

-- check if point p is on line qr
function vutil.pointOnLine(p, q, r)
  r = vutil.cross(r - q, p - q)
  return math.abs(r) < 0.01
end

function vutil.pointRightOfLine(p, q, r)
  return vutil.cross(r - q, p - q) < 0
end

function vutil.segmentTouchesOrCrossesLine(p, q, r, s)
  return vutil.pointOnLine(r, p, q) or
         vutil.pointOnLine(s, p, q) or
         (vutil.pointRightOfLine(r, p, q) ~= vutil.pointRightOfLine(s, p, q))
end

function vutil.segmentCrossesLine(p, q, r, s)
  return vutil.pointRightOfLine(r, p, q) ~= vutil.pointRightOfLine(s, p, q)
end

function vutil.segmentOnlyCrossesLine(p, q, r, s)
  return not vutil.pointOnLine(r, p, q) and
         not vutil.pointOnLine(s, p, q) and
         vutil.pointRightOfLine(r, p, q) ~= vutil.pointRightOfLine(s, p, q)
end

function vutil.intersects(p, q, r, s)
  local bbi = vutil.boundingBoxesIntersect(p, q, r, s)
  local pqrsTouch = vutil.segmentTouchesOrCrossesLine(p, q, r, s)
  local rspqTouch = vutil.segmentTouchesOrCrossesLine(r, s, p, q)
  return bbi and pqrsTouch and rspqTouch
end

-- taken from https://martin-thoma.com/how-to-check-if-two-line-segments-intersect/
function vutil.intersectsAt(p, q, r, s)
  local x1, y1, x2, y2

  -- case pq is vertical
  if p.x == q.x then
    x1 = p.x
    x2 = x1

    -- case rs is ALSO vertical
    if r.x == s.x then
      -- normalize
      if p.y > q.y then
        p, q = q, p
      end
      if r.y > s.y then
        r, s = s, r
      end
      if p.y > r.y then
        p, q, r, s = r, s, p, q
      end

      y1 = r.y
      y2 = math.min(q.y, s.y)
    -- case rs can be represented
    else
      local m, t
      m = (r.y - s.y) / (r.x - s.x)
      t = r.y - m * r.x
      y1 = m * x1 + t
      y2 = y1
    end
  -- case rs is vertical
  elseif r.x == s.x then
    x1 = r.x
    x2 = x1

    local m, t
    m = (p.y - q.y) / (p.x - q.x)
    t = p.y - m * p.x
    y1 = m * x1 + t
    y2 = y1
  -- case both lines can be represented
  else
    local mpq, mrs, tpq, trs
    mpq = (p.y - q.y) / (p.x - q.x)
    mrs = (r.y - s.y) / (r.x - s.x)
    tpq = p.y - mpq * p.x
    trs = r.y - mrs * r.x

    -- case lines are parallel
    if mpq == mrs then
      -- normalize
      if p.y > q.y then
        p, q = q, p
      end
      if r.y > s.y then
        r, s = s, r
      end
      if p.y > r.y then
        p, q, r, s = r, s, p, q
      end

      x1 = r.x
      x2 = math.min(q.x, s.x)
      y1 = mpq * x1 + tpq
      y2 = mpq * x2 + tpq
    else
      x1 = (trs - tpq) / (mpq - mrs)
      y1 = mpq * x1 + tpq
      x2 = x1
      y2 = y1
    end
  end

  if x2 == x1 and y2 == y1 then
    return vec2(x1, y1)
  else
    return vec2(x1, y1), vec2(x2, y2)
  end
end
