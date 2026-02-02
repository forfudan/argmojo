# ArgMojo — overal planning

> A command-line argument parser library for Mojo, inspired by Rust's clap.

## 1. Why ArgMojo?

I created this project to support my experiments with a CLI-based Chinese character search engine in Mojo, as well as a CLI-based calculator for [DeciMojo](https://github.com/forfudan/decimojo).

At the moment, Mojo does not have a mature command-line argument parsing library. This is a fundamental component for any CLI tool, and building it from scratch will benefit my projects and future projects.

## 2. Technical Foundations

### 2.1 `sys.argv()` ✓ Available

Mojo provides `sys.argv()` to access command-line arguments:

```mojo
from sys import argv

fn main():
    var args = argv()
    for i in range(len(args)):
        print("arg[", i, "] =", args[i])
```

```bash
$ mojo run main.mojo foo --bar -b value
arg[ 0 ] = main.mojo
arg[ 1 ] = foo
arg[ 2 ] = --bar
arg[ 3 ] = -b
arg[ 4 ] = value
```

This gives us the raw list of argument strings, and the remaining task is to implement the parsing logic.

### 2.2 Mojo's string operations ✓ Sufficient

Required string operations:

| Operation      | Mojo Support           | Description |
| -------------- | ---------------------- | ----------- |
| Prefix check   | `str.startswith("--")` | ✓           |
| String compare | `str == "value"`       | ✓           |
| Substring      | Slicing / `find`       | ✓           |
| Split          | `str.split("=")`       | ✓           |
| Concatenation  | `str + str`            | ✓           |

### 2.3 Mojo's data structures ✓ Sufficient

| Structure           | Purpose                      | Description     |
| ------------------- | ---------------------------- | --------------- |
| `List[String]`      | Store argument list          | ✓               |
| `Dict[String, ...]` | Map argument names to values | ✓               |
| `struct`            | Define Arg/Parser types      | ✓               |
| `Variant`           | Polymorphic argument values  | ✓ (or use enum) |

## 3. Design Plan

### 3.1 Reference: Core Concepts from Rust's clap

| clap Concept | Description                     | ArgMojo Correspondence               |
| ------------ | ------------------------------- | ------------------------------------ |
| `Arg`        | Definition of a single argument | `Arg` struct                         |
| `Command`    | Command/Subcommand              | `Command` struct                     |
| `ArgMatches` | Parsing result                  | `ParseResult` struct                 |
| Builder API  | Chainable argument construction | Method chaining (Mojo supports)      |
| Derive API   | Macro-based generation          | ✗ Mojo currently has no macro system |

### 3.2 Core API Design

```mojo
from argmojo import Command, Arg

fn main() raises:
    var cmd = Command("sou", "A CJK-aware text search tool")

    # 位置參數
    cmd.add_arg(
        Arg("pattern", help="Search pattern")
            .required()
            .positional()
    )
    cmd.add_arg(
        Arg("path", help="Search path")
            .positional()
            .default(".")
    )

    # 可選參數
    cmd.add_arg(
        Arg("ling", help="Use Yuho Lingming encoding")
            .long("ling")
            .short("l")
            .flag()  # 布爾旗標，無需值
    )
    cmd.add_arg(
        Arg("ignore-case", help="Case insensitive search")
            .long("ignore-case")
            .short("i")
            .flag()
    )
    cmd.add_arg(
        Arg("max-depth", help="Maximum directory depth")
            .long("max-depth")
            .short("d")
            .takes_value()
    )

    # 解析
    var result = cmd.parse()

    # 使用結果
    var pattern = result.get_string("pattern")
    var path = result.get_string("path")
    var use_ling = result.get_flag("ling")
    var max_depth = result.get_int("max-depth")
```

### 3.3 Command-line syntax support

```bash
# 長選項
--flag              # 布爾旗標
--key value         # 鍵值（空格分隔）
--key=value         # 鍵值（等號分隔）

# 短選項
-f                  # 布爾旗標
-k value            # 鍵值
-abc                # 多個短旗標合併 (= -a -b -c)  [Phase 2]

# 位置參數
pattern             # 第一個位置參數
path                # 第二個位置參數

# 特殊
--                  # 停止解析選項，之後全視為位置參數
--help / -h         # 自動生成幫助信息
--version / -V      # 版本信息
```

## 4. Repository Structure

```txt
src/
└── sou/
    └── cli/
        ├── __init__.mojo
        ├── arg.mojo        # Arg struct — 參數定義
        ├── command.mojo     # Command struct — 命令定義與解析
        └── result.mojo      # ParseResult struct — 解析結果
```

### 4.1 Core struct design

```mojo
# --- arg.mojo ---

@value
struct Arg(Stringable):
    """定義一個命令行參數。"""
    var name: String           # 內部名稱
    var help: String           # 幫助文本
    var long_name: String      # --long-name
    var short_name: String     # -s
    var is_flag: Bool          # 是否為布爾旗標
    var is_required: Bool      # 是否必須
    var is_positional: Bool    # 是否為位置參數
    var default_value: String  # 默認值
    var has_default: Bool      # 是否有默認值

    fn __init__(out self, name: String, *, help: String = ""):
        self.name = name
        self.help = help
        self.long_name = ""
        self.short_name = ""
        self.is_flag = False
        self.is_required = False
        self.is_positional = False
        self.default_value = ""
        self.has_default = False

    fn long(var self, name: String) -> Self:
        self.long_name = name
        return self^

    fn short(var self, name: String) -> Self:
        self.short_name = name
        return self^

    fn flag(var self) -> Self:
        self.is_flag = True
        return self^

    fn required(var self) -> Self:
        self.is_required = True
        return self^

    fn positional(var self) -> Self:
        self.is_positional = True
        return self^

    fn default(var self, value: String) -> Self:
        self.default_value = value
        self.has_default = True
        return self^
```

```mojo
# --- result.mojo ---

struct ParseResult:
    """存儲解析後的參數結果。"""
    var flags: Dict[String, Bool]
    var values: Dict[String, String]
    var positionals: List[String]

    fn get_flag(self, name: String) -> Bool:
        """獲取旗標值，默認 False。"""
        ...

    fn get_string(self, name: String) raises -> String:
        """獲取字符串值。"""
        ...

    fn get_int(self, name: String) raises -> Int:
        """獲取整數值。"""
        ...

    fn has(self, name: String) -> Bool:
        """檢查參數是否存在。"""
        ...
```

### 4.2 Parsing Algorithm

```txt
Input: ["sou", "zhong", "./src", "--ling", "-i", "--max-depth", "3"]

1. Skip argv[0] (program name)
2. Initialize cursor i = 1
3. Loop:
   ├─ If args[i] == "--":
   │     Everything after is treated as positional arguments, break
   ├─ If args[i].startswith("--"):
   │     Parse long option
   │     ├─ If contains "=": split into key=value
   │     ├─ If flag: set to True
   │     └─ Otherwise: take args[i+1] as value, i += 1
   ├─ If args[i].startswith("-"):
   │     Parse short option (same logic)
   └─ Otherwise:
         Treat as positional argument
4. Validate: check if required arguments are present
5. Return ParseResult
```

## 5. Feasibility Assessment

### ✓ Fully Feasible Parts

| Feature                            | Reason                                          |
| ---------------------------------- | ----------------------------------------------- |
| Basic parsing (long/short options) | Pure string operations, fully supported by Mojo |
| Positional arguments               | Simple index logic                              |
| Flags                              | Bool value storage                              |
| Key-value arguments                | String value storage                            |
| Help text generation               | String concatenation                            |
| Builder pattern                    | Mojo supports `var self` for chaining           |
| `--` stop marker                   | Standard parsing logic                          |

### ⚠️ Parts to Watch Out For

| Feature             | Challenge                                     | Mitigation                                      |
| ------------------- | --------------------------------------------- | ----------------------------------------------- |
| Method chaining     | Mojo's ownership semantics require `var self` | Confirmed feasible                              |
| Generic value types | Arg values could be String/Int/Bool           | Store as String initially, convert on retrieval |
| Error handling      | Missing/invalid arguments                     | Use `raises` + descriptive error messages       |
| Subcommands         | Nested commands (e.g., `git commit`)          | Phase 2, not implemented initially              |

### ✗ Temporarily Infeasible Parts

| Feature                                | Reason                            |
| -------------------------------------- | --------------------------------- |
| Derive macro（similar to clap derive） | Mojo does not have a macro system |
| Auto-completion                        | Need shell integration, later     |
| Environment variable fallback          | Can be implemented later          |

## 6. Comparison with Rust clap

| clap (Rust)                      | ArgMojo (Mojo)                   | Plan              |
| -------------------------------- | -------------------------------- | ----------------- |
| Builder API         ✓            | Builder API          ✓           |                   |
| Derive API          ✓            | Derive API           ✗           | (no macros)       |
| Subcommands          ✓           | Subcommands          ?           | Phase 2           |
| Value validation     ✓           | Value validation     ?           | Phase 2           |
| Auto-completion      ✓           | Auto-completion      ✗           | Not implemented   |
| Colored error output  ✓          | Colored error output ?           | (depends on mist) |
| Environment variable fallback  ✓ | Environment variable fallback  ? | Phase 2           |
| Default values       ✓           | Default values       ✓           |                   |
| Help text generation ✓           | Help text generation ✓           |                   |

## 7. Development Plan

### Phase 0: Skeleton

- [ ] Establish module structure
- [ ] Implement `Arg` struct and builder methods
- [ ] Implement basic `Command` struct
- [ ] Iimplement a small demo CLI tool to test the library

### Phase 1: Core Parsing (2-3 days)

- [ ] Parse long options `--flag`, `--key value`, `--key=value`
- [ ] Parse short options `-f`, `-k value`
- [ ] Parse positional arguments
- [ ] `ParseResult` query API
- [ ] Basic error handling

### Phase 2: Enhancement (3-5 days)

- [ ] Auto `--help` / `-h` generation
- [ ] Short option merging `-abc`
- [ ] `--` stop marker
- [ ] Required argument validation
- [ ] Optional default values

### Phase 3: Advanced (Optional)

- [ ] Subcommand support
- [ ] Value validation (numeric ranges, enums, etc.)
- [ ] Colored error output (with mist)

## 8. Testing Strategy

```mojo
# test_cli.mojo

fn test_basic_flag():
    var cmd = Command("test", "")
    cmd.add_arg(Arg("verbose").long("verbose").short("v").flag())

    # simulate argv
    var args = List[String]("test", "--verbose")
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("verbose"))

fn test_key_value():
    var cmd = Command("test", "")
    cmd.add_arg(Arg("output").long("output").short("o").takes_value())

    var args = List[String]("test", "--output", "file.txt")
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")

fn test_positional():
    var cmd = Command("test", "")
    cmd.add_arg(Arg("pattern").positional().required())
    cmd.add_arg(Arg("path").positional().default("."))

    var args = List[String]("test", "hello", "./src")
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("pattern"), "hello")
    assert_equal(result.get_string("path"), "./src")
```
