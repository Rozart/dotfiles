import readline from 'node:readline';
import { pathToFileURL } from 'node:url';
import path from 'node:path';

const modules = process.argv[2];
const { ProgramStatusReporter } = await import(pathToFileURL(path.join(modules, '@earendil-works/pi-coding-agent/dist/modes/interactive/program-status-reporter.js')));
const { formatProgramStatus } = await import(pathToFileURL(path.join(modules, '@earendil-works/pi-tui/dist/program-status.js')));
const terminal = { setProgramStatus: (status) => process.stdout.write(formatProgramStatus(status)) };
const reporter = new ProgramStatusReporter(() => terminal, () => 'Rex status fixture');
reporter.report();

for await (const line of readline.createInterface({ input: process.stdin })) {
  const command = JSON.parse(line);
  if (command.action === 'event') reporter.handleEvent(command.event);
  else if (command.action === 'blocked') reporter.setBlocked(command.source, command.status);
  else if (command.action === 'reset') reporter.reset();
  else if (command.action === 'clear') terminal.setProgramStatus({ state: 'clear' });
  else throw new Error('Unknown fixture command');
}
