function Show-StyledMarkdown {
    param(
        [Parameter()]
        [string] $Stylesheet = "https://cdn.jsdelivr.net/npm/github-markdown-css@5.9.0/github-markdown.css",

        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $MarkdownText
    )
    Begin {
        $content = New-Object System.Text.StringBuilder
    }
    
    Process {
        $content.Append($MarkdownText)
    }
    
    End {
        $markdown = $content.ToString()
        $html = ConvertFrom-Markdown -InputObject $markdown |
            Select-Object -ExpandProperty Html
        
        $sortScript = @'
<script>
document.querySelectorAll(".markdown-body table").forEach(table => {
    const headers = table.querySelectorAll("thead th");

    headers.forEach((header, columnIndex) => {
        header.style.cursor = "pointer";
        header.title = "クリックして並び替え";

        header.addEventListener("click", () => {
            const tbody = table.tBodies[0];
            if (!tbody) return;

            const rows = Array.from(tbody.rows);
            const ascending =
                header.dataset.sortOrder !== "asc";

            const collator = new Intl.Collator("ja", {
                numeric: true,
                sensitivity: "base"
            });

            function compare(a, b) {
                const x = a.trim();
                const y = b.trim();

                // 日時の比較（ISO形式など）
                const datePattern =
                    /^\d{4}[-/]\d{1,2}[-/]\d{1,2}/;

                if (datePattern.test(x) &&
                    datePattern.test(y)) {
                    const dx = Date.parse(x);
                    const dy = Date.parse(y);

                    if (!Number.isNaN(dx) &&
                        !Number.isNaN(dy)) {
                        return dx - dy;
                    }
                }

                // 数値の比較（101件、3台など）
                const numberPattern =
                    /^[+-]?[\d,]+(?:\.\d+)?\s*(?:件|台|個|回|%)?$/;

                if (numberPattern.test(x) &&
                    numberPattern.test(y)) {
                    const nx = Number(
                        x.replace(/[,\s件台個回%]/g, "")
                    );
                    const ny = Number(
                        y.replace(/[,\s件台個回%]/g, "")
                    );

                    return nx - ny;
                }

                // 文字列の比較
                return collator.compare(x, y);
            }

            rows.sort((a, b) => {
                const result = compare(
                    a.cells[columnIndex]?.innerText ?? "",
                    b.cells[columnIndex]?.innerText ?? ""
                );

                return ascending ? result : -result;
            });

            rows.forEach(row => tbody.appendChild(row));

            headers.forEach(th => {
                delete th.dataset.sortOrder;
                th.removeAttribute("aria-sort");
            });

            header.dataset.sortOrder =
                ascending ? "asc" : "desc";

            header.setAttribute(
                "aria-sort",
                ascending ? "ascending" : "descending"
            );
        });
    });
});
</script>
'@
        $document = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet"
          href="${Stylesheet}">
    <style>
        body {
            margin: 0;
            background: var(--bgColor-default, #ffffff);
        }
        .markdown-body {
            box-sizing: border-box;
            /* max-width: 1010px; */
            max-width: 100%;
            margin: 0 auto;
            padding: 32px;
        }
    </style>
</head>
<body>
    <article class="markdown-body">
$html
    </article>
$sortScript
</body>
</html>
"@

        $tempFile = Join-Path $env:TEMP (
            [guid]::NewGuid().ToString() + '.html'
        )

        Set-Content -LiteralPath $tempFile -Value $document -Encoding utf8
        Start-Process $tempFile
    }
}

Export-ModuleMember -Function @(
    "Show-StyledMarkdown"
)