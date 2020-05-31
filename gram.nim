import std/strutils
import std/monotimes
import std/lists
import std/intsets
import std/macros

##
## Goals
##
## - Sacrifice a little RAM for O(1) operations.
## - Sacrifice a little CPU for less memory churn.
## - Aggressively remove API that proves useless or confusing.
## - Aggressively abstract and hide complexity from the user.
## - Perfect is the enemy of Good.
##

type
  GraphFlag* {.size: sizeof(int).} = enum
    QueryResult = "the graph only makes sense in relation to another graph"
    UniqueNodes = "the nodes in the graph all have unique values"
    UniqueEdges = "the edges in the graph all have unique values"
    Directed    = "edges have different semantics for source and target"
    Undirected  = "edges have identical semantics for source and target"
    SelfLoops   = "nodes may have edges that target themselves"
    Ultralight  = "the graph is even lighter"

  EdgeFlag {.size: sizeof(int).} = enum
    Incoming
    Outgoing

  GraphObj[N, E; F: static[int]] = object
    nodes: Nodes[N, E]
    members: IntSet

  Graph*[N, E; F: static[int]] = ref GraphObj[N, E, F] ##
  ## A collection of nodes and edges.
  ##
  ## Nodes have a user-supplied `.value` of type `N`.
  ## Edges have a user-supplied `.value` of type `E`.

  Node*[N, E] = ref NodeObj[N, E]                            ##
  ## A node in the graph.
  ##
  ## Nodes have a user-supplied `.value` of type `N`.
  ## Edges have a user-supplied `.value` of type `E`.
  NodeObj[N, E] = object
    value*: N
    id: int
    incoming: Edges[N, E]
    outgoing: Edges[N, E]
    edges: IntSet
    peers: IntSet
    initialized: bool
  Nodes[N, E] = distinct DoublyLinkedList[Node[N, E]]

  Edge*[N, E] = ref EdgeObj[N, E]                            ##
  ## An edge connects two nodes.
  ##
  ## Nodes have a user-supplied `.value` of type `N`.
  ## Edges have a user-supplied `.value` of type `E`.
  EdgeObj[N, E] = object
    value*: E
    id: int
    source: Node[N, E]
    target: Node[N, E]
  Edges[N, E] = distinct DoublyLinkedList[Edge[N, E]]

  GraphFlags* = int

  EdgeResult*[N, E] = tuple
    source: Node[N, E]
    edge: Edge[N, E]
    target: Node[N, E]

converter toInt(flags: static[set[GraphFlag]]): GraphFlags =
  # the vm cannot cast between set and int
  when nimvm:
    for flag in items(flags):
      result = `or`(result, 1 shl flag.ord)
  else:
    result = cast[int](flags)

converter toFlags(value: int): set[GraphFlag] =
  # the vm cannot cast between set and int
  when nimvm:
    for flag in items(GraphFlag):
      if `and`(value, 1 shl flag.ord) != 0:
        result.incl flag
  else:
    result = cast[set[GraphFlag]](value)

const
  defaultGraphFlags* = {Directed, SelfLoops}

# just a hack to output the example numbers during docgen...
when defined(nimdoc):
  var
    exampleCounter {.compileTime.}: int

macro example(x: untyped): untyped =
  result = x
  when defined(nimdoc):
    for node in x.last:
      if node.kind == nnkCall:
        if node[0].kind == nnkIdent:
          if $node[0] == "runnableExamples":
            inc exampleCounter
            let id = repr(x[0])
            hint "fig. $1 for $2:" % [ $exampleCounter, $id ]
            hint indent(repr(node[1]), 4)

template graph[N, E, F](g: Graph[N, E, F]): Graph[N, E, F] = g
template node[N, E](n: Node[N, E]): Node[N, E] = n
template edge[N, E](e: Edge[N, E]): Edge[N, E] = e

proc newNodes[N, E](): Nodes[N, E] =
  ## Create a new container for nodes.
  result = Nodes[N, E] initDoublyLinkedList[Node[N, E]]()

proc newEdges[N, E](): Edges[N, E] =
  ## Create a new container for edges.
  result = Edges[N, E] initDoublyLinkedList[Edge[N, E]]()

iterator nodes[N, E](list: var Edges[N, E]): DoublyLinkedNode[Edge[N, E]] =
  for item in nodes(DoublyLinkedList[Edge[N, E]] list):
    yield item

iterator nodes[N, E](list: var Nodes[N, E]): DoublyLinkedNode[Node[N, E]] =
  for item in nodes(DoublyLinkedList[Node[N, E]] list):
    yield item

iterator mitems[N, E](list: var Edges[N, E]): var Edge[N, E] =
  for item in mitems(DoublyLinkedList[Edge[N, E]] list):
    yield item

iterator mitems[N, E](list: var Nodes[N, E]): var Node[N, E] =
  for item in mitems(DoublyLinkedList[Node[N, E]] list):
    yield item

iterator items[N, E](list: Edges[N, E]): Edge[N, E] =
  for item in items(DoublyLinkedList[Edge[N, E]] list):
    yield item

iterator items[N, E](list: Nodes[N, E]): Node[N, E] =
  for item in items(DoublyLinkedList[Node[N, E]] list):
    yield item

proc append[N, E](list: var Nodes[N, E]; value: Node[N, E]) =
  append(DoublyLinkedList[Node[N, E]] list, newDoublyLinkedNode(value))

proc append[N, E](list: var Edges[N, E]; value: Edge[N, E]) =
  append(DoublyLinkedList[Edge[N, E]] list, newDoublyLinkedNode(value))

proc remove[N, E](list: var Edges[N, E]; node: Edge[N, E]) =
  ## Remove an edge from container.
  for item in nodes(list):
    if item.value.id == node.id:
      remove(DoublyLinkedList[Edge[N, E]] list, item)

proc remove[N, E](list: var Nodes[N, E]; node: Node[N, E]) =
  ## Remove a node from container.
  for item in nodes(list):
    if item.value.id == node.id:
      remove(DoublyLinkedList[Node[N, E]] list, item)

proc clear[N, E](list: var Edges[N, E]) =
  ## Remove all edges from container.
  for item in nodes(list):
    remove(DoublyLinkedList[Edge[N, E]] list, item)

proc clear[N, E](list: var Nodes[N, E]) =
  ## Remove all nodes from container.
  for item in nodes(list):
    remove(DoublyLinkedList[Node[N, E]] list, item)

template newGraph*[N, E](flags: typed): auto =
  ## Create a new graph; nodes will hold `N` while edges will hold `E`.
  runnableExamples:
    var g = newGraph[int, string]()
    assert g != nil

  block:
    var
      result = Graph[N, E, toInt(flags)]()
    result.nodes = newNodes[N, E]()
    result.members = initIntSet()
    result

template newGraph*[N, E](): auto = newGraph[N, E](defaultGraphFlags)

proc `=destroy`[N, E](node: var NodeObj[N, E]) =
  ## Prepare a node for destruction.
  clear(node.edges)
  clear(node.peers)
  clear(node.incoming)
  clear(node.outgoing)
  # just, really fuck this thing up
  node.id = 0

proc `=destroy`[N, E](edge: var EdgeObj[N, E]) =
  ## Prepare an `edge` for destruction.
  edge.source = nil
  edge.target = nil
  # just, really fuck this thing up
  edge.id = 0

proc init[N, E, F](graph: Graph[N, E, F]; node: var Node[N, E]) {.inline.} =
  ## Initialize a `node` for use in the graph.
  if not node.initialized:
    node.incoming = newEdges[N, E]()
    node.outgoing = newEdges[N, E]()
    node.edges = initIntSet()
    node.peers = initIntSet()
    node.initialized = true

proc nodeId(node: Node): int {.inline.} =
  result = getMonoTime().ticks.int

proc hasLightNodes(flags: static[GraphFlags]): bool =
  result = {UniqueNodes, UltraLight} <= flags.toFlags

proc lightId(item: Node | Edge): int32 =
  when sizeof(item.value) > sizeof(int32):
    raise
  else:
    when item.value is set:
      result = cast[int32](item.value)
    elif item.value is Ordinal:
      result = ord(item.value).int32
    else:
      raise

proc nodeId[N; E, F](node: Node; graph: Graph[N, E, F]): int {.inline.} =
  block:
    when F.hasLightNodes:
      when sizeof(N) <= sizeof(int32):
        result = lightId(node)
        break
    result = nodeId(node)

proc edgeId(edge: Edge): int {.inline.} =
  result = getMonoTime().ticks.int

proc hasLightEdges(flags: static[GraphFlags]): bool =
  result = {UniqueEdges, UltraLight} <= flags.toFlags

proc edgeId[N, E, F](edge: Edge; graph: Graph[N, E, F]): int {.inline.} =
  block:
    when F.hasLightEdges:
      when sizeof(E) <= sizeof(int32):
        result = lightId(edge)
        break
    result = edgeId(edge)

proc embirth(graph: Graph; obj: var Node) {.inline.} =
  ## Assign a unique identifier to a node.
  obj.id = nodeId(obj, graph)

proc embirth(graph: Graph; obj: var Edge) {.inline.} =
  ## Assign a unique identifier to a edge.
  obj.id = edgeId(obj, graph)

proc newNode[N, E; F: static[GraphFlags]](graph: var Graph[N, E, F]; value: N): Node[N, E] =
  ## Create a new node of the given `value`.
  result = Node[N, E](value: value)
  when not F.hasLightNodes:
    graph.init(result)
  embirth(graph, result)

proc len*[N, E; F: static[GraphFlags]](graph: Graph[N, E, F]): int {.example.} =
  ## Return the number of nodes in a `graph`.  O(1).
  runnableExamples:
    var g = newGraph[int, string]()
    assert len(g) == 0

  result = len(graph.members)

proc incl[N, E; F: static[GraphFlags]](graph: var Graph[N, E, F];
                                       edge: Edge[N, E]) {.example.} =
  ## Includes an `edge` in the `graph`.  Has no effect if the `edge` is
  ## already in the `graph`.  O(1).
  discard

proc incl*[N, E; F: static[GraphFlags]](graph: var Graph[N, E, F];
                                        node: Node[N, E]) {.example.} =
  ## Includes a `node` in the `graph`.  Has no effect if the `node` is
  ## already in the `graph`.  O(1).
  runnableExamples:
    var g = newGraph[int, string]()
    let n = g.add 3

    var q = newGraph[int, string]()
    q.incl n
    q.incl n
    assert len(q) == 1

  if node.id notin graph.members:
    append(graph.nodes, node)
    incl graph.members, node.id

proc add*[N, E; F: static[GraphFlags]](graph: var Graph[N, E, F];
                                       value: N): Node[N, E] {.example.} =
  ## Creates a new node of `value` and adds it to the `graph`.
  ## Returns the new node.  O(1).
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    assert len(g) == 1
    discard g.add 9
    assert len(g) == 2

  result = newNode(graph, value)
  graph.incl result

proc contains*[N, E; F: static[GraphFlags]](graph: Graph[N, E, F];
                                            value: N): bool {.example.} =
  ## Returns `true` if `graph` contains a node with the given `value`.
  ## Not yet O(1).
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    assert 3 in g

  for node in items(graph):
    if value == node.value:
      result = true
      break

proc `[]`*[N, E; F: static[GraphFlags]](graph: var Graph[N, E, F];
                                        key: N): var Node[N, E]
  {.example.} =
  ## Index a mutable `graph` to retrieve a mutable node of value `key`.
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    assert g[3].value == 3

  block found:
    for node in mitems(graph.nodes):
      if node.value == key:
        result = node
        break found
    raise newException(KeyError, "node not found: " & $key)

proc clear[N, E; F: static[GraphFlags]](graph: var GraphObj[N, E, F]) =
  ## Empty a `graph` of all nodes and edges.
  clear(graph.members)
  for item in nodes(graph.nodes):
    remove(DoublyLinkedList[Node[N, E]] graph.nodes, item)

proc clear*[N, E; F: static[GraphFlags]](graph: var Graph[N, E, F])
  {.example.} =
  ## Empty a `graph` of all nodes and edges.
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    clear(g)
    assert len(g) == 0

  clear(graph[])

proc `=destroy`[N, E; F: static[GraphFlags]](graph: var GraphObj[N, E, F]) =
  ## Prepare a `graph` for destruction.
  clear(graph)

proc newEdge[N, E;
             F: static[GraphFlags]](graph: var Graph[N, E, F];
                                    node: var Node[N, E]; value: E;
                                    target: var Node[N, E]): Edge[N, E] =
  ## Create a new edge between `source` and `target` of the given `value`.
  result = Edge[N, E](source: node, value: value, target: target)
  embirth(graph, result)

iterator outgoing*[N, E](node: var Node[N, E]):
  tuple[edge: var Edge[N, E], target: var Node[N, E]] =
  ## Yield mutable outgoing `edge` and target `target` from a mutable node.
  for edge in mitems(node.outgoing):
    yield (edge: edge, target: edge.target)

iterator outgoing*[N, E](node: Node[N, E]):
  tuple[edge: Edge[N, E], target: Node[N, E]] =
  ## Yield outgoing `edge` and target `target` from a node.
  for edge in items(node.outgoing):
    yield (edge: edge, target: edge.target)

iterator incoming*[N, E](node: var Node[N, E]):
  tuple[edge: var Edge[N, E], source: var Node[N, E]] =
  ## Yield mutable incoming `edge` and source `source` from a mutable node.
  for edge in mitems(node.incoming):
    yield (edge: edge, source: edge.source)

iterator incoming*[N, E](node: Node[N, E]):
  tuple[edge: Edge[N, E], source: Node[N, E]] =
  ## Yield incoming `edge` and source `source` from a node.
  for edge in items(node.incoming):
    yield (edge: edge, source: edge.source)

iterator neighbors*[N, E](node: Node[N, E]):
  tuple[edge: Edge[N, E], node: Node[N, E]] =
  ## Yield `edge` and target `node` from a node.
  for edge, via in outgoing(node):
    yield (edge: edge, node: via)
  for edge, via in incoming(node):
    yield (edge: edge, node: via)

proc del*[N, E; F: static[GraphFlags]](graph: var Graph[N, E, F];
                                       node: Node[N, E]) {.example.} =
  ## Remove a `node` from the `graph`; O(n).
  ## Has no effect if the `node` is not in the `graph`.
  ## Not O(1) yet.
  runnableExamples:
    var g = newGraph[int, string]()
    let n = g.add 3
    g.del n
    assert len(g) == 0

  if node.id in graph.members:
    remove(graph.nodes, node)
    excl graph.members, node.id

proc incl[N, E](node: var Node[N, E]; edge: Edge[N, E]) =
  ## Link `node` to `target` via `edge`; O(1).
  if edge.id notin node.edges:
    # ensure we only execute this once per node/edge
    incl node.edges, edge.id
    # if this is the source node,
    if edge.source.id == node.id:
      # it's an outgoing edge,
      append(node.outgoing, edge)
      # and we'll ensure it's in our peers
      incl node.peers, edge.target.id
    # if this is the target node,
    if edge.target.id == node.id:
      # it's an incoming edge,
      append(node.incoming, edge)
      # and we'll ensure it's in our peers
      incl node.peers, edge.source.id
    # connect the other end of the edge as well
    incl edge.target, edge

proc edge*[N, E; F: static[GraphFlags]](graph: var Graph[N, E, F];
                                        node: var Node[N, E]; value: E;
                                        target: var Node[N, E]): Edge[N, E]
  {.example.} =
  ## Link `node` to `target` via a new edge of `value`; O(1).
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    discard g.add 27
    let e = g.edge(g[3], "cubed", g[27])
    assert e.value == "cubed"
    assert g[3] in e
    assert g[27] in e

  result = newEdge(graph, node, value, target)
  graph.incl result
  node.incl result

proc `[]`*[N, E](node: var Node[N, E]; key: E): var Node[N, E] {.example.} =
  ## Index a `node` by edge `key`, returning the opposite (mutable) node.
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    discard g.add 9
    let squared = g.edge(g[3], "squared", g[9])
    let n9 = g[3]["squared"]
    assert n9.value == 9

  block found:
    for edge, target in outgoing(node):
      if edge.value == key:
        result = target
        break found
    raise newException(KeyError, "edge not found: " & $key)

proc peers*[N, E](node: Node[N, E]; target: Node[N, E]): bool {.example.} =
  ## Returns `true` if `node` shares an edge with `target`.
  runnableExamples:
    var g = newGraph[int, string]()
    var
      g3 = g.add 3
      g9 = g.add 9
    assert not peers(g9, g3)
    discard g.edge(g3, "squared", g9)
    assert peers(g3, g9)

  result = node.id in target.peers or target.id in node.peers

iterator items*[N, E; F: static[GraphFlags]](graph: Graph[N, E, F]): Node[N, E] {.example.} =
  ## Yield each node in the `graph`.
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    for node in items(g):
      assert node.value == 3

  for node in items(graph.nodes):
    yield node

iterator edges*[N, E; F: static[GraphFlags]](graph: Graph[N, E, F]):
  EdgeResult[N, E] {.example.} =
  ## Yield `source` node, `edge`, and `target` node from a `graph`.
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    discard g.add 9
    discard g.edge(g[3], "squared", g[9])
    for source, edge, target in edges(g):
      assert edge.value == "squared"
      assert source.value == 3
      assert target.value == 9

  var
    seen = initIntSet()

  for node in graph.items:
    for edge, target in outgoing(node):
      if edge.id notin seen:
        incl seen, edge.id
        yield (source: edge.source, edge: edge, target: target)
    for edge, source in incoming(node):
      if edge.id notin seen:
        incl seen, edge.id
        yield (source: source, edge: edge, target: edge.target)

proc contains*[N, E](edge: Edge[N, E]; value: N): bool {.example.} =
  ## Returns `true` if `edge` links to a node with the given `value`;
  ## else `false`.
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    discard g.add 9
    discard g.edge(g[3], "squared", g[9])
    let n = g[9]
    for source, edge, target in g.edges:
      assert 9 in edge
      assert 3 in edge

  result = edge.source.value == value or edge.target.value == value

proc contains*[N, E](edge: Edge[N, E]; node: Node[N, E]): bool {.example.} =
  ## Returns `true` if the `edge` links to `node`;
  ## else `false`.
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    discard g.add 9
    discard g.edge(g[3], "squared", g[9])
    for source, edge, target in g.edges:
      assert source in edge
      assert target in edge

  result = node.id in [edge.source.id, edge.target.id]

proc del*[N, E](node: var Node[N, E]; edge: Edge[N, E]) =
  ## Remove `edge` from `node`.  Of course, this also removes
  ## `edge` from the `target` node on the opposite side.
  ## Not O(1) yet; indeed, it is relatively slow!

  # leave this in a single proc so it's harder to screw up
  if node.initialized:
    if edge.id in node.edges:
      # remove the source side
      remove(edge.source.incoming, edge)
      remove(edge.source.outgoing, edge)
      excl(edge.source.edges, edge.id)
      excl(edge.source.peers, edge.target.id)
      # we can skip removing the target side if this is a "loop"
      if edge.target.id != edge.source.id:
        remove(edge.target.incoming, edge)
        remove(edge.target.outgoing, edge)
        excl(edge.target.edges, edge.id)
        excl(edge.target.peers, edge.source.id)

proc del*[N, E](node: var Node[N, E]; value: E) {.example.} =
  ## Remove edge with value `value` from `node`. Of course, this also
  ## removes the edge from the `target` node on the opposite side.
  ## Not O(1) yet; indeed, it is relatively slow!
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    discard g.add 9
    discard g.edge(g[3], "squared", g[9])
    var
      n9 = g[3]["squared"]
    n9.del "squared"
    assert not peers(g[3], n9)

  for edge in nodes(node.outgoing):
    if edge.value.value == value:
      node.del edge.value
  for edge in nodes(node.incoming):
    if edge.value.value == value:
      node.del edge.value

proc count[N, E](nodes: Nodes[N, E] | Edges[N, E]): int =
  ## Count the number of items in a container.
  for node in nodes.items:
    inc result

# exported for serialization purposes
proc len*[N, E](nodes: Nodes[N, E] | Edges[N, E]): int
  {.deprecated: "count() conveys the O(N) cost".} =
  ## Use count() instead; it expresses the O more clearly.
  result = count(nodes)

proc contains*[N, E](node: Node[N, E]; key: E): bool {.example.} =
  ## Returns `true` if an edge with value `key` links `node`.
  ## Not yet O(1).
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    discard g.add 9
    discard g.edge(g[3], "squared", g[9])
    assert "squared" in g[3]

  block found:
    for edge, peer in incoming(node):
      if edge.value == key:
        result = true
        break found

    for edge, peer in outgoing(node):
      if edge.value == key:
        result = true
        break found

proc `$`*[N, E](thing: Node[N, E] | Edge[N, E]): string =
  ## A best-effort convenience.
  when compiles($thing.value):
    result = $thing.value
  else:
    result = "thing needs a dollar"

proc `[]`*[N, E](node: Node[N, E]; key: E): Node[N, E] {.example.} =
  ## Index a `node` by edge `key`, returning the opposite node.
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    discard g.add 9
    discard g.edge(g[3], "squared", g[9])
    let
      l3 = g[3]
      l9 = g[3]["squared"]
    assert l9.value == 9

  block found:
    for edge in node.incoming.items:
      if edge.value == key:
        result = edge.target
        break found
    for edge in node.outgoing.items:
      if edge.value == key:
        result = edge.target
        break found
    raise newException(KeyError, "edge not found: " & $key)

when false:
  proc `->`*[N, E](node: Node[N, E]; target: Node[N, E]): bool =
    runnableExamples:
      var g = newGraph[int, string]()
      discard g.add 3
      discard g.add 9
      discard g.edge(g[3], "squared", g[9])
      assert g[3] -> g[9]

    if target.id in node.peers:
      for edge in items(node.outgoing):
        if target in edge:
          result = true
          break

when isMainModule:
  import std/os

  import criterion

  const
    dgf = toInt(defaultGraphFlags)
  echo "graph object size ", sizeof(GraphObj[int, string, dgf])
  echo "node object size ", sizeof(NodeObj[int, string])
  echo "edge object size ", sizeof(EdgeObj[int, string])

  when not defined(danger):
    echo "build with -d:danger to run benchmarks"
  else:
    var cfg = newDefaultConfig()
    cfg.brief = true
    cfg.budget = 1.0

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
