import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, useLocation } from 'react-router-dom';
import { groupBy } from './Util';
import { fromJson } from './Docker';
import UI from './Components';

const localWebsocket = (location) => {
  return location.protocol === 'https:'
    ? `wss://localhost:8080/stream`
    : `ws://localhost:8080/stream`;
};
// const localWebsocket = (location) => {
//   return location.protocol === 'https:'
//     ? `wss://${location.host}${location.pathname}stream`
//     : `ws://${location.host}${location.pathname}stream`;
// };

const App = () => {
  const location = useLocation();
  const [model, setModel] = useState({
    pathname: location.pathname,
    webSocketUrl: localWebsocket(location),
    authToken: '',
    swarm: { services: [], nodes: [], networks: [], assignedTasks: [], refreshTime: '' },
    tasks: {},
    errors: []
  });

  useEffect(() => {
    const fetchAuthToken = async () => {
      try {
        const response = await fetch(`${location.pathname}auth_token`);
        const authToken = await response.text();
        setModel((prevModel) => ({ ...prevModel, authToken }));
      } catch (error) {
        setModel((prevModel) => ({ ...prevModel, errors: [...prevModel.errors, error.toString()] }));
      }
    };

    fetchAuthToken();
  }, [location.pathname]);

  useEffect(() => {
    if (!model.authToken) return;

    const ws = new WebSocket(`${model.webSocketUrl}?authToken=${model.authToken}`);
    ws.onmessage = (event) => {
      const serverJson = event.data;
      const result = fromJson(serverJson);
      if (result.ok) {
        setModel((prevModel) => ({
          ...prevModel,
          swarm: result.data,
          tasks: groupBy((task) => [task.nodeId, task.serviceId], result.data.assignedTasks)
        }));
      } else {
        if (result.error.includes('WrongAuthToken')) {
          fetchAuthToken();
        } else {
          setModel((prevModel) => ({ ...prevModel, errors: [...prevModel.errors, result.error] }));
        }
      }
    };

    return () => ws.close();
  }, [model.authToken, model.webSocketUrl]);

  const { swarm, tasks, errors } = model;
  const { services, nodes, networks, refreshTime } = swarm;

  return (
    <div>
      <UI.swarmGrid services={services} nodes={nodes} networks={networks} tasks={tasks} refreshTime={refreshTime} />
      <ul>
        {errors.map((error, index) => (
          <li key={index}>{error}</li>
        ))}
      </ul>
    </div>
  );
};

const Main = () => (
  <Router>
    <App />
  </Router>
);

export default Main;
