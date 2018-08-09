module tests.some;

import optional;

@("Should be callable on a dispatch chain")
unittest {
    struct S {
        int f() { return 3; }
    }

    // static assert(is(typeof(some(S()).dispatch.some) == Optional!S));
}
