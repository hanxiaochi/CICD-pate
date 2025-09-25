import { DeployDetailsClient } from "./client";

export default function DeploymentDetailPage({ params }: { params: { id: string } }) {
  const idNum = Number(params.id);
  return <DeployDetailsClient id={Number.isFinite(idNum) ? idNum : 0} />;
}