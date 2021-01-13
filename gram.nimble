version = "0.3.1"
author = "disruptek"
description = "simple generic graphs"
license = "MIT"

requires "https://github.com/disruptek/skiplists >= 0.5.0 & < 1.0.0"
requires "https://github.com/disruptek/grok < 1.0.0"
requires "https://github.com/haxscramper/hasts < 1.0.0"

when not defined(release):
  requires "https://github.com/disruptek/testes >= 1.0.0 & < 2.0.0"
  requires "https://github.com/disruptek/criterion < 1.0.0"

task test, "run unit testes":
  when defined(windows):
    exec "testes.cmd"
  else:
    exec findExe"testes"
