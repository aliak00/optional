# Optional type for D with safe dispatching and NotNull type

[![Latest version](https://img.shields.io/dub/v/optional.svg)](https://code.dlang.org/packages/optional) [![Build Status](https://travis-ci.org/aliak00/optional.svg?branch=master)](https://travis-ci.org/aliak00/optional) [![codecov](https://codecov.io/gh/aliak00/optional/branch/master/graph/badge.svg)](https://codecov.io/gh/aliak00/optional) [![license](https://img.shields.io/github/license/aliak00/optional.svg)](https://github.com/aliak00/optional/blob/master/LICENSE) [![Open on run.dlang.io](https://img.shields.io/badge/run.dlang.io-open-blue.svg)](https://run.dlang.io/is/CxJwiO)

Full API docs available [here](https://aliak00.github.io/optional/optional.html)

* [Features](#features)
* [Summary](#summary)
* [Motivation for Optional](#motivation-for-optional)
    * [Use pointers?](#use-pointers)
    * [How about ranges?](#how-about-ranges)
    * [Let's try an Optional!int](#lets-try-an-optionalint)
* [FAQ](#faq)
    * [Can't I just use a pointer as an optional](#cant-i-just-use-a-pointer-as-an-optional)
    * [What about std.typecons.Nullable?](#what-about-stdtypeconsnullable)
* [Scala we have a Swift comparison](#scala-we-have-a-swift-comparison)
* [Examples](#examples)
    * [Example Optional!T usage](#example-optionalt-usage)
    * [Example dispatch usage](#example-dispatch-usage)


## Features

* `@nogc` and `@safe`
* Shows the intent of your code that may or may not return a value
    ```d
    Optional!int fun() {} // Might return an int, or might not
    ```
* Includes a generic `orElse` range algorithm:
    ```d
    auto a = some(3);
    auto b = a.orElse(7);
    auto c = a.orElse(some(4));
    c.orElse!(() => writeln("c is empty"));
    ```
* Use pattern matching
    ```d
    fun.match!(
        (int value) => writeln("it returns an int"),
        () => writeln("did not return anything"),
    );
    ```
* Safely call functions on classes that are null, structs that don't exist, or `std.typecons.Nullable`
    ```d
    class C { int fun() { return 3; } }
    Optional!C a = null;
    oc(a).fun; // no crash, returns no!int
    ```
* Forwards any operator calls to the wrapped typed only if it exists, else just returns a `none`
    ```d
    Optional!int a = 3;
    Optional!int b = none;
    a + 3; // evaluates to some(6);
    b + 3; // evaluates to no!int;

    int f0(int) { return 4; }
    auto a0 = some(&f0); // return some(4)
    ```
* Compatible with `std.algorithm` and `std.range`
    ```d
    fun.each!(value => writeln("I got the value"));
    fun.filter!"a % 2 == 0".each!(value => writeln("got even value"));
    ```

## Summary

The pupose of this library is to provide an [Optional type](https://en.wikipedia.org/wiki/Option_type).

It contains the following constructs:
* `Optional!T`: Represents an optional data type that may or may not contain a value that acts like a range.
* `oc`: A null-safe optional chaining (oc) utility that allows you to chain methos through possible empty objects.
* `orElse`: A range algorithm that also acts as a coalescing operator
* `match`: Pattern match on optionals

An `Optional!T` signifies the intent of your code, works as a range and is therefore usable with Phobos algorithms, and allows you to call methods and operators on your types even if they are null references - i.e. safe dispatching.

Some use cases:
* When you need a type that may have a value or may not (`Optional!Type`)
* When you want to safely dispatch on types (`oc(obj).someFunction // always safe`)
* When you want to not crash with array access (`some([1, 2])[7] == none // no out of bounds exception`)
* When you want to perform an operation if you get a value (`obj.map!doSomething.orElse!doSomethingElse`)

## Motivation for Optional

Let's take a very contrived example, and say you have a function that may return a value (that should be some integer) or not (config file, server, find operation, whatever), and then you have functions add1 and add2, that have the requirements that they may or may not produce a valid value. (maybe they do some crazy division, or they contact a server themselves to fetch a value, whatevs).

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

## FAQ

### Can't I just use a pointer as an optional

Well yes, you can, but you *can* also stick a pencil up your nostril. It's a bad idea for the following reasons:

1. In order to achieve stability, you have to enforce checking for null. Which you cannot do
1. Null is part of the value domain of pointers. This means you can't use an optional of null
1. The caller doesn't know who owns the pointer returned. Is it garbage collected? If not should you deallocate it?
1. It says nothing about intent.

### What about `std.typecons.Nullable`?

It is not like the `Nullable` type in Phobos. `Nullable` is basically a pointer and applies pointer semantics to value types. It does not give you any safety guarantees and says nothing about the intent of "I might not return a value". It does not have range semantics so you cannot use it with algorithms in phobos. And it treats null class objects as valid.

It does, however, tell you if something has been assigned a value or not. Albeit a bit counterintuitively, and in some cases nonsensically:

```d
class C {}
Nullable!C a = null;
writeln(a.isNull); // prints false
```

With classes you end up having to write code like this:

```d
void f(T)(Nullable!T a) {
    if (!a.isNull) {
        static if (is(T == class) || (T == interface) || /* what else have I missed? */) {
            if (a.get !is null) {
                a.callSomeFunction;
            }
        } else {
            a.callSomeFunction;
        }
    }
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

auto n = oc(john).residence.numberOfRooms;

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

import std.algorithm: each;
import std.stdio: writeln;

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

### Example optional chaining usage
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

oc(d).f(); // calls a.f, returns some(4)
oc(d).inner.g(); // calls a.inner.g, returns some(7)

// Use on a pointer or reference type as well
A* e = null;

// If there's no value in the reference type, dispatching works, and produces an optional
assert(e.oc.f() == none);
assert(e.oc.inner.g() == none);
```
[![Open on run.dlang.io](https://img.shields.io/badge/run.dlang.io-open-blue.svg)](https://run.dlang.io/is/SmsGQu)
