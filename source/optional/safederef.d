module optional.safederef;

import optional.internal;

/**
    Use this to start a safe dispatch chain on things
*/
auto safeDeref(T)(T value) {
    import optional;
    import std.algorithm: move;
    auto d = some(value).autoDispatch;
    writeln(d.some);
    return move(d);
}

unittest {
    import optional;
    class C {
        C f() {
            return new C();
        }
    }

    auto a = new C();
    C b;

    import std.stdio;

    safeDeref(a).some.writeln;
    safeDeref(b).some.writeln;
    some(a).autoDispatch.some.writeln;
    some(b).autoDispatch.some.writeln;
}
