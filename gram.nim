import std/lists

type
  Node*[N, E] = ref object
    value*: N
    edges: Edges[N, E]
  Nodes*[N, E] = DoublyLinkedList[Node[N, E]]

  Edge*[N, E] = ref object
    value*: E
    source: Node[N, E]
    dest: Node[N, E]
  Edges*[N, E] = DoublyLinkedList[Edge[N, E]]

proc newNodes*[N, E](): Nodes[N, E] =
  ## create a new container holding nodes
  result = initDoublyLinkedList[Node[N, E]]()

proc newEdges[N, E](): Edges[N, E] =
  ## create a new container holding edges; not public
  result = initDoublyLinkedList[Edge[N, E]]()

proc newNode*[N, E](value: N): Node[N, E] =
  ## create a new node of the given value
  result = Node[N, E](value: value, edges: newEdges[N, E]())

proc append*[N, E](nodes: var Nodes[N, E]; value: N) =
  ## append a new node of the given value to the container
  var
    node = newNode[N, E](value)
  nodes.append newDoublyLinkedNode(node)

proc contains*[N, E](nodes: Nodes[N, E]; value: N): bool =
  ## true if the container holds a node with the given value
  for node in nodes.items:
    if value == node.value:
      result = true
      break

proc contains*[N, E](edge: Edge[N, E]; value: N): bool =
  ## true if the edge links a node with the given value
  result = edge.source.value == value or edge.dest.value == value

proc contains*[N, E](edge: Edge[N, E]; target: Node[N, E]): bool =
  ## true if the edge links the given node
  result = target in [edge.source, edge.dest]

proc add*[N, E](node: var Node[N, E]; edge: E; target: Node[N, E]) =
  ## add the given edge from the node to a target node
  var
    edge = Edge[N, E](value: edge, source: node, dest: target)
  node.edges.append edge

proc add*[N, E](node: var Node[N, E]; edge: E; value: N) =
  ## add the given edge from the node to a new node with the given value
  var
    target = newNode[N, E](value)
  node.add edge, target

proc count*[N, E](nodes: Nodes[N, E] | Edges[N, E]): int =
  ## count the number of items in a container
  for node in nodes.items:
    inc result

proc len*[N, E](nodes: Nodes[N, E] | Edges[N, E]): int
  {.deprecated: "count() conveys the O(N) cost".} =
  ## use count() instead; it expresses the order more clearly
  result = count(nodes)

proc hasKey*[N, E](node: Node[N, E]; key: E): bool =
  ## true if the given edge value exists from the node
  for edge in node.edges.items:
    if edge.value == key:
      result = true
      break

proc `$`*[N, E](thing: Node[N, E] | Edge[N, E]): string =
  ## a best-effort convenience
  when compiles($thing.value):
    result = $thing.value
  else:
    result = "thing needs a dollar"

proc `[]`*[N, E](node: Node[N, E]; key: E): Node[N, E] =
  ## index a node by edge, returning the opposite node
  block found:
    for edge in node.edges.mitems:
      if edge.value == key:
        result = edge.dest
        break found
    raise newException(KeyError, "edge not found: " & $key)

proc `[]`*[N, E](node: var Node[N, E]; key: E): var Node[N, E] =
  ## index a node by edge, returning the opposite (mutable) node
  block found:
    for edge in node.edges.mitems:
      if edge.value == key:
        result = edge.dest
        break found
    raise newException(KeyError, "edge not found: " & $key)

proc `[]=`*[N, E](node: var Node[N, E]; key: E; value: N) =
  ## add the given edge from the node to a new node with the given value
  block found:
    for edge in node.edges.mitems:
      if edge.value == key:
        edge.dest = newNode[N, E](value)
        break found
    node.add key, value

proc `[]`*[N, E](nodes: Nodes[N, E]; key: N): Node[N, E] =
  ## index a container of nodes using the given value
  block found:
    for node in nodes.items:
      if node.value == key:
        result = node
        break found
    raise newException(KeyError, "node not found: " & $key)

proc hasKey*[N, E](nodes: Nodes[N, E]; key: N): bool =
  ## true if a node of the given value exists in the container
  for node in nodes.items:
    if node.value == key:
      result = true
      break

iterator edges*[N, E](nodes: Nodes[N, E]):
  tuple[source: Node[N, E], edge: Edge[N, E], dest: Node[N, E]] =
  ## yield source, edge, and destination nodes from a container of nodes
  for node in nodes.items:
    for edge in node.edges.items:
      yield (source: node, edge: edge, dest: edge.dest)

iterator neighbors*[N, E](node: Node[N, E]):
  tuple[edge: Edge[N, E], node: Node[N, E]] =
  ## yield edge and destination nodes from a node
  for edge in node.edges.items:
    yield (edge: edge, node: edge.dest)

proc `==`*[N, E](edge: Edge[N, E]; value: E): bool =
  ## convenience equality for edges and their values
  result = edge.value == value

proc `==`*[N, E](node: Node[N, E]; value: N): bool =
  ## convenience equality for nodes and their values
  result = node.value == value

iterator items*[N, E](nodes: Nodes[N, E]): Node[N, E] =
  ## items iterator for nodes, obvs
  for node in lists.items(nodes):
    yield node
