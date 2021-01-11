import testes

import gram
import hasts/graphviz_ast

template checkMembership(g: Graph; n: Node): untyped =
  check n in g
  check n.value in g
  check n == g[n.value]
  check n.value == g[n.value].value

template checkEdge(g: Graph; e: Edge; s: Node; t: Node): untyped =
  check e in g
  check s in e
  check t in e

testes:
  ## make a new graph with int nodes and string edges.
  var
    g = newGraph[int, string]()

  ## tell me about it
  check card(g.flags) > 0

  ## add an item to the graph
  var
    n3 = g.add 3
  check len(g) == 1

  ## equality and membership
  checkMembership(g, n3)

  ## second node
  var
    n9 = g.add 9
  g.incl n9
  check g.len == 2

  ## check that we can get the new node.
  checkMembership(g, n9)
  ## but we can still get the first node?
  checkMembership(g, n3)

  ## empty the graph.
  clear g
  check len(g) == 0

  ## now add some new immutable nodes.
  let
    n5 = g.add 5
    n7 = g.add 7
  check len(g) == 2
  checkMembership(g, n5)
  checkMembership(g, n7)

  ## now add back in nodes we removed.
  incl(g, n9)
  incl(g, n3)

  ## and we can still get those, right?
  checkMembership(g, n9)
  checkMembership(g, n3)

  ## okay, so it seems like we can get things in and out.
  ## let's try making an edge...
  var
    squared = g.edge(n3, "squared", n9)
  checkEdge(g, squared, n3, n9)

  ## and remove it from a node using the edge object
  n3.del squared
  check squared notin n3
  check squared notin n9
  check "squared" notin n3
  check "squared" notin n9

  ## and add it back in
  squared = g.edge(n3, "squared", n9)
  checkEdge(g, squared, n3, n9)

  ## and now remove it by value
  n9.del "squared"
  check "squared" notin n3
  check "squared" notin n9

  var graph = newGraph[int, string]()

  let node1 = graph.add 12
  discard graph.edge(node1, "Hello", graph.add 13)

  let dotg = graph.dotRepr()
  echo dotg
  # dotg.toPng("/tmp/image.png")
