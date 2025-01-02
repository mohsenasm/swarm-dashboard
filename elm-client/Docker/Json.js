import { parse as parseDate } from 'date-fns';

const containerSpec = (data) => ({
  image: data.Image
});

const nodeStatus = (data) => ({
  state: data.State,
  address: data.Addr
});

const managerStatus = (data) => ({
  leader: data.Leader,
  reachability: data.Reachability
});

const node = (data) => ({
  id: data.ID,
  name: data.Description.Hostname,
  role: data.Spec.Role,
  status: nodeStatus(data.Status),
  managerStatus: data.ManagerStatus ? managerStatus(data.ManagerStatus) : null,
  info: data.info || null
});

const network = (data) => ({
  id: data.Id,
  name: data.Name,
  ingress: data.Ingress
});

const service = (data) => ({
  id: data.ID,
  name: data.Spec.Name,
  containerSpec: containerSpec(data.Spec.TaskTemplate.ContainerSpec),
  networks: data.Endpoint.VirtualIPs ? data.Endpoint.VirtualIPs.map((vip) => vip.NetworkID) : []
});

const taskStatus = (data) => ({
  timestamp: parseDate(data.Timestamp),
  timestateInfo: data.timestateInfo || null,
  state: data.State
});

const taskInfo = (data) => ({
  cpu: data.cpu || null,
  memory: data.memory || null
});

const task = (data) => ({
  id: data.ID,
  serviceId: data.ServiceID,
  nodeId: data.NodeID || null,
  slot: data.Slot || null,
  status: taskStatus(data.Status),
  desiredState: data.DesiredState,
  containerSpec: containerSpec(data.Spec.ContainerSpec),
  info: taskInfo(data.info)
});

const dockerApi = (data) => ({
  nodes: data.nodes.map(node),
  networks: data.networks.map(network),
  services: data.services.map(service),
  tasks: data.tasks.map(task),
  refreshTime: data.refreshTime
});

export const parse = (json) => {
  try {
    const data = JSON.parse(json);
    return { ok: true, data: dockerApi(data) };
  } catch (error) {
    return { ok: false, error: error.message };
  }
};
