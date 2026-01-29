// Enhanced Linux stub for claude-native module
// Key difference from existing solutions: Uses Electron APIs instead of no-ops
const { BrowserWindow, Notification, app } = require('electron');
const os = require('os');

class ClaudeNativeLinux {
  constructor() {
    this._mainWindow = null;
  }

  // Called by main process to register window
  setMainWindow(win) {
    this._mainWindow = win;
  }

  // OS version detection
  getWindowsVersion() {
    // Compatibility stub for code that checks Windows version
    return "10.0.0";
  }

  getOSVersion() {
    return os.release();
  }

  getPlatform() {
    return 'linux';
  }

  // Window effects - compositor handles these on Linux
  setWindowEffect(effect) {
    // macOS has vibrancy effects, Linux compositors handle this
    return true;
  }

  removeWindowEffect() {
    return true;
  }

  // CRITICAL: Window state - use Electron API, not hardcoded values
  getIsMaximized() {
    if (!this._mainWindow) return false;
    return this._mainWindow.isMaximized();
  }

  isFullScreen() {
    if (!this._mainWindow) return false;
    return this._mainWindow.isFullScreen();
  }

  isMinimized() {
    if (!this._mainWindow) return false;
    return this._mainWindow.isMinimized();
  }

  isVisible() {
    if (!this._mainWindow) return true;
    return this._mainWindow.isVisible();
  }

  // Window management
  maximize() {
    if (this._mainWindow) this._mainWindow.maximize();
  }

  minimize() {
    if (this._mainWindow) this._mainWindow.minimize();
  }

  restore() {
    if (this._mainWindow) this._mainWindow.restore();
  }

  focus() {
    if (this._mainWindow) this._mainWindow.focus();
  }

  show() {
    if (this._mainWindow) this._mainWindow.show();
  }

  hide() {
    if (this._mainWindow) this._mainWindow.hide();
  }

  close() {
    if (this._mainWindow) this._mainWindow.close();
  }

  // Notifications - delegate to Electron
  showNotification(options) {
    if (Notification.isSupported()) {
      const notification = new Notification(options);
      notification.show();
      return notification;
    }
    return null;
  }

  // Taskbar/dock integration
  flashFrame(flag) {
    if (this._mainWindow) {
      this._mainWindow.flashFrame(flag !== false);
    }
  }

  clearFlashFrame() {
    if (this._mainWindow) {
      this._mainWindow.flashFrame(false);
    }
  }

  setProgressBar(progress) {
    if (this._mainWindow) {
      // Clamp between 0 and 1
      const normalized = Math.max(0, Math.min(1, progress));
      this._mainWindow.setProgressBar(normalized);
    }
  }

  clearProgressBar() {
    if (this._mainWindow) {
      this._mainWindow.setProgressBar(-1);
    }
  }

  // Badge/overlay icon - limited support on Linux
  setOverlayIcon(icon, description) {
    // Not well supported on Linux, but try anyway
    if (this._mainWindow && this._mainWindow.setOverlayIcon) {
      this._mainWindow.setOverlayIcon(icon, description);
      return true;
    }
    return false;
  }

  clearOverlayIcon() {
    if (this._mainWindow && this._mainWindow.setOverlayIcon) {
      this._mainWindow.setOverlayIcon(null, '');
      return true;
    }
    return false;
  }

  setBadgeCount(count) {
    if (app && app.setBadgeCount) {
      app.setBadgeCount(count);
      return true;
    }
    return false;
  }

  getBadgeCount() {
    if (app && app.getBadgeCount) {
      return app.getBadgeCount();
    }
    return 0;
  }

  // System integration
  setAppUserModelId(id) {
    if (app && app.setAppUserModelId) {
      app.setAppUserModelId(id);
    }
  }

  // Keyboard constants - preserve from original if app uses them
  get KeyboardKey() {
    return {
      // Common key codes - add more if needed
      VK_RETURN: 13,
      VK_ESCAPE: 27,
      VK_SPACE: 32,
      VK_LEFT: 37,
      VK_UP: 38,
      VK_RIGHT: 39,
      VK_DOWN: 40,
      VK_DELETE: 46,
    };
  }

  // Accessibility features
  isAccessibilityEnabled() {
    // Linux doesn't have the same accessibility query API
    return true;
  }

  // Power management
  getPowerState() {
    return {
      onBattery: false,
      charging: false,
      percent: 100
    };
  }

  // Screen capture/recording detection
  isScreenCaptureAllowed() {
    return true;
  }

  // Microphone/camera access
  isMicrophoneAccessAllowed() {
    return true;
  }

  isCameraAccessAllowed() {
    return true;
  }

  // File system operations - delegate to Node.js fs module
  // (if the app uses these, they should work fine with standard fs)

  // System theme detection
  getSystemTheme() {
    const nativeTheme = require('electron').nativeTheme;
    return nativeTheme.shouldUseDarkColors ? 'dark' : 'light';
  }

  onSystemThemeChanged(callback) {
    const nativeTheme = require('electron').nativeTheme;
    nativeTheme.on('updated', () => {
      callback(nativeTheme.shouldUseDarkColors ? 'dark' : 'light');
    });
  }
}

// Export singleton instance
module.exports = new ClaudeNativeLinux();
