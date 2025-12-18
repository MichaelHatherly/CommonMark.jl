struct FrontMatter <: AbstractBlock
    fence::String
    data::Dict{String,Any}
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
    ln = rest_from_nonspace(parser)
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
    finalize_literal!(block)
    _, rest = split(block.literal, '\n'; limit = 2)
    block.literal = rest
    return nothing
end

can_contain(t::FrontMatter) = false

function parse_front_matter(parser::Parser, container::Node)
    if parser.line_number === 1 && !parser.indented && container.t isa Document
        m = Base.match(reFrontMatter, rest_from_nonspace(parser))
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

"""
    FrontMatterRule(; yaml=identity, toml=identity, json=identity)

Parse YAML, TOML, or JSON front matter at document start.

Not enabled by default. Front matter is delimited by `---` (YAML), `+++` (TOML),
or `;;;` (JSON). Pass parser functions for each format.

```markdown
---
title: My Document
author: Jane Doe
---

Document content here.
```

Use [`frontmatter`](@ref) to extract the parsed data.
"""
struct FrontMatterRule
    json::Function
    toml::Function
    yaml::Function

    function FrontMatterRule(; fs...)
        λ = str -> Dict{String,Any}()
        return new(get(fs, :json, λ), get(fs, :toml, λ), get(fs, :yaml, λ))
    end
end

block_rule(::FrontMatterRule) = Rule(parse_front_matter, 0.5, ";+-")
block_modifier(f::FrontMatterRule) =
    Rule(0.5) do parser, node
        if node.t isa FrontMatter
            fence = node.t.fence
            λ = fence == ";;;" ? f.json : fence == "+++" ? f.toml : f.yaml
            try
                merge!(node.t.data, λ(node.literal))
            catch err
                node.literal = string(err)
            end
        end
        return nothing
    end

# Frontmatter isn't displayed in the resulting output.

write_html(::FrontMatter, rend, node, enter) = nothing
write_latex(::FrontMatter, rend, node, enter) = nothing
write_term(::FrontMatter, rend, node, enter) = nothing
write_typst(::FrontMatter, rend, node, enter) = nothing

function write_markdown(f::FrontMatter, w, node, ent)
    literal(w, f.fence, "\n")
    # If frontmatter is not well-formed then it won't be round-trippable.
    literal(w, node.literal)
    literal(w, f.fence, "\n")
    linebreak(w, node)
end
