import AppKit
import WebKit
import Markdown

final class MarkdownViewController: NSViewController {
    private let webView = WKWebView()
    private let emptyLabel = NSTextField(labelWithString: "Select a skill to view its content")

    override func loadView() {
        view = NSView()

        emptyLabel.font = .systemFont(ofSize: 16, weight: .medium)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isHidden = true
        webView.setValue(false, forKey: "drawsBackground")
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func showItem(_ item: SkillItem?) {
        guard let item = item else {
            webView.isHidden = true
            emptyLabel.isHidden = false
            return
        }
        showMarkdownFile(item.path)
    }

    func showMarkdownFile(_ path: String?) {
        guard let path = path,
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            webView.isHidden = true
            emptyLabel.isHidden = false
            return
        }

        emptyLabel.isHidden = true
        webView.isHidden = false

        let body: String
        if path.hasSuffix(".md") {
            let (_, markdownBody) = Scanner.parseSkillFile(content)
            let document = Document(parsing: markdownBody.isEmpty ? content : markdownBody)
            var converter = HTMLConverter()
            converter.visit(document)
            body = converter.html
        } else {
            // For non-markdown files, show as preformatted text
            body = "<pre><code>\(escapeHTML(content))</code></pre>"
        }

        let html = wrapHTML(body)
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func wrapHTML(_ body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        :root {
            color-scheme: light dark;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
            font-size: 14px;
            line-height: 1.6;
            color: light-dark(#1d1d1f, #f5f5f7);
            background: transparent;
            padding: 20px;
            max-width: 100%;
            word-wrap: break-word;
        }
        h1 { font-size: 1.8em; font-weight: 700; margin-top: 0; }
        h2 { font-size: 1.4em; font-weight: 600; margin-top: 1.2em; }
        h3 { font-size: 1.2em; font-weight: 600; margin-top: 1em; }
        h4, h5, h6 { font-size: 1em; font-weight: 600; margin-top: 1em; }
        p { margin: 0.8em 0; }
        a { color: light-dark(#0066cc, #6cb4ff); }
        code {
            font-family: "SF Mono", Menlo, monospace;
            font-size: 0.9em;
            background: light-dark(#f0f0f2, #2a2a2c);
            padding: 0.15em 0.35em;
            border-radius: 4px;
        }
        pre {
            background: light-dark(#f0f0f2, #2a2a2c);
            border-radius: 8px;
            padding: 14px;
            overflow-x: auto;
        }
        pre code {
            background: none;
            padding: 0;
            font-size: 13px;
        }
        blockquote {
            border-left: 3px solid light-dark(#d1d1d6, #48484a);
            margin: 0.8em 0;
            padding: 0.4em 1em;
            color: light-dark(#6e6e73, #a1a1a6);
        }
        ul, ol { padding-left: 1.5em; }
        li { margin: 0.3em 0; }
        hr {
            border: none;
            border-top: 1px solid light-dark(#d1d1d6, #48484a);
            margin: 1.5em 0;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 1em 0;
        }
        th, td {
            border: 1px solid light-dark(#d1d1d6, #48484a);
            padding: 8px 12px;
            text-align: left;
        }
        th {
            background: light-dark(#f0f0f2, #2a2a2c);
            font-weight: 600;
        }
        img { max-width: 100%; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - HTMLConverter

struct HTMLConverter: MarkupWalker {
    var html = ""

    mutating func visitDocument(_ document: Document) -> () {
        descendInto(document)
    }

    mutating func visitHeading(_ heading: Heading) -> () {
        let tag = "h\(min(heading.level, 6))"
        html += "<\(tag)>"
        descendInto(heading)
        html += "</\(tag)>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> () {
        html += "<p>"
        descendInto(paragraph)
        html += "</p>\n"
    }

    mutating func visitText(_ text: Markdown.Text) -> () {
        html += escapeHTML(text.string)
    }

    mutating func visitStrong(_ strong: Strong) -> () {
        html += "<strong>"
        descendInto(strong)
        html += "</strong>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> () {
        html += "<em>"
        descendInto(emphasis)
        html += "</em>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> () {
        html += "<code>\(escapeHTML(inlineCode.code))</code>"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> () {
        let lang = codeBlock.language ?? ""
        let langAttr = lang.isEmpty ? "" : " class=\"language-\(escapeHTML(lang))\""
        html += "<pre><code\(langAttr)>\(escapeHTML(codeBlock.code))</code></pre>\n"
    }

    mutating func visitLink(_ link: Markdown.Link) -> () {
        let dest = link.destination ?? ""
        html += "<a href=\"\(escapeHTML(dest))\">"
        descendInto(link)
        html += "</a>"
    }

    mutating func visitImage(_ image: Markdown.Image) -> () {
        let src = image.source ?? ""
        let alt = image.plainText
        html += "<img src=\"\(escapeHTML(src))\" alt=\"\(escapeHTML(alt))\">"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> () {
        html += "<ul>\n"
        descendInto(unorderedList)
        html += "</ul>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> () {
        html += "<ol>\n"
        descendInto(orderedList)
        html += "</ol>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) -> () {
        html += "<li>"
        descendInto(listItem)
        html += "</li>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> () {
        html += "<blockquote>\n"
        descendInto(blockQuote)
        html += "</blockquote>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> () {
        html += "<hr>\n"
    }

    mutating func visitTable(_ table: Markdown.Table) -> () {
        html += "<table>\n"
        descendInto(table)
        html += "</table>\n"
    }

    mutating func visitTableHead(_ tableHead: Markdown.Table.Head) -> () {
        html += "<thead>\n<tr>\n"
        descendInto(tableHead)
        html += "</tr>\n</thead>\n"
    }

    mutating func visitTableBody(_ tableBody: Markdown.Table.Body) -> () {
        html += "<tbody>\n"
        descendInto(tableBody)
        html += "</tbody>\n"
    }

    mutating func visitTableRow(_ tableRow: Markdown.Table.Row) -> () {
        html += "<tr>\n"
        descendInto(tableRow)
        html += "</tr>\n"
    }

    mutating func visitTableCell(_ tableCell: Markdown.Table.Cell) -> () {
        let tag = tableCell.parent is Markdown.Table.Head ? "th" : "td"
        html += "<\(tag)>"
        descendInto(tableCell)
        html += "</\(tag)>\n"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> () {
        html += "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> () {
        html += "<br>\n"
    }

    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) -> () {
        html += htmlBlock.rawHTML
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> () {
        html += inlineHTML.rawHTML
    }

    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
