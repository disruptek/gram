version = "0.1.1"
author = "disruptek"
description = "simple generic graphs"
license = "MIT"
requires "nim >= 1.2.6"

requires "https://github.com/disruptek/testes >= 0.2.2 & < 1.0.0"
requires "https://github.com/disruptek/skiplists < 1.0.0"
requires "https://github.com/disruptek/grok < 1.0.0"
requires "https://github.com/disruptek/criterion < 1.0.0"

proc execCmd(cmd: string) =
  echo "execCmd:" & cmd
  exec cmd

proc execTest(test: string) =
  when getEnv("GITHUB_ACTIONS", "false") != "true":
    execCmd "nim c        -f -r " & test
    execCmd "nim c --gc:arc -d:danger -r " & test
  else:
    execCmd "nim c              -r " & test
    execCmd "nim cpp            -r " & test
    execCmd "nim c   -d:danger  -r " & test
    execCmd "nim cpp -d:danger  -r " & test
    # gram requires 1.3 for arc to work
    when (NimMajor, NimMinor) >= (1, 3):
      execCmd "nim c --useVersion:1.0 -d:danger -r " & test
      execCmd "nim c   --gc:arc -d:danger -r " & test
      execCmd "nim cpp --gc:arc -d:danger -r " & test

task test, "run tests for ci":
  execTest("tests/test.nim")
