block_rule(::Any) = nothing
block_modifier(::Any) = nothing
inline_rule(::Any) = nothing
inline_modifier(::Any) = nothing

# Delimiter-based inline hooks
delim_nodes(::Any) = nothing
flanking_rule(::Any) = nothing
uses_odd_match(::Any) = nothing

"""
The spellings a rule gives meaning to in text that the core spec reads as plain
text, such as the `--` that [`TypographyRule`](@ref) turns into an en dash.

Text is written back out with the first character of each spelling escaped, so
that a document parsed with the rule enabled reparses the same way.

A rule that declares nothing claims the characters its own parsers trigger on,
which escapes more of the text than the rule needs but never less. Naming the
spellings narrows that: `["~~"]` escapes a tilde before another tilde, where the
trigger character alone escapes every tilde. A rule whose syntax cannot be
mistaken for text, such as one that reads only the first line of a document,
declares `String[]` to claim nothing.
"""
claimed_syntax(rule) = trigger_syntax(rule)

# The characters the Markdown writer escapes in text however the parser was
# built, so a rule triggering on one of them has nothing to add.
const ALWAYS_ESCAPED = ('`', '\\', '[', ']')

# The characters a rule's own parsers are dispatched on. A rule that reads text
# the core spec passes over reaches it through one of these, so they bound what
# the rule can claim.
function trigger_syntax(rule)
    claims = String[]
    for hook in (block_rule, inline_rule)
        hooked = hook(rule)
        hooked === nothing && continue
        for r in (hooked isa Rule ? (hooked,) : hooked)
            r === nothing && continue
            for c in r.triggers
                c in ALWAYS_ESCAPED || push!(claims, string(c))
            end
        end
    end
    return unique!(claims)
end

"""
The spellings claimed by `rules` wherever they appear in text.
"""
claimed_syntax(rules::Union{Tuple, Vector}) = gather_claims(rules, !opens_blocks_only)

"""
The spellings claimed by `rules` at the start of a line, where a block opens and
nowhere else. A rule that reads only blocks claims its spellings here, so a
definition list's `: ` is escaped where it would open a definition and left
alone where it punctuates a sentence.
"""
claimed_line_syntax(rules::Union{Tuple, Vector}) = gather_claims(rules, opens_blocks_only)

function gather_claims(rules::Union{Tuple, Vector}, wanted)
    claims = String[]
    for rule in rules
        # The core spec's own syntax is escaped by the rules of the spec, which
        # read the text around a character rather than the character alone.
        is_core_rule(rule) && continue
        wanted(rule) || continue
        append!(claims, claimed_syntax(rule))
    end
    return unique!(claims)
end

is_core_rule(rule) =
    ruleoccursin(rule, COMMONMARK_BLOCK_RULES) || ruleoccursin(rule, COMMONMARK_INLINE_RULES)

# A rule with no inline parser reads its syntax only where a block can open.
opens_blocks_only(rule) = block_rule(rule) !== nothing && inline_rule(rule) === nothing

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
            p.inline_parser.trigger_table[Int(trigger) + 1] = true
        end
    end
    return p
end
enable!(p::AbstractParser, fn, ::Nothing) = p
enable!(p::AbstractParser, fn, rules::Union{Tuple, Vector}) =
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
    rebuild_claimed_syntax!(p)
    return p
end

# A fresh vector rather than one cleared in place, so a document already parsed
# keeps the claims it was parsed with.
function rebuild_claimed_syntax!(p::AbstractParser)
    p.claimed = claimed_syntax(p.rules)
    p.claimed_line = claimed_line_syntax(p.rules)
    return p
end

enable!(p::AbstractParser, rules::Union{Tuple, Vector}) =
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
function disable!(p::AbstractParser, rules::Union{Tuple, Vector})
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
    rebuild_claimed_syntax!(p)
    return enable!(p, rules_kept)
end
disable!(p::AbstractParser, rule) = disable!(p, [rule])

reset_rules!(p::AbstractParser) = (foreach(reset_rule!, p.rules); p)

"""
Clear the state a rule gathered while parsing a document, so that the next
document does not resolve against it. A rule holding no such state needs no
method here.
"""
reset_rule!(rule) = nothing
