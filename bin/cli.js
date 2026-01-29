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
  setup     Run interactive setup (configure workspaces, select tools)
  clean     Interactive cleanup for caches/configs
  help      Show this help message

Options:
  --no-cache    Build Docker images without using cache (fresh build)

Examples:
  npx @kokorolx/ai-sandbox-wrapper setup
  npx @kokorolx/ai-sandbox-wrapper setup --no-cache
  npx @kokorolx/ai-sandbox-wrapper clean

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
  return inputPath;
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
  const gitKeysDir = path.join(os.homedir(), '.ai-sandbox', 'git-keys');
  try {
    if (!pathExists(gitKeysDir)) {
      return [];
    }
    return fs
      .readdirSync(gitKeysDir, { withFileTypes: true })
      .filter((entry) => entry.isFile())
      .map((entry) => entry.name)
      .sort();
  } catch (err) {
    return [];
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
  case 'clean':
    runClean().catch((err) => {
      const message = err && err.message ? err.message : String(err);
      console.error('❌ Cleanup failed:', message);
      process.exit(1);
    });
    break;
  default:
    console.error(`❌ Unknown command: ${command}`);
    showHelp();
    process.exit(1);
}
