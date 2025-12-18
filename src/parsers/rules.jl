block_rule(::Any) = nothing
block_modifier(::Any) = nothing
inline_rule(::Any) = nothing
inline_modifier(::Any) = nothing

# Delimiter-based inline hooks
delim_nodes(::Any) = nothing
flanking_rule(::Any) = nothing
uses_odd_match(::Any) = nothing

struct Rule
    fn::Function
    priority::Float64
    triggers::String

    Rule(fn, priority, triggers = "") = new(fn, priority, triggers)
end

# Two parsing rules are generally considered the same (for the purposes of enabling and
# disabling them in the parser) if the types match --- the values on any fields do not
# matter. In case this is not correct for a rule, the two-argument is_same_rule should be
# appropriately overloaded. Some possible cases where this might be necessary:
#   (1) A rule with type parameters, where even when the type parameter values are
#       different, the rules should still be considered the same.
#   (2) A rule which can be included multiple times if some field has a different value.
is_same_rule(x, y) = typeof(x) == typeof(y)
is_same_rule(x) = y -> is_same_rule(x, y)
ruleoccursin(needle, haystack) = any(is_same_rule(needle), haystack)
ruleoccursin(haystack) = needle -> ruleoccursin(needle, haystack)

function enable!(p::AbstractParser, fn, rule::Rule)
    p.priorities[rule.fn] = rule.priority
    for trigger in (isempty(rule.triggers) ? "\0" : rule.triggers)
        λs = get_funcs(p, fn, trigger)
        if rule.fn ∉ λs
            push!(λs, rule.fn)
            sort!(λs; by = λ -> p.priorities[λ])
        end
        # Update ASCII trigger lookup table for inline rules
        if fn === inline_rule && trigger <= '\x7f'
            p.inline_parser.trigger_table[Int(trigger)+1] = true
        end
    end
    return p
end
enable!(p::AbstractParser, fn, ::Nothing) = p
enable!(p::AbstractParser, fn, rules::Union{Tuple,Vector}) =
    (foreach(r -> enable!(p, fn, r), rules); p)
enable!(p::AbstractParser, fn, rule) = enable!(p, fn, fn(rule))

"""
    enable!(parser, rule)
    enable!(parser, rules)

Enable a parsing rule or collection of rules in the parser.

Rules can be core CommonMark rules (e.g., [`AtxHeadingRule`](@ref)) or extension
rules (e.g., [`TableRule`](@ref), [`AdmonitionRule`](@ref)).

Returns the parser for method chaining.

# Examples

```julia
p = Parser()
enable!(p, TableRule())
enable!(p, [FootnoteRule(), AdmonitionRule()])
```

See also: [`disable!`](@ref), [`Parser`](@ref)
"""
function enable!(p::AbstractParser, rule)
    if ruleoccursin(rule, p.rules)
        error("$rule is already enabled in the parser")
    end
    enable!(p, inline_rule, rule)
    enable!(p, inline_modifier, rule)
    enable!(p, block_rule, rule)
    enable!(p, block_modifier, rule)
    # Register delimiter-based inline hooks
    nodes = delim_nodes(rule)
    if nodes !== nothing
        merge!(p.inline_parser.delim_nodes, nodes)
        rebuild_delim_lookups!(p.inline_parser)
    end
    flank = flanking_rule(rule)
    if flank !== nothing
        char, mode = flank
        # First registration wins
        haskey(p.inline_parser.flanking_rules, char) ||
            (p.inline_parser.flanking_rules[char] = mode)
    end
    odd = uses_odd_match(rule)
    odd !== nothing && push!(p.inline_parser.odd_match_chars, odd)
    push!(p.rules, rule)
    return p
end

enable!(p::AbstractParser, rules::Union{Tuple,Vector}) =
    (foreach(r -> enable!(p, r), rules); p)

get_funcs(p, ::typeof(block_rule), c) = get!(() -> Function[], p.block_starts, c)
get_funcs(p, ::typeof(inline_rule), c) =
    get!(() -> Function[], p.inline_parser.inline_parsers, c)

get_funcs(p, ::typeof(block_modifier), _) = p.modifiers
get_funcs(p, ::typeof(inline_modifier), _) = p.inline_parser.modifiers

"""
    disable!(parser, rule)
    disable!(parser, rules)

Disable a parsing rule or collection of rules from the parser.

This removes the specified rules and re-enables all remaining rules.
Useful for removing default CommonMark behavior.

Returns the parser for method chaining.

# Examples

```julia
p = Parser()
disable!(p, SetextHeadingRule())  # Only allow ATX-style headings
disable!(p, [HtmlBlockRule(), HtmlInlineRule()])  # Disable raw HTML
```

See also: [`enable!`](@ref), [`Parser`](@ref)
"""
function disable!(p::AbstractParser, rules::Union{Tuple,Vector})
    rules_kept = filter(!ruleoccursin(rules), p.rules)
    empty!(p.priorities)
    empty!(p.block_starts)
    empty!(p.modifiers)
    empty!(p.inline_parser.inline_parsers)
    empty!(p.inline_parser.modifiers)
    empty!(p.inline_parser.delim_nodes)
    empty!(p.inline_parser.flanking_rules)
    empty!(p.inline_parser.odd_match_chars)
    empty!(p.inline_parser.delim_chars)
    empty!(p.inline_parser.delim_counts)
    empty!(p.inline_parser.delim_max)
    fill!(p.inline_parser.trigger_table, false)
    empty!(p.rules)
    return enable!(p, rules_kept)
end
disable!(p::AbstractParser, rule) = disable!(p, [rule])

reset_rules!(p::AbstractParser) = (foreach(reset_rule!, p.rules); p)
reset_rule!(rule) = nothing
