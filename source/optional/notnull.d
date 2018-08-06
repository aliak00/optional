/**
    Provides a wrapper type to ensure objects are never null
*/
module optional.notnull;

import optional.internal;

/**
    Creates a `NotNull` type

    Params:
        args = any arguments that need to be passed to T's constructor
*/
auto notNull(T, Args...)(Args args) {
    import std.traits: isPointer;
    static if (isPointer!T) {
        import std.traits: PointerTarget;
        auto instance = new PointerTarget!T(args);
    } else static if (is(T == class)) {
        auto instance = new T(args);
    } else {
        auto instance = T(args);
    }
    return NotNull!T(instance);
}

/**
    A NotNull type ensure that the type you give it can never have a null value. So it is always
    safe to use. It's specifically designed for pointers to values or classes. You can give it
    a struct as well.

    The one thing to watch out for is inner classes or structs. Since `notNull` is a template function,
    and it ensures that a type T is always created, it has to allocate memory. But inner classes and
    structs need a context pointer to be `new`ed, so this only works with static inner classes and
    structs.

    the constructor is disabled, so you have to use the function `notNull` to construct `NotNull` objects.
*/
struct NotNull(T) {
    import std.traits: isPointer;
    import optional: isNotNull;

    // We only allow a getter if it is a class or pointer type so that it can't be set
    // to null form the outside. Otherwise just alias the whole thing.
    static if (isPointer!T || is(T == class))
    {
        private T _value;
        @property T value() { return this._value; }
        alias value this;
    }
    else
    {
        T _value;
        alias _value this;
    }

    @disable void opAssign(typeof(null));
    @disable this();

    private this(T value) {
        this._value = value;
    }

    /**
        You can only init from another `NotNull` type.
    */
    this(V)(NotNull!V other) {
        self._value = other._value;
    }

    /**
        You can only asign to another `NotNull` type.
    */
    void opAssign(V)(NotNull!V other) {
        this._value = other._value;
    }
}

///
@("Example of NotNull")
unittest {
    static class C { int i; void f() { i = 3; } }
    static struct S { int i; void f() { i = 3; } }

    void f0(NotNull!C c) {
        c.f();
    }

    void f1(NotNull!(S*) sp) {
        sp.f();
    }

    void f2(ref NotNull!(S) s) {
        s.f();
    }

    auto c = notNull!C;
    auto sp = notNull!(S*);
    auto s = notNull!S;

    f0(c);
    f1(sp);
    f2(s);

    assert(c.i == 3);
    assert(sp.i == 3);
    assert(s.i == 3);
}

