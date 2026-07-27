# Developing Extensions

!!! warning "Internal API"
    This documents internal interfaces not covered by semantic versioning.
    These APIs may change between any versions without notice.

This page documents how to create custom parsing rules for CommonMark.jl.
An extension consists of three parts: AST node types, parsing rules, and
writer functions.

```@example dev
using CommonMark
nothing # hide
```

## AST Nodes

### Type Hierarchy

All node types inherit from `AbstractContainer`:

```julia
abstract type AbstractContainer end
abstract type AbstractBlock <: AbstractContainer end   # Block-level elements
abstract type AbstractInline <: AbstractContainer end  # Inline elements
```

Define your node type as a struct:

```julia
struct MyBlock <: AbstractBlock
    info::String  # Store any data your extension needs
end

struct MyInline <: AbstractInline end
```

### The Node Struct

Nodes wrap your container type in a tree structure:

```julia
mutable struct Node
    t::AbstractContainer      # Your container type (MyBlock, MyInline, etc.)
    parent::Node              # Parent node
    first_child::Node         # First child
    last_child::Node          # Last child
    prv::Node                 # Previous sibling
    nxt::Node                 # Next sibling
    sourcepos::SourcePos      # Source position ((start_line, start_col), (end_line, end_col))
    literal::String           # Text content (for leaf nodes)
    meta::Dict{String,Any}    # Arbitrary metadata
end
```

Use `isnull(node)` to check for null references (rather than checking against `nothing`).

### Container Behavior Methods

Define these methods to control how your node participates in parsing:

```julia
# Can this node contain children? Default: false
is_container(::MyBlock) = true

# Does this block accept raw text lines? (like code blocks)
accepts_lines(::MyBlock) = false

# Which child types are allowed? Default allows most types.
can_contain(::MyBlock, child) = !(child isa Item)

# Called when the block is closed. Default: nothing
finalize(::MyBlock, parser::Parser, node::Node) = nothing

# Called to check if this block continues on the next line.
# Return: 0 = continue, 1 = close block, 2 = close and skip line
function continue_(::MyBlock, parser::Parser, node::Node)
    if parser.indent >= 4
        advance_offset(parser, 4, true)
        return 0  # Continue this block
    elseif parser.blank
        advance_next_nonspace(parser)
        return 0
    else
        return 1  # Close this block
    end
end
```

## Rule Interface

### The Rule Struct

Rules wrap parsing functions with metadata:

```julia
struct Rule
    fn::Function       # The parsing function
    priority::Float64  # Lower priority runs first
    triggers::String   # Trigger characters (empty = all positions)
end

Rule(fn, priority, triggers = "")
```

Create rules with do-block syntax:

```julia
block_rule(::MyRule) = Rule(0.5, "!") do parser, container
    # Parse logic here
    return 0
end
```

### Rule Hooks

Define these methods on your rule type to register parsing functions:

| Hook | Purpose | Signature |
|------|---------|-----------|
| `block_rule` | Parse block-level syntax | `(parser, container) → 0/1/2` |
| `inline_rule` | Parse inline syntax | `(parser, block) → Bool` |
| `block_modifier` | Transform blocks after parsing | `(parser, block) → nothing` |
| `inline_modifier` | Transform inlines after parsing | `(parser, block) → nothing` |

All hooks return `nothing` by default (no rule registered).

### Block Rule Return Values

| Value | Meaning |
|-------|---------|
| 0 | No match |
| 1 | Matched container (keeps parsing children) |
| 2 | Matched leaf block (stops block parsing) |

### Inline Rule Return Values

| Value | Meaning |
|-------|---------|
| `false` | No match, try next rule |
| `true` | Matched and consumed input |

### Delimiter Hooks

For emphasis-like syntax (paired delimiters like `~~text~~`), use these hooks
instead of writing custom inline parsing:

```julia
# Map (character, count) to node type
delim_nodes(::MyRule) = Dict(('~', 2) => Strikethrough)

# Define flanking behavior: :standard, :underscore, or :permissive
flanking_rule(::MyRule) = ('~', :standard)

# Optional: characters that use odd-match logic
uses_odd_match(::MyRule) = '~'
```

When using delimiter hooks, your `inline_rule` should call `handle_delim`:

```julia
inline_rule(::MyRule) = Rule(1, "~") do parser, block
    handle_delim(parser, '~', block)
end
inline_modifier(::MyRule) = Rule(process_emphasis, 1)
```

### Claimed Syntax

A rule that gives meaning to a spelling the core spec reads as plain text has
that spelling escaped in the Markdown the writer produces, so a document written
out and parsed again with the same rules gives back the same tree. The parser
collects the claims of every enabled rule into the `Document` node's
`claimed_syntax` and `claimed_line_syntax` fields.

By default a rule claims the characters its own parsers trigger on, so a rule
written without a thought for the writer still survives a reparse. Declaring
`claimed_syntax` narrows that to the spellings the rule actually reads:

```julia
claimed_syntax(::MyRule) = ["=="]
```

The narrower claim is the difference between escaping every `=` in the document
and escaping only those followed by another `=`. A rule that reuses syntax the
core spec already reads as markup, such as `FootnoteRule`'s `[`, can declare
`String[]`: the writer escapes that syntax regardless.

Where a rule reads only blocks, its claims are escaped where a line's content
starts and left alone anywhere else, since that is the only place the rule would
read them back. `DefinitionListRule` claims `": "` without escaping the colon in
the middle of a sentence.

A rule whose claims depend on how it was constructed builds the list at call
time. `TypographyRule` returns only the spellings its options turned on:

```julia
function claimed_syntax(tr::TypographyRule)
    claims = String[]
    tr.double_quotes && push!(claims, "\"")
    tr.single_quotes && push!(claims, "'")
    tr.ellipses && push!(claims, "...")
    tr.dashes && push!(claims, "--")
    return claims
end
```

## Writer Functions

### Signature

Implement a writer for each output format:

```julia
function write_html(::MyBlock, renderer, node, enter)
    if enter
        tag(renderer, "div", attributes(renderer, node, ["class" => "my-block"]))
    else
        tag(renderer, "/div")
    end
end
```

The `enter` parameter is `true` when entering the node, `false` when leaving.
This allows generating opening/closing tags for containers.

### Required Writers

| Function | Output Format |
|----------|--------------|
| `write_html` | HTML |
| `write_latex` | LaTeX |
| `write_typst` | Typst |
| `write_term` | Terminal (ANSI) |
| `write_markdown` | Markdown (roundtrip) |
| `write_json` | Pandoc AST JSON |

### Writer Utilities

**HTML:**
- `tag(w, name, attrs=[])` - emit HTML tag
- `attributes(w, node, extra=[])` - format attributes from node.meta

**All formats:**
- `literal(w, str...)` - emit raw text
- `cr(w)` - conditional newline (if not at line start)
- `print(w.buffer, str)` - direct buffer access

**Terminal/Markdown:**
- `push_margin!(w, prefix)` - add indentation prefix
- `pop_margin!(w)` - remove indentation prefix
- `print_margin(w)` - emit current margin

**Markdown:**
- `content(w, str)` - emit text content, escaped so it reparses as text
- `push_verbatim!(w)` / `pop_verbatim!(w)` - suspend and restore escaping around a range

**Terminal:**
- `print_literal(w, crayon, text, inv(crayon))` - styled output

### Escaping in the Markdown Writer

The Markdown writer has to produce a document that parses back to the tree it
came from, so text content and markup are written through different calls.

Use `content` for a node's text content, the characters the parser read as text
rather than as markup. The core writer calls it for `Text`; a rule with its own
text-bearing inline node calls it too. `literal` is for markup the writer itself
constructs: fences, list markers, emphasis delimiters, the `??? ` of the spoiler
block above. Text passed to `literal` is never escaped, so a `*` in it opens
emphasis on the next parse.

Escaping runs once over the whole document after every node has been written,
because whether a character needs an escape depends on the characters either
side of it. `content` records the span it wrote rather than escaping in place,
so nothing in the writer sees the escaped form.

A node that has more than one spelling picks one by reading the node: whether a
link's text repeats its destination, whether a heading holds a break, whether a
code block would be swallowed by the block before it. Each is a function of the
node alone, so the entering and exiting halves of a writer each work it out
rather than one stashing the answer for the other.

Wrap a range in `push_verbatim!` and `pop_verbatim!` when it has to reparse
exactly as written and an escape would change its meaning. `ReferenceLinkRule`
does this for a shortcut or collapsed link's text, which doubles as the label
matched against the definition:

```julia
function write_markdown(ref::MyReference, w, node, ent)
    if ent
        literal(w, "[")
        push_verbatim!(w)
    else
        literal(w, "]")
        pop_verbatim!(w)
    end
    return nothing
end
```

Verbatim ranges nest, so a rule can wrap a range that already sits inside one.

## Parser State

Key parser fields available during block parsing:

```julia
parser.indent            # Current indentation level
parser.indented          # Is line indented >= 4 spaces?
parser.blank             # Is current line blank?
parser.next_nonspace     # Position of next non-whitespace
parser.line_number       # Current line number

# Utility functions
rest_from_nonspace(parser)      # Get remaining line from next non-space
advance_offset(parser, n, cols) # Advance position by n chars
advance_next_nonspace(parser)   # Move to next non-space
advance_to_end(parser)          # Consume rest of line
close_unmatched_blocks(parser)  # Finalize pending blocks
add_child(parser, type, offset) # Create new child node
```

For inline parsing:

```julia
trypeek(parser, Char)           # Peek current character
consume(parser, match)          # Consume regex match
append_child(block, node)       # Add inline child
```

## Registration

Enable your rule with `enable!`:

```julia
parser = Parser()
enable!(parser, MyRule())
```

Rules can be disabled with `disable!`:

```julia
disable!(parser, SetextHeadingRule())  # Only allow ATX headings
```

## Example: Highlight (Inline)

A custom inline extension using delimiter hooks for `==highlighted text==` syntax.

!!! note "Built-in Alternative"
    This syntax is available as [`MarkRule`](@ref extensions-page). This example shows how such an extension is implemented.

```@example dev
# AST node
struct Highlight <: CommonMark.AbstractInline end
CommonMark.is_container(::Highlight) = true

# Rule type
struct HighlightRule end

# Use delimiter infrastructure for ==text== parsing
CommonMark.inline_rule(::HighlightRule) = CommonMark.Rule(1, "=") do parser, block
    CommonMark.handle_delim(parser, '=', block)
end
CommonMark.inline_modifier(::HighlightRule) = CommonMark.Rule(CommonMark.process_emphasis, 1)
CommonMark.delim_nodes(::HighlightRule) = Dict(('=', 2) => Highlight)
CommonMark.flanking_rule(::HighlightRule) = ('=', :standard)

# Without this the rule claims its trigger, escaping every `=` in the document.
# Naming the pair escapes only an `=` that another `=` follows.
CommonMark.claimed_syntax(::HighlightRule) = ["=="]

# Writers
CommonMark.write_html(::Highlight, r, n, ent) =
    CommonMark.tag(r, ent ? "mark" : "/mark", ent ? CommonMark.attributes(r, n) : [])

CommonMark.write_latex(::Highlight, w, n, ent) =
    print(w.buffer, ent ? "\\hl{" : "}")

CommonMark.write_term(::Highlight, w, n, ent) = nothing  # No terminal styling

CommonMark.write_markdown(::Highlight, w, n, ent) = CommonMark.literal(w, "==")
nothing # hide
```

Usage:

```@example dev
parser = Parser()
enable!(parser, HighlightRule())
ast = parser("Some ==highlighted text== here.")
html(ast)
```

## Example: Spoiler Block

A custom block extension for spoiler/collapsible content using `??? title` syntax.

```@example dev
# AST node with title field
struct Spoiler <: CommonMark.AbstractBlock
    title::String
end

# Container behavior
CommonMark.is_container(::Spoiler) = true
CommonMark.accepts_lines(::Spoiler) = false
CommonMark.can_contain(::Spoiler, t) = !(t isa CommonMark.Item)
CommonMark.finalize(::Spoiler, ::CommonMark.Parser, ::CommonMark.Node) = nothing

# Continue if indented by 4 spaces or blank
function CommonMark.continue_(::Spoiler, parser::CommonMark.Parser, ::CommonMark.Node)
    if parser.indent >= 4
        CommonMark.advance_offset(parser, 4, true)
        return 0  # Continue
    elseif parser.blank
        CommonMark.advance_next_nonspace(parser)
        return 0
    else
        return 1  # Close
    end
end

# Rule type
struct SpoilerRule end

# Block parsing function
CommonMark.block_rule(::SpoilerRule) = CommonMark.Rule(0.5, "?") do parser, container
    if !parser.indented
        ln = CommonMark.rest_from_nonspace(parser)
        m = match(r"^\?\?\? (.+)$", ln)
        if m !== nothing
            CommonMark.close_unmatched_blocks(parser)
            CommonMark.add_child(parser, Spoiler(m[1]), parser.next_nonspace)
            CommonMark.advance_to_end(parser)
            return 1  # Container block
        end
    end
    return 0
end

# Writers
function CommonMark.write_html(s::Spoiler, rend, node, enter)
    if enter
        CommonMark.tag(rend, "details", CommonMark.attributes(rend, node))
        CommonMark.tag(rend, "summary")
        print(rend.buffer, s.title)
        CommonMark.tag(rend, "/summary")
    else
        CommonMark.tag(rend, "/details")
    end
end

CommonMark.write_latex(s::Spoiler, w, n, ent) =
    CommonMark.literal(w, ent ? "\\begin{spoiler}{$(s.title)}\n" : "\\end{spoiler}\n")

CommonMark.write_term(::Spoiler, w, n, ent) = nothing

function CommonMark.write_markdown(s::Spoiler, w, node, ent)
    if ent
        CommonMark.push_margin!(w, "    ")
        CommonMark.literal(w, "??? ", s.title, "\n")
        CommonMark.print_margin(w)
        CommonMark.literal(w, "\n")
    else
        CommonMark.pop_margin!(w)
        CommonMark.cr(w)
    end
end
nothing # hide
```

Usage:

```@example dev
parser = Parser()
enable!(parser, SpoilerRule())
ast = parser("""
??? Click to reveal
    This content is hidden by default.
    It can contain **formatted** text.
""")
html(ast)
```

## Extension Patterns

### Block Modifier

Transform existing nodes without custom parsing. Useful for detecting patterns
in parsed content:

```julia
block_modifier(::MyRule) = Rule(50) do parser, block
    if block.t isa Paragraph
        # Check content and transform if needed
        m = match(r"^pattern", block.literal)
        if m !== nothing
            block.t = MyCustomType()
        end
    end
end
```

See `GitHubAlertRule` and `TaskListRule` for examples.

### Stateful Rules

Store state during parsing for cross-referencing:

```julia
struct FootnoteRule
    cache::Dict{String,Node}
    FootnoteRule() = new(Dict())
end

block_rule(fr::FootnoteRule) = Rule(0.5, "[") do parser, container
    # Store definitions in cache
    fr.cache[id] = node
end

inline_rule(fr::FootnoteRule) = Rule(0.5, "[") do parser, block
    # Reference cache to link footnotes
    def = get(fr.cache, id, nothing)
end
```
