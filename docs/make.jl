using Documenter, CommonMark

# Patch Documenter's parsedoc to remove Markdown.MD type assertion.
# This allows LazyCommonMarkDoc to pass through instead of triggering TypeError.
@eval Documenter.DocSystem begin
    function parsedoc(docstr::DocStr)
        md = try
            Base.Docs.parsedoc(docstr)  # No ::Markdown.MD assertion
        catch exception
            @error """
            parsedoc failed to parse a docstring.
            """ exception docstr.data collect(docstr.text) docstr.object
            rethrow(exception)
        end
        # Unwrap double-wrapped Markdown.MD (existing Documenter logic)
        if md isa Markdown.MD
            while length(md.content) == 1 && isa(first(md.content), Markdown.MD)
                inner_md = only(md.content)
                inner_md.meta = md.meta
                md = inner_md
            end
        end
        return md
    end
end

makedocs(
    sitename = "CommonMark.jl",
    format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
    modules = [CommonMark],
    pages = [
        "Home" => "index.md",
        "Core Rules" => "core.md",
        "Extensions" => "extensions.md",
        "Building ASTs" => "ast.md",
        "Transforms" => "transforms.md",
        "Developing Extensions" => "developing.md",
        "API Reference" => "api.md",
    ],
)

deploydocs(repo = "github.com/MichaelHatherly/CommonMark.jl.git", push_preview = true)
