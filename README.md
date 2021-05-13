# Enumify
A simple tool for generating dynamic 'enums' in D

## Example

```d
/*
Similar to Rust's:
enum Message {
    Move { x: i32, y: i32 },
    Echo(String),
    ChangeColor(u32, u32, u32),
    Quit,
}
*/
struct Message {
    @Member!("Move", int, "x", int, "y")
    @Member!("Echo", string)
    @Member!("ChangeColor", uint, uint, uint)
    @Member!("Quit")
    mixin enumify;

    /*
    members generate to:
    * public <name (original)> static functions
    * private <name (lower)> structs with data types
    * private contructors for each member
    * private SumType!(<structs>) handle
    * disables the default constructor
    */


    string toString() {
        import std.conv : to;
        return handle.to!string();
    }

    void call() {
        import sumtype;
        import std.conv : to;
        import std.format : format;
        import std.stdio;
        handle.match!(
            (move m)        { assert(toString() == format!"Move(%s, %s)"(m.x, m.y)); },
            (echo e)        { assert(toString() == format!"Echo(%s)"(e.handle)); },
            (changecolor c) { assert(toString() == format!"ChangeColor(%s, %s, %s)"(c[0], c[1], c[2])); },
            (quit q)        { assert(toString() == "Quit"); },
        );
    };
}

unittest
{
    Message[] messages = [
        Message.Move(10, 30),
        Message.Echo("Hello enumify!"),
        Message.ChangeColor(255, 255, 255),
        Message.Quit,
    ];

    foreach (ref m; messages) m.call();

    assert(!__traits(compiles, { Message m; }));
    assert((messages[1] = Message.Move(15, 20)) == Message.Move(15, 20));
    assert((messages[1] = Message.Quit) == Message.Quit);
}
```

## Code generation
```d
struct Option(T)
{
    @Member("Some", T)
    @Member("None")
    mixin enumify;
}
```

The above will generate the following:
```d
struct Option(T)
{
    public static Option!T Some(T t)
    {
        return Option!T(some(t));
    }

    private this(some payload)
    {
        handle = payload;
    }

    private struct some
    {
        T handle;
        alias handle this;

        version(D_BetterC) {} else
        string toString()
        {
            import std.conv : to;
            return "Some(" ~ handle.to!string ~ ")";
        }
    }


    public static Option!T None()
    {
        return Option!T(none());
    }

    private this(none payload)
    {
        handle = payload;
    }

    private struct none
    {
        string toString()
        {
            return "None";
        }
    }


    private SumType!(some, none) handle;
}
