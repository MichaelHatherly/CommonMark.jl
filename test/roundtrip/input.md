# Document Title

## Introduction

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident.

## Text Formatting

This paragraph has **bold text** and *italic text* and ***bold italic*** combined.
Also __double underscore bold__ and _single underscore italic_ and ___triple___.
Mix them: **bold with *nested italic* inside** and *italic with **nested bold** inside*.

Some `inline code` here and more ``x^2 + y^2`` inline math there.
Even ```code with `` double and ` single backticks``` works.

## Links and Images

Here is [a simple link](https://example.com) in a sentence.
And [a link with title](https://example.org "Example Organization") too.

Images work similarly: ![Alt text](https://example.com/logo.png) inline.
With title: ![Logo](https://example.com/logo.png "Company Logo").

## Block Quotes

> This is a simple block quote.
> It continues on the next line.

> This block quote has multiple paragraphs.
>
> Here is the second paragraph within the quote.
>
> And a third for good measure.

> Nested quotes are possible:
>
> > This is the inner quote.
> > It can also span lines.
>
> Back to outer quote.

> Block quote with other elements:
>
>   - A list item
>   - Another item
>
> And a paragraph after the list.

## Lists

#### Heading Level 4

##### Heading Level 5

###### Heading Level 6

### Unordered Lists

  - First item

  - Second item

  - Third item

  - Item with multiple paragraphs.

    This is the continuation paragraph.

  - Another item after that.

  - Nested unordered lists:

      + Sub-item one
      + Sub-item two
          * Deep item one
          * Deep item two
      + Back to sub-level

### Ordered Lists

 1. First ordered item

 2. Second ordered item

 3. Third ordered item

 4. Ordered item with paragraph.

    Continuation of the item.

 5. Next ordered item.

 6. Ordered with nested:

      + Unordered inside ordered
      + Another unordered

 7. Continue ordered

### Tight Lists

  - Tight item one
  - Tight item two
  - Tight item three

 1. Tight ordered one
 2. Tight ordered two
 3. Tight ordered three

### Task Lists

- [ ] Unchecked task
- [x] Checked task
- [ ] Another unchecked
- [x] Another checked

## Code Blocks

Indented code block:

    function example()
        return 42
    end

Fenced code block with language:

```python
def hello():
    print("Hello, World!")
    return True
```

Fenced without language:

```
Just plain text
in a code block.
```

## Tables

| Name  | Age | City        |
|:----- |:---:| -----------:|
| Alice | 30  | New York    |
| Bob   | 25  | Los Angeles |
| Carol | 35  | Chicago     |

| Left | Center | Right | Default |
|:---- |:------:| -----:|:------- |
| L    | C      | R     | D       |
| data | data   | data  | data    |

## Horizontal Rules

Above the rule.

* * *

Below the rule.

## HTML

<div class="container">
<p>Raw HTML paragraph</p>
</div>

Inline HTML: <strong>bold</strong> and <em>italic</em> and <code>code</code>.

## Escapes and Special Characters

Escaped characters: \* \_ \` \[ \] \( \) \# \+ \- \. \! \{ \} \| \\

Backslash line break:\
This is after a hard break.

Two-space line break:  
This is after a two-space hard break.

## Math

Block math:

```math
\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
```

Inline math: ``E = mc^2`` in a sentence.

## Admonitions

!!! note

    A simple note admonition.
    With multiple lines.

!!! warning "Custom Title"

    Warning with a custom title.

!!! danger

    Danger admonition here.

    With a second paragraph.

## Footnotes

Here is a sentence with a footnote[^1].

Another reference[^longnote] to a longer note.

[^1]: Simple footnote text.

[^longnote]: Longer footnote with multiple paragraphs.

    Second paragraph of the footnote.

## GitHub Alerts

> [!NOTE]
> This is a note alert.

> [!WARNING]
> This is a warning alert.

> [!TIP]
> Helpful tip here.
>
> With multiple paragraphs.

## Fenced Divs

::: info
Content inside a fenced div.
:::

::: warning
Multi-paragraph div.

Second paragraph here.
:::

## Strikethrough and Sub/Superscript

Text with ~~strikethrough~~ words.

Water is H~2~O with subscript.

E equals mc^2^ with superscript.

## Reference Links

[ref1]: https://example.com "Reference One"

[ref2]: https://example.org

Use [reference style][ref1] links.
And [another reference][ref2] without title.

## Typography

Use "curly quotes" and 'single quotes' properly.
Dashes: en-dash -- and em-dash --- work.
Ellipsis... is also handled.

## Setext Headings (normalize to ATX)

Setext Level 1
==============

Setext Level 2
--------------

## Dollar Math (normalizes to Julia-style)

Inline dollar math: $x^2 + y^2 = z^2$ in a sentence.

Display math with double dollars:

$$
\sum_{i=1}^{n} i = \frac{n(n+1)}{2}
$$

Inline display math: text $$E = mc^2$$ in a sentence.

Multiline inline display:
$$
\alpha + \beta
$$
more text.

## Autolinks

Visit <https://example.com> for more info.
Email: <user@example.org> works too.

## Attributes

{#custom-id .highlight}
### Heading with attributes

A paragraph followed by *emphasized text*{.special} with inline attributes.

{data-value="123" .note}
> A block quote with attributes.

## Raw Content

Inline raw HTML: `<span class="raw">`{=html} works.

```{=html}
<div class="special">
  Raw HTML block content.
</div>
```

## Edge Cases

### Empty Elements

>

  -

 1.

### Links with Special Characters

A [link with parens](https://example.com/path_(with_parens)) in URL.

A [link with spaces](https://example.com/path%20with%20spaces) encoded.

### Empty and Nested Links

A link with [](https://example.com) empty text.

An [![image alt](https://example.com/img.png)](https://example.com) image inside link.

### Deeply Nested Quotes

> Level 1
>
> > Level 2
> >
> > > Level 3
> > >
> > > > Level 4 deeply nested.

## Final Section

This document covers most CommonMark and extension syntax.
It serves as a comprehensive roundtrip test file.

The end.
