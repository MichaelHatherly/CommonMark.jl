using Documenter, CommonMark

makedocs(
    sitename = "CommonMark.jl",
    format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
    modules = [CommonMark],
    pages = [
        "Home" => "index.md",
        "Core Rules" => "core.md",
        "Extensions" => "extensions.md",
        "Developing Extensions" => "developing.md",
        "API Reference" => "api.md",
    ],
)

deploydocs(repo = "github.com/MichaelHatherly/CommonMark.jl.git", push_preview = true)
