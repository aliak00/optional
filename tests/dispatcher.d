module tests.dispatcher;

import std.stdio;

import optional;

class Class {
    int i = 0;

    this(int i) {
        this.i = i;
    }

    int getI() {
        return i;
    }

    void setI(int i) {
        this.i = i;
    }

    Class getAnotherClass() {
        return new Class(i);
    }

    Struct getStruct() {
        return Struct(this.i);
    }
}

struct Struct {
    int i = 0;

    void setI(int i) {
        this.i = i;
    }

    Class getClass() {
        return new Class(this.i);
    }

    Struct getAnotherStruct() {
        return Struct(this.i);
    }
}

@("Should dispatch multiple functions of a reference type")
unittest {
    auto a = no!Class;
    auto b = some(new Class(3));

    assert(a.dispatch.getI == no!int());
    assert(b.dispatch.getI == some(3));

    a.dispatch.setI(7);
    b.dispatch.setI(7);

    assert(a.dispatch.getAnotherClass.i == no!int);
    assert(b.dispatch.getAnotherClass.i == some(7));
}

@("Should dispatch a function of a reference type")
unittest {
    Class a;
    Class b = new Class(3);

    assert(a.dispatch.getI == no!int());
    assert(b.dispatch.getI == some(3));

    assert(b.i == 3);

    a.dispatch.setI(5);
    b.dispatch.setI(5);

    assert(b.i == 5);
}
