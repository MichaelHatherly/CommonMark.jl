# Shared writers for Table and GridTable (both have a `spec` field).

const AnyTable = Union{Table,GridTable}

write_html(::AnyTable, rend, node, enter) =
    tag(rend, enter ? "table" : "/table", enter ? attributes(rend, node) : [])

function write_latex(t::AnyTable, rend, node, enter)
    if enter
        print(rend.buffer, "\\begin{longtable}[]{@{}")
        join(rend.buffer, (string(a)[1] for a in t.spec))
        println(rend.buffer, "@{}}")
    else
        println(rend.buffer, "\\end{longtable}")
    end
end

function write_typst(t::AnyTable, rend, node, enter)
    if enter
        align = "align: (" * join(t.spec, ", ") * ")"
        columns = "columns: $(length(t.spec))"
        parts = ["$align", "$columns"]
        if !isnull(node.first_child) && node.first_child.t isa TableHeader
            push!(parts, "fill: (x, y) => if y == 0 { rgb(\"#e5e7eb\") }")
        end
        println(rend.buffer, "#table(", join(parts, ", "), ",")
    else
        println(rend.buffer, ")")
    end
end

function write_json(t::AnyTable, ctx, node, enter)
    if enter
        colspecs = Any[]
        for align in t.spec
            a =
                align === :left ? json_el(ctx, "AlignLeft") :
                align === :right ? json_el(ctx, "AlignRight") :
                align === :center ? json_el(ctx, "AlignCenter") :
                json_el(ctx, "AlignDefault")
            push!(colspecs, Any[a, json_el(ctx, "ColWidthDefault")])
        end
        push_container!(ctx, colspecs)
        push_container!(ctx, Any[])  # head rows
        push_container!(ctx, Any[])  # body rows
    else
        body_rows = pop_container!(ctx)
        head_rows = pop_container!(ctx)
        colspecs = pop_container!(ctx)
        caption = Any[nothing, Any[]]
        head = Any[empty_attr(), head_rows]
        body = Any[Any[empty_attr(), 0, Any[], body_rows]]
        foot = Any[empty_attr(), Any[]]
        push_element!(
            ctx,
            json_el(ctx, "Table", Any[empty_attr(), caption, colspecs, head, body, foot]),
        )
    end
end
