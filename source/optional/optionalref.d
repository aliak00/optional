module optional.optionalref;

/**
    This is a reference to a value type that is used to proxy around pointers when dispatching

    It is aliased to an Optional!T
*/
package struct OptionalRef(T) {
    import optional: Optional;
    import std.traits: isMutable, isCopyable;

    private union Data {
        Optional!T val; // this is first because it is the .init value
        Optional!T* ptr;
    }

    private Data data;
    private bool isVal;

    @disable this();

    this(Optional!T* ptr) {
        data.ptr = ptr;
        isVal = false;
    }

    this()(auto ref Optional!T val) {
        data.val = val;
        isVal = true;
    }

    public @property ref get() { if (isVal) return data.val; else return *data.ptr; }

    alias get this;
}

package template isOptionalRef(T) {
    import std.traits: isInstanceOf;
    enum isOptionalRef = isInstanceOf!(OptionalRef, T);
}


@("Should not be constructable")
unittest {
    static assert(!__traits(compiles, { OptionalRef!int a; } ));
}

@("Should be assignable to an Optional")
unittest {

    import optional;

    class C {
        C get() {
            return this;
        }
    }
    struct S {
        C c;
        this(C c) {
            this.c = c;
        }
        ref S f() {
            return this;
        }
    }

    auto makeS(C c) {
        return some(S(c)).dispatch.f;
    }

    Optional!S x;
    Optional!S y;

    auto theC = new C();
    {
        auto t1 = makeS(null);
        auto t2 = makeS(theC);

        static assert(isOptionalRef!(typeof(t1)));
        static assert(isOptionalRef!(typeof(t2)));

        x = makeS(null);
        y = makeS(theC);
    }

    assert(x.dispatch.c == none);
    assert(y.dispatch.c == theC);
}
