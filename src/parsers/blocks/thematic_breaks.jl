struct ThematicBreak <: AbstractBlock end

accepts_lines(::ThematicBreak) = false

continue_(::ThematicBreak, ::Parser, ::Node) = 1

finalize(::ThematicBreak, ::Parser, ::Node) = nothing

can_contain(::ThematicBreak, t) = false

function thematic_break(p::Parser, container::Node)
    if !p.indented && occursin(reThematicBreak, rest_from_nonspace(p))
        close_unmatched_blocks(p)
        add_child(p, ThematicBreak(), p.next_nonspace)
        advance_to_end(p)
        return 2
    end
    return 0
end

struct ThematicBreakRule end
block_rule(::ThematicBreakRule) = Rule(thematic_break, 6, "*-_")
