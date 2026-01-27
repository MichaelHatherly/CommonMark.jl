# Pre-1.9 extension compat. Loads extensions when their trigger packages load.
module ExtensionLoader

const MARKDOWN_PKG =
    Base.PkgId(Base.UUID("d6f4376e-aef5-505a-96c1-9c027394607a"), "Markdown")
const MARKDOWNAST_PKG =
    Base.PkgId(Base.UUID("d0879d2d-cac2-40c8-9cee-1863dc0c7391"), "MarkdownAST")

# Read at compile time for relocatability
const MARKDOWN_EXT =
    read(joinpath(@__DIR__, "..", "ext", "CommonMarkMarkdownExt.jl"), String)
const MARKDOWNAST_EXT =
    read(joinpath(@__DIR__, "..", "ext", "CommonMarkMarkdownASTExt.jl"), String)

const EXTENSIONS = Dict(
    MARKDOWN_PKG => (MARKDOWN_EXT, "CommonMarkMarkdownExt.jl", Ref(false)),
    MARKDOWNAST_PKG => (MARKDOWNAST_EXT, "CommonMarkMarkdownASTExt.jl", Ref(false)),
)

function load_ext(pkg::Base.PkgId)
    haskey(EXTENSIONS, pkg) || return
    extcode, extfile, loaded = EXTENSIONS[pkg]
    loaded[] && return
    loaded[] = true
    mod = Module(Symbol(:CommonMarkExtensionLoader_, pkg.name))
    Base.invokelatest() do
        Core.eval(mod, :(const $(Symbol(pkg.name)) = $(Base.loaded_modules[pkg])))
        include_string(mod, extcode, extfile)
    end
end

function __init__()
    ccall(:jl_generating_output, Cint, ()) == 1 && return
    for pkg in keys(EXTENSIONS)
        if haskey(Base.loaded_modules, pkg)
            load_ext(pkg)
        end
    end
    push!(Base.package_callbacks, load_ext)
end

end
