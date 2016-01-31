local tutil = ...

function tutil.find(t, v)
  for i, tv in ipairs(t) do
    if tv == v then return i end
  end
  return false
end
