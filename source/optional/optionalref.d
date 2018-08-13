module optional.optionalref;

struct OptionalRef(T) {
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

    this(Optional!T val) {
        data.val = val;
        isVal = true;
    }

    @property ref get() { if (isVal) return data.val; else return *data.ptr; }

    alias get this;
}
