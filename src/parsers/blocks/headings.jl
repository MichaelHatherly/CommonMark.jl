mutable struct Heading <: AbstractBlock
    level::Int
    Heading() = new(0)
end

is_container(::Heading) = true

accepts_lines(::Heading) = false

continue_(::Heading, ::Parser, ::Node) = 1

finalize(::Heading, ::Parser, ::Node) = nothing

can_contain(::Heading, t) = false

function atx_heading(parser::Parser, container::Node)
    if !parser.indented
        m = Base.match(reATXHeadingMarker, rest_from_nonspace(parser))
        if m !== nothing
            advance_next_nonspace(parser)
            advance_offset(parser, length(m.match), false)
            close_unmatched_blocks(parser)
            container = add_child(parser, Heading(), parser.next_nonspace)
            # number of #s
            container.t.level = length(strip(m.match))
            # remove trailing ###s
            container.literal = replace(
                replace(rest(parser), r"^[ \t]*#+[ \t]*$" => ""),
                r"[ \t]+#+[ \t]*$" => "",
            )
            advance_to_end(parser)
            return 2
        end
    end
    return 0
end

struct AtxHeadingRule end
block_rule(::AtxHeadingRule) = Rule(atx_heading, 2, "#")

function setext_heading(parser::Parser, container::Node)
    if !parser.indented && container.t isa Paragraph
        m = Base.match(reSetextHeadingLine, rest_from_nonspace(parser))
        if m !== nothing
            close_unmatched_blocks(parser)
            # resolve reference link definitiosn
            while get(container.literal, 1, nothing) == '['
                pos =
                    parse_reference(parser.inline_parser, container.literal, parser.refmap)
                if pos == 0
                    break
                end
                container.literal = container.literal[pos+1:end]
            end
            if !isempty(container.literal)
                heading = Node(Heading(), container.sourcepos)
                heading.t.level = m.match[1] == '=' ? 1 : 2
                heading.literal = container.literal
                insert_after(container, heading)
                unlink(container)
                parser.tip = heading
                advance_to_end(parser)
                return 2
            else
                return 0
            end
        end
    end
    return 0
end

struct SetextHeadingRule end
block_rule(::SetextHeadingRule) = Rule(setext_heading, 5, "-=")
