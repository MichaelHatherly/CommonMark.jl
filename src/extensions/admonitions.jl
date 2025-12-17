struct Admonition <: AbstractBlock
    category::String
    title::String
end

is_container(::Admonition) = true
accepts_lines(::Admonition) = false
can_contain(::Admonition, t) = !(t isa Item)
finalize(::Admonition, parser::Parser, node::Node) = nothing
function continue_(::Admonition, parser::Parser, ::Any)
    if parser.indent ≥ 4
        advance_offset(parser, 4, true)
    elseif parser.blank
        advance_next_nonspace(parser)
    else
        return 1
    end
    return 0
end

function parse_admonition(parser::Parser, container::Node)
    if !parser.indented
        ln = rest_from_nonspace(parser)
        m = match(r"^!!! (\w+)(?: \"([^\"]+)\")?$", ln)
        if m !== nothing
            close_unmatched_blocks(parser)
            title = m[2] === nothing ? uppercasefirst(m[1]) : m[2]
            add_child(parser, Admonition(m[1], title), parser.next_nonspace)
            advance_to_end(parser)
            return 1
        end
    end
    return 0
end

"""
    AdmonitionRule()

Parse admonition blocks (notes, warnings, tips, etc.).

Not enabled by default. Uses `!!!` syntax with a category and optional title.

```markdown
!!! note "Custom Title"
    This is an admonition block.
    It can contain multiple paragraphs.

!!! warning
    Default title is the category name.
```
"""
struct AdmonitionRule end
block_rule(::AdmonitionRule) = Rule(parse_admonition, 0.5, "!")

#
# Writers
#

function write_html(a::Admonition, rend, node, enter)
    if enter
        tag(rend, "div", attributes(rend, node, ["class" => "admonition $(a.category)"]))
        tag(rend, "p", ["class" => "admonition-title"])
        print(rend.buffer, a.title)
        tag(rend, "/p")
    else
        tag(rend, "/div")
    end
end

# Requires tcolorbox package and custom newtcolorbox definitions.
function write_latex(a::Admonition, w, node, enter)
    if enter
        cr(w)
        literal(w, "\\begin{admonition@$(a.category)}{$(a.title)}\n")
    else
        literal(w, "\\end{admonition@$(a.category)}\n")
        cr(w)
    end
end

function write_typst(a::Admonition, w, node, enter)
    if enter
        styles = Dict(
            "danger" => "#dc2626",
            "warning" => "#facc15",
            "info" => "#0ea5e9",
            "note" => "#9333ea",
            "tip" => "#16a34a",
        )
        style = get(styles, a.category, "#525252")
        fill = "fill: rgb(\"#e5e5e5\")"
        inset = "inset: 8pt"
        stroke = "stroke: (left: 2pt + rgb(\"$style\"), rest: none)"
        width = "width: 100%"
        cr(w)
        literal(w, "#block($fill, $inset, $stroke, $width)[")
        literal(w, "#strong[", a.title, "] \\")
        cr(w)
        linebreak(w, node)
    else
        literal(w, "]")
        cr(w)
    end
end

function write_term(a::Admonition, rend, node, enter)
    styles = Dict(
        "danger" => crayon"red bold",
        "warning" => crayon"yellow bold",
        "info" => crayon"cyan bold",
        "note" => crayon"cyan bold",
        "tip" => crayon"green bold",
    )
    style = get(styles, a.category, crayon"default bold")
    if enter
        header = rpad("┌ $(a.title) ", available_columns(rend), "─")
        print_margin(rend)
        print_literal(rend, style, header, inv(style), "\n")
        push_margin!(rend, "│", style)
        push_margin!(rend, " ", crayon"")
    else
        pop_margin!(rend)
        pop_margin!(rend)
        print_margin(rend)
        print_literal(
            rend,
            style,
            rpad("└", available_columns(rend), "─"),
            inv(style),
            "\n",
        )
        if !isnull(node.nxt)
            print_margin(rend)
            print_literal(rend, "\n")
        end
    end
end

function write_markdown(a::Admonition, w, node, ent)
    if ent
        push_margin!(w, "    ")
        literal(w, "!!! ", a.category)
        if lowercase(a.title) != lowercase(a.category)
            literal(w, " \"$(a.title)\"")
        end
        literal(w, "\n")
        print_margin_rstrip(w)
        literal(w, "\n")
    else
        pop_margin!(w)
        cr(w)
        linebreak(w, node)
    end
end
