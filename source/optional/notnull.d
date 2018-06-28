module optional.notnull;

import optional.internal;

/**
    A NotNull type ensure that the type you give it can never have a null value. So it is always
    safe to use. It's specifically designed for pointers to values or classes. You can give it
    a struct as well.

    The one thing to watch out for is inner classes or structs. Since `notNull` is a template function,
    and it ensures that a type T is always created, it has to allocate memory. But inner classes and
    structs need a context pointer to be `new`ed, so this only works with static inner classes and
    structs.
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

///
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

unittest {
    static class C {}
    auto a = notNull!C;
    auto b = notNull!C;
    assert(a !is null);
    assert(b !is null);
    assert(a !is b);
}

unittest {
    struct S {}
    static assert(__traits(compiles, { auto c = notNull!S; } ));
}

unittest {
    static class A {
        int x;
        this(int i) {
            this.x = i;
        }
    }

    static class B {
        int y;
        this(int i) {
            this.y = i;
        }
    }

    static class C : A { this() { super(3); } }

    auto a = notNull!A(3);
    auto b = notNull!B(4);

    assert(a.x == 3);
    assert(b.y == 4);

    static assert(!__traits(compiles, { a = new A(3); }));
    static assert(!__traits(compiles, { a = null; }));
    static assert(!__traits(compiles, { a = b; }));

    a = notNull!A(7);
    assert(a.x == 7);

    a = notNull!C;
    assert(a.x == 3);
}

unittest {
    static class C { int i; }
    auto c = notNull!C;
    c.i = 3;
    assert(c.i == 3);

    struct S { int i; }
    auto s = notNull!S;
    s.i = 3;
    assert(s.i == 3);
}

unittest {
    static class C { int i; }
    struct S { int i; }

    void f(C c) {
        c = null;
    }

    void g(S* s) {
        s = null;
    }

    auto c = notNull!C;
    auto s = notNull!(S*);

    f(c);
    g(s);

    assert(c !is null);
    assert(s !is null);
}

unittest {
    static class C { int i; }
    struct S { int i; }

    void f(ref C c) {
        c = null;
    }

    void g(ref S* s) {
        s = null;
    }

    static assert(!__traits(compiles, { f(notNull!C); }));
    static assert(!__traits(compiles, { g(notNull!(S*)); }));
}

unittest {
    static class C {
        int a;
        int b;
        this(int a, int b) {
            this.a = a;
            this.b = b;
        }
    }

    auto c = notNull!C(3, 4);
    assert(c.a == 3);
    assert(c.b == 4);
}
