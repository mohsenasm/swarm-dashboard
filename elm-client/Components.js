import React from 'react';
import { groupBy } from './Util';
import { connections as NetworkConnections, header as NetworkHeader, buildConnections } from './Components/Networks';

const statusString = (state, desiredState) => (state === desiredState ? state : `${state} → ${desiredState}`);

const Task = ({ service, task }) => {
  const { status, desiredState, containerSpec, slot, info } = task;
  const classes = [
    status.state,
    'task',
    `desired-${desiredState}`,
    status.state === 'running' && service.containerSpec.image !== containerSpec.image ? 'running-old' : ''
  ].join(' ');

  return (
    <li className={classes}>
      {info.cpu && <div className="tag left">{info.cpu}</div>}
      {info.memory && <div className="tag right">{info.memory}</div>}
      {service.name}
      {slot && `.${slot}`}
      <br />
      {statusString(status.state, desiredState)}
      {status.timestateInfo && <small>{` (${status.timestateInfo})`}</small>}
    </li>
  );
};

const ServiceNode = ({ service, tasks, node }) => {
  const _tasks = tasks[[node.id, service.id]] || [];
  const noTaskNowhere = Object.keys(tasks).filter(([n, s]) => s === service.id).length === 0;

  // console.log("-------");
  // console.log("tasks", tasks)
  // console.log("service.id", service.id);
  // console.log("Object.keys(tasks)", Object.keys(tasks).filter(([n, s]) => s === service.id));
  
  

  return noTaskNowhere ? (
    <td className="empty-service" />
  ) : (
    <td>
      <ul>{_tasks.map((task, idx) => <Task key={idx} service={service} task={task} />)}</ul>
    </td>
  );
};

const ServiceRow = ({ nodes, tasks, networkConnections, service }) => (
  <tr>
    <th>{service.name}</th>
    <NetworkConnections service={service} networkConnections={networkConnections} />
    {nodes.map((node, idx) => (
      <ServiceNode key={idx} service={service} tasks={tasks} node={node} />
    ))}
  </tr>
);

const Node = ({ node }) => {
  const leader = node.managerStatus?.leader || false;
  const classes = [
    node.status.state === 'down' ? 'down' : '',
    node.role === 'manager' ? 'manager' : '',
    leader ? 'leader' : ''
  ].join(' ');

  return (
    <th className={classes}>
      <strong>{node.name}</strong>
      <br />
      {`${node.role} ${leader ? '(leader)' : ''}`}
      <br />
      {node.status.address}
      {node.info && (
        <>
          <br />
          {node.info}
        </>
      )}
    </th>
  );
};

const SwarmHeader = ({ nodes, networks, refreshTime }) => (
  <tr>
    <th>
      <img src="docker_logo.svg" alt="Docker Logo" />
      <div className="refresh-time">{refreshTime}</div>
    </th>
    <NetworkHeader networks={networks} />
    {nodes.map((node, idx) => (
      <Node key={idx} node={node} />
    ))}
  </tr>
);

export const SwarmGrid = ({ services, nodes, networks, tasks, refreshTime }) => {
  const networkConnections = buildConnections(services, networks);
  
  return (
    <table>
      <thead>
        <SwarmHeader nodes={nodes} networks={networks} refreshTime={refreshTime} />
      </thead>
      <tbody>
        {services.map((service, idx) => (
          <ServiceRow
            key={idx}
            nodes={nodes}
            tasks={tasks}
            networkConnections={networkConnections}
            service={service}
          />
        ))}
      </tbody>
    </table>
  );
};
