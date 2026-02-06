@testitem "normalize_uri" begin
    import CommonMark
    using Test

    # RFC 3986 unreserved characters must not be percent-encoded
    @test CommonMark.normalize_uri("https://example.com/~user") ==
          "https://example.com/~user"
    @test CommonMark.normalize_uri("hello!world") == "hello!world"

    # RFC 3986 reserved characters used as delimiters pass through
    @test CommonMark.normalize_uri("a;b") == "a;b"
    @test CommonMark.normalize_uri("a\$b") == "a\$b"

    # Characters that should be encoded
    @test CommonMark.normalize_uri("a b") == "a%20b"
    @test CommonMark.normalize_uri("a<b") == "a%3Cb"
    @test CommonMark.normalize_uri("a>b") == "a%3Eb"

    # Already-encoded sequences pass through (% is safe)
    @test CommonMark.normalize_uri("a%20b") == "a%20b"

    # Non-ASCII gets percent-encoded
    @test CommonMark.normalize_uri("café") == "caf%C3%A9"

end
