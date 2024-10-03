# This extension captures parsed Julia expressions from a markdown string,
# which can then be evaluated into the macro expansion's context to embed the
# values of the expressions in the markdown AST. Should only really be used
# from within the `@cm_str` macro otherwise the expressions won't have "time"
# to actually evaluate.

# Captures an interpolated Julia expression and its position in the string
struct JuliaExpression <: AbstractInline
    pos::Int
    ex
end
# Captures an expression and the future value associated with it after
# macro expansion.
struct JuliaValue <: AbstractInline
    ex
    ref
end

# This rule should only be used from the exported `@cm_str` macro and not
# `enabled!` directly by users on a `Parser` object.
struct JuliaInterpolationRule
    captured::Vector{JuliaExpression}
    JuliaInterpolationRule() = new(JuliaExpression[])
end

const reInterpHere = r"^\$"

inline_rule(ji::JuliaInterpolationRule) = Rule(1, "\$") do p, node
    dollar = match(reInterpHere, p)
    if dollar === nothing || length(dollar.match) > 1
        return false
    else
        consume(p, dollar)
        after_opener, count = position(p), length(dollar.match)
        ex, after_expr = Meta.parse(rest(p), 1; greedy = false, raise = false)
        after_expr += after_opener
        if Meta.isexpr(ex, [:error, :incomplete])
            # Bails out on Julia parse errors, do we rather want to propagate them?
            return false
        else
            seek(p, after_expr - 1) # Offset Meta.parse end position.
            ref = JuliaExpression(length(ji.captured) + 1, ex)
            push!(ji.captured, ref)
            append_child(node, Node(ref))
            return true
        end
    end
end

export @cm_str

"""
    cm""

A string macro for markdown text that implements standard string interpolation.
Returns a parsed markdown AST with the values of the interpolation expressions
embedded in the AST.

```julia
value = "interpolated"
cm"Some *\$(value)* text."
```

The default syntax rules used for parsing are:

  - `AdmonitionRule`
  - `AttributeRule`
  - `AutoIdentifierRule`
  - `CitationRule`
  - `FootnoteRule`
  - `MathRule`
  - `RawContentRule`
  - `TableRule`
  - `TypographyRule`

which matches closely with the default syntax supported in `Markdown.@md_str`.

!!! info

    The `DollarMathRule` is not enabled since it conflicts with the
    interpolation syntax. Use double backticks and `math` language literal
    blocks for maths that is provided by the `MathRule`.

A custom `Parser` can be invoked when using `cm""` by providing a suffix
to the macro call, for example:

```julia
more = "more"
cm"Some **\$(uppercase(more))** text."none
```

where the suffixed `none` will invoke a basic `Parser` with no additional
syntax rules `enabled!`. To use your own custom parser, for example to only
enable the `TypographyRule`, you can suffix the call with a named function from
the current module's global scope that returns the `Parser` object with the
required rules enabled:

```julia
custom() = enable!(Parser(), TypographyRule())
```

It can then be used as

```julia
str = "custom"
cm"A '\$(titlecase(str))' parser..."custom
```
"""
macro cm_str(str, name = "jmd")
    ji = JuliaInterpolationRule()
    parser = _init_parser(__module__, name)
    enable!(parser, ji)
    multiline = occursin("\n", str)
    ast = parser(str; source=String(__source__.file), line=__source__.line + Int(multiline))
    # We construct an expression that first, one-by-one and in order, evaluates each
    # of the interpolated expressions that appeared in the string, adds them to a
    # list, and finally calls _interp! on it to update the AST with the evaluated
    # values.
    expr = Expr(:block, :(values = []))
    for v in ji.captured
        push!(expr.args, :(let x = $(esc(v.ex)); push!(values, x); end))
    end
    push!(expr.args, :(_interp!($ast, $(ji.captured), values)))
    return expr
end

function _interp!(ast::Node, refs::Vector, values::Vector)
    # Copy the parsed AST and replace any interpolations with their values.
    replace(t::JuliaExpression) = JuliaValue(t.ex, values[t.pos])
    replace(@nospecialize(other)) = other
    return copy_tree(replace, ast)
end

function _init_parser(mod::Module, name::AbstractString)::Parser
    options = (
        jmd = function ()
            p = Parser()
            enable!(p, [
                AdmonitionRule(),
                AttributeRule(),
                AutoIdentifierRule(),
                CitationRule(),
                FootnoteRule(),
                MathRule(),
                RawContentRule(),
                TableRule(),
                TypographyRule(),
            ])
            return p
        end,
        none = () -> Parser()
    )
    s = Symbol(name)
    if isdefined(mod, s)
        obj = getfield(mod, s)
        if isa(obj, Function)
            try
                p = obj()
                isa(p, Parser) && return p
            catch
            end
        end
    end
    return get(options, s, Parser)()
end

#
# Writers
#

# JuliaExpression

function write_html(jv::JuliaExpression, rend, node, enter)
    tag(rend, "span", attributes(rend, node, ["class" => "julia-expr"]))
    print(rend.buffer, sprint(print, '$', "($(jv.ex))"))
    tag(rend, "/span")
end

function write_latex(jv::JuliaExpression, rend, node, enter)
    print(rend.buffer, "\\texttt{", '\\', '$', '(')
    latex_escape(rend, string(jv.ex))
    print(rend.buffer, ")}")
end

function write_term(jv::JuliaExpression, rend, node, enter)
    style = crayon"yellow"
    push_inline!(rend, style)
    print_literal(rend, style, sprint(print, '$', "($(jv.ex))"), inv(style))
    pop_inline!(rend)
end

# JuliaValue

function write_html(jv::JuliaValue, rend, node, enter)
    tag(rend, "span", attributes(rend, node, ["class" => "julia-value"]))
    print(rend.buffer, sprint(_showas, MIME("text/html"), jv.ref; context=rend.buffer))
    tag(rend, "/span")
end

function write_latex(jv::JuliaValue, rend, node, enter)
    print(rend.buffer, sprint(_showas, MIME("text/latex"), jv.ref))
end

function _showas(io::IO, m::MIME, collection::Union{Tuple,AbstractArray,Base.Generator})
    for each in collection
        _showas(io, m, each)
        print(io, " ")
    end
end
_showas(io::IO, m::MIME, obj) = showable(m, obj) ? show(io, m, obj) : print(io, obj)

function write_term(jv::JuliaValue, rend, node, enter)
    style = crayon"yellow"
    push_inline!(rend, style)
    print_literal(rend, style, sprint(print, jv.ref), inv(style))
    pop_inline!(rend)
end

# Markdown output should be roundtrip-able, so printout the interpolated
# expression rather than it's value.
write_markdown(jv::Union{JuliaExpression,JuliaValue}, rend, node, ent) = print(rend.buffer, '$', "($(jv.ex))")
