#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');
const readline = require('readline');

const args = process.argv.slice(2);
const packageRoot = path.resolve(__dirname, '..');
const flags = { noCache: args.includes('--no-cache') };
const positionalArgs = args.filter(arg => !arg.startsWith('--'));
const command = positionalArgs[0];

function showHelp() {
  console.log(`
🔒 AI Sandbox Wrapper

Usage:
  npx @kokorolx/ai-sandbox-wrapper <command> [options]

Commands:
  setup                 Run interactive setup (configure workspaces, select tools)
  update                Interactive menu to manage config (workspaces, git, networks)
  clean                 Interactive cleanup for caches/configs
  clean cache [type]    Clear shared package caches (npm, bun, pip, playwright-browsers)
  config show [--json]         Display current global configuration
  config tool <tool> [--show]  Display host paths and config for a specific tool

  workspace list        List all whitelisted workspaces
  workspace add <path>  Add a workspace to whitelist
  workspace remove <path>  Remove a workspace from whitelist

  git status            Show git-enabled workspaces
  git enable <path>     Enable git access for a workspace
  git disable <path>    Disable git access for a workspace
  git fetch-only <path>  Enable fetch-only git access (no push) for a workspace
  git full <path>        Enable full git access for a workspace (moves from fetch-only if needed)

  network list          List configured networks
  network add <name> [--global|--workspace <path>]  Add a network
  network remove <name> [--global|--workspace <path>]  Remove a network

  help                  Show this help message

Options:
  --no-cache    Build Docker images without using cache (fresh build)
  --json        Output in JSON format (for config show)
  --global      Apply to global scope (for network commands)
  --workspace   Apply to specific workspace (for network commands)

Examples:
  npx @kokorolx/ai-sandbox-wrapper setup
  npx @kokorolx/ai-sandbox-wrapper update
  npx @kokorolx/ai-sandbox-wrapper config show --json
  npx @kokorolx/ai-sandbox-wrapper config tool claude
  npx @kokorolx/ai-sandbox-wrapper config tool opencode --show
  npx @kokorolx/ai-sandbox-wrapper workspace add ~/projects/myapp
  npx @kokorolx/ai-sandbox-wrapper git enable ~/projects/myrepo
  npx @kokorolx/ai-sandbox-wrapper network add mynetwork --global

Documentation: https://github.com/kokorolx/ai-sandbox-wrapper
`);
}

function runSetup() {
  const setupScript = path.join(packageRoot, 'setup.sh');

  if (!fs.existsSync(setupScript)) {
    console.error('❌ Error: setup.sh not found at', setupScript);
    console.error('This may indicate a corrupted installation.');
    process.exit(1);
  }

  try {
    fs.chmodSync(setupScript, '755');
  } catch (err) {
    /* Windows doesn't support chmod */
  }

  const setupEnv = {
    ...process.env,
    AI_SANDBOX_ROOT: packageRoot
  };
  if (flags.noCache) {
    setupEnv.DOCKER_NO_CACHE = '1';
  }

  const child = spawn('bash', [setupScript], {
    cwd: packageRoot,
    stdio: 'inherit',
    env: setupEnv
  });

  child.on('error', (err) => {
    if (err.code === 'ENOENT') {
      console.error('❌ Error: bash not found. Please install bash to run setup.');
      console.error('  macOS/Linux: bash is usually pre-installed');
      console.error('  Windows: Use WSL2 or Git Bash');
    } else {
      console.error('❌ Error running setup:', err.message);
    }
    process.exit(1);
  });

  child.on('close', (code) => {
    process.exit(code || 0);
  });
}

function expandHome(inputPath) {
  if (!inputPath) {
    return inputPath;
  }
  if (inputPath.startsWith('~')) {
    return path.join(os.homedir(), inputPath.slice(1));
  }
  return path.resolve(inputPath);
}

// ============================================================================
// CONFIG FILE UTILITIES
// ============================================================================
const SANDBOX_DIR = path.join(os.homedir(), '.ai-sandbox');
const CONFIG_PATH = path.join(SANDBOX_DIR, 'config.json');
const LEGACY_WORKSPACES_PATH = path.join(SANDBOX_DIR, 'workspaces');
const LEGACY_GIT_ALLOWED_PATH = path.join(SANDBOX_DIR, 'git-allowed');

function readConfig() {
  try {
    if (fs.existsSync(CONFIG_PATH)) {
      return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
    }
  } catch (err) {}
  // Return default v2 config
  return {
    version: 2,
    workspaces: [],
    git: { allowedWorkspaces: [], keySelections: {} },
    networks: { global: [], workspaces: {} }
  };
}

function writeConfig(config) {
  fs.mkdirSync(SANDBOX_DIR, { recursive: true });
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
  fs.chmodSync(CONFIG_PATH, '600');
}

function readLegacyFile(filePath) {
  try {
    if (fs.existsSync(filePath)) {
      return fs.readFileSync(filePath, 'utf8').split('\n').filter(Boolean);
    }
  } catch (err) {}
  return [];
}

function writeLegacyFile(filePath, items) {
  fs.mkdirSync(SANDBOX_DIR, { recursive: true });
  fs.writeFileSync(filePath, items.join('\n') + '\n');
  fs.chmodSync(filePath, '600');
}

function pathExists(targetPath) {
  try {
    return fs.existsSync(targetPath);
  } catch (err) {
    return false;
  }
}

function isDirectory(targetPath) {
  try {
    return fs.statSync(targetPath).isDirectory();
  } catch (err) {
    return false;
  }
}

function formatBytes(bytes) {
  if (typeof bytes !== 'number' || Number.isNaN(bytes)) {
    return 'unknown';
  }
  if (bytes < 1024) {
    return `${bytes} B`;
  }
  const kb = bytes / 1024;
  if (kb < 1024) {
    return `${kb.toFixed(1)} KB`;
  }
  const mb = kb / 1024;
  if (mb < 1024) {
    return `${mb.toFixed(1)} MB`;
  }
  const gb = mb / 1024;
  return `${gb.toFixed(1)} GB`;
}

function getPathSize(targetPath) {
  try {
    const stats = fs.lstatSync(targetPath);
    if (!stats.isDirectory()) {
      return stats.size;
    }
    let total = 0;
    const entries = fs.readdirSync(targetPath, { withFileTypes: true });
    for (const entry of entries) {
      const entryPath = path.join(targetPath, entry.name);
      const entrySize = getPathSize(entryPath);
      if (typeof entrySize === 'number') {
        total += entrySize;
      }
    }
    return total;
  } catch (err) {
    return null;
  }
}

function listDirectories(basePath) {
  if (!pathExists(basePath)) {
    return [];
  }
  try {
    return fs
      .readdirSync(basePath, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name)
      .sort();
  } catch (err) {
    return [];
  }
}

function listGitKeyFiles() {
  // V2 path: shared/git/keys
  const gitKeysDir = path.join(os.homedir(), '.ai-sandbox', 'shared', 'git', 'keys');
  // Fallback to legacy path
  const legacyDir = path.join(os.homedir(), '.ai-sandbox', 'git-keys');
  const targetDir = fs.existsSync(gitKeysDir) ? gitKeysDir : legacyDir;
  try {
    if (!pathExists(targetDir)) {
      return [];
    }
    return fs
      .readdirSync(targetDir, { withFileTypes: true })
      .filter((entry) => entry.isFile())
      .map((entry) => entry.name)
      .sort();
  } catch (err) {
    return [];
  }
}

// ============================================================================
// CONFIG SHOW COMMAND
// ============================================================================
function runConfigShow(jsonOutput) {
  const config = readConfig();

  if (jsonOutput) {
    console.log(JSON.stringify(config, null, 2));
    return;
  }

  console.log('\n📋 AI Sandbox Configuration\n');
  console.log(`Version: ${config.version || 1}`);
  console.log(`Config file: ${CONFIG_PATH}`);

  console.log('\n📁 Workspaces:');
  const workspaces = config.workspaces || [];
  if (workspaces.length === 0) {
    console.log('  (none configured)');
  } else {
    workspaces.forEach(ws => console.log(`  - ${ws}`));
  }

  console.log('\n🔐 Git Access:');
  const gitAllowed = config.git?.allowedWorkspaces || [];
  if (gitAllowed.length === 0) {
    console.log('  (no workspaces with git access)');
  } else {
    gitAllowed.forEach(ws => console.log(`  - ${ws}`));
  }

  console.log('\n🌐 Networks:');
  const globalNetworks = config.networks?.global || [];
  const wsNetworks = config.networks?.workspaces || {};
  if (globalNetworks.length > 0) {
    console.log('  Global:', globalNetworks.join(', '));
  }
  const wsKeys = Object.keys(wsNetworks).filter(k => wsNetworks[k]?.length > 0);
  if (wsKeys.length > 0) {
    console.log('  Per-workspace:');
    wsKeys.forEach(ws => console.log(`    ${ws}: ${wsNetworks[ws].join(', ')}`));
  }
  if (globalNetworks.length === 0 && wsKeys.length === 0) {
    console.log('  (none configured)');
  }
  console.log('');
}

// ============================================================================
// CONFIG TOOL COMMAND
// ============================================================================
const TOOL_CONFIG_MAP = {
  'claude': ['.claude.json'],
  'opencode': ['.opencode.json', 'auth.json', '.gitconfig'],
  'gemini': ['.gemini.json'],
  'aider': ['.aider.conf', '.aider.conf.yml'],
  'amp': [
    '.amp.json',
    'secrets.json',
    '.config/amp/settings.json',
    '.local/share/amp/secrets.json'
  ],
  'kilo': ['.kilo.json'],
  'codex': ['.codex.json'],
  'qwen': ['.qwen.json']
};

async function runConfigTool(toolName, showContent) {
  if (!toolName) {
    console.error('❌ Please provide a tool name');
    console.error('Usage: npx @kokorolx/ai-sandbox-wrapper config tool <tool> [--show]');
    process.exit(1);
  }

  const toolHome = path.join(SANDBOX_DIR, 'home');
  console.log(`\n🔍 Sandbox Configuration for: ${toolName}`);
  console.log(`Sandbox Home: ${toolHome}`);

  if (!fs.existsSync(toolHome)) {
    console.log('Status:     ⚠️  Not yet initialized (folder missing on host)');
    return;
  }

  const possibleConfigs = TOOL_CONFIG_MAP[toolName] || [];
  let foundConfig = null;

  // Search current directory first (higher priority in ai-run)
  for (const cfg of possibleConfigs) {
    const localPath = path.join(process.cwd(), cfg);
    if (fs.existsSync(localPath)) {
      foundConfig = localPath;
      console.log(`Config:     ✅ Found in current directory: ${foundConfig}`);
      break;
    }
  }

  // Then search sandbox home
  if (!foundConfig) {
    for (const cfg of possibleConfigs) {
      const sandboxPath = path.join(toolHome, cfg);
      if (fs.existsSync(sandboxPath)) {
        foundConfig = sandboxPath;
        console.log(`Config:     ✅ Found in sandbox home: ${foundConfig}`);
        break;
      }
    }
  }

  if (!foundConfig) {
    if (possibleConfigs.length > 0) {
      console.log(`Config:     ❌ Not found (searched for: ${possibleConfigs.join(', ')})`);
    } else {
      console.log('Config:     ℹ️  No common config filename matches known for this tool');
    }
  } else if (showContent) {
    try {
      const content = fs.readFileSync(foundConfig, 'utf8');
      console.log('\n--- Content ---\n');
      console.log(content);
      console.log('\n---------------\n');
    } catch (err) {
      console.error(`❌ Error reading config: ${err.message}`);
    }
  } else {
    console.log(`\nTo view content, run: npx @kokorolx/ai-sandbox-wrapper config tool ${toolName} --show`);
  }
  console.log('');
}

// ============================================================================
// WORKSPACE COMMANDS
// ============================================================================
function runWorkspaceList() {
  const config = readConfig();
  const workspaces = config.workspaces || [];

  console.log('\n📁 Whitelisted Workspaces:\n');
  if (workspaces.length === 0) {
    console.log('  (none configured)');
    console.log('\n  Add a workspace: npx @kokorolx/ai-sandbox-wrapper workspace add <path>');
  } else {
    workspaces.forEach((ws, i) => console.log(`  ${i + 1}. ${ws}`));
  }
  console.log('');
}

function runWorkspaceAdd(inputPath) {
  if (!inputPath) {
    console.error('❌ Please provide a workspace path');
    console.error('Usage: npx @kokorolx/ai-sandbox-wrapper workspace add <path>');
    process.exit(1);
  }

  const expandedPath = expandHome(inputPath);
  const config = readConfig();

  if (!config.workspaces) config.workspaces = [];

  if (config.workspaces.includes(expandedPath)) {
    console.log(`ℹ️  Workspace already exists: ${expandedPath}`);
    return;
  }

  config.workspaces.push(expandedPath);
  writeConfig(config);

  // Also update legacy file
  const legacyWs = readLegacyFile(LEGACY_WORKSPACES_PATH);
  if (!legacyWs.includes(expandedPath)) {
    legacyWs.push(expandedPath);
    writeLegacyFile(LEGACY_WORKSPACES_PATH, legacyWs);
  }

  console.log(`✅ Added workspace: ${expandedPath}`);
}

function runWorkspaceRemove(inputPath) {
  if (!inputPath) {
    console.error('❌ Please provide a workspace path');
    console.error('Usage: npx @kokorolx/ai-sandbox-wrapper workspace remove <path>');
    process.exit(1);
  }

  const expandedPath = expandHome(inputPath);
  const config = readConfig();

  if (!config.workspaces) config.workspaces = [];
  const idx = config.workspaces.indexOf(expandedPath);

  if (idx === -1) {
    console.log(`ℹ️  Workspace not found: ${expandedPath}`);
    return;
  }

  config.workspaces.splice(idx, 1);
  writeConfig(config);

  // Also update legacy file
  const legacyWs = readLegacyFile(LEGACY_WORKSPACES_PATH);
  const legacyIdx = legacyWs.indexOf(expandedPath);
  if (legacyIdx !== -1) {
    legacyWs.splice(legacyIdx, 1);
    writeLegacyFile(LEGACY_WORKSPACES_PATH, legacyWs);
  }

  console.log(`✅ Removed workspace: ${expandedPath}`);
}

// ============================================================================
// GIT COMMANDS
// ============================================================================
function runGitStatus() {
  const config = readConfig()
  const allowed = config.git?.allowedWorkspaces || []
  const fetchOnly = config.git?.fetchOnlyWorkspaces || []

  console.log('\n🔐 Git-Enabled Workspaces:\n')
  if (allowed.length === 0 && fetchOnly.length === 0) {
    console.log('  (no workspaces with git access)')
    console.log('\n  Enable git: npx @kokorolx/ai-sandbox-wrapper git enable <workspace-path>')
  } else {
    if (allowed.length > 0) {
      console.log('  Full access:')
      allowed.forEach((ws, i) => console.log(`    ${i + 1}. ${ws}`))
    }
    if (fetchOnly.length > 0) {
      console.log('  Fetch only (no push):')
      fetchOnly.forEach((ws, i) => console.log(`    ${i + 1}. ${ws}`))
    }
  }
  console.log('')
}

function runGitEnable(inputPath) {
  if (!inputPath) {
    console.error('❌ Please provide a workspace path');
    console.error('Usage: npx @kokorolx/ai-sandbox-wrapper git enable <path>');
    process.exit(1);
  }

  const expandedPath = expandHome(inputPath);
  const config = readConfig();

  if (!config.git) config.git = { allowedWorkspaces: [], keySelections: {} };
  if (!config.git.allowedWorkspaces) config.git.allowedWorkspaces = [];

  if (config.git.allowedWorkspaces.includes(expandedPath)) {
    console.log(`ℹ️  Git access already enabled for: ${expandedPath}`);
    return;
  }

  config.git.allowedWorkspaces.push(expandedPath);
  writeConfig(config);

  // Also update legacy file
  const legacyGit = readLegacyFile(LEGACY_GIT_ALLOWED_PATH);
  if (!legacyGit.includes(expandedPath)) {
    legacyGit.push(expandedPath);
    writeLegacyFile(LEGACY_GIT_ALLOWED_PATH, legacyGit);
  }

  console.log(`✅ Enabled git access for: ${expandedPath}`);
}

function runGitDisable(inputPath) {
  if (!inputPath) {
    console.error('❌ Please provide a workspace path');
    console.error('Usage: npx @kokorolx/ai-sandbox-wrapper git disable <path>');
    process.exit(1);
  }

  const expandedPath = expandHome(inputPath);
  const config = readConfig();

  if (!config.git?.allowedWorkspaces) {
    console.log(`ℹ️  Git access not enabled for: ${expandedPath}`);
    return;
  }

  const idx = config.git.allowedWorkspaces.indexOf(expandedPath);
  if (idx === -1) {
    console.log(`ℹ️  Git access not enabled for: ${expandedPath}`);
    return;
  }

  config.git.allowedWorkspaces.splice(idx, 1);
  writeConfig(config);

  // Also update legacy file
  const legacyGit = readLegacyFile(LEGACY_GIT_ALLOWED_PATH);
  const legacyIdx = legacyGit.indexOf(expandedPath);
  if (legacyIdx !== -1) {
    legacyGit.splice(legacyIdx, 1);
    writeLegacyFile(LEGACY_GIT_ALLOWED_PATH, legacyGit);
  }

  console.log(`✅ Disabled git access for: ${expandedPath}`);
}

function runGitFetchOnly(inputPath) {
  if (!inputPath) {
    console.error('❌ Please provide a workspace path')
    console.error('Usage: npx @kokorolx/ai-sandbox-wrapper git fetch-only <path>')
    process.exit(1)
  }

  const expandedPath = expandHome(inputPath)
  const config = readConfig()

  if (!config.git) config.git = { allowedWorkspaces: [], fetchOnlyWorkspaces: [], keySelections: {} }
  if (!config.git.fetchOnlyWorkspaces) config.git.fetchOnlyWorkspaces = []

  // Remove from full access if present
  if (config.git.allowedWorkspaces) {
    const fullIdx = config.git.allowedWorkspaces.indexOf(expandedPath)
    if (fullIdx !== -1) config.git.allowedWorkspaces.splice(fullIdx, 1)
  }

  if (config.git.fetchOnlyWorkspaces.includes(expandedPath)) {
    console.log(`ℹ️  Git fetch-only already enabled for: ${expandedPath}`)
    return
  }

  config.git.fetchOnlyWorkspaces.push(expandedPath)
  writeConfig(config)

  console.log(`✅ Enabled git fetch-only for: ${expandedPath}`)
}

function runGitFull(inputPath) {
  if (!inputPath) {
    console.error('❌ Please provide a workspace path')
    console.error('Usage: npx @kokorolx/ai-sandbox-wrapper git full <path>')
    process.exit(1)
  }

  const expandedPath = expandHome(inputPath)
  const config = readConfig()

  if (!config.git) config.git = { allowedWorkspaces: [], fetchOnlyWorkspaces: [], keySelections: {} }
  if (!config.git.allowedWorkspaces) config.git.allowedWorkspaces = []

  // Remove from fetch-only if present
  if (config.git.fetchOnlyWorkspaces) {
    const foIdx = config.git.fetchOnlyWorkspaces.indexOf(expandedPath)
    if (foIdx !== -1) config.git.fetchOnlyWorkspaces.splice(foIdx, 1)
  }

  if (config.git.allowedWorkspaces.includes(expandedPath)) {
    console.log(`ℹ️  Git full access already enabled for: ${expandedPath}`)
    return
  }

  config.git.allowedWorkspaces.push(expandedPath)
  writeConfig(config)

  console.log(`✅ Enabled git full access for: ${expandedPath}`)
}

// ============================================================================
// NETWORK COMMANDS
// ============================================================================
function runNetworkList() {
  const config = readConfig();
  const globalNetworks = config.networks?.global || [];
  const wsNetworks = config.networks?.workspaces || {};

  console.log('\n🌐 Configured Networks:\n');

  console.log('Global networks:');
  if (globalNetworks.length === 0) {
    console.log('  (none)');
  } else {
    globalNetworks.forEach(n => console.log(`  - ${n}`));
  }

  console.log('\nPer-workspace networks:');
  const wsKeys = Object.keys(wsNetworks).filter(k => wsNetworks[k]?.length > 0);
  if (wsKeys.length === 0) {
    console.log('  (none)');
  } else {
    wsKeys.forEach(ws => {
      console.log(`  ${ws}:`);
      wsNetworks[ws].forEach(n => console.log(`    - ${n}`));
    });
  }
  console.log('');
}

function runNetworkAdd(name, isGlobal, workspacePath) {
  if (!name) {
    console.error('❌ Please provide a network name');
    console.error('Usage: npx @kokorolx/ai-sandbox-wrapper network add <name> [--global|--workspace <path>]');
    process.exit(1);
  }

  const config = readConfig();
  if (!config.networks) config.networks = { global: [], workspaces: {} };

  if (isGlobal || !workspacePath) {
    if (!config.networks.global) config.networks.global = [];
    if (config.networks.global.includes(name)) {
      console.log(`ℹ️  Network already in global scope: ${name}`);
      return;
    }
    config.networks.global.push(name);
    writeConfig(config);
    console.log(`✅ Added network to global scope: ${name}`);
  } else {
    const expandedPath = expandHome(workspacePath);
    if (!config.networks.workspaces) config.networks.workspaces = {};
    if (!config.networks.workspaces[expandedPath]) config.networks.workspaces[expandedPath] = [];
    if (config.networks.workspaces[expandedPath].includes(name)) {
      console.log(`ℹ️  Network already configured for workspace: ${name}`);
      return;
    }
    config.networks.workspaces[expandedPath].push(name);
    writeConfig(config);
    console.log(`✅ Added network ${name} to workspace: ${expandedPath}`);
  }
}

function runNetworkRemove(name, isGlobal, workspacePath) {
  if (!name) {
    console.error('❌ Please provide a network name');
    console.error('Usage: npx @kokorolx/ai-sandbox-wrapper network remove <name> [--global|--workspace <path>]');
    process.exit(1);
  }

  const config = readConfig();
  if (!config.networks) {
    console.log(`ℹ️  Network not found: ${name}`);
    return;
  }

  if (isGlobal || !workspacePath) {
    if (!config.networks.global) {
      console.log(`ℹ️  Network not found in global scope: ${name}`);
      return;
    }
    const idx = config.networks.global.indexOf(name);
    if (idx === -1) {
      console.log(`ℹ️  Network not found in global scope: ${name}`);
      return;
    }
    config.networks.global.splice(idx, 1);
    writeConfig(config);
    console.log(`✅ Removed network from global scope: ${name}`);
  } else {
    const expandedPath = expandHome(workspacePath);
    if (!config.networks.workspaces?.[expandedPath]) {
      console.log(`ℹ️  Network not found for workspace: ${name}`);
      return;
    }
    const idx = config.networks.workspaces[expandedPath].indexOf(name);
    if (idx === -1) {
      console.log(`ℹ️  Network not found for workspace: ${name}`);
      return;
    }
    config.networks.workspaces[expandedPath].splice(idx, 1);
    writeConfig(config);
    console.log(`✅ Removed network ${name} from workspace: ${expandedPath}`);
  }
}

function createInterface() {
  return readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
}

function askQuestion(rl, prompt) {
  return new Promise((resolve) => {
    rl.question(prompt, (answer) => resolve(answer.trim()));
  });
}

function buildCategoryOptions() {
  return [
    {
      key: 'caches',
      label: 'Tool caches (~/.ai-sandbox/cache/) - Safe to delete'
    },
    {
      key: 'configs',
      label: 'Tool configs (~/.ai-sandbox/home/) - Loses settings'
    },
    {
      key: 'global',
      label: 'Global config files - Loses preferences'
    },
    {
      key: 'everything',
      label: 'Everything (~/.ai-sandbox/) - Full reset'
    }
  ];
}

function buildToolItems(baseDir, displayPrefix) {
  const resolvedBase = expandHome(baseDir);
  const names = listDirectories(resolvedBase);
  return names.map((name) => {
    const fullPath = path.join(resolvedBase, name);
    const size = getPathSize(fullPath);
    return {
      name,
      path: fullPath,
      display: `${name}/`,
      label: `${displayPrefix}/${name}/`,
      size
    };
  });
}

function buildGlobalItems() {
  const homeDir = os.homedir();
  const sandboxDir = path.join(homeDir, '.ai-sandbox');
  const gitKeysDir = path.join(sandboxDir, 'git-keys');

  const safe = [
    {
      label: '🟢 Safe',
      items: buildToolItems('~/.ai-sandbox/cache', '~/.ai-sandbox/cache')
    }
  ];
  const medium = [
    {
      label: '🟡 Medium',
      items: [
        {
          name: 'config.json',
          path: path.join(sandboxDir, 'config.json'),
          display: '~/.ai-sandbox/config.json',
          size: getPathSize(path.join(sandboxDir, 'config.json'))
        },
        {
          name: 'git-allowed',
          path: path.join(sandboxDir, 'git-allowed'),
          display: '~/.ai-sandbox/git-allowed',
          size: getPathSize(path.join(sandboxDir, 'git-allowed'))
        }
      ]
        .concat(
          listGitKeyFiles().map((file) => {
            const fullPath = path.join(gitKeysDir, file);
            return {
              name: file,
              path: fullPath,
              display: `~/.ai-sandbox/git-keys/${file}`,
              size: getPathSize(fullPath)
            };
          })
        )
        .filter((item) => pathExists(item.path))
    }
  ];
  const critical = [
    {
      label: '🔴 Critical',
      items: [
        {
          name: 'workspaces',
          path: path.join(sandboxDir, 'workspaces'),
          display: '~/.ai-sandbox/workspaces',
          size: getPathSize(path.join(sandboxDir, 'workspaces'))
        },
        {
          name: 'env',
          path: path.join(sandboxDir, 'env'),
          display: '~/.ai-sandbox/env',
          size: getPathSize(path.join(sandboxDir, 'env'))
        }
      ].filter((item) => pathExists(item.path))
    }
  ];

  const groups = [];
  for (const group of safe.concat(medium, critical)) {
    const filtered = group.items.filter((item) => pathExists(item.path));
    if (filtered.length > 0) {
      groups.push({ label: group.label, items: filtered });
    }
  }
  return groups;
}

function displayItemList(items) {
  items.forEach((item, index) => {
    const sizeText = item.size === null ? 'unknown' : formatBytes(item.size);
    console.log(`  ${index + 1}. ${item.display} (${sizeText})`);
  });
}

async function promptCategorySelection(rl) {
  console.log('\n🧹 AI Sandbox Cleanup\n');
  console.log('What would you like to clean?');
  const options = buildCategoryOptions();
  options.forEach((option, index) => {
    console.log(`  ${index + 1}. ${option.label}`);
  });
  const answer = await askQuestion(rl, "\nEnter selection (or 'q' to quit): ");
  const normalized = answer.toLowerCase();
  if (normalized === 'q' || normalized === 'quit') {
    return { action: 'quit' };
  }
  const selection = Number.parseInt(answer, 10);
  if (!Number.isNaN(selection) && selection >= 1 && selection <= options.length) {
    return { action: 'select', value: options[selection - 1].key };
  }
  console.log('❌ Invalid selection.');
  return { action: 'retry' };
}

async function promptItemSelection(rl, title, items) {
  console.log(`\n${title}\n`);
  if (items.length === 0) {
    console.log('No items found.');
    return { action: 'back' };
  }
  console.log('Select items to clear:');
  displayItemList(items);
  const answer = await askQuestion(
    rl,
    "\nEnter selection (comma-separated, 'all', or 'b' to go back): "
  );
  const normalized = answer.toLowerCase();
  if (normalized === 'b' || normalized === 'back') {
    return { action: 'back' };
  }
  if (normalized === 'q' || normalized === 'quit') {
    return { action: 'quit' };
  }
  if (normalized === 'all') {
    return { action: 'select', items };
  }
  const selections = answer
    .split(',')
    .map((entry) => Number.parseInt(entry.trim(), 10))
    .filter((value) => !Number.isNaN(value) && value >= 1 && value <= items.length);
  if (selections.length === 0) {
    console.log('❌ Invalid selection.');
    return { action: 'retry' };
  }
  const uniqueIndexes = Array.from(new Set(selections));
  return { action: 'select', items: uniqueIndexes.map((idx) => items[idx - 1]) };
}

async function promptGlobalSelection(rl, groups) {
  console.log('\n🌐 Global Config Files\n');
  if (groups.length === 0) {
    console.log('No global config files found.');
    return { action: 'back' };
  }
  let index = 1;
  const flattened = [];
  for (const group of groups) {
    console.log(group.label);
    group.items.forEach((item) => {
      const sizeText = item.size === null ? 'unknown' : formatBytes(item.size);
      console.log(`  ${index}. ${item.display} (${sizeText})`);
      flattened.push(item);
      index += 1;
    });
  }
  const answer = await askQuestion(
    rl,
    "\nEnter selection (comma-separated, 'all', or 'b' to go back): "
  );
  const normalized = answer.toLowerCase();
  if (normalized === 'b' || normalized === 'back') {
    return { action: 'back' };
  }
  if (normalized === 'q' || normalized === 'quit') {
    return { action: 'quit' };
  }
  if (normalized === 'all') {
    return { action: 'select', items: flattened };
  }
  const selections = answer
    .split(',')
    .map((entry) => Number.parseInt(entry.trim(), 10))
    .filter((value) => !Number.isNaN(value) && value >= 1 && value <= flattened.length);
  if (selections.length === 0) {
    console.log('❌ Invalid selection.');
    return { action: 'retry' };
  }
  const uniqueIndexes = Array.from(new Set(selections));
  return { action: 'select', items: uniqueIndexes.map((idx) => flattened[idx - 1]) };
}

function summarizeSelection(items) {
  let totalSize = 0;
  const summaries = items.map((item) => {
    const size = typeof item.size === 'number' ? item.size : 0;
    totalSize += size;
    const sizeLabel = item.size === null ? 'unknown' : formatBytes(item.size);
    return { display: item.display, sizeLabel };
  });
  return { summaries, totalSize };
}

async function confirmDeletion(rl, items) {
  console.log('\nYou are about to delete:');
  const { summaries, totalSize } = summarizeSelection(items);
  summaries.forEach((summary) => {
    console.log(`  - ${summary.display} (${summary.sizeLabel})`);
  });
  console.log(`\nTotal: ${formatBytes(totalSize)}\n`);
  const answer = await askQuestion(rl, "Type 'yes' to confirm: ");
  return answer.toLowerCase() === 'yes';
}

function deleteItem(item) {
  if (!pathExists(item.path)) {
    return { status: 'missing', message: `Skipped ${item.display} (missing)` };
  }
  try {
    if (isDirectory(item.path)) {
      fs.rmSync(item.path, { recursive: true, force: true });
    } else {
      fs.rmSync(item.path, { force: true });
    }
    return { status: 'deleted', message: `✓ Deleted ${item.display}` };
  } catch (err) {
    const errorMessage = err && err.message ? err.message : 'unknown error';
    return { status: 'error', message: `❌ Failed to delete ${item.display}: ${errorMessage}` };
  }
}

function deleteItems(items) {
  let deletedCount = 0;
  let freedBytes = 0;
  items.forEach((item) => {
    const size = typeof item.size === 'number' ? item.size : 0;
    const result = deleteItem(item);
    console.log(result.message);
    if (result.status === 'deleted') {
      deletedCount += 1;
      freedBytes += size;
    }
  });
  console.log(`\nDeleted ${deletedCount} items, freed ${formatBytes(freedBytes)}`);
}

async function handleCategoryItems(rl, categoryKey) {
  if (categoryKey === 'caches') {
    const items = buildToolItems('~/.ai-sandbox/cache', '~/.ai-sandbox/cache');
    return promptItemSelection(rl, '📁 Tool Caches (~/.ai-sandbox/cache/)', items);
  }
  if (categoryKey === 'configs') {
    const items = buildToolItems('~/.ai-sandbox/home', '~/.ai-sandbox/home');
    return promptItemSelection(rl, '⚙️ Tool Configs (~/.ai-sandbox/home/)', items);
  }
  if (categoryKey === 'global') {
    const groups = buildGlobalItems();
    return promptGlobalSelection(rl, groups);
  }
  if (categoryKey === 'everything') {
    const homeDir = os.homedir();
    const sandboxPath = path.join(homeDir, '.ai-sandbox');
    const sandboxItem = {
      name: '.ai-sandbox',
      path: sandboxPath,
      display: '~/.ai-sandbox/',
      size: getPathSize(sandboxPath)
    };
    if (!pathExists(sandboxPath)) {
      console.log('\n~/.ai-sandbox/ does not exist. Nothing to delete.');
      return { action: 'back' };
    }
    return { action: 'select', items: [sandboxItem] };
  }
  return { action: 'back' };
}

async function runClean() {
  const rl = createInterface();
  try {
    let inClean = true;
    while (inClean) {
      const categoryResult = await promptCategorySelection(rl);
      if (categoryResult.action === 'quit') {
        break;
      }
      if (categoryResult.action === 'retry') {
        continue;
      }
      const categoryKey = categoryResult.value;
      let selecting = true;
      while (selecting) {
        const selectionResult = await handleCategoryItems(rl, categoryKey);
        if (selectionResult.action === 'quit') {
          inClean = false;
          break;
        }
        if (selectionResult.action === 'back') {
          break;
        }
        if (selectionResult.action === 'retry') {
          continue;
        }
        const items = selectionResult.items || [];
        if (items.length === 0) {
          console.log('No items selected.');
          break;
        }
        const confirmed = await confirmDeletion(rl, items);
        if (!confirmed) {
          console.log('Aborted. Nothing deleted.');
          break;
        }
        deleteItems(items);
        selecting = false;
      }
    }
  } finally {
    rl.close();
  }
}

// ============================================================================
// TUI UPDATE COMMAND
// ============================================================================
async function runUpdate() {
  const rl = createInterface();

  const mainMenu = [
    { key: 'workspaces', label: '📁 Manage Workspaces' },
    { key: 'git', label: '🔐 Manage Git Access' },
    { key: 'networks', label: '🌐 Manage Networks' },
    { key: 'view', label: '📋 View Current Config' },
    { key: 'quit', label: '🚪 Exit' }
  ];

  try {
    let running = true;
    while (running) {
      console.log('\n🛠️  AI Sandbox Configuration Manager\n');
      mainMenu.forEach((item, i) => console.log(`  ${i + 1}. ${item.label}`));

      const answer = await askQuestion(rl, '\nSelect option (1-5): ');
      const choice = parseInt(answer, 10);

      if (isNaN(choice) || choice < 1 || choice > 5) {
        console.log('❌ Invalid selection');
        continue;
      }

      const selected = mainMenu[choice - 1];

      switch (selected.key) {
        case 'workspaces':
          await manageWorkspacesMenu(rl);
          break;
        case 'git':
          await manageGitMenu(rl);
          break;
        case 'networks':
          await manageNetworksMenu(rl);
          break;
        case 'view':
          runConfigShow(false);
          break;
        case 'quit':
          running = false;
          break;
      }
    }
    console.log('\n👋 Goodbye!\n');
  } finally {
    rl.close();
  }
}

async function manageWorkspacesMenu(rl) {
  const config = readConfig();
  const workspaces = config.workspaces || [];

  console.log('\n📁 Manage Workspaces\n');
  console.log('Current workspaces:');
  if (workspaces.length === 0) {
    console.log('  (none)');
  } else {
    workspaces.forEach((ws, i) => console.log(`  ${i + 1}. ${ws}`));
  }
  console.log('');
  console.log('  a) Add workspace');
  console.log('  r) Remove workspace');
  console.log('  b) Back');

  const choice = await askQuestion(rl, '\nSelect action: ');

  switch (choice.toLowerCase()) {
    case 'a':
      const addPath = await askQuestion(rl, 'Enter workspace path: ');
      if (addPath) runWorkspaceAdd(addPath);
      break;
    case 'r':
      if (workspaces.length === 0) {
        console.log('ℹ️  No workspaces to remove');
      } else {
        const idx = await askQuestion(rl, 'Enter number to remove: ');
        const num = parseInt(idx, 10);
        if (num >= 1 && num <= workspaces.length) {
          runWorkspaceRemove(workspaces[num - 1]);
        } else {
          console.log('❌ Invalid selection');
        }
      }
      break;
  }
}

async function manageGitMenu(rl) {
  const config = readConfig();
  const allowed = config.git?.allowedWorkspaces || [];
  const workspaces = config.workspaces || [];

  console.log('\n🔐 Manage Git Access\n');
  console.log('Git-enabled workspaces:');
  if (allowed.length === 0) {
    console.log('  (none)');
  } else {
    allowed.forEach((ws, i) => console.log(`  ${i + 1}. ${ws}`));
  }
  console.log('');
  console.log('  e) Enable git for a workspace');
  console.log('  d) Disable git for a workspace');
  console.log('  b) Back');

  const choice = await askQuestion(rl, '\nSelect action: ');

  switch (choice.toLowerCase()) {
    case 'e':
      // Show available workspaces not yet git-enabled
      const available = workspaces.filter(ws => !allowed.includes(ws));
      if (available.length === 0) {
        const path = await askQuestion(rl, 'Enter workspace path: ');
        if (path) runGitEnable(path);
      } else {
        console.log('\nAvailable workspaces:');
        available.forEach((ws, i) => console.log(`  ${i + 1}. ${ws}`));
        const idx = await askQuestion(rl, 'Enter number or path: ');
        const num = parseInt(idx, 10);
        if (num >= 1 && num <= available.length) {
          runGitEnable(available[num - 1]);
        } else if (idx) {
          runGitEnable(idx);
        }
      }
      break;
    case 'd':
      if (allowed.length === 0) {
        console.log('ℹ️  No workspaces with git access');
      } else {
        const idx = await askQuestion(rl, 'Enter number to disable: ');
        const num = parseInt(idx, 10);
        if (num >= 1 && num <= allowed.length) {
          runGitDisable(allowed[num - 1]);
        } else {
          console.log('❌ Invalid selection');
        }
      }
      break;
  }
}

async function manageNetworksMenu(rl) {
  const config = readConfig();
  const globalNetworks = config.networks?.global || [];

  console.log('\n🌐 Manage Networks\n');
  console.log('Global networks:');
  if (globalNetworks.length === 0) {
    console.log('  (none)');
  } else {
    globalNetworks.forEach((n, i) => console.log(`  ${i + 1}. ${n}`));
  }
  console.log('');
  console.log('  a) Add global network');
  console.log('  r) Remove global network');
  console.log('  b) Back');

  const choice = await askQuestion(rl, '\nSelect action: ');

  switch (choice.toLowerCase()) {
    case 'a':
      const name = await askQuestion(rl, 'Enter network name: ');
      if (name) runNetworkAdd(name, true, null);
      break;
    case 'r':
      if (globalNetworks.length === 0) {
        console.log('ℹ️  No networks to remove');
      } else {
        const idx = await askQuestion(rl, 'Enter number to remove: ');
        const num = parseInt(idx, 10);
        if (num >= 1 && num <= globalNetworks.length) {
          runNetworkRemove(globalNetworks[num - 1], true, null);
        } else {
          console.log('❌ Invalid selection');
        }
      }
      break;
  }
}

// ============================================================================
// CLEAN CACHE COMMAND (non-interactive)
// ============================================================================
const CACHE_TYPES = ['npm', 'bun', 'pip', 'playwright-browsers']

function runCleanCache(cacheType) {
  const cacheDir = path.join(SANDBOX_DIR, 'cache')

  if (cacheType && !CACHE_TYPES.includes(cacheType)) {
    console.error(`❌ Unknown cache type: ${cacheType}`)
    console.error(`Valid types: ${CACHE_TYPES.join(', ')}`)
    process.exit(1)
  }

  const targets = cacheType ? [cacheType] : CACHE_TYPES

  let totalFreed = 0
  for (const t of targets) {
    const targetPath = path.join(cacheDir, t)
    if (!pathExists(targetPath)) {
      console.log(`  ⏭  ${t}/ (not found)`)
      continue
    }
    const size = getPathSize(targetPath)
    const sizeNum = typeof size === 'number' ? size : 0
    try {
      fs.rmSync(targetPath, { recursive: true, force: true })
      fs.mkdirSync(targetPath, { recursive: true })
      totalFreed += sizeNum
      console.log(`  ✓ ${t}/ cleared (${formatBytes(sizeNum)})`)
    } catch (err) {
      const msg = err && err.message ? err.message : String(err)
      console.error(`  ❌ ${t}/: ${msg}`)
    }
  }

  console.log(`\n🧹 Freed ${formatBytes(totalFreed)}`)
}

// Parse subcommand and options
const subCommand = positionalArgs[1];
const subArg = positionalArgs[2];
const hasGlobalFlag = args.includes('--global');
const workspaceIdx = args.indexOf('--workspace');
const workspaceArg = workspaceIdx !== -1 ? args[workspaceIdx + 1] : null;
const hasJsonFlag = args.includes('--json');
const hasShowFlag = args.includes('--show');

switch (command) {
  case 'setup':
  case undefined:
    runSetup();
    break;
  case 'help':
  case '--help':
  case '-h':
    showHelp();
    break;
  case 'update':
    runUpdate().catch((err) => {
      const message = err && err.message ? err.message : String(err);
      console.error('❌ Update failed:', message);
      process.exit(1);
    });
    break;
  case 'clean':
    if (subCommand === 'cache') {
      runCleanCache(subArg)
    } else {
      runClean().catch((err) => {
        const message = err && err.message ? err.message : String(err)
        console.error('❌ Cleanup failed:', message)
        process.exit(1)
      })
    }
    break;
  case 'config':
    if (subCommand === 'show') {
      runConfigShow(hasJsonFlag);
    } else if (subCommand === 'tool') {
      runConfigTool(subArg, hasShowFlag);
    } else {
      console.error('Usage:');
      console.error('  npx @kokorolx/ai-sandbox-wrapper config show [--json]');
      console.error('  npx @kokorolx/ai-sandbox-wrapper config tool <tool> [--show]');
      process.exit(1);
    }
    break;
  case 'workspace':
    switch (subCommand) {
      case 'list':
        runWorkspaceList();
        break;
      case 'add':
        runWorkspaceAdd(subArg);
        break;
      case 'remove':
        runWorkspaceRemove(subArg);
        break;
      default:
        console.error('Usage: npx @kokorolx/ai-sandbox-wrapper workspace <list|add|remove> [path]');
        process.exit(1);
    }
    break;
  case 'git':
    switch (subCommand) {
      case 'status':
        runGitStatus();
        break;
      case 'enable':
        runGitEnable(subArg);
        break;
      case 'disable':
        runGitDisable(subArg)
        break
      case 'fetch-only':
        runGitFetchOnly(subArg)
        break
      case 'full':
        runGitFull(subArg)
        break
      default:
        console.error('Usage: npx @kokorolx/ai-sandbox-wrapper git <status|enable|disable|fetch-only|full> [path]')
        process.exit(1)
    }
    break;
  case 'network':
    switch (subCommand) {
      case 'list':
        runNetworkList();
        break;
      case 'add':
        runNetworkAdd(subArg, hasGlobalFlag, workspaceArg);
        break;
      case 'remove':
        runNetworkRemove(subArg, hasGlobalFlag, workspaceArg);
        break;
      default:
        console.error('Usage: npx @kokorolx/ai-sandbox-wrapper network <list|add|remove> [name] [--global|--workspace <path>]');
        process.exit(1);
    }
    break;
  default:
    console.error(`❌ Unknown command: ${command}`);
    showHelp();
    process.exit(1);
}
