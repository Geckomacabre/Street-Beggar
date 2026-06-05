'use strict';

// ============================================================
// Pickpocket minigame — space key captured while NUI has focus
// ============================================================

const ppGame = document.getElementById('pp-game');
const ppGrid = document.getElementById('pp-grid');

let ppSlots     = [];
let ppSpeed     = 1800;
let ppActive    = false;
let ppStartTime = null;
let ppAnimFrame = null;
let ppCurSlot   = 0;

function ppBuildGrid(slots) {
    ppGrid.innerHTML = '';
    slots.forEach(function(slot) {
        const el = document.createElement('div');
        el.className = 'pp-slot' + (slot.empty ? ' pp-empty' : ' pp-filled');

        if (!slot.empty) {
            const icon  = document.createElement('div');
            icon.className   = 'pp-slot-icon';
            icon.textContent = slot.icon || '?';
            const label = document.createElement('div');
            label.className   = 'pp-slot-label';
            label.textContent = slot.label || '';
            el.appendChild(icon);
            el.appendChild(label);
        } else {
            const icon = document.createElement('div');
            icon.className   = 'pp-slot-icon';
            icon.textContent = '';
            el.appendChild(icon);
        }

        ppGrid.appendChild(el);
    });
}

function ppTick(timestamp) {
    if (!ppActive) return;
    if (ppStartTime === null) ppStartTime = timestamp;

    const elapsed  = timestamp - ppStartTime;
    const numSlots = ppSlots.length;
    const period   = ppSpeed * 2;
    const phase    = (elapsed % period) / ppSpeed;

    const pos = phase <= 1
        ? phase * (numSlots - 1)
        : (2 - phase) * (numSlots - 1);

    ppCurSlot = Math.round(pos);

    const slotEls = ppGrid.querySelectorAll('.pp-slot');
    slotEls.forEach(function(el, i) {
        el.classList.toggle('pp-active', i === ppCurSlot);
    });

    ppAnimFrame = requestAnimationFrame(ppTick);
}

function ppResolve() {
    if (!ppActive) return;
    ppActive = false;
    cancelAnimationFrame(ppAnimFrame);

    const slot     = ppSlots[ppCurSlot];
    const slotEls  = ppGrid.querySelectorAll('.pp-slot');
    const activeEl = slotEls[ppCurSlot];
    const success  = slot && !slot.empty;

    if (activeEl) {
        activeEl.classList.remove('pp-active');
        activeEl.classList.add(success ? 'pp-success' : 'pp-fail');
    }

    fetch('https://um_beg/pickpocketResult', {
        method : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body   : JSON.stringify({ slot: slot, slotIndex: ppCurSlot }),
    }).catch(() => {});

    setTimeout(function() {
        if (ppGame) ppGame.classList.add('hidden');
    }, 850);
}

// Direct space-bar capture — NUI has keyboard focus during minigame
window.addEventListener('keydown', function(e) {
    if (e.code === 'Space' && ppActive) {
        e.preventDefault();
        ppResolve();
    }
});

// ============================================================
// Message handler
// ============================================================

window.addEventListener('message', function(event) {
    const data = event.data;
    if (!data || !data.action) return;

    switch (data.action) {

        case 'startPickpocket':
            ppSlots     = data.slots  || [];
            ppSpeed     = data.speed  || 1800;
            ppActive    = true;
            ppStartTime = null;
            ppCurSlot   = 0;
            ppBuildGrid(ppSlots);
            if (ppGame) ppGame.classList.remove('hidden');
            cancelAnimationFrame(ppAnimFrame);
            ppAnimFrame = requestAnimationFrame(ppTick);
            break;

        case 'resolvePickpocket':
            ppResolve();
            break;

        case 'hidePickpocket':
            ppActive = false;
            cancelAnimationFrame(ppAnimFrame);
            if (ppGame) ppGame.classList.add('hidden');
            break;
    }
});
