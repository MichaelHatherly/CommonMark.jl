"""
    AutoIdentifierRule()

Automatically generate IDs for headings.

Not enabled by default. IDs are slugified from heading text. Duplicate IDs
get numeric suffixes. An ID that [`AttributeRule`](@ref) sets from the block
attributes above a heading is kept, while an attribute written on the heading
line is part of the heading's text and so lands in the slug.

```markdown
# My Heading        → <h1 id="my-heading">
# My Heading        → <h1 id="my-heading-1"> (duplicate)
{#my-id}
# Custom            → <h1 id="my-id"> (with AttributeRule)
# Custom {#my-id}   → <h1 id="custom-my-id"> (with AttributeRule)
```
"""
struct AutoIdentifierRule
    refs::IdDict{Node, Dict{String, Int}}
    AutoIdentifierRule(refs = IdDict()) = new(refs)
end

reset_rule!(r::AutoIdentifierRule) = (empty!(r.refs); nothing)

# A heading's id waits for its inlines. The source line spells entities and
# escapes for characters the heading's text holds directly, so an id taken from
# the source would change every time the document was written back out.
inline_modifier(rule::AutoIdentifierRule) = Rule(100) do parser, block
    block.t isa Heading || return nothing
    hasmeta(block, "id") || setmeta!(block, "id", slugify(heading_text(block)))
    return number_identifier!(rule, block)
end

# Any other block takes its id from AttributeRule, which has already set it by
# the time the block is entered.
block_modifier(rule::AutoIdentifierRule) = Rule(100) do parser, block
    block.t isa Heading || number_identifier!(rule, block)
    return nothing
end

# An id that repeats within a document takes a counter to tell it apart.
function number_identifier!(rule::AutoIdentifierRule, block::Node)
    hasmeta(block, "id") || return nothing
    counter = get!(() -> Dict{String, Int}(), rule.refs, document(block))
    id = getmeta(block, "id", "")
    n = counter[id] = get!(counter, id, 0) + 1
    setmeta!(block, "id", n == 1 ? id : "$id-$(n - 1)")
    return nothing
end

# The text a heading renders, with each break standing in for the whitespace
# that separated the lines it joined.
function heading_text(node::Node)
    io = IOBuffer()
    for (child, entering) in node
        entering || continue
        if child.t isa SoftBreak || child.t isa LineBreak
            print(io, ' ')
        else
            print(io, child.literal)
        end
    end
    return String(take!(io))
end

# Modelled on pandoc's algorithm. A slug is derived text rather than parsed
# source, so whitespace here is Unicode's definition, wider than the spec's
# `WHITESPACE`.
function slugify(str::AbstractString)
    str = lowercase(strip(str))
    str = replace(str, r"\s+" => "-")
    str = replace(str, r"[^\p{L}\p{N}\-]+" => "")
    str = lstrip(c -> isnumeric(c) || ispunct(c), str)
    return isempty(str) ? "section" : str
end
