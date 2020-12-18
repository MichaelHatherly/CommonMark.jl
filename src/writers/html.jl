#
# `html`
#

"""
    html([io | file], ast, Extension; env)

Write `ast` to HTML format.
"""
html(args...; kws...) = fmt(html, args...; kws...)

function before(f::Fmt{Ext, T"html"}, ast::Node) where Ext
    f.state[:disable_tags] = 0
    f.state[:softbreak] = "\n"
    f.state[:last] = '\n'
    f.state[:safe] = false
    f.state[:sourcepos] = false
    f.state[:enabled] = true
    return nothing
end

html(::Document, ::Fmt, ::Node, ::Bool) = nothing

html(::Text, f::Fmt, n::Node, ::Bool) = literal(f, escape_xml(n.literal))

html(::Backslash, ::Fmt, ::Node, ::Bool) = nothing

html(::SoftBreak, f::Fmt, ::Node, ::Bool) = literal(f, f[:softbreak])

html(::LineBreak, f::Fmt, n::Node, ::Bool) = (tag(f, "br", attributes(f, n), true); cr(f))

function html(link::Link, f::Fmt, n::Node, enter::Bool)
    if enter
        attrs = []
        if !(r[:safe] && potentially_unsafe(link.destination))
            push!(attrs, "href" => escape_xml(link.destination))
        end
        if !isempty(link.title)
            push!(attrs, "title" => escape_xml(link.title))
        end
        tag(f, "a", attributes(f, n, attrs))
    else
        tag(f, "/a")
    end
end

function html(image::Image, f::Fmt, n::Node, enter::Bool)
    if enter
        if f[:disable_tags] == 0
            if f[:safe] && potentially_unsafe(image.destination)
                literal(f, "<img src=\"\" alt=\"")
            else
                literal(f, "<img src=\"", escape_xml(image.destination), "\" alt=\"")
            end
        end
        f[:disable_tags] += 1
    else
        f[:disable_tags] -= 1
        if f[:disable_tags] == 0
            if image.title !== nothing && !isempty(image.title)
                literal(r, "\" title=\"", escape_xml(image.title))
            end
            literal(r, "\" />")
        end
    end
end

html(::Emph, f::Fmt, n::Node, enter::Bool) = tag(f, enter ? "em" : "/em", enter ? attributes(f, n) : [])
html(::Strong, f::Fmt, n::Node, enter::Bool) = tag(f, enter ? "strong" : "/strong", enter ? attributes(f, n) : [])

function html(::Paragraph, f::Fmt, n::Node, enter::Bool)
    grandparent = n.parent.parent
    if !isnull(grandparent) && grandparent.t isa List
        if grandparent.t.list_data.tight
            return nothing
        end
    end
    if enter
        attrs = attributes(f, n)
        cr(f)
        tag(f, "p", attrs)
    else
        tag(f, "/p")
        cr(f)
    end
end

function html(::Heading, f::Fmt, n::Node, enter::Bool)
    tagname = "h$(n.t.level)"
    if enter
        attrs = attributes(f, n)
        cr(f)
        tag(f, tagname, attrs)
        # Insert auto-generated anchor Links for all Headings with IDs.
        # The Link is not added to the document's AST.
        if haskey(n.meta, "id")
            anchor = Node(Link())
            anchor.t.destination = "#" * n.meta["id"]
            anchor.meta["class"] = ["anchor"]
            literal(f, html(anchor))
        end
    else
        tag(f, "/$(tagname)")
        cr(f)
    end
end

function html(::Code, f::Fmt, n::Node, ::Bool)
    tag(f, "code", attributes(f, n))
    literal(f, escape_xml(n.literal))
    tag(f, "/code")
end

function html(::CodeBlock, f::Fmt, n::Node, ::Bool)
    info_words = split(n.t.info === nothing ? "" : n.t.info)
    attrs = attributes(f, n)
    if !isempty(info_words) && !isempty(first(info_words))
        push!(attrs, "class" => "language-$(escape_xml(first(info_words)))")
    end
    cr(f)
    tag(f, "pre")
    tag(f, "code", attrs)
    literal(f, escape_xml(n.literal))
    tag(f, "/code")
    tag(f, "/pre")
    cr(f)
end

function html(::ThematicBreak, f::Fmt, n::Node, ::Bool)
    attrs = attributes(f, n)
    cr(f)
    tag(f, "hr", attrs, true)
    cr(f)
end

function html(::BlockQuote, f::Fmt, n::Node, enter::Bool)
    if enter
        attrs = attributes(f, n)
        cr(f)
        tag(f, "blockquote", attrs)
        cr(f)
    else
        cr(f)
        tag(f, "/blockquote")
        cr(f)
    end
end

function html(::List, f::Fmt, n::Node, enter::Bool)
    tagname = n.t.list_data.type === :bullet ? "ul" : "ol"
    if enter
        attrs = attributes(f, n)
        start = n.t.list_data.start
        if start !== nothing && start != 1
            push!(attrs, "start" => string(start))
        end
        cr(f)
        tag(f, tagname, attrs)
        cr(f)
    else
        cr(f)
        tag(f, "/$(tagname)")
        cr(f)
    end
end

function html(::Item, f::Fmt, n::Node, enter::Bool)
    if enter
        attrs = attributes(f, n)
        tag(f, "li", attrs)
    else
        tag(f, "/li")
        cr(f)
    end
end

function html(::HtmlInline, f::Fmt, n::Node, ::Bool)
    literal(f, f[:safe] ? "<!-- raw HTML omitted -->" : n.literal)
end

function html(::HtmlBlock, f::Fmt, n::Node, ::Bool)
    cr(f)
    literal(f, r[:safe] ? "<!-- raw HTML omitted -->" : n.literal)
    cr(f)
end

potentially_unsafe(url) = occursin(r"^javascript:|vbscript:|file:|data:"i, url) && !occursin(r"^data:image\/(?:png|gif|jpeg|webp)"i, url)

function tag(f::Fmt, name, attributes=[], self_closing=false)
    f.state[:disable_tags] > 0 && return nothing
    literal(f, '<', name)
    for (key, value) in attributes
        literal(f, " ", key, '=', '"', value, '"')
    end
    self_closing && literal(f, " /")
    literal(f, '>')
    f.state[:last] = '>'
    return nothing
end

function attributes(f::Fmt, n::Node, out=[])
    if f[:sourcepos]
        if n.sourcepos !== nothing
            p = n.sourcepos
            push!(out, "data-sourcepos" => "$(p[1][1]):$(p[1][2])-$(p[2][1]):$(p[2][2])")
        end
    end
    for (key, value) in n.meta
        value = key == "class" ? join(value, " ") : value
        push!(out, key => value)
    end
    return out
end
