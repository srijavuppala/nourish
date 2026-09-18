const headers = {'content-type':'application/json','cache-control':'no-store'};
function json(body,status=200,extra={}) {return new Response(JSON.stringify(body),{status,headers:{...headers,...extra}});}
export default {
 async fetch(request,env) {
  const url=new URL(request.url);
  if(url.pathname==='/api/config'){
   const publishable=env.SUPABASE_PUBLISHABLE_KEY||'';
   // Never return a secret or service-role credential to the client.
   if(publishable.startsWith('sb_secret_'))return json({error:'Invalid public configuration'},503);
   if(publishable.startsWith('eyJ')){
    try{const payload=JSON.parse(atob(publishable.split('.')[1].replace(/-/g,'+').replace(/_/g,'/')));if(payload.role!=='anon')return json({error:'Invalid public configuration'},503);}catch{return json({error:'Invalid public configuration'},503);}
   }
   return json({supabaseUrl:env.SUPABASE_URL||null,supabasePublishableKey:publishable||null});
  }
  if(url.pathname!='/api/state'){
   if(env.ASSETS)return env.ASSETS.fetch(request);
   return new Response('Not found',{status:404});
  }
  if(!env.DB)return json({error:'Storage unavailable'},503);
  const raw=request.headers.get('cookie')||'';
  const match=raw.match(/(?:^|;\s*)nourish_session=([a-f0-9]{64})(?:;|$)/);
  let session=match?.[1];
  const extra={};
  if(!session){
    if(request.method!=='GET')return json({error:'Open the diary first'},401);
    session=Array.from(crypto.getRandomValues(new Uint8Array(32)),b=>b.toString(16).padStart(2,'0')).join('');
    extra['set-cookie']='nourish_session='+session+'; Path=/; Max-Age=31536000; HttpOnly; Secure; SameSite=Strict';
  }
  try{
   if(request.method==='GET'){
    const row=await env.DB.prepare('SELECT state FROM diaries WHERE session = ?').bind(session).first();
    return json({state:row?JSON.parse(row.state):null},200,extra);
   }
   if(request.method!=='PUT')return json({error:'Method not allowed'},405);
   if(request.headers.get('origin')!==url.origin)return json({error:'Invalid origin'},403);
   if(!request.headers.get('content-type')?.includes('application/json'))return json({error:'JSON required'},415);
   const body=await request.text();
   if(body.length>500000)return json({error:'Diary limit exceeded'},413);
   let state;try{state=JSON.parse(body);}catch{return json({error:'Invalid JSON'},400);}
   if(!state.profile||!Array.isArray(state.meals)||!Array.isArray(state.saved)||state.meals.length>2000)return json({error:'Invalid diary'},400);
   if(typeof state.profile.name!=='string'||state.profile.name.length>100)return json({error:'Invalid profile'},400);
   for(const key of ['calories','protein','carbs','fat'])if(!Number.isFinite(state.profile[key])||state.profile[key]<=0||state.profile[key]>10000)return json({error:'Invalid goals'},400);
   for(const m of state.meals){
    if(typeof m.name!=='string'||m.name.length>300||!/^\d{4}-\d{2}-\d{2}$/.test(m.date)||!['Breakfast','Lunch','Dinner','Snacks'].includes(m.group))return json({error:'Invalid meal'},400);
    for(const key of ['kcal','p','c','f','servings'])if(!Number.isFinite(m[key])||m[key]<0||m[key]>100000000)return json({error:'Invalid nutrition'},400);
   }
   for(const key of ['plans','workouts','weights','groceriesChecked']){
    if(state[key]!=null&&(!Array.isArray(state[key])||state[key].length>2000))return json({error:'Invalid planner state'},400);
   }
   for(const workout of state.workouts||[]){
    if(typeof workout.id!=='string'||typeof workout.title!=='string'||workout.title.length>100||!/^\d{4}-\d{2}-\d{2}$/.test(workout.date)||!Number.isInteger(workout.minutes)||workout.minutes<1||workout.minutes>300||!Array.isArray(workout.exercises)||workout.exercises.length<1||workout.exercises.length>20)return json({error:'Invalid workout'},400);
    for(const e of workout.exercises)if(typeof e.name!=='string'||e.name.length>100||!Number.isInteger(e.sets)||e.sets<1||e.sets>20||typeof e.reps!=='string'||typeof e.load!=='string')return json({error:'Invalid exercise'},400);
   }
   for(const entry of state.weights||[])if(!Number.isFinite(entry.kg)||entry.kg<20||entry.kg>500||!/^\d{4}-\d{2}-\d{2}$/.test(entry.date))return json({error:'Invalid weight entry'},400);
   if(state.water!=null){
    if(typeof state.water!=='object'||Array.isArray(state.water))return json({error:'Invalid water log'},400);
    for(const [date,ml] of Object.entries(state.water))if(!/^\d{4}-\d{2}-\d{2}$/.test(date)||!Number.isFinite(ml)||ml<0||ml>20000)return json({error:'Invalid water amount'},400);
   }
   await env.DB.prepare('INSERT INTO diaries (session,state,updated_at) VALUES (?,?,?) ON CONFLICT(session) DO UPDATE SET state=excluded.state, updated_at=excluded.updated_at').bind(session,body,Date.now()).run();
   return json({ok:true});
  }catch(e){console.error('Diary storage error',e.message);return json({error:'Could not save or load diary'},503);}
 }
};
