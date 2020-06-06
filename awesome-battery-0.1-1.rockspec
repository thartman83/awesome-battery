package = "awesome-battery"
version = "0.1-1"
source = {
  url = "git://github.com/thartman83/awesome-battery",
  tag = "v0.1"  
}

description = {
  summary = "Awesome battery widget",
  detailed = [[
  Display battery information for the Awesome windows manager
  ]],
  homepage = "git://github.com/thartman83/awesome-battery",
  license = "GPL v2"
}

dependencies = {
  "lua >= 5.1"
}

supported_platforms = { "linux" }

build = {
  type = "builtin",
  modules = { awesome_battery = "init.lua" }
}