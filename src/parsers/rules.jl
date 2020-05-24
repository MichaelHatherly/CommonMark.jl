block_rule(::Any) = nothing
block_modifier(::Any) = nothing
inline_rule(::Any) = nothing
inline_modifier(::Any) = nothing

struct Rule
    fn::Function
    priority::Float64
    triggers::String

    Rule(fn, priority, triggers="") = new(fn, priority, triggers)
end

enable!(parser, extension) = toggle!(true, parser, extension)
disable!(parser, extension) = toggle!(false, parser, extension)

enable!(parser, xs::Union{Vector, Tuple}) = foreach(x -> enable!(parser, x), xs)
disable!(parser, xs::Union{Vector, Tuple}) = foreach(x -> disable!(parser, x), xs)

function toggle!(on::Bool, parser::AbstractParser, extension)
    toggle!(on, parser, block_rule, extension)
    toggle!(on, parser, block_modifier, extension)
    toggle!(on, parser, inline_rule, extension)
    toggle!(on, parser, inline_modifier, extension)
    return parser
end

toggle!(on, p, fn, extension) = toggle!(on, p, fn, fn(extension))
toggle!(on, p, fn, rules::Tuple) = foreach(rule -> toggle!(on, p, fn, rule), rules)
toggle!(::Bool, ::AbstractParser, ::Function, ::Nothing) = nothing

function toggle!(on, p::AbstractParser, fn, r::Rule)
    on ? (p.priorities[r.fn] = r.priority) : delete!(p.priorities, r.fn)
    for trigger in (isempty(r.triggers) ? "\0" : r.triggers)
        λs = get_funcs(p, fn, trigger)
        if on
            r.fn in λs || push!(λs, r.fn)
            sort!(λs; by=λ -> p.priorities[λ])
        else
            filter!(f -> f != r.fn, λs)
        end
    end
end

get_funcs(p, ::typeof(block_rule), c)  = get!(() -> Function[], p.block_starts, c)
get_funcs(p, ::typeof(inline_rule), c) = get!(() -> Function[], p.inline_parser.inline_parsers, c)

get_funcs(p, ::typeof(block_modifier), _)  = p.modifiers
get_funcs(p, ::typeof(inline_modifier), _) = p.inline_parser.modifiers

function clear_rules!(p::AbstractParser)
    empty!(p.priorities)
    empty!(p.block_starts)
    empty!(p.modifiers)
    empty!(p.inline_parser.inline_parsers)
    empty!(p.inline_parser.modifiers)
    return p
end

