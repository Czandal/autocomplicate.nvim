import fastify from "fastify";

const port = parseInt(process.env.PORT || '11445')

async function runServer() {
    const app = fastify({});
    app.post('/*', {}, async (req, res) => {
        console.log('Got request', { path: req
    });
    await app.listen({
      port,
      host: '0.0.0.0',
    });
}

runServer()
.then(_ => {
    console.log('Test server running');
})
.catch(err => {
    console.log('Running test server failed', err);
});
