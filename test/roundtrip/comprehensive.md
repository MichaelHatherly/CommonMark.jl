# Heading 1

## Heading 2

### Heading 3

#### Heading 4

##### Heading 5

###### Heading 6

This is a paragraph with *emphasis* and **strong** text.
Also _underscore emphasis_ and __underscore strong__.
And *nested **strong** inside emphasis*.

Inline `code` and ```code with backticks ` inside```.

A [link](https://example.com) and [link with title](https://example.com "Title").

An ![image](https://example.com/image.png) and ![image with title](https://example.com/image.png "Alt").

> A block quote
> with multiple lines.
>
> And a second paragraph.

> Nested block quotes:
>
> > Inner quote
> > continues here.

  - Unordered list item 1
  - Unordered list item 2
  - Unordered list item 3

 1. Ordered list item 1
 2. Ordered list item 2
 3. Ordered list item 3

  - Nested lists:
      + Level 2 item
      + Another level 2
          * Level 3 item
          * Another level 3

 1. Ordered with nested:
      + Bullet inside ordered
      + Another bullet

- [ ] Task list unchecked
- [x] Task list checked

* * *

```julia
function hello()
    println("Hello, World!")
end
```

```
Plain fenced code block
with no language.
```

    Indented code block
    with multiple lines.

<div>
Raw HTML block
</div>

Inline <em>HTML</em> works too.

Hard line break with two spaces at end:\
Backslash line break.

Escaped characters: \* \_ \` \[ \] \\ \!

| Left | Center | Right |
|:---- |:------:| -----:|
| a    | b      | c     |
| d    | e      | f     |

```math
E = mc^2
```

Inline math: ``x^2 + y^2 = z^2``.

[^1]: This is a footnote definition.

Paragraph with footnote reference[^1].

[example]: https://example.com "Example Site"

A [reference link][example] and [shortcut reference][example].

!!! note "A Note"

    This is an admonition with a title.
    It has multiple paragraphs.

    Second paragraph of admonition.

> [!NOTE]
> This is a GitHub-style alert.
> It spans multiple lines.

Text with ~~strikethrough~~ formatting.

Text with ~subscript~ and ^superscript^ elements.

::: warning
This is a fenced div.

With multiple paragraphs inside.
:::
