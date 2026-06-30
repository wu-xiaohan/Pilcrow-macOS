local base_path = "/"

function string.starts(String, Starts)
  any_start_with = false
  for i, Start in ipairs(Starts) do
    any_start_with = any_start_with or string.sub(String,1,string.len(Starts[i]))==Starts[i]
  end
  return any_start_with
end

function fix_path (path)
  if base_path == "/" or string.starts(path, {"/", "www.", "http", "file://", "#", "mailto:"}) then
    return path
  else
    return base_path .. "/" .. path
  end
end

function Meta(meta)
  base_path = tostring(meta.base_path or "/")
end

function Link (element)
  element.target = fix_path(element.target)
  return element
end

function Image (element)
  element.src = fix_path(element.src)
  return element
end

return {
  {Meta = Meta},
  {Link = Link},
  {Image = Image}
}
