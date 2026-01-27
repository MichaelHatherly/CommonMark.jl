"""
Container for a single docstring's parsed content, carrying module metadata.
"""
struct DocStringSection <: AbstractBlock end
is_container(::DocStringSection) = true
accepts_lines(::DocStringSection) = false
can_contain(::DocStringSection, t) = !(t isa Item)

# Writers - transparent container, just pass through
write_html(::DocStringSection, r, n, ent) = nothing
write_latex(::DocStringSection, w, n, ent) = nothing
write_typst(::DocStringSection, w, n, ent) = nothing
write_term(::DocStringSection, w, n, ent) = nothing
write_markdown(::DocStringSection, w, n, ent) = nothing

"""
Lazy wrapper that parses docstring text with CommonMark on first display.
"""
mutable struct LazyCommonMarkDoc
    docstrs::Vector{Docs.DocStr}
    parser::Parser
    parsed::Any
    LazyCommonMarkDoc(d::Docs.DocStr, p::Parser = Parser()) = new([d], p, nothing)
    LazyCommonMarkDoc(ds::Vector{Docs.DocStr}, p::Parser = Parser()) = new(ds, p, nothing)
end

# Provide .meta property for Documenter compatibility (accesses docstr.data)
function Base.getproperty(doc::LazyCommonMarkDoc, s::Symbol)
    if s === :meta
        docstrs = getfield(doc, :docstrs)
        @assert length(docstrs) == 1 "meta only valid for single docstr"
        return docstrs[1].data
    end
    getfield(doc, s)
end

function _parse_doc(doc::LazyCommonMarkDoc)
    if doc.parsed === nothing
        result = Node(Document())
        for (i, docstr) in enumerate(doc.docstrs)
            # Add separator between docstrings
            i > 1 && append_child(result, Node(ThematicBreak()))

            # Build text for this docstring
            buf = IOBuffer()
            for part in docstr.text
                Docs.formatdoc(buf, docstr, part)
            end

            # Parse with source location from docstring metadata
            kws = Dict{Symbol,Any}()
            haskey(docstr.data, :path) && (kws[:source] = docstr.data[:path])
            haskey(docstr.data, :linenumber) && (kws[:line] = docstr.data[:linenumber])
            haskey(docstr.data, :module) && (kws[:module] = docstr.data[:module])
            haskey(docstr.data, :typesig) && (kws[:typesig] = docstr.data[:typesig])
            haskey(docstr.data, :binding) && (kws[:binding] = docstr.data[:binding])
            parsed = doc.parser(String(take!(buf)); kws...)

            # Convert Document to DocStringSection and append
            parsed.t = DocStringSection()
            append_child(result, parsed)
        end
        doc.parsed = result
    end
    doc.parsed
end

Base.show(io::IO, ::MIME"text/plain", doc::LazyCommonMarkDoc) =
    show(io, MIME("text/plain"), _parse_doc(doc))

function Docs.catdoc(docs::LazyCommonMarkDoc...)
    all_docstrs = Docs.DocStr[]
    parser = first(docs).parser
    for doc in docs
        append!(all_docstrs, doc.docstrs)
    end
    LazyCommonMarkDoc(all_docstrs, parser)
end

"""
    @docstring_parser
    @docstring_parser parser

!!! warning "Experimental"
    This macro is experimental and subject to change without notice.

Install CommonMark parser for all docstrings in the calling module.
Call at module top-level after all docstrings are defined.

Optionally pass a custom `Parser` with extensions enabled:

    @docstring_parser Parser(enable=[MathRule()])
"""
macro docstring_parser(parser = nothing)
    p = parser === nothing ? :(Parser()) : parser
    quote
        let p = $p
            for (binding, multidoc) in Docs.meta($(__module__))
                for (sig, docstr) in multidoc.docs
                    docstr.object = LazyCommonMarkDoc(docstr, p)
                end
            end
        end
    end
end

# Interface for extensions - MarkdownAST ext overrides this
function to_mast end
