module tests.notnull;

import optional.notnull;
import unit_threaded;

@("Should construct non null object by default")
unittest {
    static class C {}
    auto a = notNull!C;
    auto b = notNull!C;
    a.shouldNotBeNull;
    b.shouldNotBeNull;
    a.should.not == b;
}

@("Should allow copy of other NotNull")
unittest {
    struct S {}
    static assert(__traits(compiles, { auto c = notNull!S; } ));
}

@("Should allow covariant assignment")
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

    a.x.should == 3;
    b.y.should == 4;

    static assert(!__traits(compiles, { a = new A(3); }));
    static assert(!__traits(compiles, { a = null; }));
    static assert(!__traits(compiles, { a = b; }));

    a = notNull!A(7);
    a.x.should == 7;

    a = notNull!C;
    a.x.should == 3;
}

@("Should work with a struct")
unittest {
    static class C { int i; }
    auto c = notNull!C;
    c.i = 3;
    c.i.should == 3;

    struct S { int i; }
    auto s = notNull!S;
    s.i = 3;
    s.i.should == 3;
}

@("Should work with a struct pointer")
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

    c.shouldNotBeNull;
    s.shouldNotBeNull;
}

@("Should not implicitly convert to type")
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

@("Should forward constructor args")
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
    c.a.should == 3;
    c.b.should == 4;
}

@("Should not be contructable or assignable to possible null")
unittest {
    static class C {}
    static assert(!__traits(compiles, { auto a = NotNull!C(); }));
    auto c = notNull!C;
    static assert(!__traits(compiles, { c = null; }));
    static assert(!__traits(compiles, { c = new C(); }));
}
