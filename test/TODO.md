# Test Suite Refactoring TODO

This document outlines further improvements to the CommonMark.jl test suite after the migration to TestItemRunner.jl.

## Overview

The test suite has been successfully migrated to use `@testitem` macros, but there are significant opportunities to reduce code duplication and improve maintainability using the `@testmodule` feature.

## 1. Create Shared Test Utilities Module

### 1.1 Implement @testmodule Utilities

Create a new file `test/test_utils.jl` with shared utilities:

```julia
@testmodule Utilities begin
    using CommonMark
    using Test
    using ReferenceTests
    
    # Multi-format reference testing helper with explicit directory
    function test_all_formats(test_dir::String, base_name::String, ast, reference_dir::String; 
                            formats = [:html, :latex, :markdown, :term, :typst],
                            env = nothing)
        format_specs = Dict(
            :html => (html, "html.txt"),
            :latex => (latex, "tex"),
            :markdown => (markdown, "md"),
            :term => (term, "txt"),
            :typst => (typst, "typ")
        )
        
        for format in formats
            func, ext = format_specs[format]
            filename = joinpath(test_dir, "references", reference_dir, "$(base_name).$(ext)")
            output = isnothing(env) ? func(ast) : func(ast, env)
            @test_reference filename Text(output)
        end
    end
    
    # Convenience macro that automatically passes the test directory
    macro test_all_formats(base_name, ast, reference_dir, kwargs...)
        test_dir = dirname(string(__source__.file))
        esc(:(test_all_formats($test_dir, $base_name, $ast, $reference_dir, $(kwargs...))))
    end
    
    # Single-format reference testing helper with explicit directory
    function test_single_format(test_dir::String, filename::String, text::String, parser, format_func)
        ast = parser(text)
        output = format_func(ast)
        full_path = joinpath(test_dir, filename)
        @test_reference full_path Text(output)
    end
    
    # Convenience macro for single format
    macro test_single_format(filename, text, parser, format_func)
        test_dir = dirname(string(__source__.file))
        esc(:(test_single_format($test_dir, $filename, $text, $parser, $format_func)))
    end
    
    # Reference test with custom processing
    function test_format_with_processor(test_dir::String, filename::String, text::String, parser, format_func, processor)
        ast = parser(text)
        output = format_func(ast)
        processed = processor(output)
        full_path = joinpath(test_dir, filename)
        @test_reference full_path Text(processed)
    end
    
    # Convenience macro for custom processor
    macro test_format_with_processor(filename, text, parser, format_func, processor)
        test_dir = dirname(string(__source__.file))
        esc(:(test_format_with_processor($test_dir, $filename, $text, $parser, $format_func, $processor)))
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
        :typst => "typ"
    )
    
    const FORMAT_FUNCTIONS = Dict(
        :html => html,
        :latex => latex,
        :markdown => markdown,
        :term => term,
        :typst => typst
    )
    
    # Export all functions and macros
    export test_all_formats, test_single_format, test_format_with_processor,
           @test_all_formats, @test_single_format, @test_format_with_processor,
           create_parser, normalize_line_endings, FORMAT_EXTENSIONS, FORMAT_FUNCTIONS
end
```

### 1.2 Files to Refactor

The following files contain duplicated helper functions that should use the shared module:

#### Extension Tests (7 files with multi-format testing):
- [ ] `extensions/admonitions.jl` - Remove local `test_admonition()` function
- [ ] `extensions/citations.jl` - Remove local `test()` function  
- [ ] `extensions/footnotes.jl` - Remove local `test_footnote()` function
- [ ] `extensions/highlights.jl` - Remove local `test_highlight()` function
- [ ] `extensions/interpolation.jl` - Remove local `test_interpolation()` function
- [ ] `extensions/math.jl` - Remove local `test_math()` function
- [ ] `extensions/raw.jl` - Remove local `test_raw()` function
- [ ] `extensions/smartlinks.jl` - Remove local `test_smartlink()` function
- [ ] `extensions/tables.jl` - Remove local `test_table()` function
- [ ] `extensions/typography.jl` - Remove local `test_typography()` function
- [ ] `integration.jl` - Remove local `test_integration()` function
- [ ] `unicodes.jl` - Remove local `test_unicode()` function

#### Writer Tests (5 files with single-format testing):
- [ ] `writers/latex.jl` - Remove local `test()` function
- [ ] `writers/markdown.jl` - Remove local `test()` function
- [ ] `writers/notebook.jl` - Remove local `test()` function (special case with JSON processing)
- [ ] `writers/term.jl` - Remove local `test()` function
- [ ] `writers/typst.jl` - Remove local `test()` function

## 2. Specific Refactoring Patterns

### 2.1 Extension Test Refactoring Example

**Before** (in `extensions/admonitions.jl`):
```julia
function test_admonition(base_name, ast)
    formats = [
        (html, "html.txt"),
        (latex, "tex"),
        (markdown, "md"),
        (term, "txt"),
        (typst, "typ"),
    ]
    for (func, ext) in formats
        filename = "references/admonitions/$(base_name).$(ext)"
        output = func(ast)
        @test_reference filename Text(output)
    end
end
```

**After**:
```julia
@testitem "admonitions" tags = [:extensions, :admonitions] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests
    
    p = create_parser(AdmonitionRule())
    
    # Use the macro - it automatically gets the correct directory
    @test_all_formats("warning_basic", ast, "admonitions")
    
    # Or if you need to pass the directory explicitly (e.g., from a different location):
    # test_all_formats(@__DIR__, "warning_basic", ast, "admonitions")
end
```

### 2.2 Writer Test Refactoring Example

**Before** (in `writers/latex.jl`):
```julia
function test(filename, text)
    ast = p(text)
    @test_reference filename Text(latex(ast))
end
```

**After**:
```julia
@testitem "latex_writer" tags = [:writers, :latex] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests
    
    p = create_parser()
    
    # Use the macro - it automatically gets the correct directory
    @test_single_format("references/latex/code.tex", "`code`", p, latex)
end
```

## 3. Special Cases to Handle

### 3.1 Tests with Environment Parameters

Files like `citations.jl` and `smartlinks.jl` pass environment dictionaries:
```julia
env = Dict{String,Any}("references" => bib)
output = func(ast, env)
```

The shared `test_all_formats` function already supports this with the optional `env` parameter.

### 3.2 Tests with Custom Processing

`notebook.jl` needs special handling for JSON formatting:
```julia
json = notebook(ast)
pretty = JSON.json(JSON.parse(json), 2)
```

Use `test_format_with_processor` for such cases.

### 3.3 Tests with Subset of Formats

Some tests don't test all formats. The `formats` parameter allows specifying which formats to test:
```julia
test_all_formats("test_name", ast, "category", formats=[:html, :latex, :markdown])
```

## 4. Additional Improvements

### 4.1 Consolidate Parser Creation

Many files have similar parser creation patterns:
```julia
p = Parser()
enable!(p, ExtensionRule())
```

Should become:
```julia
p = create_parser(ExtensionRule())
```

### 4.2 Standardize Test Organization

Consider grouping related tests:
- [ ] Create subdirectories for better organization if needed
- [ ] Standardize test naming conventions
- [ ] Ensure consistent use of tags

### 4.3 Remove Redundant Code

- [ ] The `templates.jl` file has its own `test()` function that conflicts with others - rename to `test_template_output()`
- [ ] Remove unused imports after refactoring
- [ ] Consolidate similar test patterns

## 5. Implementation Order

1. **Phase 1**: Create the @testmodule with shared utilities
2. **Phase 2**: Refactor writer tests (simpler, fewer dependencies)
3. **Phase 3**: Refactor extension tests (more complex, some have special cases)
4. **Phase 4**: Clean up and optimize remaining tests

## 6. Testing the Refactoring

After each refactoring step:
1. Run the specific test item to ensure it still passes
2. Check that reference files are still being found correctly
3. Verify no functionality has been lost

## 7. Future Considerations

- Consider creating additional test modules for specific domains (e.g., `@testmodule ExtensionTestUtils`)
- Look into parameterized testing for similar test cases
- Consider performance implications of shared modules
- Document the test utilities for future contributors

## 8. Benefits of This Refactoring

1. **Reduced Code Duplication**: ~12 helper functions will be replaced by 3-4 shared utilities
2. **Easier Maintenance**: Changes to test patterns only need to be made in one place
3. **Consistency**: All tests will use the same patterns and conventions
4. **Better Discoverability**: New test writers can easily find and use existing utilities
5. **Smaller Test Files**: Each test file will focus on its specific test cases rather than utility functions

## Estimated Impact

- **Lines of code removed**: ~200-300 lines of duplicated helper functions
- **Files affected**: 17 test files
- **Time to implement**: 2-4 hours
- **Long-term maintenance savings**: Significant

## 9. Detailed Implementation Steps

### Step 1: Create the Utilities Module

1. Create file `test/test_utils.jl`
2. Copy the `@testmodule Utilities` code from section 1.1
3. Ensure all imports are included in the module
4. Test that the file loads without errors: `julia --project=test -e "include(\"test/test_utils.jl\")"`

### Step 2: Update Each Test File

For each file listed in section 1.2, follow this pattern:

1. **Add `setup = [Utilities]` to the @testitem declaration**
2. **Remove the local helper function(s)**
3. **Replace helper function calls with shared utility calls**
4. **Remove any duplicate imports that are now in Utilities**
5. **Run the specific test to ensure it still passes**

### Step 3: Verification Checklist

After refactoring each file:
- [ ] Test runs successfully: `julia --project=test -e "using TestItemRunner; @run_package_tests filter=ti\"test_name\""`
- [ ] All reference files are found (no file not found errors)
- [ ] Output matches expected references
- [ ] No undefined variable errors

## 10. Common Pitfalls and Solutions

### Problem: "UndefVarError: test_all_formats not defined" or "UndefVarError: @test_all_formats not defined"
**Solution**: Ensure `setup = [Utilities]` is added to the @testitem declaration

### Problem: "UndefVarError: Parser not defined"
**Solution**: The Utilities module needs `using CommonMark` at the top

### Problem: Reference files not found
**Solution**: Check that `joinpath` is used correctly in the Utilities module and that paths are relative to the test directory

### Problem: Different output format needed
**Solution**: Use the `formats` parameter: `@test_all_formats("name", ast, "dir", formats=[:html, :latex])`

## 11. File-by-File Refactoring Guide

### Extension Tests

#### admonitions.jl
```julia
# Current helper function to remove:
function test_admonition(base_name, ast)
    formats = [
        (html, "html.txt"),
        (latex, "tex"),
        (markdown, "md"),
        (term, "txt"),
        (typst, "typ"),
    ]
    for (func, ext) in formats
        filename = "references/admonitions/$(base_name).$(ext)"
        output = func(ast)
        @test_reference filename Text(output)
    end
end

# Replace calls like:
test_admonition("warning_basic", ast)
# With:
@test_all_formats("warning_basic", ast, "admonitions")
```

#### citations.jl
```julia
# Current helper function to remove:
test = function (bib, ast, base_name)
    env = Dict{String,Any}("references" => bib)
    formats = [
        (html, "html.txt"),
        (latex, "tex"),
        (markdown, "md"),
        (term, "txt"),
        (typst, "typ"),
    ]
    for (func, ext) in formats
        filename = "references/citations/$(base_name).$(ext)"
        output = func(ast, env)
        @test_reference filename Text(output)
    end
end

# Replace calls like:
test(bib, p("@unknown"), "unbracketed_unknown")
# With:
env = Dict{String,Any}("references" => bib)
@test_all_formats("unbracketed_unknown", p("@unknown"), "citations", env=env)
```

#### interpolation.jl
```julia
# Has special custom_parser() function - keep it
# Current helper to remove:
test_interpolation = function (...)
# Replace with test_all_formats calls

# Note: This file tests with a subset of formats
@test_all_formats("name", ast, "interpolation", formats=[:html, :latex, :markdown])
```

### Writer Tests

#### latex.jl
```julia
# Current helper function to remove:
function test(filename, text)
    ast = p(text)
    @test_reference filename Text(latex(ast))
end

# Replace calls like:
test("references/latex/code.tex", "`code`")
# With:
@test_single_format("references/latex/code.tex", "`code`", p, latex)
```

#### notebook.jl (Special Case)
```julia
# Current helper function to remove:
function test(filename, text)
    ast = p(text)
    json = notebook(ast)
    pretty = JSON.json(JSON.parse(json), 2)
    @test_reference filename Text(pretty)
end

# Replace with:
@test_format_with_processor("references/notebook/code.json", "`code`", p, notebook, 
                           json -> JSON.json(JSON.parse(json), 2))
```

## 12. Testing Strategy

### Phase 1: Test Utilities Module
```bash
# Create a temporary test file to verify utilities work
cat > test/test_utilities_check.jl << 'EOF'
include("test_utils.jl")

# Test that functions are accessible
@assert isdefined(Utilities, :test_all_formats)
@assert isdefined(Utilities, :test_single_format)
@assert isdefined(Utilities, :create_parser)
println("Utilities module loaded successfully!")
EOF

julia --project=test test/test_utilities_check.jl
rm test/test_utilities_check.jl
```

### Phase 2: Test Individual Files
```bash
# Test each refactored file individually
julia --project=test -e "using TestItemRunner; @run_package_tests filter=ti\"admonitions\""
julia --project=test -e "using TestItemRunner; @run_package_tests filter=ti\"latex_writer\""
# ... etc
```

### Phase 3: Run Full Test Suite
```bash
julia --project=test -e "using TestItemRunner; @run_package_tests"
```

## 13. Rollback Plan

If issues arise:
1. Git diff will show all changes
2. Can revert individual files while keeping others
3. Helper functions are independent, so partial refactoring is safe

## 14. Future Enhancements

After this refactoring:
1. Consider creating specialized test modules for different domains
2. Add performance benchmarking utilities
3. Create test data generators for complex scenarios
4. Add visual diff tools for failed reference tests

## 15. Quick Reference

### Utilities Module Functions and Macros

```julia
# MACROS (automatically get test directory from source location)
@test_all_formats(base_name, ast, reference_dir; formats=[:html, :latex, :markdown, :term, :typst], env=nothing)
@test_single_format(filename, text, parser, format_func)
@test_format_with_processor(filename, text, parser, format_func, processor)

# FUNCTIONS (require explicit test_dir as first argument)
test_all_formats(test_dir, base_name, ast, reference_dir; formats=[:html, :latex, :markdown, :term, :typst], env=nothing)
test_single_format(test_dir, filename, text, parser, format_func)
test_format_with_processor(test_dir, filename, text, parser, format_func, processor)

# Parser creation
create_parser()                    # Basic parser
create_parser(ExtensionRule())     # Parser with one extension
create_parser([Ext1(), Ext2()])    # Parser with multiple extensions

# Utilities
normalize_line_endings(s)          # Convert \r\n to \n

# Note: In most cases, use the macro versions (@test_all_formats, etc.) as they 
# automatically determine the correct directory. Use the function versions only
# when you need to specify a different directory.
```

### Common Patterns

```julia
# Extension test pattern
@testitem "extension_name" tags = [:extensions, :extension_name] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests
    
    p = create_parser(ExtensionRule())
    ast = p("markdown text")
    @test_all_formats("test_case_name", ast, "extension_name")
    
    # With environment parameter:
    # env = Dict("key" => value)
    # @test_all_formats("test_case", ast, "extension_name", env=env)
    
    # With specific formats only:
    # @test_all_formats("test_case", ast, "extension_name", formats=[:html, :latex])
end

# Writer test pattern  
@testitem "writer_name" tags = [:writers, :writer_name] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests
    
    p = create_parser()
    @test_single_format("references/writer/test.ext", "markdown", p, writer_func)
end
```
