import fastify from "fastify";
import { PassThrough } from "node:stream";

const port = parseInt(process.env.PORT || '11445')

const responseTimeMs = 800;
const response = [
    'You know ',
    'the day destroys',
    ' the night\n',
    'Night',
    ' divides t',
    'he day\n',
    'Tried',
    ' to run\n',
    'Tried',
    ' t',
    'o',
    ' '
    ,'h'
    ,'i',
    'de\n',
    'Break on through to',
    ' the other side\n',
];

const timeToSingleChunkMs = responseTimeMs / response.length;

async function runServer() {
    const app = fastify({});
    app.post('/*', {}, async (req, res) => {
        console.log('Got request', { body: req.body, url: req.url });
        // initial delay to emulate initial delay when querying real model
        await new Promise<void>(res => setTimeout(res, 400));
        res.header('content-type', 'text/plain');
        const outStream = new PassThrough();
        let responseIterator = 0;
        const pusherIntervalId = setInterval(() => {
            const chunk = response[responseIterator]!;
            if (++responseIterator >= response.length) {
                outStream.write(`{"model":"deepseek-coder-v2","created_at":"${new Date().toISOString()}","response":"${chunk.replaceAll('\n', '\\n')}","done":true,"done_reason":"stop","context":[100003,1558,12577,7,64,1780,100002,300,972,12577,7,64,12,16,8,919,12577,7,64,12,17,8,100004,185,300,565,245,788,15,410,245,788,16,25,185,391,972,207,16,185],"total_duration":4032406910,"load_duration":3545696101,"prompt_eval_count":24,"prompt_eval_duration":145000000,"eval_count":18,"eval_duration":341000000}\n`);
                clearInterval(pusherIntervalId);
                outStream.end();
            } else {
                outStream.write(`{"model":"deepseek-coder-v2","created_at":"${new Date().toISOString()}","response":"${chunk.replaceAll('\n', '\\n')}","done":false}\n`);
            }
        }, timeToSingleChunkMs);
        outStream.on('finish', () => {
            res.send(outStream);
        });
        return outStream;
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
