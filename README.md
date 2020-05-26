# gram
Lightweight generic graphs

- `cpp +/ nim-1.0` [![Build Status](https://travis-ci.org/disruptek/gram.svg?branch=master)](https://travis-ci.org/disruptek/gram)
- `arc +/ cpp +/ nim-1.3` [![Build Status](https://travis-ci.org/disruptek/gram.svg?branch=devel)](https://travis-ci.org/disruptek/gram)

## Goals
- generic node and edge types
- predictable performance
- predictable memory consumption
- predictable API
- hard to misuse

## Installation
```
$ nimble install gram
```

## Usage
```nim
import gram

# create a container holding nodes of JsonNode and edges of string
var
  g = newNodes[JsonNode, string]()

# create a few values to serve as test nodes
let
  j3 = newJInt(3)
  j9 = newJInt(9)

# add a node to the container
g.append j3 # O(1)

# add an edge to a node
j3.add("square", j9) # O(1)

# another means of adding an edge
j9["sqrt"] = j3 # O(1)

# hasKey tests for edges
assert not j9.hasKey("square") # O(N) currently

# contains works for containers and values
assert newJInt(3) in g

# the container holds only what you've added
assert j9 notin g

# count is a thing
assert count(g) == 1   # count is O(N) currently

# operate on a container of nodes as a linked list
import lists

# mutate the container during iteration
for node in g.nodes:
  remove node

# len is supported but warns you to use count()
assert g.len == 0

append(g, j3)

# simple iteration of the container
for node in g.items:

  # the value field holds the node's value
  assert node.value.getInt == 3

  # an equality overload for the value field
  assert node == newJInt(3)

  # edge and neighboring nodes arrive easily
  for edge, neighbor in node.neighbors:

    # edge equality works similarly
    assert edge == "square"

    # neighbor is a node, what else?
    assert neighbor == newJInt(9)

g.append j9

# iterate through all edges in a container
for source, edge, dest in g.edges:

  # a dollar will do something useful
  case $edge
  of "square":
    assert source == newJInt(3)
  of "sqrt":
    assert dest == newJInt(3)
  else:
    assert false

```

## Documentation
See [the documentation for the gram module](https://disruptek.github.io/gram/gram.html) as generated directly from the source.

## Tests
Tests?  We do'n need no stinkin' tests.

## License
MIT
