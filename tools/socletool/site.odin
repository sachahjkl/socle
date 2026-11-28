package socletool

// The site, made when it is deployed (.github/workflows/pages.yml). The steps are the toolkit's (gt:site, its `site`
// command: build <site> <out>, check, card), and the Docs section after them (docs.odin): `site build` makes both, and
// `site check` checks both. This file says what this site is: its address, names and colours.

import cli "gt:cli"
import tk_site "gt:site"
import toolbox "gt:toolbox"

SITE_URL :: "https://socle.froment.software/"

SITE_LD :: [?][2]string{
	{"applicationCategory", "UtilitiesApplication"},
	{"operatingSystem", "Linux"},
	{"license", "https://opensource.org/license/mit"},
}

site_meta :: proc() -> tk_site.Meta {
	m := tk_site.meta_default(name = "Socle", url = SITE_URL, repository = REPOSITORY, tagline = "NixOS configuration", theme = "#0b0f18", accent = "#7ebae4", card = "img/overview.png")
	@(static) ld := SITE_LD
	m.ld_fields = ld[:]   // (static: the site command keeps the Meta as long as the tool runs)
	m.docs = true         // (the Docs section: the nav links it)
	return m
}

site_command :: proc() -> toolbox.Command {
	toolkit := tk_site.command({meta = site_meta(), images = tk_site.images_default()})
	return {name = "site", usage = toolkit.usage, run_with = site_run, user = new_clone(toolkit)}
}

@(private = "file")
site_run :: proc(args: []string, user: rawptr) -> cli.Exit {
	toolkit := (^toolbox.Command)(user)
	what := len(args) > 0 ? args[0] : ""
	switch what {
	case "build":
		if len(args) != 3 { break }
		if made := toolkit.run_with(args, toolkit.user); made != .Done { return made }
		return toolbox.done(docs_build("docs", args[2]))
	case "check":
		o := tk_site.Check_Options{site = "site", user = toolkit.user, generate = proc(site, out: string, user: rawptr) -> bool {
			return tk_site.project_build((^tk_site.Project_Site)(user), site, out) && docs_build("docs", out) == ""
		}}
		if why := tk_site.check_arguments(args[1:], &o); why != "" { return toolbox.done(why) }
		return toolbox.ended(tk_site.check(o))
	}
	return toolkit.run_with(args, toolkit.user)
}
