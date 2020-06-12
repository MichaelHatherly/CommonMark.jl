@testset "Extensions" begin
    include("extensions/admonitions.jl")
    include("extensions/footnotes.jl")
    include("extensions/math.jl")
    include("extensions/tables.jl")
    include("extensions/frontmatter.jl")
    include("extensions/typography.jl")
    include("extensions/raw.jl")
    include("extensions/attributes.jl")
    include("extensions/citations.jl")
end
