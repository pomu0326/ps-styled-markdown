# PSStyledMarkdown

Render Markdown as styled HTML with sortable tables from PowerShell.

PSStyledMarkdown is a PowerShell module that renders Markdown as styled HTML and opens it in the default browser.

It uses GitHub Markdown CSS for styling and adds client-side sorting to HTML tables.

## Features

- Convert Markdown to HTML using PowerShell's `ConvertFrom-Markdown`.
- Apply GitHub-style Markdown CSS.
- Sort HTML table rows by clicking column headers.
- Compare dates, numbers, and text when sorting.
- Support Japanese text sorting and natural numeric ordering.
- Open the generated HTML in the default browser.

## Requirements

- PowerShell with the `ConvertFrom-Markdown` cmdlet available.
- An HTML-capable web browser.
- Internet access to load the default stylesheet, unless a local stylesheet is specified.

## Usage

### Display Markdown

```powershell
$markdown = @'
# Server Inventory

| Server | CPU Cores | Status |
| --- | ---: | --- |
| server-01 | 8 | Running |
| server-02 | 16 | Stopped |
| server-03 | 4 | Running |
'@

Show-StyledMarkdown -MarkdownText $markdown
```

The generated HTML opens in the default browser. Click a table header to sort the rows by that column.

### Read Markdown from a file

```powershell
Get-Content -LiteralPath ./README.md -Raw |
    Show-StyledMarkdown
```

### Use a custom stylesheet

```powershell
Show-StyledMarkdown `
    -MarkdownText $markdown `
    -Stylesheet "https://example.com/custom-markdown.css"
```

The `Stylesheet` parameter accepts a URL to a CSS stylesheet.

## How It Works

1. Collect the Markdown input.
2. Convert Markdown to HTML using `ConvertFrom-Markdown`.
3. Wrap the generated HTML in a document with GitHub-style CSS.
4. Add JavaScript for client-side table sorting.
5. Save the HTML to a temporary file and open it in the default browser.

Table sorting supports date-like values, numeric values, and text. Text comparison uses Japanese locale-aware collation.

## License

See [LICENSE](LICENSE) for details.

