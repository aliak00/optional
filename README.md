# Optional type for D featuring NotNull

[![Latest version](https://img.shields.io/dub/v/optional.svg)](http://code.dlang.org/packages/optional) [![Build Status](https://travis-ci.org/aliak00/optional.svg?branch=master)](https://travis-ci.org/aliak00/optional) [![codecov](https://codecov.io/gh/aliak00/optional/branch/master/graph/badge.svg)](https://codecov.io/gh/aliak00/optional) [![license](https://img.shields.io/github/license/aliak00/optional.svg)](https://github.com/aliak00/optional/blob/master/LICENSE)

Full API docs available [here](https://aliak00.github.io/optional/optional.html)

* [Summary](#summary)
* [Motivation for Optional](#motivation-for-optional)
    * [Use pointers?](#use-pointers)
    * [How about ranges?](#how-about-ranges)
    * [Let's try an Optional!int](#lets-try-an-optionalint)
* [Example Optional!T usage](#example-optionalt-usage)
* [Example NotNull!T usage](#example-notnullt-usage)

## Summary

* `Optional!T`: Represents an optional data type that may or may not contain a value. Acts like a range and allows safe dispatching
* `NotNull!T`: Represents a type that can never be null. Comes in handy for nullable types (e.g. classes and pointers)

An `Optional!T` signifies the intent of your code, works as a range and is therefor useable with Phobos, and allows you to call methods and operators on your types even if they are null references - i.e. safe dispatching.

It is NOT like the `Nullable` type in Phobos. `Nullable` is basically a pointer and applies pointer semantics to value types. Whereas `Optional` signifies intent on both reference and value types, and is safe to use without need to check `isNull` before every usafe. It is also NOT like `std.range.only`. `Only` cannot be used to signify intent of a value being present or not, it's only (heh) usage is to create a range out of a value so that values can act as ranges and be used seamlessly with `std.algorithms`. `Optional!T` has a type constructor - `some` that can be used for this purpose as well.

## Motivation for Optional

Lets take a very contrived example, and say you have a function that may return a value (that should be some integer) or not (config file, server, find operation, whatever), and then you have functions add1, add2, and add3, what have the requirements that they may or may not produce a value. (maybe they do some crazy division, or they contact a server themselves to fetch a value, etc).

How can you go about this?

### Use pointers?

```d
int* add1(int *v) {
  // Gotta remember to protect against null
  if (!v) {
    return v;
  }
  *v += 1;
  return v;
}

int* add2(int *v); // might forget to check for null
int* add3(int *v); // might forget to check for null

void f() {
  int* v = maybeGet();
  if (v)
    v = v.add1;
  if (v)
    v = v.add2;
  if (v)
    v = v.add3;
  if (v)
    writeln(*v);
}
```

You can also replace int* with Nullable!int and then instead of `if (v)` you'd have to do `if (!v.isNull)` and instead of `*v` you'd do `v.get`.

### How about ranges?

There's std.range.only:

```d
// How do I write it?
// Is Only!T a type?
// It's not documented though
// But Only!T is actually Only!(T0, T1, T3 ..., TN) ??
// What do I do with that?
auto add2(Range)(Range r)
if (isInputRange!Range && is(ELementType!Range == int)) // constrain to range type only and int element type?
{
  // do we have one element or more now?
  // what do we do if there's more than one?
  // do we restrain it at run time to being there?
  enforce(r.walkLength <= 1); // ??
  // Should we map all of it?
  return v.map!(a => a + 1);
  // Or just the first?
  return v.take(1).map!(a => a + 1);
  // But what do I do with the rest then?
}

auto add2(Range)(Range r) if (isInputRange!Range) {
  // same headache as above
}

auto add3(Range)(Range r) if (isInputRange!Range) {
  // same headache as above
}

void f() {
  auto v = maybeGet();
  // can we assign it to itself?
  v = v.add1.add2.add3;
  // No, no idea what it returns, not really the same type
  // so this...
  refRange(&v).add1.add2.add3; // ??
  // no that won't work (can it?), lets create a new var
  auto v2 = v.add1.add2.add3 // and let type inference do its thing
  writeln(v2); // now ok.
}
```

### Let's try an Optional!int

```d
auto add1(Optional!int v) {
  v += 1;
  return v;
}
auto add2(Optional!int v); // same as above
auto add3(Optional!int v); // same as above

void f() {
  auto v = maybeGet();
  v = v.add1.add2.add3;
  writeln(v);
}
```

## Example Optional!T usage

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

## Example NotNull!T usage

```d
class C { void f() {} }
struct S { void f() {} }

void f(NotNull!C c) {
    c.f();
}

void f(NotNull!(S*) sp) {
    sp.f();
}

auto c = notNull!C;
auto sp = notNull!(S*);

f0(c);
f1(sp);

// c = null; // nope
// sp = null; // nope
// c = new C; // nope
```