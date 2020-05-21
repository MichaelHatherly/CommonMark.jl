accepts_lines(::Heading) = false

continue_(::Heading, ::Parser, ::Node) = 1

finalize(::Heading, ::Parser, ::Node) = nothing

can_contain(::Heading, t) = false

function atx_heading(parser::Parser, container::Node)
    if !parser.indented
        m = Base.match(reATXHeadingMarker, SubString(parser.current_line, parser.next_nonspace))
        if m !== nothing
            advance_next_nonspace(parser)
            advance_offset(parser, length(m.match), false)
            close_unmatched_blocks(parser)
            container = add_child(parser, Heading(), parser.next_nonspace)
            # number of #s
            container.t.level = length(strip(m.match))
            # remove trailing ###s
            container.string_content = replace(replace(SubString(parser.current_line, parser.offset), r"^[ \t]*#+[ \t]*$" => ""), r"[ \t]+#+[ \t]*$" => "")
            advance_offset(parser, length(parser.current_line) - parser.offset + 1, false)
            return 2
        end
    end
    return 0
end

function setext_heading(parser::Parser, container::Node)
    if !parser.indented && container.t isa Paragraph
        m = Base.match(reSetextHeadingLine, SubString(parser.current_line, parser.next_nonspace))
        if m !== nothing
            close_unmatched_blocks(parser)
            # resolve reference link definitiosn
            while get(container.string_content, 1, nothing) == '['
                pos = parse_reference(parser.inline_parser, container.string_content, parser.refmap)
                if pos == 0
                    break
                end
                container.string_content = container.string_content[pos+1:end]
            end
            if !isempty(container.string_content)
                heading = Node(Heading(), container.sourcepos)
                heading.t.level = m.match[1] == '=' ? 1 : 2
                heading.string_content = container.string_content
                insert_after(container, heading)
                unlink(container)
                parser.tip = heading
                advance_offset(parser, length(parser.current_line) - parser.offset + 1, false)
                return 2
            else
                return 0
            end
        end
    end
    return 0
end

