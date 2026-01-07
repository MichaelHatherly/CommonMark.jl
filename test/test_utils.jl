@testmodule Utilities begin
    using CommonMark
    using Test
    using ReferenceTests

    function test_all_formats(test_dir::String)
        function (base_name, ast, reference_dir; kws...)
            test_all_formats(test_dir, base_name, ast, reference_dir; kws...)
        end
    end

    # Multi-format reference testing helper with explicit directory
    function test_all_formats(
        test_dir::String,
        base_name::String,
        ast,
        reference_dir::String;
        formats = [:html, :latex, :markdown, :term, :typst],
        env = nothing,
    )
        format_specs = Dict(
            :html => (html, "html.txt"),
            :latex => (latex, "tex"),
            :markdown => (markdown, "md"),
            :term => (term, "txt"),
            :typst => (typst, "typ"),
        )

        for format in formats
            func, ext = format_specs[format]
            filename =
                joinpath(test_dir, "references", reference_dir, "$(base_name).$(ext)")
            output = isnothing(env) ? func(ast) : func(ast, env)
            @test_reference filename ReferenceTests.Text(output)
        end
    end

    function test_single_format(test_dir::String, parser)
        function (filename, text, format)
            _test_single_format(test_dir, filename, text, parser, format)
        end
    end

    # Single-format reference testing helper with explicit directory
    function _test_single_format(
        test_dir::String,
        filename::String,
        text::String,
        parser,
        format_func,
    )
        ast = parser(text)
        output = format_func(ast)
        full_path = joinpath(test_dir, filename)
        @test_reference full_path ReferenceTests.Text(output)
    end

    # Reference test with custom processing
    function test_format_with_processor(
        test_dir::String,
        filename::String,
        text::String,
        parser,
        format_func,
        processor,
    )
        ast = parser(text)
        output = format_func(ast)
        processed = processor(output)
        full_path = joinpath(test_dir, filename)
        @test_reference full_path ReferenceTests.Text(processed)
    end

    # Parser creation helpers
    create_parser() = Parser()
    create_parser(extension) = enable!(Parser(), extension)
    create_parser(extensions::Vector) = enable!(Parser(), extensions)

    # Normalization utilities
    normalize_line_endings(s::String) = replace(s, "\r\n" => "\n")

    # Constants
    const FORMAT_EXTENSIONS = Dict(
        :html => "html.txt",
        :latex => "tex",
        :markdown => "md",
        :term => "txt",
        :typst => "typ",
    )

    const FORMAT_FUNCTIONS = Dict(
        :html => html,
        :latex => latex,
        :markdown => markdown,
        :term => term,
        :typst => typst,
    )

    # Export all functions and macros
    export test_all_formats,
        test_single_format,
        test_format_with_processor,
        @test_all_formats,
        @test_single_format,
        @test_format_with_processor,
        create_parser,
        normalize_line_endings,
        FORMAT_EXTENSIONS,
        FORMAT_FUNCTIONS
end
