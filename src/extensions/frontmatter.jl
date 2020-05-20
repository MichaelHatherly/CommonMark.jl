struct FrontMatter <:AbstractBlock
    fence::String
    data::Dict{String, Any}
    FrontMatter(fence) = new(fence, Dict())
end

accepts_lines(::FrontMatter) = true

# GitLab uses the following:
#
# * `---` for YAML
# * `+++` for TOML
# * `;;;` for JSON
#
const reFrontMatter = r"^(\-{3}|\+{3}|;{3})$"

function continue_(frontmatter::FrontMatter, parser::Parser, container::Node)
    ln = SubString(parser.current_line, parser.next_nonspace)
    if !parser.indented
        m = Base.match(reFrontMatter, SubString(ln, parser.next_nonspace))
        if m !== nothing && m.match == frontmatter.fence
            finalize(parser, container, parser.line_number)
            return 2
        end
    end
    return 0
end

function finalize(frontmatter::FrontMatter, parser::Parser, block::Node)
    _, rest = split(block.string_content, '\n'; limit=2)
    # Frontmatter is a type of fenced literal, so we store their parsers in the
    # .fenced_literals dict along with any for backtick fences.
    if haskey(parser.fenced_literals, frontmatter.fence)
        # Don't let errors get in our way, treat it like a markdown parser
        # would and just ignore them, kind of.
        try
            data = parser.fenced_literals[frontmatter.fence](rest)
            merge!(block.t.data, data)
            block.literal = rest
        catch err
            # At least save the error so we can work out what happened.
            block.literal = string(err)
        end
    end
    block.string_content = ""
    return nothing
end

can_contain(t::FrontMatter) = false

function parse_front_matter(parser::Parser, container::Node)
    if parser.line_number === 1 && !parser.indented && container.t isa Document
        m = Base.match(reFrontMatter, SubString(parser.current_line, parser.next_nonspace))
        if m !== nothing
            close_unmatched_blocks(parser)
            container = add_child(parser, FrontMatter(m.match), parser.next_nonspace)
            advance_next_nonspace(parser)
            advance_offset(parser, length(m.match), false)
            return 2
        end
    end
    return 0
end

# Frontmatter isn't displayed in the resulting output.

html(::FrontMatter, rend, node, enter) = nothing
latex(::FrontMatter, rend, node, enter) = nothing
term(::FrontMatter, rend, node, enter) = nothing
