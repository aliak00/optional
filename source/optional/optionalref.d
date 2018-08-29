module optional.optionalref;

package struct OptionalRef(T) {
    import optional: Optional;

    private union Data {
        Optional!T* ptr;
        Optional!T val;
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
