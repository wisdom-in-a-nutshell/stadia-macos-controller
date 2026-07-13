"use strict";

const PROFILE_LABELS = {
  codexApp: "Codex",
  ghostty: "Ghostty",
  alwaysOn: "All apps",
};

const CONTROL_LABELS = {
  leftShoulder: "L1 · Left shoulder",
  rightShoulder: "R1 · Right shoulder",
  leftTrigger: "L2 · Left trigger",
  rightTrigger: "R2 · Right trigger",
  dpadUp: "D-pad Up",
  dpadDown: "D-pad Down",
  dpadLeft: "D-pad Left",
  dpadRight: "D-pad Right",
  options: "Options",
  share: "Capture",
  menu: "Menu",
  home: "Stadia",
  a: "A button",
  b: "B button",
  x: "X button",
  y: "Y button",
  leftThumbstickButton: "L3 · Left stick press",
  rightThumbstickButton: "R3 · Right stick press",
  leftStickVerticalScroll: "Left stick · Vertical",
  rightStickVerticalScroll: "Right stick · Vertical scroll",
  rightStickPointer: "Right stick · Pointer",
  rightStickUp: "Right stick · Up",
  rightStickDown: "Right stick · Down",
  rightStickLeft: "Right stick · Left",
  rightStickRight: "Right stick · Right",
};

const CONTROL_ORDER = [
  "leftShoulder",
  "rightShoulder",
  "leftTrigger",
  "rightTrigger",
  "dpadUp",
  "dpadDown",
  "dpadLeft",
  "dpadRight",
  "options",
  "share",
  "menu",
  "leftStickVerticalScroll",
  "leftThumbstickButton",
  "rightStickUp",
  "rightStickDown",
  "rightStickLeft",
  "rightStickRight",
  "rightStickVerticalScroll",
  "rightStickPointer",
  "rightThumbstickButton",
  "a",
  "b",
  "x",
  "y",
  "home",
];

const KEY_CODES = {
  0: "A",
  8: "C",
  21: "4",
  36: "Return",
  44: "/",
  48: "Tab",
  51: "Delete",
  53: "Escape",
  59: "Control",
  111: "F12",
  123: "←",
  124: "→",
  125: "↓",
  126: "↑",
};

const SHIFTED_KEYS = {
  21: "$",
};

const MODIFIER_SYMBOLS = {
  command: "⌘",
  control: "⌃",
  option: "⌥",
  shift: "⇧",
};

const MODIFIER_ORDER = ["control", "option", "shift", "command"];

const elements = {
  configState: document.querySelector("#config-state"),
  contextNote: document.querySelector("#context-note"),
  controllerHeading: document.querySelector("#controller-heading"),
  controllerMap: document.querySelector("#controller-map"),
  calloutLayer: document.querySelector("#callout-layer"),
  detailControl: document.querySelector("#detail-control"),
  detailDescription: document.querySelector("#detail-description"),
  detailFacts: document.querySelector("#detail-facts"),
  detailSource: document.querySelector("#detail-source"),
  detailTitle: document.querySelector("#detail-title"),
  factTemplate: document.querySelector("#fact-template"),
  loadedAt: document.querySelector("#loaded-at"),
  mappingCount: document.querySelector("#mapping-count"),
  mappingList: document.querySelector("#mapping-list"),
  profileContext: document.querySelector("#profile-context"),
  profileTabs: document.querySelector("#profile-tabs"),
  refreshButton: document.querySelector("#refresh-button"),
};

const state = {
  config: null,
  profileName: null,
  records: new Map(),
  selectedControl: null,
};

const interactiveDiagram = window.matchMedia("(min-width: 720px)");

const SVGNS = "http://www.w3.org/2000/svg";

// Anchor point on the controller silhouette for each callout, plus which side
// rail the label sits in. Cluster entries (dpad, rstick) fan four directions.
const CALLOUTS = [
  { id: "leftTrigger", token: "L2", side: "left", anchor: { x: 224, y: 74 } },
  { id: "leftShoulder", token: "L1", side: "left", anchor: { x: 184, y: 131 } },
  {
    id: "dpad",
    token: "D-pad",
    side: "left",
    anchor: { x: 203, y: 250 },
    members: [
      { glyph: "↑", control: "dpadUp" },
      { glyph: "↓", control: "dpadDown" },
      { glyph: "←", control: "dpadLeft" },
      { glyph: "→", control: "dpadRight" },
    ],
  },
  { id: "options", token: "Options", side: "left", anchor: { x: 398, y: 222 } },
  { id: "share", token: "Capture", side: "left", anchor: { x: 413, y: 312 } },
  { id: "leftStickVerticalScroll", token: "L-stick", side: "left", anchor: { x: 302, y: 344 } },
  { id: "leftThumbstickButton", token: "L3", side: "left", anchor: { x: 322, y: 376 } },

  { id: "rightTrigger", token: "R2", side: "right", anchor: { x: 676, y: 74 } },
  { id: "rightShoulder", token: "R1", side: "right", anchor: { x: 716, y: 131 } },
  { id: "y", token: "Y", side: "right", anchor: { x: 676, y: 206 } },
  { id: "menu", token: "Menu", side: "right", anchor: { x: 506, y: 222 } },
  { id: "x", token: "X", side: "right", anchor: { x: 636, y: 248 } },
  { id: "b", token: "B", side: "right", anchor: { x: 712, y: 250 } },
  { id: "a", token: "A", side: "right", anchor: { x: 676, y: 300 } },
  {
    id: "rstick",
    token: "Right stick",
    side: "right",
    anchor: { x: 600, y: 352 },
    members: [
      { glyph: "↑", control: "rightStickUp" },
      { glyph: "↓", control: "rightStickDown" },
      { glyph: "←", control: "rightStickLeft" },
      { glyph: "→", control: "rightStickRight" },
    ],
  },
  { id: "rightThumbstickButton", token: "R3", side: "right", anchor: { x: 578, y: 380 } },
];

const CALLOUT_LAYOUT = {
  railTop: 58,
  railBottom: 512,
  left: { labelX: 138, turnX: 160 },
  right: { labelX: 762, turnX: 740 },
  rowHeight: 34,
  clusterHead: 24,
  clusterRow: 19,
};

function profileLabel(profileName) {
  if (PROFILE_LABELS[profileName]) {
    return PROFILE_LABELS[profileName];
  }

  return profileName
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/^./, (letter) => letter.toUpperCase());
}

function controlLabel(control) {
  return CONTROL_LABELS[control] || control.replace(/([a-z])([A-Z])/g, "$1 $2");
}

function titleCase(value) {
  return value
    .replace(/[_:-]+/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function formatShortcut(action) {
  const modifiers = [...(action.modifiers || [])].sort(
    (left, right) => MODIFIER_ORDER.indexOf(left) - MODIFIER_ORDER.indexOf(right),
  );

  if (modifiers.length === 1 && modifiers[0] === "shift" && SHIFTED_KEYS[action.keyCode]) {
    return SHIFTED_KEYS[action.keyCode];
  }

  const prefix = modifiers.map((modifier) => MODIFIER_SYMBOLS[modifier] || titleCase(modifier)).join("");
  return `${prefix}${KEY_CODES[action.keyCode] || `Key ${action.keyCode}`}`;
}

function nativeMenuTarget(script) {
  if (!script) {
    return null;
  }

  const item = script.match(/menu item \"([^\"]+)\"/);
  const menu = script.match(/of menu \"([^\"]+)\"/);
  if (!item) {
    return null;
  }

  return menu ? `${menu[1]} → ${item[1]}` : item[1];
}

function actionSummary(action) {
  if (!action) {
    return "Unmapped";
  }

  switch (action.type) {
    case "applescript": {
      const target = nativeMenuTarget(action.script);
      return target ? target.split(" → ").at(-1) : "Native app command";
    }
    case "ghosttyAction":
      return titleCase(action.ghosttyAction || "Ghostty action");
    case "keystroke":
    case "modifierChord":
      return formatShortcut(action);
    case "holdKeystroke":
      return `Hold ${formatShortcut(action)}`;
    case "text":
      return action.pressEnter ? `“${action.text}” + Return` : `Type “${action.text}”`;
    case "shell":
      return compactDescription(action.description || "Run helper");
    case "mouseClick":
      return `${titleCase(action.mouseButton || "left")} click`;
    case "analogScroll":
      return "Vertical scroll";
    case "analogPointer":
      return "Move pointer";
    default:
      return titleCase(action.type || "Action");
  }
}

function compactDescription(description) {
  return description
    .replace(/^Capture button:\s*/i, "")
    .replace(/\s+through\s+.+$/i, "")
    .replace(/\s+via\s+.+$/i, "")
    .replace(/\s+in Codex app$/i, "")
    .replace(/\s+with\s+(?:Cmd|Ctrl|Shift|Option).+$/i, "")
    .replace(/^Open\s+/i, "Open ")
    .trim();
}

function truncateLabel(value, limit = 26) {
  const text = (value || "").trim();
  if (text.length <= limit) {
    return text;
  }
  return `${text.slice(0, limit - 1).trimEnd()}…`;
}

// A concise, human-readable "what it does" phrase for the diagram callouts.
// Menu and native actions already read well from the summary; keystrokes and
// typed text read better from a compacted description.
function calloutLabel(record) {
  if (!record) {
    return "Unmapped";
  }

  const action = record.action || {};
  if (action.type === "text" && action.text) {
    return truncateLabel(action.text, 18);
  }

  if (action.type === "shell") {
    const compact = compactDescription(action.description || "Run helper")
      .replace(/ in .*/i, "")
      .replace(/\b(Ghostty|Codex)\b/g, "")
      .replace(/\b(a|an|the|new)\b/gi, " ")
      .replace(/^Split right /i, "Split ")
      .replace(/\s{2,}/g, " ")
      .trim();
    return truncateLabel(compact.charAt(0).toUpperCase() + compact.slice(1), 22);
  }

  if (action.type === "keystroke" || action.type === "modifierChord") {
    const compact = (record.description || record.summary || "")
      .replace(/^Send\s+/i, "")
      .replace(/\s+in (the )?Codex app$/i, "")
      .replace(/\s+with\s+(?:Cmd|Ctrl|Shift|Option|Shift\+Tab).+$/i, "")
      .replace(/^Toggle the Codex app\s+/i, "Toggle ")
      .replace(/^Toggle Codex\s+/i, "Toggle ")
      .replace(/\bCodex\s+/g, "")
      .replace(/\s{2,}/g, " ")
      .trim();
    const phrase = compact || record.summary;
    return truncateLabel(phrase.charAt(0).toUpperCase() + phrase.slice(1), 22);
  }

  return truncateLabel(record.summary, 22);
}

function actionTypeLabel(type) {
  const labels = {
    applescript: "Native menu command",
    ghosttyAction: "Ghostty native action",
    holdKeystroke: "Held key",
    keystroke: "Keystroke",
    modifierChord: "Modifier chord",
    mouseClick: "Mouse click",
    shell: "Local helper",
    text: "Typed text",
    analogScroll: "Analog scroll",
    analogPointer: "Analog pointer",
  };
  return labels[type] || titleCase(type || "Action");
}

function actionDescription(action, fallback) {
  if (action?.description) {
    return action.description;
  }
  return fallback || actionSummary(action);
}

function createButtonRecord(control, mapping, source, configPath) {
  return {
    action: mapping.action,
    analog: null,
    configPath,
    control,
    description: actionDescription(mapping.action),
    mapping,
    source,
    summary: actionSummary(mapping.action),
  };
}

function resolveAnalog(profileName, key) {
  const alwaysConfig = state.config.alwaysOn?.analog?.[key];
  if (alwaysConfig && alwaysConfig.enabled !== false) {
    return {
      config: alwaysConfig,
      path: `alwaysOn.analog.${key}`,
      source: "alwaysOn",
    };
  }

  if (profileName === "alwaysOn") {
    return null;
  }

  const profile = state.config.profiles?.[profileName];
  const profileConfig = profile?.enabled === false ? null : profile?.analog?.[key];
  if (!profileConfig || profileConfig.enabled === false) {
    return null;
  }

  return {
    config: profileConfig,
    path: `profiles.${profileName}.analog.${key}`,
    source: profileName,
  };
}

function createAnalogRecord(control, action, source, configPath, analog, description) {
  return {
    action,
    analog,
    configPath,
    control,
    description: actionDescription(action, description),
    mapping: {
      edgeTrigger: analog.edgeTrigger,
      repeatIntervalMs: analog.repeatIntervalMs,
    },
    source,
    summary: actionSummary(action),
  };
}

function addAnalogRecords(records, profileName) {
  for (const [key, control, stickName] of [
    ["leftStickVerticalScroll", "leftStickVerticalScroll", "left stick"],
    ["rightStickVerticalScroll", "rightStickVerticalScroll", "right stick"],
  ]) {
    const resolved = resolveAnalog(profileName, key);
    if (!resolved) {
      continue;
    }

    const { config, path, source } = resolved;
    const direction = config.invert ? "inverted vertical scrolling" : "vertical scrolling";
    const action = {
      type: "analogScroll",
      description: `Use the ${stickName} for ${direction} from ${config.minLinesPerTick || 1} to ${config.maxLinesPerTick || 8} lines per tick.`,
    };
    records.set(
      control,
      createAnalogRecord(control, action, source, path, { kind: key, ...config }, action.description),
    );
  }

  const pointer = resolveAnalog(profileName, "rightStickPointer");
  if (pointer) {
    const action = {
      type: "analogPointer",
      description: `Move the pointer with the right stick, up to ${pointer.config.maxPixelsPerTick || 24} pixels per tick.`,
    };
    records.set(
      "rightStickPointer",
      createAnalogRecord(
        "rightStickPointer",
        action,
        pointer.source,
        pointer.path,
        { kind: "rightStickPointer", ...pointer.config },
        action.description,
      ),
    );
  }

  const vertical = resolveAnalog(profileName, "rightStickVerticalActions");
  if (vertical) {
    for (const [control, action] of [
      ["rightStickUp", vertical.config.upAction],
      ["rightStickDown", vertical.config.downAction],
    ]) {
      if (action) {
        records.set(
          control,
          createAnalogRecord(
            control,
            action,
            vertical.source,
            vertical.path,
            { kind: "rightStickVerticalActions", ...vertical.config },
          ),
        );
      }
    }
  }

  const horizontal = resolveAnalog(profileName, "rightStickHorizontalActions");
  if (horizontal) {
    for (const [control, action] of [
      ["rightStickLeft", horizontal.config.leftAction],
      ["rightStickRight", horizontal.config.rightAction],
    ]) {
      if (action) {
        records.set(
          control,
          createAnalogRecord(
            control,
            action,
            horizontal.source,
            horizontal.path,
            { kind: "rightStickHorizontalActions", ...horizontal.config },
          ),
        );
      }
    }
  }
}

function resolvedRecords(profileName) {
  const records = new Map();
  const alwaysMappings = state.config.alwaysOn?.mappings || {};

  for (const [control, mapping] of Object.entries(alwaysMappings)) {
    records.set(
      control,
      createButtonRecord(control, mapping, "alwaysOn", `alwaysOn.mappings.${control}`),
    );
  }

  if (profileName !== "alwaysOn") {
    const profile = state.config.profiles?.[profileName];
    if (profile && profile.enabled !== false) {
      for (const [control, mapping] of Object.entries(profile.mappings || {})) {
        records.set(
          control,
          createButtonRecord(control, mapping, profileName, `profiles.${profileName}.mappings.${control}`),
        );
      }
    }
  }

  addAnalogRecords(records, profileName);
  return records;
}

function profileNames() {
  const names = Object.entries(state.config.profiles || {})
    .filter(([, profile]) => profile.enabled !== false)
    .map(([name]) => name);
  const preferredOrder = ["codexApp", "ghostty"];
  names.sort((left, right) => {
    const leftIndex = preferredOrder.indexOf(left);
    const rightIndex = preferredOrder.indexOf(right);
    if (leftIndex !== -1 || rightIndex !== -1) {
      return (leftIndex === -1 ? 99 : leftIndex) - (rightIndex === -1 ? 99 : rightIndex);
    }
    return profileLabel(left).localeCompare(profileLabel(right));
  });
  return [...names, "alwaysOn"];
}

function renderTabs() {
  const fragment = document.createDocumentFragment();

  for (const profileName of profileNames()) {
    const button = document.createElement("button");
    button.className = "profile-tab";
    button.dataset.profile = profileName;
    button.id = `profile-${profileName}`;
    button.setAttribute("role", "tab");
    button.setAttribute("aria-controls", "main-content");
    button.textContent = profileLabel(profileName);
    fragment.append(button);
  }

  elements.profileTabs.replaceChildren(fragment);
}

function setSelectedProfile(profileName, { remember = true } = {}) {
  if (!profileNames().includes(profileName)) {
    profileName = profileNames()[0];
  }

  state.profileName = profileName;
  state.records = resolvedRecords(profileName);

  if (!state.records.has(state.selectedControl)) {
    state.selectedControl = state.records.has("rightShoulder")
      ? "rightShoulder"
      : sortedRecords()[0]?.control || null;
  }

  for (const tab of elements.profileTabs.querySelectorAll("[role=tab]")) {
    const selected = tab.dataset.profile === profileName;
    tab.setAttribute("aria-selected", String(selected));
    tab.tabIndex = selected ? 0 : -1;
  }

  document.documentElement.dataset.activeProfile = profileName;
  elements.profileContext.textContent = profileName === "alwaysOn"
    ? "Available in every application"
    : `${profileLabel(profileName)} · profile plus always-on`;
  elements.controllerHeading.textContent = `${profileLabel(profileName)} controls`;
  elements.mappingCount.textContent = `${state.records.size} mapped`;

  renderController();
  renderMappingList();
  renderDetail();

  if (remember) {
    try {
      localStorage.setItem("controller-guide-profile", profileName);
    } catch {
      // Storage can be unavailable in locked-down browser sessions.
    }
    const url = new URL(window.location.href);
    url.searchParams.set("profile", profileName);
    window.history.replaceState({}, "", url);
  }
}

function sortedRecords() {
  return [...state.records.values()].sort((left, right) => {
    const leftIndex = CONTROL_ORDER.indexOf(left.control);
    const rightIndex = CONTROL_ORDER.indexOf(right.control);
    return (leftIndex === -1 ? 999 : leftIndex) - (rightIndex === -1 ? 999 : rightIndex);
  });
}

function renderController() {
  elements.controllerMap.classList.toggle("is-reference-only", !interactiveDiagram.matches);

  for (const controlElement of elements.controllerMap.querySelectorAll(".control[data-control]")) {
    const control = controlElement.dataset.control;
    const record = state.records.get(control);
    const selected = control === state.selectedControl;
    controlElement.classList.toggle("is-unmapped", !record);
    controlElement.classList.toggle("is-selected", selected);
    if (interactiveDiagram.matches) {
      controlElement.setAttribute("role", "button");
      controlElement.removeAttribute("aria-hidden");
      controlElement.setAttribute("aria-disabled", String(!record));
      controlElement.tabIndex = record ? 0 : -1;
      controlElement.setAttribute(
        "aria-label",
        record ? `${controlLabel(control)}: ${record.summary}` : `${controlLabel(control)}: unmapped`,
      );
    } else {
      controlElement.removeAttribute("role");
      controlElement.removeAttribute("aria-disabled");
      controlElement.removeAttribute("aria-label");
      controlElement.setAttribute("aria-hidden", "true");
      controlElement.tabIndex = -1;
    }
  }

  renderCallouts();
}

function svgEl(name, attrs = {}) {
  const node = document.createElementNS(SVGNS, name);
  for (const [key, value] of Object.entries(attrs)) {
    node.setAttribute(key, String(value));
  }
  return node;
}

function calloutEntryHeight(entry) {
  if (entry.members) {
    return CALLOUT_LAYOUT.clusterHead + entry.activeMembers.length * CALLOUT_LAYOUT.clusterRow;
  }
  return CALLOUT_LAYOUT.rowHeight;
}

function layoutRail(entries) {
  const { railTop, railBottom } = CALLOUT_LAYOUT;
  entries.sort((left, right) => left.anchor.y - right.anchor.y);
  const heights = entries.map(calloutEntryHeight);
  const total = heights.reduce((sum, height) => sum + height, 0);
  const gap = entries.length > 1
    ? Math.max(8, (railBottom - railTop - total) / (entries.length - 1))
    : 0;

  let top = entries.length > 1 ? railTop : (railTop + railBottom - total) / 2;
  entries.forEach((entry, index) => {
    entry.top = top;
    top += heights[index] + gap;
  });
}

function drawLeader(anchor, side, attachY) {
  const rail = CALLOUT_LAYOUT[side];
  return svgEl("polyline", {
    class: "callout-line",
    points: `${anchor.x},${anchor.y} ${rail.turnX},${attachY} ${rail.labelX},${attachY}`,
  });
}

function buildCalloutNode(entry) {
  const rail = CALLOUT_LAYOUT[entry.side];
  const textAnchor = entry.side === "left" ? "end" : "start";
  const group = svgEl("g", { class: "callout" });

  if (entry.members) {
    const headY = entry.top + 12;
    group.append(drawLeader(entry.anchor, entry.side, headY - 4));
    group.append(svgEl("circle", { class: "callout-dot", cx: entry.anchor.x, cy: entry.anchor.y, r: 3 }));

    const token = svgEl("text", { class: "callout-token", x: rail.labelX, y: headY, "text-anchor": textAnchor });
    token.textContent = entry.token;
    group.append(token);

    entry.activeMembers.forEach((member, index) => {
      const rowY = headY + CALLOUT_LAYOUT.clusterHead - 6 + index * CALLOUT_LAYOUT.clusterRow;
      const row = svgEl("g", {
        class: "callout-dir",
        "data-control": member.control,
        tabindex: interactiveDiagram.matches ? 0 : -1,
        role: "button",
        "aria-label": `${controlLabel(member.control)}: ${member.record.summary}`,
      });
      row.classList.toggle("is-selected", member.control === state.selectedControl);

      const text = svgEl("text", { x: rail.labelX, y: rowY, "text-anchor": textAnchor });
      const glyph = svgEl("tspan", { class: "dir-glyph" });
      glyph.textContent = `${member.glyph} `;
      const label = svgEl("tspan", { class: "dir-action" });
      label.textContent = calloutLabel(member.record);
      text.append(glyph, label);
      row.append(text);
      group.append(row);
    });
    return group;
  }

  const record = state.records.get(entry.id);
  const tokenY = entry.top + 11;
  const actionY = entry.top + 27;
  group.dataset.control = entry.id;
  group.setAttribute("tabindex", interactiveDiagram.matches ? "0" : "-1");
  group.setAttribute("role", "button");
  group.setAttribute("aria-label", `${controlLabel(entry.id)}: ${record ? record.summary : "unmapped"}`);
  group.classList.toggle("is-selected", entry.id === state.selectedControl);

  group.append(drawLeader(entry.anchor, entry.side, actionY - 5));
  group.append(svgEl("circle", { class: "callout-dot", cx: entry.anchor.x, cy: entry.anchor.y, r: 3 }));

  const token = svgEl("text", { class: "callout-token", x: rail.labelX, y: tokenY, "text-anchor": textAnchor });
  token.textContent = entry.token;
  group.append(token);

  const action = svgEl("text", { class: "callout-action", x: rail.labelX, y: actionY, "text-anchor": textAnchor });
  action.textContent = calloutLabel(record);
  group.append(action);

  return group;
}

function renderCallouts() {
  if (!elements.calloutLayer) {
    return;
  }

  const left = [];
  const right = [];

  for (const definition of CALLOUTS) {
    const entry = { ...definition };
    if (entry.members) {
      entry.activeMembers = entry.members
        .map((member) => ({ ...member, record: state.records.get(member.control) }))
        .filter((member) => member.record);
      if (!entry.activeMembers.length) {
        continue;
      }
    } else if (!state.records.has(entry.id)) {
      continue;
    }
    (entry.side === "left" ? left : right).push(entry);
  }

  layoutRail(left);
  layoutRail(right);

  const fragment = document.createDocumentFragment();
  for (const entry of [...left, ...right]) {
    fragment.append(buildCalloutNode(entry));
  }
  elements.calloutLayer.replaceChildren(fragment);
}

function renderMappingList() {
  const fragment = document.createDocumentFragment();
  const records = sortedRecords();

  if (!records.length) {
    const empty = document.createElement("p");
    empty.className = "empty-state";
    empty.textContent = "This profile has no enabled mappings.";
    fragment.append(empty);
  }

  for (const record of records) {
    const row = document.createElement("button");
    row.className = "mapping-row";
    row.type = "button";
    row.dataset.control = record.control;
    row.classList.toggle("is-selected", record.control === state.selectedControl);
    row.setAttribute("aria-pressed", String(record.control === state.selectedControl));

    const control = document.createElement("span");
    control.className = "mapping-control";
    control.textContent = controlLabel(record.control);

    const copy = document.createElement("span");
    copy.className = "mapping-copy";

    const action = document.createElement("span");
    action.className = "mapping-action";
    action.classList.toggle(
      "is-technical",
      ["holdKeystroke", "keystroke", "modifierChord", "text"].includes(record.action.type),
    );
    action.textContent = record.summary;

    const description = document.createElement("span");
    description.className = "mapping-description";
    description.textContent = record.description;

    const arrow = document.createElement("span");
    arrow.className = "mapping-arrow";
    arrow.setAttribute("aria-hidden", "true");
    arrow.textContent = "›";

    copy.append(action, description);
    row.append(control, copy, arrow);
    fragment.append(row);
  }

  elements.mappingList.replaceChildren(fragment);
}

function fact(label, value, { code = false } = {}) {
  const row = elements.factTemplate.content.firstElementChild.cloneNode(true);
  row.querySelector("dt").textContent = label;
  const definition = row.querySelector("dd");
  if (code) {
    const codeElement = document.createElement("code");
    codeElement.textContent = value;
    definition.append(codeElement);
  } else {
    definition.textContent = value;
  }
  return row;
}

function executionFact(action) {
  switch (action.type) {
    case "applescript":
      return ["Native target", nativeMenuTarget(action.script) || "AppleScript command", false];
    case "ghosttyAction":
      return ["Native target", action.ghosttyAction, true];
    case "keystroke":
    case "modifierChord":
    case "holdKeystroke":
      return ["Shortcut", formatShortcut(action), true];
    case "shell":
      return ["Command", action.command || "Local helper", true];
    case "text":
      return ["Text", action.text || "", true];
    case "mouseClick":
      return ["Button", action.mouseButton || "left", true];
    case "analogScroll":
      return ["Axis", "Vertical stick axis", false];
    case "analogPointer":
      return ["Axis", "Right stick X + Y", false];
    default:
      return null;
  }
}

function triggerLabel(record) {
  if (record.action.type === "holdKeystroke") {
    return "While held";
  }
  if (record.analog?.kind?.includes("Scroll") || record.action.type === "analogPointer") {
    return "Continuous past deadzone";
  }
  return record.mapping.edgeTrigger === false ? "Repeats while held" : "Once per press or tilt";
}

function renderDetail() {
  const record = state.records.get(state.selectedControl);
  if (!record) {
    elements.detailControl.textContent = "Control";
    elements.detailTitle.textContent = "Choose a mapped control";
    elements.detailDescription.textContent = "Its configured behavior and execution path will appear here.";
    elements.detailFacts.replaceChildren();
    elements.detailSource.textContent = "config/mappings.json";
    return;
  }

  elements.detailControl.textContent = controlLabel(record.control);
  elements.detailTitle.textContent = record.summary;
  elements.detailDescription.textContent = record.description;

  const facts = document.createDocumentFragment();
  facts.append(fact("Action", actionTypeLabel(record.action.type), { code: true }));

  const execution = executionFact(record.action);
  if (execution) {
    facts.append(fact(execution[0], execution[1], { code: execution[2] }));
  }

  facts.append(fact("Trigger", triggerLabel(record)));

  if (record.mapping.debounceMs != null) {
    facts.append(fact("Debounce", `${record.mapping.debounceMs} ms`, { code: true }));
  }
  if (record.mapping.repeatIntervalMs != null) {
    facts.append(fact("Repeat interval", `${record.mapping.repeatIntervalMs} ms`, { code: true }));
  }
  if (record.analog?.deadzone != null) {
    facts.append(fact("Deadzone", String(record.analog.deadzone), { code: true }));
  }

  const scope = record.source === "alwaysOn"
    ? "All applications"
    : `${profileLabel(record.source)} profile`;
  facts.append(fact("Scope", scope));

  elements.detailFacts.replaceChildren(facts);
  elements.detailSource.textContent = `config/mappings.json · ${record.configPath}`;
}

function selectControl(control) {
  if (!state.records.has(control)) {
    return;
  }
  state.selectedControl = control;
  renderController();
  renderMappingList();
  renderDetail();
}

function initialProfile() {
  const queryProfile = new URL(window.location.href).searchParams.get("profile");
  if (queryProfile && profileNames().includes(queryProfile)) {
    return queryProfile;
  }

  try {
    const savedProfile = localStorage.getItem("controller-guide-profile");
    if (savedProfile && profileNames().includes(savedProfile)) {
      return savedProfile;
    }
  } catch {
    // Storage can be unavailable in locked-down browser sessions.
  }

  return profileNames().includes("codexApp") ? "codexApp" : profileNames()[0];
}

function setLoading() {
  elements.configState.className = "config-state is-loading";
  elements.configState.querySelector("strong").textContent = "Loading mappings";
  elements.refreshButton.disabled = true;
}

function setLoaded() {
  const now = new Date();
  elements.configState.className = "config-state";
  elements.configState.querySelector("strong").textContent = "Live configuration";
  elements.loadedAt.textContent = `Loaded ${now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" })}`;
  elements.refreshButton.disabled = false;
}

function showError(error) {
  elements.configState.className = "config-state is-error";
  elements.configState.querySelector("strong").textContent = "Configuration unavailable";
  elements.mappingList.replaceChildren();
  const message = document.createElement("p");
  message.className = "empty-state";
  message.textContent = error instanceof Error ? error.message : String(error);
  elements.mappingList.append(message);
  elements.detailControl.textContent = "Loading error";
  elements.detailTitle.textContent = "Could not read mappings";
  elements.detailDescription.textContent = "Keep the local guide server running and verify config/mappings.json is valid JSON.";
  elements.detailFacts.replaceChildren();
  elements.refreshButton.disabled = false;
}

async function loadMappings() {
  setLoading();
  try {
    const response = await fetch("/api/mappings", { cache: "no-store" });
    if (!response.ok) {
      const payload = await response.json().catch(() => ({}));
      throw new Error(payload.detail || payload.error || `Mapping request failed (${response.status})`);
    }

    state.config = await response.json();
    if (!state.config.profiles || !state.config.safety) {
      throw new Error("Mapping JSON is missing required top-level fields.");
    }

    renderTabs();
    setSelectedProfile(state.profileName || initialProfile(), { remember: false });
    setLoaded();
  } catch (error) {
    showError(error);
  }
}

elements.profileTabs.addEventListener("click", (event) => {
  const tab = event.target.closest("[role=tab]");
  if (tab) {
    setSelectedProfile(tab.dataset.profile);
  }
});

elements.profileTabs.addEventListener("keydown", (event) => {
  if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) {
    return;
  }

  const tabs = [...elements.profileTabs.querySelectorAll("[role=tab]")];
  const currentIndex = tabs.indexOf(document.activeElement);
  if (currentIndex === -1) {
    return;
  }

  event.preventDefault();
  let nextIndex = currentIndex;
  if (event.key === "ArrowLeft") nextIndex = (currentIndex - 1 + tabs.length) % tabs.length;
  if (event.key === "ArrowRight") nextIndex = (currentIndex + 1) % tabs.length;
  if (event.key === "Home") nextIndex = 0;
  if (event.key === "End") nextIndex = tabs.length - 1;
  tabs[nextIndex].focus();
  setSelectedProfile(tabs[nextIndex].dataset.profile);
});

elements.controllerMap.addEventListener("click", (event) => {
  const control = event.target.closest("[data-control]")?.dataset.control;
  if (control) {
    selectControl(control);
  }
});

elements.controllerMap.addEventListener("keydown", (event) => {
  if (!["Enter", " "].includes(event.key)) {
    return;
  }
  const control = event.target.closest("[data-control]")?.dataset.control;
  if (control && state.records.has(control)) {
    event.preventDefault();
    selectControl(control);
  }
});

elements.mappingList.addEventListener("click", (event) => {
  const control = event.target.closest("[data-control]")?.dataset.control;
  if (control) {
    selectControl(control);
  }
});

elements.refreshButton.addEventListener("click", loadMappings);
interactiveDiagram.addEventListener("change", renderController);

loadMappings();
