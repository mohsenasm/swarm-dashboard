import { useMemo } from 'react';
import { groupBy, iff } from '../Util';

const Connection = {
  None: 'None',
  Through: 'Through',
  Start: 'Start',
  Middle: 'Middle',
  End: 'End',
  Only: 'Only'
};

const buildConnections = (services, networks) => {
  const networkAttachments = useMemo(() => {
    const attachments = new Map();
    services.forEach((service) => {
      service.networks.forEach((networkId) => {
        attachments.set([service.id, networkId], true);
      });
    });
    return attachments;
  }, [services]);

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
        if (idx < first || idx > last) return Connection.None;
        if (idx === first && idx === last) return Connection.Only;
        if (idx === first) return Connection.Start;
        if (idx === last) return Connection.End;
        return connected ? Connection.Middle : Connection.Through;
      };
      connections[[service.id, network.id]] = connectionType(service, network, attached(service.id, network.id), idx, bounds);
    });
    return connections;
  };

  const connections = networks.reduce(updateConnections, {});
  return { networks, connections };
};

const serviceConnections = (service, networkConnections) => {
  return networkConnections.networks.map((network) => networkConnections.connections[[service.id, network.id]] || Connection.None);
};

export { buildConnections, serviceConnections, Connection };
