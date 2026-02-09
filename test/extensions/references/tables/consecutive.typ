#table(align: (left, right), columns: 2, fill: (x, y) => if y < 1 { rgb("#e5e7eb") },
table.header(
[A],[B],
),
[1],[2],
)
#table(align: (left, left, left), columns: 3, fill: (x, y) => if y < 1 { rgb("#e5e7eb") },
table.header(
[X],[Y],[Z],
),
[a],[b],[c],
)
