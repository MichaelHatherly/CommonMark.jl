#table(align: (left, left), columns: 2, fill: (x, y) => if y < 1 { rgb("#e5e7eb") },
table.header(
[H1
],[H2
],
),
[B1
],[B2
],
table.footer(
table.cell(rowspan: 2)[F1
],[FA
],
[FB
],
),
)
