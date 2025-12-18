const CODE_INDENT = 4

const reHtmlBlockOpen = [
    r"^<(?:script|pre|textarea|style)(?:\s|>|$)"i,
    r"^<!--",
    r"^<[?]",
    r"^<![A-Z]",
    r"^<!\[CDATA\[",
    r"^<[/]?(?:address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h[123456]|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|section|source|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul)(?:\s|[/]?[>]|$)"i,
    Regex("^(?:$(OPENTAG)|$(CLOSETAG))\\s*\$", "i"),
]
const reHtmlBlockClose =
    [r"<\/(?:script|pre|textarea|style)>"i, r"-->", r"\?>", r">", r"\]\]>"]
const reThematicBreak = r"^(?:(?:\*[ \t]*){3,}|(?:_[ \t]*){3,}|(?:-[ \t]*){3,})[ \t]*$"
const reNonSpace = r"[^ \t\f\v\r\n]"
const reBulletListMarker = r"^[*+-]"
const reOrderedListMarker = r"^(\d{1,9})([.)])"
const reATXHeadingMarker = r"^#{1,6}(?:[ \t]+|$)"
const reCodeFence = r"^`{3,}(?!.*`)|^~{3,}"
const reClosingCodeFence = r"^(?:`{3,}|~{3,})(?= *$)"
const reSetextHeadingLine = r"^(?:=+|-+)[ \t]*$"
const reLineEnding = r"\r\n|\n|\r"
const EMPTY_FN_VEC = Function[]

"""
    Parser()

Create a CommonMark parser with default block and inline rules enabled.

The parser can be called directly on a string to produce an AST, which can then
be rendered to various output formats using [`html`](@ref), [`latex`](@ref),
[`term`](@ref), [`markdown`](@ref), [`notebook`](@ref), or [`typst`](@ref).

# Examples

```julia
p = Parser()
ast = p("# Hello\\n\\nWorld")
html(ast)  # "<h1>Hello</h1>\\n<p>World</p>\\n"
```

Use [`enable!`](@ref) and [`disable!`](@ref) to customize which rules are active.

```julia
p = Parser()
enable!(p, TableRule())
```
"""
mutable struct Parser <: AbstractParser
    doc::Node
    block_starts::Dict{Char,Vector{Function}}
    tip::Node
    oldtip::Node
    buf::String
    line_number::Int
    pos::Int
    len::Int
    column::Int
    next_nonspace::Int
    next_nonspace_column::Int
    indent::Int
    indented::Bool
    blank::Bool
    partially_consumed_tab::Bool
    all_closed::Bool
    last_matched_container::Node
    refmap::Dict{String,Tuple{String,String}}
    last_line_length::Int
    inline_parser::InlineParser
    rules::Vector{Any}
    modifiers::Vector{Function}
    typed_modifiers::Dict{DataType,Vector{Function}}
    priorities::IdDict{Function,Float64}

    function Parser()
        parser = new()
        parser.doc = Node(Document(), ((1, 1), (0, 0)))
        parser.block_starts = Dict()
        parser.tip = parser.doc
        parser.oldtip = parser.doc
        parser.buf = ""
        parser.line_number = 0
        parser.pos = 1
        parser.len = 0
        parser.column = 0
        parser.next_nonspace = 1
        parser.next_nonspace_column = 0
        parser.indent = 0
        parser.indented = false
        parser.blank = false
        parser.partially_consumed_tab = false
        parser.all_closed = true
        parser.last_matched_container = parser.doc
        parser.refmap = Dict()
        parser.last_line_length = 0
        parser.inline_parser = InlineParser()
        parser.rules = []
        parser.modifiers = Function[]
        parser.typed_modifiers = Dict{DataType,Vector{Function}}()
        parser.priorities = IdDict{Function,Float64}()

        # Enable the standard CommonMark rule set.
        enable!(parser, COMMONMARK_BLOCK_RULES)
        enable!(parser, COMMONMARK_INLINE_RULES)

        return parser
    end
end

Base.show(io::IO, parser::Parser) = print(io, "Parser($(parser.doc))")

is_blank(s::AbstractString) = !occursin(reNonSpace, s)

is_space_or_tab(s::AbstractString) = s in (" ", "\t")
is_space_or_tab(c::AbstractChar) = c in (' ', '\t')
is_space_or_tab(other) = false

function ends_with_blank_line(block::Node)
    while !isnull(block)
        if block.last_line_blank
            return true
        end
        if !block.last_line_checked && (block.t isa List || block.t isa Item)
            block.last_line_checked = true
            block = block.last_child
        else
            block.last_line_checked = true
            break
        end
    end
    return false
end

struct Document <: AbstractBlock end

is_container(::Document) = true
accepts_lines(::Document) = false
continue_(::Document, ::Parser, ::Node) = 0
finalize(::Document, ::Parser, ::Node) = nothing
can_contain(::Document, t) = !(t isa Item)

include("blocks/lists.jl")
include("blocks/blockquotes.jl")
include("blocks/headings.jl")
include("blocks/thematic_breaks.jl")
include("blocks/codeblocks.jl")
include("blocks/htmlblocks.jl")
include("blocks/paragraphs.jl")

# Block start functions.
#
# Return values
# 0 = no match
# 1 = matched container, keep going
# 2 = matched leaf, no more block starts

const COMMONMARK_BLOCK_RULES = [
    BlockQuoteRule(),
    AtxHeadingRule(),
    FencedCodeBlockRule(),
    HtmlBlockRule(),
    SetextHeadingRule(),
    ThematicBreakRule(),
    ListItemRule(),
    IndentedCodeBlockRule(),
]

function add_line(parser::Parser)
    node = parser.tip
    buf = node.literal_buffer
    if buf === nothing
        buf = node.literal_buffer = IOBuffer()
    end
    if parser.partially_consumed_tab
        parser.pos += 1
        chars_to_tab = 4 - (parser.column % 4)
        for _ = 1:chars_to_tab
            write(buf, ' ')
        end
    end
    write(buf, SubString(parser.buf, parser.pos))
    write(buf, '\n')
end

function add_child(parser::Parser, tag::AbstractContainer, offset::Integer)
    while !can_contain(parser.tip.t, tag)
        finalize(parser, parser.tip, parser.line_number - 1)
    end
    column_number = offset + 1
    new_block = Node(tag, ((parser.line_number, column_number), (0, 0)))
    append_child(parser.tip, new_block)
    parser.tip = new_block
    return new_block
end

function close_unmatched_blocks(parser::Parser)
    if !parser.all_closed
        while parser.oldtip !== parser.last_matched_container
            parent = parser.oldtip.parent
            finalize(parser, parser.oldtip, parser.line_number - 1)
            parser.oldtip = parent
        end
        parser.all_closed = true
    end
    return nothing
end

function find_next_nonspace(parser::Parser)
    buf = parser.buf
    i = parser.pos
    cols = parser.column

    c = get(buf, i, '\0')
    while c !== '\0'
        if c === ' '
            i += 1
            cols += 1
        elseif c === '\t'
            i += 1
            cols += (4 - (cols % 4))
        else
            break
        end
        c = get(buf, i, '\0')
    end
    parser.blank = c in ('\n', '\r', '\0')
    parser.next_nonspace = i
    parser.next_nonspace_column = cols
    parser.indent = parser.next_nonspace_column - parser.column
    parser.indented = parser.indent ≥ CODE_INDENT
end

function advance_next_nonspace(parser::Parser)
    parser.pos = parser.next_nonspace
    parser.column = parser.next_nonspace_column
    parser.partially_consumed_tab = false
end

function advance_offset(parser::Parser, count::Integer, columns::Bool)
    buf = parser.buf
    c = get(buf, parser.pos, '\0')
    while count > 0 && c !== '\0'
        if c === '\t'
            chars_to_tab = 4 - (parser.column % 4)
            if columns
                parser.partially_consumed_tab = chars_to_tab > count
                chars_to_advance = min(count, chars_to_tab)
                parser.column += chars_to_advance
                parser.pos += parser.partially_consumed_tab ? 0 : 1
                count -= chars_to_advance
            else
                parser.partially_consumed_tab = false
                parser.column += chars_to_tab
                parser.pos += 1
                count -= 1
            end
        else
            parser.partially_consumed_tab = false
            parser.pos = nextind(buf, parser.pos)
            # Assume ASCII; block starts are ASCII.
            parser.column += 1
            count -= 1
        end
        c = get(buf, parser.pos, '\0')
    end
end

advance_to_end(parser::Parser) = advance_offset(parser, typemax(Int), false)
rest_from_nonspace(p::Parser) = SubString(p.buf, p.next_nonspace)
peek_nonspace(p::Parser, default = '\0') = get(p.buf, p.next_nonspace, default)

function incorporate_line(parser::Parser, ln::AbstractString)
    all_matched = true

    container = parser.doc
    parser.oldtip = parser.tip
    parser.pos = 1
    parser.column = 0
    parser.blank = false
    parser.partially_consumed_tab = false
    parser.line_number += 1

    # Replace NUL characters for security.
    ln = ('\0' in ln) ? replace(ln, '\0' => '\uFFFD') : ln

    parser.buf = ln
    parser.len = length(ln)

    # For each containing block, try to parse the associated line start. Bail
    # out on failure: container will point to the last matching block. Set
    # all_matched to false if not all containers match.
    while true
        last_child = container.last_child
        (!isnull(last_child) && last_child.is_open) || break

        container = last_child

        find_next_nonspace(parser)

        rv = continue_(container.t, parser, container)::Int
        if rv == 0
            # Matched, keep going.
        elseif rv == 1
            # Failed to match a block.
            all_matched = false
        elseif rv == 2
            # Hit end of line for fenced code close and can return.
            parser.last_line_length = length(ln)
            return
        else
            # Shouldn't reach this location.
            error("continue_ returned illegal value, must be 0, 1, or 2")
        end

        if !all_matched
            # Back up to last matching block.
            container = container.parent
            break
        end
    end

    parser.all_closed = (container === parser.oldtip)
    parser.last_matched_container = container

    matched_leaf = !(container.t isa Paragraph) && accepts_lines(container.t)
    # Unless last matched container is a code block, try new container starts,
    # adding children to the last matched container.
    while !matched_leaf

        find_next_nonspace(parser)
        next_nonspace_char = get(ln, parser.next_nonspace, '\0')
        # This is a little performance optimization. Should not affect correctness.
        if !parser.indented && !haskey(parser.block_starts, next_nonspace_char)
            advance_next_nonspace(parser)
            break
        end
        found = false
        if haskey(parser.block_starts, next_nonspace_char)
            for λ in parser.block_starts[next_nonspace_char]
                res = λ(parser, container)
                if res === 1
                    found = true
                    container = parser.tip
                    break
                elseif res === 2
                    found = true
                    container = parser.tip
                    matched_leaf = true
                    break
                end
            end
        end
        if !found
            for λ in parser.block_starts['\0']
                res = λ(parser, container)
                if res === 1
                    found = true
                    container = parser.tip
                    break
                elseif res === 2
                    found = true
                    container = parser.tip
                    matched_leaf = true
                    break
                end
            end
        end
        if !found
            # Nothing matched.
            advance_next_nonspace(parser)
            break
        end
    end

    # What remains at the offset is a text line. Add the text to the
    # appropriate container.
    if !parser.all_closed && !parser.blank && parser.tip.t isa Paragraph
        # Lazy paragraph continuation.
        add_line(parser)
    else
        # Not a lazy continuation, finalize any blocks not matched.
        close_unmatched_blocks(parser)
        if parser.blank && !isnull(container.last_child)
            container.last_child.last_line_blank = true
        end

        t = container.t

        # Block quote lines are never blank as they start with > and we don't
        # count blanks in fenced code for purposes of tight/loose lists or
        # breaking out of lists. We also don't set last_line_blank on an empty
        # list item, or if we just closed a fenced block.
        last_line_blank =
            parser.blank && !(
                t isa BlockQuote ||
                (t isa CodeBlock && container.t.is_fenced) ||
                (
                    t isa Item &&
                    isnull(container.first_child) &&
                    container.sourcepos[1][1] == parser.line_number
                )
            )

        # Propagate `last_line_blank` up through parents.
        cont = container
        while !isnull(cont)
            cont.last_line_blank = last_line_blank
            cont = cont.parent
        end

        if accepts_lines(t)
            add_line(parser)
            # If HtmlBlock, check for end condition.
            if t isa HtmlBlock && container.t.html_block_type in 1:5
                str = rest(parser)
                if occursin(reHtmlBlockClose[container.t.html_block_type], str)
                    parser.last_line_length = length(ln)
                    finalize(parser, container, parser.line_number)
                end
            end
        elseif !eof(parser) && !parser.blank
            # Create a paragraph container for one line.
            container = add_child(parser, Paragraph(), parser.pos)
            advance_next_nonspace(parser)
            add_line(parser)
        end
    end

    parser.last_line_length = length(ln)
    return nothing
end

function finalize(parser::Parser, block::Node, line_number::Integer)
    above = block.parent
    block.is_open = false
    block.sourcepos = (block.sourcepos[1], (line_number, parser.last_line_length))

    finalize(block.t, parser, block)

    parser.tip = above
    return nothing
end

function process_inlines(parser::Parser, block::Node)
    parser.inline_parser.refmap = parser.refmap
    state = (block, block, true)
    while true
        result = iterate(block, state)
        result === nothing && break
        (node, entering), state = result

        if entering
            # Type-keyed modifier dispatch
            node_type = typeof(node.t)
            for fn in get(parser.typed_modifiers, node_type, EMPTY_FN_VEC)
                fn(parser, node)
            end
            for fn in get(parser.typed_modifiers, Nothing, EMPTY_FN_VEC)
                fn(parser, node)
            end
            # If modifier unlinked a child that was next in iteration, fix state
            next_node = state[2]
            if !isnull(next_node) && next_node !== block && isnull(next_node.parent)
                if !isnull(node.first_child)
                    state = (state[1], node.first_child, true)
                else
                    state = (state[1], node, false)
                end
            end
        else
            if contains_inlines(node.t)
                parse(parser.inline_parser, node)
            end
        end
    end
end

contains_inlines(t) = false
contains_inlines(::Paragraph) = true
contains_inlines(::Heading) = true

function parse(parser::Parser, my_input::IO; kws...)
    parser.doc = Node(Document(), ((1, 1), (0, 0)))
    isempty(kws) || mergemeta!(parser.doc, Dict(string(k) => v for (k, v) in kws))
    parser.tip = parser.doc
    parser.refmap = Dict{String,Tuple{String,String}}()
    parser.line_number = getmeta(parser.doc, "line", 1) - 1
    parser.last_line_length = 0
    parser.pos = 1
    parser.column = 0
    parser.last_matched_container = parser.doc
    parser.buf = ""
    parser.len = 0
    line_count = 0
    for line in eachline(my_input)
        incorporate_line(parser, line)::Nothing
        line_count += 1
    end
    while !isnull(parser.tip)
        finalize(parser, parser.tip, line_count)
    end
    process_inlines(parser, parser.doc)
    return parser.doc
end

(p::Parser)(text::AbstractString; kws...) = p(IOBuffer(text); kws...)
(p::Parser)(io::IO; kws...) = parse(p, io; kws...)

Base.open(p::Parser, file::AbstractString; kws...) =
    open(io -> p(io; :source => file, kws...), file)
