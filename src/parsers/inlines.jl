const ESCAPED_CHAR = "\\\\$(ESCAPABLE)"
const WHITESPACECHAR = collect(" \t\n\x0b\x0c\x0d")

const reLinkTitle = Regex(
    "^(?:\"($(ESCAPED_CHAR)|[^\"\\x00])*\"|'($(ESCAPED_CHAR)|[^'\\x00])*'|\\(($(ESCAPED_CHAR)|[^()\\x00])*\\))",
)
const reLinkDestinationBraces = r"^(?:<(?:[^<>\n\\\x00]|\\.)*>)"
const reEscapable = Regex("^$(ESCAPABLE)")
const reEntityHere = Regex("^$(ENTITY)", "i")
const reTicks = r"`+"
const reTicksHere = r"^`+"
const reEllipses = r"\.\.\."
const reDash = r"--+"
const reEmailAutolink =
    r"^<([a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)>"
const reAutolink = r"^<[A-Za-z][A-Za-z0-9.+-]{1,31}:[^<>\x00-\x20]*>"i
const reSpnl = r"^ *(?:\n *)?"
const reWhitespaceChar = r"^^[ \t\n\x0b\x0c\x0d]"
const reWhitespace = r"[ \t\n\x0b\x0c\x0d]+"
const reUnicodeWhitespaceChar = r"^\s"
const reFinalSpace = r" *$"
const reInitialSpace = r"^ *"
const reSpaceAtEndOfLine = r"^ *(?:\n|$)"
const reLinkLabel = r"^\[(?:[^\\\[\]]|\\.){0,1000}\]"

mutable struct Delimiter
    cc::Char
    numdelims::Int
    origdelims::Int
    node::Node
    previous::Union{Nothing,Delimiter}
    next::Union{Nothing,Delimiter}
    can_open::Bool
    can_close::Bool
end

mutable struct Bracket
    node::Node
    previous::Union{Nothing,Bracket}
    previousDelimiter::Union{Nothing,Delimiter}
    index::Int
    image::Bool
    active::Bool
    bracket_after::Bool
end

mutable struct InlineParser <: AbstractParser
    # required
    buf::String
    pos::Int
    len::Int
    # extra
    brackets::Union{Nothing,Bracket}
    delimiters::Union{Nothing,Delimiter}
    refmap::Dict{String,Any}
    inline_parsers::Dict{Char,Vector{Function}}
    modifiers::Vector{Function}
    # Delimiter-based inline registries
    delim_nodes::Dict{Tuple{Char,Int},Type{<:AbstractInline}}
    flanking_rules::Dict{Char,Symbol}
    odd_match_chars::Set{Char}
    # Precomputed emphasis lookups (derived from delim_nodes)
    delim_chars::Set{Char}
    delim_counts::Dict{Char,Vector{Int}}
    delim_max::Dict{Char,Int}
    # Fast lookup for ASCII trigger characters (indexed by codepoint+1)
    # Non-ASCII triggers fall back to haskey on inline_parsers
    trigger_table::BitVector

    function InlineParser()
        parser = new()
        parser.buf = ""
        parser.pos = 1
        parser.len = length(parser.buf)
        parser.brackets = nothing
        parser.delimiters = nothing
        parser.refmap = Dict()
        parser.inline_parsers = Dict()
        parser.modifiers = Function[]
        parser.delim_nodes = Dict{Tuple{Char,Int},Type{<:AbstractInline}}()
        parser.flanking_rules = Dict{Char,Symbol}()
        parser.odd_match_chars = Set{Char}()
        parser.delim_chars = Set{Char}()
        parser.delim_counts = Dict{Char,Vector{Int}}()
        parser.delim_max = Dict{Char,Int}()
        parser.trigger_table = falses(128)
        return parser
    end
end

# Rebuild precomputed emphasis lookups from delim_nodes
function rebuild_delim_lookups!(ip::InlineParser)
    empty!(ip.delim_chars)
    empty!(ip.delim_counts)
    empty!(ip.delim_max)
    for (char, count) in keys(ip.delim_nodes)
        push!(ip.delim_chars, char)
        counts = get!(ip.delim_counts, char, Int[])
        push!(counts, count)
    end
    for (char, counts) in ip.delim_counts
        sort!(counts, rev = true)
        ip.delim_max[char] = first(counts)
    end
end

include("inlines/code.jl")
include("inlines/escapes.jl")
include("inlines/autolinks.jl")
include("inlines/html.jl")
include("inlines/emphasis.jl")
include("inlines/links.jl")
include("inlines/text.jl")

const COMMONMARK_INLINE_RULES = [
    AutolinkRule(),
    InlineCodeRule(),
    AsteriskEmphasisRule(),
    UnderscoreEmphasisRule(),
    BackslashEscapeRule(),
    HtmlInlineRule(),
    HtmlEntityRule(),
    LinkRule(),
    ImageRule(),
    TextRule(),
    NewlineRule(),
]

function parse_inline(parser::InlineParser, block::Node, fallback::Vector{Function})
    c = trypeek(parser, Char)
    c === nothing && return false
    for λ in get(parser.inline_parsers, c, fallback)
        if λ(parser, block)
            return true
        end
    end
    read(parser, Char)
    append_child(block, text(c))
    return true
end

function parse_inlines(parser::InlineParser, block::Node)
    parser.buf = strip(block.literal)
    block.literal = ""
    parser.pos = 1
    parser.len = ncodeunits(parser.buf)
    parser.delimiters = nothing
    parser.brackets = nothing
    fallback = parser.inline_parsers['\0']
    while parse_inline(parser, block, fallback)
        nothing
    end
    for fn in parser.modifiers
        fn(parser, block)
    end
end

parse(parser::InlineParser, block::Node) = parse_inlines(parser, block)
