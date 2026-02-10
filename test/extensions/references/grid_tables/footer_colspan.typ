#table(align: (left, left, left), columns: 3, fill: (x, y) => if y < 1 { rgb("#e5e7eb") },
table.header(
[H1
],[H2
],[H3
],
),
[B1
],[B2
],[B3
],
table.footer(
[F1
],table.cell(colspan: 2)[F2 spanning
],
),
)
