when not (compiles do: import hasts, hmisc):
  echo "skipping test because hasts|hmisc isn't available"
else:
  import gram
  import gram/graphviz

  var graph = newGraph[int, string]()

  let node1 = graph.add 12
  discard graph.edge(node1, "Hello", graph.add 13)

  let dotg = graph.dotRepr()
  echo dotg
  dotg.toPng("image.png")
