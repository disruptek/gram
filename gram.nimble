version = "0.3.2"
author = "disruptek"
description = "simple generic graphs"
license = "MIT"

requires "https://github.com/disruptek/skiplists >= 0.5.1 & < 1.0.0"
requires "https://github.com/disruptek/grok < 1.0.0"
requires "https://github.com/haxscramper/hasts < 1.0.0"
requires "https://github.com/haxscramper/hmisc >= 0.11.10"

when not defined(release):
  requires "https://github.com/disruptek/balls >= 3.0.0 & < 4.0.0"
  requires "https://github.com/disruptek/criterion < 1.0.0"

task test, "run unit balls":
  when defined(windows):
    exec "balls.cmd"
  else:
    exec findExe"balls"
