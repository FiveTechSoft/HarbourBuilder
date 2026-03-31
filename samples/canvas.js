const TB = 28;
const cv = document.getElementById("c");
const ctx = cv.getContext("2d");

cv.width = FORM.w;
cv.height = FORM.h + TB;
cv.style.boxShadow = "4px 4px 16px rgba(0,0,0,.5)";

let openCombo = null;

function draw() {
  ctx.clearRect(0, 0, cv.width, cv.height);
  ctx.fillStyle = "#f0f0f0";
  ctx.fillRect(0, 0, cv.width, cv.height);

  // Title bar
  let g = ctx.createLinearGradient(0, 0, cv.width, 0);
  g.addColorStop(0, "#1b5ea4");
  g.addColorStop(1, "#2978d4");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, cv.width, TB);
  ctx.fillStyle = "#fff";
  ctx.font = "12px Segoe UI";
  ctx.textBaseline = "middle";
  ctx.fillText(FORM.title, 10, TB / 2);

  // Border
  ctx.strokeStyle = "#666";
  ctx.strokeRect(0.5, 0.5, cv.width - 1, cv.height - 1);
  ctx.font = "12px Segoe UI";

  // Controls
  for (let c of FORM.controls) {
    let x = c.x, y = c.y + TB, w = c.w, h = c.h, t = c.text;

    // GroupBox
    if (c.t == 6) {
      ctx.strokeStyle = "#bbb"; ctx.lineWidth = 1; ctx.beginPath();
      let tw = ctx.measureText(t).width + 8;
      ctx.moveTo(x + 8, y); ctx.lineTo(x, y); ctx.lineTo(x, y + h);
      ctx.lineTo(x + w, y + h); ctx.lineTo(x + w, y); ctx.lineTo(x + 12 + tw, y);
      ctx.stroke();
      ctx.fillStyle = "#333"; ctx.fillText(t, x + 12, y);
    }

    // Label
    if (c.t == 1) {
      ctx.fillStyle = "#000"; ctx.fillText(t, x, y + h / 2);
    }

    // Edit
    if (c.t == 2) {
      ctx.fillStyle = "#fff"; ctx.fillRect(x, y, w, h);
      ctx.strokeStyle = "#aaa"; ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
      ctx.fillStyle = "#000"; ctx.fillText(t, x + 4, y + h / 2);
    }

    // Button
    if (c.t == 3) {
      let bg = ctx.createLinearGradient(0, y, 0, y + h);
      bg.addColorStop(0, c._hover ? "#e8f0fe" : "#f8f8f8");
      bg.addColorStop(1, c._hover ? "#d0d8e8" : "#e0e0e0");
      ctx.fillStyle = bg; ctx.fillRect(x, y, w, h);
      ctx.strokeStyle = c._hover ? "#0078d4" : "#aaa";
      ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
      ctx.fillStyle = "#000"; ctx.textAlign = "center";
      ctx.fillText(t, x + w / 2, y + h / 2);
      ctx.textAlign = "left";
    }

    // CheckBox
    if (c.t == 4) {
      ctx.strokeStyle = "#888"; ctx.strokeRect(x + 0.5, y + 0.5, 13, 13);
      ctx.fillStyle = "#fff"; ctx.fillRect(x + 1, y + 1, 12, 12);
      if (c.checked) {
        ctx.fillStyle = "#0078d4"; ctx.font = "bold 12px Segoe UI";
        ctx.textBaseline = "alphabetic"; ctx.fillText("\u2713", x + 1, y + 12);
        ctx.textBaseline = "middle"; ctx.font = "12px Segoe UI";
      }
      ctx.fillStyle = "#000"; ctx.fillText(t, x + 20, y + h / 2);
    }

    // ComboBox
    if (c.t == 5) {
      let sel = c.sel || 0;
      let txt = (c.items && c.items[sel]) || "";
      ctx.fillStyle = "#fff"; ctx.fillRect(x, y, w, 24);
      ctx.strokeStyle = "#aaa"; ctx.strokeRect(x + 0.5, y + 0.5, w - 1, 23);
      ctx.fillStyle = "#f0f0f0"; ctx.fillRect(x + w - 20, y + 1, 19, 22);
      ctx.fillStyle = "#666"; ctx.font = "10px Segoe UI";
      ctx.fillText("\u25BC", x + w - 16, y + 15);
      ctx.fillStyle = "#000"; ctx.font = "12px Segoe UI";
      ctx.fillText(txt, x + 4, y + 13);
    }
  }

  // Dropdown overlay
  if (openCombo) {
    let c = openCombo, x = c.x, y = c.y + TB + 24, w = c.w, items = c.items || [];
    let dh = items.length * 22 + 2;
    ctx.shadowColor = "rgba(0,0,0,0.2)"; ctx.shadowBlur = 6; ctx.shadowOffsetY = 2;
    ctx.fillStyle = "#fff";
    ctx.fillRect(x, y, w, dh);
    ctx.shadowColor = "transparent"; ctx.shadowBlur = 0; ctx.shadowOffsetY = 0;
    ctx.strokeStyle = "#888";
    ctx.strokeRect(x + 0.5, y + 0.5, w - 1, dh - 1);
    ctx.font = "12px Segoe UI"; ctx.textBaseline = "middle";
    for (let i = 0; i < items.length; i++) {
      if (i == c.sel) {
        ctx.fillStyle = "#0078d4"; ctx.fillRect(x + 1, y + 1 + i * 22, w - 2, 22);
        ctx.fillStyle = "#fff";
      } else {
        ctx.fillStyle = "#000";
      }
      ctx.fillText(items[i], x + 6, y + 12 + i * 22);
    }
  }
}

draw();

// Hit test
function hit(mx, my) {
  for (let c of FORM.controls) {
    let y = c.y + TB, h = (c.t == 5) ? 24 : c.h;
    if (mx >= c.x && mx <= c.x + c.w && my >= y && my <= y + h) return c;
  }
  return null;
}

// Click
cv.addEventListener("click", function(e) {
  let r = cv.getBoundingClientRect();
  let mx = e.clientX - r.left, my = e.clientY - r.top;

  // Dropdown open - handle selection
  if (openCombo) {
    let c = openCombo, x = c.x, y = c.y + TB + 24, items = c.items || [];
    let dh = items.length * 22 + 2;
    if (mx >= x && mx <= x + c.w && my >= y && my <= y + dh) {
      c.sel = Math.floor((my - y) / 22);
    }
    openCombo = null;
    draw();
    return;
  }

  let c = hit(mx, my);
  if (!c) return;

  if (c.t == 3) { alert("Clicked: " + c.text); }
  if (c.t == 4) { c.checked = !c.checked; draw(); }
  if (c.t == 5) { openCombo = c; draw(); }
});

// Hover
cv.addEventListener("mousemove", function(e) {
  let r = cv.getBoundingClientRect();
  let mx = e.clientX - r.left, my = e.clientY - r.top;
  let h = hit(mx, my);

  // Button hover effect
  let needRedraw = false;
  for (let c of FORM.controls) {
    if (c.t == 3) {
      let over = (h === c);
      if (c._hover !== over) { c._hover = over; needRedraw = true; }
    }
  }
  if (needRedraw) draw();

  cv.style.cursor = h ? "pointer" : (my < TB ? "move" : "default");
});

// Drag by title bar
let drag = false, ox = 0, oy = 0;
cv.addEventListener("mousedown", function(e) {
  let r = cv.getBoundingClientRect();
  if (e.clientY - r.top < TB) {
    drag = true; ox = e.clientX - cv.offsetLeft; oy = e.clientY - cv.offsetTop;
  }
});
document.addEventListener("mousemove", function(e) {
  if (drag) {
    cv.style.position = "absolute";
    cv.style.left = (e.clientX - ox) + "px";
    cv.style.top = (e.clientY - oy) + "px";
  }
});
document.addEventListener("mouseup", function() { drag = false; });
