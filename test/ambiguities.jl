@testitem "method_ambiguities" tags = [:core] begin
    using CommonMark
    using Test

    # Only run on newer Julia versions.
    if VERSION > v"1.6"
        @test isempty(Test.detect_ambiguities(CommonMark))
    end
end
