using Literate

gen_results() =
    for file in readdir(@__DIR__, join = true)
        if endswith(file, ".jl") && file != @__FILE__
            Literate.markdown(
                file,
                joinpath(@__DIR__, "results"),
                execute = true,
                flavor = Literate.CommonMarkFlavor(),
                credit = false,  # It's in the readme and the TOMLs
                postprocess = rm_newlines,
            )
        end
    end

"Remove the extraneous newlines at the end of output cells"
rm_newlines(md) =
    replace(md, "\n\n````\n" => "\n````\n")


ENV["JULIA_DEBUG"] = "Literate"
# ↪ Running `startup-time.jl` takes a while.
#   We set the above flag to get feedback while running this `make.jl`
#   (It makes the code block currently being executed get printed).

gen_results()
