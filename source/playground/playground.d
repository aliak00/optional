module source.playground.playground;

import std.stdio: writeln;

struct Dispatcher(T) {
    import std.traits: hasMember;
    Optional!T* ptr;
    ref Optional!T self() {
        return *ptr;
    }
    this(U)(auto ref inout(U*) opt) inout {
        ptr = opt;
    }
    alias self this;
    @disable this();
    @disable this(this) {}
    @disable void opAssign(Dispatcher!T);

    void opAssign(None s) { self.opAssign(s); }
    void opAssign(U : T)(auto ref U lhs) { self.opAssign(lhs); }

    auto ref opDispatch(string name, Args...)(auto ref Args) if (hasMember!(T, name)) {
        import std.algorithm: move;
        return move(this);
    }
}

struct None {}
immutable None none;

struct Optional(T) {
    T val;
    this(U : T, this This)(auto ref U value) {
        val = value;
    }
    this(const None) pure {}
    void opAssign(None s) {}
    void opAssign(U : T)(auto ref U lhs) {}
    auto opUnary(string op)() {
        return Optional!(typeof(mixin(op ~ "val")))(mixin(op ~ "val"));
    }
    auto dispatch() inout {
        return inout Dispatcher!T(&this);
    }
}

void main() {
    static struct S {
        S other() { return S(); }
        int opUnary(string op)() { return 3; }
    }
    auto a = Optional!S(S()); // create optional
    auto b = a.dispatch.other; // create dispatched chain
    auto c = ++b; // opUnary uses alias this on dispatched optional (i.e. 'a')
    writeln(c); // prints Optional!int(3)
    b = S();
    b = none;
}
