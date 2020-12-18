struct LaTeXInline <: AbstractInline end
struct LaTeXBlock <: AbstractBlock end

const RAW_CONTENT_DEFAULTS = Dict(
    "html_inline"  => HtmlInline,
    "latex_inline" => LaTeXInline,
    "html_block"   => HtmlBlock,
    "latex_block"  => LaTeXBlock
)

struct RawContentRule
    formats::Dict{String, Any}
    function RawContentRule(; formats...)
        return isempty(formats) ? new(RAW_CONTENT_DEFAULTS) :
            new(Dict("$k" => v for (k, v) in formats))
    end
end

const reRawContent = r"^{=([a-z]+)}"

inline_rule(rule::RawContentRule) = Rule(1, "{") do parser, block
    if !isnull(block.last_child) && block.last_child.t isa Code
        m = match(reRawContent, parser)
        if m !== nothing
            key = "$(m[1])_inline"
            if haskey(rule.formats, key)
                block.last_child.t = rule.formats[key]()
                consume(parser, m)
                return true
            end
        end
    end
    return false
end

block_modifier(rule::RawContentRule) = Rule(2) do parser, node
    if node.t isa CodeBlock
        m = match(reRawContent, node.t.info)
        m === nothing && return nothing
        key = "$(m[1])_block"
        haskey(rule.formats, key) && (node.t = rule.formats[key]())
    end
    return nothing
end

# Raw LaTeX doesn't get displayed in HTML documents.
html(::LaTeXBlock, ::Fmt, ::Node, ::Bool) = nothing
html(::LaTeXInline, ::Fmt, ::Node, ::Bool) = nothing

# Don't do any kind of escaping for the content.
function latex(::LaTeXBlock, f::Fmt, n::Node, ::Bool)
    cr(f)
    literal(f, n.literal)
    cr(f)
end
latex(::LaTeXInline, f::Fmt, n::Node, ::Bool) = literal(f, n.literal)

# Printing to terminal using the same implementations as for HTML content.
term(::LaTeXBlock, f::Fmt, n::Node, enter::Bool) = term(HtmlBlock(), f, n, enter)
term(::LaTeXInline, f::Fmt, n::Node, enter::Bool) = term(HtmlInline(), f, n, enter)

function markdown(::LaTeXBlock, f::Fmt, n::Node, ::Bool)
    print_margin(f)
    literal(f, "```{=latex}\n")
    for line in eachline(IOBuffer(n.literal))
        print_margin(f)
        literal(f, line, "\n")
    end
    print_margin(f)
    literal(f, "```\n")
    linebreak(f, n)
end

function markdown(::LaTeXInline, f::Fmt, n::Node, ::Bool)
    num = foldl(eachmatch(r"`+", n.literal); init=0) do a, b
        max(a, length(b.match))
    end
    literal(f, '`'^(num == 1 ? 2 : 1))
    literal(f, n.literal)
    literal(f, '`'^(num == 1 ? 2 : 1), "{=latex}")
end
