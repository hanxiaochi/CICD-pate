import { NextRequest, NextResponse } from 'next/server';
import { Client } from 'ssh2';

interface SSHConnectionConfig {
  host: string;
  port?: number;
  username: string;
  password?: string;
  privateKey?: string;
  passphrase?: string;
  timeout?: number;
}

interface FileInfo {
  name: string;
  type: 'file' | 'directory' | 'link';
  size: number;
  mtime: string;
}

interface ProcessInfo {
  pid: number;
  cmd: string;
  port?: number;
  started_at?: string;
}

interface CommandResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

export async function connectSSH(config: SSHConnectionConfig): Promise<Client> {
  return new Promise((resolve, reject) => {
    const client = new Client();
    
    const connectionConfig: any = {
      host: config.host,
      port: config.port || 22,
      username: config.username,
      readyTimeout: config.timeout || 30000,
    };

    if (config.privateKey) {
      connectionConfig.privateKey = config.privateKey;
      if (config.passphrase) {
        connectionConfig.passphrase = config.passphrase;
      }
    } else if (config.password) {
      connectionConfig.password = config.password;
    } else {
      reject(new Error('Either password or privateKey must be provided'));
      return;
    }

    client.on('ready', () => {
      resolve(client);
    });

    client.on('error', (err) => {
      reject(new Error(`SSH connection failed: ${err.message}`));
    });

    client.on('timeout', () => {
      reject(new Error('SSH connection timeout'));
    });

    try {
      client.connect(connectionConfig);
    } catch (error) {
      reject(new Error(`SSH connection error: ${error}`));
    }
  });
}

export async function executeCommand(client: Client, command: string): Promise<CommandResult> {
  return new Promise((resolve, reject) => {
    if (!client || !client.exec) {
      reject(new Error('Invalid SSH client'));
      return;
    }

    client.exec(command, (err, stream) => {
      if (err) {
        reject(new Error(`Command execution failed: ${err.message}`));
        return;
      }

      let stdout = '';
      let stderr = '';
      let exitCode = 0;

      stream.on('close', (code: number) => {
        exitCode = code || 0;
        resolve({ stdout, stderr, exitCode });
      });

      stream.on('data', (data: Buffer) => {
        stdout += data.toString();
      });

      stream.stderr.on('data', (data: Buffer) => {
        stderr += data.toString();
      });

      stream.on('error', (streamErr: Error) => {
        reject(new Error(`Stream error: ${streamErr.message}`));
      });
    });
  });
}

export function parseFileList(lsOutput: string): FileInfo[] {
  try {
    const lines = lsOutput.trim().split('\n').filter(line => line.trim() !== '');
    const files: FileInfo[] = [];

    for (const line of lines) {
      // Skip total line
      if (line.startsWith('total ')) continue;

      // Parse ls -la output: permissions links owner group size month day time filename
      const parts = line.trim().split(/\s+/);
      if (parts.length < 9) continue;

      const permissions = parts[0];
      const filename = parts.slice(8).join(' ');
      
      // Skip . and .. entries
      if (filename === '.' || filename === '..') continue;

      let type: 'file' | 'directory' | 'link' = 'file';
      if (permissions.startsWith('d')) type = 'directory';
      else if (permissions.startsWith('l')) type = 'link';

      const size = parseInt(parts[4]) || 0;
      
      // Parse date (month day time/year)
      const month = parts[5];
      const day = parts[6];
      const timeOrYear = parts[7];
      
      // Create approximate date string
      const currentYear = new Date().getFullYear();
      let mtime: string;
      
      if (timeOrYear.includes(':')) {
        // It's a time, use current year
        mtime = `${currentYear}-${getMonthNumber(month).toString().padStart(2, '0')}-${day.padStart(2, '0')} ${timeOrYear}:00`;
      } else {
        // It's a year
        mtime = `${timeOrYear}-${getMonthNumber(month).toString().padStart(2, '0')}-${day.padStart(2, '0')} 00:00:00`;
      }

      files.push({
        name: filename,
        type,
        size,
        mtime
      });
    }

    return files;
  } catch (error) {
    throw new Error(`Failed to parse file list: ${error}`);
  }
}

export function parseProcessList(psOutput: string): ProcessInfo[] {
  try {
    const lines = psOutput.trim().split('\n').filter(line => line.trim() !== '');
    const processes: ProcessInfo[] = [];

    // Skip header line if present
    const dataLines = lines[0].toLowerCase().includes('pid') ? lines.slice(1) : lines;

    for (const line of dataLines) {
      const parts = line.trim().split(/\s+/);
      if (parts.length < 2) continue;

      const pid = parseInt(parts[0]);
      if (isNaN(pid)) continue;

      // Join remaining parts as command
      const cmd = parts.slice(1).join(' ');
      
      const processInfo: ProcessInfo = {
        pid,
        cmd
      };

      // Try to extract port from command if it contains port-like patterns
      const portMatch = cmd.match(/:(\d{2,5})\b/);
      if (portMatch) {
        const port = parseInt(portMatch[1]);
        if (port >= 1 && port <= 65535) {
          processInfo.port = port;
        }
      }

      // Try to extract start time if available in ps output format
      const timeMatch = cmd.match(/(\d{2}:\d{2})/);
      if (timeMatch) {
        processInfo.started_at = timeMatch[1];
      }

      processes.push(processInfo);
    }

    return processes;
  } catch (error) {
    throw new Error(`Failed to parse process list: ${error}`);
  }
}

function getMonthNumber(monthName: string): number {
  const months: { [key: string]: number } = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
    'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8,
    'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
  };
  return months[monthName] || 1;
}

// File system operations
export async function listFiles(client: Client, path: string = '.'): Promise<FileInfo[]> {
  try {
    const result = await executeCommand(client, `ls -la "${path}"`);
    if (result.exitCode !== 0) {
      throw new Error(`ls command failed: ${result.stderr}`);
    }
    return parseFileList(result.stdout);
  } catch (error) {
    throw new Error(`Failed to list files: ${error}`);
  }
}

export async function listProcesses(client: Client, filter?: string): Promise<ProcessInfo[]> {
  try {
    let command = 'ps aux';
    if (filter) {
      command += ` | grep "${filter}"`;
    }
    
    const result = await executeCommand(client, command);
    if (result.exitCode !== 0 && !filter) {
      throw new Error(`ps command failed: ${result.stderr}`);
    }
    
    return parseProcessList(result.stdout);
  } catch (error) {
    throw new Error(`Failed to list processes: ${error}`);
  }
}

export async function checkFileExists(client: Client, filePath: string): Promise<boolean> {
  try {
    const result = await executeCommand(client, `test -e "${filePath}" && echo "exists" || echo "not found"`);
    return result.stdout.trim() === 'exists';
  } catch (error) {
    throw new Error(`Failed to check file existence: ${error}`);
  }
}

export async function createDirectory(client: Client, dirPath: string): Promise<void> {
  try {
    const result = await executeCommand(client, `mkdir -p "${dirPath}"`);
    if (result.exitCode !== 0) {
      throw new Error(`mkdir command failed: ${result.stderr}`);
    }
  } catch (error) {
    throw new Error(`Failed to create directory: ${error}`);
  }
}

export async function removeFile(client: Client, filePath: string): Promise<void> {
  try {
    const result = await executeCommand(client, `rm -f "${filePath}"`);
    if (result.exitCode !== 0) {
      throw new Error(`rm command failed: ${result.stderr}`);
    }
  } catch (error) {
    throw new Error(`Failed to remove file: ${error}`);
  }
}

export async function GET(request: NextRequest) {
  try {
    return NextResponse.json({
      message: 'SSH utility module is active',
      version: '1.0.0',
      capabilities: [
        'SSH connection management',
        'Remote command execution',
        'File system operations',
        'Process monitoring',
        'Password and key-based authentication'
      ]
    });
  } catch (error) {
    console.error('SSH utility GET error:', error);
    return NextResponse.json({ 
      error: 'Internal server error: ' + error 
    }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const { action, config, command, path } = await request.json();

    if (!action) {
      return NextResponse.json({ 
        error: "Action is required",
        code: "MISSING_ACTION" 
      }, { status: 400 });
    }

    if (!config || !config.host || !config.username) {
      return NextResponse.json({ 
        error: "Valid SSH config with host and username is required",
        code: "INVALID_CONFIG" 
      }, { status: 400 });
    }

    let client: Client;
    try {
      client = await connectSSH(config);
    } catch (error) {
      return NextResponse.json({ 
        error: `SSH connection failed: ${error}`,
        code: "CONNECTION_FAILED" 
      }, { status: 400 });
    }

    let result: any;

    try {
      switch (action) {
        case 'execute':
          if (!command) {
            return NextResponse.json({ 
              error: "Command is required for execute action",
              code: "MISSING_COMMAND" 
            }, { status: 400 });
          }
          result = await executeCommand(client, command);
          break;

        case 'listFiles':
          result = await listFiles(client, path || '.');
          break;

        case 'listProcesses':
          result = await listProcesses(client, path); // path used as filter here
          break;

        case 'checkFile':
          if (!path) {
            return NextResponse.json({ 
              error: "Path is required for checkFile action",
              code: "MISSING_PATH" 
            }, { status: 400 });
          }
          result = { exists: await checkFileExists(client, path) };
          break;

        case 'createDir':
          if (!path) {
            return NextResponse.json({ 
              error: "Path is required for createDir action",
              code: "MISSING_PATH" 
            }, { status: 400 });
          }
          await createDirectory(client, path);
          result = { success: true, message: 'Directory created successfully' };
          break;

        case 'removeFile':
          if (!path) {
            return NextResponse.json({ 
              error: "Path is required for removeFile action",
              code: "MISSING_PATH" 
            }, { status: 400 });
          }
          await removeFile(client, path);
          result = { success: true, message: 'File removed successfully' };
          break;

        default:
          return NextResponse.json({ 
            error: "Invalid action. Supported actions: execute, listFiles, listProcesses, checkFile, createDir, removeFile",
            code: "INVALID_ACTION" 
          }, { status: 400 });
      }

      client.end();
      return NextResponse.json(result, { status: 201 });

    } catch (operationError) {
      client.end();
      return NextResponse.json({ 
        error: `Operation failed: ${operationError}`,
        code: "OPERATION_FAILED" 
      }, { status: 400 });
    }

  } catch (error) {
    console.error('SSH utility POST error:', error);
    return NextResponse.json({ 
      error: 'Internal server error: ' + error 
    }, { status: 500 });
  }
}