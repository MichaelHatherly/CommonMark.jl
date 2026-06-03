@testitem "ast_operations" tags = [:core] begin
    using CommonMark
    using Test

    text = CommonMark.text
    root = text("root")

    CommonMark.insert_before(root, text("insert_before"))
    CommonMark.insert_after(root, text("insert_after"))
    @test root.prv.literal == "insert_before"
    @test root.nxt.literal == "insert_after"

    CommonMark.append_child(root, text("append_child"))
    @test root.first_child.literal == "append_child"
    @test root.last_child.literal == "append_child"

    CommonMark.prepend_child(root, text("prepend_child"))
    @test root.first_child.literal == "prepend_child"
    @test root.last_child.literal == "append_child"

    CommonMark.unlink(root.last_child)
    @test root.last_child.literal == "prepend_child"

    root = text("root")
    CommonMark.prepend_child(root, text("prepend_child"))
    @test root.first_child.literal == "prepend_child"
    @test root.last_child.literal == "prepend_child"
end

@testitem "insert preserves NULL_NODE sentinel" tags = [:core] begin
    using CommonMark
    using Test

    # Inserting next to a parentless node must not write through to the shared
    # NULL_NODE sentinel, whose child fields stay undefined.
    root = CommonMark.Node(CommonMark.Paragraph())
    CommonMark.insert_after(root, CommonMark.Node(CommonMark.Text()))
    @test !isdefined(CommonMark.NULL_NODE, :last_child)

    root = CommonMark.Node(CommonMark.Paragraph())
    CommonMark.insert_before(root, CommonMark.Node(CommonMark.Text()))
    @test !isdefined(CommonMark.NULL_NODE, :first_child)
end
