struct Emph <: AbstractInline end

is_container(::Emph) = true

struct Strong <: AbstractInline end

is_container(::Strong) = true

parse_asterisk(parser, block) = handle_delim(parser, '*', block)
parse_underscore(parser, block) = handle_delim(parser, '_', block)

function scan_delims(parser::InlineParser, c::AbstractChar)
    numdelims = 0
    startpos = position(parser)

    c_before = tryprev(parser, Char, '\n')

    if c in (''', '"')
        numdelims += 1
        @assert read(parser, Char) === c
    else
        while trypeek(parser, Char) === c
            numdelims += 1
            @assert read(parser, Char) === c
        end
    end
    numdelims == 0 && return (0, false, false)

    c_after = trypeek(parser, Char, '\n')

    ws_after = Base.Unicode.isspace(c_after)
    punct_after = Base.Unicode.ispunct(c_after)
    ws_before = Base.Unicode.isspace(c_before)
    punct_before = Base.Unicode.ispunct(c_before)

    left_flanking = !ws_after && (!punct_after || ws_before || punct_before)
    right_flanking = !ws_before && (!punct_before || ws_after || punct_after)

    # Look up flanking rule from registry, default to :standard (except _ defaults to :underscore)
    flanking = get(parser.flanking_rules, c, c == '_' ? :underscore : :standard)

    can_open, can_close = if flanking == :underscore
        (left_flanking && (!right_flanking || punct_before)),
        (right_flanking && (!left_flanking || punct_after))
    elseif flanking == :permissive
        !ws_after, !ws_before
    elseif c in (''', '"')
        (left_flanking && !right_flanking), right_flanking
    else  # :standard
        left_flanking, right_flanking
    end

    seek(parser, startpos)
    return numdelims, can_open, can_close
end

function handle_delim(parser::InlineParser, cc::AbstractChar, block::Node)
    numdelims, can_open, can_close = scan_delims(parser, cc)
    numdelims === 0 && return false

    startpos = position(parser)

    seek(parser, position(parser) + numdelims) # `cc` is ASCII.
    contents = cc == ''' ? "\u2019" : cc == '"' ? "\u201C" : cc^numdelims

    node = text(contents)
    append_child(block, node)

    # Add entry to stack for this opener
    parser.delimiters = Delimiter(
        cc,
        numdelims,
        numdelims,
        node,
        parser.delimiters,
        nothing,
        can_open,
        can_close,
    )
    if parser.delimiters.previous !== nothing
        parser.delimiters.previous.next = parser.delimiters
    end
    return true
end

function remove_delimiter(parser::InlineParser, delim::Delimiter)
    if delim.previous !== nothing
        delim.previous.next = delim.next
    end
    if delim.next === nothing
        parser.delimiters = delim.previous # Top of stack.
    else
        delim.next.previous = delim.previous
    end
    return nothing
end

function remove_delimiters_between(bottom::Delimiter, top::Delimiter)
    if bottom.next !== top
        bottom.next = top
        top.previous = bottom
    end
    return nothing
end

function process_emphasis(parser::InlineParser, stack_bottom)
    # Build openers_bottom keyed by (char, count) for proper multi-count handling
    openers_bottom = Dict{Tuple{Char,Int},Union{Nothing,Delimiter}}()

    # Smart quotes use count 0 (not registered in delim_nodes)
    openers_bottom[(''', 0)] = stack_bottom
    openers_bottom[('"', 0)] = stack_bottom

    # Initialize for each registered (char, count) pair
    for ((char, count), _) in parser.delim_nodes
        openers_bottom[(char, count)] = stack_bottom
    end

    odd_match = false
    use_delims = 0

    # Find first closer above `stack_bottom`.
    closer = parser.delimiters
    while closer !== nothing && closer.previous !== stack_bottom
        closer = closer.previous
    end

    # Move forward, looking for closers, and handling each.
    while closer !== nothing
        if !closer.can_close
            closer = closer.next
        else
            closercc = closer.cc
            has_nodes = any(k -> k[1] == closercc, keys(parser.delim_nodes))

            # Skip unknown delimiters (except smart quotes handled below)
            if !has_nodes && closercc ∉ (''', '"')
                closer = closer.next
                continue
            end

            # Found emphasis closer. Now look back for first matching opener.
            opener = closer.previous
            opener_found = false

            # For chars with multiple registered counts, require compatible counts
            registered_counts = sort(
                [k[2] for k in keys(parser.delim_nodes) if k[1] == closercc],
                rev = true,
            )
            multi_count = length(registered_counts) > 1

            # For smart quotes, use count 0; otherwise use actual count
            bottom_key =
                closercc in (''', '"') ? (closercc, 0) : (closercc, closer.numdelims)
            while (
                opener !== nothing &&
                opener !== stack_bottom &&
                opener !== get(openers_bottom, bottom_key, nothing)
            )
                # Apply odd_match rule only if char is in odd_match_chars
                apply_odd_match = closercc in parser.odd_match_chars
                odd_match =
                    apply_odd_match &&
                    (closer.can_open || opener.can_close) &&
                    closer.origdelims % 3 != 0 &&
                    (opener.origdelims + closer.origdelims) % 3 == 0

                # For multi-count extension chars (not * or _), require exact match
                # Standard emphasis (* _) allows partial matching per CommonMark spec
                count_compatible = true
                if multi_count && opener.cc == closercc && closercc ∉ ('*', '_')
                    count_compatible = opener.numdelims == closer.numdelims
                end

                if opener.cc == closercc &&
                   opener.can_open &&
                   !odd_match &&
                   count_compatible
                    opener_found = true
                    break
                end
                opener = opener.previous
            end
            old_closer = closer

            if has_nodes
                if !opener_found
                    closer = closer.next
                else
                    # Calculate use_delims - find max registered for this char
                    max_delims =
                        maximum(k[2] for k in keys(parser.delim_nodes) if k[1] == closercc)
                    use_delims = min(closer.numdelims, opener.numdelims, max_delims)

                    # Find matching node type, trying smaller counts if needed
                    NodeType = get(parser.delim_nodes, (closercc, use_delims), nothing)
                    while use_delims > 0 && NodeType === nothing
                        use_delims -= 1
                        NodeType = get(parser.delim_nodes, (closercc, use_delims), nothing)
                    end

                    if NodeType === nothing
                        # No valid node type for available delimiters
                        closer = closer.next
                        continue
                    end

                    opener_inl = opener.node
                    closer_inl = closer.node

                    # Remove used delimiters from stack elements and inlines.
                    opener.numdelims -= use_delims
                    closer.numdelims -= use_delims
                    opener_inl.literal =
                        opener_inl.literal[1:length(opener_inl.literal)-use_delims]
                    closer_inl.literal =
                        closer_inl.literal[1:length(closer_inl.literal)-use_delims]

                    # Build container node
                    container = Node(NodeType())
                    container.literal = closercc^use_delims

                    tmp = opener_inl.nxt
                    while !isnull(tmp) && tmp !== closer_inl
                        nxt = tmp.nxt
                        unlink(tmp)
                        append_child(container, tmp)
                        tmp = nxt
                    end
                    insert_after(opener_inl, container)

                    # Remove elts between opener and closer in delimiters stack.
                    remove_delimiters_between(opener, closer)

                    # If opener has 0 delims, remove it and the inline.
                    if opener.numdelims == 0
                        unlink(opener_inl)
                        remove_delimiter(parser, opener)
                    end

                    if closer.numdelims == 0
                        unlink(closer_inl)
                        tempstack = closer.next
                        remove_delimiter(parser, closer)
                        closer = tempstack
                    end
                end
            elseif closercc == '''
                closer.node.literal = "\u2019"
                opener_found && (opener.node.literal = "\u2018")
                closer = closer.next
            elseif closercc == '"'
                closer.node.literal = "\u201D"
                opener_found && (opener.node.literal = "\u201C")
                closer = closer.next
            end

            if !opener_found && !odd_match
                # Set lower bound for future searches for openers
                openers_bottom[bottom_key] = old_closer.previous
                # We can remove a closer that can't be an opener, once we've
                # seen there's no matching opener.
                old_closer.can_open || remove_delimiter(parser, old_closer)
            end
        end
    end
    # Remove all delimiters
    while parser.delimiters !== nothing && parser.delimiters !== stack_bottom
        remove_delimiter(parser, parser.delimiters)
    end
end
process_emphasis(parser::InlineParser, ::Node) = process_emphasis(parser, nothing)

"""
    AsteriskEmphasisRule()

Parse emphasis using asterisks (`*` and `**`).

Enabled by default. Single for italic, double for bold.

```markdown
*italic* and **bold** and ***both***
```
"""
struct AsteriskEmphasisRule end
inline_rule(::AsteriskEmphasisRule) = Rule(parse_asterisk, 1, "*")
inline_modifier(::AsteriskEmphasisRule) = Rule(process_emphasis, 1)
delim_nodes(::AsteriskEmphasisRule) = Dict(('*', 1) => Emph, ('*', 2) => Strong)
flanking_rule(::AsteriskEmphasisRule) = ('*', :standard)
uses_odd_match(::AsteriskEmphasisRule) = '*'

"""
    UnderscoreEmphasisRule()

Parse emphasis using underscores (`_` and `__`).

Enabled by default. Single for italic, double for bold.

```markdown
_italic_ and __bold__ and ___both___
```
"""
struct UnderscoreEmphasisRule end
inline_rule(::UnderscoreEmphasisRule) = Rule(parse_underscore, 1, "_")
inline_modifier(::UnderscoreEmphasisRule) = Rule(process_emphasis, 1)
delim_nodes(::UnderscoreEmphasisRule) = Dict(('_', 1) => Emph, ('_', 2) => Strong)
flanking_rule(::UnderscoreEmphasisRule) = ('_', :underscore)
uses_odd_match(::UnderscoreEmphasisRule) = '_'
