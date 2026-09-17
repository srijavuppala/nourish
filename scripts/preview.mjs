import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {DatabaseSync} from 'node:sqlite';
import worker from '../server/index.js';
fs.mkdirSync('.sites-runtime',{recursive:true});
const db=new DatabaseSync('.sites-runtime/preview.sqlite');
db.exec(fs.readFileSync('drizzle/0000_steep_next_avengers.sql','utf8').replace('CREATE TABLE','CREATE TABLE IF NOT EXISTS'));
const DB={prepare(sql){return {bind(...params){return {async first(){return db.prepare(sql).get(...params)??null;},async run(){return db.prepare(sql).run(...params);}}}}}};
const mime={'.html':'text/html','.js':'application/javascript','.json':'application/json','.wasm':'application/wasm','.ttf':'font/ttf','.otf':'font/otf','.png':'image/png','.jpg':'image/jpeg','.svg':'image/svg+xml','.bin':'application/octet-stream'};
http.createServer(async(req,res)=>{
 try{
  const origin='http://'+req.headers.host;
  if(req.url.startsWith('/api/')){
   const chunks=[];for await(const chunk of req)chunks.push(chunk);
   const request=new Request(origin+req.url,{method:req.method,headers:req.headers,...(req.method==='GET'?{}:{body:Buffer.concat(chunks)})});
   const response=await worker.fetch(request,{DB});
   const responseHeaders=Object.fromEntries(response.headers); if(responseHeaders['set-cookie']) responseHeaders['set-cookie']=responseHeaders['set-cookie'].replace('; Secure',''); res.writeHead(response.status,responseHeaders);res.end(Buffer.from(await response.arrayBuffer()));return;
  }
  const pathname=decodeURIComponent(new URL(req.url,origin).pathname);
  const filename=path.resolve('dist/client','.'+(pathname==='/'?'/index.html':pathname));
  if(!filename.startsWith(path.resolve('dist/client')+path.sep)||!fs.existsSync(filename)||!fs.statSync(filename).isFile()){res.writeHead(404);res.end('Not found');return;}
  res.writeHead(200,{'content-type':mime[path.extname(filename)]||'application/octet-stream'});
  fs.createReadStream(filename).pipe(res);
 }catch(e){console.error(e);res.writeHead(500);res.end('Preview error');}
}).listen(Number(process.env.PORT||4173),'0.0.0.0',()=>console.log('Nourish preview ready'));
