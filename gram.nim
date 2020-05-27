import std/monotimes
import std/lists
import std/intsets

type
  Graph*[N, E] = ref GraphObj[N, E]
  GraphObj[N, E] = object
    nodes: Nodes[N, E]
    members: IntSet

  Node*[N, E] = ref NodeObj[N, E]
  NodeObj[N, E] = object
    value*: N
    id: int
    birth: MonoTime
    incoming: Edges[N, E]
    outgoing: Edges[N, E]
    edges: IntSet
    peers: IntSet
  Nodes[N, E] = DoublyLinkedList[Node[N, E]]

  Edge*[N, E] = ref EdgeObj[N, E]
  EdgeObj[N, E] = object
    value*: E
    id: int
    birth: MonoTime
    source: Node[N, E]
    target: Node[N, E]
  Edges[N, E] = DoublyLinkedList[Edge[N, E]]

proc `=destroy`[N, E](node: var NodeObj[N, E]) =
  clear(node.edges)
  clear(node.peers)
  for item in nodes(node.incoming):
    remove(node.incoming, item)
  for item in nodes(node.outgoing):
    remove(node.outgoing, item)
  # just, really fuck this thing up
  node.id = 0

proc `=destroy`[N, E](edge: var EdgeObj[N, E]) =
  edge.source = nil
  edge.target = nil
  # just, really fuck this thing up
  edge.id = 0

proc clear[N, E](graph: var GraphObj[N, E]) =
  clear(graph.members)
  for item in nodes(graph.nodes):
    remove(graph.nodes, item)

proc clear*[N, E](graph: var Graph[N, E]) =
  clear(graph[])

proc `=destroy`[N, E](graph: var GraphObj[N, E]) =
  clear(graph)

proc newNodes*[N, E](): Nodes[N, E] =
  ## create a new container holding nodes
  result = initDoublyLinkedList[Node[N, E]]()

proc newEdges[N, E](): Edges[N, E] =
  ## create a new container holding edges; not public
  result = initDoublyLinkedList[Edge[N, E]]()

proc newGraph*[N, E](): Graph[N, E] =
  result = Graph[N, E]()
  result.nodes = newNodes[N, E]()
  result.members = initIntSet()

proc embirth[N, E](obj: var Node[N, E] | var Edge[N, E]) =
  obj.birth = getMonoTime()
  obj.id = ticks(obj.birth).int

proc newEdge[N, E](source: Node[N, E]; value: E;
                   target: Node[N, E]): Edge[N, E] =
  ## create a new edge of the given value
  result = Edge[N, E](source: source, value: value, target: target)
  embirth(result)

proc newNode[N, E](value: N): Node[N, E] =
  ## create a new node of the given value
  result = Node[N, E](value: value,
                      incoming: newEdges[N, E](),
                      outgoing: newEdges[N, E]())
  result.edges = initIntSet()
  result.peers = initIntSet()
  embirth(result)

proc del*[N, E](graph: var Graph[N, E]; node: Node[N, E]) =
  ## remove a node from the graph
  if node.id in graph.members:
    for item in nodes(graph.nodes):
      if item.id == node.id:
        remove(graph.nodes, item)
        excl graph.members, item.id
        break

proc add*[N, E](graph: var Graph[N, E]; node: Node[N, E]) =
  if node.id notin graph.members:
    append(graph.nodes, newDoublyLinkedNode(node))
    incl graph.members, node.id

proc add*[N, E](graph: var Graph[N, E]; value: N) =
  ## append a new node of the given value to the graph
  var
    node = newNode[N, E](value)
  graph.add node

proc append[N, E](nodes: var Nodes[N, E]; value: N) =
  ## append a new node of the given value to the container
  var
    node = newNode[N, E](value)
  nodes.append newDoublyLinkedNode(node)

proc contains*[N, E](nodes: Nodes[N, E]; value: N): bool
  {.deprecated: "not O(1)".} =
  ## true if the container holds a node with the given value
  for node in nodes.items:
    if value == node.value:
      result = true
      break

proc contains*[N, E](edge: Edge[N, E]; value: N): bool =
  ## true if the edge links a node with the given value
  result = edge.source.value == value or edge.target.value == value

proc contains*[N, E](edge: Edge[N, E]; target: Node[N, E]): bool =
  ## true if the edge links the given node
  result = target.id in {edge.source.id, edge.target.id}

proc remove[N, E](edges: var Edges[N, E]; edge: Edge[N, E]) =
  ## not O(1) yet
  for item in nodes(edges):
    if item.id == edge.id:
      remove(edges, item)

proc del*[N, E](node: var Node[N, E]; edge: Edge[N, E]) =
  ## not O(1) yet
  if edge.id in node.edges:
    remove(node.incoming, edge)
    remove(node.outgoing, edge)
    excl node.edges, edge.id

proc add*[N, E](node: var Node[N, E]; edge: Edge[N, E]; target: Node[N, E]) =
  ## O(1)
  if edge.id notin node.edges:
    append(node.outgoing, newDoublyLinkedNode(edge))
    incl node.peers, target.id
    incl node.edges, edge.id
    append(target.incoming, newDoublyLinkedNode(edge))
    incl target.peers, node.id
    incl target.edges, edge.id

proc add*[N, E](node: var Node[N, E]; value: E; target: Node[N, E]) =
  ## connect `node` to `target` using the given `edge`
  var
    edge = newEdge[N, E](node, value, target)
  node.add edge, target

proc add*[N, E](node: var Node[N, E]; edge: E; value: N) =
  ## add the given edge from the node to a new node with the given value
  var
    target = newNode[N, E](value)
  node.add edge, target

proc count[N, E](nodes: Nodes[N, E] | Edges[N, E]): int =
  ## count the number of items in a container
  for node in nodes.items:
    inc result

# exported for serialization purposes
proc len*[N, E](nodes: Nodes[N, E] | Edges[N, E]): int
  {.deprecated: "count() conveys the O(N) cost".} =
  ## use count() instead; it expresses the order more clearly
  result = count(nodes)

proc len*[N, E](graph: Graph[N, E]): int =
  ## return the number of nodes in a graph
  result = len(graph.members)

proc hasKey*[N, E](node: Node[N, E]; key: E): bool =
  ## true if the given edge value exists from the node
  block found:
    for edge in node.incoming.items:
      if edge.value == key:
        result = true
        break found

    for edge in node.outgoing.items:
      if edge.value == key:
        result = true
        break found

proc `$`*[N, E](thing: Node[N, E] | Edge[N, E]): string =
  ## a best-effort convenience
  when compiles($thing.value):
    result = $thing.value
  else:
    result = "thing needs a dollar"

proc `[]`*[N, E](node: Node[N, E]; key: E): Node[N, E] =
  ## index a node by edge, returning the opposite node
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
  ## index a node by edge, returning the opposite (mutable) node
  block found:
    for edge in node.edges.mitems:
      if edge.value == key:
        result = edge.target
        break found
    raise newException(KeyError, "edge not found: " & $key)

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

proc `[]`*[N, E](graph: Graph[N, E]; key: N): Node[N, E] =
  ## index a container of nodes using the given value
  block found:
    for node in graph.nodes.items:
      if node.value == key:
        result = node
        break found
    raise newException(KeyError, "node not found: " & $key)

proc hasKey*[N, E](graph: Graph[N, E]; key: N): bool =
  ## true if a node of the given value exists in the container
  for node in graph.nodes.items:
    if node.value == key:
      result = true
      break

iterator edges*[N, E](graph: Graph[N, E]):
  tuple[source: Node[N, E], edge: Edge[N, E], target: Node[N, E]] =
  ## yield source, edge, and target nodes from a graph
  var
    seen = initIntSet()

  for node in graph.nodes.items:
    for edge in node.outgoing.items:
      if edge.id notin seen:
        incl seen, edge.id
        yield (source: edge.source, edge: edge, target: edge.target)
    for edge in node.incoming.items:
      if edge.id notin seen:
        incl seen, edge.id
        yield (source: edge.source, edge: edge, target: edge.target)

iterator neighbors*[N, E](node: Node[N, E]):
  tuple[edge: Edge[N, E], node: Node[N, E]] =
  ## yield edge and target nodes from a node
  for edge in node.incoming.items:
    yield (edge: edge, node: edge.source)
  for edge in node.outgoing.items:
    yield (edge: edge, node: edge.target)

when false:
  proc neighbors*[N, E](node: Node[N, E]): Graph[N, E] =
    result = newGraph()
    for node in node.edges.items:
      result.append node

when false:
  #[

  too hard to reason about

  ]#
  proc `==`*[N, E](edge: Edge[N, E]; value: E): bool =
    ## convenience equality for edges and their values
    result = edge.value == value

  proc `==`*[N, E](node: Node[N, E]; value: N): bool =
    ## convenience equality for nodes and their values
    result = node.value == value

iterator items*[N, E](graph: Graph[N, E]): Node[N, E] =
  ## yield all nodes in the graph
  for node in lists.items(graph.nodes):
    yield node
