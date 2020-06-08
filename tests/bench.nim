import std/macros
import std/random
import std/os

import criterion

import gram

const
  defGraph = defaultGraphFlags
  dgf = toInt(defGraph)
echo "graph object size ", sizeof(GraphObj[int, string, dgf])
echo "node object size ", sizeof(NodeObj[int, string])
echo "edge object size ", sizeof(EdgeObj[int, string])

when not defined(danger):
  error "build with -d:danger to run benchmarks"

var cfg = newDefaultConfig()
cfg.brief = true
cfg.budget = 1.0

when false:
  benchmark cfg:
    type
      AnN {.size: sizeof(int32).} = enum NodeA, NodeB, NodeC, NodeD
      AnE {.size: sizeof(int32).} = enum Edge1, Edge2, Edge3

    var
      g = newGraph[int, int]()
      s = newGraph[int, int]({UniqueNodes, UniqueEdges, UltraLight})
      q = newGraph[AnN, AnE]({UniqueNodes, UniqueEdges, UltraLight})
      p = newGraph[set[AnN], AnE]({UniqueNodes, UniqueEdges, UltraLight})
      r = newGraph[int32, AnE]({UniqueNodes, UniqueEdges, UltraLight})
    var
      g3 = g.add 3
      s3 = s.add 3
      q3 = q.add NodeD
      p3 = p.add {NodeA, NodeB}
      p4 = p.add {NodeB, NodeC}
      p5 = p.add {NodeD}
      r3 = r.add 3

    assert p3.value == {NodeA, NodeB}
    assert p4.value == {NodeB, NodeC}
    assert p5.value == {NodeD}
    var
      pe = p.edge(p3, Edge1, p4)
    assert p3 in pe
    assert p4 in pe

    echo "this'll take something on the order of 30s..."

    proc int_birth() {.measure.} =
      embirth(s, s3)

    proc enum_birth() {.measure.} =
      embirth(q, q3)

    proc set_birth() {.measure.} =
      embirth(p, p3)

    proc int32_birth() {.measure.} =
      embirth(r, r3)

    when "" != getEnv "TRAVIS_BUILD_DIR":
      proc slow_birth() {.measure.} =
        embirth(g, g3)

      proc slow_add() {.measure.} =
        add(g, 1)

      proc fast_add() {.measure.} =
        add(s, 1)

benchmark cfg:
  const
    biggie = 1_000

  echo "setup graphs for index benchmarks with node count " & $biggie
  var
    x = newGraph[string, int](defGraph + {UniqueNodes, ValueIndex})
    y = newGraph[string, int](defGraph + {UniqueNodes} - {ValueIndex})
  for i in 0..biggie:
    discard x.add $i
    discard y.add $i

  proc add_del_with() {.measure.} =
    ## add (and then delete) with ValueIndex
    let n = x.add $biggie
    x.del n

  proc add_del_without() {.measure.} =
    ## add (and then delete) without ValueIndex
    let n = y.add $biggie
    y.del n

  proc contains_with() {.measure.} =
    ## random node found with ValueIndex
    discard $rand(0..biggie) in x

  proc contains_without() {.measure.} =
    ## random node found without ValueIndex
    discard $rand(0..biggie) in y

  proc notin_with() {.measure.} =
    ## random node unfound with ValueIndex
    discard $rand(-biggie..0) in x

  proc notin_without() {.measure.} =
    ## random node unfound without ValueIndex
    discard $rand(-biggie..0) in y
