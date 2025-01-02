import React from 'react';
import { groupBy, iff, CustomMap } from '../Util';

const networkColors = [
  'rgb(215, 74, 136)',
  'rgb(243, 154, 155)',
  'rgb(169, 65, 144)',
  'rgb(249, 199, 160)',
  'rgb(263, 110, 141)'
];

const networkColor = (i) => networkColors[i % networkColors.length] || 'white';

const widthStep = 16;

const totalWidth = (list) => list.length * widthStep;

const columnCenter = (i) => i * widthStep + widthStep / 2;

const columnStart = (i) => i * widthStep;

const svgLine = ([ox, oy], [dx, dy], width, color, name) => (
  <line
    x1={ox}
    y1={oy}
    x2={dx}
    y2={dy}
    strokeWidth={width}
    stroke={color}
  >
    <title>{name}</title>
  </line>
);

const svgCircle = ([cenx, ceny], rad, color, name) => (
  <circle
    cx={cenx}
    cy={ceny}
    r={rad}
    fill={color}
  >
    <title>{name}</title>
  </circle>
);

const topLine = (i, color, name) => svgLine([columnCenter(i), 0], [columnCenter(i), 31], 2, color, name);

const bottomLine = (i, color, name) => svgLine([columnCenter(i), 31], [columnCenter(i), 62], 2, color, name);

const dot = (i, color, name) => svgCircle([columnCenter(i), 31], widthStep / 3, color, name);

const fullLine = (i, color, name) => svgLine([columnCenter(i), 0], [columnCenter(i), 1], 2, color, name);

const tcap = (i, color, name) => [
  svgLine([columnStart(i) + widthStep / 6, 0], [columnStart(i) + widthStep * 5 / 6, 0], 4, color, name),
  svgLine([columnCenter(i), 0], [columnCenter(i), widthStep], 2, color, name)
];

const head = (networks) => (
  <svg width={totalWidth(networks)} height={widthStep} viewBox={`0 0 ${totalWidth(networks)} ${widthStep}`}>
    {networks.flatMap((network, i) => (network.ingress ? tcap(i, 'white', network.name) : []))}
  </svg>
);

const attachments = (connections, colors, names) => (
  <svg width={totalWidth(connections)} height="62" viewBox={`0 0 ${totalWidth(connections)} 62`}>
    {connections.flatMap((connection, i) => {
      const color = colors[i] || 'white';
      const name = names[i] || '';
      switch (connection) {
        case 'Through':
          return [topLine(i, color, name), bottomLine(i, color, name)];
        case 'Start':
          return [dot(i, color, name), bottomLine(i, color, name)];
        case 'Middle':
          return [topLine(i, color, name), dot(i, color, name), bottomLine(i, color, name)];
        case 'End':
          return [topLine(i, color, name), dot(i, color, name)];
        case 'Only':
          return [dot(i, color, name)];
        default:
          return [];
      }
    })}
  </svg>
);

const tails = (connections, colors, names) => (
  <svg width={totalWidth(connections)} height="100%" viewBox={`0 0 ${totalWidth(connections)} 1`} preserveAspectRatio="none">
    {connections.flatMap((connection, i) => {
      const color = colors[i] || 'white';
      const name = names[i] || '';
      return ['Start', 'Middle', 'Through'].includes(connection) ? [fullLine(i, color, name)] : [];
    })}
  </svg>
);

export const buildConnections = (services, networks) => {
  const networkAttachments = services.reduce((acc, service) => {
    service.networks.forEach((networkId) => {
      acc.set([service.id, networkId], true);
    });
    return acc;
  }, new CustomMap());

  const attached = (sid, nid) => networkAttachments.get([sid, nid]) || false;

  const updateBounds = (current, connected, ingress, [first, last]) => [
    connected && !ingress && first < 0 ? current : first,
    connected ? current : last
  ];

  const firstAndLastConnection = (network) => services.reduce(
    (bounds, service, idx) => updateBounds(idx, attached(service.id, network.id), network.ingress, bounds),
    [-1, -1]
  );

  const updateConnections = (network, connections) => {
    const bounds = firstAndLastConnection(network);
    services.forEach((service, idx) => {
      const connectionType = (service, network, connected, idx, [first, last]) => {
        if (idx < first || idx > last) return 'None';
        if (idx === first && idx === last) return 'Only';
        if (idx === first) return 'Start';
        if (idx === last) return 'End';
        return connected ? 'Middle' : 'Through';
      };
      connections[[service.id, network.id]] = connectionType(service, network, attached(service.id, network.id), idx, bounds);
    });
    return connections;
  };

  const connections = networks.reduce(updateConnections, {});
  return { networks, connections };
};

export const header = ({ networks }) => (
  <th className="networks" style={{ width: `${totalWidth(networks)}px` }}>
    {head(networks)}
  </th>
);

export const connections = ({ service, networkConnections }) => {
  const connections = networkConnections.networks.map((network) => networkConnections.connections[[service.id, network.id]] || 'None');
  const colors = networkConnections.networks.map((network, i) => (network.ingress ? 'white' : networkColor(i)));
  const names = networkConnections.networks.map((network) => network.name);
  return (
    <td className="networks">
      {attachments(connections, colors, names)}
      <div>{tails(connections, colors, names)}</div>
    </td>
  );
};
