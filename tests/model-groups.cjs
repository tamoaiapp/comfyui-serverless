const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const source = fs.readFileSync(path.join(__dirname, '../download_models.sh'), 'utf8');
const mocked = source
  .replace(/^hf_dl \(\) \{[\s\S]*?^\}/m, 'hf_dl () { echo "MODEL $3"; }')
  .replace(/^dl \(\) \{[\s\S]*?^\}/m, 'dl () { echo "MODEL $2"; }')
  .replace(/^PYBIN=.*$/m, 'PYBIN=unused')
  .replace(/^rm -rf "\$HFTMP"$/m, ':');
// A dry run must never download weights or remove a model directory.
assert.ok(!mocked.includes('hf_hub_download'));
assert.ok(!/^\s*wget\s+/m.test(mocked));
assert.ok(!/^\s*rm\s+-rf/m.test(mocked));
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'tamowork-model-test-'));
const script = path.join(directory, 'models.sh');
fs.writeFileSync(script, mocked);
const bash = process.env.BASH_EXE || 'bash';
try {
  const expected = { all: 10, qwen_unet: 1, qwen_clip: 1, qwen_vae: 1, lightning: 1, flux_unet: 1, flux_clip: 1, flux_vae: 1, custom_loras: 3 };
  for (const [group, count] of Object.entries(expected)) {
    const result = spawnSync(bash, [script.replaceAll('\\', '/'), group], { encoding: 'utf8' });
    assert.equal(result.status, 0, `${group}: ${result.stderr || result.error}`);
    assert.equal((result.stdout.match(/^MODEL /gm) || []).length, count, group);
  }
  const invalid = spawnSync(bash, [script.replaceAll('\\', '/'), 'invalid'], { encoding: 'utf8' });
  assert.equal(invalid.status, 2);
  console.log('All 9 model groups and invalid-group handling passed; no weights downloaded.');
} finally {
  fs.unlinkSync(script);
  fs.rmdirSync(directory);
}
