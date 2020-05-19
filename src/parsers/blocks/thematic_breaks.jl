accepts_lines(::ThematicBreak) = false

continue_(::ThematicBreak, ::Parser, ::Node) = 1

finalize(::ThematicBreak, ::Parser, ::Node) = nothing

can_contain(::ThematicBreak, t) = false

function thematic_break(p::Parser, container::Node)
    if !p.indented && occursin(reThematicBreak, SubString(p.current_line, p.next_nonspace))
        close_unmatched_blocks(p)
        add_child(p, ThematicBreak(), p.next_nonspace)
        advance_offset(p, length(p.current_line) - p.offset + 1, false)
        return 2
    end
    return 0
end

