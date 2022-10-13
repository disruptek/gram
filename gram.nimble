version = "0.4.1"
author = "disruptek"
description = "simple generic graphs"
license = "MIT"

requires "https://github.com/disruptek/skiplists >= 0.5.4 & < 1.0.0"
requires "https://github.com/disruptek/grok < 1.0.0"

when false:
  # this is merely a hint; these fail under strict settings,
  # so we don't bother to run the tgraphviz test under balls
  requires "https://github.com/haxscramper/hmisc >= 0.9.15 & <= 0.11.4"
  requires "https://github.com/haxscramper/hasts >= 0.1.3 & <= 0.1.6"

when not defined(release):
  requires "https://github.com/disruptek/balls >= 3.0.0 & < 4.0.0"
  requires "https://github.com/disruptek/criterion < 1.0.0"

task test, "run unit balls":
  when defined(windows):
    exec "balls.cmd"
  else:
    exec findExe"balls"
