require('babel-register')({
  presets: [['env', { targets: { node: 'current' } }], 'stage-0']
});
require('./server');
