package socletool

// The site, made when it is deployed (.github/workflows/pages.yml). The steps are the toolkit's (gt:site, its `site`
// command: build <site> <out>, check, card); this file says what this site is: its address, names and colours. socle
// has no release yet: the home page offers the film and the source, no download.

import tk_site "gt:site"
import toolbox "gt:toolbox"

SITE_URL :: "https://socle.froment.software/"

SITE_LD :: [?][2]string{
	{"applicationCategory", "UtilitiesApplication"},
	{"operatingSystem", "Linux, macOS"},
	{"license", "https://opensource.org/license/mit"},
}

site_meta :: proc() -> tk_site.Meta {
	m := tk_site.meta_default(name = "Socle", url = SITE_URL, repository = REPOSITORY, tagline = "Your whole system in one window", theme = "#0b0f18", accent = "#7ebae4", card = "img/overview.png")
	@(static) ld := SITE_LD
	m.ld_fields = ld[:]   // (static: the site command keeps the Meta as long as the tool runs)
	return m
}

site_command :: proc() -> toolbox.Command {
	return tk_site.command({meta = site_meta(), images = tk_site.images_default()})
}
