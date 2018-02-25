## Optional type for D

[![Latest version](https://img.shields.io/dub/v/optional.svg)](http://code.dlang.org/packages/optional) [![Build Status](https://travis-ci.org/aliak00/optional.svg?branch=master)](https://travis-ci.org/aliak00/optional) [![codecov](https://codecov.io/gh/aliak00/optional/branch/master/graph/badge.svg)](https://codecov.io/gh/aliak00/optional) [![license](https://img.shields.io/github/license/aliak00/optional.svg)](https://github.com/aliak00/optional/blob/master/LICENSE)

Full API docs available [here](https://aliak00.github.io/optional/)

Represents an optional data type that may or may not contain a value. Matches behavior of haskell maybe and scala or swift
optional type. With the added benefit (like scala) of behving like an single element or empty D range.

In many cases it is equivalent to [std.range.only](https://dlang.org/phobos/std_range.html#only).

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
