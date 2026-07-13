"use strict";

const queryProfile = new URL(window.location.href).searchParams.get("profile");
let savedProfile = null;

try {
  savedProfile = localStorage.getItem("controller-guide-profile");
} catch {
  // Storage can be unavailable in locked-down browser sessions.
}

document.documentElement.dataset.activeProfile = queryProfile || savedProfile || "codexApp";
