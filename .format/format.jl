import Pkg
Pkg.instantiate()

import JuliaFormatter

JuliaFormatter.format(dirname(@__DIR__))
