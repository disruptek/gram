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
  result = initDoublyLinkedList[Node[N, E]]()

proc newEdges[N, E](): Edges[N, E] =
  result = initDoublyLinkedList[Edge[N, E]]()

proc newNode*[N, E](n: N): Node[N, E] =
  result = Node[N, E](value: n, edges: newEdges[N, E]())

proc append*[N, E](nodes: var Nodes[N, E]; value: N) =
  var
    node = newNode[N, E](value)
  nodes.append newDoublyLinkedNode(node)

proc contains*[N, E](nodes: Nodes[N, E]; value: N): bool =
  for node in nodes.items:
    if value == node.value:
      result = true
      break

proc contains*[N, E](edge: Edge[N, E]; value: N): bool =
  result = edge.source.value == value or edge.dest.value == value

proc contains*[N, E](edge: Edge[N, E]; target: Node[N, E]): bool =
  result = target in [edge.source, edge.dest]

proc add*[N, E](node: var Node[N, E]; edge: E; target: Node[N, E]) =
  var
    edge = Edge[N, E](value: edge, source: node, dest: target)
  node.edges.append edge

proc add*[N, E](node: var Node[N, E]; edge: E; value: N) =
  var
    target = newNode[N, E](value)
  node.add edge, target

proc count*[N, E](nodes: Nodes[N, E] | Edges[N, E]): int =
  for node in nodes.items:
    inc result

proc len*[N, E](nodes: Nodes[N, E] | Edges[N, E]): int
  {.deprecated: "count() conveys the O(N) cost".} =
  result = count(nodes)

proc hasKey*[N, E](node: Node[N, E]; key: E): bool =
  for edge in node.edges.items:
    if edge.value == key:
      result = true
      break

proc `$`*[N, E](thing: Node[N, E] | Edge[N, E]): string =
  when compiles($thing.value):
    result = $thing.value
  else:
    result = "thing needs a dollar"

proc `[]`*[N, E](node: Node[N, E]; key: E): Node[N, E] =
  block found:
    for edge in node.edges.mitems:
      if edge.value == key:
        result = edge.dest
        break found
    raise newException(KeyError, "edge not found: " & $key)

proc `[]`*[N, E](node: var Node[N, E]; key: E): var Node[N, E] =
  block found:
    for edge in node.edges.mitems:
      if edge.value == key:
        result = edge.dest
        break found
    raise newException(KeyError, "edge not found: " & $key)

proc `[]=`*[N, E](node: var Node[N, E]; key: E; value: N) =
  block found:
    for edge in node.edges.mitems:
      if edge.value == key:
        edge.dest = newNode[N, E](value)
        break found
    node.add key, value

proc `[]`*[N, E](nodes: Nodes[N, E]; key: N): Node[N, E] =
  block found:
    for node in nodes.items:
      if node.value == key:
        result = node
        break found
    raise newException(KeyError, "node not found: " & $key)

proc hasKey*[N, E](nodes: Nodes[N, E]; key: N): bool =
  for node in nodes.items:
    if node.value == key:
      result = true
      break

iterator edges*[N, E](nodes: Nodes[N, E]):
  tuple[source: Node[N, E], edge: Edge[N, E], dest: Node[N, E]] =
  for node in nodes.items:
    for edge in node.edges.items:
      yield (source: node, edge: edge, dest: edge.dest)

iterator neighbors*[N, E](node: Node[N, E]):
  tuple[edge: Edge[N, E], node: Node[N, E]] =
  for edge in node.edges.items:
    yield (edge: edge, node: edge.dest)

proc `==`*[N, E](edge: Edge[N, E]; value: E): bool =
  result = edge.value == value

proc `==`*[N, E](node: Node[N, E]; value: N): bool =
  result = node.value == value
