#table(align: (left, left), columns: 2, fill: (x, y) => if y < 1 { rgb("#e5e7eb") },
table.header(
[Outer Left
],[Outer Right
],
),
[#table(align: (left, left), columns: 2,
[A
],[B
],
[C
],[D
],
)
],[Regular cell
],
)
