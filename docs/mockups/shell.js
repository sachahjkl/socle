// The title bar and the sidebar, the same on every screen: each page names itself in <body data-page>.
const ICON = {
  overview: "", apps: "", people: "", desktop: "", hardware: "", sound: "",
  network: "", printing: "", gaming: "", sharing: "", power: "",
  updates: "", history: "", templates: "", all: "", search: "",
};
const PAGES = [
  [null, [["overview", "Overview"]]],
  ["System", [["apps", "Apps"], ["people", "People"], ["desktop", "Desktop"], ["hardware", "Hardware"], ["sound", "Sound"],
    ["network", "Network"], ["printing", "Printing"], ["gaming", "Gaming"], ["sharing", "Sharing"], ["power", "Start and power"]]],
  ["Manage", [["updates", "Updates"], ["history", "History"], ["templates", "Templates"], ["all", "All settings"]]],
];
const page = document.body.dataset.page;
const badges = { updates: "2" };
let side = "";
for (const [group, items] of PAGES) {
  if (group) side += `<div class="group">${group}</div>`;
  for (const [id, title] of items) {
    side += `<a class="${id === page ? "on" : ""}"><i class="i">${ICON[id]}</i>${title}${badges[id] ? `<span class="n">${badges[id]}</span>` : ""}</a>`;
  }
}
const installer = document.body.dataset.side === "none";
const search = installer ? "" : `<div class="search"><i class="i">${ICON.search}</i>Search settings, apps, actions<span class="k">Ctrl K</span></div>`;
const title = `<div class="titlebar"><span class="name">socle</span>${search}
  <div class="wc"><i class="i"></i><i class="i"></i></div></div>`;
const body = document.querySelector(".body");
if (body && !installer) body.insertAdjacentHTML("afterbegin", `<nav class="side">${side}</nav>`);
document.body.insertAdjacentHTML("afterbegin", title);
