import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';
const send=m=>process.stdout.write(JSON.stringify(m)+'\n');
const tool={name:'get_antigravity_usage',description:'读取 Gemini 娘最近一次取得的 Antigravity 分组额度及重置时间。数据含来源、观察时间与刷新状态。',inputSchema:{type:'object',properties:{},additionalProperties:false},annotations:{readOnlyHint:true,destructiveHint:false,idempotentHint:true,openWorldHint:true}};
async function handle(m){
  if(!m || typeof m!=='object' || Array.isArray(m) || typeof m.method!=='string'){send({jsonrpc:'2.0',id:null,error:{code:-32600,message:'Invalid Request'}});return;}
  if(m.id===undefined)return;
  try{
    let result;
    switch(m.method){
      case 'initialize': result={protocolVersion:m.params?.protocolVersion??'2024-11-05',capabilities:{tools:{}},serverInfo:{name:'gemini-niang',version:'0.1.0'}};break;
      case 'ping':result={};break;
      case 'tools/list':result={tools:[tool]};break;
      case 'tools/call':{
        if(m.params?.name!==tool.name)throw new Error('Unknown tool');
        const file=path.join(process.env.LOCALAPPDATA,'GeminiNiangWidget','status.json');
        const r=JSON.parse(fs.readFileSync(file,'utf8'));
        const data={source:r.source??'Antigravity 设置页快照',observedAt:r.observedAt,plan:r.planLabel,windows:r.windows,error:r.error??null};
        result={content:[{type:'text',text:JSON.stringify(data)}],isError:!r.ok || !r.queryOk};break;
      }
      default:send({jsonrpc:'2.0',id:m.id,error:{code:-32601,message:'Method not found'}});return;
    }
    send({jsonrpc:'2.0',id:m.id,result});
  }catch{send({jsonrpc:'2.0',id:m.id,error:{code:-32603,message:'尚无额度快照，请启动 Gemini 娘挂件并等待首次刷新'}});}
}
readline.createInterface({input:process.stdin}).on('line',line=>{
  if(line.length>1024*1024)return;
  try{void handle(JSON.parse(line));}catch{send({jsonrpc:'2.0',id:null,error:{code:-32700,message:'Invalid JSON'}});}
});
