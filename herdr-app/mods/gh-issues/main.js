// GitHub issues of the repository the focused terminal is in, filterable by
// label (click chips to combine them), text, state and "assigned to me".
// Data comes from the `gh` CLI on this machine; clicking an issue opens it in the browser.
import { View, div } from "gpui-kit";
import * as fs from "fs/promises";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { spaces, panes, focused, exec, theme, layout, window, run, knownAgents, notify, home, appHome, readTextFile } from "herdr";

const LIMIT = { open: 300, closed: 100 };
const STALE_MS = 60000;
const FIELDS = "number,title,labels,assignees,author,createdAt,updatedAt,url";
const SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

// Where the focused terminal is (same rule as the shipped Changes panel).
function location() {
  const space = spaces().find((s) => s.active), f = focused();
  const pane = f?.pane ? panes().find((p) => p.pane === f.pane) : null;
  const on = f?.pane === null ? (f.terminal?.includes("/") ? f.terminal.split("/")[0] : null) : space?.machine ?? null;
  return { cwd: pane?.cwd || f?.cwd || space?.folder, on };
}
const contextKey = () => JSON.stringify(location());

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const hit = find(child, id);
    if (hit) return hit;
  }
  return null;
}

// Only fetch while someone can see the panel.
function isShown() {
  const root = layout(), panel = find(root, "panel"), body = find(root, "panel-body");
  const mine = body?.children?.find((c) => c.content?.mod === "gh-issues");
  if (!mine) return true; // placed somewhere else (a pane, a window): assume visible
  return Boolean(panel && !panel.hidden && body.active === mine.id);
}

function parseGithub(url) {
  const m = /github\.com[:/]+([^/\s]+)\/([^/\s]+?)(?:\.git)?\/?$/.exec((url ?? "").trim());
  return m ? `${m[1]}/${m[2]}` : null;
}

async function resolveRepo(cwd, on) {
  const top = await exec("git", ["rev-parse", "--show-toplevel"], { cwd, on });
  if (top.code !== 0) return { error: "Not inside a git repository" };
  const root = top.stdout.trim();
  // gh knows `gh repo set-default`; only ask it on this machine (remote ones may lack gh).
  if (!on) {
    const v = await exec("gh", ["repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"], { cwd: root }).catch(() => null);
    if (v?.code === 0 && v.stdout.trim()) return { root, on, repo: v.stdout.trim() };
  }
  const remotes = await exec("git", ["remote", "-v"], { cwd: root, on });
  const lines = remotes.stdout.split("\n").sort((a, b) => Number(!a.startsWith("origin")) - Number(!b.startsWith("origin")));
  for (const line of lines) {
    const repo = parseGithub(line.split(/\s+/)[1]);
    if (repo) return { root, on, repo };
  }
  return { root, error: "This repository has no GitHub remote" };
}

const slug = (text) => text.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40).replace(/-+$/, "");
const issueBranch = (issue) => `issue-${issue.number}${slug(issue.title) ? "-" + slug(issue.title) : ""}`;

function taskFor(repo, issue) {
  return `Work on GitHub issue ${repo}#${issue.number}: "${issue.title}" (${issue.url}). ` +
    `Start by reading it, including the comments, with \`gh issue view ${issue.number} -R ${repo} --comments\`.`;
}

// A machine's home folder, as Herdr's worktree mod finds it (sh, else PowerShell on Windows).
async function homeOf(on) {
  if (!on) return home().replace(/\\/g, "/");
  let r = null;
  try { r = await exec("sh", ["-c", 'printf %s "$HOME"'], { on }); } catch {}
  if (!r || r.code !== 0 || !r.stdout.trim()) r = await exec("powershell.exe", ["-NoProfile", "-Command", "[Console]::Write($HOME)"], { on });
  if (r.code !== 0 || !r.stdout.trim()) throw new Error("Could not find the home folder on " + on);
  return r.stdout.trim().replace(/\\/g, "/");
}

// Debug trail: ~/.config/herdr-app/data/gh-issues/debug.log (last 200 lines).
let trail = [];
function debug(...parts) {
  trail = [...trail.slice(-199), `${new Date().toISOString()} ${parts.map((p) => typeof p === "string" ? p : JSON.stringify(p)).join(" ")}`];
  const dir = `${appHome()}/data/gh-issues`;
  fs.mkdir(dir, { recursive: true }).then(() => fs.writeFile(`${dir}/debug.log`, trail.join("\n") + "\n")).catch(() => {});
}

function ago(iso) {
  const s = Math.max(0, (Date.now() - Date.parse(iso)) / 1000);
  if (s < 60) return "just now";
  const units = [[60, "m"], [24, "h"], [30, "d"], [12, "mo"], [Infinity, "y"]];
  let v = s / 60;
  for (const [n, u] of units) {
    if (v < n) return `${Math.floor(v)}${u} ago`;
    v /= n;
  }
  return "";
}

function load(key, fallback) {
  try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; }
}
function save(key, value) {
  try { localStorage.setItem(key, JSON.stringify(value)); } catch {}
}

export default class GhIssues extends View {
  init(_props, cx) {
    this.repos = {};      // context -> { repo, root } | { error }
    this.cache = {};      // repo -> { open: {items, at}, closed: {items, at} }
    this.agents = {};     // machine -> the agent to start (null: asking, false: none)
    this.state = load("state", "open");
    this.mode = load("mode", "all");           // "all" | "any" for several labels
    this.sort = load("sort", "created");       // "created" | "updated"
    this.mine = load("mine", false);
    this.selectedBy = load("selected", {});    // repo -> [label names]
    this.query = "";
    this.me = null;
    this.input = InputState.new({ placeholder: "Filter by title, #number or author" });
    this.input.on("change", (_e, cx) => { this.query = this.input.value(); cx.notify(); });
    this.input.on("focus", (_e, cx) => { this.typing = true; cx.notify(); });
    this.input.on("blur", (_e, cx) => { this.typing = false; cx.notify(); });
    cx.timer.every(15000, (cx) => { if (isShown()) this.refresh(cx); });
  }

  get selected() { return this.repo ? this.selectedBy[this.repo] ?? [] : []; }
  set selected(names) { if (this.repo) { this.selectedBy[this.repo] = names; save("selected", this.selectedBy); } }

  refresh(cx, force = false) {
    const { cwd, on } = location(), ctx = contextKey();
    if (ctx !== this.ctx) { this.ctx = ctx; this.repo = null; this.error = null; }
    if (!cwd) { this.error = "Focus a terminal inside a GitHub repository"; return; }
    if (this.busy) { this.again = force ? "force" : this.again || true; return; }
    const state = this.state;
    this.busy = true;
    cx.spawn(async (cx) => {
      try {
        let info = this.repos[ctx];
        if (!info || info.error || force) info = this.repos[ctx] = await resolveRepo(cwd, on);
        if (this.ctx !== ctx) return;
        this.repo = info.repo ?? null;
        this.error = info.error ?? null;
        if (!this.repo) return;
        const repo = this.repo, entry = (this.cache[repo] ??= {});
        if (!force && entry[state] && Date.now() - entry[state].at < STALE_MS) return;
        this.syncing = true; cx.notify();
        const r = await exec("gh", ["issue", "list", "-R", repo, "--state", state, "--limit", String(LIMIT[state]), "--json", FIELDS]);
        if (r.code !== 0) throw new Error(r.stderr.trim() || "gh issue list failed");
        entry[state] = { items: JSON.parse(r.stdout), at: Date.now() };
        if (this.ctx === ctx) this.error = null;
      } catch (e) {
        if (this.ctx === ctx) this.error = String(e?.message ?? e);
      } finally {
        this.busy = false; this.syncing = false;
        const again = this.again; this.again = false;
        if (again || this.ctx !== contextKey() || this.state !== state) this.refresh(cx, again === "force");
        cx.notify();
      }
    });
  }

  // The agent people pick most on that machine (programs.json `run`), asked once per machine.
  agentFor(on, cx) {
    const where = on ?? "";
    if (!(where in this.agents)) {
      const pending = this.agents[where] = this.lookupAgent(on);
      cx.spawn(async (cx) => { const a = await pending; if (this.agents[where] === pending) this.agents[where] = a; cx.notify(); });
    }
    const v = this.agents[where];
    return v instanceof Promise ? null : v;
  }

  async lookupAgent(on) {
    try {
      const text = await readTextFile(`${appHome()}/mods/gh-issues/agents.json`).catch(() => null);
      const chosen = text ? JSON.parse(text)[on ?? ""] : null;
      if (chosen?.run?.length) { debug("agents.json", on, chosen); return { name: chosen.name ?? chosen.run[0], run: chosen.run }; }
    } catch (e) { debug("agents.json unreadable", String(e?.message ?? e)); }
    try {
      const list = await knownAgents({ on });
      debug("knownAgents", on, list.map((a) => ({ key: a.key, installed: a.installed, run: a.run })));
      return list.find((a) => a.installed) ?? false;
    } catch (e) {
      debug("knownAgents failed", on, String(e?.message ?? e));
      return false;
    }
  }

  start(issue, worktree, cx) {
    const info = this.repos[this.ctx], repo = this.repo;
    debug("start", { issue: issue.number, worktree, repo, info, starting: this.starting });
    if (!info?.root || !repo) { notify({ title: "No repository", body: "Focus a terminal in the repository first.", level: "warning" }); return; }
    if (this.starting) return;
    this.starting = issue.number; cx.notify();
    cx.spawn(async (cx) => {
      try {
        const on = info.on, where = on ?? "";
        let agent = this.agents[where];
        if (agent instanceof Promise) agent = await agent;
        else if (agent == null) agent = await (this.agents[where] = this.lookupAgent(on));
        this.agents[where] = agent;
        if (!agent) throw new Error(`Herdr reports no installed agent on ${on ?? "this computer"}.`);
        const task = taskFor(repo, issue), tab = `#${issue.number}`;
        if (!worktree) {
          const args = { name: tab, folder: info.root, argv: agent.run, task };
          debug("tab.new", args);
          const r = run("tab.new", args);
          debug("tab.new returned", r);
          notify({ title: `${agent.name} on #${issue.number}`, body: issue.title, level: "success", timeout: 4000 });
          return;
        }
        const git = (args) => exec("git", args, { cwd: info.root, on });
        const common = await git(["rev-parse", "--path-format=absolute", "--git-common-dir"]);
        if (common.code !== 0) throw new Error(common.stderr.trim());
        const main = common.stdout.trim().replace(/\/\.git\/?$/, ""), name = main.split("/").pop();
        const branch = issueBranch(issue), path = `${await homeOf(on)}/.herdr/worktrees/${name}/${branch}`;
        // Reuse a checkout from an earlier run; else make the branch (or check out an existing one).
        const there = await exec("git", ["-C", path, "rev-parse", "--show-toplevel"], { on });
        if (there.code !== 0) {
          const exists = (await git(["show-ref", "--verify", "--quiet", `refs/heads/${branch}`])).code === 0;
          const r = await git(exists ? ["worktree", "add", path, branch] : ["worktree", "add", "-b", branch, path, "HEAD"]);
          debug("worktree add", path, r);
          if (r.code !== 0) throw new Error((r.stderr || r.stdout).trim() || "git worktree add failed");
        }
        const args = { folder: path, machine: on, tab, argv: agent.run, task };
        debug("space.new", args);
        run("space.new", args);
        notify({ title: `${agent.name} on #${issue.number}`, body: `New worktree: ${branch}`, level: "success", timeout: 4000 });
      } catch (e) {
        debug("start failed", String(e?.stack ?? e));
        notify({ title: `Couldn't start on #${issue.number}`, body: String(e?.message ?? e), level: "error" });
      } finally { this.starting = null; cx.notify(); }
    });
  }

  toggleLabel(name, cx) {
    const sel = this.selected;
    this.selected = sel.includes(name) ? sel.filter((n) => n !== name) : [...sel, name];
    cx.notify();
  }

  setState(state, cx) {
    if (this.state === state) return;
    this.state = state; save("state", state);
    this.refresh(cx);
    cx.notify();
  }

  toggleMine(cx) {
    this.mine = !this.mine; save("mine", this.mine);
    if (this.mine && !this.me) cx.spawn(async (cx) => {
      const r = await exec("gh", ["api", "user", "-q", ".login"]).catch(() => null);
      this.me = r?.code === 0 ? r.stdout.trim() : null;
      cx.notify();
    });
    cx.notify();
  }

  openUrl(url) {
    exec(window()?.platform === "macos" ? "open" : "xdg-open", [url]).catch(() => {});
  }

  visible(items) {
    const q = this.query.trim().toLowerCase(), sel = this.selected;
    const num = /^#?(\d+)$/.exec(q)?.[1];
    let out = items.filter((i) => {
      if (sel.length) {
        const names = new Set(i.labels.map((l) => l.name));
        if (this.mode === "all" ? !sel.every((n) => names.has(n)) : !sel.some((n) => names.has(n))) return false;
      }
      if (this.mine && !(this.me && i.assignees.some((a) => a.login === this.me))) return false;
      if (!q) return true;
      if (num) return String(i.number).startsWith(num);
      return i.title.toLowerCase().includes(q) || i.author?.login?.toLowerCase().includes(q);
    });
    const field = this.sort === "updated" ? "updatedAt" : "createdAt";
    return out.sort((a, b) => Date.parse(b[field]) - Date.parse(a[field]));
  }

  // ---------- drawing ----------

  segment(id, options, current, onPick, t) {
    return h_flex().h(24).p(2).gap(2).rounded(7).bg(t.raised).border_1().border_color(t.border).children(options.map(([value, label]) =>
      div().id(`${id}-${value}`).h_full().px(8).flex().items_center().rounded(5).text_size(11.5).cursor_pointer()
        .bg(current === value ? t.background : t.raised).text_color(current === value ? t.foreground : t.muted)
        .hover((s) => s.text_color(t.foreground))
        .on_click((_e, cx) => onPick(value, cx)).child(label)));
  }

  chip(label, count, on, t, small = false) {
    const c = `#${label.color || "8b949e"}`;
    return h_flex().id(`${small ? "il" : "lbl"}-${label.name}-${count ?? ""}`).h(small ? 18 : 22).px(small ? 6 : 8).gap(5).items_center().rounded(11)
      .flex_none().cursor_pointer().text_size(small ? 10.5 : 11)
      .border_1().border_color(on ? c : c + "70").bg(on ? c + "55" : c + "1c").text_color(t.foreground)
      .hover((s) => s.bg(c + "40"))
      .on_click((_e, cx) => { cx.stop_propagation(); this.toggleLabel(label.name, cx); })
      .when(!small, (e) => e.child(div().size(8).rounded(4).flex_none().bg(c)))
      .child(label.name)
      .when(count !== undefined, (e) => e.child(div().text_color(t.dim).child(String(count))));
  }

  row(issue, t, agent) {
    const sel = this.selected;
    return v_flex().id(`issue-${issue.number}`).flex_none().px(10).py(7).gap(4).rounded(7).cursor_pointer()
      .hover((s) => s.bg(t.hover)).on_click(() => this.openUrl(issue.url))
      .child(h_flex().gap(8).items_start()
        .child(div().w(44).flex_none().text_size(12).text_color(this.state === "open" ? t.ansi2 : t.ansi5).child(`#${issue.number}`))
        .child(div().flex_1().min_w(0).child(issue.title)))
      .when(issue.labels.length > 0, (e) => e.child(h_flex().pl(52).gap(4).flex_wrap()
        .children(issue.labels.map((l) => this.chip(l, undefined, sel.includes(l.name), t, true)))))
      .child(h_flex().pl(52).gap(6).items_center()
        .child(div().flex_1().min_w(0).text_size(11).text_color(t.dim).truncate().child([
          issue.author?.login,
          this.sort === "updated" ? `updated ${ago(issue.updatedAt)}` : `opened ${ago(issue.createdAt)}`,
          issue.assignees.length ? `→ ${issue.assignees.map((a) => a.login).join(", ")}` : null,
        ].filter(Boolean).join(" · ")))
        .when(this.state === "open", (e) => e
          .child(this.action(`agent-${issue.number}`, "▶ Agent", `Start ${agent} on #${issue.number} in a new tab here`, (cx) => this.start(issue, false, cx), t))
          .child(this.action(`wt-${issue.number}`, this.starting === issue.number ? "Starting…" : "⎇ Worktree",
            `New worktree on branch ${issueBranch(issue)} with ${agent} on #${issue.number}`, (cx) => this.start(issue, true, cx), t))));
  }

  action(id, label, tip, onClick, t) {
    return div().id(id).h(20).px(7).flex().flex_none().items_center().rounded(5).border_1().border_color(t.border)
      .text_size(10.5).text_color(t.muted).cursor_pointer().tooltip(tip)
      .hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_click((_e, cx) => { cx.stop_propagation(); onClick(cx); })
      .child(label);
  }

  render(cx) {
    const shown = isShown();
    if (shown && (contextKey() !== this.ctx || !this.wasShown)) this.refresh(cx);
    this.wasShown = shown;

    const t = theme(), repo = this.repo, entry = repo ? this.cache[repo]?.[this.state] : null;
    const info = this.repos[this.ctx], found = info?.root ? this.agentFor(info.on, cx) : null;
    const agentName = found ? found.name : found === false ? "an agent (none installed)" : "your agent";
    const items = entry?.items ?? [], list = this.visible(items), sel = this.selected;

    // Labels used by the loaded issues, most used first; selected ones always stay.
    const labels = new Map();
    for (const i of items) for (const l of i.labels) {
      const e = labels.get(l.name) ?? { label: l, count: 0 };
      e.count++; labels.set(l.name, e);
    }
    for (const name of sel) if (!labels.has(name)) labels.set(name, { label: { name, color: "" }, count: 0 });
    const chips = [...labels.values()].sort((a, b) => Number(sel.includes(b.label.name)) - Number(sel.includes(a.label.name)) || b.count - a.count || a.label.name.localeCompare(b.label.name));

    const header = h_flex().h(42).flex_none().px(14).gap(8).items_center().border_b(1).border_color(t.border)
      .child(div().text_color(t.ansi2).child("◉"))
      .child(div().font_semibold().child("Issues"))
      .child(div().id("repo").flex_1().min_w(0).text_right().truncate().text_size(11).text_color(t.dim)
        .when(Boolean(repo), (e) => e.cursor_pointer().hover((s) => s.text_color(t.foreground)).on_click(() => this.openUrl(`https://github.com/${repo}/issues`)))
        .child(repo ?? ""))
      .child(div().id("refresh").h(24).px(8).flex().items_center().gap(4).rounded(6).border_1().border_color(t.border).text_size(11.5).text_color(t.muted).cursor_pointer()
        .hover((s) => s.bg(t.hover).text_color(t.foreground))
        .on_click((_e, cx) => this.refresh(cx, true))
        .child(this.syncing ? div().frames(SPINNER, 80) : div().child("↻"))
        .child(this.syncing ? "Syncing" : "Refresh"));

    const search = div().id("search").h(30).px(10).flex().items_center().rounded(8).border_1().border_color(this.typing ? t.accent : t.border)
      .cursor_text().on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .child(Input.new(this.input).h_full().w_full().text_size(12).text_color(t.foreground));

    const counts = (s) => this.cache[repo]?.[s]?.items?.length;
    const label = (s, name) => counts(s) === undefined ? name : `${name} ${counts(s)}${counts(s) >= LIMIT[s] ? "+" : ""}`;
    const controls = h_flex().gap(6).items_center().flex_wrap()
      .child(this.segment("state", [["open", label("open", "Open")], ["closed", label("closed", "Closed")]], this.state, (v, cx) => this.setState(v, cx), t))
      .child(this.segment("sort", [["created", "Newest"], ["updated", "Updated"]], this.sort, (v, cx) => { this.sort = v; save("sort", v); cx.notify(); }, t))
      .child(div().id("mine").h(24).px(8).flex().items_center().rounded(7).border_1().text_size(11.5).cursor_pointer()
        .border_color(this.mine ? t.accent : t.border).bg(this.mine ? t.selected : t.background).text_color(this.mine ? t.foreground : t.muted)
        .on_click((_e, cx) => this.toggleMine(cx)).child("Mine"));

    const labelBar = v_flex().gap(6)
      .child(h_flex().gap(6).items_center().text_size(11).text_color(t.dim)
        .child(div().child("Labels"))
        .when(sel.length > 1, (e) => e.child(this.segment("mode", [["all", "match all"], ["any", "match any"]], this.mode, (v, cx) => { this.mode = v; save("mode", v); cx.notify(); }, t)))
        .child(div().flex_1())
        .when(sel.length > 0, (e) => e.child(div().id("clear").cursor_pointer().hover((s) => s.text_color(t.foreground))
          .on_click((_e, cx) => { this.selected = []; cx.notify(); }).child("Clear"))))
      .child(div().id("labels").max_h(112).overflow_y_scrollbar()
        .child(h_flex().gap(5).flex_wrap()
          .children(chips.map(({ label, count }) => this.chip(label, count, sel.includes(label.name), t)))
          .when(!chips.length, (e) => e.child(div().text_size(11).text_color(t.dim).child(entry ? "No labels on these issues" : "…")))));

    const empty = (title, body) => v_flex().flex_1().items_center().justify_center().gap(6).p(24)
      .child(div().text_size(22).text_color(t.dim).child("◉"))
      .child(div().font_semibold().child(title))
      .when(Boolean(body), (e) => e.child(div().text_size(12).text_color(t.dim).text_center().child(body)));

    let body;
    if (!repo) body = empty(this.error ? "No GitHub repository" : "Looking for a repository…", this.error);
    else if (!entry) body = this.error ? empty("Couldn't load issues", this.error) : empty("Loading issues…");
    else body = v_flex().flex_1().min_h(0)
      .child(v_flex().id("issues-list").flex_1().min_h(0).overflow_y_scrollbar().p(6).gap(1)
        .children(list.map((i) => this.row(i, t, agentName)))
        .when(!list.length, (e) => e.child(div().p(12).text_color(t.dim).child(items.length ? "No issues match these filters" : `No ${this.state} issues`))))
      .child(h_flex().h(26).flex_none().px(12).gap(6).items_center().border_t(1).border_color(t.border).text_size(11).text_color(t.dim)
        .child(div().flex_1().truncate().child(this.error ? `⚠ ${this.error}` : `${list.length} of ${items.length}${items.length >= LIMIT[this.state] ? ` (latest ${LIMIT[this.state]})` : ""}`))
        .child(div().child(`synced ${ago(new Date(entry.at).toISOString())}`)));

    return v_flex().id("gh-issues").size_full().min_h(0).rounded(10).overflow_hidden().bg(t.background).border_1().border_color(t.border)
      .text_color(t.foreground).text_size(13)
      .child(header)
      .when(Boolean(repo), (e) => e.child(v_flex().flex_none().p(10).gap(8).border_b(1).border_color(t.border).child(search).child(controls).child(labelBar)))
      .child(body);
  }
}
