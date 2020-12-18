#
# `latex`
#

"""
    latex([io | file], ast, Extension; env)

Write `ast` to LaTeX format.
"""
latex(args...; kws...) = fmt(latex, args...; kws...)

function before(f::Fmt{Ext, T"latex"}, ::Node) where Ext
    f[:enabled] = true
    f[:last] = '\n'
    return nothing
end

function before(f::Fmt{Ext, T"latex"}, n::Node, enter::Bool) where Ext
    if enter && haskey(n.meta, "id")
        literal(f, "\\protect\\hypertarget{", n.meta["id"], "}{}")
    end
    return nothing
end

latex(::Document, ::Fmt, ::Node, ::Bool) = nothing

latex(::Text, f::Fmt, n, ::Bool) = latex_escape(f, n.literal)

latex(::Backslash, ::Fmt, ::Node, ::Bool) = nothing

latex(::SoftBreak, f, ::Node, ::Bool) = cr(f)
latex(::LineBreak, f, ::Node, ::Bool) = cr(f)

function latex(::Code, f::Fmt, n::Node, ::Bool)
    literal(f, "\\texttt{")
    latex_escape(f, n.literal)
    literal(f, "}")
end

latex(::HtmlInline, ::Fmt, ::Node, ::Bool) = nothing

function latex(link::Link, f::Fmt, n::Node, enter::Bool)
    if enter
        # Link destinations that begin with a # are taken to be internal to the
        # document. LaTeX wants to use a hyperlink rather than an href for
        # these, so branch based on it to allow both types of links to be used.
        # Generating `\url` commands is not supported.
        type, nth = startswith(link.destination, '#') ? ("hyperlink", 1) : ("href", 0)
        literal(f, "\\$type{$(chop(link.destination; head=nth, tail=0))}{")
    else
        literal(f, "}")
    end
end

function latex(image::Image, f::Fmt, n::Node, enter::Bool)
    if enter
        cr(f)
        literal(f, "\\begin{figure}\n")
        literal(f, "\\centering\n")
        literal(f, "\\includegraphics[max width=\\linewidth]{", image.destination, "}\n")
        literal(f, "\\caption{")
    else
        literal(f, "}\n")
        literal(f, "\\end{figure}")
        cr(f)
    end
end

latex(::Emph, f::Fmt, n::Node, enter::Bool) = literal(f, enter ? "\\textit{" : "}")

latex(::Strong, f::Fmt, n::Node, enter::Bool) = literal(f, enter ? "\\textbf{" : "}")

latex(::Paragraph, f::Fmt, n::Node, enter::Bool) = literal(f, enter ? "" : "\\par\n")

function latex(::Heading, f::Fmt, n::Node, enter::Bool)
    if enter
        cr(f)
        level = n.t.level
        name = level ≤ 3 ? "sub"^(level-1) * "section" : "sub"^(level-4) * "paragraph"
        literal(f, "\\$name{")
    else
        literal(f, "}")
        cr(f)
    end
end

function latex(::BlockQuote, f::Fmt, n::Node, enter::Bool)
    cr(f)
    literal(f, enter ? "\\begin{quote}" : "\\end{quote}")
    cr(f)
end

function latex(list::List, f::Fmt, n::Node, enter::Bool)
    cr(f)
    command = list.list_data.type === :bullet ? "itemize" : "enumerate"
    if enter
        literal(f, "\\begin{$command}\n")
        if command == "enumerate"
            literal(f, "\\def\\labelenumi{\\arabic{enumi}.}\n")
            literal(f, "\\setcounter{enumi}{$(list.list_data.start)}\n")
        end
        if list.list_data.tight
            literal(f, "\\setlength{\\itemsep}{0pt}\n")
            literal(f, "\\setlength{\\parskip}{0pt}\n")
        end
    else
        literal(f, "\\end{$command}")
    end
    cr(f)
end

function latex(::Item, f::Fmt, n::Node, enter::Bool)
    literal(f, enter ? "\\item" : "")
    cr(f)
end

function latex(::ThematicBreak, f::Fmt, n::Node, ::Bool)
    cr(f)
    literal(f, "\\par\\bigskip\\noindent\\hrulefill\\par\\bigskip")
    cr(f)
end

function latex(c::CodeBlock, f::Fmt, n::Node, ::Bool)
    environment = c.is_fenced ? "lstlisting" : "verbatim"
    cr(f)
    literal(f, "\\begin{$environment}")
    cr(f)
    literal(f, n.literal)
    cr(f)
    literal(f, "\\end{$environment}")
    cr(f)
end

latex(::HtmlBlock, ::Fmt, ::Node, ::Bool) = nothing

let chars = Dict(
    '^'  => "\\^{}",
    '\\' => "{\\textbackslash}",
    '~'  => "{\\textasciitilde}",
)
    for c in "&%\$#_{}"
        chars[c] = "\\$c"
    end
    global function latex_escape(w::Fmt, s::AbstractString)
        for ch in s
            literal(w, get(chars, ch, ch))
        end
    end

    global function latex_escape(s::AbstractString)
        buffer = IOBuffer()
        for ch in s
            write(buffer, get(chars, ch, ch))
        end
        return String(take!(buffer))
    end
end
