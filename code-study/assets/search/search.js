/* Local, dependency-free reader. Source and raw HTML are always text, never executable markup. */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const data = window.CODE_STUDY_DATA || {entries: [], baseline: '索引未加载'};
  const entries = data.entries || [], byPath = new Map(entries.map(e => [e.path, e]));
  const lessons = entries.filter(e => e.kind === '阶段' && !e.path.endsWith('/README.md'));
  const positions = new Map(); let current = '', limit = 50;
  $('baseline').textContent = data.baseline || '基线未填写';
  const node = (tag, text, cls) => {const n = document.createElement(tag); if (text !== undefined) n.textContent = text; if (cls) n.className = cls; return n;};
  const route = (path, line = '', anchor = '') => '#p=' + encodeURIComponent(path) + (line ? '&line=' + encodeURIComponent(line) : '') + (anchor ? '&anchor=' + encodeURIComponent(anchor) : '');
  function target(raw, from) {
    raw = raw.trim();
    if (/^https?:\/\//i.test(raw)) return {external: raw};
    if (/^[a-z][a-z0-9+.-]*:/i.test(raw) || raw.startsWith('//') || raw.startsWith('/') || raw.includes('\\')) return null;
    const pos = raw.indexOf('#'), hash = pos < 0 ? '' : raw.slice(pos + 1);
    let path, decodedHash;
    try {path = decodeURIComponent(pos < 0 ? raw : raw.slice(0, pos)); decodedHash = decodeURIComponent(hash);} catch (_) {return null;}
    const parts = path ? from.split('/').slice(0, -1) : from.split('/');
    if (path) for (const part of path.split('/')) {
      if (part === '..') {if (!parts.length) return null; parts.pop();}
      else if (part && part !== '.') parts.push(part);
    }
    return {path: parts.join('/'), hash: decodedHash};
  }
  function openImage(img) {
    $('zoom-image').src = img.src; $('zoom-image').alt = img.alt;
    $('image-caption').textContent = img.alt; $('image-dialog').showModal();
  }
  function inline(parent, text, from) {
    // Whitelisted Markdown tokens only. Unrecognized HTML remains literal text.
    const re = /!\[([^\]]*)\]\(([^\s)]+)\)|\[([^\]]+)\]\(([^\s)]+)\)|`([^`]+)`|\*\*([^*]+)\*\*/g;
    let m, last = 0;
    while ((m = re.exec(text))) {
      parent.append(document.createTextNode(text.slice(last, m.index)));
      if (m[1] !== undefined) {
        const t = target(m[2], from);
        if (t && t.path && /\.(svg|png|jpe?g|webp)$/i.test(t.path)) {
          const img = node('img', undefined, 'diagram'); img.alt = m[1]; img.src = t.path.split('/').map(encodeURIComponent).join('/');
          img.loading = 'lazy'; img.tabIndex = 0; img.addEventListener('keydown', e => {if (e.key === 'Enter' || e.key === ' ') {e.preventDefault(); openImage(img);}}); img.addEventListener('click', () => openImage(img)); parent.append(img);
        } else parent.append(document.createTextNode(m[0]));
      } else if (m[3] !== undefined) {
        const t = target(m[4], from), a = node('a', m[3]);
        if (t && t.external) {a.href = t.external; a.target = '_blank'; a.rel = 'noopener noreferrer';}
        else if (t && byPath.has(t.path)) {a.href = /^L\d+(?:-L?\d+)?$/.test(t.hash) ? route(t.path, t.hash.slice(1)) : route(t.path, '', t.hash);}
        else if (t && t.path) {a.href = t.path.split('/').map(encodeURIComponent).join('/') + (t.hash ? '#' + encodeURIComponent(t.hash) : ''); a.title = '在本地查看原文件';}
        else {parent.append(document.createTextNode(m[3])); last = re.lastIndex; continue;}
        parent.append(a);
      } else if (m[5] !== undefined) parent.append(node('code', m[5]));
      else parent.append(node('strong', m[6]));
      last = re.lastIndex;
    }
    parent.append(document.createTextNode(text.slice(last)));
  }
  function cells(text) {
    text = text.trim().replace(/^\|/, '').replace(/\|$/, '');
    let out = [], part = '', code = false, escaped = false;
    for (const ch of text) {
      if (escaped) {part += ch; escaped = false; continue;}
      if (ch === '\\') {escaped = true; continue;}
      if (ch === '`') code = !code;
      if (ch === '|' && !code) {out.push(part.trim()); part = '';} else part += ch;
    }
    out.push(part.trim()); return out;
  }
  function renderMarkdown(entry) {
    const root = node('div'), stack = [root], headings = [], used = new Map();
    const lines = entry.text.replace(/\r\n?/g, '\n').split('\n');
    let i = 0, paragraph = [];
    const host = () => stack[stack.length - 1];
    const flush = () => {if (paragraph.length) {const p = node('p'); inline(p, paragraph.join('\n'), entry.path); host().append(p); paragraph = [];}};
    while (i < lines.length) {
      const line = lines[i], trimmed = line.trim(); let m;
      if ((m = /^\s*(`{3,}|~{3,})(.*)$/.exec(line))) {
        flush(); const mark = m[1], code = []; i++;
        while (i < lines.length && !lines[i].trim().startsWith(mark)) code.push(lines[i++]);
        const pre = node('pre'); pre.append(node('code', code.join('\n'))); host().append(pre); i++; continue;
      }
      if ((m = /^(#{1,6})\s+(.+)$/.exec(line))) {
        flush(); const h = node('h' + m[1].length); inline(h, m[2], entry.path);
        let slug = m[2].replace(/[`*_]/g, '').trim().toLowerCase().replace(/\s+/g, '-');
        const count = used.get(slug) || 0; used.set(slug, count + 1); if (count) slug += '-' + count;
        h.id = slug; host().append(h); headings.push([slug, m[2], m[1].length]); i++; continue;
      }
      if (/^<details(?:\s+open)?>$/.test(trimmed)) {
        flush(); const d = node('details'); d.open = / open/.test(trimmed); host().append(d); stack.push(d); i++; continue;
      }
      if ((m = /^<summary>(.*?)<\/summary>$/.exec(trimmed))) {
        flush(); const s = node('summary'); inline(s, m[1], entry.path); host().append(s); i++; continue;
      }
      if ((m = /^<details><summary>(.*?)<\/summary>$/.exec(trimmed))) {
        flush(); const d = node('details'), s = node('summary'); inline(s, m[1], entry.path); d.append(s); host().append(d); stack.push(d); i++; continue;
      }
      if (trimmed === '</details>') {flush(); if (stack.length > 1) stack.pop(); i++; continue;}
      if (line.includes('|') && i + 1 < lines.length && /^\s*\|?\s*:?-{3,}/.test(lines[i + 1]) && cells(lines[i + 1]).every(x => /^:?-{3,}:?$/.test(x))) {
        flush(); const wrap = node('div', undefined, 'table-wrap'), table = node('table'), head = node('tr');
        for (const cell of cells(line)) {const th = node('th'); inline(th, cell, entry.path); head.append(th);}
        const thead = node('thead'); thead.append(head); table.append(thead); const body = node('tbody'); i += 2;
        while (i < lines.length && lines[i].trim() && lines[i].includes('|')) {
          const row = node('tr'); for (const cell of cells(lines[i++])) {const td = node('td'); inline(td, cell, entry.path); row.append(td);} body.append(row);
        }
        table.append(body); wrap.append(table); host().append(wrap); continue;
      }
      if ((m = /^\s*(?:[-*+]\s+|\d+\.\s+)(.*)$/.exec(line))) {
        flush(); const ordered = /^\s*\d+\./.test(line), list = node(ordered ? 'ol' : 'ul');
        while (i < lines.length && (m = (ordered ? /^\s*\d+\.\s+(.*)$/ : /^\s*[-*+]\s+(.*)$/).exec(lines[i]))) {
          const li = node('li'); inline(li, m[1], entry.path); list.append(li); i++;
        }
        host().append(list); continue;
      }
      if (/^>/.test(line)) {
        flush(); const q = node('blockquote');
        while (i < lines.length && /^>/.test(lines[i])) {const p = node('p'); inline(p, lines[i++].replace(/^>\s?/, ''), entry.path); q.append(p);}
        host().append(q); continue;
      }
      if (/^\s*(?:---+|\*\*\*+)\s*$/.test(line)) {flush(); host().append(node('hr')); i++; continue;}
      if (!trimmed) flush(); else paragraph.push(line);
      i++;
    }
    flush(); return {root, headings};
  }
  function renderCurrent() {
    if (current) positions.set(current, window.scrollY);
    const q = new URLSearchParams(location.hash.slice(1));
    let path = q.get('p') || (byPath.has('learning/README.md') ? 'learning/README.md' : 'README.md');
    const entry = byPath.get(path); current = location.hash || route(path); $('content').replaceChildren(); $('toc').replaceChildren();
    $('path').textContent = path;
    if (!entry) {$('content').append(node('p', '未找到本页。请重建索引或从左侧选择现有正文。', 'missing')); return;}
    document.title = entry.title + ' · 源码学习书';
    if (entry.kind === '源码') {
      $('content').append(node('h1', entry.title)); const ol = node('ol', undefined, 'source-lines');
      const match = /^(\d+)(?:-L?(\d+))?$/.exec(q.get('line') || '');
      const first = match ? Number(match[1]) : 0, last = match ? Number(match[2] || match[1]) : 0;
      entry.text.replace(/\r\n?/g, '\n').split('\n').forEach((line, i) => {const li = node('li'); li.id = 'L' + (i + 1); li.append(node('code', line || ' ')); if (i + 1 >= first && i + 1 <= last) li.classList.add('selected'); ol.append(li);});
      $('content').append(ol); $('toc-box').hidden = true;
    } else {
      const rendered = renderMarkdown(entry); $('content').append(rendered.root); $('toc-box').hidden = false;
      for (const [id, title, depth] of rendered.headings) {const a = node('a', title); a.href = route(path, '', id); a.style.paddingLeft = Math.max(0, depth - 1) * 12 + 'px'; $('toc').append(a);}
    }
    const index = lessons.findIndex(e => e.path === path);
    for (const [id, step] of [['previous', -1], ['next', 1]]) {const e = index >= 0 ? lessons[index + step] : null; $(id).hidden = !e; if (e) $(id).href = route(e.path);}
    requestAnimationFrame(() => {
      const anchor = q.get('line') ? 'L' + q.get('line').split('-')[0] : q.get('anchor');
      const el = anchor ? document.getElementById(anchor) : null;
      if (el) el.scrollIntoView({block: 'center'}); else window.scrollTo(0, positions.get(current) || 0);
    });
  }
  function search() {
    const term = $('query').value.trim().toLocaleLowerCase(), kind = $('kind').value;
    const result = entries.filter(e => (!kind || e.kind === kind) && (!term || (e.title + '\n' + e.path + '\n' + e.text).toLocaleLowerCase().includes(term)));
    $('status').textContent = result.length + '条结果' + (result.length > limit ? '，显示前' + limit + '条' : '');
    $('results').replaceChildren(); $('more').hidden = result.length <= limit;
    for (const e of result.slice(0, limit)) {const b = node('button', undefined, 'result'); b.dataset.path = e.path; b.append(node('strong', e.title), node('span', e.kind + ' · ' + e.path)); b.addEventListener('click', () => {location.hash = route(e.path);}); $('results').append(b);}
  }
  $('query').addEventListener('input', () => {limit = 50; search();}); $('kind').addEventListener('change', () => {limit = 50; search();});
  $('more').addEventListener('click', () => {limit += 50; search();}); $('back').addEventListener('click', () => history.back());
  $('close-image').addEventListener('click', () => $('image-dialog').close());
  $('image-dialog').addEventListener('click', e => {if (e.target === $('image-dialog')) $('image-dialog').close();});
  window.addEventListener('hashchange', renderCurrent); search(); renderCurrent();
})();
