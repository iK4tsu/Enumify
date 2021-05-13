module source.enumify;

struct Member(Args ...) {}

mixin template enumify() {
	struct __udaHelper {}
	private @disable this();

	import std.meta : AliasSeq, Filter;
	import std.string : toLower;
	import std.traits : getUDAs, isExpressions, isType, TemplateArgsOf;
	import std.typecons : Tuple, tuple;

	public import sumtype;

	// generate members
	static foreach (attr; getUDAs!(__udaHelper, Member))
	{
		static if (TemplateArgsOf!attr.length == 1)
		{
			/*
			member without types
			Member("None")
			---
			struct none {}
			---
			*/

			// generate member struct with data storage info
			mixin(`private struct `, TemplateArgsOf!attr[0].toLower(), `{
				version(D_BetterC) {} else
				string toString() {
					return "`, TemplateArgsOf!attr[0], `";
				}
			}`);

			// generate contructor for member
			mixin(`private this()(`, TemplateArgsOf!attr[0].toLower(), ` __payload) {
				handle = __payload;
			}`);

			// generate static function for member initialization
			mixin(`public static `, typeof(this).stringof, ` `,
				TemplateArgsOf!attr[0], `()
			{
					return typeof(return)(`, TemplateArgsOf!attr[0].toLower(), `());
			}`);
		}
		else static if (TemplateArgsOf!attr.length == 2)
		{
			/*
			only one type
			Member("Some", T)
			---
			private struct some {
				T handle;
				alias handle this;

				string toString() {
					import std.conv : to;
					return "Some("~handle.to!string~")";
				}
			}
			---
			*/

			mixin(`private struct `, TemplateArgsOf!attr[0].toLower(), ` {
				`, TemplateArgsOf!attr[1].stringof, ` handle;
				alias handle this;

				version(D_BetterC) {} else
				string toString() {
					import std.conv : to;
					return "`, TemplateArgsOf!attr[0], `("~handle.to!string~")";
				}
			}`);

			// generate contructor for member
			mixin(`private this(`, TemplateArgsOf!attr[0].toLower(), ` __payload) {
				handle = __payload;
			}`);

			// generate static function for member initialization
			mixin(`public static `, typeof(this).stringof, ` `,
				TemplateArgsOf!attr[0], `(AliasSeq!`, Filter!(isType, TemplateArgsOf!attr).stringof, ` t)
			{
					return typeof(return)(`, TemplateArgsOf!attr[0].toLower(), `(t));
			}`);
		}
		else static if(TemplateArgsOf!attr.length == 3 && isExpressions!(TemplateArgsOf!attr[2]))
		{
			/*
			named type
			Member("Some", T, "value")
			---
			private struct some {
				T value;
				alias value this;

				string toString() {
					import std.conv : to;
					return "Some("~value.to!string~")";
				}
			}
			---
			*/

			mixin(`private struct `, TemplateArgsOf!attr[0].toLower(), ` {
				`, TemplateArgsOf!attr[1].stringof, ` `, TemplateArgsOf!attr[2], `;
				alias `, TemplateArgsOf!attr[2], ` this;

				version(D_BetterC) {} else
				string toString() {
					import std.conv : to;
					return "`, TemplateArgsOf!attr[0], `("~`, TemplateArgsOf!attr[2], `.to!string~")";
				}
			}`);

			// generate contructor for member
			mixin(`private this(`, TemplateArgsOf!attr[0].toLower(), ` __payload) {
				handle = __payload;
			}`);

			// generate static function for member initialization
			mixin(`public static `, typeof(this).stringof, ` `,
				TemplateArgsOf!attr[0], `(AliasSeq!`, Filter!(isType, TemplateArgsOf!attr).stringof, `t)
			{
					return typeof(return)(`, TemplateArgsOf!attr[0].toLower(), `(t));
			}`);
		}
		else
		{
			/*
			multiple types and names
			Member("Some", T, U)
			---
			private struct some {
				Tuple!(T, U) handle;
				alias handle this;

				version(D_BetterC) {} else
				string toString() {
					import std.conv : to;
					return format!"Some%s(%(%s,%))"(handle.map!(to!string));
				}
			}
			---
			*/

			mixin(`private struct `, TemplateArgsOf!attr[0].toLower(), ` {
				`, Tuple!(TemplateArgsOf!attr[1 .. $]).stringof, ` handle;
				alias handle this;

				version(D_BetterC) {} else
				string toString() {
					import std.conv : to;
					import std.format : format;
					import std.range : iota;
					return format!"`, TemplateArgsOf!attr[0], `(%-(%s, %))"(mixin(
						format!"[%(handle[%s].to!string%|, %)]"(handle.length.iota)
					));
				}
			}`);

			// generate contructor for member
			mixin(`private this(`, TemplateArgsOf!attr[0].toLower(), ` __payload) {
				handle = __payload;
			}`);

			// generate static function for member initialization
			mixin(`public static `, typeof(this).stringof, ` `,
				TemplateArgsOf!attr[0], `(AliasSeq!`, Filter!(isType, TemplateArgsOf!attr).stringof, `t)
			{
					return typeof(return)(`, TemplateArgsOf!attr[0].toLower(), `(`,
						Tuple!(TemplateArgsOf!attr[1 .. $]).stringof,`(t)));
			}`);
		}
	}

	// generate SumType
	mixin("SumType!(", {
		string str;
		static foreach (attr; getUDAs!(__udaHelper, Member)) {
			str ~= TemplateArgsOf!attr[0].toLower() ~ ",";
		}
		return str;
	}(), ") handle;");
}

unittest {
	/*
	Similar to Rust's:
	enum Message {
		Move { x: i32, y: i32 },
		Echo(String),
		ChangeColor(u32, u32, u32),
		Quit,
	}
	*/
	static struct Message {
		@Member!("Move", int, "x", int, "y")
		@Member!("Echo", string)
		@Member!("ChangeColor", uint, uint, uint)
		@Member!("Quit")
		mixin enumify;

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

@safe pure unittest {
	/*
	Similar to Rust's:
	enum Message {
		Move { x: i32, y: i32 },
		Echo(String),
		ChangeColor(u32, u32, u32),
		Quit,
	}
	*/
	static struct Option(T) {
		@Member!("Some", T)
		@Member!("None")
		mixin enumify;

		string toString() {
			import std.conv : to;
			return handle.to!string();
		}

		bool isSome() {
			import sumtype;
			return handle.match!(
				(some _) => true,
				(none _) => false,
			);
		}

		T unwrap() {
			import sumtype;
			import std.conv;
			return handle.match!(
				(some t) => t.handle,
				delegate T (none _) { assert(false, text("Failed to unwrap ", typeof(this).stringof, " with value", handle.to!string, "!")); },
			);
		}
	}

	assert( Option!int.Some(3).isSome());
	assert(!Option!int.None.isSome());
	assert( Option!int.Some(3).unwrap() == 3);
}
