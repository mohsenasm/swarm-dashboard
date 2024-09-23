var fs = require('fs');
var http = require('http');
var https = require('https');
const { createHash } = require('crypto');
const parsePrometheusTextFormat = require('parse-prometheus-text-format');

const ws = require('ws');
const express = require('express');
const basicAuth = require('express-basic-auth')
const { v4: uuidv4 } = require('uuid');
const url = require('url');
const { sortBy, prop } = require('ramda');
const moment = require('moment');

const port = process.env.PORT || 8080;
const realm = process.env.AUTHENTICATION_REALM || "KuW2i9GdLIkql";
const enableAuthentication = process.env.ENABLE_AUTHENTICATION === "true"
const username = process.env.USERNAME || "admin";
const password = process.env.PASSWORD || "supersecret";
const enableHTTPS = process.env.ENABLE_HTTPS === "true";
const legoPath = process.env.LEGO_PATH || "/lego-files";
const httpsHostname = process.env.HTTPS_HOSTNAME;
const dockerUpdateInterval = parseInt(process.env.DOCKER_UPDATE_INTERVAL || "5000");
const metricsUpdateInterval = parseInt(process.env.METRICS_UPDATE_INTERVAL || "30000");
const showTaskTimestamp = !(process.env.SHOW_TASK_TIMESTAMP === "false");
const enableNetworks = !(process.env.ENABLE_NETWORKS === "false");
const debugMode = process.env.DEBUG_MODE === "true";
const enableDataAPI = process.env.ENABLE_DATA_API === "true";

const _nodeExporterServiceNameRegex = process.env.NODE_EXPORTER_SERVICE_NAME_REGEX || "";
const useNodeExporter = _nodeExporterServiceNameRegex !== "";
const nodeExporterServiceNameRegex = new RegExp(_nodeExporterServiceNameRegex);
const nodeExporterInterestedMountPoint = process.env.NODE_EXPORTER_INTERESTED_MOUNT_POINT || "/";
const nodeExporterPort = process.env.NODE_EXPORTER_PORT || "9100";

const _cadvisorServiceNameRegex = process.env.CADVISOR_SERVICE_NAME_REGEX || "";
const useCadvisor = _cadvisorServiceNameRegex !== "";
const cadvisorServiceNameRegex = new RegExp(_cadvisorServiceNameRegex);
const cadvisorPort = process.env.CADVISOR_PORT || "8080";

let pathPrefix = process.env.PATH_PREFIX || "/";
if (pathPrefix.endsWith("/")) {
  pathPrefix = pathPrefix.slice(0, -1);
}


const sha1OfData = data =>
  createHash('sha1').update(JSON.stringify(data)).digest('hex');

const sum = (arr) => {
  var res = undefined; for (let i = 0; i < arr.length; i++) { if (res === undefined) res = 0; res += arr[i]; } return res;
}

function formatBytes(bytes, decimals = 0) {
  if (!+bytes) return '0 Bytes'
  const k = 1000
  const dm = decimals < 0 ? 0 : decimals
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(dm))}${sizes[i]}`
}

// Docker API integration

const dockerRequestBaseOptions = {
  method: 'GET',
  socketPath: '/var/run/docker.sock',
};

const dockerAPIRequest = path => {
  return new Promise((res, rej) => {
    let buffer = '';

    const r = http.request({ ...dockerRequestBaseOptions, path }, response => {
      response.on('data', chunk => (buffer = buffer + chunk));
      response.on('end', () => res(buffer));
    });

    r.on('error', rej);

    r.end();
  });
};

const fetchDockerData = () =>
  Promise.all([
    dockerAPIRequest('/nodes').then(JSON.parse),
    dockerAPIRequest('/services').then(JSON.parse),
    dockerAPIRequest('/networks').then(JSON.parse),
    dockerAPIRequest('/tasks').then(JSON.parse),
  ]).then(([nodes, services, networks, tasks]) => ({
    nodes,
    services,
    networks,
    tasks,
  }));

// Fetch metrics

const metricRequest = (url) => {
  return new Promise((res, rej) => {
    let buffer = '';

    const r = http.request(url, response => {
      response.on('data', chunk => (buffer = buffer + chunk));
      response.on('end', () => res(buffer));
    });

    r.on('error', rej);

    r.end();
  });
};

const fetchMetrics = (addresses) => {
  let promises = [];
  for (let i = 0; i < addresses.length; i++) {
    promises.push(metricRequest(addresses[i]).then(parsePrometheusTextFormat));
  }
  return Promise.all(promises);
}

// Docker API returns networks in an undefined order, this
// stabilizes the order for effective caching
const stabilize = data => {
  return { ...data, networks: sortBy(prop('Id'), data.networks) };
};

const parseAndRedactDockerData = data => {
  const now = moment();
  const refreshTime = now.format('YYYY-MM-DD HH:mm:ss');

  let nodes = [];
  let networks = [];
  let services = [];
  let tasks = [];

  let nodeExporterServiceIDs = [];
  let runningNodeExportes = [];
  let cadvisorServiceIDs = [];
  let runningCadvisors = [];
  let runningTasksID = [];

  for (let i = 0; i < data.nodes.length; i++) {
    const baseNode = data.nodes[i];
    let node = {
      "ID": baseNode["ID"],
      "Description": {
        "Hostname": baseNode["Description"]["Hostname"],
      },
      "Spec": {
        "Role": baseNode["Spec"]["Role"],
      },
      "Status": {
        "State": baseNode["Status"]["State"],
        "Addr": baseNode["Status"]["Addr"],
      },
    };
    if (baseNode["ManagerStatus"] !== undefined) {
      node["ManagerStatus"] = {
        "Leader": baseNode["ManagerStatus"]["Leader"],
        "Reachability": baseNode["ManagerStatus"]["Reachability"],
      }
    }
    nodes.push(node);
  }

  if (enableNetworks) {
    for (let i = 0; i < data.networks.length; i++) {
      const baseNetwork = data.networks[i];
      let network = {
        "Id": baseNetwork["Id"],
        "Name": baseNetwork["Name"],
        "Ingress": baseNetwork["Ingress"],
      };
      networks.push(network);
    }
  }

  for (let i = 0; i < data.services.length; i++) {
    const baseService = data.services[i];
    let service = {
      "ID": baseService["ID"],
      "Spec": {
        "Name": baseService["Spec"]["Name"],
        "TaskTemplate": {
          "ContainerSpec": {
            "Image": baseService["Spec"]["TaskTemplate"]["ContainerSpec"]["Image"]
          },
        },
      },
    };
    if (enableNetworks && (baseService["Endpoint"] !== undefined)) {
      const _baseVIPs = baseService["Endpoint"]["VirtualIPs"];
      if (_baseVIPs !== undefined && Array.isArray(_baseVIPs) && _baseVIPs.length > 0) {
        let vips = []
        for (let j = 0; j < _baseVIPs.length; j++) {
          const _baseVIP = _baseVIPs[j];
          vips.push({
            "NetworkID": _baseVIP["NetworkID"],
          })
        }
        service["Endpoint"] = {
          "VirtualIPs": vips
        }
      }
    }
    services.push(service);

    if (useNodeExporter) {
      if (nodeExporterServiceNameRegex.test(baseService["Spec"]["Name"])) {
        nodeExporterServiceIDs.push(baseService["ID"]);
      }
    }
    if (useCadvisor) {
      if (cadvisorServiceNameRegex.test(baseService["Spec"]["Name"])) {
        cadvisorServiceIDs.push(baseService["ID"]);
      }
    }
  }

  for (let i = 0; i < data.tasks.length; i++) {
    const baseTask = data.tasks[i];
    const lastTimestamp = moment(baseTask["Status"]["Timestamp"]);
    let timestateInfo = undefined;
    if (showTaskTimestamp) {
      timestateInfo = moment.duration(lastTimestamp - now).humanize(true);
    }
    let task = {
      "ID": baseTask["ID"],
      "ServiceID": baseTask["ServiceID"],
      "Status": {
        "Timestamp": baseTask["Status"]["Timestamp"],
        "State": baseTask["Status"]["State"],
        "timestateInfo": timestateInfo,
      },
      "DesiredState": baseTask["DesiredState"],
      "Spec": {
        "ContainerSpec": {
          "Image": baseTask["Spec"]["ContainerSpec"]["Image"]
        }
      },
      "info": {} // for cpu and memory
    };
    if (baseTask["NodeID"] !== undefined)
      task["NodeID"] = baseTask["NodeID"]
    if (baseTask["Slot"] !== undefined)
      task["Slot"] = baseTask["Slot"]
    tasks.push(task);

    // get addresses for metrics
    if (nodeExporterServiceIDs.length > 0) {
      if ((nodeExporterServiceIDs.includes(baseTask["ServiceID"])) &&
        (baseTask["Status"]["State"] === "running") &&
        (baseTask["NodeID"] !== undefined) &&
        (baseTask["NetworksAttachments"] !== undefined)) {
        let ipList = [];
        // TODO: we use ip of the accessible network instead of ipList[0]
        for (let j = 0; j < baseTask["NetworksAttachments"].length; j++) {
          for (let k = 0; k < baseTask["NetworksAttachments"][j]["Addresses"].length; k++) {
            let ip = baseTask["NetworksAttachments"][j]["Addresses"][k];
            ipList.push(ip.split("/")[0]);
          }
        }
        runningNodeExportes.push({ nodeID: baseTask["NodeID"], address: ipList[0] });
      }
    }
    if (cadvisorServiceIDs.length > 0) {
      if ((cadvisorServiceIDs.includes(baseTask["ServiceID"])) &&
        (baseTask["Status"]["State"] === "running") &&
        (baseTask["NetworksAttachments"] !== undefined)) {
        let ipList = [];
        // TODO: we use ip of the accessible network instead of ipList[0]
        for (let j = 0; j < baseTask["NetworksAttachments"].length; j++) {
          for (let k = 0; k < baseTask["NetworksAttachments"][j]["Addresses"].length; k++) {
            let ip = baseTask["NetworksAttachments"][j]["Addresses"][k];
            ipList.push(ip.split("/")[0]);
          }
        }
        runningCadvisors.push({ address: ipList[0] });
      }
    }
    if (baseTask["Status"]["State"] === "running") {
      runningTasksID.push(baseTask["ID"]);
    }
  }

  return {
    data: { nodes, networks, services, tasks, refreshTime },
    runningNodeExportes, runningCadvisors, runningTasksID
  };
};

const findMetricValue = (metrics, name, searchLabels) => {
  let values = findAllMetricValue(metrics, name, searchLabels);
  if (values.length > 0) {
    return values[0]
  }
  return undefined;
}


const findAllMetricValue = (metrics, name, searchLabels) => {
  let results = [];
  for (let i = 0; i < metrics.length; i++) {
    const metricsParent = metrics[i];
    if (metricsParent.name === name) {
      for (let j = 0; j < metricsParent.metrics.length; j++) {
        const metric = metricsParent.metrics[j];
        let allLabelsExists = true;
        if (metric.labels !== undefined) {
          for (let k = 0; k < searchLabels.length; k++) {
            const label = searchLabels[k];
            if (label.value !== undefined) {
              if (metric.labels[label.name] !== label.value) {
                allLabelsExists = false;
              }
            } else if (label.notValue !== undefined) {
              if (metric.labels[label.name] === label.notValue) {
                allLabelsExists = false;
              }
            }
          }
        }
        if (allLabelsExists) {
          results.push(parseFloat(metric.value));
        }
      }
    }
  }
  return results;
}


const currentTime = () => Math.floor(Date.now() / 1000);

const fetchNodeMetrics = ({ lastData, lastRunningNodeExportes, lastNodeMetrics }, callback) => {
  let nodeMetrics = [];
  if (lastRunningNodeExportes.length > 0) { // should fetch metrics
    fetchMetrics(lastRunningNodeExportes.map(({ address }) => `http://${address}:${nodeExporterPort}/metrics`))
      .then(metricsList => {
        for (let i = 0; i < lastData.nodes.length; i++) {
          let node = lastData.nodes[i];
          for (let j = 0; j < lastRunningNodeExportes.length; j++) {
            const nodeExporterTask = lastRunningNodeExportes[j];
            if (node["ID"] === nodeExporterTask.nodeID) {
              const metricsOfThisNode = metricsList[j];
              const metricToSave = { nodeID: node["ID"], fetchTime: currentTime() };

              // last metrics
              let lastMetricsOfThisNode = {};
              let timeDiffFromLastMetrics = 0;
              for (let k = 0; k < lastNodeMetrics.length; k++) {
                if (lastNodeMetrics[k].nodeID === node["ID"]) {
                  lastMetricsOfThisNode = lastNodeMetrics[k];
                  timeDiffFromLastMetrics = metricToSave.fetchTime - lastMetricsOfThisNode.fetchTime
                  break;
                }
              }

              // disk
              let freeDisk = findMetricValue(metricsOfThisNode, "node_filesystem_avail_bytes", [{ name: "mountpoint", value: nodeExporterInterestedMountPoint }]);
              let totalDisk = findMetricValue(metricsOfThisNode, "node_filesystem_size_bytes", [{ name: "mountpoint", value: nodeExporterInterestedMountPoint }]);
              if ((freeDisk !== undefined) && (totalDisk !== undefined)) {
                metricToSave.diskFullness = Math.round((totalDisk - freeDisk) * 100 / totalDisk);
              }

              // cpu
              metricToSave.cpuSecondsTotal = sum(findAllMetricValue(metricsOfThisNode, "node_cpu_seconds_total", [{ name: "mode", notValue: "idle" }]));
              if (
                (metricToSave.cpuSecondsTotal !== undefined) &&
                (lastMetricsOfThisNode.cpuSecondsTotal !== undefined) &&
                (timeDiffFromLastMetrics > 0)
              ) {
                metricToSave.cpuPercent = Math.round((metricToSave.cpuSecondsTotal - lastMetricsOfThisNode.cpuSecondsTotal) * 100 / timeDiffFromLastMetrics);
              }

              // memory
              let node_memory_MemFree_bytes = findMetricValue(metricsOfThisNode, "node_memory_MemFree_bytes", []);
              let node_memory_Cached_bytes = findMetricValue(metricsOfThisNode, "node_memory_Cached_bytes", []);
              let node_memory_Buffers_bytes = findMetricValue(metricsOfThisNode, "node_memory_Buffers_bytes", []);
              let node_memory_MemTotal_bytes = findMetricValue(metricsOfThisNode, "node_memory_MemTotal_bytes", []);
              if (
                (node_memory_MemFree_bytes !== undefined) &&
                (node_memory_Cached_bytes !== undefined) &&
                (node_memory_Buffers_bytes !== undefined) &&
                (node_memory_MemTotal_bytes !== undefined) &&
                (node_memory_MemTotal_bytes > 0)
              ) {
                metricToSave.memoryPercent = Math.round(
                  100 * (1 - ((node_memory_MemFree_bytes + node_memory_Cached_bytes + node_memory_Buffers_bytes) / node_memory_MemTotal_bytes))
                );
              }

              nodeMetrics.push(metricToSave);
            }
          }
        }
        callback(nodeMetrics);
      })
      .catch(e => {
        console.error('Could not fetch node metrics', e)
        callback(nodeMetrics);
      });
  } else {
    callback(nodeMetrics);
  }
}

const fetchTasksMetrics = ({ lastRunningCadvisors, lastRunningTasksMetrics, lastRunningTasksID }, callback) => {
  let runningTasksMetrics = [];
  if (lastRunningCadvisors.length > 0) { // should fetch metrics
    fetchMetrics(lastRunningCadvisors.map(({ address }) => `http://${address}:${cadvisorPort}/metrics`))
      .then(metricsList => {
        let allMetrics = [];
        for (let i = 0; i < metricsList.length; i++) {
          allMetrics = allMetrics.concat(metricsList[i]);
        }
        for (let i = 0; i < lastRunningTasksID.length; i++) {
          let taskID = lastRunningTasksID[i];
          const metricToSave = { taskID, fetchTime: currentTime() };

          // last metrics
          let lastMetricsOfThisTask = {};
          let timeDiffFromLastMetrics = 0;
          for (let k = 0; k < lastRunningTasksMetrics.length; k++) {
            if (lastRunningTasksMetrics[k].taskID === taskID) {
              lastMetricsOfThisTask = lastRunningTasksMetrics[k];
              timeDiffFromLastMetrics = metricToSave.fetchTime - lastMetricsOfThisTask.fetchTime
              break;
            }
          }

          // cpu
          metricToSave.cpuSecondsTotal = sum(findAllMetricValue(allMetrics, "container_cpu_usage_seconds_total", [{ name: "container_label_com_docker_swarm_task_id", value: taskID }]));
          if (
            (lastMetricsOfThisTask.cpuSecondsTotal !== undefined) &&
            (timeDiffFromLastMetrics > 0)
          ) {
            metricToSave.cpuPercent = Math.round((metricToSave.cpuSecondsTotal - lastMetricsOfThisTask.cpuSecondsTotal) * 100 / timeDiffFromLastMetrics);
          }

          // memory
          metricToSave.memoryBytes = findMetricValue(allMetrics, "container_memory_rss", [{ name: "container_label_com_docker_swarm_task_id", value: taskID }]);
          // let memoryUsage = findMetricValue(allMetrics, "container_memory_usage_bytes", [{ name: "container_label_com_docker_swarm_task_id", value: taskID }]);
          // let memoryCache = findMetricValue(allMetrics, "container_memory_cache", [{ name: "container_label_com_docker_swarm_task_id", value: taskID }]);
          // console.log(memoryUsage, memoryCache);
          // if (
          //   (memoryUsage !== undefined) &&
          //   (memoryCache !== undefined)
          // ) {
          //   metricToSave.memoryBytes = memoryUsage - memoryCache
          // }

          runningTasksMetrics.push(metricToSave);
        }
        callback(runningTasksMetrics);
      })
      .catch(e => {
        console.error('Could not fetch tasks metrics', e)
        callback(runningTasksMetrics);
      });
  } else {
    callback(runningTasksMetrics);
  }
}

const addNodeMetricsToData = (data, lastNodeMetrics) => {
  for (let i = 0; i < data.nodes.length; i++) {
    const node = data.nodes[i];
    for (let j = 0; j < lastNodeMetrics.length; j++) {
      const nodeMetric = lastNodeMetrics[j];
      if (nodeMetric.nodeID === node["ID"]) {
        let info = "";
        if (nodeMetric.diskFullness !== undefined) {
          info += `disk: ${nodeMetric.diskFullness}%`;
        }
        if (nodeMetric.cpuPercent !== undefined) {
          if (info)
            info += " | "
          info += `cpu: ${nodeMetric.cpuPercent}%`;
        }
        if (nodeMetric.memoryPercent !== undefined) {
          if (info)
            info += " | "
          info += `mem: ${nodeMetric.memoryPercent}%`;
        }
        if (info) {
          node.info = info;
        }
      }
    }
  }
}
const addTaskMetricsToData = (data, lastRunningTasksMetrics) => {
  for (let i = 0; i < data.tasks.length; i++) {
    const task = data.tasks[i];
    for (let j = 0; j < lastRunningTasksMetrics.length; j++) {
      const taskMetric = lastRunningTasksMetrics[j];
      if (taskMetric.taskID === task["ID"]) {
        if (taskMetric.cpuPercent !== undefined) {
          task.info.cpu = `cpu: ${taskMetric.cpuPercent}%`;
        }
        if (taskMetric.memoryBytes !== undefined) {
          task.info.memory = `mem: ${formatBytes(taskMetric.memoryBytes)}`;
        }
      }
    }
  }
}

// WebSocket pub-sub

const publish = (listeners, data) => {
  listeners.forEach(listener => {
    if (listener.readyState !== ws.OPEN) return;

    listener.send(JSON.stringify(data, null, 2));
  });
};

const subscribe = (listeners, newListener) => {
  return listeners.concat([newListener]);
};

const unsubscribe = (listeners, listener) => {
  const id = listeners.indexOf(listener);
  if (id < 0) return listeners;

  return [].concat(listeners).splice(id, 1);
};

const dropClosed = listeners => {
  return listeners.filter(ws => ws.readyState === ws.OPEN);
};

// set up the application

let lastRunningNodeExportes = [];
let lastNodeMetrics = [];
let lastRunningCadvisors = [];
let lastRunningTasksID = [];
let lastRunningTasksMetrics = [];

let listeners = [];
let lastData = {};
let lastSha = '';

users = {};
users[username] = password;
const basicAuthConfig = () => basicAuth({
  users: users,
  challenge: true,
  realm: realm,
})
const tokenStore = new Set();

const app = express();
const router = express.Router();
router.use(express.static('client'));
router.get('/_health', (req, res) => res.end());
if (enableAuthentication) {
  router.get('/auth_token', basicAuthConfig(), (req, res) => {
    const token = uuidv4();
    tokenStore.add(token);
    res.send(token);
  });
  if (enableDataAPI) {
    router.get('/data', basicAuthConfig(), (req, res) => {
      res.send(lastData);
    });
  }
} else {
  router.get('/auth_token', (req, res) => {
    res.send("no-auth-token-needed");
  });
  if (enableDataAPI) {
    router.get('/data', (req, res) => {
      res.send(lastData);
    });
  }
}
if (debugMode) {
  console.log("debug mode is active");
  router.get('/debug-log', (req, res) => {
    console.log("lastRunningNodeExportes", lastRunningNodeExportes);
    console.log("lastNodeMetrics", lastNodeMetrics);
    console.log("lastRunningCadvisors", lastRunningCadvisors);
    console.log("lastRunningTasksID", lastRunningTasksID);
    console.log("lastRunningTasksMetrics", lastRunningTasksMetrics);
    console.log("---------------");
    res.send("logged.")
  });
}

app.use(pathPrefix + "/", router);

// start the polling
setInterval(() => { // update docker data
  fetchDockerData()
    .then(it => {
      let { data, runningNodeExportes, runningCadvisors, runningTasksID } = parseAndRedactDockerData(it);
      addNodeMetricsToData(data, lastNodeMetrics); // it makes fetching of main data and node metrics independent.
      addTaskMetricsToData(data, lastRunningTasksMetrics); // it makes fetching of main data and node metrics independent.

      data = stabilize(data);
      const sha = sha1OfData(data);

      if (sha == lastSha) return;

      lastSha = sha;
      lastData = data;
      lastRunningNodeExportes = runningNodeExportes;
      lastRunningCadvisors = runningCadvisors;
      lastRunningTasksID = runningTasksID;

      listeners = dropClosed(listeners);
      publish(listeners, data);
    })
    .catch(e => console.error('Could not publish', e)); // eslint-disable-line no-console
}, dockerUpdateInterval); // refreshs each 1s

setInterval(() => { // update node data
  fetchNodeMetrics({ lastData, lastRunningNodeExportes, lastNodeMetrics }, (nodeMetrics) => {
    lastNodeMetrics = nodeMetrics;
  })
}, metricsUpdateInterval); // refreshs each 5s

setInterval(() => { // update node data
  fetchTasksMetrics({ lastRunningCadvisors, lastRunningTasksMetrics, lastRunningTasksID }, (runningTasksMetrics) => {
    lastRunningTasksMetrics = runningTasksMetrics;
  })
}, metricsUpdateInterval); // refreshs each 5s

function onWSConnection(ws, req) {
  let params = undefined;
  let authToken = undefined;
  if (req)
    params = url.parse(req.url, true).query; // { authToken: 'ajsdhakjsdhak' } for 'ws://localhost:1234/?authToken=ajsdhakjsdhak'
  if (params)
    authToken = params.authToken;

  if (!enableAuthentication || tokenStore.has(authToken)) {
    if (enableAuthentication) {
      tokenStore.delete(authToken);
    }

    listeners = subscribe(listeners, ws) || [];
    publish([ws], lastData); // immediately send latest to the new listener
    ws.on('close', () => {
      listeners = unsubscribe(listeners, ws) || [];
    });
  } else {
    ws.send("WrongAuthToken");
    setTimeout(() => {
      ws.close(); // terminate this connection
    }, 10000);
  }
}


// set up the server

if (enableHTTPS) {
  const privateKeyPath = legoPath + '/certificates/' + httpsHostname + '.key';
  const certificatePath = legoPath + '/certificates/' + httpsHostname + '.crt';
  const privateKey = fs.readFileSync(privateKeyPath, 'utf8');
  const certificate = fs.readFileSync(certificatePath, 'utf8');
  const credentials = { key: privateKey, cert: certificate }
  const httpsServer = https.createServer(credentials);
  httpsServer.on('request', app);
  const wsServer = new ws.Server({
    path: pathPrefix + '/stream',
    server: httpsServer,
  });
  wsServer.on('connection', onWSConnection);
  httpsServer.listen(port, () => {
    console.log(`HTTPS server listening on ${port}`); // eslint-disable-line no-console
  });
  fs.watchFile(certificatePath, { interval: 1000 }, () => {
    try {
      console.log('Reloading TLS certificate');
      const privateKey = fs.readFileSync(privateKeyPath, 'utf8');
      const certificate = fs.readFileSync(certificatePath, 'utf8');
      const credentials = { key: privateKey, cert: certificate }
      httpsServer.setSecureContext(credentials);
    } catch (e) {
      console.log(e)
    }
  });
} else {
  const httpServer = http.createServer();
  httpServer.on('request', app);
  const wsServer = new ws.Server({
    path: pathPrefix + '/stream',
    server: httpServer,
  });
  wsServer.on('connection', onWSConnection);
  httpServer.listen(port, () => {
    console.log(`HTTP server listening on ${port}`); // eslint-disable-line no-console
  });
}
