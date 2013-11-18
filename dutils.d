import std.typecons : Proxy;
import std.algorithm : swap, move;
import std.concurrency : spawn, send, receive;
import std.c.string : memcpy;


struct Unique(T)
{
    private T _p;

    private this(T p)
    {
        _p = p;
    }

    @disable this(this);

public:
    mixin Proxy!_p;

    this(UniquePackage!T p)
    {
        memcpy(&(_p), p._p.ptr, _p.sizeof);
    }

    void opAssign(Unique!T other)
    {
        swap(other._p, _p);
    }

    UniquePackage!T pack()
    {
        return UniquePackage!T(move(this));
    }

    T rel()
    {
        T ret = _p;
        _p = null;
        return ret;
    }

    immutable(T) irel()
    {
        immutable(T) ret = cast(immutable)(_p);
        _p = null;
        return ret;
    }

    ~this()
    {
        delete _p;
    }
}

Unique!T unique(T, Args...)(Args args)
if (is(T:Object))
{
    return Unique!T(new T(args));
}

Unique!T unique(T)(T assumedUnique)
{
    return Unique!T(assumedUnique);
}

Unique!(T[]) unique(T : T[])(size_t size)
{
    return Unique!(T[])(new T[size]);
}

struct UniquePackage(T)
{
    private ubyte _p[Unique!T._p.sizeof];

public:
    this(Unique!T payload)
    {
        memcpy(_p.ptr, &(payload._p), _p.length);
        payload.rel;
    }

    Unique!T unpack()
    {
        return Unique!T(this);
    }
}

unittest
{
    static class Test
    {
        int x;
        ubyte y;
    public:
        this(int xx)
        {
            x = xx;
        }
        int test()
        {
            return x;
        }
        static Unique!(Test) test(Unique!(Test) t)
        {
            return move(t);
        }
    }

    // can create a unique class instance
    auto t1 = unique!Test(5);
    assert(t1.test == 5);

    // can assume a class instance unique
    auto t2 = new Test(6).unique;
    assert(t2.test == 6);

    // can create a unique array
    auto t3 = unique!(int[])(5);
    assert(t3.length == 5);
    assert(t3[0] == 0);
    assert(t3[0..3] == [0, 0, 0]);

    // can assume an array unique
    auto t4 = new int[6].unique;
    assert(t4.length == 6);
    assert(t4[0] == 0);
    assert(t4[0..3] == [0, 0, 0]);

    // not implicitly copyable
    assert(!__traits(compiles, t1 = t2));
    assert(!__traits(compiles, t3 = t4));
    assert(!__traits(compiles, Test.test(t1)));

    // movable
    assert(__traits(compiles, t1 = move(t2)));
    assert(__traits(compiles, t3 = move(t4)));
    assert(__traits(compiles, t1 = Test.test(move(t1))));

    // releasable
    assert(__traits(compiles, {int[] a = t3.rel();}));
    assert(__traits(compiles, {immutable(int)[] a = t3.irel();}));
    assert(__traits(compiles, {immutable(int[]) a = t3.irel();}));
    assert(__traits(compiles, {const(int)[] a = t3.irel();}));
    assert(__traits(compiles, {const(int[]) a = t3.irel();}));

    // UniquePackage works as expected
    import std.stdio;
    auto p1 = t1.pack;
    auto t5 = p1.unpack;
    assert(t5.test == 5);

    // sendable via packaging
    static void func()
    {
        receive(
            (UniquePackage!(int[]) up) => assert(up.unpack.length == 5),
            (UniquePackage!(Test) up) => assert(up.unpack.test == 5)
            );
    }
    auto tid = spawn(&func);
    assert(!__traits(compiles, tid.send(t3)));
    assert(!__traits(compiles, tid.send(t4)));
    tid.send(t3.pack);
    tid.send(t4.pack);
}
