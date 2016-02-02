local tutil = ...

function tutil.find(t, v)
  for i, tv in ipairs(t) do
    if tv == v then return i end
  end
  return false
end

function tutil.filtered(t, f)
  local res = {}
  for i, v in ipairs(t) do
    if f(v) then
      table.insert(res, v)
    end
  end
  return res
end
