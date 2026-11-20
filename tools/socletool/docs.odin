package socletool

// The site's Docs section, <out>/docs/, made by gt:site (tk_site.build_docs) of docs/*.md and docs/_nav.txt, after the
// toolkit's pages are in <out> (site.odin). Its pages wear the built home page's bar and script, so the nav (with its
// Docs link, Meta.docs) is the home's without a second copy.

import "core:fmt"
import "core:os"
import "core:strings"
import tk_site "gt:site"

docs_build :: proc(source, out: string) -> string {
	data, err := os.read_entire_file_from_path(fmt.tprintf("%s/index.html", out), context.temp_allocator)
	if err != nil { return fmt.tprintf("%s/index.html cannot be read: run `site build` first", out) }
	index := string(data)
	header := between(index, "<header class=\"bar\">", "</header>")
	script := between(index, "<script>", "</script>")
	if header == "" || script == "" { return fmt.tprintf("%s/index.html has no bar or no script", out) }
	footer := fmt.tprintf(`<footer>
<p class="small">Socle, MIT licence. These pages are the Markdown files of <a href="%s/tree/master/docs">docs/</a>.</p>
</footer>
<script>%s</script>
`, REPOSITORY, script)
	d := tk_site.Docs{
		source     = source,
		out        = fmt.tprintf("%s/docs", out),
		name       = "Socle",
		site_url   = SITE_URL,
		repository = REPOSITORY,
		branch     = "master",
		note       = "<!-- Made by socletool docs from docs/*.md: edit those. -->",
		head       = "<link rel=\"icon\" href=\"/img/logo.png\">\n<link rel=\"stylesheet\" href=\"/style.css\">\n<link rel=\"stylesheet\" href=\"/docs/docs.css\">\n",
		header     = fmt.tprintf("<header class=\"bar\">%s</header>\n", home_links(header)),
		footer     = proc(d: ^tk_site.Docs, p: ^tk_site.Doc_Page) -> string { return (^string)(d.user)^ },
		css        = {note = "/* Made by socletool docs. Layers over style.css. */", bar = DOCS_BAR, theme = DOCS_THEME, extra = DOCS_LOOK},
		user       = &footer,
		writer     = {tool = "socletool docs"},
	}
	if !tk_site.build_docs(&d) { return "the Docs pages were not made" }
	if d.writer.problems > 0 { return fmt.tprintf("%d files of the Docs pages were not written", d.writer.problems) }
	fmt.printfln("the Docs pages: %s/docs", out)
	return ""
}

// The home page's links as root-absolute ones (build_docs makes them relative to each page): "#x" is the home's.
@(private = "file")
home_links :: proc(html: string) -> string {
	rooted := tk_site.rooted(html, "")
	out, _ := strings.replace_all(rooted, ` href="#`, ` href="/#`, context.temp_allocator)
	return out
}

@(private = "file")
between :: proc(s, open, close: string) -> string {
	i := strings.index(s, open)
	if i < 0 { return "" }
	rest := s[i + len(open):]
	j := strings.index(rest, close)
	return j < 0 ? "" : rest[:j]
}

// The height of the site's bar (.bar in site/style.css), in px: the menu and the table of contents stay under it.
DOCS_BAR :: 52

// The site's colours (site/style.css), under the names the docs' style sheet reads.
DOCS_THEME :: `:root {
  --bg: var(--bg0);
  --surface: var(--bg1);
  --surface-2: var(--bg2);
  --line: #1f2a3f;
  --line-2: #2c3a55;
  --muted: var(--weak);
  --soft: var(--faint);
  --accent-dim: rgba(126, 186, 228, 0.14);
}
`

DOCS_LOOK :: tk_site.DOCS_CODE_CSS + `
/* a page's <main> is not centred by the site's rule for main; pictures fit the column */
.doc-main { max-width: none; margin: 0; }
.doc-article { overflow-wrap: break-word; }
.doc-article img { max-width: 100%; height: auto; }
.doc-seq a { min-width: 0; }
`
