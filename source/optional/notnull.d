module optional.notnull;

import optional.internal;

struct NotNull(T) {
    import optional: isNotNull;
    private T _value;
    @property T value() { return this._value; }

    alias value this;

    @disable void opAssign(typeof(null));

    private this(T value) {
        this._value = value;
    } 

    this(V)(NotNull!V other) {
        self._value = other._value;
    }
    void opAssign(V)(NotNull!V other) {
        this._value = other._value;
    }
}

auto notNull(T, Args...)(Args args) {
    import std.traits: isPointer;
    static if (isPointer!T) {
        import std.traits: PointerTarget;
        auto instance = new PointerTarget!T(args);
    } static if (is(T == class)) {
        auto instance = new T(args);
    } else {
        auto instance = T(args);
    }
    return NotNull!T(instance);
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