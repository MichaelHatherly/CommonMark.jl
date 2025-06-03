@testitem "method_ambiguities" tags = [:core] begin
    using CommonMark
    using Test

    @test isempty(Test.detect_ambiguities(Base, Core, CommonMark; recursive = true))
end
