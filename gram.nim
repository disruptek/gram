import std/monotimes
import std/lists
import std/intsets

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
  Graph*[N, E] = ref GraphObj[N, E]    ## A collection of nodes and edges.
  ##
  ## Nodes have a user-supplied `.value` of type `N`.
  ## Edges have a user-supplied `.value` of type `E`.
  GraphObj[N, E] = object
    nodes: Nodes[N, E]
    members: IntSet

  Node*[N, E] = ref NodeObj[N, E]      ## A node in the graph.
  ##
  ## Nodes have a user-supplied `.value` of type `N`.
  ## Edges have a user-supplied `.value` of type `E`.
  NodeObj[N, E] = object
    value*: N                        # 8
    id: int                          # 8
    birth: MonoTime                  # 8
    incoming: Edges[N, E]            # 8
    outgoing: Edges[N, E]            # 8
    edges: IntSet
    peers: IntSet
  Nodes[N, E] = DoublyLinkedList[Node[N, E]]

  Edge*[N, E] = ref EdgeObj[N, E]      ## An edge connects two nodes.
  ##
  ## Nodes have a user-supplied `.value` of type `N`.
  ## Edges have a user-supplied `.value` of type `E`.
  EdgeObj[N, E] = object
    value*: E
    id: int
    birth: MonoTime
    source: Node[N, E]
    target: Node[N, E]
  Edges[N, E] = DoublyLinkedList[Edge[N, E]]

proc newNodes[N, E](): Nodes[N, E] =
  ## Create a new container for nodes.
  result = initDoublyLinkedList[Node[N, E]]()

proc newEdges[N, E](): Edges[N, E] =
  ## Create a new container for edges.
  result = initDoublyLinkedList[Edge[N, E]]()

proc newGraph*[N, E](): Graph[N, E] =
  ## Create a new graph; nodes will hold `N` while edges will hold `E`.
  runnableExamples:
    type
      MyNode = int
      MyEdge = string
    var g = newGraph[MyNode, MyEdge]()

  result = Graph[N, E]()
  result.nodes = newNodes[N, E]()
  result.members = initIntSet()

proc `=destroy`[N, E](node: var NodeObj[N, E]) =
  ## Prepare a node for destruction.
  clear(node.edges)
  clear(node.peers)
  for item in nodes(node.incoming):
    remove(node.incoming, item)
  for item in nodes(node.outgoing):
    remove(node.outgoing, item)
  # just, really fuck this thing up
  node.id = 0

proc `=destroy`[N, E](edge: var EdgeObj[N, E]) =
  ## Prepare an `edge` for destruction.
  edge.source = nil
  edge.target = nil
  # just, really fuck this thing up
  edge.id = 0

proc embirth[N, E](obj: var Node[N, E] | var Edge[N, E]) =
  ## Assign a birthday (and a unique identifier) to a node or edge.
  obj.birth = getMonoTime()
  obj.id = ticks(obj.birth).int
  when obj is Edge:
    # edges have negative ids
    obj.id = -obj.id

proc newNode[N, E](value: N): Node[N, E] =
  ## Create a new node of the given `value`.
  result = Node[N, E](value: value,
                      incoming: newEdges[N, E](),
                      outgoing: newEdges[N, E]())
  result.edges = initIntSet()
  result.peers = initIntSet()
  embirth(result)

proc len*[N, E](graph: Graph[N, E]): int =
  ## Return the number of nodes in a `graph`.
  runnableExamples:
    var g = newGraph[int, string]()
    assert len(g) == 0

  result = len(graph.members)

proc add*[N, E](graph: var Graph[N, E]; value: N) =
  ## Creates a new node of `value` and adds it to the `graph`.
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    assert len(g) == 1
    g.add 9
    assert len(g) == 2

  var
    node = newNode[N, E](value)
  graph.add node

proc `[]`*[N, E](graph: var Graph[N, E]; key: N): var Node[N, E] =
  ## Index a `graph` to retrieve a node of value `key`.
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    assert g[3].value == 3

  block found:
    for node in graph.nodes.mitems:
      if node.value == key:
        result = node
        break found
    raise newException(KeyError, "node not found: " & $key)

proc clear[N, E](graph: var GraphObj[N, E]) =
  ## Empty a `graph` of all nodes and edges.
  clear(graph.members)
  for item in nodes(graph.nodes):
    remove(graph.nodes, item)

proc clear*[N, E](graph: var Graph[N, E]) =
  ## Empty a `graph` of all nodes and edges.
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    clear(g)
    assert len(g) == 0

  clear(graph[])

proc `=destroy`[N, E](graph: var GraphObj[N, E]) =
  ## Prepare a `graph` for destruction.
  clear(graph)

proc newEdge[N, E](source: Node[N, E]; value: E;
                   target: Node[N, E]): Edge[N, E] =
  ## Create a new edge between `source` and `target` of the given `value`.
  result = Edge[N, E](source: source, value: value, target: target)
  embirth(result)

proc add*[N, E](graph: var Graph[N, E]; node: Node[N, E]) =
  ## Adds a `node` to the `graph`.  Has no effect if the `node` is already
  ## in the `graph`.
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    let n = g[3]

    var q = newGraph[int, string]()
    q.add n
    q.add n
    assert len(q) == 1

  if node.id notin graph.members:
    append(graph.nodes, newDoublyLinkedNode(node))
    incl graph.members, node.id

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
  for edge, node in node.outgoing:
    yield (edge: edge, node: node)
  for edge, node in node.incoming:
    yield (edge: edge, node: node)

proc del*[N, E](graph: var Graph[N, E]; node: Node[N, E]) =
  ## Remove a `node` from the `graph`.
  ## Has no effect if the `node` is not in the `graph`.
  ## Not O(1) yet.
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    let n = g[3]
    g.del n
    assert len(g) == 0

  if node.id in graph.members:
    for item in nodes(graph.nodes):
      if item.value.id == node.id:
        remove(graph.nodes, item)
        excl graph.members, item.value.id
        break

proc append[N, E](nodes: var Nodes[N, E]; value: N) =
  ## Append a new node of `value` to the `nodes` container.
  var
    node = newNode[N, E](value)
  nodes.append newDoublyLinkedNode(node)

proc add[N, E](node: var Node[N, E]; edge: Edge[N, E]; target: var Node[N, E]) =
  ## Link `node` to `target` via `edge`; O(1).
  if edge.id notin node.edges:
    append(node.outgoing, newDoublyLinkedNode(edge))
    incl node.peers, target.id
    incl node.edges, edge.id
    append(target.incoming, newDoublyLinkedNode(edge))
    incl target.peers, node.id
    incl target.edges, edge.id

proc add*[N, E](node: var Node[N, E]; value: E; target: var Node[N, E]) =
  ## Link `node` to `target` via a new edge of `value`; O(1).
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    g.add 9
    g[3].add "squared", g[9]

  var
    edge = newEdge[N, E](node, value, target)
  node.add edge, target

# XXX: needs a better name
proc isPeerOf*[N, E](node: Node[N, E]; target: Node[N, E]): bool =
  ## Returns `true` if `node` shares an edge with `target`.
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    g.add 9
    g[3].add "squared", g[9]
    assert g[3].isPeerOf g[9]
    assert g[9].isPeerOf g[3]
  result = node.id in target.peers or target.id in node.peers

iterator items*[N, E](graph: Graph[N, E]): Node[N, E] =
  ## Yield each node in the `graph`.
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    for node in items(g):
      assert node.value == 3

  for node in lists.items(graph.nodes):
    yield node

proc contains*[N, E](graph: Graph[N, E]; value: N): bool =
  ## Returns `true` if `graph` contains a node with the given `value`.
  ## Not yet O(1).
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    assert 3 in g

  for node in items(graph):
    if value == node.value:
      result = true
      break

proc contains[N, E](nodes: Nodes[N, E]; value: N): bool
  {.deprecated: "not O(1) yet".} =
  ## Returns `true` if `nodes` contains a node with the given `value`.
  # XXX: reimpl using find()
  for node in nodes.items:
    if value == node.value:
      result = true
      break

proc add*[N, E](node: var Node[N, E]; edge: E; value: N) =
  ## Add the `edge` between `node` and a new node of `value`.
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    g[3].add "squared", 9
    assert len(g) == 1

  var
    target = newNode[N, E](value)
  node.add edge, target

iterator edges*[N, E](graph: Graph[N, E]):
  tuple[source: Node[N, E], edge: Edge[N, E], target: Node[N, E]] =
  ## Yield `source` node, `edge`, and `target` node from a `graph`.
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    g[3].add "squared", 9
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

proc contains*[N, E](edge: Edge[N, E]; value: N): bool =
  ## Returns `true` if `edge` links to a node with the given `value`;
  ## else `false`.
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    g.add 9
    g[3].add "squared", g[9]
    let n = g[9]
    for source, edge, target in g.edges:
      assert 9 in edge
      assert 3 in edge

  result = edge.source.value == value or edge.target.value == value

proc contains*[N, E](edge: Edge[N, E]; node: Node[N, E]): bool =
  ## Returns `true` if the `edge` links to `node`;
  ## else `false`.
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    g.add 9
    g[3].add "squared", g[9]
    let n = g[9]
    for source, edge, target in g.edges:
      assert n in edge

  result = node.id in [edge.source.id, edge.target.id]

proc remove[N, E](edges: var Edges[N, E]; edge: Edge[N, E]) =
  ## Remove an edge from container.
  for item in nodes(edges):
    if item.value.id == edge.id:
      remove(edges, item)

proc del*[N, E](node: var Node[N, E]; edge: Edge[N, E]) =
  ## Remove `edge` from `node`.  Of course, this also removes
  ## `edge` from the `target` node on the opposite side.
  ## Not O(1) yet; indeed, it is relatively slow!

  # leave this in a single proc so it's harder to screw up
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

proc del*[N, E](node: var Node[N, E]; value: E) =
  ## Remove edge with value `value` from `node`. Of course, this also
  ## removes the edge from the `target` node on the opposite side.
  ## Not O(1) yet; indeed, it is relatively slow!
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    g[3].add "squared", 9
    var
      n9 = g[3]["squared"]
    n9.del "squared"
    assert not g[3].isPeerOf n9

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

proc hasKey*[N, E](node: Node[N, E]; key: E): bool =
  ## Returns `true` if an edge with value `key` links `node`.
  ## Not yet O(1).
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    g[3].add "squared", 9
    assert g[3].hasKey "squared"

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

proc `[]`*[N, E](node: Node[N, E]; key: E): Node[N, E] =
  ## Index a `node` by edge `key`, returning the opposite node.
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    g[3].add "squared", 9
    let
      n9 = g[3]["squared"]
    assert n9.value == 9

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

proc `[]`*[N, E](node: var Node[N, E]; key: E): var Node[N, E] =
  ## Index a `node` by edge `key`, returning the opposite (mutable) node.
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    g[3].add "squared", 9
    let
      n9 = g[3]["squared"]
    assert n9.value == 9

  block found:
    for edge, target in outgoing(node):
      if edge.value == key:
        result = target
        break found
    raise newException(KeyError, "edge not found: " & $key)

proc hasKey*[N, E](graph: Graph[N, E]; key: N): bool
  {.deprecated: "not O(1) yet".} =
  ## Returns `true` if a node with value `key` exists in the `graph`.
  runnableExamples:
    var g = newGraph[int, string]()
    g.add 3
    assert 3 in g
  result = key in graph

when false:
  #[

  needs to be destructive

  ]#
  proc `[]=`*[N, E](node: var Node[N, E]; key: E; value: N) =
    ## add the given edge from the node to a new node with the given value
    block found:
      for edge in node.edges.mitems:
        if edge.value == key:
          edge.target = newNode[N, E](value)
          break found
      node.add key, value

when isMainModule:
  echo "graph object size ", sizeof(GraphObj[int, string])
  echo "node object size ", sizeof(NodeObj[int, string])
  echo "edge object size ", sizeof(EdgeObj[int, string])
