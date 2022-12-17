@testset "Unicodes" begin
	p = Parser()
	enable!(p, AdmonitionRule())
	text = "!!! note \"Ju 的文字\"\n    Ju\n"
	@test html(p(text)) == "<div class=\"admonition note\"><p class=\"admonition-title\">Ju 的文字</p>\n<p>Ju</p>\n</div>"

	enable!(p, TableRule())
	tabletext = """
	| 标 | 题 | 们 |
    | --- | --- | --- |
    | d | 文 字 | g |
	"""
	@test html(p(tabletext)) == "<table><thead><tr><th align=\"left\">标</th><th align=\"left\">题</th><th align=\"left\">们</th></tr></thead><tbody><tr><td align=\"left\">d</td><td align=\"left\">文 字</td><td align=\"left\">g</td></tr></tbody></table>"
end
