import { mkdir, rename, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';

process.stdin.setEncoding('utf8');
let input = '';
for await (const chunk of process.stdin) input += chunk;
try {
  const event = JSON.parse(input);
  if (event.fullyIdle === true && event.terminationReason === 'model_stop') {
    const directory = join(process.env.LOCALAPPDATA, 'GeminiNiangWidget');
    const turnId = randomUUID();
    const temp = join(directory, turnId + '.tmp');
    await mkdir(directory, { recursive: true });
    await writeFile(temp, JSON.stringify({ type: 'completion', sessionId: 'antigravity', turnId, endedAt: Date.now() }));
    await rename(temp, join(directory, 'completion.json'));
  }
} finally {
  console.log('{}');
}
