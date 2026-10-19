# PowerShell 7.5 までに同梱されている Markdig (0.45.0 未満) は、表の区切り記号 `|` を入れ子にして解析するため、
# 区切り記号が 1 万個ほどを超える表は深さの上限を超えて ConvertFrom-Markdown が失敗する。
# 大きな表は行を分けて変換し、変換後の HTML で 1 つの表につなぎ直す。
$script:TableChunkRowCount = 200

function ConvertTo-MarkdownHtml {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Markdown
    )

    $lines = $Markdown -split '\r?\n'
    $marker = 'PSStyledMarkdown-' + [guid]::NewGuid().ToString('N')
    $continuations = [System.Collections.Generic.List[string]]::new()
    $output = [System.Collections.Generic.List[string]]::new()
    $fence = $null

    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]

        # コードブロックの中は表として扱わない
        if ($fence) {
            if ($line -match "^ {0,3}$fence$($fence[0])*\s*$") {
                $fence = $null
            }
            $output.Add($line)
            $i++
            continue
        }
        if ($line -match '^ {0,3}(`{3,}|~{3,})') {
            $fence = $Matches[1]
            $output.Add($line)
            $i++
            continue
        }

        $startsBlock = $i -eq 0 -or
            $lines[$i - 1] -match '^\s*$' -or
            $lines[$i - 1] -match '^ {0,3}#{1,6}(\s|$)'
        $isTable = $startsBlock -and
            $line -match '^ {0,3}\S' -and
            $line.Contains('|') -and
            $i + 1 -lt $lines.Count -and
            $lines[$i + 1].Contains('|') -and
            $lines[$i + 1] -match '^ {0,3}\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$'
        if (-not $isTable) {
            $output.Add($line)
            $i++
            continue
        }

        $end = $i + 2
        while ($end -lt $lines.Count -and
            $lines[$end] -notmatch '^\s*$' -and
            $lines[$end].Contains('|')) {
            $end++
        }
        $endsBlock = $end -eq $lines.Count -or
            $lines[$end] -match '^\s*$' -or
            $lines[$end] -match '^ {0,3}#{1,6}(\s|$)'
        $rowCount = $end - $i - 2

        if (-not $endsBlock -or $rowCount -le $script:TableChunkRowCount) {
            for ($k = $i; $k -lt $end; $k++) {
                $output.Add($lines[$k])
            }
            $i = $end
            continue
        }

        # 先頭の行のまとまりは本文に残し、残りは見出し行を付けて個別に変換する
        $header = $lines[$i], $lines[$i + 1]
        $firstEnd = $i + 2 + $script:TableChunkRowCount
        for ($k = $i; $k -lt $firstEnd; $k++) {
            $output.Add($lines[$k])
        }

        $rows = New-Object System.Text.StringBuilder
        for ($start = $firstEnd; $start -lt $end; $start += $script:TableChunkRowCount) {
            $chunkEnd = [Math]::Min($start + $script:TableChunkRowCount, $end)
            $chunk = ($header + $lines[$start..($chunkEnd - 1)]) -join "`n"
            $chunkHtml = (ConvertFrom-Markdown -InputObject $chunk).Html
            if ($chunkHtml -match '(?s)<tbody>\s*(.*)</tbody>') {
                [void] $rows.Append($Matches[1])
            }
        }

        $output.Add('')
        $output.Add("<!--${marker}:$($continuations.Count)-->")
        $continuations.Add($rows.ToString())
        $i = $end
    }

    $html = (ConvertFrom-Markdown -InputObject ($output -join "`n")).Html
    if ($continuations.Count -eq 0) {
        return $html
    }

    $html -replace "</tbody>\s*</table>\s*<!--${marker}:(\d+)-->", {
        $continuations[[int] $_.Groups[1].Value] + "</tbody>`n</table>"
    }
}

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
        $html = ConvertTo-MarkdownHtml -Markdown $markdown
        
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