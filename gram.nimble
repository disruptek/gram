version = "0.0.9"
author = "disruptek"
description = "lightweight generic graphs"
license = "MIT"
requires "nim >= 1.2.6"

requires "https://github.com/disruptek/testes >= 0.2.2 & < 1.0.0"

proc execTest(test: string) =
  exec "nim c           -f -r " & test
  exec "nim c   -d:danger  -r " & test
  exec "nim cpp            -r " & test
  exec "nim cpp -d:danger  -r " & test
  when (NimMajor, NimMinor) >= (1, 3):
    exec "nim c --useVersion:1.0 -d:danger -r " & test
    exec "nim c   --gc:arc -r " & test
    exec "nim c   --gc:arc -d:danger -r " & test
    exec "nim cpp --useVersion:1.0 -d:danger -r " & test
    exec "nim cpp --gc:arc -r " & test
    exec "nim cpp --gc:arc -d:danger -r " & test

task test, "run tests for travis":
  execTest("tests/test.nim")

task docs, "generate docs":
  exec "nim doc --project --outdir:docs gram.nim"
