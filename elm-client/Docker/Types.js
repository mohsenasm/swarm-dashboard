export const plannedTask = ({ id, serviceId, slot, status, desiredState, containerSpec }) => ({
  id,
  serviceId,
  slot,
  status,
  desiredState,
  containerSpec
});

export const assignedTask = ({ id, serviceId, nodeId, slot, status, desiredState, containerSpec, info }) => ({
  id,
  serviceId,
  nodeId: nodeId || '',
  slot,
  status,
  desiredState,
  containerSpec,
  info
});

export const taskIndexKey = ({ nodeId, serviceId }) => [nodeId, serviceId];
