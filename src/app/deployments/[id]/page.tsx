import { DeployDetailsClient } from "./client";

export default async function DeploymentDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const idNum = Number(id);
  return <DeployDetailsClient id={Number.isFinite(idNum) ? idNum : 0} />;
}
