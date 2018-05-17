def as_bool(x)
  if x.to_s == 'true'
    return true
  elsif x.to_s == 'false'
    return false
  else
    return false
  end
end
