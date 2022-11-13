@testset "Unicodes" begin
	p = Parser()
	enable!(p, AdmonitionRule())
	text = "!!! note \"Ju 的文字\"\n    Ju\n"
	@test html(p(text)) == "<div class=\"admonition note\"><p class=\"admonition-title\">Ju 的文字</p>\n<p>Ju</p>\n</div>"
end
