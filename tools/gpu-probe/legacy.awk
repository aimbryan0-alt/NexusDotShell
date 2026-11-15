function emit() {
  if (driver != "" && pdev != "" && (engine > 0 || shared > 0 || device_mem > 0)) {
    id = client != "" ? client : fd
    key = pid SUBSEP pdev SUBSEP driver SUBSEP id
    if (engine > engines[key])
      engines[key] = engine
    if (shared > shared_kb[key])
      shared_kb[key] = shared
    if (device_mem > device_kb[key])
      device_kb[key] = device_mem
  }
}

{
  count = split($0, path, "/")
  pid = path[count - 2]
  fd = path[count]
  driver = ""
  pdev = ""
  client = ""
  engine = 0
  shared = 0
  device_mem = 0
  filename = $0

  while ((getline line < filename) > 0) {
    split(line, fields, /[ \t]+/)
    name = fields[1]
    if (name == "drm-driver:")
      driver = fields[2]
    else if (name == "drm-pdev:")
      pdev = fields[2]
    else if (name == "drm-client-id:")
      client = fields[2]
    else if (name ~ /^drm-engine-[^:]+:/ && fields[2] ~ /^[0-9]+$/)
      engine += fields[2]
    else if (name ~ /^drm-total-system[^:]*:/) {
      amount = fields[2] + 0
      if (fields[3] == "MiB")
        amount *= 1024
      else if (fields[3] == "GiB")
        amount *= 1048576
      shared += amount
    } else if (name ~ /^drm-total-(vram|local)[^:]*:/) {
      amount = fields[2] + 0
      if (fields[3] == "MiB")
        amount *= 1024
      else if (fields[3] == "GiB")
        amount *= 1048576
      device_mem += amount
    }
  }
  close(filename)
  emit()
}

END {
  for (key in engines) {
    split(key, parts, SUBSEP)
    printf "ENGINE|%s|%s|%s|%s|%.0f|%.0f|%.0f\n",
      parts[1], parts[2], parts[3], parts[4],
      engines[key], shared_kb[key], device_kb[key]
  }
}
