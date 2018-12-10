# Optional type for D with safe dispatching and NotNull type

[![Latest version](https://img.shields.io/dub/v/optional.svg)](https://code.dlang.org/packages/optional) [![Build Status](https://travis-ci.org/aliak00/optional.svg?branch=master)](https://travis-ci.org/aliak00/optional) [![codecov](https://codecov.io/gh/aliak00/optional/branch/master/graph/badge.svg)](https://codecov.io/gh/aliak00/optional) [![license](https://img.shields.io/github/license/aliak00/optional.svg)](https://github.com/aliak00/optional/blob/master/LICENSE) [![Open on run.dlang.io](https://img.shields.io/badge/run.dlang.io-open-blue.svg)](https://run.dlang.io/is/CxJwiO)

Full API docs available [here](https://aliak00.github.io/optional/optional.html)

* [Summary](#summary)
* [What about std.typecons.Nullable std.range.only?](#what-about-stdtypeconsnullable-and-stdrangeonly)
* [Motivation for Optional](#motivation-for-optional)
    * [Use pointers?](#use-pointers)
    * [How about ranges?](#how-about-ranges)
    * [Let's try an Optional!int](#lets-try-an-optionalint)
* [Scala we have a Swift comparison](#scala-we-have-a-swift-comparison)
* [Examples](#examples)
    * [Example Optional!T usage](#example-optionalt-usage)
    * [Example dispatch usage](#example-dispatch-usage)
    * [Example NotNull!T usage](#example-notnullt-usage)

## Summary

The purpose of this library is two fold, to provide types that:

1. Eliminate null dereferences - [Aka the Billion Dollar Mistake](https://en.wikipedia.org/wiki/Tony_Hoare#Apologies_and_retractions).
2. Show an explicit intent of the absence of a value
3. Safe (non crashing) array access

This is done with the following:

* `Optional!T`: Represents an optional data type that may or may not contain a value that acts like a range.
* `NotNull!T`: Represents a type that can never be null.
* `dispatch`: A null-safe dispatching utility that allows you to call methods on possibly null values (including optionals, and `std.typecons.Nullable`)

An `Optional!T` signifies the intent of your code, works as a range and is therefor useable with Phobos algorithms, and allows you to call methods and operators on your types even if they are null references - i.e. safe dispatching.

You can use this library:
* When you need a type that may have a value or may not (`Optional!Type`)
* When you want to safely dispatch on types (`possibleNullClass.dispatch.someFuncion // safe`)
* When you want a guaranteed non null object (`NotNull!Type`)
* When you want to not crash with array access (`some([1, 2])[7] == none // no out of bounds exception`)

## What about `std.typecons.Nullable` and `std.range.only`?

It is NOT like the `Nullable` type in Phobos. `Nullable` is basically a pointer and applies pointer semantics to value types. It does not give you any safety guarantees and says nothing about the intent of "I might not return a value". Whereas `Optional` signifies intent on both reference and value types, and is safe to use without the need to check `isNull` before every usage.

It is also NOT like `std.range.only`. D's `only` cannot be used to signify intent of a value being present or not, nor can be used for safe dispatching, nor the result of `only(value)` be passed around. It's only (heh) usage is to create a range out of a value so that values can act as ranges and be used seamlessly with `std.algorithms`. This `Optional` has a type constructor - `some` - that can be used for this purpose as well.

## Motivation for Optional

Lets take a very contrived example, and say you have a function that may return a value (that should be some integer) or not (config file, server, find operation, whatever), and then you have functions add1 and add2, that have the requirements that they may or may not produce a valid value. (maybe they do some crazy division, or they contact a server themselves to fetch a value, whatevs).

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

void f() {
    int* v = maybeGet();
    if (v)
        v = v.add1;
    if (v)
        v = v.add2;
    if (v)
        writeln(*v);
}
```

You can also replace int* with Nullable!int and then instead of `if (v)` you'd have to do `if (!v.isNull)` and instead of `*v` you'd do `v.get`.

### How about ranges?

There's std.range.only:

```d
auto add2(Range)(Range r)
if (isInputRange!Range && is(ElementType!Range == int))
// constrain to range type only and int element type?
// I need to ensure it has a length of one.
// And there's no way to ensure that in compile time without severly constraigning the type
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

void f() {
    auto v = maybeGet();
    // can we assign it to itself?
    v = v.add1.add2;
    // No, no idea what it returns, not really the same type
    // so this...
    refRange(&v).add1.add2; // ??
    // no that won't work (can it?), lets create a new var
    auto v2 = v.add1.add2 // and let type inference do its thing
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

void f() {
    auto v = maybeGet().add1.add2;
    writeln(v);
}
```

## Scala we have a Swift comparison

In this section we'll see how this Optional is similar to [Scala's `Option[T]`](https://www.scala-lang.org/api/current/scala/Option.html) and [Swift's `Optional<T>`](https://developer.apple.com/documentation/swift/optional) type (similar to Kotlin's [nullable type handling](https://kotlinlang.org/docs/reference/null-safety.html))

Idiomatic usage of optionals in Swift do not involve treating it like a range. They use optional unwrapping to ensure safety and dispatch chaining. Scala on the other hand, treats optionals like a range and provides primitives to get at the values safely.

Like in swift, you can chain functions safely so in case they are null, nothing will happen:

**D**: Unfortunately the lack of operator overloading makes dispatching a bit verbose.
```d
class Residence {
    auto numberOfRooms = 1;
}
class Person {
    Optional!Residence residence = new Residence();
}

auto john = some(new Person());

auto n = john.dispatch.residence.numberOfRooms;

writeln(n); // prints [1]
```

**Swift**
```swift
class Person {
    var residence: Residence?
}

class Residence {
    var numberOfRooms = 1
}

let john: Person? = Person()
let n = john?.residence?.numberOfRooms;

print(n) // prints "nil"
```

Like in Scala, a number of range primitives are provided to help (not to mention we have Phobos as well)

**D**
```d
auto x = toInt("1").orElse(0);

import std.algorithm: each; import std.stdio: writeln;
toInt("1").each!writeln;

toInt("1").match!(
    (i) => writeln(i),
    () => writeln("😱"),
);

// For completeness, the implementation of toInt:
Optional!int toInt(string str) {
    import std.conv: to;
    scope(failure) return no!int;
    return some(str.to!int);
}
```

**Scala**
```scala
val x = toInt("1").getOrElse(0)

toInt("1").foreach{ i =>
    println(s"Got an int: $i")
}

toInt("1") match {
    case Some(i) => println(i)
    case None => println("😱")
}

// Implementation of toInt
def toInt(s: String): Option[Int] = {
    try {
        Some(Integer.parseInt(s.trim))
    } catch {
        case e: Exception => None
    }
}
```

Also like in Swift, you can unwrap an optional to get at it's value:

**D**
```d
auto str = "123";
if (auto number = toInt(str).unwrap) {
    writeln(*number);
} else {
    writeln("could not convert string ", str);
}
```

**Swift**
```swift
let string = "123"
if let number = Int(str) {
    print(number) // was successfully converted
} else {
    print("could not convert string \(string)")
}
```

## Examples

The following section has example usage of the various types

### Example Optional!T usage
```d
import optional;

// Create empty optional
auto a = no!int;
assert(a == none);

++a; // safe;
a - 1; // safe;

// Assign and try doing the same stuff
a = 9;
assert(a == some(9));

++a; // some(10);
a - 1; // some(9);

// Acts like a range as well
import std.algorithm : map;
import std.conv : to;

cast(void)some(10).map!(to!double); // [10.0]
cast(void)no!int.map!(to!double); // empty

auto r = some(1).match!((int a) => "yes", () => "no",);
assert(r == "yes");
```
[![Open on run.dlang.io](https://img.shields.io/badge/run.dlang.io-open-blue.svg)](https://run.dlang.io/is/AH9LkT)

### Example NotNull!T usage
```d
static class C { void f() {} }
static struct S { void f() {} }

void f0(NotNull!C c) {
    c.f();
}

void f1(NotNull!(S*) sp) {
    sp.f();
}

auto c = notNull!C;
auto sp = notNull!(S*);

f0(c);
f1(sp);

static assert(!__traits(compiles, { c = null; }));
static assert(!__traits(compiles, { sp = null; }));
static assert(!__traits(compiles, { c = new C; }));
```
[![Open on run.dlang.io](https://img.shields.io/badge/run.dlang.io-open-blue.svg)](https://run.dlang.io/is/3AJpNA)

### Example dispatch usage
```d
// Safely dispatch to whatever inner type is
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

// Use on a pointer or reference type as well
A* e = null;

// If there's no value in the reference type, dispatching works, and produces an optional
assert(e.dispatch.f() == none);
assert(e.dispatch.inner.g() == none);
```
[![Open on run.dlang.io](https://img.shields.io/badge/run.dlang.io-open-blue.svg)](https://run.dlang.io/is/SmsGQu)
