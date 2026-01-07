#
# GitHub-style alerts: > [!NOTE], > [!TIP], etc.
#

"""
GitHub-style alert. Build with `Node(GitHubAlert, category, children...; title="optional")`.
Categories: note, tip, important, warning, caution.
"""
struct GitHubAlert <: AbstractBlock
    category::String
    title::String
end

function Node(
    ::Type{GitHubAlert},
    category::AbstractString,
    children...;
    title::Union{AbstractString,Nothing} = nothing,
)
    cat = lowercase(category)
    t = title === nothing ? get(GITHUB_ALERT_TYPES, cat, titlecase(cat)) : title
    _build(GitHubAlert(cat, t), children)
end

is_container(::GitHubAlert) = true
accepts_lines(::GitHubAlert) = false
can_contain(::GitHubAlert, t) = !(t isa Item)
finalize(::GitHubAlert, ::Parser, ::Node) = nothing

const GITHUB_ALERT_TYPES = Dict(
    "note" => "Note",
    "tip" => "Tip",
    "important" => "Important",
    "warning" => "Warning",
    "caution" => "Caution",
)

"""
    GitHubAlertRule()

Parse GitHub-style alert blockquotes.

Not enabled by default. Converts blockquotes starting with `[!TYPE]` into
styled alert boxes. Supported types: NOTE, TIP, IMPORTANT, WARNING, CAUTION.

```markdown
> [!NOTE]
> This is a note alert.

> [!WARNING]
> This is a warning alert.
```
"""
struct GitHubAlertRule end

block_modifier(::GitHubAlertRule) =
    Rule(50) do parser, block
        if block.t isa BlockQuote
            child = block.first_child
            if !isnull(child) && child.t isa Paragraph
                m = match(
                    r"^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\][ \t]*\n?"i,
                    child.literal,
                )
                if m !== nothing
                    category = lowercase(m[1])
                    title = GITHUB_ALERT_TYPES[category]
                    block.t = GitHubAlert(category, title)
                    child.literal = child.literal[length(m.match)+1:end]
                    if isempty(strip(child.literal))
                        unlink(child)
                    end
                end
            end
        end
        return nothing
    end

#
# Writers
#

function write_html(a::GitHubAlert, rend, node, enter)
    if enter
        cr(rend)
        tag(rend, "div", attributes(rend, node, ["class" => "github-alert $(a.category)"]))
        tag(rend, "p", ["class" => "github-alert-title"])
        print(rend.buffer, a.title)
        tag(rend, "/p")
        cr(rend)
    else
        tag(rend, "/div")
        cr(rend)
    end
end

function write_latex(a::GitHubAlert, w, node, enter)
    if enter
        cr(w)
        literal(w, "\\begin{githubalert@$(a.category)}{$(a.title)}\n")
    else
        literal(w, "\\end{githubalert@$(a.category)}\n")
        cr(w)
    end
end

function write_typst(a::GitHubAlert, w, node, enter)
    if enter
        styles = Dict(
            "note" => "#0969da",
            "tip" => "#1a7f37",
            "important" => "#8250df",
            "warning" => "#9a6700",
            "caution" => "#cf222e",
        )
        style = get(styles, a.category, "#525252")
        fill = "fill: rgb(\"#f6f8fa\")"
        inset = "inset: 8pt"
        stroke = "stroke: (left: 3pt + rgb(\"$style\"), rest: none)"
        width = "width: 100%"
        cr(w)
        literal(w, "#block($fill, $inset, $stroke, $width)[")
        literal(w, "#text(fill: rgb(\"$style\"))[#strong[", a.title, "]] \\")
        cr(w)
        linebreak(w, node)
    else
        literal(w, "]")
        cr(w)
    end
end

function write_term(a::GitHubAlert, rend, node, enter)
    styles = Dict(
        "note" => crayon"blue bold",
        "tip" => crayon"green bold",
        "important" => crayon"magenta bold",
        "warning" => crayon"yellow bold",
        "caution" => crayon"red bold",
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

function write_markdown(a::GitHubAlert, w, node, ent)
    if ent
        push_margin!(w, "> ")
        print_margin(w)
        literal(w, "[!", uppercase(a.category), "]\n")
    else
        pop_margin!(w)
        linebreak(w, node)
    end
end

function write_json(a::GitHubAlert, ctx, node, enter)
    if enter
        blocks = Any[]
        push_container!(ctx, blocks)
    else
        blocks = pop_container!(ctx)
        attr = Any["", String["alert", "alert-$(a.category)"], Any[]]
        push_element!(ctx, json_el(ctx, "Div", Any[attr, blocks]))
    end
end
