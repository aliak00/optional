## Optional type for D

[![Latest version](https://img.shields.io/dub/v/optional-d.svg)](http://code.dlang.org/packages/optional-d) [![Build Status](https://travis-ci.org/aliak00/optional-d.svg?branch=master)](https://travis-ci.org/aliak00/optional-d) [![codecov](https://codecov.io/gh/aliak00/optional-d/branch/master/graph/badge.svg)](https://codecov.io/gh/aliak00/optional-d) [![license](https://img.shields.io/github/license/aliak00/optional-d.svg)](https://github.com/aliak00/optional-d/blob/master/LICENSE)

Full API docs available [here](https://aliak00.github.io/optional-d/)

Represents an optional data type that may or may not contain a value. Matches behavior of haskell maybe and scala or swift
optional type.

E.g.
```d
import optional;

// Create empty optional
auto a = no!int;

// Try doing stuff, all results in none
assert(a == none);

++a; // none;
a - 1; // none;

// Assign and try doing the same stuff
a = 9;
assert(a == some(9));

++a; // some(10);
a - 1; // some(9);

// Acts like a range as well

import std.algorithm: map;
import std.conv: to;

auto b = some(10);
auto c = no!int;

b.map!(to!double) // [10.0]
c.map!(to!double) // empty

// Can safely dispatch to whatever inner type is
struct A {
    struct Inner {
        int g() { return 7; }
    }
    Inner inner() { return Inner(); }
    int f() { return 4; }
}

auto d = some(A());

// Dispatch to one of its methods

d.dispatch.f(); // calls a.f, returns some(4)
d.dispatch.inner.g(); // calls a.inner.g, returns some(7)

auto e = no!(A*); 

// If there's no value in the optional or it's a pointer that is null, dispatching still works, but produces none
assert(e.dispatch.f() == none);
assert(e.dispatch.inner.g() == none);

// Set a value and now it will work
e = new A;

assert(e.dispatch.f() == some(4));
assert(e.dispatch.inner.g() == some(7));

```
