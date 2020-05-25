
mutable struct LaTeX
    LaTeX() = new()
end

function render(r::Writer{LaTeX}, ast::Node)
    for (node, entering) in ast
        latex(node.t, r, node, entering)
    end
    return nothing
end

# Utilities.

# Rendering.

latex(::Document, r, node, ent) = nothing

latex(::Text, r, node, ent) = latex_escape(r.buffer, node.literal)

latex(::SoftBreak, r, node, ent) = println(r.buffer, " ")

latex(::LineBreak, r, node, ent) = println(r.buffer)

function latex(::Code, r, node, ent)
    print(r.buffer, "\\texttt{")
    latex_escape(r.buffer, node.literal)
    print(r.buffer, "}")
end

latex(::HtmlInline, r, node, ent) = nothing

function latex(link::Link, r, node, ent)
    print(r.buffer, ent ? "\\href{$(link.destination)}{" : "}")
end

function latex(::Image, r, node, ent)
    if ent
        println(r.buffer, "\\begin{figure}")
        println(r.buffer, "\\centering")
        println(r.buffer, "\\includegraphics{", node.t.destination, "}")
        print(r.buffer, "\\caption{")
    else
        println(r.buffer, "}")
        println(r.buffer, "\\end{figure}")
    end
end

latex(::Emph, r, node, ent) = print(r.buffer, ent ? "\\emph{" : "}")

latex(::Strong, r, node, ent) = print(r.buffer, ent ? "\\textbf{" : "}")

function latex(::Paragraph, r, node, ent)
    println(r.buffer)
end

function latex(::Heading, r, node, ent)
    if ent
        n = node.t.level
        name = n ≤ 3 ? "sub"^(n-1) * "section" : "sub"^(n-4) * "paragraph"
        print(r.buffer, "\\$name{")
    else
        println(r.buffer, "}")
    end
end

function latex(::BlockQuote, r, node, ent)
    if ent
        println(r.buffer, "\\begin{quote}")
    else
        println(r.buffer, "\\end{quote}")
    end
end

# Requires \usepackage{enumerate} for the [start=...] option to be available.
function latex(list::List, r, node, ent)
    env = list.list_data.type == "bullet" ? "itemize" : "enumerate"
    if ent
        start = env == "enumerate" ? "[start=$(list.list_data.start)]" : ""
        println(r.buffer, "\\begin{$env}$start")
    else
        println(r.buffer, "\\end{$env}")
    end
end

function latex(::Item, r, node, ent)
    if ent
        println(r.buffer, "\\item")
    else
        println(r.buffer)
    end
end

function latex(::ThematicBreak, r, node, ent)
    println(r.buffer, "\\begin{center}\\rule{0.5\\linewidth}{0.5pt}\\end{center}")
end

# TODO: handle info lines.
function latex(::CodeBlock, r, node, ent)
    println(r.buffer, "\\begin{verbatim}")
    for line in eachline(IOBuffer(node.literal))
        latex_escape(r.buffer, line)
    end
    println(r.buffer, "\n\\end{verbatim}")
end

latex(::HtmlBlock, r, node, ent) = nothing

let chars = Dict(
        '^'  => "\\^{}",
        '\\' => "{\\textbackslash}",
        '~'  => "{\\textasciitilde}",
    )
    for c in "&%\$#_{}"
        chars[c] = "\\$c"
    end
    global function latex_escape(io, s::AbstractString)
        for ch in s
            print(io, get(chars, ch, ch))
        end
    end
end
