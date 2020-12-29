version = "0.2.0"
author = "disruptek"
description = "simple generic graphs"
license = "MIT"

requires "https://github.com/disruptek/testes >= 0.7.8 & < 1.0.0"
requires "https://github.com/disruptek/skiplists >= 0.4.1 & < 1.0.0"
requires "https://github.com/disruptek/grok < 1.0.0"
requires "https://github.com/disruptek/criterion < 1.0.0"

task test, "run unit testes":
  when defined(windows):
    exec "testes.cmd"
  else:
    exec findExe"testes"
