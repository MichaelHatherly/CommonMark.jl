# Pre-1.9 extension compat. Loads ext/CommonMarkMarkdownExt.jl when Markdown loads.
module ExtensionLoader

const MARKDOWN = Base.PkgId(Base.UUID("d6f4376e-aef5-505a-96c1-9c027394607a"), "Markdown")
const EXTCODE = read(joinpath(@__DIR__, "..", "ext", "CommonMarkMarkdownExt.jl"), String)
const LOADED = Ref(false)

function load_ext(pkg::Base.PkgId)
    pkg === MARKDOWN || return
    LOADED[] && return
    LOADED[] = true
    Base.invokelatest() do
        Core.eval(@__MODULE__, :(const Markdown = $(Base.loaded_modules[MARKDOWN])))
        include_string(@__MODULE__, EXTCODE, "CommonMarkMarkdownExt.jl")
    end
end

function __init__()
    if haskey(Base.loaded_modules, MARKDOWN)
        load_ext(MARKDOWN)
    else
        push!(Base.package_callbacks, load_ext)
    end
end

end
