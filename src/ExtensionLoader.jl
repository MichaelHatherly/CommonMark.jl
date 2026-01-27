# Pre-1.9 extension compat. Loads extensions when their trigger packages load.
module ExtensionLoader

import ..CommonMark

function ext_entry(uuid, name)
    pkg = Base.PkgId(Base.UUID(uuid), name)
    file = "CommonMark$(name)Ext.jl"
    pkg => (read(joinpath(@__DIR__, "..", "ext", file), String), file, Ref(false))
end

const EXTENSIONS = Dict(
    ext_entry("d6f4376e-aef5-505a-96c1-9c027394607a", "Markdown"),
    ext_entry("d0879d2d-cac2-40c8-9cee-1863dc0c7391", "MarkdownAST"),
)

function load_ext(pkg::Base.PkgId)
    haskey(EXTENSIONS, pkg) || return
    extcode, extfile, loaded = EXTENSIONS[pkg]
    loaded[] && return
    loaded[] = true
    mod = Module(Symbol(:CommonMarkExtensionLoader_, pkg.name))
    Base.invokelatest() do
        Core.eval(mod, :(const CommonMark = $CommonMark))
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
