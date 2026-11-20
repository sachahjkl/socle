package socle

// The Templates page's own parts (src/md/data/templates.md): the applied system saved as a template, and a template
// started from a link. Their files are written on workers (template.odin).

import "core:fmt"
import "core:os"
import "core:strings"
import lucide "gt:lucide"
import "gt:ui"

EXPORT_VIEW :: "export"

Template_State :: struct {
	link:         ui.Line_Edit,   // From a link: <flake reference>#<name>
	linking:      bool,
	title:        ui.Line_Edit,   // Save as a template
	about:        ui.Line_Edit,
	saving:       bool,
}

template_state_destroy :: proc(s: ^Template_State) {
	ui.line_edit_destroy(&s.link)
	ui.line_edit_destroy(&s.title)
	ui.line_edit_destroy(&s.about)
}

// Where saved templates go: the person's own folder of them.
@(private = "file")
templates_home :: proc() -> string { return join(os.get_env("HOME", context.temp_allocator), "socle-templates") }

templates_own :: proc(app: ^App, em: f32) {
	s := &app.templates
	section("Your own", em)
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
	if ui.row(id = "###own_row") {
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .Y})
		if ui.column(id = "###own_words") {
			weak(app.target == .Home ? "Save this home's applied settings as a template, to start another home from it." : "Save the applied system as a template: its settings, without its people or their accounts.", "own_about")
		}
		ui.spacer(ui.px(em))
		if ui.button("template_save", "Save as a template", lucide.SAVE, {busy = s.saving, disabled = app.info == nil}).clicked {
			ui.view_open(ui.state_views(&app.main.state), EXPORT_VIEW, app)
		}
	}
	section("From a link", em)
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
	if ui.row(id = "###link_row") {
		ui.next({width = ui.fill(), height = ui.px(ui.control_height())})
		res := ui.line_edit("###template_link", &s.link, {placeholder = "github:owner/repository#name"})
		ui.spacer(ui.px(em * 0.6))
		_, _, bad := template_link(ui.line_edit_string(&s.link))
		go := ui.button("template_link_go", "Start from it", lucide.LINK, {busy = s.linking, disabled = bad != "" || apply_busy(app)}).clicked
		if (go || (res.committed && bad == "")) && !s.linking { template_link_start(app) }
	}
	ui.spacer(ui.px(em * 0.5))
	weak("A template runs as an administrator when the system is built: start from the templates of people you trust.", "link_note")
}

////////////////////////////////
// From a link

@(private = "file")
Link_Job :: struct { app: ^App, folder, link, ref, why: string }

@(private = "file")
template_link_start :: proc(app: ^App) {
	s := &app.templates
	if app.source == .Demo { ui.announce(&app.announcer, .Info, "The demo starts from no link", "On a real system, the link's template becomes the one you start from."); return }
	s.linking = true
	j := new_clone(Link_Job{app = app, folder = strings.clone(app.folder), link = strings.clone(ui.line_edit_string(&s.link))})
	ui.task(&app.main.state, proc(d: rawptr) {
		j := (^Link_Job)(d)
		ref, why := template_add(j.folder, j.link)
		j.ref, j.why = strings.clone(ref), strings.clone(why)
	}, proc(d: rawptr, _: u64) {
		j := (^Link_Job)(d)
		app := j.app
		app.templates.linking = false
		if j.why != "" {
			ui.announce(&app.announcer, .Bad, "The link's template was not added", j.why, stays = true)
		} else {
			// (the person's layer points at it; the evaluation locks the new input, and the review shows the change)
			layer_set_template(&app.draft, j.ref)
			draft_changed(app)
			ui.line_edit_set(&app.templates.link, "")
			ui.announce(&app.announcer, .Info, "Starting from the link's template", "Its values show once the folder is evaluated. Nothing changes until you apply.")
		}
		delete(j.folder); delete(j.link); delete(j.ref); delete(j.why)
		free(j)
	}, j, proc(d: rawptr) { free(d) })
}

////////////////////////////////
// Save as a template

export_view :: proc(v: ^ui.View, app: ^App) {
	s := &app.templates
	em := ui.font_size()
	title := strings.trim_space(ui.line_edit_string(&s.title))
	name := template_name(title)
	if ui.dialog_body("export_body") {
		if ui.form_row("Title") {
			ui.next({width = ui.fill(), height = ui.px(ui.control_height())})
			ui.line_edit("###export_title", &s.title, {placeholder = "Our family desktop"})
		}
		ui.spacer(ui.px(em * 0.6))
		if ui.form_row("What it is") {
			ui.next({width = ui.fill(), height = ui.px(ui.control_height())})
			ui.line_edit("###export_about", &s.about, {placeholder = "Krita for the drawings, no printer"})
		}
		ui.spacer(ui.px(em * 0.8))
		weak(name != "" ? fmt.tprintf("socle writes %s/%s, a git repository to push to any git host.", templates_home(), name) : "Give it a title.", "export_where")
	}
	if ui.dialog_buttons("export_buttons") {
		if ui.button("export_back", "Cancel").clicked { ui.view_end(v, ui.VIEW_CANCELLED) }
		if ui.button("export_go", "Save", lucide.SAVE, {intent = .Primary, disabled = name == "" || s.saving}).clicked {
			ui.view_end(v, 0)
			template_save_start(app, name, title, strings.trim_space(ui.line_edit_string(&s.about)))
		}
	}
}

@(private = "file")
Save_Job :: struct { app: ^App, dir, name, title, about, committed, template, why: string, target: Target }

@(private = "file")
template_save_start :: proc(app: ^App, name, title, about: string) {
	if app.source == .Demo { ui.announce(&app.announcer, .Info, "The demo saves nothing", "On a real system, socle writes the template's folder."); return }
	app.templates.saving = true
	// (the applied layer and the chain's values as text: the worker parses its own copies)
	chain := "{}"
	if app.info != nil { chain = json_text(app.info.template) }
	j := new_clone(Save_Job{
		app = app, dir = strings.clone(join(templates_home(), name)), name = strings.clone(name), title = strings.clone(title),
		about = strings.clone(about), committed = layer_text(app.committed), template = strings.clone(chain), target = app.target,
	})
	ui.task(&app.main.state, proc(d: rawptr) {
		j := (^Save_Job)(d)
		committed := layer_parse(j.committed)
		defer layer_destroy(&committed)
		chain := layer_parse(fmt.tprintf(`{{"values": %s}}`, j.template))
		defer layer_destroy(&chain)
		values, parent := export_of(committed, at(chain.tree, {"values"}))
		if why := template_export(j.dir, {name = j.name, title = j.title, description = j.about, target = j.target, parent = parent, values = values}); why != "" {
			j.why = strings.clone(why)
		}
	}, proc(d: rawptr, _: u64) {
		j := (^Save_Job)(d)
		app := j.app
		app.templates.saving = false
		if j.why != "" { ui.announce(&app.announcer, .Bad, "The template was not saved", j.why, stays = true) }
		else { ui.announce(&app.announcer, .Good, fmt.tprintf("Saved in %s", j.dir), fmt.tprintf("Push it to a git host, then start from github:<owner>/<repository>#%s.", j.name), stays = true) }
		delete(j.dir); delete(j.name); delete(j.title); delete(j.about); delete(j.committed); delete(j.template); delete(j.why)
		free(j)
	}, j, proc(d: rawptr) { free(d) })
}
