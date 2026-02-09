#table(align: (left, left, left, left), columns: 4, fill: (x, y) => if y < 2 { rgb("#e5e7eb") },
table.header(
table.cell(rowspan: 2)[Location
],table.cell(colspan: 3)[Temperature
],
[min
],[mean
],[max
],
),
[Chicago
],[-10
],[15
],[35
],
[Berlin
],[-5
],[12
],[30
],
)
