(function () {
  "use strict";

  // ---- OS detection -------------------------------------------------------
  function detectOS() {
    var ua = navigator.userAgent || "";
    var plat = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || "";
    var s = (plat + " " + ua).toLowerCase();
    if (/android|iphone|ipad|ipod/.test(s)) return null; // phones cannot run the game
    if (/win/.test(s)) return "windows";
    if (/mac/.test(s)) return "macos";
    if (/linux|x11|cros/.test(s)) return "linux";
    return null;
  }
  var NAMES = { linux: "Linux", windows: "Windows", macos: "macOS" };
  var os = detectOS();
  var hero = document.getElementById("hero-os");
  if (os) {
    document.querySelectorAll('[data-os="' + os + '"]').forEach(function (el) {
      el.classList.add("match");
      if (el.tagName === "DETAILS") el.open = true;
    });
    document.querySelectorAll("details[data-os]").forEach(function (el) {
      if (el.dataset.os !== os) el.open = false;
    });
    var primary = document.querySelector('.os[data-os="' + os + '"] a.btn');
    var heroBtn = document.getElementById("hero-dl");
    if (primary && heroBtn) {
      heroBtn.href = primary.href;
      heroBtn.textContent = "Download for " + NAMES[os];
    }
    if (hero) hero.textContent = "Detected: " + NAMES[os];
    var grid = document.getElementById("dl-grid");
    var card = grid && grid.querySelector('.os[data-os="' + os + '"]');
    if (card) grid.insertBefore(card, grid.firstChild);
    if (os === "windows") selectTab("t-ps");
  } else if (hero) {
    hero.textContent = "Desktop only";
  }

  // ---- Install tabs -------------------------------------------------------
  var tabs = Array.prototype.slice.call(document.querySelectorAll('[role="tab"]'));
  function selectTab(id) {
    tabs.forEach(function (t) {
      var on = t.id === id;
      t.setAttribute("aria-selected", on ? "true" : "false");
      t.tabIndex = on ? 0 : -1;
      document.getElementById(t.getAttribute("aria-controls")).hidden = !on;
    });
  }
  tabs.forEach(function (t, i) {
    t.addEventListener("click", function () { selectTab(t.id); });
    t.addEventListener("keydown", function (e) {
      if (e.key !== "ArrowRight" && e.key !== "ArrowLeft") return;
      var n = tabs[(i + (e.key === "ArrowRight" ? 1 : tabs.length - 1)) % tabs.length];
      selectTab(n.id); n.focus();
    });
  });

  // ---- Copy buttons -------------------------------------------------------
  document.querySelectorAll(".copy").forEach(function (b) {
    b.addEventListener("click", function () {
      var text = b.parentNode.querySelector("code").textContent;
      function done(ok) {
        b.textContent = ok ? "Copied" : "Press Ctrl+C";
        setTimeout(function () { b.textContent = "Copy"; }, 1800);
      }
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text).then(function () { done(true); }, function () { done(false); });
      } else {
        var r = document.createRange(); r.selectNodeContents(b.parentNode.querySelector("code"));
        var sel = window.getSelection(); sel.removeAllRanges(); sel.addRange(r);
        done(false);
      }
    });
  });

  // ---- Lightbox -----------------------------------------------------------
  var lb = document.getElementById("lb"), lbImg = document.getElementById("lb-img"), lbCap = document.getElementById("lb-cap");
  var items = [], idx = 0, opener = null;
  function show(i) {
    idx = (i + items.length) % items.length;
    var a = items[idx];
    lbImg.src = a.href;
    lbImg.alt = a.querySelector("img").alt;
    lbCap.textContent = a.dataset.cap || "";
  }
  function open(list, i, from) {
    items = list; opener = from; show(i);
    lb.hidden = false; document.body.style.overflow = "hidden";
    lb.querySelector(".lb-close").focus();
  }
  function close() {
    lb.hidden = true; document.body.style.overflow = "";
    if (opener) opener.focus();
  }
  ["gallery-grid", "print-grid"].forEach(function (id) {
    var grid = document.getElementById(id);
    if (!grid) return;
    var list = Array.prototype.slice.call(grid.querySelectorAll("a"));
    list.forEach(function (a, i) {
      a.addEventListener("click", function (e) { e.preventDefault(); open(list, i, a); });
    });
  });
  lb.querySelector(".lb-close").addEventListener("click", close);
  lb.querySelector(".lb-prev").addEventListener("click", function () { show(idx - 1); });
  lb.querySelector(".lb-next").addEventListener("click", function () { show(idx + 1); });
  lb.addEventListener("click", function (e) { if (e.target === lb) close(); });
  document.addEventListener("keydown", function (e) {
    if (lb.hidden) return;
    if (e.key === "Escape") close();
    else if (e.key === "ArrowLeft") show(idx - 1);
    else if (e.key === "ArrowRight") show(idx + 1);
    else if (e.key === "Tab") { // keep focus inside the dialog
      var f = lb.querySelectorAll("button"), first = f[0], last = f[f.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    }
  });
})();
