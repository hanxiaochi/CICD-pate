import { Client } from 'ssh2';
import SftpClient from 'ssh2-sftp-client';
import fs from 'fs';
import path from 'path';
import tar from 'tar';
import StreamZip from 'node-stream-zip';

export interface SSHConfig {
  host: string;
  port: number;
  username: string;
  password?: string;
  privateKey?: string | Buffer;
  passphrase?: string;
  timeout?: number;
}

export interface FileEntry {
  name: string;
  type: 'file' | 'directory';
  mtime: number;
  size?: number;
}

export interface ProcessInfo {
  pid: number;
  cmd: string;
  port?: number;
  startedAt?: number;
}

export async function connectSSH(config: SSHConfig): Promise<Client> {
  return new Promise((resolve, reject) => {
    const client = new Client();
    
    client.on('ready', () => {
      resolve(client);
    });
    
    client.on('error', (err) => {
      reject(err);
    });
    
    const connectConfig: any = {
      host: config.host,
      port: config.port,
      username: config.username,
      readyTimeout: config.timeout || 10000
    };
    
    if (config.password) {
      connectConfig.password = config.password;
    } else if (config.privateKey) {
      connectConfig.privateKey = config.privateKey;
      if (config.passphrase) {
        connectConfig.passphrase = config.passphrase;
      }
    }
    
    client.connect(connectConfig);
  });
}

export async function connectSFTP(config: SSHConfig): Promise<SftpClient> {
  const sftp = new SftpClient();
  
  const connectConfig: any = {
    host: config.host,
    port: config.port,
    username: config.username,
    readyTimeout: config.timeout || 10000
  };
  
  if (config.password) {
    connectConfig.password = config.password;
  } else if (config.privateKey) {
    connectConfig.privateKey = config.privateKey;
    if (config.passphrase) {
      connectConfig.passphrase = config.passphrase;
    }
  }
  
  await sftp.connect(connectConfig);
  return sftp;
}

export async function execCommand(client: Client, command: string): Promise<string> {
  return new Promise((resolve, reject) => {
    client.exec(command, (err, stream) => {
      if (err) {
        reject(err);
        return;
      }
      
      let stdout = '';
      let stderr = '';
      
      stream.on('close', (code: number) => {
        if (code === 0) {
          resolve(stdout);
        } else {
          reject(new Error(`Command failed with exit code ${code}: ${stderr}`));
        }
      });
      
      stream.on('data', (data: Buffer) => {
        stdout += data.toString();
      });
      
      stream.stderr.on('data', (data: Buffer) => {
        stderr += data.toString();
      });
    });
  });
}

export async function listFiles(client: Client, remotePath: string): Promise<FileEntry[]> {
  const sftp = await new Promise<any>((resolve, reject) => {
    client.sftp((err, sftp) => {
      if (err) reject(err);
      else resolve(sftp);
    });
  });

  return new Promise((resolve, reject) => {
    sftp.readdir(remotePath, (err: any, list: any[]) => {
      if (err) {
        reject(err);
        return;
      }
      
      const entries: FileEntry[] = list.map((item) => ({
        name: item.filename,
        type: item.longname.startsWith('d') ? 'directory' : 'file',
        mtime: item.attrs.mtime * 1000, // Convert to milliseconds
        size: item.attrs.size
      }));
      
      resolve(entries);
    });
  });
}

export async function listProcesses(client: Client, filter?: string): Promise<ProcessInfo[]> {
  try {
    let command = 'ps aux --no-headers';
    if (filter) {
      command += ` | grep "${filter}" | grep -v grep`;
    }
    
    const output = await execCommand(client, command);
    const processes: ProcessInfo[] = [];
    
    const lines = output.trim().split('\n').filter(line => line.trim());
    
    for (const line of lines) {
      const parts = line.trim().split(/\s+/);
      if (parts.length >= 11) {
        const pid = parseInt(parts[1]);
        const cmd = parts.slice(10).join(' ');
        
        processes.push({
          pid,
          cmd,
          startedAt: Date.now() // Approximate, could parse STIME if needed
        });
      }
    }
    
    // Try to detect ports using lsof if available
    try {
      const lsofOutput = await execCommand(client, 'lsof -i -P -n | grep LISTEN');
      const portMap = new Map<number, number>();
      
      const lsofLines = lsofOutput.trim().split('\n');
      for (const line of lsofLines) {
        const parts = line.trim().split(/\s+/);
        if (parts.length >= 9) {
          const pid = parseInt(parts[1]);
          const portMatch = parts[8].match(/:(\d+)$/);
          if (portMatch) {
            portMap.set(pid, parseInt(portMatch[1]));
          }
        }
      }
      
      // Map ports to processes
      processes.forEach(proc => {
        if (portMap.has(proc.pid)) {
          proc.port = portMap.get(proc.pid);
        }
      });
    } catch (lsofError) {
      // lsof not available or failed, continue without port info
    }
    
    return processes;
  } catch (error) {
    throw new Error(`Failed to list processes: ${error}`);
  }
}

export async function uploadFile(sftp: SftpClient, localPath: string, remotePath: string): Promise<void> {
  await sftp.put(localPath, remotePath);
}

export async function downloadFile(sftp: SftpClient, remotePath: string, localPath: string): Promise<void> {
  await sftp.get(remotePath, localPath);
}

export async function createDirectory(sftp: SftpClient, remotePath: string, recursive: boolean = true): Promise<void> {
  await sftp.mkdir(remotePath, recursive);
}

export async function extractArchive(client: Client, archivePath: string, extractPath: string): Promise<void> {
  const ext = path.extname(archivePath).toLowerCase();
  
  if (ext === '.gz' || archivePath.endsWith('.tar.gz')) {
    // Extract tar.gz
    await execCommand(client, `cd "${path.dirname(extractPath)}" && tar -xzf "${archivePath}" -C "${extractPath}"`);
  } else if (ext === '.zip') {
    // Extract zip
    await execCommand(client, `cd "${path.dirname(extractPath)}" && unzip -q "${archivePath}" -d "${extractPath}"`);
  } else {
    throw new Error(`Unsupported archive format: ${ext}`);
  }
}

export async function createSymlink(client: Client, target: string, linkPath: string): Promise<void> {
  // Remove existing symlink/file first
  try {
    await execCommand(client, `rm -f "${linkPath}"`);
  } catch (err) {
    // Ignore if file doesn't exist
  }
  
  await execCommand(client, `ln -sf "${target}" "${linkPath}"`);
}

export async function findJavaProcess(client: Client, jarName: string): Promise<ProcessInfo[]> {
  const command = `ps aux | grep "java.*${jarName}" | grep -v grep`;
  
  try {
    const output = await execCommand(client, command);
    const processes: ProcessInfo[] = [];
    
    const lines = output.trim().split('\n').filter(line => line.trim());
    
    for (const line of lines) {
      const parts = line.trim().split(/\s+/);
      if (parts.length >= 11) {
        const pid = parseInt(parts[1]);
        const cmd = parts.slice(10).join(' ');
        
        processes.push({
          pid,
          cmd,
          startedAt: Date.now()
        });
      }
    }
    
    return processes;
  } catch (error) {
    return []; // No processes found
  }
}

export async function killProcess(client: Client, pid: number): Promise<void> {
  await execCommand(client, `kill ${pid}`);
}

export async function killProcessByPattern(client: Client, pattern: string): Promise<void> {
  await execCommand(client, `pkill -f "${pattern}"`);
}