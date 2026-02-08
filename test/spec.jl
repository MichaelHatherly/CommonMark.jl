@testitem "extra_spec_tests" tags = [:spec, :core] begin
    using CommonMark
    using Test
    cases = [(
        """
        <textarea>

        *foo*

        _bar_

        </textarea>
        """,
        "<textarea>\n\n*foo*\n\n_bar_\n\n</textarea>\n",
    )]
    p = Parser()
    for (m, h) in cases
        @test html(p(m)) == h
        @test markdown(p(m)) == m
    end
end
