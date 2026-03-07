// ===================================================================
// Insta360 Bridge — WebView App Logic
// ===================================================================

// ===== STATE =====
let currentPage = 'welcome';
let isRecording = false;
let isCameraConnected = false;
let previousStatus = 'DISCONNECTED';
let startPoint = null;
let stopPoint = null;
let layoutImageObj = null;
let canvasCtx = null;
let recTimerInterval = null;
let recSeconds = 0;
let currentTargetSsid = '';
let testMode = false;

// ===== DOM REFERENCES =====
const menuToggle = document.getElementById('menuToggle');
const sideMenu = document.getElementById('sideMenu');
const menuOverlay = document.getElementById('menuOverlay');

// ===== NAVIGATION =====
function navigateTo(page) {
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    const target = document.getElementById('page-' + page);
    if (target) {
        target.classList.add('active');
        currentPage = page;
    }
    closeMenu();

    // Auto-load gallery when navigating to it
    if (page === 'gallery') {
        loadGallery();
    }
}

function toggleMenu() {
    const isOpen = sideMenu.classList.contains('open');
    if (isOpen) {
        closeMenu();
    } else {
        sideMenu.classList.add('open');
        menuOverlay.classList.add('show');
        menuToggle.classList.add('open');
    }
}

function closeMenu() {
    sideMenu.classList.remove('open');
    menuOverlay.classList.remove('show');
    menuToggle.classList.remove('open');
}

// ===== LOGGING =====
function log(msg, containerId) {
    const container = document.getElementById(containerId || 'logContainer');
    if (!container) return;
    const div = document.createElement('div');
    div.innerText = '[' + new Date().toLocaleTimeString() + '] ' + msg;
    container.prepend(div);
    if (container.children.length > 8) container.lastChild.remove();
}

function layoutLog(msg) {
    log(msg, 'layoutLogContainer');
}

// ===== TEST MODE =====
function toggleTestMode() {
    testMode = !testMode;
    document.getElementById('testModeLabel').innerText = 'Test Mode: ' + (testMode ? 'ON ✅' : 'OFF');
    if (typeof AndroidBridge !== 'undefined') {
        AndroidBridge.setDemoMode(testMode);
    }
    showToast(testMode ? 'Test Mode ON — camera simulated' : 'Test Mode OFF — using real camera');
    closeMenu();
}

// ===== TOAST =====
function showToast(msg) {
    const container = document.getElementById('toastContainer');
    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.innerText = msg;
    container.appendChild(toast);
    setTimeout(() => {
        if (toast.parentNode) toast.parentNode.removeChild(toast);
    }, 3000);
}

// ===== STATUS UPDATES (called by Android every 1 second) =====
window.updateStatus = function (status) {
    // In test mode, don't let polling override our simulated state
    if (!testMode) {
        isCameraConnected = (status !== 'DISCONNECTED');
        isRecording = (status === 'RECORDING');
    }

    // Update status dots everywhere
    updateStatusDot('welcomeStatusDot', 'welcomeStatusText', status);
    updateStatusDot('cameraStatusDot', 'cameraStatusText', status);
    updateStatusDot('menuStatusDot', 'menuStatusText', status);
    updateLayoutStatus(status);

    previousStatus = status;
};

function updateStatusDot(dotId, textId, status) {
    const dot = document.getElementById(dotId);
    const text = document.getElementById(textId);
    if (!dot || !text) return;

    dot.className = 'status-dot';
    if (status === 'DISCONNECTED') {
        dot.classList.add('disconnected');
        text.innerText = 'Disconnected';
    } else if (status === 'IDLE') {
        dot.classList.add('connected');
        text.innerText = 'Camera Ready';
    } else if (status === 'RECORDING') {
        dot.classList.add('recording');
        text.innerText = 'Recording...';
    }
}

function updateLayoutStatus(status) {
    const dot = document.getElementById('layoutStatusDot');
    const text = document.getElementById('layoutStatusText');
    if (!dot || !text) return;

    dot.className = 'status-dot-sm';
    if (status === 'DISCONNECTED') {
        dot.classList.add('disconnected');
        text.innerText = 'Offline';
    } else if (status === 'IDLE') {
        dot.classList.add('connected');
        text.innerText = 'Ready';
    } else if (status === 'RECORDING') {
        dot.classList.add('connected');
        text.innerText = 'Recording';
    }
}

// ===== CAMERA CONNECTION CALLBACKS (called by Android) =====
window.onCameraConnected = function () {
    showToast('Camera connected! ✅');
    log('Camera connected successfully.');
    layoutLog('Camera connected.');

    // Auto-navigate to layout page if on camera page
    if (currentPage === 'camera') {
        setTimeout(function () {
            navigateTo('layout');
        }, 1000);
    }
};

window.onCameraDisconnected = function () {
    showToast('Camera disconnected ⚠️');
    log('Camera disconnected.');
    layoutLog('Camera disconnected.');
};

// ===== WIFI SCANNING =====
function scanForCameras() {
    log('Scanning for cameras...');
    const wifiList = document.getElementById('wifiList');
    wifiList.innerHTML = '<div style="padding:14px; text-align:center; color:#64748b;">Scanning...</div>';
    wifiList.style.display = 'block';

    if (typeof AndroidBridge !== 'undefined') {
        AndroidBridge.scanWifi();
    } else {
        log('Error: AndroidBridge not available');
    }
}

// Called by Android with WiFi scan results
window.onWifiList = function (networks) {
    log('Found ' + networks.length + ' networks.');
    const wifiList = document.getElementById('wifiList');
    wifiList.innerHTML = '';

    if (networks.length === 0) {
        wifiList.innerHTML = '<div style="padding:14px; text-align:center; color:#64748b;">No networks found. Try again.</div>';
        return;
    }

    networks.forEach(function (net) {
        const item = document.createElement('div');
        item.className = 'wifi-item';
        item.innerHTML = '<span>' + net.ssid + '</span><span style="opacity:0.5">' + net.level + 'dBm</span>';
        item.onclick = function () {
            currentTargetSsid = net.ssid;
            document.getElementById('modalSsid').innerText = 'Connect to: ' + net.ssid;
            document.getElementById('modalPassword').value = '88888888';
            document.getElementById('passwordModal').style.display = 'flex';
        };
        wifiList.appendChild(item);
    });
};

// ===== WIFI CONNECTION MODAL =====
function handleModalConnect() {
    const pwd = document.getElementById('modalPassword').value;
    if (pwd) {
        log('Connecting to ' + currentTargetSsid + '...');
        closeModal();

        if (typeof AndroidBridge !== 'undefined') {
            AndroidBridge.connectWifi(currentTargetSsid, pwd);
        }

        // Show progress
        const wifiList = document.getElementById('wifiList');
        wifiList.innerHTML = '<div style="padding:14px; text-align:center; color:#64748b;">Connecting to WiFi... Please wait ~10s</div>';

        showToast('Connecting to ' + currentTargetSsid + '...');
    }
}

function closeModal() {
    document.getElementById('passwordModal').style.display = 'none';
}

// ===== LAYOUT UPLOAD =====
function handleFileUpload(event) {
    const file = event.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = function (e) {
        layoutImageObj = new Image();
        layoutImageObj.onload = function () {
            showCanvas();
            drawLayout();
            layoutLog('Layout uploaded: ' + file.name);
            showToast('Layout loaded! Tap to set start point.');
        };
        layoutImageObj.src = e.target.result;
    };
    reader.readAsDataURL(file);
}

function showCanvas() {
    document.getElementById('uploadZone').style.display = 'none';
    document.getElementById('canvasWrapper').style.display = 'block';
    document.getElementById('recordingControls').style.display = 'flex';
}

function changeLayout() {
    // Reset and show upload zone again
    resetPoints();
    layoutImageObj = null;
    document.getElementById('uploadZone').style.display = 'flex';
    document.getElementById('canvasWrapper').style.display = 'none';
    document.getElementById('recordingControls').style.display = 'none';
    document.getElementById('fileInput').value = '';
    layoutLog('Layout cleared. Upload a new one.');
}

// ===== CANVAS DRAWING =====
function drawLayout() {
    const canvas = document.getElementById('layoutCanvas');
    const wrapper = document.getElementById('canvasWrapper');

    // Set canvas size to match wrapper width and image aspect ratio
    const wrapperWidth = wrapper.clientWidth - 24; // minus padding
    const aspectRatio = layoutImageObj.height / layoutImageObj.width;
    canvas.width = wrapperWidth;
    canvas.height = wrapperWidth * aspectRatio;

    canvasCtx = canvas.getContext('2d');
    canvasCtx.drawImage(layoutImageObj, 0, 0, canvas.width, canvas.height);

    // Redraw markers
    if (startPoint) drawMarker(startPoint.x, startPoint.y, '#22c55e', 'S');
    if (stopPoint) drawMarker(stopPoint.x, stopPoint.y, '#ef4444', 'E');
}

function drawMarker(relX, relY, color, label) {
    const canvas = document.getElementById('layoutCanvas');
    const ctx = canvas.getContext('2d');
    const x = relX * canvas.width;
    const y = relY * canvas.height;
    const r = 14;

    // Outer glow
    ctx.beginPath();
    ctx.arc(x, y, r + 4, 0, Math.PI * 2);
    ctx.fillStyle = color + '40'; // alpha
    ctx.fill();

    // Main circle
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fillStyle = color;
    ctx.fill();
    ctx.strokeStyle = 'white';
    ctx.lineWidth = 2;
    ctx.stroke();

    // Label
    ctx.fillStyle = 'white';
    ctx.font = 'bold 12px Inter, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(label, x, y);
}

// Canvas touch/click handler — handles point selection on layout
function handleCanvasTap(clientX, clientY) {
    if (!layoutImageObj) return;

    const canvas = document.getElementById('layoutCanvas');
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width;
    const scaleY = canvas.height / rect.height;
    const x = (clientX - rect.left) * scaleX;
    const y = (clientY - rect.top) * scaleY;

    // Relative coordinates (0.0 to 1.0)
    const relX = x / canvas.width;
    const relY = y / canvas.height;

    if (!isRecording) {
        // Before recording: tap sets/moves start point
        startPoint = { x: relX, y: relY };
        stopPoint = null; // clear stop point if re-setting start
        document.getElementById('stopLegend').style.display = 'none';
        drawLayout(); // Redraw with marker
        document.getElementById('startLegend').style.display = 'flex';
        document.getElementById('startRecordBtn').disabled = false;
        document.getElementById('instructionBar').innerHTML =
            'Start point set ✅ — Tap to move, or press <strong>START RECORDING</strong>';
        layoutLog('Start point set at (' + relX.toFixed(2) + ', ' + relY.toFixed(2) + ')');
    } else if (isRecording) {
        // During recording: tap sets/moves stop point
        stopPoint = { x: relX, y: relY };
        drawLayout(); // Redraw with both markers
        document.getElementById('stopLegend').style.display = 'flex';
        document.getElementById('stopRecordBtn').disabled = false;
        document.getElementById('instructionBar').innerHTML =
            'Stop point set ✅ — Tap to move, or press <strong>STOP RECORDING</strong>';
        layoutLog('Stop point set at (' + relX.toFixed(2) + ', ' + relY.toFixed(2) + ')');
    }
}

// Touch event for mobile — prevent Android from treating taps as scrolls
var layoutCanvas = document.getElementById('layoutCanvas');

layoutCanvas.addEventListener('touchstart', function (e) {
    e.preventDefault(); // CRITICAL: stops Android from interpreting as scroll/fling
}, { passive: false });

layoutCanvas.addEventListener('touchend', function (e) {
    e.preventDefault();
    if (e.changedTouches && e.changedTouches.length > 0) {
        var touch = e.changedTouches[0];
        handleCanvasTap(touch.clientX, touch.clientY);
    }
}, { passive: false });

// Mouse click fallback (for desktop testing)
layoutCanvas.addEventListener('click', function (e) {
    handleCanvasTap(e.clientX, e.clientY);
});

// ===== RECORDING FLOW =====
function handleStartRecording() {
    // In test mode, skip camera check
    if (!testMode && !isCameraConnected) {
        showToast('Camera not connected! Redirecting...');
        layoutLog('Camera not connected. Navigate to Connect Camera.');
        setTimeout(function () {
            navigateTo('camera');
        }, 1500);
        return;
    }

    if (!startPoint) {
        showToast('Please set a start point first');
        return;
    }

    layoutLog('Sending start recording command...');

    if (typeof AndroidBridge !== 'undefined') {
        if (testMode) {
            AndroidBridge.testStartRecording();
        } else {
            AndroidBridge.startRecording();
        }
    } else {
        layoutLog('Error: AndroidBridge not available');
    }
}

function handleStopRecording() {
    if (!isRecording) {
        showToast('Not currently recording');
        return;
    }

    layoutLog('Sending stop recording command...');

    if (typeof AndroidBridge !== 'undefined') {
        if (testMode) {
            AndroidBridge.testStopRecording();
        } else {
            AndroidBridge.stopRecording();
        }
    } else {
        layoutLog('Error: AndroidBridge not available');
    }
}

// ===== RECORDING CALLBACKS (called by Android) =====
window.onRecordingStarted = function () {
    isRecording = true;
    layoutLog('Recording STARTED ✅');
    showToast('Recording started! 🔴');

    // Update UI
    document.getElementById('startRecordBtn').style.display = 'none';
    document.getElementById('stopRecordBtn').style.display = 'block';
    document.getElementById('stopRecordBtn').disabled = true; // Enabled when stop point set
    document.getElementById('recStatus').style.display = 'flex';
    document.getElementById('instructionBar').innerHTML =
        'Recording... Tap map to set <strong>stop point</strong>';

    // Start timer
    recSeconds = 0;
    recTimerInterval = setInterval(function () {
        recSeconds++;
        var m = Math.floor(recSeconds / 60);
        var s = recSeconds % 60;
        document.getElementById('recTimer').innerText =
            (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
    }, 1000);
};

window.onRecordingFailed = function (reason) {
    layoutLog('Recording FAILED: ' + reason);

    if (reason && reason.toLowerCase().includes('not connected')) {
        showToast('Camera not connected!');
        setTimeout(function () {
            navigateTo('camera');
        }, 1500);
    } else {
        showToast('Recording failed: ' + reason);
    }
};

window.onRecordingStopped = function () {
    isRecording = false;
    layoutLog('Recording STOPPED ✅');
    showToast('Recording saved! ✅');

    // Stop timer
    if (recTimerInterval) {
        clearInterval(recTimerInterval);
        recTimerInterval = null;
    }

    // Save metadata
    var currentRecId = saveRecordingData();

    // Reset UI for next recording
    document.getElementById('recStatus').style.display = 'none';
    document.getElementById('stopRecordBtn').style.display = 'none';
    document.getElementById('startRecordBtn').style.display = 'block';
    document.getElementById('startRecordBtn').disabled = true;
    document.getElementById('instructionBar').innerHTML =
        'Recording saved! Tap map to set new <strong>start point</strong>';

    // Clear points for next recording
    startPoint = null;
    stopPoint = null;
    document.getElementById('startLegend').style.display = 'none';
    document.getElementById('stopLegend').style.display = 'none';

    // Redraw layout without markers
    if (layoutImageObj) drawLayout();

    // Auto-trigger export at both resolutions
    if (currentRecId && typeof AndroidBridge !== 'undefined' && !testMode) {
        layoutLog('Starting export (8K + 1080P)...');
        showToast('Exporting video... ⏳');
        AndroidBridge.exportRecording(currentRecId);
    }
};

window.onRecordingStopFailed = function (reason) {
    layoutLog('Stop recording FAILED: ' + reason);
    showToast('Stop failed: ' + reason);
};

// ===== SAVE RECORDING METADATA =====
function saveRecordingData() {
    var recId = 'rec_' + Date.now();
    var metadata = {
        id: recId,
        timestamp: new Date().toISOString(),
        duration: recSeconds,
        startPoint: startPoint,
        stopPoint: stopPoint,
        layoutName: 'layout'
    };

    layoutLog('Saving recording: ' + metadata.id);

    if (typeof AndroidBridge !== 'undefined') {
        AndroidBridge.saveRecordingMetadata(JSON.stringify(metadata));
    }

    return recId;
}

window.onMetadataSaved = function () {
    layoutLog('Metadata saved locally ✅');
};

window.onMetadataSaveFailed = function (reason) {
    layoutLog('Metadata save failed: ' + reason);
};

// ===== EXPORT CALLBACKS (called by Android) =====
window.onExportProgress = function (pct, resolution) {
    layoutLog('Export [' + resolution + ']: ' + pct + '%');
};

window.onExportSuccess = function (path, resolution) {
    layoutLog('Export [' + resolution + '] complete ✅');
    showToast(resolution + ' export done! ✅');
};

window.onExportFailed = function (error, resolution) {
    layoutLog('Export [' + resolution + '] failed: ' + error);
    showToast('Export failed: ' + error);
};

// ===== GALLERY EXPORT BUTTON =====
function exportFromGallery(recordingId) {
    if (typeof AndroidBridge !== 'undefined') {
        showToast('Starting export...');
        AndroidBridge.exportRecording(recordingId);
    } else {
        showToast('Export not available');
    }
}

// ===== RESET POINTS =====
function resetPoints() {
    startPoint = null;
    stopPoint = null;
    document.getElementById('startLegend').style.display = 'none';
    document.getElementById('stopLegend').style.display = 'none';
    document.getElementById('startRecordBtn').disabled = true;
    document.getElementById('instructionBar').innerHTML =
        'Tap on the map to set a <strong>start point</strong>';

    if (layoutImageObj) drawLayout();
    layoutLog('Points reset.');
}

// ===== GALLERY / SAVED VIDEOS =====
function loadGallery() {
    var recordings = [];

    if (typeof AndroidBridge !== 'undefined') {
        try {
            var rawData = AndroidBridge.getRecordings();
            recordings = JSON.parse(rawData || '[]');
        } catch (e) {
            console.error('Error loading recordings:', e);
            recordings = [];
        }
    }

    var listEl = document.getElementById('galleryList');
    var emptyEl = document.getElementById('galleryEmpty');
    var countEl = document.getElementById('galleryCount');

    if (!listEl || !emptyEl || !countEl) return;

    countEl.innerText = recordings.length + ' recording' + (recordings.length !== 1 ? 's' : '');

    if (recordings.length === 0) {
        emptyEl.style.display = 'flex';
        listEl.style.display = 'none';
        return;
    }

    emptyEl.style.display = 'none';
    listEl.style.display = 'flex';
    listEl.innerHTML = '';

    // Sort newest first
    recordings.sort(function (a, b) {
        return new Date(b.timestamp || 0) - new Date(a.timestamp || 0);
    });

    recordings.forEach(function (rec) {
        var card = document.createElement('div');
        card.className = 'gallery-card';

        // Format date
        var dateStr = '';
        if (rec.timestamp) {
            var d = new Date(rec.timestamp);
            dateStr = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) +
                ' · ' + d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
        }

        // Format duration
        var durStr = '00:00';
        if (rec.duration && rec.duration > 0) {
            var m = Math.floor(rec.duration / 60);
            var s = rec.duration % 60;
            durStr = (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
        }

        // Format points
        var startStr = rec.startPoint
            ? '(' + rec.startPoint.x.toFixed(2) + ', ' + rec.startPoint.y.toFixed(2) + ')'
            : 'N/A';
        var stopStr = rec.stopPoint
            ? '(' + rec.stopPoint.x.toFixed(2) + ', ' + rec.stopPoint.y.toFixed(2) + ')'
            : 'N/A';

        card.innerHTML =
            '<div class="gallery-card-header">' +
            '<span class="gallery-card-id">' + (rec.id || 'Unknown') + '</span>' +
            '<span class="gallery-card-date">' + dateStr + '</span>' +
            '</div>' +
            '<div class="gallery-card-info">' +
            '<span class="gallery-chip"><span class="chip-icon">🎥</span> 8K / 30fps</span>' +
            '<span class="gallery-chip"><span class="chip-icon">📁</span> MP4</span>' +
            '<span class="gallery-chip"><span class="chip-icon">⚡</span> FlowState</span>' +
            '</div>' +
            '<div class="gallery-card-points">' +
            '<div class="gallery-point">' +
            '<span class="point-marker start"></span> Start: ' + startStr +
            '</div>' +
            '<div class="gallery-point">' +
            '<span class="point-marker stop"></span> Stop: ' + stopStr +
            '</div>' +
            '</div>' +
            '<div class="gallery-card-footer">' +
            '<div class="gallery-card-duration">' +
            '<span class="dur-icon">⏺</span> ' + durStr +
            '</div>' +
            '<button class="btn-refresh" onclick="exportFromGallery(\'' + (rec.id || '') + '\')">📤 Export</button>' +
            '</div>';

        listEl.appendChild(card);
    });
}

// ===== TIMER DISPLAY =====
function formatTime(secs) {
    var m = Math.floor(secs / 60);
    var s = secs % 60;
    return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
}

// ===== INIT =====
log('UI Ready.');
layoutLog('Ready. Upload a layout to begin.');

if (typeof AndroidBridge !== 'undefined') {
    // Check initial status
    var status = AndroidBridge.getStatus();
    if (status) window.updateStatus(status);
}

// Global exposure
window.updateStatus = window.updateStatus;
window.onWifiList = window.onWifiList;
window.onCameraConnected = window.onCameraConnected;
window.onCameraDisconnected = window.onCameraDisconnected;
window.onRecordingStarted = window.onRecordingStarted;
window.onRecordingFailed = window.onRecordingFailed;
window.onRecordingStopped = window.onRecordingStopped;
window.onRecordingStopFailed = window.onRecordingStopFailed;
window.onMetadataSaved = window.onMetadataSaved;
window.onMetadataSaveFailed = window.onMetadataSaveFailed;
window.onExportProgress = window.onExportProgress;
window.onExportSuccess = window.onExportSuccess;
window.onExportFailed = window.onExportFailed;
