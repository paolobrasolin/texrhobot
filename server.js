'use strict';

// const ChildProcess = require('child_process');

const Hapi = require('hapi');
const Inert = require('inert');

const YAML = require('yamljs');
const fs = require('fs');
const MD5 = require('md5');

const mkdirp = require('mkdirp');
mkdirp('tex_cache');

require('shelljs/global');

const server = new Hapi.Server();
server.connection({
    port: ~~process.env.PORT || 3000,
    host: '0.0.0.0',
    routes: {
        cors: true
    }
});
server.register(Inert, () => {});


server.route({
  method: 'GET',
  path: '/',
  handler: function(req, reply) {
    reply.file('index.html');
  }
});

server.route({
    method: 'POST',
    path: '/svg',
    config: {
        cors: {
            origin: ['*'],
            additionalHeaders: ['cache-control', 'x-requested-with']
        },
        handler: function(request, reply) {

            console.log(request.payload);

            var yaml = YAML.stringify(request.payload);
            var hash = MD5(yaml);

            fs.writeFileSync(
                `tex_cache/${hash}.yml`,
                `---\n${yaml}...`
            );

            var pandoc = exec([
                    'pandoc',
                    `${hash}.yml`,
                    '--template=../template.tex',
                    `--output=${hash}.tex`
                ].join(' '),
                {cwd: 'tex_cache'});

            if (pandoc.code !== 0) {
                return reply("pandoc failed");
            }

            var latex = exec([
                    'latex',
                    '-interaction=batchmode',
                    `${hash}.tex`
                ].join(' '),
                {cwd: 'tex_cache'});

            if (latex.code !== 0) {
                return reply("latex failed");
            }

            var dvisvgm = exec([
                    'dvisvgm',
                    `${hash}.dvi`,
                    '--no-fonts'
                ].join(' '),
                {cwd: 'tex_cache'});

            if (dvisvgm.code !== 0) {
                return reply("dvisvgm failed");
            }

            return reply.file(`tex_cache/${hash}.svg`);
        },
        // validate: {
            // payload: {
                // document: Hapi.types.String().required()
            // }
        // }
    }
});

// Start the server
server.start((err) => {
    if (err) {
        throw err;
    }
    console.log('Server running at:', server.info.uri);
});
