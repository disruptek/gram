import testes

import gram
import skiplists

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
    g3 = g.add 3
  check len(g) == 1

  ## equality and membership
  checkMembership(g, g3)

  ## second node
  var
    g9 = g.add 9
  g.incl g9
  check g.len == 2

  ## check that we can get the new node.
  checkMembership(g, g9)
  ## but we can still get the first node?
  checkMembership(g, g3)

  ## empty the graph.
  clear g
  check len(g) == 0

  ## now add some new immutable nodes.
  let
    g5 = g.add 5
    g7 = g.add 7
  check len(g) == 2
  checkMembership(g, g5)
  checkMembership(g, g7)

  ## now add back in nodes we removed.
  incl(g, g9)
  incl(g, g3)

  ## and we can still get those, right?
  checkMembership(g, g9)
  checkMembership(g, g3)

  ## okay, so it seems like we can get things in and out.
  ## let's try making an edge...
  var
    squared = g.edge(g3, "squared", g9)
  checkEdge(g, squared, g3, g9)
