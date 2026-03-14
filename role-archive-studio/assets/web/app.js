const DEFAULT_MEMORY_FOCUS = "只记录稳定偏好、重要已确认事实和关键工作边界；不把角色卡设定、某次具体开发过程或临时测试细节写进长期记忆。";

const TEXT = {
  previewEmpty: "当前激活角色的提示词会显示在这里。",
  noRoleSlots: "还没有现有角色，可以先去创建。",
  unnamedRole: "未命名角色",
  noPersonality: "未设置性格",
  noActiveRole: "尚未激活角色",
  chooseRoleFirst: "保存后可以激活这个角色。",
  selectRoleToViewMemory: "先选择一个角色，再查看或保存记忆。",
  noMemoryForRole: "这个角色还没有记忆存档。",
  pinned: "已置顶",
  savedAt: "存档写入时间：",
  eventAt: "事件时间：",
  unknownTime: "未知时间",
  dataRootMissing: "未找到",
  roleNameRequired: "请先填写角色名称。",
  roleSaved: "角色已保存。",
  selectRoleFirst: "请先选择角色。",
  roleActivated: "角色已激活。",
  nothingToDelete: "没有可删除的角色。",
  deleteRoleConfirmPrefix: "确定删除角色“",
  deleteRoleConfirmSuffix: "”吗？",
  roleDeleted: "角色已删除。",
  creatingRole: "正在新建角色。",
  editingRole: "正在编辑角色。",
  promptCopied: "提示词已复制。",
  selectRoleBeforeMemory: "保存记忆前请先选择角色。",
  memoryTextRequired: "请先填写记忆内容。",
  memorySaved: "记忆已保存。",
  settingsSaved: "记忆策略已保存。",
  editing: "编辑中...",
  loadFailed: "加载失败。",
  rememberThese: "Remember these details:",
  collaborationRules: "Collaboration rules:",
  memoryFocus: "Memory focus:",
  none: "- none",
  activeRole: "Active role:",
  roleTitle: "Role title:",
  roleSummary: "Role summary:",
  personality: "Personality:",
  voiceStyle: "Voice style:",
  notes: "Notes:",
  notSet: "Not set",
  currentRoleLabel: "当前角色：",
  noCurrentRole: "当前未激活",
  summaryFallback: "暂无功能简介",
  firstMemoryPrompt: "这是该角色首次保存记忆。请先确认这个角色以后更应该记住什么；默认只保留长期稳定信息，不把角色卡设定和一次性过程写进长期记忆。",
  memoryFocusCancelled: "已取消本次记忆保存。",
  memoryFocusConfirmed: "这个角色的记忆重点已确认。"
};

const state = {
  profiles: [],
  memories: [],
  settings: {
    memoryMode: "manual",
    sessionSummaryLimit: 3,
    defaultMemoryFocus: DEFAULT_MEMORY_FOCUS,
    memoryFilterSummary: DEFAULT_MEMORY_FOCUS
  },
  activeProfileId: "",
  selectedId: "",
  activePrompt: "",
  dataRoot: "",
  currentView: "entry"
};

const els = {
  entryView: document.querySelector("#entryView"),
  selectView: document.querySelector("#selectView"),
  editorView: document.querySelector("#editorView"),
  activeBadge: document.querySelector("#activeBadge"),
  editorTitle: document.querySelector("#editorTitle"),
  profileSummaryList: document.querySelector("#profileSummaryList"),
  profileSummaryTemplate: document.querySelector("#profileSummaryTemplate"),
  activeName: document.querySelector("#activeName"),
  activeSummary: document.querySelector("#activeSummary"),
  saveStatus: document.querySelector("#saveStatus"),
  promptPreview: document.querySelector("#promptPreview"),
  saveButton: document.querySelector("#saveButton"),
  deleteButton: document.querySelector("#deleteButton"),
  activateButton: document.querySelector("#activateButton"),
  copyPromptButton: document.querySelector("#copyPromptButton"),
  form: document.querySelector("#profileForm"),
  name: document.querySelector("#name"),
  title: document.querySelector("#title"),
  summary: document.querySelector("#summary"),
  personalityPreset: document.querySelector("#personalityPreset"),
  personality: document.querySelector("#personality"),
  voicePreset: document.querySelector("#voicePreset"),
  voice: document.querySelector("#voice"),
  memories: document.querySelector("#memories"),
  rules: document.querySelector("#rules"),
  notes: document.querySelector("#notes"),
  memoryFocus: document.querySelector("#memoryFocus"),
  memoryList: document.querySelector("#memoryList"),
  memoryTemplate: document.querySelector("#memoryItemTemplate"),
  memoryCount: document.querySelector("#memoryCount"),
  memoryText: document.querySelector("#memoryText"),
  memorySource: document.querySelector("#memorySource"),
  memoryPinned: document.querySelector("#memoryPinned"),
  saveMemoryButton: document.querySelector("#saveMemoryButton"),
  memoryMode: document.querySelector("#memoryMode"),
  sessionSummaryLimit: document.querySelector("#sessionSummaryLimit"),
  saveSettingsButton: document.querySelector("#saveSettingsButton"),
  settingsStatus: document.querySelector("#settingsStatus"),
  dataRoot: document.querySelector("#dataRoot"),
  goCreateButton: document.querySelector("#goCreateButton"),
  goSelectButton: document.querySelector("#goSelectButton"),
  backFromSelectButton: document.querySelector("#backFromSelectButton"),
  fromSelectCreateButton: document.querySelector("#fromSelectCreateButton"),
  backToEntryButton: document.querySelector("#backToEntryButton"),
  backToSelectButton: document.querySelector("#backToSelectButton")
};

function currentMinuteStamp() {
  const now = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`;
}

function splitLines(value) { return value.split(/\r?\n/).map((item) => item.trim()).filter(Boolean); }
function normalizeCollection(value) { if (Array.isArray(value)) return value; if (value && typeof value === "object" && Object.keys(value).length > 0) return [value]; return []; }
function normalizeStringList(value) { if (Array.isArray(value)) return value.filter(Boolean); if (typeof value === "string" && value.trim()) return [value.trim()]; return []; }
function normalizeProfile(profile) {
  if (!profile || typeof profile !== "object") return null;
  return { ...profile, memories: normalizeStringList(profile.memories), rules: normalizeStringList(profile.rules), memoryFocus: typeof profile.memoryFocus === "string" ? profile.memoryFocus : "", memoryFocusConfirmedAt: typeof profile.memoryFocusConfirmedAt === "string" ? profile.memoryFocusConfirmedAt : "" };
}
function profileById(id) { return state.profiles.find((item) => item.id === id) || null; }
function selectedProfile() { return profileById(state.selectedId); }
function activeProfile() { return profileById(state.activeProfileId); }
function memoriesForProfile(profileId) { return state.memories.filter((item) => item.profileId === profileId).sort((a, b) => (b.createdAt || "").localeCompare(a.createdAt || "")); }
async function loadProfileMemories(profileId) {
  if (!profileId) return [];
  const payload = await fetchJson(`/api/profiles/${profileId}/memories`);
  const items = normalizeCollection(payload.memories);
  state.memories = state.memories.filter((item) => item.profileId !== profileId).concat(items);
  return memoriesForProfile(profileId);
}
function setView(viewName) { state.currentView = viewName; els.entryView.classList.toggle("is-hidden", viewName !== "entry"); els.selectView.classList.toggle("is-hidden", viewName !== "select"); els.editorView.classList.toggle("is-hidden", viewName !== "editor"); }
function setStatus(text) { els.saveStatus.textContent = text; }
function setSettingsStatus(text) { els.settingsStatus.textContent = text; }
function syncPreset(selectEl, inputEl) { const value = inputEl.value.trim(); const matched = Array.from(selectEl.options).find((option) => option.value === value); selectEl.value = matched ? matched.value : ""; }

function serializeForm() {
  const current = selectedProfile();
  return { id: current?.id || "", createdAt: current?.createdAt || "", name: els.name.value.trim(), title: els.title.value.trim(), summary: els.summary.value.trim(), personality: els.personality.value.trim(), voice: els.voice.value.trim(), memories: splitLines(els.memories.value), rules: splitLines(els.rules.value), notes: els.notes.value.trim(), memoryFocus: els.memoryFocus.value.trim(), memoryFocusConfirmedAt: current?.memoryFocusConfirmedAt || "" };
}

function fillForm(profile) {
  const normalized = normalizeProfile(profile);
  els.name.value = normalized?.name || "";
  els.title.value = normalized?.title || "";
  els.summary.value = normalized?.summary || "";
  els.personality.value = normalized?.personality || "";
  els.voice.value = normalized?.voice || "";
  els.memories.value = (normalized?.memories || []).join("\n");
  els.rules.value = (normalized?.rules || []).join("\n");
  els.notes.value = normalized?.notes || "";
  els.memoryFocus.value = normalized?.memoryFocus || "";
  syncPreset(els.personalityPreset, els.personality);
  syncPreset(els.voicePreset, els.voice);
}

function buildPromptPreview(profile) {
  const normalized = normalizeProfile(profile);
  if (!normalized) return TEXT.previewEmpty;
  const memoryLines = [...(normalized.memories || []), ...memoriesForProfile(normalized.id).map((item) => item.text)].filter(Boolean);
  const uniqueMemoryLines = [...new Set(memoryLines)];
  const memoryBlock = uniqueMemoryLines.length ? uniqueMemoryLines.map((item) => `- ${item}`).join("\n") : TEXT.none;
  const rulesBlock = normalized.rules?.length ? normalized.rules.map((item) => `- ${item}`).join("\n") : TEXT.none;
  return [`${TEXT.activeRole} ${normalized.name || TEXT.unnamedRole}`, `${TEXT.roleTitle} ${normalized.title || TEXT.notSet}`, `${TEXT.roleSummary} ${normalized.summary || TEXT.notSet}`, `${TEXT.personality} ${normalized.personality || TEXT.notSet}`, `${TEXT.voiceStyle} ${normalized.voice || TEXT.notSet}`, `${TEXT.memoryFocus} ${normalized.memoryFocus || state.settings.defaultMemoryFocus || DEFAULT_MEMORY_FOCUS}`, TEXT.rememberThese, memoryBlock, TEXT.collaborationRules, rulesBlock, normalized.notes ? `${TEXT.notes} ${normalized.notes}` : ""].filter(Boolean).join("\n");
}

function renderHeader() { const active = activeProfile(); els.activeBadge.textContent = active ? `${TEXT.currentRoleLabel}${active.name}` : TEXT.noCurrentRole; }
function renderSelectList() {
  els.profileSummaryList.innerHTML = "";
  if (!state.profiles.length) { const empty = document.createElement("p"); empty.className = "subtle"; empty.textContent = TEXT.noRoleSlots; els.profileSummaryList.appendChild(empty); return; }
  const profiles = [...state.profiles].sort((a, b) => (b.updatedAt || "").localeCompare(a.updatedAt || ""));
  for (const profile of profiles) {
    const fragment = els.profileSummaryTemplate.content.cloneNode(true);
    fragment.querySelector(".summary-name").textContent = profile.name || TEXT.unnamedRole;
    fragment.querySelector(".summary-personality").textContent = profile.personality || TEXT.noPersonality;
    fragment.querySelector(".summary-copy").textContent = profile.summary || TEXT.summaryFallback;
    fragment.querySelector(".summary-card").addEventListener("click", async () => { state.selectedId = profile.id; fillForm(profile); setStatus(TEXT.editingRole); setView("editor"); render(); try { await loadProfileMemories(profile.id); } catch (error) { showError(error); } render(); });
    els.profileSummaryList.appendChild(fragment);
  }
}
function renderEditor() {
  const profile = selectedProfile();
  const draft = profile ? normalizeProfile({ ...profile, ...serializeForm() }) : normalizeProfile(serializeForm());
  const isEditingActive = !!profile && state.activeProfileId === profile.id;
  els.editorTitle.textContent = profile ? "编辑角色" : "创建新角色";
  els.activeName.textContent = profile?.name || TEXT.noActiveRole;
  els.activeSummary.textContent = profile
    ? (isEditingActive ? "当前显示的是已激活角色的提示词预览。" : "当前显示的是角色草稿预览，保存后可以激活。")
    : TEXT.chooseRoleFirst;
  els.promptPreview.textContent = isEditingActive && state.activePrompt ? state.activePrompt : buildPromptPreview(draft);
}
function renderMemoryList() {
  const profile = selectedProfile();
  const items = profile ? memoriesForProfile(profile.id) : [];
  els.memoryList.innerHTML = "";
  els.memoryCount.textContent = String(items.length);
  if (!profile) { const empty = document.createElement("p"); empty.className = "subtle"; empty.textContent = TEXT.selectRoleToViewMemory; els.memoryList.appendChild(empty); return; }
  if (!items.length) { const empty = document.createElement("p"); empty.className = "subtle"; empty.textContent = TEXT.noMemoryForRole; els.memoryList.appendChild(empty); return; }
  for (const item of items) {
    const fragment = els.memoryTemplate.content.cloneNode(true);
    fragment.querySelector(".memory-item-source").textContent = item.pinned ? `${item.source} | ${TEXT.pinned}` : item.source;
    fragment.querySelector(".memory-item-text").textContent = item.text;
    const eventText = item.eventAt ? `${TEXT.eventAt}${item.eventAt} | ` : "";
    fragment.querySelector(".memory-item-meta").textContent = `${eventText}${TEXT.savedAt}${item.createdAt || TEXT.unknownTime}`;
    fragment.querySelector(".memory-delete").addEventListener("click", async () => { await fetchJson(`/api/memories/${item.id}`, { method: "DELETE" }); state.memories = state.memories.filter((entry) => entry.id !== item.id); if (state.activeProfileId === item.profileId) state.activePrompt = buildPromptPreview(activeProfile()); render(); });
    els.memoryList.appendChild(fragment);
  }
}
function renderSettings() { els.memoryMode.value = state.settings.memoryMode || "manual"; els.sessionSummaryLimit.value = String(state.settings.sessionSummaryLimit || 3); }
function render() { renderHeader(); renderSelectList(); renderEditor(); renderMemoryList(); renderSettings(); els.dataRoot.textContent = state.dataRoot || TEXT.dataRootMissing; }
function showError(error) { const message = error instanceof Error ? error.message : String(error); setStatus(message); }
async function fetchJson(url, options) { const response = await fetch(url, { headers: { "Content-Type": "application/json" }, ...options }); if (!response.ok) { const payload = await response.json().catch(() => ({})); throw new Error(payload.error || `Request failed: ${response.status}`); } return response.json(); }
function toAsciiSafeJson(value) { return JSON.stringify(value).replace(/[^\x00-\x7F]/g, (char) => `\\u${char.charCodeAt(0).toString(16).padStart(4, "0")}`); }
function upsertProfile(profile) { const normalized = normalizeProfile(profile); const index = state.profiles.findIndex((item) => item.id === normalized.id); if (index >= 0) state.profiles[index] = normalized; else state.profiles.push(normalized); return normalized; }
async function persistProfile(payload) { return payload.id ? fetchJson(`/api/profiles/${payload.id}`, { method: "PUT", body: toAsciiSafeJson(payload) }) : fetchJson("/api/profiles", { method: "POST", body: toAsciiSafeJson(payload) }); }

async function ensureMemoryFocusForFirstEntry(profile) {
  const existingMemories = memoriesForProfile(profile.id);
  if (existingMemories.length > 0 || profile.memoryFocusConfirmedAt) return true;
  const suggested = (profile.memoryFocus || state.settings.defaultMemoryFocus || DEFAULT_MEMORY_FOCUS).trim();
  const response = window.prompt(TEXT.firstMemoryPrompt, suggested);
  if (response === null) { setStatus(TEXT.memoryFocusCancelled); return false; }
  const payload = { ...profile, memoryFocus: response.trim() || suggested, memoryFocusConfirmedAt: new Date().toISOString().slice(0, 19) };
  const saved = await persistProfile(payload);
  const normalized = upsertProfile(saved);
  state.selectedId = normalized.id;
  if (state.activeProfileId === normalized.id) state.activePrompt = buildPromptPreview(normalized);
  fillForm(normalized);
  setStatus(TEXT.memoryFocusConfirmed);
  render();
  return true;
}

async function bootstrap() {
  const payload = await fetchJson("/api/bootstrap");
  state.profiles = normalizeCollection(payload.profiles).map(normalizeProfile).filter(Boolean);
  state.memories = normalizeCollection(payload.activeMemories || payload.memories);
  state.settings = { ...state.settings, ...(payload.settings || {}) };
  state.activeProfileId = payload.state?.activeProfileId || "";
  state.activePrompt = payload.activePrompt || "";
  state.dataRoot = payload.dataRoot || "";
  if (state.activeProfileId) state.selectedId = state.activeProfileId; else if (state.profiles[0]) state.selectedId = state.profiles[0].id;
  fillForm(selectedProfile());
  render();
}

async function saveProfile() {
  const payload = serializeForm();
  if (!payload.name) { setStatus(TEXT.roleNameRequired); els.name.focus(); return; }
  const saved = await persistProfile(payload);
  const normalized = upsertProfile(saved);
  state.selectedId = normalized.id;
  if (state.activeProfileId === normalized.id) state.activePrompt = buildPromptPreview(normalized);
  setStatus(TEXT.roleSaved);
  setView("select");
  render();
}

async function activateProfile() {
  const profile = selectedProfile();
  if (!profile?.id) { setStatus(TEXT.selectRoleFirst); return; }
  const payload = await fetchJson("/api/activate", { method: "POST", body: toAsciiSafeJson({ id: profile.id }) });
  state.activeProfileId = profile.id;
  state.activePrompt = payload.prompt || buildPromptPreview(profile);
  await loadProfileMemories(profile.id);
  setStatus(TEXT.roleActivated);
  render();
}

async function deleteProfile() {
  const profile = selectedProfile();
  if (!profile?.id) { setStatus(TEXT.nothingToDelete); return; }
  if (!window.confirm(`${TEXT.deleteRoleConfirmPrefix}${profile.name || TEXT.unnamedRole}${TEXT.deleteRoleConfirmSuffix}`)) return;
  await fetchJson(`/api/profiles/${profile.id}`, { method: "DELETE" });
  state.profiles = state.profiles.filter((item) => item.id !== profile.id);
  state.memories = state.memories.filter((item) => item.profileId !== profile.id);
  if (state.activeProfileId === profile.id) { state.activeProfileId = ""; state.activePrompt = ""; }
  state.selectedId = "";
  fillForm(null);
  setStatus(TEXT.roleDeleted);
  setView("select");
  render();
}

function newProfile() { state.selectedId = ""; fillForm(null); setStatus(TEXT.creatingRole); setView("editor"); render(); }
async function copyPrompt() { const prompt = state.activePrompt || buildPromptPreview(selectedProfile()); await navigator.clipboard.writeText(prompt); setStatus(TEXT.promptCopied); }
async function saveMemory() {
  const profile = selectedProfile();
  if (!profile?.id) { setStatus(TEXT.selectRoleBeforeMemory); return; }
  const canContinue = await ensureMemoryFocusForFirstEntry(profile);
  if (!canContinue) return;
  const text = els.memoryText.value.trim();
  if (!text) { setStatus(TEXT.memoryTextRequired); els.memoryText.focus(); return; }
  const saved = await fetchJson("/api/memories", { method: "POST", body: toAsciiSafeJson({ profileId: profile.id, text, source: els.memorySource.value, pinned: els.memoryPinned.checked, eventAt: currentMinuteStamp() }) });
  state.memories.push(saved);
  els.memoryText.value = "";
  els.memoryPinned.checked = false;
  if (state.activeProfileId === profile.id) state.activePrompt = buildPromptPreview(activeProfile());
  setStatus(TEXT.memorySaved);
  render();
}
async function saveSettings() { const payload = await fetchJson("/api/settings", { method: "PUT", body: toAsciiSafeJson({ memoryMode: els.memoryMode.value, sessionSummaryLimit: Number(els.sessionSummaryLimit.value || 3) }) }); state.settings = { ...state.settings, ...payload }; setSettingsStatus(TEXT.settingsSaved); render(); }

els.goCreateButton.addEventListener("click", () => { try { newProfile(); } catch (error) { showError(error); } });
els.goSelectButton.addEventListener("click", () => { try { setView("select"); render(); } catch (error) { showError(error); } });
els.backFromSelectButton.addEventListener("click", () => { try { setView("entry"); } catch (error) { showError(error); } });
els.fromSelectCreateButton.addEventListener("click", () => { try { newProfile(); } catch (error) { showError(error); } });
els.backToEntryButton.addEventListener("click", () => { try { setView("entry"); } catch (error) { showError(error); } });
els.backToSelectButton.addEventListener("click", () => { try { setView("select"); } catch (error) { showError(error); } });
els.saveButton.addEventListener("click", async () => { try { await saveProfile(); } catch (error) { showError(error); } });
els.deleteButton.addEventListener("click", async () => { try { await deleteProfile(); } catch (error) { showError(error); } });
els.activateButton.addEventListener("click", async () => { try { await activateProfile(); } catch (error) { showError(error); } });
els.copyPromptButton.addEventListener("click", async () => { try { await copyPrompt(); } catch (error) { showError(error); } });
els.saveMemoryButton.addEventListener("click", async () => { try { await saveMemory(); } catch (error) { showError(error); } });
els.saveSettingsButton.addEventListener("click", async () => { try { await saveSettings(); } catch (error) { showError(error); } });
els.personalityPreset.addEventListener("change", () => { if (els.personalityPreset.value) { els.personality.value = els.personalityPreset.value; setStatus(TEXT.editing); render(); } });
els.voicePreset.addEventListener("change", () => { if (els.voicePreset.value) { els.voice.value = els.voicePreset.value; setStatus(TEXT.editing); render(); } });
els.personality.addEventListener("input", () => { syncPreset(els.personalityPreset, els.personality); render(); });
els.voice.addEventListener("input", () => { syncPreset(els.voicePreset, els.voice); render(); });
els.form.addEventListener("input", () => { setStatus(TEXT.editing); render(); });

bootstrap().catch((error) => { els.promptPreview.textContent = error.message; setStatus(TEXT.loadFailed); });
