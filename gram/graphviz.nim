import std/options

import gram

import hasts/graphviz_ast
export toDotNodeId

proc dotRepr*[N, E, F](
    graph: Graph[N, E, F],
    nodeDotRepr: proc(node: Node[N, E]): DotNode,
    edgeDotRepr: proc(edge: Edge[N, E]): DotEdge = nil,
  ): DotGraph =
  ## Convert `graph` to graphviz representation, using `edgeDotRepr` and
  ## `nodeDotRepr` to convert edges and nodes respectively.
  ##
  ## Default graph styling is monospaced rectangle with left-aligned text,
  ## but it can be changed later by setting `styleNode` and `styleEdge`
  ## fields, or configuring each node individually in converter callbacks.
  ##
  ## If ids for edges/nodes are not created in callbacks they will be added
  ## automatically based on `hash()` for edge/node.
  result = DotGraph(
    styleNode: DotNode(
      shape: nsaBox,
      labelAlign: nlaLeft,
      fontname: "consolas",
    ),
    styleEdge: DotEdge(
      fontname: "consolas"
    )
  )

  for node in nodes(graph):
    var dotNode = nodeDotRepr(node)
    if dotNode.id.isEmpty():
      dotNode.id = hash(node)

    result.nodes.add dotNode

  if edgeDotRepr.isNil:
    for edge in edges(graph):
      result.edges.add DotEdge(
        src: hash(edge.source),
        to: @[hash(edge.source)]
      )

  else:
    for edge in edges(graph):
      var dotEdge = edgeDotRepr(edge.edge)
      if dotEdge.src.isEmpty():
        dotEdge.src = hash(edge.source)

      if dotEdge.to.len == 0:
        dotEdge.to = @[hash(edge.target)]

      result.edges.add dotEdge

proc dotRepr*[N, E, F](graph: Graph[N, E, F]): DotGraph =
  ## Convert `graph` to graphviz representation, using stringification for
  ## node and edge values.
  return dotRepr(
    graph,
    proc(node: Node[N, E]): DotNode =
      DotNode(shape: nsaRect, label: some $node.value),

    proc(edge: Edge[N, E]): DotEdge =
      DotEdge(label: some $edge.value),
  )

proc toPng*(graph: DotGraph; filename: string) =
  ## Render `graph` to a PNG with the given filename.
  graphviz_ast.toPng(graph, filename)
