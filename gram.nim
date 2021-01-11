import std/strutils
import std/monotimes
import std/intsets
import std/macros
import std/hashes
import std/sets
import std/options

##
## Goals
##
## - Sacrifice a little RAM for O(1) operations.
## - Sacrifice a little CPU for less memory churn.
## - Aggressively remove API that proves useless or confusing.
## - Aggressively abstract and hide complexity from the user.
## - Perfect is the enemy of Good.
##

import skiplists
export skiplists.cmp

import grok

import hasts/graphviz_ast
export toDotNodeId

type
  Container[T] = SkipList[T]
  GraphFlag* {.size: sizeof(int).} = enum
    QueryResult  = "the graph only makes sense in relation to another graph"
    UniqueNodes  = "the nodes in the graph all have unique values"
    UniqueEdges  = "the edges in the graph all have unique values"
    Directed     = "edges have different semantics for source and target"
    Undirected   = "edges have identical semantics for source and target"
    SelfLoops    = "nodes may have edges that target themselves"
    Ultralight   = "the graph is even lighter"
    ValueIndex   = "node and edge values are indexed for speed"

  EdgeFlag {.size: sizeof(int).} = enum
    Incoming
    Outgoing

  GraphObj[N, E; F: static[int]] = object
    nodes: Container[Node[N, E]]
    members: IntSet
    hashes: HashSet[N]

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
    incoming: Container[Edge[N, E]]
    outgoing: Container[Edge[N, E]]
    edges: IntSet
    peers: IntSet
    initialized: bool

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

  GraphFlags* = int

  EdgeResult*[N, E] = tuple
    source: Node[N, E]
    edge: Edge[N, E]
    target: Node[N, E]

converter toInt*(flags: set[GraphFlag]): GraphFlags =
  # the vm cannot cast between set and int
  when nimvm:
    for flag in items(flags):
      result = `or`(result, 1 shl flag.ord)
  else:
    result = cast[int](flags)

converter toFlags*(value: GraphFlags): set[GraphFlag] =
  # the vm cannot cast between set and int
  when nimvm:
    for flag in items(GraphFlag):
      if `and`(value, 1 shl flag.ord) != 0:
        result.incl flag
  else:
    result = cast[set[GraphFlag]](value)

template flags*[N, E, F](graph: Graph[N, E, F]): set[GraphFlag] =
  F.toFlags

const
  defaultGraphFlags* = {Directed, SelfLoops, ValueIndex}

type
  ValueIndexGraph* = concept g
    contains(g.flags, ValueIndex) == true

  NoValueIndexGraph* = concept g
    contains(g.flags, ValueIndex) == false

when false:
  type
    LightNodesGraph = concept g
      {UniqueNodes, UltraLight} <= g.flags == true

    HeavyNodesGraph = concept g
      {UniqueNodes, UltraLight} <= g.flags == false

template graph[N, E, F](g: Graph[N, E, F]): Graph[N, E, F] = g
template node[N, E](n: Node[N, E]): Node[N, E] = n
template edge[N, E](e: Edge[N, E]): Edge[N, E] = e

proc newContainer*[N, E, F](graph: Graph[N, E, F]; form: typedesc): auto =
  ## Create a new container for nodes or edges.
  result = toSkipList[form]([])

proc append[T](list: var Container[T]; value: T) = list.add value

proc len*[T](list: Container[T]): int
  {.deprecated: "count() conveys the O(n) cost".} =
  ## Use count() instead; it expresses the O more clearly.
  result = count(list)

proc init*(graph: var ValueIndexGraph) =
  assert graph != nil
  graph.members = initIntSet()
  graph.hashes.init

proc init*(graph: var NoValueIndexGraph) =
  assert graph != nil
  graph.members = initIntSet()

template newGraph*[N, E](wanted: GraphFlags): auto =
  ## Create a new graph; nodes will hold `N` while edges will hold `E`.
  runnableExamples:
    var g = newGraph[int, string]()
    assert g != nil

  block:
    var
      result = Graph[N, E, wanted]()
    result.nodes = result.newContainer(Node[N, E])
    init result
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

proc init[N, E, F](graph: Graph[N, E, F]; node: var Node[N, E]) =
  ## Initialize a `node` for use in the `graph`.
  assert node != nil
  if not node.initialized:
    when Directed in graph.flags:
      node.incoming = graph.newContainer(Edge[N, E])
    node.outgoing = graph.newContainer(Edge[N, E])
    node.edges = initIntSet()
    node.peers = initIntSet()
    node.initialized = true

proc nodeId(node: Node): int {.inline.} =
  result = getMonoTime().ticks.int

proc hasLightNodes(flags: static[GraphFlags]): bool {.compileTime.} =
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

proc len*[N, E; F: static[GraphFlags]](graph: Graph[N, E, F]): int {.ex.} =
  ## Return the number of nodes in a `graph`.  O(1).
  runnableExamples:
    var g = newGraph[int, string]()
    assert len(g) == 0

  result = len(graph.members)
  assert count(graph.nodes) == result

proc incl[N, E; F: static[GraphFlags]](graph: var Graph[N, E, F];
                                       edge: Edge[N, E]) {.ex.} =
  ## Includes an `edge` in the `graph`.  Has no effect if the `edge` is
  ## already in the `graph`.  O(1).
  assert graph != nil
  assert edge != nil

proc incl*[N, E; F: static[GraphFlags]](graph: var Graph[N, E, F];
                                        node: Node[N, E]) {.ex.} =
  ## Includes a `node` in the `graph`.  Has no effect if the `node` is
  ## already in the `graph`.  O(1).
  runnableExamples:
    var g = newGraph[int, string]()
    let n = g.add 3

    var q = newGraph[int, string]()
    q.incl n
    q.incl n
    assert len(q) == 1

  assert graph != nil
  if node.id notin graph.members:
    append(graph.nodes, node)
    incl graph.members, node.id
    # cache the value hash
    incl graph.hashes, node.value

proc add*[N, E; F: static[GraphFlags]](graph: var Graph[N, E, F];
                                       value: N): Node[N, E] {.ex.} =
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
                                            node: Node[N, E]): bool {.ex.} =
  ## Returns `true` if `graph` contains `node`.
  ## O(1).
  runnableExamples:
    var g = newGraph[int, string]()
    let n = g.add 3
    assert n in g

  result = node.id in graph.members

proc contains*[N, E; F: static[GraphFlags]](graph: Graph[N, E, F];
                                            value: N): bool {.ex.} =
  ## Returns `true` if `graph` contains a node with the given `value`.
  ## O(1) for `ValueIndex` graphs, else O(n).
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    assert 3 in g

  when ValueIndex in graph.flags:
    result = value in graph.hashes
  else:
    for item in items(graph):
      if value == item:
        result = true
        break

template getNodeImpl(graph, key, iterItems: untyped): untyped =
  block found:
    block search:
      # optimization using ValueIndex
      when ValueIndex in graph.flags:
        # if it's not in the index, don't retrieve it
        if key notin graph:
          break search

      # find it and return it
      for node in iterItems(graph.nodes):
        if node.value == key:
          result = node
          break found

    raise newException(KeyError, "node not found: " & $key)


proc `[]`*[N, E; F: static[GraphFlags]](
  graph: Graph[N, E, F]; key: N): Node[N, E] =
  ## Index an immutable `graph` to retrieve a immutable node of value `key`.
  getNodeImpl graph, key, items

proc `[]`*[N, E; F: static[GraphFlags]](graph: var Graph[N, E, F];
                                        key: N): var Node[N, E] {.ex.} =
  ## Index a mutable `graph` to retrieve a mutable node of value `key`.
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    assert g[3].value == 3

  getNodeImpl graph, key, mitems

proc clear[N, E; F: static[GraphFlags]](graph: var GraphObj[N, E, F]) =
  ## Empty a `graph` of all nodes and edges.
  clear(graph.members)
  clear(graph.nodes)

proc clear*[N, E; F: static[GraphFlags]](graph: var Graph[N, E, F])
  {.ex.} =
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
  assert graph != nil
  assert node != nil
  assert target != nil
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
                                       node: Node[N, E]) {.ex.} =
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
    when ValueIndex in graph.flags:
      # uncache the value hash
      excl graph.hashes, node.value

proc incl[N, E](node: var Node[N, E]; edge: Edge[N, E]) =
  ## Link `node` to `target` via `edge`; O(1).
  assert node != nil
  assert edge != nil
  assert edge.target != nil
  assert edge.source != nil
  assert node.initialized
  if edge.id notin node.edges:
    # ensure we only execute this once per node/edge
    incl node.edges, edge.id
    # if this is the source node,
    if edge.source.id == node.id:
      # it's an outgoing edge,
      append(node.outgoing, edge)
      # and we'll ensure it's in our peers
      incl node.peers, edge.target.id
    # if we are the target node,
    if edge.target.id == node.id:
      # it's an incoming edge,
      {.warning: "need to handle Undirected graphs properly".}
      append(node.incoming, edge)
      # and we'll ensure it's in our peers
      incl node.peers, edge.source.id
    # connect the other end of the edge as well
    incl edge.target, edge

proc node*[N, E; F: static[GraphFlags]](graph: var Graph[N, E, F];
                                        value: N): Node[N, E]
  {.ex.} =
  ## Create a new node compatible with `graph`; O(1).
  runnableExamples:
    var g = newGraph[int, string]()
    var n = g.node(3)
    assert len(g) == 0
    g.incl n
    assert len(g) == 1

  result = newNode(graph, value)

proc edge*[N, E; F: static[GraphFlags]](graph: var Graph[N, E, F];
                                        node: var Node[N, E]; value: E;
                                        target: var Node[N, E]): Edge[N, E]
  {.ex.} =
  ## Link `node` to `target` via a new edge of `value`; O(1).
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    discard g.add 27
    let e = g.edge(g[3], "cubed", g[27])
    assert e.value == "cubed"
    assert g[3] in e
    assert g[27] in e

  assert node != nil
  assert target != nil

  # ensure the node and target are prepared to add an edge
  graph.init node
  graph.init target

  # create the edge
  result = newEdge(graph, node, value, target)

  # include the edge in the graph
  graph.incl result

  # include the edge in the node and target
  node.incl result
  target.incl result


proc edge*[N, E; F: static[GraphFlags]](
  graph: var Graph[N, E, F];
  node: Node[N, E]; value: E;
  target: Node[N, E]): Edge[N, E] =
  ## Add new edge into graph using immutable source and target nodes.

  var node = node
  var target = target
  edge(graph, node, value, target)

proc contains*[N, E; F: static[GraphFlags]](graph: Graph[N, E, F];
                                            edge: Edge[N, E]): bool {.ex.} =
  ## Returns `true` if `graph` contains `edge`.
  ## O(1).
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    discard g.add 27
    let e = g.edge(g[3], "cubed", g[27])
    assert e in g

  result = edge.source in graph or edge.target in graph

proc `[]`*[N, E](node: var Node[N, E]; key: E): var Node[N, E] {.ex.} =
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

proc peers*[N, E](node: Node[N, E]; target: Node[N, E]): bool {.ex.} =
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

iterator nodes*[N, E; F: static[GraphFlags]](graph: Graph[N, E, F]): Node[N, E] {.ex.} =
  ## Yield each node in the `graph`.
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    for node in nodes(g):
      assert node.value == 3

  for node in items(graph.nodes):
    yield node

iterator items*[N, E; F: static[GraphFlags]](graph: Graph[N, E, F]): N {.ex.} =
  ## Yield the values of nodes in the `graph`.
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    for value in items(g):
      assert value == 3

  for node in nodes(graph):
    yield node.value

iterator edges*[N, E; F: static[GraphFlags]](graph: Graph[N, E, F]):
  EdgeResult[N, E] {.ex.} =
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

  for node in nodes(graph):
    for edge, target in outgoing(node):
      if edge.id notin seen:
        incl seen, edge.id
        yield (source: edge.source, edge: edge, target: target)
    for edge, source in incoming(node):
      if edge.id notin seen:
        incl seen, edge.id
        yield (source: source, edge: edge, target: edge.target)

proc contains*[N, E](edge: Edge[N, E]; value: N): bool {.ex.} =
  ## Returns `true` if `edge` links to a node with the given `value`;
  ## else `false`.
  ## O(1).
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

proc contains*[N, E](edge: Edge[N, E]; node: Node[N, E]): bool {.ex.} =
  ## Returns `true` if the `edge` links to `node`;
  ## else `false`.
  ## O(1).
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
  ## O(log n).

  # leave this in a single proc so it's harder to screw up
  if node.initialized:
    if edge.id in node.edges:
      # remove the source side
      {.warning: "need to handle Undirected graphs properly".}
      remove(edge.source.incoming, edge)
      remove(edge.source.outgoing, edge)
      excl(edge.source.edges, edge.id)
      excl(edge.source.peers, edge.target.id)
      # we can skip removing the target side if this is a "loop"
      if edge.target.id != edge.source.id:
        {.warning: "need to handle Undirected graphs properly".}
        remove(edge.target.incoming, edge)
        remove(edge.target.outgoing, edge)
        excl(edge.target.edges, edge.id)
        excl(edge.target.peers, edge.source.id)

proc contains*[N, E](node: Node[N, E]; edge: Edge[N, E]): bool {.ex.} =
  ## Returns `true` if Node `node` has Edge `edge`.
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    discard g.add 9
    let e = g.edge(g[3], "squared", g[9])
    assert e in g[3]

  result = edge.id in node.edges

proc del*[N, E](node: var Node[N, E]; value: E) {.ex.} =
  ## Remove edge with value `value` from `node`. Of course, this also
  ## removes the edge from the `target` node on the opposite side.
  ## O(log n)
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    discard g.add 9
    discard g.edge(g[3], "squared", g[9])
    var n9 = g[3]["squared"]
    n9.del "squared"
    assert not peers(g[3], n9)

  func thisOne(a: SkipList[Edge[N, E]]): skiplists.cmp =
    if a.isNil:
      Undefined
    elif a.value.value == value:
      Equal
    elif a.value.value < value:
      Less
    else:
      More

  var victim: Container[Edge[N, E]]
  if find(node.outgoing, victim, compare = thisOne):
    node.del victim.value
  if find(node.incoming, victim, compare = thisOne):
    node.del victim.value

proc contains*[N, E](node: Node[N, E]; key: E): bool {.ex.} =
  ## Returns `true` if an edge with value `key` links `node`.
  ## O(log n).
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    discard g.add 9
    discard g.edge(g[3], "squared", g[9])
    assert "squared" in g[3]

  func thisOne(a: SkipList[Edge[N, E]]): skiplists.cmp =
    if a.isNil:
      Undefined
    elif a.value.value == key:
      Equal
    elif a.value.value < key:
      Less
    else:
      More

  var victim: Container[Edge[N, E]]
  result = result or find(node.outgoing, victim, thisOne)
  result = result or find(node.incoming, victim, thisOne)

proc `$`*[N, E](thing: Node[N, E] | Edge[N, E]): string =
  ## A best-effort convenience.
  when compiles($thing.value):
    result = $thing.value
  else:
    result = "$" & $typeof(thing)

proc `[]`*[N, E](node: Node[N, E]; key: E): Node[N, E] {.ex.} =
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
    for edge in items(node.incoming):
      if edge.value == key:
        result = edge.target
        break found
    for edge in items(node.outgoing):
      if edge.value == key:
        result = edge.target
        break found
    raise newException(KeyError, "edge not found: " & $key)

proc hash(intset: IntSet): Hash =
  ## Produce a `Hash` for an IntSet.
  var h: Hash = 0
  for value in items(intset):
    h = h !& hash(value)
  result = !$h

proc hash*[N, E](node: Node[N, E]): Hash =
  ## Produce a `Hash` that uniquely identifies the `node` and varies with
  ## changes to its neighborhood.
  var h: Hash = 0
  h = h !& hash(node.id)
  h = h !& hash(node.edges)
  h = h !& hash(node.peers)
  result = !$h

proc hash*[N, E](edge: Edge[N, E]): Hash =
  ## Produce a `Hash` that uniquely identifies the `edge`.
  var h: Hash = 0
  h = h !& hash(edge.id)
  result = !$h

proc hash*[N, E, F](graph: Graph[N, E, F]): Hash =
  ## Produce a `Hash` that uniquely identifies the `graph` based upon its
  ## contents.
  var h: Hash = 0
  for node in nodes(graph):
    h = h !& hash(node)
  for edge in edges(graph):
    h = h !& hash(edge)
  result = !$h

when false:
  proc `->`*[N, E](node: Node[N, E]; target: Node[N, E]): bool {.ex.} =
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

proc nodeSet[N, E, F](graph: Graph[N, E, F]): HashSet[N] =
  result = initHashSet[N](initializeSize = len(graph))
  for node in nodes(graph):
    result.incl node.value

proc nodesAreUnique*[N, E, F](graph: Graph[N, E, F]): bool {.ex.} =
  ## Returns `true` if there are no nodes in the graph with
  ## duplicate values.
  ## O(1) for `ValueIndex` graphs, else O(n).
  runnableExamples:
    var g = newGraph[int, string]()
    discard g.add 3
    discard g.add 9
    assert g.nodesAreUnique
    discard g.add 3
    assert not g.nodesAreUnique

  when ValueIndex in graph.flags:
    result = len(graph.members) == len(graph.hashes)
  else:
    var seen =
      when (NimMajor, NimMinor) >= (1, 4):
        initHashSet[N](initialSize = len(graph))
      else:
        initHashSet[N](initialSize = len(graph).rightSize)
    block found:
      for value in items(graph):
        if value in seen:
          result = false
          break found
        else:
          seen.incl value
      result = true

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

proc toPng*[N, E, F](graph: DotGraph, outfile: string) =
  ## Save `graph` to file and convert it to image.
  graph.toPng(outfile)
