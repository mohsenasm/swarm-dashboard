import { parse } from './Docker/Json';
import { plannedTask, assignedTask } from './Docker/Types';
import { groupBy, indexBy, unique, iff, complement } from './Util';

const isFailed = ({ state }) => state === 'failed';

const isCompleted = ({ state }) => state === 'rejected' || state === 'shutdown';

// const withoutFailedTaskHistory = (tasks) => {
//   const key = ({ serviceId, slot }) => [serviceId, slot || 0];

//   const latestRunning = (tasks) => tasks.filter((t) => t.status.state !== 'failed').sort((a, b) => b.status.timestamp - a.status.timestamp)[0];
//   const latest = (tasks) => tasks.sort((a, b) => b.status.timestamp - a.status.timestamp).slice(0, 1);
//   const failedOlderThan = (running, task) => isFailed(task.status) && task.status.timestamp < running.status.timestamp;

//   const filterPreviouslyFailed = (tasks) => {
//     const runningTask = latestRunning(tasks);
//     return runningTask ? tasks.filter(complement((task) => failedOlderThan(runningTask, task))) : latest(tasks);
//   };

//   const grouped = groupBy(key, tasks);

//   return grouped.flatMap(filterPreviouslyFailed);
// };

const process = ({ nodes, networks, services, tasks, refreshTime }) => {
  const emptyNetwork = { id: '', ingress: false, name: '' };
  const networkIndex = indexBy((n) => n.id, networks);
  const resolveNetworks = (networkIds) => networkIds.map((id) => networkIndex.get(id) || emptyNetwork);
  const linkNetworks = (services) => services.map((service) => ({ ...service, networks: resolveNetworks(service.networks) }));
  const allNetworks = (services) => unique(services.flatMap((s) => s.networks)).map((id) => networkIndex.get(id) || emptyNetwork).sort((a, b) => a.name.localeCompare(b.name)).sort((a, b) => iff(a.ingress, -1, 1));  

  const [assignedTasks, plannedTasks] = tasks.reduce(
    ([assigned, planned], task) => {
      if (task.nodeId) {
        assigned.push(assignedTask(task));
      } else {
        planned.push(plannedTask(task));
      }
      return [assigned, planned];
    },
    [[], []]
  );

  // const notCompleted = (tasks) => tasks.filter((task) => !isCompleted(task.status));
  // const filterTasks = (tasks) => withoutFailedTaskHistory(notCompleted(tasks));

  // console.log("process assignedTasks", assignedTasks);
  // console.log("process notCompleted(assignedTasks)", notCompleted(assignedTasks));
  // console.log("process filterTasks(assignedTasks)", filterTasks(assignedTasks));

  return {
    nodes: nodes.sort((a, b) => a.name.localeCompare(b.name)),
    networks: allNetworks(services),
    services: linkNetworks(services).sort((a, b) => a.name.localeCompare(b.name)),
    plannedTasks,
    assignedTasks: assignedTasks,
    // assignedTasks: filterTasks(assignedTasks), // TODO: add this back in, or remove
    refreshTime
  };
};

export const fromJson = (json) => {
  const result = parse(json);
  return result.ok ? { ok: true, data: process(result.data) } : result;
};
