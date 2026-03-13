"use strict";
/**
 * ClaudeSymlinkManager - Manages selective symlinks from ~/.ccs/.claude/ to ~/.claude/
 * v4.1.0: Selective symlinking for CCS items
 *
 * Purpose: Ship CCS items (.claude/) with package and symlink them to user's ~/.claude/
 * Architecture:
 *   - ~/.ccs/.claude/* (source, ships with CCS)
 *   - ~/.claude/* (target, gets selective symlinks)
 *   - ~/.ccs/shared/ (UNTOUCHED, existing profile mechanism)
 *
 * Symlink Chain:
 *   profile -> ~/.ccs/shared/ -> ~/.claude/ (which has symlinks to ~/.ccs/.claude/)
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ClaudeSymlinkManager = void 0;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const ui_1 = require("./ui");
const config_manager_1 = require("./config-manager");
// Make ora optional (might not be available during npm install postinstall)
let ora = null;
try {
    const oraModule = require('ora');
    ora = oraModule.default || oraModule;
}
catch {
    // ora not available, create fallback spinner that uses console.log with UI colors
    ora = function (text) {
        return {
            start: () => ({
                succeed: (msg) => console.log(msg || (0, ui_1.ok)(text)),
                fail: (msg) => console.log(msg || (0, ui_1.fail)(text)),
                warn: (msg) => console.log(msg || (0, ui_1.warn)(text)),
                info: (msg) => console.log(msg || (0, ui_1.info)(text)),
                text: '',
            }),
        };
    };
}
/**
 * ClaudeSymlinkManager - Manages selective symlinks from ~/.ccs/.claude/ to ~/.claude/
 */
class ClaudeSymlinkManager {
    constructor() {
        // Use getCcsHome() for test isolation - respects CCS_HOME env var
        this.homeDir = (0, config_manager_1.getCcsHome)();
        this.ccsClaudeDir = path.join((0, config_manager_1.getCcsDir)(), '.claude');
        this.userClaudeDir = path.join(this.homeDir, '.claude');
        // CCS items to symlink (selective, item-level)
        this.ccsItems = [
            { source: 'commands/ccs.md', target: 'commands/ccs.md', type: 'file' },
            { source: 'commands/ccs', target: 'commands/ccs', type: 'directory' },
            { source: 'skills/ccs-delegation', target: 'skills/ccs-delegation', type: 'directory' },
        ];
    }
    /**
     * Install CCS items to user's ~/.claude/ via selective symlinks
     * Safe: backs up existing files before creating symlinks
     */
    install(silent = false) {
        const spinner = silent || !ora ? null : ora('Installing CCS items to ~/.claude/').start();
        // Ensure ~/.ccs/.claude/ exists (should be shipped with package)
        if (!fs.existsSync(this.ccsClaudeDir)) {
            const msg = 'CCS .claude/ directory not found, skipping symlink installation';
            if (spinner) {
                spinner.warn((0, ui_1.warn)(msg));
            }
            else {
                console.log((0, ui_1.warn)(msg));
            }
            return;
        }
        // Create ~/.claude/ if missing
        if (!fs.existsSync(this.userClaudeDir)) {
            if (!silent) {
                if (spinner)
                    spinner.text = 'Creating ~/.claude/ directory';
            }
            fs.mkdirSync(this.userClaudeDir, { recursive: true, mode: 0o700 });
        }
        // Install each CCS item
        let installed = 0;
        for (const item of this.ccsItems) {
            if (!silent && spinner) {
                spinner.text = `Installing ${item.target}...`;
            }
            const result = this.installItem(item, silent);
            if (result)
                installed++;
        }
        const msg = `${installed}/${this.ccsItems.length} items installed to ~/.claude/`;
        if (spinner) {
            spinner.succeed((0, ui_1.ok)(msg));
        }
        else {
            console.log((0, ui_1.ok)(msg));
        }
    }
    /**
     * Install a single CCS item with conflict handling
     */
    installItem(item, silent = false) {
        const sourcePath = path.join(this.ccsClaudeDir, item.source);
        const targetPath = path.join(this.userClaudeDir, item.target);
        const targetDir = path.dirname(targetPath);
        // Ensure source exists
        if (!fs.existsSync(sourcePath)) {
            if (!silent)
                console.log((0, ui_1.warn)(`Source not found: ${item.source}, skipping`));
            return false;
        }
        // Create target parent directory if needed
        if (!fs.existsSync(targetDir)) {
            fs.mkdirSync(targetDir, { recursive: true, mode: 0o700 });
        }
        // Check if target already exists
        if (fs.existsSync(targetPath)) {
            // Check if it's already the correct symlink
            if (this.isOurSymlink(targetPath, sourcePath)) {
                return true; // Already correct, counts as success
            }
            // On Windows, check if it's a valid copy (symlink fallback from previous sync)
            // This prevents creating duplicate backups on every sync
            if (process.platform === 'win32' && this.isCopiedItem(targetPath, sourcePath, item.type)) {
                // Remove existing copy and refresh with latest source content
                try {
                    if (item.type === 'directory') {
                        fs.rmSync(targetPath, { recursive: true, force: true });
                    }
                    else {
                        fs.unlinkSync(targetPath);
                    }
                }
                catch {
                    // If removal fails, proceed to copy which will overwrite
                }
                return this.copyFallback(sourcePath, targetPath, item, silent);
            }
            // Backup existing file/directory (only for non-CCS items)
            this.backupItem(targetPath, silent);
        }
        // Create symlink
        try {
            const symlinkType = item.type === 'directory' ? 'dir' : 'file';
            fs.symlinkSync(sourcePath, targetPath, symlinkType);
            if (!silent)
                console.log((0, ui_1.ok)(`Symlinked ${item.target}`));
            return true;
        }
        catch (err) {
            // Windows fallback: copy instead of symlink when symlinks unavailable
            if (process.platform === 'win32') {
                return this.copyFallback(sourcePath, targetPath, item, silent);
            }
            else {
                const error = err;
                if (!silent)
                    console.log((0, ui_1.warn)(`Failed to symlink ${item.target}: ${error.message}`));
            }
            return false;
        }
    }
    /**
     * Windows fallback: copy files/directories when symlinks unavailable
     * Note: Changes won't auto-sync; user must run 'ccs sync' after updates
     */
    copyFallback(sourcePath, targetPath, item, silent = false) {
        try {
            if (item.type === 'directory') {
                // Copy directory recursively
                this.copyDirRecursive(sourcePath, targetPath);
            }
            else {
                // Copy single file
                fs.copyFileSync(sourcePath, targetPath);
            }
            if (!silent) {
                console.log((0, ui_1.ok)(`Copied ${item.target} (symlink unavailable)`));
                console.log((0, ui_1.info)("Run 'ccs sync' after CCS updates to refresh"));
            }
            return true;
        }
        catch (copyErr) {
            const error = copyErr;
            if (!silent) {
                console.log((0, ui_1.warn)(`Failed to copy ${item.target}: ${error.message}`));
                console.log((0, ui_1.info)('Enable Developer Mode for symlinks, or check permissions'));
            }
            return false;
        }
    }
    /**
     * Recursively copy directory (for Windows fallback)
     */
    copyDirRecursive(src, dest) {
        if (!fs.existsSync(dest)) {
            fs.mkdirSync(dest, { recursive: true });
        }
        const entries = fs.readdirSync(src, { withFileTypes: true });
        for (const entry of entries) {
            const srcPath = path.join(src, entry.name);
            const destPath = path.join(dest, entry.name);
            if (entry.isDirectory()) {
                this.copyDirRecursive(srcPath, destPath);
            }
            else {
                fs.copyFileSync(srcPath, destPath);
            }
        }
    }
    /**
     * Check if target is already the correct symlink pointing to source
     */
    isOurSymlink(targetPath, expectedSource) {
        try {
            const stats = fs.lstatSync(targetPath);
            if (!stats.isSymbolicLink()) {
                return false;
            }
            const actualTarget = fs.readlinkSync(targetPath);
            const resolvedTarget = path.resolve(path.dirname(targetPath), actualTarget);
            return resolvedTarget === expectedSource;
        }
        catch {
            return false;
        }
    }
    /**
     * Backup existing item before replacing with symlink
     */
    backupItem(itemPath, silent = false) {
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-').split('T')[0];
        const backupPath = `${itemPath}.backup-${timestamp}`;
        try {
            // If backup already exists, use counter
            let finalBackupPath = backupPath;
            let counter = 1;
            while (fs.existsSync(finalBackupPath)) {
                finalBackupPath = `${backupPath}-${counter}`;
                counter++;
            }
            fs.renameSync(itemPath, finalBackupPath);
            if (!silent)
                console.log((0, ui_1.info)(`Backed up existing item to ${path.basename(finalBackupPath)}`));
        }
        catch (err) {
            const error = err;
            if (!silent)
                console.log((0, ui_1.warn)(`Failed to backup ${itemPath}: ${error.message}`));
            throw err; // Don't proceed if backup fails
        }
    }
    /**
     * Uninstall CCS items from ~/.claude/ (remove symlinks or copied files)
     * Safe: only removes items that are CCS symlinks or valid copies
     * @returns number of items removed
     */
    uninstall() {
        let removed = 0;
        for (const item of this.ccsItems) {
            const targetPath = path.join(this.userClaudeDir, item.target);
            const sourcePath = path.join(this.ccsClaudeDir, item.source);
            // Check if it's our symlink or a valid copy (Windows fallback)
            const isSymlink = this.isOurSymlink(targetPath, sourcePath);
            const isCopy = process.platform === 'win32' && this.isCopiedItem(targetPath, sourcePath, item.type);
            if (fs.existsSync(targetPath) && (isSymlink || isCopy)) {
                try {
                    if (item.type === 'directory' && !isSymlink) {
                        // Remove copied directory recursively
                        fs.rmSync(targetPath, { recursive: true, force: true });
                    }
                    else {
                        // Remove symlink or file
                        fs.unlinkSync(targetPath);
                    }
                    console.log((0, ui_1.ok)(`Removed ${item.target}`));
                    removed++;
                }
                catch (err) {
                    const error = err;
                    console.log((0, ui_1.warn)(`Failed to remove ${item.target}: ${error.message}`));
                }
            }
        }
        if (removed > 0) {
            console.log((0, ui_1.ok)(`Removed ${removed} delegation commands and skills from ~/.claude/`));
        }
        else {
            console.log((0, ui_1.info)('No delegation commands or skills to remove'));
        }
        return removed;
    }
    /**
     * Check symlink health and report issues
     * Used by 'ccs doctor' command
     */
    checkHealth() {
        const issues = [];
        let healthy = true;
        // Check if ~/.ccs/.claude/ exists
        if (!fs.existsSync(this.ccsClaudeDir)) {
            issues.push('CCS .claude/ directory missing (reinstall CCS)');
            healthy = false;
            return { healthy, issues };
        }
        // Check each item
        for (const item of this.ccsItems) {
            const sourcePath = path.join(this.ccsClaudeDir, item.source);
            const targetPath = path.join(this.userClaudeDir, item.target);
            // Check source exists
            if (!fs.existsSync(sourcePath)) {
                issues.push(`Source missing: ${item.source}`);
                healthy = false;
                continue;
            }
            // Check target
            if (!fs.existsSync(targetPath)) {
                issues.push(`Not installed: ${item.target} (run 'ccs sync' to install)`);
                healthy = false;
            }
            else if (!this.isOurSymlink(targetPath, sourcePath)) {
                // On Windows, copied files are valid (symlink fallback)
                if (process.platform === 'win32' && this.isCopiedItem(targetPath, sourcePath, item.type)) {
                    // Copied file is valid on Windows, but note it's not a symlink
                    issues.push(`${item.target} is a copy (not symlink) - run 'ccs sync' after updates`);
                    // Still healthy, just a warning
                }
                else {
                    issues.push(`Not a CCS symlink: ${item.target} (run 'ccs sync' to fix)`);
                    healthy = false;
                }
            }
        }
        return { healthy, issues };
    }
    /**
     * Check if target is a valid copy of source (Windows fallback check)
     */
    isCopiedItem(targetPath, sourcePath, type) {
        try {
            const targetStats = fs.statSync(targetPath);
            const sourceStats = fs.statSync(sourcePath);
            if (type === 'directory') {
                // For directories, just check both exist and are directories
                return targetStats.isDirectory() && sourceStats.isDirectory();
            }
            else {
                // For files, compare size as basic validation
                return (targetStats.isFile() && sourceStats.isFile() && targetStats.size === sourceStats.size);
            }
        }
        catch {
            return false;
        }
    }
    /**
     * Sync delegation commands and skills to ~/.claude/ (used by 'ccs sync' command)
     * Same as install() but with explicit sync message
     */
    sync() {
        console.log('');
        console.log((0, ui_1.color)('Syncing CCS Components...', 'info'));
        console.log('');
        this.install(false);
    }
}
exports.ClaudeSymlinkManager = ClaudeSymlinkManager;
exports.default = ClaudeSymlinkManager;
//# sourceMappingURL=claude-symlink-manager.js.map