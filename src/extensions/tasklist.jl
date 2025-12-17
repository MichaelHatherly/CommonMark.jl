#
# Task List extension: - [ ] / - [x]
#

mutable struct TaskItem <: AbstractBlock
    list_data::ListData
    checked::Bool
end

is_container(::TaskItem) = true
accepts_lines(::TaskItem) = false
can_contain(::TaskItem, t) = !(t isa Item) && !(t isa TaskItem)

"""
    TaskListRule()

Parse GitHub-style task list items.

Not enabled by default. Converts list items starting with `[ ]` or `[x]` into
interactive checkboxes in HTML output.

```markdown
- [ ] Unchecked item
- [x] Checked item
- Regular item
```
"""
struct TaskListRule end

block_modifier(::TaskListRule) =
    Rule(50) do parser, block
        if block.t isa Item
            child = block.first_child
            if !isnull(child) && child.t isa Paragraph
                m = match(r"^\[([ xX])\]\s?", child.literal)
                if m !== nothing
                    block.t = TaskItem(block.t.list_data, m[1] != " ")
                    child.literal = child.literal[length(m.match)+1:end]
                end
            end
        end
        return nothing
    end

#
# Writers
#

function write_html(t::TaskItem, r, n, ent)
    if ent
        checkbox =
            t.checked ? "<input type=\"checkbox\" disabled checked> " :
            "<input type=\"checkbox\" disabled> "
        tag(r, "li", attributes(r, n))
        literal(r, checkbox)
    else
        tag(r, "/li")
        cr(r)
    end
end

function write_term(t::TaskItem, render, node, enter)
    if enter
        checkbox = t.checked ? "☑ " : "☐ "
        if t.list_data.type === :ordered
            number = string(render.format.list_item_number[end], ". ")
            render.format.list_item_number[end] += 1
            push_margin!(render, 1, number * checkbox, crayon"")
        else
            push_margin!(render, 1, checkbox, crayon"")
        end
    else
        maybe_print_margin(render, node)
        pop_margin!(render)
        if !isnull(node.nxt)
            cr(render)
        end
    end
end

function write_latex(t::TaskItem, w, node, ent)
    if ent
        checkbox = t.checked ? "\$\\boxtimes\$" : "\$\\square\$"
        literal(w, "\\item[$checkbox]")
    end
    cr(w)
end

function write_typst(t::TaskItem, w, node, enter)
    if enter
        checkbox = t.checked ? "☑ " : "☐ "
        if t.list_data.type === :ordered
            number = lpad(string(w.format.list_item_number[end], ". "), 4, " ")
            w.format.list_item_number[end] += 1
            push_margin!(w, 1, number * checkbox)
        else
            push_margin!(w, 1, lpad(checkbox, 4, " "))
        end
    else
        if isnull(node.first_child)
            cr(w)
        end
        pop_margin!(w)
    end
end

function write_markdown(t::TaskItem, w, node, enter)
    if enter
        checkbox = t.checked ? "[x] " : "[ ] "
        if t.list_data.type === :ordered
            number = lpad(string(w.format.list_item_number[end], ". "), 4, " ")
            w.format.list_item_number[end] += 1
            push_margin!(w, 1, number * checkbox)
        else
            bullets = ['-', '+', '*', '-', '+', '*']
            bullet = bullets[min(w.format.list_depth, length(bullets))]
            push_margin!(w, 1, "$bullet " * checkbox)
        end
    else
        if isnull(node.first_child)
            cr(w)
        end
        pop_margin!(w)
    end
end
