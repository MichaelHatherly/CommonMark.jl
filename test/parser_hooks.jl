@testset "Parser Hooks" begin
    # Without callbacks, an invalid reference link gets interpreted as a string
    p = Parser()
    n = p("[Foo][foo], [Bar][bar]\n\n[foo]: bar")
    @test n.first_child.first_child.t isa CommonMark.Link
    @test n.first_child.first_child.t.destination == "bar"
    @test n.first_child.first_child.nxt.nxt.t isa CommonMark.Text
    @test n.first_child.first_child.nxt.nxt.literal == "["

    # This tests we provide a proper fallback link for 'bar'
    p = Parser()
    push!(p.refmap.callbacks, s -> begin
        @test s == "bar"
        return ("url", "title")
    end)
    n = p("[Foo][foo], [Bar][bar]\n\n[foo]: bar")
    @test n.first_child.first_child.t isa CommonMark.Link
    @test n.first_child.first_child.t.destination == "bar"
    @test n.first_child.first_child.nxt.nxt.t isa CommonMark.Link
    @test n.first_child.first_child.nxt.nxt.t.destination == "url"
    @test n.first_child.first_child.nxt.nxt.t.title == "title"
    # Make sure the cache gets emptied between runs, and we also check that if
    # callback returns nothing, it gets parsed as a string, like normally.
    empty!(p.refmap.callbacks)
    n_times_called = 0
    push!(p.refmap.callbacks, s -> begin
        n_times_called += 1
        @test s == "bar"
        return nothing
    end)
    n = p("[Foo][foo], [Qux][bar]\n\n[foo]: barx")
    # If the parsin fails the callback gets called twice somehow..
    @test_broken n_times_called == 1
    @test n.first_child.first_child.t isa CommonMark.Link
    @test n.first_child.first_child.t.destination == "barx"
    @test n.first_child.first_child.nxt.nxt.t isa CommonMark.Text
    @test n.first_child.first_child.nxt.nxt.literal == "["

    # Multiple callbacks
    p = Parser()
    push!(p.refmap.callbacks, s -> begin
        @test s ∈ ["foo", "bar"]
        (s == "foo") ? ("url", "title") : nothing
    end)
    push!(p.refmap.callbacks, s -> begin
        @test s == "bar"
        return ("url2", "title2")
    end)
    n = p("[Foo][foo], [Bar][bar]")
    @test n.first_child.first_child.t isa CommonMark.Link
    @test n.first_child.first_child.t.destination == "url"
    @test n.first_child.first_child.t.title == "title"
    @test n.first_child.first_child.nxt.nxt.t isa CommonMark.Link
    @test n.first_child.first_child.nxt.nxt.t.destination == "url2"
    @test n.first_child.first_child.nxt.nxt.t.title == "title2"
end
