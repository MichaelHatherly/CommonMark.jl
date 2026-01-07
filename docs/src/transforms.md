# [Transforms](@id transforms-page)

Transforms let you intercept and modify AST nodes during rendering. Use them
for URL rewriting, syntax highlighting, document wrappers, and other
output customizations.

```@example transforms
using CommonMark
parser = Parser()
nothing # hide
```

## Basic Usage

Pass a `transform` function to any writer:

```@example transforms
function my_transform(mime, container, node, entering, writer)
    # Return (node, entering) - possibly modified
    (node, entering)
end

ast = parser("Hello *world*")
html(ast; transform = my_transform)
```

The transform is called for every node during tree traversal, both when
entering and leaving container nodes.

## Signature

```julia
transform(mime::MIME, container, node::Node, entering::Bool, writer::Writer) -> (Node, Bool)
```

| Parameter | Description |
|-----------|-------------|
| `mime` | Output format (e.g., `MIME"text/html"()`) |
| `container` | The node's container type (e.g., `Link`, `CodeBlock`) |
| `node` | The AST node being rendered |
| `entering` | `true` when entering, `false` when leaving |
| `writer` | The writer instance (access `writer.env` for config) |

**Important:** You must define a catch-all fallback that passes nodes through
unchanged:

```julia
my_transform(mime, ::CommonMark.AbstractContainer, node, entering, writer) = (node, entering)
```

## Examples

### URL Rewriting

Transform link destinations for your site structure:

```@example transforms
function xform(::MIME"text/html", link::CommonMark.Link, node, entering, writer)
    if entering
        name, _ = splitext(link.destination)
        new_node = CommonMark.Node(CommonMark.Link;
            dest = "/docs/$name.html",
            title = link.title,
        )
        (new_node, entering)
    else
        (node, entering)
    end
end
xform(mime, ::CommonMark.AbstractContainer, node, entering, writer) =
    (node, entering)

ast = parser("[Guide](guide.md)")
html(ast; transform = xform)
```

### Syntax Highlighting

Replace code blocks with pre-rendered HTML:

```@example transforms
function xform(::MIME"text/html", ::CommonMark.CodeBlock, node, entering, writer)
    lang = node.t.info === nothing ? "" : node.t.info
    highlighted = """
        <pre class="highlight"><code class="language-$lang">$(node.literal)</code></pre>
        """
    (CommonMark.Node(CommonMark.HtmlBlock, highlighted), entering)
end
xform(mime, ::CommonMark.AbstractContainer, node, entering, writer) =
    (node, entering)

ast = parser("```julia\nx = 1\n```")
html(ast; transform = xform)
```

### Document Wrapper

Add HTML structure around the rendered content:

```@example transforms
function xform(::MIME"text/html", ::CommonMark.Document, node, entering, writer)
    if entering
        title = get(writer.env, "title", "Untitled")
        CommonMark.literal(writer, """<!DOCTYPE html>
<html>
<head><title>$title</title></head>
<body>
""")
    else
        CommonMark.literal(writer, """</body>
</html>
""")
    end
    (node, entering)
end
xform(mime, ::CommonMark.AbstractContainer, node, entering, writer) =
    (node, entering)

ast = parser("# Hello\n\nWorld")
env = Dict{String,Any}("title" => "My Page")
html(ast, env; transform = xform)
```

### Format-Specific Transforms

Dispatch on MIME type for format-specific behavior:

```@example transforms
function xform(::MIME"text/html", link::CommonMark.Link, node, entering, writer)
    if entering
        dest = link.destination * "?format=html"
        (CommonMark.Node(CommonMark.Link; dest = dest, title = link.title), entering)
    else
        (node, entering)
    end
end

function xform(::MIME"text/latex", link::CommonMark.Link, node, entering, writer)
    if entering
        dest = link.destination * "?format=latex"
        (CommonMark.Node(CommonMark.Link; dest = dest, title = link.title), entering)
    else
        (node, entering)
    end
end

xform(mime, ::CommonMark.AbstractContainer, node, entering, writer) =
    (node, entering)

ast = parser("[link](page)")
println(html(ast; transform = xform))
println(latex(ast; transform = xform))
```

## Accessing Configuration

Use `writer.env` to read configuration passed to the writer:

```@example transforms
function xform(::MIME"text/html", link::CommonMark.Link, node, entering, writer)
    if entering
        base = get(writer.env, "base_url", "")
        dest = base * link.destination
        (CommonMark.Node(CommonMark.Link; dest = dest, title = link.title), entering)
    else
        (node, entering)
    end
end
xform(mime, ::CommonMark.AbstractContainer, node, entering, writer) =
    (node, entering)

ast = parser("[link](page)")
env = Dict{String,Any}("base_url" => "https://example.com/")
html(ast, env; transform = xform)
```

## Migration from Previous API

!!! note "For existing users"
    Skip this section if you're new to CommonMark.jl.

If you were using the previous env-based hooks, here's how to migrate:

| Previous | New |
|----------|-----|
| `env["smartlink-engine"]` | Transform on `Link` / `Image` |
| `env["syntax-highlighter"]` | Transform on `CodeBlock` |
| `env["template-engine"]` | Transform on `Document` |

The new system uses Julia's multiple dispatch, so you define methods for
specific container types rather than passing function values in a dictionary.
