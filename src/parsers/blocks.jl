const CODE_INDENT = 4

const reHtmlBlockOpen = [
    r"^<(?:script|pre|style)(?:\s|>|$)"i,
    r"^<!--",
    r"^<[?]",
    r"^<![A-Z]",
    r"^<!\[CDATA\[",
    r"^<[/]?(?:address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h[123456]|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|section|source|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul)(?:\s|[/]?[>]|$)"i,
    Regex("^(?:$(OPENTAG)|$(CLOSETAG))\\s*\$", "i")
]
const reHtmlBlockClose = [
    r"<\/(?:script|pre|style)>"i,
    r"-->",
    r"\?>",
    r">",
    r"\]\]>"
]
const reThematicBreak     = r"^(?:(?:\*[ \t]*){3,}|(?:_[ \t]*){3,}|(?:-[ \t]*){3,})[ \t]*$"
const reMaybeSpecial      = r"^[\[!\|:#`~*+_=<>0-9-]"
const reNonSpace          = r"[^ \t\f\v\r\n]"
const reBulletListMarker  = r"^[*+-]"
const reOrderedListMarker = r"^(\d{1,9})([.)])"
const reATXHeadingMarker  = r"^#{1,6}(?:[ \t]+|$)"
const reCodeFence         = r"^`{3,}(?!.*`)|^~{3,}"
const reClosingCodeFence  = r"^(?:`{3,}|~{3,})(?= *$)"
const reSetextHeadingLine = r"^(?:=+|-+)[ \t]*$"
const reLineEnding        = r"\r\n|\n|\r"

mutable struct Parser
    doc::Node
    block_starts::Vector{Function}
    tip::Node
    oldtip::Node
    current_line::String
    line_number::Int
    offset::Int
    column::Int
    next_nonspace::Int
    next_nonspace_column::Int
    indent::Int
    indented::Bool
    blank::Bool
    partially_consumed_tab::Bool
    all_closed::Bool
    last_matched_container::Node
    refmap::Dict{String, Any}
    last_line_length::Int
    inline_parser::InlineParser
    fenced_literals::Dict{String, Function}
    options::Dict{String, Any}

    function Parser(options=Dict())
        parser = new()
        parser.doc = Node(Document(), ((1, 1), (0, 0)))
        parser.block_starts = copy(METHODS)
        parser.tip = parser.doc
        parser.oldtip = parser.doc
        parser.current_line = ""
        parser.line_number = 0
        parser.offset = 1
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
        parser.fenced_literals = Dict()
        parser.inline_parser = InlineParser(options)
        parser.options = options
        return parser
    end
end

Base.show(io::IO, parser::Parser) = print(io, "Parser($(parser.doc))")

is_blank(s::AbstractString) = !occursin(reNonSpace, s)

is_space_or_tab(s::AbstractString) = s in (" ", "\t")
is_space_or_tab(c::AbstractChar) = c in (' ', '\t')
is_space_or_tab(other) = false

peek(ln::AbstractString, pos::Integer) = get(ln, pos, nothing)

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

const METHODS = [
    block_quote,
    atx_heading,
    fenced_code_block,
    html_block,
    setext_heading,
    thematic_break,
    list_item,
    indented_code_block,
]

function add_line(parser::Parser)
    if parser.partially_consumed_tab
        # Skip over tab.
        parser.offset += 1
        # Add space characters.
        chars_to_tab = 4 - (parser.column % 4)
        parser.tip.string_content *= (' ' ^ chars_to_tab)
    end
    parser.tip.string_content *= (SubString(parser.current_line, parser.offset) * '\n')
end

function add_child(parser::Parser, tag::AbstractContainer, offset::Integer)
    while !can_contain(parser.tip.t, tag)
        finalize(parser, parser.tip, parser.line_number - 1)
    end
    column_number = offset + 1
    new_block = Node(tag, ((parser.line_number, column_number), (0, 0)))
    new_block.string_content = ""
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
    current_line = parser.current_line
    i = parser.offset
    cols = parser.column

    c = get(current_line, i, '\0')
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
        c = get(current_line, i, '\0')
    end
    parser.blank = c in ('\n', '\r', '\0')
    parser.next_nonspace = i
    parser.next_nonspace_column = cols
    parser.indent = parser.next_nonspace_column - parser.column
    parser.indented = parser.indent ≥ CODE_INDENT
end

function advance_next_nonspace(parser::Parser)
    parser.offset = parser.next_nonspace
    parser.column = parser.next_nonspace_column
    parser.partially_consumed_tab = false
end

function advance_offset(parser::Parser, count::Integer, columns::Bool)
    current_line = parser.current_line
    c = get(current_line, parser.offset, '\0')
    while count > 0 && c !== '\0'
        if c === '\t'
            chars_to_tab = 4 - (parser.column % 4)
            if columns
                parser.partially_consumed_tab = chars_to_tab > count
                chars_to_advance = min(count, chars_to_tab)
                parser.column += chars_to_advance
                parser.offset += parser.partially_consumed_tab ? 0 : 1
                count -= chars_to_advance
            else
                parser.partially_consumed_tab = false
                parser.column += chars_to_tab
                parser.offset += 1
                count -= 1
            end
        else
            parser.partially_consumed_tab = false
            parser.offset += 1
            # assume ascii; block starts are ascii
            parser.column += 1
            count -= 1
        end
        c = get(current_line, thisind(current_line, parser.offset), '\0')
    end
end

function incorporate_line(parser::Parser, ln::AbstractString)
    all_matched = true

    container = parser.doc
    parser.oldtip = parser.tip
    parser.offset = 1
    parser.column = 0
    parser.blank = false
    parser.partially_consumed_tab = false
    parser.line_number += 1

    # replace NUL characters for security
    ln = occursin(r"\u0000", ln) ? replace(ln, '\0' => '\uFFFD') : ln

    parser.current_line = ln

    # For each containing block, try to parse the associated line start. Bail
    # out on failure: container will point to the last matching block. Set
    # all_matched to false if not all containers match.
    while true
        last_child = container.last_child
        (!isnull(last_child) && last_child.is_open) || break

        container = last_child

        find_next_nonspace(parser)

        rv = continue_(container.t, parser, container)
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
    starts = parser.block_starts
    starts_len = length(starts)
    # Unless last matched container is a code block, try new container starts,
    # adding children to the last matched container.
    while !matched_leaf
        find_next_nonspace(parser)
        # This is a little performance optimization. ALLOCATES lots.
        if !parser.indented && !occursin(reMaybeSpecial, SubString(ln, parser.next_nonspace))
            advance_next_nonspace(parser)
            break
        end
        i = 1
        while i ≤ starts_len
            res = starts[i](parser, container)
            if res === 1
                container = parser.tip
                break
            elseif res === 2
                container = parser.tip
                matched_leaf = true
                break
            else
                i += 1
            end
        end
        if i > starts_len
            # nothing matched
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
        last_line_blank = parser.blank &&
            !(t isa BlockQuote ||
              (t isa CodeBlock && container.t.is_fenced) ||
              (t isa Item && isnull(container.first_child) &&
               container.sourcepos[1][1] == parser.line_number))

        # Propagate last_line_blank up through parents.
        cont = container
        while !isnull(cont)
            cont.last_line_blank = last_line_blank
            cont = cont.parent
        end

        if accepts_lines(t)
            add_line(parser)
            # If HtmlBlock, check for end condition.
            if t isa HtmlBlock && container.t.html_block_type in 1:5
                str = parser.current_line[parser.offset:end]
                if occursin(reHtmlBlockClose[container.t.html_block_type], str)
                    parser.last_line_length = length(ln)
                    finalize(parser, container, parser.line_number)
                end
            end
        elseif parser.offset ≤ length(ln) && !parser.blank
            # create a paragraph container for one line
            container = add_child(parser, Paragraph(), parser.offset)
            advance_next_nonspace(parser)
            add_line(parser)
        end
    end

    parser.last_line_length = length(ln)
end

function finalize(parser::Parser, block::Node, line_number::Integer)
    above = block.parent
    block.is_open = false
    block.sourcepos = (block.sourcepos[1], (line_number, parser.last_line_length))

    finalize(block.t, parser, block)

    parser.tip = above
end

function process_inlines(parser::Parser, block::Node)
    parser.inline_parser.refmap = parser.refmap
    parser.inline_parser.options = parser.options
    for (node, entering) in block
        if !entering && contains_inlines(node.t)
            parse(parser.inline_parser, node)
        end
    end
end

contains_inlines(t) = false
contains_inlines(::Paragraph) = true
contains_inlines(::Heading) = true

function parse(parser::Parser, my_input::AbstractString)
    parser.doc = Node(Document(), ((1, 1), (0, 0)))
    parser.tip = parser.doc
    parser.refmap = Dict()
    parser.line_number = 0
    parser.last_line_length = 0
    parser.offset = 1
    parser.column = 0
    parser.last_matched_container = parser.doc
    parser.current_line = ""
    line_count = 0
    for line in eachline(IOBuffer(my_input))
        incorporate_line(parser, line)
        line_count += 1
    end
    while !isnull(parser.tip)
        finalize(parser, parser.tip, line_count)
    end
    process_inlines(parser, parser.doc)
    return parser.doc
end
