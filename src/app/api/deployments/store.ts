// In-memory store for demo-only deployments. In real app, use DB.
export type DeploymentRecord = {
  id: number;
  systemId: number | null;
  projectId: number;
  packageId: number;
  targetId: number;
  steps: Array<{ key: string; label: string; ok: boolean }>;
  startedAt: number;
  status: "success" | "failed" | "rolledback";
  message: string;
};

let seq = 1;
const deployments: DeploymentRecord[] = [];

export const deploymentsStore = {
  nextId() {
    return seq++;
  },
  push(rec: DeploymentRecord) {
    deployments.push(rec);
  },
  all() {
    return deployments;
  },
  find(id: number) {
    return deployments.find((d) => d.id === id);
  },
};